library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity detection_bridge is
    generic (
        FS_HZ : integer := 360 
    );
    Port (
        clk             : in  STD_LOGIC;
        reset           : in  STD_LOGIC;
        d_valid         : in  STD_LOGIC; 
        
        qrs_x, qrs_y, qrs_z : in STD_LOGIC;
        t_x, t_y, t_z       : in STD_LOGIC;
        
        -- Inicializadas para evitar 'U'
        qrs_unified     : out STD_LOGIC := '0';
        t_unified       : out STD_LOGIC := '0';
        
        rr_interval_ms  : out SIGNED(23 downto 0) := (others => '0');
        rt_interval_ms  : out SIGNED(23 downto 0) := (others => '0')
    );
end detection_bridge;

architecture Behavioral of detection_bridge is
    -- Constantes de tiempo
    constant WIN_SAMPLES : integer := (30 * FS_HZ) / 1000;
    constant SAMPLES_R   : integer := (60 * FS_HZ) / 1000;
    constant SAMPLES_T   : integer := (230 * FS_HZ) / 1000;
    
    signal qrs_x_str, qrs_y_str, qrs_z_str : std_logic := '0';
    signal t_x_str, t_y_str, t_z_str       : std_logic := '0';
    signal cnt_qrs_x, cnt_qrs_y, cnt_qrs_z : integer := 0;
    signal cnt_t_x, cnt_t_y, cnt_t_z       : integer := 0;

    signal qrs_voted, t_voted : std_logic := '0';
    signal qrs_voted_prev, t_voted_prev : std_logic := '0';

    signal cnt_rr, cnt_rt     : integer := 0;
    signal rt_busy            : std_logic := '0';
    
    signal qrs_unif_i, t_unif_i : std_logic := '0';
    signal rr_ms_i, rt_ms_i    : signed(23 downto 0) := (others => '0');

begin
    qrs_unified    <= qrs_unif_i;
    t_unified      <= t_unif_i;
    rr_interval_ms <= rr_ms_i;
    rt_interval_ms <= rt_ms_i;

    -- 1. PULSE STRETCHING CORREGIDO
    -- La señal solo baja cuando el contador llega a 0 dentro de un d_valid
    process(clk) begin
        if rising_edge(clk) then
            if reset = '1' then
                qrs_x_str <= '0'; qrs_y_str <= '0'; qrs_z_str <= '0';
                t_x_str <= '0'; t_y_str <= '0'; t_z_str <= '0';
                cnt_qrs_x <= 0; cnt_qrs_y <= 0; cnt_qrs_z <= 0;
                cnt_t_x <= 0; cnt_t_y <= 0; cnt_t_z <= 0;
            else
                -- Eje X
                if qrs_x = '1' then 
                    qrs_x_str <= '1'; cnt_qrs_x <= WIN_SAMPLES;
                elsif d_valid = '1' then
                    if cnt_qrs_x > 0 then cnt_qrs_x <= cnt_qrs_x - 1; 
                    else qrs_x_str <= '0'; end if;
                end if;

                -- Eje Y
                if qrs_y = '1' then 
                    qrs_y_str <= '1'; cnt_qrs_y <= WIN_SAMPLES;
                elsif d_valid = '1' then
                    if cnt_qrs_y > 0 then cnt_qrs_y <= cnt_qrs_y - 1; 
                    else qrs_y_str <= '0'; end if;
                end if;

                -- Eje Z (Típicamente 0 en tu TB actual)
                if qrs_z = '1' then 
                    qrs_z_str <= '1'; cnt_qrs_z <= WIN_SAMPLES;
                elsif d_valid = '1' then
                    if cnt_qrs_z > 0 then cnt_qrs_z <= cnt_qrs_z - 1; 
                    else qrs_z_str <= '0'; end if;
                end if;

                -- Repetir para Ondas T
                if t_x = '1' then 
                    t_x_str <= '1'; cnt_t_x <= WIN_SAMPLES;
                elsif d_valid = '1' then
                    if cnt_t_x > 0 then cnt_t_x <= cnt_t_x - 1; 
                    else t_x_str <= '0'; end if;
                end if;

                if t_y = '1' then 
                    t_y_str <= '1'; cnt_t_y <= WIN_SAMPLES;
                elsif d_valid = '1' then
                    if cnt_t_y > 0 then cnt_t_y <= cnt_t_y - 1; 
                    else t_y_str <= '0'; end if;
                end if;

                if t_z = '1' then 
                    t_z_str <= '1'; cnt_t_z <= WIN_SAMPLES;
                elsif d_valid = '1' then
                    if cnt_t_z > 0 then cnt_t_z <= cnt_t_z - 1; 
                    else t_z_str <= '0'; end if;
                end if;
            end if;
        end if;
    end process;

    qrs_voted <= (qrs_x_str and qrs_y_str) or (qrs_x_str and qrs_z_str) or (qrs_y_str and qrs_z_str);
    t_voted   <= (t_x_str and t_y_str) or (t_x_str and t_z_str) or (t_y_str and t_z_str);

    -- 2. CÁLCULO DE INTERVALOS
    process(clk)
        variable rt_smp : integer;
        variable ms_tmp : integer;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                qrs_unif_i <= '0'; t_unif_i <= '0';
                cnt_rr <= 0; cnt_rt <= 0; rt_busy <= '0';
                rr_ms_i <= (others => '0');
                rt_ms_i <= (others => '0');
                qrs_voted_prev <= '0'; t_voted_prev <= '0';
            elsif d_valid = '1' then
                qrs_voted_prev <= qrs_voted;
                t_voted_prev   <= t_voted;
                
                cnt_rr <= cnt_rr + 1;
                if rt_busy = '1' then cnt_rt <= cnt_rt + 1; end if;

                qrs_unif_i <= '0'; t_unif_i <= '0';

                if qrs_voted = '1' and qrs_voted_prev = '0' then 
                    qrs_unif_i <= '1';
                    ms_tmp := (cnt_rr * 1000) / FS_HZ;
                    rr_ms_i <= to_signed(ms_tmp, 24);
                    cnt_rr <= 0;
                    cnt_rt <= 0;
                    rt_busy <= '1';
                end if;

                if t_voted = '1' and t_voted_prev = '0' and rt_busy = '1' then
                    t_unif_i <= '1';
                    rt_smp := cnt_rt - SAMPLES_T + SAMPLES_R;
                    if rt_smp < 0 then rt_ms_i <= (others => '0');
                    else
                        ms_tmp := (rt_smp * 1000) / FS_HZ;
                        rt_ms_i <= to_signed(ms_tmp, 24);
                    end if;
                    rt_busy <= '0';
                end if;
            end if;
        end if;
    end process;
end Behavioral;