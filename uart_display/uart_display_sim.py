import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import matplotlib.animation as animation
from matplotlib.collections import LineCollection
import numpy as np

def decode_24bit_signed(b1, b2, b3):
    val = (b1 << 16) | (b2 << 8) | b3
    return val - 0x1000000 if val & 0x800000 else val

def decode_24bit_unsigned(b1, b2, b3):
    return (b1 << 16) | (b2 << 8) | b3

# =========================================================
# 1. CARGA Y PARSEO DE DATOS 
# =========================================================
# NOTA: Cambia este nombre al archivo txt con tus valores reales
try:
    with open("uart_prueba_3d.txt", "r") as f:
        bytes_totales = [int(line.strip()) for line in f if line.strip() != ""]
except Exception as e:
    exit(f"Error cargando archivo: {e}")

frames = []
i = 0
while i <= len(bytes_totales) - 37:
    if bytes_totales[i:i+2] == [0xAA, 0xBB] and bytes_totales[i+36] == 0x0A:
        # Extraer RAW
        rx = decode_24bit_signed(bytes_totales[i+2], bytes_totales[i+3], bytes_totales[i+4])
        ry = decode_24bit_signed(bytes_totales[i+5], bytes_totales[i+6], bytes_totales[i+7])
        rz = decode_24bit_signed(bytes_totales[i+8], bytes_totales[i+9], bytes_totales[i+10])
        # Extraer Tiempos
        rr = decode_24bit_unsigned(bytes_totales[i+29], bytes_totales[i+30], bytes_totales[i+31])
        rt = decode_24bit_unsigned(bytes_totales[i+32], bytes_totales[i+33], bytes_totales[i+34])
        
        # Registro de Alarmas y Estados
        alarms = bytes_totales[i+35]
        # Extraer detecciones (Asumimos: Bit 5 -> QRS, Bit 6 -> Onda T)
        qrs_detected = (alarms >> 5) & 1
        t_detected = (alarms >> 6) & 1
        
        frames.append((rx, ry, rz, rr, rt, alarms, qrs_detected, t_detected))
        i += 37
    else:
        i += 1

if not frames:
    exit("Error: No se encontraron tramas válidas en el archivo.")

# Conversión a Numpy Arrays para velocidad
data_rx = np.array([f[0] for f in frames])
data_ry = np.array([f[1] for f in frames])
data_rz = np.array([f[2] for f in frames])
data_rr = np.array([f[3] for f in frames])
data_rt = np.array([f[4] for f in frames])
data_al = np.array([f[5] for f in frames])
data_qrs = np.array([f[6] for f in frames])
data_t = np.array([f[7] for f in frames])

# =========================================================
# 2. CONFIGURACIÓN DE LA INTERFAZ GRÁFICA
# =========================================================
plt.style.use('dark_background')
fig = plt.figure(figsize=(15, 9), facecolor='#0a0a0a')
fig.canvas.manager.set_window_title("Dashboard TFG - Modo Pro Unificado")

gs = gridspec.GridSpec(4, 3, height_ratios=[1, 1, 1, 0.4])

# Ejes 2D para señales RAW
ax_x = fig.add_subplot(gs[0, 0:2])
ax_y = fig.add_subplot(gs[1, 0:2])
ax_z = fig.add_subplot(gs[2, 0:2])
axes_1d = [ax_x, ax_y, ax_z]

titles = ["Señal RAW - Eje X", "Señal RAW - Eje Y", "Señal RAW - Eje Z"]
colors = ["#ff4444", "#44ff44", "#4444ff"]
lines_1d = []

# Colecciones de líneas para QRS y T
qrs_collections = []
t_collections = []

for idx, ax in enumerate(axes_1d):
    ax.set_facecolor('#121212')
    ax.set_title(titles[idx], fontweight='bold', fontsize=10)
    ax.grid(True, linestyle=':', alpha=0.3)
    line, = ax.plot([], [], color=colors[idx], linewidth=1.5)
    lines_1d.append(line)
    
    # Líneas verticales: QRS en Naranja, T en Magenta
    qrs_col = LineCollection([], colors='#ffaa00', linewidths=1.2, linestyles='--')
    t_col = LineCollection([], colors='#ff00ff', linewidths=1.2, linestyles='--')
    
    ax.add_collection(qrs_col)
    ax.add_collection(t_col)
    qrs_collections.append(qrs_col)
    t_collections.append(t_col)

