# 🖼️ Galería — El Huerto de Sofía

Todo el arte y las capturas del juego en un solo lugar. Las imágenes son
los archivos reales del repo (no copias), así que si regenerás un asset
esta página se actualiza sola.

Cómo se generó cada cosa está en el [`README.md`](README.md); acá es
puro mirar.

---

## 📱 El juego andando

Capturas reales del build actual, corriendo a 540×1170 (la proporción
19.5:9 de un celular alto).

<table>
<tr>
<td align="center" width="33%"><img src="docs/capturas/menu.jpg" width="230"><br><sub><b>Menú principal</b><br>fondo ilustrado, logo y carteles de madera</sub></td>
<td align="center" width="33%"><img src="docs/capturas/dialogo.jpg" width="230"><br><sub><b>Diálogo de Sofía</b><br>un retrato distinto por emoción</sub></td>
<td align="center" width="33%"><img src="docs/capturas/partida.jpg" width="230"><br><sub><b>Partida</b><br>HUD, insectos y Sofía abajo</sub></td>
</tr>
</table>

### Los menús

Las cuatro pantallas de menú comparten fondo ilustrado, carteles de
madera y tarjetas, todo desde `scripts/ui/ui_theme.gd`.

<table>
<tr>
<td align="center" width="25%"><img src="docs/capturas/tienda.jpg" width="180"><br><sub><b>Tienda</b><br>tarjeta por arma, con ícono y precio</sub></td>
<td align="center" width="25%"><img src="docs/capturas/habilidades.jpg" width="180"><br><sub><b>Habilidades</b><br>5 casilleros por rama en vez de una barra</sub></td>
<td align="center" width="25%"><img src="docs/capturas/mapa.jpg" width="180"><br><sub><b>Mapa de mundos</b><br>pergamino con los 10 capítulos en zigzag</sub></td>
<td align="center" width="25%"><img src="docs/capturas/niveles.jpg" width="180"><br><sub><b>Selector de niveles</b><br>💀 son jefes; se puede rejugar</sub></td>
</tr>
</table>

### Efectos de golpe

Capturado cuadro a cuadro desde adentro de Godot. Izquierda: la
salpicadura con sus gotas. Derecha: el zapato bajando, achatándose
contra el suelo en el impacto y levantándose.

<img src="docs/capturas/efectos.png" width="100%">

---

## 👧 Sofía

Seis retratos, uno por emoción. El sistema de diálogo cambia la textura
según la emoción de cada línea del guion (`StoryData`). Están recortados
a busto para que la cara se lea en la caja de diálogo, que es chica.

<img src="docs/capturas/sofia_emociones.png" width="100%">

<sub>neutral · feliz · triste · enojada · preocupada · sorprendida</sub>

Y las dos de cuerpo entero: la de la partida (con el zapato en alto) y
la del menú (saludando).

<table>
<tr>
<td align="center"><img src="assets/sprites/character/sofia.png" width="150"><br><sub><b>en la partida</b></sub></td>
<td align="center"><img src="assets/sprites/character/sofia_menu.png" width="150"><br><sub><b>en el menú</b></sub></td>
</tr>
</table>

---

## 🎬 Interfaz del menú

<table>
<tr>
<td align="center"><img src="assets/sprites/ui/logo.png" width="300"><br><sub><b>Logo</b></sub></td>
<td align="center"><img src="assets/sprites/ui/button_wood.png" width="240"><br><sub><b>Cartel de madera</b><br>una sola imagen, 9-slice, con el texto por código</sub></td>
</tr>
<tr>
<td align="center"><img src="assets/sprites/ui/panel_card.png" width="240"><br><sub><b>Tarjeta</b><br>fila de la tienda y del árbol de habilidades</sub></td>
<td align="center"><img src="assets/sprites/ui/coin.png" width="90"><br><sub><b>Moneda</b><br>reemplaza el emoji 🪙 del contador</sub></td>
</tr>
</table>

Las dos imágenes de 9-slice están **recortadas al bbox de su parte
opaca**. Salieron del generador con muchísimo margen transparente
alrededor (el cartel era 512×160 con 468×96 de madera real); sin
recortar, el 9-slice estira ese vacío y la madera queda corrida
respecto del texto que va encima.

