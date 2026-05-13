library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity detection_alarm is
    Port ( 
        clk                  : in  STD_LOGIC;
        reset                : in  STD_LOGIC;
        d_valid              : in  STD_LOGIC;
        qrs_unified          : in  STD_LOGIC;
        t_unified            : in  STD_LOGIC;
        rr_interval_ms       : in  SIGNED(23 downto 0);
        rt_interval_ms       : in  SIGNED(23 downto 0);
        
        -- Alertas de salida
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
    constant THRESHOLD_ASYSTOLE   : integer := 3000; -- 3 segundos
    constant THRESHOLD_LONG_QT    : integer := 500; 

    -- Señales de memoria
    signal last_rr_ms      : SIGNED(23 downto 0) := (others => '0');
    signal asystole_cnt    : integer := 0;
    
    -- Los registros de persistencia se mantienen como señales para poder verlos en simulación,
    -- pero usaremos variables para el cálculo inmediato.
    signal tachy_persist_reg : integer := 0;
    signal brady_persist_reg : integer := 0;
    signal arrh_persist_reg  : integer := 0;
    signal death_persist_reg : integer := 0;

begin

    process(clk)
        -- Variables para actualización instantánea (Zero-latency)
        variable v_tachy_persist : integer := 0;
        variable v_brady_persist : integer := 0;
        variable v_arrh_persist  : integer := 0;
        variable v_death_persist : integer := 0;
        variable diff_rr         : SIGNED(23 downto 0);
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
                
                tachy_persist_reg <= 0;
                brady_persist_reg <= 0;
                arrh_persist_reg  <= 0;
                death_persist_reg <= 0;
                
                asystole_cnt <= 0;
                last_rr_ms   <= (others => '0');
                
            elsif d_valid = '1' then
                
                -- 1. MONITOR DE ASISTOLIA (Watchdog constante)
                if asystole_cnt >= THRESHOLD_ASYSTOLE then
                    alarm_asystole <= '1';
                else
                    asystole_cnt <= asystole_cnt + 1;
                    alarm_asystole <= '0';
                end if;

                -- 2. LÓGICA DE RITMO (Se ejecuta en cada pulso QRS detectado)
                if qrs_unified = '1' then
                    asystole_cnt <= 0; -- Reset watchdog por detección de vida

                    -- --- PERSISTENCIA DE TAQUICARDIA ---
                    if rr_interval_ms < THRESHOLD_TACHY and rr_interval_ms > 0 then
                        if v_tachy_persist < 2 then 
                            v_tachy_persist := v_tachy_persist + 1; 
                        end if;
                    else
                        v_tachy_persist := 0;
                    end if;

                    -- --- PERSISTENCIA DE BRADICARDIA ---
                    if rr_interval_ms > THRESHOLD_BRADY then
                        if v_brady_persist < 2 then 
                            v_brady_persist := v_brady_persist + 1; 
                        end if;
                    else
                        v_brady_persist := 0;
                    end if;

                    -- --- PERSISTENCIA DE ARRITMIA (Variación > 25%) ---
                    diff_rr := abs(rr_interval_ms - last_rr_ms);
                    if diff_rr > shift_right(last_rr_ms, 2) and last_rr_ms > 0 then
                        if v_arrh_persist < 2 then 
                            v_arrh_persist := v_arrh_persist + 1; 
                        end if;
                    else
                        v_arrh_persist := 0;
                    end if;

                    -- ACTUALIZACIÓN DE SALIDAS (Ahora usan el valor de la variable recién calculado)
                    if v_tachy_persist >= 2 then alarm_tachycardia <= '1'; else alarm_tachycardia <= '0'; end if;
                    if v_brady_persist >= 2 then alarm_bradycardia <= '1'; else alarm_bradycardia <= '0'; end if;
                    if v_arrh_persist  >= 2 then alarm_arrhythmia  <= '1'; else alarm_arrhythmia  <= '0'; end if;

                    -- Guardamos para el siguiente ciclo y para visualización
                    last_rr_ms <= rr_interval_ms;
                    tachy_persist_reg <= v_tachy_persist;
                    brady_persist_reg <= v_brady_persist;
                    arrh_persist_reg  <= v_arrh_persist;
                end if;

                -- 3. LÓGICA DE MUERTE SÚBITA (Onda T / Intervalo RT)
                if t_unified = '1' then
                    if rt_interval_ms > THRESHOLD_LONG_QT then
                        if v_death_persist < 2 then 
                            v_death_persist := v_death_persist + 1; 
                        end if;
                    else
                        v_death_persist := 0;
                    end if;
                    
                    -- Actualización inmediata de la alarma de muerte súbita
                    if v_death_persist >= 2 then 
                        alarm_sudden_death <= '1'; 
                    else 
                        alarm_sudden_death <= '0'; 
                    end if;
                    
                    death_persist_reg <= v_death_persist;
                end if;

            end if;
        end if;
    end process;

end Behavioral;