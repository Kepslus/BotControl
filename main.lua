local function hashKey(input)
    local hash = 5381

    for i = 1, #input do
        local char = string.byte(input, i)
        hash = bit32.band(((hash * 32 + hash) + char), 0xFFFFFFFF) -- hash * 33 + char, keep 32-bit
    end

    return string.format("%08x", hash)
end

local function validateKeyAndRunScript()
    local hwid = game:GetService("RbxAnalyticsService"):GetClientId() -- Or your own HWID method
    local key = getgenv().key
    if not key then
        print("Key not set in getgenv().key")
        return
    end

    -- Send validation request using syn.request
    local response = request({
        Url = "http://localhost:3000/checkKey",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "Roblox"
        },
        Body = game:GetService("HttpService"):JSONEncode({
            key = key,
            hwid = hwid
        })
    })

    if response.StatusCode ~= 200 then
        print("Failed to validate key:", response.Body)
        return false
    end

    -- Parse the response
    local data = game:GetService("HttpService"):JSONDecode(response.Body)

    -- Generate our own hash for comparison
    local combinedKey = key .. "__" .. hwid
    local localHash = hashKey(combinedKey)

    -- Compare hashes
    if data.hash == localHash then
        print("Key is valid! Running script...")
        
        -- Place your script logic here
        local function runScript()
            local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TextChatService = game:GetService("TextChatService")

getgenv().ownerName = ""
getgenv().accountNames = {}

local orbitRadius = 12
local lowOrbitRadius = 8  
local currentPlayer = Players.LocalPlayer
local currentMode = "idle"
local ownerPlayer = nil
local targetPlayer = nil
local orbitSpeed = 1
local moveAroundSpeed = 3 
local moveAroundDistance = 8 

local whitelist = {[getgenv().ownerName] = true}  
local blacklist = {}

local function debugPrint(message)
    print("DEBUG [" .. currentPlayer.Name .. "]: " .. message)
end

local function findPlayerByName(name)
    name = name:lower()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower():find(name, 1, true) then
            return player
        end
    end
    return nil
end

local function findPlayerByNameOrDisplay(name, sender)
    if name:lower() == "myself" then
        return sender
    end
    name = name:lower()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower():find(name, 1, true) or (player.DisplayName and player.DisplayName:lower():find(name, 1, true)) then
            return player
        end
    end
    return nil
end

local function getActiveBots()
    local activeBots = {}
    for _, name in ipairs(getgenv().accountNames) do
        local player = Players:FindFirstChild(name)
        if player and player ~= ownerPlayer then
            table.insert(activeBots, player)
        end
    end
    return activeBots
end

local function getBotIndex()
    local activeBots = getActiveBots()
    for index, bot in ipairs(activeBots) do
        if bot == currentPlayer then
            return index
        end
    end
    return nil
end

local function calculateOrbitPosition(angle, targetPosition, botCount, botIndex, radius, heightOffset)
    local x = targetPosition.X + radius * math.cos(angle)
    local z = targetPosition.Z + radius * math.sin(angle)
    local y = targetPosition.Y + heightOffset
    return Vector3.new(x, y, z)
end

local function orbitMode(isLowOrbit)
    local botIndex = getBotIndex()
    if not botIndex then return end

    local radius = isLowOrbit and lowOrbitRadius or orbitRadius
    local heightOffset = isLowOrbit and 1 or 5

    debugPrint("Entering " .. (isLowOrbit and "low orbit" or "orbit") .. " mode around " .. targetPlayer.Name .. " with speed " .. orbitSpeed)

    local startTime = tick()

    while currentMode == (isLowOrbit and "loworbit" or "orbit") do
        local activeBots = getActiveBots()
        local botCount = #activeBots
        local angleOffset = (2 * math.pi / botCount) * (botIndex - 1)

        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and
           currentPlayer.Character and currentPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetPosition = targetPlayer.Character.HumanoidRootPart.Position
            local elapsedTime = tick() - startTime
            local angle = (elapsedTime * orbitSpeed * 2 * math.pi) + angleOffset

            local orbitPosition = Vector3.new(
                targetPosition.X + radius * math.cos(angle),
                targetPosition.Y + heightOffset,
                targetPosition.Z + radius * math.sin(angle)
            )

            currentPlayer.Character:SetPrimaryPartCFrame(CFrame.new(orbitPosition, targetPosition))
        else
            debugPrint("waiting for target or character to load")
            wait(1)
        end
        RunService.Heartbeat:Wait()
    end

    debugPrint("Exiting " .. (isLowOrbit and "low orbit" or "orbit") .. " mode")
