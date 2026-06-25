library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_controller is
    generic (
        CLK_FREQ  : integer := 100000000; 
        BAUD_RATE : integer := 115200
    );
    Port (
        clk             : in  STD_LOGIC;
        reset           : in  STD_LOGIC;
        d_valid         : in  STD_LOGIC;
        
        -- Señales Raw
        raw_x           : in  STD_LOGIC_VECTOR(23 downto 0);
        raw_y           : in  STD_LOGIC_VECTOR(23 downto 0);
        raw_z           : in  STD_LOGIC_VECTOR(23 downto 0);
        
        -- Wavelets
        s3_x, s3_y, s3_z : in  SIGNED(23 downto 0);
        s8_x, s8_y, s8_z : in  SIGNED(23 downto 0);
        
        -- Intervalos
        rr_interval_ms  : in  SIGNED(23 downto 0);
        rt_interval_ms  : in  SIGNED(23 downto 0);
        
        -- Eventos y Alarmas
        qrs_unified     : in  STD_LOGIC;
        t_unified       : in  STD_LOGIC;
        al_tachy        : in  STD_LOGIC;
        al_brady        : in  STD_LOGIC;
        al_arrh         : in  STD_LOGIC;
        al_asyst        : in  STD_LOGIC;
        al_death        : in  STD_LOGIC;
        
        -- Salida física
        tx              : out STD_LOGIC := '1'
    );
end uart_controller;

architecture Behavioral of uart_controller is

    constant CLKS_PER_BIT : integer := CLK_FREQ / BAUD_RATE;
    
    -- Máquina de estados UART
    type tx_state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal tx_state : tx_state_type := IDLE;
    
    signal clk_count : integer := 0;
    signal bit_index : integer range 0 to 7 := 0;
    signal tx_data   : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_active : std_logic := '0';
    signal tx_start  : std_logic := '0';
    
    -- Trama de 37 Bytes
    type frame_array is array (0 to 36) of std_logic_vector(7 downto 0);
    signal frame_buffer : frame_array;
    
    signal sending_frame : boolean := false;
    signal byte_index    : integer range 0 to 37 := 0;

    signal qrs_aux : std_logic := '0';
    signal t_aux   : std_logic := '0';

