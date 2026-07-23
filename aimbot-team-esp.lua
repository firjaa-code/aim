--[[
    AIM LOCK + ESP TEAM-BASED — LocalScript (Roblox)
    Fitur:
    - Aim Lock: Hanya menargetkan player dari TEAM LAIN (teammate di-ignore)
    - ESP: Highlight + Name Tag + Jarak + Health Bar untuk semua player
      - Musuh (beda team) = MERAH
      - Teammate (satu team) = HIJAU
    - Tracking langsung (no delay) ke player musuh terdekat, 360 derajat
    - Otomatis ganti target kalau target mati / kabur / ketutup wall / kejauhan / pindah team
    - Wall check pakai Raycast
    - Jarak deteksi bisa diatur lewat TextBox
    - UI: Toggle AimLock ON/OFF, Toggle ESP ON/OFF, Minimize, Close, Drag
    - Posisi default: top center
    Cara pakai: taruh script ini sebagai LocalScript di StarterPlayerScripts
--]]

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local Teams = game:GetService("Teams")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
end)

--// Settings (state)
local aimLockEnabled = false
local espEnabled = false
local maxDistance = 50
local lockedTarget = nil
local lockedHumanoid = nil
local lockedPlayer = nil

--// ESP Storage: menyimpan semua ESP object per player
local espObjects = {} -- [Player] = { highlight, billboard, nameLabel, distLabel, healthBarBg, healthBarFill }

--// Warna ESP
local ENEMY_COLOR = Color3.fromRGB(255, 50, 50)       -- merah untuk musuh
local ENEMY_FILL_COLOR = Color3.fromRGB(255, 80, 80)
local TEAMMATE_COLOR = Color3.fromRGB(50, 255, 100)    -- hijau untuk teammate
local TEAMMATE_FILL_COLOR = Color3.fromRGB(80, 255, 120)

--// ============================================================
--// Helper: Cek apakah player lain adalah musuh (beda team)
--// ============================================================
local function isEnemy(otherPlayer)
    if player.Team == nil then return true end
    if otherPlayer.Team == nil then return true end
    return player.Team ~= otherPlayer.Team
end

--// ============================================================
--// UI
--// ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AimLockESPUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 240, 0, 220)
mainFrame.Position = UDim2.new(0.5, -120, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -60, 1, 0)
titleLabel.Position = UDim2.new(0, 8, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "AimLock + ESP"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.Parent = titleBar

-- Minimize
local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 24, 0, 24)
minimizeButton.Position = UDim2.new(1, -58, 0, 3)
minimizeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
minimizeButton.Text = "-"
minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 18
minimizeButton.Parent = titleBar

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minimizeButton

-- Close
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 24, 0, 24)
closeButton.Position = UDim2.new(1, -28, 0, 3)
closeButton.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

-- Body
local bodyFrame = Instance.new("Frame")
bodyFrame.Name = "Body"
bodyFrame.Size = UDim2.new(1, 0, 1, -30)
bodyFrame.Position = UDim2.new(0, 0, 0, 30)
bodyFrame.BackgroundTransparency = 1
bodyFrame.Parent = mainFrame

-- Toggle Aim Lock ON/OFF
local toggleAimButton = Instance.new("TextButton")
toggleAimButton.Size = UDim2.new(1, -16, 0, 32)
toggleAimButton.Position = UDim2.new(0, 8, 0, 8)
toggleAimButton.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
toggleAimButton.Text = "AIM LOCK: OFF"
toggleAimButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleAimButton.Font = Enum.Font.GothamBold
toggleAimButton.TextSize = 14
toggleAimButton.Parent = bodyFrame

local toggleAimCorner = Instance.new("UICorner")
toggleAimCorner.CornerRadius = UDim.new(0, 6)
toggleAimCorner.Parent = toggleAimButton

-- Toggle ESP ON/OFF
local toggleESPButton = Instance.new("TextButton")
toggleESPButton.Size = UDim2.new(1, -16, 0, 32)
toggleESPButton.Position = UDim2.new(0, 8, 0, 48)
toggleESPButton.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
toggleESPButton.Text = "ESP: OFF"
toggleESPButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleESPButton.Font = Enum.Font.GothamBold
toggleESPButton.TextSize = 14
toggleESPButton.Parent = bodyFrame

local toggleESPCorner = Instance.new("UICorner")
toggleESPCorner.CornerRadius = UDim.new(0, 6)
toggleESPCorner.Parent = toggleESPButton

