library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity wavelet_1dimension is
    Port (
        clk           : in  STD_LOGIC;
        reset         : in  STD_LOGIC;
        -- Entrada del Sensor
        sample_valid  : in  STD_LOGIC;
        raw_data      : in  STD_LOGIC_VECTOR(23 downto 0);
        
        -- Salidas Finales
        clean_ecg     : out STD_LOGIC_VECTOR(23 downto 0); -- Para ver en gráfica (Y4)
        beat_detected : out STD_LOGIC                      -- LED o contador
    );
end wavelet_1dimension;

architecture Behavioral of wavelet_1dimension is

    -- Declaramos el componente reutilizable
    component wavelet_phase is
        Port (  
                clk : in STD_LOGIC;
                reset : in STD_LOGIC;
                d_in_valid : in STD_LOGIC;
                d_in : in SIGNED(23 downto 0);
                d_out_valid : out STD_LOGIC;
                y_approx : out SIGNED(23 downto 0);
                d_detail : out SIGNED(23 downto 0)
        );
    end component;

    -- Señales de interconexión (Cables internos)
    signal val_1, val_2, val_3, val_4 : std_logic;
    signal y1, y2, y3, y4 : signed(23 downto 0);
    signal d1, d2, d3, d4 : signed(23 downto 0);
    
    -- Señal convertida a signed para operar
    signal raw_signed : signed(23 downto 0);

begin
    raw_signed <= signed(raw_data);

    -- =========================================================
    -- NIVEL 1: Elimina ruido alta frecuencia (500-1000 Hz)
    -- =========================================================
    STAGE_1: wavelet_phase 
    port map (
        clk => clk, 
        reset => reset,
        d_in_valid => sample_valid, 
        d_in => raw_signed,
        d_out_valid => val_1, 
        y_approx => y1, 
        d_detail => d1
    );

    -- =========================================================
    -- NIVEL 2: Elimina ruido muscular (250-500 Hz)
    -- =========================================================
    STAGE_2: wavelet_phase 
    port map (
        clk => clk, 
        reset => reset,
        d_in_valid => val_1, 
        d_in => y1,  -- Entra la salida Y del anterior
        d_out_valid => val_2, 
        y_approx => y2, 
        d_detail => d2
    );

    -- =========================================================
    -- NIVEL 3: Prepara la señal
    -- =========================================================
    STAGE_3: wavelet_phase 
    port map (
        clk => clk, 
        reset => reset,
        d_in_valid => val_2, 
        d_in => y2,
        d_out_valid => val_3, 
        y_approx => y3, 
        d_detail => d3
    );

    -- =========================================================
    -- NIVEL 4: Extracción del QRS (El latido está en D4)
    -- =========================================================
    STAGE_4: wavelet_phase 
    port map (
        clk => clk, 
        reset => reset,
        d_in_valid => val_3, 
        d_in => y3,
        d_out_valid => val_4, 
        y_approx => y4, 
        d_detail => d4
    );

    -- =========================================================
    -- DETECTOR DE LATIDOS (Mira D4)
    -- =========================================================
    DETECTOR: entity work.qrs_detector port map (
        clk => clk, reset => reset,
        d_in_valid => val_4,
        d_wavelet => d4,  -- ¡OJO! Aquí conectamos D4 (Detalle)
        pulse_out => beat_detected
    );

    -- Salida opcional: ECG Limpio (Sin ruido ni línea base)
    -- Podemos sacar Y4 (muy suave) o reconstruir. Y4 es bueno para ver ritmo.
    clean_ecg <= std_logic_vector(y4); 

end Behavioral;