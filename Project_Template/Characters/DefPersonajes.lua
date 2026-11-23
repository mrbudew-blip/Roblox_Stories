--[[
	DEFPERSONAJES · Aspecto de los personajes reutilizables
	Studio: ReplicatedStorage > StoryTemplate > Modulos > DefPersonajes

	Cada entrada crea un Model R15 de estilo clásico (cuerpo de bloques, colores
	planos) en StoryTemplate > Personajes. Los nombres de aquí son los nombres
	de los modelos; en cada escena se asignan a ROLES con la tabla "Reparto".

	Campos (todos opcionales):
	  Piel, Camiseta, Brazos, Pantalon → Color3 de cada parte del cuerpo
	                                     (Brazos = Piel si no se indica: manga corta)
	  Altura, Anchura, Cabeza          → escalas (1 = normal)
	  Cara                             → id de cara del catálogo (número)
	  Pelo, Sombrero, Gafas            → ids de accesorios del catálogo ("id1,id2")
	  Camisa, Pantalones, Estampado    → ids de ropa clásica del catálogo (número)

	Para añadir un personaje: copia una entrada, cambia el nombre y los colores,
	y reconstruye (ver README, "Añadir un personaje").
]]

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

return {
	Protagonista = {
		Piel = rgb(234, 184, 146),
		Camiseta = rgb(13, 105, 172), -- azul
		Pantalon = rgb(40, 50, 70),
	},

	Secundario1 = {
		Piel = rgb(124, 92, 70),
		Camiseta = rgb(196, 40, 28), -- rojo
		Pantalon = rgb(27, 42, 53),
	},

	Secundario2 = {
		Piel = rgb(255, 204, 153),
		Camiseta = rgb(75, 151, 75), -- verde
		Brazos = rgb(75, 151, 75), -- manga larga
		Pantalon = rgb(105, 64, 40),
		Altura = 0.95,
	},
}
