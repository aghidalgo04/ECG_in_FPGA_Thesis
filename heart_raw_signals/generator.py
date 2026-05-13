import numpy as np

# 1. Cargar tus datos sanos
try:
    data = np.loadtxt('ecg_healthy_raw.txt')
    print(f"Señal sana cargada: {len(data)} muestras.")
except Exception as e:
    print(f"Error: {e}")
    exit()

# 2. Extraer el latido patrón
inicio_latido = 50
fin_latido = 330
patron = data[inicio_latido:fin_latido]
muestras_latido = len(patron)

# 3. Definir la secuencia de intervalos (en muestras)
# Un ritmo normal a 360Hz son ~280 muestras (777ms)
# Arritmia: Normal -> Normal -> PREMATURO -> PAUSA COMPENSATORIA -> Normal
intervalos_muestras = [280, 280, 180, 420, 280, 280, 180, 420]

def generar_silencio(n_muestras, ultimo_valor):
    if n_muestras < 0: return np.array([])
    return np.full(n_muestras, ultimo_valor)

# 4. Construir la señal
arrhythmia_data = []
for gap in intervalos_muestras:
    arrhythmia_data.extend(patron)
    # El silencio es el gap total menos lo que ya dura el latido
    n_silencio = gap - muestras_latido
    if n_silencio > 0:
        arrhythmia_data.extend(generar_silencio(n_silencio, patron[-1]))

# 5. Guardar en formato 3 columnas para Vivado
with open("ecg_arrhythmia_mit.txt", "w") as f:
    for val in arrhythmia_data:
        v = int(val)
        f.write(f"{v} {v} 0\n")

print("Archivo 'ecg_arrhythmia_mit.txt' generado.")
print("Secuencia: 2 latidos normales, 1 prematuro (-35%), 1 pausa (+50%)")