library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity wavelet_transform is
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
        clean_x         : out STD_LOGIC_VECTOR(23 downto 0);
        clean_y         : out STD_LOGIC_VECTOR(23 downto 0);
        clean_z         : out STD_LOGIC_VECTOR(23 downto 0);
        clean_valid     : out STD_LOGIC; -- Pulso cuando el dato limpio está listo

        -- 4. SALIDAS DE ANÁLISIS (Resultados Médicos)
        qrs_detected    : out STD_LOGIC; -- Un pulso '1' cuando detectas un pico R
        heart_rate      : out STD_LOGIC_VECTOR(8 downto 0) -- PPM calculados (ej. 60, 120)
    );
end wavelet_transform;

architecture Behavioral of wavelet_transform is

begin


end Behavioral;