---

## 🐜 Ciclo de caminata

Los **5 insectos comunes** tienen ciclo de caminata de 4 cuadros. Cada
uno se generó como una sola grilla 2×2 (así el bicho no cambia de forma
entre cuadros) y después se partió con `tools/split_sheet.py`. Acá el de
la `hormiga_obrera`:

<table>
<tr>
<td align="center"><img src="assets/sprites/insects/hormiga_obrera_walk_0.png" width="110"><br><sub>1</sub></td>
<td align="center"><img src="assets/sprites/insects/hormiga_obrera_walk_1.png" width="110"><br><sub>2</sub></td>
<td align="center"><img src="assets/sprites/insects/hormiga_obrera_walk_2.png" width="110"><br><sub>3</sub></td>
<td align="center"><img src="assets/sprites/insects/hormiga_obrera_walk_3.png" width="110"><br><sub>4</sub></td>
</tr>
</table>

> Los 10 insectos incógnito todavía usan un cuadro fijo con balanceo
> procedural. Para sumarle ciclo a alguno: generá la grilla 2×2 y pasala
> por `tools/chroma_key.py` y `tools/split_sheet.py`.

---

## 🐛 Insectos

### Comunes — los que aparecen como enemigos normales

<table>
<tr>
<td align="center"><img src="assets/sprites/insects/hormiga_obrera.png" width="110"><br><sub><b>Hormiga Obrera</b><br>vel 100 · vida 1 · 50 pts</sub></td>
<td align="center"><img src="assets/sprites/insects/cucaracha_electrica.png" width="110"><br><sub><b>Cucaracha Eléctrica</b><br>vel 200 · vida 1 · 75 pts</sub></td>
<td align="center"><img src="assets/sprites/insects/escarabajo_blindado.png" width="110"><br><sub><b>Escarabajo Blindado</b><br>vel 50 · vida 3 · 150 pts</sub></td>
<td align="center"><img src="assets/sprites/insects/mosca_pesada.png" width="110"><br><sub><b>Mosca Pesada</b><br>vel 150 · vida 1 · 100 pts</sub></td>
<td align="center"><img src="assets/sprites/insects/grillo_saltarin.png" width="110"><br><sub><b>Grillo Saltarín</b><br>vel 120 · vida 1 · 80 pts</sub></td>
</tr>
</table>

### El incógnito

Aparece como silueta y se va revelando a medida que le pegás. Al llegar
a 100% se descubre cuál era y se suma a la colección.

<img src="assets/sprites/insects/mystery_bug_silueta.png" width="110">

### Incógnitos revelados — uno por capítulo

<table>
<tr>
<td align="center"><img src="assets/sprites/insects/hormiga_ladrona.png" width="105"><br><sub><b>1.</b> Hormiga Ladrona<br>de Diamantes</sub></td>
<td align="center"><img src="assets/sprites/insects/abejorro_pinata.png" width="105"><br><sub><b>2.</b> Abejorro Piñata</sub></td>
<td align="center"><img src="assets/sprites/insects/mantis_cronometro.png" width="105"><br><sub><b>3.</b> Mantis Cronómetro</sub></td>
<td align="center"><img src="assets/sprites/insects/escarabajo_radiactivo.png" width="105"><br><sub><b>4.</b> Escarabajo<br>Radiactivo</sub></td>
<td align="center"><img src="assets/sprites/insects/lombriz_gigante.png" width="105"><br><sub><b>5.</b> Lombriz Gigante</sub></td>
</tr>
<tr>
<td align="center"><img src="assets/sprites/insects/mutante_volador.png" width="105"><br><sub><b>6.</b> Mutagénesis<br>Voladora</sub></td>
<td align="center"><img src="assets/sprites/insects/centella_blindada.png" width="105"><br><sub><b>7.</b> Centella Blindada</sub></td>
<td align="center"><img src="assets/sprites/insects/rayo_insecto.png" width="105"><br><sub><b>8.</b> Rayo Insecto</sub></td>
<td align="center"><img src="assets/sprites/insects/coraza_antigua.png" width="105"><br><sub><b>9.</b> Coraza Antigua</sub></td>
<td align="center"><img src="assets/sprites/insects/reina_primordial.png" width="105"><br><sub><b>10.</b> Reina Primordial<br><i>jefe final</i></sub></td>
</tr>
</table>

