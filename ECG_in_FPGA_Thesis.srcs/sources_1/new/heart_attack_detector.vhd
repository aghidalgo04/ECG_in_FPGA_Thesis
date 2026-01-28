library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity heart_attack_detector is
    Port (
        clk             : in  STD_LOGIC;
        reset           : in  STD_LOGIC;
        
        -- Entradas (Se recomienda conectar aquí la Wavelet Escala 8 o la señal cruda filtrada)
        d_valid         : in  STD_LOGIC;
        d_wavelet       : in  SIGNED(23 downto 0);
        
        -- Salidas
        infarct_detected: out STD_LOGIC; -- '1' si se detecta un patrón de infarto (Elevación ST)
        severity_level  : out STD_LOGIC; -- '1' si la amplitud es crítica (Infarto masivo)
        
        -- Debug / Visualización de umbrales internos
        current_st_elev : out SIGNED(23 downto 0);
        current_st_depr : out SIGNED(23 downto 0)
    );
end heart_attack_detector;

architecture Behavioral of heart_attack_detector is

    -- === DEFINICIÓN DE ESTADOS (Misma estructura de 5 etapas) ===
    type state_type is (
        ETAPA_1,    -- Monitorizar desviación de línea base (Inicio ST)
        ETAPA_2,    -- Rastrear Amplitud Máxima de la Lesión
        ETAPA_3,    -- Buscar Retorno o Rebote (Persistencia)
        ETAPA_4,    -- Confirmar Fin del Evento Patológico
        ETAPA_5     -- Periodo Refractario de Seguridad
    );
    signal state : state_type := ETAPA_1;

    -- === VARIABLES DE MEMORIA ADAPTATIVAS ===
    -- En este contexto, Pmax es "Elevación ST" y Pmin es "Depresión ST"
    signal mem_st_max : signed(23 downto 0) := (others => '0');
    signal mem_st_min : signed(23 downto 0) := (others => '0');
    
    -- Tipo de evento: '0' Elevación (Supradesnivel), '1' Depresión (Infradesnivel)
    signal lesion_type : std_logic := '0';

    -- === TEMPORIZADORES ===
    -- Un evento isquémico es lento, usamos un refractario mayor (ej. 200ms)
    constant TIME_REFRACT : integer := 20_000_000; 
    signal cnt_refract    : integer := 0;

    -- Watchdog para resetear umbrales si la señal se normaliza mucho tiempo
    constant TIME_WATCHDOG : integer := 400_000_000; -- 4 segundos
    signal cnt_watchdog    : integer := 0; 

    -- Umbral de "Zona Segura" (Línea isoeléctrica)
    constant ISO_ZERO : signed(23 downto 0) := to_signed(100, 24);
    
    -- Límite Absoluto: Si la memoria supera esto, es un infarto confirmado
    constant CRITICAL_LIMIT : signed(23 downto 0) := to_signed(5000, 24); 

