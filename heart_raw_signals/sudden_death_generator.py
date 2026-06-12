import numpy as np
import random

try:
    data = np.loadtxt('ecg_healthy_raw.txt')
    if data.ndim > 1: data = data[:, 0]
except Exception as e:
    print(f"Error cargando archivo: {e}")
    exit()

# 1. LATIDO BASE (320 muestras)
latido_base = data[50:370].copy()
# Suavizado de cola para evitar dobles QRS (transición a cero)
latido_base[-10:] = np.linspace(latido_base[-11], latido_base[0], 10)

# 2. FUNCIÓN GENERADORA CON VARIABILIDAD (JITTER)
def crear_latido_realista(base, es_peligro):
    corte_st = 85
    
    # === AUMENTAMOS EL RETRASO A 70 MUESTRAS ===
    # 70 muestras * 2.77ms/muestra = ~194ms extra sobre el RT original.
    # Esto empujará tu RT por encima de los 400ms, superando el umbral del 43.75%.
    retraso_base = 70 if es_peligro else 0
    
    # JITTER DE ONDA T: Desplaza la onda T entre -1 y +1 muestras para realismo
    jitter_t = random.randint(-1, 1)
    retraso_total = max(0, retraso_base + jitter_t) 
    
    # JITTER DE RR: Mantenemos el RR muy estable para no disparar la arritmia
    jitter_rr = random.randint(-1, 1)
    
    p1 = base[:corte_st]
    p2 = np.full(retraso_total, base[corte_st]) # El estiramiento plano
    
    # Compensación de tamaño: el latido final debe medir lo mismo que el original
    recorte = retraso_total - jitter_rr
    
    if recorte > 0:
        p3 = base[corte_st : -recorte]
    elif recorte < 0:
        p3 = np.concatenate((base[corte_st:], np.full(-recorte, base[-1])))
    else:
        p3 = base[corte_st:]
        
    return np.concatenate((p1, p2, p3))

# 3. ENSAMBLAR LA SECUENCIA (12 Latidos)
secuencia = []
for _ in range(3): secuencia.extend(crear_latido_realista(latido_base, False))
for _ in range(6): secuencia.extend(crear_latido_realista(latido_base, True)) # Más latidos para ver la persistencia
for _ in range(3): secuencia.extend(crear_latido_realista(latido_base, False))

# 4. GUARDAR
with open("ecg_70_muestras_delay.txt", "w") as f:
    for val in secuencia:
        f.write(f"{int(val)} {int(val)} 0\n")

print("Archivo 'ecg_70_muestras_delay.txt' generado.")
print("Retraso base de 70 muestras aplicado.")