import matplotlib.pyplot as plt
import struct
# import serial  # <- Descomentar para usar el sensor físico

def decode_24bit_signed(b1, b2, b3):
    """Reconstruye un número con signo de 24 bits (Complemento a 2)"""
    val = (b1 << 16) | (b2 << 8) | b3
    if val & 0x800000:  # Si el bit 23 es 1, el número es negativo
        val -= 0x1000000
    return val

def decode_24bit_unsigned(b1, b2, b3):
    """Reconstruye un número sin signo de 24 bits"""
    return (b1 << 16) | (b2 << 8) | b3

# =====================================================================
# 1. ORIGEN DE DATOS
# =====================================================================

raw_bytes = []

# ---> MODO A: CO-SIMULACIÓN DESDE VIVADO (ACTIVO) <---
print("Modo Co-Simulación: Leyendo 'uart_sim_output.txt'...")
try:
    with open("uart_sim_output.txt", "r") as f:
        raw_bytes = [int(line.strip()) for line in f if line.strip() != ""]
except FileNotFoundError:
    print("Error: No se encuentra 'uart_sim_output.txt'. Corre la simulación en Vivado.")
    exit()

# ---> MODO B: SENSOR FÍSICO Y FPGA REAL (COMENTADO) <---
"""
print("Modo Tiempo Real: Conectando al puerto serie...")
puerto_serie = serial.Serial('COM3', 115200, timeout=1) # Cambia 'COM3' por tu puerto
raw_bytes = []

try:
    while True: # Bucle infinito de monitorización
        if puerto_serie.in_waiting > 0:
            nuevos_bytes = list(puerto_serie.read(puerto_serie.in_waiting))
            raw_bytes.extend(nuevos_bytes)
            
            # (El código de desempaquetado iría dentro de este bucle, y al final 
            # de cada iteración dibujaríamos la gráfica con plt.pause(0.01))
            
except KeyboardInterrupt:
    puerto_serie.close()
    print("Conexión serie cerrada por el usuario.")
"""

# =====================================================================
# 2. DECODIFICACIÓN DE LA TRAMA DE 37 BYTES
# =====================================================================

# Listas para almacenar los datos históricos
t_axis = []
raw_x_data, s3_x_data, s8_x_data = [], [], []
rr_data, rt_data = [], []

# Listas de índices para marcar dónde ocurrieron los eventos
qrs_indices, t_indices, death_indices, arrh_indices = [], [], [], []

i = 0
frame_count = 0

print("Desempaquetando tramas...")
while i <= len(raw_bytes) - 37:
    # Verificamos la cabecera (AA BB) y el fin de línea (0A)
    if raw_bytes[i] == 0xAA and raw_bytes[i+1] == 0xBB and raw_bytes[i+36] == 0x0A:
        
        # Extraemos la señal del Eje X (Ajusta si quieres ver Y o Z)
        raw_x = decode_24bit_signed(raw_bytes[i+2], raw_bytes[i+3], raw_bytes[i+4])
        s3_x  = decode_24bit_signed(raw_bytes[i+11], raw_bytes[i+12], raw_bytes[i+13])
        s8_x  = decode_24bit_signed(raw_bytes[i+20], raw_bytes[i+21], raw_bytes[i+22])
        
        # Extraemos los tiempos clínicos
        rr_ms = decode_24bit_unsigned(raw_bytes[i+29], raw_bytes[i+30], raw_bytes[i+31])
        rt_ms = decode_24bit_unsigned(raw_bytes[i+32], raw_bytes[i+33], raw_bytes[i+34])
        
        # Desempaquetamos el byte de Banderas (Byte 35)
        flags = raw_bytes[i+35]
        qrs_unif = (flags >> 6) & 1
        t_unif   = (flags >> 5) & 1
        al_tachy = (flags >> 4) & 1
        al_brady = (flags >> 3) & 1
        al_arrh  = (flags >> 2) & 1
        al_asyst = (flags >> 1) & 1
        al_death = (flags >> 0) & 1
        
        # Guardamos en los históricos
        t_axis.append(frame_count)
        raw_x_data.append(raw_x)
        s3_x_data.append(s3_x)
        s8_x_data.append(s8_x)
        
        # Para que las líneas RR y RT no caigan a cero, repetimos el último valor
        # hasta que ocurra un latido nuevo, formando una gráfica escalonada lógica.
        rr_data.append(rr_ms)
        rt_data.append(rt_ms)
        
        # Registramos las coordenadas exactas de los eventos
        if qrs_unif == 1: qrs_indices.append(frame_count)
        if t_unif == 1:   t_indices.append(frame_count)
        if al_death == 1: death_indices.append(frame_count)
        if al_arrh == 1:  arrh_indices.append(frame_count)
        
        # Avanzamos a la siguiente trama
        i += 37
        frame_count += 1
    else:
        # Si la cabecera no cuadra, avanzamos 1 byte para resincronizar
        i += 1

