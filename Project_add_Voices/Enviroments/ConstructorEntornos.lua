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
	  Pared_*, Nota_* → superficies verticales donde pegar cosas (atributo Pared)
	  Silla_*         → asientos (acción Sentar)       Suelo_* → puntos del suelo
	  Audiencia                   → desde dónde "mira el público" (orienta los planos automáticos)

	Atributos del Model (iluminación que se aplica al cargarlo):
	  Hora (ClockTime), Brillo (Brightness), Ambiente (Color3), AmbienteExterior (Color3),
	  Tinte (Color3) y Saturacion (número) → tono de color de toda la imagen
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
	Pared = rgb(40, 170, 230),
	Nota = rgb(255, 220, 60),
	Silla = rgb(60, 200, 90),
	Suelo = rgb(255, 130, 40),
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
	elseif tipo == "Pared" or tipo == "Nota" then
		-- Superficie vertical: "pos" está sobre la pared y "mirar" es la normal (hacia fuera)
		local n = (mirar or Vector3.new(0, 0, 1)).Unit
		local centro = pos + n * 0.05
		p = parte(carpeta, nombre, Vector3.new(0.7, 0.7, 0.1), CFrame.lookAt(centro, centro + n), color, { Sombra = false })
		p:SetAttribute("Pared", true)
	else
		local pequena = tipo == "Obj" or tipo == "Suelo" or tipo == "Silla"
		local tam = pequena and Vector3.new(1, 0.2, 1) or Vector3.new(2, 0.4, 2)
		local centro = pos + Vector3.new(0, tam.Y / 2, 0)
		local dir = mirar or Vector3.new(0, 0, 1)
		p = parte(carpeta, nombre, tam, CFrame.lookAt(centro, centro + dir), color, { Sombra = false })
		if tipo ~= "Obj" and tipo ~= "Suelo" then
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

-- Texto pintado en una cara de una pieza (carteles, pizarras...). Sin texturas.
local function rotulo(p, texto, fuente, color, cara, op)
	op = op or {}
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Rotulo"
	sg.Face = cara or Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = op.Densidad or 60
	sg.LightInfluence = 1
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(op.Ancho or 0.9, op.Alto or 0.84)
	t.Position = UDim2.fromScale((1 - (op.Ancho or 0.9)) / 2, (1 - (op.Alto or 0.84)) / 2)
	t.Font = fuente
	t.TextScaled = true
	t.TextWrapped = true
	t.TextColor3 = color
	t.Text = texto
	t.Parent = sg
	sg.Parent = p
	return sg
end

-- Silla sencilla mirando hacia "dir" (+Z por defecto). Devuelve el punto central del asiento.
local function silla(g, base, color, alto, haciaAtras)
	alto = alto or 1.5
	local z = haciaAtras and -1 or 1
	caja(g, "SillaBase", Vector3.new(1.2, alto - 0.2, 1.2), base.X, base.Y, base.Z, color:Lerp(Color3.new(0, 0, 0), 0.25))
	caja(g, "SillaAsiento", Vector3.new(1.6, 0.2, 1.6), base.X, base.Y + alto - 0.2, base.Z, color)
	caja(g, "SillaRespaldo", Vector3.new(1.6, 2.2, 0.2), base.X, base.Y + alto, base.Z - 0.75 * z, color)
	return Vector3.new(base.X, base.Y + alto, base.Z)
end

-- Mesa con cuatro patas. Devuelve la altura del tablero.
local function mesa(g, centro, tam, alto, colorTablero, colorPatas)
	caja(g, "MesaTablero", Vector3.new(tam.X, 0.3, tam.Y), centro.X, alto - 0.3, centro.Z, colorTablero)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			caja(
				g,
				"MesaPata",
				Vector3.new(0.25, alto - 0.3, 0.25),
				centro.X + sx * (tam.X / 2 - 0.3),
				0,
				centro.Z + sz * (tam.Y / 2 - 0.3),
				colorPatas or colorTablero
			)
		end
	end
	return alto
