--[[
	ACTOR · Controla un personaje dentro de una escena
	Studio: ReplicatedStorage > StoryTemplate > Modulos > Actor

	Optimización:
	  · La raíz (HumanoidRootPart) queda anclada: no hay física ni colisiones.
	  · El Humanoid no evalúa estados (EvaluateStateMachine = false).
	  · El movimiento se hace con Tweens (motor nativo), no con bucles de script.
	  · Los gestos giran los Motor6D con Tweens encima de la animación base.

	No hace falta editar este archivo para crear escenas.
]]

local TweenService = game:GetService("TweenService")
local Animaciones = require(script.Parent:WaitForChild("Animaciones"))

local Actor = {}
Actor.__index = Actor

local ARTICULACIONES = {
	Neck = true,
	Waist = true,
	RightShoulder = true,
	RightElbow = true,
	RightWrist = true,
	LeftShoulder = true,
	LeftElbow = true,
	LeftWrist = true,
	RightHip = true,
	LeftHip = true,
	RightKnee = true,
	LeftKnee = true,
}

-- Atuendos se carga al usarse (expresiones de la cara)
local cacheAtuendos = nil
local function Atuendos()
	if not cacheAtuendos then
		local m = script.Parent:FindFirstChild("Atuendos")
		cacheAtuendos = m and require(m) or false
	end
	return cacheAtuendos or nil
end

local function plano(v)
	local p = Vector3.new(v.X, 0, v.Z)
	if p.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return p.Unit
end

local function aVector(t)
	if typeof(t) == "Vector3" then
		return t
	end
	return Vector3.new(t[1] or 0, t[2] or 0, t[3] or 0)
end

local function cargarPista(animator, id, prioridad, bucle)
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, pista = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok then
		warn("[Actor] No se pudo cargar la animación " .. id .. ": " .. tostring(pista))
		return nil
	end
	pista.Priority = prioridad
	pista.Looped = bucle
	return pista
end

-- El modelo ya debe estar dentro de workspace (necesario para cargar animaciones).
function Actor.new(modelo, rol)
	local humanoid = modelo:FindFirstChildOfClass("Humanoid")
	local raiz = modelo:FindFirstChild("HumanoidRootPart")
	if not humanoid or not raiz then
		error(("El personaje '%s' necesita un Humanoid y un HumanoidRootPart"):format(modelo.Name), 0)
	end

	local self = setmetatable({}, Actor)
	self.Modelo = modelo
	self.Rol = rol or modelo.Name
	self.Humanoid = humanoid
	self.Raiz = raiz
	self.Motores = {}
	self.C0Base = {}
	self.Rotaciones = {}
	self.GiroCabeza = 0
	self.Postura = nil -- gesto de reposo (p. ej. "Sostener" cuando lleva algo)
	self.PosturaManual = nil -- gesto de reposo fijado desde la escena (acción "Postura")
	self.PosturaPiernas = nil -- postura de piernas ("Sentado")
	self.TokenGesto = 0
	self.TokenMovimiento = 0
	self.Objeto = nil

	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("Motor6D") and ARTICULACIONES[d.Name] then
			self.Motores[d.Name] = d
			self.C0Base[d.Name] = d.C0
		end
	end
	raiz.Anchored = true

	humanoid.EvaluateStateMachine = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false

	-- Altura de la raíz sobre el suelo y de la cabeza sobre la raíz
	local cadera = humanoid.HipHeight
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 or cadera <= 0 then
		cadera = 2
	end
	self.AlturaRaiz = cadera + raiz.Size.Y / 2
	local cabeza = modelo:FindFirstChild("Head")
	local alturaCabeza = cabeza and (cabeza.Position.Y - raiz.Position.Y) or 1.6
	if alturaCabeza < 0.5 or alturaCabeza > 4 then
		alturaCabeza = 1.6
	end
	self.AlturaCabeza = alturaCabeza
	self.TamanoCabeza = cabeza and cabeza.Size.Y or 1.2
	-- Anchura relativa al R15 estándar (torso de 2 studs): la usan las cámaras
	local torso = modelo:FindFirstChild("UpperTorso")
	self.EscalaAncho = torso and math.max(torso.Size.X / 2, 0.5) or 1
	-- Altura de la cadera respecto a la raíz y grosor del muslo (para sentarse)
	local cadera3d = self.Motores.RightHip
	if cadera3d and cadera3d.Part0 then
		self.AlturaCadera = (cadera3d.Part0.CFrame * cadera3d.C0).Position.Y - raiz.Position.Y
	end
	if not self.AlturaCadera or self.AlturaCadera > 0 or self.AlturaCadera < -2.5 then
		self.AlturaCadera = -self.AlturaRaiz / 3
	end
	local muslo = modelo:FindFirstChild("RightUpperLeg")
	self.GrosorMuslo = muslo and muslo.Size.Z or 1

	-- Animaciones
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	self.Animator = animator
	self.Pistas = {}
	for nombre, def in pairs(Animaciones.Base) do
		local prioridad = (nombre == "Quieto") and Enum.AnimationPriority.Idle or Enum.AnimationPriority.Movement
		self.Pistas[nombre] = cargarPista(animator, def.Id, prioridad, true)
	end
	self.Clips = {}
	for nombre, id in pairs(Animaciones.Clips) do
		self.Clips[nombre] = cargarPista(animator, id, Enum.AnimationPriority.Action, false)
	end

	self:Base("Quieto")
	self:_iniciarCara()
	return self
