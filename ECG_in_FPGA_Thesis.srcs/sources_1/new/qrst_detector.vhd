library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity qrst_detector is
    Port (
        clk           : in  STD_LOGIC;
        reset         : in  STD_LOGIC;
        
        -- Entrada: Viene de "d_combined" del módulo anterior
        d_valid       : in  STD_LOGIC;
        d_energy      : in  SIGNED(23 downto 0); -- Siempre es positiva
        
        -- Salida
        qrs_detected  : out STD_LOGIC; -- Pulso de 1 ciclo cuando encuentra latido
        debug_thresh  : out STD_LOGIC_VECTOR(23 downto 0) -- Para ver el umbral (opcional)
    );
end qrst_detector;

architecture Behavioral of qrst_detector is
begin

end Behavioral;