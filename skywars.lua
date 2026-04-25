repeat task.wait() until game:IsLoaded() and workspace.CurrentCamera

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/RealAquaVClip/LemonForRoblox/main/library.lua"))()
Library.ConfigFile = "Lemon_" .. game.PlaceId .. ".lua"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Skywars = {
    Remotes = {},
    Services = {},
    Store = {
        inventory = {},
        hand = {},
        tools = {sword = nil, pickaxe = nil},
        blocks = {}
    }
}

local function waitForChildOfType(obj, name, timeout, prop)
    local deadline = tick() + timeout
    local result
    repeat
        result = prop and obj[name] or obj:FindFirstChildOfClass(name)
        if result or tick() > deadline then break end
        task.wait()
    until false
    return result
end

local function roundPos(vec)
    return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
end

task.defer(function()
    local Flamework = require(ReplicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
    repeat task.wait() until debug.getupvalue(Flamework.ignite, 1)

    local function extractRemotes(name, key, func)
        for _, v in debug.getconstants(func) do
            if tostring(v):find('-') == 9 then
                Skywars.Remotes[key] = v
            end
        end
        for _, proto in debug.getprotos(func) do
            extractRemotes(name, key, proto)
        end
    end

    for id, obj in debug.getupvalue(Flamework.ignite, 2).idToObj do
        local name = tostring(obj)
        Skywars.Services[name] = Flamework.resolveDependency(id)
        for key, value in obj do
            if type(value) == 'function' then
                extractRemotes(name, key, value)
            end
        end
    end

    Skywars.Services.ItemMeta = debug.getupvalue(Skywars.Services.HotbarController.getSword, 1)
    Skywars.Services.Store = require(LocalPlayer.PlayerScripts.TS.ui.rodux['global-store']).GlobalStore
    Skywars.Gravity = debug.getupvalue(Skywars.Services.ProjectileController.chargeBow, 13).WORLD_ACCELERATION.Y
    Skywars.FireOrigin = debug.getupvalue(Skywars.Services.ProjectileController.chargeBow, 11).ORIGIN_OFFSET
end)

repeat task.wait() until next(Skywars.Remotes) and Skywars.Services.ItemMeta and Skywars.Services.Store

local function updateInventory()
    local state = Skywars.Services.Store:getState()
    if not state or not state.Inventory then return end
    Skywars.Store.inventory = state.Inventory.Contents
    Skywars.Store.hand = state.Inventory.Contents[state.ActiveSlot]
    Skywars.Store.hand = Skywars.Store.hand and Skywars.Services.ItemMeta[Skywars.Store.hand.Type] or {}

    local bestSwordDmg, bestPickTime = 0, math.huge
    Skywars.Store.tools.sword, Skywars.Store.tools.pickaxe = nil, nil
    for _, item in Skywars.Store.inventory do
        local meta = Skywars.Services.ItemMeta[item.Type]
        if meta then
            if meta.Melee and meta.Melee.Damage > bestSwordDmg then
                bestSwordDmg = meta.Melee.Damage
                Skywars.Store.tools.sword = {Name = item.Type, Meta = meta}
            end
            if meta.Pickaxe and meta.Pickaxe.TimeMultiplier < bestPickTime then
                bestPickTime = meta.Pickaxe.TimeMultiplier
                Skywars.Store.tools.pickaxe = {Name = item.Type, Meta = meta}
            end
        end
    end
end

updateInventory()
Skywars.Services.Store.changed:connect(updateInventory)

workspace.BlockContainer.DescendantAdded:Connect(function(v)
    if v:IsA('Part') and v.Size // 1 == v.Size then
        local start = (v.Position - (v.Size / 2)) + Vector3.new(1.5, 1.5, 1.5)
        for x = 0, v.Size.X - 1, 3 do
            for y = 0, v.Size.Y - 1, 3 do
                for z = 0, v.Size.Z - 1, 3 do
                    Skywars.Store.blocks[start + Vector3.new(x, y, z)] = v
                end
            end
        end
    end
end)

function Skywars:IsAlive()
    local char = LocalPlayer.Character
    return char and char.PrimaryPart and char:FindFirstChildOfClass("Humanoid") and char:FindFirstChildOfClass("Humanoid").Health > 0
end

function Skywars:GetNearestPlayer(range, teamCheck)
    local closest, closestDist = nil, range
    local myTeam = LocalPlayer:GetAttribute('TeamId')
    local myPos = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and LocalPlayer.Character.PrimaryPart.Position
    if not myPos then return nil end
    for _, plr in Players:GetPlayers() do
        if plr ~= LocalPlayer and plr.Character and plr.Character.PrimaryPart then
            if teamCheck and plr:GetAttribute('TeamId') == myTeam then continue end
            local dist = (plr.Character.PrimaryPart.Position - myPos).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = plr
            end
        end
    end
    return closest
end

function Skywars:GetNearestEgg(range)
    local closest, closestDist = nil, range
    local myTeam = LocalPlayer:GetAttribute('TeamId')
    local myPos = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and LocalPlayer.Character.PrimaryPart.Position
    if not myPos then return nil end
    for _, v in workspace:GetDescendants() do
        if v:IsA('Model') and v:GetAttribute('Egg') ~= nil and v.PrimaryPart then
            if v:GetAttribute('TeamId') == myTeam then continue end
            local dist = (v.PrimaryPart.Position - myPos).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = v
            end
        end
    end
    return closest
end

function Skywars:GetChests(range)
    local chests = {}
    local myPos = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and LocalPlayer.Character.PrimaryPart.Position
    if not myPos then return chests end
    for _, v in workspace:GetDescendants() do
        if v:IsA('Model') and v:GetAttribute('Chest') and v.PrimaryPart then
            if (v.PrimaryPart.Position - myPos).Magnitude <= range then
                table.insert(chests, v)
            end
        end
    end
    return chests
end

function Skywars:Attack(plr, toolName)
    local remotes = Skywars.Remotes
    if not remotes.strikeDesktop then return end
    if remotes.updateActiveItem then
        remotes.updateActiveItem:fire(toolName)
    end
    remotes.strikeDesktop:fire(plr)
    if remotes.updateActiveItem and Skywars.Store.hand.Name then
        remotes.updateActiveItem:fire(Skywars.Store.hand.Name)
    end
end

function Skywars:BreakBlock(block)
    local remotes = Skywars.Remotes
    if not remotes.hitBlock then return end
    local pos = block.PrimaryPart.Position + Vector3.new(0, 1.5, 0)
    remotes.hitBlock:fire(pos // 1)
end

function Skywars:PlaceBlock(position, blockName, blockType)
    Skywars.Services.BlockController:placeBlock(position, blockName, blockType, Vector3.zero)
end

function Skywars:FreezeCamera()
    local old = {Type = Camera.CameraType, CFrame = Camera.CFrame, Subject = Camera.CameraSubject}
    Camera.CameraType = Enum.CameraType.Scriptable
    Camera.CFrame = old.CFrame
    return old
end

function Skywars:RestoreCamera(old)
    pcall(function()
        Camera.CameraType = old.Type or Enum.CameraType.Custom
        if old.Subject then Camera.CameraSubject = old.Subject end
        if old.CFrame then Camera.CFrame = old.CFrame end
    end)
end

local MainFrame = Library:CreateMain()
local TabSections = {
    Combat = MainFrame:CreateTab("Combat"),
    Blatant = MainFrame:CreateTab("Blatant"),
    Move = MainFrame:CreateTab("Move"),
    Visual = MainFrame:CreateTab("Visual"),
    World = MainFrame:CreateTab("World"),
    Manager = MainFrame:CreateManager()
}

task.defer(function()
    local AuraRange = 12
    local AuraDelay = 0.1
    local Aura = TabSections.Combat:CreateToggle({
        Name = "Kill Aura",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    while Aura.Enabled do
                        if Skywars:IsAlive() and Skywars.Store.tools.sword then
                            local target = Skywars:GetNearestPlayer(AuraRange, true)
                            if target then
                                Skywars:Attack(target, Skywars.Store.tools.sword.Name)
                            end
                        end
                        task.wait(AuraDelay)
                    end
                end)
            end
        end
    })
    Aura:CreateSlider({
        Name = "Range",
        Min = 1,
        Max = 20,
        Default = 12,
        Callback = function(value) AuraRange = value end
    })
    Aura:CreateSlider({
        Name = "Delay",
        Min = 0.05,
        Max = 0.5,
        Default = 0.1,
        Decimal = 100,
        Callback = function(value) AuraDelay = value end
    })
end)

task.defer(function()
    local SpeedValue = 28
    local SpeedAutoJump = false
    local Speed = TabSections.Move:CreateToggle({
        Name = "Speed",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    while Speed.Enabled do
                        if Skywars:IsAlive() and LocalPlayer.Character.PrimaryPart then
                            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                            local dir = hum.MoveDirection
                            LocalPlayer.Character.PrimaryPart.Velocity = Vector3.new(
                                dir.X * SpeedValue,
                                LocalPlayer.Character.PrimaryPart.Velocity.Y,
                                dir.Z * SpeedValue
                            )
                            if SpeedAutoJump and hum.FloorMaterial ~= Enum.Material.Air and not hum.Jump then
                                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                            end
                        end
                        task.wait()
                    end
                end)
            end
        end
    })
    Speed:CreateSlider({
        Name = "Speed",
        Min = 0,
        Max = 150,
        Default = 28,
        Callback = function(value) SpeedValue = value end
    })
    Speed:CreateToggle({
        Name = "Auto Jump",
        Callback = function(value) SpeedAutoJump = value end
    })
end)

