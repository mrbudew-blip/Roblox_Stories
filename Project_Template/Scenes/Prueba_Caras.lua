--[[
	PRUEBA_CARAS · Escena técnica de prueba de caras (no es una historia)
	Studio: ReplicatedStorage > StoryTemplate > Escenas > Prueba_Caras

	Los 3 personajes, uno al lado del otro y mirando a cámara, quietos.
	Parpadean solos todo el rato y van hablando por turnos (solo la boca,
	sin gestos de brazos). Al final hablan los tres a la vez.

	Para verla: en StoryTemplate > Config pon  Config.EscenaActiva = "Prueba_Caras"
]]

return {
	Entorno = "Neutro",
	Reparto = {
		Protagonista = "Protagonista",
		Secundario1 = "Secundario1",
		Secundario2 = "Secundario2",
	},
	Posiciones = {
		Protagonista = { En = Vector3.new(-2.4, 0, 0), MirarA = "Camara" },
		Secundario1 = { En = Vector3.new(0, 0, -0.5), MirarA = "Camara" },
		Secundario2 = { En = Vector3.new(2.4, 0, 0), MirarA = "Camara" },
	},
	Camara = { Plano = "Medio", Encuadre = "Cara", Inclinacion = 0 },

	Pasos = {
		-- Los tres quietos, solo parpadean
		{ Accion = "Esperar", Tiempo = 3 },

		-- Habla cada uno en su primer plano
		{ Accion = "Camara", Plano = "PrimerPlano", Actor = "Protagonista", Angulo = 0 },
		{ Accion = "Hablar", Actor = "Protagonista", Duracion = 3, SoloBoca = true },
		{ Accion = "Esperar", Tiempo = 1.5 },

		{ Accion = "Camara", Plano = "PrimerPlano", Actor = "Secundario1", Angulo = 0 },
		{ Accion = "Hablar", Actor = "Secundario1", Duracion = 3, SoloBoca = true },
		{ Accion = "Esperar", Tiempo = 1.5 },

		{ Accion = "Camara", Plano = "PrimerPlano", Actor = "Secundario2", Angulo = 0 },
		{ Accion = "Hablar", Actor = "Secundario2", Duracion = 3, SoloBoca = true },
		{ Accion = "Esperar", Tiempo = 1.5 },

		-- Los tres juntos, por turnos y luego a la vez
		{ Accion = "Camara", Plano = "Medio", Encuadre = "Cara", Inclinacion = 0, Transicion = 1 },
		{ Accion = "Hablar", Actor = "Protagonista", Duracion = 1.5, SoloBoca = true },
		{ Accion = "Hablar", Actor = "Secundario1", Duracion = 1.5, SoloBoca = true },
		{ Accion = "Hablar", Actor = "Secundario2", Duracion = 1.5, SoloBoca = true },
		{ Accion = "Hablar", Actor = "Protagonista", Duracion = 3, SoloBoca = true, Paralelo = true },
		{ Accion = "Hablar", Actor = "Secundario1", Duracion = 3, SoloBoca = true, Paralelo = true },
		{ Accion = "Hablar", Actor = "Secundario2", Duracion = 3, SoloBoca = true },
		{ Accion = "Esperar", Tiempo = 3 },
	},
}
