library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;

entity tb_uart_controller is
end tb_uart_controller;

architecture Behavioral of tb_uart_controller is

    -- 1. DECLARACIÓN DE COMPONENTES
    component wavelet_3d_transform
        Port (
            clk : in STD_LOGIC; reset : in STD_LOGIC;
            sample_valid_in : in STD_LOGIC;
            raw_x, raw_y, raw_z : in STD_LOGIC_VECTOR(23 downto 0);
            vector_ready_s3, vector_ready_s8 : out STD_LOGIC;
            d_x_s3, d_y_s3, d_z_s3 : out SIGNED(23 downto 0);
            d_x_s8, d_y_s8, d_z_s8 : out SIGNED(23 downto 0)
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
            current_mem_t_pmax, current_mem_t_pmin : out SIGNED(23 downto 0)
        );
    end component;

    component detection_bridge
        generic (
            FS_HZ : integer := 360
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

    component detection_alarm
        generic (
            FS_HZ : integer := 360
        );
        Port ( 
            clk, reset, d_valid : in  STD_LOGIC;
            qrs_unified, t_unified : in  STD_LOGIC;
            rr_interval_ms, rt_interval_ms : in  SIGNED(23 downto 0);
            alarm_tachycardia, alarm_bradycardia, alarm_arrhythmia, alarm_asystole, alarm_sudden_death : out STD_LOGIC
        );
    end component;

    -- Añadimos la UART a la arquitectura
    component uart_controller
        generic (
            CLK_FREQ  : integer := 100000000; 
            BAUD_RATE : integer := 115200
        );
        Port (
            clk, reset, d_valid : in  STD_LOGIC;
            raw_x, raw_y, raw_z : in  STD_LOGIC_VECTOR(23 downto 0);
            s3_x, s3_y, s3_z    : in  SIGNED(23 downto 0);
            s8_x, s8_y, s8_z    : in  SIGNED(23 downto 0);
            rr_interval_ms      : in  SIGNED(23 downto 0);
            rt_interval_ms      : in  SIGNED(23 downto 0);
            qrs_unified, t_unified : in STD_LOGIC;
            al_tachy, al_brady, al_arrh, al_asyst, al_death : in STD_LOGIC;
            tx                  : out STD_LOGIC;
            uart_dropping       : out STD_LOGIC
        );
    end component;

    -- 2. SEÑALES INTERNAS
    signal clk          : std_logic := '0';
    signal reset        : std_logic := '0';
    signal sample_valid : std_logic := '0';
    signal rx, ry, rz   : std_logic_vector(23 downto 0) := (others => '0');

    signal v_rdy_s3, v_rdy_s8 : std_logic := '0';
    signal d_x_s3, d_y_s3, d_z_s3 : signed(23 downto 0) := (others => '0');
    signal d_x_s8, d_y_s8, d_z_s8 : signed(23 downto 0) := (others => '0');

    signal r_pulse, t_pulse   : std_logic := '0';
    signal rr_raw             : signed(23 downto 0) := (others => '0');
    signal qrs_pmax, qrs_pmin : signed(23 downto 0) := (others => '0');

    signal qrs_unif, t_unif   : std_logic := '0';
    signal rr_ms, rt_ms       : signed(23 downto 0) := (others => '0');

    signal al_tachy, al_brady, al_arrh, al_asyst, al_death : std_logic := '0';
    
    -- Señales de la UART
    signal tx            : std_logic;
    signal uart_dropping : std_logic;

    constant CLK_PERIOD : time := 10 ns;
    constant BIT_PERIOD : time := 8680.5 ns; -- 115200 baudios

begin

    -- 3. INSTANCIACIÓN DE TODOS LOS MÓDULOS (LA CADENA DE PROCESAMIENTO)
    WAVE_INST: wavelet_3d_transform
    port map (
        clk => clk, reset => reset, sample_valid_in => sample_valid,
        raw_x => rx, raw_y => ry, raw_z => rz,
        vector_ready_s3 => v_rdy_s3, vector_ready_s8 => v_rdy_s8,
        d_x_s3 => d_x_s3, d_y_s3 => d_y_s3, d_z_s3 => d_z_s3,
        d_x_s8 => d_x_s8, d_y_s8 => d_y_s8, d_z_s8 => d_z_s8
    );

    QRS_INST: qrs_detector
    port map (
        clk => clk, reset => reset,
        d_valid => v_rdy_s3, d_wavelet => d_x_s3,
        qrs_detected => r_pulse, time_rr => rr_raw,
        current_mem_pmax => qrs_pmax, current_mem_pmin => qrs_pmin
    );

    T_DET_INST: t_detector
    port map (
        clk => clk, reset => reset,
        d_valid => v_rdy_s8, d_wavelet => d_x_s8,
        start_trigger => r_pulse, rr_interval => rr_raw,
        qrs_mem_pmax => qrs_pmax, qrs_mem_pmin => qrs_pmin,
        t_detected => t_pulse
    );

    BRIDGE_INST: detection_bridge
    generic map ( FS_HZ => 360 )
    port map (
        clk => clk, reset => reset, d_valid => sample_valid,
        qrs_x => r_pulse, qrs_y => r_pulse, qrs_z => '0',
        t_x => t_pulse,   t_y => t_pulse, t_z => t_pulse,
        qrs_unified => qrs_unif, t_unified => t_unif,
        rr_interval_ms => rr_ms, rt_interval_ms => rt_ms
    );

    DIAG_INST: detection_alarm
    generic map ( FS_HZ => 360 )
    port map (
        clk => clk, reset => reset, d_valid => sample_valid,
        qrs_unified => qrs_unif, t_unified => t_unif,
        rr_interval_ms => rr_ms, rt_interval_ms => rt_ms,
        alarm_tachycardia => al_tachy, alarm_bradycardia => al_brady,
        alarm_arrhythmia => al_arrh, alarm_asystole => al_asyst,
        alarm_sudden_death => al_death
    );

    -- LA JOYA DE LA CORONA: EL TRANSMISOR UART
    UART_INST: uart_controller
    generic map (
        CLK_FREQ  => 100000000,
        BAUD_RATE => 115200
    )
    port map (
        clk => clk, reset => reset, d_valid => sample_valid,
        raw_x => rx, raw_y => ry, raw_z => rz,
        s3_x => d_x_s3, s3_y => d_y_s3, s3_z => d_z_s3,
        s8_x => d_x_s8, s8_y => d_y_s8, s8_z => d_z_s8,
        rr_interval_ms => rr_ms, rt_interval_ms => rt_ms,
        qrs_unified => qrs_unif, t_unified => t_unif,
        al_tachy => al_tachy, al_brady => al_brady, al_arrh => al_arrh,
        al_asyst => al_asyst, al_death => al_death,
        tx => tx,
        uart_dropping => uart_dropping
    );

    -- 4. RELOJ
    clk_process : process begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    -- =========================================================
    -- 5. RECEPTOR UART VIRTUAL (Software-in-the-Loop)
    -- Escucha el cable TX y crea el archivo para Python
    -- =========================================================
    UART_RX_VIRTUAL : process
        file out_file : text open write_mode is "C:\Users\aleja\Desktop\Uni\4toAno\8_Cuatrimestre\TFG\ECG_in_FPGA_Thesis\uart_display\uart_sim_output.txt";
        variable out_line : line;
        variable rx_byte  : std_logic_vector(7 downto 0);
    begin
        wait for 200 ns; 

        loop
            wait until falling_edge(tx); 
            wait for BIT_PERIOD / 2;

            if tx = '0' then 
                for i in 0 to 7 loop
                    wait for BIT_PERIOD;
                    rx_byte(i) := tx;
                end loop;

                write(out_line, to_integer(unsigned(rx_byte)));
                writeline(out_file, out_line);
                wait for BIT_PERIOD;
            end if;
        end loop;
    end process;

    -- =========================================================
    -- 6. PROCESO DE ESTÍMULOS (Lectura del archivo ECG)
    -- =========================================================
    stim_proc: process
        -- CAMBIA LA RUTA AL ARCHIVO QUE QUIERAS PROBAR
        file data_file : text open read_mode is "C:/Users/aleja/Desktop/Uni/4toAno/8_Cuatrimestre/TFG/ECG_in_FPGA_Thesis/heart_raw_signals/ecg_sudden_death.txt";
        variable L : line;
        variable v_x, v_y, v_z : integer;
    begin
        reset <= '1'; wait for 100 ns;
        reset <= '0'; wait for 100 ns;

        report "--- Iniciando lectura de archivo ---";

        while not endfile(data_file) loop
            readline(data_file, L);
            
            if L'length > 0 then
                read(L, v_x); read(L, v_y); read(L, v_z);
                
                wait until falling_edge(clk);
                rx <= std_logic_vector(to_signed(v_x, 24));
                ry <= std_logic_vector(to_signed(v_y, 24));
                rz <= std_logic_vector(to_signed(v_z, 24));
                
                sample_valid <= '1';
                wait for CLK_PERIOD;
                sample_valid <= '0';
                
                -- CAMBIO CRÍTICO: Esperamos 2.77 milisegundos reales (360 Hz)
                -- Esto permite a la UART transmitir a su velocidad real y generar
                -- una trama fluida sin descartar de forma artificial.
                wait for 2777 us; 
            end if;
        end loop;

        -- Esperamos 5ms extra para que el último frame termine de enviarse por UART
        wait for 5 ms;

        report "--- Simulación y Exportación UART finalizada con éxito ---";
        std.env.stop; 
        wait;
    end process;

end Behavioral;