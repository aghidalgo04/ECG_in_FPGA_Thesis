library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity wavelet_phase is
    Generic (
        m : integer := 1  -- Factor de expansión (distancia entre muestras)
    );
    Port (
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        -- Entradas
        d_in_valid  : in  STD_LOGIC;
        d_in        : in  SIGNED(23 downto 0);
        -- Salidas
        d_out_valid : out STD_LOGIC;
        y           : out SIGNED(23 downto 0); 
        d           : out SIGNED(23 downto 0)  
    );
end wavelet_phase;

architecture Behavioral of wavelet_phase is
    -- Buffer de 33 muestras para soportar escala 8 (4 * 8 = 32)
    type delay_line is array (0 to 32) of signed(23 downto 0);
    signal regs : delay_line := (others => (others => '0'));

begin
    process(clk)
        variable sum_h : signed(28 downto 0); 
    begin
        if rising_edge(clk) then
            if reset = '1' then
                regs <= (others => (others => '0'));
                y  <= (others => '0');
                d  <= (others => '0');
                d_out_valid <= '0';
            else
                d_out_valid <= '0';

                if d_in_valid = '1' then
                    -- Desplazamiento del historial (Mantenemos frecuencia 1:1)
                    regs(1 to 32) <= regs(0 to 31);
                    regs(0) <= d_in;

                    -- FILTRO B-SPLINE CÚBICO (Algoritmo à trous)
                    -- Coeficientes [1, 4, 6, 4, 1] aplicados a muestras con distancia m
                    sum_h := resize(regs(0), 29) + 
                             shift_left(resize(regs(1*m), 29), 2) + -- x4
                             (shift_left(resize(regs(2*m), 29), 2) + shift_left(resize(regs(2*m), 29), 1)) + -- x6
                             shift_left(resize(regs(3*m), 29), 2) + -- x4
                             resize(regs(4*m), 29);
                    
                    -- Aproximación (Paso Bajo) dividida por 16
                    y <= sum_h(27 downto 4); 
                    
                    -- Detalle (Paso Banda) calculado como la diferencia a escala m
                    d <= regs(0) - regs(4*m); 

                    d_out_valid <= '1';
                end if;
            end if;
        end if;
    end process;
end Behavioral;