--[[
    FREEZER v6.2.0  ::  Targeted-fix build
    Single-file Roblox executor menu, by ENI for LO

    Design principle: ZERO global hooks installed at load. Hooks for Silent Aim,
    Magic Bullet, Perms Spoof, and AntiCheat Bypass are installed LAZILY when the
    user enables those features and gated by state flags. All defaults OFF.

    v6.2 changes:
      A. Solara-tolerant safeGet (getfenv(1) first, loadstring fallback) +
         each install fn surfaces real errors.
      B. HSV color picker popup with SV square + hue bar + hex + preview.
      C. Ghost Desync rewritten: freeze server position; optional FreeCam;
         optional camera-origin override for silent shots.
      D. Cage card gets LOCAL-ONLY label and a new TRAP/RELEASE pair that
         force-locks aimbot+silent to a chosen player via S.Aimbot.ForceTarget.
      E. New Movement card: Ninja TP — stick behind nearest enemy each Heartbeat.
]]

--[[ EXPLOIT FN RESOLUTION (Solara-tolerant) ]]
local function safeGet(name)
    -- 1. Try as a direct global via getfenv(1) (calling env)
    local ok, val = pcall(function()
        local g = getfenv(1)
        return g and g[name]
    end)
    if ok and val then return val end
    -- 2. getgenv()
    ok, val = pcall(function() return getgenv and getgenv()[name] end)
    if ok and val then return val end
    -- 3. getfenv(0) script env
    ok, val = pcall(function() return getfenv(0)[name] end)
    if ok and val then return val end
    -- 4. shared/_G
    ok, val = pcall(function() return _G[name] end)
    if ok and val then return val end
    -- 5. last-ditch: try the function name directly via raw access in a string-eval
    local fn
    ok = pcall(function()
        local loader = loadstring or load
        if not loader then return end
        local chunk = loader("return " .. name)
        if chunk then fn = chunk() end
    end)
    if ok and fn then return fn end
    return nil
end

local cloneref         = safeGet("cloneref")         or function(o) return o end
-- SOLARA SANDBOX BYPASS:
-- Solara isolates loadstring chunks from executor globals. The user runs a
-- bootstrap snippet BEFORE loadstring that captures exploit fns into
-- getgenv()._FREEZER_EXPLOIT (getgenv survives the sandbox). We read from
-- there first, then fall back to whatever's visible in the chunk env.
local _exploit = {}
pcall(function()
    local g = getgenv and getgenv()
    if g and type(g._FREEZER_EXPLOIT) == "table" then
        _exploit = g._FREEZER_EXPLOIT
    end
end)

local _scriptEnv
pcall(function() _scriptEnv = getfenv() end)
_scriptEnv = _scriptEnv or _G or {}

local function rawglobal(name)
    -- 1. captured bootstrap (most reliable across sandboxed executors)
    local v = _exploit[name]
    if v ~= nil then return v end
    -- 2. script chunk env
    v = _scriptEnv[name]
    if v ~= nil then return v end
    -- 3. _G
    v = _G[name]
    if v ~= nil then return v end
    -- 4. safeGet fallback (getgenv/getfenv(0)/loadstring)
    return safeGet(name)
end

local _gethui          = rawglobal("gethui")
local hookmetamethod   = rawglobal("hookmetamethod")
local hookfunction     = rawglobal("hookfunction")
local getrawmetatable  = rawglobal("getrawmetatable")
local setreadonly      = rawglobal("setreadonly")      or function() end
local newcclosure      = rawglobal("newcclosure")      or function(f) return f end
local checkcaller      = rawglobal("checkcaller")      or function() return false end
local getnamecallmethod= rawglobal("getnamecallmethod")

-- NOTE: this Solara build does not expose hookmetamethod or getnamecallmethod.
-- Polyfilling __namecall via raw metatable manipulation caused game freezes
-- (likely due to missing checkcaller + recursive hook execution). Disabled until
-- a safer per-remote hook strategy is implemented. Affected features that will
-- show "Hook install failed" until then: Silent Aim, Magic Bullet, Perms Spoof,
-- AntiCheat Bypass, Remote Spy. All other features (Aimbot/ESP/Movement/Desync/
-- Cage/Ninja TP/Player KILL TRAP) work fully without these hooks.
local setfpscap        = safeGet("setfpscap")
local writefile        = safeGet("writefile")
local readfile         = safeGet("readfile")
local isfile           = safeGet("isfile")           or function() return false end
local makefolder       = safeGet("makefolder")
local listfiles        = safeGet("listfiles")
local delfile          = safeGet("delfile")
local Drawing          = safeGet("Drawing")
local identifyexecutor = safeGet("identifyexecutor") or function() return "Unknown" end
local setclipboard     = safeGet("setclipboard")     or function() end
local queue_on_teleport= safeGet("queue_on_teleport")

local EXEC = "Unknown"
pcall(function() EXEC = tostring(identifyexecutor()) end)

--[[ SERVICES ]]
local Players          = cloneref(game:GetService("Players"))
local RunService       = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local TweenService     = cloneref(game:GetService("TweenService"))
local Lighting         = cloneref(game:GetService("Lighting"))
local Workspace        = cloneref(game:GetService("Workspace"))
local CoreGui          = cloneref(game:GetService("CoreGui"))
local Stats            = cloneref(game:GetService("Stats"))
local VirtualUser      = cloneref(game:GetService("VirtualUser"))
local HttpService      = cloneref(game:GetService("HttpService"))
local SoundService     = cloneref(game:GetService("SoundService"))
local TeleportService  = cloneref(game:GetService("TeleportService"))
local TextChatService  = nil
pcall(function() TextChatService = cloneref(game:GetService("TextChatService")) end)

local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()
local function GetCamera() return Workspace.CurrentCamera end

--[[ THEME ]]
local C = {
    Window        = Color3.fromRGB(20, 20, 26),
    Sidebar       = Color3.fromRGB(24, 24, 30),
    Content       = Color3.fromRGB(28, 28, 34),
    Card          = Color3.fromRGB(36, 36, 44),
    CardHover     = Color3.fromRGB(44, 44, 54),
    Border        = Color3.fromRGB(54, 54, 66),
    Accent        = Color3.fromRGB(255, 65, 180),
    AccentSoft    = Color3.fromRGB(80, 32, 60),
    Text          = Color3.fromRGB(240, 240, 248),
    TextSecondary = Color3.fromRGB(170, 170, 188),
    TextDim       = Color3.fromRGB(115, 115, 135),
    Success       = Color3.fromRGB(80, 220, 130),
    Warning       = Color3.fromRGB(255, 185, 70),
    Danger        = Color3.fromRGB(255, 90, 110),
}

local EASE      = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local EASE_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

--[[ STATE â€” all features OFF by default ]]
local S = {
    Master = { Enabled = false, ToggleKey = "RightControl" },
    Aimbot = {
        Enabled = false, FOV = 120, Smooth = 0.2,
        TargetPart = "Head", TeamCheck = false, WallCheck = true,
        ShowFovCircle = false, ColorFovCircle = Color3.fromRGB(255, 65, 180),
        FilledFovCircle = false, FovCircleThickness = 1,
        ActivationKey = "MouseButton2",
        Prediction = false, VelocityMultiplier = 0.165,
        StickyLock = false, LockIndicator = false,
        LockIndicatorColor = Color3.fromRGB(255, 65, 180),
        TargetHighlight = false,
        TargetHighlightColor = Color3.fromRGB(255, 65, 180),
        LockSound = false, LockSoundId = "rbxassetid://9118823106",
        ForceTarget = nil,
    },
    SilentAim = {
        Enabled = false, FOV = 200, TargetPart = "Head",
        HitChance = 100, TeamCheck = false, WallCheck = false,
        Method = "AUTO", RemotePath = "", Visualizer = false,
        ShowFovCircle = false,
        ColorFovCircle = Color3.fromRGB(150, 100, 255),
    },
    MagicBullet = {
        Enabled = false, Mode = "Direct", RemotePath = "",
        ForceHit = true, Range = 1000, MaxBPS = 30, Jitter = 0.0,
    },
    TriggerBot = {
        Enabled = false, Delay = 0.05, Jitter = 0.02,
        Key = "Q", KnockCheck = false,
    },
    Desync = {
        Enabled = false, TriggerKey = "F",
        FreeCam = false, FreeCamSpeed = 60,
        UseCamForShots = false,
        engaged = false, frozenCFrame = nil,
        freezeConn = nil, camConn = nil,
        origCameraType = nil, camPos = nil,
        LastEngagedAt = 0,
    },
    Hitbox = {
        Enabled = false, Size = 5, Transparency = 0.6,
        Parts = {
            Head = false, HumanoidRootPart = true,
            UpperTorso = false, LowerTorso = false, Torso = false,
            LeftUpperArm = false, RightUpperArm = false,
            LeftUpperLeg = false, RightUpperLeg = false,
        },
    },
    Player = {
        SelectedPlayer = "",
    },
    Network = {
        RemoteSpy = {
            Enabled = false, Paused = false, Filter = "", MaxLog = 60,
        },
    },
    ESP = {
        Master = false, Box = false, BoxMode = "3D Corners", Name = true, Health = true,
        Distance = true, Tracer = false, Chams = false, Skeleton = false,
        TeamCheck = false, MaxDistance = 1000, HideOwn = true,
        RefreshRate = 0, NPCEsp = false,
        ItemList = "",
        ColorEnemy = Color3.fromRGB(255, 65, 180),
        ColorTeam  = Color3.fromRGB(80, 220, 130),
        ColorVisible   = Color3.fromRGB(80, 220, 130),
        ColorInvisible = Color3.fromRGB(255, 90, 110),
        ColorBox     = Color3.fromRGB(255, 65, 180),
        ColorName    = Color3.fromRGB(240, 240, 248),
        ColorTracer  = Color3.fromRGB(255, 65, 180),
        ColorSkeleton= Color3.fromRGB(255, 255, 255),
        ColorChamsFill    = Color3.fromRGB(255, 65, 180),
        ColorChamsOutline = Color3.fromRGB(255, 255, 255),
        DepthMode = "AlwaysOnTop",
        TracerOrigin = "Bottom",
        NameFormat = "{name} | {hp}HP | {dist}m",
    },
    Movement = {
        WalkSpeed = 16, JumpPower = 50, Gravity = 196,
        Fly = false, FlySpeed = 50, FlyKey = "E",
        Noclip = false, NoclipKey = "B", InfJump = false,
        Spinbot = false, SpinRate = 30,
        TpForwardKey = "T", TpForwardDistance = 20,
        WallClimb = false, MoonJump = false,
        SpeedBurst = false, SpeedBurstKey = "G",
        SpeedBurstMultiplier = 3, SpeedBurstDuration = 1.5,
        AntiFling = false, AntiFlingThreshold = 200,
        AntiVoid = false, AntiVoidThreshold = -200,
        PanicResetKey = "End",
        NinjaTP = {
            Enabled = false, StickDistance = 2.5,
            FaceTarget = true, TeamCheck = true, Key = "Z",
            conn = nil,
        },
    },
    Teleport = {
        Slots = {}, Waypoints = {},
        CtrlClick = false, Smooth = false, SmoothDuration = 0.5,
        TpNearestKey = "N", TpRandomKey = "M", ReturnLastKey = "Backspace",
    },
    Perms = {
        Premium = false,
        Gamepass = { Enabled = false, Whitelist = "", Blacklist = "" },
        Asset = false, Badge = false,
        Group = { Id = 0, Rank = 0, Role = "" },
        Policy = false, IsStudio = false, Owner = false,
    },
    AntiCheat = {
        Enabled = false,
        Spoof = {
            WalkSpeed = false, JumpPower = false, JumpHeight = false,
            HipHeight = false, Gravity = false,
        },
        NamecallBlocklist = "",
        AntiKick = false,
    },
    ChatSpy = {
        Enabled = false, ShowWhispers = true, ShowOtherTeam = true,
        Keywords = "", Filter = "",
    },
    Misc = {
        AntiAFK = false, FPSCap = 60, CamFOV = 70,
        Fullbright = false, NoFog = false, NoShadows = false,
        Crosshair = false, CrosshairSize = 10,
        CrosshairColor = Color3.fromRGB(255, 65, 180),
        HitMarker = false, NoRecoil = false,
        ServerHopThreshold = 5, RejoinAfterHop = false,
    },
    Theme = { Accent = C.Accent, AccentOverride = false, Preset = "Magenta" },
}

--[[ KEYBIND REGISTRY ]]
local KeyRegistry = {}
local function registerKey(name, getter, setter)
    table.insert(KeyRegistry, { name = name, get = getter, set = setter })
end

--[[ CONFIG SAVE / LOAD ]]
local CFG_FOLDER = "FREEZER"
local CFG_PATH = "FREEZER/config.json"
pcall(function() if makefolder then makefolder(CFG_FOLDER) end end)

local function serializeColor(c)
    if typeof(c) == "Color3" then
        return { __c3 = true, r = c.R, g = c.G, b = c.B }
    end
    return c
end
local function deserializeColor(t)
    if type(t) == "table" and t.__c3 then
        return Color3.new(t.r, t.g, t.b)
    end
    return t
end

local function deepCopy(v)
    if type(v) ~= "table" then return serializeColor(v) end
    local out = {}
    for k, vv in pairs(v) do out[k] = deepCopy(vv) end
    return out
end
local function deepRestore(v)
    if type(v) ~= "table" then return v end
    if v.__c3 then return deserializeColor(v) end
    local out = {}
    for k, vv in pairs(v) do out[k] = deepRestore(vv) end
    return out
end

local function saveConfig()
    if not writefile then return end
    local plain = {}
    for k, v in pairs(S) do plain[k] = deepCopy(v) end
    pcall(function() writefile(CFG_PATH, HttpService:JSONEncode(plain)) end)
end

local function loadConfig()
    if not readfile or not isfile(CFG_PATH) then return end
    pcall(function()
        local raw = readfile(CFG_PATH)
        local t = HttpService:JSONDecode(raw)
        for k, v in pairs(t or {}) do
            if S[k] and type(v) == "table" then
                for k2, v2 in pairs(v) do
                    S[k][k2] = deepRestore(v2)
                end
            end
        end
    end)
end

local function saveSlot(name)
    if not writefile then return end
    pcall(function()
        local plain = {}
        for k, v in pairs(S) do plain[k] = deepCopy(v) end
        writefile(CFG_FOLDER .. "/" .. name .. ".json", HttpService:JSONEncode(plain))
    end)
end
local function loadSlot(name)
    if not readfile then return end
    local path = CFG_FOLDER .. "/" .. name .. ".json"
    if not isfile(path) then return end
    pcall(function()
        local raw = readfile(path)
        local t = HttpService:JSONDecode(raw)
        for k, v in pairs(t or {}) do
            if S[k] and type(v) == "table" then
                for k2, v2 in pairs(v) do S[k][k2] = deepRestore(v2) end
            end
        end
    end)
end
local function deleteSlot(name)
    if not delfile then return end
    pcall(function() delfile(CFG_FOLDER .. "/" .. name .. ".json") end)
end
local function listSlots()
    local out = {}
    if not listfiles then return out end
    pcall(function()
        for _, f in ipairs(listfiles(CFG_FOLDER)) do
            local n = f:match("([^/\\]+)%.json$")
            if n and n ~= "config" then table.insert(out, n) end
        end
    end)
    return out
end

--[[ CONNECTION TRACKER ]]
local _connections = {}
local Engines = {}
local function track(c) table.insert(_connections, c); return c end
local function clearConnections()
    for _, c in ipairs(_connections) do pcall(function() c:Disconnect() end) end
    _connections = {}
end

--[[ UI HELPERS ]]
local function new(class, props)
    local i = Instance.new(class)
    if props then
        local parent = props.Parent; props.Parent = nil
        for k, v in pairs(props) do i[k] = v end
        if parent then i.Parent = parent end
    end
    return i
end

local function corner(g, r) new("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = g }) end
local function stroke(g, color, thick, transparency)
    return new("UIStroke", {
        Color = color or C.Border, Thickness = thick or 1,
        Transparency = transparency or 0, Parent = g,
    })
end
local function pad(g, p)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, p), PaddingRight = UDim.new(0, p),
        PaddingTop = UDim.new(0, p), PaddingBottom = UDim.new(0, p), Parent = g,
    })
end
local function listLayout(g, gap, dir)
    return new("UIListLayout", {
        FillDirection = dir or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 6), Parent = g,
    })
end
local function tween(o, ti, props) return TweenService:Create(o, ti or EASE, props):Play() end

--[[ SCREEN GUI WITH FALLBACK CHAIN ]]
local function makeScreenGui(name, displayOrder)
    local g = new("ScreenGui", {
        Name = name, IgnoreGuiInset = true, ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = displayOrder or 1000,
    })
    if _gethui then
        local ok = pcall(function() g.Parent = _gethui() end)
        if ok and g.Parent then return g end
    end
    local syn = safeGet("syn")
    if syn and syn.protect_gui then
        pcall(function() syn.protect_gui(g) end)
        if g.Parent then return g end
    end
    pcall(function() g.Parent = CoreGui end)
    if g.Parent then return g end
    pcall(function() g.Parent = LP:WaitForChild("PlayerGui", 5) end)
    return g
end

--[[ NOTIFICATIONS ]]
local NotifyGui = makeScreenGui("FREEZER_Notify", 99998)
local NotifyContainer = new("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -20, 0, 20),
    AnchorPoint = Vector2.new(1, 0),
    Size = UDim2.new(0, 320, 1, -40),
    Parent = NotifyGui,
})
listLayout(NotifyContainer, 8)

local function notify(title, body, accent, duration)
    accent = accent or C.Accent
    duration = duration or 3
    local f = new("Frame", {
        BackgroundColor3 = C.Card,
        Size = UDim2.new(0, 320, 0, 60),
        Position = UDim2.new(1, 40, 0, 0),
        Parent = NotifyContainer,
    })
    corner(f, 6); stroke(f, C.Border, 1)
    new("Frame", {
        BackgroundColor3 = accent, BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, 0), Parent = f,
    })
    new("TextLabel", {
        BackgroundTransparency = 1, Text = title,
        Font = Enum.Font.GothamSemibold, TextSize = 13,
        TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(1, -20, 0, 16),
        Parent = f,
    })
    new("TextLabel", {
        BackgroundTransparency = 1, Text = body or "",
        Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = C.TextSecondary, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
        Position = UDim2.new(0, 12, 0, 26), Size = UDim2.new(1, -20, 0, 30),
        Parent = f,
    })
    tween(f, EASE, { Position = UDim2.new(1, -340, 0, 0) })
    task.delay(duration, function()
        pcall(function() tween(f, EASE_FAST, { Position = UDim2.new(1, 40, 0, 0) }) end)
        task.delay(0.2, function() pcall(function() f:Destroy() end) end)
    end)
end

--[[ SPLASH â€” minimal 2s fade, can never block ]]
local function showSplash(onDone)
    local ok = pcall(function()
        local splash = makeScreenGui("FREEZER_Splash", 999999)
        local bg = new("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0), Parent = splash,
        })
        local title = new("TextLabel", {
            BackgroundTransparency = 1, Text = "FREEZER",
            Font = Enum.Font.GothamBold, TextSize = 96,
            TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 600, 0, 110),
            Parent = bg,
        })
        local s = new("UIStroke", { Color = C.Accent, Thickness = 2, Transparency = 1, Parent = title })
        local sub = new("TextLabel", {
            BackgroundTransparency = 1, Text = "v6.0.0  ::  " .. EXEC,
            Font = Enum.Font.Gotham, TextSize = 14,
            TextColor3 = C.TextDim, TextTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 70),
            Size = UDim2.new(0, 400, 0, 20),
            Parent = bg,
        })
        tween(title, TweenInfo.new(0.45, Enum.EasingStyle.Quart), { TextTransparency = 0 })
        tween(s, TweenInfo.new(0.45, Enum.EasingStyle.Quart), { Transparency = 0 })
        tween(sub, TweenInfo.new(0.6, Enum.EasingStyle.Quart), { TextTransparency = 0 })
        task.wait(1.4)
        tween(bg, TweenInfo.new(0.35), { BackgroundTransparency = 1 })
        tween(title, TweenInfo.new(0.35), { TextTransparency = 1 })
        tween(sub, TweenInfo.new(0.35), { TextTransparency = 1 })
        tween(s, TweenInfo.new(0.35), { Transparency = 1 })
        task.wait(0.45)
        pcall(function() splash:Destroy() end)
    end)
    if onDone then pcall(onDone) end
end

--[[ DYNAMIC BODY PART DETECTION ]]
local BODY_PATTERNS = {
    "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso", "Torso",
    "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
    "LeftHand", "RightHand", "LeftArm", "RightArm",
    "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
    "LeftFoot", "RightFoot", "LeftLeg", "RightLeg",
}
local BAD_NAME_KEYS = { "Handle", "Accessory", "Hat", "Hair", "Tool" }

local function isBodyPart(part, char)
    if not part:IsA("BasePart") then return false end
    if part.Parent ~= char then return false end
    local nm = part.Name
    for _, bad in ipairs(BAD_NAME_KEYS) do
        if nm:find(bad) then return false end
    end
    return true
end

local function scanBodyParts(plr)
    local out = {}
    local ok = pcall(function()
        local ch = plr and plr.Character
        if not ch then return end
        local seen = {}
        for _, name in ipairs(BODY_PATTERNS) do
            local p = ch:FindFirstChild(name)
            if p and p:IsA("BasePart") and not seen[name] then
                table.insert(out, name); seen[name] = true
            end
        end
        for _, p in ipairs(ch:GetChildren()) do
            if isBodyPart(p, ch) and not seen[p.Name] then
                table.insert(out, p.Name); seen[p.Name] = true
            end
        end
    end)
    if not ok or #out < 3 then
        return { "Head", "HumanoidRootPart", "UpperTorso", "Torso" }
    end
    table.sort(out)
    return out
