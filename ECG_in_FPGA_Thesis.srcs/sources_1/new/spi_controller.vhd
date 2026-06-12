library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_controller is
    generic (
        CLK_DIV : integer := 10
    );
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
end spi_controller;

architecture Behavioral of spi_controller is
    type state_type is (IDLE, TRANSFER, DONE, WAIT_DRDY_HIGH);
    signal state : state_type := IDLE;
    
    signal clk_cnt  : integer range 0 to CLK_DIV - 1 := 0;
    signal bit_cnt  : integer range 0 to 7 := 0;
    signal byte_cnt : integer range 0 to 10 := 0;
    
    signal shift_out : std_logic_vector(7 downto 0) := x"00";
    signal shift_in  : std_logic_vector(7 downto 0) := x"00";
    signal sclk_reg  : std_logic := '0';
    
    signal rx_buf_x  : std_logic_vector(23 downto 0) := x"000000";
    signal rx_buf_y  : std_logic_vector(23 downto 0) := x"000000";
    signal rx_buf_z  : std_logic_vector(23 downto 0) := x"000000";
    
begin

    sclk <= sclk_reg;
    
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                cs_b <= '1';
                sclk_reg <= '0';
                mosi <= '0';
                d_valid <= '0';
                clk_cnt <= 0;
                bit_cnt <= 0;
                byte_cnt <= 0;
                raw_x <= x"000000";
                raw_y <= x"000000";
                raw_z <= x"000000";
                shift_out <= x"00";
                shift_in <= x"00";
            else
                case state is
                    when IDLE =>
                        d_valid <= '0';
                        cs_b <= '1';
                        sclk_reg <= '0';
                        clk_cnt <= 0;
                        bit_cnt <= 7;
                        byte_cnt <= 0;
                        if drdy_b = '0' then
                            cs_b <= '0';
                            shift_out <= x"B7";
                            mosi <= '1';
                            state <= TRANSFER;
                        end if;
                        
                    when TRANSFER =>
                        if clk_cnt = (CLK_DIV / 2) - 1 then
                            sclk_reg <= '1';
                            shift_in <= shift_in(6 downto 0) & miso;
                            clk_cnt <= clk_cnt + 1;
                        elsif clk_cnt = CLK_DIV - 1 then
                            sclk_reg <= '0';
                            clk_cnt <= 0;
                            
                            if bit_cnt = 0 then
                                bit_cnt <= 7;
                                byte_cnt <= byte_cnt + 1;
                                shift_out <= x"00";
                                mosi <= '0';
                                
                                case byte_cnt is
                                    when 1 => rx_buf_x(23 downto 16) <= shift_in;
                                    when 2 => rx_buf_x(15 downto 8) <= shift_in;
                                    when 3 => rx_buf_x(7 downto 0) <= shift_in;
                                    when 4 => rx_buf_y(23 downto 16) <= shift_in;
                                    when 5 => rx_buf_y(15 downto 8) <= shift_in;
                                    when 6 => rx_buf_y(7 downto 0) <= shift_in;
                                    when 7 => rx_buf_z(23 downto 16) <= shift_in;
                                    when 8 => rx_buf_z(15 downto 8) <= shift_in;
                                    when 9 => 
                                        rx_buf_z(7 downto 0) <= shift_in;
                                        state <= DONE;
                                    when others => null;
                                end case;
                            else
                                bit_cnt <= bit_cnt - 1;
                                mosi <= shift_out(bit_cnt - 1);
                            end if;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;
                        
                    when DONE =>
                        cs_b <= '1';
                        raw_x <= rx_buf_x;
                        raw_y <= rx_buf_y;
                        raw_z <= rx_buf_z;
                        d_valid <= '1';
                        state <= WAIT_DRDY_HIGH;
                        
                    when WAIT_DRDY_HIGH =>
                        d_valid <= '0';
                        if drdy_b = '1' then
                            state <= IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;

end Behavioral;