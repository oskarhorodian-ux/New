-- v12.0 (резче: замах-замер-удар-hit-stop, лупа вбивается у игрока) | v11.0: резкие и жестокие анимации предметов (лупа -> зазубренная половина линзы вбивается в стол, отвёртка, пила режет дуло в руках, телефон: камера + слушает + разбивает + на пол, таблетки, сигареты, наручники, адреналин), новые реакции Дилера, исправлена камера у телефона
-- v10.0: стиль ближе к оригиналу: лупа разбивается и вбивается в стол, отвёртка вместо пива, новый реверсер, банка таблеток (HP меняется после проглатывания), надетые наручники с рывками и поломкой, раунд на экране справа, Дилер сам заряжает дробовик и отлетает в темноту при попадании
-- v9.0: УЛУЧШЕНИЯ (основа не тронута): висячая лампа с мотыльками, свеча и пепельница с дымом, туман, пинок камеры и ударные волны при выстреле, баннеры предметов и ходов, детали на всех 9 предметах и дробовике, вспышки предметов, лечение с эффектом, пульс/сердцебиение на последнем HP, счётчик патронов
-- v8.7: после финала (череп) чемодан выезжает -> «ЗАБРАТЬ ДЕНЬГИ» -> ночная машина с дробовиком и чемоданом + статистика забега
-- BLOX ROULETTE 3D v8 (+ главное меню, дождь из патронов, магазин дробовиков и аксессуаров Дилера) | v7 (правки по баг-репорту: ячейки 4+4, табло как в оригинале, тесная комната) | v6: + Последний шанс / Сдаться / смерть в Роблоксе / награды / дилер улетает в темноту
-- НАЧАЛО ЧАСТИ 1А
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
math.randomseed(math.floor(os.clock() * 1000000) % 2147483647)
local parentGui = (gethui and gethui()) or CoreGui or player:WaitForChild("PlayerGui")

if parentGui:FindFirstChild("BloxRoulette3D") then
    parentGui.BloxRoulette3D:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BloxRoulette3D"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- весь UI рассчитан на Sibling; при Global меню (ZIndex 30) лежало ПОВЕРХ своих кнопок и глотало клики
ScreenGui.DisplayOrder = 10
ScreenGui.Parent = parentGui

local SOUNDS = {
    Shot = "rbxassetid://168143115",
    Blank = "rbxassetid://142082166",
    Rack = "rbxassetid://168143162",
    Saw = "rbxassetid://131072992",
    Heal = "rbxassetid://4612375233",
    Zap = "rbxassetid://4612375233", -- звук разряда после удара (поменяй ID на свой, если хочешь другой)
    Win = "rbxassetid://9114021242" -- 8-Bit Retro Win (в духе DOORS Thank You)
}

-- >>> МУЗЫКА <<<  Вставь сюда ID трека "General Release" (Mike Klubnika), например "rbxassetid://123456789".
-- Экран трясётся в такт реальной громкости этого звука. Пока ID пустой - музыки и тряски от неё нет.
local MUSIC_ID = ""
local MUSIC_VOLUME = 0.55
local MUSIC_SHAKE = 1.0 -- 1 = слегка, 2 = сильнее, 0 = выключить тряску

-- >>> МУЗЫКА ГЛАВНОГО МЕНЮ <<< Вставь ID самого мрачного эмбиента/хоррор-трека, например "rbxassetid://123456789".
-- Если пусто - в меню играет MUSIC_ID. Скрипт сам добавляет реверб, срез верхов и замедление, чтобы звучало ещё мрачнее.
local MENU_MUSIC_ID = ""
local MENU_MUSIC_VOLUME = 0.6

-- >>> ХАРДКОР И НАГРАДЫ <<<
local HARDCORE_DEATH = true       -- true: при проигрыше / «Сдаться» твой персонаж в Роблоксе умирает
local LAST_CHANCE_TIMEOUT = 0     -- таймер на «Последний шанс?» убран (0 = без таймера). Смерть только по кнопке «Сдаться»
local ROUND_REWARD = 50           -- монет за победу в раунде (x номер раунда)
local WIN_REWARD = 300            -- монет за победу в игре
local STREAK_BONUS = 0.25         -- +25% к награде за каждую победу в игре подряд
local DIRTY_FONT = Enum.Font.Code -- сюда можно вписать свой грязный шрифт (он должен уметь кириллицу)
shared.BloxRoulette = shared.BloxRoulette or {coins = 0, streak = 0, best = 0}
local Progress = shared.BloxRoulette

local function playSFX(soundId, pitch)
    task.spawn(function()
        pcall(function()
            local s = Instance.new("Sound", ScreenGui)
            s.SoundId = soundId
            s.Volume = 0.85
            s.PlaybackSpeed = pitch or 1
            s:Play()
            s.Ended:Connect(function() s:Destroy() end)
            task.delay(3, function() if s then s:Destroy() end end)
        end)
    end)
end
-- КОНЕЦ ЧАСТИ 1А
-- НАЧАЛО ЧАСТИ 1Б
local function makeDraggable(obj, handle)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, obj.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            obj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local MiniLauncher = Instance.new("Frame", ScreenGui)
MiniLauncher.Name = "PromtHackerLauncher"
MiniLauncher.Size = UDim2.new(0, 230, 0, 82)
MiniLauncher.Position = UDim2.new(0, 20, 0.5, -41)
MiniLauncher.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
Instance.new("UICorner", MiniLauncher).CornerRadius = UDim.new(0, 8)
local lStroke = Instance.new("UIStroke", MiniLauncher)
lStroke.Color = Color3.fromRGB(180, 35, 35)
lStroke.Thickness = 1.6
makeDraggable(MiniLauncher, MiniLauncher)

local LHeader = Instance.new("TextLabel", MiniLauncher)
LHeader.Size = UDim2.new(1, -35, 0, 22)
LHeader.Position = UDim2.new(0, 8, 0, 4)
LHeader.BackgroundTransparency = 1
LHeader.Text = "⚡ PROMT_HACKER // MODULE"
LHeader.TextColor3 = Color3.fromRGB(150, 150, 165)
LHeader.Font = Enum.Font.Code
LHeader.TextSize = 11
LHeader.TextXAlignment = Enum.TextXAlignment.Left

local UnloadBtn = Instance.new("TextButton", MiniLauncher)
UnloadBtn.Size = UDim2.new(0, 20, 0, 20)
UnloadBtn.Position = UDim2.new(1, -24, 0, 4)
UnloadBtn.BackgroundColor3 = Color3.fromRGB(45, 25, 25)
UnloadBtn.Text = "X"
UnloadBtn.TextColor3 = Color3.fromRGB(255, 90, 90)
UnloadBtn.Font = Enum.Font.Code
UnloadBtn.TextSize = 11
Instance.new("UICorner", UnloadBtn).CornerRadius = UDim.new(0, 4)
UnloadBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local TriggerBtn = Instance.new("TextButton", MiniLauncher)
TriggerBtn.Size = UDim2.new(1, -16, 0, 44)
TriggerBtn.Position = UDim2.new(0, 8, 0, 30)
TriggerBtn.BackgroundColor3 = Color3.fromRGB(155, 30, 30)
TriggerBtn.Text = "🎲 BLOX ROULETTE.3D\n[ НАЖМИ ДЛЯ ЗАПУСКА ]"
TriggerBtn.TextColor3 = Color3.new(1, 1, 1)
TriggerBtn.Font = Enum.Font.Code
TriggerBtn.TextSize = 12
Instance.new("UICorner", TriggerBtn).CornerRadius = UDim.new(0, 6)
-- КОНЕЦ ЧАСТИ 1Б
-- НАЧАЛО ЧАСТИ 1В
local ITEMS_DB = {
    ["Magnifying Glass"] = {Icon = "🔍", Short = "Лупа", Desc = "Показывает, какой патрон сейчас в стволе (боевой или холостой)"},
    ["Screwdriver"] = {Icon = "🪛", Short = "Отвёртка", Desc = "Выковыривает текущий патрон, ты видишь какой. Ход не теряется"},
    ["Handsaw"] = {Icon = "🪚", Short = "Ножовка", Desc = "Следующий выстрел наносит 2 урона. Действует на один выстрел"},
    ["Handcuffs"] = {Icon = "⛓️", Short = "Наручники", Desc = "Соперник пропускает свой следующий ход"},
    ["Cigarettes"] = {Icon = "🚬", Short = "Сигареты", Desc = "Восстанавливает 1 HP (не больше максимума)"},
    ["Inverter"] = {Icon = "🔄", Short = "Реверсер", Desc = "Меняет текущий патрон на противоположный (боевой <-> холостой)"},
    ["Burner Phone"] = {Icon = "📱", Short = "Телефон", Desc = "Показывает случайный патрон дальше в обойме (не текущий)"},
    ["Expired Medicine"] = {Icon = "💊", Short = "Таблетки", Desc = "50%: +2 HP, 50%: -1 HP (можно умереть!)"},
    ["Adrenaline"] = {Icon = "💉", Short = "Адреналин", Desc = "Украсть предмет соперника и сразу применить (Адреналин украсть нельзя)"}
}

local ITEM_NAMES = {}
for k in pairs(ITEMS_DB) do table.insert(ITEM_NAMES, k) end
table.sort(ITEM_NAMES) -- стабильный список; случайность задаётся отдельным перемешиванием
local itemBag = {}
local function refillItemBag()
    table.clear(itemBag)
    for _, itemName in ipairs(ITEM_NAMES) do table.insert(itemBag, itemName) end
    for i = #itemBag, 2, -1 do
        local j = math.random(1, i)
        itemBag[i], itemBag[j] = itemBag[j], itemBag[i]
    end
end
refillItemBag()
local function drawRandomItem()
    if #itemBag == 0 then refillItemBag() end
    return table.remove(itemBag)
end
-- КОНЕЦ ЧАСТИ 1В
-- НАЧАЛО ЧАСТИ 5 (ГЛАВНОЕ МЕНЮ + МАГАЗИН). Вынесено в отдельную функцию, чтобы не упереться в лимит 200 локальных переменных
local function BuildMenuAndShop(ctx)
    local RunService = game:GetService("RunService")
    local C3, M = Color3.fromRGB, Enum.Material
    local VIEW_W, VIEW_H = ctx.VIEW_W, ctx.VIEW_H
    local mk, newModel, GS, FX = ctx.mk, ctx.newModel, ctx.GameState, ctx.FX
    local Content, MainFrame, DealerHead, gunParts = ctx.Content, ctx.MainFrame, ctx.DealerHead, ctx.gunParts
    local FONT_TITLE = Enum.Font.Bodoni
    local FONT_UI = Enum.Font.Code

    Progress.owned = Progress.owned or {}
    Progress.owned.classic = true
    Progress.equipGun = Progress.equipGun or "classic"
    Progress.equipAcc = Progress.equipAcc or {}

    ----------------------------------------------------------------
    -- ДАННЫЕ: дробовики
    ----------------------------------------------------------------
    local GUN_SHAPE = {
        {"block", Vector3.new(0.26, 0.36, 1.1), Vector3.new(0, -0.05, 1.1), "stock"},
        {"block", Vector3.new(0.28, 0.4, 0.08), Vector3.new(0, -0.05, 1.68), "butt"},
        {"block", Vector3.new(0.3, 0.32, 0.9), Vector3.new(0, 0.05, 0.2), "recv"},
        {"block", Vector3.new(0.1, 0.05, 0.35), Vector3.new(0, -0.14, 0.15), "trig"},
        {"block", Vector3.new(0.34, 0.28, 0.8), Vector3.new(0, -0.05, -0.75), "pump"},
        {"cylZ", Vector3.new(0.2, 0.2, 1.3), Vector3.new(0, 0.1, -0.8), "tube"},
        {"cylZ", Vector3.new(0.19, 0.19, 0.8), Vector3.new(0, 0.1, -1.8), "tip"},
        {"ball", Vector3.new(0.13, 0.13, 0.13), Vector3.new(0, 0.1, -2.2), "muzzle"},
        {"block", Vector3.new(0.05, 0.07, 0.05), Vector3.new(0, 0.24, -1.0), "sight"},
    }
    -- порядок деталей в игровом дробовике (gunParts) -> ключ раскраски
    local GAME_IDX = {[1] = "stock", [2] = "butt", [3] = "recv", [4] = "trig", [5] = "pump", [6] = "tube", [7] = "tip", [8] = "muzzle", [10] = "sight"}

    local BASE_SKIN = {
        stock = {C3(95, 50, 25), M.Wood}, butt = {C3(30, 30, 34), M.Metal}, recv = {C3(35, 35, 40), M.Metal},
        trig = {C3(10, 10, 12), M.Metal}, pump = {C3(85, 45, 20), M.Wood}, tube = {C3(55, 55, 62), M.Metal},
        tip = {C3(62, 62, 70), M.Metal}, muzzle = {C3(0, 0, 0), M.Metal}, sight = {C3(200, 200, 205), M.Metal},
    }
    local function newSkin(id, name, price, over)
        local s = {id = id, name = name, price = price, kind = "gun"}
        for k, v in pairs(BASE_SKIN) do s[k] = v end
        for k, v in pairs(over) do s[k] = v end
        return s
    end
    local GUNS = {
        newSkin("classic", "CLASSIC PUMP", 0, {}),
        newSkin("rusty", "RUSTY OLD", 150, {
            stock = {C3(62, 40, 26), M.Wood}, pump = {C3(70, 42, 26), M.Wood}, recv = {C3(105, 52, 28), M.CorrodedMetal},
            tube = {C3(120, 62, 34), M.CorrodedMetal}, tip = {C3(130, 68, 36), M.CorrodedMetal},
            butt = {C3(80, 46, 28), M.CorrodedMetal}, sight = {C3(160, 95, 52), M.Metal}}),
        newSkin("bone", "BONE WHITE", 300, {
            stock = {C3(226, 219, 194), M.SmoothPlastic}, pump = {C3(214, 207, 182), M.SmoothPlastic},
            recv = {C3(48, 46, 44), M.Metal}, tube = {C3(170, 165, 150), M.Metal}, tip = {C3(185, 180, 165), M.Metal},
            butt = {C3(60, 58, 54), M.Metal}}),
        newSkin("blood", "BLOOD STEEL", 450, {
            stock = {C3(120, 12, 14), M.SmoothPlastic}, pump = {C3(145, 16, 20), M.SmoothPlastic},
            recv = {C3(22, 8, 10), M.Metal}, tube = {C3(68, 18, 20), M.Metal}, tip = {C3(84, 24, 26), M.Metal},
            butt = {C3(20, 8, 10), M.Metal}, sight = {C3(255, 60, 60), M.Neon}}),
        newSkin("gold", "GOLD PLATED", 900, {
            stock = {C3(232, 190, 70), M.Metal}, pump = {C3(238, 198, 84), M.Metal}, recv = {C3(196, 150, 44), M.Metal},
            tube = {C3(225, 182, 64), M.Metal}, tip = {C3(235, 194, 78), M.Metal}, butt = {C3(190, 145, 40), M.Metal},
            sight = {C3(255, 255, 235), M.Neon}}),
        newSkin("void", "VOID", 1500, {
            stock = {C3(9, 9, 13), M.SmoothPlastic}, pump = {C3(12, 12, 17), M.SmoothPlastic}, recv = {C3(6, 6, 9), M.Metal},
            tube = {C3(210, 18, 22), M.Neon}, tip = {C3(18, 18, 24), M.Metal}, butt = {C3(6, 6, 9), M.Metal},
            sight = {C3(255, 30, 30), M.Neon}}),
    }
    local BY_ID = {}
    for _, g in ipairs(GUNS) do BY_ID[g.id] = g end

    ----------------------------------------------------------------
    -- ДАННЫЕ: аксессуары Дилера (координаты в системе головы: лицо смотрит в +Z, макушка y=1.1)
    ----------------------------------------------------------------
    local function ringParts(add, y, radius, count, size, color, mat)
        for i = 0, count - 1 do
            local th = (i / count) * math.pi * 2
            add("block", size, CFrame.new(math.sin(th) * radius, y, math.cos(th) * radius) * CFrame.Angles(0, th, 0), color, mat)
        end
    end
    local function segPart(add, a, b, th, color, mat)
        add("block", Vector3.new(th, th, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, mat)
    end

    local ACCS = {
        {id = "eyepatch", name = "EYEPATCH", price = 150, slot = "face", kind = "acc", build = function(add)
            local blk = C3(10, 10, 12)
            add("block", Vector3.new(0.66, 0.66, 0.1), CFrame.new(-0.36, 0.18, 0.96), blk, M.Fabric)
            local y = 0.72
            local r = 0.95 * math.sqrt(1 - (y / 1.1) ^ 2) * 1.05
            ringParts(add, y, r, 14, Vector3.new(r * 0.5, 0.12, 0.08), blk, M.Fabric)
            segPart(add, Vector3.new(-0.36, 0.5, 0.97), Vector3.new(-0.3, 0.72, r * 0.95), 0.07, blk, M.Fabric)
        end},
        {id = "shades", name = "SHADES", price = 250, slot = "face", kind = "acc", build = function(add)
            local dk = C3(8, 8, 10)
            for _, s in ipairs({-1, 1}) do
                add("block", Vector3.new(0.66, 0.5, 0.1), CFrame.new(0.36 * s, 0.2, 0.98), dk, M.SmoothPlastic)
                segPart(add, Vector3.new(0.68 * s, 0.3, 0.98), Vector3.new(0.92 * s, 0.3, 0.25), 0.06, dk, M.SmoothPlastic)
            end
            add("block", Vector3.new(0.18, 0.07, 0.08), CFrame.new(0, 0.3, 0.99), dk, M.SmoothPlastic)
            add("block", Vector3.new(1.5, 0.07, 0.1), CFrame.new(0, 0.47, 0.99), dk, M.SmoothPlastic)
        end},
        {id = "tophat", name = "TOP HAT", price = 350, slot = "head", kind = "acc", build = function(add)
            local blk = C3(14, 14, 16)
            add("cylY", Vector3.new(2.7, 0.1, 2.7), CFrame.new(0, 0.92, 0), blk, M.Fabric)
            add("cylY", Vector3.new(1.55, 1.25, 1.55), CFrame.new(0, 1.52, 0), blk, M.Fabric)
            add("cylY", Vector3.new(1.6, 0.22, 1.6), CFrame.new(0, 1.1, 0), C3(150, 20, 24), M.Fabric)
        end},
        {id = "halo", name = "HALO", price = 600, slot = "head", kind = "acc", build = function(add)
            ringParts(add, 1.85, 0.8, 16, Vector3.new(0.34, 0.08, 0.1), C3(255, 236, 150), M.Neon)
        end},
        {id = "horns", name = "DEVIL HORNS", price = 700, slot = "head", kind = "acc", build = function(add)
            for _, s in ipairs({-1, 1}) do
                for i = 0, 3 do
                    local d = 0.34 - i * 0.07
                    add("cylY", Vector3.new(d, 0.55, d),
                        CFrame.new(s * (0.5 + i * 0.2 + i * i * 0.03), 0.85 + i * 0.42, 0) * CFrame.Angles(0, 0, -s * math.rad(18 + i * 10)),
                        i == 3 and C3(232, 226, 200) or C3(110, 14, 16), M.SmoothPlastic)
                end
            end
        end},
        {id = "crown", name = "GOLDEN CROWN", price = 1200, slot = "head", kind = "acc", build = function(add)
            local g = C3(235, 190, 70)
            add("cylY", Vector3.new(1.4, 0.3, 1.4), CFrame.new(0, 0.82, 0), g, M.Metal)
            for i = 0, 5 do
                local th = (i / 6) * math.pi * 2
                local px, pz = math.sin(th) * 0.66, math.cos(th) * 0.66
                add("block", Vector3.new(0.18, 0.5, 0.18), CFrame.new(px, 1.2, pz), g, M.Metal)
                add("ball", Vector3.new(0.17, 0.17, 0.17), CFrame.new(px, 1.5, pz), (i % 2 == 0) and C3(210, 20, 30) or C3(40, 90, 220), M.Neon)
            end
        end},
    }
    for _, a in ipairs(ACCS) do BY_ID[a.id] = a end

    ----------------------------------------------------------------
    -- ПРИМЕНЕНИЕ ПОКУПОК К ИГРЕ
    ----------------------------------------------------------------
    local function applyGunSkin(skin)
        for idx, key in pairs(GAME_IDX) do
            local g = gunParts[idx]
            local sk = skin[key]
            if g and sk then
                g.p.Color = sk[1]
                g.p.Material = sk[2]
            end
        end
    end

    local accModel
    local function applyDealerAcc()
        if accModel then accModel:Destroy() end
        accModel = Instance.new("Model")
        accModel.Name = "DealerAccessories"
        accModel.Parent = DealerHead
        local pivot = DealerHead:GetPivot()
        local function add(kind, size, cf, color, mat, tr)
            return mk(accModel, kind, size, pivot * cf, color, mat, tr)
        end
        for _, id in pairs(Progress.equipAcc) do
            local a = BY_ID[id]
            if a and a.build then a.build(add) end
        end
    end

    applyGunSkin(BY_ID[Progress.equipGun] or GUNS[1])
    applyDealerAcc()

    ----------------------------------------------------------------
    -- ГЛАВНОЕ МЕНЮ (как в Buckshot Roulette: дождь из патронов, название, список кнопок)
    ----------------------------------------------------------------
    local menuOpen, starting = false, false
    local musicMuted = false
    local MenuSound
    local Shop -- объявлено заранее (кнопка магазина), создаётся ниже
    local openShop

    -- ВАЖНО: раньше тут был CanvasGroup (GroupTransparency) - на части устройств/executor'ов после появления
    -- меню содержимое пропадало и оставался чёрный экран. Теперь обычный Frame + ручное плавное появление.
    local MenuRoot = Instance.new("Frame", Content)
    MenuRoot.Name = "MenuRoot"
    MenuRoot.Size = UDim2.new(1, 0, 0, VIEW_H)
    MenuRoot.BackgroundColor3 = C3(2, 1, 1)
    MenuRoot.BorderSizePixel = 0
    MenuRoot.ZIndex = 30
    MenuRoot.Active = true
    MenuRoot.Visible = false
    MenuRoot.BackgroundTransparency = 1 -- ВСЕГДА прозрачный: иначе его фон (ZIndex 30) рисуется поверх кнопок/названия (ZIndex 1-5) и всё чернеет
    MenuRoot.ClipsDescendants = true
    Instance.new("UICorner", MenuRoot).CornerRadius = UDim.new(0, 6)

    local Backdrop = Instance.new("Frame", MenuRoot)
    Backdrop.Name = "Backdrop"
    Backdrop.Size = UDim2.new(1, 0, 1, 0)
    Backdrop.BackgroundColor3 = C3(2, 1, 1)
    Backdrop.BorderSizePixel = 0
    Backdrop.ZIndex = 0

    local Rain = Instance.new("Frame", MenuRoot)
    Rain.Size = UDim2.new(1, 0, 1, 0)
    Rain.BackgroundTransparency = 1
    Rain.ClipsDescendants = true
    Rain.ZIndex = 1

    local shells = {}
    for i = 1, 30 do
        local depth = math.random()
        local sc = 0.55 + depth * 0.9
        local red = math.random() < 0.5
        local f = Instance.new("Frame", Rain)
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Size = UDim2.new(0, 9 * sc, 0, 24 * sc)
        f.BorderSizePixel = 0
        f.BackgroundColor3 = red and C3(150, 22, 22) or C3(20, 20, 22)
        f.BackgroundTransparency = 0.5 - depth * 0.4
        f.ZIndex = 1
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 2)
        local st = Instance.new("UIStroke", f)
        st.Color = red and C3(90, 12, 12) or C3(70, 70, 76)
        st.Thickness = 1
        st.Transparency = 0.3
        local cap = Instance.new("Frame", f)
        cap.Size = UDim2.new(1, 0, 0.3, 0)
        cap.Position = UDim2.new(0, 0, 0.7, 0)
        cap.BorderSizePixel = 0
        cap.BackgroundColor3 = C3(176, 138, 64)
        cap.BackgroundTransparency = f.BackgroundTransparency
        shells[i] = {f = f, x = math.random(), y = math.random() * VIEW_H, vy = 70 + depth * 170,
            rot = math.random(-30, 30), spin = math.random(-28, 28)}
    end

    local Dim = Instance.new("Frame", MenuRoot)
    Dim.Size = UDim2.new(1, 0, 1, 0)
    Dim.BackgroundColor3 = C3(0, 0, 0)
    Dim.BorderSizePixel = 0
    Dim.ZIndex = 2
    local dg = Instance.new("UIGradient", Dim)
    dg.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.3, 0.3),
        NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 0.75)})

    local TitleGroup = Instance.new("Frame", MenuRoot)
    TitleGroup.AnchorPoint = Vector2.new(0.5, 0)
    TitleGroup.Position = UDim2.new(0.5, 0, 0, 12)
    TitleGroup.Size = UDim2.new(0, 360, 0, 116)
    TitleGroup.BackgroundTransparency = 1
    TitleGroup.ZIndex = 3
    local titleScale = Instance.new("UIScale", TitleGroup)

    local function titleLabel(text, size, y, h)
        local l = Instance.new("TextLabel", TitleGroup)
        l.Size = UDim2.new(1, 0, 0, h)
        l.Position = UDim2.new(0, 0, 0, y)
        l.BackgroundTransparency = 1
        l.Text = text
        l.Font = FONT_TITLE
        l.TextSize = size
        l.TextColor3 = C3(236, 230, 218)
        l.TextStrokeColor3 = C3(0, 0, 0)
        l.TextStrokeTransparency = 0.25
        l.ZIndex = 4
        return l
    end
    local T1 = titleLabel("BLOX", 50, 0, 52)
    local T2 = titleLabel("ROULETTE", 42, 50, 44)
    local SubT = Instance.new("TextLabel", TitleGroup)
    SubT.Size = UDim2.new(1, 0, 0, 14)
    SubT.Position = UDim2.new(0, 0, 0, 98)
    SubT.BackgroundTransparency = 1
    SubT.Text = "A COMPUTER GAME"
    SubT.Font = FONT_UI
    SubT.TextSize = 11
    SubT.TextColor3 = C3(200, 196, 184)
    SubT.ZIndex = 4

    local VerLabel = Instance.new("TextLabel", MenuRoot)
    VerLabel.Position = UDim2.new(0, 8, 1, -18)
    VerLabel.Size = UDim2.new(0, 60, 0, 14)
    VerLabel.BackgroundTransparency = 1
    VerLabel.Text = "V7"
    VerLabel.Font = FONT_UI
    VerLabel.TextSize = 10
    VerLabel.TextColor3 = C3(150, 146, 136)
    VerLabel.TextXAlignment = Enum.TextXAlignment.Left
    VerLabel.ZIndex = 4

    local MenuCoins = Instance.new("TextLabel", MenuRoot)
    MenuCoins.AnchorPoint = Vector2.new(1, 0)
    MenuCoins.Position = UDim2.new(1, -10, 0, 8)
    MenuCoins.Size = UDim2.new(0, 160, 0, 16)
    MenuCoins.BackgroundTransparency = 1
    MenuCoins.Font = FONT_UI
    MenuCoins.TextSize = 13
    MenuCoins.TextColor3 = C3(255, 215, 90)
    MenuCoins.TextXAlignment = Enum.TextXAlignment.Right
    MenuCoins.ZIndex = 4
    local ShopMenuBtn
    local function updateCoinLabels()
        MenuCoins.Text = string.format("$%d", Progress.coins)
        if ShopMenuBtn then
            local t = string.format("SHOP  $%d", Progress.coins)
            ShopMenuBtn:SetAttribute("Base", t)
            ShopMenuBtn.Text = t
        end
    end

    -- кнопки меню
    local MainButtons = Instance.new("Frame", MenuRoot)
    MainButtons.AnchorPoint = Vector2.new(0.5, 0)
    MainButtons.Position = UDim2.new(0.5, 0, 0, 142)
    MainButtons.Size = UDim2.new(0, 220, 0, 130)
    MainButtons.BackgroundTransparency = 1
    MainButtons.ZIndex = 3
    local OptionsButtons = Instance.new("Frame", MenuRoot)
    OptionsButtons.AnchorPoint = Vector2.new(0.5, 0)
    OptionsButtons.Position = UDim2.new(0.5, 0, 0, 142)
    OptionsButtons.Size = UDim2.new(0, 260, 0, 130)
    OptionsButtons.BackgroundTransparency = 1
    OptionsButtons.Visible = false
    OptionsButtons.ZIndex = 3

    local function menuButton(parent, text, y, onClick)
        local b = Instance.new("TextButton", parent)
        b.Size = UDim2.new(1, 0, 0, 24)
        b.Position = UDim2.new(0, 0, 0, y)
        b.BackgroundTransparency = 1
        b.AutoButtonColor = false
        b.Font = FONT_UI
        b.TextSize = 16
        b.TextColor3 = C3(226, 222, 210)
        b.Text = text
        b.ZIndex = 5
        local base = text
        b:SetAttribute("Base", base)
        b.MouseEnter:Connect(function()
            b.Text = "> " .. (b:GetAttribute("Base") or base) .. " <"
            b.TextColor3 = C3(255, 72, 60)
        end)
        b.MouseLeave:Connect(function()
            b.Text = b:GetAttribute("Base") or base
            b.TextColor3 = C3(226, 222, 210)
        end)
        b.MouseButton1Click:Connect(function()
            playSFX(SOUNDS.Rack, 1.4)
            onClick(b)
        end)
        return b
    end

    local function showSub(which)
        MainButtons.Visible = (which == "main")
        OptionsButtons.Visible = (which == "options")
    end

    -- музыка меню: мрачная ID из MENU_MUSIC_ID (если пусто - берётся MUSIC_ID). Реверб + срез верхов + замедление = ещё мрачнее
    local function targetMenuVolume()
        return musicMuted and 0 or MENU_MUSIC_VOLUME
    end
    local function startMenuMusic()
        local id = (MENU_MUSIC_ID ~= "" and MENU_MUSIC_ID) or MUSIC_ID
        if id == "" then return end
        if not MenuSound then
            MenuSound = Instance.new("Sound")
            MenuSound.Name = "MenuMusic"
            MenuSound.SoundId = id
            MenuSound.Looped = true
            MenuSound.PlaybackSpeed = 0.9
            MenuSound.Volume = 0
            MenuSound.Parent = MainFrame
            pcall(function()
                local rv = Instance.new("ReverbSoundEffect", MenuSound)
                rv.DecayTime = 4.5
                rv.Density = 0.9
                rv.Diffusion = 0.9
                rv.DryLevel = -2
                rv.WetLevel = -7
                local eq = Instance.new("EqualizerSoundEffect", MenuSound)
                eq.LowGain = 3
                eq.MidGain = -3
                eq.HighGain = -12
            end)
        end
        pcall(function() MenuSound:Play() end)
        TweenService:Create(MenuSound, TweenInfo.new(3, Enum.EasingStyle.Quad), {Volume = targetMenuVolume()}):Play()
    end
    local function stopMenuMusic()
        if not MenuSound then return end
        local snd = MenuSound
        local tw = TweenService:Create(snd, TweenInfo.new(0.9), {Volume = 0})
        tw:Play()
        task.delay(1, function() pcall(function() snd:Stop() end) end)
    end

    -- анимация меню: дождь из патронов, глитч названия, пульс от громкости музыки
    local menuConn
    local glitch, mt0 = 0, os.clock()
    local function menuStep(dt)
        for _, s in ipairs(shells) do
            s.y += s.vy * dt
            s.rot += s.spin * dt
            if s.y > VIEW_H + 30 then
                s.y = -30
                s.x = math.random()
            end
            s.f.Position = UDim2.new(s.x, 0, 0, s.y)
            s.f.Rotation = s.rot
        end
        glitch -= dt
        if glitch <= 0 and math.random() < 0.012 then glitch = 0.07 end
        local jx = glitch > 0 and math.random(-3, 3) or 0
        T1.Position = UDim2.new(0, jx, 0, 0)
        T2.Position = UDim2.new(0, -jx, 0, 50)
        local col = glitch > 0 and C3(255, 70, 60) or C3(236, 230, 218)
        T1.TextColor3 = col
        T2.TextColor3 = col
        local pulse = 0
        if MenuSound and MenuSound.IsPlaying then
            pulse = math.clamp(MenuSound.PlaybackLoudness / 1200, 0, 1) * 0.04
        end
        titleScale.Scale = 1 + pulse + math.sin((os.clock() - mt0) * 1.2) * 0.006
    end

    -- плавное проявление/затухание меню без CanvasGroup: масштабируем прозрачность всех потомков
    local fadeList
    local function setMenuAlpha(a)
        if not fadeList then
            fadeList = {}
            for _, d in ipairs(MenuRoot:GetDescendants()) do
                local e
                if d:IsA("GuiObject") then
                    e = {i = d, bg = d.BackgroundTransparency}
                    if d:IsA("TextLabel") or d:IsA("TextButton") then
                        e.tx, e.ts = d.TextTransparency, d.TextStrokeTransparency
                    end
                elseif d:IsA("UIStroke") then
                    e = {i = d, st = d.Transparency}
                end
                if e then table.insert(fadeList, e) end
            end
        end
        for _, e in ipairs(fadeList) do
            local i = e.i
            if i.Parent then
                if e.bg then i.BackgroundTransparency = 1 - (1 - e.bg) * a end
                if e.tx then
                    i.TextTransparency = 1 - (1 - e.tx) * a
                    i.TextStrokeTransparency = 1 - (1 - e.ts) * a
                end
                if e.st then i.Transparency = 1 - (1 - e.st) * a end
            end
        end
    end
    local fadeVal = Instance.new("NumberValue")
    fadeVal.Changed:Connect(setMenuAlpha)
    local function fadeMenu(target, dur, dir)
        local tw = TweenService:Create(fadeVal, TweenInfo.new(dur, Enum.EasingStyle.Quad, dir), {Value = target})
        tw:Play()
        return tw
    end

    local function showMenu()
        if menuOpen then return end
        menuOpen = true
        local mus = ctx.getMusic()
        if mus then pcall(function() mus:Stop() end) end
        updateCoinLabels()
        showSub("main")
        ctx.Viewport.Visible = false -- ничего из игры не видно под меню
        fadeVal.Value = 0
        setMenuAlpha(0)
        MenuRoot.Visible = true
        fadeMenu(1, 1.6, Enum.EasingDirection.Out)
        if menuConn then menuConn:Disconnect() end
        menuConn = RunService.RenderStepped:Connect(menuStep)
        startMenuMusic()
    end

    local function startGame()
        if not menuOpen or starting then return end
        starting = true
        stopMenuMusic()
        local tw = fadeMenu(0, 0.8, Enum.EasingDirection.In)
        tw.Completed:Wait()
        MenuRoot.Visible = false
        if menuConn then menuConn:Disconnect() menuConn = nil end
        menuOpen, starting = false, false
        ctx.Viewport.Visible = true -- экран был чёрным, теперь показываем сцену
        FX.Dealer.yoff = -3.4 -- Дилер выходит из темноты
        local mus = ctx.getMusic()
        if mus then pcall(function() mus:Play() end) end
        ctx.startNewGame()
    end

    local function exitGame()
        local closeTw = TweenService:Create(ctx.WinScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0})
        closeTw:Play()
        closeTw.Completed:Wait()
        MainFrame:Destroy()
    end

    menuButton(MainButtons, "PLAY", 0, function() startGame() end)
    menuButton(MainButtons, "OPTIONS", 26, function() showSub("options") end)
    ShopMenuBtn = menuButton(MainButtons, "SHOP", 52, function() if openShop then openShop() end end)
    updateCoinLabels()
    menuButton(MainButtons, "EXIT", 78, function() exitGame() end)

    -- настройки
    local function onOff(v) return v and "ON" or "OFF" end
    local function toggleButton(y, label, getter, setter)
        local b
        local function text() return label .. ": " .. onOff(getter()) end
        b = menuButton(OptionsButtons, text(), y, function()
            setter(not getter())
            b:SetAttribute("Base", text())
            b.Text = "> " .. text() .. " <"
        end)
    end
    toggleButton(0, "MUSIC", function() return not musicMuted end, function(v)
        musicMuted = not v
        if MenuSound then MenuSound.Volume = targetMenuVolume() end
        local mus = ctx.getMusic()
        if mus then mus.Volume = musicMuted and 0 or MUSIC_VOLUME end
    end)
    toggleButton(26, "SCREEN SHAKE", function() return MUSIC_SHAKE > 0 end, function(v) MUSIC_SHAKE = v and 1 or 0 end)
    toggleButton(52, "HARDCORE DEATH", function() return HARDCORE_DEATH end, function(v) HARDCORE_DEATH = v end)
    menuButton(OptionsButtons, "BACK", 82, function() showSub("main") end)

    ----------------------------------------------------------------
    -- МАГАЗИН
    ----------------------------------------------------------------
    Shop = Instance.new("Frame", Content)
    Shop.Name = "ShopRoot"
    Shop.Size = UDim2.new(1, 0, 0, VIEW_H)
    Shop.BackgroundColor3 = C3(0, 0, 0)
    Shop.BorderSizePixel = 0
    Shop.ZIndex = 40
    Shop.Active = true
    Shop.Visible = false
    Shop.ClipsDescendants = true
    Instance.new("UICorner", Shop).CornerRadius = UDim.new(0, 6)

    local ShopView = Instance.new("ViewportFrame", Shop)
    ShopView.Size = UDim2.new(1, 0, 1, 0)
    ShopView.BackgroundColor3 = C3(4, 3, 3)
    ShopView.Ambient = C3(46, 36, 34)
    ShopView.LightColor = C3(150, 108, 92)
    ShopView.LightDirection = Vector3.new(-0.3, -1, -0.7)
    ShopView.ZIndex = 1
    local SW = Instance.new("WorldModel", ShopView)
    local SCam = Instance.new("Camera", ShopView)
    SCam.FieldOfView = 60
    SCam.CFrame = CFrame.new(0, 4.2, 0)
    ShopView.CurrentCamera = SCam
    local TAN_HALF = math.tan(math.rad(60) / 2)
    local ASPECT = VIEW_W / VIEW_H

    local function vignette(pos, size, rot)
        local f = Instance.new("Frame", ShopView)
        f.Position = pos
        f.Size = size
        f.BackgroundColor3 = C3(0, 0, 0)
        f.BorderSizePixel = 0
        f.ZIndex = 2
        local g = Instance.new("UIGradient", f)
        g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
        g.Rotation = rot
    end
    vignette(UDim2.new(0, 0, 0, 0), UDim2.new(0, 90, 1, 0), 0)
    vignette(UDim2.new(1, -90, 0, 0), UDim2.new(0, 90, 1, 0), 180)
    vignette(UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 36), 90)
    vignette(UDim2.new(0, 0, 1, -36), UDim2.new(1, 0, 0, 36), -90)

    local function shopLabel(text, size, color)
        local l = Instance.new("TextLabel", Shop)
        l.BackgroundTransparency = 1
        l.Text = text
        l.Font = FONT_UI
        l.TextSize = size
        l.TextColor3 = color
        l.TextStrokeTransparency = 0.5
        l.ZIndex = 10
        return l
    end
    local SectionLabel = shopLabel("SHOTGUNS", 14, C3(236, 230, 218))
    SectionLabel.AnchorPoint = Vector2.new(0.5, 0)
    SectionLabel.Position = UDim2.new(0.5, 0, 0, 6)
    SectionLabel.Size = UDim2.new(0, 260, 0, 18)
    local ShopCoins = shopLabel("$0", 13, C3(255, 215, 90))
    ShopCoins.AnchorPoint = Vector2.new(1, 0)
    ShopCoins.Position = UDim2.new(1, -10, 0, 7)
    ShopCoins.Size = UDim2.new(0, 120, 0, 16)
    ShopCoins.TextXAlignment = Enum.TextXAlignment.Right

    local function shopButton(text, size, pos, anchor)
        local b = Instance.new("TextButton", Shop)
        b.Size = size
        b.Position = pos
        b.AnchorPoint = anchor or Vector2.new(0, 0)
        b.BackgroundColor3 = C3(14, 8, 9)
        b.BackgroundTransparency = 0.25
        b.AutoButtonColor = true
        b.Text = text
        b.TextColor3 = C3(236, 230, 218)
        b.Font = FONT_UI
        b.TextSize = 14
        b.ZIndex = 12
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        local s = Instance.new("UIStroke", b)
        s.Color = C3(110, 30, 30)
        s.Thickness = 1
        return b
    end
    local BackBtn = shopButton("< BACK", UDim2.new(0, 74, 0, 22), UDim2.new(0, 8, 0, 6))
    local ArrowR = shopButton("►", UDim2.new(0, 36, 0, 70), UDim2.new(1, -6, 0.5, 0), Vector2.new(1, 0.5))
    local ArrowL = shopButton("◄", UDim2.new(0, 36, 0, 70), UDim2.new(0, 6, 0.5, 0), Vector2.new(0, 0.5))
    ArrowR.TextSize = 22
    ArrowL.TextSize = 22
    ArrowL.Visible = false

    local Tag = Instance.new("TextLabel", Shop)
    Tag.AnchorPoint = Vector2.new(0.5, 1)
    Tag.AutomaticSize = Enum.AutomaticSize.XY
    Tag.Size = UDim2.new(0, 0, 0, 0)
    Tag.BackgroundColor3 = C3(0, 0, 0)
    Tag.BackgroundTransparency = 0.15
    Tag.Font = FONT_UI
    Tag.TextSize = 13
    Tag.TextColor3 = C3(255, 215, 90)
    Tag.ZIndex = 15
    Tag.Visible = false
    local tagPad = Instance.new("UIPadding", Tag)
    tagPad.PaddingTop = UDim.new(0, 4)
    tagPad.PaddingBottom = UDim.new(0, 4)
    tagPad.PaddingLeft = UDim.new(0, 8)
    tagPad.PaddingRight = UDim.new(0, 8)
    local tagStroke = Instance.new("UIStroke", Tag)
    tagStroke.Color = C3(120, 90, 40)
    tagStroke.Thickness = 1

    -- нижняя панель: подтверждение покупки / EQUIP
    local Panel = Instance.new("Frame", Shop)
    Panel.AnchorPoint = Vector2.new(0.5, 1)
    Panel.Position = UDim2.new(0.5, 0, 1, -8)
    Panel.Size = UDim2.new(0, 330, 0, 72)
    Panel.BackgroundColor3 = C3(0, 0, 0)
    Panel.BackgroundTransparency = 0.1
    Panel.ZIndex = 20
    Panel.Visible = false
    local pStroke = Instance.new("UIStroke", Panel)
    pStroke.Color = C3(110, 30, 30)
    pStroke.Thickness = 1.5
    local Info = Instance.new("TextLabel", Panel)
    Info.Size = UDim2.new(1, -16, 0, 30)
    Info.Position = UDim2.new(0, 8, 0, 4)
    Info.BackgroundTransparency = 1
    Info.Font = FONT_UI
    Info.TextSize = 14
    Info.TextColor3 = C3(236, 230, 218)
    Info.TextWrapped = true
    Info.ZIndex = 21
    local function panelBtn(color)
        local b = Instance.new("TextButton", Panel)
        b.AnchorPoint = Vector2.new(0.5, 0)
        b.Size = UDim2.new(0, 70, 0, 26)
        b.Position = UDim2.new(0.5, 0, 0, 38)
        b.BackgroundColor3 = color
        b.Font = FONT_UI
        b.TextSize = 16
        b.TextColor3 = C3(255, 255, 255)
        b.ZIndex = 21
        b.Visible = false
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        return b
    end
    local B1 = panelBtn(C3(40, 140, 60))
    local B2 = panelBtn(C3(160, 36, 36))

    local Cover = Instance.new("Frame", Shop)
    Cover.Size = UDim2.new(1, 0, 1, 0)
    Cover.BackgroundColor3 = C3(0, 0, 0)
    Cover.BorderSizePixel = 0
    Cover.ZIndex = 30
    Cover.Visible = false

    -- состояние магазина
    local entries, hovered, selected = {}, nil, nil
    local panelState = nil
    local yawT, yawCur = 0, 0
    local shopBuilt, shopConn = false, nil
    local bulbs, dust = {}, {}
    local camCF = CFrame.new(0, 4.2, 0)

    local function ownedE(e) return Progress.owned[e.id] == true end
    local function equippedE(e)
        if e.kind == "gun" then return Progress.equipGun == e.id end
        return Progress.equipAcc[e.slot] == e.id
    end

    local function refreshBadges()
        ShopCoins.Text = string.format("$%d", Progress.coins)
        updateCoinLabels()
        for _, e in ipairs(entries) do
            if equippedE(e) then
                e.badge.Text = "✔"
                e.badge.TextColor3 = C3(90, 255, 130)
            elseif ownedE(e) then
                e.badge.Text = ""
            else
                e.badge.Text = "🔒"
                e.badge.TextColor3 = C3(200, 200, 200)
            end
        end
    end

    local function layoutButtons(one, two, t1, t2)
        B1.Visible = one
        B2.Visible = two
        if one and two then
            B1.Position = UDim2.new(0.5, -44, 0, 38)
            B2.Position = UDim2.new(0.5, 44, 0, 38)
            B1.Size = UDim2.new(0, 70, 0, 26)
            B2.Size = UDim2.new(0, 70, 0, 26)
        elseif one then
            B1.Position = UDim2.new(0.5, 0, 0, 38)
            B1.Size = UDim2.new(0, 130, 0, 26)
        elseif two then
            B2.Position = UDim2.new(0.5, 0, 0, 38)
            B2.Size = UDim2.new(0, 90, 0, 26)
        end
        if t1 then B1.Text = t1 end
        if t2 then B2.Text = t2 end
    end

    local function refreshPanel()
        local e = selected
        if not e then
            Panel.Visible = false
            return
        end
        Panel.Visible = true
        if panelState == "buy" then
            Info.Text = string.format("BUY %s FOR $%d?", e.name, e.price)
            Info.TextColor3 = C3(255, 215, 90)
            B1.BackgroundColor3 = C3(40, 140, 60)
            layoutButtons(true, true, "✓", "✗")
        elseif panelState == "poor" then
            Info.Text = string.format("NOT ENOUGH COINS  ($%d / $%d)", Progress.coins, e.price)
            Info.TextColor3 = C3(255, 90, 80)
            layoutButtons(false, true, nil, "OK")
        elseif panelState == "equip" then
            Info.Text = e.name .. "  -  OWNED"
            Info.TextColor3 = C3(130, 255, 150)
            B1.BackgroundColor3 = C3(46, 110, 170)
            layoutButtons(true, true, "EQUIP", "✗")
            B1.Size = UDim2.new(0, 100, 0, 26)
            B1.Position = UDim2.new(0.5, -56, 0, 38)
            B2.Size = UDim2.new(0, 60, 0, 26)
            B2.Position = UDim2.new(0.5, 56, 0, 38)
        elseif panelState == "unequip" then
            Info.Text = e.name .. "  -  EQUIPPED"
            Info.TextColor3 = C3(90, 255, 130)
            B1.BackgroundColor3 = C3(120, 70, 30)
            layoutButtons(true, true, "UNEQUIP", "✗")
            B1.Size = UDim2.new(0, 110, 0, 26)
            B1.Position = UDim2.new(0.5, -56, 0, 38)
            B2.Size = UDim2.new(0, 60, 0, 26)
            B2.Position = UDim2.new(0.5, 56, 0, 38)
        else -- equipped gun
            Info.Text = e.name .. "  -  EQUIPPED"
            Info.TextColor3 = C3(90, 255, 130)
            layoutButtons(false, true, nil, "OK")
        end
    end

    local function closePanel()
        selected = nil
        panelState = nil
        refreshPanel()
        for _, e in ipairs(entries) do
            if e ~= hovered then
                e.liftT = 0
                e.stroke.Transparency = 1
            end
        end
    end

    local function selectEntry(e)
        selected = e
        if ownedE(e) then
            if equippedE(e) then
                panelState = (e.kind == "acc") and "unequip" or "info"
            else
                panelState = "equip"
            end
        else
            panelState = (Progress.coins >= e.price) and "buy" or "poor"
        end
        refreshPanel()
    end

    B1.MouseButton1Click:Connect(function()
        local e = selected
        if not e then return end
        if panelState == "buy" then
            if Progress.coins >= e.price then
                Progress.coins -= e.price
                Progress.owned[e.id] = true
                playSFX(SOUNDS.Win, 1.3)
                refreshBadges()
                selectEntry(e) -- теперь покажет EQUIP
            else
                panelState = "poor"
                refreshPanel()
            end
        elseif panelState == "equip" then
            if e.kind == "gun" then
                Progress.equipGun = e.id
                applyGunSkin(e)
            else
                Progress.equipAcc[e.slot] = e.id
                applyDealerAcc()
            end
            playSFX(SOUNDS.Rack, 1.1)
            refreshBadges()
            selectEntry(e)
        elseif panelState == "unequip" then
            Progress.equipAcc[e.slot] = nil
            applyDealerAcc()
            playSFX(SOUNDS.Rack, 0.9)
            refreshBadges()
            selectEntry(e)
        end
    end)
    B2.MouseButton1Click:Connect(function()
        playSFX(SOUNDS.Rack, 0.8)
        closePanel()
    end)

    -- построение 3D-мира магазина (один раз, при первом открытии)
    local function webSeg(model, a, b)
        mk(model, "block", Vector3.new(0.025, 0.025, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), C3(215, 215, 208), M.SmoothPlastic, 0.45)
    end
    local function buildWeb(model, U, corner, dx, dy, L)
        local radii, angs = {0.4, 0.7, 1.0}, {0, 22.5, 45, 67.5, 90}
        local pts = {}
        for j, r in ipairs(radii) do
            pts[j] = {}
            for k, a in ipairs(angs) do
                local rr = r * L * (0.82 + 0.18 * ((j + k) % 2))
                pts[j][k] = U * (corner + Vector3.new(dx * rr * math.cos(math.rad(a)), dy * rr * math.sin(math.rad(a)), 0))
            end
        end
        local o = U * corner
        for k = 1, #angs do webSeg(model, o, pts[3][k]) end
        for j = 1, 3 do
            for k = 1, #angs - 1 do webSeg(model, pts[j][k], pts[j][k + 1]) end
        end
    end

    local function addScaled(model, base, s)
        return function(kind, size, cf, color, mat, tr)
            local rel = CFrame.new(cf.Position * s) * (cf - cf.Position)
            return mk(model, kind, size * s, base * rel, color, mat, tr)
        end
    end

    local function buildUnit(U, list, kindName)
        local W = 15
        local model = newModel(SW)
        local wood, woodD = C3(62, 42, 26), C3(48, 33, 22)
        mk(model, "block", Vector3.new(W + 2, 10.5, 0.3), U * CFrame.new(0, 5.25, -1.7), C3(40, 30, 25), M.Wood)
        for _, sx in ipairs({-1, 1}) do
            mk(model, "block", Vector3.new(0.35, 9.6, 2.0), U * CFrame.new(sx * (W / 2 + 0.1), 4.8, -0.8), woodD, M.Wood)
        end
        local boards = {1.6, 5.2, 8.8}
        for _, y in ipairs(boards) do
            mk(model, "block", Vector3.new(W + 0.4, 0.2, 2.0), U * CFrame.new(0, y, -0.8), wood, M.Wood)
        end
        -- декор верхней полки: патроны
        for i = 1, 7 do
            local x = -6 + i * 1.6 + math.random() * 0.4
            local red = i % 2 == 0
            mk(model, "cylY", Vector3.new(0.34, 0.9, 0.34), U * CFrame.new(x, 8.9 + 0.45, -0.3), red and C3(140, 20, 20) or C3(18, 18, 20), M.SmoothPlastic)
            mk(model, "cylY", Vector3.new(0.36, 0.25, 0.36), U * CFrame.new(x, 8.9 + 0.12, -0.3), C3(176, 138, 64), M.Metal)
        end
        -- лампочка
        local bulbPos = U * Vector3.new(0, 10.2, 0.6)
        mk(model, "block", Vector3.new(0.04, 1.2, 0.04), CFrame.new(bulbPos + Vector3.new(0, 0.7, 0)), C3(10, 10, 10))
        local bulb = mk(model, "ball", Vector3.new(0.4, 0.4, 0.4), CFrame.new(bulbPos), C3(255, 190, 110), M.Neon, 0.1)
        local glow = mk(model, "ball", Vector3.new(2.0, 2.0, 2.0), CFrame.new(bulbPos), C3(255, 170, 90), M.Neon, 0.93)
        table.insert(bulbs, {bulb = bulb, glow = glow})
        -- паутина
        buildWeb(model, U, Vector3.new(-W / 2, 9.4, -1.4), 1, -1, 3.6)
        buildWeb(model, U, Vector3.new(W / 2, 9.4, -1.4), -1, -1, 3.2)
        buildWeb(model, U, Vector3.new(-W / 2 + 0.2, 5.3, -0.2), 1, 1, 1.9)
        buildWeb(model, U, Vector3.new(W / 2 - 0.2, 1.7, -0.2), -1, 1, 2.2)
        buildWeb(model, U, Vector3.new(W / 2 - 0.2, 5.3, -0.2), -1, 1, 1.6)
        -- паучок
        local sp = U * Vector3.new(-5.2, 7.4, -1.2)
        mk(model, "block", Vector3.new(0.012, 2.0, 0.012), CFrame.new(sp + Vector3.new(0, 1.0, 0)), C3(215, 215, 208), M.SmoothPlastic, 0.4)
        mk(model, "ball", Vector3.new(0.26, 0.22, 0.26), CFrame.new(sp), C3(8, 8, 8), M.SmoothPlastic)

        -- предметы на полках
        local xs = {-4.8, 0, 4.8}
        for i, def in ipairs(list) do
            local row = (i <= 3) and 1 or 2
            local col = (i - 1) % 3 + 1
            local top = boards[row] + 0.1
            local x = xs[col]
            local im = newModel(SW)
            local e = {id = def.id, name = def.name, price = def.price, kind = def.kind, slot = def.slot, model = im, lift = 0, liftT = 0}
            if def.kind == "gun" then
                local s = 1.0
                local base = U * CFrame.new(x - 0.25 * s, top + 0.27 * s, 0.15) * CFrame.Angles(0, -math.pi / 2 + math.rad(math.random(-5, 5)), 0)
                for _, sp2 in ipairs(GUN_SHAPE) do
                    local sk = def[sp2[4]]
                    mk(im, sp2[1], sp2[2] * s, base * CFrame.new(sp2[3] * s), sk[1], sk[2])
                end
                e.pos = (U * CFrame.new(x, top + 0.35, 0.15)).Position
                e.w, e.h = 4.0, 1.0
            else
                local s = 0.8
                local base = U * CFrame.new(x, top + 1.1 * s, 0.1) * CFrame.Angles(0, math.rad(math.random(-14, 14)), 0)
                local add = addScaled(im, base, s)
                local SK = C3(196, 188, 172)
                add("ball", Vector3.new(1.9, 2.2, 1.9), CFrame.new(), SK, M.SmoothPlastic)
                add("ball", Vector3.new(1.3, 0.9, 1.1), CFrame.new(0, -0.8, 0.2), SK, M.SmoothPlastic)
                for _, sgn in ipairs({-1, 1}) do
                    add("ball", Vector3.new(0.62, 0.78, 0.34), CFrame.new(0.36 * sgn, 0.18, 0.74), C3(2, 1, 1), M.SmoothPlastic)
                end
                def.build(add)
                e.pos = (U * CFrame.new(x, top + 1.5, 0.1)).Position
                e.w, e.h = 2.3, 2.8
            end
            -- кнопка поверх предмета
            local btn = Instance.new("TextButton", Shop)
            btn.AnchorPoint = Vector2.new(0.5, 0.5)
            btn.BackgroundTransparency = 1
            btn.Text = ""
            btn.ZIndex = 6
            btn.Visible = false
            local bs = Instance.new("UIStroke", btn)
            bs.Color = C3(255, 70, 60)
            bs.Thickness = 1.5
            bs.Transparency = 1
            local badge = Instance.new("TextLabel", btn)
            badge.AnchorPoint = Vector2.new(0.5, 1)
            badge.Position = UDim2.new(0.5, 0, 0, -2)
            badge.Size = UDim2.new(0, 30, 0, 16)
            badge.BackgroundTransparency = 1
            badge.Font = FONT_UI
            badge.TextSize = 13
            badge.TextColor3 = C3(90, 255, 130)
            badge.ZIndex = 7
            e.btn, e.stroke, e.badge = btn, bs, badge
            btn.MouseEnter:Connect(function()
                hovered = e
                e.liftT = 0.3
                bs.Transparency = 0.1
            end)
            btn.MouseLeave:Connect(function()
                if hovered == e then hovered = nil end
                e.liftT = (selected == e) and 0.15 or 0
                if selected ~= e then bs.Transparency = 1 end
            end)
            btn.MouseButton1Click:Connect(function()
                if selected and selected ~= e then
                    selected.liftT = 0
                    selected.stroke.Transparency = 1
                end
                playSFX(SOUNDS.Rack, 1.6)
                selectEntry(e)
                e.liftT = 0.3
                bs.Transparency = 0.1
            end)
            entries[#entries + 1] = e
        end
    end

    local function buildWorld()
        shopBuilt = true
        -- пол, потолок, стены вокруг камеры
        mk(SW, "block", Vector3.new(70, 0.4, 70), CFrame.new(0, -0.2, 0), C3(20, 15, 13), M.Wood)
        mk(SW, "block", Vector3.new(70, 0.4, 70), CFrame.new(0, 13, 0), C3(10, 8, 8), M.Concrete)
        local R = 12.5
        for i = 0, 11 do
            local a = math.rad(i * 30)
            local pos = Vector3.new(math.sin(a) * R, 6.5, -math.cos(a) * R)
            local v = 26 + (i % 3) * 5
            mk(SW, "block", Vector3.new(6.9, 13, 0.4), CFrame.lookAt(pos, Vector3.new(0, 6.5, 0)), C3(v, v - 6, v - 8), M.Concrete)
        end
        local UA = CFrame.new(0, 0, -9)
        local UB = CFrame.new(9, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0)
        buildUnit(UA, GUNS, "gun")
        buildUnit(UB, ACCS, "acc")
        for i = 1, 26 do
            local ang, rad = math.random() * math.pi * 2, 3 + math.random() * 6
            local p = mk(SW, "ball", Vector3.new(0.05, 0.05, 0.05), CFrame.new(), C3(190, 150, 120), M.Neon, 0.4)
            dust[i] = {p = p, x = math.sin(ang) * rad, z = -math.cos(ang) * rad, y = math.random() * 11, ph = math.random() * 6}
        end
        refreshBadges()
    end

    local function shopStep(dt)
        local t = os.clock()
        yawCur += (yawT - yawCur) * math.min(1, dt * 3.2)
        camCF = CFrame.new(0, 4.2, 0) * CFrame.Angles(0, -yawCur, 0)
            * CFrame.Angles(math.sin(t * 0.4) * 0.004 - 0.02, math.sin(t * 0.3) * 0.006, 0)
        SCam.CFrame = camCF

        for i, b in ipairs(bulbs) do
            local blink = (math.noise(t * 1.4, i * 7.3) > 0.28) and (0.5 + 0.5 * math.sin(t * 55 + i)) or 1
            b.bulb.Transparency = 0.1 + 0.9 * (1 - blink)
            b.glow.Transparency = 0.93 + 0.07 * (1 - blink)
        end
        for _, d in ipairs(dust) do
            local yy = (d.y + t * 0.12) % 11
            d.p.CFrame = CFrame.new(d.x + math.sin(t * 0.4 + d.ph) * 0.5, yy, d.z + math.cos(t * 0.3 + d.ph) * 0.5)
        end

        local tagE = hovered or selected
        local tagShown = false
        for _, e in ipairs(entries) do
            local before = e.lift
            e.lift += (e.liftT - e.lift) * math.min(1, dt * 10)
            if math.abs(e.lift - before) > 0.0005 then
                e.model:PivotTo(CFrame.new(0, e.lift, 0))
            end
            local rel = camCF:PointToObjectSpace(e.pos + Vector3.new(0, e.lift, 0))
            local depth = -rel.Z
            local vis = false
            if depth > 1.5 then
                local nx = rel.X / (depth * TAN_HALF * ASPECT) * 0.5 + 0.5
                local ny = 0.5 - (rel.Y / (depth * TAN_HALF)) * 0.5
                if nx > -0.1 and nx < 1.1 then
                    vis = true
                    local ppu = VIEW_H / (2 * TAN_HALF * depth)
                    local w, h = math.max(56, e.w * ppu), math.max(34, e.h * ppu)
                    e.btn.Size = UDim2.new(0, w, 0, h)
                    e.btn.Position = UDim2.new(nx, 0, ny, 0)
                    if e == tagE and Panel.Visible == false or e == hovered then
                        tagShown = true
                        local st = equippedE(e) and "EQUIPPED" or (ownedE(e) and "OWNED" or ("$" .. e.price))
                        Tag.Text = e.name .. "\n" .. st
                        Tag.TextColor3 = ownedE(e) and C3(130, 255, 150) or C3(255, 215, 90)
                        Tag.Position = UDim2.new(nx, 0, ny, -h / 2 - 16)
                    end
                end
            end
            e.btn.Visible = vis and not Cover.Visible
        end
        Tag.Visible = tagShown

        local pulse = math.floor(math.sin(t * 4) * 3)
        ArrowR.Position = UDim2.new(1, -6 + pulse, 0.5, 0)
        ArrowL.Position = UDim2.new(0, 6 - pulse, 0.5, 0)
    end

    local function turnTo(accessories)
        yawT = accessories and math.rad(90) or 0
        ArrowR.Visible = not accessories
        ArrowL.Visible = accessories
        SectionLabel.Text = accessories and "DEALER ACCESSORIES" or "SHOTGUNS"
        for _, e in ipairs(entries) do
            e.liftT = 0
            e.stroke.Transparency = 1
        end
        hovered = nil
        closePanel()
        playSFX(SOUNDS.Rack, 0.7)
    end
    ArrowR.MouseButton1Click:Connect(function() turnTo(true) end)
    ArrowL.MouseButton1Click:Connect(function() turnTo(false) end)

    local function closeShop()
        if shopConn then shopConn:Disconnect() shopConn = nil end
        Shop.Visible = false
        Tag.Visible = false
        hovered = nil
        closePanel()
        for _, e in ipairs(entries) do
            e.liftT = 0
            e.stroke.Transparency = 1
            e.btn.Visible = false
        end
        updateCoinLabels()
    end
    BackBtn.MouseButton1Click:Connect(function()
        playSFX(SOUNDS.Rack, 1.2)
        closeShop()
    end)

    openShop = function()
        if not shopBuilt then buildWorld() end
        yawT, yawCur = 0, 0
        ArrowR.Visible = true
        ArrowL.Visible = false
        SectionLabel.Text = "SHOTGUNS"
        closePanel()
        refreshBadges()
        Shop.Visible = true
        Cover.Visible = true
        Cover.BackgroundTransparency = 0
        local tw = TweenService:Create(Cover, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {BackgroundTransparency = 1})
        tw:Play()
        tw.Completed:Connect(function() Cover.Visible = false end)
        if shopConn then shopConn:Disconnect() end
        shopConn = RunService.RenderStepped:Connect(shopStep)
    end

    return showMenu
end
-- КОНЕЦ ЧАСТИ 5
-- НАЧАЛО ЧАСТИ 2А
local function Launch3DBuckshot()
    if ScreenGui:FindFirstChild("MainFrame") or ScreenGui:FindFirstChild("IntroOrb") then return end

    local GameState = {
        Round = 1, MaxHP = 4, PlayerHP = 4, DealerHP = 4,
        Shells = {}, PlayerItems = {}, DealerItems = {},
        Turn = "Player", SawActive = false,
        DealerCuffed = false, PlayerCuffed = false,
        StealingMode = false, GameOver = false, Busy = false, Aiming = false
    }

    local IntroOrb = Instance.new("Frame", ScreenGui)
    IntroOrb.Name = "IntroOrb"
    IntroOrb.Size = UDim2.new(0, 56, 0, 56)
    IntroOrb.Position = UDim2.new(0.5, -28, 0, -70)
    IntroOrb.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    IntroOrb.ZIndex = 20
    Instance.new("UICorner", IntroOrb).CornerRadius = UDim.new(1, 0)
    local orbStroke = Instance.new("UIStroke", IntroOrb)
    orbStroke.Color = Color3.fromRGB(255, 200, 50)
    orbStroke.Thickness = 2

    local BoltLabel = Instance.new("TextLabel", IntroOrb)
    BoltLabel.Size = UDim2.new(1, 0, 1, 0)
    BoltLabel.BackgroundTransparency = 1
    BoltLabel.Text = "⚡"
    BoltLabel.TextColor3 = Color3.fromRGB(255, 225, 65)
    BoltLabel.Font = Enum.Font.Code
    BoltLabel.TextSize = 28
    BoltLabel.ZIndex = 21

    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 640, 0, 340)
    MainFrame.Position = UDim2.new(0.5, -320, 0.5, -170)
    MainFrame.BackgroundColor3 = Color3.fromRGB(9, 6, 7)
    MainFrame.ClipsDescendants = true
    MainFrame.Visible = false
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
    local MainStroke = Instance.new("UIStroke", MainFrame)
    MainStroke.Color = Color3.fromRGB(100, 25, 25)
    MainStroke.Thickness = 2

    local WinScale = Instance.new("UIScale", MainFrame)
    WinScale.Scale = 0.01

    local FlashOverlay = Instance.new("Frame", MainFrame)
    FlashOverlay.Size = UDim2.new(1, 0, 1, 0)
    FlashOverlay.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    FlashOverlay.BackgroundTransparency = 1
    FlashOverlay.ZIndex = 10

    local TopBar = Instance.new("Frame", MainFrame)
    TopBar.Size = UDim2.new(1, 0, 0, 34)
    TopBar.BackgroundColor3 = Color3.fromRGB(17, 10, 11)
    makeDraggable(MainFrame, TopBar)

    local Title = Instance.new("TextLabel", TopBar)
    Title.Size = UDim2.new(1, -80, 1, 0)
    Title.Position = UDim2.new(0, 12, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "BLOX ROULETTE"
    Title.TextColor3 = Color3.fromRGB(240, 55, 55)
    Title.Font = Enum.Font.Code
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left

    -- Журнал убран: вместо него субтитры внизу (см. subtitle ниже). Заглушки, чтобы остальной код не ломался.
    local SideLog = Instance.new("Frame")
    SideLog.Visible = false
    local function addSideLog() end
    local function syncSidePanel() end
-- КОНЕЦ ЧАСТИ 2А
-- НАЧАЛО ЧАСТИ 2Б
    local MinBtn = Instance.new("TextButton", TopBar)
    MinBtn.Size = UDim2.new(0, 28, 0, 24)
    MinBtn.Position = UDim2.new(1, -64, 0, 5)
    MinBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
    MinBtn.Text = "_"
    MinBtn.TextColor3 = Color3.new(1,1,1)
    MinBtn.Font = Enum.Font.Code
    Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 4)

    local CloseBtn = Instance.new("TextButton", TopBar)
    CloseBtn.Size = UDim2.new(0, 28, 0, 24)
    CloseBtn.Position = UDim2.new(1, -32, 0, 5)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(160, 30, 30)
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.new(1,1,1)
    CloseBtn.Font = Enum.Font.Code
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 4)

    local Content = Instance.new("Frame", MainFrame)
    Content.Size = UDim2.new(1, -20, 1, -44)
    Content.Position = UDim2.new(0, 10, 0, 38)
    Content.BackgroundTransparency = 1

    local minimized = false
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        Content.Visible = not minimized
        SideLog.Visible = not minimized
        local targetSize = minimized and UDim2.new(0, 640, 0, 34) or UDim2.new(0, 640, 0, 340)
        TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize}):Play()
    end)

    CloseBtn.MouseButton1Click:Connect(function()
        local closeTw = TweenService:Create(WinScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0})
        closeTw:Play()
        SideLog:Destroy()
        closeTw.Completed:Wait()
        MainFrame:Destroy()
    end)

    local function spawnMiniExplosion(impactOffset)
        playSFX(SOUNDS.Shot, 1.85)
        local ring = Instance.new("Frame", ScreenGui)
        ring.Size = UDim2.new(0, 10, 0, 10)
        ring.Position = UDim2.new(0.5, impactOffset.X - 5, 0.5, impactOffset.Y - 5)
        ring.BackgroundTransparency = 1
        ring.ZIndex = 25
        Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
        local rStroke = Instance.new("UIStroke", ring)
        rStroke.Color = Color3.fromRGB(255, 225, 70)
        rStroke.Thickness = 2.5

        TweenService:Create(ring, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 64, 0, 64),
            Position = UDim2.new(0.5, impactOffset.X - 32, 0.5, impactOffset.Y - 32)
        }):Play()
        TweenService:Create(rStroke, TweenInfo.new(0.32), {Transparency = 1}):Play()
        task.delay(0.35, function() if ring then ring:Destroy() end end)

        for i = 1, 6 do
            local spark = Instance.new("Frame", ScreenGui)
            spark.Size = UDim2.new(0, 5, 0, 5)
            spark.Position = UDim2.new(0.5, impactOffset.X, 0.5, impactOffset.Y)
            spark.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(255, 230, 80) or Color3.fromRGB(255, 90, 60)
            spark.ZIndex = 26
            Instance.new("UICorner", spark).CornerRadius = UDim.new(1, 0)

            local angle = math.rad(i * 60 + math.random(-15, 15))
            local dist = math.random(24, 38)
            TweenService:Create(spark, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, impactOffset.X + math.cos(angle) * dist, 0.5, impactOffset.Y + math.sin(angle) * dist),
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 2, 0, 2)
            }):Play()
            task.delay(0.3, function() if spark then spark:Destroy() end end)
        end

        Title.Text = "BLOX ROULETTE ⚡ // 3D EDITION"
        Title.TextColor3 = Color3.fromRGB(255, 230, 100)
        Title.Position = UDim2.new(0, 16, 0, -2)
        TweenService:Create(Title, TweenInfo.new(0.25, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 12, 0, 0),
            TextColor3 = Color3.fromRGB(240, 55, 55)
        }):Play()
    end

    task.spawn(function()
        playSFX(SOUNDS.Heal, 1.3)
        local slideTw = TweenService:Create(IntroOrb, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -28, 0.5, -28)
        })
        slideTw:Play()
        slideTw.Completed:Wait()

        MainFrame.Visible = true
        TweenService:Create(IntroOrb, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Rotation = 360,
            BackgroundTransparency = 1
        }):Play()
        orbStroke.Transparency = 1

        local openTw = TweenService:Create(WinScale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
        openTw:Play()
        openTw.Completed:Wait()

        if MainFrame.Parent then
            SideLog.Visible = true
            syncSidePanel()
        end

        -- цель: место молнии в заголовке "BLOX ROULETTE ⚡ // 3D EDITION" (считаем по реальному положению Title)
        task.wait()
        local gp, gs = Vector2.new(0, 0), ScreenGui.AbsoluteSize
        pcall(function() gp = ScreenGui.AbsolutePosition end)
        local center = gs / 2
        local target
        local okT = pcall(function()
            local TextService = game:GetService("TextService")
            local pre = TextService:GetTextSize("BLOX ROULETTE ", Title.TextSize, Title.Font, Vector2.new(1000, 100))
            local bolt = TextService:GetTextSize("⚡", Title.TextSize, Title.Font, Vector2.new(1000, 100))
            local abs = Title.AbsolutePosition - gp
            target = Vector2.new(abs.X + pre.X + bolt.X / 2, abs.Y + Title.AbsoluteSize.Y / 2) - center
        end)
        if not okT or not target then
            target = Vector2.new(-MainFrame.AbsoluteSize.X / 2 + 140, -MainFrame.AbsoluteSize.Y / 2 + 17)
        end
        IntroOrb.AnchorPoint = Vector2.new(0.5, 0.5)
        IntroOrb.Position = UDim2.new(0.5, 0, 0.5, 0)
        local p0, p2 = Vector2.new(0, 0), target
        local p1 = Vector2.new(p2.X * 0.15, p2.Y * 0.9)
        local STEPS = 24
        for step = 1, STEPS do
            local t = step / STEPS
            local pos = ((1 - t)^2) * p0 + 2 * (1 - t) * t * p1 + (t^2) * p2
            IntroOrb.Position = UDim2.new(0.5, pos.X, 0.5, pos.Y)
            IntroOrb.Rotation = 360 + (t * 360)
            BoltLabel.TextSize = 28 - (t * 14)
            task.wait(0.016)
        end
        IntroOrb:Destroy()
        spawnMiniExplosion(p2)
        -- молния вправилась в название -> плавно появляется главное меню
        task.wait(0.6)
        local waited = os.clock()
        while MainFrame.Parent and not GameState.ShowMenu and os.clock() - waited < 5 do task.wait(0.1) end
        if MainFrame.Parent and GameState.ShowMenu then GameState.ShowMenu() end
    end)
-- КОНЕЦ ЧАСТИ 2Б
-- НАЧАЛО ЧАСТИ 2В (3D-СЦЕНА: комната, стол, Дилер, дробовик)
    local RunService = game:GetService("RunService")
    local VIEW_W, VIEW_H = 620, 296
    local ASPECT = VIEW_W / VIEW_H
    local CAM_FOV = 58
    -- КАМЕРА ОТ ПЕРВОГО ЛИЦА (как в видео): ты сидишь за столом напротив Дилера
    local CAM_TABLE  = CFrame.lookAt(Vector3.new(0, 8.6, 9.2), Vector3.new(0, 0, -1.2))  -- сидим на конце длинного узкого стола
    local CAM_DEALER = CFrame.lookAt(Vector3.new(0, 3.3, 8.4), Vector3.new(0, 3.6, -6.4))    -- взгляд на Дилера
    local CAM_HP = CFrame.lookAt(Vector3.new(6.3, 1.5, 0) + Vector3.new(-0.62, 0.35, 0.7).Unit * 3.0, Vector3.new(6.3, 1.5, 0)) -- крупно на табло справа (как на фото 3)
    local CAM_SELF   = CFrame.lookAt(Vector3.new(0, 5.0, 11.2), Vector3.new(0, 4.2, 8.6))    -- дуло смотрит прямо на тебя
    local BASE_CAM = CAM_TABLE
    local camTarget, camCur = CAM_DEALER, CAM_DEALER -- камера плавно едет к camTarget (лупа - крупный план)
    local DEALER_Z = -6.5
    local DEALER_ITEM_Z, PLAYER_ITEM_Z, ITEM_SPACING = -1.6, 3.2, 2.2
    local DEALER_BANK = (CFrame.lookAt(Vector3.new(6.3, 1.5, 0), Vector3.new(6.3, 1.5, 0) - Vector3.new(-0.62, 0.35, 0.7).Unit) * CFrame.new(-1.3, 0.3, 0.3)).Position
    local PLAYER_BANK = (CFrame.lookAt(Vector3.new(6.3, 1.5, 0), Vector3.new(6.3, 1.5, 0) - Vector3.new(-0.62, 0.35, 0.7).Unit) * CFrame.new(1.3, 0.3, 0.3)).Position
    local shake = 0

    local Viewport = Instance.new("ViewportFrame", Content)
    Viewport.Visible = false -- 3D-сцена (дилер, подписи) скрыта, пока открыто меню: сначала чёрный экран -> меню -> игра
    Viewport.Size = UDim2.new(1, 0, 0, VIEW_H)
    Viewport.Position = UDim2.new(0, 0, 0, 0)
    Viewport.BackgroundColor3 = Color3.fromRGB(5, 3, 4)
    Viewport.Ambient = Color3.fromRGB(42, 34, 36)
    Viewport.LightColor = Color3.fromRGB(145, 105, 105)
    Viewport.LightDirection = Vector3.new(-0.35, -1, -0.8)
    Instance.new("UICorner", Viewport).CornerRadius = UDim.new(0, 6)
    local ViewStroke = Instance.new("UIStroke", Viewport)
    ViewStroke.Color = Color3.fromRGB(110, 30, 30)
    ViewStroke.Thickness = 1.5

    local WorldModel = Instance.new("WorldModel", Viewport)
    local Camera = Instance.new("Camera", Viewport)
    Camera.FieldOfView = CAM_FOV
    Camera.CFrame = CAM_DEALER
    Viewport.CurrentCamera = Camera

    local TAN_HALF = math.tan(math.rad(CAM_FOV) / 2)
    -- Проекция 3D-точки на экран окна: возвращает (x, y) в долях 0..1 и пикселей на 1 единицу мира
    local function project(worldPos)
        local rel = camCur:PointToObjectSpace(worldPos)
        local depth = -rel.Z
        if depth < 0.5 then return 0.5, 0.5, 20 end
        local nx = rel.X / (depth * TAN_HALF * ASPECT)
        local ny = rel.Y / (depth * TAN_HALF)
        return nx * 0.5 + 0.5, 0.5 - ny * 0.5, VIEW_H / (2 * TAN_HALF * depth)
    end

    -- Конструктор деталей: block / ball / cyl(ось X) / cylY(стоит вертикально, size=(диаметр, высота, диаметр)) / cylZ(ось Z, size=(диаметр, диаметр, длина))
    local function mk(parent, kind, size, rel, color, material, transparency)
        local p = Instance.new("Part")
        p.Anchored = true
        p.CanCollide = false
        p.CastShadow = false
        p.Material = material or Enum.Material.SmoothPlastic
        p.Color = color
        p.Transparency = transparency or 0
        if kind == "ball" then
            p.Shape = Enum.PartType.Ball
            p.Size = size
        elseif kind == "cyl" then
            p.Shape = Enum.PartType.Cylinder
            p.Size = size
        elseif kind == "cylY" then
            p.Shape = Enum.PartType.Cylinder
            p.Size = Vector3.new(size.Y, size.X, size.X)
            rel = rel * CFrame.Angles(0, 0, math.pi / 2)
        elseif kind == "cylZ" then
            p.Shape = Enum.PartType.Cylinder
            p.Size = Vector3.new(size.Z, size.X, size.X)
            rel = rel * CFrame.Angles(0, math.pi / 2, 0)
        else
            p.Size = size
        end
        p.CFrame = rel
        p.Parent = parent
        return p
    end

    local function newModel(parent)
        local m = Instance.new("Model")
        local root = Instance.new("Part")
        root.Name = "Root"
        root.Size = Vector3.new(0.2, 0.2, 0.2)
        root.Transparency = 1
        root.Anchored = true
        root.CanCollide = false
        root.CFrame = CFrame.new()
        root.Parent = m
        m.PrimaryPart = root
        m.Parent = parent
        return m
    end

    local function limb(parent, a, b, thick, color)
        local len = (b - a).Magnitude
        return mk(parent, "block", Vector3.new(thick, thick, len), CFrame.lookAt((a + b) / 2, b), color, Enum.Material.Fabric)
    end

    local FX = {lamps = {}}
    FX.Dealer = {lean = 0, leanT = 0, kick = 0, yoff = -3.4, laugh = 0, look = 0, away = 0, awayT = 0, tilt = 0, tiltT = 0, nod = 0, nodT = 0, yaw = 0, yawT = 0, fast = false}
    FX.Panel = {Dealer = {bolts = {}}, Player = {bolts = {}}}
    FX.PANEL_CF = CFrame.lookAt(Vector3.new(6.3, 1.5, 0), Vector3.new(6.3, 1.5, 0) - Vector3.new(-0.62, 0.35, 0.7).Unit)
    -- 8 ячеек для предметов: слева 4 (2 колонки x 2 ряда) и справа 4. Предмет всегда лежит на СВОЁМ месте
    FX.SLOT_X = {-2.32, -0.97, 0.97, 2.32}
    FX.SLOT_COL = {1, 4, 2, 3, 1, 4, 2, 3}
    FX.SLOT_ROW = {1, 1, 1, 1, 2, 2, 2, 2}
    FX.hint = {}
    FX.lastHP = {}
    FX.nick = (string.upper(player.Name):gsub("[^A-Z0-9_]", ""))
    if FX.nick == "" then FX.nick = "PLAYER" end
    FX.nick = string.sub(FX.nick, 1, 10)

    -- молнии на табло: пока есть HP молния горит, потерянная молния рассыпается искрами и пропадает
    function FX.setMonitor(side, hp, maxHp)
        for i, b in ipairs(FX.Panel[side].bolts) do
            local show = (i <= hp)
            if b.alive == nil then
                b.alive = show
                for _, p in ipairs(b.parts) do p.Transparency = (show and not FX.roundMode) and 0 or 1 end
            elseif b.alive ~= show then
                b.alive = show
                for _, p in ipairs(b.parts) do p.Transparency = (show and not FX.roundMode) and 0 or 1 end
                if FX.emit and not FX.roundMode then
                    FX.emit(b.world, show and 8 or 16, show and Color3.fromRGB(150, 255, 190) or Color3.fromRGB(215, 255, 215), 3.5, 0.8, 0.07, 0)
                end
            end
        end
    end

    -- КОМНАТА И СТОЛ: тесный кирпичный подвал, сзади Дилера темнота
    do
        local WOOD = Color3.fromRGB(40, 26, 20)
        local BRICK = Color3.fromRGB(62, 32, 29)
        local MORTAR = Color3.fromRGB(20, 10, 11)
        local DARKM = Color3.fromRGB(14, 13, 15)
        local function block(size, pos, color, material, transp)
            return mk(WorldModel, "block", size, CFrame.new(pos), color, material, transp)
        end
        local function cable(a, b, sag, thick)
            local prev = a
            for i = 1, 8 do
                local t = i / 8
                local p = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
                limb(WorldModel, prev, p, thick or 0.06, DARKM)
                prev = p
            end
        end

        -- пол и кирпичные стены
        block(Vector3.new(90, 1, 70), Vector3.new(0, -3.6, 0), Color3.fromRGB(9, 7, 8), Enum.Material.Concrete)
        block(Vector3.new(19.6, 0.6, 34), Vector3.new(0, 11.5, -1), Color3.fromRGB(8, 6, 7), Enum.Material.Concrete) -- потолок: комната тесная
        block(Vector3.new(70, 26, 0.6), Vector3.new(0, 8, -10.5), BRICK, Enum.Material.Brick)
        block(Vector3.new(0.6, 26, 40), Vector3.new(-9.8, 8, -2), BRICK, Enum.Material.Brick)
        block(Vector3.new(0.6, 26, 40), Vector3.new(9.8, 8, -2), BRICK, Enum.Material.Brick)
        for r = 0, 12 do
            local y = -2.6 + r * 0.8
            block(Vector3.new(70, 0.07, 0.05), Vector3.new(0, y, -10.17), MORTAR)
            block(Vector3.new(0.05, 0.07, 40), Vector3.new(-9.47, y, -2), MORTAR)
            block(Vector3.new(0.05, 0.07, 40), Vector3.new(9.47, y, -2), MORTAR)
            local off = (r % 2) * 1.0
            for x = -12 + off, 12, 2.0 do
                block(Vector3.new(0.07, 0.8, 0.05), Vector3.new(x, y + 0.4, -10.17), MORTAR)
            end
        end
        -- неровные, закопчённые кирпичи
        local rng = Random.new(11)
        for _ = 1, 46 do
            local r = rng:NextInteger(0, 11)
            local c = rng:NextInteger(0, 11)
            local off = (r % 2) * 1.0
            local k = rng:NextNumber(0.45, 1.5)
            block(Vector3.new(1.85, 0.7, 0.03), Vector3.new(-11 + off + c * 2, -2.6 + r * 0.8 + 0.4, -10.188),
                Color3.fromRGB(62 * k, 32 * k, 29 * k), Enum.Material.Brick)
        end

        -- трубы и опоры
        for _, x in ipairs({-9, -5.5, 5.5, 9}) do
            block(Vector3.new(0.5, 22, 0.5), Vector3.new(x, 6, -9.9), Color3.fromRGB(28, 22, 24), Enum.Material.Metal)
        end
        block(Vector3.new(70, 0.3, 0.3), Vector3.new(0, 5.5, -9.8), Color3.fromRGB(24, 19, 21), Enum.Material.Metal)

        -- свисающие провода
        cable(Vector3.new(-9.2, 6.1, -9.9), Vector3.new(-4.5, 5.9, -9.9), 1.3)
        cable(Vector3.new(-6, 6.2, -9.9), Vector3.new(4, 6.0, -9.9), 1.7)
        cable(Vector3.new(3, 6.1, -9.9), Vector3.new(9.2, 6.3, -9.9), 1.4)
        cable(Vector3.new(-9, 6.2, -9.9), Vector3.new(-9.3, 2.6, -9.6), 0.3, 0.05)
        cable(Vector3.new(8, 6.2, -9.9), Vector3.new(8.4, 2.2, -9.6), 0.4, 0.05)

        -- сценические прожекторы по бокам от монстра
        local function spot(x)
            local pos = Vector3.new(x, 4.9, -6.4)
            local aim = Vector3.new(x * 0.2, 0.4, -1.2)
            local cf = CFrame.lookAt(pos, aim)
            mk(WorldModel, "cylZ", Vector3.new(1.3, 1.3, 1.4), cf, Color3.fromRGB(14, 13, 15), Enum.Material.Metal)
            mk(WorldModel, "cylZ", Vector3.new(0.9, 0.9, 0.5), cf * CFrame.new(0, 0, 0.9), DARKM, Enum.Material.Metal)
            local lens = mk(WorldModel, "cylZ", Vector3.new(1.1, 1.1, 0.08), cf * CFrame.new(0, 0, -0.72), Color3.fromRGB(255, 196, 140), Enum.Material.Neon, 0.1)
            table.insert(FX.lamps, {p = lens, base = 0.1})
            mk(WorldModel, "block", Vector3.new(1.5, 0.05, 0.55), cf * CFrame.new(0, 0.8, -0.95) * CFrame.Angles(math.rad(-30), 0, 0), DARKM, Enum.Material.Metal)
            mk(WorldModel, "block", Vector3.new(1.5, 0.05, 0.55), cf * CFrame.new(0, -0.8, -0.95) * CFrame.Angles(math.rad(30), 0, 0), DARKM, Enum.Material.Metal)
            mk(WorldModel, "block", Vector3.new(0.05, 1.4, 0.55), cf * CFrame.new(0.8, 0, -0.95) * CFrame.Angles(0, math.rad(-30), 0), DARKM, Enum.Material.Metal)
            mk(WorldModel, "block", Vector3.new(0.05, 1.4, 0.55), cf * CFrame.new(-0.8, 0, -0.95) * CFrame.Angles(0, math.rad(30), 0), DARKM, Enum.Material.Metal)
            block(Vector3.new(1.9, 0.1, 0.1), Vector3.new(x, 5.75, -6.4), DARKM, Enum.Material.Metal)
            block(Vector3.new(0.1, 0.9, 0.1), Vector3.new(x - 0.9, 5.3, -6.4), DARKM, Enum.Material.Metal)
            block(Vector3.new(0.1, 0.9, 0.1), Vector3.new(x + 0.9, 5.3, -6.4), DARKM, Enum.Material.Metal)
            block(Vector3.new(0.14, 3, 0.14), Vector3.new(x, 7.2, -6.4), DARKM, Enum.Material.Metal)
            local L = (aim - pos).Magnitude
            local beam = mk(WorldModel, "block", Vector3.new(1.5, 1.5, L), CFrame.lookAt(pos:Lerp(aim, 0.5), aim), Color3.fromRGB(255, 150, 105), Enum.Material.Neon, 0.945)
            table.insert(FX.lamps, {p = beam, base = 0.945})
            cable(Vector3.new(x * 1.9, 6.2, -9.8), Vector3.new(x, 4.7, -7.0), 0.8)
        end
        spot(-3.9)
        spot(3.9)

        -- аварийная красная лампа
        local bulb = mk(WorldModel, "ball", Vector3.new(0.35, 0.35, 0.35), CFrame.new(-7.6, 4.3, -10.0), Color3.fromRGB(255, 40, 30), Enum.Material.Neon, 0.05)
        table.insert(FX.lamps, {p = bulb, base = 0.05})
        local bulbGlow = mk(WorldModel, "ball", Vector3.new(1.3, 1.3, 1.3), CFrame.new(-7.6, 4.3, -10.0), Color3.fromRGB(255, 30, 20), Enum.Material.Neon, 0.93)
        table.insert(FX.lamps, {p = bulbGlow, base = 0.93})

        -- слева: ящик, колонка и старая магнитола
        block(Vector3.new(3.2, 3.4, 2.6), Vector3.new(-7.9, -1.4, -4.2), WOOD, Enum.Material.Wood)
        block(Vector3.new(2.6, 3.0, 1.9), Vector3.new(-7.9, 1.8, -4.2), Color3.fromRGB(26, 25, 27), Enum.Material.Metal)
        mk(WorldModel, "cylZ", Vector3.new(1.7, 1.7, 0.1), CFrame.new(-7.9, 1.35, -3.22), Color3.fromRGB(10, 10, 11), Enum.Material.Metal)
        mk(WorldModel, "cylZ", Vector3.new(0.8, 0.8, 0.12), CFrame.new(-7.9, 1.35, -3.2), Color3.fromRGB(46, 40, 38), Enum.Material.Metal)
        mk(WorldModel, "cylZ", Vector3.new(0.5, 0.5, 0.1), CFrame.new(-7.9, 2.65, -3.22), Color3.fromRGB(10, 10, 11), Enum.Material.Metal)
        block(Vector3.new(2.4, 0.8, 1.3), Vector3.new(-7.9, 3.7, -4.2), Color3.fromRGB(70, 66, 62), Enum.Material.Metal)
        block(Vector3.new(0.5, 0.18, 0.04), Vector3.new(-8.5, 3.7, -3.54), Color3.fromRGB(255, 50, 40), Enum.Material.Neon, 0.3)

        -- ТЁМНЫЙ ЗАДНИК: Дилер выходит из темноты, как в оригинале (виден только свет на лице и руках)
        FX.backdrop = block(Vector3.new(14.5, 20, 0.3), Vector3.new(0, 4, -8.4), Color3.fromRGB(4, 3, 4), Enum.Material.Fabric)

        -- СТОЛ как в Buckshot Roulette: УЗКИЙ и длинный, сидим друг напротив друга (как в настольный теннис)
        local TW, TL = 6.8, 11.2
        block(Vector3.new(TW, 0.4, TL), Vector3.new(0, -0.2, 0), Color3.fromRGB(40, 72, 48), Enum.Material.Fabric)
        block(Vector3.new(TW - 0.8, 3.2, TL - 0.8), Vector3.new(0, -2.0, 0), Color3.fromRGB(18, 12, 10), Enum.Material.Wood)
        block(Vector3.new(TW + 0.9, 0.5, 0.45), Vector3.new(0, 0.02, TL / 2 + 0.2), WOOD, Enum.Material.Wood)
        block(Vector3.new(TW + 0.9, 0.5, 0.45), Vector3.new(0, 0.02, -TL / 2 - 0.2), WOOD, Enum.Material.Wood)
        block(Vector3.new(0.45, 0.5, TL + 0.9), Vector3.new(TW / 2 + 0.2, 0.02, 0), WOOD, Enum.Material.Wood)
        block(Vector3.new(0.45, 0.5, TL + 0.9), Vector3.new(-TW / 2 - 0.2, 0.02, 0), WOOD, Enum.Material.Wood)

        -- боковая полка справа: на ней заряды (HP) игрока и Дилера
        block(Vector3.new(3.3, 0.4, 9.6), Vector3.new(5.65, -0.2, 0), Color3.fromRGB(22, 22, 26), Enum.Material.Metal)
        block(Vector3.new(2.9, 3.0, 9.0), Vector3.new(5.65, -2.0, 0), Color3.fromRGB(14, 12, 12), Enum.Material.Wood)

        -- ЭКРАН СПРАВА (как в оригинале): ЭЛТ-табло зарядов. Сверху MONSTER (красные), снизу YOU (зелёные)
        -- ТАБЛО КАК В ОРИГИНАЛЕ (фото 3): ржавая рамка, чёрное стекло, бледно-зелёные надписи, молнии = HP
        block(Vector3.new(3.6, 0.7, 2.4), Vector3.new(6.2, 0.35, 0), Color3.fromRGB(58, 34, 28), Enum.Material.Metal)
        do
            local PCF = FX.PANEL_CF
            local RUST = Color3.fromRGB(106, 58, 42)
            local RUST_D = Color3.fromRGB(72, 40, 32)
            local GLOW = Color3.fromRGB(205, 255, 205)
            local NEON = Enum.Material.Neon
            local METALM = Enum.Material.Metal
            local collect = nil -- в какой список складывать детали (HP / раунды)
            local function pc(kind, size, cf, color, mat, tr)
                local p = mk(WorldModel, kind, size, PCF * cf, color, mat, tr)
                if collect then table.insert(collect, p) end
                return p
            end
            -- рамка и стекло
            pc("block", Vector3.new(5.2, 2.3, 0.4), CFrame.new(0, 0, 0), RUST, METALM)
            pc("block", Vector3.new(5.2, 0.14, 0.52), CFrame.new(0, 1.16, 0.02), RUST_D, METALM)
            pc("block", Vector3.new(5.2, 0.14, 0.52), CFrame.new(0, -1.16, 0.02), RUST_D, METALM)
            pc("block", Vector3.new(0.14, 2.3, 0.52), CFrame.new(2.63, 0, 0.02), RUST_D, METALM)
            pc("block", Vector3.new(0.14, 2.3, 0.52), CFrame.new(-2.63, 0, 0.02), RUST_D, METALM)
            pc("block", Vector3.new(4.9, 1.95, 0.1), CFrame.new(0, 0, 0.2), Color3.fromRGB(3, 9, 6), Enum.Material.SmoothPlastic)
            pc("block", Vector3.new(4.9, 1.95, 0.02), CFrame.new(0, 0, 0.255), GLOW, NEON, 0.955)
            for _, sx in ipairs({-1, 1}) do
                for _, sy in ipairs({-1, 1}) do
                    pc("cylZ", Vector3.new(0.16, 0.16, 0.08), CFrame.new(sx * 2.54, sy * 1.08, 0.3), Color3.fromRGB(150, 140, 120), METALM)
                end
            end
            FX.screenHP = {}
            collect = FX.screenHP
            -- линии разметки табло
            pc("block", Vector3.new(0.05, 1.9, 0.03), CFrame.new(0, 0, 0.27), GLOW, NEON)
            pc("block", Vector3.new(4.9, 0.04, 0.03), CFrame.new(0, 0.28, 0.27), GLOW, NEON)
            -- батарейки сверху (как на фото)
            for i = 0, 3 do
                local x = -1.8 + i * 1.2
                pc("cylY", Vector3.new(0.85, 1.0, 0.85), CFrame.new(x, 1.7, -0.15), Color3.fromRGB(112, 96, 80), METALM)
                pc("cylY", Vector3.new(0.92, 0.14, 0.92), CFrame.new(x, 1.4, -0.15), Color3.fromRGB(70, 58, 48), METALM)
                pc("cylY", Vector3.new(0.4, 0.16, 0.4), CFrame.new(x, 2.28, -0.15), Color3.fromRGB(176, 120, 70), METALM)
            end

            -- мини-шрифт 5x7 (латиница, цифры, подчёркивание) для имён
            local FONT = {
                A = "01110/10001/10001/11111/10001/10001/10001", B = "11110/10001/10001/11110/10001/10001/11110",
                C = "01110/10001/10000/10000/10000/10001/01110", D = "11110/10001/10001/10001/10001/10001/11110",
                E = "11111/10000/10000/11110/10000/10000/11111", F = "11111/10000/10000/11110/10000/10000/10000",
                G = "01110/10001/10000/10111/10001/10001/01111", H = "10001/10001/10001/11111/10001/10001/10001",
                I = "01110/00100/00100/00100/00100/00100/01110", J = "00111/00010/00010/00010/00010/10010/01100",
                K = "10001/10010/10100/11000/10100/10010/10001", L = "10000/10000/10000/10000/10000/10000/11111",
                M = "10001/11011/10101/10101/10001/10001/10001", N = "10001/11001/10101/10011/10001/10001/10001",
                O = "01110/10001/10001/10001/10001/10001/01110", P = "11110/10001/10001/11110/10000/10000/10000",
                Q = "01110/10001/10001/10001/10101/10010/01101", R = "11110/10001/10001/11110/10100/10010/10001",
                S = "01111/10000/10000/01110/00001/00001/11110", T = "11111/00100/00100/00100/00100/00100/00100",
                U = "10001/10001/10001/10001/10001/10001/01110", V = "10001/10001/10001/10001/10001/01010/00100",
                W = "10001/10001/10001/10101/10101/10101/01010", X = "10001/10001/01010/00100/01010/10001/10001",
                Y = "10001/10001/01010/00100/00100/00100/00100", Z = "11111/00001/00010/00100/01000/10000/11111",
                ["0"] = "01110/10001/10011/10101/11001/10001/01110", ["1"] = "00100/01100/00100/00100/00100/00100/01110",
                ["2"] = "01110/10001/00001/00010/00100/01000/11111", ["3"] = "11110/00001/00001/01110/00001/00001/11110",
                ["4"] = "00010/00110/01010/10010/11111/00010/00010", ["5"] = "11111/10000/11110/00001/00001/10001/01110",
                ["6"] = "00110/01000/10000/11110/10001/10001/01110", ["7"] = "11111/00001/00010/00100/01000/01000/01000",
                ["8"] = "01110/10001/10001/01110/10001/10001/01110", ["9"] = "01110/10001/10001/01111/00001/00010/01100",
                ["_"] = "00000/00000/00000/00000/00000/00000/11111",
            }
            local function drawText(txt, x0, y0, pix, alignRight)
                local n = #txt
                local width = n * 6 * pix - pix
                local startX = alignRight and (x0 - width) or x0
                for ci = 1, n do
                    local g = FONT[txt:sub(ci, ci)]
                    if g then
                        local ry = 0
                        for row in g:gmatch("[^/]+") do
                            ry += 1
                            local cx = 1
                            while cx <= 5 do
                                if row:sub(cx, cx) == "1" then
                                    local ex = cx
                                    while ex < 5 and row:sub(ex + 1, ex + 1) == "1" do ex += 1 end
                                    local w = (ex - cx + 1) * pix
                                    local px = startX + ((ci - 1) * 6 + (cx - 1)) * pix + w / 2
                                    local py = y0 - (ry - 1) * pix - pix / 2
                                    pc("block", Vector3.new(w * 0.94, pix * 0.94, 0.03), CFrame.new(px, py, 0.27), GLOW, NEON)
                                    cx = ex + 1
                                else
                                    cx += 1
                                end
                            end
                        end
                    end
                end
            end
            local pix = math.min(0.07, 2.2 / (math.max(#FX.nick, 6) * 6))
            drawText("DEALER", -2.3, 0.85, pix, false)
            drawText(FX.nick, 2.3, 0.85, pix, true)   -- имя = твой ник в Роблоксе
            collect = nil

            -- молнии (по 6 мест на сторону, горят столько, сколько HP)
            local function makeBolt(x, y)
                local s = 1.25
                local ang = CFrame.Angles(0, 0, math.rad(-22))
                local parts = {
                    pc("block", Vector3.new(0.09 * s, 0.26 * s, 0.03), CFrame.new(x + 0.05 * s, y + 0.13 * s, 0.27) * ang, GLOW, NEON),
                    pc("block", Vector3.new(0.2 * s, 0.07 * s, 0.03), CFrame.new(x, y, 0.27), GLOW, NEON),
                    pc("block", Vector3.new(0.09 * s, 0.26 * s, 0.03), CFrame.new(x - 0.05 * s, y - 0.13 * s, 0.27) * ang, GLOW, NEON),
                }
                return {parts = parts, world = (PCF * CFrame.new(x, y, 0.3)).Position}
            end
            for i = 1, 6 do
                FX.Panel.Dealer.bolts[i] = makeBolt(-2.15 + (i - 1) * 0.4, -0.38)
                FX.Panel.Player.bolts[i] = makeBolt(2.15 - (i - 1) * 0.4, -0.38)
            end

            -- ЭКРАН РАУНДА: I, II, череп и кружки под ними (рисуется прямо на этом табло)
            do
                local all, dots = {}, {}
                collect = all
                local function bar(x, y, w, h) pc("block", Vector3.new(w, h, 0.03), CFrame.new(x, y, 0.28), GLOW, NEON, 1) end
                local function roman(cx, n)
                    for k = 1, n do bar(cx + (k - (n + 1) / 2) * 0.28, 0.32, 0.11, 0.66) end
                    bar(cx, 0.68, 0.18 + n * 0.24, 0.08)
                    bar(cx, -0.04, 0.18 + n * 0.24, 0.08)
                end
                roman(-1.6, 1)
                roman(0, 2)
                -- череп финального раунда (пиксельный)
                for r, row in ipairs({"0111110", "1111111", "1001001", "1001001", "1110111", "0111110", "0101010"}) do
                    for c = 1, 7 do
                        if row:sub(c, c) == "1" then bar(1.6 + (c - 4) * 0.115, 0.67 - (r - 1) * 0.115, 0.108, 0.108) end
                    end
                end
                for i = 1, 3 do
                    local cx = (i - 2) * 1.6
                    for k = 0, 13 do
                        local a = k / 14 * math.pi * 2
                        pc("block", Vector3.new(0.15, 0.055, 0.03), CFrame.new(cx + math.cos(a) * 0.3, -0.52 + math.sin(a) * 0.3, 0.28) * CFrame.Angles(0, 0, a + math.pi / 2), GLOW, NEON, 1)
                    end
                end
                collect = nil
                for i = 1, 3 do
                    dots[i] = pc("cylZ", Vector3.new(0.34, 0.34, 0.03), CFrame.new((i - 2) * 1.6, -0.52, 0.28), GLOW, NEON, 1)
                end
                local token = 0
                local function setMode(on, round)
                    FX.roundMode = on
                    for _, p in ipairs(FX.screenHP) do p.Transparency = on and 1 or 0 end
                    for _, side in ipairs({"Player", "Dealer"}) do
                        for _, b in ipairs(FX.Panel[side].bolts) do
                            for _, p in ipairs(b.parts) do p.Transparency = (not on and b.alive) and 0 or 1 end
                        end
                    end
                    for _, p in ipairs(all) do p.Transparency = on and 0 or 1 end
                    for i, d in ipairs(dots) do d.Transparency = (on and i == round) and 0 or 1 end
                end
                function FX.showRound(round)
                    token += 1
                    local my = token
                    FX.roundUntil = os.clock() + 3.4
                    setMode(true, round)
                    playSFX(SOUNDS.Rack, 1.1)
                    task.delay(3.4, function()
                        if my == token then setMode(false) end
                    end)
                end
            end
        end

        -- РАЗМЕТКА НА СТОЛЕ: яркие толстые линии, как в оригинале
        local LINE = Color3.fromRGB(150, 146, 122) -- матовая краска, без свечения
        local LW = 0.09
        local function ln(x1, z1, x2, z2)
            local a, b = Vector3.new(x1, 0.022, z1), Vector3.new(x2, 0.022, z2)
            mk(WorldModel, "block", Vector3.new(LW, 0.02, (b - a).Magnitude + LW), CFrame.lookAt((a + b) / 2, b), LINE, Enum.Material.SmoothPlastic, 0.3)
        end
        local function rect(x1, z1, x2, z2)
            ln(x1, z1, x2, z1); ln(x2, z1, x2, z2); ln(x2, z2, x1, z2); ln(x1, z2, x1, z1)
        end
        rect(-3.05, -5.2, 3.05, 5.2)           -- рамка стола
        ln(-3.05, -1.75, 3.05, -1.75)          -- граница зоны Дилера
        ln(-3.05, 1.75, 3.05, 1.75)            -- граница твоей зоны
        for _, zc in ipairs({-4.3, -2.7, 2.7, 4.3}) do   -- 8 ячеек для предметов у каждого: слева 4 и справа 4
            for _, cx in ipairs(FX.SLOT_X) do
                rect(cx - 0.62, zc - 0.7, cx + 0.62, zc + 0.7)
            end
        end
        rect(-2.48, -1.3, 2.48, -0.6)          -- ряд из 8 ячеек для патронов
        for k = 1, 7 do ln(-2.48 + k * 0.62, -1.3, -2.48 + k * 0.62, -0.6) end
        rect(-2.75, 0.2, 2.75, 1.4)            -- место для дробовика
        for k = -2, 2 do ln(k * 1.0 - 0.25, 0.0 - 0.0, k * 1.0 + 0.25, 0.0) end -- пунктир по центру

    end

    -- 3D-ДРОБОВИК
    local GUN_S = 1.35
    local GunRoot = Instance.new("Part")
    GunRoot.Name = "GunRoot"
    GunRoot.Size = Vector3.new(0.2, 0.2, 0.2)
    GunRoot.Transparency = 1
    GunRoot.Anchored = true
    GunRoot.CanCollide = false
    local REST_CF = CFrame.new(0.4, 0.55, 0.8) * CFrame.Angles(0, math.rad(90), 0)
    GunRoot.CFrame = REST_CF
    GunRoot.Parent = WorldModel

    local gunParts = {}
    local gunTip, gunMuzzle, gunCut
    FX.pumpOff = 0
    local gunSawedOverride = false
    do
        local function gp(kind, size, offset, color, material, transparency)
            local p = mk(WorldModel, kind, size * GUN_S, GunRoot.CFrame * CFrame.new(offset * GUN_S), color, material or Enum.Material.Metal, transparency)
            table.insert(gunParts, {p = p, rel = GunRoot.CFrame:ToObjectSpace(p.CFrame)})
            return p
        end
        gp("block", Vector3.new(0.26, 0.36, 1.1), Vector3.new(0, -0.05, 1.1), Color3.fromRGB(95, 50, 25), Enum.Material.Wood)
        gp("block", Vector3.new(0.28, 0.4, 0.08), Vector3.new(0, -0.05, 1.68), Color3.fromRGB(30, 30, 34))
        gp("block", Vector3.new(0.3, 0.32, 0.9), Vector3.new(0, 0.05, 0.2), Color3.fromRGB(35, 35, 40))
        gp("block", Vector3.new(0.1, 0.05, 0.35), Vector3.new(0, -0.14, 0.15), Color3.fromRGB(10, 10, 12))
        FX.pump = gp("block", Vector3.new(0.34, 0.28, 0.8), Vector3.new(0, -0.05, -0.75), Color3.fromRGB(85, 45, 20), Enum.Material.Wood)
        gp("cylZ", Vector3.new(0.2, 0.2, 1.3), Vector3.new(0, 0.1, -0.8), Color3.fromRGB(55, 55, 62))
        gunTip = gp("cylZ", Vector3.new(0.19, 0.19, 0.8), Vector3.new(0, 0.1, -1.8), Color3.fromRGB(62, 62, 70))
        gunMuzzle = gp("ball", Vector3.new(0.13, 0.13, 0.13), Vector3.new(0, 0.1, -2.2), Color3.fromRGB(0, 0, 0))
        gunCut = gp("cylZ", Vector3.new(0.215, 0.215, 0.04), Vector3.new(0, 0.1, -1.42), Color3.fromRGB(215, 215, 220), Enum.Material.Metal, 1)
        gp("block", Vector3.new(0.05, 0.07, 0.05), Vector3.new(0, 0.24, -1.0), Color3.fromRGB(200, 200, 205))
        -- v9: латунные кольца, мушка, патроны на цевье, скоба
        gp("cylZ", Vector3.new(0.215, 0.215, 0.05), Vector3.new(0, 0.1, -0.3), Color3.fromRGB(205, 165, 70))
        gp("cylZ", Vector3.new(0.215, 0.215, 0.05), Vector3.new(0, 0.1, -1.1), Color3.fromRGB(205, 165, 70))
        gp("ball", Vector3.new(0.05, 0.05, 0.05), Vector3.new(0, 0.29, -1.0), Color3.fromRGB(255, 60, 40), Enum.Material.Neon)
        for k = 0, 3 do
            gp("cylZ", Vector3.new(0.09, 0.09, 0.2), Vector3.new(0.17, 0.0, 0.9 + k * 0.12), (k % 2 == 0) and Color3.fromRGB(190, 40, 40) or Color3.fromRGB(205, 165, 70))
        end
        gp("block", Vector3.new(0.31, 0.02, 0.5), Vector3.new(0, 0.205, 0.2), Color3.fromRGB(205, 165, 70))
    end

    local function syncGunParts()
        local cf = GunRoot.CFrame
        for _, g in ipairs(gunParts) do
            if g.p == FX.pump then
                g.p.CFrame = cf * g.rel * CFrame.new(0, 0, FX.pumpOff * GUN_S)
            else
                g.p.CFrame = cf * g.rel
            end
        end
        local sawed = GameState.SawActive or gunSawedOverride
        gunTip.Transparency = sawed and 1 or 0
        gunMuzzle.Transparency = sawed and 1 or 0
        gunCut.Transparency = sawed and 0 or 1
    end
    syncGunParts()
    -- мягкая подсветка под дробовиком, когда его можно взять
    local GunHalo = {Transparency = 1} -- подсветка дробовика убрана

    -- 3D-ДИЛЕР как в оригинале: бледная вытянутая голова, ПУСТЫЕ чёрные глазницы, огромная улыбка с рядами зубов
    local SKIN = Color3.fromRGB(196, 188, 172)
    local SKIN_D = Color3.fromRGB(118, 110, 100)
    local SUIT = Color3.fromRGB(19, 15, 17)
    local BONE = Color3.fromRGB(238, 232, 210)
    local HR = 0.95
    local HY = 1.1
    local MOUTH_N = 17
    local DealerBody = newModel(WorldModel)
    local DealerHead = newModel(WorldModel)
    local headBall
    local eyeSet, mouthTop, mouthBot, mouthBack = {}, {}, {}, {}
    do
        -- тела у Дилера нет: из темноты видны только голова и руки (как в оригинале)

        -- голова: лысая, вытянутая
        headBall = mk(DealerHead, "ball", Vector3.new(HR * 2, HY * 2, HR * 2), CFrame.new(), SKIN)
        mk(DealerHead, "ball", Vector3.new(1.3, 0.9, 1.1), CFrame.new(0, -0.8, 0.2), SKIN)
        mk(DealerHead, "ball", Vector3.new(1.5, 0.3, 0.5), CFrame.new(0, 0.55, 0.62), SKIN_D, nil, 0.35)
        mk(DealerHead, "ball", Vector3.new(0.2, 0.42, 0.26), CFrame.new(0, -0.02, 0.92), SKIN)
        for _, sgn in ipairs({-1, 1}) do
            mk(DealerHead, "ball", Vector3.new(0.2, 0.55, 0.16), CFrame.new(0.95 * sgn, 0, 0), SKIN)
            mk(DealerHead, "ball", Vector3.new(0.07, 0.16, 0.06), CFrame.new(0.07 * sgn, -0.1, 0.93), Color3.fromRGB(40, 30, 28))
            -- тёмные впадины вокруг глазниц
            mk(DealerHead, "ball", Vector3.new(0.8, 0.95, 0.3), CFrame.new(0.36 * sgn, 0.18, 0.68), SKIN_D)
            -- ПУСТЫЕ глазницы: чёрные провалы без зрачков
            mk(DealerHead, "ball", Vector3.new(0.62, 0.78, 0.34), CFrame.new(0.36 * sgn, 0.18, 0.74), Color3.fromRGB(2, 1, 1))
            local e = {sgn = sgn}
            e.eye = mk(DealerHead, "ball", Vector3.new(0.5, 0.62, 0.2), CFrame.new(0.36 * sgn, 0.18, 0.82), Color3.fromRGB(3, 2, 2))
            e.pupil = mk(DealerHead, "ball", Vector3.new(0.05, 0.05, 0.05), CFrame.new(0.36 * sgn, 0.18, 0.95), Color3.fromRGB(3, 2, 2), nil, 1)
            e.brow = mk(DealerHead, "block", Vector3.new(0.58, 0.07, 0.08), CFrame.new(0.36 * sgn, 0.62, 0.82), SKIN_D, nil, 0.3)
            e.x1 = mk(DealerHead, "block", Vector3.new(0.46, 0.07, 0.06), CFrame.new(0.36 * sgn, 0.18, 0.95) * CFrame.Angles(0, 0, math.rad(45)), BONE, nil, 1)
            e.x2 = mk(DealerHead, "block", Vector3.new(0.46, 0.07, 0.06), CFrame.new(0.36 * sgn, 0.18, 0.95) * CFrame.Angles(0, 0, math.rad(-45)), BONE, nil, 1)
            table.insert(eyeSet, e)
        end
        -- ОГРОМНАЯ УЛЫБКА: два ряда ровных зубов поверх тёмной пасти
        for i = 1, MOUTH_N do
            mouthBack[i] = mk(DealerHead, "block", Vector3.new(0.1, 0.4, 0.06), CFrame.new(), Color3.fromRGB(16, 3, 3))
            mouthTop[i] = mk(DealerHead, "block", Vector3.new(0.1, 0.24, 0.08), CFrame.new(), BONE)
            mouthBot[i] = mk(DealerHead, "block", Vector3.new(0.1, 0.22, 0.08), CFrame.new(), Color3.fromRGB(222, 214, 190))
        end
    end

    -- Настроение Дилера (игровой код пишет DealerFace.Text = "[ 😵 _ 😵 ]" - здесь это превращается в мимику)
    local MOODS = {
        neutral = {curve = 0.26, width = 1.0, open = 0.05, eyeL = 1, eyeR = 1, pupil = 1, brow = 0, pitch = 0, xeyes = 0, red = 0},
        inspect = {curve = 0.30, width = 1.0, open = 0.05, eyeL = 1.1, eyeR = 0.85, pupil = 0.8, brow = 0, pitch = 0.03, xeyes = 0, red = 0},
        smirk = {curve = 0.34, width = 1.0, open = 0.05, eyeL = 0.75, eyeR = 0.75, pupil = 1, brow = -0.15, pitch = 0, xeyes = 0, red = 0},
        hurt = {curve = 0.30, width = 1.0, open = 0.05, eyeL = 1, eyeR = 1, pupil = 1, brow = 0, pitch = 0, xeyes = 0, red = 0},
        evil = {curve = 0.42, width = 1.05, open = 0.14, eyeL = 0.95, eyeR = 0.95, pupil = 0.6, brow = -0.4, pitch = 0.05, xeyes = 0, red = 1},
        dead = {curve = 0.26, width = 1.0, open = 0.05, eyeL = 1, eyeR = 1, pupil = 1, brow = 0, pitch = 0, xeyes = 0, red = 0},
    }
    local moodCur = {}
    for k, v in pairs(MOODS.neutral) do moodCur[k] = v end
    local moodTarget = MOODS.neutral

    local function setDealerMoodFromText(txt)
        local key = "neutral"
        if txt:find("😵", 1, true) then key = "hurt"
        elseif txt:find("😈", 1, true) then key = "evil"
        elseif txt:find("🧐", 1, true) then key = "inspect"
        elseif txt:find("😏", 1, true) then key = "smirk"
        elseif txt:find("❌", 1, true) then key = "dead" end
        moodTarget = MOODS[key]
        FX.Dealer.laugh = (key == "evil" or key == "smirk") and 1 or 0
        if key == "hurt" then FX.Dealer.kick = 1 elseif key == "dead" then FX.Dealer.kick = 1.6 end
        if key == "dead" then
            headBall.Color = Color3.fromRGB(88, 84, 82)
        elseif key == "hurt" then
            headBall.Color = Color3.fromRGB(205, 90, 80)
            TweenService:Create(headBall, TweenInfo.new(0.7), {Color = SKIN}):Play()
        else
            headBall.Color = SKIN
        end
    end

    local DealerFace = setmetatable({}, {
        __newindex = function(_, key, value)
            if key == "Text" then setDealerMoodFromText(tostring(value)) end
        end
    })

    local blinkT, nextBlink = 0, 3
    local function updateDealerFace(headCF)
        local m = moodCur
        local blinkK = (blinkT > 0) and 0.12 or 1
        local isX = false -- крестиков в глазах больше нет, только пустые чёрные глазницы
        for i, e in ipairs(eyeSet) do
            local sc = ((i == 1) and m.eyeL or m.eyeR) * blinkK
            e.eye.Size = Vector3.new(0.5, 0.62 * math.max(0.05, sc), 0.2)
            e.eye.CFrame = headCF * CFrame.new(0.36 * e.sgn, 0.18, 0.82)
            e.eye.Color = Color3.fromRGB(3, 2, 2):Lerp(Color3.fromRGB(80, 0, 0), m.red)
            e.eye.Transparency = isX and 1 or 0
            e.pupil.CFrame = headCF * CFrame.new(0.36 * e.sgn, 0.18, 0.95)
            e.x1.Transparency = isX and 0 or 1
            e.x2.Transparency = isX and 0 or 1
            e.x1.CFrame = headCF * CFrame.new(0.36 * e.sgn, 0.18, 0.95) * CFrame.Angles(0, 0, math.rad(45))
            e.x2.CFrame = headCF * CFrame.new(0.36 * e.sgn, 0.18, 0.95) * CFrame.Angles(0, 0, math.rad(-45))
            e.brow.CFrame = headCF * CFrame.new(0.36 * e.sgn, 0.62 + m.brow * 0.06, 0.82) * CFrame.Angles(0, 0, -e.sgn * m.brow * 0.6)
        end
        local halfW = 0.9 * m.width
        local rise = m.curve * 1.2
        local baseY = -0.4
        local span = 2 * halfW / (MOUTH_N - 1)
        local thT, thB = 0.24, 0.22
        for i = 1, MOUTH_N do
            local u = (i - (MOUTH_N + 1) / 2) / ((MOUTH_N - 1) / 2)
            local mx = u * halfW
            local my = baseY + rise * (u * u)
            local inside = 1 - (mx / HR) ^ 2 - (my / HY) ^ 2
            local zt = HR * math.sqrt(math.max(0.0016, inside)) + 0.02
            local pos = Vector3.new(mx, my, zt)
            local normal = Vector3.new(mx / (HR * HR), my / (HY * HY), zt / (HR * HR))
            local face = CFrame.lookAt(pos, pos + normal)
            local o = m.open + FX.Dealer.laugh * 0.07 * math.abs(math.sin(os.clock() * 13))
            mouthBack[i].Size = Vector3.new(span * 1.12, o + thT + thB, 0.06)
            mouthBack[i].CFrame = headCF * face * CFrame.new(0, 0, 0.03)
            mouthTop[i].Size = Vector3.new(span * 0.86, thT, 0.08)
            mouthTop[i].CFrame = headCF * face * CFrame.new(0, o * 0.5 + thT * 0.5 - 0.02, -0.03)
            mouthBot[i].Size = Vector3.new(span * 0.86, thB, 0.08)
            mouthBot[i].CFrame = headCF * face * CFrame.new(0, -o * 0.5 - thB * 0.5 + 0.02, -0.03)
        end
    end

    -- ЧАСТИЦЫ (искры, осколки, вспышки)
    local particles = {}
    local function emit(pos, count, color, speed, life, size, grav)
        for _ = 1, count do
            if #particles > 140 then break end
            local p = mk(WorldModel, "ball", Vector3.new(size, size, size), CFrame.new(pos), color, Enum.Material.Neon)
            local dir = Vector3.new(math.random() - 0.5, math.random() * 0.9 + 0.25, math.random() - 0.5).Unit
            local l = life * (0.6 + math.random() * 0.6)
            table.insert(particles, {p = p, v = dir * (speed * (0.5 + math.random())), life = l, max = l, g = grav})
        end
    end
    FX.emit = emit
-- КОНЕЦ ЧАСТИ 2В
-- НАЧАЛО ЧАСТИ 2Г (интерфейс поверх 3D: виньетка, подписи HP, кнопки выстрела)
    -- МУЗЫКА "General Release": экран трясётся в такт реальной громкости трека (PlaybackLoudness)
    local MusicSound
    if MUSIC_ID ~= "" then
        MusicSound = Instance.new("Sound")
        MusicSound.Name = "GeneralRelease"
        MusicSound.SoundId = MUSIC_ID
        MusicSound.Looped = true
        MusicSound.Volume = MUSIC_VOLUME
        MusicSound.Parent = ScreenGui -- играть начнёт после нажатия PLAY в меню
    end
    local musicEnv, musicKick = 0, 0

    local function vignette(pos, size, rot)
        local f = Instance.new("Frame", Viewport)
        f.Position = pos
        f.Size = size
        f.BackgroundColor3 = Color3.new(0, 0, 0)
        f.BorderSizePixel = 0
        f.ZIndex = 2
        local g = Instance.new("UIGradient", f)
        g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
        g.Rotation = rot
    end
    vignette(UDim2.new(0, 0, 0, 0), UDim2.new(0, 90, 1, 0), 0)
    vignette(UDim2.new(1, -90, 0, 0), UDim2.new(0, 90, 1, 0), 180)
    vignette(UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 36), 90)
    vignette(UDim2.new(0, 0, 1, -36), UDim2.new(1, 0, 0, 36), -90)

    -- СУБТИТРЫ внизу (как в оригинале) вместо журнала: чёрная плашка, печатающийся моно-шрифт
    local SubFrame = Instance.new("Frame", Viewport)
    SubFrame.AnchorPoint = Vector2.new(0.5, 1)
    SubFrame.Position = UDim2.new(0.5, 0, 1, -10)
    SubFrame.Size = UDim2.new(0.84, 0, 0, 0)
    SubFrame.AutomaticSize = Enum.AutomaticSize.Y
    SubFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    SubFrame.BackgroundTransparency = 0.04
    SubFrame.BorderSizePixel = 0
    SubFrame.ZIndex = 9
    SubFrame.Visible = false
    local subStroke = Instance.new("UIStroke", SubFrame)
    subStroke.Color = Color3.fromRGB(90, 90, 80)
    subStroke.Thickness = 1
    local subPad = Instance.new("UIPadding", SubFrame)
    subPad.PaddingTop = UDim.new(0, 7)
    subPad.PaddingBottom = UDim.new(0, 7)
    subPad.PaddingLeft = UDim.new(0, 12)
    subPad.PaddingRight = UDim.new(0, 12)
    local SubText = Instance.new("TextLabel", SubFrame)
    SubText.Size = UDim2.new(1, 0, 0, 0)
    SubText.AutomaticSize = Enum.AutomaticSize.Y
    SubText.BackgroundTransparency = 1
    SubText.Font = Enum.Font.Code
    SubText.TextSize = 15
    SubText.TextColor3 = Color3.fromRGB(238, 236, 222)
    SubText.TextWrapped = true
    SubText.RichText = true
    SubText.TextXAlignment = Enum.TextXAlignment.Center
    SubText.ZIndex = 10

    local function stripEmoji(str)
        str = str:gsub("—", "-"):gsub("–", "-")
        str = str:gsub("[\240-\247][\128-\191]*", "")
        str = str:gsub("[\224-\239][\128-\191][\128-\191]", "")
        str = str:gsub("%s+", " ")
        return (str:gsub("^%s+", ""):gsub("%s+$", ""))
    end
    local function upperRu(str)
        return (str:gsub(utf8.charpattern, function(c)
            local ok, cp = pcall(utf8.codepoint, c)
            if not ok then return c end
            if cp >= 0x430 and cp <= 0x44F then return utf8.char(cp - 32) end
            if cp == 0x451 then return utf8.char(0x401) end
            if cp < 128 then return c:upper() end
            return c
        end))
    end

    local subToken = 0
    -- rich=true: текст уже готов (можно <font color=...>), startAt: сколько символов уже напечатано
    local function subtitle(txt, color, rich, startAt)
        subToken += 1
        local my = subToken
        local shown = rich and txt or upperRu(stripEmoji(txt))
        local visible = shown:gsub("<[^>]->", "")
        local n = utf8.len(visible) or #visible
        SubText.TextColor3 = Color3.fromRGB(238, 236, 222):Lerp(color or Color3.fromRGB(238, 236, 222), 0.3)
        SubText.Text = shown
        SubText.TextTransparency = 0
        SubFrame.BackgroundTransparency = 0.04
        subStroke.Transparency = 0
        SubText.MaxVisibleGraphemes = startAt or 0
        SubFrame.Visible = true
        task.spawn(function()
            for i = (startAt or 0) + 1, n do
                if my ~= subToken then return end
                SubText.MaxVisibleGraphemes = i
                task.wait(0.016)
            end
            SubText.MaxVisibleGraphemes = -1
            task.wait(3.4 + n * 0.02)
            if my ~= subToken then return end
            TweenService:Create(SubText, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
            TweenService:Create(SubFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
            TweenService:Create(subStroke, TweenInfo.new(0.5), {Transparency = 1}):Play()
            task.wait(0.55)
            if my == subToken then SubFrame.Visible = false end
        end)
    end

    -- кнопка музыки в верхней панели
    local MusicBtn = Instance.new("TextButton", TopBar)
    MusicBtn.Size = UDim2.new(0, 28, 0, 24)
    MusicBtn.Position = UDim2.new(1, -96, 0, 5)
    MusicBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
    MusicBtn.Text = "M"
    MusicBtn.TextColor3 = Color3.new(1, 1, 1)
    MusicBtn.Font = Enum.Font.Code
    Instance.new("UICorner", MusicBtn).CornerRadius = UDim.new(0, 4)
    MusicBtn.MouseButton1Click:Connect(function()
        if not MusicSound then
            subtitle("Вставь ID трека General Release в переменную MUSIC_ID в начале скрипта", Color3.fromRGB(255, 210, 120))
            return
        end
        if MusicSound.IsPlaying then
            MusicSound:Pause()
            MusicBtn.TextColor3 = Color3.fromRGB(120, 120, 120)
        else
            MusicSound:Resume()
            MusicBtn.TextColor3 = Color3.new(1, 1, 1)
        end
    end)

    -- кнопка FULL SCREEN: окно увеличивается на весь экран (UIScale), повторное нажатие возвращает как было
    do
        local FsBtn = Instance.new("TextButton", TopBar)
        FsBtn.Size = UDim2.new(0, 28, 0, 24)
        FsBtn.Position = UDim2.new(1, -128, 0, 5)
        FsBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
        FsBtn.Text = "[ ]"
        FsBtn.TextColor3 = Color3.new(1, 1, 1)
        FsBtn.Font = Enum.Font.Code
        FsBtn.TextSize = 13
        Instance.new("UICorner", FsBtn).CornerRadius = UDim.new(0, 4)
        local isFull = false
        local function fitScale()
            local sz = ScreenGui.AbsoluteSize
            return math.max(0.5, math.min(sz.X / 640, sz.Y / 340) * 0.99)
        end
        local function apply(animated)
            MainFrame.Position = UDim2.new(0.5, -320, 0.5, -170)
            local target = isFull and fitScale() or 1
            FsBtn.TextColor3 = isFull and Color3.fromRGB(255, 225, 90) or Color3.new(1, 1, 1)
            if animated then
                TweenService:Create(WinScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = target}):Play()
            else
                WinScale.Scale = target
            end
        end
        FsBtn.MouseButton1Click:Connect(function()
            isFull = not isFull
            apply(true)
        end)
        ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            if isFull and MainFrame.Parent then apply(false) end
        end)
    end

    local DealerHPLabel = Instance.new("TextLabel", Viewport)
    DealerHPLabel.Size = UDim2.new(0, 170, 0, 20)
    DealerHPLabel.Position = UDim2.new(0, 8, 0, 6)
    DealerHPLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    DealerHPLabel.BackgroundTransparency = 0.45
    DealerHPLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    DealerHPLabel.Font = Enum.Font.Code
    DealerHPLabel.TextSize = 13
    DealerHPLabel.TextXAlignment = Enum.TextXAlignment.Left
    DealerHPLabel.ZIndex = 6
    Instance.new("UICorner", DealerHPLabel).CornerRadius = UDim.new(0, 4)
    Instance.new("UIPadding", DealerHPLabel).PaddingLeft = UDim.new(0, 6)

    DealerHPLabel.Visible = false -- подписи слева убраны (HP видно на табло справа)
    local PlayerHPLabel = Instance.new("TextLabel", Viewport)
    PlayerHPLabel.Size = UDim2.new(0, 170, 0, 20)
    PlayerHPLabel.Position = UDim2.new(0, 8, 1, -88)
    PlayerHPLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    PlayerHPLabel.BackgroundTransparency = 0.45
    PlayerHPLabel.TextColor3 = Color3.fromRGB(85, 255, 130)
    PlayerHPLabel.Font = Enum.Font.Code
    PlayerHPLabel.TextSize = 13
    PlayerHPLabel.TextXAlignment = Enum.TextXAlignment.Left
    PlayerHPLabel.ZIndex = 6
    Instance.new("UICorner", PlayerHPLabel).CornerRadius = UDim.new(0, 4)
    Instance.new("UIPadding", PlayerHPLabel).PaddingLeft = UDim.new(0, 6)
    PlayerHPLabel.Visible = false

    local HoverTag = Instance.new("TextLabel", Viewport)
    HoverTag.AnchorPoint = Vector2.new(0.5, 1)
    HoverTag.Size = UDim2.new(0, 0, 0, 18)
    HoverTag.AutomaticSize = Enum.AutomaticSize.X
    HoverTag.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
    HoverTag.BackgroundTransparency = 0.25
    HoverTag.TextColor3 = Color3.fromRGB(255, 235, 150)
    HoverTag.Font = Enum.Font.Code
    HoverTag.TextSize = 12
    HoverTag.ZIndex = 12
    HoverTag.Visible = false
    Instance.new("UICorner", HoverTag).CornerRadius = UDim.new(0, 4)
    local hoverPad = Instance.new("UIPadding", HoverTag)
    hoverPad.PaddingLeft = UDim.new(0, 6)
    hoverPad.PaddingRight = UDim.new(0, 6)

    -- Подсказка предмета (вверху справа)
    local TooltipLabel = Instance.new("TextLabel", Viewport)
    TooltipLabel.AnchorPoint = Vector2.new(1, 0)
    TooltipLabel.Size = UDim2.new(0, 240, 0, 44)
    TooltipLabel.Position = UDim2.new(1, -8, 0, 6)
    TooltipLabel.BackgroundTransparency = 1
    TooltipLabel.Text = ""
    TooltipLabel.TextColor3 = Color3.fromRGB(190, 210, 230)
    TooltipLabel.Font = Enum.Font.Code
    TooltipLabel.TextSize = 11
    TooltipLabel.TextWrapped = true
    TooltipLabel.TextXAlignment = Enum.TextXAlignment.Right
    TooltipLabel.TextYAlignment = Enum.TextYAlignment.Top
    TooltipLabel.ZIndex = 6

    -- ВЫБОР ЦЕЛИ: просто нажимной текст без фона. Появляется, когда ты берёшь дробовик в руки
    local GunCtl = {holder = nil, blend = {Player = 0, Dealer = 0}, arms = {}, hover = false}

    local function makeChoiceText(txt, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 150, 0, 34)
        b.BackgroundTransparency = 1
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.Text = txt
        b.TextColor3 = color
        b.TextStrokeColor3 = Color3.new(0, 0, 0)
        b.TextStrokeTransparency = 0.15
        b.Font = Enum.Font.Code
        b.TextSize = 26
        b.ZIndex = 14
        b.Visible = false
        b.Parent = Viewport
        b.MouseEnter:Connect(function() b.TextSize = 31; b.TextColor3 = Color3.new(1, 1, 1) end)
        b.MouseLeave:Connect(function() b.TextSize = 26; b.TextColor3 = color end)
        return b
    end
    local CHOICE_COL = Color3.fromRGB(190, 184, 170)
    local ChooseDealerBtn = makeChoiceText("ДИЛЕР", CHOICE_COL)
    ChooseDealerBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    ChooseDealerBtn.Position = UDim2.new(0.5, 0, 0.2, 0)
    local ChooseSelfBtn = makeChoiceText("ВЫ", CHOICE_COL)
    ChooseSelfBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    ChooseSelfBtn.Position = UDim2.new(0.5, 0, 0.85, 0)

    local function showChoices(on)
        ChooseDealerBtn.Visible = on
        ChooseSelfBtn.Visible = on
        ChooseDealerBtn.Text = "ДИЛЕР"
        ChooseDealerBtn.TextSize = 26
        ChooseDealerBtn.TextColor3 = CHOICE_COL
        ChooseDealerBtn.TextTransparency = 0.3
        ChooseSelfBtn.Text = "ВЫ"
        ChooseSelfBtn.TextSize = 26
        ChooseSelfBtn.TextColor3 = CHOICE_COL
        ChooseSelfBtn.TextTransparency = 0.3
    end

    local RestartBtn = Instance.new("TextButton")
    RestartBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    RestartBtn.Size = UDim2.new(0, 280, 0, 44)
    RestartBtn.Position = UDim2.new(0.5, 0, 0.42, 0)
    RestartBtn.BackgroundTransparency = 1
    RestartBtn.BorderSizePixel = 0
    RestartBtn.AutoButtonColor = false
    RestartBtn.Text = "ИГРАТЬ СНОВА"
    RestartBtn.TextColor3 = Color3.fromRGB(255, 225, 90)
    RestartBtn.TextStrokeColor3 = Color3.new(0, 0, 0)
    RestartBtn.TextStrokeTransparency = 0.1
    RestartBtn.Font = Enum.Font.Code
    RestartBtn.TextSize = 28
    RestartBtn.ZIndex = 32
    RestartBtn.Visible = false
    RestartBtn.Parent = Viewport

    -- невидимая кнопка поверх дробовика: клик = взять его в руки (повторный клик, пока держишь = положить)
    local GunBtn = Instance.new("TextButton")
    GunBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    GunBtn.Size = UDim2.fromOffset(110, 30)
    GunBtn.BackgroundTransparency = 1
    GunBtn.Text = ""
    GunBtn.AutoButtonColor = false
    GunBtn.ZIndex = 9
    GunBtn.Visible = false
    GunBtn.Parent = Viewport
    GunBtn.MouseEnter:Connect(function() GunCtl.hover = true end)
    GunBtn.MouseLeave:Connect(function() GunCtl.hover = false end)
-- КОНЕЦ ЧАСТИ 2Г (Вся Часть 2 готова!)
-- НАЧАЛО ЧАСТИ 3А
    local function muzzleWorld(sawed)
        local z = (sawed and -1.5 or -2.2) * GUN_S
        return (GunRoot.CFrame * CFrame.new(0, 0.1 * GUN_S, z)).Position
    end

    local function muzzleFlash(pos)
        local f = mk(WorldModel, "ball", Vector3.new(0.5, 0.5, 0.5), CFrame.new(pos), Color3.fromRGB(255, 220, 120), Enum.Material.Neon)
        if FX.fx then FX.fx("muzzle", pos) end
        task.spawn(function()
            for i = 1, 6 do
                local s = 0.5 + i * 0.35
                f.Size = Vector3.new(s, s, s)
                f.Transparency = i / 6
                task.wait(0.02)
            end
            f:Destroy()
        end)
        emit(pos, 14, Color3.fromRGB(255, 190, 80), 9, 0.5, 0.1)
    end

    -- УДАР В ИГРОКА: белая вспышка -> резкая темнота -> звук разряда -> экран возвращается
    local BlackOverlay = Instance.new("Frame", Viewport)
    BlackOverlay.Size = UDim2.new(1, 0, 1, 0)
    BlackOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
    BlackOverlay.BackgroundTransparency = 1
    BlackOverlay.BorderSizePixel = 0
    BlackOverlay.ZIndex = 30
    BlackOverlay.Visible = false
    local blackoutAt = 0

    local function blackoutStart()
        blackoutAt = os.clock()
        BlackOverlay.Visible = true
        BlackOverlay.BackgroundColor3 = Color3.new(1, 1, 1)
        BlackOverlay.BackgroundTransparency = 0 -- последнее, что видно: вспышка
        task.delay(0.07, function()
            BlackOverlay.BackgroundColor3 = Color3.new(0, 0, 0) -- и мгновенно темнота
        end)
    end

    local function blackoutEnd()
        local rest = 1.5 - (os.clock() - blackoutAt)
        if rest > 0 then task.wait(rest) end
        playSFX(SOUNDS.Zap, 1.15)
        playSFX(SOUNDS.Blank, 0.72)
        shake = math.max(shake, 0.9)
        task.wait(0.45)
        TweenService:Create(BlackOverlay, TweenInfo.new(0.7), {BackgroundTransparency = 1}):Play()
        task.wait(0.7)
        BlackOverlay.Visible = false
    end

    -- СМЕРТЕЛЬНЫЙ УДАР: тот же звук и тряска, но экран остаётся чёрным
    local function blackoutHold()
        local rest = 1.5 - (os.clock() - blackoutAt)
        if rest > 0 then task.wait(rest) end
        playSFX(SOUNDS.Zap, 1.15)
        playSFX(SOUNDS.Blank, 0.72)
        shake = math.max(shake, 0.9)
        task.wait(0.45)
    end

    local function killRobloxCharacter()
        if not HARDCORE_DEATH then return end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end

    -- ГРЯЗНЫЙ ТЕКСТ: без фона, дрожит и мерцает
    local dirtyTexts = {}
    local function makeDirtyText(txt, size, color, pos)
        local b = Instance.new("TextButton")
        b.AnchorPoint = Vector2.new(0.5, 0.5)
        b.Size = UDim2.new(0, 360, 0, size + 14)
        b.Position = pos
        b.BackgroundTransparency = 1
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.Text = txt
        b.TextColor3 = color
        b.TextStrokeColor3 = Color3.fromRGB(40, 0, 0)
        b.TextStrokeTransparency = 0
        b.Font = DIRTY_FONT
        b.TextSize = size
        b.ZIndex = 32
        b.Visible = false
        b.Parent = Viewport
        local d = {btn = b, pos = pos, color = color, hover = false}
        b.MouseEnter:Connect(function() d.hover = true end)
        b.MouseLeave:Connect(function() d.hover = false end)
        table.insert(dirtyTexts, d)
        return b
    end
    task.spawn(function()
        while ScreenGui.Parent and Viewport.Parent do
            for _, d in ipairs(dirtyTexts) do
                if d.btn.Visible then
                    local j = d.hover and 1 or 3
                    d.btn.Position = d.pos + UDim2.fromOffset(math.random(-j, j), math.random(-j, j))
                    d.btn.TextTransparency = (math.random() < 0.12) and 0.55 or (d.hover and 0 or 0.1)
                    d.btn.TextColor3 = d.hover and Color3.fromRGB(215, 65, 50) or d.color
                end
            end
            task.wait(0.06)
        end
    end)

    local LastChanceBtn = makeDirtyText("ПОСЛЕДНИЙ ШАНС?", 30, Color3.fromRGB(150, 28, 28), UDim2.new(0.5, 0, 0.42, 0))
    local SurrenderBtn = makeDirtyText("сдаться", 14, Color3.fromRGB(110, 88, 88), UDim2.new(0.5, 0, 0.64, 0))
    local LastTimer = Instance.new("TextLabel", Viewport)
    LastTimer.AnchorPoint = Vector2.new(0.5, 0.5)
    LastTimer.Size = UDim2.new(0, 60, 0, 20)
    LastTimer.Position = UDim2.new(0.5, 0, 0.53, 0)
    LastTimer.BackgroundTransparency = 1
    LastTimer.TextColor3 = Color3.fromRGB(110, 40, 40)
    LastTimer.Font = DIRTY_FONT
    LastTimer.TextSize = 16
    LastTimer.ZIndex = 32
    LastTimer.Visible = false

    -- HUD: монеты и серия побед
    local EconLabel = Instance.new("TextLabel", Viewport)
    EconLabel.AnchorPoint = Vector2.new(0.5, 0)
    EconLabel.Size = UDim2.new(0, 190, 0, 18)
    EconLabel.Position = UDim2.new(0.5, 0, 0, 6)
    EconLabel.BackgroundTransparency = 1
    EconLabel.TextColor3 = Color3.fromRGB(255, 215, 90)
    EconLabel.TextStrokeTransparency = 0.4
    EconLabel.Font = Enum.Font.Code
    EconLabel.TextSize = 12
    EconLabel.ZIndex = 6
    local function updateEconomyUI()
        EconLabel.Text = string.format("$%d  СЕРИЯ %d  РЕКОРД %d", Progress.coins, Progress.streak, Progress.best)
    end
    updateEconomyUI()

    local function makeShellModel(isLive)
        local m = newModel(WorldModel)
        local col = isLive and Color3.fromRGB(215, 40, 40) or Color3.fromRGB(34, 34, 40)
        mk(m, "cylY", Vector3.new(0.3, 0.62, 0.3), CFrame.new(0, 0.31, 0), col, Enum.Material.SmoothPlastic)
        mk(m, "cylY", Vector3.new(0.32, 0.2, 0.32), CFrame.new(0, 0.1, 0), Color3.fromRGB(205, 165, 70), Enum.Material.Metal)
        return m
    end

    -- место патрона в ряду из 8 ячеек на разметке (лежит ровно внутри ячейки)
    local function shellCell(i)
        return CFrame.new(-2.17 + (i - 1) * 0.62, 0.16, -1.26) * CFrame.Angles(math.rad(90), 0, 0)
    end
    local casingIdx = 0

    -- Гильза вылетает из дробовика и падает в ячейку на разметке
    local function spawn3DShell(isLive, from)
        casingIdx = casingIdx % 8 + 1
        local cell = shellCell(casingIdx)
        task.spawn(function()
            local m = makeShellModel(isLive)
            local start = from or (GunRoot.Position + Vector3.new(0.3, 0.5, 0))
            for i = 1, 20 do
                local t = i / 20
                local pos = start:Lerp(cell.Position, t) + Vector3.new(0, math.sin(t * math.pi) * 1.8, 0)
                m:PivotTo(CFrame.new(pos) * CFrame.Angles(math.rad(90) + (1 - t) * 11, 0, (1 - t) * 7))
                task.wait(0.025)
            end
            m:PivotTo(cell)
            playSFX(SOUNDS.Rack, 2.2)
            task.wait(2.2)
            m:Destroy()
        end)
    end

    -- Показ обоймы перед зарядкой: патроны падают в ячейки и лежат там, пока Дилер их не заберёт
    local function showShellsOnTable(liveCount, blankCount)
        local shells = {}
        for i = 1, liveCount + blankCount do
            local m = makeShellModel(i <= liveCount)
            local cell = shellCell(i)
            for step = 1, 7 do
                m:PivotTo(cell + Vector3.new(0, 1.6 * (1 - (step / 7) ^ 2), 0))
                task.wait(0.012)
            end
            m:PivotTo(cell)
            playSFX(SOUNDS.Rack, 2.0)
            table.insert(shells, m)
        end
        return shells
    end

    local function setLog(mainText, color, subText)
        subtitle(mainText, color)
    end

    local function ease(a) return a * a * (3 - 2 * a) end
    local function runAnim(dur, fn)
        local t0 = os.clock()
        while true do
            local a = math.min(1, (os.clock() - t0) / dur)
            fn(a)
            if a >= 1 then break end
            task.wait()
        end
    end

    -- ===== РУКИ И ДРОБОВИК: оружие берут в руки (ты и Дилер), оно больше не летает само =====
    local function makeArm(sleeve, skin, upperT, foreT, foreSleeve, handsOnly)
        local a = {parts = {}, fingers = {}, hidden = false, handsOnly = handsOnly}
        local function add(kind, size, color)
            local p = mk(WorldModel, kind, size, CFrame.new(0, -100, 0), color, Enum.Material.Fabric)
            table.insert(a.parts, p)
            return p
        end
        a.upper = add("block", Vector3.new(upperT, upperT, 1), sleeve)
        a.fore = add("block", Vector3.new(foreT, foreT, 1), foreSleeve and sleeve or skin)
        a.elbow = add("ball", Vector3.new(upperT * 1.08, upperT * 1.08, upperT * 1.08), sleeve)
        a.hand = add("ball", Vector3.new(0.58, 0.44, 0.62), skin)
        for k = -1, 2 do
            table.insert(a.fingers, {p = add("block", Vector3.new(0.08, 0.08, 0.5), skin), x = (k - 0.5) * 0.15})
        end
        return a
    end

    local function hideArm(a)
        if a.hidden then return end
        a.hidden = true
        for _, p in ipairs(a.parts) do p.CFrame = CFrame.new(0, -100, 0) end
    end

    -- простая 2-костная рука: плечо -> локоть -> кисть (длина подстраивается, чтобы дотянуться)
    local function poseArm(a, shoulder, hand, pole, minL)
        a.hidden = false
        if a.handsOnly then
            -- у Дилера только ладони: рук (плечо/предплечье/локоть) нет, остаются кисть и пальцы
            local hd = hand - shoulder
            local hcf0 = CFrame.lookAt(hand, hand + ((hd.Magnitude > 0.01) and hd or Vector3.new(0, 0, 1)))
            a.hand.CFrame = hcf0
            for _, f in ipairs(a.fingers) do f.p.CFrame = hcf0 * CFrame.new(f.x, -0.03, -0.42) end
            return
        end
        local d = hand - shoulder
        local dist = math.max(0.1, d.Magnitude)
        local dir = d / dist
        local L = math.max(minL, dist * 0.52)
        local along = dist * 0.5
        local hh = math.sqrt(math.max(0, L * L - along * along))
        local perp = pole - dir * pole:Dot(dir)
        perp = (perp.Magnitude > 0.001) and perp.Unit or Vector3.new(0, 1, 0)
        local elbow = shoulder + dir * along + perp * hh
        local function seg(p, p0, p1)
            local t = p.Size.X
            p.Size = Vector3.new(t, t, math.max(0.05, (p1 - p0).Magnitude))
            p.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
        end
        seg(a.upper, shoulder, elbow)
        seg(a.fore, elbow, hand)
        a.elbow.Position = elbow
        local hcf = CFrame.lookAt(hand, hand + (hand - elbow))
        a.hand.CFrame = hcf
        for _, f in ipairs(a.fingers) do f.p.CFrame = hcf * CFrame.new(f.x, -0.03, -0.42) end
    end

    -- управление руками в анимациях: pos = куда тянется кисть, k = насколько сильно (0..1)
    FX.Hands = {
        Player = {rear = {pos = Vector3.new(1, 1, 4), k = 0}, fore = {pos = Vector3.new(-1, 1, 4), k = 0}},
        Dealer = {rear = {pos = Vector3.new(1, 1, -4), k = 0}, fore = {pos = Vector3.new(-1, 1, -4), k = 0}},
    }
    -- наручники: off = смещение кистей во время рывков, hold = держать руки на виду после поломки
    FX.cuffHand = {
        Player = {off = {rear = Vector3.zero, fore = Vector3.zero}, hold = false},
        Dealer = {off = {rear = Vector3.zero, fore = Vector3.zero}, hold = false},
    }

    GunCtl.arms.Player = {
        rear = makeArm(Color3.fromRGB(38, 58, 96), Color3.fromRGB(222, 178, 148), 0.62, 0.56, true),
        fore = makeArm(Color3.fromRGB(38, 58, 96), Color3.fromRGB(222, 178, 148), 0.62, 0.56, true),
    }
    GunCtl.arms.Dealer = {
        rear = makeArm(SUIT, SKIN, 0.5, 0.34, false, true),
        fore = makeArm(SUIT, SKIN, 0.5, 0.34, false, true),
    }

    -- где у дробовика рукоять (rear) и цевьё (fore)
    local function gunGrips()
        local cf = GunRoot.CFrame
        return (cf * CFrame.new(0, -0.1 * GUN_S, 0.68 * GUN_S)).Position,
            (cf * CFrame.new(0, -0.08 * GUN_S, -0.8 * GUN_S)).Position
    end

    -- каждый кадр: руки тянутся к дробовику (blend 0 = руки на месте, 1 = держат оружие)
    function GunCtl.updateArms(bob, lean, t)
        lean = lean or 0
        t = t or 0
        local rearG, foreG = gunGrips()
        local bl = GunCtl.blend
        for _, part in ipairs({"rear", "fore"}) do
            local sx = (part == "rear") and 1 or -1
            local grip = (part == "rear") and rearG or foreG

            local pArm = GunCtl.arms.Player[part]
            local ph = FX.Hands.Player[part]
            local pc = FX.cuffHand.Player
            local pBound = GameState.PlayerCuffed or pc.hold
            if bl.Player <= 0.001 and ph.k <= 0.001 and not pBound then
                hideArm(pArm)
            else
                local rest = Vector3.new(sx * 2.4, 0.5, 6.6)
                if pBound then rest = Vector3.new(sx * 0.72, 0.45, 5.0) + pc.off[part] end
                local hand = rest:Lerp(grip, bl.Player)
                if ph.k > 0.001 then hand = hand:Lerp(ph.pos, ph.k) end
                poseArm(pArm, Vector3.new(sx * 2.8, 0.3, 10.2), hand, Vector3.new(sx * 0.8, 0.6, 0), 2.2)
            end

            local dh = FX.Hands.Dealer[part]
            local dc = FX.cuffHand.Dealer
            local dBound = GameState.DealerCuffed or dc.hold
            local tap = 0
            if bl.Dealer < 0.05 and dh.k < 0.05 and not dBound then
                -- пальцы Дилера нервно барабанят по столу
                tap = (math.max(0, math.sin(t * 7 + ((sx > 0) and 0 or 2.3))) ^ 3) * 0.1
            end
            local dRest = Vector3.new(1.35 * sx, 0.28 + bob * 0.3 + tap, DEALER_Z + 1.9 + lean * 0.3)
            if dBound then dRest = Vector3.new(0.72 * sx, 0.42, DEALER_Z + 2.2 + lean) + dc.off[part] end
            local hand = dRest:Lerp(grip + Vector3.new(0, 0, math.min(0, lean + 0.5)), bl.Dealer)
            if dh.k > 0.001 then hand = hand:Lerp(dh.pos, dh.k) end
            poseArm(GunCtl.arms.Dealer[part], Vector3.new(1.5 * sx, 2.45 + bob, DEALER_Z + 0.1 + lean), hand, Vector3.new(sx, -0.15, 0.1), 1.9)
        end
    end

    -- дуло в точке muzzle, ствол смотрит по dir
    local function aimCF(muzzle, dir, sawed)
        dir = dir.Unit
        local L = (sawed and 1.5 or 2.2) * GUN_S
        local rot = CFrame.lookAt(Vector3.zero, dir)
        local origin = muzzle - dir * L - rot.UpVector * (0.1 * GUN_S)
        return CFrame.lookAt(origin, origin + dir)
    end

    -- поза "взял в руки" (ещё не целится)
    local READY_CF = {
        Player = CFrame.lookAt(Vector3.new(-1.5, 2.2, 4.4), Vector3.new(-0.9, 1.6, -3.0)), -- дробовик в руках слева-снизу, как в видео
        Dealer = CFrame.lookAt(Vector3.new(0, 2.3, -3.0), Vector3.new(0, 2.3, 5)), -- ровно, на уровне груди
    }

    local function gunAimCF(holder, target, sawed)
        if holder == "Player" then
            if target == "Dealer" then
                return aimCF(Vector3.new(-0.4, 3.0, -1.2), Vector3.new(0.1, 0.1, -1), sawed)
            end
            return aimCF(Vector3.new(0, 4.2, 8.6), Vector3.new(0, 0.69, 0.72), sawed) -- дуло тебе в лицо
        end
        local function levelFrom(rootPos, aimAt)
            local d = (aimAt - rootPos).Unit
            return CFrame.lookAt(rootPos, rootPos + d)
        end
        if target == "Player" then
            return levelFrom(Vector3.new(0, 2.5, -2.4), Vector3.new(0, 4.6, 9.0)) -- ровно в тебя, без крена
        end
        return levelFrom(Vector3.new(0, 2.7, -2.6), Vector3.new(0, 3.4, -9.0)) -- ровно к своему рту
    end

    -- руки тянутся к дробовику на столе, хватают и поднимают
    function GunCtl.take(holder)
        GunCtl.holder = holder
        local bl = GunCtl.blend
        runAnim(0.6, function(a) bl[holder] = ease(a) end)
        bl[holder] = 1
        playSFX(SOUNDS.Rack, 1.25)
        local from, ready = GunRoot.CFrame, READY_CF[holder]
        runAnim(0.55, function(a)
            GunRoot.CFrame = from:Lerp(ready, ease(a)) + Vector3.new(0, math.sin(a * math.pi) * 0.3, 0)
            syncGunParts()
        end)
        GunRoot.CFrame = ready
        syncGunParts()
    end

    -- руки кладут дробовик на стол и убираются
    function GunCtl.release(holder)
        local bl = GunCtl.blend
        local from = GunRoot.CFrame
        runAnim(0.6, function(a)
            GunRoot.CFrame = from:Lerp(REST_CF, ease(a)) + Vector3.new(0, math.sin(a * math.pi) * 0.4, 0)
            syncGunParts()
        end)
        GunRoot.CFrame = REST_CF
        syncGunParts()
        playSFX(SOUNDS.Rack, 0.55)
        task.wait(0.1)
        local b0 = bl[holder]
        runAnim(0.45, function(a) bl[holder] = b0 * (1 - ease(a)) end)
        bl[holder] = 0
        GunCtl.holder = nil
    end

    -- передёргивание цевья (анимация + звук)
    function GunCtl.rack(pitch)
        playSFX(SOUNDS.Rack, pitch or 1)
        runAnim(0.13, function(a) FX.pumpOff = ease(a) * 0.55; syncGunParts() end)
        runAnim(0.13, function(a) FX.pumpOff = (1 - ease(a)) * 0.55; syncGunParts() end)
        FX.pumpOff = 0
        syncGunParts()
    end

    function GunCtl.clickable()
        return GameState.Turn == "Player" and not GameState.GameOver and not GameState.StealingMode
            and not GameState.Busy and not GameState.Aiming and not GameState.Intro
    end

    -- ===== v10: НАДЕТЫЕ НАРУЧНИКИ, ОТЛЁТ ДИЛЕРА В ТЬМУ, ЗАРЯДКА ДРОБОВИКА =====
    do
        local STEEL = Color3.fromRGB(176, 178, 188)
        local STEEL_D = Color3.fromRGB(112, 114, 124)
        local SEG, LINKS = 12, 9
        local worn = {}

        local function buildWorn(radius)
            local c = {radius = radius, rings = {{}, {}}, links = {}, shown = false}
            local function metal(size, color)
                return mk(WorldModel, "block", size, CFrame.new(0, -100, 0), color, Enum.Material.Metal, 1)
            end
            local chord = 2 * radius * math.sin(math.pi / SEG) * 1.12
            for r = 1, 2 do
                for k = 1, SEG do table.insert(c.rings[r], metal(Vector3.new(chord, 0.1, 0.24), STEEL)) end
                c.rings[r].lock = metal(Vector3.new(0.24, 0.2, 0.3), STEEL_D) -- замок на браслете
            end
            for k = 1, LINKS do c.links[k] = metal(Vector3.new(0.14, 0.06, 0.24), STEEL_D) end
            return c
        end

        local function wristCF(side, part)
            return GunCtl.arms[side][part].hand.CFrame * CFrame.new(0, 0, (side == "Player") and 0.42 or 0.45)
        end

        local function allParts(c)
            local list = {}
            for r = 1, 2 do
                for _, p in ipairs(c.rings[r]) do table.insert(list, p) end
                table.insert(list, c.rings[r].lock)
            end
            for _, p in ipairs(c.links) do table.insert(list, p) end
            return list
        end

        -- каждый кадр: браслеты сидят на запястьях, цепь тянется между ними (натягивается при рывке)
        function FX.updateCuffs()
            for _, side in ipairs({"Player", "Dealer"}) do
                local want = (GameState[side .. "Cuffed"] == true)
                local c = worn[side]
                if want and not c then
                    c = buildWorn((side == "Player") and 0.43 or 0.37)
                    worn[side] = c
                end
                if c then
                    if c.shown ~= want then
                        c.shown = want
                        for _, p in ipairs(allParts(c)) do p.Transparency = want and 0 or 1 end
                    end
                    if want then
                        local anchors = {}
                        for r, part in ipairs({"rear", "fore"}) do
                            local w = wristCF(side, part)
                            for k, p in ipairs(c.rings[r]) do
                                local a = k / SEG * math.pi * 2
                                p.CFrame = w * CFrame.Angles(0, 0, a) * CFrame.new(0, c.radius, 0)
                            end
                            local inner = (r == 1) and -1 or 1
                            c.rings[r].lock.CFrame = w * CFrame.new(inner * c.radius, -0.05, 0)
                            anchors[r] = (w * CFrame.new(inner * (c.radius + 0.1), -0.1, 0)).Position
                        end
                        local a, b = anchors[1], anchors[2]
                        local dist = (b - a).Magnitude
                        local sag = math.max(0, 1.2 - dist) * 0.35
                        local function at(u) return a:Lerp(b, u) - Vector3.new(0, sag * 4 * u * (1 - u), 0) end
                        for k, p in ipairs(c.links) do
                            local p0, p1 = at((k - 1) / LINKS), at(k / LINKS)
                            local len = math.max(0.03, (p1 - p0).Magnitude)
                            p.Size = Vector3.new(0.14, 0.06, len * 1.25)
                            p.CFrame = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, 0, (k % 2) * math.pi / 2)
                        end
                    end
                end
            end
        end

        function FX.cuffList(side)
            return worn[side] and allParts(worn[side]) or {}
        end

        -- осколки наручников разлетаются и падают на стол
        local function shatterCuffs(side)
            local c = worn[side]
            if not c then return end
            local debris = {}
            for i, p in ipairs(allParts(c)) do
                local q = p:Clone()
                q.Transparency = 0
                q.Parent = WorldModel
                local dir = (i % 2 == 0) and 1 or -1
                table.insert(debris, {p = q, pos = p.Position,
                    v = Vector3.new(dir * (1 + math.random() * 4), 2 + math.random() * 5, (math.random() - 0.5) * 5),
                    rot = p.CFrame - p.Position,
                    spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 18})
            end
            task.spawn(function()
                local age, dt = 0, 0.03
                while age < 2.6 do
                    for _, d in ipairs(debris) do
                        if not d.rest then
                            d.v = d.v + Vector3.new(0, -24 * dt, 0)
                            d.pos = d.pos + d.v * dt
                            d.rot = d.rot * CFrame.Angles(d.spin.X * dt, d.spin.Y * dt, d.spin.Z * dt)
                            if d.pos.Y < 0.08 then
                                d.pos = Vector3.new(d.pos.X, 0.08, d.pos.Z)
                                if d.v.Y < -3 then d.v = Vector3.new(d.v.X * 0.5, -d.v.Y * 0.3, d.v.Z * 0.5) else d.rest = true end
                            end
                            d.p.CFrame = CFrame.new(d.pos) * d.rot
                        end
                        if age > 1.9 then d.p.Transparency = math.min(1, (age - 1.9) / 0.7) end
                    end
                    task.wait(dt)
                    age += dt
                end
                for _, d in ipairs(debris) do d.p:Destroy() end
            end)
        end

        local function cuffCamera(side)
            if side == "Player" then
                return CFrame.lookAt(Vector3.new(0, 4.4, 9.0), Vector3.new(0, 0.5, 4.8))
            end
            return CFrame.lookAt(Vector3.new(0, 4.0, 0.9), Vector3.new(0, 0.9, -4.3))
        end

        -- плавно двигает обе кисти к новым смещениям
        local function pull(side, rear, fore, dur, snappy)
            local o = FX.cuffHand[side].off
            local r0, f0 = o.rear, o.fore
            runAnim(dur, function(a)
                local k = snappy and (a * a) or ease(a)
                o.rear = r0:Lerp(rear, k)
                o.fore = f0:Lerp(fore, k)
            end)
        end

        local function tremble(side, dur, power)
            local o = FX.cuffHand[side].off
            local r0, f0 = o.rear, o.fore
            runAnim(dur, function()
                local j = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * power
                o.rear, o.fore = r0 + j, f0 - j
            end)
            o.rear, o.fore = r0, f0
        end

        local function toward(side) return (side == "Player") and 1 or -1 end -- направление "к себе"

        -- ПРОПУСК ХОДА: два рывка рукой, наручники держат
        function FX.cuffStruggle(side)
            camTarget = cuffCamera(side)
            task.wait(0.75)
            local sd = toward(side)
            for i = 1, 2 do
                pull(side, Vector3.new(0.85, 0.65, sd * 0.35), Vector3.new(0.28, 0.12, 0), 0.13, true)
                playSFX(SOUNDS.Rack, 1.9 + i * 0.1)
                shake = math.max(shake, 0.4)
                tremble(side, 0.16, 0.09) -- цепь натянута и не пускает
                pull(side, Vector3.zero, Vector3.zero, 0.2)
                task.wait(0.4)
            end
            task.wait(0.35)
        end

        -- ОСВОБОЖДЕНИЕ: замах, очень сильный рывок, наручники ломаются
        function FX.cuffBreak(side)
            camTarget = cuffCamera(side)
            local c = FX.cuffHand[side]
            c.hold = true
            task.wait(0.7)
            local sd = toward(side)
            pull(side, Vector3.new(-0.3, -0.05, 0), Vector3.new(0.3, -0.05, 0), 0.35) -- руки вместе
            tremble(side, 0.45, 0.07) -- напряжение
            playSFX(SOUNDS.Rack, 0.7)
            pull(side, Vector3.new(0.9, 1.0, sd * 0.4), Vector3.new(-0.9, 1.0, sd * 0.4), 0.09, true)
            tremble(side, 0.14, 0.14)
            FX.updateCuffs()
            shatterCuffs(side)
            GameState[side .. "Cuffed"] = false
            GameState[side .. "CuffSkipped"] = false
            playSFX(SOUNDS.Shot, 1.8)
            playSFX(SOUNDS.Rack, 0.55)
            shake = math.max(shake, 1.5)
            pull(side, Vector3.new(1.5, 1.5, sd * 0.6), Vector3.new(-1.5, 1.5, sd * 0.6), 0.12)
            task.wait(0.55)
            pull(side, Vector3.new(1.4, 0, sd * 1.6), Vector3.new(-1.4, 0, sd * 1.6), 0.5)
            c.hold = false
            c.off.rear, c.off.fore = Vector3.zero, Vector3.zero
            task.wait(0.2)
        end

        function FX.resetCuffs()
            for _, side in ipairs({"Player", "Dealer"}) do
                GameState[side .. "CuffSkipped"] = false
                local c = FX.cuffHand[side]
                c.hold = false
                c.off.rear, c.off.fore = Vector3.zero, Vector3.zero
            end
        end

        -- ===== ДИЛЕР ПОЛУЧАЕТ ЗАРЯД: улетает во тьму, через секунду медленно возвращается =====
        local DARK = Color3.fromRGB(2, 1, 2)
        local FAR = 2.8
        local flyId = 0
        local baseColors = nil
        local backdropHome = nil

        function FX.dealerShade(amount)
            local d = math.clamp(amount / 2.3, 0, 1)
            if d > 0.001 then
                if not baseColors then
                    baseColors = {}
                    local function keep(p) if p:IsA("BasePart") then baseColors[p] = p.Color end end
                    for _, p in ipairs(DealerHead:GetDescendants()) do keep(p) end
                    for _, p in ipairs(DealerBody:GetDescendants()) do keep(p) end
                    for _, a in pairs(GunCtl.arms.Dealer) do
                        for _, p in ipairs(a.parts) do keep(p) end
                    end
                    for _, p in ipairs(FX.cuffList("Dealer")) do keep(p) end
                end
                for p, col in pairs(baseColors) do p.Color = col:Lerp(DARK, d) end
            elseif baseColors then
                for p, col in pairs(baseColors) do p.Color = col end
                baseColors = nil
            end
        end

        local function moveBackdrop(back)
            if not FX.backdrop then return end
            backdropHome = backdropHome or FX.backdrop.CFrame
            FX.backdrop.CFrame = back and (backdropHome + Vector3.new(0, 0, -1.65)) or backdropHome
        end

        function FX.dealerReset()
            flyId += 1
            local F = FX.Dealer
            F.flying, F.away, F.awayT = false, 0, 0
            F.tilt, F.tiltT, F.nod, F.nodT, F.yaw, F.yawT, F.fast = 0, 0, 0, 0, 0, 0, false
            moveBackdrop(false)
        end

        function FX.dealerFly(returns)
            flyId += 1
            local my = flyId
            local F = FX.Dealer
            F.flying = true
            moveBackdrop(true) -- задник отодвигается, чтобы было куда лететь
            task.spawn(function()
                local start = F.away
                runAnim(0.3, function(a)
                    if my == flyId then F.away = start + (FAR - start) * (1 - (1 - a) ^ 3) end
                end)
                if my ~= flyId then return end
                task.wait(1.0) -- секунда в темноте
                if returns then
                    runAnim(2.4, function(a)
                        if my == flyId then F.away = FAR * (1 - ease(a)) end
                    end)
                    if my ~= flyId then return end
                    F.away, F.awayT = 0, 0
                    moveBackdrop(false)
                    task.wait(0.25)
                else
                    F.awayT = FAR -- последний выстрел: он остаётся во тьме
                end
                if my == flyId then F.flying = false end
            end)
        end

        function FX.waitDealer()
            local t0 = os.clock()
            while FX.Dealer.flying and os.clock() - t0 < 8 do task.wait() end
        end

        -- ===== ДИЛЕР ЗАРЯЖАЕТ ДРОБОВИК патронами с разметки, по одному =====
        function FX.dealerLoad(shells, alive)
            if not alive() then return end
            GunCtl.take("Dealer")
            local LOAD_CF = CFrame.lookAt(Vector3.new(-0.1, 1.9, -2.7), Vector3.new(-4, 2.3, -2.2)) * CFrame.Angles(0, 0, math.rad(-40))
            local from = GunRoot.CFrame
            runAnim(0.4, function(a) GunRoot.CFrame = from:Lerp(LOAD_CF, ease(a)); syncGunParts() end)
            local H = FX.Hands.Dealer.rear
            H.pos = (GunRoot.CFrame * CFrame.new(0, -0.1 * GUN_S, 0.68 * GUN_S)).Position
            H.k = 1
            local function handTo(target, dur, arc, carry)
                local p0 = H.pos
                runAnim(dur, function(a)
                    H.pos = p0:Lerp(target, ease(a)) + Vector3.new(0, math.sin(a * math.pi) * arc, 0)
                    if carry then
                        carry:PivotTo(CFrame.new(H.pos + Vector3.new(0, -0.05, 0.25)) * CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(0, -0.31, 0))
                    end
                end)
            end
            local port = (LOAD_CF * CFrame.new(0, -0.3 * GUN_S, 0.1 * GUN_S)).Position
            for _, m in ipairs(shells) do
                if not alive() then break end
                local at = m:GetPivot() * CFrame.new(0, 0.31, 0)
                handTo(at.Position + Vector3.new(0, 0.22, -0.2), 0.17, 0.35)
                handTo(port + Vector3.new(0, -0.15, -0.25), 0.22, 0.4, m)
                handTo(port + Vector3.new(0, 0.18, -0.25), 0.08, 0) -- вдавливает патрон в окно
                m:Destroy()
                playSFX(SOUNDS.Rack, 1.7)
                GunRoot.CFrame = LOAD_CF * CFrame.new(0, 0.06, 0); syncGunParts()
                task.wait(0.06)
                GunRoot.CFrame = LOAD_CF; syncGunParts()
            end
            runAnim(0.25, function(a) H.k = 1 - ease(a) end)
            H.k = 0
            GunCtl.rack(0.85)
            task.wait(0.15)
            GunCtl.release("Dealer")
        end
    end

    local function animate3DGun(shooter, targetType, isLive, wasSawed)
        gunSawedOverride = (wasSawed == true)
        if shooter == "Dealer" then
            FX.Dealer.leanT = (targetType == "Player") and 1.3 or 0.5
            FX.Dealer.fast, FX.Dealer.nodT = true, 0.25 -- резко подаётся вперёд, голова склоняется к цели
            FX.Dealer.tiltT = (targetType == "Player") and -0.14 or 0.22
        end
        if GunCtl.holder ~= shooter then GunCtl.take(shooter) end -- Дилер сам берёт дробовик

        local targetCF = gunAimCF(shooter, targetType, wasSawed == true)
        local fromCF = GunRoot.CFrame
        runAnim(0.5, function(a)
            GunRoot.CFrame = fromCF:Lerp(targetCF, ease(a))
            syncGunParts()
        end)
        GunRoot.CFrame = targetCF
        syncGunParts()

        -- НАПРЯЖЁННАЯ ПАУЗА перед выстрелом: передёргивание затвора и лёгкое дрожание ствола
        task.spawn(GunCtl.rack, 0.75)
        local holdStart = os.clock()
        while os.clock() - holdStart < 1.6 do
            local tt = os.clock() * 9
            GunRoot.CFrame = targetCF * CFrame.new(math.sin(tt * 1.3) * 0.012, math.sin(tt) * 0.012, 0)
                * CFrame.Angles(math.sin(tt * 0.8) * 0.012, math.sin(tt * 1.1) * 0.012, 0)
            syncGunParts()
            task.wait()
        end
        GunRoot.CFrame = targetCF
        syncGunParts()

        if isLive then
            playSFX(SOUNDS.Shot, 0.95)
            muzzleFlash(muzzleWorld(wasSawed))
            shake = math.max(shake, 1.2)
            if FX.fx then FX.fx("shot") end
            FlashOverlay.BackgroundColor3 = Color3.fromRGB(255, 20, 20)
            FlashOverlay.BackgroundTransparency = 0.3
            TweenService:Create(FlashOverlay, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
            GunRoot.CFrame = targetCF * CFrame.new(0, 0.25, 0.9) * CFrame.Angles(math.rad(22), 0, 0)
            syncGunParts()
            if shooter == "Dealer" then FX.Dealer.kick = math.max(FX.Dealer.kick, 0.5) end -- отдача дёргает Дилера
            if targetType == "Player" then blackoutStart() end
        else
            playSFX(SOUNDS.Blank, 1.1)
            emit(muzzleWorld(wasSawed), 6, Color3.fromRGB(150, 190, 255), 2.5, 0.5, 0.08)
            FlashOverlay.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
            FlashOverlay.BackgroundTransparency = 0.75
            TweenService:Create(FlashOverlay, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
        end

        local flies = isLive and targetType == "Dealer"
        if flies then
            local lastBlow = GameState.Round >= 3 and GameState.DealerHP - (wasSawed and 2 or 1) <= 0
            DealerFace.Text = "[ ‿ ‿ ]"
            emit(Vector3.new(0, 3.4, DEALER_Z + 0.8), 46, Color3.fromRGB(205, 70, 95), 8, 1.3, 0.16, -6)
            FX.dealerFly(not lastBlow)
        end

        task.wait(0.25)
        if isLive then emit(muzzleWorld(wasSawed), 9, Color3.fromRGB(105, 105, 110), 1.6, 1.8, 0.24, 1.3) end -- дымок
        GunCtl.rack(1.0)
        spawn3DShell(isLive) -- гильза вылетает при передёргивании
        task.wait(0.15)
        if shooter == "Dealer" then
            FX.Dealer.leanT = 0
            FX.Dealer.nodT, FX.Dealer.tiltT, FX.Dealer.fast = 0, 0, false
        end
        GunCtl.release(shooter) -- кладёт дробовик обратно на стол
        gunSawedOverride = false
        syncGunParts()
    end

    -- ЛУПА: камера подъезжает к дробовику, из патронника поднимается патрон: красный = LIVE, чёрный = BLANK
    local function showChamberCloseup(isLive)
        camTarget = CFrame.lookAt(Vector3.new(1.5, 1.8, 3.1), Vector3.new(0.55, 0.8, 0.8))
        playSFX(SOUNDS.Rack, 1.3)
        task.wait(0.8)
        local shell = makeShellModel(isLive)
        local base = Vector3.new(0.67, 0.7, 0.8)
        shell:PivotTo(CFrame.new(base))
        local pre = "THIS SHOT IS..."
        subtitle(pre, nil, true)
        runAnim(0.7, function(a)
            shell:PivotTo(CFrame.new(base + Vector3.new(0, ease(a) * 0.85, 0)) * CFrame.Angles(0, a * 3, 0))
        end)
        task.wait(0.9)
        local word = isLive
            and '<font color="rgb(255,55,55)">LIVE</font>'
            or '<font color="rgb(150,150,165)">BLANK</font>'
        subtitle(pre .. " " .. word, nil, true, utf8.len(pre))
        if isLive then
            playSFX(SOUNDS.Rack, 0.8)
            FlashOverlay.BackgroundColor3 = Color3.fromRGB(255, 20, 20)
            FlashOverlay.BackgroundTransparency = 0.7
            TweenService:Create(FlashOverlay, TweenInfo.new(0.6), {BackgroundTransparency = 1}):Play()
        else
            playSFX(SOUNDS.Blank, 0.9)
        end
        task.wait(2.3)
        runAnim(0.35, function(a)
            shell:PivotTo(CFrame.new(base + Vector3.new(0, 0.85 * (1 - ease(a)), 0)))
        end)
        shell:Destroy()
        camTarget = BASE_CAM
        task.wait(0.6)
    end

    -- 3D-ЗДОРОВЬЕ: ячейки-заряды на столе (каждая ячейка = 1 HP)
    local hpBanks = {
        Player = {origin = PLAYER_BANK, color = Color3.fromRGB(70, 255, 130), cells = {}, strips = {}},
        Dealer = {origin = DEALER_BANK, color = Color3.fromRGB(255, 70, 70), cells = {}, strips = {}},
    }
    local playerLabelPos, dealerLabelPos = PlayerHPLabel.Position, DealerHPLabel.Position

    local function lossFX(side, amount)
        local isPlayerSide = (side == "Player")
        shake = math.max(shake, isPlayerSide and 1.0 or 0.5)
        if FX.fx then FX.fx("hurt", isPlayerSide, side) end
        FlashOverlay.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        FlashOverlay.BackgroundTransparency = isPlayerSide and 0.45 or 0.8
        TweenService:Create(FlashOverlay, TweenInfo.new(0.55), {BackgroundTransparency = 1}):Play()

        local label = isPlayerSide and PlayerHPLabel or DealerHPLabel
        local basePos = isPlayerSide and playerLabelPos or dealerLabelPos
        local baseColor = isPlayerSide and Color3.fromRGB(85, 255, 130) or Color3.fromRGB(255, 80, 80)
        label.TextColor3 = Color3.fromRGB(255, 0, 0)
        label.TextSize = 20
        TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextSize = 13, TextColor3 = baseColor}):Play()
        task.spawn(function()
            for _ = 1, 10 do
                label.Position = UDim2.new(basePos.X.Scale, basePos.X.Offset + math.random(-6, 6), basePos.Y.Scale, basePos.Y.Offset + math.random(-4, 4))
                task.wait(0.03)
            end
            label.Position = basePos
        end)

        local sx, sy = project(hpBanks[side].origin + Vector3.new(0, 1.6, 0))
        local pop = Instance.new("TextLabel", Viewport)
        pop.AnchorPoint = Vector2.new(0.5, 0.5)
        pop.Size = UDim2.new(0, 110, 0, 34)
        pop.Position = UDim2.new(sx, 0, sy, 0)
        pop.BackgroundTransparency = 1
        pop.Text = "-" .. amount .. " HP"
        pop.TextColor3 = Color3.fromRGB(255, 40, 40)
        pop.TextStrokeColor3 = Color3.new(0, 0, 0)
        pop.TextStrokeTransparency = 0
        pop.Font = Enum.Font.Code
        pop.TextSize = 26
        pop.ZIndex = 20
        TweenService:Create(pop, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(sx, 0, sy - 0.22, 0),
            TextTransparency = 1,
            TextStrokeTransparency = 1
        }):Play()
        task.delay(1.2, function() if pop then pop:Destroy() end end)
    end

    local function updateHPUI()
        for _, side in ipairs({"Player", "Dealer"}) do
            local hp = math.max(0, (side == "Player") and GameState.PlayerHP or GameState.DealerHP)
            local maxHp = GameState.MaxHP
            local prev = FX.lastHP[side]
            if prev and prev.max == maxHp and hp < prev.hp then
                lossFX(side, prev.hp - hp)
            elseif prev and prev.max == maxHp and hp > prev.hp and FX.fx then
                FX.fx("healFX", side, hp - prev.hp)
            end
            FX.lastHP[side] = {hp = hp, max = maxHp}
            local label = (side == "Player") and PlayerHPLabel or DealerHPLabel
            local name = (side == "Player") and FX.nick or "DEALER"
            label.Text = name .. " ⚡ " .. hp .. "/" .. maxHp .. (hp == 0 and " 💀" or "")
            FX.setMonitor(side, hp, maxHp)
        end
        syncGunParts()
    end

    local UseItem, DealerTurn

    -- Можно ли применить предмет сейчас (правила настоящей Buckshot Roulette)
    local function canUseItem(who, itemName)
        local isPlayer = (who == "Player")
        if itemName == "Handsaw" and GameState.SawActive then
            return false, "ствол уже отпилен"
        elseif itemName == "Handcuffs" then
            if isPlayer and GameState.DealerCuffed then return false, "Дилер уже в наручниках" end
            if (not isPlayer) and GameState.PlayerCuffed then return false, "ты уже в наручниках" end
        elseif itemName == "Adrenaline" then
            local targets = isPlayer and GameState.DealerItems or GameState.PlayerItems
            local hasTarget = false
            for _, n in ipairs(targets) do
                if n ~= "Adrenaline" and canUseItem(who, n) then
                    hasTarget = true
                    break
                end
            end
            if not hasTarget then return false, "у соперника нечего красть" end
        end
        return true
    end
-- КОНЕЦ ЧАСТИ 3А
-- НАЧАЛО ЧАСТИ 3Б (3D-предметы)
    local renderInventories
    local displayed = {Player = {}, Dealer = {}}
    FX.items = {}

    -- Модели предметов: низ на уровне стола, примерно 1.3 единицы в ширину
    local function buildItemModel(name, parent)
        local m = newModel(parent)
        local METAL = Enum.Material.Metal
        if name == "Magnifying Glass" then
            mk(m, "cylZ", Vector3.new(0.95, 0.95, 0.14), CFrame.new(0, 0.95, 0), Color3.fromRGB(120, 95, 40), METAL).Name = "Rim"
            mk(m, "cylZ", Vector3.new(0.78, 0.78, 0.17), CFrame.new(0, 0.95, 0), Color3.fromRGB(150, 220, 255), Enum.Material.Glass, 0.5).Name = "Lens"
            mk(m, "block", Vector3.new(0.15, 0.75, 0.15), CFrame.new(0.5, 0.35, 0) * CFrame.Angles(0, 0, math.rad(35)), Color3.fromRGB(60, 35, 20), Enum.Material.Wood)
        elseif name == "Screwdriver" then
            -- отвёртка: толстая рукоятка с накладками, стальной стержень, плоское жало
            mk(m, "cylY", Vector3.new(0.34, 0.56, 0.34), CFrame.new(0, 0.3, 0), Color3.fromRGB(190, 110, 20))
            mk(m, "ball", Vector3.new(0.34, 0.2, 0.34), CFrame.new(0, 0.03, 0), Color3.fromRGB(28, 26, 26))
            mk(m, "cylY", Vector3.new(0.37, 0.12, 0.37), CFrame.new(0, 0.18, 0), Color3.fromRGB(28, 26, 26))
            mk(m, "cylY", Vector3.new(0.24, 0.1, 0.24), CFrame.new(0, 0.62, 0), Color3.fromRGB(120, 122, 130), METAL)
            mk(m, "cylY", Vector3.new(0.11, 0.62, 0.11), CFrame.new(0, 0.96, 0), Color3.fromRGB(175, 178, 188), METAL)
            mk(m, "block", Vector3.new(0.15, 0.16, 0.045), CFrame.new(0, 1.33, 0), Color3.fromRGB(150, 153, 162), METAL)
        elseif name == "Handsaw" then
            mk(m, "block", Vector3.new(1.3, 0.42, 0.05), CFrame.new(0.15, 0.6, 0) * CFrame.Angles(0, 0, math.rad(-8)), Color3.fromRGB(190, 195, 205), METAL)
            for k = 0, 7 do
                mk(m, "block", Vector3.new(0.09, 0.1, 0.06), CFrame.new(-0.35 + k * 0.17, 0.36 - k * 0.024, 0) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(150, 155, 165), METAL)
            end
            mk(m, "block", Vector3.new(0.34, 0.62, 0.16), CFrame.new(-0.7, 0.62, 0), Color3.fromRGB(110, 60, 28), Enum.Material.Wood)
            mk(m, "block", Vector3.new(0.14, 0.22, 0.18), CFrame.new(-0.7, 0.62, 0), Color3.fromRGB(20, 20, 20))
        elseif name == "Handcuffs" then
            for _, x in ipairs({-0.5, 0.5}) do
                mk(m, "cylZ", Vector3.new(0.62, 0.62, 0.1), CFrame.new(x, 0.35, 0), Color3.fromRGB(200, 200, 210), METAL)
                mk(m, "cylZ", Vector3.new(0.4, 0.4, 0.12), CFrame.new(x, 0.35, 0), Color3.fromRGB(26, 36, 30))
            end
            for k = -1, 1 do
                mk(m, "block", Vector3.new(0.12, 0.09, 0.09), CFrame.new(k * 0.14, 0.35, 0), Color3.fromRGB(170, 170, 180), METAL)
            end
        elseif name == "Cigarettes" then
            mk(m, "block", Vector3.new(0.7, 0.95, 0.3), CFrame.new(0, 0.48, 0), Color3.fromRGB(200, 30, 30))
            mk(m, "block", Vector3.new(0.72, 0.3, 0.31), CFrame.new(0, 0.55, 0), Color3.fromRGB(235, 235, 235))
            for _, x in ipairs({-0.18, 0, 0.18}) do
                mk(m, "cylY", Vector3.new(0.11, 0.32, 0.11), CFrame.new(x, 1.1, 0), Color3.fromRGB(250, 250, 245)).Name = "Cig"
                mk(m, "cylY", Vector3.new(0.11, 0.1, 0.11), CFrame.new(x, 0.97, 0), Color3.fromRGB(230, 140, 40))
            end
        elseif name == "Inverter" then
            -- РЕВЕРСЕР: потёртая железная коробочка с тумблером и двумя лампами
            local BOX = Color3.fromRGB(62, 66, 56)
            mk(m, "block", Vector3.new(0.95, 0.58, 0.52), CFrame.new(0, 0.29, 0), BOX, METAL)
            mk(m, "block", Vector3.new(1.0, 0.07, 0.57), CFrame.new(0, 0.6, 0), Color3.fromRGB(40, 40, 38), METAL)
            mk(m, "block", Vector3.new(0.78, 0.4, 0.02), CFrame.new(0, 0.29, 0.265), Color3.fromRGB(150, 142, 112), METAL)
            mk(m, "cylY", Vector3.new(0.2, 0.08, 0.2), CFrame.new(0, 0.65, 0), Color3.fromRGB(120, 122, 130), METAL)
            mk(m, "cylY", Vector3.new(0.09, 0.4, 0.09), CFrame.new(0, 0.85, 0), Color3.fromRGB(190, 192, 200), METAL).Name = "Lever"
            mk(m, "ball", Vector3.new(0.17, 0.17, 0.17), CFrame.new(0, 1.07, 0), Color3.fromRGB(205, 205, 212), METAL).Name = "Lever"
            mk(m, "ball", Vector3.new(0.17, 0.17, 0.17), CFrame.new(-0.24, 0.31, 0.29), Color3.fromRGB(255, 50, 40), Enum.Material.Neon).Name = "LampA"
            mk(m, "ball", Vector3.new(0.17, 0.17, 0.17), CFrame.new(0.24, 0.31, 0.29), Color3.fromRGB(20, 60, 30), Enum.Material.SmoothPlastic).Name = "LampB"
        elseif name == "Burner Phone" then
            mk(m, "block", Vector3.new(0.55, 1.0, 0.14), CFrame.new(0, 0.55, 0), Color3.fromRGB(32, 32, 38))
            mk(m, "block", Vector3.new(0.42, 0.4, 0.03), CFrame.new(0, 0.8, 0.08), Color3.fromRGB(90, 255, 120), Enum.Material.Neon).Name = "Screen"
            for r = 0, 1 do
                for c = -1, 1 do
                    mk(m, "block", Vector3.new(0.11, 0.08, 0.03), CFrame.new(c * 0.14, 0.42 - r * 0.13, 0.08), Color3.fromRGB(190, 190, 195))
                end
            end
            mk(m, "cylY", Vector3.new(0.05, 0.35, 0.05), CFrame.new(0.2, 1.2, 0), Color3.fromRGB(150, 150, 155), METAL).Name = "Antenna"
        elseif name == "Expired Medicine" then
            -- АПТЕЧНАЯ БАНКА: тёмно-янтарный пузырёк, белая крышка, потёртая бумажная этикетка
            local AMBER = Color3.fromRGB(150, 72, 14)
            mk(m, "cylY", Vector3.new(0.66, 0.86, 0.66), CFrame.new(0, 0.43, 0), AMBER, Enum.Material.Glass, 0.2)
            mk(m, "cylY", Vector3.new(0.68, 0.52, 0.68), CFrame.new(0, 0.4, 0), Color3.fromRGB(206, 196, 164))
            mk(m, "cylY", Vector3.new(0.46, 0.12, 0.46), CFrame.new(0, 0.92, 0), AMBER, Enum.Material.Glass, 0.2)
            mk(m, "cylY", Vector3.new(0.58, 0.24, 0.58), CFrame.new(0, 1.09, 0), Color3.fromRGB(226, 224, 214)).Name = "Cap"
            mk(m, "cylY", Vector3.new(0.61, 0.05, 0.61), CFrame.new(0, 1.0, 0), Color3.fromRGB(190, 188, 180)).Name = "Cap"
        elseif name == "Adrenaline" then
            mk(m, "cyl", Vector3.new(0.9, 0.34, 0.34), CFrame.new(0, 0.27, 0), Color3.fromRGB(220, 240, 255), Enum.Material.Glass, 0.5)
            mk(m, "cyl", Vector3.new(0.6, 0.26, 0.26), CFrame.new(-0.05, 0.27, 0), Color3.fromRGB(255, 150, 40), Enum.Material.Neon)
            mk(m, "cyl", Vector3.new(0.4, 0.1, 0.1), CFrame.new(0.65, 0.27, 0), Color3.fromRGB(200, 200, 210), METAL)
            mk(m, "cyl", Vector3.new(0.06, 0.34, 0.34), CFrame.new(0.88, 0.27, 0), Color3.fromRGB(200, 200, 210), METAL)
            mk(m, "block", Vector3.new(0.06, 0.5, 0.14), CFrame.new(0.42, 0.27, 0), Color3.fromRGB(200, 200, 210), METAL)
            mk(m, "cyl", Vector3.new(0.45, 0.05, 0.05), CFrame.new(-0.67, 0.27, 0), Color3.fromRGB(215, 215, 225), METAL)
        end
        if FX.fx then FX.fx("detail", m, name) end
        return m
    end

    local function slotPos(side, slot)
        local x = FX.SLOT_X[FX.SLOT_COL[slot]]
        local row = FX.SLOT_ROW[slot]
        local z = (side == "Player") and (2.7 + (row - 1) * 1.6) or (-2.7 - (row - 1) * 1.6)
        return Vector3.new(x, 0, z)
    end

    local function indexOf(list, it)
        for i, o in ipairs(list) do
            if o == it then return i end
        end
        return nil
    end

    -- Клик по 3D-предмету (кнопка невидимо лежит поверх предмета)
    local function onItemClick(it)
        local info = ITEMS_DB[it.name]
        local idx = indexOf(displayed[it.side], it)
        if not idx then return end
        TooltipLabel.Text = "[" .. info.Short .. "]: " .. info.Desc

        if it.side == "Player" then
            if GameState.PlayerItems[idx] ~= it.name then return end
            if GameState.Turn == "Player" and not GameState.GameOver and not GameState.StealingMode and not GameState.Busy and not GameState.Intro then
                local ok, reason = canUseItem("Player", it.name)
                if not ok then
                    setLog("⛔ " .. info.Short .. ": " .. reason, Color3.fromRGB(255, 90, 90))
                    addSideLog("⛔ " .. info.Icon .. " " .. info.Short .. " нельзя применить: " .. reason, Color3.fromRGB(255, 90, 90))
                    return
                end
                GameState.Busy = true
                FX.hint.Player = it
                table.remove(GameState.PlayerItems, idx)
                renderInventories()
                UseItem("Player", it.name)
                GameState.Busy = false
            end
        else
            if GameState.DealerItems[idx] ~= it.name then return end
            if GameState.StealingMode and GameState.Turn == "Player" and not GameState.Busy then
                if it.name == "Adrenaline" then
                    setLog("Нельзя украсть Адреналин!", Color3.fromRGB(255, 90, 90))
                    addSideLog("⛔ Адреналин украсть нельзя", Color3.fromRGB(255, 90, 90))
                    return
                end
                local ok, reason = canUseItem("Player", it.name)
                if not ok then
                    setLog("⛔ " .. info.Short .. ": " .. reason, Color3.fromRGB(255, 90, 90))
                    addSideLog("⛔ Нельзя украсть " .. info.Icon .. " " .. info.Short .. ": " .. reason, Color3.fromRGB(255, 90, 90))
                    return
                end
                GameState.StealingMode = false
                GameState.Busy = true
                FX.hint.Dealer = it
                it.actor = "Player"
                table.remove(GameState.DealerItems, idx)
                renderInventories()
                setLog("💉 УКРАДЕН ПРЕДМЕТ: " .. info.Short .. "!", Color3.fromRGB(255, 220, 80))
                addSideLog("💉 ТЫ украл у Дилера " .. info.Icon .. " " .. info.Short, Color3.fromRGB(255, 220, 80))
                camTarget = BASE_CAM
                UseItem("Player", it.name)
                camTarget = BASE_CAM
                GameState.Busy = false
            end
        end
    end

    local LAY = math.rad(-90)
    local ITEM_BAKE = {
        ["Magnifying Glass"] = CFrame.new(0, 0.09, 0.55) * CFrame.Angles(LAY, 0, 0),
        ["Handsaw"] = CFrame.new(0, 0.08, 0.6) * CFrame.Angles(LAY, 0, 0),
        ["Handcuffs"] = CFrame.new(0, 0.06, 0.35) * CFrame.Angles(LAY, 0, 0),
        ["Screwdriver"] = CFrame.new(0, 0.24, 0.9) * CFrame.Angles(LAY, 0, 0),
        ["Cigarettes"] = CFrame.new(0, 0.155, 0.55) * CFrame.Angles(LAY, 0, 0),
        ["Burner Phone"] = CFrame.new(0, 0.07, 0.6) * CFrame.Angles(LAY, 0, 0),
    }

    local function createItem(side, name)
        local m = buildItemModel(name, WorldModel)
        -- предметы заметнее: крупнее на 30% и светлее (неоновые детали не трогаем)
        local ITEM_SCALE = 1.3
        for _, p in ipairs(m:GetChildren()) do
            if p:IsA("BasePart") and p.Name ~= "Root" then
                local cf = p.CFrame
                p.Size = p.Size * ITEM_SCALE
                p.CFrame = CFrame.new(cf.Position * ITEM_SCALE) * (cf - cf.Position)
                if p.Material ~= Enum.Material.Neon then
                    p.Color = p.Color:Lerp(Color3.new(1, 1, 1), 0.28)
                end
            end
        end
        local parts = {}
        for _, p in ipairs(m:GetChildren()) do
            if p:IsA("BasePart") and p.Name ~= "Root" then
                table.insert(parts, {p = p, t = p.Transparency})
            end
        end
        -- плоские предметы укладываем на стол (запекаем поворот в детали модели)
        local bake = ITEM_BAKE[name] or CFrame.new()
        if ITEM_BAKE[name] then
            for _, e in ipairs(parts) do e.p.CFrame = bake * e.p.CFrame end
        end
        local it = {name = name, side = side, model = m, parts = parts, pos = Vector3.new(0, 4, 0),
            target = Vector3.new(0, 0, 0), lift = 0, hover = false, phase = math.random() * 6.28,
            bake = bake, bakeInv = bake:Inverse(), yaw = (math.random() - 0.5) * 0.5, vy = 0, thud = false}

        local btn = Instance.new("TextButton")
        btn.AnchorPoint = Vector2.new(0.5, 0.5)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.ZIndex = 10
        btn.Size = UDim2.fromOffset(40, 40)
        btn.Parent = Viewport
        it.btn = btn
        btn.MouseEnter:Connect(function()
            it.hover = true
            local info = ITEMS_DB[name]
            TooltipLabel.Text = ((side == "Dealer") and "[Дилер - " or "[") .. info.Short .. "]: " .. info.Desc
        end)
        btn.MouseLeave:Connect(function() it.hover = false; TooltipLabel.Text = "" end)
        btn.MouseButton1Click:Connect(function() onItemClick(it) end)
        table.insert(FX.items, it)
        return it
    end

    -- АНИМАЦИИ ПРЕДМЕТОВ: у каждого предмета своя при использовании.
    -- rec.cue = "момент действия": только после него меняются патроны / HP / наручники
    FX.anim = {}
    function FX.waitAnim(rec, key)
        local t0 = os.clock()
        while rec and not rec[key] and os.clock() - t0 < 14 do task.wait() end
    end

    -- убрать предмет без анимации (новый раунд / новая игра)
    local function discardItem(it)
        if it.btn then it.btn:Destroy() end
        it.hover = false
        it.dying = true
        it.dyingAt = os.clock()
        task.spawn(function()
            runAnim(0.25, function(a)
                for _, e in ipairs(it.parts) do e.p.Transparency = e.t + (1 - e.t) * a end
            end)
            it.model:Destroy()
        end)
    end

    -- осколки стекла / щепки: падают на стол, лежат и исчезают
    local function shards(pos, count, color, material, speed, size, transp)
        local list = {}
        for i = 1, count do
            local sz = Vector3.new(size * (0.5 + math.random()), 0.025, size * (0.3 + math.random() * 0.8))
            local p = mk(WorldModel, "block", sz, CFrame.new(pos), color, material, transp)
            local ang = math.random() * math.pi * 2
            local sp = speed * (0.35 + math.random() * 0.75)
            list[i] = {p = p, pos = pos, v = Vector3.new(math.cos(ang) * sp, 1 + math.random() * speed, math.sin(ang) * sp), yaw = math.random() * 6, spin = math.random() * 20 - 10, rest = false}
        end
        task.spawn(function()
            local age, dt = 0, 0.03
            while age < 3.2 do
                for _, d in ipairs(list) do
                    if not d.rest then
                        d.v = d.v + Vector3.new(0, -22 * dt, 0)
                        d.pos = d.pos + d.v * dt
                        d.yaw += d.spin * dt
                        if d.pos.Y <= 0.05 then
                            d.pos = Vector3.new(d.pos.X, 0.05, d.pos.Z)
                            d.rest = true
                            d.p.CFrame = CFrame.new(d.pos) * CFrame.Angles(0, d.yaw, 0)
                        else
                            d.p.CFrame = CFrame.new(d.pos) * CFrame.Angles(d.yaw, d.yaw * 0.6, d.yaw * 0.3)
                        end
                    end
                    if age > 2.6 then d.p.Transparency = math.min(1, (transp or 0) + (age - 2.6) / 0.6) end
                end
                task.wait(dt)
                age += dt
            end
            for _, d in ipairs(list) do d.p:Destroy() end
        end)
    end

    -- трещины в столе от удара
    local function tableCracks(pos)
        local list = {}
        for k = 1, 7 do
            local a = k / 7 * math.pi * 2 + math.random() * 0.5
            local len = 0.35 + math.random() * 0.65
            local dir = Vector3.new(math.cos(a), 0, math.sin(a))
            local p0 = Vector3.new(pos.X, 0.034, pos.Z)
            list[k] = mk(WorldModel, "block", Vector3.new(0.035, 0.008, len), CFrame.lookAt(p0 + dir * (0.12 + len / 2), p0 + dir * 3), Color3.fromRGB(10, 14, 10), Enum.Material.SmoothPlastic)
        end
        task.delay(7, function()
            for _, p in ipairs(list) do p:Destroy() end
        end)
    end

    local function removeItem(it)
        if it.btn then it.btn:Destroy() end
        it.hover = false
        it.dying = true
        it.dyingAt = os.clock()
        local actor = it.actor or it.side -- украденный предмет использует тот, кто украл
        local rec = {name = it.name, cue = false, done = false}
        FX.anim[actor] = rec
        task.spawn(function()
            local sd = (actor == "Player") and 1 or -1
            local faceYaw = (sd < 0) and math.pi or 0
            local main = FX.Hands[actor].rear -- правая рука
            local off = FX.Hands[actor].fore  -- левая рука
            local cur = CFrame.new(it.pos) * CFrame.Angles(0, it.yaw, 0) * it.bake -- поза в "стоячем" виде модели
            local gripAt = Vector3.new(0, 0.5, 0) -- за какое место модели держит рука
            local holding = true
            local function pose(cf)
                it.model:PivotTo(cf * it.bakeInv)
                if holding then main.pos = (cf * CFrame.new(gripAt)).Position + Vector3.new(0, 0, sd * 0.12) end
            end
            local function moveTo(target, dur, arc, snappy)
                local from = cur
                runAnim(dur, function(a)
                    local cf = from:Lerp(target, snappy and (a * a * a) or ease(a))
                    if arc then cf = cf + Vector3.new(0, math.sin(a * math.pi) * arc, 0) end
                    pose(cf)
                end)
                cur = target
                pose(cur)
            end
            local function handTo(hand, target, dur, arc)
                local from = hand.pos
                runAnim(dur, function(a)
                    hand.pos = from:Lerp(target, ease(a)) + Vector3.new(0, math.sin(a * math.pi) * (arc or 0), 0)
                end)
                hand.pos = target
            end
            local function handIn(hand, target, dur)
                hand.pos = target
                runAnim(dur, function(a) hand.k = ease(a) end)
                hand.k = 1
            end
            local function handOut(hand)
                local k0 = hand.k
                if k0 <= 0 then return end
                runAnim(0.12, function(a) hand.k = k0 * (1 - ease(a)) end)
                hand.k = 0
            end
            local function fade(dur)
                runAnim(dur, function(a)
                    for _, e in ipairs(it.parts) do e.p.Transparency = e.t + (1 - e.t) * a end
                end)
            end
            local function named(n)
                local list = {}
                for _, e in ipairs(it.parts) do
                    if e.p.Name == n then table.insert(list, e) end
                end
                return list
            end
            local function screenTint(color, alpha, dur)
                FlashOverlay.BackgroundColor3 = color
                FlashOverlay.BackgroundTransparency = alpha
                TweenService:Create(FlashOverlay, TweenInfo.new(dur), {BackgroundTransparency = 1}):Play()
            end
            local stage = CFrame.new(0, 1.8, sd * 2.0) * CFrame.Angles(0, faceYaw, 0)
            local name = it.name
            local gunMoved = false

            -- ===== вспомогательное для резких анимаций v11 =====
            local D = FX.Dealer
            local isD = (actor == "Dealer")
            local function dr(t) -- реакция Дилера (голова/корпус) на то, что он делает
                if isD then for k, v in pairs(t) do D[k] = v end end
            end
            local function mouthPos()
                if sd > 0 then return (BASE_CAM * CFrame.new(0, -0.75, -1.7)).Position end
                return Vector3.new(0, 3.1, DEALER_Z + 1.35)
            end
            -- деталь, добавленная предмету прямо во время анимации (координаты как в buildItemModel)
            local function addLocal(kind, size, lcf, color, mat, tr)
                local base = it.model:GetPivot() * it.bake
                local p = mk(it.model, kind, size * 1.3, base * CFrame.new(lcf.Position * 1.3) * (lcf - lcf.Position), color, mat, tr)
                table.insert(it.parts, {p = p, t = p.Transparency})
                return p
            end
            local function hideNamed(n)
                for _, e in ipairs(it.parts) do
                    if e.p.Name == n then e.t = 1; e.p.Transparency = 1 end
                end
            end
            -- швырнуть предмет по дуге (в пол / в сторону)
            local function fling(target, dur, spinX, spinY)
                holding = false
                local c0 = cur
                runAnim(dur, function(a)
                    local cf = c0:Lerp(target, a * a) + Vector3.new(0, math.sin(a * math.pi) * 1.6 * (1 - a * 0.5), 0)
                    it.model:PivotTo(cf * CFrame.Angles(a * (spinX or 9), a * (spinY or 6), 0) * it.bakeInv)
                end)
                cur = target
            end
            -- берёт дробовик со стола в руки
            local function grabGun(gunPose, dur)
                if GunCtl.holder ~= nil then return false end
                gunMoved = true
                local gFrom = GunRoot.CFrame
                off.pos = (gFrom * CFrame.new(0, -0.08 * GUN_S, -0.8 * GUN_S)).Position
                runAnim(0.08, function(a) off.k = ease(a) end)
                runAnim(dur, function(a)
                    GunRoot.CFrame = gFrom:Lerp(gunPose, ease(a)) + Vector3.new(0, math.sin(a * math.pi) * 0.4, 0)
                    syncGunParts()
                    off.pos = (GunRoot.CFrame * CFrame.new(0, -0.2 * GUN_S, -0.8 * GUN_S)).Position
                end)
                GunRoot.CFrame = gunPose; syncGunParts()
                return true
            end
            local function dropGun(dur)
                if not gunMoved then return end
                local gFrom = GunRoot.CFrame
                runAnim(dur, function(a)
                    GunRoot.CFrame = gFrom:Lerp(REST_CF, ease(a))
                    syncGunParts()
                    off.pos = (GunRoot.CFrame * CFrame.new(0, -0.08 * GUN_S, -0.8 * GUN_S)).Position
                end)
                GunRoot.CFrame = REST_CF; syncGunParts()
                gunMoved = false
            end
            if isD then D.fast = true end

            local function body()
                if name == "Magnifying Glass" then
                    -- ЛУПА: резкий удар о стол -> остаётся ПОЛОВИНА линзы, вся в острых углах -> вонзаю её в стол
                    local yawCF = CFrame.Angles(0, faceYaw, 0)
                    local spot = Vector3.new(0, 0, sd * 4.6) -- у моего края стола, рядом со мной (не у дробовика)
                    gripAt = Vector3.new(0.55, 0.25, 0) -- за ручку
                    dr{leanT = -0.2, nodT = -0.15}
                    moveTo(CFrame.new(spot + Vector3.new(0, 3.1, sd * 0.4)) * yawCF * CFrame.Angles(math.rad(75), 0, math.rad(15)), 0.34, 0.2)
                    task.wait(0.12) -- замер перед ударом
                    -- удар 1: перевёрнутая лупа бьётся линзой о стол
                    local hit1 = CFrame.new(spot + Vector3.new(0, 2.0, 0)) * yawCF * CFrame.Angles(math.pi, 0, 0)
                    dr{leanT = 0.6, nodT = 0.35, kick = 0.5}
                    moveTo(hit1, 0.045, nil, true)
                    task.wait(0.07) -- hit-stop: удар «застывает»
                    -- целая линза и обод пропадают, вместо них остаётся половина с рваным краем
                    hideNamed("Lens"); hideNamed("Rim"); hideNamed("Stud")
                    local BR = Color3.fromRGB(210, 170, 70)
                    local GL = Color3.fromRGB(190, 235, 255)
                    local R = 0.475
                    for k = 0, 7 do -- половина обода (со стороны ручки)
                        local a = math.pi + (k + 0.5) * math.pi / 8
                        addLocal("block", Vector3.new(0.1, 0.2, 0.14), CFrame.new(math.cos(a) * R, 0.95 + math.sin(a) * R, 0) * CFrame.Angles(0, 0, a), BR, Enum.Material.Metal)
                    end
                    for i = -4, 4 do -- уцелевшая половина стекла: рваный верх, каждый осколок под своим углом
                        local x = i * 0.1
                        local depth = math.sqrt(math.max(0.01, R * R - x * x))
                        local jag = (i % 2 == 0) and (0.14 + math.random() * 0.26) or (0.02 + math.random() * 0.1)
                        local top, bot = 0.95 + jag, 0.95 - depth + 0.03
                        addLocal("block", Vector3.new(0.098, top - bot, 0.05), CFrame.new(x, (top + bot) / 2, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.2), GL, Enum.Material.Glass, 0.25)
                    end
                    for k = 1, 8 do -- острые иглы стекла
                        local x = -0.43 + (k - 1) * 0.123 + (math.random() - 0.5) * 0.05
                        local len = 0.22 + math.random() * 0.2
                        addLocal("block", Vector3.new(0.045, len, 0.025), CFrame.new(x, 1.0 + len * 0.45, 0.01) * CFrame.Angles(0, 0, (math.random() - 0.5) * 1.0), Color3.fromRGB(235, 250, 255), Enum.Material.Neon, 0.3)
                    end
                    shards(spot + Vector3.new(0, 0.2, 0), 30, GL, Enum.Material.Glass, 6.5, 0.17, 0.25)
                    emit(spot + Vector3.new(0, 0.3, 0), 12, Color3.fromRGB(220, 245, 255), 5, 0.4, 0.05)
                    playSFX(SOUNDS.Rack, 2.4)
                    playSFX(SOUNDS.Blank, 2.6)
                    shake = math.max(shake, 1.0)
                    screenTint(Color3.fromRGB(220, 240, 255), 0.7, 0.2)
                    task.wait(0.05)
                    -- рывок вверх остатком и сразу вбиваю рваным краем в стол
                    moveTo(CFrame.new(spot + Vector3.new(0, 3.9, sd * 0.7)) * yawCF * CFrame.Angles(math.rad(160), 0, 0), 0.24)
                    task.wait(0.1)
                    local hit2 = CFrame.new(spot + Vector3.new(0, 1.62, 0)) * yawCF * CFrame.Angles(math.pi, 0, math.rad(-8))
                    dr{leanT = -0.3, kick = 0.9}
                    moveTo(hit2, 0.035, nil, true)
                    playSFX(SOUNDS.Shot, 0.55)
                    playSFX(SOUNDS.Saw, 1.8)
                    shake = math.max(shake, 2.4)
                    task.wait(0.1) -- hit-stop
                    tableCracks(spot)
                    shards(spot + Vector3.new(0, 0.15, 0), 16, Color3.fromRGB(74, 48, 28), Enum.Material.Wood, 5, 0.2, 0)
                    shards(spot + Vector3.new(0, 0.2, 0), 10, GL, Enum.Material.Glass, 3.5, 0.1, 0.25)
                    emit(spot + Vector3.new(0, 0.2, 0), 10, Color3.fromRGB(255, 220, 130), 6, 0.3, 0.05)
                    -- проворачивает, вдавливая
                    runAnim(0.22, function(a)
                        pose(hit2 * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, math.sin(a * math.pi * 3) * 0.3 * (1 - a), 0) * CFrame.new(0, -1.6, 0))
                    end)
                    holding = false
                    handOut(main) -- половина линзы остаётся торчать в столе
                    rec.cue = true
                    task.wait(1.5)

                elseif name == "Screwdriver" then
                    -- ОТВЁРТКА: хватает дробовик и жёстко, одним рывком выдирает патрон
                    gripAt = Vector3.new(0, 0.4, 0)
                    dr{leanT = 0.9, nodT = 0.3}
                    moveTo(CFrame.new(1.7, 2.3, sd * 2.8) * CFrame.Angles(0, 0, math.rad(35)), 0.24, 0.3)
                    local gunPose = CFrame.new(-0.1, 1.45, sd * 2.1) * CFrame.Angles(0, math.rad(90 * sd), 0) * CFrame.Angles(0, 0, math.rad(75))
                    local port = (gunPose * CFrame.new(0.17 * GUN_S, 0.04 * GUN_S, 0.12 * GUN_S)).Position
                    local gunFree = grabGun(gunPose, 0.14)
                    local TIP = 1.38 * 1.3
                    local function pry(angle, depth)
                        return CFrame.new(port) * CFrame.Angles(0, 0, angle) * CFrame.Angles(math.pi, 0, 0) * CFrame.new(0, -TIP - depth, 0)
                    end
                    moveTo(pry(math.rad(-35), 0.55), 0.2)
                    task.wait(0.1)
                    moveTo(pry(math.rad(-35), -0.08), 0.03, nil, true) -- вогнал жало в окно
                    playSFX(SOUNDS.Rack, 1.8)
                    shake = math.max(shake, 0.5)
                    emit(port, 6, Color3.fromRGB(255, 205, 110), 3, 0.25, 0.04)
                    for i = 1, 2 do -- два злых рывка
                        runAnim(0.11, function(a) pose(pry(math.rad(-35) - math.sin(a * math.pi) * math.rad(38), -0.08)) end)
                        task.wait(0.05)
                        playSFX(SOUNDS.Rack, 2.2 + i * 0.2)
                        emit(port, 4, Color3.fromRGB(255, 205, 110), 3, 0.25, 0.035)
                        shake = math.max(shake, 0.4)
                        if gunFree then
                            GunRoot.CFrame = gunPose * CFrame.Angles(0, 0, 0.07 * ((i % 2) * 2 - 1)); syncGunParts()
                        end
                    end
                    cur = pry(math.rad(-35), -0.08)
                    dr{kick = 0.6}
                    moveTo(pry(math.rad(-15), -0.08), 0.12) -- отвожу назад для рывка
                    moveTo(pry(math.rad(-90), -0.02), 0.04, nil, true) -- резкий выдирающий рывок рычагом
                    if gunFree then GunRoot.CFrame = gunPose; syncGunParts() end
                    playSFX(SOUNDS.Blank, 1.7)
                    playSFX(SOUNDS.Shot, 1.9)
                    shake = math.max(shake, 1.0)
                    emit(port, 8, Color3.fromRGB(255, 190, 90), 6, 0.3, 0.05)
                    if rec.live ~= nil then spawn3DShell(rec.live, port + Vector3.new(0, 0.15, 0)) end -- патрон вылетает на разметку
                    task.wait(0.34) -- hit-stop, патрон летит
                    rec.cue = true
                    moveTo(CFrame.new(1.9, 1.6, sd * 3.0) * CFrame.Angles(0, 0, math.rad(60)), 0.14, 0.3, true)
                    dropGun(0.16)

                elseif name == "Inverter" then
                    -- РЕВЕРСЕР: хватает, резко щёлкает тумблером, лампы меняются местами
                    gripAt = Vector3.new(0.5, 0.35, 0)
                    local held = CFrame.new(0.1, 2.0, sd * 2.9) * CFrame.Angles(0, faceYaw, 0) * CFrame.Angles(math.rad(-12), 0, 0)
                    dr{leanT = 0.4, yawT = 0.2}
                    moveTo(held, 0.2, 0.5, true)
                    local levers = {}
                    local rootCF = it.model:GetPivot()
                    for _, e in ipairs(named("Lever")) do table.insert(levers, {p = e.p, rel = rootCF:ToObjectSpace(e.p.CFrame)}) end
                    local pivot = CFrame.new(0, 0.65 * 1.3, 0)
                    local function setLever(ang)
                        local base = it.model:GetPivot()
                        for _, l in ipairs(levers) do
                            l.p.CFrame = base * pivot * CFrame.Angles(0, 0, ang) * pivot:Inverse() * l.rel
                        end
                    end
                    setLever(0.6)
                    local function knob(ang) return (held * pivot * CFrame.Angles(0, 0, ang) * CFrame.new(-0.12, 0.62, 0)).Position end
                    handIn(off, knob(0.6) + Vector3.new(-0.5, 0.3, 0), 0.08)
                    handTo(off, knob(0.6), 0.07)
                    task.wait(0.12) -- палец на тумблере
                    runAnim(0.035, function(a)
                        local ang = 0.6 - 1.2 * a
                        pose(held); setLever(ang); off.pos = knob(ang)
                    end)
                    playSFX(SOUNDS.Rack, 2.5) -- ЩЁЛК
                    shake = math.max(shake, 1.1)
                    task.wait(0.08) -- hit-stop
                    local a1, b1 = named("LampA")[1], named("LampB")[1]
                    if a1 and b1 then
                        a1.p.Color, a1.p.Material = Color3.fromRGB(70, 20, 18), Enum.Material.SmoothPlastic
                        b1.p.Color, b1.p.Material = Color3.fromRGB(70, 255, 110), Enum.Material.Neon
                        emit(b1.p.Position, 8, Color3.fromRGB(120, 255, 150), 2, 0.3, 0.04, 0)
                    end
                    rec.cue = true
                    playSFX(SOUNDS.Zap, 1.9)
                    runAnim(0.22, function(a)
                        pose(held * CFrame.new((math.random() - 0.5) * 0.1 * (1 - a), (math.random() - 0.5) * 0.1 * (1 - a), 0))
                        setLever(-0.6)
                    end)
                    handOut(off)
                    moveTo(CFrame.new(2.0, 0.6, sd * 2.6) * CFrame.Angles(0, faceYaw, 0), 0.14, 0.3, true)
                    setLever(-0.6)

                elseif name == "Expired Medicine" then
                    -- ТАБЛЕТКИ: срываю крышку, вытряхиваю таблетку и глотаю. Эффект только после этого
                    gripAt = Vector3.new(0.3, 0.45, 0)
                    local held = CFrame.new(0.35, 1.8, sd * 2.9) * CFrame.Angles(0, faceYaw, 0)
                    dr{nodT = 0.25, leanT = 0.3}
                    moveTo(held, 0.16, 0.4, true)
                    local capParts = {}
                    local rootCF = it.model:GetPivot()
                    for _, e in ipairs(named("Cap")) do table.insert(capParts, {e = e, rel = rootCF:ToObjectSpace(e.p.CFrame)}) end
                    local capC = CFrame.new(0, 1.09 * 1.3, 0)
                    local function setCap(world) -- world = где сейчас центр крышки
                        for _, c in ipairs(capParts) do c.e.p.CFrame = world * capC:Inverse() * c.rel end
                    end
                    local top = held * capC
                    handIn(off, top.Position + Vector3.new(-0.4, 0.5, 0), 0.07)
                    handTo(off, top.Position + Vector3.new(0, 0.2, 0), 0.06)
                    -- одним резким поворотом срываю крышку и отшвыриваю
                    local turn = 0
                    runAnim(0.1, function(a)
                        turn = a * 4.5
                        local cap = held * capC * CFrame.new(0, turn * 0.06, 0) * CFrame.Angles(0, turn, 0)
                        setCap(cap)
                        off.pos = cap.Position + Vector3.new(0, 0.2, 0)
                    end)
                    playSFX(SOUNDS.Rack, 2.8)
                    shake = math.max(shake, 0.5)
                    task.wait(0.07)
                    local capFrom = held * capC * CFrame.new(0, turn * 0.06, 0)
                    local capTo = CFrame.new(-1.7, 0.18, sd * 2.5)
                    runAnim(0.17, function(a)
                        local cap = capFrom:Lerp(capTo, a * a) + Vector3.new(0, math.sin(a * math.pi) * 0.7, 0)
                        setCap(cap)
                        off.pos = cap.Position + Vector3.new(0, 0.2, 0)
                    end)
                    local function keepCap() setCap(capTo) end
                    local palm = Vector3.new(-0.65, 1.35, sd * 2.9)
                    handTo(off, palm, 0.09, 0.2)
                    keepCap()
                    -- резко наклоняю банку и встряхиваю
                    local tipped = CFrame.new(0.55, 2.25, sd * 2.9) * CFrame.Angles(0, 0, math.rad(112)) * CFrame.Angles(0, faceYaw, 0)
                    local from = cur
                    runAnim(0.12, function(a) pose(from:Lerp(tipped, ease(a))); keepCap() end)
                    for _ = 1, 2 do
                        runAnim(0.06, function(a) pose(tipped * CFrame.new(0, math.sin(a * math.pi) * 0.16, 0)); keepCap() end)
                        playSFX(SOUNDS.Rack, 3.0)
                    end
                    cur = tipped
                    local pill = newModel(WorldModel)
                    rec.temp = pill
                    mk(pill, "cyl", Vector3.new(0.2, 0.17, 0.17), CFrame.new(-0.09, 0, 0), Color3.fromRGB(236, 230, 214))
                    mk(pill, "cyl", Vector3.new(0.2, 0.175, 0.175), CFrame.new(0.09, 0, 0), Color3.fromRGB(160, 40, 34))
                    mk(pill, "ball", Vector3.new(0.17, 0.17, 0.17), CFrame.new(-0.19, 0, 0), Color3.fromRGB(236, 230, 214))
                    mk(pill, "ball", Vector3.new(0.175, 0.175, 0.175), CFrame.new(0.19, 0, 0), Color3.fromRGB(160, 40, 34))
                    local mouthOfBottle = (tipped * CFrame.new(0, 1.35, 0)).Position
                    local onPalm = palm + Vector3.new(0, 0.34, -0.15)
                    runAnim(0.1, function(a)
                        pill:PivotTo(CFrame.new(mouthOfBottle:Lerp(onPalm, a * a)) * CFrame.Angles(a * 7, 0, a * 5))
                    end)
                    -- банку отбрасываю на стол, таблетку в рот
                    moveTo(CFrame.new(1.8, 0.05, sd * 2.5) * CFrame.Angles(0, faceYaw, 0), 0.14, 0.4, true)
                    keepCap()
                    holding = false
                    task.spawn(handOut, main)
                    local mouth = mouthPos()
                    local p0 = off.pos
                    runAnim(0.2, function(a)
                        off.pos = p0:Lerp(mouth + Vector3.new(0, -0.35, 0), ease(a))
                        pill:PivotTo(CFrame.new(off.pos + Vector3.new(0, 0.34, -0.15 * sd)))
                    end)
                    runAnim(0.07, function(a)
                        pill:PivotTo(CFrame.new((off.pos + Vector3.new(0, 0.34, -0.15 * sd)):Lerp(mouth, a)))
                    end)
                    pill:Destroy()
                    rec.temp = nil
                    playSFX(SOUNDS.Blank, 0.45) -- глоток
                    shake = math.max(shake, 0.35)
                    if sd > 0 then
                        screenTint(Color3.new(0, 0, 0), 0.2, 0.5)
                    else
                        dr{leanT = -0.35, nodT = -0.45}
                    end
                    handOut(off)
                    task.wait(0.2)
                    dr{leanT = 0, nodT = 0}
                    rec.cue = true -- таблетка проглочена: теперь действует
                    task.wait(0.2)

                elseif name == "Handcuffs" then
                    -- НАРУЧНИКИ: быстро несу к рукам соперника и жёстко защёлкиваю
                    local victim = (actor == "Player") and "Dealer" or "Player"
                    local wz = (victim == "Dealer") and (DEALER_Z + 2.7) or 4.6
                    local wy = 0.55
                    gripAt = Vector3.new(0, 0.55, 0)
                    camTarget = (victim == "Dealer") and CFrame.lookAt(Vector3.new(0, 4.6, 2.2), Vector3.new(0, 0.8, -4.0)) or CFrame.lookAt(Vector3.new(0, 5.4, 9.2), Vector3.new(0, 0.4, 4.4))
                    FX.cuffHand[victim].hold = true -- жертва кладёт руки на стол
                    dr{yawT = 0.2, leanT = 0.5}
                    playSFX(SOUNDS.Rack, 0.9)
                    moveTo(CFrame.new(0, 1.9, sd * 0.8) * CFrame.Angles(0, faceYaw, 0), 0.18, 0.5, true)
                    moveTo(CFrame.new(0, wy + 0.9, wz) * CFrame.Angles(0, faceYaw, 0), 0.2, 0.5)
                    task.wait(0.1)
                    moveTo(CFrame.new(0, wy - 0.35, wz) * CFrame.Angles(0, faceYaw, 0), 0.04, nil, true)
                    FX.cuffHand[victim].hold = false
                    GameState[victim .. "Cuffed"] = true -- теперь наручники видно на запястьях
                    GameState[victim .. "CuffSkipped"] = false
                    for _, e in ipairs(it.parts) do e.t = 1; e.p.Transparency = 1 end
                    playSFX(SOUNDS.Rack, 2.1)
                    playSFX(SOUNDS.Blank, 2.4)
                    shake = math.max(shake, 1.8)
                    task.wait(0.1)
                    emit(Vector3.new(0, wy, wz), 10, Color3.fromRGB(220, 220, 235), 3, 0.25, 0.04)
                    holding = false
                    handOut(main)
                    playSFX(SOUNDS.Rack, 1.9)
                    task.wait(0.4)
                    rec.cue = true

                elseif name == "Handsaw" then
                    -- ПИЛА: хватаю дробовик и на весу быстро отпиливаю дуло
                    gripAt = Vector3.new(-0.9, 0.8, 0) -- за рукоять пилы
                    dr{leanT = 0.7, nodT = 0.3, yawT = 0.2}
                    local gunPose = CFrame.new(-0.1, 1.5, sd * 2.4) * CFrame.Angles(0, math.rad(90 * sd), 0)
                    local C = (gunPose * CFrame.new(0, 0.1 * GUN_S, -1.42 * GUN_S)).Position -- место реза
                    local base = CFrame.new(C) * CFrame.Angles(0, math.pi / 2, 0)
                    local function sawCF(o, s) return base * CFrame.new(-0.2 + o, -0.18 - 0.3 * s, 0) end
                    local gunFree = grabGun(gunPose, 0.2)
                    moveTo(sawCF(0, 0), 0.24, 0.5)
                    task.wait(0.1)
                    playSFX(SOUNDS.Saw, 1.7)
                    runAnim(0.75, function(a)
                        local o = math.sin(a * math.pi * 9) * 0.5
                        pose(sawCF(o, a))
                        if gunFree then
                            GunRoot.CFrame = gunPose * CFrame.new((math.random() - 0.5) * 0.04, (math.random() - 0.5) * 0.04, 0)
                            syncGunParts()
                        end
                        shake = math.max(shake, 0.4)
                        if math.random() < 0.85 then
                            emit(C + Vector3.new(0, 0.1, o * -0.3), 2, Color3.fromRGB(255, 200, 90), 4, 0.35, 0.05)
                        end
                    end)
                    cur = sawCF(0, 1)
                    if gunFree then GunRoot.CFrame = gunPose; syncGunParts() end
                    -- дуло отрезано и падает на стол
                    gunSawedOverride = true
                    syncGunParts()
                    local tipCF = gunPose * CFrame.new(0, 0.1 * GUN_S, -1.8 * GUN_S)
                    local piece = mk(WorldModel, "cylZ", Vector3.new(0.19 * GUN_S, 0.19 * GUN_S, 0.8 * GUN_S), tipCF, Color3.fromRGB(62, 62, 70), Enum.Material.Metal)
                    local ppos, pvel, pyaw = tipCF.Position, Vector3.new(-sd * 2.2, 2.6, sd * 0.8), 0
                    task.spawn(function()
                        local age, dt, rest = 0, 0.03, false
                        while age < 2.2 do
                            if not rest then
                                pvel = pvel + Vector3.new(0, -26 * dt, 0)
                                ppos = ppos + pvel * dt
                                pyaw += 9 * dt
                                if ppos.Y <= 0.17 then
                                    ppos = Vector3.new(ppos.X, 0.17, ppos.Z)
                                    if pvel.Y < -3 then
                                        pvel = Vector3.new(pvel.X * 0.5, -pvel.Y * 0.3, pvel.Z * 0.5)
                                        playSFX(SOUNDS.Rack, 0.6)
                                    else
                                        rest = true
                                    end
                                end
                                piece.CFrame = CFrame.new(ppos) * CFrame.Angles(0, pyaw * 0.5, 0) * (tipCF - tipCF.Position) * CFrame.Angles(0, math.pi / 2, 0)
                            end
                            task.wait(dt)
                            age += dt
                        end
                        piece:Destroy()
                    end)
                    playSFX(SOUNDS.Rack, 0.7)
                    playSFX(SOUNDS.Shot, 1.6)
                    shake = math.max(shake, 1.6)
                    emit(C, 16, Color3.fromRGB(255, 190, 80), 7, 0.3, 0.05)
                    dr{kick = 0.7}
                    rec.cue = true
                    task.wait(0.18) -- hit-stop
                    -- швыряю пилу в сторону и кладу дробовик на место
                    moveTo(CFrame.new(-2.4, 0.5, sd * 3.6) * CFrame.Angles(0, math.pi / 2, 0), 0.14, 0.6, true)
                    dropGun(0.16)
                    gunSawedOverride = false
                    syncGunParts()

                elseif name == "Cigarettes" then
                    -- СИГАРЕТЫ: выхватываю, прикуриваю, две резкие затяжки, выдох дыма
                    gripAt = Vector3.new(0, 0.5, 0)
                    local mp = mouthPos()
                    local packAt = CFrame.new(mp + Vector3.new(0.4, -0.7, 0)) * CFrame.Angles(0, faceYaw, math.rad(-18))
                    dr{nodT = 0.2, leanT = 0.3}
                    moveTo(packAt, 0.26, 0.5)
                    task.wait(0.08)
                    local cigs = named("Cig")
                    if cigs[2] then cigs[2].t = 1; cigs[2].p.Transparency = 1 end
                    local emberP = mk(WorldModel, "ball", Vector3.new(0.1, 0.1, 0.1), CFrame.new(mp + Vector3.new(0, 0.02, -sd * 0.22)), Color3.fromRGB(255, 110, 30), Enum.Material.Neon)
                    rec.temp = emberP
                    playSFX(SOUNDS.Rack, 2.2)
                    emit(emberP.Position, 8, Color3.fromRGB(255, 190, 80), 3, 0.25, 0.04)
                    for _ = 1, 2 do -- две жадные затяжки
                        runAnim(0.14, function(a)
                            local s = 0.1 + math.sin(a * math.pi) * 0.14
                            emberP.Size = Vector3.new(s, s, s)
                            pose(packAt * CFrame.new(0, -math.sin(a * math.pi) * 0.1, 0))
                        end)
                        emit(emberP.Position, 3, Color3.fromRGB(255, 150, 60), 1.5, 0.2, 0.03, 0)
                    end
                    rec.cue = true -- затянулся: здоровье восстанавливается
                    dr{nodT = -0.3}
                    emit(mp + Vector3.new(0, 0.05, -sd * 0.3), 16, Color3.fromRGB(190, 190, 190), 1.6, 1.3, 0.24, 1.6)
                    playSFX(SOUNDS.Blank, 0.5)
                    task.wait(0.22)
                    emberP:Destroy()
                    rec.temp = nil
                    moveTo(CFrame.new(2.2, 0.3, sd * 3.2) * CFrame.Angles(0, faceYaw, 0), 0.14, 0.4, true)

                elseif name == "Burner Phone" then
                    -- ТЕЛЕФОН: подношу к уху (камера приезжает к нему), слушаю, потом разбиваю о стол и швыряю на пол
                    gripAt = Vector3.new(0, 0.5, 0)
                    local camPrev = camTarget
                    local ear
                    if sd > 0 then
                        ear = CFrame.new(0.7, 3.1, 6.0) * CFrame.Angles(0, faceYaw, math.rad(-10))
                        camTarget = CFrame.lookAt(Vector3.new(0.2, 4.4, 9.2), Vector3.new(0.7, 2.9, 5.2))
                    else
                        ear = CFrame.new(0.8, 3.1, DEALER_Z + 1.2) * CFrame.Angles(0, faceYaw, math.rad(10))
                    end
                    local spot = Vector3.new(0.6, 0, sd * 2.6)
                    dr{tiltT = 0.4, yawT = 0.25, nodT = 0.1}
                    moveTo(ear, 0.18, 0.6, true)
                    -- слушаю: корпус дрожит, экран мигает
                    local scr = named("Screen")
                    playSFX(SOUNDS.Blank, 1.8)
                    runAnim(0.85, function(a)
                        pose(ear * CFrame.new((math.random() - 0.5) * 0.05, (math.random() - 0.5) * 0.05, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.06))
                        for _, e in ipairs(scr) do e.p.Transparency = (math.random() < 0.3) and 0.5 or 0 end
                        if math.random() < 0.3 then
                            emit((ear * CFrame.new(0, 1.1, 0.1)).Position, 1, Color3.fromRGB(100, 255, 140), 1.5, 0.4, 0.05, 0)
                        end
                    end)
                    for _, e in ipairs(scr) do e.p.Transparency = e.t end
                    cur = ear
                    rec.cue = true -- информация получена
                    -- ярость: замах и удар об стол
                    dr{tiltT = 0, yawT = 0, nodT = 0.4, leanT = 0.8, kick = 0.4}
                    local yawCF = CFrame.Angles(0, faceYaw, 0)
                    local raise = CFrame.new(spot + Vector3.new(0, 3.4, sd * 0.3)) * yawCF * CFrame.Angles(math.rad(-40), 0, 0)
                    local slam = CFrame.new(spot + Vector3.new(0, 0.1, 0)) * yawCF * CFrame.Angles(-math.pi / 2, 0, 0)
                    moveTo(raise, 0.26)
                    task.wait(0.1)
                    moveTo(slam, 0.035, nil, true)
                    playSFX(SOUNDS.Shot, 0.8)
                    playSFX(SOUNDS.Saw, 2.0)
                    shake = math.max(shake, 1.8)
                    task.wait(0.09) -- hit-stop
                    for k = 1, 5 do -- трещины по экрану
                        addLocal("block", Vector3.new(0.02, 0.2 + math.random() * 0.2, 0.02), CFrame.new((math.random() - 0.5) * 0.35, 0.8 + (math.random() - 0.5) * 0.3, 0.1) * CFrame.Angles(0, 0, math.random() * 3), Color3.fromRGB(235, 240, 235))
                    end
                    shards(spot + Vector3.new(0, 0.2, 0), 10, Color3.fromRGB(32, 32, 38), Enum.Material.SmoothPlastic, 5, 0.15, 0)
                    emit(spot + Vector3.new(0, 0.3, 0), 10, Color3.fromRGB(255, 220, 120), 6, 0.3, 0.05)
                    moveTo(slam + Vector3.new(0, 1.6, 0), 0.17)
                    task.wait(0.06)
                    moveTo(slam, 0.035, nil, true) -- второй удар: добиваю
                    playSFX(SOUNDS.Shot, 1.1)
                    playSFX(SOUNDS.Rack, 2.4)
                    shake = math.max(shake, 2.4)
                    task.wait(0.12) -- hit-stop
                    if sd > 0 then screenTint(Color3.fromRGB(255, 255, 255), 0.8, 0.15) end
                    for _, e in ipairs(it.parts) do -- экран и лампочка гаснут
                        if e.p.Material == Enum.Material.Neon then
                            e.p.Color = Color3.fromRGB(14, 22, 14)
                            e.p.Material = Enum.Material.SmoothPlastic
                        end
                    end
                    hideNamed("Antenna")
                    shards(spot + Vector3.new(0, 0.2, 0), 18, Color3.fromRGB(32, 32, 38), Enum.Material.SmoothPlastic, 7, 0.16, 0)
                    shards(spot + Vector3.new(0, 0.25, 0), 8, Color3.fromRGB(90, 255, 120), Enum.Material.Neon, 4, 0.1, 0.2)
                    emit(spot + Vector3.new(0, 0.3, 0), 14, Color3.fromRGB(255, 220, 120), 7, 0.35, 0.05)
                    -- хватаю обломок и швыряю на пол
                    moveTo(slam + Vector3.new(0, 0.9, 0), 0.08)
                    task.spawn(handOut, main)
                    local floorAt = (sd > 0) and CFrame.new(3.4, -7.0, 6.8) or CFrame.new(-3.4, -7.0, DEALER_Z + 2.0)
                    fling(floorAt * yawCF, 0.4)
                    playSFX(SOUNDS.Rack, 0.5) -- грохот на полу
                    shake = math.max(shake, 0.6)
                    if sd > 0 then camTarget = camPrev end
                    task.wait(0.1)

                elseif name == "Adrenaline" then
                    -- АДРЕНАЛИН: резко лечу шприцем и вгоняю в тело
                    local dirYaw = (sd > 0) and -math.pi / 2 or math.pi / 2
                    local aim = CFrame.new(0, 2.6, sd * 5.2) * CFrame.Angles(0, dirYaw, 0) * CFrame.Angles(0, 0, math.rad(-15))
                    dr{leanT = 0.5, yawT = 0.2}
                    moveTo(aim, 0.32, 0.6)
                    task.wait(0.2) -- замер, целюсь
                    local stab = aim + Vector3.new(0, -0.3, sd * 1.3)
                    moveTo(stab, 0.04, nil, true)
                    playSFX(SOUNDS.Heal, 1.4)
                    playSFX(SOUNDS.Shot, 1.9)
                    emit((stab * CFrame.new(0.9, 0, 0)).Position, 18, Color3.fromRGB(255, 160, 50), 5, 0.7, 0.08)
                    shake = math.max(shake, 1.8)
                    if sd > 0 then screenTint(Color3.fromRGB(255, 160, 60), 0.5, 0.4) end
                    task.wait(0.3) -- hit-stop
                end
            end

            pcall(function()
                main.pos = (cur * CFrame.new(0, 0.5, 0)).Position
                runAnim(0.12, function(a) main.k = ease(a) end) -- рука резко хватает предмет
            end)
            local camBefore = camTarget
            local ok, err = pcall(body)
            if not ok then
                warn("[BloxRoulette] item anim: " .. tostring(err))
                FX.cuffHand.Player.hold, FX.cuffHand.Dealer.hold = false, false
                if rec.temp then rec.temp:Destroy() end
                if gunMoved then GunRoot.CFrame = REST_CF; syncGunParts() end
                gunSawedOverride = false
            end
            if name == "Burner Phone" and sd > 0 then camTarget = camBefore end -- камера всегда возвращается от телефона
            if isD then -- Дилер расслабляет голову после предмета
                D.nodT, D.tiltT, D.yawT, D.leanT, D.fast = 0, 0, 0, 0, false
            end
            rec.cue = true
            pcall(fade, 0.15)
            pcall(handOut, main)
            pcall(handOut, off)
            main.k, off.k = 0, 0
            it.model:Destroy()
            rec.done = true
        end)
    end

    -- Сопоставляет списки предметов из игры с 3D-моделями: новые падают на стол, использованные улетают
    local function reconcile(side, list)
        local hint = FX.hint[side]      -- какой именно предмет только что использован
        FX.hint[side] = nil
        local pool, present = {}, {}
        for _, it in ipairs(displayed[side]) do
            present[it] = true
            if it ~= hint then
                pool[it.name] = pool[it.name] or {}
                table.insert(pool[it.name], it)
            end
        end
        local assigned, taken = {}, {}
        for idx, name in ipairs(list) do
            local q = pool[name]
            if q and #q > 0 then
                local it = table.remove(q, 1)
                assigned[idx] = it
                taken[it.slot or 0] = true   -- старый предмет остаётся в своей ячейке
            end
        end
        local newList, fresh = {}, 0
        for idx, name in ipairs(list) do
            local it = assigned[idx]
            if not it then
                local free = 1
                while taken[free] and free < 8 do free += 1 end
                taken[free] = true
                it = createItem(side, name)
                it.slot = free
                it.pos = Vector3.new(0, 1.1, FX.CASE_Z); it.vy = 7
                fresh += 1
            end
            it.target = slotPos(side, it.slot or 1)
            newList[idx] = it
        end
        for _, q in pairs(pool) do
            for _, it in ipairs(q) do discardItem(it) end
        end
        if hint and present[hint] then removeItem(hint) end
        displayed[side] = newList
        if fresh > 0 then playSFX(SOUNDS.Rack, 1.6) end
    end

    renderInventories = function()
        reconcile("Player", GameState.PlayerItems)
        reconcile("Dealer", GameState.DealerItems)
    end

    local function giveFairItems(count)
        local pSpace = 8 - #GameState.PlayerItems
        local dSpace = 8 - #GameState.DealerItems
        local actualGive = math.min(count, pSpace, dSpace)

        for _ = 1, actualGive do
            table.insert(GameState.PlayerItems, drawRandomItem())
            table.insert(GameState.DealerItems, drawRandomItem())
        end
        return actualGive
    end

    -- КЕЙС С ПРЕДМЕТАМИ: выезжает на ТВОЁМ конце стола, крышка открывается
    FX.CASE_Z = 5.55 -- положение коробки (конец стола)
    local function playCaseOpen()
        task.spawn(function()
            local DK = Color3.fromRGB(20, 20, 23)
            local Z = FX.CASE_Z
            local base = mk(WorldModel, "block", Vector3.new(3.2, 0.45, 1.35), CFrame.new(0, -2, Z), DK, Enum.Material.Metal)
            local inner = mk(WorldModel, "block", Vector3.new(2.85, 0.05, 1.05), CFrame.new(0, -2, Z), Color3.fromRGB(5, 5, 7), Enum.Material.Metal)
            local lid = mk(WorldModel, "block", Vector3.new(3.2, 0.11, 1.35), CFrame.new(0, -2, Z), DK, Enum.Material.Metal)
            local function place(zoff, ang)
                local o = Vector3.new(0, 0, Z + zoff)
                base.CFrame = CFrame.new(o + Vector3.new(0, 0.5, 0))
                inner.CFrame = CFrame.new(o + Vector3.new(0, 0.74, 0))
                -- крышка открывается к тебе, чтобы предметы летели на стол
                lid.CFrame = CFrame.new(o + Vector3.new(0, 0.75, 0.675)) * CFrame.Angles(ang, 0, 0) * CFrame.new(0, 0.055, -0.675)
            end
            playSFX(SOUNDS.Rack, 0.5)
            runAnim(0.45, function(a) place(2.2 * (1 - ease(a)), 0) end)
            task.wait(0.2)
            runAnim(0.45, function(a) place(0, ease(a) * 1.75) end)
            task.wait(2.4)
            runAnim(0.35, function(a) place(0, (1 - ease(a)) * 1.75) end)
            runAnim(0.4, function(a) place(2.2 * ease(a), 0) end)
            base:Destroy(); inner:Destroy(); lid:Destroy()
        end)
    end

    local function loadShotgun()
        refillItemBag()
        playSFX(SOUNDS.Rack, 1.0)
        GameState.Shells = {}
        GameState.SawActive = false
        local total = math.random(3, 8)
        local liveCount = math.clamp(math.floor(total / 2) + math.random(0, 1), 1, total - 1)
        local blankCount = total - liveCount

        for _ = 1, liveCount do table.insert(GameState.Shells, true) end
        for _ = 1, blankCount do table.insert(GameState.Shells, false) end

        for i = #GameState.Shells, 2, -1 do
            local j = math.random(1, i)
            GameState.Shells[i], GameState.Shells[j] = GameState.Shells[j], GameState.Shells[i]
        end

        local prePl, preDe = table.clone(GameState.PlayerItems), table.clone(GameState.DealerItems)
        local given = giveFairItems(math.random(2, 4))
        reconcile("Player", prePl) -- на столе пока только старые предметы, новые достанут из кейса
        reconcile("Dealer", preDe)

        GunRoot.CFrame = REST_CF
        DealerFace.Text = "[ ‿ ‿ ]"
        GameState.Intro = true
        FX.loadId = (FX.loadId or 0) + 1
        local myLoad = FX.loadId
        updateHPUI()

        task.spawn(function()
            local shells = {}
            local function alive()
                return myLoad == FX.loadId and not GameState.GameOver and ScreenGui.Parent ~= nil
            end
            local function finish()
                for _, m in ipairs(shells) do m:Destroy() end -- уже вставленные удалены раньше, повторный Destroy безопасен
                if myLoad == FX.loadId then GameState.Intro = false end
            end
            -- 1. раунд на экране справа
            if FX.roundUntil and os.clock() < FX.roundUntil then
                camTarget = CAM_HP
                task.wait(FX.roundUntil - os.clock() + 0.2)
                if not alive() then return finish() end
            end
            -- 2. патроны ложатся на разметку
            camTarget = BASE_CAM
            setLog("Я вставляю патроны в случайном порядке.", Color3.fromRGB(235, 230, 215))
            task.wait(0.7)
            if not alive() then return finish() end
            shells = showShellsOnTable(liveCount, blankCount)
            task.wait(0.5)
            setLog(string.format("%d боевых. %d холостых.", liveCount, blankCount), Color3.fromRGB(255, 215, 90))
            task.wait(2.4)
            if not alive() then return finish() end
            -- 3. Дилер сам заряжает дробовик
            camTarget = CFrame.lookAt(Vector3.new(0, 6.4, 4.6), Vector3.new(0, 1.0, -2.4))
            FX.dealerLoad(shells, alive)
            if not alive() then
                if GunCtl.holder == "Dealer" then GunCtl.release("Dealer") end
                FX.Hands.Dealer.rear.k = 0
                return finish()
            end
            -- 4. коробка с предметами в конце стола
            if given > 0 then
                camTarget = CFrame.lookAt(Vector3.new(0, 9.0, 10.2), Vector3.new(0, 0, 1.4))
                playCaseOpen()
                task.wait(1.15)
                if not alive() then return finish() end
                renderInventories()
                setLog(string.format("%d предм. каждому.", given), Color3.fromRGB(235, 230, 215))
                task.wait(2.2)
            else
                renderInventories()
            end
            if not alive() then return finish() end
            finish()
            camTarget = (GameState.Turn == "Dealer") and CAM_DEALER or BASE_CAM
        end)
    end

-- НАЧАЛО ЧАСТИ 6 (УЛУЧШЕНИЯ v9.0: атмосфера, эффекты выстрела, анимации, детали предметов, HUD).
-- Всё внутри одной таблицы FX.E и одного do-блока: лимит 200 локальных переменных не затронут.
-- Каждый вызов идёт через FX.fx() с pcall: если что-то в украшениях сломается, сама игра продолжит работать.
    do
        local E = {t = 0, fov = 0, roll = 0, swayK = 0, embT = 0, smokeT = 0, lastPh = 1, lampParts = {}, fog = {}}
        FX.E = E
        E.COL = {
            ["Magnifying Glass"] = Color3.fromRGB(150, 225, 255), ["Screwdriver"] = Color3.fromRGB(255, 200, 80),
            ["Handsaw"] = Color3.fromRGB(255, 150, 60), ["Handcuffs"] = Color3.fromRGB(130, 200, 255),
            ["Cigarettes"] = Color3.fromRGB(255, 130, 60), ["Inverter"] = Color3.fromRGB(200, 120, 255),
            ["Burner Phone"] = Color3.fromRGB(110, 255, 170), ["Expired Medicine"] = Color3.fromRGB(120, 255, 150),
            ["Adrenaline"] = Color3.fromRGB(255, 235, 90)
        }

        FX.fx = function(name, ...)
            local f = E[name]
            if f then
                local ok, err = pcall(f, ...)
                if not ok and not E["warned_" .. name] then
                    E["warned_" .. name] = true
                    warn("[BloxRoulette v9] " .. name .. ": " .. tostring(err))
                end
            end
        end

        -- звук с настраиваемой громкостью
        function E.sfx(id, pitch, vol)
            pcall(function()
                local s = Instance.new("Sound")
                s.SoundId = id
                s.Volume = vol or 0.5
                s.PlaybackSpeed = pitch or 1
                s.Parent = ScreenGui
                s:Play()
                task.delay(3, function() if s then s:Destroy() end end)
            end)
        end

        -- плоская ударная волна на столе
        function E.ring(pos, color, size)
            task.spawn(function()
                local d = mk(WorldModel, "cylY", Vector3.new(0.2, 0.05, 0.2), CFrame.new(pos), color, Enum.Material.Neon, 0.35)
                for i = 1, 12 do
                    local a = i / 12
                    local s = 0.2 + (size or 3) * a
                    d.Size = Vector3.new(0.05, s, s)
                    d.Transparency = 0.35 + 0.65 * a
                    task.wait(0.02)
                end
                d:Destroy()
            end)
        end

        -- шарообразная вспышка-волна
        function E.pulseBall(pos, color, size)
            task.spawn(function()
                local b = mk(WorldModel, "ball", Vector3.new(0.3, 0.3, 0.3), CFrame.new(pos), color, Enum.Material.Neon, 0.5)
                for i = 1, 9 do
                    local a = i / 9
                    local s = 0.3 + (size or 4) * a
                    b.Size = Vector3.new(s, s, s)
                    b.Transparency = 0.5 + 0.5 * a
                    task.wait(0.02)
                end
                b:Destroy()
            end)
        end

        -- выстрел: пинок камеры, лёгкий крен, пыль со стола
        function E.shot()
            E.fov = E.fov + 9
            E.roll = (math.random() - 0.5) * 0.05
            E.swayK = 0.1
            emit(Vector3.new(0, 0.3, 0.8), 10, Color3.fromRGB(70, 60, 55), 3, 0.8, 0.12, -3)
        end

        function E.muzzle(pos)
            E.pulseBall(pos, Color3.fromRGB(255, 205, 110), 4.5)
            E.ring(Vector3.new(pos.X, 0.12, pos.Z), Color3.fromRGB(255, 170, 70), 5)
            emit(pos, 12, Color3.fromRGB(255, 235, 150), 14, 0.35, 0.07, -2)
            E.swayK = math.max(E.swayK, 0.1)
        end

        -- потеря HP: толчок камеры и брызги на табло
        function E.hurt(isPlayer, side)
            E.fov = E.fov + (isPlayer and 7 or 4)
            E.roll = (math.random() < 0.5 and -1 or 1) * (isPlayer and 0.03 or 0.015)
            local bank = hpBanks[side]
            if bank then
                emit(bank.origin + Vector3.new(0, 0.8, 0), 14, Color3.fromRGB(255, 70, 70), 4, 0.8, 0.09, -6)
                E.ring(bank.origin + Vector3.new(0, 0.1, 0), Color3.fromRGB(255, 60, 60), 3)
            end
        end

        -- лечение: зелёный всплеск и всплывающая надпись +HP
        function E.healFX(side, amount)
            local bank = hpBanks[side]
            local origin = bank and bank.origin or Vector3.new(6.3, 1.5, 0)
            E.sfx(SOUNDS.Heal, 1.2, 0.45)
            emit(origin + Vector3.new(0, 0.8, 0), 18, Color3.fromRGB(90, 255, 150), 3, 1.0, 0.1, 1.5)
            E.ring(origin + Vector3.new(0, 0.1, 0), Color3.fromRGB(90, 255, 150), 3.5)
            local sx, sy = project(origin + Vector3.new(0, 1.6, 0))
            local pop = Instance.new("TextLabel", Viewport)
            pop.AnchorPoint = Vector2.new(0.5, 0.5)
            pop.Size = UDim2.new(0, 110, 0, 34)
            pop.Position = UDim2.new(sx, 0, sy, 0)
            pop.BackgroundTransparency = 1
            pop.Text = "+" .. amount .. " HP"
            pop.TextColor3 = Color3.fromRGB(90, 255, 150)
            pop.TextStrokeColor3 = Color3.new(0, 0, 0)
            pop.TextStrokeTransparency = 0
            pop.Font = Enum.Font.Code
            pop.TextSize = 26
            pop.ZIndex = 20
            TweenService:Create(pop, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(sx, 0, sy - 0.22, 0), TextTransparency = 1, TextStrokeTransparency = 1
            }):Play()
            task.delay(1.2, function() if pop then pop:Destroy() end end)
        end

        -- ДЕТАЛИ ПРЕДМЕТОВ (координаты в системе модели предмета, как в buildItemModel)
        function E.detail(m, name)
            local METAL = Enum.Material.Metal
            local NEON = Enum.Material.Neon
            if name == "Magnifying Glass" then
                mk(m, "block", Vector3.new(0.3, 0.05, 0.02), CFrame.new(-0.15, 1.12, 0.1) * CFrame.Angles(0, 0, math.rad(35)), Color3.new(1, 1, 1), NEON, 0.35).Name = "Lens"
                for k = 0, 5 do
                    local a = k * math.pi / 3
                    mk(m, "ball", Vector3.new(0.09, 0.09, 0.09), CFrame.new(math.cos(a) * 0.48, 0.95 + math.sin(a) * 0.48, 0.08), Color3.fromRGB(210, 170, 70), METAL).Name = "Stud"
                end
                mk(m, "ball", Vector3.new(0.19, 0.19, 0.19), CFrame.new(0.64, 0.07, 0), Color3.fromRGB(200, 160, 60), METAL)
            elseif name == "Screwdriver" then
                for _, x in ipairs({-0.17, 0.17}) do
                    mk(m, "block", Vector3.new(0.03, 0.3, 0.08), CFrame.new(x, 0.4, 0), Color3.fromRGB(28, 26, 26))
                end
            elseif name == "Handsaw" then
                for k = 0, 2 do
                    mk(m, "ball", Vector3.new(0.07, 0.07, 0.07), CFrame.new(-0.7, 0.46 + k * 0.16, 0.09), Color3.fromRGB(205, 170, 80), METAL)
                end
                mk(m, "block", Vector3.new(1.2, 0.02, 0.06), CFrame.new(0.15, 0.78, 0.03) * CFrame.Angles(0, 0, math.rad(-8)), Color3.new(1, 1, 1), NEON, 0.6)
            elseif name == "Handcuffs" then
                for _, x in ipairs({-0.28, 0.28}) do
                    mk(m, "block", Vector3.new(0.12, 0.09, 0.09), CFrame.new(x, 0.35, 0), Color3.fromRGB(170, 170, 180), METAL)
                end
                mk(m, "cylZ", Vector3.new(0.2, 0.2, 0.05), CFrame.new(0, 0.1, 0.35), Color3.fromRGB(210, 170, 60), METAL)
                mk(m, "block", Vector3.new(0.05, 0.3, 0.05), CFrame.new(0, 0.1, 0.5) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(210, 170, 60), METAL)
            elseif name == "Cigarettes" then
                mk(m, "block", Vector3.new(0.72, 0.08, 0.31), CFrame.new(0, 0.22, 0), Color3.fromRGB(215, 175, 60), METAL)
                mk(m, "block", Vector3.new(0.2, 0.2, 0.02), CFrame.new(0, 0.55, 0.16) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(200, 30, 30), NEON, 0.2)
            elseif name == "Inverter" then
                for _, sx in ipairs({-0.42, 0.42}) do
                    for _, sy in ipairs({0.07, 0.51}) do
                        mk(m, "ball", Vector3.new(0.07, 0.07, 0.07), CFrame.new(sx, sy, 0.26), Color3.fromRGB(150, 150, 160), METAL)
                    end
                end
                for k = -2, 2 do -- решётка и провод
                    mk(m, "block", Vector3.new(0.04, 0.16, 0.02), CFrame.new(k * 0.09, 0.14, 0.28), Color3.fromRGB(24, 24, 22))
                end
                mk(m, "block", Vector3.new(0.05, 0.05, 0.4), CFrame.new(0.52, 0.2, 0), Color3.fromRGB(130, 30, 24))
            elseif name == "Burner Phone" then
                for k = 0, 2 do
                    mk(m, "block", Vector3.new(0.3 - k * 0.06, 0.035, 0.01), CFrame.new(-0.02, 0.92 - k * 0.1, 0.1), Color3.fromRGB(10, 70, 30))
                end
                mk(m, "ball", Vector3.new(0.08, 0.08, 0.08), CFrame.new(0.2, 1.4, 0), Color3.fromRGB(255, 60, 60), NEON)
            elseif name == "Expired Medicine" then
                local INK = Color3.fromRGB(46, 38, 30)
                for k, w in ipairs({0.34, 0.26, 0.3, 0.18}) do -- строчки на этикетке
                    mk(m, "block", Vector3.new(w, 0.035, 0.02), CFrame.new(0, 0.6 - k * 0.085, 0.34), INK)
                end
                mk(m, "block", Vector3.new(0.4, 0.1, 0.02), CFrame.new(0, 0.18, 0.34), Color3.fromRGB(140, 36, 28)) -- красный штамп
                for k = 0, 7 do -- рёбра на крышке
                    local a = k * math.pi / 4
                    mk(m, "block", Vector3.new(0.04, 0.2, 0.04), CFrame.new(math.cos(a) * 0.29, 1.1, math.sin(a) * 0.29), Color3.fromRGB(196, 194, 186)).Name = "Cap"
                end
            elseif name == "Adrenaline" then
                for k = 0, 3 do
                    mk(m, "block", Vector3.new(0.02, 0.04, 0.2), CFrame.new(-0.2 + k * 0.15, 0.445, 0), Color3.fromRGB(30, 30, 35))
                end
                mk(m, "cyl", Vector3.new(0.3, 0.14, 0.14), CFrame.new(0.4, 0.27, 0), Color3.fromRGB(230, 60, 60), METAL)
            end
        end

        function E.build()
            local DK = Color3.fromRGB(14, 13, 15)
            -- 1. ВИСЯЧАЯ ЛАМПА над столом: качается, мигает, вокруг неё кружат мотыльки
            local function lp(kind, size, rel, color, mat, tr)
                local p = mk(WorldModel, kind, size, rel, color, mat, tr)
                table.insert(E.lampParts, {p = p, rel = p.CFrame})
                return p
            end
            lp("block", Vector3.new(0.05, 3.4, 0.05), CFrame.new(0, -1.7, 0), DK, Enum.Material.Metal)
            lp("cylY", Vector3.new(0.45, 0.25, 0.45), CFrame.new(0, -3.45, 0), DK, Enum.Material.Metal)
            lp("cylY", Vector3.new(1.5, 0.12, 1.5), CFrame.new(0, -3.75, 0), Color3.fromRGB(32, 26, 24), Enum.Material.Metal)
            local bulb = lp("ball", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, -3.95, 0), Color3.fromRGB(255, 205, 150), Enum.Material.Neon, 0.05)
            local glow = lp("ball", Vector3.new(1.7, 1.7, 1.7), CFrame.new(0, -3.95, 0), Color3.fromRGB(255, 170, 110), Enum.Material.Neon, 0.94)
            local beam = lp("block", Vector3.new(1.5, 7.2, 1.5), CFrame.new(0, -7.6, 0), Color3.fromRGB(255, 170, 120), Enum.Material.Neon, 0.978)
            table.insert(FX.lamps, {p = bulb, base = 0.05})
            table.insert(FX.lamps, {p = glow, base = 0.94})
            table.insert(FX.lamps, {p = beam, base = 0.978})

            -- 2. СВЕЧА на краю стола (колышется пламя, летят искры)
            local cx, cz = 3.0, 1.5
            E.candlePos = Vector3.new(cx, 0, cz)
            mk(WorldModel, "cylY", Vector3.new(0.55, 0.06, 0.55), CFrame.new(cx, 0.03, cz), Color3.fromRGB(60, 50, 40), Enum.Material.Metal)
            mk(WorldModel, "cylY", Vector3.new(0.26, 0.6, 0.26), CFrame.new(cx, 0.36, cz), Color3.fromRGB(226, 214, 180))
            mk(WorldModel, "cylY", Vector3.new(0.3, 0.06, 0.3), CFrame.new(cx, 0.66, cz), Color3.fromRGB(236, 226, 196))
            mk(WorldModel, "block", Vector3.new(0.02, 0.12, 0.02), CFrame.new(cx, 0.72, cz), Color3.fromRGB(20, 16, 14))
            E.flame = mk(WorldModel, "ball", Vector3.new(0.15, 0.26, 0.15), CFrame.new(cx, 0.86, cz), Color3.fromRGB(255, 170, 60), Enum.Material.Neon, 0.1)
            E.flameGlow = mk(WorldModel, "ball", Vector3.new(0.9, 0.9, 0.9), CFrame.new(cx, 0.86, cz), Color3.fromRGB(255, 140, 50), Enum.Material.Neon, 0.9)

            -- 3. ПЕПЕЛЬНИЦА с тлеющей сигаретой и дымом
            local ax, az = -3.0, 1.5
            E.ashPos = Vector3.new(ax + 0.17, 0.2, az + 0.09)
            mk(WorldModel, "cylY", Vector3.new(0.75, 0.1, 0.75), CFrame.new(ax, 0.05, az), Color3.fromRGB(70, 70, 78), Enum.Material.Metal)
            mk(WorldModel, "cylY", Vector3.new(0.6, 0.04, 0.6), CFrame.new(ax, 0.1, az), Color3.fromRGB(20, 20, 24), Enum.Material.Metal)
            mk(WorldModel, "block", Vector3.new(0.4, 0.05, 0.05), CFrame.new(ax, 0.14, az) * CFrame.Angles(0, 0.5, 0), Color3.fromRGB(235, 232, 222))
            E.ember = mk(WorldModel, "ball", Vector3.new(0.07, 0.07, 0.07), CFrame.new(ax + 0.17, 0.15, az - 0.09), Color3.fromRGB(255, 110, 30), Enum.Material.Neon, 0.1)
            E.ashPos = Vector3.new(ax + 0.17, 0.2, az - 0.09)

            -- 4. ТУМАН: три медленно дрейфующих слоя за Дилером и над дальним краем стола
            for i, d in ipairs({{-7.6, 2.5, 3.0, 0.9}, {-7.0, 1.0, 1.6, 0.93}, {-9.0, 4.0, 4.0, 0.93}}) do
                local p = mk(WorldModel, "block", Vector3.new(8, d[3], 0.05), CFrame.new(0, d[2], d[1]), Color3.fromRGB(80, 66, 68), Enum.Material.SmoothPlastic, d[4])
                table.insert(E.fog, {p = p, z = d[1], y = d[2], ph = i * 1.7})
            end

            -- 6. КРАСНАЯ ПУЛЬСАЦИЯ ПО КРАЯМ, когда у тебя остался 1 HP (+ стук сердца)
            E.low = Instance.new("Frame", Viewport)
            E.low.Size = UDim2.new(1, 0, 1, 0)
            E.low.BackgroundTransparency = 1
            E.low.ZIndex = 3
            E.low.Visible = false
            E.lowStrips = {}
            for _, d in ipairs({
                {UDim2.new(0, 0, 0, 0), UDim2.new(0, 120, 1, 0), 0}, {UDim2.new(1, -120, 0, 0), UDim2.new(0, 120, 1, 0), 180},
                {UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 60), 90}, {UDim2.new(0, 0, 1, -60), UDim2.new(1, 0, 0, 60), -90}
            }) do
                local f = Instance.new("Frame", E.low)
                f.Position, f.Size = d[1], d[2]
                f.BackgroundColor3 = Color3.fromRGB(190, 0, 0)
                f.BorderSizePixel = 0
                f.ZIndex = 3
                local g = Instance.new("UIGradient", f)
                g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
                g.Rotation = d[3]
                table.insert(E.lowStrips, f)
            end

            -- 7. СЧЁТЧИК ПАТРОНОВ в обойме (сколько осталось, тип скрыт)
            E.hud = Instance.new("TextLabel", Viewport)
            E.hud.Position = UDim2.new(0, 12, 0, 8)
            E.hud.Size = UDim2.new(0, 220, 0, 18)
            E.hud.BackgroundTransparency = 1
            E.hud.Font = Enum.Font.Code
            E.hud.TextSize = 13
            E.hud.TextColor3 = Color3.fromRGB(205, 190, 165)
            E.hud.TextStrokeTransparency = 0.4
            E.hud.TextXAlignment = Enum.TextXAlignment.Left
            E.hud.ZIndex = 6
            E.hud.Visible = false
        end

        -- ПОКАДРОВОЕ ОБНОВЛЕНИЕ (до расстановки предметов)
        function E.tick(dt, t)
            E.fov = E.fov * math.max(0, 1 - dt * 7)
            E.roll = E.roll * math.max(0, 1 - dt * 5)
            E.swayK = E.swayK * math.max(0, 1 - dt * 0.8)
            Camera.FieldOfView = CAM_FOV - E.fov
            if math.abs(E.roll) > 0.0005 then
                Camera.CFrame = Camera.CFrame * CFrame.Angles(0, 0, E.roll)
            end
            if not Viewport.Visible then return end

            -- лампа и мотыльки
            local sw = math.sin(t * 0.7) * 0.06 + math.sin(t * 1.9 + 1) * 0.02 + E.swayK * math.sin(t * 4)
            local pivot = CFrame.new(0, 11.2, -3) * CFrame.Angles(sw, 0, math.sin(t * 0.55) * 0.04)
            for _, e in ipairs(E.lampParts) do e.p.CFrame = pivot * e.rel end
                        -- туман
            for _, f in ipairs(E.fog) do
                f.p.CFrame = CFrame.new(math.sin(t * 0.15 + f.ph) * 1.6, f.y + math.sin(t * 0.2 + f.ph) * 0.15, f.z)
            end

            -- свеча
            local n1 = math.noise(t * 9, 3.3)
            local n2 = math.noise(t * 7, 8.1)
            local fp = E.candlePos + Vector3.new(n1 * 0.02, 0.86 + n2 * 0.03, 0)
            E.flame.Size = Vector3.new(0.15 + n1 * 0.05, 0.26 + n2 * 0.1, 0.15 + n1 * 0.05)
            E.flame.Position = fp
            E.flameGlow.Position = fp
            E.flameGlow.Transparency = math.clamp(0.9 + math.noise(t * 6, 1.7) * 0.08, 0.8, 0.97)
            -- дымок из пепельницы
            E.ember.Transparency = 0.1 + 0.25 * (0.5 + 0.5 * math.sin(t * 2.2))
            E.smokeT -= dt
            if E.smokeT <= 0 then
                E.smokeT = 0.45 + math.random() * 0.3
                emit(E.ashPos, 1, Color3.fromRGB(105, 105, 112), 0.4, 2.2, 0.14, 1.0)
            end

            -- пульс и сердцебиение на последнем HP
            local lowOn = (GameState.PlayerHP == 1) and ((GameState.MaxHP or 4) > 1) and (not GameState.GameOver) and (not GameState.Victory)
            E.low.Visible = lowOn
            if lowOn then
                local ph = (t * 1.05) % 1
                local s = math.exp(-(((ph - 0.04) / 0.06) ^ 2)) + 0.6 * math.exp(-(((ph - 0.24) / 0.06) ^ 2))
                local tr = 1 - math.clamp(s, 0, 1) * 0.7
                for _, f in ipairs(E.lowStrips) do f.BackgroundTransparency = tr end
                if ph < E.lastPh then
                    E.sfx(SOUNDS.Rack, 0.3, 0.35)
                    E.fov = E.fov + 1.2
                end
                E.lastPh = ph
            end

            -- счётчик патронов
            local n = #GameState.Shells
            local showHud = (n > 0) and (not GameState.Intro) and (not GameState.GameOver)
            E.hud.Visible = showHud
            if showHud and E.hudN ~= n then
                E.hudN = n
                E.hud.Text = "ПАТРОНЫ: " .. string.rep("● ", n)
            end
        end

        -- ПОКАДРОВОЕ ОБНОВЛЕНИЕ (после расстановки предметов): мерцание неона, покачивание под курсором, пыль при падении
        function E.late(dt, t)
            for _, side in ipairs({"Player", "Dealer"}) do
                for _, it in ipairs(displayed[side]) do
                    if (not it.dying) and it.model and it.model.Parent then
                        if it.thud and not it.puffed then
                            it.puffed = true
                            emit(it.pos + Vector3.new(0, 0.1, 0), 5, Color3.fromRGB(150, 140, 130), 1.6, 0.5, 0.12, -1)
                        end
                        local ph = it.phase or 0
                        for _, e in ipairs(it.parts) do
                            if e.p.Material == Enum.Material.Neon then
                                e.p.Transparency = e.t + (1 - e.t) * 0.18 * (0.5 + 0.5 * math.sin(t * 3 + ph))
                            end
                        end
                        if it.hover then
                            it.model:PivotTo(it.model:GetPivot() * CFrame.Angles(0, math.sin(t * 6) * 0.08, 0))
                        end
                    end
                end
            end
        end

        local okB, errB = pcall(E.build)
        if not okB then warn("[BloxRoulette v9] build: " .. tostring(errB)) end
    end
-- КОНЕЦ ЧАСТИ 6
    -- ГЛАВНЫЙ ЦИКЛ АНИМАЦИИ (Дилер дышит, предметы парят, заряды пульсируют, частицы летят)
    local clock0 = os.clock()
    local function step(dt)
        local t = os.clock() - clock0

        camCur = camCur:Lerp(camTarget, math.min(1, dt * 5))
        local ox, oy, roll = 0, 0, 0
        if shake > 0 then
            local s = shake * 0.18
            ox, oy = (math.random() - 0.5) * s, (math.random() - 0.5) * s
            shake = math.max(0, shake - dt * 2.2)
        end
        -- лёгкая тряска экрана от музыки: берём громкость трека, ловим удар (резкий скачок над средним уровнем)
        if MusicSound and MusicSound.IsPlaying and MUSIC_SHAKE > 0 then
            local loud = MusicSound.PlaybackLoudness
            musicEnv += (loud - musicEnv) * math.min(1, dt * 10)
            local kick = math.clamp((loud - musicEnv * 0.9) / 260, 0, 1)
            musicKick = math.max(musicKick * math.max(0, 1 - dt * 9), kick)
            local amp = (math.clamp(musicEnv / 600, 0, 1) * 0.35 + musicKick * 0.65) * MUSIC_SHAKE
            local ms = amp * 0.12
            ox += (math.random() - 0.5) * ms
            oy += (math.random() - 0.5) * ms * 1.3
            roll = (math.random() - 0.5) * amp * 0.006
        end
        Camera.CFrame = camCur * CFrame.new(ox, oy, 0) * CFrame.Angles(math.sin(t * 0.5) * 0.004, math.sin(t * 0.37) * 0.006, roll)
        if FX.fx then FX.fx("tick", dt, t) end

        local bob = math.sin(t * 1.6) * 0.05
        for i, L in ipairs(FX.lamps) do
            local blink = (math.noise(t * 1.4, i * 7.3) > 0.32) and (0.5 + 0.5 * math.sin(t * 60 + i)) or 1
            L.p.Transparency = L.base + (1 - L.base) * (1 - blink)
        end
        local twitch = (math.noise(t * 7, 1.3) > 0.28) and math.noise(t * 35, 2.1) * 0.22 or 0
        local F = FX.Dealer
        F.lean += (F.leanT - F.lean) * math.min(1, dt * (F.fast and 14 or 4)) -- во время предметов Дилер двигается резко
        local hk = math.min(1, dt * 14)
        F.tilt += (F.tiltT - F.tilt) * hk
        F.nod += (F.nodT - F.nod) * hk
        F.yaw += (F.yawT - F.yaw) * hk
        F.kick = math.max(0, F.kick - dt * 1.4)
        F.yoff += (0 - F.yoff) * math.min(1, dt * 1.6) -- Дилер выходит из темноты при старте
        if not F.flying then -- во время отлёта положением управляет FX.dealerFly
            F.away += (F.awayT - F.away) * math.min(1, dt * (F.awayT > F.away and 10 or 1.1))
        end
        local lean = F.lean - F.kick * 0.55 - F.away
        bob = bob + F.yoff
        DealerBody:PivotTo(CFrame.new(0, bob, DEALER_Z + lean))
        local a = math.min(1, dt * 8)
        for k, v in pairs(moodTarget) do moodCur[k] = moodCur[k] + (v - moodCur[k]) * a end
        blinkT = math.max(0, blinkT - dt)
        nextBlink -= dt
        if nextBlink <= 0 then
            blinkT = 0.12
            nextBlink = 2 + math.random() * 3
        end
        local gunHeld = (GunCtl.blend.Player > 0.1 or GunCtl.blend.Dealer > 0.1)
        local lookT = gunHeld and math.clamp(GunRoot.Position.X * 0.09, -0.3, 0.3) or 0
        F.look += (lookT - F.look) * math.min(1, dt * 5)
        local headCF = CFrame.new(0, 3.55 + bob * 1.4 - F.lean * 0.3, DEALER_Z + 0.05 + lean)
            * CFrame.Angles(moodCur.pitch + math.sin(t * 0.6) * 0.03 + F.lean * 0.22 - F.kick * 0.35 + F.nod,
                math.sin(t * 0.5) * 0.12 + twitch + F.look + F.yaw,
                math.sin(t * 0.8) * 0.03 + twitch * 0.5 + F.kick * 0.12 * math.sin(t * 40) + F.laugh * 0.04 * math.sin(t * 15) + F.tilt)
        DealerHead:PivotTo(headCF)
        updateDealerFace(headCF)
        GunCtl.updateArms(bob, lean, t)

        FX.updateCuffs()
        FX.dealerShade(F.away)

        local hoveredIt, hx, hy = nil, 0, 0
        for _, side in ipairs({"Player", "Dealer"}) do
            for _, it in ipairs(displayed[side]) do
                -- по столу предметы скользят, по высоте падают под гравитацией и отскакивают (никакого парения)
                local k = math.min(1, dt * 7)
                local px = it.pos.X + (it.target.X - it.pos.X) * k
                local pz = it.pos.Z + (it.target.Z - it.pos.Z) * k
                it.vy -= 28 * dt
                local py = it.pos.Y + it.vy * dt
                if py <= it.target.Y then
                    py = it.target.Y
                    if it.vy < -3 then
                        if not it.thud then
                            it.thud = true
                            playSFX(SOUNDS.Rack, 0.55)
                        end
                        it.vy = -it.vy * 0.28
                    else
                        it.vy = 0
                    end
                end
                it.pos = Vector3.new(px, py, pz)
                local steal = GameState.StealingMode and side == "Dealer" -- при краже предметы Дилера слегка приподнимаются
                local liftT = (it.hover and (steal and 0.4 or 0.1)) or (steal and (0.14 + 0.07 * math.sin(t * 5 + it.phase))) or 0
                it.lift += (liftT - it.lift) * math.min(1, dt * 12)
                it.model:PivotTo(CFrame.new(it.pos + Vector3.new(0, it.lift, 0)) * CFrame.Angles(0, it.yaw, 0))
                local sx, sy, ppu = project(it.pos + Vector3.new(0, 0.5 + it.lift, 0))
                it.btn.Position = UDim2.fromScale(sx, sy)
                local sz = math.clamp(ppu * 1.5, 30, 54)
                it.btn.Size = UDim2.fromOffset(sz, sz)
                if it.hover then hoveredIt, hx, hy = it, sx, sy end
            end
        end
        -- чистка: использованный предмет (например телефон Дилера) не должен оставаться на столе
        for i = #FX.items, 1, -1 do
            local o = FX.items[i]
            local orphan = (not o.dying) and (not indexOf(displayed[o.side], o))
            if orphan or (o.dying and os.clock() - o.dyingAt > 16) then
                if o.btn then o.btn:Destroy() end
                if o.model then o.model:Destroy() end
                table.remove(FX.items, i)
            end
        end
        -- кнопка-дробовик следует за самим дробовиком (на столе и в руках)
        local gx, gy, gppu = project(GunRoot.Position + Vector3.new(0, 0.15, 0))
        GunBtn.Position = UDim2.fromScale(gx, gy)
        GunBtn.Size = UDim2.fromOffset(math.clamp(gppu * 4.8, 70, 130), math.clamp(gppu * 1.4, 22, 34))
        if GameState.Aiming then
            local dx, dy = project(Vector3.new(0, 0.02, -3.3))
            ChooseDealerBtn.Position = UDim2.fromScale(dx, dy)
            local sx2, sy2 = project(Vector3.new(0, 0.02, 4.5))
            ChooseSelfBtn.Position = UDim2.fromScale(sx2, sy2)
        end
        local canGun = GunCtl.clickable()
        local gunActive = (canGun or GameState.Aiming) and not GameState.GameOver
        GunBtn.Visible = gunActive
        GunHalo.Transparency = canGun and (0.6 + 0.25 * math.sin(t * 5)) or 1

        if hoveredIt then
            local info = ITEMS_DB[hoveredIt.name]
            HoverTag.Text = info.Icon .. " " .. info.Short
            HoverTag.Position = UDim2.new(hx, 0, hy, -30)
            HoverTag.Visible = true
        elseif GunCtl.hover and gunActive then
            HoverTag.Text = GameState.Aiming and "↩ Положить дробовик" or "🔫 Взять дробовик"
            HoverTag.Position = UDim2.new(gx, 0, gy, -22)
            HoverTag.Visible = true
        else
            HoverTag.Visible = false
        end

        for side, bank in pairs(hpBanks) do
            local active = (GameState.Turn == side) and not GameState.GameOver
            local stripT = active and (0.05 + 0.2 * (0.5 + 0.5 * math.sin(t * 4))) or 0.8
            for _, s in ipairs(bank.strips) do s.Transparency = stripT end
            for _, c in ipairs(bank.cells) do
                if c.alive then c.core.Transparency = 0.04 + 0.1 * (0.5 + 0.5 * math.sin(t * 3 + c.idx)) end
            end
        end

        for side, pn in pairs(FX.Panel) do
            local active = (GameState.Turn == side) and not GameState.GameOver
            for i, b in ipairs(pn.bolts) do
                if b.alive and not FX.roundMode then
                    local tr = active and (0.02 + 0.2 * (0.5 + 0.5 * math.sin(t * 5 + i))) or 0.03
                    for _, p in ipairs(b.parts) do p.Transparency = tr end
                end
            end
        end
        for i = #particles, 1, -1 do
            local q = particles[i]
            q.life -= dt
            if q.life <= 0 then
                q.p:Destroy()
                table.remove(particles, i)
            else
                q.v += Vector3.new(0, q.g or -9, 0) * dt
                q.p.Position = q.p.Position + q.v * dt
                q.p.Transparency = 1 - math.clamp(q.life / q.max, 0, 1)
            end
        end
        if FX.fx then FX.fx("late", dt, t) end
    end

    local stepWarned = false
    local stepConn = RunService.Heartbeat:Connect(function(dt)
        local ok, err = pcall(step, dt)
        if not ok and not stepWarned then
            stepWarned = true
            warn("[BloxRoulette] " .. tostring(err))
        end
    end)
    MainFrame.Destroying:Connect(function()
        stepConn:Disconnect()
        if MusicSound then MusicSound:Destroy() end
    end)
-- КОНЕЦ ЧАСТИ 3Б
-- НАЧАЛО ЧАСТИ 3В
    -- ПОСЛЕДНИЙ ШАНС / СДАТЬСЯ
    local lastChanceToken = 0
    local function hideLastChanceUI()
        lastChanceToken += 1
        LastChanceBtn.Visible = false
        SurrenderBtn.Visible = false
        LastTimer.Visible = false
    end

    local function dieForReal()
        hideLastChanceUI()
        GameState.LastChance = false
        Progress.streak = 0
        updateEconomyUI()
        killRobloxCharacter()
        task.delay(1.6, function()
            if not ScreenGui.Parent or not GameState.GameOver then return end
            if GameState.ShowMenu then
                GameState.ShowMenu() -- проигрыш / «Сдаться» -> кидает в лобби (главное меню)
            else
                RestartBtn.Text = "ИГРАТЬ СНОВА"
                RestartBtn.Visible = true
            end
        end)
    end

    local function showLastChance()
        hideLastChanceUI()
        local my = lastChanceToken
        GameState.GameOver = true
        GameState.LastChance = true
        BlackOverlay.Visible = true
        BlackOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
        BlackOverlay.BackgroundTransparency = 0
        RestartBtn.Visible = false
        ChooseDealerBtn.Visible = false
        ChooseSelfBtn.Visible = false
        LastChanceBtn.Visible = true
        SurrenderBtn.Visible = true
        if HARDCORE_DEATH and LAST_CHANCE_TIMEOUT > 0 then
            task.spawn(function()
                for s = LAST_CHANCE_TIMEOUT, 1, -1 do
                    if my ~= lastChanceToken then return end
                    LastTimer.Text = tostring(s)
                    LastTimer.Visible = true
                    task.wait(1)
                end
                if my ~= lastChanceToken then return end
                dieForReal()
            end)
        end
    end

    -- НАГРАДЫ: монеты за раунд и за игру, бонус за серию побед
    local function awardWin(isFinal, roundWon)
        local amount
        if isFinal then
            Progress.streak += 1
            Progress.best = math.max(Progress.best, Progress.streak)
            amount = math.floor(WIN_REWARD * (1 + STREAK_BONUS * (Progress.streak - 1)))
        else
            amount = math.floor(ROUND_REWARD * roundWon * (1 + STREAK_BONUS * Progress.streak))
        end
        Progress.coins += amount
        GameState.addStat("coins", amount)
        GameState.addStat("rounds")
        updateEconomyUI()
        return amount
    end

    -- ПОБЕДА: Дилер исчезает в темноте, к тебе на механических руках подъезжает чемодан с деньгами
    local victoryParts = {}
    local function cleanupVictory()
        for _, p in ipairs(victoryParts) do p:Destroy() end
        table.clear(victoryParts)
    end
    local function addV(p) table.insert(victoryParts, p) return p end

    local function playVictoryCase()
        task.spawn(function()
            cleanupVictory()
            FX.dealerFly(false)
            camTarget = BASE_CAM
            local DK = Color3.fromRGB(28, 22, 20)
            local GOLD = Color3.fromRGB(215, 170, 60)
            local METAL = Color3.fromRGB(70, 72, 80)
            local RED = Color3.fromRGB(150, 40, 35)
            local base = addV(mk(WorldModel, "block", Vector3.new(3.2, 0.9, 2.0), CFrame.new(), DK, Enum.Material.Fabric))
            local lid = addV(mk(WorldModel, "block", Vector3.new(3.2, 0.12, 2.0), CFrame.new(), DK, Enum.Material.Fabric))
            local clasp = addV(mk(WorldModel, "block", Vector3.new(0.5, 0.3, 0.1), CFrame.new(), GOLD, Enum.Material.Metal))
            local bills = {}
            local rng = Random.new(11)
            for i = 1, 36 do
                local isGold = (i % 5 == 0)
                local col = isGold and GOLD or Color3.fromRGB(70 + rng:NextInteger(0, 30), 150 + rng:NextInteger(0, 40), 80)
                local sz = isGold and Vector3.new(0.4, 0.14, 0.4) or Vector3.new(0.55, 0.12, 1.0)
                local p = addV(mk(WorldModel, "block", sz, CFrame.new(), col, isGold and Enum.Material.Metal or Enum.Material.SmoothPlastic, 1))
                bills[i] = {p = p, ox = rng:NextNumber(-1.25, 1.25), oz = rng:NextNumber(-0.7, 0.7), oy = 0.94 + (i % 4) * 0.09, rot = rng:NextNumber(-0.6, 0.6)}
            end
            local arms = {}
            for _, sg in ipairs({-1, 1}) do
                arms[#arms + 1] = {
                    sg = sg,
                    up = addV(mk(WorldModel, "block", Vector3.new(0.24, 0.24, 1), CFrame.new(), METAL, Enum.Material.Metal)),
                    fo = addV(mk(WorldModel, "block", Vector3.new(0.2, 0.2, 1), CFrame.new(), Color3.fromRGB(95, 96, 104), Enum.Material.Metal)),
                    j1 = addV(mk(WorldModel, "ball", Vector3.new(0.42, 0.42, 0.42), CFrame.new(), RED, Enum.Material.Metal)),
                    j2 = addV(mk(WorldModel, "ball", Vector3.new(0.34, 0.34, 0.34), CFrame.new(), RED, Enum.Material.Metal)),
                }
            end
            local function seg(p, a, b)
                local len = math.max(0.05, (b - a).Magnitude)
                p.Size = Vector3.new(p.Size.X, p.Size.Y, len)
                p.CFrame = CFrame.lookAt((a + b) / 2, b)
            end
            local function place(cz, ang)
                base.CFrame = CFrame.new(0, 0.45, cz)
                lid.CFrame = CFrame.new(0, 0.9, cz - 1.0) * CFrame.Angles(-ang, 0, 0) * CFrame.new(0, 0.06, 1.0)
                clasp.CFrame = CFrame.new(0, 0.8, cz + 1.02)
                for _, b in ipairs(bills) do
                    b.p.CFrame = CFrame.new(b.ox, b.oy, cz + b.oz) * CFrame.Angles(0, b.rot, 0)
                    b.p.Transparency = (ang > 0.2) and 0 or 1
                end
                for _, a in ipairs(arms) do
                    local sh = Vector3.new(a.sg * 2.9, 2.2, -7.6)
                    local hand = Vector3.new(a.sg * 1.75, 0.6, cz)
                    local el = (sh + hand) / 2 + Vector3.new(a.sg * 0.5, 1.5, 0)
                    seg(a.up, sh, el)
                    seg(a.fo, el, hand)
                    a.j1.Position = el
                    a.j2.Position = hand
                end
            end
            place(-7, 0)
            task.wait(1.1) -- Дилер улетает в темноту
            playSFX(SOUNDS.Rack, 0.5)
            runAnim(2.8, function(a) place(-7 + 9.3 * ease(a), 0) end)
            task.wait(0.4)
            runAnim(0.7, function(a) place(2.3, ease(a) * 1.75) end)
            playSFX(SOUNDS.Win, 1.0)
            emit(Vector3.new(0, 1.8, 2.3), 40, Color3.fromRGB(255, 215, 90), 6, 1.8, 0.14, -4)
            task.wait(1.0)
            if GameState.Victory and GameState.Ending then GameState.Ending.offerTake() end
        end)
    end

    -- РАУНДЫ показываются на экране справа (FX.showRound)
    local function showRoundPanel(round) FX.showRound(round) end

    -- ===== КОНЦОВКА v8.7: ЗАБРАТЬ ДЕНЬГИ -> ночная машина, на сиденье дробовик и чемодан, итоговая статистика =====
    -- Всё внутри одной функции и в таблице GameState (лимит 200 локальных переменных не трогаем)
    GameState.Ending = (function()
        Progress.total = Progress.total or {}
        local run = {}
        GameState.RunStats = run
        GameState.resetRun = function() run = {}; GameState.RunStats = run end
        GameState.addStat = function(key, n)
            n = n or 1
            run[key] = (run[key] or 0) + n
            Progress.total[key] = (Progress.total[key] or 0) + n
        end
        GameState.recordShot = function(shooter, target, isLive)
            if shooter == "Player" then
                if target == "Dealer" then
                    GameState.addStat(isLive and "liveDealer" or "blankDealer")
                else
                    GameState.addStat(isLive and "liveSelf" or "blankSelf")
                end
            elseif target == "Player" then
                GameState.addStat(isLive and "liveTaken" or "blankTaken")
            end
        end

        local ROWS = {
            {"screw", "Патронов выковыряно"},
            {"liveDealer", "Боевых в Дилера"},
            {"blankDealer", "Холостых в Дилера"},
            {"liveSelf", "Боевых в себя"},
            {"blankSelf", "Холостых в себя"},
            {"liveTaken", "Боевых от Дилера"},
            {"blankTaken", "Холостых от Дилера"},
            {"items", "Предметов в деле"},
            {"rounds", "Раундов выиграно"},
            {"coins", "Монет заработано"},
            {"deaths", "Раз умирал"},
        }

        -- ---------- маленькие помощники ----------
        local function mkF(parent, x, y, w, h, col, tr, z)
            local f = Instance.new("Frame")
            f.BorderSizePixel = 0
            f.Position = UDim2.fromScale(x, y)
            f.Size = UDim2.fromScale(w, h)
            f.BackgroundColor3 = col
            f.BackgroundTransparency = tr or 0
            f.ZIndex = z or 1
            f.Parent = parent
            return f
        end
        local function mkP(parent, x, y, w, h, col, tr, z)
            local f = Instance.new("Frame")
            f.BorderSizePixel = 0
            f.Position = UDim2.new(0, x, 0, y)
            f.Size = UDim2.new(0, w, 0, h)
            f.BackgroundColor3 = col
            f.BackgroundTransparency = tr or 0
            f.ZIndex = z or 1
            f.Parent = parent
            return f
        end
        local function rnd(f, r)
            local c = Instance.new("UICorner")
            c.CornerRadius = r
            c.Parent = f
            return f
        end
        local function grad(f, rot, c0, c1, t0, t1)
            local g = Instance.new("UIGradient")
            g.Rotation = rot
            g.Color = ColorSequence.new(c0, c1)
            g.Transparency = NumberSequence.new(t0 or 0, t1 or 0)
            g.Parent = f
            return g
        end
        local function stroke(f, col, th, tr)
            local s = Instance.new("UIStroke")
            s.Color = col
            s.Thickness = th
            s.Transparency = tr or 0
            s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            s.Parent = f
            return s
        end
        local function mkT(parent, text, x, y, w, h, size, col, align, z)
            local l = Instance.new("TextLabel")
            l.BackgroundTransparency = 1
            l.Position = UDim2.new(0, x, 0, y)
            l.Size = UDim2.new(0, w, 0, h)
            l.Text = text
            l.Font = Enum.Font.Code
            l.TextSize = size
            l.TextColor3 = col
            l.TextXAlignment = align or Enum.TextXAlignment.Left
            l.ZIndex = z or 6
            l.Parent = parent
            return l
        end
        local GOLD = Color3.fromRGB(255, 225, 90)
        local BROWN = Color3.fromRGB(106, 58, 42)
        local BLACK = Color3.new(0, 0, 0)

        -- ---------- корень сцены ----------
        local Root = Instance.new("Frame")
        Root.Name = "CarEnding"
        Root.Size = UDim2.new(1, 0, 1, 0)
        Root.BackgroundColor3 = Color3.fromRGB(4, 5, 9)
        Root.BorderSizePixel = 0
        Root.ClipsDescendants = true
        Root.Active = true
        Root.Visible = false
        Root.ZIndex = 50
        Root.Parent = Viewport
        rnd(Root, UDim.new(0, 6))

        local World = Instance.new("Frame")
        World.AnchorPoint = Vector2.new(0.5, 0.5)
        World.Position = UDim2.fromScale(0.5, 0.5)
        World.Size = UDim2.fromScale(1.04, 1.04)
        World.BackgroundTransparency = 1
        World.ZIndex = 1
        World.Parent = Root

        -- небо за окном
        local sky = mkF(World, 0, 0, 1, 0.68, Color3.fromRGB(10, 14, 30), 0, 1)
        grad(sky, 90, Color3.fromRGB(8, 11, 26), Color3.fromRGB(86, 44, 56))

        -- силуэты города (две линии, едут медленно)
        local blds = {}
        local function addCity(count, col, hMin, hMax, speed, z, lit)
            for i = 1, count do
                local w = 0.06 + math.random() * 0.07
                local h = hMin + math.random() * (hMax - hMin)
                local x = (i - 1) / count * 1.25 + math.random() * 0.03
                local f = mkF(World, x, 0.68 - h, w, h, col, 0, z)
                if lit then
                    for _ = 1, 4 do
                        local wf = mkF(f, 0.15 + math.random() * 0.6, 0.08 + math.random() * 0.8, 0.14, 0.04, Color3.fromRGB(255, 205, 120), 0.2 + math.random() * 0.4, z)
                    end
                end
                table.insert(blds, {f = f, x = x, w = w, y = 0.68 - h, sp = speed})
            end
        end
        addCity(10, Color3.fromRGB(26, 20, 34), 0.12, 0.34, 0.025, 2, false)
        addCity(8, Color3.fromRGB(9, 8, 14), 0.08, 0.26, 0.07, 3, true)

        -- боке от фонарей и фар
        local bokeh = {}
        local bokehCols = {
            Color3.fromRGB(255, 170, 80), Color3.fromRGB(255, 70, 60),
            Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 240, 220),
        }
        for i = 1, 18 do
            local px = 6 + math.random() * 20
            local w, h = px / 620, px / 296
            local f = mkF(World, math.random(), 0.1 + math.random() * 0.5, w, h, bokehCols[(i % #bokehCols) + 1], 0.55 + math.random() * 0.25, 4)
            rnd(f, UDim.new(1, 0))
            table.insert(bokeh, {f = f, x = math.random(), y = 0.1 + math.random() * 0.5, w = w, sp = 0.04 + math.random() * 0.2, ph = 1 + math.random() * 2})
        end

        -- дождь по стеклу
        local rain = {}
        for _ = 1, 34 do
            local f = mkF(World, math.random(), math.random() * 0.7, 0.0016, 0.09, Color3.fromRGB(170, 190, 220), 0.65, 4)
            f.Rotation = 12
            table.insert(rain, {f = f, x = math.random() * 1.1, y = math.random() * 0.7, vy = 1.1 + math.random() * 0.7})
        end

        -- потолок и дверь
        local roof = mkF(World, 0, 0, 1, 0.1, Color3.fromRGB(5, 5, 7), 0, 5)
        grad(roof, 90, Color3.fromRGB(5, 5, 7), Color3.fromRGB(5, 5, 7), 0, 1)
        local door = mkF(World, 0, 0.66, 1, 0.34, Color3.fromRGB(17, 14, 16), 0, 5)
        grad(door, 90, Color3.fromRGB(26, 21, 22), Color3.fromRGB(8, 7, 9))
        mkF(World, 0, 0.66, 1, 0.006, Color3.fromRGB(95, 95, 106), 0, 5)

        -- сиденье
        local headrest = mkF(World, 0.2, 0.17, 0.17, 0.22, Color3.fromRGB(36, 25, 21), 0, 6)
        rnd(headrest, UDim.new(0, 16))
        grad(headrest, 100, Color3.fromRGB(58, 40, 32), Color3.fromRGB(26, 18, 15))
        mkF(World, 0.275, 0.36, 0.02, 0.1, Color3.fromRGB(14, 14, 16), 0, 6)
        local back = mkF(World, 0.04, 0.3, 0.56, 0.46, Color3.fromRGB(40, 28, 23), 0, 7)
        rnd(back, UDim.new(0, 18))
        grad(back, 100, Color3.fromRGB(66, 46, 36), Color3.fromRGB(28, 19, 16))
        for _, sx in ipairs({0.25, 0.5, 0.75}) do
            mkF(back, sx, 0.1, 0.004, 0.8, Color3.fromRGB(18, 12, 10), 0.2, 7)
        end
        mkF(back, 0.04, 0.03, 0.92, 0.012, Color3.fromRGB(110, 80, 62), 0.55, 7)
        local cushion = mkF(World, -0.02, 0.68, 0.7, 0.4, Color3.fromRGB(48, 34, 27), 0, 8)
        rnd(cushion, UDim.new(0, 20))
        grad(cushion, 90, Color3.fromRGB(74, 52, 40), Color3.fromRGB(30, 21, 17))
        mkF(cushion, 0.04, 0.02, 0.92, 0.015, Color3.fromRGB(120, 88, 68), 0.5, 8)
        mkF(cushion, 0.0, 0.5, 1, 0.01, Color3.fromRGB(16, 11, 9), 0.4, 8)

        -- ЧЕМОДАН С ДЕНЬГАМИ
        mkF(World, 0.05, 0.86, 0.31, 0.04, BLACK, 0.55, 8)
        local case = Instance.new("Frame")
        case.BackgroundTransparency = 1
        case.Position = UDim2.fromScale(0.06, 0.655)
        case.Size = UDim2.fromScale(0.27, 0.22)
        case.Rotation = -4
        case.ZIndex = 9
        case.Parent = World
        local bills = mkF(case, 0.05, 0.05, 0.9, 0.12, Color3.fromRGB(86, 170, 96), 0, 9)
        rnd(bills, UDim.new(0, 3))
        local billsTop = mkF(case, 0.12, 0.02, 0.76, 0.06, Color3.fromRGB(120, 200, 120), 0, 9)
        rnd(billsTop, UDim.new(0, 3))
        local body = mkF(case, 0, 0.12, 1, 0.88, Color3.fromRGB(32, 27, 27), 0, 10)
        rnd(body, UDim.new(0, 8))
        stroke(body, Color3.fromRGB(70, 60, 54), 1)
        grad(body, 90, Color3.fromRGB(52, 44, 42), Color3.fromRGB(22, 18, 18))
        mkF(case, 0.02, 0.5, 0.96, 0.025, Color3.fromRGB(10, 8, 8), 0, 11)
        local handle = mkF(case, 0.38, -0.12, 0.24, 0.16, BLACK, 1, 9)
        rnd(handle, UDim.new(0, 6))
        stroke(handle, Color3.fromRGB(20, 18, 18), 3)
        for _, cx in ipairs({0.1, 0.78}) do
            local c = mkF(case, cx, 0.42, 0.11, 0.16, GOLD, 0, 12)
            rnd(c, UDim.new(0, 2))
            grad(c, 90, Color3.fromRGB(255, 235, 140), Color3.fromRGB(170, 125, 40))
        end
        local lock = mkF(case, 0.465, 0.4, 0.07, 0.2, GOLD, 0, 12)
        rnd(lock, UDim.new(0, 2))
        for _, cp in ipairs({{0.01, 0.14}, {0.94, 0.14}, {0.01, 0.9}, {0.94, 0.9}}) do
            local g = mkF(case, cp[1], cp[2], 0.05, 0.08, Color3.fromRGB(190, 145, 50), 0, 12)
            rnd(g, UDim.new(0, 2))
        end

        -- ДРОБОВИК (помповый) лежит на сиденье
        mkF(World, 0.14, 0.93, 0.36, 0.03, BLACK, 0.5, 8)
        local gun = Instance.new("Frame")
        gun.AnchorPoint = Vector2.new(0.5, 0.5)
        gun.BackgroundTransparency = 1
        gun.Position = UDim2.fromScale(0.36, 0.86)
        gun.Size = UDim2.new(0, 300, 0, 44)
        gun.Rotation = -8
        gun.ZIndex = 13
        gun.Parent = World
        local gunScale = Instance.new("UIScale")
        gunScale.Scale = 0.78
        gunScale.Parent = gun
        local WOOD = Color3.fromRGB(112, 70, 38)
        local STEEL = Color3.fromRGB(40, 42, 48)
        local stock = mkP(gun, 0, 8, 88, 24, WOOD, 0, 13)
        rnd(stock, UDim.new(0, 6))
        grad(stock, 90, Color3.fromRGB(150, 98, 54), Color3.fromRGB(78, 48, 26))
        local comb = mkP(gun, 30, 4, 60, 14, WOOD, 0, 13)
        rnd(comb, UDim.new(0, 5))
        local pad = mkP(gun, 0, 8, 10, 24, Color3.fromRGB(20, 20, 22), 0, 14)
        rnd(pad, UDim.new(0, 3))
        local recv = mkP(gun, 86, 8, 50, 20, Color3.fromRGB(44, 46, 54), 0, 14)
        rnd(recv, UDim.new(0, 3))
        mkP(gun, 100, 12, 22, 5, BLACK, 0, 15)
        local barrel = mkP(gun, 134, 9, 166, 7, STEEL, 0, 14)
        rnd(barrel, UDim.new(0, 2))
        grad(barrel, 90, Color3.fromRGB(86, 90, 100), Color3.fromRGB(24, 25, 30))
        mkP(gun, 136, 10, 158, 1, Color3.new(1, 1, 1), 0.7, 15)
        mkP(gun, 294, 8, 6, 9, Color3.fromRGB(20, 20, 22), 0, 15)
        mkP(gun, 290, 5, 3, 4, Color3.fromRGB(20, 20, 22), 0, 15)
        local tube = mkP(gun, 134, 18, 150, 5, Color3.fromRGB(30, 32, 38), 0, 14)
        rnd(tube, UDim.new(0, 2))
        local pump = mkP(gun, 160, 15, 60, 14, Color3.fromRGB(98, 60, 32), 0, 15)
        rnd(pump, UDim.new(0, 5))
        for _, rx in ipairs({168, 178, 188, 198}) do mkP(gun, rx, 17, 2, 10, Color3.fromRGB(40, 24, 12), 0, 16) end
        local guard = mkP(gun, 96, 26, 26, 9, BLACK, 1, 14)
        rnd(guard, UDim.new(0, 5))
        stroke(guard, Color3.fromRGB(30, 30, 34), 2)
        mkP(gun, 106, 27, 2, 6, Color3.fromRGB(20, 20, 22), 0, 15)

        -- тёплые пятна света и «проезжающий фонарь»
        local glow1 = mkF(World, 0.0, 0.5, 0.6, 1.1, Color3.fromRGB(255, 190, 110), 0.93, 17)
        rnd(glow1, UDim.new(1, 0))
        local glow2 = mkF(World, 0.1, 0.62, 0.36, 0.8, Color3.fromRGB(255, 190, 110), 0.9, 17)
        rnd(glow2, UDim.new(1, 0))
        local sweep = mkF(World, -0.3, 0, 0.26, 1, Color3.fromRGB(255, 200, 120), 0, 18)
        grad(sweep, 0, Color3.fromRGB(255, 200, 120), Color3.fromRGB(255, 200, 120), 1, 1).Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.84), NumberSequenceKeypoint.new(1, 1),
        })
        sweep.Visible = false

        -- виньетка
        local function vig(x, y, w, h, rot)
            local f = mkF(Root, x, y, w, h, BLACK, 0, 3)
            grad(f, rot, BLACK, BLACK, 0.15, 1)
            return f
        end
        vig(0, 0, 1, 0.25, 90)
        local vb = mkF(Root, 0, 0.75, 1, 0.25, BLACK, 0, 3)
        grad(vb, 90, BLACK, BLACK, 1, 0.15)
        vig(0, 0, 0.18, 1, 0)
        local vr = mkF(Root, 0.82, 0, 0.18, 1, BLACK, 0, 3)
        grad(vr, 0, BLACK, BLACK, 1, 0.15)

        -- заголовок
        local TitleL = mkT(Root, "ДЕНЬГИ ЗАБРАНЫ", 14, 8, 300, 22, 17, GOLD, nil, 6)
        TitleL.TextStrokeTransparency = 0.3
        local SubL = mkT(Root, "", 14, 30, 300, 16, 12, Color3.fromRGB(215, 215, 205), nil, 6)
        SubL.TextStrokeTransparency = 0.4

        -- ---------- панель статистики ----------
        local Panel = Instance.new("Frame")
        Panel.AnchorPoint = Vector2.new(1, 0.5)
        Panel.Position = UDim2.new(0.985, 0, 0.5, 0)
        Panel.Size = UDim2.new(0, 229, 0, 276)
        Panel.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
        Panel.BackgroundTransparency = 0.12
        Panel.BorderSizePixel = 0
        Panel.ZIndex = 5
        Panel.Parent = Root
        rnd(Panel, UDim.new(0, 6))
        stroke(Panel, BROWN, 2)
        local hdr = mkT(Panel, "— ИТОГИ ЗАБЕГА —", 0, 6, 229, 20, 14, GOLD, Enum.TextXAlignment.Center, 6)
        mkT(Panel, "ЗАБЕГ", 133, 28, 40, 12, 10, Color3.fromRGB(150, 150, 150), Enum.TextXAlignment.Right, 6)
        mkT(Panel, "ВСЕГО", 171, 28, 52, 12, 10, Color3.fromRGB(150, 150, 150), Enum.TextXAlignment.Right, 6)
        mkP(Panel, 6, 42, 217, 1, BROWN, 0, 6)

        local rows = {}
        for i, r in ipairs(ROWS) do
            local rf = Instance.new("Frame")
            rf.BackgroundTransparency = 1
            rf.Position = UDim2.new(0, 6, 0, 44 + (i - 1) * 16)
            rf.Size = UDim2.new(0, 217, 0, 16)
            rf.ZIndex = 6
            rf.Visible = false
            rf.Parent = Panel
            mkT(rf, r[2], 0, 0, 127, 16, 11, Color3.fromRGB(205, 205, 200), nil, 7)
            local runL = mkT(rf, "0", 127, 0, 38, 16, 11, GOLD, Enum.TextXAlignment.Right, 7)
            local totL = mkT(rf, "0", 165, 0, 52, 16, 11, Color3.fromRGB(150, 150, 150), Enum.TextXAlignment.Right, 7)
            rows[i] = {key = r[1], frame = rf, run = runL, tot = totL}
        end

        local function mkBtn(text, x, col)
            local b = Instance.new("TextButton")
            b.Position = UDim2.new(0, x, 0, 232)
            b.Size = UDim2.new(0, 104, 0, 30)
            b.BackgroundColor3 = Color3.fromRGB(22, 17, 10)
            b.BorderSizePixel = 0
            b.Text = text
            b.Font = Enum.Font.Code
            b.TextSize = 12
            b.TextColor3 = col
            b.ZIndex = 7
            b.Visible = false
            b.Parent = Panel
            rnd(b, UDim.new(0, 5))
            stroke(b, col, 1.5, 0.2)
            return b
        end
        local AgainBtn = mkBtn("ИГРАТЬ СНОВА", 6, GOLD)
        local MenuBtn = mkBtn("В МЕНЮ", 119, Color3.fromRGB(190, 190, 190))

        local Fade = mkF(Root, 0, 0, 1, 1, BLACK, 0, 20)

        -- ---------- анимация сцены ----------
        local conn
        local function startLoop()
            if conn then conn:Disconnect() end
            local t0 = os.clock()
            conn = RunService.Heartbeat:Connect(function(dt)
                local t = os.clock() - t0
                World.Position = UDim2.new(0.5, math.sin(t * 1.9) * 1.6, 0.5, math.sin(t * 2.7) * 1.1)
                for _, b in ipairs(blds) do
                    b.x -= b.sp * dt
                    if b.x + b.w < -0.05 then b.x += 1.3 end
                    b.f.Position = UDim2.fromScale(b.x, b.y)
                end
                for _, b in ipairs(bokeh) do
                    b.x -= b.sp * dt
                    if b.x < -b.w then b.x = 1 + b.w end
                    b.f.Position = UDim2.fromScale(b.x, b.y + math.sin(t * b.ph) * 0.004)
                end
                for _, r in ipairs(rain) do
                    r.y += r.vy * dt
                    r.x -= 0.22 * dt
                    if r.y > 0.7 then r.y = -0.1; r.x = math.random() * 1.1 end
                    if r.x < -0.05 then r.x += 1.1 end
                    r.f.Position = UDim2.fromScale(r.x, r.y)
                end
                local ph = (t % 3.6) / 1.1
                if ph < 1 then
                    sweep.Visible = true
                    sweep.Position = UDim2.fromScale(-0.3 + ph * 1.6, 0)
                else
                    sweep.Visible = false
                end
                glow1.BackgroundTransparency = 0.93 + math.sin(t * 1.3) * 0.015
            end)
        end
        Root.Destroying:Connect(function() if conn then conn:Disconnect() end end)

        -- ---------- показ статистики ----------
        local token = 0
        local leaving = false
        local function revealStats()
            token += 1
            local my = token
            for _, r in ipairs(rows) do r.frame.Visible = false end
            task.spawn(function()
                task.wait(1.1)
                for _, r in ipairs(rows) do
                    if my ~= token then return end
                    local runV, totV = run[r.key] or 0, Progress.total[r.key] or 0
                    r.run.Text = "0"
                    r.tot.Text = "0"
                    r.frame.Visible = true
                    pcall(playSFX, SOUNDS.Blank, 2.4)
                    local t0 = os.clock()
                    while true do
                        local a = math.min(1, (os.clock() - t0) / 0.35)
                        r.run.Text = tostring(math.floor(runV * a))
                        r.tot.Text = tostring(math.floor(totV * a))
                        if a >= 1 then break end
                        task.wait()
                        if my ~= token then return end
                    end
                    task.wait(0.04)
                end
                if my ~= token then return end
                AgainBtn.Visible = true
                MenuBtn.Visible = true
            end)
        end

        local TakeBtn = Instance.new("TextButton")
        TakeBtn.AnchorPoint = Vector2.new(0.5, 0.5)
        TakeBtn.Position = UDim2.new(0.5, 0, 0.86, 0)
        TakeBtn.Size = UDim2.new(0, 270, 0, 42)
        TakeBtn.BackgroundColor3 = Color3.fromRGB(22, 17, 8)
        TakeBtn.BackgroundTransparency = 0.15
        TakeBtn.BorderSizePixel = 0
        TakeBtn.Text = "💰  ЗАБРАТЬ ДЕНЬГИ"
        TakeBtn.Font = Enum.Font.Code
        TakeBtn.TextSize = 20
        TakeBtn.TextColor3 = GOLD
        TakeBtn.TextStrokeTransparency = 0.2
        TakeBtn.ZIndex = 33
        TakeBtn.Visible = false
        TakeBtn.Parent = Viewport
        rnd(TakeBtn, UDim.new(0, 6))
        local tkStroke = stroke(TakeBtn, GOLD, 2)
        TweenService:Create(tkStroke, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.75}):Play()

        local Ending = {}

        function Ending.hide()
            token += 1
            Root.Visible = false
            TakeBtn.Visible = false
            if conn then conn:Disconnect(); conn = nil end
        end

        local function showScene()
            token += 1
            leaving = false
            AgainBtn.Visible = false
            MenuBtn.Visible = false
            local won = GameState.LastWin or 0
            SubL.Text = string.format("+$%d    СЕРИЯ ПОБЕД: %d", won, Progress.streak or 0)
            Fade.BackgroundTransparency = 0
            Root.Visible = true
            startLoop()
            TweenService:Create(Fade, TweenInfo.new(1.6), {BackgroundTransparency = 1}):Play()
            revealStats()
        end

        -- чемодан приехал и открыт: показываем кнопку «Забрать деньги»
        local taking = false
        function Ending.offerTake()
            taking = false
            TakeBtn.TextTransparency = 1
            TakeBtn.BackgroundTransparency = 1
            TakeBtn.Visible = true
            TweenService:Create(TakeBtn, TweenInfo.new(0.5), {TextTransparency = 0, BackgroundTransparency = 0.15}):Play()
        end

        TakeBtn.MouseButton1Click:Connect(function()
            if taking or not GameState.Victory then return end
            taking = true
            TakeBtn.Visible = false
            playSFX(SOUNDS.Rack, 0.7)
            emit(Vector3.new(0, 1.8, 2.3), 60, Color3.fromRGB(255, 215, 90), 7, 1.6, 0.14, -4)
            task.spawn(function()
                task.wait(0.45)
                if not GameState.Victory then return end
                BlackOverlay.BackgroundColor3 = BLACK
                BlackOverlay.BackgroundTransparency = 1
                BlackOverlay.Visible = true
                TweenService:Create(BlackOverlay, TweenInfo.new(0.8), {BackgroundTransparency = 0}):Play()
                task.wait(0.9)
                if not GameState.Victory then return end
                cleanupVictory()
                showScene()
                BlackOverlay.Visible = false
                BlackOverlay.BackgroundTransparency = 1
            end)
        end)

        AgainBtn.MouseButton1Click:Connect(function()
            if leaving then return end
            leaving = true
            TweenService:Create(Fade, TweenInfo.new(0.5), {BackgroundTransparency = 0}):Play()
            task.wait(0.55)
            Ending.hide()
            if GameState.StartNew then GameState.StartNew() end
        end)

        MenuBtn.MouseButton1Click:Connect(function()
            if leaving then return end
            leaving = true
            TweenService:Create(Fade, TweenInfo.new(0.5), {BackgroundTransparency = 0}):Play()
            task.wait(0.55)
            Ending.hide()
            cleanupVictory()
            FX.Dealer.awayT = 0
            if GameState.ShowMenu then GameState.ShowMenu() elseif GameState.StartNew then GameState.StartNew() end
        end)

        return Ending
    end)()

    local function startNewGame()
        if not GameState.LastChance then GameState.resetRun() end -- новый забег; после смерти («Последний шанс») статистика продолжается
        GameState.Ending.hide()
        GameState.Round = 1
        GameState.MaxHP = math.random(3, 5)
        GameState.PlayerHP = GameState.MaxHP
        GameState.DealerHP = GameState.MaxHP
        GameState.PlayerItems = {}
        GameState.DealerItems = {}
        GameState.Turn = "Player"
        GameState.DealerCuffed = false
        GameState.PlayerCuffed = false
        GameState.StealingMode = false
        GameState.GameOver = false
        GameState.Busy = false
        GameState.Aiming = false
        showChoices(false)
        GameState.LastChance = false
        GameState.Victory = false
        hideLastChanceUI()
        cleanupVictory()
        FX.dealerReset()
        FX.resetCuffs()
        RestartBtn.Visible = false
        BlackOverlay.Visible = false
        BlackOverlay.BackgroundTransparency = 1
        showRoundPanel(1)
        loadShotgun()
    end

    GameState.StartNew = startNewGame

    local function checkEndCondition()
        if GameState.PlayerHP <= 0 then
            DealerFace.Text = "[ ‿ ‿ ]"
            Progress.streak = 0
            GameState.addStat("deaths")
            updateEconomyUI()
            showLastChance()
            return true
        elseif GameState.DealerHP <= 0 then
            GameState.Round += 1
            DealerFace.Text = "[ ‿ ‿ ]"
            if GameState.Round > 3 then
                GameState.GameOver = true
                GameState.Victory = true
                local won = awardWin(true, 3)
                setLog(string.format("🏆 ПОБЕДА! +%d монет. Серия: %d", won, Progress.streak), Color3.fromRGB(80, 255, 130))
                GameState.LastWin = won
                playVictoryCase() -- чемодан выезжает; в конце анимации появится кнопка «ЗАБРАТЬ ДЕНЬГИ» -> машина + статистика
                return true
            else
                local got = awardWin(false, GameState.Round - 1)
                GameState.MaxHP = math.random(4, 6)
                GameState.PlayerHP = GameState.MaxHP
                GameState.DealerHP = GameState.MaxHP
                GameState.PlayerItems = {}
                GameState.DealerItems = {}
                GameState.DealerCuffed = false
                GameState.PlayerCuffed = false
                FX.resetCuffs()
                GameState.StealingMode = false
                setLog("🔥 ДИЛЕР ПОВЕРЖЕН! +" .. got .. " монет. РАУНД " .. GameState.Round, Color3.fromRGB(100, 255, 150), "Заряжаем новую партию...")
                task.wait(1.4)
                showRoundPanel(GameState.Round)
                loadShotgun()
                GameState.Turn = "Player"
                return true
            end
        end

        if #GameState.Shells == 0 then
            task.wait(0.8)
            loadShotgun()
        end
        return false
    end

    local function switchTurn(nextTurn)
        GameState.Turn = nextTurn
        camTarget = (nextTurn == "Dealer") and CAM_DEALER or BASE_CAM
        local isDealer = (nextTurn == "Dealer")

        if GameState[nextTurn .. "Cuffed"] then
            while GameState.Intro and not GameState.GameOver do task.wait(0.1) end
            if GameState.GameOver then return end
            GameState.Busy = true
            if not GameState[nextTurn .. "CuffSkipped"] then
                -- первый раз: наручники держат, ход пропускается
                GameState[nextTurn .. "CuffSkipped"] = true
                if isDealer then
                    setLog("⛓️ Дилер в наручниках и пропускает ход!", Color3.fromRGB(120, 200, 255))
                else
                    setLog("⛓️ Ты в наручниках и пропускаешь ход!", Color3.fromRGB(255, 120, 120))
                end
                FX.cuffStruggle(nextTurn)
                GameState.Busy = false
                if GameState.GameOver then return end
                GameState.Turn = isDealer and "Player" or "Dealer"
                camTarget = isDealer and BASE_CAM or CAM_DEALER
                if isDealer then
                    setLog("ТВОЙ ХОД", Color3.fromRGB(120, 255, 150))
                else
                    task.spawn(DealerTurn)
                end
                return
            end
            -- следующая очередь: вырывается, наручники ломаются, и ход идёт как обычно
            FX.cuffBreak(nextTurn)
            GameState.Busy = false
            if GameState.GameOver then return end
            camTarget = isDealer and CAM_DEALER or BASE_CAM
        end

        if isDealer then
            task.spawn(DealerTurn)
        else
            setLog("ТВОЙ ХОД", Color3.fromRGB(120, 255, 150), "Используй предметы или возьми дробовик.")
        end
    end
-- КОНЕЦ ЧАСТИ 3В (Вся Часть 3 готова!)
-- НАЧАЛО ЧАСТИ 4А
    UseItem = function(who, itemName)
        local isPlayer = (who == "Player")
        local actorName = isPlayer and "ТЫ" or "ДИЛЕР"
        if isPlayer then GameState.addStat("items") end
        local info = ITEMS_DB[itemName]
        local head = "▶ " .. actorName .. " использовал " .. info.Icon .. " " .. info.Short
        local function report(resultText, color)
            addSideLog(head .. "\n" .. resultText, color)
        end
        local RED = Color3.fromRGB(255, 90, 90)
        local BLUE = Color3.fromRGB(110, 190, 255)
        local GREEN = Color3.fromRGB(120, 255, 150)
        local GOLD = Color3.fromRGB(255, 220, 80)
        local GRAY = Color3.fromRGB(190, 190, 190)

        renderInventories() -- запускает анимацию использованного предмета
        local rec = FX.anim[who]
        if rec and (rec.name ~= itemName or rec.taken) then rec = nil end
        if rec then rec.taken = true end

        if itemName == "Magnifying Glass" then
            if isPlayer then
                local current = GameState.Shells[1]
                FX.waitAnim(rec, "cue") -- лупа разбита и вбита в стол
                showChamberCloseup(current == true)
                report("В стволе сейчас: " .. (current and "🔴 БОЕВОЙ" or "🔵 ХОЛОСТОЙ"), current and RED or BLUE)
            else
                FX.waitAnim(rec, "cue")
                FX.Dealer.leanT = 1.4 -- наклоняется к дробовику и смотрит патрон
                task.wait(0.9)
                FX.Dealer.leanT = 0
                DealerFace.Text = "[ 🧐 _ 👁️ ]"
                setLog("🔍 Дилер проверил патронник лупой...", Color3.fromRGB(210, 210, 210))
                report("Заглянул в ствол. Что он увидел — неизвестно.", GRAY)
            end

        elseif itemName == "Screwdriver" then
            if isPlayer then GameState.addStat("screw") end
            local ejected = table.remove(GameState.Shells, 1)
            if rec then rec.live = ejected else spawn3DShell(ejected) end
            FX.waitAnim(rec, "cue")
            setLog("🪛 " .. (isPlayer and "Ты выковырял" or "Дилер выковырял") .. " патрон: " .. (ejected and "🔴 БОЕВОЙ!" or "🔵 ХОЛОСТОЙ!"), Color3.fromRGB(255, 200, 100))
            report("Текущий патрон выброшен: " .. (ejected and "🔴 БОЕВОЙ" or "🔵 ХОЛОСТОЙ"), ejected and RED or BLUE)
            updateHPUI()
            FX.waitAnim(rec, "done") -- сначала дробовик возвращается на стол
            if #GameState.Shells == 0 and not GameState.GameOver then task.wait(0.8); loadShotgun() end

        elseif itemName == "Handsaw" then
            FX.waitAnim(rec, "cue") -- дуло отпилено в руках
            GameState.SawActive = true
            setLog("🪚 3D-СТВОЛ ОТПИЛЕН! Следующий выстрел = 2 УРОНА!", Color3.fromRGB(255, 100, 50))
            report("Ствол отпилен: следующий выстрел наносит 2 урона (если патрон боевой).", Color3.fromRGB(255, 150, 60))
            updateHPUI()

        elseif itemName == "Handcuffs" then
            FX.waitAnim(rec, "cue") -- наручники защёлкнулись
            if isPlayer then
                GameState.DealerCuffed = true
                setLog("⛓️ Дилер закован в наручники!", Color3.fromRGB(120, 210, 255))
                report("Дилер пропустит свой следующий ход.", BLUE)
            else
                GameState.PlayerCuffed = true
                setLog("⛓️ Дилер заковал тебя в наручники!", Color3.fromRGB(255, 110, 110))
                report("Ты пропустишь свой следующий ход.", RED)
            end

        elseif itemName == "Cigarettes" then
            FX.waitAnim(rec, "cue") -- затянулся: теперь лечит
            playSFX(SOUNDS.Heal, 1.0)
            local key = isPlayer and "PlayerHP" or "DealerHP"
            local before = GameState[key]
            GameState[key] = math.min(GameState.MaxHP, before + 1)
            if GameState[key] > before then
                setLog("🚬 " .. (isPlayer and "Ты" or "Дилер") .. " восстановил +1 HP.", Color3.fromRGB(120, 255, 150))
                report("+1 HP (теперь " .. GameState[key] .. "/" .. GameState.MaxHP .. ")", GREEN)
            else
                setLog("🚬 Здоровье уже полное — эффекта нет.", Color3.fromRGB(180, 180, 180))
                report("Здоровье уже полное — эффекта нет.", GRAY)
            end
            updateHPUI()

        elseif itemName == "Inverter" then
            local flipped = #GameState.Shells > 0
            if flipped then GameState.Shells[1] = not GameState.Shells[1] end
            FX.waitAnim(rec, "cue") -- щелчок тумблера
            if flipped then
                setLog("🔄 РЕВЕРСЕР: Полярность патрона изменена!", Color3.fromRGB(200, 130, 255))
                report("Текущий патрон стал противоположным. Какой он теперь — неизвестно.", Color3.fromRGB(200, 130, 255))
            end

        elseif itemName == "Burner Phone" then
            FX.waitAnim(rec, "cue") -- прослушал: информация получена
            if isPlayer then
                if #GameState.Shells > 1 then
                    local idx = math.random(2, #GameState.Shells)
                    local isLiveShell = GameState.Shells[idx]
                    setLog(string.format("📱 ТЕЛЕФОН: «%d-й патрон — %s»", idx, isLiveShell and "🔴 БОЕВОЙ" or "🔵 ХОЛОСТОЙ"), Color3.fromRGB(130, 255, 220))
                    report(string.format("Патрон №%d в обойме: %s\n(№1 — тот, что сейчас в стволе)", idx, isLiveShell and "🔴 БОЕВОЙ" or "🔵 ХОЛОСТОЙ"), isLiveShell and RED or BLUE)
                else
                    setLog("📱 ТЕЛЕФОН: «В стволе остался последний патрон...»", Color3.fromRGB(180, 180, 180))
                    report("В стволе остался последний патрон — телефон ничего не показал.", GRAY)
                end
            else
                DealerFace.Text = "[ 😏 _ 👁️ ]"
                setLog("📱 Дилер прослушал одноразовый телефон...", Color3.fromRGB(200, 200, 200))
                report("Что-то узнал про один из патронов. Что именно — неизвестно.", GRAY)
            end

        elseif itemName == "Expired Medicine" then
            FX.waitAnim(rec, "cue") -- HP меняется только после того, как таблетка проглочена
            local key = isPlayer and "PlayerHP" or "DealerHP"
            local before = GameState[key]
            if math.random(1, 2) == 1 then
                playSFX(SOUNDS.Heal, 1.1)
                GameState[key] = math.min(GameState.MaxHP, before + 2)
                setLog("💊 ТАБЛЕТКИ: Повезло! +" .. (GameState[key] - before) .. " HP!", Color3.fromRGB(100, 255, 140))
                report("Повезло! +" .. (GameState[key] - before) .. " HP (теперь " .. GameState[key] .. "/" .. GameState.MaxHP .. ")", GREEN)
            else
                playSFX(SOUNDS.Blank, 0.6)
                GameState[key] = before - 1
                setLog("💊 ТАБЛЕТКИ: Отравление! -1 HP!", Color3.fromRGB(255, 70, 70))
                report("Отравление! -1 HP (теперь " .. math.max(0, GameState[key]) .. "/" .. GameState.MaxHP .. ")", RED)
            end
            camTarget = CAM_HP
            task.wait(0.55)
            updateHPUI()
            task.wait(1.3)
            camTarget = (GameState.Turn == "Dealer") and CAM_DEALER or BASE_CAM
            FX.waitAnim(rec, "done")
            checkEndCondition()

        elseif itemName == "Adrenaline" then
            FX.waitAnim(rec, "done")
            if isPlayer then
                local previousCameraTarget = camTarget
                camTarget = CFrame.lookAt(Vector3.new(0, 7.0, 4.0), Vector3.new(0, 0, -3.2))
                task.wait(0.75)
                GameState.StealingMode = true
                setLog("💉 АДРЕНАЛИН! Камера подъехала к полю Дилера — выбери предмет!", Color3.fromRGB(255, 220, 60))
                report("Выбери предмет Дилера (подсвечены золотым): он украдётся и сразу применится.", GOLD)
            else
                local candidates = {}
                for idx, n in ipairs(GameState.PlayerItems) do
                    if n ~= "Adrenaline" and canUseItem("Dealer", n) then table.insert(candidates, idx) end
                end
                if #candidates > 0 then
                    local pick = candidates[math.random(1, #candidates)]
                    FX.hint.Player = displayed.Player[pick]
                    if FX.hint.Player then FX.hint.Player.actor = "Dealer" end
                    local stolen = table.remove(GameState.PlayerItems, pick)
                    local sInfo = ITEMS_DB[stolen]
                    setLog("💉 Дилер украл твой предмет: " .. sInfo.Short .. "!", Color3.fromRGB(255, 100, 100))
                    report("Украл у тебя " .. sInfo.Icon .. " " .. sInfo.Short .. " и применяет его сразу.", RED)
                    renderInventories()
                    task.wait(0.8)
                    UseItem("Dealer", stolen)
                else
                    report("Красть было нечего.", GRAY)
                end
            end
        end
        FX.waitAnim(rec, "done")
        renderInventories()
    end
-- КОНЕЦ ЧАСТИ 4А
-- НАЧАЛО ЧАСТИ 4Б
    local function fireShot(shooter, target)
        if #GameState.Shells == 0 or GameState.Busy then return end
        GameState.Busy = true

        local isLive = table.remove(GameState.Shells, 1)
        GameState.recordShot(shooter, target, isLive)
        local dmg = GameState.SawActive and 2 or 1
        GameState.SawActive = false
        local fatal = isLive and target == "Player" and (GameState.PlayerHP - dmg <= 0)

        local whoName = (shooter == "Player") and "ТЫ" or "ДИЛЕР"
        local atName
        if shooter == target then atName = "в себя"
        elseif target == "Dealer" then atName = "в Дилера"
        else atName = "в тебя" end

        camTarget = (shooter == "Player" and target == "Player") and CAM_SELF or CAM_DEALER
        animate3DGun(shooter, target, isLive, dmg > 1)
        if isLive and target == "Player" then
            if fatal then blackoutHold() else blackoutEnd() end
        end

        if isLive then
            addSideLog("🔫 " .. whoName .. " выстрелил " .. atName .. ": 🔴 БОЕВОЙ (-" .. dmg .. " HP)", Color3.fromRGB(255, 90, 90))
            if target == "Dealer" then
                FX.waitDealer() -- HP снимается только после того, как Дилер вернулся из темноты
                GameState.DealerHP -= dmg
                setLog("💥 БАХ! БОЕВОЙ! Дилер получил -" .. dmg .. " HP!", Color3.fromRGB(255, 70, 70))
            else
                GameState.PlayerHP -= dmg
                DealerFace.Text = "[ ‿ ‿ ]"
                setLog("💥 БАХ! БОЕВОЙ! Ты получил -" .. dmg .. " HP!", Color3.fromRGB(255, 50, 50))
            end
            camTarget = CAM_HP -- камера уезжает на табло справа
            task.wait(fatal and 0.2 or 0.9)
            updateHPUI() -- молния рассыпается и пропадает
            task.wait(fatal and 0.5 or 2.2)
            GameState.Busy = false
            if checkEndCondition() then return end
            switchTurn(shooter == "Player" and "Dealer" or "Player")
        else
            addSideLog("🔫 " .. whoName .. " выстрелил " .. atName .. ": 🔵 ХОЛОСТОЙ", Color3.fromRGB(110, 190, 255))
            setLog("💨 *ЩЕЛК* — ХОЛОСТОЙ ПАТРОН!", Color3.fromRGB(110, 190, 255))
            updateHPUI()
            GameState.Busy = false
            if checkEndCondition() then return end
            if shooter == target then
                if shooter == "Player" then
                    setLog("💨 ХОЛОСТОЙ В СЕБЯ! Ты сохраняешь ход.", Color3.fromRGB(110, 255, 170))
                    camTarget = BASE_CAM
                else
                    task.wait(0.6)
                    task.spawn(DealerTurn)
                end
            else
                switchTurn(shooter == "Player" and "Dealer" or "Player")
            end
        end
    end

    DealerTurn = function()
        while GameState.Intro do task.wait(0.1) end -- пока идёт зарядка и раздача предметов
        if GameState.GameOver or GameState.Turn ~= "Dealer" then return end
        DealerFace.Text = "[ ‿ ‿ ]"
        setLog("🤖 Дилер оценивает шансы...", Color3.fromRGB(255, 180, 180))
        task.wait(2.0)

        local knownShell = nil
        local i = 1
        while i <= #GameState.DealerItems do
            if GameState.GameOver or GameState.Turn ~= "Dealer" or #GameState.Shells == 0 then break end
            local item = GameState.DealerItems[i]
            local want = false
            if item == "Cigarettes" and GameState.DealerHP < GameState.MaxHP then want = true
            elseif item == "Magnifying Glass" and knownShell == nil then want = true
            elseif item == "Inverter" and knownShell == false then want = true
            elseif item == "Handcuffs" and not GameState.PlayerCuffed and #GameState.Shells > 1 then want = true
            elseif item == "Handsaw" and not GameState.SawActive and knownShell == true then want = true
            elseif item == "Screwdriver" and knownShell == nil and #GameState.Shells > 1 then want = true
            elseif item == "Burner Phone" and knownShell == nil and #GameState.Shells > 1 then want = true
            elseif item == "Expired Medicine" and GameState.DealerHP == 2 and GameState.DealerHP < GameState.MaxHP then want = true
            elseif item == "Adrenaline" and canUseItem("Dealer", "Adrenaline") then want = true
            end

            if want then
                task.wait(1.4) -- Дилер думает перед каждым предметом
                if GameState.GameOver or GameState.Turn ~= "Dealer" or #GameState.Shells == 0 then break end
                FX.hint.Dealer = displayed.Dealer[i]
                table.remove(GameState.DealerItems, i)
                if item == "Magnifying Glass" then
                    local _, first = next(GameState.Shells)
                    knownShell = first
                elseif item == "Inverter" then
                    knownShell = true
                end
                local before = GameState.Shells
                UseItem("Dealer", item) -- возвращается, когда анимация предмета закончилась
                renderInventories()
                camTarget = CAM_DEALER
                while GameState.Intro do task.wait(0.1) end -- вдруг пошла перезарядка
                if GameState.Shells ~= before then knownShell = nil end
                task.wait(0.9)
            else
                i += 1
            end
        end

        if GameState.GameOver or GameState.Turn ~= "Dealer" or #GameState.Shells == 0 then return end

        local liveCount, blankCount = 0, 0
        for _, s in ipairs(GameState.Shells) do if s then liveCount += 1 else blankCount += 1 end end

        local shootPlayer
        if knownShell ~= nil then
            shootPlayer = (knownShell == true) -- live -> shoot player, blank -> shoot self
        else
            shootPlayer = liveCount >= blankCount
        end
        task.wait(1.8)
        if shootPlayer then
            setLog("🤖 Дилер наводит 3D-дробовик на ТЕБЯ...", Color3.fromRGB(255, 100, 100))
            fireShot("Dealer", "Player")
        else
            setLog("🤖 Дилер приставляет дуло к СЕБЕ...", Color3.fromRGB(150, 200, 255))
            fireShot("Dealer", "Dealer")
        end
    end

    -- ВЗЯТЬ ДРОБОВИК -> выбрать цель (Dealer / You) -> выстрел
    local function pickUpGun()
        if not GunCtl.clickable() then return end
        GameState.Busy = true
        GunCtl.take("Player")
        if GameState.GameOver or not ScreenGui.Parent then return end
        GameState.Aiming = true
        showChoices(true)
        subtitle("Выбери цель", Color3.fromRGB(255, 235, 150))
    end

    local function putGunBack()
        if not GameState.Aiming then return end
        GameState.Aiming = false
        showChoices(false)
        GunCtl.release("Player")
        GameState.Busy = false
    end

    local function chooseTarget(target)
        if not GameState.Aiming then return end
        GameState.Aiming = false
        showChoices(false)
        GameState.Busy = false
        fireShot("Player", target)
    end

    ChooseDealerBtn.MouseButton1Click:Connect(function() chooseTarget("Dealer") end)
    ChooseSelfBtn.MouseButton1Click:Connect(function() chooseTarget("Player") end)
    GunBtn.MouseButton1Click:Connect(function()
        if GameState.GameOver then return end
        if GameState.Aiming then putGunBack() else pickUpGun() end
    end)
    RestartBtn.MouseButton1Click:Connect(function()
        if GameState.GameOver then startNewGame() end
    end)

    LastChanceBtn.MouseButton1Click:Connect(function()
        if not GameState.LastChance then return end
        startNewGame()
    end)
    SurrenderBtn.MouseButton1Click:Connect(function()
        if not GameState.LastChance then return end
        dieForReal()
    end)

    -- игра стартует не сразу, а из меню (кнопка PLAY)
    GameState.ShowMenu = BuildMenuAndShop({
        ScreenGui = ScreenGui, MainFrame = MainFrame, Content = Content, Viewport = Viewport, WinScale = WinScale,
        WorldModel = WorldModel, mk = mk, newModel = newModel, FX = FX, GameState = GameState,
        DealerHead = DealerHead, gunParts = gunParts, VIEW_W = VIEW_W, VIEW_H = VIEW_H,
        startNewGame = startNewGame,
        getMusic = function() return MusicSound end,
    })
end

TriggerBtn.MouseButton1Click:Connect(Launch3DBuckshot)
-- КОНЕЦ ЧАСТИ 4Б (Финал!)
