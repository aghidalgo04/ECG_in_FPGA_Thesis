library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity t_detector is
    Port (
        clk                : in  STD_LOGIC;
        reset              : in  STD_LOGIC;
        d_valid            : in  STD_LOGIC;
        d_wavelet          : in  SIGNED(23 downto 0);
        start_trigger      : in  STD_LOGIC;
        rr_interval        : in  SIGNED(23 downto 0);
        qrs_mem_pmax       : in  SIGNED(23 downto 0);
        qrs_mem_pmin       : in  SIGNED(23 downto 0);
        
        -- Salidas inicializadas para evitar estados 'U'
        t_detected         : out STD_LOGIC := '0';
        current_mem_t_pmax : out SIGNED(23 downto 0) := (others => '0');
        current_mem_t_pmin : out SIGNED(23 downto 0) := (others => '0')
    );
end t_detector;

architecture Behavioral of t_detector is
    type state_type is (ETAPA_1, ETAPA_2, ETAPA_3, ETAPA_4, ETAPA_5);
    signal state : state_type := ETAPA_1;

    signal mem_pmax_t : signed(23 downto 0) := (others => '0');
    signal mem_pmin_t : signed(23 downto 0) := (others => '0');
    signal t_n : std_logic := '0';
    signal cnt_window   : integer := 0;
    signal limit_window : integer := 0;

    constant TIME_700MS : signed(23 downto 0) := to_signed(700, 24); 
    constant WIN_FAST   : integer := 60; 
    constant WIN_NORMAL : integer := 90;
    
    -- Umbral de cero
    constant VIRTUAL_ZERO : signed(23 downto 0) := to_signed(100000, 24);

begin
    current_mem_t_pmax <= mem_pmax_t;
    current_mem_t_pmin <= mem_pmin_t;

    process(clk)
        variable val_75_pmax : signed(23 downto 0);
        variable val_75_pmin : signed(23 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= ETAPA_1;
                mem_pmax_t <= (others => '0');
                mem_pmin_t <= (others => '0');
                t_detected <= '0';
                cnt_window <= 0;
            else
                t_detected <= '0';

                if start_trigger = '1' then
                    if rr_interval > TIME_700MS then 
                        limit_window <= WIN_FAST;
                    else
                        limit_window <= WIN_NORMAL;
                    end if;
                    cnt_window <= 1;
                    state <= ETAPA_1;
                end if;

                if d_valid = '1' then
                    case state is
                        when ETAPA_1 =>
                            if cnt_window > 0 then
                                if cnt_window >= limit_window then
                                    cnt_window <= 0;
                                    state <= ETAPA_2; 
                                else
                                    cnt_window <= cnt_window + 1; 
                                end if; 
                            end if;

                        when ETAPA_2 =>
                            -- Buscamos el primer pico (el más grande)
                            if d_wavelet > mem_pmax_t then
                                mem_pmax_t <= d_wavelet;
                                t_n <= '0';
                            elsif d_wavelet < mem_pmin_t then
                                mem_pmin_t <= d_wavelet;
                                t_n <= '1';
                            end if;

                            -- Solo salimos si el pico es válido Y estamos volviendo al cero
                            if (abs(d_wavelet) <= VIRTUAL_ZERO) then
                                if (mem_pmax_t > shift_right(qrs_mem_pmax, 3)) or 
                                   (mem_pmin_t < shift_right(qrs_mem_pmin, 3)) then
                                    state <= ETAPA_3;
                                end if;
                            end if;

                        when ETAPA_3 =>
                            -- Buscamos que la señal entre en la polaridad opuesta
                            if t_n = '0' then 
                                if d_wavelet < -VIRTUAL_ZERO then 
                                    state <= ETAPA_4;
                                end if;
                            else
                                if d_wavelet > VIRTUAL_ZERO then 
                                    state <= ETAPA_4;
                                end if;
                            end if;
                            
                        when ETAPA_4 =>
                            -- Actualizamos el segundo pico (el más pequeño)
                            if t_n = '1' then 
                                val_75_pmax := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmax > mem_pmax_t then mem_pmax_t <= val_75_pmax; end if;
                            else 
                                val_75_pmin := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmin < mem_pmin_t then mem_pmin_t <= val_75_pmin; end if;
                            end if;

                            -- DETECCIÓN FINAL: Cuando volvemos a cero tras el segundo pico
                            if abs(d_wavelet) <= VIRTUAL_ZERO then
                                state <= ETAPA_5;
                            end if;

                        when ETAPA_5 =>
                            if mem_pmax_t > qrs_mem_pmax then
                                mem_pmax_t <= shift_right(mem_pmax_t, 1);
                            end if;
                            if mem_pmin_t < qrs_mem_pmin then
                                mem_pmin_t <= shift_right(mem_pmin_t, 1);
                            end if;
                            t_detected <= '1'; 
                            state <= ETAPA_1;
                    end case;
                end if;
            end if;
        end if;
    end process;
end Behavioral;