---

## 🥿 Armas

En orden de desbloqueo. El arma equipada es la que se ve bajando cuando
tocás la pantalla, y su tamaño en pantalla escala con su radio.

<table>
<tr>
<td align="center"><img src="assets/sprites/weapons/zapato_viejo.png" width="110"><br><sub><b>Zapato Viejo</b><br>daño 1 · radio 50<br><i>gratis</i></sub></td>
<td align="center"><img src="assets/sprites/weapons/chancla_goma.png" width="110"><br><sub><b>Chancla de Goma</b><br>daño 1 · radio 60<br>200 🪙</sub></td>
<td align="center"><img src="assets/sprites/weapons/matamoscas_metalico.png" width="110"><br><sub><b>Matamoscas Metálico</b><br>daño 1 · radio 80<br>500 🪙</sub></td>
<td align="center"><img src="assets/sprites/weapons/sarten_hierro.png" width="110"><br><sub><b>Sartén de Hierro</b><br>daño 2 · radio 70<br>900 🪙</sub></td>
<td align="center"><img src="assets/sprites/weapons/pala_electrificada.png" width="110"><br><sub><b>Pala Electrificada</b><br>daño 2 · radio 90<br>1500 🪙</sub></td>
</tr>
</table>

---

## 🌄 Fondos de capítulo

Los 10 están incluidos en el APK, aunque la demo solo llega jugable
hasta el capítulo 1.

<table>
<tr>
<td align="center"><img src="assets/sprites/backgrounds/chapter_1_huerto.jpg" width="120"><br><sub><b>1.</b> El Huerto<br>de Tomates</sub></td>
<td align="center"><img src="assets/sprites/backgrounds/chapter_2_invernadero.jpg" width="120"><br><sub><b>2.</b> El Invernadero</sub></td>
<td align="center"><img src="assets/sprites/backgrounds/chapter_3_cueva.jpg" width="120"><br><sub><b>3.</b> La Cueva<br>Subterránea</sub></td>
<td align="center"><img src="assets/sprites/backgrounds/chapter_4_radiactivo.jpg" width="120"><br><sub><b>4.</b> El Cultivo<br>Radiactivo</sub></td>
<td align="center"><img src="assets/sprites/backgrounds/chapter_5_pantano.jpg" width="120"><br><sub><b>5.</b> El Pantano</sub></td>
</tr>
<tr>
<td align="center"><img src="assets/sprites/backgrounds/chapter_6_lab.jpg" width="120"><br><sub><b>6.</b> Laboratorio<br>Mutante</sub></td>
<td align="center"><img src="assets/sprites/backgrounds/chapter_7_fabrica.jpg" width="120"><br><sub><b>7.</b> La Fábrica</sub></td>
<td align="center"><img src="assets/sprites/backgrounds/chapter_8_tuneles.jpg" width="120"><br><sub><b>8.</b> Los Túneles</sub></td>
<td align="center"><img src="assets/sprites/backgrounds/chapter_9_bunker.jpg" width="120"><br><sub><b>9.</b> El Búnker</sub></td>
<td align="center"><img src="assets/sprites/backgrounds/chapter_10_nucleo.jpg" width="120"><br><sub><b>10.</b> El Núcleo</sub></td>
</tr>
</table>

---

## 📦 Ícono de la app

<img src="icon.png" width="130">

---

## Resumen

| | Cantidad |
|---|---|
| Insectos | 16 (5 comunes + 1 silueta + 10 incógnitos) |
| Cuadros de caminata | 20 (4 × los 5 insectos comunes) |
| Retratos de Sofía | 6 emociones + 2 de cuerpo entero |
| Armas | 5 |
| Fondos de capítulo | 10 |
| Ícono | 1 |
| Interfaz del menú | 3 (fondo, logo, cartel) |
| **Total de imágenes** | **68** |
| Pistas de música | 11 (Suno) |
| Efectos de sonido | 11 (CC0, Kenney.nl) |
