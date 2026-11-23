--[[
	ATUENDOS · Biblioteca reutilizable de caras, pelo, ropa y accesorios
	Studio: ReplicatedStorage > StoryTemplate > Modulos > Atuendos

	Todo se construye con colores planos y unas pocas Parts soldadas al cuerpo,
	sin texturas ni ids del catálogo: no depende de nada externo y cuesta muy poco.
	Lo usa FabricaPersonajes al construir los personajes de DefPersonajes.

	PIEZAS DISPONIBLES (para usar en DefPersonajes)

	Caras (Cara = "Nombre" o una tabla { Ojos, Cejas, Boca, Mejillas, Pecas })
	  Caras predefinidas : Timido, Seguro, Alegre, Neutral, Serio
	  Ojos   : tabla { Iris = Color3, Parpado = 0..0.6, ParpadoInferior = 0..0.4, Tamano = 1 }
	           (ojos detallados que parpadean solos)
	  Cejas  : Normales, Gruesas, Preocupadas, Arqueadas, Ninguna
	  Boca   : Sonrisa, SonrisaPequena, SonrisaAbierta, MediaSonrisa, Seria, O
	           (al hablar se cambia por una boca que se abre y se cierra)

	Pelo (Pelo = { Estilo = "...", Color = Color3 })
	  Corto, Despeinado, Rapado, Ninguno

	Prendas superiores (Superior = { Prenda = "...", Color = Color3, ColorDetalle = Color3 })
	  Camiseta, MangaLarga, Sudadera, Polo, Tirantes, Chaqueta, CamisetaRayas

	Prendas inferiores (Inferior = { Prenda = "...", Color = Color3 })
	  Pantalon, Corto

	Accesorios (Accesorios = { { Tipo = "...", Color = Color3 }, ... })
	  Gorra, GorraAtras, Gafas, Barba, Cinturon, Barriga, Mochila
]]

local Atuendos = {}

local OSCURO = Color3.fromRGB(35, 28, 28)
local BLANCO = Color3.fromRGB(250, 250, 250)

--==============================================================================
-- CABEZA CLÁSICA
-- La cabeza por defecto de Roblox es una "cabeza dinámica" con su propia cara
-- animada (ojos que parpadean). Para que no se superponga a nuestra cara, se
-- sustituye por la cabeza clásica de bloques (SpecialMesh "Head", sin texturas).
--==============================================================================

function Atuendos.CabezaClasica(modelo)
	local vieja = modelo:FindFirstChild("Head")
	if not vieja or not vieja:IsA("BasePart") then
		return nil
	end
	local lado = vieja.Size.Y
	local nueva = Instance.new("Part")
	nueva.Name = "Head"
	nueva.Size = Vector3.new(lado, lado, lado)
	nueva.CFrame = vieja.CFrame
	nueva.Color = vieja.Color
	nueva.Material = Enum.Material.SmoothPlastic
	nueva.TopSurface = Enum.SurfaceType.Smooth
	nueva.BottomSurface = Enum.SurfaceType.Smooth
	nueva.CanCollide = false
	nueva.CanTouch = false
	nueva.CanQuery = false
	local malla = Instance.new("SpecialMesh")
	malla.MeshType = Enum.MeshType.Head
	malla.Scale = Vector3.new(1, 1, 1)
	malla.Parent = nueva

	-- Conserva articulaciones y puntos de anclaje; descarta cara, texturas y FaceControls
	for _, hijo in ipairs(vieja:GetChildren()) do
		if hijo:IsA("Attachment") or hijo:IsA("JointInstance") or hijo:IsA("WeldConstraint") or hijo:IsA("ValueBase") then
			hijo.Parent = nueva
		end
	end
	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			if d.Part0 == vieja then
				d.Part0 = nueva
			end
			if d.Part1 == vieja then
				d.Part1 = nueva
			end
		end
	end
	vieja:Destroy()
	nueva.Parent = modelo
	return nueva
