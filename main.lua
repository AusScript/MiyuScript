-- Miyu | Defusal Mobile
local urlList = {
    "https://sirius.menu/gen2",
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
}

local candidates = {}
for _, url in ipairs(urlList) do
    local ok, r = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and r and (type(r) == "table" or type(r) == "userdata") then
        table.insert(candidates, { url = url, lib = r })
    end
end
if #candidates == 0 then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Camera = workspace.CurrentCamera
local LP = Players.LocalPlayer

local S = {
    Aim = { Enabled=false, FOV=120, Smooth=0.35, Part="auto", Wall=true, Team=true, VisFOV=true },
    Silent = { Enabled=false, FOV=150, Part="auto", Wall=true, Team=true },
    Trigger = { Enabled=false, Delay=0.05, Team=true },
    ESP = { Enabled=false, Box=true, HP=true, Name=true, Dist=true, Team=true },
    Move = { Bhop=false, Strafe=false },
    Vis = { Shaders=false, Fullbright=false, Jump=false, Walk=false, JumpCol=Color3.fromRGB(0,200,255), WalkCol=Color3.fromRGB(255,200,0) },
    Gren = { Enabled=false, Speed=70, Col=Color3.fromRGB(255,120,0) },
    Misc = { AntiAFK=false },
}
local lastTrig = 0

local function guiParent()
    if gethui then local ok,h = pcall(gethui); if ok and h then return h end end
    local ok,cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then local t=Instance.new("Folder"); local ok2=pcall(function() t.Parent=cg end); if ok2 then t:Destroy(); return cg end; t:Destroy() end
    return LP:WaitForChild("PlayerGui")
end
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Miyu"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = guiParent()

local function draggable(text, color, onClick, pos)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,60,0,60)
    b.Position = pos or UDim2.new(0,20,0.5,-30)
    b.BackgroundColor3 = color
    b.BackgroundTransparency = 0.25
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.AutoButtonColor = false
    b.Parent = screenGui
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = b
    local drag, sPos, sBtn, moved = false, nil, nil, 0
    b.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=true; sPos=i.Position; sBtn=b.Position; moved=0
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-sPos; moved=d.Magnitude
            b.Position = UDim2.new(sBtn.X.Scale, sBtn.X.Offset+d.X, sBtn.Y.Scale, sBtn.Y.Offset+d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch) then
            drag=false; if moved<8 and onClick then onClick() end
        end
    end)
    return b
end

local FOV = Drawing.new("Circle")
FOV.Thickness=1; FOV.NumSides=64; FOV.Filled=false; FOV.Transparency=0.6
FOV.Color=Color3.fromRGB(255,255,255); FOV.Visible=false
RunService.RenderStepped:Connect(function()
    local show = S.Aim.Enabled and S.Aim.VisFOV
    FOV.Visible = show
    if show then
        FOV.Radius = S.Aim.FOV
        FOV.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    end
end)

local function targetPart(char, pref)
    if not char then return nil end
    if pref and pref~="auto" then local p=char:FindFirstChild(pref); if p and p:IsA("BasePart") then return p end end
    for _,n in ipairs({"Head","UpperTorso","Torso","HumanoidRootPart","LowerTorso"}) do
        local p=char:FindFirstChild(n); if p and p:IsA("BasePart") then return p end
    end
    for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then return p end end
    return nil
end
local function teammate(pl)
    if not LP.Team or not pl.Team then return false end
    return pl.Team == LP.Team
end
local function los(part)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {LP.Character, Camera}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local hit = workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, rp)
    if hit then return hit.Instance:IsDescendantOf(part.Parent) end
    return true
