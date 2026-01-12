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
    process(clk)
        -- Variables temporales para la matemática completa (evitar overflow antes de dividir)
        variable sum_h : signed(26 downto 0); -- 3 bits extra para la suma
        variable diff_g : signed(23 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                r0 <= (others => '0'); r1 <= (others => '0'); 
                r2 <= (others => '0'); r3 <= (others => '0');
                decimate_toggle <= '0';
                d_out_valid <= '0';
            else
                d_out_valid <= '0'; -- Por defecto '0'

                if d_in_valid = '1' then
                    -- 1. Mover el Shift Register (Entra dato nuevo por r0)
                    r3 <= r2;
                    r2 <= r1;
                    r1 <= r0;
                    r0 <= d_in;

                    -- 2. Control de Diezmado (Solo procesamos 1 de cada 2 muestras)
                    decimate_toggle <= not decimate_toggle;

                    if decimate_toggle = '1' then -- Muestra IMPAR (Procesamos)
                        
                        -- === FILTRO PASO BAJO (Spline: 1/8 * [1, 3, 3, 1]) ===
                        -- Multiplicar por 3 es lo mismo que (x*2) + x. Es decir: (x << 1) + x
                        sum_h := resize(r0, 27) + 
                                 resize((r1 & '0') + r1, 27) + -- r1 * 3
                                 resize((r2 & '0') + r2, 27) + -- r2 * 3
                                 resize(r3, 27);
                        
                        -- Desplazar 3 bits a la derecha(/8)
                        y <= sum_h(26 downto 3); 
                        d <= r1 - r2;
                        d_out_valid <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;
end Behavioral;