end

--[[ DRAWING HELPERS WITH FRAME FALLBACK ]]
local FallbackLayer = nil
local function ensureFallbackLayer()
    if FallbackLayer then return FallbackLayer end
    FallbackLayer = makeScreenGui("FREEZER_Draw", 49000)
    return FallbackLayer
end

local function makeDrawingObj(kind)
    local obj = { _kind = kind, _visible = true, _props = {} }
    if Drawing then
        local d
        pcall(function() d = Drawing.new(kind) end)
        obj._d = d
        function obj:Set(props)
            for k, v in pairs(props) do
                self._props[k] = v
                pcall(function() self._d[k] = v end)
            end
        end
        function obj:SetVisible(b)
            self._visible = b
            pcall(function() self._d.Visible = b end)
        end
        function obj:Remove()
            pcall(function() self._d:Remove() end)
        end
        return obj
    end
    -- Frame fallback
    local layer = ensureFallbackLayer()
    local f = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        BackgroundTransparency = 0, Size = UDim2.fromOffset(2, 2),
        Visible = true, Parent = layer,
    })
    obj._f = f
    function obj:Set(props)
        for k, v in pairs(props) do
            self._props[k] = v
            if k == "Color" and typeof(v) == "Color3" then
                pcall(function() self._f.BackgroundColor3 = v end)
            elseif k == "Transparency" then
                pcall(function() self._f.BackgroundTransparency = 1 - v end)
            elseif k == "Position" then
                pcall(function() self._f.Position = UDim2.fromOffset(v.X, v.Y) end)
            elseif k == "Size" then
                if kind == "Square" then
                    pcall(function() self._f.Size = UDim2.fromOffset(v.X, v.Y) end)
                end
            elseif k == "Radius" then
                pcall(function()
                    self._f.Size = UDim2.fromOffset(v * 2, v * 2)
                    local uc = self._f:FindFirstChildOfClass("UICorner")
                    if not uc then uc = new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = self._f }) end
                end)
            elseif k == "From" then
                self._from = v
                self:_updateLine()
            elseif k == "To" then
                self._to = v
                self:_updateLine()
            elseif k == "Text" then
                pcall(function()
                    if not self._textLbl then
                        self._textLbl = new("TextLabel", {
                            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
                            Font = Enum.Font.Gotham, TextSize = props.Size or 14,
                            TextColor3 = props.Color or Color3.new(1, 1, 1),
                            Text = v, Parent = self._f,
                        })
                    else
                        self._textLbl.Text = v
                    end
                end)
            end
        end
    end
    function obj:_updateLine()
        if not self._from or not self._to then return end
        local a, b = self._from, self._to
        local dx, dy = b.X - a.X, b.Y - a.Y
        local len = math.sqrt(dx * dx + dy * dy)
        local angle = math.deg(math.atan2(dy, dx))
        pcall(function()
            self._f.Size = UDim2.fromOffset(len, self._props.Thickness or 1)
            self._f.Position = UDim2.fromOffset(a.X, a.Y)
            self._f.AnchorPoint = Vector2.new(0, 0.5)
            self._f.Rotation = angle
        end)
    end
    function obj:SetVisible(b)
        self._visible = b
        pcall(function() self._f.Visible = b end)
    end
    function obj:Remove()
        pcall(function() self._f:Destroy() end)
    end
    return obj
end

local function drawLine(thickness, color, alpha)
    local o = makeDrawingObj("Line")
    o:Set({ Thickness = thickness or 1, Color = color or Color3.new(1, 1, 1), Transparency = alpha or 1, Visible = true })
    return o
end
local function drawText(text, font, size, color)
    local o = makeDrawingObj("Text")
    o:Set({ Text = text or "", Font = font or 2, Size = size or 14, Color = color or Color3.new(1, 1, 1), Outline = true, Visible = true })
    return o
end
local function drawCircle(thickness, radius, color, filled, alpha)
    local o = makeDrawingObj("Circle")
    o:Set({ Thickness = thickness or 1, Radius = radius or 50, Color = color or Color3.new(1, 1, 1), Filled = filled or false, Transparency = alpha or 1, NumSides = 60, Visible = true })
    return o
end
local function drawQuad(color, thickness)
    local o = makeDrawingObj("Quad")
    o:Set({ Thickness = thickness or 1, Color = color or Color3.new(1, 1, 1), Transparency = 1, Visible = true })
    return o
end
local function drawSquare(size, color, thickness)
    local o = makeDrawingObj("Square")
    o:Set({ Thickness = thickness or 1, Size = size or Vector2.new(20, 20), Color = color or Color3.new(1, 1, 1), Transparency = 1, Visible = true })
    return o
end

--[[ CONTROL FACTORIES ]]
local Controls = {}

function Controls.Card(parent, title, subtitle)
    local card = new("Frame", {
        BackgroundColor3 = C.Card, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 40), AutomaticSize = Enum.AutomaticSize.Y,
        Parent = parent,
    })
    corner(card, 8); stroke(card, C.Border, 1, 0.5)
    pad(card, 14)
    local lay = listLayout(card, 8)
    if title then
        new("TextLabel", {
            BackgroundTransparency = 1, Text = title,
            Font = Enum.Font.GothamSemibold, TextSize = 14,
            TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 0, Parent = card,
        })
    end
    if subtitle then
        new("TextLabel", {
            BackgroundTransparency = 1, Text = subtitle,
            Font = Enum.Font.Gotham, TextSize = 12,
            TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Parent = card,
        })
    end
    return card
end

function Controls.Section(parent, title)
    local sec = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24),
        LayoutOrder = #parent:GetChildren(), Parent = parent,
    })
    new("TextLabel", {
        BackgroundTransparency = 1, Text = title,
        Font = Enum.Font.GothamSemibold, TextSize = 12,
        TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 16), Parent = sec,
    })
    new("Frame", {
        BackgroundColor3 = C.Border, BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -2),
        Size = UDim2.new(1, 0, 0, 1), Parent = sec,
    })
    return sec
end

local function makeRow(parent, label)
    local row = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32),
        LayoutOrder = #parent:GetChildren(), Parent = parent,
    })
    if label then
        new("TextLabel", {
            BackgroundTransparency = 1, Text = label,
            Font = Enum.Font.Gotham, TextSize = 13,
            TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(0.55, 0, 1, 0), Parent = row,
        })
    end
    return row
end

function Controls.Toggle(parent, label, default, callback)
    local row = makeRow(parent, label)
    local box = new("Frame", {
        BackgroundColor3 = default and C.Accent or C.CardHover,
        BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 40, 0, 22),
        Parent = row,
    })
    corner(box, 11)
    local knob = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Position = default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
        Size = UDim2.new(0, 18, 0, 18), Parent = box,
    })
    corner(knob, 9)
    local state = default
    local btn = new("TextButton", {
        BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 0, 1, 0),
        Parent = row,
    })
    local function apply(v)
        state = v
        tween(box, EASE_FAST, { BackgroundColor3 = v and C.Accent or C.CardHover })
        tween(knob, EASE_FAST, { Position = v and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9) })
        if callback then pcall(callback, v) end
    end
    btn.MouseButton1Click:Connect(function() apply(not state); saveConfig() end)
    return { Set = apply, Get = function() return state end, Frame = row }
end

function Controls.Slider(parent, label, min, max, default, decimals, callback)
    decimals = decimals or 0
    local row = makeRow(parent, label)
    local val = default
    local trackFrame = new("Frame", {
        BackgroundColor3 = C.CardHover, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -50, 0.5, 0),
        Size = UDim2.new(0, 160, 0, 4),
        Parent = row,
    })
    corner(trackFrame, 2)
    local fill = new("Frame", {
        BackgroundColor3 = C.Accent, BorderSizePixel = 0,
        Size = UDim2.new((val - min) / (max - min), 0, 1, 0),
        Parent = trackFrame,
    })
    corner(fill, 2)
    local knob = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        Position = UDim2.new((val - min) / (max - min), -7, 0.5, -7),
        Size = UDim2.new(0, 14, 0, 14), Parent = trackFrame,
    })
    corner(knob, 7)
    local valLbl = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -42, 0.5, -8), Size = UDim2.new(0, 42, 0, 16),
        Font = Enum.Font.Code, TextSize = 12,
        TextColor3 = C.TextSecondary, TextXAlignment = Enum.TextXAlignment.Right,
        Text = tostring(default), Parent = row,
    })
    local function fmt(v)
        if decimals == 0 then return tostring(math.floor(v + 0.5)) end
        local m = 10 ^ decimals
        return tostring(math.floor(v * m + 0.5) / m)
    end
    local function set(v, fire)
        val = math.clamp(v, min, max)
        local pct = (val - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, -7, 0.5, -7)
        valLbl.Text = fmt(val)
        if fire and callback then pcall(callback, tonumber(fmt(val))) end
    end
    local dragging = false
    track(trackFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if dragging then dragging = false; saveConfig() end
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local pct = math.clamp((input.Position.X - trackFrame.AbsolutePosition.X) / trackFrame.AbsoluteSize.X, 0, 1)
            set(min + pct * (max - min), true)
        end
    end))
    return { Set = function(v) set(v, true) end, Get = function() return val end }
end

function Controls.Dropdown(parent, label, options, default, callback)
    local row = makeRow(parent, label)
    local val = default
    local btn = new("TextButton", {
        BackgroundColor3 = C.Content, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 140, 0, 26),
        Text = "  " .. tostring(default) .. "  v",
        Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    corner(btn, 4); stroke(btn, C.Border, 1)
    local open, list = false, nil
    local currentOptions = options
    local function build()
        if list then list:Destroy(); list = nil end
        list = new("Frame", {
            BackgroundColor3 = C.Content, BorderSizePixel = 0,
            Position = UDim2.fromOffset(btn.AbsolutePosition.X, btn.AbsolutePosition.Y + 30),
            Size = UDim2.new(0, 140, 0, math.min(#currentOptions, 6) * 26),
            Parent = NotifyGui,
        })
        corner(list, 4); stroke(list, C.Border, 1)
        local sf = new("ScrollingFrame", {
            BackgroundTransparency = 1, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(0, 0, 0, #currentOptions * 26),
            ScrollBarThickness = 2, ScrollBarImageColor3 = C.Accent,
            Parent = list,
        })
        listLayout(sf, 0)
        for _, opt in ipairs(currentOptions) do
            local item = new("TextButton", {
                BackgroundColor3 = C.Content,
                BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 26),
                Text = "  " .. tostring(opt), Font = Enum.Font.Gotham, TextSize = 12,
                TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false, Parent = sf,
            })
            item.MouseEnter:Connect(function() item.BackgroundColor3 = C.CardHover end)
            item.MouseLeave:Connect(function() item.BackgroundColor3 = C.Content end)
            item.MouseButton1Click:Connect(function()
                val = opt
                btn.Text = "  " .. tostring(opt) .. "  v"
                list:Destroy(); list = nil; open = false
                if callback then pcall(callback, opt) end
                saveConfig()
            end)
        end
    end
    btn.MouseButton1Click:Connect(function()
        if open and list then list:Destroy(); list = nil; open = false; return end
        open = true; build()
    end)
    return {
        Get = function() return val end,
        Set = function(v) val = v; btn.Text = "  " .. tostring(v) .. "  v" end,
        Refresh = function(newOptions)
            currentOptions = newOptions
            if open then build() end
        end,
    }
end

function Controls.Button(parent, label, style, callback)
    local row = makeRow(parent, nil)
    row.Size = UDim2.new(1, 0, 0, 32)
    local bg = (style == "danger" and C.Danger) or (style == "secondary" and C.Card) or C.Accent
    local btn = new("TextButton", {
        BackgroundColor3 = bg, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 140, 0, 28),
        Text = label, Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false,
        Parent = row,
    })
    corner(btn, 4)
    btn.MouseEnter:Connect(function() tween(btn, EASE_FAST, { BackgroundTransparency = 0.15 }) end)
    btn.MouseLeave:Connect(function() tween(btn, EASE_FAST, { BackgroundTransparency = 0 }) end)
    btn.MouseButton1Click:Connect(function() pcall(callback) end)
    return btn
end

function Controls.Keybind(parent, label, default, callback)
    local row = makeRow(parent, label)
    local key = default
    local btn = new("TextButton", {
        BackgroundColor3 = C.Content, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 100, 0, 26),
        Text = tostring(default), Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = C.Text, AutoButtonColor = false, Parent = row,
    })
    corner(btn, 4); stroke(btn, C.Border, 1)
    local listening = false
    btn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        btn.Text = "..."
        local con
        con = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                key = input.KeyCode.Name
                btn.Text = key
                listening = false
                if con then con:Disconnect() end
                if callback then pcall(callback, key) end
                saveConfig()
            elseif input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.MouseButton2
                or input.UserInputType == Enum.UserInputType.MouseButton3 then
                key = input.UserInputType.Name
                btn.Text = key
                listening = false
                if con then con:Disconnect() end
                if callback then pcall(callback, key) end
                saveConfig()
            end
        end)
    end)
    return { Get = function() return key end, Set = function(v) key = v; btn.Text = v end }
end

function Controls.Textbox(parent, label, default, callback, placeholder)
    local row = makeRow(parent, label)
    local box = new("TextBox", {
        BackgroundColor3 = C.Content, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 180, 0, 26),
        Text = tostring(default or ""), PlaceholderText = placeholder or "",
        Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = C.Text, PlaceholderColor3 = C.TextDim,
        ClearTextOnFocus = false, Parent = row,
    })
    corner(box, 4)
    local s = stroke(box, C.Border, 1)
    box.Focused:Connect(function() tween(s, EASE_FAST, { Color = C.Accent }) end)
    box.FocusLost:Connect(function(enter)
        tween(s, EASE_FAST, { Color = C.Border })
        if callback then pcall(callback, box.Text, enter) end
        saveConfig()
    end)
    return { Get = function() return box.Text end, Set = function(v) box.Text = v end }
end

function Controls.MultilineTextbox(parent, label, default, callback, heightRows)
    local rows = heightRows or 4
    local wrap = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22 + rows * 18),
        LayoutOrder = #parent:GetChildren(), Parent = parent,
    })
    new("TextLabel", {
        BackgroundTransparency = 1, Text = label,
        Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 18), Parent = wrap,
    })
    local box = new("TextBox", {
        BackgroundColor3 = C.Content, BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 22),
        Size = UDim2.new(1, 0, 0, rows * 18),
        Text = tostring(default or ""), MultiLine = true,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Font = Enum.Font.Code, TextSize = 12,
        TextColor3 = C.Text, ClearTextOnFocus = false, Parent = wrap,
    })
    corner(box, 4)
    pad(box, 6)
    local s = stroke(box, C.Border, 1)
    box.Focused:Connect(function() tween(s, EASE_FAST, { Color = C.Accent }) end)
    box.FocusLost:Connect(function(enter)
        tween(s, EASE_FAST, { Color = C.Border })
        if callback then pcall(callback, box.Text, enter) end
        saveConfig()
    end)
    return { Get = function() return box.Text end, Set = function(v) box.Text = v end }
end

function Controls.ColorPicker(parent, label, defaultColor3, callback)
    local row = makeRow(parent, label)
    local color = defaultColor3 or Color3.fromRGB(255, 65, 180)
    local swatch = new("TextButton", {
        BackgroundColor3 = color, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 28, 0, 28),
        Text = "", AutoButtonColor = false, Parent = row,
    })
    corner(swatch, 4); stroke(swatch, C.Border, 1)

    local panel = nil
    local outsideConn = nil
    local function closePanel()
        if panel then pcall(function() panel:Destroy() end); panel = nil end
        if outsideConn then outsideConn:Disconnect(); outsideConn = nil end
    end

    swatch.MouseButton1Click:Connect(function()
        if panel then closePanel(); return end

        -- Decompose current color into HSV
        local curH, curS, curV
        pcall(function() curH, curS, curV = Color3.toHSV(color) end)
        curH = curH or 0; curS = curS or 1; curV = curV or 1

        -- Anchor popup relative to swatch screen position, clamped to screen
        local sw, sh = 220, 290
        local sp, ss = swatch.AbsolutePosition, swatch.AbsoluteSize
        local px = sp.X - sw + ss.X
        local py = sp.Y + ss.Y + 6
        local vp = (Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
        if px + sw > vp.X then px = vp.X - sw - 4 end
        if px < 4 then px = 4 end
        if py + sh > vp.Y then py = sp.Y - sh - 6 end
        if py < 4 then py = 4 end

        panel = new("Frame", {
            BackgroundColor3 = C.Card, BorderSizePixel = 0,
            Position = UDim2.fromOffset(px, py),
            Size = UDim2.new(0, sw, 0, sh), Parent = NotifyGui,
        })
        corner(panel, 6); stroke(panel, C.Border, 1)

        -- Header row
        local header = new("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 8),
            Size = UDim2.new(1, -20, 0, 18), Parent = panel,
        })
        new("TextLabel", {
            BackgroundTransparency = 1, Text = "Pick a color",
            Font = Enum.Font.GothamSemibold, TextSize = 13,
            TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, -24, 1, 0), Parent = header,
        })
        local closeX = new("TextButton", {
            BackgroundTransparency = 1, Text = "X",
            Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.TextSecondary,
            Position = UDim2.new(1, -18, 0, 0), Size = UDim2.new(0, 18, 1, 0),
            AutoButtonColor = false, Parent = header,
        })
        closeX.MouseButton1Click:Connect(function() closePanel() end)

        -- SV square
        local svSize = 180
        local svBox = new("Frame", {
            BackgroundColor3 = Color3.fromHSV(curH, 1, 1), BorderSizePixel = 0,
            Position = UDim2.new(0, 10, 0, 32),
            Size = UDim2.new(0, svSize, 0, svSize), Parent = panel,
        })
        corner(svBox, 4); stroke(svBox, C.Border, 1)
        -- White → hue (saturation axis)
        local satGrad = Instance.new("UIGradient")
        satGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV(curH, 1, 1)),
        })
        satGrad.Parent = svBox
        -- Overlay black gradient on Y for value
        local valOverlay = new("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0), Parent = svBox,
        })
        local valGrad = Instance.new("UIGradient")
        valGrad.Rotation = 90
        valGrad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        })
        valGrad.Parent = valOverlay
        -- Selector circle
        local svSel = new("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(curS, 0, 1 - curV, 0),
            Size = UDim2.new(0, 10, 0, 10), Parent = valOverlay,
        })
        corner(svSel, 5); stroke(svSel, Color3.new(0, 0, 0), 1)

        -- Hue bar
        local hueBar = new("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
            Position = UDim2.new(0, 10, 0, 32 + svSize + 8),
            Size = UDim2.new(0, svSize, 0, 20), Parent = panel,
        })
        corner(hueBar, 4); stroke(hueBar, C.Border, 1)
        local hueGrad = Instance.new("UIGradient")
        local hueKeys = {}
        for i = 0, 6 do
            local t = i / 6
            table.insert(hueKeys, ColorSequenceKeypoint.new(t, Color3.fromHSV(t, 1, 1)))
        end
        hueGrad.Color = ColorSequence.new(hueKeys)
        hueGrad.Parent = hueBar
        local hueThumb = new("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(curH, 0, 0.5, 0),
            Size = UDim2.new(0, 4, 1, 4), Parent = hueBar,
        })
        corner(hueThumb, 2); stroke(hueThumb, Color3.new(0, 0, 0), 1)

        -- Forward declarations so drag handlers can reference these before assignment
        local hexInputSync, previewSync

        local function recompute()
            local rgb = Color3.fromHSV(curH, curS, curV)
            color = rgb
            svBox.BackgroundColor3 = Color3.fromHSV(curH, 1, 1)
            satGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromHSV(curH, 1, 1)),
            })
            svSel.Position = UDim2.new(curS, 0, 1 - curV, 0)
            hueThumb.Position = UDim2.new(curH, 0, 0.5, 0)
        end

        -- SV drag handling
        local svDragging = false
        local function updateSV(input)
            local pos = svBox.AbsolutePosition
            local size = svBox.AbsoluteSize
            local mx = input.Position.X - pos.X
            local my = input.Position.Y - pos.Y
            curS = math.clamp(mx / size.X, 0, 1)
            curV = 1 - math.clamp(my / size.Y, 0, 1)
            recompute()
            if hexInputSync then hexInputSync() end
            if previewSync then previewSync() end
        end
        svBox.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                svDragging = true
                updateSV(input)
            end
        end)
        svBox.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                svDragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if svDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                updateSV(input)
            end
        end)

        -- Hue drag handling
        local hueDragging = false
        local function updateHue(input)
            local pos = hueBar.AbsolutePosition
            local size = hueBar.AbsoluteSize
            local mx = input.Position.X - pos.X
            curH = math.clamp(mx / size.X, 0, 1)
            recompute()
            if hexInputSync then hexInputSync() end
            if previewSync then previewSync() end
        end
        hueBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                hueDragging = true
                updateHue(input)
            end
        end)
        hueBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                hueDragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if hueDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                updateHue(input)
            end
        end)

        -- Hex input + preview swatch
        local bottomY = 32 + svSize + 8 + 20 + 8
        local hexRow = new("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, bottomY),
            Size = UDim2.new(0, svSize, 0, 22), Parent = panel,
        })
        local hexLbl = new("TextLabel", {
            BackgroundTransparency = 1, Text = "Hex",
            Font = Enum.Font.Gotham, TextSize = 12,
            TextColor3 = C.TextSecondary, TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(0, 28, 1, 0), Parent = hexRow,
        })
        local hexTB = new("TextBox", {
            BackgroundColor3 = C.Content, BorderSizePixel = 0,
            Position = UDim2.new(0, 32, 0, 0),
            Size = UDim2.new(1, -64, 1, 0),
            Text = string.format("%02X%02X%02X", math.floor(color.R*255), math.floor(color.G*255), math.floor(color.B*255)),
            Font = Enum.Font.Code, TextSize = 12, TextColor3 = C.Text,
            ClearTextOnFocus = false, Parent = hexRow,
        })
        corner(hexTB, 3); stroke(hexTB, C.Border, 1)
        local preview = new("Frame", {
            BackgroundColor3 = color, BorderSizePixel = 0,
            Position = UDim2.new(1, -28, 0, 0),
            Size = UDim2.new(0, 28, 1, 0), Parent = hexRow,
        })
        corner(preview, 3); stroke(preview, C.Border, 1)

        hexInputSync = function()
            hexTB.Text = string.format("%02X%02X%02X",
                math.floor(color.R * 255 + 0.5),
                math.floor(color.G * 255 + 0.5),
                math.floor(color.B * 255 + 0.5))
        end
        previewSync = function()
            preview.BackgroundColor3 = color
        end

        hexTB.FocusLost:Connect(function()
            local hex = (hexTB.Text or ""):gsub("[^0-9A-Fa-f]", "")
            if #hex >= 6 then
                local hr = tonumber(hex:sub(1, 2), 16)
                local hg = tonumber(hex:sub(3, 4), 16)
                local hb = tonumber(hex:sub(5, 6), 16)
                if hr and hg and hb then
                    color = Color3.fromRGB(hr, hg, hb)
                    local h2, s2, v2 = Color3.toHSV(color)
                    curH, curS, curV = h2, s2, v2
                    recompute()
                    previewSync()
                end
            end
            hexInputSync()
        end)

        -- Apply / Cancel buttons
        local btnRow = new("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, bottomY + 28),
            Size = UDim2.new(0, svSize, 0, 28), Parent = panel,
        })
        local apply = new("TextButton", {
            BackgroundColor3 = C.Accent, BorderSizePixel = 0,
            Size = UDim2.new(0.5, -4, 1, 0),
            Text = "Apply", Font = Enum.Font.GothamMedium, TextSize = 12,
            TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, Parent = btnRow,
        })
        corner(apply, 4)
        local cancel = new("TextButton", {
            BackgroundColor3 = C.Card, BorderSizePixel = 0,
            Position = UDim2.new(0.5, 4, 0, 0),
            Size = UDim2.new(0.5, -4, 1, 0),
            Text = "Cancel", Font = Enum.Font.GothamMedium, TextSize = 12,
            TextColor3 = C.Text, AutoButtonColor = false, Parent = btnRow,
        })
        corner(cancel, 4); stroke(cancel, C.Border, 1)

        apply.MouseButton1Click:Connect(function()
            swatch.BackgroundColor3 = color
            if callback then pcall(callback, color) end
            saveConfig()
            closePanel()
        end)
        cancel.MouseButton1Click:Connect(closePanel)

        recompute(); previewSync(); hexInputSync()

        task.wait(0.1)
        outsideConn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                if not panel then return end
                local mp = UserInputService:GetMouseLocation()
                local pp, ps2 = panel.AbsolutePosition, panel.AbsoluteSize
                if mp.X < pp.X or mp.X > pp.X + ps2.X or mp.Y < pp.Y or mp.Y > pp.Y + ps2.Y then
                    local sp2, ss2 = swatch.AbsolutePosition, swatch.AbsoluteSize
                    if mp.X < sp2.X or mp.X > sp2.X + ss2.X or mp.Y < sp2.Y or mp.Y > sp2.Y + ss2.Y then
                        closePanel()
                    end
                end
            end
        end)
    end)

    return {
        Get = function() return color end,
        Set = function(v) color = v; swatch.BackgroundColor3 = v end,
    }