end
local function closestTarget(fov, team, wall, pref)
    local best, bestD = nil, fov
    local c = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _,pl in ipairs(Players:GetPlayers()) do
        if pl~=LP and not (team and teammate(pl)) then
            local ch = pl.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health>0 then
                local pt = targetPart(ch, pref)
                if pt then
                    local sp, on = Camera:WorldToViewportPoint(pt.Position)
                    if on then
                        local d = (Vector2.new(sp.X, sp.Y) - c).Magnitude
                        if d < bestD and (not wall or los(pt)) then best=pt; bestD=d end
                    end
                end
            end
        end
    end
    return best
end

RunService.RenderStepped:Connect(function()
    if not S.Aim.Enabled then return end
    local t = closestTarget(S.Aim.FOV, S.Aim.Team, S.Aim.Wall, S.Aim.Part)
    if t then
        local goal = CFrame.lookAt(Camera.CFrame.Position, t.Position)
        Camera.CFrame = Camera.CFrame:Lerp(goal, 1-S.Aim.Smooth)
    end
end)
_G.MiyuSilent = nil
RunService.RenderStepped:Connect(function()
    _G.MiyuSilent = S.Silent.Enabled and closestTarget(S.Silent.FOV, S.Silent.Team, S.Silent.Wall, S.Silent.Part) or nil
end)
RunService.Heartbeat:Connect(function()
    if not S.Trigger.Enabled or tick()-lastTrig < S.Trigger.Delay then return end
    local c = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _,pl in ipairs(Players:GetPlayers()) do
        if pl~=LP and not (S.Trigger.Team and teammate(pl)) then
            local ch = pl.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health>0 then
                local h = targetPart(ch, "Head")
                if h then
                    local sp,on = Camera:WorldToViewportPoint(h.Position)
                    if on and (Vector2.new(sp.X,sp.Y)-c).Magnitude<30 and los(h) then
                        local vim = game:GetService("VirtualInputManager")
                        vim:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 1)
                        vim:SendMouseButtonEvent(c.X, c.Y, 0, false, game, 1)
                        lastTrig = tick(); break
                    end
                end
            end
        end
    end
end)

local espCache = {}
local function makeESP(pl)
    if pl==LP or espCache[pl] then return end
    local box=Drawing.new("Square"); box.Thickness=1; box.Filled=false; box.Color=Color3.fromRGB(255,60,60); box.Visible=false
    local nm=Drawing.new("Text"); nm.Size=13; nm.Center=true; nm.Outline=true; nm.Color=Color3.fromRGB(255,255,255); nm.Visible=false
    local bg=Drawing.new("Square"); bg.Filled=true; bg.Color=Color3.fromRGB(0,0,0); bg.Visible=false
    local fill=Drawing.new("Square"); fill.Filled=true; fill.Color=Color3.fromRGB(0,255,0); fill.Visible=false
    local dt=Drawing.new("Text"); dt.Size=12; dt.Center=true; dt.Outline=true; dt.Color=Color3.fromRGB(200,200,200); dt.Visible=false
    espCache[pl]={Box=box, Name=nm, Bg=bg, Fill=fill, Dist=dt}
end
local function updESP()
    for pl,e in pairs(espCache) do
        local ch = pl.Character
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        local head = ch and targetPart(ch, "Head")
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        local hide = (not S.ESP.Enabled) or (not root) or (not head) or (not hum) or hum.Health<=0 or (S.ESP.Team and teammate(pl))
        if hide then
            e.Box.Visible=false; e.Name.Visible=false; e.Bg.Visible=false; e.Fill.Visible=false; e.Dist.Visible=false
        else
            local rp, ron = Camera:WorldToViewportPoint(root.Position)
            local hp, hon = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
            if ron and hon then
                local hgt = math.abs(hp.Y-rp.Y)
                local w = hgt*0.5
                local x,y = rp.X-w/2, hp.Y
                e.Box.Size=Vector2.new(w,hgt); e.Box.Position=Vector2.new(x,y); e.Box.Visible=S.ESP.Box
                e.Name.Text=pl.Name; e.Name.Position=Vector2.new(rp.X, y-16); e.Name.Visible=S.ESP.Name
                local pct=hum.Health/hum.MaxHealth; local bh=hgt*pct
                e.Bg.Size=Vector2.new(3,hgt); e.Bg.Position=Vector2.new(x-6,y); e.Bg.Visible=S.ESP.HP
                e.Fill.Size=Vector2.new(3,bh); e.Fill.Position=Vector2.new(x-6, y+hgt-bh)
                e.Fill.Color=Color3.fromRGB(255*(1-pct), 255*pct, 0); e.Fill.Visible=S.ESP.HP
                e.Dist.Text=string.format("[%d]", math.floor((Camera.CFrame.Position-root.Position).Magnitude))
                e.Dist.Position=Vector2.new(rp.X, y+hgt+2); e.Dist.Visible=S.ESP.Dist
            else
                e.Box.Visible=false; e.Name.Visible=false; e.Bg.Visible=false; e.Fill.Visible=false; e.Dist.Visible=false
            end
        end
    end
