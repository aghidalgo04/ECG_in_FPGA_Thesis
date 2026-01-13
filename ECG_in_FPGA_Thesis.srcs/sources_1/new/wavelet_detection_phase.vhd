library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity wavelet_detection_phase is
    Port (
        clk         : in STD_LOGIC;
        reset       : in STD_LOGIC;
        d_in_valid  : in STD_LOGIC;
        d_wavelet   : in SIGNED(23 downto 0); -- Viene de D4 o D3
        
        pulse_out   : out STD_LOGIC -- '1' un ciclo cuando detecta latido
    );
end wavelet_detection_phase;

architecture Behavioral of wavelet_detection_phase is
    -- Umbral (Ajustar según pruebas reales, ej: 1000 en decimal)
    constant THRESHOLD : signed(23 downto 0) := to_signed(50000, 24);
    
    -- Temporizador Refractario (250ms a 100MHz = 25,000,000 ciclos)
    constant REFRACTORY_TIME : integer := 25_000_000;
    signal timer_cnt : integer range 0 to REFRACTORY_TIME := 0;
    
    type state_type is (SEARCHING, BLOCKED);
    signal state : state_type := SEARCHING;

begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= SEARCHING;
                pulse_out <= '0';
                timer_cnt <= 0;
            else
                pulse_out <= '0'; -- Pulso por defecto apagado
                
                case state is
                    when SEARCHING =>
                        if d_in_valid = '1' then
                            -- Usamos valor absoluto o simplemente > Positivo
                            if d_wavelet > THRESHOLD then
                                pulse_out <= '1'; -- ¡LATIDO DETECTADO!
                                state <= BLOCKED;
                                timer_cnt <= 0;
                            end if;
                        end if;
                        
                    when BLOCKED =>
                        -- Esperamos 250ms sin mirar la señal (Periodo Refractario)
                        if timer_cnt < REFRACTORY_TIME then
                            timer_cnt <= timer_cnt + 1;
                        else
                            state <= SEARCHING; -- Volvemos a buscar
                        end if;
                end case;
            end if;
        end if;
    end process;
end Behavioral;
