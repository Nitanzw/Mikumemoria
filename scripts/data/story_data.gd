class_name StoryData
extends RefCounted

## Guión del juego. Cada línea de diálogo es un Dictionary:
##   {"speaker": String, "emotion": String, "text": String}
## emotion ∈ "neutral" | "happy" | "sad" | "angry" | "worried" |
## "surprised" (ver dialogue_box.gd / sofia_portrait.gd para cómo se
## interpreta cada una — cada emoción tiene su propio retrato).
##
## La trama: Sofía tiene 15 años y se quedó a cargo del huerto de su
## abuela durante el verano. Una plaga de insectos cada vez más raros lo
## invade; siguiendo el rastro descubre que no es una plaga cualquiera,
## sino insectos mutados a propósito por un laboratorio clandestino bajo
## tierra, todos al servicio de la Reina Primordial, que quiere convertir
## el mundo entero en su colonia. Sofía, armada con lo que tenga a mano
## (empezando por un zapato viejo), es lo único que se interpone.

## Gancho de apertura. DOS líneas y a jugar.
##
## Antes eran siete, y encima seguía el tutorial de cinco: doce taps
## antes de ver un insecto. Nadie quiere leer eso para empezar a jugar.
## Todo lo que se sacó de acá no se perdió: está repartido en STORY_BEATS,
## que van cayendo de a poco mientras jugás.
const INTRO := [
	{"speaker": "Sofía", "emotion": "angry", "text": "¡Me están saqueando el huerto! Tres meses de laburo y me dejaron el cantero pelado en una noche."},
	{"speaker": "Sofía", "emotion": "neutral", "text": "No tengo veneno ni experiencia. Tengo un zapato viejo. Dale, ayudame."},
]

## La historia repartida en el juego, por nivel. Cortas a propósito: una
## o dos líneas, para que sean un respiro entre partidas y no un muro de
## texto. Se muestran una sola vez cada una.
const STORY_BEATS := {
	3: [
		{"speaker": "Sofía", "emotion": "neutral", "text": "Che... ¿desde cuándo las hormigas caminan en fila derecha y doblan todas en la misma esquina?"},
	],
	6: [
		{"speaker": "Sofía", "emotion": "worried", "text": "Eso no es una fila. Es una formación. Como si alguien les hubiera dado una orden."},
	],
	12: [
		{"speaker": "Sofía", "emotion": "surprised", "text": "Encontré uno que no es de acá. No es de ningún lado, en realidad."},
		{"speaker": "Sofía", "emotion": "worried", "text": "Tiene marcas. Como si lo hubieran... fabricado."},
	],
	18: [
		{"speaker": "Sofía", "emotion": "neutral", "text": "El rastro va todo para el mismo lado. Al fondo del terreno."},
	],
	25: [
		{"speaker": "Sofía", "emotion": "angry", "text": "La abuela vuelve en dos meses. Para entonces esto tiene que estar limpio."},
		{"speaker": "Sofía", "emotion": "happy", "text": "Y capaz que hasta le sale una cosecha decente."},
	],
	32: [
		{"speaker": "Sofía", "emotion": "surprised", "text": "Escuché algo abajo. Bajo tierra. Un zumbido que no para nunca."},
	],
	45: [
		{"speaker": "Sofía", "emotion": "worried", "text": "Cuantos más mato, más raros vienen. No es una plaga. Alguien los está mandando."},
	],
	60: [
		{"speaker": "Sofía", "emotion": "angry", "text": "Hay una reina. Tiene que haberla. Todo esto responde a algo."},
	],
}

