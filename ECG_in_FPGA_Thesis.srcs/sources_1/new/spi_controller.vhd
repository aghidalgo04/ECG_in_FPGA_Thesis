library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_controller is
    generic (
        CLK_DIV : integer := 100  -- 100 MHz / 100 = 1 MHz (Velocidad segura para cables Dupont)
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
    type state_type is (STARTUP, STARTUP_HOLD, IDLE, TRANSFER, DONE, WAIT_DRDY_HIGH);
    signal state : state_type := STARTUP;
    
    signal clk_cnt  : integer range 0 to 255 := 0; 
    signal bit_cnt  : integer range 0 to 7 := 0;
    signal byte_cnt : integer range 0 to 16 := 0;
    
    signal shift_out : std_logic_vector(7 downto 0) := x"00";
    signal shift_in  : std_logic_vector(7 downto 0) := x"00";
    signal sclk_reg  : std_logic := '0';
    
    signal rx_buf_x  : std_logic_vector(23 downto 0) := x"000000";
    signal rx_buf_y  : std_logic_vector(23 downto 0) := x"000000";
    signal rx_buf_z  : std_logic_vector(23 downto 0) := x"000000";
    
    -- Array de configuración optimizado (17 registros = 34 bytes)
    type config_array is array (0 to 33) of std_logic_vector(7 downto 0);
    constant CONFIG_DATA : config_array := (
        x"01", x"11", -- 1. FLEX_CH1_CN  -> CH1: IN2 - IN1 (LA - RA)
        x"02", x"19", -- 2. FLEX_CH2_CN  -> CH2: IN3 - IN1 (LL - RA) [¡CORREGIDO CORTOCIRCUITO!]
        x"03", x"1E", -- 3. FLEX_CH3_CN  -> CH3: IN3 - IN6 (Espalda - Centro WCT)
        x"0A", x"07", -- 4. CMDET_EN     -> Activar detector de modo común en IN1, IN2 e IN3
        x"0C", x"04", -- 5. RLD_CN       -> RLD activo hacia el electrodo acoplado a la placa (IN4)
        
        -- === ACTIVACIÓN DEL TERMINAL CENTRAL DE WILSON (WCT) PARA EL PIN IN6 ===
        x"0D", x"01", -- 6. WILSON_EN1   -> Enrutar IN1 (RA) al componente WCTA
        x"0E", x"02", -- 7. WILSON_EN2   -> Enrutar IN2 (LA) al componente WCTB
        x"0F", x"03", -- 8. WILSON_EN3   -> Enrutar IN3 (LL) al componente WCTC
        x"10", x"01", -- 9. WILSON_CN    -> Encender buffers WCT y enrutar la constante eléctrica a IN6
        
        x"12", x"04", -- 10. OSC_CN      -> ¡CRÍTICO! STRTCLK=1 (Despierta la lógica digital)
        x"21", x"02", -- 11. R2_RATE     -> Decimación R2 = 5
        x"22", x"02", -- 12. R3_RATE_CH1 -> Decimación R3 = 6 (Canal 1)
        x"23", x"02", -- 13. R3_RATE_CH2 -> Decimación R3 = 6 (Canal 2)
        x"24", x"02", -- 14. R3_RATE_CH3 -> Decimación R3 = 6 (Canal 3) -> Fs ~1066 Hz
        x"27", x"20", -- 15. DRDYB_SRC   -> Mapear señal física DRDY_B al Canal 3 de ECG
        x"2F", x"70", -- 16. CH_CNFG     -> Habilitar CH1, CH2 y CH3 ECG para Loop Readback
        x"00", x"01"  -- 17. CONFIG      -> Activar modo operativo de los ADCs e iniciar conversión
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
                    when STARTUP =>
                        d_valid <= '0';
                        if cfg_ptr < 17 then
                            cs_b <= '0'; -- Mantener el chip activo
                            if clk_cnt = 0 and bit_cnt = 7 and byte_cnt = 0 then
                                shift_out <= CONFIG_DATA(cfg_ptr * 2);
                                mosi <= CONFIG_DATA(cfg_ptr * 2)(7);
                            end if;
                            
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
                                        -- [CORREGIDO] NO subimos cs_b aquí para cumplir con tCSH del Datasheet
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

                    when STARTUP_HOLD =>
                        cs_b <= '1'; -- [CORREGIDO] Subir CS_B aquí añade 1 ciclo de reloj de retraso (Hold Time > 5ns)
                        sclk_reg <= '0';
                        mosi <= '0';
                        if clk_cnt = 20 then
                            clk_cnt <= 0;
                            cfg_ptr <= cfg_ptr + 1;
                            state <= STARTUP;
                        else
                            clk_cnt <= clk_cnt + 1;
                        end if;

                    when IDLE =>
                        d_valid <= '0';
                        cs_b <= '1';
                        sclk_reg <= '0';
                        clk_cnt <= 0;
                        bit_cnt <= 7;
                        byte_cnt <= 0;
                        if drdy_b = '0' then
                            cs_b <= '0';
                            shift_out <= x"B7"; -- Comando de lectura por ráfaga (0x37 | 0x80)
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
                                
                                -- Evaluación precisa basada en lógica no-bloqueante de VHDL
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
                        
                    when DONE =>
                        cs_b <= '1'; -- Desactivación correcta con Hold Time garantizado
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