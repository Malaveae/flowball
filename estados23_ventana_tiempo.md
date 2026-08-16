# Presión Temporal — Ventanas de Tiempo de los Estados 2 y 3
**Módulo del documento:** `diseno_tiro_libre_3_estados.md` · v1.0 — Agosto 2026
**Dependencias:** `estado1_potencia_calibracion.md` (curva de potencia), sistema de jugadores/atributos

---

## 1. Concepto

La potencia cargada en el Estado 1 (p, 0–120%) determina la velocidad de la carrera de impulso y, por tanto, el **tiempo real que el jugador tiene para reaccionar** en los Estados 2 y 3. Más potencia = llegada más rápida al balón = menos tiempo para apuntar y aplicar efecto.

Justificación física: la velocidad de aproximación en tiros libres reales llega a ~9 m/s; una carrera más potente reduce el tiempo entre el plante del apoyo y el impacto. El juego traslada esa relación a las ventanas de decisión.

---

## 2. Fórmulas base (dificultad normal)

```
T2(p) = 2.6 − 1.5 × (p / 120)     → ventana del Estado 2 (pie de apoyo), en segundos
T3(p) = 2.0 − 1.2 × (p / 120)     → ventana del Estado 3 (contacto + roce), en segundos
```

## 3. Tabla de calibración

| Potencia | T2 (apoyo) | T3 (contacto) | Decisión total | Perfil de uso |
|---:|---:|---:|---:|---|
| 30% | 2,23 s | 1,70 s | ~3,9 s | Tutorial, tiros cortos con rosca elaborada |
| 50% | 1,98 s | 1,50 s | ~3,5 s | Juego cómodo, 18–22 m |
| 65% | 1,79 s | 1,35 s | ~3,1 s | Juego medio, 22–28 m |
| 85% | 1,54 s | 1,15 s | ~2,7 s | Sweet spot: máximo equilibrio |
| 100% | 1,35 s | 1,00 s | ~2,4 s | Potencia plena controlable |
| 120% | 1,10 s | 0,80 s | ~1,9 s | Sobrecarga: solo gestos simples |

**Regla de diseño:** por encima de 100% solo debe dar tiempo a un gesto de roce simple (desliz recto o curva básica). Las técnicas complejas (trivela, rosca cerrada con punto de contacto lateral) son viables hasta ~95%.

---