end

local function followMode()
    local botIndex = getBotIndex()
    if not botIndex then return end

    debugPrint("Entering follow mode behind " .. targetPlayer.Name)
    while currentMode == "follow" do
        local offset = botIndex * 5 

        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and 
           currentPlayer.Character and currentPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetPosition = targetPlayer.Character.HumanoidRootPart.Position
            local targetLookVector = targetPlayer.Character.HumanoidRootPart.CFrame.LookVector
            local followPosition = targetPosition - (targetLookVector * offset)

            local direction = (followPosition - currentPlayer.Character.HumanoidRootPart.Position).Unit
            local distance = (followPosition - currentPlayer.Character.HumanoidRootPart.Position).Magnitude

            if distance > 1 then
                if currentPlayer.Character:FindFirstChild("Humanoid") then
                    currentPlayer.Character.Humanoid:MoveTo(followPosition)
                    currentPlayer.Character.Humanoid.MoveToFinished:Wait()
                end
            else

                currentPlayer.Character:SetPrimaryPartCFrame(CFrame.new(currentPlayer.Character.HumanoidRootPart.Position, 
                                                                       currentPlayer.Character.HumanoidRootPart.Position + targetLookVector))
            end
        else
            debugPrint("Waiting for target or character to load in follow mode")
            wait(1)
        end
        RunService.Heartbeat:Wait()
    end
    debugPrint("Exiting follow mode")
end

local function lineMode()
    local botIndex = getBotIndex()
    if not botIndex then return end

    debugPrint("Entering line mode behind " .. targetPlayer.Name)
    while currentMode == "line" do
        local offset = botIndex * 5 

        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and 
           currentPlayer.Character and currentPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetPosition = targetPlayer.Character.HumanoidRootPart.Position
            local targetLookVector = targetPlayer.Character.HumanoidRootPart.CFrame.LookVector
            local linePosition = targetPosition - (targetLookVector * offset)

            currentPlayer.Character:SetPrimaryPartCFrame(CFrame.new(linePosition, targetPosition))
        else
            debugPrint("Waiting for target or character to load in line mode")
            wait(1)
        end
        RunService.Heartbeat:Wait()
    end
    debugPrint("Exiting line mode")
end

local function shieldMode()
    local botIndex = getBotIndex()
    if not botIndex then return end

    debugPrint("Entering shield mode")
    while currentMode == "shield" do
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and 
           currentPlayer.Character and currentPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetPosition = targetPlayer.Character.HumanoidRootPart.Position
            local activeBots = getActiveBots()
            local botCount = #activeBots

            local baseWidth = math.ceil(math.sqrt(botCount))
            local level = math.floor((botIndex - 1) / (baseWidth * baseWidth))
            local indexInLevel = (botIndex - 1) % (baseWidth * baseWidth)
            local row = math.floor(indexInLevel / baseWidth)
            local col = indexInLevel % baseWidth

            local xOffset = (col - (baseWidth - 1) / 2) * 5
            local zOffset = (row - (baseWidth - 1) / 2) * 5
            local yOffset = level * 5

            local shieldPosition = targetPosition + Vector3.new(xOffset, yOffset, zOffset)

            currentPlayer.Character:SetPrimaryPartCFrame(CFrame.new(shieldPosition, targetPosition))
        else
            debugPrint("Waiting for target or character to load in shield mode")
            wait(1)
        end
        RunService.Heartbeat:Wait()
    end
    debugPrint("Exiting shield mode")
