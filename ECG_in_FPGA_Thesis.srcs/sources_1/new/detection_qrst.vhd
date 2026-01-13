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

    -- ESTADOS
    type state_type is (
        IDLE_SEARCH,    -- Buscando que la energía suba
        TRACK_PEAK,     -- Subiendo la montaña
        REFRACTORY      -- Espera de seguridad (200ms)
    );
    signal state : state_type := IDLE_SEARCH;

    -- MEMORIA ADAPTATIVA (Aprendizaje)
    -- Empezamos con 2000. Si tu ECG es muy débil, bajará solo.
    signal mem_peak_max : signed(23 downto 0) := to_signed(2000, 24); 
    
    -- Pico que estamos midiendo ahora mismo
    signal current_peak : signed(23 downto 0) := (others => '0');

    -- TIMERS (Asumiendo reloj de 100 MHz, ajusta si usas otro)
    constant T_REFRACTORY : integer := 20_000_000; -- 200 ms
    constant T_DECAY      : integer := 300_000_000; -- 3 segundos
    
    signal timer_ref   : integer range 0 to T_REFRACTORY := 0;
    signal timer_decay : integer range 0 to T_DECAY := 0;

begin
    
    debug_thresh <= std_logic_vector(mem_peak_max);

    process(clk)
        variable threshold : signed(23 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= IDLE_SEARCH;
                mem_peak_max <= to_signed(2000, 24);
                qrs_detected <= '0';
                timer_decay <= 0;
            else
                qrs_detected <= '0'; -- Pulso por defecto apagado
                
                -- EL UMBRAL ES DINÁMICO: 50% del máximo histórico
                threshold := mem_peak_max / 2;

                -- === LOGICA DE DECAIMIENTO (Si se seca el gel) ===
                if timer_decay < T_DECAY then
                    timer_decay <= timer_decay + 1;
                else
                    -- Pasaron 3 seg sin latidos: Bajamos la exigencia
                    timer_decay <= 0;
                    mem_peak_max <= mem_peak_max / 2; 
                    -- Límite mínimo para no detectar ruido de fondo
                    if mem_peak_max < 100 then mem_peak_max <= to_signed(100, 24); end if;
                end if;

                -- === MÁQUINA DE ESTADOS ===
                if d_valid = '1' then
                    case state is
                        
                        -- 1. BUSCANDO EL INICIO DEL LATIDO
                        when IDLE_SEARCH =>
                            if d_energy > threshold then
                                state <= TRACK_PEAK;
                                current_peak <= d_energy; -- Guardamos el valor actual
                            end if;

                        -- 2. SIGUIENDO LA MONTAÑA
                        when TRACK_PEAK =>
                            -- A. Si sigue subiendo, actualizamos el pico actual
                            if d_energy > current_peak then
                                current_peak <= d_energy;
                            
                            -- B. Si baja significativamente (cayó al 50% del pico que acabamos de ver)
                            -- Significa que ya pasamos la cima y estamos bajando.
                            elsif d_energy < (current_peak / 2) then
                                -- ¡LATIDO CONFIRMADO!
                                qrs_detected <= '1';
                                state <= REFRACTORY;
                                timer_ref <= 0;
                                timer_decay <= 0; -- Reseteamos el contador de "pánico"
                                
                                -- APRENDIZAJE: Actualizamos la memoria
                                -- Nuevo Promedio = (Viejo + Nuevo) / 2
                                mem_peak_max <= (mem_peak_max + current_peak) / 2;
                            end if;

                        -- 3. PERIODO REFRACTARIO (Ciego por 200ms)
                        when REFRACTORY =>
                            if timer_ref < T_REFRACTORY then
                                timer_ref <= timer_ref + 1;
                            else
                                state <= IDLE_SEARCH; -- Volvemos a escuchar
                            end if;
                            
                    end case;
                end if;
            end if;
        end if;
    end process;
end Behavioral;