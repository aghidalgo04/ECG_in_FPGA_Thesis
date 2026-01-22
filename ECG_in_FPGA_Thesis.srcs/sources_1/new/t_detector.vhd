library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity t_detector is
    Port (
        clk             : in  STD_LOGIC;
        reset           : in  STD_LOGIC;
        
        -- Entradas de Wavelet Escala 8
        d_valid         : in  STD_LOGIC;
        d_wavelet       : in  SIGNED(23 downto 0);
        
        -- QRS_DETECTOR
        start_trigger   : in  STD_LOGIC;
        rr_interval     : in  SIGNED(23 downto 0); -- Intervalo RR del QRS anterior
        
        qrs_mem_pmax    : in  SIGNED(23 downto 0);
        qrs_mem_pmin    : in  SIGNED(23 downto 0);

        -- Salidas
        t_detected      : out STD_LOGIC;
        
        -- Debug
        current_mem_t_pmax : out SIGNED(23 downto 0);
        current_mem_t_pmin : out SIGNED(23 downto 0)
    );
end t_detector;

architecture Behavioral of t_detector is

    type state_type is (
        ETAPA_1,    --  Ventana y Definir Polaridad T
        ETAPA_2,    --  Actualizar Memoria y Buscar Cruce P1
        ETAPA_3,    --  Buscar Pico 2 (Bifásica)
        ETAPA_4,    --  Actualizar Memoria y Buscar Cruce P2
        ETAPA_5     --  Comparación de Seguridad con QRS
    );
    signal state : state_type := IDLE;

    -- Variables de Memoria para Onda T
    signal mem_pmax_t : signed(23 downto 0) := (others => '0');
    signal mem_pmin_t : signed(23 downto 0) := (others => '0');
    
    -- Polaridad de la Onda T (0: Positiva | 1: Negativa)
    signal t_n : std_logic := '0';

    -- Temporizadores y Ventanas
    signal cnt_window   : integer := 0;
    signal limit_window : integer := 0;

    -- Constantes de tiempo (Asumiendo 100 MHz, ajustar según tu reloj)
    -- 700 ms = 70_000_000 ciclos
    constant TIME_700MS : signed(23 downto 0) := to_signed(700, 24); -- Ajustar escala si RR no está en ms reales
    
    -- Ventanas de búsqueda (en ciclos de reloj 100MHz)
    constant WIN_100MS  : integer := 10_000_000; 
    constant WIN_140MS  : integer := 14_000_000;
    
    -- Umbral de cero
    constant VIRTUAL_ZERO : signed(23 downto 0) := to_signed(50, 24);

