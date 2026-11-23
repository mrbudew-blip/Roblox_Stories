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
	-- Brazo estirado hacia delante y arriba: pegar o despegar algo de una pared
	Pegar = {
		Transicion = 0.3,
		Duracion = 0.9,
		Fotogramas = {
			{ RightShoulder = { 105, 0, 0 }, RightElbow = { 10, 0, 0 }, Neck = { 8, 0, 0 } },
		},
	},

	-- Alcanzar algo de una mesa (de pie o sentado)
	AlcanzarMesa = {
		Transicion = 0.3,
		Duracion = 0.8,
		Fotogramas = {
			{ RightShoulder = { 55, 0, 0 }, RightElbow = { 25, 0, 0 }, Waist = { -12, 0, 0 }, Neck = { -15, 0, 0 } },
		},
	},

	-- Enseñar un objeto que lleva en la mano (a la altura de la cara)
	Mostrar = {
		Transicion = 0.3,
		Duracion = 1.5,
		Fotogramas = {
			{ RightShoulder = { 80, 0, 12 }, RightElbow = { 70, 0, 0 }, Neck = { -4, 0, 0 } },
		},
	},

	-- Mirar con atención algo que tiene en la mano
	Examinar = {
		Transicion = 0.35,
		Duracion = 1.5,
		Fotogramas = {
			{ RightShoulder = { 65, 0, -8 }, RightElbow = { 85, 0, 0 }, Neck = { -10, 0, 8 } },
		},
	},

	-- ¡Idea! Dedo índice arriba junto a la cara
	Idea = {
		Transicion = 0.18,
		Duracion = 1.4,
		Fotogramas = {
			{ RightShoulder = { 70, 0, 20 }, RightElbow = { 100, 0, 0 }, Neck = { 10, 0, 0 }, Waist = { 4, 0, 0 } },
		},
	},

	-- Encogerse de hombros, palmas hacia arriba
	Encogerse = {
		Transicion = 0.25,
		Duracion = 1,
		Fotogramas = {
			{
				RightShoulder = { 20, 0, 35 },
				LeftShoulder = { 20, 0, -35 },
				RightElbow = { 80, 0, 0 },
				LeftElbow = { 80, 0, 0 },
				Neck = { 0, 0, 8 },
			},
		},
	},

	-- Cabeza y torso hacia abajo (mirar al suelo)
	MirarAbajo = {
		Transicion = 0.35,
		Duracion = 1.2,
		Fotogramas = {
			{ Neck = { -30, 0, 0 }, Waist = { -10, 0, 0 } },
		},
	},

	-- Lamentarse: mano izquierda a la frente, cabeza baja
	Lamentarse = {
		Transicion = 0.3,
		Duracion = 1.2,
		Fotogramas = {
			{ LeftShoulder = { 100, 0, -15 }, LeftElbow = { 115, 0, 0 }, Neck = { -18, 0, 0 } },
		},
	},

	-- Celebrar con el brazo derecho en alto
	BrazoArriba = {
		Transicion = 0.22,
		Duracion = 1.2,
		Fotogramas = {
			{ RightShoulder = { 160, 0, 10 }, RightElbow = { 10, 0, 0 }, Neck = { 8, 0, 0 } },
		},
	},

	-- Untar pegamento con un pincel (bucle)
	Untar = {
		Bucle = true,
		Transicion = 0.22,
		Duracion = 2,
		Fotogramas = {
			{ RightShoulder = { 50, 0, -5 }, RightElbow = { 40, 0, 0 }, Waist = { -10, 0, 0 }, Neck = { -18, 0, 0 } },
			{ RightShoulder = { 45, 0, 12 }, RightElbow = { 52, 0, 0 }, Waist = { -10, 0, 0 }, Neck = { -18, 0, 0 } },
		},
	},
}

-- 4) POSTURAS DE PIERNAS --------------------------------------------------------
-- Se mantienen debajo de cualquier gesto (acción "Sentar" / "Levantar").
-- Articulaciones: RightHip, LeftHip (X+ = muslo hacia delante), RightKnee, LeftKnee (X- = dobla la rodilla).
Animaciones.Piernas = {
	Sentado = {
		RightHip = { 90, 0, 0 },
		LeftHip = { 90, 0, 0 },
		RightKnee = { -90, 0, 0 },
		LeftKnee = { -90, 0, 0 },
	},
}

return Animaciones
