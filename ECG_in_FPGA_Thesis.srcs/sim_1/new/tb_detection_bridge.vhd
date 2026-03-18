library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_detection_bridge is
end tb_detection_bridge;

architecture Sim of tb_detection_bridge is
    component detection_bridge
        Port (
            clk : in STD_LOGIC; reset : in STD_LOGIC; d_valid : in STD_LOGIC;
            qrs_x, qrs_y, qrs_z : in STD_LOGIC;
            t_x, t_y, t_z : in STD_LOGIC;
            qrs_unified, t_unified : out STD_LOGIC;
            rr_interval_ms, rt_interval_ms : out SIGNED(23 downto 0)
        );
    end component;

    signal clk, reset, dv : std_logic := '0';
    signal qx, qy, qz : std_logic := '0';
    signal tx, ty, tz : std_logic := '0';
    signal qu, tu : std_logic;
    signal rr, rt : signed(23 downto 0);

    constant CLK_PER : time := 10 ns;

begin
    UUT: detection_bridge port map (clk, reset, dv, qx, qy, qz, tx, ty, tz, qu, tu, rr, rt);

    -- Generador de Reloj
    clk_gen: process begin
        clk <= '0'; wait for CLK_PER/2;
        clk <= '1'; wait for CLK_PER/2;
    end process;

    stim_proc: process
        -- ---------------------------------------------------------
        -- PROCEDIMIENTO 1: Avanzar el tiempo (N milisegundos)
        -- Genera pulsos de d_valid para simular que pasa el tiempo
        -- ---------------------------------------------------------
        procedure wait_ms(ms : integer) is
        begin
            for i in 1 to ms loop
                wait until falling_edge(clk);
                dv <= '1';
                wait until falling_edge(clk);
                dv <= '0';
                wait for CLK_PER * 2; -- Breve pausa entre ms
            end loop;
        end procedure;

        -- ---------------------------------------------------------
        -- PROCEDIMIENTO 2: Inyectar señales al Bridge
        -- Asegura que qrs y t entran EXACTAMENTE cuando d_valid = '1'
        -- ---------------------------------------------------------
        procedure inject_pulses(
            p_qx: std_logic; p_qy: std_logic; p_qz: std_logic;
            p_tx: std_logic; p_ty: std_logic; p_tz: std_logic
        ) is
        begin
            wait until falling_edge(clk);
            qx <= p_qx; qy <= p_qy; qz <= p_qz;
            tx <= p_tx; ty <= p_ty; tz <= p_tz;
            dv <= '1';
            wait until falling_edge(clk);
            qx <= '0'; qy <= '0'; qz <= '0';
            tx <= '0'; ty <= '0'; tz <= '0';
            dv <= '0';
        end procedure;

    begin
        -- 0. Reset inicial del sistema
        reset <= '1';
        wait for 50 ns;
        reset <= '0';
        wait for 50 ns;

        -- ========================================================
        -- CASO 1: Sincronía Perfecta (Los 3 ejes a la vez)
        -- ========================================================
        report "--- INICIANDO CASO 1: SINCRONIA PERFECTA ---";
        wait_ms(100); 
        inject_pulses('1','1','1', '0','0','0'); -- QRS en X, Y, Z
        wait_ms(300); -- Esperamos 300ms (Simula el intervalo QT/RT)
        inject_pulses('0','0','0', '1','1','1'); -- Onda T en X, Y, Z
        wait_ms(500); -- Completamos el ciclo simulando el resto del latido

        -- ========================================================
        -- CASO 2: Desfase temporal (Comprobando la ventana de 30ms)
        -- ========================================================
        report "--- INICIANDO CASO 2: DESFASE TEMPORAL ---";
        inject_pulses('1','0','0', '0','0','0'); -- Llega QRS_X (Inicia cuenta regresiva)
        wait_ms(15); -- Pasan 15ms (Aún dentro de la ventana de 30ms)
        inject_pulses('0','1','0', '0','0','0'); -- Llega QRS_Y -> ¡AQUI DEBE DISPARAR qrs_unified!
        wait_ms(10); 
        inject_pulses('0','0','1', '0','0','0'); -- Llega QRS_Z
        
        wait_ms(350); 
        inject_pulses('0','0','0', '1','0','0'); -- Llega T_X
        wait_ms(10);
        inject_pulses('0','0','0', '0','1','1'); -- Llegan T_Y y T_Z juntos -> ¡AQUI DEBE DISPARAR t_unified!
        wait_ms(400);

        -- ========================================================
        -- CASO 3: Fallo de un eje (Votación 2 de 3)
        -- ========================================================
        report "--- INICIANDO CASO 3: FALLO DE UN EJE (2 DE 3) ---";
        inject_pulses('1','0','1', '0','0','0'); -- QRS_X y QRS_Z (Y está roto/desconectado) -> DEBE VOTAR SÍ
        wait_ms(280); 
        inject_pulses('0','0','0', '1','1','0'); -- T_X y T_Y (Z está roto) -> DEBE VOTAR SÍ
        wait_ms(600);

        -- ========================================================
        -- CASO 4: Votación Insuficiente (Rechazo de ruido)
        -- ========================================================
        report "--- INICIANDO CASO 4: INSUFICIENTE (1 DE 3) ---";
        inject_pulses('0','1','0', '0','0','0'); -- Solo llega QRS_Y -> NO DEBE SALIR NADA
        wait_ms(300);
        inject_pulses('0','0','0', '0','0','1'); -- Solo llega T_Z -> NO DEBE SALIR NADA
        wait_ms(400);

        report "--- SIMULACION COMPLETADA ---";
        wait;
    end process;
end Sim;