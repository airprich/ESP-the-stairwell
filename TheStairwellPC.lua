-- Stairwell ESP (standalone)
-- Author: betmon1904p
-- Version: 2.0
--
-- N — включить подсветку
-- M — выключить подсветку
--
-- Оптимизация взята из Honcho ESP:
--   • Event-based detection
--   • Safety rescan раз в 5 секунд
--   • Разделение по комнатам
--   • Никаких постоянных сканов каждые 0.2с

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

-- Объекты для подсветки (имя = цвет)
local TARGETS = {
    ["ShoppingCart"]  = Color3.fromRGB(0, 255, 0),      -- зелёный
    ["BottleCrate"]   = Color3.fromRGB(180, 120, 60),   -- коричневый
    ["DinkyLamp"]     = Color3.fromRGB(255, 255, 100),  -- жёлтый
    ["GweenSodaPack"] = Color3.fromRGB(0, 200, 100),    -- изумрудный
    ["BrokenMonitor"] = Color3.fromRGB(200, 200, 200),  -- серый
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
-- NOTIFICATION (простой)
------------------------------------------------------------

local function notify(text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Stairwell ESP",
            Text = text,
            Duration = 2,
        })
    end)
    print("[Stairwell ESP] " .. text)
end

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
-- KEYBINDS: N — вкл, M — выкл
------------------------------------------------------------

local function enable()
    if espEnabled then
        notify("Уже включено")
        return
    end
    espEnabled = true
    startESP()
    notify("Включено (N)")
end

local function disable()
    if not espEnabled then
        notify("Уже выключено")
        return
    end
    espEnabled = false
    stopESP()
    notify("Выключено (M)")
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if UserInputService:GetFocusedTextBox() then return end

    if input.KeyCode == Enum.KeyCode.N then
        enable()
    elseif input.KeyCode == Enum.KeyCode.M then
        disable()
    end
end)

------------------------------------------------------------
-- ЗАГРУЗКА
------------------------------------------------------------

notify("Загружено. N — включить, M — выключить")
