--[[
	HISTORIA_POSTIT · «El pegamento que no pegaba» (Guion.md, 6 escenas)
	Studio: ReplicatedStorage > StoryTemplate > Escenas > Historia_PostIt

	Toda la escena es una LÍNEA DE TIEMPO: cada paso tiene  T = segundo  y se
	ejecuta exactamente en ese momento (contado desde el primer paso).
	Las voces (Audio/postit1..11.WAV) empiezan en los segundos de la tabla VOZ y
	cada acción se ancla a una voz:  T = en("postit2", 1.5)  = 1.5 s después de
	que empiece postit2. Así, si cambias un audio, basta con mover su entrada en VOZ.

	Duración de cada audio y tramos con voz (medidos por Audio/analizar_audio.py):
	  postit1  4.20 s  [0.18-1.96] [2.38-4.08]
	  postit2  4.20 s  [0.52-1.82] [2.00-4.10]
	  postit3  1.30 s  [0.36-1.20]
	  postit4  4.04 s  [0.28-1.94] [2.26-3.94]
	  postit5  1.07 s  [0.26-0.94]
	  postit6  2.88 s  [0.32-2.80]
	  postit7  2.11 s  [0.22-1.84]
	  postit8  2.88 s  [0.16-1.00] [1.36-2.64]
	  postit9  5.43 s  [0.22-2.08] [2.50-3.86] [4.02-5.24]
	  postit10 8.75 s  [0.36-1.46] [1.72-3.62] [4.24-6.40] [7.36-8.58]
	  postit11 1.65 s  [0.24-1.48]

	Personajes: Spencer (químico, bata y gafas) y Art (ingeniero y narrador).
	Escenarios: Laboratorio y SalaEnsayo.
]]

-- Segundo de la escena en el que empieza cada audio (tabla de sincronización)
local VOZ = {
	postit1 = 0.00, -- Escena 1
	postit2 = 5.20, -- Escena 2
	postit3 = 9.75,
	postit4 = 12.45, -- Escena 3
	postit5 = 16.60,
	postit6 = 17.95, -- Escena 4
	postit7 = 21.10,
	postit8 = 23.75, -- Escena 5
	postit9 = 26.95,
	postit10 = 32.55, -- Escena 6
	postit11 = 41.80,
}
local FIN = 47.0

local function en(voz, mas)
	return VOZ[voz] + (mas or 0)
end

local NOTA_AMARILLA = Color3.fromRGB(255, 225, 60)
local NOTA_ROSA = Color3.fromRGB(255, 160, 190)
local NOTA_AZUL = Color3.fromRGB(140, 205, 245)
local NOTA_VERDE = Color3.fromRGB(170, 230, 140)