end

--[[ HUB WINDOW ]]
local HubGui = makeScreenGui("FREEZER_Hub", 50000)
HubGui.Enabled = false

local Window = new("Frame", {
    BackgroundColor3 = C.Window, BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 880, 0, 560),
    Parent = HubGui,
})
corner(Window, 10); stroke(Window, C.Border, 1)
new("Frame", {
    BackgroundColor3 = C.Accent, BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 2), Parent = Window,
})

-- Title bar
local TitleBar = new("Frame", {
    BackgroundColor3 = C.Window, BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 2), Size = UDim2.new(1, 0, 0, 42),
    Parent = Window,
})
local Logo = new("Frame", {
    BackgroundColor3 = C.Accent, BorderSizePixel = 0,
    Position = UDim2.new(0, 16, 0.5, -7), Size = UDim2.new(0, 14, 0, 14),
    Parent = TitleBar,
})
corner(Logo, 3)
new("TextLabel", {
    BackgroundTransparency = 1, Text = "FREEZER",
    Font = Enum.Font.GothamBold, TextSize = 14,
    TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.new(0, 38, 0, 0), Size = UDim2.new(0, 200, 1, 0),
    Parent = TitleBar,
})
local CloseBtn = new("TextButton", {
    BackgroundColor3 = C.Window, BorderSizePixel = 0,
    Position = UDim2.new(1, -46, 0, 0), Size = UDim2.new(0, 46, 1, 0),
    Text = "X", Font = Enum.Font.GothamBold, TextSize = 14,
    TextColor3 = C.Text, AutoButtonColor = false,
    Parent = TitleBar,
})
CloseBtn.MouseEnter:Connect(function() tween(CloseBtn, EASE_FAST, { BackgroundColor3 = C.Danger }) end)
CloseBtn.MouseLeave:Connect(function() tween(CloseBtn, EASE_FAST, { BackgroundColor3 = C.Window }) end)
CloseBtn.MouseButton1Click:Connect(function() HubGui.Enabled = false end)

-- Make window draggable
do
    local dragging, dragStart, startPos = false, nil, nil
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = Window.Position
        end
    end)
    TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragStart
            Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                         startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- Sidebar
local Sidebar = new("Frame", {
    BackgroundColor3 = C.Sidebar, BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 44), Size = UDim2.new(0, 200, 1, -70),
    Parent = Window,
})
pad(Sidebar, 8)
local SidebarList = listLayout(Sidebar, 4)

-- Content area
local Content = new("ScrollingFrame", {
    BackgroundColor3 = C.Content, BorderSizePixel = 0,
    Position = UDim2.new(0, 200, 0, 44), Size = UDim2.new(1, -200, 1, -70),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 3, ScrollBarImageColor3 = C.Accent,
    Parent = Window,
})
pad(Content, 16)
listLayout(Content, 10)

-- Status bar
local StatusBar = new("Frame", {
    BackgroundColor3 = C.Window, BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 26),
    Parent = Window,
})
new("Frame", {
    BackgroundColor3 = C.Border, BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 1), Parent = StatusBar,
})
local StatusText = new("TextLabel", {
    BackgroundTransparency = 1, Text = "FPS -- / -- players / " .. EXEC,
    Font = Enum.Font.Code, TextSize = 11,
    TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -20, 1, 0),
    Parent = StatusBar,
})

--[[ PAGE MANAGEMENT ]]
local pages = {}
local pageOpenCallbacks = {}
local currentPage
local function showPage(name)
    for _, c in ipairs(Content:GetChildren()) do
        if c:IsA("Frame") or c:IsA("ScrollingFrame") then c.Visible = false end
    end
    if pages[name] then pages[name].Visible = true end
    for _, item in ipairs(Sidebar:GetChildren()) do
        if item:IsA("TextButton") then
            if item.Name == "Nav_" .. name then
                tween(item, EASE_FAST, { BackgroundColor3 = C.AccentSoft })
            else
                tween(item, EASE_FAST, { BackgroundColor3 = C.Sidebar })
            end
        end
    end
    currentPage = name
    if pageOpenCallbacks[name] then
        for _, cb in ipairs(pageOpenCallbacks[name]) do pcall(cb) end
    end
end

local function onPageOpen(name, cb)
    pageOpenCallbacks[name] = pageOpenCallbacks[name] or {}
    table.insert(pageOpenCallbacks[name], cb)
end

local function addNav(name, icon)
    local btn = new("TextButton", {
        Name = "Nav_" .. name,
        BackgroundColor3 = C.Sidebar, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 36), AutoButtonColor = false,
        Text = "  " .. icon .. "   " .. name,
        Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Sidebar,
    })
    corner(btn, 4)
    btn.MouseEnter:Connect(function()
        if currentPage ~= name then tween(btn, EASE_FAST, { BackgroundColor3 = C.Card }) end
    end)
    btn.MouseLeave:Connect(function()
        if currentPage ~= name then tween(btn, EASE_FAST, { BackgroundColor3 = C.Sidebar }) end
    end)
    btn.MouseButton1Click:Connect(function() showPage(name) end)
    return btn
end

local function addPage(name)
    local p = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false, Parent = Content,
    })
    listLayout(p, 8)
    pages[name] = p
    return p
end

--[[ ENGINES ]]

-- Resolve characters helper
local function getChar(plr) return plr and plr.Character end
local function getHum(plr)
    local ch = getChar(plr); return ch and ch:FindFirstChildOfClass("Humanoid")
end
local function getHRP(plr)
    local ch = getChar(plr); return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function getKeyHeld(name)
    if not name then return false end
    if name == "MouseButton1" then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    elseif name == "MouseButton2" then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    elseif name == "MouseButton3" then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3)
    else
        local kc = Enum.KeyCode[name]
        if kc then return UserInputService:IsKeyDown(kc) end
    end
    return false
end

local function predictPosition(part, mult)
    local vel = Vector3.zero
    pcall(function() vel = part.AssemblyLinearVelocity end)
    return part.Position + vel * (mult or 0.165)
end

-- Find best target (with optional ForceTarget override from Trap mode)
local function findTarget(maxFovPx, partName, teamCheck, wallCheck, prediction, predMult)
    local cam = GetCamera()
    if not cam then return nil end
    -- Trap override: if ForceTarget is set and that player is alive with a valid part, use them.
    local forced = S.Aimbot.ForceTarget
    if forced and forced.Parent and forced.Character then
        local fhum = forced.Character:FindFirstChildOfClass("Humanoid")
        local fpart = forced.Character:FindFirstChild(partName)
        if fhum and fhum.Health > 0 and fpart then
            local pos = prediction and predictPosition(fpart, predMult) or fpart.Position
            return { plr = forced, part = fpart, predPos = pos }
        end
    end
    local mousePos = UserInputService:GetMouseLocation()
    local best, bestDist = nil, maxFovPx
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local hum = getHum(plr)
            if hum and hum.Health > 0 then
                local skip = false
                if teamCheck and plr.Team and plr.Team == LP.Team then skip = true end
                if not skip then
                    local ch = plr.Character
                    local part = ch and ch:FindFirstChild(partName)
                    if part then
                        local pos = prediction and predictPosition(part, predMult) or part.Position
                        local screenPos, onScreen = cam:WorldToViewportPoint(pos)
                        if onScreen then
                            local dx = screenPos.X - mousePos.X
                            local dy = screenPos.Y - mousePos.Y
                            local dist = math.sqrt(dx * dx + dy * dy)
                            if dist < bestDist then
                                if wallCheck then
                                    local origin = cam.CFrame.Position
                                    local dir = (part.Position - origin)
                                    local params = RaycastParams.new()
                                    params.FilterType = Enum.RaycastFilterType.Exclude
                                    params.FilterDescendantsInstances = { LP.Character }
                                    local res = Workspace:Raycast(origin, dir, params)
                                    if not res or res.Instance:IsDescendantOf(ch) then
                                        best, bestDist = { plr = plr, part = part, predPos = pos }, dist
                                    end
                                else
                                    best, bestDist = { plr = plr, part = part, predPos = pos }, dist
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

-- Particles + lock animation
local function spawnLockParticles(screenPos, color)
    pcall(function()
        for i = 1, 10 do
            local p = new("Frame", {
                BackgroundColor3 = color or C.Accent, BorderSizePixel = 0,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(screenPos.X, screenPos.Y),
                Size = UDim2.fromOffset(4, 4), Parent = NotifyGui,
            })
            corner(p, 2)
            local angle = math.rad(i * 36 + math.random(-20, 20))
            local dist = math.random(35, 70)
            local ep = Vector2.new(screenPos.X + math.cos(angle) * dist, screenPos.Y + math.sin(angle) * dist)
            tween(p, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                { Position = UDim2.fromOffset(ep.X, ep.Y), BackgroundTransparency = 1 })
            task.delay(0.55, function() pcall(function() p:Destroy() end) end)
        end
        local ring = new("Frame", {
            BackgroundTransparency = 1, BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(screenPos.X, screenPos.Y),
            Size = UDim2.fromOffset(32, 32), Parent = NotifyGui,
        })
        corner(ring, 16)
        stroke(ring, color or C.Accent, 2, 0)
        tween(ring, TweenInfo.new(0.4), {
            Size = UDim2.fromOffset(80, 80),
        })
        local rs = ring:FindFirstChildOfClass("UIStroke")
        if rs then tween(rs, TweenInfo.new(0.4), { Transparency = 1 }) end
        task.delay(0.45, function() pcall(function() ring:Destroy() end) end)
    end)
end

local function playLockSound(id)
    if not id or id == "" then return end
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = id
        s.Volume = 0.5
        s.Parent = SoundService
        SoundService:PlayLocalSound(s)
        task.delay(2, function() pcall(function() s:Destroy() end) end)
    end)
end

-- FOV Circle (drives both Aimbot targeting FOV and SilentAim FOV; offset for GuiInset)
local fovCircle = nil
local fovCircleConn = nil
local function updateFovCircle()
    if not fovCircle then return end
    local mp = UserInputService:GetMouseLocation()
    -- mp from GetMouseLocation is already in screen coords with inset applied
    local aimShow = S.Aimbot.ShowFovCircle and S.Aimbot.Enabled
    local saShow = S.SilentAim.ShowFovCircle and S.SilentAim.Enabled
    local r = 0
    if aimShow and saShow then r = math.max(S.Aimbot.FOV, S.SilentAim.FOV)
    elseif aimShow then r = S.Aimbot.FOV
    elseif saShow then r = S.SilentAim.FOV
    else r = S.Aimbot.FOV end
    local col = aimShow and S.Aimbot.ColorFovCircle or S.SilentAim.ColorFovCircle
    fovCircle:Set({
        Position = mp, Radius = r,
        Color = col,
        Filled = S.Aimbot.FilledFovCircle,
        Thickness = S.Aimbot.FovCircleThickness,
        Visible = aimShow or saShow,
    })
end
Engines.startFovCircle = function()
    if fovCircle then return end
    fovCircle = drawCircle(1, 120, C.Accent, false, 1)
    fovCircleConn = RunService.RenderStepped:Connect(updateFovCircle)
end
Engines.stopFovCircle = function()
    if fovCircleConn then fovCircleConn:Disconnect(); fovCircleConn = nil end
    if fovCircle then fovCircle:Remove(); fovCircle = nil end
end

-- Lock indicator line
local lockLine = nil
local lockHighlight = nil
local function ensureLockLine()
    if not lockLine then lockLine = drawLine(1, C.Accent, 1) end
    return lockLine
end
local function clearLockHighlight()
    if lockHighlight then pcall(function() lockHighlight:Destroy() end); lockHighlight = nil end
end

-- Aimbot
local aimbotConn = nil
local stickyTarget = nil
local lastLockedTarget = nil
Engines.startAimbot = function()
    if aimbotConn then return end
    aimbotConn = RunService.RenderStepped:Connect(function()
        if not S.Master.Enabled or not S.Aimbot.Enabled then
            if lockLine then lockLine:SetVisible(false) end
            clearLockHighlight(); return
        end
        if not getKeyHeld(S.Aimbot.ActivationKey) then
            stickyTarget = nil
            if lockLine then lockLine:SetVisible(false) end
            clearLockHighlight(); return
        end
        local t
        if S.Aimbot.StickyLock and stickyTarget and getHum(stickyTarget.plr) and stickyTarget.plr.Character then
            local p = stickyTarget.plr.Character:FindFirstChild(S.Aimbot.TargetPart)
            if p then t = { plr = stickyTarget.plr, part = p, predPos = S.Aimbot.Prediction and predictPosition(p, S.Aimbot.VelocityMultiplier) or p.Position } end
        end
        if not t then
            t = findTarget(S.Aimbot.FOV, S.Aimbot.TargetPart, S.Aimbot.TeamCheck, S.Aimbot.WallCheck, S.Aimbot.Prediction, S.Aimbot.VelocityMultiplier)
            if t and S.Aimbot.StickyLock then stickyTarget = { plr = t.plr } end
        end
        if t and t.part then
            local cam = GetCamera()
            local targetPos = t.predPos or t.part.Position
            local goal = CFrame.new(cam.CFrame.Position, targetPos)
            cam.CFrame = cam.CFrame:Lerp(goal, math.clamp(1 - S.Aimbot.Smooth, 0.05, 1))
            -- Lock indicator
            if S.Aimbot.LockIndicator then
                local sp, onS = cam:WorldToViewportPoint(targetPos)
                if onS then
                    ensureLockLine()
                    local vps = cam.ViewportSize
                    lockLine:Set({
                        From = Vector2.new(vps.X / 2, vps.Y / 2),
                        To = Vector2.new(sp.X, sp.Y),
                        Color = S.Aimbot.LockIndicatorColor,
                        Visible = true,
                    })
                end
            elseif lockLine then lockLine:SetVisible(false) end
            -- Highlight
            if S.Aimbot.TargetHighlight and t.plr.Character then
                if not lockHighlight or lockHighlight.Adornee ~= t.plr.Character then
                    clearLockHighlight()
                    lockHighlight = new("Highlight", {
                        FillColor = S.Aimbot.TargetHighlightColor,
                        OutlineColor = S.Aimbot.TargetHighlightColor,
                        FillTransparency = 0.5, OutlineTransparency = 0,
                        Adornee = t.plr.Character, Parent = t.plr.Character,
                    })
                end
            else clearLockHighlight() end
            -- Particles + sound on new lock
            if lastLockedTarget ~= t.plr then
                lastLockedTarget = t.plr
                local sp, onS = cam:WorldToViewportPoint(targetPos)
                if onS then spawnLockParticles(Vector2.new(sp.X, sp.Y), S.Aimbot.LockIndicatorColor) end
                if S.Aimbot.LockSound then playLockSound(S.Aimbot.LockSoundId) end
            end
        else
            lastLockedTarget = nil
            if lockLine then lockLine:SetVisible(false) end
            clearLockHighlight()
        end
    end)
end
Engines.stopAimbot = function()
    if aimbotConn then aimbotConn:Disconnect(); aimbotConn = nil end
    if lockLine then lockLine:SetVisible(false) end
    clearLockHighlight()
    stickyTarget = nil; lastLockedTarget = nil
end

-- Trigger Bot
local triggerConn = nil
Engines.startTriggerBot = function()
    if triggerConn then return end
    triggerConn = RunService.Heartbeat:Connect(function()
        if not S.Master.Enabled or not S.TriggerBot.Enabled then return end
        if not getKeyHeld(S.TriggerBot.Key) then return end
        local target = Mouse.Target
        if not target then return end
        local model = target:FindFirstAncestorOfClass("Model")
        if not model then return end
        local plr = Players:GetPlayerFromCharacter(model)
        if not plr or plr == LP then return end
        if plr.Team and plr.Team == LP.Team then return end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        if S.TriggerBot.KnockCheck and hum:GetState() == Enum.HumanoidStateType.Dead then return end
        local jitter = math.random() * S.TriggerBot.Jitter
        task.wait(S.TriggerBot.Delay + jitter)
        pcall(function()
            local m1p = safeGet("mouse1press")
            local m1r = safeGet("mouse1release")
            if m1p then m1p() end
            task.wait(0.03)
            if m1r then m1r() end
        end)
    end)
end
Engines.stopTriggerBot = function()
    if triggerConn then triggerConn:Disconnect(); triggerConn = nil end
end

-- Click correlation for AUTO method
local silentHookInstalled = false
local mouseHitHookInstalled = false
local autoDetectedRemote = nil
local lastClickTime = 0
local recentNamecalls = {}
track(UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.UserInputType == Enum.UserInputType.MouseButton1 then
        lastClickTime = tick()
    end
end))

local function recordNamecallSample(self, method)
    if tick() - lastClickTime > 0.1 then return end
    if method ~= "FireServer" and method ~= "InvokeServer" then return end
    pcall(function()
        local path = self:GetFullName()
        recentNamecalls[path] = (recentNamecalls[path] or 0) + 1
        if recentNamecalls[path] >= 3 then
            autoDetectedRemote = path
        end
    end)
end

-- Forward declarations for cross-section subscribers
local pushRemote

-- Trigger-based fallback: when the user clicks MouseButton1, we mark a
-- Engines._pendingShot. The namecall hook below then modifies the FIRST FireServer-ish
-- call with a Vector3/CFrame arg, regardless of whether we know the method name.
-- This lets Silent Aim work even on executors that do NOT expose
-- getnamecallmethod (Solara is the prime example).
-- Use Engines table fields (zero extra locals, avoid Luau 200-local limit)
Engines._pendingShot = nil
Engines._hookRecursion = false
track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and S.SilentAim.Enabled then
        local fov = S.SilentAim.FOV or 200
        local part = S.SilentAim.TargetPart or "Head"
        local tc = S.SilentAim.TeamCheck
        local wc = S.SilentAim.WallCheck
        local target
        pcall(function() target = findTarget(fov, part, tc, wc, false, 0) end)
        if target and target.part then
            Engines._pendingShot = target
            task.delay(0.5, function() Engines._pendingShot = nil end)
        end
    end
end))

