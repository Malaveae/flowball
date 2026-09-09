# Stadium Revamp Plan — Flowball

## Overview

Revamp del estadio del free-kick sandbox basado en los mockups de `G:/Coding/Flowball III/assets/Inputs RAW/REvamp/`.  
Objetivo: ambiente más limpio, detallado y coherente con la estética sci-fi del HUD.

---

## Mockups de Referencia

| Archivo | Contenido | Implicancia |
|---------|-----------|-------------|
| `Clean Soccer Gameplay Scene.png` | Vista general gameplay | Dirección visual general |
| `Empty Stadium Goal View.png` | Vista desde el arco | Ambiente de tribunas |
| `Top-Down Stadium Penalty Spot.png` | Vista cenital | Marcaciones de campo |
| `Penalty Spot Turf Close Up.png` | Close-up césped | Textura de grass |
| `Sci-Fi Soccer HUD Edits.png` | HUD sci-fi | Estética UI |
| `Sci-Fi Soccer Stage HUD Edit.png` | UI del stage | Elementos de stage |

---

## Análisis del Estado Actual

### FreeKickSandbox.tscn — Componentes

```
├── WorldEnvironment (ProceduralSkyMaterial + Environment)
├── DirectionalLight3D (sol principal)
├── StadiumLighting (9 SpotLight3D/OmniLight3D)
├── TestPitch (BoxMesh con pitch_ground shader)
├── GrassPatch0-13 (14 MultiMeshInstance3D con grass_card shader)
├── GoalBackgroundFloor (suelo detrás del arco)
├── FieldLines (FootballFieldMarkings3D)
├── Ball3D
├── Goal (goal.glb - arco)
├── GoalNetVisual
├── Goalkeeper
├── GoalCollision + GoalTrigger + GoalNetCollision
├── TribunaBackground (QuadMesh con Tribuna.png)
├── LeftLateralBackground + RightLateralBackground
├── Player3D
├── Camera3D
└── FreeKickController
```

### Assets Actuales

| Asset | Tipo | Estado |
|-------|------|--------|
| `assets/Tribuna.png` | Textura tribuna | Calidad media, necesito mejorar |
| `assets/Cesped/grass_*.png` | Texturas césped | Calidad media |
| `assets/models/goal.glb` | Arco | Básico, creado con Blender script |
| `assets/shaders/grass_card.gdshader` | Shader grass | Funcional |
| `assets/shaders/pitch_ground.gdshader` | Shader pitch | Funcional |

---

## Plan de Implementación — Fases

### Fase 1: Iluminación y Atmósfera
**Prioridad: ALTA**

1. **Actualizar ProceduralSkyMaterial**
   - Colores más vibrantes (azules más saturados)
   - Mejor gradiente horizon → sky
   - Ajustar `sun_angle_max` para golden hour feel

2. **Revisar Environment**
   - Ajustar `ambient_light_color` para más calidez
   - Afinar SSAO (menos intenso, más natural)
   - Glow más sutil para no saturar

3. **Ajustar StadiumLighting**
   - SpotLights más focalizados en el área de gol
   - Reducir fugas de luz en los laterales
   - Mejorar balance de sombras

**Archivos a modificar:**
- `scenes/sandbox/FreeKickSandbox.tscn` (sub_resources)

**Assets necesarios:**
- Ninguno (ajustes de parámetros)

---

### Fase 2: Césped y Campo
**Prioridad: ALTA**

1. **Generar nuevas texturas de césped**
   - Resolución más alta (4K albedo, 2K normal)
   - Más variación de color
   - Patrón de rayado más definido

2. **Ajustar shader parameters**
   - `stripe_strength` más visible
   - `patch_noise_strength` para naturales
   - `wear_strength` mejorado

3. **Revisar GrassPatch instances**
   - Considerar reducir count de instancias (99960 es alto)
   - Optimizar para performance

**Archivos a modificar:**
- `scenes/sandbox/FreeKickSandbox.tscn`
- `scripts/sandbox/GrassPatch3D.gd`

**Assets a generar (Hedra):**
- [ ] `grass_albedo_4k.png` - Textura de césped 4096x4096
- [ ] `grass_normal_2k.png` - Normal map detallado
- [ ] `grass_roughness_2k.png` - Roughness map

---

### Fase 3: Tribunas y Fondo
**Prioridad: MEDIA**

1. **Generar nueva textura de tribuna**
   - Estilo: mezcla entre fotografía y render
   - Paleta coherente con el proyecto
   - Perspective-correct UV mapping

