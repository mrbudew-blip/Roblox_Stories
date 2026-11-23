--[[
	PLANTILLA DE ESCENA · Copia este ModuleScript para crear una escena nueva
	Studio: ReplicatedStorage > StoryTemplate > Escenas > _PlantillaEscena

	1. Duplica este ModuleScript (Ctrl+D) y renómbralo (p. ej. "Historia01_Escena1").
	2. Rellena los apartados de abajo.
	3. En StoryTemplate > Config pon  Config.EscenaActiva = "Historia01_Escena1"
	4. Pulsa Play (F5).

	REGLA DE TIEMPO: cada paso espera a que termine su acción (caminar, gesto,
	sonido...) antes de pasar al siguiente. Añade  Paralelo = true  para que
	el siguiente paso empiece a la vez, y  Pausa = segundos  para esperar más.

	ACCIONES DISPONIBLES (ejemplos completos en README.md)
	  Esperar    { Accion = "Esperar", Tiempo = 1 }
	  Colocar    { Accion = "Colocar", Actor = "Protagonista", En = "Pos_A", MirarA = "Camara" }
	  Ocultar    { Accion = "Ocultar", Actor = "Secundario1" }
	  Caminar    { Accion = "Caminar", Actor = "Protagonista", Hasta = "Pos_B", Desde = "Entrada_Izq", MirarA = "Secundario1" }
	  Correr     { Accion = "Correr",  Actor = "Protagonista", Hasta = "Secundario1", Distancia = 3 }
	  Mirar      { Accion = "Mirar", Actor = "Protagonista", A = "Secundario1", SoloCabeza = false }
	  Hablar     { Accion = "Hablar", Actor = "Protagonista", Duracion = 3 }   (o Sonido = "Voz1")
	  Senalar    { Accion = "Senalar", Actor = "Protagonista", A = "Obj_1" }
	  Sorpresa   { Accion = "Sorpresa", Actor = "Secundario1" }
	  Gesto      { Accion = "Gesto", Actor = "Protagonista", Gesto = "Pensar", Duracion = 2, Mantener = false }
	  Animacion  { Accion = "Animacion", Actor = "Protagonista", Clip = "Saludar" }
	  Entregar   { Accion = "Entregar", De = "Protagonista", A = "Secundario1", Objeto = "Caja" }
	  Recoger    { Accion = "Recoger", Actor = "Protagonista", Objeto = "Caja" }
	  Soltar     { Accion = "Soltar", Actor = "Protagonista", En = "Obj_1" }
	  Objeto     { Accion = "Objeto", Objeto = "Caja", En = "Obj_2" }  /  EnManoDe = "Rol"  /  Visible = false
	  Camara     { Accion = "Camara", Plano = "DosPersonajes", Actores = {"Protagonista","Secundario1"}, Transicion = 1 }
	  Sonido     { Accion = "Sonido", Sonido = "Narracion", Volumen = 1, Paralelo = true }
	  Musica     { Accion = "Musica", Sonido = "Musica", Volumen = 0.3 }   /  Parar = true
	  Entorno    { Accion = "Entorno", Nombre = "Habitacion" }
]]

return {
	-- Escenario inicial: "Calle", "Habitacion", "Exterior", "Neutro" (o uno tuyo)
	Entorno = "Neutro",

	-- ROL = MODELO. Los pasos usan el rol; el modelo sale de StoryTemplate > Personajes.
	-- Para cambiar quién hace de protagonista basta con cambiar el modelo aquí.
	Reparto = {
		Protagonista = "Protagonista",
		Secundario1 = "Secundario1",
		Secundario2 = "Secundario2",
	},

	-- Dónde está cada rol al empezar. Los que no aparezcan aquí no se ven
	-- hasta que un paso los coloque (Colocar o Caminar con Desde).
	Posiciones = {
		Protagonista = "Pos_A",
		Secundario1 = { Marca = "Pos_B", MirarA = "Protagonista" },
	},

	-- Objetos al empezar:  Nombre = "Marca"  o  Nombre = { Modelo = "Caja", En = "Obj_1" }
	--                      o  Nombre = { EnManoDe = "Protagonista" }
	Objetos = {
		-- Caja = "Obj_1",
	},

	-- Música de fondo (Sound de StoryTemplate > Audio o id numérico)
	-- Musica = { Sonido = "Musica", Volumen = 0.3 },

	-- Plano inicial
	Camara = { Plano = "DosPersonajes" },

	Pasos = {
		{ Accion = "Hablar", Actor = "Protagonista", Duracion = 2 },
		{ Accion = "Camara", Plano = "PrimerPlano", Actor = "Secundario1" },
		{ Accion = "Hablar", Actor = "Secundario1", Duracion = 2 },
		{ Accion = "Esperar", Tiempo = 1 },
	},
}