-- ============================================================
-- MINIMAL Silent Aim namecall hook (v6.4 — Solara-safe rewrite)
-- ============================================================
-- The previous big hook (which checked AntiCheat blocklist, RemoteSpy,
-- Magic Bullet, etc. on every namecall) caused input freezes on Solara
-- when newcclosure is a Lua-passthrough fallback. This minimal hook
-- does ONE thing: if a click captured a Engines._pendingShot, rewrite the next
-- FireServer call's first Vector3/CFrame arg to that shot's position.
-- Every other code path is a direct passthrough to oldNamecall — no
-- :GetFullName(), no :IsA(), no findTarget(), nothing that can throw.
-- Falls back to oldNamecall on ANY error via pcall wrapper.
local function installNamecallHook()
    if silentHookInstalled then return true end
    local ok, err = pcall(function()
        -- Re-resolve at install time in case exploit fns become available later
        hookmetamethod  = hookmetamethod  or safeGet("hookmetamethod")
        getrawmetatable = getrawmetatable or safeGet("getrawmetatable")
        newcclosure     = newcclosure     or safeGet("newcclosure") or function(f) return f end
        setreadonly     = setreadonly     or safeGet("setreadonly") or function() end
        if not getrawmetatable then error("getrawmetatable missing in this executor env") end
        local mt = getrawmetatable(game)
        if not mt then error("getrawmetatable(game) returned nil") end
        pcall(setreadonly, mt, false)
        local oldNamecall = mt.__namecall
        if not oldNamecall then error("mt.__namecall missing — game metatable unsupported") end
        mt.__namecall = newcclosure(function(self, ...)
            -- =========================================================
            -- ULTRA-MINIMAL hook body. Does ONLY trigger-based silent aim.
            -- Every other condition is a direct passthrough (oldNamecall).
            -- All work is wrapped in pcall, so any error falls back safely.
            -- =========================================================
            if Engines._hookRecursion then return oldNamecall(self, ...) end
            -- Engines._pendingShot is the gate: nothing happens unless the user just clicked.
            if not Engines._pendingShot then return oldNamecall(self, ...) end
            if not S.SilentAim.Enabled then return oldNamecall(self, ...) end
            if typeof(self) ~= "Instance" then return oldNamecall(self, ...) end

            -- Capture varargs OUTSIDE the pcall (nested fn has no '...')
            local args = table.pack(...)
            Engines._hookRecursion = true
            local override = nil
            pcall(function()
                local shot = Engines._pendingShot
                if not shot or not shot.part then return end
                -- find first Vector3 or CFrame arg and swap it
                for i = 1, args.n do
                    local a = args[i]
                    local t = typeof(a)
                    if t == "Vector3" then
                        args[i] = shot.part.Position
                        Engines._pendingShot = nil
                        override = { oldNamecall(self, table.unpack(args, 1, args.n)) }
                        return
                    elseif t == "CFrame" then
                        args[i] = CFrame.new(shot.part.Position)
                        Engines._pendingShot = nil
                        override = { oldNamecall(self, table.unpack(args, 1, args.n)) }
                        return
                    end
                end
            end)
            Engines._hookRecursion = false
            if override then return table.unpack(override) end
            -- legacy logic below kept for executors that DO have full hook env
            local method = ""
            pcall(function() method = (getnamecallmethod and getnamecallmethod()) or "" end)
            local isShotCall = (method == "FireServer" or method == "InvokeServer")
            -- AUTO correlation
            if S.SilentAim.Enabled and S.SilentAim.Method == "AUTO" and method ~= "" then
                pcall(function() recordNamecallSample(self, method) end)
            end
            -- Remote Spy subscriber (logs FireServer/InvokeServer)
            if S.Network and S.Network.RemoteSpy and S.Network.RemoteSpy.Enabled and not S.Network.RemoteSpy.Paused then
                if method == "FireServer" or method == "InvokeServer" then
                    pcall(function()
                        local path = self:GetFullName()
                        local flt = S.Network.RemoteSpy.Filter or ""
                        local pass = (flt == "") or path:lower():find(flt:lower(), 1, true) ~= nil
                        if pass then
                            local argSummary = {}
                            for i = 1, args.n do
                                argSummary[i] = typeof(args[i])
                            end
                            pushRemote(path, method, table.concat(argSummary, ","))
                        end
                    end)
                end
            end
            -- AntiCheat namecall blocklist
            if S.AntiCheat.Enabled and S.AntiCheat.NamecallBlocklist ~= "" then
                local blocked = false
                pcall(function()
                    for line in S.AntiCheat.NamecallBlocklist:gmatch("[^\r\n]+") do
                        line = line:match("^%s*(.-)%s*$")
                        if line ~= "" then
                            if (method or ""):match(line) or self:GetFullName():match(line) then
                                blocked = true; break
                            end
                        end
                    end
                end)
                if blocked then return nil end
            end
            -- AntiKick
            if S.AntiCheat.AntiKick and method == "Kick" and self == LP then
                return nil
            end
            -- Magic Bullet (only when method known and no Engines._pendingShot path matched)
            if S.MagicBullet.Enabled and isShotCall then
                local override2
                Engines._hookRecursion = true
                pcall(function()
                    local fov = 1000
                    local part = S.SilentAim.TargetPart or S.Aimbot.TargetPart or "Head"
                    local t = findTarget(fov, part, false, false, false, 0)
                    if not t or not t.part then return end
                    local hitPos = t.part.Position
                    for i = 1, args.n do
                        local a = args[i]
                        if typeof(a) == "Vector3" then
                            args[i] = hitPos
                            override2 = { oldNamecall(self, table.unpack(args, 1, args.n)) }
                            return
                        elseif typeof(a) == "CFrame" then
                            args[i] = CFrame.new(hitPos)
                            override2 = { oldNamecall(self, table.unpack(args, 1, args.n)) }
                            return
                        end
                    end
                end)
                Engines._hookRecursion = false
                if override2 then return table.unpack(override2) end
            end
            -- Workspace:Raycast spoof
            if S.SilentAim.Enabled and S.SilentAim.Method == "RaycastHook" and method == "Raycast" and self == Workspace then
                local override
                pcall(function()
                    local t = findTarget(S.SilentAim.FOV, S.SilentAim.TargetPart, S.SilentAim.TeamCheck, false, false, 0)
                    if not t or not t.part then return end
                    local origin = args[1] or Vector3.zero
                    local proxy = setmetatable({
                        Instance = t.part,
                        Position = t.part.Position,
                        Normal = Vector3.new(0, 1, 0),
                        Material = Enum.Material.Plastic,
                        Distance = (t.part.Position - origin).Magnitude,
                    }, { __index = function(_, k) return nil end })
                    override = { proxy }
                end)
                if override then Engines._hookRecursion = false; return table.unpack(override) end
            end
            Engines._hookRecursion = false  -- release guard before fallback
            return oldNamecall(self, ...)
        end)
        silentHookInstalled = true
    end)
    if not ok then
        notify("Hook", "install failed: " .. tostring(err), C.Danger, 6)
        return false
    end
    return true
end

-- Mouse.Hit __index hook (lazy)
local function installMouseHitHook()
    if mouseHitHookInstalled then return true end
    local ok, err = pcall(function()
        hookmetamethod = hookmetamethod or safeGet("hookmetamethod")
        newcclosure    = newcclosure    or safeGet("newcclosure") or function(f) return f end
        if not hookmetamethod then error("hookmetamethod missing in this executor env") end
        local oldIndex
        oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
            if checkcaller() then return oldIndex(self, key) end
            if S.SilentAim.Enabled and S.SilentAim.Method == "MouseHit" and typeof(self) == "Instance" and self:IsA("Mouse") then
                if key == "Hit" then
                    local t = findTarget(S.SilentAim.FOV, S.SilentAim.TargetPart, S.SilentAim.TeamCheck, S.SilentAim.WallCheck, false, 0)
                    if t and t.part then return CFrame.new(t.part.Position) end
                elseif key == "Target" then
                    local t = findTarget(S.SilentAim.FOV, S.SilentAim.TargetPart, S.SilentAim.TeamCheck, S.SilentAim.WallCheck, false, 0)
                    if t and t.part then return t.part end
                end
            end
            -- AntiCheat property spoof
            if S.AntiCheat.Enabled and typeof(self) == "Instance" then
                if self:IsA("Humanoid") then
                    if key == "WalkSpeed" and S.AntiCheat.Spoof.WalkSpeed then return 16 end
                    if key == "JumpPower" and S.AntiCheat.Spoof.JumpPower then return 50 end
                    if key == "JumpHeight" and S.AntiCheat.Spoof.JumpHeight then return 7.2 end
                    if key == "HipHeight" and S.AntiCheat.Spoof.HipHeight then return 2 end
                end
            end
            -- Perms spoofing
            if S.Perms.Premium and typeof(self) == "Instance" and self:IsA("Player") and key == "MembershipType" then
                return Enum.MembershipType.Premium
            end
            return oldIndex(self, key)
        end))
        mouseHitHookInstalled = true
    end)
    if not ok then
        notify("Hook", "Mouse __index install failed: " .. tostring(err), C.Danger, 6)
        return false
    end
    return true
end

-- FindPartOnRayWithIgnoreList hook
local fpoiHooked = false
local function installFpoiHook()
    if fpoiHooked then return true end
    local ok, err = pcall(function()
        hookfunction = hookfunction or safeGet("hookfunction")
        newcclosure  = newcclosure  or safeGet("newcclosure") or function(f) return f end
        if not hookfunction then error("hookfunction missing in this executor env") end
        if not Workspace.FindPartOnRayWithIgnoreList then error("Workspace.FindPartOnRayWithIgnoreList missing — legacy raycast API unavailable") end
        local old
        old = hookfunction(Workspace.FindPartOnRayWithIgnoreList, newcclosure(function(self, ray, ignore, ...)
            if checkcaller() and not S.SilentAim.Enabled then return old(self, ray, ignore, ...) end
            if S.SilentAim.Enabled and S.SilentAim.Method == "FindPart" then
                local t = findTarget(S.SilentAim.FOV, S.SilentAim.TargetPart, S.SilentAim.TeamCheck, false, false, 0)
                if t and t.part then
                    return t.part, t.part.Position, Vector3.new(0, 1, 0), Enum.Material.Plastic
                end
            end
            return old(self, ray, ignore, ...)
        end))
        fpoiHooked = true
    end)
    if not ok then
        notify("Hook", "FindPart hook install failed: " .. tostring(err), C.Danger, 6)
        return false
    end
    return true
end

-- Perms spoofer namecall (lazy)
local permsHookInstalled = false
local function installPermsHook()
    if permsHookInstalled then return true end
    local ok, err = pcall(function()
        hookmetamethod = hookmetamethod or safeGet("hookmetamethod")
        newcclosure    = newcclosure    or safeGet("newcclosure") or function(f) return f end
        if not hookmetamethod then error("hookmetamethod missing in this executor env") end
        local oldNc
        oldNc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            if checkcaller() then return oldNc(self, ...) end
            local method = ""
            pcall(function() method = (getnamecallmethod and getnamecallmethod()) or "" end)
            local args = { ... }
            if S.Perms.Gamepass.Enabled and method == "UserOwnsGamePassAsync" then
                local id = tostring(args[2] or "")
                local wl, bl = S.Perms.Gamepass.Whitelist, S.Perms.Gamepass.Blacklist
                local function listHas(s, v)
                    for line in s:gmatch("[^\r\n,]+") do
                        if line:match("^%s*" .. v .. "%s*$") then return true end
                    end
                    return false
                end
                if listHas(bl, id) then return false end
                if listHas(wl, id) then return true end
                return true
            end
            if S.Perms.Asset and method == "PlayerOwnsAsset" then return true end
            if S.Perms.Badge and method == "UserHasBadgeAsync" then return true end
            if method == "GetRankInGroup" and S.Perms.Group.Id > 0 and args[2] == S.Perms.Group.Id then
                return S.Perms.Group.Rank
            end
            if method == "GetRoleInGroup" and S.Perms.Group.Id > 0 and args[2] == S.Perms.Group.Id then
                return S.Perms.Group.Role
            end
            if method == "IsInGroup" and S.Perms.Group.Id > 0 and args[2] == S.Perms.Group.Id then
                return true
            end
            if S.Perms.Policy and method == "GetPolicyInfoForPlayerAsync" then
                return {
                    AreAdsAllowed = true,
                    ArePaidRandomItemsRestricted = false,
                    AllowedExternalLinkReferences = { "Discord", "Facebook", "Twitter", "YouTube", "Twitch" },
                    IsContentSharingAllowed = true,
                    IsPaidItemTradingAllowed = true,
                    IsSubjectToChinaPolicies = false,
                }
            end
            return oldNc(self, ...)
        end))
        permsHookInstalled = true
    end)
    if not ok then
        notify("Hook", "Perms hook install failed: " .. tostring(err), C.Danger, 6)
        return false
    end
    return true
end

-- ESP v6
local espItems = {}
local espConn = nil
local function clearOneESP(plr)
    local it = espItems[plr]
    if not it then return end
    if it.high then pcall(function() it.high:Destroy() end) end
    if it.bb then pcall(function() it.bb:Destroy() end) end
    if it.box then pcall(function() it.box:Remove() end) end
    if it.box3d then
        for _, l in ipairs(it.box3d) do pcall(function() l:Remove() end) end
    end
    if it.tracer then pcall(function() it.tracer:Remove() end) end
    if it.skeleton then
        for _, l in ipairs(it.skeleton) do pcall(function() l:Remove() end) end
    end
    espItems[plr] = nil
end
local function ensureESP(plr)
    if espItems[plr] then return espItems[plr] end
    espItems[plr] = {}
    return espItems[plr]
end

