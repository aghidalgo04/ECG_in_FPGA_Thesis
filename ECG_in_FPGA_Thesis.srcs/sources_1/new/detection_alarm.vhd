library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity detection_alarm is
    generic (
        FS_HZ : integer := 1000 
    );
    Port ( 
        clk                  : in  STD_LOGIC;
        reset                : in  STD_LOGIC;
        
        -- Entradas (bridge)
        d_valid              : in  STD_LOGIC;
        qrs_unified          : in  STD_LOGIC;
        t_unified            : in  STD_LOGIC;
        rr_interval_ms       : in  SIGNED(23 downto 0);
        rt_interval_ms       : in  SIGNED(23 downto 0);
        
        -- Salidas (Alarmas UART)
        alarm_tachycardia    : out STD_LOGIC := '0';
        alarm_bradycardia    : out STD_LOGIC := '0';
        alarm_arrhythmia     : out STD_LOGIC := '0';
        alarm_asystole       : out STD_LOGIC := '0';
        alarm_sudden_death   : out STD_LOGIC := '0'
    );
end detection_alarm;

architecture Behavioral of detection_alarm is

    -- Umbrales clínicos
    constant THRESHOLD_TACHY      : integer := 600;
    constant THRESHOLD_BRADY      : integer := 1200;

    -- 3 segundos para asistolia 
    constant THRESHOLD_ASYSTOLE   : integer := 3 * FS_HZ;

    signal last_rr_ms      : SIGNED(23 downto 0) := (others => '0');
    signal asystole_cnt    : integer := 0;
    
    -- Registros de persistencia (Para activar una alarma cuando varios latidos confirman la patología)
    signal tachy_persist_reg : integer := 0;
    signal brady_persist_reg : integer := 0;
    signal arrh_persist_reg  : integer := 0;
    signal death_persist_reg : integer := 0;

begin

    process(clk)
        -- Variables actualizar valores
        variable v_tachy_persist : integer := 0;
        variable v_brady_persist : integer := 0;
        variable v_arrh_persist  : integer := 0;
        variable v_death_persist : integer := 0;
        variable diff_rr         : SIGNED(23 downto 0);
        variable v_r_since_t     : integer := 0; 
    begin
        if rising_edge(clk) then
            if reset = '1' then
                alarm_tachycardia  <= '0';
                alarm_bradycardia  <= '0';
                alarm_arrhythmia   <= '0';
                alarm_asystole     <= '0';
                alarm_sudden_death <= '0';
                
                v_tachy_persist := 0;
                v_brady_persist := 0;
                v_arrh_persist  := 0;
                v_death_persist := 0;
                v_r_since_t     := 0;
                
                tachy_persist_reg <= 0;
                brady_persist_reg <= 0;
                arrh_persist_reg  <= 0;
                death_persist_reg <= 0;
                
                asystole_cnt <= 0;
                last_rr_ms   <= (others => '0');
                
            elsif d_valid = '1' then
                
                -- Activador Asistolia
                if asystole_cnt >= THRESHOLD_ASYSTOLE then
                    alarm_asystole <= '1';
                else
                    asystole_cnt <= asystole_cnt + 1;
                    alarm_asystole <= '0';
                end if;

                if qrs_unified = '1' then
                    asystole_cnt <= 0;
                    
                    -- Registro de onda R
                    v_r_since_t := v_r_since_t + 1;

                    -- Persistencia de Taquicardia
                    if rr_interval_ms < THRESHOLD_TACHY and rr_interval_ms > 0 then
                        if v_tachy_persist < 2 then 
                            v_tachy_persist := v_tachy_persist + 1; 
                        end if;
                    else
                        v_tachy_persist := 0;
                    end if;

                    -- Persistencia de Bradicardia
                    if rr_interval_ms > THRESHOLD_BRADY then
                        if v_brady_persist < 2 then 
                            v_brady_persist := v_brady_persist + 1; 
                        end if;
                    else
                        v_brady_persist := 0;
                    end if;

                    -- Persistencia de arritmia
                    diff_rr := abs(rr_interval_ms - last_rr_ms);
                    if diff_rr > shift_right(last_rr_ms, 2) and last_rr_ms > 0 then
                        if v_arrh_persist < 2 then 
                            v_arrh_persist := v_arrh_persist + 1; 
                        end if;
                    else
                        v_arrh_persist := 0;
                    end if;

                    -- Activacion de alarmas
                    if v_tachy_persist >= 2 then alarm_tachycardia <= '1'; else alarm_tachycardia <= '0'; end if;
                    if v_brady_persist >= 2 then alarm_bradycardia <= '1'; else alarm_bradycardia <= '0'; end if;
                    if v_arrh_persist  >= 2 then alarm_arrhythmia  <= '1'; else alarm_arrhythmia  <= '0'; end if;

                    last_rr_ms <= rr_interval_ms;
                    tachy_persist_reg <= v_tachy_persist;
                    brady_persist_reg <= v_brady_persist;
                    arrh_persist_reg  <= v_arrh_persist;
                end if;

                -- Detección de muerte súbita
                if t_unified = '1' then
                    
                    -- Validacion de únicamente una R antes de la T para asegurarnos de no hacer un falso positivo por fallo de detección
                    if v_r_since_t = 1 then
                        
                        -- Regla de la mitad clínica. Adaptación del tiempo máximo antes de hacer saltar la alarma según ritmo cardíaco.
                        if rt_interval_ms > shift_right(last_rr_ms, 1) - shift_right(last_rr_ms, 4) then
                            if v_death_persist < 2 then 
                                v_death_persist := v_death_persist + 1; 
                            end if;
                        else
                            v_death_persist := 0;
                        end if;
                        
                    else
                        v_death_persist := 0;
                    end if;
                    
                    -- Activación de la alarma
                    if v_death_persist >= 2 then 
                        alarm_sudden_death <= '1'; 
                    else 
                        alarm_sudden_death <= '0'; 
                    end if;
                    
                    death_persist_reg <= v_death_persist;
                    
                    v_r_since_t := 0; 
                end if;
            end if;
        end if;
    end process;

end Behavioral;