end

-- CARA: PARPADEO Y BOCA --------------------------------------------------------
-- Funciona con las caras creadas por Atuendos (SurfaceGui "Cara" en la cabeza).

local azar = Random.new()

function Actor:_iniciarCara()
	local cabeza = self.Modelo:FindFirstChild("Head")
	local cara = cabeza and cabeza:FindFirstChild("Cara")
	if not cara then
		return
	end
	self.Cara = cara
	self.TokenBoca = 0
	self.Parpados = {}
	for _, nombre in ipairs({ "OjoIzq", "OjoDer" }) do
		local ojo = cara:FindFirstChild(nombre)
		local parpado = ojo and ojo:FindFirstChild("Parpado")
		if parpado then
			table.insert(self.Parpados, parpado)
		end
	end
	if #self.Parpados == 0 then
		return
	end
	-- Parpadeo automático cada 2-5 s (a veces doble). Termina al destruir el modelo.
	task.spawn(function()
		task.wait(azar:NextNumber(0.3, 2))
		while cara.Parent do
			self:Parpadear()
			if azar:NextNumber() < 0.15 then
				task.wait(0.28)
				self:Parpadear()
			end
			task.wait(azar:NextNumber(2, 5))
		end
	end)
end

function Actor:Parpadear()
	for _, parpado in ipairs(self.Parpados or {}) do
		local abierto = UDim2.fromScale(1.2, parpado:GetAttribute("Alto") or 0.06)
		local cierra = TweenService:Create(parpado, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromScale(1.2, 1.05),
		})
		cierra.Completed:Connect(function()
			task.wait(0.04)
			TweenService:Create(parpado, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = abierto,
			}):Play()
		end)
		cierra:Play()
	end
end

-- Abre y cierra la boca durante "duracion" segundos (no bloquea).
function Actor:MoverBoca(duracion)
	local cara = self.Cara
	local reposo = cara and cara:FindFirstChild("BocaReposo")
	local habla = cara and cara:FindFirstChild("BocaHabla")
	if not reposo or not habla then
		return 0
	end
	self.TokenBoca = self.TokenBoca + 1
	local token = self.TokenBoca
	task.spawn(function()
		local fin = os.clock() + duracion
		while os.clock() < fin and self.TokenBoca == token and cara.Parent do
			local abre = azar:NextNumber()
			if abre < 0.25 then
				reposo.Visible = true
				habla.Visible = false
			else
				reposo.Visible = false
				habla.Visible = true
				TweenService:Create(habla, TweenInfo.new(0.06), {
					Size = UDim2.fromScale(0.13 + 0.09 * abre, 0.03 + 0.13 * abre),
				}):Play()
			end
			task.wait(azar:NextNumber(0.09, 0.18))
		end
		if self.TokenBoca == token then
			reposo.Visible = true
			habla.Visible = false
		end
	end)
	return duracion
end