local R6_BONES = {
    { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
    { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}
local R15_BONES = {
    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}

Engines.startESP = function()
    if espConn then return end
    espConn = RunService.Heartbeat:Connect(function()
        local cam = GetCamera()
        if not cam then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LP and S.ESP.HideOwn then continue end
            local ch = plr.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local it = ensureESP(plr)
            if not S.ESP.Master or not hrp or not hum or hum.Health <= 0 then
                clearOneESP(plr); continue
            end
            local dist = (hrp.Position - cam.CFrame.Position).Magnitude
            if dist > S.ESP.MaxDistance then clearOneESP(plr); continue end
            -- onScreen check (BillboardGui-based labels still work behind us, so this is just a hint)
            local hrpSp, hrpOn = cam:WorldToViewportPoint(hrp.Position)
            if not hrpOn and not S.ESP.Chams then clearOneESP(plr); continue end
            local sameTeam = (plr.Team and plr.Team == LP.Team)
            if S.ESP.TeamCheck and sameTeam then clearOneESP(plr); continue end
            local color = sameTeam and S.ESP.ColorTeam or S.ESP.ColorEnemy
            -- Chams
            if S.ESP.Chams then
                if not it.high then
                    it.high = new("Highlight", {
                        FillColor = S.ESP.ColorChamsFill,
                        OutlineColor = S.ESP.ColorChamsOutline,
                        FillTransparency = 0.6, OutlineTransparency = 0,
                        Parent = ch,
                    })
                else
                    it.high.FillColor = S.ESP.ColorChamsFill
                    it.high.OutlineColor = S.ESP.ColorChamsOutline
                end
                pcall(function()
                    if S.ESP.DepthMode == "AlwaysOnTop" then
                        it.high.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    else
                        it.high.DepthMode = Enum.HighlightDepthMode.Occluded
                    end
                end)
            elseif it.high then it.high:Destroy(); it.high = nil end
            -- Box (multi-mode: 2D Rectangle / 3D Corners / 3D Full)
            if S.ESP.Box then
                local mode = S.ESP.BoxMode or "3D Corners"
                -- Clean up wrong-mode artifacts
                if it.boxMode ~= mode then
                    if it.box then pcall(function() it.box:Remove() end); it.box = nil end
                    if it.box3d then
                        for _, l in ipairs(it.box3d) do pcall(function() l:Remove() end) end
                        it.box3d = nil
                    end
                    it.boxMode = mode
                end
                if mode == "2D Rectangle" then
                    if not it.box then it.box = drawSquare(Vector2.new(2, 2), S.ESP.ColorBox, 1) end
                    -- Build 8 worldspace corners of bounding box then project, pick min/max
                    local cf = hrp.CFrame
                    local half = Vector3.new(2, 3, 1.5)
                    local corners3 = {
                        cf * CFrame.new( half.X,  half.Y,  half.Z),
                        cf * CFrame.new(-half.X,  half.Y,  half.Z),
                        cf * CFrame.new( half.X, -half.Y,  half.Z),
                        cf * CFrame.new(-half.X, -half.Y,  half.Z),
                        cf * CFrame.new( half.X,  half.Y, -half.Z),
                        cf * CFrame.new(-half.X,  half.Y, -half.Z),
                        cf * CFrame.new( half.X, -half.Y, -half.Z),
                        cf * CFrame.new(-half.X, -half.Y, -half.Z),
                    }
                    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                    local anyOn = false
                    for _, c in ipairs(corners3) do
                        local sp, onS = cam:WorldToViewportPoint(c.Position)
                        if onS then anyOn = true end
                        if sp.X < minX then minX = sp.X end
                        if sp.Y < minY then minY = sp.Y end
                        if sp.X > maxX then maxX = sp.X end
                        if sp.Y > maxY then maxY = sp.Y end
                    end
                    if anyOn then
                        it.box:Set({
                            Position = Vector2.new(minX, minY),
                            Size = Vector2.new(maxX - minX, maxY - minY),
                            Color = S.ESP.ColorBox, Visible = true,
                            Thickness = 1, Filled = false,
                        })
                    else
                        it.box:Set({ Visible = false })
                    end
                else
                    -- 3D Corners (24 short lines) or 3D Full (12 lines)
                    local cf = hrp.CFrame
                    local half = Vector3.new(2, 3, 1.5)
                    local c3 = {
                        cf * CFrame.new( half.X,  half.Y,  half.Z), -- 1
                        cf * CFrame.new(-half.X,  half.Y,  half.Z), -- 2
                        cf * CFrame.new( half.X, -half.Y,  half.Z), -- 3
                        cf * CFrame.new(-half.X, -half.Y,  half.Z), -- 4
                        cf * CFrame.new( half.X,  half.Y, -half.Z), -- 5
                        cf * CFrame.new(-half.X,  half.Y, -half.Z), -- 6
                        cf * CFrame.new( half.X, -half.Y, -half.Z), -- 7
                        cf * CFrame.new(-half.X, -half.Y, -half.Z), -- 8
                    }
                    local proj = {}
                    for i = 1, 8 do
                        local sp, onS = cam:WorldToViewportPoint(c3[i].Position)
                        proj[i] = { v = Vector2.new(sp.X, sp.Y), on = onS }
                    end
                    -- 12 edges of the cube
                    local edges = {
                        {1,2},{3,4},{5,6},{7,8},
                        {1,3},{2,4},{5,7},{6,8},
                        {1,5},{2,6},{3,7},{4,8},
                    }
                    it.box3d = it.box3d or {}
                    if mode == "3D Full" then
                        for i, e in ipairs(edges) do
                            if not it.box3d[i] then it.box3d[i] = drawLine(1, S.ESP.ColorBox, 1) end
                            local a, b = proj[e[1]], proj[e[2]]
                            if a.on or b.on then
                                it.box3d[i]:Set({ From = a.v, To = b.v, Color = S.ESP.ColorBox, Visible = true })
                            else
                                it.box3d[i]:Set({ Visible = false })
                            end
                        end
                        -- remove extra corner lines if mode switched
                        for i = #edges + 1, #it.box3d do
                            pcall(function() it.box3d[i]:Remove() end); it.box3d[i] = nil
                        end
                    else
                        -- 3D Corners: 24 short segments (3 per corner along each axis)
                        local seg = 0.25 -- fraction of edge length
                        local idx = 0
                        for _, e in ipairs(edges) do
                            local aIdx, bIdx = e[1], e[2]
                            local a, b = proj[aIdx], proj[bIdx]
                            -- from A toward B (short)
                            idx = idx + 1
                            if not it.box3d[idx] then it.box3d[idx] = drawLine(1, S.ESP.ColorBox, 1) end
                            local toMid = Vector2.new(a.v.X + (b.v.X - a.v.X) * seg, a.v.Y + (b.v.Y - a.v.Y) * seg)
                            if a.on or b.on then
                                it.box3d[idx]:Set({ From = a.v, To = toMid, Color = S.ESP.ColorBox, Visible = true })
                            else
                                it.box3d[idx]:Set({ Visible = false })
                            end
                            -- from B toward A (short)
                            idx = idx + 1
                            if not it.box3d[idx] then it.box3d[idx] = drawLine(1, S.ESP.ColorBox, 1) end
                            local toMid2 = Vector2.new(b.v.X + (a.v.X - b.v.X) * seg, b.v.Y + (a.v.Y - b.v.Y) * seg)
                            if a.on or b.on then
                                it.box3d[idx]:Set({ From = b.v, To = toMid2, Color = S.ESP.ColorBox, Visible = true })
                            else
                                it.box3d[idx]:Set({ Visible = false })
                            end
                        end
                        for i = idx + 1, #it.box3d do
                            pcall(function() it.box3d[i]:Remove() end); it.box3d[i] = nil
                        end
                    end
                end
            else
                if it.box then it.box:Remove(); it.box = nil end
                if it.box3d then
                    for _, l in ipairs(it.box3d) do pcall(function() l:Remove() end) end
                    it.box3d = nil
                end
                it.boxMode = nil
            end
            -- Tracer
            if S.ESP.Tracer then
                if not it.tracer then it.tracer = drawLine(1, S.ESP.ColorTracer, 1) end
                local sp, onS = cam:WorldToViewportPoint(hrp.Position)
                local vps = cam.ViewportSize
                local origin
                if S.ESP.TracerOrigin == "Bottom" then origin = Vector2.new(vps.X / 2, vps.Y)
                elseif S.ESP.TracerOrigin == "Top" then origin = Vector2.new(vps.X / 2, 0)
                elseif S.ESP.TracerOrigin == "Mouse" then origin = UserInputService:GetMouseLocation()
                else origin = Vector2.new(vps.X / 2, vps.Y / 2) end
                if onS then
                    it.tracer:Set({ From = origin, To = Vector2.new(sp.X, sp.Y), Color = S.ESP.ColorTracer, Visible = true })
                else
                    it.tracer:Set({ Visible = false })
                end
            elseif it.tracer then it.tracer:Remove(); it.tracer = nil end
            -- Skeleton
            if S.ESP.Skeleton then
                local bones = (hum.RigType == Enum.HumanoidRigType.R6) and R6_BONES or R15_BONES
                it.skeleton = it.skeleton or {}
                for i, bone in ipairs(bones) do
                    local a = ch:FindFirstChild(bone[1])
                    local b = ch:FindFirstChild(bone[2])
                    if a and b then
                        if not it.skeleton[i] then it.skeleton[i] = drawLine(1, S.ESP.ColorSkeleton, 1) end
                        local pa, oa = cam:WorldToViewportPoint(a.Position)
                        local pb, ob = cam:WorldToViewportPoint(b.Position)
                        if oa and ob then
                            it.skeleton[i]:Set({ From = Vector2.new(pa.X, pa.Y), To = Vector2.new(pb.X, pb.Y), Color = S.ESP.ColorSkeleton, Visible = true })
                        else
                            it.skeleton[i]:Set({ Visible = false })
                        end
                    end
                end
            elseif it.skeleton then
                for _, l in ipairs(it.skeleton) do pcall(function() l:Remove() end) end
                it.skeleton = nil
            end
            -- Name / health / distance
            if S.ESP.Name or S.ESP.Health or S.ESP.Distance then
                if not it.bb then
                    it.bb = new("BillboardGui", {
                        Adornee = hrp, AlwaysOnTop = true,
                        Size = UDim2.new(0, 200, 0, 60),
                        StudsOffset = Vector3.new(0, 3, 0), Parent = hrp,
                    })
                    it.lblName = new("TextLabel", {
                        BackgroundTransparency = 1, Text = "",
                        Font = Enum.Font.GothamBold, TextSize = 14,
                        TextColor3 = color, TextStrokeTransparency = 0.5,
                        Size = UDim2.new(1, 0, 0, 18), Parent = it.bb,
                    })
                    it.hpBar = new("Frame", {
                        BackgroundColor3 = Color3.fromRGB(40, 40, 40), BorderSizePixel = 0,
                        Position = UDim2.new(0.2, 0, 0, 20), Size = UDim2.new(0.6, 0, 0, 4),
                        Parent = it.bb,
                    })
                    corner(it.hpBar, 2)
                    it.hpFill = new("Frame", {
                        BackgroundColor3 = Color3.fromRGB(80, 220, 130), BorderSizePixel = 0,
                        Size = UDim2.new(1, 0, 1, 0), Parent = it.hpBar,
                    })
                    corner(it.hpFill, 2)
                    it.lblInfo = new("TextLabel", {
                        BackgroundTransparency = 1, Text = "",
                        Font = Enum.Font.Code, TextSize = 12,
                        TextColor3 = color, TextStrokeTransparency = 0.5,
                        Position = UDim2.new(0, 0, 0, 28),
                        Size = UDim2.new(1, 0, 0, 16), Parent = it.bb,
                    })
                end
                local txt = S.ESP.NameFormat or "{name}"
                txt = txt:gsub("{name}", plr.Name)
                            :gsub("{hp}", tostring(math.floor(hum.Health)))
                            :gsub("{maxhp}", tostring(math.floor(hum.MaxHealth)))
                            :gsub("{dist}", tostring(math.floor(dist)))
                it.lblName.Text = S.ESP.Name and plr.Name or ""
                it.lblName.TextColor3 = S.ESP.ColorName
                local parts = {}
                if S.ESP.Distance then table.insert(parts, string.format("%dm", math.floor(dist))) end
                it.lblInfo.Text = table.concat(parts, "  /  ")
                it.lblInfo.TextColor3 = color
                if S.ESP.Health then
                    it.hpBar.Visible = true
                    local hpct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    it.hpFill.Size = UDim2.new(hpct, 0, 1, 0)
                    it.hpFill.BackgroundColor3 = Color3.fromRGB(
                        math.floor(255 * (1 - hpct)),
                        math.floor(220 * hpct),
                        math.floor(80 * hpct)
                    )
                else
                    it.hpBar.Visible = false
                end
            elseif it.bb then it.bb:Destroy(); it.bb = nil end
        end
    end)
end
Engines.stopESP = function()
    if espConn then espConn:Disconnect(); espConn = nil end
    for plr in pairs(espItems) do clearOneESP(plr) end
end
track(Players.PlayerRemoving:Connect(clearOneESP))

-- Item / NPC ESP
local itemHighlights = {}
local npcHighlights = {}
local itemEspConn = nil
Engines.startItemEsp = function()
    if itemEspConn then return end
    itemEspConn = RunService.Heartbeat:Connect(function()
        -- Clear stale
        for inst, h in pairs(itemHighlights) do
            if not inst.Parent then pcall(function() h:Destroy() end); itemHighlights[inst] = nil end
        end
        for inst, h in pairs(npcHighlights) do
            if not inst.Parent then pcall(function() h:Destroy() end); npcHighlights[inst] = nil end
        end
        -- Items
        if S.ESP.ItemList and S.ESP.ItemList ~= "" then
            local names = {}
            for line in S.ESP.ItemList:gmatch("[^\r\n,]+") do
                line = line:match("^%s*(.-)%s*$")
                if line ~= "" then names[line:lower()] = true end
            end
            for _, inst in ipairs(Workspace:GetDescendants()) do
                if (inst:IsA("BasePart") or inst:IsA("Model")) and names[inst.Name:lower()] then
                    if not itemHighlights[inst] then
                        local h = new("Highlight", {
                            FillColor = S.ESP.ColorChamsFill,
                            OutlineColor = S.ESP.ColorChamsOutline,
                            FillTransparency = 0.5, OutlineTransparency = 0,
                            Parent = inst,
                        })
                        itemHighlights[inst] = h
                    end
                end
            end
        else
            for inst, h in pairs(itemHighlights) do pcall(function() h:Destroy() end); itemHighlights[inst] = nil end
        end
        -- NPCs
        if S.ESP.NPCEsp then
            for _, m in ipairs(Workspace:GetDescendants()) do
                if m:IsA("Model") then
                    local hum = m:FindFirstChildOfClass("Humanoid")
                    if hum and not Players:GetPlayerFromCharacter(m) and not npcHighlights[m] then
                        local h = new("Highlight", {
                            FillColor = Color3.fromRGB(255, 185, 70),
                            OutlineColor = Color3.fromRGB(255, 185, 70),
                            FillTransparency = 0.7, OutlineTransparency = 0,
                            Parent = m,
                        })
                        npcHighlights[m] = h
                    end
                end
            end
        else
            for inst, h in pairs(npcHighlights) do pcall(function() h:Destroy() end); npcHighlights[inst] = nil end
        end
    end)
end
Engines.stopItemEsp = function()
    if itemEspConn then itemEspConn:Disconnect(); itemEspConn = nil end
    for inst, h in pairs(itemHighlights) do pcall(function() h:Destroy() end) end
    for inst, h in pairs(npcHighlights) do pcall(function() h:Destroy() end) end
    itemHighlights = {}; npcHighlights = {}
end

-- Movement appliers
local function applyMovement()
    local hum = getHum(LP)
    if hum then
        pcall(function() hum.WalkSpeed = S.Movement.WalkSpeed end)
        pcall(function() hum.JumpPower = S.Movement.JumpPower end)
        pcall(function() hum.UseJumpPower = true end)
    end
    pcall(function() Workspace.Gravity = S.Movement.Gravity end)
end
track(LP.CharacterAdded:Connect(function(ch)
    ch:WaitForChild("Humanoid")
    task.wait(0.2)
    applyMovement()
end))

-- Fly
local flyBV, flyBG, flyConn
Engines.startFly = function()
    if flyBV then return end
    local hrp = getHRP(LP)
    if not hrp then notify("Fly", "No HumanoidRootPart", C.Danger); S.Movement.Fly = false; return end
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = hrp
    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    flyBG.P = 9000
    flyBG.Parent = hrp
    flyConn = RunService.RenderStepped:Connect(function()
        if not S.Movement.Fly then return end
        local cam = GetCamera()
        if not cam then return end
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end
        flyBV.Velocity = move * S.Movement.FlySpeed
        flyBG.CFrame = cam.CFrame
    end)
end
Engines.stopFly = function()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
end

-- Noclip
local noclipConn
Engines.startNoclip = function()
    if noclipConn then return end
    noclipConn = RunService.Stepped:Connect(function()
        if not S.Movement.Noclip then return end
        local ch = LP.Character
        if not ch then return end
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end)
end
Engines.stopNoclip = function()
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
end

-- Inf Jump
local infJumpConn
Engines.startInfJump = function()
    if infJumpConn then return end
    infJumpConn = UserInputService.JumpRequest:Connect(function()
        if not S.Movement.InfJump then return end
        local hum = getHum(LP)
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end
Engines.stopInfJump = function()
    if infJumpConn then infJumpConn:Disconnect(); infJumpConn = nil end
end

-- Ninja TP: teleport behind closest enemy every heartbeat while enabled
Engines.startNinjaTP = function()
    if S.Movement.NinjaTP.conn then return end
    S.Movement.NinjaTP.conn = RunService.Heartbeat:Connect(function()
        if not S.Movement.NinjaTP.Enabled then return end
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local closest, closestDist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local thrp = p.Character:FindFirstChild("HumanoidRootPart")
                local thum = p.Character:FindFirstChildOfClass("Humanoid")
                if thrp and thum and thum.Health > 0 then
                    if S.Movement.NinjaTP.TeamCheck and p.Team and p.Team == LP.Team then
                        -- skip teammate
                    else
                        local d = (thrp.Position - hrp.Position).Magnitude
                        if d < closestDist then closest, closestDist = thrp, d end
                    end
                end
            end
        end
        if closest then
            local dist = S.Movement.NinjaTP.StickDistance or 2.5
            local back = closest.CFrame * CFrame.new(0, 0, dist)
            if S.Movement.NinjaTP.FaceTarget then
                pcall(function() hrp.CFrame = CFrame.new(back.Position, closest.Position) end)
            else
                pcall(function() hrp.CFrame = CFrame.new(back.Position) end)
            end
        end
    end)
end

Engines.stopNinjaTP = function()
    if S.Movement.NinjaTP.conn then S.Movement.NinjaTP.conn:Disconnect(); S.Movement.NinjaTP.conn = nil end
end

-- Spinbot
local spinConn
Engines.startSpinbot = function()
    if spinConn then return end
    local angle = 0
    spinConn = RunService.Heartbeat:Connect(function(dt)
        if not S.Movement.Spinbot then return end
        local hrp = getHRP(LP)
        if not hrp then return end
        angle = (angle + S.Movement.SpinRate * dt) % 360
        pcall(function()
            hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(angle * 12), 0)
        end)
    end)
end
Engines.stopSpinbot = function()
    if spinConn then spinConn:Disconnect(); spinConn = nil end
end

-- Moon jump
local moonJumpConn
Engines.startMoonJump = function()
    if moonJumpConn then return end
    moonJumpConn = RunService.Heartbeat:Connect(function()
        if not S.Movement.MoonJump then return end
        local hum = getHum(LP)
        if hum and hum:GetState() == Enum.HumanoidStateType.Jumping then
            pcall(function() Workspace.Gravity = 30 end)
        end
    end)
end
Engines.stopMoonJump = function()
    if moonJumpConn then moonJumpConn:Disconnect(); moonJumpConn = nil end
    pcall(function() Workspace.Gravity = S.Movement.Gravity end)
end

-- Wall climb
local wallClimbConn
Engines.startWallClimb = function()
    if wallClimbConn then return end
    wallClimbConn = RunService.Heartbeat:Connect(function()
        if not S.Movement.WallClimb then return end
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if not UserInputService:IsKeyDown(Enum.KeyCode.Space) then return end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { ch }
        local res = Workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 3, params)
        if res then
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 50, hrp.AssemblyLinearVelocity.Z)
        end
    end)
end
Engines.stopWallClimb = function()
    if wallClimbConn then wallClimbConn:Disconnect(); wallClimbConn = nil end
end

-- Anti-fling / Anti-void
local antiFlingConn
Engines.startAntiFling = function()
    if antiFlingConn then return end
    antiFlingConn = RunService.Heartbeat:Connect(function()
        if not S.Movement.AntiFling then return end
        local hrp = getHRP(LP)
        if not hrp then return end
        local v = hrp.AssemblyLinearVelocity
        if v.Magnitude > S.Movement.AntiFlingThreshold then
            pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
        end
    end)
end
Engines.stopAntiFling = function()
    if antiFlingConn then antiFlingConn:Disconnect(); antiFlingConn = nil end
end

local antiVoidConn
local lastSafePos = nil
Engines.startAntiVoid = function()
    if antiVoidConn then return end
    antiVoidConn = RunService.Heartbeat:Connect(function()
        if not S.Movement.AntiVoid then return end
        local hrp = getHRP(LP)
        if not hrp then return end
        if hrp.Position.Y < S.Movement.AntiVoidThreshold then
            if lastSafePos then pcall(function() hrp.CFrame = CFrame.new(lastSafePos) end) end
        elseif hrp.Position.Y > S.Movement.AntiVoidThreshold + 5 then
            lastSafePos = hrp.Position
        end
    end)
end
Engines.stopAntiVoid = function()
    if antiVoidConn then antiVoidConn:Disconnect(); antiVoidConn = nil end
end

-- Ghost Desync (real position freeze)
-- When engaged: server-replicated HRP stays at frozenCFrame so enemies shoot at body,
-- while LO can move the camera (optionally free-cam) and shoot from elsewhere.
Engines.startDesync = function()
    if S.Desync.engaged then return end
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then notify("Desync", "No HumanoidRootPart", C.Danger); return end
    S.Desync.engaged = true
    S.Desync.frozenCFrame = hrp.CFrame
    S.Desync.LastEngagedAt = tick()

    S.Desync.freezeConn = RunService.Heartbeat:Connect(function()
        if not S.Desync.engaged then return end
        local h2 = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if h2 then
            pcall(function() h2.CFrame = S.Desync.frozenCFrame end)
            pcall(function() h2.AssemblyLinearVelocity = Vector3.zero end)
            pcall(function() h2.AssemblyAngularVelocity = Vector3.zero end)
        end
    end)

    if S.Desync.FreeCam then
        local cam = GetCamera()
        if cam then
            S.Desync.origCameraType = cam.CameraType
            pcall(function() cam.CameraType = Enum.CameraType.Scriptable end)
            S.Desync.camPos = cam.CFrame.Position
            S.Desync.camConn = RunService.RenderStepped:Connect(function(dt)
                if not S.Desync.engaged then return end
                local c = GetCamera()
                if not c then return end
                local move = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + c.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - c.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - c.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + c.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end
                S.Desync.camPos = S.Desync.camPos + move * (S.Desync.FreeCamSpeed or 60) * dt
                pcall(function() c.CFrame = CFrame.new(S.Desync.camPos, S.Desync.camPos + c.CFrame.LookVector) end)
            end)
        end
    end

    notify("Desync", "Body frozen at current position. You can move freely.", C.Success, 4)
end

Engines.stopDesync = function()
    S.Desync.engaged = false
    if S.Desync.freezeConn then S.Desync.freezeConn:Disconnect(); S.Desync.freezeConn = nil end
    if S.Desync.camConn then S.Desync.camConn:Disconnect(); S.Desync.camConn = nil end
    local cam = GetCamera()
    if S.Desync.origCameraType and cam then
        pcall(function() cam.CameraType = S.Desync.origCameraType end)
        S.Desync.origCameraType = nil
    end
    S.Desync.frozenCFrame = nil
    S.Desync.camPos = nil
end

-- Teleport
local lastTpPos = nil
local function teleportTo(pos)
    local hrp = getHRP(LP)
    if not hrp then return end
    lastTpPos = hrp.Position
    if S.Teleport.Smooth then
        local steps = 30
        local dur = S.Teleport.SmoothDuration
        local startCF = hrp.CFrame
        local goalCF = CFrame.new(pos)
        for i = 1, steps do
            local t = i / steps
            pcall(function() hrp.CFrame = startCF:Lerp(goalCF, t) end)
            task.wait(dur / steps)
        end
    else
        pcall(function() hrp.CFrame = CFrame.new(pos) end)
    end
end

local function tpNearestPlayer()
    local cam = GetCamera()
    if not cam then return end
    local best, bestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local hrp = getHRP(plr)
            if hrp then
                local d = (hrp.Position - cam.CFrame.Position).Magnitude
                if d < bestDist then bestDist = d; best = hrp end
            end
        end
    end
    if best then teleportTo(best.Position + Vector3.new(0, 3, 0)) end
end

local function tpRandomPlayer()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and getHRP(plr) then table.insert(list, plr) end
    end
    if #list == 0 then return end
    local pick = list[math.random(1, #list)]
    teleportTo(getHRP(pick).Position + Vector3.new(0, 3, 0))
end

-- Anti-AFK
local afkConn
Engines.startAntiAFK = function()
    if afkConn then return end
    afkConn = LP.Idled:Connect(function()
        if not S.Misc.AntiAFK then return end
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), GetCamera().CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0, 0), GetCamera().CFrame)
        end)
    end)
end
Engines.stopAntiAFK = function()
    if afkConn then afkConn:Disconnect(); afkConn = nil end
end

-- Fullbright
local origLight = {}
Engines.startFullbright = function()
    if origLight.set then return end
    origLight.Brightness = Lighting.Brightness
    origLight.ClockTime = Lighting.ClockTime
    origLight.FogEnd = Lighting.FogEnd
    origLight.OutdoorAmbient = Lighting.OutdoorAmbient
    origLight.GlobalShadows = Lighting.GlobalShadows
    origLight.set = true
    pcall(function() Lighting.Brightness = 2 end)
    pcall(function() Lighting.ClockTime = 14 end)
    pcall(function() Lighting.FogEnd = 100000 end)
    pcall(function() Lighting.OutdoorAmbient = Color3.new(1, 1, 1) end)
    pcall(function() Lighting.GlobalShadows = false end)
end
Engines.stopFullbright = function()
    if not origLight.set then return end
    pcall(function() Lighting.Brightness = origLight.Brightness end)
    pcall(function() Lighting.ClockTime = origLight.ClockTime end)
    pcall(function() Lighting.FogEnd = origLight.FogEnd end)
    pcall(function() Lighting.OutdoorAmbient = origLight.OutdoorAmbient end)
    pcall(function() Lighting.GlobalShadows = origLight.GlobalShadows end)
    origLight = {}
end

-- No fog
local origFog = {}
Engines.startNoFog = function()
    if origFog.set then return end
    origFog.FogEnd = Lighting.FogEnd
    origFog.FogStart = Lighting.FogStart
    origFog.set = true
    pcall(function() Lighting.FogEnd = 100000 end)
    pcall(function() Lighting.FogStart = 100000 end)
end
Engines.stopNoFog = function()
    if not origFog.set then return end
    pcall(function() Lighting.FogEnd = origFog.FogEnd end)
    pcall(function() Lighting.FogStart = origFog.FogStart end)
    origFog = {}
end

-- Crosshair
local crosshairObjs = nil
local crosshairConn = nil
Engines.startCrosshair = function()
    if crosshairObjs then return end
    crosshairObjs = {
        h = drawLine(1, S.Misc.CrosshairColor, 1),
        v = drawLine(1, S.Misc.CrosshairColor, 1),
    }
    crosshairConn = RunService.RenderStepped:Connect(function()
        if not S.Misc.Crosshair then
            crosshairObjs.h:SetVisible(false); crosshairObjs.v:SetVisible(false); return
        end
        local cam = GetCamera()
        if not cam then return end
        local vps = cam.ViewportSize
        local cx, cy = vps.X / 2, vps.Y / 2
        local sz = S.Misc.CrosshairSize
        crosshairObjs.h:Set({ From = Vector2.new(cx - sz, cy), To = Vector2.new(cx + sz, cy), Color = S.Misc.CrosshairColor, Visible = true })
        crosshairObjs.v:Set({ From = Vector2.new(cx, cy - sz), To = Vector2.new(cx, cy + sz), Color = S.Misc.CrosshairColor, Visible = true })
    end)
end
Engines.stopCrosshair = function()
    if crosshairConn then crosshairConn:Disconnect(); crosshairConn = nil end
    if crosshairObjs then
        crosshairObjs.h:Remove(); crosshairObjs.v:Remove(); crosshairObjs = nil
    end
end

-- Chat Spy
local chatLog = {}
local chatLogFrame = nil
local function pushChat(speaker, text, channel)
    table.insert(chatLog, { speaker = speaker, text = text, channel = channel or "All", t = os.time() })
    if #chatLog > 200 then table.remove(chatLog, 1) end
    if chatLogFrame then
        local row = new("TextLabel", {
            BackgroundTransparency = 1, Text = string.format("[%s] %s: %s", channel or "All", speaker, text),
            Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.TextSecondary,
            TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
            AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -8, 0, 0),
            Parent = chatLogFrame,
        })
        if S.ChatSpy.Keywords ~= "" then
            for kw in S.ChatSpy.Keywords:gmatch("[^\r\n,]+") do
                kw = kw:match("^%s*(.-)%s*$")
                if kw ~= "" and text:lower():find(kw:lower(), 1, true) then
                    row.TextColor3 = C.Warning
                    notify("Chat Alert", string.format("%s: %s", speaker, text), C.Warning, 4)
                    break
                end
            end
        end
    end
end

