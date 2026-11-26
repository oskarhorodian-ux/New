--[[
  Prompt Phone: Camera + Gallery  (прототип v0.1)
  Платформа: Roblox Luau, Delta Executor (Android), ScreenGui, сенсорное управление.

  ЧЕСТНО О СКРИНШОТАХ:
  * У Delta/UNC НЕТ функции "скриншот экрана". Её здесь не выдумываем.
  * Настоящий снимок даёт официальный Roblox-сервис CaptureService:CaptureScreenshot().
    Он возвращает временный ID (rbxtemp://...), живущий до выхода из игры.
  * Постоянное сохранение в файл возможно ТОЛЬКО если Roblox позволит прочитать
    пиксели снимка (EditableImage). Это зависит от версии клиента и прав - скрипт
    пробует это в рантайме и честно сообщает результат.
  * Запасные пути: кнопка "в Roblox Gallery" (официальный диалог сохранения)
    и показ файлов .png/.jpg из папки PromptPhone_Photos (скриншоты Android,
    скопированные туда вручную).

  НИЧЕГО не подменяется картинками-заглушками. Если снимок не получен - будет ошибка.
]]

----------------------------------------------------------------------
-- Сервисы и проверка доступных функций
----------------------------------------------------------------------
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local AssetService = game:GetService("AssetService")

local okCS, CaptureService = pcall(function() return game:GetService("CaptureService") end)
if not okCS then CaptureService = nil end

local FOLDER = "PromptPhone_Photos"

local hasFS = type(writefile) == "function" and type(readfile) == "function"
	and type(listfiles) == "function" and type(delfile) == "function"
	and type(isfile) == "function" and type(isfolder) == "function"
	and type(makefolder) == "function"

if hasFS then
	pcall(function()
		if not isfolder(FOLDER) then makefolder(FOLDER) end
	end)
end

local sessionPhotos = {} -- снимки, которые не удалось записать в файл (живут до выхода)
local counter = 0

----------------------------------------------------------------------
-- Мелкие помощники UI
----------------------------------------------------------------------
local C = {
	bg = Color3.fromRGB(16, 16, 20),
	panel = Color3.fromRGB(28, 28, 34),
	btn = Color3.fromRGB(0, 122, 255),
	red = Color3.fromRGB(200, 55, 55),
	grey = Color3.fromRGB(60, 60, 70),
	text = Color3.fromRGB(240, 240, 245),
	dim = Color3.fromRGB(150, 150, 160),
}

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function label(parent, text, pos, size, color)
	local l = make("TextLabel", {
		Text = text, Position = pos, Size = size, BackgroundTransparency = 1,
		TextColor3 = color or C.text, Font = Enum.Font.Gotham, TextScaled = true,
		TextWrapped = true,
	}, parent)
	make("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 8 }, l)
	return l
end

local function button(parent, text, pos, size, color)
	local b = make("TextButton", {
		Text = text, Position = pos, Size = size, BackgroundColor3 = color or C.btn,
		TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamMedium,
		TextScaled = true, BorderSizePixel = 0, AutoButtonColor = true,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, b)
	make("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 8 }, b)
	return b
end

----------------------------------------------------------------------
-- Корневой ScreenGui + рамка телефона
----------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "PP_CameraGallery", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local function mountGui()
	local okH, parent = pcall(function() return type(gethui) == "function" and gethui() or nil end)
	if okH and parent then
		pcall(function() gui.Parent = parent end)
	end
	if not gui.Parent then
		pcall(function() gui.Parent = CoreGui end)
	end
	if not gui.Parent then
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
end

-- убрать прошлую копию при повторном запуске
for _, root in ipairs({ CoreGui, Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") }) do
	if root then
		local old = root:FindFirstChild("PP_CameraGallery")
		if old then old:Destroy() end
	end
end
mountGui()

local phone = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.5, 0.94), BackgroundColor3 = C.bg, BorderSizePixel = 0,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 18) }, phone)
make("UIAspectRatioConstraint", {
	AspectRatio = 0.56, DominantAxis = Enum.DominantAxis.Height,
}, phone)

-- уведомление (toast)
local toastFrame = make("Frame", {
	Position = UDim2.fromScale(0.03, 0.012), Size = UDim2.fromScale(0.94, 0.085),
	BackgroundColor3 = C.panel, BorderSizePixel = 0, Visible = false, ZIndex = 50,
}, phone)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, toastFrame)
local toastText = label(toastFrame, "", UDim2.fromScale(0.03, 0.05), UDim2.fromScale(0.94, 0.9))
toastText.ZIndex = 51
local toastToken = 0
local function toast(msg, isError)
	toastToken = toastToken + 1
	local my = toastToken
	toastText.Text = msg
	toastText.TextColor3 = isError and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(120, 230, 140)
	toastFrame.Visible = true
	task.delay(isError and 6 or 3.5, function()
		if toastToken == my then toastFrame.Visible = false end
	end)
end

local content = make("Frame", {
	Position = UDim2.fromScale(0, 0.1), Size = UDim2.fromScale(1, 0.78),
	BackgroundTransparency = 1,
}, phone)
local camPage = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, content)
local galPage = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, content)