# Gráfico 3D Unificado (Sin rotación automática)
ax_3d = fig.add_subplot(gs[0:3, 2], projection='3d')
ax_3d.set_facecolor('#0a0a0a')
ax_3d.set_title("Vectorcardiograma 3D Unificado", fontsize=11, fontweight='bold')
ax_3d.xaxis.set_pane_color((0.0, 0.0, 0.0, 0.0))
ax_3d.yaxis.set_pane_color((0.0, 0.0, 0.0, 0.0))
ax_3d.zaxis.set_pane_color((0.0, 0.0, 0.0, 0.0))
line_3d, = ax_3d.plot([], [], [], color='cyan', linewidth=1.5)

# Panel Inferior de Estados y Tiempos
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

# =========================================================
# 3. CONFIGURACIÓN FINAL Y ANIMACIÓN
# =========================================================
ANCHO = 400
STEP = 4 

margin = 500
lim_x = (np.min(data_rx) - margin, np.max(data_rx) + margin)
lim_y = (np.min(data_ry) - margin, np.max(data_ry) + margin)
lim_z = (np.min(data_rz) - margin, np.max(data_rz) - 100 if np.min(data_rz) == np.max(data_rz) else np.max(data_rz) + margin)

if lim_z[0] == lim_z[1]:
    lim_z = (-1000, 1000)

def init():
    for ax in axes_1d:
        ax.set_xlim(0, ANCHO)
    ax_x.set_ylim(lim_x)
    ax_y.set_ylim(lim_y)
    ax_z.set_ylim(lim_z)
    
    ax_3d.set_xlim(lim_x)
    ax_3d.set_ylim(lim_y)
    ax_3d.set_zlim(lim_z)
    return lines_1d + [line_3d, txt_rr, txt_rt] + botones

def update(frame_step):
    idx = frame_step * STEP
    if idx >= len(data_rx):
        idx = len(data_rx) - 1

    start = max(0, idx - ANCHO)
    window_length = idx - start
    
    if window_length > 0:
        # Actualización de la señal 2D
        t_axis = np.arange(window_length)
        lines_1d[0].set_data(t_axis, data_rx[start:idx])
        lines_1d[1].set_data(t_axis, data_ry[start:idx])
        lines_1d[2].set_data(t_axis, data_rz[start:idx])

        # Actualización de líneas verticales dinámicas (QRS y T)
        window_qrs = data_qrs[start:idx]
        window_t = data_t[start:idx]
        
        qrs_x_coords = np.where(window_qrs == 1)[0]
        t_x_coords = np.where(window_t == 1)[0]
        
        qrs_collections[0].set_segments([[(x, lim_x[0]), (x, lim_x[1])] for x in qrs_x_coords])
        qrs_collections[1].set_segments([[(x, lim_y[0]), (x, lim_y[1])] for x in qrs_x_coords])
        qrs_collections[2].set_segments([[(x, lim_z[0]), (x, lim_z[1])] for x in qrs_x_coords])

        t_collections[0].set_segments([[(x, lim_x[0]), (x, lim_x[1])] for x in t_x_coords])
        t_collections[1].set_segments([[(x, lim_y[0]), (x, lim_y[1])] for x in t_x_coords])
        t_collections[2].set_segments([[(x, lim_z[0]), (x, lim_z[1])] for x in t_x_coords])

        # Actualización de la señal 3D
        line_3d.set_data(data_rx[start:idx], data_ry[start:idx])
        line_3d.set_3d_properties(data_rz[start:idx])

    # Textos de intervalos
    txt_rr.set_text(f"RR: {data_rr[idx]} ms")
    txt_rt.set_text(f"RT: {data_rt[idx]} ms")

    # Mapeo de bits de Alarma
    f = data_al[idx]
    al_states = [(f>>4)&1, (f>>3)&1, (f>>2)&1, (f>>1)&1, f&1]
    
    for j, state in enumerate(al_states):
        color_fondo = '#FF0000' if state else '#222222'
        botones[j].set_bbox(dict(facecolor=color_fondo, edgecolor='#777777', boxstyle='round,pad=0.8'))

    return lines_1d + [line_3d, txt_rr, txt_rt] + botones

# Ejecución a 50Hz (interval=20ms)
total_frames = len(data_rx) // STEP
ani = animation.FuncAnimation(fig, update, frames=total_frames, init_func=init, blit=False, interval=20)

plt.tight_layout()
plt.show()