# Publicidad y compras: qué está hecho y qué falta

La versión gratis tiene **toda la lógica del negocio hecha y andando**:
cuándo corresponde un anuncio, qué paga cada uno, el regalo diario con
su racha, el tope de anuncios por día, qué hace cada compra y cómo se
guarda. Lo que está **simulado** son las dos puntas que necesitan una
cuenta de Google que yo no puedo crear:

| Pieza | Estado | Archivo |
|---|---|---|
| Reglas de negocio, premios, racha, tope diario | **Real** | `scripts/autoload/store.gd` |
| Catálogo, precios, qué incluye cada compra | **Real** | `scripts/data/iap_data.gd` |
| Mostrar el anuncio | Simulado | `scripts/services/ads_service.gd` |
| Cobrar la compra | Simulado | `scripts/services/billing_service.gd` |

El simulado no es un cartel vacío: se ve el anuncio con su cuenta
regresiva y la compra con su confirmación y su precio, así se puede
probar el circuito entero en el celular antes de tener las cuentas.

## Para enchufar AdMob de verdad

Los números **ya están dados de alta y guardados** en
`scripts/data/ads_config.gd`, con un interruptor `USAR_PRUEBA` arriba de
todo:

| | ID |
|---|---|
| App ID | `ca-app-pub-2714414375957960~7276707362` |
| Banner (franja de abajo) | `ca-app-pub-2714414375957960/6949404308` |
| Intersticial (cada 3 niveles) | `ca-app-pub-2714414375957960/4711816877` |
| Recompensado (los 5 premios) | `ca-app-pub-2714414375957960/5444750948` |

Mientras `USAR_PRUEBA` esté en `true`, el juego usa los de prueba de
Google y estos ni se tocan. **Se pone en `false` una sola vez, en el
build que se sube a producción.** Tocar tus propios anuncios de
producción, aunque sea probando, es motivo de suspensión de la cuenta y
de que no te paguen lo acumulado.

Pasos que faltan:

1. Agregar el plugin de Godot para Android de AdMob (un `.aar` más su
   `.gdap` en `android/plugins/`) y prenderlo en el preset de exportación.
   Tiene que ser uno que soporte Godot 4.
2. El App ID va en el `AndroidManifest`, como `meta-data` de
   `com.google.android.gms.ads.APPLICATION_ID`. Casi todos los plugins lo
   resuelven solos con un campo en el `.gdap`; si no, hay que agregarlo a
   mano al proyecto de gradle en `android/build/`.
3. En `ads_service.gd` reemplazar el cuerpo de `mostrar_con_premio()` y
   `mostrar_entre_niveles()` por las llamadas del plugin, y en
   `banner_ad.gd` el cuerpo de `mostrar()`. **Las firmas no cambian**: el
   juego sigue llamando igual y el espacio del banner ya está reservado
   en todas las pantallas.
4. El premio se entrega en el callback del evento "el usuario ganó la
   recompensa" — **nunca** al abrir el anuncio, o se puede cobrar sin
   verlo.
5. Para confirmar que cada anuncio sale donde corresponde, el juego ya
   escribe en el log de Android una línea por cada uno:
   `[Ads] recompensado -> ca-app-pub-… (PRUEBA)`.

## Para enchufar Google Play Billing

1. En Play Console, dar de alta los productos con **el mismo id** que
   usa `IapData`: `sin_anuncios`, `arma_legendaria`, `reloj_abuela`,
   `pack_fundador` (no consumibles) y `monedas_chico`, `monedas_medio`,
   `monedas_grande` (consumibles).
2. Agregar el plugin de Godot de Play Billing.
3. En `billing_service.gd`, reemplazar el cartel de confirmación por el
   flujo del plugin, y llamar a `Store.grant(id)` **sólo** cuando la
   compra vuelve confirmada por Google.
4. Los consumibles hay que consumirlos después de entregarlos, si no no
   se pueden volver a comprar.
5. **Restaurar compras al abrir el juego**: consultar las compras del
   usuario y llamar a `Store.grant()` por cada una. Sin esto, el que
   reinstala pierde lo que pagó, y eso además de estar mal termina en
   reembolsos y en una reseña de una estrella.
6. Mostrar el precio que devuelve Google, no el de `IapData`: el precio
   real cambia por país y por promoción.

## ⚠️ Al meter el plugin de AdMob, hay que volver a Play Console

Esto es lo más fácil de olvidar y lo que más caro sale: **declarar "no
recopila datos" teniendo AdMob adentro es de las causas más comunes de
que Google baje la app**, sin aviso previo.

Mientras el juego no tenga el SDK de anuncios, la declaración de
**Seguridad de los datos** en "No recopila ni comparte datos" es
correcta: el juego no manda nada a ningún lado. En el momento en que se
agrega el plugin, deja de serlo.

Entonces, junto con el `.aar`, en Play Console → Política → Contenido de
la app → **Seguridad de los datos**, hay que pasar la respuesta a **Sí**
y declarar:

| Tipo de dato | Recopilado | Compartido | Necesario | Para qué |
|---|---|---|---|---|
| ID del dispositivo o de otro tipo | Sí | Sí | Necesaria | Publicidad + Estadísticas |
| Ubicación aproximada | Sí | Sí | Necesaria | Publicidad |
| Interacciones con la app | Sí | Sí | Necesaria | Publicidad + Estadísticas |

Ninguno se procesa de forma efímera (Google registra las solicitudes de
anuncios de su lado).

**No** declarar registros de fallos ni diagnósticos: el proyecto no tiene
ningún SDK de analítica ni de reporte de errores, está verificado. Si la
página de ayuda de AdMob dice que esa versión del SDK sí los reporta,
ahí sí hay que sumarlos — esa página es la que manda.

Y declarar de más tampoco es gratis: la lista se le muestra al jugador en
la ficha, y cuanto más larga, más invasivo parece el juego.

## Antes de publicar la versión gratis

- Política de privacidad publicada y declarada en Play (**obligatoria**,
  incluso sin recolectar datos propios: AdMob sí recolecta).
- Formulario de Seguridad de los datos completo, declarando lo que
  recolecta el SDK de anuncios.
- Consentimiento de privacidad para Europa (el formulario de mensajes de
  privacidad del propio AdMob lo resuelve).
- Si la app apunta a chicos, hay reglas extra de contenido de anuncios.
