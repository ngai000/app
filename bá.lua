-- ============================================================
-- LocalScript: Kaitun Supper (Automated Suite - Upgraded)
-- Chức năng: Tự động chạy tất cả tính năng ngầm + GUI Theo dõi góc trái
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
local Mouse = LocalPlayer:GetMouse()

local RespawnRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestLoadSelfAsyncE")

-- ===================== CẤU HÌNH (TẤT CẢ LÀ TRUE) =============================
local CONFIG = {
    Radius = 8,                  
    Speed = 3,                   
    Height = 5,                  
    
    -- Khóa cứng trạng thái tự động hoạt động
    AimbotEnabled = true,
    SilentAimEnabled = true,
    TriggerbotEnabled = true,
    AutoRespawn = true,
    AutoHop = true,             
    RemoteSpamEnabled = true,   
    
    AimbotFOV = 200,             
    AimPart = "Head",

    -- [NÂNG CẤP]: Cấu hình giới hạn Hop Server
    MinPlayersToHop = 3,         -- Đổi server nếu ít hơn 3 người
    MaxKillsToHop = 500,         -- Đổi server nếu đạt 500 Kills

    -- [NÂNG CẤP]: Danh sách đồng đội cần né (Nhập Username hoặc UserID dạng chuỗi/số)
    WhitelistUsers = {
        "DongDoi1",
        "DongDoi2",
        123456789 -- Ví dụ UserID
    }
}

-- ===================== BIẾN TOÀN CỤC ========================
local isRunning = true           -- Luôn chạy Orbit
local targetPlayer = nil         
local currentAngle = 0           
local character = nil            
local rootPart = nil             
local targetRootPart = nil       

local renderConnection = nil     
local characterAddedConn = nil   
local customKillCount = 0        

-- Biến lưu trữ UI để cập nhật dữ liệu
local killLabel, fpsLabel, pingLabel, playersLabel

-- Biến tính toán FPS
local fpsFrameCount = 0
local fpsElapsedTime = 0

-- ===================== LUỒNG CHẠY NGẦM (SPAM & HOP) =====================

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

-- ===================== ANTI-AFK (NÂNG CẤP) =====================
task.spawn(function()
    local VirtualUser = game:GetService("VirtualUser")
    
    -- Cách 1: Gửi tín hiệu giả lập người dùng đang tương tác
    LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
    
    -- Cách 2: Tương tác vật lý mỗi 60 giây (Nhảy nhẹ)
    while task.wait(60) do
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            -- Giả lập nhấn nút nhảy để chống AFK
            local humanoid = LocalPlayer.Character.Humanoid
            humanoid.Jump = true
            
            -- Di chuyển nhẹ để không bị tính là đứng yên
            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                root.CFrame = root.CFrame * CFrame.new(0, 0, 0.1)
            end
        end
    end
end)


-- Tự động đổi server nếu ít hơn mốc chỉ định hoặc đạt điều kiện đặc biệt
local function hopServer()
    local success, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    
    if success and result and result.data then
        local validServers = {}
        for _, server in ipairs(result.data) do
            -- Tìm kiếm server có số lượng người chơi lý tưởng và không trùng server hiện tại
            if server.id ~= game.JobId and server.playing and server.playing > CONFIG.MinPlayersToHop and server.playing < server.maxPlayers then
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

-- [NÂNG CẤP]: Hàm kiểm tra xem có đồng đội trong Server hay không
local function isWhitelistPresent()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            for _, whitelisted in ipairs(CONFIG.WhitelistUsers) do
                if player.Name == whitelisted or player.UserId == whitelisted then
                    return true
                end
            end
        end
    end
    return false
end

task.spawn(function()
    while task.wait(5) do
        if CONFIG.AutoHop then
            -- Điều kiện 1: Số người chơi ít hơn giới hạn cấu hình
            local conditionPlayerCount = #Players:GetPlayers() < CONFIG.MinPlayersToHop
            
            -- Điều kiện 2: Đạt hoặc vượt quá số mạng hạ gục mục tiêu
            local conditionKillReached = customKillCount >= CONFIG.MaxKillsToHop
            
            -- Điều kiện 3: Có sự xuất hiện của user nằm trong danh sách cài đặt trước
            local conditionWhitelistDetected = isWhitelistPresent()

            if conditionPlayerCount or conditionKillReached or conditionWhitelistDetected then
                hopServer()
            end
        end
    end
end)

