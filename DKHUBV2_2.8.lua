--[[
    DKHUB EggWarpUI v2.8
    - รายการไข่ active เรียงตามระยะทาง
    - วาร์ปไปหาไข่ -> เรียก Pickup prompt -> กลับฐาน
    - UI ใหม่: ลากได้, รีเฟรช, สถานะ, ปุ่มป้องกันกดซ้ำ, โลโก้ DKHUB
    - ดาวน์โหลดภาพจาก GitHub อัตโนมัติ แล้วแสดงผ่าน getcustomasset / getsynasset

    ระบบภาพ:
    ถ้าไม่มีไฟล์ local สคริปต์จะดาวน์โหลดจาก GitHub ด้วย game:HttpGet
    แล้วบันทึกเป็น local asset ด้วย writefile ก่อนแสดงใน ImageLabel
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local RemoteBase = "https://raw.githubusercontent.com/nightEX1/DKHUB67/main/"

local Config = {
    ToggleKey = Enum.KeyCode.RightShift,
    PickupWait = 4,
    AutoInterval = 60,
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
-- Leaf Egg ไม่อยู่ใน EggNames หลักเดิม แต่ยังให้โหมดออโต้และ webhook เลือกได้
local NotifyEggNames = {}
for _, name in ipairs(EggNames) do table.insert(NotifyEggNames, name) end
table.insert(NotifyEggNames, "Leaf Egg")

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

local function httpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and #body > 0 then return body end
    if type(request) == "function" then
        local okRequest, response = pcall(request, {Url = url, Method = "GET"})
        if okRequest and response and (response.Success or response.StatusCode == 200) then
            return response.Body
        end
    end
    return nil
end

local function ensureLocalAsset(fileName, url)
    if type(isfile) == "function" then
        local exists = false
        pcall(function() exists = isfile(fileName) end)
        if exists then return fileName end
    end
    if type(writefile) ~= "function" then return nil end
    if type(makefolder) == "function" and fileName:find("/") then
        pcall(makefolder, "DKHUB_Eggs")
    end
    local body = httpGet(url)
    if not body then return nil end
    local ok = pcall(writefile, fileName, body)
    return ok and fileName or nil
end

local function imageForEgg(name)
    local safe = tostring(name or "Egg"):gsub("[^%w%-]", "_")
    local fileName = "DKHUB_Eggs/" .. safe .. ".png"
    local localFile = ensureLocalAsset(fileName, RemoteBase .. fileName) or fileName
    return getAsset(localFile) or getAsset(safe .. ".png") or ""
end

local ActiveEggs = RS:WaitForChild("ServerData"):WaitForChild("ActiveEggs")

-- ห้าไข่ที่ไม่ให้โหมดออโต้ไปหา เพื่อลดเวลา
local AutoSkip = {
    ["White Egg"] = true,
    ["Brown Egg"] = true,
    ["Cracked Egg"] = true,
    ["Easter Egg"] = true,
    ["Stone Egg"] = true,
}
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

local function requestJson(url, payload)
    local body = HttpService:JSONEncode(payload)
    local req = request or http_request or (syn and syn.request)
    if type(req) ~= "function" then return false, "request ไม่พร้อมใช้งาน" end
    local ok, response = pcall(req, {
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = body,
    })
    if not ok then return false, tostring(response) end
    if response and response.StatusCode and response.StatusCode >= 300 then
        return false, "HTTP " .. tostring(response.StatusCode)
    end
    return true
end

local function imageUrlForEgg(name)
    local safe = tostring(name or "Egg"):gsub("[^%w%-]", "_")
    return RemoteBase .. "DKHUB_Eggs/" .. safe .. ".png"
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
local logoFile = ensureLocalAsset(Config.LogoFile, RemoteBase .. Config.LogoFile) or Config.LogoFile
local logoAsset = getAsset(logoFile)
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
main.Size = UDim2.fromOffset(430, 500)
main.Position = UDim2.new(0, 92, 0.5, -250)
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
header.Size = UDim2.new(1, 0, 0, 86)
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

local autoLabel = label(main, "ออโต้หาไข่  •  รอบละ 60 วินาที", 13, TEXT, Enum.Font.GothamBold)
autoLabel.Position = UDim2.fromOffset(14, 88)
autoLabel.Size = UDim2.new(1, -150, 0, 24)
local autoSwitch = Instance.new("TextButton")
autoSwitch.Size = UDim2.fromOffset(116, 38)
autoSwitch.Position = UDim2.new(1, -130, 0, 82)
autoSwitch.BackgroundColor3 = CARD
autoSwitch.Text = "ปิด"
autoSwitch.TextSize = 13
autoSwitch.TextColor3 = DIM
autoSwitch.Font = Enum.Font.GothamBold
autoSwitch.Parent = main
corner(autoSwitch, 9)

local webhookBox = Instance.new("TextBox")
webhookBox.Size = UDim2.new(1, -28, 0, 38)
webhookBox.Position = UDim2.fromOffset(14, 190)
webhookBox.BackgroundColor3 = CARD
webhookBox.PlaceholderText = "Webhook URL (ไม่ใส่ก็ได้)"
webhookBox.PlaceholderColor3 = DIM
webhookBox.Text = ""
webhookBox.TextColor3 = TEXT
webhookBox.TextSize = 11
webhookBox.Font = Enum.Font.Gotham
webhookBox.ClearTextOnFocus = false
webhookBox.TextXAlignment = Enum.TextXAlignment.Left
webhookBox.Parent = main
corner(webhookBox, 9)

local notifyTitle = label(main, "เลือกไข่ที่ต้องการให้แจ้งเตือน", 12, DIM)
notifyTitle.Position = UDim2.fromOffset(14, 238)
notifyTitle.Size = UDim2.new(1, -28, 0, 20)
local notifyFrame = Instance.new("ScrollingFrame")
notifyFrame.Position = UDim2.fromOffset(14, 262)
notifyFrame.Size = UDim2.new(1, -28, 0, 30)
notifyFrame.BackgroundTransparency = 1
notifyFrame.BorderSizePixel = 0
notifyFrame.ScrollBarThickness = 2
notifyFrame.AutomaticCanvasSize = Enum.AutomaticSize.X
notifyFrame.CanvasSize = UDim2.new()
notifyFrame.ScrollingDirection = Enum.ScrollingDirection.X
notifyFrame.Parent = main
local notifyLayout = Instance.new("UIListLayout")
notifyLayout.FillDirection = Enum.FillDirection.Horizontal
notifyLayout.Padding = UDim.new(0, 5)
notifyLayout.Parent = notifyFrame

-- v2.7: เมนูปุ่มฟังก์ชันแทนหน้าเลื่อนไข่
local functionButtonTitle = label(main, "FUNCTIONS", 11, DIM, Enum.Font.GothamBold)
functionButtonTitle.Position = UDim2.fromOffset(14, 122)
functionButtonTitle.Size = UDim2.new(1, -28, 0, 18)
local webhookToggle = Instance.new("TextButton")
webhookToggle.Size = UDim2.fromOffset(126, 38)
webhookToggle.Position = UDim2.fromOffset(14, 144)
webhookToggle.BackgroundColor3 = CARD
webhookToggle.Text = "WEBHOOK"
webhookToggle.TextSize = 12
webhookToggle.TextColor3 = TEXT
webhookToggle.Font = Enum.Font.GothamBold
webhookToggle.Parent = main
corner(webhookToggle, 8)
local notifyToggle = Instance.new("TextButton")
notifyToggle.Size = UDim2.fromOffset(170, 38)
notifyToggle.Position = UDim2.fromOffset(150, 144)
notifyToggle.BackgroundColor3 = CARD
notifyToggle.Text = "เลือกไข่แจ้งเตือน"
notifyToggle.TextSize = 12
notifyToggle.TextColor3 = TEXT
notifyToggle.Font = Enum.Font.GothamBold
notifyToggle.Parent = main
corner(notifyToggle, 8)
local refreshButton = Instance.new("TextButton")
refreshButton.Size = UDim2.fromOffset(92, 38)
refreshButton.Position = UDim2.fromOffset(330, 144)
refreshButton.BackgroundColor3 = ACCENT
refreshButton.Text = "รีเฟรช"
refreshButton.TextSize = 12
refreshButton.TextColor3 = TEXT
refreshButton.Font = Enum.Font.GothamBold
refreshButton.Parent = main
corner(refreshButton, 8)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(12, 300)
list.Size = UDim2.new(1, -24, 1, -345)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.ScrollBarImageColor3 = ACCENT
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = main
list.Visible = false
webhookBox.Visible = false
notifyTitle.Visible = false
notifyFrame.Visible = false
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local status = label(main, "พร้อมใช้งาน", 12, DIM)
status.Position = UDim2.new(0, 16, 1, -38)
status.Size = UDim2.new(1, -32, 0, 20)

local rows, busy = {}, false
local autoEnabled = false
local notifySelection = {}
local function setStatus(text, color)
    status.Text = text
    status.TextColor3 = color or DIM
end

local function warpToEgg(cfg, silent)
    if busy then if not silent then setStatus("กำลังทำงานอยู่ กรุณารอสักครู่", ACCENT2) end; return false end
    if not cfg or not cfg.Parent then return false end
    local root, pos = getRoot(), getPosition(cfg)
    if not root or not pos then if not silent then setStatus("ไม่พบตำแหน่งตัวละครหรือไข่", ACCENT2) end; return false end
    busy = true
    local oldBase = getBaseCFrame() or root.CFrame
    local name = tostring(cfg:GetAttribute("Egg") or cfg.Name or "Egg")
    if not silent then setStatus("กำลังไปที่ " .. name .. "...", ACCENT2) end
    local ok = pcall(function() root.CFrame = CFrame.new(pos + Vector3.new(0, Config.HeightOffset, 0)) end)
    if ok then task.wait(0.4) end
    local collected = false
    local prompt = findPrompt(pos)
    if prompt and type(fireproximityprompt) == "function" then
        if not silent then setStatus("กำลังเก็บ " .. name .. "...", GREEN) end
        local start = os.clock()
        repeat
            pcall(fireproximityprompt, prompt)
            task.wait(0.15)
            collected = not cfg.Parent
        until collected or os.clock() - start >= Config.PickupWait
    else
        if not silent then setStatus("ไม่พบ Pickup prompt — รอการเก็บ...", DIM) end
        task.wait(1)
        collected = not cfg.Parent
    end
    root = getRoot()
    if root then pcall(function() root.CFrame = oldBase end) end
    if not silent then setStatus("กลับฐานแล้ว: " .. name, GREEN) end
    busy = false
    task.delay(2.5, function() if not busy and not silent then setStatus("พร้อมใช้งาน", DIM) end end)
    return collected
end

local function makeRow(cfg, order, distance)
    local name = tostring(cfg:GetAttribute("Egg") or cfg.Name or "Egg")
    local row = Instance.new("Frame")
    row.Name = "EggRow"
    row.Size = UDim2.new(1, -4, 0, 70)
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

    local state = label(row, "AUTO", 10, ACCENT2, Enum.Font.GothamBold)
    state.Position = UDim2.new(1, -98, 0.5, -10)
    state.Size = UDim2.fromOffset(80, 20)
    state.TextXAlignment = Enum.TextXAlignment.Center
    rows[cfg] = row
end

local function sendWebhook(cfg)
    local name = tostring(cfg:GetAttribute("Egg") or cfg.Name or "Egg")
    if not notifySelection[name] then return end
    local url = tostring(webhookBox.Text or ""):gsub("%s+", "")
    if url == "" then return end
    local weight = tonumber(cfg:GetAttribute("Weight")) or 0
    local ok, err = requestJson(url, {
        username = "DKHUB Egg Alert",
        embeds = {{
            title = "ไข่ที่พบ",
            description = "**" .. name .. "**",
            color = 15158332,
            fields = {{name = "ชื่อไข่", value = name, inline = true}, {name = "น้ำหนัก", value = string.format("%.2f kg", weight), inline = true}},
            thumbnail = {url = imageUrlForEgg(name)},
            footer = {text = "DKHUB EggWarpUI v2.8"},
        }},
    })
    if not ok then setStatus("Webhook ล้มเหลว: " .. tostring(err), ACCENT2) end
end

local function buildNotifyButtons()
    for _, child in ipairs(notifyFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, name in ipairs(NotifyEggNames) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.fromOffset(108, 28)
        button.BackgroundColor3 = notifySelection[name] and GREEN or CARD
        button.Text = name:gsub(" Egg", "")
        button.TextSize = 11
        button.TextColor3 = TEXT
        button.Font = Enum.Font.GothamBold
        button.Parent = notifyFrame
        corner(button, 7)
        button.MouseButton1Click:Connect(function()
            notifySelection[name] = not notifySelection[name]
            button.BackgroundColor3 = notifySelection[name] and GREEN or CARD
        end)
    end
end

local function eligibleItems()
    local root = getRoot()
    local items = {}
    for _, cfg in ipairs(ActiveEggs:GetChildren()) do
        local name, pos = tostring(cfg:GetAttribute("Egg") or cfg.Name or "Egg"), getPosition(cfg)
        if pos and not AutoSkip[name] then
            table.insert(items, {cfg = cfg, distance = root and (root.Position - pos).Magnitude or 0})
        end
    end
    table.sort(items, function(a, b) return a.distance < b.distance end)
    return items
end

local function autoCycle()
    local started = os.clock()
    local items = eligibleItems()
    setStatus("ออโต้เริ่มรอบใหม่: " .. #items .. " ใบ", ACCENT2)
    for index, item in ipairs(items) do
        if not autoEnabled then break end
        setStatus(string.format("ออโต้: เก็บใบที่ %d/%d", index, #items), ACCENT2)
        if warpToEgg(item.cfg, true) then
            sendWebhook(item.cfg)
            task.wait(0.35)
        end
    end
    local waitTime = math.max(1, Config.AutoInterval - (os.clock() - started))
    if autoEnabled then setStatus(string.format("ออโต้รอบถัดไปใน %.0f วินาที", waitTime), GREEN); task.wait(waitTime) end
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
    sub.Text = string.format("พบไข่ที่ใช้งานอยู่ %d ใบ  •  ใช้เมนู FUNCTIONS", #items)
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

webhookToggle.MouseButton1Click:Connect(function()
    webhookBox.Visible = not webhookBox.Visible
    webhookToggle.BackgroundColor3 = webhookBox.Visible and ACCENT or CARD
end)
notifyToggle.MouseButton1Click:Connect(function()
    notifyTitle.Visible = not notifyTitle.Visible
    notifyFrame.Visible = notifyTitle.Visible
    notifyToggle.BackgroundColor3 = notifyTitle.Visible and ACCENT or CARD
end)
refreshButton.MouseButton1Click:Connect(function()
    refreshList()
    setStatus("รีเฟรชสถานะแล้ว", GREEN)
end)

autoSwitch.MouseButton1Click:Connect(function()
    autoEnabled = not autoEnabled
    autoSwitch.Text = autoEnabled and "เปิด" or "ปิด"
    autoSwitch.BackgroundColor3 = autoEnabled and GREEN or CARD
    autoSwitch.TextColor3 = autoEnabled and BG or DIM
    if autoEnabled then
        task.spawn(function()
            while autoEnabled do autoCycle() end
            setStatus("ออโต้หยุดแล้ว", DIM)
        end)
        setStatus("กำลังเริ่มออโต้...", ACCENT2)
    else
        setStatus("ออโต้หยุดแล้ว", DIM)
    end
end)

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

buildNotifyButtons()
refreshList()
print("[DKHUB EggWarpUI v2.8] Ready — toggle: " .. Config.ToggleKey.Name)