begin

    -- Prolongación de detección de ondas(Al enviar parte de la información, es necesario evtar pérdida de información de las ondas)
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                qrs_aux <= '0';
                t_aux   <= '0';
            else
                if qrs_unified = '1' then qrs_aux <= '1'; end if;
                if t_unified   = '1' then t_aux   <= '1'; end if;
                
                if d_valid = '1' and not sending_frame then
                    qrs_aux <= '0';
                    t_aux   <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Guardado de datos en la trama
    process(clk)
        variable flags_byte : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                sending_frame <= false;
                byte_index <= 0;
                tx_start <= '0';
            else
                tx_start <= '0';
                
                if d_valid = '1' then
                    if not sending_frame then
                        
                        -- Cabecera
                        frame_buffer(0) <= x"AA";
                        frame_buffer(1) <= x"BB";
                        
                        -- Señales crudas
                        frame_buffer(2) <= raw_x(23 downto 16); 
                        frame_buffer(3) <= raw_x(15 downto 8); 
                        frame_buffer(4) <= raw_x(7 downto 0);
                        frame_buffer(5) <= raw_y(23 downto 16); 
                        frame_buffer(6) <= raw_y(15 downto 8); 
                        frame_buffer(7) <= raw_y(7 downto 0);
                        frame_buffer(8) <= raw_z(23 downto 16); 
                        frame_buffer(9) <= raw_z(15 downto 8); 
                        frame_buffer(10)<= raw_z(7 downto 0);
                        
                        -- Wavelet S3
                        frame_buffer(11) <= std_logic_vector(s3_x(23 downto 16)); 
                        frame_buffer(12) <= std_logic_vector(s3_x(15 downto 8)); 
                        frame_buffer(13) <= std_logic_vector(s3_x(7 downto 0));
                        frame_buffer(14) <= std_logic_vector(s3_y(23 downto 16)); 
                        frame_buffer(15) <= std_logic_vector(s3_y(15 downto 8)); 
                        frame_buffer(16) <= std_logic_vector(s3_y(7 downto 0));
                        frame_buffer(17) <= std_logic_vector(s3_z(23 downto 16)); 
                        frame_buffer(18) <= std_logic_vector(s3_z(15 downto 8)); 
                        frame_buffer(19) <= std_logic_vector(s3_z(7 downto 0));

                        -- Wavelet S8
                        frame_buffer(20) <= std_logic_vector(s8_x(23 downto 16)); 
                        frame_buffer(21) <= std_logic_vector(s8_x(15 downto 8)); 
                        frame_buffer(22) <= std_logic_vector(s8_x(7 downto 0));
                        frame_buffer(23) <= std_logic_vector(s8_y(23 downto 16)); 
                        frame_buffer(24) <= std_logic_vector(s8_y(15 downto 8)); 
                        frame_buffer(25) <= std_logic_vector(s8_y(7 downto 0));
                        frame_buffer(26) <= std_logic_vector(s8_z(23 downto 16)); 
                        frame_buffer(27) <= std_logic_vector(s8_z(15 downto 8)); 
                        frame_buffer(28) <= std_logic_vector(s8_z(7 downto 0));

                        -- Intervalos
                        frame_buffer(29) <= std_logic_vector(rr_interval_ms(23 downto 16)); 
                        frame_buffer(30) <= std_logic_vector(rr_interval_ms(15 downto 8)); 
                        frame_buffer(31) <= std_logic_vector(rr_interval_ms(7 downto 0));
                        frame_buffer(32) <= std_logic_vector(rt_interval_ms(23 downto 16)); 
                        frame_buffer(33) <= std_logic_vector(rt_interval_ms(15 downto 8)); 
                        frame_buffer(34) <= std_logic_vector(rt_interval_ms(7 downto 0));

                        -- Bit de validacón
                        flags_byte(7) := '1'; -- Bit de validación
                        
                        -- Alarmas y detección de ondas
                        flags_byte(6) := qrs_aux or qrs_unified;
                        flags_byte(5) := t_aux or t_unified;
                        
                        flags_byte(4) := al_tachy;
                        flags_byte(3) := al_brady;
                        flags_byte(2) := al_arrh;
                        flags_byte(1) := al_asyst;
                        flags_byte(0) := al_death;
                        frame_buffer(35) <= flags_byte;

                        -- Fin de Trama (\n)
                        frame_buffer(36) <= x"0A"; 

                        sending_frame <= true;
                        byte_index <= 0;
                    end if;
                end if;
                
                if sending_frame and tx_active = '0' and tx_start = '0' then
                    tx_data <= frame_buffer(byte_index);
                    tx_start <= '1';
                    
                    if byte_index = 36 then
                        sending_frame <= false;
                    else
                        byte_index <= byte_index + 1;
                    end if;
                end if;
                
            end if;
        end if;
    end process;

    -- Máquina de estados UART
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                tx <= '1';
                tx_active <= '0';
                tx_state <= IDLE;
                clk_count <= 0;
                bit_index <= 0;
            else
                case tx_state is
                
                -- Estado reposo
                    when IDLE =>
                        tx <= '1';
                        tx_active <= '0';
                        if tx_start = '1' then
                            tx_active <= '1';
                            tx_state <= START_BIT;
                            clk_count <= 0;
                        end if;
                        
                    -- Envío del START bit
                    when START_BIT =>
                        tx <= '0';
                        if clk_count < CLKS_PER_BIT - 1 then
                            clk_count <= clk_count + 1;
                        else
                            clk_count <= 0;
                            tx_state <= DATA_BITS;
                            bit_index <= 0;
                        end if;
                    
                    -- Envío de la trama
                    when DATA_BITS =>
                        tx <= tx_data(bit_index);
                        if clk_count < CLKS_PER_BIT - 1 then
                            clk_count <= clk_count + 1;
                        else
                            clk_count <= 0;
                            if bit_index < 7 then
                                bit_index <= bit_index + 1;
                            else
                                tx_state <= STOP_BIT;
                            end if;
                        end if;
                        
                    -- Envío del STOP bit
                    when STOP_BIT =>
                        tx <= '1';
                        if clk_count < CLKS_PER_BIT - 1 then
                            clk_count <= clk_count + 1;
                        else
                            clk_count <= 0;
                            tx_state <= IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;

end Behavioral;