end
RunService.RenderStepped:Connect(function()
    if not S.ESP.Enabled then return end
    for _,pl in ipairs(Players:GetPlayers()) do makeESP(pl) end
    updESP()
end)

local bhopConn, strafeConn
local function bhopOn()
    if bhopConn then return end
    bhopConn = RunService.Heartbeat:Connect(function()
        if not S.Move.Bhop then return end
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h and h:GetState()==Enum.HumanoidStateType.Freefall then h.Jump=true end
    end)
end
local function bhopOff() if bhopConn then bhopConn:Disconnect(); bhopConn=nil end end

local function strafeOn()
    if strafeConn then return end
    strafeConn = RunService.Heartbeat:Connect(function()
        if not S.Move.Strafe then return end
        local ch = LP.Character
        local h = ch and ch:FindFirstChildOfClass("Humanoid")
        local r = ch and ch:FindFirstChild("HumanoidRootPart")
        if h and r and h:GetState()==Enum.HumanoidStateType.Freefall then
            local v = r.AssemblyLinearVelocity
            local f = Vector3.new(v.X,0,v.Z)
            if f.Magnitude>=5 then h:Move(Vector3.new(-f.Unit.Z,0,f.Unit.X), false) end
        end
    end)
end
local function strafeOff() if strafeConn then strafeConn:Disconnect(); strafeConn=nil end end

local shaders = {}
local function applyShaders()
    if S.Vis.Shaders and #shaders==0 then
        local b=Instance.new("BloomEffect"); b.Intensity=0.4; b.Size=20; b.Threshold=0.85; b.Enabled=true; b.Parent=Camera
        local cc=Instance.new("ColorCorrectionEffect"); cc.Brightness=0.05; cc.Contrast=0.3; cc.Saturation=0.2; cc.TintColor=Color3.fromRGB(255,245,230); cc.Enabled=true; cc.Parent=Camera
        local s=Instance.new("SunRaysEffect"); s.Intensity=0.1; s.Spread=0.7; s.Enabled=true; s.Parent=Camera
        local bl=Instance.new("BlurEffect"); bl.Size=2; bl.Enabled=true; bl.Parent=Camera
        for _,i in ipairs({b,cc,s,bl}) do table.insert(shaders,i) end
    elseif not S.Vis.Shaders and #shaders>0 then
        for _,i in ipairs(shaders) do i:Destroy() end
        shaders={}
    end
end
local sAmb, sOut
local function applyFB()
    if S.Vis.Fullbright then
        sAmb = sAmb or Lighting.Ambient
        sOut = sOut or Lighting.OutdoorAmbient
        Lighting.Ambient = Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
        Lighting.Brightness = 2
    else
        if sAmb then Lighting.Ambient=sAmb end
        if sOut then Lighting.OutdoorAmbient=sOut end
        Lighting.Brightness = 1
    end
end

