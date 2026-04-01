# 🗺️ CÓMO CREAR TU PROPIO MAPA EN PVPROLL
### (Sin programar — solo con nodos de Godot)

---

## 📋 RESUMEN RÁPIDO

Para crear un mapa necesitas **2 ficheros**:
1. Un `.gd` muy pequeño (3 líneas, copias y pegas)
2. Una `.tscn` que haces desde el editor visual

---

## 🧱 PASO 1 — Crear el script del mapa (3 líneas)

1. Abre Godot y en el panel **FileSystem** (abajo-izquierda) ve a la carpeta `scenes/maps/`
2. Haz **clic derecho → New Script**
3. Ponle de nombre, por ejemplo, `mi_mapa.gd`
4. Borra todo lo que haya dentro y escribe **exactamente esto**:

```gdscript
extends BaseArena

func _setup_arena():
	pass
```

> ✅ Eso es todo el código que necesitas. El `pass` significa "mapa vacío solo con paredes".  
> Si quieres añadir obstáculos de código, lo harás más adelante (sección **EXTRA**).

---

## 🏗️ PASO 2 — Crear la escena del mapa

1. En Godot, menú superior: **Scene → New Scene**
2. En el panel de arriba (Scene tree), haz clic en el botón **"+"** (Add Child Node)
3. Busca **`Node2D`** y selecciónalo → **"Create"**
4. Con ese nodo seleccionado, en el panel de la derecha (**Inspector**) busca el campo **Script** y arrastra ahí tu `mi_mapa.gd`
5. Guarda la escena: **Ctrl+S** → llámala `mi_mapa.tscn` (en `scenes/maps/`)

> Ahora si abres el Inspector verás un montón de propiedades que puedes cambiar, como el tamaño del mapa, colores, etc.

---

## 📐 PASO 3 — Ajustar el tamaño del mapa

En el **Inspector** (panel derecho), busca el grupo **"Dimensiones"**:

| Propiedad | Qué hace | Valor por defecto |
|---|---|---|
| `Arena Size` | Tamaño total en píxeles (X = ancho, Y = alto) | 1152 × 648 |
| `Wall Thickness` | Grosor de las paredes del borde | 16 px |

💡 **Ejemplo mapa grande:** X = `2048`, Y = `1152`  
💡 **Ejemplo mapa pequeño:** X = `800`, Y = `600`

---

## 📍 PASO 4 — Poner los Spawn Points (¡OBLIGATORIO!)

Los spawn points son los puntos donde aparecen los jugadores y los objetos. Sin ellos el juego no sabe dónde poner a los personajes.

### Cómo añadir un Spawn de Jugador:

1. En el **Scene tree** (panel izquierdo), selecciona el nodo raíz de tu mapa
2. Haz clic en **"+"** → busca **`Marker2D`** → Create
3. En el campo **Name** (Inspector) ponle exactamente:
   - `SpawnP1` → para el Jugador 1
   - `SpawnP2` → para el Jugador 2
4. **Mueve el Marker2D** haciendo clic sobre él en la escena y arrastrándolo al lugar donde quieres que aparezca cada jugador

> ⚠️ Los nombres deben empezar exactamente con `SpawnP` (con la P mayúscula). El juego los detecta automáticamente.

### Cómo añadir Spawns de Objetos (Pickups):

1. Haz clic en **"+"** → busca **`Marker2D`** → Create
2. Nómbralo `PickupSpawn1`, `PickupSpawn2`, `PickupSpawn3`... (pueden ser los que quieras)
3. Colócalos por el mapa donde quieras que aparezcan los objetos (curaciones, escudos, etc.)

> 💡 Si no pones ningún `PickupSpawn`, los objetos aparecerán en el centro del mapa.

---

## 🧱 PASO 5 — Añadir paredes y obstáculos con nodos (sin código)

Esta es la parte **visual**. Puedes poner paredes como nodos normales en el editor.

### Crear una pared o caja de colisión:

1. En el Scene tree, selecciona el nodo raíz
2. Haz clic en **"+"** → busca **`StaticBody2D`** → Create
3. Con el `StaticBody2D` seleccionado, haz clic en **"+"** de nuevo → **`CollisionShape2D`**
4. En el Inspector del `CollisionShape2D`, haz clic en **"Shape"** → **"New RectangleShape2D"**
5. Aparecerá un rectángulo naranja en la escena → arrástralo/escálalo donde quieras

