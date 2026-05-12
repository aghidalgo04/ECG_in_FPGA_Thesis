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

    -- Restauramos los 5 estados originales
    type state_type is (ETAPA_1, ETAPA_2, ETAPA_3, ETAPA_4, ETAPA_5);
    signal state : state_type := ETAPA_1;

    signal mem_pmax : signed(23 downto 0) := (others => '0');
    signal mem_pmin : signed(23 downto 0) := (others => '0');
    
    signal qrs_n : std_logic := '0';
    constant TIME_40MS : integer := 40; 
    signal cnt_40ms    : integer := 0;
    constant TIME_3S   : integer := 3000;
    signal cnt_rr      : integer := 0; 

    -- Restaurado VIRTUAL_ZERO a 100.000 como estaba originalmente
    constant VIRTUAL_ZERO : signed(23 downto 0) := to_signed(100000, 24);

begin
    current_mem_pmax <= mem_pmax;
    current_mem_pmin <= mem_pmin;
    polarity <= qrs_n;

    process(clk)
        variable val_75_pmax : signed(23 downto 0);
        variable val_75_pmin : signed(23 downto 0);
        variable abs_pmin    : signed(23 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= ETAPA_1;
                mem_pmax <= (others => '0');
                mem_pmin <= (others => '0');
                qrs_detected <= '0';
                cnt_rr <= 0;
                cnt_40ms <= 0;
                qrs_n <= '0';
                time_rr <= (others => '0');
            else
                qrs_detected <= '0'; 

                if d_valid = '1' then
                    
                    -- === LÓGICA DE EQUILIBRADO DE UMBRALES (NUEVA) ===
                    -- Si pmax es mucho mayor que pmin (o viceversa), los igualamos en magnitud
                    abs_pmin := abs(mem_pmin);
                    if mem_pmax > shift_left(abs_pmin, 1) and abs_pmin > 0 then
                        mem_pmin <= -mem_pmax; -- Igualamos el pequeño al grande
                    elsif abs_pmin > shift_left(mem_pmax, 1) and mem_pmax > 0 then
                        mem_pmax <= abs_pmin;  -- Igualamos el pequeño al grande
                    end if;

                    -- Watchdog 3s
                    if cnt_rr < TIME_3S then
                        cnt_rr <= cnt_rr + 1;
                    else
                        cnt_rr <= 0;
                        mem_pmax <= shift_right(mem_pmax, 1); 
                        mem_pmin <= shift_right(mem_pmin, 1);
                        state <= ETAPA_1; 
                    end if;

                    case state is
                        when ETAPA_1 =>
                            if d_wavelet < mem_pmin then 
                                qrs_n <= '1';
                                state <= ETAPA_2;
                            elsif d_wavelet > mem_pmax then
                                qrs_n <= '0';
                                state <= ETAPA_2;
                            end if;

                        when ETAPA_2 =>
                            if qrs_n = '0' then 
                                val_75_pmax := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmax > mem_pmax then mem_pmax <= val_75_pmax; end if;
                                if (d_wavelet <= VIRTUAL_ZERO) then 
                                    time_rr <= to_signed(cnt_rr, 24);
                                    cnt_rr <= 0; 
                                    state <= ETAPA_3;
                                end if;
                            else 
                                val_75_pmin := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmin < mem_pmin then mem_pmin <= val_75_pmin; end if;
                                if (d_wavelet >= -VIRTUAL_ZERO) then 
                                    time_rr <= to_signed(cnt_rr, 24);
                                    cnt_rr <= 0; 
                                    state <= ETAPA_3;
                                end if;
                            end if;

                        when ETAPA_3 =>
                            if qrs_n = '0' then 
                                if d_wavelet < mem_pmin then
                                    state <= ETAPA_4;
                                end if;
                            else 
                                if d_wavelet > mem_pmax then
                                    state <= ETAPA_4;
                                end if;
                            end if;

                        when ETAPA_4 =>
                            if qrs_n = '1' then 
                                val_75_pmax := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmax > mem_pmax then mem_pmax <= val_75_pmax; end if;
                                if (d_wavelet <= VIRTUAL_ZERO) then
                                    qrs_detected <= '1'; 
                                    state <= ETAPA_5;
                                end if;
                            else 
                                val_75_pmin := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmin < mem_pmin then mem_pmin <= val_75_pmin; end if;
                                if (d_wavelet >= -VIRTUAL_ZERO) then
                                    qrs_detected <= '1'; 
                                    state <= ETAPA_5;
                                end if;
                            end if;

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