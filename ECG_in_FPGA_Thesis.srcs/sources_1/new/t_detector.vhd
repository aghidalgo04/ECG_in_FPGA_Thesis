library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity t_detector is
    Port (
        clk             : in  STD_LOGIC;
        reset           : in  STD_LOGIC;
        
        -- Entradas de Datos
        d_valid         : in  STD_LOGIC;
        d_energy        : in  SIGNED(23 downto 0); -- Señal de entrada
        
        -- Entradas de Sincronización (Vienen del QRS Detector)
        qrs_trigger     : in  STD_LOGIC;           -- "Start" cuando acaba el QRS
        rr_interval     : in  INTEGER;             -- Valor del último intervalo RR
        qrs_mem_pmax    : in  SIGNED(23 downto 0); -- Memoria de amplitud del QRS (para Etapa 10)

        -- Salidas
        t_detected      : out STD_LOGIC;           -- Pulso fin de onda T
        debug_t_thresh  : out STD_LOGIC_VECTOR(23 downto 0)
    );
end t_detector;

architecture Behavioral of t_detector is

    -- === ESTADOS ===
    type state_type is (
        IDLE,               -- Esperando disparo del QRS
        ETAPA_6_VENTANA,    -- Definiendo ventana y buscando inicio (Pmax_T)
        ETAPA_7_SEGUIMIENTO,-- Actualizando memoria y buscando fin (Cruce Cero)
        ETAPA_10_CHECK      -- Comparación de seguridad contra el QRS
    );
    signal state : state_type := IDLE;

    -- === MEMORIA ADAPTATIVA ONDA T ===
    signal mem_pmax_t : signed(23 downto 0) := (others => '0');

    -- === TEMPORIZADORES (Reloj 100 MHz) ===
    -- Umbrales de decisión según texto
    constant TIME_700MS : integer := 70_000_000; 
    
    -- Duraciones de ventana
    constant WIN_100MS  : integer := 10_000_000;
    constant WIN_140MS  : integer := 14_000_000;
    
    -- Contador para la ventana de búsqueda activa
    signal cnt_window   : integer range 0 to 15_000_000 := 0;
    signal limit_window : integer range 0 to 15_000_000 := 0;

    -- Umbral de cero virtual para fin de onda
    constant VIRTUAL_ZERO : signed(23 downto 0) := to_signed(100, 24);

begin

    debug_t_thresh <= std_logic_vector(mem_pmax_t);

    process(clk)
        -- Variables auxiliares
        variable val_75_percent : signed(23 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= IDLE;
                mem_pmax_t <= (others => '0');
                t_detected <= '0';
                cnt_window <= 0;
                limit_window <= 0;
            else
                t_detected <= '0'; -- Pulso por defecto apagado

                -- Máquina de Estados
                case state is
                    
                    -- =========================================================
                    -- ESTADO DE ESPERA
                    -- =========================================================
                    when IDLE =>
                        -- Esperamos a que el detector QRS nos diga que ha terminado
                        if qrs_trigger = '1' then
                            state <= ETAPA_6_VENTANA;
                            cnt_window <= 0;
                            
                            -- FUNCIÓN 1 ETAPA 6: Definir ventana según RR
                            if rr_interval > TIME_700MS then
                                limit_window <= WIN_100MS;
                            else
                                limit_window <= WIN_140MS;
                            end if;
                        end if;

                    -- =========================================================
                    -- ETAPA 6: Búsqueda dentro de la ventana
                    -- =========================================================
                    when ETAPA_6_VENTANA =>
                        if d_valid = '1' then
                            -- Control de tiempo de ventana
                            if cnt_window < limit_window then
                                cnt_window <= cnt_window + 1;
                                
                                -- FUNCIÓN 2 ETAPA 6: Detección Pmax_T
                                -- Si encontramos energía suficiente, pasamos a seguimiento
                                if d_energy > mem_pmax_t then
                                    state <= ETAPA_7_SEGUIMIENTO;
                                end if;
                            else
                                -- Se acabó el tiempo sin encontrar nada
                                state <= IDLE;
                            end if;
                        end if;

                    -- =========================================================
                    -- ETAPA 7 (y 9): Actualización y Búsqueda del Final (P1/P2)
                    -- =========================================================
                    when ETAPA_7_SEGUIMIENTO =>
                        if d_valid = '1' then
                            -- FUNCIÓN 1: Actualización Adaptativa (0.75)
                            -- Cálculo: 0.75 = 0.5 + 0.25 -> (x >> 1) + (x >> 2)
                            val_75_percent := shift_right(d_energy, 1) + shift_right(d_energy, 2);
                            
                            -- Promedio suavizado para actualizar memoria T
                            mem_pmax_t <= shift_right(mem_pmax_t + val_75_percent, 1);
                            
                            -- Límite de seguridad inferior
                            if mem_pmax_t < 100 then
                                mem_pmax_t <= to_signed(100, 24);
                            end if;

                            -- FUNCIÓN 2: Detección de vuelta a cero (Fin de Onda T)
                            if d_energy <= VIRTUAL_ZERO then
                                t_detected <= '1'; -- ¡ONDA T COMPLETADA!
                                state <= ETAPA_10_CHECK;
                            end if;
                        end if;

                    -- =========================================================
                    -- ETAPA 10: Comparación de Seguridad con QRS
                    -- Evita confundir una T grande con un QRS o viceversa
                    -- =========================================================
                    when ETAPA_10_CHECK =>
                        -- "Si valor de Memoria_T es mayor a Memoria_QRS..."
                        if mem_pmax_t > qrs_mem_pmax then
                            -- "...entonces se realiza una división por 2"
                            mem_pmax_t <= shift_right(mem_pmax_t, 1);
                        end if;
                        
                        -- Volvemos a esperar al siguiente latido
                        state <= IDLE;

                end case;
            end if;
        end if;
    end process;

end Behavioral;