local chatSpyConns = {}
Engines.startChatSpy = function()
    if #chatSpyConns > 0 then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        table.insert(chatSpyConns, plr.Chatted:Connect(function(msg)
            if S.ChatSpy.Enabled then pushChat(plr.Name, msg, "Chat") end
        end))
    end
    table.insert(chatSpyConns, Players.PlayerAdded:Connect(function(plr)
        table.insert(chatSpyConns, plr.Chatted:Connect(function(msg)
            if S.ChatSpy.Enabled then pushChat(plr.Name, msg, "Chat") end
        end))
    end))
    if TextChatService then
        pcall(function()
            table.insert(chatSpyConns, TextChatService.MessageReceived:Connect(function(msg)
                if S.ChatSpy.Enabled then
                    pushChat(msg.TextSource and msg.TextSource.Name or "?", msg.Text, "TextChat")
                end
            end))
        end)
    end
end
Engines.stopChatSpy = function()
    for _, c in ipairs(chatSpyConns) do pcall(function() c:Disconnect() end) end
    chatSpyConns = {}
end

-- Mini Remote Spy (uses shared installNamecallHook; no second hook)
local remoteLog = {}
local remoteLogFrame = nil
pushRemote = function(path, kind, argSummary)
    local entry = { path = path, kind = kind, t = os.time(), args = argSummary or "" }
    table.insert(remoteLog, entry)
    local cap = (S.Network and S.Network.RemoteSpy and S.Network.RemoteSpy.MaxLog) or 60
    while #remoteLog > cap do table.remove(remoteLog, 1) end
    if remoteLogFrame then
        pcall(function()
            local row = new("TextLabel", {
                BackgroundTransparency = 1,
                Text = string.format("[%s] %s  (%s)", kind, path, argSummary or ""),
                Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.TextSecondary,
                TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
                AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -8, 0, 0),
                Parent = remoteLogFrame,
            })
            -- Cap the visible rows to maxLog
            local rows = {}
            for _, c in ipairs(remoteLogFrame:GetChildren()) do
                if c:IsA("TextLabel") then table.insert(rows, c) end
            end
            while #rows > cap do
                pcall(function() rows[1]:Destroy() end)
                table.remove(rows, 1)
            end
        end)
    end
end

local function installRemoteSpy()
    -- Shared with installNamecallHook; just ensure the main namecall hook is installed.
    return installNamecallHook()
end

local function quickFire(path, args)
    pcall(function()
        local obj = game
        for seg in path:gmatch("[^.]+") do obj = obj:FindFirstChild(seg) or obj[seg] end
        if obj and obj.FireServer then obj:FireServer(table.unpack(args)) end
        if obj and obj.InvokeServer then obj:InvokeServer(table.unpack(args)) end
    end)
end

--[[ BUILD PAGES ]]

-- HOME
do
    addNav("Home", "[H]")
    local p = addPage("Home")
    local c1 = Controls.Card(p, "Master", "Global kill switch.")
    Controls.Toggle(c1, "FREEZER enabled", S.Master.Enabled, function(v) S.Master.Enabled = v end)
    Controls.Keybind(c1, "Toggle hub key", S.Master.ToggleKey, function(k) S.Master.ToggleKey = k end)

    local c2 = Controls.Card(p, "Quick toggles", "Top 5.")
    Controls.Toggle(c2, "Aimbot", S.Aimbot.Enabled, function(v)
        S.Aimbot.Enabled = v
        if v then Engines.startAimbot() else Engines.stopAimbot() end
    end)
    Controls.Toggle(c2, "Silent Aim", S.SilentAim.Enabled, function(v)
        if v then if not installNamecallHook() then return end end
        S.SilentAim.Enabled = v
    end)
    Controls.Toggle(c2, "ESP Master", S.ESP.Master, function(v)
        S.ESP.Master = v
        if v then Engines.startESP() else Engines.stopESP() end
    end)
    Controls.Toggle(c2, "Fly", S.Movement.Fly, function(v)
        S.Movement.Fly = v
        if v then Engines.startFly() else Engines.stopFly() end
    end)
    Controls.Toggle(c2, "Noclip", S.Movement.Noclip, function(v)
        S.Movement.Noclip = v
        if v then Engines.startNoclip() else Engines.stopNoclip() end
    end)

    local c3 = Controls.Card(p, "Session", "Live status.")
    local lblGame = new("TextLabel", {
        BackgroundTransparency = 1, Text = "", LayoutOrder = 99,
        Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = C.TextSecondary, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 80), Parent = c3,
    })
    task.spawn(function()
        while true do
            local players = #Players:GetPlayers()
            local exec = EXEC
            local pid = game.PlaceId
            lblGame.Text = string.format("Place: %d\nPlayers: %d\nExecutor: %s\nJobId: %s",
                pid, players, exec, tostring(game.JobId):sub(1, 18))
            task.wait(2)
        end
    end)
end

-- AIM
do
    addNav("Aim", "[A]")
    local p = addPage("Aim")
    local cA = Controls.Card(p, "Aimbot", "Camera-snap aimbot. Hold activation key.")
    Controls.Toggle(cA, "Enabled", S.Aimbot.Enabled, function(v)
        S.Aimbot.Enabled = v
        if v then Engines.startAimbot(); Engines.startFovCircle() else Engines.stopAimbot() end
    end)
    Controls.Keybind(cA, "Activation key", S.Aimbot.ActivationKey, function(k) S.Aimbot.ActivationKey = k end)
    registerKey("Aimbot activation", function() return S.Aimbot.ActivationKey end, function(k) S.Aimbot.ActivationKey = k end)
    Controls.Slider(cA, "FOV (pixels)", 10, 500, S.Aimbot.FOV, 0, function(v) S.Aimbot.FOV = v end)
    Controls.Slider(cA, "Smoothing", 0, 1, S.Aimbot.Smooth, 2, function(v) S.Aimbot.Smooth = v end)
    local aimPartDD = Controls.Dropdown(cA, "Target part", { "Head", "HumanoidRootPart", "UpperTorso", "Torso" }, S.Aimbot.TargetPart, function(v) S.Aimbot.TargetPart = v end)
    Controls.Toggle(cA, "Wall check", S.Aimbot.WallCheck, function(v) S.Aimbot.WallCheck = v end)
    Controls.Toggle(cA, "Team check", S.Aimbot.TeamCheck, function(v) S.Aimbot.TeamCheck = v end)
    Controls.Toggle(cA, "Prediction", S.Aimbot.Prediction, function(v) S.Aimbot.Prediction = v end)
    Controls.Slider(cA, "Velocity multiplier", 0, 1, S.Aimbot.VelocityMultiplier, 3, function(v) S.Aimbot.VelocityMultiplier = v end)
    Controls.Toggle(cA, "Sticky lock", S.Aimbot.StickyLock, function(v) S.Aimbot.StickyLock = v end)
    Controls.Toggle(cA, "Lock indicator", S.Aimbot.LockIndicator, function(v) S.Aimbot.LockIndicator = v end)
    Controls.ColorPicker(cA, "Indicator color", S.Aimbot.LockIndicatorColor, function(v) S.Aimbot.LockIndicatorColor = v end)
    Controls.Toggle(cA, "Target highlight", S.Aimbot.TargetHighlight, function(v) S.Aimbot.TargetHighlight = v end)
    Controls.ColorPicker(cA, "Highlight color", S.Aimbot.TargetHighlightColor, function(v) S.Aimbot.TargetHighlightColor = v end)
    Controls.Toggle(cA, "Lock sound", S.Aimbot.LockSound, function(v) S.Aimbot.LockSound = v end)
    Controls.Textbox(cA, "Sound ID", S.Aimbot.LockSoundId, function(v) S.Aimbot.LockSoundId = v end, "rbxassetid://...")
    Controls.Section(cA, "FOV circle")
    Controls.Toggle(cA, "Show FOV circle", S.Aimbot.ShowFovCircle, function(v)
        S.Aimbot.ShowFovCircle = v
        if v then Engines.startFovCircle() end
    end)
    Controls.ColorPicker(cA, "Circle color", S.Aimbot.ColorFovCircle, function(v) S.Aimbot.ColorFovCircle = v end)
    Controls.Toggle(cA, "Filled", S.Aimbot.FilledFovCircle, function(v) S.Aimbot.FilledFovCircle = v end)
    Controls.Slider(cA, "Thickness", 1, 5, S.Aimbot.FovCircleThickness, 0, function(v) S.Aimbot.FovCircleThickness = v end)

    local cTB = Controls.Card(p, "Trigger Bot", "Hold key, auto-fire when crosshair over enemy.")
    Controls.Toggle(cTB, "Enabled", S.TriggerBot.Enabled, function(v)
        S.TriggerBot.Enabled = v
        if v then Engines.startTriggerBot() else Engines.stopTriggerBot() end
    end)
    Controls.Keybind(cTB, "Activation key", S.TriggerBot.Key, function(k) S.TriggerBot.Key = k end)
    registerKey("Trigger bot", function() return S.TriggerBot.Key end, function(k) S.TriggerBot.Key = k end)
    Controls.Slider(cTB, "Delay (s)", 0, 0.5, S.TriggerBot.Delay, 3, function(v) S.TriggerBot.Delay = v end)
    Controls.Slider(cTB, "Jitter (s)", 0, 0.2, S.TriggerBot.Jitter, 3, function(v) S.TriggerBot.Jitter = v end)
    Controls.Toggle(cTB, "Knock check", S.TriggerBot.KnockCheck, function(v) S.TriggerBot.KnockCheck = v end)

    local cS = Controls.Card(p, "Silent Aim", "Hooks installed lazily; never on if you leave it off.")
    Controls.Toggle(cS, "Enabled", S.SilentAim.Enabled, function(v)
        if v then
            if not installNamecallHook() then return end
            if S.SilentAim.Method == "MouseHit" then installMouseHitHook() end
            if S.SilentAim.Method == "FindPart" then installFpoiHook() end
            notify("Silent Aim", "Hook armed", C.Success, 3)
        end
        S.SilentAim.Enabled = v
    end)
    Controls.Dropdown(cS, "Method", { "AUTO", "MouseHit", "Namecall", "FindPart", "RaycastHook" }, S.SilentAim.Method, function(v)
        S.SilentAim.Method = v
        if S.SilentAim.Enabled then
            if v == "MouseHit" then installMouseHitHook() end
            if v == "FindPart" then installFpoiHook() end
        end
    end)
    Controls.Slider(cS, "FOV (pixels)", 10, 1000, S.SilentAim.FOV, 0, function(v) S.SilentAim.FOV = v end)
    local saPartDD = Controls.Dropdown(cS, "Target part", { "Head", "HumanoidRootPart", "UpperTorso", "Torso" }, S.SilentAim.TargetPart, function(v) S.SilentAim.TargetPart = v end)
    Controls.Slider(cS, "Hit chance %", 0, 100, S.SilentAim.HitChance, 0, function(v) S.SilentAim.HitChance = v end)
    Controls.Toggle(cS, "Wall check", S.SilentAim.WallCheck, function(v) S.SilentAim.WallCheck = v end)
    Controls.Toggle(cS, "Team check", S.SilentAim.TeamCheck, function(v) S.SilentAim.TeamCheck = v end)
    Controls.Toggle(cS, "Show FOV circle", S.SilentAim.ShowFovCircle, function(v)
        S.SilentAim.ShowFovCircle = v
        if v then Engines.startFovCircle() end
    end)
    Controls.ColorPicker(cS, "FOV circle color", S.SilentAim.ColorFovCircle, function(v) S.SilentAim.ColorFovCircle = v end)
    Controls.Textbox(cS, "Remote path", S.SilentAim.RemotePath, function(v) S.SilentAim.RemotePath = v end, "auto-detect if empty")
    Controls.Button(cS, "Use auto-detected", "secondary", function()
        if autoDetectedRemote then
            S.SilentAim.RemotePath = autoDetectedRemote
            notify("Silent Aim", "Detected: " .. autoDetectedRemote, C.Success, 4)
        else
            notify("Silent Aim", "No remote detected yet. Click while shooting.", C.Warning, 4)
        end
    end)

    local cMB = Controls.Card(p, "Magic Bullet", "Uses Silent Aim hook. Force-hit through walls.")
    Controls.Toggle(cMB, "Enabled", S.MagicBullet.Enabled, function(v)
        if v then installNamecallHook() end
        S.MagicBullet.Enabled = v
    end)
    Controls.Dropdown(cMB, "Mode", { "Direct", "Wall-Pen", "Arc" }, S.MagicBullet.Mode, function(v) S.MagicBullet.Mode = v end)
    Controls.Textbox(cMB, "Bullet remote", S.MagicBullet.RemotePath, function(v) S.MagicBullet.RemotePath = v end, "auto-detect if empty")
    Controls.Button(cMB, "Use auto-detected", "secondary", function()
        if autoDetectedRemote then S.MagicBullet.RemotePath = autoDetectedRemote
            notify("Magic Bullet", "Detected: " .. autoDetectedRemote, C.Success, 4)
        end
    end)
    Controls.Toggle(cMB, "Force hit", S.MagicBullet.ForceHit, function(v) S.MagicBullet.ForceHit = v end)
    Controls.Slider(cMB, "Range", 50, 5000, S.MagicBullet.Range, 0, function(v) S.MagicBullet.Range = v end)
    Controls.Slider(cMB, "Max BPS", 1, 100, S.MagicBullet.MaxBPS, 0, function(v) S.MagicBullet.MaxBPS = v end)
    Controls.Slider(cMB, "Jitter", 0, 1, S.MagicBullet.Jitter, 2, function(v) S.MagicBullet.Jitter = v end)

    onPageOpen("Aim", function()
        local t = findTarget(99999, "Head", false, false, false, 0)
        local parts = scanBodyParts(t and t.plr or LP)
        aimPartDD.Refresh(parts)
        saPartDD.Refresh(parts)
    end)
end

-- VISUAL
do
    addNav("Visual", "[V]")
    local p = addPage("Visual")
    local cE = Controls.Card(p, "ESP master", "Player highlights / labels.")
    Controls.Toggle(cE, "Master ESP", S.ESP.Master, function(v)
        S.ESP.Master = v
        if v then Engines.startESP() else Engines.stopESP() end
    end)
    Controls.Toggle(cE, "Hide own player", S.ESP.HideOwn, function(v) S.ESP.HideOwn = v end)
    Controls.Slider(cE, "Max distance", 50, 5000, S.ESP.MaxDistance, 0, function(v) S.ESP.MaxDistance = v end)
    Controls.Slider(cE, "Refresh rate (Hz)", 0, 60, S.ESP.RefreshRate, 0, function(v) S.ESP.RefreshRate = v end)

    local cF = Controls.Card(p, "Features", "Toggle any feature.")
    Controls.Toggle(cF, "Box", S.ESP.Box, function(v) S.ESP.Box = v end)
    Controls.Dropdown(cF, "Box mode", { "2D Rectangle", "3D Corners", "3D Full" }, S.ESP.BoxMode, function(v) S.ESP.BoxMode = v end)
    Controls.Toggle(cF, "Name", S.ESP.Name, function(v) S.ESP.Name = v end)
    Controls.Toggle(cF, "Health bar", S.ESP.Health, function(v) S.ESP.Health = v end)
    Controls.Toggle(cF, "Distance", S.ESP.Distance, function(v) S.ESP.Distance = v end)
    Controls.Toggle(cF, "Tracer", S.ESP.Tracer, function(v) S.ESP.Tracer = v end)
    Controls.Dropdown(cF, "Tracer origin", { "Bottom", "Top", "Center", "Mouse" }, S.ESP.TracerOrigin, function(v) S.ESP.TracerOrigin = v end)
    Controls.Toggle(cF, "Skeleton", S.ESP.Skeleton, function(v) S.ESP.Skeleton = v end)
    Controls.Toggle(cF, "Chams (Highlight)", S.ESP.Chams, function(v) S.ESP.Chams = v end)
    Controls.Dropdown(cF, "Chams depth", { "AlwaysOnTop", "Occluded" }, S.ESP.DepthMode, function(v) S.ESP.DepthMode = v end)
    Controls.Textbox(cF, "Name format", S.ESP.NameFormat, function(v) S.ESP.NameFormat = v end, "{name} | {hp}HP | {dist}m")

    local cC = Controls.Card(p, "Colors", "Per-feature color.")
    Controls.ColorPicker(cC, "Enemy", S.ESP.ColorEnemy, function(v) S.ESP.ColorEnemy = v end)
    Controls.ColorPicker(cC, "Team", S.ESP.ColorTeam, function(v) S.ESP.ColorTeam = v end)
    Controls.ColorPicker(cC, "Visible", S.ESP.ColorVisible, function(v) S.ESP.ColorVisible = v end)
    Controls.ColorPicker(cC, "Invisible", S.ESP.ColorInvisible, function(v) S.ESP.ColorInvisible = v end)
    Controls.ColorPicker(cC, "Box", S.ESP.ColorBox, function(v) S.ESP.ColorBox = v end)
    Controls.ColorPicker(cC, "Name", S.ESP.ColorName, function(v) S.ESP.ColorName = v end)
    Controls.ColorPicker(cC, "Tracer", S.ESP.ColorTracer, function(v) S.ESP.ColorTracer = v end)
    Controls.ColorPicker(cC, "Skeleton", S.ESP.ColorSkeleton, function(v) S.ESP.ColorSkeleton = v end)
    Controls.ColorPicker(cC, "Chams fill", S.ESP.ColorChamsFill, function(v) S.ESP.ColorChamsFill = v end)
    Controls.ColorPicker(cC, "Chams outline", S.ESP.ColorChamsOutline, function(v) S.ESP.ColorChamsOutline = v end)

    local cFi = Controls.Card(p, "Filters", "Skip / include.")
    Controls.Toggle(cFi, "Skip teammates", S.ESP.TeamCheck, function(v) S.ESP.TeamCheck = v end)

    local cI = Controls.Card(p, "Item / NPC ESP", "Highlight world items + NPC humanoids.")
    Controls.MultilineTextbox(cI, "Item names (one per line)", S.ESP.ItemList, function(v)
        S.ESP.ItemList = v
        if v ~= "" or S.ESP.NPCEsp then Engines.startItemEsp() else Engines.stopItemEsp() end
    end, 4)
    Controls.Toggle(cI, "NPC ESP (humanoids)", S.ESP.NPCEsp, function(v)
        S.ESP.NPCEsp = v
        if v or S.ESP.ItemList ~= "" then Engines.startItemEsp() else Engines.stopItemEsp() end
    end)
end

-- MOVEMENT
do
    addNav("Movement", "[M]")
    local p = addPage("Movement")
    local c1 = Controls.Card(p, "Speed & jump", "Applies on respawn too.")
    Controls.Slider(c1, "WalkSpeed", 0, 500, S.Movement.WalkSpeed, 0, function(v) S.Movement.WalkSpeed = v; applyMovement() end)
    Controls.Slider(c1, "JumpPower", 0, 500, S.Movement.JumpPower, 0, function(v) S.Movement.JumpPower = v; applyMovement() end)
    Controls.Slider(c1, "Gravity", 0, 300, S.Movement.Gravity, 0, function(v) S.Movement.Gravity = v; applyMovement() end)

    local c2 = Controls.Card(p, "Abilities", "WASD + Space/LCtrl during fly.")
    Controls.Toggle(c2, "Fly", S.Movement.Fly, function(v)
        S.Movement.Fly = v
        if v then Engines.startFly() else Engines.stopFly() end
    end)
    Controls.Slider(c2, "Fly speed", 10, 300, S.Movement.FlySpeed, 0, function(v) S.Movement.FlySpeed = v end)
    Controls.Keybind(c2, "Fly toggle key", S.Movement.FlyKey, function(k) S.Movement.FlyKey = k end)
    registerKey("Fly toggle", function() return S.Movement.FlyKey end, function(k) S.Movement.FlyKey = k end)
    Controls.Toggle(c2, "Noclip", S.Movement.Noclip, function(v)
        S.Movement.Noclip = v
        if v then Engines.startNoclip() else Engines.stopNoclip() end
    end)
    Controls.Keybind(c2, "Noclip toggle key", S.Movement.NoclipKey, function(k) S.Movement.NoclipKey = k end)
    registerKey("Noclip toggle", function() return S.Movement.NoclipKey end, function(k) S.Movement.NoclipKey = k end)
    Controls.Toggle(c2, "Infinite jump", S.Movement.InfJump, function(v)
        S.Movement.InfJump = v
        if v then Engines.startInfJump() else Engines.stopInfJump() end
    end)
    Controls.Toggle(c2, "Spinbot", S.Movement.Spinbot, function(v)
        S.Movement.Spinbot = v
        if v then Engines.startSpinbot() else Engines.stopSpinbot() end
    end)
    Controls.Slider(c2, "Spin rate", 1, 100, S.Movement.SpinRate, 0, function(v) S.Movement.SpinRate = v end)
    Controls.Toggle(c2, "Moon jump", S.Movement.MoonJump, function(v)
        S.Movement.MoonJump = v
        if v then Engines.startMoonJump() else Engines.stopMoonJump() end
    end)
    Controls.Toggle(c2, "Wall climb", S.Movement.WallClimb, function(v)
        S.Movement.WallClimb = v
        if v then Engines.startWallClimb() else Engines.stopWallClimb() end
    end)
    Controls.Keybind(c2, "TP forward key", S.Movement.TpForwardKey, function(k) S.Movement.TpForwardKey = k end)
    registerKey("TP forward", function() return S.Movement.TpForwardKey end, function(k) S.Movement.TpForwardKey = k end)
    Controls.Slider(c2, "TP forward distance", 5, 100, S.Movement.TpForwardDistance, 0, function(v) S.Movement.TpForwardDistance = v end)
    Controls.Keybind(c2, "Speed burst key", S.Movement.SpeedBurstKey, function(k) S.Movement.SpeedBurstKey = k end)
    registerKey("Speed burst", function() return S.Movement.SpeedBurstKey end, function(k) S.Movement.SpeedBurstKey = k end)
    Controls.Slider(c2, "Burst multiplier", 1, 10, S.Movement.SpeedBurstMultiplier, 1, function(v) S.Movement.SpeedBurstMultiplier = v end)
    Controls.Slider(c2, "Burst duration", 0.5, 5, S.Movement.SpeedBurstDuration, 1, function(v) S.Movement.SpeedBurstDuration = v end)

    local c3 = Controls.Card(p, "Safety", "Anti-fling, anti-void, panic reset.")
    Controls.Toggle(c3, "Anti-fling", S.Movement.AntiFling, function(v)
        S.Movement.AntiFling = v
        if v then Engines.startAntiFling() else Engines.stopAntiFling() end
    end)
    Controls.Slider(c3, "Fling threshold", 50, 1000, S.Movement.AntiFlingThreshold, 0, function(v) S.Movement.AntiFlingThreshold = v end)
    Controls.Toggle(c3, "Anti-void", S.Movement.AntiVoid, function(v)
        S.Movement.AntiVoid = v
        if v then Engines.startAntiVoid() else Engines.stopAntiVoid() end
    end)
    Controls.Slider(c3, "Void threshold (Y)", -1000, 0, S.Movement.AntiVoidThreshold, 0, function(v) S.Movement.AntiVoidThreshold = v end)
    Controls.Keybind(c3, "Panic reset key", S.Movement.PanicResetKey, function(k) S.Movement.PanicResetKey = k end)
    registerKey("Panic reset", function() return S.Movement.PanicResetKey end, function(k) S.Movement.PanicResetKey = k end)

    local cN = Controls.Card(p, "Ninja TP", "Stick behind closest enemy every Heartbeat.")
    Controls.Toggle(cN, "Ninja TP enabled", S.Movement.NinjaTP.Enabled, function(v)
        S.Movement.NinjaTP.Enabled = v
        if v then Engines.startNinjaTP() else Engines.stopNinjaTP() end
    end)
    Controls.Slider(cN, "Stick distance", 1, 10, S.Movement.NinjaTP.StickDistance, 1, function(v) S.Movement.NinjaTP.StickDistance = v end)
    Controls.Toggle(cN, "Face target", S.Movement.NinjaTP.FaceTarget, function(v) S.Movement.NinjaTP.FaceTarget = v end)
    Controls.Toggle(cN, "Team check", S.Movement.NinjaTP.TeamCheck, function(v) S.Movement.NinjaTP.TeamCheck = v end)
    Controls.Keybind(cN, "Activation key", S.Movement.NinjaTP.Key, function(k) S.Movement.NinjaTP.Key = k end)
    registerKey("Ninja TP toggle", function() return S.Movement.NinjaTP.Key end, function(k) S.Movement.NinjaTP.Key = k end)
