library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity heart_attack_detector is
    Port (
        clk             : in  STD_LOGIC;
        reset           : in  STD_LOGIC;
        
        -- Entrada: Usar Wavelet Escala 8 (Baja frecuencia)
        d_valid         : in  STD_LOGIC;
        d_wavelet       : in  SIGNED(23 downto 0);
        
        -- Salidas
        infarct_detected: out STD_LOGIC; -- '1' = Infarto (ST Elevado o T invertida)
        st_elevation    : out STD_LOGIC; -- Específico: Elevación sostenida (Agudo)
        
        current_level   : out SIGNED(23 downto 0)
    );
end heart_attack_detector;

architecture Behavioral of heart_attack_detector is

    type state_type is (IDLE, MONITOR_ELEVACION, MONITOR_RECUPERACION, REFRACTARIO);
    signal state : state_type := IDLE;

    -- Umbrales
    signal mem_peak : signed(23 downto 0) := (others => '0');
    
    -- Umbral de "Silencio" (Línea Isoeléctrica)
    constant ISO_ZERO : signed(23 downto 0) := to_signed(100, 24);
    
    -- Umbral mínimo para considerar que algo es un evento patológico
    constant MIN_AMPLITUDE : signed(23 downto 0) := to_signed(500, 24);

    -- Temporizadores
    -- ST Duration: Si la señal no baja a cero en este tiempo, es un ST Elevado.
    -- Un QRS normal dura < 120ms. Si la señal sigue alta tras 150ms, es patológico.
    -- Asumiendo clk 100MHz: 150ms = 15,000,000 ciclos.
    constant TIME_ST_LIMIT : integer := 15_000_000; 
    signal cnt_st_duration : integer := 0;
    
    constant TIME_REFRACT  : integer := 20_000_000; -- 200ms espera tras evento
    signal cnt_refract     : integer := 0;

begin
    current_level <= mem_peak;

    process(clk)
        variable abs_input : signed(23 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= IDLE;
                infarct_detected <= '0';
                st_elevation <= '0';
                cnt_st_duration <= 0;
                mem_peak <= (others => '0');
            else
                -- Pulsos de salida duran solo 1 ciclo por defecto (o latch según se desee)
                infarct_detected <= '0'; 
                st_elevation <= '0';
                
                if d_valid = '1' then
                    abs_input := abs(d_wavelet);

                    case state is
                        
                        -- =====================================================
                        -- IDLE: Esperamos a que la señal salga del cero
                        -- =====================================================
                        when IDLE =>
                            cnt_st_duration <= 0;
                            
                            if abs_input > ISO_ZERO then
                                mem_peak <= abs_input;
                                state <= MONITOR_ELEVACION;
                            end if;

                        -- =====================================================
                        -- MONITOR ELEVACION: La señal es alta. ¿Vuelve a cero?
                        -- =====================================================
                        when MONITOR_ELEVACION =>
                            
                            -- 1. Actualizar pico máximo detectado
                            if abs_input > mem_peak then
                                mem_peak <= abs_input;
                            end if;

                            -- 2. CHECK DE SEGURIDAD (Si vuelve a cero rápido)
                            if abs_input <= ISO_ZERO then
                                -- Si bajó a cero muy rápido, era un QRS normal o ruido.
                                -- No hay alarma.
                                state <= REFRACTARIO; 
                            else
                                -- 3. LA SEÑAL SIGUE ALTA (NO HA BAJADO)
                                cnt_st_duration <= cnt_st_duration + 1;
                                
                                -- 4. DETECCIÓN DE LA "ALETA DE TIBURÓN"
                                -- Si llevamos X tiempo y la señal SIGUE alta sin tocar cero...
                                if cnt_st_duration > TIME_ST_LIMIT then
                                    
                                    -- Y además tiene una amplitud considerable
                                    if mem_peak > MIN_AMPLITUDE then
                                        st_elevation <= '1';     -- ¡ST ELEVATION!
                                        infarct_detected <= '1'; -- ALARMA
                                        state <= MONITOR_RECUPERACION; -- Ya pitamos, ahora a esperar que baje
                                    else
                                        -- Si duró mucho pero es muy bajita, quizás es ruido de línea base
                                        state <= MONITOR_RECUPERACION;
                                    end if;
                                end if;
                            end if;

                        -- =====================================================
                        -- MONITOR RECUPERACION: Esperamos a que termine la onda T
                        -- =====================================================
                        when MONITOR_RECUPERACION =>
                            -- Aquí ya hemos dado la alarma (o descartado).
                            -- Solo esperamos a que la señal baje a cero para reiniciar.
                            if abs_input <= ISO_ZERO then
                                state <= REFRACTARIO;
                            end if;

                        -- =====================================================
                        -- REFRACTARIO: Pausa para no detectar rebotes
                        -- =====================================================
                        when REFRACTARIO =>
                            if cnt_refract < TIME_REFRACT then
                                cnt_refract <= cnt_refract + 1;
                            else
                                cnt_refract <= 0;
                                state <= IDLE;
                            end if;

                    end case;
                end if;
            end if;
        end if;
    end process;
end Behavioral;