task.defer(function()
    local FlightSpeed = 28
    local Flight = TabSections.Move:CreateToggle({
        Name = "Flight",
        Callback = function(callback)
            if callback then
                local oldGravity = workspace.Gravity
                local newY = 0
                task.spawn(function()
                    while Flight.Enabled do
                        if Skywars:IsAlive() and LocalPlayer.Character.PrimaryPart then
                            workspace.Gravity = 0
                            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                            local dir = hum.MoveDirection
                            local root = LocalPlayer.Character.PrimaryPart
                            root.Velocity = Vector3.new(dir.X * FlightSpeed, root.Velocity.Y, dir.Z * FlightSpeed)
                            if UserInputService:IsKeyDown(Enum.KeyCode.Space) and not UserInputService:GetFocusedTextBox() then
                                newY += 0.8
                            end
                            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and not UserInputService:GetFocusedTextBox() then
                                newY -= 0.8
                            end
                            root.CFrame = CFrame.new(root.Position.X, newY, root.Position.Z) * root.CFrame.Rotation
                        end
                        task.wait()
                    end
                    workspace.Gravity = oldGravity
                end)
            end
        end
    })
    Flight:CreateSlider({
        Name = "Speed",
        Min = 0,
        Max = 150,
        Default = 28,
        Callback = function(value) FlightSpeed = value end
    })
end)

task.defer(function()
    TabSections.Move:CreateToggle({
        Name = "No Slowdown",
        Callback = function(callback)
            if callback then
                local old = Skywars.Services.HumanoidController.addSpeedModifier
                Skywars.Services.HumanoidController.addSpeedModifier = function(self, index, speed)
                    return old(self, index, math.max(speed, 1))
                end
                for i, v in Skywars.Services.HumanoidController.speedModifiers do
                    if v < 1 then
                        Skywars.Services.HumanoidController:removeSpeedModifier(i)
                    end
                end
            else
                if old then
                    Skywars.Services.HumanoidController.addSpeedModifier = old
                end
            end
        end
    })
end)

