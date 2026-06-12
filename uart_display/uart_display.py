import matplotlib.pyplot as plt
import matplotlib.animation as animation
import serial
import numpy as np
from collections import deque
import sys

def decode_24bit_signed(b1, b2, b3):
    val = (b1 << 16) | (b2 << 8) | b3
    if val & 0x800000: val -= 0x1000000
    return val

def decode_24bit_unsigned(b1, b2, b3):
    return (b1 << 16) | (b2 << 8) | b3

# =========================================================
# 1. CONEXIÓN FÍSICA A LA FPGA
# =========================================================
PUERTO = 'COM3' # <-- Cambiar por el puerto real
BAUD_RATE = 115200

try:
    # timeout=0 es crucial para que la lectura no bloquee el entorno gráfico
    puerto_serie = serial.Serial(PUERTO, BAUD_RATE, timeout=0)
    print(f"Conectado a la FPGA en {PUERTO} a {BAUD_RATE} bps.")
except Exception as e:
    print(f"Error abriendo el puerto serie: {e}")
    sys.exit()

# =========================================================
# 2. CONFIGURACIÓN DEL DASHBOARD Y MEMORIA
# =========================================================
plt.style.use('dark_background')
fig, axs = plt.subplots(4, 1, figsize=(12, 8), sharex=True)
fig.canvas.manager.set_window_title("Dashboard TFG - MODO SENSOR REAL EN VIVO")

line_raw, = axs[0].plot([], [], color='#00FFFF', linewidth=1.2)
line_s3,  = axs[1].plot([], [], color='#44FF44', linewidth=1)
scat_qrs  = axs[1].scatter([], [], color='#FFAA00', s=70, zorder=5, label='QRS')
line_s8,  = axs[2].plot([], [], color='#FF00FF', linewidth=1)
scat_t    = axs[2].scatter([], [], color='#FFFF00', s=70, zorder=5, label='Onda T')
line_rr,  = axs[3].plot([], [], color='#00FF00', label='RR')
line_rt,  = axs[3].plot([], [], color='#0088FF', label='RT')
scat_death = axs[3].scatter([], [], color='red', s=150, marker='X', zorder=10, label='Muerte Súbita')
scat_arrh  = axs[3].scatter([], [], color='magenta', s=150, marker='^', zorder=10, label='Arritmia')

axs[0].set_title("ECG Raw", fontweight='bold')
axs[1].set_title("Filtro S3 (QRS)", fontweight='bold')
axs[2].set_title("Filtro S8 (Onda T)", fontweight='bold')
axs[3].set_title("Intervalos y Alarmas", fontweight='bold')

for ax in axs: 
    ax.grid(True, linestyle=':', alpha=0.3)
axs[3].legend(loc="upper left")

# MEMORIA LIMITADA (Circular): Evita que explote la RAM con el paso del tiempo
ANCHO_VENTANA = 400 
t_axis = deque(maxlen=ANCHO_VENTANA)
raw_x = deque(maxlen=ANCHO_VENTANA)
s3_x = deque(maxlen=ANCHO_VENTANA)
s8_x = deque(maxlen=ANCHO_VENTANA)
rr_list = deque(maxlen=ANCHO_VENTANA)
rt_list = deque(maxlen=ANCHO_VENTANA)

# Memoria dinámica para los puntos Scatters
qrs_pts, t_pts, death_pts, arrh_pts = [], [], [], []

buffer_recepcion = bytearray()
frame_global = 0

print("Escuchando datos del paciente... Cierra la ventana de la gráfica para detener.")

