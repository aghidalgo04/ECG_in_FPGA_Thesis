library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;

entity tb_t_detector is
end tb_t_detector;

architecture Behavioral of tb_t_detector is

    component wavelet_3d_transform
        Port (
            clk : in STD_LOGIC; reset : in STD_LOGIC;
            sample_valid_in : in STD_LOGIC;
            raw_x, raw_y, raw_z : in STD_LOGIC_VECTOR(23 downto 0);
            vector_ready_s3, vector_ready_s8 : out STD_LOGIC;
            d_x_s3, d_x_s8 : out SIGNED(23 downto 0)
        );
    end component;

    component qrs_detector
        Port (
            clk : in STD_LOGIC; reset : in STD_LOGIC;
            d_valid : in STD_LOGIC;
            d_wavelet : in SIGNED(23 downto 0);
            qrs_detected : out STD_LOGIC;
            time_rr : out SIGNED(23 downto 0);
            current_mem_pmax, current_mem_pmin : out SIGNED(23 downto 0)
        );
    end component;

    component t_detector
        Port (
            clk : in STD_LOGIC; reset : in STD_LOGIC;
            d_valid : in STD_LOGIC;
            d_wavelet : in SIGNED(23 downto 0);
            start_trigger : in STD_LOGIC;
            rr_interval : in SIGNED(23 downto 0);
            qrs_mem_pmax, qrs_mem_pmin : in SIGNED(23 downto 0);
            t_detected : out STD_LOGIC;
            t_mem_pmax, t_mem_pmin : out SIGNED(23 downto 0) 
        );
    end component;

    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal sample_valid : std_logic := '0';
    signal rx, ry, rz : std_logic_vector(23 downto 0) := (others => '0');
    
    signal v_rdy_s3, v_rdy_s8 : std_logic;
    signal data_s3, data_s8 : signed(23 downto 0);

    signal qrs_hit : std_logic;
    signal rr_val : signed(23 downto 0);
    signal qrs_m_pmax, qrs_m_pmin : signed(23 downto 0);

    signal t_hit : std_logic;
    signal t_m_pmax, t_m_pmin : signed(23 downto 0);

    constant CLK_PERIOD : time := 10 ns;

begin

    WAVE_INST: wavelet_3d_transform
    port map (
        clk => clk, reset => reset,
        sample_valid_in => sample_valid,
        raw_x => rx, raw_y => ry, raw_z => rz,
        vector_ready_s3 => v_rdy_s3,
        vector_ready_s8 => v_rdy_s8,
        d_x_s3 => data_s3,
        d_x_s8 => data_s8
    );

    QRS_INST: qrs_detector
    port map (
        clk => clk, reset => reset,
        d_valid => v_rdy_s3,
        d_wavelet => data_s3,
        qrs_detected => qrs_hit,
        time_rr => rr_val,
        current_mem_pmax => qrs_m_pmax,
        current_mem_pmin => qrs_m_pmin
    );

    T_DET_INST: t_detector
    port map (
        clk => clk, reset => reset,
        d_valid => v_rdy_s8,
        d_wavelet => data_s8,
        start_trigger => qrs_hit,
        rr_interval => rr_val,
        qrs_mem_pmax => qrs_m_pmax,
        qrs_mem_pmin => qrs_m_pmin,
        t_detected => t_hit,
        t_mem_pmax => t_m_pmax,
        t_mem_pmin => t_m_pmin
    );

    clk_process : process begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    stim_proc: process
        file data_file_x : text open read_mode is "C:/Users/aleja/Desktop/Uni/4toAno/8_Cuatrimestre/TFG/ECG_in_FPGA_Thesis/heart_raw_signals/ecg_real_eje_x.txt";
        file data_file_y : text open read_mode is "C:/Users/aleja/Desktop/Uni/4toAno/8_Cuatrimestre/TFG/ECG_in_FPGA_Thesis/heart_raw_signals/ecg_real_eje_y.txt";
        file data_file_z : text open read_mode is "C:/Users/aleja/Desktop/Uni/4toAno/8_Cuatrimestre/TFG/ECG_in_FPGA_Thesis/heart_raw_signals/ecg_real_eje_z.txt";
        
        variable L_x, L_y, L_z : line;
        variable v_x, v_y, v_z : integer;
        variable good_x, good_y, good_z : boolean;
    begin
        reset <= '1'; wait for 100 ns;
        reset <= '0'; wait for 100 ns;

        while not endfile(data_file_x) loop
            readline(data_file_x, L_x);
            read(L_x, v_x, good_x);
            
            v_y := 0;
            if not endfile(data_file_y) then 
                readline(data_file_y, L_y); 
                read(L_y, v_y, good_y);
            end if;
            
            v_z := 0;
            if not endfile(data_file_z) then 
                readline(data_file_z, L_z); 
                read(L_z, v_z, good_z);
            end if;

            if good_x then
                wait until falling_edge(clk);
                rx <= std_logic_vector(to_signed(v_x, 24));
                ry <= std_logic_vector(to_signed(v_y, 24));
                rz <= std_logic_vector(to_signed(v_z, 24));
                sample_valid <= '1';
                wait for CLK_PERIOD;
                sample_valid <= '0';
                
                wait for 1 ms; 
            end if;
        end loop;
        
        std.env.stop;
        wait;
    end process;

end Behavioral;