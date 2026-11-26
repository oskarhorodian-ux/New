--[[
	PROMPT PHONE v1.0 — PART 1: CORE
	Виртуальный смартфон для Roblox (Luau). Запуск: Delta Executor (Android).

	Содержит только ядро:
	  1. Config / Theme / утилиты (Signal, Maid, New, tween, drag)
	  2. WindowManager  — окна: открыть / закрыть / свернуть / переместить / несколько окон
	  3. Apps           — реестр приложений (Id, Name, Icon, OnOpen, OnClose, свой Window)
	  4. Modules        — подключение будущих модулей без правки ядра
	  5. Shell          — окно телефона (домашний экран + список открытых окон)
	  6. API / Boot     — публичный объект PromptPhone, корректная перезагрузка

	Публичный API после запуска: getgenv().PromptPhone
	Приложений в ядре НЕТ — домашний экран пуст, пока не подключён модуль.
]]

------------------------------------------------------------------
-- 0. КОНФИГ И СЕРВИСЫ
------------------------------------------------------------------
local CONFIG = {
	Name = "Prompt Phone",
	Version = "1.0.0-core",
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
-- Будущие модули (не реализованы): YouTube, PromptBrowser, Camera, Gallery,
-- Game Launcher, Prompt Translate, Prompt Voice Translate.

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

    function FeatureEngine:Set(id, enabled)
        if id == "fly" then
            if enabled then
                local ok, err = self:StartFly()
                if not ok then return false, err end
            else
                self:StopFly()
            end
        elseif id == "noclip" then
            if enabled then
                local ok, err = self:StartNoclip()
                if not ok then return false, err end
            else
                self:StopNoclip()
            end
        else
            return false, "Такой функции пока нет в библиотеке."
        end
        self.Active[id] = enabled == true
        return true
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
                    local horizontal = Vector3.zero
                    if move.Magnitude > 0.05 then
                        horizontal = move.Unit * 55
                    end

                    local vertical = 0
                    if UserInputService:IsKeyDown(Enum.KeyCode.E) then
                        vertical = 42
                    elseif UserInputService:IsKeyDown(Enum.KeyCode.Q) then
                        vertical = -42
                    elseif os.clock() < self.AscendUntil then
                        vertical = 42
                    end

                    bv.Velocity = Vector3.new(horizontal.X, vertical, horizontal.Z)
                    bg.CFrame = camera.CFrame
                end
            end
        end)

        self.JumpConnection = UserInputService.JumpRequest:Connect(function()
            if self.Fly then
                self.AscendUntil = os.clock() + 0.28
            end
        end)
    end

    function FeatureEngine:Destroy()
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
    local FeatureDefs = {
        fly = {
            Id = "fly",
            Name = "Полёт",
            Icon = "✈️",
            Description = "Движение в воздухе. На телефоне — джойстик и кнопка прыжка.",
            Match = {
                "полет", "летать", "летаю", "fly", "flying", "flight"
            }
        },
        noclip = {
            Id = "noclip",
            Name = "Проход сквозь стены",
            Icon = "👻",
            Description = "Отключает столкновения частей персонажа.",
            Match = {
                "сквозь стены", "проходить сквозь", "проходить через",
                "ноклип", "noclip", "no clip", "проходить стены"
            }
        }
    }

    local function normalize(s)
        s = string.lower(tostring(s or ""))
        s = s:gsub("ё", "е")
        return s
    end

    local function parsePrompt(prompt)
        local text = normalize(prompt)
        local found = {}
        for id, def in pairs(FeatureDefs) do
            for _, phrase in ipairs(def.Match) do
                if string.find(text, normalize(phrase), 1, true) then
                    found[id] = true
                    break
                end
            end
        end
        return found
    end

    ------------------------------------------------------------------
    -- СОХРАНЕНИЕ
    ------------------------------------------------------------------
    local function readSaved()
        if type(readfile) ~= "function" or type(isfile) ~= "function" then
            return {}
        end
        local ok, exists = pcall(isfile, SAVE_PATH)
        if not ok or not exists then return {} end
        local okRead, raw = pcall(readfile, SAVE_PATH)
        if not okRead or type(raw) ~= "string" then return {} end
        local okJson, data = pcall(function()
            return HttpService:JSONDecode(raw)
        end)
        if okJson and type(data) == "table" then return data end
        return {}
    end

    local function writeSaved(data)
        if type(writefile) ~= "function" then
            return false, "В этом executor нет writefile."
        end
        if type(makefolder) == "function" then
            pcall(makefolder, "PromptPhone")
        end
        local ok, err = pcall(function()
            writefile(SAVE_PATH, HttpService:JSONEncode(data))
        end)
        return ok, err
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
                    Text = "Введи запрос. Доступны: полёт и прохождение сквозь стены.",
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
                    local count = 0
                    for id in pairs(found) do
                        if entries[id] then
                            if editingId == id then
                                entries[id].Prompt = prompt
                                count = count + 1
                            end
                        else
                            addFeature(id, prompt, false)
                            count = count + 1
                        end
                    end
                    if editingId then
                        local stillPresent = found[editingId] == true
                        if not stillPresent and entries[editingId] then
                            engine:Set(editingId, false)
                            entries[editingId].Frame:Destroy()
                            entries[editingId] = nil
                            selectedId = nil
                        end
                        editingId = nil
                        refreshSelection()
                    end
                    if count == 0 then
                        if not silent then
                            setStatus("Не распознал функцию. Сейчас доступны: полёт, проход сквозь стены.", true)
                        end
                        return false
                    end
                    if not silent then
                        setStatus("Создано функций: " .. tostring(count) .. ". Выбери переключатель ниже.")
                    end
                    return true
                end

                createBtn.Activated:Connect(function()
                    local prompt = tostring(promptBox.Text or "")
                    if prompt:gsub("%s", "") == "" then
                        setStatus("Сначала напиши, что нужно создать.", true)
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
                        setStatus("Сохранено. Функция восстановится при следующем запуске.")
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
                    local ok, err = engine:Set(id, true)
                    if ok then
                        refreshCard(id)
                        setStatus("Повторная активация выполнена.")
                    else
                        setStatus("Повтор не удался: " .. tostring(err), true)
                    end
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
                    promptBox.Text = entry.Prompt or ""
                    editingId = id
                    setStatus("Измени текст сверху и нажми «Создать функции».")
                end)

                -- Восстанавливаем сохранённые запросы один раз за сессию.
                if not restored then
                    restored = true
                    for _, item in ipairs(saved) do
                        if type(item) == "table" and type(item.prompt) == "string" then
                            createFromPrompt(item.prompt, true)
                        end
                    end
                    if #saved > 0 then
                        setStatus("Сохранённые функции восстановлены. Включи нужные переключатели.")
                    end
                end

                if not next(entries) then
                    setStatus("Пока пусто. Попробуй: «полёт + проходить сквозь стены».")
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
