import numpy as np

def decode_24bit_signed(b1, b2, b3):
    val = (b1 << 16) | (b2 << 8) | b3
    return val - 0x1000000 if val & 0x800000 else val

def encode_24bit_signed(val):
    val = int(val)
    # Manejar el complemento a 2 para números negativos
    if val < 0:
        val += 0x1000000
    b1 = (val >> 16) & 0xFF
    b2 = (val >> 8) & 0xFF
    b3 = val & 0xFF
    return b1, b2, b3

print("Leyendo archivo original...")
try:
    with open("uart_sudden_death.txt", "r") as f:
        bytes_totales = [int(line.strip()) for line in f if line.strip() != ""]
except Exception as e:
    exit(f"Error cargando archivo: {e}")

frames = []
i = 0
# Parsear la trama
while i <= len(bytes_totales) - 37:
    if bytes_totales[i:i+2] == [0xAA, 0xBB] and bytes_totales[i+36] == 0x0A:
        frame = bytes_totales[i:i+37]
        rx = decode_24bit_signed(frame[2], frame[3], frame[4])
        frames.append({'raw': frame, 'rx': rx})
        i += 37
    else:
        i += 1

print(f"Se han detectado {len(frames)} tramas válidas.")
print("Generando ejes Y y Z (Phase Shift)...")

# Configuración del retraso (delay) para crear el efecto 3D
DELAY_Y = 8   # Retraso para Y (aprox 22ms a 360Hz)
DELAY_Z = 16  # Retraso para Z (aprox 44ms a 360Hz)

for idx, f in enumerate(frames):
    # Generar Y retrasando la señal X
    idx_y = max(0, idx - DELAY_Y)
    ry_val = frames[idx_y]['rx']
    
    # Generar Z retrasando aún más la señal X
    idx_z = max(0, idx - DELAY_Z)
    rz_val = frames[idx_z]['rx']
    
    # Codificamos de nuevo a bytes
    by1, by2, by3 = encode_24bit_signed(ry_val)
    bz1, bz2, bz3 = encode_24bit_signed(rz_val)
    
    # Modificamos los bytes dentro del frame original
    # Bytes 5, 6, 7 son el Eje Y
    f['raw'][5], f['raw'][6], f['raw'][7] = by1, by2, by3
    # Bytes 8, 9, 10 son el Eje Z
    f['raw'][8], f['raw'][9], f['raw'][10] = bz1, bz2, bz3

print("Exportando a uart_prueba_3d.txt...")
with open("uart_prueba_3d.txt", "w") as f_out:
    for f in frames:
        for b in f['raw']:
            f_out.write(f"{b}\n")

print("¡Proceso completado! Ya puedes usar 'uart_prueba_3d.txt' en el display.")