2. **Agregar elementos 3D de tribuna**
   - Geometría de asientos con parallax
   - Estructura de soporte del techo
   - Indicadores de publicidad (si aplica)

3. **Mejorar transición campo → tribuna**
   - Gradiente más suave
   - Menos hard edge

**Archivos a modificar:**
- `scenes/sandbox/FreeKickSandbox.tscn`
- Posible nuevo nodo `StadiumStands.tscn`

**Assets a generar (Hedra):**
- [ ] `stadium_stands_panoramic.png` - Vista panorámica 8192x2048
- [ ] `stadium_stands_side.png` - Vista lateral para tribunas laterales

**Assets a modelar (Blender):**
- [ ] Geometría de tribunas (asientos, estructura)

---

### Fase 4: Arco y Red
**Prioridad: MEDIA**

1. **Mejorar goal.glb**
   - Postes con sección circular real (no cylinders)
   - Detalle de soldaduras/soportes
   - Material con roughness más realista

2. **GoalNetVisual3D**
   - Red más detallada (shader o geometry)
   - Física de red cuando la pelota entra
   - Material semi-transparente mejorado

3. **Back net mesh**
   - Considerar geometría real de red
   - Animación de "wave" cuando gol

**Archivos a modificar:**
- `tools/blender/create_goal_and_goalkeeper.py`
- `scripts/sandbox/GoalNetVisual3D.gd`

**Assets a modelar (Blender):**
- [ ] `goal_improved.glb` - Arco con mejor geometría
- [ ] `goal_net_mesh.glb` - Red 3D (alternativa al shader)

---

### Fase 5: Estética Sci-Fi (HUD)
**Prioridad: BAJA** (ya está parcialmente implementado)

1. **Refinar estilo visual del HUD**
   - Basado en `Sci-Fi Soccer HUD Edits.png`
   - Colores neón sutiles
   - Tipografía consistente

2. **Elementos de stage**
   - Indicadores de zona de tiro
   - Efectos de partículas al patear
   - UI de feedback post-tiro

**Nota:** Esto es trabajo de UI, no de stadium per-se.

---

## Assets Requirements Summary

### Texturas a Generar en Hedra

| Textura | Resolución | Uso |
|---------|------------|-----|
| `stadium_stands_panoramic` | 8192x2048 | Tribuna trasera |
| `stadium_stands_side` | 4096x2048 | Tribunas laterales |
| `grass_albedo_4k` | 4096x4096 | Césped principal |
| `grass_normal_2k` | 2048x2048 | Normal map césped |
| `grass_roughness_2k` | 2048x2048 | Roughness césped |
| `crowd_texture` | 4096x4096 | Detalle de multitud |

### Modelos a Crear en Blender

| Modelo | Descripción | Prioridad |
|--------|-------------|-----------|
| `goal_improved.glb` | Arco mejorado | Alta |
| `stadium_seats.glb` | Asientos tribuna | Media |
| `roof_structure.glb` | Estructura del techo | Baja |
| `scoreboard.glb` | Tablero de marcador | Baja |

### Scripts a Crear/Modificar

| Script | Acción |
|--------|--------|
| `tools/blender/create_stadium.py` | Crear stadium seats geometry |
| `tools/blender/create_goal_improved.py` | Mejorar goal.glb |
| `scripts/sandbox/StadiumEnvironment.gd` | Nuevo script para管理 ambiente |

---

## Timeline Estimado

```
Semana 1: Fase 1 (Iluminación) + Fase 2 (Césped)
Semana 2: Fase 3 (Tribunas) + Generar texturas en Hedra
Semana 3: Fase 4 (Arco) + Modelar en Blender
Semana 4: Testing + Integración + Polish
```

---

## Verification Checklist

- [ ] Smoke test pasa: `godot --headless --script scripts/tests/ShotCalculatorSmokeTest.gd`
- [ ] FPS estable en target (60fps desktop, 30fps mobile)
- [ ] No visual artifacts en grass shader
- [ ] Tribunas sin flickering de z-order
- [ ] Luz de estadio ilumina correctamente el arco
- [ ] Goal net reacciona a goles
- [ ] Goalkeeper animations funcionan post-cambio de modelo

---

## Notes

- Mantener backward compatibility con scripts existentes
- No cambiar dimensiones del campo (68x105m)
- Preservar estado de debug del grass shader
- Documentar cambios en `piedeapoyo.md`