local trails = {}
local function addTrail(pos, col)
    local ray = workspace:Raycast(pos, Vector3.new(0,-50,0))
    local gp = ray and ray.Position or (pos - Vector3.new(0,3,0))
    local c = Drawing.new("Circle")
    c.Thickness=2; c.NumSides=32; c.Filled=false; c.Color=col; c.Visible=false; c.Transparency=1
    table.insert(trails, {C=c, P=gp, L=1.5, M=1.5})
end
local lastState
RunService.Heartbeat:Connect(function()
    if not S.Vis.Jump then lastState=nil; return end
    local ch=LP.Character; local h=ch and ch:FindFirstChildOfClass("Humanoid"); local r=ch and ch:FindFirstChild("HumanoidRootPart")
    if not h or not r then return end
    local st=h:GetState()
    if st==Enum.HumanoidStateType.Jumping and lastState~=Enum.HumanoidStateType.Jumping then
        addTrail(r.Position, S.Vis.JumpCol)
    end
    lastState=st
end)
local lastWalk
RunService.Heartbeat:Connect(function()
    if not S.Vis.Walk then lastWalk=nil; return end
    local ch=LP.Character; local h=ch and ch:FindFirstChildOfClass("Humanoid"); local r=ch and ch:FindFirstChild("HumanoidRootPart")
    if not h or not r or h:GetState()~=Enum.HumanoidStateType.Running then return end
    if not lastWalk or (r.Position-lastWalk).Magnitude>3 then
        addTrail(r.Position, S.Vis.WalkCol); lastWalk=r.Position
    end
end)
RunService.RenderStepped:Connect(function(dt)
    for i=#trails,1,-1 do
        local t=trails[i]; t.L = t.L - dt
        if t.L<=0 then t.C:Remove(); table.remove(trails,i)
        else
            local sp,on=Camera:WorldToViewportPoint(t.P)
            if on and sp.Z>0 then
                t.C.Position=Vector2.new(sp.X,sp.Y)
                t.C.Radius=math.clamp(200/math.max((Camera.CFrame.Position-t.P).Magnitude,1),4,60)
                t.C.Transparency=(t.L/t.M)*0.8
                t.C.Visible=true
            else t.C.Visible=false end
        end
    end
end)

local gDots = {}
local gLand = Drawing.new("Circle")
gLand.Thickness=2; gLand.NumSides=32; gLand.Filled=false; gLand.Color=Color3.fromRGB(255,60,60); gLand.Visible=false
local function clearG()
    for _,d in ipairs(gDots) do d:Remove() end
    gDots={}
end
RunService.RenderStepped:Connect(function()
    if not S.Gren.Enabled then clearG(); gLand.Visible=false; return end
    local dir = Camera.CFrame.LookVector
    local p = Camera.CFrame.Position + dir*2
    local v = dir*S.Gren.Speed
    local dt=0.03
    local g = Vector3.new(0,-workspace.Gravity,0)
    local pts, land = {}, nil
    for i=1,300 do
        local nv = v + g*dt
        local np = p + nv*dt
        local hit = workspace:Raycast(p, np-p)
        if hit then land=hit.Position; table.insert(pts, hit.Position); break end
        p,v = np,nv
        if i%3==0 then table.insert(pts,p) end
        if p.Y<-50 then break end
    end
    while #gDots<#pts do
        local c=Drawing.new("Circle"); c.Radius=3; c.Thickness=1; c.Filled=true; c.Color=S.Gren.Col; c.Visible=false
        table.insert(gDots,c)
    end
    while #gDots>#pts do table.remove(gDots):Remove() end
    for i,pt in ipairs(pts) do
        local sp,on=Camera:WorldToViewportPoint(pt)
        if on and sp.Z>0 then gDots[i].Position=Vector2.new(sp.X,sp.Y); gDots[i].Visible=true
        else gDots[i].Visible=false end
    end
    if land then
        local sp,on=Camera:WorldToViewportPoint(land)
        if on and sp.Z>0 then
            gLand.Position=Vector2.new(sp.X,sp.Y)
            gLand.Radius=math.clamp(300/math.max((Camera.CFrame.Position-land).Magnitude,1),8,80)
            gLand.Color=S.Gren.Col; gLand.Visible=true
        else gLand.Visible=false end
    else gLand.Visible=false end
end)