-- Label jarak
local distanceLbl = Instance.new("TextLabel")
distanceLbl.Size = UDim2.new(0, 90, 0, 28)
distanceLbl.Position = UDim2.new(0, 8, 0, 90)
distanceLbl.BackgroundTransparency = 1
distanceLbl.Text = "Jarak (studs):"
distanceLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
distanceLbl.Font = Enum.Font.Gotham
distanceLbl.TextSize = 13
distanceLbl.TextXAlignment = Enum.TextXAlignment.Left
distanceLbl.Parent = bodyFrame

-- Input jarak
local distanceBox = Instance.new("TextBox")
distanceBox.Size = UDim2.new(0, 110, 0, 28)
distanceBox.Position = UDim2.new(0, 110, 0, 90)
distanceBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
distanceBox.Text = tostring(maxDistance)
distanceBox.TextColor3 = Color3.fromRGB(255, 255, 255)
distanceBox.Font = Enum.Font.Gotham
distanceBox.TextSize = 14
distanceBox.ClearTextOnFocus = false
distanceBox.Parent = bodyFrame

local distCorner = Instance.new("UICorner")
distCorner.CornerRadius = UDim.new(0, 6)
distCorner.Parent = distanceBox

-- Status label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -16, 0, 60)
statusLabel.Position = UDim2.new(0, 8, 0, 126)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Target: Tidak ada\nESP: Mati"
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Parent = bodyFrame

--// ============================================================
--// Drag Logic
--// ============================================================
local dragging = false
local dragInput, dragStart, startPos

local function updateDrag(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateDrag(input)
    end
end)

--// ============================================================
--// Minimize & Close
--// ============================================================
local minimized = false
minimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    bodyFrame.Visible = not minimized
    mainFrame.Size = minimized and UDim2.new(0, 240, 0, 30) or UDim2.new(0, 240, 0, 220)
    minimizeButton.Text = minimized and "+" or "-"
end)

closeButton.MouseButton1Click:Connect(function()
    screenGui.Enabled = false
    aimLockEnabled = false
    espEnabled = false
    removeAllESP()
end)

--// ============================================================
--// Toggle Aim Lock
--// ============================================================
toggleAimButton.MouseButton1Click:Connect(function()
    aimLockEnabled = not aimLockEnabled
    toggleAimButton.Text = aimLockEnabled and "AIM LOCK: ON" or "AIM LOCK: OFF"
    toggleAimButton.BackgroundColor3 = aimLockEnabled and Color3.fromRGB(40, 150, 60) or Color3.fromRGB(150, 40, 40)

    if not aimLockEnabled then
        lockedTarget = nil
        lockedHumanoid = nil
        lockedPlayer = nil
    end
end)

--// ============================================================
--// ESP Functions
--// ============================================================

-- Hapus ESP dari satu player
local function removeESP(targetPlayer)
    local data = espObjects[targetPlayer]
    if data then
        if data.highlight and data.highlight.Parent then
            data.highlight:Destroy()
        end
        if data.billboard and data.billboard.Parent then
            data.billboard:Destroy()
        end
        espObjects[targetPlayer] = nil
    end
end

-- Hapus semua ESP
function removeAllESP()
    for targetPlayer, _ in pairs(espObjects) do
        removeESP(targetPlayer)
    end
    espObjects = {}
end

-- Buat ESP untuk satu player
local function createESP(targetPlayer)
    local targetChar = targetPlayer.Character
    if not targetChar then return end

    local targetHead = targetChar:FindFirstChild("Head")
    local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
    if not targetHead or not targetHumanoid then return end

    -- Tentukan warna berdasarkan team
    local enemy = isEnemy(targetPlayer)
    local outlineColor = enemy and ENEMY_COLOR or TEAMMATE_COLOR
    local fillColor = enemy and ENEMY_FILL_COLOR or TEAMMATE_FILL_COLOR

    -- === HIGHLIGHT (glow tembus wall) ===
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Highlight"
    highlight.Adornee = targetChar
    highlight.FillColor = fillColor
    highlight.FillTransparency = 0.7
    highlight.OutlineColor = outlineColor
    highlight.OutlineTransparency = 0.1
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = targetChar

    -- === BILLBOARD GUI (nama + jarak + health bar di atas kepala) ===
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Billboard"
    billboard.Adornee = targetHead
    billboard.Size = UDim2.new(0, 160, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.Parent = targetChar

    -- Nama player
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 16)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = targetPlayer.DisplayName
    nameLabel.TextColor3 = outlineColor
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextStrokeTransparency = 0.4
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Parent = billboard

    -- Jarak
    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1, 0, 0, 14)
    distLabel.Position = UDim2.new(0, 0, 0, 16)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = "[0 studs]"
    distLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = 11
    distLabel.TextStrokeTransparency = 0.5
    distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLabel.Parent = billboard

    -- Health bar background
    local healthBarBg = Instance.new("Frame")
    healthBarBg.Size = UDim2.new(0.7, 0, 0, 5)
    healthBarBg.Position = UDim2.new(0.15, 0, 0, 33)
    healthBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    healthBarBg.BorderSizePixel = 0
    healthBarBg.Parent = billboard

    local healthBgCorner = Instance.new("UICorner")
    healthBgCorner.CornerRadius = UDim.new(0, 3)
    healthBgCorner.Parent = healthBarBg

    -- Health bar fill
    local healthBarFill = Instance.new("Frame")
    healthBarFill.Size = UDim2.new(1, 0, 1, 0)
    healthBarFill.BackgroundColor3 = outlineColor
    healthBarFill.BorderSizePixel = 0
    healthBarFill.Parent = healthBarBg

    local healthFillCorner = Instance.new("UICorner")
    healthFillCorner.CornerRadius = UDim.new(0, 3)
    healthFillCorner.Parent = healthBarFill

    -- Simpan referensi
    espObjects[targetPlayer] = {
        highlight = highlight,
        billboard = billboard,
        nameLabel = nameLabel,
        distLabel = distLabel,
        healthBarBg = healthBarBg,
        healthBarFill = healthBarFill,
        isEnemy = enemy
    }
