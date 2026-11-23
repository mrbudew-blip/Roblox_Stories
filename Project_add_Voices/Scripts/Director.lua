--[[
	DIRECTOR · Reproduce una escena paso a paso
	Studio: ReplicatedStorage > StoryTemplate > Modulos > Director

	Lo arranca el LocalScript StarterPlayerScripts > StoryRunner.
	Todo ocurre en el cliente: personajes, objetos y escenario son copias
	locales, sin física ni red, para que el coste sea mínimo.

	Dos formas de ordenar los pasos (se pueden mezclar):
	  · Secuencial: cada paso espera a que termine el anterior (Paralelo = true para no esperar).
	  · Línea de tiempo: un paso con  T = segundos  se ejecuta exactamente en ese segundo
	    de la escena (contado desde el primer paso) y no bloquea a los siguientes.
	    Es la forma recomendada para sincronizar con audio: los tiempos no se desvían.

	La lista completa de acciones está en README.md. No hace falta editar este
	archivo para crear escenas nuevas.
]]

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")

local Modulos = script.Parent
local Raiz = Modulos.Parent
local Config = require(Raiz:WaitForChild("Config"))
local Actor = require(Modulos:WaitForChild("Actor"))
local Camaras = require(Modulos:WaitForChild("Camaras"))
local Guias = require(Modulos:WaitForChild("Guias"))
local Efectos = require(Modulos:WaitForChild("Efectos"))

local Voces = nil
do
	local m = Modulos:FindFirstChild("Voces")
	if m then
		local ok, res = pcall(require, m)
		if ok then
			Voces = res
		else
			warn("[Historia] Error al leer Modulos > Voces: " .. tostring(res))
		end
	end
end

local NOMBRE_RENDER = "CamaraHistoria"

local LUZ_ORIGINAL = {
	ClockTime = Lighting.ClockTime,
	Brightness = Lighting.Brightness,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
}

local Director = {}

local function plano(v)
	local p = Vector3.new(v.X, 0, v.Z)
	if p.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return p.Unit
end

local function suavizar(a)
	return a * a * (3 - 2 * a)
end

