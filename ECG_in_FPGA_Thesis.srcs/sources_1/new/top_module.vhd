library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_module is
    generic (
        CLK_FREQ  : integer := 100000000;
        BAUD_RATE : integer := 115200;
        CLK_DIV   : integer := 10;
        FS_HZ     : integer := 1000
    );
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        drdy_b   : in  std_logic;
        miso     : in  std_logic;
        
        sclk     : out std_logic;
        mosi     : out std_logic;
        cs_b     : out std_logic;
        tx       : out std_logic
    );
end top_module;

architecture Structural of top_module is

    component spi_controller is
        generic ( CLK_DIV : integer := 10 );
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            drdy_b   : in  std_logic;
            sclk     : out std_logic;
            mosi     : out std_logic;
            miso     : in  std_logic;
            cs_b     : out std_logic;
            raw_x    : out std_logic_vector(23 downto 0);
            raw_y    : out std_logic_vector(23 downto 0);
            raw_z    : out std_logic_vector(23 downto 0);
            d_valid  : out std_logic
        );
    end component;

    component wavelet_3d_transform is
        port (
            clk             : in  std_logic;
            reset           : in  std_logic;
            sample_valid_in : in  std_logic;
            raw_x           : in  std_logic_vector(23 downto 0);
            raw_y           : in  std_logic_vector(23 downto 0);
            raw_z           : in  std_logic_vector(23 downto 0);
            wavelet_x       : out std_logic_vector(23 downto 0);
            wavelet_y       : out std_logic_vector(23 downto 0);
            wavelet_z       : out std_logic_vector(23 downto 0);
            vector_ready_s3 : out std_logic;
            vector_ready_s8 : out std_logic;
            d_x_s3          : out signed(23 downto 0);
            d_y_s3          : out signed(23 downto 0);
            d_z_s3          : out signed(23 downto 0);
            d_x_s8          : out signed(23 downto 0);
            d_y_s8          : out signed(23 downto 0);
            d_z_s8          : out signed(23 downto 0)
        );
    end component;

    component qrs_detector is
        port (
            clk                 : in  std_logic;
            reset               : in  std_logic;
            d_valid             : in  std_logic;
            d_wavelet           : in  signed(23 downto 0);
            qrs_detected        : out std_logic;
            polarity            : out std_logic;
            time_rr             : out signed(23 downto 0);
            current_mem_pmax    : out signed(23 downto 0);
            current_mem_pmin    : out signed(23 downto 0)
        );
    end component;

    component t_detector is
        port (
            clk                : in  std_logic;
            reset              : in  std_logic;
            d_valid            : in  std_logic;
            d_wavelet          : in  signed(23 downto 0);
            start_trigger      : in  std_logic;
            rr_interval        : in  signed(23 downto 0);
            qrs_mem_pmax       : in  signed(23 downto 0);
            qrs_mem_pmin       : in  signed(23 downto 0);
            t_detected         : out std_logic;
            current_mem_t_pmax : out signed(23 downto 0);
            current_mem_t_pmin : out signed(23 downto 0)
        );
    end component;

    component detection_bridge is
        generic ( FS_HZ : integer := 1000 );
        port (
            clk             : in  std_logic;
            reset           : in  std_logic;
            d_valid         : in  std_logic;
            qrs_x, qrs_y, qrs_z : in std_logic;
            t_x, t_y, t_z       : in std_logic;
            qrs_unified     : out std_logic;
            t_unified       : out std_logic;
            rr_interval_ms  : out signed(23 downto 0);
            rt_interval_ms  : out signed(23 downto 0)
        );
    end component;

    component detection_alarm is
        generic ( FS_HZ : integer := 1000 );
        port (
            clk                  : in  std_logic;
            reset                : in  std_logic;
            d_valid              : in  std_logic;
            qrs_unified          : in  std_logic;
            t_unified            : in  std_logic;
            rr_interval_ms       : in  signed(23 downto 0);
            rt_interval_ms       : in  signed(23 downto 0);
            alarm_tachycardia    : out std_logic;
            alarm_bradycardia    : out std_logic;
            alarm_arrhythmia     : out std_logic;
            alarm_asystole       : out std_logic;
            alarm_sudden_death   : out std_logic
        );
    end component;

    component uart_controller is
        generic (
            CLK_FREQ  : integer := 100000000;
            BAUD_RATE : integer := 115200
        );
        port (
            clk             : in  std_logic;
            reset           : in  std_logic;
            d_valid         : in  std_logic;
            raw_x           : in  std_logic_vector(23 downto 0);
            raw_y           : in  std_logic_vector(23 downto 0);
            raw_z           : in  std_logic_vector(23 downto 0);
            s3_x, s3_y, s3_z : in  signed(23 downto 0);
            s8_x, s8_y, s8_z : in  signed(23 downto 0);
            rr_interval_ms  : in  signed(23 downto 0);
            rt_interval_ms  : in  signed(23 downto 0);
            qrs_unified     : in  std_logic;
            t_unified       : in  std_logic;
            al_tachy        : in  std_logic;
            al_brady        : in  std_logic;
            al_arrh         : in  std_logic;
            al_asyst        : in  std_logic;
            al_death        : in  std_logic;
            tx              : out std_logic
        );
    end component;

    signal s_raw_x, s_raw_y, s_raw_z : std_logic_vector(23 downto 0);
    signal s_spi_valid               : std_logic;

    signal s_w_x, s_w_y, s_w_z       : std_logic_vector(23 downto 0);
    signal s_rdy_s3, s_rdy_s8        : std_logic;
    
    signal s_dx_s3, s_dy_s3, s_dz_s3 : signed(23 downto 0);
    signal s_dx_s8, s_dy_s8, s_dz_s8 : signed(23 downto 0);

    signal s_qrs_x, s_qrs_y, s_qrs_z : std_logic;
    signal s_t_x, s_t_y, s_t_z       : std_logic;

    signal s_pol_x, s_pol_y, s_pol_z : std_logic;
    signal s_trr_x, s_trr_y, s_trr_z : signed(23 downto 0);
    
    signal s_pmax_x, s_pmax_y, s_pmax_z : signed(23 downto 0);
    signal s_pmin_x, s_pmin_y, s_pmin_z : signed(23 downto 0);
    
    signal s_tpmax_x, s_tpmax_y, s_tpmax_z : signed(23 downto 0);
    signal s_tpmin_x, s_tpmin_y, s_tpmin_z : signed(23 downto 0);

    signal s_qrs_unified, s_t_unified : std_logic;
    signal s_rr_ms, s_rt_ms           : signed(23 downto 0);

    signal s_al_tachy, s_al_brady, s_al_arrh, s_al_asyst, s_al_death : std_logic;

