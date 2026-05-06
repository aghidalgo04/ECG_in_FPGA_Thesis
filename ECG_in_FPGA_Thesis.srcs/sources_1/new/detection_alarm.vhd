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
    constant THRESHOLD_ASYSTOLE   : integer := 3000;
    constant THRESHOLD_LONG_QT    : integer := 500; -- Aumentado a 500 para evitar falsos positivos por fase

    -- Señales de memoria
    signal last_rr_ms      : SIGNED(23 downto 0) := (others => '0');
    signal asystole_cnt    : integer := 0;
    
    -- Contadores de persistencia (Integers normales)
    -- Necesitamos llegar a 2 para activar la alarma
    signal tachy_persist : integer := 0;
    signal brady_persist : integer := 0;
    signal arrh_persist  : integer := 0;
    signal death_persist : integer := 0;

begin

    process(clk)
        variable diff_rr : SIGNED(23 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                alarm_tachycardia  <= '0';
                alarm_bradycardia  <= '0';
                alarm_arrhythmia   <= '0';
                alarm_asystole     <= '0';
                alarm_sudden_death <= '0';
                
                tachy_persist <= 0;
                brady_persist <= 0;
                arrh_persist  <= 0;
                death_persist <= 0;
                
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

                -- 2. LÓGICA DE RITMO (Se ejecuta en cada pulso QRS)
                if qrs_unified = '1' then
                    asystole_cnt <= 0; -- Reset watchdog porque hay vida

                    -- --- PERSISTENCIA DE TAQUICARDIA ---
                    if rr_interval_ms < THRESHOLD_TACHY and rr_interval_ms > 0 then
                        if tachy_persist < 2 then tachy_persist <= tachy_persist + 1; end if;
                    else
                        tachy_persist <= 0;
                    end if;

                    -- --- PERSISTENCIA DE BRADICARDIA ---
                    if rr_interval_ms > THRESHOLD_BRADY then
                        if brady_persist < 2 then brady_persist <= brady_persist + 1; end if;
                    else
                        brady_persist <= 0;
                    end if;

                    -- --- PERSISTENCIA DE ARRITMIA (Variación > 25%) ---
                    diff_rr := abs(rr_interval_ms - last_rr_ms);
                    if diff_rr > shift_right(last_rr_ms, 2) and last_rr_ms > 0 then
                        if arrh_persist < 2 then arrh_persist <= arrh_persist + 1; end if;
                    else
                        arrh_persist <= 0;
                    end if;

                    -- ACTUALIZACIÓN DE SALIDAS RÍTMICAS
                    if tachy_persist >= 2 then alarm_tachycardia <= '1'; else alarm_tachycardia <= '0'; end if;
                    if brady_persist >= 2 then alarm_bradycardia <= '1'; else alarm_bradycardia <= '0'; end if;
                    if arrh_persist  >= 2 then alarm_arrhythmia  <= '1'; else alarm_arrhythmia  <= '0'; end if;

                    last_rr_ms <= rr_interval_ms;
                end if;

                -- 3. LÓGICA DE MUERTE SÚBITA (Onda T / Long QT)
                if t_unified = '1' then
                    if rt_interval_ms > THRESHOLD_LONG_QT then
                        if death_persist < 2 then death_persist <= death_persist + 1; end if;
                    else
                        death_persist <= 0;
                    end if;
                    
                    -- ACTUALIZACIÓN DE SALIDA
                    if death_persist >= 2 then alarm_sudden_death <= '1'; else alarm_sudden_death <= '0'; end if;
                end if;

            end if;
        end if;
    end process;

end Behavioral;