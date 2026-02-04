library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity wavelet_phase is
Port (
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        d_in_valid  : in  STD_LOGIC;
        d_in        : in  SIGNED(23 downto 0);
        d_out_valid : out STD_LOGIC;
        y           : out SIGNED(23 downto 0); 
        d           : out SIGNED(23 downto 0)  
    );
end wavelet_phase;

architecture Behavioral of wavelet_phase is
    
    signal r0, r1, r2, r3 : signed(23 downto 0) := (others => '0');
    signal decimate_toggle : std_logic := '0';

begin
    process(clk)
        variable sum_h : signed(26 downto 0); 
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- INICIALIZACIÓN CRÍTICA PARA EVITAR "U"
                r0 <= (others => '0'); 
                r1 <= (others => '0'); 
                r2 <= (others => '0'); 
                r3 <= (others => '0');
                y  <= (others => '0'); -- Añadido
                d  <= (others => '0'); -- Añadido
                decimate_toggle <= '0';
                d_out_valid <= '0';
            else
                d_out_valid <= '0';

                if d_in_valid = '1' then
                    -- Shift Register
                    r3 <= r2;
                    r2 <= r1;
                    r1 <= r0;
                    r0 <= d_in;

                    decimate_toggle <= not decimate_toggle;

                    if decimate_toggle = '1' then 
                        -- FILTRO PASO BAJO (Spline)
                        sum_h := resize(r0, 27) + 
                                 (shift_left(resize(r1, 27), 1) + resize(r1, 27)) + 
                                 (shift_left(resize(r2, 27), 1) + resize(r2, 27)) + 
                                 resize(r3, 27);
                        
                        y <= sum_h(26 downto 3); -- División /8
                        d <= r1 - r2;            -- Detalle Haar-like
                        d_out_valid <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;
end Behavioral;