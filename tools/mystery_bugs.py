"""Los 90 insectos incógnita que faltaban (índices 11 a 100).

El juego pide el incógnito número `nivel/10`, o sea hasta el 100, pero
MYSTERY_DATABASE solo tenía diez: del nivel 110 en adelante el bicho
aparecía, no encontraba sus datos y se autodestruía sin avisar.

Van agrupados de a diez por capítulo, siguiendo su tema: el incógnito
número N sale en el nivel N*10, y el capítulo es (N*10-1)/100+1. Así el
del pantano aparece en el pantano.

El arte se genera de a una hoja por capítulo (grilla 5x2), y no de a un
bicho por llamada, por dos razones: sale diez veces más barato y los diez
salen con el mismo estilo y el mismo tamaño, que es lo que hace que se
vean de la misma familia.
"""

# (id, nombre visible, descripción en inglés para el prompt)
CAPITULOS: dict[int, tuple[str, list[tuple[str, str, str]]]] = {
    2: ("El Invernadero", [
        ("pulgon_cristal", "Pulgón de Cristal", "a tiny translucent pale-green glass-like aphid"),
        ("arana_roja_riego", "Araña Roja del Riego", "a small bright red spider mite with water droplets on its back"),
        ("mosca_blanca_vapor", "Mosca Blanca del Vapor", "a tiny white whitefly with steamy translucent wings"),
        ("trips_plateado", "Trips Plateado", "a slender silver thrips insect"),
        ("cochinilla_algodon", "Cochinilla de Algodón", "a fluffy white cottony mealybug"),
        ("minador_hoja", "Minador de Hojas", "a small brown leaf-miner grub curled inside a green leaf"),
        ("caracol_maceta", "Caracol de Maceta", "a small snail with a terracotta flowerpot for a shell"),
        ("grillo_topo_verde", "Grillo Topo Verde", "a green mole cricket with wide shovel-shaped front legs"),
        ("escarabajo_pulga", "Escarabajo Pulga", "a shiny black flea beetle with big jumping hind legs"),
        ("avispa_polinizadora", "Avispa Polinizadora", "a fuzzy yellow pollinator wasp dusted with pollen"),
    ]),
    3: ("La Cueva Subterránea", [
        ("ciempies_fosforo", "Ciempiés de Fósforo", "a glowing pale centipede with bioluminescent segments"),
        ("arana_lampara", "Araña Lámpara", "a cave spider with a glowing lantern-like abdomen"),
        ("grillo_ciego", "Grillo Ciego", "a pale eyeless cave cricket with very long antennae"),
        ("escarabajo_estalactita", "Escarabajo Estalactita", "a grey beetle with a rocky spiked stone shell"),
        ("colembolo_saltarin", "Colémbolo Saltarín", "a tiny round purple springtail with a spring-loaded tail"),
        ("opilion_zanco", "Opilión Zanco", "a harvestman with extremely long thin stilt legs"),
        ("cucaracha_murcielago", "Cucaracha Murciélago", "a dark cockroach with leathery bat wings"),
        ("gusano_luz", "Gusano de Luz", "a glowworm larva with a glowing blue tail"),
        ("escorpion_pozo", "Escorpión de Pozo", "a small pale translucent cave scorpion"),
        ("polilla_cristal", "Polilla de Cristal", "a moth with transparent crystalline wings"),
    ]),
    4: ("El Cultivo Radiactivo", [
        ("escarabajo_uranio", "Escarabajo de Uranio", "a beetle with a glowing green cracked shell"),
        ("mosca_geiger", "Mosca Geiger", "a fly with a tiny geiger-counter dial on its back"),
        ("hormiga_isotopo", "Hormiga Isótopo", "an ant with a glowing yellow abdomen"),
        ("gusano_neon", "Gusano Neón", "a bright neon-green glowing worm"),
        ("chinche_plutonio", "Chinche de Plutonio", "a stink bug with a purple glowing shield back"),
        ("libelula_reactor", "Libélula Reactor", "a dragonfly with glowing orange reactor-core wings"),
        ("avispa_cesio", "Avispa Cesio", "a wasp with glowing blue stripes"),
        ("oruga_fluorescente", "Oruga Fluorescente", "a caterpillar with fluorescent glowing spots"),
        ("escarabajo_barril", "Escarabajo Barril", "a beetle carrying a small toxic-waste barrel as its shell"),
        ("mosquito_radon", "Mosquito Radón", "a mosquito with a glowing green translucent body"),
    ]),
    5: ("El Pantano", [
        ("mosquito_cieno", "Mosquito de Cieno", "a muddy brown mosquito dripping with slime"),
        ("sanguijuela_saltarina", "Sanguijuela Saltarina", "a dark red leech coiled up like a spring"),
        ("libelula_juncos", "Libélula de Juncos", "a green dragonfly with reed-patterned wings"),
        ("escarabajo_buzo", "Escarabajo Buzo", "a diving beetle carrying an air bubble on its back"),
        ("arana_pescadora", "Araña Pescadora", "a large brown fishing spider with splayed legs"),
        ("tabano_barro", "Tábano de Barro", "a chunky horsefly caked in dried mud"),
        ("caracol_manglar", "Caracol de Manglar", "a snail with a mossy shell and small roots growing on it"),
        ("zapatero_agua", "Zapatero de Agua", "a thin water strider with very long splayed legs"),
        ("larva_pantano", "Larva de Pantano", "a fat greenish swamp larva with algae on its skin"),
        ("luciernaga_niebla", "Luciérnaga de Niebla", "a firefly with a soft glowing misty halo"),
    ]),
    6: ("Laboratorio Mutante", [
        ("quimera_seis_patas", "Quimera de Seis Patas", "a chimera insect with mismatched body parts from different bugs"),
        ("clon_defectuoso", "Clon Defectuoso", "a beetle with a half-formed duplicate body growing out of it"),
        ("hormiga_probeta", "Hormiga Probeta", "an ant with a glass test-tube for an abdomen"),
        ("escarabajo_bisturi", "Escarabajo Bisturí", "a beetle with scalpel-blade mandibles"),
        ("mosca_dos_cabezas", "Mosca de Dos Cabezas", "a fly with two heads"),
        ("mantis_injerto", "Mantis Injerto", "a mantis with one grafted mechanical arm"),
        ("gusano_adn", "Gusano ADN", "a worm with a double-helix twisted body"),
        ("avispa_jeringa", "Avispa Jeringa", "a wasp with a syringe for a stinger"),
        ("cucaracha_espejo", "Cucaracha Espejo", "a cockroach with a mirror-chrome shell"),
        ("larva_incubadora", "Larva de Incubadora", "a pale larva inside a small glass incubator pod"),
    ]),
    7: ("Fábrica de Cascos", [
        ("escarabajo_yunque", "Escarabajo Yunque", "a beetle with an anvil-shaped iron shell"),
        ("hormiga_remache", "Hormiga Remache", "an ant made of riveted metal plates"),
        ("tornillo_viviente", "Tornillo Viviente", "a living bug whose body is a big steel screw"),
        ("mantis_soldadora", "Mantis Soldadora", "a mantis with welding-torch arms throwing sparks"),
        ("escarabajo_engranaje", "Escarabajo Engranaje", "a beetle with gear-wheel wing covers"),
        ("avispa_taladro", "Avispa Taladro", "a wasp with a drill bit for a stinger"),
        ("cucaracha_chapa", "Cucaracha de Chapa", "a cockroach made of corrugated sheet metal"),
        ("grillo_resorte", "Grillo Resorte", "a cricket with coiled steel spring legs"),
        ("escarabajo_prensa", "Escarabajo Prensa", "a heavy beetle with a flat press-plate back"),
        ("mosca_chispa", "Mosca Chispa", "a fly trailing welding sparks"),
    ]),
    8: ("Red de Túneles Express", [
        ("hormiga_correo", "Hormiga Correo", "an ant carrying a small parcel on its back"),
        ("escarabajo_vagon", "Escarabajo Vagón", "a beetle with a train-car shaped shell"),
        ("cucaracha_turbo", "Cucaracha Turbo", "a cockroach with a small jet turbine on its back"),
        ("gusano_taladro", "Gusano Taladro", "a worm with a rotating drill head"),
        ("mantis_semaforo", "Mantis Semáforo", "a mantis with traffic-light coloured eyes"),
        ("avispa_mensajera", "Avispa Mensajera", "a wasp with a tiny mail satchel"),
        ("grillo_riel", "Grillo de Riel", "a cricket with rail-track patterned legs"),
        ("escarabajo_furgon", "Escarabajo Furgón", "an armoured beetle shaped like a freight wagon"),
        ("mosca_expres", "Mosca Exprés", "a streamlined fast fly with speed-blur wings"),
        ("hormiga_carga", "Hormiga de Carga", "a big ant hauling a stack of crates"),
    ]),
    9: ("El Búnker Enemigo", [
        ("escarabajo_bunker", "Escarabajo de Búnker", "a beetle with thick concrete-grey armour"),
        ("hormiga_centinela", "Hormiga Centinela", "an ant wearing a searchlight helmet"),
        ("mantis_francotiradora", "Mantis Francotiradora", "a mantis with a long rifle-like foreleg"),
        ("avispa_granada", "Avispa Granada", "a wasp with a grenade-shaped abdomen"),
        ("cucaracha_radar", "Cucaracha Radar", "a cockroach with a radar dish on its back"),
        ("escarabajo_torreta", "Escarabajo Torreta", "a beetle with a rotating turret shell"),
        ("grillo_alarma", "Grillo Alarma", "a cricket with a siren horn on its back"),
        ("gusano_mina", "Gusano Mina", "a worm curled up like a land mine"),
        ("mosca_dron", "Mosca Dron", "a fly with four small drone rotors"),
        ("escorpion_guardia", "Escorpión Guardia", "an armoured scorpion with a shield-shaped tail"),
    ]),
    10: ("El Núcleo Reina", [
        ("cortesano_dorado", "Cortesano Dorado", "an elegant golden beetle wearing a small cape"),
        ("guardia_real", "Guardia Real", "a tall armoured purple and gold ant guard holding a spear"),
        ("nodriza_larvas", "Nodriza de Larvas", "a pale nurse insect carrying eggs on her back"),
        ("heraldo_reina", "Heraldo de la Reina", "an insect with a trumpet-shaped proboscis"),
        ("tejedor_panal", "Tejedor de Panal", "an insect weaving golden honeycomb"),
        ("sacerdote_ambar", "Sacerdote de Ámbar", "an insect wrapped in translucent amber robes"),
        ("verdugo_quitina", "Verdugo de Quitina", "a dark executioner beetle with an axe-shaped claw"),
        ("arquitecto_nido", "Arquitecto del Nido", "an insect with blueprint-patterned wings"),
        ("principe_alado", "Príncipe Alado", "a regal winged insect prince with a small crown"),
        ("eco_primordial", "Eco Primordial", "a ghostly translucent insect glowing violet"),
    ]),
}

def indice_de(capitulo: int, posicion: int) -> int:
    """Índice global del incógnito. El capítulo 2 arranca en el 11."""
    return (capitulo - 2) * 10 + 11 + posicion

def prompt_hoja(capitulo: int) -> str:
    """Una hoja 5x2 con los diez bichos del capítulo."""
    _, bichos = CAPITULOS[capitulo]
    lista = "; ".join("cell %d: %s" % (i + 1, d) for i, (_, _, d) in enumerate(bichos))
    return (
        "a 5x2 sprite sheet grid of 10 DIFFERENT cute cartoon insects, five "
        "columns and two rows, with NO grid lines, NO borders and NO frames "
        "between them, each insect centered in its own cell and clearly "
        "separated from the others by wide empty background. Reading left to "
        "right, top row first: " + lista + ". Every insect is drawn at the "
        "same size and fills a similar amount of its cell, same camera angle "
        "and same art style for all ten, seen from a three-quarter view"
    )
