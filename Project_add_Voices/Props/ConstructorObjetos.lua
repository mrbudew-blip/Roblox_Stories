--[[
	CONSTRUCTOROBJETOS · Genera los objetos (props) básicos
	Studio: ReplicatedStorage > StoryTemplate > Herramientas > ConstructorObjetos

	Cada objeto es un Model pequeño (1-2 Parts, sin texturas) con:
	  · PrimaryPart = la pieza principal (por ahí se agarra).
	  · Atributo "OffsetAgarre" (CFrame) = cómo se coloca en la mano derecha.
	  · Atributo "Plano" = true en hojas y notas: su cara grande es la frontal (-Z),
	    se pegan planas en paredes y mesas y caen como un papel.

	Puedes añadir tus propios objetos directamente en StoryTemplate > Objetos:
	cualquier Model sirve (si no tiene PrimaryPart se usa su primera pieza).
]]

local Constructor = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function nuevo(carpeta, nombre, offset)
	local viejo = carpeta:FindFirstChild(nombre)
	if viejo then
		viejo:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = nombre
	m:SetAttribute("OffsetAgarre", offset or CFrame.new())
	m.Parent = carpeta
	return m
end

local function plano(m)
	m:SetAttribute("Plano", true)
	return m
end

-- Texto impreso o escrito en la cara frontal de una pieza
local function escrito(p, texto, fuente, color, cara)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Escrito"
	sg.Face = cara or Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 120
	sg.LightInfluence = 1
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.86, 0.8)
	t.Position = UDim2.fromScale(0.07, 0.1)
	t.Font = fuente
	t.TextScaled = true
	t.TextWrapped = true
	t.TextColor3 = color
	t.Text = texto
	t.Parent = sg
	sg.Parent = p
end

local function pieza(m, nombre, tam, cf, color)
	local p = Instance.new("Part")
	p.Name = nombre
	p.Size = tam
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

