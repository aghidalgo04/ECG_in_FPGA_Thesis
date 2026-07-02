import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import matplotlib.animation as animation
from matplotlib.collections import LineCollection
import serial
import numpy as np
from collections import deque
import sys

def decode_24bit_signed(b1, b2, b3):
    val = (b1 << 16) | (b2 << 8) | b3
    return val - 0x1000000 if val & 0x800000 else val

def decode_24bit_unsigned(b1, b2, b3):
    return (b1 << 16) | (b2 << 8) | b3

# conexion fisica a la fpga
PUERTO = 'COM4' 
BAUD_RATE = 115200

try:
    # timeout cero evita bloqueo grafico
    puerto_serie = serial.Serial(PUERTO, BAUD_RATE, timeout=0)
    print(f"Conectado a la FPGA en {PUERTO} a {BAUD_RATE} bps.")
except Exception as e:
    print(f"Error abriendo el puerto serie: {e}")
    sys.exit()

# configuracion de la interfaz grafica
plt.style.use('dark_background')
fig = plt.figure(figsize=(15, 9), facecolor='#0a0a0a')
fig.canvas.manager.set_window_title("Dashboard TFG - MODO REAL-TIME SENSOR")

gs = gridspec.GridSpec(4, 3, height_ratios=[1, 1, 1, 0.4])

# ejes 2d para señales raw
ax_x = fig.add_subplot(gs[0, 0:2])
ax_y = fig.add_subplot(gs[1, 0:2])
ax_z = fig.add_subplot(gs[2, 0:2])
axes_1d = [ax_x, ax_y, ax_z]

titles = ["Señal RAW - Eje X", "Señal RAW - Eje Y", "Señal RAW - Eje Z"]
colors = ["#ff4444", "#44ff44", "#4444ff"]
lines_1d = []

# colecciones para marcas de qrs y t
qrs_collections = []
t_collections = []

for idx, ax in enumerate(axes_1d):
    ax.set_facecolor('#121212')
    ax.set_title(titles[idx], fontweight='bold', fontsize=10)
    ax.grid(True, linestyle=':', alpha=0.3)
    line, = ax.plot([], [], color=colors[idx], linewidth=1.5)
    lines_1d.append(line)
    
    qrs_col = LineCollection([], colors='#ffaa00', linewidths=1.2, linestyles='--')
    t_col = LineCollection([], colors='#ff00ff', linewidths=1.2, linestyles='--')
    ax.add_collection(qrs_col)
    ax.add_collection(t_col)
    qrs_collections.append(qrs_col)
    t_collections.append(t_col)

# grafico 3d unificado
ax_3d = fig.add_subplot(gs[0:3, 2], projection='3d')
ax_3d.set_facecolor('#0a0a0a')
ax_3d.set_title("Vectorcardiograma 3D en Vivo", fontsize=11, fontweight='bold')
ax_3d.xaxis.set_pane_color((0.0, 0.0, 0.0, 0.0))
ax_3d.yaxis.set_pane_color((0.0, 0.0, 0.0, 0.0))
ax_3d.zaxis.set_pane_color((0.0, 0.0, 0.0, 0.0))
line_3d, = ax_3d.plot([], [], [], color='cyan', linewidth=1.5)

# panel inferior de estados y tiempos
ax_dash = fig.add_subplot(gs[3, :])
ax_dash.set_facecolor('#050505')
ax_dash.axis('off')

txt_rr = ax_dash.text(0.20, 0.7, "RR: --- ms", fontsize=22, color='#00FF00', fontfamily='monospace', ha='center')
txt_rt = ax_dash.text(0.80, 0.7, "RT: --- ms", fontsize=22, color='#00FFFF', fontfamily='monospace', ha='center')

labels_alarmas = ['TAQUICARDIA', 'BRADICARDIA', 'ARRITMIA', 'ASISTOLIA', 'MUERTE SÚBITA']
botones = []
for idx, lab in enumerate(labels_alarmas):
    x_pos = 0.1 + (idx * 0.2)
    btn = ax_dash.text(x_pos, 0.2, lab, ha='center', va='center', fontsize=11, color='white', fontweight='bold',
                       bbox=dict(facecolor='#222222', edgecolor='#555555', boxstyle='round,pad=0.8'))
    botones.append(btn)

# memoria dinamica de alta velocidad
ANCHO_VENTANA = 400
t_axis = deque(maxlen=ANCHO_VENTANA)
data_rx = deque(maxlen=ANCHO_VENTANA)
data_ry = deque(maxlen=ANCHO_VENTANA)
data_rz = deque(maxlen=ANCHO_VENTANA)
data_qrs = deque(maxlen=ANCHO_VENTANA)
data_t = deque(maxlen=ANCHO_VENTANA)

buffer_recepcion = bytearray()
frame_global = 0

ultimo_rr = 0
ultimo_rt = 0
ultimo_alarm_byte = 0

print("Escuchando datos... Cierra la ventana de Matplotlib para detener.")

