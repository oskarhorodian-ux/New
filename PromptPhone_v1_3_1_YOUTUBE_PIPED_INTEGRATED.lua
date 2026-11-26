--[[
	PROMPT PHONE v1.3.1 — CORE + PIPED YOUTUBE + REALITY MODIFIER v5
	Виртуальный смартфон для Roblox (Luau). Запуск: Delta Executor (Android).

	Содержит только ядро:
	  1. Config / Theme / утилиты (Signal, Maid, New, tween, drag)
	  2. WindowManager  — окна: открыть / закрыть / свернуть / переместить / несколько окон
	  3. Apps           — реестр приложений (Id, Name, Icon, OnOpen, OnClose, свой Window)
	  4. Modules        — подключение будущих модулей без правки ядра
	  5. Shell          — окно телефона (домашний экран + список открытых окон)
	  6. API / Boot     — публичный объект PromptPhone, корректная перезагрузка

	Публичный API после запуска: getgenv().PromptPhone
	Встроены приложения YouTube и Reality Modifier; другие приложения подключаются модулями.
]]

------------------------------------------------------------------
-- 0. КОНФИГ И СЕРВИСЫ
------------------------------------------------------------------
local CONFIG = {
	Name = "Prompt Phone",
	Version = "1.3.1-131",
	GuiName = "PromptPhone_Root",
	EnvKey = "PromptPhone",
	Debug = false, -- true = в консоль выводится traceback ошибок
}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	warn("[Prompt Phone] Скрипт нужно запускать на клиенте (LocalPlayer не найден).")
	return
end

local ENV = (typeof(getgenv) == "function" and getgenv()) or _G

local TAG = "[Prompt Phone]"
local function log(...)
	print(TAG, ...)
end
local function warnf(fmt, ...)
	warn(TAG .. " " .. string.format(fmt, ...))
end

local function safeCall(label, fn, ...)
	local ok, res = xpcall(fn, function(err)
		if CONFIG.Debug then
			return tostring(err) .. "\n" .. debug.traceback()
		end
		return tostring(err)
	end, ...)
	if not ok then
		warnf("Ошибка в «%s»: %s", tostring(label), tostring(res))
	end
	return ok, res
end

local State = { Gui = nil, Destroyed = false, ShuttingDown = false }
local API -- заполняется ниже

local Theme = {
	Bg = Color3.fromRGB(14, 16, 24),
	Surface = Color3.fromRGB(22, 25, 36),
	Bar = Color3.fromRGB(32, 36, 52),
	BarInactive = Color3.fromRGB(24, 27, 38),
	Stroke = Color3.fromRGB(58, 63, 84),
	Accent = Color3.fromRGB(88, 101, 242),
	Text = Color3.fromRGB(238, 240, 248),
	Muted = Color3.fromRGB(150, 156, 178),
	Danger = Color3.fromRGB(237, 90, 90),
	Warning = Color3.fromRGB(246, 190, 70),
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
	Radius = 16,
	PhoneRadius = 30,
	TitleBarHeight = 38,
}

------------------------------------------------------------------
-- 1. УТИЛИТЫ
------------------------------------------------------------------
-- Signal
local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ _h = {} }, Signal)
end
function Signal:Connect(fn)
	local h = { fn = fn }
	table.insert(self._h, h)
	local conn = {}
	function conn:Disconnect()
		h.dead = true
		local i = table.find(self._list or {}, h)
		if i then
			table.remove(self._list, i)
		end
	end
	conn._list = self._h
	conn.Destroy = conn.Disconnect
	return conn
end
function Signal:Fire(...)
	for _, h in ipairs(table.clone(self._h)) do
		if not h.dead then
			safeCall("обработчик сигнала", h.fn, ...)
		end
	end
end

-- Maid (очистка соединений / объектов / функций)
local Maid = {}
Maid.__index = Maid
function Maid.new()
	return setmetatable({ _items = {} }, Maid)
end
function Maid:Give(item)
	table.insert(self._items, item)
	return item
end
function Maid:Clean()
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		local x = items[i]
		local ty = typeof(x)
		if ty == "RBXScriptConnection" then
			pcall(function() x:Disconnect() end)
		elseif ty == "Instance" then
			pcall(function() x:Destroy() end)
		elseif ty == "function" then
			safeCall("Maid.function", x)
		elseif ty == "thread" then
			pcall(task.cancel, x)
		elseif type(x) == "table" then
			if type(x.Disconnect) == "function" then
				pcall(function() x:Disconnect() end)
			elseif type(x.Destroy) == "function" then
				pcall(function() x:Destroy() end)
			end
		end
	end
end

local RootMaid = Maid.new()

-- Создание инстансов
local function New(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(r)
	return New("UICorner", { CornerRadius = r })
end

local function tween(obj, dur, props, style, dir)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(dur, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function getViewport()
	local v = State.Gui and State.Gui.AbsoluteSize or Vector2.zero
	if v.X < 2 or v.Y < 2 then
		local cam = workspace.CurrentCamera
		v = cam and cam.ViewportSize or Vector2.new(800, 450)
	end
	return v
end

local function clampToScreen(pos, size)
	local vp = getViewport()
	local mx = math.min(80, size.X)
	local x = math.clamp(pos.X, -(size.X - mx), vp.X - mx)
	local y = math.clamp(pos.Y, 0, vp.Y - math.min(Theme.TitleBarHeight, size.Y))
	return Vector2.new(x, y)
end

-- Иконка: rbxassetid / число = картинка; иначе текст/эмодзи; иначе первая буква названия
local function makeIcon(parent, icon, fallback, color, px)
	local box = New("Frame", {
		Size = UDim2.fromOffset(px, px),
		BackgroundColor3 = color or Theme.Accent,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = parent,
	}, { corner(UDim.new(0.26, 0)) })
	local isImage = type(icon) == "number"
		or (type(icon) == "string" and (icon:sub(1, 13) == "rbxassetid://" or icon:sub(1, 11) == "rbxasset://"))
	if isImage then
		New("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = type(icon) == "number" and ("rbxassetid://" .. icon) or icon,
			Parent = box,
		})
	else
		local text = (type(icon) == "string" and icon ~= "") and icon
			or string.upper((tostring(fallback or "?")):match(utf8.charpattern) or "?")
		New("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			Font = Theme.FontBold,
			TextScaled = true,
			Parent = box,
		}, {
			New("UIPadding", {
				PaddingTop = UDim.new(0.22, 0),
				PaddingBottom = UDim.new(0.22, 0),
				PaddingLeft = UDim.new(0.22, 0),
				PaddingRight = UDim.new(0.22, 0),
			}),
		})
	end
	return box
end

-- Перетаскивание (мышь + тач). Позиции хранятся в Offset.
local function makeDraggable(handle, target, maid, opts)
	opts = opts or {}
	local dragging, activeInput = false, nil
	local startPtr, startPos, moved = Vector2.zero, Vector2.zero, 0

	maid:Give(handle.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end
		if dragging then
			return
		end
		dragging, activeInput, moved = true, input, 0
		startPtr = Vector2.new(input.Position.X, input.Position.Y)
		startPos = Vector2.new(target.Position.X.Offset, target.Position.Y.Offset)
		if opts.OnBegin then
			safeCall("drag.OnBegin", opts.OnBegin)
		end
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				conn:Disconnect()
				if dragging and activeInput == input then
					dragging = false
					if moved < 8 and opts.OnTap then
						safeCall("drag.OnTap", opts.OnTap)
					end
				end
			end
		end)
	end))

	maid:Give(UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input ~= activeInput then
			return
		end
		local d = Vector2.new(input.Position.X, input.Position.Y) - startPtr
		if d.Magnitude > moved then
			moved = d.Magnitude
		end
		if moved < 4 then
			return
		end
		local np = clampToScreen(startPos + d, target.AbsoluteSize)
		target.Position = UDim2.fromOffset(np.X, np.Y)
	end))
end

------------------------------------------------------------------
-- 2. WINDOW MANAGER
------------------------------------------------------------------
local WM = {
	_list = {},
	_byId = {},
	_nextId = 0,
	_z = 10,
	_cascade = 0,
	_focused = nil,
	Created = Signal.new(),
	Closed = Signal.new(),
	StateChanged = Signal.new(),
	Focused = Signal.new(),
	Changed = Signal.new(), -- любое изменение (для UI-списков)
}

local Window = {}
Window.__index = Window

local HIDE_SCALE = 0.86

function Window:_applyFocus(on)
	tween(self.TitleBar, 0.15, { BackgroundColor3 = on and Theme.Bar or Theme.BarInactive })
	tween(self.TitleLabel, 0.15, { TextTransparency = on and 0 or 0.35 })
end

function Window:_playIn()
	self._token = self._token + 1
	self.Root.Visible = true
	tween(self.Body, 0.2, { GroupTransparency = 0 })
	tween(self.Scale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
end

function Window:_playOut(dur, cb)
	self._token = self._token + 1
	local t = self._token
	tween(self.Body, dur, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(self.Scale, dur, { Scale = HIDE_SCALE }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(dur + 0.02, function()
		if self._token == t then
			cb()
		end
	end)
end

function Window:SetTitle(text)
	self.Title = tostring(text)
	self.TitleLabel.Text = self.Title
	WM.Changed:Fire()
end

function Window:SetSize(size)
	self.Size = size
	self.Root.Size = UDim2.fromOffset(size.X, size.Y)
end

function Window:SetPosition(pos)
	local p = clampToScreen(pos, self.Size)
	self.Root.Position = UDim2.fromOffset(p.X, p.Y)
end

function Window:Focus()
	WM:Focus(self)
end

function Window:Minimize()
	if self.State ~= "open" then
		return
	end
	self.State = "minimized"
	if WM._focused == self then
		WM._focused = nil
	end
	self:_playOut(0.18, function()
		self.Root.Visible = false
	end)
	WM.StateChanged:Fire(self, "minimized")
	WM.Changed:Fire()
	WM:_focusTop()
end

function Window:Restore()
	if self.State ~= "minimized" then
		return
	end
	self.State = "open"
	self:_playIn()
	WM.StateChanged:Fire(self, "open")
	WM:Focus(self)
end

function Window:Close(instant)
	if self.State == "closing" or self.State == "closed" then
		return
	end
	local visible = self.State == "open"
	self.State = "closing"
	self.Closing:Fire(self)
	WM.StateChanged:Fire(self, "closing")
	if instant or not visible then
		self:_finalize()
	else
		self:_playOut(0.16, function()
			self:_finalize()
		end)
	end
end

function Window:Destroy()
	self:Close(true)
end

function Window:_finalize()
	if self.State == "closed" then
		return
	end
	self.State = "closed"
	self.Maid:Clean()
	if self.Root then
		pcall(function() self.Root:Destroy() end)
	end
	WM:_remove(self)
	self.Closed:Fire(self)
	WM.Closed:Fire(self)
	WM.Changed:Fire()
end

function WM:_remove(win)
	local i = table.find(self._list, win)
	if i then
		table.remove(self._list, i)
	end
	self._byId[win.Id] = nil
	if self._focused == win then
		self._focused = nil
		self:_focusTop()
	end
end

function WM:_focusTop()
	local best
	for _, w in ipairs(self._list) do
		if w.State == "open" and (not best or w.Root.ZIndex > best.Root.ZIndex) then
			best = w
		end
	end
	if best then
		self:Focus(best)
	end
end

function WM:Focus(win)
	if not win or win.State ~= "open" or State.Destroyed then
		return
	end
	self._z = self._z + 1
	win.Root.ZIndex = self._z
	if self._focused == win then
		return
	end
	local prev = self._focused
	self._focused = win
	if prev and prev.State ~= "closed" and prev.Root and prev.Root.Parent then
		prev:_applyFocus(false)
	end
	win:_applyFocus(true)
	self.Focused:Fire(win)
	self.Changed:Fire()
end

function WM:Get(id)
	return self._byId[id]
end

function WM:List()
	return table.clone(self._list)
end

function WM:FindByApp(appId)
	local out = {}
	for _, w in ipairs(self._list) do
		if w.AppId == appId and w.State ~= "closing" and w.State ~= "closed" then
			table.insert(out, w)
		end
	end
	return out
end

function WM:CloseAll(instant)
	for _, w in ipairs(table.clone(self._list)) do
		w:Close(instant)
	end
end

function WM:ClampAll()
	local vp = getViewport()
	for _, w in ipairs(table.clone(self._list)) do
		if w.Root and w.Root.Parent then
			if not w.IsPhone then
				local ns = Vector2.new(math.min(w.Size.X, vp.X - 12), math.min(w.Size.Y, vp.Y - 12))
				if ns ~= w.Size then
					w:SetSize(ns)
				end
			end
			w:SetPosition(Vector2.new(w.Root.Position.X.Offset, w.Root.Position.Y.Offset))
		end
	end
end

--[[ opts:
	Title, Icon, IconColor, Size(Vector2), Position(Vector2), AppId,
	CanMinimize(bool, по умолчанию true), IsPhone(bool),
	OnCloseRequest(fn), OnMinimizeRequest(fn) -- переопределяют поведение кнопок
]]
function WM:Create(opts)
	if State.Destroyed or not State.Gui then
		return nil
	end
	opts = opts or {}
	self._nextId = self._nextId + 1
	local id = self._nextId
	local vp = getViewport()
	local size = opts.Size or Vector2.new(300, 380)
	size = Vector2.new(
		math.max(160, math.min(size.X, vp.X - 12)),
		math.max(120, math.min(size.Y, vp.Y - 12))
	)
	local pos = opts.Position
	if not pos then
		self._cascade = (self._cascade % 6) + 1
		local off = (self._cascade - 3) * 26
		pos = Vector2.new((vp.X - size.X) / 2 + off, (vp.Y - size.Y) / 2 + off)
	end
	pos = clampToScreen(pos, size)

	local TB = Theme.TitleBarHeight
	local isPhone = opts.IsPhone == true
	local radius = isPhone and Theme.PhoneRadius or Theme.Radius

	local win = setmetatable({
		Id = id,
		Title = tostring(opts.Title or "Window"),
		AppId = opts.AppId,
		IsPhone = isPhone,
		State = "open",
		Size = size,
		Maid = Maid.new(),
		Closing = Signal.new(),
		Closed = Signal.new(),
		OnCloseRequest = opts.OnCloseRequest,
		OnMinimizeRequest = opts.OnMinimizeRequest,
		_token = 0,
	}, Window)

	local root = New("Frame", {
		Name = "Window_" .. id,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(pos.X, pos.Y),
		ZIndex = self._z,
		Parent = State.Gui,
	})
	local scale = New("UIScale", { Scale = HIDE_SCALE })
	local body = New("CanvasGroup", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Active = true, -- тапы не проваливаются в игру
		Parent = root,
	}, {
		corner(UDim.new(0, radius)),
		scale,
		New("UIStroke", {
			Color = Theme.Stroke,
			Thickness = isPhone and 3 or 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})

	local titleBar = New("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, TB),
		BackgroundColor3 = Theme.Bar,
		BorderSizePixel = 0,
		Active = true,
		Parent = body,
	})

	local leftOff = 14
	if opts.Icon ~= nil or (opts.AppId ~= nil and not isPhone) then
		local ic = makeIcon(titleBar, opts.Icon, opts.Title, opts.IconColor, 22)
		ic.AnchorPoint = Vector2.new(0, 0.5)
		ic.Position = UDim2.new(0, 10, 0.5, 0)
		leftOff = 40
	end

	local titleLabel = New("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, leftOff, 0, 0),
		Size = UDim2.new(1, -(leftOff + 84), 1, 0),
		Text = win.Title,
		TextColor3 = Theme.Text,
		Font = Theme.FontBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = titleBar,
	})

	local function circleButton(text, color, xOff)
		return New("TextButton", {
			Size = UDim2.fromOffset(30, 30),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xOff, 0.5, 0),
			BackgroundColor3 = color,
			Text = text,
			TextColor3 = Color3.fromRGB(22, 22, 30),
			Font = Theme.FontBold,
			TextSize = 20,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			Parent = titleBar,
		}, { corner(UDim.new(1, 0)) })
	end

	local closeBtn = circleButton("×", Theme.Danger, -8)
	win.Maid:Give(closeBtn.Activated:Connect(function()
		if win.OnCloseRequest then
			safeCall("OnCloseRequest", win.OnCloseRequest, win)
		else
			win:Close()
		end
	end))

	if opts.CanMinimize ~= false then
		local minBtn = circleButton("–", Theme.Warning, -44)
		win.Maid:Give(minBtn.Activated:Connect(function()
			if win.OnMinimizeRequest then
				safeCall("OnMinimizeRequest", win.OnMinimizeRequest, win)
			else
				win:Minimize()
			end
		end))
	end

	local content = New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, TB),
		Size = UDim2.new(1, 0, 1, -TB),
		ClipsDescendants = true,
		Parent = body,
	})

	win.Root, win.Body, win.Scale = root, body, scale
	win.TitleBar, win.TitleLabel, win.Content = titleBar, titleLabel, content

	-- Перетаскивание за заголовок + фокус по нажатию
	makeDraggable(titleBar, root, win.Maid, {
		OnBegin = function()
			WM:Focus(win)
		end,
	})
	win.Maid:Give(body.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			WM:Focus(win)
		end
	end))

	table.insert(self._list, win)
	self._byId[id] = win
	win:_playIn()
	self:Focus(win)
	self.Created:Fire(win)
	self.Changed:Fire()
	return win
end

------------------------------------------------------------------
-- 3. РЕЕСТР ПРИЛОЖЕНИЙ
------------------------------------------------------------------
local Apps = {
	_apps = {},
	_order = {},
	Changed = Signal.new(),
	Opened = Signal.new(),
}

--[[ def:
	Id (string, уникальный)        — обязательно
	Name (string)                   — обязательно
	OnOpen (function(ctx))          — обязательно; строит интерфейс в ctx.Content
	OnClose (function(ctx))         — необязательно; вызывается перед закрытием окна
	Icon (rbxassetid/число/текст)   — необязательно
	IconColor (Color3)              — необязательно
	WindowSize (Vector2)            — необязательно
	Singleton (bool)                — по умолчанию true (одно окно на приложение)
	ctx = { App, Window, Content, Maid, Phone, Log }
]]
function Apps:Register(def)
	if type(def) ~= "table" then
		warnf("Register: ожидается таблица с описанием приложения.")
		return false
	end
	if type(def.Id) ~= "string" or def.Id == "" then
		warnf("Register: поле Id должно быть непустой строкой.")
		return false
	end
	if type(def.Name) ~= "string" or def.Name == "" then
		warnf("Register(%s): поле Name должно быть непустой строкой.", def.Id)
		return false
	end
	if type(def.OnOpen) ~= "function" then
		warnf("Register(%s): поле OnOpen должно быть функцией.", def.Id)
		return false
	end
	if def.OnClose ~= nil and type(def.OnClose) ~= "function" then
		warnf("Register(%s): поле OnClose должно быть функцией.", def.Id)
		return false
	end
	if self._apps[def.Id] then
		warnf("Register: приложение «%s» уже зарегистрировано. Сначала вызовите Unregister.", def.Id)
		return false
	end
	local app = {
		Id = def.Id,
		Name = def.Name,
		Icon = def.Icon,
		IconColor = typeof(def.IconColor) == "Color3" and def.IconColor or Theme.Accent,
		WindowSize = typeof(def.WindowSize) == "Vector2" and def.WindowSize or Vector2.new(300, 380),
		Singleton = def.Singleton ~= false,
		OnOpen = def.OnOpen,
		OnClose = def.OnClose,
	}
	self._apps[app.Id] = app
	table.insert(self._order, app.Id)
	log("Приложение зарегистрировано:", app.Name)
	self.Changed:Fire()
	return true
end

function Apps:Unregister(id)
	local app = self._apps[id]
	if not app then
		return false
	end
	self:Close(id)
	self._apps[id] = nil
	local i = table.find(self._order, id)
	if i then
		table.remove(self._order, i)
	end
	self.Changed:Fire()
	return true
end

function Apps:Get(id)
	return self._apps[id]
end