end

--==============================================================================
-- CARAS
-- Se dibujan con un SurfaceGui en la cara frontal de la cabeza. Los nombres
-- de los elementos (OjoIzq, OjoDer, Parpado, BocaReposo, BocaHabla) los usa
-- el Actor para parpadear y mover la boca al hablar.
--==============================================================================

--[[
	Ojos = {
	  Iris            = Color3 del iris
	  Parpado         = 0..0.6  cuánto tapa el párpado superior (0.35 = mirada entornada)
	  ParpadoInferior = 0..0.4  cuánto sube el párpado inferior (ojos sonrientes)
	  Tamano          = 1       escala del ojo
	}
]]
Atuendos.Caras = {
	Neutral = {
		Ojos = { Iris = Color3.fromRGB(95, 65, 40), Parpado = 0.08 },
		Cejas = "Normales",
		Boca = "SonrisaPequena",
	},
	Timido = {
		Ojos = { Iris = Color3.fromRGB(70, 125, 190), Parpado = 0.04, Tamano = 1.1 },
		Cejas = "Preocupadas",
		Boca = "SonrisaPequena",
		Pecas = true,
	},
	Seguro = {
		Ojos = { Iris = Color3.fromRGB(80, 50, 30), Parpado = 0.36, Tamano = 0.95 },
		Cejas = "Gruesas",
		Boca = "MediaSonrisa",
	},
	Alegre = {
		Ojos = { Iris = Color3.fromRGB(60, 145, 80), Parpado = 0.1, ParpadoInferior = 0.28, Tamano = 1.05 },
		Cejas = "Arqueadas",
		Boca = "SonrisaAbierta",
		Mejillas = true,
	},
	Serio = {
		Ojos = { Iris = Color3.fromRGB(90, 90, 100), Parpado = 0.25 },
		Cejas = "Gruesas",
		Boca = "Seria",
	},
}

-- Rectángulo (o pastilla/círculo si redondo) centrado en "x, y" (escala 0-1 del padre).
local function forma(padre, x, y, ancho, alto, color, redondo, rotacion, transparencia, z)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(ancho, alto)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparencia or 0
	f.BorderSizePixel = 0
	f.Rotation = rotacion or 0
	f.ZIndex = z or 1
	if redondo then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
	end
	f.Parent = padre
	return f
end

--[[
	Media elipse centrada en (x, y).
	haciaAbajo = true → forma de U (sonrisa); false → forma de ∩.
	relleno = Color3 → media elipse rellena; nil → solo el contorno (grosor en píxeles de 100).
]]
local function arco(padre, x, y, ancho, alto, haciaAbajo, color, grosor, relleno)
	local cont = Instance.new("Frame")
	cont.BackgroundTransparency = 1
	cont.ClipsDescendants = true
	cont.AnchorPoint = Vector2.new(0.5, haciaAbajo and 0 or 1)
	cont.Position = UDim2.fromScale(x, y)
	cont.Size = UDim2.fromScale(ancho, alto / 2)
	cont.Parent = padre
	local e = Instance.new("Frame")
	e.Size = UDim2.fromScale(1, 2)
	e.Position = UDim2.fromScale(0, haciaAbajo and -1 or 0)
	e.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = e
	if relleno then
		e.BackgroundColor3 = relleno
	else
		e.BackgroundTransparency = 1
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = grosor or 3
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = e
	end
	e.Parent = cont
	return cont
end

local PESTANAS = Color3.fromRGB(25, 18, 18)