--[[
	Mueve la boca siguiendo la envolvente de volumen de un audio (Modulos > Voces):
	una cadena de cifras 0-9, una cada "paso" segundos. "hasta" limita los segundos
	(por ejemplo, para mover los labios solo en la primera frase).
]]
function Actor:MoverBocaEnvolvente(envolvente, paso, hasta)
	local cara = self.Cara
	local reposo = cara and cara:FindFirstChild("BocaReposo")
	local habla = cara and cara:FindFirstChild("BocaHabla")
	if not reposo or not habla or not envolvente then
		return 0
	end
	paso = paso or 0.05
	local total = #envolvente * paso
	if hasta then
		total = math.min(total, hasta)
	end
	self.TokenBoca = self.TokenBoca + 1
	local token = self.TokenBoca
	task.spawn(function()
		local inicio = os.clock()
		local ultimo = -1
		while self.TokenBoca == token and cara.Parent do
			local t = os.clock() - inicio
			if t >= total then
				break
			end
			local i = math.floor(t / paso) + 1
			if i ~= ultimo then
				ultimo = i
				local v = (tonumber(envolvente:sub(i, i)) or 0) / 9
				if v < 0.3 then
					reposo.Visible = true
					habla.Visible = false
				else
					reposo.Visible = false
					habla.Visible = true
					TweenService:Create(habla, TweenInfo.new(paso), {
						Size = UDim2.fromScale(0.12 + 0.1 * v, 0.03 + 0.14 * v),
					}):Play()
				end
			end
			task.wait()
		end
		if self.TokenBoca == token then
			reposo.Visible = true
			habla.Visible = false
		end
	end)
	return total
end

-- Cambia la expresión de la cara (Atuendos.Expresiones). duracion = nil → se mantiene.
-- nombre = nil → vuelve a la cara base.
function Actor:Expresion(nombre, duracion)
	local A = Atuendos()
	if not self.Cara or not A then
		return 0
	end
	self.TokenExpresion = (self.TokenExpresion or 0) + 1
	local token = self.TokenExpresion
	local parpado = A.Expresar(self.Cara, nombre)
	for _, p in ipairs(self.Parpados or {}) do
		local alto = parpado or p:GetAttribute("AltoBase") or 0.06
		p:SetAttribute("Alto", alto)
		TweenService:Create(p, TweenInfo.new(0.15), { Size = UDim2.fromScale(1.2, alto) }):Play()
	end
	if duracion and nombre then
		task.delay(duracion, function()
			if self.TokenExpresion == token then
				self:Expresion(nil)
			end
		end)
	end
	return 0
end

-- POSICIÓN ---------------------------------------------------------------------

function Actor:PosicionSuelo()
	return self.Raiz.Position - Vector3.new(0, self.AlturaRaiz, 0)
end

function Actor:_tween(cf, info)
	if self.Tween then
		self.Tween:Cancel()
	end
	self.Tween = TweenService:Create(self.Raiz, info, { CFrame = cf })
	self.Tween:Play()
	return self.Tween
end

function Actor:_cancelarMovimiento()
	self.TokenMovimiento = self.TokenMovimiento + 1
	if self.Tween then
		self.Tween:Cancel()
		self.Tween = nil
	end
end

-- Coloca al personaje de pie sobre un punto del suelo, mirando en "direccion".
function Actor:Colocar(posSuelo, direccion)
	self:_cancelarMovimiento()
	-- Colocar deja al personaje de pie y en su postura de reposo
	self.PosturaPiernas = nil
	self.TokenGesto = self.TokenGesto + 1
	self:_postura(nil)
	self:_aplicar(0)
	local pos = posSuelo + Vector3.new(0, self.AlturaRaiz, 0)
	local dir = plano(direccion or self.Raiz.CFrame.LookVector)
	self.Raiz.CFrame = CFrame.lookAt(pos, pos + dir)
	self:Base("Quieto")
end

-- Sienta al personaje: "asiento" es el punto central de la superficie del asiento.
function Actor:Sentar(asiento, direccion)
	self:_cancelarMovimiento()
	local dir = plano(direccion or self.Raiz.CFrame.LookVector)
	local y = asiento.Y - self.AlturaCadera + self.GrosorMuslo / 2
	-- la cadera queda un poco hacia el respaldo
	local pos = Vector3.new(asiento.X, y, asiento.Z) - dir * 0.25
	self.Raiz.CFrame = CFrame.lookAt(pos, pos + dir)
	self.PosturaPiernas = "Sentado"
	self:Base("Quieto")
	self:_postura(nil)
	self:_aplicar(0)
end

-- Fija (o quita con nil) un gesto de reposo que se mantiene debajo de los demás gestos.
function Actor:FijarPostura(nombre, tiempo)
	self.PosturaManual = nombre
	self:_postura(nil)
	self:_aplicar(tiempo or 0.3)
end

