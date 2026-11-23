--[[
	EFECTOS · Textos en pantalla, fundidos y filtros de color
	Studio: ReplicatedStorage > StoryTemplate > Modulos > Efectos

	Todo se dibuja dentro del área 9:16 (Guias.Lienzo), así que nunca se sale
	del encuadre vertical. Lo usan las acciones "Texto", "Fundido" y "Filtro".

	ESTILOS DE TEXTO
	  Titulo     → letras grandes amarillas con borde negro (frase final, ganchos)
	  Rotulo     → nota adhesiva amarilla torcida (fechas, lugares: "1974")
	  Icono      → emoji que rebota (💡, ❗, ❓)
	  Subtitulo  → texto blanco abajo, en la zona reservada

	FILTROS
	  Recuerdo   → tonos sepia y apagados (flashbacks)
	  Calido     → luz de tarde
	  Ninguno    → quita el filtro
]]

local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Guias = require(script.Parent:WaitForChild("Guias"))

local Efectos = {}

local AMARILLO = Color3.fromRGB(255, 222, 60)

local function tween(obj, t, props, estilo, direccion)
	local tw = TweenService:Create(obj, TweenInfo.new(t, estilo or Enum.EasingStyle.Quad, direccion or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function etiqueta(padre, texto, fuente, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = fuente
	l.TextScaled = true
	l.TextWrapped = true
	l.TextColor3 = color
	l.Text = texto
	l.Parent = padre
	return l
end

-- Entrada con rebote (escala 0 → 1.12 → 1)
local function aparecer(obj)
	local escala = Instance.new("UIScale")
	escala.Scale = 0
	escala.Parent = obj
	local t1 = tween(escala, 0.18, { Scale = 1.12 }, Enum.EasingStyle.Back)
	t1.Completed:Connect(function()
		tween(escala, 0.1, { Scale = 1 })
	end)
	return escala
end

-- Desvanece todos los textos, fondos y bordes de "obj" y lo destruye.
local function desvanecer(obj, t)
	t = t or 0.25
	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("TextLabel") then
			tween(d, t, { TextTransparency = 1, TextStrokeTransparency = 1, BackgroundTransparency = 1 })
		elseif d:IsA("Frame") then
			tween(d, t, { BackgroundTransparency = 1 })
		elseif d:IsA("UIStroke") then
			tween(d, t, { Transparency = 1 })
		end
	end
	if obj:IsA("Frame") then
		tween(obj, t, { BackgroundTransparency = 1 })
	end
	task.delay(t + 0.05, function()
		obj:Destroy()
	end)
end

--[[
	Muestra un texto. op (opcional):
	  Posicion = Vector2 (escala 0-1 del área 9:16)
	  Tamano   = Vector2 (escala)
	  Color    = Color3
	  Giro     = grados
	Devuelve el objeto creado. Si duracion es nil se queda hasta Efectos.Limpiar().
]]
function Efectos.Texto(texto, estilo, duracion, op)
	local lienzo = Guias.Lienzo
	if not lienzo then
		return nil
	end
	op = op or {}
	estilo = estilo or "Titulo"
	local raiz

	if estilo == "Rotulo" then
		local pos = op.Posicion or Vector2.new(0.5, 0.11)
		local tam = op.Tamano or Vector2.new(0.38, 0.1)
		raiz = Instance.new("Frame")
		raiz.BackgroundTransparency = 1
		raiz.AnchorPoint = Vector2.new(0.5, 0.5)
		raiz.Position = UDim2.fromScale(pos.X, pos.Y)
		raiz.Size = UDim2.fromScale(tam.X, tam.Y)
		raiz.Rotation = op.Giro or -4
		raiz.ZIndex = 20
		local sombra = Instance.new("Frame")
		sombra.Size = UDim2.fromScale(1, 1)
		sombra.Position = UDim2.new(0, 5, 0, 6)
		sombra.BackgroundColor3 = Color3.new(0, 0, 0)
		sombra.BackgroundTransparency = 0.7
		sombra.BorderSizePixel = 0
		sombra.ZIndex = 1
		sombra.Parent = raiz
		local nota = Instance.new("Frame")
		nota.Size = UDim2.fromScale(1, 1)
		nota.BackgroundColor3 = op.Color or AMARILLO
		nota.BorderSizePixel = 0
		nota.ZIndex = 2
		nota.Parent = raiz
		local banda = Instance.new("Frame")
		banda.Size = UDim2.fromScale(1, 0.14)
		banda.BackgroundColor3 = (op.Color or AMARILLO):Lerp(Color3.new(0.6, 0.45, 0), 0.25)
		banda.BorderSizePixel = 0
		banda.ZIndex = 1
		banda.Parent = nota
		local margen = Instance.new("Frame")
		margen.BackgroundTransparency = 1
		margen.Size = UDim2.fromScale(0.86, 0.72)
		margen.Position = UDim2.fromScale(0.07, 0.2)
		margen.ZIndex = 2
		margen.Parent = nota
		etiqueta(margen, texto, Enum.Font.PermanentMarker, Color3.fromRGB(55, 40, 20))
	elseif estilo == "Icono" then
		raiz = Instance.new("Frame")
		raiz.BackgroundTransparency = 1
		raiz.AnchorPoint = Vector2.new(0.5, 0.5)
		local pos = op.Posicion or Vector2.new(0.5, 0.2)
		local tam = op.Tamano or Vector2.new(0.22, 0.12)
		raiz.Position = UDim2.fromScale(pos.X, pos.Y)
		raiz.Size = UDim2.fromScale(tam.X, tam.Y)
		raiz.ZIndex = 20
		local l = etiqueta(raiz, texto, Enum.Font.GothamBold, Color3.new(1, 1, 1))
		l.ZIndex = 21
	elseif estilo == "Subtitulo" then
		raiz = Instance.new("Frame")
		raiz.BackgroundTransparency = 1
		raiz.AnchorPoint = Vector2.new(0.5, 0.5)
		raiz.Position = UDim2.fromScale(0.5, 0.91)
		raiz.Size = UDim2.fromScale(0.9, 0.09)
		raiz.ZIndex = 20
		local l = etiqueta(raiz, texto, Enum.Font.GothamBold, Color3.new(1, 1, 1))
		l.TextStrokeTransparency = 0
		l.ZIndex = 21
	else -- Titulo
		raiz = Instance.new("Frame")
		raiz.BackgroundTransparency = 1
		raiz.AnchorPoint = Vector2.new(0.5, 0.5)
		local pos = op.Posicion or Vector2.new(0.5, 0.3)
		local tam = op.Tamano or Vector2.new(0.92, 0.2)
		raiz.Position = UDim2.fromScale(pos.X, pos.Y)
		raiz.Size = UDim2.fromScale(tam.X, tam.Y)
		raiz.Rotation = op.Giro or -3
		raiz.ZIndex = 20
		local l = etiqueta(raiz, texto, Enum.Font.FredokaOne, op.Color or AMARILLO)
		l.ZIndex = 21
		local borde = Instance.new("UIStroke")
		borde.Color = Color3.fromRGB(20, 15, 10)
		borde.Thickness = 4
		borde.Parent = l
	end

	raiz.Name = "Texto_" .. estilo
	raiz.Parent = lienzo
	if estilo ~= "Subtitulo" then
		aparecer(raiz)
	end
	if estilo == "Icono" then
		-- pequeño rebote continuo
		task.spawn(function()
			local base = raiz.Position
			while raiz.Parent do
				tween(raiz, 0.35, { Position = base - UDim2.fromScale(0, 0.012) }, Enum.EasingStyle.Sine)
				task.wait(0.35)
				if not raiz.Parent then
					break
				end
				tween(raiz, 0.35, { Position = base }, Enum.EasingStyle.Sine)
				task.wait(0.35)
			end
		end)
	end
	if duracion then
		task.delay(duracion, function()
			if raiz.Parent then
				desvanecer(raiz)
			end
		end)
	end
	return raiz
end

-- Quita todos los textos que haya en pantalla.
function Efectos.Limpiar()
	if not Guias.Lienzo then
		return
	end
	for _, hijo in ipairs(Guias.Lienzo:GetChildren()) do
		if hijo.Name:sub(1, 6) == "Texto_" then
			desvanecer(hijo, 0.15)
		end
	end
end

--[[
	Fundido a un color y vuelta. Devuelve el tiempo hasta que la pantalla está
	totalmente cubierta (entrada + mantener): en ese momento se puede cambiar de
	entorno sin que se note. La salida ocurre sola después.
]]
function Efectos.Fundido(color, entrada, mantener, salida)
	local velo = Guias.Velo
	if not velo then
		return 0
	end
	entrada = entrada or 0.3
	mantener = mantener or 0.1
	salida = salida or 0.35
	if color == "Blanco" then
		velo.BackgroundColor3 = Color3.new(1, 1, 1)
	elseif typeof(color) == "Color3" then
		velo.BackgroundColor3 = color
	else
		velo.BackgroundColor3 = Color3.new(0, 0, 0)
	end
	velo.BackgroundTransparency = 1
	tween(velo, entrada, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine)
	task.delay(entrada + mantener, function()
		tween(velo, salida, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
	end)
	return entrada + mantener
end

local FILTROS = {
	Recuerdo = { Saturation = -0.65, Contrast = 0.12, Brightness = 0.04, TintColor = Color3.fromRGB(255, 226, 180) },
	Calido = { Saturation = 0.05, Contrast = 0.05, Brightness = 0.02, TintColor = Color3.fromRGB(255, 238, 215) },
}

-- Aplica (o quita con "Ninguno"/nil) un filtro de color a toda la imagen.
function Efectos.Filtro(nombre)
	local cc = Lighting:FindFirstChild("FiltroHistoria")
	local def = FILTROS[nombre or ""]
	if not def then
		if cc then
			cc:Destroy()
		end
		return
	end
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "FiltroHistoria"
		cc.Parent = Lighting
	end
	for k, v in pairs(def) do
		cc[k] = v
	end
end

-- Tono de color propio de cada entorno (atributos Tinte / Saturacion del Model).
function Efectos.TonoEntorno(tinte, saturacion)
	local cc = Lighting:FindFirstChild("TonoEntorno")
	if not tinte and not saturacion then
		if cc then
			cc:Destroy()
		end
		return
	end
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "TonoEntorno"
		cc.Parent = Lighting
	end
	cc.TintColor = tinte or Color3.new(1, 1, 1)
	cc.Saturation = saturacion or 0
end

return Efectos
