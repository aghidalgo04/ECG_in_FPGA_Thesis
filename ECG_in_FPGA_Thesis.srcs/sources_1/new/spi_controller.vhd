library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_controller is
    generic (
        CLK_DIV : integer := 100  -- Spi a 100 MHz
    );
    port (
        -- Sistema
        clk      : in  std_logic;
        rst      : in  std_logic;
        
        -- Control Sensor
        drdy_b   : in  std_logic;
        
        -- Bus SPI
        sclk     : out std_logic;
        mosi     : out std_logic;
        miso     : in  std_logic;
        cs_b     : out std_logic;
        
        -- Salidas de datos (Canales X, Y, Z)
        raw_x    : out std_logic_vector(23 downto 0);
        raw_y    : out std_logic_vector(23 downto 0);
        raw_z    : out std_logic_vector(23 downto 0);
        d_valid  : out std_logic
    );
end spi_controller;

architecture Behavioral of spi_controller is
    
    -- Estados de la FSM
    type state_type is (STARTUP, STARTUP_HOLD, IDLE, TRANSFER, DONE, WAIT_DRDY_HIGH);
    signal state : state_type := STARTUP;
    
    -- Contadores de tiempo y bits
    signal clk_cnt  : integer range 0 to 255 := 0; 
    signal bit_cnt  : integer range 0 to 7 := 0;
    signal byte_cnt : integer range 0 to 16 := 0;
    
    -- Registros de desplazamiento y reloj interno
    signal shift_out : std_logic_vector(7 downto 0) := x"00";
    signal shift_in  : std_logic_vector(7 downto 0) := x"00";
    signal sclk_reg  : std_logic := '0';
    
    -- Buffers de recepción de datos
    signal rx_buf_x  : std_logic_vector(23 downto 0) := x"000000";
    signal rx_buf_y  : std_logic_vector(23 downto 0) := x"000000";
    signal rx_buf_z  : std_logic_vector(23 downto 0) := x"000000";
    
    -- Array de configuración
    type config_array is array (0 to 33) of std_logic_vector(7 downto 0);
    constant CONFIG_DATA : config_array := (
        x"01", x"11", -- FLEX_CH1_CN
        x"02", x"19", -- FLEX_CH2_CN
        x"03", x"1E", -- FLEX_CH3_CN
        x"0A", x"07", -- CMDET_EN   
        x"0C", x"04", -- RLD_CN     
        
        -- Activacion de WCT
        x"0D", x"01", -- WILSON_EN1   
        x"0E", x"02", -- WILSON_EN2   
        x"0F", x"03", -- WILSON_EN3   
        x"10", x"01", -- WILSON_CN    
        
        x"12", x"04", -- OSC_CN     
        x"21", x"02", -- R2_RATE    
        x"22", x"02", -- R3_RATE_CH1
        x"23", x"02", -- R3_RATE_CH2
        x"24", x"02", -- R3_RATE_CH3
        x"27", x"20", -- DRDYB_SRC  
        x"2F", x"70", -- CH_CNFG    
        x"00", x"01"  -- CONFIG      
    );
    signal cfg_ptr : integer range 0 to 17 := 0;
    
begin
    sclk <= sclk_reg;
    
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= STARTUP;
                cs_b <= '1';
                sclk_reg <= '0';
                mosi <= '0';
                d_valid <= '0';
                clk_cnt <= 0;
                bit_cnt <= 7;
                byte_cnt <= 0;
                cfg_ptr <= 0;
                raw_x <= x"000000";
                raw_y <= x"000000";
                raw_z <= x"000000";
                shift_out <= x"01";
                shift_in <= x"00";
            else
                case state is
                    
                    -- Configuración inicial de los registros del sensor
                    when STARTUP =>
                        d_valid <= '0';
                        if cfg_ptr < 17 then
                            cs_b <= '0';
                            
                            -- Carga del primer bit
                            if clk_cnt = 0 and bit_cnt = 7 and byte_cnt = 0 then
                                shift_out <= CONFIG_DATA(cfg_ptr * 2);
                                mosi <= CONFIG_DATA(cfg_ptr * 2)(7);
                            end if;
                            
                            -- Generación de SCLK
                            if clk_cnt = (CLK_DIV / 2) - 1 then
                                sclk_reg <= '1';
                                clk_cnt <= clk_cnt + 1;
                            elsif clk_cnt = CLK_DIV - 1 then
                                sclk_reg <= '0';
                                clk_cnt <= 0;
                                
                                if bit_cnt = 0 then
                                    bit_cnt <= 7;
                                    if byte_cnt = 0 then
                                        byte_cnt <= 1;
                                        shift_out <= CONFIG_DATA((cfg_ptr * 2) + 1);
                                        mosi <= CONFIG_DATA((cfg_ptr * 2) + 1)(7);
                                    else
                                        byte_cnt <= 0;
                                        clk_cnt <= 0;
                                        state <= STARTUP_HOLD;
                                    end if;
                                else
                                    bit_cnt <= bit_cnt - 1;
                                    mosi <= shift_out(bit_cnt - 1);
                                end if;
                            else
                                clk_cnt <= clk_cnt + 1;
                            end if;
                        else
                            cs_b <= '1';
                            sclk_reg <= '0';
                            mosi <= '0';
                            state <= IDLE;
                        end if;

                    -- Retención de CS_B
                    when STARTUP_HOLD =>
                        cs_b <= '1'; 
                        sclk_reg <= '0';
                        mosi <= '0';
                        if clk_cnt = 20 then
                            clk_cnt <= 0;
                            cfg_ptr <= cfg_ptr + 1;
                            state <= STARTUP;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    -- Espera la respuesta del sensor
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
                        
                    -- Lectura SPI
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
                                    when 2 => rx_buf_x(15 downto 8)  <= shift_in;
                                    when 3 => rx_buf_x(7 downto 0)   <= shift_in;
                                    when 4 => rx_buf_y(23 downto 16) <= shift_in;
                                    when 5 => rx_buf_y(15 downto 8)  <= shift_in;
                                    when 6 => rx_buf_y(7 downto 0)   <= shift_in;
                                    when 7 => rx_buf_z(23 downto 16) <= shift_in;
                                    when 8 => rx_buf_z(15 downto 8)  <= shift_in;
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
                        
                    -- Fin de transmisión
                    when DONE =>
                        cs_b <= '1';
                        raw_x <= rx_buf_x;
                        raw_y <= rx_buf_y;
                        raw_z <= rx_buf_z;
                        d_valid <= '1';
                        state <= WAIT_DRDY_HIGH;
                        
                    -- Espera DRDY_B nivel alto
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