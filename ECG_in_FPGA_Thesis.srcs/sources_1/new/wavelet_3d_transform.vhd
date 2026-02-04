library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity wavelet_3d_transform is
Port (
        clk             : in  STD_LOGIC;
        reset           : in  STD_LOGIC;
        
        -- Entrada de datos
        sample_valid_in : in  STD_LOGIC;
        raw_x           : in  STD_LOGIC_VECTOR(23 downto 0);
        raw_y           : in  STD_LOGIC_VECTOR(23 downto 0);
        raw_z           : in  STD_LOGIC_VECTOR(23 downto 0);

        -- Salidas wavelet (Escala 3)
        wavelet_x       : out STD_LOGIC_VECTOR(23 downto 0);
        wavelet_y       : out STD_LOGIC_VECTOR(23 downto 0);
        wavelet_z       : out STD_LOGIC_VECTOR(23 downto 0);
        
        -- Ready Flags
        vector_ready_s3 : out STD_LOGIC;
        vector_ready_s8 : out STD_LOGIC;
        
        -- Escala 3 (Para QRS)
        d_x_s3          : out SIGNED(23 downto 0);
        d_y_s3          : out SIGNED(23 downto 0);
        d_z_s3          : out SIGNED(23 downto 0);
        
        -- Escala 8 (Para Onda T)
        d_x_s8          : out SIGNED(23 downto 0);
        d_y_s8          : out SIGNED(23 downto 0);
        d_z_s8          : out SIGNED(23 downto 0)
    );
end wavelet_3d_transform;

architecture Behavioral of wavelet_3d_transform is

    component wavelet_1dimension is
        port (
            clk              : in  STD_LOGIC;
            reset            : in  STD_LOGIC;
            sample_valid     : in  STD_LOGIC;
            raw_data         : in  STD_LOGIC_VECTOR(23 downto 0);
            y_wavelet_s3     : out SIGNED(23 downto 0);
            d_wavelet_s3     : out SIGNED(23 downto 0);
            d_wavelet_s8     : out SIGNED(23 downto 0);
            wavelet_ready_s3 : out STD_LOGIC;
            wavelet_ready_s8 : out STD_LOGIC
        );
    end component;
    
    -- Señales internas
    signal yx3, yy3, yz3 : SIGNED(23 downto 0);
    signal dx3, dy3, dz3 : SIGNED(23 downto 0);
    signal dx8, dy8, dz8 : SIGNED(23 downto 0);
    
    signal rdyx_s3, rdyy_s3, rdyz_s3 : STD_LOGIC;
    signal rdyx_s8, rdyy_s8, rdyz_s8 : STD_LOGIC;

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
        wavelet_ready_s3 => rdyx_s3,
        wavelet_ready_s8 => rdyx_s8
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
        wavelet_ready_s3 => rdyy_s3,
        wavelet_ready_s8 => rdyy_s8
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
        wavelet_ready_s3 => rdyz_s3,
        wavelet_ready_s8 => rdyz_s8
    );
    
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                vector_ready_s3 <= '0';
                vector_ready_s8 <= '0';
                
                d_x_s3 <= (others => '0');
                d_y_s3 <= (others => '0');
                d_z_s3 <= (others => '0');
                
                d_x_s8 <= (others => '0');
                d_y_s8 <= (others => '0');
                d_z_s8 <= (others => '0');
                
                wavelet_x <= (others => '0');
                wavelet_y <= (others => '0');
                wavelet_z <= (others => '0');
            else
                vector_ready_s3 <= '0';
                vector_ready_s8 <= '0';

                -- Procesamiento Escala 3
                if rdyz_s3 = '1' then
                    d_x_s3 <= dx3;
                    d_y_s3 <= dy3;
                    d_z_s3 <= dz3;
                    
                    -- Salidas de visualización
                    wavelet_x <= std_logic_vector(yx3);
                    wavelet_y <= std_logic_vector(yy3);
                    wavelet_z <= std_logic_vector(yz3);
                    
                    vector_ready_s3 <= '1';
                end if;
                
                -- Procesamiento Escala 8 
                if rdyz_s8 = '1' then
                    d_x_s8 <= dx8;
                    d_y_s8 <= dy8;
                    d_z_s8 <= dz8;
                    
                    vector_ready_s8 <= '1';
                end if;
            end if;
        end if;
    end process;
end Behavioral;