function Apps:List()
	local out = {}
	for _, id in ipairs(self._order) do
		table.insert(out, self._apps[id])
	end
	return out
end

function Apps:IsOpen(id)
	return #WM:FindByApp(id) > 0
end

function Apps:Close(id)
	for _, w in ipairs(WM:FindByApp(id)) do
		w:Close()
	end
end

function Apps:Open(id)
	if State.Destroyed then
		return nil
	end
	local app = self._apps[id]
	if not app then
		warnf("Open: приложение «%s» не найдено.", tostring(id))
		return nil, "not_found"
	end
	if app.Singleton then
		local existing = WM:FindByApp(id)[1]
		if existing then
			if existing.State == "minimized" then
				existing:Restore()
			else
				WM:Focus(existing)
			end
			return existing
		end
	end
	local win = WM:Create({
		Title = app.Name,
		Icon = app.Icon or "",
		IconColor = app.IconColor,
		Size = app.WindowSize,
		AppId = id,
	})
	if not win then
		return nil, "no_window"
	end
	local ctx = {
		App = app,
		Window = win,
		Content = win.Content,
		Maid = win.Maid,
		Phone = API,
		Log = function(...)
			log("[" .. app.Name .. "]", ...)
		end,
	}
	win.Context = ctx
	local opened = false
	win.Closing:Connect(function()
		if opened and app.OnClose then
			safeCall(app.Name .. ".OnClose", app.OnClose, ctx)
		end
	end)
	local ok = safeCall(app.Name .. ".OnOpen", app.OnOpen, ctx)
	if not ok then
		win:Close(true)
		warnf("Приложение «%s» не удалось открыть.", app.Name)
		return nil, "open_failed"
	end
	opened = true
	self.Opened:Fire(app, win)
	return win
end

------------------------------------------------------------------
-- 4. МОДУЛИ (точка подключения будущих функций)
------------------------------------------------------------------
local Modules = { _loaded = {} }

-- init(Phone) может вернуть функцию очистки (cleanup)
function Modules:Register(name, init)
	if type(name) ~= "string" or name == "" then
		warnf("Modules:Register: имя модуля должно быть строкой.")
		return false
	end
	if type(init) ~= "function" then
		warnf("Modules:Register(%s): init должен быть функцией.", name)
		return false
	end
	if self._loaded[name] then
		warnf("Модуль «%s» уже подключён.", name)
		return false
	end
	local ok, cleanup = safeCall("модуль " .. name, init, API)
	if not ok then
		warnf("Модуль «%s» не подключён из-за ошибки (ядро продолжает работать).", name)
		return false
	end
	self._loaded[name] = { Cleanup = type(cleanup) == "function" and cleanup or nil }
	log("Модуль подключён:", name)
	return true
end

function Modules:Unload(name)
	local m = self._loaded[name]
	if not m then
		return false
	end
	self._loaded[name] = nil
	if m.Cleanup then
		safeCall("очистка модуля " .. name, m.Cleanup)
	end
	return true
end

function Modules:UnloadAll()
	for name in pairs(table.clone(self._loaded)) do
		self:Unload(name)
	end
end

function Modules:IsLoaded(name)
	return self._loaded[name] ~= nil
end

------------------------------------------------------------------
-- 5. SHELL — окно телефона
------------------------------------------------------------------
local Shell = {}

local function phoneSize(vp)
	local h = math.clamp(vp.Y * 0.82, 300, 640)
	local w = math.clamp(h * 0.5, 200, 320)
	h = math.min(h, vp.Y * 0.95)
	w = math.min(w, vp.X * 0.92)
	return Vector2.new(math.floor(w), math.floor(h))
end

function Shell:Minimize()
	local win = self.Window
	if not win or win.State ~= "open" then
		return
	end
	local p = Vector2.new(win.Root.Position.X.Offset, win.Root.Position.Y.Offset)
	win:Minimize()
	self:_showBubble(p)
end

function Shell:Restore()
	self:_hideBubble()
	if self.Window then
		self.Window:Restore()
	end
end

function Shell:_showBubble(pos)
	local b = self.Bubble
	if not b then
		return
	end
	local p = clampToScreen(pos, b.AbsoluteSize.X > 0 and b.AbsoluteSize or Vector2.new(54, 54))
	b.Position = UDim2.fromOffset(p.X, p.Y)
	self._bubbleToken = (self._bubbleToken or 0) + 1
	b.Visible = true
	self.BubbleScale.Scale = 0
	tween(self.BubbleScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

function Shell:_hideBubble()
	local b = self.Bubble
	if not b or not b.Visible then
		return
	end
	self._bubbleToken = (self._bubbleToken or 0) + 1
	local t = self._bubbleToken
	tween(self.BubbleScale, 0.12, { Scale = 0 })
	task.delay(0.14, function()
		if self._bubbleToken == t and b.Parent then
			b.Visible = false
		end
	end)
end

function Shell:Refit()
	if not self.Window or self.Window.State == "closed" then
		return
	end
	self.Window:SetSize(phoneSize(getViewport()))
	if self.Bubble and self.Bubble.Visible then
		self:_showBubble(Vector2.new(self.Bubble.Position.X.Offset, self.Bubble.Position.Y.Offset))
	end
end

function Shell:RefreshHome()
	if State.Destroyed or not self.Grid then
		return
	end
	for _, c in ipairs(self.Grid:GetChildren()) do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
	local apps = Apps:List()
	self.Empty.Visible = #apps == 0
	for i, app in ipairs(apps) do
		local tile = New("TextButton", {
			Name = "App_" .. app.Id,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = i,
			Parent = self.Grid,
		})
		local icon = makeIcon(tile, app.Icon, app.Name, app.IconColor, 54)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 4)
		local sc = New("UIScale", { Scale = 1, Parent = icon })
		New("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, 62),
			Size = UDim2.new(1, 0, 0, 22),
			Text = app.Name,
			TextColor3 = Theme.Text,
			Font = Theme.Font,
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = tile,
		})
		tile.InputBegan:Connect(function(input)
			local t = input.UserInputType
			if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
				tween(sc, 0.08, { Scale = 0.9 })
			end
		end)
		tile.InputEnded:Connect(function()
			tween(sc, 0.12, { Scale = 1 })
		end)
		tile.Activated:Connect(function()
			Apps:Open(app.Id)
		end)
	end
end

function Shell:RefreshDock()
	if State.Destroyed or not self.Dock then
		return
	end
	for _, c in ipairs(self.DockScroll:GetChildren()) do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
	local n = 0
	for _, w in ipairs(WM:List()) do
		if not w.IsPhone and w.State ~= "closing" and w.State ~= "closed" then
			n = n + 1
			local focused = (w == WM._focused)
			local minimized = (w.State == "minimized")
			local chip = New("TextButton", {
				Name = "Chip_" .. w.Id,
				Size = UDim2.fromOffset(0, 34),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = focused and Theme.Accent or Theme.Surface,
				Text = w.Title,
				TextColor3 = Theme.Text,
				TextTransparency = minimized and 0.4 or 0,
				Font = Theme.Font,
				TextSize = 13,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				LayoutOrder = n,
				Parent = self.DockScroll,
			}, {
				corner(UDim.new(0, 10)),
				New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
			})
			chip.Activated:Connect(function()
				if w.State == "minimized" then
					w:Restore()
				elseif w == WM._focused then
					w:Minimize()
				else
					WM:Focus(w)
				end
			end)
		end
	end
	self.Dock.Visible = n > 0
	self.Grid.Size = n > 0 and UDim2.new(1, 0, 1, -64) or UDim2.fromScale(1, 1)
end

function Shell:GoHome()
	if self.RecentsPanel then self.RecentsPanel.Visible = false end
	for _, w in ipairs(WM:List()) do
		if not w.IsPhone and w.State == "open" then
			w:Minimize()
		end
	end
	if self.Window then
		if self.Window.State == "minimized" then self.Window:Restore() end
		WM:Focus(self.Window)
	end
end

function Shell:ToggleRecents()
	if not self.RecentsPanel then return end
	local panel = self.RecentsPanel
	panel:ClearAllChildren()
	corner(UDim.new(0, 14)).Parent = panel
	local list = New("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 2,
		Parent = panel,
	}, {
		New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local count = 0
	for _, w in ipairs(WM:List()) do
		if not w.IsPhone and w.State ~= "closing" and w.State ~= "closed" then
			count += 1
			local item = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = Theme.Surface,
				BorderSizePixel = 0, Text = (w.State == "minimized" and "◌  " or "●  ") .. w.Title,
				TextColor3 = Theme.Text, Font = Theme.FontBold, TextSize = 13,
				LayoutOrder = count, Parent = list,
			})
			corner(UDim.new(0, 9)).Parent = item
			item.Activated:Connect(function()
				panel.Visible = false
				if w.State == "minimized" then w:Restore() else WM:Focus(w) end
			end)
		end
	end
	if count == 0 then
		New("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
			Text = "Нет открытых приложений", TextColor3 = Theme.Muted,
			Font = Theme.Font, TextSize = 13, Parent = panel })
	end
	panel.Visible = not panel.Visible
end

function Shell:Build()
	local vp = getViewport()
	local size = phoneSize(vp)
	local win = WM:Create({
		Title = CONFIG.Name,
		IsPhone = true,
		Size = size,
		Position = Vector2.new(math.floor((vp.X - size.X) / 2), math.floor((vp.Y - size.Y) / 2)),
		OnCloseRequest = function()
			API.Shutdown()
		end,
		OnMinimizeRequest = function()
			Shell:Minimize()
		end,
	})
	if not win then
		return false
	end
	self.Window = win
	local content = win.Content

	self.Grid = New("ScrollingFrame", {
		Name = "AppGrid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Muted,
		Parent = content,
	}, {
		New("UIPadding", {
			PaddingTop = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),
		New("UIGridLayout", {
			CellSize = UDim2.fromOffset(72, 88),
			CellPadding = UDim2.fromOffset(6, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	self.Empty = New("TextLabel", {
		Name = "Empty",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1, -32, 0, 90),
		Text = "Нет установленных приложений\n\nПриложения подключаются через PromptPhone.RegisterApp()",
		TextColor3 = Theme.Muted,
		Font = Theme.Font,
		TextSize = 14,
		TextWrapped = true,
		Visible = false,
		Parent = content,
	})

	self.Dock = New("Frame", {
		Name = "Dock",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 50),
		BackgroundColor3 = Theme.Bar,
		BorderSizePixel = 0,
		Visible = false,
		Parent = content,
	}, { corner(UDim.new(0, 16)) })
	self.DockScroll = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
		Parent = self.Dock,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})

	-- Системная нижняя панель навигации (Недавние / Домой / Назад)
	self.NavBar = New("Frame", {
		Name = "SystemNavigationBar", AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0,
		ZIndex = 200000, Parent = State.Gui,
	})
	local function navButton(name, text, xScale, callback)
		local b = New("TextButton", {
			Name = name, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(xScale, 0, 0.5, 0), Size = UDim2.fromOffset(68, 46),
			BackgroundTransparency = 1, BorderSizePixel = 0, Text = text,
			TextColor3 = Color3.fromRGB(155, 155, 160), Font = Enum.Font.Gotham,
			TextSize = 34, AutoButtonColor = false, ZIndex = 200001, Parent = self.NavBar,
		})
		b.Activated:Connect(callback)
		return b
	end
	self.RecentsPanel = New("Frame", {
		Name = "RecentAppsPanel", AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -62), Size = UDim2.new(0.82, 0, 0, 210),
		BackgroundColor3 = Color3.fromRGB(18, 19, 24), BorderSizePixel = 0,
		Visible = false, ZIndex = 200010, Parent = State.Gui,
	}, { corner(UDim.new(0, 14)), New("UIStroke", { Color = Theme.Stroke, Thickness = 1 }) })
	local recentsBtn = navButton("RecentAppsButton", "▯", 0.19, function()
		Shell:ToggleRecents()
	end)
	navButton("HomeButton", "○", 0.5, function()
		Shell:GoHome()
	end)
	navButton("BackButton", "⌄", 0.81, function()
		if Shell.RecentsPanel and Shell.RecentsPanel.Visible then
			Shell.RecentsPanel.Visible = false
			return
		end
		local focused = WM._focused
		if focused and not focused.IsPhone and focused.State == "open" then
			local ctx = focused.Context
			if ctx and type(ctx.OnBack) == "function" then
				local ok, handled = safeCall("обработчик Back приложения", ctx.OnBack)
				if ok and handled == true then return end
			end
			focused:Close()
		else
			Shell:GoHome()
		end
	end)
	-- Плавающая кнопка свёрнутого телефона
	self.BubbleScale = New("UIScale", { Scale = 0 })
	self.Bubble = New("TextButton", {
		Name = "PhoneBubble",
		Size = UDim2.fromOffset(54, 54),
		Position = UDim2.fromOffset(20, 120),
		BackgroundColor3 = Theme.Accent,
		Text = "P",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Theme.FontBold,
		TextSize = 26,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
		ZIndex = 100000,
		Parent = State.Gui,
	}, {
		corner(UDim.new(1, 0)),
		self.BubbleScale,
		New("UIStroke", { Color = Theme.Stroke, Thickness = 2 }),
	})
	makeDraggable(self.Bubble, self.Bubble, RootMaid, {
		OnTap = function()
			Shell:Restore()
		end,
	})

	RootMaid:Give(Apps.Changed:Connect(function() Shell:RefreshHome() end))
	RootMaid:Give(WM.Changed:Connect(function() Shell:RefreshDock() end))

	self:RefreshHome()
	self:RefreshDock()
	return true
end

------------------------------------------------------------------
-- 6. ПУБЛИЧНЫЙ API И ЗАПУСК
------------------------------------------------------------------
API = {
	Version = CONFIG.Version,
	Theme = Theme,
	Apps = Apps,
	Windows = WM,
	Modules = Modules,
	Shell = Shell,
	Utils = {
		New = New,
		Tween = tween,
		Maid = Maid,
		Signal = Signal,
		MakeDraggable = makeDraggable,
		MakeIcon = makeIcon,
		SafeCall = safeCall,
		Log = log,
		Warn = warnf,
	},
}

function API.RegisterApp(def)
	return Apps:Register(def)
end

function API.OpenApp(id)
	return Apps:Open(id)
end

-- Мгновенная выгрузка всего интерфейса и подключений
function API.Destroy()
	if State.Destroyed then
		return
	end
	State.Destroyed = true
	safeCall("выгрузка модулей", function() Modules:UnloadAll() end)
	safeCall("закрытие окон", function() WM:CloseAll(true) end)
	RootMaid:Clean()
	if State.Gui then
		pcall(function() State.Gui:Destroy() end)
	end
	if ENV[CONFIG.EnvKey] == API then
		ENV[CONFIG.EnvKey] = nil
	end
	log("Prompt Phone выгружен.")
end

-- Плавное закрытие всех окон, затем полная выгрузка
function API.Shutdown()
	if State.ShuttingDown or State.Destroyed then
		return
	end
	State.ShuttingDown = true
	log("Закрытие Prompt Phone…")
	WM:CloseAll(false)
	task.delay(0.4, API.Destroy)
end

-- Контейнеры, где мог остаться старый интерфейс
local function guiContainers()
	local list = {}
	if typeof(gethui) == "function" then
		local ok, h = pcall(gethui)
		if ok and typeof(h) == "Instance" then
			table.insert(list, h)
		end
	end
	table.insert(list, CoreGui)
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if pg then
		table.insert(list, pg)
	end
	return list
end

local function purgePrevious()
	local prev = ENV[CONFIG.EnvKey]
	if type(prev) == "table" and type(prev.Destroy) == "function" then
		safeCall("выгрузка предыдущей версии", prev.Destroy)
	end
	ENV[CONFIG.EnvKey] = nil
	for _, container in ipairs(guiContainers()) do
		pcall(function()
			for _, c in ipairs(container:GetChildren()) do
				if c.Name == CONFIG.GuiName then
					c:Destroy()
				end
			end
		end)
	end
end

local function mountGui(gui)
	pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(gui)
		end
	end)
	local targets = guiContainers()
	if #targets == 0 then
		local pg = LocalPlayer:WaitForChild("PlayerGui", 5)
		if pg then
			table.insert(targets, pg)
		end
	end
	for _, t in ipairs(targets) do
		local ok = pcall(function()
			gui.Parent = t
		end)
		if ok and gui.Parent == t then
			return true
		end
	end
	return false
end

