library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;

entity tb_wavelet_3d is
-- El testbench no tiene puertos
end tb_wavelet_3d;

architecture Behavioral of tb_wavelet_3d is

    -- Componente a probar (DUT)
    component wavelet_3d_transform
    Port (
        clk             : in  STD_LOGIC;
        reset           : in  STD_LOGIC;
        sample_valid_in : in  STD_LOGIC;
        raw_x           : in  STD_LOGIC_VECTOR(23 downto 0);
        raw_y           : in  STD_LOGIC_VECTOR(23 downto 0);
        raw_z           : in  STD_LOGIC_VECTOR(23 downto 0);
        
        wavelet_x       : out STD_LOGIC_VECTOR(23 downto 0);
        wavelet_y       : out STD_LOGIC_VECTOR(23 downto 0);
        wavelet_z       : out STD_LOGIC_VECTOR(23 downto 0);
        
        vector_ready_s3 : out STD_LOGIC;
        vector_ready_s8 : out STD_LOGIC;
        d_x_s3          : out SIGNED(23 downto 0);
        d_y_s3          : out SIGNED(23 downto 0);
        d_z_s3          : out SIGNED(23 downto 0);
        d_x_s8          : out SIGNED(23 downto 0);
        d_y_s8          : out SIGNED(23 downto 0);
        d_z_s8          : out SIGNED(23 downto 0)
    );
    end component;

    -- Señales de conexión
    signal clk             : std_logic := '0';
    signal reset           : std_logic := '0';
    signal sample_valid_in : std_logic := '0';
    signal raw_x           : std_logic_vector(23 downto 0) := (others => '0');
    signal raw_y           : std_logic_vector(23 downto 0) := (others => '0');
    signal raw_z           : std_logic_vector(23 downto 0) := (others => '0');

    -- Salidas (observables)
    signal wavelet_x, wavelet_y, wavelet_z : std_logic_vector(23 downto 0);
    signal vector_ready_s3, vector_ready_s8 : std_logic;
    signal dx3, dy3, dz3 : signed(23 downto 0);
    signal dx8, dy8, dz8 : signed(23 downto 0);

    -- Configuración del reloj (100 MHz)
    constant CLK_PERIOD : time := 10 ns;
    
    -- Configuración de muestreo (Simulamos 500 Hz => 2 ms entre muestras)
    -- Para acelerar la simulación, usaremos un tiempo más rápido, pero 
    -- en la realidad sería 2 ms.
    constant SAMPLE_RATE_DELAY : time := 20 us; 

begin

    -- Instancia del DUT
    uut: wavelet_3d_transform
    port map (
        clk => clk,
        reset => reset,
        sample_valid_in => sample_valid_in,
        raw_x => raw_x,
        raw_y => raw_y,
        raw_z => raw_z,
        wavelet_x => wavelet_x,
        wavelet_y => wavelet_y,
        wavelet_z => wavelet_z,
        vector_ready_s3 => vector_ready_s3,
        vector_ready_s8 => vector_ready_s8,
        d_x_s3 => dx3, d_y_s3 => dy3, d_z_s3 => dz3,
        d_x_s8 => dx8, d_y_s8 => dy8, d_z_s8 => dz8
    );

    -- Generación de Reloj
    clk_process :process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- Proceso de lectura de archivo y estímulos
    stim_proc: process
        file ecg_file : text open read_mode is "ecg_data.txt";
        variable current_line : line;
        variable v_x, v_y, v_z : integer;
    begin
        -- 1. Reset inicial
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait for 100 ns;

        -- 2. Bucle de lectura
        while not endfile(ecg_file) loop
            -- Leer una línea del archivo
            readline(ecg_file, current_line);
            
            -- Leer los tres enteros separados por espacios
            read(current_line, v_x);
            read(current_line, v_y);
            read(current_line, v_z);

            -- Sincronizar con flanco de bajada para cambiar datos
            wait until falling_edge(clk);
            
            -- Asignar a las entradas (conversión Integer -> STD_LOGIC_VECTOR)
            raw_x <= std_logic_vector(to_signed(v_x, 24));
            raw_y <= std_logic_vector(to_signed(v_y, 24));
            raw_z <= std_logic_vector(to_signed(v_z, 24));
            
            -- Generar pulso de validación
            sample_valid_in <= '1';
            wait for CLK_PERIOD; -- Un ciclo de reloj
            sample_valid_in <= '0';

            -- Esperar hasta la siguiente muestra (simula la frecuencia de muestreo)
            wait for SAMPLE_RATE_DELAY;
            
        end loop;

        -- Fin de la simulación
        wait for 1000 ns;
        assert false report "Fin de la simulación (Fin del archivo)" severity failure;
        wait;
    end process;

end Behavioral;