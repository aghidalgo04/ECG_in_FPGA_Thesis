library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity wavelet_3d_transform is
Port (
        -- 1. CONTROL GENERAL
        clk             : in  STD_LOGIC; -- Reloj de 100 MHz
        reset           : in  STD_LOGIC;
        
        -- 2. ENTRADA DE DATOS (Vienen del módulo ADS1293)
        sample_valid_in : in  STD_LOGIC; -- El pulso de "Dato Nuevo"
        raw_x           : in  STD_LOGIC_VECTOR(23 downto 0);
        raw_y           : in  STD_LOGIC_VECTOR(23 downto 0);
        raw_z           : in  STD_LOGIC_VECTOR(23 downto 0);

        -- 3. SALIDAS DE SEÑAL LIMPIA (Para visualizar/CORDIC)
        -- La Wavelet elimina el ruido de alta frecuencia y la línea base
        wavelet_x         : out STD_LOGIC_VECTOR(23 downto 0);
        wavelet_y         : out STD_LOGIC_VECTOR(23 downto 0);
        wavelet_z         : out STD_LOGIC_VECTOR(23 downto 0);
        
        vector_ready    : out  STD_LOGIC;
        d_vector          : out  SIGNED(23 downto 0);
        y_vector         : out SIGNED(23 downto 0)
    );
end wavelet_3d_transform;

architecture Behavioral of wavelet_3d_transform is

    component wavelet_1dimension is
        port (
            clk           : in  STD_LOGIC;
            reset         : in  STD_LOGIC;
            sample_valid  : in  STD_LOGIC;
            raw_data      : in  STD_LOGIC_VECTOR(23 downto 0);
            y_wavelet     : out SIGNED(23 downto 0);
            d_wavelet     : out SIGNED(23 downto 0);
            wavelet_ready : out STD_LOGIC
        );
end component;
    
    signal yx, yy, yz : SIGNED(23 downto 0);
    signal dx, dy, dz : SIGNED(23 downto 0);
    signal rdyx, rdyy, rdyz : STD_LOGIC;
    signal abs_dx, abs_dy, abs_dz : signed(23 downto 0);

begin
    EJE_X: wavelet_1dimension
    port map (
        clk => clk,
        reset => reset,
        sample_valid => sample_valid_in,
        raw_data => raw_x,
        y_wavelet => yx,
        d_wavelet => dx,
        wavelet_ready => rdyx
    );
    
    EJE_Y: wavelet_1dimension
    port map (
        clk => clk,
        reset => reset,
        sample_valid => sample_valid_in,
        raw_data => raw_y,
        y_wavelet => yy,
        d_wavelet => dy,
        wavelet_ready => rdyy
    );
    
    EJE_Z: wavelet_1dimension
    port map (
        clk => clk,
        reset => reset,
        sample_valid => sample_valid_in,
        raw_data => raw_z,
        y_wavelet => yz,
        d_wavelet => dz,
        wavelet_ready => rdyz
    );
    
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                vector_ready <= '0';
                d_vector <= (others => '0');
                y_vector <= (others => '0');
            else
                vector_ready <= '0'; -- Por defecto '0'

                if rdyz = '1' then
                    -- Sumamos los absolutos (aseguramos no desbordamiento con resize si fuera necesario, 
                    -- pero 24 bits suele sobrar para ECG)
                    d_vector <= abs(dx) + abs(dy) + abs(dz);
                    y_vector <= abs(yx) + abs(yy) + abs(yz);
                    
                    vector_ready <= '1';
                end if;
            end if;
        end if;
    end process;
end Behavioral;