task.defer(function()
    local VelocityHorizontal = 0
    local VelocityVertical = 0
    local VelocityChance = 100
    local VelocityTargeting = false
    local Velocity = TabSections.Combat:CreateToggle({
        Name = "Velocity",
        Callback = function(callback)
            if callback then
                local conn = getconnections(debug.getupvalue(
                    debug.getupvalue(Skywars.Remotes['PlayerVelocityController:onStart'].connect, 1).fireClient, 1
                ).OnClientEvent)[1]
                if conn then
                    local old = hookfunction(conn.Function, function(velo, ...)
                        if math.random(0, 100) > VelocityChance then return old(velo, ...) end
                        if VelocityTargeting then
                            local target = Skywars:GetNearestPlayer(50, true)
                            if not target then return old(velo, ...) end
                        end
                        return old(Vector3.new(
                            velo.X * (VelocityHorizontal / 100),
                            velo.Y * (VelocityVertical / 100),
                            velo.Z * (VelocityHorizontal / 100)
                        ), ...)
                    end)
                end
            end
        end
    })
    Velocity:CreateSlider({
        Name = "Horizontal",
        Min = 0,
        Max = 100,
        Default = 0,
        Suffix = "%",
        Callback = function(value) VelocityHorizontal = value end
    })
    Velocity:CreateSlider({
        Name = "Vertical",
        Min = 0,
        Max = 100,
        Default = 0,
        Suffix = "%",
        Callback = function(value) VelocityVertical = value end
    })
    Velocity:CreateSlider({
        Name = "Chance",
        Min = 0,
        Max = 100,
        Default = 100,
        Suffix = "%",
        Callback = function(value) VelocityChance = value end
    })
    Velocity:CreateToggle({
        Name = "Only when targeting",
        Callback = function(value) VelocityTargeting = value end
    })
end)

task.defer(function()
    local ChestStealRange = 10
    local ChestSteal = TabSections.World:CreateToggle({
        Name = "ChestSteal",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    while ChestSteal.Enabled do
                        if Skywars:IsAlive() and Skywars.Remotes.openChest then
                            for _, chest in Skywars:GetChests(ChestStealRange) do
                                Skywars.Remotes.openChest:fire(chest)
                            end
                        end
                        task.wait(0.1)
                    end
                end)
            end
        end
    })
    ChestSteal:CreateSlider({
        Name = "Range",
        Min = 0,
        Max = 10,
        Default = 10,
        Callback = function(value) ChestStealRange = value end
    })
end)

task.defer(function()
    local TPRange = 100
    local TPDelay = 0.2
    local TP = TabSections.Blatant:CreateToggle({
        Name = "TP Aura",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    while TP.Enabled do
                        if Skywars:IsAlive() and Skywars.Store.tools.sword then
                            local target = Skywars:GetNearestPlayer(TPRange, true)
                            if target then
                                local camState = Skywars:FreezeCamera()
                                local root = LocalPlayer.Character.PrimaryPart
                                local origCF = root.CFrame
                                local behind = target.Character.PrimaryPart.CFrame * CFrame.new(0, 0, 3)
                                root.CFrame = CFrame.new(behind.Position, target.Character.PrimaryPart.Position)
                                Skywars:Attack(target, Skywars.Store.tools.sword.Name)
                                task.wait(0.05)
                                pcall(function() root.CFrame = origCF end)
                                Skywars:RestoreCamera(camState)
                                task.wait(TPDelay)
                            end
                        end
                        task.wait(0.05)
                    end
                end)
            end
        end
    })
    TP:CreateSlider({
        Name = "Range",
        Min = 1,
        Max = 200,
        Default = 100,
        Callback = function(value) TPRange = value end
    })
    TP:CreateSlider({
        Name = "Delay",
        Min = 0.1,
        Max = 1,
        Default = 0.2,
        Decimal = 10,
        Callback = function(value) TPDelay = value end
    })
end)

task.defer(function()
    local DesyncOffset = 5
    local Desync = TabSections.Blatant:CreateToggle({
        Name = "Desync",
        Callback = function(callback)
            if callback then
                local clone = Instance.new("Part")
                clone.Size = Vector3.new(1, 1, 1)
                clone.Anchored = true
                clone.CanCollide = false
                clone.Transparency = 0.7
                clone.Color = Color3.new(0, 1, 1)
                clone.Material = Enum.Material.Neon
                clone.Parent = workspace
                task.spawn(function()
                    while Desync.Enabled do
                        if Skywars:IsAlive() and LocalPlayer.Character.PrimaryPart then
                            local root = LocalPlayer.Character.PrimaryPart
                            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                            local dir = hum and hum.MoveDirection or Vector3.zero
                            local offsetPos = root.Position - (dir * DesyncOffset)
                            if dir.Magnitude < 0.1 then
                                offsetPos = root.Position + Vector3.new(DesyncOffset, 0, 0)
                            end
                            clone.CFrame = CFrame.new(offsetPos)
                            local oldCF = root.CFrame
                            root.CFrame = clone.CFrame
                            task.wait()
                            pcall(function() root.CFrame = oldCF end)
                        end
                        task.wait(0.05)
                    end
                    clone:Destroy()
                end)
            end
        end
    })
    Desync:CreateSlider({
        Name = "Offset",
        Min = 1,
        Max = 10,
        Default = 5,
        Callback = function(value) DesyncOffset = value end
    })
end)

task.defer(function()
    local BacktrackDelay = 150
    local Backtrack = TabSections.Visual:CreateToggle({
        Name = "Backtrack",
        Callback = function(callback)
            if callback then
                local records = {}
                local ghost = Instance.new("Highlight")
                ghost.FillTransparency = 0.5
                ghost.OutlineTransparency = 1
                ghost.FillColor = Color3.new(0, 1, 0)
                task.spawn(function()
                    while Backtrack.Enabled do
                        local target = Skywars:GetNearestPlayer(12, true)
                        if target and target.Character and target.Character.PrimaryPart then
                            local userId = target.UserId
                            if not records[userId] then records[userId] = {} end
                            table.insert(records[userId], {
                                TimeMs = os.clock() * 1000,
                                CFrame = target.Character.PrimaryPart.CFrame
                            })
                            while #records[userId] > 200 do
                                table.remove(records[userId], 1)
                            end
                            ghost.Parent = target.Character
                        end
                        task.wait(0.016)
                    end
                    ghost:Destroy()
                end)
            end
        end
    })
    Backtrack:CreateSlider({
        Name = "Delay (ms)",
        Min = 50,
        Max = 500,
        Default = 150,
        Callback = function(value) BacktrackDelay = value end
    })
end)

