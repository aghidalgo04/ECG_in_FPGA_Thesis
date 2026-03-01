library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity t_detector is
    Port (
        clk             : in  STD_LOGIC;
        reset           : in  STD_LOGIC;
        
        -- Entradas de Wavelet Escala 8
        d_valid         : in  STD_LOGIC;
        d_wavelet       : in  SIGNED(23 downto 0);
        
        -- QRS_DETECTOR
        start_trigger   : in  STD_LOGIC;
        rr_interval     : in  SIGNED(23 downto 0); -- Intervalo RR del QRS anterior
        
        qrs_mem_pmax    : in  SIGNED(23 downto 0);
        qrs_mem_pmin    : in  SIGNED(23 downto 0);

        -- Salidas
        t_detected      : out STD_LOGIC;
        
        -- Debug
        current_mem_t_pmax : out SIGNED(23 downto 0);
        current_mem_t_pmin : out SIGNED(23 downto 0)
    );
end t_detector;

architecture Behavioral of t_detector is

    type state_type is (
        ETAPA_1,    --  Ventana y Definir Polaridad T
        ETAPA_2,    --  Actualizar Memoria y Buscar Cruce P1
        ETAPA_3,    --  Buscar Pico 2 (Bifásica)
        ETAPA_4,    --  Actualizar Memoria y Buscar Cruce P2
        ETAPA_5     --  Comparación de Seguridad con QRS
    );
    signal state : state_type := ETAPA_1;

    -- Variables de Memoria para Onda T
    signal mem_pmax_t : signed(23 downto 0) := (others => '0');
    signal mem_pmin_t : signed(23 downto 0) := (others => '0');
    
    -- Polaridad de la Onda T (0: Positiva | 1: Negativa)
    signal t_n : std_logic := '0';

    -- Temporizadores y Ventanas
    signal cnt_window   : integer := 0;
    signal limit_window : integer := 0;

    -- Constantes de tiempo Sincronizadas (1kHz)
    -- 700 ms = 700 muestras
    constant TIME_700MS : signed(23 downto 0) := to_signed(700, 24); 
    
    -- Ventanas de búsqueda (en muestras de 1ms)
    constant WIN_100MS  : integer := 100; 
    constant WIN_140MS  : integer := 140;
    
    -- Umbral de cero ampliado para captar saltos rápidos
    constant VIRTUAL_ZERO : signed(23 downto 0) := to_signed(100000, 24);

begin
    -- Debug
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
                t_n <= '0';
            else
                t_detected <= '0';

                if d_valid = '1' then
                    
                    case state is
                        -- =====================================================
                        -- ETAPA 1: Definir Ventana y Polaridad
                        -- =====================================================
                        when ETAPA_1 =>
                            if start_trigger = '1' then
                                if rr_interval > TIME_700MS then 
                                    limit_window <= WIN_100MS;
                                else
                                    limit_window <= WIN_140MS;
                                end if;
                                cnt_window <= 1;
                            end if;
                            
                            if cnt_window > 0 then
                                if cnt_window > limit_window then
                                    cnt_window <= 0;
                                else
                                    cnt_window <= cnt_window + 1; 
                                    
                                    if d_wavelet > mem_pmax_t then
                                        t_n <= '0'; -- Positiva
                                        cnt_window <= 0; -- Apagar ventana
                                        state <= ETAPA_2; 
                                        
                                    elsif d_wavelet < mem_pmin_t then
                                        t_n <= '1'; -- Negativa
                                        cnt_window <= 0;
                                        state <= ETAPA_2;
                                    end if;
                                end if; 
                            end if;

                        -- =====================================================
                        -- ETAPA 2: Actualizar Memoria y Buscar Cruce P1
                        -- =====================================================
                        when ETAPA_2 =>
                            
                            if t_n = '0' then -- T Positiva
                                val_75_pmax := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmax > mem_pmax_t then
                                    mem_pmax_t <= val_75_pmax;
                                end if;
                                
                            else -- T Negativa
                                val_75_pmin := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmin < mem_pmin_t then
                                    mem_pmin_t <= val_75_pmin;
                                end if;
                            end if;

                            -- Detección cruce a cero
                            if abs(d_wavelet) <= VIRTUAL_ZERO then
                                state <= ETAPA_3;
                            end if;

                        -- =====================================================
                        -- ETAPA 3: Buscar Pico 2 o Rebote
                        -- =====================================================
                        when ETAPA_3 =>
                            if t_n = '0' then 
                                if d_wavelet < mem_pmin_t then
                                    state <= ETAPA_4;
                                end if;
                            else
                                if d_wavelet > mem_pmax_t then
                                    state <= ETAPA_4;
                                end if;
                            end if;
                            
                        -- =====================================================
                        -- ETAPA 4: Actualizar Rebote y Fin de Onda
                        -- =====================================================
                        when ETAPA_4 =>
                            if t_n = '1' then -- T Negativa(ahora positiva)
                                val_75_pmax := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmax > mem_pmax_t then
                                    mem_pmax_t <= val_75_pmax;
                                end if;
                                
                            else -- T Positiva
                                val_75_pmin := shift_right(d_wavelet, 1) + shift_right(d_wavelet, 2);
                                if val_75_pmin < mem_pmin_t then
                                    mem_pmin_t <= val_75_pmin;
                                end if;
                            end if;

                            -- Detección ruce cero
                            if abs(d_wavelet) <= VIRTUAL_ZERO then
                                state <= ETAPA_5;
                            end if;

                        -- =====================================================
                        -- ETAPA 5: Comparación de Seguridad con QRS
                        -- =====================================================
                        when ETAPA_5 =>
                            if mem_pmax_t > qrs_mem_pmax then
                                mem_pmax_t <= shift_right(mem_pmax_t, 1);
                            end if;
                            
                            if mem_pmin_t < qrs_mem_pmin then
                                mem_pmin_t <= shift_right(mem_pmin_t, 1);
                            end if;
                            
                            t_detected <= '1'; -- ONDA T!
                            state <= ETAPA_1;
                    end case;
                end if;
            end if;
        end if;
    end process;
end Behavioral;