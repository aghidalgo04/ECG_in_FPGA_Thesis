library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity qrs_detector is
    Port (
        clk                 : in  STD_LOGIC;
        reset               : in  STD_LOGIC;
        
        -- Entradas
        d_valid             : in  STD_LOGIC;
        d_wavelet           : in  SIGNED(23 downto 0);
        
        -- Salidas
        qrs_detected        : out STD_LOGIC;
        polarity            : out STD_LOGIC; -- 0: Positivo, 1: Negativo (QRS_N)
        
        -- T_DETECTOR
        time_rr              : out SIGNED(23 downto 0);
        current_mem_pmax    : out SIGNED(23 downto 0);
        current_mem_pmin    : out SIGNED(23 downto 0)
    );
end qrs_detector;

architecture Behavioral of qrs_detector is

    -- === DEFINICIÓN DE ESTADOS (5 ETAPAS) ===
    type state_type is (
        ETAPA_1,    -- Detectar Primer Pico (Pmax o Pmin)
        ETAPA_2,    -- Actualizar Pico 1 y Buscar Cruce Cero (P1)
        ETAPA_3,    -- Detectar Segundo Pico (Rebote)
        ETAPA_4,    -- Actualizar Pico 2 y Buscar Cruce Cero (P2)
        ETAPA_5     -- Espera de 40ms
    );
    signal state : state_type := ETAPA_1;

    -- === VARIABLES DE MEMORIA ADAPTATIVAS ===
    signal mem_pmax : signed(23 downto 0) := (others => '0');
    signal mem_pmin : signed(23 downto 0) := (others => '0');
    
    -- "QRS_N": Variable de estado de polaridad (0: QRS Positivo | 1: QRS Negativo)
    signal qrs_n : std_logic := '0';

    -- === TEMPORIZADORES SINCRONIZADOS (1kHz) ===
    constant TIME_40MS : integer := 40; 
    signal cnt_40ms    : integer := 0;

    -- Watchdog 3 segundos (3000 muestras)
    constant TIME_3S   : integer := 3000;
    signal cnt_rr      : integer := 0; 

    -- Umbral de cero ampliado para captar saltos rápidos
    constant VIRTUAL_ZERO : signed(23 downto 0) := to_signed(100000, 24);

begin
    -- Asignaciones continuas de salida
    current_mem_pmax <= mem_pmax;
    current_mem_pmin <= mem_pmin;
    polarity <= qrs_n;

    process(clk)
        -- Variables auxiliares para cálculos
        variable val_75_pmax : signed(23 downto 0);
        variable val_75_pmin : signed(23 downto 0);
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
                    
                    -- === PROTECCIÓN WATCHDOG (Sincronizada con d_valid) ===
                    if cnt_rr < TIME_3S then
                        cnt_rr <= cnt_rr + 1;
                    else
                        cnt_rr <= 0;
                        mem_pmax <= shift_right(mem_pmax, 1); 
                        mem_pmin <= shift_right(mem_pmin, 1);
                        state <= ETAPA_1; 
                    end if;

                    case state is
                        
                        -- =========================================================
                        -- ETAPA 1: Detección del Primer Pico (Inicio QRS)
                        -- =========================================================
                        when ETAPA_1 =>
                            if d_wavelet < mem_pmin then 
                                qrs_n <= '1';
                                state <= ETAPA_2;
                            elsif d_wavelet > mem_pmax then
                                qrs_n <= '0';
                                state <= ETAPA_2;
                            end if;

                        -- =========================================================
                        -- ETAPA 2: Actualizar Pmax/Pmin y Buscar Cruce P1
                        -- =========================================================
                        when ETAPA_2 =>
                            if qrs_n = '0' then 
                                val_75_pmax := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmax > mem_pmax then
                                     mem_pmax <= val_75_pmax;
                                end if;
                            else 
                                val_75_pmin := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmin < mem_pmin then
                                     mem_pmin <= val_75_pmin;
                                end if;
                            end if;

                            if (abs(d_wavelet) <= VIRTUAL_ZERO) then 
                                time_rr <= to_signed(cnt_rr, 24);
                                cnt_rr <= 0; 
                                state <= ETAPA_3;
                            end if;

                        -- =========================================================
                        -- ETAPA 3: Detectar Segundo Pico (Rebote Bifásico)
                        -- =========================================================
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
                            
                        -- =========================================================
                        -- ETAPA 4: Actualizar Pico 2 y Buscar P2 (Final QRS)
                        -- =========================================================
                        when ETAPA_4 =>
                            if qrs_n = '1' then 
                                val_75_pmax := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmax > mem_pmax then
                                     mem_pmax <= val_75_pmax;
                                end if;
                            else 
                                val_75_pmin := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmin < mem_pmin then
                                     mem_pmin <= val_75_pmin;
                                end if;
                            end if;

                            if (abs(d_wavelet) <= VIRTUAL_ZERO) then
                                qrs_detected <= '1'; 
                                state <= ETAPA_5;
                            end if;

                        -- =========================================================
                        -- ETAPA 5: Refractario 40 ms (40 muestras)
                        -- =========================================================
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