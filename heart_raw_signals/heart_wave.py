import wfdb
import numpy as np

# === CONFIGURACIÓN ===
FILENAME = "ecg_healthy_raw.txt"
SAMPLES = 5000          
AMPLITUD_MAX = 6000000  

try:
    record = wfdb.rdrecord('100', pn_dir='mitdb', sampfrom=0, sampto=SAMPLES)
    raw_signal = record.p_signal[:, 0]
except Exception as e:
    print(f"Error: {e}")
    exit()

# Escalado a 24 bits
max_val = np.max(np.abs(raw_signal))
int_signal = (raw_signal / max_val * AMPLITUD_MAX).astype(int)

np.savetxt(FILENAME, int_signal, fmt='%d')