-- Luồng cập nhật thông số UI định kỳ mỗi giây (FPS, Ping, Người chơi)
task.spawn(function()
    while task.wait(1) do
        -- Cập nhật FPS
        if fpsLabel then
            fpsLabel.Text = "FPS: " .. tostring(fpsFrameCount)
        end
        fpsFrameCount = 0 -- Reset bộ đếm khung hình
        
        -- Cập nhật Ping (lấy dữ liệu thực từ Network)
        if pingLabel then
            local ping = math.round(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            pingLabel.Text = "PING: " .. tostring(ping) .. " ms"
        end
        
        -- Cập nhật số người trong server
        if playersLabel then
            playersLabel.Text = "PLAYERS: " .. tostring(#Players:GetPlayers())
        end
    end
end)

-- ===================== HÀM TRỢ NĂNG AIM & ORBIT =====================

-- [NÂNG CẤP]: Bổ sung kiểm tra whitelist vào hàm kiểm tra mục tiêu hợp lệ để tránh nhắm/bắn nhầm đồng đội
local function isPlayerValid(player)
    if not player then return false end
    if player == LocalPlayer then return false end
    
    -- Không nhắm vào đồng đội có trong danh sách cấu hình
    for _, whitelisted in ipairs(CONFIG.WhitelistUsers) do
        if player.Name == whitelisted or player.UserId == whitelisted then
            return false
        end
    end

    if not player.Character then return false end
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    return true
end

local function getClosestPlayerToCursor()
    if isRunning and targetPlayer and isPlayerValid(targetPlayer) then return targetPlayer end
    local closestPlayer = nil
    local shortestDistance = CONFIG.AimbotFOV

    for _, player in ipairs(Players:GetPlayers()) do
        if isPlayerValid(player) then
            local aimPart = player.Character:FindFirstChild(CONFIG.AimPart)
            if aimPart then
                local screenPos, onScreen = Camera:WorldToViewportPoint(aimPart.Position)
                if onScreen then
                    local mousePos = UserInputService:GetMouseLocation()
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if distance < shortestDistance then
                        closestPlayer = player
                        shortestDistance = distance
                    end
                end
            end
        end
    end
    return closestPlayer
end

-- Tự động kích hoạt Hook Silent Aim vĩnh viễn
local function initSilentAim()
    local gmt = getrawmetatable(game)
    if gmt then
        setreadonly(gmt, false)
        local oldNamecall = gmt.__index
        gmt.__index = newcclosure(function(self, key)
            if CONFIG.SilentAimEnabled and self == Mouse and (key == "Hit" or key == "Target") then
                local aimTarget = getClosestPlayerToCursor()
                if aimTarget and aimTarget.Character and aimTarget.Character:FindFirstChild(CONFIG.AimPart) then
                    local part = aimTarget.Character[CONFIG.AimPart]
                    if key == "Hit" then return part.CFrame end
                    if key == "Target" then return part end
                end
            end
            return oldNamecall(self, key)
        end)
        setreadonly(gmt, true)
    end
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
    
    if targetPlayer then
        targetRootPart = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetPlayer ~= oldTarget then
            customKillCount = customKillCount + 1
            if killLabel then killLabel.Text = "KILLS: " .. tostring(customKillCount) end
        end
    else
        targetRootPart = nil
    end
end

-- ===================== VÒNG LẶP CẬP NHẬT CHÍNH =====================

local function onRenderStep(dt)
    -- Tăng bộ đếm khung hình phục vụ tính toán FPS
    fpsFrameCount = fpsFrameCount + 1

    -- Orbit Logic
    if isRunning then
        if not character or not rootPart then
            character = LocalPlayer.Character
            if character then rootPart = character:FindFirstChild("HumanoidRootPart") end
        else
            if not targetPlayer or not isPlayerValid(targetPlayer) then selectNewTarget(false) end
            if targetPlayer and targetPlayer.Character then
                targetRootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetRootPart then
                    currentAngle = currentAngle + CONFIG.Speed * dt
                    local targetPos = targetRootPart.Position
                    local offset = Vector3.new(CONFIG.Radius * math.cos(currentAngle), CONFIG.Height, CONFIG.Radius * math.sin(currentAngle))
                    rootPart.CFrame = CFrame.lookAt(targetPos + offset, targetPos)
                end
            end
        end
    end

    -- Aim Logic
    local aimTarget = getClosestPlayerToCursor()
    if aimTarget and aimTarget.Character then
        local targetPart = aimTarget.Character:FindFirstChild(CONFIG.AimPart)
        if targetPart then
            if CONFIG.AimbotEnabled then
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPart.Position)
            end
            if CONFIG.TriggerbotEnabled and Mouse.Target and Mouse.Target:IsDescendantOf(aimTarget.Character) then
                mouse1click()
            end
        end
    end
end

-- ===================== QUẢN LÝ HỒI SINH =====================

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

    -- MainFrame nhỏ gọn đặt ở góc TRÁI TRÊN CÙNG màn hình
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 160, 0, 140)
    mainFrame.Position = UDim2.new(0, 10, 0, 10) -- Toạ độ góc trái trên cùng
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    mainFrame.BackgroundTransparency = 0.2
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = mainFrame

    -- Tiêu đề Kaitun Supper
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 25)
    title.BackgroundTransparency = 1
    title.Text = "KAITUN SUPPER"
    title.TextColor3 = Color3.fromRGB(0, 255, 127) -- Màu xanh lá dạ quang nổi bật
    title.TextSize = 14
    title.Font = Enum.Font.SourceSansBold
    title.Parent = mainFrame

    -- Hàm tạo nhãn hiển thị thông số nhanh
    local function createStatusLabel(name, defaultText, posY)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.Size = UDim2.new(1, -20, 0, 20)
        label.Position = UDim2.new(0, 10, 0, posY)
        label.BackgroundTransparency = 1
        label.Text = defaultText
        label.TextColor3 = Color3.fromRGB(240, 240, 240)
        label.TextXAlignment = Enum.TextXAlignment.Left -- Căn lề trái giống danh sách theo dõi
        label.TextSize = 13
        label.Font = Enum.Font.SourceSansSemibold
        label.Parent = mainFrame
        return label
    end

    -- Khởi tạo cấu trúc các dòng thông số hiển thị
    killLabel = createStatusLabel("KillLabel", "KILLS: 0", 30)
    fpsLabel = createStatusLabel("FpsLabel", "FPS: --", 55)
    pingLabel = createStatusLabel("PingLabel", "PING: -- ms", 80)
    playersLabel = createStatusLabel("PlayersLabel", "PLAYERS: --", 105)

    -- Đổi màu chữ riêng cho dòng mạng hạ gục để dễ nhìn lướt qua
    killLabel.TextColor3 = Color3.fromRGB(255, 215, 0) 

    return screenGui
end

-- ===================== KHỞI TẠO HỆ THỐNG MÃ NGUỒN ==============================

createGUI()
initSilentAim()

characterAddedConn = LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
end

renderConnection = RunService.RenderStepped:Connect(onRenderStep)
selectNewTarget(false)