local afkConn
local function afkOn()
    if afkConn then return end
    afkConn = LP.Idled:Connect(function()
        local v = game:GetService("VirtualUser"); v:CaptureController(); v:ClickButton2(Vector2.new())
    end)
end
local function afkOff() if afkConn then afkConn:Disconnect(); afkConn=nil end end

-- ============================================================
-- WINDOW + KEY SYSTEM
-- ============================================================
local Window
for _, c in ipairs(candidates) do
    local ok, w = pcall(function()
        return c.lib:CreateWindow({
            Name = "Miyu",
            LoadingTitle = "Miyu",
            Theme = "Default",
            ToggleUIKeybind = "K",
            ConfigurationSaving = { Enabled = false },
            Discord = { Enabled = false },
            KeySystem = true,
            KeySettings = {
                Title = "Miyu | Key",
                Subtitle = "Enter key to continue",
                Note = "Get key: https://t.me/Tyyoiv",
                FileName = "MiyuKey",
                SaveKey = true,
                GrabKeyFromSite = false,
                Key = { "Miyu-Free/Hub-Defusal" },
            },
        })
    end)
    if ok and w then Window = w; break end
end
if not Window then return end

local function makeTab(name)
    local ok, t = pcall(function() return Window:CreateTab(name) end)
    if ok and t then return t end
    ok, t = pcall(function() return Window:CreateTab({ name = name }) end)
    if ok and t then return t end
    return nil
end
local function safe(fn)
    pcall(fn)
end
local function section(tab, name)
    if not tab then return end
    safe(function() tab:CreateSection(name) end)
    safe(function() tab:CreateSection({ name = name }) end)
end

local AimTab = makeTab("Aim")
if AimTab then
    local aimToggle
    safe(function()
        aimToggle = AimTab:CreateToggle({
            Name = "Aimbot", CurrentValue = false, Flag = "aim_on",
            Callback = function(v)
                S.Aim.Enabled = v
                if _G.MiyuAimBtn then
                    _G.MiyuAimBtn.BackgroundColor3 = v and Color3.fromRGB(200,50,50) or Color3.fromRGB(60,60,60)
                end
            end,
        })
    end)
    safe(function() AimTab:CreateSlider({ Name="FOV", Range={30,400}, Increment=5, Suffix="px", CurrentValue=120, Flag="aim_fov", Callback=function(v) S.Aim.FOV=v end }) end)
    safe(function() AimTab:CreateSlider({ Name="Smoothness", Range={0.05,0.95}, Increment=0.05, CurrentValue=0.35, Flag="aim_smooth", Callback=function(v) S.Aim.Smooth=v end }) end)
    safe(function() AimTab:CreateDropdown({ Name="Target Part", Options={"auto","Head","UpperTorso","Torso","HumanoidRootPart"}, CurrentOption={"auto"}, Flag="aim_part", Callback=function(o) S.Aim.Part=o[1] end }) end)
    safe(function() AimTab:CreateToggle({ Name="Wall Check", CurrentValue=true, Flag="aim_wall", Callback=function(v) S.Aim.Wall=v end }) end)
    safe(function() AimTab:CreateToggle({ Name="Team Check", CurrentValue=true, Flag="aim_team", Callback=function(v) S.Aim.Team=v end }) end)
    safe(function() AimTab:CreateToggle({ Name="Show FOV", CurrentValue=true, Flag="aim_fovvis", Callback=function(v) S.Aim.VisFOV=v end }) end)

    section(AimTab, "Silent Aim")
    safe(function() AimTab:CreateToggle({ Name="Silent Aim", CurrentValue=false, Flag="sil_on", Callback=function(v) S.Silent.Enabled=v end }) end)
    safe(function() AimTab:CreateSlider({ Name="Silent FOV", Range={50,500}, Increment=10, CurrentValue=150, Flag="sil_fov", Callback=function(v) S.Silent.FOV=v end }) end)
    safe(function() AimTab:CreateToggle({ Name="Silent Wall", CurrentValue=true, Flag="sil_wall", Callback=function(v) S.Silent.Wall=v end }) end)
    safe(function() AimTab:CreateToggle({ Name="Silent Team", CurrentValue=true, Flag="sil_team", Callback=function(v) S.Silent.Team=v end }) end)

    section(AimTab, "Triggerbot")
    safe(function() AimTab:CreateToggle({ Name="Triggerbot", CurrentValue=false, Flag="trig_on", Callback=function(v) S.Trigger.Enabled=v end }) end)
    safe(function() AimTab:CreateSlider({ Name="Trigger Delay", Range={0,500}, Increment=10, Suffix="ms", CurrentValue=50, Flag="trig_delay", Callback=function(v) S.Trigger.Delay=v/1000 end }) end)
