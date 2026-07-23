--[[
    AIM LOCK KE PLAYER LAIN — LocalScript (Roblox)
    Fitur:
    - Tracking langsung (no delay) ke Player terdekat, 360 derajat
    - Otomatis ganti target kalau target sekarang mati / kabur / ketutup wall / kejauhan
    - Wall check pakai Raycast
    - Jarak deteksi bisa diatur lewat TextBox
    - UI: Toggle ON/OFF, Minimize, Close, dan bisa di-drag
    - Posisi default: top center
    Cara pakai: taruh script ini sebagai LocalScript di StarterPlayerScripts
--]]

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

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
local maxDistance = 50
local lockedTarget = nil
local lockedHumanoid = nil

--// ============================================================
--// UI
--// ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AimLockUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 220, 0, 150)
mainFrame.Position = UDim2.new(0.5, -110, 0, 10) -- top center (default)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

-- Title bar (buat drag)
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
titleLabel.Text = "Aim Lock"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.Parent = titleBar

-- Tombol minimize
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

-- Tombol close
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

-- Body content (disembunyikan saat minimize)
local bodyFrame = Instance.new("Frame")
bodyFrame.Name = "Body"
bodyFrame.Size = UDim2.new(1, 0, 1, -30)
bodyFrame.Position = UDim2.new(0, 0, 0, 30)
bodyFrame.BackgroundTransparency = 1
bodyFrame.Parent = mainFrame

-- Toggle button ON/OFF
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(1, -16, 0, 36)
toggleButton.Position = UDim2.new(0, 8, 0, 8)
toggleButton.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
toggleButton.Text = "AIM LOCK: OFF"
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 16
toggleButton.Parent = bodyFrame

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 6)
toggleCorner.Parent = toggleButton

-- Label jarak
local distanceLabel = Instance.new("TextLabel")
distanceLabel.Size = UDim2.new(0, 90, 0, 30)
distanceLabel.Position = UDim2.new(0, 8, 0, 54)
distanceLabel.BackgroundTransparency = 1
distanceLabel.Text = "Jarak (studs):"
distanceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
distanceLabel.Font = Enum.Font.Gotham
distanceLabel.TextSize = 13
distanceLabel.TextXAlignment = Enum.TextXAlignment.Left
distanceLabel.Parent = bodyFrame

-- Input jarak (TextBox, sesuai request: ketikan bukan slider)
local distanceBox = Instance.new("TextBox")
distanceBox.Size = UDim2.new(0, 100, 0, 30)
distanceBox.Position = UDim2.new(0, 110, 0, 54)
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

-- Status label (target aktif sekarang)
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -16, 0, 40)
statusLabel.Position = UDim2.new(0, 8, 0, 92)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Target: Tidak ada"
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Parent = bodyFrame

--// ============================================================
--// Drag Logic (UI bisa dipindah)
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
    mainFrame.Size = minimized and UDim2.new(0, 220, 0, 30) or UDim2.new(0, 220, 0, 150)
    minimizeButton.Text = minimized and "+" or "-"
end)

closeButton.MouseButton1Click:Connect(function()
    screenGui.Enabled = false
    aimLockEnabled = false -- otomatis matikan fitur saat UI ditutup
end)

--// ============================================================
--// Toggle Aim Lock
--// ============================================================
toggleButton.MouseButton1Click:Connect(function()
    aimLockEnabled = not aimLockEnabled
    toggleButton.Text = aimLockEnabled and "AIM LOCK: ON" or "AIM LOCK: OFF"
    toggleButton.BackgroundColor3 = aimLockEnabled and Color3.fromRGB(40, 150, 60) or Color3.fromRGB(150, 40, 40)

    if not aimLockEnabled then
        lockedTarget = nil
        lockedHumanoid = nil
        statusLabel.Text = "Target: Tidak ada"
    end
end)

-- Update jarak dari input teks
distanceBox.FocusLost:Connect(function()
    local num = tonumber(distanceBox.Text)
    if num and num > 0 then
        maxDistance = num
    else
        distanceBox.Text = tostring(maxDistance) -- reset kalau input tidak valid
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
            return false -- ada penghalang sebelum sampai target
        end
    end

    return true
end

--// ============================================================
--// Cari PLAYER LAIN terdekat yang valid (dalam jarak, tidak ketutup wall)
--// ============================================================
local function findNearestValidPlayer()
    local nearest = nil
    local nearestHumanoid = nil
    local shortestDistance = maxDistance

    for _, otherPlayer in pairs(Players:GetPlayers()) do
        -- Lewati diri sendiri
        if otherPlayer ~= player then
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
                        end
                    end
                end
            end
        end
    end

    return nearest, nearestHumanoid
end

--// ============================================================
--// Main Loop — jalan tiap frame
--// ============================================================
RunService.RenderStepped:Connect(function()
    if not aimLockEnabled then return end

    local targetStillValid = false

    if lockedTarget and lockedHumanoid then
        local root = lockedTarget:FindFirstChild("HumanoidRootPart")
        if root and lockedHumanoid.Health > 0 then
            local distance = (root.Position - humanoidRootPart.Position).Magnitude
            if distance <= maxDistance then
                targetStillValid = hasClearLineOfSight(camera.CFrame.Position, root.Position, {character, lockedTarget, camera})
            end
        end
    end

    -- Kalau target lama sudah mati / kabur / ketutup wall / kejauhan -> ganti target
    if not targetStillValid then
        lockedTarget, lockedHumanoid = findNearestValidPlayer()
    end

    -- Kunci kamera ke target (instan, tanpa lerp, bisa 360 derajat termasuk ke belakang)
    if lockedTarget then
        local root = lockedTarget:FindFirstChild("HumanoidRootPart")
        if root then
            local camPos = camera.CFrame.Position
            camera.CFrame = CFrame.new(camPos, root.Position)

            -- Tampilkan nama player (DisplayName) di status
            local targetPlayer = Players:GetPlayerFromCharacter(lockedTarget)
            if targetPlayer then
                statusLabel.Text = "Target: " .. targetPlayer.DisplayName .. " (@" .. targetPlayer.Name .. ")"
            else
                statusLabel.Text = "Target: " .. lockedTarget.Name
            end
        end
    else
        statusLabel.Text = "Target: Tidak ada"
    end
end)
