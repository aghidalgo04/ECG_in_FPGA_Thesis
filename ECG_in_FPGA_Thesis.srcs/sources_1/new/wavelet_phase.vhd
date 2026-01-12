library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity wavelet_phase is
Port (
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        -- Entrada
        d_in_valid  : in  STD_LOGIC;
        d_in        : in  SIGNED(23 downto 0);
        -- Salidas
        d_out_valid : out STD_LOGIC;            -- Saldrá a la mitad de frecuencia
        y           : out SIGNED(23 downto 0); -- Salida Suavizada (Pasa al siguiente nivel)
        d           : out SIGNED(23 downto 0)  -- Salida Detalle (Se analiza o se tira)
    );
end wavelet_phase;

architecture Behavioral of wavelet_phase is
    
    signal r0, r1, r2, r3 : signed(23 downto 0) := (others => '0');
    signal decimate_toggle : std_logic := '0'; -- Para alternar (quedarse 1, tirar 1)

begin
    (r0, r1, r2, r3) <= (others => (others => '0')) WHEN clk = '1' AND CLK'EVENT AND reset = '1';
    
end Behavioral;