function Constructor.ConstruirTodos(carpeta)
	-- Caja de cartón
	local m = nuevo(carpeta, "Caja", CFrame.new(0, 0.3, -0.45))
	m.PrimaryPart = pieza(m, "Cuerpo", Vector3.new(1.3, 1, 1.1), CFrame.new(), rgb(190, 150, 100))
	pieza(m, "Cinta", Vector3.new(0.3, 1.02, 1.12), CFrame.new(), rgb(225, 205, 150))

	-- Sobre / carta
	m = nuevo(carpeta, "Sobre", CFrame.new(0, 0.2, -0.35) * CFrame.Angles(math.rad(70), 0, 0))
	m.PrimaryPart = pieza(m, "Papel", Vector3.new(1.1, 0.06, 0.75), CFrame.new(), rgb(245, 240, 225))
	pieza(m, "Sello", Vector3.new(0.22, 0.08, 0.22), CFrame.new(0, 0.01, 0), rgb(180, 30, 30))

	-- Teléfono móvil
	m = nuevo(carpeta, "Telefono", CFrame.new(0, 0.15, -0.25) * CFrame.Angles(math.rad(60), 0, 0))
	m.PrimaryPart = pieza(m, "Carcasa", Vector3.new(0.45, 0.06, 0.85), CFrame.new(), rgb(25, 25, 30))
	pieza(m, "Pantalla", Vector3.new(0.39, 0.065, 0.75), CFrame.new(0, 0.002, 0), rgb(60, 120, 200))

	-- Libro
	m = nuevo(carpeta, "Libro", CFrame.new(0, 0.2, -0.4))
	m.PrimaryPart = pieza(m, "Tapas", Vector3.new(0.9, 0.25, 1.2), CFrame.new(), rgb(150, 40, 45))
	pieza(m, "Paginas", Vector3.new(0.86, 0.2, 1.1), CFrame.new(0.03, 0, 0), rgb(245, 240, 225))

	-- Bolsa
	m = nuevo(carpeta, "Bolsa", CFrame.new(0, -0.2, -0.5))
	m.PrimaryPart = pieza(m, "Cuerpo", Vector3.new(1.2, 1.3, 0.6), CFrame.new(), rgb(205, 175, 125))
	pieza(m, "Borde", Vector3.new(1.22, 0.15, 0.62), CFrame.new(0, 0.58, 0), rgb(150, 115, 70))

	--==========================================================================
	-- HISTORIA: EL ORIGEN DEL POST-IT
	-- Hojas y notas: finas en Z, cara frontal = -Z (en la mano mira hacia delante).
	--==========================================================================

	-- Folio con unas líneas de texto
	m = plano(nuevo(carpeta, "Papel", CFrame.new(0, 0.5, -0.1)))
	m.PrimaryPart = pieza(m, "Hoja", Vector3.new(1, 1.3, 0.03), CFrame.new(), rgb(248, 248, 245))
	for i, y in ipairs({ 0.4, 0.2, 0, -0.2 }) do
		pieza(m, "Linea" .. i, Vector3.new(0.7 - i * 0.05, 0.04, 0.032), CFrame.new(-0.05, y, 0), rgb(150, 150, 160))
	end

	-- Hoja con el pegamento de Spencer (crema, con la franja adhesiva arriba)
	m = plano(nuevo(carpeta, "PapelAdhesivo", CFrame.new(0, 0.35, -0.1)))
	m.PrimaryPart = pieza(m, "Hoja", Vector3.new(0.75, 0.75, 0.03), CFrame.new(), rgb(250, 241, 205))
	pieza(m, "Franja", Vector3.new(0.75, 0.13, 0.034), CFrame.new(0, 0.31, 0), rgb(232, 216, 160))

	-- Nota adhesiva amarilla (Post-it)
	m = plano(nuevo(carpeta, "NotaAmarilla", CFrame.new(0, 0.3, -0.1)))
	m.PrimaryPart = pieza(m, "Hoja", Vector3.new(0.6, 0.6, 0.03), CFrame.new(), rgb(255, 225, 60))
	pieza(m, "Franja", Vector3.new(0.6, 0.1, 0.034), CFrame.new(0, 0.25, 0), rgb(242, 205, 45))

	-- Marcapáginas de papel
	m = plano(nuevo(carpeta, "Marcapaginas", CFrame.new(0, 0.45, -0.1)))
	m.PrimaryPart = pieza(m, "Tira", Vector3.new(0.3, 1.1, 0.03), CFrame.new(), rgb(246, 246, 240))
	pieza(m, "Borla", Vector3.new(0.1, 0.25, 0.04), CFrame.new(0, -0.62, 0), rgb(180, 40, 45))

	-- Bloc de notas amarillas
	m = plano(nuevo(carpeta, "BlocNotas", CFrame.new(0, 0.4, -0.25)))
	m.PrimaryPart = pieza(m, "Bloque", Vector3.new(0.9, 0.9, 0.3), CFrame.new(), rgb(250, 215, 50))
	pieza(m, "HojaSuperior", Vector3.new(0.9, 0.9, 0.02), CFrame.new(0, 0, -0.155), rgb(255, 230, 80))
	pieza(m, "Canto", Vector3.new(0.92, 0.08, 0.31), CFrame.new(0, 0.42, 0), rgb(235, 195, 40))

	-- Cancionero cerrado (granate con franja dorada)
	m = nuevo(carpeta, "Cancionero", CFrame.new(0, 0.1, -0.5) * CFrame.Angles(math.rad(-80), 0, 0))
	m.PrimaryPart = pieza(m, "Tapa", Vector3.new(0.95, 0.28, 1.25), CFrame.new(), rgb(110, 30, 40))
	pieza(m, "Paginas", Vector3.new(0.9, 0.24, 1.2), CFrame.new(0.04, 0, 0), rgb(245, 238, 220))
	pieza(m, "Franja", Vector3.new(0.96, 0.29, 0.12), CFrame.new(0, 0, -0.42), rgb(210, 170, 70))

	-- Cancionero abierto sobre la mesa
	m = nuevo(carpeta, "CancioneroAbierto", CFrame.new(0, 0.1, -0.5) * CFrame.Angles(math.rad(-70), 0, 0))
	m.PrimaryPart = pieza(m, "Tapas", Vector3.new(1.95, 0.05, 1.3), CFrame.new(), rgb(110, 30, 40))
	pieza(m, "PaginasIzq", Vector3.new(0.92, 0.12, 1.2), CFrame.new(-0.48, 0.08, 0) * CFrame.Angles(0, 0, math.rad(4)), rgb(245, 238, 220))
	pieza(m, "PaginasDer", Vector3.new(0.92, 0.12, 1.2), CFrame.new(0.48, 0.08, 0) * CFrame.Angles(0, 0, math.rad(-4)), rgb(245, 238, 220))
	pieza(m, "Lomo", Vector3.new(0.05, 0.14, 1.2), CFrame.new(0, 0.07, 0), rgb(200, 190, 170))
	for i, z in ipairs({ -0.35, -0.15, 0.05, 0.25 }) do
		pieza(m, "Pentagrama" .. i, Vector3.new(0.7, 0.01, 0.03), CFrame.new(-0.5, 0.145, z), rgb(120, 110, 100))
		pieza(m, "Pentagrama" .. i, Vector3.new(0.7, 0.01, 0.03), CFrame.new(0.5, 0.145, z), rgb(120, 110, 100))
	end

	-- Bote de pegamento con pincel
	m = nuevo(carpeta, "Pegamento", CFrame.new(0, 0.2, -0.3))
	m.PrimaryPart = pieza(m, "Bote", Vector3.new(0.6, 0.55, 0.55), CFrame.Angles(0, 0, math.pi / 2), rgb(175, 115, 45))
	m.PrimaryPart.Shape = Enum.PartType.Cylinder
	m.PrimaryPart.Size = Vector3.new(0.6, 0.55, 0.55)
	m.PrimaryPart.Transparency = 0.15
	local etiqueta = pieza(m, "Etiqueta", Vector3.new(0.25, 0.57, 0.57), CFrame.Angles(0, 0, math.pi / 2), rgb(245, 245, 240))
	etiqueta.Shape = Enum.PartType.Cylinder
	etiqueta.Size = Vector3.new(0.25, 0.57, 0.57)
	local tapa = pieza(m, "Tapa", Vector3.new(0.12, 0.6, 0.6), CFrame.new(0, 0.36, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(30, 30, 30))
	tapa.Shape = Enum.PartType.Cylinder
	tapa.Size = Vector3.new(0.12, 0.6, 0.6)
	pieza(m, "Pincel", Vector3.new(0.07, 0.6, 0.07), CFrame.new(0.08, 0.55, 0) * CFrame.Angles(0, 0, math.rad(-15)), rgb(150, 100, 55))

	-- Caja de producto (notas adhesivas listas para las tiendas)
	m = nuevo(carpeta, "CajaNotas", CFrame.new(0, 0.3, -0.5))
	m.PrimaryPart = pieza(m, "Caja", Vector3.new(1.6, 1, 1.2), CFrame.new(), rgb(250, 205, 40))
	local franja = pieza(m, "Franja", Vector3.new(1.62, 0.35, 1.22), CFrame.new(0, 0, 0), rgb(255, 245, 220))
	escrito(franja, "NOTAS ADHESIVAS", Enum.Font.GothamBold, rgb(60, 50, 30), Enum.NormalId.Back)
	escrito(franja, "NOTAS ADHESIVAS", Enum.Font.GothamBold, rgb(60, 50, 30), Enum.NormalId.Front)
end

return Constructor
