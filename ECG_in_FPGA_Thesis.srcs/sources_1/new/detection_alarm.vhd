library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity detection_alarm is
    generic (
        -- Frecuencia de muestreo real de la señal (ej. 360 Hz para MIT-BIH)
        FS_HZ : integer := 360 
    );
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

    -- Umbrales clínicos fijos
    constant THRESHOLD_TACHY      : integer := 600;
    constant THRESHOLD_BRADY      : integer := 1200;
    
    -- El umbral de Long QT fijo se elimina. Ahora usamos la dinámica (50% del RR)

    -- 3 segundos físicos para asistolia adaptados a la frecuencia
    constant THRESHOLD_ASYSTOLE   : integer := 3 * FS_HZ;

    -- Señales de memoria
    signal last_rr_ms      : SIGNED(23 downto 0) := (others => '0');
    signal asystole_cnt    : integer := 0;
    
    -- Registros de persistencia para visualización en el Waveform
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
        
        -- Variable para asegurar secuencia clínica R -> T
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
                
                -- =========================================================
                -- 1. MONITOR DE ASISTOLIA (Watchdog adaptado a FS_HZ)
                -- =========================================================
                if asystole_cnt >= THRESHOLD_ASYSTOLE then
                    alarm_asystole <= '1';
                else
                    asystole_cnt <= asystole_cnt + 1;
                    alarm_asystole <= '0';
                end if;

                -- =========================================================
                -- 2. LÓGICA DE RITMO
                -- =========================================================
                if qrs_unified = '1' then
                    asystole_cnt <= 0; -- Hay un latido -> Reseteamos el contador de muerte
                    
                    -- Registramos que ha ocurrido una onda R para la lógica de la onda T
                    v_r_since_t := v_r_since_t + 1;

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

                    -- ACTUALIZACIÓN DE SALIDAS RÍTMICAS (Zero-latency)
                    if v_tachy_persist >= 2 then alarm_tachycardia <= '1'; else alarm_tachycardia <= '0'; end if;
                    if v_brady_persist >= 2 then alarm_bradycardia <= '1'; else alarm_bradycardia <= '0'; end if;
                    
                    -- ARRITMIA: Disparo inmediato al primer latido anormal (Persistencia >= 1)
                    if v_arrh_persist  >= 2 then alarm_arrhythmia  <= '1'; else alarm_arrhythmia  <= '0'; end if;

                    -- Guardamos para el siguiente ciclo
                    last_rr_ms <= rr_interval_ms;
                    tachy_persist_reg <= v_tachy_persist;
                    brady_persist_reg <= v_brady_persist;
                    arrh_persist_reg  <= v_arrh_persist;
                end if;

                -- =========================================================
                -- 3. LÓGICA DE MUERTE SÚBITA DINÁMICA (QT Corregido)
                -- =========================================================
                if t_unified = '1' then
                    
                    -- VALIDACIÓN DE SECUENCIA: Exactamente 1 R antes de esta T
                    if v_r_since_t = 1 then
                        
                        -- LA REGLA DE LA MITAD CLÍNICA PURA (Adaptativa al ritmo actual)
                        if rt_interval_ms > shift_right(last_rr_ms, 1) then
                            if v_death_persist < 2 then 
                                v_death_persist := v_death_persist + 1; 
                            end if;
                        else
                            v_death_persist := 0;
                        end if;
                        
                    else
                        -- SECUENCIA INVÁLIDA (Missed T o False T): Se descarta
                        v_death_persist := 0;
                    end if;
                    
                    -- Actualización de la alarma
                    if v_death_persist >= 2 then 
                        alarm_sudden_death <= '1'; 
                    else 
                        alarm_sudden_death <= '0'; 
                    end if;
                    
                    death_persist_reg <= v_death_persist;
                    
                    -- Reiniciamos el contador de R ya que acabamos de consumir la pareja R-T
                    v_r_since_t := 0; 
                end if;

            end if;
        end if;
    end process;

end Behavioral;