end

local VisTab = makeTab("Visuals")
if VisTab then
    safe(function() VisTab:CreateToggle({ Name="ESP", CurrentValue=false, Flag="esp_on", Callback=function(v) S.ESP.Enabled=v end }) end)
    safe(function() VisTab:CreateToggle({ Name="Box", CurrentValue=true, Flag="esp_box", Callback=function(v) S.ESP.Box=v end }) end)
    safe(function() VisTab:CreateToggle({ Name="Health", CurrentValue=true, Flag="esp_hp", Callback=function(v) S.ESP.HP=v end }) end)
    safe(function() VisTab:CreateToggle({ Name="Name", CurrentValue=true, Flag="esp_name", Callback=function(v) S.ESP.Name=v end }) end)
    safe(function() VisTab:CreateToggle({ Name="Distance", CurrentValue=true, Flag="esp_dist", Callback=function(v) S.ESP.Dist=v end }) end)
    safe(function() VisTab:CreateToggle({ Name="Team Check", CurrentValue=true, Flag="esp_team", Callback=function(v) S.ESP.Team=v end }) end)

    section(VisTab, "Trails")
    safe(function() VisTab:CreateToggle({ Name="Jump Trail", CurrentValue=false, Flag="jt", Callback=function(v) S.Vis.Jump=v end }) end)
    safe(function() VisTab:CreateColorPicker({ Name="Jump Color", Color=S.Vis.JumpCol, Flag="jtc", Callback=function(c) S.Vis.JumpCol=c end }) end)
    safe(function() VisTab:CreateToggle({ Name="Walk Trail", CurrentValue=false, Flag="wt", Callback=function(v) S.Vis.Walk=v end }) end)
    safe(function() VisTab:CreateColorPicker({ Name="Walk Color", Color=S.Vis.WalkCol, Flag="wtc", Callback=function(c) S.Vis.WalkCol=c end }) end)

    section(VisTab, "Grenade")
    safe(function() VisTab:CreateToggle({ Name="Grenade Trajectory", CurrentValue=false, Flag="gr_on", Callback=function(v) S.Gren.Enabled=v end }) end)
    safe(function() VisTab:CreateSlider({ Name="Throw Speed", Range={30,150}, Increment=5, CurrentValue=70, Flag="gr_spd", Callback=function(v) S.Gren.Speed=v end }) end)
    safe(function() VisTab:CreateColorPicker({ Name="Trajectory Color", Color=S.Gren.Col, Flag="gr_col", Callback=function(c) S.Gren.Col=c end }) end)

    section(VisTab, "Render")
    safe(function() VisTab:CreateToggle({ Name="Cinematic Shaders", CurrentValue=false, Flag="sh", Callback=function(v) S.Vis.Shaders=v; applyShaders() end }) end)
    safe(function() VisTab:CreateToggle({ Name="Fullbright", CurrentValue=false, Flag="fb", Callback=function(v) S.Vis.Fullbright=v; applyFB() end }) end)
