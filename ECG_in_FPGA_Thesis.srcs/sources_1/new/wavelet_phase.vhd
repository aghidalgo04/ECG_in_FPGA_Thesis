library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity wavelet_phase is
Port (
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        -- Entradas
        d_in_valid  : in  STD_LOGIC;
        d_in        : in  SIGNED(23 downto 0);
        -- Salidas
        d_out_valid : out STD_LOGIC;            -- Procesamiento síncrono 1:1
        y           : out SIGNED(23 downto 0); -- Salida Suavizada (B-Spline)
        d           : out SIGNED(23 downto 0)  -- Salida Detalle (Derivada)
    );
end wavelet_phase;

architecture Behavioral of wavelet_phase is
    
    -- Registro de 5 etapas para Spline Cúbico (nb = 5)
    signal r0, r1, r2, r3, r4 : signed(23 downto 0) := (others => '0');

begin
    process(clk)
        variable sum_h : signed(28 downto 0); -- Espacio para sumas con pesos
    begin
        if rising_edge(clk) then
            if reset = '1' then
                r0 <= (others => '0'); 
                r1 <= (others => '0'); 
                r2 <= (others => '0'); 
                r3 <= (others => '0');
                r4 <= (others => '0');
                y  <= (others => '0');
                d  <= (others => '0');
                d_out_valid <= '0';
            else
                d_out_valid <= '0';

                if d_in_valid = '1' then
                    -- Shift Register de 5 etapas
                    r4 <= r3;
                    r3 <= r2;
                    r2 <= r1;
                    r1 <= r0;
                    r0 <= d_in;

                    -- FILTRO PASO BAJO (Spline Cúbico: 1/16 * [1, 4, 6, 4, 1])
                    sum_h := resize(r0, 29) + 
                             shift_left(resize(r1, 29), 2) + -- r1 * 4
                             (shift_left(resize(r2, 29), 2) + shift_left(resize(r2, 29), 1)) + -- r2 * 6
                             shift_left(resize(r3, 29), 2) + -- r3 * 4
                             resize(r4, 29);
                    
                    -- Salida Aproximación: División entre 16 (shift 4)
                    y <= sum_h(27 downto 4); 
                    
                    -- Salida Detalle (Derivada para resaltar singularidades)
                    d <= r0 - r4; 

                    -- Genera salida válida en cada ciclo (Muestra a Muestra)
                    d_out_valid <= '1';
                end if;
            end if;
        end if;
    end process;
end Behavioral;