local galleryRefresh = function() end -- заполняется ниже

local function showPage(which)
	camPage.Visible = (which == "cam")
	galPage.Visible = (which == "gal")
	if which == "gal" then galleryRefresh() end
end

local nav = make("Frame", {
	Position = UDim2.fromScale(0, 0.89), Size = UDim2.fromScale(1, 0.1),
	BackgroundTransparency = 1,
}, phone)
local navCam = button(nav, "📸 Camera", UDim2.fromScale(0.03, 0), UDim2.fromScale(0.4, 1), C.grey)
local navGal = button(nav, "🖼️ Gallery", UDim2.fromScale(0.45, 0), UDim2.fromScale(0.34, 1), C.grey)
local navClose = button(nav, "✕", UDim2.fromScale(0.81, 0), UDim2.fromScale(0.16, 1), C.red)
navCam.Activated:Connect(function() showPage("cam") end)
navGal.Activated:Connect(function() showPage("gal") end)
navClose.Activated:Connect(function() gui:Destroy() end)

----------------------------------------------------------------------
-- Работа с файлами / EditableImage
----------------------------------------------------------------------
local function isBlank(buf)
	local n = buffer.len(buf)
	if n == 0 then return true end
	for i = 0, n - 1, 61 do
		if buffer.readu8(buf, i) ~= 0 then return false end
	end
	return true
end

-- Пытается превратить снимок (rbxtemp://) в пиксели и записать файл. Бросает error при неудаче.
local function persistRaw(id, name)
	if not hasFS then error("нет filesystem API у executor", 0) end

	local ei
	local ok1, r1 = pcall(function() return AssetService:CreateEditableImageAsync(Content.fromUri(id)) end)
	if ok1 and r1 then
		ei = r1
	else
		local ok2, r2 = pcall(function() return AssetService:CreateEditableImageAsync(id) end)
		if ok2 and r2 then
			ei = r2
		else
			error("Roblox не даёт прочитать пиксели снимка: " .. tostring(r2 or r1), 0)
		end
	end

	local okAll, errAll = pcall(function()
		local sz = ei.Size
		local maxW = 512
		if sz.X > maxW then
			ei:Resize(Vector2.new(maxW, math.max(1, math.floor(maxW * sz.Y / sz.X))))
			sz = ei.Size
		end
		if sz.X > 1024 or sz.Y > 1024 then error("размер снимка превышает лимит 1024", 0) end

		local buf = ei:ReadPixelsBuffer(Vector2.new(0, 0), sz)
		if isBlank(buf) then error("снимок пустой - не сохраняю", 0) end

		local data = string.format("PPRAW1 %d %d\n", sz.X, sz.Y) .. buffer.tostring(buf)
		local path = FOLDER .. "/" .. name .. ".ppraw"
		writefile(path, data)

		-- проверка, что файл реально записан
		if not isfile(path) or #readfile(path) ~= #data then
			pcall(delfile, path)
			error("файл не записался корректно", 0)
		end
	end)
	pcall(function() ei:Destroy() end)
	if not okAll then error(tostring(errAll), 0) end
end

local function decodeRaw(path)
	local data = readfile(path)
	local nl = data:find("\n", 1, true)
	if not nl then error("повреждённый файл", 0) end
	local w, h = data:sub(1, nl - 1):match("^PPRAW1 (%d+) (%d+)$")
	w, h = tonumber(w), tonumber(h)
	if not w or not h then error("неизвестный формат файла", 0) end
	local px = data:sub(nl + 1)
	if #px ~= w * h * 4 then error("размер данных не совпадает", 0) end
	local ei = AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
	ei:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(w, h), buffer.fromstring(px))
	return ei