task.defer(function()
    local ESP = TabSections.Visual:CreateToggle({
        Name = "ESP",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    local boxes = {}
                    while ESP.Enabled do
                        for _, plr in Players:GetPlayers() do
                            if plr ~= LocalPlayer and plr.Character and plr.Character.PrimaryPart then
                                local char = plr.Character
                                if not boxes[char] then
                                    local billboard = Instance.new("BillboardGui")
                                    billboard.Parent = char
                                    billboard.AlwaysOnTop = true
                                    billboard.Size = UDim2.new(4, 0, 5, 0)
                                    local frame = Instance.new("Frame")
                                    frame.Parent = billboard
                                    frame.AnchorPoint = Vector2.new(0.5, 0.5)
                                    frame.BackgroundTransparency = 1
                                    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
                                    frame.Size = UDim2.new(1, 0, 1, 0)
                                    local stroke = Instance.new("UIStroke")
                                    stroke.Parent = frame
                                    stroke.Color = Color3.new(1, 1, 1)
                                    stroke.Thickness = 2
                                    boxes[char] = billboard
                                end
                            end
                        end
                        for char, billboard in boxes do
                            if not char.PrimaryPart then
                                billboard:Destroy()
                                boxes[char] = nil
                            end
                        end
                        task.wait()
                    end
                    for _, billboard in boxes do
                        billboard:Destroy()
                    end
                end)
            end
        end
    })
end)

task.defer(function()
    local Chams = TabSections.Visual:CreateToggle({
        Name = "Chams",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    local highlights = {}
                    while Chams.Enabled do
                        for _, plr in Players:GetPlayers() do
                            if plr ~= LocalPlayer and plr.Character then
                                if not highlights[plr.Character] then
                                    local highlight = Instance.new("Highlight")
                                    highlight.FillTransparency = 1
                                    highlight.OutlineTransparency = 0.45
                                    highlight.OutlineColor = Color3.new(1, 1, 1)
                                    highlight.Parent = plr.Character
                                    highlights[plr.Character] = highlight
                                end
                            end
                        end
                        for char, highlight in highlights do
                            if not char.PrimaryPart then
                                highlight:Destroy()
                                highlights[char] = nil
                            end
                        end
                        task.wait()
                    end
                    for _, highlight in highlights do
                        highlight:Destroy()
                    end
                end)
            end
        end
    })
end)

task.defer(function()
    local EggRange = 50
    local EggAura = TabSections.World:CreateToggle({
        Name = "Egg Aura",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    while EggAura.Enabled do
                        if Skywars:IsAlive() and Skywars.Store.tools.pickaxe then
                            local egg = Skywars:GetNearestEgg(EggRange)
                            if egg then
                                local camState = Skywars:FreezeCamera()
                                local root = LocalPlayer.Character.PrimaryPart
                                local origCF = root.CFrame
                                root.CFrame = CFrame.new(egg.PrimaryPart.Position + Vector3.new(0, 4, 0))
                                Skywars:BreakBlock(egg)
                                task.wait(0.05)
                                pcall(function() root.CFrame = origCF end)
                                Skywars:RestoreCamera(camState)
                                task.wait(0.2)
                            end
                        end
                        task.wait(0.1)
                    end
                end)
            end
        end
    })
    EggAura:CreateSlider({
        Name = "Range",
        Min = 1,
        Max = 100,
        Default = 50,
        Callback = function(value) EggRange = value end
    })
end)    until false
    return result
end

