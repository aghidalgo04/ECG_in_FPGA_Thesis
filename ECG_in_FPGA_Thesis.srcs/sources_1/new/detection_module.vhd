library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity detection_module is
    Port ( 
        clk                  : in  STD_LOGIC;
        reset                : in  STD_LOGIC;
        d_valid              : in  STD_LOGIC; 
        
        qrs_unified          : in  STD_LOGIC;
        t_unified            : in  STD_LOGIC;
        rr_interval_ms       : in  SIGNED(23 downto 0);
        rt_interval_ms       : in  SIGNED(23 downto 0);
        
        alarm_tachycardia    : out STD_LOGIC;
        alarm_bradycardia    : out STD_LOGIC;
        alarm_arrhythmia     : out STD_LOGIC;
        alarm_asystole       : out STD_LOGIC;
        alarm_sudden_death   : out STD_LOGIC
    );
end detection_module;

architecture Behavioral of detection_module is

    -- Internal signals to allow reading for priority logic
    signal asystole_int     : std_logic := '0';
    signal sudden_death_int : std_logic := '0';
    signal tachy_int        : std_logic := '0';
    signal brady_int        : std_logic := '0';
    signal arrhythmia_int   : std_logic := '0';

    signal rr_prev_ms       : signed(23 downto 0) := (others => '0');
    signal watchdog_cnt     : integer := 0;
    
    constant THRESHOLD_TACHYCARDIA : signed(23 downto 0) := to_signed(600, 24);  
    constant THRESHOLD_BRADYCARDIA : signed(23 downto 0) := to_signed(1000, 24); 
    constant THRESHOLD_LONG_QT     : signed(23 downto 0) := to_signed(450, 24);  
    constant THRESHOLD_ASYSTOLE    : integer := 3000;                            

begin

    -- ==========================================================
    -- ALARM PRIORITIZATION (The "Muting" Logic)
    -- ==========================================================
    -- 1. Asystole is absolute. No other alarms if heart stops.
    alarm_asystole     <= asystole_int;
    
    -- 2. Sudden Death alarm only if heart is still beating.
    alarm_sudden_death <= sudden_death_int and not asystole_int;
    
    -- 3. Rhythm alarms only if there is no Asystole and no Sudden Death risk.
    alarm_tachycardia  <= tachy_int      and not asystole_int and not sudden_death_int;
    alarm_bradycardia  <= brady_int      and not asystole_int and not sudden_death_int;
    alarm_arrhythmia   <= arrhythmia_int and not asystole_int and not sudden_death_int;

    process(clk)
        variable diff_rr          : signed(23 downto 0);
        variable limit_arrhythmia : signed(23 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                asystole_int     <= '0';
                sudden_death_int <= '0';
                tachy_int        <= '0';
                brady_int        <= '0';
                arrhythmia_int   <= '0';
                rr_prev_ms       <= (others => '0');
                watchdog_cnt     <= 0;
            else
                
                -- 1. ASYSTOLE WATCHDOG
                if d_valid = '1' then
                    if qrs_unified = '1' then
                        watchdog_cnt <= 0;
                        asystole_int <= '0';
                    else
                        if watchdog_cnt > THRESHOLD_ASYSTOLE then
                            asystole_int <= '1';
                        else
                            watchdog_cnt <= watchdog_cnt + 1;
                        end if;
                    end if;
                end if;

                -- 2. RHYTHM EVALUATION (QRS Triggered)
                if qrs_unified = '1' then
                    -- Tachycardia check
                    if rr_interval_ms < THRESHOLD_TACHYCARDIA and rr_interval_ms > 200 then
                        tachy_int <= '1';
                    else
                        tachy_int <= '0';
                    end if;

                    -- Bradycardia check
                    if rr_interval_ms > THRESHOLD_BRADYCARDIA then
                        brady_int <= '1';
                    else
                        brady_int <= '0';
                    end if;

                    -- Arrhythmia check
                    if rr_interval_ms > rr_prev_ms then
                        diff_rr := rr_interval_ms - rr_prev_ms;
                    else
                        diff_rr := rr_prev_ms - rr_interval_ms;
                    end if;
                    
                    limit_arrhythmia := shift_right(rr_prev_ms, 2); 
                    if diff_rr > limit_arrhythmia and rr_prev_ms > 0 then
                        arrhythmia_int <= '1';
                    else
                        arrhythmia_int <= '0';
                    end if;
                    
                    rr_prev_ms <= rr_interval_ms;
                end if;

                -- 3. SUDDEN DEATH EVALUATION (T Triggered)
                if t_unified = '1' then
                    if (rt_interval_ms > THRESHOLD_LONG_QT) then
                        sudden_death_int <= '1';
                    elsif (rr_interval_ms >= THRESHOLD_TACHYCARDIA) then
                        if (rt_interval_ms > shift_right(rr_interval_ms, 1)) then
                            sudden_death_int <= '1';
                        else
                            sudden_death_int <= '0';
                        end if;
                    else
                        sudden_death_int <= '0';
                    end if;
                end if;

            end if;
        end if;
    end process;
end Behavioral;