# =========================================================
# 3. MOTOR DE ACTUALIZACIÓN EN TIEMPO REAL
# =========================================================
def update(frame_anim):
    global frame_global, buffer_recepcion
    
    tramas_procesadas_ahora = 0

    # 1. Volcar todo lo que haya escupido el USB desde el último renderizado
    if puerto_serie.in_waiting > 0:
        buffer_recepcion.extend(puerto_serie.read(puerto_serie.in_waiting))
        
    # 2. Buscar e interpretar todas las tramas completas acumuladas en el buffer
    i = 0
    while i <= len(buffer_recepcion) - 37:
        if buffer_recepcion[i] == 0xAA and buffer_recepcion[i+1] == 0xBB and buffer_recepcion[i+36] == 0x0A:
            v_raw = decode_24bit_signed(buffer_recepcion[i+2], buffer_recepcion[i+3], buffer_recepcion[i+4])
            v_s3  = decode_24bit_signed(buffer_recepcion[i+11], buffer_recepcion[i+12], buffer_recepcion[i+13])
            v_s8  = decode_24bit_signed(buffer_recepcion[i+20], buffer_recepcion[i+21], buffer_recepcion[i+22])
            v_rr  = decode_24bit_unsigned(buffer_recepcion[i+29], buffer_recepcion[i+30], buffer_recepcion[i+31])
            v_rt  = decode_24bit_unsigned(buffer_recepcion[i+32], buffer_recepcion[i+33], buffer_recepcion[i+34])
            
            flags = buffer_recepcion[i+35]
            qrs_unif = (flags >> 6) & 1
            t_unif   = (flags >> 5) & 1
            al_arrh  = (flags >> 2) & 1
            al_death = (flags >> 0) & 1

            # Inyección en colas de memoria de alta velocidad
            t_axis.append(frame_global)
            raw_x.append(v_raw)
            s3_x.append(v_s3)
            s8_x.append(v_s8)
            rr_list.append(v_rr)
            rt_list.append(v_rt)

            # Inyección de marcadores
            if qrs_unif: qrs_pts.append((frame_global, v_s3))
            if t_unif:   t_pts.append((frame_global, v_s8))
            if al_death: death_pts.append((frame_global, v_rt))
            if al_arrh:  arrh_pts.append((frame_global, v_rr))

            frame_global += 1
            i += 37
            tramas_procesadas_ahora += 1
        else:
            i += 1 # Si hay ruido eléctrico en el cable o un bit caído, avanzamos 1 y nos resincronizamos

    # 3. Limpiar el buffer liberando memoria instantáneamente
    del buffer_recepcion[:i]

    # 4. Actualizar visuales (SÓLO SI ha entrado algo nuevo)
    if tramas_procesadas_ahora > 0 and len(t_axis) > 0:
        line_raw.set_data(t_axis, raw_x)
        line_s3.set_data(t_axis, s3_x)
        line_s8.set_data(t_axis, s8_x)
        line_rr.set_data(t_axis, rr_list)
        line_rt.set_data(t_axis, rt_list)
        
        # Desplazamiento inteligente de la ventana del Eje X
        min_x = t_axis[0]
        max_x = t_axis[-1]
        for ax in axs:
            ax.set_xlim(min_x, max(min_x + ANCHO_VENTANA, max_x))
        
        # Recolector de basura manual para los scatter points que se han salido por la izquierda
        qrs_pts[:] = [p for p in qrs_pts if p[0] >= min_x]
        t_pts[:] = [p for p in t_pts if p[0] >= min_x]
        death_pts[:] = [p for p in death_pts if p[0] >= min_x]
        arrh_pts[:] = [p for p in arrh_pts if p[0] >= min_x]

        # Pintar Scatters
        scat_qrs.set_offsets(qrs_pts if qrs_pts else np.empty((0,2)))
        scat_t.set_offsets(t_pts if t_pts else np.empty((0,2)))
        scat_death.set_offsets(death_pts if death_pts else np.empty((0,2)))
        scat_arrh.set_offsets(arrh_pts if arrh_pts else np.empty((0,2)))
        
        # Escala automática inteligente del Eje Y
        margin = 1000
        if max(raw_x) != min(raw_x):
            axs[0].set_ylim(min(raw_x)-margin, max(raw_x)+margin)
        if max(s3_x) != min(s3_x):
            axs[1].set_ylim(min(s3_x)-margin, max(s3_x)+margin)
        if max(s8_x) != min(s8_x):
            axs[2].set_ylim(min(s8_x)-margin, max(s8_x)+margin)
        axs[3].set_ylim(0, 1500)

    return line_raw, line_s3, scat_qrs, line_s8, scat_t, line_rr, line_rt, scat_death, scat_arrh

# Configurar motor de animación (interval=30 ms aproxima a 30 FPS muy estables)
ani = animation.FuncAnimation(fig, update, interval=30, blit=False, cache_frame_data=False)

# Cierre seguro del puerto serie cuando pulsas la 'X' de la ventana
def on_close(event):
    puerto_serie.close()
    print("Puerto serie cerrado con seguridad.")
fig.canvas.mpl_connect('close_event', on_close)

plt.tight_layout()
plt.show()