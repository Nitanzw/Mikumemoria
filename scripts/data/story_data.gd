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

const INTRO := [
	{"speaker": "Sofía", "emotion": "happy", "text": "Un verano entero sola en el huerto de la abuela. Ella se fue tranquila: «Sofi, solo regá y no te compliques»."},
	{"speaker": "Sofía", "emotion": "neutral", "text": "Y me estaba saliendo bien, eh. Los tomates este año están enormes."},
	{"speaker": "Sofía", "emotion": "surprised", "text": "Pará. ¿Desde cuándo las hormigas caminan en fila derecha... y doblan todas en la misma esquina?"},
	{"speaker": "Sofía", "emotion": "worried", "text": "Eso no es una fila. Eso es una formación. Como si alguien les hubiera dado una orden."},
	{"speaker": "Sofía", "emotion": "angry", "text": "¡Y me dejaron el cantero pelado! ¡Tres meses de laburo en una noche!"},
	{"speaker": "Sofía", "emotion": "angry", "text": "Okey. Nadie le hace esto al huerto de mi abuela mientras yo esté a cargo."},
	{"speaker": "Sofía", "emotion": "happy", "text": "No tengo veneno ni experiencia... pero tengo un zapato viejo y muchas ganas. Vamos."},
]

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
const TUTORIAL := [
	{"speaker": "Sofía", "emotion": "happy", "text": "Es simple: tocá la pantalla justo encima de un bicho y le doy con el zapato."},
	{"speaker": "Sofía", "emotion": "worried", "text": "Ojo con errarle. Si tocás al vacío, los que están cerca se dan cuenta, se burlan y salen disparados."},
	{"speaker": "Sofía", "emotion": "happy", "text": "Si encadenás golpes sin fallar hacés combo: más puntos y más monedas al terminar."},
	{"speaker": "Sofía", "emotion": "surprised", "text": "Y cada tanto aparece uno todo oscuro, que no se deja ver. A ese hay que insistirle hasta descubrir qué es."},
	{"speaker": "Sofía", "emotion": "happy", "text": "Con las monedas comprás algo mejor que un zapato. Dale, que el huerto no se defiende solo."},
]

const ENDING := [
	{"speaker": "Sofía", "emotion": "surprised", "text": "Ahí estaba. La Reina Primordial. Más grande que el galpón entero."},
	{"speaker": "Sofía", "emotion": "worried", "text": "Y me miró como si yo fuera la plaga."},
	{"speaker": "Sofía", "emotion": "angry", "text": "¡Esto es por cada planta que me arruinaste!"},
	{"speaker": "Sofía", "emotion": "happy", "text": "Se terminó. El huerto vuelve a ser un huerto."},
	{"speaker": "Sofía", "emotion": "neutral", "text": "Cuando vuelva la abuela le voy a decir que regué todo y que no me compliqué."},
	{"speaker": "Sofía", "emotion": "happy", "text": "No hace falta que sepa el resto. Igual, por las dudas, el zapato me lo guardo cerca."},
]

## Devuelve las líneas de intro del capítulo pedido, o un array vacío si
## ese capítulo no tiene intro definida.
static func get_chapter_intro(chapter: int) -> Array:
	return CHAPTER_INTROS.get(chapter, [])