-- Ojo detallado: blanco, iris, pupila, dos brillos, párpado superior con pestañas
-- y párpado inferior. "haciaDentro" (1 o -1) desplaza un poco el iris hacia la nariz.
local function ojo(g, nombre, x, y, op, piel, haciaDentro)
	local t = op.Tamano or 1
	local cont = Instance.new("Frame")
	cont.Name = nombre
	cont.AnchorPoint = Vector2.new(0.5, 0.5)
	cont.Position = UDim2.fromScale(x, y)
	cont.Size = UDim2.fromScale(0.17 * t, 0.21 * t)
	cont.BackgroundTransparency = 1
	cont.ClipsDescendants = true
	cont.Parent = g

	local dx = 0.05 * haciaDentro
	forma(cont, 0.5, 0.5, 1, 1, BLANCO, true, 0, 0, 1) -- blanco del ojo
	forma(cont, 0.5 + dx, 0.55, 0.64, 0.52, op.Iris or Color3.fromRGB(95, 65, 40), true, 0, 0, 2) -- iris
	forma(cont, 0.5 + dx, 0.55, 0.32, 0.26, Color3.fromRGB(15, 12, 12), true, 0, 0, 3) -- pupila
	forma(cont, 0.62 + dx, 0.42, 0.2, 0.16, BLANCO, true, 0, 0, 4) -- brillo grande
	forma(cont, 0.4 + dx, 0.66, 0.09, 0.075, BLANCO, true, 0, 0.1, 4) -- brillo pequeño

	-- Párpado inferior (tapa desde abajo)
	local inferior = op.ParpadoInferior or 0
	if inferior > 0 then
		local pi = Instance.new("Frame")
		pi.Name = "ParpadoInferior"
		pi.AnchorPoint = Vector2.new(0.5, 1)
		pi.Position = UDim2.fromScale(0.5, 1)
		pi.Size = UDim2.fromScale(1.2, inferior)
		pi.BackgroundColor3 = piel
		pi.BorderSizePixel = 0
		pi.ZIndex = 5
		pi.Parent = cont
	end

	-- Párpado superior (el que se cierra al parpadear) con la línea de pestañas
	local alto = op.Parpado or 0.06
	local p = Instance.new("Frame")
	p.Name = "Parpado"
	p.AnchorPoint = Vector2.new(0.5, 0)
	p.Position = UDim2.fromScale(0.5, 0)
	p.Size = UDim2.fromScale(1.2, alto)
	p.BackgroundColor3 = piel
	p.BorderSizePixel = 0
	p.ZIndex = 6
	p:SetAttribute("Alto", alto)
	p.Parent = cont

	local pestanas = forma(p, 0.5, 1, 0.86, 0, PESTANAS, true, 0, 0, 7)
	pestanas.Name = "Pestanas"
	pestanas.Size = UDim2.new(0.86, 0, 0, 3)
	-- Pestaña exterior (detalle)
	local rabito = forma(p, 0.5 - 0.42 * haciaDentro, 1, 0.22, 0, PESTANAS, true, 25 * haciaDentro, 0, 7)
	rabito.Name = "PestanaExterior"
	rabito.Size = UDim2.new(0.22, 0, 0, 3)
	return cont
end

-- Cada ceja: inclinación de la izquierda (la derecha es simétrica), altura y grosor.
local CEJAS = {
	Normales = { Giro = 0, Y = 0.26, Grosor = 0.035 },
	Gruesas = { Giro = 7, Y = 0.28, Grosor = 0.06 },
	Preocupadas = { Giro = -16, Y = 0.25, Grosor = 0.035 },
	Arqueadas = { Giro = -9, Y = 0.22, Grosor = 0.04 },
}

