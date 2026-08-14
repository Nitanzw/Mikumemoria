# 🎨 Pedido de arte — El Huerto de Sofía

Todo lo que hay que generar con Nano Banana para reemplazar el arte
actual, con el prompt listo para copiar y pegar, el tamaño y **el nombre
de archivo exacto** que espera el código.

**48 imágenes en total.** Los prompts están en inglés a propósito (los
modelos de imagen responden bastante mejor); las explicaciones van en
castellano.

> ⚠️ **Los nombres de archivo importan.** El juego carga los assets por
> ruta fija. Si guardás algo con otro nombre, no aparece y no tira error
> — simplemente no se ve. Respetá la columna "Guardar como".

---

## 📖 Índice

1. [Cómo trabajar (leer antes de generar)](#1-cómo-trabajar)
2. [Bloques que se repiten](#2-bloques-que-se-repiten)
3. [Sofía](#3-sofía--8-imágenes) · 8
4. [Menú](#4-menú--3-imágenes) · 3
5. [Insectos comunes + caminata](#5-insectos-comunes--5--5) · 5 + 5
6. [Incógnitos](#6-incógnitos--11-imágenes) · 11
7. [Armas](#7-armas--5-imágenes) · 5
8. [Fondos de capítulo](#8-fondos-de-capítulo--10-imágenes) · 10
9. [Ícono](#9-ícono--1-imagen) · 1
10. [Checklist](#10-checklist)
11. [Qué hago yo cuando estén](#11-qué-hago-yo-cuando-estén)

---

## 1. Cómo trabajar

### El orden importa (te ahorra plata)

No generes en cualquier orden. Nano Banana acepta **imágenes de
referencia**, y ahí está el truco para que todo quede coherente:

1. **Primero: Sofía neutral** (§3.1). Iterá esa sola hasta que te guste
   de verdad. Puede llevarte 5 o 10 intentos y está perfecto.
2. Esa imagen aprobada pasa a ser **la referencia de Sofía**. Para las
   otras 7 de Sofía, adjuntala y escribí:
   `Using the attached character reference, keep her face, hair, outfit and colors EXACTLY the same. Now draw her <lo que pidas>.`
   Sin esto, cada imagen te va a salir con otra cara.
3. **Después: una hormiga obrera** (§5.1). Iterala hasta que el estilo
   te cierre. Esa pasa a ser **la referencia de estilo de los bichos**.
4. Para los otros 15 insectos, adjuntá la hormiga aprobada:
   `Using the attached image as the STYLE reference (same rendering, outline weight, shading and color richness), draw a completely different insect: <descripción>.`
5. Recién al final los fondos, que no necesitan referencia entre sí más
   allá del bloque de estilo.

### Fondo transparente

Los insectos, armas, Sofía y el logo **necesitan fondo transparente**.
Dos caminos, probá en este orden:

- **Pedí PNG transparente directo.** Si te lo da limpio, listo.
- **Si te devuelve fondo:** pedilo sobre **verde puro (#00FF00)** usando
  el bloque `[RECORTE]` de abajo, y después pasalo por el script del
  repo, que samplea el color real del borde y hace flood-fill:
  ```bash
  python3 tools/generate_sprites_openrouter.py --help   # ver la lógica
  ```
  o mandámelo y yo le hago el recorte.

> No uses magenta. Ya lo probé: el modelo no respeta el `#FF00FF` exacto
> y encima les mete tonos rosados a las patas de los bichos marrones,
> que después el recorte se come. El verde da mucho menos problema.

### Iterar

Como tenés Nano Banana paga, aprovechá que **edita imágenes**, no solo
las crea de cero. Si una sale casi bien:

> `Keep everything identical, only change: <el detalle>.`

Sale más barato y más consistente que volver a tirar el prompt entero.

---

## 2. Bloques que se repiten

Copiá estos bloques dentro de los prompts donde diga `[ESTILO]`,
`[SOFÍA]` o `[RECORTE]`.

### `[ESTILO]` — va en TODAS las imágenes

```
polished mobile game art, soft cel shading with rim light, subtle gradients,
painterly texture, rich saturated palette, clean readable silhouette,
no text, no watermark, no signature, no logo, high detail
```

### `[SOFÍA]` — va en toda imagen donde aparezca ella

Este bloque es lo que la mantiene siendo la misma persona. **No lo
edites entre imágenes.**

```
Sofia, a 15-year-old teenage girl, warm light-brown skin, brown eyes,
brown hair tied in a messy bun with loose strands framing her face,
wearing green denim gardening overalls over a mustard-yellow hoodie,
white sneakers, chunky headphones resting around her neck,
brown gardening gloves, friendly expressive face
```

### `[RECORTE]` — solo para lo que va con fondo transparente

```
isolated on a solid flat chroma-key green background (#00FF00),
no shadow on the background, no gradient, no other objects, no floor,
the subject must not contain any green or pink tones
```

### Tamaños

| Tipo | Tamaño final | Proporción |
|---|---|---|
| Insectos | 128×128 | 1:1 |
| Armas | 128×128 | 1:1 |
| Sofía (retratos y cuerpo) | 200×320 | ~9:16 |
| Fondos de capítulo y menú | **1080×2340** | **9:19.5** |
| Logo | 800×400 | 2:1 |
| Ícono | 512×512 | 1:1 |

> 📐 **Ojo con los fondos: pedilos 9:19.5, no 9:16.** El juego ahora
> estira el viewport al alto real del celular. Los fondos viejos eran
> 540×960 (9:16) y en un celular alto el motor los agranda y recorta por
> los costados para tapar la pantalla. Generándolos 9:19.5 entran justos
> y no se pierde nada. Generá grande (1080×2340) que después yo los bajo.

---

## 3. Sofía — 8 imágenes

Los retratos son **de la cintura para arriba**, mirando de frente: es el
encuadre que usa la caja de diálogo. Las 5 emociones no son decorativas,
el guion las pide por nombre (`worried` aparece 10 veces, `happy` 7,
`angry` 6, `neutral` 2, `sad` 1).

### 3.1 · Retrato neutral 🥇 *(generá esta PRIMERO, es la referencia)*

**Guardar como:** `assets/sprites/character/sofia_neutral.png` · 200×320

```
Character portrait, waist-up, front view, of [SOFÍA], calm neutral friendly
expression, relaxed mouth, looking straight at the viewer, [ESTILO], [RECORTE]
```

### 3.2 · Feliz

**Guardar como:** `assets/sprites/character/sofia_happy.png` · 200×320

```
Character portrait, waist-up, front view, of [SOFÍA], big genuine smile showing
teeth, eyes crinkled with joy, cheerful energetic posture, one fist raised in
small triumph, [ESTILO], [RECORTE]
```

### 3.3 · Triste

**Guardar como:** `assets/sprites/character/sofia_sad.png` · 200×320

```
Character portrait, waist-up, front view, of [SOFÍA], sad downturned mouth,
droopy sorrowful eyes looking slightly down, slumped shoulders, [ESTILO], [RECORTE]
```

### 3.4 · Enojada

**Guardar como:** `assets/sprites/character/sofia_angry.png` · 200×320

```
Character portrait, waist-up, front view, of [SOFÍA], furrowed angry eyebrows,
gritted teeth, flushed cheeks, determined furious glare, fists clenched,
[ESTILO], [RECORTE]
```

### 3.5 · Preocupada *(la más usada del guion)*

**Guardar como:** `assets/sprites/character/sofia_worried.png` · 200×320

```
Character portrait, waist-up, front view, of [SOFÍA], wide anxious eyes,
eyebrows raised in worry, biting her lower lip, a single sweat drop on her
temple, nervous uneasy expression, [ESTILO], [RECORTE]
```

### 3.6 · Cuerpo entero (la que se ve abajo en la partida)

**Guardar como:** `assets/sprites/character/sofia.png` · 200×320

```
Full body character, front view, of [SOFÍA], standing confidently, holding an
old brown leather shoe raised up in her right hand ready to swat, determined
half-smile, feet planted apart, [ESTILO], [RECORTE]
```

### 3.7 · Saludando (para el menú)

**Guardar como:** `assets/sprites/character/sofia_menu.png` · 200×320

```
Full body character, three-quarter view, of [SOFÍA], waving hello with her right
hand raised, warm welcoming smile, relaxed friendly pose, weight on one leg,
[ESTILO], [RECORTE]
```

### 3.8 · Sorprendida *(opcional pero recomendada)*

Todavía no la usa el guion, pero es la que va a pedir cualquier escena
donde descubra algo. Si la tenés, la meto.

**Guardar como:** `assets/sprites/character/sofia_surprised.png` · 200×320

```
Character portrait, waist-up, front view, of [SOFÍA], eyes wide open in shock,
mouth open in a surprised gasp, eyebrows high, both hands raised near her
cheeks, [ESTILO], [RECORTE]
```

---

## 4. Menú — 3 imágenes

### 4.1 · Fondo del menú

**Guardar como:** `assets/sprites/ui/menu_background.png` · 1080×2340

```
A warm illustrated vegetable garden at golden hour, tall tomato plants heavy with
ripe red tomatoes, wooden fence, sunflowers, terracotta pots, watering can, soft
sun flare and long shadows, dreamy inviting atmosphere, vertical mobile game menu
background, empty clear space in the upper third for a logo and clear space in
the middle for buttons, no characters, no text, [ESTILO]
```

> El "empty clear space" no es capricho: el logo va arriba y los botones
> en el medio. Si el fondo tiene detalle fuerte ahí, no se lee nada.

### 4.2 · Logo del juego

**Guardar como:** `assets/sprites/ui/logo.png` · 800×400 · **transparente**

```
Game logo lettering reading exactly "EL HUERTO DE SOFIA", playful bouncy inflated
3D letters, fresh green and warm yellow gradient with a thick cream outline and
soft drop shadow, a small cute cartoon ant peeking mischievously over the top of
one letter, a couple of tomato leaves sprouting from the corner letters, slight
upward arch, [ESTILO], [RECORTE]
```

> ⚠️ Los modelos de imagen escriben mal el texto seguido. Revisá letra
> por letra que diga **EL HUERTO DE SOFIA** (sin tilde, es más seguro).
> Si sale mal, pedí: `Keep the exact same design, only fix the lettering
> to read "EL HUERTO DE SOFIA".` Si después de 4 o 5 intentos no sale,
> avisame y lo pongo como texto con tipografía, que siempre sale bien.

### 4.3 · Botón cartel de madera

Una sola imagen: la repito y le pongo el texto encima por código, así
todos los botones quedan idénticos y puedo cambiarles el texto sin arte
nuevo.

**Guardar como:** `assets/sprites/ui/button_wood.png` · 512×160 · **transparente**

```
A horizontal wooden sign plank for a game button, warm sanded wood with visible
grain and rounded corners, two small metal screws at the left and right ends,
thin darker wood border, completely empty surface with no text and no carving,
even lighting, front view, [ESTILO], [RECORTE]
```

---

## 5. Insectos comunes · 5 + 5

Los 5 que aparecen como enemigos normales. Todos **de tres cuartos**,
mirando levemente hacia la izquierda, para que se lean bien en 128px.

> 🥇 Generá la **hormiga obrera** primero e iterala hasta que el estilo
> te guste. Esa imagen es la referencia de estilo para los otros 15
> bichos (los 4 de acá + la silueta + los 10 incógnitos).

### 5.1 · Hormiga Obrera 🥇 *(referencia de estilo)*

*vel 100 · vida 1 · 50 pts — el bicho básico, el del tutorial*

**Guardar como:** `assets/sprites/insects/hormiga_obrera.png` · 128×128

```
A cute cartoon worker ant character for a garden-defense mobile game, rich brown
segmented body with glossy highlights, big round expressive eyes, six sturdy legs
all in the same solid brown, thin antennae, three-quarter view facing slightly
left, cheerful but mischievous, [ESTILO], [RECORTE]
```

### 5.2 · Cucaracha Eléctrica

*vel 200 · vida 1 · 75 pts — la rápida*

**Guardar como:** `assets/sprites/insects/cucaracha_electrica.png` · 128×128

```
A cute cartoon cockroach crackling with yellow electric energy, dark reddish-brown
shell with glowing yellow lightning arcs around its body, small sparks, speedy
alert posture, big round eyes, three-quarter view facing slightly left, [ESTILO], [RECORTE]
```

### 5.3 · Escarabajo Blindado

*vel 50 · **vida 3** · 150 pts — el tanque, tiene que verse duro de matar*

**Guardar como:** `assets/sprites/insects/escarabajo_blindado.png` · 128×128

```
A cute but tough cartoon beetle with a thick metallic blue-grey armored shell with
riveted plates, short stubby legs, heavy solid stance, small determined eyes,
scratches on the armor, three-quarter view facing slightly left, [ESTILO], [RECORTE]
```

### 5.4 · Mosca Pesada

*vel 150 · vida 1 · 100 pts*

**Guardar como:** `assets/sprites/insects/mosca_pesada.png` · 128×128

```
A cute chubby cartoon housefly, round heavy dark grey body, translucent iridescent
wings mid-buzz with slight motion blur, big compound red eyes, tiny legs tucked in,
three-quarter view facing slightly left, [ESTILO], [RECORTE]
```

### 5.5 · Grillo Saltarín

*vel 120 · vida 1 · 80 pts*

**Guardar como:** `assets/sprites/insects/grillo_saltarin.png` · 128×128

```
A cute cartoon green cricket caught mid-leap, powerful folded hind legs pushing off,
long antennae trailing back, bright leaf-green body with lighter belly, cheerful
energetic expression, three-quarter view facing slightly left, [ESTILO], [RECORTE]
```

### 5.6 a 5.10 · Ciclos de caminata (5 grillas)

Esto es lo que hace que los bichos **caminen** en vez de deslizarse. Una
sola imagen por insecto: una grilla 2×2 con las 4 poses. Se genera de una
sola vez a propósito — si pedís 4 imágenes sueltas, el bicho te cambia de
forma entre cuadro y cuadro.

**Plantilla** — reemplazá `<INSECTO>` por la descripción del bicho de
arriba (la misma, sin cambiarle nada) y adjuntá su sprite ya aprobado
como referencia:

```
A 2x2 grid sprite sheet, divided into 4 equal square cells by thin black grid lines.
Each cell shows the exact same character: <INSECTO>.
The ONLY difference between the 4 cells is the leg position through one walk cycle.
Identical character design, identical size, identical colors, identical camera angle
in all 4 cells. Do not change the body, only the legs.
[ESTILO], [RECORTE]
```

| # | Insecto | Guardar como | Tamaño |
|---|---|---|---|
| 5.6 | Hormiga Obrera | `assets/sprites/insects/hormiga_obrera_walk.png` | 1024×1024 |
| 5.7 | Cucaracha Eléctrica | `assets/sprites/insects/cucaracha_electrica_walk.png` | 1024×1024 |
| 5.8 | Escarabajo Blindado | `assets/sprites/insects/escarabajo_blindado_walk.png` | 1024×1024 |
| 5.9 | Mosca Pesada | `assets/sprites/insects/mosca_pesada_walk.png` | 1024×1024 |
| 5.10 | Grillo Saltarín | `assets/sprites/insects/grillo_saltarin_walk.png` | 1024×1024 |

> Mandame la grilla entera, sin cortar. Yo la parto en los 4 cuadros y
> los dejo con los nombres que espera el código (`..._walk_0.png` a
> `_3.png`). Para la mosca, en vez de patas moví las **alas**; para el
> grillo, el **salto** (agachado → estirado → en el aire → cayendo).

---

## 6. Incógnitos — 11 imágenes

### 6.1 · Silueta del incógnito

La que se ve antes de descubrirlo. Tiene que ser **una silueta genérica**
que no revele ningún bicho en particular, porque se usa para los 10.

**Guardar como:** `assets/sprites/insects/mystery_bug_silueta.png` · 128×128

```
A mysterious solid dark-purple insect silhouette, generic bug shape with antennae
and six legs, completely filled with a flat dark purple gradient showing no interior
detail, a large glowing white question mark floating on its body, soft purple glow
outline, spooky but cute, three-quarter view, [ESTILO], [RECORTE]
```

### 6.2 a 6.11 · Los 10 revelados

Uno por capítulo, cada vez más raros. Mismo formato que los comunes:
128×128, tres cuartos, `[ESTILO]` + `[RECORTE]`, con la hormiga aprobada
adjunta como referencia de estilo.

| # | Cap. | Nombre | Guardar como | Prompt (el sujeto) |
|---|---|---|---|---|
| 6.2 | 1 | Hormiga Ladrona de Diamantes | `hormiga_ladrona.png` | `A cute cartoon golden ant wearing a black bandit eye mask, clutching a tiny sparkling blue diamond in its front legs, sly grin, small loot sack on its back` |
| 6.3 | 2 | Abejorro Piñata | `abejorro_pinata.png` | `A cute cartoon bumblebee whose body is made of a colorful layered paper piñata, orange and black crepe-paper fringe, tiny paper wings, festive party look, small candies spilling from a seam` |
| 6.4 | 3 | Mantis Cronómetro | `mantis_cronometro.png` | `A cute cartoon praying mantis, teal-green body, with a real analog stopwatch embedded in its chest showing visible clock hands, raised scythe arms, focused intense stare` |
| 6.5 | 4 | Escarabajo Radiactivo | `escarabajo_radiactivo.png` | `A cute cartoon beetle glowing toxic neon green, radioactive trefoil symbol markings on its shell, dripping glowing green ooze, faint green light emanating from seams` |
| 6.6 | 5 | Lombriz Gigante | `lombriz_gigante.png` | `A cute cartoon giant earthworm, thick pink segmented glossy body coiled in an S-shape, small simple friendly face at one end, damp soil crumbs stuck to its skin` |
| 6.7 | 6 | Mutagénesis Voladora | `mutante_volador.png` | `A cute cartoon mutant flying insect with four translucent purple wings, an extra pair of asymmetric eyes on its forehead, slightly lumpy mutated body, unsettling but still cute` |
| 6.8 | 7 | Centella Blindada | `centella_blindada.png` | `A cute cartoon insect encased in riveted blue electric armor plating, arcs of white-blue energy sparking between the plates, glowing seams, heavy powerful stance` |
| 6.9 | 8 | Rayo Insecto | `rayo_insecto.png` | `A cute cartoon insect whose entire body is made of bright yellow lightning bolts and crackling energy, semi-transparent glowing form, motion streaks, extremely fast look` |
| 6.10 | 9 | Coraza Antigua | `coraza_antigua.png` | `A cute cartoon insect wearing weathered ancient bronze beetle-shell armor with green patina, engraved tribal glyphs on the plates, chipped edges, ancient guardian feel` |
| 6.11 | 10 | Reina Primordial | `reina_primordial.png` | `A majestic cartoon insect queen, large regal body in deep purple and gold, ornate crown-like antennae, layered iridescent wings, glowing amber eyes, imposing final-boss presence, commanding pose` |

> Todas van en `assets/sprites/insects/`. Prompt completo =
> `<lo de la última columna>, three-quarter view facing slightly left, [ESTILO], [RECORTE]`.
> La **Reina Primordial** es el jefe final: dale más intentos que al resto.

---

## 7. Armas — 5 imágenes

Son las que se ven bajando y aplastando cuando tocás la pantalla, así
que tienen que leerse **de perfil o tres cuartos**, no de frente.

| # | Arma | Guardar como | Prompt |
|---|---|---|---|
| 7.1 | Zapato Viejo *(el inicial)* | `zapato_viejo.png` | `An old worn brown leather shoe, scuffed toe, worn sole, loose laces, comic video game item icon, three-quarter view` |
| 7.2 | Chancla de Goma | `chancla_goma.png` | `A blue rubber flip-flop sandal, thick foam sole, slightly bent as if mid-swing, comic video game item icon, three-quarter view` |
| 7.3 | Matamoscas Metálico | `matamoscas_metalico.png` | `A metallic fly swatter with a square wire-mesh head and a chrome handle with a red grip, comic video game item icon, three-quarter view` |
| 7.4 | Sartén de Hierro | `sarten_hierro.png` | `A heavy black cast iron frying pan with a thick handle, slight worn shine on the cooking surface, comic video game item icon, three-quarter view` |
| 7.5 | Pala Electrificada | `pala_electrificada.png` | `A metal garden shovel crackling with yellow electricity, arcs of energy along the blade, glowing wooden handle grip, comic video game item icon, three-quarter view` |

Todas en `assets/sprites/weapons/`, 128×128, prompt completo =
`<prompt>, [ESTILO], [RECORTE]`.

---

## 8. Fondos de capítulo — 10 imágenes

Hay que regenerarlos porque cambiamos el estilo: si dejamos los viejos,
Sofía y los bichos nuevos van a desentonar contra ellos.

**Todos: 1080×2340 (9:19.5), sin `[RECORTE]`** (son opacos), **sin
personajes ni texto**, y con la zona de arriba despejada porque ahí va el
HUD.

Prompt completo = `<descripción>, vertical mobile game background, portrait orientation, no characters, no text, clear uncluttered area in the top fifth of the image for a HUD, [ESTILO]`

| # | Cap. | Nombre | Guardar como | Descripción |
|---|---|---|---|---|
| 8.1 | 1 | El Huerto de Tomates | `chapter_1_huerto.png` | `A sunny cheerful vegetable garden with tall tomato plants heavy with ripe red tomatoes, wooden picket fence, sunflowers, marigolds, terracotta pots, watering can, rolling green hills and blue sky with fluffy clouds` |
| 8.2 | 2 | El Invernadero | `chapter_2_invernadero.png` | `The warm humid interior of a glass greenhouse packed with lush tropical plants, condensation on the glass panes, soft god-rays streaming through, hanging vines, wooden potting benches` |
| 8.3 | 3 | La Cueva Subterránea | `chapter_3_cueva.png` | `A mysterious dark underground cave with glowing blue crystals embedded in the rock, stalactites, a shallow reflective pool, roots breaking through the ceiling, cool moody lighting` |
| 8.4 | 4 | El Cultivo Radiactivo | `chapter_4_radiactivo.png` | `A glowing toxic radioactive crop field at dusk, mutated oversized green plants pulsing with light, yellow hazard warning signs, rusted barrels, eerie green fog` |
| 8.5 | 5 | El Pantano | `chapter_5_pantano.png` | `A misty swamp with murky green water, twisted mangrove trees draped in hanging moss, lily pads, fireflies, half-sunken logs, hazy atmospheric light` |
| 8.6 | 6 | Laboratorio Mutante | `chapter_6_lab.png` | `A sci-fi secret laboratory interior, tall glowing specimen tubes with mutated insects floating inside, computer screens with green readouts, stainless steel tables, cold clinical lighting` |
| 8.7 | 7 | La Fábrica | `chapter_7_fabrica.png` | `An industrial factory interior with conveyor belts, thick pipes, giant metal gears, hanging work lamps, steam vents, grimy metal walkways` |
| 8.8 | 8 | Los Túneles | `chapter_8_tuneles.png` | `A fast underground tunnel network, curved concrete walls with yellow and black hazard stripes, receding light strips creating strong perspective, speed motion lines, dust in the air` |
| 8.9 | 9 | El Búnker | `chapter_9_bunker.png` | `A tense military bunker interior, riveted metal walls, red alert lights casting harsh shadows, stacked supply crates, a heavy sealed blast door, warning stencils` |
| 8.10 | 10 | El Núcleo | `chapter_10_nucleo.png` | `An epic alien queen's core chamber, monumental organic architecture, swirling purple and gold energy, a massive glowing egg sac core, floating embers, dramatic final-boss atmosphere` |

Todos en `assets/sprites/backgrounds/`.

---

## 9. Ícono — 1 imagen

El de la pantalla del celular. Tiene que leerse **a 48px**, así que poco
elemento y mucho contraste.

**Guardar como:** `icon.png` (raíz del repo) · 512×512 · sin transparencia

```
A bold cute mobile game app icon: a brown leather shoe coming down to squash a
startled cartoon ant, viewed from a dynamic angle, warm green garden background
with a red tomato accent, thick clean shapes, very high contrast, centered
composition, readable at very small size, no text, [ESTILO]
```

---

## 10. Checklist

Marcá a medida que salgan. Todo lo transparente lo podés mandar con
fondo verde, yo lo recorto.

### Sofía · 8
- [ ] 3.1 `sofia_neutral.png` 🥇 *(primero — es la referencia)*
- [ ] 3.2 `sofia_happy.png`
- [ ] 3.3 `sofia_sad.png`
- [ ] 3.4 `sofia_angry.png`
- [ ] 3.5 `sofia_worried.png`
- [ ] 3.6 `sofia.png` *(cuerpo entero)*
- [ ] 3.7 `sofia_menu.png`
- [ ] 3.8 `sofia_surprised.png` *(opcional)*

### Menú · 3
- [ ] 4.1 `menu_background.png`
- [ ] 4.2 `logo.png` ⚠️ *(revisar que el texto diga bien EL HUERTO DE SOFIA)*
- [ ] 4.3 `button_wood.png`

### Insectos comunes · 5
- [ ] 5.1 `hormiga_obrera.png` 🥇 *(referencia de estilo de los bichos)*
- [ ] 5.2 `cucaracha_electrica.png`
- [ ] 5.3 `escarabajo_blindado.png`
- [ ] 5.4 `mosca_pesada.png`
- [ ] 5.5 `grillo_saltarin.png`

### Caminatas · 5 grillas
- [ ] 5.6 `hormiga_obrera_walk.png`
- [ ] 5.7 `cucaracha_electrica_walk.png`
- [ ] 5.8 `escarabajo_blindado_walk.png`
- [ ] 5.9 `mosca_pesada_walk.png` *(alas, no patas)*
- [ ] 5.10 `grillo_saltarin_walk.png` *(salto)*

### Incógnitos · 11
- [ ] 6.1 `mystery_bug_silueta.png`
- [ ] 6.2 `hormiga_ladrona.png`
- [ ] 6.3 `abejorro_pinata.png`
- [ ] 6.4 `mantis_cronometro.png`
- [ ] 6.5 `escarabajo_radiactivo.png`
- [ ] 6.6 `lombriz_gigante.png`
- [ ] 6.7 `mutante_volador.png`
- [ ] 6.8 `centella_blindada.png`
- [ ] 6.9 `rayo_insecto.png`
- [ ] 6.10 `coraza_antigua.png`
- [ ] 6.11 `reina_primordial.png` *(jefe final, dale más intentos)*

### Armas · 5
- [ ] 7.1 `zapato_viejo.png`
- [ ] 7.2 `chancla_goma.png`
- [ ] 7.3 `matamoscas_metalico.png`
- [ ] 7.4 `sarten_hierro.png`
- [ ] 7.5 `pala_electrificada.png`

### Fondos · 10
- [ ] 8.1 `chapter_1_huerto.png`
- [ ] 8.2 `chapter_2_invernadero.png`
- [ ] 8.3 `chapter_3_cueva.png`
- [ ] 8.4 `chapter_4_radiactivo.png`
- [ ] 8.5 `chapter_5_pantano.png`
- [ ] 8.6 `chapter_6_lab.png`
- [ ] 8.7 `chapter_7_fabrica.png`
- [ ] 8.8 `chapter_8_tuneles.png`
- [ ] 8.9 `chapter_9_bunker.png`
- [ ] 8.10 `chapter_10_nucleo.png`

### Ícono · 1
- [ ] 9 `icon.png`

---

### 💡 Si querés ver algo andando ya

No hace falta que generes las 48 para probar. Con estas **6** ya podés
ver el juego nuevo funcionando de punta a punta:

`sofia_neutral` · `sofia_happy` · `sofia_worried` · `sofia.png` ·
`hormiga_obrera` · `chapter_1_huerto`

Mandámelas y armo un APK con eso, dejando el resto del arte viejo hasta
que las tengas.

---

## 11. Qué hago yo cuando estén

No te preocupes por el lado técnico, mandame los archivos como salgan:

1. **Recorto los fondos verdes** con el flood-fill del repo y los dejo
   con transparencia real.
2. **Parto las grillas 2×2** en los 4 cuadros con los nombres que espera
   el motor, y **conecto las caminatas de los 5 insectos** (hoy solo la
   hormiga tiene ciclo; el resto se desliza).
3. **Reescribo la historia** a la de Sofía: hoy son 27 líneas de diálogo
   y las 26 del protagonista dicen "Don Beto". Cambio guion, nombre del
   que habla y las emociones.
4. **Renombro en el código** `don_beto*` → `sofia*` (retrato, diálogo,
   escena de juego) y borro los assets viejos.
5. **Rehago el menú** con el fondo, el logo y los botones de madera.
6. **Reajusto los fondos** al nuevo 9:19.5.
7. Compilo el APK, lo pruebo corriendo de verdad y te paso el link.

### Lo que sí necesito que decidas vos

- **El nombre del juego.** Le puse *El Huerto de Sofía* en el logo. Si
  querés otro, decímelo **antes** de generar el logo, que es la imagen
  más difícil de corregir.
- **Si Sofía tiene alguien con quien hablar.** Hoy el protagonista habla
  solo. Si querés un segundo personaje (una abuela, un perro, la voz de
  la Reina), decime y le sumo el pedido de arte y las líneas de guion.
