# Estado 3 — Trazado de Contacto y Roce sobre el Balón
**Módulo del documento:** `diseno_tiro_libre_3_estados.md` · v1.0 — Agosto 2026
**Sustituye a:** sección 5 del documento principal (selector manual de superficie + desliz)
**Dependencias:** `estado1_potencia_calibracion.md`, `estados23_ventana_tiempo.md`, `estado2_mecanica_talon_v3.md`, sistema de atributos.

---

## 1. Concepto

En la ventana de impacto (cámara lenta, zoom al balón), el jugador **traza sobre la cara del balón** imaginando la interacción del zapato con él. El juego **clasifica el gesto** y deduce la superficie de contacto y el efecto — no hay menú de superficies. Cuatro descriptores definen el gesto: **punto de inicio, longitud, curvatura y velocidad**.

Base real: empeine frontal = potencia/larga distancia; empeine interior = rosca para superar obstáculos; interior = precisión; empeine exterior = trivela; puntera = recurso de poco espacio. Zonas del balón: superior = raso, centro = media/recta, inferior = se eleva, laterales = curva.

---

## 2. Clasificador de gestos → técnica

| Gesto | Superficie reconocida | Efecto |
|---|---|---|
| Toque simple (punto, sin arrastre) | Puntera | Picado, imprevisible, baja potencia |
| Recto corto (< 40% L_max), curvatura baja, centrado | Empeine frontal | Potencia máxima; roce casi nulo → **knuckleball** |
| Recto largo (> 60% L_max), curvatura baja | Empeine frontal + follow-through | Potencia + estabilidad direccional |
| Curvo envolvente hacia dentro (lado del pie dominante) | Empeine interior | **Rosca**: curva al lado natural |
| Curvo envolvente hacia fuera (lado contrario) | Empeine exterior | **Trivela**: curva invertida |
| Barrido ascendente (abajo→arriba, cara trasera) | Empeine frontal bajo | **Topspin**: sube y baja rápido (dip) |
| Barrido descendente | Interior alto | **Backspin**: el balón flota |
| Curvo + ascendente (diagonal envolvente) | Interior / empeine interior | **Rosca con dip** — la clásica sobre la barrera |

### Umbrales del clasificador (prototipo)
- Curvatura baja: desviación del trazo < 12% de su longitud.
- Envolvente: ángulo barrido del trazo ≥ 90° alrededor de su propio centro.
- Ascendente/descendente: componente vertical media > 55% de la velocidad del trazo.
- Conflicto de firmas: gana la de mayor similitud; si la confianza < 60%, se etiqueta "contacto sucio" con dispersión extra.

---

## 3. Descriptores del gesto → física

| Descriptor | Medición | Traducción |
|---|---|---|
| Punto de inicio (x, y) | Coordenadas sobre la cara del balón | Elevación base: inferior +3°, centro 0°, superior −2°; lateral = predisposición de curva (±1°) |
| Longitud L | Recorrido total / L_max | Tiempo de roce → estabilidad del efecto y factor de superficie |
| Curvatura C | Desviación vs recta del trazo | Magnitud del spin lateral (RPM) |
| Dirección D | Signo de C + orientación media | Eje de rotación: lado de curva; componente vertical = topspin/backspin |
| Velocidad V | Velocidad media del puntero | RPM del spin junto con C |

---

## 4. L_max variable: la potencia y las habilidades acotan el roce

### Límite espacial (cuánto balón puede abrazar el zapato)
```
L_esp(p, CUR) = 260 − 90 × (p/120) + (CUR − 50) × 0.8     [píxeles]
```

### Límite temporal (cuánto gesto cabe en la ventana de impacto)
```
L_temp(p) = v_gesto × T3(p)      con v_gesto ≈ 350 px/s
```

### L_max aplicado
```
L_max = min(L_esp, L_temp)
```

| Potencia | T3 | L_esp (CUR 50) | L_esp (CUR 90) |
|---:|---:|---:|---:|
| 30% | 1,70 s | 270 px | 302 px |
| 65% | 1,35 s | 241 px | 273 px |
| 85% | 1,15 s | 226 px | 258 px |
| 100% | 1,00 s | 215 px | 247 px |
| 120% | 0,80 s | 170 px | 202 px |

**Consecuencia de diseño:** a potencia alta/sobrecarga solo caben gestos cortos (puntera, empeine seco, knuckleball). Las roscas largas envolventes exigen potencia contenida o CUR alta. El trade-off potencia↔efecto se siente en la mano, no solo en números.

---

## 5. Calidad de ejecución (0–100%)

| Componente | Peso | Qué mide |
|---|---:|---|
| Limpieza | 40% | Desviación lateral respecto a la firma ideal (temblor) |
| Consistencia de velocidad | 30% | Roce uniforme = spin limpio; trazo entrecortado lo rompe |
| Punto de inicio | 30% | Cuadrante correcto del balón para esa técnica |

```
intensidad_efecto = 0.5 + 0.5 × calidad
RPM_efectivo      = min(RPM_gesto, 150 + 4.5 × CUR) × intensidad_efecto
dispersión_extra  = (1 − calidad) × 2° × (1 − PRE/200)
```

PRE amplía la ventana de tolerancia de limpieza; CUR sube el techo de RPM.

---

## 6. Interacción con Estados 1 y 2

- **Estado 2 (talón):** d_ap > +4 cm habilita trivela; −8 a +4 cm habilita todo; < −20 cm da bonus knuckleball (+15% calidad en recto corto centrado). Técnica no habilitada → superficie más cercana con calidad ×0,7.
- **Estado 1 (potencia):** fija L_max y T3. En sobrecarga solo son viables gestos simples.
- **Recetas objetivo:**
  - Rosca clásica: potencia 60–80% + talón ligeramente adelantado + trazo curvo largo ascendente.
  - Misil/knuckleball: potencia 95–120% + talón retrasado + recto corto centrado.
  - Trivela: potencia 70–90% + talón adelantado + curvo hacia fuera.

---

## 7. Feedback UI/UX

- **Estela del trazo** con color por técnica reconocida en vivo: gris (indefinido) → azul empeine, magenta rosca, naranja topspin, verde trivela, rojo contacto sucio.
- **Etiqueta flotante** con técnica detectada y % de calidad cuando hay confianza del clasificador.
- **Arco fantasma** sobre el balón que se consume con la longitud trazada (muestra L_max restante); la retícula se encoge con la ventana T3.
- **Timeout T3:** si no hay gesto, contacto automático empeine al centro sin efecto ("disparo ciego"); si el trazo queda a la mitad, se ejecuta con calidad proporcional.
- Desglose post-tiro: técnica, calidad %, RPM, punto de contacto y superficie reconocida.

---

## 8. Telemetría

- Distribución de técnicas intentadas vs reconocidas (tasa de "contacto sucio" por técnica).
- Longitud de trazo media por banda de potencia (¿los jugadores perciben el límite L_max o lo ignoran?).
- % de gestos que agotan L_temp antes de terminar la firma (si alto en rosca a 85%, revisar v_gesto o la curva T3).
- Correlación calidad de ejecución → tasa de gol por técnica (balanceo de firmas).
