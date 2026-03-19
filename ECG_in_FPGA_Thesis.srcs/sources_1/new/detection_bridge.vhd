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
    -- Coincidence window: 30ms to allow axes to synchronize
    constant WIN_COINCIDENCE : integer := 30;
    
    -- Filter delay compensations (in ms/samples) based on physiological return to baseline
    constant DELAY_R_WAVE : integer := 60;  -- ACTUALIZADO DE 20 A 60
    constant DELAY_T_WAVE : integer := 230; -- ACTUALIZADO DE 80 A 230
    
    -- Stretched signals
    signal qrs_x_str, qrs_y_str, qrs_z_str : std_logic := '0';
    signal t_x_str, t_y_str, t_z_str       : std_logic := '0';
    
    -- Counters for pulse stretching
    signal cnt_qrs_x, cnt_qrs_y, cnt_qrs_z : integer := 0;
    signal cnt_t_x, cnt_t_y, cnt_t_z       : integer := 0;

    -- Voting results
    signal qrs_voted, t_voted : std_logic := '0';
    
    -- Edge Detector signals (to capture only the rising edge of the vote)
    signal qrs_voted_prev : std_logic := '0';
    signal t_voted_prev   : std_logic := '0';

    -- Counters for clinical intervals
    signal cnt_rr, cnt_rt     : integer := 0;
    signal rt_busy            : std_logic := '0';
    
    -- Internal mirror signals (to be able to read them internally)
    signal qrs_unif_internal : std_logic := '0';
    signal t_unif_internal   : std_logic := '0';

begin
    -- Assign mirror signals to output ports
    qrs_unified <= qrs_unif_internal;
    t_unified   <= t_unif_internal;

    -- 1. PULSE STRETCHING LOGIC
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                qrs_x_str <= '0'; qrs_y_str <= '0'; qrs_z_str <= '0';
                t_x_str <= '0'; t_y_str <= '0'; t_z_str <= '0';
                cnt_qrs_x <= 0; cnt_qrs_y <= 0; cnt_qrs_z <= 0;
                cnt_t_x <= 0; cnt_t_y <= 0; cnt_t_z <= 0;
            elsif d_valid = '1' then
                -- QRS Stretching
                if qrs_x = '1' then qrs_x_str <= '1'; cnt_qrs_x <= WIN_COINCIDENCE;
                elsif cnt_qrs_x > 0 then cnt_qrs_x <= cnt_qrs_x - 1;
                else qrs_x_str <= '0'; end if;
                
                if qrs_y = '1' then qrs_y_str <= '1'; cnt_qrs_y <= WIN_COINCIDENCE;
                elsif cnt_qrs_y > 0 then cnt_qrs_y <= cnt_qrs_y - 1;
                else qrs_y_str <= '0'; end if;
                
                if qrs_z = '1' then qrs_z_str <= '1'; cnt_qrs_z <= WIN_COINCIDENCE;
                elsif cnt_qrs_z > 0 then cnt_qrs_z <= cnt_qrs_z - 1;
                else qrs_z_str <= '0'; end if;

                -- T-Wave Stretching
                if t_x = '1' then t_x_str <= '1'; cnt_t_x <= WIN_COINCIDENCE;
                elsif cnt_t_x > 0 then cnt_t_x <= cnt_t_x - 1;
                else t_x_str <= '0'; end if;

                if t_y = '1' then t_y_str <= '1'; cnt_t_y <= WIN_COINCIDENCE;
                elsif cnt_t_y > 0 then cnt_t_y <= cnt_t_y - 1;
                else t_y_str <= '0'; end if;

                if t_z = '1' then t_z_str <= '1'; cnt_t_z <= WIN_COINCIDENCE;
                elsif cnt_t_z > 0 then cnt_t_z <= cnt_t_z - 1;
                else t_z_str <= '0'; end if;
            end if;
        end if;
    end process;

    -- 2. 2-OUT-OF-3 VOTING
    qrs_voted <= (qrs_x_str and qrs_y_str) or (qrs_x_str and qrs_z_str) or (qrs_y_str and qrs_z_str);
    t_voted   <= (t_x_str and t_y_str) or (t_x_str and t_z_str) or (t_y_str and t_z_str);

    -- 3. INTERVAL CALCULATION AND EDGE DETECTION
    process(clk)
        variable rt_real : integer;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                qrs_unif_internal <= '0'; t_unif_internal <= '0';
                cnt_rr <= 0; cnt_rt <= 0; rt_busy <= '0';
                rr_interval_ms <= (others => '0');
                rt_interval_ms <= (others => '0');
                qrs_voted_prev <= '0';
                t_voted_prev <= '0';
            else
                -- By default, turn off output pulses so they last only 1 clock cycle
                qrs_unif_internal <= '0'; 
                t_unif_internal <= '0';
                
                if d_valid = '1' then
                    -- Update previous state for edge detection
                    qrs_voted_prev <= qrs_voted;
                    t_voted_prev   <= t_voted;

                    cnt_rr <= cnt_rr + 1;
                    
                    -- Detect RISING EDGE of the vote (only the first time it goes to '1')
                    if qrs_voted = '1' and qrs_voted_prev = '0' then 
                        qrs_unif_internal <= '1';
                        
                        -- RR interval doesn't need delay compensation because the delay 
                        -- is the same for both R waves (Delay_R - Delay_R = 0).
                        rr_interval_ms <= to_signed(cnt_rr, 24);
                        
                        cnt_rr <= 0;
                        cnt_rt <= 0;
                        rt_busy <= '1';
                    end if;
                    
                    if rt_busy = '1' then
                        cnt_rt <= cnt_rt + 1;
                        
                        -- Detect RISING EDGE of the T-wave vote
                        if t_voted = '1' and t_voted_prev = '0' then
                            t_unif_internal <= '1';
                            
                            -- APPLY MATHEMATICAL COMPENSATION FOR DIFFERENTIAL DELAYS
                            -- Real RT = Measured RT - T_Delay + R_Delay
                            rt_real := cnt_rt - DELAY_T_WAVE + DELAY_R_WAVE;
                            
                            -- Protection against negative values in case of noise or extreme anomalies
                            if rt_real < 0 then
                                rt_interval_ms <= (others => '0');
                            else
                                rt_interval_ms <= to_signed(rt_real, 24);
                            end if;
                            
                            rt_busy <= '0';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
end Behavioral;