local BOCAS = {
	Sonrisa = function(g, y)
		arco(g, 0.5, y, 0.32, 0.18, true, OSCURO, 3.5)
	end,
	SonrisaPequena = function(g, y)
		arco(g, 0.5, y, 0.2, 0.1, true, OSCURO, 3)
	end,
	SonrisaAbierta = function(g, y)
		local boca = arco(g, 0.5, y - 0.02, 0.34, 0.26, true, nil, nil, Color3.fromRGB(90, 25, 30))
		forma(boca, 0.5, 0.1, 0.8, 0.2, BLANCO, false, 0, 0, 2)
		forma(boca, 0.5, 0.78, 0.4, 0.28, Color3.fromRGB(220, 90, 100), true, 0, 0, 2)
	end,
	MediaSonrisa = function(g, y)
		forma(g, 0.43, y + 0.005, 0.12, 0.03, OSCURO, true, -4)
		arco(g, 0.55, y - 0.03, 0.16, 0.1, true, OSCURO, 3)
	end,
	Seria = function(g, y)
		forma(g, 0.5, y, 0.22, 0.03, OSCURO, true)
	end,
	O = function(g, y)
		forma(g, 0.5, y, 0.1, 0.13, Color3.fromRGB(90, 25, 30), true)
	end,
}

-- Boca abierta que se usa al hablar (oculta en reposo). El Actor cambia su tamaño.
local function bocaHabla(g, y)
	local b = forma(g, 0.5, y, 0.2, 0.12, Color3.fromRGB(90, 25, 30), true, 0, 0, 1)
	b.Name = "BocaHabla"
	b.ClipsDescendants = true
	b.Visible = false
	local dientes = Instance.new("Frame")
	dientes.AnchorPoint = Vector2.new(0.5, 0)
	dientes.Position = UDim2.fromScale(0.5, 0)
	dientes.Size = UDim2.fromScale(0.8, 0.22)
	dientes.BackgroundColor3 = BLANCO
	dientes.BorderSizePixel = 0
	dientes.ZIndex = 2
	dientes.Parent = b
	local lengua = forma(b, 0.5, 1.15, 0.6, 0.5, Color3.fromRGB(220, 90, 100), true, 0, 0, 2)
	lengua.AnchorPoint = Vector2.new(0.5, 1)
	return b
end

function Atuendos.CrearCara(cabeza, def)
	if type(def) == "string" then
		def = Atuendos.Caras[def]
	end
	if type(def) ~= "table" then
		return nil
	end
	for _, d in ipairs(cabeza:GetChildren()) do
		if d:IsA("Decal") or d:IsA("FaceControls") or d:IsA("SurfaceAppearance") or d.Name == "Cara" then
			d:Destroy()
		end
	end

	local piel = cabeza.Color
	local g = Instance.new("SurfaceGui")
	g.Name = "Cara"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(100, 100)
	g.LightInfluence = 1
	g.ClipsDescendants = true
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local ojos = type(def.Ojos) == "table" and def.Ojos or {}
	ojo(g, "OjoIzq", 0.33, 0.45, ojos, piel, 1)
	ojo(g, "OjoDer", 0.67, 0.45, ojos, piel, -1)

	local ceja = CEJAS[def.Cejas or "Normales"]
	if ceja then
		forma(g, 0.33, ceja.Y, 0.17, ceja.Grosor, OSCURO, true, ceja.Giro)
		forma(g, 0.67, ceja.Y, 0.17, ceja.Grosor, OSCURO, true, -ceja.Giro)
	end

	local reposo = Instance.new("Frame")
	reposo.Name = "BocaReposo"
	reposo.Size = UDim2.fromScale(1, 1)
	reposo.BackgroundTransparency = 1
	reposo.Parent = g
	local boca = BOCAS[def.Boca or "SonrisaPequena"] or BOCAS.SonrisaPequena
	boca(reposo, 0.69)
	bocaHabla(g, 0.71)

	if def.Mejillas then
		local rosa = Color3.fromRGB(240, 120, 120)
		forma(g, 0.18, 0.62, 0.13, 0.08, rosa, true, 0, 0.45)
		forma(g, 0.82, 0.62, 0.13, 0.08, rosa, true, 0, 0.45)
	end
	if def.Pecas then
		local marron = Color3.fromRGB(170, 110, 80)
		for _, p in ipairs({ { 0.2, 0.6 }, { 0.25, 0.63 }, { 0.17, 0.65 } }) do
			forma(g, p[1], p[2], 0.025, 0.025, marron, true, 0, 0.2)
			forma(g, 1 - p[1], p[2], 0.025, 0.025, marron, true, 0, 0.2)
		end
	end

	g.Parent = cabeza
	return g
