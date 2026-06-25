library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity wavelet_1dimension is
    Port (
        clk              : in  STD_LOGIC;
        reset            : in  STD_LOGIC;
        
        -- Entradas (modulo SPI)
        sample_valid     : in  STD_LOGIC;
        raw_data         : in  STD_LOGIC_VECTOR(23 downto 0);
        
        -- Salidas (Detección)
        y_wavelet_s3     : out SIGNED(23 downto 0);
        d_wavelet_s3     : out SIGNED(23 downto 0);
        d_wavelet_s8     : out SIGNED(23 downto 0);
        wavelet_ready_s3 : out STD_LOGIC;
        wavelet_ready_s8 : out STD_LOGIC
    );
end wavelet_1dimension;

architecture Behavioral of wavelet_1dimension is

    component wavelet_phase is
        generic ( m : integer );
        Port (  
                clk : in STD_LOGIC;
                reset : in STD_LOGIC;
                d_in_valid : in STD_LOGIC;
                d_in : in SIGNED(23 downto 0);
                d_out_valid : out STD_LOGIC;
                y : out SIGNED(23 downto 0);
                d : out SIGNED(23 downto 0)
        );
    end component;

    signal val_1, val_2, val_3, val_4, val_5, val_6, val_7, val_8 : std_logic;
    signal y1, y2, y3, y4, y5, y6, y7, y8 : signed(23 downto 0);
    signal d1, d2, d3, d4, d5, d6, d7, d8 : signed(23 downto 0);
    
    signal raw_signed : signed(23 downto 0);

begin
    raw_signed <= signed(raw_data);

    -- Escalado
    STAGE_1: wavelet_phase generic map(m => 1) 
    port map (
        clk => clk, 
        reset => reset,
        d_in_valid => sample_valid, 
        d_in => raw_signed,
        d_out_valid => val_1, 
        y => y1, 
        d => d1
    );

    STAGE_2: wavelet_phase generic map(m => 2)
    port map (
        clk => clk, 
        reset => reset,
        d_in_valid => val_1, 
        d_in => y1,
        d_out_valid => val_2, 
        y => y2, 
        d => d2
    );
    -- Fin de escalado para qrs
    STAGE_3: wavelet_phase generic map(m => 3)
    port map (
        clk => clk, 
        reset => reset,
        d_in_valid => val_2, 
        d_in => y2,
        d_out_valid => val_3, 
        y => y3, 
        d => d3
    );
    
    STAGE_4: wavelet_phase generic map(m => 4)
    port map (
        clk => clk, 
        reset => reset,
        d_in_valid => val_3, 
        d_in => y3,
        d_out_valid => val_4, 
        y => y4, 
        d => d4
    );

    STAGE_5: wavelet_phase generic map(m => 5)
    port map (
        clk => clk, 
        reset => reset,
        d_in_valid => val_4, 
        d_in => y4,
        d_out_valid => val_5, 
        y => y5, 
        d => d5
    );

    STAGE_6: wavelet_phase generic map(m => 6)
    port map (
        clk => clk, 
        reset => reset,
        d_in_valid => val_5, 
        d_in => y5,
        d_out_valid => val_6, 
        y => y6, 
        d => d6
    );

    STAGE_7: wavelet_phase generic map(m => 7)
    port map (
        clk => clk, 
        reset => reset,
        d_in_valid => val_6, 
        d_in => y6,
        d_out_valid => val_7, 
        y => y7, 
        d => d7
    );

    -- Fin de escalado para t
    STAGE_8: wavelet_phase generic map(m => 8)
    port map (
        clk => clk, 
        reset => reset,
        d_in_valid => val_7, 
        d_in => y7,
        d_out_valid => wavelet_ready_s8, 
        y => y8, 
        d => d_wavelet_s8
    );
    
    y_wavelet_s3 <= y3;
    d_wavelet_s3 <= d3;
    wavelet_ready_s3 <= val_3;
    
end Behavioral;