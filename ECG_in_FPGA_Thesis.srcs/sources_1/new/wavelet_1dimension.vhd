library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity wavelet_1dimension is
    Port (
        clk           : in  STD_LOGIC;
        reset         : in  STD_LOGIC;
        -- Entrada del Sensor
        sample_valid  : in  STD_LOGIC;
        raw_data      : in  STD_LOGIC_VECTOR(23 downto 0);
        
        -- Salidas Finales
        clean_ecg     : out STD_LOGIC_VECTOR(23 downto 0); -- Para ver en gráfica (Y4)
        beat_detected : out STD_LOGIC                      -- LED o contador
    );
end wavelet_1dimension;

architecture Behavioral of wavelet_1dimension is

begin
 
end Behavioral;