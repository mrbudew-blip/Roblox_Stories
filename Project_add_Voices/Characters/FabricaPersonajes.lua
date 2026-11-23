--[[
	FABRICAPERSONAJES · Construye los modelos de personaje a partir de DefPersonajes
	Studio: ReplicatedStorage > StoryTemplate > Modulos > FabricaPersonajes

	Lo usan el instalador (en modo edición) y StoryServer (al pulsar Play, solo
	si falta algún personaje). Usa Players:CreateHumanoidModelFromDescription
	(cuerpo, piel y escalas) y después el módulo Atuendos (ropa, pelo, cara...).
	Solo funciona en el servidor o en la barra de comandos de Studio.
]]

local Players = game:GetService("Players")

local Fabrica = {}

local CARA_POR_DEFECTO = "rbxasset://textures/face.png"

-- Se carga al usarse (el módulo Atuendos está junto a este en Modulos)
local cacheAtuendos = nil
local function Atuendos()
	if not cacheAtuendos then
		cacheAtuendos = require(script.Parent:WaitForChild("Atuendos"))
	end
	return cacheAtuendos
end

-- Escalas del cuerpo. Acepta def.Cuerpo = { Altura, Anchura, Profundidad, Cabeza }
-- (y, por compatibilidad, def.Altura / def.Anchura / def.Cabeza).
local function escalas(def)
	local c = def.Cuerpo or {}
	return {
		Altura = c.Altura or def.Altura or 1,
		Anchura = c.Anchura or def.Anchura or 1,
		Profundidad = c.Profundidad or c.Anchura or def.Anchura or 1,
		Cabeza = c.Cabeza or def.Cabeza or 1,
	}
end

-- Compatibilidad con el formato antiguo (Camiseta / Brazos / Pantalon)
local function normalizar(def)
	local d = {}
	for k, v in pairs(def) do
		d[k] = v
	end
	if not d.Superior and d.Camiseta then
		d.Superior = { Prenda = (d.Brazos == d.Camiseta) and "MangaLarga" or "Camiseta", Color = d.Camiseta }
	end
	if not d.Inferior and d.Pantalon then
		d.Inferior = { Prenda = "Pantalon", Color = d.Pantalon }
	end
	return d
end

function Fabrica.Descripcion(def)
	local d = Instance.new("HumanoidDescription")
	local piel = def.Piel or Color3.fromRGB(255, 204, 153)
	d.HeadColor = piel
	d.TorsoColor = piel
	d.LeftArmColor = piel
	d.RightArmColor = piel
	d.LeftLegColor = piel
	d.RightLegColor = piel

	-- Proporciones clásicas (bloques) con la complexión de cada personaje
	local e = escalas(def)
	d.BodyTypeScale = 0
	d.ProportionScale = 0
	d.HeightScale = e.Altura
	d.WidthScale = e.Anchura
	d.DepthScale = e.Profundidad
	d.HeadScale = e.Cabeza

	-- Cara del catálogo (solo si Cara es un número)
	if type(def.Cara) == "number" then
		d.Face = def.Cara
	end
	return d
end

function Fabrica.Construir(nombre, def)
	def = normalizar(def)
	local modelo = Players:CreateHumanoidModelFromDescription(Fabrica.Descripcion(def), Enum.HumanoidRigType.R15)
	modelo.Name = nombre
	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("BodyColors") then
			d:Destroy()
		end
	end
	local humanoid = modelo:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end

	-- Ropa, pelo, accesorios y cara (Atuendos)
	Atuendos().Vestir(modelo, def)

	-- Si no tiene cara propia, pone la cara clásica
	local cabeza = modelo:FindFirstChild("Head")
	if cabeza and not cabeza:FindFirstChild("Cara") and not cabeza:FindFirstChildOfClass("Decal") then
		local cara = Instance.new("Decal")
		cara.Name = "face"
		cara.Texture = CARA_POR_DEFECTO
		cara.Face = Enum.NormalId.Front
		cara.Parent = cabeza
	end
	if def.Personalidad then
		modelo:SetAttribute("Personalidad", def.Personalidad)
	end
	local raiz = modelo:FindFirstChild("HumanoidRootPart")
	if raiz then
		raiz.Anchored = true
	end
	return modelo
end

--[[
	Construye todos los personajes de "defs" dentro de "carpeta".
	defs         → tabla de DefPersonajes (si es nil, se carga el módulo)
	soloFaltantes → true = no toca los que ya existen
]]
function Fabrica.ConstruirTodos(carpeta, defs, soloFaltantes)
	defs = defs or require(script.Parent:WaitForChild("DefPersonajes"))
	local nombres = {}
	for nombre in pairs(defs) do
		table.insert(nombres, nombre)
	end
	table.sort(nombres)
	for i, nombre in ipairs(nombres) do
		local existente = carpeta:FindFirstChild(nombre)
		if not (soloFaltantes and existente) then
			local ok, modelo = pcall(Fabrica.Construir, nombre, defs[nombre])
			if ok then
				if existente then
					existente:Destroy()
				end
				modelo:PivotTo(CFrame.new((i - 1) * 5, 3, 0))
				modelo.Parent = carpeta
			else
				warn(("[Personajes] No se pudo crear '%s': %s"):format(nombre, tostring(modelo)))
			end
		end
	end
end

return Fabrica