end

-- Update warna ESP jika team berubah
local function updateESPColor(targetPlayer, data)
    local enemy = isEnemy(targetPlayer)

    -- Kalau status team tidak berubah, skip
    if data.isEnemy == enemy then return end
    data.isEnemy = enemy

    local outlineColor = enemy and ENEMY_COLOR or TEAMMATE_COLOR
    local fillColor = enemy and ENEMY_FILL_COLOR or TEAMMATE_FILL_COLOR

    if data.highlight then
        data.highlight.OutlineColor = outlineColor
        data.highlight.FillColor = fillColor
    end
    if data.nameLabel then
        data.nameLabel.TextColor3 = outlineColor
    end
    if data.healthBarFill then
        data.healthBarFill.BackgroundColor3 = outlineColor
    end
end

-- Update jarak & health bar setiap frame
local function updateESPInfo()
    for targetPlayer, data in pairs(espObjects) do
        local targetChar = targetPlayer.Character
        if not targetChar then
            removeESP(targetPlayer)
            continue
        end

        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
        local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")

        if not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then
            removeESP(targetPlayer)
            continue
        end

        -- Update jarak
        if humanoidRootPart and data.distLabel then
            local dist = math.floor((targetRoot.Position - humanoidRootPart.Position).Magnitude + 0.5)
            data.distLabel.Text = "[" .. dist .. " studs]"
        end

        -- Update health bar
        if data.healthBarFill and targetHumanoid then
            local healthPercent = targetHumanoid.Health / targetHumanoid.MaxHealth
            data.healthBarFill.Size = UDim2.new(math.clamp(healthPercent, 0, 1), 0, 1, 0)

            -- Warna health bar: hijau -> kuning -> merah berdasarkan HP
            if healthPercent > 0.5 then
                data.healthBarFill.BackgroundColor3 = Color3.fromRGB(
                    math.floor(255 * (1 - healthPercent) * 2),
                    255,
                    50
                )
            else
                data.healthBarFill.BackgroundColor3 = Color3.fromRGB(
                    255,
                    math.floor(255 * healthPercent * 2),
                    50
                )
            end
        end

        -- Update warna jika team berubah
        updateESPColor(targetPlayer, data)
    end
end

--// ============================================================
--// Toggle ESP
--// ============================================================
toggleESPButton.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    toggleESPButton.Text = espEnabled and "ESP: ON" or "ESP: OFF"
    toggleESPButton.BackgroundColor3 = espEnabled and Color3.fromRGB(40, 150, 60) or Color3.fromRGB(150, 40, 40)

    if not espEnabled then
        removeAllESP()
    end
end)

--// ============================================================
--// ESP: Auto-setup saat player join/leave/respawn
--// ============================================================
local function setupPlayerESP(targetPlayer)
    if targetPlayer == player then return end

    -- Buat ESP saat karakter muncul
    local function onCharacterAdded(char)
        -- Tunggu model loaded
        task.wait(0.5)
        if espEnabled then
            removeESP(targetPlayer) -- hapus ESP lama kalau ada
            createESP(targetPlayer)
        end
    end

    -- Hapus ESP saat karakter hilang
    local function onCharacterRemoving()
        removeESP(targetPlayer)
    end

    targetPlayer.CharacterAdded:Connect(onCharacterAdded)
    targetPlayer.CharacterRemoving:Connect(onCharacterRemoving)

    -- Kalau karakter sudah ada sekarang
    if targetPlayer.Character then
        onCharacterAdded(targetPlayer.Character)
    end
end

-- Setup untuk semua player yang sudah ada
for _, p in pairs(Players:GetPlayers()) do
    setupPlayerESP(p)
