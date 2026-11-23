--[[
	DEFPERSONAJES · Aspecto y personalidad de los personajes reutilizables
	Studio: ReplicatedStorage > StoryTemplate > Modulos > DefPersonajes

	Cada entrada crea un Model R15 de estilo clásico en StoryTemplate > Personajes.
	En cada escena se asignan a ROLES con la tabla "Reparto".
	Las piezas disponibles (caras, pelo, prendas, accesorios) están en Modulos > Atuendos.

	Campos:
	  Personalidad → texto de referencia (se guarda como atributo del Model)
	  Piel         → Color3 del tono de piel
	  Cuerpo       → { Altura, Anchura, Profundidad, Cabeza }  (1 = normal)
	  Cara         → nombre de Atuendos.Caras, tabla { Ojos, Cejas, Boca, Mejillas, Pecas }
	                 o id numérico de una cara del catálogo
	  Pelo         → { Estilo = "Corto" | "Despeinado" | "Rapado" | "Ninguno", Color }
	  Superior     → { Prenda = "Camiseta" | "MangaLarga" | "Sudadera" | "Polo" | "Tirantes"
	                            | "Chaqueta" | "CamisetaRayas", Color, ColorDetalle }
	  Inferior     → { Prenda = "Pantalon" | "Corto", Color }
	  Calzado      → Color3
	  Accesorios   → lista de { Tipo = "Gorra" | "GorraAtras" | "Gafas" | "Barba" | "Cinturon"
	                                  | "Barriga" | "Mochila", Color }

	Las prendas son básicas a propósito (sudadera, camiseta, pantalón largo, gorra)
	para que sirvan en casi cualquier historia: casa, calle, colegio, trabajo...
	Para un atuendo especial (pijama, uniforme...) crea una variante con otro nombre,
	p. ej. "Protagonista_Pijama", copiando la entrada y cambiando solo la ropa.
]]

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

return {
	-- Flaco, piel clara. Curioso, algo tímido y nervioso: el chico corriente
	-- al que le pasan las cosas. Sudadera con capucha, vaqueros y zapatillas.
	Protagonista = {
		Personalidad = "Curioso, tímido y algo nervioso",
		Piel = rgb(245, 218, 196),
		Cuerpo = { Altura = 1.02, Anchura = 0.72, Profundidad = 0.75, Cabeza = 1 },
		Cara = "Timido",
		Pelo = { Estilo = "Despeinado", Color = rgb(96, 62, 38) },
		Superior = { Prenda = "Sudadera", Color = rgb(52, 98, 170) },
		Inferior = { Prenda = "Pantalon", Color = rgb(44, 56, 80) },
		Calzado = rgb(235, 235, 235),
	},

	-- Alto y fuerte, piel negra. Seguro de sí mismo, tranquilo y protector:
	-- el amigo fiable. Camiseta blanca, pantalón gris oscuro, cinturón y barba corta.
	Secundario1 = {
		Personalidad = "Seguro, tranquilo y protector",
		Piel = rgb(92, 60, 44),
		Cuerpo = { Altura = 1.15, Anchura = 1.2, Profundidad = 1.1, Cabeza = 1 },
		Cara = "Seguro",
		Pelo = { Estilo = "Rapado", Color = rgb(25, 20, 20) },
		Superior = { Prenda = "Camiseta", Color = rgb(242, 242, 238) },
		Inferior = { Prenda = "Pantalon", Color = rgb(58, 58, 64) },
		Calzado = rgb(85, 58, 40),
		Accesorios = {
			{ Tipo = "Barba", Color = rgb(25, 20, 20) },
			{ Tipo = "Cinturon", Color = rgb(70, 45, 30) },
		},
	},

	-- Pequeño y gordito, piel amarilla clásica de Roblox. Alegre, glotón y
	-- gracioso: el que alivia la tensión. Camiseta de rayas, pantalón caqui y gorra.
	Secundario2 = {
		Personalidad = "Alegre, glotón y gracioso",
		Piel = rgb(245, 205, 48),
		Cuerpo = { Altura = 0.85, Anchura = 1.25, Profundidad = 1.35, Cabeza = 1.08 },
		Cara = "Alegre",
		Pelo = { Estilo = "Ninguno" },
		Superior = { Prenda = "CamisetaRayas", Color = rgb(70, 150, 210), ColorDetalle = rgb(245, 245, 245) },
		Inferior = { Prenda = "Pantalon", Color = rgb(180, 150, 105) },
		Calzado = rgb(190, 40, 40),
		Accesorios = {
			{ Tipo = "GorraAtras", Color = rgb(196, 40, 28) },
			{ Tipo = "Barriga" },
		},
	},
}
