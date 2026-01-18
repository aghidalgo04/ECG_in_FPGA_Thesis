library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity qrst_detection is
    Port (
        clk             : in  STD_LOGIC;
        reset           : in  STD_LOGIC;
        
        -- ENTRADAS (wavelet_3d_transform)
        d_valid_s3      : in  STD_LOGIC;           
        d_energy_s3     : in  SIGNED(23 downto 0); -- Energía para detectar QRS
        
        d_valid_s8      : in  STD_LOGIC;           -- Validez Escala 8 (Lenta)
        d_energy_s8     : in  SIGNED(23 downto 0); -- Energía para detectar Onda T
        
        -- SALIDAS
        qrs_detected    : out STD_LOGIC; -- Pulso cuando ocurre QRS
        t_detected      : out STD_LOGIC -- Pulso cuando acaba la Onda T
    );
end qrst_detection;

architecture Behavioral of qrst_detection is

    -- === COMPONENTES ===
    component qrs_detector is
        Port (
            clk : in STD_LOGIC;
            reset : in STD_LOGIC;
            d_valid : in STD_LOGIC;
            d_energy : in SIGNED(23 downto 0);
            qrs_detected : out STD_LOGIC;
            
            -- Nuevo puerto necesario para exponer la memoria interna al detector T
            current_mem_pmax : out SIGNED(23 downto 0) 
        );
    end component;

    component t_detector is
        Port (
            clk : in STD_LOGIC;
            reset : in STD_LOGIC;
            d_valid : in STD_LOGIC;
            d_energy : in SIGNED(23 downto 0);
            qrs_trigger : in STD_LOGIC;
            rr_interval : in INTEGER;
            qrs_mem_pmax : in SIGNED(23 downto 0);
            t_detected : out STD_LOGIC
        );
    end component;

    -- === SEÑALES INTERNAS ===
    signal qrs_pulse_internal : std_logic;
    signal mem_pmax_qrs       : signed(23 downto 0);
    
    -- Medición de RR (Ritmo Cardiaco)
    signal rr_counter         : integer := 0;
    signal rr_value_latched   : integer := 70_000_000; -- Valor inicial (700ms)

begin

    -- =========================================================
    -- 1. DETECTOR QRS
    -- =========================================================ç
    INST_QRS: qrs_detector
    port map (
        clk => clk,
        reset => reset,
        d_valid => d_valid_s3,
        d_energy => d_energy_s3,
        qrs_detected => qrs_pulse_internal,
        
        current_mem_pmax => mem_pmax_qrs 
    );
    
    -- Sacamos el pulso QRS hacia afuera también
    qrs_detected <= qrs_pulse_internal;

    -- =========================================================
    -- 2. CÁLCULO DEL INTERVALO RR (Para la ventana de la T)
    -- =========================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                rr_counter <= 0;
                rr_value_latched <= 70_000_000; -- Default 700ms
            else
                -- Cuenta siempre
                if rr_counter < 200_000_000 then -- Límite 2 seg
                    rr_counter <= rr_counter + 1;
                end if;
                
                if qrs_pulse_internal = '1' then
                    rr_value_latched <= rr_counter;
                    rr_counter <= 0;
                end if;
            end if;
        end if;
    end process;

    -- =========================================================
    -- 3. INSTANCIA DETECTOR ONDA T
    -- =========================================================
    INST_T_WAVE: t_detector
    port map (
        clk => clk,
        reset => reset,
        d_valid => d_valid_s8,
        d_energy => d_energy_s8,
        
        qrs_trigger => qrs_pulse_internal,
        rr_interval => rr_value_latched,
        qrs_mem_pmax => mem_pmax_qrs,
        
        t_detected => t_detected
    );
    

end Behavioral;