end

local function moveAroundMode()
    local botIndex = getBotIndex()
    if not botIndex then return end

    debugPrint("Entering movearound mode behind " .. targetPlayer.Name)
    local startTime = tick()
    while currentMode == "movearound" do
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and 
           currentPlayer.Character and currentPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetPosition = targetPlayer.Character.HumanoidRootPart.Position
            local targetLookVector = targetPlayer.Character.HumanoidRootPart.CFrame.LookVector
            local targetRightVector = targetPlayer.Character.HumanoidRootPart.CFrame.RightVector

            local baseOffset = -targetLookVector * (10 + botIndex * 2) 

            local elapsedTime = tick() - startTime
            local sideOffset = math.sin(elapsedTime * moveAroundSpeed) * moveAroundDistance * targetRightVector

            local finalPosition = targetPosition + baseOffset + sideOffset

            currentPlayer.Character:SetPrimaryPartCFrame(CFrame.new(finalPosition, targetPosition))
        else
            debugPrint("Waiting for target or character to load in movearound mode")
            wait(1)
        end
        RunService.Heartbeat:Wait()
    end
    debugPrint("Exiting movearound mode")
end

local function changeMode(newMode, newTarget, newSpeed)
    debugPrint("Changing mode from " .. currentMode .. " to " .. newMode)
    currentMode = newMode
    targetPlayer = newTarget
    orbitSpeed = newSpeed or orbitSpeed

    if currentMode == "orbit" then
        coroutine.wrap(function() orbitMode(false) end)()
    elseif currentMode == "loworbit" then
        coroutine.wrap(function() orbitMode(true) end)()
    elseif currentMode == "line" then
        coroutine.wrap(lineMode)()
    elseif currentMode == "shield" then
        coroutine.wrap(shieldMode)()
    elseif currentMode == "movearound" then
        coroutine.wrap(moveAroundMode)()
    elseif currentMode == "follow" then
        coroutine.wrap(followMode)()
    elseif currentMode == "idle" then
        if currentPlayer.Character and currentPlayer.Character:FindFirstChild("HumanoidRootPart") then
            currentPlayer.Character.HumanoidRootPart.Anchored = false
            if currentPlayer.Character:FindFirstChild("Humanoid") then
                currentPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end
end

local function rejoinGame()
    local jobId = game.JobId
    local placeId = game.PlaceId

    debugPrint("Attempting to rejoin. Place ID: " .. placeId .. ", Job ID: " .. jobId)

    local success, errorMessage = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, jobId, currentPlayer)
    end)

    if not success then
        debugPrint("Rejoin failed: " .. errorMessage)
    end
end

local function dieCommand()
    if currentPlayer.Character and currentPlayer.Character:FindFirstChild("Humanoid") then
        currentPlayer.Character.Humanoid.Health = 0
        debugPrint("Bot health set to 0")
    else
        debugPrint("Unable to set bot health to 0 - character or humanoid not found")
    end
end

local function whitelistPlayer(playerName)
    whitelist[playerName] = true
    blacklist[playerName] = nil
    print(playerName .. " has been whitelisted")
end

local function blacklistPlayer(playerName)
    blacklist[playerName] = true
    whitelist[playerName] = nil
    print(playerName .. " has been blacklisted")
end

local function isPlayerAllowed(player)
    return whitelist[player.Name] and not blacklist[player.Name]
end

local function sendChatMessage(message)
    if TextChatService then
        local channel = TextChatService.TextChannels.RBXGeneral
        if channel then
            channel:SendAsync(message)
            debugPrint("Sent message: " .. message)
        else
            debugPrint("RBXGeneral channel not found")
        end
    else
        debugPrint("TextChatService not available")
    end
