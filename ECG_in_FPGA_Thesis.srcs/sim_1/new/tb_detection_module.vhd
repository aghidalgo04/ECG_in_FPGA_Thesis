library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_detection_module is
end tb_detection_module;

architecture Sim of tb_detection_module is

    -- Component Declaration
    component detection_module
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
    end component;

    -- Signals
    signal clk            : std_logic := '0';
    signal reset          : std_logic := '0';
    signal d_valid        : std_logic := '0';
    signal qrs_unif       : std_logic := '0';
    signal t_unif         : std_logic := '0';
    signal rr_ms          : signed(23 downto 0) := (others => '0');
    signal rt_ms          : signed(23 downto 0) := (others => '0');
    
    -- Outputs
    signal al_tachy, al_brady, al_arrh, al_asyst, al_death : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    -- Unit Under Test (UUT)
    UUT: detection_module 
    port map (
        clk => clk, reset => reset, d_valid => d_valid,
        qrs_unified => qrs_unif, t_unified => t_unif,
        rr_interval_ms => rr_ms, rt_interval_ms => rt_ms,
        alarm_tachycardia => al_tachy, alarm_bradycardia => al_brady,
        alarm_arrhythmia => al_arrh, alarm_asystole => al_asyst,
        alarm_sudden_death => al_death
    );

    -- Clock Generation
    clk_process : process begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    -- d_valid Generation (Simulating 1ms pulses for the Watchdog)
    dv_process : process begin
        d_valid <= '0'; wait for 99 * CLK_PERIOD;
        d_valid <= '1'; wait for CLK_PERIOD;
    end process;

    -- Stimulus Process
    stim_proc: process
        -- Helper procedure to simulate a heartbeat
        procedure send_heartbeat(rr : integer; rt : integer) is
        begin
            rr_ms <= to_signed(rr, 24);
            rt_ms <= to_signed(rt, 24);
            wait until d_valid = '1';
            qrs_unif <= '1';
            wait for CLK_PERIOD;
            qrs_unif <= '0';
            
            -- Wait for the RT period to fire the T-wave
            for i in 1 to rt loop
                wait until d_valid = '1';
            end loop;
            
            t_unif <= '1';
            wait for CLK_PERIOD;
            t_unif <= '0';
            
            -- Wait for the rest of the RR interval
            for i in 1 to (rr - rt - 2) loop
                wait until d_valid = '1';
            end loop;
        end procedure;

    begin
        -- Initial Reset
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait for 100 ns;

        -- CASE 1: Healthy Patient (800ms RR, 300ms RT)
        -- Result: All alarms should be '0'
        report "Testing Healthy Patient...";
        for i in 1 to 3 loop
            send_heartbeat(800, 300);
        end loop;

        -- CASE 2: Tachycardia (400ms RR)
        -- Result: alarm_tachycardia = '1'
        report "Testing Tachycardia...";
        for i in 1 to 3 loop
            send_heartbeat(400, 150);
        end loop;

        -- CASE 3: Bradycardia (1200ms RR)
        -- Result: alarm_bradycardia = '1'
        report "Testing Bradycardia...";
        for i in 1 to 2 loop
            send_heartbeat(1200, 350);
        end loop;

        -- CASE 4: Arrhythmia (RR changes from 800 to 400 suddenly)
        -- Result: alarm_arrhythmia = '1' (Variation > 25%)
        report "Testing Arrhythmia...";
        send_heartbeat(800, 300);
        send_heartbeat(400, 150);

        -- CASE 5: Sudden Death Risk (Long QT: RT > 450ms)
        -- Result: alarm_sudden_death = '1'
        report "Testing Sudden Death (Long QT)...";
        send_heartbeat(1000, 500);

        -- CASE 6: Priority Check (Asystole stops everything)
        -- Result: alarm_asystole = '1', all others = '0'
        report "Testing Asystole Priority...";
        send_heartbeat(500, 200); -- Trigger Tachycardia first
        wait for 4000 ms; -- Wait 4 seconds (exceeds 3000ms threshold)

        report "Simulation Finished";
        wait;
    end process;

end Sim;