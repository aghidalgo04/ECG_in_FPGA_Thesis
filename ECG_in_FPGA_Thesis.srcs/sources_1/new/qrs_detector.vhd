library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity qrs_detector is
    Port (
        clk                 : in  STD_LOGIC;
        reset               : in  STD_LOGIC;
        
        -- Entradas
        d_valid             : in  STD_LOGIC;
        d_wavelet           : in  SIGNED(23 downto 0); -- AHORA CON SIGNO (+/-)
        
        -- Salidas
        qrs_detected        : out STD_LOGIC; -- Pulso de 1 ciclo
        polarity            : out STD_LOGIC; -- 0: Positivo, 1: Negativo (QRS_N)
        
        -- Debug
        current_mem_pmax    : out SIGNED(23 downto 0);
        current_mem_pmin    : out SIGNED(23 downto 0)
    );
end qrs_detector;

architecture Behavioral of qrs_detector is

    -- === DEFINICIÓN DE ESTADOS (5 ETAPAS) ===
    type state_type is (
        ETAPA_1,    -- Detectar Primer Pico (Pmax o Pmin)
        ETAPA_2,    -- Actualizar Pico 1 y Buscar Cruce Cero (P1)
        ETAPA_3,    -- Detectar Segundo Pico (Rebote)
        ETAPA_4,    -- Actualizar Pico 2 y Buscar Cruce Cero (P2)
        ETAPA_5     -- Espera de 40ms (Refractario)
    );
    signal state : state_type := ETAPA_1;

    -- === VARIABLES DE MEMORIA ADAPTATIVAS ===
    signal mem_pmax : signed(23 downto 0) := (others => '0');
    signal mem_pmin : signed(23 downto 0) := (others => '0');
    
    -- "QRS_N": Variable de estado de polaridad
    -- 0: QRS Positivo (Primero sube)
    -- 1: QRS Negativo (Primero baja)
    signal qrs_n : std_logic := '0';

    -- === TEMPORIZADORES ===
    constant TIME_40MS : integer := 4_000_000; 
    signal cnt_40ms    : integer range 0 to TIME_40MS := 0;

    -- Watchdog 3 segundos
    constant TIME_3S   : integer := 300_000_000;
    signal cnt_rr      : integer range 0 to TIME_3S := 0; 

    -- Umbral de cero virtual para cruces
    constant VIRTUAL_ZERO_POS : signed(23 downto 0) := to_signed(50, 24); 
    constant VIRTUAL_ZERO_NEG : signed(23 downto 0) := to_signed(-50, 24);

