--[[
	CONSTRUCTOROBJETOS · Genera los objetos (props) básicos
	Studio: ReplicatedStorage > StoryTemplate > Herramientas > ConstructorObjetos

	Cada objeto es un Model pequeño (1-2 Parts, sin texturas) con:
	  · PrimaryPart = la pieza principal (por ahí se agarra).
	  · Atributo "OffsetAgarre" (CFrame) = cómo se coloca en la mano derecha.

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
end

return Constructor