end

--==============================================================================
-- PIEZAS 3D SOLDADAS AL CUERPO
--==============================================================================

-- Crea una Part pegada a "base" con un desplazamiento local (CFrame) y la suelda.
local function pegar(modelo, base, nombre, tam, offset, color, forma3d)
	local p = Instance.new("Part")
	p.Name = nombre
	p.Shape = forma3d or Enum.PartType.Block
	p.Size = tam
	p.CFrame = base.CFrame * offset
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = base
	w.Part1 = p
	w.Parent = p
	local carpeta = modelo:FindFirstChild("Atuendo")
	if not carpeta then
		carpeta = Instance.new("Folder")
		carpeta.Name = "Atuendo"
		carpeta.Parent = modelo
	end
	p.Parent = carpeta
	return p
end

local function C(x, y, z)
	return CFrame.new(x, y, z)
end

-- Cada pieza recibe (modelo, color, colorDetalle). El frente del cuerpo es -Z.
local PIEZAS = {}

PIEZAS.PeloCorto = function(m, color)
	local h = m.Head
	local s = h.Size
	pegar(m, h, "Pelo", Vector3.new(s.X * 1.06, s.Y * 0.22, s.Z * 1.06), C(0, s.Y * 0.43, 0), color)
	pegar(m, h, "Pelo", Vector3.new(s.X * 1.06, s.Y * 0.65, s.Z * 0.2), C(0, s.Y * 0.13, s.Z * 0.45), color)
end

PIEZAS.PeloDespeinado = function(m, color)
	PIEZAS.PeloCorto(m, color)
	local h = m.Head
	local s = h.Size
	pegar(m, h, "Flequillo", Vector3.new(s.X * 0.85, s.Y * 0.16, s.Z * 0.14), C(s.X * 0.06, s.Y * 0.33, -s.Z * 0.5) * CFrame.Angles(0, 0, math.rad(-6)), color)
	for i, d in ipairs({ { -0.25, 15 }, { 0.05, -10 }, { 0.3, 20 } }) do
		pegar(m, h, "Mechon" .. i, Vector3.new(s.X * 0.28, s.Y * 0.18, s.Z * 0.35), C(s.X * d[1], s.Y * 0.56, -s.Z * 0.1 * i) * CFrame.Angles(math.rad(d[2]), math.rad(d[2] * 2), math.rad(d[2])), color)
	end
end

PIEZAS.PeloRapado = function(m, color)
	local h = m.Head
	local s = h.Size
	pegar(m, h, "Pelo", Vector3.new(s.X * 1.02, s.Y * 0.08, s.Z * 1.02), C(0, s.Y * 0.47, 0), color)
	pegar(m, h, "Pelo", Vector3.new(s.X * 1.02, s.Y * 0.5, s.Z * 0.06), C(0, s.Y * 0.2, s.Z * 0.49), color)
end

PIEZAS.Gorra = function(m, color, _, atras)
	local h = m.Head
	local s = h.Size
	pegar(m, h, "GorraCopa", Vector3.new(s.X * 1.1, s.Y * 0.3, s.Z * 1.1), C(0, s.Y * 0.5, 0), color)
	local z = atras and s.Z * 0.75 or -s.Z * 0.75
	pegar(m, h, "GorraVisera", Vector3.new(s.X * 0.8, s.Y * 0.06, s.Z * 0.5), C(0, s.Y * 0.38, z), color)
end

PIEZAS.GorraAtras = function(m, color, detalle)
	PIEZAS.Gorra(m, color, detalle, true)
end

