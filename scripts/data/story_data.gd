class_name StoryData
extends RefCounted

## Guión del juego. Cada línea de diálogo es un Dictionary:
##   {"speaker": String, "emotion": String, "text": String}
## emotion ∈ "neutral" | "happy" | "sad" | "angry" | "worried" (ver
## dialogue_box.gd / don_beto_portrait.gd para cómo se interpreta cada una).
##
## La trama: Don Beto es un jubilado que cultiva tomates. Una plaga de
## insectos cada vez más raros invade su huerto; siguiendo el rastro
## descubre que no es una plaga cualquiera, sino insectos mutados a
## propósito por un laboratorio clandestino bajo tierra, todos al
## servicio de la Reina Primordial, que quiere convertir el mundo entero
## en su colonia. Don Beto, armado con lo que tenga a mano (empezando
## por un zapato viejo), es lo único que se interpone.

const INTRO := [
	{"speaker": "Don Beto", "emotion": "happy", "text": "Otro día tranquilo en el huerto... mis tomates están quedando de novela este año."},
	{"speaker": "Don Beto", "emotion": "worried", "text": "Un momento... ¿esas hormigas siempre caminaron tan derechito, en fila, como si tuvieran un plan?"},
	{"speaker": "Don Beto", "emotion": "angry", "text": "¡Me están dejando el cantero pelado! Esto no es una plaga normal, ¡esto es una invasión!"},
	{"speaker": "Don Beto", "emotion": "happy", "text": "Bueno... nadie se mete con mis tomates y sale ileso. ¡A ver qué tiene este zapato viejo!"},
]

# Se muestra la primera vez que el jugador entra a cada capítulo
# (nivel = (capítulo-1)*100 + 1). Cortito, tipo "gancho" de un capítulo
# a otro — no interrumpe mucho el ritmo del juego.
const CHAPTER_INTROS := {
	1: [
		{"speaker": "Don Beto", "emotion": "neutral", "text": "El Huerto de Tomates. Mi hogar, mi orgullo... y ahora, campo de batalla."},
	],
	2: [
		{"speaker": "Don Beto", "emotion": "worried", "text": "Las hormigas huyeron hacia el invernadero. Ahí guardo los plantines más caros... ¡no puedo dejar que lleguen!"},
	],
	3: [
		{"speaker": "Don Beto", "emotion": "worried", "text": "El rastro sigue bajo tierra, hacia una cueva que ni sabía que tenía en el fondo del terreno."},
		{"speaker": "Don Beto", "emotion": "neutral", "text": "Con razón nunca encontré la pala buena."},
	],
	4: [
		{"speaker": "Don Beto", "emotion": "angry", "text": "¿Un cultivo radiactivo abandonado? Acá hubo algo raro de 'SuperCosecha S.A.' hace años... esto explica por qué los bichos brillan."},
	],
	5: [
		{"speaker": "Don Beto", "emotion": "worried", "text": "El pantano. Húmedo, oscuro, y lleno de zumbidos que no me gustan nada."},
	],
	6: [
		{"speaker": "Don Beto", "emotion": "sad", "text": "Un laboratorio. Acá los mutaron a propósito, ¿no? Esto ya no es casualidad."},
		{"speaker": "Don Beto", "emotion": "angry", "text": "Alguien va a tener que darme explicaciones. Con este zapato, si hace falta."},
	],
	7: [
		{"speaker": "Don Beto", "emotion": "worried", "text": "¿Una fábrica de cascos para insectos? Se están organizando en serio. Esto es más grande de lo que pensé."},
	],
	8: [
		{"speaker": "Don Beto", "emotion": "worried", "text": "Túneles express, dice el cartel. Hasta tienen mejor logística que el almacén del pueblo."},
	],
	9: [
		{"speaker": "Don Beto", "emotion": "angry", "text": "Un búnker militar. Están armados y organizados. Falta poco para llegar al fondo de todo esto."},
	],
	10: [
		{"speaker": "Don Beto", "emotion": "worried", "text": "El Núcleo. Puedo sentir que hay algo — o alguien — muy grande esperando ahí adentro."},
		{"speaker": "Don Beto", "emotion": "angry", "text": "Vengo por mis tomates. No me voy a ir sin una explicación... y sin mi huerto en paz."},
	],
}

const TUTORIAL := [
	{"speaker": "Don Beto", "emotion": "happy", "text": "Mirá, así de fácil: tocá la pantalla donde veas un bicho para darle con el zapato."},
	{"speaker": "Don Beto", "emotion": "worried", "text": "Ojo, si tocás donde no hay ninguno, los bichos cercanos se burlan y salen corriendo más rápido. ¡No fallés de más!"},
	{"speaker": "Don Beto", "emotion": "happy", "text": "Golpeá varios seguidos sin fallar y vas a hacer combo — más puntos y más monedas al final del nivel."},
	{"speaker": "Don Beto", "emotion": "worried", "text": "De vez en cuando va a aparecer un bicho misterioso, todo oscuro. Ese hay que golpearlo varias veces para revelar quién es."},
	{"speaker": "Don Beto", "emotion": "happy", "text": "Con las monedas comprá armas mejores y mejorá tus habilidades. ¡Dale, el huerto no se defiende solo!"},
]

# Se muestra al completar el nivel 1000 (Reina Primordial derrotada).
const ENDING := [
	{"speaker": "Don Beto", "emotion": "worried", "text": "Ahí estaba. La Reina Primordial. Tan grande como mi galpón."},
	{"speaker": "Don Beto", "emotion": "angry", "text": "¡Esto es por cada tomate que me arruinaste!"},
	{"speaker": "Don Beto", "emotion": "happy", "text": "¡Se acabó! El huerto vuelve a ser mío... aunque después de esto, no sé si voy a poder mirar una hormiga igual."},
	{"speaker": "Don Beto", "emotion": "happy", "text": "Ahora sí. A plantar tomates en paz. Bueno... hasta la próxima plaga."},
]

static func get_chapter_intro(chapter: int) -> Array:
	return CHAPTER_INTROS.get(chapter, [])