-- Gira el cuerpo hacia una dirección horizontal. Devuelve la duración.
function Actor:Girar(direccion, tiempo)
	tiempo = tiempo or 0.35
	local pos = self.Raiz.Position
	local objetivo = CFrame.lookAt(pos, pos + plano(direccion))
	-- Si ya mira hacia ahí (menos de 10 grados), no gasta tiempo en girar
	if tiempo > 0 and self.Raiz.CFrame.LookVector:Dot(objetivo.LookVector) > 0.985 then
		return 0
	end
	if tiempo <= 0 then
		if self.Tween then
			self.Tween:Cancel()
		end
		self.Raiz.CFrame = objetivo
		return 0
	end
	self:_tween(objetivo, TweenInfo.new(tiempo, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
	return tiempo
end

function Actor:MirarHacia(posicion, tiempo)
	return self:Girar(posicion - self.Raiz.Position, tiempo)
end

-- Desplaza al personaje hasta un punto del suelo. base = "Caminar" o "Correr".
-- Devuelve la duración total (no bloquea).
function Actor:Mover(posSuelo, velocidad, base)
	self:_cancelarMovimiento()
	local token = self.TokenMovimiento
	local destino = posSuelo + Vector3.new(0, self.AlturaRaiz, 0)
	local delta = destino - self.Raiz.Position
	local distancia = Vector3.new(delta.X, 0, delta.Z).Magnitude
	if distancia < 0.05 then
		return 0
	end
	local dir = plano(delta)
	local giro = 0.2
	local duracion = distancia / math.max(velocidad, 0.1)

	self:Base(base, velocidad)
	self:Girar(dir, giro)
	task.delay(giro, function()
		if self.TokenMovimiento ~= token then
			return
		end
		local tween = self:_tween(CFrame.lookAt(destino, destino + dir), TweenInfo.new(duracion, Enum.EasingStyle.Linear))
		tween.Completed:Wait()
		if self.TokenMovimiento == token then
			self:Base("Quieto")
		end
	end)
	return giro + duracion
end

-- ANIMACIONES BASE Y CLIPS -----------------------------------------------------

function Actor:Base(nombre, velocidad)
	local pista = self.Pistas[nombre]
	if self.BaseActual ~= nombre then
		for n, p in pairs(self.Pistas) do
			if n ~= nombre and p.IsPlaying then
				p:Stop(0.25)
			end
		end
		if pista then
			pista:Play(0.25)
		end
		self.BaseActual = nombre
	end
	local def = Animaciones.Base[nombre]
	if pista and def then
		if velocidad and def.VelocidadReferencia then
			pista:AdjustSpeed(velocidad / def.VelocidadReferencia)
		else
			pista:AdjustSpeed(1)
		end
	end
end

-- Vuelve a lanzar la animación base (tras ocultar y mostrar al personaje).
function Actor:Reanudar()
	local actual = self.BaseActual or "Quieto"
	self.BaseActual = nil
	self:Base(actual)
end

function Actor:Clip(nombre)
	local pista = self.Clips[nombre]
	if not pista then
		warn(("[Actor] No existe el clip '%s' en Animaciones.Clips"):format(tostring(nombre)))
		return 0
	end
	pista:Play(0.2)
	if pista.Length > 0 then
		return pista.Length
	end
	return 2
end

-- GESTOS -----------------------------------------------------------------------

function Actor:_postura(fotograma)
	local rot = {}
	local piernas = self.PosturaPiernas and Animaciones.Piernas and Animaciones.Piernas[self.PosturaPiernas]
	if piernas then
		for k, v in pairs(piernas) do
			rot[k] = aVector(v)
		end
	end
	local nombreReposo = self.PosturaManual or self.Postura
	local reposo = nombreReposo and Animaciones.Gestos[nombreReposo]
	if reposo then
		for k, v in pairs(reposo.Fotogramas[1]) do
			rot[k] = aVector(v)
		end
	end
	if fotograma then
		for k, v in pairs(fotograma) do
			rot[k] = aVector(v)
		end
	end
	self.Rotaciones = rot
end

function Actor:_aplicar(tiempo)
	tiempo = tiempo or 0.3
	local info = TweenInfo.new(math.max(tiempo, 0.01), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for nombre, motor in pairs(self.Motores) do
		local r = self.Rotaciones[nombre] or Vector3.zero
		local giro = (nombre == "Neck") and self.GiroCabeza or 0
		local objetivo = self.C0Base[nombre] * CFrame.Angles(math.rad(r.X), math.rad(r.Y + giro), math.rad(r.Z))
		if tiempo <= 0 then
			motor.C0 = objetivo
		else
			TweenService:Create(motor, info, { C0 = objetivo }):Play()
		end
	end
end

-- Reproduce un gesto de Animaciones.Gestos. No bloquea; devuelve su duración.
-- mantener = true → se queda en la postura final hasta el siguiente gesto.
function Actor:Gesto(nombre, duracion, mantener)
	local def = Animaciones.Gestos[nombre]
	if not def then
		warn(("[Actor] No existe el gesto '%s' en Animaciones.Gestos"):format(tostring(nombre)))
		return 0
	end
	self.TokenGesto = self.TokenGesto + 1
	local token = self.TokenGesto
	local transicion = def.Transicion or 0.3
	duracion = duracion or def.Duracion or 1.5
	local fotogramas = def.Fotogramas
	local bucle = def.Bucle and #fotogramas > 1

	task.spawn(function()
		local inicio = os.clock()
		local i = 1
		repeat
			self:_postura(fotogramas[i])
			self:_aplicar(transicion)
			task.wait(transicion + (def.Pausa or 0))
			if self.TokenGesto ~= token then
				return
			end
			i = i % #fotogramas + 1
		until not bucle or (os.clock() - inicio) >= duracion

		local restante = duracion - (os.clock() - inicio)
		if restante > 0 then
			task.wait(restante)
		end
		if mantener or self.TokenGesto ~= token then
			return
		end
		self:_postura(nil)
		self:_aplicar(0.35)
	end)
	return duracion
end

-- Vuelve a la postura de reposo.
function Actor:Neutral(tiempo)
	self.TokenGesto = self.TokenGesto + 1
	self:_postura(nil)
	self:_aplicar(tiempo or 0.3)
end

-- Gira solo la cabeza hacia una posición (nil = mirar al frente).
function Actor:MirarCabeza(posicion, tiempo)
	if posicion then
		local rel = self.Raiz.CFrame:PointToObjectSpace(posicion)
		local angulo = math.deg(math.atan2(-rel.X, -rel.Z))
		self.GiroCabeza = math.clamp(angulo, -70, 70)
	else
		self.GiroCabeza = 0
	end
	self:_aplicar(tiempo or 0.3)
end

-- OBJETOS ----------------------------------------------------------------------

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

-- Pone un objeto (Model con PrimaryPart) en la mano derecha.
function Actor:Sostener(objeto)
	if self.Objeto and self.Objeto ~= objeto then
		self:Soltar(true)
	end
	local mano = self.Modelo:FindFirstChild("RightHand") or self.Modelo:FindFirstChild("Right Arm")
	if not mano or not objeto.PrimaryPart then
		warn("[Actor] No se puede sostener el objeto: falta la mano o el PrimaryPart del objeto")
		return
	end
	local agarre = mano:FindFirstChild("RightGripAttachment")
	local base = agarre and agarre.WorldCFrame or (mano.CFrame * CFrame.new(0, -mano.Size.Y / 2, 0))
	local offset = objeto:GetAttribute("OffsetAgarre")
	if typeof(offset) ~= "CFrame" then
		offset = CFrame.new()
	end

	fijarObjeto(objeto, true)
	objeto:PivotTo(base * offset)
	local soldadura = Instance.new("WeldConstraint")
	soldadura.Name = "AgarreHistoria"
	soldadura.Part0 = mano
	soldadura.Part1 = objeto.PrimaryPart
	soldadura.Parent = objeto.PrimaryPart
	fijarObjeto(objeto, false)

	self.Objeto = objeto
	self.Postura = "Sostener"
	self:_postura(nil)
	self:_aplicar(0.3)
end

-- Suelta el objeto que lleva (no lo coloca en ningún sitio). Devuelve el objeto.
function Actor:Soltar(sinAplicar)
	local objeto = self.Objeto
	if not objeto then
		return nil
	end
	local soldadura = objeto.PrimaryPart and objeto.PrimaryPart:FindFirstChild("AgarreHistoria")
	if soldadura then
		soldadura:Destroy()
	end
	fijarObjeto(objeto, true)
	self.Objeto = nil
	self.Postura = nil
	if not sinAplicar then
		self:_postura(nil)
		self:_aplicar(0.3)
	end
	return objeto
end

return Actor