end

-- Setup untuk player yang baru join
Players.PlayerAdded:Connect(function(p)
    setupPlayerESP(p)
end)

-- Cleanup saat player leave
Players.PlayerRemoving:Connect(function(p)
    removeESP(p)
end)

-- Update jarak dari input teks
distanceBox.FocusLost:Connect(function()
    local num = tonumber(distanceBox.Text)
    if num and num > 0 then
        maxDistance = num
    else
        distanceBox.Text = tostring(maxDistance)
    end
end)

--// ============================================================
--// Wall Check (raycast)
--// ============================================================
local function hasClearLineOfSight(fromPos, toPos, ignoreList)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = ignoreList
    rayParams.IgnoreWater = true

    local direction = toPos - fromPos
    local result = Workspace:Raycast(fromPos, direction, rayParams)

    if result then
        local hitDistance = (result.Position - fromPos).Magnitude
        local targetDistance = direction.Magnitude
        if hitDistance < targetDistance - 1 then
            return false
        end
    end

    return true
end

--// ============================================================
--// Cari PLAYER MUSUH (beda team) terdekat yang valid
--// ============================================================
local function findNearestEnemy()
    local nearest = nil
    local nearestHumanoid = nil
    local nearestPlayer = nil
    local shortestDistance = maxDistance

    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player and isEnemy(otherPlayer) then
            local otherCharacter = otherPlayer.Character
            if otherCharacter then
                local humanoid = otherCharacter:FindFirstChildOfClass("Humanoid")
                local root = otherCharacter:FindFirstChild("HumanoidRootPart")

                if humanoid and root and humanoid.Health > 0 then
                    local distance = (root.Position - humanoidRootPart.Position).Magnitude

                    if distance <= shortestDistance then
                        local clear = hasClearLineOfSight(
                            camera.CFrame.Position,
                            root.Position,
                            {character, otherCharacter, camera}
                        )

                        if clear then
                            shortestDistance = distance
                            nearest = otherCharacter
                            nearestHumanoid = humanoid
                            nearestPlayer = otherPlayer
                        end
                    end
                end
            end
        end
    end

    return nearest, nearestHumanoid, nearestPlayer
end

--// ============================================================
--// Main Loop — jalan tiap frame
--// ============================================================
RunService.RenderStepped:Connect(function()
    -- === ESP Update (berjalan independen dari aim lock) ===
    if espEnabled then
        -- Buat ESP untuk player yang belum punya
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player and not espObjects[otherPlayer] then
                if otherPlayer.Character then
                    local hum = otherPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        createESP(otherPlayer)
                    end
                end
            end
        end
        -- Update info (jarak, health, warna team)
        updateESPInfo()
    end

    -- === AIM LOCK ===
    if not aimLockEnabled then
        -- Update status text (ESP-only mode)
        local espStatus = espEnabled and "ESP: Aktif" or "ESP: Mati"
        if not aimLockEnabled then
            statusLabel.Text = "Target: -\n" .. espStatus
            statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
        return
    end

    local targetStillValid = false

    if lockedTarget and lockedHumanoid and lockedPlayer then
        if isEnemy(lockedPlayer) then
            local root = lockedTarget:FindFirstChild("HumanoidRootPart")
            if root and lockedHumanoid.Health > 0 then
                local distance = (root.Position - humanoidRootPart.Position).Magnitude
                if distance <= maxDistance then
                    targetStillValid = hasClearLineOfSight(camera.CFrame.Position, root.Position, {character, lockedTarget, camera})
                end
            end
        end
    end

    if not targetStillValid then
        lockedTarget, lockedHumanoid, lockedPlayer = findNearestEnemy()
    end

    -- Kunci kamera ke target
    local espStatus = espEnabled and "ESP: Aktif" or "ESP: Mati"
    if lockedTarget and lockedPlayer then
        local root = lockedTarget:FindFirstChild("HumanoidRootPart")
        if root then
            local camPos = camera.CFrame.Position
            camera.CFrame = CFrame.new(camPos, root.Position)

            local teamName = lockedPlayer.Team and lockedPlayer.Team.Name or "No Team"
            local teamColor = lockedPlayer.Team and lockedPlayer.Team.TeamColor.Color or Color3.fromRGB(200, 200, 200)
            local dist = math.floor((root.Position - humanoidRootPart.Position).Magnitude + 0.5)
            statusLabel.Text = "Target: " .. lockedPlayer.DisplayName .. " [" .. dist .. "m]\nTeam: " .. teamName .. "\n" .. espStatus
            statusLabel.TextColor3 = teamColor
        end
    else
        statusLabel.Text = "Target: Tidak ada\n" .. espStatus
        statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    end
end)