PIEZAS.Gafas = function(m, color)
	local h = m.Head
	local s = h.Size
	for _, lado in ipairs({ -1, 1 }) do
		pegar(m, h, "Lente", Vector3.new(s.X * 0.28, s.Y * 0.2, 0.05), C(lado * s.X * 0.17, s.Y * 0.07, -s.Z * 0.52), color)
	end
	pegar(m, h, "Puente", Vector3.new(s.X * 0.1, 0.05, 0.05), C(0, s.Y * 0.1, -s.Z * 0.52), color)
end

PIEZAS.Barba = function(m, color)
	local h = m.Head
	local s = h.Size
	pegar(m, h, "Barba", Vector3.new(s.X * 0.86, s.Y * 0.26, s.Z * 0.2), C(0, -s.Y * 0.38, -s.Z * 0.42), color)
	pegar(m, h, "Patilla", Vector3.new(s.X * 1.02, s.Y * 0.35, s.Z * 0.3), C(0, -s.Y * 0.2, -s.Z * 0.15), color)
end

PIEZAS.Capucha = function(m, color)
	local t = m.UpperTorso
	local s = t.Size
	pegar(m, t, "Capucha", Vector3.new(s.X * 0.7, s.Y * 0.3, s.Z * 0.35), C(0, s.Y * 0.38, s.Z * 0.6), color)
end

PIEZAS.Cuello = function(m, color)
	local t = m.UpperTorso
	local s = t.Size
	pegar(m, t, "Cuello", Vector3.new(s.X * 0.55, s.Y * 0.08, s.Z * 1.04), C(0, s.Y * 0.47, 0), color)
end

PIEZAS.Abertura = function(m, _, detalle)
	local t = m.UpperTorso
	local s = t.Size
	pegar(m, t, "Abertura", Vector3.new(s.X * 0.3, s.Y * 0.98, 0.06), C(0, 0, -s.Z * 0.51), detalle or BLANCO)
end

PIEZAS.Rayas = function(m, _, detalle)
	local t = m.UpperTorso
	local s = t.Size
	for i, y in ipairs({ 0.22, -0.08, -0.38 }) do
		pegar(m, t, "Raya" .. i, Vector3.new(s.X * 1.03, s.Y * 0.1, s.Z * 1.03), C(0, s.Y * y, 0), detalle or BLANCO)
	end
end

PIEZAS.Cinturon = function(m, color)
	local t = m.LowerTorso
	local s = t.Size
	pegar(m, t, "Cinturon", Vector3.new(s.X * 1.03, s.Y * 0.22, s.Z * 1.03), C(0, s.Y * 0.36, 0), color)
end

PIEZAS.Barriga = function(m, color)
	local t = m.UpperTorso
	local s = t.Size
	local d = math.min(s.X * 0.72, s.Y * 1.1)
	pegar(m, t, "Barriga", Vector3.new(d, d, d), C(0, -s.Y * 0.2, -s.Z * 0.18), color, Enum.PartType.Ball)
end

PIEZAS.Mochila = function(m, color)
	local t = m.UpperTorso
	local s = t.Size
	pegar(m, t, "Mochila", Vector3.new(s.X * 0.7, s.Y * 0.85, s.Z * 0.5), C(0, -s.Y * 0.05, s.Z * 0.72), color)
end

--==============================================================================
-- PRENDAS (qué partes del cuerpo se colorean y qué piezas se añaden)
--==============================================================================

-- Brazos: "Ninguno" (sin mangas), "Superior" (manga corta), "Completo" (manga larga)
Atuendos.Superiores = {
	Camiseta = { Brazos = "Superior" },
	MangaLarga = { Brazos = "Completo" },
	Sudadera = { Brazos = "Completo", Extras = { "Capucha" } },
	Polo = { Brazos = "Superior", Extras = { "Cuello" } },
	Tirantes = { Brazos = "Ninguno" },
	Chaqueta = { Brazos = "Completo", Extras = { "Abertura" } }, -- ColorDetalle = camiseta de debajo
	CamisetaRayas = { Brazos = "Superior", Extras = { "Rayas" } }, -- ColorDetalle = color de las rayas
}

