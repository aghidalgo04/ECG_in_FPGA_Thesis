library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity detection_bridge is
    generic (
        -- Frecuencia de muestreo (360 para MIT-BIH, 1000 para tiempo real estandar)
        FS_HZ : integer := 1000
    );
    Port (
        clk             : in  STD_LOGIC;
        reset           : in  STD_LOGIC;
        d_valid         : in  STD_LOGIC; 
        
        qrs_x, qrs_y, qrs_z : in STD_LOGIC;
        t_x, t_y, t_z       : in STD_LOGIC;
        
        qrs_unified     : out STD_LOGIC;
        t_unified       : out STD_LOGIC;
        
        rr_interval_ms  : out SIGNED(23 downto 0);
        rt_interval_ms  : out SIGNED(23 downto 0)
    );
end detection_bridge;

architecture Behavioral of detection_bridge is
    -- Ventana de coincidencia (30 muestras aprox)
    constant WIN_COINCIDENCE : integer := 30;
    
    -- Compensacion de retardos de los filtros Wavelet (en muestras)
    constant DELAY_R_WAVE : integer := 60;  
    constant DELAY_T_WAVE : integer := 230; 
    
    -- Señales de stretching (ensanchamiento)
    signal qrs_x_str, qrs_y_str, qrs_z_str : std_logic := '0';
    signal t_x_str, t_y_str, t_z_str       : std_logic := '0';
    
    -- Contadores para el ensanchamiento
    signal cnt_qrs_x, cnt_qrs_y, cnt_qrs_z : integer := 0;
    signal cnt_t_x, cnt_t_y, cnt_t_z       : integer := 0;

    -- Resultados de votacion
    signal qrs_voted, t_voted : std_logic := '0';
    signal qrs_voted_prev, t_voted_prev : std_logic := '0';

    -- Contadores de intervalos (en muestras)
    signal cnt_rr, cnt_rt     : integer := 0;
    signal rt_busy            : std_logic := '0';
    
    signal qrs_unif_int, t_unif_int : std_logic := '0';

begin
    qrs_unified <= qrs_unif_int;
    t_unified   <= t_unif_int;

    -- 1. LOGICA DE CAPTURA Y ENSANCHAMIENTO (STRETCHING)
    -- Ahora corregida para capturar el pulso aunque no coincida con d_valid
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                qrs_x_str <= '0'; qrs_y_str <= '0'; qrs_z_str <= '0';
                t_x_str <= '0'; t_y_str <= '0'; t_z_str <= '0';
                cnt_qrs_x <= 0; cnt_qrs_y <= 0; cnt_qrs_z <= 0;
                cnt_t_x <= 0; cnt_t_y <= 0; cnt_t_z <= 0;
            else
                -- Eje X (QRS y T)
                if qrs_x = '1' then qrs_x_str <= '1'; cnt_qrs_x <= WIN_COINCIDENCE;
                elsif d_valid = '1' then
                    if cnt_qrs_x > 0 then cnt_qrs_x <= cnt_qrs_x - 1; else qrs_x_str <= '0'; end if;
                end if;
                if t_x = '1' then t_x_str <= '1'; cnt_t_x <= WIN_COINCIDENCE;
                elsif d_valid = '1' then
                    if cnt_t_x > 0 then cnt_t_x <= cnt_t_x - 1; else t_x_str <= '0'; end if;
                end if;

                -- Eje Y (QRS y T)
                if qrs_y = '1' then qrs_y_str <= '1'; cnt_qrs_y <= WIN_COINCIDENCE;
                elsif d_valid = '1' then
                    if cnt_qrs_y > 0 then cnt_qrs_y <= cnt_qrs_y - 1; else qrs_y_str <= '0'; end if;
                end if;
                if t_y = '1' then t_y_str <= '1'; cnt_t_y <= WIN_COINCIDENCE;
                elsif d_valid = '1' then
                    if cnt_t_y > 0 then cnt_t_y <= cnt_t_y - 1; else t_y_str <= '0'; end if;
                end if;

                -- Eje Z (QRS y T)
                if qrs_z = '1' then qrs_z_str <= '1'; cnt_qrs_z <= WIN_COINCIDENCE;
                elsif d_valid = '1' then
                    if cnt_qrs_z > 0 then cnt_qrs_z <= cnt_qrs_z - 1; else qrs_z_str <= '0'; end if;
                end if;
                if t_z = '1' then t_z_str <= '1'; cnt_t_z <= WIN_COINCIDENCE;
                elsif d_valid = '1' then
                    if cnt_t_z > 0 then cnt_t_z <= cnt_t_z - 1; else t_z_str <= '0'; end if;
                end if;
            end if;
        end if;
    end process;

    -- 2. VOTACION 2-DE-3
    qrs_voted <= (qrs_x_str and qrs_y_str) or (qrs_x_str and qrs_z_str) or (qrs_y_str and qrs_z_str);
    t_voted   <= (t_x_str and t_y_str) or (t_x_str and t_z_str) or (t_y_str and t_z_str);

    -- 3. CALCULO DE INTERVALOS CON CONVERSION A MS
    process(clk)
        variable rt_samples : integer;
        variable ms_calc    : integer;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                qrs_unif_int <= '0'; t_unif_int <= '0';
                cnt_rr <= 0; cnt_rt <= 0; rt_busy <= '0';
                rr_interval_ms <= (others => '0');
                rt_interval_ms <= (others => '0');
            else
                qrs_unif_int <= '0'; 
                t_unif_int   <= '0';
                
                if d_valid = '1' then
                    qrs_voted_prev <= qrs_voted;
                    t_voted_prev   <= t_voted;

                    cnt_rr <= cnt_rr + 1;
                    if rt_busy = '1' then cnt_rt <= cnt_rt + 1; end if;

                    -- Deteccion de QRS Unificado
                    if qrs_voted = '1' and qrs_voted_prev = '0' then 
                        qrs_unif_int <= '1';
                        
                        -- Formula de conversion: (muestras * 1000) / Frecuencia
                        -- Si FS_HZ = 1000, ms = muestras.
                        -- Si FS_HZ = 360, ms = muestras * 2.77
                        ms_calc := (cnt_rr * 1000) / FS_HZ;
                        rr_interval_ms <= to_signed(ms_calc, 24);
                        
                        cnt_rr <= 0;
                        cnt_rt <= 0;
                        rt_busy <= '1';
                    end if;

                    -- Deteccion de Onda T Unificada
                    if t_voted = '1' and t_voted_prev = '0' and rt_busy = '1' then
                        t_unif_int <= '1';
                        
                        -- Compensacion de retardo de grupo (Wavelet Scale 8 vs Scale 3)
                        rt_samples := cnt_rt - DELAY_T_WAVE + DELAY_R_WAVE;
                        
                        if rt_samples < 0 then
                            rt_interval_ms <= (others => '0');
                        else
                            ms_calc := (rt_samples * 1000) / FS_HZ;
                            rt_interval_ms <= to_signed(ms_calc, 24);
                        end if;
                        
                        rt_busy <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;
end Behavioral;