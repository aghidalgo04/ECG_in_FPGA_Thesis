library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity detection_module is
    Port ( 
        clk                  : in  STD_LOGIC;
        reset                : in  STD_LOGIC;
        d_valid              : in  STD_LOGIC;
        qrs_unified          : in  STD_LOGIC;
        t_unified            : in  STD_LOGIC;
        rr_interval_ms       : in  SIGNED(23 downto 0);
        rt_interval_ms       : in  SIGNED(23 downto 0);
        
        -- Alertas de salida
        alarm_tachycardia    : out STD_LOGIC;
        alarm_bradycardia    : out STD_LOGIC;
        alarm_arrhythmia     : out STD_LOGIC;
        alarm_asystole       : out STD_LOGIC;
        alarm_sudden_death   : out STD_LOGIC
    );
end detection_module;

architecture Behavioral of detection_module is

    -- Umbrales clínicos
    constant THRESHOLD_TACHY      : integer := 600;  -- < 600ms (100 BPM)
    constant THRESHOLD_BRADY      : integer := 1200; -- > 1200ms (50 BPM)
    constant THRESHOLD_ASYSTOLE   : integer := 3000; -- 3 segundos
    constant THRESHOLD_LONG_QT    : integer := 450;  -- Riesgo Muerte Súbita

    -- Señales internas de memoria
    signal last_rr_ms      : SIGNED(23 downto 0) := (others => '0');
    signal last_rr_valid   : STD_LOGIC := '0'; -- Flag para ignorar el primer latido
    
    -- Watchdog para Asistolia
    signal asystole_cnt    : integer := 0;
    
    -- Señales de alarma internas para poder leerlas
    signal tachy_i, brady_i, arrh_i, death_i, asyst_i : STD_LOGIC := '0';

begin

    -- Asignación de salidas con jerarquía (Si hay asistolia, se limpian las otras)
    alarm_asystole     <= asyst_i;
    alarm_tachycardia  <= tachy_i and (not asyst_i);
    alarm_bradycardia  <= brady_i and (not asyst_i);
    alarm_arrhythmia   <= arrh_i  and (not asyst_i);
    alarm_sudden_death <= death_i and (not asyst_i);

    process(clk)
        variable diff_rr : SIGNED(23 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                tachy_i      <= '0';
                brady_i      <= '0';
                arrh_i       <= '0';
                death_i      <= '0';
                asyst_i      <= '0';
                asystole_cnt <= 0;
                last_rr_ms   <= (others => '0');
                last_rr_valid <= '0';
            else
                -- 1. WATCHDOG DE ASISTOLIA (Se incrementa cada ms con d_valid)
                if d_valid = '1' then
                    if asystole_cnt >= THRESHOLD_ASYSTOLE then
                        asyst_i <= '1';
                    else
                        asystole_cnt <= asystole_cnt + 1;
                        asyst_i <= '0';
                    end if;
                end if;

                -- 2. LÓGICA TRAS DETECTAR QRS (RR-dependiente)
                if qrs_unified = '1' then
                    asystole_cnt <= 0; -- Reset watchdog
                    
                    -- Taquicardia
                    if rr_interval_ms < THRESHOLD_TACHY then
                        tachy_i <= '1';
                    else
                        tachy_i <= '0';
                    end if;

                    -- Bradicardia
                    if rr_interval_ms > THRESHOLD_BRADY then
                        brady_i <= '1';
                    else
                        brady_i <= '0';
                    end if;

                    -- ARRITMIA (Protección contra primer latido)
                    if last_rr_valid = '1' then
                        diff_rr := abs(rr_interval_ms - last_rr_ms);
                        -- Si la variación es > 25% del latido anterior
                        if diff_rr > shift_right(last_rr_ms, 2) then 
                            arrh_i <= '1';
                        else
                            arrh_i <= '0';
                        end if;
                    else
                        last_rr_valid <= '1'; -- A partir de ahora ya podemos comparar
                        arrh_i <= '0';
                    end if;

                    last_rr_ms <= rr_interval_ms; -- Guardar para la siguiente comparativa
                end if;

                -- 3. LÓGICA TRAS DETECTAR ONDA T (QT-dependiente)
                if t_unified = '1' then
                    if rt_interval_ms > THRESHOLD_LONG_QT then
                        death_i <= '1';
                    else
                        death_i <= '0';
                    end if;
                end if;

            end if;
        end if;
    end process;

end Behavioral;