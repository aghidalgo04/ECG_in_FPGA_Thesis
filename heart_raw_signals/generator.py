import numpy as np
import wfdb

print("Conectando con PhysioNet para descargar el registro 100 del MIT-BIH...")

# 1. Descargamos 3000 muestras de un paciente sano
try:
    record = wfdb.rdrecord('100', pn_dir='mitdb', sampfrom=0, sampto=3000)
    signal_mv = record.p_signal[:, 0]
except Exception as e:
    print(f"Error al descargar: {e}")
    exit()

# 2. Extraemos los primeros 3 latidos reales (aprox 1000 muestras)
muestras_sanas = 1000
fase_latidos = signal_mv[:muestras_sanas]

# 3. Simulamos el Paro Cardíaco / Desconexión
# A partir de la muestra 1000, el corazón se detiene. 
# Necesitamos que esté parado más de 1080 muestras (3 segundos). Le daremos 1500 (4.1 seg).
muestras_asistolia = 1500

# Cogemos el último valor de la señal sana para que no haya un salto irreal
ultimo_voltaje = fase_latidos[-1]

# Creamos una línea plana, pero le añadimos un ruido blanco minúsculo (0.005 mV)
# Esto simula el ruido térmico de los cables cuando el corazón no emite electricidad
ruido_cables = np.random.normal(0, 0.005, muestras_asistolia)
fase_plana = np.full(muestras_asistolia, ultimo_voltaje) + ruido_cables

# 4. Unimos la vida y la asistolia
signal_completa = np.concatenate((fase_latidos, fase_plana))

# 5. Escalamos para la FPGA (x2000 como hicimos antes)
scaled_signal = np.int32(signal_completa * 2000000)

# 6. Guardamos en formato 3 columnas
output_filename = "ecg_asyst.txt"
with open(output_filename, "w") as f:
    for val in scaled_signal:
        f.write(f"{val} {val} 0\n")

print(f"¡Éxito! Archivo '{output_filename}' generado.")
print("Composición: 3 latidos reales normales seguidos de 4 segundos de asistolia/desconexión.")