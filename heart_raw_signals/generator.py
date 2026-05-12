import numpy as np

# 1. Cargar tus datos sanos
# El script leerá el archivo 'ecg_healthy_raw.txt' que me pasaste
try:
    # Cargamos asumiendo que es una sola columna como el texto que pusiste
    data = np.loadtxt('ecg_healthy_raw.txt')
    print(f"Señal original cargada: {len(data)} muestras.")
except Exception as e:
    print(f"Error al cargar el archivo: {e}")
    exit()

# 2. Definir factor de aceleración
# 2.0 significa el doble de rápido (Taquicardia clara)
factor = 2.0

# 3. Remuestreo (Aceleración)
# Creamos un nuevo eje de tiempo más corto
original_indices = np.arange(len(data))
new_indices = np.linspace(0, len(data) - 1, int(len(data) / factor))

# Interpolamos los valores para "encoger" la señal
tachy_data = np.interp(new_indices, original_indices, data)

# 4. Guardar en formato 3 columnas (X Y Z) para tu Testbench
# Usamos el formato que le gusta a tu FPGA: X e Y con señal, Z en 0
with open("ecg_tachy_accelerated.txt", "w") as f:
    for val in tachy_data:
        # Convertimos a entero para mantener el formato original
        v = int(val)
        f.write(f"{v} {v} 0\n")

print(f"Archivo 'ecg_tachy_accelerated.txt' generado con {len(tachy_data)} muestras.")
print(f"Frecuencia cardíaca aumentada en un factor de {factor}x.")