## Mini tutoriales por HITO, no por nivel: se muestran cuando el jugador
## llega a la situación donde el consejo sirve, y una sola vez.
##
## Antes el juego explicaba todo de una en el tutorial inicial y después
## nunca más. Las mecánicas que aparecen mucho más tarde (objetos
## pasivos, poderes activos) no las explicaba nadie: había que adivinar
## que existían.
const TUTORIALS := {
	"tienda": [
		{"speaker": "Sofía", "emotion": "happy", "text": "Ya junté unas cuantas monedas. Con esto me compro algo mejor que el zapato."},
		{"speaker": "Sofía", "emotion": "neutral", "text": "Al terminar un nivel tocá «Tienda», o entrá desde el menú. Las armas pegan más fuerte y llegan más lejos."},
	],
	"objetos": [
		{"speaker": "Sofía", "emotion": "neutral", "text": "En la tienda, abajo de las armas, están los «Objetos»."},
		{"speaker": "Sofía", "emotion": "happy", "text": "Esos no hay que equiparlos ni nada: los comprás y andan solos. Más daño, más monedas, más aguante contra los jefes."},
	],
	"poderes": [
		{"speaker": "Sofía", "emotion": "surprised", "text": "¡Mirá! Ahora tengo un botón abajo a la derecha en la pantalla."},
		{"speaker": "Sofía", "emotion": "neutral", "text": "Eso es el poder que compré. Se toca cuando lo necesitás, pero cada uso me cuesta monedas — fijate el precio en el botón."},
	],
	"jefe": [
		{"speaker": "Sofía", "emotion": "worried", "text": "Este es más grande que los otros. Un jefe."},
		{"speaker": "Sofía", "emotion": "neutral", "text": "Van a aparecer dos barras a los costados: la mía y la de él. Si me vacían la mía, pierdo una vida."},
		{"speaker": "Sofía", "emotion": "happy", "text": "Ojo: cuando avisa que va a atacar, pegale ahí mismo y le cortás el ataque."},
	],
	"combo": [
		{"speaker": "Sofía", "emotion": "happy", "text": "¡Cinco seguidos sin errar! Eso es combo: cuantos más encadenás, más puntos y más monedas al final."},
		{"speaker": "Sofía", "emotion": "worried", "text": "Pero si le pego al aire se corta. Mejor esperar el momento que tirar manotazos."},
	],
	"vidas": [
		{"speaker": "Sofía", "emotion": "sad", "text": "Perdí una vida. Tengo tres, y solo se gastan cuando me gana un jefe."},
		{"speaker": "Sofía", "emotion": "neutral", "text": "Se recuperan solas con el tiempo, aunque cierre el juego. O las pago con monedas desde el menú."},
	],
}

# Se muestra la primera vez que el jugador entra a cada capítulo
# (nivel = (capítulo-1)*100 + 1). Cortito, tipo "gancho" de un capítulo
# a otro — no interrumpe mucho el ritmo del juego.
const CHAPTER_INTROS := {
	1: [
		{"speaker": "Sofía", "emotion": "neutral", "text": "El huerto de tomates. Acá aprendí a plantar con la abuela... y acá los voy a frenar."},
	],
	2: [
		{"speaker": "Sofía", "emotion": "worried", "text": "Se metieron en el invernadero. Ahí están los plantines que la abuela cuida hace años."},
		{"speaker": "Sofía", "emotion": "angry", "text": "Esos no los tocan. Punto."},
	],
	3: [
		{"speaker": "Sofía", "emotion": "surprised", "text": "El rastro baja... ¿a una cueva? ¿Había una cueva en el fondo del terreno y nadie me avisó?"},
		{"speaker": "Sofía", "emotion": "neutral", "text": "Bueno, misterio resuelto de dónde salían los ruidos raros de noche."},
	],
	4: [
		{"speaker": "Sofía", "emotion": "worried", "text": "Un cultivo abandonado, con todo brillando en verde. Los carteles dicen «SuperCosecha S.A.»."},
		{"speaker": "Sofía", "emotion": "angry", "text": "Con razón los bichos están mutados. Esto no fue la naturaleza, esto lo hizo alguien."},
	],
	5: [
		{"speaker": "Sofía", "emotion": "worried", "text": "El pantano. Oscuro, húmedo, y con un zumbido que se siente en los dientes."},
		{"speaker": "Sofía", "emotion": "neutral", "text": "Me pongo los auriculares y sigo. No es negación, es estrategia."},
	],
	6: [
		{"speaker": "Sofía", "emotion": "surprised", "text": "Un laboratorio. Entero, funcionando, abajo del campo de mi abuela."},
		{"speaker": "Sofía", "emotion": "sad", "text": "Los mutaron a propósito. Estos bichos tampoco eligieron ser así."},
	],
	7: [
		{"speaker": "Sofía", "emotion": "surprised", "text": "¿Una fábrica? ¿Les están fabricando armaduras en serie?"},
		{"speaker": "Sofía", "emotion": "worried", "text": "Esto es mucho más grande que mi huerto."},
	],
	8: [
		{"speaker": "Sofía", "emotion": "neutral", "text": "«Túneles Express», dice el cartel. Tienen mejor logística que el correo del pueblo."},
	],
	9: [
		{"speaker": "Sofía", "emotion": "worried", "text": "Un búnker. Están armados, organizados y esperando algo."},
		{"speaker": "Sofía", "emotion": "angry", "text": "Ya llegué hasta acá. No me voy a volver ahora."},
	],
	10: [
		{"speaker": "Sofía", "emotion": "worried", "text": "El Núcleo. Se siente el latido desde la entrada."},
		{"speaker": "Sofía", "emotion": "angry", "text": "Vine por los tomates de mi abuela. Me quedo por todo lo demás."},
	],
}