local function boot()
	purgePrevious()

	local gui = New("ScreenGui", {
		Name = CONFIG.GuiName,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	if not mountGui(gui) then
		gui:Destroy()
		warnf("Не удалось разместить интерфейс (gethui / CoreGui / PlayerGui недоступны).")
		return false
	end
	State.Gui = gui

	-- Адаптация при смене размера экрана / поворота
	local resizeToken = 0
	RootMaid:Give(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		resizeToken = resizeToken + 1
		local t = resizeToken
		task.delay(0.12, function()
			if t ~= resizeToken or State.Destroyed then
				return
			end
			safeCall("адаптация размеров", function()
				Shell:Refit()
				WM:ClampAll()
			end)
		end)
	end))

	if not Shell:Build() then
		warnf("Не удалось создать окно телефона.")
		return false
	end

	ENV[CONFIG.EnvKey] = API
	log(string.format("Запущен %s v%s. Приложений: %d.", CONFIG.Name, CONFIG.Version, #Apps:List()))
	return true
end

local ok, result = safeCall("запуск Prompt Phone", boot)
if not ok or result == false then
	API.Destroy()
	return
end

------------------------------------------------------------------
-- МОДУЛИ: зона подключения (сейчас пусто — PART 1 только ядро)
------------------------------------------------------------------
-- Пример подключения (раскомментируйте и замените своим модулем):
--
-- PromptPhone.Modules:Register("MyModule", function(Phone)
--     Phone.RegisterApp({
--         Id = "my_app",
--         Name = "My App",
--         Icon = "M",                          -- текст или rbxassetid://...
--         IconColor = Color3.fromRGB(88, 101, 242),
--         WindowSize = Vector2.new(300, 260),
--         OnOpen = function(ctx)
--             -- строим интерфейс внутри ctx.Content, мусор складываем в ctx.Maid
--         end,
--         OnClose = function(ctx) end,
--     })
--     return function() Phone.Apps:Unregister("my_app") end  -- cleanup
-- end)
--
-- Следующие приложения можно подключать отдельными модулями. YouTube реализован ниже.

------------------------------------------------------------------
-- 7. APP: YOUTUBE
-- Piped API module integrated into the existing Prompt Phone window.
-- No separate ScreenGui/test phone is created.
------------------------------------------------------------------
do
	local Phone = ENV and ENV.PromptPhone
	if type(Phone) == "table" then
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")

local CONFIG = {
	REGION = "US",          -- регион ленты трендов
	TIMEOUT = 10,           -- секунд на один HTTP-запрос
	MAX_CARDS = 100,        -- максимум карточек в списке
	CACHE = "PromptPhone_YT_cache",
}

local STATIC_INSTANCES = {
	"https://pipedapi.kavin.rocks",
	"https://pipedapi.leptons.xyz",
	"https://pipedapi.nosebs.ru",
	"https://pipedapi-libre.kavin.rocks",
	"https://piped-api.privacy.com.de",
	"https://pipedapi.adminforge.de",
	"https://api.piped.yt",
	"https://pipedapi.drgns.space",
}

----------------------------------------------------------------------
-- Возможности executor
----------------------------------------------------------------------
local requestFn = (type(request) == "function" and request)
	or (type(http_request) == "function" and http_request)
	or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
	or (type(http) == "table" and type(http.request) == "function" and http.request)
	or nil

local hasFS = type(writefile) == "function"
	and type(isfolder) == "function" and type(makefolder) == "function"
local hasAsset = hasFS and type(getcustomasset) == "function"
local clipFn = (type(setclipboard) == "function" and setclipboard)
	or (type(toclipboard) == "function" and toclipboard)
	or (type(set_clipboard) == "function" and set_clipboard) or nil

----------------------------------------------------------------------
-- HTTP + Piped
----------------------------------------------------------------------
local function httpGet(url, timeout)
	if not requestFn then return nil, "у executor нет функции request" end
	local result
	task.spawn(function()
		local ok, res = pcall(requestFn, {
			Url = url, Method = "GET",
			Headers = { ["User-Agent"] = "Mozilla/5.0 (Linux; Android 13) PromptPhone" },
		})
		result = { ok = ok, res = res }
	end)
	local t0 = os.clock()
	while not result and os.clock() - t0 < timeout do task.wait(0.1) end
	if not result then return nil, "таймаут" end
	if not result.ok then return nil, tostring(result.res) end
	local r = result.res
	if type(r) ~= "table" then return nil, "пустой ответ" end
	local code = r.StatusCode or r.status_code
	if r.Success == false or (code and tonumber(code) ~= 200) then return nil, "HTTP " .. tostring(code) end
	if type(r.Body) ~= "string" or r.Body == "" then return nil, "пустое тело ответа" end
	return r.Body
end

local instances = {}
local instIdx = 1
for _, u in ipairs(STATIC_INSTANCES) do table.insert(instances, u) end

local function apiGet(path)
	local lastErr = "нет доступных серверов"
	local tries = math.min(4, #instances)
	for _ = 1, tries do
		local base = instances[instIdx]
		local body, err = httpGet(base .. path, CONFIG.TIMEOUT)
		if body then
			local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
			if ok and type(data) == "table" then
				if data.error then
					lastErr = tostring(data.message or data.error)
				else
					return data, base
				end
			else
				lastErr = "ответ не JSON"
			end
		else
			lastErr = err
		end
		instIdx = instIdx % #instances + 1
	end
	return nil, lastErr
end

-- дополнительный список живых серверов (в фоне, не блокирует интерфейс)
local function refreshInstancesAsync()
	task.spawn(function()
		local body = httpGet("https://piped-instances.kavin.rocks", 8)
		if not body then return end
		local ok, list = pcall(function() return HttpService:JSONDecode(body) end)
		if not ok or type(list) ~= "table" then return end
		local extra = {}
		for _, e in ipairs(list) do
			if type(e) == "table" and type(e.api_url) == "string" then
				table.insert(extra, e)
			end
		end
		table.sort(extra, function(a, b) return (tonumber(a.uptime_24h) or 0) > (tonumber(b.uptime_24h) or 0) end)
		local seen = {}
		for _, u in ipairs(instances) do seen[u] = true end
		for i = 1, math.min(#extra, 6) do
			local u = extra[i].api_url
			if not seen[u] then seen[u] = true table.insert(instances, u) end
		end
	end)
end

local function normItem(it)
	if type(it) ~= "table" or type(it.url) ~= "string" then return nil end
	local id = it.url:match("[?&]v=([%w_%-]+)")
	if not id then return nil end
	if it.type and it.type ~= "stream" then return nil end
	return {
		id = id,
		title = (type(it.title) == "string" and it.title ~= "") and it.title or "(без названия)",
		channel = type(it.uploaderName) == "string" and it.uploaderName or "",
		views = tonumber(it.views),
		dur = tonumber(it.duration),
		date = type(it.uploadedDate) == "string" and it.uploadedDate or nil,
	}
end

local function extractItems(data)
	local arr = data.items or data
	local out = {}
	if type(arr) == "table" then
		for _, it in ipairs(arr) do
			local n = normItem(it)
			if n then table.insert(out, n) end
		end
	end
	return out
end

----------------------------------------------------------------------
-- Форматирование
----------------------------------------------------------------------
local function fmtViews(n)
	if not n or n < 0 then return nil end
	if n >= 1e6 then return string.format("%.1f млн просм.", n / 1e6) end
	if n >= 1e3 then return string.format("%d тыс. просм.", math.floor(n / 1e3)) end
	return string.format("%d просм.", n)
end

local function fmtDur(s)
	if not s then return nil end
	if s < 0 then return "LIVE" end
	s = math.floor(s)
	local h, m, sec = math.floor(s / 3600), math.floor(s % 3600 / 60), s % 60
	if h > 0 then return string.format("%d:%02d:%02d", h, m, sec) end
	return string.format("%d:%02d", m, sec)
end

local function cleanHtml(s)
	s = tostring(s or "")
	s = s:gsub("<br%s*/?>", "\n"):gsub("</p>", "\n"):gsub("<[^>]+>", "")
	s = s:gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&#39;", "'")
	if #s > 1500 then s = s:sub(1, 1500) .. "…" end
	return s
end

----------------------------------------------------------------------
-- UI-помощники
----------------------------------------------------------------------
local C = {
	bg = Color3.fromRGB(15, 15, 15),
	card = Color3.fromRGB(32, 32, 32),
	red = Color3.fromRGB(230, 30, 30),
	grey = Color3.fromRGB(58, 58, 62),
	text = Color3.fromRGB(240, 240, 240),
	dim = Color3.fromRGB(160, 160, 165),
}

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function text(parent, str, size, color, pos, sz)
	return make("TextLabel", {
		Text = str, TextSize = size, TextColor3 = color or C.text, Font = Enum.Font.Gotham,
		BackgroundTransparency = 1, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, Position = pos or UDim2.new(), Size = sz or UDim2.new(1, 0, 0, 16),
	}, parent)
end

local function btn(parent, str, size, color, pos, sz)
	local b = make("TextButton", {
		Text = str, TextSize = size, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamMedium,
		BackgroundColor3 = color or C.grey, BorderSizePixel = 0, AutoButtonColor = true,
		Position = pos or UDim2.new(), Size = sz or UDim2.new(0, 60, 0, 32),
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
	return b
end

----------------------------------------------------------------------
-- Приложение
----------------------------------------------------------------------
local function mountYouTube(parent)
	local app = {}
	local destroyed = false

	local root = make("Frame", { Name = "PP_YouTube", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true }, parent)

	-- Кэш миниатюр сохраняется между открытиями YouTube.
	local function ensureCache()
		if not hasFS then return end
		pcall(function()
			if not isfolder(CONFIG.CACHE) then makefolder(CONFIG.CACHE) end
		end)
	end
	ensureCache()

	-- ===== шапка =====
	local header = make("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = C.bg, BorderSizePixel = 0 }, root)
	local logo = make("TextButton", {
		Text = "", Position = UDim2.new(0, 6, 0, 4), Size = UDim2.new(0, 92, 0, 26),
		BackgroundTransparency = 1, AutoButtonColor = false,
	}, header)
	local logoBox = make("Frame", { Size = UDim2.new(0, 30, 1, 0), BackgroundColor3 = C.red, BorderSizePixel = 0 }, logo)
	make("UICorner", { CornerRadius = UDim.new(0, 7) }, logoBox)
	make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "▶", TextColor3 = Color3.new(1, 1, 1), TextSize = 14, Font = Enum.Font.GothamBold }, logoBox)
	make("TextLabel", { Position = UDim2.new(0, 34, 0, 0), Size = UDim2.new(1, -34, 1, 0), BackgroundTransparency = 1, Text = "YouTube", TextColor3 = C.text, TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left }, logo)
	local modeLabel = text(header, "", 11, C.dim, UDim2.new(0, 102, 0, 9), UDim2.new(1, -108, 0, 16))
	modeLabel.TextXAlignment = Enum.TextXAlignment.Right
	modeLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local box = make("TextBox", {
		Position = UDim2.new(0, 6, 0, 34), Size = UDim2.new(1, -52, 0, 30),
		BackgroundColor3 = C.card, BorderSizePixel = 0, Text = "", PlaceholderText = "Поиск видео или канала",
		PlaceholderColor3 = C.dim, TextColor3 = C.text, TextSize = 14, Font = Enum.Font.Gotham,
		ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
	}, header)
	make("UICorner", { CornerRadius = UDim.new(0, 15) }, box)
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8) }, box)
	local searchBtn = btn(header, "🔍", 15, C.grey, UDim2.new(1, -42, 0, 34), UDim2.new(0, 36, 0, 30))

	-- ===== список =====
	local list = make("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 70), Size = UDim2.new(1, 0, 1, -70),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, root)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }, list)

	local moreBtn = btn(list, "Загрузить ещё", 13, C.grey, nil, UDim2.new(1, 0, 0, 34))
	moreBtn.LayoutOrder = 1000000
	moreBtn.Visible = false

	-- статус по центру
	local statusFrame = make("Frame", { Position = UDim2.new(0.1, 0, 0, 100), Size = UDim2.new(0.8, 0, 0, 90), BackgroundTransparency = 1, Visible = false }, root)
	local statusText = text(statusFrame, "", 13, C.dim, UDim2.new(), UDim2.new(1, 0, 0, 56))
	statusText.TextXAlignment = Enum.TextXAlignment.Center
	local retryBtn = btn(statusFrame, "Повторить", 13, C.red, UDim2.new(0.5, -45, 0, 58), UDim2.new(0, 90, 0, 30))
	retryBtn.Visible = false

	-- toast
	local toastL = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(0.94, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(45, 45, 48), BorderSizePixel = 0,
		TextColor3 = C.text, TextSize = 12, Font = Enum.Font.Gotham, TextWrapped = true, Visible = false, ZIndex = 30,
	}, root)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, toastL)
	make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, toastL)
	local toastTok = 0
	local function toast(msg, isErr)
		if destroyed then return end
		toastTok = toastTok + 1
		local my = toastTok
		toastL.Text = msg
		toastL.TextColor3 = isErr and Color3.fromRGB(255, 130, 130) or C.text
		toastL.Visible = true
		task.delay(isErr and 6 or 3.5, function()
			if my == toastTok and not destroyed then toastL.Visible = false end
		end)
	end

	local function setStatus(kind, msg)
		if kind == "hidden" then statusFrame.Visible = false return end
		statusFrame.Visible = true
		statusText.Text = msg or ""
		retryBtn.Visible = (kind == "error")
	end

	-- ===== миниатюры =====
	local thumbs, thumbFail, tq, tActive = {}, {}, {}, 0

	local function fetchThumb(id)
		if not hasAsset then return nil end
		local body = httpGet("https://i.ytimg.com/vi/" .. id .. "/mqdefault.jpg", 8)
		if not body or #body < 1000 or body:sub(1, 2) ~= "\255\216" then return nil end -- только настоящий JPEG
		local path = CONFIG.CACHE .. "/" .. id .. ".jpg"
		local ok = pcall(writefile, path, body)
		if not ok then return nil end
		local ok2, asset = pcall(getcustomasset, path)
		if ok2 and asset then return asset end
		return nil
	end

	local pumpThumbs
	pumpThumbs = function()
		while tActive < 3 and #tq > 0 and not destroyed do
			local job = table.remove(tq, 1)
			tActive = tActive + 1
			task.spawn(function()
				local asset = thumbs[job.id]
				if not asset and not thumbFail[job.id] then
					asset = fetchThumb(job.id)
					if asset then thumbs[job.id] = asset else thumbFail[job.id] = true end
				end
				tActive = tActive - 1
				if asset and not destroyed and job.label.Parent then
					job.label.Image = asset
					for _, ch in ipairs(job.label:GetChildren()) do
						if ch.Name == "Placeholder" then ch:Destroy() end
					end
				end
				pumpThumbs()
			end)
		end
	end

	local function thumbInto(label, id)
		make("TextLabel", { Name = "Placeholder", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "▶", TextColor3 = C.dim, TextSize = 18, Font = Enum.Font.GothamBold }, label)
		if thumbs[id] then
			label.Image = thumbs[id]
			label.Placeholder:Destroy()
		elseif not thumbFail[id] then
			table.insert(tq, { id = id, label = label })
			pumpThumbs()
		end
	end

	-- ===== состояние =====
	local mode, query = "trending", ""
	local reqToken, moreBusy, nextToken = 0, false, nil
	local cardCount = 0
	local openWatch

	local function clearCards()
		for _, ch in ipairs(list:GetChildren()) do
			if ch.Name == "Card" then ch:Destroy() end
		end
		tq = {}
		cardCount = 0
		moreBtn.Visible = false
		list.CanvasPosition = Vector2.new(0, 0)
	end

	local function addCards(items)
		for _, it in ipairs(items) do
			if cardCount >= CONFIG.MAX_CARDS then break end
			cardCount = cardCount + 1
			local card = make("TextButton", {
				Name = "Card", Text = "", Size = UDim2.new(1, 0, 0, 72), BackgroundColor3 = C.card,
				BorderSizePixel = 0, AutoButtonColor = true, LayoutOrder = cardCount,
			}, list)
			make("UICorner", { CornerRadius = UDim.new(0, 8) }, card)
			local th = make("ImageLabel", {
				Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(0, 112, 0, 64), BackgroundColor3 = Color3.fromRGB(10, 10, 10),
				BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop, Image = "",
			}, card)
			make("UICorner", { CornerRadius = UDim.new(0, 6) }, th)
			local d = fmtDur(it.dur)
			if d then
				local badge = make("TextLabel", {
					AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -3), Size = UDim2.new(0, 0, 0, 14),
					AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25,
					Text = d, TextColor3 = Color3.new(1, 1, 1), TextSize = 10, Font = Enum.Font.GothamMedium, ZIndex = 3,
				}, th)
				make("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }, badge)
			end
			thumbInto(th, it.id)

			local t = text(card, it.title, 12, C.text, UDim2.new(0, 122, 0, 5), UDim2.new(1, -128, 0, 32))
			t.Font = Enum.Font.GothamMedium
			t.TextTruncate = Enum.TextTruncate.AtEnd
			local parts = {}
			if it.channel ~= "" then table.insert(parts, it.channel) end
			local v = fmtViews(it.views)
			if v then table.insert(parts, v) end
			if it.date then table.insert(parts, it.date) end
			local m = text(card, table.concat(parts, " · "), 10, C.dim, UDim2.new(0, 122, 0, 40), UDim2.new(1, -128, 0, 28))
			m.TextTruncate = Enum.TextTruncate.AtEnd

			card.Activated:Connect(function() openWatch(it) end)
		end
	end

	local function updateMore()
		moreBtn.Visible = (nextToken ~= nil) and cardCount < CONFIG.MAX_CARDS
		moreBtn.Text = "Загрузить ещё"
	end

	local function startLoad()
		reqToken = reqToken + 1
		local my = reqToken
		moreBusy = false
		nextToken = nil
		clearCards()
		setStatus("loading", "Загрузка…")
		modeLabel.Text = (mode == "search") and ("🔍 " .. query) or "🔥 В тренде"

		task.spawn(function()
			local path
			if mode == "search" then
				path = "/search?q=" .. HttpService:UrlEncode(query) .. "&filter=videos"
			else
				path = "/trending?region=" .. CONFIG.REGION
			end
			local data, err = apiGet(path)
			if destroyed or my ~= reqToken then return end
			if not data then
				setStatus("error", "Не удалось загрузить:\n" .. tostring(err))
				return
			end
			local items = extractItems(data)
			if #items == 0 then
				setStatus("empty", mode == "search" and "Ничего не найдено" or "Лента пуста")
				return
			end
			setStatus("hidden")
			addCards(items)
			if mode == "search" and type(data.nextpage) == "string" and data.nextpage ~= "" then
				nextToken = data.nextpage
			end
			updateMore()
		end)
	end

	local function doSearch()
		local q = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if q == "" then toast("Введите поисковый запрос", true) return end
		if mode == "search" and q == query and statusFrame.Visible and not retryBtn.Visible then return end -- уже грузится
		mode, query = "search", q
		box:ReleaseFocus()
		startLoad()
	end

	local function goHome()
		mode, query = "trending", ""
		box.Text = ""
		startLoad()
	end

	moreBtn.Activated:Connect(function()
		if moreBusy or not nextToken then return end
		moreBusy = true
		moreBtn.Text = "Загрузка…"
		local my = reqToken
		task.spawn(function()
			local path = "/nextpage/search?nextpage=" .. HttpService:UrlEncode(nextToken)
				.. "&q=" .. HttpService:UrlEncode(query) .. "&filter=videos"
			local data, err = apiGet(path)
			if destroyed or my ~= reqToken then return end
			moreBusy = false
			if not data then
				toast("Не удалось загрузить ещё: " .. tostring(err), true)
				updateMore()
				return
			end
			addCards(extractItems(data))
			nextToken = (type(data.nextpage) == "string" and data.nextpage ~= "") and data.nextpage or nil
			updateMore()
		end)
	end)

	box.FocusLost:Connect(function(enter) if enter then doSearch() end end)
	searchBtn.Activated:Connect(doSearch)
	logo.Activated:Connect(function() if mode ~= "trending" then goHome() end end)
	retryBtn.Activated:Connect(startLoad)

	-- ===== страница видео =====
	local watch, watchTok = nil, 0

	local function closeWatch()
		watchTok = watchTok + 1
		if watch then watch:Destroy() watch = nil end
	end

	local function openExternal(id)
		local url = "https://www.youtube.com/watch?v=" .. id
		if clipFn then pcall(clipFn, url) end
		local okOpen = pcall(function() GuiService:OpenBrowserWindow(url) end)
		if okOpen then
			toast("Запрос на открытие отправлен. Если браузер не открылся - ссылка скопирована, вставьте её в браузер.")
		elseif clipFn then
			toast("Roblox не разрешил открыть браузер. Ссылка скопирована - вставьте её в браузер или приложение YouTube.", true)
		else
			toast("Открыть браузер и скопировать нельзя. Ссылку можно выделить в поле на странице.", true)
		end
	end

	openWatch = function(it)
		closeWatch()
		local my = watchTok
		local url = "https://www.youtube.com/watch?v=" .. it.id

		watch = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 5 }, root)
		local back = btn(watch, "◀", 14, C.grey, UDim2.new(0, 6, 0, 6), UDim2.new(0, 40, 0, 30))
		text(watch, "Видео", 14, C.text, UDim2.new(0, 54, 0, 12), UDim2.new(1, -60, 0, 18)).Font = Enum.Font.GothamBold
		back.Activated:Connect(closeWatch)

		local sc = make("ScrollingFrame", {
			Position = UDim2.new(0, 0, 0, 42), Size = UDim2.new(1, 0, 1, -42), BackgroundTransparency = 1,
			BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, watch)
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, sc)
		make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10) }, sc)

		local order = 0
		local function nextOrder() order = order + 1 return order end

		-- область "плеера": реальная миниатюра + кнопка открытия (воспроизведения внутри Roblox нет)
		local player = make("ImageLabel", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 110), BackgroundColor3 = Color3.fromRGB(10, 10, 10), BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop, Image = "" }, sc)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, player)
		local function fitPlayer() player.Size = UDim2.new(1, 0, 0, math.max(80, math.floor(sc.AbsoluteSize.X * 9 / 16))) end
		sc:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPlayer)
		fitPlayer()
		thumbInto(player, it.id)
		local play = btn(player, "▶ Открыть", 14, C.red, UDim2.new(0.5, -50, 0.5, -17), UDim2.new(0, 100, 0, 34))
		play.ZIndex = 4
		play.Activated:Connect(function() openExternal(it.id) end)

		local cap = text(sc, "Плеер YouTube нельзя встроить в Roblox: видео откроется во внешнем браузере или приложении.", 10, C.dim)
		cap.LayoutOrder = nextOrder() cap.AutomaticSize = Enum.AutomaticSize.Y cap.Size = UDim2.new(1, 0, 0, 0)

		local ttl = text(sc, it.title, 14, C.text)
		ttl.LayoutOrder = nextOrder() ttl.Font = Enum.Font.GothamBold ttl.AutomaticSize = Enum.AutomaticSize.Y ttl.Size = UDim2.new(1, 0, 0, 0)

		local meta = text(sc, "", 11, C.dim)
		meta.LayoutOrder = nextOrder() meta.AutomaticSize = Enum.AutomaticSize.Y meta.Size = UDim2.new(1, 0, 0, 0)
		local function setMeta(extra)
			local parts = {}
			if it.channel ~= "" then table.insert(parts, it.channel) end
			local v = fmtViews(it.views)
			if v then table.insert(parts, v) end
			if it.date then table.insert(parts, it.date) end
			if extra then table.insert(parts, extra) end
			meta.Text = table.concat(parts, " · ")
		end
		setMeta()

		local row = make("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1 }, sc)
		local b1 = btn(row, "▶ Смотреть", 12, C.red, UDim2.new(0, 0, 0, 0), UDim2.new(0.5, -3, 1, 0))
		local b2 = btn(row, "📋 Ссылка", 12, C.grey, UDim2.new(0.5, 3, 0, 0), UDim2.new(0.5, -3, 1, 0))
		b1.Activated:Connect(function() openExternal(it.id) end)
		b2.Activated:Connect(function()
			if clipFn and pcall(clipFn, url) then toast("Ссылка скопирована")
			else toast("У executor нет буфера обмена. Выделите ссылку в поле ниже.", true) end
		end)

		local linkBox = make("TextBox", {
			LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = C.card, BorderSizePixel = 0,
			Text = url, TextEditable = false, ClearTextOnFocus = false, TextColor3 = C.dim, TextSize = 11,
			Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
		}, sc)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, linkBox)
		make("UIPadding", { PaddingLeft = UDim.new(0, 6) }, linkBox)

		local desc = text(sc, "Загрузка описания…", 11, C.text)
		desc.LayoutOrder = nextOrder() desc.AutomaticSize = Enum.AutomaticSize.Y desc.Size = UDim2.new(1, 0, 0, 0)

		task.spawn(function()
			local data, err = apiGet("/streams/" .. it.id)
			if destroyed or my ~= watchTok or not watch then return end
			if not data then
				desc.Text = "Описание недоступно: " .. tostring(err)
				return
			end
			if tonumber(data.views) and not it.views then it.views = tonumber(data.views) end
			local extra = tonumber(data.likes) and tonumber(data.likes) >= 0 and ("👍 " .. data.likes) or nil
			if type(data.uploadDate) == "string" and not it.date then it.date = data.uploadDate end
			setMeta(extra)
			local d = cleanHtml(data.description)
			desc.Text = (d ~= "") and d or "Описание отсутствует"
		end)
	end

	-- ===== публичный API приложения =====
	function app:Back()
		if watch then closeWatch() return true end
		if mode == "search" then goHome() return true end
		return false
	end
	function app:Home() closeWatch() if mode ~= "trending" then goHome() end end
	function app:Destroy()
		if destroyed then return end
		destroyed = true
		tq = {}
		closeWatch()
		root:Destroy()
	end

	if not requestFn then
		setStatus("error", "У executor нет HTTP-функции request - YouTube работать не сможет.")
		retryBtn.Visible = false
	else
		refreshInstancesAsync()
		startLoad()
	end
	return app