end

local function cilindroFrontal(padre, nombre, grosor, diametro, centro, color, op)
	op = op or {}
	op.Forma = Enum.PartType.Cylinder
	return parte(padre, nombre, Vector3.new(grosor, diametro, diametro), CFrame.new(centro) * CFrame.Angles(0, math.pi / 2, 0), color, op)
end

--[[
	LABORATORIO · Laboratorio de adhesivos de los años 70
	Mesa central de trabajo junto a la pared del fondo, tablón de corcho y pizarra
	(superficies donde pegar papeles), banco de química con microscopio y matraces,
	armario de vidrio, ventana, reloj y cartel.
]]
function Constructor.Laboratorio(carpeta)
	local _, g, M = nuevoEntorno(carpeta, "Laboratorio", {
		Hora = 13,
		Brillo = 2,
		Ambiente = rgb(120, 125, 128),
		Tinte = rgb(238, 246, 255),
	})
	local pared = rgb(238, 240, 232)
	local menta = rgb(150, 195, 175)
	local madera = rgb(130, 90, 55)
	local metal = rgb(150, 152, 158)
	local negro = rgb(45, 48, 52)

	-- Suelo de baldosas
	bloque(g, "Suelo", Vector3.new(32, 1, 24), Vector3.new(0, -0.5, -3), rgb(208, 212, 204), { Sombra = false })
	for x = -12, 12, 4 do
		bloque(g, "Junta", Vector3.new(0.08, 0.02, 24), Vector3.new(x, 0.01, -3), rgb(182, 188, 180), { Sombra = false })
	end
	for z = -11, 5, 4 do
		bloque(g, "Junta", Vector3.new(32, 0.02, 0.08), Vector3.new(0, 0.01, z), rgb(182, 188, 180), { Sombra = false })
	end

	-- Paredes con zócalo verde menta
	bloque(g, "ParedFondo", Vector3.new(32, 16, 1), Vector3.new(0, 8, -15.5), pared)
	bloque(g, "ParedIzquierda", Vector3.new(1, 16, 24), Vector3.new(-16.5, 8, -3), pared)
	bloque(g, "ParedDerecha", Vector3.new(1, 16, 24), Vector3.new(16.5, 8, -3), pared)
	bloque(g, "ZocaloFondo", Vector3.new(32, 4, 0.2), Vector3.new(0, 2, -14.9), menta, { Sombra = false })
	bloque(g, "ZocaloIzq", Vector3.new(0.2, 4, 24), Vector3.new(-15.9, 2, -3), menta, { Sombra = false })
	bloque(g, "ZocaloDer", Vector3.new(0.2, 4, 24), Vector3.new(15.9, 2, -3), menta, { Sombra = false })

	-- Cartel
	local cartel = bloque(g, "Cartel", Vector3.new(11, 1.3, 0.2), Vector3.new(0, 13.2, -14.85), rgb(40, 85, 70))
	rotulo(cartel, "LABORATORIO DE ADHESIVOS", Enum.Font.GothamBold, rgb(245, 245, 235))

	-- Tablón de corcho (a la derecha) con un par de hojas clavadas
	bloque(g, "TablonMarco", Vector3.new(6.6, 4.8, 0.25), Vector3.new(2.2, 6, -14.85), madera)
	bloque(g, "TablonCorcho", Vector3.new(6, 4.2, 0.3), Vector3.new(2.2, 6, -14.8), rgb(196, 156, 104), { Sombra = false })
	local hoja1 = bloque(g, "HojaClavada", Vector3.new(1, 1.3, 0.04), Vector3.new(-0.15, 4.75, -14.63), rgb(248, 248, 244), { Sombra = false })
	rotulo(hoja1, "PRUEBA 12\n✗", Enum.Font.PatrickHand, rgb(60, 60, 70))
	bloque(g, "Chincheta", Vector3.new(0.12, 0.12, 0.12), Vector3.new(-0.15, 5.3, -14.6), rgb(200, 40, 40), { Forma = Enum.PartType.Ball })
	local hoja2 = bloque(g, "HojaClavada", Vector3.new(1.2, 0.9, 0.04), Vector3.new(4.6, 7.45, -14.63), rgb(248, 248, 244), { Sombra = false })
	rotulo(hoja2, "PRUEBA 13\n✗", Enum.Font.PatrickHand, rgb(60, 60, 70))
	bloque(g, "Chincheta", Vector3.new(0.12, 0.12, 0.12), Vector3.new(4.6, 7.8, -14.6), rgb(40, 90, 200), { Forma = Enum.PartType.Ball })

	-- Pizarra (a la izquierda) con fórmulas
	bloque(g, "PizarraMarco", Vector3.new(7.4, 4.6, 0.25), Vector3.new(-6, 6, -14.85), rgb(110, 80, 50))
	local pizarra = bloque(g, "Pizarra", Vector3.new(7, 4.2, 0.3), Vector3.new(-6, 6, -14.8), rgb(40, 70, 55), { Sombra = false })
	rotulo(pizarra, "Polímero A-174\nadhesión: BAJA\n¿utilidad?  ???", Enum.Font.PatrickHand, rgb(235, 240, 230), Enum.NormalId.Back, { Ancho = 0.62, Alto = 0.8 })
	bloque(g, "Repisa", Vector3.new(7, 0.15, 0.45), Vector3.new(-6, 3.85, -14.55), rgb(110, 80, 50))
	bloque(g, "Tiza", Vector3.new(0.4, 0.1, 0.1), Vector3.new(-8.5, 3.98, -14.5), rgb(250, 250, 250), { Sombra = false })

	-- Reloj de pared
	cilindroFrontal(g, "RelojAro", 0.15, 2.2, Vector3.new(-12, 11, -14.9), rgb(30, 30, 30))
	cilindroFrontal(g, "RelojEsfera", 0.2, 2, Vector3.new(-12, 11, -14.85), rgb(250, 250, 245))
	parte(g, "Aguja", Vector3.new(0.1, 0.75, 0.05), CFrame.new(-12, 11.3, -14.73), rgb(20, 20, 20), { Sombra = false })
	parte(g, "Aguja", Vector3.new(0.1, 0.55, 0.05), CFrame.new(-11.8, 11, -14.73) * CFrame.Angles(0, 0, math.rad(-70)), rgb(20, 20, 20), { Sombra = false })

	-- Mesa central de trabajo (encimera negra)
	caja(g, "MesaTablero", Vector3.new(6, 0.3, 3), -1, 2.85, -10, negro)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			caja(g, "MesaPata", Vector3.new(0.25, 2.85, 0.25), -1 + sx * 2.7, 0, -10 + sz * 1.2, metal)
		end
	end
	caja(g, "MesaBalda", Vector3.new(5.6, 0.15, 2.6), -1, 0.8, -10, metal)
	caja(g, "Folios", Vector3.new(1, 0.25, 1.3), -0.6, 3.15, -10.6, rgb(250, 250, 248), { Sombra = false })
	cilindroVertical(g, "VasoPrecipitado", 0.6, 0.45, Vector3.new(1.3, 3.15, -10.9), rgb(190, 225, 240), { Sombra = false }).Transparency = 0.35
	cilindroVertical(g, "Liquido", 0.3, 0.4, Vector3.new(1.3, 3.16, -10.9), rgb(120, 200, 120), { Sombra = false })
	cilindroVertical(g, "TuboEnsayo", 0.7, 0.18, Vector3.new(1.75, 3.15, -10.6), rgb(240, 170, 60), { Sombra = false })

	-- Banco de química a la derecha
	caja(g, "BancoMueble", Vector3.new(2.6, 2.85, 11), 14.4, 0, -8, rgb(120, 165, 150))
	caja(g, "BancoEncimera", Vector3.new(2.9, 0.3, 11.2), 14.3, 2.85, -8, negro)
	for i, z in ipairs({ -11, -9.5, -8, -6.5 }) do
		caja(g, "Cajon" .. i, Vector3.new(0.05, 1, 1.2), 13.08, 1.5, z, rgb(100, 140, 128), { Sombra = false })
	end
	-- Microscopio
	caja(g, "MicroBase", Vector3.new(0.8, 0.15, 1), 14.3, 3.15, -11.5, rgb(235, 235, 230))
	caja(g, "MicroBrazo", Vector3.new(0.25, 1.2, 0.25), 14.3, 3.3, -11.85, rgb(235, 235, 230))
	parte(g, "MicroTubo", Vector3.new(0.9, 0.25, 0.25), CFrame.new(14.3, 4.5, -11.55) * CFrame.Angles(0, 0, math.rad(70)), rgb(40, 40, 45))
	-- Matraces de colores
	for i, d in ipairs({ { -9, rgb(240, 140, 60) }, { -8, rgb(80, 150, 230) }, { -7, rgb(130, 210, 110) } }) do
		cilindroVertical(g, "Matraz" .. i, 0.5, 0.7, Vector3.new(14.3, 3.15, d[1]), d[2], { Sombra = false })
		cilindroVertical(g, "Cuello" .. i, 0.5, 0.22, Vector3.new(14.3, 3.65, d[1]), rgb(210, 235, 245), { Sombra = false })
	end
	-- Balda con frascos
	caja(g, "Balda", Vector3.new(1.3, 0.2, 10), 15.3, 7, -8, madera)
	for i, z in ipairs({ -12, -10.5, -9, -7.5, -6, -4.5 }) do
		local c = (i % 2 == 0) and rgb(120, 70, 30) or rgb(60, 110, 70)
		cilindroVertical(g, "Frasco" .. i, 0.9, 0.5, Vector3.new(15.3, 7.2, z), c, { Sombra = false })
	end
	-- Taburetes
	for _, z in ipairs({ -6, -3.5 }) do
		cilindroVertical(g, "TaburetePie", 1.9, 0.25, Vector3.new(12, 0, z), metal)
		cilindroVertical(g, "TabureteAsiento", 0.25, 1.2, Vector3.new(12, 1.9, z), rgb(60, 60, 65))
	end

	-- Armario de vidrio (izquierda) y ventana
	caja(g, "Armario", Vector3.new(2, 8, 6), -15, 0, -9, rgb(180, 186, 182))
	for _, z in ipairs({ -10.4, -7.6 }) do
		bloque(g, "ArmarioCristal", Vector3.new(0.1, 3.4, 2.5), Vector3.new(-13.97, 5.6, z), rgb(190, 220, 235), { Sombra = false })
	end
	bloque(g, "VentanaMarco", Vector3.new(0.3, 4.6, 6.2), Vector3.new(-15.9, 8.6, -1.5), rgb(245, 245, 245))
	bloque(g, "VentanaCristal", Vector3.new(0.3, 4, 5.6), Vector3.new(-15.8, 8.6, -1.5), rgb(170, 210, 240), { Sombra = false })

	-- Papelera con intentos fallidos
	cilindroVertical(g, "Papelera", 1.5, 1.2, Vector3.new(-5.2, 0, -13), rgb(120, 125, 130))
	for i, d in ipairs({ { -5.4, -12.9 }, { -5, -13.2 }, { -5.1, -12.7 } }) do
		parte(g, "PapelArrugado" .. i, Vector3.new(0.5, 0.5, 0.5), CFrame.new(d[1], 1.55 + i * 0.05, d[2]), rgb(245, 245, 240), {
			Forma = Enum.PartType.Ball,
			Sombra = false,
		})
	end

	-- Marcas
	local frente = Vector3.new(0, 0, 1)
	marca(M, "Pos_A", Vector3.new(-3.2, 0, -12.7), frente)
	marca(M, "Pos_TrasMesa", Vector3.new(1, 0, -12.7), frente)
	marca(M, "Pos_B", Vector3.new(2.6, 0, -6.5), Vector3.new(-0.5, 0, 1))
	marca(M, "Pos_C", Vector3.new(-0.5, 0, -4.5), frente)
	marca(M, "Pos_D", Vector3.new(6.5, 0, -6), Vector3.new(-1, 0, 0.3))
	marca(M, "Entrada_Izq", Vector3.new(-13, 0, -4), Vector3.new(1, 0, 0))
	marca(M, "Entrada_Der", Vector3.new(12.5, 0, -1), Vector3.new(-1, 0, 0))
	marca(M, "Obj_1", Vector3.new(-2.8, 3.15, -10.2), frente)
	marca(M, "Obj_2", Vector3.new(0.6, 3.15, -9.5), frente)
	marca(M, "Obj_3", Vector3.new(14.1, 3.15, -4.6), Vector3.new(-1, 0, 0))
	marca(M, "Obj_4", Vector3.new(14.1, 3.15, -2.9), Vector3.new(-1, 0, 0))
	marca(M, "Suelo_1", Vector3.new(10.5, 0, -2), Vector3.new(-1, 0, 0.5))
	-- Superficies de pared (cara frontal = hacia fuera de la pared)
	local corcho, encerado = -14.65, -14.65
	marca(M, "Pared_1", Vector3.new(1.6, 5, corcho), frente)
	marca(M, "Pared_2", Vector3.new(-3.7, 5, encerado), frente)
	for i, d in ipairs({ { 0.3, 7.2 }, { 1.8, 7.4 }, { 3.2, 7 }, { 3, 5.2 }, { 4.5, 5.5 }, { 1.5, 4.5 } }) do
		marca(M, "Nota_" .. i, Vector3.new(d[1], d[2], corcho), frente)
	end
	camarasEstandar(M, Vector3.new(0, 3.5, -9), 24)
	marca(M, "Cam_Tablon", Vector3.new(2.2, 6, -6.5), Vector3.new(2.2, 6, -14.7))
	marca(M, "Cam_Mesa", Vector3.new(-0.5, 5.2, -3), Vector3.new(-0.5, 3.4, -10.5))
	marca(M, "Audiencia", Vector3.new(0, 4, 14))