# Tutorial: se muestra una sola vez, antes del primer nivel jugado.

const ENDING := [
	{"speaker": "Sofía", "emotion": "surprised", "text": "Ahí estaba. La Reina Primordial. Más grande que el galpón entero."},
	{"speaker": "Sofía", "emotion": "worried", "text": "Y me miró como si yo fuera la plaga."},
	{"speaker": "Sofía", "emotion": "angry", "text": "¡Esto es por cada planta que me arruinaste!"},
	{"speaker": "Sofía", "emotion": "happy", "text": "Se terminó. El huerto vuelve a ser un huerto."},
	{"speaker": "Sofía", "emotion": "neutral", "text": "Cuando vuelva la abuela le voy a decir que regué todo y que no me compliqué."},
	{"speaker": "Sofía", "emotion": "happy", "text": "No hace falta que sepa el resto. Igual, por las dudas, el zapato me lo guardo cerca."},
]

## Aviso de escalón de dificultad: sale cada 10 niveles, cuando los
## insectos se ponen más rápidos y aguantan más. Va rotando para que no
## sea siempre el mismo cartel.
const DIFFICULTY_WARNINGS := [
	[
		{"speaker": "Sofía", "emotion": "surprised", "text": "Pará... estos vienen más rápido que los de antes."},
		{"speaker": "Sofía", "emotion": "worried", "text": "Y aguantan más. Con el zapato solo no me alcanza mucho más."},
		{"speaker": "Sofía", "emotion": "neutral", "text": "Mejor paso por la tienda antes del próximo. Algo que pegue más fuerte."},
	],
	[
		{"speaker": "Sofía", "emotion": "worried", "text": "Cada tanda que pasa son más duros. Ya no caen de un golpe."},
		{"speaker": "Sofía", "emotion": "neutral", "text": "Si me estanco acá, el próximo jefe me pasa por arriba."},
		{"speaker": "Sofía", "emotion": "happy", "text": "Con lo que junté puedo mejorar algo. Fuerza, o algún objeto de esos."},
	],
	[
		{"speaker": "Sofía", "emotion": "angry", "text": "¿En serio? Ahora salen de a montones y encima más rápido."},
		{"speaker": "Sofía", "emotion": "neutral", "text": "Esto no se gana a los manotazos. Se gana mejorando."},
		{"speaker": "Sofía", "emotion": "happy", "text": "Tienda, habilidades, objetos. Después seguimos."},
	],
	[
		{"speaker": "Sofía", "emotion": "surprised", "text": "Los de esta tanda ya casi no se inmutan cuando les pego."},
		{"speaker": "Sofía", "emotion": "worried", "text": "Y para los jefes esto se va a poner feo si no me preparo."},
		{"speaker": "Sofía", "emotion": "neutral", "text": "Un botiquín, un delantal... algo que me aguante los golpes."},
	],
]

## Elige el aviso según el escalón, rotando por la lista.
static func get_difficulty_warning(tier: int) -> Array:
	if DIFFICULTY_WARNINGS.is_empty():
		return []
	return DIFFICULTY_WARNINGS[(maxi(tier, 1) - 1) % DIFFICULTY_WARNINGS.size()]

## Beat de historia de ese nivel, o vacío si ese nivel no tiene.
static func get_story_beat(level: int) -> Array:
	return STORY_BEATS.get(level, [])

static func get_tutorial(tutorial_id: String) -> Array:
	return TUTORIALS.get(tutorial_id, [])

## Devuelve las líneas de intro del capítulo pedido, o un array vacío si
## ese capítulo no tiene intro definida.
static func get_chapter_intro(chapter: int) -> Array:
	return CHAPTER_INTROS.get(chapter, [])
