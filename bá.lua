-- ============================================================
-- LocalScript: Kaitun Supper (Automated Suite - Upgraded)
-- Chức năng: Tự động Orbit + Packet-Based Silent Aim & Auto Fire + GUI
-- Yêu cầu: Chạy trong LocalScript (StarterPlayerScripts hoặc PlayerGui)
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RespawnRemote = Remotes:WaitForChild("RequestLoadSelfAsyncE")
local GunRemote = Remotes:WaitForChild("GunRemote")

-- ===================== CẤU HÌNH (TẤT CẢ LÀ TRUE) =============================
local CONFIG = {
    Radius = 8,                  
    Speed = 6,                   
    Height = 5,                  
    
    AimbotEnabled = true,        -- Khóa cứng Camera vào mục tiêu
    SilentAimEnabled = true,     -- Kích hoạt Packet-Based Silent Aim qua Remote
    AutoFireEnabled = true,      -- Tự động xả đạn liên tục khi có mục tiêu
    AutoRespawn = true,
    AutoHop = true,             
    RemoteSpamEnabled = true,   
    
    AimPart = "Head",            -- Bộ phận nhắm mục tiêu
    FireRate = 0.1               -- Tốc độ xả đạn (giây), điều chỉnh tùy độ delay vũ khí
}

-- ===================== BIẾN TOÀN CỤC ========================
local isRunning = true           
local targetPlayer = nil         
local currentAngle = 0           
local character = nil            
local rootPart = nil             

local renderConnection = nil     
local characterAddedConn = nil   
local customKillCount = 0        

-- Biến lưu trữ UI để cập nhật dữ liệu
local killLabel, fpsLabel, pingLabel, playersLabel
local fpsFrameCount = 0

-- ===================== HÀM TRỢ NĂNG KIỂM TRA MỤC TIÊU =====================

local function isPlayerValid(player)
    if not player or player == LocalPlayer then return false end
    if not player.Character then return false end
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    return true
end

local function getValidPlayers()
    local valid = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if isPlayerValid(plr) then table.insert(valid, plr) end
    end
    return valid
end