task.defer(function()
    local Flamework = require(ReplicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
    repeat task.wait() until debug.getupvalue(Flamework.ignite, 1)

    local function extractRemotes(name, key, func)
        for _, v in debug.getconstants(func) do
            if tostring(v):find('-') == 9 then
                Skywars.Remotes[key] = v
            end
        end
        for _, proto in debug.getprotos(func) do
            extractRemotes(name, key, proto)
        end
    end

    for id, obj in debug.getupvalue(Flamework.ignite, 2).idToObj do
        local name = tostring(obj)
        Skywars.Services[name] = Flamework.resolveDependency(id)
        for key, value in obj do
            if type(value) == 'function' then
                extractRemotes(name, key, value)
            end
        end
    end

    Skywars.Services.ItemMeta = debug.getupvalue(Skywars.Services.HotbarController.getSword, 1)
    Skywars.Services.Store = require(LocalPlayer.PlayerScripts.TS.ui.rodux['global-store']).GlobalStore
    Skywars.Services.Roact = require(ReplicatedStorage['rbxts_include']['node_modules']['@rbxts'].ReactLua['node_modules']['@jsdotlua']['roact-compat'])
    Skywars.Gravity = debug.getupvalue(Skywars.Services.ProjectileController.chargeBow, 13).WORLD_ACCELERATION.Y
    Skywars.FireOrigin = debug.getupvalue(Skywars.Services.ProjectileController.chargeBow, 11).ORIGIN_OFFSET
end)

repeat task.wait() until next(Skywars.Remotes) and Skywars.Services.ItemMeta

local function updateInventory()
    local state = Skywars.Services.Store:getState()
    if not state or not state.Inventory then return end
    Skywars.Store.inventory = state.Inventory.Contents
    Skywars.Store.hand = state.Inventory.Contents[state.ActiveSlot]
    Skywars.Store.hand = Skywars.Store.hand and Skywars.Services.ItemMeta[Skywars.Store.hand.Type] or {}

    local bestSwordDmg, bestPickTime = 0, math.huge
    Skywars.Store.tools.sword, Skywars.Store.tools.pickaxe = nil, nil
    for _, item in Skywars.Store.inventory do
        local meta = Skywars.Services.ItemMeta[item.Type]
        if meta then
            if meta.Melee and meta.Melee.Damage > bestSwordDmg then
                bestSwordDmg = meta.Melee.Damage
                Skywars.Store.tools.sword = {Name = item.Type, Meta = meta}
            end
            if meta.Pickaxe and meta.Pickaxe.TimeMultiplier < bestPickTime then
                bestPickTime = meta.Pickaxe.TimeMultiplier
                Skywars.Store.tools.pickaxe = {Name = item.Type, Meta = meta}
            end
        end
    end
end

updateInventory()
Skywars.Services.Store.changed:connect(updateInventory)

workspace.BlockContainer.DescendantAdded:Connect(function(v)
    if v:IsA('Part') and v.Size // 1 == v.Size then
        local start = (v.Position - (v.Size / 2)) + Vector3.new(1.5, 1.5, 1.5)
        for x = 0, v.Size.X - 1, 3 do
            for y = 0, v.Size.Y - 1, 3 do
                for z = 0, v.Size.Z - 1, 3 do
                    Skywars.Store.blocks[start + Vector3.new(x, y, z)] = v
                end
            end
        end
    end
end)

function Skywars:IsAlive()
    local char = LocalPlayer.Character
    return char and char.PrimaryPart and char:FindFirstChildOfClass("Humanoid") and char:FindFirstChildOfClass("Humanoid").Health > 0
end

function Skywars:GetNearestPlayer(range, teamCheck)
    local closest, closestDist = nil, range
    local myTeam = LocalPlayer:GetAttribute('TeamId')
    local myPos = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and LocalPlayer.Character.PrimaryPart.Position
    if not myPos then return nil end
    for _, plr in Players:GetPlayers() do
        if plr ~= LocalPlayer and plr.Character and plr.Character.PrimaryPart then
            if teamCheck and plr:GetAttribute('TeamId') == myTeam then continue end
            local dist = (plr.Character.PrimaryPart.Position - myPos).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = plr
            end
        end
    end
    return closest
end

function Skywars:GetNearestEgg(range)
    local closest, closestDist = nil, range
    local myTeam = LocalPlayer:GetAttribute('TeamId')
    local myPos = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and LocalPlayer.Character.PrimaryPart.Position
    if not myPos then return nil end
    for _, v in workspace:GetDescendants() do
        if v:IsA('Model') and v:GetAttribute('Egg') ~= nil and v.PrimaryPart then
            if v:GetAttribute('TeamId') == myTeam then continue end
            local dist = (v.PrimaryPart.Position - myPos).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = v
            end
        end
    end
    return closest
end

function Skywars:GetChests(range)
    local chests = {}
    local myPos = LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and LocalPlayer.Character.PrimaryPart.Position
    if not myPos then return chests end
    for _, v in workspace:GetDescendants() do
        if v:IsA('Model') and v:GetAttribute('Chest') and v.PrimaryPart then
            if (v.PrimaryPart.Position - myPos).Magnitude <= range then
                table.insert(chests, v)
            end
        end
    end
    return chests
end

function Skywars:Attack(plr, toolName)
    local remotes = Skywars.Remotes
    if not remotes.strikeDesktop then return end
    if remotes.updateActiveItem then
        remotes.updateActiveItem:fire(toolName)
    end
    remotes.strikeDesktop:fire(plr)
    if remotes.updateActiveItem and Skywars.Store.hand.Name then
        remotes.updateActiveItem:fire(Skywars.Store.hand.Name)
    end
end

function Skywars:BreakBlock(block)
    local remotes = Skywars.Remotes
    if not remotes.hitBlock then return end
    local pos = block.PrimaryPart.Position + Vector3.new(0, 1.5, 0)
    remotes.hitBlock:fire(pos // 1)
end

function Skywars:PlaceBlock(position, blockName, blockType)
    Skywars.Services.BlockController:placeBlock(position, blockName, blockType, Vector3.zero)
end

function Skywars:FreezeCamera()
    local old = {Type = Camera.CameraType, CFrame = Camera.CFrame, Subject = Camera.CameraSubject}
    Camera.CameraType = Enum.CameraType.Scriptable
    Camera.CFrame = old.CFrame
    return old
end

function Skywars:RestoreCamera(old)
    pcall(function()
        Camera.CameraType = old.Type or Enum.CameraType.Custom
        if old.Subject then Camera.CameraSubject = old.Subject end
        if old.CFrame then Camera.CFrame = old.CFrame end
    end)
end

local function roundPos(vec)
    return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
end

local MainFrame = Library:CreateMain()
local TabSections = {
    Combat = MainFrame:CreateTab("Combat"),
    Blatant = MainFrame:CreateTab("Blatant"),
    Move = MainFrame:CreateTab("Move"),
    Visual = MainFrame:CreateTab("Visual"),
    World = MainFrame:CreateTab("World"),
    Manager = MainFrame:CreateManager()
}

task.defer(function()
    local KillAura = TabSections.Combat:CreateToggle({
        Name = "Kill Aura",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    while KillAura.Enabled do
                        if Skywars:IsAlive() and Skywars.Store.tools.sword then
                            local target = Skywars:GetNearestPlayer(KillAuraRange, true)
                            if target then
                                Skywars:Attack(target, Skywars.Store.tools.sword.Name)
                            end
                        end
                        task.wait(KillAuraDelay)
                    end
                end)
            end
        end
    })
    local KillAuraRange = 12
    local KillAuraDelay = 0.1
    KillAura:CreateSlider({
        Name = "Range",
        Min = 1,
        Max = 20,
        Default = 12,
        Callback = function(value)
            KillAuraRange = value
        end
    })
    KillAura:CreateSlider({
        Name = "Delay",
        Min = 0.05,
        Max = 0.5,
        Default = 0.1,
        Decimal = 100,
        Callback = function(value)
            KillAuraDelay = value
        end
    })
end)

task.defer(function()
    local Speed = TabSections.Move:CreateToggle({
        Name = "Speed",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    while Speed.Enabled do
                        if Skywars:IsAlive() and LocalPlayer.Character.PrimaryPart then
                            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                            local dir = hum.MoveDirection
                            LocalPlayer.Character.PrimaryPart.Velocity = Vector3.new(
                                dir.X * SpeedValue,
                                LocalPlayer.Character.PrimaryPart.Velocity.Y,
                                dir.Z * SpeedValue
                            )
                            if SpeedAutoJump and hum.FloorMaterial ~= Enum.Material.Air and not hum.Jump then
                                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                            end
                        end
                        task.wait()
                    end
                end)
            end
        end
    })
    local SpeedValue = 28
    local SpeedAutoJump = false
    Speed:CreateSlider({
        Name = "Speed",
        Min = 0,
        Max = 150,
        Default = 28,
        Callback = function(value)
            SpeedValue = value
        end
    })
    Speed:CreateMiniToggle({
        Name = "Auto Jump",
        Callback = function(value)
            SpeedAutoJump = value
        end
    })
end)

