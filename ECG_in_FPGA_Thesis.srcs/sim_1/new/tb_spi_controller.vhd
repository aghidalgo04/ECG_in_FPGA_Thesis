library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_spi_controller is
end tb_spi_controller;

architecture Behavioral of tb_spi_controller is

    component spi_controller is
        generic ( CLK_DIV : integer := 10 );
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            drdy_b   : in  std_logic;
            sclk     : out std_logic;
            mosi     : out std_logic;
            miso     : in  std_logic;
            cs_b     : out std_logic;
            raw_x    : out std_logic_vector(23 downto 0);
            raw_y    : out std_logic_vector(23 downto 0);
            raw_z    : out std_logic_vector(23 downto 0);
            d_valid  : out std_logic
        );
    end component;

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal drdy_b   : std_logic := '1';
    signal sclk     : std_logic;
    signal mosi     : std_logic;
    signal miso     : std_logic := '0';
    signal cs_b     : std_logic;
    signal raw_x    : std_logic_vector(23 downto 0);
    signal raw_y    : std_logic_vector(23 downto 0);
    signal raw_z    : std_logic_vector(23 downto 0);
    signal d_valid  : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    UUT: spi_controller
        generic map ( CLK_DIV => 10 )
        port map (
            clk      => clk,
            rst      => rst,
            drdy_b   => drdy_b,
            sclk     => sclk,
            mosi     => mosi,
            miso     => miso,
            cs_b     => cs_b,
            raw_x    => raw_x,
            raw_y    => raw_y,
            raw_z    => raw_z,
            d_valid  => d_valid
        );

    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    stim_process : process
    begin
        rst <= '1';
        drdy_b <= '1';
        wait for 40 ns;
        rst <= '0';
        wait for 40 ns;
        
        drdy_b <= '0';
        wait for 20 ns;
        drdy_b <= '1';
        
        wait until d_valid = '1';
        wait for 200 ns;
        
        drdy_b <= '0';
        wait for 20 ns;
        drdy_b <= '1';
        
        wait until d_valid = '1';
        wait for 200 ns;
        
        assert false report "Simulacion terminada con exito" severity failure;
        wait;
    end process;

    sensor_emulator_process : process
        variable test_stream : std_logic_vector(0 to 79) := x"00123456789ABC123456";
        variable bit_idx : integer := 0;
    begin
        miso <= '0';
        wait until cs_b = '0';
        bit_idx := 0;
        while cs_b = '0' loop
            wait until falling_edge(sclk);
            miso <= test_stream(bit_idx);
            bit_idx := bit_idx + 1;
        end loop;
    end process;

end Behavioral;