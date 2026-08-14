# 🖼️ Galería — ¡Invasión en el Huerto!

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
<td align="center" width="25%"><img src="docs/capturas/menu.png" width="200"><br><sub><b>Menú principal</b></sub></td>
<td align="center" width="25%"><img src="docs/capturas/mapa.png" width="200"><br><sub><b>Mapa de mundos</b><br>capítulo actual en dorado, el resto con candado</sub></td>
<td align="center" width="25%"><img src="docs/capturas/dialogo.jpg" width="200"><br><sub><b>Diálogo de Don Beto</b><br>retrato real por emoción</sub></td>
<td align="center" width="25%"><img src="docs/capturas/partida.jpg" width="200"><br><sub><b>Partida</b><br>HUD, hormigas y contador</sub></td>
</tr>
</table>

### Efectos de golpe

Capturado cuadro a cuadro desde adentro de Godot. Izquierda: la
salpicadura con sus gotas. Derecha: el zapato bajando, achatándose
contra el suelo en el impacto y levantándose.

<img src="docs/capturas/efectos.png" width="100%">

---

## 👨‍🌾 Don Beto

Cinco retratos reales, uno por emoción. El sistema de diálogo cambia la
textura según la emoción de cada línea del guion (`StoryData`), en vez
de teñir un único sprite como hacía antes.

<table>
<tr>
<td align="center"><img src="assets/sprites/character/don_beto_neutral.png" width="130"><br><sub><b>neutral</b></sub></td>
<td align="center"><img src="assets/sprites/character/don_beto_happy.png" width="130"><br><sub><b>feliz</b></sub></td>
<td align="center"><img src="assets/sprites/character/don_beto_sad.png" width="130"><br><sub><b>triste</b></sub></td>
<td align="center"><img src="assets/sprites/character/don_beto_angry.png" width="130"><br><sub><b>enojado</b></sub></td>
<td align="center"><img src="assets/sprites/character/don_beto_worried.png" width="130"><br><sub><b>preocupado</b></sub></td>
</tr>
</table>

Y el Don Beto de cuerpo entero, el que se ve abajo en la pantalla de
juego:

<img src="assets/sprites/character/don_beto.png" width="120">

---

## 🐜 Ciclo de caminata

Los 4 cuadros de la `hormiga_obrera`, generados como una sola grilla 2×2
para que el bicho no cambie de forma entre cuadros, y después partidos
en post-proceso:

<table>
<tr>
<td align="center"><img src="assets/sprites/insects/hormiga_obrera_walk_0.png" width="110"><br><sub>1</sub></td>
<td align="center"><img src="assets/sprites/insects/hormiga_obrera_walk_1.png" width="110"><br><sub>2</sub></td>
<td align="center"><img src="assets/sprites/insects/hormiga_obrera_walk_2.png" width="110"><br><sub>3</sub></td>
<td align="center"><img src="assets/sprites/insects/hormiga_obrera_walk_3.png" width="110"><br><sub>4</sub></td>
</tr>
</table>

> Es el único insecto con caminata animada por ahora. El resto usa un
> cuadro fijo con balanceo procedural. Para sumarle ciclo a otro, ver
> "Más ciclos de caminata" en el README.

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
<td align="center"><img src="assets/sprites/backgrounds/chapter_1_huerto.png" width="120"><br><sub><b>1.</b> El Huerto<br>de Tomates</sub></td>
<td align="center"><img src="assets/sprites/backgrounds/chapter_2_invernadero.png" width="120"><br><sub><b>2.</b> El Invernadero</sub></td>
<td align="center"><img src="assets/sprites/backgrounds/chapter_3_cueva.png" width="120"><br><sub><b>3.</b> La Cueva<br>Subterránea</sub></td>
<td align="center"><img src="assets/sprites/backgrounds/chapter_4_radiactivo.png" width="120"><br><sub><b>4.</b> El Cultivo<br>Radiactivo</sub></td>
<td align="center"><img src="assets/sprites/backgrounds/chapter_5_pantano.png" width="120"><br><sub><b>5.</b> El Pantano</sub></td>
</tr>
<tr>
<td align="center"><img src="assets/sprites/backgrounds/chapter_6_lab.png" width="120"><br><sub><b>6.</b> Laboratorio<br>Mutante</sub></td>
<td align="center"><img src="assets/sprites/backgrounds/chapter_7_fabrica.png" width="120"><br><sub><b>7.</b> La Fábrica</sub></td>
<td align="center"><img src="assets/sprites/backgrounds/chapter_8_tuneles.png" width="120"><br><sub><b>8.</b> Los Túneles</sub></td>
<td align="center"><img src="assets/sprites/backgrounds/chapter_9_bunker.png" width="120"><br><sub><b>9.</b> El Búnker</sub></td>
<td align="center"><img src="assets/sprites/backgrounds/chapter_10_nucleo.png" width="120"><br><sub><b>10.</b> El Núcleo</sub></td>
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
| Cuadros de caminata | 4 (`hormiga_obrera`) |
| Retratos de Don Beto | 5 emociones + 1 cuerpo entero |
| Armas | 5 |
| Fondos de capítulo | 10 |
| Ícono | 1 |
| **Total de imágenes** | **42** |
| Pistas de música | 11 (Suno) |
| Efectos de sonido | 11 (CC0, Kenney.nl) |