begin
    -- Asignaciones continuas de salida
    current_mem_pmax <= mem_pmax;
    current_mem_pmin <= mem_pmin;
    polarity <= qrs_n;

    process(clk)
        -- Variables auxiliares para cálculos
        variable val_75_pmax : signed(23 downto 0);
        variable val_75_pmin : signed(23 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= ETAPA_1;
                mem_pmax <= (others => '0');
                mem_pmin <= (others => '0');
                qrs_detected <= '0';
                cnt_rr <= 0;
                cnt_40ms <= 0;
                qrs_n <= '0';
            else
                qrs_detected <= '0'; 

                -- === PROTECCIÓN WATCHDOG (3s) ===
                -- "si transcurren más de 3 s... se dividan a la mitad"
                if cnt_rr < TIME_3S then
                    cnt_rr <= cnt_rr + 1;
                else
                    cnt_rr <= 0;
                    mem_pmax <= shift_right(mem_pmax, 1); -- Division / 2
                    mem_pmin <= shift_right(mem_pmin, 1); -- Division / 2 (mantiene signo)
                    state <= ETAPA_1; 
                end if;

                if d_valid = '1' then
                    
                    -- Pre-cálculo de umbrales adaptativos (0.75 * Entrada)
                    -- (x >> 1) + (x >> 2)
                    -- Nota: Esto se calcula sobre la ENTRADA actual para comparar con memoria
                    -- O según el texto: "valor recibido... multiplicado por 0.75 es mayor que Salida_Memoria..."
                    -- Vamos a interpretar que se refiere a actualizar el umbral suavizándolo.
                    
                    case state is
                        
                        -- =========================================================
                        -- ETAPA 1: Detección del Primer Pico (Inicio QRS)
                        -- =========================================================
                        when ETAPA_1 =>
                            -- Caso A: Posible QRS Negativo (Señal baja mucho)
                            if d_wavelet < mem_pmin then 
                                qrs_n <= '1';
                                state <= ETAPA_2;
                                
                            -- Caso B: Posible QRS Positivo (Señal sube mucho)
                            elsif d_wavelet > mem_pmax then
                                qrs_n <= '0';
                                state <= ETAPA_2;
                            end if;

                        -- =========================================================
                        -- ETAPA 2: Actualizar Pmax/Pmin y Buscar Cruce P1
                        -- =========================================================
                        when ETAPA_2 =>
                            
                            -- FUNCIÓN 1: Actualización Adaptativa
                            -- Si la señal sigue creciendo (o bajando), actualizamos el pico
                            if qrs_n = '0' then -- Caso Positivo
                                -- "Si valor * 0.75 > Memoria Pmax..." (Texto confuso, solemos actualizar si Entrada > Memoria)
                                -- Implementación estándar de Peak Hold:
                                if d_wavelet > mem_pmax then
                                    mem_pmax <= d_wavelet;
                                else
                                    -- Adaptación suave hacia abajo (promedio) si no supera
                                    -- val_75 = d_wavelet * 0.75
                                    val_75_pmax := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                    if val_75_pmax > mem_pmax then
                                         mem_pmax <= val_75_pmax;
                                    end if;
                                end if;
                                
                            else -- Caso Negativo (QRS_N = 1)
                                if d_wavelet < mem_pmin then
                                    mem_pmin <= d_wavelet;
                                else
                                    val_75_pmin := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                    if val_75_pmin < mem_pmin then -- Ojo: comparamos negativos (más negativo es menor)
                                         mem_pmin <= val_75_pmin;
                                    end if;
                                end if;
                            end if;

                            -- FUNCIÓN 2: Detección de P1 (Cruce por cero)
                            -- Buscamos que la señal vuelva a 0
                            if (abs(d_wavelet) <= 50) then -- Zona segura cerca de cero
                                -- FUNCIÓN 3: Reiniciar contador RR (Inicio de detección firme)
                                cnt_rr <= 0; 
                                state <= ETAPA_3;
                            end if;

                        -- =========================================================
                        -- ETAPA 3: Detectar Segundo Pico (Rebote Bifásico)
                        -- =========================================================
                        when ETAPA_3 =>
                            -- Si veníamos de positivo, ahora esperamos un rebote negativo (y viceversa)
                            if qrs_n = '0' then -- QRS Positivo -> Esperamos rebote hacia Pmin
                                if d_wavelet < mem_pmin then
                                    state <= ETAPA_4;
                                end if;
                            else -- QRS Negativo -> Esperamos rebote hacia Pmax
                                if d_wavelet > mem_pmax then
                                    state <= ETAPA_4;
                                end if;
                            end if;
                            
                            -- Timeout de seguridad: Si no hay rebote en X tiempo, volver (opcional, no está en texto explícito pero recomendable)
                            -- Aquí seguimos el texto estricto: espera infinita hasta que ocurra.

                        -- =========================================================
                        -- ETAPA 4: Actualizar Pico 2 y Buscar Cruce P2 (Final QRS)
                        -- =========================================================
                        when ETAPA_4 =>
                            -- Función 1: Actualización del segundo pico
                            if qrs_n = '0' then -- Estamos en el rebote negativo
                                if d_wavelet < mem_pmin then
                                    mem_pmin <= d_wavelet;
                                end if;
                            else -- Estamos en el rebote positivo
                                if d_wavelet > mem_pmax then
                                    mem_pmax <= d_wavelet;
                                end if;
                            end if;

                            -- Función 2: Detección de P2 (Segundo Cruce por cero)
                            if (abs(d_wavelet) <= 50) then
                                qrs_detected <= '1'; -- ¡LATIDO COMPLETADO!
                                state <= ETAPA_5;
                            end if;

                        -- =========================================================
                        -- ETAPA 5: Refractario 40 ms
                        -- =========================================================
                        when ETAPA_5 =>
                            if cnt_40ms < TIME_40MS then
                                cnt_40ms <= cnt_40ms + 1;
                            else
                                cnt_40ms <= 0;
                                state <= ETAPA_1;
                            end if;

                    end case;
                end if; -- d_valid
            end if; -- reset
        end if; -- clk
    end process;
end Behavioral;