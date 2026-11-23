--[[
	PRUEBA_PLANTILLA · Escena técnica de prueba (no es una historia)
	Studio: ReplicatedStorage > StoryTemplate > Escenas > Prueba_Plantilla

	Recorre todos los recursos de la plantilla para comprobar que funcionan:
	los 3 personajes, los 4 entornos, todas las animaciones y gestos,
	todos los planos de cámara, y entregar / recoger objetos.
	Dura aproximadamente 1 minuto. Mira la ventana Output por si hay avisos.
]]

return {
	Entorno = "Calle",
	Reparto = {
		Protagonista = "Protagonista",
		Secundario1 = "Secundario1",
		Secundario2 = "Secundario2",
	},
	Posiciones = {
		Secundario1 = { Marca = "Pos_B", MirarA = "Camara" },
	},
	Objetos = {
		Caja = "Obj_2",
	},
	Camara = { Plano = "Fija", Marca = "Cam_General" },

	Pasos = {
		-- 1 · CALLE: entrada caminando, plano fijo
		{ Accion = "Caminar", Actor = "Protagonista", Desde = "Entrada_Izq", Hasta = "Pos_A", MirarA = "Secundario1" },

		-- 2 · Conversación: dos personajes, mirar, saludar, hablar
		{ Accion = "Camara", Plano = "DosPersonajes", Actores = { "Protagonista", "Secundario1" }, Transicion = 1 },
		{ Accion = "Mirar", Actor = "Secundario1", A = "Protagonista" },
		{ Accion = "Animacion", Actor = "Secundario1", Clip = "Saludar", Paralelo = true },
		{ Accion = "Hablar", Actor = "Protagonista", Duracion = 2.5 },
		{ Accion = "Camara", Plano = "PrimerPlano", Actor = "Secundario1" },
		{ Accion = "Hablar", Actor = "Secundario1", Duracion = 2 },
		{ Accion = "Gesto", Actor = "Secundario1", Gesto = "Asentir" },

		-- 3 · Señalar y recoger un objeto
		{ Accion = "Camara", Plano = "Medio", Transicion = 0.6 },
		{ Accion = "Senalar", Actor = "Protagonista", A = "Caja" },
		{ Accion = "Camara", Plano = "Personaje", Actor = "Protagonista", Encuadre = "Cuerpo", Seguir = true },
		{ Accion = "Caminar", Actor = "Protagonista", Hasta = "Caja" },
		{ Accion = "Recoger", Actor = "Protagonista", Objeto = "Caja" },

		-- 4 · Entregar el objeto
		{ Accion = "Caminar", Actor = "Protagonista", Hasta = "Secundario1", Distancia = 2.6 },
		{ Accion = "Camara", Plano = "DosPersonajes", Transicion = 0.8 },
		{ Accion = "Entregar", De = "Protagonista", A = "Secundario1" },

		-- 5 · Sorpresa en primer plano con zoom lento
		{ Accion = "Camara", Plano = "PrimerPlano", Actor = "Secundario1", Acercar = 1.5, TiempoAcercar = 2 },
		{ Accion = "Mirar", Actor = "Secundario1", A = "Camara" },
		{ Accion = "Sorpresa", Actor = "Secundario1" },

		-- 6 · Tercer personaje entra corriendo, la cámara le sigue
		{ Accion = "Colocar", Actor = "Secundario2", En = "Entrada_Der" },
		{ Accion = "Camara", Plano = "Personaje", Actor = "Secundario2", Encuadre = "Cuerpo", Seguir = true },
		{ Accion = "Correr", Actor = "Secundario2", Hasta = "Pos_C", MirarA = "Camara" },
		{ Accion = "Camara", Plano = "General", Transicion = 1 },
		{ Accion = "Gesto", Actor = "Secundario2", Gesto = "Negar" },
		{ Accion = "Gesto", Actor = "Protagonista", Gesto = "Pensar" },

		-- 7 · Recorrido por los demás entornos con los puntos de cámara fijos
		{ Accion = "Entorno", Nombre = "Habitacion" },
		{ Accion = "Colocar", Actor = "Protagonista", En = "Pos_A", MirarA = "Camara" },
		{ Accion = "Colocar", Actor = "Secundario1", En = "Pos_B", MirarA = "Camara" },
		{ Accion = "Colocar", Actor = "Secundario2", En = "Pos_C", MirarA = "Camara" },
		{ Accion = "Camara", Plano = "Fija", Marca = "Cam_General" },
		{ Accion = "Soltar", Actor = "Secundario1", En = "Obj_1" },
		{ Accion = "Camara", Plano = "Fija", Marca = "Cam_Izquierda", Transicion = 1.5, Pausa = 2 },
		{ Accion = "Camara", Plano = "Fija", Marca = "Cam_Derecha", Transicion = 1.5, Pausa = 2 },
		{ Accion = "Camara", Plano = "Fija", Marca = "Cam_Alta", Transicion = 1.5, Pausa = 2 },
		{ Accion = "Esperar", Tiempo = 1.5 },

		{ Accion = "Entorno", Nombre = "Exterior" },
		{ Accion = "Colocar", Actor = "Protagonista", En = "Pos_A", MirarA = "Camara" },
		{ Accion = "Colocar", Actor = "Secundario1", En = "Pos_B", MirarA = "Camara" },
		{ Accion = "Ocultar", Actor = "Secundario2" },
		{ Accion = "Camara", Plano = "General" },
		{ Accion = "Animacion", Actor = "Protagonista", Clip = "Celebrar", Paralelo = true },
		{ Accion = "Correr", Actor = "Secundario1", Hasta = "Pos_D" },
		{ Accion = "Esperar", Tiempo = 1 },

		{ Accion = "Entorno", Nombre = "Neutro" },
		{ Accion = "Colocar", Actor = "Protagonista", En = "Pos_A" },
		{ Accion = "Colocar", Actor = "Secundario1", En = "Pos_B" },
		{ Accion = "Camara", Plano = "DosPersonajes" },
		{ Accion = "Hablar", Actor = "Protagonista", Duracion = 2, Paralelo = true },
		{ Accion = "Mirar", Actor = "Secundario1", A = "Protagonista", SoloCabeza = true },
		{ Accion = "Camara", Plano = "Fija", Marca = "Cam_General", Transicion = 2 },
		{ Accion = "Esperar", Tiempo = 2.5 },
	},
}
