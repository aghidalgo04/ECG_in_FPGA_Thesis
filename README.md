# Real-Time ECG Diagnosis System

The **Real-Time ECG Diagnosis System** is an advanced embedded medical solution developed in VHDL for FPGAs. It processes 3-lead electrocardiogram (ECG) signals in real-time, utilizing **Discrete Wavelet Transforms (DWT)** to detect life-threatening cardiac pathologies with high precision and reliability.

## Overview

The primary objective of REDIS is to provide an autonomous monitoring system capable of identifying cardiac anomalies without high-level software processing. By leveraging FPGA hardware parallelism, the system analyzes the morphological characteristics of the QRS complex and the T-wave to calculate vital intervals (RR and RT).

The system implements a **2-out-of-3 voting architecture** to ensure robustness against sensor noise and signal artifacts, providing a synchronized diagnosis even in sub-optimal electrode conditions.

---

## Current Status & Roadmap

### ✅ Completed (Done)
* **3D Wavelet Engine:** Real-time extraction of $S_3$ and $S_8$ scales for multi-lead ECG processing.
* **QRS & T-wave Detectors:** FSM-based peak and zero-crossing detection with adaptive memory thresholds.
* **Detection Bridge:** Implementation of **2-out-of-3 voting logic** and **Pulse Stretching** for axis synchronization.
* **Group Delay Compensation:** Mathematical alignment of $S_3$ and $S_8$ delays (**60ms / 230ms** offsets) to ensure accurate RT interval measurement.
* **Diagnosis Logic:** Prioritized alarm system for **Asystole, Sudden Death (Long QT), Tachycardia, Bradycardia, and Arrhythmia**.
* **Functional Validation:** Simulation using real patient data from the **MIT-BIH Database** at various sampling rates (360Hz and 1000Hz).

### ⏳ To Do (Future Work)
* **Physical ADC Integration:** Implementation of SPI/XADC protocols to interface with sensors like AD8232.
* **P-Wave Expansion:** Addition of Scale $S_9/S_{10}$ to detect P-waves for Atrial Fibrillation (A-Fib) diagnosis.
* **Hardware Prototyping:** Final deployment on **Basys 3 / Nexys** board using physical alarm LEDs and a buzzer for critical alerts.

---

## Key Features

### Advanced DSP & Diagnosis
* **Clinical Precision:** Real-time calculation of RR and RT intervals with millisecond accuracy.
* **Priority Alarm Hierarchy:** Intelligent masking system where **Asystole** takes absolute priority, silencing lower-level rhythm alerts to prevent alarm fatigue.
* **Adaptive Thresholding:** The detection logic adapts to the patient's signal amplitude, maintaining sensitivity during signal fluctuations.
* **Sudden Death Prevention:** Specialized logic for Long QT Syndrome, including a smart filter that adjusts thresholds during high heart rates.

### Efficient Hardware Design
* **Resource Optimization:** Use of `shift_right` operations for 25% (Arrhythmia) and 50% (QT) calculations, minimizing LUT/DSP usage.
* **Multi-Lead Robustness:** Voting logic prevents false positives caused by a single failing or noisy electrode.

---

## Software Structure (VHDL Modules)

* **`wavelet_3d_transform.vhd`**: The core DSP engine extracting morphological scales.
* **`qrs_detector.vhd` / `t_detector.vhd`**: FSM-based units for specific wave detection.
* **`detection_bridge.vhd`**: Voting logic and inter-scale time synchronization.
* **`detection_module.vhd`**: The "Medical Brain" that evaluates intervals and manages prioritized alarm flags.

---

## Testing & Verification

* **Pathological Simulation:** Testbenches validated against Tachycardia (240 BPM), Arrhythmia, and Asystole conditions.
* **Sample Rate Scaling:** Validated performance at 360Hz (PhysioNet standard) using custom `wait` timing in simulation to match real-world data acquisition.
* **Priority Logic Verification:** Confirmed that the Asystole watchdog correctly overrides Tachycardia/Bradycardia flags in a cardiac arrest scenario.

---
