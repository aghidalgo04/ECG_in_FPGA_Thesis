import wfdb

# Registro 200: Taquicardia Ventricular muy clara
# Descargamos los valores digitales originales (physical=False)
# Esto te dará los enteros puros del archivo sin convertirlos a mV
record = wfdb.rdrecord('200', pn_dir='mitdb', sampfrom=0, sampto=3000, physical=False)
digital_signal = record.d_signal

# Guardar en formato X Y Z (Valores reales del MIT-BIH)
with open("ecg_mit_raw_tachy.txt", "w") as f:
    for i in range(len(digital_signal)):
        val_x = digital_signal[i, 0] # Canal MLII
        val_y = digital_signal[i, 1] # Canal V1
        val_z = 0
        f.write(f"{val_x} {val_y} {val_z}\n")

print("Archivo 'ecg_mit_raw_tachy.txt' generado con valores digitales reales.")