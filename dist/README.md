# APK de demo — El Huerto de Sofía

`el_huerto_de_sofia.apk` es un build de Android **release**, firmado
con una keystore de prueba (no es la keystore de producción — para
publicar en Play Store hay que generar una propia y no commitearla).
Versión 0.17.0 (versionCode 23), ~73MB, arquitectura arm64-v8a solamente.

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

**A los jefes se les pueden cortar los ataques**: cuando se preparan
para embestir, invocar o escupir, pegarles cancela el ataque y los deja
aturdidos. Y atacan bastante más seguido que antes, que se pasaban la
pelea paseando.

**Tienda tipo market**: por defecto es una grilla de íconos; tocás uno y
se abre su ficha. Con el botón de arriba se pasa a la vista de lista
detallada. Y desde el resumen de un nivel se entra derecho a la tienda,
sin volver al menú.

**Resumen de nivel rediseñado**: era un panel gris con tres líneas de
texto. Ahora arriba va un cartel dorado con "¡COMBO PERFECTO!" y la racha
en grande (solo si llegaste a x5 o más), y debajo una placa de madera con
un moño verde montado sobre el borde con el título en mayúscula. Adentro,
cuatro tiras con ícono: la medalla del nivel (Huerto Perfecto, Buena Mano
o Jardinero, según la racha), puntos, racha y recompensa. Abajo, Menú y
Tienda en madera y **Seguir en verde**, que es el que uno busca sin leer.
El fondo se ve a través del velo, así la pantalla se siente parte del
juego, y las filas van dentro de un rebaje oscuro en vez de flotar sobre
la madera. **Entra animada**: el panel rebota, las filas aparecen de a
una y el puntaje y las monedas suben desde cero. La derrota reusa la
misma placa y se encoge sola.

**Sofía ya no se dibuja durante la partida**: aparecía abajo del todo,
cortada por el borde y sin animación. Los ataques del jefe siguen
apuntando al mismo lugar.

**Resumen de nivel con marco verde**: el panel pasa a un marco verde con
guardas de hojas y labio dorado, con las filas en un rebaje oscuro
adentro. Los tres botones llevan ícono (pergamino, canasta y doble
flecha) y la racha va sobre una placa dorada.

**Tienda con barras de nivel**: cada casillero muestra el ícono, el nivel
sobre 10, el precio con la moneda y una barra de progreso que se pone
dorada al completarse. Lo bloqueado va en gris con candado, y las
secciones se separan con filetes dorados.

**Progresión para los 1000 niveles**: antes se compraba todo antes del
nivel 40 y después no quedaba nada. Ahora cada arma tiene **10 niveles de
mejora** y hay que llevarla al 10 para poder comprar la siguiente. Lo
mismo con los objetos, en dos cadenas: los pasivos (guantes → botiquín →
lupa → frasco → repelente → reloj de arena → trébol → delantal → botas) y
los poderes (reloj de bolsillo → campo → tormenta → lanzallamas). Son
**180 compras** en total, un hito cada 25 o 30 niveles. Simulado de punta
a punta: el último se completa en el nivel 970 de 1000.

El daño del arma va de 1 (Zapato nivel 1) a 107 (Pala nivel 10), así que
mejorar se nota. Y el árbol de habilidades pasa a sumar daño plano en vez
de multiplicarlo: multiplicando, sus 4.800 monedas regalaban +107 de daño
y dejaban sin sentido las 50 mejoras de arma.

**Los insectos se ponen duros y las mejoras hacen falta**: antes una
hormiga tenía 1 de vida hasta el nivel 29 — un toque, siempre. Ahora suman
+2 de vida cada 10 niveles (hormiga: 3 en el nivel 10, 5 en el 20, 11 en
el 50, 21 en el 100). Y las armas, que hacían 1/1/1/2/2 de daño (el
Matamoscas de 900 monedas pegaba igual que el Zapato gratis), ahora hacen
**1/2/3/5/8**. Si comprás, el juego se mantiene ágil: 1 toque por bicho
hasta el nivel 10, 2 desde el 20. Si no comprás, esa misma hormiga te
lleva 6 toques en el nivel 20 y 12 en el 50.

La vida de los jefes se multiplicó para compensar el daño nuevo, si no se
derretían: la Reina Primordial pasaba de 65 golpes a 16.

**Precios rebalanceados (segunda pasada)**: la primera no alcanzó. Las
monedas venían sobre todo de **matar bichos**, no del fin de nivel, y eso
no lo había tocado. Bajaron a ~1/5. La Pala pasa de comprarse en el nivel
14 a en el 35.

**Precios rebalanceados**: un tester llegó al nivel 7 con plata para el
arma más cara. El culpable era el bonus de combo, que no tenía tope y
creció solo cuando subí la cantidad de bichos en pantalla. Ahora el bonus
está topeado y las armas salen el doble. Con los números viejos la Sartén
se compraba en el nivel 7 y la Pala en el 11; ahora en el 22 y el 35.

**La tienda scrollea bien**: antes se pegaba o iba para un solo lado,
porque los botones de las tarjetas se quedaban con el arrastre. Aplicado
también al árbol de habilidades, al selector de niveles y al mapa.

**La historia ya no te frena al empezar**: la apertura son dos líneas y
arrancás. El resto se cuenta de a poco mientras jugás, en niveles
sueltos. Y los **mini tutoriales salen cuando hacen falta**: cómo usar la
tienda cuando te alcanza para la primera arma, qué son los objetos
pasivos cuando podés comprar uno, cómo funciona el botón de poder apenas
comprás uno, y cómo va la pelea de jefe justo antes del primero.

**Más insectos y más visibles**: antes se quedaban pegados a los bordes
(nacían fuera de la pantalla y cambiaban de rumbo antes de entrar, así
que se volvían). Ahora el rumbo tira hacia adentro, no se meten detrás
del panel del HUD, y desde el nivel 1 hay bastantes más.

**HUD nuevo**: la barra de arriba pasó de un panel plano de 215px a un
marco de 132px con banda para el nombre del nivel, medallón central para
el reloj y placas con emblema para puntos y monedas. Y **nada puede
meterse debajo**: ni insectos ni jefes, que antes quedaban atrapados ahí
donde no se los podía golpear.

**Vidas en la pelea de jefe**: las dos barras pasan a un panel abajo de
la pantalla, con el número exacto (Sofía 1.000, el jefe entre 2.000 y
6.800). Eso permite **subir la vida de Sofía en la tienda** y que los
jefes peguen más fuerte a medida que sube la dificultad — antes el daño
del jefe era fijo y las peleas tardías dejaban de doler.

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
