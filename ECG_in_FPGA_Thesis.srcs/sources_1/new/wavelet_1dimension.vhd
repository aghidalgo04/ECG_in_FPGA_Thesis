library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity wavelet_1dimension is
    Port (
        clk           : in  STD_LOGIC;
        reset         : in  STD_LOGIC;
        -- Entradas del Sensor
        sample_valid  : in  STD_LOGIC;
        raw_data      : in  STD_LOGIC_VECTOR(23 downto 0);
        
        -- Salidas
        y_wavelet_s3     : out SIGNED(23 downto 0);
        d_wavelet_s3     : out SIGNED(23 downto 0);
        d_wavelet_s8     : out SIGNED(23 downto 0);
        wavelet_ready_s3 : out STD_LOGIC;
        wavelet_ready_s8 : out STD_LOGIC
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

    -- Señales de interconexión
    signal val_1, val_2, val_3, val_4, val_5, val_6, val_7, val_8 : std_logic;
    signal y1, y2, y3, y4, y5, y6, y7, y8 : signed(23 downto 0);
    signal d1, d2, d3, d4, d5, d6, d7, d8 : signed(23 downto 0);
    
    -- Señal convertida a signed
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
        d_in => y1,
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

    STAGE_5: wavelet_phase 
    port map (
        clk => clk, 
        reset => reset,
        d_in_valid => val_4, 
        d_in => y4,
        d_out_valid => val_5, 
        y_approx => y5, 
        d_detail => d5
    );

    STAGE_6: wavelet_phase 
    port map (
        clk => clk, 
        reset => reset,
        d_in_valid => val_5, 
        d_in => y5,
        d_out_valid => val_6, 
        y_approx => y6, 
        d_detail => d6
    );

    STAGE_7: wavelet_phase 
    port map (
        clk => clk, 
        reset => reset,
        d_in_valid => val_6, 
        d_in => y6,
        d_out_valid => val_7, 
        y_approx => y7, 
        d_detail => d7
    );

    STAGE_8: wavelet_phase 
    port map (
        clk => clk, 
        reset => reset,
        d_in_valid => val_7, 
        d_in => y7,
        d_out_valid => wavelet_ready_s8, 
        y_approx => y8, 
        d_detail => d_wavelet_s8
    );
    
    y_wavelet_s3 <= y3;
    d_wavelet_s3 <= d3;
    wavelet_ready_s3 <= val_3;
    
end Behavioral;