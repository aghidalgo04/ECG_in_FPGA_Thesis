library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity t_detector is
    Port (
        clk                : in  STD_LOGIC;
        reset              : in  STD_LOGIC;
        
        --Entradas
        --Señal S8 (Wavelet)
        d_valid            : in  STD_LOGIC;
        d_wavelet          : in  SIGNED(23 downto 0); 
        start_trigger      : in  STD_LOGIC;
        
        -- Intervalo RR y umbrales (QRS_Detector)
        rr_interval        : in  SIGNED(23 downto 0);
        qrs_mem_pmax       : in  SIGNED(23 downto 0);
        qrs_mem_pmin       : in  SIGNED(23 downto 0);
        
        -- Salidas (Bridge)
        t_detected         : out STD_LOGIC := '0';
        t_mem_pmax : out SIGNED(23 downto 0) := (others => '0');
        t_mem_pmin : out SIGNED(23 downto 0) := (others => '0')
    );
end t_detector;

architecture Behavioral of t_detector is
    type state_type is (ETAPA_1, ETAPA_2, ETAPA_3, ETAPA_4, ETAPA_5);
    signal state : state_type := ETAPA_1;

    -- Umbrales predefinidos para evitar falsos positivos
    signal mem_pmax : signed(23 downto 0) := to_signed(300000, 24);
    signal mem_pmin : signed(23 downto 0) := to_signed(-300000, 24);
    
    signal hold_pmax : signed(23 downto 0) := (others => '0');
    signal hold_pmin : signed(23 downto 0) := (others => '0');

    signal t_n : std_logic := '0';
    signal cnt_window   : integer := 0;
    signal limit_window : integer := 0;
    
    constant VIRTUAL_ZERO : signed(23 downto 0) := to_signed(100000, 24);

begin
    t_mem_pmax <= mem_pmax;
    t_mem_pmin <= mem_pmin;

    process(clk)
        variable abs_pmin : signed(23 downto 0);
        variable calc_win   : integer;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= ETAPA_1;
                mem_pmax <= to_signed(300000, 24);
                mem_pmin <= to_signed(-300000, 24);
                t_detected <= '0';
                cnt_window <= 0;
                limit_window <= 170;
            else
                t_detected <= '0';

                -- Ajustar umbrales para seguir detectando aunque la señal decrezca
                abs_pmin := abs(mem_pmin);
                if mem_pmax > shift_left(abs_pmin, 1) and abs_pmin > 0 then
                    mem_pmin <= -mem_pmax;
                elsif abs_pmin > shift_left(mem_pmax, 1) and mem_pmax > 0 then
                    mem_pmax <= abs_pmin;
                end if;

                -- Cálculo de periodo de espera
                if start_trigger = '1' then
                    
                    -- RR_ms/8 + RR_ms/16 equivale al ~52% del latido.
                    calc_win := to_integer(shift_right(rr_interval, 3)) + to_integer(shift_right(rr_interval, 4));
                    
                    -- Minimo de seguridad
                    if calc_win < 100 then
                        limit_window <= 170; 
                    else
                        limit_window <= calc_win;
                    end if;
                    
                    cnt_window <= 1;
                    state <= ETAPA_1;
                end if;

                if d_valid = '1' then
                    case state is
                        -- ETAPA 1: Espera tras latido
                        when ETAPA_1 =>
                            hold_pmax <= (others => '0');
                            hold_pmin <= (others => '0');
                            if cnt_window > 0 then
                                if cnt_window >= limit_window then
                                    cnt_window <= 0;
                                    state <= ETAPA_2; 
                                else
                                    cnt_window <= cnt_window + 1; 
                                end if; 
                            end if;

                        -- ETAPA 2: Buscar primer pico T (Entrada al 50% de la memoria)
                        when ETAPA_2 =>
                            if d_wavelet > hold_pmax then hold_pmax <= d_wavelet; end if;
                            if d_wavelet < hold_pmin then hold_pmin <= d_wavelet; end if;

                            if d_wavelet > shift_right(mem_pmax, 1) then
                                t_n <= '0';
                            elsif d_wavelet < shift_right(mem_pmin, 1) then
                                t_n <= '1';
                            end if;

                            if (abs(d_wavelet) <= VIRTUAL_ZERO) and 
                               (hold_pmax > 80000 or hold_pmin < -80000) then
                                state <= ETAPA_3;
                            end if;

                        -- ETAPA 3: Buscar espejo negativo
                        when ETAPA_3 =>
                            if d_wavelet > hold_pmax then hold_pmax <= d_wavelet; end if;
                            if d_wavelet < hold_pmin then hold_pmin <= d_wavelet; end if;

                            if (t_n = '0' and d_wavelet < shift_right(mem_pmin, 2)) or 
                               (t_n = '1' and d_wavelet > shift_right(mem_pmax, 2)) then
                                state <= ETAPA_4;
                            end if;
                            
                        -- ETAPA 4: Final de onda T y actualizacion de umbrales
                        when ETAPA_4 =>
                            if d_wavelet > hold_pmax then hold_pmax <= d_wavelet; end if;
                            if d_wavelet < hold_pmin then hold_pmin <= d_wavelet; end if;

                            if abs(d_wavelet) <= VIRTUAL_ZERO then
                                
                                -- Minimo de seguridad (150.000)
                                if shift_right(hold_pmax, 1) < to_signed(150000, 24) then
                                    mem_pmax <= to_signed(150000, 24);
                                else
                                    mem_pmax <= shift_right(hold_pmax, 1);
                                end if;

                                if shift_right(hold_pmin, 1) > to_signed(-150000, 24) then
                                    mem_pmin <= to_signed(-150000, 24);
                                else
                                    mem_pmin <= shift_right(hold_pmin, 1);
                                end if;
                                
                                state <= ETAPA_5;
                            end if;

                        -- ETAPA 5: Pulso de salida
                        when ETAPA_5 =>
                            if mem_pmax > shift_right(qrs_mem_pmax, 1) then
                                mem_pmax <= shift_right(qrs_mem_pmax, 2);
                            end if;
                            t_detected <= '1'; 
                            state <= ETAPA_1;
                    end case;
                end if;
            end if;
        end if;
    end process;
end Behavioral;