end

--[[
	SALAENSAYO · Sala de ensayo del coro (años 70)
	Gradas con sillas, atriles, piano vertical, vidrieras de colores, tablero de
	himnos y, en primer plano, la mesa y la silla donde Art lee su cancionero.
]]
function Constructor.SalaEnsayo(carpeta)
	local _, g, M = nuevoEntorno(carpeta, "SalaEnsayo", {
		Hora = 17.4,
		Brillo = 1.7,
		Ambiente = rgb(135, 112, 92),
		Tinte = rgb(255, 236, 210),
		Saturacion = 0.05,
	})
	local pared = rgb(232, 214, 184)
	local madera = rgb(125, 85, 52)
	local maderaClara = rgb(150, 102, 62)
	local tapizado = rgb(140, 45, 50)

	-- Suelo de tarima
	bloque(g, "Suelo", Vector3.new(32, 1, 26), Vector3.new(0, -0.5, -3), maderaClara, { Sombra = false })
	for x = -12, 12, 4.8 do
		bloque(g, "Tabla", Vector3.new(0.06, 0.02, 26), Vector3.new(x, 0.01, -3), rgb(125, 82, 48), { Sombra = false })
	end

	-- Paredes con friso de madera
	bloque(g, "ParedFondo", Vector3.new(32, 16, 1), Vector3.new(0, 8, -16.5), pared)
	bloque(g, "ParedIzquierda", Vector3.new(1, 16, 26), Vector3.new(-16.5, 8, -3), pared)
	bloque(g, "ParedDerecha", Vector3.new(1, 16, 26), Vector3.new(16.5, 8, -3), pared)
	bloque(g, "FrisoFondo", Vector3.new(32, 3.5, 0.2), Vector3.new(0, 1.75, -15.9), madera, { Sombra = false })
	bloque(g, "MolduraFondo", Vector3.new(32, 0.2, 0.35), Vector3.new(0, 3.6, -15.85), madera, { Sombra = false })
	bloque(g, "FrisoIzq", Vector3.new(0.2, 3.5, 26), Vector3.new(-15.9, 1.75, -3), madera, { Sombra = false })
	bloque(g, "FrisoDer", Vector3.new(0.2, 3.5, 26), Vector3.new(15.9, 1.75, -3), madera, { Sombra = false })

	-- Vidrieras de colores
	local colores = {
		rgb(190, 60, 60),
		rgb(60, 90, 170),
		rgb(220, 180, 60),
		rgb(60, 140, 90),
		rgb(150, 70, 150),
		rgb(230, 140, 60),
	}
	for _, x in ipairs({ -9, 9 }) do
		bloque(g, "VidrieraMarco", Vector3.new(4.2, 6.4, 0.3), Vector3.new(x, 9.2, -15.85), rgb(60, 45, 40))
		local i = 0
		for fila = 0, 2 do
			for col = 0, 1 do
				i = i + 1
				bloque(g, "Vidrio", Vector3.new(1.8, 1.9, 0.3), Vector3.new(x - 0.95 + col * 1.9, 7.2 + fila * 2, -15.8), colores[i], {
					Material = Enum.Material.Neon,
					Sombra = false,
				}).Transparency = 0.25
			end
		end
	end

	-- Tablero de himnos y cartel
	local tablero = bloque(g, "TableroHimnos", Vector3.new(3, 4, 0.25), Vector3.new(0, 9.4, -15.85), rgb(70, 45, 30))
	rotulo(tablero, "CORO\n\n12\n47\n103", Enum.Font.Antique, rgb(245, 235, 210))
	local cartel = bloque(g, "Cartel", Vector3.new(12, 1.3, 0.2), Vector3.new(0, 13.6, -15.85), rgb(245, 238, 220))
	rotulo(cartel, "ENSAYO DEL CORO · JUEVES 19:00", Enum.Font.Antique, rgb(110, 40, 40))

	-- Gradas con sillas
	caja(g, "GradaAlta", Vector3.new(22, 1.2, 2.8), 0, 0, -14.3, madera)
	caja(g, "GradaBaja", Vector3.new(22, 0.6, 2.8), 0, 0, -11.5, madera)
	for _, x in ipairs({ -6, 0, 6 }) do
		silla(g, Vector3.new(x, 1.2, -14.3), tapizado, 1.5)
		silla(g, Vector3.new(x + 3, 0.6, -11.5), tapizado, 1.5)
	end
	-- Atriles
	for _, x in ipairs({ -5, 1, 7 }) do
		cilindroVertical(g, "AtrilPie", 3, 0.15, Vector3.new(x, 0, -9), rgb(35, 35, 38))
		parte(g, "AtrilBandeja", Vector3.new(1.4, 1, 0.08), CFrame.new(x, 3.3, -8.95) * CFrame.Angles(math.rad(-25), 0, 0), rgb(35, 35, 38))
	end

	-- Piano vertical (izquierda)
	caja(g, "PianoCuerpo", Vector3.new(2.2, 4.6, 6), -12.6, 0, -6, rgb(60, 34, 22))
	caja(g, "PianoTapa", Vector3.new(2.5, 0.2, 6.3), -12.6, 4.6, -6, rgb(45, 25, 16))
	caja(g, "PianoTeclas", Vector3.new(1.1, 0.25, 5.4), -11.05, 2.5, -6, rgb(242, 240, 232))
	caja(g, "PianoTeclasNegras", Vector3.new(0.45, 0.12, 5.2), -11.35, 2.75, -6, rgb(20, 20, 20), { Sombra = false })
	parte(g, "Partitura", Vector3.new(0.05, 1, 1.4), CFrame.new(-11.45, 3.5, -6) * CFrame.Angles(0, 0, math.rad(-12)), rgb(248, 246, 238), { Sombra = false })
	caja(g, "PianoBanqueta", Vector3.new(1.4, 1.6, 3), -9.4, 0, -6, rgb(60, 34, 22))

	-- Planta
	cilindroVertical(g, "Maceta", 1.2, 1.2, Vector3.new(13.5, 0, -13), rgb(170, 90, 60))
	parte(g, "Planta", Vector3.new(2.4, 2.4, 2.4), CFrame.new(13.5, 2.4, -13), rgb(70, 130, 60), { Forma = Enum.PartType.Ball })

	-- Mesa y silla de Art (primer término, mirando a cámara)
	local alto = mesa(g, Vector3.new(2.5, 0, -2.5), Vector2.new(4.4, 2.6), 2.75, rgb(140, 95, 55))
	local asiento = silla(g, Vector3.new(2.5, 0, -5), rgb(120, 80, 48), 1.5)
	-- Pila de cancioneros y lámpara de mesa
	for i, c in ipairs({ rgb(110, 30, 40), rgb(30, 60, 110), rgb(110, 30, 40) }) do
		caja(g, "CancioneroPila" .. i, Vector3.new(0.9, 0.22, 1.2), 0.9, alto + (i - 1) * 0.22, -2.1, c, { Sombra = false })
	end
	cilindroVertical(g, "LamparaPie", 1.2, 0.12, Vector3.new(4.2, alto, -3.4), rgb(40, 40, 40))
	parte(g, "LamparaPantalla", Vector3.new(0.7, 0.7, 0.7), CFrame.new(4.2, alto + 1.35, -3.2), rgb(40, 110, 70), {
		Forma = Enum.PartType.Ball,
	})
	-- Papeles sueltos sobre la mesa
	for i, d in ipairs({ { 3.6, -2.2, 12 }, { 3.9, -1.9, -20 } }) do
		parte(g, "PapelSuelto" .. i, Vector3.new(0.85, 0.03, 1.1), CFrame.new(d[1], alto + 0.02 * i, d[2]) * CFrame.Angles(0, math.rad(d[3]), 0), rgb(248, 248, 242), {
			Sombra = false,
		})
	end

	local frente = Vector3.new(0, 0, 1)
	marca(M, "Silla_1", asiento, frente)
	marca(M, "Obj_Libro", Vector3.new(2.4, alto, -3), frente)
	marca(M, "Obj_Papeles", Vector3.new(3.7, alto + 0.05, -2.9), frente)
	marca(M, "Obj_Nota", Vector3.new(1.4, alto, -3.1), frente)
	marca(M, "Suelo_Libro", Vector3.new(3.1, 0, -0.5), frente)
	marca(M, "Pos_A", Vector3.new(-2, 0, -2), frente)
	marca(M, "Pos_B", Vector3.new(6, 0, -2), frente)
	marca(M, "Pos_C", Vector3.new(0, 0, -7), frente)
	marca(M, "Pos_D", Vector3.new(-8, 0, -4), frente)
	marca(M, "Entrada_Izq", Vector3.new(-13, 0, 0), Vector3.new(1, 0, 0))
	marca(M, "Entrada_Der", Vector3.new(13, 0, 0), Vector3.new(-1, 0, 0))
	camarasEstandar(M, Vector3.new(1, 3, -5), 22)
	marca(M, "Cam_Mesa", Vector3.new(2.5, 3.9, 4.5), Vector3.new(2.5, 2.7, -3))
	marca(M, "Audiencia", Vector3.new(1, 4, 16))
end

Constructor.Lista = { "Calle", "Habitacion", "Exterior", "Neutro", "Laboratorio", "SalaEnsayo" }

function Constructor.ConstruirTodos(carpeta)
	for _, nombre in ipairs(Constructor.Lista) do
		Constructor[nombre](carpeta)
	end
end

return Constructor