# motor de actualizacion en tiempo real
def update(frame_anim):
    global frame_global, buffer_recepcion
    global ultimo_rr, ultimo_rt, ultimo_alarm_byte
    
    tramas_procesadas_ahora = 0

    # lectura de buffer usb sin bloqueo
    if puerto_serie.in_waiting > 0:
        buffer_recepcion.extend(puerto_serie.read(puerto_serie.in_waiting))
        
    # parseo y extraccion de tramas
    i = 0
    while i <= len(buffer_recepcion) - 37:
        if buffer_recepcion[i] == 0xAA and buffer_recepcion[i+1] == 0xBB and buffer_recepcion[i+36] == 0x0A:
            # extraccion de ejes raw
            rx = decode_24bit_signed(buffer_recepcion[i+2], buffer_recepcion[i+3], buffer_recepcion[i+4])
            ry = decode_24bit_signed(buffer_recepcion[i+5], buffer_recepcion[i+6], buffer_recepcion[i+7])
            rz = decode_24bit_signed(buffer_recepcion[i+8], buffer_recepcion[i+9], buffer_recepcion[i+10])
            
            # extraccion de tiempos
            ultimo_rr = decode_24bit_unsigned(buffer_recepcion[i+29], buffer_recepcion[i+30], buffer_recepcion[i+31])
            ultimo_rt = decode_24bit_unsigned(buffer_recepcion[i+32], buffer_recepcion[i+33], buffer_recepcion[i+34])
            
            # extraccion de alarmas
            ultimo_alarm_byte = buffer_recepcion[i+35]
            qrs_detected = (ultimo_alarm_byte >> 5) & 1
            t_detected = (ultimo_alarm_byte >> 6) & 1

            # almacenamiento en memoria
            t_axis.append(frame_global)
            data_rx.append(rx)
            data_ry.append(ry)
            data_rz.append(rz)
            data_qrs.append(qrs_detected)
            data_t.append(t_detected)

            frame_global += 1
            i += 37
            tramas_procesadas_ahora += 1
        else:
            i += 1 # resincronizacion por ruido

    # liberacion de memoria ram
    del buffer_recepcion[:i]

    # actualizacion visual por datos nuevos
    if tramas_procesadas_ahora > 0 and len(t_axis) > 0:
        # conversion a numpy para velocidad
        arr_rx = np.array(data_rx)
        arr_ry = np.array(data_ry)
        arr_rz = np.array(data_rz)
        arr_t = np.array(t_axis)
        
        # actualizacion de trayectorias 2d y 3d
        lines_1d[0].set_data(arr_t, arr_rx)
        lines_1d[1].set_data(arr_t, arr_ry)
        lines_1d[2].set_data(arr_t, arr_rz)
        
        line_3d.set_data(arr_rx, arr_ry)
        line_3d.set_3d_properties(arr_rz)

        # autoescalado dinamico
        margin = 500
        lim_x = (np.min(arr_rx) - margin, np.max(arr_rx) + margin)
        lim_y = (np.min(arr_ry) - margin, np.max(arr_ry) + margin)
        
        # proteccion contra z plana
        min_z, max_z = np.min(arr_rz), np.max(arr_rz)
        lim_z = (min_z - 1000, max_z + 1000) if min_z == max_z else (min_z - margin, max_z + margin)

        # aplicacion de limites
        min_time = arr_t[0]
        max_time = arr_t[-1]
        for ax in axes_1d:
            ax.set_xlim(min_time, max(min_time + ANCHO_VENTANA, max_time))
            
        ax_x.set_ylim(lim_x)
        ax_y.set_ylim(lim_y)
        ax_z.set_ylim(lim_z)

        ax_3d.set_xlim(lim_x)
        ax_3d.set_ylim(lim_y)
        ax_3d.set_zlim(lim_z)

        # actualizacion de marcadores qrs y t
        qrs_idx = [t for t, q in zip(arr_t, data_qrs) if q == 1]
        t_idx = [t for t, dt in zip(arr_t, data_t) if dt == 1]
        
        qrs_collections[0].set_segments([[(x, lim_x[0]), (x, lim_x[1])] for x in qrs_idx])
        qrs_collections[1].set_segments([[(x, lim_y[0]), (x, lim_y[1])] for x in qrs_idx])
        qrs_collections[2].set_segments([[(x, lim_z[0]), (x, lim_z[1])] for x in qrs_idx])

        t_collections[0].set_segments([[(x, lim_x[0]), (x, lim_x[1])] for x in t_idx])
        t_collections[1].set_segments([[(x, lim_y[0]), (x, lim_y[1])] for x in t_idx])
        t_collections[2].set_segments([[(x, lim_z[0]), (x, lim_z[1])] for x in t_idx])

        # actualizacion de textos y alarmas
        txt_rr.set_text(f"RR: {ultimo_rr} ms")
        txt_rt.set_text(f"RT: {ultimo_rt} ms")

        f = ultimo_alarm_byte
        al_states = [(f>>4)&1, (f>>3)&1, (f>>2)&1, (f>>1)&1, f&1]
        for j, state in enumerate(al_states):
            color_fondo = '#FF0000' if state else '#222222'
            botones[j].set_bbox(dict(facecolor=color_fondo, edgecolor='#777777', boxstyle='round,pad=0.8'))

    # retorno de elementos a actualizar
    elementos = lines_1d + [line_3d, txt_rr, txt_rt] + botones
    return elementos

# ejecucion de la animacion
ani = animation.FuncAnimation(fig, update, interval=30, blit=False, cache_frame_data=False)

# cierre seguro del puerto com
def on_close(event):
    puerto_serie.close()
    print("Puerto serie cerrado con seguridad. Hasta la próxima.")
fig.canvas.mpl_connect('close_event', on_close)

plt.tight_layout()
plt.show()