end

local MoveTab = makeTab("Movement")
if MoveTab then
    safe(function() MoveTab:CreateToggle({ Name="Bhop", CurrentValue=false, Flag="bhop", Callback=function(v) S.Move.Bhop=v; if v then bhopOn() else bhopOff() end end }) end)
    safe(function() MoveTab:CreateToggle({ Name="Auto Strafe", CurrentValue=false, Flag="strafe", Callback=function(v) S.Move.Strafe=v; if v then strafeOn() else strafeOff() end end }) end)
    safe(function() MoveTab:CreateSlider({ Name="WalkSpeed", Range={16,200}, Increment=1, CurrentValue=16, Flag="ws", Callback=function(v) local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid"); if h then h.WalkSpeed=v end end }) end)
    safe(function() MoveTab:CreateSlider({ Name="JumpPower", Range={50,300}, Increment=5, CurrentValue=50, Flag="jp", Callback=function(v) local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid"); if h then h.JumpPower=v; h.UseJumpPower=true end end }) end)
end

local MiscTab = makeTab("Misc")
if MiscTab then
    safe(function() MiscTab:CreateToggle({ Name="Anti-AFK", CurrentValue=false, Flag="afk", Callback=function(v) S.Misc.AntiAFK=v; if v then afkOn() else afkOff() end end }) end)
    safe(function() MiscTab:CreateButton({ Name="Unload", Callback=function()
        pcall(function() FOV:Remove() end)
        clearG(); pcall(function() gLand:Remove() end)
        for _,e in pairs(espCache) do for _,d in pairs(e) do pcall(function() d:Remove() end) end end
        for _,i in ipairs(shaders) do pcall(function() i:Destroy() end) end
        for _,t in ipairs(trails) do pcall(function() t.C:Remove() end) end
        if screenGui then screenGui:Destroy() end
        pcall(function() Window:Unload() end)
    end }) end)
end

_G.MiyuAimBtn = draggable("AIM", Color3.fromRGB(60,60,60), function()
    S.Aim.Enabled = not S.Aim.Enabled
    _G.MiyuAimBtn.BackgroundColor3 = S.Aim.Enabled and Color3.fromRGB(200,50,50) or Color3.fromRGB(60,60,60)
end, UDim2.new(0,20,0.5,-80))

local peekPlaced, peekCF, ghost = false, nil, nil
local peekBtn
peekBtn = draggable("PEEK", Color3.fromRGB(60,60,60), function()
    local ch = LP.Character
    local r = ch and ch:FindFirstChild("HumanoidRootPart")
    if not r then return end
    if not peekPlaced then
        peekCF = r.CFrame; peekPlaced = true
        peekBtn.BackgroundColor3 = Color3.fromRGB(60,200,200)
        if ghost then ghost:Destroy() end
        ghost = Instance.new("Part")
        ghost.Size = Vector3.new(2,5,1)
        ghost.CFrame = peekCF
        ghost.Anchored = true
        ghost.CanCollide = false
        ghost.Transparency = 0.7
        ghost.Color = Color3.fromRGB(0,255,200)
        ghost.Material = Enum.Material.Neon
        ghost.Parent = workspace
    else
        local t = peekCF
        peekPlaced = false
        peekBtn.BackgroundColor3 = Color3.fromRGB(60,60,60)
        if ghost then ghost:Destroy(); ghost = nil end
        peekCF = nil
        if t then
            TweenService:Create(r, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = t}):Play()
        end
    end
end, UDim2.new(0,20,0.5,-10))