> 🔑 **IMPORTANTE:** El `StaticBody2D` necesita estar en la **capa de colisión 3** para que los jugadores y balas choquen con él.  
> En el Inspector del `StaticBody2D` busca **"Collision"** → **"Layer"** → activa solo el bit **3** (el tercero).

### Para que la pared se vea (opcional, si no tienes sprites):

1. Con el `StaticBody2D` seleccionado, haz **"+"** → **`ColorRect`** o **`Sprite2D`**  
2. Ajusta el tamaño para que tape visualmente la pared de colisión

---

## 🎨 PASO 6 — Cambiar los colores de fondo (sin sprites)

Si no tienes sprites de mapa todavía, puedes personalizar los colores en el Inspector:

| Propiedad (grupo "Colores Placeholder") | Descripción |
|---|---|
| `Background Color` | Color del suelo/fondo |
| `Wall Color` | Color de las paredes del borde |
| `Obstacle Color` | Color de los obstáculos internos |
| `Wall Border Color` | Color del borde de las paredes |

---

## 🔌 PASO 7 — Registrar el mapa en el juego

Para que el juego use tu mapa **en lugar del existente**:

1. Abre la escena principal del juego: `scenes/main/main.tscn`
2. En el Scene tree busca el nodo del mapa actual (probablemente se llama `ArenaSimple` o similar)
3. **Bórralo** (clic derecho → Delete)
4. Haz clic en **"+"**, busca **"Instance Child Scene"** (o arrastra tu `.tscn` desde el FileSystem)
5. Selecciona tu `mi_mapa.tscn`

> ✅ ¡El juego usará tu mapa automáticamente!

---

## 🎮 EXTRAS — Obstáculos rápidos con código (solo si quieres)

Si quieres añadir obstáculos simétricos y rápidos **sin hacer nodos a mano**, puedes añadir estas líneas dentro de `func _setup_arena():` en tu `.gd`:

```gdscript
func _setup_arena():
    # 4 pilares simétricos (distancia desde centro, tamaño del pilar)
    add_symmetric_pillars(300, 150, 60)

    # Una pared horizontal en el centro
    add_cover(arena_size / 2, 200, 20)

    # Dos coberturas simétricas a los lados
    add_symmetric_covers_h(350, 0, 80, 20)
```

### Referencia de funciones disponibles:

| Función | Qué hace |
|---|---|
| `add_symmetric_pillars(offset_x, offset_y, tamaño)` | 4 pilares simétricos alrededor del centro |
| `add_cover(Vector2(x,y), ancho, alto)` | Una caja de cobertura centrada en esa posición |
| `add_symmetric_covers_h(offset_x, offset_y, ancho, alto)` | 2 cajas simétricas horizontalmente |
| `add_pillar(Vector2(x,y), tamaño)` | Un pilar suelto donde quieras |
| `add_cross(Vector2(x,y), longitud_brazo, grosor)` | Una cruz de paredes |

> 📌 `arena_size / 2` es siempre el centro del mapa. Úsalo como referencia.

---

## ✅ CHECKLIST FINAL

Antes de probar tu mapa asegúrate de que:

- [ ] La escena `.tscn` tiene el script `mi_mapa.gd` asignado al nodo raíz
- [ ] Existe un `Marker2D` llamado `SpawnP1`
- [ ] Existe un `Marker2D` llamado `SpawnP2`
- [ ] Los `StaticBody2D` de paredes tienen **Collision Layer = bit 3**
- [ ] El mapa está instanciado en `main.tscn`
- [ ] Guardaste todos los ficheros (**Ctrl+S** en cada pestaña abierta)

---

## ❓ PREGUNTAS FRECUENTES

**¿Por qué el jugador 1 aparece en el centro del mapa?**  
→ Falta el `Marker2D` llamado exactamente `SpawnP1`. Cómproba que no tenga espacio ni error tipográfico.

**¿El mapa no aparece / sale negro?**  
→ Comprueba que el nodo raíz de tu escena tiene el script asignado en el campo **Script** del Inspector.

**¿Los jugadores atraviesan las paredes?**  
→ El `StaticBody2D` no tiene el **Collision Layer 3** activado, o le falta el `CollisionShape2D` hijo.

**¿Puedo tener varios mapas y que se elija uno al azar?**  
→ Aún no está implementado, pero es posible. Díselo al asistente y lo añadimos.