local function fijarObjeto(objeto, anclado)
	for _, d in ipairs(objeto:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = anclado
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
end

-- Gesto adecuado para alcanzar algo según su altura respecto al personaje.
local function gestoPorAltura(actor, y)
	local d = y - actor.Raiz.Position.Y
	if d > 1 then
		return "Pegar"
	elseif d > -1.9 then
		return "AlcanzarMesa"
	end
	return "Agacharse"
end

--==============================================================================
-- CONTEXTO: estado de la escena en reproducción
--==============================================================================

local Contexto = {}
Contexto.__index = Contexto

function Contexto.new(escena)
	local self = setmetatable({}, Contexto)
	self.Escena = escena
	self.Actores = {} -- rol -> Actor
	self.Orden = {} -- roles en orden de aparición
	self.Objetos = {} -- nombre -> Model
	self.EntornoObj = {} -- Model -> nombre del entorno donde está colocado
	self.Memoria = {} -- entorno -> { Actores, Objetos } al salir de él
	self.Sonidos = {}
	self.SonidosVoz = {}
	self.Inicio = nil
	local viejo = workspace:FindFirstChild("Escenario")
	if viejo then
		viejo:Destroy()
	end
	self.Carpeta = Instance.new("Folder")
	self.Carpeta.Name = "Escenario"
	self.Carpeta.Parent = workspace
	return self
end

-- Segundos desde el primer paso de la escena.
function Contexto:Reloj()
	if not self.Inicio then
		return 0
	end
	return os.clock() - self.Inicio
end

-- ENTORNO ----------------------------------------------------------------------

function Contexto:EnMano(objeto)
	for _, a in pairs(self.Actores) do
		if a.Objeto == objeto then
			return a
		end
	end
	return nil
end

--[[
	Cambia de escenario. Cada entorno "recuerda" quién y qué había al salir:
	al volver, los personajes y objetos aparecen donde estaban (útil para
	flashbacks y para alternar escenarios). Al entrar en un entorno nuevo no
	hay nadie: coloca a los personajes con Colocar / Caminar / Sentar.
]]
function Contexto:CargarEntorno(nombre)
	local plantilla = Raiz.Entornos:FindFirstChild(tostring(nombre))
	if not plantilla then
		error(("No existe el entorno '%s' en StoryTemplate > Entornos"):format(tostring(nombre)), 0)
	end
	if self.Entorno then
		local mem = { Actores = {}, Objetos = {} }
		for _, a in pairs(self.Actores) do
			if a.Modelo.Parent then
				mem.Actores[a] = { CFrame = a.Raiz.CFrame, Piernas = a.PosturaPiernas }
				self:OcultarActor(a)
			end
		end
		for _, objeto in pairs(self.Objetos) do
			if objeto.Parent and not self:EnMano(objeto) then
				mem.Objetos[objeto] = true
				objeto.Parent = nil
			end
		end
		self.Memoria[self.Entorno.Name] = mem
		self.Entorno:Destroy()
	end

	local entorno = plantilla:Clone()
	local marcas = entorno:FindFirstChild("Marcas")
	if marcas then
		for _, d in ipairs(marcas:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CastShadow = false
			elseif d:IsA("LayerCollector") then
				d.Enabled = false
			end
		end
	end
	entorno.Parent = self.Carpeta
	self.Entorno = entorno

	-- Iluminación y tono del entorno (atributos del Model)
	Lighting.ClockTime = entorno:GetAttribute("Hora") or LUZ_ORIGINAL.ClockTime
	Lighting.Brightness = entorno:GetAttribute("Brillo") or LUZ_ORIGINAL.Brightness
	Lighting.Ambient = entorno:GetAttribute("Ambiente") or LUZ_ORIGINAL.Ambient
	Lighting.OutdoorAmbient = entorno:GetAttribute("AmbienteExterior") or LUZ_ORIGINAL.OutdoorAmbient
	Efectos.TonoEntorno(entorno:GetAttribute("Tinte"), entorno:GetAttribute("Saturacion"))

	local audiencia = self:Marca("Audiencia")
	self.Audiencia = audiencia and audiencia.Position or nil

	-- Restaura lo que había la última vez que se estuvo aquí
	local mem = self.Memoria[entorno.Name]
	if mem then
		for a, estado in pairs(mem.Actores) do
			if not a.Modelo.Parent then
				a:_cancelarMovimiento()
				a.Raiz.CFrame = estado.CFrame
				a.PosturaPiernas = estado.Piernas
				self:Mostrar(a)
				a:_postura(nil)
				a:_aplicar(0)
			end
		end
		for objeto in pairs(mem.Objetos) do
			if not objeto.Parent and self.EntornoObj[objeto] == entorno.Name then
				objeto.Parent = self.Carpeta
			end
		end
	end
end

function Contexto:Marca(nombre)
	local marcas = self.Entorno and self.Entorno:FindFirstChild("Marcas")
	return marcas and marcas:FindFirstChild(tostring(nombre)) or nil
end

-- ACTORES ----------------------------------------------------------------------

function Contexto:ObtenerActor(rol)
	local actor = self.Actores[rol]
	if actor then
		return actor
	end
	local reparto = self.Escena.Reparto or {}
	local nombreModelo = reparto[rol] or rol
	local plantilla = Raiz.Personajes:FindFirstChild(tostring(nombreModelo))
	if not plantilla then
		error(("No existe el personaje '%s' (rol '%s') en StoryTemplate > Personajes"):format(tostring(nombreModelo), tostring(rol)), 0)
	end
	local modelo = plantilla:Clone()
	modelo.Name = rol
	modelo.Parent = self.Carpeta
	actor = Actor.new(modelo, rol)
	self.Actores[rol] = actor
	table.insert(self.Orden, rol)
	return actor
end

function Contexto:ActorVisible(rol)
	local actor = self.Actores[rol]
	if not actor then
		error(("El actor '%s' todavía no está en escena: usa Colocar (o Posiciones) antes"):format(tostring(rol)), 0)
	end
	if not actor.Modelo.Parent then
		error(("El actor '%s' está oculto: usa Colocar para que vuelva"):format(tostring(rol)), 0)
	end
	return actor
end

function Contexto:ActoresVisibles()
	local lista = {}
	for _, rol in ipairs(self.Orden) do
		local a = self.Actores[rol]
		if a.Modelo.Parent then
			table.insert(lista, a)
		end
	end
	return lista
end

function Contexto:Mostrar(actor)
	if not actor.Modelo.Parent then
		actor.Modelo.Parent = self.Carpeta
		if actor.Objeto then
			actor.Objeto.Parent = self.Carpeta
		end
		actor:Reanudar()
	end
end

function Contexto:OcultarActor(actor)
	actor.Modelo.Parent = nil
	if actor.Objeto then
		actor.Objeto.Parent = nil
	end
end

-- POSICIONES -------------------------------------------------------------------

--[[
	Convierte un destino en un punto. "valor" puede ser:
	  · nombre de marca del entorno ("Pos_A", "Entrada_Izq", "Obj_1"...) → su base
	  · rol de un actor visible → se queda a "distancia" de él (3 por defecto)
	  · nombre de un objeto en escena → su cara de arriba (o a "distancia" si se camina hacia él)
	  · un Vector3
	Devuelve: posición, marca (si era una marca)
]]
function Contexto:Pos(valor, desde, distancia)
	if typeof(valor) == "Vector3" then
		return valor, nil
	end
	local nombre = tostring(valor)
	local actor = self.Actores[nombre]
	if actor and actor.Modelo.Parent then
		local p = actor:PosicionSuelo()
		if desde then
			return p + plano(desde - p) * (distancia or 3), nil
		end
		return p, nil
	end
	local objeto = self.Objetos[nombre]
	if objeto and objeto.Parent then
		local cf, tam = objeto:GetBoundingBox()
		if desde then
			local suelo = Vector3.new(cf.X, desde.Y, cf.Z)
			return suelo + plano(desde - suelo) * (distancia or 1.6), nil
		end
		return cf.Position + Vector3.new(0, tam.Y / 2, 0), nil
	end
	local marca = self:Marca(nombre)
	if marca then
		if marca:GetAttribute("Pared") then
			-- Para caminar hacia una marca de pared: un punto del suelo delante de ella
			local n = plano(marca.CFrame.LookVector)
			local y = desde and desde.Y or 0
			return Vector3.new(marca.Position.X, y, marca.Position.Z) + n * (distancia or 1.4), marca
		end
		return marca.Position - Vector3.new(0, marca.Size.Y / 2, 0), marca
	end
	error(
		("No encuentro '%s': no es una marca del entorno '%s', ni un actor visible, ni un objeto en escena"):format(
			nombre,
			self.Entorno and self.Entorno.Name or "?"
		),
		0
	)
end

-- Punto al que mirar: "Camara", un actor (su cabeza), una marca, un objeto o un Vector3.
function Contexto:PuntoMirada(valor)
	if valor == "Camara" then
		local e = self.EstadoCamara
		local ok, cf = pcall(function()
			return e.Calcular()
		end)
		if ok and typeof(cf) == "CFrame" then
			return cf.Position
		end
		return workspace.CurrentCamera.CFrame.Position
	end
	local actor = type(valor) == "string" and self.Actores[valor]
	if actor and actor.Modelo.Parent then
		return actor.Raiz.Position + Vector3.new(0, actor.AlturaCabeza, 0)
	end
	local objeto = type(valor) == "string" and self.Objetos[valor]
	if objeto and objeto.Parent then
		return objeto:GetBoundingBox().Position
	end
	local pos, marca = self:Pos(valor)
	if marca then
		return marca.Position
	end
	return pos
end

--[[
	Superficie sobre la que pegar o apoyar algo. Devuelve punto y normal:
	  · marca de pared (atributo Pared) → su centro y su cara frontal
	  · marca normal / Vector3          → hacia arriba
	  · objeto en escena                → su cara de arriba
]]
function Contexto:Superficie(destino, desplazamiento)
	local punto, normal
	if typeof(destino) == "Vector3" then
		punto, normal = destino, Vector3.yAxis
	else
		local nombre = tostring(destino)
		local objeto = self.Objetos[nombre]
		local marca = self:Marca(nombre)
		if objeto and objeto.Parent then
			local cf, tam = objeto:GetBoundingBox()
			punto, normal = cf.Position + Vector3.new(0, tam.Y / 2, 0), Vector3.yAxis
		elseif marca and marca:GetAttribute("Pared") then
			normal = marca.CFrame.LookVector
			punto = marca.Position - normal * (marca.Size.Z / 2)
		elseif marca then
			punto, normal = marca.Position - Vector3.new(0, marca.Size.Y / 2, 0), Vector3.yAxis
		else
			punto, normal = self:Pos(destino), Vector3.yAxis
		end
	end
	if typeof(desplazamiento) == "Vector3" then
		punto = punto + desplazamiento
	end
	return punto, normal
end

-- OBJETOS ----------------------------------------------------------------------

function Contexto:ObtenerObjeto(nombre)
	if self.Objetos[nombre] then
		return self.Objetos[nombre]
	end
	local def = (self.Escena.Objetos or {})[nombre]
	if type(def) ~= "table" then
		def = {}
	end
	local nombreModelo = def.Modelo or nombre
	local plantilla = Raiz.Objetos:FindFirstChild(tostring(nombreModelo))
	if not plantilla then
		error(("No existe el objeto '%s' en StoryTemplate > Objetos"):format(tostring(nombreModelo)), 0)
	end
	local objeto = plantilla:Clone()
	objeto.Name = nombre
	if not objeto.PrimaryPart then
		objeto.PrimaryPart = objeto:FindFirstChildWhichIsA("BasePart", true)
	end
	for _, d in ipairs(objeto:GetDescendants()) do
		if d:IsA("BasePart") and d ~= objeto.PrimaryPart then
			local w = Instance.new("WeldConstraint")
			w.Part0 = objeto.PrimaryPart
			w.Part1 = d
			w.Parent = d
		end
	end
	if typeof(def.Color) == "Color3" then
		objeto.PrimaryPart.Color = def.Color
		local franja = objeto:FindFirstChild("Franja")
		if franja and franja:IsA("BasePart") then
			franja.Color = def.Color:Lerp(Color3.new(0, 0, 0), 0.08)
		end
	end
	-- Texto escrito a mano en la cara frontal (notas, carteles...)
	if def.Texto then
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Escrito"
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 150
		sg.LightInfluence = 1
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(0.84, 0.74)
		l.Position = UDim2.fromScale(0.08, 0.16)
		l.Font = Enum.Font.PermanentMarker
		l.TextScaled = true
		l.TextWrapped = true
		l.TextColor3 = def.ColorTexto or Color3.fromRGB(30, 40, 110)
		l.Text = def.Texto
		l.Parent = sg
		sg.Parent = objeto.PrimaryPart
	end
	fijarObjeto(objeto, true)
	self.Objetos[nombre] = objeto
	return objeto
end

function Contexto:QuitarDeManos(objeto)
	for _, a in pairs(self.Actores) do
		if a.Objeto == objeto then
			a:Soltar()
		end
	end
end

--[[
	Coloca un objeto en una superficie.
	  · Pared: la cara frontal del objeto queda hacia fuera.
	  · Horizontal y objeto "Plano" (hojas, notas): tumbado, con el texto legible desde la cámara.
	  · Horizontal y objeto normal: de pie, mirando hacia "direccion".
]]
function Contexto:FijarEnSuperficie(objeto, punto, normal, direccion)
	self:QuitarDeManos(objeto)
	fijarObjeto(objeto, true)
	local tam = objeto:GetExtentsSize()
	local esPlano = objeto:GetAttribute("Plano") == true
	if math.abs(normal.Y) < 0.7 then
		objeto:PivotTo(CFrame.lookAt(punto, punto + normal) + normal * (tam.Z / 2 + 0.01))
	elseif esPlano then
		local arriba = direccion and -plano(direccion) or Vector3.new(0, 0, -1)
		objeto:PivotTo(CFrame.lookAt(punto, punto + Vector3.yAxis, arriba) + Vector3.new(0, tam.Z / 2 + 0.01, 0))
	else
		local dir = direccion and plano(direccion) or Vector3.new(0, 0, -1)
		objeto:PivotTo(CFrame.lookAt(punto, punto + dir))
		local cf, t = objeto:GetBoundingBox()
		objeto:PivotTo(objeto:GetPivot() + Vector3.new(0, punto.Y - (cf.Position.Y - t.Y / 2), 0))
	end
	objeto.Parent = self.Carpeta
	self.EntornoObj[objeto] = self.Entorno and self.Entorno.Name
end

function Contexto:ColocarObjeto(nombre, donde, desplazamiento)
	local objeto = self:ObtenerObjeto(nombre)
	local punto, normal = self:Superficie(donde, desplazamiento)
	local marca = type(donde) == "string" and self:Marca(donde)
	self:FijarEnSuperficie(objeto, punto, normal, marca and marca.CFrame.LookVector or nil)
	return objeto
end

function Contexto:DarObjeto(nombre, actor)
	local objeto = self:ObtenerObjeto(nombre)
	self:QuitarDeManos(objeto)
	objeto.Parent = self.Carpeta
	actor:Sostener(objeto)
	return objeto
end

-- Hace caer un objeto hasta el suelo (o hasta "destino") con vaivén de papel.
function Contexto:Caer(objeto, destino, tiempo)
	self:QuitarDeManos(objeto)
	fijarObjeto(objeto, true)
	objeto.Parent = self.Carpeta
	local azar = Random.new()
	local inicio = objeto:GetPivot()
	local punto
	if destino then
		punto = self:Superficie(destino)
	else
		punto = Vector3.new(inicio.X + azar:NextNumber(-0.5, 0.5), 0, inicio.Z + azar:NextNumber(0.4, 0.9))
	end
	local tam = objeto:GetExtentsSize()
	local giro = math.rad(azar:NextNumber(-35, 35))
	local final
	if objeto:GetAttribute("Plano") then
		local arriba = CFrame.Angles(0, giro, 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
		final = CFrame.lookAt(punto, punto + Vector3.yAxis, arriba) + Vector3.new(0, tam.Z / 2 + 0.01, 0)
	else
		final = CFrame.new(punto + Vector3.new(0, tam.Y / 2, 0)) * CFrame.Angles(0, giro, 0)
	end
	tiempo = tiempo or 0.9
	self.EntornoObj[objeto] = self.Entorno and self.Entorno.Name
	task.spawn(function()
		local t0 = os.clock()
		while objeto.Parent do
			local a = math.min((os.clock() - t0) / tiempo, 1)
			local pos = inicio.Position:Lerp(final.Position, a)
			pos = Vector3.new(pos.X, inicio.Y + (final.Y - inicio.Y) * a * a, pos.Z)
			local vaiven = math.sin(a * math.pi * 3) * 0.35 * (1 - a)
			local rot = inicio.Rotation:Lerp(final.Rotation, math.min(1, a * 1.3))
			objeto:PivotTo(CFrame.new(pos + Vector3.new(vaiven, 0, 0)) * rot * CFrame.Angles(vaiven * 0.8, 0, vaiven))
			if a >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		objeto:PivotTo(final)
	end)
	return tiempo
end

-- Aparece un objeto con un pequeño rebote (ideal para notas que "brotan").
function Contexto:Aparecer(nombre, donde, desplazamiento)
	local objeto = self:ColocarObjeto(nombre, donde, desplazamiento)
	local ok = pcall(function()
		objeto:ScaleTo(0.05)
	end)
	if ok then
		task.spawn(function()
			local t0 = os.clock()
			while objeto.Parent do
				local a = math.min((os.clock() - t0) / 0.28, 1)
				local e = a < 0.7 and (a / 0.7) * 1.15 or 1.15 - (a - 0.7) / 0.3 * 0.15
				objeto:ScaleTo(math.max(0.05, e))
				if a >= 1 then
					break
				end
				RunService.Heartbeat:Wait()
			end
			objeto:ScaleTo(1)
		end)
	end
	return objeto
end

-- SONIDO -----------------------------------------------------------------------

-- "nombre" puede ser un Sound de StoryTemplate > Audio, un id numérico o "rbxassetid://...".
function Contexto:Sonido(nombre, volumen, bucle)
	local plantilla = Raiz.Audio:FindFirstChild(tostring(nombre))
	local s
	if plantilla and plantilla:IsA("Sound") then
		s = plantilla:Clone()
	else
		s = Instance.new("Sound")
		local id = tostring(nombre)
		if id:match("^%d+$") then
			id = "rbxassetid://" .. id
		end
		s.SoundId = id
	end
	if s.SoundId == "" or not s.SoundId:match("%d") then
		warn(("[Historia] El sonido '%s' no tiene un SoundId válido; se omite"):format(tostring(nombre)))
		s:Destroy()
		return nil
	end
	if volumen then
		s.Volume = volumen
	end
	if bucle ~= nil then
		s.Looped = bucle
	end
	s.Parent = SoundService
	table.insert(self.Sonidos, s)
	return s
end

function Contexto:Duracion(sonido)
	local t = 0
	while not sonido.IsLoaded and t < 5 do
		t = t + task.wait(0.05)
	end
	return sonido.TimeLength / math.max(sonido.PlaybackSpeed, 0.01)
end

-- Sonido de una voz de Modulos > Voces (se precarga al empezar la escena).
function Contexto:SonidoVoz(nombre)
	if self.SonidosVoz[nombre] then
		return self.SonidosVoz[nombre]
	end
	local datos = Voces and Voces[nombre]
	if not datos or not datos.Id or datos.Id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "Voz_" .. nombre
	s.SoundId = datos.Id
	s.Volume = 1
	s.Parent = SoundService
	self.SonidosVoz[nombre] = s
	table.insert(self.Sonidos, s)
	return s
end

function Contexto:PrecargarVoces()
	if not Voces then
		return
	end
	local lista = {}
	for nombre, datos in pairs(Voces) do
		if type(datos) == "table" then
			local s = self:SonidoVoz(nombre)
			if s then
				table.insert(lista, s)
			end
		end
	end
	if #lista > 0 then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(lista)
			end)
		end)
	end
end

-- CÁMARA -----------------------------------------------------------------------

function Contexto:IniciarCamara()
	local camara = workspace.CurrentCamera
	camara.CameraType = Enum.CameraType.Scriptable
	self.EstadoCamara = {
		Calcular = function()
			return camara.CFrame
		end,
		Inicio = os.clock(),
	}
	RunService:UnbindFromRenderStep(NOMBRE_RENDER)
	RunService:BindToRenderStep(NOMBRE_RENDER, Enum.RenderPriority.Camera.Value + 1, function()
		if self.Inicio then
			Guias.Tiempo(self:Reloj(), self.Etiqueta)
		end
		local e = self.EstadoCamara
		local ok, objetivo = pcall(e.Calcular)
		if not ok or typeof(objetivo) ~= "CFrame" then
			return
		end
		local ahora = os.clock()
		if e.Acercar and e.Acercar ~= 0 then
			local p = math.clamp((ahora - e.Inicio) / e.TiempoAcercar, 0, 1)
			objetivo = objetivo * CFrame.new(0, 0, -e.Acercar * suavizar(p))
		end
		if e.Desde then
			local a = (ahora - e.Inicio) / e.Transicion
			if a >= 1 then
				e.Desde = nil
			else
				objetivo = e.Desde:Lerp(objetivo, suavizar(a))
			end
		end
		camara.CameraType = Enum.CameraType.Scriptable
		camara.CFrame = objetivo
		camara.FieldOfView = Guias.FOVReal(camara, e.FOV or Config.CampoVision, Config.Aspecto)
	end)
end

function Contexto:Camara(p)
	local fov = p.FOV or Config.CampoVision
	local calcular = Camaras.Preparar(p, self, fov, Config.Aspecto)
	local camara = workspace.CurrentCamera
	local estado = {
		Calcular = calcular,
		Inicio = os.clock(),
		FOV = fov,
		Acercar = p.Acercar,
		TiempoAcercar = p.TiempoAcercar or 4,
	}
	local transicion = p.Transicion or Config.TransicionCamara or 0
	if transicion > 0 then
		estado.Desde = camara.CFrame
		estado.Transicion = transicion
	end
	self.EstadoCamara = estado
end

function Contexto:Destruir()
	RunService:UnbindFromRenderStep(NOMBRE_RENDER)
	for _, s in ipairs(self.Sonidos) do
		s:Destroy()
	end
	Efectos.Filtro(nil)
	Efectos.TonoEntorno(nil)
	Efectos.Limpiar()
	self.Carpeta:Destroy()
end

--==============================================================================
-- ACCIONES: cada una devuelve los segundos que dura (el Director espera ese
-- tiempo salvo que el paso tenga Paralelo = true o T = segundos).
--==============================================================================

local Acciones = {}

Acciones.Esperar = function(_, p)
	return p.Tiempo or p[2] or 1
end

-- Espera hasta el segundo "Tiempo" de la escena (contado desde el primer paso).
Acciones.EsperarHasta = function(ctx, p)
	return math.max(0, (p.Tiempo or p[2] or 0) - ctx:Reloj())
end

Acciones.Colocar = function(ctx, p)
	local actor = ctx:ObtenerActor(p.Actor)
	local pos, marca = ctx:Pos(p.En or p.Marca)
	ctx:Mostrar(actor)
	actor:Colocar(pos, marca and marca.CFrame.LookVector or nil)
	if p.MirarA then
		actor:MirarHacia(ctx:PuntoMirada(p.MirarA), 0)
	end
	return 0
end

Acciones.Ocultar = function(ctx, p)
	local actor = ctx.Actores[p.Actor]
	if actor then
		ctx:OcultarActor(actor)
	end
	return 0
end

-- Sienta a un actor en una marca de asiento (Silla_...).
Acciones.Sentar = function(ctx, p)
	local actor = ctx:ObtenerActor(p.Actor)
	local punto = ctx:Superficie(p.En or p.Marca)
	local marca = ctx:Marca(p.En or p.Marca)
	ctx:Mostrar(actor)
	actor:Sentar(punto, marca and marca.CFrame.LookVector or nil)
	return 0
end

-- Levanta a un actor sentado y lo deja de pie en "En" (o justo delante del asiento).
Acciones.Levantar = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local pos, marca
	if p.En then
		pos, marca = ctx:Pos(p.En)
	else
		local r = actor.Raiz.Position
		pos = Vector3.new(r.X, 0, r.Z) + plano(actor.Raiz.CFrame.LookVector) * 1.4
	end
	actor:Colocar(pos, marca and marca.CFrame.LookVector or actor.Raiz.CFrame.LookVector)
	return 0
end

local function desplazar(ctx, p, base, velocidad)
	local actor
	if p.Desde then
		actor = ctx:ObtenerActor(p.Actor)
		local pos0, marca0 = ctx:Pos(p.Desde)
		ctx:Mostrar(actor)
		actor:Colocar(pos0, marca0 and marca0.CFrame.LookVector or nil)
	else
		actor = ctx:ActorVisible(p.Actor)
	end
	local destino = ctx:Pos(p.Hasta, actor:PosicionSuelo(), p.Distancia)
	local duracion = actor:Mover(destino, p.Velocidad or velocidad, base)
	if p.MirarA then
		local objetivo = p.MirarA
		task.delay(duracion, function()
			if actor.Modelo.Parent then
				actor:MirarHacia(ctx:PuntoMirada(objetivo))
			end
		end)
		duracion = duracion + 0.35
	end
	return duracion
end

Acciones.Caminar = function(ctx, p)
	return desplazar(ctx, p, "Caminar", Config.VelocidadCaminar)
end

Acciones.Correr = function(ctx, p)
	return desplazar(ctx, p, "Correr", Config.VelocidadCorrer)
end

Acciones.Mirar = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	if p.SoloCabeza then
		actor:MirarCabeza(p.A and ctx:PuntoMirada(p.A) or nil, p.Tiempo)
		return p.Tiempo or 0.3
	end
	actor:MirarCabeza(nil, 0.3)
	return actor:MirarHacia(ctx:PuntoMirada(p.A), p.Tiempo)
end

Acciones.Gesto = function(ctx, p)
	return ctx:ActorVisible(p.Actor):Gesto(p.Gesto, p.Duracion, p.Mantener)
end

-- Gesto de reposo que se mantiene debajo de los demás ("Ninguna" para quitarlo).
Acciones.Postura = function(ctx, p)
	local nombre = p.Postura
	if nombre == "Ninguna" then
		nombre = nil
	end
	ctx:ActorVisible(p.Actor):FijarPostura(nombre)
	return 0
end

Acciones.Expresion = function(ctx, p)
	local nombre = p.Expresion
	if nombre == "Ninguna" then
		nombre = nil
	end
	ctx:ActorVisible(p.Actor):Expresion(nombre, p.Duracion)
	return 0
end

Acciones.Hablar = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local duracion = p.Duracion
	if p.Sonido then
		local s = ctx:Sonido(p.Sonido, p.Volumen, false)
		if s then
			s:Play()
			duracion = duracion or ctx:Duracion(s)
		end
	end
	duracion = duracion or 2
	actor:MoverBoca(duracion)
	if p.SoloBoca then
		return duracion
	end
	return actor:Gesto("Hablar", duracion)
end

--[[
	Reproduce una voz de Modulos > Voces y sincroniza los labios con su volumen.
	  Voz         = nombre de la voz ("postit1")
	  Actor       = rol que habla (por defecto, el Personaje de la voz si es Dialogo)
	  Labios      = mover la boca (por defecto: sí en Dialogo, no en Narrador)
	  LabiosHasta = segundos de labios (p. ej. solo la primera frase)
	  Gestos      = true → además gesticula con las manos
]]
Acciones.Voz = function(ctx, p)
	local nombre = p.Voz
	local datos = Voces and Voces[nombre]
	if type(datos) ~= "table" then
		error(("No existe la voz '%s' en Modulos > Voces"):format(tostring(nombre)), 0)
	end
	local duracion = datos.Duracion
	local s = ctx:SonidoVoz(nombre)
	if s then
		if p.Volumen then
			s.Volume = p.Volumen
		end
		s.TimePosition = 0
		s:Play()
	end
	local rol = p.Actor
	if rol == nil and datos.Tipo ~= "Narrador" then
		rol = datos.Personaje
	end
	local labios = p.Labios
	if labios == nil then
		labios = datos.Tipo ~= "Narrador"
	end
	if rol and labios then
		local actor = ctx.Actores[rol]
		if actor and actor.Modelo.Parent then
			actor:MoverBocaEnvolvente(datos.Envolvente, Voces.Paso, p.LabiosHasta)
			if p.Gestos then
				actor:Gesto("Hablar", p.LabiosHasta or duracion)
			end
		end
	end
	if Config.Subtitulos and datos.Texto and datos.Texto ~= "" then
		Efectos.Texto(datos.Texto, "Subtitulo", duracion)
	end
	ctx.Etiqueta = nombre
	print(("[Historia] t = %6.2f s  ▶ %s (%.2f s) %s"):format(ctx:Reloj(), nombre, duracion, s and "" or "[sin Id: silencio]"))
	return duracion
end

Acciones.Senalar = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local giro = 0
	if p.A then
		if actor.PosturaPiernas then
			actor:MirarCabeza(ctx:PuntoMirada(p.A))
		else
			giro = actor:MirarHacia(ctx:PuntoMirada(p.A))
		end
	end
	local duracion = p.Duracion or 1.5
	task.delay(giro, function()
		actor:Gesto("Senalar", duracion, p.Mantener)
	end)
	return giro + duracion
end

Acciones.Sorpresa = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local duracion = actor:Gesto("Sorpresa", p.Duracion, p.Mantener)
	actor:Expresion("Sorpresa", (not p.Mantener) and duracion + 0.3 or nil)
	return duracion
end

Acciones.Animacion = function(ctx, p)
	return ctx:ActorVisible(p.Actor):Clip(p.Clip or p.Animacion)
end

Acciones.Entregar = function(ctx, p)
	local de = ctx:ActorVisible(p.De)
	local para = ctx:ActorVisible(p.A)
	local objeto
	if p.Objeto then
		objeto = ctx:ObtenerObjeto(p.Objeto)
		if de.Objeto ~= objeto then
			ctx:DarObjeto(p.Objeto, de)
		end
	else
		objeto = de.Objeto
	end
	if not objeto then
		error(("Entregar: '%s' no lleva ningún objeto; indica Objeto = \"...\""):format(tostring(p.De)), 0)
	end
	task.spawn(function()
		de:MirarHacia(para.Raiz.Position)
		para:MirarHacia(de.Raiz.Position)
		task.wait(0.35)
		de:Gesto("Entregar", 1)
		task.wait(0.35)
		para:Gesto("Recibir", 0.7)
		task.wait(0.4)
		if de.Objeto == objeto then
			de:Soltar(true)
			para:Sostener(objeto)
		end
	end)
	return 2
end

-- Coge un objeto (del suelo, de una mesa o de una pared: elige el gesto según la altura).
Acciones.Recoger = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local objeto = ctx:ObtenerObjeto(p.Objeto)
	local giro = 0
	local gesto = p.Gesto
	if objeto.Parent then
		local pos = objeto:GetBoundingBox().Position
		gesto = gesto or gestoPorAltura(actor, pos.Y)
		if not actor.PosturaPiernas then
			giro = actor:MirarHacia(pos)
		end
	end
	gesto = gesto or "Agacharse"
	task.spawn(function()
		task.wait(giro)
		actor:Gesto(gesto, 0.8)
		task.wait(0.45)
		ctx:DarObjeto(p.Objeto, actor)
	end)
	return giro + 1.1
end

-- Deja lo que lleva en la mano en "En" (o lo hace desaparecer si no hay En).
Acciones.Soltar = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local objeto = actor.Objeto
	if not objeto then
		return 0
	end
	if p.En then
		local donde, desp = p.En, p.Desplazamiento
		local punto = ctx:Superficie(donde, desp)
		local gesto = p.Gesto or gestoPorAltura(actor, punto.Y)
		task.spawn(function()
			actor:Gesto(gesto, 0.7)
			task.wait(0.45)
			ctx:ColocarObjeto(objeto.Name, donde, desp)
		end)
		return 1
	end
	actor:Soltar()
	objeto.Parent = nil
	return 0
end

-- Pega lo que lleva en la mano (u Objeto) en una pared o encima de otro objeto.
Acciones.Pegar = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local objeto
	if p.Objeto then
		objeto = ctx:ObtenerObjeto(p.Objeto)
		if actor.Objeto ~= objeto then
			ctx:DarObjeto(p.Objeto, actor)
		end
	else
		objeto = actor.Objeto
	end
	if not objeto then
		error(("Pegar: '%s' no lleva nada en la mano; indica Objeto = \"...\""):format(tostring(p.Actor)), 0)
	end
	local punto, normal = ctx:Superficie(p.En, p.Desplazamiento)
	local giro = 0
	if not actor.PosturaPiernas then
		giro = actor:MirarHacia(punto)
	end
	local gesto = p.Gesto or gestoPorAltura(actor, punto.Y)
	task.spawn(function()
		task.wait(giro)
		actor:Gesto(gesto, 0.8)
		task.wait(0.45)
		ctx:FijarEnSuperficie(objeto, punto, normal, actor.Raiz.CFrame.LookVector * -1)
	end)
	return giro + 1
end

-- Un objeto cae al suelo (o a "Hasta") balanceándose como un papel.
Acciones.Caer = function(ctx, p)
	local objeto = ctx:ObtenerObjeto(p.Objeto)
	return ctx:Caer(objeto, p.Hasta, p.Tiempo)
end

-- Un objeto aparece de golpe con un rebote en "En".
Acciones.Aparecer = function(ctx, p)
	ctx:Aparecer(p.Objeto, p.En or p.Marca, p.Desplazamiento)
	return 0.3
end

Acciones.Objeto = function(ctx, p)
	if p.Visible == false then
		local objeto = ctx.Objetos[p.Objeto]
		if objeto then
			ctx:QuitarDeManos(objeto)
			objeto.Parent = nil
		end
		return 0
	end
	if p.EnManoDe then
		ctx:DarObjeto(p.Objeto, ctx:ActorVisible(p.EnManoDe))
		return 0
	end
	ctx:ColocarObjeto(p.Objeto, p.En or p.Marca, p.Desplazamiento)
	return 0
end

Acciones.Camara = function(ctx, p)
	ctx:Camara(p)
	return 0
end

Acciones.Texto = function(_, p)
	Efectos.Texto(p.Texto, p.Estilo, p.Duracion, {
		Posicion = p.Posicion,
		Tamano = p.Tamano,
		Color = p.Color,
		Giro = p.Giro,
	})
	return 0
end

-- Fundido a negro (o Color = "Blanco"). Devuelve el tiempo hasta cubrir la pantalla.
Acciones.Fundido = function(_, p)
	return Efectos.Fundido(p.Color, p.Entrada, p.Mantener, p.Salida)
end

Acciones.Filtro = function(_, p)
	Efectos.Filtro(p.Filtro)
	return 0
end

Acciones.Sonido = function(ctx, p)
	local s = ctx:Sonido(p.Sonido, p.Volumen, false)
	if not s then
		return 0
	end
	s:Play()
	return ctx:Duracion(s)
end

Acciones.Musica = function(ctx, p)
	if ctx.Musica then
		ctx.Musica:Stop()
		ctx.Musica:Destroy()
		ctx.Musica = nil
	end
	if p.Parar then
		return 0
	end
	local s = ctx:Sonido(p.Sonido, p.Volumen or 0.3, true)
	if s then
		s:Play()
		ctx.Musica = s
	end
	return 0
end

Acciones.Entorno = function(ctx, p)
	ctx:CargarEntorno(p.Nombre or p.Entorno)
	return 0
end

Acciones.Ejecutar = function(ctx, p)
	return p.Funcion(ctx) or 0
end

Director.Acciones = Acciones

--==============================================================================
-- REPRODUCCIÓN
--==============================================================================

local function ejecutarPaso(ctx, paso, i)
	local nombre = paso.Accion or paso[1]
	local accion = Acciones[nombre]
	if not accion then
		warn(("[Historia] Paso %d: acción desconocida '%s'"):format(i, tostring(nombre)))
		return
	end
	if type(paso.T) == "number" and ctx.Inicio then
		local espera = paso.T - ctx:Reloj()
		if espera > 0 then
			task.wait(espera)
		elseif espera < -0.15 then
			warn(("[Historia] Paso %d (%s) llega %.2f s tarde: T = %.2f"):format(i, tostring(nombre), -espera, paso.T))
		end
	end
	local ok, duracion = pcall(accion, ctx, paso)
	if not ok then
		warn(("[Historia] Paso %d (%s): %s"):format(i, tostring(nombre), tostring(duracion)))
		return
	end
	local bloquea = not paso.Paralelo and (paso.T == nil or paso.Esperar == true)
	if bloquea and type(duracion) == "number" and duracion > 0 then
		task.wait(duracion)
	end
	if type(paso.Pausa) == "number" and paso.Pausa > 0 then
		task.wait(paso.Pausa)
	end
end

local function preparar(ctx, escena)
	ctx:CargarEntorno(escena.Entorno or "Neutro")
	ctx:IniciarCamara()

	local posiciones = escena.Posiciones or {}
	for rol, def in pairs(posiciones) do
		local d = type(def) == "table" and def or { Marca = def }
		if d.Sentado then
			Acciones.Sentar(ctx, { Actor = rol, En = d.Sentado })
		else
			Acciones.Colocar(ctx, { Actor = rol, En = d.Marca or d.En })
		end
	end

	ctx:Camara(escena.Camara or { Plano = "General" })

	for rol, def in pairs(posiciones) do
		if type(def) == "table" and def.MirarA then
			ctx:ActorVisible(rol):MirarHacia(ctx:PuntoMirada(def.MirarA), 0)
		end
		if type(def) == "table" and def.Expresion then
			ctx:ActorVisible(rol):Expresion(def.Expresion)
		end
	end

	for nombre, def in pairs(escena.Objetos or {}) do
		local d = type(def) == "table" and def or { En = def }
		if d.EnManoDe then
			ctx:DarObjeto(nombre, ctx:ActorVisible(d.EnManoDe))
		elseif d.En or d.Marca then
			ctx:ColocarObjeto(nombre, d.En or d.Marca, d.Desplazamiento)
		end
	end
	ctx:PrecargarVoces()
end

local function esperarPersonajes()
	local t = 0
	while not Raiz:GetAttribute("PersonajesListos") and t < 20 do
		t = t + task.wait(0.1)
	end
end

local interfazPreparada = false
local function prepararInterfaz()
	if interfazPreparada then
		return
	end
	interfazPreparada = true
	Guias.Crear(Config, Camaras.Margenes)
	if Config.OcultarRaton then
		UserInputService.MouseIconEnabled = false
	end
	if Config.OcultarInterfazRoblox then
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)
		task.spawn(function()
			for _ = 1, 10 do
				if pcall(function()
					StarterGui:SetCore("TopbarEnabled", false)
				end) then
					return
				end
				task.wait(0.5)
			end
		end)
	end