return {
	Entorno = "Laboratorio",

	Reparto = {
		Spencer = "Spencer",
		Art = "Art",
	},

	Posiciones = {
		Spencer = "Pos_TrasMesa",
		Art = { Marca = "Pos_A", MirarA = "Camara" },
	},

	-- Objetos: los que tienen En / EnManoDe aparecen al empezar; el resto se usan más tarde.
	Objetos = {
		Muestra = { Modelo = "PapelAdhesivo", EnManoDe = "Spencer" }, -- el papel con el pegamento de Spencer
		Bote = { Modelo = "Pegamento", En = "Obj_1" },
		Recuerdo = { Modelo = "PapelAdhesivo" }, -- el que aparece en el flashback
		Cancionero = { Modelo = "Cancionero" },
		CancioneroAbierto = { Modelo = "CancioneroAbierto" },
		Marcapaginas = { Modelo = "Marcapaginas" },
		Bloc = { Modelo = "BlocNotas" },
		CajaA = { Modelo = "CajaNotas" },
		CajaB = { Modelo = "CajaNotas" },
		CajaC = { Modelo = "CajaNotas" },
		Nota1 = { Modelo = "NotaAmarilla", Texto = "¡Reunión 3pm!", Color = NOTA_AMARILLA },
		Nota2 = { Modelo = "NotaAmarilla", Texto = "Llamar a Bob", Color = NOTA_ROSA },
		Nota3 = { Modelo = "NotaAmarilla", Texto = "Comprar café", Color = NOTA_AZUL },
		Nota4 = { Modelo = "NotaAmarilla", Texto = "¡Funciona!", Color = NOTA_AMARILLA },
		Nota5 = { Modelo = "NotaAmarilla", Texto = "Ensayo jueves", Color = NOTA_VERDE },
		Nota6 = { Modelo = "NotaAmarilla", Texto = "No tocar :)", Color = NOTA_AMARILLA },
	},

	-- Plano inicial: Art habla a cámara (gancho)
	Camara = { Plano = "PrimerPlano", Actor = "Art", Angulo = 0 },

	Pasos = {
		--======================================================================
		-- ESCENA 1 · El pegamento que no pegaba (Laboratorio)
		-- ART: «¿Te interesa saber cómo se creó el primer Post-it?
		--       ¡Todo comenzó con un pegamento que parecía un fracaso!»
		--======================================================================
		-- Gancho: Art mira a cámara y habla (labios solo en la primera frase)
		{ T = en("postit1"), Accion = "Voz", Voz = "postit1", Actor = "Art", Labios = true, LabiosHasta = 2.05, Gestos = true },
		{ T = en("postit1"), Accion = "Gesto", Actor = "Spencer", Gesto = "Examinar", Duracion = 2 },

		-- «¡Todo comenzó con un pegamento...»: Spencer pega el papel en el tablón
		{ T = en("postit1", 2.05), Accion = "Camara", Plano = "General", Actores = { "Art", "Spencer" }, Inclinacion = 6, Holgura = 1.05 },
		{ T = en("postit1", 2.05), Accion = "Mirar", Actor = "Art", A = "Spencer" },
		{ T = en("postit1", 2.15), Accion = "Pegar", Actor = "Spencer", Objeto = "Muestra", En = "Pared_1" },
		-- «...que parecía un fracaso!»: el papel se despega y cae
		{ T = en("postit1", 3.2), Accion = "Caer", Objeto = "Muestra", Tiempo = 0.85 },
		{ T = en("postit1", 3.35), Accion = "Expresion", Actor = "Art", Expresion = "Curiosidad", Duracion = 2.2 },
		-- Spencer lo recoge del suelo y se acerca a Art
		{ T = en("postit1", 4.15), Accion = "Recoger", Actor = "Spencer", Objeto = "Muestra" },
		{ T = en("postit1", 4.95), Accion = "Expresion", Actor = "Spencer", Expresion = "Feliz", Duracion = 4.4 },
		{ T = en("postit1", 5.0), Accion = "Caminar", Actor = "Spencer", Hasta = "Art", Distancia = 2.5, MirarA = "Art" },

		--======================================================================
		-- ESCENA 2 · Un invento inútil (Laboratorio)
		-- SPENCER: «¡He creado un pegamento especial! Se pega, pero puedes quitarlo sin problemas».
		-- ART: «¿Y para qué sirve eso?».
		--======================================================================
		{ T = en("postit2"), Accion = "Voz", Voz = "postit2" },
		{ T = en("postit2", 0.35), Accion = "Camara", Plano = "DosPersonajes", Actores = { "Spencer", "Art" }, Angulo = 0 },
		-- «¡He creado un pegamento especial!»: Spencer enseña el papel, orgulloso
		{ T = en("postit2", 0.4), Accion = "Gesto", Actor = "Spencer", Gesto = "Mostrar", Duracion = 1.1 },
		{ T = en("postit2", 0.4), Accion = "Expresion", Actor = "Art", Expresion = "Curiosidad", Duracion = 3.6 },
		-- Se lo entrega a Art
		{ T = en("postit2", 1.55), Accion = "Entregar", De = "Spencer", A = "Art" },
		-- «Se pega...»: Art lo pega en la pizarra
		{ T = en("postit2", 2.7), Accion = "Pegar", Actor = "Art", Objeto = "Muestra", En = "Pared_2" },
		-- «...pero puedes quitarlo sin problemas»: y lo despega
		{ T = en("postit2", 3.65), Accion = "Recoger", Actor = "Art", Objeto = "Muestra" },

		-- ART: «¿Y para qué sirve eso?» mirando el papel con curiosidad
		{ T = en("postit3", -0.43), Accion = "Mirar", Actor = "Art", A = "Camara" },
		{ T = en("postit3", -0.4), Accion = "Gesto", Actor = "Art", Gesto = "Examinar", Mantener = true },
		{ T = en("postit3", -0.05), Accion = "Camara", Plano = "Personaje", Actor = "Art", Angulo = 0 },
		{ T = en("postit3"), Accion = "Voz", Voz = "postit3" },
		{ T = en("postit3"), Accion = "Expresion", Actor = "Art", Expresion = "Duda", Duracion = 1.5 },
		-- Spencer se encoge de hombros
		{ T = en("postit3", 1.4), Accion = "Camara", Plano = "DosPersonajes", Actores = { "Art", "Spencer" }, Angulo = 0 },
		{ T = en("postit3", 1.4), Accion = "Gesto", Actor = "Spencer", Gesto = "Encogerse", Duracion = 0.9 },
		{ T = en("postit3", 1.4), Accion = "Expresion", Actor = "Spencer", Expresion = "Duda", Duracion = 0.9 },

		-- Fundido a negro: saltamos a 1974
		{ T = en("postit3", 2.1), Accion = "Fundido", Entrada = 0.3, Mantener = 0.3, Salida = 0.4 },

		--======================================================================
		-- ESCENA 3 · Mi pequeño problema (Sala de ensayo)
		-- ART (NARRADOR): «En 1974 tenía un problema: ¡mis marcapáginas siempre acababan en el suelo!».
		-- ART: «¡Otra vez no!».
		--======================================================================
		{ T = en("postit4", -0.3), Accion = "Entorno", Nombre = "SalaEnsayo" },
		{ T = en("postit4", -0.3), Accion = "Sentar", Actor = "Art", En = "Silla_1" },
		{ T = en("postit4", -0.3), Accion = "Objeto", Objeto = "Muestra", En = "Obj_Nota" }, -- Art se guardó la muestra
		{ T = en("postit4", -0.3), Accion = "Objeto", Objeto = "Cancionero", En = "Obj_Libro" },
		{ T = en("postit4", -0.3), Accion = "Objeto", Objeto = "Marcapaginas", En = "Obj_Papeles" },
		{ T = en("postit4", -0.3), Accion = "Camara", Plano = "Fija", Marca = "Cam_General", Acercar = 3, TiempoAcercar = 1.4 },
		{ T = en("postit4", -0.15), Accion = "Texto", Texto = "1974", Estilo = "Rotulo", Duracion = 2.6 },
		{ T = en("postit4"), Accion = "Voz", Voz = "postit4" },

		-- «tenía un problema»: abre el cancionero
		{ T = en("postit4", 1.1), Accion = "Camara", Plano = "Personaje", Actor = "Art", Angulo = 12, Acercar = 0.6, TiempoAcercar = 3 },
		{ T = en("postit4", 1.15), Accion = "Gesto", Actor = "Art", Gesto = "AlcanzarMesa", Duracion = 0.7 },
		{ T = en("postit4", 1.55), Accion = "Objeto", Objeto = "Cancionero", Visible = false },
		{ T = en("postit4", 1.55), Accion = "Objeto", Objeto = "CancioneroAbierto", En = "Obj_Libro" },
		-- Coge un marcapáginas y lo pone entre las páginas
		{ T = en("postit4", 2.05), Accion = "Recoger", Actor = "Art", Objeto = "Marcapaginas" },
		{ T = en("postit4", 2.7), Accion = "Soltar", Actor = "Art", En = "CancioneroAbierto", Desplazamiento = Vector3.new(0.25, 0, 0) },
		-- «...acababan en el suelo!»: se escurre y cae
		{ T = en("postit4", 3.2), Accion = "Camara", Plano = "Personaje", Actor = "Art", Encuadre = "Cuerpo", Angulo = 18 },
		{ T = en("postit4", 3.25), Accion = "Caer", Objeto = "Marcapaginas", Hasta = "Suelo_Libro", Tiempo = 0.75 },

		-- Art mira al suelo, frustrado: «¡Otra vez no!»
		{ T = en("postit5", -0.15), Accion = "Gesto", Actor = "Art", Gesto = "MirarAbajo", Mantener = true },
		{ T = en("postit5", -0.15), Accion = "Expresion", Actor = "Art", Expresion = "Frustracion", Duracion = 1.5 },
		{ T = en("postit5", -0.1), Accion = "Camara", Plano = "PrimerPlano", Actor = "Art", Angulo = 0, Inclinacion = 4 },
		{ T = en("postit5"), Accion = "Voz", Voz = "postit5" },
		{ T = en("postit5", 0.25), Accion = "Gesto", Actor = "Art", Gesto = "Lamentarse", Duracion = 0.9 },

		--======================================================================
		-- ESCENA 4 · ¡Eureka! (Sala de ensayo + recuerdo del laboratorio)
		-- ART (NARRADOR): «Entonces recordé aquel extraño pegamento y tuve una idea».
		-- ART: «¡Espera! ¿Y si lo utilizo para crear un marcapáginas?».
		--======================================================================
		{ T = en("postit6", -0.2), Accion = "Camara", Plano = "Personaje", Actor = "Art", Angulo = -12 },
		{ T = en("postit6", -0.2), Accion = "Gesto", Actor = "Art", Gesto = "Pensar", Duracion = 1.2 },
		{ T = en("postit6", -0.2), Accion = "Expresion", Actor = "Art", Expresion = "Pensativo", Duracion = 1 },
		{ T = en("postit6"), Accion = "Voz", Voz = "postit6" },

		-- «recordé aquel extraño pegamento»: flashback en sepia
		{ T = en("postit6", 0.6), Accion = "Fundido", Color = "Blanco", Entrada = 0.12, Mantener = 0.08, Salida = 0.25 },
		{ T = en("postit6", 0.8), Accion = "Entorno", Nombre = "Laboratorio" },
		{ T = en("postit6", 0.8), Accion = "Ocultar", Actor = "Art" },
		{ T = en("postit6", 0.8), Accion = "Colocar", Actor = "Spencer", En = "Pos_TrasMesa" },
		{ T = en("postit6", 0.8), Accion = "Objeto", Objeto = "Recuerdo", EnManoDe = "Spencer" },
		{ T = en("postit6", 0.8), Accion = "Filtro", Filtro = "Recuerdo" },
		{ T = en("postit6", 0.8), Accion = "Camara", Plano = "Personaje", Actor = "Spencer", Angulo = 0, Acercar = 0.8, TiempoAcercar = 1.1 },
		{ T = en("postit6", 0.85), Accion = "Gesto", Actor = "Spencer", Gesto = "Mostrar", Mantener = true },
		{ T = en("postit6", 0.85), Accion = "Expresion", Actor = "Spencer", Expresion = "Feliz", Duracion = 1.1 },

		-- «y tuve una idea»: vuelta a la sala, ¡idea!
		{ T = en("postit6", 1.85), Accion = "Fundido", Color = "Blanco", Entrada = 0.12, Mantener = 0.08, Salida = 0.25 },
		{ T = en("postit6", 2.05), Accion = "Filtro", Filtro = "Ninguno" },
		{ T = en("postit6", 2.05), Accion = "Entorno", Nombre = "SalaEnsayo" },
		{ T = en("postit6", 2.05), Accion = "Camara", Plano = "Personaje", Actor = "Art", Angulo = 0 },
		{ T = en("postit6", 2.1), Accion = "Gesto", Actor = "Art", Gesto = "Idea", Duracion = 1.3 },
		{ T = en("postit6", 2.1), Accion = "Expresion", Actor = "Art", Expresion = "Idea", Duracion = 1.6 },
		{ T = en("postit6", 2.15), Accion = "Texto", Texto = "💡", Estilo = "Icono", Duracion = 1.3, Posicion = Vector2.new(0.72, 0.2) },

		-- «¡Espera! ¿Y si lo utilizo para crear un marcapáginas?»: coge la muestra y la pega en la página
		{ T = en("postit7"), Accion = "Voz", Voz = "postit7" },
		{ T = en("postit7"), Accion = "Camara", Plano = "Personaje", Actor = "Art", Angulo = 8, Acercar = 0.8, TiempoAcercar = 2.2 },
		{ T = en("postit7", 0.65), Accion = "Recoger", Actor = "Art", Objeto = "Muestra" },
		{ T = en("postit7", 1.2), Accion = "Pegar", Actor = "Art", Objeto = "Muestra", En = "CancioneroAbierto", Desplazamiento = Vector3.new(0.55, 0, -0.35) },
		{ T = en("postit7", 1.8), Accion = "Expresion", Actor = "Art", Expresion = "Feliz", Duracion = 1.2 },
		{ T = en("postit7", 1.85), Accion = "Gesto", Actor = "Art", Gesto = "Asentir", Duracion = 0.8 },

		--======================================================================
		-- ESCENA 5 · ¡Funciona! (Laboratorio)
		-- ART: «¡Funciona! ¡No se cae y puedo quitarlo sin romper nada!».
		-- ART (NARRADOR): «Después empezamos a utilizarlos para dejar mensajes.
		--                  ¡Habíamos encontrado algo mucho más útil que un simple marcapáginas!».
		--======================================================================
		{ T = en("postit8", -0.2), Accion = "Fundido", Entrada = 0.15, Mantener = 0.05, Salida = 0.25 },
		{ T = en("postit8"), Accion = "Entorno", Nombre = "Laboratorio" },
		{ T = en("postit8"), Accion = "Objeto", Objeto = "Recuerdo", Visible = false },
		{ T = en("postit8"), Accion = "Colocar", Actor = "Spencer", En = "Pos_TrasMesa" },
		{ T = en("postit8"), Accion = "Colocar", Actor = "Art", En = "Pos_A" },
		{ T = en("postit8"), Accion = "Objeto", Objeto = "CancioneroAbierto", En = "Obj_2" },
		{ T = en("postit8"), Accion = "Objeto", Objeto = "Muestra", En = "CancioneroAbierto", Desplazamiento = Vector3.new(0.55, 0, -0.35) },
		{ T = en("postit8"), Accion = "Camara", Plano = "DosPersonajes", Actores = { "Art", "Spencer" }, Angulo = 0 },
		{ T = en("postit8"), Accion = "Voz", Voz = "postit8" },
		-- «¡Funciona!»: Art señala el papel pegado
		{ T = en("postit8", 0.05), Accion = "Senalar", Actor = "Art", A = "CancioneroAbierto", Duracion = 1.1 },
		{ T = en("postit8", 0.05), Accion = "Expresion", Actor = "Art", Expresion = "Feliz", Duracion = 2.9 },
		{ T = en("postit8", 0.1), Accion = "Mirar", Actor = "Spencer", A = "CancioneroAbierto", SoloCabeza = true },
		-- «¡No se cae y puedo quitarlo sin romper nada!»: Spencer lo quita y lo vuelve a pegar
		{ T = en("postit8", 1.3), Accion = "Camara", Plano = "Personaje", Actor = "Spencer", Angulo = 0 },
		{ T = en("postit8", 1.35), Accion = "Recoger", Actor = "Spencer", Objeto = "Muestra" },
		{ T = en("postit8", 2.1), Accion = "Pegar", Actor = "Spencer", Objeto = "Muestra", En = "CancioneroAbierto", Desplazamiento = Vector3.new(0.55, 0, -0.35) },
		-- Art observa satisfecho
		{ T = en("postit8", 2.7), Accion = "Camara", Plano = "DosPersonajes", Actores = { "Art", "Spencer" }, Angulo = 0, Transicion = 0.5 },
		{ T = en("postit8", 2.75), Accion = "Gesto", Actor = "Art", Gesto = "Asentir", Duracion = 1 },
		{ T = en("postit8", 2.75), Accion = "Expresion", Actor = "Art", Expresion = "Orgullo", Duracion = 2 },
		{ T = en("postit8", 2.75), Accion = "Expresion", Actor = "Spencer", Expresion = "Feliz", Duracion = 2 },

		-- «Después empezamos a utilizarlos para dejar mensajes»: el tablón se llena de notas
		{ T = en("postit9"), Accion = "Voz", Voz = "postit9" },
		{ T = en("postit9", 0.1), Accion = "Camara", Plano = "Fija", Marca = "Cam_Tablon", Acercar = 0.8, TiempoAcercar = 2.4 },
		{ T = en("postit9", 0.3), Accion = "Aparecer", Objeto = "Nota1", En = "Nota_1" },
		{ T = en("postit9", 0.6), Accion = "Aparecer", Objeto = "Nota2", En = "Nota_2" },
		{ T = en("postit9", 0.9), Accion = "Aparecer", Objeto = "Nota3", En = "Nota_3" },
		{ T = en("postit9", 1.2), Accion = "Aparecer", Objeto = "Nota4", En = "Nota_4" },
		{ T = en("postit9", 1.5), Accion = "Aparecer", Objeto = "Nota5", En = "Nota_5" },
		{ T = en("postit9", 1.8), Accion = "Aparecer", Objeto = "Nota6", En = "Nota_6" },
		-- «¡Habíamos encontrado algo mucho más útil...»: se miran, satisfechos
		{ T = en("postit9", 2.35), Accion = "Camara", Plano = "DosPersonajes", Actores = { "Art", "Spencer" }, Angulo = 0, Transicion = 0.5 },
		{ T = en("postit9", 2.4), Accion = "Mirar", Actor = "Art", A = "Spencer" },
		{ T = en("postit9", 2.4), Accion = "Mirar", Actor = "Spencer", A = "Art" },
		{ T = en("postit9", 2.4), Accion = "Expresion", Actor = "Art", Expresion = "Orgullo", Duracion = 1.6 },
		-- «...que un simple marcapáginas!»: celebran
		{ T = en("postit9", 4.05), Accion = "Gesto", Actor = "Spencer", Gesto = "BrazoArriba", Duracion = 1.1 },
		{ T = en("postit9", 4.05), Accion = "Expresion", Actor = "Spencer", Expresion = "Feliz", Duracion = 1.4 },
		{ T = en("postit9", 4.1), Accion = "Gesto", Actor = "Art", Gesto = "Asentir", Duracion = 1 },
		{ T = en("postit9", 4.1), Accion = "Expresion", Actor = "Art", Expresion = "Feliz", Duracion = 1.4 },

		--======================================================================
		-- ESCENA 6 · Un fracaso convertido en éxito (Laboratorio, 1980)
		-- ART (NARRADOR): «En 1980 llegaron oficialmente a las tiendas como Post-it.
		--                  ¡Y todo gracias a un pegamento que parecía inútil!».
		-- SPENCER: «¡Al final sí que servía para algo!».
		--======================================================================
		{ T = en("postit10", -0.4), Accion = "Fundido", Entrada = 0.2, Mantener = 0.2, Salida = 0.35 },
		{ T = en("postit10", -0.2), Accion = "Colocar", Actor = "Art", En = "Pos_C" },
		{ T = en("postit10", -0.2), Accion = "Objeto", Objeto = "Bloc", EnManoDe = "Art" },
		{ T = en("postit10", -0.2), Accion = "Colocar", Actor = "Spencer", En = "Pos_D" },
		{ T = en("postit10", -0.2), Accion = "Objeto", Objeto = "CajaA", En = "Obj_3" },
		{ T = en("postit10", -0.2), Accion = "Objeto", Objeto = "CajaB", En = "Obj_4" },
		{ T = en("postit10", -0.2), Accion = "Objeto", Objeto = "CajaC", En = "Suelo_1" },
		{ T = en("postit10", -0.2), Accion = "Camara", Plano = "Fija", Marca = "Cam_General", Acercar = 2.5, TiempoAcercar = 1.8 },
		{ T = en("postit10"), Accion = "Voz", Voz = "postit10" },
		-- «En 1980...»
		{ T = en("postit10", 0.1), Accion = "Texto", Texto = "1980", Estilo = "Rotulo", Duracion = 2.4 },
		-- «...llegaron oficialmente a las tiendas como Post-it»: Art presenta el bloc
		{ T = en("postit10", 1.65), Accion = "Camara", Plano = "Personaje", Actor = "Art", Angulo = 0, Acercar = 0.8, TiempoAcercar = 2.4 },
		{ T = en("postit10", 1.65), Accion = "Postura", Actor = "Art", Postura = "Mostrar" },
		{ T = en("postit10", 1.65), Accion = "Expresion", Actor = "Art", Expresion = "Orgullo", Duracion = 2.5 },
		-- «¡Y todo gracias a un pegamento...»: Spencer se acerca
		{ T = en("postit10", 4.15), Accion = "Camara", Plano = "DosPersonajes", Actores = { "Art", "Spencer" }, Angulo = 0, Seguir = true },
		{ T = en("postit10", 4.2), Accion = "Caminar", Actor = "Spencer", Hasta = "Art", Distancia = 2.4, MirarA = "Bloc" },
		-- Ambos miran el bloc
		{ T = en("postit10", 5.35), Accion = "Gesto", Actor = "Art", Gesto = "MirarAbajo", Mantener = true },
		{ T = en("postit10", 5.35), Accion = "Mirar", Actor = "Spencer", A = "Bloc", SoloCabeza = true },
		-- «...que parecía inútil!»
		{ T = en("postit10", 7.35), Accion = "Gesto", Actor = "Spencer", Gesto = "Asentir", Duracion = 1 },
		{ T = en("postit10", 7.35), Accion = "Expresion", Actor = "Spencer", Expresion = "Orgullo", Duracion = 1.8 },

		-- SPENCER: «¡Al final sí que servía para algo!» (a cámara)
		{ T = en("postit11", -0.5), Accion = "Mirar", Actor = "Spencer", A = "Camara" },
		{ T = en("postit11", -0.5), Accion = "Gesto", Actor = "Art", Gesto = "Asentir", Duracion = 0.8 },
		{ T = en("postit11", -0.12), Accion = "Camara", Plano = "PrimerPlano", Actor = "Spencer", Angulo = 0 },
		{ T = en("postit11"), Accion = "Voz", Voz = "postit11", Gestos = true },
		{ T = en("postit11"), Accion = "Expresion", Actor = "Spencer", Expresion = "Feliz", Duracion = 1.8 },

		-- «¡DE FRACASO A INVENTO MILLONARIO!»
		{ T = en("postit11", 1.7), Accion = "Camara", Plano = "General", Actores = { "Art", "Spencer" }, Inclinacion = 4, Transicion = 0.6 },
		{ T = en("postit11", 1.75), Accion = "Postura", Actor = "Art", Postura = "Ninguna" },
		{ T = en("postit11", 1.75), Accion = "Gesto", Actor = "Art", Gesto = "BrazoArriba", Mantener = true },
		{ T = en("postit11", 1.75), Accion = "Gesto", Actor = "Spencer", Gesto = "BrazoArriba", Mantener = true },
		{ T = en("postit11", 1.75), Accion = "Expresion", Actor = "Art", Expresion = "Feliz" },
		{ T = en("postit11", 1.75), Accion = "Expresion", Actor = "Spencer", Expresion = "Feliz" },
		{ T = en("postit11", 1.85), Accion = "Texto", Texto = "¡DE FRACASO A INVENTO MILLONARIO!", Estilo = "Titulo", Duracion = FIN - en("postit11", 1.85), Posicion = Vector2.new(0.5, 0.22) },

		{ T = FIN, Accion = "Esperar", Tiempo = 0 },
	},
}
