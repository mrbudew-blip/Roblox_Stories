--[[
	FABRICAPERSONAJES · Construye los modelos de personaje a partir de DefPersonajes
	Studio: ReplicatedStorage > StoryTemplate > Modulos > FabricaPersonajes

	Lo usan el instalador (en modo edición) y StoryServer (al pulsar Play, solo
	si falta algún personaje). Usa Players:CreateHumanoidModelFromDescription,
	que solo funciona en el servidor o en la barra de comandos de Studio.
]]

local Players = game:GetService("Players")

local Fabrica = {}

local CARA_POR_DEFECTO = "rbxasset://textures/face.png"

function Fabrica.Descripcion(def)
	local d = Instance.new("HumanoidDescription")
	local piel = def.Piel or Color3.fromRGB(255, 204, 153)
	local brazos = def.Brazos or piel
	local piernas = def.Pantalon or Color3.fromRGB(40, 50, 70)
	d.HeadColor = piel
	d.TorsoColor = def.Camiseta or Color3.fromRGB(13, 105, 172)
	d.LeftArmColor = brazos
	d.RightArmColor = brazos
	d.LeftLegColor = piernas
	d.RightLegColor = piernas

	-- Proporciones clásicas
	d.BodyTypeScale = 0
	d.ProportionScale = 0
	d.HeightScale = def.Altura or 1
	d.WidthScale = def.Anchura or 1
	d.DepthScale = def.Anchura or 1
	d.HeadScale = def.Cabeza or 1

	if def.Cara then
		d.Face = tonumber(def.Cara) or 0
	end
	if def.Camisa then
		d.Shirt = tonumber(def.Camisa) or 0
	end
	if def.Pantalones then
		d.Pants = tonumber(def.Pantalones) or 0
	end
	if def.Estampado then
		d.GraphicTShirt = tonumber(def.Estampado) or 0
	end
	if def.Pelo then
		d.HairAccessory = tostring(def.Pelo)
	end
	if def.Sombrero then
		d.HatAccessory = tostring(def.Sombrero)
	end
	if def.Gafas then
		d.FaceAccessory = tostring(def.Gafas)
	end
	return d
end

function Fabrica.Construir(nombre, def)
	local modelo = Players:CreateHumanoidModelFromDescription(Fabrica.Descripcion(def), Enum.HumanoidRigType.R15)
	modelo.Name = nombre
	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	local humanoid = modelo:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	-- Asegura que la cabeza tenga cara
	local cabeza = modelo:FindFirstChild("Head")
	if cabeza and not cabeza:FindFirstChildOfClass("Decal") then
		local cara = Instance.new("Decal")
		cara.Name = "face"
		cara.Texture = CARA_POR_DEFECTO
		cara.Face = Enum.NormalId.Front
		cara.Parent = cabeza
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
