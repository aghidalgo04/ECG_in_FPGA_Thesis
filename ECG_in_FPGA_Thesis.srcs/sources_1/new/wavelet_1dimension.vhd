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
        y_wavelet     : out SIGNED(23 downto 0);
        d_wavelet     : out SIGNED(23 downto 0);
        wavelet_ready : out STD_LOGIC
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
    signal val_1, val_2 : std_logic;
    signal y1, y2, y3 : signed(23 downto 0);
    signal d1, d2, d3 : signed(23 downto 0);
    
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
        d_out_valid => wavelet_ready, 
        y_approx => y_wavelet, 
        d_detail => d_wavelet
    );
end Behavioral;