end

local function showEditable(imgLabel, ei)
	local ok = pcall(function() imgLabel.ImageContent = Content.fromObject(ei) end)
	if not ok then
		local ok2 = pcall(function() ei.Parent = imgLabel end)
		if not ok2 then error("не удалось показать EditableImage в этой версии Roblox", 0) end
	end
end

----------------------------------------------------------------------
-- CAMERA
----------------------------------------------------------------------
local preview = make("ImageLabel", {
	Position = UDim2.fromScale(0.04, 0.02), Size = UDim2.fromScale(0.92, 0.6),
	BackgroundColor3 = C.panel, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit,
	Image = "",
}, camPage)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, preview)
local previewHint = label(preview, "Здесь появится реальный снимок", UDim2.fromScale(0.1, 0.4),
	UDim2.fromScale(0.8, 0.2), C.dim)

local modeText = hasFS
	and ("💾 Файлы: " .. FOLDER .. " (если Roblox разрешит чтение пикселей)")
	or "⚠ У executor нет filesystem API: снимки живут только до выхода из игры"
if not CaptureService then modeText = "❌ CaptureService недоступен: снимок сделать нельзя" end
label(camPage, modeText, UDim2.fromScale(0.04, 0.64), UDim2.fromScale(0.92, 0.12), C.dim)

