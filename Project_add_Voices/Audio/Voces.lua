--[[
	VOCES · Datos de cada audio de la historia
	Studio: ReplicatedStorage > StoryTemplate > Modulos > Voces

	GENERADO por Audio/analizar_audio.py a partir de Audio/voces.json y los WAV.
	No lo edites a mano: cambia voces.json (por ejemplo el Id) y vuelve a ejecutar
	  python Audio/analizar_audio.py  y  node build.js

	Id         → id del audio subido a Roblox ("rbxassetid://..."). Vacío = sin sonido,
	             pero la escena mantiene los mismos tiempos (útil para montar el audio después).
	Duracion   → segundos del archivo.
	Segmentos  → tramos con voz { inicio, fin } en segundos desde el inicio del audio.
	Envolvente → volumen cada Paso segundos (0-9) para mover la boca.
]]

return {
	Paso = 0.05,
	postit1 = {
		Archivo = "postit1.WAV",
		Id = "rbxassetid://112400743441885",
		Personaje = "Art",
		Tipo = "Narrador",
		Escena = 1,
		Duracion = 4.203,
		Texto = "¿Te interesa saber cómo se creó el primer Post-it? ¡Todo comenzó con un pegamento que parecía un fracaso!",
		Segmentos = { { 0.18, 1.96 }, { 2.38, 4.08 } },
		Envolvente = "1116978876588996310887574999837895893262201111069968875968879867777758757968838733100",
	},
	postit2 = {
		Archivo = "postit2.WAV",
		Id = "rbxassetid://73048597437669",
		Personaje = "Spencer",
		Tipo = "Dialogo",
		Escena = 2,
		Duracion = 4.203,
		Texto = "¡He creado un pegamento especial! Se pega, pero puedes quitarlo sin problemas.",
		Segmentos = { { 0.52, 1.82 }, { 2.0, 4.1 } },
		Envolvente = "0000002211783799886476655375264477742111486996982167725976442786564454466755444212210",
	},
	postit3 = {
		Archivo = "postit3.WAV",
		Id = "rbxassetid://121842356559664",
		Personaje = "Art",
		Tipo = "Dialogo",
		Escena = 2,
		Duracion = 1.3,
		Texto = "¿Y para qué sirve eso?",
		Segmentos = { { 0.36, 1.2 } },
		Envolvente = "000011184886396597997475200",
	},
	postit4 = {
		Archivo = "postit4.WAV",
		Id = "rbxassetid://135160250082727",
		Personaje = "Art",
		Tipo = "Narrador",
		Escena = 3,
		Duracion = 4.04,
		Texto = "En 1974 tenía un problema: ¡mis marcapáginas siempre acababan en el suelo!",
		Segmentos = { { 0.28, 1.94 }, { 2.26, 3.94 } },
		Envolvente = "000114999889878758878689487779985999774111110799797787538956997877899776658986410",
	},
	postit5 = {
		Archivo = "postit5.WAV",
		Id = "rbxassetid://140254214115431",
		Personaje = "Art",
		Tipo = "Dialogo",
		Escena = 3,
		Duracion = 1.068,
		Texto = "¡Otra vez no!",
		Segmentos = { { 0.26, 0.94 } },
		Envolvente = "0011188798966899885110",
	},
	postit6 = {
		Archivo = "postit6.WAV",
		Id = "rbxassetid://7474276044230",
		Personaje = "Art",
		Tipo = "Narrador",
		Escena = 4,
		Duracion = 2.879,
		Texto = "Entonces recordé aquel extraño pegamento y tuve una idea.",
		Segmentos = { { 0.32, 2.8 } },
		Envolvente = "0000113787599998778897786387748879876488876517897778987410",
	},
	postit7 = {
		Archivo = "postit7.WAV",
		Id = "rbxassetid://118988480490208",
		Personaje = "Art",
		Tipo = "Dialogo",
		Escena = 4,
		Duracion = 2.113,
		Texto = "¡Espera! ¿Y si lo utilizo para crear un marcapáginas?",
		Segmentos = { { 0.22, 1.84 } },
		Envolvente = "0011772988465875968798489878663956763201100",
	},
	postit8 = {
		Archivo = "postit8.WAV",
		Id = "rbxassetid://79697612206428",
		Personaje = "Art",
		Tipo = "Dialogo",
		Escena = 5,
		Duracion = 2.879,
		Texto = "¡Funciona! ¡No se cae y puedo quitarlo sin romper nada!",
		Segmentos = { { 0.16, 1.0 }, { 1.36, 2.64 } },
		Envolvente = "1116979966327785988511110016999983895688875586867988411100",
	},
	postit9 = {
		Archivo = "postit9.WAV",
		Id = "rbxassetid://105692879107754",
		Personaje = "Art",
		Tipo = "Narrador",
		Escena = 5,
		Duracion = 5.433,
		Texto = "Después empezamos a utilizarlos para dejar mensajes. ¡Habíamos encontrado algo mucho más útil que un simple marcapáginas!",
		Segmentos = { { 0.22, 2.08 }, { 2.5, 3.86 }, { 4.02, 5.24 } },
		Envolvente = "0011563967758858576796964268974877569568540112222189885777689977774886586798521129999977698888676773677541110",
	},
	postit10 = {
		Archivo = "postit10.WAV",
		Id = "rbxassetid://131840630034624",
		Personaje = "Art",
		Tipo = "Narrador",
		Escena = 6,
		Duracion = 8.754,
		Texto = "En 1980 llegaron oficialmente a las tiendas como Post-it. ¡Y todo gracias a un pegamento que parecía inútil!",
		Segmentos = { { 0.36, 1.46 }, { 1.72, 3.62 }, { 4.24, 6.4 }, { 7.36, 8.58 } },
		Envolvente = "00001117888999956978584876885101104999888666598788679886369887278729842732100001100018689797895767876898788677418387648987772664100000000000002211157468644784655465466653331200",
	},
	postit11 = {
		Archivo = "postit11.WAV",
		Id = "rbxassetid://117221469329445",
		Personaje = "Spencer",
		Tipo = "Dialogo",
		Escena = 6,
		Duracion = 1.649,
		Texto = "¡Al final sí que servía para algo!",
		Segmentos = { { 0.24, 1.48 } },
		Envolvente = "232116757965589575646646776443120",
	},
}
