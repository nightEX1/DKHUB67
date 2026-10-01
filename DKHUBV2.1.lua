--[[
    EggWarpUI — รายชื่อไข่ที่ spawn ในแมพตอนนี้ + ปุ่มวาร์ป (ไปที่ไข่ -> เก็บ -> วาร์ปกลับฐาน)
    อ้างอิงจาก dump:
      - ไข่ที่ active: ReplicatedStorage.ServerData.ActiveEggs (Configuration ต่อไข่ 1 ใบ)
          Attributes: Egg (ชื่อ), Position (Vector3), Weight, Cycle, Elevated
      - โมเดลไข่ที่ render: Workspace.RenderedEggs (มี ProximityPrompt ชื่อ "Pickup")
      - ฐานของเรา: Workspace.Plots.<Plot> ที่ Owner(ObjectValue).Value == LocalPlayer, มี Baseplate
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------
local Config = {
    ToggleKey = Enum.KeyCode.RightShift,
    PickupWait = 4,        -- วินาทีสูงสุดที่รอให้เก็บไข่สำเร็จก่อนกลับฐาน
    PickupRange = 25,      -- ระยะหา Pickup prompt รอบตำแหน่งไข่
    HeightOffset = 3,      -- ยกตัวเหนือพื้นตอนวาร์ป
    ReturnOffset = Vector3.new(0, 5, 0),
}

---------------------------------------------------------------------
-- DATA
---------------------------------------------------------------------
local ActiveEggs = RS:WaitForChild("ServerData"):WaitForChild("ActiveEggs")

local function getRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getBaseCFrame()
    local plots = workspace:FindFirstChild("Plots")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            local owner = plot:FindFirstChild("Owner")
            if owner and owner:IsA("ObjectValue") and owner.Value == LocalPlayer then
                local bp = plot:FindFirstChild("Baseplate")
                if bp then return bp.CFrame + Config.ReturnOffset end
                return plot:GetPivot() + Config.ReturnOffset
            end
        end
    end
    return nil
end

local function findPrompt(pos)
    local rendered = workspace:FindFirstChild("RenderedEggs")
    if not rendered then return nil end
    local best, bestD = nil, Config.PickupRange
    for _, m in ipairs(rendered:GetChildren()) do
        local ok, pivot = pcall(function() return m:GetPivot() end)
        if ok then
            local d = (pivot.Position - pos).Magnitude
            if d < bestD then
                local pp = m:FindFirstChild("Pickup", true)
                if pp and pp:IsA("ProximityPrompt") then best, bestD = pp, d end
            end
        end
    end
    return best
end

---------------------------------------------------------------------
-- WARP
---------------------------------------------------------------------
local busy = false
local statusLabel -- ตั้งค่าตอนสร้าง UI

local function setStatus(t)
    if statusLabel then statusLabel.Text = t end
end

local function warpToEgg(cfg)
    if busy then return end
    local root = getRoot()
    if not root then return end
    busy = true

    local pos = cfg:GetAttribute("Position")
    if typeof(pos) ~= "Vector3" then busy = false return end

    local base = getBaseCFrame() or root.CFrame -- ถ้าหาฐานไม่เจอ ใช้จุดที่ยืนอยู่
    local name = cfg:GetAttribute("Egg") or "Egg"

    setStatus("ไปที่ " .. name .. "...")
    root.CFrame = CFrame.new(pos + Vector3.new(0, Config.HeightOffset, 0))
    task.wait(0.35)

    -- พยายามเก็บไข่ผ่าน prompt (ต้องมี fireproximityprompt จาก executor)
    local prompt = findPrompt(pos)
    if prompt and fireproximityprompt then
        setStatus("เก็บไข่...")
        local t0 = os.clock()
        while cfg.Parent and os.clock() - t0 < Config.PickupWait do
            pcall(fireproximityprompt, prompt)
            task.wait(0.15)
        end
    else
        task.wait(1) -- ไม่มี prompt/ฟังก์ชัน: รอสั้น ๆ ให้เก็บเอง
    end

    root = getRoot()
    if root then
        root.CFrame = base
        setStatus("กลับฐานแล้ว")
    end
    task.delay(2, function() setStatus("") end)
    busy = false
end

---------------------------------------------------------------------
-- UI
---------------------------------------------------------------------
local parent = (gethui and gethui()) or game:GetService("CoreGui")
pcall(function()
    local old = parent:FindFirstChild("EggWarpUI")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "EggWarpUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parent

local function corner(o, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = o end
local function stroke(o, col, th) local s = Instance.new("UIStroke") s.Color = col s.Thickness = th s.Transparency = 0.3 s.Parent = o end

local BG = Color3.fromRGB(22, 24, 32)
local PANEL = Color3.fromRGB(32, 35, 46)
local ACCENT = Color3.fromRGB(99, 130, 255)
local TEXT = Color3.fromRGB(235, 238, 250)
local DIM = Color3.fromRGB(150, 156, 180)

-- ลากได้
local function draggable(handle, target)
    local dragging, startPos, startInput
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, startInput = true, target.Position, i.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- ไอคอนเปิด/ปิด
local icon = Instance.new("TextButton")
icon.Name = "Icon"
icon.Size = UDim2.fromOffset(48, 48)
icon.Position = UDim2.new(0, 16, 0.5, -24)
icon.BackgroundColor3 = ACCENT
icon.Text = "🥚"
icon.TextSize = 26
icon.AutoButtonColor = false
icon.Parent = gui
corner(icon, 24)
stroke(icon, Color3.new(1, 1, 1), 1.5)
draggable(icon, icon)

-- หน้าต่างหลัก
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(320, 400)
main.Position = UDim2.new(0, 76, 0.5, -200)
main.BackgroundColor3 = BG
main.BackgroundTransparency = 1
main.Visible = false
main.ClipsDescendants = true
main.Parent = gui
corner(main, 14)
stroke(main, ACCENT, 1.5)

local scale = Instance.new("UIScale")
scale.Scale = 0.9
scale.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 52)
header.BackgroundColor3 = PANEL
header.BorderSizePixel = 0
header.Parent = main
draggable(header, main)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(14, 6)
title.Size = UDim2.new(1, -60, 0, 24)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.TextColor3 = TEXT
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = string.format("%s [%s]", LocalPlayer.DisplayName, LocalPlayer.Name)
title.Parent = header

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.Position = UDim2.fromOffset(14, 29)
sub.Size = UDim2.new(1, -60, 0, 16)
sub.Font = Enum.Font.Gotham
sub.TextSize = 12
sub.TextColor3 = DIM
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.Text = "ไข่ในแมพ: 0"
sub.Parent = header

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(28, 28)
close.Position = UDim2.new(1, -38, 0, 12)
close.BackgroundColor3 = BG
close.Text = "✕"
close.Font = Enum.Font.GothamBold
close.TextSize = 14
close.TextColor3 = DIM
close.AutoButtonColor = true
close.Parent = header
corner(close, 8)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(10, 60)
list.Size = UDim2.new(1, -20, 1, -96)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 3
list.ScrollBarImageColor3 = ACCENT
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.new(0, 14, 1, -28)
statusLabel.Size = UDim2.new(1, -28, 0, 20)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextColor3 = ACCENT
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = ""
statusLabel.Parent = main

---------------------------------------------------------------------
-- เปิด/ปิดแบบสมูท
---------------------------------------------------------------------
local isOpen = false
local info = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function setOpen(v)
    isOpen = v
    if v then
        main.Visible = true
        TweenService:Create(main, info, { BackgroundTransparency = 0.02 }):Play()
        TweenService:Create(scale, info, { Scale = 1 }):Play()
    else
        TweenService:Create(main, info, { BackgroundTransparency = 1 }):Play()
        local t = TweenService:Create(scale, info, { Scale = 0.9 })
        t:Play()
        t.Completed:Connect(function() if not isOpen then main.Visible = false end end)
    end
    TweenService:Create(icon, info, { BackgroundColor3 = v and Color3.fromRGB(70, 200, 130) or ACCENT }):Play()
end

icon.MouseButton1Click:Connect(function() setOpen(not isOpen) end)
close.MouseButton1Click:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(i, gpe)
    if not gpe and i.KeyCode == Config.ToggleKey then setOpen(not isOpen) end
end)

---------------------------------------------------------------------
-- รายการไข่
---------------------------------------------------------------------
local rows = {} -- [Configuration] = Frame

local function makeRow(cfg)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, 50)
    row.BackgroundColor3 = PANEL
    row.BorderSizePixel = 0
    corner(row, 10)

    local nameL = Instance.new("TextLabel")
    nameL.Name = "Name"
    nameL.BackgroundTransparency = 1
    nameL.Position = UDim2.fromOffset(12, 6)
    nameL.Size = UDim2.new(1, -90, 0, 20)
    nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 14
    nameL.TextColor3 = TEXT
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.TextTruncate = Enum.TextTruncate.AtEnd
    nameL.Parent = row

    local detail = Instance.new("TextLabel")
    detail.Name = "Detail"
    detail.BackgroundTransparency = 1
    detail.Position = UDim2.fromOffset(12, 27)
    detail.Size = UDim2.new(1, -90, 0, 16)
    detail.Font = Enum.Font.Gotham
    detail.TextSize = 12
    detail.TextColor3 = DIM
    detail.TextXAlignment = Enum.TextXAlignment.Left
    detail.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(66, 30)
    btn.Position = UDim2.new(1, -76, 0.5, -15)
    btn.BackgroundColor3 = ACCENT
    btn.Text = "วาร์ป"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.AutoButtonColor = true
    btn.Parent = row
    corner(btn, 8)

    btn.MouseButton1Click:Connect(function()
        task.spawn(warpToEgg, cfg)
    end)

    row.Parent = list
    return row
end

local function refresh()
    local items = {}
    local root = getRoot()
    for _, cfg in ipairs(ActiveEggs:GetChildren()) do
        local pos = cfg:GetAttribute("Position")
        if typeof(pos) == "Vector3" then
            table.insert(items, {
                cfg = cfg,
                dist = root and (root.Position - pos).Magnitude or 0,
            })
        end
    end
    table.sort(items, function(a, b) return a.dist < b.dist end)

    local alive = {}
    for i, it in ipairs(items) do
        local cfg = it.cfg
        alive[cfg] = true
        local row = rows[cfg] or makeRow(cfg)
        rows[cfg] = row
        row.LayoutOrder = i
        row.Name.Text = string.format("%d. %s", i, tostring(cfg:GetAttribute("Egg") or cfg.Name))
        row.Detail.Text = string.format("%.2f kg  •  %d studs", cfg:GetAttribute("Weight") or 0, it.dist)
    end
    for cfg, row in pairs(rows) do
        if not alive[cfg] then row:Destroy() rows[cfg] = nil end
    end
    sub.Text = "ไข่ในแมพ: " .. #items
end

ActiveEggs.ChildAdded:Connect(function() task.wait(0.1) refresh() end)
ActiveEggs.ChildRemoved:Connect(refresh)

local acc = 0
RunService.Heartbeat:Connect(function(dt)
    if not isOpen then return end
    acc += dt
    if acc >= 0.5 then acc = 0 refresh() end
end)

refresh()
print("[EggWarpUI] พร้อมใช้งาน — กดไอคอน 🥚 หรือ " .. Config.ToggleKey.Name)