task.defer(function()
    local Flight = TabSections.Move:CreateToggle({
        Name = "Flight",
        Callback = function(callback)
            if callback then
                local oldGravity = workspace.Gravity
                local newY = 0
                task.spawn(function()
                    while Flight.Enabled do
                        if Skywars:IsAlive() and LocalPlayer.Character.PrimaryPart then
                            workspace.Gravity = 0
                            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                            local dir = hum.MoveDirection
                            local root = LocalPlayer.Character.PrimaryPart
                            root.Velocity = Vector3.new(dir.X * FlightSpeed, root.Velocity.Y, dir.Z * FlightSpeed)
                            if UserInputService:IsKeyDown(Enum.KeyCode.Space) and not UserInputService:GetFocusedTextBox() then
                                newY += 0.8
                            end
                            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and not UserInputService:GetFocusedTextBox() then
                                newY -= 0.8
                            end
                            root.CFrame = CFrame.new(root.Position.X, newY, root.Position.Z) * root.CFrame.Rotation
                        end
                        task.wait()
                    end
                    workspace.Gravity = oldGravity
                end)
            end
        end
    })
    local FlightSpeed = 28
    Flight:CreateSlider({
        Name = "Speed",
        Min = 0,
        Max = 150,
        Default = 28,
        Callback = function(value)
            FlightSpeed = value
        end
    })
end)

task.defer(function()
    TabSections.Move:CreateToggle({
        Name = "No Slowdown",
        Callback = function(callback)
            if callback then
                local old = Skywars.Services.HumanoidController.addSpeedModifier
                Skywars.Services.HumanoidController.addSpeedModifier = function(self, index, speed)
                    return old(self, index, math.max(speed, 1))
                end
                for i, v in Skywars.Services.HumanoidController.speedModifiers do
                    if v < 1 then
                        Skywars.Services.HumanoidController:removeSpeedModifier(i)
                    end
                end
                Skywars.Services.SprintingController:setCanSprint(true)
                Skywars.Services.SprintingController:enableSprinting()
            else
                if old then
                    Skywars.Services.HumanoidController.addSpeedModifier = old
                    old = nil
                end
            end
        end
    })
end)

task.defer(function()
    local Velocity = TabSections.Combat:CreateToggle({
        Name = "Velocity",
        Callback = function(callback)
            if callback then
                local connection = getconnections(debug.getupvalue(
                    debug.getupvalue(Skywars.Remotes['PlayerVelocityController:onStart'].connect, 1).fireClient, 1
                ).OnClientEvent)[1]
                if connection then
                    local old = hookfunction(connection.Function, function(velo, ...)
                        if math.random(0, 100) > VelocityChance then return old(velo, ...) end
                        if VelocityTargeting then
                            local target = Skywars:GetNearestPlayer(50, true)
                            if not target then return old(velo, ...) end
                        end
                        return old(Vector3.new(
                            velo.X * (VelocityHorizontal / 100),
                            velo.Y * (VelocityVertical / 100),
                            velo.Z * (VelocityHorizontal / 100)
                        ), ...)
                    end)
                    Velocity:Clean(function()
                        hookfunction(connection.Function, old)
                    end)
                end
            end
        end
    })
    local VelocityHorizontal = 0
    local VelocityVertical = 0
    local VelocityChance = 100
    local VelocityTargeting = false
    Velocity:CreateSlider({
        Name = "Horizontal",
        Min = 0,
        Max = 100,
        Default = 0,
        Suffix = "%",
        Callback = function(value)
            VelocityHorizontal = value
        end
    })
    Velocity:CreateSlider({
        Name = "Vertical",
        Min = 0,
        Max = 100,
        Default = 0,
        Suffix = "%",
        Callback = function(value)
            VelocityVertical = value
        end
    })
    Velocity:CreateSlider({
        Name = "Chance",
        Min = 0,
        Max = 100,
        Default = 100,
        Suffix = "%",
        Callback = function(value)
            VelocityChance = value
        end
    })
    Velocity:CreateMiniToggle({
        Name = "Only when targeting",
        Callback = function(value)
            VelocityTargeting = value
        end
    })
end)

task.defer(function()
    local ChestSteal = TabSections.World:CreateToggle({
        Name = "ChestSteal",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    while ChestSteal.Enabled do
                        if Skywars:IsAlive() and Skywars.Remotes.openChest then
                            for _, chest in Skywars:GetChests(ChestStealRange) do
                                Skywars.Remotes.openChest:fire(chest)
                            end
                        end
                        task.wait(0.1)
                    end
                end)
            end
        end
    })
    local ChestStealRange = 10
    ChestSteal:CreateSlider({
        Name = "Range",
        Min = 0,
        Max = 10,
        Default = 10,
        Callback = function(value)
            ChestStealRange = value
        end
    })
end)

task.defer(function()
    local Scaffold = TabSections.World:CreateToggle({
        Name = "Scaffold",
        Callback = function(callback)
            if callback then
                local adjacent = {}
                for x = -3, 3, 3 do
                    for y = -3, 3, 3 do
                        for z = -3, 3, 3 do
                            local vec = Vector3.new(x, y, z)
                            if vec.Y ~= 0 and (vec.X ~= 0 or vec.Z ~= 0) then continue end
                            if vec ~= Vector3.zero then
                                table.insert(adjacent, vec)
                            end
                        end
                    end
                end
                local lastpos = Vector3.zero
                task.spawn(function()
                    while Scaffold.Enabled do
                        if Skywars:IsAlive() then
                            local wool = nil
                            for _, item in Skywars.Store.inventory do
                                local meta = Skywars.Services.ItemMeta[item.Type]
                                if meta and meta.Rewrite then
                                    wool = {Name = item.Type, Meta = meta}
                                    break
                                end
                            end
                            if wool then
                                local root = LocalPlayer.Character.PrimaryPart
                                local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                                if ScaffoldTower and UserInputService:IsKeyDown(Enum.KeyCode.Space) and not UserInputService:GetFocusedTextBox() then
                                    root.Velocity = Vector3.new(root.Velocity.X, 38, root.Velocity.Z)
                                end
                                for i = ScaffoldExpand, 1, -1 do
                                    local currentpos = roundPos(
                                        root.Position
                                        - Vector3.new(0, hum.HipHeight + 1.5 + (ScaffoldDownwards and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 3 or 0), 0)
                                        + hum.MoveDirection * (i * 3)
                                    )
                                    if not Skywars.Store.blocks[currentpos] then
                                        local checkadj = false
                                        for _, adj in adjacent do
                                            if Skywars.Store.blocks[currentpos + adj] then
                                                checkadj = true
                                                break
                                            end
                                        end
                                        local blockpos = checkadj and currentpos or nil
                                        if blockpos then
                                            local block = Skywars.Services.ItemMeta[wool.Meta.Rewrite.Type:gsub('{TeamId}', Skywars.Services.TeamController:getPlayerTeamId(LocalPlayer) or 'White')]
                                            Skywars:PlaceBlock(blockpos, wool.Name, block)
                                        end
                                    end
                                    lastpos = currentpos
                                end
                            end
                        end
                        task.wait(0.03)
                    end
                end)
            end
        end
    })
    local ScaffoldExpand = 1
    local ScaffoldTower = true
    local ScaffoldDownwards = true
    Scaffold:CreateSlider({
        Name = "Expand",
        Min = 1,
        Max = 6,
        Default = 1,
        Callback = function(value)
            ScaffoldExpand = value
        end
    })
    Scaffold:CreateMiniToggle({
        Name = "Tower",
        Callback = function(value)
            ScaffoldTower = value
        end
    })
    Scaffold:CreateMiniToggle({
        Name = "Downwards",
        Callback = function(value)
            ScaffoldDownwards = value
        end
    })
end)