end

		local activeYouTube = nil
		Phone.RegisterApp({
			Id = "youtube",
			Name = "YouTube",
			Icon = "▶",
			IconColor = Color3.fromRGB(235, 45, 45),
			WindowSize = Vector2.new(350, 520),
			Singleton = true,
			OnOpen = function(ctx)
				activeYouTube = mountYouTube(ctx.Content)
				ctx.OnBack = function()
					return activeYouTube and activeYouTube:Back() or false
				end
			end,
			OnClose = function(ctx)
				if activeYouTube then
					activeYouTube:Destroy()
					activeYouTube = nil
				end
				ctx.OnBack = nil
			end,
		})
	else
		warn("[YouTube] PromptPhone API не найден.")
	end
end

------------------------------------------------------------------
-- 7. APP: REALITY MODIFIER
-- Добавлено поверх ядра Prompt Phone. Работает через библиотеку
-- проверенных локальных функций, а не исполняет текст пользователя как Lua.
------------------------------------------------------------------
do
    local Phone = ENV and ENV.PromptPhone
    if type(Phone) ~= "table" then
        warn("[Reality Modifier] PromptPhone API не найден. Сначала запусти ядро.")
        return
    end

    -- При повторном запуске заменяем только это приложение.
    pcall(function()
        if Phone.Apps and Phone.Apps:Get("reality_modifier") then
            Phone.Apps:Unregister("reality_modifier")
        end
    end)

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    local LocalPlayer = Players.LocalPlayer

    local Theme = Phone.Theme
    local New = Phone.Utils.New
    local Maid = Phone.Utils.Maid
    local SAVE_PATH = "PromptPhone/RealityModifier_Saved.json"

    local function make(class, props, children)
        props = props or {}
        props.Parent = props.Parent
        return New(class, props, children)
    end

    local function round(parent, radius)
        return New("UICorner", {
            CornerRadius = UDim.new(0, radius or 10),
            Parent = parent
        })
    end

    local function label(parent, text, size, color, bold)
        return New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, size or 22),
            Text = text,
            TextColor3 = color or Theme.Text,
            Font = bold and Theme.FontBold or Theme.Font,
            TextSize = size or 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            Parent = parent
        })
    end

    local function button(parent, text, width, callback, color)
        local b = New("TextButton", {
            Size = UDim2.new(0, width, 0, 34),
            BackgroundColor3 = color or Theme.Bar,
            BorderSizePixel = 0,
            AutoButtonColor = true,
            Text = text,
            TextColor3 = Theme.Text,
            Font = Theme.FontBold,
            TextSize = 13,
            Parent = parent
        })
        round(b, 9)
        b.Activated:Connect(callback)
        return b
    end

    ------------------------------------------------------------------
    -- БИБЛИОТЕКА ФУНКЦИЙ
    ------------------------------------------------------------------
    local FeatureEngine = {}
    FeatureEngine.__index = FeatureEngine

    function FeatureEngine.new()
        return setmetatable({
            Active = {},
            Connections = {},
            CharacterMaid = Maid.new(),
            Fly = false,
            Noclip = false,
            AscendUntil = 0,
            LastCharacter = nil,
            SavedCharacterValues = {},
            SavedLighting = nil,
            SavedGravity = nil,
            SavedFov = nil,
        }, FeatureEngine)
    end

    function FeatureEngine:GetCharacter()
        local char = LocalPlayer.Character
        if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not hum or not root or hum.Health <= 0 then return nil end
        return char, hum, root
    end

    function FeatureEngine:StopFly()
        self.Fly = false
        local _, hum, root = self:GetCharacter()
        if root then
            local bv = root:FindFirstChild("PP_RealityFlyVelocity")
            local bg = root:FindFirstChild("PP_RealityFlyGyro")
            if bv then bv:Destroy() end
            if bg then bg:Destroy() end
        end
        if hum then
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end

    function FeatureEngine:StartFly()
        local char, hum, root = self:GetCharacter()
        if not char then return false, "Персонаж ещё не загружен." end

        self:StopFly()
        self.Fly = true

        local velocity = Instance.new("BodyVelocity")
        velocity.Name = "PP_RealityFlyVelocity"
        velocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        velocity.P = 18000
        velocity.Velocity = Vector3.zero
        velocity.Parent = root

        local gyro = Instance.new("BodyGyro")
        gyro.Name = "PP_RealityFlyGyro"
        gyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        gyro.P = 12000
        gyro.D = 500
        gyro.CFrame = workspace.CurrentCamera.CFrame
        gyro.Parent = root

        hum.PlatformStand = true
        hum:ChangeState(Enum.HumanoidStateType.Physics)
        return true
    end

    function FeatureEngine:StopNoclip()
        self.Noclip = false
        local char = LocalPlayer.Character
        if not char then return end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") then
                local old = obj:GetAttribute("PP_RealityOldCollision")
                if old ~= nil then
                    obj.CanCollide = old
                    obj:SetAttribute("PP_RealityOldCollision", nil)
                end
            end
        end
    end

    function FeatureEngine:StartNoclip()
        if not LocalPlayer.Character then
            return false, "Персонаж ещё не загружен."
        end
        self.Noclip = true
        return true
    end

    local EXTRA_FEATURE_CONFIG = {
        walk_speed_20 = {Kind="walk", Value=20},
        walk_speed_24 = {Kind="walk", Value=24},
        walk_speed_40 = {Kind="walk", Value=40},
        walk_speed_50 = {Kind="walk", Value=50},
        walk_speed_80 = {Kind="walk", Value=80},
        walk_speed_100 = {Kind="walk", Value=100},
        walk_speed_120 = {Kind="walk", Value=120},
        walk_speed_150 = {Kind="walk", Value=150},
        walk_speed_200 = {Kind="walk", Value=200},
        jump_power_60 = {Kind="jump", Value=60},
        jump_power_70 = {Kind="jump", Value=70},
        jump_power_100 = {Kind="jump", Value=100},
        jump_power_120 = {Kind="jump", Value=120},
        jump_power_160 = {Kind="jump", Value=160},
        jump_power_200 = {Kind="jump", Value=200},
        jump_power_250 = {Kind="jump", Value=250},
        jump_power_300 = {Kind="jump", Value=300},
        jump_power_400 = {Kind="jump", Value=400},
        gravity_0 = {Kind="gravity", Value=0},
        gravity_20 = {Kind="gravity", Value=20},
        gravity_50 = {Kind="gravity", Value=50},
        gravity_70 = {Kind="gravity", Value=70},
        gravity_120 = {Kind="gravity", Value=120},
        gravity_150 = {Kind="gravity", Value=150},
        gravity_250 = {Kind="gravity", Value=250},
        gravity_300 = {Kind="gravity", Value=300},
        gravity_400 = {Kind="gravity", Value=400},
        gravity_600 = {Kind="gravity", Value=600},
        fov_80 = {Kind="fov", Value=80},
        fov_100 = {Kind="fov", Value=100},
        fov_110 = {Kind="fov", Value=110},
        fov_120 = {Kind="fov", Value=120},
        fov_130 = {Kind="fov", Value=130},
        fov_140 = {Kind="fov", Value=140},
        fov_150 = {Kind="fov", Value=150},
        camera_zoom_10 = {Kind="zoom", Value=10},
        camera_zoom_20 = {Kind="zoom", Value=20},
        camera_zoom_30 = {Kind="zoom", Value=30},
        camera_zoom_50 = {Kind="zoom", Value=50},
        camera_zoom_80 = {Kind="zoom", Value=80},
        camera_zoom_100 = {Kind="zoom", Value=100},
        hip_height_low = {Kind="hip", Value=0.5},
        hip_height_normal = {Kind="hip", Value=2},
        hip_height_high = {Kind="hip", Value=4},
        hip_height_very_high = {Kind="hip", Value=8},
        body_translucent = {Kind="transparency", Value=0.45},
        ghost_body = {Kind="transparency", Value=0.8},
        metal_body = {Kind="material", Value="Metal"},
        neon_body = {Kind="material", Value="Neon"},
        plastic_body = {Kind="material", Value="Plastic"},
        ice_body = {Kind="material", Value="Ice"},
        body_color_red = {Kind="color", Value={255,70,70}},
        body_color_blue = {Kind="color", Value={70,130,255}},
        body_color_green = {Kind="color", Value={70,220,110}},
        body_color_gold = {Kind="color", Value={255,190,40}},
        body_color_purple = {Kind="color", Value={170,90,255}},
        body_color_black = {Kind="color", Value={25,25,30}},
        body_color_white = {Kind="color", Value={245,245,245}},
        lighting_day = {Kind="lighting", Value={2,14, Color3.fromRGB(200,200,200)}},
        lighting_sunset = {Kind="lighting", Value={2,18, Color3.fromRGB(255,150,100)}},
        lighting_midnight = {Kind="lighting", Value={0.7,0, Color3.fromRGB(80,90,140)}},
        lighting_soft = {Kind="lighting", Value={1.4,12, Color3.fromRGB(180,190,210)}},
        lighting_contrast = {Kind="lighting", Value={3,13, Color3.fromRGB(255,255,255)}},
        outline_blue = {Kind="outline", Value=Color3.fromRGB(60,150,255)},
        outline_red = {Kind="outline", Value=Color3.fromRGB(255,70,70)},
        outline_green = {Kind="outline", Value=Color3.fromRGB(70,255,120)},
        outline_gold = {Kind="outline", Value=Color3.fromRGB(255,190,40)},
        aura_blue = {Kind="aura", Value=Color3.fromRGB(60,150,255)},
        aura_green = {Kind="aura", Value=Color3.fromRGB(70,255,120)},
        aura_purple = {Kind="aura", Value=Color3.fromRGB(180,80,255)},
        aura_gold = {Kind="aura", Value=Color3.fromRGB(255,190,40)},
    }

    local function getFeatureConflictGroup(id)
        if id == "speed" or id == "slow" or id == "super_speed" or id:match("^walk_speed_") then return "movement_speed" end
        if id == "jump" or id == "mega_jump" or id:match("^jump_power_") then return "jump_power" end
        if id == "low_gravity" or id == "high_gravity" or id == "slow_fall" or id:match("^gravity_") then return "gravity" end
        if id == "fov" or id == "narrow_fov" or id:match("^fov_") then return "camera_fov" end
        if id == "zoom_in" or id == "zoom_out" or id:match("^camera_zoom_") then return "camera_zoom" end
        if id == "first_person" or id == "third_person" then return "camera_mode" end
        if id == "bright" or id == "night_vision" or id:match("^lighting_") then return "lighting_preset" end
        return nil
    end

    function FeatureEngine:Set(id, enabled)
        enabled = enabled == true
        -- Повторное нажатие с тем же состоянием не перезаписывает сохранённые исходные значения.
        if self.Active[id] == enabled then return true end
        local char, hum, root = self:GetCharacter()
        if enabled and not char then return false, "Персонаж ещё не загружен." end

        -- Взаимоисключающие параметры одной категории не конфликтуют и не восстанавливают
        -- друг другу неправильные исходные значения (например, Speed 40 и Speed 200).
        if enabled then
            local group = getFeatureConflictGroup(id)
            if group then
                local activeIds = {}
                for activeId, isActive in pairs(self.Active) do
                    if isActive and activeId ~= id and getFeatureConflictGroup(activeId) == group then
                        table.insert(activeIds, activeId)
                    end
                end
                for _, activeId in ipairs(activeIds) do
                    self:Set(activeId, false)
                end
            end
        end

        if id == "fly" then
            if enabled then local ok, err = self:StartFly(); if not ok then return false, err end
            else self:StopFly() end
        elseif id == "noclip" then
            if enabled then local ok, err = self:StartNoclip(); if not ok then return false, err end
            else self:StopNoclip() end
        elseif id == "speed" then
            if enabled then self.SavedCharacterValues.WalkSpeed = hum.WalkSpeed; hum.WalkSpeed = 32
            elseif hum then hum.WalkSpeed = self.SavedCharacterValues.WalkSpeed or 16; self.SavedCharacterValues.WalkSpeed = nil end
        elseif id == "jump" then
            if enabled then
                self.SavedCharacterValues.JumpPower = hum.JumpPower
                self.SavedCharacterValues.JumpHeight = hum.JumpHeight
                self.SavedCharacterValues.UseJumpPower = hum.UseJumpPower
                hum.UseJumpPower = true; hum.JumpPower = 90
            elseif hum then
                hum.UseJumpPower = self.SavedCharacterValues.UseJumpPower ~= false
                hum.JumpPower = self.SavedCharacterValues.JumpPower or 50
                if self.SavedCharacterValues.JumpHeight then hum.JumpHeight = self.SavedCharacterValues.JumpHeight end
                self.SavedCharacterValues.JumpPower = nil; self.SavedCharacterValues.JumpHeight = nil; self.SavedCharacterValues.UseJumpPower = nil
            end
        elseif id == "infinite_jump" then
            self.InfiniteJump = enabled
        elseif id == "low_gravity" then
            if enabled then self.SavedGravity = workspace.Gravity; workspace.Gravity = 90
            else workspace.Gravity = self.SavedGravity or 196.2; self.SavedGravity = nil end
        elseif id == "fov" then
            local cam = workspace.CurrentCamera
            if enabled and cam then self.SavedFov = cam.FieldOfView; cam.FieldOfView = 90
            elseif cam then cam.FieldOfView = self.SavedFov or 70; self.SavedFov = nil end
        elseif id == "spin" then
            if enabled then
                local spin = Instance.new("BodyAngularVelocity")
                spin.Name = "PP_RealitySpin"; spin.AngularVelocity = Vector3.new(0, 12, 0)
                spin.MaxTorque = Vector3.new(0, 1e6, 0); spin.P = 5000; spin.Parent = root
            else
                local spin = root and root:FindFirstChild("PP_RealitySpin")
                if spin then spin:Destroy() end
            end
        elseif id == "freeze" then
            if enabled then self.SavedCharacterValues.Anchored = root.Anchored; root.Anchored = true
            elseif root then root.Anchored = self.SavedCharacterValues.Anchored == true; self.SavedCharacterValues.Anchored = nil end
        elseif id == "invisible" then
            if enabled then
                self.SavedTransparency = {}
                for _, obj in ipairs(char:GetDescendants()) do
                    if obj:IsA("BasePart") then self.SavedTransparency[obj] = { "part", obj.LocalTransparencyModifier }; obj.LocalTransparencyModifier = 1
                    elseif obj:IsA("Decal") then self.SavedTransparency[obj] = { "decal", obj.Transparency }; obj.Transparency = 1 end
                end
            else
                for obj, saved in pairs(self.SavedTransparency or {}) do
                    if obj and obj.Parent then pcall(function()
                        if saved[1] == "part" then obj.LocalTransparencyModifier = saved[2] else obj.Transparency = saved[2] end
                    end) end
                end
                self.SavedTransparency = nil
            end
        elseif id == "bright" then
            local lighting = game:GetService("Lighting")
            if enabled then
                self.SavedLighting = { lighting.Brightness, lighting.ClockTime, lighting.Ambient, lighting.OutdoorAmbient }
                lighting.Brightness = 3; lighting.ClockTime = 14
                lighting.Ambient = Color3.new(1,1,1); lighting.OutdoorAmbient = Color3.new(1,1,1)
            else
                local old = self.SavedLighting
                if old then lighting.Brightness = old[1]; lighting.ClockTime = old[2]; lighting.Ambient = old[3]; lighting.OutdoorAmbient = old[4] end
                self.SavedLighting = nil
            end
        elseif id == "slow" or id == "super_speed" then
            if enabled then
                self.SavedCharacterValues[id] = hum.WalkSpeed
                hum.WalkSpeed = id == "slow" and 8 or 65
            elseif hum then
                hum.WalkSpeed = self.SavedCharacterValues[id] or 16
                self.SavedCharacterValues[id] = nil
            end
        elseif id == "mega_jump" then
            if enabled then
                self.SavedCharacterValues.MegaJumpPower = hum.JumpPower
                self.SavedCharacterValues.MegaUseJumpPower = hum.UseJumpPower
                hum.UseJumpPower = true; hum.JumpPower = 140
            elseif hum then
                hum.UseJumpPower = self.SavedCharacterValues.MegaUseJumpPower ~= false
                hum.JumpPower = self.SavedCharacterValues.MegaJumpPower or 50
                self.SavedCharacterValues.MegaJumpPower = nil; self.SavedCharacterValues.MegaUseJumpPower = nil
            end
        elseif id == "high_gravity" then
            if enabled then self.SavedHighGravity = workspace.Gravity; workspace.Gravity = 320
            else workspace.Gravity = self.SavedHighGravity or 196.2; self.SavedHighGravity = nil end
        elseif id == "no_fog" then
            local lighting = game:GetService("Lighting")
            if enabled then
                self.SavedFog = {lighting.FogStart, lighting.FogEnd}
                lighting.FogStart = 0; lighting.FogEnd = 1000000
            else
                if self.SavedFog then lighting.FogStart = self.SavedFog[1]; lighting.FogEnd = self.SavedFog[2] end
                self.SavedFog = nil
            end
        elseif id == "first_person" then
            if enabled then self.SavedCameraMode = LocalPlayer.CameraMode; LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
            else LocalPlayer.CameraMode = self.SavedCameraMode or Enum.CameraMode.Classic; self.SavedCameraMode = nil end
        elseif id == "third_person" then
            if enabled then self.SavedCameraMode = LocalPlayer.CameraMode; LocalPlayer.CameraMode = Enum.CameraMode.Classic
            else LocalPlayer.CameraMode = self.SavedCameraMode or Enum.CameraMode.Classic; self.SavedCameraMode = nil end
        elseif id == "auto_rotate_off" then
            if enabled then self.SavedAutoRotate = hum.AutoRotate; hum.AutoRotate = false
            elseif hum then hum.AutoRotate = self.SavedAutoRotate ~= false; self.SavedAutoRotate = nil end
        elseif id == "sit" then
            if enabled then hum.Sit = true else hum.Sit = false end
        elseif id == "platform" then
            if enabled then
                local part = Instance.new("Part")
                part.Name = "PP_RealityPlatform"; part.Size = Vector3.new(8, 1, 8)
                part.Anchored = true; part.CanCollide = true; part.Transparency = 0.35
                part.Parent = workspace; self.Platform = part
            else
                if self.Platform then self.Platform:Destroy(); self.Platform = nil end
            end
        elseif id == "anti_afk" then
            if enabled then
                local ok, signal = pcall(function() return LocalPlayer.Idled end)
                if ok and signal then
                    self.AntiAfkConnection = signal:Connect(function()
                        pcall(function()
                            local vu = game:GetService("VirtualUser")
                            vu:CaptureController(); vu:ClickButton2(Vector2.new(0,0))
                        end)
                    end)
                end
            else
                if self.AntiAfkConnection then self.AntiAfkConnection:Disconnect(); self.AntiAfkConnection = nil end
            end
        elseif id == "highlight_players" then
            if enabled then
                self.PlayerHighlights = {}
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr.Character then
                        local h = Instance.new("Highlight")
                        h.Name = "PP_RealityPlayerHighlight"; h.Adornee = plr.Character
                        h.FillTransparency = 0.65; h.OutlineTransparency = 0.05; h.Parent = plr.Character
                        self.PlayerHighlights[plr] = h
                    end
                end
                self.HighlightAdded = Players.PlayerAdded:Connect(function(plr)
                    if plr == LocalPlayer then return end
                    local c = plr.Character or plr.CharacterAdded:Wait()
                    if self.Active.highlight_players and c then
                        local h = Instance.new("Highlight"); h.Name = "PP_RealityPlayerHighlight"
                        h.Adornee = c; h.FillTransparency = 0.65; h.Parent = c
                        self.PlayerHighlights[plr] = h
                    end
                end)
            else
                if self.HighlightAdded then self.HighlightAdded:Disconnect(); self.HighlightAdded = nil end
                for _, h in pairs(self.PlayerHighlights or {}) do pcall(function() h:Destroy() end) end
                self.PlayerHighlights = nil
            end
        elseif id == "hide_others" then
            if enabled then
                self.HiddenOthers = {}
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr.Character then
                        for _, obj in ipairs(plr.Character:GetDescendants()) do
                            if obj:IsA("BasePart") or obj:IsA("Decal") then
                                self.HiddenOthers[obj] = obj:IsA("BasePart") and obj.LocalTransparencyModifier or obj.Transparency
                                if obj:IsA("BasePart") then obj.LocalTransparencyModifier = 1 else obj.Transparency = 1 end
                            end
                        end
                    end
                end
            else
                for obj, old in pairs(self.HiddenOthers or {}) do if obj and obj.Parent then pcall(function() if obj:IsA("BasePart") then obj.LocalTransparencyModifier = old else obj.Transparency = old end end) end end
                self.HiddenOthers = nil
            end
        elseif id == "highlight_npcs" then
            if enabled then
                self.NPCHighlights = {}
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(obj) then
                        local h = Instance.new("Highlight"); h.Name = "PP_RealityNPCHighlight"; h.Adornee = obj; h.FillTransparency = 0.72; h.Parent = obj
                        table.insert(self.NPCHighlights, h)
                    end
                end
            else
                for _, h in ipairs(self.NPCHighlights or {}) do pcall(function() h:Destroy() end) end
                self.NPCHighlights = nil
            end
        elseif id == "remove_particles" or id == "remove_decals" or id == "remove_postfx" then
            if enabled then
                self.HiddenVisuals = self.HiddenVisuals or {}
                local targets = {}
                if id == "remove_postfx" then
                    for _, obj in ipairs(game:GetService("Lighting"):GetChildren()) do if obj:IsA("PostEffect") then table.insert(targets, obj) end end
                else
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if id == "remove_particles" and (obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles")) then table.insert(targets, obj)
                        elseif id == "remove_decals" and (obj:IsA("Decal") or obj:IsA("Texture")) then table.insert(targets, obj) end
                    end
                end
                self.HiddenVisuals[id] = {}
                for _, obj in ipairs(targets) do
                    if obj:IsA("Decal") or obj:IsA("Texture") then self.HiddenVisuals[id][obj] = obj.Transparency; obj.Transparency = 1
                    elseif obj:IsA("PostEffect") or obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then self.HiddenVisuals[id][obj] = obj.Enabled; obj.Enabled = false end
                end
            else
                for obj, old in pairs((self.HiddenVisuals or {})[id] or {}) do if obj and obj.Parent then pcall(function() if obj:IsA("Decal") or obj:IsA("Texture") then obj.Transparency = old else obj.Enabled = old end end) end end
                if self.HiddenVisuals then self.HiddenVisuals[id] = nil end
            end
        elseif id == "no_shadows" then
            local lighting = game:GetService("Lighting")
            if enabled then self.SavedGlobalShadows = lighting.GlobalShadows; lighting.GlobalShadows = false
            else lighting.GlobalShadows = self.SavedGlobalShadows ~= false; self.SavedGlobalShadows = nil end
        elseif id == "night_vision" then
            local lighting = game:GetService("Lighting")
            if enabled then
                self.SavedNightVision = {lighting.Brightness, lighting.Ambient, lighting.OutdoorAmbient, lighting.ClockTime}
                lighting.Brightness = 4; lighting.Ambient = Color3.fromRGB(180, 220, 180); lighting.OutdoorAmbient = Color3.fromRGB(180, 220, 180)
            else
                local v = self.SavedNightVision; if v then lighting.Brightness=v[1]; lighting.Ambient=v[2]; lighting.OutdoorAmbient=v[3]; lighting.ClockTime=v[4] end; self.SavedNightVision=nil
            end
        elseif id == "zoom_out" or id == "zoom_in" then
            if enabled then
                self.SavedZoom = {LocalPlayer.CameraMinZoomDistance, LocalPlayer.CameraMaxZoomDistance}
                if id == "zoom_out" then LocalPlayer.CameraMinZoomDistance = 12; LocalPlayer.CameraMaxZoomDistance = 40
                else LocalPlayer.CameraMinZoomDistance = 1; LocalPlayer.CameraMaxZoomDistance = 8 end
            else
                local z = self.SavedZoom; if z then LocalPlayer.CameraMinZoomDistance=z[1]; LocalPlayer.CameraMaxZoomDistance=z[2] end; self.SavedZoom=nil
            end
        elseif id == "narrow_fov" then
            local cam = workspace.CurrentCamera
            if enabled and cam then self.SavedNarrowFov = cam.FieldOfView; cam.FieldOfView = 45
            elseif cam then cam.FieldOfView = self.SavedNarrowFov or 70; self.SavedNarrowFov=nil end
        elseif id == "hide_names" then
            if enabled then self.SavedNameDisplay = hum.DisplayDistanceType; hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            elseif hum then hum.DisplayDistanceType = self.SavedNameDisplay or Enum.HumanoidDisplayDistanceType.Viewer; self.SavedNameDisplay=nil end
        elseif id == "forcefield_visual" then
            if enabled then local ff = Instance.new("ForceField"); ff.Name = "PP_RealityForceField"; ff.Visible = true; ff.Parent = char; self.ForceField = ff
            elseif self.ForceField then self.ForceField:Destroy(); self.ForceField=nil end
        elseif id == "sparkles" or id == "fire_aura" or id == "smoke_aura" then
            if enabled then
                local effect = Instance.new(id == "sparkles" and "Sparkles" or (id == "fire_aura" and "Fire" or "Smoke"))
                effect.Name = "PP_RealityAura"; effect.Parent = root; self.AuraEffect = effect
            elseif self.AuraEffect then self.AuraEffect:Destroy(); self.AuraEffect=nil end
        elseif id == "trail" then
            if enabled then
                local a0 = Instance.new("Attachment"); a0.Name="PP_TrailA0"; a0.Position=Vector3.new(0,1,0); a0.Parent=root
                local a1 = Instance.new("Attachment"); a1.Name="PP_TrailA1"; a1.Position=Vector3.new(0,-1,0); a1.Parent=root
                local tr = Instance.new("Trail"); tr.Name="PP_RealityTrail"; tr.Attachment0=a0; tr.Attachment1=a1; tr.Lifetime=0.45; tr.Parent=root
                self.CharacterTrail = {tr,a0,a1}
            else
                for _, obj in ipairs(self.CharacterTrail or {}) do pcall(function() obj:Destroy() end) end; self.CharacterTrail=nil
            end
        elseif id == "remove_accessories" then
            if enabled then
                self.HiddenAccessories = {}
                for _, obj in ipairs(char:GetChildren()) do if obj:IsA("Accessory") then for _, part in ipairs(obj:GetDescendants()) do if part:IsA("BasePart") then self.HiddenAccessories[part]=part.LocalTransparencyModifier; part.LocalTransparencyModifier=1 end end end end
            else
                for obj, old in pairs(self.HiddenAccessories or {}) do if obj and obj.Parent then obj.LocalTransparencyModifier=old end end; self.HiddenAccessories=nil
            end
        elseif id == "sit_off" then
            hum.Sit = false
        elseif id == "reset_camera" then
            local cam = workspace.CurrentCamera
            if cam then cam.CameraType = Enum.CameraType.Custom; cam.CameraSubject = hum; cam.FieldOfView = 70 end
        elseif id == "reset_movement" then
            hum.WalkSpeed = 16; hum.JumpPower = 50; hum.UseJumpPower = true; hum.AutoRotate = true
        elseif id == "slow_fall" then
            if enabled then self.SavedFallGravity=workspace.Gravity; workspace.Gravity=130
            else workspace.Gravity=self.SavedFallGravity or 196.2; self.SavedFallGravity=nil end
        elseif id == "head_hide" then
            local head=char:FindFirstChild("Head")
            if head then if enabled then self.SavedHeadTransparency=head.LocalTransparencyModifier; head.LocalTransparencyModifier=1 else head.LocalTransparencyModifier=self.SavedHeadTransparency or 0; self.SavedHeadTransparency=nil end end
        elseif id == "body_highlight" then
            if enabled then local h=Instance.new("Highlight"); h.Name="PP_RealityBodyHighlight"; h.Adornee=char; h.FillTransparency=0.8; h.Parent=char; self.BodyHighlight=h
            elseif self.BodyHighlight then self.BodyHighlight:Destroy(); self.BodyHighlight=nil end
        elseif EXTRA_FEATURE_CONFIG[id] then
            local cfg = EXTRA_FEATURE_CONFIG[id]
            self.ExtraSaved = self.ExtraSaved or {}
            local saved = self.ExtraSaved[id]
            if cfg.Kind == "walk" then
                if enabled then self.ExtraSaved[id] = hum.WalkSpeed; hum.WalkSpeed = cfg.Value
                elseif hum then hum.WalkSpeed = saved or 16; self.ExtraSaved[id] = nil end
            elseif cfg.Kind == "jump" then
                if enabled then self.ExtraSaved[id] = {hum.JumpPower, hum.JumpHeight, hum.UseJumpPower}; hum.UseJumpPower = true; hum.JumpPower = cfg.Value
                elseif hum and saved then hum.JumpPower=saved[1]; hum.JumpHeight=saved[2]; hum.UseJumpPower=saved[3]; self.ExtraSaved[id]=nil end
            elseif cfg.Kind == "gravity" then
                if enabled then self.ExtraSaved[id]=workspace.Gravity; workspace.Gravity=cfg.Value
                elseif saved then workspace.Gravity=saved; self.ExtraSaved[id]=nil end
            elseif cfg.Kind == "fov" then
                local cam=workspace.CurrentCamera
                if enabled and cam then self.ExtraSaved[id]=cam.FieldOfView; cam.FieldOfView=cfg.Value
                elseif cam and saved then cam.FieldOfView=saved; self.ExtraSaved[id]=nil end
            elseif cfg.Kind == "zoom" then
                if enabled then self.ExtraSaved[id]={LocalPlayer.CameraMinZoomDistance,LocalPlayer.CameraMaxZoomDistance}; LocalPlayer.CameraMinZoomDistance=1; LocalPlayer.CameraMaxZoomDistance=cfg.Value
                elseif saved then LocalPlayer.CameraMinZoomDistance=saved[1]; LocalPlayer.CameraMaxZoomDistance=saved[2]; self.ExtraSaved[id]=nil end
            elseif cfg.Kind == "hip" then
                if enabled then self.ExtraSaved[id]=hum.HipHeight; hum.HipHeight=cfg.Value
                elseif hum and saved~=nil then hum.HipHeight=saved; self.ExtraSaved[id]=nil end
            elseif cfg.Kind == "transparency" or cfg.Kind == "material" or cfg.Kind == "color" then
                if enabled then
                    local values={}
                    for _,part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name~="HumanoidRootPart" then
                            if cfg.Kind=="transparency" then values[part]=part.LocalTransparencyModifier; part.LocalTransparencyModifier=cfg.Value
                            elseif cfg.Kind=="material" then values[part]=part.Material; part.Material=Enum.Material[cfg.Value] or Enum.Material.Plastic
                            else values[part]=part.Color; part.Color=Color3.fromRGB(cfg.Value[1],cfg.Value[2],cfg.Value[3]) end
                        end
                    end
                    self.ExtraSaved[id]=values
                else
                    for part,old in pairs(saved or {}) do if part and part.Parent then pcall(function() if cfg.Kind=="transparency" then part.LocalTransparencyModifier=old elseif cfg.Kind=="material" then part.Material=old else part.Color=old end end) end end
                    self.ExtraSaved[id]=nil
                end
            elseif cfg.Kind == "lighting" then
                local light=game:GetService("Lighting")
                if enabled then self.ExtraSaved[id]={light.Brightness,light.ClockTime,light.Ambient}; light.Brightness=cfg.Value[1]; light.ClockTime=cfg.Value[2]; light.Ambient=cfg.Value[3]
                elseif saved then light.Brightness=saved[1]; light.ClockTime=saved[2]; light.Ambient=saved[3]; self.ExtraSaved[id]=nil end
            elseif cfg.Kind == "outline" or cfg.Kind == "aura" then
                if enabled then
                    local h=Instance.new("Highlight"); h.Name="PP_Reality_"..id; h.Adornee=char; h.FillColor=cfg.Value; h.OutlineColor=cfg.Value
                    h.FillTransparency=cfg.Kind=="aura" and 0.72 or 1; h.OutlineTransparency=cfg.Kind=="aura" and 0.35 or 0
                    h.Parent=char; self.ExtraSaved[id]=h
                elseif saved then pcall(function() saved:Destroy() end); self.ExtraSaved[id]=nil end
            end
        else
            return false, "Такой функции пока нет в библиотеке."
        end
        self.Active[id] = enabled
        return true
    end

    function FeatureEngine:Repair(id, issue)
        local text = string.lower(tostring(issue or "")):gsub("ё", "е")
        if id == "fly" then
            -- Restart physics controllers; tune common complaints without replacing the module.
            self:StopFly()
            local ok, err = self:StartFly()
            if not ok then return false, err end
            if text:find("вверх", 1, true) or text:find("подним", 1, true) or text:find("высот", 1, true) then
                self.AscendUntil = os.clock() + 0.65
            end
            if text:find("медленно", 1, true) or text:find("скорост", 1, true) then
                self.FlySpeed = 70
            end
            return true
        elseif id == "speed" and (text:find("медленно", 1, true) or text:find("слаб", 1, true)) then
            local _, hum = self:GetCharacter()
            if hum then hum.WalkSpeed = 45; self.Active[id] = true; return true end
        elseif id == "jump" and (text:find("низк", 1, true) or text:find("слаб", 1, true)) then
            local _, hum = self:GetCharacter()
            if hum then hum.UseJumpPower = true; hum.JumpPower = 110; self.Active[id] = true; return true end
        end
        local offOk, offErr = self:Set(id, false)
        if not offOk then return false, offErr end
        return self:Set(id, true)
    end

    function FeatureEngine:Start()
        if self.Heartbeat then return end

        self.Heartbeat = RunService.Heartbeat:Connect(function()
            local char, hum, root = self:GetCharacter()
            if not char then return end

            if self.LastCharacter ~= char then
                self.LastCharacter = char
                if self.Fly then
                    self.Fly = false
                    self.Active.fly = false
                end
            end

            if self.Platform and self.Platform.Parent then
                self.Platform.CFrame = CFrame.new(root.Position.X, root.Position.Y - 4, root.Position.Z)
            end

            if self.Noclip then
                for _, obj in ipairs(char:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        if obj:GetAttribute("PP_RealityOldCollision") == nil then
                            obj:SetAttribute("PP_RealityOldCollision", obj.CanCollide)
                        end
                        obj.CanCollide = false
                    end
                end
            end

            if self.Fly then
                local bv = root:FindFirstChild("PP_RealityFlyVelocity")
                local bg = root:FindFirstChild("PP_RealityFlyGyro")
                if not bv or not bg then
                    self.Fly = false
                    self.Active.fly = false
                    return
                end

                local camera = workspace.CurrentCamera
                if camera then
                    local move = hum.MoveDirection
                    local velocityVector = Vector3.zero
                    if move.Magnitude > 0.05 then
                        -- Сначала переводим стик в локальные оси тела, затем обратно
                        -- в мир: наклон тела теперь влияет на вертикальную составляющую.
                        local localMove = root.CFrame:VectorToObjectSpace(move)
                        local bodyRelative = Vector3.new(localMove.X, 0, localMove.Z)
                        if bodyRelative.Magnitude > 0.05 then
                            velocityVector = root.CFrame:VectorToWorldSpace(bodyRelative.Unit) * (self.FlySpeed or 55)
                        end
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.E) then
                        velocityVector += Vector3.new(0, 42, 0)
                    elseif UserInputService:IsKeyDown(Enum.KeyCode.Q) then
                        velocityVector -= Vector3.new(0, 42, 0)
                    elseif os.clock() < self.AscendUntil then
                        velocityVector += Vector3.new(0, 42, 0)
                    end
                    bv.Velocity = velocityVector
                    bg.CFrame = camera.CFrame
                end
            end
        end)

        self.JumpConnection = UserInputService.JumpRequest:Connect(function()
            if self.Fly then self.AscendUntil = os.clock() + 0.28 end
            if self.InfiniteJump then
                local _, hum = self:GetCharacter()
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end
        end)
    end

    function FeatureEngine:Destroy()
        for id, active in pairs(table.clone(self.Active)) do
            if active then pcall(function() self:Set(id, false) end) end
        end
        self:Set("fly", false)
        self:Set("noclip", false)
        if self.Heartbeat then self.Heartbeat:Disconnect() self.Heartbeat = nil end
        if self.JumpConnection then self.JumpConnection:Disconnect() self.JumpConnection = nil end
        self.CharacterMaid:Clean()
    end

    local engine = FeatureEngine.new()
    engine:Start()

    ------------------------------------------------------------------
    -- РАСПОЗНАВАНИЕ ТЕКСТОВОГО ЗАПРОСА (ТОЛЬКО WHITELIST)
    ------------------------------------------------------------------
    -- Reality Brain v5: расширенная база намерений, нормализация и безопасное сопоставление.
    -- Версия остаётся whitelist-движком: текст пользователя никогда не исполняется как код.
    -- Только локальный whitelist; пользовательский текст никогда не исполняется как Lua.
    local FeatureDefs = {
        fly = {Id="fly", Name="Полёт", Icon="✈️", Description="Полёт с учётом наклона тела.",
            Match=[[полет|летать|летаю|лети|лететь|взлететь|взлетай|парить|парение|режим полета|дай полет|хочу летать|свободный полет|управляемый полет|летать как птица|полет по наклону|fly|flying|flight|take off|levitate|air mode|fly mode|летат|полетик|дай крылья|свободно летать|лети куда смотрю|flying mode|хочу взлететь|подними меня в воздух|режим полета включи|парить в воздухе|летающий режим|хочу свободно летать|дай возможность летать|летать без ограничений|подниматься в воздух|включи режим полёта]]},
        noclip = {Id="noclip", Name="Проход сквозь стены", Icon="👻", Description="Отключает столкновения частей персонажа.",
            Match=[[сквозь стены|проходить сквозь|проходить через|проходить стены|ходить сквозь|ходить через стены|пролетать сквозь|ноклип|ноуклип|ноклипчик|no clip|noclip|ghost mode|призрак|стать призраком|без столкновений|убрать коллизии|отключить коллизию|нет коллизии|no collision|сквозь объекты|сквозь блоки|пройти стену|сквозь текстуры|без стен|no clipping|проходи через любые стены|не сталкиваться с объектами|убери столкновения персонажа|выключи столкновения|ходить через объекты]]},
        speed = {Id="speed", Name="Ускорение", Icon="⚡", Description="Увеличивает скорость ходьбы.",
            Match=[[ускорение|ускорь меня|быстрее|быстрый бег|быстро бегать|скорость бега|скорость ходьбы|увеличить скорость|повысить скорость|дай скорость|супер скорость|сверхскорость|спринт|бегать быстро|двигаться быстрее|speed|walkspeed|walk speed|run faster|fast run|super speed|sprint|speed boost|ускориться|быстрое передвижение|быстрый персонаж|скоростной режим|спид|спидхак|speedhack|быстроногий|максимальная скорость|бег на максималках|бегать намного быстрее|ускорь передвижение|сделай меня быстрее|дай максимальный бег|двигаться на высокой скорости]]},
        jump = {Id="jump", Name="Высокий прыжок", Icon="🦘", Description="Увеличивает силу прыжка.",
            Match=[[высокий прыжок|прыгать выше|прыжок выше|сильный прыжок|суперпрыжок|супер прыжок|высоко прыгать|увеличить прыжок|усилить прыжок|большой прыжок|мощный прыжок|прыжковая сила|дай прыжок|jump boost|high jump|super jump|higher jump|jump higher|big jump|strong jump|прыгучесть|прыгать высоко|джамп|джампхак|jumphack|прыгать как супермен|прыжок на максимум|прыгать намного выше|сделай прыжки сильнее|дай высокий прыжок|подбрось меня выше]]},
        infinite_jump = {Id="infinite_jump", Name="Бесконечный прыжок", Icon="♾️", Description="Повторный прыжок в воздухе.",
            Match=[[бесконечный прыжок|бесконечные прыжки|прыгать бесконечно|много прыжков|двойной прыжок|двойные прыжки|тройной прыжок|прыгать в воздухе|прыжок в воздухе|повторный прыжок|мульти прыжок|multi jump|infinite jump|double jump|triple jump|air jump|unlimited jump|jump in air|прыгать несколько раз|инфинити джамп|инфинит джамп|джамп бесконечный|прыжки без земли|прыгать без касания земли]]},
        low_gravity = {Id="low_gravity", Name="Низкая гравитация", Icon="🌙", Description="Уменьшает гравитацию на клиенте.",
            Match=[[низкая гравитация|меньше гравитации|уменьшить гравитацию|слабая гравитация|лунная гравитация|как на луне|легкая гравитация|низкая сила тяжести|плавать в воздухе|медленно падать|low gravity|moon gravity|less gravity|low grav|floaty|уменьши тяжесть|легкость|антигравитация|анти гравитация|гравитация луны|падать медленнее|парить|почти нет гравитации|сделай падение медленнее|уменьши силу тяжести|гравитация поменьше]]},
        fov = {Id="fov", Name="Широкая камера", Icon="🎥", Description="Расширяет поле зрения камеры.",
            Match=[[широкая камера|увеличить обзор|шире обзор|широкий обзор|увеличить fov|фов|поле зрения|дальний обзор|камера шире|wide fov|increase fov|field of view|широкий угол|расширь камеру|больше обзора|фов побольше|камера отдаленнее|отдалить камеру|расширить fov]]},
        spin = {Id="spin", Name="Вращение", Icon="🌀", Description="Вращает персонажа вокруг вертикальной оси.",
            Match=[[крутиться|вращаться|крути меня|спин|вращение персонажа|крутящийся персонаж|вертеться|spin|spinning|spin bot|rotate character|крутиться на месте|быстро вращаться|спиннер|вертушка|крутилка|вращай меня|крутись|крути меня|кружиться|кружи меня|вращай персонажа|вертись|спинбот]]},
        freeze = {Id="freeze", Name="Заморозка", Icon="🧊", Description="Фиксирует персонажа на месте.",
            Match=[[заморозить меня|заморозка|заморозь персонажа|замри|стоять неподвижно|зафиксировать персонажа|не двигаться|остановить персонажа|freeze|frozen|lock position|anchor me|заморозить персонажа|останови меня|стоп персонаж|замри на месте|закрепить на месте]]},
        invisible = {Id="invisible", Name="Локальная невидимость", Icon="👁️", Description="Скрывает персонажа только на твоём клиенте.",
            Match=[[невидимость|невидимый|сделай невидимым|скрыть персонажа|спрятать персонажа|невидимый персонаж|прозрачный персонаж|исчезнуть|invisible|invisibility|hide character|hide me|make me invisible|прозрачность персонажа|скрыть себя|инвиз|инвизибл|исчезни|сделай инвиз|невидеиость|невидемость|невидимка|невидимым|невидимая|сделай меня невидимым|сделай невидимость|спрячь меня|invis]]},
        bright = {Id="bright", Name="Яркое освещение", Icon="☀️", Description="Меняет локальное освещение для видимости.",
            Match=[[яркость|сделай ярче|яркое освещение|увеличить яркость|светлее|убрать темноту|день|сделай день|осветлить карту|полный свет|bright|fullbright|brightness|daylight|bright mode|больше света|освети|фулбрайт|фуллбрайт|максимальная яркость|убрать ночь|поставь день]]},
        slow = {Id="slow", Name="Медленная ходьба", Icon="🐢", Description="Снижает скорость ходьбы.",
            Match=[[медленно ходить|замедлиться|медленная ходьба|медленный бег|ходить медленно|slow speed|slow walk|slow motion movement|улитка|скорость поменьше|снизить скорость]]},
        super_speed = {Id="super_speed", Name="Суперскорость", Icon="⚡", Description="Устанавливает очень высокую скорость ходьбы.",
            Match=[[суперскорость|очень быстро|максимальная скорость бега|скорость 65|бегать как молния|сверхбыстрый бег|super speed|super fast|extreme speed|быстрее всех|турбо скорость|турбо бег|ускорение максимум]]},
        mega_jump = {Id="mega_jump", Name="Мега-прыжок", Icon="🚀", Description="Даёт очень высокий прыжок.",
            Match=[[мега прыжок|мега-прыжок|гигантский прыжок|прыжок очень высоко|прыгнуть на крышу|прыжок 140|ультра прыжок|mega jump|extreme jump|super high jump|прыгать очень высоко]]},
        high_gravity = {Id="high_gravity", Name="Высокая гравитация", Icon="🪨", Description="Увеличивает гравитацию на клиенте.",
            Match=[[высокая гравитация|сильная гравитация|увеличить гравитацию|тяжёлая гравитация|тяжелая гравитация|как на земле|high gravity|heavy gravity|большая сила тяжести|падать быстрее|ускорить падение]]},
        no_fog = {Id="no_fog", Name="Убрать туман", Icon="🌫️", Description="Убирает стандартный туман локального освещения.",
            Match=[[убрать туман|отключить туман|без тумана|видеть сквозь туман|снять туман|no fog|remove fog|disable fog|clear fog|прозрачный воздух|дальний обзор без тумана]]},
        first_person = {Id="first_person", Name="Первое лицо", Icon="👁️", Description="Переключает камеру в первое лицо.",
            Match=[[первое лицо|вид от первого лица|камера от глаз|переключи на fp|first person|first-person|fps camera|режим от глаз]]},
        third_person = {Id="third_person", Name="Третье лицо", Icon="🎥", Description="Возвращает обычную камеру от третьего лица.",
            Match=[[третье лицо|вид от третьего лица|камера сзади|обычная камера|third person|third-person|tps camera|отодвинь камеру]]},
        auto_rotate_off = {Id="auto_rotate_off", Name="Отключить автоповорот", Icon="🧭", Description="Отключает автоматический поворот персонажа по направлению движения.",
            Match=[[отключить автоповорот|без автоповорота|не поворачивай персонажа|зафиксировать направление|не разворачивай меня|disable autorotate|no auto rotate|lock character rotation]]},
        sit = {Id="sit", Name="Сесть", Icon="🪑", Description="Заставляет персонажа сесть.",
            Match=[[сядь|сесть|посади персонажа|сесть на землю|sit down|make me sit|sit]]},
        platform = {Id="platform", Name="Платформа под ногами", Icon="🟦", Description="Создаёт локальную платформу под персонажем.",
            Match=[[платформа под ногами|создай платформу|платформа подо мной|плиту под ногами|стоять на платформе|platform under me|spawn platform|платформа снизу|летающая платформа]]},
        anti_afk = {Id="anti_afk", Name="Анти-AFK", Icon="⏱️", Description="Пытается предотвращать локальный AFK-таймер, если executor поддерживает VirtualUser.",
            Match=[[анти афк|анти-afk|не кикать за афк|защита от афк|не выкидывай за бездействие|anti afk|anti-afk|prevent afk kick|stay active]]},
        highlight_players = {Id="highlight_players", Name="Подсветка игроков", Icon="🟡", Description="Подсвечивает персонажей других игроков на твоём клиенте.",
            Match=[[подсветить игроков|подсветка игроков|видеть игроков|обводка игроков|подсвети всех|highlight players|player esp highlight|выделить игроков|светящиеся игроки|контуры игроков|esp|еср|еsр|еsp|wallhack|wall hack|вх|видеть сквозь стены|вижу сквозь стены|видеть игроков через стены|подсветить всех игроков|обнаружение игроков|player esp|players esp|игроки сквозь стены|покажи где игроки|найди игроков на карте|подсвечивай противников]]},
        hide_others = {Id="hide_others", Name="Скрыть других игроков", Icon="🙈", Description="Локально скрывает персонажей остальных игроков.",
            Match=[[скрыть других игроков|убрать игроков с экрана|спрятать всех игроков|невидимые другие игроки|hide other players|hide players|hide everyone|убери остальных|не показывать игроков]]},
        highlight_npcs = {Id="highlight_npcs", Name="Подсветка NPC", Icon="🤖", Description="Подсвечивает NPC с Humanoid на карте.",
            Match=[[подсветить нпс|подсветка нпс|найти npc|обводка нпс|подсвети ботов|highlight npcs|npc esp|выделить npc|покажи нпс]]},
        remove_particles = {Id="remove_particles", Name="Убрать эффекты", Icon="🧹", Description="Отключает локальные частицы, лучи и визуальные эффекты.",
            Match=[[убрать частицы|отключить эффекты|убери визуальные эффекты|без частиц|выключить партиклы|remove particles|disable particles|remove effects|убрать дым и огонь]]},
        remove_decals = {Id="remove_decals", Name="Убрать текстуры", Icon="🧽", Description="Скрывает Decal и Texture локально.",
            Match=[[убрать текстуры|скрыть декали|убрать наклейки|без текстур|remove decals|hide decals|remove textures|отключить текстуры]]},
        remove_postfx = {Id="remove_postfx", Name="Отключить постэффекты", Icon="🎞️", Description="Отключает постэффекты Lighting на клиенте.",
            Match=[[отключить постэффекты|убрать постобработку|без bloom|убрать blur|отключить blur|disable post effects|remove postfx|no post processing]]},
        no_shadows = {Id="no_shadows", Name="Убрать тени", Icon="🌑", Description="Отключает глобальные тени локально.",
            Match=[[убрать тени|отключить тени|без теней|выключи тени|no shadows|disable shadows|remove shadows]]},
        night_vision = {Id="night_vision", Name="Ночное зрение", Icon="🟢", Description="Повышает локальную яркость для тёмных карт.",
            Match=[[ночное зрение|вижу в темноте|сделай темноту светлой|подсвети темноту|night vision|see in dark|ночной режим зрения]]},
        zoom_out = {Id="zoom_out", Name="Отдалить камеру", Icon="🔭", Description="Увеличивает доступное отдаление камеры.",
            Match=[[отдалить камеру|камера дальше|максимально отдалить|дальний зум|zoom out|far camera|камера подальше]]},
        zoom_in = {Id="zoom_in", Name="Приблизить камеру", Icon="🔍", Description="Ограничивает камеру близким расстоянием.",
            Match=[[приблизить камеру|камера ближе|максимально приблизить|ближний зум|zoom in|close camera|камера поближе]]},
        narrow_fov = {Id="narrow_fov", Name="Узкий угол камеры", Icon="🎯", Description="Уменьшает поле зрения камеры.",
            Match=[[узкий угол камеры|уменьши обзор|меньше fov|снизить фов|узкий fov|narrow fov|decrease fov|zoomed fov]]},
        hide_names = {Id="hide_names", Name="Скрыть имя над головой", Icon="🔤", Description="Скрывает отображение имени своего Humanoid.",
            Match=[[скрыть имя|убрать ник над головой|не показывать ник|скрыть ник|hide name|hide username|no name tag]]},
        forcefield_visual = {Id="forcefield_visual", Name="Силовое поле", Icon="🛡️", Description="Добавляет визуальный ForceField; не гарантирует защиту от урона.",
            Match=[[силовое поле|создай щит вокруг меня|визуальный щит|forcefield|force field|shield effect|оболочка щита]]},
        sparkles = {Id="sparkles", Name="Искры вокруг персонажа", Icon="✨", Description="Добавляет локальный эффект искр.",
            Match=[[искры вокруг меня|добавь искры|эффект искр|сверкать|sparkles|sparkle aura|блёстки вокруг]]},
        fire_aura = {Id="fire_aura", Name="Огонь вокруг персонажа", Icon="🔥", Description="Добавляет локальный визуальный огонь.",
            Match=[[огонь вокруг меня|поджечь визуально|аура огня|пламя вокруг|fire aura|flames around me|добавь огонь]]},
        smoke_aura = {Id="smoke_aura", Name="Дым вокруг персонажа", Icon="💨", Description="Добавляет локальный визуальный дым.",
            Match=[[дым вокруг меня|аура дыма|дымовая оболочка|smoke aura|smoke effect|добавь дым]]},
        trail = {Id="trail", Name="След за персонажем", Icon="🌈", Description="Создаёт локальный Trail при движении.",
            Match=[[след за мной|шлейф за персонажем|оставлять след|трейл|trail behind me|character trail|светящийся след]]},
        remove_accessories = {Id="remove_accessories", Name="Скрыть аксессуары", Icon="🧢", Description="Скрывает аксессуары только на своём клиенте.",
            Match=[[скрыть аксессуары|убрать шапку|убрать шляпы|без аксессуаров|hide accessories|remove hats|hide hats|убрать украшения]]},
        sit_off = {Id="sit_off", Name="Встать", Icon="🧍", Description="Поднимает персонажа из положения сидя.",
            Match=[[встань|подняться со стула|перестань сидеть|выйти из сидения|stand up|stop sitting|get up]]},
        reset_camera = {Id="reset_camera", Name="Сбросить камеру", Icon="📷", Description="Возвращает стандартный тип камеры и FOV.",
            Match=[[сбросить камеру|верни обычную камеру|почини камеру|reset camera|default camera|обычная камера по умолчанию]]},
        reset_movement = {Id="reset_movement", Name="Сбросить движение", Icon="♻️", Description="Возвращает базовые скорость, прыжок и автоповорот.",
            Match=[[сбросить движение|обычная скорость|вернуть стандартные параметры|сбросить скорость и прыжок|reset movement|default movement|reset walk speed]]},
        slow_fall = {Id="slow_fall", Name="Медленное падение", Icon="🪂", Description="Снижает гравитацию для более медленного падения.",
            Match=[[медленно падать|замедлить падение|плавное падение|падать как перо|slow fall|feather fall|парашютное падение]]},
        head_hide = {Id="head_hide", Name="Скрыть голову", Icon="🎭", Description="Скрывает голову локально.",
            Match=[[скрыть голову|убрать голову|без головы|невидимая голова|hide head|headless look|no head]]},
        body_highlight = {Id="body_highlight", Name="Обводка персонажа", Icon="🔆", Description="Добавляет локальную подсветку своего персонажа.",
            Match=[[обвести меня|подсветить себя|обводка моего персонажа|свечение вокруг меня|highlight my character|self highlight|outline myself]]},
        walk_speed_20 = {Id="walk_speed_20", Name="Скорость 20", Icon="⚡", Description="Устанавливает локальную скорость ходьбы 20.",
            Match=[[скорость ходьбы 20|скорость 20|ходить со скоростью 20|walk speed 20|speed 20]]},
        walk_speed_24 = {Id="walk_speed_24", Name="Скорость 24", Icon="⚡", Description="Устанавливает локальную скорость ходьбы 24.",
            Match=[[скорость ходьбы 24|скорость 24|ходить со скоростью 24|walk speed 24|speed 24]]},
        walk_speed_40 = {Id="walk_speed_40", Name="Скорость 40", Icon="⚡", Description="Устанавливает локальную скорость ходьбы 40.",
            Match=[[скорость ходьбы 40|скорость 40|ходить со скоростью 40|walk speed 40|speed 40]]},
        walk_speed_50 = {Id="walk_speed_50", Name="Скорость 50", Icon="⚡", Description="Устанавливает локальную скорость ходьбы 50.",
            Match=[[скорость ходьбы 50|скорость 50|ходить со скоростью 50|walk speed 50|speed 50]]},
        walk_speed_80 = {Id="walk_speed_80", Name="Скорость 80", Icon="⚡", Description="Устанавливает локальную скорость ходьбы 80.",
            Match=[[скорость ходьбы 80|скорость 80|ходить со скоростью 80|walk speed 80|speed 80]]},
        walk_speed_100 = {Id="walk_speed_100", Name="Скорость 100", Icon="⚡", Description="Устанавливает локальную скорость ходьбы 100.",
            Match=[[скорость ходьбы 100|скорость 100|ходить со скоростью 100|walk speed 100|speed 100]]},
        walk_speed_120 = {Id="walk_speed_120", Name="Скорость 120", Icon="⚡", Description="Устанавливает локальную скорость ходьбы 120.",
            Match=[[скорость ходьбы 120|скорость 120|ходить со скоростью 120|walk speed 120|speed 120]]},
        walk_speed_150 = {Id="walk_speed_150", Name="Скорость 150", Icon="⚡", Description="Устанавливает локальную скорость ходьбы 150.",
            Match=[[скорость ходьбы 150|скорость 150|ходить со скоростью 150|walk speed 150|speed 150]]},
        jump_power_60 = {Id="jump_power_60", Name="Сила прыжка 60", Icon="🦘", Description="Устанавливает силу прыжка 60.",
            Match=[[сила прыжка 60|прыжок 60|прыгать на 60|jump power 60|jump 60]]},
        jump_power_70 = {Id="jump_power_70", Name="Сила прыжка 70", Icon="🦘", Description="Устанавливает силу прыжка 70.",
            Match=[[сила прыжка 70|прыжок 70|прыгать на 70|jump power 70|jump 70]]},
        jump_power_100 = {Id="jump_power_100", Name="Сила прыжка 100", Icon="🦘", Description="Устанавливает силу прыжка 100.",
            Match=[[сила прыжка 100|прыжок 100|прыгать на 100|jump power 100|jump 100]]},
        jump_power_120 = {Id="jump_power_120", Name="Сила прыжка 120", Icon="🦘", Description="Устанавливает силу прыжка 120.",
            Match=[[сила прыжка 120|прыжок 120|прыгать на 120|jump power 120|jump 120]]},
        jump_power_160 = {Id="jump_power_160", Name="Сила прыжка 160", Icon="🦘", Description="Устанавливает силу прыжка 160.",
            Match=[[сила прыжка 160|прыжок 160|прыгать на 160|jump power 160|jump 160]]},
        jump_power_200 = {Id="jump_power_200", Name="Сила прыжка 200", Icon="🦘", Description="Устанавливает силу прыжка 200.",
            Match=[[сила прыжка 200|прыжок 200|прыгать на 200|jump power 200|jump 200]]},
        jump_power_250 = {Id="jump_power_250", Name="Сила прыжка 250", Icon="🦘", Description="Устанавливает силу прыжка 250.",
            Match=[[сила прыжка 250|прыжок 250|прыгать на 250|jump power 250|jump 250]]},
        jump_power_300 = {Id="jump_power_300", Name="Сила прыжка 300", Icon="🦘", Description="Устанавливает силу прыжка 300.",
            Match=[[сила прыжка 300|прыжок 300|прыгать на 300|jump power 300|jump 300]]},
        gravity_50 = {Id="gravity_50", Name="Гравитация 50", Icon="🪐", Description="Устанавливает локальную гравитацию 50.",
            Match=[[гравитация 50|сила тяжести 50|gravity 50|grav 50]]},
        gravity_70 = {Id="gravity_70", Name="Гравитация 70", Icon="🪐", Description="Устанавливает локальную гравитацию 70.",
            Match=[[гравитация 70|сила тяжести 70|gravity 70|grav 70]]},
        gravity_120 = {Id="gravity_120", Name="Гравитация 120", Icon="🪐", Description="Устанавливает локальную гравитацию 120.",
            Match=[[гравитация 120|сила тяжести 120|gravity 120|grav 120]]},
        gravity_150 = {Id="gravity_150", Name="Гравитация 150", Icon="🪐", Description="Устанавливает локальную гравитацию 150.",
            Match=[[гравитация 150|сила тяжести 150|gravity 150|grav 150]]},
        gravity_250 = {Id="gravity_250", Name="Гравитация 250", Icon="🪐", Description="Устанавливает локальную гравитацию 250.",
            Match=[[гравитация 250|сила тяжести 250|gravity 250|grav 250]]},
        gravity_300 = {Id="gravity_300", Name="Гравитация 300", Icon="🪐", Description="Устанавливает локальную гравитацию 300.",
            Match=[[гравитация 300|сила тяжести 300|gravity 300|grav 300]]},
        gravity_400 = {Id="gravity_400", Name="Гравитация 400", Icon="🪐", Description="Устанавливает локальную гравитацию 400.",
            Match=[[гравитация 400|сила тяжести 400|gravity 400|grav 400]]},
        gravity_600 = {Id="gravity_600", Name="Гравитация 600", Icon="🪐", Description="Устанавливает локальную гравитацию 600.",
            Match=[[гравитация 600|сила тяжести 600|gravity 600|grav 600]]},
        fov_80 = {Id="fov_80", Name="Угол камеры 80", Icon="🎥", Description="Устанавливает поле зрения камеры 80 градусов.",
            Match=[[fov 80|фов 80|угол обзора 80|поле зрения 80|camera fov 80]]},
        fov_100 = {Id="fov_100", Name="Угол камеры 100", Icon="🎥", Description="Устанавливает поле зрения камеры 100 градусов.",
            Match=[[fov 100|фов 100|угол обзора 100|поле зрения 100|camera fov 100]]},
        fov_110 = {Id="fov_110", Name="Угол камеры 110", Icon="🎥", Description="Устанавливает поле зрения камеры 110 градусов.",
            Match=[[fov 110|фов 110|угол обзора 110|поле зрения 110|camera fov 110]]},
        fov_120 = {Id="fov_120", Name="Угол камеры 120", Icon="🎥", Description="Устанавливает поле зрения камеры 120 градусов.",
            Match=[[fov 120|фов 120|угол обзора 120|поле зрения 120|camera fov 120]]},
        fov_130 = {Id="fov_130", Name="Угол камеры 130", Icon="🎥", Description="Устанавливает поле зрения камеры 130 градусов.",
            Match=[[fov 130|фов 130|угол обзора 130|поле зрения 130|camera fov 130]]},
        fov_140 = {Id="fov_140", Name="Угол камеры 140", Icon="🎥", Description="Устанавливает поле зрения камеры 140 градусов.",
            Match=[[fov 140|фов 140|угол обзора 140|поле зрения 140|camera fov 140]]},
        camera_zoom_10 = {Id="camera_zoom_10", Name="Зум камеры 10", Icon="🔭", Description="Настраивает максимальное отдаление камеры до 10.",
            Match=[[зум камеры 10|отдаление камеры 10|камера на 10|camera zoom 10|zoom 10]]},
        camera_zoom_20 = {Id="camera_zoom_20", Name="Зум камеры 20", Icon="🔭", Description="Настраивает максимальное отдаление камеры до 20.",
            Match=[[зум камеры 20|отдаление камеры 20|камера на 20|camera zoom 20|zoom 20]]},
        camera_zoom_30 = {Id="camera_zoom_30", Name="Зум камеры 30", Icon="🔭", Description="Настраивает максимальное отдаление камеры до 30.",
            Match=[[зум камеры 30|отдаление камеры 30|камера на 30|camera zoom 30|zoom 30]]},
        camera_zoom_50 = {Id="camera_zoom_50", Name="Зум камеры 50", Icon="🔭", Description="Настраивает максимальное отдаление камеры до 50.",
            Match=[[зум камеры 50|отдаление камеры 50|камера на 50|camera zoom 50|zoom 50]]},
        hip_height_low = {Id="hip_height_low", Name="Низкая посадка", Icon="📏", Description="Уменьшает высоту HipHeight персонажа.",
            Match=[[низкая посадка|низкий hip height|low hip height]]},
        hip_height_normal = {Id="hip_height_normal", Name="Обычная высота", Icon="📏", Description="Возвращает стандартную высоту HipHeight.",
            Match=[[обычная высота персонажа|нормальный hip height|normal hip height]]},
        hip_height_high = {Id="hip_height_high", Name="Высокая посадка", Icon="📏", Description="Увеличивает высоту HipHeight персонажа.",
            Match=[[высокая посадка|высокий hip height|high hip height]]},
        hip_height_very_high = {Id="hip_height_very_high", Name="Очень высокая посадка", Icon="📏", Description="Сильно увеличивает высоту HipHeight персонажа.",
            Match=[[очень высокая посадка|максимальный hip height|very high hip height]]},
        body_translucent = {Id="body_translucent", Name="Полупрозрачное тело", Icon="🧊", Description="Делает части тела полупрозрачными локально.",
            Match=[[полупрозрачное тело|сделай меня прозрачным наполовину|translucent body]]},
        ghost_body = {Id="ghost_body", Name="Призрачное тело", Icon="🧊", Description="Делает тело почти прозрачным локально.",
            Match=[[призрачное тело|почти прозрачный персонаж|ghost body]]},
        metal_body = {Id="metal_body", Name="Металлическое тело", Icon="🧊", Description="Меняет материал частей тела на металл локально.",
            Match=[[металлическое тело|тело из металла|metal body]]},
        neon_body = {Id="neon_body", Name="Неоновое тело", Icon="🧊", Description="Меняет материал частей тела на Neon локально.",
            Match=[[неоновое тело|сделай тело неоновым|neon body]]},
        plastic_body = {Id="plastic_body", Name="Пластиковое тело", Icon="🧊", Description="Меняет материал частей тела на пластик локально.",
            Match=[[пластиковое тело|тело из пластика|plastic body]]},
        ice_body = {Id="ice_body", Name="Ледяное тело", Icon="🧊", Description="Меняет материал частей тела на лёд локально.",
            Match=[[ледяное тело|тело изо льда|ice body]]},
        body_color_red = {Id="body_color_red", Name="Красное тело", Icon="🎨", Description="Меняет цвет частей тела только на твоём клиенте.",
            Match=[[красное тело|покрась меня в красный|red body]]},
        body_color_blue = {Id="body_color_blue", Name="Синее тело", Icon="🎨", Description="Меняет цвет частей тела только на твоём клиенте.",
            Match=[[синее тело|покрась меня в синий|blue body]]},
        body_color_green = {Id="body_color_green", Name="Зелёное тело", Icon="🎨", Description="Меняет цвет частей тела только на твоём клиенте.",
            Match=[[зеленое тело|зелёное тело|покрась меня в зеленый|green body]]},
        body_color_gold = {Id="body_color_gold", Name="Золотое тело", Icon="🎨", Description="Меняет цвет частей тела только на твоём клиенте.",
            Match=[[золотое тело|покрась меня в золотой|gold body]]},
        body_color_purple = {Id="body_color_purple", Name="Фиолетовое тело", Icon="🎨", Description="Меняет цвет частей тела только на твоём клиенте.",
            Match=[[фиолетовое тело|покрась меня в фиолетовый|purple body]]},
        body_color_black = {Id="body_color_black", Name="Чёрное тело", Icon="🎨", Description="Меняет цвет частей тела только на твоём клиенте.",
            Match=[[черное тело|чёрное тело|покрась меня в черный|black body]]},
        body_color_white = {Id="body_color_white", Name="Белое тело", Icon="🎨", Description="Меняет цвет частей тела только на твоём клиенте.",
            Match=[[белое тело|покрась меня в белый|white body]]},
        lighting_day = {Id="lighting_day", Name="Дневное освещение", Icon="💡", Description="Переключает локальную сцену на яркий день.",
            Match=[[сделай день|дневное освещение|day lighting]]},
        lighting_sunset = {Id="lighting_sunset", Name="Закатное освещение", Icon="💡", Description="Применяет тёплый локальный закатный свет.",
            Match=[[сделай закат|закатное освещение|sunset lighting]]},
        lighting_midnight = {Id="lighting_midnight", Name="Полночь", Icon="💡", Description="Применяет локальную ночную освещённость.",
            Match=[[сделай полночь|ночное освещение|midnight lighting]]},
        lighting_soft = {Id="lighting_soft", Name="Мягкий свет", Icon="💡", Description="Смягчает локальное освещение.",
            Match=[[мягкий свет|soft lighting]]},
        lighting_contrast = {Id="lighting_contrast", Name="Контрастный свет", Icon="💡", Description="Усиливает локальную яркость и контраст окружения.",
            Match=[[контрастное освещение|сильный контраст света|high contrast lighting]]},
        outline_blue = {Id="outline_blue", Name="Синяя обводка", Icon="🔆", Description="Добавляет локальную цветную обводку персонажа.",
            Match=[[синяя обводка меня|обведи синим|blue outline]]},
        outline_red = {Id="outline_red", Name="Красная обводка", Icon="🔆", Description="Добавляет локальную цветную обводку персонажа.",
            Match=[[красная обводка меня|обведи красным|red outline]]},
        outline_green = {Id="outline_green", Name="Зелёная обводка", Icon="🔆", Description="Добавляет локальную цветную обводку персонажа.",
            Match=[[зеленая обводка меня|зелёная обводка меня|обведи зеленым|green outline]]},
        outline_gold = {Id="outline_gold", Name="Золотая обводка", Icon="🔆", Description="Добавляет локальную цветную обводку персонажа.",
            Match=[[золотая обводка меня|обведи золотым|gold outline]]},
        aura_blue = {Id="aura_blue", Name="Синяя аура", Icon="✨", Description="Создаёт локальное свечение вокруг персонажа.",
            Match=[[синяя аура|аура синего цвета|blue aura]]},
        aura_green = {Id="aura_green", Name="Зелёная аура", Icon="✨", Description="Создаёт локальное свечение вокруг персонажа.",
            Match=[[зеленая аура|зелёная аура|green aura]]},
        aura_purple = {Id="aura_purple", Name="Фиолетовая аура", Icon="✨", Description="Создаёт локальное свечение вокруг персонажа.",
            Match=[[фиолетовая аура|аура фиолетового цвета|purple aura]]},
        aura_gold = {Id="aura_gold", Name="Золотая аура", Icon="✨", Description="Создаёт локальное свечение вокруг персонажа.",
            Match=[[золотая аура|аура золотого цвета|gold aura]]},

        -- Дополнительные режимы параметров: появляются только по запросу.
        walk_speed_200 = {Id="walk_speed_200", Name="Скорость 200", Icon="⚡", Description="Устанавливает локальную скорость ходьбы 200.",
            Match=[[скорость 200|беги 200|ходьба 200|walk speed 200|speed 200|супер скорость 200]]},
        jump_power_400 = {Id="jump_power_400", Name="Прыжок 400", Icon="🚀", Description="Устанавливает силу прыжка 400.",
            Match=[[прыжок 400|прыгай 400|сила прыжка 400|jump power 400|jump 400|мега прыжок 400]]},
        gravity_0 = {Id="gravity_0", Name="Нулевая гравитация", Icon="🪐", Description="Устанавливает локальную гравитацию в ноль.",
            Match=[[нулевая гравитация|гравитация 0|невесомость|сделай невесомость|zero gravity|gravity zero|gravity 0|парить без веса]]},
        gravity_20 = {Id="gravity_20", Name="Гравитация 20", Icon="🌙", Description="Устанавливает очень низкую локальную гравитацию.",
            Match=[[гравитация 20|сила тяжести 20|gravity 20|grav 20|почти невесомость]]},
        fov_150 = {Id="fov_150", Name="Угол камеры 150", Icon="🎥", Description="Устанавливает поле зрения камеры 150 градусов.",
            Match=[[fov 150|фов 150|угол обзора 150|поле зрения 150|camera fov 150|очень широкий обзор]]},
        camera_zoom_100 = {Id="camera_zoom_100", Name="Зум камеры 100", Icon="🔭", Description="Увеличивает доступное отдаление камеры до 100.",
            Match=[[зум камеры 100|отдаление камеры 100|камера на 100|camera zoom 100|zoom 100|очень далеко камера]]},

    }

    local function normalize(s)
        s = string.lower(tostring(s or "")):gsub("ё", "е")
        s = s:gsub("[%p%c]", " "):gsub("%s+", " ")
        return " " .. s:match("^%s*(.-)%s*$") .. " "
    end

    -- Словарь строится из уже проверенных фраз. Это не генерация кода:
    -- корректор только исправляет опечатки перед поиском совпадений.
    local typoAliases = {
        ["еср"]="esp", ["еsр"]="esp", ["еsp"]="esp", ["еcр"]="esp", ["есп"]="esp",
        ["невидеиость"]="невидимость", ["невидемость"]="невидимость", ["невидимост"]="невидимость",
        ["невидемым"]="невидимым", ["невидимымм"]="невидимым", ["врвщение"]="вращение",
        ["вращенее"]="вращение", ["вращенеи"]="вращение", ["полетт"]="полет",
        ["палет"]="полет", ["польот"]="полет", ["ноклипп"]="ноклип", ["ноклип"]="ноклип",
        ["фовв"]="фов", ["гравитацмя"]="гравитация", ["гравитацыя"]="гравитация",
        ["скорост"]="скорость", ["прыжокк"]="прыжок", ["летат"]="летать",
    }

    local function utf8Chars(value)
        local chars = {}
        for _, codepoint in utf8.codes(value) do
            chars[#chars + 1] = utf8.char(codepoint)
        end
        return chars
    end

    local function editDistance(a, b, cutoff)
        local aa, bb = utf8Chars(a), utf8Chars(b)
        if math.abs(#aa - #bb) > cutoff then return cutoff + 1 end
        local prev = {}
        for j = 0, #bb do prev[j] = j end
        for i = 1, #aa do
            local cur = {[0] = i}
            local rowMin = i
            for j = 1, #bb do
                local cost = aa[i] == bb[j] and 0 or 1
                cur[j] = math.min(cur[j-1] + 1, prev[j] + 1, prev[j-1] + cost)
                if cur[j] < rowMin then rowMin = cur[j] end
            end
            if rowMin > cutoff then return cutoff + 1 end
            prev = cur
        end
        return prev[#bb]
    end

    local vocabulary = {}
    for _, def in pairs(FeatureDefs) do
        for phrase in string.gmatch(def.Match, "([^|]+)") do
            for word in string.gmatch(normalize(phrase), "%S+") do
                if #utf8Chars(word) >= 4 then vocabulary[word] = true end
            end
        end
    end

    local function correctWord(word)
        if typoAliases[word] then return typoAliases[word] end
        if vocabulary[word] then return word end
        local n = #utf8Chars(word)
        if n < 4 then return word end
        local limit = n >= 8 and 2 or 1
        local best, bestDistance, ties = word, limit + 1, 0
        for candidate in pairs(vocabulary) do
            local candidateLength = #utf8Chars(candidate)
            if math.abs(candidateLength - n) <= limit then
                local distance = editDistance(word, candidate, limit)
                if distance < bestDistance then
                    best, bestDistance, ties = candidate, distance, 1
                elseif distance == bestDistance then
                    ties = ties + 1
                end
            end
        end
        if bestDistance <= limit and ties == 1 then return best end
        return word
    end

    local function registerDynamicNumeric(kind, rawValue)
        local value = tonumber(rawValue)
        if not value then return nil end
        local limits = {
            walk = { 16, 200, "walk_speed_", "Скорость ", "⚡", "walk" },
            jump = { 25, 400, "jump_power_", "Прыжок ", "🦘", "jump" },
            gravity = { 0, 600, "gravity_", "Гравитация ", "🌙", "gravity" },
            fov = { 40, 150, "fov_", "Угол камеры ", "🎥", "fov" },
            zoom = { 1, 100, "camera_zoom_", "Зум камеры ", "🔭", "zoom" },
        }
        local cfg = limits[kind]
        if not cfg then return nil end
        value = math.floor(math.clamp(value, cfg[1], cfg[2]) + 0.5)
        local id = cfg[3] .. tostring(value)
        if not FeatureDefs[id] then
            local kindMap = { walk = "walk", jump = "jump", gravity = "gravity", fov = "fov", zoom = "zoom" }
            EXTRA_FEATURE_CONFIG[id] = { Kind = kindMap[kind], Value = value }
            FeatureDefs[id] = {
                Id = id,
                Name = cfg[4] .. tostring(value),
                Icon = cfg[5],
                Description = "Пользовательское числовое значение " .. tostring(value) .. ".",
                Match = "",
            }
        end
        return id
    end

    local function isNegatedMatch(text, startPos)
        local prefix = text:sub(math.max(1, startPos - 42), startPos - 1)
        -- Не трактуем просьбу об отключении/отказе как создание включённой функции.
        -- Конструкции «без тумана», «без коллизий» остаются обычными позитивными намерениями.
        return prefix:match("не%s+хочу%s*$") ~= nil
            or prefix:match("не%s+надо%s*$") ~= nil
            or prefix:match("не%s+включай%s*$") ~= nil
            or prefix:match("не%s+делай%s*$") ~= nil
            or prefix:match("не%s+делай%s+меня%s*$") ~= nil
            or prefix:match("не%s+включай%s+мне%s*$") ~= nil
            or prefix:match("не%s+добавляй%s*$") ~= nil
            or prefix:match("отмени%s*$") ~= nil
    end

    local function parsePrompt(prompt)
        local raw = normalize(prompt)
        if #raw > 1200 then raw = raw:sub(1, 1200) end
        local corrected = {}
        for word in string.gmatch(raw, "%S+") do
            corrected[#corrected + 1] = correctWord(word)
        end
        local text = " " .. table.concat(corrected, " ") .. " "
        local found, matched = {}, {}
        for id, def in pairs(FeatureDefs) do
            local bestPhrase, bestLength, bestPos = nil, 0, nil
            for phrase in string.gmatch(def.Match, "([^|]+)") do
                phrase = phrase:match("^%s*(.-)%s*$")
                local normalizedPhrase = normalize(phrase)
                if phrase ~= "" then
                    local pos = text:find(normalizedPhrase, 1, true)
                    if pos and #normalizedPhrase > bestLength then
                        bestPhrase, bestLength, bestPos = phrase, #normalizedPhrase, pos
                    end
                end
            end
            if bestPhrase and not isNegatedMatch(text, bestPos) then
                found[id] = true
                matched[id] = bestPhrase
            end
        end
        -- Числовые пожелания поддерживают произвольные значения в безопасных пределах.
        -- Например: «скорость 73», «прыжок 180», «гравитация 35», «фов 105».
        local numericRules = {
            { kind = "walk", patterns = { "скорость%s+(%d+)", "скорости%s+(%d+)", "скоростью%s+(%d+)", "скорост%s+(%d+)", "walk%s+speed%s+(%d+)", "speed%s+(%d+)" }, remove = { "speed", "slow", "super_speed" } },
            { kind = "jump", patterns = { "сила%s+прыжка%s+(%d+)", "прыжок%s+(%d+)", "прыгать%s+(%d+)", "jump%s+power%s+(%d+)", "jump%s+(%d+)" }, remove = { "jump", "mega_jump" } },
            { kind = "gravity", patterns = { "гравитация%s+(%d+)", "сила%s+тяжести%s+(%d+)", "gravity%s+(%d+)" }, remove = { "low_gravity", "high_gravity", "slow_fall" } },
            { kind = "fov", patterns = { "угол%s+обзора%s+(%d+)", "поле%s+зрения%s+(%d+)", "фов%s+(%d+)", "fov%s+(%d+)" }, remove = { "fov", "narrow_fov" } },
            { kind = "zoom", patterns = { "зум%s+камеры%s+(%d+)", "отдаление%s+камеры%s+(%d+)", "camera%s+zoom%s+(%d+)", "zoom%s+(%d+)" }, remove = { "zoom_in", "zoom_out" } },
        }
        for _, rule in ipairs(numericRules) do
            local numericValue, numericStart
            for _, pattern in ipairs(rule.patterns) do
                local startPos, _, capture = text:find(pattern)
                if capture then
                    numericValue, numericStart = capture, startPos
                    break
                end
            end
            if numericValue and not isNegatedMatch(text, numericStart) then
                local dynamicId = registerDynamicNumeric(rule.kind, numericValue)
                if dynamicId then
                    for _, oldId in ipairs(rule.remove) do found[oldId] = nil end
                    found[dynamicId] = true
                    matched[dynamicId] = rule.kind .. " " .. tostring(numericValue)
                end
            end
        end
        return found, matched
    end

    -- СОХРАНЕНИЕ
    ------------------------------------------------------------------
    local SAVE_VERSION = 2
    local MAX_SAVED_FEATURES = 120
    local MAX_PROMPT_LENGTH = 500

    local function sanitizeSavedItems(data)
        local source = type(data) == "table" and (type(data.items) == "table" and data.items or data) or {}
        local clean, seen = {}, {}
        for _, item in ipairs(source) do
            if #clean >= MAX_SAVED_FEATURES then break end
            if type(item) == "table" and type(item.id) == "string" and type(item.prompt) == "string"
                and not seen[item.id] then
                local prompt = item.prompt:sub(1, MAX_PROMPT_LENGTH)
                local validId = FeatureDefs[item.id] ~= nil
                if not validId and prompt:gsub("%s", "") ~= "" then
                    local parsed = parsePrompt(prompt)
                    validId = parsed[item.id] == true
                end
                if validId and prompt:gsub("%s", "") ~= "" then
                    seen[item.id] = true
                    table.insert(clean, { id = item.id, prompt = prompt })
                end
            end
        end
        return clean
    end

    local function readSaved()
        if type(readfile) ~= "function" or type(isfile) ~= "function" then return {} end
        local ok, exists = pcall(isfile, SAVE_PATH)
        if not ok or not exists then return {} end
        local okRead, raw = pcall(readfile, SAVE_PATH)
        if not okRead or type(raw) ~= "string" or #raw > 100000 then return {} end
        local okJson, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if not okJson or type(data) ~= "table" then return {} end
        return sanitizeSavedItems(data)
    end

    local function writeSaved(data)
        if type(writefile) ~= "function" then return false, "В этом executor нет writefile." end
        local clean = sanitizeSavedItems(data)
        if type(makefolder) == "function" then pcall(makefolder, "PromptPhone") end
        local payload = {
            version = SAVE_VERSION,
            updatedAt = os.time(),
            items = clean,
        }
        local encodedOk, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
        if not encodedOk then return false, "Не удалось подготовить данные сохранения: " .. tostring(encoded) end
        local ok, err = pcall(function() writefile(SAVE_PATH, encoded) end)
        if not ok then return false, tostring(err) end
        -- Проверка записи, если executor предоставляет чтение.
        if type(readfile) == "function" then
            local verifyOk, verifyRaw = pcall(readfile, SAVE_PATH)
            if not verifyOk or type(verifyRaw) ~= "string" or verifyRaw ~= encoded then
                return false, "Файл записан, но проверка чтения не прошла."
            end
        end
        return true
    end

    ------------------------------------------------------------------
    -- ПРИЛОЖЕНИЕ / UI
    ------------------------------------------------------------------
    local appMaid = Maid.new()
    local saved = readSaved()
    local restored = false

    local function registerApp()
        return Phone.RegisterApp({
            Id = "reality_modifier",
            Name = "Reality Modifier",
            Icon = "✦",
            IconColor = Color3.fromRGB(105, 92, 245),
            WindowSize = Vector2.new(340, 500),
            Singleton = true,

            OnOpen = function(ctx)
                local content = ctx.Content
                local uiMaid = ctx.Maid
                local selectedId = nil
                local editingId = nil
                local retryingId = nil
                local entries = {}
                local statusLabel

                local root = New("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(1, 1),
                    Parent = content
                })

                local padding = New("UIPadding", {
                    PaddingTop = UDim.new(0, 10),
                    PaddingBottom = UDim.new(0, 10),
                    PaddingLeft = UDim.new(0, 10),
                    PaddingRight = UDim.new(0, 10),
                    Parent = root
                })

                local promptBox = New("TextBox", {
                    Name = "PromptInput",
                    Size = UDim2.new(1, 0, 0, 68),
                    BackgroundColor3 = Theme.Bar,
                    BorderSizePixel = 0,
                    ClearTextOnFocus = false,
                    MultiLine = true,
                    Text = "",
                    PlaceholderText = "Например: полёт + проходить сквозь стены",
                    PlaceholderColor3 = Theme.Muted,
                    TextColor3 = Theme.Text,
                    Font = Theme.Font,
                    TextSize = 14,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    Parent = root
                })
                round(promptBox, 10)
                New("UIPadding", {
                    PaddingTop = UDim.new(0, 8),
                    PaddingBottom = UDim.new(0, 8),
                    PaddingLeft = UDim.new(0, 9),
                    PaddingRight = UDim.new(0, 9),
                    Parent = promptBox
                })

                local createBtn = New("TextButton", {
                    Position = UDim2.new(0, 0, 0, 76),
                    Size = UDim2.new(1, 0, 0, 36),
                    BackgroundColor3 = Theme.Accent,
                    BorderSizePixel = 0,
                    Text = "✦ Создать функции",
                    TextColor3 = Color3.new(1, 1, 1),
                    Font = Theme.FontBold,
                    TextSize = 14,
                    Parent = root
                })
                round(createBtn, 10)

                statusLabel = New("TextLabel", {
                    Position = UDim2.new(0, 0, 0, 118),
                    Size = UDim2.new(1, 0, 0, 34),
                    BackgroundTransparency = 1,
                    Text = "Опиши желаемый результат обычными словами. Можно несколько пожеланий сразу.",
                    TextColor3 = Theme.Muted,
                    Font = Theme.Font,
                    TextSize = 11,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = root
                })

                local list = New("ScrollingFrame", {
                    Position = UDim2.new(0, 0, 0, 154),
                    Size = UDim2.new(1, 0, 1, -246),
                    BackgroundColor3 = Theme.Bg,
                    BorderSizePixel = 0,
                    ScrollBarThickness = 3,
                    ScrollBarImageColor3 = Theme.Muted,
                    CanvasSize = UDim2.new(),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    Parent = root
                })
                round(list, 10)
                New("UIPadding", {
                    PaddingTop = UDim.new(0, 7),
                    PaddingBottom = UDim.new(0, 7),
                    PaddingLeft = UDim.new(0, 7),
                    PaddingRight = UDim.new(0, 7),
                    Parent = list
                })
                New("UIListLayout", {
                    Padding = UDim.new(0, 6),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = list
                })

                local actionRow = New("Frame", {
                    Position = UDim2.new(0, 0, 1, -82),
                    Size = UDim2.new(1, 0, 0, 76),
                    BackgroundTransparency = 1,
                    Parent = root
                })
                New("UIGridLayout", {
                    CellSize = UDim2.new(0.5, -4, 0, 32),
                    CellPadding = UDim2.fromOffset(8, 6),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = actionRow
                })

                local function setStatus(text, isError)
                    statusLabel.Text = tostring(text)
                    statusLabel.TextColor3 = isError and Theme.Danger or Theme.Muted
                end

                local function refreshSelection()
                    for id, card in pairs(entries) do
                        card.Frame.BackgroundColor3 =
                            id == selectedId and Theme.Accent:Lerp(Theme.Surface, 0.55) or Theme.Surface
                        card.SelectStroke.Transparency = id == selectedId and 0 or 1
                    end
                end

                local function refreshCard(id)
                    local card = entries[id]
                    if not card then return end
                    local active = engine.Active[id] == true
                    card.Toggle.Text = active and "ВКЛ" or "ВЫКЛ"
                    card.Toggle.BackgroundColor3 = active and Color3.fromRGB(42, 150, 100) or Theme.Bar
                    card.State.Text = active and "Активно" or "Отключено"
                end

                local function addFeature(id, prompt, isRestored)
                    local def = FeatureDefs[id]
                    if not def then return end
                    local key = id .. "_" .. tostring(#list:GetChildren()) .. "_" .. tostring(math.floor(os.clock() * 1000))
                    local frame = New("Frame", {
                        Name = "Feature_" .. id,
                        Size = UDim2.new(1, -2, 0, 70),
                        BackgroundColor3 = Theme.Surface,
                        BorderSizePixel = 0,
                        Parent = list
                    })
                    round(frame, 10)
                    local stroke = New("UIStroke", {
                        Color = Theme.Accent,
                        Thickness = 1,
                        Transparency = 1,
                        Parent = frame
                    })

                    New("TextLabel", {
                        Position = UDim2.new(0, 9, 0, 7),
                        Size = UDim2.new(1, -92, 0, 24),
                        BackgroundTransparency = 1,
                        Text = def.Icon .. "  " .. def.Name,
                        TextColor3 = Theme.Text,
                        Font = Theme.FontBold,
                        TextSize = 14,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = frame
                    })
                    local state = New("TextLabel", {
                        Position = UDim2.new(0, 9, 0, 34),
                        Size = UDim2.new(1, -92, 0, 20),
                        BackgroundTransparency = 1,
                        Text = "Отключено",
                        TextColor3 = Theme.Muted,
                        Font = Theme.Font,
                        TextSize = 11,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = frame
                    })
                    local toggle = New("TextButton", {
                        AnchorPoint = Vector2.new(1, 0.5),
                        Position = UDim2.new(1, -8, 0.5, 0),
                        Size = UDim2.fromOffset(70, 34),
                        BackgroundColor3 = Theme.Bar,
                        BorderSizePixel = 0,
                        Text = "ВЫКЛ",
                        TextColor3 = Theme.Text,
                        Font = Theme.FontBold,
                        TextSize = 12,
                        Parent = frame
                    })
                    round(toggle, 9)

                    local selectButton = New("TextButton", {
                        Size = UDim2.fromScale(1, 1),
                        BackgroundTransparency = 1,
                        Text = "",
                        Parent = frame
                    })
                    selectButton.ZIndex = 1
                    toggle.ZIndex = 2

                    entries[id] = {
                        Frame = frame,
                        SelectStroke = stroke,
                        Toggle = toggle,
                        State = state,
                        Prompt = prompt,
                        Key = key
                    }

                    selectButton.Activated:Connect(function()
                        selectedId = id
                        refreshSelection()
                    end)

                    toggle.Activated:Connect(function()
                        local nextState = not (engine.Active[id] == true)
                        local ok, err = engine:Set(id, nextState)
                        if ok then
                            refreshCard(id)
                            setStatus(def.Name .. (nextState and " включено." or " выключено."))
                        else
                            setStatus(err or "Не удалось переключить функцию.", true)
                        end
                    end)

                    if isRestored then
                        selectedId = id
                    end
                    refreshCard(id)
                    refreshSelection()
                end

                local function createFromPrompt(prompt, silent)
                    local found = parsePrompt(prompt)
                    local count, duplicates, removed = 0, 0, 0
                    createBtn.Text = "✦ Создать функции"

                    -- Редактирование действительно заменяет старое намерение:
                    -- если новая формулировка больше не распознаёт прежнюю функцию, она удаляется.
                    local oldEditingId = editingId
                    if oldEditingId then
                        if found[oldEditingId] and entries[oldEditingId] then
                            entries[oldEditingId].Prompt = prompt
                            local wasActive = engine.Active[oldEditingId] == true
                            if not wasActive then
                                local ok, err = engine:Set(oldEditingId, true)
                                if ok then count = count + 1
                                elseif not silent then setStatus("Не удалось применить изменение: " .. tostring(err), true) end
                            else
                                count = count + 1
                            end
                            for _, item in ipairs(saved) do
                                if item.id == oldEditingId then item.prompt = prompt end
                            end
                        elseif entries[oldEditingId] then
                            engine:Set(oldEditingId, false)
                            entries[oldEditingId].Frame:Destroy()
                            entries[oldEditingId] = nil
                            for i = #saved, 1, -1 do
                                if saved[i].id == oldEditingId then table.remove(saved, i) end
                            end
                            if selectedId == oldEditingId then selectedId = nil end
                            removed = removed + 1
                        end
                        editingId = nil
                        retryingId = nil
                        refreshSelection()
                    end

                    for id in pairs(found) do
                        if id ~= oldEditingId then
                            if entries[id] then
                                duplicates = duplicates + 1
                            else
                                addFeature(id, prompt, false)
                                count = count + 1
                            end
                        end
                    end

                    if oldEditingId then writeSaved(saved) end
                    if count == 0 then
                        if removed > 0 then
                            if not silent then setStatus("Старое пожелание удалено. Новых функций в запросе не найдено.") end
                            return true
                        end
                        if not silent then
                            if duplicates > 0 then
                                setStatus("Такие функции уже добавлены. Новые дубликаты не создавались.")
                            else
                                setStatus("Пока не понял желание. Попробуй описать результат другими словами — я учитываю опечатки и похожие формулировки.", true)
                            end
                        end
                        return duplicates > 0
                    end
                    if not silent then
                        local message = "Готово: " .. tostring(count) .. " функций."
                        if duplicates > 0 then message = message .. " Уже существующих: " .. tostring(duplicates) .. "." end
                        if removed > 0 then message = message .. " Удалено прежних: " .. tostring(removed) .. "." end
                        setStatus(message .. " Переключатели готовы.")
                    end
                    return true
                end

                createBtn.Activated:Connect(function()
                    local prompt = tostring(promptBox.Text or "")
                    if prompt:gsub("%s", "") == "" then
                        setStatus("Сначала напиши, что нужно создать или что работает неправильно.", true)
                        return
                    end
                    if retryingId and entries[retryingId] then
                        local id = retryingId
                        local ok, err = engine:Repair(id, prompt)
                        retryingId = nil
                        editingId = nil
                        promptBox.PlaceholderText = "Например: полёт + ускорение + высокий прыжок"
                        createBtn.Text = "✦ Создать функции"
                        if ok then
                            refreshCard(id)
                            setStatus("Описание учтено. Функция повторно настроена: " .. FeatureDefs[id].Name)
                        else
                            setStatus("Не удалось исправить: " .. tostring(err), true)
                        end
                        promptBox.Text = ""
                        return
                    end
                    createFromPrompt(prompt, false)
                end)

                local function getSelected()
                    if not selectedId or not entries[selectedId] then
                        setStatus("Сначала выбери функцию в списке.", true)
                        return nil
                    end
                    return selectedId, entries[selectedId]
                end

                local deleteBtn = New("TextButton", {
                    BackgroundColor3 = Theme.Danger,
                    BorderSizePixel = 0,
                    Text = "🗑 Удалить",
                    TextColor3 = Color3.new(1, 1, 1),
                    Font = Theme.FontBold,
                    TextSize = 12,
                    Parent = actionRow
                })
                round(deleteBtn, 8)
                deleteBtn.Activated:Connect(function()
                    local id = getSelected()
                    if not id then return end
                    engine:Set(id, false)
                    entries[id].Frame:Destroy()
                    entries[id] = nil
                    for i = #saved, 1, -1 do
                        if type(saved[i]) == "table" and saved[i].id == id then
                            table.remove(saved, i)
                        end
                    end
                    writeSaved(saved)
                    selectedId = nil
                    refreshSelection()
                    setStatus("Функция удалена из списка и сохранений.")
                end)

                local saveBtn = New("TextButton", {
                    BackgroundColor3 = Theme.Bar,
                    BorderSizePixel = 0,
                    Text = "📁 Сохранить",
                    TextColor3 = Theme.Text,
                    Font = Theme.FontBold,
                    TextSize = 12,
                    Parent = actionRow
                })
                round(saveBtn, 8)
                saveBtn.Activated:Connect(function()
                    local id, entry = getSelected()
                    if not id then return end
                    local found = false
                    for _, item in ipairs(saved) do
                        if item.id == id then
                            item.prompt = entry.Prompt
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(saved, { id = id, prompt = entry.Prompt })
                    end
                    local ok, err = writeSaved(saved)
                    if ok then
                        setStatus("Сохранено и проверено. Функция восстановится при следующем запуске.")
                    else
                        setStatus("Сохранено только до закрытия. " .. tostring(err), true)
                    end
                end)

                local retryBtn = New("TextButton", {
                    BackgroundColor3 = Theme.Bar,
                    BorderSizePixel = 0,
                    Text = "🔁 Повторить",
                    TextColor3 = Theme.Text,
                    Font = Theme.FontBold,
                    TextSize = 12,
                    Parent = actionRow
                })
                round(retryBtn, 8)
                retryBtn.Activated:Connect(function()
                    local id, entry = getSelected()
                    if not id then return end
                    promptBox.Text = ""
                    promptBox.PlaceholderText = "Что не так с функцией? Опиши проблему..."
                    editingId = id
                    retryingId = id
                    createBtn.Text = "✦ Исправить функцию"
                    setStatus("Опиши проблему и нажми «Исправить функцию». Reality Brain выберет доступный способ повторной настройки.")
                end)

                local editBtn = New("TextButton", {
                    BackgroundColor3 = Theme.Bar,
                    BorderSizePixel = 0,
                    Text = "🔂 Изменить запрос",
                    TextColor3 = Theme.Text,
                    Font = Theme.FontBold,
                    TextSize = 12,
                    Parent = actionRow
                })
                round(editBtn, 8)
                editBtn.Activated:Connect(function()
                    local id, entry = getSelected()
                    if not id then return end
                    retryingId = nil
                    promptBox.PlaceholderText = "Например: полёт + ускорение + высокий прыжок"
                    createBtn.Text = "✦ Создать функции"
                    promptBox.Text = entry.Prompt or ""
                    editingId = id
                    setStatus("Измени текст сверху и нажми «Создать функции».")
                end)

                -- Восстанавливаем сохранённые запросы один раз за сессию.
                if not restored then
                    restored = true
                    for _, item in ipairs(saved) do
                        if type(item) == "table" and type(item.prompt) == "string" and FeatureDefs[item.id] then
                            createFromPrompt(item.prompt, true)
                        end
                    end
                    if #saved > 0 then
                        setStatus("Сохранённые функции восстановлены. Включи нужные переключатели.")
                    end
                end

                if not next(entries) then
                    setStatus("Напиши, каким ты хочешь видеть свой мир. Можно обычными словами — не обязательно знать название эффекта.")
                end
            end
        })
    end

    local registered = registerApp()
    if registered then
        print("[Reality Modifier] Приложение установлено. Открой его на главном экране Prompt Phone.")
    else
        warn("[Reality Modifier] Не удалось зарегистрировать приложение.")
    end

    -- При выгрузке модуля все эффекты выключаются.
    Phone.Modules:Register("RealityModifierEngine", function()
        return function()
            engine:Destroy()
            pcall(function()
                Phone.Apps:Unregister("reality_modifier")
            end)
        end
    end)
end
