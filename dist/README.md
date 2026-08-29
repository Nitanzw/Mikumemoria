# APK de demo — El Huerto de Sofía

`el_huerto_de_sofia.apk` es un build de Android **release**, firmado
con una keystore de prueba (no es la keystore de producción — para
publicar en Play Store hay que generar una propia y no commitearla).
Versión 0.4.0, ~87MB, arquitectura arm64-v8a solamente.

Este build ya es **completo**: incluye la música de los 10 capítulos,
que los builds anteriores dejaban afuera para no pasarse del límite de
100MB por archivo de GitHub (ver "Sobre el tamaño" más abajo).

**Qué tiene**: el recorrido completo (intro con diálogo → menú → mapa de
mundos → selector de niveles → nivel con tutorial la primera vez →
tienda → árbol de habilidades), con el arte, la música de los 10
capítulos y los SFX reales (no placeholders)
de `assets/` — los SFX son CC0 de Kenney.nl. Orientación **fija en
vertical** (ver más abajo — fue un bug real, ya corregido), HUD con
fuente grande y contorno para que se lea bien, niveles de 30 segundos,
historia narrada por **Sofía** con retratos reales por emoción
(neutral/feliz/triste/enojada/preocupada/sorprendida). Los **5 insectos
comunes** y los **10 incógnitos** tienen ciclo de caminata animado de 4
cuadros, en el mismo estilo pulido que el resto del arte y con el tamaño
emparejado entre cuadros, más el balanceo procedural que llevan todos.

**Jefes cada 5 niveles**: los niveles múltiplo de 5 son pelea de jefe,
con **dos barras de vida** (la del jefe arriba, la de Sofía abajo) y 90
segundos. Hay 10 jefes con habilidades propias: invocar refuerzos que lo
escudan y hay que limpiar antes de poder tocarlo, enterrarse, levantar
escudo, embestir a Sofía, escupir proyectiles (que se revientan
tocándolos), robarte monedas, dividirse en copias falsas, curarse si lo
dejás tranquilo y enfurecerse con poca vida. Cuando el jefe está
protegido su barra se pone azul. Al terminar la vuelta de 10 vuelven a
aparecer más fuertes.

**Los jefes ya no son un insecto grande que va de izquierda a derecha.**
Cada uno tiene su forma de moverse (baja en picada, reaparece lejos,
gira en círculo, se acerca de a poco) y un **patrón de ataque en orden**
que se puede aprender. Al 60% y al 30% de vida cambian de fase: atacan
casi al doble de rápido, invocan más refuerzos y desbloquean una
habilidad nueva. Los refuerzos ahora van al doble de velocidad.

**La dificultad sube cada 10 niveles** y Sofía lo avisa: los bichos van
más rápido, salen más seguido y aguantan más. La vida de los jefes
también escala, porque antes te mejorabas hasta hacer 7 veces más daño y
el jefe seguía igual: la Reina Primordial caía en 10 golpes.

**Objetos en la tienda**: mejoras pasivas que no hay que equipar —
guantes (+daño), botiquín (+corazones en las peleas de jefe), delantal
(bloquea golpes) y repelente (frena a los refuerzos).

**Música nueva y variada**: las 16 pistas se rehicieron **acústicas**
(guitarra, ukelele, marimba, mandolina) en vez del chiptune 8-bit de
antes, que cansaba. Y ahora rotan **por nivel**: antes la pista se elegía
por capítulo, y un capítulo son 100 niveles, así que sonaba siempre la
misma. Las peleas de jefe tienen su propio tema.

**HUD con panel**: los datos de arriba van sobre un panel translúcido.
Antes el texto flotaba sobre el fondo y un insecto que pasaba por atrás
lo tapaba. En las peleas de jefe las **dos barras de vida van verticales
a los costados** — Sofía a la izquierda, el jefe a la derecha — en vez de
comerse el alto de la pantalla.

**Los refuerzos ahora muerden**: antes tocaban a Sofía, hacían un punto
de daño y desaparecían solos; no había nada que reaccionar. Ahora se le
**prenden encima** y siguen mordiendo cada segundo hasta que los
aplastás.

**Tienda con 13 objetos y 4 poderes**. Los pasivos hacen efecto solos
(crítico, suerte, más tiempo, más radio, perdón de combo, corazones
extra). Los **poderes** son botones en la pantalla de juego: cámara
lenta, campo expansivo, tormenta de rayos que pega a todos, y
lanzallamas. Se pagan al desbloquearlos **y cada vez que los usás**, así
no rompen el juego.

**Vidas**: 3 corazones, se pierde uno solo al perder una pelea de jefe.
Regeneran una cada 10 minutos de tiempo real (también con el juego
cerrado) o se recargan pagando 150 monedas tocando los corazones en el
menú.

**Selector de niveles**: entrar a un capítulo abre una grilla con sus 100
niveles, marcando cuáles están completados y cuáles son de jefe (💀).
Se puede **rejugar** cualquiera ya superado sin perder el avance.

**Más variedad de insectos**: 14 tipos, de un tanque de 8 de vida que
camina lentísimo a uno de un solo golpe que cruza la pantalla volando.
Además cada bicho que aparece toma su propia velocidad dentro de un
rango, así dos del mismo tipo no se mueven calcados.

