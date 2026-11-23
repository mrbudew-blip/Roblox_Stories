--[[
	GUIAS · Encuadre vertical 9:16 en pantalla
	Studio: ReplicatedStorage > StoryTemplate > Modulos > Guias

	· Si la ventana no es 9:16, dibuja bandas negras para que solo se vea la
	  zona que acabará en el vídeo (Config.BandasNegras).
	· Dibuja un recuadro verde con la zona segura (Config.MostrarGuias).
	· Ajusta el campo de visión para que la composición sea idéntica sea cual
	  sea el tamaño de la ventana.
]]

local Players = game:GetService("Players")

local Guias = {}

-- Rectángulo (x, y, ancho, alto) en píxeles del área 9:16 centrada en la ventana.
function Guias.Rect(viewport, aspecto)
	local W, H = viewport.X, viewport.Y
	if H <= 0 then
		return 0, 0, W, H
	end
	if W / H > aspecto then
		local w = H * aspecto
		return (W - w) / 2, 0, w, H
	end
	local h = W / aspecto
	return 0, (H - h) / 2, W, h
end

-- FOV real de la cámara para que el área 9:16 tenga exactamente "fov" en vertical.
function Guias.FOVReal(camara, fov, aspecto)
	local vp = camara.ViewportSize
	if vp.Y <= 0 then
		return fov
	end
	local _, _, _, h = Guias.Rect(vp, aspecto)
	if h >= vp.Y - 0.5 then
		return fov
	end
	return math.deg(2 * math.atan(math.tan(math.rad(fov) / 2) * vp.Y / h))
end

function Guias.Crear(config, margenes)
	local jugador = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "GuiasVertical"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local barras = {}
	for i = 1, 4 do
		local f = Instance.new("Frame")
		f.Name = "Banda" .. i
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Visible = config.BandasNegras ~= false
		f.Parent = gui
		barras[i] = f
	end

	-- Lienzo: el área 9:16 exacta, donde se colocan los rótulos y textos
	local lienzo = Instance.new("Frame")
	lienzo.Name = "Lienzo"
	lienzo.BackgroundTransparency = 1
	lienzo.ClipsDescendants = true
	lienzo.ZIndex = 5
	lienzo.Parent = gui
	Guias.Lienzo = lienzo

	-- Velo para fundidos (cubre toda la pantalla)
	local velo = Instance.new("Frame")
	velo.Name = "Velo"
	velo.Size = UDim2.fromScale(1, 1)
	velo.BackgroundColor3 = Color3.new(0, 0, 0)
	velo.BackgroundTransparency = 1
	velo.BorderSizePixel = 0
	velo.ZIndex = 50
	velo.Parent = gui
	Guias.Velo = velo

	-- Reloj de la escena (solo con las guías activas): ayuda a comprobar la sincronización
	local reloj = Instance.new("TextLabel")
	reloj.Name = "Reloj"
	reloj.BackgroundColor3 = Color3.new(0, 0, 0)
	reloj.BackgroundTransparency = 0.4
	reloj.TextColor3 = Color3.fromRGB(0, 255, 140)
	reloj.Font = Enum.Font.Code
	reloj.TextSize = 14
	reloj.Size = UDim2.fromOffset(150, 20)
	reloj.Position = UDim2.fromOffset(6, 6)
	reloj.Text = ""
	reloj.Visible = config.MostrarGuias == true
	reloj.ZIndex = 40
	reloj.Parent = lienzo
	Guias.Reloj = reloj

	local zona = Instance.new("Frame")
	zona.Name = "ZonaSegura"
	zona.BackgroundTransparency = 1
	zona.Visible = config.MostrarGuias == true
	zona.Parent = gui
	local borde = Instance.new("UIStroke")
	borde.Color = Color3.fromRGB(0, 255, 140)
	borde.Thickness = 2
	borde.Transparency = 0.2
	borde.Parent = zona
	local texto = Instance.new("TextLabel")
	texto.BackgroundTransparency = 1
	texto.Size = UDim2.new(1, 0, 0, 18)
	texto.Position = UDim2.new(0, 0, 1, 4)
	texto.Font = Enum.Font.GothamBold
	texto.TextSize = 12
	texto.TextColor3 = Color3.fromRGB(0, 255, 140)
	texto.Text = "Zona segura · Config.MostrarGuias = false para grabar"
	texto.Parent = zona

	local function actualizar()
		local vp = workspace.CurrentCamera.ViewportSize
		local x, y, w, h = Guias.Rect(vp, config.Aspecto)
		barras[1].Position = UDim2.fromOffset(0, 0)
		barras[1].Size = UDim2.fromOffset(x, vp.Y)
		barras[2].Position = UDim2.fromOffset(x + w, 0)
		barras[2].Size = UDim2.fromOffset(vp.X - x - w, vp.Y)
		barras[3].Position = UDim2.fromOffset(x, 0)
		barras[3].Size = UDim2.fromOffset(w, y)
		barras[4].Position = UDim2.fromOffset(x, y + h)
		barras[4].Size = UDim2.fromOffset(w, vp.Y - y - h)
		lienzo.Position = UDim2.fromOffset(x, y)
		lienzo.Size = UDim2.fromOffset(w, h)
		zona.Position = UDim2.fromOffset(x + w * margenes.Lateral, y + h * margenes.Superior)
		zona.Size = UDim2.fromOffset(w * (1 - 2 * margenes.Lateral), h * (1 - margenes.Superior - margenes.Inferior))
	end
	actualizar()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(actualizar)

	gui.Parent = jugador:WaitForChild("PlayerGui")
	Guias.Gui = gui
	return gui
end

-- Actualiza el reloj de la escena (segundos desde el primer paso).
function Guias.Tiempo(t, texto)
	if Guias.Reloj and Guias.Reloj.Visible then
		Guias.Reloj.Text = string.format(" t = %6.2f s %s", t, texto or "")
	end
end

return Guias