print(f"Tramas decodificadas: {frame_count}")

# =====================================================================
# 3. DIBUJADO DEL DASHBOARD (MATPLOTLIB)
# =====================================================================

if frame_count > 0:
    # Creamos una ventana grande con 4 subgráficas (filas)
    fig, axs = plt.subplots(4, 1, figsize=(14, 10), sharex=True)
    fig.canvas.manager.set_window_title("Monitor FPGA - Telemetría Avanzada")

    # --- Gráfica 1: RAW ECG ---
    axs[0].plot(t_axis, raw_x_data, color='black', linewidth=1.2)
    axs[0].set_title("Señal Original (Raw X)", fontweight='bold')
    axs[0].set_ylabel("Amplitud")
    axs[0].grid(True, linestyle='--', alpha=0.6)

    # --- Gráfica 2: WAVELET S3 (Detector de QRS) ---
    axs[1].plot(t_axis, s3_x_data, color='blue', linewidth=1)
    # Marcamos los QRS detectados con puntos verdes
    s3_qrs_y = [s3_x_data[idx] for idx in qrs_indices]
    axs[1].scatter(qrs_indices, s3_qrs_y, color='green', s=60, zorder=5, label='QRS Unificado')
    axs[1].set_title("Filtro S3 - Alta Frecuencia (Detección QRS)", fontweight='bold')
    axs[1].legend(loc="upper right")
    axs[1].grid(True, linestyle='--', alpha=0.6)

    # --- Gráfica 3: WAVELET S8 (Detector de Onda T) ---
    axs[2].plot(t_axis, s8_x_data, color='purple', linewidth=1)
    # Marcamos las ondas T detectadas con puntos naranjas
    s8_t_y = [s8_x_data[idx] for idx in t_indices]
    axs[2].scatter(t_indices, s8_t_y, color='orange', s=60, zorder=5, label='Onda T Unificada')
    axs[2].set_title("Filtro S8 - Baja Frecuencia (Detección Onda T)", fontweight='bold')
    axs[2].legend(loc="upper right")
    axs[2].grid(True, linestyle='--', alpha=0.6)

    # --- Gráfica 4: INTERVALOS CLÍNICOS Y ALARMAS ---
    axs[3].plot(t_axis, rr_data, color='darkgreen', linestyle='-', label='RR (Ritmo)')
    axs[3].plot(t_axis, rt_data, color='darkblue', linestyle='-', label='RT (Intervalo QT)')
    
    # Superposición de Alarmas
    rt_death_y = [rt_data[idx] for idx in death_indices]
    axs[3].scatter(death_indices, rt_death_y, color='red', s=100, marker='X', zorder=10, label='ALERTA: Muerte Súbita')
    
    rr_arrh_y = [rr_data[idx] for idx in arrh_indices]
    axs[3].scatter(arrh_indices, rr_arrh_y, color='magenta', s=100, marker='^', zorder=10, label='ALERTA: Arritmia')

    axs[3].set_title("Intervalos Clínicos en Tiempo Real (ms) y Alarmas", fontweight='bold')
    axs[3].set_ylabel("Milisegundos (ms)")
    axs[3].set_xlabel("Muestras (Frames UART)")
    axs[3].legend(loc="upper left")
    axs[3].grid(True, linestyle='--', alpha=0.6)

    plt.tight_layout()
    plt.show()

else:
    print("No se encontraron tramas válidas para representar. Verifica la simulación.")