local function getRandomTarget(excludePlayer)
    local valid = getValidPlayers()
    if #valid == 0 then return nil end
    if excludePlayer then
        local filtered = {}
        for _, plr in ipairs(valid) do
            if plr ~= excludePlayer then table.insert(filtered, plr) end
        end
        if #filtered == 0 then return nil end
        return filtered[math.random(1, #filtered)]
    else
        return valid[math.random(1, #valid)]
    end
end

local function selectNewTarget(forceDifferent)
    local oldTarget = targetPlayer
    if forceDifferent then targetPlayer = getRandomTarget(targetPlayer) else targetPlayer = getRandomTarget() end
    
    if targetPlayer and targetPlayer ~= oldTarget then
        customKillCount = customKillCount + 1
        if killLabel then killLabel.Text = "KILLS: " .. tostring(customKillCount) end
    end
end

-- Tìm vũ khí hiện tại nhân vật đang cầm (Tool trong Character)
local function getCurrentWeapon()
    if not character then return nil end
    for _, obj in ipairs(character:GetChildren()) do
        if obj:IsA("Tool") then
            return obj
        end
    end
    return nil
end

-- ===================== LUỒNG TỰ ĐỘNG BẮN VÀ SILENT AIM (PACKET) =====================

task.spawn(function()
    while true do
        task.wait(CONFIG.FireRate)
        
        if CONFIG.SilentAimEnabled and CONFIG.AutoFireEnabled and isPlayerValid(targetPlayer) then
            local currentWeapon = getCurrentWeapon()
            
            if currentWeapon and targetPlayer.Character then
                local targetPart = targetPlayer.Character:FindFirstChild(CONFIG.AimPart)
                
                if targetPart then
                    pcall(function()
                        -- Theo spec của cậu: Vị trí bắn ra cách đầu kẻ địch 5 đơn vị về phía trước mặt của đầu đó
                        local targetLookDirection = targetPart.CFrame.LookVector
                        local originPosition = targetPart.Position + (targetLookDirection * 5)
                        
                        -- Tính toán hướng bay từ vị trí xuất phát đến tâm mục tiêu
                        local directionVector = (targetPart.Position - originPosition).Unit
                        
                        -- Khởi tạo mảng Arguments đúng cấu trúc mã nguồn game
                        local args = {
                            [1] = 1,
                            [2] = currentWeapon,
                            [3] = originPosition,
                            [4] = directionVector,
                            [5] = targetPart
                        }
                        
                        -- Gửi gói tin khai hỏa trực tiếp lên Server độc lập với hướng Camera
                        GunRemote:FireServer(unpack(args))
                    end)
                end
            end
        end
    end
end)

-- ===================== CÁC LUỒNG CHẠY NGẦM KHÁC =====================

-- Spam Remote hồi sinh mỗi 2 giây
task.spawn(function()
    while true do
        task.wait(2)
        if CONFIG.RemoteSpamEnabled then
            pcall(function()
                RespawnRemote:FireServer(false)
            end)
        end
    end
end)

-- Tự động đổi server nếu ít hơn 5 người
local function hopServer()
    local success, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    
    if success and result and result.data then
        local validServers = {}
        for _, server in ipairs(result.data) do
            if server.id ~= game.JobId and server.playing and server.playing > 5 and server.playing < server.maxPlayers then
                table.insert(validServers, server.id)
            end
        end
        
        if #validServers > 0 then
            local targetServerId = validServers[math.random(1, #validServers)]
            TeleportService:TeleportToPlaceInstance(game.PlaceId, targetServerId, LocalPlayer)
            return
        end
    end
    TeleportService:TeleportAsync(game.PlaceId, {LocalPlayer})
end

task.spawn(function()
    while task.wait(5) do
        if CONFIG.AutoHop and #Players:GetPlayers() < 5 then
            hopServer()
        end
    end
end)

-- Luồng cập nhật thông số UI định kỳ mỗi giây
task.spawn(function()
    while task.wait(1) do
        if fpsLabel then fpsLabel.Text = "FPS: " .. tostring(fpsFrameCount) end
        fpsFrameCount = 0 
        
        if pingLabel then
            local ping = math.round(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            pingLabel.Text = "PING: " .. tostring(ping) .. " ms"
        end
        
        if playersLabel then playersLabel.Text = "PLAYERS: " .. tostring(#Players:GetPlayers()) end
    end
end)

-- ===================== VÒNG LẶP CẬP NHẬT KHUNG HÌNH (ORBIT & LOCK) =====================

local function onRenderStep(dt)
    fpsFrameCount = fpsFrameCount + 1

    -- Thuật toán Quỹ đạo (Orbit) xung quanh mục tiêu hiện tại
    if isRunning then
        if not character or not rootPart then
            character = LocalPlayer.Character
            if character then rootPart = character:FindFirstChild("HumanoidRootPart") end
        else
            if not targetPlayer or not isPlayerValid(targetPlayer) then selectNewTarget(false) end
            if targetPlayer and targetPlayer.Character then
                local targetRootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetRootPart then
                    currentAngle = currentAngle + CONFIG.Speed * dt
                    local targetPos = targetRootPart.Position
                    local offset = Vector3.new(CONFIG.Radius * math.cos(currentAngle), CONFIG.Height, CONFIG.Radius * math.sin(currentAngle))
                    rootPart.CFrame = CFrame.lookAt(targetPos + offset, targetPos)
                end
            end
        end
    end

    -- Khóa cứng góc nhìn Camera (Aimbot) phục vụ việc quan sát của cậu
    if CONFIG.AimbotEnabled and isPlayerValid(targetPlayer) and targetPlayer.Character then
        local targetPart = targetPlayer.Character:FindFirstChild(CONFIG.AimPart)
        if targetPart then
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPart.Position)
        end
    end
end

-- ===================== QUẢN LÝ XỬ LÝ NHÂN VẬT =====================

local function onCharacterAdded(newChar)
    character = newChar
    rootPart = newChar:WaitForChild("HumanoidRootPart")
    
    local humanoid = newChar:WaitForChild("Humanoid")
    humanoid.Died:Connect(function()
        if CONFIG.AutoRespawn then
            task.wait()
            RespawnRemote:FireServer(false)
        end
    end)
end

-- ===================== GUI DISPLAY INTERFACE =========================

local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KaitunSupperGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = PlayerGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 160, 0, 140)
    mainFrame.Position = UDim2.new(0, 10, 0, 10) 
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    mainFrame.BackgroundTransparency = 0.2
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 25)
    title.BackgroundTransparency = 1
    title.Text = "KAITUN SUPPER"
    title.TextColor3 = Color3.fromRGB(0, 255, 127) 
    title.TextSize = 14
    title.Font = Enum.Font.SourceSansBold
    title.Parent = mainFrame

    local function createStatusLabel(name, defaultText, posY)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.Size = UDim2.new(1, -20, 0, 20)
        label.Position = UDim2.new(0, 10, 0, posY)
        label.BackgroundTransparency = 1
        label.Text = defaultText
        label.TextColor3 = Color3.fromRGB(240, 240, 240)
        label.TextXAlignment = Enum.TextXAlignment.Left 
        label.TextSize = 13
        label.Font = Enum.Font.SourceSansSemibold
        label.Parent = mainFrame
        return label
    end

    killLabel = createStatusLabel("KillLabel", "KILLS: 0", 30)
    fpsLabel = createStatusLabel("FpsLabel", "FPS: --", 55)
    pingLabel = createStatusLabel("PingLabel", "PING: -- ms", 80)
    playersLabel = createStatusLabel("PlayersLabel", "PLAYERS: --", 105)

    killLabel.TextColor3 = Color3.fromRGB(255, 215, 0) 

    return screenGui
end

-- ===================== KHỞI TẠO HỆ THỐNG MÃ NGUỒN ==============================

createGUI()

characterAddedConn = LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
end

renderConnection = RunService.RenderStepped:Connect(onRenderStep)
selectNewTarget(false)
