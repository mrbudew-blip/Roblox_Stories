--[[
	ANIMACIONES · Biblioteca de animaciones reutilizables
	Studio: ReplicatedStorage > StoryTemplate > Modulos > Animaciones

	Hay tres tipos:

	1) Base   → animaciones en bucle del cuerpo entero (quieto, caminar, correr).
	            Son las animaciones oficiales de Roblox para R15: no hay que subir nada.

	2) Clips  → animaciones de catálogo que se reproducen una vez (acción "Animacion").
	            Puedes añadir tus propias animaciones subidas: Nombre = "rbxassetid://ID".

	3) Gestos → posturas "procedurales": giran articulaciones del personaje encima de la
	            animación base. No necesitan subir nada y cuestan casi cero recursos.
	            Cada gesto es una lista de Fotogramas; cada fotograma indica, para cada
	            articulación R15, una rotación {X, Y, Z} en grados.

	            Articulaciones disponibles:
	              Neck (cuello), Waist (cintura),
	              RightShoulder, RightElbow, RightWrist (brazo derecho),
	              LeftShoulder,  LeftElbow,  LeftWrist  (brazo izquierdo)

	            Guía rápida de ejes:
	              Shoulder X+  → levanta el brazo hacia delante
	              RightShoulder Z+ / LeftShoulder Z-  → abre el brazo hacia el lado
	              Elbow X+     → dobla el codo hacia delante
	              Neck X+ / X- → mira arriba / abajo     Neck Y+ → gira la cabeza a su izquierda
	              Waist X+ / X- → inclina el torso atrás / adelante

	            Opciones de cada gesto:
	              Transicion = segundos para pasar de un fotograma al siguiente
	              Pausa      = segundos que se mantiene cada fotograma (solo en bucles)
	              Bucle      = true → alterna los fotogramas hasta que acaba la duración
	              Duracion   = duración por defecto si el paso no indica una
]]

local Animaciones = {}

-- 1) BASE ----------------------------------------------------------------------
-- VelocidadReferencia = studs/s a la que la animación se ve natural (ajusta los pies).
Animaciones.Base = {
	Quieto = { Id = "rbxassetid://507766388" },
	Caminar = { Id = "rbxassetid://507777826", VelocidadReferencia = 8 },
	Correr = { Id = "rbxassetid://507767714", VelocidadReferencia = 16 },
}

-- 2) CLIPS ---------------------------------------------------------------------
Animaciones.Clips = {
	Saludar = "rbxassetid://507770239",
	Reir = "rbxassetid://507770818",
	Celebrar = "rbxassetid://507770677",
}

-- 3) GESTOS --------------------------------------------------------------------
Animaciones.Gestos = {
	-- Gestos de manos al hablar (bucle)
	Hablar = {
		Bucle = true,
		Transicion = 0.35,
		Pausa = 0.05,
		Duracion = 2,
		Fotogramas = {
			{ RightShoulder = { 25, 0, 6 }, RightElbow = { 60, 0, 0 }, Neck = { 4, 0, 0 } },
			{
				RightShoulder = { 32, 0, 14 },
				RightElbow = { 45, 0, 0 },
				LeftShoulder = { 18, 0, -6 },
				LeftElbow = { 35, 0, 0 },
				Neck = { -3, 4, 0 },
			},
		},
	},

	-- Brazo derecho extendido señalando al frente
	Senalar = {
		Transicion = 0.25,
		Duracion = 1.5,
		Fotogramas = {
			{ RightShoulder = { 90, 0, 0 }, RightElbow = { 5, 0, 0 }, RightWrist = { 0, 0, 0 } },
		},
	},

	-- Manos arriba, cabeza y torso hacia atrás
	Sorpresa = {
		Transicion = 0.15,
		Duracion = 1.2,
		Fotogramas = {
			{
				RightShoulder = { 10, 0, 95 },
				LeftShoulder = { 10, 0, -95 },
				RightElbow = { 60, 0, 0 },
				LeftElbow = { 60, 0, 0 },
				Neck = { 15, 0, 0 },
				Waist = { 8, 0, 0 },
			},
		},
	},

	-- Extiende el brazo para dar algo
	Entregar = {
		Transicion = 0.35,
		Duracion = 1,
		Fotogramas = {
			{ RightShoulder = { 70, 0, 0 }, RightElbow = { 15, 0, 0 }, Waist = { -5, 0, 0 } },
		},
	},

	-- Extiende el brazo para recibir algo
	Recibir = {
		Transicion = 0.35,
		Duracion = 0.8,
		Fotogramas = {
			{ RightShoulder = { 60, 0, 0 }, RightElbow = { 20, 0, 0 }, LeftShoulder = { 30, 0, 0 } },
		},
	},

	-- Se inclina para coger o dejar algo del suelo / mesa
	Agacharse = {
		Transicion = 0.35,
		Duracion = 0.8,
		Fotogramas = {
			{
				Waist = { -25, 0, 0 },
				Neck = { -15, 0, 0 },
				RightShoulder = { 50, 0, 0 },
				RightElbow = { 20, 0, 0 },
			},
		},
	},

	-- Postura de reposo mientras lleva un objeto (se aplica sola)
	Sostener = {
		Transicion = 0.3,
		Fotogramas = {
			{ RightShoulder = { 30, 0, 0 }, RightElbow = { 60, 0, 0 } },
		},
	},

	-- Asentir con la cabeza (sí)
	Asentir = {
		Bucle = true,
		Transicion = 0.18,
		Duracion = 1.2,
		Fotogramas = {
			{ Neck = { -14, 0, 0 } },
			{ Neck = { 6, 0, 0 } },
		},
	},

	-- Negar con la cabeza (no)
	Negar = {
		Bucle = true,
		Transicion = 0.18,
		Duracion = 1.2,
		Fotogramas = {
			{ Neck = { 0, 22, 0 } },
			{ Neck = { 0, -22, 0 } },
		},
	},

	-- Mano a la barbilla, pensando
	Pensar = {
		Transicion = 0.4,
		Duracion = 2,
		Fotogramas = {
			{ RightShoulder = { 40, 0, -10 }, RightElbow = { 125, 0, 0 }, Neck = { 8, 10, 0 } },
		},
	},
}

return Animaciones
