library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;

entity tb_wavelet_1dimension is
end tb_wavelet_1dimension;

architecture Behavioral of tb_wavelet_1dimension is

    -- Componente a probar
    component wavelet_1dimension
        Port (
            clk              : in  STD_LOGIC;
            reset            : in  STD_LOGIC;
            sample_valid     : in  STD_LOGIC;
            raw_data         : in  STD_LOGIC_VECTOR(23 downto 0);
            y_wavelet_s3     : out SIGNED(23 downto 0);
            d_wavelet_s3     : out SIGNED(23 downto 0);
            d_wavelet_s8     : out SIGNED(23 downto 0);
            wavelet_ready_s3 : out STD_LOGIC;
            wavelet_ready_s8 : out STD_LOGIC
        );
    end component;

    -- Señales de estímulo
    signal clk          : std_logic := '0';
    signal reset        : std_logic := '0';
    signal sample_valid : std_logic := '0';
    signal raw_data     : std_logic_vector(23 downto 0) := (others => '0');

    -- Señales de observación
    signal y_s3, d_s3, d_s8 : signed(23 downto 0);
    signal rdy_s3, rdy_s8   : std_logic;

    constant CLK_PERIOD : time := 10 ns; -- 100 MHz

begin

    -- Instancia del filtro 1D
    DUT: wavelet_1dimension
    port map (
        clk => clk,
        reset => reset,
        sample_valid => sample_valid,
        raw_data => raw_data,
        y_wavelet_s3 => y_s3,
        d_wavelet_s3 => d_s3,
        d_wavelet_s8 => d_s8,
        wavelet_ready_s3 => rdy_s3,
        wavelet_ready_s8 => rdy_s8
    );

    -- Generador de Reloj
    clk_process : process
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    -- Proceso de lectura de datos reales
    stim_proc: process
        file data_file : text open read_mode is "ecg_healthy_raw.txt";
        variable current_line : line;
        variable data_int : integer;
    begin
        -- Reset del sistema
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait for 100 ns;

        while not endfile(data_file) loop
            readline(data_file, current_line);
            read(current_line, data_int);

            wait until falling_edge(clk);
            raw_data <= std_logic_vector(to_signed(data_int, 24));
            sample_valid <= '1';
            wait for CLK_PERIOD;
            sample_valid <= '0';

            -- Simulamos una tasa de muestreo de 1kHz (1ms entre muestras)
            wait for 1 ms; 
        end loop;

        assert false report "Simulación terminada con éxito" severity failure;
        wait;
    end process;

end Behavioral;