local shutter = button(camPage, "📸", UDim2.fromScale(0.35, 0.78), UDim2.fromScale(0.3, 0.2), Color3.fromRGB(235, 235, 240))
shutter.TextColor3 = Color3.fromRGB(20, 20, 20)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, shutter)
make("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }, shutter)

local saveBtn = button(camPage, "→ Roblox\nGallery", UDim2.fromScale(0.7, 0.79), UDim2.fromScale(0.27, 0.17), C.grey)
saveBtn.Visible = false

local lastId = nil
local busy = false

local function savePromptFor(id)
	if not CaptureService then toast("CaptureService недоступен", true) return end
	local ok, err = pcall(function()
		CaptureService:PromptSaveCapturesToGallery({ id }, function(results)
			local v = type(results) == "table" and results[id] or nil
			local good = (v == true) or (v ~= nil and tostring(v):find("Success") ~= nil)
			if good then
				toast("✅ Сохранено в галерею Roblox")
			else
				toast("Roblox не подтвердил сохранение (отмена или ошибка)", true)
			end
		end)
	end)
	if not ok then toast("Не удалось открыть диалог сохранения: " .. tostring(err), true) end
end
saveBtn.Activated:Connect(function() if lastId then savePromptFor(lastId) end end)

local function onCaptured(id)
	if type(id) ~= "string" or id == "" then
		toast("Roblox вернул пустой снимок - ничего не сохранено", true)
		busy = false
		shutter.Text = "📸"
		return
	end
	counter = counter + 1
	local name = string.format("photo_%d_%03d", os.time(), counter)
	lastId = id
	previewHint.Visible = false
	preview.Image = id
	saveBtn.Visible = true

	local ok, err = pcall(persistRaw, id, name)
	if ok then
		toast("✅ Фото сохранено в файл: " .. name .. ".ppraw")
	else
		table.insert(sessionPhotos, { kind = "temp", id = id, name = name .. " (сессия)" })
		toast("⚠ Снимок сделан, но в файл не сохранён: " .. tostring(err)
			.. ". Он есть в Gallery до выхода из игры.", true)
	end
	busy = false
	shutter.Text = "📸"
	galleryRefresh()
end

local function takePhoto()
	if busy then return end
	if not CaptureService then toast("CaptureService недоступен", true) return end
	busy = true
	shutter.Text = "…"

	gui.Enabled = false -- прячем телефон, чтобы он не попал в кадр
	task.wait(0.25)

	local done = false
	local function finish(id)
		if done then return end
		done = true
		gui.Enabled = true
		task.spawn(onCaptured, id)
	end

	local ok, err = pcall(function()
		CaptureService:CaptureScreenshot(function(id) finish(id) end)
	end)
	if not ok then
		done = true
		gui.Enabled = true
		busy = false
		shutter.Text = "📸"
		toast("Ошибка захвата: " .. tostring(err), true)
		return
	end

	task.delay(6, function()
		if not done then
			done = true
			gui.Enabled = true
			busy = false
			shutter.Text = "📸"
			toast("Таймаут: Roblox не вернул снимок", true)
		end
	end)
end
shutter.Activated:Connect(takePhoto)

----------------------------------------------------------------------
-- GALLERY
----------------------------------------------------------------------
local galHeader = label(galPage, "Фото: 0", UDim2.fromScale(0.04, 0), UDim2.fromScale(0.55, 0.07), C.text)
galHeader.TextXAlignment = Enum.TextXAlignment.Left
local refreshBtn = button(galPage, "⟳ Обновить", UDim2.fromScale(0.62, 0), UDim2.fromScale(0.34, 0.07), C.grey)

local list = make("ScrollingFrame", {
	Position = UDim2.fromScale(0.04, 0.09), Size = UDim2.fromScale(0.92, 0.9),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
	CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, galPage)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local emptyLabel = label(galPage, "", UDim2.fromScale(0.1, 0.4), UDim2.fromScale(0.8, 0.2), C.dim)

-- просмотр
local viewer = make("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BorderSizePixel = 0,
	Visible = false, ZIndex = 10,
}, galPage)
local vImg = make("ImageLabel", {
	Position = UDim2.fromScale(0.04, 0.08), Size = UDim2.fromScale(0.92, 0.72),
	BackgroundColor3 = C.panel, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Fit,
	ZIndex = 11,
}, viewer)
local vTitle = label(viewer, "", UDim2.fromScale(0.04, 0), UDim2.fromScale(0.92, 0.07), C.dim)
vTitle.ZIndex = 11
local vErr = label(viewer, "", UDim2.fromScale(0.1, 0.35), UDim2.fromScale(0.8, 0.2), Color3.fromRGB(255, 120, 120))
vErr.ZIndex = 12
vErr.Visible = false
local vClose = button(viewer, "Закрыть", UDim2.fromScale(0.04, 0.84), UDim2.fromScale(0.28, 0.14), C.grey)
local vDelete = button(viewer, "🗑 Удалить", UDim2.fromScale(0.35, 0.84), UDim2.fromScale(0.3, 0.14), C.red)
local vRoblox = button(viewer, "→ Roblox", UDim2.fromScale(0.68, 0.84), UDim2.fromScale(0.28, 0.14), C.btn)
vClose.ZIndex, vDelete.ZIndex, vRoblox.ZIndex = 11, 11, 11

local currentEI, currentEntry, armed = nil, nil, false

local function clearViewerImage()
	if currentEI then pcall(function() currentEI:Destroy() end) currentEI = nil end
	vImg.Image = ""
	pcall(function() vImg.ImageContent = Content.none end)
end

local function listEntries()
	local out = {}
	for _, e in ipairs(sessionPhotos) do table.insert(out, e) end
	if hasFS then
		local ok, files = pcall(listfiles, FOLDER)
		if ok and type(files) == "table" then
			for _, p in ipairs(files) do
				local name = tostring(p):match("[^/\\]+$") or tostring(p)
				local ext = (name:match("%.(%w+)$") or ""):lower()
				local kind = (ext == "ppraw" and "raw")
					or ((ext == "png" or ext == "jpg" or ext == "jpeg") and "img") or nil
				if kind then
					table.insert(out, { kind = kind, path = FOLDER .. "/" .. name, name = name })
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.name > b.name end)
	return out
end

