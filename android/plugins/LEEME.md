# Acá van los plugins de Android

Vacía a propósito. Godot busca en esta carpeta los plugins de Android:
cada uno son **dos archivos**, un `.aar` (el código Java/Kotlin ya
compilado) y un `.gdap` al lado (un archivo de texto que le dice a Godot
cómo cargarlo). Al ponerlos acá, aparecen como una casilla para tildar en
el preset de exportación de Android.

Faltan dos, y son los únicos que separan al juego de facturar de verdad:

## 1. AdMob

Convierte los carteles simulados en anuncios reales. Tiene que ser un
plugin que soporte **Godot 4** (varios de los que se encuentran son de
Godot 3 y no cargan).

Una vez puesto:

- El **App ID** (`ca-app-pub-2714414375957960~7276707362`) va donde lo
  pida el `.gdap`, o a mano en el `AndroidManifest` como `meta-data` de
  `com.google.android.gms.ads.APPLICATION_ID`.
- Los tres ad units ya están en `scripts/data/ads_config.gd`.
- Hay que reemplazar el cuerpo de tres funciones y nada más:
  `AdsService.mostrar_con_premio()`, `AdsService.mostrar_entre_niveles()`
  y `BannerAd.mostrar()`. El espacio del banner **ya está reservado** en
  todas las pantallas.

## 2. Google Play Billing

Para las compras. Ídem: tiene que soportar Godot 4 y una versión de la
Billing Library que Play siga aceptando.

Una vez puesto, se reemplaza el cuerpo de `BillingService.comprar()` y se
enganchan dos cosas más, que están explicadas con el detalle de por qué
en `scripts/services/LEEME.md`:

- entregar en el callback de "compras actualizadas", **nunca** en el
  botón;
- consultar las compras al abrir el juego, para restaurar.

## Ojo con esta carpeta y el editor

Si algún día corrés `godot --import` sobre el proyecto, el editor entra a
`android/build/` y le deja un `.import` al lado de cada `.webp`, y
después `aapt2` corta el build. Por eso `android/.gdignore` está en el
repo. Si agregás archivos acá y algo se rompe al exportar, revisá que ese
`.gdignore` siga estando.
