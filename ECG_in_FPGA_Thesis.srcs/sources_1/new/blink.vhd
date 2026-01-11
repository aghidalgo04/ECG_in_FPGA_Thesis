library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity blink is
    Port ( 
        clk : in STD_LOGIC;
        sw1  : in STD_LOGIC;
        led0 : out STD_LOGIC;
        led1 : out STD_LOGIC
    );
end blink;

architecture Behavioral of blink is
    constant MAX_COUNT : integer := 100000000;
    
    -- SEÑALES INTERNAS
    signal counter : integer := 0;
    signal led_0_state : std_logic := '0';

begin

    -- PROCESO 1: El parpadeo (Lógica Secuencial)
    -- Este proceso se despierta cada vez que el reloj sube (Rising Edge)
    blink_proc: process(clk)
    begin
        if rising_edge(clk) then
            if counter = MAX_COUNT then
                counter <= 0;           -- Reiniciar contador
                led_0_state <= not led_0_state; -- Invertir estado del LED
            else
                counter <= counter + 1; -- Seguir contando
            end if;
        end if;
    end process;

    -- ASIGNACIÓN DE SALIDAS
    
    -- Funcionalidad 1: El LED 0 parpadea con la señal interna
    led0 <= led_0_state;

    -- Funcionalidad 2: El LED 1 copia directamente el estado del Switch 1 (Lógica Combinacional)
    -- Esto es instantáneo, no depende del reloj.
    led1 <= sw1;

end Behavioral;