task.defer(function()
    local TP = TabSections.Blatant:CreateToggle({
        Name = "TP Aura",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    while TP.Enabled do
                        if Skywars:IsAlive() and Skywars.Store.tools.sword then
                            local target = Skywars:GetNearestPlayer(TPRange, true)
                            if target then
                                local camState = Skywars:FreezeCamera()
                                local root = LocalPlayer.Character.PrimaryPart
                                local origCF = root.CFrame
                                local behind = target.Character.PrimaryPart.CFrame * CFrame.new(0, 0, 3)
                                root.CFrame = CFrame.new(behind.Position, target.Character.PrimaryPart.Position)
                                Skywars:Attack(target, Skywars.Store.tools.sword.Name)
                                task.wait(0.05)
                                pcall(function() root.CFrame = origCF end)
                                Skywars:RestoreCamera(camState)
                                task.wait(TPDelay)
                            end
                        end
                        task.wait(0.05)
                    end
                end)
            end
        end
    })
    local TPRange = 100
    local TPDelay = 0.2
    TP:CreateSlider({
        Name = "Range",
        Min = 1,
        Max = 200,
        Default = 100,
        Callback = function(value)
            TPRange = value
        end
    })
    TP:CreateSlider({
        Name = "Delay",
        Min = 0.1,
        Max = 1,
        Default = 0.2,
        Decimal = 10,
        Callback = function(value)
            TPDelay = value
        end
    })
end)

task.defer(function()
    local Desync = TabSections.Blatant:CreateToggle({
        Name = "Desync",
        Callback = function(callback)
            if callback then
                local clone = Instance.new("Part")
                clone.Size = Vector3.new(1, 1, 1)
                clone.Anchored = true
                clone.CanCollide = false
                clone.Transparency = 0.7
                clone.Color = Color3.new(0, 1, 1)
                clone.Material = Enum.Material.Neon
                clone.Parent = workspace
                task.spawn(function()
                    while Desync.Enabled do
                        if Skywars:IsAlive() and LocalPlayer.Character.PrimaryPart then
                            local root = LocalPlayer.Character.PrimaryPart
                            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                            local dir = hum and hum.MoveDirection or Vector3.zero
                            local offsetPos = root.Position - (dir * DesyncOffset)
                            if dir.Magnitude < 0.1 then
                                offsetPos = root.Position + Vector3.new(DesyncOffset, 0, 0)
                            end
                            clone.CFrame = CFrame.new(offsetPos)
                            local oldCF = root.CFrame
                            root.CFrame = clone.CFrame
                            task.wait()
                            pcall(function() root.CFrame = oldCF end)
                        end
                        task.wait(0.05)
                    end
                    clone:Destroy()
                end)
            end
        end
    })
    local DesyncOffset = 5
    Desync:CreateSlider({
        Name = "Offset",
        Min = 1,
        Max = 10,
        Default = 5,
        Callback = function(value)
            DesyncOffset = value
        end
    })
end)

task.defer(function()
    local Backtrack = TabSections.Visual:CreateToggle({
        Name = "Backtrack",
        Callback = function(callback)
            if callback then
                local records = {}
                local ghost = Instance.new("Highlight")
                ghost.FillTransparency = 0.5
                ghost.OutlineTransparency = 1
                ghost.FillColor = Color3.new(0, 1, 0)
                task.spawn(function()
                    while Backtrack.Enabled do
                        local target = Skywars:GetNearestPlayer(12, true)
                        if target and target.Character and target.Character.PrimaryPart then
                            local userId = target.UserId
                            if not records[userId] then records[userId] = {} end
                            table.insert(records[userId], {
                                TimeMs = os.clock() * 1000,
                                CFrame = target.Character.PrimaryPart.CFrame
                            })
                            while #records[userId] > 200 do
                                table.remove(records[userId], 1)
                            end
                            ghost.Parent = target.Character
                        end
                        task.wait(0.016)
                    end
                    ghost:Destroy()
                end)
            end
        end
    })
    local BacktrackDelay = 150
    Backtrack:CreateSlider({
        Name = "Delay (ms)",
        Min = 50,
        Max = 500,
        Default = 150,
        Callback = function(value)
            BacktrackDelay = value
        end
    })
end)

task.defer(function()
    TabSections.Visual:CreateToggle({
        Name = "ESP",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    local boxes = {}
                    while ESP.Enabled do
                        for _, plr in Players:GetPlayers() do
                            if plr ~= LocalPlayer and plr.Character and plr.Character.PrimaryPart then
                                local char = plr.Character
                                if not boxes[char] then
                                    local billboard = Instance.new("BillboardGui")
                                    billboard.Parent = char
                                    billboard.AlwaysOnTop = true
                                    billboard.Size = UDim2.new(4, 0, 5, 0)
                                    local frame = Instance.new("Frame")
                                    frame.Parent = billboard
                                    frame.AnchorPoint = Vector2.new(0.5, 0.5)
                                    frame.BackgroundTransparency = 1
                                    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
                                    frame.Size = UDim2.new(1, 0, 1, 0)
                                    local stroke = Instance.new("UIStroke")
                                    stroke.Parent = frame
                                    stroke.Color = Color3.new(1, 1, 1)
                                    stroke.Thickness = 2
                                    boxes[char] = billboard
                                end
                            end
                        end
                        for char, billboard in boxes do
                            if not char.PrimaryPart then
                                billboard:Destroy()
                                boxes[char] = nil
                            end
                        end
                        task.wait()
                    end
                    for _, billboard in boxes do
                        billboard:Destroy()
                    end
                end)
            end
        end
    })