end

-- WORLD
do
    addNav("World", "[W]")
    local p = addPage("World")
    local cT = Controls.Card(p, "Teleport", "Player TP + offset + waypoints.")
    local playerNames = {}
    for _, plr in ipairs(Players:GetPlayers()) do if plr ~= LP then table.insert(playerNames, plr.Name) end end
    if #playerNames == 0 then playerNames = { "(no other players)" } end
    local tpDD = Controls.Dropdown(cT, "TP to player", playerNames, playerNames[1], function() end)
    local offX = Controls.Slider(cT, "Offset X", -50, 50, 0, 0, function() end)
    local offY = Controls.Slider(cT, "Offset Y", -50, 50, 3, 0, function() end)
    local offZ = Controls.Slider(cT, "Offset Z", -50, 50, 0, 0, function() end)
    Controls.Button(cT, "Go", "primary", function()
        local name = tpDD.Get()
        local plr = Players:FindFirstChild(name)
        if not plr then notify("Teleport", "Player not found", C.Danger); return end
        local hrp = getHRP(plr)
        if hrp then teleportTo(hrp.Position + Vector3.new(offX.Get(), offY.Get(), offZ.Get())) end
    end)
    Controls.Toggle(cT, "Ctrl+Click TP", S.Teleport.CtrlClick, function(v) S.Teleport.CtrlClick = v end)
    Controls.Toggle(cT, "Smooth TP", S.Teleport.Smooth, function(v) S.Teleport.Smooth = v end)
    Controls.Slider(cT, "Smooth duration", 0.1, 3, S.Teleport.SmoothDuration, 2, function(v) S.Teleport.SmoothDuration = v end)
    Controls.Keybind(cT, "TP nearest key", S.Teleport.TpNearestKey, function(k) S.Teleport.TpNearestKey = k end)
    registerKey("TP nearest", function() return S.Teleport.TpNearestKey end, function(k) S.Teleport.TpNearestKey = k end)
    Controls.Keybind(cT, "TP random key", S.Teleport.TpRandomKey, function(k) S.Teleport.TpRandomKey = k end)
    registerKey("TP random", function() return S.Teleport.TpRandomKey end, function(k) S.Teleport.TpRandomKey = k end)
    Controls.Keybind(cT, "Return last key", S.Teleport.ReturnLastKey, function(k) S.Teleport.ReturnLastKey = k end)
    registerKey("Return last", function() return S.Teleport.ReturnLastKey end, function(k) S.Teleport.ReturnLastKey = k end)

    local cSlots = Controls.Card(p, "Save slots", "10 position slots.")
    for i = 1, 10 do
        local r = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), Parent = cSlots })
        new("TextLabel", {
            BackgroundTransparency = 1, Text = "Slot " .. i,
            Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(0, 60, 1, 0), Parent = r,
        })
        local saveBtn = new("TextButton", {
            BackgroundColor3 = C.Accent, BorderSizePixel = 0,
            Position = UDim2.new(0, 70, 0.5, -11), Size = UDim2.new(0, 70, 0, 22),
            Text = "Save", Font = Enum.Font.GothamMedium, TextSize = 11,
            TextColor3 = Color3.new(1, 1, 1), Parent = r,
        })
        corner(saveBtn, 3)
        local loadBtn = new("TextButton", {
            BackgroundColor3 = C.Card, BorderSizePixel = 0,
            Position = UDim2.new(0, 148, 0.5, -11), Size = UDim2.new(0, 70, 0, 22),
            Text = "Load", Font = Enum.Font.GothamMedium, TextSize = 11,
            TextColor3 = C.Text, Parent = r,
        })
        corner(loadBtn, 3); stroke(loadBtn, C.Border, 1)
        saveBtn.MouseButton1Click:Connect(function()
            local hrp = getHRP(LP)
            if hrp then
                S.Teleport.Slots[i] = { x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z }
                notify("Teleport", "Slot " .. i .. " saved", C.Success); saveConfig()
            end
        end)
        loadBtn.MouseButton1Click:Connect(function()
            local s = S.Teleport.Slots[i]
            if s then teleportTo(Vector3.new(s.x, s.y, s.z))
            else notify("Teleport", "Slot " .. i .. " empty", C.Warning) end
        end)
    end

    local cCam = Controls.Card(p, "Camera", "FOV + freecam.")
    Controls.Slider(cCam, "Camera FOV", 30, 120, S.Misc.CamFOV, 0, function(v)
        S.Misc.CamFOV = v
        local cam = GetCamera()
        if cam then pcall(function() cam.FieldOfView = v end) end
    end)

    local cSrv = Controls.Card(p, "Server", "Hop, rejoin.")
    Controls.Slider(cSrv, "Server hop threshold", 1, 30, S.Misc.ServerHopThreshold, 0, function(v) S.Misc.ServerHopThreshold = v end)
    Controls.Button(cSrv, "Server hop", "primary", function()
        pcall(function()
            local s = HttpService:JSONDecode(game:HttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?limit=100", game.PlaceId)))
            if s and s.data then
                for _, srv in ipairs(s.data) do
                    if srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, srv.id, LP); return
                    end
                end
            end
        end)
    end)
    Controls.Button(cSrv, "Rejoin", "secondary", function()
        TeleportService:Teleport(game.PlaceId, LP)
    end)
end

-- COMBAT
do
    addNav("Combat", "[K]")
    local p = addPage("Combat")
    local cD = Controls.Card(p, "Ghost Desync", "Freezes your server-replicated body where you are. Enemies shoot your frozen body; you keep moving.")
    Controls.Toggle(cD, "Enabled", S.Desync.Enabled, function(v)
        S.Desync.Enabled = v
        if v then Engines.startDesync() else Engines.stopDesync() end
    end)
    Controls.Toggle(cD, "FreeCam mode while desync", S.Desync.FreeCam, function(v)
        S.Desync.FreeCam = v
        if S.Desync.engaged then
            Engines.stopDesync()
            if S.Desync.Enabled then Engines.startDesync() end
        end
    end)
    Controls.Slider(cD, "FreeCam speed", 10, 200, S.Desync.FreeCamSpeed, 0, function(v) S.Desync.FreeCamSpeed = v end)
    Controls.Toggle(cD, "Use camera position for shots", S.Desync.UseCamForShots, function(v) S.Desync.UseCamForShots = v end)
    Controls.Keybind(cD, "Toggle trigger key", S.Desync.TriggerKey, function(k) S.Desync.TriggerKey = k end)
    registerKey("Desync toggle", function() return S.Desync.TriggerKey end, function(k) S.Desync.TriggerKey = k end)

    local cH = Controls.Card(p, "Hitbox extender", "Resize enemy parts. Per-part toggles.")
    Controls.Toggle(cH, "Enabled", S.Hitbox.Enabled, function(v) S.Hitbox.Enabled = v end)
    Controls.Slider(cH, "Size (studs)", 2, 30, S.Hitbox.Size, 0, function(v) S.Hitbox.Size = v end)
    Controls.Slider(cH, "Transparency", 0, 1, S.Hitbox.Transparency, 2, function(v) S.Hitbox.Transparency = v end)

    -- Per-part toggles dynamic container
    local hbPartsContainer = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 98, Parent = cH,
    })
    listLayout(hbPartsContainer, 4)
    local function rebuildHbToggles()
        for _, c in ipairs(hbPartsContainer:GetChildren()) do
            if not c:IsA("UIListLayout") then pcall(function() c:Destroy() end) end
        end
        local detected = scanBodyParts(LP)
        local seen = {}
        for _, name in ipairs(detected) do
            if S.Hitbox.Parts[name] == nil then S.Hitbox.Parts[name] = (name == "HumanoidRootPart") end
            seen[name] = true
            local nameLocal = name
            Controls.Toggle(hbPartsContainer, "Part: " .. nameLocal, S.Hitbox.Parts[nameLocal], function(v) S.Hitbox.Parts[nameLocal] = v end)
        end
        -- Keep existing toggles for known body parts not currently in character
        for partName, _ in pairs(S.Hitbox.Parts) do
            if not seen[partName] then
                local nameLocal = partName
                Controls.Toggle(hbPartsContainer, "Part: " .. nameLocal, S.Hitbox.Parts[nameLocal], function(v) S.Hitbox.Parts[nameLocal] = v end)
            end
        end
    end
    rebuildHbToggles()
    Controls.Button(cH, "Refresh from character", "secondary", rebuildHbToggles)

    -- Hitbox state: snapshot original values per part per player
    -- _hbOriginals[plr] = { [partName] = { Size=, Transparency=, CanCollide=, Massless= } }
    local _hbOriginals = {}
    local function snapshotPart(plr, part)
        _hbOriginals[plr] = _hbOriginals[plr] or {}
        if _hbOriginals[plr][part.Name] then return end
        _hbOriginals[plr][part.Name] = {
            Size = part.Size, Transparency = part.Transparency,
            CanCollide = part.CanCollide, Massless = part.Massless,
        }
    end
    local function restorePlayer(plr)
        local snap = _hbOriginals[plr]
        if not snap then return end
        local ch = plr.Character
        if ch then
            for partName, orig in pairs(snap) do
                local p = ch:FindFirstChild(partName)
                if p and p:IsA("BasePart") then
                    pcall(function()
                        p.Size = orig.Size
                        p.Transparency = orig.Transparency
                        p.CanCollide = orig.CanCollide
                        p.Massless = orig.Massless
                    end)
                end
            end
        end
        _hbOriginals[plr] = nil
    end
    task.spawn(function()
        local prevEnabled = false
        while true do
            if S.Hitbox.Enabled then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LP and plr.Character then
                        for partName, on in pairs(S.Hitbox.Parts) do
                            if on then
                                local part = plr.Character:FindFirstChild(partName)
                                if part and part:IsA("BasePart") then
                                    snapshotPart(plr, part)
                                    pcall(function()
                                        part.Size = Vector3.new(S.Hitbox.Size, S.Hitbox.Size, S.Hitbox.Size)
                                        part.Transparency = S.Hitbox.Transparency
                                        part.CanCollide = false
                                        part.Massless = true
                                    end)
                                end
                            else
                                -- Part toggle off: restore that specific part if snapshotted
                                local snap = _hbOriginals[plr] and _hbOriginals[plr][partName]
                                if snap and plr.Character then
                                    local part = plr.Character:FindFirstChild(partName)
                                    if part and part:IsA("BasePart") then
                                        pcall(function()
                                            part.Size = snap.Size
                                            part.Transparency = snap.Transparency
                                            part.CanCollide = snap.CanCollide
                                            part.Massless = snap.Massless
                                        end)
                                    end
                                    _hbOriginals[plr][partName] = nil
                                end
                            end
                        end
                    end
                end
                prevEnabled = true
            elseif prevEnabled then
                for plr, _ in pairs(_hbOriginals) do restorePlayer(plr) end
                _hbOriginals = {}
                prevEnabled = false
            end
            task.wait(0.5)
        end
    end)
end

-- SPOOF
do
    addNav("Spoof", "[F]")
    local p = addPage("Spoof")
    local cP = Controls.Card(p, "Premium / Policy / Studio / Owner", "Per-toggle spoofs.")
    local premiumStatus = new("TextLabel", {
        BackgroundTransparency = 1, Text = "Premium hook: idle",
        Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 100, Parent = cP,
    })
    Controls.Toggle(cP, "Premium", S.Perms.Premium, function(v)
        S.Perms.Premium = v
        if v then
            local ok1 = installPermsHook()
            local ok2 = installMouseHitHook()
            if ok1 and ok2 then
                premiumStatus.Text = "Premium hook: active"
                premiumStatus.TextColor3 = C.Success
            else
                premiumStatus.Text = "Premium hook: install failed"
                premiumStatus.TextColor3 = C.Danger
            end
        else
            premiumStatus.Text = "Premium hook: awaiting first activation"
            premiumStatus.TextColor3 = C.TextDim
        end
    end)
    local policyStatus = new("TextLabel", {
        BackgroundTransparency = 1, Text = "Policy hook: idle",
        Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 101, Parent = cP,
    })
    Controls.Toggle(cP, "Policy", S.Perms.Policy, function(v)
        S.Perms.Policy = v
        if v then
            if installPermsHook() then
                policyStatus.Text = "Policy hook: active"; policyStatus.TextColor3 = C.Success
            else
                policyStatus.Text = "Policy hook: install failed"; policyStatus.TextColor3 = C.Danger
            end
        else
            policyStatus.Text = "Policy hook: awaiting first activation"; policyStatus.TextColor3 = C.TextDim
        end
    end)
    Controls.Toggle(cP, "IsStudio", S.Perms.IsStudio, function(v) S.Perms.IsStudio = v end)
    Controls.Toggle(cP, "Owner", S.Perms.Owner, function(v) S.Perms.Owner = v end)

    local cG = Controls.Card(p, "Gamepass spoofer", "Whitelist forces TRUE, blacklist forces FALSE.")
    local gpStatus = new("TextLabel", {
        BackgroundTransparency = 1, Text = "Gamepass hook: idle",
        Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 100, Parent = cG,
    })
    Controls.Toggle(cG, "Enabled", S.Perms.Gamepass.Enabled, function(v)
        S.Perms.Gamepass.Enabled = v
        if v then
            if installPermsHook() then
                gpStatus.Text = "Gamepass hook: active"; gpStatus.TextColor3 = C.Success
            else
                gpStatus.Text = "Gamepass hook: install failed"; gpStatus.TextColor3 = C.Danger
            end
        else
            gpStatus.Text = "Gamepass hook: awaiting first activation"; gpStatus.TextColor3 = C.TextDim
        end
    end)
    Controls.MultilineTextbox(cG, "Whitelist IDs", S.Perms.Gamepass.Whitelist, function(v) S.Perms.Gamepass.Whitelist = v end, 3)
    Controls.MultilineTextbox(cG, "Blacklist IDs", S.Perms.Gamepass.Blacklist, function(v) S.Perms.Gamepass.Blacklist = v end, 3)

    local cAB = Controls.Card(p, "Asset / Badge", "")
    Controls.Toggle(cAB, "Spoof PlayerOwnsAsset", S.Perms.Asset, function(v)
        S.Perms.Asset = v
        if v then installPermsHook() end
    end)
    Controls.Toggle(cAB, "Spoof UserHasBadgeAsync", S.Perms.Badge, function(v)
        S.Perms.Badge = v
        if v then installPermsHook() end
    end)

    local cGr = Controls.Card(p, "Group spoofer", "")
    Controls.Textbox(cGr, "Group ID", tostring(S.Perms.Group.Id), function(v) S.Perms.Group.Id = tonumber(v) or 0; if S.Perms.Group.Id > 0 then installPermsHook() end end)
    Controls.Slider(cGr, "Rank", 0, 255, S.Perms.Group.Rank, 0, function(v) S.Perms.Group.Rank = v end)
    Controls.Textbox(cGr, "Role name", S.Perms.Group.Role, function(v) S.Perms.Group.Role = v end)

    local cAC = Controls.Card(p, "AntiCheat bypass", "Property + namecall blocklist + AntiKick.")
    local acStatus = new("TextLabel", {
        BackgroundTransparency = 1, Text = "AntiCheat hook: idle",
        Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 100, Parent = cAC,
    })
    Controls.Toggle(cAC, "Enabled", S.AntiCheat.Enabled, function(v)
        S.AntiCheat.Enabled = v
        if v then
            local ok1 = installMouseHitHook()
            local ok2 = installNamecallHook()
            if ok1 and ok2 then
                acStatus.Text = "AntiCheat hook: active"; acStatus.TextColor3 = C.Success
            else
                acStatus.Text = "AntiCheat hook: install failed"; acStatus.TextColor3 = C.Danger
            end
        else
            acStatus.Text = "AntiCheat hook: awaiting first activation"; acStatus.TextColor3 = C.TextDim
        end
    end)
    Controls.Toggle(cAC, "Spoof WalkSpeed", S.AntiCheat.Spoof.WalkSpeed, function(v) S.AntiCheat.Spoof.WalkSpeed = v end)
    Controls.Toggle(cAC, "Spoof JumpPower", S.AntiCheat.Spoof.JumpPower, function(v) S.AntiCheat.Spoof.JumpPower = v end)
    Controls.Toggle(cAC, "Spoof JumpHeight", S.AntiCheat.Spoof.JumpHeight, function(v) S.AntiCheat.Spoof.JumpHeight = v end)
    Controls.Toggle(cAC, "Spoof HipHeight", S.AntiCheat.Spoof.HipHeight, function(v) S.AntiCheat.Spoof.HipHeight = v end)
    Controls.Toggle(cAC, "Spoof Gravity", S.AntiCheat.Spoof.Gravity, function(v) S.AntiCheat.Spoof.Gravity = v end)
    Controls.Toggle(cAC, "Anti-kick", S.AntiCheat.AntiKick, function(v)
        S.AntiCheat.AntiKick = v
        if v then installNamecallHook() end
    end)
    Controls.MultilineTextbox(cAC, "Namecall blocklist (regex per line)", S.AntiCheat.NamecallBlocklist, function(v) S.AntiCheat.NamecallBlocklist = v end, 4)
    Controls.Button(cAC, "Restore originals", "secondary", function()
        for k in pairs(S.AntiCheat.Spoof) do S.AntiCheat.Spoof[k] = false end
        notify("AntiCheat", "Spoofs cleared", C.Success)
    end)
end

-- NETWORK
do
    addNav("Network", "[N]")
    local p = addPage("Network")
    local cR = Controls.Card(p, "Remote Spy", "Logs FireServer / InvokeServer calls.")
    Controls.Toggle(cR, "Enabled", S.Network.RemoteSpy.Enabled, function(v)
        S.Network.RemoteSpy.Enabled = v
        if v then
            if installRemoteSpy() then
                notify("RemoteSpy", "Listening...", C.Success)
            else
                notify("RemoteSpy", "Hook install failed", C.Danger)
            end
        end
    end)
    Controls.Toggle(cR, "Paused", S.Network.RemoteSpy.Paused, function(v) S.Network.RemoteSpy.Paused = v end)
    Controls.Textbox(cR, "Filter (substring)", S.Network.RemoteSpy.Filter, function(v) S.Network.RemoteSpy.Filter = v end, "name fragment")
    Controls.Slider(cR, "Max log entries", 10, 500, S.Network.RemoteSpy.MaxLog, 0, function(v) S.Network.RemoteSpy.MaxLog = v end)
    Controls.Button(cR, "Clear log", "secondary", function()
        remoteLog = {}
        if remoteLogFrame then
            for _, c in ipairs(remoteLogFrame:GetChildren()) do
                if c:IsA("TextLabel") then c:Destroy() end
            end
        end
    end)
    -- Auto-install hook + enable spy on opening Network page
    onPageOpen("Network", function()
        if S.Network.RemoteSpy.Enabled then installRemoteSpy() end
    end)
    remoteLogFrame = new("ScrollingFrame", {
        BackgroundColor3 = C.Content, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 180),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.Accent,
        LayoutOrder = 99, Parent = cR,
    })
    corner(remoteLogFrame, 4); stroke(remoteLogFrame, C.Border, 1)
    pad(remoteLogFrame, 6)
    listLayout(remoteLogFrame, 2)

    local cF = Controls.Card(p, "Quick fire", "Fire a remote by path with args.")
    local pathBox = Controls.Textbox(cF, "Remote path", "", function() end, "game.ReplicatedStorage.Remotes.X")
    local argsBox = Controls.MultilineTextbox(cF, "Args (one per line, lua expr)", "", function() end, 4)
    Controls.Button(cF, "Fire", "primary", function()
        local args = {}
        for line in argsBox.Get():gmatch("[^\r\n]+") do
            local ok, v = pcall(function() return loadstring("return " .. line)() end)
            table.insert(args, ok and v or line)
        end
        quickFire(pathBox.Get(), args)
    end)
