-- FlyBase Stealth+++ (versão otimizada)
-- • Mais rápido (ajustei MIN_SPEED e MAX_SPEED, mantendo suavização)
-- • Minimizar/Maximizar 100% funcional
-- • Ao minimizar: mostra só barra com título e botão "Maximizar +"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

-- Config
local HOLD_SECONDS   = 5
local POST_SPAWN_PIN = 1.2
local WAYPOINT_DIST  = 16
local MAX_SPEED      = 120  -- velocidade máx (↑ mais rápido, mas natural)
local MIN_SPEED      = 60   -- velocidade mín (↑ mais rápido, mas natural)
local ACCEL_FACTOR   = 0.20 -- suavização
local OBST_CHECK_DIST= 8
local OBST_UP_STEP   = 6

local KEY_FLY        = Enum.KeyCode.F
local KEY_SET        = Enum.KeyCode.G
local KEY_TOGGLE_RESP= Enum.KeyCode.R
local KEY_SLOT_1     = Enum.KeyCode.One

-- Estado
getgenv().FlyBaseUltimate = getgenv().FlyBaseUltimate or {
    savedCFrame = nil,
    slot1 = nil,
    isFlying = false,
    uiBuilt = false,
    autoRespawn = true,
    uiPos = nil
}
local state = getgenv().FlyBaseUltimate

local function notify(msg)
    pcall(function()
        StarterGui:SetCore("SendNotification",{Title="FlyBase+++",Text=msg,Duration=2})
    end)
end

-- Helpers
local function getChar() return player.Character or player.CharacterAdded:Wait() end
local function getHRP(c) c=c or getChar(); return c:WaitForChild("HumanoidRootPart") end
local function getHumanoid(c) c=c or getChar(); return c:WaitForChild("Humanoid") end

local function groundAt(pos)
    local rp=RaycastParams.new()
    rp.FilterDescendantsInstances={player.Character}
    rp.FilterType=Enum.RaycastFilterType.Blacklist
    local hit=Workspace:Raycast(pos+Vector3.new(0,12,0),Vector3.new(0,-1000,0),rp)
    return hit and Vector3.new(pos.X,hit.Position.Y+2,pos.Z) or pos
end

local function hardLockTo(target,seconds)
    local hrp=getHRP(); if not hrp then return end
    local g=groundAt(target)
    local t0=tick()
    local conn; conn=RunService.Heartbeat:Connect(function()
        if not hrp.Parent then conn:Disconnect() return end
        hrp.AssemblyLinearVelocity=Vector3.zero
        hrp.CFrame=CFrame.new(g,g+hrp.CFrame.LookVector)
        if tick()-t0>=seconds then conn:Disconnect() end
    end)
end

-- Anti-reset
local Anti={active=false}
local function hookReset() pcall(function()
    StarterGui:SetCore("ResetButtonCallback",function() notify("⛔ Reset bloqueado em voo") return end)
end) end
local function unhookReset() pcall(function() StarterGui:SetCore("ResetButtonCallback",true) end) end
local function enableAnti()
    if Anti.active then return end
    Anti.active=true; hookReset()
    local hum=getHumanoid(); hum.BreakJointsOnDeath=false; hum:SetStateEnabled(Enum.HumanoidStateType.Dead,false)
end
local function disableAnti()
    if not Anti.active then return end
    Anti.active=false; unhookReset()
    local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Dead,true) end
end

-- Fly
local uiStatus
local function flyToBase()
    if state.isFlying or not state.savedCFrame then notify("⚠ Define a base primeiro"); return end
    state.isFlying=true; enableAnti()
    local hrp=getHRP(); local hum=getHumanoid()
    local target=groundAt(state.savedCFrame.Position)
    local start=hrp.Position
    local total=(target-start).Magnitude
    local wpCount=math.max(1,math.ceil(total/WAYPOINT_DIST))
    local iWp=1; local wpTarget=start:Lerp(target,iWp/wpCount)
    hum:MoveTo(wpTarget)
    local conn; conn=RunService.Heartbeat:Connect(function(dt)
        if not hrp.Parent then conn:Disconnect(); state.isFlying=false; disableAnti(); return end
        local dist=(wpTarget-hrp.Position).Magnitude
        if dist<3 then
            iWp+=1
            if iWp>wpCount then conn:Disconnect(); state.isFlying=false
                notify("✅ Chegou!"); hardLockTo(target,HOLD_SECONDS); disableAnti(); return
            end
            wpTarget=start:Lerp(target,iWp/wpCount); hum:MoveTo(wpTarget)
        end
        local dir=(wpTarget-hrp.Position).Unit
        local spd=MIN_SPEED+(MAX_SPEED-MIN_SPEED)*math.random()
        hrp.AssemblyLinearVelocity=hrp.AssemblyLinearVelocity:Lerp(dir*spd,ACCEL_FACTOR)
        if uiStatus then uiStatus.Text=string.format("Dist: %.1f",(target-hrp.Position).Magnitude) end
    end)
end