end)

task.defer(function()
    TabSections.Visual:CreateToggle({
        Name = "Chams",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    local highlights = {}
                    while Chams.Enabled do
                        for _, plr in Players:GetPlayers() do
                            if plr ~= LocalPlayer and plr.Character then
                                if not highlights[plr.Character] then
                                    local highlight = Instance.new("Highlight")
                                    highlight.FillTransparency = 1
                                    highlight.OutlineTransparency = 0.45
                                    highlight.OutlineColor = Color3.new(1, 1, 1)
                                    highlight.Parent = plr.Character
                                    highlights[plr.Character] = highlight
                                end
                            end
                        end
                        for char, highlight in highlights do
                            if not char.PrimaryPart then
                                highlight:Destroy()
                                highlights[char] = nil
                            end
                        end
                        task.wait()
                    end
                    for _, highlight in highlights do
                        highlight:Destroy()
                    end
                end)
            end
        end
    })
end)

task.defer(function()
    TabSections.Visual:CreateToggle({
        Name = "Tracers",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    local lines = {}
                    while Tracers.Enabled do
                        for _, plr in Players:GetPlayers() do
                            if plr ~= LocalPlayer and plr.Character and plr.Character.PrimaryPart then
                                local char = plr.Character
                                local pos, onScreen = Camera:WorldToScreenPoint(char.PrimaryPart.Position)
                                if onScreen then
                                    local origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 1.5)
                                    local dest = Vector2.new(pos.X, pos.Y)
                                    if not lines[char] then
                                        lines[char] = MainFrame:CreateLine(origin, dest)
                                    else
                                        local line = lines[char]
                                        line.Position = UDim2.new(0, (origin + dest).X / 2, 0, (origin + dest).Y / 2)
                                        line.Size = UDim2.new(0, (origin - dest).Magnitude, 0, 1)
                                        line.Rotation = math.deg(math.atan2(dest.Y - origin.Y, dest.X - origin.X))
                                    end
                                else
                                    if lines[char] then
                                        lines[char]:Destroy()
                                        lines[char] = nil
                                    end
                                end
                            end
                        end
                        task.wait()
                    end
                    for _, line in lines do
                        line:Destroy()
                    end
                end)
            end
        end
    })
end)

task.defer(function()
    TabSections.World:CreateToggle({
        Name = "AutoBuy",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    while AutoBuy.Enabled do
                        local state = Skywars.Services.Store:getState()
                        if state and state.GameCurrency then
                            local currency = table.clone(state.GameCurrency.Quantities)
                            if Skywars.Store.tools.sword then
                                local name = Skywars.Store.tools.sword.Name
                                local shop = Skywars.Services.Shop.Blacksmith.ItemUpgrades[2]
                                if shop then
                                    local currentItem
                                    for i, item in shop.Items do
                                        if item.ItemType == name then currentItem = i end
                                    end
                                    if currentItem then
                                        for i = currentItem + 1, #shop.Items do
                                            local nextItem = shop.Items[i]
                                            if nextItem and currency[nextItem.CurrencyType] >= nextItem.Price then
                                                Skywars.Remotes.purchaseItemUpgrade:fire('Blacksmith', shop.ItemIndex)
                                                currency[nextItem.CurrencyType] -= nextItem.Price
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        task.wait(1)
                    end
                end)
            end
        end
    })
end)

task.defer(function()
    TabSections.Visual:CreateToggle({
        Name = "Fullbright",
        Callback = function(callback)
            if callback then
                Lighting.Brightness = 5
                Lighting.Ambient = Color3.new(1, 1, 1)
            else
                Lighting.Brightness = 2
                Lighting.Ambient = Color3.new(0, 0, 0)
            end
        end
    })
end)

task.defer(function()
    TabSections.Player:CreateToggle({
        Name = "No Fall",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    local groundPos = Vector3.zero
                    while NoFall.Enabled do
                        if Skywars:IsAlive() then
                            local root = LocalPlayer.Character.PrimaryPart
                            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                            if hum.FloorMaterial ~= Enum.Material.Air then
                                groundPos = root.Position
                            end
                            if (groundPos.Y - root.Position.Y) > 10 then
                                local rayParams = RaycastParams.new()
                                rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
                                local ray = workspace:Raycast(root.Position, Vector3.new(0, -hum.HipHeight - 10, 0), rayParams)
                                if not ray then
                                    hum:ChangeState(Enum.HumanoidStateType.Ragdoll)
                                    task.wait(0.1)
                                    hum:ChangeState(Enum.HumanoidStateType.Running)
                                end
                            end
                        end
                        task.wait(0.05)
                    end
                end)
            end
        end
    })
end)

task.defer(function()
    local EggAura = TabSections.Minigames:CreateToggle({
        Name = "Egg Aura",
        Callback = function(callback)
            if callback then
                task.spawn(function()
                    while EggAura.Enabled do
                        if Skywars:IsAlive() and Skywars.Store.tools.pickaxe then
                            local egg = Skywars:GetNearestEgg(EggRange)
                            if egg then
                                local camState = Skywars:FreezeCamera()
                                local root = LocalPlayer.Character.PrimaryPart
                                local origCF = root.CFrame
                                root.CFrame = CFrame.new(egg.PrimaryPart.Position + Vector3.new(0, 4, 0))
                                Skywars:BreakBlock(egg)
                                task.wait(0.05)
                                pcall(function() root.CFrame = origCF end)
                                Skywars:RestoreCamera(camState)
                                task.wait(0.2)
                            end
                        end
                        task.wait(0.1)
                    end
                end)
            end
        end
    })
    local EggRange = 50
    EggAura:CreateSlider({
        Name = "Range",
        Min = 1,
        Max = 100,
        Default = 50,
        Callback = function(value)
            EggRange = value
        end
    })
end)
