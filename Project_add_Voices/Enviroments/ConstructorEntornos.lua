--[[
	CONSTRUCTORENTORNOS · Genera los escenarios básicos
	Studio: ReplicatedStorage > StoryTemplate > Herramientas > ConstructorEntornos

	Solo se usa al instalar (o para regenerar un escenario). En tiempo de
	ejecución el Director clona el entorno ya construido.

	Convención de todos los entornos:
	  · El suelo donde actúan los personajes está a Y = 0, alrededor de (0, 0, 0).
	  · La cámara/público está hacia +Z y los personajes miran hacia +Z.
	  · Todo es Part con SmoothPlastic: sin texturas, sin luces, sin colisiones.

	Carpeta "Marcas" de cada entorno (se vuelven invisibles al reproducir):
	  Pos_A, Pos_B, Pos_C, Pos_D → posiciones de personajes (cara FRENTE = hacia dónde miran)
	  Entrada_Izq, Entrada_Der    → puntos de entrada/salida de escena
	  Obj_1, Obj_2                → posiciones de objetos
	  Cam_General, Cam_Izquierda, Cam_Derecha, Cam_Alta → puntos de cámara fijos
	  Audiencia                   → desde dónde "mira el público" (orienta los planos automáticos)

	Atributos del Model (iluminación que se aplica al cargarlo):
	  Hora (ClockTime), Brillo (Brightness), Ambiente (Color3), AmbienteExterior (Color3)
]]

local Constructor = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local COLOR_MARCA = {
	Pos = rgb(60, 200, 90),
	Entrada = rgb(240, 190, 40),
	Obj = rgb(255, 130, 40),
	Cam = rgb(30, 30, 30),
	Audiencia = rgb(160, 80, 220),
}

local function parte(padre, nombre, tam, cf, color, op)
	op = op or {}
	local p = Instance.new("Part")
	p.Name = nombre
	p.Shape = op.Forma or Enum.PartType.Block
	p.Size = tam
	p.CFrame = cf
	p.Color = color
	p.Material = op.Material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = op.Sombra ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = padre
	return p
end

-- Bloque centrado en "centro"
local function bloque(padre, nombre, tam, centro, color, op)
	return parte(padre, nombre, tam, CFrame.new(centro), color, op)
end

-- Bloque apoyado: su base está a la altura yBase
local function caja(padre, nombre, tam, x, yBase, z, color, op)
	return parte(padre, nombre, tam, CFrame.new(x, yBase + tam.Y / 2, z), color, op)
end

