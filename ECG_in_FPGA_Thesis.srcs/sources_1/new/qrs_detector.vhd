library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity qrs_detector is
    Port (
        clk                 : in  STD_LOGIC;
        reset               : in  STD_LOGIC;
        d_valid             : in  STD_LOGIC;
        d_wavelet           : in  SIGNED(23 downto 0);
        qrs_detected        : out STD_LOGIC := '0';
        polarity            : out STD_LOGIC := '0'; 
        time_rr             : out SIGNED(23 downto 0) := (others => '0');
        current_mem_pmax    : out SIGNED(23 downto 0) := (others => '0');
        current_mem_pmin    : out SIGNED(23 downto 0) := (others => '0')
    );
end qrs_detector;

architecture Behavioral of qrs_detector is

    -- 5 Estados originales de la tesis
    type state_type is (ETAPA_1, ETAPA_2, ETAPA_3, ETAPA_4, ETAPA_5);
    signal state : state_type := ETAPA_1;

    -- Memorias de umbral (Oficiales)
    signal mem_pmax : signed(23 downto 0) := to_signed(1000000, 24);
    signal mem_pmin : signed(23 downto 0) := to_signed(-1000000, 24);
    
    -- REGISTROS HOLD: Capturan el pico real (100%) del latido en curso
    signal hold_pmax : signed(23 downto 0) := (others => '0');
    signal hold_pmin : signed(23 downto 0) := (others => '0');
    
    signal qrs_n : std_logic := '0';
    constant TIME_40MS : integer := 40; 
    signal cnt_40ms    : integer := 0;
    constant TIME_3S   : integer := 3000;
    signal cnt_rr      : integer := 0; 

    constant VIRTUAL_ZERO : signed(23 downto 0) := to_signed(100000, 24);

begin
    current_mem_pmax <= mem_pmax;
    current_mem_pmin <= mem_pmin;
    polarity <= qrs_n;

    process(clk)
        variable abs_pmin : signed(23 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= ETAPA_1;
                mem_pmax <= to_signed(1000000, 24);
                mem_pmin <= to_signed(-1000000, 24);
                qrs_detected <= '0';
                cnt_rr <= 0;
                cnt_40ms <= 0;
                hold_pmax <= (others => '0');
                hold_pmin <= (others => '0');
            else
                qrs_detected <= '0'; 

                if d_valid = '1' then
                    
                    -- === 1. LÓGICA DE EQUILIBRADO DE UMBRALES ===
                    abs_pmin := abs(mem_pmin);
                    if mem_pmax > shift_left(abs_pmin, 1) and abs_pmin > 0 then
                        mem_pmin <= -mem_pmax;
                    elsif abs_pmin > shift_left(mem_pmax, 1) and mem_pmax > 0 then
                        mem_pmax <= abs_pmin;
                    end if;

                    -- === 2. WATCHDOG 3S ===
                    if cnt_rr < TIME_3S then
                        cnt_rr <= cnt_rr + 1;
                    else
                        cnt_rr <= 0;
                        mem_pmax <= shift_right(mem_pmax, 1); 
                        mem_pmin <= shift_right(mem_pmin, 1);
                        state <= ETAPA_1; 
                    end if;

                    case state is
                        -- ETAPA 1: Buscar superar el umbral actual (25% del anterior)
                        when ETAPA_1 =>
                            hold_pmax <= (others => '0');
                            hold_pmin <= (others => '0');
                            if d_wavelet < mem_pmin then 
                                qrs_n <= '1';
                                hold_pmin <= d_wavelet;
                                state <= ETAPA_2;
                            elsif d_wavelet > mem_pmax then
                                qrs_n <= '0';
                                hold_pmax <= d_wavelet;
                                state <= ETAPA_2;
                            end if;

                        -- ETAPA 2: Trackear picos y buscar primer cruce
                        when ETAPA_2 =>
                            if d_wavelet > hold_pmax then hold_pmax <= d_wavelet; end if;
                            if d_wavelet < hold_pmin then hold_pmin <= d_wavelet; end if;

                            if (qrs_n = '0' and d_wavelet <= VIRTUAL_ZERO) or 
                               (qrs_n = '1' and d_wavelet >= -VIRTUAL_ZERO) then
                                time_rr <= to_signed(cnt_rr, 24);
                                cnt_rr <= 0; 
                                state <= ETAPA_3;
                            end if;

                        -- ETAPA 3: Rebote biphasic
                        when ETAPA_3 =>
                            if d_wavelet > hold_pmax then hold_pmax <= d_wavelet; end if;
                            if d_wavelet < hold_pmin then hold_pmin <= d_wavelet; end if;

                            if (qrs_n = '0' and d_wavelet < mem_pmin) or 
                               (qrs_n = '1' and d_wavelet > mem_pmax) then
                                state <= ETAPA_4;
                            end if;

                        -- ETAPA 4: Confirmación y ACTUALIZACIÓN OBLIGATORIA AL 75%
                        when ETAPA_4 =>
                            if d_wavelet > hold_pmax then hold_pmax <= d_wavelet; end if;
                            if d_wavelet < hold_pmin then hold_pmin <= d_wavelet; end if;

                            if (qrs_n = '0' and d_wavelet >= -VIRTUAL_ZERO) or 
                               (qrs_n = '1' and d_wavelet <= VIRTUAL_ZERO) then
                                
                                -- AQUÍ ACTUALIZAMOS SIEMPRE (Pico actual * 0.75)
                                -- Independientemente de si el latido fue mayor o menor
                                mem_pmax <= shift_right(hold_pmax, 1) + shift_right(hold_pmax, 2);
                                mem_pmin <= shift_right(hold_pmin, 1) + shift_right(hold_pmin, 2);
                                
                                qrs_detected <= '1'; 
                                state <= ETAPA_5;
                            end if;

                        -- ETAPA 5: Refractario
                        when ETAPA_5 =>
                            if cnt_40ms < TIME_40MS then
                                cnt_40ms <= cnt_40ms + 1;
                            else
                                cnt_40ms <= 0;
                                state <= ETAPA_1;
                            end if;
                    end case;
                end if; 
            end if; 
        end if; 
    end process;
end Behavioral;