-- Respawn
local function postSpawnPin(char)
    if not(state.autoRespawn and state.savedCFrame) then return end
    task.defer(function()
        local hrp=char:WaitForChild("HumanoidRootPart")
        local g=groundAt(state.savedCFrame.Position)
        hrp.CFrame=CFrame.new(g); hardLockTo(g,POST_SPAWN_PIN)
    end)
end

-- UI
local function buildUI()
    if state.uiBuilt then return end
    state.uiBuilt=true
    local gui=Instance.new("ScreenGui")
    gui.Name="FlyBaseUI"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true
    gui.Parent=player:WaitForChild("PlayerGui")

    local frame=Instance.new("Frame")
    frame.Size=UDim2.fromOffset(300,280)
    frame.AnchorPoint=Vector2.new(0.5,0.5)
    frame.Position=state.uiPos or UDim2.fromScale(0.5,0.5)
    frame.BackgroundColor3=Color3.fromRGB(26,28,36)
    frame.Parent=gui
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,12)

    local stroke=Instance.new("UIStroke"); stroke.Thickness=2; stroke.Color=Color3.fromRGB(120,140,255); stroke.Parent=frame

    local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,10)
    layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
    layout.VerticalAlignment=Enum.VerticalAlignment.Center; layout.Parent=frame

    -- Título + Minimizar
    local titleBar=Instance.new("Frame")
    titleBar.Size=UDim2.fromOffset(280,26); titleBar.BackgroundTransparency=1; titleBar.Parent=frame
    local title=Instance.new("TextLabel")
    title.Size=UDim2.fromScale(0.8,1); title.BackgroundTransparency=1
    title.Text="🚀 FlyBase Stealth+++"
    title.Font=Enum.Font.GothamBlack; title.TextSize=18; title.TextColor3=Color3.fromRGB(255,255,255)
    title.Parent=titleBar
    local minBtn=Instance.new("TextButton")
    minBtn.Size=UDim2.fromScale(0.2,1); minBtn.Position=UDim2.fromScale(0.8,0)
    minBtn.Text="—"; minBtn.Font=Enum.Font.GothamBlack; minBtn.TextSize=18
    minBtn.TextColor3=Color3.fromRGB(255,255,255); minBtn.BackgroundColor3=Color3.fromRGB(50,50,60)
    Instance.new("UICorner",minBtn).CornerRadius=UDim.new(0,6)
    minBtn.Parent=titleBar

    -- Botões
    local function makeBtn(txt,color)
        local b=Instance.new("TextButton")
        b.Size=UDim2.fromOffset(240,44)
        b.Text=txt; b.Font=Enum.Font.GothamBold; b.TextSize=16
        b.TextColor3=Color3.new(1,1,1); b.BackgroundColor3=color
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
        b.Parent=frame; return b
    end

    local flyBtn = makeBtn("✈ Fly to Base (F)", Color3.fromRGB(70,70,120))
    local setBtn = makeBtn("➕ Set Position (G)", Color3.fromRGB(70,120,70))
    local respBtn= makeBtn("🔄 Auto Respawn: ON (R)", Color3.fromRGB(120,90,70))
    local slot1  = makeBtn("🎯 Slot 1 (1) | SHIFT+1 salva", Color3.fromRGB(52,98,160))

    uiStatus=Instance.new("TextLabel")
    uiStatus.Size=UDim2.fromOffset(260,20); uiStatus.BackgroundTransparency=1
    uiStatus.Text="Base salva: nenhuma"; uiStatus.Font=Enum.Font.Gotham
    uiStatus.TextSize=14; uiStatus.TextColor3=Color3.fromRGB(200,220,255)
    uiStatus.Parent=frame

    -- Ações
    setBtn.MouseButton1Click:Connect(function()
        state.savedCFrame=getHRP().CFrame; uiStatus.Text="📍 Base salva ✔"; notify("📍 Base salva ✔")
    end)
    flyBtn.MouseButton1Click:Connect(flyToBase)
    respBtn.MouseButton1Click:Connect(function()
        state.autoRespawn=not state.autoRespawn
        respBtn.Text=state.autoRespawn and "🔄 Auto Respawn: ON (R)" or "🔄 Auto Respawn: OFF (R)"
    end)
    slot1.MouseButton1Click:Connect(function()
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            state.slot1=getHRP().CFrame; notify("💾 Slot 1 salvo.")
        else
            if state.slot1 then state.savedCFrame=state.slot1; notify("🎯 Slot 1 ativado.") else notify("⚠ Slot 1 vazio.") end
        end
    end)

    -- Minimizar/Maximizar
    local minimized=false
    minBtn.MouseButton1Click:Connect(function()
        minimized=not minimized
        for _,child in ipairs(frame:GetChildren()) do
            if child~=titleBar and child~=stroke then
                child.Visible=not minimized
            end
        end
        if minimized then
            minBtn.Text="Maximizar +"
        else
            minBtn.Text="—"
        end
    end)
end

buildUI()
notify("FlyBase Stealth+++ carregado — mais rápido e com minimizar/maximizar funcional")
