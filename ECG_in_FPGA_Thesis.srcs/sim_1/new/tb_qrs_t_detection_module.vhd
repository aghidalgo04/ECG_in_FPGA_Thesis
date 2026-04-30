library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;

entity tb_qrs_t_detection_module is
end tb_qrs_t_detection_module;

architecture Behavioral of tb_qrs_t_detection_module is

    ---------------------------------------------------------------------------
    -- COMPONENT DECLARATIONS
    ---------------------------------------------------------------------------
    
    -- 1. Wavelet 3D Transformation
    component wavelet_3d_transform
        Port (
            clk : in STD_LOGIC; reset : in STD_LOGIC;
            sample_valid_in : in STD_LOGIC;
            raw_x, raw_y, raw_z : in STD_LOGIC_VECTOR(23 downto 0);
            vector_ready_s3, vector_ready_s8 : out STD_LOGIC;
            d_x_s3, d_x_s8 : out SIGNED(23 downto 0)
        );
    end component;

    -- 2. QRS Detector (R-wave)
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

    -- 3. T-Wave Detector
    component t_detector
        Port (
            clk : in STD_LOGIC; reset : in STD_LOGIC;
            d_valid : in STD_LOGIC;
            d_wavelet : in SIGNED(23 downto 0);
            start_trigger : in STD_LOGIC;
            rr_interval : in SIGNED(23 downto 0);
            qrs_mem_pmax, qrs_mem_pmin : in SIGNED(23 downto 0);
            t_detected : out STD_LOGIC;
            current_mem_t_pmax, current_mem_t_pmin : out SIGNED(23 downto 0)
        );
    end component;

    -- 4. Detection Bridge
    component detection_bridge
    generic (
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
    end component;

    -- 5. Diagnosis Module
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

    ---------------------------------------------------------------------------
    -- SIGNAL INTERCONNECTIONS
    ---------------------------------------------------------------------------
    signal clk          : std_logic := '0';
    signal reset        : std_logic := '0';
    signal sample_valid : std_logic := '0';
    signal rx, ry, rz   : std_logic_vector(23 downto 0) := (others => '0');

    signal v_rdy_s3, v_rdy_s8 : std_logic;
    signal data_s3, data_s8   : signed(23 downto 0);

    signal r_pulse, t_pulse   : std_logic;
    signal rr_raw             : signed(23 downto 0);
    signal qrs_pmax, qrs_pmin : signed(23 downto 0);

    signal qrs_unif, t_unif   : std_logic;
    signal rr_ms, rt_ms       : signed(23 downto 0);

    signal al_tachy, al_brady, al_arrh, al_asyst, al_death : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    ---------------------------------------------------------------------------
    -- INSTANTIATIONS
    ---------------------------------------------------------------------------

    WAVE_INST: wavelet_3d_transform
    port map (
        clk => clk, reset => reset, sample_valid_in => sample_valid,
        raw_x => rx, raw_y => ry, raw_z => rz,
        vector_ready_s3 => v_rdy_s3, vector_ready_s8 => v_rdy_s8,
        d_x_s3 => data_s3, d_x_s8 => data_s8
    );

    QRS_INST: qrs_detector
    port map (
        clk => clk, reset => reset,
        d_valid => v_rdy_s3, d_wavelet => data_s3,
        qrs_detected => r_pulse, time_rr => rr_raw,
        current_mem_pmax => qrs_pmax, current_mem_pmin => qrs_pmin
    );

    T_DET_INST: t_detector
    port map (
        clk => clk, reset => reset,
        d_valid => v_rdy_s8, d_wavelet => data_s8,
        start_trigger => r_pulse, rr_interval => rr_raw,
        qrs_mem_pmax => qrs_pmax, qrs_mem_pmin => qrs_pmin,
        t_detected => t_pulse
    );

    BRIDGE_INST: detection_bridge
    generic map (
        FS_HZ => 360
    )
    port map (
        clk => clk, reset => reset, d_valid => sample_valid,
        qrs_x => r_pulse, qrs_y => r_pulse, qrs_z => '0',
        t_x => t_pulse,   t_y => t_pulse, t_z => t_pulse,
        qrs_unified => qrs_unif, t_unified => t_unif,
        rr_interval_ms => rr_ms, rt_interval_ms => rt_ms
    );

    DIAG_INST: detection_module
    port map (
        clk => clk, reset => reset, d_valid => sample_valid,
        qrs_unified => qrs_unif, t_unified => t_unif,
        rr_interval_ms => rr_ms, rt_interval_ms => rt_ms,
        alarm_tachycardia => al_tachy, alarm_bradycardia => al_brady,
        alarm_arrhythmia => al_arrh, alarm_asystole => al_asyst,
        alarm_sudden_death => al_death
    );

    ---------------------------------------------------------------------------
    -- PROCESSES
    ---------------------------------------------------------------------------

    clk_process : process begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    stim_proc: process
        -- CAMBIO 1: Ruta con barras normales para evitar errores de escape \U
        file data_file : text open read_mode is "C:/Users/aleja/Desktop/Uni/4toAno/8_Cuatrimestre/TFG/ECG_in_FPGA_Thesis/heart_raw_signals/ecg_healthy_raw.txt";
        variable L : line;
        variable v_x, v_y, v_z : integer;
    begin
        reset <= '1'; wait for 100 ns;
        reset <= '0'; wait for 100 ns;

        report "--- Iniciando lectura de archivo ---";

        while not endfile(data_file) loop
            readline(data_file, L);
            
            -- CAMBIO 2: Protección contra líneas vacías (evita el Fatal Error de TextIO)
            if L'length > 0 then
                read(L, v_x); read(L, v_y); read(L, v_z);
                
                wait until falling_edge(clk);
                rx <= std_logic_vector(to_signed(v_x, 24));
                ry <= std_logic_vector(to_signed(v_y, 24));
                rz <= std_logic_vector(to_signed(v_z, 24));
                
                sample_valid <= '1';
                wait for CLK_PERIOD;
                sample_valid <= '0';
                
                -- CAMBIO 3: Desaceleración a 1ms (Equilibrio entre velocidad y estabilidad)
                wait for 1 ms; 
            end if;
        end loop;

        report "--- Simulación finalizada con éxito ---";
        std.env.stop; -- Finaliza la simulación de forma limpia en Vivado
        wait;
    end process;

end Behavioral;