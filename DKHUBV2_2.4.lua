--[[
    DKHUB EggWarpUI v2.4
    - รายการไข่ active เรียงตามระยะทาง
    - วาร์ปไปหาไข่ -> เรียก Pickup prompt -> กลับฐาน
    - UI ใหม่: ลากได้, รีเฟรช, สถานะ, ปุ่มป้องกันกดซ้ำ, โลโก้ DKHUB
    - โหลดภาพไข่ local ที่ดาวน์โหลดไว้ผ่าน getcustomasset / getsynasset

    วิธีใช้ภาพโลโก้:
    วาง DKHUB_Logo.png ไว้โฟลเดอร์เดียวกับไฟล์สคริปต์ของ executor
    หาก executor รองรับ getcustomasset หรือ getsynasset ระบบจะโหลดให้อัตโนมัติ
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local RemoteBase = "https://raw.githubusercontent.com/nightEX1/DKHUB67/main/"

local Config = {
    ToggleKey = Enum.KeyCode.RightShift,
    PickupWait = 4,
    PickupRange = 28,
    HeightOffset = 3,
    ReturnOffset = Vector3.new(0, 5, 0),
    LogoFile = "DKHUB_Logo.png",
}

local EggNames = {
    "Mushroom Egg", "Flower Egg", "Slime Egg", "Ice Egg", "Glass Egg", "Golden Egg",
    "Crystal Egg", "Skull Egg", "Dominus Egg", "Flaming Egg", "Sinister Egg", "Soul Egg",
    "Aurora Egg", "Galaxy Egg", "Blackhole Egg", "Cherub Egg",
}

-- URL อ้างอิงจาก Ride a Pet Wiki; Roblox ปกติไม่อนุญาต URL ภายนอกใน ImageLabel
local EggImages = {
    ["Mushroom Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/4/4a/Mushroom_Egg_RideAPet.png/revision/latest",
    ["Flower Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/d/d5/Flower_Egg_RideAPet.png/revision/latest",
    ["Slime Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/8/87/Slime_Egg_RideAPet.png/revision/latest",
    ["Ice Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/2/2b/Ice_Egg_RideAPet.png/revision/latest",
    ["Glass Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/0/04/Glass_Egg_RideAPet.png/revision/latest",
    ["Golden Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/3/37/Golden_Egg_RideAPet.png/revision/latest",
    ["Crystal Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/a/a3/Crystal_Egg_RideAPet.png/revision/latest",
    ["Skull Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/8/85/Skull_Egg_RideAPet.png/revision/latest",
    ["Dominus Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/7/7b/Dominus_Egg_RideAPet.png/revision/latest",
    ["Flaming Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/b/b0/Flaming_Egg_RideAPet.png/revision/latest",
    ["Sinister Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/1/12/Sinister_Egg_RideAPet.png/revision/latest",
    ["Soul Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/7/79/Soul_Egg_RideAPet.png/revision/latest",
    ["Aurora Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/4/4e/Aurora_Egg_RideAPet.png/revision/latest",
    ["Galaxy Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/3/37/Galaxy_Egg_RideAPet.png/revision/latest",
    ["Blackhole Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/0/0e/Black_Hole_Egg_RideAPet.png/revision/latest",
    ["Black Hole Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/0/0e/Black_Hole_Egg_RideAPet.png/revision/latest",
    ["Cherub Egg"] = "https://static.wikia.nocookie.net/ride-a-pet/images/0/02/Cherub_Egg_RideAPet.png/revision/latest",
}

local function getAsset(fileName)
    local loaders = {getcustomasset, getsynasset}
    for _, loader in ipairs(loaders) do
        if type(loader) == "function" then
            local ok, result = pcall(loader, fileName)
            if ok and type(result) == "string" then return result end
        end
    end
    return nil
end

local function imageForEgg(name)
    local safe = tostring(name or "Egg"):gsub("[^%w%-]", "_")
    -- ใช้ภาพ local ก่อน แล้ว fallback ไปยังไฟล์ใน GitHub รีโพซิทอรี
    return getAsset("DKHUB_Eggs/" .. safe .. ".png")
        or getAsset(safe .. ".png")
        or RemoteBase .. "DKHUB_Eggs/" .. safe .. ".png"
end

local ActiveEggs = RS:WaitForChild("ServerData"):WaitForChild("ActiveEggs")
local function getRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getBaseCFrame()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local owner = plot:FindFirstChild("Owner")
        if owner and owner:IsA("ObjectValue") and owner.Value == LocalPlayer then
            local bp = plot:FindFirstChild("Baseplate")
            return (bp and bp.CFrame or plot:GetPivot()) + Config.ReturnOffset
        end
    end
    return nil
end

local function getPosition(cfg)
    local p = cfg:GetAttribute("Position")
    return typeof(p) == "Vector3" and p or nil
end

local function findPrompt(pos)
    local rendered = workspace:FindFirstChild("RenderedEggs")
    if not rendered then return nil end
    local best, bestDistance = nil, Config.PickupRange
    for _, model in ipairs(rendered:GetChildren()) do
        local ok, pivot = pcall(function() return model:GetPivot() end)
        if ok and pivot then
            local distance = (pivot.Position - pos).Magnitude
            local prompt = model:FindFirstChild("Pickup", true)
            if distance <= bestDistance and prompt and prompt:IsA("ProximityPrompt") then
                best, bestDistance = prompt, distance
            end
        end
    end
    return best
end

-- UI setup
local parent = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function()
    local old = parent:FindFirstChild("DKHUB_EggWarpUI")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "DKHUB_EggWarpUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parent

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = obj
end
local function outline(obj, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color, s.Thickness, s.Transparency = color, thickness or 1, transparency or 0.25
    s.Parent = obj
end
local function label(parentObj, text, size, color, font)
    local x = Instance.new("TextLabel")
    x.BackgroundTransparency = 1
    x.Text = text
    x.TextSize = size
    x.TextColor3 = color
    x.Font = font or Enum.Font.Gotham
    x.TextXAlignment = Enum.TextXAlignment.Left
    x.Parent = parentObj
    return x
end

local BG = Color3.fromRGB(12, 13, 19)
local PANEL = Color3.fromRGB(24, 26, 36)
local CARD = Color3.fromRGB(31, 34, 47)
local ACCENT = Color3.fromRGB(232, 48, 91)
local ACCENT2 = Color3.fromRGB(255, 86, 119)
local TEXT = Color3.fromRGB(246, 247, 252)
local DIM = Color3.fromRGB(157, 163, 181)
local GREEN = Color3.fromRGB(70, 211, 143)

local function draggable(handle, target)
    local dragging, startPos, startInput
    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging, startPos, startInput = true, target.Position, input.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - startInput
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local icon = Instance.new("ImageButton")
icon.Name = "Launcher"
icon.Size = UDim2.fromOffset(58, 58)
icon.Position = UDim2.new(0, 18, 0.5, -29)
icon.BackgroundColor3 = BG
icon.AutoButtonColor = false
icon.Parent = gui
corner(icon, 29)
outline(icon, ACCENT, 2, 0.05)
local logoAsset = getAsset(Config.LogoFile) or RemoteBase .. Config.LogoFile
if logoAsset then
    icon.Image = logoAsset
    icon.ScaleType = Enum.ScaleType.Crop
else
    icon.Image = ""
    local fallback = label(icon, "DK", 18, TEXT, Enum.Font.GothamBold)
    fallback.Size = UDim2.fromScale(1, 1)
    fallback.TextXAlignment = Enum.TextXAlignment.Center
    fallback.TextYAlignment = Enum.TextYAlignment.Center
end
draggable(icon, icon)

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(390, 500)
main.Position = UDim2.new(0, 88, 0.5, -250)
main.BackgroundColor3 = BG
main.Visible = false
main.ClipsDescendants = true
main.Parent = gui
corner(main, 16)
outline(main, ACCENT, 1.5, 0.15)
local scale = Instance.new("UIScale")
scale.Scale = 0.94
scale.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 78)
header.BackgroundColor3 = PANEL
header.BorderSizePixel = 0
header.Parent = main
corner(header, 16)
draggable(header, main)

local headerLogo = Instance.new("ImageLabel")
headerLogo.BackgroundTransparency = 1
headerLogo.Position = UDim2.fromOffset(12, 12)
headerLogo.Size = UDim2.fromOffset(54, 54)
headerLogo.ScaleType = Enum.ScaleType.Crop
headerLogo.Image = logoAsset or ""
headerLogo.Parent = header
corner(headerLogo, 12)

local title = label(header, "DKHUB  •  EGG WARP", 17, TEXT, Enum.Font.GothamBold)
title.Position = UDim2.fromOffset(78, 12)
title.Size = UDim2.new(1, -140, 0, 24)
local sub = label(header, "กำลังตรวจหาไข่ในแมพ...", 12, DIM)
sub.Position = UDim2.fromOffset(78, 39)
sub.Size = UDim2.new(1, -140, 0, 20)

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(32, 32)
close.Position = UDim2.new(1, -44, 0, 12)
close.BackgroundColor3 = CARD
close.Text = "×"
close.TextSize = 22
close.TextColor3 = DIM
close.Font = Enum.Font.GothamBold
close.Parent = header
corner(close, 10)

local refresh = Instance.new("TextButton")
refresh.Size = UDim2.fromOffset(92, 30)
refresh.Position = UDim2.new(1, -106, 0, 42)
refresh.BackgroundColor3 = ACCENT
refresh.Text = "รีเฟรช  ↻"
refresh.TextSize = 12
refresh.TextColor3 = TEXT
refresh.Font = Enum.Font.GothamBold
refresh.Parent = header
corner(refresh, 9)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(12, 90)
list.Size = UDim2.new(1, -24, 1, -137)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.ScrollBarImageColor3 = ACCENT
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = main
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local status = label(main, "พร้อมใช้งาน", 12, DIM)
status.Position = UDim2.new(0, 16, 1, -35)
status.Size = UDim2.new(1, -32, 0, 20)

local rows, busy = {}, false
local function setStatus(text, color)
    status.Text = text
    status.TextColor3 = color or DIM
end

local function warpToEgg(cfg)
    if busy then setStatus("กำลังทำงานอยู่ กรุณารอสักครู่", ACCENT2); return end
    local root, pos = getRoot(), getPosition(cfg)
    if not root or not pos then setStatus("ไม่พบตำแหน่งตัวละครหรือไข่", ACCENT2); return end
    busy = true
    local oldBase = getBaseCFrame() or root.CFrame
    local name = tostring(cfg:GetAttribute("Egg") or cfg.Name or "Egg")
    setStatus("กำลังไปที่ " .. name .. "...", ACCENT2)
    local ok = pcall(function() root.CFrame = CFrame.new(pos + Vector3.new(0, Config.HeightOffset, 0)) end)
    if ok then task.wait(0.4) end
    local prompt = findPrompt(pos)
    if prompt and type(fireproximityprompt) == "function" then
        setStatus("กำลังเก็บ " .. name .. "...", GREEN)
        local start = os.clock()
        repeat
            pcall(fireproximityprompt, prompt)
            task.wait(0.15)
        until not cfg.Parent or os.clock() - start >= Config.PickupWait
    else
        setStatus("ไม่พบ Pickup prompt — รอการเก็บ...", DIM)
        task.wait(1)
    end
    root = getRoot()
    if root then pcall(function() root.CFrame = oldBase end) end
    setStatus("กลับฐานแล้ว: " .. name, GREEN)
    busy = false
    task.delay(2.5, function() if not busy then setStatus("พร้อมใช้งาน", DIM) end end)
end

local function makeRow(cfg, order, distance)
    local name = tostring(cfg:GetAttribute("Egg") or cfg.Name or "Egg")
    local row = Instance.new("Frame")
    row.Name = "EggRow"
    row.Size = UDim2.new(1, -4, 0, 66)
    row.BackgroundColor3 = CARD
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = list
    corner(row, 12)

    local image = Instance.new("ImageLabel")
    image.BackgroundTransparency = 1
    image.Position = UDim2.fromOffset(8, 8)
    image.Size = UDim2.fromOffset(50, 50)
    image.ScaleType = Enum.ScaleType.Fit
    image.Image = imageForEgg(name) or ""
    image.Parent = row
    corner(image, 10)

    local nameLabel = label(row, name, 14, TEXT, Enum.Font.GothamBold)
    nameLabel.Position = UDim2.fromOffset(70, 11)
    nameLabel.Size = UDim2.new(1, -175, 0, 22)
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    local detail = label(row, string.format("%.1f studs  •  %.2f kg", distance, tonumber(cfg:GetAttribute("Weight")) or 0), 11, DIM)
    detail.Position = UDim2.fromOffset(70, 36)
    detail.Size = UDim2.new(1, -175, 0, 18)

    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(88, 34)
    button.Position = UDim2.new(1, -98, 0.5, -17)
    button.BackgroundColor3 = ACCENT
    button.Text = "วาร์ป  ›"
    button.TextSize = 12
    button.TextColor3 = TEXT
    button.Font = Enum.Font.GothamBold
    button.Parent = row
    corner(button, 10)
    button.MouseButton1Click:Connect(function() task.spawn(warpToEgg, cfg) end)
    rows[cfg] = row
end

local function refreshList()
    for _, row in pairs(rows) do row:Destroy() end
    rows = {}
    local root = getRoot()
    local items = {}
    for _, cfg in ipairs(ActiveEggs:GetChildren()) do
        local pos = getPosition(cfg)
        if pos then table.insert(items, {cfg = cfg, distance = root and (root.Position - pos).Magnitude or 0}) end
    end
    table.sort(items, function(a, b) return a.distance < b.distance end)
    for index, item in ipairs(items) do makeRow(item.cfg, index, item.distance) end
    sub.Text = string.format("พบไข่ที่ใช้งานอยู่ %d ใบ", #items)
    if #items == 0 then setStatus("ยังไม่พบไข่ active ในแมพ", DIM) else setStatus("พร้อมใช้งาน", DIM) end
end

local open = false
local tween = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local function setOpen(value)
    open = value
    if value then
        main.Visible = true
        TweenService:Create(scale, tween, {Scale = 1}):Play()
        TweenService:Create(icon, tween, {BackgroundColor3 = Color3.fromRGB(51, 58, 76)}):Play()
        refreshList()
    else
        TweenService:Create(scale, tween, {Scale = 0.94}):Play()
        TweenService:Create(icon, tween, {BackgroundColor3 = BG}):Play()
        task.delay(0.2, function() if not open then main.Visible = false end end)
    end
end

icon.MouseButton1Click:Connect(function() setOpen(not open) end)
close.MouseButton1Click:Connect(function() setOpen(false) end)
refresh.MouseButton1Click:Connect(refreshList)
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Config.ToggleKey then setOpen(not open) end
end)
ActiveEggs.ChildAdded:Connect(function() task.wait(0.1); if open then refreshList() end end)
ActiveEggs.ChildRemoved:Connect(function() if open then refreshList() end end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    if not open or busy then return end
    elapsed += dt
    if elapsed >= 1 then elapsed = 0; refreshList() end
end)

refreshList()
print("[DKHUB EggWarpUI v2.4] Ready — toggle: " .. Config.ToggleKey.Name)
