library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity qrs_detector is
    Port (
        clk                 : in  STD_LOGIC;
        reset               : in  STD_LOGIC;
        
        -- Entradas
        d_valid             : in  STD_LOGIC;
        d_energy            : in  SIGNED(23 downto 0);
        
        -- Salidas
        qrs_detected        : out STD_LOGIC;
        current_mem_pmax    : out SIGNED(23 downto 0)
    );
end qrs_detector;

architecture Behavioral of qrs_detector is
-- === DEFINICIÓN DE ESTADOS ===
    type state_type is (
        ETAPA_1,    -- Buscar superar Salida_Memoria_Pmax
        ETAPA_2,    -- Actualizar Pmax y buscar "Cruce por cero" (P1)
        ETAPA_3     -- Espera de 40ms (Refractario)
   );
    signal state : state_type := ETAPA_1;

    -- === VARIABLES DE MEMORIA ADAPTATIVAS ===
    -- Pmax empieza en 0
    signal mem_pmax : signed(23 downto 0) := (others => '0');
    
    -- === TEMPORIZADORES ===
    constant TIME_40MS : integer := 4_000_000; 
    signal cnt_40ms    : integer range 0 to TIME_40MS := 0;

    -- 3 segundos para el "Watchdog"
    constant TIME_3S   : integer := 300_000_000;
    signal cnt_rr      : integer range 0 to TIME_3S := 0; -- Contador RR

    constant VIRTUAL_ZERO : signed(23 downto 0) := to_signed(100, 24); 

begin
    current_mem_pmax <= mem_pmax;

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

                -- === PROTECCIÓN WATCHDOG ===
                if cnt_rr < TIME_3S then
                    cnt_rr <= cnt_rr + 1;
                else
                    -- Timeout de 3s
                    cnt_rr <= 0;
                    mem_pmax <= shift_right(mem_pmax, 1); --/2
                    state <= ETAPA_1;
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
                        -- ETAPA 2: Actualización y Detección de P1
                        -- =========================================================
                        when ETAPA_2 =>
                            -- FUNCIÓN 1: Actualización Adaptativa
                            -- Calculo: 0.75 = 0.5 + 0.25 -> (x >> 1) + (x >> 2)
                            val_75_percent := shift_right(d_energy, 1) + shift_right(d_energy, 2);
                            
                            --Promedio de anterior y actual para cambiar umbral ante cambios leves
                            mem_pmax <= shift_right(mem_pmax + val_75_percent, 1); 
                            
                            if mem_pmax < 200 then
                                mem_pmax <= to_signed(200, 24);
                            end if;
                            
                            -- Detección de P1, esperar a que la señal vuelva a ruido base
                            if d_energy <= VIRTUAL_ZERO then
                                qrs_detected <= '1'; -- ¡LATIDO CONFIRMADO!
                                cnt_rr <= 0;
                                
                                state <= ETAPA_3;
                            end if;

                        -- =========================================================
                        -- ETAPA 3: Espera de 40 ms para no detectar mas de un latido
                        -- =========================================================
                        when ETAPA_3 =>
                            if cnt_40ms < TIME_40MS then
                                cnt_40ms <= cnt_40ms + 1;
                            else
                                cnt_40ms <= 0;
                                state <= ETAPA_1;
                            end if;
                    end case;
                end if;
            end if;
        end if;
    end process;
end Behavioral;