end

local function onAuthorizedPlayerChatted(player, message)
    if not isPlayerAllowed(player) then return end

    debugPrint("Authorized player " .. player.Name .. " chatted: " .. message)
    local args = {}
    for arg in message:gmatch("%S+") do
        table.insert(args, arg:lower())
    end

    if args[1] == "orbit" or args[1] == "loworbit" or args[1] == "line" or args[1] == "shield" or args[1] == "movearound" or args[1] == "follow" then
        local targetName = args[2] or player.Name
        local targetPlayer = findPlayerByNameOrDisplay(targetName, player)
        if targetPlayer then
            local speed = tonumber(args[3]) or 1
            changeMode(args[1], targetPlayer, speed)
        else
            debugPrint("Target player not found: " .. targetName)
        end
    elseif args[1] == "stop" then
        changeMode("idle")
    elseif args[1] == "rejoin" then
        rejoinGame()
    elseif args[1] == "die" then
        dieCommand()
    elseif args[1] == "whitelist" and args[2] then
        whitelistPlayer(args[2])
    elseif args[1] == "blacklist" and args[2] then
        blacklistPlayer(args[2])
    elseif args[1] == "send" and args[2] then
        local chatMessage = table.concat(args, " ", 2)
        sendChatMessage(chatMessage)
    end
end

debugPrint("Script started for player: " .. currentPlayer.Name)
ownerPlayer = Players:FindFirstChild(getgenv().ownerName)

local function onPlayerAdded(player)
    player.Chatted:Connect(function(message)
        onAuthorizedPlayerChatted(player, message)
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

if ownerPlayer then
    debugPrint("Owner found. Initializing bot system for: " .. currentPlayer.Name)

    if getBotIndex() then
        RunService:Set3dRenderingEnabled(false)
        setfpscap(5)
        debugPrint("3D rendering disabled and FPS capped at 5")
    end

    debugPrint("Chat command listener set up")
else
    debugPrint("Owner not found in the game. Waiting for owner to join.")

    local ownerJoinedConnection
    ownerJoinedConnection = Players.PlayerAdded:Connect(function(player)
        if player.Name == getgenv().ownerName then
            debugPrint("Owner joined the game")
            ownerPlayer = player
            debugPrint("Chat command listener set up")
            ownerJoinedConnection:Disconnect()
        end
end)
end

local function findPlayerByNameOrDisplay(name, sender)
    if name:lower() == "myself" then
        return sender
    end
    name = name:lower()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower():find(name, 1, true) or (player.DisplayName and player.DisplayName:lower():find(name, 1, true)) then
            return player
        end
    end
    return nil
end

Players.PlayerAdded:Connect(onPlayerAdded)

if ownerPlayer then
    debugPrint("Owner found. Initializing bot system for: " .. currentPlayer.Name)

    if getBotIndex() then
        RunService:Set3dRenderingEnabled(false)
        setfpscap(5)
        debugPrint("3D rendering disabled and FPS capped at 5")
    end

    debugPrint("chat command listener set up")
else
    debugPrint("owner not found in the game")

    local ownerJoinedConnection
    ownerJoinedConnection = Players.PlayerAdded:Connect(function(player)
        if player.Name == getgenv().ownerName then
            debugPrint("Owner joined the game")
            ownerPlayer = player
            debugPrint("command listener set up")
            ownerJoinedConnection:Disconnect()
        end
    end)
end

debugPrint("initialization complete")

while true do
    if currentMode == "idle" then

        wait(0.5)
    else

        wait(0.1)
    end
end
        end
        
        runScript()
        return true
    else
        print("Key is invalid!")
        print("Server hash:", data.hash)
        print("Local hash:", localHash)
        return false
    end
end

-- Example usage
validateKeyAndRunScript()