begin
    -- Asignaciones de salida
    current_st_elev <= mem_st_max;
    current_st_depr <= mem_st_min;

    process(clk)
        -- Variables auxiliares para cálculo de 75%
        variable val_75_max : signed(23 downto 0);
        variable val_75_min : signed(23 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= ETAPA_1;
                mem_st_max <= (others => '0');
                mem_st_min <= (others => '0');
                infarct_detected <= '0';
                severity_level <= '0';
                cnt_watchdog <= 0;
                cnt_refract <= 0;
                lesion_type <= '0';
            else
                infarct_detected <= '0'; 

                -- === LOGICA DE ALARMA DE GRAVEDAD ===
                -- Si el umbral aprendido supera un límite físico, activar alarma de severidad
                if abs(mem_st_max) > CRITICAL_LIMIT or abs(mem_st_min) > CRITICAL_LIMIT then
                    severity_level <= '1';
                else
                    severity_level <= '0';
                end if;

                -- === WATCHDOG (Resetear umbrales si no hay eventos patológicos) ===
                if cnt_watchdog < TIME_WATCHDOG then
                    cnt_watchdog <= cnt_watchdog + 1;
                else
                    cnt_watchdog <= 0;
                    mem_st_max <= shift_right(mem_st_max, 1); -- Decaimiento
                    mem_st_min <= shift_right(mem_st_min, 1);
                    state <= ETAPA_1; 
                end if;

                if d_valid = '1' then
                    
                    case state is
                        
                        -- =========================================================
                        -- ETAPA 1: Detectar Desviación del Segmento ST
                        -- =========================================================
                        when ETAPA_1 =>
                            -- Caso A: Infradesnivel (Isquemia subendocárdica)
                            if d_wavelet < mem_st_min then 
                                lesion_type <= '1';
                                state <= ETAPA_2;
                                
                            -- Caso B: Supradesnivel (Infarto agudo / Lesión)
                            elsif d_wavelet > mem_st_max then
                                lesion_type <= '0';
                                state <= ETAPA_2;
                            end if;

                        -- =========================================================
                        -- ETAPA 2: Actualizar Pico de la Lesión y Buscar Cruce
                        -- =========================================================
                        when ETAPA_2 =>
                            cnt_watchdog <= 0; -- Reiniciar watchdog porque hay actividad

                            if lesion_type = '0' then -- Supradesnivel
                                -- Adaptación del umbral (Learning)
                                val_75_max := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_max > mem_st_max then
                                     mem_st_max <= val_75_max;
                                end if;
                                
                            else -- Infradesnivel
                                val_75_min := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_min < mem_st_min then
                                     mem_st_min <= val_75_min;
                                end if;
                            end if;

                            -- Vuelta a la línea isoeléctrica (cero)
                            if (abs(d_wavelet) <= ISO_ZERO) then 
                                state <= ETAPA_3;
                            end if;

                        -- =========================================================
                        -- ETAPA 3: Detectar Rebote o Persistencia de la Onda
                        -- =========================================================
                        when ETAPA_3 =>
                            -- En infartos, a veces la onda T se invierte tras el ST.
                            -- Buscamos si la señal cruza al lado opuesto.
                            
                            if lesion_type = '0' then -- Venimos de positivo
                                if d_wavelet < mem_st_min then
                                    state <= ETAPA_4; -- Rebote detectado
                                end if;
                            else -- Venimos de negativo
                                if d_wavelet > mem_st_max then
                                    state <= ETAPA_4; -- Rebote detectado
                                end if;
                            end if;
                            
                        -- =========================================================
                        -- ETAPA 4: Confirmar Fin del Evento y Disparar Alerta
                        -- =========================================================
                        when ETAPA_4 =>
                            cnt_watchdog <= 0;

                            if lesion_type = '1' then -- Ahora estamos en zona positiva
                                val_75_max := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_max > mem_st_max then
                                     mem_st_max <= val_75_max;
                                end if;
                                
                            else -- Ahora estamos en zona negativa
                                val_75_min := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_min < mem_st_min then
                                     mem_st_min <= val_75_min;
                                end if;
                            end if;

                            -- Cuando la señal vuelve a cero, confirmamos el evento completo
                            if (abs(d_wavelet) <= ISO_ZERO) then
                                infarct_detected <= '1'; -- ¡PATRÓN DETECTADO!
                                state <= ETAPA_5;
                            end if;

                        -- =========================================================
                        -- ETAPA 5: Periodo Refractario (Cooldown)
                        -- =========================================================
                        when ETAPA_5 =>
                            if cnt_refract < TIME_REFRACT then
                                cnt_refract <= cnt_refract + 1;
                            else
                                cnt_refract <= 0;
                                state <= ETAPA_1;
                            end if;

                    end case;
                end if; -- d_valid
            end if; -- reset
        end if; -- clk
    end process;
end Behavioral;