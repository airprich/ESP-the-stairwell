-- Stairwell ESP (mobile standalone)
-- Author: betmon1904p
-- Version: 2.1
--
-- Работает без Cheesy — loadstring в любом executor'е (Delta, Xeno, Arceus и т.д.)
-- Две плавающие кнопки: ON (включить) и OFF (выключить)
-- Кнопки можно таскать пальцем.
--
-- Оптимизация взята из Honcho ESP.

------------------------------------------------------------
-- SERVICES
------------------------------------------------------------

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------

local SAFETY_SCAN_INTERVAL = 5

local TARGETS = {
    ["ShoppingCart"]  = Color3.fromRGB(0, 255, 0),
    ["BottleCrate"]   = Color3.fromRGB(180, 120, 60),
    ["DinkyLamp"]     = Color3.fromRGB(255, 255, 100),
    ["GweenSodaPack"] = Color3.fromRGB(0, 200, 100),
    ["BrokenMonitor"] = Color3.fromRGB(200, 200, 200),
}

local OUTLINE_COLOR = Color3.fromRGB(255, 255, 255)

------------------------------------------------------------
-- STATE
------------------------------------------------------------

local espEnabled = false
local currentRooms = nil
local rooms = {}
local connections = {}

------------------------------------------------------------
-- CONNECTION MANAGEMENT
------------------------------------------------------------

local function disconnectAll()
    for _, connection in ipairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    table.clear(connections)
end

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

------------------------------------------------------------
-- HIGHLIGHTS
------------------------------------------------------------

local function applyHighlight(object, color, name)
    if not object or not object.Parent then
        return
    end

    local highlight = object:FindFirstChild(name)

    if not highlight or not highlight:IsA("Highlight") then
        highlight = Instance.new("Highlight")
        highlight.Name = name
        highlight.FillTransparency = 0.4
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = object
    end

    highlight.FillColor = color
    highlight.OutlineColor = OUTLINE_COLOR
end

local function removeHighlight(object, name)
    if not object then return end
    local highlight = object:FindFirstChild(name)
    if highlight then
        highlight:Destroy()
    end
end

local function clearAllHighlights()
    for _, roomData in pairs(rooms) do
        for obj in pairs(roomData.objects) do
            if obj and obj.Parent then
                removeHighlight(obj, "StairwellESP")
            end
        end
    end
end

------------------------------------------------------------
-- ROOM HELPERS
------------------------------------------------------------

local function getRoomForObject(object)
    if not currentRooms or not object then
        return nil
    end
    local current = object
    while current and current.Parent ~= currentRooms do
        current = current.Parent
    end
    if current and current.Parent == currentRooms then
        return current
    end
    return nil
end

local function getOrCreateRoom(room)
    if not room then return nil end
    if rooms[room] then return rooms[room] end
    rooms[room] = { objects = {} }
    return rooms[room]
end

------------------------------------------------------------
-- ADD / REMOVE OBJECT
------------------------------------------------------------

local function addObject(object)
    if not espEnabled then return end
    if not object or not object.Parent then return end

    local targetColor = TARGETS[object.Name]
    if not targetColor then return end

    if not (object:IsA("Model") or object:IsA("BasePart")) then
        return
    end

    local room = getRoomForObject(object)
    if not room then return end

    local roomData = getOrCreateRoom(room)

    if roomData.objects[object] then
        applyHighlight(object, targetColor, "StairwellESP")
        return
    end

    roomData.objects[object] = {
        color = targetColor,
    }

    applyHighlight(object, targetColor, "StairwellESP")
end

local function removeObject(object)
    removeHighlight(object, "StairwellESP")
end

------------------------------------------------------------
-- ROOM SCAN
------------------------------------------------------------

local function scanRoom(room)
    if not room then return end

    local roomData = getOrCreateRoom(room)

    for _, object in ipairs(room:GetDescendants()) do
        if TARGETS[object.Name] and (object:IsA("Model") or object:IsA("BasePart")) then
            addObject(object)
        end
    end

    for obj, data in pairs(roomData.objects) do
        if obj and obj.Parent then
            applyHighlight(obj, data.color, "StairwellESP")
        end
    end
end

local function scanAllRooms()
    if not currentRooms then return end

    for _, room in ipairs(currentRooms:GetChildren()) do
        scanRoom(room)
    end
end

------------------------------------------------------------
-- SAFETY RESCAN
------------------------------------------------------------

local function safetyRescan()
    if not espEnabled then return end

    scanAllRooms()

    for _, roomData in pairs(rooms) do
        for obj, data in pairs(roomData.objects) do
            if obj and obj.Parent and data.color then
                applyHighlight(obj, data.color, "StairwellESP")
            end
        end
    end