local function openViewer(entry)
	clearViewerImage()
	currentEntry = entry
	armed = false
	vDelete.Text = "🗑 Удалить"
	vTitle.Text = entry.name
	vErr.Visible = false
	vRoblox.Visible = (entry.kind == "temp")
	viewer.Visible = true

	local ok, err = pcall(function()
		if entry.kind == "temp" then
			vImg.Image = entry.id
		elseif entry.kind == "img" then
			if type(getcustomasset) ~= "function" then error("нет getcustomasset у executor", 0) end
			vImg.Image = getcustomasset(entry.path)
		else
			currentEI = decodeRaw(entry.path)
			showEditable(vImg, currentEI)
		end
	end)
	if not ok then
		vErr.Text = "Не удалось открыть: " .. tostring(err)
		vErr.Visible = true
	end
end

galleryRefresh = function()
	for _, ch in ipairs(list:GetChildren()) do
		if ch:IsA("GuiObject") then ch:Destroy() end
	end
	local entries = listEntries()
	galHeader.Text = "Фото: " .. #entries
	if #entries == 0 then
		emptyLabel.Text = hasFS
			and "Фотографий пока нет. Сделайте снимок в Camera."
			or "Фотографий нет (filesystem API недоступен, показываются только снимки сессии)."
		emptyLabel.Visible = true
	else
		emptyLabel.Visible = false
	end

	for i, e in ipairs(entries) do
		local row = make("TextButton", {
			Size = UDim2.new(1, -6, 0, 56), BackgroundColor3 = C.panel, BorderSizePixel = 0,
			Text = "", LayoutOrder = i, AutoButtonColor = true,
		}, list)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, row)

		local thumb = make("ImageLabel", {
			Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(0, 48, 0, 48),
			BackgroundColor3 = C.bg, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop,
		}, row)
		if e.kind == "temp" then
			thumb.Image = e.id
		elseif e.kind == "img" and type(getcustomasset) == "function" then
			pcall(function() thumb.Image = getcustomasset(e.path) end)
		else
			make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
				Text = "🖼️", TextScaled = true, TextColor3 = C.dim }, thumb)
		end

		local nameL = make("TextLabel", {
			Position = UDim2.new(0, 60, 0, 4), Size = UDim2.new(1, -66, 1, -8),
			BackgroundTransparency = 1, Text = e.name, TextColor3 = C.text,
			Font = Enum.Font.Gotham, TextScaled = true, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		make("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 8 }, nameL)

		row.Activated:Connect(function() openViewer(e) end)
	end
end
refreshBtn.Activated:Connect(function() galleryRefresh() toast("Список обновлён") end)

vClose.Activated:Connect(function()
	viewer.Visible = false
	clearViewerImage()
	currentEntry = nil
end)

vRoblox.Activated:Connect(function()
	if currentEntry and currentEntry.kind == "temp" then savePromptFor(currentEntry.id) end
end)

vDelete.Activated:Connect(function()
	if not currentEntry then return end
	if not armed then
		armed = true
		vDelete.Text = "Точно удалить?"
		task.delay(3, function()
			if armed and currentEntry then armed = false vDelete.Text = "🗑 Удалить" end
		end)
		return
	end
	armed = false

	local e = currentEntry
	local deleted = false
	if e.kind == "temp" then
		for i, s in ipairs(sessionPhotos) do
			if s == e then table.remove(sessionPhotos, i) deleted = true break end
		end
	else
		local ok = pcall(delfile, e.path)
		deleted = ok and not isfile(e.path)
	end

	if deleted then
		viewer.Visible = false
		clearViewerImage()
		currentEntry = nil
		toast("🗑 Фото удалено")
		galleryRefresh()
	else
		vDelete.Text = "🗑 Удалить"
		toast("Не удалось удалить файл", true)
	end
end)

----------------------------------------------------------------------
-- Старт
----------------------------------------------------------------------
showPage("cam")
toast(CaptureService and "Camera + Gallery готовы" or "CaptureService недоступен", not CaptureService)

-- для интеграции в Prompt Phone: getgenv().PP_CameraGallery.ShowCamera() / .ShowGallery()
pcall(function()
	getgenv().PP_CameraGallery = {
		ShowCamera = function() gui.Enabled = true showPage("cam") end,
		ShowGallery = function() gui.Enabled = true showPage("gal") end,
		Gui = gui,
	}
end)