end

-- PLAYER
do
    addNav("Player", "[P]")
    local p = addPage("Player")
    local cC = Controls.Card(p, "Chat Spy", "Log all chat including whispers.")
    Controls.Toggle(cC, "Enabled", S.ChatSpy.Enabled, function(v)
        S.ChatSpy.Enabled = v
        if v then Engines.startChatSpy() else Engines.stopChatSpy() end
    end)
    Controls.Toggle(cC, "Show whispers", S.ChatSpy.ShowWhispers, function(v) S.ChatSpy.ShowWhispers = v end)
    Controls.Toggle(cC, "Show other team", S.ChatSpy.ShowOtherTeam, function(v) S.ChatSpy.ShowOtherTeam = v end)
    Controls.MultilineTextbox(cC, "Keyword alerts (one per line)", S.ChatSpy.Keywords, function(v) S.ChatSpy.Keywords = v end, 3)
    Controls.Textbox(cC, "Filter (substring)", S.ChatSpy.Filter, function(v) S.ChatSpy.Filter = v end)
    Controls.Button(cC, "Clear log", "secondary", function()
        chatLog = {}
        if chatLogFrame then
            for _, c in ipairs(chatLogFrame:GetChildren()) do
                if c:IsA("TextLabel") then c:Destroy() end
            end
        end
    end)
    chatLogFrame = new("ScrollingFrame", {
        BackgroundColor3 = C.Content, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 200),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.Accent,
        LayoutOrder = 99, Parent = cC,
    })
    corner(chatLogFrame, 4); stroke(chatLogFrame, C.Border, 1)
    pad(chatLogFrame, 6)
    listLayout(chatLogFrame, 2)

    -- Target Actions card (KILL / CAGE / TP)
    local cTA = Controls.Card(p, "Target Actions", "Select a player and act. All actions pcall-wrapped.")
    local taNames = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then table.insert(taNames, plr.Name) end
    end
    if #taNames == 0 then taNames = { "(no other players)" } end
    local taDD = Controls.Dropdown(cTA, "Select player", taNames, taNames[1], function(v) S.Player.SelectedPlayer = v end)
    S.Player.SelectedPlayer = taNames[1]

    local taStatusLbl = new("TextLabel", {
        BackgroundTransparency = 1, Text = "Status: idle",
        Font = Enum.Font.Code, TextSize = 11,
        TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 50, Parent = cTA,
    })

    -- Cage tracking
    local function cageFolderName(plrName) return "FREEZER_Cage_" .. plrName end
    local function findCage(plrName)
        return Workspace:FindFirstChild(cageFolderName(plrName))
    end
    local function refreshTaStatus()
        local sel = S.Player.SelectedPlayer
        if not sel or sel == "" or sel == "(no other players)" then
            taStatusLbl.Text = "Status: no target"
            return
        end
        local caged = findCage(sel) ~= nil
        taStatusLbl.Text = string.format("Status: target=%s, caged=%s", sel, tostring(caged))
    end

    local function getSelectedPlayer()
        local name = S.Player.SelectedPlayer
        if not name or name == "" then return nil end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Name == name then return plr end
        end
        return nil
    end

    Controls.Button(cTA, "KILL (void)", "danger", function()
        local plr = getSelectedPlayer()
        if not plr then notify("Target", "No target selected", C.Danger); return end
        local hrp = getHRP(plr)
        if not hrp then notify("Target", "Target HRP missing", C.Danger); return end
        local ok, err = pcall(function()
            hrp.CFrame = CFrame.new(0, -1e6, 0)
        end)
        if ok then notify("KILL", "Sent " .. plr.Name .. " to the void", C.Success)
        else notify("KILL", "Failed: " .. tostring(err), C.Danger) end
        refreshTaStatus()
    end)

    new("TextLabel", {
        BackgroundTransparency = 1,
        Text = "CAGE is LOCAL ONLY — others do not see the cage. Use TRAP for a live-fire lock.",
        Font = Enum.Font.Code, TextSize = 11,
        TextColor3 = C.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 49, Parent = cTA,
    })

    Controls.Button(cTA, "CAGE", "secondary", function()
        local plr = getSelectedPlayer()
        if not plr then notify("Target", "No target selected", C.Danger); return end
        local hrp = getHRP(plr)
        if not hrp then notify("Target", "Target HRP missing", C.Danger); return end
        pcall(function()
            local existing = findCage(plr.Name)
            if existing then existing:Destroy() end
            local folder = Instance.new("Folder")
            folder.Name = cageFolderName(plr.Name)
            folder.Parent = Workspace
            local center = hrp.Position
            local size = 12
            local thick = 1
            local half = size / 2
            -- 4 sides + floor + ceiling
            local sides = {
                { pos = center + Vector3.new( half, 0, 0), sz = Vector3.new(thick, size, size) },
                { pos = center + Vector3.new(-half, 0, 0), sz = Vector3.new(thick, size, size) },
                { pos = center + Vector3.new(0, 0,  half), sz = Vector3.new(size, size, thick) },
                { pos = center + Vector3.new(0, 0, -half), sz = Vector3.new(size, size, thick) },
                { pos = center + Vector3.new(0,  half, 0), sz = Vector3.new(size, thick, size) },
                { pos = center + Vector3.new(0, -half, 0), sz = Vector3.new(size, thick, size) },
            }
            for _, w in ipairs(sides) do
                local part = Instance.new("Part")
                part.Anchored = true
                part.CanCollide = true
                part.Transparency = 0.7
                part.Size = w.sz
                part.Position = w.pos
                part.BrickColor = BrickColor.new("Magenta")
                part.Material = Enum.Material.Neon
                part.TopSurface = Enum.SurfaceType.Smooth
                part.BottomSurface = Enum.SurfaceType.Smooth
                part.Parent = folder
            end
        end)
        notify("CAGE", "Caged " .. plr.Name, C.Success)
        refreshTaStatus()
    end)

    Controls.Button(cTA, "UNCAGE", "secondary", function()
        local name = S.Player.SelectedPlayer
        if not name or name == "" then notify("Target", "No target selected", C.Danger); return end
        local cage = findCage(name)
        if cage then pcall(function() cage:Destroy() end); notify("UNCAGE", "Removed cage for " .. name, C.Success)
        else notify("UNCAGE", "No cage for " .. name, C.Warning) end
        refreshTaStatus()
    end)

    Controls.Button(cTA, "TRAP (lock aimbot + silent)", "danger", function()
        local plr = getSelectedPlayer()
        if not plr then notify("Target", "No target selected", C.Danger); return end
        S.Aimbot.ForceTarget = plr
        S.Aimbot.Enabled = true
        S.SilentAim.Enabled = true
        Engines.startAimbot()
        if S.Aimbot.ShowFovCircle or S.SilentAim.ShowFovCircle then Engines.startFovCircle() end
        installNamecallHook()
        notify("TRAP", "Trap armed: aimbot+silent locked on " .. plr.Name, C.Success, 4)
    end)

    Controls.Button(cTA, "RELEASE trap", "secondary", function()
        S.Aimbot.ForceTarget = nil
        notify("TRAP", "Released. Aimbot resumes normal targeting.", C.Success, 3)
    end)

    Controls.Button(cTA, "Teleport TO", "primary", function()
        local plr = getSelectedPlayer()
        if not plr then notify("Target", "No target selected", C.Danger); return end
        local hrp = getHRP(plr)
        if not hrp then notify("Target", "Target HRP missing", C.Danger); return end
        pcall(function() teleportTo(hrp.Position + Vector3.new(0, 3, 0)) end)
    end)

    Controls.Button(cTA, "Teleport HERE", "primary", function()
        local plr = getSelectedPlayer()
        if not plr then notify("Target", "No target selected", C.Danger); return end
        local theirHrp = getHRP(plr)
        local myHrp = getHRP(LP)
        if not theirHrp or not myHrp then notify("Target", "Missing HRP", C.Danger); return end
        pcall(function() theirHrp.CFrame = myHrp.CFrame + Vector3.new(0, 0, -3) end)
        notify("Target", "TP'd " .. plr.Name .. " to me", C.Success)
    end)

    Controls.Button(cTA, "Refresh status", "secondary", refreshTaStatus)

    -- Auto-refresh dropdown every 2s
    task.spawn(function()
        while true do
            task.wait(2)
            local newNames = {}
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP then table.insert(newNames, plr.Name) end
            end
            if #newNames == 0 then newNames = { "(no other players)" } end
            pcall(function() taDD.Refresh(newNames) end)
            pcall(refreshTaStatus)
        end
    end)
    refreshTaStatus()

    local cL = Controls.Card(p, "Player list", "Live roster.")
    local listFrame = new("ScrollingFrame", {
        BackgroundColor3 = C.Content, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 200),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.Accent,
        LayoutOrder = 99, Parent = cL,
    })
    corner(listFrame, 4); stroke(listFrame, C.Border, 1)
    pad(listFrame, 6); listLayout(listFrame, 2)
    task.spawn(function()
        while true do
            for _, c in ipairs(listFrame:GetChildren()) do
                if c:IsA("TextLabel") then c:Destroy() end
            end
            for _, plr in ipairs(Players:GetPlayers()) do
                new("TextLabel", {
                    BackgroundTransparency = 1,
                    Text = string.format("%s  |  @%s  |  id %d", plr.DisplayName, plr.Name, plr.UserId),
                    Font = Enum.Font.Code, TextSize = 11,
                    TextColor3 = (plr == LP) and C.Accent or C.TextSecondary,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Size = UDim2.new(1, -8, 0, 16), Parent = listFrame,
                })
            end
            task.wait(3)
        end
    end)
end

-- MISC
do
    addNav("Misc", "[X]")
    local p = addPage("Misc")
    local c1 = Controls.Card(p, "System", "Quality of life.")
    Controls.Toggle(c1, "Anti-AFK", S.Misc.AntiAFK, function(v)
        S.Misc.AntiAFK = v
        if v then Engines.startAntiAFK() else Engines.stopAntiAFK() end
    end)
    Controls.Slider(c1, "FPS cap", 30, 1000, S.Misc.FPSCap, 0, function(v)
        S.Misc.FPSCap = v
        if setfpscap then pcall(setfpscap, v) end
    end)

    local c2 = Controls.Card(p, "Lighting", "")
    Controls.Toggle(c2, "Fullbright", S.Misc.Fullbright, function(v)
        S.Misc.Fullbright = v
        if v then Engines.startFullbright() else Engines.stopFullbright() end
    end)
    Controls.Toggle(c2, "No fog", S.Misc.NoFog, function(v)
        S.Misc.NoFog = v
        if v then Engines.startNoFog() else Engines.stopNoFog() end
    end)
    Controls.Toggle(c2, "No shadows", S.Misc.NoShadows, function(v)
        S.Misc.NoShadows = v
        pcall(function() Lighting.GlobalShadows = not v end)
    end)

    local c3 = Controls.Card(p, "Audio", "")
    Controls.Slider(c3, "Master volume", 0, 10, 1, 1, function(v)
        pcall(function() SoundService.Volume = v end)
    end)

    local c4 = Controls.Card(p, "Visual extras", "Crosshair / hit marker / no recoil.")
    Controls.Toggle(c4, "Crosshair", S.Misc.Crosshair, function(v)
        S.Misc.Crosshair = v
        if v then Engines.startCrosshair() else Engines.stopCrosshair() end
    end)
    Controls.Slider(c4, "Crosshair size", 4, 30, S.Misc.CrosshairSize, 0, function(v) S.Misc.CrosshairSize = v end)
    Controls.ColorPicker(c4, "Crosshair color", S.Misc.CrosshairColor, function(v) S.Misc.CrosshairColor = v end)
    Controls.Toggle(c4, "Hit marker", S.Misc.HitMarker, function(v) S.Misc.HitMarker = v end)
    Controls.Toggle(c4, "No recoil", S.Misc.NoRecoil, function(v) S.Misc.NoRecoil = v end)
end

-- CONFIGS
do
    addNav("Configs", "[C]")
    local p = addPage("Configs")
    local c1 = Controls.Card(p, "Theme", "Accent + preset.")
    Controls.Dropdown(c1, "Preset", { "Magenta", "Cyan", "Lime", "Orange", "Crimson" }, S.Theme.Preset, function(v)
        S.Theme.Preset = v
        local map = {
            Magenta = Color3.fromRGB(255, 65, 180),
            Cyan = Color3.fromRGB(80, 200, 240),
            Lime = Color3.fromRGB(140, 230, 90),
            Orange = Color3.fromRGB(255, 150, 60),
            Crimson = Color3.fromRGB(220, 60, 80),
        }
        S.Theme.Accent = map[v] or C.Accent
        C.Accent = S.Theme.Accent
        notify("Theme", "Restart for full effect", C.Success)
    end)
    Controls.ColorPicker(c1, "Accent override", S.Theme.Accent, function(v)
        S.Theme.Accent = v
        S.Theme.AccentOverride = true
        C.Accent = v
    end)

    local c2 = Controls.Card(p, "Slots", "Save / load / delete by name.")
    local slotBox = Controls.Textbox(c2, "Slot name", "default", function() end, "default")
    Controls.Button(c2, "Save", "primary", function() saveSlot(slotBox.Get()); notify("Config", "Saved " .. slotBox.Get(), C.Success) end)
    Controls.Button(c2, "Load", "secondary", function() loadSlot(slotBox.Get()); notify("Config", "Loaded " .. slotBox.Get(), C.Success) end)
    Controls.Button(c2, "Delete", "danger", function() deleteSlot(slotBox.Get()); notify("Config", "Deleted " .. slotBox.Get(), C.Success) end)

    local c3 = Controls.Card(p, "Storage", "Manual save / restore / autosave.")
    local autoSave = true
    Controls.Toggle(c3, "Auto-save", autoSave, function(v) autoSave = v end)
    Controls.Button(c3, "Save now", "primary", function() saveConfig(); notify("Config", "Saved.", C.Success) end)
    Controls.Button(c3, "Reload from disk", "secondary", function() loadConfig(); notify("Config", "Reloaded.", C.Success) end)
    Controls.Button(c3, "Export to clipboard", "secondary", function()
        local plain = {}
        for k, v in pairs(S) do plain[k] = deepCopy(v) end
        setclipboard(HttpService:JSONEncode(plain))
        notify("Config", "Exported to clipboard", C.Success)
    end)
    local importBox = Controls.MultilineTextbox(c3, "Import JSON", "", function() end, 4)
    Controls.Button(c3, "Import paste", "primary", function()
        pcall(function()
            local t = HttpService:JSONDecode(importBox.Get())
            for k, v in pairs(t or {}) do
                if S[k] and type(v) == "table" then
                    for k2, v2 in pairs(v) do S[k][k2] = deepRestore(v2) end
                end
            end
            notify("Config", "Imported", C.Success)
        end)
    end)
    local resetConfirm = false
    Controls.Button(c3, "Reset to defaults", "danger", function()
        if not resetConfirm then
            resetConfirm = true
            notify("Confirm", "Press again to confirm reset", C.Warning, 3)
            task.delay(3, function() resetConfirm = false end)
            return
        end
        resetConfirm = false
        pcall(function() delfile(CFG_PATH) end)
        notify("Config", "Reset. Reload required.", C.Success)
    end)

    local c4 = Controls.Card(p, "Global keybind editor", "Rebind any registered keybind.")
    for _, kb in ipairs(KeyRegistry) do
        local kbCopy = kb
        Controls.Keybind(c4, kbCopy.name, kbCopy.get(), function(k) kbCopy.set(k); saveConfig() end)
    end

    local c5 = Controls.Card(p, "About", "FREEZER v6.2.0 - safe-init build, hooks lazy, all defaults off.")
end

-- Default page
showPage("Home")

--[[ MASTER KEYBIND + GLOBAL KEY HANDLERS ]]
track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    local key
    if input.UserInputType == Enum.UserInputType.Keyboard then key = input.KeyCode.Name
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then key = "MouseButton1"
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then key = "MouseButton2"
    elseif input.UserInputType == Enum.UserInputType.MouseButton3 then key = "MouseButton3"
    end
    if not key then return end
    if key == S.Master.ToggleKey then HubGui.Enabled = not HubGui.Enabled end
    if key == S.Movement.FlyKey then
        S.Movement.Fly = not S.Movement.Fly
        if S.Movement.Fly then Engines.startFly() else Engines.stopFly() end
    end
    if key == S.Movement.NoclipKey then
        S.Movement.Noclip = not S.Movement.Noclip
        if S.Movement.Noclip then Engines.startNoclip() else Engines.stopNoclip() end
    end
    if key == S.Teleport.TpNearestKey then tpNearestPlayer() end
    if key == S.Teleport.TpRandomKey then tpRandomPlayer() end
    if key == S.Teleport.ReturnLastKey and lastTpPos then teleportTo(lastTpPos) end
    if key == S.Movement.PanicResetKey then
        S.Movement.Fly = false; Engines.stopFly()
        S.Movement.Noclip = false; Engines.stopNoclip()
        S.Aimbot.Enabled = false; Engines.stopAimbot()
        S.SilentAim.Enabled = false
        S.MagicBullet.Enabled = false
        S.Desync.Enabled = false; Engines.stopDesync()
        S.Movement.NinjaTP.Enabled = false; Engines.stopNinjaTP()
        notify("Panic", "All combat disabled", C.Warning)
    end
    if key == S.Desync.TriggerKey then
        S.Desync.Enabled = not S.Desync.Enabled
        if S.Desync.Enabled then Engines.startDesync() else Engines.stopDesync() end
    end
    if key == S.Movement.NinjaTP.Key then
        S.Movement.NinjaTP.Enabled = not S.Movement.NinjaTP.Enabled
        if S.Movement.NinjaTP.Enabled then Engines.startNinjaTP() else Engines.stopNinjaTP() end
    end
    if key == S.Movement.TpForwardKey then
        local hrp = getHRP(LP)
        local cam = GetCamera()
        if hrp and cam then
            teleportTo(hrp.Position + cam.CFrame.LookVector * S.Movement.TpForwardDistance)
        end
    end
    if key == S.Movement.SpeedBurstKey then
        local hum = getHum(LP)
        if hum then
            local orig = hum.WalkSpeed
            pcall(function() hum.WalkSpeed = orig * S.Movement.SpeedBurstMultiplier end)
            task.delay(S.Movement.SpeedBurstDuration, function()
                pcall(function() hum.WalkSpeed = S.Movement.WalkSpeed end)
            end)
        end
    end
end))

-- Ctrl+Click TP
track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
        and S.Teleport.CtrlClick
        and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        if Mouse.Hit then teleportTo(Mouse.Hit.Position + Vector3.new(0, 3, 0)) end
    end
end))

--[[ STATUS BAR LIVE UPDATER ]]
task.spawn(function()
    while true do
        local fps = 0
        pcall(function() fps = math.floor(1 / RunService.Heartbeat:Wait()) end)
        local players = #Players:GetPlayers()
        StatusText.Text = string.format("FPS %d  /  %d players  /  %s  /  %s",
            fps, players, EXEC, S.Master.Enabled and "ARMED" or "SAFE")
        task.wait(0.5)
    end
end)

-- Refresh body part dropdowns on character add
track(LP.CharacterAdded:Connect(function() task.wait(1) end))
track(Players.PlayerAdded:Connect(function() end))

--[[ EXPOSE API + INIT ]]
local API = {
    Version = "6.2.0",
    State = S,
    Notify = notify,
    Show = function() HubGui.Enabled = true end,
    Hide = function() HubGui.Enabled = false end,
    Toggle = function() HubGui.Enabled = not HubGui.Enabled end,
    Save = saveConfig,
    Load = loadConfig,
    ScanBodyParts = scanBodyParts,
    Destroy = function()
        clearConnections()
        Engines.stopAimbot(); Engines.stopESP(); Engines.stopFly(); Engines.stopNoclip(); Engines.stopInfJump()
        Engines.stopAntiAFK(); Engines.stopFullbright(); Engines.stopFovCircle()
        Engines.stopTriggerBot(); Engines.stopDesync(); Engines.stopSpinbot(); Engines.stopMoonJump()
        Engines.stopWallClimb(); Engines.stopAntiFling(); Engines.stopAntiVoid()
        Engines.stopItemEsp(); Engines.stopChatSpy(); Engines.stopCrosshair(); Engines.stopNoFog()
        Engines.stopNinjaTP()
        pcall(function() HubGui:Destroy() end)
        pcall(function() NotifyGui:Destroy() end)
        pcall(function() if FallbackLayer then FallbackLayer:Destroy() end end)
    end,
}
pcall(function() getgenv().FREEZER = API end)

loadConfig()

-- Show hub IMMEDIATELY so it is ready when splash fades.
-- Splash has DisplayOrder 999999, hub has 50000, so splash overlays cleanly.
HubGui.Enabled = true

task.spawn(function()
    showSplash(function()
        notify("FREEZER", "Ready. Press " .. S.Master.ToggleKey .. " to hide.", C.Success, 4)
    end)
end)

return API