**Feedback del golpe**: al tocar la pantalla se ve el **arma equipada**
(el zapato viejo de arranque, o la que tengas puesta) bajando, aplastando
y levantándose en el punto del tap; al matar un insecto salta una
**salpicadura** con gotas, del color de ese bicho, más un **sonido de
aplastado**. La pantalla ahora **usa todo el alto** del celular — antes
`stretch/aspect` estaba en `keep` y dejaba franjas negras arriba y abajo
en pantallas 19.5:9, y el HUD se cortaba a los costados.

**Lo que NO tiene que entrar al APK**: cualquier carpeta dentro del
proyecto que no se use en runtime igual la importa Godot y viaja
empaquetada. Estaban entrando las **hojas crudas** de los sprite sheets
(7.5MB, insumo de generación) y las **capturas del README** (3.9MB), más
12.5MB de caché huérfana de assets viejos. Un `.gdignore` en cada carpeta
y borrar `.godot/imported` para regenerarla limpia: las texturas pasaron
de 34.8MB a 11.1MB y el APK de 97.6MB a 82MB, con más arte que antes.

**Sobre el tamaño**: antes este APK salía de 134MB y no entraba en
GitHub. No era culpa de los assets: el Android Gradle Plugin, con
`minSdk > 29`, empaqueta los `.so` **sin comprimir** (para poder mapear
las páginas directo desde el APK). Así `libgodot_android.so` ocupaba
67.8MB en vez de los 22.9MB que ocupa deflateado. Se arregla con una
línea en `export_presets.cfg`:

```ini
gradle_build/compress_native_libraries=true
```

Con eso el APK bajó de 134MB a 87MB y ya entra toda la música. (No era
un problema de símbolos de depuración: los `.so` de la plantilla ya
vienen strippeados, `llvm-strip` no les saca ni un byte.)

**Cómo instalar**: pasá el `.apk` al teléfono (o descargalo directo desde
GitHub en el celular) y abrilo — Android va a pedir habilitar "instalar
apps de orígenes desconocidos" para el navegador/gestor de archivos que
uses.

**Sobre el bug de orientación** (arrastrado por varios builds, ya
resuelto de raíz): no era un problema del manifest de Android ni una
política de Samsung — era un **error de tipo en `project.godot`**.

En Godot 3, `display/window/handheld/orientation` era un string
(`"portrait"`); en **Godot 4 es un entero** (enum: `0`=Landscape,
`1`=Portrait, …). El proyecto lo tenía como string, y Godot lo convertía
silenciosamente a **0 = Landscape**. De ahí salía todo:

- Godot escribía `screenOrientation="landscape"` en el manifest generado
  (parecía que "Godot hardcodea landscape", no era eso).
- Parchear el manifest a mano **no arreglaba nada**, porque Godot llama a
  `setRequestedOrientation()` al arrancar con ese mismo 0 y esa llamada
  pisa el manifest. Estaba arreglando el lugar equivocado.
- Las franjas negras a los costados no eran letterboxing de Android:
  eran de Godot, encajando el contenido vertical (540×960) con
  `stretch/aspect="keep"` dentro de una ventana horizontal.

La corrección real es una línea: `window/handheld/orientation=1` (entero,
sin comillas). Está explicado en detalle, con los comandos para
verificar el **tipo** de la setting y el manifest binario del APK, en el
`README.md` de la raíz, sección "Orientación en Android:
`handheld/orientation` es un ENTERO, no un string".

**Dos arreglos de arte** (0.4.0): el overol de Sofía en el menú estaba
**azul denim** mientras que en todo el resto del arte es **verde**; se
corrigió rotando el tono con `tools/recolor_hue.py`, que conserva el
sombreado original de los pliegues (no toca el brillo, solo el tono).
Y en el menú principal la **cabeza de Sofía quedaba tapada** por el
botón "Historia": los botones terminan a los 700px y ella ocupaba de
640 para abajo, así que ahora entra en el hueco libre de abajo y se ve
entera.

**Menús rediseñados** (0.4.0): tienda, árbol de habilidades, mapa de
mundos y selector de niveles ya no usan el tema por defecto de Godot.
Comparten fondo ilustrado, botones de madera y tarjetas con
`scripts/ui/ui_theme.gd`. De paso se arregló que en la tienda y en las
habilidades los botones y los precios quedaban **cortados fuera de la
pantalla**: el `ScrollContainer` permitía scroll horizontal y los textos
largos empujaban la fila más ancha que los 540px del viewport.

**Para exportar vos mismo**: `export_presets.cfg` está completo en el
repo. La keystore no, obviamente — pasala por variables de entorno:

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/ruta/a/tu.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=tu_alias
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=tu_password
godot --headless --export-release "Android" dist/el_huerto_de_sofia.apk
```

Ojo con una trampa: si corrés `godot --import` sobre el proyecto, el
editor entra a `android/build/res/` y le deja un `.import` al lado de
cada `.webp`. Después `aapt2` corta el build con *"The file name must
end with .xml or .png"*. Por eso `android/.gdignore` está en el repo:
le dice al editor que no toque el proyecto de gradle.