local function cilindroVertical(padre, nombre, altura, diametro, base, color, op)
	op = op or {}
	op.Forma = Enum.PartType.Cylinder
	local cf = CFrame.new(base + Vector3.new(0, altura / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	return parte(padre, nombre, Vector3.new(altura, diametro, diametro), cf, color, op)
end

local function etiqueta(p, texto, color)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Etiqueta"
	bb.Size = UDim2.fromOffset(110, 20)
	bb.StudsOffset = Vector3.new(0, 1.3, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 150
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = color
	t.BackgroundTransparency = 0.25
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.Text = texto
	t.Parent = bb
	bb.Parent = p
end

--[[
	Crea una marca.
	  Pos/Entrada/Obj : "pos" es el punto del suelo; "mirar" la dirección a la que mira.
	  Cam             : "pos" es la posición de la cámara; "mirar" el punto al que apunta.
	  Audiencia       : solo "pos".
]]
local function marca(carpeta, nombre, pos, mirar)
	local tipo = nombre:match("^(%a+)")
	local color = COLOR_MARCA[tipo] or rgb(255, 255, 255)
	local p
	if tipo == "Cam" then
		p = parte(carpeta, nombre, Vector3.new(0.8, 0.8, 1.6), CFrame.lookAt(pos, mirar), color, { Sombra = false })
	elseif tipo == "Audiencia" then
		p = parte(carpeta, nombre, Vector3.new(1, 1, 1), CFrame.new(pos), color, { Forma = Enum.PartType.Ball, Sombra = false })
	else
		local tam = (tipo == "Obj") and Vector3.new(1, 0.2, 1) or Vector3.new(2, 0.4, 2)
		local centro = pos + Vector3.new(0, tam.Y / 2, 0)
		local dir = mirar or Vector3.new(0, 0, 1)
		p = parte(carpeta, nombre, tam, CFrame.lookAt(centro, centro + dir), color, { Sombra = false })
		if tipo ~= "Obj" then
			-- Indica la cara frontal (hacia donde mirará el personaje)
			local sg = Instance.new("SurfaceGui")
			sg.Name = "Frente"
			sg.Face = Enum.NormalId.Front
			sg.LightInfluence = 0
			sg.PixelsPerStud = 40
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundColor3 = Color3.new(1, 1, 1)
			t.TextColor3 = Color3.new(0, 0, 0)
			t.TextScaled = true
			t.Font = Enum.Font.GothamBold
			t.Text = "FRENTE"
			t.Parent = sg
			sg.Parent = p
		end
	end
	p.Transparency = 0.35
	etiqueta(p, nombre, color)
	return p
end

local function camarasEstandar(M, objetivo, distancia)
	marca(M, "Cam_General", objetivo + Vector3.new(0, 3, distancia), objetivo)
	marca(M, "Cam_Izquierda", objetivo + Vector3.new(-distancia * 0.55, 2, distancia * 0.7), objetivo)
	marca(M, "Cam_Derecha", objetivo + Vector3.new(distancia * 0.55, 2, distancia * 0.7), objetivo)
	marca(M, "Cam_Alta", objetivo + Vector3.new(0, distancia * 0.7, distancia * 0.6), objetivo - Vector3.new(0, 1.5, 0))
end

local function nuevoEntorno(carpeta, nombre, atributos)
	local viejo = carpeta:FindFirstChild(nombre)
	if viejo then
		viejo:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = nombre
	for k, v in pairs(atributos) do
		m:SetAttribute(k, v)
	end
	local g = Instance.new("Folder")
	g.Name = "Geometria"
	g.Parent = m
	local marcas = Instance.new("Folder")
	marcas.Name = "Marcas"
	marcas.Parent = m
	m.Parent = carpeta
	return m, g, marcas
end

-- Elementos reutilizables ------------------------------------------------------

local function arbol(g, base, escala)
	escala = escala or 1
	cilindroVertical(g, "Tronco", 6 * escala, 1 * escala, base, rgb(110, 80, 50))
	parte(
		g,
		"Copa",
		Vector3.new(7, 7, 7) * escala,
		CFrame.new(base + Vector3.new(0, 7.5 * escala, 0)),
		rgb(70, 140, 60),
		{ Forma = Enum.PartType.Ball }
	)
end

-- Banco mirando hacia +Z. Devuelve la altura del asiento.
local function banco(g, base, color)
	local gris = rgb(60, 60, 60)
	caja(g, "BancoPata", Vector3.new(0.4, 1.4, 1.4), base.X - 2, base.Y, base.Z, gris)
	caja(g, "BancoPata", Vector3.new(0.4, 1.4, 1.4), base.X + 2, base.Y, base.Z, gris)
	caja(g, "BancoAsiento", Vector3.new(5, 0.4, 1.6), base.X, base.Y + 1.4, base.Z, color)
	caja(g, "BancoRespaldo", Vector3.new(5, 1.6, 0.3), base.X, base.Y + 1.8, base.Z - 0.75, color)
	return base.Y + 1.8
end

-- ENTORNOS ---------------------------------------------------------------------

function Constructor.Calle(carpeta)
	local _, g, M = nuevoEntorno(carpeta, "Calle", { Hora = 15, Brillo = 2 })
	local acera = rgb(190, 190, 185)

	bloque(g, "Acera", Vector3.new(90, 1, 10), Vector3.new(0, -0.5, -1), acera, { Sombra = false })
	bloque(g, "Carretera", Vector3.new(90, 1, 14), Vector3.new(0, -0.8, 11), rgb(60, 60, 65), { Sombra = false })
	bloque(g, "AceraFrontal", Vector3.new(90, 1, 8), Vector3.new(0, -0.5, 22), acera, { Sombra = false })
	for i = -4, 4 do
		bloque(g, "Linea", Vector3.new(4, 0.05, 0.4), Vector3.new(i * 10, -0.275, 11), rgb(240, 240, 240), { Sombra = false })
	end

	local edificios = {
		{ -33, 12, 18, rgb(150, 95, 80) },
		{ -20, 14, 24, rgb(178, 107, 82) },
		{ -7, 12, 16, rgb(226, 203, 160) },
		{ 5, 12, 28, rgb(120, 144, 156) },
		{ 18, 14, 18, rgb(196, 160, 120) },
		{ 31, 12, 22, rgb(140, 120, 150) },
	}
	for i, e in ipairs(edificios) do
		local x, ancho, alto, color = e[1], e[2], e[3], e[4]
		caja(g, "Edificio" .. i, Vector3.new(ancho, alto, 10), x, 0, -11, color)
		for y = 9, alto - 4, 6 do
			for _, dx in ipairs({ -ancho / 4, ancho / 4 }) do
				bloque(g, "Ventana", Vector3.new(2.6, 3, 0.2), Vector3.new(x + dx, y, -5.95), rgb(160, 200, 225), { Sombra = false })
			end
		end
	end
	for _, x in ipairs({ -7, 5, 18 }) do
		caja(g, "Puerta", Vector3.new(3.5, 6.5, 0.3), x, 0, -5.9, rgb(95, 65, 45), { Sombra = false })
	end

	for _, x in ipairs({ -12, 12 }) do
		cilindroVertical(g, "Farola", 11, 0.4, Vector3.new(x, 0, 3), rgb(50, 50, 55))
		bloque(g, "FarolaLuz", Vector3.new(1.4, 0.6, 1.4), Vector3.new(x, 11.2, 3), rgb(255, 235, 170), {
			Material = Enum.Material.Neon,
			Sombra = false,
		})
	end
	arbol(g, Vector3.new(-25, 0, 1.5), 1)
	local asiento = banco(g, Vector3.new(14, 0, -4), rgb(120, 85, 55))

	local frente = Vector3.new(0, 0, 1)
	marca(M, "Pos_A", Vector3.new(-2, 0, 0), frente)
	marca(M, "Pos_B", Vector3.new(2, 0, 0), frente)
	marca(M, "Pos_C", Vector3.new(0, 0, -3), frente)
	marca(M, "Pos_D", Vector3.new(-7, 0, -2), frente)
	marca(M, "Entrada_Izq", Vector3.new(-22, 0, 0), Vector3.new(1, 0, 0))
	marca(M, "Entrada_Der", Vector3.new(22, 0, 0), Vector3.new(-1, 0, 0))
	marca(M, "Obj_1", Vector3.new(15.2, asiento, -4), frente)
	marca(M, "Obj_2", Vector3.new(-5, 0, 1.5), frente)
	camarasEstandar(M, Vector3.new(0, 3, 0), 26)
	marca(M, "Audiencia", Vector3.new(0, 4, 20))
end

function Constructor.Habitacion(carpeta)
	local _, g, M = nuevoEntorno(carpeta, "Habitacion", {
		Hora = 13,
		Brillo = 2,
		Ambiente = rgb(110, 105, 100),
	})
	local pared = rgb(232, 222, 200)
	local paredLateral = rgb(220, 208, 185)
	local madera = rgb(130, 90, 55)
	local tela = rgb(70, 95, 145)

	bloque(g, "Suelo", Vector3.new(28, 1, 22), Vector3.new(0, -0.5, -2), rgb(165, 120, 80), { Sombra = false })
	bloque(g, "ParedFondo", Vector3.new(28, 14, 1), Vector3.new(0, 7, -13.5), pared)
	bloque(g, "ParedIzquierda", Vector3.new(1, 14, 22), Vector3.new(-14.5, 7, -2), paredLateral)
	bloque(g, "ParedDerecha", Vector3.new(1, 14, 22), Vector3.new(14.5, 7, -2), paredLateral)
	bloque(g, "Zocalo", Vector3.new(28, 0.8, 0.2), Vector3.new(0, 0.4, -12.95), rgb(120, 90, 60), { Sombra = false })

	bloque(g, "MarcoVentana", Vector3.new(6.4, 5.4, 0.3), Vector3.new(6, 8, -12.9), rgb(250, 250, 250))
	bloque(g, "Ventana", Vector3.new(5.6, 4.6, 0.3), Vector3.new(6, 8, -12.8), rgb(170, 210, 235), { Sombra = false })
	bloque(g, "Cuadro", Vector3.new(4, 3, 0.2), Vector3.new(-5, 8, -12.9), rgb(90, 130, 170))
	bloque(g, "Puerta", Vector3.new(0.3, 8, 4), Vector3.new(-13.9, 4, -6), rgb(120, 80, 50))
	bloque(g, "Alfombra", Vector3.new(10, 0.06, 7), Vector3.new(0, 0.03, -1), rgb(160, 70, 70), { Sombra = false })

	-- Mesa y silla
	caja(g, "MesaTablero", Vector3.new(5, 0.3, 3), -7, 2.6, -8, madera)
	for _, d in ipairs({ { -2.2, -1.2 }, { 2.2, -1.2 }, { -2.2, 1.2 }, { 2.2, 1.2 } }) do
		caja(g, "MesaPata", Vector3.new(0.3, 2.6, 0.3), -7 + d[1], 0, -8 + d[2], madera)
	end
	caja(g, "SillaBase", Vector3.new(1.6, 1.5, 1.6), -7, 0, -5.4, madera)
	caja(g, "SillaRespaldo", Vector3.new(1.6, 2.2, 0.3), -7, 1.5, -4.75, madera)

	-- Sofá
	caja(g, "SofaBase", Vector3.new(8, 1.6, 3), 6, 0, -10.5, tela)
	caja(g, "SofaRespaldo", Vector3.new(8, 2.4, 1), 6, 1.6, -11.6, tela)
	caja(g, "SofaBrazo", Vector3.new(1, 2.4, 3), 1.5, 0, -10.5, tela)
	caja(g, "SofaBrazo", Vector3.new(1, 2.4, 3), 10.5, 0, -10.5, tela)

	-- Estantería y lámpara (sin luz real)
	caja(g, "Estanteria", Vector3.new(1.2, 7, 5), 13.4, 0, 1, madera)
	cilindroVertical(g, "LamparaPie", 6, 0.3, Vector3.new(12, 0, -11), rgb(60, 60, 60))
	parte(g, "LamparaPantalla", Vector3.new(1.4, 1.8, 1.8), CFrame.new(12, 6.4, -11) * CFrame.Angles(0, 0, math.pi / 2), rgb(245, 230, 190), {
		Forma = Enum.PartType.Cylinder,
		Sombra = false,
	})

	local frente = Vector3.new(0, 0, 1)
	marca(M, "Pos_A", Vector3.new(-2, 0, 0), frente)
	marca(M, "Pos_B", Vector3.new(2, 0, 0), frente)
	marca(M, "Pos_C", Vector3.new(0, 0, -4), frente)
	marca(M, "Pos_D", Vector3.new(6, 0, -7.5), frente)
	marca(M, "Entrada_Izq", Vector3.new(-12, 0, -6), Vector3.new(1, 0, 0))
	marca(M, "Entrada_Der", Vector3.new(12, 0, 4), Vector3.new(-1, 0, 0))
	marca(M, "Obj_1", Vector3.new(-6, 2.9, -8), frente)
	marca(M, "Obj_2", Vector3.new(-3, 0, 2), frente)
	camarasEstandar(M, Vector3.new(0, 3, -2), 22)
	marca(M, "Audiencia", Vector3.new(0, 4, 16))
end

function Constructor.Exterior(carpeta)
	local _, g, M = nuevoEntorno(carpeta, "Exterior", { Hora = 11, Brillo = 2.2 })

	bloque(g, "Cesped", Vector3.new(400, 1, 400), Vector3.new(0, -0.5, -100), rgb(100, 155, 75), { Sombra = false })
	bloque(g, "Camino", Vector3.new(5, 0.05, 120), Vector3.new(0, 0.025, -40), rgb(195, 175, 135), { Sombra = false })

	local arboles = {
		{ -12, -8, 1 },
		{ -20, -22, 1.3 },
		{ 14, -10, 1.1 },
		{ 24, -26, 1.4 },
		{ -9, -40, 1.2 },
		{ 10, -48, 1.5 },
		{ -30, -6, 1.2 },
		{ 32, -4, 1 },
	}
	for _, a in ipairs(arboles) do
		arbol(g, Vector3.new(a[1], 0, a[2]), a[3])
	end
	for _, r in ipairs({ { -6, -14, 3 }, { 7, -20, 2.2 }, { -16, 3, 2.5 } }) do
		parte(g, "Roca", Vector3.new(r[3], r[3], r[3]), CFrame.new(r[1], r[3] * 0.25, r[2]), rgb(130, 130, 125), {
			Forma = Enum.PartType.Ball,
		})
	end
	local asiento = banco(g, Vector3.new(8, 0, -4), rgb(120, 85, 55))
	parte(g, "Colina", Vector3.new(120, 120, 120), CFrame.new(-90, -35, -200), rgb(85, 140, 70), {
		Forma = Enum.PartType.Ball,
		Sombra = false,
	})
	parte(g, "Colina", Vector3.new(140, 140, 140), CFrame.new(100, -40, -220), rgb(90, 145, 75), {
		Forma = Enum.PartType.Ball,
		Sombra = false,
	})

	local frente = Vector3.new(0, 0, 1)
	marca(M, "Pos_A", Vector3.new(-2, 0, 0), frente)
	marca(M, "Pos_B", Vector3.new(2, 0, 0), frente)
	marca(M, "Pos_C", Vector3.new(0, 0, -3), frente)
	marca(M, "Pos_D", Vector3.new(0, 0, -12), frente)
	marca(M, "Entrada_Izq", Vector3.new(-22, 0, 0), Vector3.new(1, 0, 0))
	marca(M, "Entrada_Der", Vector3.new(22, 0, 0), Vector3.new(-1, 0, 0))
	marca(M, "Obj_1", Vector3.new(9.2, asiento, -4), frente)
	marca(M, "Obj_2", Vector3.new(-4, 0, 2), frente)
	camarasEstandar(M, Vector3.new(0, 3, 0), 26)
	marca(M, "Audiencia", Vector3.new(0, 4, 20))
end

function Constructor.Neutro(carpeta)
	local _, g, M = nuevoEntorno(carpeta, "Neutro", {
		Hora = 12,
		Brillo = 2,
		Ambiente = rgb(120, 115, 125),
	})
	local fondo = rgb(225, 215, 235)

	bloque(g, "Suelo", Vector3.new(60, 1, 40), Vector3.new(0, -0.5, -4), rgb(210, 200, 220), { Sombra = false })
	bloque(g, "Fondo", Vector3.new(60, 40, 1), Vector3.new(0, 20, -16.5), fondo, { Sombra = false })
	bloque(g, "FondoIzq", Vector3.new(1, 40, 40), Vector3.new(-30.5, 20, -4), fondo, { Sombra = false })
	bloque(g, "FondoDer", Vector3.new(1, 40, 40), Vector3.new(30.5, 20, -4), fondo, { Sombra = false })

	-- Pos_A y Pos_B ya están giradas una hacia la otra (posición de conversación)
	marca(M, "Pos_A", Vector3.new(-2, 0, 0), Vector3.new(0.6, 0, 1))
	marca(M, "Pos_B", Vector3.new(2, 0, 0), Vector3.new(-0.6, 0, 1))
	marca(M, "Pos_C", Vector3.new(0, 0, -3), Vector3.new(0, 0, 1))
	marca(M, "Pos_D", Vector3.new(-6, 0, -2), Vector3.new(0, 0, 1))
	marca(M, "Entrada_Izq", Vector3.new(-14, 0, 0), Vector3.new(1, 0, 0))
	marca(M, "Entrada_Der", Vector3.new(14, 0, 0), Vector3.new(-1, 0, 0))
	marca(M, "Obj_1", Vector3.new(0, 0, 2), Vector3.new(0, 0, 1))
	marca(M, "Obj_2", Vector3.new(-4, 0, 1), Vector3.new(0, 0, 1))
	camarasEstandar(M, Vector3.new(0, 3, 0), 20)
	marca(M, "Audiencia", Vector3.new(0, 4, 18))
end

Constructor.Lista = { "Calle", "Habitacion", "Exterior", "Neutro" }

function Constructor.ConstruirTodos(carpeta)
	for _, nombre in ipairs(Constructor.Lista) do
		Constructor[nombre](carpeta)
	end
end

return Constructor
