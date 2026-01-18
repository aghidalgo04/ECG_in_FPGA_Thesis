library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity wavelet_3d_transform is
Port (
        -- 1. CONTROL GENERAL
        clk             : in  STD_LOGIC;
        reset           : in  STD_LOGIC;
        
        -- 2. ENTRADA DE DATOS (del módulo ADS1293)
        sample_valid_in : in  STD_LOGIC;
        raw_x           : in  STD_LOGIC_VECTOR(23 downto 0);
        raw_y           : in  STD_LOGIC_VECTOR(23 downto 0);
        raw_z           : in  STD_LOGIC_VECTOR(23 downto 0);

        -- 3. SALIDAS DE SEÑAL LIMPIA
        -- La Wavelet elimina el ruido de alta frecuencia
        wavelet_x         : out STD_LOGIC_VECTOR(23 downto 0);
        wavelet_y         : out STD_LOGIC_VECTOR(23 downto 0);
        wavelet_z         : out STD_LOGIC_VECTOR(23 downto 0);
        
        vector_ready    : out  STD_LOGIC;
        d_vector_s3     : out  SIGNED(23 downto 0);
        y_vector_s3     : out SIGNED(23 downto 0);
        d_vector_s8     : out SIGNED(23 downto 0)
    );
end wavelet_3d_transform;

architecture Behavioral of wavelet_3d_transform is

    component wavelet_1dimension is
        port (
            clk           : in  STD_LOGIC;
            reset         : in  STD_LOGIC;
            sample_valid  : in  STD_LOGIC;
            raw_data      : in  STD_LOGIC_VECTOR(23 downto 0);
            y_wavelet_s3     : out SIGNED(23 downto 0);
            d_wavelet_s3     : out SIGNED(23 downto 0);
            d_wavelet_s8     : out SIGNED(23 downto 0);
            wavelet_ready : out STD_LOGIC
        );
end component;
    
    signal yx3, yy3, yz3 : SIGNED(23 downto 0);
    signal dx3, dy3, dz3 : SIGNED(23 downto 0);
    signal dx8, dy8, dz8 : SIGNED(23 downto 0);
    signal rdyx, rdyy, rdyz : STD_LOGIC;
    signal abs_dx, abs_dy, abs_dz : signed(23 downto 0);

begin
    EJE_X: wavelet_1dimension
    port map (
        clk => clk,
        reset => reset,
        sample_valid => sample_valid_in,
        raw_data => raw_x,
        y_wavelet_s3 => yx3,
        d_wavelet_s3 => dx3,
        d_wavelet_s8 => dx8,
        wavelet_ready => rdyx
    );
    
    EJE_Y: wavelet_1dimension
    port map (
        clk => clk,
        reset => reset,
        sample_valid => sample_valid_in,
        raw_data => raw_y,
        y_wavelet_s3 => yy3,
        d_wavelet_s3 => dy3,
        d_wavelet_s8 => dy8,
        wavelet_ready => rdyy
    );
    
    EJE_Z: wavelet_1dimension
    port map (
        clk => clk,
        reset => reset,
        sample_valid => sample_valid_in,
        raw_data => raw_z,
        y_wavelet_s3 => yz3,
        d_wavelet_s3 => dz3,
        d_wavelet_s8 => dz8,
        wavelet_ready => rdyz
    );
    
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                vector_ready <= '0';
                d_vector_s3 <= (others => '0');
                y_vector_s3 <= (others => '0');
            else
                vector_ready <= '0';

                if rdyz = '1' then
                    -- Sumamos los absolutos
                    d_vector_s3 <= abs(dx3) + abs(dy3) + abs(dz3);
                    d_vector_s8 <= abs(dx8) + abs(dy8) + abs(dz8);
                    y_vector_s3 <= abs(yx3) + abs(yy3) + abs(yz3);
                    
                    wavelet_x <= std_logic_vector(yx3);
                    wavelet_y <= std_logic_vector(yy3);
                    wavelet_z <= std_logic_vector(yz3);
                    
                    vector_ready <= '1';
                end if;
            end if;
        end if;
    end process;
end Behavioral;