begin

    SPI_INST: spi_controller
        generic map ( CLK_DIV => CLK_DIV )
        port map (
            clk      => clk,
            rst      => reset,
            drdy_b   => drdy_b,
            sclk     => sclk,
            mosi     => mosi,
            miso     => miso,
            cs_b     => cs_b,
            raw_x    => s_raw_x,
            raw_y    => s_raw_y,
            raw_z    => s_raw_z,
            d_valid  => s_spi_valid
        );

    WAVELET_INST: wavelet_3d_transform
        port map (
            clk             => clk,
            reset           => reset,
            sample_valid_in => s_spi_valid,
            raw_x           => s_raw_x,
            raw_y           => s_raw_y,
            raw_z           => s_raw_z,
            wavelet_x       => s_w_x,
            wavelet_y       => s_w_y,
            wavelet_z       => s_w_z,
            vector_ready_s3 => s_rdy_s3,
            vector_ready_s8 => s_rdy_s8,
            d_x_s3          => s_dx_s3,
            d_y_s3          => s_dy_s3,
            d_z_s3          => s_dz_s3,
            d_x_s8          => s_dx_s8,
            d_y_s8          => s_dy_s8,
            d_z_s8          => s_dz_s8
        );

    QRS_DET_X: qrs_detector
        port map (
            clk                 => clk,
            reset               => reset,
            d_valid             => s_rdy_s3,
            d_wavelet           => s_dx_s3,
            qrs_detected        => s_qrs_x,
            polarity            => s_pol_x,
            time_rr             => s_trr_x,
            current_mem_pmax    => s_pmax_x,
            current_mem_pmin    => s_pmin_x
        );

    QRS_DET_Y: qrs_detector
        port map (
            clk                 => clk,
            reset               => reset,
            d_valid             => s_rdy_s3,
            d_wavelet           => s_dy_s3,
            qrs_detected        => s_qrs_y,
            polarity            => s_pol_y,
            time_rr             => s_trr_y,
            current_mem_pmax    => s_pmax_y,
            current_mem_pmin    => s_pmin_y
        );

    QRS_DET_Z: qrs_detector
        port map (
            clk                 => clk,
            reset               => reset,
            d_valid             => s_rdy_s3,
            d_wavelet           => s_dz_s3,
            qrs_detected        => s_qrs_z,
            polarity            => s_pol_z,
            time_rr             => s_trr_z,
            current_mem_pmax    => s_pmax_z,
            current_mem_pmin    => s_pmin_z
        );

    T_DET_X: t_detector
        port map (
            clk                => clk,
            reset              => reset,
            d_valid            => s_rdy_s8,
            d_wavelet          => s_dx_s8,
            start_trigger      => s_qrs_x,
            rr_interval        => s_trr_x,
            qrs_mem_pmax       => s_pmax_x,
            qrs_mem_pmin       => s_pmin_x,
            t_detected         => s_t_x,
            current_mem_t_pmax => s_tpmax_x,
            current_mem_t_pmin => s_tpmin_x
        );

    T_DET_Y: t_detector
        port map (
            clk                => clk,
            reset              => reset,
            d_valid            => s_rdy_s8,
            d_wavelet          => s_dy_s8,
            start_trigger      => s_qrs_y,
            rr_interval        => s_trr_y,
            qrs_mem_pmax       => s_pmax_y,
            qrs_mem_pmin       => s_pmin_y,
            t_detected         => s_t_y,
            current_mem_t_pmax => s_tpmax_y,
            current_mem_t_pmin => s_tpmin_y
        );

    T_DET_Z: t_detector
        port map (
            clk                => clk,
            reset              => reset,
            d_valid            => s_rdy_s8,
            d_wavelet          => s_dz_s8,
            start_trigger      => s_qrs_z,
            rr_interval        => s_trr_z,
            qrs_mem_pmax       => s_pmax_z,
            qrs_mem_pmin       => s_pmin_z,
            t_detected         => s_t_z,
            current_mem_t_pmax => s_tpmax_z,
            current_mem_t_pmin => s_tpmin_z
        );

    BRIDGE_INST: detection_bridge
        generic map ( FS_HZ => FS_HZ )
        port map (
            clk             => clk,
            reset           => reset,
            d_valid         => s_spi_valid,
            qrs_x           => s_qrs_x,
            qrs_y           => s_qrs_y,
            qrs_z           => s_qrs_z,
            t_x             => s_t_x,
            t_y             => s_t_y,
            t_z             => s_t_z,
            qrs_unified     => s_qrs_unified,
            t_unified       => s_t_unified,
            rr_interval_ms  => s_rr_ms,
            rt_interval_ms  => s_rt_ms
        );

    ALARM_INST: detection_alarm
        generic map ( FS_HZ => FS_HZ )
        port map (
            clk                => clk,
            reset              => reset,
            d_valid            => s_spi_valid,
            qrs_unified        => s_qrs_unified,
            t_unified          => s_t_unified,
            rr_interval_ms     => s_rr_ms,
            rt_interval_ms     => s_rt_ms,
            alarm_tachycardia  => s_al_tachy,
            alarm_bradycardia  => s_al_brady,
            alarm_arrhythmia   => s_al_arrh,
            alarm_asystole     => s_al_asyst,
            alarm_sudden_death => s_al_death
        );

    UART_INST: uart_controller
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => BAUD_RATE
        )
        port map (
            clk             => clk,
            reset           => reset,
            d_valid         => s_spi_valid,
            raw_x           => s_raw_x,
            raw_y           => s_raw_y,
            raw_z           => s_raw_z,
            s3_x            => s_dx_s3,
            s3_y            => s_dy_s3,
            s3_z            => s_dz_s3,
            s8_x            => s_dx_s8,
            s8_y            => s_dy_s8,
            s8_z            => s_dz_s8,
            rr_interval_ms  => s_rr_ms,
            rt_interval_ms  => s_rt_ms,
            qrs_unified     => s_qrs_unified,
            t_unified       => s_t_unified,
            al_tachy        => s_al_tachy,
            al_brady        => s_al_brady,
            al_arrh         => s_al_arrh,
            al_asyst        => s_al_asyst,
            al_death        => s_al_death,
            tx              => tx
        );
end Structural;