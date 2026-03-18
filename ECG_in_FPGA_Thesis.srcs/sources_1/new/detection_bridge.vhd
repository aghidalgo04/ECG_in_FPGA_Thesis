library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity detection_bridge is
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
    constant WIN_COINCIDENCE : integer := 30;
    
    -- Señales estiradas
    signal qx_s, qy_s, qz_s : std_logic := '0';
    signal tx_s, ty_s, tz_s : std_logic := '0';
    
    signal cnt_qx, cnt_qy, cnt_qz : integer := 0;
    signal cnt_tx, cnt_ty, cnt_tz : integer := 0;

    signal qrs_voted, t_voted : std_logic := '0';
    
    -- NUEVO: Señales para detectar el flanco de subida del voto (Edge Detector)
    signal qrs_voted_prev : std_logic := '0';
    signal t_voted_prev   : std_logic := '0';

    signal cnt_rr, cnt_rt     : integer := 0;
    signal rt_busy            : std_logic := '0';
    
    -- SEÑALES ESPEJO (Para poder leerlas internamente)
    signal qrs_unif_int : std_logic := '0';
    signal t_unif_int   : std_logic := '0';

begin
    -- Asignación de señales espejo a puertos de salida
    qrs_unified <= qrs_unif_int;
    t_unified   <= t_unif_int;

    -- 1. LÓGICA DE ESTIRAMIENTO
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                qx_s <= '0'; qy_s <= '0'; qz_s <= '0';
                tx_s <= '0'; ty_s <= '0'; tz_s <= '0';
            elsif d_valid = '1' then
                -- QRS
                if qrs_x = '1' then qx_s <= '1'; cnt_qx <= WIN_COINCIDENCE;
                elsif cnt_qx > 0 then cnt_qx <= cnt_qx - 1;
                else qx_s <= '0'; end if;
                
                if qrs_y = '1' then qy_s <= '1'; cnt_qy <= WIN_COINCIDENCE;
                elsif cnt_qy > 0 then cnt_qy <= cnt_qy - 1;
                else qy_s <= '0'; end if;
                
                if qrs_z = '1' then qz_s <= '1'; cnt_qz <= WIN_COINCIDENCE;
                elsif cnt_qz > 0 then cnt_qz <= cnt_qz - 1;
                else qz_s <= '0'; end if;

                -- T
                if t_x = '1' then tx_s <= '1'; cnt_tx <= WIN_COINCIDENCE;
                elsif cnt_tx > 0 then cnt_tx <= cnt_tx - 1;
                else tx_s <= '0'; end if;

                if t_y = '1' then ty_s <= '1'; cnt_ty <= WIN_COINCIDENCE;
                elsif cnt_ty > 0 then cnt_ty <= cnt_ty - 1;
                else ty_s <= '0'; end if;

                if t_z = '1' then tz_s <= '1'; cnt_tz <= WIN_COINCIDENCE;
                elsif cnt_tz > 0 then cnt_tz <= cnt_tz - 1;
                else tz_s <= '0'; end if;
            end if;
        end if;
    end process;

    -- 2. VOTACIÓN 2 DE 3
    qrs_voted <= (qx_s and qy_s) or (qx_s and qz_s) or (qy_s and qz_s);
    t_voted   <= (tx_s and ty_s) or (tx_s and tz_s) or (ty_s and tz_s);

    -- 3. CÁLCULO DE INTERVALOS Y DETECCIÓN DE FLANCO
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                qrs_unif_int <= '0'; t_unif_int <= '0';
                cnt_rr <= 0; cnt_rt <= 0; rt_busy <= '0';
                rr_interval_ms <= (others => '0');
                rt_interval_ms <= (others => '0');
                qrs_voted_prev <= '0';
                t_voted_prev <= '0';
            else
                -- Por defecto apagamos los pulsos de salida para que duren 1 solo ciclo de reloj
                qrs_unif_int <= '0'; 
                t_unif_int <= '0';
                
                if d_valid = '1' then
                    -- Actualizamos el estado previo para el detector de flancos
                    qrs_voted_prev <= qrs_voted;
                    t_voted_prev   <= t_voted;

                    cnt_rr <= cnt_rr + 1;
                    
                    -- Detectamos el FLANCO DE SUBIDA de la votación (solo la primera vez que se hace '1')
                    if qrs_voted = '1' and qrs_voted_prev = '0' then 
                        qrs_unif_int <= '1';
                        rr_interval_ms <= to_signed(cnt_rr, 24);
                        cnt_rr <= 0;
                        cnt_rt <= 0;
                        rt_busy <= '1';
                    end if;
                    
                    if rt_busy = '1' then
                        cnt_rt <= cnt_rt + 1;
                        if t_voted = '1' and t_voted_prev = '0' then
                            t_unif_int <= '1';
                            rt_interval_ms <= to_signed(cnt_rt, 24);
                            rt_busy <= '0';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
end Behavioral;