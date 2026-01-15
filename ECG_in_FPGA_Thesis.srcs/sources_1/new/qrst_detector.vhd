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
-- === DEFINICIÓN DE ESTADOS SEGÚN TESIS ===
    type state_type is (
        ETAPA_1,    -- Buscar superar Salida_Memoria_Pmax
        ETAPA_2,    -- Actualizar Pmax y buscar "Cruce por cero" (P1)
        ETAPA_3     -- Espera de 40ms (Refractario)
   );
    signal state : state_type := ETAPA_1;

    -- === VARIABLES DE MEMORIA (ADAPTATIVAS) ===
    -- "Salida_Memoria_Pmax": Empieza en 0 como dice el texto
    signal mem_pmax : signed(23 downto 0) := (others => '0');
    
    -- === TEMPORIZADORES (Asumiendo reloj de 100 MHz) ===
    -- 40 ms para la etapa 5
    constant TIME_40MS : integer := 4_000_000; 
    signal cnt_40ms    : integer range 0 to TIME_40MS := 0;

    -- 3 segundos para el "Watchdog" (Protección ruido/gel seco)
    constant TIME_3S   : integer := 300_000_000;
    signal cnt_rr      : integer range 0 to TIME_3S := 0; -- Contador RR

    -- El "cruce por cero" (P1) es cuando la señal baja mucho.
    constant VIRTUAL_ZERO : signed(23 downto 0) := to_signed(100, 24); 

begin

    -- Salida para debug
    debug_thresh <= std_logic_vector(mem_pmax);

    process(clk)
        -- Variable 0.75 * Entrada
        variable val_75_percent : signed(23 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= ETAPA_1;
                mem_pmax <= (others => '0');
                qrs_detected <= '0';
                cnt_rr <= 0;
                cnt_40ms <= 0;
            else
                qrs_detected <= '0'; -- Pulso por defecto apagado

                -- === PROTECCIÓN WATCHDOG (Pág 70) ===
                -- "si transcurren más de 3 s... se dividan a la mitad hasta llegar a cero"
                if cnt_rr < TIME_3S then
                    cnt_rr <= cnt_rr + 1;
                else
                    -- Timeout de 3s: Reducir umbral
                    cnt_rr <= 0; -- Reinicia cuenta para volver a dividir en otros 3s si sigue fallando
                    mem_pmax <= mem_pmax / 2; -- División bit-shift
                    state <= ETAPA_1; -- Regresa a etapa 1 por seguridad
                end if;

                if d_valid = '1' then
                    
                    case state is
                        
                        -- =========================================================
                        -- ETAPA 1: Detección de Pmax
                        -- =========================================================
                        when ETAPA_1 =>
                            if d_energy > mem_pmax then
                                state <= ETAPA_2;
                            end if;

                        -- =========================================================
                        -- ETAPA 2: Actualización y Detección de P1 (Pág 69)
                        -- =========================================================
                        when ETAPA_2 =>
                            -- FUNCIÓN 1: Actualización Adaptativa (El 0.75)
                            -- Cálculo: x * 0.75 = (x * 3) / 4
                            val_75_percent := resize((d_energy * 3) / 4, 24);
                            
                            if val_75_percent > mem_pmax then
                                mem_pmax <= val_75_percent;
                            end if;

                            -- FUNCIÓN 2: Detección de P1 (Valor 0)
                            -- En magnitud vectorial, la señal vuelve a "casi cero" (ruido base)
                            if d_energy <= VIRTUAL_ZERO then
                                -- FUNCIÓN 3: Copiar contador y reiniciar
                                qrs_detected <= '1'; -- ¡LATIDO CONFIRMADO!
                                cnt_rr <= 0;         -- Reiniciar contador RR
                                
                                state <= ETAPA_3;
                            end if;

                        -- =========================================================
                        -- ETAPA 3
                        -- "realizar una espera de 40 ms"
                        -- =========================================================
                        when ETAPA_3 =>
                            if cnt_40ms < TIME_40MS then
                                cnt_40ms <= cnt_40ms + 1;
                            else
                                cnt_40ms <= 0;
                                state <= ETAPA_1; -- Volver a buscar
                            end if;
                    end case;
                end if;
            end if;
        end if;
    end process;
end Behavioral;