end

-- Cuenta atrás 3-2-1 antes del primer paso (referencia para montar el audio).
local function cuentaAtras(retraso)
	local n = math.min(3, math.floor(retraso))
	if not Config.CuentaAtras or n < 1 then
		task.wait(retraso)
		return
	end
	task.wait(retraso - n)
	for k = n, 1, -1 do
		Efectos.Texto(tostring(k), "Icono", 0.8, { Posicion = Vector2.new(0.5, 0.45), Tamano = Vector2.new(0.4, 0.25) })
		task.wait(1)
	end
end

function Director.Reproducir(nombreEscena)
	esperarPersonajes()
	local modulo = Raiz.Escenas:FindFirstChild(tostring(nombreEscena))
	if not modulo then
		local disponibles = {}
		for _, m in ipairs(Raiz.Escenas:GetChildren()) do
			table.insert(disponibles, m.Name)
		end
		warn(
			("[Historia] No existe la escena '%s'. Escenas disponibles: %s"):format(
				tostring(nombreEscena),
				table.concat(disponibles, ", ")
			)
		)
		return
	end
	local okEscena, escena = pcall(require, modulo)
	if not okEscena or type(escena) ~= "table" then
		warn(("[Historia] Error al leer la escena '%s': %s"):format(modulo.Name, tostring(escena)))
		return
	end

	prepararInterfaz()

	repeat
		local ctx = Contexto.new(escena)
		local ok, err = pcall(preparar, ctx, escena)
		if not ok then
			warn("[Historia] Error preparando la escena: " .. tostring(err))
		end
		print(("[Historia] Escena '%s' lista. Empieza en %s s"):format(modulo.Name, tostring(Config.RetrasoInicio)))
		cuentaAtras(Config.RetrasoInicio or 0)

		ctx.Inicio = os.clock()
		if escena.Musica then
			local paso = { Accion = "Musica" }
			for k, v in pairs(escena.Musica) do
				paso[k] = v
			end
			ejecutarPaso(ctx, paso, 0)
		end
		for i, paso in ipairs(escena.Pasos or {}) do
			ejecutarPaso(ctx, paso, i)
		end
		print(("[Historia] Escena '%s' terminada (%.2f s)"):format(modulo.Name, ctx:Reloj()))

		if Config.Repetir then
			task.wait(2)
			ctx:Destruir()
		end
	until not Config.Repetir
end

return Director