begin
    -- Debug
    current_mem_t_pmax <= mem_pmax_t;
    current_mem_t_pmin <= mem_pmin_t;

    process(clk)
        variable val_75_pmax : signed(23 downto 0);
        variable val_75_pmin : signed(23 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= ETAPA_1;
                mem_pmax_t <= (others => '0');
                mem_pmin_t <= (others => '0');
                t_detected <= '0';
                cnt_window <= 0;
                t_n <= '0';
            else
                t_detected <= '0';
                
                

                if d_valid = '1' then
                    
                    case state is
                        -- =====================================================
                        -- ETAPA 1: Definir Ventana y Polaridad
                        -- =====================================================
                        when ETAPA_1 =>
                            if start_trigger = '1' then
                                if rr_interval > TIME_700MS then -- Comparación conceptual
                                    limit_window <= WIN_100MS;
                                    cnt_window <= cnt_window + 1;
                                else
                                    limit_window <= WIN_140MS;
                                    cnt_window <= cnt_window + 1;
                                end if;
                            end if;
                            
                            if cnt_window <= limit_window AND cnt_window > 0 then
                                cnt_window <= cnt_window + 1;
                                
                                if d_wavelet > mem_pmax_t then
                                    t_n <= '0'; -- Positiva
                                    state <= ETAPA_2; -- Pasamos a seguimiento
                                elsif d_wavelet < mem_pmin_t then
                                    t_n <= '1'; -- Negativa
                                    state <= ETAPA_2;
                                end if; 
                            end if;

                        -- =====================================================
                        -- ETAPA 2 (Texto: ETAPA 7)
                        -- Actualizar Memoria y Buscar Cruce P1
                        -- =====================================================
                        when ETAPA_2 =>
                            
                            -- Función 1: Actualizar con la regla del 0.75
                            if t_n = '0' then -- T Positiva
                                val_75_pmax := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                -- "Si valor * 0.75 es mayor... se actualizan"
                                if val_75_pmax > mem_pmax_t then
                                    mem_pmax_t <= val_75_pmax;
                                end if;
                                
                            else -- T Negativa
                                val_75_pmin := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmin < mem_pmin_t then -- Más negativo
                                    mem_pmin_t <= val_75_pmin;
                                end if;
                            end if;

                            -- Función 2: Detección P1_T (Cruce a cero)
                            if abs(d_wavelet) <= VIRTUAL_ZERO then
                                state <= ETAPA_3;
                            end if;

                        -- =====================================================
                        -- ETAPA 3 (Texto: ETAPA 8)
                        -- Buscar Pico 2 (Bifásica) o Rebote
                        -- =====================================================
                        when ETAPA_3 =>
                            -- "Si T_N es cero detecta Pmax... si es uno detecta Pmin"
                            -- Aquí buscamos el rebote contrario a la polaridad inicial
                            if t_n = '0' then 
                                -- Venimos de positiva, si es bifásica podría bajar a negativa
                                if d_wavelet < mem_pmin_t then
                                    state <= ETAPA_4;
                                end if;
                            else
                                if d_wavelet > mem_pmax_t then
                                    state <= ETAPA_4;
                                end if;
                            end if;
                            
                            -- NOTA: Si la onda es Monofásica (no tiene rebote), 
                            -- debería haber un timeout aquí para terminar. 
                            -- El texto asume que pasará a la etapa 9 (4) eventualmente.
                            -- Para robustez, podrías añadir un contador de salida si tarda mucho.

                        -- =====================================================
                        -- ETAPA 4 (Texto: ETAPA 9)
                        -- Actualizar Rebote y Fin de Onda
                        -- =====================================================
                        when ETAPA_4 =>
                            -- Función 1: Actualización (Cruzada por ser rebote)
                            if t_n = '0' then -- Era positiva, ahora estamos en la parte negativa
                                val_75_pmin := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmin < mem_pmin_t then
                                    mem_pmin_t <= val_75_pmin;
                                end if;
                            else -- Era negativa, ahora estamos en la parte positiva
                                val_75_pmax := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmax > mem_pmax_t then
                                    mem_pmax_t <= val_75_pmax;
                                end if;
                            end if;

                            -- Función 2: Detección P2_T (Cruce cero final)
                            if abs(d_wavelet) <= VIRTUAL_ZERO then
                                -- Función 3: Copiar tiempo (no implementado aquí, se asume externo)
                                state <= ETAPA_5; -- Ir a verificación final
                            end if;

                        -- =====================================================
                        -- ETAPA 5 (Texto: ETAPA 10)
                        -- Comparación de Seguridad con QRS
                        -- =====================================================
                        when ETAPA_5 =>
                            -- "Si Salida_Memoria_Pmax_T > Salida_Memoria_Pmax [del QRS]..."
                            if mem_pmax_t > qrs_mem_pmax then
                                -- "...división por 2"
                                mem_pmax_t <= shift_right(mem_pmax_t, 1);
                            end if;
                            
                            -- Lo mismo con los mínimos
                            if mem_pmin_t < qrs_mem_pmin then -- (Más negativo es "menor" en signed?) 
                                -- Cuidado: si pmin es -1000 y qrs es -500. -1000 < -500.
                                -- Si la T es más grande (más negativa) que el QRS, reducimos.
                                mem_pmin_t <= shift_right(mem_pmin_t, 1);
                            end if;
                            
                            t_detected <= '1'; -- Fin del proceso
                            state <= IDLE;

                    end case;
                end if;
            end if;
        end if;
    end process;
end Behavioral;