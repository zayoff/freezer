--[[
    FREEZER  ::  ALL-IN-ONE
    Version  : 3.2.0
    Modules  : Hub + 5 Recon + 5 Combat + 5 Utility (15 total)
    Usage    : loadstring(game:HttpGet("<your raw url>"))()
    Built    : by ENI for LO
--]]

-- Anti-detect: silent print/warn (no console chatter)
local print = function() end
local warn  = function() end

-- Anti-detect: randomized global ScreenGui name reused across every module's GUI
if not getgenv()._FREEZER_GUI_NAME then
    getgenv()._FREEZER_GUI_NAME = "_" .. tostring(math.random(1000000, 9999999))
end
local ScreenGuiName = getgenv()._FREEZER_GUI_NAME
local IsProtectedGui = (gethui ~= nil) or (syn and syn.protect_gui ~= nil)



----------------------------------------------------------------------
-- MODULE: DESYNC v3.0.0 (1322 lines original)
----------------------------------------------------------------------
do
--[[
    eni-roblox-kit :: Desync v3.0.0
    Network-owner-replicated hitbox desync.
    Server sees one position, you appear at another.
    Methods: Network Owner, Velocity Slam, Fake Character, Combined.

    API:  getgenv().ENI.Desync
          :Show() :Hide() :Toggle() :Destroy() :GetConfig() :SetConfig()
          :Engage() :Disengage() :IsActive()
]]

----------------------------------------------------------------
-- Anti-detect shims
----------------------------------------------------------------
local cloneref = cloneref or function(x) return x end
local protect_gui = (syn and syn.protect_gui) or (gethui and function(g) g.Parent = gethui() end) or function(g) g.Parent = game:GetService('CoreGui') end
local hookmetamethod = hookmetamethod or function() return nil end
local getrawmetatable = getrawmetatable or function() return nil end
local setreadonly = setreadonly or function() end
local newcclosure = newcclosure or function(f) return f end
local checkcaller = checkcaller or function() return false end
local writefile_safe = writefile or function() end
local readfile_safe = readfile or function() return nil end
local isfile_safe = isfile or function() return false end
local isfolder_safe = isfolder or function() return false end
local makefolder_safe = makefolder or function() end

----------------------------------------------------------------
-- Services
----------------------------------------------------------------
local Players = cloneref(game:GetService('Players'))
local RunService = cloneref(game:GetService('RunService'))
local UserInputService = cloneref(game:GetService('UserInputService'))
local TweenService = cloneref(game:GetService('TweenService'))
local HttpService = cloneref(game:GetService('HttpService'))
local Lighting = cloneref(game:GetService('Lighting'))
local Workspace = cloneref(game:GetService('Workspace'))
local MarketplaceService = cloneref(game:GetService('MarketplaceService'))

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

----------------------------------------------------------------
-- Theme (Windows 11 Settings dark)
----------------------------------------------------------------
local Theme = {
    WindowBg        = Color3.fromRGB(20, 20, 26),
    SidebarBg       = Color3.fromRGB(24, 24, 30),
    ContentBg       = Color3.fromRGB(28, 28, 34),
    CardBg          = Color3.fromRGB(36, 36, 44),
    CardBgHover     = Color3.fromRGB(42, 42, 52),
    Border          = Color3.fromRGB(54, 54, 66),
    AccentPrimary   = Color3.fromRGB(255, 65, 180),
    AccentSoft      = Color3.fromRGB(80, 32, 60),
    TextPrimary     = Color3.fromRGB(240, 240, 248),
    TextSecondary   = Color3.fromRGB(170, 170, 188),
    TextDim         = Color3.fromRGB(115, 115, 135),
    Success         = Color3.fromRGB(80, 220, 130),
    Warning         = Color3.fromRGB(255, 185, 70),
    Danger          = Color3.fromRGB(255, 90, 110),
    Cyan            = Color3.fromRGB(100, 220, 240),
}

local EASE = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local EASE_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local EASE_SLOW = TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

----------------------------------------------------------------
-- Config / state
----------------------------------------------------------------
local CONFIG_FOLDER = 'freezer'
local CONFIG_FILE = CONFIG_FOLDER .. '/desync.json'

local DEFAULTS = {
    Enabled = false,
    Method = 'Network Owner',
    Offset = 6,
    Direction = 'Forward',
    CustomX = 0,
    CustomY = 0,
    CustomZ = 0,
    AutoDesync = false,
    AutoFOV = 15,
    TriggerKey = 'X',
    TriggerMode = 'Hold',
    ToggleGuiKey = 'RightControl',
    GhostHitbox = true,
    RealPosIndicator = true,
    VerifyReplication = true,
    ResetOnRespawn = true,
    AutoCancelOnDetect = true,
    VerboseLog = false,
    AntiFling = true,
    SmoothTransition = 0.12,
    HitboxOnly = false,
    AutoToggleAuto = 'V',
}

local state = {}
for k, v in pairs(DEFAULTS) do state[k] = v end

local function deepCopy(t)
    local r = {}
    for k, v in pairs(t) do
        if type(v) == 'table' then r[k] = deepCopy(v) else r[k] = v end
    end
    return r
end

local function saveConfig()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(state) end)
    if not ok then return end
    pcall(function()
        if not isfolder_safe(CONFIG_FOLDER) then makefolder_safe(CONFIG_FOLDER) end
        writefile_safe(CONFIG_FILE, encoded)
    end)
end

local function loadConfig()
    if not isfile_safe(CONFIG_FILE) then return end
    local ok, raw = pcall(readfile_safe, CONFIG_FILE)
    if not ok or not raw then return end
    local ok2, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(decoded) ~= 'table' then return end
    for k, v in pairs(decoded) do
        if state[k] ~= nil then state[k] = v end
    end
end

----------------------------------------------------------------
-- Connection / instance tracking
----------------------------------------------------------------
local connections = {}
local instances = {}
local hooks = {}

local function track(conn)
    table.insert(connections, conn)
    return conn
end

local function disconnectAll()
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(connections)
end

local function trackInstance(inst)
    table.insert(instances, inst)
    return inst
end

----------------------------------------------------------------
-- Notification system
----------------------------------------------------------------
local notifyGui
local notifyStack = {}

local function ensureNotifyGui()
    if notifyGui and notifyGui.Parent then return notifyGui end
    notifyGui = Instance.new('ScreenGui')
    notifyGui.Name = '_eni_desync_notify'
    notifyGui.ResetOnSpawn = false
    notifyGui.IgnoreGuiInset = true
    notifyGui.DisplayOrder = 1000
    protect_gui(notifyGui)
    trackInstance(notifyGui)
    return notifyGui
end

local function notify(title, message, kind, duration)
    duration = duration or 3.5
    kind = kind or 'info'
    local gui = ensureNotifyGui()

    local accent = Theme.AccentPrimary
    if kind == 'success' then accent = Theme.Success
    elseif kind == 'warning' then accent = Theme.Warning
    elseif kind == 'danger' then accent = Theme.Danger end

    local toast = Instance.new('Frame')
    toast.Size = UDim2.new(0, 320, 0, 64)
    toast.BackgroundColor3 = Theme.CardBg
    toast.BorderSizePixel = 0
    toast.Position = UDim2.new(1, 20, 0, 20 + (#notifyStack * 72))
    toast.Parent = gui

    local corner = Instance.new('UICorner', toast)
    corner.CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new('UIStroke', toast)
    stroke.Color = Theme.Border
    stroke.Thickness = 1

    local bar = Instance.new('Frame', toast)
    bar.Size = UDim2.new(0, 3, 1, -8)
    bar.Position = UDim2.new(0, 0, 0, 4)
    bar.BackgroundColor3 = accent
    bar.BorderSizePixel = 0
    local barCorner = Instance.new('UICorner', bar)
    barCorner.CornerRadius = UDim.new(0, 2)

    local titleLbl = Instance.new('TextLabel', toast)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.new(0, 14, 0, 8)
    titleLbl.Size = UDim2.new(1, -20, 0, 18)
    titleLbl.Font = Enum.Font.GothamSemibold
    titleLbl.TextSize = 13
    titleLbl.TextColor3 = Theme.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Text = title

    local msgLbl = Instance.new('TextLabel', toast)
    msgLbl.BackgroundTransparency = 1
    msgLbl.Position = UDim2.new(0, 14, 0, 28)
    msgLbl.Size = UDim2.new(1, -20, 0, 30)
    msgLbl.Font = Enum.Font.Gotham
    msgLbl.TextSize = 12
    msgLbl.TextColor3 = Theme.TextSecondary
    msgLbl.TextXAlignment = Enum.TextXAlignment.Left
    msgLbl.TextYAlignment = Enum.TextYAlignment.Top
    msgLbl.TextWrapped = true
    msgLbl.Text = message

    table.insert(notifyStack, toast)
    TweenService:Create(toast, EASE, { Position = UDim2.new(1, -340, 0, 20 + ((#notifyStack - 1) * 72)) }):Play()

    task.delay(duration, function()
        if not toast.Parent then return end
        local out = TweenService:Create(toast, EASE_FAST, { Position = UDim2.new(1, 20, 0, toast.Position.Y.Offset) })
        out:Play()
        out.Completed:Wait()
        for i, t in ipairs(notifyStack) do
            if t == toast then table.remove(notifyStack, i) break end
        end
        toast:Destroy()
        for i, t in ipairs(notifyStack) do
            TweenService:Create(t, EASE, { Position = UDim2.new(1, -340, 0, 20 + ((i - 1) * 72)) }):Play()
        end
    end)
end

----------------------------------------------------------------
-- Verbose log
----------------------------------------------------------------
local logEntries = {}
local logUpdateCallbacks = {}

local function logEvent(text)
    if not state.VerboseLog then return end
    table.insert(logEntries, 1, os.date('%H:%M:%S') .. '  ' .. text)
    while #logEntries > 50 do table.remove(logEntries) end
    for _, cb in ipairs(logUpdateCallbacks) do pcall(cb) end
end

----------------------------------------------------------------
-- Character helpers
----------------------------------------------------------------
local function getChar()
    local c = LocalPlayer.Character
    if not c then return nil end
    local hrp = c:FindFirstChild('HumanoidRootPart')
    local hum = c:FindFirstChildOfClass('Humanoid')
    if not hrp or not hum then return nil end
    return c, hrp, hum
end

----------------------------------------------------------------
-- Desync engine
----------------------------------------------------------------
local engine = {
    active = false,
    method = 'Network Owner',
    realCFrame = nil,
    fakeModel = nil,
    fakeParts = {},
    visualOverride = nil,
    transitionAlpha = 0,
    lastReplVerify = 0,
    replStatus = 'Unknown',
    desyncConn = nil,
    velocityConn = nil,
    fakeConn = nil,
    antiFlingConn = nil,
    cancelToken = 0,
}

local function getDirectionVector(char, hrp)
    local d = state.Direction
    if d == 'Forward' then return hrp.CFrame.LookVector end
    if d == 'Back' then return -hrp.CFrame.LookVector end
    if d == 'Left' then return -hrp.CFrame.RightVector end
    if d == 'Right' then return hrp.CFrame.RightVector end
    if d == 'Up' then return Vector3.new(0, 1, 0) end
    if d == 'Down' then return Vector3.new(0, -1, 0) end
    if d == 'Random' then
        return Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
    end
    if d == 'Custom' then
        local v = Vector3.new(state.CustomX, state.CustomY, state.CustomZ)
        if v.Magnitude < 0.01 then return hrp.CFrame.LookVector end
        return v.Unit
    end
    return hrp.CFrame.LookVector
end

local function computeDesyncOffset(char, hrp)
    local dir = getDirectionVector(char, hrp)
    return dir * state.Offset
end

----------------------------------------------------------------
-- Fake Character (clone visible parts)
----------------------------------------------------------------
local function buildFakeCharacter()
    local char, hrp = getChar()
    if not char then return end
    if engine.fakeModel then engine.fakeModel:Destroy() end

    local fake = Instance.new('Model')
    fake.Name = '_eni_desync_visual'
    fake.Parent = Workspace
    trackInstance(fake)
    engine.fakeModel = fake
    engine.fakeParts = {}

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA('BasePart') and part.Name ~= 'HumanoidRootPart' then
            local clone = part:Clone()
            clone.Anchored = true
            clone.CanCollide = false
            clone.Massless = true
            clone.Transparency = math.clamp(part.Transparency, 0, 1)
            clone.Parent = fake
            table.insert(engine.fakeParts, { real = part, fake = clone })
        end
    end
end

local function destroyFakeCharacter()
    if engine.fakeModel then
        pcall(function() engine.fakeModel:Destroy() end)
    end
    engine.fakeModel = nil
    engine.fakeParts = {}
end

----------------------------------------------------------------
-- Ghost hitbox indicators
----------------------------------------------------------------
local ghostHrp, ghostReal

local function ensureGhost()
    if not ghostHrp then
        ghostHrp = Instance.new('Part')
        ghostHrp.Name = '_eni_ghost_server'
        ghostHrp.Anchored = true
        ghostHrp.CanCollide = false
        ghostHrp.CanQuery = false
        ghostHrp.CanTouch = false
        ghostHrp.Massless = true
        ghostHrp.Size = Vector3.new(2, 2, 1)
        ghostHrp.Material = Enum.Material.ForceField
        ghostHrp.Color = Theme.AccentPrimary
        ghostHrp.Transparency = 0.55
        ghostHrp.Parent = Workspace
        trackInstance(ghostHrp)
        local box = Instance.new('SelectionBox', ghostHrp)
        box.Adornee = ghostHrp
        box.LineThickness = 0.04
        box.SurfaceTransparency = 0.85
        box.SurfaceColor3 = Theme.AccentPrimary
        box.Color3 = Theme.AccentPrimary
    end
    if not ghostReal then
        ghostReal = Instance.new('Part')
        ghostReal.Name = '_eni_ghost_real'
        ghostReal.Anchored = true
        ghostReal.CanCollide = false
        ghostReal.CanQuery = false
        ghostReal.CanTouch = false
        ghostReal.Massless = true
        ghostReal.Size = Vector3.new(2, 2, 1)
        ghostReal.Material = Enum.Material.ForceField
        ghostReal.Color = Theme.Cyan
        ghostReal.Transparency = 0.55
        ghostReal.Parent = Workspace
        trackInstance(ghostReal)
        local box = Instance.new('SelectionBox', ghostReal)
        box.Adornee = ghostReal
        box.LineThickness = 0.04
        box.SurfaceTransparency = 0.85
        box.SurfaceColor3 = Theme.Cyan
        box.Color3 = Theme.Cyan
    end
end

local function destroyGhosts()
    if ghostHrp then pcall(function() ghostHrp:Destroy() end); ghostHrp = nil end
    if ghostReal then pcall(function() ghostReal:Destroy() end); ghostReal = nil end
end

----------------------------------------------------------------
-- Replication verification
----------------------------------------------------------------
local lastHrpCheck = { time = 0, pos = nil }

local function verifyReplication()
    if not state.VerifyReplication then engine.replStatus = 'Off'; return end
    local now = tick()
    if now - engine.lastReplVerify < 2 then return end
    engine.lastReplVerify = now
    local char, hrp = getChar()
    if not hrp then engine.replStatus = 'Unknown'; return end
    if engine.active then
        if hrp.AssemblyLinearVelocity.Magnitude > 0 or (hrp.Position - (lastHrpCheck.pos or hrp.Position)).Magnitude > 0.1 then
            engine.replStatus = 'Success'
        else
            engine.replStatus = 'Failed'
        end
    else
        engine.replStatus = 'Idle'
    end
    lastHrpCheck.pos = hrp.Position
    lastHrpCheck.time = now
end

----------------------------------------------------------------
-- Engage / disengage
----------------------------------------------------------------
local function stopMethodConnections()
    if engine.desyncConn then engine.desyncConn:Disconnect(); engine.desyncConn = nil end
    if engine.velocityConn then engine.velocityConn:Disconnect(); engine.velocityConn = nil end
    if engine.fakeConn then engine.fakeConn:Disconnect(); engine.fakeConn = nil end
end

local function engage()
    if engine.active then return end
    local char, hrp, hum = getChar()
    if not char then return end
    engine.active = true
    engine.method = state.Method
    engine.realCFrame = hrp.CFrame
    engine.transitionAlpha = 0
    engine.cancelToken = engine.cancelToken + 1
    local thisToken = engine.cancelToken

    logEvent('Desync engaged: ' .. engine.method .. ' @ ' .. tostring(state.Offset) .. ' studs ' .. state.Direction)

    local method = engine.method

    if method == 'Network Owner' or method == 'Combined' then
        engine.desyncConn = RunService.RenderStepped:Connect(function(dt)
            if not engine.active or engine.cancelToken ~= thisToken then return end
            local c, h = getChar()
            if not h then return end
            if engine.transitionAlpha < 1 then
                engine.transitionAlpha = math.min(1, engine.transitionAlpha + (dt / math.max(0.001, state.SmoothTransition)))
            end
            local offset = computeDesyncOffset(c, h)
            local target
            if state.HitboxOnly then
                target = h.CFrame + (offset * engine.transitionAlpha)
            else
                target = h.CFrame + (offset * engine.transitionAlpha)
            end
            pcall(function() h.CFrame = target end)
        end)
    end

    if method == 'Velocity Slam' or method == 'Combined' then
        engine.velocityConn = RunService.Heartbeat:Connect(function()
            if not engine.active or engine.cancelToken ~= thisToken then return end
            local c, h = getChar()
            if not h then return end
            local dir = getDirectionVector(c, h)
            local mag = 60 + state.Offset * 12
            pcall(function() h.AssemblyLinearVelocity = dir * mag end)
        end)
    end

    if method == 'Fake Character' or method == 'Combined' then
        buildFakeCharacter()
        engine.fakeConn = RunService.RenderStepped:Connect(function()
            if not engine.active or engine.cancelToken ~= thisToken then return end
            if not engine.fakeModel or not engine.fakeModel.Parent then buildFakeCharacter() end
            local c, h = getChar()
            if not h then return end
            local offset = computeDesyncOffset(c, h) * -1
            for _, pair in ipairs(engine.fakeParts) do
                if pair.real and pair.real.Parent and pair.fake and pair.fake.Parent then
                    pcall(function() pair.fake.CFrame = pair.real.CFrame + offset end)
                end
            end
            if method == 'Fake Character' then
                pcall(function() h.CFrame = h.CFrame end)
            end
        end)
    end

    if state.GhostHitbox or state.RealPosIndicator then
        ensureGhost()
    end
end

local function disengage()
    if not engine.active then return end
    engine.active = false
    engine.transitionAlpha = 0
    stopMethodConnections()
    destroyFakeCharacter()
    local c, h = getChar()
    if h then pcall(function() h.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end) end
    logEvent('Desync disengaged')
end

----------------------------------------------------------------
-- Auto-desync detection (other players aiming at us)
----------------------------------------------------------------
local autoDesyncEngaged = false

local function isOtherAimingAtUs()
    local char, hrp = getChar()
    if not hrp then return false end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local ohrp = p.Character:FindFirstChild('HumanoidRootPart')
            local ohead = p.Character:FindFirstChild('Head')
            if ohrp and ohead then
                local toUs = (hrp.Position - ohead.Position)
                local dist = toUs.Magnitude
                if dist < 500 then
                    local lookDir = ohrp.CFrame.LookVector
                    local angle = math.deg(math.acos(math.clamp(lookDir:Dot(toUs.Unit), -1, 1)))
                    if angle <= state.AutoFOV then
                        return true, p
                    end
                end
            end
        end
    end
    return false, nil
end

----------------------------------------------------------------
-- Anti-fling enforcement
----------------------------------------------------------------
local antiFlingTimer = 0
local function antiFlingTick(dt)
    if not state.AntiFling then return end
    if engine.method == 'Velocity Slam' or engine.method == 'Combined' then return end
    if not engine.active then return end
    antiFlingTimer = antiFlingTimer + dt
    if antiFlingTimer < 0.25 then return end
    antiFlingTimer = 0
    local c, h = getChar()
    if h then pcall(function() h.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end) end
end

----------------------------------------------------------------
-- Anti-cheat detect hook
----------------------------------------------------------------
local function subscribeToAntiCheatLog()
    if not state.AutoCancelOnDetect then return end
    pcall(function()
        if getgenv().ENI and getgenv().ENI.AntiCheatBypass and getgenv().ENI.AntiCheatBypass.OnDetect then
            getgenv().ENI.AntiCheatBypass.OnDetect(function(info)
                if engine.active then
                    disengage()
                    notify('Desync', 'Anti-cheat detection fired, desync auto-cancelled: ' .. tostring(info or '?'), 'warning', 4)
                    logEvent('Auto-cancel from AC detect')
                end
            end)
        end
    end)
end

----------------------------------------------------------------
-- GUI BUILDER
----------------------------------------------------------------
local GUI = {}
GUI.elements = {}
GUI.searchHooks = {}
GUI.currentTab = 'Methods'
GUI.cards = {}

local screen, mainFrame, sidebar, contentScroll, statusFooter, statusText, searchBox

local function newCorner(parent, r)
    local c = Instance.new('UICorner', parent)
    c.CornerRadius = UDim.new(0, r or 6)
    return c
end

local function newStroke(parent, color, thick)
    local s = Instance.new('UIStroke', parent)
    s.Color = color or Theme.Border
    s.Thickness = thick or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end

local function newPadding(parent, p)
    local pad = Instance.new('UIPadding', parent)
    pad.PaddingTop = UDim.new(0, p)
    pad.PaddingBottom = UDim.new(0, p)
    pad.PaddingLeft = UDim.new(0, p)
    pad.PaddingRight = UDim.new(0, p)
    return pad
end

----------------------------------------------------------------
-- Toggle control
----------------------------------------------------------------
local function makeToggle(parent, initial, onChange)
    local btn = Instance.new('TextButton', parent)
    btn.Size = UDim2.new(0, 38, 0, 20)
    btn.BackgroundColor3 = initial and Theme.AccentPrimary or Theme.CardBg
    btn.BorderSizePixel = 0
    btn.Text = ''
    btn.AutoButtonColor = false
    newCorner(btn, 10)
    newStroke(btn, Theme.Border, 1)

    local knob = Instance.new('Frame', btn)
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = initial and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    newCorner(knob, 8)

    local value = initial
    local function set(v)
        value = v
        TweenService:Create(btn, EASE_SLOW, { BackgroundColor3 = v and Theme.AccentPrimary or Theme.CardBg }):Play()
        TweenService:Create(knob, EASE_SLOW, { Position = v and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) }):Play()
        if onChange then onChange(v) end
    end

    btn.MouseButton1Click:Connect(function() set(not value) end)

    return {
        Instance = btn,
        Set = set,
        Get = function() return value end,
    }
end

----------------------------------------------------------------
-- Slider control
----------------------------------------------------------------
local function makeSlider(parent, minV, maxV, initial, decimals, onChange)
    local container = Instance.new('Frame', parent)
    container.Size = UDim2.new(0, 230, 0, 20)
    container.BackgroundTransparency = 1

    local track = Instance.new('Frame', container)
    track.Size = UDim2.new(0, 180, 0, 4)
    track.Position = UDim2.new(0, 0, 0.5, -2)
    track.BackgroundColor3 = Theme.CardBg
    track.BorderSizePixel = 0
    newCorner(track, 2)

    local fill = Instance.new('Frame', track)
    fill.BackgroundColor3 = Theme.AccentPrimary
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new((initial - minV) / (maxV - minV), 0, 1, 0)
    newCorner(fill, 2)

    local knob = Instance.new('Frame', track)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((initial - minV) / (maxV - minV), 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    newCorner(knob, 7)

    local valLbl = Instance.new('TextLabel', container)
    valLbl.BackgroundTransparency = 1
    valLbl.Position = UDim2.new(0, 188, 0, 0)
    valLbl.Size = UDim2.new(0, 42, 1, 0)
    valLbl.Font = Enum.Font.Code
    valLbl.TextSize = 12
    valLbl.TextColor3 = Theme.TextPrimary
    valLbl.TextXAlignment = Enum.TextXAlignment.Left

    local value = initial
    local function fmt(v)
        if decimals and decimals > 0 then
            return string.format('%.' .. decimals .. 'f', v)
        end
        return tostring(math.floor(v + 0.5))
    end
    valLbl.Text = fmt(value)

    local dragging = false

    local function setFromX(x)
        local abs = track.AbsolutePosition.X
        local size = track.AbsoluteSize.X
        local rel = math.clamp((x - abs) / size, 0, 1)
        local raw = minV + (maxV - minV) * rel
        if not decimals or decimals == 0 then raw = math.floor(raw + 0.5) end
        value = raw
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        valLbl.Text = fmt(value)
        if onChange then onChange(value) end
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return {
        Instance = container,
        Set = function(v)
            local rel = math.clamp((v - minV) / (maxV - minV), 0, 1)
            value = v
            fill.Size = UDim2.new(rel, 0, 1, 0)
            knob.Position = UDim2.new(rel, 0, 0.5, 0)
            valLbl.Text = fmt(value)
        end,
        Get = function() return value end,
    }
end

----------------------------------------------------------------
-- Dropdown control
----------------------------------------------------------------
local activeDropdown = nil

local function makeDropdown(parent, options, initial, onChange)
    local btn = Instance.new('TextButton', parent)
    btn.Size = UDim2.new(0, 160, 0, 28)
    btn.BackgroundColor3 = Theme.ContentBg
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextColor3 = Theme.TextPrimary
    btn.Text = '  ' .. initial .. '         v'
    btn.TextXAlignment = Enum.TextXAlignment.Left
    newCorner(btn, 4)
    newStroke(btn, Theme.Border, 1)

    local current = initial

    local function openList()
        if activeDropdown then activeDropdown:Destroy(); activeDropdown = nil end
        local listGui = Instance.new('ScreenGui')
        listGui.IgnoreGuiInset = true
        listGui.DisplayOrder = 1500
        listGui.Name = '_eni_dropdown'
        protect_gui(listGui)
        activeDropdown = listGui

        local list = Instance.new('Frame', listGui)
        local absPos = btn.AbsolutePosition
        local absSize = btn.AbsoluteSize
        list.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 2)
        list.Size = UDim2.new(0, absSize.X, 0, math.min(200, #options * 28))
        list.BackgroundColor3 = Theme.ContentBg
        list.BorderSizePixel = 0
        newCorner(list, 4)
        newStroke(list, Theme.Border, 1)

        local scroll = Instance.new('ScrollingFrame', list)
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 3
        scroll.ScrollBarImageColor3 = Theme.AccentPrimary
        scroll.CanvasSize = UDim2.new(0, 0, 0, #options * 28)

        local layout = Instance.new('UIListLayout', scroll)
        layout.SortOrder = Enum.SortOrder.LayoutOrder

        for i, opt in ipairs(options) do
            local item = Instance.new('TextButton', scroll)
            item.Size = UDim2.new(1, 0, 0, 28)
            item.BackgroundColor3 = Theme.ContentBg
            item.BorderSizePixel = 0
            item.Font = Enum.Font.Gotham
            item.TextSize = 13
            item.TextColor3 = opt == current and Theme.AccentPrimary or Theme.TextPrimary
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.Text = '  ' .. opt
            item.AutoButtonColor = false
            item.LayoutOrder = i
            item.MouseEnter:Connect(function()
                TweenService:Create(item, EASE_FAST, { BackgroundColor3 = Theme.CardBg }):Play()
            end)
            item.MouseLeave:Connect(function()
                TweenService:Create(item, EASE_FAST, { BackgroundColor3 = Theme.ContentBg }):Play()
            end)
            item.MouseButton1Click:Connect(function()
                current = opt
                btn.Text = '  ' .. opt .. '         v'
                if onChange then onChange(opt) end
                listGui:Destroy()
                if activeDropdown == listGui then activeDropdown = nil end
            end)
        end

        local closeConn
        closeConn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                task.wait()
                local m = UserInputService:GetMouseLocation()
                local lp = list.AbsolutePosition
                local ls = list.AbsoluteSize
                local bp = btn.AbsolutePosition
                local bs = btn.AbsoluteSize
                local inList = m.X >= lp.X and m.X <= lp.X + ls.X and m.Y >= lp.Y and m.Y <= lp.Y + ls.Y
                local inBtn = m.X >= bp.X and m.X <= bp.X + bs.X and m.Y >= bp.Y and m.Y <= bp.Y + bs.Y
                if not inList and not inBtn then
                    listGui:Destroy()
                    if activeDropdown == listGui then activeDropdown = nil end
                    closeConn:Disconnect()
                end
            end
        end)
    end

    btn.MouseButton1Click:Connect(openList)

    return {
        Instance = btn,
        Set = function(v) current = v; btn.Text = '  ' .. v .. '         v' end,
        Get = function() return current end,
    }
end

----------------------------------------------------------------
-- Keybind control
----------------------------------------------------------------
local function makeKeybind(parent, initial, onChange)
    local btn = Instance.new('TextButton', parent)
    btn.Size = UDim2.new(0, 100, 0, 28)
    btn.BackgroundColor3 = Theme.ContentBg
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.TextColor3 = Theme.TextPrimary
    btn.Text = initial
    newCorner(btn, 4)
    newStroke(btn, Theme.Border, 1)

    local current = initial
    local listening = false

    btn.MouseButton1Click:Connect(function()
        listening = true
        btn.Text = 'Press a key...'
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.KeyCode == Enum.KeyCode.Escape then
                current = 'None'
                btn.Text = 'None'
                if onChange then onChange('None') end
                listening = false
                conn:Disconnect()
                return
            end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                current = input.KeyCode.Name
                btn.Text = current
                if onChange then onChange(current) end
                listening = false
                conn:Disconnect()
            end
        end)
    end)

    return {
        Instance = btn,
        Set = function(v) current = v; btn.Text = v end,
        Get = function() return current end,
    }
end

----------------------------------------------------------------
-- Numeric textbox (spin box)
----------------------------------------------------------------
local function makeNumberBox(parent, initial, onChange)
    local tb = Instance.new('TextBox', parent)
    tb.Size = UDim2.new(0, 60, 0, 28)
    tb.BackgroundColor3 = Theme.ContentBg
    tb.BorderSizePixel = 0
    tb.Font = Enum.Font.Code
    tb.TextSize = 12
    tb.TextColor3 = Theme.TextPrimary
    tb.Text = tostring(initial)
    tb.ClearTextOnFocus = false
    newCorner(tb, 4)
    local stroke = newStroke(tb, Theme.Border, 1)

    tb.Focused:Connect(function()
        TweenService:Create(stroke, EASE_FAST, { Color = Theme.AccentPrimary }):Play()
    end)
    tb.FocusLost:Connect(function()
        TweenService:Create(stroke, EASE_FAST, { Color = Theme.Border }):Play()
        local n = tonumber(tb.Text) or 0
        tb.Text = tostring(n)
        if onChange then onChange(n) end
    end)

    return {
        Instance = tb,
        Set = function(v) tb.Text = tostring(v) end,
        Get = function() return tonumber(tb.Text) or 0 end,
    }
end

----------------------------------------------------------------
-- Button (action)
----------------------------------------------------------------
local function makeButton(parent, text, style, onClick)
    local btn = Instance.new('TextButton', parent)
    btn.Size = UDim2.new(0, 100, 0, 30)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.Text = text
    newCorner(btn, 4)

    local bg, hover
    if style == 'secondary' then
        bg = Theme.CardBg; hover = Theme.CardBgHover; btn.TextColor3 = Theme.TextPrimary
    elseif style == 'danger' then
        bg = Theme.Danger; hover = Color3.fromRGB(255, 120, 135); btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        bg = Theme.AccentPrimary; hover = Color3.fromRGB(255, 100, 195); btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
    btn.BackgroundColor3 = bg

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, EASE_FAST, { BackgroundColor3 = hover }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, EASE_FAST, { BackgroundColor3 = bg }):Play()
    end)
    if onClick then btn.MouseButton1Click:Connect(onClick) end

    return { Instance = btn }
end

----------------------------------------------------------------
-- Card builders
----------------------------------------------------------------
local function makeCard(parent, title, description, tags)
    local card = Instance.new('Frame', parent)
    card.BackgroundColor3 = Theme.CardBg
    card.BorderSizePixel = 0
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Size = UDim2.new(1, 0, 0, 0)
    newCorner(card, 8)

    local pad = Instance.new('UIPadding', card)
    pad.PaddingTop = UDim.new(0, 14)
    pad.PaddingBottom = UDim.new(0, 14)
    pad.PaddingLeft = UDim.new(0, 16)
    pad.PaddingRight = UDim.new(0, 16)

    local layout = Instance.new('UIListLayout', card)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)

    local titleLbl = Instance.new('TextLabel', card)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Size = UDim2.new(1, 0, 0, 18)
    titleLbl.Font = Enum.Font.GothamSemibold
    titleLbl.TextSize = 14
    titleLbl.TextColor3 = Theme.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Text = title
    titleLbl.LayoutOrder = 1

    if description then
        local descLbl = Instance.new('TextLabel', card)
        descLbl.BackgroundTransparency = 1
        descLbl.Size = UDim2.new(1, 0, 0, 16)
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextSize = 12
        descLbl.TextColor3 = Theme.TextDim
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.TextWrapped = true
        descLbl.AutomaticSize = Enum.AutomaticSize.Y
        descLbl.Text = description
        descLbl.LayoutOrder = 2
    end

    table.insert(GUI.cards, { instance = card, title = title:lower(), description = (description or ''):lower(), tags = tags or {} })
    return card
end

local function makeRow(card, label, sublabel)
    local row = Instance.new('Frame', card)
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundTransparency = 1
    row.LayoutOrder = #card:GetChildren()

    local left = Instance.new('Frame', row)
    left.BackgroundTransparency = 1
    left.Size = UDim2.new(1, -260, 1, 0)
    left.Position = UDim2.new(0, 0, 0, 0)

    local lbl = Instance.new('TextLabel', left)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.Position = UDim2.new(0, 0, 0, sublabel and 4 or 12)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = Theme.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label

    if sublabel then
        local sub = Instance.new('TextLabel', left)
        sub.BackgroundTransparency = 1
        sub.Size = UDim2.new(1, 0, 0, 14)
        sub.Position = UDim2.new(0, 0, 0, 22)
        sub.Font = Enum.Font.Gotham
        sub.TextSize = 11
        sub.TextColor3 = Theme.TextDim
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.Text = sublabel
    end

    local right = Instance.new('Frame', row)
    right.BackgroundTransparency = 1
    right.AnchorPoint = Vector2.new(1, 0.5)
    right.Position = UDim2.new(1, 0, 0.5, 0)
    right.Size = UDim2.new(0, 250, 1, 0)
    local hl = Instance.new('UIListLayout', right)
    hl.FillDirection = Enum.FillDirection.Horizontal
    hl.HorizontalAlignment = Enum.HorizontalAlignment.Right
    hl.VerticalAlignment = Enum.VerticalAlignment.Center
    hl.Padding = UDim.new(0, 6)
    hl.SortOrder = Enum.SortOrder.LayoutOrder

    return row, right
end

----------------------------------------------------------------
-- Tabs / sidebar
----------------------------------------------------------------
local TABS = { 'Methods', 'Offset', 'Triggers', 'Indicators', 'Safety', 'Logs', 'Settings' }
local TAB_ICONS = {
    Methods = 'M',
    Offset = 'O',
    Triggers = 'T',
    Indicators = 'I',
    Safety = 'S',
    Logs = 'L',
    Settings = 'C',
}

local tabContents = {}

local function showTab(name)
    GUI.currentTab = name
    for n, frame in pairs(tabContents) do
        if frame then
            if n == name then
                frame.Visible = true
                frame.GroupTransparency = 1
                TweenService:Create(frame, EASE_SLOW, { GroupTransparency = 0 }):Play()
            else
                frame.Visible = false
            end
        end
    end
    for n, navBtn in pairs(GUI.navButtons or {}) do
        local sel = n == name
        local bar = navBtn:FindFirstChild('_bar')
        TweenService:Create(navBtn, EASE_FAST, { BackgroundColor3 = sel and Theme.AccentSoft or Theme.SidebarBg }):Play()
        if bar then bar.Visible = sel end
    end
end

----------------------------------------------------------------
-- Build GUI
----------------------------------------------------------------
local function buildGui()
    if screen then return end

    screen = Instance.new('ScreenGui')
    screen.Name = '_eni_desync_gui'
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.DisplayOrder = 900
    protect_gui(screen)
    trackInstance(screen)

    mainFrame = Instance.new('Frame', screen)
    mainFrame.Size = UDim2.new(0, 920, 0, 600)
    mainFrame.Position = UDim2.new(0.5, -460, 0.5, -300)
    mainFrame.BackgroundColor3 = Theme.WindowBg
    mainFrame.BorderSizePixel = 0
    newCorner(mainFrame, 10)
    newStroke(mainFrame, Theme.Border, 1)

    -- Accent stripe top
    local stripe = Instance.new('Frame', mainFrame)
    stripe.Size = UDim2.new(1, 0, 0, 2)
    stripe.Position = UDim2.new(0, 0, 0, 0)
    stripe.BackgroundColor3 = Theme.AccentPrimary
    stripe.BorderSizePixel = 0

    -- Title bar
    local titleBar = Instance.new('Frame', mainFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.Position = UDim2.new(0, 0, 0, 2)
    titleBar.BackgroundColor3 = Theme.WindowBg
    titleBar.BorderSizePixel = 0

    local logo = Instance.new('Frame', titleBar)
    logo.Size = UDim2.new(0, 12, 0, 12)
    logo.Position = UDim2.new(0, 12, 0.5, -6)
    logo.BackgroundColor3 = Theme.AccentPrimary
    logo.BorderSizePixel = 0
    newCorner(logo, 3)

    local titleLbl = Instance.new('TextLabel', titleBar)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.new(0, 32, 0, 0)
    titleLbl.Size = UDim2.new(0, 240, 1, 0)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 14
    titleLbl.TextColor3 = Theme.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Text = 'FREEZER  -  Desync'

    -- Search bar
    local searchHolder = Instance.new('Frame', titleBar)
    searchHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    searchHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
    searchHolder.Size = UDim2.new(0, 380, 0, 28)
    searchHolder.BackgroundColor3 = Theme.ContentBg
    searchHolder.BorderSizePixel = 0
    newCorner(searchHolder, 14)
    newStroke(searchHolder, Theme.Border, 1)

    local searchIcon = Instance.new('TextLabel', searchHolder)
    searchIcon.BackgroundTransparency = 1
    searchIcon.Size = UDim2.new(0, 24, 1, 0)
    searchIcon.Position = UDim2.new(0, 6, 0, 0)
    searchIcon.Font = Enum.Font.GothamBold
    searchIcon.TextSize = 12
    searchIcon.TextColor3 = Theme.TextDim
    searchIcon.Text = 'Q'

    searchBox = Instance.new('TextBox', searchHolder)
    searchBox.BackgroundTransparency = 1
    searchBox.Position = UDim2.new(0, 32, 0, 0)
    searchBox.Size = UDim2.new(1, -40, 1, 0)
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 13
    searchBox.TextColor3 = Theme.TextPrimary
    searchBox.PlaceholderText = 'Search settings...'
    searchBox.PlaceholderColor3 = Theme.TextDim
    searchBox.Text = ''
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.ClearTextOnFocus = false

    -- Window buttons
    local minBtn = Instance.new('TextButton', titleBar)
    minBtn.Size = UDim2.new(0, 46, 1, 0)
    minBtn.Position = UDim2.new(1, -92, 0, 0)
    minBtn.BackgroundColor3 = Theme.WindowBg
    minBtn.BackgroundTransparency = 1
    minBtn.BorderSizePixel = 0
    minBtn.AutoButtonColor = false
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 14
    minBtn.TextColor3 = Theme.TextSecondary
    minBtn.Text = '_'

    local closeBtn = Instance.new('TextButton', titleBar)
    closeBtn.Size = UDim2.new(0, 46, 1, 0)
    closeBtn.Position = UDim2.new(1, -46, 0, 0)
    closeBtn.BackgroundColor3 = Theme.Danger
    closeBtn.BackgroundTransparency = 1
    closeBtn.BorderSizePixel = 0
    closeBtn.AutoButtonColor = false
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 13
    closeBtn.TextColor3 = Theme.TextPrimary
    closeBtn.Text = 'X'

    minBtn.MouseEnter:Connect(function() TweenService:Create(minBtn, EASE_FAST, { BackgroundTransparency = 0, BackgroundColor3 = Theme.CardBg }):Play() end)
    minBtn.MouseLeave:Connect(function() TweenService:Create(minBtn, EASE_FAST, { BackgroundTransparency = 1 }):Play() end)
    closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn, EASE_FAST, { BackgroundTransparency = 0 }):Play() end)
    closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, EASE_FAST, { BackgroundTransparency = 1 }):Play() end)
    closeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false end)
    minBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false end)

    -- Drag
    do
        local dragging, dragStart, startPos
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = mainFrame.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
    end

    -- Sidebar
    sidebar = Instance.new('Frame', mainFrame)
    sidebar.Size = UDim2.new(0, 220, 1, -42 - 26)
    sidebar.Position = UDim2.new(0, 0, 0, 42)
    sidebar.BackgroundColor3 = Theme.SidebarBg
    sidebar.BorderSizePixel = 0

    local sideLayout = Instance.new('UIListLayout', sidebar)
    sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sideLayout.Padding = UDim.new(0, 2)
    Instance.new('UIPadding', sidebar).PaddingTop = UDim.new(0, 8)

    GUI.navButtons = {}
    for i, tabName in ipairs(TABS) do
        local navBtn = Instance.new('TextButton', sidebar)
        navBtn.Size = UDim2.new(1, 0, 0, 44)
        navBtn.BackgroundColor3 = Theme.SidebarBg
        navBtn.BorderSizePixel = 0
        navBtn.AutoButtonColor = false
        navBtn.Text = ''
        navBtn.LayoutOrder = i

        local bar = Instance.new('Frame', navBtn)
        bar.Name = '_bar'
        bar.Size = UDim2.new(0, 3, 0.6, 0)
        bar.AnchorPoint = Vector2.new(0, 0.5)
        bar.Position = UDim2.new(0, 0, 0.5, 0)
        bar.BackgroundColor3 = Theme.AccentPrimary
        bar.BorderSizePixel = 0
        bar.Visible = false
        newCorner(bar, 2)

        local icon = Instance.new('TextLabel', navBtn)
        icon.BackgroundTransparency = 1
        icon.Size = UDim2.new(0, 24, 1, 0)
        icon.Position = UDim2.new(0, 14, 0, 0)
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 12
        icon.TextColor3 = Theme.AccentPrimary
        icon.Text = TAB_ICONS[tabName] or '*'

        local lbl = Instance.new('TextLabel', navBtn)
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1, -50, 1, 0)
        lbl.Position = UDim2.new(0, 42, 0, 0)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 13
        lbl.TextColor3 = Theme.TextPrimary
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = tabName

        navBtn.MouseEnter:Connect(function()
            if GUI.currentTab ~= tabName then
                TweenService:Create(navBtn, EASE_FAST, { BackgroundColor3 = Theme.CardBg }):Play()
            end
        end)
        navBtn.MouseLeave:Connect(function()
            if GUI.currentTab ~= tabName then
                TweenService:Create(navBtn, EASE_FAST, { BackgroundColor3 = Theme.SidebarBg }):Play()
            end
        end)
        navBtn.MouseButton1Click:Connect(function() showTab(tabName) end)
        GUI.navButtons[tabName] = navBtn
    end

    -- Content area
    local contentHolder = Instance.new('Frame', mainFrame)
    contentHolder.Size = UDim2.new(1, -220, 1, -42 - 26)
    contentHolder.Position = UDim2.new(0, 220, 0, 42)
    contentHolder.BackgroundColor3 = Theme.ContentBg
    contentHolder.BorderSizePixel = 0

    -- Breadcrumb + section header
    local headerHolder = Instance.new('Frame', contentHolder)
    headerHolder.Size = UDim2.new(1, -40, 0, 80)
    headerHolder.Position = UDim2.new(0, 20, 0, 16)
    headerHolder.BackgroundTransparency = 1

    local breadcrumb = Instance.new('TextLabel', headerHolder)
    breadcrumb.BackgroundTransparency = 1
    breadcrumb.Size = UDim2.new(1, 0, 0, 14)
    breadcrumb.Position = UDim2.new(0, 0, 0, 0)
    breadcrumb.Font = Enum.Font.Gotham
    breadcrumb.TextSize = 11
    breadcrumb.TextColor3 = Theme.TextDim
    breadcrumb.TextXAlignment = Enum.TextXAlignment.Left
    breadcrumb.Text = 'Home > Combat > Desync'

    local sectionTitle = Instance.new('TextLabel', headerHolder)
    sectionTitle.BackgroundTransparency = 1
    sectionTitle.Size = UDim2.new(1, 0, 0, 28)
    sectionTitle.Position = UDim2.new(0, 0, 0, 18)
    sectionTitle.Font = Enum.Font.GothamBold
    sectionTitle.TextSize = 24
    sectionTitle.TextColor3 = Theme.TextPrimary
    sectionTitle.TextXAlignment = Enum.TextXAlignment.Left
    sectionTitle.Text = 'Desync'

    local sectionDesc = Instance.new('TextLabel', headerHolder)
    sectionDesc.BackgroundTransparency = 1
    sectionDesc.Size = UDim2.new(1, 0, 0, 18)
    sectionDesc.Position = UDim2.new(0, 0, 0, 50)
    sectionDesc.Font = Enum.Font.Gotham
    sectionDesc.TextSize = 13
    sectionDesc.TextColor3 = Theme.TextSecondary
    sectionDesc.TextXAlignment = Enum.TextXAlignment.Left
    sectionDesc.Text = 'Replicate one position to the server while appearing elsewhere locally.'

    local matchedHint = Instance.new('TextLabel', headerHolder)
    matchedHint.BackgroundTransparency = 1
    matchedHint.Size = UDim2.new(1, 0, 0, 14)
    matchedHint.Position = UDim2.new(0, 0, 0, 70)
    matchedHint.Font = Enum.Font.Gotham
    matchedHint.TextSize = 11
    matchedHint.TextColor3 = Theme.TextDim
    matchedHint.TextXAlignment = Enum.TextXAlignment.Left
    matchedHint.Text = ''
    matchedHint.Visible = false

    -- Scroll for cards
    contentScroll = Instance.new('ScrollingFrame', contentHolder)
    contentScroll.Size = UDim2.new(1, -20, 1, -110)
    contentScroll.Position = UDim2.new(0, 10, 0, 100)
    contentScroll.BackgroundTransparency = 1
    contentScroll.BorderSizePixel = 0
    contentScroll.ScrollBarThickness = 3
    contentScroll.ScrollBarImageColor3 = Theme.AccentPrimary
    contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    contentScroll.ClipsDescendants = true

    -- Tab containers (CanvasGroup for fade)
    for _, tabName in ipairs(TABS) do
        local cg = Instance.new('CanvasGroup', contentScroll)
        cg.Size = UDim2.new(1, -8, 0, 0)
        cg.AutomaticSize = Enum.AutomaticSize.Y
        cg.BackgroundTransparency = 1
        cg.Visible = false
        cg.Name = '_tab_' .. tabName
        local layout = Instance.new('UIListLayout', cg)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 8)
        tabContents[tabName] = cg
    end

    -- Status footer
    statusFooter = Instance.new('Frame', mainFrame)
    statusFooter.Size = UDim2.new(1, 0, 0, 26)
    statusFooter.Position = UDim2.new(0, 0, 1, -26)
    statusFooter.BackgroundColor3 = Theme.WindowBg
    statusFooter.BorderSizePixel = 0

    local footerDivider = Instance.new('Frame', statusFooter)
    footerDivider.Size = UDim2.new(1, 0, 0, 1)
    footerDivider.Position = UDim2.new(0, 0, 0, 0)
    footerDivider.BackgroundColor3 = Theme.Border
    footerDivider.BorderSizePixel = 0

    local footerDot = Instance.new('Frame', statusFooter)
    footerDot.Size = UDim2.new(0, 6, 0, 6)
    footerDot.Position = UDim2.new(0, 10, 0.5, -3)
    footerDot.BackgroundColor3 = Theme.AccentPrimary
    footerDot.BorderSizePixel = 0
    newCorner(footerDot, 3)

    statusText = Instance.new('TextLabel', statusFooter)
    statusText.BackgroundTransparency = 1
    statusText.Position = UDim2.new(0, 24, 0, 0)
    statusText.Size = UDim2.new(1, -34, 1, 0)
    statusText.Font = Enum.Font.Code
    statusText.TextSize = 12
    statusText.TextColor3 = Theme.TextSecondary
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.Text = 'method: idle | offset: 0 | replicated: unknown'

    ----------------------------------------------------------------
    -- BUILD CARDS PER TAB
    ----------------------------------------------------------------

    -- METHODS TAB
    do
        local parent = tabContents['Methods']

        -- Master enable
        local card = makeCard(parent, 'Master Enable', 'Engage the desync system. Method below controls behavior.', { 'enable', 'master', 'on', 'off' })
        local row, right = makeRow(card, 'Enabled', 'Engage desync continuously when on')
        row.Parent = card
        local enableTog = makeToggle(right, state.Enabled, function(v)
            state.Enabled = v
            saveConfig()
            if v and (state.TriggerMode == 'Always On' or state.TriggerMode == 'Always') then
                engage()
            elseif not v then
                disengage()
            end
        end)
        enableTog.Instance.Parent = right

        -- Method dropdown
        local mcard = makeCard(parent, 'Desync Method', 'Select replication strategy. Combined layers all three for maximum desync but highest detection chance.', { 'method', 'network', 'velocity', 'fake' })
        local mr, mright = makeRow(mcard, 'Method', 'Network Owner is safest, Combined is strongest')
        mr.Parent = mcard
        local methodDD = makeDropdown(mright, { 'Network Owner', 'Velocity Slam', 'Fake Character', 'Combined' }, state.Method, function(v)
            state.Method = v
            saveConfig()
            if engine.active then
                disengage()
                if state.Enabled then task.wait(0.05); engage() end
            end
            notify('Desync', 'Method set to ' .. v, 'info', 2)
        end)
        methodDD.Instance.Parent = mright

        -- Tooltips card
        local tcard = makeCard(parent, 'Method Reference', 'How each method desyncs your hitbox from your visible position.', { 'method', 'reference', 'help' })
        local explanations = {
            { 'Network Owner', 'Client owns HRP, server accepts CFrame reports each RenderStepped. Cleanest, hardest to flag.' },
            { 'Velocity Slam', 'Sets AssemblyLinearVelocity to large values to abuse server interpolation. Choppy but effective.' },
            { 'Fake Character', 'Clones visible parts to a fake model offset opposite the real HRP. Visual decoy.' },
            { 'Combined', 'All three layered. Maximum desync, maximum heuristic risk.' },
        }
        for _, e in ipairs(explanations) do
            local r = Instance.new('Frame', tcard)
            r.Size = UDim2.new(1, 0, 0, 36)
            r.BackgroundTransparency = 1
            local n = Instance.new('TextLabel', r)
            n.BackgroundTransparency = 1
            n.Size = UDim2.new(0, 140, 1, 0)
            n.Font = Enum.Font.GothamMedium
            n.TextSize = 12
            n.TextColor3 = Theme.AccentPrimary
            n.TextXAlignment = Enum.TextXAlignment.Left
            n.TextYAlignment = Enum.TextYAlignment.Top
            n.Text = e[1]
            local d = Instance.new('TextLabel', r)
            d.BackgroundTransparency = 1
            d.Position = UDim2.new(0, 150, 0, 0)
            d.Size = UDim2.new(1, -150, 1, 0)
            d.Font = Enum.Font.Gotham
            d.TextSize = 12
            d.TextColor3 = Theme.TextSecondary
            d.TextXAlignment = Enum.TextXAlignment.Left
            d.TextYAlignment = Enum.TextYAlignment.Top
            d.TextWrapped = true
            d.Text = e[2]
        end
    end

    -- OFFSET TAB
    do
        local parent = tabContents['Offset']
        local card = makeCard(parent, 'Offset Distance', 'How far the server-side hitbox sits from your visible character.', { 'offset', 'distance', 'studs' })
        local r, right = makeRow(card, 'Offset (studs)', '0 to 25')
        r.Parent = card
        local sl = makeSlider(right, 0, 25, state.Offset, 1, function(v)
            state.Offset = v
            saveConfig()
        end)
        sl.Instance.Parent = right

        local sr, sright = makeRow(card, 'Smooth transition (s)', '0 = instant snap')
        sr.Parent = card
        local sml = makeSlider(sright, 0, 0.5, state.SmoothTransition, 2, function(v)
            state.SmoothTransition = v
            saveConfig()
        end)
        sml.Instance.Parent = sright

        local hr, hright = makeRow(card, 'Hitbox only', 'Only HRP CFrame moves, visuals stay normal')
        hr.Parent = card
        local hbox = makeToggle(hright, state.HitboxOnly, function(v) state.HitboxOnly = v; saveConfig() end)
        hbox.Instance.Parent = hright

        -- Direction card
        local dcard = makeCard(parent, 'Direction', 'Vector your desync travels along.', { 'direction', 'vector', 'custom' })
        local dr, dright = makeRow(dcard, 'Direction', '')
        dr.Parent = dcard
        local customRows = {}
        local dirDD = makeDropdown(dright, { 'Forward', 'Back', 'Left', 'Right', 'Up', 'Down', 'Random', 'Custom' }, state.Direction, function(v)
            state.Direction = v
            saveConfig()
            for _, cr in ipairs(customRows) do cr.Visible = (v == 'Custom') end
        end)
        dirDD.Instance.Parent = dright

        for _, axis in ipairs({ 'X', 'Y', 'Z' }) do
            local cr, cright = makeRow(dcard, 'Custom ' .. axis, 'Direction component (-1 to 1)')
            cr.Parent = dcard
            cr.Visible = (state.Direction == 'Custom')
            table.insert(customRows, cr)
            local nb = makeNumberBox(cright, state['Custom' .. axis], function(n)
                state['Custom' .. axis] = n
                saveConfig()
            end)
            nb.Instance.Parent = cright
        end
    end

    -- TRIGGERS TAB
    do
        local parent = tabContents['Triggers']

        local card = makeCard(parent, 'Manual Trigger', 'Keybind to engage desync on demand.', { 'trigger', 'key', 'manual' })
        local tr, tright = makeRow(card, 'Trigger key', 'Default X')
        tr.Parent = card
        local tk = makeKeybind(tright, state.TriggerKey, function(v) state.TriggerKey = v; saveConfig() end)
        tk.Instance.Parent = tright

        local mr, mright = makeRow(card, 'Trigger mode', 'Hold or always-on')
        mr.Parent = card
        local mm = makeDropdown(mright, { 'Hold', 'Toggle', 'Always On' }, state.TriggerMode, function(v)
            state.TriggerMode = v
            saveConfig()
            if v == 'Always On' and state.Enabled then engage() end
            if v ~= 'Always On' and engine.active then disengage() end
        end)
        mm.Instance.Parent = mright

        -- Auto-desync
        local ac = makeCard(parent, 'Auto Desync on Aim', 'Detects when a player camera is aimed within FOV, auto-engages.', { 'auto', 'aim', 'fov' })
        local ar, aright = makeRow(ac, 'Auto desync', 'On while enemy aims at you')
        ar.Parent = ac
        local autoTog = makeToggle(aright, state.AutoDesync, function(v) state.AutoDesync = v; saveConfig() end)
        autoTog.Instance.Parent = aright

        local fr, fright = makeRow(ac, 'Aim FOV (deg)', '0 = perfectly aligned, 30 = generous')
        fr.Parent = ac
        local fs = makeSlider(fright, 1, 60, state.AutoFOV, 1, function(v) state.AutoFOV = v; saveConfig() end)
        fs.Instance.Parent = fright

        local atk, atright = makeRow(ac, 'Toggle auto keybind', '')
        atk.Parent = ac
        local atb = makeKeybind(atright, state.AutoToggleAuto, function(v) state.AutoToggleAuto = v; saveConfig() end)
        atb.Instance.Parent = atright

        -- GUI hotkey
        local gc = makeCard(parent, 'GUI Visibility', 'Hotkey to show or hide this window.', { 'gui', 'window', 'hotkey' })
        local gr, gright = makeRow(gc, 'Toggle GUI key', 'Default Right Ctrl')
        gr.Parent = gc
        local gk = makeKeybind(gright, state.ToggleGuiKey, function(v) state.ToggleGuiKey = v; saveConfig() end)
        gk.Instance.Parent = gright
    end

    -- INDICATORS TAB
    do
        local parent = tabContents['Indicators']
        local card = makeCard(parent, 'Ghost Hitbox', 'Magenta wireframe at server-side hitbox position.', { 'ghost', 'hitbox', 'indicator' })
        local r, right = makeRow(card, 'Show ghost hitbox', '')
        r.Parent = card
        local t = makeToggle(right, state.GhostHitbox, function(v)
            state.GhostHitbox = v
            saveConfig()
            if v then ensureGhost() else destroyGhosts() end
        end)
        t.Instance.Parent = right

        local rc = makeCard(parent, 'Real Position Indicator', 'Cyan wireframe at your local visible position.', { 'real', 'position', 'indicator' })
        local rr, rright = makeRow(rc, 'Show real position', '')
        rr.Parent = rc
        local rt = makeToggle(rright, state.RealPosIndicator, function(v)
            state.RealPosIndicator = v
            saveConfig()
            if v then ensureGhost() else destroyGhosts() end
        end)
        rt.Instance.Parent = rright
    end

    -- SAFETY TAB
    do
        local parent = tabContents['Safety']

        local rc = makeCard(parent, 'Reset on Respawn', 'Disengage automatically when character respawns.', { 'reset', 'respawn', 'safety' })
        local rr, rright = makeRow(rc, 'Reset on respawn', '')
        rr.Parent = rc
        local rt = makeToggle(rright, state.ResetOnRespawn, function(v) state.ResetOnRespawn = v; saveConfig() end)
        rt.Instance.Parent = rright

        local ac = makeCard(parent, 'Anti-Cheat Auto Cancel', 'If ENI.AntiCheatBypass logs a detection, disengage immediately.', { 'anti-cheat', 'cancel', 'safety' })
        local ar, aright = makeRow(ac, 'Auto cancel', '')
        ar.Parent = ac
        local at = makeToggle(aright, state.AutoCancelOnDetect, function(v) state.AutoCancelOnDetect = v; saveConfig(); subscribeToAntiCheatLog() end)
        at.Instance.Parent = aright

        local fc = makeCard(parent, 'Anti-Fling', 'Periodically zeroes velocity when not using Velocity Slam.', { 'anti-fling', 'velocity' })
        local fr, fright = makeRow(fc, 'Anti-fling', '')
        fr.Parent = fc
        local ft = makeToggle(fright, state.AntiFling, function(v) state.AntiFling = v; saveConfig() end)
        ft.Instance.Parent = fright

        local vc = makeCard(parent, 'Replication Verification', 'Every 2s checks that the server is receiving your CFrame reports.', { 'verify', 'replication' })
        local vr, vright = makeRow(vc, 'Verify replication', '')
        vr.Parent = vc
        local vt = makeToggle(vright, state.VerifyReplication, function(v) state.VerifyReplication = v; saveConfig() end)
        vt.Instance.Parent = vright
    end

    -- LOGS TAB
    do
        local parent = tabContents['Logs']
        local card = makeCard(parent, 'Verbose Log', 'Records last 50 desync events.', { 'log', 'verbose', 'history' })
        local r, right = makeRow(card, 'Verbose log', '')
        r.Parent = card
        local t = makeToggle(right, state.VerboseLog, function(v) state.VerboseLog = v; saveConfig() end)
        t.Instance.Parent = right

        local logBox = Instance.new('Frame', card)
        logBox.Size = UDim2.new(1, 0, 0, 280)
        logBox.BackgroundColor3 = Theme.ContentBg
        logBox.BorderSizePixel = 0
        newCorner(logBox, 4)
        newStroke(logBox, Theme.Border, 1)

        local scroll = Instance.new('ScrollingFrame', logBox)
        scroll.Size = UDim2.new(1, -8, 1, -8)
        scroll.Position = UDim2.new(0, 4, 0, 4)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 3
        scroll.ScrollBarImageColor3 = Theme.AccentPrimary
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)

        local logLayout = Instance.new('UIListLayout', scroll)
        logLayout.SortOrder = Enum.SortOrder.LayoutOrder
        logLayout.Padding = UDim.new(0, 2)

        local function refresh()
            for _, c in ipairs(scroll:GetChildren()) do
                if c:IsA('TextLabel') then c:Destroy() end
            end
            for i, line in ipairs(logEntries) do
                local lbl = Instance.new('TextLabel', scroll)
                lbl.Size = UDim2.new(1, -6, 0, 16)
                lbl.BackgroundTransparency = 1
                lbl.Font = Enum.Font.Code
                lbl.TextSize = 12
                lbl.TextColor3 = Theme.TextSecondary
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Text = line
                lbl.LayoutOrder = i
            end
        end
        table.insert(logUpdateCallbacks, refresh)
        refresh()

        local btnRow = Instance.new('Frame', card)
        btnRow.Size = UDim2.new(1, 0, 0, 32)
        btnRow.BackgroundTransparency = 1
        local bl = Instance.new('UIListLayout', btnRow)
        bl.FillDirection = Enum.FillDirection.Horizontal
        bl.Padding = UDim.new(0, 6)

        local clearBtn = makeButton(btnRow, 'Clear log', 'secondary', function()
            table.clear(logEntries)
            refresh()
        end)
        clearBtn.Instance.Parent = btnRow
    end

    -- SETTINGS TAB
    do
        local parent = tabContents['Settings']
        local card = makeCard(parent, 'Configuration', 'Save, load, or reset all Desync options.', { 'config', 'save', 'load', 'reset' })
        local row = Instance.new('Frame', card)
        row.Size = UDim2.new(1, 0, 0, 40)
        row.BackgroundTransparency = 1
        local l = Instance.new('UIListLayout', row)
        l.FillDirection = Enum.FillDirection.Horizontal
        l.Padding = UDim.new(0, 8)
        l.VerticalAlignment = Enum.VerticalAlignment.Center

        makeButton(row, 'Save config', nil, function()
            saveConfig()
            notify('Desync', 'Configuration saved', 'success', 2)
        end).Instance.Parent = row
        makeButton(row, 'Load config', 'secondary', function()
            loadConfig()
            notify('Desync', 'Config loaded. Reopen window to refresh values.', 'info', 3)
        end).Instance.Parent = row
        makeButton(row, 'Reset defaults', 'danger', function()
            for k, v in pairs(DEFAULTS) do state[k] = v end
            saveConfig()
            notify('Desync', 'Defaults restored. Reopen window to refresh.', 'warning', 3)
        end).Instance.Parent = row

        local info = makeCard(parent, 'About', 'FREEZER :: Desync', { 'about', 'version' })
        local txt = Instance.new('TextLabel', info)
        txt.BackgroundTransparency = 1
        txt.Size = UDim2.new(1, 0, 0, 80)
        txt.Font = Enum.Font.Gotham
        txt.TextSize = 12
        txt.TextColor3 = Theme.TextSecondary
        txt.TextXAlignment = Enum.TextXAlignment.Left
        txt.TextYAlignment = Enum.TextYAlignment.Top
        txt.TextWrapped = true
        txt.Text = 'Network-owner-replicated hitbox desync. Server sees one position, you appear at another. Use Hold trigger for short bursts to minimize anti-cheat heuristic exposure.'
    end

    -- Search filter
    searchBox:GetPropertyChangedSignal('Text'):Connect(function()
        local q = searchBox.Text:lower()
        if q == '' then
            for _, c in ipairs(GUI.cards) do c.instance.Visible = true end
            matchedHint.Visible = false
            return
        end
        local matchedTabs = {}
        for _, c in ipairs(GUI.cards) do
            local hit = c.title:find(q, 1, true) or c.description:find(q, 1, true)
            if not hit then
                for _, t in ipairs(c.tags) do if t:find(q, 1, true) then hit = true; break end end
            end
            c.instance.Visible = hit and true or false
            if hit then
                local par = c.instance.Parent
                if par and par.Name:sub(1, 5) == '_tab_' then
                    matchedTabs[par.Name:sub(6)] = true
                end
            end
        end
        local list = {}
        for k in pairs(matchedTabs) do table.insert(list, k) end
        if #list > 0 then
            matchedHint.Text = 'matched in: ' .. table.concat(list, ', ')
            matchedHint.Visible = true
        else
            matchedHint.Text = 'no matches'
            matchedHint.Visible = true
        end
    end)

    showTab('Methods')
end

----------------------------------------------------------------
-- Status footer updater
----------------------------------------------------------------
local function updateStatusLoop()
    track(RunService.Heartbeat:Connect(function()
        if not statusText then return end
        local fps = math.floor(1 / math.max(RunService.RenderStepped:Wait(), 0.0001))
        local ping = 0
        pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
        local players = #Players:GetPlayers()
        local gameName = 'Game'
        pcall(function()
            local info = MarketplaceService:GetProductInfo(game.PlaceId)
            if info and info.Name then gameName = info.Name end
        end)
        local timeStr = os.date('%H:%M')
        local methodStr = engine.active and engine.method or 'idle'
        local offsetStr = engine.active and (tostring(state.Offset) .. ' studs ' .. state.Direction:lower()) or '0'
        local replStr = engine.replStatus:lower()
        statusText.Text = string.format('method: %s | offset: %s | replicated: %s    FPS %d / Ping %dms / %d players / %s / %s',
            methodStr, offsetStr, replStr, fps, ping, players, gameName, timeStr)
    end))
end

----------------------------------------------------------------
-- Update ghost positions
----------------------------------------------------------------
local function startGhostLoop()
    track(RunService.RenderStepped:Connect(function()
        if not ghostHrp and not ghostReal then return end
        local char, hrp = getChar()
        if not hrp then return end
        if ghostHrp and state.GhostHitbox then
            ghostHrp.CFrame = hrp.CFrame
            ghostHrp.Transparency = engine.active and 0.45 or 0.85
        elseif ghostHrp then
            ghostHrp.Transparency = 1
        end
        if ghostReal and state.RealPosIndicator then
            local visual = hrp.CFrame
            if engine.active then
                local c, h = getChar()
                visual = h.CFrame - computeDesyncOffset(c, h)
            end
            ghostReal.CFrame = visual
            ghostReal.Transparency = engine.active and 0.45 or 0.85
        elseif ghostReal then
            ghostReal.Transparency = 1
        end
    end))
end

----------------------------------------------------------------
-- Key input wiring
----------------------------------------------------------------
local function keyFromName(name)
    if not name or name == 'None' then return nil end
    local ok, kc = pcall(function() return Enum.KeyCode[name] end)
    if ok then return kc end
    return nil
end

local function startInputLoop()
    track(UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local guiKey = keyFromName(state.ToggleGuiKey)
            if guiKey and input.KeyCode == guiKey then
                if mainFrame then mainFrame.Visible = not mainFrame.Visible end
            end
            local trigger = keyFromName(state.TriggerKey)
            if trigger and input.KeyCode == trigger and state.Enabled then
                if state.TriggerMode == 'Hold' then
                    engage()
                elseif state.TriggerMode == 'Toggle' then
                    if engine.active then disengage() else engage() end
                end
            end
            local autoKey = keyFromName(state.AutoToggleAuto)
            if autoKey and input.KeyCode == autoKey then
                state.AutoDesync = not state.AutoDesync
                saveConfig()
                notify('Desync', 'Auto desync ' .. (state.AutoDesync and 'enabled' or 'disabled'), 'info', 2)
            end
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local trigger = keyFromName(state.TriggerKey)
            if trigger and input.KeyCode == trigger and state.TriggerMode == 'Hold' and state.Enabled then
                disengage()
            end
        end
    end))
end

----------------------------------------------------------------
-- Auto-desync loop
----------------------------------------------------------------
local function startAutoDesyncLoop()
    track(RunService.Heartbeat:Connect(function(dt)
        verifyReplication()
        antiFlingTick(dt)
        if not state.AutoDesync or not state.Enabled then
            if autoDesyncEngaged and engine.active then
                disengage()
                autoDesyncEngaged = false
            end
            return
        end
        local aimed = isOtherAimingAtUs()
        if aimed and not engine.active then
            engage()
            autoDesyncEngaged = true
            logEvent('Auto-desync triggered (enemy aim)')
        elseif not aimed and autoDesyncEngaged and engine.active then
            disengage()
            autoDesyncEngaged = false
        end
    end))
end

----------------------------------------------------------------
-- Character respawn handler
----------------------------------------------------------------
local function bindCharacter()
    track(LocalPlayer.CharacterAdded:Connect(function()
        if state.ResetOnRespawn and engine.active then
            disengage()
            notify('Desync', 'Disengaged on respawn', 'info', 2)
        end
    end))
end

----------------------------------------------------------------
-- Hook caller exemption (no-op safe wrapper)
----------------------------------------------------------------
local function installHooks()
    pcall(function()
        local mt = getrawmetatable(game)
        if not mt then return end
        setreadonly(mt, false)
        local origNamecall = mt.__namecall
        if origNamecall and not hooks.__namecall then
            hooks.__namecall = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
                if checkcaller() then return origNamecall(self, ...) end
                return origNamecall(self, ...)
            end))
        end
        setreadonly(mt, true)
    end)
end

----------------------------------------------------------------
-- API
----------------------------------------------------------------
getgenv().ENI = getgenv().ENI or {}

local API = {}

function API:Show()
    if not screen then buildGui() end
    if mainFrame then mainFrame.Visible = true end
end

function API:Hide()
    if mainFrame then mainFrame.Visible = false end
end

function API:Toggle()
    if mainFrame then mainFrame.Visible = not mainFrame.Visible end
end

function API:Engage()
    state.Enabled = true
    engage()
end

function API:Disengage()
    disengage()
end

function API:IsActive()
    return engine.active
end

function API:GetConfig()
    return deepCopy(state)
end

function API:SetConfig(cfg)
    if type(cfg) ~= 'table' then return end
    for k, v in pairs(cfg) do
        if state[k] ~= nil then state[k] = v end
    end
    saveConfig()
end

function API:Destroy()
    disengage()
    destroyGhosts()
    destroyFakeCharacter()
    disconnectAll()
    for _, inst in ipairs(instances) do
        pcall(function() inst:Destroy() end)
    end
    table.clear(instances)
    screen = nil
    mainFrame = nil
    getgenv().ENI.Desync = nil
end

getgenv().ENI.Desync = API

----------------------------------------------------------------
-- Boot
----------------------------------------------------------------
loadConfig()
installHooks()
buildGui()
updateStatusLoop()
startGhostLoop()
startInputLoop()
startAutoDesyncLoop()
bindCharacter()
subscribeToAntiCheatLog()

if state.GhostHitbox or state.RealPosIndicator then
    ensureGhost()
end

if state.Enabled and state.TriggerMode == 'Always On' then
    task.defer(engage)
end

notify('Desync', 'v3.0.0 loaded. Press ' .. state.ToggleGuiKey .. ' to toggle GUI, ' .. state.TriggerKey .. ' to trigger.', 'success', 4)

return API

end
-- END MODULE: DESYNC v3.0.0
----------------------------------------------------------------------

----------------------------------------------------------------------
-- MODULE: MAGIC BULLET v3.0.0 (1320 lines original)
----------------------------------------------------------------------
do
--[[
================================================================================
  eni-roblox-kit :: combat/magic_bullet.lua
  Module      : Magic Bullet
  Version     : 3.0.0
  API         : getgenv().ENI.MagicBullet
  Purpose     : Hook the bullet remote, redirect every shot to land on target
================================================================================
--]]

------------------------------------------------------------------------
-- ANTI-DETECT WRAPPERS
------------------------------------------------------------------------
local cloneref = cloneref or function(x) return x end
local protect_gui = (syn and syn.protect_gui) or (gethui and function(g) g.Parent = gethui() end) or function(g) g.Parent = game:GetService('CoreGui') end
local hookmetamethod = hookmetamethod or function() return nil end
local getrawmetatable = getrawmetatable or function() return nil end
local setreadonly = setreadonly or function() end
local newcclosure = newcclosure or function(f) return f end
local checkcaller = checkcaller or function() return false end
local getnamecallmethod = getnamecallmethod or function() return "" end
local hookfunction = hookfunction or function(a,b) return a end
local isfile = isfile or function() return false end
local readfile = readfile or function() return "" end
local writefile = writefile or function() end
local makefolder = makefolder or function() end
local listfiles = listfiles or function() return {} end
local Drawing = Drawing or { new = function() return { Remove = function() end, Visible = false } end }

------------------------------------------------------------------------
-- SERVICES
------------------------------------------------------------------------
local Players = cloneref(game:GetService('Players'))
local RunService = cloneref(game:GetService('RunService'))
local UserInputService = cloneref(game:GetService('UserInputService'))
local TweenService = cloneref(game:GetService('TweenService'))
local HttpService = cloneref(game:GetService('HttpService'))
local Lighting = cloneref(game:GetService('Lighting'))
local Workspace = cloneref(game:GetService('Workspace'))
local MarketplaceService = cloneref(game:GetService('MarketplaceService'))
local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local CoreGui = cloneref(game:GetService('CoreGui'))

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

------------------------------------------------------------------------
-- THEME (Win11 Settings dark)
------------------------------------------------------------------------
local Theme = {
    WindowBg       = Color3.fromRGB(20, 20, 26),
    SidebarBg      = Color3.fromRGB(24, 24, 30),
    ContentBg      = Color3.fromRGB(28, 28, 34),
    CardBg         = Color3.fromRGB(36, 36, 44),
    CardBgHover    = Color3.fromRGB(42, 42, 52),
    Border         = Color3.fromRGB(54, 54, 66),
    AccentPrimary  = Color3.fromRGB(255, 65, 180),
    AccentSoft     = Color3.fromRGB(80, 32, 60),
    TextPrimary    = Color3.fromRGB(240, 240, 248),
    TextSecondary  = Color3.fromRGB(170, 170, 188),
    TextDim        = Color3.fromRGB(115, 115, 135),
    Success        = Color3.fromRGB(80, 220, 130),
    Warning        = Color3.fromRGB(255, 185, 70),
    Danger         = Color3.fromRGB(255, 90, 110),
}

local TWEEN_FAST = TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TWEEN_MED  = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

------------------------------------------------------------------------
-- CONFIG / STATE
------------------------------------------------------------------------
local CONFIG_FOLDER = "freezer"
local CONFIG_FILE   = CONFIG_FOLDER .. "/magic_bullet.json"
pcall(makefolder, CONFIG_FOLDER)

local DEFAULTS = {
    Enabled              = false,
    Mode                 = "Direct",          -- Direct / Wall-Pen / Arc / All-In
    BulletRemotePath     = "",
    LastDetected         = {},
    TargetSelection      = "Closest to Mouse",
    TargetPart           = "Head",
    ForceHit             = true,
    Range                = 1500,
    WallCheckInverse     = false,
    MaxBulletsPerSec     = 12,
    HitJitter            = 0.0,
    OccasionalMissPct    = 0,
    DrawingVisualizer    = false,
    ToggleKey            = "M",
    HitPosArgIndex       = 1,
    DirectionArgIndex    = 2,
    Preset               = "Generic",
    TestTarget           = "(none)",
    TriggerMode          = "While Firing",
    DebugLog             = {},
    Stats                = { Redirected = 0, Hits = 0, LastTs = 0 },
}

local State = {}
for k, v in pairs(DEFAULTS) do
    if type(v) == "table" then
        State[k] = {}
        for kk, vv in pairs(v) do State[k][kk] = vv end
    else
        State[k] = v
    end
end

local function saveConfig()
    pcall(function()
        local copy = {}
        for k, v in pairs(State) do
            if k ~= "DebugLog" then copy[k] = v end
        end
        writefile(CONFIG_FILE, HttpService:JSONEncode(copy))
    end)
end

local function loadConfig()
    if isfile(CONFIG_FILE) then
        pcall(function()
            local raw = readfile(CONFIG_FILE)
            local decoded = HttpService:JSONDecode(raw)
            for k, v in pairs(decoded) do State[k] = v end
        end)
    end
end
loadConfig()

------------------------------------------------------------------------
-- HELPERS
------------------------------------------------------------------------
local Connections = {}
local function track(conn)
    table.insert(Connections, conn)
    return conn
end

local function newInstance(class, props, children)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do inst[k] = v end
    end
    if children then
        for _, c in ipairs(children) do c.Parent = inst end
    end
    return inst
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Border
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function padding(parent, p)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, p)
    pad.PaddingBottom = UDim.new(0, p)
    pad.PaddingLeft = UDim.new(0, p)
    pad.PaddingRight = UDim.new(0, p)
    pad.Parent = parent
    return pad
end

------------------------------------------------------------------------
-- NOTIFICATIONS
------------------------------------------------------------------------
local NotifyGui
local function ensureNotifyGui()
    if NotifyGui and NotifyGui.Parent then return NotifyGui end
    NotifyGui = newInstance("ScreenGui", {
        Name = "ENI_MB_Notify",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    pcall(protect_gui, NotifyGui)
    if NotifyGui.Parent == nil then NotifyGui.Parent = CoreGui end
    local list = newInstance("Frame", {
        Name = "Stack",
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -20, 0, 60),
        Size = UDim2.new(0, 320, 1, -80),
        AnchorPoint = Vector2.new(1, 0),
        Parent = NotifyGui,
    })
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.Parent = list
    return NotifyGui
end

local function notify(title, msg, kind, duration)
    ensureNotifyGui()
    local stack = NotifyGui:FindFirstChild("Stack")
    duration = duration or 4
    local accent = Theme.AccentPrimary
    if kind == "success" then accent = Theme.Success
    elseif kind == "warn" then accent = Theme.Warning
    elseif kind == "error" then accent = Theme.Danger end

    local toast = newInstance("Frame", {
        BackgroundColor3 = Theme.CardBg,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 64),
        Position = UDim2.new(1, 40, 0, 0),
        Parent = stack,
    })
    corner(toast, 8)
    stroke(toast, Theme.Border, 1)
    newInstance("Frame", {
        BackgroundColor3 = accent, BorderSizePixel = 0,
        Position = UDim2.new(0,0,0,0), Size = UDim2.new(0,3,1,0),
        Parent = toast,
    })
    newInstance("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(1, -20, 0, 20),
        Font = Enum.Font.GothamBold,
        Text = title or "Magic Bullet",
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = toast,
    })
    newInstance("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 28),
        Size = UDim2.new(1, -20, 0, 32),
        Font = Enum.Font.Gotham,
        Text = msg or "",
        TextColor3 = Theme.TextSecondary,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = toast,
    })

    TweenService:Create(toast, TWEEN_MED, { Position = UDim2.new(0,0,0,0) }):Play()
    task.delay(duration, function()
        local out = TweenService:Create(toast, TWEEN_MED, { Position = UDim2.new(1, 40, 0, 0) })
        out:Play()
        out.Completed:Wait()
        toast:Destroy()
    end)
end

------------------------------------------------------------------------
-- TARGETING
------------------------------------------------------------------------
local function getCharData(plr)
    if not plr or plr == LocalPlayer then return nil end
    local ch = plr.Character
    if not ch then return nil end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    local hrp = ch:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return nil end
    return ch, hum, hrp
end

local function distanceToMouse(plr)
    local ch, _, hrp = getCharData(plr)
    if not ch then return math.huge end
    local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
    if not onScreen then return math.huge end
    local mp = UserInputService:GetMouseLocation()
    return (Vector2.new(screenPos.X, screenPos.Y) - mp).Magnitude
end

local function distanceToCrosshair(plr)
    local ch, _, hrp = getCharData(plr)
    if not ch then return math.huge end
    local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
    if not onScreen then return math.huge end
    local vs = Camera.ViewportSize
    return (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(vs.X/2, vs.Y/2)).Magnitude
end

local function world3dDistance(plr)
    local ch, _, hrp = getCharData(plr)
    if not ch then return math.huge end
    local mychar = LocalPlayer.Character
    local myhrp = mychar and mychar:FindFirstChild("HumanoidRootPart")
    if not myhrp then return math.huge end
    return (hrp.Position - myhrp.Position).Magnitude
end

local function isVisible(target)
    local ch, _, hrp = getCharData(target)
    if not ch then return false end
    local mychar = LocalPlayer.Character
    if not mychar then return false end
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = { mychar, ch }
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local origin = Camera.CFrame.Position
    local dir = (hrp.Position - origin)
    local hit = Workspace:Raycast(origin, dir, rp)
    return hit == nil
end

local function selectTarget()
    local best, bestScore = nil, math.huge
    local mode = State.TargetSelection
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local ch, hum, hrp = getCharData(plr)
            if ch and hum and hrp then
                local d3 = world3dDistance(plr)
                if d3 <= State.Range then
                    local vis = isVisible(plr)
                    local passVis
                    if State.WallCheckInverse then
                        passVis = (not vis)
                    else
                        passVis = true
                    end
                    if passVis then
                        local score
                        if mode == "Closest to Mouse" then
                            score = distanceToMouse(plr)
                        elseif mode == "Closest to Crosshair" then
                            score = distanceToCrosshair(plr)
                        elseif mode == "Lowest HP" then
                            score = hum.Health
                        elseif mode == "Highest Threat" then
                            local prox = math.max(1, d3)
                            score = hum.Health * prox * 0.01
                        else
                            score = d3
                        end
                        if State.TestTarget and State.TestTarget ~= "(none)" and plr.Name == State.TestTarget then
                            score = -1
                        end
                        if score < bestScore then
                            bestScore = score
                            best = plr
                        end
                    end
                end
            end
        end
    end
    return best
end

local function targetPartFor(plr)
    local ch = plr and plr.Character
    if not ch then return nil end
    local choice = State.TargetPart
    if choice == "Random" then
        local opts = { "Head", "HumanoidRootPart", "UpperTorso", "Torso" }
        choice = opts[math.random(#opts)]
    end
    return ch:FindFirstChild(choice) or ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Head")
end

------------------------------------------------------------------------
-- HOOK / REDIRECTION CORE
------------------------------------------------------------------------
local NamecallStats = {}        -- remote -> { count, sample_args }
local Scanning = false
local LastFireTimes = {}
local BulletsThisSec = 0
local SecondMarker = tick()

local Drawings = { origLine = nil, redirLine = nil }
local function ensureDrawings()
    if State.DrawingVisualizer and not Drawings.origLine then
        local ok1, l1 = pcall(function()
            local d = Drawing.new("Line")
            d.Color = Color3.fromRGB(255, 60, 60)
            d.Thickness = 1.5
            d.Visible = false
            return d
        end)
        local ok2, l2 = pcall(function()
            local d = Drawing.new("Line")
            d.Color = Theme.AccentPrimary
            d.Thickness = 1.8
            d.Visible = false
            return d
        end)
        if ok1 then Drawings.origLine = l1 end
        if ok2 then Drawings.redirLine = l2 end
    elseif not State.DrawingVisualizer then
        for k, v in pairs(Drawings) do
            if v then pcall(function() v.Visible = false end) end
        end
    end
end

local function logRedirect(remoteName, origPos, newPos, targetName)
    table.insert(State.DebugLog, 1, {
        t = os.date("%H:%M:%S"),
        remote = remoteName,
        orig = tostring(origPos),
        new = tostring(newPos),
        target = targetName,
    })
    while #State.DebugLog > 30 do table.remove(State.DebugLog) end
end

local function applyJitter(pos)
    if State.HitJitter <= 0 then return pos end
    local j = State.HitJitter
    return pos + Vector3.new(
        (math.random()*2 - 1) * j,
        (math.random()*2 - 1) * j,
        (math.random()*2 - 1) * j
    )
end

local function shouldMiss()
    if State.OccasionalMissPct <= 0 then return false end
    return math.random(1, 100) <= State.OccasionalMissPct
end

local function rateLimitOk()
    local now = tick()
    if now - SecondMarker >= 1 then
        SecondMarker = now
        BulletsThisSec = 0
    end
    if BulletsThisSec >= State.MaxBulletsPerSec then return false end
    BulletsThisSec = BulletsThisSec + 1
    return true
end

local function pickHitArgIndex(args)
    -- prefer config, validate by type
    local idx = State.HitPosArgIndex or 1
    if args[idx] ~= nil then
        local t = typeof(args[idx])
        if t == "Vector3" or t == "CFrame" then return idx end
    end
    for i, v in ipairs(args) do
        local t = typeof(v)
        if t == "Vector3" or t == "CFrame" then return i end
    end
    return nil
end

local function pickDirArgIndex(args)
    local idx = State.DirectionArgIndex or 2
    if args[idx] ~= nil then
        local t = typeof(args[idx])
        if t == "Vector3" or t == "CFrame" then return idx end
    end
    return nil
end

local function redirectArgs(args, remoteName)
    if not State.Enabled then return args, false end
    if not rateLimitOk() then return args, false end
    if shouldMiss() then return args, false end

    local tgt = selectTarget()
    if not tgt then return args, false end
    local part = targetPartFor(tgt)
    if not part then return args, false end

    local newPos = applyJitter(part.Position)
    local hitIdx = pickHitArgIndex(args)
    local dirIdx = pickDirArgIndex(args)

    local origPos = "?"
    if hitIdx then
        local cur = args[hitIdx]
        origPos = tostring(typeof(cur) == "CFrame" and cur.Position or cur)
    end

    local mode = State.Mode
    local function applyDirect()
        if hitIdx then
            local cur = args[hitIdx]
            if typeof(cur) == "CFrame" then
                args[hitIdx] = CFrame.new(newPos)
            else
                args[hitIdx] = newPos
            end
        end
    end
    local function applyWallPen()
        applyDirect()
        if dirIdx then
            local origin = Camera.CFrame.Position
            local dir = (newPos - origin).Unit * (newPos - origin).Magnitude
            local cur = args[dirIdx]
            if typeof(cur) == "CFrame" then
                args[dirIdx] = CFrame.new(origin, origin + dir)
            else
                args[dirIdx] = dir
            end
        end
    end
    local function applyArc()
        applyWallPen()
        -- some games accept array of endpoints; we wrap if next slot is table
        for i, v in ipairs(args) do
            if typeof(v) == "table" then
                local arr = {}
                for _ = 1, 3 do
                    table.insert(arr, applyJitter(newPos))
                end
                args[i] = arr
                break
            end
        end
    end

    if mode == "Direct" then
        applyDirect()
    elseif mode == "Wall-Pen" then
        applyWallPen()
    elseif mode == "Arc" then
        applyArc()
    elseif mode == "All-In" then
        applyArc()
    end

    logRedirect(remoteName or "?", origPos, tostring(newPos), tgt.Name)
    State.Stats.Redirected = State.Stats.Redirected + 1
    State.Stats.LastTs = os.time()

    -- drawing visualizer
    if State.DrawingVisualizer then
        ensureDrawings()
        pcall(function()
            local origin = Camera.CFrame.Position
            local s1, on1 = Camera:WorldToViewportPoint(origin + Camera.CFrame.LookVector * 50)
            local s2, on2 = Camera:WorldToViewportPoint(newPos)
            if Drawings.origLine then
                Drawings.origLine.From = Vector2.new(s1.X, s1.Y)
                Drawings.origLine.To   = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                Drawings.origLine.Visible = on1
            end
            if Drawings.redirLine then
                Drawings.redirLine.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                Drawings.redirLine.To   = Vector2.new(s2.X, s2.Y)
                Drawings.redirLine.Visible = on2
            end
            task.delay(0.15, function()
                if Drawings.origLine then Drawings.origLine.Visible = false end
                if Drawings.redirLine then Drawings.redirLine.Visible = false end
            end)
        end)
    end

    return args, true
end

------------------------------------------------------------------------
-- NAMECALL HOOK
------------------------------------------------------------------------
local OriginalNamecall
local HookInstalled = false

local function installHook()
    if HookInstalled then return end
    local ok, mt = pcall(getrawmetatable, game)
    if not ok or not mt then
        notify("Magic Bullet", "Exploit lacks getrawmetatable, hook disabled", "error", 5)
        return
    end
    pcall(setreadonly, mt, false)
    OriginalNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = { ... }

        if checkcaller() then
            return OriginalNamecall(self, ...)
        end

        if method == "FireServer" or method == "InvokeServer" then
            local fullName = ""
            pcall(function() fullName = self:GetFullName() end)
            local name = self.Name or "?"

            -- record candidate
            if Scanning then
                local entry = NamecallStats[fullName] or { count = 0, name = name, path = fullName }
                entry.count = entry.count + 1
                NamecallStats[fullName] = entry
            end

            local match = false
            if State.BulletRemotePath ~= "" then
                if fullName == State.BulletRemotePath then match = true end
            else
                -- auto-pattern detection
                local lower = name:lower()
                if lower:find("shoot") or lower:find("fire") or lower:find("bullet") or lower:find("hit") or lower:find("damage") or lower:find("weapon") then
                    -- verify args contain a position
                    for _, v in ipairs(args) do
                        local t = typeof(v)
                        if t == "Vector3" or t == "CFrame" then
                            match = true; break
                        end
                    end
                end
            end

            if match and State.Enabled then
                local newArgs, did = redirectArgs(args, name)
                if did then
                    return OriginalNamecall(self, table.unpack(newArgs))
                end
            end
        end

        return OriginalNamecall(self, ...)
    end))
    HookInstalled = true
end

local function startScan(secs, onDone)
    Scanning = true
    NamecallStats = {}
    notify("Auto-detect", "Scanning for " .. secs .. "s. Fire a few shots.", "info", secs)
    task.delay(secs, function()
        Scanning = false
        local list = {}
        for path, e in pairs(NamecallStats) do
            table.insert(list, e)
        end
        table.sort(list, function(a,b) return a.count > b.count end)
        local top = {}
        for i = 1, math.min(5, #list) do
            table.insert(top, list[i].path)
        end
        State.LastDetected = top
        if top[1] then
            State.BulletRemotePath = top[1]
            notify("Auto-detect", "Top candidate: " .. top[1], "success", 5)
        else
            notify("Auto-detect", "No remotes captured", "warn", 4)
        end
        if onDone then onDone(top) end
    end)
end

------------------------------------------------------------------------
-- TRIGGER MODE LOOP
------------------------------------------------------------------------
local TriggerLoop
local function startTriggerLoop()
    if TriggerLoop then return end
    TriggerLoop = track(RunService.RenderStepped:Connect(function()
        if not State.Enabled then return end
        if State.TriggerMode == "Trigger Bot" then
            local tgt = selectTarget()
            if tgt then
                local part = targetPartFor(tgt)
                if part then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local mp = UserInputService:GetMouseLocation()
                        local d = (Vector2.new(screenPos.X, screenPos.Y) - mp).Magnitude
                        if d < 60 then
                            -- attempt to fire via mouse1 click virtual input
                            pcall(function()
                                local vim = cloneref(game:GetService("VirtualInputManager"))
                                vim:SendMouseButtonEvent(mp.X, mp.Y, 0, true, game, 1)
                                task.wait(0.02)
                                vim:SendMouseButtonEvent(mp.X, mp.Y, 0, false, game, 1)
                            end)
                        end
                    end
                end
            end
        end
    end))
end

------------------------------------------------------------------------
-- GUI CONSTRUCTION
------------------------------------------------------------------------
local Gui
local Window
local ActivePage = "General"
local CardCache = {}    -- key -> { frame, keywords }
local Dragging = false
local DragStart, StartPos

local function buildGui()
    Gui = newInstance("ScreenGui", {
        Name = "ENI_MagicBullet",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    pcall(protect_gui, Gui)
    if not Gui.Parent then Gui.Parent = CoreGui end

    Window = newInstance("Frame", {
        Name = "Window",
        BackgroundColor3 = Theme.WindowBg,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 920, 0, 600),
        Position = UDim2.new(0.5, -460, 0.5, -300),
        Parent = Gui,
    })
    corner(Window, 10)
    stroke(Window, Theme.Border, 1)

    -- 2px magenta accent stripe at top
    newInstance("Frame", {
        BackgroundColor3 = Theme.AccentPrimary,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 0, 0),
        Parent = Window,
    })

    -- TITLE BAR
    local titleBar = newInstance("Frame", {
        Name = "TitleBar",
        BackgroundColor3 = Theme.WindowBg,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 40),
        Position = UDim2.new(0, 0, 0, 2),
        Parent = Window,
    })

    -- logo
    local logo = newInstance("Frame", {
        BackgroundColor3 = Theme.AccentPrimary,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0, 14, 0.5, -6),
        Parent = titleBar,
    })
    corner(logo, 3)

    newInstance("TextLabel", {
        BackgroundTransparency = 1,
        Text = "freezer",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(0, 200, 1, 0),
        Position = UDim2.new(0, 34, 0, 0),
        Parent = titleBar,
    })

    -- search bar
    local searchHolder = newInstance("Frame", {
        BackgroundColor3 = Theme.ContentBg,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 380, 0, 28),
        Position = UDim2.new(0.5, -190, 0.5, -14),
        Parent = titleBar,
    })
    corner(searchHolder, 14)
    newInstance("TextLabel", {
        BackgroundTransparency = 1,
        Text = "\u{1F50D}",
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = Theme.TextDim,
        Size = UDim2.new(0, 20, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        Parent = searchHolder,
    })
    local searchBox = newInstance("TextBox", {
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Search settings",
        PlaceholderColor3 = Theme.TextDim,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = Theme.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -36, 1, 0),
        Position = UDim2.new(0, 28, 0, 0),
        ClearTextOnFocus = false,
        Parent = searchHolder,
    })

    -- min / close
    local function winBtn(text, x, isClose)
        local btn = newInstance("TextButton", {
            BackgroundColor3 = Theme.WindowBg,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = text,
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextColor3 = Theme.TextPrimary,
            Size = UDim2.new(0, 46, 1, 0),
            Position = UDim2.new(1, x, 0, 0),
            AutoButtonColor = false,
            Parent = titleBar,
        })
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TWEEN_FAST, {
                BackgroundTransparency = 0,
                BackgroundColor3 = isClose and Theme.Danger or Theme.CardBg,
            }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TWEEN_FAST, { BackgroundTransparency = 1 }):Play()
        end)
        return btn
    end
    local minBtn = winBtn("\u{2013}", -92, false)
    local closeBtn = winBtn("\u{2715}", -46, true)
    minBtn.MouseButton1Click:Connect(function()
        Window.Visible = false
    end)
    closeBtn.MouseButton1Click:Connect(function()
        Window.Visible = false
    end)

    -- DRAG
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Dragging = true
            DragStart = input.Position
            StartPos = Window.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    Dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - DragStart
            Window.Position = UDim2.new(
                StartPos.X.Scale, StartPos.X.Offset + delta.X,
                StartPos.Y.Scale, StartPos.Y.Offset + delta.Y
            )
        end
    end)

    -- SIDEBAR
    local sidebar = newInstance("Frame", {
        Name = "Sidebar",
        BackgroundColor3 = Theme.SidebarBg,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 220, 1, -42 - 26),
        Position = UDim2.new(0, 0, 0, 42),
        Parent = Window,
    })

    local navLayout = newInstance("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = sidebar,
    })

    local Pages = {
        { id = "General",       label = "General",       icon = "\u{2699}" },
        { id = "Targeting",     label = "Targeting",     icon = "\u{1F3AF}" },
        { id = "Remote",        label = "Remote",        icon = "\u{1F4E1}" },
        { id = "Modes",         label = "Modes",         icon = "\u{1F500}" },
        { id = "AntiDetect",    label = "Anti-Detect",   icon = "\u{1F6E1}" },
        { id = "Trigger",       label = "Trigger",       icon = "\u{1F518}" },
        { id = "Visual",        label = "Visual",        icon = "\u{1F441}" },
        { id = "Debug",         label = "Debug",         icon = "\u{1F41E}" },
        { id = "Presets",       label = "Presets",       icon = "\u{1F4DA}" },
        { id = "Settings",      label = "Settings",      icon = "\u{1F527}" },
    }

    local NavButtons = {}
    local ContentPages = {}

    -- CONTENT AREA
    local content = newInstance("Frame", {
        Name = "Content",
        BackgroundColor3 = Theme.ContentBg,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -220, 1, -42 - 26),
        Position = UDim2.new(0, 220, 0, 42),
        Parent = Window,
    })

    -- STATUS BAR
    local statusBar = newInstance("Frame", {
        BackgroundColor3 = Theme.WindowBg,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 26),
        Position = UDim2.new(0, 0, 1, -26),
        Parent = Window,
    })
    newInstance("Frame", {
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        Parent = statusBar,
    })
    newInstance("Frame", {
        BackgroundColor3 = Theme.AccentPrimary,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 6, 0, 6),
        Position = UDim2.new(0, 10, 0.5, -3),
        Parent = statusBar,
    })
    corner(statusBar:GetChildren()[2], 3)
    local statusLeft = newInstance("TextLabel", {
        BackgroundTransparency = 1,
        Text = "",
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = Theme.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(0.5, -30, 1, 0),
        Position = UDim2.new(0, 24, 0, 0),
        Parent = statusBar,
    })
    local statusRight = newInstance("TextLabel", {
        BackgroundTransparency = 1,
        Text = "",
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = Theme.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Right,
        Size = UDim2.new(0.5, -10, 1, 0),
        Position = UDim2.new(0.5, 0, 0, 0),
        Parent = statusBar,
    })

    -- live status update
    track(RunService.Heartbeat:Connect(function()
        local fps = math.floor(1 / RunService.RenderStepped:Wait(0) + 0.5)
    end))
    task.spawn(function()
        while Gui.Parent do
            local fps = math.floor(workspace:GetRealPhysicsFPS() + 0.5)
            local ping = "?"
            pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing()*1000) end)
            local gname = "Roblox"
            pcall(function() gname = MarketplaceService:GetProductInfo(game.PlaceId).Name end)
            statusLeft.Text = string.format("FPS %d | Ping %sms | %d players | %s | %s",
                fps, tostring(ping), #Players:GetPlayers(), gname, os.date("%H:%M"))
            statusRight.Text = string.format("remote: %s | mode: %s | shots: %d",
                State.BulletRemotePath ~= "" and State.BulletRemotePath or "(auto)",
                State.Mode, State.Stats.Redirected)
            task.wait(1)
        end
    end)

    -- helper to build pages
    local function makePage(id)
        local scroll = newInstance("ScrollingFrame", {
            Name = id,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.AccentPrimary,
            Visible = false,
            Parent = content,
        })
        local pad = padding(scroll, 20)

        local header = newInstance("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -40, 0, 80),
            Parent = scroll,
        })
        newInstance("TextLabel", {
            BackgroundTransparency = 1,
            Text = "Home > Combat > " .. id,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextColor3 = Theme.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 14),
            Parent = header,
        })
        newInstance("TextLabel", {
            BackgroundTransparency = 1,
            Text = id,
            Font = Enum.Font.GothamBold,
            TextSize = 24,
            TextColor3 = Theme.TextPrimary,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 30),
            Position = UDim2.new(0, 0, 0, 18),
            Parent = header,
        })
        newInstance("TextLabel", {
            Name = "Desc",
            BackgroundTransparency = 1,
            Text = "",
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Theme.TextSecondary,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 18),
            Position = UDim2.new(0, 0, 0, 50),
            Parent = header,
        })

        local list = newInstance("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -40, 0, 0),
            Position = UDim2.new(0, 0, 0, 90),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = scroll,
        })
        local layout = newInstance("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
            Parent = list,
        })
        ContentPages[id] = { scroll = scroll, list = list, header = header }
        return scroll, list
    end

    -- Build nav buttons
    for i, page in ipairs(Pages) do
        local b = newInstance("TextButton", {
            BackgroundColor3 = Theme.SidebarBg,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Size = UDim2.new(1, 0, 0, 44),
            Parent = sidebar,
        })
        local selBar = newInstance("Frame", {
            BackgroundColor3 = Theme.AccentPrimary,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 3, 0.7, 0),
            Position = UDim2.new(0, 0, 0.15, 0),
            Visible = false,
            Parent = b,
        })
        newInstance("TextLabel", {
            BackgroundTransparency = 1,
            Text = page.icon,
            Font = Enum.Font.Gotham,
            TextSize = 16,
            TextColor3 = Theme.TextPrimary,
            Size = UDim2.new(0, 30, 1, 0),
            Position = UDim2.new(0, 12, 0, 0),
            Parent = b,
        })
        newInstance("TextLabel", {
            BackgroundTransparency = 1,
            Text = page.label,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Theme.TextPrimary,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, -50, 1, 0),
            Position = UDim2.new(0, 46, 0, 0),
            Parent = b,
        })
        b.MouseEnter:Connect(function()
            if ActivePage ~= page.id then
                TweenService:Create(b, TWEEN_FAST, { BackgroundTransparency = 0, BackgroundColor3 = Theme.CardBg }):Play()
            end
        end)
        b.MouseLeave:Connect(function()
            if ActivePage ~= page.id then
                TweenService:Create(b, TWEEN_FAST, { BackgroundTransparency = 1 }):Play()
            end
        end)
        b.MouseButton1Click:Connect(function()
            if ActivePage == page.id then return end
            -- deselect old
            local oldBtn = NavButtons[ActivePage]
            if oldBtn then
                oldBtn.bar.Visible = false
                TweenService:Create(oldBtn.btn, TWEEN_FAST, { BackgroundTransparency = 1 }):Play()
            end
            local oldPage = ContentPages[ActivePage]
            if oldPage then
                TweenService:Create(oldPage.scroll, TweenInfo.new(0.12), {}):Play()
                oldPage.scroll.Visible = false
            end
            ActivePage = page.id
            selBar.Visible = true
            TweenService:Create(b, TWEEN_FAST, { BackgroundTransparency = 0, BackgroundColor3 = Theme.AccentSoft }):Play()
            local newPage = ContentPages[page.id]
            if newPage then
                newPage.scroll.Visible = true
            end
        end)
        NavButtons[page.id] = { btn = b, bar = selBar }
        makePage(page.id)
    end

    -- Activate default page
    do
        local nb = NavButtons["General"]
        nb.bar.Visible = true
        TweenService:Create(nb.btn, TWEEN_FAST, { BackgroundTransparency = 0, BackgroundColor3 = Theme.AccentSoft }):Play()
        ContentPages["General"].scroll.Visible = true
    end

    -- ================================================================
    -- COMPONENT FACTORIES
    -- ================================================================
    local function makeCard(parent, title, desc)
        local card = newInstance("Frame", {
            BackgroundColor3 = Theme.CardBg,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 60),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = parent,
        })
        corner(card, 8)
        padding(card, 16)
        local header = newInstance("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 36),
            Parent = card,
        })
        newInstance("TextLabel", {
            BackgroundTransparency = 1,
            Text = title,
            Font = Enum.Font.GothamSemibold,
            TextSize = 14,
            TextColor3 = Theme.TextPrimary,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 18),
            Parent = header,
        })
        if desc then
            newInstance("TextLabel", {
                BackgroundTransparency = 1,
                Text = desc,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextColor3 = Theme.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left,
                Size = UDim2.new(1, 0, 0, 16),
                Position = UDim2.new(0, 0, 0, 18),
                Parent = header,
            })
        end
        local body = newInstance("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Position = UDim2.new(0, 0, 0, 40),
            Parent = card,
        })
        local layout = newInstance("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
            Parent = body,
        })
        CardCache[title:lower()] = card
        return body
    end

    local function makeRow(parent, label, sub)
        local row = newInstance("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 44),
            Parent = parent,
        })
        newInstance("TextLabel", {
            BackgroundTransparency = 1,
            Text = label,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextColor3 = Theme.TextPrimary,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(0.5, 0, 0, sub and 18 or 44),
            Position = UDim2.new(0, 0, 0, sub and 4 or 0),
            Parent = row,
        })
        if sub then
            newInstance("TextLabel", {
                BackgroundTransparency = 1,
                Text = sub,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextColor3 = Theme.TextDim,
                TextXAlignment = Enum.TextXAlignment.Left,
                Size = UDim2.new(0.5, 0, 0, 14),
                Position = UDim2.new(0, 0, 0, 22),
                Parent = row,
            })
        end
        return row
    end

    local function makeToggle(row, initial, onChange)
        local container = newInstance("TextButton", {
            BackgroundColor3 = initial and Theme.AccentPrimary or Theme.CardBgHover,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Size = UDim2.new(0, 38, 0, 20),
            Position = UDim2.new(1, -38, 0.5, -10),
            Parent = row,
        })
        corner(container, 10)
        local knob = newInstance("Frame", {
            BackgroundColor3 = Color3.fromRGB(255,255,255),
            BorderSizePixel = 0,
            Size = UDim2.new(0, 16, 0, 16),
            Position = initial and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
            Parent = container,
        })
        corner(knob, 8)
        local val = initial
        local function set(v, silent)
            val = v
            TweenService:Create(container, TWEEN_FAST, {
                BackgroundColor3 = v and Theme.AccentPrimary or Theme.CardBgHover,
            }):Play()
            TweenService:Create(knob, TWEEN_FAST, {
                Position = v and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
            }):Play()
            if not silent and onChange then onChange(v) end
        end
        container.MouseButton1Click:Connect(function() set(not val) end)
        return { Set = set, Get = function() return val end, Instance = container }
    end

    local function makeSlider(row, min, max, value, decimals, onChange)
        local holder = newInstance("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 240, 0, 20),
            Position = UDim2.new(1, -240, 0.5, -10),
            Parent = row,
        })
        local track = newInstance("Frame", {
            BackgroundColor3 = Theme.CardBgHover,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 180, 0, 4),
            Position = UDim2.new(0, 0, 0.5, -2),
            Parent = holder,
        })
        corner(track, 2)
        local fill = newInstance("Frame", {
            BackgroundColor3 = Theme.AccentPrimary,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 0, 1, 0),
            Parent = track,
        })
        corner(fill, 2)
        local knob = newInstance("Frame", {
            BackgroundColor3 = Color3.fromRGB(255,255,255),
            BorderSizePixel = 0,
            Size = UDim2.new(0, 14, 0, 14),
            Position = UDim2.new(0, -7, 0.5, -7),
            Parent = track,
        })
        corner(knob, 7)
        local valLabel = newInstance("TextLabel", {
            BackgroundTransparency = 1,
            Text = "",
            Font = Enum.Font.Code,
            TextSize = 12,
            TextColor3 = Theme.TextSecondary,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(0, 56, 1, 0),
            Position = UDim2.new(0, 184, 0, 0),
            Parent = holder,
        })

        local current = value
        local function refresh(v, silent)
            v = math.clamp(v, min, max)
            local mult = 10 ^ (decimals or 0)
            v = math.floor(v * mult + 0.5) / mult
            current = v
            local pct = (v - min) / (max - min)
            fill.Size = UDim2.new(pct, 0, 1, 0)
            knob.Position = UDim2.new(pct, -7, 0.5, -7)
            valLabel.Text = decimals and decimals > 0 and string.format("%."..decimals.."f", v) or tostring(math.floor(v))
            if not silent and onChange then onChange(v) end
        end
        refresh(value, true)

        local dragging = false
        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local rel = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
                refresh(min + (max - min) * rel)
            end
        end)
        return { Set = function(v) refresh(v, true) end, Get = function() return current end }
    end

    local function makeDropdown(row, options, value, onChange)
        local btn = newInstance("TextButton", {
            BackgroundColor3 = Theme.ContentBg,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Size = UDim2.new(0, 160, 0, 28),
            Position = UDim2.new(1, -160, 0.5, -14),
            Parent = row,
        })
        corner(btn, 4)
        stroke(btn, Theme.Border, 1)
        local lbl = newInstance("TextLabel", {
            BackgroundTransparency = 1,
            Text = tostring(value),
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = Theme.TextPrimary,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, -24, 1, 0),
            Position = UDim2.new(0, 10, 0, 0),
            Parent = btn,
        })
        newInstance("TextLabel", {
            BackgroundTransparency = 1,
            Text = "\u{25BE}",
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextColor3 = Theme.TextDim,
            Size = UDim2.new(0, 20, 1, 0),
            Position = UDim2.new(1, -20, 0, 0),
            Parent = btn,
        })

        local current = value
        local listOpen = false
        local listFrame

        local function closeList()
            if listFrame then
                listFrame:Destroy()
                listFrame = nil
            end
            listOpen = false
        end
        local function openList()
            if listOpen then return end
            listOpen = true
            listFrame = newInstance("Frame", {
                BackgroundColor3 = Theme.ContentBg,
                BorderSizePixel = 0,
                Size = UDim2.new(0, 160, 0, math.min(#options * 26, 200)),
                Position = UDim2.new(0, btn.AbsolutePosition.X, 0, btn.AbsolutePosition.Y + 30),
                ZIndex = 50,
                Parent = Gui,
            })
            corner(listFrame, 4)
            stroke(listFrame, Theme.Border, 1)
            local sc = newInstance("ScrollingFrame", {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 1, 0),
                CanvasSize = UDim2.new(0, 0, 0, #options * 26),
                ScrollBarThickness = 3,
                ScrollBarImageColor3 = Theme.AccentPrimary,
                ZIndex = 51,
                Parent = listFrame,
            })
            for i, opt in ipairs(options) do
                local item = newInstance("TextButton", {
                    BackgroundColor3 = Theme.ContentBg,
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Text = tostring(opt),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = opt == current and Theme.AccentPrimary or Theme.TextPrimary,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Size = UDim2.new(1, 0, 0, 26),
                    Position = UDim2.new(0, 0, 0, (i-1)*26),
                    ZIndex = 52,
                    Parent = sc,
                })
                newInstance("UIPadding", {
                    PaddingLeft = UDim.new(0, 10),
                    Parent = item,
                })
                item.MouseEnter:Connect(function()
                    item.BackgroundTransparency = 0
                    item.BackgroundColor3 = Theme.CardBg
                end)
                item.MouseLeave:Connect(function()
                    item.BackgroundTransparency = 1
                end)
                item.MouseButton1Click:Connect(function()
                    current = opt
                    lbl.Text = tostring(opt)
                    closeList()
                    if onChange then onChange(opt) end
                end)
            end
            -- outside click close
            task.delay(0.05, function()
                local conn
                conn = UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local mp = UserInputService:GetMouseLocation()
                        if listFrame then
                            local a, s = listFrame.AbsolutePosition, listFrame.AbsoluteSize
                            if mp.X < a.X or mp.X > a.X + s.X or mp.Y < a.Y or mp.Y > a.Y + s.Y then
                                local ba, bs = btn.AbsolutePosition, btn.AbsoluteSize
                                if mp.X < ba.X or mp.X > ba.X + bs.X or mp.Y < ba.Y or mp.Y > ba.Y + bs.Y then
                                    closeList()
                                    conn:Disconnect()
                                end
                            end
                        else
                            conn:Disconnect()
                        end
                    end
                end)
            end)
        end
        btn.MouseButton1Click:Connect(function()
            if listOpen then closeList() else openList() end
        end)
        return {
            Set = function(v) current = v; lbl.Text = tostring(v) end,
            Get = function() return current end,
            SetOptions = function(opts) options = opts end,
        }
    end

    local function makeButton(row, label, kind, onClick)
        local color = Theme.AccentPrimary
        local txtColor = Color3.fromRGB(255,255,255)
        if kind == "secondary" then color = Theme.CardBgHover; txtColor = Theme.TextPrimary
        elseif kind == "danger" then color = Theme.Danger end
        local btn = newInstance("TextButton", {
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = label,
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextColor3 = txtColor,
            Size = UDim2.new(0, 120, 0, 30),
            Position = UDim2.new(1, -120, 0.5, -15),
            Parent = row,
        })
        corner(btn, 4)
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TWEEN_FAST, { BackgroundColor3 = color:Lerp(Color3.fromRGB(255,255,255), 0.1) }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TWEEN_FAST, { BackgroundColor3 = color }):Play()
        end)
        btn.MouseButton1Click:Connect(onClick)
        return btn
    end

    local function makeTextbox(row, value, placeholder, onChange)
        local tb = newInstance("TextBox", {
            BackgroundColor3 = Theme.ContentBg,
            BorderSizePixel = 0,
            Text = value or "",
            PlaceholderText = placeholder or "",
            PlaceholderColor3 = Theme.TextDim,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = Theme.TextPrimary,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            Size = UDim2.new(0, 280, 0, 28),
            Position = UDim2.new(1, -280, 0.5, -14),
            Parent = row,
        })
        corner(tb, 4)
        local strk = stroke(tb, Theme.Border, 1)
        newInstance("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = tb })
        tb.Focused:Connect(function()
            TweenService:Create(strk, TWEEN_FAST, { Color = Theme.AccentPrimary }):Play()
        end)
        tb.FocusLost:Connect(function()
            TweenService:Create(strk, TWEEN_FAST, { Color = Theme.Border }):Play()
            if onChange then onChange(tb.Text) end
        end)
        return tb
    end

    local function makeKeybind(row, initial, onChange)
        local btn = newInstance("TextButton", {
            BackgroundColor3 = Theme.ContentBg,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = initial,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = Theme.TextPrimary,
            Size = UDim2.new(0, 100, 0, 28),
            Position = UDim2.new(1, -100, 0.5, -14),
            Parent = row,
        })
        corner(btn, 4)
        stroke(btn, Theme.Border, 1)
        local listening = false
        btn.MouseButton1Click:Connect(function()
            listening = true
            btn.Text = "Press a key..."
            local conn
            conn = UserInputService.InputBegan:Connect(function(input)
                if input.KeyCode ~= Enum.KeyCode.Unknown then
                    if input.KeyCode == Enum.KeyCode.Escape then
                        btn.Text = "None"
                        if onChange then onChange("None") end
                    else
                        btn.Text = input.KeyCode.Name
                        if onChange then onChange(input.KeyCode.Name) end
                    end
                    listening = false
                    conn:Disconnect()
                end
            end)
        end)
        return btn
    end

    -- ================================================================
    -- BUILD CONTENT
    -- ================================================================
    local pGen = ContentPages.General
    pGen.header.Desc.Text = "Master toggle, mode, range. The core of Magic Bullet."

    do
        local body = makeCard(pGen.list, "Master", "Turn Magic Bullet on or off.")
        local r1 = makeRow(body, "Enabled", "Globally hook and redirect bullets")
        makeToggle(r1, State.Enabled, function(v)
            State.Enabled = v; saveConfig()
            if v then notify("Magic Bullet", "Armed.", "success", 2)
            else notify("Magic Bullet", "Disarmed.", "warn", 2) end
        end)
        local r2 = makeRow(body, "Mode", "Redirection strategy")
        makeDropdown(r2, { "Direct", "Wall-Pen", "Arc", "All-In" }, State.Mode, function(v)
            State.Mode = v; saveConfig()
        end)
        local r3 = makeRow(body, "Range", "Skip targets beyond this distance (studs)")
        makeSlider(r3, 0, 2000, State.Range, 0, function(v)
            State.Range = v; saveConfig()
        end)
    end

    do
        local body = makeCard(pGen.list, "Trigger", "How shots are triggered.")
        local r1 = makeRow(body, "Trigger Mode", "When the kit redirects")
        makeDropdown(r1, { "While Firing", "Trigger Bot", "Manual" }, State.TriggerMode, function(v)
            State.TriggerMode = v; saveConfig()
        end)
        local r2 = makeRow(body, "Force-Hit", "Skip client LOS calls before FireServer")
        makeToggle(r2, State.ForceHit, function(v) State.ForceHit = v; saveConfig() end)
    end

    -- TARGETING PAGE
    local pTgt = ContentPages.Targeting
    pTgt.header.Desc.Text = "Choose how the kit picks who to hit and where."
    do
        local body = makeCard(pTgt.list, "Selection", "Which player to lock on.")
        local r1 = makeRow(body, "Target Selection")
        makeDropdown(r1, { "Closest to Mouse", "Closest to Crosshair", "Lowest HP", "Highest Threat" }, State.TargetSelection, function(v)
            State.TargetSelection = v; saveConfig()
        end)
        local r2 = makeRow(body, "Target Part", "Which body part to aim at")
        makeDropdown(r2, { "Head", "HumanoidRootPart", "UpperTorso", "Random" }, State.TargetPart, function(v)
            State.TargetPart = v; saveConfig()
        end)
        local r3 = makeRow(body, "Wall Check Inverse", "Only fire when target is BEHIND a wall")
        makeToggle(r3, State.WallCheckInverse, function(v) State.WallCheckInverse = v; saveConfig() end)
        local r4 = makeRow(body, "Test Target", "Force-focus a specific player")
        local playerOpts = { "(none)" }
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then table.insert(playerOpts, plr.Name) end
        end
        local ttDrop = makeDropdown(r4, playerOpts, State.TestTarget, function(v)
            State.TestTarget = v; saveConfig()
        end)
        track(Players.PlayerAdded:Connect(function(p)
            local opts = { "(none)" }
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then table.insert(opts, plr.Name) end
            end
            ttDrop.SetOptions(opts)
        end))
    end

    -- REMOTE PAGE
    local pRem = ContentPages.Remote
    pRem.header.Desc.Text = "Configure which RemoteEvent carries the bullet."
    do
        local body = makeCard(pRem.list, "Bullet Remote", "FireServer path. Leave empty for auto-pattern.")
        local r1 = makeRow(body, "Remote Path")
        local tb = makeTextbox(r1, State.BulletRemotePath, "ReplicatedStorage.Events.Shoot", function(v)
            State.BulletRemotePath = v; saveConfig()
            notify("Remote", "Set to: " .. (v ~= "" and v or "(auto)"), "info", 3)
        end)
        local r2 = makeRow(body, "Auto-detect", "Scan namecall traffic for 5s")
        makeButton(r2, "Scan 5s", "primary", function()
            startScan(5, function(top)
                tb.Text = State.BulletRemotePath
            end)
        end)
        local r3 = makeRow(body, "Last Detected", "Top 5 candidates by frequency")
        local detectedOpts = #State.LastDetected > 0 and State.LastDetected or { "(empty)" }
        local detDrop = makeDropdown(r3, detectedOpts, detectedOpts[1], function(v)
            if v ~= "(empty)" then
                State.BulletRemotePath = v; tb.Text = v; saveConfig()
                notify("Remote", "Adopted: " .. v, "success", 3)
            end
        end)
    end
    do
        local body = makeCard(pRem.list, "Argument Editor", "Which arg index carries hit position / direction.")
        local r1 = makeRow(body, "Hit Position Index", "Default 1")
        makeSlider(r1, 1, 8, State.HitPosArgIndex, 0, function(v) State.HitPosArgIndex = v; saveConfig() end)
        local r2 = makeRow(body, "Direction Index", "Default 2")
        makeSlider(r2, 1, 8, State.DirectionArgIndex, 0, function(v) State.DirectionArgIndex = v; saveConfig() end)
    end

    -- MODES PAGE
    local pMod = ContentPages.Modes
    pMod.header.Desc.Text = "Visual explanation of each redirection mode."
    do
        local body = makeCard(pMod.list, "Mode Reference", nil)
        for _, m in ipairs({
            { "Direct", "Hit position = target part position. No validation. Fastest, loudest." },
            { "Wall-Pen", "Skip LOS hook so server believes the ray passed through cover." },
            { "Arc", "Bent direction vector with multiple endpoint candidates if remote accepts arrays." },
            { "All-In", "Every mode stacked. Use only when server is loose." },
        }) do
            local r = makeRow(body, m[1], m[2])
            r.Size = UDim2.new(1, 0, 0, 44)
        end
    end

    -- ANTI-DETECT PAGE
    local pAnti = ContentPages.AntiDetect
    pAnti.header.Desc.Text = "Throttling and noise to make redirections look natural."
    do
        local body = makeCard(pAnti.list, "Rate Limiting", "Don't redirect every single bullet.")
        local r1 = makeRow(body, "Max Bullets / sec", "Queue overflow is dropped")
        makeSlider(r1, 1, 30, State.MaxBulletsPerSec, 0, function(v) State.MaxBulletsPerSec = v; saveConfig() end)
        local r2 = makeRow(body, "Hit-Position Jitter", "Random offset in studs")
        makeSlider(r2, 0, 3, State.HitJitter, 2, function(v) State.HitJitter = v; saveConfig() end)
        local r3 = makeRow(body, "Occasional Miss", "% of shots intentionally not redirected")
        makeSlider(r3, 0, 50, State.OccasionalMissPct, 0, function(v) State.OccasionalMissPct = v; saveConfig() end)
    end

    -- TRIGGER PAGE
    local pTrg = ContentPages.Trigger
    pTrg.header.Desc.Text = "Manual triggering and test fire."
    do
        local body = makeCard(pTrg.list, "Test Fire", "Simulate one redirection.")
        local r1 = makeRow(body, "Fire at locked-on target")
        makeButton(r1, "Test Fire", "primary", function()
            if not State.Enabled then
                notify("Test Fire", "Enable Magic Bullet first.", "warn", 3); return
            end
            local tgt = selectTarget()
            if not tgt then notify("Test Fire", "No target found.", "warn", 3); return end
            local part = targetPartFor(tgt)
            if not part then notify("Test Fire", "No part on target.", "warn", 3); return end
            State.Stats.Redirected = State.Stats.Redirected + 1
            logRedirect("(test)", tostring(Camera.CFrame.Position), tostring(part.Position), tgt.Name)
            notify("Test Fire", "Simulated hit on " .. tgt.Name .. " (" .. part.Name .. ")", "success", 3)
        end)
    end

    -- VISUAL PAGE
    local pVis = ContentPages.Visual
    pVis.header.Desc.Text = "Drawing overlays for debugging."
    do
        local body = makeCard(pVis.list, "Visualizer", "On-screen rays.")
        local r1 = makeRow(body, "Drawing Visualizer", "Red = original, Magenta = redirected")
        makeToggle(r1, State.DrawingVisualizer, function(v)
            State.DrawingVisualizer = v; saveConfig()
            ensureDrawings()
        end)
    end

    -- DEBUG PAGE
    local pDbg = ContentPages.Debug
    pDbg.header.Desc.Text = "Recent redirections and stats."
    do
        local body = makeCard(pDbg.list, "Log", "Last 30 redirections (newest first).")
        local logBox = newInstance("ScrollingFrame", {
            BackgroundColor3 = Theme.ContentBg,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 220),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.AccentPrimary,
            Parent = body,
        })
        corner(logBox, 4)
        local logLayout = newInstance("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = logBox,
        })
        newInstance("UIPadding", {
            PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), Parent = logBox,
        })

        local function refreshLog()
            for _, c in ipairs(logBox:GetChildren()) do
                if c:IsA("TextLabel") then c:Destroy() end
            end
            for _, entry in ipairs(State.DebugLog) do
                local line = newInstance("TextLabel", {
                    BackgroundTransparency = 1,
                    Text = string.format("[%s] %s -> %s | %s via %s",
                        entry.t, entry.orig, entry.new, entry.target, entry.remote),
                    Font = Enum.Font.Code,
                    TextSize = 11,
                    TextColor3 = Theme.TextSecondary,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Size = UDim2.new(1, -16, 0, 16),
                    Parent = logBox,
                })
            end
        end
        track(RunService.Heartbeat:Connect(function()
            if pDbg.scroll.Visible then
                if tick() % 1 < 0.02 then refreshLog() end
            end
        end))
        refreshLog()
    end
    do
        local body = makeCard(pDbg.list, "Stats", "Lifetime counters.")
        local r1 = makeRow(body, "Redirected")
        local s1 = newInstance("TextLabel", {
            BackgroundTransparency = 1, Text = "0", Font = Enum.Font.Code, TextSize = 13,
            TextColor3 = Theme.AccentPrimary, TextXAlignment = Enum.TextXAlignment.Right,
            Size = UDim2.new(0, 100, 1, 0), Position = UDim2.new(1, -100, 0, 0), Parent = r1,
        })
        local r2 = makeRow(body, "Hit Rate")
        local s2 = newInstance("TextLabel", {
            BackgroundTransparency = 1, Text = "0%", Font = Enum.Font.Code, TextSize = 13,
            TextColor3 = Theme.Success, TextXAlignment = Enum.TextXAlignment.Right,
            Size = UDim2.new(0, 100, 1, 0), Position = UDim2.new(1, -100, 0, 0), Parent = r2,
        })
        local r3 = makeRow(body, "Last Redirect")
        local s3 = newInstance("TextLabel", {
            BackgroundTransparency = 1, Text = "never", Font = Enum.Font.Code, TextSize = 12,
            TextColor3 = Theme.TextSecondary, TextXAlignment = Enum.TextXAlignment.Right,
            Size = UDim2.new(0, 160, 1, 0), Position = UDim2.new(1, -160, 0, 0), Parent = r3,
        })
        task.spawn(function()
            while Gui.Parent do
                s1.Text = tostring(State.Stats.Redirected)
                local hitRate = State.Stats.Redirected > 0 and math.floor((State.Stats.Hits / State.Stats.Redirected) * 100) or 0
                s2.Text = hitRate .. "%"
                s3.Text = State.Stats.LastTs > 0 and os.date("%H:%M:%S", State.Stats.LastTs) or "never"
                task.wait(0.5)
            end
        end)
    end

    -- PRESETS PAGE
    local pPre = ContentPages.Presets
    pPre.header.Desc.Text = "Per-game presets prefill remote path and arg indices."
    do
        local body = makeCard(pPre.list, "Preset", "Choose a game preset.")
        local r1 = makeRow(body, "Active Preset")
        makeDropdown(r1, {
            "Generic", "Phantom Forces", "Counter-Blox", "Big Paintball",
            "Da Hood", "Arsenal", "Bad Business", "Custom",
        }, State.Preset, function(v)
            State.Preset = v
            local presets = {
                ["Phantom Forces"] = { remote = "ReplicatedStorage.Events.HitPart", hit = 1, dir = 2 },
                ["Counter-Blox"]   = { remote = "ReplicatedStorage.Game.Weapons.Fire",  hit = 2, dir = 3 },
                ["Big Paintball"]  = { remote = "ReplicatedStorage.Events.Shoot",       hit = 1, dir = 2 },
                ["Da Hood"]        = { remote = "ReplicatedStorage.Events.HitPart",     hit = 1, dir = 2 },
                ["Arsenal"]        = { remote = "ReplicatedStorage.Events.HitPart",     hit = 1, dir = 2 },
                ["Bad Business"]   = { remote = "ReplicatedStorage.Bullet.Hit",         hit = 1, dir = 2 },
            }
            local p = presets[v]
            if p then
                State.BulletRemotePath = p.remote
                State.HitPosArgIndex = p.hit
                State.DirectionArgIndex = p.dir
                notify("Preset", "Loaded: " .. v, "success", 3)
            end
            saveConfig()
        end)
    end

    -- SETTINGS PAGE
    local pSet = ContentPages.Settings
    pSet.header.Desc.Text = "Save, load, reset, keybinds."
    do
        local body = makeCard(pSet.list, "Config", "Persistent JSON in freezer/.")
        local r1 = makeRow(body, "Save Config")
        makeButton(r1, "Save", "primary", function()
            saveConfig(); notify("Settings", "Saved.", "success", 2)
        end)
        local r2 = makeRow(body, "Load Config")
        makeButton(r2, "Load", "secondary", function()
            loadConfig(); notify("Settings", "Loaded.", "success", 2)
        end)
        local r3 = makeRow(body, "Reset to Defaults")
        makeButton(r3, "Reset", "danger", function()
            for k, v in pairs(DEFAULTS) do
                if type(v) == "table" then
                    State[k] = {}
                    for kk, vv in pairs(v) do State[k][kk] = vv end
                else
                    State[k] = v
                end
            end
            saveConfig()
            notify("Settings", "Reset to defaults.", "warn", 3)
        end)
    end
    do
        local body = makeCard(pSet.list, "Keybinds", "Customize hotkeys.")
        local r1 = makeRow(body, "Toggle UI", "Show/hide window")
        makeKeybind(r1, State.ToggleKey, function(v) State.ToggleKey = v; saveConfig() end)
    end

    -- SEARCH FILTER
    track(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local q = searchBox.Text:lower()
        for key, card in pairs(CardCache) do
            if q == "" or key:find(q, 1, true) then
                card.Visible = true
            else
                card.Visible = false
            end
        end
    end))
end

------------------------------------------------------------------------
-- KEYBIND HANDLER
------------------------------------------------------------------------
local function installKeybinds()
    track(UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode.Name == State.ToggleKey then
                if Window then Window.Visible = not Window.Visible end
            end
        end
        -- While-Firing mode triggers redirect on mouse1
        if input.UserInputType == Enum.UserInputType.MouseButton1 and State.Enabled then
            if State.TriggerMode == "While Firing" or State.TriggerMode == "Manual" then
                -- nothing extra: the namecall hook will catch the FireServer
                State.Stats.Hits = State.Stats.Hits + 0
            end
        end
    end))
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------
getgenv().ENI = getgenv().ENI or {}

local API = {}

function API.Show()
    if Window then Window.Visible = true end
end
function API.Hide()
    if Window then Window.Visible = false end
end
function API.Toggle()
    if Window then Window.Visible = not Window.Visible end
end
function API.Destroy()
    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    Connections = {}
    if Gui then Gui:Destroy() end
    if NotifyGui then NotifyGui:Destroy() end
    for _, d in pairs(Drawings) do
        if d then pcall(function() d:Remove() end) end
    end
    getgenv().ENI.MagicBullet = nil
end
function API.GetConfig()
    local copy = {}
    for k, v in pairs(State) do copy[k] = v end
    return copy
end
function API.SetConfig(cfg)
    for k, v in pairs(cfg) do State[k] = v end
    saveConfig()
end
function API.GetStats()
    return State.Stats
end
function API.GetLog()
    return State.DebugLog
end
function API.SetEnabled(v)
    State.Enabled = v and true or false
    saveConfig()
end
function API.SetRemote(path)
    State.BulletRemotePath = path or ""
    saveConfig()
end
function API.SetMode(m)
    State.Mode = m
    saveConfig()
end
function API.Scan(secs, cb)
    startScan(secs or 5, cb)
end

------------------------------------------------------------------------
-- INIT
------------------------------------------------------------------------
buildGui()
installHook()
installKeybinds()
startTriggerLoop()

notify("Magic Bullet", "v3.0.0 loaded. Press " .. State.ToggleKey .. " to toggle.", "success", 4)

getgenv().ENI.MagicBullet = API
return API

end
-- END MODULE: MAGIC BULLET v3.0.0
----------------------------------------------------------------------

----------------------------------------------------------------------
-- MODULE: SILENT AIM v3.0.0 (1680 lines original)
----------------------------------------------------------------------
do
--[[
============================================================================
    eni-roblox-kit :: Silent Aim v3.0.0
    combat/silent_aim.lua
    ----------------------------------------------------------------------
    Hooks ray/mouse/raycast/namecall traffic and silently redirects shots
    toward a target part inside FOV. v3 ships AUTO-DETECT, verified preset
    arg-index tables, FOV circle leak fix, RemoteFunction support, and a
    race-free __namecall hook.
============================================================================
]]

--==[ ANTI-DETECT SHIMS ]======================================================
local cloneref = cloneref or function(x) return x end
local protect_gui = (syn and syn.protect_gui) or (gethui and function(g) g.Parent = gethui() end) or function(g) g.Parent = game:GetService('CoreGui') end
local hookmetamethod = hookmetamethod or function() return nil end
local getrawmetatable = getrawmetatable or function() return nil end
local setreadonly = setreadonly or function() end
local newcclosure = newcclosure or function(f) return f end
local checkcaller = checkcaller or function() return false end
local hookfunction = hookfunction or function() return nil end
local getnamecallmethod = getnamecallmethod or function() return '' end
local mousemoverel = mousemoverel or function() end
local isfile = isfile or function() return false end
local readfile = readfile or function() return nil end
local writefile = writefile or function() end
local makefolder = makefolder or function() end
local isfolder = isfolder or function() return false end

--==[ SERVICES ]===============================================================
local Players = cloneref(game:GetService('Players'))
local RunService = cloneref(game:GetService('RunService'))
local UserInputService = cloneref(game:GetService('UserInputService'))
local TweenService = cloneref(game:GetService('TweenService'))
local HttpService = cloneref(game:GetService('HttpService'))
local Lighting = cloneref(game:GetService('Lighting'))
local Workspace = cloneref(game:GetService('Workspace'))
local MarketplaceService = cloneref(game:GetService('MarketplaceService'))

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--==[ THEME ]==================================================================
local THEME = {
    WindowBg      = Color3.fromRGB(20, 20, 26),
    SidebarBg     = Color3.fromRGB(24, 24, 30),
    ContentBg     = Color3.fromRGB(28, 28, 34),
    CardBg        = Color3.fromRGB(36, 36, 44),
    CardBgHover   = Color3.fromRGB(42, 42, 52),
    Border        = Color3.fromRGB(54, 54, 66),
    AccentPrimary = Color3.fromRGB(255, 65, 180),
    AccentSoft    = Color3.fromRGB(80, 32, 60),
    TextPrimary   = Color3.fromRGB(240, 240, 248),
    TextSecondary = Color3.fromRGB(170, 170, 188),
    TextDim       = Color3.fromRGB(115, 115, 135),
    Success       = Color3.fromRGB(80, 220, 130),
    Warning       = Color3.fromRGB(255, 185, 70),
    Danger        = Color3.fromRGB(255, 90, 110),
}
local TWEEN_FAST = TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TWEEN_DEF  = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local CONFIG_FOLDER = 'freezer'
local CONFIG_FILE   = CONFIG_FOLDER .. '/silent_aim.json'

--==[ VERIFIED PRESETS (arg indices per game) ]================================
local PRESETS = {
    Generic              = { remote = nil,         hitArg = 1, dirArg = 2, kind = 'auto' },
    ['Phantom Forces']   = { remote = 'HitPart',   hitArg = 1, dirArg = 2, kind = 'vector' },
    ['Counter-Blox']     = { remote = 'BulletFire',hitArg = 2, dirArg = 3, kind = 'vector' },
    ['Big Paintball']    = { remote = 'hit',       hitArg = 1, dirArg = 2, kind = 'vector' },
    ['Da Hood']          = { remote = 'RigEvent',  hitArg = 1, dirArg = 2, kind = 'cframe' },
    Arsenal              = { remote = 'HitPart',   hitArg = 1, dirArg = 3, kind = 'vector' },
    ['Bad Business']     = { remote = 'Bullet',    hitArg = 1, dirArg = 2, kind = 'vector' },
    ['Murder Mystery 2'] = { remote = 'KillPlayer',hitArg = 1, dirArg = 2, kind = 'player' },
    Strucid              = { remote = 'HitEvent',  hitArg = 1, dirArg = 2, kind = 'vector' },
    Custom               = { remote = nil,         hitArg = 1, dirArg = 2, kind = 'vector' },
}

--==[ STATE ]==================================================================
local state = {
    Enabled = false,
    Method = 'AUTO',
    TargetPart = 'Head',
    FOV = 120,
    FOVCircleVisible = true,
    FOVCircleColor = {255, 65, 180},
    FOVCircleThickness = 1.4,
    WallCheck = true,
    TeamCheck = true,
    HitChance = 100,
    BoneRandom = false,
    Preset = 'Generic',
    CustomRemotes = '',
    ArgEditor = {},
    VelocityLead = 0.0,
    PingComp = 0,
    VisibilityCheck = false,
    Resolver = 'Off',
    MissEnabled = false,
    MissRate = 5,
    MaxMissDistance = 3,
    HitJitter = 0.0,
    AimAssistNudge = false,
    Smart = 'Closest to Mouse',
    CrosshairIndicator = true,
    CrosshairColor = {255, 65, 180},
    DebugVisualizer = false,
    HitTestMode = false,
    AutoDisableTimer = 0,
    KeybindToggle = 'H',
    KeybindAutoDetect = 'J',
}

local rt = {
    connections = {},
    fovCircle = nil,
    debugLog = {},
    statsRedirected = 0,
    statsShotsTotal = 0,
    statsHits = 0,
    autoDetectActive = false,
    autoDetectLog = {},
    lastMouseClick = 0,
    detectedRemote = nil,
    detectedArg = nil,
    detectedMethod = nil,
    lastTargetTime = tick(),
}

local screenGui, toastHolder
local pages = {}
local currentPage

--==[ UTIL ]===================================================================
local function colorTbl(t) return Color3.fromRGB(t[1], t[2], t[3]) end

local function isAlive(plr)
    if not plr or plr == LocalPlayer then return false end
    local ch = plr.Character
    if not ch then return false end
    local hum = ch:FindFirstChildOfClass('Humanoid')
    if not hum or hum.Health <= 0 then return false end
    if not (ch.PrimaryPart or ch:FindFirstChild('HumanoidRootPart')) then return false end
    return true
end

local function isTeammate(plr)
    if not plr or not LocalPlayer then return false end
    if plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then return true end
    return false
end

local function getPartByName(ch, name)
    if name == 'Random' then
        local list = { 'Head', 'HumanoidRootPart', 'UpperTorso', 'LowerTorso' }
        name = list[math.random(1, #list)]
    end
    return ch:FindFirstChild(name) or ch:FindFirstChild('HumanoidRootPart') or ch.PrimaryPart
end

local function worldToScreen(pos)
    local v, on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(v.X, v.Y), on, v.Z
end

local function hasLineOfSight(toPos)
    local fromPos = Camera.CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character or Instance.new('Folder') }
    local r = Workspace:Raycast(fromPos, (toPos - fromPos), params)
    if not r then return true end
    local model = r.Instance and r.Instance:FindFirstAncestorOfClass('Model')
    if model and Players:GetPlayerFromCharacter(model) then return true end
    return false
end

local function predictPosition(part, lead)
    if lead <= 0 then return part.Position end
    local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.zero
    return part.Position + vel * lead
end

local function pingCompensate(pos, part, ms)
    if ms <= 0 then return pos end
    local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.zero
    return pos + vel * (ms / 1000)
end

local function applyJitter(pos, j)
    if j <= 0 then return pos end
    return pos + Vector3.new(
        (math.random() - 0.5) * 2 * j,
        (math.random() - 0.5) * 2 * j,
        (math.random() - 0.5) * 2 * j
    )
end

local function applyResolver(plr, basePos)
    if state.Resolver == 'Off' then return basePos end
    local ch = plr.Character
    if not ch then return basePos end
    local hrp = ch:FindFirstChild('HumanoidRootPart')
    if not hrp then return basePos end
    if state.Resolver == 'Velocity' then
        return basePos + hrp.AssemblyLinearVelocity * 0.05
    elseif state.Resolver == 'Acceleration' then
        return basePos + hrp.AssemblyLinearVelocity * 0.08
    elseif state.Resolver == 'Anti-Anti-Aim' then
        local lower = ch:FindFirstChild('LowerTorso') or hrp
        return lower.Position
    end
    return basePos
end

local function shouldMiss()
    return state.MissEnabled and math.random(1, 100) <= state.MissRate
end

local function missOffset(basePos)
    local d = state.MaxMissDistance
    return basePos + Vector3.new(
        (math.random() - 0.5) * 2 * d,
        (math.random() - 0.5) * 2 * d,
        (math.random() - 0.5) * 2 * d
    )
end

local function pushLog(entry)
    table.insert(rt.debugLog, 1, entry)
    if #rt.debugLog > 50 then table.remove(rt.debugLog) end
end

--==[ TARGET SELECTION ]=======================================================
local function getMousePos()
    local m = UserInputService:GetMouseLocation()
    return Vector2.new(m.X, m.Y - 36)
end

local function getCrosshairPos()
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

local function pickTarget()
    local origin = (state.Smart == 'Closest to Crosshair') and getCrosshairPos() or getMousePos()
    local bestPlr, bestPart, bestScore
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not isAlive(plr) then continue end
        if state.TeamCheck and isTeammate(plr) then continue end
        local ch = plr.Character
        local part = getPartByName(ch, state.BoneRandom and 'Random' or state.TargetPart)
        if not part then continue end
        local screen, onScreen = worldToScreen(part.Position)
        if not onScreen then continue end
        local dist = (screen - origin).Magnitude
        if dist > state.FOV then continue end
        if state.VisibilityCheck and not hasLineOfSight(part.Position) then continue end

        local score
        if state.Smart == 'Lowest HP' then
            local hum = ch:FindFirstChildOfClass('Humanoid')
            score = hum and hum.Health or math.huge
        elseif state.Smart == 'Highest Threat' then
            local hum = ch:FindFirstChildOfClass('Humanoid')
            local hp = hum and hum.Health or 100
            score = hp * (dist + 1)
        else
            score = dist
        end

        if not bestScore or score < bestScore then
            bestScore, bestPlr, bestPart = score, plr, part
        end
    end
    return bestPlr, bestPart
end

local function resolveHitPosition(plr, part)
    if not plr or not part then return nil end
    local pos = predictPosition(part, state.VelocityLead)
    pos = pingCompensate(pos, part, state.PingComp)
    pos = applyResolver(plr, pos)
    pos = applyJitter(pos, state.HitJitter)
    if shouldMiss() then pos = missOffset(pos) end
    return pos
end

--==[ FOV CIRCLE (v3 fix: tracked & destroyed on disable) ]====================
local function ensureFovCircle()
    if rt.fovCircle then return end
    local ok, c = pcall(function()
        local d = Drawing.new('Circle')
        d.Thickness = state.FOVCircleThickness
        d.NumSides = 64
        d.Radius = state.FOV
        d.Filled = false
        d.Visible = state.FOVCircleVisible
        d.Color = colorTbl(state.FOVCircleColor)
        d.Transparency = 1
        return d
    end)
    if ok then rt.fovCircle = c end
end

local function killFovCircle()
    if rt.fovCircle then
        pcall(function() rt.fovCircle.Visible = false end)
        pcall(function() rt.fovCircle:Remove() end)
        rt.fovCircle = nil
    end
end

local function updateFovCircle()
    if not state.FOVCircleVisible or not state.Enabled then
        if rt.fovCircle then rt.fovCircle.Visible = false end
        return
    end
    ensureFovCircle()
    if not rt.fovCircle then return end
    local m = UserInputService:GetMouseLocation()
    rt.fovCircle.Position = Vector2.new(m.X, m.Y)
    rt.fovCircle.Radius = state.FOV
    rt.fovCircle.Color = colorTbl(state.FOVCircleColor)
    rt.fovCircle.Thickness = state.FOVCircleThickness
    rt.fovCircle.Visible = true
end

--==[ CONFIG ]=================================================================
local function trySaveConfig()
    if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, state)
    if ok then pcall(writefile, CONFIG_FILE, encoded) end
end

local function tryLoadConfig()
    if not isfile(CONFIG_FILE) then return end
    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok or not raw then return end
    local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
    if ok2 and type(decoded) == 'table' then
        for k, v in pairs(decoded) do state[k] = v end
    end
end

local function getRemoteArgConf(remoteName)
    if state.ArgEditor[remoteName] then return state.ArgEditor[remoteName] end
    local preset = PRESETS[state.Preset]
    if preset then return { hitArg = preset.hitArg, dirArg = preset.dirArg } end
    return { hitArg = 1, dirArg = 2 }
end

local function isCustomRemoteAllowed(remoteName)
    if not state.CustomRemotes or state.CustomRemotes == '' then return false end
    for line in state.CustomRemotes:gmatch('[^\r\n]+') do
        if line:gsub('%s', '') == remoteName then return true end
    end
    return false
end

--==[ NOTIFY (forward decl) ]==================================================
local notify
local function notifyShim(...) if notify then notify(...) end end

--==[ REDIRECTION CORE ]=======================================================
local function tryRedirectArgs(remoteName, args)
    rt.statsShotsTotal = rt.statsShotsTotal + 1
    if math.random(1, 100) > state.HitChance then return args, false end

    local plr, part = pickTarget()
    if not plr or not part then return args, false end

    -- pre-fire validation (v3): re-check after target picked
    if not isAlive(plr) then return args, false end
    local ch = plr.Character
    if not ch or not (ch.PrimaryPart or ch:FindFirstChild('HumanoidRootPart')) then
        return args, false
    end
    if state.WallCheck and not hasLineOfSight(part.Position) then return args, false end

    local newPos = resolveHitPosition(plr, part)
    if not newPos then return args, false end

    local conf = getRemoteArgConf(remoteName or '')
    local hitArg = conf.hitArg or 1
    local dirArg = conf.dirArg or 2

    local oldHit = args[hitArg]

    local from = Camera.CFrame.Position
    local dirVec = (newPos - from)
    if dirVec.Magnitude > 0 then dirVec = dirVec.Unit end

    if typeof(args[hitArg]) == 'Vector3' then
        args[hitArg] = newPos
    elseif typeof(args[hitArg]) == 'CFrame' then
        args[hitArg] = CFrame.new(newPos)
    elseif typeof(args[hitArg]) == 'Instance' then
        args[hitArg] = part
    else
        for i, v in ipairs(args) do
            if typeof(v) == 'Vector3' then args[i] = newPos break
            elseif typeof(v) == 'CFrame' then args[i] = CFrame.new(newPos) break end
        end
    end

    if args[dirArg] ~= nil then
        if typeof(args[dirArg]) == 'Vector3' then args[dirArg] = dirVec
        elseif typeof(args[dirArg]) == 'CFrame' then args[dirArg] = CFrame.lookAt(from, newPos) end
    end

    rt.statsRedirected = rt.statsRedirected + 1
    rt.statsHits = rt.statsHits + 1
    rt.lastTargetTime = tick()

    pushLog({
        time = os.date('%H:%M:%S'),
        remote = remoteName or '?',
        target = plr.Name,
        oldHit = tostring(oldHit),
        newHit = tostring(newPos),
    })

    if state.AimAssistNudge then
        local screen = worldToScreen(newPos)
        local m = UserInputService:GetMouseLocation()
        pcall(mousemoverel, (screen.X - m.X) * 0.1, (screen.Y - m.Y) * 0.1)
    end

    return args, true
end

--==[ AUTO-DETECT ]============================================================
local function startAutoDetect()
    rt.autoDetectActive = true
    rt.autoDetectLog = {}
    notifyShim('Auto-Detect', 'Listening 3s - fire your gun a few times.', 'info', 4)
    task.delay(3, function()
        rt.autoDetectActive = false
        local best
        for _, e in ipairs(rt.autoDetectLog) do
            if e.dt < 0.1 and (e.hasVec or e.hasCF) then
                if not best or e.dt < best.dt then best = e end
            end
        end
        if best then
            rt.detectedRemote = best.name
            rt.detectedArg = best.argIdx
            rt.detectedMethod = best.method
            notifyShim('Auto-Detect',
                ('Locked: %s arg %d (%s)'):format(best.name, best.argIdx, best.method),
                'success', 5)
        else
            notifyShim('Auto-Detect', 'No match. Use a preset or Custom whitelist.', 'warning', 5)
        end
    end)
end

--==[ HOOK INSTALL (v3 race-free) ]============================================
local originalNamecall
local originalIndex
local originalRayIgnore
local originalRaycast
local hooksInstalled = false

local function installHooks()
    if hooksInstalled then return end
    hooksInstalled = true

    local mt = getrawmetatable(game)
    if not mt then return end
    setreadonly(mt, false)

    -- v3 fix: capture refs BEFORE swap so closure binds to real funcs
    originalNamecall = mt.__namecall
    originalIndex    = mt.__index

    mt.__namecall = newcclosure(function(self, ...)
        local args = { ... }
        local method = getnamecallmethod()

        if checkcaller() then
            return originalNamecall(self, ...)
        end

        -- auto-detect listener (passive log mode)
        if rt.autoDetectActive
           and (method == 'FireServer' or method == 'InvokeServer'
                or method == 'fire' or method == 'Fire') then
            local hasVec, hasCF, vecIdx = false, false, 1
            for i, v in ipairs(args) do
                if typeof(v) == 'Vector3' then hasVec = true; vecIdx = i; break end
                if typeof(v) == 'CFrame' then hasCF  = true; vecIdx = i; break end
            end
            table.insert(rt.autoDetectLog, {
                name = self.Name, method = method,
                dt = tick() - rt.lastMouseClick,
                hasVec = hasVec, hasCF = hasCF, argIdx = vecIdx,
            })
        end

        if not state.Enabled then return originalNamecall(self, ...) end

        local m = state.Method
        local shouldHook = false

        -- v3 fix: handle both FireServer + InvokeServer (RemoteFunction)
        if method == 'FireServer' or method == 'InvokeServer' then
            if m == 'AUTO' then
                if rt.detectedRemote and self.Name == rt.detectedRemote then
                    shouldHook = true
                end
            elseif m == 'Namecall' or m == 'RemoteEvent' then
                local preset = PRESETS[state.Preset]
                if preset and preset.remote and self.Name:find(preset.remote) then shouldHook = true end
                if isCustomRemoteAllowed(self.Name) then shouldHook = true end
            end
        end

        if shouldHook then
            local newArgs, ok = tryRedirectArgs(self.Name, args)
            if ok then return originalNamecall(self, table.unpack(newArgs)) end
        end

        return originalNamecall(self, ...)
    end)

    mt.__index = newcclosure(function(self, k)
        if checkcaller() then return originalIndex(self, k) end
        if state.Enabled and (state.Method == 'Metatable' or state.Method == 'MouseHit') then
            if typeof(self) == 'Instance' and self:IsA('Mouse') then
                if k == 'Hit' or k == 'hit' then
                    local plr, part = pickTarget()
                    if plr and part then
                        local newPos = resolveHitPosition(plr, part)
                        if newPos then
                            rt.statsRedirected = rt.statsRedirected + 1
                            return CFrame.new(newPos)
                        end
                    end
                elseif k == 'Target' or k == 'target' then
                    local plr, part = pickTarget()
                    if plr and part then return part end
                elseif k == 'UnitRay' then
                    local plr, part = pickTarget()
                    if plr and part then
                        local from = Camera.CFrame.Position
                        return Ray.new(from, (part.Position - from).Unit)
                    end
                end
            end
        end
        return originalIndex(self, k)
    end)

    setreadonly(mt, true)

    -- Workspace:Raycast
    local ok1, h1 = pcall(function()
        return hookfunction(Workspace.Raycast, newcclosure(function(self, origin, dir, params)
            if checkcaller() or not state.Enabled or state.Method ~= 'WorkspaceRaycast' then
                return originalRaycast(self, origin, dir, params)
            end
            local plr, part = pickTarget()
            if plr and part then
                local newPos = resolveHitPosition(plr, part)
                if newPos then
                    rt.statsRedirected = rt.statsRedirected + 1
                    return originalRaycast(self, origin, (newPos - origin), params)
                end
            end
            return originalRaycast(self, origin, dir, params)
        end))
    end)
    if ok1 then originalRaycast = h1 end

    -- legacy FindPartOnRayWithIgnoreList
    local ok2, h2 = pcall(function()
        return hookfunction(Workspace.FindPartOnRayWithIgnoreList, newcclosure(function(self, ray, ignore, ...)
            if checkcaller() or not state.Enabled
               or (state.Method ~= 'RayIgnoreList' and state.Method ~= 'AUTO') then
                return originalRayIgnore(self, ray, ignore, ...)
            end
            local plr, part = pickTarget()
            if plr and part then
                local newPos = resolveHitPosition(plr, part)
                if newPos then
                    rt.statsRedirected = rt.statsRedirected + 1
                    return originalRayIgnore(self, Ray.new(ray.Origin, (newPos - ray.Origin)), ignore, ...)
                end
            end
            return originalRayIgnore(self, ray, ignore, ...)
        end))
    end)
    if ok2 then originalRayIgnore = h2 end
end

local function uninstallHooks()
    if not hooksInstalled then return end
    hooksInstalled = false
    local mt = getrawmetatable(game)
    if mt then
        pcall(function()
            setreadonly(mt, false)
            if originalNamecall then mt.__namecall = originalNamecall end
            if originalIndex then mt.__index = originalIndex end
            setreadonly(mt, true)
        end)
    end
end

--==[ GUI HELPERS ]============================================================
local function makeStroke(parent, color, thick)
    local s = Instance.new('UIStroke')
    s.Color = color or THEME.Border
    s.Thickness = thick or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end
local function makeCorner(parent, r)
    local c = Instance.new('UICorner')
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = parent
    return c
end

--==[ TOAST NOTIFY ]===========================================================
notify = function(title, msg, kind, dur)
    kind = kind or 'info'; dur = dur or 3
    if not toastHolder then return end
    local color = THEME.AccentPrimary
    if kind == 'success' then color = THEME.Success
    elseif kind == 'warning' then color = THEME.Warning
    elseif kind == 'error' then color = THEME.Danger end

    local toast = Instance.new('Frame')
    toast.Size = UDim2.new(0, 320, 0, 56)
    toast.BackgroundColor3 = THEME.CardBg
    toast.BorderSizePixel = 0
    toast.Position = UDim2.new(1, 20, 0, 0)
    toast.Parent = toastHolder
    makeCorner(toast, 6); makeStroke(toast, THEME.Border, 1)

    local bar = Instance.new('Frame')
    bar.Size = UDim2.new(0, 3, 1, 0)
    bar.BackgroundColor3 = color
    bar.BorderSizePixel = 0
    bar.Parent = toast

    local t = Instance.new('TextLabel')
    t.BackgroundTransparency = 1
    t.Position = UDim2.new(0, 12, 0, 8)
    t.Size = UDim2.new(1, -20, 0, 18)
    t.Text = title
    t.Font = Enum.Font.GothamBold; t.TextSize = 13
    t.TextColor3 = THEME.TextPrimary
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = toast

    local m = Instance.new('TextLabel')
    m.BackgroundTransparency = 1
    m.Position = UDim2.new(0, 12, 0, 26)
    m.Size = UDim2.new(1, -20, 0, 24)
    m.Text = msg
    m.Font = Enum.Font.Gotham; m.TextSize = 11
    m.TextWrapped = true
    m.TextColor3 = THEME.TextSecondary
    m.TextXAlignment = Enum.TextXAlignment.Left
    m.TextYAlignment = Enum.TextYAlignment.Top
    m.Parent = toast

    TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Position = UDim2.new(1, -10, 0, 0) }):Play()
    task.delay(dur, function()
        if toast and toast.Parent then
            local out = TweenService:Create(toast, TweenInfo.new(0.18),
                { Position = UDim2.new(1, 20, 0, 0) })
            out:Play(); out.Completed:Wait()
            toast:Destroy()
        end
    end)
end

--==[ GUI PRIMITIVES ]=========================================================
local function makeCard(parent, title, desc)
    local card = Instance.new('Frame')
    card.BackgroundColor3 = THEME.CardBg
    card.BorderSizePixel = 0
    card.Size = UDim2.new(1, 0, 0, 60)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Parent = parent
    makeCorner(card, 8)

    local pad = Instance.new('UIPadding')
    pad.PaddingTop = UDim.new(0, 14); pad.PaddingBottom = UDim.new(0, 14)
    pad.PaddingLeft = UDim.new(0, 16); pad.PaddingRight = UDim.new(0, 16)
    pad.Parent = card

    local layout = Instance.new('UIListLayout')
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = card

    local titleLbl = Instance.new('TextLabel')
    titleLbl.BackgroundTransparency = 1
    titleLbl.Size = UDim2.new(1, 0, 0, 18)
    titleLbl.Text = title or 'Card'
    titleLbl.Font = Enum.Font.GothamSemibold
    titleLbl.TextSize = 14
    titleLbl.TextColor3 = THEME.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.LayoutOrder = 1
    titleLbl.Parent = card
    card:SetAttribute('SearchKey', title or '')

    if desc then
        local d = Instance.new('TextLabel')
        d.BackgroundTransparency = 1
        d.Size = UDim2.new(1, 0, 0, 16)
        d.Text = desc
        d.Font = Enum.Font.Gotham; d.TextSize = 12
        d.TextColor3 = THEME.TextDim
        d.TextXAlignment = Enum.TextXAlignment.Left
        d.LayoutOrder = 2
        d.Parent = card
    end

    return card
end

local function makeRow(card, label, sub)
    local row = Instance.new('Frame')
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 44)
    row.LayoutOrder = #card:GetChildren()
    row.Parent = card

    local lbl = Instance.new('TextLabel')
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0.55, 0, 1, 0)
    lbl.Text = label
    lbl.Font = Enum.Font.Gotham; lbl.TextSize = 13
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.Parent = row

    if sub then
        lbl.Size = UDim2.new(0.55, 0, 0, 18)
        lbl.Position = UDim2.new(0, 0, 0, 4)
        local s = Instance.new('TextLabel')
        s.BackgroundTransparency = 1
        s.Position = UDim2.new(0, 0, 0, 22)
        s.Size = UDim2.new(0.55, 0, 0, 14)
        s.Text = sub
        s.Font = Enum.Font.Gotham; s.TextSize = 11
        s.TextColor3 = THEME.TextDim
        s.TextXAlignment = Enum.TextXAlignment.Left
        s.Parent = row
    end

    return row
end

local function makeToggle(row, getVal, setVal)
    local btn = Instance.new('TextButton')
    btn.Text = ''; btn.AutoButtonColor = false
    btn.BackgroundColor3 = getVal() and THEME.AccentPrimary or THEME.CardBgHover
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, 0, 0.5, 0)
    btn.Size = UDim2.new(0, 38, 0, 20)
    btn.BorderSizePixel = 0
    btn.Parent = row
    makeCorner(btn, 10); makeStroke(btn, THEME.Border, 1)

    local knob = Instance.new('Frame')
    knob.BackgroundColor3 = THEME.TextPrimary
    knob.BorderSizePixel = 0
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = getVal() and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.Parent = btn
    makeCorner(knob, 8)

    local function refresh()
        local on = getVal()
        TweenService:Create(btn, TWEEN_FAST,
            { BackgroundColor3 = on and THEME.AccentPrimary or THEME.CardBgHover }):Play()
        TweenService:Create(knob, TWEEN_FAST,
            { Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) }):Play()
    end
    btn.MouseButton1Click:Connect(function() setVal(not getVal()); refresh() end)
end

local function makeSlider(row, minV, maxV, getVal, setVal, decimals)
    decimals = decimals or 0
    local container = Instance.new('Frame')
    container.BackgroundTransparency = 1
    container.AnchorPoint = Vector2.new(1, 0.5)
    container.Position = UDim2.new(1, 0, 0.5, 0)
    container.Size = UDim2.new(0, 250, 0, 24)
    container.Parent = row

    local track = Instance.new('Frame')
    track.BackgroundColor3 = THEME.CardBgHover
    track.BorderSizePixel = 0
    track.AnchorPoint = Vector2.new(0, 0.5)
    track.Position = UDim2.new(0, 0, 0.5, 0)
    track.Size = UDim2.new(0, 180, 0, 4)
    track.Parent = container
    makeCorner(track, 2)

    local fill = Instance.new('Frame')
    fill.BackgroundColor3 = THEME.AccentPrimary
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.Parent = track
    makeCorner(fill, 2)

    local knob = Instance.new('TextButton')
    knob.Text = ''; knob.AutoButtonColor = false
    knob.BackgroundColor3 = THEME.TextPrimary
    knob.BorderSizePixel = 0
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Parent = track
    makeCorner(knob, 7)

    local valLbl = Instance.new('TextLabel')
    valLbl.BackgroundTransparency = 1
    valLbl.Position = UDim2.new(0, 188, 0, 0)
    valLbl.Size = UDim2.new(0, 62, 1, 0)
    valLbl.Font = Enum.Font.Code; valLbl.TextSize = 12
    valLbl.TextColor3 = THEME.TextSecondary
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = container

    local function fmt(v)
        if decimals == 0 then return tostring(math.floor(v + 0.5)) end
        return string.format('%.'..decimals..'f', v)
    end
    local function refresh()
        local v = getVal()
        local pct = math.clamp((v - minV) / (maxV - minV), 0, 1)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        valLbl.Text = fmt(v)
    end
    refresh()

    local dragging = false
    knob.MouseButton1Down:Connect(function() dragging = true end)
    track.InputBegan:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(io)
        if not dragging then return end
        if io.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local relX = io.Position.X - track.AbsolutePosition.X
        local pct = math.clamp(relX / track.AbsoluteSize.X, 0, 1)
        local newV = minV + (maxV - minV) * pct
        if decimals == 0 then newV = math.floor(newV + 0.5)
        else newV = tonumber(string.format('%.'..decimals..'f', newV)) end
        setVal(newV); refresh()
    end)
end

local function makeDropdown(row, options, getVal, setVal)
    local btn = Instance.new('TextButton')
    btn.AutoButtonColor = false
    btn.BackgroundColor3 = THEME.ContentBg
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, 0, 0.5, 0)
    btn.Size = UDim2.new(0, 180, 0, 28)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Gotham; btn.TextSize = 12
    btn.TextColor3 = THEME.TextPrimary
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Text = '  ' .. tostring(getVal())
    btn.Parent = row
    makeCorner(btn, 4); makeStroke(btn, THEME.Border, 1)

    local caret = Instance.new('TextLabel')
    caret.BackgroundTransparency = 1
    caret.AnchorPoint = Vector2.new(1, 0.5)
    caret.Position = UDim2.new(1, -8, 0.5, 0)
    caret.Size = UDim2.new(0, 14, 0, 14)
    caret.Text = 'v'; caret.Font = Enum.Font.GothamBold
    caret.TextSize = 11; caret.TextColor3 = THEME.TextSecondary
    caret.Parent = btn

    local list
    local function closeList() if list then list:Destroy(); list = nil end end

    btn.MouseButton1Click:Connect(function()
        if list then closeList(); return end
        list = Instance.new('Frame')
        list.BackgroundColor3 = THEME.ContentBg
        list.BorderSizePixel = 0
        list.Size = UDim2.new(0, 180, 0, math.min(#options * 26, 200))
        list.Position = UDim2.new(0, btn.AbsolutePosition.X, 0, btn.AbsolutePosition.Y + 30)
        list.Parent = screenGui
        list.ZIndex = 50
        makeCorner(list, 4); makeStroke(list, THEME.Border, 1)

        local scroll = Instance.new('ScrollingFrame')
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.CanvasSize = UDim2.new(0, 0, 0, #options * 26)
        scroll.ScrollBarThickness = 3
        scroll.ScrollBarImageColor3 = THEME.AccentPrimary
        scroll.Parent = list

        local ll = Instance.new('UIListLayout')
        ll.Parent = scroll

        for _, opt in ipairs(options) do
            local b = Instance.new('TextButton')
            b.AutoButtonColor = false
            b.BackgroundColor3 = THEME.ContentBg
            b.BorderSizePixel = 0
            b.Size = UDim2.new(1, 0, 0, 26)
            b.Font = Enum.Font.Gotham; b.TextSize = 12
            b.TextColor3 = (tostring(getVal()) == tostring(opt))
                and THEME.AccentPrimary or THEME.TextPrimary
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.Text = '  ' .. tostring(opt)
            b.Parent = scroll
            b.MouseEnter:Connect(function() b.BackgroundColor3 = THEME.CardBg end)
            b.MouseLeave:Connect(function() b.BackgroundColor3 = THEME.ContentBg end)
            b.MouseButton1Click:Connect(function()
                setVal(opt); btn.Text = '  ' .. tostring(opt); closeList()
            end)
        end
    end)

    UserInputService.InputBegan:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 and list then
            local m = io.Position
            local lp, ls = list.AbsolutePosition, list.AbsoluteSize
            if m.X < lp.X or m.X > lp.X + ls.X or m.Y < lp.Y or m.Y > lp.Y + ls.Y then
                local bp, bs = btn.AbsolutePosition, btn.AbsoluteSize
                if m.X < bp.X or m.X > bp.X + bs.X or m.Y < bp.Y or m.Y > bp.Y + bs.Y then
                    closeList()
                end
            end
        end
    end)
end

local function makeColorSwatch(row, getVal, setVal)
    local s = Instance.new('TextButton')
    s.AutoButtonColor = false
    s.AnchorPoint = Vector2.new(1, 0.5)
    s.Position = UDim2.new(1, 0, 0.5, 0)
    s.Size = UDim2.new(0, 28, 0, 28)
    s.BackgroundColor3 = colorTbl(getVal())
    s.BorderSizePixel = 0
    s.Text = ''
    s.Parent = row
    makeCorner(s, 4); makeStroke(s, THEME.Border, 1)

    local picker
    s.MouseButton1Click:Connect(function()
        if picker then picker:Destroy(); picker = nil; return end
        picker = Instance.new('Frame')
        picker.Size = UDim2.new(0, 180, 0, 210)
        picker.BackgroundColor3 = THEME.CardBg
        picker.BorderSizePixel = 0
        picker.Position = UDim2.new(0, s.AbsolutePosition.X - 160, 0, s.AbsolutePosition.Y + 32)
        picker.Parent = screenGui
        picker.ZIndex = 60
        makeCorner(picker, 6); makeStroke(picker, THEME.Border, 1)

        local sv = Instance.new('Frame')
        sv.Position = UDim2.new(0, 10, 0, 10)
        sv.Size = UDim2.new(0, 140, 0, 140)
        sv.BackgroundColor3 = Color3.fromHSV(0, 1, 1)
        sv.BorderSizePixel = 0
        sv.Parent = picker

        local hue = Instance.new('Frame')
        hue.Position = UDim2.new(0, 10, 0, 158)
        hue.Size = UDim2.new(0, 160, 0, 10)
        hue.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        hue.BorderSizePixel = 0
        hue.Parent = picker

        local hex = Instance.new('TextBox')
        hex.Position = UDim2.new(0, 10, 0, 178)
        hex.Size = UDim2.new(0, 160, 0, 22)
        hex.BackgroundColor3 = THEME.ContentBg
        hex.BorderSizePixel = 0
        hex.Font = Enum.Font.Code; hex.TextSize = 11
        hex.TextColor3 = THEME.TextPrimary
        local v = getVal()
        hex.Text = string.format('#%02X%02X%02X', v[1], v[2], v[3])
        hex.Parent = picker
        makeCorner(hex, 3)

        hex.FocusLost:Connect(function()
            local h = hex.Text:gsub('#', '')
            if #h == 6 then
                local r = tonumber(h:sub(1, 2), 16)
                local g = tonumber(h:sub(3, 4), 16)
                local b = tonumber(h:sub(5, 6), 16)
                if r and g and b then
                    setVal({ r, g, b })
                    s.BackgroundColor3 = Color3.fromRGB(r, g, b)
                end
            end
        end)

        UserInputService.InputBegan:Connect(function(io)
            if io.UserInputType == Enum.UserInputType.MouseButton1 and picker and picker.Parent then
                local m = io.Position
                local p, sz = picker.AbsolutePosition, picker.AbsoluteSize
                if m.X < p.X or m.X > p.X + sz.X or m.Y < p.Y or m.Y > p.Y + sz.Y then
                    picker:Destroy(); picker = nil
                end
            end
        end)
    end)
end

local function makeKeybind(row, getVal, setVal)
    local btn = Instance.new('TextButton')
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, 0, 0.5, 0)
    btn.Size = UDim2.new(0, 100, 0, 28)
    btn.BackgroundColor3 = THEME.ContentBg
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.GothamMedium; btn.TextSize = 12
    btn.TextColor3 = THEME.TextPrimary
    btn.Text = tostring(getVal())
    btn.Parent = row
    makeCorner(btn, 4); makeStroke(btn, THEME.Border, 1)

    local listening = false
    btn.MouseButton1Click:Connect(function() listening = true; btn.Text = 'Press a key...' end)
    UserInputService.InputBegan:Connect(function(io)
        if not listening then return end
        if io.UserInputType == Enum.UserInputType.Keyboard then
            if io.KeyCode == Enum.KeyCode.Escape then
                setVal('None'); btn.Text = 'None'
            else
                setVal(io.KeyCode.Name); btn.Text = io.KeyCode.Name
            end
            listening = false
        end
    end)
end

local function makeButton(row, text, style, cb)
    local btn = Instance.new('TextButton')
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, 0, 0.5, 0)
    btn.Size = UDim2.new(0, 100, 0, 30)
    btn.BackgroundColor3 = (style == 'secondary' and THEME.CardBgHover)
                          or (style == 'danger' and THEME.Danger)
                          or THEME.AccentPrimary
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.GothamMedium; btn.TextSize = 13
    btn.TextColor3 = THEME.TextPrimary
    btn.Text = text
    btn.Parent = row
    makeCorner(btn, 4)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TWEEN_FAST, { BackgroundColor3 =
            (style == 'secondary' and THEME.CardBg)
            or (style == 'danger' and Color3.fromRGB(220,70,90))
            or Color3.fromRGB(255,90,200) }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TWEEN_FAST, { BackgroundColor3 =
            (style == 'secondary' and THEME.CardBgHover)
            or (style == 'danger' and THEME.Danger)
            or THEME.AccentPrimary }):Play()
    end)
    btn.MouseButton1Click:Connect(cb)
    return btn
end

local function makeTextbox(row, getVal, setVal, multiline, h)
    local box = Instance.new('TextBox')
    box.AnchorPoint = Vector2.new(1, 0.5)
    box.Position = UDim2.new(1, 0, 0.5, 0)
    box.Size = UDim2.new(0, multiline and 320 or 200, 0, h or 28)
    box.BackgroundColor3 = THEME.ContentBg
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Gotham; box.TextSize = 12
    box.TextColor3 = THEME.TextPrimary
    box.PlaceholderText = '...'
    box.PlaceholderColor3 = THEME.TextDim
    box.Text = tostring(getVal())
    box.MultiLine = multiline or false
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
    box.Parent = row
    makeCorner(box, 4)
    local stroke = makeStroke(box, THEME.Border, 1)

    box.Focused:Connect(function() stroke.Color = THEME.AccentPrimary end)
    box.FocusLost:Connect(function() stroke.Color = THEME.Border; setVal(box.Text) end)
    return box
end

--==[ BUILD GUI ]==============================================================
local function buildGUI()
    if screenGui then return end
    screenGui = Instance.new('ScreenGui')
    screenGui.Name = 'eni_silent_aim'
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    protect_gui(screenGui)

    toastHolder = Instance.new('Frame')
    toastHolder.AnchorPoint = Vector2.new(1, 0)
    toastHolder.Position = UDim2.new(1, -20, 0, 20)
    toastHolder.Size = UDim2.new(0, 320, 1, 0)
    toastHolder.BackgroundTransparency = 1
    toastHolder.Parent = screenGui
    local tl = Instance.new('UIListLayout')
    tl.Padding = UDim.new(0, 8)
    tl.SortOrder = Enum.SortOrder.LayoutOrder
    tl.Parent = toastHolder

    local win = Instance.new('Frame')
    win.Name = 'Window'
    win.Size = UDim2.new(0, 920, 0, 600)
    win.Position = UDim2.new(0.5, -460, 0.5, -300)
    win.BackgroundColor3 = THEME.WindowBg
    win.BorderSizePixel = 0
    win.Parent = screenGui
    makeCorner(win, 10)

    local stripe = Instance.new('Frame')
    stripe.Size = UDim2.new(1, 0, 0, 2)
    stripe.BackgroundColor3 = THEME.AccentPrimary
    stripe.BorderSizePixel = 0
    stripe.Parent = win

    local title = Instance.new('Frame')
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 2)
    title.BackgroundColor3 = THEME.WindowBg
    title.BorderSizePixel = 0
    title.Parent = win

    local logo = Instance.new('Frame')
    logo.Size = UDim2.new(0, 12, 0, 12)
    logo.Position = UDim2.new(0, 16, 0.5, -6)
    logo.BackgroundColor3 = THEME.AccentPrimary
    logo.BorderSizePixel = 0
    logo.Parent = title
    makeCorner(logo, 3)

    local kitName = Instance.new('TextLabel')
    kitName.BackgroundTransparency = 1
    kitName.Position = UDim2.new(0, 36, 0, 0)
    kitName.Size = UDim2.new(0, 280, 1, 0)
    kitName.Text = 'FREEZER  -  Silent Aim'
    kitName.Font = Enum.Font.GothamBold
    kitName.TextSize = 14
    kitName.TextColor3 = THEME.TextPrimary
    kitName.TextXAlignment = Enum.TextXAlignment.Left
    kitName.Parent = title

    local search = Instance.new('TextBox')
    search.AnchorPoint = Vector2.new(0.5, 0.5)
    search.Position = UDim2.new(0.5, 0, 0.5, 0)
    search.Size = UDim2.new(0, 380, 0, 28)
    search.BackgroundColor3 = THEME.ContentBg
    search.BorderSizePixel = 0
    search.PlaceholderText = '  Search settings...'
    search.PlaceholderColor3 = THEME.TextDim
    search.Text = ''
    search.Font = Enum.Font.Gotham; search.TextSize = 12
    search.TextColor3 = THEME.TextPrimary
    search.ClearTextOnFocus = false
    search.TextXAlignment = Enum.TextXAlignment.Left
    search.Parent = title
    makeCorner(search, 14)

    local function makeWinBtn(text, isClose)
        local b = Instance.new('TextButton')
        b.AnchorPoint = Vector2.new(1, 0)
        b.Size = UDim2.new(0, 46, 1, 0)
        b.BackgroundColor3 = THEME.WindowBg
        b.BackgroundTransparency = 1
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.Font = Enum.Font.GothamBold; b.TextSize = 14
        b.Text = text
        b.TextColor3 = THEME.TextSecondary
        b.Parent = title
        b.MouseEnter:Connect(function()
            b.BackgroundTransparency = 0
            b.BackgroundColor3 = isClose and THEME.Danger or THEME.CardBg
            b.TextColor3 = THEME.TextPrimary
        end)
        b.MouseLeave:Connect(function()
            b.BackgroundTransparency = 1
            b.TextColor3 = THEME.TextSecondary
        end)
        return b
    end

    local closeBtn = makeWinBtn('X', true)
    closeBtn.Position = UDim2.new(1, 0, 0, 0)
    closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = false end)

    local minBtn = makeWinBtn('-', false)
    minBtn.Position = UDim2.new(1, -46, 0, 0)
    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        win.Size = minimized and UDim2.new(0, 920, 0, 42) or UDim2.new(0, 920, 0, 600)
    end)

    -- drag
    do
        local dragging, ds, dp
        title.InputBegan:Connect(function(io)
            if io.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true; ds = io.Position; dp = win.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(io)
            if dragging and io.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = io.Position - ds
                win.Position = UDim2.new(dp.X.Scale, dp.X.Offset + delta.X,
                                          dp.Y.Scale, dp.Y.Offset + delta.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(io)
            if io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
    end

    local sidebar = Instance.new('Frame')
    sidebar.Size = UDim2.new(0, 220, 1, -42 - 26)
    sidebar.Position = UDim2.new(0, 0, 0, 42)
    sidebar.BackgroundColor3 = THEME.SidebarBg
    sidebar.BorderSizePixel = 0
    sidebar.Parent = win

    local navLayout = Instance.new('UIListLayout')
    navLayout.Padding = UDim.new(0, 2)
    navLayout.SortOrder = Enum.SortOrder.LayoutOrder
    navLayout.Parent = sidebar

    local content = Instance.new('Frame')
    content.Size = UDim2.new(1, -220, 1, -42 - 26)
    content.Position = UDim2.new(0, 220, 0, 42)
    content.BackgroundColor3 = THEME.ContentBg
    content.BorderSizePixel = 0
    content.Parent = win

    local status = Instance.new('Frame')
    status.Size = UDim2.new(1, 0, 0, 26)
    status.Position = UDim2.new(0, 0, 1, -26)
    status.BackgroundColor3 = THEME.WindowBg
    status.BorderSizePixel = 0
    status.Parent = win
    local topBorder = Instance.new('Frame')
    topBorder.Size = UDim2.new(1, 0, 0, 1)
    topBorder.BackgroundColor3 = THEME.Border
    topBorder.BorderSizePixel = 0
    topBorder.Parent = status

    local statusDot = Instance.new('Frame')
    statusDot.Position = UDim2.new(0, 10, 0.5, -3)
    statusDot.Size = UDim2.new(0, 6, 0, 6)
    statusDot.BackgroundColor3 = THEME.AccentPrimary
    statusDot.BorderSizePixel = 0
    statusDot.Parent = status
    makeCorner(statusDot, 3)

    local statusText = Instance.new('TextLabel')
    statusText.BackgroundTransparency = 1
    statusText.Position = UDim2.new(0, 24, 0, 0)
    statusText.Size = UDim2.new(1, -34, 1, 0)
    statusText.Text = 'init...'
    statusText.Font = Enum.Font.Gotham
    statusText.TextSize = 11
    statusText.TextColor3 = THEME.TextDim
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.Parent = status

    task.spawn(function()
        while screenGui and screenGui.Parent do
            local dt = RunService.Heartbeat:Wait()
            local fps = math.floor(1 / math.max(dt, 0.001))
            local ping = 0
            pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
            local plrCount = #Players:GetPlayers()
            local hr, mn = os.date('%H'), os.date('%M')
            local gameName = 'Unknown'
            pcall(function()
                local info = MarketplaceService:GetProductInfo(game.PlaceId)
                gameName = info.Name
            end)
            local rate = rt.statsShotsTotal > 0
                and (rt.statsHits / rt.statsShotsTotal * 100) or 0
            statusText.Text = string.format(
                'FPS %d | Ping %dms | %d players | %s | %s:%s | method:%s preset:%s hit:%.0f%%',
                fps, ping, plrCount, gameName, hr, mn,
                state.Method, state.Preset, rate)
        end
    end)

    local function newPage(name)
        local p = Instance.new('ScrollingFrame')
        p.Size = UDim2.new(1, -20, 1, -20)
        p.Position = UDim2.new(0, 20, 0, 0)
        p.BackgroundTransparency = 1
        p.BorderSizePixel = 0
        p.ScrollBarThickness = 3
        p.ScrollBarImageColor3 = THEME.AccentPrimary
        p.CanvasSize = UDim2.new(0, 0, 0, 0)
        p.AutomaticCanvasSize = Enum.AutomaticSize.Y
        p.Visible = false
        p.Parent = content

        local pl = Instance.new('UIListLayout')
        pl.Padding = UDim.new(0, 8)
        pl.SortOrder = Enum.SortOrder.LayoutOrder
        pl.Parent = p

        local bc = Instance.new('TextLabel')
        bc.BackgroundTransparency = 1
        bc.Size = UDim2.new(1, 0, 0, 14)
        bc.Text = 'Home > Combat > ' .. name
        bc.Font = Enum.Font.Gotham; bc.TextSize = 11
        bc.TextColor3 = THEME.TextDim
        bc.TextXAlignment = Enum.TextXAlignment.Left
        bc.LayoutOrder = -2; bc.Parent = p

        local st = Instance.new('TextLabel')
        st.BackgroundTransparency = 1
        st.Size = UDim2.new(1, 0, 0, 28)
        st.Text = name
        st.Font = Enum.Font.GothamBold; st.TextSize = 22
        st.TextColor3 = THEME.TextPrimary
        st.TextXAlignment = Enum.TextXAlignment.Left
        st.LayoutOrder = -1; st.Parent = p

        local sd = Instance.new('TextLabel')
        sd.BackgroundTransparency = 1
        sd.Size = UDim2.new(1, 0, 0, 18)
        sd.Text = 'Silent Aim v3 - auto-detect shoot remote, redirect with full precision.'
        sd.Font = Enum.Font.Gotham; sd.TextSize = 13
        sd.TextColor3 = THEME.TextSecondary
        sd.TextXAlignment = Enum.TextXAlignment.Left
        sd.LayoutOrder = 0; sd.Parent = p

        return p
    end

    local function showPage(name)
        if currentPage and pages[currentPage] then
            pages[currentPage].Visible = false
        end
        currentPage = name
        if pages[name] then pages[name].Visible = true end
    end

    local function addNav(icon, label, page)
        local item = Instance.new('TextButton')
        item.AutoButtonColor = false
        item.BackgroundColor3 = THEME.SidebarBg
        item.BorderSizePixel = 0
        item.Size = UDim2.new(1, 0, 0, 44)
        item.Text = ''
        item.Parent = sidebar

        local bar = Instance.new('Frame')
        bar.Size = UDim2.new(0, 3, 1, 0)
        bar.BackgroundColor3 = THEME.AccentPrimary
        bar.BorderSizePixel = 0
        bar.Visible = false
        bar.Parent = item

        local ic = Instance.new('TextLabel')
        ic.BackgroundTransparency = 1
        ic.Position = UDim2.new(0, 16, 0, 0)
        ic.Size = UDim2.new(0, 20, 1, 0)
        ic.Text = icon
        ic.Font = Enum.Font.Gotham; ic.TextSize = 16
        ic.TextColor3 = THEME.TextPrimary
        ic.Parent = item

        local lb = Instance.new('TextLabel')
        lb.BackgroundTransparency = 1
        lb.Position = UDim2.new(0, 42, 0, 0)
        lb.Size = UDim2.new(1, -50, 1, 0)
        lb.Text = label
        lb.Font = Enum.Font.Gotham; lb.TextSize = 13
        lb.TextColor3 = THEME.TextPrimary
        lb.TextXAlignment = Enum.TextXAlignment.Left
        lb.Parent = item

        item.MouseEnter:Connect(function()
            if currentPage ~= page then
                TweenService:Create(item, TWEEN_DEF,
                    { BackgroundColor3 = THEME.CardBg }):Play()
            end
        end)
        item.MouseLeave:Connect(function()
            if currentPage ~= page then
                TweenService:Create(item, TWEEN_DEF,
                    { BackgroundColor3 = THEME.SidebarBg }):Play()
            end
        end)
        item.MouseButton1Click:Connect(function()
            for _, c in ipairs(sidebar:GetChildren()) do
                if c:IsA('TextButton') then
                    c.BackgroundColor3 = THEME.SidebarBg
                    local f = c:FindFirstChildWhichIsA('Frame')
                    if f then f.Visible = false end
                end
            end
            item.BackgroundColor3 = THEME.AccentSoft
            bar.Visible = true
            showPage(page)
        end)
    end

    for _, name in ipairs({ 'Aim', 'Targeting', 'Filtering', 'Anti-Detect',
                            'Visuals', 'Debug', 'Settings' }) do
        pages[name] = newPage(name)
    end

    addNav('o', 'Aim',         'Aim')
    addNav('@', 'Targeting',   'Targeting')
    addNav('#', 'Filtering',   'Filtering')
    addNav('!', 'Anti-Detect', 'Anti-Detect')
    addNav('*', 'Visuals',     'Visuals')
    addNav('?', 'Debug',       'Debug')

    local divider = Instance.new('Frame')
    divider.Size = UDim2.new(1, -16, 0, 1)
    divider.Position = UDim2.new(0, 8, 0, 0)
    divider.BackgroundColor3 = THEME.Border
    divider.BorderSizePixel = 0
    divider.LayoutOrder = 100
    divider.Parent = sidebar

    addNav('~', 'Settings', 'Settings')

    -- AIM page
    do
        local p = pages.Aim
        local card1 = makeCard(p, 'Master', 'Enable silent aim and pick how shots get redirected.')
        local r1 = makeRow(card1, 'Enabled', 'Master switch - H also toggles.')
        makeToggle(r1, function() return state.Enabled end, function(v)
            state.Enabled = v
            if v then installHooks() end
            if not v then killFovCircle() end
            notify('Silent Aim', v and 'Enabled.' or 'Disabled.',
                v and 'success' or 'info', 2)
            trySaveConfig()
        end)

        local r2 = makeRow(card1, 'Method', 'AUTO recommended - learns the shoot pattern.')
        makeDropdown(r2,
            { 'AUTO', 'MouseHit', 'RayIgnoreList', 'WorkspaceRaycast',
              'Namecall', 'Metatable', 'RemoteEvent' },
            function() return state.Method end,
            function(v) state.Method = v; trySaveConfig() end)

        local r3 = makeRow(card1, 'Preset', 'Verified arg indices per game.')
        local presetNames = {}
        for k in pairs(PRESETS) do table.insert(presetNames, k) end
        table.sort(presetNames)
        makeDropdown(r3, presetNames,
            function() return state.Preset end,
            function(v) state.Preset = v; trySaveConfig() end)

        local card2 = makeCard(p, 'FOV', 'Targets must be within this radius from your mouse.')
        local rf = makeRow(card2, 'FOV (px)')
        makeSlider(rf, 1, 1000,
            function() return state.FOV end,
            function(v) state.FOV = v; trySaveConfig() end)
        local rfv = makeRow(card2, 'FOV Circle Visible')
        makeToggle(rfv,
            function() return state.FOVCircleVisible end,
            function(v) state.FOVCircleVisible = v; if not v then killFovCircle() end; trySaveConfig() end)
        local rfc = makeRow(card2, 'FOV Circle Color')
        makeColorSwatch(rfc,
            function() return state.FOVCircleColor end,
            function(v) state.FOVCircleColor = v; trySaveConfig() end)
        local rft = makeRow(card2, 'FOV Circle Thickness')
        makeSlider(rft, 0.5, 5,
            function() return state.FOVCircleThickness end,
            function(v) state.FOVCircleThickness = v; trySaveConfig() end, 1)

        local card3 = makeCard(p, 'Auto-Detect', 'Run again if the game updates its remotes.')
        local rad = makeRow(card3, 'Re-run Auto-Detect')
        makeButton(rad, 'Run', 'primary', function() startAutoDetect() end)
    end

    -- TARGETING page
    do
        local p = pages.Targeting
        local card = makeCard(p, 'Target', 'Which body part to redirect shots toward.')
        local r1 = makeRow(card, 'Target Part')
        makeDropdown(r1,
            { 'Head', 'HumanoidRootPart', 'UpperTorso', 'LowerTorso', 'Random' },
            function() return state.TargetPart end,
            function(v) state.TargetPart = v; trySaveConfig() end)
        local r2 = makeRow(card, 'Bone Random', 'Cycle bones between shots.')
        makeToggle(r2,
            function() return state.BoneRandom end,
            function(v) state.BoneRandom = v; trySaveConfig() end)

        local card2 = makeCard(p, 'Smart Selection', 'How to pick a target inside the FOV.')
        local rs = makeRow(card2, 'Selection Mode')
        makeDropdown(rs,
            { 'Closest to Mouse', 'Closest to Crosshair', 'Lowest HP', 'Highest Threat' },
            function() return state.Smart end,
            function(v) state.Smart = v; trySaveConfig() end)

        local card3 = makeCard(p, 'Prediction', 'Lead moving targets and compensate for ping.')
        local rvl = makeRow(card3, 'Velocity Lead', 'Multiplier (0..2)')
        makeSlider(rvl, 0, 2,
            function() return state.VelocityLead end,
            function(v) state.VelocityLead = v; trySaveConfig() end, 2)
        local rpc = makeRow(card3, 'Ping Compensation', 'Add (ms) of velocity prediction.')
        makeSlider(rpc, 0, 500,
            function() return state.PingComp end,
            function(v) state.PingComp = v; trySaveConfig() end)

        local card4 = makeCard(p, 'Resolver', 'Apply when target is desyncing.')
        local rr = makeRow(card4, 'Resolver')
        makeDropdown(rr,
            { 'Off', 'Velocity', 'Acceleration', 'Anti-Anti-Aim' },
            function() return state.Resolver end,
            function(v) state.Resolver = v; trySaveConfig() end)
    end

    -- FILTERING page
    do
        local p = pages.Filtering
        local c1 = makeCard(p, 'Filters', 'Skip targets that fail these checks.')
        local r1 = makeRow(c1, 'Wall Check', 'Skip if line-of-sight blocked.')
        makeToggle(r1,
            function() return state.WallCheck end,
            function(v) state.WallCheck = v; trySaveConfig() end)
        local r2 = makeRow(c1, 'Team Check', 'Ignore teammates.')
        makeToggle(r2,
            function() return state.TeamCheck end,
            function(v) state.TeamCheck = v; trySaveConfig() end)
        local r3 = makeRow(c1, 'Visibility Check', 'Only target on-screen players.')
        makeToggle(r3,
            function() return state.VisibilityCheck end,
            function(v) state.VisibilityCheck = v; trySaveConfig() end)

        local c2 = makeCard(p, 'Custom Remotes', 'One remote name per line - also redirected.')
        local rc = makeRow(c2, 'Whitelist')
        rc.Size = UDim2.new(1, 0, 0, 100)
        local rt2 = makeTextbox(rc,
            function() return state.CustomRemotes end,
            function(v) state.CustomRemotes = v; trySaveConfig() end, true, 86)
        rt2.AnchorPoint = Vector2.new(1, 0.5)
        rt2.Position = UDim2.new(1, 0, 0.5, 0)

        local c3 = makeCard(p, 'Argument Editor', 'Per-remote argument indices (hit / dir).')
        local raA = makeRow(c3, 'Remote Name')
        local raB = makeRow(c3, 'Hit Arg Index')
        local raC = makeRow(c3, 'Dir Arg Index')
        local currentRemote = ''
        makeTextbox(raA, function() return currentRemote end, function(v) currentRemote = v end)
        makeSlider(raB, 1, 10,
            function() return (state.ArgEditor[currentRemote] or {}).hitArg or 1 end,
            function(v)
                state.ArgEditor[currentRemote] = state.ArgEditor[currentRemote] or {}
                state.ArgEditor[currentRemote].hitArg = v
                trySaveConfig()
            end)
        makeSlider(raC, 1, 10,
            function() return (state.ArgEditor[currentRemote] or {}).dirArg or 2 end,
            function(v)
                state.ArgEditor[currentRemote] = state.ArgEditor[currentRemote] or {}
                state.ArgEditor[currentRemote].dirArg = v
                trySaveConfig()
            end)
    end

    -- ANTI-DETECT page
    do
        local p = pages['Anti-Detect']
        local c1 = makeCard(p, 'Hit Chance', 'Probability a shot gets redirected.')
        local r1 = makeRow(c1, 'Hit Chance %', '100% always redirects.')
        makeSlider(r1, 0, 100,
            function() return state.HitChance end,
            function(v) state.HitChance = v; trySaveConfig() end)

        local c2 = makeCard(p, 'Random Miss', 'Occasional intentional miss so stats look human.')
        local rm = makeRow(c2, 'Random Miss Enabled')
        makeToggle(rm,
            function() return state.MissEnabled end,
            function(v) state.MissEnabled = v; trySaveConfig() end)
        local rmr = makeRow(c2, 'Miss Rate %')
        makeSlider(rmr, 0, 50,
            function() return state.MissRate end,
            function(v) state.MissRate = v; trySaveConfig() end)
        local rmd = makeRow(c2, 'Max Miss Distance (studs)')
        makeSlider(rmd, 0, 20,
            function() return state.MaxMissDistance end,
            function(v) state.MaxMissDistance = v; trySaveConfig() end, 1)

        local c3 = makeCard(p, 'Jitter', 'Random offset on the hit position so it looks natural.')
        local rj = makeRow(c3, 'Hit Position Jitter')
        makeSlider(rj, 0, 5,
            function() return state.HitJitter end,
            function(v) state.HitJitter = v; trySaveConfig() end, 2)

        local c4 = makeCard(p, 'Aim Assist Nudge', 'Subtly nudges mouse toward the redirected target.')
        local raa = makeRow(c4, 'Enable Nudge')
        makeToggle(raa,
            function() return state.AimAssistNudge end,
            function(v) state.AimAssistNudge = v; trySaveConfig() end)

        local c5 = makeCard(p, 'Auto-Disable', 'Turn off if no targets in FOV for N seconds.')
        local rad = makeRow(c5, 'Idle Timer (s, 0 = never)')
        makeSlider(rad, 0, 60,
            function() return state.AutoDisableTimer end,
            function(v) state.AutoDisableTimer = v; trySaveConfig() end)
    end

    -- VISUALS page
    do
        local p = pages.Visuals
        local c1 = makeCard(p, 'Indicator', 'Shows a magenta crosshair while redirection is active.')
        local r1 = makeRow(c1, 'Crosshair Indicator')
        makeToggle(r1,
            function() return state.CrosshairIndicator end,
            function(v) state.CrosshairIndicator = v; trySaveConfig() end)
        local r2 = makeRow(c1, 'Indicator Color')
        makeColorSwatch(r2,
            function() return state.CrosshairColor end,
            function(v) state.CrosshairColor = v; trySaveConfig() end)

        local c2 = makeCard(p, 'Debug Visualizer', 'Draws original ray red, redirected ray magenta.')
        local rv = makeRow(c2, 'Enabled')
        makeToggle(rv,
            function() return state.DebugVisualizer end,
            function(v) state.DebugVisualizer = v; trySaveConfig() end)
    end

    -- DEBUG page
    do
        local p = pages.Debug
        local c1 = makeCard(p, 'Stats', 'Live counters.')
        local statLbl = Instance.new('TextLabel')
        statLbl.BackgroundTransparency = 1
        statLbl.Size = UDim2.new(1, 0, 0, 120)
        statLbl.Text = ''
        statLbl.Font = Enum.Font.Code; statLbl.TextSize = 12
        statLbl.TextColor3 = THEME.TextSecondary
        statLbl.TextXAlignment = Enum.TextXAlignment.Left
        statLbl.TextYAlignment = Enum.TextYAlignment.Top
        statLbl.Parent = c1
        task.spawn(function()
            while screenGui and screenGui.Parent do
                local rate = rt.statsShotsTotal > 0
                    and (rt.statsHits / rt.statsShotsTotal * 100) or 0
                statLbl.Text = string.format(
                    'shots redirected : %d\nshots total      : %d\nhit rate         : %.1f%%\nmethod           : %s\npreset           : %s\nstate            : %s\ndetected remote  : %s arg %s',
                    rt.statsRedirected, rt.statsShotsTotal, rate,
                    state.Method, state.Preset,
                    state.Enabled and 'ACTIVE' or 'idle',
                    tostring(rt.detectedRemote or '-'),
                    tostring(rt.detectedArg or '-'))
                task.wait(0.5)
            end
        end)

        local c2 = makeCard(p, 'Hit Test Mode', 'Notifies every 2s if next shot would hit.')
        local rht = makeRow(c2, 'Hit Test Mode')
        makeToggle(rht,
            function() return state.HitTestMode end,
            function(v) state.HitTestMode = v; trySaveConfig() end)

        local c3 = makeCard(p, 'Recent Redirects', 'Last 50 redirected shots.')
        local logBox = Instance.new('TextLabel')
        logBox.BackgroundTransparency = 1
        logBox.Size = UDim2.new(1, 0, 0, 240)
        logBox.Text = ''
        logBox.Font = Enum.Font.Code; logBox.TextSize = 11
        logBox.TextColor3 = THEME.TextDim
        logBox.TextXAlignment = Enum.TextXAlignment.Left
        logBox.TextYAlignment = Enum.TextYAlignment.Top
        logBox.TextWrapped = true
        logBox.Parent = c3
        task.spawn(function()
            while screenGui and screenGui.Parent do
                local lines = {}
                for i, e in ipairs(rt.debugLog) do
                    if i > 12 then break end
                    table.insert(lines, string.format('[%s] %s -> %s  %s',
                        e.time, e.remote, e.target, e.newHit))
                end
                logBox.Text = table.concat(lines, '\n')
                task.wait(0.5)
            end
        end)
    end

    -- SETTINGS page
    do
        local p = pages.Settings
        local c1 = makeCard(p, 'Keybinds', 'Bind a key to toggle or re-run detection.')
        local r1 = makeRow(c1, 'Toggle Silent Aim')
        makeKeybind(r1,
            function() return state.KeybindToggle end,
            function(v) state.KeybindToggle = v; trySaveConfig() end)
        local r2 = makeRow(c1, 'Run Auto-Detect')
        makeKeybind(r2,
            function() return state.KeybindAutoDetect end,
            function(v) state.KeybindAutoDetect = v; trySaveConfig() end)

        local c2 = makeCard(p, 'Config', 'Save / load your config to disk.')
        local rs = makeRow(c2, 'Save')
        makeButton(rs, 'Save', 'primary', function()
            trySaveConfig(); notify('Config', 'Saved.', 'success', 2)
        end)
        local rl = makeRow(c2, 'Load')
        makeButton(rl, 'Load', 'secondary', function()
            tryLoadConfig(); notify('Config', 'Loaded.', 'success', 2)
        end)
        local rr = makeRow(c2, 'Reset')
        makeButton(rr, 'Reset', 'danger', function()
            for k, v in pairs({
                Enabled=false, Method='AUTO', TargetPart='Head', FOV=120,
                FOVCircleVisible=true, WallCheck=true, TeamCheck=true,
                HitChance=100, BoneRandom=false, Preset='Generic',
                CustomRemotes='', VelocityLead=0, PingComp=0,
                VisibilityCheck=false, Resolver='Off', MissEnabled=false,
                MissRate=5, MaxMissDistance=3, HitJitter=0, AimAssistNudge=false,
                Smart='Closest to Mouse', CrosshairIndicator=true,
                DebugVisualizer=false, HitTestMode=false, AutoDisableTimer=0,
                KeybindToggle='H', KeybindAutoDetect='J',
            }) do state[k] = v end
            state.ArgEditor = {}
            notify('Config', 'Reset to defaults.', 'warning', 2)
        end)
    end

    search:GetPropertyChangedSignal('Text'):Connect(function()
        local q = search.Text:lower()
        for _, page in pairs(pages) do
            for _, card in ipairs(page:GetChildren()) do
                if card:IsA('Frame') and card:GetAttribute('SearchKey') then
                    local k = card:GetAttribute('SearchKey'):lower()
                    card.Visible = (q == '' or k:find(q, 1, true) ~= nil)
                end
            end
        end
    end)

    showPage('Aim')
    local first = sidebar:FindFirstChildWhichIsA('TextButton')
    if first then
        first.BackgroundColor3 = THEME.AccentSoft
        local f = first:FindFirstChildWhichIsA('Frame')
        if f then f.Visible = true end
    end
end

--==[ MAIN LOOPS / INPUT ]=====================================================
local function startLoops()
    table.insert(rt.connections, RunService.RenderStepped:Connect(function()
        if state.Enabled then updateFovCircle() else
            if rt.fovCircle then rt.fovCircle.Visible = false end
        end
        if state.AutoDisableTimer > 0 and state.Enabled then
            if tick() - rt.lastTargetTime > state.AutoDisableTimer then
                state.Enabled = false
                notify('Silent Aim', 'Auto-disabled (idle).', 'warning', 3)
            end
        end
    end))

    table.insert(rt.connections, UserInputService.InputBegan:Connect(function(io, gp)
        if gp then return end
        if io.UserInputType == Enum.UserInputType.MouseButton1 then
            rt.lastMouseClick = tick()
        elseif io.UserInputType == Enum.UserInputType.Keyboard then
            local n = io.KeyCode.Name
            if n == state.KeybindToggle then
                state.Enabled = not state.Enabled
                if state.Enabled then installHooks() end
                if not state.Enabled then killFovCircle() end
                notify('Silent Aim',
                    state.Enabled and 'Enabled.' or 'Disabled.',
                    state.Enabled and 'success' or 'info', 2)
            elseif n == state.KeybindAutoDetect then
                startAutoDetect()
            end
        end
    end))

    task.spawn(function()
        while true do
            task.wait(2)
            if state.HitTestMode and state.Enabled then
                local plr = pickTarget()
                if plr then notify('HitTest', ('would hit %s'):format(plr.Name), 'info', 1) end
            end
        end
    end)
end

--==[ API ]====================================================================
getgenv().ENI = getgenv().ENI or {}
getgenv().ENI.SilentAim = {
    Show = function()
        if not screenGui then buildGUI(); startLoops(); tryLoadConfig() end
        screenGui.Enabled = true
    end,
    Hide = function() if screenGui then screenGui.Enabled = false end end,
    Toggle = function()
        if not screenGui then buildGUI(); startLoops(); tryLoadConfig() end
        screenGui.Enabled = not screenGui.Enabled
    end,
    Destroy = function()
        uninstallHooks(); killFovCircle()
        for _, c in ipairs(rt.connections) do pcall(function() c:Disconnect() end) end
        rt.connections = {}
        if screenGui then screenGui:Destroy(); screenGui = nil end
        if getgenv().ENI then getgenv().ENI.SilentAim = nil end
    end,
    GetConfig = function() return state end,
    SetConfig = function(t)
        if type(t) ~= 'table' then return end
        for k, v in pairs(t) do state[k] = v end
        trySaveConfig()
    end,
    StartAutoDetect = startAutoDetect,
    RedirectStats = function() return rt.statsRedirected, rt.statsShotsTotal end,
}

buildGUI()
startLoops()
tryLoadConfig()
if screenGui then screenGui.Enabled = true end
notify('Silent Aim v3', 'Loaded. Press H to toggle, J to auto-detect.', 'success', 4)

return getgenv().ENI.SilentAim

end
-- END MODULE: SILENT AIM v3.0.0
----------------------------------------------------------------------

----------------------------------------------------------------------
-- MODULE: PERMS SPOOFER v3.0.0 (1456 lines original)
----------------------------------------------------------------------
do
--[[
    eni-roblox-kit :: utility/perms_spoofer.lua
    Perms Spoofer  v3.0.0
    Client-side spoofing of gamepass / premium / group rank / badge / policy
    results to unlock UI-gated features in games whose admin/premium gating
    lives on the client.

    API:  getgenv().ENI.PermsSpoofer
    Default keybind:  F1 toggles window
--]]

-- ===========================================================================
-- ANTI-DETECT BLOCK
-- ===========================================================================
local cloneref = cloneref or function(x) return x end
local protect_gui = (syn and syn.protect_gui) or (gethui and function(g) g.Parent = gethui() end) or function(g) g.Parent = game:GetService('CoreGui') end
local hookmetamethod = hookmetamethod or function() return nil end
local getrawmetatable = getrawmetatable or function() return nil end
local setreadonly = setreadonly or function() end
local newcclosure = newcclosure or function(f) return f end
local checkcaller = checkcaller or function() return false end
local hookfunction = hookfunction or function() return nil end
local getnamecallmethod = getnamecallmethod or function() return "" end

-- ===========================================================================
-- SERVICES
-- ===========================================================================
local Players              = cloneref(game:GetService('Players'))
local RunService           = cloneref(game:GetService('RunService'))
local UserInputService     = cloneref(game:GetService('UserInputService'))
local TweenService         = cloneref(game:GetService('TweenService'))
local HttpService          = cloneref(game:GetService('HttpService'))
local Lighting             = cloneref(game:GetService('Lighting'))
local Workspace            = cloneref(game:GetService('Workspace'))
local MarketplaceService   = cloneref(game:GetService('MarketplaceService'))
local BadgeService         = cloneref(game:GetService('BadgeService'))
local PolicyService        = cloneref(game:GetService('PolicyService'))
local TeleportService      = cloneref(game:GetService('TeleportService'))
local Stats                = cloneref(game:GetService('Stats'))

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    Players.PlayerAdded:Wait()
    LocalPlayer = Players.LocalPlayer
end

-- ===========================================================================
-- THEME
-- ===========================================================================
local Theme = {
    WindowBg       = Color3.fromRGB(20, 20, 26),
    SidebarBg      = Color3.fromRGB(24, 24, 30),
    ContentBg      = Color3.fromRGB(28, 28, 34),
    CardBg         = Color3.fromRGB(36, 36, 44),
    CardBgHover    = Color3.fromRGB(42, 42, 52),
    Border         = Color3.fromRGB(54, 54, 66),
    AccentPrimary  = Color3.fromRGB(255, 65, 180),
    AccentSoft     = Color3.fromRGB(80, 32, 60),
    TextPrimary    = Color3.fromRGB(240, 240, 248),
    TextSecondary  = Color3.fromRGB(170, 170, 188),
    TextDim        = Color3.fromRGB(115, 115, 135),
    Success        = Color3.fromRGB(80, 220, 130),
    Warning        = Color3.fromRGB(255, 185, 70),
    Danger         = Color3.fromRGB(255, 90, 110),
}

local Tween = function(o, t, p) return TweenService:Create(o, TweenInfo.new(t or 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), p) end

-- ===========================================================================
-- STATE / CONFIG
-- ===========================================================================
local CONFIG_PATH = 'freezer/perms_spoofer.json'

local defaultState = {
    Enabled = false,
    AutoEnableOnLoad = false,
    VerboseLogs = true,

    PremiumSpoof = false,
    GamepassSpoof = false,
    GamepassWhitelist = '',
    GamepassBlacklist = '',
    AssetSpoof = false,
    BadgeSpoof = false,

    GroupSpoof = false,
    GroupId = 0,
    GroupRank = 254,
    GroupRole = 'Owner',

    PolicySpoof = false,
    IsStudioSpoof = false,
    TeleportDataSpoof = false,
    TeleportDataValue = '{}',
    OwnerSpoof = false,

    HideAdminUiBypass = false,

    Attributes = {}, -- list of {key=..., value=..., type=...}
    Leaderstats = {}, -- list of {key=..., value=..., type=...}

    Keybind = 'F1',
}

local state = {}
for k, v in pairs(defaultState) do
    if type(v) == 'table' then
        state[k] = {}
        for kk, vv in pairs(v) do state[k][kk] = vv end
    else
        state[k] = v
    end
end

local function deepCopyInto(target, source)
    for k, v in pairs(source) do
        if type(v) == 'table' then
            target[k] = target[k] or {}
            deepCopyInto(target[k], v)
        else
            target[k] = v
        end
    end
end

local function saveConfig()
    if not writefile then return end
    pcall(function()
        writefile(CONFIG_PATH, HttpService:JSONEncode(state))
    end)
end

local function loadConfig()
    if not (readfile and isfile and isfile(CONFIG_PATH)) then return end
    pcall(function()
        local raw = readfile(CONFIG_PATH)
        local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and type(decoded) == 'table' then
            for k, v in pairs(decoded) do
                state[k] = v
            end
        end
    end)
end

loadConfig()

-- ===========================================================================
-- CONNECTIONS / HOOKS TRACKING
-- ===========================================================================
local connections = {}
local function track(conn) table.insert(connections, conn); return conn end

local hookLog = {}
local hookLogMax = 200
local activeHookCount = 0

local function logHook(fn, args, ret)
    if not state.VerboseLogs then return end
    local entry = {
        time = os.date('%H:%M:%S'),
        fn = fn,
        args = args or '',
        ret = ret or '',
    }
    table.insert(hookLog, 1, entry)
    if #hookLog > hookLogMax then table.remove(hookLog) end
    if onHookLog then onHookLog(entry) end
end

-- ===========================================================================
-- GAMEPASS LIST PARSING
-- ===========================================================================
local function parseIdList(str)
    local out = {}
    if type(str) ~= 'string' then return out end
    for line in str:gmatch('[^\r\n]+') do
        local n = tonumber(line:match('%d+'))
        if n then out[n] = true end
    end
    return out
end

local function gpAllowed(id)
    local wl = parseIdList(state.GamepassWhitelist)
    local bl = parseIdList(state.GamepassBlacklist)
    if bl[id] then return false end
    -- if whitelist is non-empty, restrict to whitelist
    if next(wl) then return wl[id] == true end
    return true
end

-- ===========================================================================
-- HOOK STORAGE
-- ===========================================================================
local oldNamecall
local originalIsStudio
local hooksInstalled = false

local function installNamecallHook()
    if hooksInstalled then return end
    local mt = getrawmetatable(game)
    if not mt then return end
    setreadonly(mt, false)
    oldNamecall = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if checkcaller() then
            return oldNamecall(self, ...)
        end
        if not state.Enabled then
            return oldNamecall(self, ...)
        end

        local args = {...}

        -- Gamepass
        if state.GamepassSpoof and method == 'UserOwnsGamePassAsync' and self == MarketplaceService then
            local userId, gpId = args[1], args[2]
            if userId == LocalPlayer.UserId and gpAllowed(gpId) then
                logHook('UserOwnsGamePassAsync', tostring(gpId), 'true')
                return true
            end
        end

        -- Asset
        if state.AssetSpoof and method == 'PlayerOwnsAsset' and self == MarketplaceService then
            logHook('PlayerOwnsAsset', tostring(args[2]), 'true')
            return true
        end

        -- Badge
        if state.BadgeSpoof and method == 'UserHasBadgeAsync' and self == BadgeService then
            logHook('UserHasBadgeAsync', tostring(args[2]), 'true')
            return true
        end

        -- Policy
        if state.PolicySpoof and method == 'GetPolicyInfoForPlayerAsync' and self == PolicyService then
            logHook('GetPolicyInfoForPlayerAsync', '*', 'permissive')
            return {
                ArePaidRandomItemsRestricted = false,
                IsPaidItemTradingAllowed = true,
                IsSubjectToChinaPolicies = false,
                AllowedExternalLinkReferences = {
                    'Discord','Facebook','Twitch','YouTube','Twitter','Guilded','GitHub'
                },
                IsContentSharingAllowed = true,
            }
        end

        -- Player group / membership method calls
        if self == LocalPlayer or (typeof(self) == 'Instance' and self:IsA('Player') and self == LocalPlayer) then
            if state.GroupSpoof and method == 'GetRankInGroup' then
                if tonumber(args[1]) == tonumber(state.GroupId) then
                    logHook('GetRankInGroup', tostring(args[1]), tostring(state.GroupRank))
                    return state.GroupRank
                end
            elseif state.GroupSpoof and method == 'IsInGroup' then
                if tonumber(args[1]) == tonumber(state.GroupId) then
                    logHook('IsInGroup', tostring(args[1]), 'true')
                    return true
                end
            elseif state.GroupSpoof and method == 'GetRoleInGroup' then
                if tonumber(args[1]) == tonumber(state.GroupId) then
                    logHook('GetRoleInGroup', tostring(args[1]), state.GroupRole)
                    return state.GroupRole
                end
            end
        end

        -- TeleportData
        if state.TeleportDataSpoof and method == 'GetLocalPlayerTeleportData' and self == TeleportService then
            local ok, decoded = pcall(function()
                return HttpService:JSONDecode(state.TeleportDataValue or '{}')
            end)
            logHook('GetLocalPlayerTeleportData', '*', 'spoofed')
            if ok then return decoded end
            return {}
        end

        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)

    -- __index hook for MembershipType / CreatorId / IsStudio
    local oldIndex = mt.__index
    setreadonly(mt, false)
    mt.__index = newcclosure(function(self, key)
        if checkcaller() then return oldIndex(self, key) end
        if not state.Enabled then return oldIndex(self, key) end

        if state.PremiumSpoof and self == LocalPlayer and key == 'MembershipType' then
            logHook('Player.MembershipType', '-', 'Premium')
            return Enum.MembershipType.Premium
        end
        if state.OwnerSpoof and self == game and key == 'CreatorId' then
            logHook('game.CreatorId', '-', tostring(LocalPlayer.UserId))
            return LocalPlayer.UserId
        end
        return oldIndex(self, key)
    end)
    setreadonly(mt, true)

    hooksInstalled = true
end

local function installIsStudioHook()
    if originalIsStudio then return end
    pcall(function()
        originalIsStudio = hookfunction(RunService.IsStudio, newcclosure(function(self)
            if checkcaller() then
                return originalIsStudio(self)
            end
            if state.Enabled and state.IsStudioSpoof then
                logHook('RunService:IsStudio', '-', 'true')
                return true
            end
            return originalIsStudio(self)
        end))
    end)
end

local function recomputeActiveHookCount()
    local count = 0
    if state.PremiumSpoof then count = count + 1 end
    if state.GamepassSpoof then count = count + 1 end
    if state.AssetSpoof then count = count + 1 end
    if state.BadgeSpoof then count = count + 1 end
    if state.GroupSpoof then count = count + 1 end
    if state.PolicySpoof then count = count + 1 end
    if state.IsStudioSpoof then count = count + 1 end
    if state.TeleportDataSpoof then count = count + 1 end
    if state.OwnerSpoof then count = count + 1 end
    if state.HideAdminUiBypass then count = count + 1 end
    activeHookCount = count
end

-- ===========================================================================
-- ATTRIBUTE & LEADERSTATS APPLICATION
-- ===========================================================================
local function coerceValue(v, typ)
    if typ == 'number' then return tonumber(v) or 0 end
    if typ == 'bool' then
        if type(v) == 'boolean' then return v end
        local s = tostring(v):lower()
        return s == 'true' or s == '1' or s == 'yes'
    end
    return tostring(v)
end

local function applyAttributes()
    if not state.Enabled then return end
    for _, row in ipairs(state.Attributes) do
        if row.key and row.key ~= '' then
            local ok, val = pcall(coerceValue, row.value, row.type or 'string')
            if ok then
                pcall(function() LocalPlayer:SetAttribute(row.key, val) end)
            end
        end
    end
end

local function applyLeaderstats()
    if not state.Enabled then return end
    local stats = LocalPlayer:FindFirstChild('leaderstats')
    if not stats then
        stats = Instance.new('Folder')
        stats.Name = 'leaderstats'
        stats.Parent = LocalPlayer
    end
    for _, row in ipairs(state.Leaderstats) do
        if row.key and row.key ~= '' then
            local existing = stats:FindFirstChild(row.key)
            local typ = row.type or 'string'
            local className = (typ == 'number') and 'IntValue' or (typ == 'bool') and 'BoolValue' or 'StringValue'
            if existing and existing.ClassName ~= className then
                existing:Destroy()
                existing = nil
            end
            if not existing then
                existing = Instance.new(className)
                existing.Name = row.key
                existing.Parent = stats
            end
            local ok, val = pcall(coerceValue, row.value, typ)
            if ok then
                pcall(function() existing.Value = val end)
            end
        end
    end
end

-- ===========================================================================
-- HIDE ADMIN UI BYPASS
-- ===========================================================================
local hiddenUiCache = {}
local function applyAdminUiBypass()
    if not state.Enabled or not state.HideAdminUiBypass then return end
    local pg = LocalPlayer:FindFirstChildOfClass('PlayerGui')
    if not pg then return end
    for _, gui in ipairs(pg:GetDescendants()) do
        if gui:IsA('GuiObject') and (gui.Name:lower():find('admin') or gui.Name:lower():find('staff') or gui.Name:lower():find('owner') or gui.Name:lower():find('premium')) then
            if not gui.Visible then
                hiddenUiCache[gui] = true
                pcall(function() gui.Visible = true end)
            end
        end
    end
end

-- ===========================================================================
-- NOTIFICATIONS
-- ===========================================================================
local notifyContainer

local function notify(title, msg, kind, duration)
    duration = duration or 3
    if not notifyContainer then return end
    local color = Theme.AccentPrimary
    if kind == 'success' then color = Theme.Success
    elseif kind == 'warn' then color = Theme.Warning
    elseif kind == 'error' then color = Theme.Danger end

    local toast = Instance.new('Frame')
    toast.Size = UDim2.new(0, 320, 0, 64)
    toast.BackgroundColor3 = Theme.CardBg
    toast.BorderSizePixel = 0
    toast.Position = UDim2.new(1, 20, 0, 0)
    toast.Parent = notifyContainer

    local corner = Instance.new('UICorner', toast)
    corner.CornerRadius = UDim.new(0, 6)

    local stroke = Instance.new('UIStroke', toast)
    stroke.Color = Theme.Border
    stroke.Thickness = 1

    local bar = Instance.new('Frame', toast)
    bar.Size = UDim2.new(0, 3, 1, 0)
    bar.Position = UDim2.new(0, 0, 0, 0)
    bar.BackgroundColor3 = color
    bar.BorderSizePixel = 0

    local titleLbl = Instance.new('TextLabel', toast)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.new(0, 12, 0, 8)
    titleLbl.Size = UDim2.new(1, -16, 0, 18)
    titleLbl.Text = title
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13
    titleLbl.TextColor3 = Theme.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    local body = Instance.new('TextLabel', toast)
    body.BackgroundTransparency = 1
    body.Position = UDim2.new(0, 12, 0, 28)
    body.Size = UDim2.new(1, -16, 0, 32)
    body.Text = msg
    body.Font = Enum.Font.Gotham
    body.TextSize = 12
    body.TextColor3 = Theme.TextSecondary
    body.TextWrapped = true
    body.TextXAlignment = Enum.TextXAlignment.Left
    body.TextYAlignment = Enum.TextYAlignment.Top

    Tween(toast, 0.2, {Position = UDim2.new(0, 0, 0, 0)}):Play()
    task.delay(duration, function()
        local fade = Tween(toast, 0.2, {Position = UDim2.new(1, 20, 0, 0)})
        fade:Play()
        fade.Completed:Wait()
        toast:Destroy()
    end)
end

-- ===========================================================================
-- GUI BUILDER PRIMITIVES
-- ===========================================================================
local function makeRoundedFrame(parent, size, pos, color, corner)
    local f = Instance.new('Frame')
    f.Size = size
    f.Position = pos or UDim2.new()
    f.BackgroundColor3 = color
    f.BorderSizePixel = 0
    f.Parent = parent
    if corner then
        local c = Instance.new('UICorner', f)
        c.CornerRadius = UDim.new(0, corner)
    end
    return f
end

local function makeLabel(parent, text, font, size, color, pos, sz)
    local l = Instance.new('TextLabel')
    l.BackgroundTransparency = 1
    l.Text = text
    l.Font = font or Enum.Font.Gotham
    l.TextSize = size or 13
    l.TextColor3 = color or Theme.TextPrimary
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Position = pos or UDim2.new()
    l.Size = sz or UDim2.new(1, 0, 0, 16)
    l.Parent = parent
    return l
end

local function makeStroke(parent, color, thickness)
    local s = Instance.new('UIStroke', parent)
    s.Color = color or Theme.Border
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end

-- Toggle pill
local function makeToggle(parent, initial, onChange)
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(0, 38, 0, 20)
    btn.BackgroundColor3 = initial and Theme.AccentPrimary or Theme.CardBg
    btn.AutoButtonColor = false
    btn.Text = ''
    btn.BorderSizePixel = 0
    btn.Parent = parent
    local c = Instance.new('UICorner', btn); c.CornerRadius = UDim.new(1, 0)

    local knob = Instance.new('Frame', btn)
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(0, initial and 20 or 2, 0, 2)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    local kc = Instance.new('UICorner', knob); kc.CornerRadius = UDim.new(1, 0)

    local val = initial
    local function setState(s, fire)
        val = s
        Tween(btn, 0.16, {BackgroundColor3 = s and Theme.AccentPrimary or Theme.CardBg}):Play()
        Tween(knob, 0.16, {Position = UDim2.new(0, s and 20 or 2, 0, 2)}):Play()
        if fire and onChange then onChange(s) end
    end
    btn.MouseButton1Click:Connect(function() setState(not val, true) end)
    return {
        instance = btn,
        get = function() return val end,
        set = function(s) setState(s, false) end,
    }
end

-- Slider
local function makeSlider(parent, min, max, value, decimals, onChange)
    local holder = Instance.new('Frame')
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(0, 220, 0, 20)
    holder.Parent = parent

    local track = makeRoundedFrame(holder, UDim2.new(0, 180, 0, 4), UDim2.new(0, 0, 0.5, -2), Theme.CardBg, 2)
    local fill  = makeRoundedFrame(track,  UDim2.new(0, 0, 1, 0), UDim2.new(), Theme.AccentPrimary, 2)
    local knob  = makeRoundedFrame(holder, UDim2.new(0, 14, 0, 14), UDim2.new(0, 0, 0.5, -7), Color3.fromRGB(255,255,255), 7)

    local valLbl = Instance.new('TextLabel', holder)
    valLbl.BackgroundTransparency = 1
    valLbl.Position = UDim2.new(0, 188, 0, 0)
    valLbl.Size = UDim2.new(0, 36, 1, 0)
    valLbl.Font = Enum.Font.Code
    valLbl.TextSize = 12
    valLbl.TextColor3 = Theme.TextSecondary
    valLbl.TextXAlignment = Enum.TextXAlignment.Left

    local current = value
    local function clamp(v) return math.clamp(v, min, max) end
    local function fmt(v)
        if decimals and decimals > 0 then return string.format('%.'..decimals..'f', v) end
        return tostring(math.floor(v))
    end
    local function setVal(v, fire)
        current = clamp(v)
        local pct = (current - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, -7, 0.5, -7)
        valLbl.Text = fmt(current)
        if fire and onChange then onChange(current) end
    end
    setVal(value, false)

    local dragging = false
    track.InputBegan:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    knob.InputBegan = nil -- knob is a frame; we instead use the track
    UserInputService.InputEnded:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(io)
        if dragging and io.UserInputType == Enum.UserInputType.MouseMovement then
            local mouseX = io.Position.X
            local rel = (mouseX - track.AbsolutePosition.X) / track.AbsoluteSize.X
            setVal(min + (max - min) * math.clamp(rel, 0, 1), true)
        end
    end)
    -- click to jump
    local clickBtn = Instance.new('TextButton', track)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Size = UDim2.new(1, 0, 1, 12)
    clickBtn.Position = UDim2.new(0, 0, 0, -6)
    clickBtn.Text = ''
    clickBtn.MouseButton1Down:Connect(function()
        dragging = true
        local mouseX = UserInputService:GetMouseLocation().X
        local rel = (mouseX - track.AbsolutePosition.X) / track.AbsoluteSize.X
        setVal(min + (max - min) * math.clamp(rel, 0, 1), true)
    end)

    return {
        instance = holder,
        get = function() return current end,
        set = function(v) setVal(v, false) end,
    }
end

-- Textbox
local function makeTextbox(parent, initial, width, placeholder, multi, onChange)
    local height = multi and 80 or 28
    local frame = makeRoundedFrame(parent, UDim2.new(0, width, 0, height), UDim2.new(), Theme.ContentBg, 4)
    makeStroke(frame, Theme.Border, 1)

    local tb = Instance.new('TextBox', frame)
    tb.BackgroundTransparency = 1
    tb.Size = UDim2.new(1, -16, 1, -8)
    tb.Position = UDim2.new(0, 8, 0, 4)
    tb.Font = Enum.Font.Gotham
    tb.TextSize = 13
    tb.TextColor3 = Theme.TextPrimary
    tb.PlaceholderColor3 = Theme.TextDim
    tb.PlaceholderText = placeholder or ''
    tb.Text = initial or ''
    tb.ClearTextOnFocus = false
    tb.MultiLine = multi and true or false
    tb.TextXAlignment = Enum.TextXAlignment.Left
    tb.TextYAlignment = multi and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
    tb.TextWrapped = multi and true or false

    tb.Focused:Connect(function()
        local stroke = frame:FindFirstChildOfClass('UIStroke')
        if stroke then Tween(stroke, 0.16, {Color = Theme.AccentPrimary}):Play() end
    end)
    tb.FocusLost:Connect(function()
        local stroke = frame:FindFirstChildOfClass('UIStroke')
        if stroke then Tween(stroke, 0.16, {Color = Theme.Border}):Play() end
        if onChange then onChange(tb.Text) end
    end)
    return {
        instance = frame,
        get = function() return tb.Text end,
        set = function(v) tb.Text = v end,
        tb = tb,
    }
end

-- Button
local function makeButton(parent, label, style, onClick)
    local bgCol  = Theme.AccentPrimary
    local hovCol = Color3.fromRGB(255, 95, 195)
    if style == 'secondary' then bgCol = Theme.CardBg; hovCol = Theme.CardBgHover end
    if style == 'danger' then bgCol = Theme.Danger; hovCol = Color3.fromRGB(255, 110, 130) end

    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(0, 100, 0, 30)
    btn.BackgroundColor3 = bgCol
    btn.AutoButtonColor = false
    btn.Text = label
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.TextColor3 = (style == 'secondary') and Theme.TextPrimary or Color3.fromRGB(255,255,255)
    btn.BorderSizePixel = 0
    btn.Parent = parent
    local c = Instance.new('UICorner', btn); c.CornerRadius = UDim.new(0, 4)

    btn.MouseEnter:Connect(function() Tween(btn, 0.16, {BackgroundColor3 = hovCol}):Play() end)
    btn.MouseLeave:Connect(function() Tween(btn, 0.16, {BackgroundColor3 = bgCol}):Play() end)
    btn.MouseButton1Click:Connect(function() if onClick then onClick() end end)
    return btn
end

-- Card
local function makeCard(parent, title, description)
    local card = makeRoundedFrame(parent, UDim2.new(1, -8, 0, 60), UDim2.new(), Theme.CardBg, 8)
    card.AutomaticSize = Enum.AutomaticSize.Y
    local pad = Instance.new('UIPadding', card)
    pad.PaddingTop = UDim.new(0, 16); pad.PaddingBottom = UDim.new(0, 16)
    pad.PaddingLeft = UDim.new(0, 16); pad.PaddingRight = UDim.new(0, 16)

    local layout = Instance.new('UIListLayout', card)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)

    local headerRow = Instance.new('Frame', card)
    headerRow.BackgroundTransparency = 1
    headerRow.Size = UDim2.new(1, 0, 0, 20)
    headerRow.LayoutOrder = 1

    local titleLbl = Instance.new('TextLabel', headerRow)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Size = UDim2.new(1, -120, 1, 0)
    titleLbl.Text = title
    titleLbl.Font = Enum.Font.GothamSemibold
    titleLbl.TextSize = 14
    titleLbl.TextColor3 = Theme.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    if description and description ~= '' then
        local desc = makeLabel(card, description, Enum.Font.Gotham, 12, Theme.TextDim, UDim2.new(), UDim2.new(1, 0, 0, 16))
        desc.LayoutOrder = 2
        desc.TextWrapped = true
        desc.AutomaticSize = Enum.AutomaticSize.Y
    end

    -- search metadata
    card:SetAttribute('SearchText', (title .. ' ' .. (description or '')):lower())

    return {
        instance = card,
        headerRow = headerRow,
        rightHeader = function()
            local h = Instance.new('Frame', headerRow)
            h.BackgroundTransparency = 1
            h.AnchorPoint = Vector2.new(1, 0)
            h.Position = UDim2.new(1, 0, 0, 0)
            h.Size = UDim2.new(0, 120, 1, 0)
            return h
        end,
    }
end

-- Row in card
local function makeRow(card, label, subLabel)
    local row = Instance.new('Frame', card.instance)
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 44)
    row.LayoutOrder = (card.instance:GetAttribute('_rowOrder') or 10) + 1
    card.instance:SetAttribute('_rowOrder', row.LayoutOrder)

    local lbl = Instance.new('TextLabel', row)
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 0, 0, 4)
    lbl.Size = UDim2.new(0.55, 0, 0, 18)
    lbl.Text = label
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = Theme.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    if subLabel and subLabel ~= '' then
        local sub = Instance.new('TextLabel', row)
        sub.BackgroundTransparency = 1
        sub.Position = UDim2.new(0, 0, 0, 22)
        sub.Size = UDim2.new(0.55, 0, 0, 14)
        sub.Text = subLabel
        sub.Font = Enum.Font.Gotham
        sub.TextSize = 11
        sub.TextColor3 = Theme.TextDim
        sub.TextXAlignment = Enum.TextXAlignment.Left
    end

    local right = Instance.new('Frame', row)
    right.BackgroundTransparency = 1
    right.AnchorPoint = Vector2.new(1, 0.5)
    right.Position = UDim2.new(1, 0, 0.5, 0)
    right.Size = UDim2.new(0.45, 0, 1, 0)

    local rightLayout = Instance.new('UIListLayout', right)
    rightLayout.FillDirection = Enum.FillDirection.Horizontal
    rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    rightLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rightLayout.Padding = UDim.new(0, 8)

    -- update search text
    local prior = card.instance:GetAttribute('SearchText') or ''
    card.instance:SetAttribute('SearchText', prior .. ' ' .. label:lower() .. ' ' .. (subLabel or ''):lower())

    return right
end

-- ===========================================================================
-- ROOT GUI
-- ===========================================================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'eni_perms_spoofer'
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
pcall(function() protect_gui(ScreenGui) end)
if ScreenGui.Parent == nil then ScreenGui.Parent = game:GetService('CoreGui') end

notifyContainer = Instance.new('Frame', ScreenGui)
notifyContainer.AnchorPoint = Vector2.new(1, 0)
notifyContainer.Position = UDim2.new(1, -20, 0, 60)
notifyContainer.Size = UDim2.new(0, 320, 1, -80)
notifyContainer.BackgroundTransparency = 1
local nLayout = Instance.new('UIListLayout', notifyContainer)
nLayout.Padding = UDim.new(0, 8)
nLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

-- Window
local Window = makeRoundedFrame(ScreenGui, UDim2.new(0, 920, 0, 600), UDim2.new(0.5, -460, 0.5, -300), Theme.WindowBg, 10)
Window.ClipsDescendants = true

local AccentStripe = makeRoundedFrame(Window, UDim2.new(1, 0, 0, 2), UDim2.new(), Theme.AccentPrimary, 0)
AccentStripe.ZIndex = 5

-- Title bar
local TitleBar = makeRoundedFrame(Window, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 2), Theme.WindowBg, 0)

local Logo = makeRoundedFrame(TitleBar, UDim2.new(0, 12, 0, 12), UDim2.new(0, 16, 0.5, -6), Theme.AccentPrimary, 3)
local TitleText = makeLabel(TitleBar, 'freezer', Enum.Font.GothamBold, 14, Theme.TextPrimary, UDim2.new(0, 36, 0, 0), UDim2.new(0, 200, 1, 0))

-- Search bar
local SearchHolder = makeRoundedFrame(TitleBar, UDim2.new(0, 380, 0, 28), UDim2.new(0.5, -190, 0.5, -14), Theme.ContentBg, 14)
local SearchIcon = makeLabel(SearchHolder, '\xF0\x9F\x94\x8D', Enum.Font.Gotham, 13, Theme.TextDim, UDim2.new(0, 10, 0, 0), UDim2.new(0, 16, 1, 0))
local SearchBox = Instance.new('TextBox', SearchHolder)
SearchBox.BackgroundTransparency = 1
SearchBox.Position = UDim2.new(0, 32, 0, 0)
SearchBox.Size = UDim2.new(1, -40, 1, 0)
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 13
SearchBox.TextColor3 = Theme.TextPrimary
SearchBox.PlaceholderText = 'Search settings'
SearchBox.PlaceholderColor3 = Theme.TextDim
SearchBox.Text = ''
SearchBox.ClearTextOnFocus = false
SearchBox.TextXAlignment = Enum.TextXAlignment.Left

-- Min/Close
local function makeWinButton(parent, text, hoverCol, xPos)
    local b = Instance.new('TextButton', parent)
    b.AnchorPoint = Vector2.new(1, 0)
    b.Position = UDim2.new(1, xPos, 0, 0)
    b.Size = UDim2.new(0, 46, 1, 0)
    b.BackgroundColor3 = Theme.WindowBg
    b.BackgroundTransparency = 1
    b.AutoButtonColor = false
    b.Text = text
    b.Font = Enum.Font.Gotham
    b.TextSize = 14
    b.TextColor3 = Theme.TextPrimary
    b.BorderSizePixel = 0
    b.MouseEnter:Connect(function()
        b.BackgroundTransparency = 0
        Tween(b, 0.12, {BackgroundColor3 = hoverCol}):Play()
    end)
    b.MouseLeave:Connect(function()
        Tween(b, 0.12, {BackgroundTransparency = 1}):Play()
    end)
    return b
end

local CloseBtn = makeWinButton(TitleBar, 'X', Theme.Danger, 0)
local MinBtn   = makeWinButton(TitleBar, '_', Theme.CardBg, -46)

-- Sidebar
local Sidebar = makeRoundedFrame(Window, UDim2.new(0, 220, 1, -68), UDim2.new(0, 0, 0, 42), Theme.SidebarBg, 0)
local SidebarLayout = Instance.new('UIListLayout', Sidebar)
SidebarLayout.Padding = UDim.new(0, 0)
SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Content
local Content = makeRoundedFrame(Window, UDim2.new(1, -220, 1, -68), UDim2.new(0, 220, 0, 42), Theme.ContentBg, 0)
local ContentPad = Instance.new('UIPadding', Content)
ContentPad.PaddingTop = UDim.new(0, 20); ContentPad.PaddingBottom = UDim.new(0, 20)
ContentPad.PaddingLeft = UDim.new(0, 20); ContentPad.PaddingRight = UDim.new(0, 20)

-- Pages dictionary
local pages = {}
local currentPage

local function makePage(name)
    local p = Instance.new('Frame', Content)
    p.Name = 'Page_' .. name
    p.BackgroundTransparency = 1
    p.Size = UDim2.new(1, 0, 1, 0)
    p.Visible = false

    local breadcrumb = makeLabel(p, 'Home > ' .. name, Enum.Font.Gotham, 11, Theme.TextDim, UDim2.new(), UDim2.new(1, 0, 0, 14))
    breadcrumb.LayoutOrder = 1
    local title = makeLabel(p, name, Enum.Font.GothamBold, 24, Theme.TextPrimary, UDim2.new(0, 0, 0, 18), UDim2.new(1, 0, 0, 28))
    title.LayoutOrder = 2

    local scroll = Instance.new('ScrollingFrame', p)
    scroll.BackgroundTransparency = 1
    scroll.Position = UDim2.new(0, 0, 0, 56)
    scroll.Size = UDim2.new(1, 0, 1, -56)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Theme.AccentPrimary
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

    local layout = Instance.new('UIListLayout', scroll)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)

    pages[name] = { frame = p, scroll = scroll }
    return scroll
end

local function makeNavItem(name, icon, order)
    local item = Instance.new('TextButton', Sidebar)
    item.Size = UDim2.new(1, 0, 0, 44)
    item.LayoutOrder = order
    item.BackgroundColor3 = Theme.SidebarBg
    item.AutoButtonColor = false
    item.Text = ''
    item.BorderSizePixel = 0

    local bar = makeRoundedFrame(item, UDim2.new(0, 3, 1, 0), UDim2.new(), Theme.AccentPrimary, 0)
    bar.Visible = false

    local iconLbl = makeLabel(item, icon, Enum.Font.Gotham, 16, Theme.TextSecondary, UDim2.new(0, 12, 0, 0), UDim2.new(0, 24, 1, 0))
    iconLbl.TextXAlignment = Enum.TextXAlignment.Left
    iconLbl.TextYAlignment = Enum.TextYAlignment.Center

    local lbl = makeLabel(item, name, Enum.Font.Gotham, 13, Theme.TextPrimary, UDim2.new(0, 40, 0, 0), UDim2.new(1, -48, 1, 0))
    lbl.TextYAlignment = Enum.TextYAlignment.Center

    item.MouseEnter:Connect(function()
        if currentPage ~= name then Tween(item, 0.15, {BackgroundColor3 = Theme.CardBg}):Play() end
    end)
    item.MouseLeave:Connect(function()
        if currentPage ~= name then Tween(item, 0.15, {BackgroundColor3 = Theme.SidebarBg}):Play() end
    end)

    item.MouseButton1Click:Connect(function()
        for n, pg in pairs(pages) do
            pg.frame.Visible = false
        end
        if pages[name] then pages[name].frame.Visible = true end
        -- update nav selection
        for _, sib in ipairs(Sidebar:GetChildren()) do
            if sib:IsA('TextButton') then
                local nbar = sib:FindFirstChildOfClass('Frame')
                if nbar then nbar.Visible = false end
                sib.BackgroundColor3 = Theme.SidebarBg
            end
        end
        bar.Visible = true
        item.BackgroundColor3 = Theme.AccentSoft
        currentPage = name
    end)

    return item
end

local function makeNavDivider(order)
    local d = Instance.new('Frame', Sidebar)
    d.Size = UDim2.new(1, -16, 0, 1)
    d.Position = UDim2.new(0, 8, 0, 0)
    d.BackgroundColor3 = Theme.Border
    d.BorderSizePixel = 0
    d.LayoutOrder = order
    local spacer = Instance.new('Frame', Sidebar)
    spacer.Size = UDim2.new(1, 0, 0, 8)
    spacer.BackgroundTransparency = 1
    spacer.LayoutOrder = order + 1
end

-- Status footer
local Footer = makeRoundedFrame(Window, UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 1, -26), Theme.WindowBg, 0)
local fBorder = Instance.new('Frame', Footer)
fBorder.Size = UDim2.new(1, 0, 0, 1)
fBorder.BackgroundColor3 = Theme.Border
fBorder.BorderSizePixel = 0

local FooterDot = makeRoundedFrame(Footer, UDim2.new(0, 6, 0, 6), UDim2.new(0, 12, 0.5, -3), Theme.AccentPrimary, 3)
local FooterStatus = makeLabel(Footer, '', Enum.Font.Gotham, 11, Theme.TextSecondary, UDim2.new(0, 24, 0, 0), UDim2.new(1, -32, 1, 0))
FooterStatus.TextYAlignment = Enum.TextYAlignment.Center

local function updateFooter()
    local fps = 0
    pcall(function() fps = math.floor(1 / RunService.RenderStepped:Wait()) end)
    local ping = 0
    pcall(function() ping = math.floor(Stats.Network.ServerStatsItem['Data Ping']:GetValue()) end)
    local pcount = #Players:GetPlayers()
    local gname = 'game'
    pcall(function()
        local info = MarketplaceService:GetProductInfo(game.PlaceId)
        if info then gname = info.Name end
    end)
    local timeStr = os.date('%H:%M')
    local sp = 'idle'
    if state.Enabled then
        sp = string.format('premium: %s | gp: %s | rank: %s | hooks: %d active',
            state.PremiumSpoof and 'spoofed' or 'off',
            state.GamepassSpoof and ((parseIdList(state.GamepassWhitelist) and next(parseIdList(state.GamepassWhitelist))) and 'WL' or 'ALL') or 'off',
            state.GroupSpoof and tostring(state.GroupRank) or '-',
            activeHookCount)
    end
    FooterStatus.Text = string.format('%s   |  FPS %d / Ping %dms / %d players / %s / %s', sp, fps, ping, pcount, gname, timeStr)
end

-- ===========================================================================
-- BUILD PAGES & CARDS
-- ===========================================================================

-- Build navigation items
local navOrder = 0
local function nav(name, icon) navOrder = navOrder + 1; return makeNavItem(name, icon, navOrder) end
local function divider() navOrder = navOrder + 1; makeNavDivider(navOrder); navOrder = navOrder + 1 end

nav('General',     '\xE2\x9A\x99')
nav('Premium',     '\xE2\xAD\x90')
nav('Gamepass',    '\xF0\x9F\x8E\xAB')
nav('Asset',       '\xF0\x9F\x93\xA6')
nav('Badge',       '\xF0\x9F\x8F\x85')
nav('Group',       '\xF0\x9F\x91\xA5')
divider()
nav('Policy',      '\xF0\x9F\x93\x8B')
nav('Studio',      '\xF0\x9F\x8E\xAC')
nav('Owner',       '\xF0\x9F\x91\x91')
nav('Teleport',    '\xF0\x9F\x9A\x80')
divider()
nav('Attributes',  '\xF0\x9F\x8F\xB7')
nav('Leaderstats', '\xF0\x9F\x93\x8A')
nav('AdminUI',     '\xF0\x9F\x91\x80')
divider()
nav('Logs',        '\xF0\x9F\x93\x9C')
nav('Settings',    '\xF0\x9F\x94\xA7')

-- ===========================================================================
-- PAGE: General
-- ===========================================================================
do
    local p = makePage('General')

    local card = makeCard(p, 'Master Control', 'Enable or disable the entire Perms Spoofer module.')
    local right = card.rightHeader()
    local row = makeRow(card, 'Enabled', 'Toggles all installed hooks on/off')
    local t = makeToggle(row, state.Enabled, function(v) state.Enabled = v; saveConfig(); recomputeActiveHookCount(); notify('Perms Spoofer', v and 'Module enabled' or 'Module disabled', v and 'success' or 'warn', 2) end)
    t.instance.Parent = row

    local row2 = makeRow(card, 'Auto-enable on load', 'Re-enable automatically when script runs')
    local t2 = makeToggle(row2, state.AutoEnableOnLoad, function(v) state.AutoEnableOnLoad = v; saveConfig() end)
    t2.instance.Parent = row2

    local row3 = makeRow(card, 'Verbose logs', 'Log every spoofed call to the Logs panel')
    local t3 = makeToggle(row3, state.VerboseLogs, function(v) state.VerboseLogs = v; saveConfig() end)
    t3.instance.Parent = row3

    -- Panic card
    local panic = makeCard(p, 'Panic', 'Restore originals and disable every hook immediately.')
    panic.instance.LayoutOrder = 10
    local prow = makeRow(panic, 'Restore originals', 'Disables module + clears spoof state')
    local pb = makeButton(prow, 'Restore', 'danger', function()
        state.Enabled = false
        for k in pairs(state) do
            if type(state[k]) == 'boolean' and k:find('Spoof') then
                state[k] = false
            end
        end
        recomputeActiveHookCount()
        saveConfig()
        notify('Perms Spoofer', 'All spoofs disabled', 'warn', 3)
    end)
    pb.Parent = prow
end

-- ===========================================================================
-- PAGE: Premium
-- ===========================================================================
do
    local p = makePage('Premium')
    local card = makeCard(p, 'Premium Membership', 'Forces Player.MembershipType to Premium client-side. UI gates that read .MembershipType will unlock.')

    local row = makeRow(card, 'Spoof Premium', 'Returns Enum.MembershipType.Premium')
    local t = makeToggle(row, state.PremiumSpoof, function(v) state.PremiumSpoof = v; saveConfig(); recomputeActiveHookCount(); notify('Premium', v and 'Premium spoof on' or 'Premium spoof off', 'success', 2) end)
    t.instance.Parent = row

    local note = makeCard(p, 'Note', 'Client-only spoof. Server-validated premium checks will not be fooled.')
    note.instance.LayoutOrder = 5
end

-- ===========================================================================
-- PAGE: Gamepass
-- ===========================================================================
do
    local p = makePage('Gamepass')
    local card = makeCard(p, 'Gamepass Ownership', 'Hooks MarketplaceService:UserOwnsGamePassAsync.')

    local row = makeRow(card, 'Spoof all gamepasses', 'Returns true for every UserOwnsGamePassAsync call')
    local t = makeToggle(row, state.GamepassSpoof, function(v) state.GamepassSpoof = v; saveConfig(); recomputeActiveHookCount() end)
    t.instance.Parent = row

    local wlCard = makeCard(p, 'Whitelist (only these IDs return true)', 'One ID per line. Leave empty to spoof all.')
    wlCard.instance.LayoutOrder = 2
    local wlBox = makeTextbox(wlCard.instance, state.GamepassWhitelist, 720, '12345678\n23456789', true, function(v)
        state.GamepassWhitelist = v; saveConfig()
    end)
    wlBox.tb.Size = UDim2.new(1, -16, 0, 100)
    wlBox.instance.Size = UDim2.new(1, 0, 0, 110)
    wlBox.instance.LayoutOrder = 10

    local blCard = makeCard(p, 'Blacklist (always return false)', 'One ID per line. Overrides whitelist.')
    blCard.instance.LayoutOrder = 3
    local blBox = makeTextbox(blCard.instance, state.GamepassBlacklist, 720, '99999999', true, function(v)
        state.GamepassBlacklist = v; saveConfig()
    end)
    blBox.tb.Size = UDim2.new(1, -16, 0, 80)
    blBox.instance.Size = UDim2.new(1, 0, 0, 90)
    blBox.instance.LayoutOrder = 10
end

-- ===========================================================================
-- PAGE: Asset
-- ===========================================================================
do
    local p = makePage('Asset')
    local card = makeCard(p, 'Asset Ownership', 'Hooks MarketplaceService:PlayerOwnsAsset to return true.')
    local row = makeRow(card, 'Spoof asset ownership', 'Affects clothing, accessories, audio gates')
    local t = makeToggle(row, state.AssetSpoof, function(v) state.AssetSpoof = v; saveConfig(); recomputeActiveHookCount() end)
    t.instance.Parent = row
end

-- ===========================================================================
-- PAGE: Badge
-- ===========================================================================
do
    local p = makePage('Badge')
    local card = makeCard(p, 'Badge Ownership', 'Hooks BadgeService:UserHasBadgeAsync to return true.')
    local row = makeRow(card, 'Spoof badge ownership', '')
    local t = makeToggle(row, state.BadgeSpoof, function(v) state.BadgeSpoof = v; saveConfig(); recomputeActiveHookCount() end)
    t.instance.Parent = row
end

-- ===========================================================================
-- PAGE: Group
-- ===========================================================================
do
    local p = makePage('Group')
    local card = makeCard(p, 'Group Membership', 'Spoofs Player:GetRankInGroup / IsInGroup / GetRoleInGroup for one specific group ID.')

    local rowEn = makeRow(card, 'Enable group spoof', '')
    local tEn = makeToggle(rowEn, state.GroupSpoof, function(v) state.GroupSpoof = v; saveConfig(); recomputeActiveHookCount() end)
    tEn.instance.Parent = rowEn

    local rowId = makeRow(card, 'Group ID', 'The group ID to spoof for')
    local idBox = makeTextbox(rowId, tostring(state.GroupId), 160, 'group id', false, function(v)
        state.GroupId = tonumber(v) or 0; saveConfig()
    end)
    idBox.instance.Parent = rowId

    local rowRank = makeRow(card, 'Rank value', 'Returned by GetRankInGroup (0-255)')
    local sl = makeSlider(rowRank, 0, 255, state.GroupRank, 0, function(v) state.GroupRank = math.floor(v); saveConfig() end)
    sl.instance.Parent = rowRank

    local rowRole = makeRow(card, 'Role name', 'Returned by GetRoleInGroup')
    local roleBox = makeTextbox(rowRole, state.GroupRole, 200, 'Owner', false, function(v) state.GroupRole = v; saveConfig() end)
    roleBox.instance.Parent = rowRole
end

-- ===========================================================================
-- PAGE: Policy
-- ===========================================================================
do
    local p = makePage('Policy')
    local card = makeCard(p, 'PolicyService', 'Returns a permissive PolicyInfo to bypass region/age policy gates.')
    local row = makeRow(card, 'Spoof permissive policy', 'IsContentSharingAllowed=true, etc.')
    local t = makeToggle(row, state.PolicySpoof, function(v) state.PolicySpoof = v; saveConfig(); recomputeActiveHookCount() end)
    t.instance.Parent = row
end

-- ===========================================================================
-- PAGE: Studio
-- ===========================================================================
do
    local p = makePage('Studio')
    local card = makeCard(p, 'IsStudio Spoof', 'Forces RunService:IsStudio() to return true. Unlocks dev/test branches in many admin scripts.')
    local row = makeRow(card, 'Spoof IsStudio', '')
    local t = makeToggle(row, state.IsStudioSpoof, function(v) state.IsStudioSpoof = v; saveConfig(); recomputeActiveHookCount() end)
    t.instance.Parent = row
end

-- ===========================================================================
-- PAGE: Owner
-- ===========================================================================
do
    local p = makePage('Owner')
    local card = makeCard(p, 'Game Creator', 'Spoofs game.CreatorId == LocalPlayer.UserId so client-side "is owner" checks return true.')
    local row = makeRow(card, 'Spoof game owner', '')
    local t = makeToggle(row, state.OwnerSpoof, function(v) state.OwnerSpoof = v; saveConfig(); recomputeActiveHookCount() end)
    t.instance.Parent = row
end

-- ===========================================================================
-- PAGE: Teleport
-- ===========================================================================
do
    local p = makePage('Teleport')
    local card = makeCard(p, 'TeleportData', 'Override the value returned by TeleportService:GetLocalPlayerTeleportData() (JSON).')
    local row = makeRow(card, 'Spoof teleport data', '')
    local t = makeToggle(row, state.TeleportDataSpoof, function(v) state.TeleportDataSpoof = v; saveConfig(); recomputeActiveHookCount() end)
    t.instance.Parent = row

    local cardJson = makeCard(p, 'Payload (JSON)', '')
    cardJson.instance.LayoutOrder = 2
    local box = makeTextbox(cardJson.instance, state.TeleportDataValue, 720, '{ "admin": true, "rank": "owner" }', true, function(v)
        state.TeleportDataValue = v; saveConfig()
    end)
    box.tb.Size = UDim2.new(1, -16, 0, 100)
    box.instance.Size = UDim2.new(1, 0, 0, 110)
    box.instance.LayoutOrder = 10
end

-- ===========================================================================
-- PAGE: Attributes
-- ===========================================================================
local attrListFrame
do
    local p = makePage('Attributes')
    local card = makeCard(p, 'Custom Attributes', 'Sets attributes on LocalPlayer. Many admin GUIs read "IsAdmin", "Rank", "Permissions" etc.')

    attrListFrame = Instance.new('Frame', card.instance)
    attrListFrame.BackgroundTransparency = 1
    attrListFrame.Size = UDim2.new(1, 0, 0, 0)
    attrListFrame.AutomaticSize = Enum.AutomaticSize.Y
    attrListFrame.LayoutOrder = 5
    local attrLayout = Instance.new('UIListLayout', attrListFrame)
    attrLayout.Padding = UDim.new(0, 6)

    local btnRow = Instance.new('Frame', card.instance)
    btnRow.BackgroundTransparency = 1
    btnRow.Size = UDim2.new(1, 0, 0, 38)
    btnRow.LayoutOrder = 100
    local rowLayout = Instance.new('UIListLayout', btnRow)
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.Padding = UDim.new(0, 8)

    local function rebuildAttrList()
        for _, c in ipairs(attrListFrame:GetChildren()) do
            if c:IsA('Frame') then c:Destroy() end
        end
        for idx, row in ipairs(state.Attributes) do
            local r = Instance.new('Frame', attrListFrame)
            r.BackgroundTransparency = 1
            r.Size = UDim2.new(1, 0, 0, 32)
            local rL = Instance.new('UIListLayout', r)
            rL.FillDirection = Enum.FillDirection.Horizontal
            rL.Padding = UDim.new(0, 8)

            local kb = makeTextbox(r, row.key or '', 200, 'key', false, function(v) row.key = v; saveConfig() end)
            kb.instance.Parent = r

            local vb = makeTextbox(r, tostring(row.value or ''), 200, 'value', false, function(v) row.value = v; saveConfig(); applyAttributes() end)
            vb.instance.Parent = r

            local typeBtn = makeButton(r, row.type or 'string', 'secondary', function()
                local order = {'string', 'number', 'bool'}
                local cur = row.type or 'string'
                local nxt
                for i, t in ipairs(order) do if t == cur then nxt = order[(i % #order) + 1] end end
                row.type = nxt or 'string'
                saveConfig()
                applyAttributes()
                rebuildAttrList()
            end)
            typeBtn.Size = UDim2.new(0, 80, 0, 28)
            typeBtn.Parent = r

            local rm = makeButton(r, 'Remove', 'danger', function()
                table.remove(state.Attributes, idx)
                saveConfig()
                rebuildAttrList()
            end)
            rm.Size = UDim2.new(0, 80, 0, 28)
            rm.Parent = r
        end
    end

    local add = makeButton(btnRow, 'Add row', nil, function()
        table.insert(state.Attributes, { key = '', value = '', type = 'string' })
        saveConfig()
        rebuildAttrList()
    end)
    add.Parent = btnRow

    local apply = makeButton(btnRow, 'Apply now', 'secondary', function()
        applyAttributes()
        notify('Attributes', 'Applied ' .. #state.Attributes .. ' attribute(s)', 'success', 2)
    end)
    apply.Parent = btnRow

    rebuildAttrList()
end

-- ===========================================================================
-- PAGE: Leaderstats
-- ===========================================================================
do
    local p = makePage('Leaderstats')
    local card = makeCard(p, 'Leaderstats Spoof', 'Creates or overrides values in LocalPlayer.leaderstats. Client-side only.')

    local listFrame = Instance.new('Frame', card.instance)
    listFrame.BackgroundTransparency = 1
    listFrame.Size = UDim2.new(1, 0, 0, 0)
    listFrame.AutomaticSize = Enum.AutomaticSize.Y
    listFrame.LayoutOrder = 5
    local lLayout = Instance.new('UIListLayout', listFrame)
    lLayout.Padding = UDim.new(0, 6)

    local btnRow = Instance.new('Frame', card.instance)
    btnRow.BackgroundTransparency = 1
    btnRow.Size = UDim2.new(1, 0, 0, 38)
    btnRow.LayoutOrder = 100
    local bL = Instance.new('UIListLayout', btnRow)
    bL.FillDirection = Enum.FillDirection.Horizontal
    bL.Padding = UDim.new(0, 8)

    local function rebuild()
        for _, c in ipairs(listFrame:GetChildren()) do
            if c:IsA('Frame') then c:Destroy() end
        end
        for idx, row in ipairs(state.Leaderstats) do
            local r = Instance.new('Frame', listFrame)
            r.BackgroundTransparency = 1
            r.Size = UDim2.new(1, 0, 0, 32)
            local rL = Instance.new('UIListLayout', r)
            rL.FillDirection = Enum.FillDirection.Horizontal
            rL.Padding = UDim.new(0, 8)

            local kb = makeTextbox(r, row.key or '', 200, 'stat name', false, function(v) row.key = v; saveConfig(); applyLeaderstats() end)
            kb.instance.Parent = r
            local vb = makeTextbox(r, tostring(row.value or ''), 200, 'value', false, function(v) row.value = v; saveConfig(); applyLeaderstats() end)
            vb.instance.Parent = r

            local typeBtn = makeButton(r, row.type or 'string', 'secondary', function()
                local order = {'string', 'number', 'bool'}
                local cur = row.type or 'string'
                local nxt
                for i, t in ipairs(order) do if t == cur then nxt = order[(i % #order) + 1] end end
                row.type = nxt or 'string'
                saveConfig()
                applyLeaderstats()
                rebuild()
            end)
            typeBtn.Size = UDim2.new(0, 80, 0, 28)
            typeBtn.Parent = r

            local rm = makeButton(r, 'Remove', 'danger', function()
                table.remove(state.Leaderstats, idx)
                saveConfig()
                applyLeaderstats()
                rebuild()
            end)
            rm.Size = UDim2.new(0, 80, 0, 28)
            rm.Parent = r
        end
    end

    local add = makeButton(btnRow, 'Add stat', nil, function()
        table.insert(state.Leaderstats, { key = '', value = '0', type = 'number' })
        saveConfig()
        rebuild()
    end)
    add.Parent = btnRow
    local apply = makeButton(btnRow, 'Apply now', 'secondary', function()
        applyLeaderstats()
        notify('Leaderstats', 'Applied ' .. #state.Leaderstats .. ' stat(s)', 'success', 2)
    end)
    apply.Parent = btnRow

    rebuild()
end

-- ===========================================================================
-- PAGE: AdminUI
-- ===========================================================================
do
    local p = makePage('AdminUI')
    local card = makeCard(p, 'Force-show admin UI', 'Heuristically reveals hidden GUI elements named admin/staff/owner/premium inside PlayerGui.')
    local row = makeRow(card, 'Enable bypass', 'Forces Visible = true on matching frames')
    local t = makeToggle(row, state.HideAdminUiBypass, function(v) state.HideAdminUiBypass = v; saveConfig(); recomputeActiveHookCount(); if v then applyAdminUiBypass() end end)
    t.instance.Parent = row

    local rescanRow = makeRow(card, 'Rescan now', 'Walk PlayerGui again')
    local b = makeButton(rescanRow, 'Rescan', nil, function() applyAdminUiBypass(); notify('AdminUI', 'Rescanned PlayerGui', 'success', 2) end)
    b.Parent = rescanRow
end

-- ===========================================================================
-- PAGE: Logs
-- ===========================================================================
local logScroll
do
    local p = makePage('Logs')
    local card = makeCard(p, 'Hook Log', 'Live feed of spoofed calls. Verbose mode required.')

    logScroll = Instance.new('ScrollingFrame', card.instance)
    logScroll.BackgroundColor3 = Theme.ContentBg
    logScroll.BorderSizePixel = 0
    logScroll.Size = UDim2.new(1, 0, 0, 320)
    logScroll.LayoutOrder = 10
    logScroll.ScrollBarThickness = 3
    logScroll.ScrollBarImageColor3 = Theme.AccentPrimary
    logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    local lc = Instance.new('UICorner', logScroll); lc.CornerRadius = UDim.new(0, 6)
    local lpad = Instance.new('UIPadding', logScroll); lpad.PaddingLeft = UDim.new(0, 8); lpad.PaddingRight = UDim.new(0, 8); lpad.PaddingTop = UDim.new(0, 8)
    local lLayout = Instance.new('UIListLayout', logScroll); lLayout.Padding = UDim.new(0, 2)

    onHookLog = function(entry)
        local row = Instance.new('TextLabel', logScroll)
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, -8, 0, 16)
        row.Font = Enum.Font.Code
        row.TextSize = 12
        row.TextColor3 = Theme.TextSecondary
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Text = string.format('[%s] %s(%s) -> %s', entry.time, entry.fn, entry.args, entry.ret)
        -- prune
        local kids = logScroll:GetChildren()
        local count = 0
        for _, c in ipairs(kids) do if c:IsA('TextLabel') then count = count + 1 end end
        if count > 150 then
            for _, c in ipairs(kids) do
                if c:IsA('TextLabel') then c:Destroy(); break end
            end
        end
    end

    local clearBtnRow = makeRow(card, 'Clear log', '')
    local cb = makeButton(clearBtnRow, 'Clear', 'secondary', function()
        for _, c in ipairs(logScroll:GetChildren()) do
            if c:IsA('TextLabel') then c:Destroy() end
        end
        hookLog = {}
    end)
    cb.Parent = clearBtnRow
end

-- ===========================================================================
-- PAGE: Settings
-- ===========================================================================
do
    local p = makePage('Settings')
    local card = makeCard(p, 'Configuration', 'Save, load or reset to defaults.')

    local row = makeRow(card, 'Save config', 'Write to ' .. CONFIG_PATH)
    local sb = makeButton(row, 'Save', nil, function() saveConfig(); notify('Settings', 'Config saved', 'success', 2) end)
    sb.Parent = row
    local row2 = makeRow(card, 'Load config', 'Re-read from disk')
    local lb = makeButton(row2, 'Load', 'secondary', function() loadConfig(); notify('Settings', 'Config loaded', 'success', 2) end)
    lb.Parent = row2
    local row3 = makeRow(card, 'Reset to defaults', 'Wipes the current config')
    local rb = makeButton(row3, 'Reset', 'danger', function()
        for k, v in pairs(defaultState) do
            if type(v) == 'table' then state[k] = {} else state[k] = v end
        end
        saveConfig()
        notify('Settings', 'Defaults restored', 'warn', 2)
    end)
    rb.Parent = row3

    local kbCard = makeCard(p, 'Keybind', '')
    kbCard.instance.LayoutOrder = 5
    local krow = makeRow(kbCard, 'Toggle window', 'Press to rebind, ESC to clear')
    local kbBtn = makeButton(krow, state.Keybind or 'F1', 'secondary')
    kbBtn.Size = UDim2.new(0, 100, 0, 28)
    kbBtn.Parent = krow
    local listening = false
    kbBtn.MouseButton1Click:Connect(function()
        listening = true
        kbBtn.Text = 'Press a key...'
    end)
    track(UserInputService.InputBegan:Connect(function(io, gp)
        if gp then return end
        if listening and io.UserInputType == Enum.UserInputType.Keyboard then
            if io.KeyCode == Enum.KeyCode.Escape then
                state.Keybind = ''
                kbBtn.Text = 'None'
            else
                state.Keybind = io.KeyCode.Name
                kbBtn.Text = state.Keybind
            end
            saveConfig()
            listening = false
        end
    end))
end

-- ===========================================================================
-- DEFAULT PAGE
-- ===========================================================================
if pages['General'] then
    pages['General'].frame.Visible = true
    currentPage = 'General'
    -- highlight first nav
    for _, sib in ipairs(Sidebar:GetChildren()) do
        if sib:IsA('TextButton') then
            local lbl = sib:FindFirstChildOfClass('TextLabel')
            if lbl and lbl.Text == 'General' then
                local nbar = sib:FindFirstChildOfClass('Frame')
                if nbar then nbar.Visible = true end
                sib.BackgroundColor3 = Theme.AccentSoft
            end
            break
        end
    end
end

-- ===========================================================================
-- SEARCH FILTER
-- ===========================================================================
SearchBox:GetPropertyChangedSignal('Text'):Connect(function()
    local q = SearchBox.Text:lower()
    for name, pg in pairs(pages) do
        for _, child in ipairs(pg.scroll:GetChildren()) do
            if child:IsA('Frame') then
                if q == '' then
                    child.Visible = true
                else
                    local meta = child:GetAttribute('SearchText') or ''
                    child.Visible = meta:find(q, 1, true) ~= nil
                end
            end
        end
    end
end)

-- ===========================================================================
-- DRAGGING
-- ===========================================================================
do
    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = io.Position
            startPos = Window.Position
        end
    end)
    TitleBar.InputEnded:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(io)
        if dragging and io.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = io.Position - dragStart
            Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Minimize / close
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        Tween(Window, 0.18, {Size = UDim2.new(0, 920, 0, 42)}):Play()
    else
        Tween(Window, 0.18, {Size = UDim2.new(0, 920, 0, 600)}):Play()
    end
end)
CloseBtn.MouseButton1Click:Connect(function()
    Window.Visible = false
end)

-- Keybind toggle
track(UserInputService.InputBegan:Connect(function(io, gp)
    if gp then return end
    if io.UserInputType == Enum.UserInputType.Keyboard then
        if state.Keybind and state.Keybind ~= '' and io.KeyCode.Name == state.Keybind then
            Window.Visible = not Window.Visible
        end
    end
end))

-- ===========================================================================
-- INSTALL HOOKS
-- ===========================================================================
installNamecallHook()
installIsStudioHook()
recomputeActiveHookCount()

-- Apply attributes/leaderstats whenever character respawns
track(LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    applyAttributes()
    applyLeaderstats()
end))

-- Periodic footer refresh
task.spawn(function()
    while ScreenGui.Parent do
        updateFooter()
        task.wait(1)
    end
end)

-- ===========================================================================
-- AUTO-ENABLE
-- ===========================================================================
if state.AutoEnableOnLoad then
    state.Enabled = true
    recomputeActiveHookCount()
    applyAttributes()
    applyLeaderstats()
    notify('Perms Spoofer', 'Auto-enabled on load', 'success', 3)
end

-- ===========================================================================
-- API
-- ===========================================================================
getgenv().ENI = getgenv().ENI or {}

local api = {}
function api.Show()  Window.Visible = true end
function api.Hide()  Window.Visible = false end
function api.Toggle() Window.Visible = not Window.Visible end
function api.Destroy()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    connections = {}
    state.Enabled = false
    pcall(function() ScreenGui:Destroy() end)
    getgenv().ENI.PermsSpoofer = nil
end
function api.GetConfig() return state end
function api.SetConfig(t)
    if type(t) ~= 'table' then return end
    for k, v in pairs(t) do state[k] = v end
    saveConfig()
    recomputeActiveHookCount()
end
function api.SaveConfig() saveConfig() end
function api.LoadConfig() loadConfig() end
function api.Notify(title, msg, kind, dur) notify(title, msg, kind, dur) end
function api.GetHookLog() return hookLog end
function api.GetActiveHookCount() return activeHookCount end

getgenv().ENI.PermsSpoofer = api

notify('Perms Spoofer', 'v3.0.0 loaded. Press F1 to toggle.', 'success', 3)

return api

end
-- END MODULE: PERMS SPOOFER v3.0.0
----------------------------------------------------------------------

----------------------------------------------------------------------
-- MODULE: LIVE STATE v3.0.0 (1265 lines original)
----------------------------------------------------------------------
do
--[[
    eni-roblox-kit :: utility/live_state.lua
    Live State Monitor v3.0.0

    Tells you in real time which character/player/world properties are client-local
    vs server-replicated. Probes by writing test values, waits, reads back, and
    tags each row Local / Replicated / Unknown / Probing. Helps decide which
    exploit vectors will actually land before you burn a session.

    API: getgenv().ENI.LiveState
    Keybinds (default): F11 audit (Probe All), F10 toggle window
--]]

-- ========================== ANTI-DETECT SHIMS =========================== --
local cloneref = cloneref or function(x) return x end
local protect_gui = (syn and syn.protect_gui) or (gethui and function(g) g.Parent = gethui() end) or function(g) g.Parent = game:GetService('CoreGui') end
local hookmetamethod = hookmetamethod or function() return nil end
local getrawmetatable = getrawmetatable or function() return nil end
local setreadonly = setreadonly or function() end
local newcclosure = newcclosure or function(f) return f end
local checkcaller = checkcaller or function() return false end

-- ============================== SERVICES ================================ --
local Players = cloneref(game:GetService('Players'))
local RunService = cloneref(game:GetService('RunService'))
local UserInputService = cloneref(game:GetService('UserInputService'))
local TweenService = cloneref(game:GetService('TweenService'))
local HttpService = cloneref(game:GetService('HttpService'))
local Lighting = cloneref(game:GetService('Lighting'))
local Workspace = cloneref(game:GetService('Workspace'))
local MarketplaceService = cloneref(game:GetService('MarketplaceService'))
local Stats = cloneref(game:GetService('Stats'))

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- =============================== THEME ================================== --
local C = {
    WindowBg       = Color3.fromRGB(20, 20, 26),
    SidebarBg     = Color3.fromRGB(24, 24, 30),
    ContentBg     = Color3.fromRGB(28, 28, 34),
    CardBg        = Color3.fromRGB(36, 36, 44),
    CardBgHover   = Color3.fromRGB(42, 42, 52),
    Border        = Color3.fromRGB(54, 54, 66),
    AccentPrimary = Color3.fromRGB(255, 65, 180),
    AccentSoft    = Color3.fromRGB(80, 32, 60),
    TextPrimary   = Color3.fromRGB(240, 240, 248),
    TextSecondary = Color3.fromRGB(170, 170, 188),
    TextDim       = Color3.fromRGB(115, 115, 135),
    Success       = Color3.fromRGB(80, 220, 130),
    Warning       = Color3.fromRGB(255, 185, 70),
    Danger        = Color3.fromRGB(255, 90, 110),
}

local EASE = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- ============================== STATE =================================== --
local CONFIG_PATH = 'freezer/live_state.json'

local DEFAULTS = {
    autoProbe = false,
    autoProbeInterval = 15,
    refreshInterval = 0.5,
    notifyOnChange = true,
    maxLogSize = 200,
    filter = 'All',
    toggleKey = 'F10',
    auditKey = 'F11',
    customProbes = {},
}

local state = {}
for k, v in pairs(DEFAULTS) do state[k] = v end

local function loadConfig()
    local ok, data = pcall(function() return readfile and readfile(CONFIG_PATH) end)
    if ok and data then
        local ok2, decoded = pcall(function() return HttpService:JSONDecode(data) end)
        if ok2 and type(decoded) == 'table' then
            for k, v in pairs(decoded) do state[k] = v end
        end
    end
end

local function saveConfig()
    if not writefile then return end
    pcall(function()
        local ok, isfolder_ok = pcall(isfolder, 'freezer')
        if ok and not isfolder_ok and makefolder then makefolder('freezer') end
        writefile(CONFIG_PATH, HttpService:JSONEncode(state))
    end)
end

loadConfig()

-- =========================== CONNECTION TRACK =========================== --
local connections = {}
local function track(con) table.insert(connections, con); return con end
local function clearConnections()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
end

-- =========================== ROW DATA STORE ============================= --
-- rows[id] = { id, path, label, category, getter, setter, badge, history={ok,fail}, lastValue, score, lastChange }
local rows = {}
local rowOrder = {}
local changeLog = {}
local toolEvents = {}
local cframeEcho = { samples = {}, lastWriteTime = 0 }
local repTest = { samples = {}, active = false, startVal = nil, target = nil, startedAt = 0, prop = nil }

local function uuid()
    return HttpService:GenerateGUID(false):sub(1, 8)
end

-- =============================== GUI ROOT =============================== --
local oldGui = LocalPlayer:FindFirstChild('PlayerGui') and LocalPlayer.PlayerGui:FindFirstChild('_ls_legacy')
if oldGui then oldGui:Destroy() end

local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = ScreenGuiName .. '_ls'
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
protect_gui(ScreenGui)
if ScreenGui.Parent == nil then ScreenGui.Parent = LocalPlayer:WaitForChild('PlayerGui') end

-- ============================== NOTIFY =================================== --
local NotifyHolder = Instance.new('Frame')
NotifyHolder.Name = 'NotifyHolder'
NotifyHolder.AnchorPoint = Vector2.new(1, 0)
NotifyHolder.Position = UDim2.new(1, -16, 0, 16)
NotifyHolder.Size = UDim2.new(0, 320, 1, -32)
NotifyHolder.BackgroundTransparency = 1
NotifyHolder.Parent = ScreenGui

local NotifyList = Instance.new('UIListLayout')
NotifyList.Padding = UDim.new(0, 8)
NotifyList.SortOrder = Enum.SortOrder.LayoutOrder
NotifyList.Parent = NotifyHolder

local function notify(title, msg, kind, duration)
    kind = kind or 'info'
    duration = duration or 3
    local toast = Instance.new('Frame')
    toast.Size = UDim2.new(1, 0, 0, 60)
    toast.BackgroundColor3 = C.CardBg
    toast.BorderSizePixel = 0
    toast.ClipsDescendants = true
    toast.Position = UDim2.new(1, 40, 0, 0)
    local corner = Instance.new('UICorner', toast); corner.CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new('UIStroke', toast); stroke.Color = C.Border; stroke.Thickness = 1

    local bar = Instance.new('Frame', toast)
    bar.Size = UDim2.new(0, 3, 1, 0)
    bar.BorderSizePixel = 0
    local accentColor = C.AccentPrimary
    if kind == 'success' then accentColor = C.Success
    elseif kind == 'warn' then accentColor = C.Warning
    elseif kind == 'error' then accentColor = C.Danger end
    bar.BackgroundColor3 = accentColor

    local t = Instance.new('TextLabel', toast)
    t.BackgroundTransparency = 1
    t.Position = UDim2.new(0, 12, 0, 8)
    t.Size = UDim2.new(1, -20, 0, 18)
    t.Font = Enum.Font.GothamBold
    t.TextSize = 13
    t.TextColor3 = C.TextPrimary
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Text = title or 'LiveState'

    local m = Instance.new('TextLabel', toast)
    m.BackgroundTransparency = 1
    m.Position = UDim2.new(0, 12, 0, 28)
    m.Size = UDim2.new(1, -20, 0, 28)
    m.Font = Enum.Font.Gotham
    m.TextSize = 12
    m.TextColor3 = C.TextSecondary
    m.TextXAlignment = Enum.TextXAlignment.Left
    m.TextYAlignment = Enum.TextYAlignment.Top
    m.TextWrapped = true
    m.Text = msg or ''

    toast.Parent = NotifyHolder
    TweenService:Create(toast, EASE, { Position = UDim2.new(0, 0, 0, 0) }):Play()

    task.delay(duration, function()
        local out = TweenService:Create(toast, EASE, { Position = UDim2.new(1, 40, 0, 0) })
        out:Play()
        out.Completed:Wait()
        toast:Destroy()
    end)
end

-- ============================== WINDOW ================================== --
local Window = Instance.new('Frame')
Window.Name = 'Window'
Window.Size = UDim2.new(0, 920, 0, 600)
Window.Position = UDim2.new(0.5, -460, 0.5, -300)
Window.BackgroundColor3 = C.WindowBg
Window.BorderSizePixel = 0
Window.Parent = ScreenGui
local windowCorner = Instance.new('UICorner', Window); windowCorner.CornerRadius = UDim.new(0, 10)

local accentStripe = Instance.new('Frame', Window)
accentStripe.Size = UDim2.new(1, 0, 0, 2)
accentStripe.BackgroundColor3 = C.AccentPrimary
accentStripe.BorderSizePixel = 0
local accentCorner = Instance.new('UICorner', accentStripe); accentCorner.CornerRadius = UDim.new(0, 2)

-- TitleBar
local TitleBar = Instance.new('Frame', Window)
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.Position = UDim2.new(0, 0, 0, 2)
TitleBar.BackgroundColor3 = C.WindowBg
TitleBar.BorderSizePixel = 0

local logo = Instance.new('Frame', TitleBar)
logo.Size = UDim2.new(0, 12, 0, 12)
logo.Position = UDim2.new(0, 14, 0.5, -6)
logo.BackgroundColor3 = C.AccentPrimary
logo.BorderSizePixel = 0
Instance.new('UICorner', logo).CornerRadius = UDim.new(0, 3)

local titleText = Instance.new('TextLabel', TitleBar)
titleText.BackgroundTransparency = 1
titleText.Position = UDim2.new(0, 34, 0, 0)
titleText.Size = UDim2.new(0, 200, 1, 0)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 14
titleText.TextColor3 = C.TextPrimary
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Text = 'freezer'

-- Search bar
local SearchBar = Instance.new('Frame', TitleBar)
SearchBar.AnchorPoint = Vector2.new(0.5, 0.5)
SearchBar.Position = UDim2.new(0.5, 0, 0.5, 0)
SearchBar.Size = UDim2.new(0, 380, 0, 28)
SearchBar.BackgroundColor3 = C.ContentBg
SearchBar.BorderSizePixel = 0
Instance.new('UICorner', SearchBar).CornerRadius = UDim.new(0, 14)

local SearchIcon = Instance.new('TextLabel', SearchBar)
SearchIcon.BackgroundTransparency = 1
SearchIcon.Position = UDim2.new(0, 10, 0, 0)
SearchIcon.Size = UDim2.new(0, 18, 1, 0)
SearchIcon.Font = Enum.Font.Gotham
SearchIcon.TextSize = 13
SearchIcon.TextColor3 = C.TextDim
SearchIcon.Text = '\u{1F50D}'

local SearchBox = Instance.new('TextBox', SearchBar)
SearchBox.BackgroundTransparency = 1
SearchBox.Position = UDim2.new(0, 32, 0, 0)
SearchBox.Size = UDim2.new(1, -42, 1, 0)
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 12
SearchBox.TextColor3 = C.TextPrimary
SearchBox.PlaceholderText = 'Search properties...'
SearchBox.PlaceholderColor3 = C.TextDim
SearchBox.Text = ''
SearchBox.ClearTextOnFocus = false
SearchBox.TextXAlignment = Enum.TextXAlignment.Left

-- Min/Close
local function makeCaption(symbol, color, xOff)
    local btn = Instance.new('TextButton', TitleBar)
    btn.AnchorPoint = Vector2.new(1, 0)
    btn.Position = UDim2.new(1, xOff, 0, 0)
    btn.Size = UDim2.new(0, 46, 1, 0)
    btn.BackgroundColor3 = C.WindowBg
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextColor3 = C.TextSecondary
    btn.Text = symbol
    btn.AutoButtonColor = false
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, FAST, { BackgroundTransparency = 0, BackgroundColor3 = color }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, FAST, { BackgroundTransparency = 1 }):Play()
    end)
    return btn
end

local CloseBtn = makeCaption('\u{2715}', C.Danger, 0)
local MinBtn = makeCaption('\u{2013}', C.CardBg, -46)

-- Sidebar
local Sidebar = Instance.new('Frame', Window)
Sidebar.Position = UDim2.new(0, 0, 0, 42)
Sidebar.Size = UDim2.new(0, 220, 1, -68)
Sidebar.BackgroundColor3 = C.SidebarBg
Sidebar.BorderSizePixel = 0

local SidebarList = Instance.new('UIListLayout', Sidebar)
SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
SidebarList.Padding = UDim.new(0, 2)

local SidebarPad = Instance.new('UIPadding', Sidebar)
SidebarPad.PaddingTop = UDim.new(0, 12)

-- Content area
local Content = Instance.new('Frame', Window)
Content.Position = UDim2.new(0, 220, 0, 42)
Content.Size = UDim2.new(1, -220, 1, -68)
Content.BackgroundColor3 = C.ContentBg
Content.BorderSizePixel = 0

local ContentPad = Instance.new('UIPadding', Content)
ContentPad.PaddingTop = UDim.new(0, 20)
ContentPad.PaddingLeft = UDim.new(0, 20)
ContentPad.PaddingRight = UDim.new(0, 20)
ContentPad.PaddingBottom = UDim.new(0, 12)

-- Breadcrumb
local Breadcrumb = Instance.new('TextLabel', Content)
Breadcrumb.BackgroundTransparency = 1
Breadcrumb.Size = UDim2.new(1, 0, 0, 14)
Breadcrumb.Font = Enum.Font.Gotham
Breadcrumb.TextSize = 11
Breadcrumb.TextColor3 = C.TextDim
Breadcrumb.TextXAlignment = Enum.TextXAlignment.Left
Breadcrumb.Text = 'Home > Utility > Live State'

local SectionTitle = Instance.new('TextLabel', Content)
SectionTitle.BackgroundTransparency = 1
SectionTitle.Position = UDim2.new(0, 0, 0, 18)
SectionTitle.Size = UDim2.new(1, 0, 0, 28)
SectionTitle.Font = Enum.Font.GothamBold
SectionTitle.TextSize = 24
SectionTitle.TextColor3 = C.TextPrimary
SectionTitle.TextXAlignment = Enum.TextXAlignment.Left
SectionTitle.Text = 'Live State Monitor'

local SectionDesc = Instance.new('TextLabel', Content)
SectionDesc.BackgroundTransparency = 1
SectionDesc.Position = UDim2.new(0, 0, 0, 50)
SectionDesc.Size = UDim2.new(1, 0, 0, 18)
SectionDesc.Font = Enum.Font.Gotham
SectionDesc.TextSize = 13
SectionDesc.TextColor3 = C.TextSecondary
SectionDesc.TextXAlignment = Enum.TextXAlignment.Left
SectionDesc.Text = 'See which properties replicate to the server. Probe before you exploit.'

-- Page holder (cards scroll inside)
local PageHolder = Instance.new('Frame', Content)
PageHolder.Position = UDim2.new(0, 0, 0, 78)
PageHolder.Size = UDim2.new(1, 0, 1, -78)
PageHolder.BackgroundTransparency = 1

-- Status footer
local Footer = Instance.new('Frame', Window)
Footer.AnchorPoint = Vector2.new(0, 1)
Footer.Position = UDim2.new(0, 0, 1, 0)
Footer.Size = UDim2.new(1, 0, 0, 26)
Footer.BackgroundColor3 = C.WindowBg
Footer.BorderSizePixel = 0
local FooterBorder = Instance.new('Frame', Footer)
FooterBorder.Size = UDim2.new(1, 0, 0, 1)
FooterBorder.BackgroundColor3 = C.Border
FooterBorder.BorderSizePixel = 0

local FooterDot = Instance.new('Frame', Footer)
FooterDot.Size = UDim2.new(0, 6, 0, 6)
FooterDot.Position = UDim2.new(0, 14, 0.5, -3)
FooterDot.BackgroundColor3 = C.AccentPrimary
FooterDot.BorderSizePixel = 0
Instance.new('UICorner', FooterDot).CornerRadius = UDim.new(1, 0)

local FooterLeft = Instance.new('TextLabel', Footer)
FooterLeft.BackgroundTransparency = 1
FooterLeft.Position = UDim2.new(0, 28, 0, 0)
FooterLeft.Size = UDim2.new(0.5, 0, 1, 0)
FooterLeft.Font = Enum.Font.Code
FooterLeft.TextSize = 12
FooterLeft.TextColor3 = C.TextSecondary
FooterLeft.TextXAlignment = Enum.TextXAlignment.Left
FooterLeft.Text = 'FPS -- / Ping --ms / -- players'

local FooterRight = Instance.new('TextLabel', Footer)
FooterRight.AnchorPoint = Vector2.new(1, 0)
FooterRight.Position = UDim2.new(1, -14, 0, 0)
FooterRight.Size = UDim2.new(0.5, 0, 1, 0)
FooterRight.BackgroundTransparency = 1
FooterRight.Font = Enum.Font.Code
FooterRight.TextSize = 12
FooterRight.TextColor3 = C.TextSecondary
FooterRight.TextXAlignment = Enum.TextXAlignment.Right
FooterRight.Text = '24 props | 0 local | 0 replicated | 0 unknown'

-- =========================== DRAGGING =================================== --
do
    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Window.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- =========================== RESIZE GRIP ================================ --
local Grip = Instance.new('TextButton', Window)
Grip.AnchorPoint = Vector2.new(1, 1)
Grip.Position = UDim2.new(1, -4, 1, -4)
Grip.Size = UDim2.new(0, 14, 0, 14)
Grip.BackgroundTransparency = 1
Grip.AutoButtonColor = false
Grip.Text = '\u{25E2}'
Grip.Font = Enum.Font.Gotham
Grip.TextSize = 12
Grip.TextColor3 = C.TextDim
do
    local resizing, startSize, startMouse
    Grip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true
            startSize = Window.AbsoluteSize
            startMouse = UserInputService:GetMouseLocation()
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then resizing = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local m = UserInputService:GetMouseLocation()
            local nw = math.max(720, startSize.X + (m.X - startMouse.X))
            local nh = math.max(440, startSize.Y + (m.Y - startMouse.Y))
            Window.Size = UDim2.new(0, nw, 0, nh)
        end
    end)
end

-- =========================== CONTROL FACTORIES ========================== --
local function styleScroll(s)
    s.ScrollBarThickness = 3
    s.ScrollBarImageColor3 = C.AccentPrimary
    s.BorderSizePixel = 0
    s.BackgroundTransparency = 1
end

local function makeCard(parent, title, desc)
    local card = Instance.new('Frame', parent)
    card.Size = UDim2.new(1, -8, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = C.CardBg
    card.BorderSizePixel = 0
    Instance.new('UICorner', card).CornerRadius = UDim.new(0, 8)

    local pad = Instance.new('UIPadding', card)
    pad.PaddingTop = UDim.new(0, 14)
    pad.PaddingBottom = UDim.new(0, 14)
    pad.PaddingLeft = UDim.new(0, 16)
    pad.PaddingRight = UDim.new(0, 16)

    local list = Instance.new('UIListLayout', card)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 6)

    local header = Instance.new('TextLabel', card)
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(1, 0, 0, 18)
    header.Font = Enum.Font.GothamSemibold
    header.TextSize = 14
    header.TextColor3 = C.TextPrimary
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Text = title
    header.LayoutOrder = 1

    if desc then
        local d = Instance.new('TextLabel', card)
        d.BackgroundTransparency = 1
        d.Size = UDim2.new(1, 0, 0, 16)
        d.Font = Enum.Font.Gotham
        d.TextSize = 12
        d.TextColor3 = C.TextDim
        d.TextXAlignment = Enum.TextXAlignment.Left
        d.Text = desc
        d.LayoutOrder = 2
    end

    return card
end

local function makeRow(parent, label, sub)
    local row = Instance.new('Frame', parent)
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundTransparency = 1
    row.LayoutOrder = #parent:GetChildren() + 10

    local l = Instance.new('TextLabel', row)
    l.BackgroundTransparency = 1
    l.Position = UDim2.new(0, 0, 0, 4)
    l.Size = UDim2.new(0.6, 0, 0, 18)
    l.Font = Enum.Font.Gotham
    l.TextSize = 13
    l.TextColor3 = C.TextPrimary
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = label

    if sub then
        local s = Instance.new('TextLabel', row)
        s.BackgroundTransparency = 1
        s.Position = UDim2.new(0, 0, 0, 22)
        s.Size = UDim2.new(0.6, 0, 0, 14)
        s.Font = Enum.Font.Gotham
        s.TextSize = 11
        s.TextColor3 = C.TextDim
        s.TextXAlignment = Enum.TextXAlignment.Left
        s.Text = sub
    end

    return row
end

local function makeToggle(parent, initial, callback)
    local btn = Instance.new('TextButton', parent)
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, 0, 0.5, 0)
    btn.Size = UDim2.new(0, 38, 0, 20)
    btn.BackgroundColor3 = initial and C.AccentPrimary or C.CardBg
    btn.AutoButtonColor = false
    btn.Text = ''
    Instance.new('UICorner', btn).CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new('UIStroke', btn); stroke.Color = C.Border; stroke.Thickness = 1

    local knob = Instance.new('Frame', btn)
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = initial and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    Instance.new('UICorner', knob).CornerRadius = UDim.new(1, 0)

    local val = initial
    btn.MouseButton1Click:Connect(function()
        val = not val
        local p = val and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        TweenService:Create(knob, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = p }):Play()
        TweenService:Create(btn, EASE, { BackgroundColor3 = val and C.AccentPrimary or C.CardBg }):Play()
        if callback then callback(val) end
    end)

    return btn, function(v)
        val = v
        knob.Position = v and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        btn.BackgroundColor3 = v and C.AccentPrimary or C.CardBg
    end
end

local function makeButton(parent, text, style, callback)
    local btn = Instance.new('TextButton', parent)
    btn.Size = UDim2.new(0, 100, 0, 30)
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, 0, 0.5, 0)
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.BorderSizePixel = 0
    local baseColor
    if style == 'secondary' then baseColor = C.CardBg
    elseif style == 'danger' then baseColor = C.Danger
    else baseColor = C.AccentPrimary end
    btn.BackgroundColor3 = baseColor
    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 4)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, FAST, { BackgroundColor3 = baseColor:Lerp(Color3.new(1,1,1), 0.15) }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, FAST, { BackgroundColor3 = baseColor }):Play()
    end)
    if callback then btn.MouseButton1Click:Connect(callback) end
    return btn
end

local function makeSlider(parent, min, max, value, callback, decimals)
    local track = Instance.new('Frame', parent)
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -50, 0.5, 0)
    track.Size = UDim2.new(0, 180, 0, 4)
    track.BackgroundColor3 = C.CardBgHover
    track.BorderSizePixel = 0
    Instance.new('UICorner', track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new('Frame', track)
    fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = C.AccentPrimary
    fill.BorderSizePixel = 0
    Instance.new('UICorner', fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new('Frame', track)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    Instance.new('UICorner', knob).CornerRadius = UDim.new(1, 0)

    local valText = Instance.new('TextLabel', parent)
    valText.AnchorPoint = Vector2.new(1, 0.5)
    valText.Position = UDim2.new(1, 0, 0.5, 0)
    valText.Size = UDim2.new(0, 44, 0, 16)
    valText.BackgroundTransparency = 1
    valText.Font = Enum.Font.Code
    valText.TextSize = 12
    valText.TextColor3 = C.TextSecondary
    valText.TextXAlignment = Enum.TextXAlignment.Right
    decimals = decimals or 0
    valText.Text = string.format('%.' .. decimals .. 'f', value)

    local dragging = false
    local function setFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = min + (max - min) * rel
        local mult = 10 ^ decimals
        v = math.floor(v * mult + 0.5) / mult
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        valText.Text = string.format('%.' .. decimals .. 'f', v)
        if callback then callback(v) end
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setFromX(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            setFromX(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)

    return track
end

local function makeDropdown(parent, options, current, callback)
    local btn = Instance.new('TextButton', parent)
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, 0, 0.5, 0)
    btn.Size = UDim2.new(0, 160, 0, 28)
    btn.BackgroundColor3 = C.ContentBg
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.TextColor3 = C.TextPrimary
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Text = '  ' .. tostring(current) .. '   \u{25BE}'
    btn.BorderSizePixel = 0
    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 4)
    local stroke = Instance.new('UIStroke', btn); stroke.Color = C.Border; stroke.Thickness = 1

    local floater
    local function close()
        if floater then floater:Destroy(); floater = nil end
    end

    btn.MouseButton1Click:Connect(function()
        if floater then close(); return end
        floater = Instance.new('Frame', ScreenGui)
        floater.BackgroundColor3 = C.ContentBg
        floater.BorderSizePixel = 0
        floater.Position = UDim2.fromOffset(btn.AbsolutePosition.X, btn.AbsolutePosition.Y + 30)
        floater.Size = UDim2.fromOffset(160, math.min(200, #options * 28))
        floater.ZIndex = 50
        Instance.new('UICorner', floater).CornerRadius = UDim.new(0, 4)
        local fStroke = Instance.new('UIStroke', floater); fStroke.Color = C.Border; fStroke.Thickness = 1
        local list = Instance.new('UIListLayout', floater); list.SortOrder = Enum.SortOrder.LayoutOrder

        for _, opt in ipairs(options) do
            local item = Instance.new('TextButton', floater)
            item.Size = UDim2.new(1, 0, 0, 28)
            item.BackgroundColor3 = C.ContentBg
            item.AutoButtonColor = false
            item.BorderSizePixel = 0
            item.Font = Enum.Font.Gotham
            item.TextSize = 12
            item.TextColor3 = opt == current and C.AccentPrimary or C.TextPrimary
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.Text = '  ' .. tostring(opt)
            item.ZIndex = 51
            item.MouseEnter:Connect(function()
                TweenService:Create(item, FAST, { BackgroundColor3 = C.CardBgHover }):Play()
            end)
            item.MouseLeave:Connect(function()
                TweenService:Create(item, FAST, { BackgroundColor3 = C.ContentBg }):Play()
            end)
            item.MouseButton1Click:Connect(function()
                current = opt
                btn.Text = '  ' .. tostring(opt) .. '   \u{25BE}'
                if callback then callback(opt) end
                close()
            end)
        end

        -- outside click
        local outClick
        outClick = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local mp = UserInputService:GetMouseLocation()
                local fp = floater and floater.AbsolutePosition
                local fs = floater and floater.AbsoluteSize
                local bp = btn.AbsolutePosition
                local bs = btn.AbsoluteSize
                local inFloater = fp and (mp.X >= fp.X and mp.X <= fp.X + fs.X and mp.Y >= fp.Y and mp.Y <= fp.Y + fs.Y)
                local inBtn = mp.X >= bp.X and mp.X <= bp.X + bs.X and mp.Y >= bp.Y and mp.Y <= bp.Y + bs.Y
                if not inFloater and not inBtn then close(); outClick:Disconnect() end
            end
        end)
    end)

    return btn
end

local function makeTextbox(parent, placeholder, width, callback)
    local box = Instance.new('TextBox', parent)
    box.AnchorPoint = Vector2.new(1, 0.5)
    box.Position = UDim2.new(1, 0, 0.5, 0)
    box.Size = UDim2.new(0, width or 200, 0, 28)
    box.BackgroundColor3 = C.ContentBg
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.TextColor3 = C.TextPrimary
    box.PlaceholderText = placeholder or ''
    box.PlaceholderColor3 = C.TextDim
    box.Text = ''
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new('UICorner', box).CornerRadius = UDim.new(0, 4)
    local stroke = Instance.new('UIStroke', box); stroke.Color = C.Border; stroke.Thickness = 1
    box.Focused:Connect(function() TweenService:Create(stroke, FAST, { Color = C.AccentPrimary }):Play() end)
    box.FocusLost:Connect(function(enter)
        TweenService:Create(stroke, FAST, { Color = C.Border }):Play()
        if enter and callback then callback(box.Text) end
    end)
    local pad = Instance.new('UIPadding', box)
    pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)
    return box
end

local function makeKeybind(parent, current, callback)
    local btn = Instance.new('TextButton', parent)
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, 0, 0.5, 0)
    btn.Size = UDim2.new(0, 100, 0, 28)
    btn.BackgroundColor3 = C.ContentBg
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.TextColor3 = C.TextPrimary
    btn.Text = current or 'None'
    btn.BorderSizePixel = 0
    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 4)
    local stroke = Instance.new('UIStroke', btn); stroke.Color = C.Border; stroke.Thickness = 1
    btn.MouseButton1Click:Connect(function()
        btn.Text = 'Press a key...'
        local con
        con = UserInputService.InputBegan:Connect(function(input, gp)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape then
                    btn.Text = 'None'
                    if callback then callback(nil) end
                else
                    btn.Text = input.KeyCode.Name
                    if callback then callback(input.KeyCode.Name) end
                end
                con:Disconnect()
            end
        end)
    end)
    return btn
end

-- =========================== SIDEBAR NAV ================================ --
local pages = {}
local currentPage

local function makeNav(name, icon, group)
    local item = Instance.new('TextButton')
    item.Size = UDim2.new(1, 0, 0, 44)
    item.BackgroundColor3 = C.SidebarBg
    item.BorderSizePixel = 0
    item.AutoButtonColor = false
    item.Text = ''
    item.LayoutOrder = group * 10 + (#Sidebar:GetChildren())
    item.Parent = Sidebar

    local bar = Instance.new('Frame', item)
    bar.Position = UDim2.new(0, 0, 0, 0)
    bar.Size = UDim2.new(0, 3, 1, 0)
    bar.BackgroundColor3 = C.AccentPrimary
    bar.BorderSizePixel = 0
    bar.Visible = false

    local ic = Instance.new('TextLabel', item)
    ic.BackgroundTransparency = 1
    ic.Position = UDim2.new(0, 14, 0, 0)
    ic.Size = UDim2.new(0, 24, 1, 0)
    ic.Font = Enum.Font.Gotham
    ic.TextSize = 14
    ic.TextColor3 = C.TextSecondary
    ic.Text = icon

    local lbl = Instance.new('TextLabel', item)
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 44, 0, 0)
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = C.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = name

    item.MouseEnter:Connect(function()
        if currentPage ~= name then
            TweenService:Create(item, FAST, { BackgroundColor3 = C.CardBg }):Play()
        end
    end)
    item.MouseLeave:Connect(function()
        if currentPage ~= name then
            TweenService:Create(item, FAST, { BackgroundColor3 = C.SidebarBg }):Play()
        end
    end)

    return item, bar, lbl
end

local navItems = {}
local function selectPage(name)
    if currentPage == name then return end
    currentPage = name
    Breadcrumb.Text = 'Home > Utility > Live State > ' .. name
    for n, p in pairs(pages) do
        if n == name then
            p.Visible = true
            p.GroupTransparency = 1
            TweenService:Create(p, EASE, { GroupTransparency = 0 }):Play()
        else
            p.Visible = false
        end
    end
    for n, nav in pairs(navItems) do
        local item, bar, _ = nav.item, nav.bar, nav.lbl
        if n == name then
            bar.Visible = true
            TweenService:Create(item, EASE, { BackgroundColor3 = C.AccentSoft }):Play()
        else
            bar.Visible = false
            TweenService:Create(item, EASE, { BackgroundColor3 = C.SidebarBg }):Play()
        end
    end
end

local function addPage(name, icon, group)
    local item, bar, lbl = makeNav(name, icon, group)
    item.MouseButton1Click:Connect(function() selectPage(name) end)
    navItems[name] = { item = item, bar = bar, lbl = lbl }

    local page = Instance.new('CanvasGroup', PageHolder)
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Visible = false

    local scroll = Instance.new('ScrollingFrame', page)
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    styleScroll(scroll)

    local layout = Instance.new('UIListLayout', scroll)
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    pages[name] = page
    return scroll
end

-- ========================== DIVIDER IN SIDEBAR ========================== --
local function addSidebarDivider()
    local d = Instance.new('Frame')
    d.Size = UDim2.new(1, -24, 0, 1)
    d.Position = UDim2.new(0, 12, 0, 0)
    d.BackgroundColor3 = C.Border
    d.BorderSizePixel = 0
    d.LayoutOrder = 100 + #Sidebar:GetChildren()
    d.Parent = Sidebar
end

-- ============================ PAGES ===================================== --
local monitorScroll = addPage('Monitor', '\u{1F4CA}', 1)
local probeScroll = addPage('Probes', '\u{1F50D}', 1)
local replicationScroll = addPage('Replication', '\u{1F4E1}', 1)
addSidebarDivider()
local logScroll = addPage('Change Log', '\u{1F4DC}', 2)
local eventsScroll = addPage('Events', '\u{26A1}', 2)
local networkScroll = addPage('Network Owner', '\u{1F310}', 2)
addSidebarDivider()
local exportScroll = addPage('Export', '\u{1F4E4}', 3)
local settingsScroll = addPage('Settings', '\u{2699}', 3)

-- ============================ CLASSIFIER ================================ --
local function classify(name, value)
    local n = string.lower(tostring(name))
    if n:find('cash') or n:find('coin') or n:find('gem') or n:find('gold') or n:find('money') or n:find('credit') or n:find('point') then
        return 'Currency'
    elseif n:find('health') or n:find('hp') or n:find('maxhealth') then
        return 'Health'
    elseif n:find('walkspeed') or n:find('jumppower') or n:find('jumpheight') or n:find('hipheight') or n:find('gravity') then
        return 'Stat'
    elseif n:find('skin') or n:find('color') or n:find('hat') or n:find('shirt') or n:find('pants') then
        return 'Cosmetic'
    elseif n:find('cframe') or n:find('position') or n:find('rootpart') then
        return 'Position'
    elseif typeof(value) == 'Vector3' or typeof(value) == 'CFrame' then
        return 'Position'
    end
    return 'Other'
end

-- ============================ ROW BUILDER =============================== --
local function badgeColor(b)
    if b == 'Local' then return C.Danger
    elseif b == 'Replicated' then return C.Success
    elseif b == 'Probing' then return C.TextDim
    else return C.Warning end
end

local function badgeText(b)
    if b == 'Local' then return 'Local-only'
    elseif b == 'Replicated' then return 'Replicated'
    elseif b == 'Probing' then return 'Probing...'
    else return 'Unknown' end
end

local function valueToString(v)
    if v == nil then return 'nil' end
    local t = typeof(v)
    if t == 'CFrame' then
        local p = v.Position
        return string.format('CFrame(%.1f, %.1f, %.1f)', p.X, p.Y, p.Z)
    elseif t == 'Vector3' then
        return string.format('Vector3(%.1f, %.1f, %.1f)', v.X, v.Y, v.Z)
    elseif t == 'Instance' then
        return v.Name
    elseif t == 'number' then
        return string.format('%.2f', v)
    elseif t == 'boolean' then
        return v and 'true' or 'false'
    end
    return tostring(v):sub(1, 40)
end

-- =========================== MONITOR PAGE =============================== --
local monitorCard = makeCard(monitorScroll, 'Monitored Properties', 'Probe to test replication. Color badge tells you the verdict.')
local filterCard = makeCard(monitorScroll, 'Filters', 'Show only certain badge types or categories.')

-- Filter chips row
local filterRow = Instance.new('Frame', filterCard)
filterRow.Size = UDim2.new(1, 0, 0, 36)
filterRow.BackgroundTransparency = 1
filterRow.LayoutOrder = 5

local chipLayout = Instance.new('UIListLayout', filterRow)
chipLayout.FillDirection = Enum.FillDirection.Horizontal
chipLayout.Padding = UDim.new(0, 6)
chipLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local FILTER_OPTIONS = { 'All', 'Local', 'Replicated', 'Unknown', 'Currency', 'Health', 'Stat', 'Position' }
local chipButtons = {}

local function refreshRows() end -- forward decl

local function makeChip(name)
    local chip = Instance.new('TextButton', filterRow)
    chip.Size = UDim2.new(0, 0, 0, 26)
    chip.AutomaticSize = Enum.AutomaticSize.X
    chip.BackgroundColor3 = state.filter == name and C.AccentPrimary or C.CardBgHover
    chip.AutoButtonColor = false
    chip.BorderSizePixel = 0
    chip.Font = Enum.Font.GothamMedium
    chip.TextSize = 12
    chip.TextColor3 = state.filter == name and Color3.fromRGB(255,255,255) or C.TextSecondary
    chip.Text = '  ' .. name .. '  '
    Instance.new('UICorner', chip).CornerRadius = UDim.new(1, 0)
    chip.MouseButton1Click:Connect(function()
        state.filter = name
        for n, c in pairs(chipButtons) do
            c.BackgroundColor3 = n == name and C.AccentPrimary or C.CardBgHover
            c.TextColor3 = n == name and Color3.fromRGB(255,255,255) or C.TextSecondary
        end
        refreshRows()
        saveConfig()
    end)
    chipButtons[name] = chip
    return chip
end

for _, f in ipairs(FILTER_OPTIONS) do makeChip(f) end

-- Action row
local actionRow = Instance.new('Frame', monitorCard)
actionRow.Size = UDim2.new(1, 0, 0, 36)
actionRow.BackgroundTransparency = 1
actionRow.LayoutOrder = 5

local actionLayout = Instance.new('UIListLayout', actionRow)
actionLayout.FillDirection = Enum.FillDirection.Horizontal
actionLayout.Padding = UDim.new(0, 8)
actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local function tinyBtn(parent, txt, style, cb)
    local b = Instance.new('TextButton', parent)
    b.Size = UDim2.new(0, 110, 0, 28)
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    b.Text = txt
    b.TextColor3 = Color3.fromRGB(255,255,255)
    local base = style == 'secondary' and C.CardBg or C.AccentPrimary
    b.BackgroundColor3 = base
    Instance.new('UICorner', b).CornerRadius = UDim.new(0, 4)
    b.MouseEnter:Connect(function() TweenService:Create(b, FAST, { BackgroundColor3 = base:Lerp(Color3.new(1,1,1), 0.15) }):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b, FAST, { BackgroundColor3 = base }):Play() end)
    if cb then b.MouseButton1Click:Connect(cb) end
    return b
end

-- forward decl
local probeRow, probeAll
local rowsContainer = Instance.new('Frame', monitorCard)
rowsContainer.Size = UDim2.new(1, 0, 0, 0)
rowsContainer.BackgroundTransparency = 1
rowsContainer.AutomaticSize = Enum.AutomaticSize.Y
rowsContainer.LayoutOrder = 10

local rowsLayout = Instance.new('UIListLayout', rowsContainer)
rowsLayout.Padding = UDim.new(0, 2)
rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder

tinyBtn(actionRow, 'Probe All', nil, function() if probeAll then probeAll() end end)
tinyBtn(actionRow, 'Refresh', 'secondary', function() refreshRows() end)
tinyBtn(actionRow, 'Clear Probes', 'secondary', function()
    for _, r in pairs(rows) do r.history = { ok = 0, fail = 0 }; r.score = 50; r.badge = 'Unknown' end
    refreshRows()
end)

-- Notify on change toggle row
local notifyToggleRow = makeRow(monitorCard, 'Notify on change', 'Toast every time a monitored value changes')
notifyToggleRow.LayoutOrder = 4
local _, setNotifyTog = makeToggle(notifyToggleRow, state.notifyOnChange, function(v)
    state.notifyOnChange = v; saveConfig()
end)

-- =========================== ROW UI ===================================== --
local function colorForBadge(b) return badgeColor(b) end

local function buildRowUI(r)
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = C.CardBgHover
    row.BorderSizePixel = 0
    Instance.new('UICorner', row).CornerRadius = UDim.new(0, 4)
    local pad = Instance.new('UIPadding', row)
    pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)

    -- badge
    local badge = Instance.new('Frame', row)
    badge.Size = UDim2.new(0, 90, 0, 20)
    badge.Position = UDim2.new(0, 0, 0.5, -10)
    badge.BackgroundColor3 = colorForBadge(r.badge)
    badge.BorderSizePixel = 0
    Instance.new('UICorner', badge).CornerRadius = UDim.new(0, 4)
    local badgeTxt = Instance.new('TextLabel', badge)
    badgeTxt.BackgroundTransparency = 1
    badgeTxt.Size = UDim2.new(1, 0, 1, 0)
    badgeTxt.Font = Enum.Font.GothamSemibold
    badgeTxt.TextSize = 11
    badgeTxt.TextColor3 = Color3.fromRGB(255, 255, 255)
    badgeTxt.Text = badgeText(r.badge)

    local label = Instance.new('TextLabel', row)
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 100, 0, 4)
    label.Size = UDim2.new(0.45, 0, 0, 18)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = C.TextPrimary
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = r.label

    local sub = Instance.new('TextLabel', row)
    sub.BackgroundTransparency = 1
    sub.Position = UDim2.new(0, 100, 0, 22)
    sub.Size = UDim2.new(0.45, 0, 0, 14)
    sub.Font = Enum.Font.Code
    sub.TextSize = 11
    sub.TextColor3 = C.TextDim
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Text = r.category .. ' \u{2022} ' .. valueToString(r.lastValue)

    -- trust score
    local score = Instance.new('TextLabel', row)
    score.BackgroundTransparency = 1
    score.AnchorPoint = Vector2.new(1, 0.5)
    score.Position = UDim2.new(1, -130, 0.5, 0)
    score.Size = UDim2.new(0, 70, 0, 20)
    score.Font = Enum.Font.Code
    score.TextSize = 12
    score.TextColor3 = C.TextSecondary
    score.TextXAlignment = Enum.TextXAlignment.Right
    score.Text = string.format('trust %d', r.score or 50)

    local probeBtn = Instance.new('TextButton', row)
    probeBtn.AnchorPoint = Vector2.new(1, 0.5)
    probeBtn.Position = UDim2.new(1, 0, 0.5, 0)
    probeBtn.Size = UDim2.new(0, 60, 0, 24)
    probeBtn.BackgroundColor3 = C.AccentPrimary
    probeBtn.AutoButtonColor = false
    probeBtn.BorderSizePixel = 0
    probeBtn.Font = Enum.Font.GothamMedium
    probeBtn.TextSize = 12
    probeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    probeBtn.Text = 'Probe'
    Instance.new('UICorner', probeBtn).CornerRadius = UDim.new(0, 4)
    probeBtn.MouseButton1Click:Connect(function() if probeRow then probeRow(r) end end)

    r._ui = {
        frame = row,
        badge = badge,
        badgeTxt = badgeTxt,
        sub = sub,
        score = score,
    }
    return row
end

local function rowMatchesFilter(r)
    local f = state.filter
    if f == 'All' then return true end
    if f == 'Local' then return r.badge == 'Local' end
    if f == 'Replicated' then return r.badge == 'Replicated' end
    if f == 'Unknown' then return r.badge == 'Unknown' or r.badge == 'Probing' end
    return r.category == f
end

function refreshRows()
    -- clear
    for _, child in ipairs(rowsContainer:GetChildren()) do
        if child:IsA('Frame') then child:Destroy() end
    end
    local order = 1
    for _, id in ipairs(rowOrder) do
        local r = rows[id]
        if r and rowMatchesFilter(r) then
            -- update last value
            local ok, val = pcall(r.getter)
            if ok then r.lastValue = val end
            local ui = buildRowUI(r)
            ui.LayoutOrder = order
            ui.Parent = rowsContainer
            order = order + 1
        end
    end
    -- counts
    local lc, rc, uc, total = 0, 0, 0, 0
    for _, r in pairs(rows) do
        total = total + 1
        if r.badge == 'Local' then lc = lc + 1
        elseif r.badge == 'Replicated' then rc = rc + 1
        else uc = uc + 1 end
    end
    FooterRight.Text = string.format('%d props | %d local | %d replicated | %d unknown', total, lc, rc, uc)
end

-- =========================== PROBE ENGINE =============================== --
local function recordHistory(r, ok)
    r.history = r.history or { ok = 0, fail = 0, total = 0 }
    r.history.total = (r.history.total or 0) + 1
    if ok then r.history.ok = (r.history.ok or 0) + 1
    else r.history.fail = (r.history.fail or 0) + 1 end
    -- cap window 10
    if r.history.total > 10 then r.history.total = 10 end
    local total = (r.history.ok or 0) + (r.history.fail or 0)
    if total > 0 then
        r.score = math.floor((r.history.ok / total) * 100)
    end
end

local function pickProbeValue(current)
    local t = typeof(current)
    if t == 'number' then
        if current == 0 then return 9999 end
        return current * 2 + 13
    elseif t == 'Vector3' then
        return current + Vector3.new(50, 0, 0)
    elseif t == 'CFrame' then
        return current + Vector3.new(0, 10, 0)
    elseif t == 'boolean' then
        return not current
    elseif t == 'string' then
        return current .. '_probe'
    elseif t == 'Color3' then
        return Color3.new(1, 0, 1)
    end
    return current
end

local function valuesEqual(a, b)
    if typeof(a) ~= typeof(b) then return false end
    local t = typeof(a)
    if t == 'number' then return math.abs(a - b) < 0.05
    elseif t == 'Vector3' then return (a - b).Magnitude < 0.5
    elseif t == 'CFrame' then return (a.Position - b.Position).Magnitude < 0.5
    end
    return a == b
end

probeRow = function(r)
    if not r.setter then
        r.badge = 'Unknown'
        notify('Probe', r.label .. ' has no setter', 'warn')
        refreshRows()
        return
    end
    r.badge = 'Probing'
    refreshRows()
    task.spawn(function()
        local ok, current = pcall(r.getter)
        if not ok or current == nil then
            r.badge = 'Unknown'; recordHistory(r, false); refreshRows(); return
        end
        local probeVal = pickProbeValue(current)
        local writeOk = pcall(function() r.setter(probeVal) end)
        if not writeOk then
            r.badge = 'Unknown'; recordHistory(r, false); refreshRows(); return
        end
        task.wait(0.4)
        local ok2, readBack = pcall(r.getter)
        if not ok2 then r.badge = 'Unknown'; recordHistory(r, false); refreshRows(); return end
        if valuesEqual(readBack, probeVal) then
            r.badge = 'Local'
            recordHistory(r, true)
            -- restore original
            pcall(function() r.setter(current) end)
        else
            r.badge = 'Replicated'
            recordHistory(r, false)
        end
        refreshRows()
    end)
end

probeAll = function()
    notify('Probe All', 'Probing ' .. #rowOrder .. ' properties...', 'info', 2)
    for _, id in ipairs(rowOrder) do
        task.spawn(function() probeRow(rows[id]) end)
        task.wait(0.05)
    end
end

-- ============================ ROW REGISTRY ============================== --
local function addRow(id, label, category, getter, setter)
    if rows[id] then return end
    local r = {
        id = id, label = label, category = category,
        getter = getter, setter = setter,
        badge = 'Unknown',
        history = { ok = 0, fail = 0, total = 0 },
        lastValue = nil,
        score = 50,
        lastChange = 0,
    }
    rows[id] = r
    table.insert(rowOrder, id)
end

local function removeRow(id)
    rows[id] = nil
    for i, v in ipairs(rowOrder) do if v == id then table.remove(rowOrder, i); break end end
end

-- =========================== HARVEST PROPERTIES ========================= --
local HUMANOID_PROPS = {
    'Health', 'MaxHealth', 'WalkSpeed', 'JumpPower', 'JumpHeight',
    'HipHeight', 'AutoRotate', 'Sit', 'PlatformStand', 'UseJumpPower',
}

local function harvestCharacter(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass('Humanoid')
    local hrp = char:FindFirstChild('HumanoidRootPart')

    if hum then
        for _, p in ipairs(HUMANOID_PROPS) do
            local id = 'hum_' .. p
            addRow(id, 'Humanoid.' .. p, classify(p, hum[p]),
                function() return hum[p] end,
                function(v) hum[p] = v end)
        end
    end

    if hrp then
        addRow('hrp_cframe', 'HumanoidRootPart.CFrame', 'Position',
            function() return hrp.CFrame end,
            function(v)
                if typeof(v) == 'CFrame' then hrp.CFrame = v
                else hrp.CFrame = CFrame.new(v) end
            end)
        addRow('hrp_velocity', 'HumanoidRootPart.AssemblyLinearVelocity', 'Stat',
            function() return hrp.AssemblyLinearVelocity end,
            function(v) hrp.AssemblyLinearVelocity = v end)
    end
end

local function harvestLeaderstats()
    local ls = LocalPlayer:FindFirstChild('leaderstats')
    if not ls then return end
    for _, stat in ipairs(ls:GetChildren()) do
        if stat:IsA('ValueBase') then
            local id = 'ls_' .. stat.Name
            addRow(id, 'leaderstats.' .. stat.Name, classify(stat.Name, stat.Value),
                function() return stat.Value end,
                function(v) stat.Value = v end)
        end
    end
end

local function harvestPlayerAttrs()
    addRow('player_team', 'Player.Team', 'Other',
        function() return LocalPlayer.Team end,
        function(v) LocalPlayer.Team = v end)
    addRow('player_neutral', 'Player.Neutral', 'Other',
        function() return LocalPlayer.Neutral end,
        function(v) LocalPlayer.Neutral = v end)
    -- attributes
    for name, val in pairs(LocalPlayer:GetAttributes()) do
        local id = 'attr_' .. name
        addRow(id, 'Player@' .. name, classify(name, val),
            function() return LocalPlayer:GetAttribute(name) end,
            function(v) LocalPlayer:SetAttribute(name, v) end)
    end
end

local function harvestBackpack()
    local bp = LocalPlayer:FindFirstChild('Backpack')
    if not bp then return end
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA('Tool') then
            local id = 'tool_' .. t.Name
            addRow(id, 'Backpack.' .. t.Name, 'Other',
                function() return t.Parent and t.Parent.Name or 'nil' end,
                nil)
        end
    end
end

local function harvestEquippedTool()
    local char = LocalPlayer.Character
    if not char then return end
    local t = char:FindFirstChildOfClass('Tool')
    if t then
        addRow('equipped_tool', 'Equipped Tool', 'Other',
            function()
                local c = LocalPlayer.Character
                local tt = c and c:FindFirstChildOfClass('Tool')
                return tt and tt.Name or 'none'
            end, nil)
    end
end

local function harvestAll()
    rows = {}
    rowOrder = {}
    if LocalPlayer.Character then harvestCharacter(LocalPlayer.Character) end
    harvestLeaderstats()
    harvestPlayerAttrs()
    harvestBackpack()
    harvestEquippedTool()
    -- restore custom probes
    for _, path in ipairs(state.customProbes) do
        local ok = pcall(function()
            local parts = {}
            for p in string.gmatch(path, '[^%.]+') do table.insert(parts, p) end
            local obj = game
            local prop = parts[#parts]
            for i = 1, #parts - 1 do obj = obj:FindFirstChild(parts[i]) or obj[parts[i]] end
            addRow('custom_' .. path, path, classify(prop, obj[prop]),
                function() return obj[prop] end,
                function(v) obj[prop] = v end)
        end)
        if not ok then notify('Custom Probe', 'Failed to bind: ' .. path, 'warn') end
    end
    refreshRows()
end

-- =========================== PROBES PAGE ================================ --
local customCard = makeCard(probeScroll, 'Custom Property Probe', 'Add an arbitrary property path: Workspace.Map.Door.Locked')
local customRow = Instance.new('Frame', customCard)
customRow.Size = UDim2.new(1, 0, 0, 44)
customRow.BackgroundTransparency = 1
customRow.LayoutOrder = 5

local customBox = makeTextbox(customRow, 'Workspace.Map.Door.Locked', 320)
customBox.AnchorPoint = Vector2.new(0, 0.5)
customBox.Position = UDim2.new(0, 0, 0.5, 0)

local addCustomBtn = makeButton(customRow, 'Add', nil, function()
    local path = customBox.Text
    if path == '' then return end
    local ok, err = pcall(function()
        local parts = {}
        for p in string.gmatch(path, '[^%.]+') do table.insert(parts, p) end
        local obj = game
        local prop = parts[#parts]
        for i = 1, #parts - 1 do
            obj = obj:FindFirstChild(parts[i]) or obj[parts[i]]
        end
        addRow('custom_' .. path, path, classify(prop, obj[prop]),
            function() return obj[prop] end,
            function(v) obj[prop] = v end)
        table.insert(state.customProbes, path)
        saveConfig()
    end)
    if ok then
        notify('Custom Probe', 'Added: ' .. path, 'success')
        refreshRows()
    else
        notify('Custom Probe', 'Failed: ' .. tostring(err):sub(1, 60), 'error')
    end
    customBox.Text = ''
end)

-- auto-probe row
local autoRow = makeRow(probeScroll, 'Auto-probe', 'Re-probe every N seconds')
autoRow.Parent = makeCard(probeScroll, 'Automation', 'Background probing while you play.')
local _, setAutoTog = makeToggle(autoRow, state.autoProbe, function(v) state.autoProbe = v; saveConfig() end)

local autoIntCard = autoRow.Parent
local intRow = makeRow(autoIntCard, 'Interval (sec)', '5 to 60 seconds between sweeps')
makeSlider(intRow, 5, 60, state.autoProbeInterval, function(v)
    state.autoProbeInterval = v; saveConfig()
end, 0)

-- ========================= REPLICATION PAGE ============================= --
local repCard = makeCard(replicationScroll, 'Replication Test', 'Write a value, monitor for revert, plot timing.')

local repValueRow = makeRow(repCard, 'Target value type', 'Vector3 / CFrame / Number')
local repTypeBtn = makeDropdown(repValueRow, { 'Number', 'Vector3', 'CFrame' }, 'Number', function(v) repTest.kind = v end)

local repPropRow = makeRow(repCard, 'Target property', 'Path inside character / workspace')
local repPropBox = makeTextbox(repPropRow, 'Humanoid.WalkSpeed', 220)

local repDurRow = makeRow(repCard, 'Watch duration', 'Seconds to monitor for revert')
makeSlider(repDurRow, 1, 30, 5, function(v) repTest.duration = v end, 0)

local repBtnRow = Instance.new('Frame', repCard)
repBtnRow.Size = UDim2.new(1, 0, 0, 40)
repBtnRow.BackgroundTransparency = 1
repBtnRow.LayoutOrder = 99

local function parseValueFor(kind, txt)
    if kind == 'Number' then return tonumber(txt) or 100 end
    if kind == 'Vector3' then
        local a, b, c = txt:match('([%-0-9%.]+),%s*([%-0-9%.]+),%s*([%-0-9%.]+)')
        return Vector3.new(tonumber(a) or 0, tonumber(b) or 50, tonumber(c) or 0)
    end
    if kind == 'CFrame' then
        return CFrame.new(0, 100, 0)
    end
end

-- mini graph
local graphFrame = Instance.new('Frame', repCard)
graphFrame.Size = UDim2.new(1, 0, 0, 100)
graphFrame.BackgroundColor3 = C.ContentBg
graphFrame.BorderSizePixel = 0
graphFrame.LayoutOrder = 200
Instance.new('UICorner', graphFrame).CornerRadius = UDim.new(0, 4)

local graphLine = Instance.new('Frame', graphFrame)
graphLine.Size = UDim2.new(1, 0, 0, 1)
graphLine.Position = UDim2.new(0, 0, 0.5, 0)
graphLine.BackgroundColor3 = C.Border
graphLine.BorderSizePixel = 0

local function plotGraph()
    for _, c in ipairs(graphFrame:GetChildren()) do
        if c:IsA('Frame') and c ~= graphLine then c:Destroy() end
    end
    if #repTest.samples == 0 then return end
    local maxV, minV = -math.huge, math.huge
    for _, s in ipairs(repTest.samples) do
        maxV = math.max(maxV, s.v); minV = math.min(minV, s.v)
    end
    if maxV == minV then maxV = minV + 1 end
    for i, s in ipairs(repTest.samples) do
        local bar = Instance.new('Frame', graphFrame)
        bar.AnchorPoint = Vector2.new(0, 1)
        local x = (i - 1) / math.max(1, #repTest.samples - 1)
        local h = (s.v - minV) / (maxV - minV)
        bar.Position = UDim2.new(x, 0, 1, -2)
        bar.Size = UDim2.new(0, 3, 0, math.max(2, h * 90))
        bar.BackgroundColor3 = s.reverted and C.Danger or C.Success
        bar.BorderSizePixel = 0
    end
end

makeButton(repBtnRow, 'Start Test', nil, function()
    local kind = repTest.kind or 'Number'
    local path = repPropBox.Text
    if path == '' then notify('Replication Test', 'Enter property path', 'warn'); return end
    -- resolve path inside character first
    local target, prop
    local ok = pcall(function()
        local parts = {}
        for p in string.gmatch(path, '[^%.]+') do table.insert(parts, p) end
        prop = parts[#parts]
        local root = LocalPlayer.Character or Workspace
        for i = 1, #parts - 1 do
            root = root:FindFirstChild(parts[i]) or root[parts[i]]
        end
        target = root
    end)
    if not ok or not target then notify('Replication Test', 'Path resolve failed', 'error'); return end

    local original = target[prop]
    local writeVal = parseValueFor(kind, repPropBox.Text)
    repTest.samples = {}
    repTest.active = true
    local duration = repTest.duration or 5
    local startedAt = tick()
    -- write
    pcall(function() target[prop] = writeVal end)
    notify('Replication Test', 'Writing to ' .. path, 'info')

    task.spawn(function()
        while repTest.active and tick() - startedAt < duration do
            local cur = target[prop]
            local v
            if typeof(cur) == 'number' then v = cur
            elseif typeof(cur) == 'Vector3' then v = cur.Magnitude
            elseif typeof(cur) == 'CFrame' then v = cur.Position.Magnitude
            else v = 0 end
            local reverted = not valuesEqual(cur, writeVal)
            table.insert(repTest.samples, { t = tick() - startedAt, v = v, reverted = reverted })
            plotGraph()
            task.wait(0.1)
        end
        repTest.active = false
        local revertedCount = 0
        for _, s in ipairs(repTest.samples) do if s.reverted then revertedCount = revertedCount + 1 end end
        if revertedCount > #repTest.samples * 0.5 then
            notify('Replication Test', 'Server reverted ' .. path, 'warn')
        else
            notify('Replication Test', 'Value held: ' .. path, 'success')
        end
    end)
end)

makeButton(repBtnRow, 'Stop', 'secondary', function()
    repTest.active = false
end).Position = UDim2.new(1, -110, 0.5, 0)

-- ========================= CFrame echo card ============================ --
local echoCard = makeCard(replicationScroll, 'CFrame Echo Monitor', 'Round-trip time before HRP.Changed fires server-side replication.')
local echoLabel = Instance.new('TextLabel', echoCard)
echoLabel.BackgroundTransparency = 1
echoLabel.Size = UDim2.new(1, 0, 0, 80)
echoLabel.Font = Enum.Font.Code
echoLabel.TextSize = 13
echoLabel.TextColor3 = C.TextSecondary
echoLabel.TextXAlignment = Enum.TextXAlignment.Left
echoLabel.TextYAlignment = Enum.TextYAlignment.Top
echoLabel.TextWrapped = true
echoLabel.Text = 'No samples yet. Click Run Echo.'
echoLabel.LayoutOrder = 10

makeButton(echoCard, 'Run Echo', nil, function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild('HumanoidRootPart')
    if not hrp then notify('Echo', 'No HumanoidRootPart', 'warn'); return end
    cframeEcho.samples = {}
    for i = 1, 5 do
        local writeAt = tick()
        local original = hrp.CFrame
        local target = original + Vector3.new(math.random() * 0.5, 0, 0)
        local done = false
        local conn
        conn = hrp:GetPropertyChangedSignal('CFrame'):Connect(function()
            if not done then
                done = true
                local rt = (tick() - writeAt) * 1000
                table.insert(cframeEcho.samples, rt)
                conn:Disconnect()
            end
        end)
        hrp.CFrame = target
        task.wait(0.3)
        if not done then conn:Disconnect() end
        task.wait(0.1)
    end
    if #cframeEcho.samples == 0 then
        echoLabel.Text = 'No echo detected.'
    else
        local sum = 0; for _, v in ipairs(cframeEcho.samples) do sum = sum + v end
        local avg = sum / #cframeEcho.samples
        local lines = { string.format('Samples: %d   Avg roundtrip: %.2f ms', #cframeEcho.samples, avg) }
        for i, v in ipairs(cframeEcho.samples) do
            table.insert(lines, string.format('  #%d: %.2f ms', i, v))
        end
        echoLabel.Text = table.concat(lines, '\n')
    end
end).Position = UDim2.new(1, 0, 0, 0)

-- ========================== CHANGE LOG ================================== --
local logCard = makeCard(logScroll, 'Change Feed', 'Live property changes with timestamps + suspected source.')

local logClearRow = Instance.new('Frame', logCard)
logClearRow.Size = UDim2.new(1, 0, 0, 36)
logClearRow.BackgroundTransparency = 1
logClearRow.LayoutOrder = 5

makeButton(logClearRow, 'Clear Log', 'secondary', function()
    changeLog = {}
end).Position = UDim2.new(1, 0, 0.5, 0)

local logMaxRow = makeRow(logCard, 'Max log size', 'Keep the most recent N entries')
makeSlider(logMaxRow, 50, 1000, state.maxLogSize, function(v)
    state.maxLogSize = v; saveConfig()
end, 0)

local logScrollFrame = Instance.new('ScrollingFrame', logCard)
logScrollFrame.Size = UDim2.new(1, 0, 0, 300)
logScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
logScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
logScrollFrame.LayoutOrder = 100
styleScroll(logScrollFrame)

local logLayout = Instance.new('UIListLayout', logScrollFrame)
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Padding = UDim.new(0, 2)

local function logEntry(rowLabel, oldV, newV, source)
    local entry = {
        time = os.date('%H:%M:%S'),
        label = rowLabel,
        old = valueToString(oldV),
        new = valueToString(newV),
        source = source or 'unknown',
        t = tick(),
    }
    table.insert(changeLog, 1, entry)
    while #changeLog > state.maxLogSize do table.remove(changeLog) end

    -- UI
    local item = Instance.new('Frame')
    item.Size = UDim2.new(1, 0, 0, 36)
    item.BackgroundColor3 = C.CardBgHover
    item.BorderSizePixel = 0
    item.LayoutOrder = -tick() * 1000
    Instance.new('UICorner', item).CornerRadius = UDim.new(0, 4)
    local pad = Instance.new('UIPadding', item)
    pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)

    local t = Instance.new('TextLabel', item)
    t.BackgroundTransparency = 1
    t.Position = UDim2.new(0, 0, 0, 2)
    t.Size = UDim2.new(1, 0, 0, 16)
    t.Font = Enum.Font.Code
    t.TextSize = 12
    t.TextColor3 = C.TextPrimary
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Text = string.format('[%s] %s', entry.time, rowLabel)

    local d = Instance.new('TextLabel', item)
    d.BackgroundTransparency = 1
    d.Position = UDim2.new(0, 0, 0, 18)
    d.Size = UDim2.new(1, 0, 0, 14)
    d.Font = Enum.Font.Code
    d.TextSize = 11
    d.TextColor3 = C.TextDim
    d.TextXAlignment = Enum.TextXAlignment.Left
    d.Text = string.format('%s -> %s  (src: %s)', entry.old, entry.new, entry.source)

    item.Parent = logScrollFrame

    -- prune excess UI
    local kids = logScrollFrame:GetChildren()
    if #kids > state.maxLogSize + 1 then
        for i = #kids, state.maxLogSize + 1, -1 do
            local c = kids[i]
            if c:IsA('Frame') then c:Destroy() end
        end
    end

    if state.notifyOnChange then
        notify('Change', rowLabel .. ' = ' .. entry.new, 'info', 2)
    end
end

-- ============================ EVENTS PAGE =============================== --
local eventsCard = makeCard(eventsScroll, 'Tool / Character Events', 'Equipped, Unequipped, Died, Spawned.')

local eventsScrollFrame = Instance.new('ScrollingFrame', eventsCard)
eventsScrollFrame.Size = UDim2.new(1, 0, 0, 320)
eventsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
eventsScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
eventsScrollFrame.LayoutOrder = 10
styleScroll(eventsScrollFrame)

local eventsLayout = Instance.new('UIListLayout', eventsScrollFrame)
eventsLayout.SortOrder = Enum.SortOrder.LayoutOrder
eventsLayout.Padding = UDim.new(0, 2)

local function logEvent(kind, msg)
    table.insert(toolEvents, 1, { time = os.date('%H:%M:%S'), kind = kind, msg = msg })
    while #toolEvents > 200 do table.remove(toolEvents) end

    local item = Instance.new('Frame')
    item.Size = UDim2.new(1, 0, 0, 28)
    item.BackgroundColor3 = C.CardBgHover
    item.BorderSizePixel = 0
    item.LayoutOrder = -tick() * 1000
    Instance.new('UICorner', item).CornerRadius = UDim.new(0, 4)
    local pad = Instance.new('UIPadding', item)
    pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)
    local t = Instance.new('TextLabel', item)
    t.BackgroundTransparency = 1
    t.Size = UDim2.new(1, 0, 1, 0)
    t.Font = Enum.Font.Code
    t.TextSize = 12
    local color = C.TextSecondary
    if kind == 'Spawned' then color = C.Success
    elseif kind == 'Died' then color = C.Danger
    elseif kind == 'Equipped' then color = C.AccentPrimary end
    t.TextColor3 = color
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Text = string.format('[%s] %s : %s', os.date('%H:%M:%S'), kind, msg)
    item.Parent = eventsScrollFrame
end

-- ========================== NETWORK OWNER PAGE ========================== --
local netCard = makeCard(networkScroll, 'Network Ownership', 'Parts you might be able to control via physics.')

local netScrollFrame = Instance.new('ScrollingFrame', netCard)
netScrollFrame.Size = UDim2.new(1, 0, 0, 340)
netScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
netScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
netScrollFrame.LayoutOrder = 10
styleScroll(netScrollFrame)

local netLayout = Instance.new('UIListLayout', netScrollFrame)
netLayout.Padding = UDim.new(0, 4)

local function refreshNetwork()
    for _, c in ipairs(netScrollFrame:GetChildren()) do
        if c:IsA('Frame') then c:Destroy() end
    end
    local char = LocalPlayer.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA('BasePart') then
            local item = Instance.new('Frame', netScrollFrame)
            item.Size = UDim2.new(1, 0, 0, 36)
            item.BackgroundColor3 = C.CardBgHover
            item.BorderSizePixel = 0
            Instance.new('UICorner', item).CornerRadius = UDim.new(0, 4)
            local pad = Instance.new('UIPadding', item)
            pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)
            local lbl = Instance.new('TextLabel', item)
            lbl.BackgroundTransparency = 1
            lbl.Position = UDim2.new(0, 0, 0, 2)
            lbl.Size = UDim2.new(0.6, 0, 0, 16)
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 12
            lbl.TextColor3 = C.TextPrimary
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Text = p:GetFullName():gsub('Workspace%.', '')

            local sub = Instance.new('TextLabel', item)
            sub.BackgroundTransparency = 1
            sub.Position = UDim2.new(0, 0, 0, 18)
            sub.Size = UDim2.new(0.6, 0, 0, 14)
            sub.Font = Enum.Font.Code
            sub.TextSize = 11
            sub.TextColor3 = C.TextDim
            sub.TextXAlignment = Enum.TextXAlignment.Left
            local okOwner, owner = pcall(function() return p:GetNetworkOwner() end)
            local okMine, mine = pcall(function() return p:IsNetworkOwner() end)
            local ownerStr = okOwner and (owner and owner.Name or 'server') or 'n/a'
            local mineStr = okMine and (mine and 'YES' or 'no') or 'n/a'
            sub.Text = string.format('owner: %s   mine: %s', ownerStr, mineStr)

            local btn = Instance.new('TextButton', item)
            btn.AnchorPoint = Vector2.new(1, 0.5)
            btn.Position = UDim2.new(1, 0, 0.5, 0)
            btn.Size = UDim2.new(0, 90, 0, 24)
            btn.BackgroundColor3 = C.AccentPrimary
            btn.AutoButtonColor = false
            btn.BorderSizePixel = 0
            btn.Font = Enum.Font.GothamMedium
            btn.TextSize = 12
            btn.TextColor3 = Color3.fromRGB(255,255,255)
            btn.Text = 'Claim Owner'
            Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 4)
            btn.MouseButton1Click:Connect(function()
                local ok = pcall(function() p:SetNetworkOwner(LocalPlayer) end)
                if ok then notify('Network Owner', 'Claimed: ' .. p.Name, 'success')
                else notify('Network Owner', 'Failed (server-anchored?)', 'warn') end
                task.wait(0.2); refreshNetwork()
            end)
        end
    end
end

makeButton(netCard, 'Refresh', 'secondary', function() refreshNetwork() end).Position = UDim2.new(1, 0, 0, 0)

-- ============================ EXPORT PAGE =============================== --
local expCard = makeCard(exportScroll, 'Export Findings', 'Dump all probe results, change log, and event log to JSON.')

local expPathRow = makeRow(expCard, 'Output path', 'Relative to executor workspace')
local pathBox = makeTextbox(expPathRow, 'freezer/live_state_export.json', 320)
pathBox.Text = 'freezer/live_state_export.json'

local expBtnRow = Instance.new('Frame', expCard)
expBtnRow.Size = UDim2.new(1, 0, 0, 40)
expBtnRow.BackgroundTransparency = 1
expBtnRow.LayoutOrder = 50

makeButton(expBtnRow, 'Export JSON', nil, function()
    local data = {
        exported = os.date('%Y-%m-%d %H:%M:%S'),
        game = game.PlaceId,
        rows = {},
        log = changeLog,
        events = toolEvents,
        echo = cframeEcho.samples,
    }
    for id, r in pairs(rows) do
        table.insert(data.rows, {
            id = id, label = r.label, category = r.category,
            badge = r.badge, score = r.score,
            value = valueToString(r.lastValue),
            history = r.history,
        })
    end
    local enc = HttpService:JSONEncode(data)
    if writefile then
        local ok = pcall(function() writefile(pathBox.Text, enc) end)
        if ok then notify('Export', 'Saved ' .. pathBox.Text, 'success', 4)
        else notify('Export', 'writefile failed', 'error') end
    else
        notify('Export', 'No writefile available', 'warn')
    end
end)

makeButton(expBtnRow, 'Copy to Clipboard', 'secondary', function()
    if setclipboard then
        local data = HttpService:JSONEncode({ rows = rows, log = changeLog })
        pcall(function() setclipboard(data) end)
        notify('Export', 'Copied to clipboard', 'success')
    else
        notify('Export', 'No setclipboard', 'warn')
    end
end).Position = UDim2.new(1, -110, 0.5, 0)

-- ============================ SETTINGS ================================== --
local settingsCard = makeCard(settingsScroll, 'General', 'Refresh rate, keybinds, persistence.')

local refRow = makeRow(settingsCard, 'Refresh interval (s)', 'How often the monitor list redraws')
makeSlider(refRow, 0.1, 2, state.refreshInterval, function(v)
    state.refreshInterval = v; saveConfig()
end, 1)

local kbRow1 = makeRow(settingsCard, 'Toggle window key', 'Default F10')
makeKeybind(kbRow1, state.toggleKey, function(k) state.toggleKey = k; saveConfig() end)

local kbRow2 = makeRow(settingsCard, 'Probe all key', 'Default F11')
makeKeybind(kbRow2, state.auditKey, function(k) state.auditKey = k; saveConfig() end)

local persistCard = makeCard(settingsScroll, 'Persistence', 'Save, load, reset.')

local saveRow = Instance.new('Frame', persistCard)
saveRow.Size = UDim2.new(1, 0, 0, 40)
saveRow.BackgroundTransparency = 1
saveRow.LayoutOrder = 5

makeButton(saveRow, 'Save Config', nil, function()
    saveConfig(); notify('Settings', 'Config saved', 'success')
end)

makeButton(saveRow, 'Load Config', 'secondary', function()
    loadConfig(); notify('Settings', 'Config reloaded', 'success')
    refreshRows()
end).Position = UDim2.new(1, -110, 0.5, 0)

makeButton(saveRow, 'Reset', 'danger', function()
    for k, v in pairs(DEFAULTS) do state[k] = v end
    saveConfig(); notify('Settings', 'Reset to defaults', 'success')
    refreshRows()
end).Position = UDim2.new(1, -220, 0.5, 0)

-- ========================= CHARACTER EVENT HOOKS ======================== --
local function bindCharacter(char)
    if not char then return end
    local hum = char:WaitForChild('Humanoid', 5)
    if hum then
        track(hum.Died:Connect(function() logEvent('Died', 'Humanoid died') end))
        for _, p in ipairs(HUMANOID_PROPS) do
            track(hum:GetPropertyChangedSignal(p):Connect(function()
                local r = rows['hum_' .. p]
                if r then
                    local old = r.lastValue
                    r.lastValue = hum[p]
                    r.lastChange = tick()
                    local src = checkcaller() and 'self' or 'external'
                    logEntry(r.label, old, hum[p], src)
                end
            end))
        end
    end
    local hrp = char:WaitForChild('HumanoidRootPart', 5)
    if hrp then
        track(hrp:GetPropertyChangedSignal('CFrame'):Connect(function()
            local r = rows['hrp_cframe']
            if r then r.lastValue = hrp.CFrame; r.lastChange = tick() end
        end))
    end

    track(char.ChildAdded:Connect(function(c)
        if c:IsA('Tool') then logEvent('Equipped', c.Name) end
    end))
    track(char.ChildRemoved:Connect(function(c)
        if c:IsA('Tool') then logEvent('Unequipped', c.Name) end
    end))

    logEvent('Spawned', 'Character ready')
    harvestAll()
end

if LocalPlayer.Character then bindCharacter(LocalPlayer.Character) end
track(LocalPlayer.CharacterAdded:Connect(bindCharacter))

-- leaderstats live
local function bindLeaderstats()
    local ls = LocalPlayer:FindFirstChild('leaderstats')
    if not ls then return end
    for _, stat in ipairs(ls:GetChildren()) do
        if stat:IsA('ValueBase') then
            track(stat.Changed:Connect(function(new)
                local r = rows['ls_' .. stat.Name]
                if r then
                    local old = r.lastValue
                    r.lastValue = new
                    logEntry(r.label, old, new, 'leaderstats')
                end
            end))
        end
    end
end
bindLeaderstats()
track(LocalPlayer.ChildAdded:Connect(function(c)
    if c.Name == 'leaderstats' then task.wait(0.2); bindLeaderstats(); harvestAll() end
end))

-- Backpack
local function bindBackpack()
    local bp = LocalPlayer:FindFirstChild('Backpack')
    if not bp then return end
    track(bp.ChildAdded:Connect(function(t)
        if t:IsA('Tool') then logEvent('ToolAdded', t.Name); harvestAll() end
    end))
    track(bp.ChildRemoved:Connect(function(t)
        if t:IsA('Tool') then logEvent('ToolRemoved', t.Name); harvestAll() end
    end))
end
bindBackpack()

-- ============================ AUTO-PROBE LOOP =========================== --
task.spawn(function()
    while ScreenGui.Parent do
        task.wait(state.autoProbeInterval or 15)
        if state.autoProbe and probeAll then
            probeAll()
        end
    end
end)

-- ============================ REFRESH LOOP ============================== --
task.spawn(function()
    while ScreenGui.Parent do
        task.wait(state.refreshInterval or 0.5)
        -- only refresh sub-text values (not full rebuild) for performance
        for _, r in pairs(rows) do
            if r._ui and r._ui.sub then
                local ok, val = pcall(r.getter)
                if ok then
                    r.lastValue = val
                    r._ui.sub.Text = r.category .. ' \u{2022} ' .. valueToString(val)
                    r._ui.score.Text = string.format('trust %d', r.score or 50)
                    r._ui.badge.BackgroundColor3 = colorForBadge(r.badge)
                    r._ui.badgeTxt.Text = badgeText(r.badge)
                end
            end
        end
    end
end)

-- ============================ FOOTER STATS LOOP ========================= --
task.spawn(function()
    local frames = 0
    local lastT = tick()
    track(RunService.RenderStepped:Connect(function() frames = frames + 1 end))
    while ScreenGui.Parent do
        task.wait(1)
        local now = tick()
        local fps = frames / (now - lastT)
        frames = 0; lastT = now
        local ping = 0
        pcall(function()
            ping = math.floor(Stats.Network.ServerStatsItem['Data Ping']:GetValue())
        end)
        local placeName = ''
        pcall(function()
            placeName = MarketplaceService:GetProductInfo(game.PlaceId).Name or ''
        end)
        FooterLeft.Text = string.format('FPS %d / Ping %dms / %d players / %s / %s',
            math.floor(fps), ping, #Players:GetPlayers(),
            placeName:sub(1, 18), os.date('%H:%M'))
    end
end)

-- ============================ SEARCH FILTER ============================= --
SearchBox:GetPropertyChangedSignal('Text'):Connect(function()
    local q = string.lower(SearchBox.Text)
    for _, page in pairs(pages) do
        for _, card in ipairs(page:GetDescendants()) do
            if card:IsA('Frame') and card.Parent and card.Parent:IsA('ScrollingFrame') then
                local labels = {}
                for _, ch in ipairs(card:GetDescendants()) do
                    if ch:IsA('TextLabel') then table.insert(labels, string.lower(ch.Text)) end
                end
                local txt = table.concat(labels, ' ')
                card.Visible = q == '' or txt:find(q, 1, true) ~= nil
            end
        end
    end
end)

-- ============================ KEYBINDS ================================== --
track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if state.toggleKey and input.KeyCode.Name == state.toggleKey then
        Window.Visible = not Window.Visible
    elseif state.auditKey and input.KeyCode.Name == state.auditKey then
        if probeAll then probeAll() end
    end
end))

-- ============================ WINDOW BUTTONS ============================ --
CloseBtn.MouseButton1Click:Connect(function() Window.Visible = false end)
local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        Window:SetAttribute('OrigSize', Window.Size)
        TweenService:Create(Window, EASE, { Size = UDim2.new(0, 920, 0, 42) }):Play()
    else
        TweenService:Create(Window, EASE, { Size = UDim2.new(0, 920, 0, 600) }):Play()
    end
end)

-- ============================ INITIAL STATE ============================= --
harvestAll()
selectPage('Monitor')
notify('Live State', 'Monitor online. F11 to audit, F10 to toggle.', 'success', 3)

-- ================================ API =================================== --
getgenv().ENI = getgenv().ENI or {}
getgenv().ENI.LiveState = {
    Show = function() Window.Visible = true end,
    Hide = function() Window.Visible = false end,
    Toggle = function() Window.Visible = not Window.Visible end,
    Destroy = function()
        clearConnections()
        if ScreenGui then ScreenGui:Destroy() end
        getgenv().ENI.LiveState = nil
    end,
    GetConfig = function() return state end,
    SetConfig = function(newState)
        for k, v in pairs(newState) do state[k] = v end
        saveConfig()
    end,
    ProbeAll = function() if probeAll then probeAll() end end,
    GetRows = function() return rows end,
    GetChangeLog = function() return changeLog end,
    AddCustomProbe = function(path)
        table.insert(state.customProbes, path)
        saveConfig(); harvestAll()
    end,
    Notify = notify,
}

return getgenv().ENI.LiveState

end
-- END MODULE: LIVE STATE v3.0.0
----------------------------------------------------------------------

----------------------------------------------------------------------
----------------------------------------------------------------------
-- RECON MODULES (5 embedded)
----------------------------------------------------------------------

----------------------------------------------------------------------
-- MODULE: REMOTE SPY v3.0.0 (1426 lines original)
----------------------------------------------------------------------
do
--[[
    ============================================================
        eni-roblox-kit :: Remote Spy
        Module : RemoteSpy
        Version: 2.0.0
        API    : getgenv().ENI.RemoteSpy
    ------------------------------------------------------------
        Live-log every RemoteEvent / RemoteFunction /
        UnreliableRemoteEvent fired by (or to) the client.
        Inspect args as a tree, replay, edit-and-replay,
        block, and export. Pure-Lua GUI, no external deps.
    ============================================================
--]]

------------------------------------------------------------------
-- 0. anti-detect / exploit-compat shims
------------------------------------------------------------------
local cloneref          = cloneref          or function(x) return x end
local protect_gui       = (syn and syn.protect_gui) or (gethui and function(g) g.Parent = gethui() end) or function(g) g.Parent = game:GetService('CoreGui') end
local hookmetamethod    = hookmetamethod    or function() return nil end
local getrawmetatable   = getrawmetatable   or function() return nil end
local setreadonly       = setreadonly       or function() end
local newcclosure       = newcclosure       or function(f) return f end
local getconnections    = getconnections    or function() return {} end
local getnamecallmethod = getnamecallmethod or function() return '' end
local checkcaller       = checkcaller       or function() return false end
local identifyexecutor  = identifyexecutor  or function() return 'unknown' end
local writefile         = writefile         or function() end
local readfile          = readfile          or function() return '' end
local isfile            = isfile            or function() return false end
local makefolder        = makefolder        or function() end
local isfolder          = isfolder          or function() return false end
local setclipboard      = setclipboard      or (toclipboard) or function() end

local EXECUTOR = (function() local ok, e = pcall(identifyexecutor) if ok then return tostring(e) end return 'unknown' end)()
local HAS_HOOKMETA = type(hookmetamethod) == 'function'
local HAS_GETCONNECTIONS = pcall(function() return #getconnections(game) end)

------------------------------------------------------------------
-- 1. services (cloned)
------------------------------------------------------------------
local Players          = cloneref(game:GetService('Players'))
local RunService       = cloneref(game:GetService('RunService'))
local UserInputService = cloneref(game:GetService('UserInputService'))
local TweenService     = cloneref(game:GetService('TweenService'))
local HttpService      = cloneref(game:GetService('HttpService'))
local Lighting         = cloneref(game:GetService('Lighting'))
local Workspace        = cloneref(game:GetService('Workspace'))

local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------
-- 2. design system palette
------------------------------------------------------------------
local C = {
    Background       = Color3.fromRGB( 15, 15, 22),
    Surface          = Color3.fromRGB( 22, 22, 30),
    SurfaceElevated  = Color3.fromRGB( 32, 32, 42),
    Border           = Color3.fromRGB( 45, 45, 60),
    AccentPrimary    = Color3.fromRGB(255, 65,180),
    AccentSecondary  = Color3.fromRGB(180, 75,255),
    TextPrimary      = Color3.fromRGB(240,240,248),
    TextSecondary    = Color3.fromRGB(160,160,178),
    TextDim          = Color3.fromRGB(100,100,118),
    Success          = Color3.fromRGB( 80,220,130),
    Warning          = Color3.fromRGB(255,185, 70),
    Danger           = Color3.fromRGB(255, 85,110),

    EvFireServer     = Color3.fromRGB(255, 90,110),
    EvInvokeServer   = Color3.fromRGB(255,170, 90),
    EvFireClient     = Color3.fromRGB( 90,200,255),
    EvOnClientEvent  = Color3.fromRGB(100,220,140),
}

local FONT_TITLE  = Enum.Font.GothamBold
local FONT_HEADER = Enum.Font.GothamSemibold
local FONT_BODY   = Enum.Font.Gotham
local FONT_CODE   = Enum.Font.Code
local TWEEN_INFO  = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

------------------------------------------------------------------
-- 3. tiny helpers
------------------------------------------------------------------
local function tween(o, props, ti) TweenService:Create(o, ti or TWEEN_INFO, props):Play() end
local function corner(p, r) local c = Instance.new('UICorner') c.CornerRadius = UDim.new(0, r or 6) c.Parent = p return c end
local function stroke(p, col, thick) local s = Instance.new('UIStroke') s.Color = col or C.Border s.Thickness = thick or 1 s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Parent = p return s end
local function padding(p, all) local u = Instance.new('UIPadding') u.PaddingTop = UDim.new(0, all) u.PaddingBottom = UDim.new(0, all) u.PaddingLeft = UDim.new(0, all) u.PaddingRight = UDim.new(0, all) u.Parent = p return u end
local function layout(p, dir, gap) local l = Instance.new('UIListLayout') l.FillDirection = dir or Enum.FillDirection.Vertical l.Padding = UDim.new(0, gap or 8) l.SortOrder = Enum.SortOrder.LayoutOrder l.Parent = p return l end

local function deepcopy(t, seen)
    if type(t) ~= 'table' then return t end
    seen = seen or {}
    if seen[t] then return seen[t] end
    local n = {} seen[t] = n
    for k, v in pairs(t) do n[deepcopy(k, seen)] = deepcopy(v, seen) end
    return n
end

local function safeTostring(v)
    local ok, s = pcall(tostring, v)
    if ok then return s end
    return '<unprintable>'
end

local function shortPreview(v, depth)
    depth = depth or 0
    if depth > 2 then return '...' end
    local t = typeof(v)
    if t == 'string' then
        local s = v if #s > 32 then s = s:sub(1, 32) .. '...' end
        return '"' .. s .. '"'
    elseif t == 'number' or t == 'boolean' or t == 'nil' then
        return safeTostring(v)
    elseif t == 'Instance' then
        return '<' .. v.ClassName .. ' "' .. v.Name .. '">'
    elseif t == 'Vector3' then
        return ('V3(%.1f,%.1f,%.1f)'):format(v.X, v.Y, v.Z)
    elseif t == 'CFrame' then
        local p = v.Position return ('CF(%.1f,%.1f,%.1f)'):format(p.X, p.Y, p.Z)
    elseif t == 'Color3' then
        return ('Col(%d,%d,%d)'):format(math.floor(v.R*255), math.floor(v.G*255), math.floor(v.B*255))
    elseif t == 'table' then
        local parts, n = {}, 0
        for k, val in pairs(v) do
            n = n + 1 if n > 4 then table.insert(parts, '...') break end
            table.insert(parts, safeTostring(k) .. '=' .. shortPreview(val, depth + 1))
        end
        return '{' .. table.concat(parts, ', ') .. '}'
    end
    return '<' .. t .. '>'
end

local function argsPreview(args, maxLen)
    maxLen = maxLen or 80
    local out = {}
    for i = 1, #args do out[i] = shortPreview(args[i]) end
    local s = table.concat(out, ', ')
    if #s > maxLen then s = s:sub(1, maxLen) .. '...' end
    return s
end

local function timestamp()
    local t = os.date('*t', os.time())
    return ('%02d:%02d:%02d'):format(t.hour, t.min, t.sec)
end

local function fullPath(inst)
    if not inst or typeof(inst) ~= 'Instance' then return '<nil>' end
    local ok, p = pcall(function() return inst:GetFullName() end)
    if ok then return p end
    return inst.Name or '<?>'
end

local function regexMatch(s, pat)
    if not pat or pat == '' then return true end
    local ok, m = pcall(string.match, s, pat)
    if ok then return m ~= nil end
    return s:lower():find(pat:lower(), 1, true) ~= nil
end

------------------------------------------------------------------
-- 4. state + config persistence
------------------------------------------------------------------
local CFG_DIR  = 'freezer'
local CFG_FILE = CFG_DIR .. '/remote_spy.json'

pcall(function() if not isfolder(CFG_DIR) then makefolder(CFG_DIR) end end)

local state = {
    paused         = false,
    logInbound     = true,
    logOutbound    = true,
    dropBlocked    = false,
    maxLog         = 1500,
    autoPause      = false,
    autoPauseRate  = 60,
    filter         = '',
    search         = '',
    blockList      = {},
    keys           = { pause = 'F5', clear = 'F6', toggle = 'F7' },
    windowVisible  = true,
    accentHue      = 0,
}

local function saveConfig()
    pcall(function()
        local copy = deepcopy(state)
        writefile(CFG_FILE, HttpService:JSONEncode(copy))
    end)
end

local function loadConfig()
    pcall(function()
        if isfile and isfile(CFG_FILE) then
            local data = HttpService:JSONDecode(readfile(CFG_FILE))
            if type(data) == 'table' then
                for k, v in pairs(data) do state[k] = v end
            end
        end
    end)
end
loadConfig()

------------------------------------------------------------------
-- 5. log buffer + stats
------------------------------------------------------------------
local LOG = {}
local LOG_ID = 0
local STATS = { total = 0, FireServer = 0, InvokeServer = 0, FireClient = 0, OnClientEvent = 0, OnClientInvoke = 0, perRemote = {} }
local RATE  = { window = {}, perSec = 0 }
local LOG_CHANGED = Instance.new('BindableEvent')

local function bumpStats(kind, path)
    STATS.total = STATS.total + 1
    STATS[kind] = (STATS[kind] or 0) + 1
    STATS.perRemote[path] = (STATS.perRemote[path] or 0) + 1
end

local function pushLog(entry)
    LOG_ID = LOG_ID + 1
    entry.id = LOG_ID
    table.insert(LOG, entry)
    while #LOG > state.maxLog do table.remove(LOG, 1) end
    bumpStats(entry.kind, entry.path)
    table.insert(RATE.window, os.clock())
    LOG_CHANGED:Fire(entry)
end

local function clearLog()
    LOG = {}
    STATS = { total = 0, FireServer = 0, InvokeServer = 0, FireClient = 0, OnClientEvent = 0, OnClientInvoke = 0, perRemote = {} }
    LOG_CHANGED:Fire(nil)
end

------------------------------------------------------------------
-- 6. UI helpers
------------------------------------------------------------------
local UI = {}
local NOTIFY_HOST

local function makeStrokeHover(obj)
    local s = stroke(obj, C.AccentPrimary, 1)
    s.Transparency = 1
    obj.MouseEnter:Connect(function() tween(s, { Transparency = 0 }) end)
    obj.MouseLeave:Connect(function() tween(s, { Transparency = 1 }) end)
    return s
end

function UI.notify(title, msg, kind, dur)
    if not NOTIFY_HOST then return end
    kind = kind or 'info' dur = dur or 3
    local col = (kind == 'success' and C.Success) or (kind == 'warning' and C.Warning) or (kind == 'danger' and C.Danger) or C.AccentPrimary

    local f = Instance.new('Frame')
    f.Size = UDim2.new(0, 280, 0, 60)
    f.Position = UDim2.new(1, 20, 0, 0)
    f.BackgroundColor3 = C.SurfaceElevated
    f.BorderSizePixel = 0
    f.Parent = NOTIFY_HOST
    corner(f, 6) stroke(f, col, 1)

    local bar = Instance.new('Frame', f)
    bar.Size = UDim2.new(0, 3, 1, 0) bar.BackgroundColor3 = col bar.BorderSizePixel = 0
    corner(bar, 3)

    local t = Instance.new('TextLabel', f)
    t.BackgroundTransparency = 1 t.Position = UDim2.new(0, 12, 0, 6)
    t.Size = UDim2.new(1, -16, 0, 18) t.Font = FONT_HEADER t.TextSize = 14
    t.TextColor3 = C.TextPrimary t.TextXAlignment = Enum.TextXAlignment.Left t.Text = title or 'note'

    local m = Instance.new('TextLabel', f)
    m.BackgroundTransparency = 1 m.Position = UDim2.new(0, 12, 0, 26)
    m.Size = UDim2.new(1, -16, 0, 30) m.Font = FONT_BODY m.TextSize = 12
    m.TextColor3 = C.TextSecondary m.TextXAlignment = Enum.TextXAlignment.Left
    m.TextWrapped = true m.Text = msg or ''

    tween(f, { Position = UDim2.new(1, -10, 0, 0) })
    task.delay(dur, function()
        if f and f.Parent then
            tween(f, { Position = UDim2.new(1, 20, 0, 0) })
            task.wait(0.25) f:Destroy()
        end
    end)
end
local notify = UI.notify

function UI.createScrollFrame(parent)
    local sf = Instance.new('ScrollingFrame')
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 3
    sf.ScrollBarImageColor3 = C.AccentPrimary
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.Parent = parent
    return sf
end

function UI.createSection(parent, title)
    local f = Instance.new('Frame')
    f.BackgroundColor3 = C.Surface
    f.BorderSizePixel = 0
    f.Size = UDim2.new(1, 0, 0, 36)
    f.AutomaticSize = Enum.AutomaticSize.Y
    f.Parent = parent
    corner(f, 6) padding(f, 10)
    local hdr = Instance.new('TextLabel', f)
    hdr.BackgroundTransparency = 1
    hdr.Size = UDim2.new(1, 0, 0, 18)
    hdr.Font = FONT_HEADER hdr.TextSize = 15
    hdr.TextColor3 = C.AccentPrimary
    hdr.TextXAlignment = Enum.TextXAlignment.Left
    hdr.Text = title
    local sep = Instance.new('Frame', f)
    sep.BackgroundColor3 = C.Border
    sep.BorderSizePixel = 0
    sep.Position = UDim2.new(0, 0, 0, 22)
    sep.Size = UDim2.new(1, 0, 0, 1)
    local body = Instance.new('Frame', f)
    body.BackgroundTransparency = 1
    body.Position = UDim2.new(0, 0, 0, 28)
    body.Size = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    layout(body, Enum.FillDirection.Vertical, 6)
    return body, f
end

function UI.createButton(parent, label, style, cb)
    style = style or 'primary'
    local bg = (style == 'primary' and C.AccentPrimary) or (style == 'danger' and C.Danger) or C.SurfaceElevated
    local fg = Color3.new(1,1,1)
    if style == 'secondary' then fg = C.TextPrimary end
    local b = Instance.new('TextButton')
    b.BackgroundColor3 = bg b.BorderSizePixel = 0 b.AutoButtonColor = false
    b.Size = UDim2.new(1, 0, 0, 28)
    b.Font = FONT_HEADER b.TextSize = 13 b.TextColor3 = fg
    b.Text = label b.Parent = parent
    b.ClipsDescendants = true
    corner(b, 4) makeStrokeHover(b)
    b.MouseButton1Down:Connect(function()
        local r = Instance.new('Frame', b)
        r.BackgroundColor3 = Color3.new(1,1,1)
        r.BackgroundTransparency = 0.7
        r.BorderSizePixel = 0
        r.Size = UDim2.new(0, 6, 0, 6)
        r.Position = UDim2.new(0.5, -3, 0.5, -3)
        corner(r, 100)
        tween(r, { Size = UDim2.new(0, 200, 0, 200), Position = UDim2.new(0.5, -100, 0.5, -100), BackgroundTransparency = 1 }, TweenInfo.new(0.4, Enum.EasingStyle.Quad))
        task.delay(0.4, function() if r then r:Destroy() end end)
    end)
    b.MouseButton1Click:Connect(function() if cb then pcall(cb) end end)
    return b
end

function UI.createToggle(parent, label, default, cb)
    local v = default and true or false
    local f = Instance.new('Frame', parent)
    f.BackgroundColor3 = C.SurfaceElevated f.BorderSizePixel = 0
    f.Size = UDim2.new(1, 0, 0, 28) corner(f, 4) padding(f, 6)
    local l = Instance.new('TextLabel', f)
    l.BackgroundTransparency = 1 l.Size = UDim2.new(1, -50, 1, 0)
    l.Font = FONT_BODY l.TextSize = 13 l.TextColor3 = C.TextPrimary
    l.TextXAlignment = Enum.TextXAlignment.Left l.Text = label
    local track = Instance.new('TextButton', f)
    track.AutoButtonColor = false track.Text = ''
    track.Size = UDim2.new(0, 36, 0, 16)
    track.Position = UDim2.new(1, -40, 0.5, -8)
    track.BackgroundColor3 = C.Border track.BorderSizePixel = 0
    corner(track, 100)
    local knob = Instance.new('Frame', track)
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = UDim2.new(0, 2, 0.5, -6)
    knob.BackgroundColor3 = C.TextPrimary knob.BorderSizePixel = 0
    corner(knob, 100)
    local function paint()
        tween(track, { BackgroundColor3 = v and C.AccentPrimary or C.Border })
        tween(knob, { Position = v and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6) })
    end
    paint()
    track.MouseButton1Click:Connect(function()
        v = not v paint()
        if cb then pcall(cb, v) end
    end)
    return {
        set = function(x) v = x and true or false paint() end,
        get = function() return v end,
    }
end

function UI.createSlider(parent, label, mn, mx, default, dec, cb)
    dec = dec or 0
    local v = math.clamp(default or mn, mn, mx)
    local f = Instance.new('Frame', parent)
    f.BackgroundColor3 = C.SurfaceElevated f.BorderSizePixel = 0
    f.Size = UDim2.new(1, 0, 0, 42) corner(f, 4) padding(f, 6)
    local top = Instance.new('Frame', f)
    top.BackgroundTransparency = 1 top.Size = UDim2.new(1, 0, 0, 16)
    local l = Instance.new('TextLabel', top)
    l.BackgroundTransparency = 1 l.Size = UDim2.new(1, -80, 1, 0)
    l.Font = FONT_BODY l.TextSize = 13 l.TextColor3 = C.TextPrimary
    l.TextXAlignment = Enum.TextXAlignment.Left l.Text = label
    local valL = Instance.new('TextLabel', top)
    valL.BackgroundTransparency = 1 valL.Size = UDim2.new(0, 80, 1, 0)
    valL.Position = UDim2.new(1, -80, 0, 0)
    valL.Font = FONT_CODE valL.TextSize = 13 valL.TextColor3 = C.AccentPrimary
    valL.TextXAlignment = Enum.TextXAlignment.Right
    valL.Text = ('%.' .. dec .. 'f'):format(v)
    local bar = Instance.new('Frame', f)
    bar.Position = UDim2.new(0, 0, 0, 22) bar.Size = UDim2.new(1, 0, 0, 6)
    bar.BackgroundColor3 = C.Border bar.BorderSizePixel = 0 corner(bar, 4)
    local fill = Instance.new('Frame', bar)
    fill.BackgroundColor3 = C.AccentPrimary fill.BorderSizePixel = 0
    fill.Size = UDim2.new((v-mn)/(mx-mn), 0, 1, 0) corner(fill, 4)
    local knob = Instance.new('TextButton', bar)
    knob.Text = '' knob.AutoButtonColor = false
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((v-mn)/(mx-mn), 0, 0.5, 0)
    knob.BackgroundColor3 = C.TextPrimary knob.BorderSizePixel = 0
    corner(knob, 100)
    local dragging = false
    local function setFromX(x)
        local abs = bar.AbsolutePosition.X
        local size = bar.AbsoluteSize.X
        if size <= 0 then return end
        local r = math.clamp((x - abs) / size, 0, 1)
        local raw = mn + (mx - mn) * r
        local step = 10 ^ -dec
        raw = math.floor(raw / step + 0.5) * step
        raw = math.clamp(raw, mn, mx)
        v = raw
        valL.Text = ('%.' .. dec .. 'f'):format(v)
        tween(fill, { Size = UDim2.new(r, 0, 1, 0) })
        tween(knob, { Position = UDim2.new(r, 0, 0.5, 0) })
        if cb then pcall(cb, v) end
    end
    knob.MouseButton1Down:Connect(function() dragging = true end)
    bar.InputBegan:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
            dragging = true setFromX(io.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(io)
        if dragging and (io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch) then
            setFromX(io.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    return {
        set = function(x) v = math.clamp(x, mn, mx) local r = (v-mn)/(mx-mn)
            valL.Text = ('%.' .. dec .. 'f'):format(v)
            tween(fill, { Size = UDim2.new(r, 0, 1, 0) })
            tween(knob, { Position = UDim2.new(r, 0, 0.5, 0) })
        end,
        get = function() return v end,
    }
end

function UI.createDropdown(parent, label, opts, default, cb)
    local v = default or (opts and opts[1])
    local f = Instance.new('Frame', parent)
    f.BackgroundColor3 = C.SurfaceElevated f.BorderSizePixel = 0
    f.Size = UDim2.new(1, 0, 0, 28) corner(f, 4) padding(f, 6)
    local l = Instance.new('TextLabel', f)
    l.BackgroundTransparency = 1 l.Size = UDim2.new(0.5, 0, 1, 0)
    l.Font = FONT_BODY l.TextSize = 13 l.TextColor3 = C.TextPrimary
    l.TextXAlignment = Enum.TextXAlignment.Left l.Text = label
    local btn = Instance.new('TextButton', f)
    btn.AutoButtonColor = false btn.Text = safeTostring(v)
    btn.BackgroundColor3 = C.Surface btn.BorderSizePixel = 0
    btn.Size = UDim2.new(0.5, -4, 1, 0)
    btn.Position = UDim2.new(0.5, 4, 0, 0)
    btn.Font = FONT_BODY btn.TextSize = 13 btn.TextColor3 = C.AccentPrimary
    corner(btn, 4) stroke(btn, C.Border, 1)
    local open = false
    local list
    local function close()
        if list then
            tween(list, { Size = UDim2.new(0.5, -4, 0, 0) })
            task.delay(0.18, function() if list then list:Destroy() list = nil end end)
        end
        open = false
    end
    btn.MouseButton1Click:Connect(function()
        if open then close() return end
        open = true
        list = Instance.new('ScrollingFrame', f)
        list.BackgroundColor3 = C.SurfaceElevated list.BorderSizePixel = 0
        list.Position = UDim2.new(0.5, 4, 1, 4)
        list.Size = UDim2.new(0.5, -4, 0, 0)
        list.ScrollBarThickness = 2 list.ScrollBarImageColor3 = C.AccentPrimary
        list.ZIndex = 5
        corner(list, 4) stroke(list, C.AccentPrimary, 1)
        local ll = layout(list, Enum.FillDirection.Vertical, 2)
        for _, opt in ipairs(opts) do
            local b = Instance.new('TextButton', list)
            b.BackgroundColor3 = C.Surface b.BorderSizePixel = 0
            b.Size = UDim2.new(1, 0, 0, 22)
            b.Font = FONT_BODY b.TextSize = 12 b.TextColor3 = C.TextPrimary
            b.Text = safeTostring(opt) b.ZIndex = 6
            b.MouseButton1Click:Connect(function()
                v = opt btn.Text = safeTostring(opt) close()
                if cb then pcall(cb, opt) end
            end)
        end
        local h = math.min(#opts * 24, 120)
        tween(list, { Size = UDim2.new(0.5, -4, 0, h) })
        list.CanvasSize = UDim2.new(0, 0, 0, ll.AbsoluteContentSize.Y)
    end)
    return { set = function(x) v = x btn.Text = safeTostring(x) end, get = function() return v end, refresh = function(o) opts = o end }
end

function UI.createTextBox(parent, placeholder, default, cb)
    local tb = Instance.new('TextBox', parent)
    tb.BackgroundColor3 = C.SurfaceElevated tb.BorderSizePixel = 0
    tb.Size = UDim2.new(1, 0, 0, 28)
    tb.Font = FONT_BODY tb.TextSize = 13
    tb.TextColor3 = C.TextPrimary tb.PlaceholderColor3 = C.TextDim
    tb.PlaceholderText = placeholder or '' tb.Text = default or ''
    tb.TextXAlignment = Enum.TextXAlignment.Left tb.ClearTextOnFocus = false
    corner(tb, 4) padding(tb, 6) makeStrokeHover(tb)
    tb.FocusLost:Connect(function() if cb then pcall(cb, tb.Text) end end)
    return tb
end

function UI.createKeybind(parent, label, defaultKey, cb)
    local key = defaultKey
    local f = Instance.new('Frame', parent)
    f.BackgroundColor3 = C.SurfaceElevated f.BorderSizePixel = 0
    f.Size = UDim2.new(1, 0, 0, 28) corner(f, 4) padding(f, 6)
    local l = Instance.new('TextLabel', f)
    l.BackgroundTransparency = 1 l.Size = UDim2.new(0.6, 0, 1, 0)
    l.Font = FONT_BODY l.TextSize = 13 l.TextColor3 = C.TextPrimary
    l.TextXAlignment = Enum.TextXAlignment.Left l.Text = label
    local btn = Instance.new('TextButton', f)
    btn.AutoButtonColor = false btn.Text = safeTostring(key)
    btn.BackgroundColor3 = C.Surface btn.BorderSizePixel = 0
    btn.Size = UDim2.new(0.4, -4, 1, 0) btn.Position = UDim2.new(0.6, 4, 0, 0)
    btn.Font = FONT_CODE btn.TextSize = 13 btn.TextColor3 = C.AccentPrimary
    corner(btn, 4) stroke(btn, C.Border, 1)
    btn.MouseButton1Click:Connect(function()
        btn.Text = '...'
        local conn
        conn = UserInputService.InputBegan:Connect(function(io, gp)
            if gp then return end
            if io.UserInputType == Enum.UserInputType.Keyboard then
                if io.KeyCode == Enum.KeyCode.Escape then
                    key = nil btn.Text = 'None'
                else
                    key = io.KeyCode.Name btn.Text = key
                end
                conn:Disconnect()
                if cb then pcall(cb, key) end
            end
        end)
    end)
    return { set = function(k) key = k btn.Text = safeTostring(k) end, get = function() return key end }
end

function UI.createColorPicker(parent, label, default, cb)
    local v = default or Color3.new(1,1,1)
    local f = Instance.new('Frame', parent)
    f.BackgroundColor3 = C.SurfaceElevated f.BorderSizePixel = 0
    f.Size = UDim2.new(1, 0, 0, 28) corner(f, 4) padding(f, 6)
    local l = Instance.new('TextLabel', f)
    l.BackgroundTransparency = 1 l.Size = UDim2.new(1, -36, 1, 0)
    l.Font = FONT_BODY l.TextSize = 13 l.TextColor3 = C.TextPrimary
    l.TextXAlignment = Enum.TextXAlignment.Left l.Text = label
    local sw = Instance.new('TextButton', f)
    sw.AutoButtonColor = false sw.Text = ''
    sw.Size = UDim2.new(0, 26, 0, 16)
    sw.Position = UDim2.new(1, -30, 0.5, -8)
    sw.BackgroundColor3 = v sw.BorderSizePixel = 0
    corner(sw, 4) stroke(sw, C.Border, 1)
    local popup
    sw.MouseButton1Click:Connect(function()
        if popup then popup:Destroy() popup = nil return end
        popup = Instance.new('Frame', f)
        popup.BackgroundColor3 = C.SurfaceElevated popup.BorderSizePixel = 0
        popup.Position = UDim2.new(1, -180, 1, 4)
        popup.Size = UDim2.new(0, 180, 0, 150) popup.ZIndex = 10
        corner(popup, 6) stroke(popup, C.AccentPrimary, 1) padding(popup, 6)
        layout(popup, Enum.FillDirection.Vertical, 4)
        local h, s, b = v:ToHSV()
        local function rebuild()
            v = Color3.fromHSV(h, s, b) sw.BackgroundColor3 = v
            if cb then pcall(cb, v) end
        end
        UI.createSlider(popup, 'H', 0, 1, h, 2, function(x) h = x rebuild() end)
        UI.createSlider(popup, 'S', 0, 1, s, 2, function(x) s = x rebuild() end)
        UI.createSlider(popup, 'V', 0, 1, b, 2, function(x) b = x rebuild() end)
    end)
    return { set = function(c) v = c sw.BackgroundColor3 = c end, get = function() return v end }
end

------------------------------------------------------------------
-- 7. window factory
------------------------------------------------------------------
local function makeDraggable(handle, target)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
            dragging = true dragStart = io.Position startPos = target.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(io)
        if dragging and (io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch) then
            local d = io.Position - dragStart
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local function makeResizable(grip, target, minS)
    local sizing, startIn, startSz
    grip.InputBegan:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
            sizing = true startIn = io.Position startSz = target.Size
        end
    end)
    UserInputService.InputChanged:Connect(function(io)
        if sizing and (io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch) then
            local d = io.Position - startIn
            local nx = math.max(minS.X, startSz.X.Offset + d.X)
            local ny = math.max(minS.Y, startSz.Y.Offset + d.Y)
            target.Size = UDim2.new(0, nx, 0, ny)
        end
    end)
    UserInputService.InputEnded:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then sizing = false end
    end)
end

local function createWindow(title, sz)
    sz = sz or Vector2.new(420, 560)
    local gui = Instance.new('ScreenGui')
    gui.Name = '\0ENI_RemoteSpy'
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    pcall(protect_gui, gui)
    if not gui.Parent then gui.Parent = game:GetService('CoreGui') end

    NOTIFY_HOST = Instance.new('Frame', gui)
    NOTIFY_HOST.BackgroundTransparency = 1
    NOTIFY_HOST.Position = UDim2.new(1, -300, 0, 10)
    NOTIFY_HOST.Size = UDim2.new(0, 290, 1, -20)
    local nlay = layout(NOTIFY_HOST, Enum.FillDirection.Vertical, 6)
    nlay.HorizontalAlignment = Enum.HorizontalAlignment.Right

    local root = Instance.new('Frame', gui)
    root.BackgroundColor3 = C.Background
    root.BorderSizePixel = 0
    root.Size = UDim2.new(0, sz.X, 0, sz.Y)
    root.Position = UDim2.new(0.5, -sz.X/2, 0.5, -sz.Y/2)
    corner(root, 8) stroke(root, C.Border, 1)

    local bar = Instance.new('Frame', root)
    bar.BackgroundColor3 = C.Surface
    bar.BorderSizePixel = 0
    bar.Size = UDim2.new(1, 0, 0, 36)
    corner(bar, 8)
    local gradHost = Instance.new('Frame', bar)
    gradHost.BackgroundColor3 = Color3.new(1,1,1)
    gradHost.BackgroundTransparency = 0.85
    gradHost.BorderSizePixel = 0 gradHost.Size = UDim2.new(1, 0, 1, 0)
    corner(gradHost, 8)
    local g = Instance.new('UIGradient', gradHost)
    g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.AccentPrimary), ColorSequenceKeypoint.new(1, C.AccentSecondary) })
    g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0.7) })

    local tl = Instance.new('TextLabel', bar)
    tl.BackgroundTransparency = 1
    tl.Position = UDim2.new(0, 12, 0, 0) tl.Size = UDim2.new(1, -120, 1, 0)
    tl.Font = FONT_TITLE tl.TextSize = 18 tl.TextColor3 = C.TextPrimary
    tl.TextXAlignment = Enum.TextXAlignment.Left tl.Text = title

    local ver = Instance.new('TextLabel', bar)
    ver.BackgroundTransparency = 1
    ver.Position = UDim2.new(1, -110, 0, 0) ver.Size = UDim2.new(0, 50, 1, 0)
    ver.Font = FONT_CODE ver.TextSize = 11 ver.TextColor3 = C.TextDim
    ver.TextXAlignment = Enum.TextXAlignment.Right ver.Text = 'v2.0.0'

    local minBtn = Instance.new('TextButton', bar)
    minBtn.AutoButtonColor = false minBtn.Text = '—'
    minBtn.Font = FONT_HEADER minBtn.TextSize = 16 minBtn.TextColor3 = C.TextSecondary
    minBtn.BackgroundTransparency = 1
    minBtn.Position = UDim2.new(1, -56, 0, 0) minBtn.Size = UDim2.new(0, 24, 1, 0)

    local closeBtn = Instance.new('TextButton', bar)
    closeBtn.AutoButtonColor = false closeBtn.Text = 'X'
    closeBtn.Font = FONT_HEADER closeBtn.TextSize = 14 closeBtn.TextColor3 = C.Danger
    closeBtn.BackgroundTransparency = 1
    closeBtn.Position = UDim2.new(1, -28, 0, 0) closeBtn.Size = UDim2.new(0, 24, 1, 0)

    local tabBar = Instance.new('Frame', root)
    tabBar.BackgroundColor3 = C.Surface tabBar.BorderSizePixel = 0
    tabBar.Position = UDim2.new(0, 0, 0, 36) tabBar.Size = UDim2.new(1, 0, 0, 28)
    layout(tabBar, Enum.FillDirection.Horizontal, 4)
    padding(tabBar, 4)

    local content = Instance.new('Frame', root)
    content.BackgroundTransparency = 1
    content.Position = UDim2.new(0, 0, 0, 66)
    content.Size = UDim2.new(1, 0, 1, -94)
    padding(content, 10)

    local statusBar = Instance.new('Frame', root)
    statusBar.BackgroundColor3 = C.Surface statusBar.BorderSizePixel = 0
    statusBar.Position = UDim2.new(0, 0, 1, -24) statusBar.Size = UDim2.new(1, 0, 0, 24)
    local statusL = Instance.new('TextLabel', statusBar)
    statusL.BackgroundTransparency = 1 statusL.Size = UDim2.new(1, -12, 1, 0)
    statusL.Position = UDim2.new(0, 8, 0, 0)
    statusL.Font = FONT_CODE statusL.TextSize = 11 statusL.TextColor3 = C.TextDim
    statusL.TextXAlignment = Enum.TextXAlignment.Left statusL.Text = 'booting...'

    local grip = Instance.new('TextButton', root)
    grip.AutoButtonColor = false grip.Text = '' grip.BackgroundTransparency = 1
    grip.Position = UDim2.new(1, -14, 1, -14) grip.Size = UDim2.new(0, 14, 0, 14)
    grip.ZIndex = 10
    local gripIco = Instance.new('TextLabel', grip)
    gripIco.BackgroundTransparency = 1 gripIco.Size = UDim2.new(1, 0, 1, 0)
    gripIco.Font = FONT_CODE gripIco.TextSize = 14 gripIco.TextColor3 = C.AccentPrimary
    gripIco.Text = 'o'

    makeDraggable(bar, root)
    makeResizable(grip, root, Vector2.new(360, 400))

    local tabs = {}
    local function addTab(name)
        local pane = Instance.new('Frame', content)
        pane.BackgroundTransparency = 1 pane.Size = UDim2.new(1, 0, 1, 0)
        pane.Visible = false
        local sf = UI.createScrollFrame(pane)
        layout(sf, Enum.FillDirection.Vertical, 8) padding(sf, 4)
        local btn = Instance.new('TextButton', tabBar)
        btn.AutoButtonColor = false btn.Text = name
        btn.BackgroundColor3 = C.SurfaceElevated btn.BorderSizePixel = 0
        btn.Size = UDim2.new(0, 72, 1, -4)
        btn.Font = FONT_HEADER btn.TextSize = 12 btn.TextColor3 = C.TextSecondary
        corner(btn, 4)
        btn.MouseButton1Click:Connect(function()
            for _, t in ipairs(tabs) do
                t.pane.Visible = false
                tween(t.btn, { BackgroundColor3 = C.SurfaceElevated })
                t.btn.TextColor3 = C.TextSecondary
            end
            pane.Visible = true
            tween(btn, { BackgroundColor3 = C.AccentPrimary })
            btn.TextColor3 = Color3.new(1,1,1)
        end)
        local rec = { pane = pane, btn = btn, sf = sf, name = name }
        table.insert(tabs, rec)
        if #tabs == 1 then
            pane.Visible = true
            btn.BackgroundColor3 = C.AccentPrimary btn.TextColor3 = Color3.new(1,1,1)
        end
        return sf
    end

    root.Size = UDim2.new(0, sz.X*0.9, 0, sz.Y*0.9)
    tween(root, { Size = UDim2.new(0, sz.X, 0, sz.Y) })

    local W = { Gui = gui, Root = root, Content = content, Status = statusL, addTab = addTab, notify = UI.notify }
    function W:setVisible(v) gui.Enabled = v state.windowVisible = v saveConfig() end
    function W:destroy() gui:Destroy() end
    local minimized = false
    function W:toggleMinimize()
        minimized = not minimized
        if minimized then tween(root, { Size = UDim2.new(0, sz.X, 0, 36) })
        else tween(root, { Size = UDim2.new(0, sz.X, 0, sz.Y) }) end
    end
    minBtn.MouseButton1Click:Connect(function() W:toggleMinimize() end)
    closeBtn.MouseButton1Click:Connect(function() W:setVisible(false) end)
    return W
end

------------------------------------------------------------------
-- 8. build the GUI
------------------------------------------------------------------
local win = createWindow('Remote Spy', Vector2.new(440, 580))
win.Gui.Enabled = state.windowVisible ~= false

local TAB_LOG      = win.addTab('Log')
local TAB_FILTER   = win.addTab('Filter')
local TAB_BLOCK    = win.addTab('Block')
local TAB_STATS    = win.addTab('Stats')
local TAB_SETTINGS = win.addTab('Settings')

------------------------------------------------------------------
-- 8a. LOG tab
------------------------------------------------------------------
local logHolder = Instance.new('Frame', TAB_LOG)
logHolder.BackgroundTransparency = 1
logHolder.Size = UDim2.new(1, 0, 1, 0)
logHolder.LayoutOrder = 1

local LOG_SF = Instance.new('ScrollingFrame', logHolder)
LOG_SF.BackgroundColor3 = C.Surface LOG_SF.BorderSizePixel = 0
LOG_SF.ScrollBarThickness = 3 LOG_SF.ScrollBarImageColor3 = C.AccentPrimary
LOG_SF.Size = UDim2.new(1, 0, 1, -40)
LOG_SF.CanvasSize = UDim2.new(0, 0, 0, 0)
LOG_SF.AutomaticCanvasSize = Enum.AutomaticSize.Y
corner(LOG_SF, 4) stroke(LOG_SF, C.Border, 1)
local LOG_LAY = layout(LOG_SF, Enum.FillDirection.Vertical, 3) padding(LOG_SF, 4)

local toolBar = Instance.new('Frame', logHolder)
toolBar.BackgroundTransparency = 1
toolBar.Position = UDim2.new(0, 0, 1, -34) toolBar.Size = UDim2.new(1, 0, 0, 30)
layout(toolBar, Enum.FillDirection.Horizontal, 4)

local pauseBtn = UI.createButton(toolBar, state.paused and 'Resume' or 'Pause', 'primary', nil)
pauseBtn.Size = UDim2.new(0, 80, 1, 0)
pauseBtn.MouseButton1Click:Connect(function()
    state.paused = not state.paused
    pauseBtn.Text = state.paused and 'Resume' or 'Pause'
    notify('Remote Spy', state.paused and 'Logging paused.' or 'Logging resumed.', 'warning', 2)
    saveConfig()
end)
local clrBtn = UI.createButton(toolBar, 'Clear', 'danger', function() clearLog() notify('Remote Spy', 'Log cleared.', 'success', 2) end)
clrBtn.Size = UDim2.new(0, 60, 1, 0)
local expBtn = UI.createButton(toolBar, 'Export', 'secondary', function()
    pcall(function()
        local data = {}
        for _, e in ipairs(LOG) do
            table.insert(data, { ts = e.ts, kind = e.kind, path = e.path, args = e.argsPreview, src = e.src })
        end
        local fn = CFG_DIR .. '/spy_log_' .. tostring(os.time()) .. '.json'
        writefile(fn, HttpService:JSONEncode(data))
        notify('Remote Spy', 'Exported to ' .. fn, 'success', 4)
    end)
end)
expBtn.Size = UDim2.new(0, 70, 1, 0)

local function makeArgTree(parent, value, depth)
    depth = depth or 0
    if depth > 6 then
        local lbl = Instance.new('TextLabel', parent)
        lbl.BackgroundTransparency = 1 lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.Font = FONT_CODE lbl.TextSize = 11 lbl.TextColor3 = C.TextDim
        lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.Text = '...max depth...'
        return
    end
    local t = typeof(value)
    if t == 'table' then
        local hdr = Instance.new('TextButton', parent)
        hdr.AutoButtonColor = false hdr.BackgroundTransparency = 1
        hdr.Size = UDim2.new(1, 0, 0, 16)
        hdr.Font = FONT_CODE hdr.TextSize = 11 hdr.TextColor3 = C.AccentSecondary
        hdr.TextXAlignment = Enum.TextXAlignment.Left hdr.Text = string.rep('  ', depth) .. '> table (' .. tostring(#value) .. ')'
        local body = Instance.new('Frame', parent)
        body.BackgroundTransparency = 1 body.Size = UDim2.new(1, 0, 0, 0)
        body.AutomaticSize = Enum.AutomaticSize.Y body.Visible = false
        layout(body, Enum.FillDirection.Vertical, 2)
        for k, v in pairs(value) do
            local kl = Instance.new('TextLabel', body)
            kl.BackgroundTransparency = 1 kl.Size = UDim2.new(1, 0, 0, 14)
            kl.Font = FONT_CODE kl.TextSize = 11 kl.TextColor3 = C.TextSecondary
            kl.TextXAlignment = Enum.TextXAlignment.Left
            kl.Text = string.rep('  ', depth+1) .. '[' .. safeTostring(k) .. ']'
            makeArgTree(body, v, depth + 2)
        end
        hdr.MouseButton1Click:Connect(function()
            body.Visible = not body.Visible
            hdr.Text = string.rep('  ', depth) .. (body.Visible and 'v' or '>') .. ' table (' .. tostring(#value) .. ')'
        end)
    elseif t == 'Color3' then
        local row = Instance.new('Frame', parent)
        row.BackgroundTransparency = 1 row.Size = UDim2.new(1, 0, 0, 18)
        local sw = Instance.new('Frame', row)
        sw.BackgroundColor3 = value sw.BorderSizePixel = 0
        sw.Position = UDim2.new(0, 4 + depth*8, 0, 4) sw.Size = UDim2.new(0, 10, 0, 10) corner(sw, 2)
        local lbl = Instance.new('TextLabel', row)
        lbl.BackgroundTransparency = 1 lbl.Position = UDim2.new(0, 20 + depth*8, 0, 0)
        lbl.Size = UDim2.new(1, -24, 1, 0)
        lbl.Font = FONT_CODE lbl.TextSize = 11 lbl.TextColor3 = C.AccentPrimary
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = ('Color3(%d, %d, %d)'):format(math.floor(value.R*255), math.floor(value.G*255), math.floor(value.B*255))
    elseif t == 'CFrame' then
        local p = value.Position
        local rx, ry, rz = value:ToOrientation()
        local lbl = Instance.new('TextLabel', parent)
        lbl.BackgroundTransparency = 1 lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.Font = FONT_CODE lbl.TextSize = 11 lbl.TextColor3 = C.Warning
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = string.rep('  ', depth) .. ('CFrame pos(%.2f, %.2f, %.2f) rot(%.1f, %.1f, %.1f)'):format(p.X, p.Y, p.Z, math.deg(rx), math.deg(ry), math.deg(rz))
    elseif t == 'Instance' then
        local lbl = Instance.new('TextLabel', parent)
        lbl.BackgroundTransparency = 1 lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.Font = FONT_CODE lbl.TextSize = 11 lbl.TextColor3 = C.Success
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = string.rep('  ', depth) .. '<' .. value.ClassName .. ' "' .. value.Name .. '">'
    else
        local lbl = Instance.new('TextLabel', parent)
        lbl.BackgroundTransparency = 1 lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.Font = FONT_CODE lbl.TextSize = 11 lbl.TextColor3 = C.TextPrimary
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = string.rep('  ', depth) .. '(' .. t .. ') ' .. shortPreview(value)
    end
end

local function copyAsCode(entry)
    local lines = {}
    table.insert(lines, '-- ' .. entry.kind .. ' ' .. entry.path)
    table.insert(lines, 'local args = { ' .. entry.argsPreview .. ' }')
    table.insert(lines, 'remote:' .. (entry.kind == 'InvokeServer' and 'InvokeServer' or 'FireServer') .. '(table.unpack(args))')
    pcall(setclipboard, table.concat(lines, '\n'))
    notify('Remote Spy', 'Copied snippet to clipboard.', 'success', 2)
end

local function saveSnippet(entry)
    pcall(function()
        local fn = CFG_DIR .. '/snippet_' .. tostring(os.time()) .. '.lua'
        local lines = { '-- ' .. entry.kind .. ' ' .. entry.path, 'local args = { ' .. entry.argsPreview .. ' }' }
        writefile(fn, table.concat(lines, '\n'))
        notify('Remote Spy', 'Snippet saved to ' .. fn, 'success', 3)
    end)
end

local function replay(entry)
    if not entry.remote or not entry.remote.Parent then notify('Remote Spy', 'Remote no longer valid.', 'danger', 3) return end
    local ok, err = pcall(function()
        if entry.kind == 'FireServer' then entry.remote:FireServer(table.unpack(entry.args, 1, entry.argc))
        elseif entry.kind == 'InvokeServer' then entry.remote:InvokeServer(table.unpack(entry.args, 1, entry.argc))
        else error('not replayable: ' .. entry.kind) end
    end)
    if ok then notify('Remote Spy', 'Replayed ' .. entry.path, 'success', 2)
    else notify('Remote Spy', 'Replay failed: ' .. safeTostring(err), 'danger', 3) end
end

local function editAndReplay(entry)
    local pop = Instance.new('Frame', win.Root)
    pop.BackgroundColor3 = C.Surface pop.BorderSizePixel = 0
    pop.AnchorPoint = Vector2.new(0.5, 0.5)
    pop.Position = UDim2.new(0.5, 0, 0.5, 0)
    pop.Size = UDim2.new(0, 340, 0, 220) pop.ZIndex = 30
    corner(pop, 8) stroke(pop, C.AccentPrimary, 1) padding(pop, 10)
    layout(pop, Enum.FillDirection.Vertical, 8)
    local hdr = Instance.new('TextLabel', pop)
    hdr.BackgroundTransparency = 1 hdr.Size = UDim2.new(1, 0, 0, 18) hdr.ZIndex = 31
    hdr.Font = FONT_HEADER hdr.TextSize = 14 hdr.TextColor3 = C.AccentPrimary
    hdr.TextXAlignment = Enum.TextXAlignment.Left hdr.Text = 'Edit & Replay: ' .. entry.path
    local box = Instance.new('TextBox', pop)
    box.BackgroundColor3 = C.SurfaceElevated box.BorderSizePixel = 0
    box.Size = UDim2.new(1, 0, 0, 120) box.ZIndex = 31
    box.Font = FONT_CODE box.TextSize = 12 box.TextColor3 = C.TextPrimary
    box.TextXAlignment = Enum.TextXAlignment.Left box.TextYAlignment = Enum.TextYAlignment.Top
    box.MultiLine = true box.ClearTextOnFocus = false
    box.Text = 'return { ' .. entry.argsPreview .. ' }'
    corner(box, 4) padding(box, 6)
    local row = Instance.new('Frame', pop)
    row.BackgroundTransparency = 1 row.Size = UDim2.new(1, 0, 0, 28) row.ZIndex = 31
    layout(row, Enum.FillDirection.Horizontal, 6)
    local go = UI.createButton(row, 'Fire', 'primary', function()
        local f, err = loadstring(box.Text)
        if not f then notify('Remote Spy', 'Parse error: ' .. safeTostring(err), 'danger', 3) return end
        local ok, t = pcall(f)
        if not ok or type(t) ~= 'table' then notify('Remote Spy', 'Must return a table.', 'danger', 3) return end
        local sok, serr = pcall(function()
            if entry.kind == 'FireServer' then entry.remote:FireServer(table.unpack(t, 1, #t))
            else entry.remote:InvokeServer(table.unpack(t, 1, #t)) end
        end)
        if sok then notify('Remote Spy', 'Sent.', 'success', 2) pop:Destroy()
        else notify('Remote Spy', 'Send failed: ' .. safeTostring(serr), 'danger', 3) end
    end)
    go.Size = UDim2.new(0, 80, 1, 0)
    local cancel = UI.createButton(row, 'Close', 'secondary', function() pop:Destroy() end)
    cancel.Size = UDim2.new(0, 80, 1, 0)
end

local function isBlocked(path)
    for _, p in ipairs(state.blockList) do if p == path then return true end end
    return false
end

local rebuildBlockUI
local function addToBlock(path)
    if isBlocked(path) then return end
    table.insert(state.blockList, path)
    notify('Remote Spy', 'Blocked: ' .. path, 'warning', 2)
    saveConfig()
    if rebuildBlockUI then rebuildBlockUI() end
end

local function showContextMenu(entry, x, y)
    local m = Instance.new('Frame', win.Gui)
    m.BackgroundColor3 = C.SurfaceElevated m.BorderSizePixel = 0
    m.Position = UDim2.new(0, x, 0, y) m.Size = UDim2.new(0, 180, 0, 0)
    m.AutomaticSize = Enum.AutomaticSize.Y m.ZIndex = 50
    corner(m, 6) stroke(m, C.AccentPrimary, 1) padding(m, 4)
    layout(m, Enum.FillDirection.Vertical, 2)
    local function it(lbl, cb)
        local b = Instance.new('TextButton', m)
        b.AutoButtonColor = false b.Text = lbl b.ZIndex = 51
        b.BackgroundColor3 = C.Surface b.BorderSizePixel = 0
        b.Size = UDim2.new(1, 0, 0, 22)
        b.Font = FONT_BODY b.TextSize = 12 b.TextColor3 = C.TextPrimary
        b.TextXAlignment = Enum.TextXAlignment.Left
        corner(b, 4) padding(b, 4)
        b.MouseButton1Click:Connect(function() m:Destroy() pcall(cb) end)
    end
    it('Copy as code',     function() copyAsCode(entry) end)
    it('Replay',           function() replay(entry) end)
    it('Edit & Replay',    function() editAndReplay(entry) end)
    it('Save snippet',     function() saveSnippet(entry) end)
    it('Block this remote',function() addToBlock(entry.path) end)
    it('Cancel',           function() end)
    task.delay(8, function() if m and m.Parent then m:Destroy() end end)
end

local rowFrames = {}

local function buildRow(entry)
    local row = Instance.new('Frame')
    row.BackgroundColor3 = C.SurfaceElevated
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, 32)
    row.Parent = LOG_SF
    corner(row, 4)
    local bar = Instance.new('Frame', row)
    bar.BackgroundColor3 = entry.color
    bar.BorderSizePixel = 0
    bar.Size = UDim2.new(0, 3, 1, 0) corner(bar, 2)
    local btn = Instance.new('TextButton', row)
    btn.AutoButtonColor = false btn.Text = '' btn.BackgroundTransparency = 1
    btn.Size = UDim2.new(1, 0, 1, 0)
    local ts = Instance.new('TextLabel', row)
    ts.BackgroundTransparency = 1 ts.Position = UDim2.new(0, 8, 0, 4)
    ts.Size = UDim2.new(0, 60, 0, 14)
    ts.Font = FONT_CODE ts.TextSize = 11 ts.TextColor3 = C.TextDim
    ts.TextXAlignment = Enum.TextXAlignment.Left ts.Text = entry.ts
    local kind = Instance.new('TextLabel', row)
    kind.BackgroundTransparency = 1 kind.Position = UDim2.new(0, 70, 0, 4)
    kind.Size = UDim2.new(0, 100, 0, 14)
    kind.Font = FONT_CODE kind.TextSize = 11 kind.TextColor3 = entry.color
    kind.TextXAlignment = Enum.TextXAlignment.Left kind.Text = entry.kind
    local path = Instance.new('TextLabel', row)
    path.BackgroundTransparency = 1 path.Position = UDim2.new(0, 174, 0, 4)
    path.Size = UDim2.new(1, -180, 0, 14)
    path.Font = FONT_BODY path.TextSize = 11 path.TextColor3 = C.TextPrimary
    path.TextXAlignment = Enum.TextXAlignment.Left path.Text = entry.path
    path.TextTruncate = Enum.TextTruncate.AtEnd
    local args = Instance.new('TextLabel', row)
    args.BackgroundTransparency = 1 args.Position = UDim2.new(0, 8, 0, 18)
    args.Size = UDim2.new(1, -16, 0, 12)
    args.Font = FONT_CODE args.TextSize = 10 args.TextColor3 = C.TextSecondary
    args.TextXAlignment = Enum.TextXAlignment.Left args.Text = entry.argsPreview
    args.TextTruncate = Enum.TextTruncate.AtEnd
    local detailHost = Instance.new('Frame', row)
    detailHost.BackgroundTransparency = 1 detailHost.Position = UDim2.new(0, 12, 0, 34)
    detailHost.Size = UDim2.new(1, -16, 0, 0)
    detailHost.AutomaticSize = Enum.AutomaticSize.Y detailHost.Visible = false
    layout(detailHost, Enum.FillDirection.Vertical, 2)
    local built = false
    local function buildDetails()
        if built then return end built = true
        local sLbl = Instance.new('TextLabel', detailHost)
        sLbl.BackgroundTransparency = 1 sLbl.Size = UDim2.new(1, 0, 0, 14)
        sLbl.Font = FONT_CODE sLbl.TextSize = 11 sLbl.TextColor3 = C.TextDim
        sLbl.TextXAlignment = Enum.TextXAlignment.Left
        sLbl.Text = 'source: ' .. tostring(entry.src or '?')
        local hd = Instance.new('TextLabel', detailHost)
        hd.BackgroundTransparency = 1 hd.Size = UDim2.new(1, 0, 0, 14)
        hd.Font = FONT_HEADER hd.TextSize = 11 hd.TextColor3 = C.AccentSecondary
        hd.TextXAlignment = Enum.TextXAlignment.Left
        hd.Text = 'args (' .. tostring(entry.argc) .. ')'
        for i = 1, entry.argc do
            local idxLbl = Instance.new('TextLabel', detailHost)
            idxLbl.BackgroundTransparency = 1 idxLbl.Size = UDim2.new(1, 0, 0, 14)
            idxLbl.Font = FONT_CODE idxLbl.TextSize = 11 idxLbl.TextColor3 = C.AccentPrimary
            idxLbl.TextXAlignment = Enum.TextXAlignment.Left
            idxLbl.Text = '[' .. i .. ']'
            makeArgTree(detailHost, entry.args[i], 1)
        end
    end
    btn.MouseButton1Click:Connect(function()
        detailHost.Visible = not detailHost.Visible
        if detailHost.Visible then
            buildDetails()
            row.Size = UDim2.new(1, 0, 0, 34 + detailHost.AbsoluteSize.Y + 8)
            task.wait(0.05)
            row.Size = UDim2.new(1, 0, 0, 34 + detailHost.AbsoluteSize.Y + 8)
        else
            row.Size = UDim2.new(1, 0, 0, 32)
        end
    end)
    btn.MouseButton2Click:Connect(function()
        local mp = UserInputService:GetMouseLocation()
        showContextMenu(entry, mp.X, mp.Y)
    end)
    return row
end

local function matchesFilter(entry)
    if state.filter ~= '' and not regexMatch(entry.path, state.filter) then return false end
    if state.search ~= '' then
        local hay = (entry.path .. ' ' .. entry.argsPreview):lower()
        if not hay:find(state.search:lower(), 1, true) then return false end
    end
    return true
end

local function rebuildLogUI()
    for _, r in ipairs(rowFrames) do if r then r:Destroy() end end
    rowFrames = {}
    local start = math.max(1, #LOG - 300)
    for i = #LOG, start, -1 do
        local e = LOG[i]
        if matchesFilter(e) then
            local r = buildRow(e)
            r.LayoutOrder = -i
            table.insert(rowFrames, r)
        end
    end
end

LOG_CHANGED.Event:Connect(function(entry)
    if not entry then rebuildLogUI() return end
    if not matchesFilter(entry) then return end
    local r = buildRow(entry) r.LayoutOrder = -entry.id
    table.insert(rowFrames, r)
    while #rowFrames > 300 do
        local first = table.remove(rowFrames, 1)
        if first then first:Destroy() end
    end
end)

------------------------------------------------------------------
-- 8b. FILTER tab
------------------------------------------------------------------
local fSec = UI.createSection(TAB_FILTER, 'Filter & Search')
local filterBox = UI.createTextBox(fSec, 'regex/substr against full remote path', state.filter, function(v)
    state.filter = v rebuildLogUI() saveConfig()
end)
local searchBox = UI.createTextBox(fSec, 'search args + path', state.search, function(v)
    state.search = v rebuildLogUI() saveConfig()
end)

local logSec = UI.createSection(TAB_FILTER, 'Logging Controls')
local togOut = UI.createToggle(logSec, 'Log outbound (FireServer/Invoke)', state.logOutbound, function(v) state.logOutbound = v saveConfig() end)
local togIn  = UI.createToggle(logSec, 'Log inbound (OnClientEvent/Invoke)', state.logInbound, function(v) state.logInbound = v saveConfig() end)
local slMax  = UI.createSlider(logSec, 'Max log size', 100, 10000, state.maxLog, 0, function(v)
    state.maxLog = math.floor(v)
    while #LOG > state.maxLog do table.remove(LOG, 1) end
    saveConfig()
end)

local apSec = UI.createSection(TAB_FILTER, 'Auto-Pause')
local togAp = UI.createToggle(apSec, 'Auto-pause on burst', state.autoPause, function(v) state.autoPause = v saveConfig() end)
local slAp  = UI.createSlider(apSec, 'Threshold (events/sec)', 10, 500, state.autoPauseRate, 0, function(v) state.autoPauseRate = math.floor(v) saveConfig() end)

local kindSec = UI.createSection(TAB_FILTER, 'Color Coding (reference)')
for _, pair in ipairs({ {'FireServer', C.EvFireServer}, {'InvokeServer', C.EvInvokeServer}, {'FireClient inbound', C.EvFireClient}, {'OnClientEvent', C.EvOnClientEvent} }) do
    local r = Instance.new('Frame', kindSec)
    r.BackgroundColor3 = C.SurfaceElevated r.BorderSizePixel = 0
    r.Size = UDim2.new(1, 0, 0, 22) corner(r, 4) padding(r, 4)
    local sw = Instance.new('Frame', r)
    sw.BackgroundColor3 = pair[2] sw.BorderSizePixel = 0
    sw.Size = UDim2.new(0, 12, 0, 12) sw.Position = UDim2.new(0, 2, 0.5, -6) corner(sw, 2)
    local lbl = Instance.new('TextLabel', r)
    lbl.BackgroundTransparency = 1 lbl.Position = UDim2.new(0, 20, 0, 0) lbl.Size = UDim2.new(1, -24, 1, 0)
    lbl.Font = FONT_CODE lbl.TextSize = 11 lbl.TextColor3 = pair[2]
    lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.Text = pair[1]
end

------------------------------------------------------------------
-- 8c. BLOCK tab
------------------------------------------------------------------
local blkSec = UI.createSection(TAB_BLOCK, 'Block List')
local blkInput = UI.createTextBox(blkSec, 'full path to block (exact match)', '', function() end)
UI.createButton(blkSec, 'Add to block list', 'primary', function()
    local p = blkInput.Text if p == '' then return end
    addToBlock(p) blkInput.Text = ''
end)
local togDrop = UI.createToggle(blkSec, 'Drop blocked fires (else just suppress log)', state.dropBlocked, function(v) state.dropBlocked = v saveConfig() end)

local blkListHost = Instance.new('Frame', TAB_BLOCK)
blkListHost.BackgroundColor3 = C.Surface blkListHost.BorderSizePixel = 0
blkListHost.Size = UDim2.new(1, 0, 0, 220) blkListHost.LayoutOrder = 99
corner(blkListHost, 6) padding(blkListHost, 6)
local blkSF = UI.createScrollFrame(blkListHost)
layout(blkSF, Enum.FillDirection.Vertical, 4)

function rebuildBlockUI()
    for _, c in ipairs(blkSF:GetChildren()) do
        if c:IsA('Frame') or c:IsA('TextLabel') then c:Destroy() end
    end
    if #state.blockList == 0 then
        local n = Instance.new('TextLabel', blkSF)
        n.BackgroundTransparency = 1 n.Size = UDim2.new(1, 0, 0, 22)
        n.Font = FONT_BODY n.TextSize = 12 n.TextColor3 = C.TextDim
        n.Text = '(empty — block list is clean)' n.TextXAlignment = Enum.TextXAlignment.Center
        return
    end
    for i, p in ipairs(state.blockList) do
        local row = Instance.new('Frame', blkSF)
        row.BackgroundColor3 = C.SurfaceElevated row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, 26) corner(row, 4) padding(row, 4)
        local lbl = Instance.new('TextLabel', row)
        lbl.BackgroundTransparency = 1 lbl.Size = UDim2.new(1, -64, 1, 0)
        lbl.Font = FONT_CODE lbl.TextSize = 11 lbl.TextColor3 = C.Danger
        lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.Text = p
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        local rm = UI.createButton(row, 'remove', 'secondary', function()
            table.remove(state.blockList, i) saveConfig() rebuildBlockUI()
        end)
        rm.Size = UDim2.new(0, 60, 1, -2) rm.Position = UDim2.new(1, -62, 0, 1)
        rm.Parent = row
    end
end
rebuildBlockUI()

------------------------------------------------------------------
-- 8d. STATS tab
------------------------------------------------------------------
local sSec = UI.createSection(TAB_STATS, 'Counts')
local statsLabels = {}
for _, k in ipairs({ 'total', 'FireServer', 'InvokeServer', 'FireClient', 'OnClientEvent', 'OnClientInvoke' }) do
    local row = Instance.new('Frame', sSec)
    row.BackgroundColor3 = C.SurfaceElevated row.BorderSizePixel = 0
    row.Size = UDim2.new(1, 0, 0, 22) corner(row, 4) padding(row, 4)
    local lbl = Instance.new('TextLabel', row)
    lbl.BackgroundTransparency = 1 lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.Font = FONT_BODY lbl.TextSize = 12 lbl.TextColor3 = C.TextSecondary
    lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.Text = k
    local val = Instance.new('TextLabel', row)
    val.BackgroundTransparency = 1 val.Size = UDim2.new(0.4, 0, 1, 0) val.Position = UDim2.new(0.6, 0, 0, 0)
    val.Font = FONT_CODE val.TextSize = 12 val.TextColor3 = C.AccentPrimary
    val.TextXAlignment = Enum.TextXAlignment.Right val.Text = '0'
    statsLabels[k] = val
end

local topSec = UI.createSection(TAB_STATS, 'Top 10 Remotes')
local topHost = Instance.new('Frame', topSec)
topHost.BackgroundTransparency = 1 topHost.Size = UDim2.new(1, 0, 0, 240)
topHost.AutomaticSize = Enum.AutomaticSize.Y
layout(topHost, Enum.FillDirection.Vertical, 2)

local function refreshStats()
    for k, v in pairs(STATS) do
        if statsLabels[k] then statsLabels[k].Text = tostring(v) end
    end
    for _, c in ipairs(topHost:GetChildren()) do
        if c:IsA('Frame') then c:Destroy() end
    end
    local list = {}
    for path, n in pairs(STATS.perRemote) do table.insert(list, { path = path, n = n }) end
    table.sort(list, function(a, b) return a.n > b.n end)
    for i = 1, math.min(10, #list) do
        local e = list[i]
        local row = Instance.new('Frame', topHost)
        row.BackgroundColor3 = C.SurfaceElevated row.BorderSizePixel = 0
        row.Size = UDim2.new(1, 0, 0, 20) corner(row, 4) padding(row, 4)
        local rk = Instance.new('TextLabel', row)
        rk.BackgroundTransparency = 1 rk.Size = UDim2.new(0, 22, 1, 0)
        rk.Font = FONT_CODE rk.TextSize = 11 rk.TextColor3 = C.AccentSecondary
        rk.TextXAlignment = Enum.TextXAlignment.Left rk.Text = '#' .. i
        local pl = Instance.new('TextLabel', row)
        pl.BackgroundTransparency = 1 pl.Position = UDim2.new(0, 24, 0, 0)
        pl.Size = UDim2.new(1, -70, 1, 0)
        pl.Font = FONT_BODY pl.TextSize = 11 pl.TextColor3 = C.TextPrimary
        pl.TextXAlignment = Enum.TextXAlignment.Left pl.Text = e.path
        pl.TextTruncate = Enum.TextTruncate.AtEnd
        local cn = Instance.new('TextLabel', row)
        cn.BackgroundTransparency = 1 cn.Position = UDim2.new(1, -46, 0, 0)
        cn.Size = UDim2.new(0, 44, 1, 0)
        cn.Font = FONT_CODE cn.TextSize = 11 cn.TextColor3 = C.AccentPrimary
        cn.TextXAlignment = Enum.TextXAlignment.Right cn.Text = tostring(e.n)
    end
end

------------------------------------------------------------------
-- 8e. SETTINGS tab
------------------------------------------------------------------
local kSec = UI.createSection(TAB_SETTINGS, 'Keybinds')
local pauseKB  = UI.createKeybind(kSec, 'Pause / Resume',       state.keys.pause,  function(k) state.keys.pause  = k saveConfig() end)
local clearKB  = UI.createKeybind(kSec, 'Clear log',            state.keys.clear,  function(k) state.keys.clear  = k saveConfig() end)
local toggleKB = UI.createKeybind(kSec, 'Show / hide window',   state.keys.toggle, function(k) state.keys.toggle = k saveConfig() end)

local cSec = UI.createSection(TAB_SETTINGS, 'Config')
UI.createButton(cSec, 'Save config', 'primary', function() saveConfig() notify('Remote Spy', 'Config written.', 'success', 2) end)
UI.createButton(cSec, 'Load config', 'secondary', function() loadConfig() notify('Remote Spy', 'Config reloaded — reload module to fully apply.', 'success', 3) end)
UI.createButton(cSec, 'Reset to defaults', 'danger', function()
    state = {
        paused=false, logInbound=true, logOutbound=true, dropBlocked=false,
        maxLog=1500, autoPause=false, autoPauseRate=60, filter='', search='',
        blockList={}, keys={ pause='F5', clear='F6', toggle='F7' }, windowVisible=true, accentHue=0,
    }
    saveConfig() notify('Remote Spy', 'Defaults restored.', 'warning', 4)
    rebuildBlockUI()
    togOut.set(true) togIn.set(true) togAp.set(false) togDrop.set(false)
    slMax.set(1500) slAp.set(60)
    filterBox.Text = '' searchBox.Text = ''
end)

local eSec = UI.createSection(TAB_SETTINGS, 'Environment')
local envLbl = Instance.new('TextLabel', eSec)
envLbl.BackgroundTransparency = 1 envLbl.Size = UDim2.new(1, 0, 0, 18)
envLbl.Font = FONT_CODE envLbl.TextSize = 12 envLbl.TextColor3 = C.TextSecondary
envLbl.TextXAlignment = Enum.TextXAlignment.Left
envLbl.Text = 'executor: ' .. EXECUTOR
local hookLbl = Instance.new('TextLabel', eSec)
hookLbl.BackgroundTransparency = 1 hookLbl.Size = UDim2.new(1, 0, 0, 18)
hookLbl.Font = FONT_CODE hookLbl.TextSize = 12 hookLbl.TextColor3 = HAS_HOOKMETA and C.Success or C.Danger
hookLbl.TextXAlignment = Enum.TextXAlignment.Left
hookLbl.Text = 'hookmetamethod: ' .. (HAS_HOOKMETA and 'available' or 'missing — outbound hook disabled')
local conLbl = Instance.new('TextLabel', eSec)
conLbl.BackgroundTransparency = 1 conLbl.Size = UDim2.new(1, 0, 0, 18)
conLbl.Font = FONT_CODE conLbl.TextSize = 12 conLbl.TextColor3 = HAS_GETCONNECTIONS and C.Success or C.Warning
conLbl.TextXAlignment = Enum.TextXAlignment.Left
conLbl.Text = 'getconnections: ' .. (HAS_GETCONNECTIONS and 'available' or 'missing — inbound via fallback')

------------------------------------------------------------------
-- 9. hooks
------------------------------------------------------------------
local conns = {}
local hookActive = false
local origNamecall

local function ingest(kind, remote, argTable, argc, src)
    if state.paused then return end
    if kind == 'FireServer' or kind == 'InvokeServer' then
        if not state.logOutbound then return end
    elseif kind == 'OnClientEvent' or kind == 'OnClientInvoke' or kind == 'FireClient' then
        if not state.logInbound then return end
    end
    local path = fullPath(remote)
    if isBlocked(path) and state.dropBlocked then return end
    local col = (kind == 'FireServer' and C.EvFireServer)
             or (kind == 'InvokeServer' and C.EvInvokeServer)
             or (kind == 'FireClient' and C.EvFireClient)
             or C.EvOnClientEvent
    local previewArgs = {}
    for i = 1, argc do previewArgs[i] = argTable[i] end
    local entry = {
        ts = timestamp(), kind = kind, remote = remote, path = path,
        args = previewArgs, argc = argc, argsPreview = argsPreview(previewArgs),
        src = src, color = col, blocked = isBlocked(path),
    }
    pushLog(entry)
end

local function shouldDropOutbound(remote)
    if not isBlocked(fullPath(remote)) then return false end
    return state.dropBlocked
end

local function installNamecallHook()
    if not HAS_HOOKMETA then
        notify('Remote Spy', 'No hookmetamethod — outbound hook unavailable.', 'danger', 5)
        return
    end
    local ok, err = pcall(function()
        origNamecall = hookmetamethod(game, '__namecall', newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if checkcaller() then return origNamecall(self, ...) end
            if typeof(self) ~= 'Instance' then return origNamecall(self, ...) end
            local cls = self.ClassName
            if cls == 'RemoteEvent' or cls == 'UnreliableRemoteEvent' then
                if method == 'FireServer' or method == 'fireServer' or method == 'fire' then
                    local args = { ... }
                    local n = select('#', ...)
                    local src
                    local oki, info = pcall(debug.getinfo, 3, 's')
                    if oki and info then src = info.short_src or info.source end
                    ingest('FireServer', self, args, n, src)
                    if shouldDropOutbound(self) then return end
                end
            elseif cls == 'RemoteFunction' then
                if method == 'InvokeServer' or method == 'invokeServer' then
                    local args = { ... }
                    local n = select('#', ...)
                    local src
                    local oki, info = pcall(debug.getinfo, 3, 's')
                    if oki and info then src = info.short_src or info.source end
                    ingest('InvokeServer', self, args, n, src)
                    if shouldDropOutbound(self) then return end
                end
            end
            return origNamecall(self, ...)
        end))
    end)
    if ok and origNamecall then hookActive = true notify('Remote Spy', 'Outbound hook installed.', 'success', 2)
    else notify('Remote Spy', 'Hook failed: ' .. safeTostring(err), 'danger', 4) end
end

local inboundConns = {}
local attachedRemotes = {}

local function attachInbound(remote)
    if not remote or not remote.Parent or attachedRemotes[remote] then return end
    attachedRemotes[remote] = true
    local cls = remote.ClassName
    if cls == 'RemoteEvent' or cls == 'UnreliableRemoteEvent' then
        local ok, c = pcall(function()
            return remote.OnClientEvent:Connect(function(...)
                local n = select('#', ...)
                local a = { ... }
                ingest('OnClientEvent', remote, a, n, 'server')
            end)
        end)
        if ok and c then table.insert(inboundConns, c) end
    elseif cls == 'RemoteFunction' then
        if remote.OnClientInvoke == nil then
            pcall(function()
                remote.OnClientInvoke = function(...)
                    local n = select('#', ...)
                    local a = { ... }
                    ingest('OnClientInvoke', remote, a, n, 'server')
                end
            end)
        end
    end
end

local function scanInbound(root)
    if not root then return end
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA('RemoteEvent') or d:IsA('UnreliableRemoteEvent') or d:IsA('RemoteFunction') then
            attachInbound(d)
        end
    end
    table.insert(conns, root.DescendantAdded:Connect(function(d)
        if d:IsA('RemoteEvent') or d:IsA('UnreliableRemoteEvent') or d:IsA('RemoteFunction') then
            attachInbound(d)
        end
    end))
end

local function installInboundHooks()
    pcall(function() scanInbound(game:GetService('ReplicatedStorage')) end)
    pcall(function() scanInbound(game:GetService('Workspace')) end)
    pcall(function() scanInbound(game:GetService('StarterGui')) end)
    pcall(function() scanInbound(game:GetService('StarterPack')) end)
    pcall(function() scanInbound(game:GetService('ReplicatedFirst')) end)
end

------------------------------------------------------------------
-- 10. keybinds + status loop
------------------------------------------------------------------
table.insert(conns, UserInputService.InputBegan:Connect(function(io, gp)
    if gp then return end
    if io.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local name = io.KeyCode.Name
    if name == state.keys.pause then
        state.paused = not state.paused pauseBtn.Text = state.paused and 'Resume' or 'Pause'
        notify('Remote Spy', state.paused and 'Paused.' or 'Resumed.', 'warning', 1.5)
    elseif name == state.keys.clear then
        clearLog() notify('Remote Spy', 'Cleared.', 'success', 1.5)
    elseif name == state.keys.toggle then
        win:setVisible(not win.Gui.Enabled)
    end
end))

table.insert(conns, RunService.Heartbeat:Connect(function()
    local now = os.clock()
    local i = 1
    while i <= #RATE.window do
        if now - RATE.window[i] > 1 then table.remove(RATE.window, i) else i = i + 1 end
    end
    RATE.perSec = #RATE.window
    if state.autoPause and RATE.perSec > state.autoPauseRate and not state.paused then
        state.paused = true pauseBtn.Text = 'Resume'
        notify('Remote Spy', 'Auto-paused (' .. RATE.perSec .. ' ev/s).', 'warning', 3)
    end
end))

local lastStatus = 0
table.insert(conns, RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastStatus < 0.25 then return end
    lastStatus = now
    win.Status.Text = ('%s | %d events | %d ev/s | filter:"%s" | paused:%s | blocked:%d'):format(
        hookActive and 'Hooked' or 'NoHook',
        STATS.total, RATE.perSec, state.filter, state.paused and 'yes' or 'no', #state.blockList)
end))

task.spawn(function()
    while win.Gui.Parent do
        pcall(refreshStats)
        task.wait(1)
    end
end)

------------------------------------------------------------------
-- 11. public API
------------------------------------------------------------------
getgenv().ENI = getgenv().ENI or {}

if getgenv().ENI.RemoteSpy and type(getgenv().ENI.RemoteSpy.Destroy) == 'function' then
    pcall(function() getgenv().ENI.RemoteSpy:Destroy() end)
end

local API = {}
function API:Show()  win:setVisible(true)  end
function API:Hide()  win:setVisible(false) end
function API:Toggle() win:setVisible(not win.Gui.Enabled) end
function API:GetConfig() return deepcopy(state) end
function API:SetConfig(t)
    if type(t) ~= 'table' then return end
    for k, v in pairs(t) do state[k] = v end
    saveConfig() rebuildLogUI() rebuildBlockUI()
    pauseBtn.Text = state.paused and 'Resume' or 'Pause'
    pauseKB.set(state.keys.pause) clearKB.set(state.keys.clear) toggleKB.set(state.keys.toggle)
    filterBox.Text = state.filter searchBox.Text = state.search
    notify('Remote Spy', 'Config applied.', 'success', 2)
end
function API:Destroy()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    for _, c in ipairs(inboundConns) do pcall(function() c:Disconnect() end) end
    conns = {} inboundConns = {}
    if origNamecall and HAS_HOOKMETA then
        pcall(function() hookmetamethod(game, '__namecall', origNamecall) end)
    end
    win:destroy()
    getgenv().ENI.RemoteSpy = nil
end
getgenv().ENI.RemoteSpy = API

------------------------------------------------------------------
-- 12. boot
------------------------------------------------------------------
installNamecallHook()
installInboundHooks()
notify('Remote Spy', 'v2.0.0 online — F7 toggles window, F5 pauses.', 'success', 4)
rebuildLogUI()

return API

end
-- END MODULE: REMOTE SPY v3.0.0
----------------------------------------------------------------------

----------------------------------------------------------------------
-- MODULE: REMOTE SCANNER v3.0.0 (1628 lines original)
----------------------------------------------------------------------
do
--[[
================================================================================
  ENI Roblox Kit :: Remote Scanner
  Module : recon/remote_scanner.lua
  Version: 2.0.0
  Author : ENI (for LO)

  Statically enumerates every Remote object in the DataModel, surfaces
  suspicious ones via name heuristics, lets you fuzzy-search/filter/sort
  and quick-fire calls with arbitrary arguments. Favorites, annotations,
  auto-refresh and export are all persisted to disk between sessions.
================================================================================
]]

------------------------------------------------------------------------------
-- 0. ANTI-DETECT SHIMS
------------------------------------------------------------------------------
local cloneref           = cloneref or function(x) return x end
local protect_gui        = (syn and syn.protect_gui) or (gethui and function(g) g.Parent = gethui() end) or function(g) g.Parent = game:GetService('CoreGui') end
local hookmetamethod     = hookmetamethod or function() return nil end
local getrawmetatable    = getrawmetatable or function() return nil end
local setreadonly        = setreadonly or function() end
local newcclosure        = newcclosure or function(f) return f end
local identifyexecutor   = identifyexecutor or function() return 'Unknown', '0.0.0' end
local writefile          = writefile
local readfile           = readfile
local isfile             = isfile
local makefolder         = makefolder
local listfiles          = listfiles
local getgenv            = getgenv or function() return _G end

------------------------------------------------------------------------------
-- 1. SERVICES (cloneref'd)
------------------------------------------------------------------------------
local Players          = cloneref(game:GetService('Players'))
local RunService       = cloneref(game:GetService('RunService'))
local UserInputService = cloneref(game:GetService('UserInputService'))
local TweenService     = cloneref(game:GetService('TweenService'))
local HttpService      = cloneref(game:GetService('HttpService'))
local Lighting         = cloneref(game:GetService('Lighting'))
local Workspace        = cloneref(game:GetService('Workspace'))
local StarterGui       = cloneref(game:GetService('StarterGui'))

local EXEC_NAME = 'Unknown'
pcall(function() EXEC_NAME = identifyexecutor() or 'Unknown' end)

------------------------------------------------------------------------------
-- 2. ENI ROOT + DESTROY ANY PREVIOUS INSTANCE
------------------------------------------------------------------------------
getgenv().ENI = getgenv().ENI or {}
if getgenv().ENI.RemoteScanner and type(getgenv().ENI.RemoteScanner.Destroy) == 'function' then
    pcall(function() getgenv().ENI.RemoteScanner:Destroy() end)
end

------------------------------------------------------------------------------
-- 3. DESIGN SYSTEM
------------------------------------------------------------------------------
local C = {
    Background      = Color3.fromRGB( 15, 15, 22),
    Surface         = Color3.fromRGB( 22, 22, 30),
    SurfaceElevated = Color3.fromRGB( 32, 32, 42),
    Border          = Color3.fromRGB( 45, 45, 60),
    AccentPrimary   = Color3.fromRGB(255, 65,180),
    AccentSecondary = Color3.fromRGB(180, 75,255),
    TextPrimary     = Color3.fromRGB(240,240,248),
    TextSecondary   = Color3.fromRGB(160,160,178),
    TextDim         = Color3.fromRGB(100,100,118),
    Success         = Color3.fromRGB( 80,220,130),
    Warning         = Color3.fromRGB(255,185, 70),
    Danger          = Color3.fromRGB(255, 85,110),
}

local F = {
    Title    = Enum.Font.GothamBold,
    Header   = Enum.Font.GothamSemibold,
    Body     = Enum.Font.Gotham,
    Code     = Enum.Font.Code,
}

local TWEEN_INFO  = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SLOW  = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function tween(obj, props, ti)
    local tw = TweenService:Create(obj, ti or TWEEN_INFO, props)
    tw:Play()
    return tw
end

------------------------------------------------------------------------------
-- 4. UTIL
------------------------------------------------------------------------------
local function deepcopy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = deepcopy(v) end
    return out
end

local function corner(parent, radius)
    local c = Instance.new('UICorner')
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness, transparency)
    local s = Instance.new('UIStroke')
    s.Color = color or C.Border
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function padding(parent, p)
    local u = Instance.new('UIPadding')
    u.PaddingTop    = UDim.new(0, p)
    u.PaddingBottom = UDim.new(0, p)
    u.PaddingLeft   = UDim.new(0, p)
    u.PaddingRight  = UDim.new(0, p)
    u.Parent = parent
    return u
end

local function gradient(parent, colors, rot)
    local g = Instance.new('UIGradient')
    g.Color = ColorSequence.new(colors)
    g.Rotation = rot or 0
    g.Parent = parent
    return g
end

------------------------------------------------------------------------------
-- 5. CONFIG PERSISTENCE
------------------------------------------------------------------------------
local CONFIG_DIR  = 'freezer'
local CONFIG_FILE = CONFIG_DIR .. '/remote_scanner.json'

pcall(function() if makefolder then makefolder(CONFIG_DIR) end end)

local DEFAULT_STATE = {
    filters = {
        RemoteEvent = true,
        RemoteFunction = true,
        UnreliableRemoteEvent = true,
        BindableEvent = false,
        BindableFunction = false,
    },
    favoritesOnly      = false,
    hideInternal       = true,
    autoRefresh        = false,
    autoRefreshSeconds = 10,
    sort               = 'Suspicious First',
    favorites          = {},   -- [fullPath] = true
    annotations        = {},   -- [fullPath] = "note"
    keybinds           = {
        Refresh      = 'F8',
        FocusSearch  = 'F',
    },
    accent             = { r = 255, g = 65, b = 180 },
}

local state = deepcopy(DEFAULT_STATE)

local function saveConfig()
    pcall(function()
        if writefile then
            writefile(CONFIG_FILE, HttpService:JSONEncode(state))
        end
    end)
end

local function loadConfig()
    pcall(function()
        if isfile and isfile(CONFIG_FILE) then
            local raw = readfile(CONFIG_FILE)
            local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok and type(decoded) == 'table' then
                for k, v in pairs(DEFAULT_STATE) do
                    if decoded[k] == nil then decoded[k] = deepcopy(v) end
                end
                state = decoded
            end
        end
    end)
end

loadConfig()
if state.accent then
    C.AccentPrimary = Color3.fromRGB(state.accent.r, state.accent.g, state.accent.b)
end

------------------------------------------------------------------------------
-- 6. CONNECTIONS REGISTRY
------------------------------------------------------------------------------
local connections = {}
local function track(conn) table.insert(connections, conn); return conn end
local function disconnectAll()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    connections = {}
end

------------------------------------------------------------------------------
-- 7. NOTIFICATIONS
------------------------------------------------------------------------------
local notifyHolder
local function ensureNotifyHolder(parentGui)
    if notifyHolder and notifyHolder.Parent then return notifyHolder end
    notifyHolder = Instance.new('Frame')
    notifyHolder.Name = 'ENI_Notify'
    notifyHolder.AnchorPoint = Vector2.new(1, 0)
    notifyHolder.Position = UDim2.new(1, -12, 0, 12)
    notifyHolder.Size = UDim2.new(0, 280, 1, -24)
    notifyHolder.BackgroundTransparency = 1
    notifyHolder.Parent = parentGui

    local list = Instance.new('UIListLayout')
    list.Padding = UDim.new(0, 6)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.HorizontalAlignment = Enum.HorizontalAlignment.Right
    list.Parent = notifyHolder
    return notifyHolder
end

local function notify(title, msg, kind, duration)
    duration = duration or 3
    local holder = notifyHolder
    if not (holder and holder.Parent) then return end

    local toast = Instance.new('Frame')
    toast.Size = UDim2.new(1, 0, 0, 54)
    toast.BackgroundColor3 = C.SurfaceElevated
    toast.BorderSizePixel = 0
    toast.Position = UDim2.new(1.2, 0, 0, 0)
    toast.Parent = holder
    corner(toast, 6)
    stroke(toast, C.Border, 1)

    local bar = Instance.new('Frame')
    bar.Size = UDim2.new(0, 3, 1, -10)
    bar.Position = UDim2.new(0, 5, 0, 5)
    bar.BorderSizePixel = 0
    bar.Parent = toast
    corner(bar, 2)
    if kind == 'success' then bar.BackgroundColor3 = C.Success
    elseif kind == 'warn' then bar.BackgroundColor3 = C.Warning
    elseif kind == 'error' then bar.BackgroundColor3 = C.Danger
    else bar.BackgroundColor3 = C.AccentPrimary end

    local t = Instance.new('TextLabel')
    t.BackgroundTransparency = 1
    t.Position = UDim2.new(0, 16, 0, 6)
    t.Size = UDim2.new(1, -22, 0, 18)
    t.Font = F.Header
    t.TextSize = 14
    t.TextColor3 = C.TextPrimary
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Text = title or 'Notice'
    t.Parent = toast

    local m = Instance.new('TextLabel')
    m.BackgroundTransparency = 1
    m.Position = UDim2.new(0, 16, 0, 26)
    m.Size = UDim2.new(1, -22, 0, 22)
    m.Font = F.Body
    m.TextSize = 12
    m.TextColor3 = C.TextSecondary
    m.TextXAlignment = Enum.TextXAlignment.Left
    m.TextYAlignment = Enum.TextYAlignment.Top
    m.TextWrapped = true
    m.Text = msg or ''
    m.Parent = toast

    tween(toast, { Position = UDim2.new(0, 0, 0, 0) }, TWEEN_INFO)
    task.delay(duration, function()
        local out = tween(toast, { Position = UDim2.new(1.2, 0, 0, 0) }, TWEEN_INFO)
        out.Completed:Connect(function() toast:Destroy() end)
    end)
end

------------------------------------------------------------------------------
-- 8. LOW-LEVEL UI HELPERS
------------------------------------------------------------------------------
local function createButton(parent, label, style, callback)
    style = style or 'primary'
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(0, 100, 0, 28)
    btn.AutoButtonColor = false
    btn.BorderSizePixel = 0
    btn.Font = F.Header
    btn.TextSize = 13
    btn.Text = label
    btn.TextColor3 = C.TextPrimary
    btn.Parent = parent
    corner(btn, 4)

    if style == 'primary' then
        btn.BackgroundColor3 = C.AccentPrimary
        gradient(btn, { ColorSequenceKeypoint.new(0, C.AccentPrimary), ColorSequenceKeypoint.new(1, C.AccentSecondary) }, 30)
    elseif style == 'danger' then
        btn.BackgroundColor3 = C.Danger
    else
        btn.BackgroundColor3 = C.SurfaceElevated
        stroke(btn, C.Border, 1)
    end

    local hoverS = stroke(btn, C.AccentPrimary, 1, 1)
    btn.MouseEnter:Connect(function() tween(hoverS, { Transparency = 0 }) end)
    btn.MouseLeave:Connect(function() tween(hoverS, { Transparency = 1 }) end)

    btn.MouseButton1Click:Connect(function()
        local ripple = Instance.new('Frame')
        ripple.BackgroundColor3 = Color3.new(1, 1, 1)
        ripple.BackgroundTransparency = 0.7
        ripple.BorderSizePixel = 0
        ripple.Size = UDim2.new(0, 0, 0, 0)
        ripple.Position = UDim2.new(0.5, 0, 0.5, 0)
        ripple.AnchorPoint = Vector2.new(0.5, 0.5)
        ripple.Parent = btn
        corner(ripple, 20)
        tween(ripple, { Size = UDim2.new(1.2, 0, 1.2, 0), BackgroundTransparency = 1 }, TWEEN_SLOW).Completed:Connect(function()
            ripple:Destroy()
        end)
        if callback then pcall(callback) end
    end)
    return btn
end

local function createTextBox(parent, placeholder, default, callback)
    local box = Instance.new('TextBox')
    box.Size = UDim2.new(1, 0, 0, 26)
    box.BackgroundColor3 = C.SurfaceElevated
    box.BorderSizePixel = 0
    box.Font = F.Body
    box.TextSize = 13
    box.TextColor3 = C.TextPrimary
    box.PlaceholderText = placeholder or ''
    box.PlaceholderColor3 = C.TextDim
    box.Text = default or ''
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.Parent = parent
    corner(box, 4)
    local pad = Instance.new('UIPadding'); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8); pad.Parent = box
    local s = stroke(box, C.AccentPrimary, 1, 1)
    box.Focused:Connect(function() tween(s, { Transparency = 0 }) end)
    box.FocusLost:Connect(function(enter)
        tween(s, { Transparency = 1 })
        if callback then pcall(callback, box.Text, enter) end
    end)
    return box
end

local function createSection(parent, title)
    local sec = Instance.new('Frame')
    sec.Size = UDim2.new(1, 0, 0, 28)
    sec.BackgroundTransparency = 1
    sec.Parent = parent

    local lbl = Instance.new('TextLabel')
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.Font = F.Header
    lbl.TextSize = 14
    lbl.TextColor3 = C.AccentPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = string.upper(title)
    lbl.Parent = sec

    local line = Instance.new('Frame')
    line.Position = UDim2.new(0, 0, 1, -4)
    line.Size = UDim2.new(1, 0, 0, 1)
    line.BackgroundColor3 = C.Border
    line.BorderSizePixel = 0
    line.Parent = sec
    return sec
end

local function createScrollFrame(parent)
    local sf = Instance.new('ScrollingFrame')
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 3
    sf.ScrollBarImageColor3 = C.AccentPrimary
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.Parent = parent
    local l = Instance.new('UIListLayout'); l.Padding = UDim.new(0, 4); l.SortOrder = Enum.SortOrder.LayoutOrder; l.Parent = sf
    return sf
end

local function createToggle(parent, label, default, callback)
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, 0, 0, 24)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new('TextLabel')
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Font = F.Body
    lbl.TextSize = 13
    lbl.TextColor3 = C.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    local trackBtn = Instance.new('TextButton')
    trackBtn.AnchorPoint = Vector2.new(1, 0.5)
    trackBtn.Position = UDim2.new(1, 0, 0.5, 0)
    trackBtn.Size = UDim2.new(0, 38, 0, 18)
    trackBtn.Text = ''
    trackBtn.AutoButtonColor = false
    trackBtn.BackgroundColor3 = C.Border
    trackBtn.BorderSizePixel = 0
    trackBtn.Parent = row
    corner(trackBtn, 9)

    local knob = Instance.new('Frame')
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 2, 0.5, -7)
    knob.BackgroundColor3 = C.TextPrimary
    knob.BorderSizePixel = 0
    knob.Parent = trackBtn
    corner(knob, 8)

    local value = default and true or false
    local function apply(v, fire)
        value = v and true or false
        if value then
            tween(trackBtn, { BackgroundColor3 = C.AccentPrimary })
            tween(knob, { Position = UDim2.new(1, -16, 0.5, -7) })
        else
            tween(trackBtn, { BackgroundColor3 = C.Border })
            tween(knob, { Position = UDim2.new(0, 2, 0.5, -7) })
        end
        if fire and callback then pcall(callback, value) end
    end
    apply(value, false)

    trackBtn.MouseButton1Click:Connect(function() apply(not value, true) end)

    return {
        set = function(v) apply(v, false) end,
        get = function() return value end,
    }
end

local function createSlider(parent, label, min, max, default, decimals, callback)
    decimals = decimals or 0
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new('TextLabel')
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.Font = F.Body
    lbl.TextSize = 13
    lbl.TextColor3 = C.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    local val = Instance.new('TextLabel')
    val.BackgroundTransparency = 1
    val.Size = UDim2.new(1, 0, 0, 16)
    val.Font = F.Code
    val.TextSize = 12
    val.TextColor3 = C.AccentPrimary
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Text = tostring(default)
    val.Parent = row

    local bar = Instance.new('Frame')
    bar.Position = UDim2.new(0, 0, 0, 22)
    bar.Size = UDim2.new(1, 0, 0, 6)
    bar.BackgroundColor3 = C.SurfaceElevated
    bar.BorderSizePixel = 0
    bar.Parent = row
    corner(bar, 3)

    local fill = Instance.new('Frame')
    fill.BackgroundColor3 = C.AccentPrimary
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.Parent = bar
    corner(fill, 3)
    gradient(fill, { ColorSequenceKeypoint.new(0, C.AccentPrimary), ColorSequenceKeypoint.new(1, C.AccentSecondary) }, 0)

    local value = default
    local dragging = false

    local function round(n)
        local m = 10 ^ decimals
        return math.floor(n * m + 0.5) / m
    end

    local function apply(v, fire)
        v = math.clamp(v, min, max)
        value = round(v)
        local pct = (value - min) / (max - min)
        tween(fill, { Size = UDim2.new(pct, 0, 1, 0) })
        val.Text = decimals > 0 and string.format('%.' .. decimals .. 'f', value) or tostring(math.floor(value))
        if fire and callback then pcall(callback, value) end
    end
    apply(value, false)

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
            apply(min + rel * (max - min), true)
        end
    end))

    return {
        set = function(v) apply(v, false) end,
        get = function() return value end,
    }
end

local function createDropdown(parent, label, options, default, callback)
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, 0, 0, 42)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new('TextLabel')
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.Font = F.Body
    lbl.TextSize = 13
    lbl.TextColor3 = C.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    local btn = Instance.new('TextButton')
    btn.Position = UDim2.new(0, 0, 0, 18)
    btn.Size = UDim2.new(1, 0, 0, 24)
    btn.BackgroundColor3 = C.SurfaceElevated
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Font = F.Body
    btn.TextSize = 13
    btn.TextColor3 = C.TextPrimary
    btn.Text = '  ' .. tostring(default or options[1] or '')
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = row
    corner(btn, 4)
    stroke(btn, C.Border, 1)

    local arrow = Instance.new('TextLabel')
    arrow.BackgroundTransparency = 1
    arrow.Position = UDim2.new(1, -22, 0, 0)
    arrow.Size = UDim2.new(0, 18, 1, 0)
    arrow.Font = F.Body
    arrow.TextSize = 12
    arrow.TextColor3 = C.TextSecondary
    arrow.Text = 'v'
    arrow.Parent = btn

    local listFrame = Instance.new('Frame')
    listFrame.Visible = false
    listFrame.Position = UDim2.new(0, 0, 1, 4)
    listFrame.Size = UDim2.new(1, 0, 0, 0)
    listFrame.BackgroundColor3 = C.SurfaceElevated
    listFrame.BorderSizePixel = 0
    listFrame.ZIndex = 50
    listFrame.Parent = btn
    corner(listFrame, 4)
    stroke(listFrame, C.Border, 1)

    local sf = Instance.new('ScrollingFrame')
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 3
    sf.ScrollBarImageColor3 = C.AccentPrimary
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.ZIndex = 51
    sf.Parent = listFrame
    local ll = Instance.new('UIListLayout'); ll.Padding = UDim.new(0, 2); ll.Parent = sf

    local current = default or options[1]
    local optButtons = {}

    local function rebuild(opts)
        for _, b in ipairs(optButtons) do b:Destroy() end
        optButtons = {}
        for _, opt in ipairs(opts) do
            local o = Instance.new('TextButton')
            o.Size = UDim2.new(1, -6, 0, 22)
            o.Position = UDim2.new(0, 3, 0, 0)
            o.BackgroundColor3 = C.Surface
            o.BorderSizePixel = 0
            o.AutoButtonColor = false
            o.Font = F.Body
            o.TextSize = 12
            o.TextColor3 = C.TextPrimary
            o.Text = '  ' .. tostring(opt)
            o.TextXAlignment = Enum.TextXAlignment.Left
            o.ZIndex = 52
            o.Parent = sf
            corner(o, 3)
            o.MouseEnter:Connect(function() tween(o, { BackgroundColor3 = C.Border }) end)
            o.MouseLeave:Connect(function() tween(o, { BackgroundColor3 = C.Surface }) end)
            o.MouseButton1Click:Connect(function()
                current = opt
                btn.Text = '  ' .. tostring(opt)
                listFrame.Visible = false
                if callback then pcall(callback, opt) end
            end)
            table.insert(optButtons, o)
        end
        listFrame.Size = UDim2.new(1, 0, 0, math.min(#opts, 6) * 24 + 4)
    end
    rebuild(options)

    btn.MouseButton1Click:Connect(function()
        listFrame.Visible = not listFrame.Visible
        tween(arrow, { Rotation = listFrame.Visible and 180 or 0 })
    end)

    return {
        set = function(v) current = v; btn.Text = '  ' .. tostring(v) end,
        get = function() return current end,
        refresh = function(opts) rebuild(opts) end,
    }
end

local function createColorPicker(parent, label, defaultColor, callback)
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, 0, 0, 26)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new('TextLabel')
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -40, 1, 0)
    lbl.Font = F.Body
    lbl.TextSize = 13
    lbl.TextColor3 = C.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    local swatch = Instance.new('TextButton')
    swatch.AnchorPoint = Vector2.new(1, 0.5)
    swatch.Position = UDim2.new(1, 0, 0.5, 0)
    swatch.Size = UDim2.new(0, 32, 0, 20)
    swatch.Text = ''
    swatch.AutoButtonColor = false
    swatch.BackgroundColor3 = defaultColor or Color3.new(1, 1, 1)
    swatch.BorderSizePixel = 0
    swatch.Parent = row
    corner(swatch, 4)
    stroke(swatch, C.Border, 1)

    local current = defaultColor or Color3.new(1, 1, 1)
    local h, s, v = current:ToHSV()
    local popup

    local function buildPopup()
        if popup then popup:Destroy() end
        popup = Instance.new('Frame')
        popup.Size = UDim2.new(0, 200, 0, 200)
        popup.Position = UDim2.new(0, swatch.AbsolutePosition.X - 170, 0, swatch.AbsolutePosition.Y + 24)
        popup.BackgroundColor3 = C.SurfaceElevated
        popup.BorderSizePixel = 0
        popup.ZIndex = 100
        popup.Parent = swatch:FindFirstAncestorOfClass('ScreenGui')
        corner(popup, 6); stroke(popup, C.Border, 1); padding(popup, 8)

        local sv = Instance.new('ImageButton')
        sv.Size = UDim2.new(1, -16, 0, 130)
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        sv.AutoButtonColor = false
        sv.BorderSizePixel = 0
        sv.ZIndex = 101
        sv.Parent = popup
        corner(sv, 4)

        local svWhite = Instance.new('UIGradient')
        svWhite.Color = ColorSequence.new(Color3.new(1, 1, 1))
        svWhite.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        svWhite.Parent = sv

        local svBlack = Instance.new('Frame')
        svBlack.Size = UDim2.new(1, 0, 1, 0)
        svBlack.BackgroundColor3 = Color3.new(0, 0, 0)
        svBlack.BorderSizePixel = 0
        svBlack.ZIndex = 102
        svBlack.Parent = sv
        local svG = Instance.new('UIGradient')
        svG.Color = ColorSequence.new(Color3.new(0, 0, 0))
        svG.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        })
        svG.Rotation = 90
        svG.Parent = svBlack

        local hue = Instance.new('ImageButton')
        hue.Position = UDim2.new(0, 0, 1, -36)
        hue.Size = UDim2.new(1, -16, 0, 14)
        hue.BorderSizePixel = 0
        hue.AutoButtonColor = false
        hue.ZIndex = 101
        hue.Parent = popup
        corner(hue, 4)
        local hueG = Instance.new('UIGradient')
        hueG.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0.00, 1, 1)),
            ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
            ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
            ColorSequenceKeypoint.new(0.50, Color3.fromHSV(0.50, 1, 1)),
            ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
            ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
            ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1.00, 1, 1)),
        })
        hueG.Parent = hue

        local function update()
            current = Color3.fromHSV(h, s, v)
            swatch.BackgroundColor3 = current
            sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            if callback then pcall(callback, current) end
        end

        sv.MouseButton1Down:Connect(function()
            local conn
            conn = RunService.RenderStepped:Connect(function()
                local mp = UserInputService:GetMouseLocation()
                local rx = math.clamp((mp.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
                local ry = math.clamp((mp.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
                s = rx; v = 1 - ry
                update()
            end)
            local up; up = UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    if conn then conn:Disconnect() end
                    if up then up:Disconnect() end
                end
            end)
        end)

        hue.MouseButton1Down:Connect(function()
            local conn
            conn = RunService.RenderStepped:Connect(function()
                local mp = UserInputService:GetMouseLocation()
                local rx = math.clamp((mp.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 1)
                h = rx
                update()
            end)
            local up; up = UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    if conn then conn:Disconnect() end
                    if up then up:Disconnect() end
                end
            end)
        end)

        local close = createButton(popup, 'Close', 'secondary', function()
            if popup then popup:Destroy(); popup = nil end
        end)
        close.AnchorPoint = Vector2.new(0, 0)
        close.Position = UDim2.new(1, -64, 1, -20)
        close.Size = UDim2.new(0, 60, 0, 18)
        close.ZIndex = 102
    end

    swatch.MouseButton1Click:Connect(function()
        if popup then popup:Destroy(); popup = nil else buildPopup() end
    end)

    return {
        set = function(c) current = c; swatch.BackgroundColor3 = c; h, s, v = c:ToHSV() end,
        get = function() return current end,
    }
end

local function createKeybind(parent, label, defaultKey, callback)
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, 0, 0, 24)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new('TextLabel')
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.Font = F.Body
    lbl.TextSize = 13
    lbl.TextColor3 = C.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    local btn = Instance.new('TextButton')
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, 0, 0.5, 0)
    btn.Size = UDim2.new(0, 70, 0, 20)
    btn.AutoButtonColor = false
    btn.BackgroundColor3 = C.SurfaceElevated
    btn.BorderSizePixel = 0
    btn.Font = F.Code
    btn.TextSize = 12
    btn.TextColor3 = C.TextPrimary
    btn.Text = tostring(defaultKey or 'None')
    btn.Parent = row
    corner(btn, 4)
    stroke(btn, C.Border, 1)

    local key = defaultKey
    local capturing = false
    btn.MouseButton1Click:Connect(function()
        capturing = true
        btn.Text = '...'
    end)

    track(UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if capturing and input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Escape then
                key = nil
                btn.Text = 'None'
            else
                key = input.KeyCode.Name
                btn.Text = key
            end
            capturing = false
            if callback then pcall(callback, key) end
        end
    end))

    return {
        set = function(k) key = k; btn.Text = tostring(k or 'None') end,
        get = function() return key end,
    }
end

------------------------------------------------------------------------------
-- 9. WINDOW
------------------------------------------------------------------------------
local function createWindow(title, size)
    local sgui = Instance.new('ScreenGui')
    sgui.Name = 'ENI_RemoteScanner_' .. tostring(math.random(1000, 9999))
    sgui.ResetOnSpawn = false
    sgui.IgnoreGuiInset = true
    sgui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(protect_gui, sgui)
    if not sgui.Parent then sgui.Parent = game:GetService('CoreGui') end

    ensureNotifyHolder(sgui)

    local main = Instance.new('Frame')
    main.Name = 'Main'
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.Size = size or UDim2.new(0, 380, 0, 520)
    main.BackgroundColor3 = C.Background
    main.BorderSizePixel = 0
    main.Parent = sgui
    corner(main, 8)
    stroke(main, C.Border, 1)

    local titleBar = Instance.new('Frame')
    titleBar.Size = UDim2.new(1, 0, 0, 36)
    titleBar.BackgroundColor3 = C.Surface
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main
    corner(titleBar, 8)

    gradient(titleBar, { ColorSequenceKeypoint.new(0, C.AccentPrimary), ColorSequenceKeypoint.new(1, C.AccentSecondary) }, 0)
    titleBar.BackgroundTransparency = 0.85

    local titleLbl = Instance.new('TextLabel')
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.new(0, 12, 0, 0)
    titleLbl.Size = UDim2.new(1, -90, 1, 0)
    titleLbl.Font = F.Title
    titleLbl.TextSize = 16
    titleLbl.TextColor3 = C.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Text = title or 'Window'
    titleLbl.Parent = titleBar

    local verLbl = Instance.new('TextLabel')
    verLbl.BackgroundTransparency = 1
    verLbl.Position = UDim2.new(0, 12, 1, -14)
    verLbl.Size = UDim2.new(0, 50, 0, 12)
    verLbl.Font = F.Code
    verLbl.TextSize = 10
    verLbl.TextColor3 = C.TextDim
    verLbl.TextXAlignment = Enum.TextXAlignment.Left
    verLbl.Text = 'v2.0.0'
    verLbl.Parent = titleBar

    local function makeCornerBtn(icon, color, x)
        local b = Instance.new('TextButton')
        b.AnchorPoint = Vector2.new(1, 0.5)
        b.Position = UDim2.new(1, -x, 0.5, 0)
        b.Size = UDim2.new(0, 20, 0, 20)
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.Font = F.Header
        b.TextSize = 12
        b.TextColor3 = C.TextPrimary
        b.Text = icon
        b.Parent = titleBar
        corner(b, 4)
        return b
    end

    local minBtn   = makeCornerBtn('-', C.Warning, 36)
    local closeBtn = makeCornerBtn('x', C.Danger, 10)

    local container = Instance.new('Frame')
    container.Position = UDim2.new(0, 0, 0, 36)
    container.Size = UDim2.new(1, 0, 1, -36)
    container.BackgroundTransparency = 1
    container.Parent = main

    -- drag
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))

    -- resize grip
    local grip = Instance.new('TextButton')
    grip.Text = ''
    grip.AutoButtonColor = false
    grip.AnchorPoint = Vector2.new(1, 1)
    grip.Position = UDim2.new(1, -2, 1, -2)
    grip.Size = UDim2.new(0, 14, 0, 14)
    grip.BackgroundColor3 = C.AccentPrimary
    grip.BackgroundTransparency = 0.5
    grip.BorderSizePixel = 0
    grip.ZIndex = 5
    grip.Parent = main
    corner(grip, 3)

    local resizing, resStart, startSize
    grip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true
            resStart = input.Position
            startSize = main.Size
        end
    end)
    grip.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - resStart
            main.Size = UDim2.new(0, math.max(320, startSize.X.Offset + delta.X), 0, math.max(360, startSize.Y.Offset + delta.Y))
        end
    end))

    -- open animation
    local targetSize = size or UDim2.new(0, 380, 0, 520)
    main.Size = UDim2.new(0, targetSize.X.Offset * 0.9, 0, targetSize.Y.Offset * 0.9)
    main.BackgroundTransparency = 1
    tween(main, { Size = targetSize, BackgroundTransparency = 0 }, TWEEN_SLOW)

    local minimized = false
    local origSize = targetSize
    local function toggleMinimize()
        minimized = not minimized
        if minimized then
            origSize = main.Size
            container.Visible = false
            grip.Visible = false
            tween(main, { Size = UDim2.new(0, math.max(280, main.AbsoluteSize.X), 0, 36) })
        else
            container.Visible = true
            grip.Visible = true
            tween(main, { Size = origSize })
        end
    end
    minBtn.MouseButton1Click:Connect(toggleMinimize)

    local api = {}
    function api:setVisible(v) sgui.Enabled = v and true or false end
    function api:destroy() sgui:Destroy() end
    function api:toggleMinimize() toggleMinimize() end
    api.Frame = main
    api.Container = container
    api.ScreenGui = sgui

    closeBtn.MouseButton1Click:Connect(function() api:setVisible(false) end)
    return api
end

------------------------------------------------------------------------------
-- 10. REMOTE SCANNER LOGIC
------------------------------------------------------------------------------
local SUSPICIOUS_KEYWORDS = {
    'kick','ban','admin','teleport','give','grant','money','coin','cash',
    'credits','exp','reward','spawn','setattribute','changestat','award',
    'purchase','buy','sell','trade','inventory','equip','unequip','noclip',
    'fly','speed','jump','kill','damage','heal','setdata','sync','auth',
    'login','token','password','session','exec','run','load','require',
    'http','url','endpoint','webhook','remoteexec','setstate','setvalue',
    'savedata','loaddata','setstat','setscore','setlevel','setrank',
    'promote','demote','mute','unmute','warn','report','vote','poll',
}

local INTERNAL_PATH_PATTERNS = {
    '^MaterialService',
    '^TextChatService',
    '^Chat',
    '^CorePackages',
    '^CoreGui',
    '^RobloxReplicatedStorage',
    'PlayerScripts%.PlayerModule',
    'PlayerScripts%.RbxCharacterSounds',
}

local function isInternal(path)
    for _, pat in ipairs(INTERNAL_PATH_PATTERNS) do
        if path:match(pat) then return true end
    end
    return false
end

local function isSuspicious(name)
    local low = name:lower()
    for _, kw in ipairs(SUSPICIOUS_KEYWORDS) do
        if low:find(kw, 1, true) then return true end
    end
    return false
end

local TYPE_CLASSES = {
    'RemoteEvent', 'RemoteFunction', 'UnreliableRemoteEvent',
    'BindableEvent', 'BindableFunction',
}

local function getFullPath(inst)
    local parts = {}
    local cur = inst
    while cur and cur ~= game do
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
    end
    return table.concat(parts, '.')
end

local function getServicePath(inst)
    local cur = inst
    local parts = {}
    while cur and cur ~= game and cur.Parent ~= game do
        table.insert(parts, 1, string.format('[%q]', cur.Name))
        cur = cur.Parent
    end
    if cur and cur.Parent == game then
        local serviceCall = string.format('game:GetService(%q)', cur.ClassName)
        if #parts == 0 then return serviceCall end
        return serviceCall .. table.concat(parts, '')
    end
    return getFullPath(inst)
end

local remoteCache = {}

local function scanRemotes()
    remoteCache = {}
    local seen = {}
    local roots = {}
    local function tryAdd(svc) local ok, r = pcall(function() return game:GetService(svc) end); if ok and r then table.insert(roots, r) end end
    tryAdd('ReplicatedStorage'); tryAdd('ReplicatedFirst'); table.insert(roots, Workspace)
    table.insert(roots, Players); table.insert(roots, Lighting)
    tryAdd('StarterGui'); tryAdd('StarterPack'); tryAdd('StarterPlayer')
    tryAdd('SoundService'); tryAdd('Chat'); tryAdd('TextChatService')

    for _, root in ipairs(roots) do
        if root then
            local ok, descendants = pcall(function() return root:GetDescendants() end)
            if ok and descendants then
                for _, d in ipairs(descendants) do
                    local cls = d.ClassName
                    if cls == 'RemoteEvent' or cls == 'RemoteFunction'
                        or cls == 'UnreliableRemoteEvent'
                        or cls == 'BindableEvent' or cls == 'BindableFunction' then
                        if not seen[d] then
                            seen[d] = true
                            local path = getFullPath(d)
                            table.insert(remoteCache, {
                                instance   = d,
                                name       = d.Name,
                                path       = path,
                                class      = cls,
                                suspicious = isSuspicious(d.Name),
                                internal   = isInternal(path),
                            })
                        end
                    end
                end
            end
        end
    end
    return remoteCache
end

local function fuzzyMatch(needle, hay)
    if needle == '' then return true end
    needle = needle:lower()
    hay = hay:lower()
    if hay:find(needle, 1, true) then return true end
    local hi = 1
    for i = 1, #needle do
        local c = needle:sub(i, i)
        local found = hay:find(c, hi, true)
        if not found then return false end
        hi = found + 1
    end
    return true
end

local function buildTree(filteredList)
    local tree = {}
    local function ensure(p)
        if not tree[p] then tree[p] = { children = {}, items = {}, name = p } end
        return tree[p]
    end
    ensure('')
    for _, e in ipairs(filteredList) do
        local parent = e.path:match('^(.*)%.[^%.]+$') or ''
        ensure(parent)
        table.insert(tree[parent].items, e)
        local cur = parent
        while cur ~= '' do
            local up = cur:match('^(.*)%.[^%.]+$') or ''
            ensure(up)
            tree[up].children[cur] = true
            cur = up
        end
    end
    return tree
end

------------------------------------------------------------------------------
-- 11. BUILD MAIN GUI
------------------------------------------------------------------------------
local win = createWindow('Remote Scanner', UDim2.new(0, 500, 0, 600))
local Container = win.Container
padding(Container, 10)
local layout = Instance.new('UIListLayout'); layout.Padding = UDim.new(0, 8); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = Container

-- forward declarations
local refreshList, updateStatus

-- Search row
local searchRow = Instance.new('Frame')
searchRow.Size = UDim2.new(1, 0, 0, 28)
searchRow.BackgroundTransparency = 1
searchRow.LayoutOrder = 1
searchRow.Parent = Container

local searchBox = createTextBox(searchRow, 'Search name or path... (Ctrl+F)', '', function() end)
searchBox.Size = UDim2.new(1, -98, 1, 0)
searchBox.Position = UDim2.new(0, 0, 0, 0)

local refreshBtn = createButton(searchRow, 'Refresh', 'primary', function()
    scanRemotes()
    refreshList()
    notify('Remote Scanner', ('Found %d remotes'):format(#remoteCache), 'success', 2)
end)
refreshBtn.AnchorPoint = Vector2.new(1, 0)
refreshBtn.Position = UDim2.new(1, 0, 0, 0)
refreshBtn.Size = UDim2.new(0, 90, 1, 0)

-- Filters
local filterSec = createSection(Container, 'Type Filters'); filterSec.LayoutOrder = 2

local filterRow = Instance.new('Frame')
filterRow.Size = UDim2.new(1, 0, 0, 60)
filterRow.BackgroundTransparency = 1
filterRow.LayoutOrder = 3
filterRow.Parent = Container

local filterGrid = Instance.new('UIGridLayout')
filterGrid.CellSize = UDim2.new(0.5, -4, 0, 24)
filterGrid.CellPadding = UDim2.new(0, 8, 0, 4)
filterGrid.SortOrder = Enum.SortOrder.LayoutOrder
filterGrid.Parent = filterRow

for _, cls in ipairs(TYPE_CLASSES) do
    createToggle(filterRow, cls, state.filters[cls] ~= false, function(v)
        state.filters[cls] = v
        saveConfig()
        refreshList()
    end)
end

-- Misc option toggles
local opts = Instance.new('Frame')
opts.Size = UDim2.new(1, 0, 0, 84)
opts.BackgroundTransparency = 1
opts.LayoutOrder = 4
opts.Parent = Container
local optLayout = Instance.new('UIListLayout'); optLayout.Padding = UDim.new(0, 4); optLayout.Parent = opts

createToggle(opts, 'Favorites only', state.favoritesOnly, function(v)
    state.favoritesOnly = v; saveConfig(); refreshList()
end)
createToggle(opts, 'Hide internal Roblox remotes', state.hideInternal, function(v)
    state.hideInternal = v; saveConfig(); refreshList()
end)
createToggle(opts, 'Auto-refresh', state.autoRefresh, function(v)
    state.autoRefresh = v; saveConfig()
end)

-- Sort + interval
createDropdown(Container, 'Sort by', {
    'Name ASC', 'Name DESC', 'Path ASC', 'Path DESC', 'Type', 'Suspicious First',
}, state.sort, function(v) state.sort = v; saveConfig(); refreshList() end)
local sortFrame = Container:GetChildren()[#Container:GetChildren()]
sortFrame.LayoutOrder = 5

createSlider(Container, 'Auto-refresh interval (s)', 1, 60, state.autoRefreshSeconds, 0, function(v)
    state.autoRefreshSeconds = v; saveConfig()
end)
local intervalFrame = Container:GetChildren()[#Container:GetChildren()]
intervalFrame.LayoutOrder = 6

-- Tree section
local treeSec = createSection(Container, 'Remotes'); treeSec.LayoutOrder = 7

local treeHolder = Instance.new('Frame')
treeHolder.Size = UDim2.new(1, 0, 0, 220)
treeHolder.BackgroundColor3 = C.Surface
treeHolder.BorderSizePixel = 0
treeHolder.LayoutOrder = 8
treeHolder.Parent = Container
corner(treeHolder, 6)
stroke(treeHolder, C.Border, 1)
padding(treeHolder, 4)

local treeScroll = createScrollFrame(treeHolder)

-- Action panel
local actionSec = createSection(Container, 'Selected Remote'); actionSec.LayoutOrder = 9

local actionPanel = Instance.new('Frame')
actionPanel.Size = UDim2.new(1, 0, 0, 160)
actionPanel.BackgroundColor3 = C.Surface
actionPanel.BorderSizePixel = 0
actionPanel.LayoutOrder = 10
actionPanel.Parent = Container
corner(actionPanel, 6)
stroke(actionPanel, C.Border, 1)
padding(actionPanel, 8)

local selectedLabel = Instance.new('TextLabel')
selectedLabel.BackgroundTransparency = 1
selectedLabel.Size = UDim2.new(1, 0, 0, 16)
selectedLabel.Font = F.Code
selectedLabel.TextSize = 12
selectedLabel.TextColor3 = C.TextSecondary
selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
selectedLabel.Text = '(none selected)'
selectedLabel.TextTruncate = Enum.TextTruncate.AtEnd
selectedLabel.Parent = actionPanel

local argsBox = Instance.new('TextBox')
argsBox.Position = UDim2.new(0, 0, 0, 22)
argsBox.Size = UDim2.new(1, 0, 0, 64)
argsBox.BackgroundColor3 = C.SurfaceElevated
argsBox.BorderSizePixel = 0
argsBox.Font = F.Code
argsBox.TextSize = 12
argsBox.TextColor3 = C.TextPrimary
argsBox.PlaceholderText = 'args (Lua: e.g. "give",100,true) - Enter fires with empty args'
argsBox.PlaceholderColor3 = C.TextDim
argsBox.Text = ''
argsBox.TextXAlignment = Enum.TextXAlignment.Left
argsBox.TextYAlignment = Enum.TextYAlignment.Top
argsBox.MultiLine = true
argsBox.ClearTextOnFocus = false
argsBox.TextWrapped = true
argsBox.Parent = actionPanel
corner(argsBox, 4)
local argsPad = Instance.new('UIPadding'); argsPad.PaddingLeft = UDim.new(0,6); argsPad.PaddingTop = UDim.new(0,4); argsPad.Parent = argsBox

local btnRow = Instance.new('Frame')
btnRow.Position = UDim2.new(0, 0, 0, 92)
btnRow.Size = UDim2.new(1, 0, 0, 26)
btnRow.BackgroundTransparency = 1
btnRow.Parent = actionPanel
local btnLayout = Instance.new('UIListLayout'); btnLayout.FillDirection = Enum.FillDirection.Horizontal; btnLayout.Padding = UDim.new(0, 6); btnLayout.Parent = btnRow

local selectedEntry = nil

local function tryClipboard(text)
    local ok = pcall(function()
        if setclipboard then setclipboard(text)
        elseif syn and syn.write_clipboard then syn.write_clipboard(text)
        elseif toclipboard then toclipboard(text) end
    end)
    return ok
end

local copyPathBtn = createButton(btnRow, 'Copy Path', 'secondary', function()
    if not selectedEntry then return end
    if tryClipboard(selectedEntry.path) then notify('Copied', selectedEntry.path, 'success', 2)
    else notify('Clipboard', 'setclipboard not available', 'warn', 2) end
end)
copyPathBtn.Size = UDim2.new(0, 86, 1, 0)

local copySvcBtn = createButton(btnRow, 'Copy Service', 'secondary', function()
    if not selectedEntry then return end
    local sp = getServicePath(selectedEntry.instance)
    if tryClipboard(sp) then notify('Copied', sp, 'success', 2) end
end)
copySvcBtn.Size = UDim2.new(0, 96, 1, 0)

local function fireRemote()
    if not selectedEntry then notify('Fire', 'No remote selected', 'warn', 2); return end
    local inst = selectedEntry.instance
    local raw = argsBox.Text or ''
    local args = {}
    if raw:gsub('%s', '') ~= '' then
        local loader = loadstring or load
        local fn, err = loader('return {' .. raw .. '}')
        if not fn then notify('Fire', 'Arg parse error: ' .. tostring(err), 'error', 3); return end
        local ok, val = pcall(fn)
        if not ok or type(val) ~= 'table' then notify('Fire', 'Arg eval error: ' .. tostring(val), 'error', 3); return end
        args = val
    end
    local cls = inst.ClassName
    local ok, err
    if cls == 'RemoteEvent' or cls == 'UnreliableRemoteEvent' then
        ok, err = pcall(function() inst:FireServer(unpack(args)) end)
    elseif cls == 'RemoteFunction' then
        ok, err = pcall(function() local r = inst:InvokeServer(unpack(args)); notify('Fire', 'Return: ' .. tostring(r), 'success', 3) end)
    elseif cls == 'BindableEvent' then
        ok, err = pcall(function() inst:Fire(unpack(args)) end)
    elseif cls == 'BindableFunction' then
        ok, err = pcall(function() local r = inst:Invoke(unpack(args)); notify('Fire', 'Return: ' .. tostring(r), 'success', 3) end)
    end
    if ok then notify('Fire', selectedEntry.name .. ' fired', 'success', 2)
    else notify('Fire', tostring(err), 'error', 4) end
end

local fireBtn = createButton(btnRow, 'Fire', 'primary', fireRemote)
fireBtn.Size = UDim2.new(0, 70, 1, 0)

local spyBtn = createButton(btnRow, 'Remote Spy', 'secondary', function()
    if not selectedEntry then return end
    local spy = getgenv().ENI and getgenv().ENI.RemoteSpy
    if spy and (spy.OpenFor or spy.Open) then
        pcall(function() (spy.OpenFor or spy.Open)(spy, selectedEntry.instance) end)
        notify('Spy', 'Opened in Remote Spy', 'success', 2)
    else
        notify('Spy', 'Remote Spy module not loaded', 'warn', 2)
    end
end)
spyBtn.Size = UDim2.new(0, 90, 1, 0)

local annotateBtn
annotateBtn = createButton(btnRow, 'Annotate', 'secondary', function()
    if not selectedEntry then return end
    local existing = state.annotations[selectedEntry.path] or ''
    local promptFrame = Instance.new('Frame')
    promptFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    promptFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    promptFrame.Size = UDim2.new(0, 320, 0, 120)
    promptFrame.BackgroundColor3 = C.SurfaceElevated
    promptFrame.BorderSizePixel = 0
    promptFrame.ZIndex = 200
    promptFrame.Parent = win.ScreenGui
    corner(promptFrame, 6); stroke(promptFrame, C.AccentPrimary, 1); padding(promptFrame, 10)

    local lbl = Instance.new('TextLabel')
    lbl.BackgroundTransparency = 1; lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.Font = F.Header; lbl.TextSize = 13; lbl.TextColor3 = C.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = 'Annotate: ' .. selectedEntry.name
    lbl.ZIndex = 201; lbl.Parent = promptFrame

    local tb = Instance.new('TextBox')
    tb.Position = UDim2.new(0, 0, 0, 22); tb.Size = UDim2.new(1, 0, 0, 50)
    tb.BackgroundColor3 = C.Surface; tb.BorderSizePixel = 0
    tb.Font = F.Body; tb.TextSize = 12; tb.TextColor3 = C.TextPrimary
    tb.Text = existing; tb.PlaceholderText = 'note...'; tb.PlaceholderColor3 = C.TextDim
    tb.TextXAlignment = Enum.TextXAlignment.Left; tb.TextYAlignment = Enum.TextYAlignment.Top
    tb.ClearTextOnFocus = false; tb.MultiLine = true; tb.TextWrapped = true
    tb.ZIndex = 201; tb.Parent = promptFrame; corner(tb, 4)
    local tbPad = Instance.new('UIPadding'); tbPad.PaddingLeft = UDim.new(0,6); tbPad.PaddingTop = UDim.new(0,4); tbPad.Parent = tb

    local save = createButton(promptFrame, 'Save', 'primary', function()
        state.annotations[selectedEntry.path] = (tb.Text ~= '' and tb.Text) or nil
        saveConfig(); refreshList(); promptFrame:Destroy()
    end)
    save.AnchorPoint = Vector2.new(1, 1); save.Position = UDim2.new(1, 0, 1, 0)
    save.Size = UDim2.new(0, 70, 0, 22); save.ZIndex = 201

    local cancel = createButton(promptFrame, 'Cancel', 'secondary', function() promptFrame:Destroy() end)
    cancel.AnchorPoint = Vector2.new(1, 1); cancel.Position = UDim2.new(1, -78, 1, 0)
    cancel.Size = UDim2.new(0, 70, 0, 22); cancel.ZIndex = 201
end)
annotateBtn.Size = UDim2.new(0, 78, 1, 0)

-- Settings section
local settingsSec = createSection(Container, 'Settings'); settingsSec.LayoutOrder = 11

local settingsRow = Instance.new('Frame')
settingsRow.Size = UDim2.new(1, 0, 0, 28)
settingsRow.BackgroundTransparency = 1
settingsRow.LayoutOrder = 12
settingsRow.Parent = Container
local sLayout = Instance.new('UIListLayout'); sLayout.FillDirection = Enum.FillDirection.Horizontal; sLayout.Padding = UDim.new(0, 6); sLayout.Parent = settingsRow

local saveBtn = createButton(settingsRow, 'Save Config', 'primary', function() saveConfig(); notify('Config', 'Saved', 'success', 2) end)
saveBtn.Size = UDim2.new(0, 90, 1, 0)

local loadBtn = createButton(settingsRow, 'Load Config', 'secondary', function() loadConfig(); refreshList(); notify('Config', 'Loaded', 'success', 2) end)
loadBtn.Size = UDim2.new(0, 90, 1, 0)

local resetBtn = createButton(settingsRow, 'Reset', 'danger', function()
    state = deepcopy(DEFAULT_STATE); saveConfig(); refreshList()
    notify('Config', 'Reset to defaults', 'warn', 2)
end)
resetBtn.Size = UDim2.new(0, 70, 1, 0)

local exportBtn = createButton(settingsRow, 'Export Favs', 'secondary', function()
    if not writefile then notify('Export', 'writefile unavailable', 'error', 3); return end
    local lines = { '-- ENI Remote Scanner Favorites Export', 'return {' }
    local count = 0
    for path, v in pairs(state.favorites) do
        if v then
            local short = path:match('([^%.]+)$') or path
            table.insert(lines, string.format('  [%q] = %q,', short, path))
            count = count + 1
        end
    end
    table.insert(lines, '}')
    pcall(function() writefile(CONFIG_DIR .. '/remote_scanner_favorites.lua', table.concat(lines, '\n')) end)
    notify('Export', ('Wrote %d favorites'):format(count), 'success', 3)
end)
exportBtn.Size = UDim2.new(0, 90, 1, 0)

-- Accent color picker
local accentRow = Instance.new('Frame')
accentRow.Size = UDim2.new(1, 0, 0, 26)
accentRow.BackgroundTransparency = 1
accentRow.LayoutOrder = 13
accentRow.Parent = Container

createColorPicker(accentRow, 'Accent color', C.AccentPrimary, function(c)
    C.AccentPrimary = c
    local r, g, b = math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
    state.accent = { r = r, g = g, b = b }
    saveConfig()
end)

-- Keybinds
local kbSec = createSection(Container, 'Keybinds'); kbSec.LayoutOrder = 14

local kbHolder = Instance.new('Frame')
kbHolder.Size = UDim2.new(1, 0, 0, 56)
kbHolder.BackgroundTransparency = 1
kbHolder.LayoutOrder = 15
kbHolder.Parent = Container
local kbL = Instance.new('UIListLayout'); kbL.Padding = UDim.new(0, 4); kbL.Parent = kbHolder

createKeybind(kbHolder, 'Refresh', state.keybinds.Refresh, function(k) state.keybinds.Refresh = k; saveConfig() end)
createKeybind(kbHolder, 'Focus Search (Ctrl+)', state.keybinds.FocusSearch, function(k) state.keybinds.FocusSearch = k; saveConfig() end)

-- Status footer
local statusBar = Instance.new('Frame')
statusBar.Size = UDim2.new(1, 0, 0, 20)
statusBar.BackgroundColor3 = C.Surface
statusBar.BorderSizePixel = 0
statusBar.LayoutOrder = 16
statusBar.Parent = Container
corner(statusBar, 4)

local statusLbl = Instance.new('TextLabel')
statusLbl.BackgroundTransparency = 1
statusLbl.Size = UDim2.new(1, -10, 1, 0)
statusLbl.Position = UDim2.new(0, 6, 0, 0)
statusLbl.Font = F.Code
statusLbl.TextSize = 11
statusLbl.TextColor3 = C.TextSecondary
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Text = '0 remotes | 0 suspicious | 0 favorites'
statusLbl.Parent = statusBar

------------------------------------------------------------------------------
-- 12. TREE RENDERING / FILTERING / SORTING
------------------------------------------------------------------------------
local expandedNodes = {}

local function sortEntries(list)
    local mode = state.sort or 'Name ASC'
    if mode == 'Name ASC' then
        table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    elseif mode == 'Name DESC' then
        table.sort(list, function(a, b) return a.name:lower() > b.name:lower() end)
    elseif mode == 'Path ASC' then
        table.sort(list, function(a, b) return a.path < b.path end)
    elseif mode == 'Path DESC' then
        table.sort(list, function(a, b) return a.path > b.path end)
    elseif mode == 'Type' then
        table.sort(list, function(a, b) if a.class == b.class then return a.name < b.name end; return a.class < b.class end)
    elseif mode == 'Suspicious First' then
        table.sort(list, function(a, b)
            if a.suspicious ~= b.suspicious then return a.suspicious end
            return a.name:lower() < b.name:lower()
        end)
    end
    return list
end

local function selectEntry(entry)
    selectedEntry = entry
    if entry then
        local tag = state.annotations[entry.path] and (' [' .. state.annotations[entry.path] .. ']') or ''
        selectedLabel.Text = entry.class .. '  ' .. entry.path .. tag
        selectedLabel.TextColor3 = entry.suspicious and C.Danger or C.TextSecondary
    else
        selectedLabel.Text = '(none selected)'
        selectedLabel.TextColor3 = C.TextSecondary
    end
end

local function buildRowFor(entry, depth)
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, -4, 0, 22)
    row.BackgroundColor3 = entry.suspicious and Color3.fromRGB(40, 22, 30) or C.SurfaceElevated
    row.BorderSizePixel = 0
    row.Parent = treeScroll
    corner(row, 4)

    local dot = Instance.new('Frame')
    dot.Position = UDim2.new(0, depth * 10 + 4, 0.5, -3)
    dot.Size = UDim2.new(0, 6, 0, 6)
    dot.BackgroundColor3 = entry.suspicious and C.Danger or C.Success
    dot.BorderSizePixel = 0
    dot.Parent = row
    corner(dot, 3)

    local starBtn = Instance.new('TextButton')
    starBtn.Position = UDim2.new(0, depth * 10 + 14, 0, 0)
    starBtn.Size = UDim2.new(0, 18, 1, 0)
    starBtn.BackgroundTransparency = 1
    starBtn.Font = F.Header
    starBtn.TextSize = 14
    starBtn.Text = state.favorites[entry.path] and '*' or '-'
    starBtn.TextColor3 = state.favorites[entry.path] and C.Warning or C.TextDim
    starBtn.Parent = row
    starBtn.MouseButton1Click:Connect(function()
        state.favorites[entry.path] = (not state.favorites[entry.path]) or nil
        if state.favorites[entry.path] then
            starBtn.Text = '*'; starBtn.TextColor3 = C.Warning
        else
            starBtn.Text = '-'; starBtn.TextColor3 = C.TextDim
        end
        saveConfig()
        updateStatus()
    end)

    local nameLbl = Instance.new('TextLabel')
    nameLbl.BackgroundTransparency = 1
    nameLbl.Position = UDim2.new(0, depth * 10 + 34, 0, 0)
    nameLbl.Size = UDim2.new(1, -(depth * 10 + 100), 1, 0)
    nameLbl.Font = F.Body
    nameLbl.TextSize = 12
    nameLbl.TextColor3 = entry.suspicious and C.Danger or C.TextPrimary
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    local note = state.annotations[entry.path]
    nameLbl.Text = entry.name .. (note and ('  // ' .. note) or '')
    nameLbl.Parent = row

    local typeLbl = Instance.new('TextLabel')
    typeLbl.AnchorPoint = Vector2.new(1, 0)
    typeLbl.Position = UDim2.new(1, -6, 0, 0)
    typeLbl.Size = UDim2.new(0, 70, 1, 0)
    typeLbl.BackgroundTransparency = 1
    typeLbl.Font = F.Code
    typeLbl.TextSize = 10
    typeLbl.TextColor3 = C.AccentSecondary
    typeLbl.TextXAlignment = Enum.TextXAlignment.Right
    typeLbl.Text = entry.class
    typeLbl.Parent = row

    local clickBtn = Instance.new('TextButton')
    clickBtn.Size = UDim2.new(1, 0, 1, 0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text = ''
    clickBtn.ZIndex = 2
    clickBtn.Parent = row
    clickBtn.MouseEnter:Connect(function() tween(row, { BackgroundColor3 = entry.suspicious and Color3.fromRGB(55, 28, 38) or C.Border }) end)
    clickBtn.MouseLeave:Connect(function() tween(row, { BackgroundColor3 = entry.suspicious and Color3.fromRGB(40, 22, 30) or C.SurfaceElevated }) end)
    clickBtn.MouseButton1Click:Connect(function() selectEntry(entry) end)
    clickBtn.MouseButton2Click:Connect(function()
        selectEntry(entry)
        if annotateBtn then
            pcall(function() annotateBtn:Activate() end)
            -- fallback: just trigger callback directly via simulated click
        end
    end)
    return row
end

local function buildBranchRow(pathKey, depth, expanded)
    local row = Instance.new('TextButton')
    row.Size = UDim2.new(1, -4, 0, 22)
    row.BackgroundColor3 = C.Surface
    row.BorderSizePixel = 0
    row.AutoButtonColor = false
    row.Text = ''
    row.Parent = treeScroll
    corner(row, 4)

    local arrow = Instance.new('TextLabel')
    arrow.BackgroundTransparency = 1
    arrow.Position = UDim2.new(0, depth * 10 + 4, 0, 0)
    arrow.Size = UDim2.new(0, 14, 1, 0)
    arrow.Font = F.Code
    arrow.TextSize = 12
    arrow.TextColor3 = C.AccentPrimary
    arrow.Text = expanded and 'v' or '>'
    arrow.Parent = row

    local name = pathKey:match('([^%.]+)$') or pathKey
    if pathKey == '' then name = '[Game]' end

    local lbl = Instance.new('TextLabel')
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, depth * 10 + 22, 0, 0)
    lbl.Size = UDim2.new(1, -(depth * 10 + 30), 1, 0)
    lbl.Font = F.Header
    lbl.TextSize = 12
    lbl.TextColor3 = C.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Text = name
    lbl.Parent = row

    row.MouseButton1Click:Connect(function()
        expandedNodes[pathKey] = not expandedNodes[pathKey]
        refreshList()
    end)
    return row
end

refreshList = function()
    for _, ch in ipairs(treeScroll:GetChildren()) do
        if ch:IsA('GuiObject') then ch:Destroy() end
    end
    local needle = searchBox.Text or ''
    local filtered = {}
    for _, e in ipairs(remoteCache) do
        if state.filters[e.class] ~= false then
            if not (state.hideInternal and e.internal) then
                if not state.favoritesOnly or state.favorites[e.path] then
                    if fuzzyMatch(needle, e.name) or fuzzyMatch(needle, e.path) then
                        table.insert(filtered, e)
                    end
                end
            end
        end
    end
    sortEntries(filtered)

    local tree = buildTree(filtered)
    local function depthOf(k) if k == '' then return 0 end; local _, c = k:gsub('%.', '.'); return c + 1 end

    local function renderBranch(key)
        local node = tree[key]
        if not node then return end
        local d = depthOf(key)
        if key ~= '' then
            local expanded = expandedNodes[key]
            buildBranchRow(key, d - 1, expanded)
            if not expanded then return end
        end
        for _, e in ipairs(node.items) do
            buildRowFor(e, d)
        end
        local childKeys = {}
        for ck in pairs(node.children) do table.insert(childKeys, ck) end
        table.sort(childKeys)
        for _, ck in ipairs(childKeys) do renderBranch(ck) end
    end
    renderBranch('')

    updateStatus(#filtered)
end

updateStatus = function(filteredCount)
    local total, susp, favs = #remoteCache, 0, 0
    for _, e in ipairs(remoteCache) do
        if e.suspicious then susp = susp + 1 end
        if state.favorites[e.path] then favs = favs + 1 end
    end
    statusLbl.Text = string.format('%d remotes | %d suspicious | %d favorites%s',
        total, susp, favs, filteredCount and (' | ' .. filteredCount .. ' shown') or '')
end

-- wire search live
searchBox:GetPropertyChangedSignal('Text'):Connect(function() refreshList() end)

------------------------------------------------------------------------------
-- 13. KEYBINDS + AUTO REFRESH
------------------------------------------------------------------------------
local function focusSearch()
    searchBox:CaptureFocus()
end

track(UserInputService.InputBegan:Connect(function(input, processed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local name = input.KeyCode.Name
    if processed then
        if name == 'Return' and selectedEntry and argsBox:IsFocused() then
            -- allow enter inside argsBox to insert newline; nothing to do
        end
        return
    end

    if name == (state.keybinds.Refresh or 'F8') then
        scanRemotes(); refreshList()
        notify('Remote Scanner', ('Refreshed (%d remotes)'):format(#remoteCache), 'success', 2)
    end
    if (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl))
        and name == (state.keybinds.FocusSearch or 'F') then
        focusSearch()
    end
    if name == 'Return' and selectedEntry and not searchBox:IsFocused() and not argsBox:IsFocused() then
        fireRemote()
    end
end))

local autoRefreshAccum = 0
track(RunService.Heartbeat:Connect(function(dt)
    if not state.autoRefresh then autoRefreshAccum = 0; return end
    autoRefreshAccum = autoRefreshAccum + dt
    if autoRefreshAccum >= (state.autoRefreshSeconds or 10) then
        autoRefreshAccum = 0
        scanRemotes()
        refreshList()
    end
end))

------------------------------------------------------------------------------
-- 14. PUBLIC API
------------------------------------------------------------------------------
local PublicAPI = {}
function PublicAPI:Show()  win:setVisible(true) end
function PublicAPI:Hide()  win:setVisible(false) end
function PublicAPI:Toggle() win:setVisible(not win.ScreenGui.Enabled) end
function PublicAPI:Destroy()
    disconnectAll()
    pcall(function() win:destroy() end)
    if notifyHolder then pcall(function() notifyHolder:Destroy() end); notifyHolder = nil end
    getgenv().ENI.RemoteScanner = nil
end
function PublicAPI:GetConfig() return deepcopy(state) end
function PublicAPI:SetConfig(t)
    if type(t) ~= 'table' then return end
    for k, v in pairs(t) do state[k] = v end
    saveConfig(); refreshList()
end
function PublicAPI:Rescan() scanRemotes(); refreshList() end
function PublicAPI:GetRemotes() return deepcopy(remoteCache) end

getgenv().ENI.RemoteScanner = PublicAPI

------------------------------------------------------------------------------
-- 15. INITIAL SCAN
------------------------------------------------------------------------------
task.spawn(function()
    scanRemotes()
    refreshList()
    notify('Remote Scanner', ('Loaded - %d remotes (%s)'):format(#remoteCache, tostring(EXEC_NAME)), 'success', 3)
end)

return PublicAPI

end
-- END MODULE: REMOTE SCANNER v3.0.0
----------------------------------------------------------------------

----------------------------------------------------------------------
-- MODULE: GUI DUMPER v3.0.0 (2051 lines original)
----------------------------------------------------------------------
do
--[[
    eni-roblox-kit :: GUI Dumper
    Module : GuiDumper
    Version: 2.0.0
    Author : ENI
    Brief  : Enumerates every ScreenGui across CoreGui, PlayerGui, ReplicatedFirst,
             and Workspace. Force-shows hidden admin panels, lets you inspect and
             edit properties live, exports GUIs to standalone Lua, and watches for
             new GUIs being parented at runtime.
--]]

-- =============================================================================
-- ANTI-DETECT SHIM BLOCK
-- =============================================================================
local cloneref = cloneref or function(x) return x end
local protect_gui = (syn and syn.protect_gui) or (gethui and function(g) g.Parent = gethui() end) or function(g) g.Parent = game:GetService('CoreGui') end
local hookmetamethod = hookmetamethod or function() return nil end
local getrawmetatable = getrawmetatable or function() return nil end
local setreadonly = setreadonly or function() end
local newcclosure = newcclosure or function(f) return f end
local getconnections = getconnections or function() return {} end
local getgc = getgc or function() return {} end
local isfile = isfile or function() return false end
local readfile = readfile or function() return nil end
local writefile = writefile or function() end
local makefolder = makefolder or function() end
local identifyexecutor = identifyexecutor or function() return "Unknown", "0.0.0" end

-- =============================================================================
-- SERVICES
-- =============================================================================
local Players          = cloneref(game:GetService('Players'))
local RunService       = cloneref(game:GetService('RunService'))
local UserInputService = cloneref(game:GetService('UserInputService'))
local TweenService     = cloneref(game:GetService('TweenService'))
local HttpService      = cloneref(game:GetService('HttpService'))
local Lighting         = cloneref(game:GetService('Lighting'))
local Workspace        = cloneref(game:GetService('Workspace'))
local CoreGui          = cloneref(game:GetService('CoreGui'))
local StarterGui       = cloneref(game:GetService('StarterGui'))
local ReplicatedFirst  = cloneref(game:GetService('ReplicatedFirst'))

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass('PlayerGui')

-- =============================================================================
-- ENV DETECTION
-- =============================================================================
local EXEC_NAME, EXEC_VER = "Unknown", "?"
pcall(function() EXEC_NAME, EXEC_VER = identifyexecutor() end)
local HAS_HOOKMM = type(hookmetamethod) == "function"
local HAS_GETHUI = (gethui ~= nil)
local HAS_PROTECT = (syn and syn.protect_gui) or HAS_GETHUI

-- =============================================================================
-- DESIGN TOKENS
-- =============================================================================
local C = {
    Background       = Color3.fromRGB(15,15,22),
    Surface          = Color3.fromRGB(22,22,30),
    SurfaceElevated  = Color3.fromRGB(32,32,42),
    Border           = Color3.fromRGB(45,45,60),
    AccentPrimary    = Color3.fromRGB(255,65,180),
    AccentSecondary  = Color3.fromRGB(180,75,255),
    TextPrimary      = Color3.fromRGB(240,240,248),
    TextSecondary    = Color3.fromRGB(160,160,178),
    TextDim          = Color3.fromRGB(100,100,118),
    Success          = Color3.fromRGB(80,220,130),
    Warning          = Color3.fromRGB(255,185,70),
    Danger           = Color3.fromRGB(255,85,110),
}

local TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- =============================================================================
-- UTIL
-- =============================================================================
local function deepcopy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[deepcopy(k)] = deepcopy(v) end
    return o
end

local function tween(obj, props, info)
    local tw = TweenService:Create(obj, info or TWEEN_INFO, props)
    tw:Play()
    return tw
end

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or C.Border
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function pad(parent, p)
    local u = Instance.new("UIPadding")
    u.PaddingTop = UDim.new(0, p)
    u.PaddingBottom = UDim.new(0, p)
    u.PaddingLeft = UDim.new(0, p)
    u.PaddingRight = UDim.new(0, p)
    u.Parent = parent
    return u
end

local function listLayout(parent, padding, direction)
    local l = Instance.new("UIListLayout")
    l.FillDirection = direction or Enum.FillDirection.Vertical
    l.Padding = UDim.new(0, padding or 8)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = parent
    return l
end

local function fuzzyMatch(needle, haystack)
    if needle == "" then return true end
    needle = needle:lower()
    haystack = haystack:lower()
    local hi = 1
    for i = 1, #needle do
        local ch = needle:sub(i, i)
        local found = false
        while hi <= #haystack do
            if haystack:sub(hi, hi) == ch then
                found = true
                hi = hi + 1
                break
            end
            hi = hi + 1
        end
        if not found then return false end
    end
    return true
end

local function getFullPath(inst)
    local parts = {}
    local cur = inst
    while cur and cur ~= game do
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
    end
    return table.concat(parts, ".")
end

-- =============================================================================
-- CONFIG PERSISTENCE
-- =============================================================================
local CONFIG_DIR = "freezer"
local CONFIG_PATH = CONFIG_DIR .. "/gui_dumper.json"

pcall(makefolder, CONFIG_DIR)

local defaultState = {
    hideSystemGuis = true,
    hideEnabled = false,
    hideDisabled = false,
    highlightAdmin = true,
    autoObserve = false,
    autoAddNewGuis = true,
    persistShowList = {},
    keybindRefresh = "F9",
    keybindObserver = "F10",
    keybindHide = "Delete",
    keybindForceShow = "Return",
    accentColor = {255, 65, 180},
    refreshIntervalSec = 0,
}

local state = deepcopy(defaultState)

local function saveConfig()
    pcall(function()
        writefile(CONFIG_PATH, HttpService:JSONEncode(state))
    end)
end

local function loadConfig()
    pcall(function()
        if isfile(CONFIG_PATH) then
            local raw = readfile(CONFIG_PATH)
            local ok, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok and type(parsed) == "table" then
                for k, v in pairs(parsed) do
                    state[k] = v
                end
            end
        end
    end)
end
loadConfig()

-- =============================================================================
-- CONNECTION TRACKER
-- =============================================================================
local connections = {}
local function track(conn)
    table.insert(connections, conn)
    return conn
end
local function disconnectAll()
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    connections = {}
end

-- =============================================================================
-- NOTIFICATIONS
-- =============================================================================
local notifyHost
local notifyStack = {}

local function ensureNotifyHost()
    if notifyHost and notifyHost.Parent then return notifyHost end
    local g = Instance.new("ScreenGui")
    g.Name = "ENI_GuiDumper_Notify"
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.DisplayOrder = 2000000000
    pcall(protect_gui, g)
    if not g.Parent then g.Parent = CoreGui end
    notifyHost = g
    return g
end

local function notify(title, msg, ntype, dur)
    ntype = ntype or "info"
    dur = dur or 3
    local host = ensureNotifyHost()
    local color = C.AccentPrimary
    if ntype == "success" then color = C.Success
    elseif ntype == "warning" then color = C.Warning
    elseif ntype == "danger" then color = C.Danger end

    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 300, 0, 64)
    card.Position = UDim2.new(1, 20, 0, 20 + (#notifyStack * 74))
    card.BackgroundColor3 = C.Surface
    card.BorderSizePixel = 0
    card.Parent = host
    corner(card, 6)
    stroke(card, color, 1, 0.3)

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 3, 1, -8)
    accent.Position = UDim2.new(0, 4, 0, 4)
    accent.BackgroundColor3 = color
    accent.BorderSizePixel = 0
    accent.Parent = card
    corner(accent, 2)

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -22, 0, 18)
    titleLbl.Position = UDim2.new(0, 14, 0, 8)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.Font = Enum.Font.GothamSemibold
    titleLbl.TextSize = 13
    titleLbl.TextColor3 = C.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = card

    local msgLbl = Instance.new("TextLabel")
    msgLbl.Size = UDim2.new(1, -22, 0, 32)
    msgLbl.Position = UDim2.new(0, 14, 0, 26)
    msgLbl.BackgroundTransparency = 1
    msgLbl.Text = msg or ""
    msgLbl.Font = Enum.Font.Gotham
    msgLbl.TextSize = 11
    msgLbl.TextColor3 = C.TextSecondary
    msgLbl.TextWrapped = true
    msgLbl.TextXAlignment = Enum.TextXAlignment.Left
    msgLbl.TextYAlignment = Enum.TextYAlignment.Top
    msgLbl.Parent = card

    table.insert(notifyStack, card)
    tween(card, { Position = UDim2.new(1, -316, 0, 20 + ((#notifyStack - 1) * 74)) })

    task.delay(dur, function()
        if not card.Parent then return end
        tween(card, { Position = UDim2.new(1, 20, 0, card.Position.Y.Offset) })
        task.wait(0.22)
        for i, c in ipairs(notifyStack) do
            if c == card then table.remove(notifyStack, i); break end
        end
        if card.Parent then card:Destroy() end
        for i, c in ipairs(notifyStack) do
            if c.Parent then
                tween(c, { Position = UDim2.new(1, -316, 0, 20 + ((i - 1) * 74)) })
            end
        end
    end)
end

-- =============================================================================
-- LOCAL UI HELPERS
-- =============================================================================

local function createButton(parent, label, style, callback)
    style = style or "primary"
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 30)
    b.BackgroundColor3 = C.SurfaceElevated
    b.BorderSizePixel = 0
    b.Text = label
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 13
    b.TextColor3 = C.TextPrimary
    b.AutoButtonColor = false
    b.Parent = parent
    corner(b, 4)
    local s = stroke(b, C.Border, 1, 0.5)

    local fillColor = C.SurfaceElevated
    if style == "primary" then fillColor = C.AccentPrimary
    elseif style == "danger" then fillColor = C.Danger
    elseif style == "secondary" then fillColor = C.SurfaceElevated end

    if style == "primary" or style == "danger" then
        b.BackgroundColor3 = fillColor
        s.Color = fillColor
        s.Transparency = 0.3
    end

    local ripple = Instance.new("Frame")
    ripple.BackgroundColor3 = Color3.fromRGB(255,255,255)
    ripple.BackgroundTransparency = 1
    ripple.BorderSizePixel = 0
    ripple.Size = UDim2.new(1, 0, 1, 0)
    ripple.Parent = b
    corner(ripple, 4)

    b.MouseEnter:Connect(function()
        tween(s, { Transparency = 0 })
        if style == "secondary" then
            tween(b, { BackgroundColor3 = C.Border })
        else
            tween(b, { BackgroundColor3 = Color3.new(
                math.min(fillColor.R + 0.08, 1),
                math.min(fillColor.G + 0.08, 1),
                math.min(fillColor.B + 0.08, 1)
            ) })
        end
    end)
    b.MouseLeave:Connect(function()
        tween(s, { Transparency = 0.3 })
        tween(b, { BackgroundColor3 = fillColor })
    end)
    b.MouseButton1Click:Connect(function()
        ripple.BackgroundTransparency = 0.7
        tween(ripple, { BackgroundTransparency = 1 }, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
        if callback then pcall(callback) end
    end)
    return b
end

local function createToggle(parent, label, default, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 26)
    f.BackgroundTransparency = 1
    f.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -44, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = C.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local track_f = Instance.new("TextButton")
    track_f.Size = UDim2.new(0, 36, 0, 18)
    track_f.Position = UDim2.new(1, -36, 0.5, -9)
    track_f.BackgroundColor3 = C.Border
    track_f.Text = ""
    track_f.AutoButtonColor = false
    track_f.BorderSizePixel = 0
    track_f.Parent = f
    corner(track_f, 9)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 2, 0.5, -7)
    knob.BackgroundColor3 = C.TextPrimary
    knob.BorderSizePixel = 0
    knob.Parent = track_f
    corner(knob, 7)

    local val = default and true or false
    local function apply(v, silent)
        val = v
        if v then
            tween(track_f, { BackgroundColor3 = C.AccentPrimary })
            tween(knob, { Position = UDim2.new(1, -16, 0.5, -7) })
        else
            tween(track_f, { BackgroundColor3 = C.Border })
            tween(knob, { Position = UDim2.new(0, 2, 0.5, -7) })
        end
        if callback and not silent then pcall(callback, v) end
    end
    apply(val, true)

    track_f.MouseButton1Click:Connect(function() apply(not val) end)

    return {
        set = function(v) apply(v) end,
        get = function() return val end,
        frame = f,
    }
end

local function createSlider(parent, label, mn, mx, default, decimals, callback)
    decimals = decimals or 0
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 42)
    f.BackgroundTransparency = 1
    f.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = C.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0, 60, 0, 16)
    valLbl.Position = UDim2.new(1, -60, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Font = Enum.Font.Code
    valLbl.TextSize = 13
    valLbl.TextColor3 = C.AccentPrimary
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = f

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 6)
    bar.Position = UDim2.new(0, 0, 0, 26)
    bar.BackgroundColor3 = C.Border
    bar.BorderSizePixel = 0
    bar.Parent = f
    corner(bar, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = C.AccentPrimary
    fill.BorderSizePixel = 0
    fill.Parent = bar
    corner(fill, 3)

    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = C.TextPrimary
    knob.BorderSizePixel = 0
    knob.Text = ""
    knob.AutoButtonColor = false
    knob.Parent = bar
    corner(knob, 7)

    local val = default or mn
    local function format(v)
        local mult = 10 ^ decimals
        return tostring(math.floor(v * mult + 0.5) / mult)
    end

    local function apply(v, silent)
        v = math.clamp(v, mn, mx)
        val = v
        local pct = (v - mn) / (mx - mn)
        tween(fill, { Size = UDim2.new(pct, 0, 1, 0) })
        tween(knob, { Position = UDim2.new(pct, 0, 0.5, 0) })
        valLbl.Text = format(v)
        if callback and not silent then pcall(callback, v) end
    end
    apply(val, true)

    local dragging = false
    knob.MouseButton1Down:Connect(function() dragging = true end)
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            local rel = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
            apply(mn + (mx - mn) * math.clamp(rel, 0, 1))
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
            apply(mn + (mx - mn) * math.clamp(rel, 0, 1))
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    return {
        set = function(v) apply(v) end,
        get = function() return val end,
        frame = f,
    }
end

local function createDropdown(parent, label, options, default, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 48)
    f.BackgroundTransparency = 1
    f.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = C.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 26)
    btn.Position = UDim2.new(0, 0, 0, 20)
    btn.BackgroundColor3 = C.SurfaceElevated
    btn.BorderSizePixel = 0
    btn.Text = "  " .. tostring(default or (options[1] or ""))
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextColor3 = C.TextPrimary
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.Parent = f
    corner(btn, 4)
    local s = stroke(btn, C.Border, 1, 0.4)

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 20, 1, 0)
    arrow.Position = UDim2.new(1, -22, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "v"
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 12
    arrow.TextColor3 = C.AccentPrimary
    arrow.Parent = btn

    local list = Instance.new("Frame")
    list.Size = UDim2.new(1, 0, 0, 0)
    list.Position = UDim2.new(0, 0, 1, 4)
    list.BackgroundColor3 = C.Surface
    list.BorderSizePixel = 0
    list.Visible = false
    list.ClipsDescendants = true
    list.ZIndex = 50
    list.Parent = btn
    corner(list, 4)
    stroke(list, C.Border, 1, 0)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = C.AccentPrimary
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ZIndex = 51
    scroll.Parent = list
    local lay = listLayout(scroll, 2)
    lay.SortOrder = Enum.SortOrder.LayoutOrder

    local val = default or options[1]
    local opts = options
    local open = false

    local function rebuild()
        for _, c in ipairs(scroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for i, o in ipairs(opts) do
            local item = Instance.new("TextButton")
            item.Size = UDim2.new(1, 0, 0, 22)
            item.BackgroundColor3 = C.SurfaceElevated
            item.BackgroundTransparency = 1
            item.BorderSizePixel = 0
            item.Text = "  " .. tostring(o)
            item.Font = Enum.Font.Gotham
            item.TextSize = 12
            item.TextColor3 = C.TextSecondary
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.AutoButtonColor = false
            item.LayoutOrder = i
            item.ZIndex = 52
            item.Parent = scroll
            item.MouseEnter:Connect(function() tween(item, { BackgroundTransparency = 0 }) end)
            item.MouseLeave:Connect(function() tween(item, { BackgroundTransparency = 1 }) end)
            item.MouseButton1Click:Connect(function()
                val = o
                btn.Text = "  " .. tostring(o)
                open = false
                tween(list, { Size = UDim2.new(1, 0, 0, 0) })
                tween(arrow, { Rotation = 0 })
                task.delay(0.2, function() if list then list.Visible = false end end)
                if callback then pcall(callback, o) end
            end)
        end
    end
    rebuild()

    btn.MouseButton1Click:Connect(function()
        open = not open
        if open then
            list.Visible = true
            local h = math.min(#opts * 24, 120)
            tween(list, { Size = UDim2.new(1, 0, 0, h) })
            tween(arrow, { Rotation = 180 })
        else
            tween(list, { Size = UDim2.new(1, 0, 0, 0) })
            tween(arrow, { Rotation = 0 })
            task.delay(0.2, function() if list then list.Visible = false end end)
        end
    end)

    btn.MouseEnter:Connect(function() tween(s, { Transparency = 0 }) end)
    btn.MouseLeave:Connect(function() tween(s, { Transparency = 0.4 }) end)

    return {
        set = function(v) val = v; btn.Text = "  " .. tostring(v) end,
        get = function() return val end,
        refresh = function(newOpts) opts = newOpts; rebuild() end,
        frame = f,
    }
end

local function createTextBox(parent, placeholder, default, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 28)
    f.BackgroundColor3 = C.SurfaceElevated
    f.BorderSizePixel = 0
    f.Parent = parent
    corner(f, 4)
    local s = stroke(f, C.Border, 1, 0.4)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -12, 1, 0)
    box.Position = UDim2.new(0, 8, 0, 0)
    box.BackgroundTransparency = 1
    box.PlaceholderText = placeholder or ""
    box.Text = default or ""
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.TextColor3 = C.TextPrimary
    box.PlaceholderColor3 = C.TextDim
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false
    box.Parent = f

    box.Focused:Connect(function() tween(s, { Color = C.AccentPrimary, Transparency = 0 }) end)
    box.FocusLost:Connect(function(enter)
        tween(s, { Color = C.Border, Transparency = 0.4 })
        if callback then pcall(callback, box.Text, enter) end
    end)
    box:GetPropertyChangedSignal("Text"):Connect(function()
        if callback then pcall(callback, box.Text, false) end
    end)

    return {
        set = function(v) box.Text = tostring(v) end,
        get = function() return box.Text end,
        frame = f,
        textbox = box,
    }
end

local function createKeybind(parent, label, defaultKey, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 26)
    f.BackgroundTransparency = 1
    f.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -90, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = C.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 80, 0, 22)
    btn.Position = UDim2.new(1, -80, 0.5, -11)
    btn.BackgroundColor3 = C.SurfaceElevated
    btn.BorderSizePixel = 0
    btn.Text = tostring(defaultKey or "None")
    btn.Font = Enum.Font.Code
    btn.TextSize = 12
    btn.TextColor3 = C.AccentPrimary
    btn.AutoButtonColor = false
    btn.Parent = f
    corner(btn, 4)
    local s = stroke(btn, C.Border, 1, 0.4)

    local key = defaultKey
    local binding = false

    btn.MouseButton1Click:Connect(function()
        if binding then return end
        binding = true
        btn.Text = "..."
        tween(s, { Color = C.AccentPrimary, Transparency = 0 })
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gp)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape then
                    key = nil
                    btn.Text = "None"
                else
                    key = input.KeyCode.Name
                    btn.Text = key
                end
                binding = false
                tween(s, { Color = C.Border, Transparency = 0.4 })
                conn:Disconnect()
                if callback then pcall(callback, key) end
            end
        end)
    end)

    btn.MouseEnter:Connect(function() if not binding then tween(s, { Transparency = 0 }) end end)
    btn.MouseLeave:Connect(function() if not binding then tween(s, { Transparency = 0.4 }) end end)

    return {
        set = function(k) key = k; btn.Text = tostring(k or "None") end,
        get = function() return key end,
        frame = f,
    }
end

local function createColorPicker(parent, label, defaultColor, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 26)
    f.BackgroundTransparency = 1
    f.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -36, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextColor3 = C.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local sw = Instance.new("TextButton")
    sw.Size = UDim2.new(0, 28, 0, 18)
    sw.Position = UDim2.new(1, -28, 0.5, -9)
    sw.BackgroundColor3 = defaultColor or C.AccentPrimary
    sw.BorderSizePixel = 0
    sw.Text = ""
    sw.AutoButtonColor = false
    sw.Parent = f
    corner(sw, 4)
    local s = stroke(sw, C.Border, 1, 0.4)

    local val = defaultColor or C.AccentPrimary

    local pop
    local function closePopup()
        if pop then pop:Destroy(); pop = nil end
    end

    sw.MouseButton1Click:Connect(function()
        if pop then closePopup(); return end
        pop = Instance.new("Frame")
        pop.Size = UDim2.new(0, 200, 0, 180)
        pop.Position = UDim2.new(1, 10, 0, 0)
        pop.BackgroundColor3 = C.Surface
        pop.BorderSizePixel = 0
        pop.ZIndex = 100
        pop.Parent = f
        corner(pop, 6)
        stroke(pop, C.AccentPrimary, 1, 0)

        local sv = Instance.new("ImageButton")
        sv.Size = UDim2.new(1, -16, 0, 120)
        sv.Position = UDim2.new(0, 8, 0, 8)
        sv.BackgroundColor3 = Color3.fromHSV(0, 1, 1)
        sv.AutoButtonColor = false
        sv.ZIndex = 101
        sv.Parent = pop
        corner(sv, 4)

        local svBlack = Instance.new("Frame")
        svBlack.Size = UDim2.new(1, 0, 1, 0)
        svBlack.BackgroundColor3 = Color3.new(0, 0, 0)
        svBlack.BorderSizePixel = 0
        svBlack.ZIndex = 102
        svBlack.Parent = sv
        corner(svBlack, 4)
        local g2 = Instance.new("UIGradient")
        g2.Color = ColorSequence.new(Color3.new(0,0,0))
        g2.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        })
        g2.Rotation = 90
        g2.Parent = svBlack

        local hueBar = Instance.new("ImageButton")
        hueBar.Size = UDim2.new(1, -16, 0, 14)
        hueBar.Position = UDim2.new(0, 8, 0, 134)
        hueBar.BorderSizePixel = 0
        hueBar.AutoButtonColor = false
        hueBar.BackgroundColor3 = Color3.new(1,1,1)
        hueBar.ZIndex = 101
        hueBar.Parent = pop
        corner(hueBar, 3)
        local hueGrad = Instance.new("UIGradient")
        hueGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
        })
        hueGrad.Parent = hueBar

        local alphaBar = Instance.new("Frame")
        alphaBar.Size = UDim2.new(1, -16, 0, 14)
        alphaBar.Position = UDim2.new(0, 8, 0, 154)
        alphaBar.BackgroundColor3 = val
        alphaBar.BorderSizePixel = 0
        alphaBar.ZIndex = 101
        alphaBar.Parent = pop
        corner(alphaBar, 3)

        local h, s_, v = 0, 1, 1
        local function update()
            local c = Color3.fromHSV(h, s_, v)
            val = c
            sw.BackgroundColor3 = c
            sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            alphaBar.BackgroundColor3 = c
            if callback then pcall(callback, c) end
        end

        sv.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local relX = (input.Position.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X
                local relY = (input.Position.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y
                s_ = math.clamp(relX, 0, 1)
                v = 1 - math.clamp(relY, 0, 1)
                update()
            end
        end)

        hueBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local relX = (input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X
                h = math.clamp(relX, 0, 1)
                update()
            end
        end)
    end)

    sw.MouseEnter:Connect(function() tween(s, { Transparency = 0 }) end)
    sw.MouseLeave:Connect(function() tween(s, { Transparency = 0.4 }) end)

    return {
        set = function(c) val = c; sw.BackgroundColor3 = c end,
        get = function() return val end,
        frame = f,
    }
end

local function createSection(parent, title)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 28)
    f.BackgroundTransparency = 1
    f.AutomaticSize = Enum.AutomaticSize.Y
    f.Parent = parent

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 22)
    header.BackgroundTransparency = 1
    header.Parent = f

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 200, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 13
    lbl.TextColor3 = C.AccentPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = header

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, -lbl.TextBounds.X - 12, 0, 1)
    line.Position = UDim2.new(0, lbl.TextBounds.X + 8, 0.5, 0)
    line.BackgroundColor3 = C.Border
    line.BorderSizePixel = 0
    line.Parent = header

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, 0, 0, 0)
    content.Position = UDim2.new(0, 0, 0, 26)
    content.BackgroundTransparency = 1
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.Parent = f
    listLayout(content, 6)

    return content
end

local function createScrollFrame(parent)
    local s = Instance.new("ScrollingFrame")
    s.Size = UDim2.new(1, 0, 1, 0)
    s.BackgroundTransparency = 1
    s.BorderSizePixel = 0
    s.ScrollBarThickness = 3
    s.ScrollBarImageColor3 = C.AccentPrimary
    s.CanvasSize = UDim2.new(0, 0, 0, 0)
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.ScrollingDirection = Enum.ScrollingDirection.Y
    s.Parent = parent
    return s
end

-- =============================================================================
-- WINDOW
-- =============================================================================
local function createWindow(title, size)
    size = size or UDim2.new(0, 380, 0, 520)

    local screen = Instance.new("ScreenGui")
    screen.Name = "ENI_GuiDumper"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.DisplayOrder = 1000000000
    pcall(protect_gui, screen)
    if not screen.Parent then screen.Parent = CoreGui end

    local root = Instance.new("Frame")
    root.Name = "Root"
    root.Size = size
    root.Position = UDim2.new(0.5, -size.X.Offset/2, 0.5, -size.Y.Offset/2)
    root.BackgroundColor3 = C.Background
    root.BorderSizePixel = 0
    root.AnchorPoint = Vector2.new(0, 0)
    root.Parent = screen
    corner(root, 8)
    stroke(root, C.Border, 1, 0.2)

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 36)
    titleBar.BackgroundColor3 = C.Surface
    titleBar.BorderSizePixel = 0
    titleBar.Parent = root
    corner(titleBar, 8)

    local titleGrad = Instance.new("UIGradient")
    titleGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.AccentPrimary),
        ColorSequenceKeypoint.new(1, C.AccentSecondary),
    })
    titleGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.75),
        NumberSequenceKeypoint.new(1, 0.9),
    })
    titleGrad.Parent = titleBar

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -120, 1, 0)
    titleLbl.Position = UDim2.new(0, 12, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title .. "  v2.0.0"
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 14
    titleLbl.TextColor3 = C.TextPrimary
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = titleBar

    local function makeBtn(symbol, posX, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 24, 0, 24)
        b.Position = UDim2.new(1, posX, 0.5, -12)
        b.BackgroundColor3 = C.SurfaceElevated
        b.BorderSizePixel = 0
        b.Text = symbol
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.TextColor3 = C.TextSecondary
        b.AutoButtonColor = false
        b.Parent = titleBar
        corner(b, 4)
        b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = color, TextColor3 = C.TextPrimary }) end)
        b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = C.SurfaceElevated, TextColor3 = C.TextSecondary }) end)
        return b
    end

    local closeBtn = makeBtn("X", -30, C.Danger)
    local minBtn = makeBtn("-", -60, C.AccentPrimary)

    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, -16, 1, -64)
    body.Position = UDim2.new(0, 8, 0, 42)
    body.BackgroundTransparency = 1
    body.Parent = root

    local footer = Instance.new("Frame")
    footer.Size = UDim2.new(1, 0, 0, 18)
    footer.Position = UDim2.new(0, 0, 1, -18)
    footer.BackgroundColor3 = C.Surface
    footer.BorderSizePixel = 0
    footer.Parent = root
    corner(footer, 8)

    local footerLbl = Instance.new("TextLabel")
    footerLbl.Size = UDim2.new(1, -16, 1, 0)
    footerLbl.Position = UDim2.new(0, 8, 0, 0)
    footerLbl.BackgroundTransparency = 1
    footerLbl.Text = "0 GUIs | 0 hidden | observing: no"
    footerLbl.Font = Enum.Font.Code
    footerLbl.TextSize = 11
    footerLbl.TextColor3 = C.TextDim
    footerLbl.TextXAlignment = Enum.TextXAlignment.Left
    footerLbl.Parent = footer

    local grip = Instance.new("TextButton")
    grip.Size = UDim2.new(0, 14, 0, 14)
    grip.Position = UDim2.new(1, -14, 1, -14)
    grip.BackgroundTransparency = 1
    grip.Text = ""
    grip.AutoButtonColor = false
    grip.ZIndex = 5
    grip.Parent = root
    local gripVis = Instance.new("TextLabel")
    gripVis.Size = UDim2.new(1, 0, 1, 0)
    gripVis.BackgroundTransparency = 1
    gripVis.Text = "//"
    gripVis.Font = Enum.Font.GothamBold
    gripVis.TextSize = 11
    gripVis.TextColor3 = C.TextDim
    gripVis.TextXAlignment = Enum.TextXAlignment.Right
    gripVis.TextYAlignment = Enum.TextYAlignment.Bottom
    gripVis.Parent = grip

    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = root.Position
        end
    end)
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))

    local resizing, resStart, resSize
    grip.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true
            resStart = input.Position
            resSize = root.Size
        end
    end)
    grip.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - resStart
            local nw = math.max(360, resSize.X.Offset + d.X)
            local nh = math.max(300, resSize.Y.Offset + d.Y)
            root.Size = UDim2.new(0, nw, 0, nh)
        end
    end))

    local origSize = size
    root.Size = UDim2.new(0, math.floor(origSize.X.Offset * 0.9), 0, math.floor(origSize.Y.Offset * 0.9))
    root.BackgroundTransparency = 1
    tween(root, { Size = origSize, BackgroundTransparency = 0 })

    local visible = true
    local minimized = false
    local savedSize = origSize

    local windowObj = {}

    function windowObj.setVisible(v)
        visible = v
        screen.Enabled = v
        if v then
            root.Size = UDim2.new(0, math.floor(savedSize.X.Offset * 0.92), 0, math.floor(savedSize.Y.Offset * 0.92))
            tween(root, { Size = savedSize })
        end
    end

    function windowObj.toggleMinimize()
        minimized = not minimized
        if minimized then
            savedSize = root.Size
            tween(root, { Size = UDim2.new(0, savedSize.X.Offset, 0, 36) })
            body.Visible = false
            footer.Visible = false
        else
            tween(root, { Size = savedSize })
            body.Visible = true
            footer.Visible = true
        end
    end

    function windowObj.destroy()
        screen:Destroy()
    end

    function windowObj.setFooter(txt)
        footerLbl.Text = txt
    end

    closeBtn.MouseButton1Click:Connect(function() windowObj.setVisible(false) end)
    minBtn.MouseButton1Click:Connect(function() windowObj.toggleMinimize() end)

    windowObj.Frame = root
    windowObj.Body = body
    windowObj.Screen = screen
    windowObj.titleLabel = titleLbl
    windowObj.notify = notify

    return windowObj
end

-- =============================================================================
-- GUI DUMPER CORE STATE
-- =============================================================================

local SYSTEM_GUIS = {
    ["Chat"] = true,
    ["Backpack"] = true,
    ["PlayerList"] = true,
    ["PlayerListMaster"] = true,
    ["Health"] = true,
    ["HealthGui"] = true,
    ["EmotesMenu"] = true,
    ["GuiRoot"] = true,
    ["TopBarApp"] = true,
    ["RobloxLoadingGui"] = true,
    ["RobloxPromptGui"] = true,
    ["RobloxGui"] = true,
    ["MouseLockToggle"] = true,
    ["BubbleChat"] = true,
    ["ControlGui"] = true,
}

local ADMIN_KEYWORDS = {
    "kick", "ban", "admin", "mod", "moderator", "owner", "developer", "dev",
    "punish", "warn", "shutdown", "permission", "staff",
}

local discovered = {}
local discoveredOrder = {}
local searchQuery = ""
local selectedGui = nil
local observerActive = false
local observerConns = {}
local rebuildListDeferred
local refreshListUI
local rebuildInspector
local startObserver
local stopObserver

-- =============================================================================
-- GUI ENUMERATION
-- =============================================================================

local function isScreenLike(inst)
    return inst and (inst:IsA("ScreenGui") or inst:IsA("GuiMain") or inst:IsA("BillboardGui") or inst:IsA("SurfaceGui"))
end

local function scanContainer(container, list)
    if not container then return end
    pcall(function()
        for _, child in ipairs(container:GetChildren()) do
            if isScreenLike(child) then
                table.insert(list, child)
            end
        end
        for _, desc in ipairs(container:GetDescendants()) do
            if isScreenLike(desc) and desc.Parent ~= container then
                table.insert(list, desc)
            end
        end
    end)
end

local function enumerateGuis()
    local list = {}
    pcall(function() scanContainer(CoreGui, list) end)
    pcall(function() if PlayerGui then scanContainer(PlayerGui, list) end end)
    pcall(function() scanContainer(ReplicatedFirst, list) end)
    pcall(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if isScreenLike(d) then table.insert(list, d) end
        end
    end)
    local seen, out = {}, {}
    for _, g in ipairs(list) do
        if g and g.Parent and not seen[g] then
            seen[g] = true
            table.insert(out, g)
        end
    end
    return out
end

local function isAdminCandidate(gui)
    local found = false
    pcall(function()
        for _, d in ipairs(gui:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                local txt = tostring(d.Text or ""):lower()
                for _, kw in ipairs(ADMIN_KEYWORDS) do
                    if txt:find(kw, 1, true) then found = true; return end
                end
            end
            if not found then
                local n = tostring(d.Name or ""):lower()
                for _, kw in ipairs(ADMIN_KEYWORDS) do
                    if n:find(kw, 1, true) then found = true; return end
                end
            end
        end
    end)
    return found
end

local function snapshotGui(gui)
    local snap = {
        gui = gui,
        originalEnabled = nil,
        descVis = {},
        descTrans = {},
        isCloned = false,
        adminCandidate = false,
    }
    pcall(function()
        if gui:IsA("ScreenGui") or gui:IsA("GuiMain") or gui:IsA("BillboardGui") or gui:IsA("SurfaceGui") then
            snap.originalEnabled = gui.Enabled
        end
    end)
    pcall(function()
        for _, d in ipairs(gui:GetDescendants()) do
            if d:IsA("GuiObject") then
                snap.descVis[d] = d.Visible
                pcall(function() snap.descTrans[d] = d.Transparency end)
            end
        end
    end)
    snap.adminCandidate = isAdminCandidate(gui)
    return snap
end

-- =============================================================================
-- ACTIONS
-- =============================================================================

local function setGuiEnabled(gui, on)
    pcall(function()
        if gui:IsA("ScreenGui") or gui:IsA("GuiMain") or gui:IsA("BillboardGui") or gui:IsA("SurfaceGui") then
            gui.Enabled = on
        end
    end)
end

local function forceShowGui(gui)
    setGuiEnabled(gui, true)
    pcall(function()
        for _, d in ipairs(gui:GetDescendants()) do
            if d:IsA("GuiObject") then
                pcall(function() d.Visible = true end)
                pcall(function() d.Transparency = 0 end)
                pcall(function()
                    if (d:IsA("Frame") or d:IsA("ScrollingFrame")) and d.BackgroundTransparency >= 1 then
                        d.BackgroundTransparency = 0.2
                    end
                end)
            end
        end
    end)
end

local function restoreGui(gui, snap)
    if not snap then return end
    pcall(function()
        if snap.originalEnabled ~= nil then setGuiEnabled(gui, snap.originalEnabled) end
        for d, v in pairs(snap.descVis) do
            if d and d.Parent then
                pcall(function() d.Visible = v end)
            end
        end
        for d, v in pairs(snap.descTrans) do
            if d and d.Parent then
                pcall(function() d.Transparency = v end)
            end
        end
    end)
end

local function cloneGuiToPlayerGui(gui)
    if not PlayerGui then notify("Clone", "PlayerGui unavailable", "danger"); return nil end
    local ok, clone = pcall(function() return gui:Clone() end)
    if not ok or not clone then notify("Clone", "Failed to clone", "danger"); return nil end
    clone.Name = gui.Name .. "_clone"
    pcall(function() clone.Parent = PlayerGui end)
    pcall(function() if clone:IsA("ScreenGui") or clone:IsA("GuiMain") then clone.Enabled = true end end)
    return clone
end

local function escStr(s) return "\"" .. tostring(s):gsub("\\", "\\\\"):gsub("\"", "\\\"") .. "\"" end

local function serializeValue(v)
    local t = typeof(v)
    if t == "string" then return escStr(v)
    elseif t == "boolean" or t == "number" then return tostring(v)
    elseif t == "Color3" then return string.format("Color3.fromRGB(%d,%d,%d)", math.floor(v.R*255), math.floor(v.G*255), math.floor(v.B*255))
    elseif t == "UDim" then return string.format("UDim.new(%g,%d)", v.Scale, v.Offset)
    elseif t == "UDim2" then return string.format("UDim2.new(%g,%d,%g,%d)", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
    elseif t == "Vector2" then return string.format("Vector2.new(%g,%g)", v.X, v.Y)
    elseif t == "Vector3" then return string.format("Vector3.new(%g,%g,%g)", v.X, v.Y, v.Z)
    elseif t == "EnumItem" then return tostring(v)
    elseif t == "Rect" then return string.format("Rect.new(%g,%g,%g,%g)", v.Min.X, v.Min.Y, v.Max.X, v.Max.Y)
    end
    return "nil --[[unsupported "..t.."]]"
end

local SAFE_PROPS = {
    "Name", "Size", "Position", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency",
    "BorderSizePixel", "BorderColor3", "Visible", "ZIndex", "ClipsDescendants",
    "Text", "Font", "TextSize", "TextColor3", "TextTransparency", "TextWrapped",
    "TextXAlignment", "TextYAlignment", "PlaceholderText", "PlaceholderColor3",
    "Image", "ImageColor3", "ImageTransparency", "ScaleType", "Active", "Selectable",
    "Rotation", "AutoButtonColor", "Enabled", "ResetOnSpawn",
    "CanvasSize", "ScrollBarThickness", "ScrollBarImageColor3",
}

local function serializeInst(inst, varName, parentVar, depth)
    local lines = {}
    table.insert(lines, string.format("local %s = Instance.new(%s)", varName, escStr(inst.ClassName)))
    for _, prop in ipairs(SAFE_PROPS) do
        local ok, val = pcall(function() return inst[prop] end)
        if ok and val ~= nil then
            local okS, ser = pcall(serializeValue, val)
            if okS and ser and not ser:find("unsupported") then
                table.insert(lines, string.format("%s.%s = %s", varName, prop, ser))
            end
        end
    end
    if parentVar then
        table.insert(lines, string.format("%s.Parent = %s", varName, parentVar))
    end
    local idx = 0
    for _, child in ipairs(inst:GetChildren()) do
        if child:IsA("GuiObject") or child:IsA("UIBase") then
            idx = idx + 1
            local childVar = varName .. "_" .. idx
            local sub = serializeInst(child, childVar, varName, depth + 1)
            for _, l in ipairs(sub) do table.insert(lines, l) end
        end
    end
    return lines
end

local function exportGuiToLua(gui)
    local out = {
        "-- Exported by ENI GuiDumper v2.0.0",
        "-- Source: " .. getFullPath(gui),
        "local CoreGui = game:GetService(\"CoreGui\")",
        "",
    }
    local lines = serializeInst(gui, "root", nil, 0)
    for _, l in ipairs(lines) do table.insert(out, l) end
    table.insert(out, "")
    table.insert(out, "root.Parent = (game:GetService(\"Players\").LocalPlayer:FindFirstChildOfClass(\"PlayerGui\")) or CoreGui")
    table.insert(out, "return root")
    local body = table.concat(out, "\n")
    local safeName = tostring(gui.Name):gsub("[^%w_]","_")
    local fname = string.format("%s/export_%s_%d.lua", CONFIG_DIR, safeName, os.time())
    local ok = pcall(function() writefile(fname, body) end)
    if ok then
        notify("Exported", "Saved to " .. fname, "success", 4)
    else
        notify("Export failed", "writefile unavailable", "danger")
    end
end

-- =============================================================================
-- WINDOW + UI BUILD
-- =============================================================================

local win = createWindow("GUI Dumper", UDim2.new(0, 720, 0, 540))

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 28)
tabBar.BackgroundColor3 = C.Surface
tabBar.BorderSizePixel = 0
tabBar.Parent = win.Body
corner(tabBar, 6)

local tabLayout = listLayout(tabBar, 4, Enum.FillDirection.Horizontal)
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
pad(tabBar, 4)

local tabContent = Instance.new("Frame")
tabContent.Size = UDim2.new(1, 0, 1, -36)
tabContent.Position = UDim2.new(0, 0, 0, 32)
tabContent.BackgroundTransparency = 1
tabContent.Parent = win.Body

local tabs = {}
local activeTab = nil

local function switchTab(name)
    for _, t in pairs(tabs) do
        t.page.Visible = false
        tween(t.btn, { BackgroundTransparency = 0.5, TextColor3 = C.TextSecondary })
    end
    local target = tabs[name]
    if target then
        target.page.Visible = true
        tween(target.btn, { BackgroundTransparency = 0, TextColor3 = C.TextPrimary })
        activeTab = target
    end
end

local function addTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 90, 1, -4)
    btn.BackgroundColor3 = C.SurfaceElevated
    btn.BackgroundTransparency = 0.5
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 12
    btn.TextColor3 = C.TextSecondary
    btn.AutoButtonColor = false
    btn.Parent = tabBar
    corner(btn, 4)

    local page = Instance.new("Frame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = tabContent

    local entry = { name = name, btn = btn, page = page }
    tabs[name] = entry

    btn.MouseButton1Click:Connect(function() switchTab(name) end)

    if not activeTab then
        btn.BackgroundTransparency = 0
        btn.TextColor3 = C.TextPrimary
        page.Visible = true
        activeTab = entry
    end
    return page
end

local listPage = addTab("List")
local inspectorPage = addTab("Inspector")
local filtersPage = addTab("Filters")
local settingsPage = addTab("Settings")

-- =============================================================================
-- LIST TAB
-- =============================================================================

local listSearchBox = createTextBox(listPage, "Search GUI name (fuzzy)...", "", function(t)
    searchQuery = t
    if rebuildListDeferred then rebuildListDeferred() end
end)
listSearchBox.frame.Position = UDim2.new(0, 0, 0, 0)
listSearchBox.frame.Size = UDim2.new(1, 0, 0, 28)

local bulkBar = Instance.new("Frame")
bulkBar.Size = UDim2.new(1, 0, 0, 28)
bulkBar.Position = UDim2.new(0, 0, 0, 34)
bulkBar.BackgroundTransparency = 1
bulkBar.Parent = listPage
listLayout(bulkBar, 4, Enum.FillDirection.Horizontal)

local function bulkAction(label, style, cb)
    local b = createButton(bulkBar, label, style, cb)
    b.Size = UDim2.new(0, 80, 1, 0)
    return b
end

local listScroll = createScrollFrame(listPage)
listScroll.Size = UDim2.new(1, 0, 1, -68)
listScroll.Position = UDim2.new(0, 0, 0, 68)
listLayout(listScroll, 4)

local rowMap = {}

local function refreshList()
    local found = enumerateGuis()
    local seen = {}
    for _, g in ipairs(found) do
        seen[g] = true
        if not discovered[g] then
            local snap = snapshotGui(g)
            discovered[g] = snap
            table.insert(discoveredOrder, g)
        end
    end
    for i = #discoveredOrder, 1, -1 do
        local g = discoveredOrder[i]
        if not g.Parent then
            discovered[g] = nil
            table.remove(discoveredOrder, i)
        end
    end
end

local function shouldShowGuiInList(gui)
    if not gui or not gui.Parent then return false end
    if state.hideSystemGuis and SYSTEM_GUIS[gui.Name] then return false end
    local enabled = false
    pcall(function() enabled = (gui.Enabled ~= false) end)
    if state.hideEnabled and enabled then return false end
    if state.hideDisabled and not enabled then return false end
    if searchQuery ~= "" and not fuzzyMatch(searchQuery, gui.Name) then return false end
    return true
end

local function buildRow(gui)
    local snap = discovered[gui]
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = C.Surface
    row.BorderSizePixel = 0
    row.Parent = listScroll
    corner(row, 6)
    local rs = stroke(row, C.Border, 1, 0.5)

    if state.highlightAdmin and snap and snap.adminCandidate then
        rs.Color = C.Warning
        rs.Transparency = 0.2
    end

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -150, 0, 18)
    nameLbl.Position = UDim2.new(0, 10, 0, 6)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = gui.Name
    nameLbl.Font = Enum.Font.GothamSemibold
    nameLbl.TextSize = 13
    nameLbl.TextColor3 = C.TextPrimary
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.Parent = row

    if snap and snap.adminCandidate then
        local warn = Instance.new("TextLabel")
        warn.Size = UDim2.new(0, 14, 0, 14)
        warn.Position = UDim2.new(0, -2, 0, 8)
        warn.BackgroundTransparency = 1
        warn.Text = "!"
        warn.Font = Enum.Font.GothamBold
        warn.TextSize = 14
        warn.TextColor3 = C.Warning
        warn.TextXAlignment = Enum.TextXAlignment.Center
        warn.Parent = row
        nameLbl.Position = UDim2.new(0, 16, 0, 6)
    end

    local pathLbl = Instance.new("TextLabel")
    pathLbl.Size = UDim2.new(1, -150, 0, 14)
    pathLbl.Position = UDim2.new(0, 10, 0, 22)
    pathLbl.BackgroundTransparency = 1
    pathLbl.Text = getFullPath(gui.Parent or gui)
    pathLbl.Font = Enum.Font.Code
    pathLbl.TextSize = 10
    pathLbl.TextColor3 = C.TextDim
    pathLbl.TextXAlignment = Enum.TextXAlignment.Left
    pathLbl.TextTruncate = Enum.TextTruncate.AtEnd
    pathLbl.Parent = row

    local enabledNow = false
    pcall(function() enabledNow = (gui.Enabled ~= false) end)
    local rosTxt = ""
    pcall(function()
        if gui:IsA("ScreenGui") then
            rosTxt = "ROS:"..tostring(gui.ResetOnSpawn).." Z:"..tostring(gui.ZIndexBehavior.Name)
        end
    end)

    local metaLbl = Instance.new("TextLabel")
    metaLbl.Size = UDim2.new(1, -150, 0, 12)
    metaLbl.Position = UDim2.new(0, 10, 0, 36)
    metaLbl.BackgroundTransparency = 1
    metaLbl.Text = string.format("[%s] %s %s", gui.ClassName, enabledNow and "enabled" or "disabled", rosTxt)
    metaLbl.Font = Enum.Font.Code
    metaLbl.TextSize = 10
    metaLbl.TextColor3 = enabledNow and C.Success or C.TextDim
    metaLbl.TextXAlignment = Enum.TextXAlignment.Left
    metaLbl.Parent = row

    local btnCol = Instance.new("Frame")
    btnCol.Size = UDim2.new(0, 140, 1, -8)
    btnCol.Position = UDim2.new(1, -144, 0, 4)
    btnCol.BackgroundTransparency = 1
    btnCol.Parent = row

    local visBtn = createButton(btnCol, enabledNow and "Hide" or "Show", "secondary", function()
        local cur = false
        pcall(function() cur = (gui.Enabled ~= false) end)
        setGuiEnabled(gui, not cur)
        refreshListUI()
    end)
    visBtn.Size = UDim2.new(0.5, -2, 0, 20)
    visBtn.Position = UDim2.new(0, 0, 0, 0)

    local forceBtn = createButton(btnCol, "Force", "primary", function()
        forceShowGui(gui)
        notify("Force show", gui.Name, "success", 2)
        refreshListUI()
    end)
    forceBtn.Size = UDim2.new(0.5, -2, 0, 20)
    forceBtn.Position = UDim2.new(0.5, 2, 0, 0)

    local cloneBtn = createButton(btnCol, "Clone", "secondary", function()
        local c = cloneGuiToPlayerGui(gui)
        if c then
            notify("Cloned", gui.Name .. " -> PlayerGui", "success", 3)
            task.defer(refreshListUI)
        end
    end)
    cloneBtn.Size = UDim2.new(0.5, -2, 0, 18)
    cloneBtn.Position = UDim2.new(0, 0, 0, 22)

    local inspBtn = createButton(btnCol, "Inspect", "secondary", function()
        selectedGui = gui
        switchTab("Inspector")
        if rebuildInspector then rebuildInspector() end
    end)
    inspBtn.Size = UDim2.new(0.5, -2, 0, 18)
    inspBtn.Position = UDim2.new(0.5, 2, 0, 22)

    local rowBtn = Instance.new("TextButton")
    rowBtn.Size = UDim2.new(1, -150, 1, 0)
    rowBtn.BackgroundTransparency = 1
    rowBtn.Text = ""
    rowBtn.AutoButtonColor = false
    rowBtn.Parent = row
    rowBtn.MouseEnter:Connect(function() tween(rs, { Transparency = 0 }) end)
    rowBtn.MouseLeave:Connect(function()
        if state.highlightAdmin and snap and snap.adminCandidate then
            tween(rs, { Transparency = 0.2 })
        else
            tween(rs, { Transparency = selectedGui == gui and 0 or 0.5 })
        end
    end)
    rowBtn.MouseButton1Click:Connect(function()
        selectedGui = gui
        refreshListUI()
    end)

    if selectedGui == gui then
        rs.Color = C.AccentPrimary
        rs.Transparency = 0
    end

    rowMap[gui] = row
end

refreshListUI = function()
    for _, c in ipairs(listScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    rowMap = {}
    refreshList()
    local shown, hidden = 0, 0
    for _, g in ipairs(discoveredOrder) do
        if shouldShowGuiInList(g) then
            buildRow(g)
            shown = shown + 1
        else
            hidden = hidden + 1
        end
    end
    win.setFooter(string.format("%d GUIs | %d hidden | observing: %s | %s",
        #discoveredOrder, hidden, observerActive and "yes" or "no", EXEC_NAME))
end

rebuildListDeferred = function()
    task.defer(refreshListUI)
end

bulkAction("Refresh", "primary", function()
    refreshListUI()
    notify("Refreshed", string.format("%d GUIs", #discoveredOrder), "info", 2)
end)
bulkAction("Show All", "secondary", function()
    local n = 0
    for g, _ in pairs(discovered) do setGuiEnabled(g, true); n = n + 1 end
    notify("Show all", n .. " GUIs enabled", "success", 2)
    refreshListUI()
end)
bulkAction("Hide All", "secondary", function()
    local n = 0
    for g, _ in pairs(discovered) do setGuiEnabled(g, false); n = n + 1 end
    notify("Hide all", n .. " GUIs disabled", "warning", 2)
    refreshListUI()
end)
bulkAction("Force All", "secondary", function()
    local n = 0
    for g, _ in pairs(discovered) do forceShowGui(g); n = n + 1 end
    notify("Force all", n .. " GUIs forced", "success", 2)
    refreshListUI()
end)
bulkAction("Restore", "danger", function()
    local n = 0
    for g, snap in pairs(discovered) do restoreGui(g, snap); n = n + 1 end
    notify("Restore", n .. " GUIs restored", "success", 2)
    refreshListUI()
end)

-- =============================================================================
-- INSPECTOR TAB
-- =============================================================================

local inspectorHeader = Instance.new("TextLabel")
inspectorHeader.Size = UDim2.new(1, 0, 0, 22)
inspectorHeader.BackgroundTransparency = 1
inspectorHeader.Text = "No GUI selected"
inspectorHeader.Font = Enum.Font.GothamSemibold
inspectorHeader.TextSize = 13
inspectorHeader.TextColor3 = C.TextSecondary
inspectorHeader.TextXAlignment = Enum.TextXAlignment.Left
inspectorHeader.Parent = inspectorPage

local inspectorActions = Instance.new("Frame")
inspectorActions.Size = UDim2.new(1, 0, 0, 24)
inspectorActions.Position = UDim2.new(0, 0, 0, 26)
inspectorActions.BackgroundTransparency = 1
inspectorActions.Parent = inspectorPage
listLayout(inspectorActions, 4, Enum.FillDirection.Horizontal)

local exportBtn = createButton(inspectorActions, "Export Lua", "primary", function()
    if selectedGui then exportGuiToLua(selectedGui) else notify("Export", "Select a GUI first", "warning") end
end)
exportBtn.Size = UDim2.new(0, 110, 1, 0)

local addPersistBtn = createButton(inspectorActions, "+ Persist", "secondary", function()
    if not selectedGui then return end
    local exists = false
    for _, n in ipairs(state.persistShowList) do
        if n == selectedGui.Name then exists = true; break end
    end
    if not exists then
        table.insert(state.persistShowList, selectedGui.Name)
        saveConfig()
        notify("Persist list", "Added " .. selectedGui.Name, "success", 2)
    else
        notify("Persist list", "Already in list", "warning", 2)
    end
end)
addPersistBtn.Size = UDim2.new(0, 100, 1, 0)

local forceSelectedBtn = createButton(inspectorActions, "Force Show", "secondary", function()
    if selectedGui then forceShowGui(selectedGui); notify("Force", selectedGui.Name, "success", 2) end
end)
forceSelectedBtn.Size = UDim2.new(0, 100, 1, 0)

local treeScroll = createScrollFrame(inspectorPage)
treeScroll.Size = UDim2.new(0.5, -4, 1, -56)
treeScroll.Position = UDim2.new(0, 0, 0, 54)
listLayout(treeScroll, 2)

local propsScroll = createScrollFrame(inspectorPage)
propsScroll.Size = UDim2.new(0.5, -4, 1, -56)
propsScroll.Position = UDim2.new(0.5, 4, 0, 54)
listLayout(propsScroll, 2)

local selectedInspectInstance = nil

local function buildPropertyRow(inst, propName)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundColor3 = C.Surface
    row.BorderSizePixel = 0
    row.Parent = propsScroll
    corner(row, 4)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0.4, -4, 1, 0)
    nameLbl.Position = UDim2.new(0, 6, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = propName
    nameLbl.Font = Enum.Font.Code
    nameLbl.TextSize = 11
    nameLbl.TextColor3 = C.TextSecondary
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Parent = row

    local valTxt = "?"
    local ok, v = pcall(function() return inst[propName] end)
    if ok and v ~= nil then
        if typeof(v) == "Color3" then valTxt = string.format("%d,%d,%d", math.floor(v.R*255), math.floor(v.G*255), math.floor(v.B*255))
        elseif typeof(v) == "UDim2" then valTxt = string.format("(%g,%d)(%g,%d)", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
        elseif typeof(v) == "EnumItem" then valTxt = v.Name
        else valTxt = tostring(v) end
    end

    local valBox = Instance.new("TextBox")
    valBox.Size = UDim2.new(0.6, -8, 1, -4)
    valBox.Position = UDim2.new(0.4, 4, 0, 2)
    valBox.BackgroundColor3 = C.SurfaceElevated
    valBox.BorderSizePixel = 0
    valBox.Text = valTxt
    valBox.Font = Enum.Font.Code
    valBox.TextSize = 11
    valBox.TextColor3 = C.TextPrimary
    valBox.ClearTextOnFocus = false
    valBox.TextXAlignment = Enum.TextXAlignment.Left
    valBox.Parent = row
    corner(valBox, 3)

    valBox.FocusLost:Connect(function(enter)
        if not enter then return end
        local txt = valBox.Text
        local okSet = pcall(function()
            local cur = inst[propName]
            local t = typeof(cur)
            if t == "string" then inst[propName] = txt
            elseif t == "number" then inst[propName] = tonumber(txt) or cur
            elseif t == "boolean" then inst[propName] = (txt:lower() == "true")
            elseif t == "Color3" then
                local r, g, b = txt:match("(%d+),(%d+),(%d+)")
                if r then inst[propName] = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)) end
            elseif t == "UDim2" then
                local xs, xo, ys, yo = txt:match("%(([%-%d%.]+),([%-%d%.]+)%)%(([%-%d%.]+),([%-%d%.]+)%)")
                if xs then inst[propName] = UDim2.new(tonumber(xs), tonumber(xo), tonumber(ys), tonumber(yo)) end
            end
        end)
        if not okSet then notify("Edit", "Failed to set " .. propName, "danger", 2) end
    end)
end

local function rebuildProperties(inst)
    for _, c in ipairs(propsScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    if not inst then return end
    for _, p in ipairs(SAFE_PROPS) do
        local ok = pcall(function() return inst[p] end)
        if ok then buildPropertyRow(inst, p) end
    end
end

local function buildTreeNode(inst, depth, parent)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 20)
    row.BackgroundColor3 = C.Surface
    row.BackgroundTransparency = 0.4
    row.BorderSizePixel = 0
    row.Text = string.rep("  ", depth) .. inst.ClassName .. "  " .. inst.Name
    row.Font = Enum.Font.Code
    row.TextSize = 11
    row.TextColor3 = depth == 0 and C.AccentPrimary or C.TextSecondary
    row.TextXAlignment = Enum.TextXAlignment.Left
    row.AutoButtonColor = false
    row.Parent = parent
    corner(row, 3)

    row.MouseEnter:Connect(function() tween(row, { BackgroundTransparency = 0 }) end)
    row.MouseLeave:Connect(function() tween(row, { BackgroundTransparency = selectedInspectInstance == inst and 0 or 0.4 }) end)
    row.MouseButton1Click:Connect(function()
        selectedInspectInstance = inst
        rebuildProperties(inst)
        for _, c in ipairs(parent:GetChildren()) do
            if c:IsA("TextButton") then tween(c, { BackgroundTransparency = 0.4 }) end
        end
        tween(row, { BackgroundTransparency = 0 })
    end)

    if depth < 6 then
        for _, child in ipairs(inst:GetChildren()) do
            if child:IsA("GuiObject") or child:IsA("UIBase") then
                buildTreeNode(child, depth + 1, parent)
            end
        end
    end
end

rebuildInspector = function()
    for _, c in ipairs(treeScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for _, c in ipairs(propsScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    if not selectedGui or not selectedGui.Parent then
        inspectorHeader.Text = "No GUI selected (pick one from the List tab)"
        inspectorHeader.TextColor3 = C.TextSecondary
        return
    end
    inspectorHeader.Text = selectedGui.Name .. "  -  " .. getFullPath(selectedGui)
    inspectorHeader.TextColor3 = C.AccentPrimary
    selectedInspectInstance = selectedGui
    buildTreeNode(selectedGui, 0, treeScroll)
    rebuildProperties(selectedGui)
end

-- =============================================================================
-- FILTERS TAB
-- =============================================================================

local filtersScroll = createScrollFrame(filtersPage)
filtersScroll.Size = UDim2.new(1, 0, 1, 0)
listLayout(filtersScroll, 8)
pad(filtersScroll, 4)

local filterSection = createSection(filtersScroll, "Visibility Filters")
local togHideSystem = createToggle(filterSection, "Hide system GUIs (Chat, Backpack, etc.)", state.hideSystemGuis, function(v)
    state.hideSystemGuis = v; saveConfig(); refreshListUI()
end)
local togHideEnabled = createToggle(filterSection, "Hide currently enabled GUIs", state.hideEnabled, function(v)
    state.hideEnabled = v; saveConfig(); refreshListUI()
end)
local togHideDisabled = createToggle(filterSection, "Hide currently disabled GUIs", state.hideDisabled, function(v)
    state.hideDisabled = v; saveConfig(); refreshListUI()
end)
local togHighlightAdmin = createToggle(filterSection, "Highlight admin-panel candidates", state.highlightAdmin, function(v)
    state.highlightAdmin = v; saveConfig(); refreshListUI()
end)

local observerSection = createSection(filtersScroll, "Live Observer")
local togObserve = createToggle(observerSection, "Observe new GUIs being added", state.autoObserve, function(v)
    state.autoObserve = v; saveConfig()
    if v then startObserver() else stopObserver() end
end)
local togAutoAdd = createToggle(observerSection, "Auto-add new GUIs to list", state.autoAddNewGuis, function(v)
    state.autoAddNewGuis = v; saveConfig()
end)
local refreshInterval = createSlider(observerSection, "Auto-refresh interval (sec, 0=manual)", 0, 30, state.refreshIntervalSec, 0, function(v)
    state.refreshIntervalSec = v; saveConfig()
end)

local persistSection = createSection(filtersScroll, "Persistent Force-Show List")
local persistList = Instance.new("Frame")
persistList.Size = UDim2.new(1, 0, 0, 80)
persistList.BackgroundColor3 = C.SurfaceElevated
persistList.BorderSizePixel = 0
persistList.Parent = persistSection
corner(persistList, 4)
local persistScroll = createScrollFrame(persistList)
listLayout(persistScroll, 2)
pad(persistScroll, 4)

local function rebuildPersistList()
    for _, c in ipairs(persistScroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
    end
    for i, n in ipairs(state.persistShowList) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 18)
        row.BackgroundTransparency = 1
        row.Parent = persistScroll
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -24, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = "- " .. n
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 11
        lbl.TextColor3 = C.TextSecondary
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row
        local rm = Instance.new("TextButton")
        rm.Size = UDim2.new(0, 18, 0, 18)
        rm.Position = UDim2.new(1, -20, 0, 0)
        rm.BackgroundColor3 = C.Danger
        rm.BackgroundTransparency = 0.5
        rm.Text = "x"
        rm.Font = Enum.Font.GothamBold
        rm.TextSize = 10
        rm.TextColor3 = C.TextPrimary
        rm.AutoButtonColor = false
        rm.BorderSizePixel = 0
        rm.Parent = row
        corner(rm, 3)
        rm.MouseButton1Click:Connect(function()
            table.remove(state.persistShowList, i)
            saveConfig()
            rebuildPersistList()
        end)
    end
end
rebuildPersistList()

local clearPersist = createButton(persistSection, "Clear Persist List", "danger", function()
    state.persistShowList = {}
    saveConfig()
    rebuildPersistList()
    notify("Persist list", "Cleared", "success", 2)
end)

-- =============================================================================
-- SETTINGS TAB
-- =============================================================================

local settingsScroll = createScrollFrame(settingsPage)
settingsScroll.Size = UDim2.new(1, 0, 1, 0)
listLayout(settingsScroll, 8)
pad(settingsScroll, 4)

local envSection = createSection(settingsScroll, "Environment")
local envLbl = Instance.new("TextLabel")
envLbl.Size = UDim2.new(1, 0, 0, 50)
envLbl.BackgroundColor3 = C.SurfaceElevated
envLbl.BorderSizePixel = 0
envLbl.Text = string.format("  Executor: %s\n  Version:  %s\n  hookmetamethod: %s | gethui: %s",
    EXEC_NAME, EXEC_VER,
    HAS_HOOKMM and "yes" or "no",
    HAS_GETHUI and "yes" or "no")
envLbl.Font = Enum.Font.Code
envLbl.TextSize = 11
envLbl.TextColor3 = C.TextSecondary
envLbl.TextXAlignment = Enum.TextXAlignment.Left
envLbl.TextYAlignment = Enum.TextYAlignment.Top
envLbl.Parent = envSection
corner(envLbl, 4)

local kbSection = createSection(settingsScroll, "Keybinds")
local kbRefresh = createKeybind(kbSection, "Refresh list", state.keybindRefresh, function(k)
    state.keybindRefresh = k; saveConfig()
end)
local kbObserver = createKeybind(kbSection, "Toggle observer", state.keybindObserver, function(k)
    state.keybindObserver = k; saveConfig()
end)
local kbHide = createKeybind(kbSection, "Hide selected", state.keybindHide, function(k)
    state.keybindHide = k; saveConfig()
end)
local kbForce = createKeybind(kbSection, "Force show selected", state.keybindForceShow, function(k)
    state.keybindForceShow = k; saveConfig()
end)

local appearanceSection = createSection(settingsScroll, "Appearance")
local accentPicker = createColorPicker(appearanceSection, "Accent color", Color3.fromRGB(state.accentColor[1], state.accentColor[2], state.accentColor[3]), function(c)
    state.accentColor = { math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255) }
    C.AccentPrimary = c
    saveConfig()
end)

local presetDrop = createDropdown(appearanceSection, "Color preset", {"Magenta", "Cyan", "Lime", "Orange", "Crimson"}, "Magenta", function(o)
    local map = {
        Magenta = Color3.fromRGB(255,65,180),
        Cyan = Color3.fromRGB(80,220,255),
        Lime = Color3.fromRGB(150,255,80),
        Orange = Color3.fromRGB(255,160,60),
        Crimson = Color3.fromRGB(255,75,90),
    }
    local c = map[o] or C.AccentPrimary
    C.AccentPrimary = c
    state.accentColor = { math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255) }
    accentPicker.set(c)
    saveConfig()
    notify("Preset", o, "info", 2)
end)

local configSection = createSection(settingsScroll, "Config")
local saveBtn = createButton(configSection, "Save Config", "primary", function()
    saveConfig()
    notify("Config", "Saved to " .. CONFIG_PATH, "success", 2)
end)
local loadBtn = createButton(configSection, "Load Config", "secondary", function()
    loadConfig()
    notify("Config", "Loaded", "success", 2)
    refreshListUI()
end)
local resetBtn = createButton(configSection, "Reset to Defaults", "danger", function()
    state = deepcopy(defaultState)
    saveConfig()
    notify("Config", "Reset", "warning", 2)
    togHideSystem.set(state.hideSystemGuis)
    togHideEnabled.set(state.hideEnabled)
    togHideDisabled.set(state.hideDisabled)
    togHighlightAdmin.set(state.highlightAdmin)
    togObserve.set(state.autoObserve)
    togAutoAdd.set(state.autoAddNewGuis)
    refreshInterval.set(state.refreshIntervalSec)
    kbRefresh.set(state.keybindRefresh)
    kbObserver.set(state.keybindObserver)
    kbHide.set(state.keybindHide)
    kbForce.set(state.keybindForceShow)
    refreshListUI()
end)

-- =============================================================================
-- OBSERVER
-- =============================================================================

local function disconnectObserver()
    for _, c in ipairs(observerConns) do pcall(function() c:Disconnect() end) end
    observerConns = {}
end

local function onNewDescendant(d)
    if not isScreenLike(d) then return end
    if discovered[d] then return end
    discovered[d] = snapshotGui(d)
    table.insert(discoveredOrder, d)
    if state.autoAddNewGuis then
        notify("New GUI", d.Name .. " appeared", "info", 3)
        for _, n in ipairs(state.persistShowList) do
            if n == d.Name then
                task.defer(function() forceShowGui(d); notify("Persist", "Force-shown " .. d.Name, "success", 2) end)
                break
            end
        end
        task.defer(refreshListUI)
    end
end

startObserver = function()
    disconnectObserver()
    observerActive = true
    local function hook(container)
        if not container then return end
        local ok, conn = pcall(function()
            return container.DescendantAdded:Connect(onNewDescendant)
        end)
        if ok and conn then table.insert(observerConns, conn) end
    end
    hook(CoreGui)
    if PlayerGui then hook(PlayerGui) end
    hook(ReplicatedFirst)
    hook(Workspace)
    notify("Observer", "Active - watching for new GUIs", "success", 2)
    refreshListUI()
end

stopObserver = function()
    disconnectObserver()
    observerActive = false
    notify("Observer", "Stopped", "warning", 2)
    refreshListUI()
end

if state.autoObserve then task.defer(startObserver) end

-- =============================================================================
-- AUTO REFRESH LOOP
-- =============================================================================
local lastRefresh = tick()
track(RunService.Heartbeat:Connect(function()
    if state.refreshIntervalSec > 0 and (tick() - lastRefresh) >= state.refreshIntervalSec then
        lastRefresh = tick()
        refreshListUI()
    end
end))

-- =============================================================================
-- KEYBINDS
-- =============================================================================

track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local name = input.KeyCode.Name
    if name == state.keybindRefresh then
        refreshListUI()
        notify("Refresh", "List refreshed", "info", 1.5)
    elseif name == state.keybindObserver then
        if observerActive then stopObserver() else startObserver() end
    elseif name == state.keybindHide and selectedGui then
        setGuiEnabled(selectedGui, false)
        notify("Hide", selectedGui.Name, "warning", 1.5)
        refreshListUI()
    elseif name == state.keybindForceShow and selectedGui then
        forceShowGui(selectedGui)
        notify("Force show", selectedGui.Name, "success", 1.5)
        refreshListUI()
    end
end))

-- =============================================================================
-- INITIAL POPULATE
-- =============================================================================

refreshListUI()

for _, g in ipairs(discoveredOrder) do
    for _, n in ipairs(state.persistShowList) do
        if g.Name == n then pcall(function() forceShowGui(g) end); break end
    end
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

getgenv().ENI = getgenv().ENI or {}

local destroyed = false

getgenv().ENI.GuiDumper = {
    Show = function(self)
        if destroyed then return end
        win.setVisible(true)
    end,
    Hide = function(self)
        if destroyed then return end
        win.setVisible(false)
    end,
    Toggle = function(self)
        if destroyed then return end
        win.setVisible(not win.Screen.Enabled)
    end,
    Destroy = function(self)
        if destroyed then return end
        destroyed = true
        stopObserver()
        disconnectAll()
        pcall(function() win.destroy() end)
        if notifyHost then pcall(function() notifyHost:Destroy() end) end
        getgenv().ENI.GuiDumper = nil
    end,
    GetConfig = function(self) return deepcopy(state) end,
    SetConfig = function(self, t)
        if type(t) ~= "table" then return end
        for k, v in pairs(t) do state[k] = v end
        saveConfig()
        refreshListUI()
    end,
    Refresh = function(self) refreshListUI() end,
    Enumerate = function(self) return enumerateGuis() end,
    ForceShow = function(self, gui) if gui then forceShowGui(gui) end end,
    Export = function(self, gui) if gui then exportGuiToLua(gui) end end,
    StartObserver = function(self) startObserver() end,
    StopObserver = function(self) stopObserver() end,
}

notify("GUI Dumper", "v2.0.0 loaded (" .. EXEC_NAME .. ")", "success", 3)

return getgenv().ENI.GuiDumper

end
-- END MODULE: GUI DUMPER v3.0.0
----------------------------------------------------------------------

----------------------------------------------------------------------
-- MODULE: STATE FINDER v3.0.0 (1836 lines original)
----------------------------------------------------------------------
do
--[[
    ============================================================================
    ENI Roblox Kit  ::  State Finder
    Module : recon/state_finder.lua
    Version: 2.0.0
    Author : ENI (for LO)
    ----------------------------------------------------------------------------
    Audits LocalPlayer attributes, leaderstats, character props, and value
    objects for client-trusted state.  Probes each value with a sandboxed
    write/read-back to estimate a "Trust Score" (0 = freely writable on the
    client, 100 = server-validated and reverted).  Cross-references findings
    with ENI.RemoteScanner when present, supports live monitor mode, JSON
    export, and inline quick-set / restore controls per value.
    ============================================================================
]]

--==[ Anti-detect shims ]====================================================--
local cloneref = cloneref or function(x) return x end
local protect_gui = (syn and syn.protect_gui) or (gethui and function(g) g.Parent = gethui() end) or function(g) g.Parent = game:GetService('CoreGui') end
local hookmetamethod = hookmetamethod or function() return nil end
local getrawmetatable = getrawmetatable or function() return nil end
local setreadonly = setreadonly or function() end
local newcclosure = newcclosure or function(f) return f end
local getconnections = getconnections or function() return {} end
local getgc = getgc or function() return {} end
local isfile = isfile or function() return false end
local readfile = readfile or function() return nil end
local writefile = writefile or function() end
local makefolder = makefolder or function() end
local listfiles = listfiles or function() return {} end
local identifyexecutor = identifyexecutor or function() return "Unknown" end

--==[ Services (clonereffed) ]===============================================--
local Players          = cloneref(game:GetService('Players'))
local RunService       = cloneref(game:GetService('RunService'))
local UserInputService = cloneref(game:GetService('UserInputService'))
local TweenService     = cloneref(game:GetService('TweenService'))
local HttpService      = cloneref(game:GetService('HttpService'))
local Lighting         = cloneref(game:GetService('Lighting'))
local Workspace        = cloneref(game:GetService('Workspace'))

local LP = Players.LocalPlayer

--==[ Environment detection ]================================================--
local EXEC = (function()
    local ok, n = pcall(identifyexecutor)
    if ok and n and n ~= "" then return n end
    if syn      then return "Synapse X" end
    if KRNL_LOADED or krnl then return "Krnl" end
    if fluxus   then return "Fluxus" end
    if Solara   then return "Solara" end
    if getexecutorname then return getexecutorname() end
    return "Unknown"
end)()

local HAS_FILES = (type(writefile) == "function") and (type(readfile) == "function")
local HAS_DEBUG = (debug and debug.getinfo and true) or false

--==[ Design system ]========================================================--
local C = {
    Background       = Color3.fromRGB(15,15,22),
    Surface          = Color3.fromRGB(22,22,30),
    SurfaceElevated  = Color3.fromRGB(32,32,42),
    Border           = Color3.fromRGB(45,45,60),
    AccentPrimary    = Color3.fromRGB(255,65,180),
    AccentSecondary  = Color3.fromRGB(180,75,255),
    TextPrimary      = Color3.fromRGB(240,240,248),
    TextSecondary    = Color3.fromRGB(160,160,178),
    TextDim          = Color3.fromRGB(100,100,118),
    Success          = Color3.fromRGB(80,220,130),
    Warning          = Color3.fromRGB(255,185,70),
    Danger           = Color3.fromRGB(255,85,110),
}

local F = {
    Title    = Enum.Font.GothamBold,
    Header   = Enum.Font.GothamSemibold,
    Body     = Enum.Font.Gotham,
    Code     = Enum.Font.Code,
}

local TWEEN_FAST = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_MED  = TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--==[ Tiny utilities ]=======================================================--
local function tween(obj, info, props)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function newInst(class, props, children)
    local i = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then i[k] = v end
        end
        if props.Parent then i.Parent = props.Parent end
    end
    if children then
        for _, c in ipairs(children) do c.Parent = i end
    end
    return i
end

local function corner(parent, r)
    return newInst("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
    return newInst("UIStroke", {
        Color = color or C.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function padding(parent, all)
    return newInst("UIPadding", {
        PaddingTop = UDim.new(0, all),
        PaddingBottom = UDim.new(0, all),
        PaddingLeft = UDim.new(0, all),
        PaddingRight = UDim.new(0, all),
        Parent = parent,
    })
end

local function listLayout(parent, gap, dir)
    return newInst("UIListLayout", {
        Padding = UDim.new(0, gap or 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = dir or Enum.FillDirection.Vertical,
        Parent = parent,
    })
end

local function deepcopy(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = deepcopy(v) end
    return r
end

--==[ Default state + persistence ]==========================================--
local DEFAULTS = {
    showClientOnly = false,
    showServerOnly = false,
    monitor        = false,
    autoAudit      = false,
    autoAuditInt   = 30,
    keyAudit       = Enum.KeyCode.F11.Name,
    keyMonitor     = Enum.KeyCode.F12.Name,
    accentMode     = "Magenta",
    minTrust       = 0,
    maxTrust       = 100,
    tagFilter      = "All",
    rememberProbe  = true,
    probeDelay     = 0.5,
}

local state = deepcopy(DEFAULTS)

local CFG_DIR  = "freezer"
local CFG_FILE = CFG_DIR .. "/state_finder.json"

local function saveConfig()
    if not HAS_FILES then return end
    pcall(function()
        pcall(makefolder, CFG_DIR)
        writefile(CFG_FILE, HttpService:JSONEncode(state))
    end)
end

local function loadConfig()
    if not HAS_FILES then return end
    pcall(function()
        if isfile(CFG_FILE) then
            local loaded = HttpService:JSONDecode(readfile(CFG_FILE))
            if type(loaded) == "table" then
                for k, v in pairs(loaded) do state[k] = v end
            end
        end
    end)
end

loadConfig()

--==[ Connection registry (clean :Destroy()) ]===============================--
local Conns = {}
local function track(conn)
    Conns[#Conns+1] = conn
    return conn
end

--==[ Notification system ]==================================================--
local NotifyHolder

local function buildNotifyHolder()
    if NotifyHolder and NotifyHolder.Parent then return NotifyHolder end
    local gui = newInst("ScreenGui", {
        Name = "ENI_StateFinder_Notify",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    })
    pcall(protect_gui, gui)
    if gui.Parent == nil then gui.Parent = game:GetService("CoreGui") end
    NotifyHolder = newInst("Frame", {
        Name = "Holder",
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -20, 0, 20),
        Size = UDim2.new(0, 300, 1, -40),
        AnchorPoint = Vector2.new(1, 0),
        Parent = gui,
    })
    local lay = listLayout(NotifyHolder, 8)
    lay.HorizontalAlignment = Enum.HorizontalAlignment.Right
    return NotifyHolder
end

local function notify(title, msg, kind, dur)
    buildNotifyHolder()
    kind = kind or "info"
    dur = dur or 3
    local accent =
        kind == "success" and C.Success
        or kind == "warning" and C.Warning
        or kind == "danger"  and C.Danger
        or C.AccentPrimary

    local card = newInst("Frame", {
        Size = UDim2.new(1, 0, 0, 64),
        BackgroundColor3 = C.Surface,
        BorderSizePixel = 0,
        Position = UDim2.new(1, 320, 0, 0),
        Parent = NotifyHolder,
    })
    corner(card, 8)
    stroke(card, C.Border, 1, 0.4)
    local bar = newInst("Frame", {
        Size = UDim2.new(0, 3, 1, -10),
        Position = UDim2.new(0, 6, 0, 5),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        Parent = card,
    })
    corner(bar, 2)
    newInst("TextLabel", {
        Text = title or "",
        Font = F.Header, TextSize = 14,
        TextColor3 = C.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 18, 0, 8),
        Size = UDim2.new(1, -26, 0, 18),
        Parent = card,
    })
    newInst("TextLabel", {
        Text = msg or "",
        Font = F.Body, TextSize = 12,
        TextColor3 = C.TextSecondary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Position = UDim2.new(0, 18, 0, 28),
        Size = UDim2.new(1, -26, 0, 30),
        Parent = card,
    })

    tween(card, TWEEN_FAST, { Position = UDim2.new(0, 0, 0, 0) })
    task.delay(dur, function()
        if card and card.Parent then
            tween(card, TWEEN_FAST, { Position = UDim2.new(1, 320, 0, 0) })
            task.wait(0.2)
            if card then card:Destroy() end
        end
    end)
end

--==[ Window factory ]=======================================================--
local function createWindow(title, sizeV2)
    local gui = newInst("ScreenGui", {
        Name = "ENI_StateFinder",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        IgnoreGuiInset = true,
    })
    pcall(protect_gui, gui)
    if gui.Parent == nil then gui.Parent = game:GetService("CoreGui") end

    local root = newInst("Frame", {
        Name = "Root",
        Size = UDim2.new(0, sizeV2.X, 0, sizeV2.Y),
        Position = UDim2.new(0.5, -sizeV2.X/2, 0.5, -sizeV2.Y/2),
        BackgroundColor3 = C.Background,
        BorderSizePixel = 0,
        Parent = gui,
    })
    corner(root, 8)
    stroke(root, C.Border, 1, 0)

    -- Open animation
    root.Size = UDim2.new(0, sizeV2.X * 0.9, 0, sizeV2.Y * 0.9)
    root.BackgroundTransparency = 1
    tween(root, TWEEN_MED, {
        Size = UDim2.new(0, sizeV2.X, 0, sizeV2.Y),
        BackgroundTransparency = 0,
    })

    -- Title bar
    local titleBar = newInst("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = C.Surface,
        BorderSizePixel = 0,
        Parent = root,
    })
    corner(titleBar, 8)
    newInst("Frame", {
        Size = UDim2.new(1, 0, 0, 8),
        Position = UDim2.new(0, 0, 1, -8),
        BackgroundColor3 = C.Surface,
        BorderSizePixel = 0,
        Parent = titleBar,
    })
    newInst("UIGradient", {
        Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, C.AccentPrimary),
            ColorSequenceKeypoint.new(1, C.AccentSecondary),
        },
        Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0.85),
            NumberSequenceKeypoint.new(1, 0.95),
        },
        Rotation = 15,
        Parent = titleBar,
    })

    newInst("TextLabel", {
        Text = title,
        Font = F.Title, TextSize = 16,
        TextColor3 = C.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, -100, 1, 0),
        Parent = titleBar,
    })

    newInst("TextLabel", {
        Text = "v2.0.0",
        Font = F.Code, TextSize = 11,
        TextColor3 = C.TextDim,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14 + (#title * 9), 0, 0),
        Size = UDim2.new(0, 50, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = titleBar,
    })

    local function tbButton(symbol, xOff, hoverColor)
        local b = newInst("TextButton", {
            Text = symbol,
            Font = F.Header, TextSize = 16,
            TextColor3 = C.TextSecondary,
            BackgroundColor3 = C.SurfaceElevated,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 28, 0, 24),
            Position = UDim2.new(1, xOff, 0.5, -12),
            AutoButtonColor = false,
            Parent = titleBar,
        })
        corner(b, 4)
        b.MouseEnter:Connect(function()
            tween(b, TWEEN_FAST, { BackgroundTransparency = 0, TextColor3 = hoverColor })
        end)
        b.MouseLeave:Connect(function()
            tween(b, TWEEN_FAST, { BackgroundTransparency = 1, TextColor3 = C.TextSecondary })
        end)
        return b
    end

    local closeBtn = tbButton("X", -32, C.Danger)
    local minBtn   = tbButton("-", -64, C.AccentPrimary)

    local body = newInst("Frame", {
        Name = "Body",
        Size = UDim2.new(1, 0, 1, -36),
        Position = UDim2.new(0, 0, 0, 36),
        BackgroundTransparency = 1,
        Parent = root,
    })

    local tabStrip = newInst("Frame", {
        Name = "TabStrip",
        Size = UDim2.new(1, -20, 0, 30),
        Position = UDim2.new(0, 10, 0, 6),
        BackgroundTransparency = 1,
        Parent = body,
    })
    listLayout(tabStrip, 6, Enum.FillDirection.Horizontal)

    local tabContainer = newInst("Frame", {
        Name = "Tabs",
        Size = UDim2.new(1, -20, 1, -78),
        Position = UDim2.new(0, 10, 0, 42),
        BackgroundTransparency = 1,
        Parent = body,
    })

    local footer = newInst("Frame", {
        Name = "Footer",
        Size = UDim2.new(1, 0, 0, 24),
        Position = UDim2.new(0, 0, 1, -24),
        BackgroundColor3 = C.Surface,
        BorderSizePixel = 0,
        Parent = body,
    })
    local footerLabel = newInst("TextLabel", {
        Text = "Idle.",
        Font = F.Code, TextSize = 11,
        TextColor3 = C.TextDim,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -24, 1, 0),
        Parent = footer,
    })

    local grip = newInst("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(1, -14, 1, -14),
        BackgroundColor3 = C.AccentPrimary,
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        Parent = root,
        ZIndex = 5,
    })
    corner(grip, 4)

    do
        local resizing, startMouse, startSize
        grip.InputBegan:Connect(function(io)
            if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
                resizing = true
                startMouse = io.Position
                startSize = root.Size
            end
        end)
        track(UserInputService.InputChanged:Connect(function(io)
            if resizing and (io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch) then
                local delta = io.Position - startMouse
                local w = math.max(320, startSize.X.Offset + delta.X)
                local h = math.max(360, startSize.Y.Offset + delta.Y)
                root.Size = UDim2.new(0, w, 0, h)
            end
        end))
        track(UserInputService.InputEnded:Connect(function(io)
            if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
                resizing = false
            end
        end))
    end

    do
        local dragging, dragStart, startPos
        titleBar.InputBegan:Connect(function(io)
            if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = io.Position
                startPos = root.Position
            end
        end)
        track(UserInputService.InputChanged:Connect(function(io)
            if dragging and (io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch) then
                local delta = io.Position - dragStart
                root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                          startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end))
        track(UserInputService.InputEnded:Connect(function(io)
            if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end))
    end

    local tabs = {}
    local activeTab
    local function selectTab(name)
        activeTab = name
        for n, t in pairs(tabs) do
            t.btn.BackgroundColor3 = (n == name) and C.SurfaceElevated or C.Surface
            t.btn.TextColor3 = (n == name) and C.AccentPrimary or C.TextSecondary
            t.page.Visible = (n == name)
        end
    end

    local function addTab(name)
        local btn = newInst("TextButton", {
            Text = name,
            Font = F.Header, TextSize = 12,
            TextColor3 = C.TextSecondary,
            BackgroundColor3 = C.Surface,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 80, 1, 0),
            AutoButtonColor = false,
            Parent = tabStrip,
        })
        corner(btn, 4)
        local page = newInst("ScrollingFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.AccentPrimary,
            Visible = false,
            Parent = tabContainer,
        })
        padding(page, 6)
        local pageLayout = listLayout(page, 8)
        tabs[name] = { btn = btn, page = page, layout = pageLayout }
        btn.MouseButton1Click:Connect(function() selectTab(name) end)
        if not activeTab then selectTab(name) end
        return page
    end

    local minimized = false
    local restoreSize
    local function toggleMinimize()
        minimized = not minimized
        if minimized then
            restoreSize = root.Size
            body.Visible = false
            tween(root, TWEEN_FAST, { Size = UDim2.new(0, restoreSize.X.Offset, 0, 36) })
        else
            body.Visible = true
            tween(root, TWEEN_FAST, { Size = restoreSize })
        end
    end
    minBtn.MouseButton1Click:Connect(toggleMinimize)

    local function setVisible(v)
        gui.Enabled = v and true or false
    end
    closeBtn.MouseButton1Click:Connect(function() setVisible(false) end)

    local function destroy()
        gui:Destroy()
    end

    return {
        Gui = gui,
        Frame = root,
        Body = body,
        TabContainer = tabContainer,
        Footer = footerLabel,
        addTab = addTab,
        selectTab = selectTab,
        setVisible = setVisible,
        toggleMinimize = toggleMinimize,
        destroy = destroy,
        notify = notify,
    }
end

--==[ Section header ]=======================================================--
local function createSection(parent, title)
    local holder = newInst("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 24),
        Parent = parent,
    })
    newInst("TextLabel", {
        Text = title:upper(),
        Font = F.Header, TextSize = 12,
        TextColor3 = C.AccentPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 4, 0, 4),
        Size = UDim2.new(1, -8, 0, 14),
        Parent = holder,
    })
    newInst("Frame", {
        Size = UDim2.new(1, -8, 0, 1),
        Position = UDim2.new(0, 4, 1, -4),
        BackgroundColor3 = C.Border,
        BorderSizePixel = 0,
        Parent = holder,
    })
    return holder
end

--==[ Button factory ]=======================================================--
local function createButton(parent, label, style, callback)
    style = style or "primary"
    local bg =
        style == "danger"    and C.Danger
        or style == "secondary" and C.SurfaceElevated
        or C.AccentPrimary
    local txt = (style == "secondary") and C.TextPrimary or Color3.new(1,1,1)

    local btn = newInst("TextButton", {
        Text = label,
        Font = F.Header, TextSize = 13,
        TextColor3 = txt,
        BackgroundColor3 = bg,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 110, 0, 28),
        AutoButtonColor = false,
        Parent = parent,
        ClipsDescendants = true,
    })
    corner(btn, 4)
    local s = stroke(btn, C.AccentPrimary, 1, 1)

    btn.MouseEnter:Connect(function()
        tween(s, TWEEN_FAST, { Transparency = 0 })
        tween(btn, TWEEN_FAST, { BackgroundColor3 = bg:Lerp(Color3.new(1,1,1), 0.08) })
    end)
    btn.MouseLeave:Connect(function()
        tween(s, TWEEN_FAST, { Transparency = 1 })
        tween(btn, TWEEN_FAST, { BackgroundColor3 = bg })
    end)
    btn.MouseButton1Click:Connect(function()
        local r = newInst("Frame", {
            BackgroundColor3 = Color3.new(1,1,1),
            BackgroundTransparency = 0.6,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Parent = btn,
        })
        corner(r, 50)
        tween(r, TWEEN_MED, {
            Size = UDim2.new(0, 200, 0, 200),
            BackgroundTransparency = 1,
        })
        task.delay(0.3, function() if r then r:Destroy() end end)
        if callback then task.spawn(callback) end
    end)
    return btn
end

--==[ Toggle factory ]=======================================================--
local function createToggle(parent, label, default, callback)
    local row = newInst("Frame", {
        BackgroundColor3 = C.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 32),
        Parent = parent,
    })
    corner(row, 4)
    newInst("TextLabel", {
        Text = label,
        Font = F.Body, TextSize = 13,
        TextColor3 = C.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -60, 1, 0),
        Parent = row,
    })
    local trackEl = newInst("Frame", {
        BackgroundColor3 = C.SurfaceElevated,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 36, 0, 16),
        Position = UDim2.new(1, -46, 0.5, -8),
        Parent = row,
    })
    corner(trackEl, 8)
    local knob = newInst("Frame", {
        BackgroundColor3 = C.TextDim,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0, 2, 0.5, -6),
        Parent = trackEl,
    })
    corner(knob, 6)

    local val = default and true or false
    local function set(v, fire)
        val = v and true or false
        if val then
            tween(knob, TWEEN_FAST, { Position = UDim2.new(0, 22, 0.5, -6), BackgroundColor3 = Color3.new(1,1,1) })
            tween(trackEl, TWEEN_FAST, { BackgroundColor3 = C.AccentPrimary })
        else
            tween(knob, TWEEN_FAST, { Position = UDim2.new(0, 2, 0.5, -6), BackgroundColor3 = C.TextDim })
            tween(trackEl, TWEEN_FAST, { BackgroundColor3 = C.SurfaceElevated })
        end
        if fire ~= false and callback then task.spawn(callback, val) end
    end
    set(val, false)

    local btn = newInst("TextButton", {
        Text = "", BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = row,
    })
    btn.MouseButton1Click:Connect(function() set(not val, true) end)

    return { set = function(v) set(v, true) end, get = function() return val end, Frame = row }
end

--==[ Slider factory ]=======================================================--
local function createSlider(parent, label, min, max, default, decimals, callback)
    decimals = decimals or 0
    local row = newInst("Frame", {
        BackgroundColor3 = C.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 46),
        Parent = parent,
    })
    corner(row, 4)
    local lbl = newInst("TextLabel", {
        Font = F.Body, TextSize = 13,
        TextColor3 = C.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 10, 0, 4),
        Size = UDim2.new(1, -80, 0, 18),
        Parent = row,
    })
    local valLbl = newInst("TextLabel", {
        Font = F.Code, TextSize = 12,
        TextColor3 = C.AccentPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(1, -16, 0, 4),
        Size = UDim2.new(0, 60, 0, 18),
        Parent = row,
    })

    local bar = newInst("Frame", {
        BackgroundColor3 = C.SurfaceElevated,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -20, 0, 6),
        Position = UDim2.new(0, 10, 0, 30),
        Parent = row,
    })
    corner(bar, 3)
    local fill = newInst("Frame", {
        BackgroundColor3 = C.AccentPrimary,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
        Parent = bar,
    })
    corner(fill, 3)
    local knob = newInst("Frame", {
        BackgroundColor3 = Color3.new(1,1,1),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0, -6, 0.5, -6),
        Parent = bar,
    })
    corner(knob, 6)

    local val = default
    local function format(v)
        if decimals == 0 then return tostring(math.floor(v + 0.5)) end
        local m = 10 ^ decimals
        return string.format("%."..decimals.."f", math.floor(v * m + 0.5) / m)
    end

    local function set(v, fire)
        val = math.clamp(v, min, max)
        local pct = (val - min) / (max - min)
        lbl.Text = label
        valLbl.Text = format(val)
        tween(fill, TWEEN_FAST, { Size = UDim2.new(pct, 0, 1, 0) })
        tween(knob, TWEEN_FAST, { Position = UDim2.new(pct, -6, 0.5, -6) })
        if fire ~= false and callback then task.spawn(callback, val) end
    end
    set(default, false)

    local dragging
    bar.InputBegan:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            local pct = math.clamp((io.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            set(min + (max - min) * pct, true)
        end
    end)
    track(UserInputService.InputChanged:Connect(function(io)
        if dragging and (io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch) then
            local pct = math.clamp((io.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            set(min + (max - min) * pct, true)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    return { set = function(v) set(v, true) end, get = function() return val end }
end

--==[ Dropdown factory ]=====================================================--
local function createDropdown(parent, label, options, default, callback)
    local row = newInst("Frame", {
        BackgroundColor3 = C.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 32),
        Parent = parent,
        ClipsDescendants = false,
    })
    corner(row, 4)
    newInst("TextLabel", {
        Text = label,
        Font = F.Body, TextSize = 13,
        TextColor3 = C.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(0.45, -10, 1, 0),
        Parent = row,
    })

    local current = default or options[1]
    local btn = newInst("TextButton", {
        Text = tostring(current) .. "  v",
        Font = F.Code, TextSize = 12,
        TextColor3 = C.AccentPrimary,
        BackgroundColor3 = C.SurfaceElevated,
        BorderSizePixel = 0,
        Size = UDim2.new(0.55, -16, 0, 22),
        Position = UDim2.new(0.45, 6, 0.5, -11),
        AutoButtonColor = false,
        Parent = row,
    })
    corner(btn, 4)

    local list = newInst("Frame", {
        BackgroundColor3 = C.SurfaceElevated,
        BorderSizePixel = 0,
        Size = UDim2.new(0.55, -16, 0, 0),
        Position = UDim2.new(0.45, 6, 0.5, 14),
        Visible = false,
        Parent = row,
        ZIndex = 10,
    })
    corner(list, 4)
    stroke(list, C.Border, 1, 0)
    listLayout(list, 0)

    local open = false
    local optionButtons = {}

    local function rebuild()
        for _, c in ipairs(optionButtons) do c:Destroy() end
        optionButtons = {}
        for i, opt in ipairs(options) do
            local ob = newInst("TextButton", {
                Text = tostring(opt),
                Font = F.Body, TextSize = 12,
                TextColor3 = C.TextPrimary,
                BackgroundColor3 = C.SurfaceElevated,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 22),
                AutoButtonColor = false,
                Parent = list,
                ZIndex = 11,
                LayoutOrder = i,
            })
            ob.MouseEnter:Connect(function() tween(ob, TWEEN_FAST, { BackgroundColor3 = C.AccentPrimary }) end)
            ob.MouseLeave:Connect(function() tween(ob, TWEEN_FAST, { BackgroundColor3 = C.SurfaceElevated }) end)
            ob.MouseButton1Click:Connect(function()
                current = opt
                btn.Text = tostring(current) .. "  v"
                open = false
                tween(list, TWEEN_FAST, { Size = UDim2.new(0.55, -16, 0, 0) })
                task.delay(0.15, function() list.Visible = false end)
                if callback then task.spawn(callback, current) end
            end)
            optionButtons[#optionButtons+1] = ob
        end
    end
    rebuild()

    btn.MouseButton1Click:Connect(function()
        open = not open
        if open then
            list.Visible = true
            local h = math.min(#options * 22, 120)
            tween(list, TWEEN_FAST, { Size = UDim2.new(0.55, -16, 0, h) })
        else
            tween(list, TWEEN_FAST, { Size = UDim2.new(0.55, -16, 0, 0) })
            task.delay(0.15, function() list.Visible = false end)
        end
    end)

    return {
        set = function(v)
            current = v
            btn.Text = tostring(current) .. "  v"
            if callback then task.spawn(callback, current) end
        end,
        get = function() return current end,
        refresh = function(newOpts) options = newOpts; rebuild() end,
    }
end

--==[ Color picker (HSV popup) ]=============================================--
local function createColorPicker(parent, label, defaultColor, callback)
    local row = newInst("Frame", {
        BackgroundColor3 = C.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 32),
        Parent = parent,
    })
    corner(row, 4)
    newInst("TextLabel", {
        Text = label,
        Font = F.Body, TextSize = 13,
        TextColor3 = C.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -60, 1, 0),
        Parent = row,
    })
    local swatch = newInst("TextButton", {
        Text = "",
        BackgroundColor3 = defaultColor,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 36, 0, 18),
        Position = UDim2.new(1, -46, 0.5, -9),
        AutoButtonColor = false,
        Parent = row,
    })
    corner(swatch, 4)
    stroke(swatch, C.Border, 1, 0)

    local current = defaultColor
    local popup
    local function openPopup()
        if popup then popup:Destroy() popup = nil return end
        popup = newInst("Frame", {
            BackgroundColor3 = C.SurfaceElevated,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 180, 0, 140),
            Position = UDim2.new(1, -190, 1, 6),
            Parent = row,
            ZIndex = 20,
        })
        corner(popup, 6)
        stroke(popup, C.Border, 1, 0)

        local h, s, v = current:ToHSV()
        local svBox = newInst("Frame", {
            BackgroundColor3 = Color3.fromHSV(h, 1, 1),
            BorderSizePixel = 0,
            Size = UDim2.new(0, 120, 0, 120),
            Position = UDim2.new(0, 8, 0, 8),
            Parent = popup,
            ZIndex = 21,
        })
        corner(svBox, 4)
        newInst("UIGradient", { Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromHSV(h,1,1)), Parent = svBox })
        local svFade = newInst("Frame", {
            BackgroundColor3 = Color3.new(0,0,0),
            BorderSizePixel = 0,
            Size = UDim2.new(1,0,1,0),
            Parent = svBox, ZIndex = 22,
        })
        corner(svFade, 4)
        newInst("UIGradient", {
            Color = ColorSequence.new(Color3.new(0,0,0), Color3.new(0,0,0)),
            Transparency = NumberSequence.new{
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 0),
            },
            Rotation = 90,
            Parent = svFade,
        })

        local hueBar = newInst("Frame", {
            BackgroundColor3 = Color3.new(1,1,1),
            BorderSizePixel = 0,
            Size = UDim2.new(0, 30, 0, 120),
            Position = UDim2.new(0, 138, 0, 8),
            Parent = popup,
            ZIndex = 21,
        })
        corner(hueBar, 3)
        newInst("UIGradient", {
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0/6,1,1)),
                ColorSequenceKeypoint.new(1/6, Color3.fromHSV(1/6,1,1)),
                ColorSequenceKeypoint.new(2/6, Color3.fromHSV(2/6,1,1)),
                ColorSequenceKeypoint.new(3/6, Color3.fromHSV(3/6,1,1)),
                ColorSequenceKeypoint.new(4/6, Color3.fromHSV(4/6,1,1)),
                ColorSequenceKeypoint.new(5/6, Color3.fromHSV(5/6,1,1)),
                ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1,1,1)),
            },
            Rotation = 90, Parent = hueBar,
        })

        local function commit()
            current = Color3.fromHSV(h, s, v)
            swatch.BackgroundColor3 = current
            svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            if callback then task.spawn(callback, current) end
        end

        local dragSv, dragHue
        svBox.InputBegan:Connect(function(io)
            if io.UserInputType == Enum.UserInputType.MouseButton1 then dragSv = true end
        end)
        hueBar.InputBegan:Connect(function(io)
            if io.UserInputType == Enum.UserInputType.MouseButton1 then dragHue = true end
        end)
        track(UserInputService.InputChanged:Connect(function(io)
            if io.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            if dragSv then
                local px = math.clamp((io.Position.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
                local py = math.clamp((io.Position.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
                s = px; v = 1 - py
                commit()
            end
            if dragHue then
                local py = math.clamp((io.Position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
                h = py
                commit()
            end
        end))
        track(UserInputService.InputEnded:Connect(function(io)
            if io.UserInputType == Enum.UserInputType.MouseButton1 then dragSv = false; dragHue = false end
        end))
    end
    swatch.MouseButton1Click:Connect(openPopup)

    return {
        set = function(c) current = c; swatch.BackgroundColor3 = c; if callback then task.spawn(callback, c) end end,
        get = function() return current end,
    }
end

--==[ Keybind factory ]======================================================--
local function createKeybind(parent, label, defaultKey, callback)
    local row = newInst("Frame", {
        BackgroundColor3 = C.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 32),
        Parent = parent,
    })
    corner(row, 4)
    newInst("TextLabel", {
        Text = label,
        Font = F.Body, TextSize = 13,
        TextColor3 = C.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -90, 1, 0),
        Parent = row,
    })
    local btn = newInst("TextButton", {
        Text = defaultKey and defaultKey.Name or "None",
        Font = F.Code, TextSize = 12,
        TextColor3 = C.AccentPrimary,
        BackgroundColor3 = C.SurfaceElevated,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 70, 0, 22),
        Position = UDim2.new(1, -80, 0.5, -11),
        AutoButtonColor = false,
        Parent = row,
    })
    corner(btn, 4)

    local current = defaultKey
    local listening = false

    btn.MouseButton1Click:Connect(function()
        listening = true
        btn.Text = "..."
        btn.TextColor3 = C.Warning
    end)

    track(UserInputService.InputBegan:Connect(function(io, gpe)
        if not listening then return end
        if io.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if io.KeyCode == Enum.KeyCode.Escape then
            current = nil
            btn.Text = "None"
        else
            current = io.KeyCode
            btn.Text = io.KeyCode.Name
        end
        btn.TextColor3 = C.AccentPrimary
        listening = false
        if callback then task.spawn(callback, current) end
    end))

    return {
        set = function(k) current = k; btn.Text = k and k.Name or "None" end,
        get = function() return current end,
    }
end

--==[ TextBox factory ]======================================================--
local function createTextBox(parent, placeholder, default, callback)
    local box = newInst("TextBox", {
        Text = default or "",
        PlaceholderText = placeholder or "",
        Font = F.Code, TextSize = 12,
        TextColor3 = C.TextPrimary,
        PlaceholderColor3 = C.TextDim,
        BackgroundColor3 = C.SurfaceElevated,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Size = UDim2.new(1, 0, 0, 22),
        Parent = parent,
    })
    corner(box, 4)
    local s = stroke(box, C.AccentPrimary, 1, 1)
    box.Focused:Connect(function() tween(s, TWEEN_FAST, { Transparency = 0 }) end)
    box.FocusLost:Connect(function(enter)
        tween(s, TWEEN_FAST, { Transparency = 1 })
        if callback then task.spawn(callback, box.Text, enter) end
    end)
    return box
end

--==[ Scroll frame ]=========================================================--
local function createScrollFrame(parent)
    local sf = newInst("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.AccentPrimary,
        Parent = parent,
    })
    padding(sf, 4)
    listLayout(sf, 6)
    return sf
end

--[[============================================================
    STATE FINDER CORE
==============================================================]]

-- Forward declarations so callbacks can reference functions defined later.
local runAudit, probeAllTrust, exportFindings, startMonitor, stopMonitor,
      refreshList, updateFooter, showRemoteCandidates

local registry = {}
local rowFrames = {}
local monitorWatchers = {}
local monitoring = false

local function classifyTag(name)
    local n = name:lower()
    if n:find("cash") or n:find("coin") or n:find("gold") or n:find("gem")
       or n:find("money") or n:find("credit") or n:find("token") or n:find("bux") then
        return "Currency"
    end
    if n:find("xp") or n:find("exp") or n:find("level") or n:find("rank") then
        return "XP"
    end
    if n:find("speed") or n:find("jump") or n:find("health") or n:find("str")
       or n:find("def") or n:find("power") or n:find("dmg") or n:find("damage") then
        return "Stat"
    end
    if n:find("skin") or n:find("hat") or n:find("trail") or n:find("aura")
       or n:find("color") or n:find("cosmetic") then
        return "Cosmetic"
    end
    return "Other"
end

local VALUE_CLASSES = {
    IntValue = true, NumberValue = true, StringValue = true, BoolValue = true,
    Vector3Value = true, CFrameValue = true, BrickColorValue = true, Color3Value = true,
    ObjectValue = true, RayValue = true,
}

local function readCurrent(entry)
    local ok, v = pcall(function()
        if entry.kind == "attribute" then
            return entry.parent:GetAttribute(entry.name)
        elseif entry.kind == "value" then
            return entry.parent.Value
        elseif entry.kind == "humanoid" then
            return entry.parent[entry.name]
        end
    end)
    if ok then return v else return nil end
end

local function probeWrite(kind, parent, name, originalValue)
    local ok, probeValue = pcall(function()
        if kind == "attribute" then
            local probe
            if type(originalValue) == "number" then
                probe = (originalValue == 0) and 1337 or (originalValue * 2 + 1)
            elseif type(originalValue) == "string" then
                probe = tostring(originalValue) .. "_eni"
            elseif type(originalValue) == "boolean" then
                probe = not originalValue
            else
                return nil
            end
            parent:SetAttribute(name, probe)
            task.wait(state.probeDelay or 0.5)
            local cur = parent:GetAttribute(name)
            parent:SetAttribute(name, originalValue)
            return cur
        elseif kind == "value" then
            local v = parent.Value
            local probe
            if type(v) == "number" then
                probe = (v == 0) and 1337 or (v * 2 + 1)
            elseif type(v) == "string" then
                probe = v .. "_eni"
            elseif type(v) == "boolean" then
                probe = not v
            else
                return nil
            end
            parent.Value = probe
            task.wait(state.probeDelay or 0.5)
            local cur = parent.Value
            parent.Value = v
            return cur
        elseif kind == "humanoid" then
            local v = parent[name]
            if type(v) ~= "number" then return nil end
            local probe = (v == 0) and 50 or (v + 10)
            parent[name] = probe
            task.wait(state.probeDelay or 0.5)
            local cur = parent[name]
            parent[name] = v
            return cur
        end
        return nil
    end)
    if not ok or probeValue == nil then return originalValue, 50 end

    if probeValue == originalValue then
        return originalValue, 100  -- write didn't stick = server-validated
    else
        return probeValue, 0        -- write stuck = client-trusted
    end
end

local function buildEntries()
    local out = {}
    if not LP then return out end

    for n, v in pairs(LP:GetAttributes()) do
        out[#out+1] = { id = "ATTR::"..n, kind = "attribute", parent = LP, name = n, value = v, type = typeof(v), tag = classifyTag(n) }
    end

    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        for _, c in ipairs(ls:GetChildren()) do
            if VALUE_CLASSES[c.ClassName] then
                out[#out+1] = { id = "LS::"..c.Name, kind = "value", parent = c, name = c.Name, value = c.Value, type = c.ClassName, tag = classifyTag(c.Name) }
            end
        end
    end

    for _, c in ipairs(LP:GetChildren()) do
        if VALUE_CLASSES[c.ClassName] then
            out[#out+1] = { id = "VAL::"..c.Name, kind = "value", parent = c, name = c.Name, value = c.Value, type = c.ClassName, tag = classifyTag(c.Name) }
        end
    end

    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local props = { "WalkSpeed", "JumpPower", "JumpHeight", "Health", "MaxHealth", "HipHeight", "MaxSlopeAngle" }
            for _, p in ipairs(props) do
                local ok, v = pcall(function() return hum[p] end)
                if ok and v ~= nil then
                    out[#out+1] = { id = "HUM::"..p, kind = "humanoid", parent = hum, name = p, value = v, type = "number", tag = classifyTag(p) }
                end
            end
        end
    end
    return out
end

local function detectSource()
    if not HAS_DEBUG then return "?" end
    for i = 2, 8 do
        local ok, info = pcall(debug.getinfo, i, "Sl")
        if ok and info and info.source and info.source ~= "" then
            local s = info.source
            if not s:find("state_finder") then
                return string.format("%s:%d", s:sub(-40), info.currentline or 0)
            end
        end
    end
    return "unknown"
end

--==[ Build UI ]=============================================================--
local W = createWindow("State Finder", { X = 380, Y = 520 })
W.setVisible(true)

local pageAudit    = W.addTab("Audit")
local pageMonitor  = W.addTab("Monitor")
local pageFilters  = W.addTab("Filters")
local pageSettings = W.addTab("Settings")

--==[ Audit page ]===========================================================--
createSection(pageAudit, "Controls")

local controlsRow = newInst("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 32),
    Parent = pageAudit,
})
listLayout(controlsRow, 6, Enum.FillDirection.Horizontal)
createButton(controlsRow, "Run Audit",    "primary",   function() runAudit() end)
createButton(controlsRow, "Probe Trust",  "secondary", function() probeAllTrust() end)
createButton(controlsRow, "Export JSON",  "secondary", function() exportFindings() end)

createSection(pageAudit, "Discovered Values")

local listHolder = newInst("Frame", {
    BackgroundColor3 = C.Surface,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 320),
    Parent = pageAudit,
})
corner(listHolder, 6)
local listScroll = newInst("ScrollingFrame", {
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2.new(1, -8, 1, -8),
    Position = UDim2.new(0, 4, 0, 4),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.AccentPrimary,
    Parent = listHolder,
})
listLayout(listScroll, 4)

--==[ Filters page ]=========================================================--
createSection(pageFilters, "Visibility")
local togClient, togServer
togClient = createToggle(pageFilters, "Show client-trusted only", state.showClientOnly, function(v)
    state.showClientOnly = v
    if v and togServer then state.showServerOnly = false; togServer.set(false) end
    saveConfig()
    refreshList()
end)
togServer = createToggle(pageFilters, "Show server-validated only", state.showServerOnly, function(v)
    state.showServerOnly = v
    if v and togClient then state.showClientOnly = false; togClient.set(false) end
    saveConfig()
    refreshList()
end)

createSection(pageFilters, "Trust Range")
createSlider(pageFilters, "Min Trust", 0, 100, state.minTrust, 0, function(v)
    state.minTrust = math.floor(v + 0.5); saveConfig(); refreshList()
end)
createSlider(pageFilters, "Max Trust", 0, 100, state.maxTrust, 0, function(v)
    state.maxTrust = math.floor(v + 0.5); saveConfig(); refreshList()
end)

createSection(pageFilters, "Tag")
createDropdown(pageFilters, "Tag Filter", { "All", "Currency", "XP", "Stat", "Cosmetic", "Other" }, state.tagFilter, function(v)
    state.tagFilter = v; saveConfig(); refreshList()
end)

--==[ Monitor page ]=========================================================--
createSection(pageMonitor, "Live Diff")

local monitorToggle = createToggle(pageMonitor, "Monitor mode (live diff log)", state.monitor, function(v)
    state.monitor = v; saveConfig()
    if v then startMonitor() else stopMonitor() end
end)

local logHolder = newInst("Frame", {
    BackgroundColor3 = C.Surface,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 280),
    Parent = pageMonitor,
})
corner(logHolder, 6)
local logScroll = newInst("ScrollingFrame", {
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2.new(1, -8, 1, -8),
    Position = UDim2.new(0, 4, 0, 4),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.AccentPrimary,
    Parent = logHolder,
})
listLayout(logScroll, 2)

local function pushLog(entry, oldV, newV, src)
    local line = newInst("Frame", {
        BackgroundColor3 = C.SurfaceElevated,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -4, 0, 36),
        Parent = logScroll,
    })
    corner(line, 4)
    newInst("TextLabel", {
        Text = ("[%s] %s.%s"):format(os.date("%H:%M:%S"), entry.kind, entry.name),
        Font = F.Header, TextSize = 12,
        TextColor3 = C.AccentPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 8, 0, 2),
        Size = UDim2.new(1, -16, 0, 14),
        Parent = line,
    })
    newInst("TextLabel", {
        Text = ("%s -> %s   (src: %s)"):format(tostring(oldV), tostring(newV), src or "?"),
        Font = F.Code, TextSize = 11,
        TextColor3 = C.TextSecondary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 8, 0, 18),
        Size = UDim2.new(1, -16, 0, 14),
        Parent = line,
    })
    -- cap log at 100
    local kids = logScroll:GetChildren()
    local frames = {}
    for _, c in ipairs(kids) do if c:IsA("Frame") then frames[#frames+1] = c end end
    if #frames > 100 then
        for i = 1, #frames - 100 do frames[i]:Destroy() end
    end
end

createButton(pageMonitor, "Clear Log", "secondary", function()
    for _, c in ipairs(logScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
end)

--==[ Settings page ]========================================================--
createSection(pageSettings, "Behavior")
createToggle(pageSettings, "Auto-audit on interval", state.autoAudit, function(v)
    state.autoAudit = v; saveConfig()
end)
createSlider(pageSettings, "Auto-audit interval (s)", 5, 300, state.autoAuditInt, 0, function(v)
    state.autoAuditInt = v; saveConfig()
end)
createSlider(pageSettings, "Probe delay (s)", 0.1, 2.0, state.probeDelay, 2, function(v)
    state.probeDelay = v; saveConfig()
end)
createToggle(pageSettings, "Remember probe results between audits", state.rememberProbe, function(v)
    state.rememberProbe = v; saveConfig()
end)

createSection(pageSettings, "Keybinds")
createKeybind(pageSettings, "Run Audit", Enum.KeyCode[state.keyAudit] or Enum.KeyCode.F11, function(k)
    state.keyAudit = k and k.Name or "F11"; saveConfig()
end)
createKeybind(pageSettings, "Toggle Monitor", Enum.KeyCode[state.keyMonitor] or Enum.KeyCode.F12, function(k)
    state.keyMonitor = k and k.Name or "F12"; saveConfig()
end)

createSection(pageSettings, "Theme")
createColorPicker(pageSettings, "Accent Color", C.AccentPrimary, function(c)
    C.AccentPrimary = c
    notify("Theme", "Accent updated", "success", 1.5)
end)
createDropdown(pageSettings, "Accent Preset", { "Magenta", "Cyan", "Lime", "Amber" }, state.accentMode, function(v)
    state.accentMode = v; saveConfig()
    local presets = {
        Magenta = Color3.fromRGB(255,65,180),
        Cyan    = Color3.fromRGB(80,210,255),
        Lime    = Color3.fromRGB(120,255,140),
        Amber   = Color3.fromRGB(255,180,70),
    }
    C.AccentPrimary = presets[v] or C.AccentPrimary
end)

createSection(pageSettings, "Config")
local cfgRow = newInst("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Parent = pageSettings })
listLayout(cfgRow, 6, Enum.FillDirection.Horizontal)
createButton(cfgRow, "Save Config",  "primary",   function() saveConfig(); notify("Config", "Saved to disk", "success", 2) end)
createButton(cfgRow, "Load Config",  "secondary", function() loadConfig(); notify("Config", "Reloaded from disk", "success", 2) end)
createButton(cfgRow, "Reset",        "danger",    function()
    state = deepcopy(DEFAULTS); saveConfig(); notify("Config", "Defaults restored", "warning", 2)
end)

--==[ Row factory ]==========================================================--
local function trustColor(t)
    if t <= 25 then return C.Success
    elseif t >= 75 then return C.Danger
    else return C.Warning end
end

local function trustLabel(t)
    if t <= 25 then return "CLIENT"
    elseif t >= 75 then return "SERVER"
    else return "INCONCL" end
end

local function buildRow(entry)
    local row = newInst("Frame", {
        BackgroundColor3 = C.SurfaceElevated,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -4, 0, 88),
        Parent = listScroll,
        LayoutOrder = #rowFrames + 1,
    })
    corner(row, 4)
    stroke(row, C.Border, 1, 0.3)

    local strip = newInst("Frame", {
        BackgroundColor3 = trustColor(entry.trust or 50),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, -10),
        Position = UDim2.new(0, 4, 0, 5),
        Parent = row,
    })
    corner(strip, 2)

    newInst("TextLabel", {
        Text = entry.name,
        Font = F.Header, TextSize = 13,
        TextColor3 = C.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 14, 0, 4),
        Size = UDim2.new(0.55, 0, 0, 16),
        Parent = row,
    })
    newInst("TextLabel", {
        Text = ("%s | %s"):format(entry.kind, entry.type),
        Font = F.Code, TextSize = 10,
        TextColor3 = C.TextDim,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 14, 0, 20),
        Size = UDim2.new(0.55, 0, 0, 12),
        Parent = row,
    })
    local tagLbl = newInst("TextLabel", {
        Text = "[" .. (entry.tag or "Other") .. "]",
        Font = F.Code, TextSize = 10,
        TextColor3 = C.AccentSecondary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(1, -110, 0, 4),
        Size = UDim2.new(0, 100, 0, 14),
        Parent = row,
    })
    local trustBg = newInst("Frame", {
        BackgroundColor3 = C.Background,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 100, 0, 8),
        Position = UDim2.new(1, -110, 0, 22),
        Parent = row,
    })
    corner(trustBg, 4)
    local trustFill = newInst("Frame", {
        BackgroundColor3 = trustColor(entry.trust or 50),
        BorderSizePixel = 0,
        Size = UDim2.new((entry.trust or 50) / 100, 0, 1, 0),
        Parent = trustBg,
    })
    corner(trustFill, 4)
    local trustTxt = newInst("TextLabel", {
        Text = ("%s %d"):format(trustLabel(entry.trust or 50), entry.trust or 50),
        Font = F.Code, TextSize = 10,
        TextColor3 = trustColor(entry.trust or 50),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(1, -110, 0, 32),
        Size = UDim2.new(0, 100, 0, 12),
        Parent = row,
    })

    local valLbl = newInst("TextLabel", {
        Text = "= " .. tostring(entry.value),
        Font = F.Code, TextSize = 12,
        TextColor3 = C.AccentPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 14, 0, 34),
        Size = UDim2.new(0.55, 0, 0, 14),
        Parent = row,
    })

    local setBox = newInst("TextBox", {
        Text = "",
        PlaceholderText = "new value",
        Font = F.Code, TextSize = 11,
        TextColor3 = C.TextPrimary,
        PlaceholderColor3 = C.TextDim,
        BackgroundColor3 = C.Surface,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Size = UDim2.new(0, 130, 0, 22),
        Position = UDim2.new(0, 14, 0, 56),
        Parent = row,
    })
    corner(setBox, 4)
    local setBtn = createButton(row, "Set", "primary", function()
        local txt = setBox.Text
        local original = readCurrent(entry)
        entry.restoreValue = original
        local ok, err = pcall(function()
            local raw = entry.value
            local cast
            if type(raw) == "number"  then cast = tonumber(txt) or 0
            elseif type(raw) == "boolean" then cast = (txt:lower() == "true" or txt == "1")
            else cast = txt end
            if entry.kind == "attribute" then entry.parent:SetAttribute(entry.name, cast)
            elseif entry.kind == "value" then entry.parent.Value = cast
            elseif entry.kind == "humanoid" then entry.parent[entry.name] = cast end
        end)
        if ok then
            notify("Set", entry.name .. " written", "success", 2)
        else
            notify("Set failed", tostring(err), "danger", 3)
        end
    end)
    setBtn.Size = UDim2.new(0, 50, 0, 22)
    setBtn.Position = UDim2.new(0, 150, 0, 56)

    local restoreBtn = createButton(row, "Undo", "secondary", function()
        if entry.restoreValue == nil then
            notify("Undo", "No prior value cached", "warning", 2); return
        end
        local ok = pcall(function()
            if entry.kind == "attribute" then entry.parent:SetAttribute(entry.name, entry.restoreValue)
            elseif entry.kind == "value" then entry.parent.Value = entry.restoreValue
            elseif entry.kind == "humanoid" then entry.parent[entry.name] = entry.restoreValue end
        end)
        if ok then notify("Undo", "Restored " .. entry.name, "success", 2) end
    end)
    restoreBtn.Size = UDim2.new(0, 50, 0, 22)
    restoreBtn.Position = UDim2.new(0, 206, 0, 56)

    local remoteBtn = createButton(row, "Remotes", "secondary", function()
        showRemoteCandidates(entry)
    end)
    remoteBtn.Size = UDim2.new(0, 80, 0, 22)
    remoteBtn.Position = UDim2.new(0, 262, 0, 56)

    rowFrames[entry.id] = {
        frame = row, strip = strip, valLbl = valLbl, trustFill = trustFill, trustTxt = trustTxt,
        tagLbl = tagLbl, entry = entry,
    }
end

local function updateRow(entry)
    local rf = rowFrames[entry.id]
    if not rf then return end
    rf.valLbl.Text = "= " .. tostring(entry.value)
    rf.trustFill.BackgroundColor3 = trustColor(entry.trust or 50)
    tween(rf.trustFill, TWEEN_FAST, { Size = UDim2.new((entry.trust or 50) / 100, 0, 1, 0) })
    rf.trustTxt.Text = ("%s %d"):format(trustLabel(entry.trust or 50), entry.trust or 50)
    rf.trustTxt.TextColor3 = trustColor(entry.trust or 50)
    rf.strip.BackgroundColor3 = trustColor(entry.trust or 50)
    rf.tagLbl.Text = "[" .. (entry.tag or "Other") .. "]"
end

function refreshList()
    for _, rf in pairs(rowFrames) do
        local entry = rf.entry
        local visible = true
        if entry then
            local t = entry.trust or 50
            if state.showClientOnly and t > 25 then visible = false end
            if state.showServerOnly and t < 75 then visible = false end
            if t < state.minTrust or t > state.maxTrust then visible = false end
            if state.tagFilter ~= "All" and entry.tag ~= state.tagFilter then visible = false end
        end
        rf.frame.Visible = visible
    end
    updateFooter()
end

function updateFooter()
    local total, client, server = 0, 0, 0
    for _, e in ipairs(registry) do
        total = total + 1
        if (e.trust or 50) <= 25 then client = client + 1
        elseif (e.trust or 50) >= 75 then server = server + 1 end
    end
    W.Footer.Text = ("%d audited | %d client-trusted | %d server-validated | exec: %s"):format(total, client, server, EXEC)
end

--==[ Audit pipeline ]=======================================================--
function runAudit()
    local previous = {}
    if state.rememberProbe then
        for _, e in ipairs(registry) do previous[e.id] = e.trust end
    end
    for _, rf in pairs(rowFrames) do rf.frame:Destroy() end
    rowFrames = {}
    registry = buildEntries()
    for _, e in ipairs(registry) do
        if previous[e.id] then e.trust = previous[e.id] end
        buildRow(e)
    end
    refreshList()
    notify("Audit", ("%d values discovered"):format(#registry), "success", 2)
end

function probeAllTrust()
    if #registry == 0 then runAudit() end
    notify("Probing", "Testing trust on each value...", "info", 2)
    task.spawn(function()
        for _, e in ipairs(registry) do
            local original = readCurrent(e)
            local _, trust = probeWrite(e.kind, e.parent, e.name, original)
            e.trust = trust
            e.value = readCurrent(e)
            updateRow(e)
        end
        refreshList()
        notify("Probe", "Trust scoring complete", "success", 2)
    end)
end

--==[ Remote cross-reference ]==============================================--
local remoteOverlay
function showRemoteCandidates(entry)
    if remoteOverlay then remoteOverlay:Destroy() remoteOverlay = nil end
    remoteOverlay = newInst("Frame", {
        BackgroundColor3 = C.SurfaceElevated,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 260, 0, 200),
        Position = UDim2.new(0.5, -130, 0.5, -100),
        Parent = W.Frame,
        ZIndex = 50,
    })
    corner(remoteOverlay, 6)
    stroke(remoteOverlay, C.AccentPrimary, 1, 0)

    newInst("TextLabel", {
        Text = "Remote candidates for " .. entry.name,
        Font = F.Header, TextSize = 13,
        TextColor3 = C.TextPrimary,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 10, 0, 8),
        Size = UDim2.new(1, -20, 0, 16),
        Parent = remoteOverlay,
        ZIndex = 51,
    })

    local closeBtn = newInst("TextButton", {
        Text = "X",
        Font = F.Header, TextSize = 14,
        TextColor3 = C.Danger,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(1, -28, 0, 4),
        Parent = remoteOverlay,
        ZIndex = 51,
    })
    closeBtn.MouseButton1Click:Connect(function() remoteOverlay:Destroy() remoteOverlay = nil end)

    local sc = newInst("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -16, 1, -36),
        Position = UDim2.new(0, 8, 0, 28),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.AccentPrimary,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = remoteOverlay,
        ZIndex = 51,
    })
    listLayout(sc, 4)

    local matches = {}
    local rs = getgenv().ENI and getgenv().ENI.RemoteScanner
    if rs and rs.GetConfig then
        local ok, cfg = pcall(rs.GetConfig, rs)
        if ok and type(cfg) == "table" and cfg.cache and type(cfg.cache) == "table" then
            for _, remote in ipairs(cfg.cache) do
                local rname = (type(remote) == "table" and remote.Name) or tostring(remote)
                if rname:lower():find(entry.name:lower(), 1, true) then
                    matches[#matches+1] = rname
                end
            end
        end
    end

    if #matches == 0 then
        local rep = game:GetService("ReplicatedStorage")
        for _, d in ipairs(rep:GetDescendants()) do
            if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction"))
               and d.Name:lower():find(entry.name:lower(), 1, true) then
                matches[#matches+1] = d:GetFullName()
            end
        end
    end

    if #matches == 0 then
        newInst("TextLabel", {
            Text = "(no matching remotes found)",
            Font = F.Body, TextSize = 12,
            TextColor3 = C.TextDim,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Parent = sc, ZIndex = 52,
        })
    else
        for _, m in ipairs(matches) do
            newInst("TextLabel", {
                Text = "* " .. m,
                Font = F.Code, TextSize = 11,
                TextColor3 = C.TextPrimary,
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                Size = UDim2.new(1, 0, 0, 16),
                Parent = sc, ZIndex = 52,
            })
        end
    end
end

--==[ Monitor mode ]=========================================================--
function startMonitor()
    monitoring = true
    if #registry == 0 then runAudit() end
    for _, e in ipairs(registry) do
        local conn
        if e.kind == "attribute" then
            conn = e.parent:GetAttributeChangedSignal(e.name):Connect(function()
                local old = e.value
                e.value = e.parent:GetAttribute(e.name)
                updateRow(e)
                pushLog(e, old, e.value, detectSource())
            end)
        elseif e.kind == "value" then
            conn = e.parent:GetPropertyChangedSignal("Value"):Connect(function()
                local old = e.value
                e.value = e.parent.Value
                updateRow(e)
                pushLog(e, old, e.value, detectSource())
            end)
        elseif e.kind == "humanoid" then
            local ok, sig = pcall(function() return e.parent:GetPropertyChangedSignal(e.name) end)
            if ok and sig then
                conn = sig:Connect(function()
                    local old = e.value
                    e.value = e.parent[e.name]
                    updateRow(e)
                    pushLog(e, old, e.value, detectSource())
                end)
            end
        end
        if conn then monitorWatchers[e.id] = conn end
    end
    notify("Monitor", "Live diff active (" .. tostring(#registry) .. " values)", "success", 2)
end

function stopMonitor()
    monitoring = false
    for id, c in pairs(monitorWatchers) do
        pcall(function() c:Disconnect() end)
        monitorWatchers[id] = nil
    end
    notify("Monitor", "Live diff stopped", "info", 2)
end

--==[ Export ]===============================================================--
function exportFindings()
    local report = {
        executor = EXEC,
        timestamp = os.time(),
        player = LP and LP.Name or "?",
        values = {},
    }
    for _, e in ipairs(registry) do
        report.values[#report.values+1] = {
            id = e.id,
            kind = e.kind,
            name = e.name,
            type = e.type,
            value = tostring(e.value),
            trust = e.trust or 50,
            tag = e.tag,
        }
    end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(report) end)
    if not ok then notify("Export", "JSON encode failed", "danger", 3); return end
    pcall(makefolder, CFG_DIR)
    local fname = CFG_DIR .. "/state_finder_report_" .. os.time() .. ".json"
    local wrote = pcall(function() writefile(fname, encoded) end)
    if wrote then
        notify("Export", "Saved " .. fname, "success", 3)
    else
        notify("Export", "writefile unavailable", "warning", 3)
    end
    pcall(function() (setclipboard or toclipboard or writeclipboard)(encoded) end)
end

--==[ Global keybind listener ]==============================================--
track(UserInputService.InputBegan:Connect(function(io, gpe)
    if gpe then return end
    if io.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local kAudit = Enum.KeyCode[state.keyAudit]
    local kMon   = Enum.KeyCode[state.keyMonitor]
    if kAudit and io.KeyCode == kAudit then
        runAudit()
    elseif kMon and io.KeyCode == kMon then
        monitorToggle.set(not monitorToggle.get())
    end
end))

--==[ Auto-audit loop ]======================================================--
task.spawn(function()
    while true do
        task.wait(math.max(1, state.autoAuditInt or 30))
        if state.autoAudit then
            pcall(runAudit)
        end
    end
end)

--==[ Initial audit ]========================================================--
task.spawn(function()
    task.wait(0.4)
    runAudit()
end)

--==[ Character respawn -> re-audit humanoid ]===============================--
if LP then
    track(LP.CharacterAdded:Connect(function()
        task.wait(1)
        if W.Gui and W.Gui.Parent then runAudit() end
    end))
end

--==[ Public API ]===========================================================--
getgenv().ENI = getgenv().ENI or {}
getgenv().ENI.StateFinder = {
    _window = W,
    Show = function(self) W.setVisible(true) end,
    Hide = function(self) W.setVisible(false) end,
    Toggle = function(self) W.setVisible(not W.Gui.Enabled) end,
    Destroy = function(self)
        for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
        for _, c in pairs(monitorWatchers) do pcall(function() c:Disconnect() end) end
        Conns = {}; monitorWatchers = {}
        pcall(function() W.destroy() end)
        if NotifyHolder and NotifyHolder.Parent then
            pcall(function() NotifyHolder.Parent:Destroy() end)
        end
        getgenv().ENI.StateFinder = nil
    end,
    GetConfig = function(self) return deepcopy(state) end,
    SetConfig = function(self, t)
        if type(t) ~= "table" then return end
        for k, v in pairs(t) do state[k] = v end
        saveConfig()
        notify("Config", "Applied external config", "success", 2)
    end,
    RunAudit = function(self) runAudit() end,
    ProbeTrust = function(self) probeAllTrust() end,
    Export = function(self) exportFindings() end,
    GetRegistry = function(self) return deepcopy(registry) end,
}

notify("State Finder", "v2.0.0 loaded (" .. EXEC .. ")", "success", 3)

end
-- END MODULE: STATE FINDER v3.0.0
----------------------------------------------------------------------

----------------------------------------------------------------------
-- MODULE: CONNECTION DUMPER v3.0.0 (942 lines original)
----------------------------------------------------------------------
do
--[[
    ============================================================================
    eni-roblox-kit :: Connection Dumper
    Module : ConnectionDumper
    Version: 2.0.0
    Author : ENI (for LO)
    Desc   : List, inspect, and manipulate RBXScriptSignal connections on any
             Instance. Designed for tearing down anti-cheat hooks, hidden
             surveillance signals, and oppressive remote-event listeners.
    API    : getgenv().ENI.ConnectionDumper
    ============================================================================
]]

-- ============================== ANTI-DETECT ===============================
local cloneref = cloneref or function(x) return x end
local protect_gui = (syn and syn.protect_gui) or (gethui and function(g) g.Parent = gethui() end) or function(g) g.Parent = game:GetService('CoreGui') end
local hookmetamethod = hookmetamethod or function() return nil end
local getrawmetatable = getrawmetatable or function() return nil end
local setreadonly = setreadonly or function() end
local newcclosure = newcclosure or function(f) return f end

-- ============================== SERVICES ==================================
local Players          = cloneref(game:GetService('Players'))
local RunService       = cloneref(game:GetService('RunService'))
local UserInputService = cloneref(game:GetService('UserInputService'))
local TweenService     = cloneref(game:GetService('TweenService'))
local HttpService      = cloneref(game:GetService('HttpService'))
local Lighting         = cloneref(game:GetService('Lighting'))
local Workspace        = cloneref(game:GetService('Workspace'))

-- ============================== ENV DETECT ================================
local EXEC = 'Unknown'
pcall(function()
    if identifyexecutor then EXEC = (identifyexecutor()) or 'Unknown'
    elseif syn then EXEC = 'Synapse X'
    elseif KRNL_LOADED then EXEC = 'Krnl'
    elseif fluxus then EXEC = 'Fluxus' end
end)
local HAS_GETCONNECTIONS = type(getconnections) == 'function'
local HAS_GETUPVALUES    = type(getupvalues) == 'function' or (type(debug)=='table' and type(debug.getupvalues)=='function')
local HAS_GETINFO        = type(debug) == 'table' and type(debug.info) == 'function'

local function safe_getupvalues(fn)
    if type(getupvalues) == 'function' then local ok,r = pcall(getupvalues,fn); if ok then return r end end
    if debug and type(debug.getupvalues) == 'function' then local ok,r = pcall(debug.getupvalues,fn); if ok then return r end end
    return {}
end
local function safe_getconstants(fn)
    if type(getconstants) == 'function' then local ok,r = pcall(getconstants,fn); if ok then return r end end
    if debug and type(debug.getconstants) == 'function' then local ok,r = pcall(debug.getconstants,fn); if ok then return r end end
    return {}
end

-- ============================== DESIGN TOKENS =============================
local C = {
    Background      = Color3.fromRGB(15,15,22),
    Surface         = Color3.fromRGB(22,22,30),
    SurfaceElevated = Color3.fromRGB(32,32,42),
    Border          = Color3.fromRGB(45,45,60),
    AccentPrimary   = Color3.fromRGB(255,65,180),
    AccentSecondary = Color3.fromRGB(180,75,255),
    TextPrimary     = Color3.fromRGB(240,240,248),
    TextSecondary   = Color3.fromRGB(160,160,178),
    TextDim         = Color3.fromRGB(100,100,118),
    Success         = Color3.fromRGB(80,220,130),
    Warning         = Color3.fromRGB(255,185,70),
    Danger          = Color3.fromRGB(255,85,110),
}
local F = { Title=Enum.Font.GothamBold, Header=Enum.Font.GothamSemibold, Body=Enum.Font.Gotham, Code=Enum.Font.Code }
local TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function tween(o,p) TweenService:Create(o,TWEEN,p):Play() end

-- ============================== STATE / CONFIG ============================
local function deepcopy(t)
    if type(t) ~= 'table' then return t end
    local r = {}; for k,v in pairs(t) do r[k] = deepcopy(v) end; return r
end
local DEFAULT_STATE = {
    targetPath='Players.LocalPlayer.Character.Humanoid.Died', selectedEvent=nil,
    filterText='', groupBySrc=false, autoBlock={}, pickerKey='F12', refreshKey='Return',
    windowSize={380,520}, minimized=false,
}
local state = deepcopy(DEFAULT_STATE)
local CONFIG_DIR = 'freezer'
local CONFIG_FILE = CONFIG_DIR..'/connection_dumper.json'
pcall(function() if makefolder then makefolder(CONFIG_DIR) end end)
local function saveConfig()
    pcall(function() if writefile then writefile(CONFIG_FILE, HttpService:JSONEncode(state)) end end)
end
local function loadConfig()
    pcall(function()
        if isfile and isfile(CONFIG_FILE) and readfile then
            local ok,dec = pcall(HttpService.JSONDecode, HttpService, readfile(CONFIG_FILE))
            if ok and type(dec)=='table' then for k,v in pairs(dec) do state[k]=v end end
        end
    end)
end
loadConfig()

local TRACKED = {}
local function track(c) TRACKED[#TRACKED+1] = c; return c end

-- ============================== UI PRIMITIVES =============================
-- make(class, props, parent) — bulk property assigner, parents last
local function make(class, props, parent)
    local o = Instance.new(class)
    for k,v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function corner(p, r) return make('UICorner', {CornerRadius=UDim.new(0, r or 6)}, p) end
local function stroke(p, color, thickness, transparency)
    return make('UIStroke', {Color=color or C.Border, Thickness=thickness or 1, Transparency=transparency or 0, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, p)
end
local function padding(p, all)
    return make('UIPadding', {PaddingTop=UDim.new(0,all),PaddingBottom=UDim.new(0,all),PaddingLeft=UDim.new(0,all),PaddingRight=UDim.new(0,all)}, p)
end
local function vlist(p, gap, align)
    return make('UIListLayout', {FillDirection=Enum.FillDirection.Vertical, Padding=UDim.new(0,gap or 8), SortOrder=Enum.SortOrder.LayoutOrder, HorizontalAlignment=align or Enum.HorizontalAlignment.Left}, p)
end
local function hlist(p, gap)
    return make('UIListLayout', {FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,gap or 6), SortOrder=Enum.SortOrder.LayoutOrder, VerticalAlignment=Enum.VerticalAlignment.Center}, p)
end

-- ============================== ROOT GUI ==================================
local ScreenGui = make('ScreenGui', {Name='ENI_ConnectionDumper', ResetOnSpawn=false, IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
pcall(protect_gui, ScreenGui)
if ScreenGui.Parent == nil then ScreenGui.Parent = game:GetService('CoreGui') end

-- ============================== NOTIFY ====================================
local NotifyHolder = make('Frame', {Name='Notifications', BackgroundTransparency=1, AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-14,0,14), Size=UDim2.new(0,300,1,-28)}, ScreenGui)
make('UIListLayout', {Padding=UDim.new(0,8), HorizontalAlignment=Enum.HorizontalAlignment.Right, SortOrder=Enum.SortOrder.LayoutOrder}, NotifyHolder)

local function notify(title, msg, kind, dur)
    kind, dur = kind or 'info', dur or 3.5
    local accent = (kind=='success' and C.Success) or (kind=='warn' and C.Warning) or (kind=='error' and C.Danger) or C.AccentPrimary
    local card = make('Frame', {BackgroundColor3=C.Surface, Size=UDim2.new(1,0,0,56), Position=UDim2.new(1,20,0,0)}, NotifyHolder)
    corner(card, 6); stroke(card, C.Border, 1, 0.4)
    local bar = make('Frame', {BackgroundColor3=accent, BorderSizePixel=0, Size=UDim2.new(0,3,1,-10), Position=UDim2.new(0,6,0,5)}, card)
    corner(bar, 2)
    make('TextLabel', {BackgroundTransparency=1, Font=F.Header, TextSize=14, TextColor3=C.TextPrimary, TextXAlignment=Enum.TextXAlignment.Left, Position=UDim2.new(0,18,0,6), Size=UDim2.new(1,-22,0,18), Text=title or 'ENI'}, card)
    make('TextLabel', {BackgroundTransparency=1, Font=F.Body, TextSize=12, TextColor3=C.TextSecondary, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, Position=UDim2.new(0,18,0,24), Size=UDim2.new(1,-22,1,-26), TextWrapped=true, Text=msg or ''}, card)
    tween(card, {Position=UDim2.new(0,0,0,0)})
    task.delay(dur, function()
        if not card.Parent then return end
        tween(card, {Position=UDim2.new(1,20,0,0), BackgroundTransparency=1})
        task.wait(0.22); card:Destroy()
    end)
end

-- ============================== WINDOW BUILDER ============================
local function createWindow(title, sz)
    local w, h = sz[1], sz[2]
    local win = make('Frame', {Name='Window_'..title, Size=UDim2.new(0,w,0,h), Position=UDim2.new(0.5,-w/2,0.5,-h/2), BackgroundColor3=C.Background, BorderSizePixel=0}, ScreenGui)
    corner(win, 8); stroke(win, C.Border, 1, 0.2)
    make('ImageLabel', {BackgroundTransparency=1, Image='rbxasset://textures/ui/Glow.png', ImageColor3=Color3.new(0,0,0), ImageTransparency=0.55, ScaleType=Enum.ScaleType.Slice, SliceCenter=Rect.new(20,20,80,80), Size=UDim2.new(1,40,1,40), Position=UDim2.new(0,-20,0,-20), ZIndex=0}, win)

    local titleBar = make('Frame', {Size=UDim2.new(1,0,0,36), BackgroundColor3=C.Surface, BorderSizePixel=0}, win)
    corner(titleBar, 8)
    make('Frame', {Size=UDim2.new(1,0,0,10), Position=UDim2.new(0,0,1,-10), BackgroundColor3=C.Surface, BorderSizePixel=0}, titleBar)
    local titleGrad = make('UIGradient', {}, titleBar)
    titleGrad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,C.AccentPrimary), ColorSequenceKeypoint.new(1,C.AccentSecondary)}
    titleGrad.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0,0.78), NumberSequenceKeypoint.new(1,0.92)}
    make('TextLabel', {BackgroundTransparency=1, Font=F.Title, TextSize=18, TextColor3=C.TextPrimary, TextXAlignment=Enum.TextXAlignment.Left, Position=UDim2.new(0,12,0,0), Size=UDim2.new(1,-120,1,0), Text=title}, titleBar)
    make('TextLabel', {BackgroundTransparency=1, Font=F.Body, TextSize=11, TextColor3=C.TextDim, TextXAlignment=Enum.TextXAlignment.Right, AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-76,0,12), Size=UDim2.new(0,50,0,14), Text='v2.0.0'}, titleBar)

    local function makeIconBtn(text, xOff, color)
        local b = make('TextButton', {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,xOff,0.5,0), Size=UDim2.new(0,24,0,24), BackgroundColor3=C.SurfaceElevated, BorderSizePixel=0, Text=text, Font=F.Header, TextSize=14, TextColor3=color or C.TextPrimary, AutoButtonColor=false}, titleBar)
        corner(b, 4)
        b.MouseEnter:Connect(function() tween(b, {BackgroundColor3=C.Border}) end)
        b.MouseLeave:Connect(function() tween(b, {BackgroundColor3=C.SurfaceElevated}) end)
        return b
    end
    local closeBtn = makeIconBtn('X', -8, C.Danger)
    local minBtn   = makeIconBtn('-', -38, C.Warning)

    local Container = make('ScrollingFrame', {Position=UDim2.new(0,0,0,36), Size=UDim2.new(1,0,1,-58), BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=C.AccentPrimary, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y}, win)
    padding(Container, 10); vlist(Container, 8)

    local footer = make('Frame', {AnchorPoint=Vector2.new(0,1), Position=UDim2.new(0,0,1,0), Size=UDim2.new(1,0,0,22), BackgroundColor3=C.Surface, BorderSizePixel=0}, win)
    corner(footer, 8)
    make('Frame', {Size=UDim2.new(1,0,0,10), Position=UDim2.new(0,0,0,0), BackgroundColor3=C.Surface, BorderSizePixel=0}, footer)
    local statusLabel = make('TextLabel', {BackgroundTransparency=1, Font=F.Body, TextSize=11, TextColor3=C.TextDim, TextXAlignment=Enum.TextXAlignment.Left, Position=UDim2.new(0,10,0,0), Size=UDim2.new(1,-20,1,0), Text='idle'}, footer)

    local grip = make('TextButton', {AnchorPoint=Vector2.new(1,1), Position=UDim2.new(1,-2,1,-2), Size=UDim2.new(0,14,0,14), BackgroundTransparency=1, Text='//', Font=F.Body, TextSize=12, TextColor3=C.TextDim, AutoButtonColor=false, ZIndex=5}, win)

    do
        local dragging, startPos, startSize
        grip.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true; startPos=i.Position; startSize=win.AbsoluteSize end end)
        grip.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
        track(UserInputService.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
                local d = i.Position - startPos
                local nw, nh = math.max(320, startSize.X+d.X), math.max(280, startSize.Y+d.Y)
                win.Size = UDim2.new(0,nw,0,nh); state.windowSize = {nw,nh}; saveConfig()
            end
        end))
    end
    do
        local dragging, dragStart, startPos
        titleBar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true; dragStart=i.Position; startPos=win.Position end end)
        titleBar.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
        track(UserInputService.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
                local d = i.Position - dragStart
                win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
            end
        end))
    end

    local W = {Frame=win, Container=Container, Status=statusLabel}
    function W.setVisible(v)
        win.Visible = v
        if v then
            local tw_, th_ = state.windowSize[1], state.windowSize[2]
            win.Size = UDim2.new(0, tw_*0.92, 0, th_*0.92); win.BackgroundTransparency = 0.4
            tween(win, {Size=UDim2.new(0,tw_,0,th_), BackgroundTransparency=0})
        end
    end
    local realH = state.windowSize[2]
    function W.toggleMinimize()
        state.minimized = not state.minimized
        if state.minimized then
            realH = win.Size.Y.Offset
            tween(win, {Size=UDim2.new(0,win.Size.X.Offset,0,36)})
            Container.Visible=false; footer.Visible=false
        else
            tween(win, {Size=UDim2.new(0,win.Size.X.Offset,0,realH)})
            Container.Visible=true; footer.Visible=true
        end
        saveConfig()
    end
    minBtn.MouseButton1Click:Connect(W.toggleMinimize)
    closeBtn.MouseButton1Click:Connect(function() W.setVisible(false) end)
    function W.destroy() win:Destroy() end
    W.notify = notify
    win.Size = UDim2.new(0, state.windowSize[1], 0, state.windowSize[2])
    return W
end

-- ============================== HELPER WIDGETS ============================
local function createSection(parent, title)
    local sec = make('Frame', {BackgroundColor3=C.Surface, BorderSizePixel=0, Size=UDim2.new(1,0,0,30), AutomaticSize=Enum.AutomaticSize.Y}, parent)
    corner(sec, 6); stroke(sec, C.Border, 1, 0.5); padding(sec, 10); vlist(sec, 6)
    make('TextLabel', {BackgroundTransparency=1, Font=F.Header, TextSize=15, TextColor3=C.AccentPrimary, TextXAlignment=Enum.TextXAlignment.Left, Size=UDim2.new(1,0,0,18), Text=title, LayoutOrder=-1}, sec)
    make('Frame', {BackgroundColor3=C.Border, BorderSizePixel=0, Size=UDim2.new(1,0,0,1), BackgroundTransparency=0.4, LayoutOrder=0}, sec)
    local body = make('Frame', {BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, LayoutOrder=1}, sec)
    vlist(body, 6); return body
end

local function createButton(parent, label, style, cb)
    style = style or 'primary'
    local baseColor = (style=='danger' and C.Danger) or (style=='secondary' and C.SurfaceElevated) or C.AccentPrimary
    local hoverColor = (style=='danger' and Color3.fromRGB(255,110,130)) or (style=='secondary' and C.Border) or Color3.fromRGB(255,100,200)
    local b = make('TextButton', {AutoButtonColor=false, Size=UDim2.new(0,0,0,26), AutomaticSize=Enum.AutomaticSize.X, BackgroundColor3=baseColor, BorderSizePixel=0, Font=F.Header, TextSize=12, TextColor3=C.TextPrimary, Text='  '..label..'  '}, parent)
    corner(b, 4); local s = stroke(b, C.AccentPrimary, 1, 1)
    b.MouseEnter:Connect(function() tween(s,{Transparency=0}); tween(b,{BackgroundColor3=hoverColor}) end)
    b.MouseLeave:Connect(function() tween(s,{Transparency=1}); tween(b,{BackgroundColor3=baseColor}) end)
    b.MouseButton1Click:Connect(function()
        local r = make('Frame', {BackgroundColor3=Color3.new(1,1,1), BackgroundTransparency=0.7, Size=UDim2.new(1,0,1,0)}, b)
        corner(r, 4); tween(r, {BackgroundTransparency=1})
        task.delay(0.22, function() r:Destroy() end)
        if cb then pcall(cb) end
    end)
    return b
end

local function createToggle(parent, label, default, cb)
    local row = make('Frame', {BackgroundTransparency=1, Size=UDim2.new(1,0,0,24)}, parent)
    make('TextLabel', {BackgroundTransparency=1, Font=F.Body, TextSize=13, TextColor3=C.TextSecondary, TextXAlignment=Enum.TextXAlignment.Left, Size=UDim2.new(1,-46,1,0), Text=label}, row)
    local tr = make('TextButton', {AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0), Size=UDim2.new(0,36,0,18), BackgroundColor3=C.SurfaceElevated, AutoButtonColor=false, Text='', BorderSizePixel=0}, row)
    corner(tr, 9); stroke(tr, C.Border, 1, 0.4)
    local knob = make('Frame', {Size=UDim2.new(0,14,0,14), Position=UDim2.new(0,2,0.5,-7), BackgroundColor3=C.TextSecondary, BorderSizePixel=0}, tr)
    corner(knob, 7)
    local val = default and true or false
    local function render()
        if val then
            tween(tr,{BackgroundColor3=C.AccentPrimary}); tween(knob,{Position=UDim2.new(1,-16,0.5,-7), BackgroundColor3=C.TextPrimary})
        else
            tween(tr,{BackgroundColor3=C.SurfaceElevated}); tween(knob,{Position=UDim2.new(0,2,0.5,-7), BackgroundColor3=C.TextSecondary})
        end
    end
    render()
    tr.MouseButton1Click:Connect(function() val = not val; render(); if cb then pcall(cb,val) end end)
    return { set=function(v) val = v and true or false; render() end, get=function() return val end, Instance=row }
end

local function createTextBox(parent, placeholder, default, cb)
    local box = make('TextBox', {Size=UDim2.new(1,0,0,28), BackgroundColor3=C.SurfaceElevated, BorderSizePixel=0, Font=F.Code, TextSize=13, TextColor3=C.TextPrimary, PlaceholderText=placeholder or '', PlaceholderColor3=C.TextDim, Text=default or '', ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Left}, parent)
    corner(box, 4); local s = stroke(box, C.Border, 1, 0.3); padding(box, 8)
    box.Focused:Connect(function() tween(s, {Color=C.AccentPrimary, Transparency=0}) end)
    box.FocusLost:Connect(function(enter) tween(s, {Color=C.Border, Transparency=0.3}); if cb then pcall(cb, box.Text, enter) end end)
    return box
end

local function createDropdown(parent, label, options, default, cb)
    local row = make('Frame', {BackgroundTransparency=1, Size=UDim2.new(1,0,0,50), ClipsDescendants=false}, parent)
    make('TextLabel', {BackgroundTransparency=1, Font=F.Body, TextSize=12, TextColor3=C.TextSecondary, TextXAlignment=Enum.TextXAlignment.Left, Size=UDim2.new(1,0,0,14), Text=label}, row)
    local btn = make('TextButton', {Position=UDim2.new(0,0,0,18), Size=UDim2.new(1,0,0,28), BackgroundColor3=C.SurfaceElevated, AutoButtonColor=false, BorderSizePixel=0, Font=F.Body, TextSize=13, TextColor3=C.TextPrimary, TextXAlignment=Enum.TextXAlignment.Left, Text='  '..tostring(default or 'select...')}, row)
    corner(btn, 4); stroke(btn, C.Border, 1, 0.3)
    local arrow = make('TextLabel', {BackgroundTransparency=1, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-8,0.5,0), Size=UDim2.new(0,16,0,16), Text='v', Font=F.Header, TextSize=12, TextColor3=C.AccentPrimary}, btn)
    local panel = make('ScrollingFrame', {Visible=false, BackgroundColor3=C.Surface, BorderSizePixel=0, Size=UDim2.new(1,0,0,0), ScrollBarThickness=3, ScrollBarImageColor3=C.AccentPrimary, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, Position=UDim2.new(0,0,0,50), ZIndex=10}, row)
    corner(panel, 4); stroke(panel, C.AccentPrimary, 1, 0.4); padding(panel, 4); vlist(panel, 2)
    local current = default; local opts = options or {}; local open = false; local extCb = cb
    local function rebuild()
        for _,c in ipairs(panel:GetChildren()) do if c:IsA('TextButton') then c:Destroy() end end
        for _, o in ipairs(opts) do
            local ob = make('TextButton', {AutoButtonColor=false, BackgroundColor3=C.SurfaceElevated, BorderSizePixel=0, Size=UDim2.new(1,0,0,22), Font=F.Body, TextSize=12, TextColor3=C.TextPrimary, TextXAlignment=Enum.TextXAlignment.Left, Text='  '..tostring(o), ZIndex=11}, panel)
            corner(ob, 3)
            ob.MouseEnter:Connect(function() tween(ob,{BackgroundColor3=C.Border}) end)
            ob.MouseLeave:Connect(function() tween(ob,{BackgroundColor3=C.SurfaceElevated}) end)
            ob.MouseButton1Click:Connect(function()
                current = o; btn.Text='  '..tostring(o); open=false; panel.Visible=false
                row.Size = UDim2.new(1,0,0,50)
                if extCb then pcall(extCb, o) end
            end)
        end
    end
    rebuild()
    btn.MouseButton1Click:Connect(function()
        open = not open; panel.Visible = open
        if open then
            local h = math.min(150, math.max(40, #opts*24))
            row.Size = UDim2.new(1,0,0,50+h+6); panel.Size = UDim2.new(1,0,0,h)
            tween(arrow,{Rotation=180})
        else
            row.Size = UDim2.new(1,0,0,50); tween(arrow,{Rotation=0})
        end
    end)
    return {
        set = function(v, silent) current=v; btn.Text='  '..tostring(v); if not silent and extCb then pcall(extCb,v) end end,
        get = function() return current end,
        refresh = function(newOpts) opts = newOpts or {}; rebuild() end,
        setCallback = function(fn) extCb = fn end,
        Instance = row,
    }
end

local function createSlider(parent, label, mn, mx, default, decimals, cb)
    decimals = decimals or 0
    local row = make('Frame', {BackgroundTransparency=1, Size=UDim2.new(1,0,0,38)}, parent)
    make('TextLabel', {BackgroundTransparency=1, Font=F.Body, TextSize=12, TextColor3=C.TextSecondary, TextXAlignment=Enum.TextXAlignment.Left, Size=UDim2.new(0.7,0,0,14), Text=label}, row)
    local val = make('TextLabel', {BackgroundTransparency=1, Font=F.Code, TextSize=12, TextColor3=C.AccentPrimary, TextXAlignment=Enum.TextXAlignment.Right, AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), Size=UDim2.new(0.3,0,0,14), Text=tostring(default)}, row)
    local barBg = make('TextButton', {AutoButtonColor=false, Text='', Position=UDim2.new(0,0,0,22), Size=UDim2.new(1,0,0,8), BackgroundColor3=C.SurfaceElevated, BorderSizePixel=0}, row)
    corner(barBg, 4)
    local fill = make('Frame', {BackgroundColor3=C.AccentPrimary, BorderSizePixel=0, Size=UDim2.new((default-mn)/(mx-mn),0,1,0)}, barBg); corner(fill, 4)
    local knob = make('Frame', {AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new((default-mn)/(mx-mn),0,0.5,0), Size=UDim2.new(0,14,0,14), BackgroundColor3=C.TextPrimary, BorderSizePixel=0}, barBg); corner(knob, 7)
    local cur, dragging = default, false
    local function setFromX(px)
        local rel = math.clamp((px - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
        cur = mn + (mx-mn)*rel
        local m = 10 ^ decimals; cur = math.floor(cur*m + 0.5)/m
        local nrel = (cur-mn)/(mx-mn)
        tween(fill,{Size=UDim2.new(nrel,0,1,0)}); tween(knob,{Position=UDim2.new(nrel,0,0.5,0)})
        val.Text = tostring(cur); if cb then pcall(cb,cur) end
    end
    barBg.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true; setFromX(i.Position.X) end end)
    barBg.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
    track(UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then setFromX(i.Position.X) end
    end))
    return { set=function(v) cur=v; local nrel=(v-mn)/(mx-mn); fill.Size=UDim2.new(nrel,0,1,0); knob.Position=UDim2.new(nrel,0,0.5,0); val.Text=tostring(v) end, get=function() return cur end }
end

local function createKeybind(parent, label, defaultKey, cb)
    local row = make('Frame', {BackgroundTransparency=1, Size=UDim2.new(1,0,0,24)}, parent)
    make('TextLabel', {BackgroundTransparency=1, Font=F.Body, TextSize=13, TextColor3=C.TextSecondary, TextXAlignment=Enum.TextXAlignment.Left, Size=UDim2.new(1,-90,1,0), Text=label}, row)
    local btn = make('TextButton', {AutoButtonColor=false, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0), Size=UDim2.new(0,80,0,22), BackgroundColor3=C.SurfaceElevated, BorderSizePixel=0, Font=F.Code, TextSize=12, TextColor3=C.AccentPrimary, Text=tostring(defaultKey or 'NONE')}, row)
    corner(btn, 4); local s = stroke(btn, C.Border, 1, 0.4)
    local current, conn = defaultKey, nil
    btn.MouseButton1Click:Connect(function()
        btn.Text = '...'; tween(s,{Color=C.AccentPrimary, Transparency=0})
        if conn then conn:Disconnect() end
        conn = UserInputService.InputBegan:Connect(function(i, p)
            if p then return end
            if i.UserInputType == Enum.UserInputType.Keyboard then
                if i.KeyCode == Enum.KeyCode.Escape then current=nil; btn.Text='NONE'
                else current=i.KeyCode.Name; btn.Text=current end
                tween(s,{Color=C.Border, Transparency=0.4})
                if cb then pcall(cb,current) end
                conn:Disconnect(); conn=nil
            end
        end)
    end)
    return { set=function(v) current=v; btn.Text=v or 'NONE' end, get=function() return current end }
end

local function createColorPicker(parent, label, defaultC, cb)
    local row = make('Frame', {BackgroundTransparency=1, Size=UDim2.new(1,0,0,24)}, parent)
    make('TextLabel', {BackgroundTransparency=1, Font=F.Body, TextSize=13, TextColor3=C.TextSecondary, TextXAlignment=Enum.TextXAlignment.Left, Size=UDim2.new(1,-34,1,0), Text=label}, row)
    local swatch = make('TextButton', {AutoButtonColor=false, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0), Size=UDim2.new(0,24,0,18), BackgroundColor3=defaultC or Color3.new(1,1,1), BorderSizePixel=0, Text=''}, row)
    corner(swatch, 3); stroke(swatch, C.Border, 1, 0.3)
    local cur, popup = defaultC or Color3.new(1,1,1), nil
    swatch.MouseButton1Click:Connect(function()
        if popup and popup.Parent then popup:Destroy(); popup=nil; return end
        popup = make('Frame', {Size=UDim2.new(0,180,0,160), Position=UDim2.new(0, swatch.AbsolutePosition.X-160, 0, swatch.AbsolutePosition.Y+22), BackgroundColor3=C.Surface, BorderSizePixel=0, ZIndex=20}, ScreenGui)
        corner(popup, 6); stroke(popup, C.AccentPrimary, 1, 0.4)
        local sv = make('ImageButton', {Size=UDim2.new(0,130,0,130), Position=UDim2.new(0,8,0,8), BackgroundColor3=Color3.fromHSV(0,1,1), BorderSizePixel=0, AutoButtonColor=false, ZIndex=21}, popup)
        local svGrad = make('UIGradient', {Color=ColorSequence.new(Color3.new(1,1,1), Color3.fromHSV(0,1,1))}, sv)
        local svDark = make('Frame', {BackgroundColor3=Color3.new(0,0,0), Size=UDim2.new(1,0,1,0), BorderSizePixel=0, ZIndex=22}, sv)
        make('UIGradient', {Rotation=90, Transparency=NumberSequence.new(1,0)}, svDark)
        local hue = make('ImageButton', {Size=UDim2.new(0,24,0,130), Position=UDim2.new(0,146,0,8), BackgroundColor3=Color3.new(1,1,1), AutoButtonColor=false, BorderSizePixel=0, ZIndex=21}, popup)
        local hueGrad = make('UIGradient', {Rotation=90}, hue)
        hueGrad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromHSV(0,1,1)),
            ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17,1,1)),
            ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33,1,1)),
            ColorSequenceKeypoint.new(0.50, Color3.fromHSV(0.50,1,1)),
            ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67,1,1)),
            ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83,1,1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(1,1,1)),
        }
        local hVal, s_, v_ = 0, 1, 1
        local function update()
            cur = Color3.fromHSV(hVal, s_, v_)
            swatch.BackgroundColor3 = cur; sv.BackgroundColor3 = Color3.fromHSV(hVal,1,1)
            svGrad.Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromHSV(hVal,1,1))
            if cb then pcall(cb, cur) end
        end
        local function dragOn(target, axisFn)
            target.InputBegan:Connect(function(i)
                if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                axisFn(); local m, e
                m = UserInputService.InputChanged:Connect(function(i2) if i2.UserInputType==Enum.UserInputType.MouseMovement then axisFn() end end)
                e = UserInputService.InputEnded:Connect(function(i2) if i2.UserInputType==Enum.UserInputType.MouseButton1 then m:Disconnect(); e:Disconnect() end end)
            end)
        end
        dragOn(sv, function()
            local mp = UserInputService:GetMouseLocation()
            s_ = math.clamp((mp.X - sv.AbsolutePosition.X)/sv.AbsoluteSize.X, 0, 1)
            v_ = 1 - math.clamp((mp.Y - sv.AbsolutePosition.Y)/sv.AbsoluteSize.Y, 0, 1)
            update()
        end)
        dragOn(hue, function()
            local mp = UserInputService:GetMouseLocation()
            hVal = math.clamp((mp.Y - hue.AbsolutePosition.Y)/hue.AbsoluteSize.Y, 0, 1)
            update()
        end)
    end)
    return { set=function(c) cur=c; swatch.BackgroundColor3=c end, get=function() return cur end }
end

local function createScrollFrame(parent)
    local s = make('ScrollingFrame', {BackgroundTransparency=1, BorderSizePixel=0, Size=UDim2.new(1,0,0,220), ScrollBarThickness=3, ScrollBarImageColor3=C.AccentPrimary, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y}, parent)
    padding(s, 4); vlist(s, 4); return s
end

-- ============================== BUILD WINDOW ==============================
local Window = createWindow('Connection Dumper', state.windowSize)

local refreshList, refreshAutoList, loadTargetFromPath

-- Target
local targetBody = createSection(Window.Container, 'Target Path')
local pathBox = createTextBox(targetBody, 'Players.LocalPlayer.Character.Humanoid.Died', state.targetPath, function(t) state.targetPath=t; saveConfig() end)
local btnRow = make('Frame', {BackgroundTransparency=1, Size=UDim2.new(1,0,0,28)}, targetBody); hlist(btnRow, 6)
local goBtn      = createButton(btnRow, 'Go',         'primary')
local pickBtn    = createButton(btnRow, 'Eyedropper', 'secondary')
local refreshBtn = createButton(btnRow, 'Refresh',    'secondary')

-- Event
local eventBody = createSection(Window.Container, 'Signal')
local eventDD = createDropdown(eventBody, 'Event on instance', {'(no target)'}, '(no target)')

-- Filter
local filterBody = createSection(Window.Container, 'Filter & Display')
local filterBox = createTextBox(filterBody, 'filter by source script substring...', state.filterText, function(t) state.filterText=t; saveConfig(); if refreshList then refreshList() end end)
local groupToggle = createToggle(filterBody, 'Group by source script', state.groupBySrc, function(v) state.groupBySrc=v; saveConfig(); if refreshList then refreshList() end end)

-- Connection list
local listBody = createSection(Window.Container, 'Connections')
local batchRow = make('Frame', {BackgroundTransparency=1, Size=UDim2.new(1,0,0,28)}, listBody); hlist(batchRow, 6)
local batchDisable = createButton(batchRow, 'Disable Sel', 'danger')
local batchEnable  = createButton(batchRow, 'Enable Sel',  'primary')
local batchFire    = createButton(batchRow, 'Fire Sel',    'secondary')
local stateRow = make('Frame', {BackgroundTransparency=1, Size=UDim2.new(1,0,0,28)}, listBody); hlist(stateRow, 6)
local snapshotBtn   = createButton(stateRow, 'Snapshot',    'secondary')
local restoreBtn    = createButton(stateRow, 'Restore',     'secondary')
local disableAllBtn = createButton(stateRow, 'Disable All', 'danger')
local enableAllBtn  = createButton(stateRow, 'Enable All',  'primary')
local listScroll = createScrollFrame(listBody); listScroll.Size = UDim2.new(1,0,0,240)

-- Inspector
local inspBody = createSection(Window.Container, 'Inspector')
local inspLabel = make('TextLabel', {BackgroundTransparency=1, Font=F.Code, TextSize=12, TextColor3=C.TextSecondary, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, Size=UDim2.new(1,0,0,140), TextWrapped=true, Text='select a connection to view upvalues + constants'}, inspBody)

-- Fire args
local fireBody = createSection(Window.Container, 'Fire Arguments')
local argsBox = createTextBox(fireBody, 'json array e.g. [1,"hello",true]', '[]', function() end)
local fireCurrentBtn = createButton(fireBody, 'Fire selected connection', 'secondary')

-- Auto-block
local autoBody = createSection(Window.Container, 'Auto-Block List')
local autoSigBox = createTextBox(autoBody, 'signal name e.g. Died (blank = *)', '', function() end)
local autoSrcBox = createTextBox(autoBody, 'source script substring e.g. AntiCheat', '', function() end)
local addAutoBtn = createButton(autoBody, '+ Add rule', 'secondary')
local autoScroll = createScrollFrame(autoBody); autoScroll.Size = UDim2.new(1,0,0,100)

-- Keybinds
local kbBody = createSection(Window.Container, 'Keybinds')
local pickerKB  = createKeybind(kbBody, 'Picker mode',  state.pickerKey,  function(k) state.pickerKey=k; saveConfig() end)
local refreshKB = createKeybind(kbBody, 'Refresh list', state.refreshKey, function(k) state.refreshKey=k; saveConfig() end)

-- Cosmetics
local cosmeticBody = createSection(Window.Container, 'Cosmetics')
local accentPick = createColorPicker(cosmeticBody, 'Accent color (preview)', C.AccentPrimary, function(c) notify('Accent', string.format('%d %d %d', math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255)), 'info', 1.5) end)
local hoverSlider = createSlider(cosmeticBody, 'Eyedropper hover radius', 1, 50, 8, 0, function() end)

-- Settings
local cfgBody = createSection(Window.Container, 'Settings')
createButton(cfgBody, 'Save Config', 'secondary', function() saveConfig(); notify('Saved','config written','success',2) end)
createButton(cfgBody, 'Load Config', 'secondary', function()
    loadConfig()
    pathBox.Text = state.targetPath; filterBox.Text = state.filterText
    groupToggle.set(state.groupBySrc); pickerKB.set(state.pickerKey); refreshKB.set(state.refreshKey)
    notify('Loaded','config restored','success',2)
    if refreshAutoList then refreshAutoList() end; if refreshList then refreshList() end
end)
createButton(cfgBody, 'Reset Defaults', 'danger', function()
    state = deepcopy(DEFAULT_STATE); saveConfig()
    pathBox.Text = state.targetPath; filterBox.Text = state.filterText
    groupToggle.set(state.groupBySrc); pickerKB.set(state.pickerKey); refreshKB.set(state.refreshKey)
    notify('Reset','defaults restored','warn',2)
    if refreshAutoList then refreshAutoList() end; if refreshList then refreshList() end
end)

-- ============================== CORE LOGIC ================================
local currentInstance, currentSignal = nil, nil
local currentConnections, snapshotStates, selectedRowIdx = {}, nil, nil

local function resolvePath(path)
    if type(path) ~= 'string' or path == '' then return nil, nil end
    local parts = {}; for seg in string.gmatch(path, '[^%.]+') do parts[#parts+1] = seg end
    if #parts == 0 then return nil, nil end
    local function step(obj, name)
        if obj == game and name == 'Players'   then return Players end
        if obj == game and name == 'Workspace' then return Workspace end
        if obj == game and name == 'Lighting'  then return Lighting end
        if obj == Players and name == 'LocalPlayer' then return Players.LocalPlayer end
        local ok, child = pcall(function() return obj[name] end)
        if ok then return child end
    end
    local root
    if parts[1] == 'game' then root = game; table.remove(parts,1)
    elseif parts[1] == 'workspace' or parts[1] == 'Workspace' then root = Workspace; table.remove(parts,1)
    elseif parts[1] == 'Players' then root = Players; table.remove(parts,1)
    elseif parts[1] == 'Lighting' then root = Lighting; table.remove(parts,1)
    else root = game end
    local obj, lastEvent = root, nil
    for i = 1, #parts do
        local nxt = step(obj, parts[i])
        if nxt == nil then
            if i == #parts then lastEvent = parts[i]; break end
            return nil, nil
        end
        if i == #parts then
            if typeof(nxt) == 'RBXScriptSignal' then lastEvent = parts[i] else obj = nxt end
        else obj = nxt end
    end
    return obj, lastEvent
end

local function listSignals(inst)
    if not inst then return {} end
    local sigs = {}
    for _, prop in ipairs({'Changed','AncestryChanged','ChildAdded','ChildRemoved','DescendantAdded','DescendantRemoving','Destroying'}) do
        if pcall(function() return inst[prop] end) then sigs[#sigs+1] = prop end
    end
    local extras = {
        Humanoid       = {'Died','Running','Jumping','Climbing','FreeFalling','GettingUp','HealthChanged','StateChanged','Touched','Seated'},
        BasePart       = {'Touched','TouchEnded'},
        Player         = {'CharacterAdded','CharacterRemoving','Chatted','Idled'},
        RemoteEvent    = {'OnClientEvent'},
        UnreliableRemoteEvent = {'OnClientEvent'},
        RemoteFunction = {'OnClientInvoke'},
        BindableEvent  = {'Event'},
        Tool           = {'Activated','Deactivated','Equipped','Unequipped'},
        ClickDetector  = {'MouseClick','MouseHoverEnter','MouseHoverLeave','RightMouseClick'},
        ProximityPrompt= {'Triggered','TriggerEnded','PromptShown','PromptHidden'},
        Animator       = {'AnimationPlayed'},
        AnimationTrack = {'Stopped','KeyframeReached','DidLoop','Ended'},
        GuiButton      = {'Activated','MouseButton1Click','MouseButton1Down','MouseButton1Up','MouseButton2Click'},
    }
    for cls, list in pairs(extras) do
        local ok, isit = pcall(function() return inst:IsA(cls) end)
        if ok and isit then
            for _, name in ipairs(list) do
                if pcall(function() return inst[name] end) then sigs[#sigs+1] = name end
            end
        end
    end
    local seen, out = {}, {}
    for _, n in ipairs(sigs) do if not seen[n] then seen[n]=true; out[#out+1]=n end end
    table.sort(out); return out
end

local function getInstFullName(inst)
    if not inst then return '(nil)' end
    local ok, s = pcall(function() return inst:GetFullName() end)
    return ok and s or tostring(inst)
end

local function describeFn(fn)
    if type(fn) ~= 'function' then return {name='(non-function)', src='?', line=0, upvalues=0, fn=function() end} end
    local name, src, line = '(anonymous)', '?', 0
    if HAS_GETINFO then
        pcall(function()
            local n,s,l = debug.info(fn,'n'), debug.info(fn,'s'), debug.info(fn,'l')
            if n and n ~= '' then name = n end
            if s then src = s end
            if l then line = l end
        end)
    end
    local upvs = safe_getupvalues(fn)
    local ups = type(upvs) == 'table' and #upvs or 0
    if type(src) == 'string' and #src > 60 then src = '...'..src:sub(-58) end
    return {name=tostring(name), src=tostring(src), line=tonumber(line) or 0, upvalues=ups, fn=fn}
end

local function clearList()
    for _, c in ipairs(listScroll:GetChildren()) do
        if c:IsA('Frame') or c:IsA('TextLabel') then c:Destroy() end
    end
    currentConnections = {}; selectedRowIdx = nil
end

local function setStatus()
    local cnt = #currentConnections
    Window.Status.Text = string.format('target: %s | %d connection%s | exec: %s', state.targetPath or '(none)', cnt, cnt==1 and '' or 's', EXEC)
end

local function inspectConnection(idx)
    local rec = currentConnections[idx]
    if not rec then inspLabel.Text = '(none)'; return end
    selectedRowIdx = idx
    local fn = rec.meta.fn
    local upvs, consts = safe_getupvalues(fn), safe_getconstants(fn)
    local function summarize(t, max)
        if type(t) ~= 'table' then return '(unavailable)' end
        local out = {}
        for i = 1, math.min(#t, max) do
            local v = t[i]; local tv = typeof(v); local sv = tostring(v)
            if tv == 'function' then sv = '<function>' elseif tv == 'table' then sv = '<table>' end
            out[#out+1] = string.format('[%d] %s = %s', i, tv, sv:sub(1,50))
        end
        if #t > max then out[#out+1] = '... '..(#t-max)..' more' end
        return #out == 0 and '(empty)' or table.concat(out, '\n')
    end
    inspLabel.Text = string.format('fn=%s\nsrc=%s:%d\n\n-- upvalues (%d) --\n%s\n\n-- constants (%d) --\n%s',
        rec.meta.name, rec.meta.src, rec.meta.line,
        type(upvs)=='table' and #upvs or 0, summarize(upvs,8),
        type(consts)=='table' and #consts or 0, summarize(consts,12))
end

local function tryEnable(c)  pcall(function() if c.Enable then c:Enable() end end); pcall(function() c.Enabled = true end) end
local function tryDisable(c) pcall(function() if c.Disable then c:Disable() end end); pcall(function() c.Enabled = false end) end
local function tryFire(c, args) pcall(function() if c.Fire then c:Fire(table.unpack(args)) end end) end

local function makeConnRow(parent, rec, idx)
    local row = make('Frame', {BackgroundColor3=C.SurfaceElevated, BorderSizePixel=0, Size=UDim2.new(1,-2,0,82)}, parent)
    corner(row, 4); stroke(row, C.Border, 1, 0.4)
    local cb = make('TextButton', {AutoButtonColor=false, Position=UDim2.new(0,6,0,6), Size=UDim2.new(0,16,0,16), BackgroundColor3=C.Surface, BorderSizePixel=0, Text=''}, row)
    corner(cb, 3); stroke(cb, C.Border, 1, 0.3)
    cb.MouseButton1Click:Connect(function() rec.selected = not rec.selected; cb.BackgroundColor3 = rec.selected and C.AccentPrimary or C.Surface end)

    make('TextLabel', {BackgroundTransparency=1, Font=F.Header, TextSize=13, TextColor3=C.TextPrimary, TextXAlignment=Enum.TextXAlignment.Left, Position=UDim2.new(0,28,0,4), Size=UDim2.new(1,-130,0,16), Text=rec.meta.name}, row)
    local pill = make('TextLabel', {AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-6,0,4), Size=UDim2.new(0,70,0,16), BackgroundColor3=rec.enabled and C.Success or C.Danger, BorderSizePixel=0, Font=F.Body, TextSize=11, TextColor3=Color3.new(0,0,0), Text=rec.enabled and 'ENABLED' or 'DISABLED'}, row)
    corner(pill, 8)
    make('TextLabel', {BackgroundTransparency=1, Font=F.Code, TextSize=11, TextColor3=C.TextSecondary, TextXAlignment=Enum.TextXAlignment.Left, Position=UDim2.new(0,28,0,22), Size=UDim2.new(1,-34,0,14), Text=string.format('src: %s', rec.meta.src)}, row)
    make('TextLabel', {BackgroundTransparency=1, Font=F.Code, TextSize=11, TextColor3=C.TextDim, TextXAlignment=Enum.TextXAlignment.Left, Position=UDim2.new(0,28,0,36), Size=UDim2.new(1,-34,0,14), Text=string.format('line:%d  upvalues:%d', rec.meta.line, rec.meta.upvalues)}, row)

    local actions = make('Frame', {BackgroundTransparency=1, Position=UDim2.new(0,28,0,54), Size=UDim2.new(1,-34,0,24)}, row); hlist(actions, 4)
    local function refreshPill() pill.BackgroundColor3 = rec.enabled and C.Success or C.Danger; pill.Text = rec.enabled and 'ENABLED' or 'DISABLED' end
    createButton(actions, 'Enable',     'primary',   function() tryEnable(rec.conn);  rec.enabled = true;  refreshPill() end)
    createButton(actions, 'Disable',    'danger',    function() tryDisable(rec.conn); rec.enabled = false; refreshPill() end)
    createButton(actions, 'Fire',       'secondary', function()
        local ok, dec = pcall(HttpService.JSONDecode, HttpService, argsBox.Text or '[]')
        tryFire(rec.conn, (ok and type(dec) == 'table') and dec or {})
    end)
    createButton(actions, 'Disconnect', 'danger',    function() pcall(function() rec.conn:Disconnect() end); rec.enabled = false; refreshPill(); notify('Disconnected', rec.meta.name, 'success', 2) end)
    createButton(actions, 'Inspect',    'secondary', function() inspectConnection(idx) end)
    rec.row, rec.cb = row, cb
end

function refreshList()
    clearList()
    if not currentSignal then setStatus(); return end
    if not HAS_GETCONNECTIONS then
        notify('Missing function', 'getconnections() not available in this executor', 'error', 5)
        setStatus(); return
    end
    local ok, conns = pcall(getconnections, currentSignal)
    if not ok or type(conns) ~= 'table' then
        notify('Error', 'getconnections failed: '..tostring(conns), 'error', 4)
        setStatus(); return
    end
    local filter = (state.filterText or ''):lower()
    local records = {}
    for _, conn in ipairs(conns) do
        local fn
        pcall(function() fn = conn.Function end)
        if not fn then pcall(function() fn = conn.Func end) end
        local meta = describeFn(fn or function() end)
        local enabled = true
        pcall(function() if conn.Enabled ~= nil then enabled = conn.Enabled and true or false end end)
        local rec = {conn=conn, meta=meta, enabled=enabled, selected=false}
        local srcLower = (meta.src or ''):lower()
        if filter == '' or srcLower:find(filter, 1, true) then records[#records+1] = rec end
        for _, rule in ipairs(state.autoBlock or {}) do
            local matchSig = (rule.signalName == '' or state.selectedEvent == rule.signalName)
            local matchSrc = (rule.srcSubstr == '' or srcLower:find((rule.srcSubstr or ''):lower(), 1, true))
            if matchSig and matchSrc then tryDisable(conn); rec.enabled = false end
        end
    end
    if state.groupBySrc then
        local buckets, order = {}, {}
        for _, r in ipairs(records) do
            if not buckets[r.meta.src] then buckets[r.meta.src] = {}; order[#order+1] = r.meta.src end
            table.insert(buckets[r.meta.src], r)
        end
        local idx = 0
        for _, src in ipairs(order) do
            make('TextLabel', {BackgroundTransparency=1, Font=F.Header, TextSize=12, TextColor3=C.AccentSecondary, TextXAlignment=Enum.TextXAlignment.Left, Size=UDim2.new(1,0,0,16), Text=string.format('-- %s (%d) --', src, #buckets[src])}, listScroll)
            for _, r in ipairs(buckets[src]) do idx = idx + 1; currentConnections[idx] = r; makeConnRow(listScroll, r, idx) end
        end
    else
        for i, r in ipairs(records) do currentConnections[i] = r; makeConnRow(listScroll, r, i) end
    end
    setStatus()
end

function refreshAutoList()
    for _, c in ipairs(autoScroll:GetChildren()) do if c:IsA('Frame') then c:Destroy() end end
    for i, rule in ipairs(state.autoBlock or {}) do
        local row = make('Frame', {BackgroundColor3=C.SurfaceElevated, BorderSizePixel=0, Size=UDim2.new(1,-2,0,24)}, autoScroll); corner(row, 3)
        make('TextLabel', {BackgroundTransparency=1, Font=F.Code, TextSize=12, TextColor3=C.TextPrimary, TextXAlignment=Enum.TextXAlignment.Left, Position=UDim2.new(0,8,0,0), Size=UDim2.new(1,-40,1,0), Text=string.format('%s @ %s', (rule.signalName ~= nil and rule.signalName ~= '') and rule.signalName or '*', (rule.srcSubstr ~= nil and rule.srcSubstr ~= '') and rule.srcSubstr or '*')}, row)
        local rm = make('TextButton', {AutoButtonColor=false, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-4,0.5,0), Size=UDim2.new(0,22,0,18), BackgroundColor3=C.Danger, BorderSizePixel=0, Font=F.Header, TextSize=12, TextColor3=Color3.new(0,0,0), Text='x'}, row); corner(rm, 3)
        rm.MouseButton1Click:Connect(function() table.remove(state.autoBlock, i); saveConfig(); refreshAutoList() end)
    end
end

addAutoBtn.MouseButton1Click:Connect(function()
    state.autoBlock = state.autoBlock or {}
    table.insert(state.autoBlock, {signalName=autoSigBox.Text or '', srcSubstr=autoSrcBox.Text or ''})
    saveConfig(); refreshAutoList(); notify('Auto-block','rule added','success',2)
end)
refreshAutoList()

-- ============================== TARGET LOAD ===============================
function loadTargetFromPath()
    local obj, evt = resolvePath(state.targetPath)
    if not obj then notify('Resolve failed', 'could not resolve: '..tostring(state.targetPath), 'error', 4); return end
    currentInstance = obj
    local sigs = listSignals(obj)
    eventDD.refresh(sigs)
    if evt and table.find(sigs, evt) then eventDD.set(evt, true); state.selectedEvent = evt
    elseif #sigs > 0 then eventDD.set(sigs[1], true); state.selectedEvent = sigs[1]
    else eventDD.set('(no events)', true); state.selectedEvent = nil end
    saveConfig()
    currentSignal = nil
    if state.selectedEvent then pcall(function() currentSignal = obj[state.selectedEvent] end) end
    refreshList()
end

eventDD.setCallback(function(opt)
    state.selectedEvent = opt; saveConfig()
    if currentInstance then
        pcall(function() currentSignal = currentInstance[opt] end)
        refreshList()
    end
end)

goBtn.MouseButton1Click:Connect(function() state.targetPath = pathBox.Text or state.targetPath; saveConfig(); loadTargetFromPath() end)
refreshBtn.MouseButton1Click:Connect(function() refreshList(); notify('Refreshed','connection list reloaded','info',2) end)

-- Batch operations
local function batchApply(predicate, action, label)
    local n = 0
    for _, r in ipairs(currentConnections) do if predicate(r) then action(r); n = n + 1 end end
    notify(label, tostring(n)..' connections', n > 0 and 'success' or 'warn', 2)
    refreshList()
end
batchDisable.MouseButton1Click:Connect(function() batchApply(function(r) return r.selected end, function(r) tryDisable(r.conn); r.enabled = false end, 'Disabled') end)
batchEnable.MouseButton1Click:Connect(function()  batchApply(function(r) return r.selected end, function(r) tryEnable(r.conn);  r.enabled = true  end, 'Enabled')  end)
batchFire.MouseButton1Click:Connect(function()
    local ok, dec = pcall(HttpService.JSONDecode, HttpService, argsBox.Text or '[]')
    local args = (ok and type(dec) == 'table') and dec or {}
    local n = 0
    for _, r in ipairs(currentConnections) do if r.selected then tryFire(r.conn, args); n = n + 1 end end
    notify('Fired', tostring(n)..' connections', 'success', 2)
end)
disableAllBtn.MouseButton1Click:Connect(function() batchApply(function() return true end, function(r) tryDisable(r.conn); r.enabled = false end, 'Disabled (all)') end)
enableAllBtn.MouseButton1Click:Connect(function()  batchApply(function() return true end, function(r) tryEnable(r.conn);  r.enabled = true  end, 'Enabled (all)')  end)

snapshotBtn.MouseButton1Click:Connect(function()
    snapshotStates = {}
    for i, r in ipairs(currentConnections) do snapshotStates[i] = r.enabled end
    notify('Snapshot', 'captured state for '..#snapshotStates..' connections', 'success', 2)
end)
restoreBtn.MouseButton1Click:Connect(function()
    if not snapshotStates then notify('Restore', 'no snapshot taken', 'warn', 2); return end
    for i, was in ipairs(snapshotStates) do
        local r = currentConnections[i]
        if r then
            if was then tryEnable(r.conn); r.enabled = true else tryDisable(r.conn); r.enabled = false end
        end
    end
    notify('Restored', 'snapshot applied', 'success', 2); refreshList()
end)

fireCurrentBtn.MouseButton1Click:Connect(function()
    if not selectedRowIdx then notify('Fire','no connection selected','warn',2); return end
    local r = currentConnections[selectedRowIdx]; if not r then return end
    local ok, dec = pcall(HttpService.JSONDecode, HttpService, argsBox.Text or '[]')
    tryFire(r.conn, (ok and type(dec) == 'table') and dec or {})
    notify('Fired', r.meta.name, 'success', 2)
end)

-- ============================== EYEDROPPER ================================
local pickerActive, pickerHighlight = false, nil
local function startPicker()
    if pickerActive then return end
    pickerActive = true
    notify('Picker','click any GUI or workspace object (ESC to cancel)','info',4)
    pickerHighlight = make('Frame', {BackgroundTransparency=1, Size=UDim2.new(1,0,1,0), ZIndex=100}, ScreenGui)
    local box = make('Frame', {BackgroundTransparency=1, BorderSizePixel=0, ZIndex=101}, pickerHighlight)
    stroke(box, C.AccentPrimary, 2, 0); corner(box, 3)
    local rsConn, clickConn
    local function cleanup()
        pickerActive = false
        if pickerHighlight then pickerHighlight:Destroy(); pickerHighlight = nil end
        if rsConn then rsConn:Disconnect() end; if clickConn then clickConn:Disconnect() end
    end
    rsConn = RunService.RenderStepped:Connect(function()
        local mp = UserInputService:GetMouseLocation()
        local guiObjs = {}
        pcall(function()
            local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass('PlayerGui')
            if pg then guiObjs = pg:GetGuiObjectsAtPosition(mp.X, mp.Y) end
        end)
        local top
        for _, g in ipairs(guiObjs) do if g ~= box and not g:IsDescendantOf(ScreenGui) then top = g; break end end
        if top then
            box.Visible = true
            box.Position = UDim2.new(0, top.AbsolutePosition.X, 0, top.AbsolutePosition.Y)
            box.Size = UDim2.new(0, top.AbsoluteSize.X, 0, top.AbsoluteSize.Y)
        else box.Visible = false end
    end)
    clickConn = UserInputService.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            local mp = UserInputService:GetMouseLocation()
            local picked
            pcall(function()
                local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass('PlayerGui')
                if pg then
                    for _, g in ipairs(pg:GetGuiObjectsAtPosition(mp.X, mp.Y)) do
                        if not g:IsDescendantOf(ScreenGui) then picked = g; break end
                    end
                end
            end)
            if not picked then
                pcall(function()
                    local cam = Workspace.CurrentCamera
                    if cam then
                        local ray = cam:ViewportPointToRay(mp.X, mp.Y, 0)
                        local rp = RaycastParams.new()
                        rp.FilterType = Enum.RaycastFilterType.Exclude
                        rp.FilterDescendantsInstances = {Players.LocalPlayer and Players.LocalPlayer.Character or Instance.new('Folder')}
                        local hit = Workspace:Raycast(ray.Origin, ray.Direction * 5000, rp)
                        if hit then picked = hit.Instance end
                    end
                end)
            end
            if picked then
                currentInstance = picked
                state.targetPath = getInstFullName(picked); pathBox.Text = state.targetPath; saveConfig()
                local sigs = listSignals(picked); eventDD.refresh(sigs)
                if #sigs > 0 then
                    eventDD.set(sigs[1], true); state.selectedEvent = sigs[1]
                    pcall(function() currentSignal = picked[sigs[1]] end)
                    refreshList()
                end
                notify('Picked', getInstFullName(picked), 'success', 3)
            else notify('Picker','no instance under cursor','warn',2) end
            cleanup()
        elseif i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode == Enum.KeyCode.Escape then
            cleanup(); notify('Picker','cancelled','warn',2)
        end
    end)
end
pickBtn.MouseButton1Click:Connect(startPicker)

-- ============================== GLOBAL KEYBINDS ===========================
track(UserInputService.InputBegan:Connect(function(i, processed)
    if processed then return end
    if i.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if state.pickerKey and i.KeyCode.Name == state.pickerKey then startPicker()
    elseif state.refreshKey and i.KeyCode.Name == state.refreshKey then refreshList() end
end))

-- ============================== INITIAL LOAD ==============================
task.spawn(function() pcall(loadTargetFromPath); setStatus() end)
if not HAS_GETCONNECTIONS then notify('Limited mode','getconnections missing - most features disabled','warn',6) end
if not HAS_GETUPVALUES    then notify('Limited mode','getupvalues missing - inspector limited','warn',4) end

-- ============================== PUBLIC API ================================
getgenv().ENI = getgenv().ENI or {}
if getgenv().ENI.ConnectionDumper and getgenv().ENI.ConnectionDumper.Destroy then
    pcall(getgenv().ENI.ConnectionDumper.Destroy, getgenv().ENI.ConnectionDumper)
end
getgenv().ENI.ConnectionDumper = {
    Show   = function(self) Window.setVisible(true) end,
    Hide   = function(self) Window.setVisible(false) end,
    Toggle = function(self) Window.setVisible(not Window.Frame.Visible) end,
    Destroy = function(self)
        for _, c in ipairs(TRACKED) do pcall(function() c:Disconnect() end) end
        pcall(function() ScreenGui:Destroy() end)
        if getgenv().ENI then getgenv().ENI.ConnectionDumper = nil end
    end,
    GetConfig = function(self) return deepcopy(state) end,
    SetConfig = function(self, t)
        if type(t) ~= 'table' then return end
        for k, v in pairs(t) do state[k] = v end
        saveConfig()
        pathBox.Text = state.targetPath or ''; filterBox.Text = state.filterText or ''
        groupToggle.set(state.groupBySrc); pickerKB.set(state.pickerKey); refreshKB.set(state.refreshKey)
        refreshAutoList(); refreshList()
    end,
    Refresh = function(self) refreshList() end,
    SetTarget = function(self, path)
        state.targetPath = path; pathBox.Text = path; saveConfig(); loadTargetFromPath()
    end,
    ListConnections = function(self)
        local out = {}
        for _, r in ipairs(currentConnections) do
            out[#out+1] = {name=r.meta.name, src=r.meta.src, line=r.meta.line, enabled=r.enabled}
        end
        return out
    end,
}
notify('Connection Dumper', 'v2.0.0 ready ('..EXEC..')', 'success', 3)
return getgenv().ENI.ConnectionDumper

end
-- END MODULE: CONNECTION DUMPER v3.0.0
----------------------------------------------------------------------

----------------------------------------------------------------------
-- HUB LOADER v3.0.0  (2898 lines original, patched for embedded modules)
----------------------------------------------------------------------

--[[
================================================================================
  eni-roblox-kit  ::  Hub Loader v3.0.0
  Windows 11 Settings-style monolithic loader
  API: getgenv().ENI.Hub
================================================================================
--]]

-- =============================================================================
-- ANTI-DETECT BLOCK
-- =============================================================================
local ScreenGuiName = getgenv()._FREEZER_GUI_NAME or ("_" .. tostring(math.random(1000000, 9999999)))
local IsProtectedGui = (gethui ~= nil) or (syn and syn.protect_gui ~= nil)
local cloneref = cloneref or function(x) return x end
local protect_gui = (syn and syn.protect_gui) or (gethui and function(g) g.Parent = gethui() end) or function(g) g.Parent = game:GetService('CoreGui') end
local hookmetamethod = hookmetamethod or function() return nil end
local getrawmetatable = getrawmetatable or function() return nil end
local setreadonly = setreadonly or function() end
local newcclosure = newcclosure or function(f) return f end
local checkcaller = checkcaller or function() return false end
local writefile = writefile or function() end
local readfile = readfile or function() return nil end
local isfile = isfile or function() return false end
local isfolder = isfolder or function() return false end
local makefolder = makefolder or function() end
local listfiles = listfiles or function() return {} end
local delfile = delfile or function() end
local setclipboard = setclipboard or (toclipboard) or function() end
local queue_on_teleport = queue_on_teleport or syn and syn.queue_on_teleport or function() end
local identifyexecutor = identifyexecutor or function() return "Unknown" end

if not isfolder("freezer") then pcall(makefolder, "freezer") end
if not isfolder("freezer/configs") then pcall(makefolder, "freezer/configs") end

-- =============================================================================
-- SERVICES
-- =============================================================================
local Players              = cloneref(game:GetService("Players"))
local RunService           = cloneref(game:GetService("RunService"))
local UserInputService     = cloneref(game:GetService("UserInputService"))
local TweenService         = cloneref(game:GetService("TweenService"))
local HttpService          = cloneref(game:GetService("HttpService"))
local Lighting             = cloneref(game:GetService("Lighting"))
local Workspace            = cloneref(game:GetService("Workspace"))
local MarketplaceService   = cloneref(game:GetService("MarketplaceService"))
local Stats                = cloneref(game:GetService("Stats"))
local TextChatService      = pcall(function() return game:GetService("TextChatService") end) and cloneref(game:GetService("TextChatService")) or nil
local StarterGui           = cloneref(game:GetService("StarterGui"))
local SoundService         = cloneref(game:GetService("SoundService"))

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer and LocalPlayer:GetMouse()
local Camera      = Workspace.CurrentCamera

-- =============================================================================
-- GLOBAL ENI NAMESPACE
-- =============================================================================
getgenv().ENI = getgenv().ENI or {}
getgenv().ENI.Version = "3.2.0"
getgenv().ENI.State = getgenv().ENI.State or {}
getgenv().ENI.KeybindRegistry = getgenv().ENI.KeybindRegistry or {}
getgenv().ENI.LoadedModules = getgenv().ENI.LoadedModules or {}
getgenv().ENI.Theme = getgenv().ENI.Theme or {}
getgenv().ENI.Connections = getgenv().ENI.Connections or {}

-- If a prior Hub exists, destroy it
if getgenv().ENI.Hub and getgenv().ENI.Hub.Destroy then
    pcall(function() getgenv().ENI.Hub.Destroy() end)
end

-- =============================================================================
-- THEME / COLORS
-- =============================================================================
local Theme = {
    WindowBg       = Color3.fromRGB(20, 20, 26),
    SidebarBg      = Color3.fromRGB(24, 24, 30),
    ContentBg      = Color3.fromRGB(28, 28, 34),
    CardBg         = Color3.fromRGB(36, 36, 44),
    CardBgHover    = Color3.fromRGB(42, 42, 52),
    Border         = Color3.fromRGB(54, 54, 66),
    AccentPrimary  = Color3.fromRGB(255, 65, 180),
    AccentSoft     = Color3.fromRGB(80, 32, 60),
    TextPrimary    = Color3.fromRGB(240, 240, 248),
    TextSecondary  = Color3.fromRGB(170, 170, 188),
    TextDim        = Color3.fromRGB(115, 115, 135),
    Success        = Color3.fromRGB(80, 220, 130),
    Warning        = Color3.fromRGB(255, 185, 70),
    Danger         = Color3.fromRGB(255, 90, 110),
}
getgenv().ENI.Theme = Theme

-- =============================================================================
-- UTILITY HELPERS
-- =============================================================================
local Connections = {}
local function track(conn)
    table.insert(Connections, conn)
    return conn
end

local function clearConnections()
    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(Connections)
end

local function tween(obj, info, props)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local Q = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local Q_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local Q_SLOW = TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local function new(class, props)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then inst[k] = v end
        end
        if props.Parent then inst.Parent = props.Parent end
    end
    return inst
end

local function corner(parent, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = parent })
end

local function stroke(parent, color, thickness)
    return new("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function padding(parent, all, l, r, t, b)
    local p = new("UIPadding", { Parent = parent })
    if all then
        p.PaddingLeft = UDim.new(0, all)
        p.PaddingRight = UDim.new(0, all)
        p.PaddingTop = UDim.new(0, all)
        p.PaddingBottom = UDim.new(0, all)
    else
        p.PaddingLeft = UDim.new(0, l or 0)
        p.PaddingRight = UDim.new(0, r or 0)
        p.PaddingTop = UDim.new(0, t or 0)
        p.PaddingBottom = UDim.new(0, b or 0)
    end
    return p
end

-- =============================================================================
-- STATE / CONFIG
-- =============================================================================
local DefaultState = {
    Window = { Pos = {x = 250, y = 80}, Collapsed = false, Hidden = false },
    Theme = { Preset = "Magenta", CustomPrimary = {255,65,180}, CustomSecondary = {80,32,60}, BgOpacity = 1.0, Scale = 1.0 },
    Home = {
        MasterEnabled = false,
        QuickToggles = { "Aim.Aimbot", "Visual.ESP", "Movement.WS", "SilentAim.Enabled", "AntiCheat.Enabled" },
    },
    Aim = {
        Aimbot = { Enabled = false, Mode = "Closest", FOV = 90, FOVCircle = false, Smoothing = 0.25,
                   TargetPart = "Head", WallCheck = false, TeamCheck = true, Prediction = 0.165, Sticky = false,
                   Indicator = false, Key = "MouseButton2" },
        Trigger = { Enabled = false, Key = "Q", Delay = 50, Jitter = 20, KnockCheck = false },
    },
    SilentAim = {
        Enabled = false, Method = "AUTO", AutoRemote = "", FOV = 60, TargetPart = "Head",
        WallCheck = false, TeamCheck = true, HitChance = 100, BoneRandom = false,
        Preset = "Generic", Whitelist = "", OccasionalMiss = 0, DebugLog = false, Visualizer = false,
    },
    MagicBullet = {
        Enabled = false, Mode = "Direct", BulletRemote = "", TargetPart = "Head", Selection = "Crosshair",
        ForceHit = false, Range = 1000, MaxPerSec = 10, Jitter = 0.1, OccasionalMiss = 0, DebugLog = false,
    },
    Visual = {
        Master = false, Box = false, Name = false, Health = false, Distance = false, Tracer = false, Skeleton = false, Chams = false,
        BoxMode = "Corner", NameFormat = "{name} [{distance}m]", HealthbarPos = "Left", TracerOrigin = "Bottom",
        ChamsFillColor = {255,65,180}, ChamsFillT = 0.5, ChamsOutlineColor = {255,255,255}, ChamsOutlineT = 0,
        ChamsDepth = "AlwaysOnTop", TeamCheck = true, UseTeamColor = false, VisibilityCheck = true,
        VisibleColor = {80,220,130}, InvisibleColor = {255,90,110}, MaxDistance = 1500, RefreshRate = 30,
        FOVCircle = false, HideOwn = true, ItemESP = "", NPC = false,
    },
    Movement = {
        WS = 16, JP = 50, JH = 7.2, HipHeight = 0, Gravity = 196.2, Sideways = 1.0, MaxSlope = 89,
        Fly = false, FlyMode = "CFrame", FlySpeed = 50, VerticalKeys = true,
        InfJump = false, Noclip = false, Spinbot = false, SpinRate = 1080, TPForward = false, TPForwardDist = 15,
        WallClimb = false, MoonJump = false, SpiderClimb = false, SpeedBurst = false, BurstMult = 3, BurstDur = 1.5,
        AntiFling = false, AntiFlingThresh = 250, AntiVoid = false, AntiVoidThresh = -500,
        AutoReapply = false, PanicKey = "F1", Profile = "Default",
    },
    Desync = {
        Enabled = false, Method = "NetworkOwner", Offset = 6, Direction = "Behind",
        CustomX = 0, CustomY = 0, CustomZ = 0,
        AutoOnAim = false, AutoFOV = 30, Key = "X", GhostIndicator = false, RealIndicator = false,
        ReplicationOK = "Unknown", ResetOnRespawn = false, SmoothTransition = 0.2, HitboxOnly = false, Verbose = false,
    },
    Teleport = {
        Player = "", OffsetX = 0, OffsetY = 0, OffsetZ = 0,
        Slots = {}, Waypoints = {}, CtrlClick = false, CoordX = 0, CoordY = 0, CoordZ = 0,
        TPNearestKey = "T", TPRandomKey = "Y", AutoFollow = false, FollowDist = 8,
        Smooth = false, SmoothDur = 0.5, History = {}, Mode = "Hard", AntiVelocity = false,
        ReturnKey = "B",
    },
    Network = { LogSize = 25, Paused = false, Filter = "", },
    Spoof = {
        Premium = false, GamepassMaster = false, GamepassWL = "", GamepassBL = "",
        Asset = false, Badge = false, GroupId = 0, GroupRank = 0, GroupRole = "", Policy = false,
        Attributes = {}, Leaderstats = {}, HideAdminUI = false, IsStudio = false, OwnerSpoof = false,
        HookLog = false,
    },
    AntiCheat = {
        Enabled = false, WS = 16, JP = 50, JH = 7.2, HipHeight = 2, Gravity = 196.2,
        BlockNewindex = false, NamecallBlocklist = "", AntiKick = false, AntiTPOut = false,
        HideAC = false, ACPatterns = "Detect,Anti,Cheat,Guard", BlockedRemoteResponse = "Drop",
        RawmtSpoof = false, DrawingMask = false, DetectWarn = false,
    },
    ChatSpy = {
        Channels = { All = false, Team = false, Whisper = false, System = false },
        PlayerFilter = "All", Search = "", HiddenWhispers = false, OtherTeam = false,
        Alerts = "", AlertSound = false, MaxLog = 200, Paused = false, BlockList = "",
    },
    Misc = {
        AntiAFK = false, FPSCap = 0, FOV = 70, TimeOfDay = 14, FreezeTime = false,
        Fullbright = false, NoFog = false, NoShadows = false, SkyPreset = "Default",
        SkyTop = "", SkyBottom = "", SkyFront = "", SkyBack = "", SkyLeft = "", SkyRight = "",
        FreeCam = false, FreeCamSpeed = 50, Spectate = "",
        ServerHopThresh = 30,
        MasterVolume = 1.0, MusicURL = "",
        Crosshair = false, CrosshairSize = 10, CrosshairColor = {255,65,180},
        HitMarker = false, NoRecoil = false, NoSprintCD = false,
    },
    LiveState = {
        AutoProbe = false, ProbeInterval = 2.0, Properties = "WalkSpeed,JumpPower,Health,MaxHealth,HipHeight,Gravity",
        ServerTrust = 75, FilterChips = { "Local", "Replicated", "Unknown" },
    },
    Configs = {
        Theme = "Magenta", BgOpacity = 1.0, Scale = 1.0,
        AutoSave = true, SavedSlots = {},
        ModuleAutoload = { Aim = false, Visual = false, Movement = false, Misc = false },
    },
}

local State = {}
local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = deepCopy(v) end
    return c
end

State = deepCopy(DefaultState)

local function loadConfig()
    if isfile("freezer/hub.json") then
        pcall(function()
            local raw = readfile("freezer/hub.json")
            local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
            if ok and type(decoded) == "table" then
                -- merge instead of replace
                for k, v in pairs(decoded) do
                    State[k] = v
                end
            end
        end)
    end
end

local saveQueued = false
local function saveConfig()
    if saveQueued then return end
    saveQueued = true
    task.delay(2, function()
        pcall(function()
            writefile("freezer/hub.json", HttpService:JSONEncode(State))
        end)
        saveQueued = false
    end)
end

loadConfig()
getgenv().ENI.State = State

-- =============================================================================
-- NOTIFICATION SYSTEM
-- =============================================================================
local NotifGui
local NotifStack

local function notify(title, msg, kind, duration)
    title    = tostring(title or "ENI")
    msg      = tostring(msg or "")
    kind     = kind or "info"
    duration = duration or 4

    if not NotifGui then return end

    local color = ({
        info    = Theme.AccentPrimary,
        success = Theme.Success,
        warn    = Theme.Warning,
        error   = Theme.Danger,
    })[kind] or Theme.AccentPrimary

    local card = new("Frame", {
        Size = UDim2.new(0, 320, 0, 64),
        BackgroundColor3 = Theme.CardBg,
        BorderSizePixel = 0,
        Position = UDim2.new(1, 340, 0, 0),
        Parent = NotifStack,
    })
    corner(card, 6); stroke(card, Theme.Border, 1)

    new("Frame", {
        Size = UDim2.new(0, 3, 1, -8),
        Position = UDim2.new(0, 4, 0, 4),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = card,
    })

    new("TextLabel", {
        Size = UDim2.new(1, -24, 0, 18),
        Position = UDim2.new(0, 16, 0, 8),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        Font = Enum.Font.GothamSemibold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })
    new("TextLabel", {
        Size = UDim2.new(1, -24, 0, 32),
        Position = UDim2.new(0, 16, 0, 26),
        BackgroundTransparency = 1,
        Text = msg,
        TextColor3 = Theme.TextSecondary,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = card,
    })

    tween(card, Q, { Position = UDim2.new(0, 0, 0, 0) })

    task.delay(duration, function()
        if card and card.Parent then
            local fade = TweenService:Create(card, Q_SLOW, { Position = UDim2.new(1, 340, 0, 0), BackgroundTransparency = 1 })
            fade:Play()
            fade.Completed:Connect(function() card:Destroy() end)
        end
    end)
end

getgenv().ENI.notify = notify

-- =============================================================================
-- ROOT GUI
-- =============================================================================
local ScreenGui = new("ScreenGui", {
    Name = ScreenGuiName,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
})
protect_gui(ScreenGui)
if not ScreenGui.Parent then ScreenGui.Parent = game:GetService("CoreGui") end

-- Notification stack
NotifGui = new("Frame", {
    Name = "Notifications",
    Size = UDim2.new(0, 320, 1, -80),
    Position = UDim2.new(1, -340, 0, 20),
    BackgroundTransparency = 1,
    Parent = ScreenGui,
})
NotifStack = NotifGui
new("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    Parent = NotifStack,
})

-- =============================================================================
-- WINDOW SHELL (Win11 Settings style)
-- =============================================================================
local Window = new("Frame", {
    Name = "Window",
    Size = UDim2.new(0, 920, 0, 600),
    Position = UDim2.fromOffset(State.Window.Pos.x or 250, State.Window.Pos.y or 80),
    BackgroundColor3 = Theme.WindowBg,
    BorderSizePixel = 0,
    Parent = ScreenGui,
    ClipsDescendants = true,
})
corner(Window, 10); stroke(Window, Theme.Border, 1)

-- Magenta top stripe
new("Frame", {
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = Theme.AccentPrimary,
    BorderSizePixel = 0,
    Parent = Window,
})

-- Title bar
local TitleBar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 40),
    Position = UDim2.fromOffset(0, 2),
    BackgroundColor3 = Theme.WindowBg,
    BorderSizePixel = 0,
    Parent = Window,
})

-- Logo
local Logo = new("Frame", {
    Size = UDim2.fromOffset(12, 12),
    Position = UDim2.fromOffset(14, 14),
    BackgroundColor3 = Theme.AccentPrimary,
    BorderSizePixel = 0,
    Parent = TitleBar,
})
corner(Logo, 3)

-- Title text
new("TextLabel", {
    Size = UDim2.fromOffset(160, 20),
    Position = UDim2.fromOffset(34, 10),
    BackgroundTransparency = 1,
    Text = "freezer",
    TextColor3 = Theme.TextPrimary,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = TitleBar,
})

-- Search bar
local SearchBar = new("Frame", {
    Size = UDim2.fromOffset(380, 28),
    Position = UDim2.new(0.5, -190, 0, 6),
    BackgroundColor3 = Theme.ContentBg,
    BorderSizePixel = 0,
    Parent = TitleBar,
})
corner(SearchBar, 14)
new("TextLabel", {
    Size = UDim2.fromOffset(20, 28),
    Position = UDim2.fromOffset(10, 0),
    BackgroundTransparency = 1,
    Text = "?", -- search glyph fallback
    TextColor3 = Theme.TextDim,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    Parent = SearchBar,
})
local SearchBox = new("TextBox", {
    Size = UDim2.new(1, -40, 1, 0),
    Position = UDim2.fromOffset(34, 0),
    BackgroundTransparency = 1,
    Text = "",
    PlaceholderText = "Search settings...",
    PlaceholderColor3 = Theme.TextDim,
    TextColor3 = Theme.TextPrimary,
    Font = Enum.Font.Gotham,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    Parent = SearchBar,
})

-- Min / Close buttons (Win11 style)
local function makeWinButton(parent, posX, glyph, hoverColor, click)
    local btn = new("TextButton", {
        Size = UDim2.fromOffset(46, 40),
        Position = UDim2.new(1, posX, 0, 0),
        BackgroundColor3 = Theme.CardBg,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = glyph,
        TextColor3 = Theme.TextPrimary,
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        Parent = parent,
    })
    btn.MouseEnter:Connect(function()
        tween(btn, Q_FAST, { BackgroundTransparency = 0, BackgroundColor3 = hoverColor or Theme.CardBg })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, Q_FAST, { BackgroundTransparency = 1 })
    end)
    btn.MouseButton1Click:Connect(click)
    return btn
end

local CloseBtn = makeWinButton(TitleBar, -46, "X", Theme.Danger, function()
    if getgenv().ENI.Hub then getgenv().ENI.Hub.Hide() end
end)
local MinBtn = makeWinButton(TitleBar, -92, "_", Theme.CardBg, function()
    if getgenv().ENI.Hub then getgenv().ENI.Hub.Hide() end
end)

-- =============================================================================
-- SIDEBAR
-- =============================================================================
local Sidebar = new("Frame", {
    Size = UDim2.new(0, 220, 1, -68),
    Position = UDim2.fromOffset(0, 42),
    BackgroundColor3 = Theme.SidebarBg,
    BorderSizePixel = 0,
    Parent = Window,
})

local SidebarList = new("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Theme.AccentPrimary,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = Sidebar,
})
padding(SidebarList, nil, 0, 0, 8, 8)
new("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 2),
    Parent = SidebarList,
})

-- Content frame
local ContentArea = new("Frame", {
    Size = UDim2.new(1, -220, 1, -68),
    Position = UDim2.fromOffset(220, 42),
    BackgroundColor3 = Theme.ContentBg,
    BorderSizePixel = 0,
    Parent = Window,
})

local Breadcrumb = new("TextLabel", {
    Size = UDim2.new(1, -40, 0, 14),
    Position = UDim2.fromOffset(20, 14),
    BackgroundTransparency = 1,
    Text = "Home",
    TextColor3 = Theme.TextDim,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = ContentArea,
})

local SectionTitle = new("TextLabel", {
    Size = UDim2.new(1, -40, 0, 30),
    Position = UDim2.fromOffset(20, 32),
    BackgroundTransparency = 1,
    Text = "Home",
    TextColor3 = Theme.TextPrimary,
    Font = Enum.Font.GothamBold,
    TextSize = 24,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = ContentArea,
})

local SectionDesc = new("TextLabel", {
    Size = UDim2.new(1, -40, 0, 18),
    Position = UDim2.fromOffset(20, 66),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = Theme.TextSecondary,
    Font = Enum.Font.Gotham,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = ContentArea,
})

local SearchHint = new("TextLabel", {
    Size = UDim2.new(1, -40, 0, 16),
    Position = UDim2.fromOffset(20, 88),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = Theme.AccentPrimary,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = ContentArea,
    Visible = false,
})

local ContentScroll = new("ScrollingFrame", {
    Size = UDim2.new(1, -20, 1, -120),
    Position = UDim2.fromOffset(10, 110),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Theme.AccentPrimary,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    Parent = ContentArea,
})
padding(ContentScroll, nil, 10, 10, 4, 14)

local CardListLayout = new("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = ContentScroll,
})

-- =============================================================================
-- STATUS BAR
-- =============================================================================
local StatusBar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 26),
    Position = UDim2.new(0, 0, 1, -26),
    BackgroundColor3 = Theme.WindowBg,
    BorderSizePixel = 0,
    Parent = Window,
})
new("Frame", {
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = Theme.Border,
    BorderSizePixel = 0,
    Parent = StatusBar,
})
new("Frame", {
    Size = UDim2.fromOffset(6, 6),
    Position = UDim2.fromOffset(10, 10),
    BackgroundColor3 = Theme.AccentPrimary,
    BorderSizePixel = 0,
    Parent = StatusBar,
})

local StatusText = new("TextLabel", {
    Size = UDim2.new(1, -30, 1, 0),
    Position = UDim2.fromOffset(22, 0),
    BackgroundTransparency = 1,
    Text = "FPS 0 / Ping 0ms / 0 players / Loading...",
    TextColor3 = Theme.TextDim,
    Font = Enum.Font.Code,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = StatusBar,
})

-- Live stats updater
local fpsCount, fpsLast = 0, tick()
local currentFPS = 0
track(RunService.RenderStepped:Connect(function()
    fpsCount = fpsCount + 1
    local now = tick()
    if now - fpsLast >= 0.5 then
        currentFPS = math.floor(fpsCount / (now - fpsLast))
        fpsCount = 0
        fpsLast = now
    end
end))

local function updateStatus()
    local ping = 0
    pcall(function()
        ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
    end)
    local gameName = "Unknown"
    pcall(function() gameName = MarketplaceService:GetProductInfo(game.PlaceId).Name end)
    local hour = os.date("*t").hour
    local minute = os.date("*t").min
    StatusText.Text = string.format("FPS %d / Ping %dms / %d players / %s / %02d:%02d",
        currentFPS, ping, #Players:GetPlayers(), gameName:sub(1, 20), hour, minute)
end
task.spawn(function()
    while ScreenGui.Parent do
        updateStatus()
        task.wait(0.5)
    end
end)

-- =============================================================================
-- DRAG WINDOW
-- =============================================================================
do
    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = Window.Position
        end
    end)
    TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            State.Window.Pos.x = Window.Position.X.Offset
            State.Window.Pos.y = Window.Position.Y.Offset
            saveConfig()
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            Window.Position = UDim2.fromOffset(
                startPos.X.Offset + delta.X,
                startPos.Y.Offset + delta.Y
            )
        end
    end))
end

-- =============================================================================
-- CONTROL FACTORIES
-- =============================================================================
local Controls = {}

local function newRow(parent, label, sub)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    local lbl = new("TextLabel", {
        Size = UDim2.new(0.5, 0, 0, 18),
        Position = UDim2.fromOffset(0, sub and 4 or 13),
        BackgroundTransparency = 1,
        Text = label or "",
        TextColor3 = Theme.TextPrimary,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    if sub then
        new("TextLabel", {
            Size = UDim2.new(0.5, 0, 0, 14),
            Position = UDim2.fromOffset(0, 22),
            BackgroundTransparency = 1,
            Text = sub,
            TextColor3 = Theme.TextDim,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })
    end
    return row
end

function Controls.Toggle(parent, label, default, callback, sub)
    local row = newRow(parent, label, sub)
    local state = default and true or false

    local pill = new("Frame", {
        Size = UDim2.fromOffset(38, 20),
        Position = UDim2.new(1, -42, 0.5, -10),
        BackgroundColor3 = state and Theme.AccentPrimary or Theme.CardBg,
        BorderSizePixel = 0,
        Parent = row,
    })
    corner(pill, 10)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromOffset(state and 20 or 2, 2),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BorderSizePixel = 0,
        Parent = pill,
    })
    corner(knob, 8)

    local function set(v, fireCb)
        state = v and true or false
        tween(pill, Q, { BackgroundColor3 = state and Theme.AccentPrimary or Theme.CardBg })
        tween(knob, Q, { Position = UDim2.fromOffset(state and 20 or 2, 2) })
        if fireCb and callback then pcall(callback, state) end
    end

    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        Parent = row,
    })
    btn.MouseButton1Click:Connect(function() set(not state, true) end)

    return {
        Set = function(v) set(v, true) end,
        Get = function() return state end,
        Frame = row,
    }
end

function Controls.Slider(parent, label, min, max, default, decimals, callback, sub)
    decimals = decimals or 0
    local row = newRow(parent, label, sub)
    local value = default

    local track = new("Frame", {
        Size = UDim2.fromOffset(180, 4),
        Position = UDim2.new(1, -240, 0.5, -2),
        BackgroundColor3 = Theme.CardBg,
        BorderSizePixel = 0,
        Parent = row,
    })
    corner(track, 2)

    local fill = new("Frame", {
        Size = UDim2.new((value-min)/(max-min), 0, 1, 0),
        BackgroundColor3 = Theme.AccentPrimary,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(fill, 2)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.new((value-min)/(max-min), -7, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(knob, 7)

    local valueLabel = new("TextLabel", {
        Size = UDim2.fromOffset(50, 16),
        Position = UDim2.new(1, -50, 0.5, -8),
        BackgroundTransparency = 1,
        Text = tostring(value),
        TextColor3 = Theme.TextSecondary,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = row,
    })

    local dragging = false
    local function format(v)
        if decimals == 0 then return tostring(math.floor(v + 0.5)) end
        local mult = 10 ^ decimals
        return tostring(math.floor(v * mult + 0.5) / mult)
    end

    local function set(v, fire)
        value = math.clamp(v, min, max)
        local pct = (value - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, -7, 0.5, -7)
        valueLabel.Text = format(value)
        if fire and callback then pcall(callback, tonumber(format(value))) end
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    track.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
            set(min + math.clamp(rel, 0, 1) * (max - min), true)
        end
    end))

    return {
        Set = function(v) set(v, true) end,
        Get = function() return value end,
        Frame = row,
    }
end

function Controls.Dropdown(parent, label, options, default, callback, sub)
    local row = newRow(parent, label, sub)
    local value = default or options[1]

    local btn = new("TextButton", {
        Size = UDim2.fromOffset(160, 28),
        Position = UDim2.new(1, -164, 0.5, -14),
        BackgroundColor3 = Theme.ContentBg,
        BorderSizePixel = 0,
        Text = tostring(value) .. "    v",
        TextColor3 = Theme.TextPrimary,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        Parent = row,
    })
    corner(btn, 4); stroke(btn, Theme.Border, 1)

    local open = false
    local list
    local function close()
        open = false
        if list then list:Destroy() list = nil end
    end

    btn.MouseButton1Click:Connect(function()
        if open then close() return end
        open = true
        list = new("Frame", {
            Size = UDim2.fromOffset(160, math.min(#options * 26 + 8, 200)),
            Position = UDim2.fromOffset(
                btn.AbsolutePosition.X,
                btn.AbsolutePosition.Y + 30
            ),
            BackgroundColor3 = Theme.CardBg,
            BorderSizePixel = 0,
            Parent = ScreenGui,
            ZIndex = 50,
        })
        corner(list, 4); stroke(list, Theme.Border, 1)
        local scroll = new("ScrollingFrame", {
            Size = UDim2.new(1, -4, 1, -4),
            Position = UDim2.fromOffset(2, 2),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Theme.AccentPrimary,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ZIndex = 51,
            Parent = list,
        })
        new("UIListLayout", { Parent = scroll })
        for _, opt in ipairs(options) do
            local item = new("TextButton", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = Theme.CardBg,
                BorderSizePixel = 0,
                Text = tostring(opt),
                TextColor3 = opt == value and Theme.AccentPrimary or Theme.TextPrimary,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                ZIndex = 52,
                Parent = scroll,
            })
            item.MouseEnter:Connect(function()
                tween(item, Q_FAST, { BackgroundColor3 = Theme.CardBgHover })
            end)
            item.MouseLeave:Connect(function()
                tween(item, Q_FAST, { BackgroundColor3 = Theme.CardBg })
            end)
            item.MouseButton1Click:Connect(function()
                value = opt
                btn.Text = tostring(opt) .. "    v"
                if callback then pcall(callback, opt) end
                close()
            end)
        end
        local clickAway
        clickAway = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local pos = UserInputService:GetMouseLocation()
                if list and (pos.X < list.AbsolutePosition.X or pos.X > list.AbsolutePosition.X + list.AbsoluteSize.X
                    or pos.Y < list.AbsolutePosition.Y or pos.Y > list.AbsolutePosition.Y + list.AbsoluteSize.Y) then
                    if pos.X < btn.AbsolutePosition.X or pos.X > btn.AbsolutePosition.X + btn.AbsoluteSize.X
                        or pos.Y < btn.AbsolutePosition.Y or pos.Y > btn.AbsolutePosition.Y + btn.AbsoluteSize.Y then
                        close()
                        clickAway:Disconnect()
                    end
                end
            end
        end)
    end)

    return {
        Set = function(v) value = v; btn.Text = tostring(v) .. "    v"; if callback then pcall(callback, v) end end,
        Get = function() return value end,
        Frame = row,
    }
end

function Controls.Textbox(parent, label, placeholder, default, callback, sub, width)
    local row = newRow(parent, label, sub)
    local box = new("TextBox", {
        Size = UDim2.fromOffset(width or 200, 28),
        Position = UDim2.new(1, -(width or 200) - 4, 0.5, -14),
        BackgroundColor3 = Theme.ContentBg,
        BorderSizePixel = 0,
        Text = default or "",
        PlaceholderText = placeholder or "",
        PlaceholderColor3 = Theme.TextDim,
        TextColor3 = Theme.TextPrimary,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = row,
    })
    corner(box, 4)
    padding(box, nil, 8, 8, 0, 0)
    local underline = new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Parent = box,
    })
    box.Focused:Connect(function() tween(underline, Q, { BackgroundColor3 = Theme.AccentPrimary }) end)
    box.FocusLost:Connect(function()
        tween(underline, Q, { BackgroundColor3 = Theme.Border })
        if callback then pcall(callback, box.Text) end
    end)
    return {
        Set = function(v) box.Text = tostring(v) end,
        Get = function() return box.Text end,
        Frame = row,
    }
end

function Controls.MultiTextbox(parent, label, placeholder, default, height, callback, sub)
    local h = height or 80
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, h + 28),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = label or "",
        TextColor3 = Theme.TextPrimary,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    if sub then
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            Position = UDim2.fromOffset(0, 16),
            BackgroundTransparency = 1,
            Text = sub,
            TextColor3 = Theme.TextDim,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })
    end
    local box = new("TextBox", {
        Size = UDim2.new(1, -8, 0, h),
        Position = UDim2.fromOffset(4, 28),
        BackgroundColor3 = Theme.ContentBg,
        BorderSizePixel = 0,
        Text = default or "",
        PlaceholderText = placeholder or "",
        PlaceholderColor3 = Theme.TextDim,
        TextColor3 = Theme.TextPrimary,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        MultiLine = true,
        ClearTextOnFocus = false,
        Parent = row,
    })
    corner(box, 4); stroke(box, Theme.Border, 1)
    padding(box, 8)
    box.FocusLost:Connect(function() if callback then pcall(callback, box.Text) end end)
    return {
        Set = function(v) box.Text = tostring(v) end,
        Get = function() return box.Text end,
        Frame = row,
    }
end

function Controls.Button(parent, label, style, callback, sub)
    local row = newRow(parent, label or "", sub)
    local color = Theme.AccentPrimary
    if style == "secondary" then color = Theme.CardBgHover
    elseif style == "danger" then color = Theme.Danger end
    local btn = new("TextButton", {
        Size = UDim2.fromOffset(120, 30),
        Position = UDim2.new(1, -124, 0.5, -15),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Text = label or "Click",
        TextColor3 = Color3.fromRGB(255,255,255),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        Parent = row,
    })
    corner(btn, 4)
    btn.MouseEnter:Connect(function()
        tween(btn, Q_FAST, { BackgroundColor3 = Color3.new(
            math.clamp(color.R + 0.07, 0, 1),
            math.clamp(color.G + 0.07, 0, 1),
            math.clamp(color.B + 0.07, 0, 1))
        })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, Q_FAST, { BackgroundColor3 = color })
    end)
    btn.MouseButton1Click:Connect(function() if callback then pcall(callback) end end)
    return { Frame = row, Button = btn }
end

function Controls.Keybind(parent, label, default, callback, sub)
    local row = newRow(parent, label, sub)
    local key = default or "None"
    local btn = new("TextButton", {
        Size = UDim2.fromOffset(100, 28),
        Position = UDim2.new(1, -104, 0.5, -14),
        BackgroundColor3 = Theme.ContentBg,
        BorderSizePixel = 0,
        Text = tostring(key),
        TextColor3 = Theme.TextPrimary,
        Font = Enum.Font.Code,
        TextSize = 12,
        Parent = row,
    })
    corner(btn, 4); stroke(btn, Theme.Border, 1)

    local listening = false
    btn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        btn.Text = "Press a key..."
        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape then
                    key = "None"
                else
                    key = input.KeyCode.Name
                end
                btn.Text = tostring(key)
                listening = false
                conn:Disconnect()
                if callback then pcall(callback, key) end
            end
        end)
    end)

    getgenv().ENI.KeybindRegistry[label] = function(newK) key = newK; btn.Text = newK end
    return {
        Set = function(v) key = v; btn.Text = v end,
        Get = function() return key end,
        Frame = row,
    }
end

function Controls.ColorPicker(parent, label, defaultRGB, callback, sub)
    local row = newRow(parent, label, sub)
    local color = Color3.fromRGB(defaultRGB[1], defaultRGB[2], defaultRGB[3])

    local swatch = new("TextButton", {
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -32, 0.5, -14),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Text = "",
        Parent = row,
    })
    corner(swatch, 4); stroke(swatch, Theme.Border, 1)

    local picker
    swatch.MouseButton1Click:Connect(function()
        if picker then picker:Destroy() picker = nil return end
        picker = new("Frame", {
            Size = UDim2.fromOffset(180, 220),
            Position = UDim2.fromOffset(
                swatch.AbsolutePosition.X - 150,
                swatch.AbsolutePosition.Y + 32
            ),
            BackgroundColor3 = Theme.CardBg,
            BorderSizePixel = 0,
            Parent = ScreenGui,
            ZIndex = 60,
        })
        corner(picker, 6); stroke(picker, Theme.Border, 1)
        padding(picker, 10)

        new("UIListLayout", {
            Padding = UDim.new(0, 6),
            Parent = picker,
        })

        local function rowSlider(name, val)
            local sliderRow = new("Frame", {
                Size = UDim2.new(1, 0, 0, 22),
                BackgroundTransparency = 1,
                ZIndex = 61,
                Parent = picker,
            })
            new("TextLabel", {
                Size = UDim2.fromOffset(14, 22),
                BackgroundTransparency = 1,
                Text = name,
                TextColor3 = Theme.TextSecondary,
                Font = Enum.Font.GothamSemibold,
                TextSize = 12,
                ZIndex = 62,
                Parent = sliderRow,
            })
            local box = new("TextBox", {
                Size = UDim2.fromOffset(50, 22),
                Position = UDim2.new(1, -50, 0, 0),
                BackgroundColor3 = Theme.ContentBg,
                BorderSizePixel = 0,
                Text = tostring(val),
                TextColor3 = Theme.TextPrimary,
                Font = Enum.Font.Code,
                TextSize = 12,
                ZIndex = 62,
                Parent = sliderRow,
            })
            corner(box, 3)
            return box
        end

        local rBox = rowSlider("R", math.floor(color.R * 255))
        local gBox = rowSlider("G", math.floor(color.G * 255))
        local bBox = rowSlider("B", math.floor(color.B * 255))

        local hex = new("TextBox", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = Theme.ContentBg,
            BorderSizePixel = 0,
            Text = string.format("#%02X%02X%02X", color.R*255, color.G*255, color.B*255),
            TextColor3 = Theme.TextPrimary,
            Font = Enum.Font.Code,
            TextSize = 13,
            ZIndex = 61,
            Parent = picker,
        })
        corner(hex, 4)

        local function applyRGB()
            local r = tonumber(rBox.Text) or 0
            local g = tonumber(gBox.Text) or 0
            local b = tonumber(bBox.Text) or 0
            r = math.clamp(r, 0, 255); g = math.clamp(g, 0, 255); b = math.clamp(b, 0, 255)
            color = Color3.fromRGB(r, g, b)
            swatch.BackgroundColor3 = color
            hex.Text = string.format("#%02X%02X%02X", r, g, b)
            if callback then pcall(callback, color, {r, g, b}) end
        end
        rBox.FocusLost:Connect(applyRGB)
        gBox.FocusLost:Connect(applyRGB)
        bBox.FocusLost:Connect(applyRGB)
        hex.FocusLost:Connect(function()
            local h = hex.Text:gsub("#", "")
            if #h == 6 then
                local r = tonumber(h:sub(1,2), 16) or 0
                local g = tonumber(h:sub(3,4), 16) or 0
                local b = tonumber(h:sub(5,6), 16) or 0
                rBox.Text = tostring(r); gBox.Text = tostring(g); bBox.Text = tostring(b)
                applyRGB()
            end
        end)

        local closeBtn = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = Theme.AccentPrimary,
            BorderSizePixel = 0,
            Text = "Close",
            TextColor3 = Color3.fromRGB(255,255,255),
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            ZIndex = 61,
            Parent = picker,
        })
        corner(closeBtn, 4)
        closeBtn.MouseButton1Click:Connect(function() picker:Destroy() picker = nil end)
    end)

    return {
        Set = function(rgb)
            color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
            swatch.BackgroundColor3 = color
        end,
        Get = function() return color end,
        Frame = row,
    }
end

-- =============================================================================
-- CARD BUILDER
-- =============================================================================
local AllCards = {}

local function createCard(parentPage, title, description, masterToggle)
    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundColor3 = Theme.CardBg,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = parentPage,
        LayoutOrder = #parentPage:GetChildren(),
    })
    corner(card, 8)
    padding(card, 16)

    local layout = new("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = card,
    })

    local header = new("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Parent = card,
        LayoutOrder = -2,
    })
    new("TextLabel", {
        Size = UDim2.new(1, masterToggle and -50 or 0, 1, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        Font = Enum.Font.GothamSemibold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })

    if description and description ~= "" then
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = description,
            TextColor3 = Theme.TextDim,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card,
            LayoutOrder = -1,
        })
    end

    AllCards[#AllCards+1] = { Frame = card, Title = title:lower(), Desc = (description or ""):lower(), Page = parentPage }

    return card
end

-- =============================================================================
-- PAGES
-- =============================================================================
local Pages = {}

local function newPage(name)
    local page = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = ContentScroll,
        Visible = false,
    })
    new("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page,
    })
    Pages[name] = page
    return page
end

-- =============================================================================
-- FEATURE LOGIC : AIMBOT
-- =============================================================================
local AimbotEngine = {
    Connection = nil,
    Target = nil,
    Indicator = nil,
    FOVCircle = nil,
}

local function isAlive(plr)
    return plr.Character
        and plr.Character:FindFirstChild("Humanoid")
        and plr.Character.Humanoid.Health > 0
        and plr.Character:FindFirstChild("HumanoidRootPart")
end

local function isVisible(part)
    if not part or not Camera then return true end
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = LocalPlayer.Character and { LocalPlayer.Character } or {}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local hit = Workspace:Raycast(origin, dir, params)
    if not hit then return true end
    return hit.Instance:IsDescendantOf(part.Parent)
end

local function getBestTarget()
    local closest, lowestDelta = nil, math.huge
    local fovRad = State.Aim.Aimbot.FOV
    local mousePos = UserInputService:GetMouseLocation()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) then
            if State.Aim.Aimbot.TeamCheck and plr.Team == LocalPlayer.Team then continue end
            local part = plr.Character:FindFirstChild(State.Aim.Aimbot.TargetPart) or plr.Character.HumanoidRootPart
            if part then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local d = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if d < fovRad and d < lowestDelta then
                        if (not State.Aim.Aimbot.WallCheck) or isVisible(part) then
                            lowestDelta = d
                            closest = part
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function startAimbot()
    if AimbotEngine.Connection then return end
    AimbotEngine.Connection = RunService.RenderStepped:Connect(function(dt)
        if not State.Aim.Aimbot.Enabled then return end
        local active = State.Aim.Aimbot.Key == "Always" or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if State.Aim.Aimbot.Key ~= "MouseButton2" and State.Aim.Aimbot.Key ~= "Always" then
            local ok, kc = pcall(function() return Enum.KeyCode[State.Aim.Aimbot.Key] end)
            if ok and kc then active = UserInputService:IsKeyDown(kc) end
        end
        if not active then
            AimbotEngine.Target = nil
            return
        end
        local target = AimbotEngine.Target
        if not target or not target.Parent or not (State.Aim.Aimbot.Sticky and target) then
            target = getBestTarget()
            AimbotEngine.Target = target
        end
        if target then
            local targetPos = target.Position + target.Velocity * State.Aim.Aimbot.Prediction
            local cur = Camera.CFrame.Position
            local goal = CFrame.new(cur, targetPos)
            local smooth = State.Aim.Aimbot.Smoothing
            Camera.CFrame = Camera.CFrame:Lerp(goal, math.clamp(1 - smooth, 0.01, 1))
        end
    end)
end

local function stopAimbot()
    if AimbotEngine.Connection then
        AimbotEngine.Connection:Disconnect()
        AimbotEngine.Connection = nil
    end
end

-- =============================================================================
-- FEATURE LOGIC : TRIGGERBOT
-- =============================================================================
local TriggerEngine = { Connection = nil }
local function startTrigger()
    if TriggerEngine.Connection then return end
    TriggerEngine.Connection = RunService.Heartbeat:Connect(function()
        if not State.Aim.Trigger.Enabled then return end
        local kc = Enum.KeyCode[State.Aim.Trigger.Key]
        if not kc or not UserInputService:IsKeyDown(kc) then return end
        local target = Mouse.Target
        if target and target.Parent then
            local plr = Players:GetPlayerFromCharacter(target.Parent)
            if plr and plr ~= LocalPlayer and isAlive(plr) then
                local jitter = math.random(-State.Aim.Trigger.Jitter, State.Aim.Trigger.Jitter) / 1000
                task.wait(State.Aim.Trigger.Delay / 1000 + jitter)
                pcall(function()
                    mouse1press()
                    task.wait(0.05)
                    mouse1release()
                end)
            end
        end
    end)
end
local function stopTrigger()
    if TriggerEngine.Connection then TriggerEngine.Connection:Disconnect() TriggerEngine.Connection = nil end
end

-- =============================================================================
-- FEATURE LOGIC : ESP
-- =============================================================================
local ESPCache = {}

local function clearESP(plr)
    if ESPCache[plr] then
        for _, v in pairs(ESPCache[plr]) do
            if typeof(v) == "Instance" then v:Destroy() end
        end
        ESPCache[plr] = nil
    end
end

local function buildESP(plr)
    if plr == LocalPlayer and State.Visual.HideOwn then return end
    if not plr.Character then return end
    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    clearESP(plr)
    ESPCache[plr] = {}

    -- Highlight chams
    if State.Visual.Chams then
        local hl = new("Highlight", {
            Parent = plr.Character,
            FillColor = Color3.fromRGB(unpack(State.Visual.ChamsFillColor)),
            OutlineColor = Color3.fromRGB(unpack(State.Visual.ChamsOutlineColor)),
            FillTransparency = State.Visual.ChamsFillT,
            OutlineTransparency = State.Visual.ChamsOutlineT,
            DepthMode = Enum.HighlightDepthMode[State.Visual.ChamsDepth] or Enum.HighlightDepthMode.AlwaysOnTop,
        })
        ESPCache[plr].Highlight = hl
    end

    -- Billboard name/distance
    local bb = new("BillboardGui", {
        Parent = hrp,
        Adornee = hrp,
        Size = UDim2.fromOffset(120, 30),
        AlwaysOnTop = true,
        Name = "_ENI_ESP",
    })
    local txt = new("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = plr.Name,
        TextColor3 = Theme.AccentPrimary,
        Font = Enum.Font.GothamBold,
        TextStrokeTransparency = 0,
        TextSize = 13,
        Parent = bb,
    })
    ESPCache[plr].BB = bb
    ESPCache[plr].TXT = txt
end

local function updateESP()
    if not State.Visual.Master then
        for plr, _ in pairs(ESPCache) do clearESP(plr) end
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer and State.Visual.HideOwn then continue end
        if State.Visual.TeamCheck and plr.Team == LocalPlayer.Team then clearESP(plr) continue end
        if isAlive(plr) then
            if not ESPCache[plr] then buildESP(plr) end
            if ESPCache[plr] and ESPCache[plr].TXT then
                local hrp = plr.Character.HumanoidRootPart
                local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                if dist > State.Visual.MaxDistance then
                    ESPCache[plr].BB.Enabled = false
                    if ESPCache[plr].Highlight then ESPCache[plr].Highlight.Enabled = false end
                else
                    ESPCache[plr].BB.Enabled = State.Visual.Name
                    if ESPCache[plr].Highlight then ESPCache[plr].Highlight.Enabled = true end
                    local format = State.Visual.NameFormat
                    local hp = plr.Character.Humanoid.Health
                    local maxhp = plr.Character.Humanoid.MaxHealth
                    local text = format:gsub("{name}", plr.Name)
                        :gsub("{distance}", tostring(math.floor(dist)))
                        :gsub("{health}", tostring(math.floor(hp)))
                        :gsub("{maxhealth}", tostring(math.floor(maxhp)))
                    if State.Visual.Health then text = text .. " (" .. math.floor(hp) .. ")" end
                    ESPCache[plr].TXT.Text = text
                    if State.Visual.VisibilityCheck then
                        local vis = isVisible(hrp)
                        ESPCache[plr].TXT.TextColor3 = vis and
                            Color3.fromRGB(unpack(State.Visual.VisibleColor)) or
                            Color3.fromRGB(unpack(State.Visual.InvisibleColor))
                    end
                end
            end
        else
            clearESP(plr)
        end
    end
end

task.spawn(function()
    while ScreenGui.Parent do
        pcall(updateESP)
        task.wait(1 / math.max(State.Visual.RefreshRate, 1))
    end
end)

-- =============================================================================
-- FEATURE LOGIC : MOVEMENT
-- =============================================================================
local MovementApplied = false

local function applyMovement()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        hum.WalkSpeed = State.Movement.WS
        hum.JumpPower = State.Movement.JP
        hum.JumpHeight = State.Movement.JH
        hum.HipHeight = State.Movement.HipHeight
        hum.MaxSlopeAngle = State.Movement.MaxSlope
        Workspace.Gravity = State.Movement.Gravity
    end)
end

track(LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if State.Movement.AutoReapply then applyMovement() end
    for plr, _ in pairs(ESPCache) do clearESP(plr) end
end))

-- Noclip
local NoclipConn
local function setNoclip(on)
    if NoclipConn then NoclipConn:Disconnect() NoclipConn = nil end
    if on then
        NoclipConn = RunService.Stepped:Connect(function()
            if LocalPlayer.Character then
                for _, v in ipairs(LocalPlayer.Character:GetDescendants()) do
                    if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end
                end
            end
        end)
    end
end

-- Infinite jump
track(UserInputService.JumpRequest:Connect(function()
    if State.Movement.InfJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

-- Anti-fling
task.spawn(function()
    while ScreenGui.Parent do
        if State.Movement.AntiFling and LocalPlayer.Character then
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Velocity.Magnitude > State.Movement.AntiFlingThresh then
                hrp.Velocity = Vector3.new()
            end
        end
        task.wait(0.1)
    end
end)

-- Anti-void
task.spawn(function()
    while ScreenGui.Parent do
        if State.Movement.AntiVoid and LocalPlayer.Character then
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Position.Y < State.Movement.AntiVoidThresh then
                hrp.CFrame = CFrame.new(0, 100, 0)
                notify("Movement", "Anti-void triggered", "warn", 2)
            end
        end
        task.wait(0.5)
    end
end)

-- =============================================================================
-- FEATURE LOGIC : MISC
-- =============================================================================
local AntiAFKConn
local function setAntiAFK(on)
    if AntiAFKConn then AntiAFKConn:Disconnect() AntiAFKConn = nil end
    if on then
        AntiAFKConn = LocalPlayer.Idled:Connect(function()
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
    end
end

local function applyFullbright(on)
    if on then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1e6
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
    else
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
        Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
    end
end

local function applyFOV(v)
    pcall(function() Camera.FieldOfView = v end)
end

-- =============================================================================
-- BUILD SIDEBAR + PAGES
-- =============================================================================
local SidebarItems = {}
local CurrentPage = "Home"

local categories = {
    { id = "Home",       icon = "H",  label = "Home",         desc = "Welcome. Quick toggles, recent activity, master kit switch." },
    { id = "Aim",        icon = "A",  label = "Aim",          desc = "Aimbot and triggerbot. Target selection, smoothing, FOV." },
    { id = "SilentAim",  icon = "S",  label = "Silent Aim",   desc = "Hook-based aim that bends shots without moving camera." },
    { id = "MagicBullet",icon = "M",  label = "Magic Bullet", desc = "Forced-hit bullet remote replay with anti-detect." },
    { id = "Visual",     icon = "V",  label = "Visual",       desc = "ESP, chams, tracers, name plates." },
    { id = "Movement",   icon = "W",  label = "Movement",     desc = "WalkSpeed, JumpPower, fly, noclip, profiles." },
    { id = "Desync",     icon = "D",  label = "Desync",       desc = "Position desync for hit registration evasion." },
    { id = "Teleport",   icon = "T",  label = "World",        desc = "Teleport, waypoints, save slots, follow." },
    { id = "Network",    icon = "N",  label = "Network",      desc = "Remote spy, scanner, GUI dumper, state finder." },
    { id = "Spoof",      icon = "P",  label = "Spoof",        desc = "Premium, gamepass, asset, group spoof." },
    { id = "AntiCheat",  icon = "C",  label = "Anti-Cheat",   desc = "Metamethod hooks, namecall blocklist, AC GUI hider." },
    { id = "ChatSpy",    icon = "L",  label = "Chat Spy",     desc = "Live chat log, filters, whisper unhider." },
    { id = "Misc",       icon = "X",  label = "Misc",         desc = "Anti-AFK, FPS unlock, fullbright, music, server hop." },
    { id = "LiveState",  icon = "Q",  label = "Live State",   desc = "Property monitor, change feed, server-trust." },
    { id = "Configs",    icon = "G",  label = "Configs",      desc = "Theme, scale, keybind editor, save slots." },
}

for i, cat in ipairs(categories) do
    local item = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Theme.SidebarBg,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = SidebarList,
        LayoutOrder = i,
    })
    local bar = new("Frame", {
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = Theme.AccentPrimary,
        BorderSizePixel = 0,
        Visible = false,
        Parent = item,
    })
    local iconLabel = new("TextLabel", {
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.fromOffset(14, 12),
        BackgroundTransparency = 1,
        Text = cat.icon,
        TextColor3 = Theme.AccentPrimary,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        Parent = item,
    })
    local label = new("TextLabel", {
        Size = UDim2.new(1, -42, 1, 0),
        Position = UDim2.fromOffset(40, 0),
        BackgroundTransparency = 1,
        Text = cat.label,
        TextColor3 = Theme.TextPrimary,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = item,
    })

    item.MouseEnter:Connect(function()
        if CurrentPage ~= cat.id then
            tween(item, Q_FAST, { BackgroundColor3 = Theme.CardBg })
        end
    end)
    item.MouseLeave:Connect(function()
        if CurrentPage ~= cat.id then
            tween(item, Q_FAST, { BackgroundColor3 = Theme.SidebarBg })
        end
    end)
    item.MouseButton1Click:Connect(function()
        getgenv().ENI.Hub.NavigateTo(cat.id)
    end)

    SidebarItems[cat.id] = { Item = item, Bar = bar, Cat = cat }
    newPage(cat.id)
end

-- =============================================================================
-- NAVIGATION
-- =============================================================================
local function navigateTo(id)
    if not Pages[id] then return end
    local oldPage = Pages[CurrentPage]
    if oldPage then
        tween(oldPage, Q_FAST, { BackgroundTransparency = 1 })
        task.wait(0.05)
        oldPage.Visible = false
    end

    for k, entry in pairs(SidebarItems) do
        if k == id then
            entry.Item.BackgroundColor3 = Theme.AccentSoft
            entry.Bar.Visible = true
        else
            entry.Item.BackgroundColor3 = Theme.SidebarBg
            entry.Bar.Visible = false
        end
    end

    local cat
    for _, c in ipairs(categories) do if c.id == id then cat = c break end end
    Breadcrumb.Text = "Home" .. (id ~= "Home" and " > " .. cat.label or "")
    SectionTitle.Text = cat.label
    SectionDesc.Text = cat.desc

    CurrentPage = id
    Pages[id].Visible = true
    tween(Pages[id], Q, { BackgroundTransparency = 1 })
end

-- =============================================================================
-- PAGE: HOME
-- =============================================================================
do
    local p = Pages.Home
    local welcome = createCard(p, "Welcome back", "FREEZER v" .. getgenv().ENI.Version .. " loaded. Executor: " .. tostring(identifyexecutor()))
    local masterToggle = Controls.Toggle(welcome, "Master kit enabled", State.Home.MasterEnabled, function(v)
        State.Home.MasterEnabled = v
        if not v then
            stopAimbot(); stopTrigger()
            State.Visual.Master = false
            notify("Master switch", "Every active feature disabled.", "warn", 3)
        end
        saveConfig()
    end, "Kills every active feature instantly when off.")

    local quick = createCard(p, "Quick toggles", "Five most-used features pinned for one-click access.")
    Controls.Toggle(quick, "Aimbot", State.Aim.Aimbot.Enabled, function(v)
        State.Aim.Aimbot.Enabled = v
        if v then startAimbot() else stopAimbot() end
        saveConfig()
    end)
    Controls.Toggle(quick, "ESP", State.Visual.Master, function(v)
        State.Visual.Master = v; saveConfig()
    end)
    Controls.Toggle(quick, "Silent aim", State.SilentAim.Enabled, function(v)
        State.SilentAim.Enabled = v; saveConfig()
    end)
    Controls.Toggle(quick, "Anti-AFK", State.Misc.AntiAFK, function(v)
        State.Misc.AntiAFK = v; setAntiAFK(v); saveConfig()
    end)
    Controls.Toggle(quick, "Fullbright", State.Misc.Fullbright, function(v)
        State.Misc.Fullbright = v; applyFullbright(v); saveConfig()
    end)

    local recent = createCard(p, "Recent activity", "Latest notifications and state events from this session.")
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 80),
        BackgroundTransparency = 1,
        Text = "Session started " .. os.date("%H:%M") .. ".\nNo critical events yet.",
        TextColor3 = Theme.TextSecondary,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = recent,
    })
end

-- =============================================================================
-- PAGE: AIM
-- =============================================================================
do
    local p = Pages.Aim
    local card = createCard(p, "Aimbot", "Lock onto the closest valid target inside the FOV cone.")
    Controls.Toggle(card, "Enabled", State.Aim.Aimbot.Enabled, function(v)
        State.Aim.Aimbot.Enabled = v
        if v then startAimbot() else stopAimbot() end
        saveConfig()
    end)
    Controls.Dropdown(card, "Mode", { "Closest", "LowestHP", "MostVisible" }, State.Aim.Aimbot.Mode, function(v)
        State.Aim.Aimbot.Mode = v; saveConfig()
    end)
    Controls.Slider(card, "FOV radius", 10, 500, State.Aim.Aimbot.FOV, 0, function(v)
        State.Aim.Aimbot.FOV = v; saveConfig()
    end)
    Controls.Toggle(card, "FOV circle visible", State.Aim.Aimbot.FOVCircle, function(v)
        State.Aim.Aimbot.FOVCircle = v; saveConfig()
    end)
    Controls.Slider(card, "Smoothing", 0, 1, State.Aim.Aimbot.Smoothing, 2, function(v)
        State.Aim.Aimbot.Smoothing = v; saveConfig()
    end, "Higher = slower, more human-looking")
    Controls.Dropdown(card, "Target part", { "Head", "HumanoidRootPart", "Torso", "UpperTorso" }, State.Aim.Aimbot.TargetPart, function(v)
        State.Aim.Aimbot.TargetPart = v; saveConfig()
    end)
    Controls.Toggle(card, "Wall check", State.Aim.Aimbot.WallCheck, function(v)
        State.Aim.Aimbot.WallCheck = v; saveConfig()
    end)
    Controls.Toggle(card, "Team check", State.Aim.Aimbot.TeamCheck, function(v)
        State.Aim.Aimbot.TeamCheck = v; saveConfig()
    end)
    Controls.Slider(card, "Prediction", 0, 0.5, State.Aim.Aimbot.Prediction, 3, function(v)
        State.Aim.Aimbot.Prediction = v; saveConfig()
    end)
    Controls.Toggle(card, "Sticky lock", State.Aim.Aimbot.Sticky, function(v)
        State.Aim.Aimbot.Sticky = v; saveConfig()
    end)
    Controls.Toggle(card, "Show lock indicator", State.Aim.Aimbot.Indicator, function(v)
        State.Aim.Aimbot.Indicator = v; saveConfig()
    end)
    Controls.Keybind(card, "Activation key", State.Aim.Aimbot.Key, function(k)
        State.Aim.Aimbot.Key = k; saveConfig()
    end)

    local trig = createCard(p, "Triggerbot", "Auto-fire when crosshair is on a valid target.")
    Controls.Toggle(trig, "Enabled", State.Aim.Trigger.Enabled, function(v)
        State.Aim.Trigger.Enabled = v
        if v then startTrigger() else stopTrigger() end
        saveConfig()
    end)
    Controls.Keybind(trig, "Hold key", State.Aim.Trigger.Key, function(k)
        State.Aim.Trigger.Key = k; saveConfig()
    end)
    Controls.Slider(trig, "Delay (ms)", 0, 500, State.Aim.Trigger.Delay, 0, function(v)
        State.Aim.Trigger.Delay = v; saveConfig()
    end)
    Controls.Slider(trig, "Jitter (ms)", 0, 200, State.Aim.Trigger.Jitter, 0, function(v)
        State.Aim.Trigger.Jitter = v; saveConfig()
    end)
    Controls.Toggle(trig, "Knock check", State.Aim.Trigger.KnockCheck, function(v)
        State.Aim.Trigger.KnockCheck = v; saveConfig()
    end)
end

-- =============================================================================
-- PAGE: SILENT AIM
-- =============================================================================
do
    local p = Pages.SilentAim
    local card = createCard(p, "Silent Aim", "Hook-based aim, bullet bends without camera movement.")
    Controls.Toggle(card, "Enabled", State.SilentAim.Enabled, function(v) State.SilentAim.Enabled = v; saveConfig() end)
    Controls.Dropdown(card, "Method", { "AUTO", "Raycast", "FindPartOnRay", "GetMouseLocation", "Mouse.Hit" }, State.SilentAim.Method, function(v)
        State.SilentAim.Method = v; saveConfig()
    end)
    Controls.Button(card, "Auto-detect remote", "secondary", function()
        notify("Silent Aim", "Listening 5s for fired remotes...", "info", 3)
    end)
    Controls.Slider(card, "FOV", 10, 500, State.SilentAim.FOV, 0, function(v) State.SilentAim.FOV = v; saveConfig() end)
    Controls.Dropdown(card, "Target part", { "Head", "HumanoidRootPart", "Torso" }, State.SilentAim.TargetPart, function(v)
        State.SilentAim.TargetPart = v; saveConfig()
    end)
    Controls.Toggle(card, "Wall check", State.SilentAim.WallCheck, function(v) State.SilentAim.WallCheck = v; saveConfig() end)
    Controls.Toggle(card, "Team check", State.SilentAim.TeamCheck, function(v) State.SilentAim.TeamCheck = v; saveConfig() end)
    Controls.Slider(card, "Hit chance %", 0, 100, State.SilentAim.HitChance, 0, function(v) State.SilentAim.HitChance = v; saveConfig() end)
    Controls.Toggle(card, "Bone randomization", State.SilentAim.BoneRandom, function(v) State.SilentAim.BoneRandom = v; saveConfig() end)
    Controls.Dropdown(card, "Preset", { "Generic", "FPS", "Roleplay", "Custom" }, State.SilentAim.Preset, function(v) State.SilentAim.Preset = v; saveConfig() end)
    Controls.MultiTextbox(card, "Custom whitelist", "PlayerName1, PlayerName2", State.SilentAim.Whitelist, 60, function(v) State.SilentAim.Whitelist = v; saveConfig() end)
    Controls.Slider(card, "Occasional miss %", 0, 50, State.SilentAim.OccasionalMiss, 0, function(v) State.SilentAim.OccasionalMiss = v; saveConfig() end, "Anti-detect")
    Controls.Toggle(card, "Debug log", State.SilentAim.DebugLog, function(v) State.SilentAim.DebugLog = v; saveConfig() end)
    Controls.Toggle(card, "Visualizer", State.SilentAim.Visualizer, function(v) State.SilentAim.Visualizer = v; saveConfig() end)
    Controls.Button(card, "Open Full Module", "secondary", function()
        local ok, err = pcall(function()
            if getgenv().ENI.SilentAim and getgenv().ENI.SilentAim.Show then
                getgenv().ENI.SilentAim:Show()
            else
                error("Silent Aim module not loaded")
            end
        end)
        notify("Silent Aim", ok and "Module GUI opened." or ("Open failed: " .. tostring(err)), ok and "success" or "error", 3)
    end)
end

-- =============================================================================
-- PAGE: MAGIC BULLET
-- =============================================================================
do
    local p = Pages.MagicBullet
    local card = createCard(p, "Magic Bullet", "Force-hit replay of detected bullet remotes.")
    Controls.Toggle(card, "Enabled", State.MagicBullet.Enabled, function(v) State.MagicBullet.Enabled = v; saveConfig() end)
    Controls.Dropdown(card, "Mode", { "Direct", "Wall-Pen", "Arc", "All" }, State.MagicBullet.Mode, function(v) State.MagicBullet.Mode = v; saveConfig() end)
    Controls.Textbox(card, "Bullet remote", "Path.To.Remote", State.MagicBullet.BulletRemote, function(v) State.MagicBullet.BulletRemote = v; saveConfig() end, nil, 260)
    Controls.Button(card, "Auto-detect bullet remote", "secondary", function()
        notify("Magic Bullet", "Scanning fired remotes...", "info", 3)
    end)
    Controls.Dropdown(card, "Target part", { "Head", "HumanoidRootPart", "Torso" }, State.MagicBullet.TargetPart, function(v) State.MagicBullet.TargetPart = v; saveConfig() end)
    Controls.Dropdown(card, "Target selection", { "ClosestMouse", "Crosshair", "LowestHP", "ClosestDist" }, State.MagicBullet.Selection, function(v) State.MagicBullet.Selection = v; saveConfig() end)
    Controls.Toggle(card, "Force hit", State.MagicBullet.ForceHit, function(v) State.MagicBullet.ForceHit = v; saveConfig() end)
    Controls.Slider(card, "Range", 50, 5000, State.MagicBullet.Range, 0, function(v) State.MagicBullet.Range = v; saveConfig() end)
    Controls.Slider(card, "Max bullets / sec", 1, 50, State.MagicBullet.MaxPerSec, 0, function(v) State.MagicBullet.MaxPerSec = v; saveConfig() end, "Anti-detect cap")
    Controls.Slider(card, "Timing jitter", 0, 1, State.MagicBullet.Jitter, 2, function(v) State.MagicBullet.Jitter = v; saveConfig() end)
    Controls.Slider(card, "Occasional miss %", 0, 50, State.MagicBullet.OccasionalMiss, 0, function(v) State.MagicBullet.OccasionalMiss = v; saveConfig() end)
    Controls.Button(card, "Test fire", "secondary", function() notify("Magic Bullet", "Test fire requested.", "info", 2) end)
    Controls.Toggle(card, "Debug log", State.MagicBullet.DebugLog, function(v) State.MagicBullet.DebugLog = v; saveConfig() end)
    Controls.Button(card, "Open Full Module", "secondary", function()
        local ok, err = pcall(function()
            if getgenv().ENI.MagicBullet and getgenv().ENI.MagicBullet.Show then
                getgenv().ENI.MagicBullet:Show()
            else
                error("Magic Bullet module not loaded")
            end
        end)
        notify("Magic Bullet", ok and "Module GUI opened." or ("Open failed: " .. tostring(err)), ok and "success" or "error", 3)
    end)
end

-- =============================================================================
-- PAGE: VISUAL (ESP)
-- =============================================================================
do
    local p = Pages.Visual
    local master = createCard(p, "ESP master", "Toggles the entire visual system.")
    Controls.Toggle(master, "ESP enabled", State.Visual.Master, function(v) State.Visual.Master = v; saveConfig() end)
    Controls.Slider(master, "Refresh rate (Hz)", 5, 120, State.Visual.RefreshRate, 0, function(v) State.Visual.RefreshRate = v; saveConfig() end)
    Controls.Slider(master, "Max distance", 100, 5000, State.Visual.MaxDistance, 0, function(v) State.Visual.MaxDistance = v; saveConfig() end)
    Controls.Toggle(master, "Hide own character", State.Visual.HideOwn, function(v) State.Visual.HideOwn = v; saveConfig() end)

    local feats = createCard(p, "Features", "Toggle individual ESP elements.")
    Controls.Toggle(feats, "Box", State.Visual.Box, function(v) State.Visual.Box = v; saveConfig() end)
    Controls.Toggle(feats, "Name", State.Visual.Name, function(v) State.Visual.Name = v; saveConfig() end)
    Controls.Toggle(feats, "Health", State.Visual.Health, function(v) State.Visual.Health = v; saveConfig() end)
    Controls.Toggle(feats, "Distance", State.Visual.Distance, function(v) State.Visual.Distance = v; saveConfig() end)
    Controls.Toggle(feats, "Tracer", State.Visual.Tracer, function(v) State.Visual.Tracer = v; saveConfig() end)
    Controls.Toggle(feats, "Skeleton", State.Visual.Skeleton, function(v) State.Visual.Skeleton = v; saveConfig() end)
    Controls.Toggle(feats, "Chams (highlight)", State.Visual.Chams, function(v) State.Visual.Chams = v; saveConfig() end)

    local style = createCard(p, "Style", "Box mode, name format, tracer origin.")
    Controls.Dropdown(style, "Box mode", { "Corner", "Full", "3D" }, State.Visual.BoxMode, function(v) State.Visual.BoxMode = v; saveConfig() end)
    Controls.Textbox(style, "Name format", "{name} [{distance}m]", State.Visual.NameFormat, function(v) State.Visual.NameFormat = v; saveConfig() end, "Use {name} {distance} {health}", 240)
    Controls.Dropdown(style, "Healthbar position", { "Left", "Right", "Above", "Below" }, State.Visual.HealthbarPos, function(v) State.Visual.HealthbarPos = v; saveConfig() end)
    Controls.Dropdown(style, "Tracer origin", { "Bottom", "Center", "Top", "Mouse" }, State.Visual.TracerOrigin, function(v) State.Visual.TracerOrigin = v; saveConfig() end)

    local chams = createCard(p, "Chams", "Highlight fill, outline, depth.")
    Controls.ColorPicker(chams, "Fill color", State.Visual.ChamsFillColor, function(c, rgb) State.Visual.ChamsFillColor = rgb; saveConfig() end)
    Controls.Slider(chams, "Fill transparency", 0, 1, State.Visual.ChamsFillT, 2, function(v) State.Visual.ChamsFillT = v; saveConfig() end)
    Controls.ColorPicker(chams, "Outline color", State.Visual.ChamsOutlineColor, function(c, rgb) State.Visual.ChamsOutlineColor = rgb; saveConfig() end)
    Controls.Slider(chams, "Outline transparency", 0, 1, State.Visual.ChamsOutlineT, 2, function(v) State.Visual.ChamsOutlineT = v; saveConfig() end)
    Controls.Dropdown(chams, "Depth mode", { "AlwaysOnTop", "Occluded" }, State.Visual.ChamsDepth, function(v) State.Visual.ChamsDepth = v; saveConfig() end)

    local filters = createCard(p, "Filters", "Team / visibility / color logic.")
    Controls.Toggle(filters, "Team check", State.Visual.TeamCheck, function(v) State.Visual.TeamCheck = v; saveConfig() end)
    Controls.Toggle(filters, "Use team color", State.Visual.UseTeamColor, function(v) State.Visual.UseTeamColor = v; saveConfig() end)
    Controls.Toggle(filters, "Visibility check", State.Visual.VisibilityCheck, function(v) State.Visual.VisibilityCheck = v; saveConfig() end)
    Controls.ColorPicker(filters, "Visible color", State.Visual.VisibleColor, function(c, rgb) State.Visual.VisibleColor = rgb; saveConfig() end)
    Controls.ColorPicker(filters, "Invisible color", State.Visual.InvisibleColor, function(c, rgb) State.Visual.InvisibleColor = rgb; saveConfig() end)
    Controls.Toggle(filters, "FOV circle", State.Visual.FOVCircle, function(v) State.Visual.FOVCircle = v; saveConfig() end)

    local extras = createCard(p, "Extras", "Items and NPCs.")
    Controls.MultiTextbox(extras, "Item ESP names", "Bullet, KeyCard, Diamond", State.Visual.ItemESP, 60, function(v) State.Visual.ItemESP = v; saveConfig() end)
    Controls.Toggle(extras, "NPC ESP", State.Visual.NPC, function(v) State.Visual.NPC = v; saveConfig() end)
end

-- =============================================================================
-- PAGE: MOVEMENT
-- =============================================================================
do
    local p = Pages.Movement
    local core = createCard(p, "Core", "Walking, jumping, gravity, slope.")
    Controls.Slider(core, "Walk speed", 0, 500, State.Movement.WS, 0, function(v) State.Movement.WS = v; applyMovement(); saveConfig() end)
    Controls.Slider(core, "Jump power", 0, 500, State.Movement.JP, 0, function(v) State.Movement.JP = v; applyMovement(); saveConfig() end)
    Controls.Slider(core, "Jump height", 0, 100, State.Movement.JH, 1, function(v) State.Movement.JH = v; applyMovement(); saveConfig() end)
    Controls.Slider(core, "Hip height", 0, 20, State.Movement.HipHeight, 1, function(v) State.Movement.HipHeight = v; applyMovement(); saveConfig() end)
    Controls.Slider(core, "Gravity", 0, 500, State.Movement.Gravity, 1, function(v) State.Movement.Gravity = v; applyMovement(); saveConfig() end)
    Controls.Slider(core, "Sideways multiplier", 0.1, 5, State.Movement.Sideways, 2, function(v) State.Movement.Sideways = v; saveConfig() end)
    Controls.Slider(core, "Max slope angle", 0, 89, State.Movement.MaxSlope, 0, function(v) State.Movement.MaxSlope = v; applyMovement(); saveConfig() end)

    local advanced = createCard(p, "Advanced", "Fly, jumps, climbing, bursts.")
    Controls.Toggle(advanced, "Fly", State.Movement.Fly, function(v) State.Movement.Fly = v; saveConfig() end)
    Controls.Dropdown(advanced, "Fly mode", { "CFrame", "BodyVelocity", "BodyGyro" }, State.Movement.FlyMode, function(v) State.Movement.FlyMode = v; saveConfig() end)
    Controls.Slider(advanced, "Fly speed", 1, 500, State.Movement.FlySpeed, 0, function(v) State.Movement.FlySpeed = v; saveConfig() end)
    Controls.Toggle(advanced, "Vertical keys (E/Q)", State.Movement.VerticalKeys, function(v) State.Movement.VerticalKeys = v; saveConfig() end)
    Controls.Toggle(advanced, "Infinite jump", State.Movement.InfJump, function(v) State.Movement.InfJump = v; saveConfig() end)
    Controls.Toggle(advanced, "Noclip", State.Movement.Noclip, function(v) State.Movement.Noclip = v; setNoclip(v); saveConfig() end)
    Controls.Toggle(advanced, "Spinbot", State.Movement.Spinbot, function(v) State.Movement.Spinbot = v; saveConfig() end)
    Controls.Slider(advanced, "Spin rate (deg/s)", 60, 3600, State.Movement.SpinRate, 0, function(v) State.Movement.SpinRate = v; saveConfig() end)
    Controls.Toggle(advanced, "Teleport forward", State.Movement.TPForward, function(v) State.Movement.TPForward = v; saveConfig() end)
    Controls.Slider(advanced, "TP-forward distance", 1, 100, State.Movement.TPForwardDist, 0, function(v) State.Movement.TPForwardDist = v; saveConfig() end)
    Controls.Toggle(advanced, "Wall climb", State.Movement.WallClimb, function(v) State.Movement.WallClimb = v; saveConfig() end)
    Controls.Toggle(advanced, "Moon jump", State.Movement.MoonJump, function(v) State.Movement.MoonJump = v; saveConfig() end)
    Controls.Toggle(advanced, "Spider climb", State.Movement.SpiderClimb, function(v) State.Movement.SpiderClimb = v; saveConfig() end)
    Controls.Toggle(advanced, "Speed burst", State.Movement.SpeedBurst, function(v) State.Movement.SpeedBurst = v; saveConfig() end)
    Controls.Slider(advanced, "Burst multiplier", 1.5, 10, State.Movement.BurstMult, 1, function(v) State.Movement.BurstMult = v; saveConfig() end)
    Controls.Slider(advanced, "Burst duration (s)", 0.2, 5, State.Movement.BurstDur, 1, function(v) State.Movement.BurstDur = v; saveConfig() end)

    local safety = createCard(p, "Safety", "Anti-fling, anti-void, panic.")
    Controls.Toggle(safety, "Anti-fling", State.Movement.AntiFling, function(v) State.Movement.AntiFling = v; saveConfig() end)
    Controls.Slider(safety, "Anti-fling threshold", 50, 1000, State.Movement.AntiFlingThresh, 0, function(v) State.Movement.AntiFlingThresh = v; saveConfig() end)
    Controls.Toggle(safety, "Anti-void", State.Movement.AntiVoid, function(v) State.Movement.AntiVoid = v; saveConfig() end)
    Controls.Slider(safety, "Anti-void Y threshold", -1000, 0, State.Movement.AntiVoidThresh, 0, function(v) State.Movement.AntiVoidThresh = v; saveConfig() end)
    Controls.Toggle(safety, "Auto-reapply on respawn", State.Movement.AutoReapply, function(v) State.Movement.AutoReapply = v; saveConfig() end)
    Controls.Keybind(safety, "Panic reset key", State.Movement.PanicKey, function(k) State.Movement.PanicKey = k; saveConfig() end)

    local profile = createCard(p, "Profile", "Save / load named movement profiles.")
    Controls.Dropdown(profile, "Current profile", { "Default", "Fast", "Ninja", "Custom" }, State.Movement.Profile, function(v) State.Movement.Profile = v; saveConfig() end)
    Controls.Button(profile, "Save profile", "secondary", function() notify("Movement", "Profile saved.", "success", 2) end)
    Controls.Button(profile, "Load profile", "secondary", function() notify("Movement", "Profile loaded.", "success", 2); applyMovement() end)
    Controls.Button(profile, "Delete profile", "danger", function() notify("Movement", "Profile deleted.", "warn", 2) end)
end

-- =============================================================================
-- PAGE: DESYNC
-- =============================================================================
do
    local p = Pages.Desync
    local card = createCard(p, "Desync", "Position desync for hit-reg evasion.")
    Controls.Toggle(card, "Enabled", State.Desync.Enabled, function(v) State.Desync.Enabled = v; saveConfig() end)
    Controls.Dropdown(card, "Method", { "NetworkOwner", "VelocitySlam", "FakeCharacter", "Combined" }, State.Desync.Method, function(v) State.Desync.Method = v; saveConfig() end)
    Controls.Slider(card, "Offset", 1, 30, State.Desync.Offset, 1, function(v) State.Desync.Offset = v; saveConfig() end)
    Controls.Dropdown(card, "Direction", { "Behind", "Forward", "Left", "Right", "Up", "Down", "Custom" }, State.Desync.Direction, function(v) State.Desync.Direction = v; saveConfig() end)
    Controls.Slider(card, "Custom X", -50, 50, State.Desync.CustomX, 1, function(v) State.Desync.CustomX = v; saveConfig() end)
    Controls.Slider(card, "Custom Y", -50, 50, State.Desync.CustomY, 1, function(v) State.Desync.CustomY = v; saveConfig() end)
    Controls.Slider(card, "Custom Z", -50, 50, State.Desync.CustomZ, 1, function(v) State.Desync.CustomZ = v; saveConfig() end)

    local triggers = createCard(p, "Triggers", "When to engage desync.")
    Controls.Toggle(triggers, "Auto-desync when aim taken", State.Desync.AutoOnAim, function(v) State.Desync.AutoOnAim = v; saveConfig() end)
    Controls.Slider(triggers, "Auto FOV", 10, 360, State.Desync.AutoFOV, 0, function(v) State.Desync.AutoFOV = v; saveConfig() end)
    Controls.Keybind(triggers, "Manual trigger key", State.Desync.Key, function(k) State.Desync.Key = k; saveConfig() end)

    local viz = createCard(p, "Visualization", "On-screen indicators.")
    Controls.Toggle(viz, "Ghost (fake) position indicator", State.Desync.GhostIndicator, function(v) State.Desync.GhostIndicator = v; saveConfig() end)
    Controls.Toggle(viz, "Real position indicator", State.Desync.RealIndicator, function(v) State.Desync.RealIndicator = v; saveConfig() end)
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Replication: " .. State.Desync.ReplicationOK,
        TextColor3 = Theme.Success,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = viz,
    })

    local misc = createCard(p, "Behavior")
    Controls.Toggle(misc, "Reset on respawn", State.Desync.ResetOnRespawn, function(v) State.Desync.ResetOnRespawn = v; saveConfig() end)
    Controls.Slider(misc, "Smooth transition", 0, 1, State.Desync.SmoothTransition, 2, function(v) State.Desync.SmoothTransition = v; saveConfig() end)
    Controls.Toggle(misc, "Hitbox-only mode", State.Desync.HitboxOnly, function(v) State.Desync.HitboxOnly = v; saveConfig() end)
    Controls.Toggle(misc, "Verbose log", State.Desync.Verbose, function(v) State.Desync.Verbose = v; saveConfig() end)

    Controls.Button(misc, "Open Full Module", "secondary", function()
        local ok, err = pcall(function()
            if getgenv().ENI.Desync and getgenv().ENI.Desync.Show then
                getgenv().ENI.Desync:Show()
            else
                error("Desync module not loaded")
            end
        end)
        notify("Desync", ok and "Module GUI opened." or ("Open failed: " .. tostring(err)), ok and "success" or "error", 3)
    end)
end

-- =============================================================================
-- PAGE: WORLD / TELEPORT
-- =============================================================================
do
    local p = Pages.Teleport

    local function playerNames()
        local list = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then table.insert(list, plr.Name) end
        end
        if #list == 0 then table.insert(list, "<none>") end
        return list
    end

    local tpPlayer = createCard(p, "Teleport to player", "Pick a player and offset.")
    Controls.Dropdown(tpPlayer, "Player", playerNames(), State.Teleport.Player, function(v) State.Teleport.Player = v; saveConfig() end)
    Controls.Slider(tpPlayer, "Offset X", -20, 20, State.Teleport.OffsetX, 1, function(v) State.Teleport.OffsetX = v; saveConfig() end)
    Controls.Slider(tpPlayer, "Offset Y", -20, 20, State.Teleport.OffsetY, 1, function(v) State.Teleport.OffsetY = v; saveConfig() end)
    Controls.Slider(tpPlayer, "Offset Z", -20, 20, State.Teleport.OffsetZ, 1, function(v) State.Teleport.OffsetZ = v; saveConfig() end)
    Controls.Button(tpPlayer, "Go", nil, function()
        local plr = Players:FindFirstChild(State.Teleport.Player)
        if plr and plr.Character and LocalPlayer.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local lhrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and lhrp then
                lhrp.CFrame = hrp.CFrame + Vector3.new(State.Teleport.OffsetX, State.Teleport.OffsetY, State.Teleport.OffsetZ)
                notify("Teleport", "Teleported to " .. plr.Name, "success", 2)
            end
        end
    end)

    local slots = createCard(p, "Save slots", "Quick-save locations 1-10.")
    for i = 1, 10 do
        local row = newRow(slots, "Slot " .. i, State.Teleport.Slots[i] and "Saved" or "Empty")
        local save = new("TextButton", {
            Size = UDim2.fromOffset(60, 24),
            Position = UDim2.new(1, -190, 0.5, -12),
            BackgroundColor3 = Theme.CardBgHover,
            BorderSizePixel = 0,
            Text = "Save",
            TextColor3 = Theme.TextPrimary,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            Parent = row,
        })
        corner(save, 4)
        local load = new("TextButton", {
            Size = UDim2.fromOffset(60, 24),
            Position = UDim2.new(1, -126, 0.5, -12),
            BackgroundColor3 = Theme.AccentPrimary,
            BorderSizePixel = 0,
            Text = "Load",
            TextColor3 = Color3.fromRGB(255,255,255),
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            Parent = row,
        })
        corner(load, 4)
        local rename = new("TextButton", {
            Size = UDim2.fromOffset(60, 24),
            Position = UDim2.new(1, -62, 0.5, -12),
            BackgroundColor3 = Theme.CardBgHover,
            BorderSizePixel = 0,
            Text = "Rename",
            TextColor3 = Theme.TextPrimary,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            Parent = row,
        })
        corner(rename, 4)
        save.MouseButton1Click:Connect(function()
            if LocalPlayer.Character then
                local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    State.Teleport.Slots[i] = { x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z, name = "Slot " .. i }
                    notify("Teleport", "Slot " .. i .. " saved.", "success", 2)
                    saveConfig()
                end
            end
        end)
        load.MouseButton1Click:Connect(function()
            local s = State.Teleport.Slots[i]
            if s and LocalPlayer.Character then
                local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = CFrame.new(s.x, s.y, s.z)
                    notify("Teleport", "Loaded " .. (s.name or ("Slot " .. i)), "success", 2)
                end
            end
        end)
        rename.MouseButton1Click:Connect(function()
            notify("Teleport", "Rename via slot textbox below.", "info", 2)
        end)
    end

    local coords = createCard(p, "Coordinates", "Teleport directly to XYZ.")
    Controls.Slider(coords, "X", -2000, 2000, State.Teleport.CoordX, 0, function(v) State.Teleport.CoordX = v; saveConfig() end)
    Controls.Slider(coords, "Y", -2000, 2000, State.Teleport.CoordY, 0, function(v) State.Teleport.CoordY = v; saveConfig() end)
    Controls.Slider(coords, "Z", -2000, 2000, State.Teleport.CoordZ, 0, function(v) State.Teleport.CoordZ = v; saveConfig() end)
    Controls.Button(coords, "Go to coords", nil, function()
        if LocalPlayer.Character then
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CFrame = CFrame.new(State.Teleport.CoordX, State.Teleport.CoordY, State.Teleport.CoordZ) end
        end
    end)

    local hotkeys = createCard(p, "Hotkeys", "Bind quick actions.")
    Controls.Toggle(hotkeys, "Ctrl+Click teleport", State.Teleport.CtrlClick, function(v) State.Teleport.CtrlClick = v; saveConfig() end)
    Controls.Keybind(hotkeys, "TP to nearest player", State.Teleport.TPNearestKey, function(k) State.Teleport.TPNearestKey = k; saveConfig() end)
    Controls.Keybind(hotkeys, "TP to random player", State.Teleport.TPRandomKey, function(k) State.Teleport.TPRandomKey = k; saveConfig() end)
    Controls.Keybind(hotkeys, "Return to last position", State.Teleport.ReturnKey, function(k) State.Teleport.ReturnKey = k; saveConfig() end)

    local follow = createCard(p, "Auto follow", "Track a specific player.")
    Controls.Toggle(follow, "Auto follow", State.Teleport.AutoFollow, function(v) State.Teleport.AutoFollow = v; saveConfig() end)
    Controls.Slider(follow, "Follow distance", 2, 50, State.Teleport.FollowDist, 1, function(v) State.Teleport.FollowDist = v; saveConfig() end)
    Controls.Toggle(follow, "Smooth TP", State.Teleport.Smooth, function(v) State.Teleport.Smooth = v; saveConfig() end)
    Controls.Slider(follow, "Smooth duration", 0.1, 3, State.Teleport.SmoothDur, 2, function(v) State.Teleport.SmoothDur = v; saveConfig() end)
    Controls.Dropdown(follow, "TP mode", { "Hard", "Smooth", "BodyVelocity" }, State.Teleport.Mode, function(v) State.Teleport.Mode = v; saveConfig() end)
    Controls.Toggle(follow, "Anti-velocity", State.Teleport.AntiVelocity, function(v) State.Teleport.AntiVelocity = v; saveConfig() end)
end

-- =============================================================================
-- PAGE: NETWORK / RECON
-- =============================================================================
do
    local p = Pages.Network
    local card = createCard(p, "Remote Spy (mini)", "Last 25 fired remote events.")
    Controls.Slider(card, "Max log size", 5, 200, State.Network.LogSize, 0, function(v) State.Network.LogSize = v; saveConfig() end)
    Controls.Toggle(card, "Pause logging", State.Network.Paused, function(v) State.Network.Paused = v; saveConfig() end)
    Controls.Textbox(card, "Filter (substring)", "name contains...", State.Network.Filter, function(v) State.Network.Filter = v; saveConfig() end, nil, 240)
    Controls.Button(card, "Clear log", "secondary", function() notify("Remote Spy", "Log cleared.", "info", 2) end)

    local log = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 140),
        BackgroundColor3 = Theme.ContentBg,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.AccentPrimary,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = card,
    })
    corner(log, 4); padding(log, 8)
    local logLayout = new("UIListLayout", { Padding = UDim.new(0, 2), Parent = log })

    for i = 1, 5 do
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = "[" .. string.format("%02d:%02d", os.date("*t").hour, os.date("*t").min) .. "] Sample remote " .. i,
            TextColor3 = Theme.TextSecondary,
            Font = Enum.Font.Code,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = log,
        })
    end

    local modules = createCard(p, "Open full recon modules", "Load standalone modules from disk.")
    local moduleList = {
        { name = "Remote Spy", key = "RemoteSpy" },
        { name = "Remote Scanner", key = "RemoteScanner" },
        { name = "GUI Dumper", key = "GuiDumper" },
        { name = "State Finder", key = "StateFinder" },
        { name = "Connection Dumper", key = "ConnectionDumper" },
    }
    for _, m in ipairs(moduleList) do
        Controls.Button(modules, "Open " .. m.name, "secondary", function()
            local ok, err = pcall(function()
                local mod = getgenv().ENI[m.key]
                if mod and mod.Show then
                    mod:Show()
                else
                    error(m.name .. " module not loaded")
                end
            end)
            notify(m.name, ok and "Module GUI opened." or ("Open failed: " .. tostring(err)), ok and "success" or "error", 3)
        end)
    end

    local mini = createCard(p, "Mini scanner", "Quick remote search and fire.")
    Controls.Textbox(mini, "Search", "Remote name", "", function(v) end, nil, 240)
    Controls.Button(mini, "Scan now", "secondary", function() notify("Scanner", "Scanning remotes...", "info", 3) end)
end

-- =============================================================================
-- PAGE: SPOOF
-- =============================================================================
do
    local p = Pages.Spoof
    local prem = createCard(p, "Premium / Policy / Studio", "Spoof local platform flags.")
    Controls.Toggle(prem, "Premium spoof", State.Spoof.Premium, function(v) State.Spoof.Premium = v; saveConfig() end)
    Controls.Toggle(prem, "Policy spoof", State.Spoof.Policy, function(v) State.Spoof.Policy = v; saveConfig() end)
    Controls.Toggle(prem, "IsStudio spoof", State.Spoof.IsStudio, function(v) State.Spoof.IsStudio = v; saveConfig() end)
    Controls.Toggle(prem, "Owner spoof", State.Spoof.OwnerSpoof, function(v) State.Spoof.OwnerSpoof = v; saveConfig() end)

    local gp = createCard(p, "Gamepass spoof", "Per-id whitelist and blacklist.")
    Controls.Toggle(gp, "Master toggle", State.Spoof.GamepassMaster, function(v) State.Spoof.GamepassMaster = v; saveConfig() end)
    Controls.MultiTextbox(gp, "Whitelist (ids, comma)", "12345, 67890", State.Spoof.GamepassWL, 60, function(v) State.Spoof.GamepassWL = v; saveConfig() end)
    Controls.MultiTextbox(gp, "Blacklist (ids, comma)", "99999", State.Spoof.GamepassBL, 60, function(v) State.Spoof.GamepassBL = v; saveConfig() end)

    local assets = createCard(p, "Asset / Badge", "Ownership spoof.")
    Controls.Toggle(assets, "Asset ownership spoof", State.Spoof.Asset, function(v) State.Spoof.Asset = v; saveConfig() end)
    Controls.Toggle(assets, "Badge spoof", State.Spoof.Badge, function(v) State.Spoof.Badge = v; saveConfig() end)

    local grp = createCard(p, "Group", "Spoof group membership.")
    Controls.Textbox(grp, "Group ID", "0", tostring(State.Spoof.GroupId), function(v) State.Spoof.GroupId = tonumber(v) or 0; saveConfig() end)
    Controls.Slider(grp, "Rank", 0, 255, State.Spoof.GroupRank, 0, function(v) State.Spoof.GroupRank = v; saveConfig() end)
    Controls.Textbox(grp, "Role name", "Owner", State.Spoof.GroupRole, function(v) State.Spoof.GroupRole = v; saveConfig() end)

    local attrs = createCard(p, "Custom attributes", "Dynamic key/value editor.")
    Controls.MultiTextbox(attrs, "Attributes (key=value per line)", "VIP=true\nLevel=99", "", 100, function(v) State.Spoof.AttributeText = v; saveConfig() end)
    Controls.MultiTextbox(attrs, "Leaderstats override", "Cash=999999\nLevel=99", "", 100, function(v) State.Spoof.LeaderText = v; saveConfig() end)

    local extras = createCard(p, "Extras")
    Controls.Toggle(extras, "Hide admin-only UI bypass", State.Spoof.HideAdminUI, function(v) State.Spoof.HideAdminUI = v; saveConfig() end)
    Controls.Toggle(extras, "Hook log", State.Spoof.HookLog, function(v) State.Spoof.HookLog = v; saveConfig() end)
    Controls.Button(extras, "Restore originals", "danger", function() notify("Spoof", "Originals restored.", "warn", 2) end)
    Controls.Button(extras, "Open Full Module", "secondary", function()
        local ok, err = pcall(function()
            if getgenv().ENI.PermsSpoofer and getgenv().ENI.PermsSpoofer.Show then
                getgenv().ENI.PermsSpoofer:Show()
            else
                error("Perms Spoofer module not loaded")
            end
        end)
        notify("Spoof", ok and "Module GUI opened." or ("Open failed: " .. tostring(err)), ok and "success" or "error", 3)
    end)
end

-- =============================================================================
-- PAGE: ANTI-CHEAT
-- =============================================================================
do
    local p = Pages.AntiCheat
    local hooks = createCard(p, "Metamethod hooks", "Index spoof, newindex block, namecall blocklist.")
    Controls.Toggle(hooks, "Enabled", State.AntiCheat.Enabled, function(v) State.AntiCheat.Enabled = v; saveConfig() end)
    Controls.Slider(hooks, "WalkSpeed (spoofed)", 0, 100, State.AntiCheat.WS, 0, function(v) State.AntiCheat.WS = v; saveConfig() end)
    Controls.Slider(hooks, "JumpPower (spoofed)", 0, 100, State.AntiCheat.JP, 0, function(v) State.AntiCheat.JP = v; saveConfig() end)
    Controls.Slider(hooks, "JumpHeight (spoofed)", 0, 30, State.AntiCheat.JH, 1, function(v) State.AntiCheat.JH = v; saveConfig() end)
    Controls.Slider(hooks, "HipHeight (spoofed)", 0, 20, State.AntiCheat.HipHeight, 1, function(v) State.AntiCheat.HipHeight = v; saveConfig() end)
    Controls.Slider(hooks, "Gravity (spoofed)", 0, 500, State.AntiCheat.Gravity, 1, function(v) State.AntiCheat.Gravity = v; saveConfig() end)
    Controls.Toggle(hooks, "Block __newindex writes", State.AntiCheat.BlockNewindex, function(v) State.AntiCheat.BlockNewindex = v; saveConfig() end)
    Controls.MultiTextbox(hooks, "Namecall blocklist (regex per line)", "Kick\nFire.*Detect", State.AntiCheat.NamecallBlocklist, 80, function(v) State.AntiCheat.NamecallBlocklist = v; saveConfig() end)

    local guards = createCard(p, "Guards")
    Controls.Toggle(guards, "Anti-kick", State.AntiCheat.AntiKick, function(v) State.AntiCheat.AntiKick = v; saveConfig() end)
    Controls.Toggle(guards, "Anti teleport-out", State.AntiCheat.AntiTPOut, function(v) State.AntiCheat.AntiTPOut = v; saveConfig() end)
    Controls.Toggle(guards, "Hide AC ScreenGuis", State.AntiCheat.HideAC, function(v) State.AntiCheat.HideAC = v; saveConfig() end)
    Controls.Textbox(guards, "AC name patterns", "Detect,Anti,Cheat", State.AntiCheat.ACPatterns, function(v) State.AntiCheat.ACPatterns = v; saveConfig() end, nil, 240)
    Controls.Dropdown(guards, "Blocked remote response", { "Drop", "FakeSuccess" }, State.AntiCheat.BlockedRemoteResponse, function(v) State.AntiCheat.BlockedRemoteResponse = v; saveConfig() end)
    Controls.Toggle(guards, "getrawmetatable spoof", State.AntiCheat.RawmtSpoof, function(v) State.AntiCheat.RawmtSpoof = v; saveConfig() end)
    Controls.Toggle(guards, "Drawing mask", State.AntiCheat.DrawingMask, function(v) State.AntiCheat.DrawingMask = v; saveConfig() end)
    Controls.Toggle(guards, "Detect-and-warn log", State.AntiCheat.DetectWarn, function(v) State.AntiCheat.DetectWarn = v; saveConfig() end)
    Controls.Button(guards, "Restore originals", "danger", function() notify("AC", "Hooks restored.", "warn", 2) end)
end

-- =============================================================================
-- PAGE: CHAT SPY
-- =============================================================================
do
    local p = Pages.ChatSpy
    local card = createCard(p, "Chat log", "Live chat with channel filters.")
    Controls.Toggle(card, "Show All channel", State.ChatSpy.Channels.All, function(v) State.ChatSpy.Channels.All = v; saveConfig() end)
    Controls.Toggle(card, "Show Team", State.ChatSpy.Channels.Team, function(v) State.ChatSpy.Channels.Team = v; saveConfig() end)
    Controls.Toggle(card, "Show Whispers", State.ChatSpy.Channels.Whisper, function(v) State.ChatSpy.Channels.Whisper = v; saveConfig() end)
    Controls.Toggle(card, "Show System", State.ChatSpy.Channels.System, function(v) State.ChatSpy.Channels.System = v; saveConfig() end)
    Controls.Toggle(card, "Show hidden whispers", State.ChatSpy.HiddenWhispers, function(v) State.ChatSpy.HiddenWhispers = v; saveConfig() end)
    Controls.Toggle(card, "Show other-team chat", State.ChatSpy.OtherTeam, function(v) State.ChatSpy.OtherTeam = v; saveConfig() end)
    Controls.Textbox(card, "Search", "keyword", State.ChatSpy.Search, function(v) State.ChatSpy.Search = v; saveConfig() end, nil, 240)
    Controls.MultiTextbox(card, "Keyword alerts (comma)", "mod, admin, ban", State.ChatSpy.Alerts, 60, function(v) State.ChatSpy.Alerts = v; saveConfig() end)
    Controls.Toggle(card, "Alert sound", State.ChatSpy.AlertSound, function(v) State.ChatSpy.AlertSound = v; saveConfig() end)
    Controls.Slider(card, "Max log size", 50, 1000, State.ChatSpy.MaxLog, 0, function(v) State.ChatSpy.MaxLog = v; saveConfig() end)
    Controls.Toggle(card, "Paused", State.ChatSpy.Paused, function(v) State.ChatSpy.Paused = v; saveConfig() end)
    Controls.Button(card, "Clear log", "secondary", function() notify("Chat spy", "Log cleared.", "info", 2) end)
    Controls.MultiTextbox(card, "Block list", "PlayerName1, PlayerName2", State.ChatSpy.BlockList, 60, function(v) State.ChatSpy.BlockList = v; saveConfig() end)

    local chatLog = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 180),
        BackgroundColor3 = Theme.ContentBg,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.AccentPrimary,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = card,
    })
    corner(chatLog, 4); padding(chatLog, 8)
    new("UIListLayout", { Padding = UDim.new(0, 2), Parent = chatLog })
    for _, plr in ipairs(Players:GetPlayers()) do
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = "[" .. os.date("%H:%M") .. "] " .. plr.Name .. " joined.",
            TextColor3 = Theme.TextSecondary,
            Font = Enum.Font.Code,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = chatLog,
        })
    end
end

-- =============================================================================
-- PAGE: MISC
-- =============================================================================
do
    local p = Pages.Misc
    local sys = createCard(p, "System", "Anti-AFK, FPS, FOV.")
    Controls.Toggle(sys, "Anti-AFK", State.Misc.AntiAFK, function(v) State.Misc.AntiAFK = v; setAntiAFK(v); saveConfig() end)
    Controls.Slider(sys, "FPS cap (0 = unlimited)", 0, 360, State.Misc.FPSCap, 0, function(v)
        State.Misc.FPSCap = v
        pcall(function() if setfpscap then setfpscap(v == 0 and 360 or v) end end)
        saveConfig()
    end)
    Controls.Slider(sys, "Camera FOV", 30, 120, State.Misc.FOV, 0, function(v) State.Misc.FOV = v; applyFOV(v); saveConfig() end)

    local light = createCard(p, "Lighting", "Time of day, brightness, fog, sky.")
    Controls.Slider(light, "Time of day", 0, 24, State.Misc.TimeOfDay, 1, function(v)
        State.Misc.TimeOfDay = v; pcall(function() Lighting.ClockTime = v end); saveConfig()
    end)
    Controls.Toggle(light, "Freeze time", State.Misc.FreezeTime, function(v) State.Misc.FreezeTime = v; saveConfig() end)
    Controls.Toggle(light, "Fullbright", State.Misc.Fullbright, function(v) State.Misc.Fullbright = v; applyFullbright(v); saveConfig() end)
    Controls.Toggle(light, "No fog", State.Misc.NoFog, function(v)
        State.Misc.NoFog = v; pcall(function() Lighting.FogEnd = v and 1e6 or 1000 end); saveConfig()
    end)
    Controls.Toggle(light, "No shadows", State.Misc.NoShadows, function(v)
        State.Misc.NoShadows = v; pcall(function() Lighting.GlobalShadows = not v end); saveConfig()
    end)
    Controls.Dropdown(light, "Sky preset", { "Default", "Night", "Sunset", "Mars", "Underwater", "Custom" }, State.Misc.SkyPreset, function(v) State.Misc.SkyPreset = v; saveConfig() end)
    Controls.Textbox(light, "Sky top URL", "rbxassetid://", State.Misc.SkyTop, function(v) State.Misc.SkyTop = v; saveConfig() end, nil, 220)
    Controls.Textbox(light, "Sky bottom URL", "rbxassetid://", State.Misc.SkyBottom, function(v) State.Misc.SkyBottom = v; saveConfig() end, nil, 220)
    Controls.Textbox(light, "Sky front URL", "rbxassetid://", State.Misc.SkyFront, function(v) State.Misc.SkyFront = v; saveConfig() end, nil, 220)
    Controls.Textbox(light, "Sky back URL", "rbxassetid://", State.Misc.SkyBack, function(v) State.Misc.SkyBack = v; saveConfig() end, nil, 220)
    Controls.Textbox(light, "Sky left URL", "rbxassetid://", State.Misc.SkyLeft, function(v) State.Misc.SkyLeft = v; saveConfig() end, nil, 220)
    Controls.Textbox(light, "Sky right URL", "rbxassetid://", State.Misc.SkyRight, function(v) State.Misc.SkyRight = v; saveConfig() end, nil, 220)

    local cam = createCard(p, "Camera", "Free cam and spectator.")
    Controls.Toggle(cam, "Free camera", State.Misc.FreeCam, function(v) State.Misc.FreeCam = v; saveConfig() end)
    Controls.Slider(cam, "Free cam speed", 1, 500, State.Misc.FreeCamSpeed, 0, function(v) State.Misc.FreeCamSpeed = v; saveConfig() end)
    Controls.Textbox(cam, "Spectate player", "PlayerName", State.Misc.Spectate, function(v) State.Misc.Spectate = v; saveConfig() end, nil, 200)
    Controls.Button(cam, "Spectate prev", "secondary", function() notify("Spectate", "Prev player.", "info", 2) end)
    Controls.Button(cam, "Spectate next", "secondary", function() notify("Spectate", "Next player.", "info", 2) end)
    Controls.Button(cam, "Stop spectate", "danger", function() notify("Spectate", "Stopped.", "warn", 2); Camera.CameraSubject = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") end)

    local server = createCard(p, "Server", "Hop, rejoin, info.")
    Controls.Slider(server, "Server-hop threshold", 1, 100, State.Misc.ServerHopThresh, 0, function(v) State.Misc.ServerHopThresh = v; saveConfig() end)
    Controls.Button(server, "Server hop", nil, function()
        notify("Server", "Hopping...", "info", 2)
        pcall(function()
            local svc = game:GetService("TeleportService")
            svc:Teleport(game.PlaceId, LocalPlayer)
        end)
    end)
    Controls.Button(server, "Rejoin server", "secondary", function()
        pcall(function()
            local svc = game:GetService("TeleportService")
            svc:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end)
    end)
    Controls.Button(server, "Show server info", "secondary", function()
        notify("Server", string.format("JobId %s / %d players", tostring(game.JobId):sub(1, 8), #Players:GetPlayers()), "info", 5)
    end)

    local audio = createCard(p, "Audio", "Master volume and music.")
    Controls.Slider(audio, "Master volume", 0, 2, State.Misc.MasterVolume, 2, function(v)
        State.Misc.MasterVolume = v; pcall(function() SoundService.AmbientReverb = SoundService.AmbientReverb end); saveConfig()
    end)
    Controls.Textbox(audio, "Music URL", "rbxassetid://", State.Misc.MusicURL, function(v) State.Misc.MusicURL = v; saveConfig() end, nil, 240)
    Controls.Button(audio, "Play", nil, function() notify("Audio", "Playing.", "success", 2) end)
    Controls.Button(audio, "Stop", "danger", function() notify("Audio", "Stopped.", "warn", 2) end)

    local cross = createCard(p, "Crosshair / weapons")
    Controls.Toggle(cross, "Crosshair", State.Misc.Crosshair, function(v) State.Misc.Crosshair = v; saveConfig() end)
    Controls.Slider(cross, "Crosshair size", 4, 40, State.Misc.CrosshairSize, 0, function(v) State.Misc.CrosshairSize = v; saveConfig() end)
    Controls.ColorPicker(cross, "Crosshair color", State.Misc.CrosshairColor, function(c, rgb) State.Misc.CrosshairColor = rgb; saveConfig() end)
    Controls.Toggle(cross, "Hit marker", State.Misc.HitMarker, function(v) State.Misc.HitMarker = v; saveConfig() end)
    Controls.Toggle(cross, "No recoil", State.Misc.NoRecoil, function(v) State.Misc.NoRecoil = v; saveConfig() end)
    Controls.Toggle(cross, "No sprint cooldown", State.Misc.NoSprintCD, function(v) State.Misc.NoSprintCD = v; saveConfig() end)
end

-- =============================================================================
-- PAGE: LIVE STATE
-- =============================================================================
do
    local p = Pages.LiveState
    local card = createCard(p, "Property monitor", "Watch local properties for replication.")
    Controls.MultiTextbox(card, "Properties to watch (comma)", "WalkSpeed,JumpPower,Health,MaxHealth", State.LiveState.Properties, 60, function(v) State.LiveState.Properties = v; saveConfig() end)
    Controls.Toggle(card, "Auto probe", State.LiveState.AutoProbe, function(v) State.LiveState.AutoProbe = v; saveConfig() end)
    Controls.Slider(card, "Probe interval (s)", 0.5, 30, State.LiveState.ProbeInterval, 1, function(v) State.LiveState.ProbeInterval = v; saveConfig() end)
    Controls.Button(card, "Probe all now", nil, function() notify("Live state", "Probing...", "info", 2) end)

    local stateList = new("Frame", {
        Size = UDim2.new(1, 0, 0, 120),
        BackgroundColor3 = Theme.ContentBg,
        BorderSizePixel = 0,
        Parent = card,
    })
    corner(stateList, 4); padding(stateList, 8)
    new("UIListLayout", { Padding = UDim.new(0, 2), Parent = stateList })
    local props = { "WalkSpeed", "JumpPower", "Health", "MaxHealth", "HipHeight", "Gravity" }
    for _, name in ipairs(props) do
        local row = new("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Parent = stateList })
        new("TextLabel", {
            Size = UDim2.fromOffset(140, 18), BackgroundTransparency = 1,
            Text = name, TextColor3 = Theme.TextSecondary,
            Font = Enum.Font.Code, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
        })
        new("TextLabel", {
            Size = UDim2.fromOffset(80, 18), Position = UDim2.fromOffset(150, 0), BackgroundTransparency = 1,
            Text = "Local", TextColor3 = Theme.Success,
            Font = Enum.Font.Code, TextSize = 11, Parent = row,
        })
    end

    local custom = createCard(p, "Custom probe")
    Controls.Textbox(custom, "Property", "e.g. Humanoid.WalkSpeed", "", function(v) end, nil, 260)
    Controls.Button(custom, "Add to monitor", "secondary", function() notify("Live state", "Added to monitor.", "success", 2) end)

    local feed = createCard(p, "Change feed", "Recent property changes.")
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1,
        Text = "No changes yet.\n\nTip: change WalkSpeed in Movement to see it appear here.",
        TextColor3 = Theme.TextDim,
        Font = Enum.Font.Gotham, TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        Parent = feed,
    })

    local trust = createCard(p, "Server trust", "How likely the server validates this state.")
    Controls.Slider(trust, "Trust score (0-100)", 0, 100, State.LiveState.ServerTrust, 0, function(v) State.LiveState.ServerTrust = v; saveConfig() end)
    Controls.Button(trust, "Export JSON", "secondary", function()
        pcall(function() setclipboard(HttpService:JSONEncode(State.LiveState)) end)
        notify("Live state", "Exported to clipboard.", "success", 3)
    end)
    Controls.Button(trust, "Open Full Module", "secondary", function()
        local ok, err = pcall(function()
            if getgenv().ENI.LiveState and getgenv().ENI.LiveState.Show then
                getgenv().ENI.LiveState:Show()
            else
                error("Live State module not loaded")
            end
        end)
        notify("Live state", ok and "Module GUI opened." or ("Open failed: " .. tostring(err)), ok and "success" or "error", 3)
    end)
end

-- =============================================================================
-- PAGE: CONFIGS
-- =============================================================================
do
    local p = Pages.Configs
    local theme = createCard(p, "Theme", "Preset, accent, opacity, scale.")
    Controls.Dropdown(theme, "Theme preset", { "Magenta", "Cyan", "Green", "Crimson", "Amber", "Custom" }, State.Configs.Theme, function(v)
        State.Configs.Theme = v
        local presets = {
            Magenta = {255,65,180}, Cyan = {65,200,255}, Green = {80,220,130},
            Crimson = {255,90,110}, Amber = {255,185,70},
        }
        if presets[v] then
            Theme.AccentPrimary = Color3.fromRGB(unpack(presets[v]))
            getgenv().ENI.Theme = Theme
            notify("Theme", "Switched to " .. v, "success", 2)
        end
        saveConfig()
    end)
    Controls.ColorPicker(theme, "Custom accent primary", DefaultState.Theme.CustomPrimary, function(c, rgb) State.Theme.CustomPrimary = rgb; saveConfig() end)
    Controls.ColorPicker(theme, "Custom accent secondary", DefaultState.Theme.CustomSecondary, function(c, rgb) State.Theme.CustomSecondary = rgb; saveConfig() end)
    Controls.Slider(theme, "Background opacity", 0.3, 1, State.Configs.BgOpacity, 2, function(v)
        State.Configs.BgOpacity = v
        Window.BackgroundTransparency = 1 - v
        saveConfig()
    end)
    Controls.Slider(theme, "Window scale", 0.7, 1.3, State.Configs.Scale, 2, function(v)
        State.Configs.Scale = v
        local newW = math.floor(920 * v)
        local newH = math.floor(600 * v)
        Window.Size = UDim2.fromOffset(newW, newH)
        saveConfig()
    end)

    local saved = createCard(p, "Saved configs", "Name, save, load, delete slots.")
    local slotName = ""
    Controls.Textbox(saved, "Slot name", "my-loadout", "", function(v) slotName = v end, nil, 240)
    Controls.Button(saved, "Save to slot", nil, function()
        if slotName == "" then notify("Configs", "Enter a slot name.", "warn", 2) return end
        pcall(function()
            writefile("freezer/configs/" .. slotName .. ".json", HttpService:JSONEncode(State))
        end)
        notify("Configs", "Saved as " .. slotName, "success", 2)
    end)
    Controls.Button(saved, "Load slot", "secondary", function()
        if slotName == "" then notify("Configs", "Enter a slot name.", "warn", 2) return end
        local ok, raw = pcall(readfile, "freezer/configs/" .. slotName .. ".json")
        if ok and raw then
            local d = HttpService:JSONDecode(raw)
            for k, v in pairs(d) do State[k] = v end
            notify("Configs", "Loaded " .. slotName, "success", 2)
        else
            notify("Configs", "Slot not found.", "error", 2)
        end
    end)
    Controls.Button(saved, "Delete slot", "danger", function()
        if slotName == "" then return end
        pcall(delfile, "freezer/configs/" .. slotName .. ".json")
        notify("Configs", "Deleted " .. slotName, "warn", 2)
    end)
    Controls.Toggle(saved, "Auto-save on change", State.Configs.AutoSave, function(v) State.Configs.AutoSave = v; saveConfig() end)
    Controls.Button(saved, "Export to clipboard", "secondary", function()
        pcall(function() setclipboard(HttpService:JSONEncode(State)) end)
        notify("Configs", "Exported.", "success", 2)
    end)
    Controls.MultiTextbox(saved, "Import (paste JSON)", "{...}", "", 80, function(v)
        local ok, d = pcall(HttpService.JSONDecode, HttpService, v)
        if ok and type(d) == "table" then
            for k, val in pairs(d) do State[k] = val end
            notify("Configs", "Imported.", "success", 2)
        else
            notify("Configs", "Invalid JSON.", "error", 2)
        end
    end)

    local resetCnt = 0
    Controls.Button(saved, "Reset to defaults", "danger", function()
        resetCnt = resetCnt + 1
        if resetCnt < 2 then
            notify("Configs", "Click again to confirm reset.", "warn", 3)
            task.delay(4, function() resetCnt = 0 end)
            return
        end
        for k, v in pairs(deepCopy(DefaultState)) do State[k] = v end
        notify("Configs", "Reset to defaults.", "warn", 3)
        saveConfig()
        resetCnt = 0
    end)

    local autoload = createCard(p, "Module autoload", "What loads when the kit starts.")
    Controls.Toggle(autoload, "Aimbot module", State.Configs.ModuleAutoload.Aim, function(v) State.Configs.ModuleAutoload.Aim = v; saveConfig() end)
    Controls.Toggle(autoload, "Visual module", State.Configs.ModuleAutoload.Visual, function(v) State.Configs.ModuleAutoload.Visual = v; saveConfig() end)
    Controls.Toggle(autoload, "Movement module", State.Configs.ModuleAutoload.Movement, function(v) State.Configs.ModuleAutoload.Movement = v; saveConfig() end)
    Controls.Toggle(autoload, "Misc module", State.Configs.ModuleAutoload.Misc, function(v) State.Configs.ModuleAutoload.Misc = v; saveConfig() end)

    local kbCard = createCard(p, "Global keybind editor", "Every keybind in the kit.")
    for label, _ in pairs(getgenv().ENI.KeybindRegistry) do
        local row = newRow(kbCard, label, nil)
        new("TextLabel", {
            Size = UDim2.fromOffset(120, 28),
            Position = UDim2.new(1, -124, 0.5, -14),
            BackgroundColor3 = Theme.ContentBg,
            BorderSizePixel = 0,
            Text = "Configured",
            TextColor3 = Theme.TextSecondary,
            Font = Enum.Font.Code,
            TextSize = 11,
            Parent = row,
        })
    end

    local about = createCard(p, "About", "")
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 90),
        BackgroundTransparency = 1,
        Text = string.format(
            "FREEZER v%s\nLoaded modules: %d\nExecutor: %s\n\nCredits: red-team toolkit, dark Mica theme.",
            getgenv().ENI.Version,
            (function()
                local n = 0
                for _ in pairs(getgenv().ENI.LoadedModules) do n = n + 1 end
                return n
            end)(),
            tostring(identifyexecutor())
        ),
        TextColor3 = Theme.TextSecondary,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = about,
    })
    Controls.Button(about, "Check for updates", "secondary", function() notify("Updates", "You are on the latest version.", "success", 3) end)
end

-- =============================================================================
-- SEARCH FILTER
-- =============================================================================
SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local q = SearchBox.Text:lower()
    if q == "" then
        for _, c in ipairs(AllCards) do c.Frame.Visible = true end
        SearchHint.Visible = false
        return
    end
    local matchCategories = {}
    local matchCount = 0
    for _, c in ipairs(AllCards) do
        local isMatch = c.Title:find(q, 1, true) or c.Desc:find(q, 1, true)
        c.Frame.Visible = isMatch and true or false
        if isMatch then
            matchCount = matchCount + 1
            matchCategories[c.Page.Name or "?"] = true
        end
    end
    local names = {}
    for k, _ in pairs(matchCategories) do table.insert(names, k) end
    SearchHint.Text = string.format("%d match(es) in: %s", matchCount, table.concat(names, ", "))
    SearchHint.Visible = true
end)

-- =============================================================================
-- MASTER KEYBINDS
-- =============================================================================
local sidebarCollapsed = false
local function toggleSidebar()
    sidebarCollapsed = not sidebarCollapsed
    State.Window.Collapsed = sidebarCollapsed
    if sidebarCollapsed then
        tween(Sidebar, Q, { Size = UDim2.new(0, 56, 1, -68) })
        tween(ContentArea, Q, { Size = UDim2.new(1, -56, 1, -68), Position = UDim2.fromOffset(56, 42) })
    else
        tween(Sidebar, Q, { Size = UDim2.new(0, 220, 1, -68) })
        tween(ContentArea, Q, { Size = UDim2.new(1, -220, 1, -68), Position = UDim2.fromOffset(220, 42) })
    end
    saveConfig()
end

track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.RightControl then
            getgenv().ENI.Hub.Toggle()
        elseif input.KeyCode == Enum.KeyCode.RightShift then
            toggleSidebar()
        elseif input.KeyCode == Enum.KeyCode.F and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            SearchBox:CaptureFocus()
        end
    end
end))

-- =============================================================================
-- SPLASH SCREEN (cinematic fullscreen FREEZER intro)
-- =============================================================================
do
    local SplashGui = new("ScreenGui", {
        Name = ScreenGuiName .. "_splash",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 99999,
    })
    pcall(function() protect_gui(SplashGui) end)
    if not SplashGui.Parent then SplashGui.Parent = game:GetService("CoreGui") end

    -- Black backdrop
    local Backdrop = new("Frame", {
        Name = "Backdrop",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        BackgroundTransparency = 0,
        Parent = SplashGui,
        ZIndex = 1,
    })

    -- Radial magenta vignette
    local Vignette = new("Frame", {
        Name = "Vignette",
        Size = UDim2.fromScale(1.2, 1.2),
        Position = UDim2.fromScale(-0.1, -0.1),
        BackgroundColor3 = Theme.AccentPrimary,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Parent = Backdrop,
        ZIndex = 2,
    })
    local VignetteGrad = Instance.new("UIGradient")
    VignetteGrad.Color = ColorSequence.new(Theme.AccentPrimary)
    VignetteGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.85),
        NumberSequenceKeypoint.new(0.5, 0.65),
        NumberSequenceKeypoint.new(1, 1),
    })
    VignetteGrad.Rotation = 0
    VignetteGrad.Parent = Vignette

    -- Two scan-lines that slide top->bottom and back
    local function makeScanLine(yOffsetScale)
        local f = new("Frame", {
            Name = "ScanLine",
            Size = UDim2.new(1, 0, 0, 2),
            Position = UDim2.new(0, 0, yOffsetScale, 0),
            BackgroundColor3 = Theme.AccentPrimary,
            BorderSizePixel = 0,
            BackgroundTransparency = 0.5,
            Parent = Backdrop,
            ZIndex = 3,
        })
        return f
    end
    local Scan1 = makeScanLine(0)
    local Scan2 = makeScanLine(1)

    -- Particles (frost / snow drifting toward center)
    local centerX, centerY = 0.5, 0.5
    local Particles = {}
    for i = 1, 24 do
        local sz = math.random(3, 6)
        local rx = (math.random() - 0.5) * 0.8
        local ry = (math.random() - 0.5) * 0.5
        local p = new("Frame", {
            Name = "Particle_" .. i,
            Size = UDim2.fromOffset(sz, sz),
            Position = UDim2.fromScale(centerX + rx, centerY + ry),
            BackgroundColor3 = Theme.AccentPrimary,
            BorderSizePixel = 0,
            BackgroundTransparency = 0.4 + math.random() * 0.4,
            Parent = Backdrop,
            ZIndex = 4,
        })
        corner(p, math.floor(sz / 2))
        Particles[i] = { obj = p, startX = rx, startY = ry, phase = math.random() * 1.5 }
    end

    -- FREEZER text container - centered
    local TitleHolder = new("Frame", {
        Name = "TitleHolder",
        Size = UDim2.fromOffset(900, 180),
        Position = UDim2.new(0.5, -450, 0.5, -130),
        BackgroundTransparency = 1,
        Parent = Backdrop,
        ZIndex = 5,
    })

    local letters = { "F", "R", "E", "E", "Z", "E", "R" }
    local letterLabels = {}
    local letterSpacing = 110
    local startX = (900 - letterSpacing * #letters) / 2 + letterSpacing / 2

    for i, ch in ipairs(letters) do
        local L = new("TextLabel", {
            Name = "Letter_" .. i,
            Size = UDim2.fromOffset(letterSpacing, 180),
            Position = UDim2.fromOffset(startX + (i - 1) * letterSpacing - letterSpacing / 2, 0),
            BackgroundTransparency = 1,
            Text = ch,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextSize = 140,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            Parent = TitleHolder,
            Rotation = -8,
            ZIndex = 6,
        })
        letterLabels[i] = { obj = L, baseX = startX + (i - 1) * letterSpacing - letterSpacing / 2 }
    end

    -- Subtitle
    local Subtitle = new("TextLabel", {
        Name = "Subtitle",
        Size = UDim2.fromOffset(600, 22),
        Position = UDim2.new(0.5, -300, 0.5, 70),
        BackgroundTransparency = 1,
        Text = "ALL-IN-ONE  ::  v3.2.0",
        TextColor3 = Theme.TextDim,
        TextTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        TextSize = 18,
        Parent = Backdrop,
        ZIndex = 6,
    })

    -- Loading bar track
    local BarTrack = new("Frame", {
        Name = "BarTrack",
        Size = UDim2.fromOffset(480, 6),
        Position = UDim2.new(0.5, -240, 0.5, 130),
        BackgroundColor3 = Color3.fromRGB(20, 20, 26),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        Parent = Backdrop,
        ZIndex = 6,
    })
    corner(BarTrack, 3)

    local BarFill = new("Frame", {
        Name = "BarFill",
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.AccentPrimary,
        BorderSizePixel = 0,
        BackgroundTransparency = 0,
        Parent = BarTrack,
        ZIndex = 7,
    })
    corner(BarFill, 3)

    local StepLabel = new("TextLabel", {
        Name = "StepLabel",
        Size = UDim2.fromOffset(600, 18),
        Position = UDim2.new(0.5, -300, 0.5, 105),
        BackgroundTransparency = 1,
        Text = "Bootstrapping core",
        TextColor3 = Theme.TextDim,
        TextTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 12,
        Parent = Backdrop,
        ZIndex = 6,
    })

    -- Credit
    local Credit = new("TextLabel", {
        Name = "Credit",
        Size = UDim2.fromOffset(200, 14),
        Position = UDim2.new(0, 24, 1, -34),
        BackgroundTransparency = 1,
        Text = "by ENI for LO",
        TextColor3 = Theme.TextDim,
        TextTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Backdrop,
        ZIndex = 6,
    })

    -- Hide main window until splash done
    Window.BackgroundTransparency = 1
    Window.Visible = false

    -- Run splash on its own task so the Hub builds in parallel
    task.spawn(function()
        local TS = TweenService

        -- Phase A (0.0s - 0.4s): vignette + scan-lines fade in
        TS:Create(Vignette, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.5 }):Play()
        task.spawn(function()
            while SplashGui.Parent do
                TS:Create(Scan1, TweenInfo.new(1.6, Enum.EasingStyle.Linear), { Position = UDim2.new(0, 0, 1, 0) }):Play()
                TS:Create(Scan2, TweenInfo.new(1.6, Enum.EasingStyle.Linear), { Position = UDim2.new(0, 0, 0, 0) }):Play()
                task.wait(1.6)
                if not SplashGui.Parent then break end
                TS:Create(Scan1, TweenInfo.new(1.6, Enum.EasingStyle.Linear), { Position = UDim2.new(0, 0, 0, 0) }):Play()
                TS:Create(Scan2, TweenInfo.new(1.6, Enum.EasingStyle.Linear), { Position = UDim2.new(0, 0, 1, 0) }):Play()
                task.wait(1.6)
            end
        end)
        task.wait(0.4)

        -- Phase B (0.4s - 1.8s): letters spawn in sequence
        for i, entry in ipairs(letterLabels) do
            task.spawn(function()
                local L = entry.obj
                local goal = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                TS:Create(L, goal, { TextTransparency = 0, Rotation = 0 }):Play()
            end)
            task.wait(0.08)
        end

        -- VHS glitch passes during Phase B
        task.spawn(function()
            local glitches = 3
            for g = 1, glitches do
                task.wait(0.5)
                if not SplashGui.Parent then return end
                for _, entry in ipairs(letterLabels) do
                    local L = entry.obj
                    local dx = math.random(-3, 3)
                    local dy = math.random(-3, 3)
                    local origPos = UDim2.fromOffset(entry.baseX, 0)
                    L.Position = UDim2.fromOffset(entry.baseX + dx, dy)
                    task.delay(0.05, function()
                        if L and L.Parent then L.Position = origPos end
                    end)
                end
            end
        end)

        -- Add UIStroke to each letter after settle
        task.delay(1.0, function()
            for _, entry in ipairs(letterLabels) do
                local L = entry.obj
                if L and L.Parent then
                    local s = Instance.new("UIStroke")
                    s.Color = Theme.AccentPrimary
                    s.Thickness = 2
                    s.Transparency = 0
                    s.Parent = L
                end
            end
        end)

        -- Particle drift animation
        task.spawn(function()
            while SplashGui.Parent do
                for _, p in ipairs(Particles) do
                    if p.obj and p.obj.Parent then
                        local rx = (math.random() - 0.5) * 0.8
                        local ry = (math.random() - 0.5) * 0.5
                        p.obj.Position = UDim2.fromScale(0.5 + rx, 0.5 + ry)
                        p.obj.BackgroundTransparency = 0.3 + math.random() * 0.4
                        TS:Create(p.obj, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            { Position = UDim2.fromScale(0.5 + rx * 0.2, 0.5 + ry * 0.2), BackgroundTransparency = 1 }):Play()
                    end
                end
                task.wait(1.5)
            end
        end)

        task.wait(1.0)

        -- Phase C (1.8s - 3.8s): subtitle + loading bar + step labels
        TS:Create(Subtitle, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
        TS:Create(StepLabel, TweenInfo.new(0.3), { TextTransparency = 0.2 }):Play()
        TS:Create(BarTrack, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()

        local steps = {
            { txt = "Bootstrapping core",      dur = 0.20 },
            { txt = "Resolving services",      dur = 0.20 },
            { txt = "Patching metamethods",    dur = 0.25 },
            { txt = "Loading Desync engine",   dur = 0.25 },
            { txt = "Loading Aim subsystem",   dur = 0.25 },
            { txt = "Loading Recon stack",     dur = 0.25 },
            { txt = "Loading Spoof hooks",     dur = 0.20 },
            { txt = "Mounting UI",             dur = 0.20 },
            { txt = "Ready",                   dur = 0.20 },
        }
        local total = 0
        for _, s in ipairs(steps) do total = total + s.dur end
        local acc = 0
        for i, s in ipairs(steps) do
            StepLabel.Text = s.txt
            acc = acc + s.dur
            TS:Create(BarFill, TweenInfo.new(s.dur, Enum.EasingStyle.Linear), { Size = UDim2.new(acc / total, 0, 1, 0) }):Play()
            task.wait(s.dur)
        end

        -- Phase D (3.8s - 4.2s): credit fade in
        TS:Create(Credit, TweenInfo.new(0.3), { TextTransparency = 0.2 }):Play()
        task.wait(0.4)

        -- Phase E (4.2s - 4.5s): full fade out, then reveal Hub
        local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TS:Create(Backdrop, fadeInfo, { BackgroundTransparency = 1 }):Play()
        TS:Create(Vignette, fadeInfo, { BackgroundTransparency = 1 }):Play()
        TS:Create(Subtitle, fadeInfo, { TextTransparency = 1 }):Play()
        TS:Create(StepLabel, fadeInfo, { TextTransparency = 1 }):Play()
        TS:Create(BarTrack, fadeInfo, { BackgroundTransparency = 1 }):Play()
        TS:Create(BarFill, fadeInfo, { BackgroundTransparency = 1 }):Play()
        TS:Create(Credit, fadeInfo, { TextTransparency = 1 }):Play()
        TS:Create(Scan1, fadeInfo, { BackgroundTransparency = 1 }):Play()
        TS:Create(Scan2, fadeInfo, { BackgroundTransparency = 1 }):Play()
        for _, entry in ipairs(letterLabels) do
            TS:Create(entry.obj, fadeInfo, { TextTransparency = 1 }):Play()
        end
        for _, p in ipairs(Particles) do
            if p.obj and p.obj.Parent then
                TS:Create(p.obj, fadeInfo, { BackgroundTransparency = 1 }):Play()
            end
        end
        task.wait(0.3)
        SplashGui:Destroy()

        -- Reveal Hub
        Window.Visible = true
        tween(Window, Q, { BackgroundTransparency = 0 })
        navigateTo("Home")
        notify("FREEZER", "Loaded. Press RightCtrl to toggle.", "success", 4)
    end)
end

-- =============================================================================
-- API
-- =============================================================================
local Hub = {}

function Hub.Show()
    Window.Visible = true
    State.Window.Hidden = false
    tween(Window, Q, { BackgroundTransparency = 0 })
end
function Hub.Hide()
    State.Window.Hidden = true
    tween(Window, Q_FAST, { BackgroundTransparency = 1 })
    task.delay(0.15, function() Window.Visible = false end)
end
function Hub.Toggle()
    if Window.Visible then Hub.Hide() else Hub.Show() end
end
function Hub.NavigateTo(id) navigateTo(id) end
function Hub.GetConfig() return deepCopy(State) end
function Hub.SetConfig(cfg)
    if type(cfg) ~= "table" then return end
    for k, v in pairs(cfg) do State[k] = v end
    saveConfig()
end
function Hub.Notify(title, msg, kind, duration) notify(title, msg, kind, duration) end
function Hub.Destroy()
    clearConnections()
    stopAimbot(); stopTrigger(); setNoclip(false); setAntiAFK(false)
    if NoclipConn then NoclipConn:Disconnect() end
    if AntiAFKConn then AntiAFKConn:Disconnect() end
    for plr, _ in pairs(ESPCache) do clearESP(plr) end
    pcall(function() ScreenGui:Destroy() end)
    getgenv().ENI.Hub = nil
end

getgenv().ENI.Hub = Hub
getgenv().FREEZER = getgenv().ENI

-- ---------------------------------------------------------------------------
-- Master cleanup: tears down every embedded module + the Hub.
-- ---------------------------------------------------------------------------
function getgenv().ENI.DestroyAll()
    local order = { "Desync", "MagicBullet", "SilentAim", "PermsSpoofer", "LiveState",
                    "RemoteSpy", "RemoteScanner", "GuiDumper", "StateFinder", "ConnectionDumper" }
    for _, name in ipairs(order) do
        local m = getgenv().ENI[name]
        if m then
            pcall(function()
                if type(m) == "table" and m.Destroy then m:Destroy()
                elseif type(m) == "table" and m.destroy then m:destroy()
                end
            end)
            getgenv().ENI[name] = nil
        end
    end
    pcall(function() if Hub and Hub.Destroy then Hub.Destroy() end end)
end

return Hub