-- Piernas: "Superior" (pantalón corto) o "Completo"
Atuendos.Inferiores = {
	Pantalon = { Piernas = "Completo" },
	Corto = { Piernas = "Superior" },
}

local CUERPO = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"RightUpperArm",
	"LeftLowerArm",
	"RightLowerArm",
	"LeftHand",
	"RightHand",
	"LeftUpperLeg",
	"RightUpperLeg",
	"LeftLowerLeg",
	"RightLowerLeg",
	"LeftFoot",
	"RightFoot",
}

local function colorear(modelo, nombres, color)
	for _, n in ipairs(nombres) do
		local p = modelo:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			p.Color = color
		end
	end
end

local function pieza(modelo, nombre, color, detalle)
	local f = PIEZAS[nombre]
	if not f then
		warn(("[Atuendos] Pieza desconocida: '%s'"):format(tostring(nombre)))
		return
	end
	local ok, err = pcall(f, modelo, color, detalle)
	if not ok then
		warn(("[Atuendos] No se pudo añadir '%s': %s"):format(nombre, tostring(err)))
	end
end

-- Viste un modelo R15 ya construido según la definición de DefPersonajes.
function Atuendos.Vestir(modelo, def)
	local piel = def.Piel or Color3.fromRGB(255, 204, 153)
	if type(def.Cara) ~= "number" then
		Atuendos.CabezaClasica(modelo)
	end
	colorear(modelo, CUERPO, piel)

	-- Parte de arriba
	local sup = def.Superior or {}
	local prendaSup = Atuendos.Superiores[sup.Prenda or "Camiseta"] or Atuendos.Superiores.Camiseta
	local colorSup = sup.Color or Color3.fromRGB(13, 105, 172)
	colorear(modelo, { "UpperTorso" }, colorSup)
	if prendaSup.Brazos ~= "Ninguno" then
		colorear(modelo, { "LeftUpperArm", "RightUpperArm" }, colorSup)
	end
	if prendaSup.Brazos == "Completo" then
		colorear(modelo, { "LeftLowerArm", "RightLowerArm" }, colorSup)
	end

	-- Parte de abajo
	local inf = def.Inferior or {}
	local prendaInf = Atuendos.Inferiores[inf.Prenda or "Pantalon"] or Atuendos.Inferiores.Pantalon
	local colorInf = inf.Color or Color3.fromRGB(40, 50, 70)
	colorear(modelo, { "LowerTorso", "LeftUpperLeg", "RightUpperLeg" }, colorInf)
	if prendaInf.Piernas == "Completo" then
		colorear(modelo, { "LeftLowerLeg", "RightLowerLeg" }, colorInf)
	end

	-- Calzado
	colorear(modelo, { "LeftFoot", "RightFoot" }, def.Calzado or Color3.fromRGB(40, 40, 40))

	-- Piezas extra de las prendas
	for _, extra in ipairs(prendaSup.Extras or {}) do
		pieza(modelo, extra, colorSup, sup.ColorDetalle)
	end

	-- Pelo
	if def.Pelo and def.Pelo.Estilo and def.Pelo.Estilo ~= "Ninguno" then
		pieza(modelo, "Pelo" .. def.Pelo.Estilo, def.Pelo.Color or OSCURO)
	end

	-- Accesorios
	for _, acc in ipairs(def.Accesorios or {}) do
		local color = acc.Color
		if acc.Tipo == "Barriga" then
			color = color or colorSup
		end
		pieza(modelo, acc.Tipo, color or OSCURO, acc.ColorDetalle)
	end

	-- Cara
	if def.Cara and type(def.Cara) ~= "number" and modelo:FindFirstChild("Head") then
		Atuendos.CrearCara(modelo.Head, def.Cara)
	end
end

return Atuendos
