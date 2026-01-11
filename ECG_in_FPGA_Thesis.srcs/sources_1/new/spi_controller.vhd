library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity spi_driver is
    Port ( 
        -- SISTEMA
        clk           : in  STD_LOGIC;
        reset_n       : in  STD_LOGIC;
        
        -- Wavelet
        data_x        : out STD_LOGIC_VECTOR(23 downto 0);
        data_y        : out STD_LOGIC_VECTOR(23 downto 0);
        data_z        : out STD_LOGIC_VECTOR(23 downto 0);
        sample_valid  : out STD_LOGIC; -- Esto NO es DRDY, es "Dato SPI terminado"
        device_ready  : out STD_LOGIC;
        lead_off_err  : out STD_LOGIC; 
        
        -- ADS1293
        spi_sclk      : out STD_LOGIC;
        spi_mosi      : out STD_LOGIC;
        spi_miso      : in  STD_LOGIC;
        spi_cs_n      : out STD_LOGIC;
        drdy          : in  STD_LOGIC; -- Conectar a P4 Pin 4
        alarm         : in  STD_LOGIC; -- Conectar a P4 Pin 3 (Nuevo)
        ads_reset     : out STD_LOGIC; -- Para resetear el chip (Pin RST)
        syncb         : out STD_LOGIC; -- Conectar a P4 Pin 9 (Nuevo - Poner a '1')
        oe            : out STD_LOGIC  -- Conectar a 0
    );
end spi_driver;

architecture Behavioral of spi_driver is

begin


end Behavioral;