end

------------------------------------------------------------
-- CLEANUP
------------------------------------------------------------

local function cleanupRooms()
    for room, roomData in pairs(rooms) do
        if not room or not room.Parent then
            for obj in pairs(roomData.objects) do
                removeHighlight(obj, "StairwellESP")
            end
            rooms[room] = nil
        end
    end
end

------------------------------------------------------------
-- EVENT LISTENERS
------------------------------------------------------------

local function setupRoomListeners()
    if not currentRooms then return end

    connect(currentRooms.ChildAdded, function(room)
        if not espEnabled then return end
        task.delay(0.1, function()
            if espEnabled and room and room.Parent == currentRooms then
                scanRoom(room)
            end
        end)
    end)

    connect(currentRooms.DescendantAdded, function(object)
        if not espEnabled then return end
        if TARGETS[object.Name] then
            addObject(object)
        end
    end)

    connect(currentRooms.DescendantRemoving, function(object)
        if not currentRooms then return end
        local room = getRoomForObject(object)
        if not room then return end
        local roomData = rooms[room]
        if not roomData then return end
        if roomData.objects[object] then
            removeObject(object)
        end
    end)
end

------------------------------------------------------------
-- START / STOP
------------------------------------------------------------

local function startESP()
    disconnectAll()
    table.clear(rooms)

    currentRooms = Workspace:FindFirstChild("CurrentRooms")

    if not currentRooms then
        warn("[Stairwell ESP] CurrentRooms не найден.")
        return
    end

    scanAllRooms()
    setupRoomListeners()

    task.spawn(function()
        while espEnabled do
            task.wait(SAFETY_SCAN_INTERVAL)

            if espEnabled then
                cleanupRooms()
                safetyRescan()
            end
        end
    end)
end

local function stopESP()
    clearAllHighlights()
    disconnectAll()
    table.clear(rooms)
    currentRooms = nil
end

------------------------------------------------------------
-- MOBILE UI (плавающие кнопки)
------------------------------------------------------------

-- Убираем старый GUI, если перезапускаем скрипт
pcall(function()
    local old = CoreGui:FindFirstChild("StairwellESP_Mobile")
    if old then old:Destroy() end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StairwellESP_Mobile"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Защита от обнаружения (если executor поддерживает)
pcall(function()
    if syn and syn.protect_gui then
        syn.protect_gui(screenGui)
    end
    screenGui.Parent = CoreGui
end)

if not screenGui.Parent then
    screenGui.Parent = player:WaitForChild("PlayerGui")
end

-- Функция создания таскаемой кнопки
local function makeDraggableButton(name, text, color, initialPos, callback)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.fromOffset(90, 45)
    btn.Position = initialPos
    btn.BackgroundColor3 = color
    btn.BackgroundTransparency = 0.15
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.Active = true
    btn.Draggable = false -- используем свой drag
    btn.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    stroke.Parent = btn

    -- Drag + tap
    local dragging = false
    local dragStart = nil
    local startPos = nil
    local moved = false

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            moved = false
            dragStart = input.Position
            startPos = btn.Position
        end
    end)

    btn.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 5 then
                moved = true
            end
            btn.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            if dragging and not moved then
                -- Это был тап, не драг
                callback()
            end
            dragging = false
        end
    end)

    return btn
end

local guiHeight = workspace.CurrentCamera.ViewportSize.Y

local onButton = makeDraggableButton(
    "OnButton",
    "ON",
    Color3.fromRGB(0, 170, 0),
    UDim2.new(0, 20, 0, guiHeight - 160),
    function()
        if espEnabled then
            onButton.Text = "ALREADY ON"
            task.wait(0.8)
            onButton.Text = "ON"
            return
        end
        espEnabled = true
        startESP()
        onButton.Text = "ON ✓"
        task.wait(0.8)
        onButton.Text = "ON"
        print("[Stairwell ESP] Включено")
    end
)

local offButton = makeDraggableButton(
    "OffButton",
    "OFF",
    Color3.fromRGB(170, 0, 0),
    UDim2.new(0, 20, 0, guiHeight - 100),
    function()
        if not espEnabled then
            offButton.Text = "ALREADY OFF"
            task.wait(0.8)
            offButton.Text = "OFF"
            return
        end
        espEnabled = false
        stopESP()
        offButton.Text = "OFF ✓"
        task.wait(0.8)
        offButton.Text = "OFF"
        print("[Stairwell ESP] Выключено")
    end
)

------------------------------------------------------------
-- АВТОЗАПУСК? (нет — ждём нажатия ON)
------------------------------------------------------------

print("[Stairwell ESP] Загружено. Нажми ON для включения, OFF для выключения.")
