--[[
    FREEZER v4.0.0
    All-in-one Roblox exploit menu
    by ENI for LO
    Single-file monolithic build, no runtime module loads.
]]

--[[ ANTI-DETECT / EXPLOIT FUNCTION RESOLUTION ]]
local function safeGet(name)
    local ok, val = pcall(function() return getfenv(0)[name] end)
    if ok and val then return val end
    return nil
end

local cloneref       = safeGet("cloneref")       or function(o) return o end
local protect_gui    = safeGet("protect_gui")    or safeGet("syn_protect_gui") or function(g) return g end
local hookmetamethod = safeGet("hookmetamethod") or function() return nil end
local newcclosure    = safeGet("newcclosure")    or function(f) return f end
local checkcaller    = safeGet("checkcaller")    or function() return false end
local hookfunction   = safeGet("hookfunction")   or function() return nil end
local getrawmetatable= safeGet("getrawmetatable")or function() return nil end
local setreadonly    = safeGet("setreadonly")    or function() end
local setfpscap      = safeGet("setfpscap")      or function() end
local setclipboard   = safeGet("setclipboard")   or safeGet("toclipboard") or function() end
local writefile      = safeGet("writefile")      or function() end
local readfile       = safeGet("readfile")       or function() return "" end
local isfile         = safeGet("isfile")         or function() return false end
local makefolder     = safeGet("makefolder")     or function() end
local isfolder       = safeGet("isfolder")       or function() return false end
local listfiles      = safeGet("listfiles")      or function() return {} end
local Drawing        = safeGet("Drawing")
local identifyexec   = safeGet("identifyexecutor") or function() return "Unknown", "0" end

local EXECUTOR_NAME = "Unknown"
local function _resolveExecutor()
    local ok, n = pcall(identifyexec)
    if ok and n then EXECUTOR_NAME = tostring(n) end
end
_resolveExecutor()

--[[ SERVICES ]]
local Players           = cloneref(game:GetService("Players"))
local RunService        = cloneref(game:GetService("RunService"))
local UserInputService  = cloneref(game:GetService("UserInputService"))
local TweenService      = cloneref(game:GetService("TweenService"))
local Lighting          = cloneref(game:GetService("Lighting"))
local Workspace         = cloneref(game:GetService("Workspace"))
local HttpService       = cloneref(game:GetService("HttpService"))
local TeleportService   = cloneref(game:GetService("TeleportService"))
local StarterGui        = cloneref(game:GetService("StarterGui"))
local CoreGui           = cloneref(game:GetService("CoreGui"))
local TextChatService   = cloneref(game:GetService("TextChatService"))
local VirtualUser       = cloneref(game:GetService("VirtualUser"))
local Stats             = cloneref(game:GetService("Stats"))
local MarketplaceService= cloneref(game:GetService("MarketplaceService"))

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()
local Camera      = Workspace.CurrentCamera

--[[ THEME + EASE CONSTANTS ]]
local THEME = {
    WindowBg       = Color3.fromRGB(20, 20, 26),
    SidebarBg      = Color3.fromRGB(24, 24, 30),
    ContentBg      = Color3.fromRGB(28, 28, 34),
    CardBg         = Color3.fromRGB(36, 36, 44),
    CardHover      = Color3.fromRGB(44, 44, 54),
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

local EASE      = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local EASE_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local EASE_SLOW = TweenInfo.new(0.30, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local CONFIG_FOLDER = "FREEZER"

--[[ DEFAULT STATE ]]
local DefaultState = {
    Master = { Enabled = true, ToggleKey = "RightControl" },
    Aim = {
        Aimbot = { Enabled = false, FOV = 120, Smoothness = 0.25, TargetPart = "Head",
            TeamCheck = true, WallCheck = true, VisibleCheck = true,
            Prediction = 0.135, Activation = "Hold", Key = "MouseButton2",
            DrawFOV = true, FOVColor = {255, 65, 180} },
        TriggerBot = { Enabled = false, Delay = 0.05, FOV = 5, TeamCheck = true,
            Key = "MouseButton2", Activation = "Hold" },
        SilentAim = { Enabled = false, Method = "AUTO", FOV = 200, TargetPart = "Head",
            HitChance = 100, TeamCheck = true, WallCheck = false, RemotePath = "" },
        MagicBullet = { Enabled = false, RemotePath = "", AutoDetect = true,
            HitPosArgIndex = 1, TargetPart = "Head" },
    },
    Visual = {
        ESP = { Master = false, Box = false, Name = false, Health = false, Distance = false,
            Tracer = false, Skeleton = false, Chams = false,
            BoxColor = {255, 65, 180}, NameColor = {240, 240, 248},
            HealthColor = {80, 220, 130}, TracerColor = {255, 65, 180},
            ChamsColor = {255, 65, 180}, ChamsOutlineColor = {255, 255, 255},
            TeamCheck = true, MaxDistance = 1000, ShowNPCs = false, TracerOrigin = "Bottom" },
    },
    Movement = {
        WalkSpeed = { Enabled = false, Value = 16 },
        JumpPower = { Enabled = false, Value = 50 },
        JumpHeight= { Enabled = false, Value = 7.2 },
        HipHeight = { Enabled = false, Value = 2 },
        Gravity   = { Enabled = false, Value = 196.2 },
        MaxSlope  = { Enabled = false, Value = 89 },
        Fly       = { Enabled = false, Speed = 50, Mode = "Camera", ToggleKey = "F" },
        InfiniteJump = { Enabled = false },
        Noclip       = { Enabled = false },
        Spinbot      = { Enabled = false, Rate = 30 },
        TPForward    = { Enabled = false, Distance = 25, Key = "T" },
        WallClimb    = { Enabled = false },
        MoonJump     = { Enabled = false, Power = 100 },
        SpiderClimb  = { Enabled = false },
        SpeedBurst   = { Enabled = false, Multiplier = 4, Duration = 1.5, Key = "Q" },
        AntiFling    = { Enabled = false, Threshold = 300 },
        AntiVoid     = { Enabled = false, Threshold = -200 },
        AutoReapply  = { Enabled = true },
        PanicKey     = "End",
    },
    World = {
        Slots = {}, Waypoints = {}, CtrlClickTP = false,
        TPNearestKey = "Y", TPRandomKey = "U", FOV = 70,
        FreeCam = { Enabled = false, Speed = 50 },
        Spectate = { Target = nil },
        ServerHop = { Threshold = 10 },
    },
    Combat = {
        Desync = { Enabled = false, Method = "NetworkOwner", Offset = 8,
            Direction = "Forward", Key = "G",
            AutoEngage = false, AutoEngageFOV = 90, GhostIndicator = true },
        Hitbox = { Enabled = false, Size = 8, Transparency = 0.7,
            Color = {255, 65, 180}, TargetPart = "HumanoidRootPart" },
    },
    Spoof = {
        Premium  = { Enabled = false },
        Gamepass = { Enabled = false, Whitelist = "" },
        Asset    = { Enabled = false },
        Badge    = { Enabled = false },
        Group    = { Enabled = false, GroupId = 0, Rank = 255 },
        Policy   = { Enabled = false },
        IsStudio = { Enabled = false },
        Owner    = { Enabled = false },
        Attribute = {},
        AntiCheat = { Enabled = false, FakeWalkSpeed = 16, FakeJumpPower = 50,
            NamecallBlocklist = "Kick\nReport",
            AntiKick = false, AntiTPOut = false, HideACGui = false },
    },
    Network = {
        RemoteSpy = { Enabled = false, Paused = false, Filter = "" },
        Quick = { Path = "", Args = "" },
        Scanner = { Search = "" },
    },
    Player = {
        ChatSpy = { Enabled = false, ShowWhispers = true, ShowOtherTeam = true,
            Search = "", KeywordAlerts = "" },
    },
    Misc = {
        AntiAFK = { Enabled = false },
        FPSUnlock = { Enabled = false, Value = 240 },
        FOV = { Enabled = false, Value = 70 },
        Time = { Enabled = false, Value = 12 },
        FreezeTime = { Enabled = false },
        Fullbright = { Enabled = false },
        NoFog = { Enabled = false },
        NoShadows = { Enabled = false },
        SkyPreset = "Default",
        Volume = { Enabled = false, Value = 1 },
        Music = { Url = "", Playing = false },
        Crosshair = { Enabled = false, Size = 12, Color = {255, 65, 180} },
        HitMarker = { Enabled = false },
        NoRecoil = { Enabled = false },
        NoSprintCooldown = { Enabled = false },
    },
    Configs = {
        Theme = "Magenta", BgOpacity = 1, Scale = 1,
        AutoSave = true, CurrentSlot = "default",
    },
}

--[[ STATE INIT + CONFIG HELPERS ]]
local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = deepCopy(v) end
    return out
end
local State = deepCopy(DefaultState)
for i = 1, 10 do State.World.Slots[i] = nil end

local function ensureFolder()
    pcall(function()
        if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
    end)
end

local function saveConfig(slot)
    ensureFolder()
    slot = slot or State.Configs.CurrentSlot or "default"
    local ok, encoded = pcall(function() return HttpService:JSONEncode(State) end)
    if ok and encoded then
        pcall(function() writefile(CONFIG_FOLDER.."/"..slot..".json", encoded) end)
    end
end

local function loadConfig(slot)
    slot = slot or State.Configs.CurrentSlot or "default"
    local path = CONFIG_FOLDER.."/"..slot..".json"
    local ok, exists = pcall(function() return isfile(path) end)
    if ok and exists then
        local ok2, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if ok2 and type(data) == "table" then
            local function merge(dst, src)
                for k, v in pairs(src) do
                    if type(v) == "table" and type(dst[k]) == "table" then merge(dst[k], v)
                    else dst[k] = v end
                end
            end
            merge(State, data)
            return true
        end
    end
    return false
end

local function listConfigSlots()
    local list = {}
    pcall(function()
        if isfolder(CONFIG_FOLDER) then
            for _, f in ipairs(listfiles(CONFIG_FOLDER)) do
                local name = f:match("([^/\\]+)%.json$")
                if name then table.insert(list, name) end
            end
        end
    end)
    return list
end

--[[ CONNECTION TRACKER ]]
local _connections = {}
local function track(conn)
    if conn then table.insert(_connections, conn) end
    return conn
end

local function colorOf(rgb)
    if typeof(rgb) == "Color3" then return rgb end
    if type(rgb) == "table" then return Color3.fromRGB(rgb[1] or 0, rgb[2] or 0, rgb[3] or 0) end
    return Color3.new(1, 1, 1)
end

--[[ UI PRIMITIVE HELPERS ]]
local function new(class, props)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then pcall(function() inst[k] = v end) end
        end
        if props.Parent then inst.Parent = props.Parent end
    end
    return inst
end

local function corner(parent, radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = parent })
end

local function stroke(parent, color, thickness)
    return new("UIStroke", {
        Color = color or THEME.Border, Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
    })
end

local function padding(parent, p)
    local pad = type(p) == "table" and p or { p, p, p, p }
    return new("UIPadding", {
        PaddingTop = UDim.new(0, pad[1] or 0),
        PaddingRight = UDim.new(0, pad[2] or 0),
        PaddingBottom = UDim.new(0, pad[3] or 0),
        PaddingLeft = UDim.new(0, pad[4] or 0),
        Parent = parent,
    })
end

local function listLayout(parent, padpx, dir)
    return new("UIListLayout", {
        FillDirection = dir or Enum.FillDirection.Vertical,
        Padding = UDim.new(0, padpx or 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = parent,
    })
end

local function gradient(parent, colorSeq, rotation)
    return new("UIGradient", { Color = colorSeq, Rotation = rotation or 0, Parent = parent })
end

local function tween(obj, info, props)
    local t = TweenService:Create(obj, info or EASE, props)
    t:Play()
    return t
end

local function makeScreenGui(name, displayOrder)
    local gui = new("ScreenGui", {
        Name = name, IgnoreGuiInset = true, ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = displayOrder or 1000,
    })
    pcall(function()
        gui = protect_gui(gui) or gui
        gui.Parent = CoreGui
    end)
    if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    return gui
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
listLayout(NotifyContainer, 8, Enum.FillDirection.Vertical)

local function notify(opts)
    opts = opts or {}
    local title = opts.title or "FREEZER"
    local body  = opts.body or ""
    local duration = opts.duration or 3.5
    local accent = opts.accent or THEME.AccentPrimary
    local frame = new("Frame", {
        BackgroundColor3 = THEME.CardBg,
        Size = UDim2.new(0, 320, 0, 64),
        Position = UDim2.new(1, 40, 0, 0),
        Parent = NotifyContainer,
    })
    corner(frame, 6)
    stroke(frame, THEME.Border, 1)
    local bar = new("Frame", {
        BackgroundColor3 = accent,
        Size = UDim2.new(0, 3, 1, 0),
        Parent = frame,
    })
    corner(bar, 2)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 8),
        Size = UDim2.new(1, -22, 0, 18),
        Font = Enum.Font.GothamSemibold,
        TextSize = 13, TextColor3 = THEME.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = title, Parent = frame,
    })
    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0, 28),
        Size = UDim2.new(1, -22, 0, 30),
        Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = THEME.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true, Text = body, Parent = frame,
    })
    tween(frame, EASE, { Position = UDim2.new(0, 0, 0, 0) })
    task.delay(duration, function()
        local out = tween(frame, EASE, { Position = UDim2.new(1, 40, 0, 0) })
        out.Completed:Wait()
        frame:Destroy()
    end)
end

--[[ SPLASH SCREEN ]]
local function showSplash(onDone)
    local splash = makeScreenGui("FREEZER_Splash", 99999)
    local bg = new("Frame", {
        BackgroundColor3 = Color3.new(0, 0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        Parent = splash,
    })
    local vignette = new("Frame", {
        BackgroundColor3 = THEME.AccentPrimary,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = bg,
    })
    gradient(vignette, ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
        ColorSequenceKeypoint.new(0.5, THEME.AccentPrimary),
        ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
    }), 0)
    tween(vignette, EASE_SLOW, { BackgroundTransparency = 0.85 })

    local scanTop = new("Frame", {
        BackgroundColor3 = THEME.AccentPrimary, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 0, 0),
        Parent = bg,
    })
    local scanBottom = new("Frame", {
        BackgroundColor3 = THEME.AccentPrimary, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2),
        Parent = bg,
    })
    tween(scanTop, TweenInfo.new(1.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Position = UDim2.new(0, 0, 1, -2) })
    tween(scanBottom, TweenInfo.new(1.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Position = UDim2.new(0, 0, 0, 0) })

    local wordContainer = new("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.45, 0),
        Size = UDim2.new(0, 800, 0, 140),
        Parent = bg,
    })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 4),
        Parent = wordContainer,
    })

    local letters = {}
    local word = "FREEZER"
    for i = 1, #word do
        local ch = word:sub(i, i)
        local letter = new("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 90, 0, 140),
            Font = Enum.Font.GothamBold, TextSize = 120,
            TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1,
            Text = ch, LayoutOrder = i,
            Position = UDim2.new(0, 0, 0, -20),
            Parent = wordContainer,
        })
        letters[i] = letter
        task.delay(0.08 * (i - 1), function()
            tween(letter, EASE, { TextTransparency = 0, Position = UDim2.new(0, 0, 0, 0) })
        end)
    end

    task.delay(1.4, function()
        for _, l in ipairs(letters) do
            local s = new("UIStroke", {
                Color = THEME.AccentPrimary, Thickness = 2, Transparency = 1, Parent = l,
            })
            tween(s, EASE, { Transparency = 0 })
        end
    end)

    local glitchActive = true
    task.spawn(function()
        while glitchActive do
            task.wait(0.5)
            for _, l in ipairs(letters) do
                if l.Parent then
                    local origPos = l.Position
                    local jitter = UDim2.new(0, math.random(-3, 3), 0, math.random(-3, 3))
                    l.Position = origPos + jitter
                    task.delay(0.05, function()
                        if l.Parent then l.Position = origPos end
                    end)
                end
            end
        end
    end)

    for i = 1, 20 do
        local p = new("Frame", {
            BackgroundColor3 = THEME.AccentPrimary,
            BackgroundTransparency = math.random(40, 80) / 100,
            BorderSizePixel = 0,
            Size = UDim2.new(0, math.random(3, 6), 0, math.random(3, 6)),
            Position = UDim2.new(math.random(20, 80) / 100, 0, math.random(30, 70) / 100, 0),
            Parent = bg,
        })
        corner(p, 2)
        task.spawn(function()
            while p.Parent do
                local nx = math.random(15, 85) / 100
                local ny = math.random(20, 75) / 100
                tween(p, TweenInfo.new(2 + math.random() * 2,
                    Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                    { Position = UDim2.new(nx, 0, ny, 0) })
                task.wait(2 + math.random() * 2)
            end
        end)
    end

    local subtitle = new("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0.62, 0),
        Size = UDim2.new(0, 600, 0, 24),
        Font = Enum.Font.GothamSemibold, TextSize = 18,
        TextColor3 = THEME.TextDim, TextTransparency = 1,
        Text = "ALL-IN-ONE :: v4.0.0", Parent = bg,
    })
    local stepLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0.69, 0),
        Size = UDim2.new(0, 600, 0, 18),
        Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = THEME.TextSecondary, TextTransparency = 1,
        Text = "Bootstrapping core", Parent = bg,
    })
    local progressBg = new("Frame", {
        BackgroundColor3 = THEME.CardBg, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0.73, 0),
        Size = UDim2.new(0, 480, 0, 6),
        BackgroundTransparency = 1, Parent = bg,
    })
    corner(progressBg, 3)
    local progressFill = new("Frame", {
        BackgroundColor3 = THEME.AccentPrimary, BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 1, Parent = progressBg,
    })
    corner(progressFill, 3)

    task.delay(1.8, function()
        tween(subtitle, EASE_SLOW, { TextTransparency = 0 })
        tween(stepLabel, EASE_SLOW, { TextTransparency = 0 })
        tween(progressBg, EASE_SLOW, { BackgroundTransparency = 0 })
        tween(progressFill, EASE_SLOW, { BackgroundTransparency = 0 })
        local steps = {
            "Bootstrapping core", "Resolving services",
            "Loading aim subsystem", "Loading visual subsystem",
            "Loading movement subsystem", "Loading spoof hooks",
            "Loading network", "Mounting UI", "Ready",
        }
        tween(progressFill, TweenInfo.new(2, Enum.EasingStyle.Linear),
            { Size = UDim2.new(1, 0, 1, 0) })
        task.spawn(function()
            for _, s in ipairs(steps) do
                if stepLabel.Parent then stepLabel.Text = s end
                task.wait(2 / #steps)
            end
        end)
    end)

    local credit = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 18, 1, -36),
        Size = UDim2.new(0, 200, 0, 18),
        Font = Enum.Font.GothamSemibold, TextSize = 12,
        TextColor3 = THEME.TextDim, TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "by ENI for LO", Parent = bg,
    })
    task.delay(3.8, function()
        tween(credit, EASE_SLOW, { TextTransparency = 0 })
    end)

    task.delay(4.2, function()
        glitchActive = false
        tween(bg, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
        for _, l in ipairs(letters) do
            tween(l, TweenInfo.new(0.3), { TextTransparency = 1 })
        end
        tween(subtitle, TweenInfo.new(0.3), { TextTransparency = 1 })
        tween(stepLabel, TweenInfo.new(0.3), { TextTransparency = 1 })
        tween(credit, TweenInfo.new(0.3), { TextTransparency = 1 })
    end)

    task.delay(4.5, function()
        splash:Destroy()
        if onDone then onDone() end
    end)
end
--[[ HUB BASE + FLOATING LAYER ]]
local HubGui = makeScreenGui("FREEZER_Hub", 1000)
HubGui.Enabled = false
local FloatingLayer = new("Frame", {
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
    ZIndex = 40, Parent = HubGui,
})

--[[ UI CONTROL FACTORIES ]]
local function createRow(parent, height)
    return new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height or 38), Parent = parent,
    })
end

local function createLabel(parent, text, sub)
    local row = createRow(parent, sub and 44 or 38)
    local lbl = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0.6, 0, 0, 20),
        Font = Enum.Font.Gotham, TextSize = 13,
        TextColor3 = THEME.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = text or "", Parent = row,
    })
    if sub then
        new("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 22),
            Size = UDim2.new(0.6, 0, 0, 14),
            Font = Enum.Font.Gotham, TextSize = 11,
            TextColor3 = THEME.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = sub, Parent = row,
        })
    end
    return row, lbl
end

local function createToggle(parent, text, initial, callback, sub)
    local row, lbl = createLabel(parent, text, sub)
    local pill = new("Frame", {
        BackgroundColor3 = initial and THEME.AccentPrimary or THEME.CardHover,
        BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 38, 0, 20), Parent = row,
    })
    corner(pill, 10)
    local knob = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = initial and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.new(0, 16, 0, 16), Parent = pill,
    })
    corner(knob, 8)
    local state = initial and true or false
    local function set(v, fire)
        state = v and true or false
        tween(pill, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { BackgroundColor3 = state and THEME.AccentPrimary or THEME.CardHover })
        tween(knob, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { Position = state and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) })
        if fire ~= false and callback then pcall(callback, state) end
    end
    local btn = new("TextButton", {
        BackgroundTransparency = 1, Text = "",
        Size = UDim2.new(1, 0, 1, 0), Parent = row,
    })
    btn.MouseButton1Click:Connect(function() set(not state, true) end)
    return {
        Frame = row, Label = lbl,
        Set = function(v) set(v, false) end,
        Get = function() return state end,
        Toggle = function() set(not state, true) end,
    }
end

local function createSlider(parent, text, min, max, initial, callback, sub, decimals)
    decimals = decimals or 0
    local row, lbl = createLabel(parent, text, sub)
    local bar = new("Frame", {
        BackgroundColor3 = THEME.CardHover, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -60, 0.5, 0),
        Size = UDim2.new(0, 180, 0, 4), Parent = row,
    })
    corner(bar, 2)
    local fill = new("Frame", {
        BackgroundColor3 = THEME.AccentPrimary, BorderSizePixel = 0,
        Size = UDim2.new((initial - min) / math.max(0.0001, max - min), 0, 1, 0),
        Parent = bar,
    })
    corner(fill, 2)
    local knob = new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((initial - min) / math.max(0.0001, max - min), 0, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14), Parent = bar,
    })
    corner(knob, 7)
    local valLbl = new("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 50, 0, 18),
        Font = Enum.Font.Code, TextSize = 12,
        TextColor3 = THEME.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Right,
        Text = tostring(initial), Parent = row,
    })
    local value = initial
    local dragging = false
    local function fmt(v)
        if decimals == 0 then return tostring(math.floor(v + 0.5)) end
        return string.format("%." .. decimals .. "f", v)
    end
    local function set(v, fire)
        v = math.clamp(v, min, max)
        value = v
        local pct = (v - min) / math.max(0.0001, max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        valLbl.Text = fmt(v)
        if fire ~= false and callback then pcall(callback, decimals == 0 and math.floor(v + 0.5) or v) end
    end
    local function updateFromMouse(input)
        local abs = bar.AbsolutePosition.X
        local w = bar.AbsoluteSize.X
        local pct = math.clamp((input.Position.X - abs) / w, 0, 1)
        set(min + (max - min) * pct, true)
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromMouse(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromMouse(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    return {
        Frame = row, Label = lbl,
        Set = function(v) set(v, false) end,
        Get = function() return value end,
    }
end

local function createDropdown(parent, text, options, initial, callback, sub)
    local row, lbl = createLabel(parent, text, sub)
    local btn = new("TextButton", {
        BackgroundColor3 = THEME.ContentBg, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 160, 0, 28),
        Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = THEME.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "  " .. tostring(initial),
        AutoButtonColor = false, Parent = row,
    })
    corner(btn, 4)
    stroke(btn, THEME.Border, 1)
    new("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14),
        Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = THEME.TextDim, Text = "v", Parent = btn,
    })
    local value = initial
    local listOpen = nil
    local function closeList()
        if listOpen then listOpen:Destroy(); listOpen = nil end
    end
    btn.MouseButton1Click:Connect(function()
        if listOpen then closeList() return end
        local abs = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        local h = math.min(#options * 26, 200)
        local list = new("Frame", {
            BackgroundColor3 = THEME.ContentBg, BorderSizePixel = 0,
            Position = UDim2.new(0, abs.X, 0, abs.Y + size.Y + 2),
            Size = UDim2.new(0, size.X, 0, h),
            ZIndex = 50, Parent = FloatingLayer,
        })
        corner(list, 4)
        stroke(list, THEME.Border, 1)
        local scroll = new("ScrollingFrame", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = THEME.AccentPrimary,
            CanvasSize = UDim2.new(0, 0, 0, #options * 26),
            ZIndex = 51, Parent = list,
        })
        new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
        for _, opt in ipairs(options) do
            local item = new("TextButton", {
                BackgroundColor3 = THEME.ContentBg, BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 26),
                Font = Enum.Font.Gotham, TextSize = 12,
                TextColor3 = THEME.TextPrimary,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = "  " .. tostring(opt),
                AutoButtonColor = false, ZIndex = 52, Parent = scroll,
            })
            item.MouseEnter:Connect(function() item.BackgroundColor3 = THEME.CardBg end)
            item.MouseLeave:Connect(function() item.BackgroundColor3 = THEME.ContentBg end)
            item.MouseButton1Click:Connect(function()
                value = opt
                btn.Text = "  " .. tostring(opt)
                closeList()
                if callback then pcall(callback, opt) end
            end)
        end
        listOpen = list
        local outsideConn
        outsideConn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local mp = UserInputService:GetMouseLocation()
                local p, s = list.AbsolutePosition, list.AbsoluteSize
                local bp, bs = btn.AbsolutePosition, btn.AbsoluteSize
                local inList = mp.X >= p.X and mp.X <= p.X + s.X
                    and mp.Y >= p.Y and mp.Y <= p.Y + s.Y
                local inBtn = mp.X >= bp.X and mp.X <= bp.X + bs.X
                    and mp.Y >= bp.Y and mp.Y <= bp.Y + bs.Y
                if not inList and not inBtn then
                    closeList()
                    outsideConn:Disconnect()
                end
            end
        end)
    end)
    return {
        Frame = row, Label = lbl,
        Set = function(v) value = v; btn.Text = "  " .. tostring(v) end,
        Get = function() return value end,
        SetOptions = function(newOpts) options = newOpts end,
    }
end

local function createColorPicker(parent, text, initial, callback, sub)
    local row, lbl = createLabel(parent, text, sub)
    local rgb = initial or {255, 65, 180}
    local swatch = new("TextButton", {
        BackgroundColor3 = colorOf(rgb), BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 28, 0, 28),
        AutoButtonColor = false, Text = "", Parent = row,
    })
    corner(swatch, 4)
    stroke(swatch, THEME.Border, 1)
    local panelOpen = nil
    local function closePanel()
        if panelOpen then panelOpen:Destroy(); panelOpen = nil end
    end
    swatch.MouseButton1Click:Connect(function()
        if panelOpen then closePanel() return end
        local abs = swatch.AbsolutePosition
        local size = swatch.AbsoluteSize
        local panel = new("Frame", {
            BackgroundColor3 = THEME.ContentBg, BorderSizePixel = 0,
            Position = UDim2.new(0, abs.X - 200, 0, abs.Y + size.Y + 4),
            Size = UDim2.new(0, 240, 0, 160),
            ZIndex = 50, Parent = FloatingLayer,
        })
        corner(panel, 6)
        stroke(panel, THEME.Border, 1)
        padding(panel, 10)
        listLayout(panel, 6)
        local fields = {}
        for i, name in ipairs({"R", "G", "B"}) do
            local fr = new("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 24),
                LayoutOrder = i, ZIndex = 51, Parent = panel,
            })
            new("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 30, 1, 0),
                Font = Enum.Font.GothamSemibold, TextSize = 12,
                TextColor3 = THEME.TextPrimary,
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = name, ZIndex = 52, Parent = fr,
            })
            local tb = new("TextBox", {
                BackgroundColor3 = THEME.CardBg, BorderSizePixel = 0,
                Position = UDim2.new(0, 36, 0, 0),
                Size = UDim2.new(1, -36, 1, 0),
                Font = Enum.Font.Code, TextSize = 12,
                TextColor3 = THEME.TextPrimary,
                Text = tostring(rgb[i] or 0),
                ZIndex = 52, Parent = fr,
            })
            corner(tb, 3)
            fields[i] = tb
        end
        local hexFr = new("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 24),
            LayoutOrder = 4, ZIndex = 51, Parent = panel,
        })
        new("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 30, 1, 0),
            Font = Enum.Font.GothamSemibold, TextSize = 12,
            TextColor3 = THEME.TextPrimary,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "#", ZIndex = 52, Parent = hexFr,
        })
        local hexBox = new("TextBox", {
            BackgroundColor3 = THEME.CardBg, BorderSizePixel = 0,
            Position = UDim2.new(0, 36, 0, 0),
            Size = UDim2.new(1, -36, 1, 0),
            Font = Enum.Font.Code, TextSize = 12,
            TextColor3 = THEME.TextPrimary,
            Text = string.format("%02X%02X%02X", rgb[1] or 0, rgb[2] or 0, rgb[3] or 0),
            ZIndex = 52, Parent = hexFr,
        })
        corner(hexBox, 3)
        local apply = new("TextButton", {
            BackgroundColor3 = THEME.AccentPrimary, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 5,
            Font = Enum.Font.GothamSemibold, TextSize = 12,
            TextColor3 = Color3.new(1, 1, 1),
            Text = "Apply", AutoButtonColor = false,
            ZIndex = 52, Parent = panel,
        })
        corner(apply, 4)
        apply.MouseButton1Click:Connect(function()
            local r = tonumber(fields[1].Text) or rgb[1]
            local g = tonumber(fields[2].Text) or rgb[2]
            local b = tonumber(fields[3].Text) or rgb[3]
            local hex = hexBox.Text:gsub("#", "")
            if #hex == 6 then
                local hr = tonumber(hex:sub(1, 2), 16)
                local hg = tonumber(hex:sub(3, 4), 16)
                local hb = tonumber(hex:sub(5, 6), 16)
                if hr and hg and hb then r, g, b = hr, hg, hb end
            end
            rgb = { math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255) }
            swatch.BackgroundColor3 = colorOf(rgb)
            closePanel()
            if callback then pcall(callback, rgb) end
        end)
        panelOpen = panel
    end)
    return {
        Frame = row, Label = lbl,
        Set = function(v) rgb = v; swatch.BackgroundColor3 = colorOf(v) end,
        Get = function() return rgb end,
    }
end

local function createKeybind(parent, text, initial, callback, sub)
    local row, lbl = createLabel(parent, text, sub)
    local btn = new("TextButton", {
        BackgroundColor3 = THEME.ContentBg, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 100, 0, 28),
        Font = Enum.Font.GothamSemibold, TextSize = 12,
        TextColor3 = THEME.TextPrimary,
        Text = tostring(initial or "None"),
        AutoButtonColor = false, Parent = row,
    })
    corner(btn, 4)
    stroke(btn, THEME.Border, 1)
    local key = initial
    local listening = false
    btn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        btn.Text = "Press a key..."
        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape then
                    key = nil
                    btn.Text = "None"
                else
                    key = input.KeyCode.Name
                    btn.Text = key
                end
                listening = false
                conn:Disconnect()
                if callback then pcall(callback, key) end
            elseif input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.MouseButton2
                or input.UserInputType == Enum.UserInputType.MouseButton3 then
                key = input.UserInputType.Name
                btn.Text = key
                listening = false
                conn:Disconnect()
                if callback then pcall(callback, key) end
            end
        end)
    end)
    return {
        Frame = row, Label = lbl,
        Set = function(v) key = v; btn.Text = tostring(v or "None") end,
        Get = function() return key end,
    }
end

local function createTextbox(parent, text, initial, callback, sub, placeholder)
    local row, lbl = createLabel(parent, text, sub)
    local tb = new("TextBox", {
        BackgroundColor3 = THEME.ContentBg, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 200, 0, 28),
        Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = THEME.TextPrimary,
        PlaceholderColor3 = THEME.TextDim,
        PlaceholderText = placeholder or "",
        Text = initial or "", ClearTextOnFocus = false, Parent = row,
    })
    corner(tb, 4)
    local s = stroke(tb, THEME.Border, 1)
    tb.Focused:Connect(function() s.Color = THEME.AccentPrimary end)
    tb.FocusLost:Connect(function(enter)
        s.Color = THEME.Border
        if callback then pcall(callback, tb.Text, enter) end
    end)
    return {
        Frame = row, Label = lbl,
        Set = function(v) tb.Text = tostring(v or "") end,
        Get = function() return tb.Text end,
        Box = tb,
    }
end

local function createMultilineTextbox(parent, text, initial, height, callback, sub)
    local row, lbl = createLabel(parent, text, sub)
    row.Size = UDim2.new(1, 0, 0, (height or 80) + 20)
    local tb = new("TextBox", {
        BackgroundColor3 = THEME.ContentBg, BorderSizePixel = 0,
        Position = UDim2.new(1, -320, 0, 18),
        Size = UDim2.new(0, 320, 0, height or 80),
        Font = Enum.Font.Code, TextSize = 12,
        TextColor3 = THEME.TextPrimary,
        Text = initial or "", ClearTextOnFocus = false,
        MultiLine = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true, Parent = row,
    })
    corner(tb, 4)
    local s = stroke(tb, THEME.Border, 1)
    tb.Focused:Connect(function() s.Color = THEME.AccentPrimary end)
    tb.FocusLost:Connect(function(enter)
        s.Color = THEME.Border
        if callback then pcall(callback, tb.Text, enter) end
    end)
    return {
        Frame = row, Label = lbl,
        Set = function(v) tb.Text = tostring(v or "") end,
        Get = function() return tb.Text end,
        Box = tb,
    }
end

local function createButton(parent, text, style, callback)
    local color = THEME.AccentPrimary
    if style == "secondary" then color = THEME.CardHover
    elseif style == "danger" then color = THEME.Danger end
    local btn = new("TextButton", {
        BackgroundColor3 = color, BorderSizePixel = 0,
        Size = UDim2.new(0, 100, 0, 30),
        Font = Enum.Font.GothamSemibold, TextSize = 12,
        TextColor3 = style == "secondary" and THEME.TextPrimary or Color3.new(1, 1, 1),
        Text = text or "Button", AutoButtonColor = false, Parent = parent,
    })
    corner(btn, 4)
    local origColor = color
    btn.MouseEnter:Connect(function()
        local hoverColor = style == "secondary" and THEME.CardBg or color:Lerp(Color3.new(1, 1, 1), 0.1)
        tween(btn, EASE_FAST, { BackgroundColor3 = hoverColor })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, EASE_FAST, { BackgroundColor3 = origColor })
    end)
    btn.MouseButton1Click:Connect(function()
        if callback then pcall(callback) end
    end)
    return btn
end

local function createCard(parent, title, desc, masterToggle, masterCallback)
    local card = new("Frame", {
        BackgroundColor3 = THEME.CardBg, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Parent = parent,
    })
    corner(card, 8)
    stroke(card, THEME.Border, 1)
    padding(card, 16)
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4), Parent = card,
    })
    local headerRow = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 22),
        LayoutOrder = 1, Parent = card,
    })
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -50, 1, 0),
        Font = Enum.Font.GothamSemibold, TextSize = 14,
        TextColor3 = THEME.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = title or "Card", Parent = headerRow,
    })
    if masterToggle ~= nil then
        local pill = new("Frame", {
            BackgroundColor3 = masterToggle and THEME.AccentPrimary or THEME.CardHover,
            BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 38, 0, 20), Parent = headerRow,
        })
        corner(pill, 10)
        local knob = new("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = masterToggle and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
            Size = UDim2.new(0, 16, 0, 16), Parent = pill,
        })
        corner(knob, 8)
        local mstate = masterToggle and true or false
        local btn = new("TextButton", {
            BackgroundTransparency = 1, Text = "",
            Size = UDim2.new(1, 0, 1, 0), Parent = headerRow,
        })
        btn.MouseButton1Click:Connect(function()
            mstate = not mstate
            tween(pill, EASE_FAST, { BackgroundColor3 = mstate and THEME.AccentPrimary or THEME.CardHover })
            tween(knob, EASE_FAST, { Position = mstate and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) })
            if masterCallback then pcall(masterCallback, mstate) end
        end)
    end
    if desc then
        new("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Font = Enum.Font.Gotham, TextSize = 12,
            TextColor3 = THEME.TextDim,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = desc, LayoutOrder = 2, Parent = card,
        })
    end
    local body = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 3, Parent = card,
    })
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2), Parent = body,
    })
    return body, card
end
--[[ HUB WINDOW BUILD ]]
local Window = new("Frame", {
    BackgroundColor3 = THEME.WindowBg, BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 920, 0, 600),
    Parent = HubGui,
})
corner(Window, 10)
stroke(Window, THEME.Border, 1)

local AccentStripe = new("Frame", {
    BackgroundColor3 = THEME.AccentPrimary, BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 2), Parent = Window,
})

local TitleBar = new("Frame", {
    BackgroundColor3 = THEME.WindowBg, BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 2),
    Size = UDim2.new(1, 0, 0, 40),
    Parent = Window,
})

local logo = new("Frame", {
    BackgroundColor3 = THEME.AccentPrimary, BorderSizePixel = 0,
    Position = UDim2.new(0, 14, 0.5, -6),
    Size = UDim2.new(0, 12, 0, 12),
    Parent = TitleBar,
})
corner(logo, 3)

new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 34, 0, 0),
    Size = UDim2.new(0, 120, 1, 0),
    Font = Enum.Font.GothamBold, TextSize = 14,
    TextColor3 = THEME.TextPrimary,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "FREEZER", Parent = TitleBar,
})

local SearchBox = new("TextBox", {
    BackgroundColor3 = THEME.ContentBg, BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 320, 0, 24),
    Font = Enum.Font.Gotham, TextSize = 12,
    TextColor3 = THEME.TextPrimary,
    PlaceholderColor3 = THEME.TextDim,
    PlaceholderText = "Search settings...",
    Text = "", ClearTextOnFocus = false,
    Parent = TitleBar,
})
corner(SearchBox, 14)
new("UIPadding", {
    PaddingLeft = UDim.new(0, 28), PaddingRight = UDim.new(0, 8),
    Parent = SearchBox,
})
new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 8, 0, 0),
    Size = UDim2.new(0, 20, 1, 0),
    Font = Enum.Font.Gotham, TextSize = 12,
    TextColor3 = THEME.TextDim,
    Text = "Q", Parent = SearchBox,
})

local function makeWinBtn(text, color, callback)
    local btn = new("TextButton", {
        BackgroundColor3 = THEME.WindowBg, BorderSizePixel = 0,
        Size = UDim2.new(0, 46, 1, 0),
        Font = Enum.Font.Gotham, TextSize = 16,
        TextColor3 = THEME.TextPrimary,
        Text = text, AutoButtonColor = false,
        Parent = TitleBar,
    })
    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = color or THEME.CardBg end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = THEME.WindowBg end)
    btn.MouseButton1Click:Connect(function() if callback then pcall(callback) end end)
    return btn
end

local CloseBtn = makeWinBtn("x", THEME.Danger, function() HubGui.Enabled = false end)
CloseBtn.Position = UDim2.new(1, -46, 0, 0)
local MinBtn = makeWinBtn("-", nil, function() HubGui.Enabled = false end)
MinBtn.Position = UDim2.new(1, -92, 0, 0)

local _dragging, _dragStart, _dragStartPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        _dragging = true
        _dragStart = input.Position
        _dragStartPos = Window.Position
    end
end)
TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then _dragging = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if _dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - _dragStart
        Window.Position = UDim2.new(_dragStartPos.X.Scale, _dragStartPos.X.Offset + delta.X,
                                    _dragStartPos.Y.Scale, _dragStartPos.Y.Offset + delta.Y)
    end
end)

local Sidebar = new("Frame", {
    BackgroundColor3 = THEME.SidebarBg, BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 42),
    Size = UDim2.new(0, 220, 1, -68),
    Parent = Window,
})
new("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 2), Parent = Sidebar,
})
new("UIPadding", {
    PaddingTop = UDim.new(0, 12),
    PaddingLeft = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8),
    Parent = Sidebar,
})

local ContentArea = new("ScrollingFrame", {
    BackgroundColor3 = THEME.ContentBg, BorderSizePixel = 0,
    Position = UDim2.new(0, 220, 0, 42),
    Size = UDim2.new(1, -220, 1, -68),
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = THEME.AccentPrimary,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Parent = Window,
})
new("UIPadding", {
    PaddingTop = UDim.new(0, 20),
    PaddingBottom = UDim.new(0, 20),
    PaddingLeft = UDim.new(0, 20),
    PaddingRight = UDim.new(0, 20),
    Parent = ContentArea,
})
new("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 8), Parent = ContentArea,
})

local StatusBar = new("Frame", {
    BackgroundColor3 = THEME.SidebarBg, BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 1, -26),
    Size = UDim2.new(1, 0, 0, 26),
    Parent = Window,
})
local statusDot = new("Frame", {
    BackgroundColor3 = THEME.AccentPrimary, BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 10, 0.5, 0),
    Size = UDim2.new(0, 6, 0, 6),
    Parent = StatusBar,
})
corner(statusDot, 3)
local statusText = new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 22, 0, 0),
    Size = UDim2.new(1, -32, 1, 0),
    Font = Enum.Font.Gotham, TextSize = 11,
    TextColor3 = THEME.TextSecondary,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = "FPS -- / Ping --ms / 0 players / Loading / --:--",
    Parent = StatusBar,
})

local Pages = {}
local NavButtons = {}
local CurrentPage = nil

local function selectPage(name)
    for k, page in pairs(Pages) do page.Visible = (k == name) end
    for k, btn in pairs(NavButtons) do
        local sel = (k == name)
        tween(btn.Bg, EASE_FAST, { BackgroundColor3 = sel and THEME.AccentSoft or THEME.SidebarBg })
        btn.LeftBar.Visible = sel
    end
    CurrentPage = name
end

local function addNavItem(name, label, icon, order)
    local item = new("Frame", {
        BackgroundColor3 = THEME.SidebarBg, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 44),
        LayoutOrder = order or 1, Parent = Sidebar,
    })
    corner(item, 6)
    local leftBar = new("Frame", {
        BackgroundColor3 = THEME.AccentPrimary, BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, -10),
        Position = UDim2.new(0, 0, 0, 5),
        Visible = false, Parent = item,
    })
    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(0, 26, 1, 0),
        Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = THEME.AccentPrimary,
        Text = icon or "", Parent = item,
    })
    new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 40, 0, 0),
        Size = UDim2.new(1, -48, 1, 0),
        Font = Enum.Font.GothamSemibold, TextSize = 13,
        TextColor3 = THEME.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = label, Parent = item,
    })
    local btn = new("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Text = "", Parent = item,
    })
    btn.MouseEnter:Connect(function()
        if CurrentPage ~= name then tween(item, EASE_FAST, { BackgroundColor3 = THEME.CardBg }) end
    end)
    btn.MouseLeave:Connect(function()
        if CurrentPage ~= name then tween(item, EASE_FAST, { BackgroundColor3 = THEME.SidebarBg }) end
    end)
    btn.MouseButton1Click:Connect(function()
        selectPage(name)
        if Pages[name] then
            local bc = Pages[name]:FindFirstChild("_breadcrumb")
            if bc then bc.Text = "Home > " .. label end
        end
    end)
    NavButtons[name] = { Bg = item, LeftBar = leftBar }
end

local function makePage(name)
    local page = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false, LayoutOrder = 1, Parent = ContentArea,
    })
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8), Parent = page,
    })
    new("TextLabel", {
        Name = "_breadcrumb", BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 14),
        Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = THEME.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Home > " .. name,
        LayoutOrder = 0, Parent = page,
    })
    Pages[name] = page
    return page
end

local function sectionTitle(parent, title, desc, order)
    local f = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, desc and 56 or 32),
        LayoutOrder = order or 1, Parent = parent,
    })
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 30),
        Font = Enum.Font.GothamBold, TextSize = 24,
        TextColor3 = THEME.TextPrimary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = title, Parent = f,
    })
    if desc then
        new("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 32),
            Size = UDim2.new(1, 0, 0, 18),
            Font = Enum.Font.Gotham, TextSize = 13,
            TextColor3 = THEME.TextSecondary,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = desc, Parent = f,
        })
    end
    return f
end
--[[ ENGINE: helpers ]]
local function getCharacter(plr)
    plr = plr or LocalPlayer
    return plr.Character
end

local function getRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
end

local function getHumanoid(char)
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function isAlive(plr)
    local char = getCharacter(plr)
    local h = getHumanoid(char)
    return char and h and h.Health > 0
end

local function getPart(char, name)
    if not char then return nil end
    local part = char:FindFirstChild(name)
    if part and part:IsA("BasePart") then return part end
    return getRoot(char)
end

local function project(pos)
    local v, on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(v.X, v.Y), on, v.Z
end

local function distance2D(a, b)
    return math.sqrt((a.X - b.X)^2 + (a.Y - b.Y)^2)
end

local function rgbToColor(t) return colorOf(t) end

local function getDistance(plr)
    local root = getRoot(getCharacter(plr))
    local me = getRoot(getCharacter(LocalPlayer))
    if not root or not me then return math.huge end
    return (root.Position - me.Position).Magnitude
end

--[[ ENGINE: Aimbot ]]
local Aimbot = { fovCircle = nil }
local function aimbotActivationActive()
    local cfg = State.Aim.Aimbot
    if cfg.Activation == "Always" then return true end
    if not cfg.Key then return false end
    if cfg.Key:find("Mouse") then
        local mb
        if cfg.Key == "MouseButton1" then mb = Enum.UserInputType.MouseButton1
        elseif cfg.Key == "MouseButton2" then mb = Enum.UserInputType.MouseButton2
        elseif cfg.Key == "MouseButton3" then mb = Enum.UserInputType.MouseButton3 end
        if mb then return UserInputService:IsMouseButtonPressed(mb) end
    else
        local ok, kc = pcall(function() return Enum.KeyCode[cfg.Key] end)
        if ok and kc then return UserInputService:IsKeyDown(kc) end
    end
    return false
end

local function findAimTarget()
    local cfg = State.Aim.Aimbot
    local mouse = UserInputService:GetMouseLocation()
    local best, bestDist = nil, cfg.FOV
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) then
            if not (cfg.TeamCheck and LocalPlayer.Team and plr.Team == LocalPlayer.Team) then
                local part = getPart(plr.Character, cfg.TargetPart)
                if part then
                    local screen, on = project(part.Position)
                    if on then
                        local d = distance2D(screen, mouse)
                        if d < bestDist then
                            if cfg.WallCheck then
                                local params = RaycastParams.new()
                                params.FilterType = Enum.RaycastFilterType.Exclude
                                params.FilterDescendantsInstances = { LocalPlayer.Character }
                                local origin = Camera.CFrame.Position
                                local dir = (part.Position - origin)
                                local result = Workspace:Raycast(origin, dir, params)
                                if result and result.Instance and not result.Instance:IsDescendantOf(plr.Character) then
                                    -- blocked
                                else
                                    bestDist = d
                                    best = { plr = plr, part = part }
                                end
                            else
                                bestDist = d
                                best = { plr = plr, part = part }
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function startAimbot()
    if Aimbot.conn then return end
    if State.Aim.Aimbot.DrawFOV and Drawing then
        local ok, circle = pcall(function()
            local c = Drawing.new("Circle")
            c.Visible = true
            c.Thickness = 1
            c.NumSides = 64
            c.Filled = false
            c.Color = colorOf(State.Aim.Aimbot.FOVColor)
            return c
        end)
        if ok then Aimbot.fovCircle = circle end
    end
    Aimbot.conn = track(RunService.RenderStepped:Connect(function()
        if not State.Master.Enabled or not State.Aim.Aimbot.Enabled then return end
        local cfg = State.Aim.Aimbot
        if Aimbot.fovCircle then
            local mouse = UserInputService:GetMouseLocation()
            Aimbot.fovCircle.Position = Vector2.new(mouse.X, mouse.Y)
            Aimbot.fovCircle.Radius = cfg.FOV
            Aimbot.fovCircle.Color = colorOf(cfg.FOVColor)
            Aimbot.fovCircle.Visible = true
        end
        if not aimbotActivationActive() then return end
        local target = findAimTarget()
        if target then
            local part = target.part
            local pred = part.Position
            local vel = part.AssemblyLinearVelocity
            if vel then pred = pred + vel * cfg.Prediction end
            local lookCFrame = CFrame.new(Camera.CFrame.Position, pred)
            Camera.CFrame = Camera.CFrame:Lerp(lookCFrame, math.clamp(1 - cfg.Smoothness, 0.01, 1))
        end
    end))
end

local function stopAimbot()
    if Aimbot.conn then Aimbot.conn:Disconnect(); Aimbot.conn = nil end
    if Aimbot.fovCircle then
        pcall(function() Aimbot.fovCircle:Remove() end)
        Aimbot.fovCircle = nil
    end
end

--[[ ENGINE: TriggerBot ]]
local TriggerBot = {}
local function startTriggerBot()
    if TriggerBot.conn then return end
    local lastFire = 0
    TriggerBot.conn = track(RunService.RenderStepped:Connect(function()
        if not State.Master.Enabled or not State.Aim.TriggerBot.Enabled then return end
        local cfg = State.Aim.TriggerBot
        if cfg.Activation == "Hold" and cfg.Key then
            local pressed = false
            if cfg.Key:find("Mouse") then
                local mb
                if cfg.Key == "MouseButton2" then mb = Enum.UserInputType.MouseButton2
                elseif cfg.Key == "MouseButton3" then mb = Enum.UserInputType.MouseButton3 end
                if mb then pressed = UserInputService:IsMouseButtonPressed(mb) end
            end
            if not pressed then return end
        end
        if tick() - lastFire < cfg.Delay then return end
        local mouse = UserInputService:GetMouseLocation()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and isAlive(plr) then
                if not (cfg.TeamCheck and LocalPlayer.Team and plr.Team == LocalPlayer.Team) then
                    local part = getPart(plr.Character, "Head")
                    if part then
                        local screen, on = project(part.Position)
                        if on and distance2D(screen, mouse) < cfg.FOV then
                            lastFire = tick()
                            pcall(function()
                                VirtualUser:Button1Down(Vector2.new(mouse.X, mouse.Y))
                                task.wait(0.02)
                                VirtualUser:Button1Up(Vector2.new(mouse.X, mouse.Y))
                            end)
                            break
                        end
                    end
                end
            end
        end
    end))
end
local function stopTriggerBot()
    if TriggerBot.conn then TriggerBot.conn:Disconnect(); TriggerBot.conn = nil end
end

--[[ ENGINE: Silent Aim + Magic Bullet hook ]]
local SilentAim = {}
local autoDetectedRemote = nil
local lastClickTime = 0
track(UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and input.UserInputType == Enum.UserInputType.MouseButton1 then
        lastClickTime = tick()
    end
end))

local function findSilentTarget()
    local cfg = State.Aim.SilentAim
    local mouse = UserInputService:GetMouseLocation()
    local best, bestDist = nil, cfg.FOV
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) then
            if not (cfg.TeamCheck and LocalPlayer.Team and plr.Team == LocalPlayer.Team) then
                local part = getPart(plr.Character, cfg.TargetPart)
                if part then
                    local screen, on = project(part.Position)
                    if on then
                        local d = distance2D(screen, mouse)
                        if d < bestDist then
                            bestDist = d
                            best = { plr = plr, part = part }
                        end
                    end
                end
            end
        end
    end
    if best and math.random(1, 100) <= cfg.HitChance then return best end
    return nil
end

local mt = getrawmetatable(game)
if mt then
    pcall(function() setreadonly(mt, false) end)
    local oldNamecall = mt.__namecall
    if oldNamecall then
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod and getnamecallmethod() or ""
            local args = { ... }
            if not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
                if State.Master.Enabled then
                    -- AUTO-detect correlation
                    if State.Aim.SilentAim.Enabled and State.Aim.SilentAim.Method == "AUTO" and not autoDetectedRemote then
                        if tick() - lastClickTime < 0.1 then
                            for _, a in ipairs(args) do
                                if typeof(a) == "Vector3" or typeof(a) == "CFrame" then
                                    autoDetectedRemote = self
                                    State.Aim.SilentAim.RemotePath = self:GetFullName()
                                    pcall(notify, { title = "Silent Aim", body = "Auto-detected: " .. self.Name })
                                    break
                                end
                            end
                        end
                    end
                    -- Silent Aim modify args
                    local shouldRedirect = false
                    if State.Aim.SilentAim.Enabled then
                        if State.Aim.SilentAim.Method == "AUTO" and self == autoDetectedRemote then
                            shouldRedirect = true
                        elseif State.Aim.SilentAim.RemotePath ~= "" and self:GetFullName() == State.Aim.SilentAim.RemotePath then
                            shouldRedirect = true
                        end
                    end
                    if State.Aim.MagicBullet.Enabled and State.Aim.MagicBullet.RemotePath ~= "" and self:GetFullName() == State.Aim.MagicBullet.RemotePath then
                        shouldRedirect = true
                    end
                    if shouldRedirect then
                        local target = findSilentTarget()
                        if target then
                            local hitPos = target.part.Position
                            for i, a in ipairs(args) do
                                if typeof(a) == "Vector3" then
                                    args[i] = hitPos
                                    return oldNamecall(self, table.unpack(args))
                                elseif typeof(a) == "CFrame" then
                                    args[i] = CFrame.new(hitPos)
                                    return oldNamecall(self, table.unpack(args))
                                end
                            end
                        end
                    end
                end
            end
            -- Anti-cheat namecall blocklist
            if State.Spoof.AntiCheat.Enabled and not checkcaller() then
                local blocklist = State.Spoof.AntiCheat.NamecallBlocklist or ""
                for line in blocklist:gmatch("[^\r\n]+") do
                    if line ~= "" and method:lower():find(line:lower()) then return nil end
                end
                if State.Spoof.AntiCheat.AntiKick and method == "Kick" then return nil end
            end
            -- Spoof: UserOwnsGamePassAsync, Premium, etc.
            if State.Spoof.Gamepass.Enabled and method == "UserOwnsGamePassAsync" then
                local _, gpid = ...
                local wl = State.Spoof.Gamepass.Whitelist or ""
                if wl == "" then return true end
                for id in wl:gmatch("%d+") do
                    if tonumber(id) == gpid then return true end
                end
            end
            if State.Spoof.Asset.Enabled and method == "PlayerOwnsAsset" then return true end
            if State.Spoof.Badge.Enabled and method == "UserHasBadgeAsync" then return true end
            if State.Spoof.Group.Enabled and method == "GetRankInGroup" then
                return State.Spoof.Group.Rank
            end
            return oldNamecall(self, ...)
        end)
    end
    -- __index hook for Premium / WalkSpeed spoofing
    local oldIndex = mt.__index
    if oldIndex then
        mt.__index = newcclosure(function(self, key)
            if not checkcaller() then
                if State.Spoof.Premium.Enabled and key == "MembershipType" and self == LocalPlayer then
                    return Enum.MembershipType.Premium
                end
                if State.Spoof.AntiCheat.Enabled and typeof(self) == "Instance" and self:IsA("Humanoid") then
                    if key == "WalkSpeed" then return State.Spoof.AntiCheat.FakeWalkSpeed end
                    if key == "JumpPower" then return State.Spoof.AntiCheat.FakeJumpPower end
                end
            end
            return oldIndex(self, key)
        end)
    end
end

--[[ ENGINE: ESP ]]
local ESP = { items = {}, conn = nil }
local function clearPlayerESP(plr)
    local item = ESP.items[plr]
    if not item then return end
    if item.Highlight then item.Highlight:Destroy() end
    if item.NameGui then item.NameGui:Destroy() end
    if item.Box then pcall(function() item.Box:Remove() end) end
    if item.Tracer then pcall(function() item.Tracer:Remove() end) end
    if item.Skeleton then
        for _, l in ipairs(item.Skeleton) do pcall(function() l:Remove() end) end
    end
    ESP.items[plr] = nil
end

local function ensureItem(plr)
    if not ESP.items[plr] then ESP.items[plr] = {} end
    return ESP.items[plr]
end

local function updateESP()
    local cfg = State.Visual.ESP
    if not cfg.Master then
        for plr, _ in pairs(ESP.items) do clearPlayerESP(plr) end
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) then
            local skip = false
            if cfg.TeamCheck and LocalPlayer.Team and plr.Team == LocalPlayer.Team then skip = true end
            local dist = getDistance(plr)
            if dist > cfg.MaxDistance then skip = true end
            if not skip then
                local item = ensureItem(plr)
                local char = plr.Character
                local root = getRoot(char)
                if cfg.Chams then
                    if not item.Highlight then
                        local h = Instance.new("Highlight")
                        h.Adornee = char
                        h.FillColor = colorOf(cfg.ChamsColor)
                        h.OutlineColor = colorOf(cfg.ChamsOutlineColor)
                        h.FillTransparency = 0.6
                        h.OutlineTransparency = 0
                        h.Parent = char
                        item.Highlight = h
                    else
                        item.Highlight.Adornee = char
                        item.Highlight.FillColor = colorOf(cfg.ChamsColor)
                        item.Highlight.OutlineColor = colorOf(cfg.ChamsOutlineColor)
                    end
                elseif item.Highlight then item.Highlight:Destroy(); item.Highlight = nil end
                if cfg.Name or cfg.Health or cfg.Distance then
                    if not item.NameGui then
                        local bb = Instance.new("BillboardGui")
                        bb.Size = UDim2.new(0, 200, 0, 60)
                        bb.StudsOffset = Vector3.new(0, 3, 0)
                        bb.AlwaysOnTop = true
                        bb.Adornee = char:FindFirstChild("Head") or root
                        bb.Parent = char
                        local l = Instance.new("TextLabel")
                        l.BackgroundTransparency = 1
                        l.Size = UDim2.new(1, 0, 1, 0)
                        l.Font = Enum.Font.GothamSemibold
                        l.TextSize = 14
                        l.TextColor3 = colorOf(cfg.NameColor)
                        l.TextStrokeTransparency = 0.5
                        l.Parent = bb
                        item.NameGui = bb
                        item.NameLabel = l
                    end
                    item.NameGui.Adornee = char:FindFirstChild("Head") or root
                    local txt = ""
                    if cfg.Name then txt = plr.Name end
                    if cfg.Distance then txt = txt .. "\n[" .. math.floor(dist) .. "m]" end
                    if cfg.Health then
                        local h = getHumanoid(char)
                        if h then txt = txt .. "\n" .. math.floor(h.Health) .. "/" .. math.floor(h.MaxHealth) end
                    end
                    item.NameLabel.Text = txt
                    item.NameLabel.TextColor3 = colorOf(cfg.NameColor)
                elseif item.NameGui then item.NameGui:Destroy(); item.NameGui = nil end
                if Drawing and root then
                    if cfg.Box then
                        if not item.Box then
                            pcall(function()
                                item.Box = Drawing.new("Square")
                                item.Box.Thickness = 1
                                item.Box.Filled = false
                            end)
                        end
                        if item.Box then
                            local screen, on = project(root.Position)
                            local size = 4 / math.max(1, screen.Y / 100)
                            if on then
                                item.Box.Visible = true
                                item.Box.Color = colorOf(cfg.BoxColor)
                                item.Box.Size = Vector2.new(60, 90)
                                item.Box.Position = Vector2.new(screen.X - 30, screen.Y - 45)
                            else
                                item.Box.Visible = false
                            end
                        end
                    elseif item.Box then item.Box.Visible = false end
                    if cfg.Tracer then
                        if not item.Tracer then
                            pcall(function()
                                item.Tracer = Drawing.new("Line")
                                item.Tracer.Thickness = 1
                            end)
                        end
                        if item.Tracer then
                            local screen, on = project(root.Position)
                            if on then
                                item.Tracer.Visible = true
                                item.Tracer.Color = colorOf(cfg.TracerColor)
                                local cam = Camera.ViewportSize
                                item.Tracer.From = Vector2.new(cam.X / 2, cam.Y)
                                item.Tracer.To = screen
                            else
                                item.Tracer.Visible = false
                            end
                        end
                    elseif item.Tracer then item.Tracer.Visible = false end
                end
            else
                clearPlayerESP(plr)
            end
        else
            clearPlayerESP(plr)
        end
    end
end

local function startESP()
    if ESP.conn then return end
    ESP.conn = track(RunService.Heartbeat:Connect(function()
        if not State.Master.Enabled then return end
        pcall(updateESP)
    end))
end
local function stopESP()
    if ESP.conn then ESP.conn:Disconnect(); ESP.conn = nil end
    for plr, _ in pairs(ESP.items) do clearPlayerESP(plr) end
end
--[[ ENGINE: Movement ]]
local Movement = { flyBV = nil, flyBG = nil, flyConn = nil, noclipConn = nil,
    infJumpConn = nil, spinConn = nil, antiFlingConn = nil, antiVoidConn = nil,
    wallClimbConn = nil, spiderConn = nil, lastChar = nil, lastHumanoid = nil }

local function applyMovement()
    local char = getCharacter(LocalPlayer)
    local hum = getHumanoid(char)
    if not hum then return end
    if State.Movement.WalkSpeed.Enabled then hum.WalkSpeed = State.Movement.WalkSpeed.Value end
    if State.Movement.JumpPower.Enabled then
        hum.UseJumpPower = true
        hum.JumpPower = State.Movement.JumpPower.Value
    end
    if State.Movement.JumpHeight.Enabled then hum.JumpHeight = State.Movement.JumpHeight.Value end
    if State.Movement.HipHeight.Enabled then hum.HipHeight = State.Movement.HipHeight.Value end
    if State.Movement.Gravity.Enabled then Workspace.Gravity = State.Movement.Gravity.Value end
    if State.Movement.MaxSlope.Enabled then hum.MaxSlopeAngle = State.Movement.MaxSlope.Value end
end

local function startFly()
    if Movement.flyConn then return end
    local char = getCharacter(LocalPlayer)
    local root = getRoot(char)
    if not root then return end
    Movement.flyBV = Instance.new("BodyVelocity")
    Movement.flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    Movement.flyBV.Velocity = Vector3.new(0, 0, 0)
    Movement.flyBV.Parent = root
    Movement.flyBG = Instance.new("BodyGyro")
    Movement.flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    Movement.flyBG.P = 10000
    Movement.flyBG.Parent = root
    Movement.flyConn = track(RunService.Heartbeat:Connect(function()
        if not State.Movement.Fly.Enabled then return end
        local r = getRoot(getCharacter(LocalPlayer))
        if not r or not Movement.flyBV then return end
        Movement.flyBV.Parent = r
        Movement.flyBG.Parent = r
        Movement.flyBG.CFrame = Camera.CFrame
        local dir = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
        if dir.Magnitude > 0 then dir = dir.Unit * State.Movement.Fly.Speed end
        Movement.flyBV.Velocity = dir
    end))
end
local function stopFly()
    if Movement.flyConn then Movement.flyConn:Disconnect(); Movement.flyConn = nil end
    if Movement.flyBV then Movement.flyBV:Destroy(); Movement.flyBV = nil end
    if Movement.flyBG then Movement.flyBG:Destroy(); Movement.flyBG = nil end
end

local function startNoclip()
    if Movement.noclipConn then return end
    Movement.noclipConn = track(RunService.Stepped:Connect(function()
        if not State.Movement.Noclip.Enabled then return end
        local char = getCharacter(LocalPlayer)
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end))
end
local function stopNoclip()
    if Movement.noclipConn then Movement.noclipConn:Disconnect(); Movement.noclipConn = nil end
end

local function startInfJump()
    if Movement.infJumpConn then return end
    Movement.infJumpConn = track(UserInputService.JumpRequest:Connect(function()
        if not State.Movement.InfiniteJump.Enabled then return end
        local hum = getHumanoid(getCharacter(LocalPlayer))
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end))
end
local function stopInfJump()
    if Movement.infJumpConn then Movement.infJumpConn:Disconnect(); Movement.infJumpConn = nil end
end

local function startSpinbot()
    if Movement.spinConn then return end
    Movement.spinConn = track(RunService.Heartbeat:Connect(function(dt)
        if not State.Movement.Spinbot.Enabled then return end
        local root = getRoot(getCharacter(LocalPlayer))
        if root then
            local rate = State.Movement.Spinbot.Rate
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(rate * dt * 60), 0)
        end
    end))
end
local function stopSpinbot()
    if Movement.spinConn then Movement.spinConn:Disconnect(); Movement.spinConn = nil end
end

local function startAntiFling()
    if Movement.antiFlingConn then return end
    Movement.antiFlingConn = track(RunService.Heartbeat:Connect(function()
        if not State.Movement.AntiFling.Enabled then return end
        local root = getRoot(getCharacter(LocalPlayer))
        if root and root.AssemblyLinearVelocity.Magnitude > State.Movement.AntiFling.Threshold then
            root.AssemblyLinearVelocity = Vector3.new()
            root.AssemblyAngularVelocity = Vector3.new()
        end
    end))
end
local function stopAntiFling()
    if Movement.antiFlingConn then Movement.antiFlingConn:Disconnect(); Movement.antiFlingConn = nil end
end

local function startAntiVoid()
    if Movement.antiVoidConn then return end
    Movement.antiVoidConn = track(RunService.Heartbeat:Connect(function()
        if not State.Movement.AntiVoid.Enabled then return end
        local root = getRoot(getCharacter(LocalPlayer))
        if root and root.Position.Y < State.Movement.AntiVoid.Threshold then
            root.CFrame = CFrame.new(0, 100, 0)
            root.AssemblyLinearVelocity = Vector3.new()
        end
    end))
end
local function stopAntiVoid()
    if Movement.antiVoidConn then Movement.antiVoidConn:Disconnect(); Movement.antiVoidConn = nil end
end

local function tpForward()
    local root = getRoot(getCharacter(LocalPlayer))
    if not root then return end
    root.CFrame = root.CFrame + Camera.CFrame.LookVector * State.Movement.TPForward.Distance
end

local function moonJump()
    local hum = getHumanoid(getCharacter(LocalPlayer))
    local root = getRoot(getCharacter(LocalPlayer))
    if hum and root then
        root.AssemblyLinearVelocity = root.AssemblyLinearVelocity + Vector3.new(0, State.Movement.MoonJump.Power, 0)
    end
end

local function speedBurst()
    local hum = getHumanoid(getCharacter(LocalPlayer))
    if not hum then return end
    local orig = hum.WalkSpeed
    hum.WalkSpeed = orig * State.Movement.SpeedBurst.Multiplier
    task.delay(State.Movement.SpeedBurst.Duration, function()
        if getHumanoid(getCharacter(LocalPlayer)) then
            getHumanoid(getCharacter(LocalPlayer)).WalkSpeed = orig
        end
    end)
end

local function panicReset()
    State.Movement.Fly.Enabled = false; stopFly()
    State.Movement.Noclip.Enabled = false; stopNoclip()
    State.Movement.InfiniteJump.Enabled = false; stopInfJump()
    State.Movement.Spinbot.Enabled = false; stopSpinbot()
    State.Movement.WalkSpeed.Enabled = false
    State.Movement.JumpPower.Enabled = false
    local hum = getHumanoid(getCharacter(LocalPlayer))
    if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
    Workspace.Gravity = 196.2
end

track(LocalPlayer.CharacterAdded:Connect(function(char)
    Movement.lastChar = char
    task.wait(0.5)
    if State.Movement.AutoReapply.Enabled then applyMovement() end
end))

--[[ ENGINE: World / Teleport ]]
local World = { freeCamConn = nil, spectateConn = nil, ctrlClickConn = nil }

local function tpToPlayer(plr, offset)
    local root = getRoot(getCharacter(LocalPlayer))
    local troot = getRoot(getCharacter(plr))
    if root and troot then
        root.CFrame = troot.CFrame + (offset or Vector3.new(0, 3, 0))
    end
end

local function saveSlot(i)
    local root = getRoot(getCharacter(LocalPlayer))
    if root then
        State.World.Slots[i] = { root.CFrame.X, root.CFrame.Y, root.CFrame.Z,
            root.CFrame.LookVector.X, root.CFrame.LookVector.Y, root.CFrame.LookVector.Z }
        notify({ title = "World", body = "Saved slot " .. i })
    end
end

local function loadSlot(i)
    local s = State.World.Slots[i]
    local root = getRoot(getCharacter(LocalPlayer))
    if s and root then
        root.CFrame = CFrame.new(Vector3.new(s[1], s[2], s[3]),
            Vector3.new(s[1] + s[4], s[2] + s[5], s[3] + s[6]))
        notify({ title = "World", body = "Loaded slot " .. i })
    end
end

local function tpToNearest()
    local me = getRoot(getCharacter(LocalPlayer))
    if not me then return end
    local best, bestD = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) then
            local d = getDistance(p)
            if d < bestD then bestD = d; best = p end
        end
    end
    if best then tpToPlayer(best) end
end

local function tpToRandom()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) then table.insert(list, p) end
    end
    if #list > 0 then tpToPlayer(list[math.random(1, #list)]) end
end

local function startCtrlClickTP()
    if World.ctrlClickConn then return end
    World.ctrlClickConn = track(UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if not State.World.CtrlClickTP then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            local hit = Mouse.Hit
            local root = getRoot(getCharacter(LocalPlayer))
            if root and hit then root.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0)) end
        end
    end))
end
local function stopCtrlClickTP()
    if World.ctrlClickConn then World.ctrlClickConn:Disconnect(); World.ctrlClickConn = nil end
end

local function serverHop()
    pcall(function()
        local placeId = game.PlaceId
        local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
        local res = HttpService:JSONDecode(game:HttpGet(url))
        local lowest, lowestId = math.huge, nil
        local threshold = State.World.ServerHop.Threshold
        for _, s in ipairs(res.data or {}) do
            if s.playing and s.playing < lowest and s.playing >= 1 and s.id ~= game.JobId
                and s.playing <= threshold then
                lowest = s.playing
                lowestId = s.id
            end
        end
        if lowestId then
            TeleportService:TeleportToPlaceInstance(placeId, lowestId, LocalPlayer)
        else
            notify({ title = "Server Hop", body = "No matching server found", accent = THEME.Warning })
        end
    end)
end

local function rejoin()
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end

--[[ ENGINE: Desync ]]
local Desync = { conn = nil, fakeChar = nil }
local function getDesyncOffset()
    local dir = State.Combat.Desync.Direction
    local mag = State.Combat.Desync.Offset
    local look = Camera.CFrame.LookVector
    if dir == "Forward" then return Vector3.new(look.X, 0, look.Z).Unit * mag
    elseif dir == "Back" then return -Vector3.new(look.X, 0, look.Z).Unit * mag
    elseif dir == "Left" then
        local r = Camera.CFrame.RightVector
        return -Vector3.new(r.X, 0, r.Z).Unit * mag
    elseif dir == "Right" then
        local r = Camera.CFrame.RightVector
        return Vector3.new(r.X, 0, r.Z).Unit * mag
    elseif dir == "Up" then return Vector3.new(0, mag, 0)
    elseif dir == "Down" then return Vector3.new(0, -mag, 0) end
    return Vector3.new()
end

local function startDesync()
    if Desync.conn then return end
    Desync.conn = track(RunService.Heartbeat:Connect(function()
        if not State.Master.Enabled or not State.Combat.Desync.Enabled then return end
        local root = getRoot(getCharacter(LocalPlayer))
        if not root then return end
        local method = State.Combat.Desync.Method
        local offset = getDesyncOffset()
        if method == "NetworkOwner" or method == "Combined" then
            pcall(function() root.CFrame = root.CFrame + offset end)
        end
        if method == "VelocitySlam" or method == "Combined" then
            root.AssemblyLinearVelocity = offset * 50
        end
        if method == "FakeCharacter" or method == "Combined" then
            if not Desync.fakeChar or not Desync.fakeChar.Parent then
                local char = getCharacter(LocalPlayer)
                if char then
                    Desync.fakeChar = char:Clone()
                    for _, p in ipairs(Desync.fakeChar:GetDescendants()) do
                        if p:IsA("HumanoidRootPart") then p:Destroy() end
                    end
                    Desync.fakeChar.Parent = Workspace
                end
            end
            if Desync.fakeChar then
                local fr = Desync.fakeChar:FindFirstChild("Torso") or Desync.fakeChar:FindFirstChild("UpperTorso")
                if fr then fr.CFrame = root.CFrame + offset end
            end
        end
    end))
end
local function stopDesync()
    if Desync.conn then Desync.conn:Disconnect(); Desync.conn = nil end
    if Desync.fakeChar then Desync.fakeChar:Destroy(); Desync.fakeChar = nil end
end

--[[ ENGINE: Hitbox Extender ]]
local Hitbox = { conn = nil, originals = {} }
local function startHitbox()
    if Hitbox.conn then return end
    Hitbox.conn = track(RunService.Heartbeat:Connect(function()
        if not State.Combat.Hitbox.Enabled then return end
        local cfg = State.Combat.Hitbox
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and isAlive(plr) then
                local part = getPart(plr.Character, cfg.TargetPart)
                if part then
                    if not Hitbox.originals[part] then
                        Hitbox.originals[part] = { Size = part.Size, Transparency = part.Transparency,
                            Color = part.Color, CanCollide = part.CanCollide, Material = part.Material }
                    end
                    part.Size = Vector3.new(cfg.Size, cfg.Size, cfg.Size)
                    part.Transparency = cfg.Transparency
                    part.Color = colorOf(cfg.Color)
                    part.CanCollide = false
                    part.Material = Enum.Material.ForceField
                end
            end
        end
    end))
end
local function stopHitbox()
    if Hitbox.conn then Hitbox.conn:Disconnect(); Hitbox.conn = nil end
    for part, o in pairs(Hitbox.originals) do
        if part and part.Parent then
            pcall(function()
                part.Size = o.Size; part.Transparency = o.Transparency
                part.Color = o.Color; part.CanCollide = o.CanCollide
                part.Material = o.Material
            end)
        end
    end
    Hitbox.originals = {}
end

--[[ ENGINE: Misc ]]
local Misc = { antiAFKConn = nil, fullbrightSnap = nil, music = nil }
local function startAntiAFK()
    if Misc.antiAFKConn then return end
    Misc.antiAFKConn = track(LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end))
end
local function stopAntiAFK()
    if Misc.antiAFKConn then Misc.antiAFKConn:Disconnect(); Misc.antiAFKConn = nil end
end

local function applyFullbright()
    if not Misc.fullbrightSnap then
        Misc.fullbrightSnap = {
            Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
            OutdoorAmbient = Lighting.OutdoorAmbient, Ambient = Lighting.Ambient,
        }
    end
    Lighting.Brightness = 2
    Lighting.ClockTime = 12
    Lighting.FogEnd = 100000
    Lighting.GlobalShadows = false
    Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    Lighting.Ambient = Color3.new(1, 1, 1)
end
local function restoreLighting()
    if Misc.fullbrightSnap then
        for k, v in pairs(Misc.fullbrightSnap) do Lighting[k] = v end
        Misc.fullbrightSnap = nil
    end
end

local function playMusic(url)
    if Misc.music then Misc.music:Destroy() end
    Misc.music = Instance.new("Sound")
    Misc.music.SoundId = url
    Misc.music.Volume = State.Misc.Volume.Value
    Misc.music.Looped = true
    Misc.music.Parent = LocalPlayer
    Misc.music:Play()
end
local function stopMusic()
    if Misc.music then Misc.music:Destroy(); Misc.music = nil end
end

--[[ ENGINE: Chat Spy ]]
local ChatLog = {}
local function logChat(speaker, text, channel, isWhisper)
    table.insert(ChatLog, {
        speaker = speaker, text = text, channel = channel or "Main",
        whisper = isWhisper, time = os.time(),
    })
    if #ChatLog > 200 then table.remove(ChatLog, 1) end
end

local chatStarted = false
local function startChatSpy()
    if chatStarted then return end
    chatStarted = true
    pcall(function()
        for _, p in ipairs(Players:GetPlayers()) do
            track(p.Chatted:Connect(function(msg) if State.Player.ChatSpy.Enabled then logChat(p.Name, msg, "All", false) end end))
        end
        track(Players.PlayerAdded:Connect(function(p)
            track(p.Chatted:Connect(function(msg) if State.Player.ChatSpy.Enabled then logChat(p.Name, msg, "All", false) end end))
        end))
    end)
end

--[[ ENGINE: RemoteSpy ]]
local RemoteLog = {}
local function logRemote(remote, args, method)
    if State.Network.RemoteSpy.Paused then return end
    local entry = { name = remote.Name, full = remote:GetFullName(),
        method = method, time = os.time(), args = {} }
    for i, a in ipairs(args) do entry.args[i] = typeof(a) .. ": " .. tostring(a) end
    table.insert(RemoteLog, entry)
    if #RemoteLog > 30 then table.remove(RemoteLog, 1) end
end
--[[ NAV ITEMS ]]
addNavItem("HOME",     "Home",     "H", 1)
addNavItem("AIM",      "Aim",      "A", 2)
addNavItem("VISUAL",   "Visual",   "V", 3)
addNavItem("MOVEMENT", "Movement", "M", 4)
addNavItem("WORLD",    "World",    "W", 5)
addNavItem("COMBAT",   "Combat",   "C", 6)
addNavItem("SPOOF",    "Spoof",    "S", 7)
addNavItem("NETWORK",  "Network",  "N", 8)
addNavItem("PLAYER",   "Player",   "P", 9)
addNavItem("MISC",     "Misc",     "X", 10)
addNavItem("CONFIGS",  "Configs",  "G", 11)

--[[ PAGE: HOME ]]
local function buildHome()
    local page = makePage("HOME")
    sectionTitle(page, "Home", "Welcome to FREEZER. Pick a category from the sidebar.")
    local welc = createCard(page, "FREEZER v4.0.0", "by ENI for LO")
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 60),
        Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = THEME.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Text = "Executor: " .. EXECUTOR_NAME .. "\nPlace: " .. tostring(game.PlaceId) .. "\nAll features default OFF. Tick what you want.",
        Parent = welc,
    })
    local kill = createCard(page, "Master Kill Switch", "Disables every running engine at once.")
    createToggle(kill, "Master Enabled", State.Master.Enabled, function(v)
        State.Master.Enabled = v
        notify({ title = "Master", body = v and "Engines armed" or "Engines disarmed" })
    end)
    createKeybind(kill, "Toggle Hub", State.Master.ToggleKey, function(k) State.Master.ToggleKey = k end)
    local stat = createCard(page, "Status", "Live snapshot of the current server.")
    local statusInfo = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 100),
        Font = Enum.Font.Code, TextSize = 12,
        TextColor3 = THEME.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = "Loading...", Parent = stat,
    })
    task.spawn(function()
        while statusInfo.Parent do
            local ok, name = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId).Name end)
            statusInfo.Text = string.format(
                "Game: %s\nPlaceId: %s\nJobId: %s\nPlayers: %d/%d\nMax FPS: %d",
                ok and name or "Unknown", tostring(game.PlaceId), tostring(game.JobId),
                #Players:GetPlayers(), Players.MaxPlayers,
                math.floor(1 / RunService.RenderStepped:Wait()))
            task.wait(2)
        end
    end)
    local quick = createCard(page, "Quick Toggles", "One-tap switches for the big features.")
    createToggle(quick, "Master ESP", State.Visual.ESP.Master, function(v)
        State.Visual.ESP.Master = v
        if v then startESP() else stopESP() end
    end)
    createToggle(quick, "Master Aimbot", State.Aim.Aimbot.Enabled, function(v)
        State.Aim.Aimbot.Enabled = v
        if v then startAimbot() else stopAimbot() end
    end)
    createToggle(quick, "Master Silent Aim", State.Aim.SilentAim.Enabled, function(v)
        State.Aim.SilentAim.Enabled = v
    end)
    createToggle(quick, "Anti-AFK", State.Misc.AntiAFK.Enabled, function(v)
        State.Misc.AntiAFK.Enabled = v
        if v then startAntiAFK() else stopAntiAFK() end
    end)
    createToggle(quick, "Fullbright", State.Misc.Fullbright.Enabled, function(v)
        State.Misc.Fullbright.Enabled = v
        if v then applyFullbright() else restoreLighting() end
    end)
end

--[[ PAGE: AIM ]]
local function buildAim()
    local page = makePage("AIM")
    sectionTitle(page, "Aim", "Aimbot, trigger bot, silent aim, magic bullet.")
    local aim = createCard(page, "Aimbot", "Smooth aim assist with raycast wall check.",
        State.Aim.Aimbot.Enabled, function(v)
            State.Aim.Aimbot.Enabled = v
            if v then startAimbot() else stopAimbot() end
        end)
    createSlider(aim, "FOV", 1, 800, State.Aim.Aimbot.FOV, function(v) State.Aim.Aimbot.FOV = v end)
    createSlider(aim, "Smoothness", 0, 1, State.Aim.Aimbot.Smoothness, function(v) State.Aim.Aimbot.Smoothness = v end, nil, 2)
    createDropdown(aim, "Target Part", {"Head","HumanoidRootPart","UpperTorso","LowerTorso"},
        State.Aim.Aimbot.TargetPart, function(v) State.Aim.Aimbot.TargetPart = v end)
    createToggle(aim, "Team Check", State.Aim.Aimbot.TeamCheck, function(v) State.Aim.Aimbot.TeamCheck = v end)
    createToggle(aim, "Wall Check", State.Aim.Aimbot.WallCheck, function(v) State.Aim.Aimbot.WallCheck = v end)
    createSlider(aim, "Prediction", 0, 0.5, State.Aim.Aimbot.Prediction, function(v) State.Aim.Aimbot.Prediction = v end, nil, 3)
    createDropdown(aim, "Activation", {"Hold","Toggle","Always"}, State.Aim.Aimbot.Activation, function(v) State.Aim.Aimbot.Activation = v end)
    createKeybind(aim, "Key", State.Aim.Aimbot.Key, function(k) State.Aim.Aimbot.Key = k end)
    createToggle(aim, "Draw FOV Circle", State.Aim.Aimbot.DrawFOV, function(v) State.Aim.Aimbot.DrawFOV = v end)
    createColorPicker(aim, "FOV Color", State.Aim.Aimbot.FOVColor, function(c) State.Aim.Aimbot.FOVColor = c end)

    local trig = createCard(page, "Trigger Bot", "Auto-clicks when a target enters your crosshair.",
        State.Aim.TriggerBot.Enabled, function(v)
            State.Aim.TriggerBot.Enabled = v
            if v then startTriggerBot() else stopTriggerBot() end
        end)
    createSlider(trig, "Delay", 0, 1, State.Aim.TriggerBot.Delay, function(v) State.Aim.TriggerBot.Delay = v end, nil, 2)
    createSlider(trig, "FOV", 1, 50, State.Aim.TriggerBot.FOV, function(v) State.Aim.TriggerBot.FOV = v end)
    createToggle(trig, "Team Check", State.Aim.TriggerBot.TeamCheck, function(v) State.Aim.TriggerBot.TeamCheck = v end)
    createKeybind(trig, "Key", State.Aim.TriggerBot.Key, function(k) State.Aim.TriggerBot.Key = k end)
    createDropdown(trig, "Activation", {"Hold","Always"}, State.Aim.TriggerBot.Activation, function(v) State.Aim.TriggerBot.Activation = v end)

    local sil = createCard(page, "Silent Aim", "Hooks shoot remote and rewrites hit position.",
        State.Aim.SilentAim.Enabled, function(v) State.Aim.SilentAim.Enabled = v end)
    createDropdown(sil, "Method", {"AUTO","Namecall","RayHook","WorkspaceRaycast","RemoteEvent"},
        State.Aim.SilentAim.Method, function(v) State.Aim.SilentAim.Method = v end)
    createSlider(sil, "FOV", 1, 800, State.Aim.SilentAim.FOV, function(v) State.Aim.SilentAim.FOV = v end)
    createDropdown(sil, "Target Part", {"Head","HumanoidRootPart","UpperTorso"},
        State.Aim.SilentAim.TargetPart, function(v) State.Aim.SilentAim.TargetPart = v end)
    createSlider(sil, "Hit Chance", 1, 100, State.Aim.SilentAim.HitChance, function(v) State.Aim.SilentAim.HitChance = v end)
    createToggle(sil, "Team Check", State.Aim.SilentAim.TeamCheck, function(v) State.Aim.SilentAim.TeamCheck = v end)
    createToggle(sil, "Wall Check", State.Aim.SilentAim.WallCheck, function(v) State.Aim.SilentAim.WallCheck = v end)
    createTextbox(sil, "Remote Path", State.Aim.SilentAim.RemotePath, function(t) State.Aim.SilentAim.RemotePath = t end, nil, "Full path or empty for AUTO")

    local mag = createCard(page, "Magic Bullet", "Forces hit position regardless of LOS.",
        State.Aim.MagicBullet.Enabled, function(v) State.Aim.MagicBullet.Enabled = v end)
    createTextbox(mag, "Remote Path", State.Aim.MagicBullet.RemotePath, function(t) State.Aim.MagicBullet.RemotePath = t end, nil, "Full path")
    createToggle(mag, "Auto Detect", State.Aim.MagicBullet.AutoDetect, function(v) State.Aim.MagicBullet.AutoDetect = v end)
    createSlider(mag, "Hit Pos Arg Index", 1, 6, State.Aim.MagicBullet.HitPosArgIndex, function(v) State.Aim.MagicBullet.HitPosArgIndex = v end)
    createDropdown(mag, "Target Part", {"Head","HumanoidRootPart","UpperTorso"},
        State.Aim.MagicBullet.TargetPart, function(v) State.Aim.MagicBullet.TargetPart = v end)
end

--[[ PAGE: VISUAL ]]
local function buildVisual()
    local page = makePage("VISUAL")
    sectionTitle(page, "Visual", "ESP toggles, colors, and visibility filters.")
    local esp = createCard(page, "ESP", "Box, name, health, distance, tracer, skeleton, chams.",
        State.Visual.ESP.Master, function(v)
            State.Visual.ESP.Master = v
            if v then startESP() else stopESP() end
        end)
    createToggle(esp, "Box",      State.Visual.ESP.Box,      function(v) State.Visual.ESP.Box = v end)
    createToggle(esp, "Name",     State.Visual.ESP.Name,     function(v) State.Visual.ESP.Name = v end)
    createToggle(esp, "Health",   State.Visual.ESP.Health,   function(v) State.Visual.ESP.Health = v end)
    createToggle(esp, "Distance", State.Visual.ESP.Distance, function(v) State.Visual.ESP.Distance = v end)
    createToggle(esp, "Tracer",   State.Visual.ESP.Tracer,   function(v) State.Visual.ESP.Tracer = v end)
    createToggle(esp, "Skeleton", State.Visual.ESP.Skeleton, function(v) State.Visual.ESP.Skeleton = v end)
    createToggle(esp, "Chams",    State.Visual.ESP.Chams,    function(v) State.Visual.ESP.Chams = v end)

    local col = createCard(page, "Colors", "Tint every ESP layer.")
    createColorPicker(col, "Box Color",     State.Visual.ESP.BoxColor,     function(c) State.Visual.ESP.BoxColor = c end)
    createColorPicker(col, "Name Color",    State.Visual.ESP.NameColor,    function(c) State.Visual.ESP.NameColor = c end)
    createColorPicker(col, "Health Color",  State.Visual.ESP.HealthColor,  function(c) State.Visual.ESP.HealthColor = c end)
    createColorPicker(col, "Tracer Color",  State.Visual.ESP.TracerColor,  function(c) State.Visual.ESP.TracerColor = c end)
    createColorPicker(col, "Chams Fill",    State.Visual.ESP.ChamsColor,   function(c) State.Visual.ESP.ChamsColor = c end)
    createColorPicker(col, "Chams Outline", State.Visual.ESP.ChamsOutlineColor, function(c) State.Visual.ESP.ChamsOutlineColor = c end)

    local fil = createCard(page, "Filters", "Limit who gets rendered.")
    createToggle(fil, "Team Check",    State.Visual.ESP.TeamCheck, function(v) State.Visual.ESP.TeamCheck = v end)
    createSlider(fil, "Max Distance", 50, 5000, State.Visual.ESP.MaxDistance, function(v) State.Visual.ESP.MaxDistance = v end)
    createToggle(fil, "Show NPCs",    State.Visual.ESP.ShowNPCs,  function(v) State.Visual.ESP.ShowNPCs = v end)
    createDropdown(fil, "Tracer Origin", {"Bottom","Top","Center","Mouse"},
        State.Visual.ESP.TracerOrigin, function(v) State.Visual.ESP.TracerOrigin = v end)
end

--[[ PAGE: MOVEMENT ]]
local function buildMovement()
    local page = makePage("MOVEMENT")
    sectionTitle(page, "Movement", "WalkSpeed, fly, noclip, anti-fling and friends.")
    local core = createCard(page, "Core", "Per-stat toggle + value.")
    createToggle(core, "WalkSpeed",  State.Movement.WalkSpeed.Enabled, function(v) State.Movement.WalkSpeed.Enabled = v; applyMovement() end)
    createSlider(core, "  Value", 0, 500, State.Movement.WalkSpeed.Value, function(v) State.Movement.WalkSpeed.Value = v; applyMovement() end)
    createToggle(core, "JumpPower",  State.Movement.JumpPower.Enabled, function(v) State.Movement.JumpPower.Enabled = v; applyMovement() end)
    createSlider(core, "  Value", 0, 500, State.Movement.JumpPower.Value, function(v) State.Movement.JumpPower.Value = v; applyMovement() end)
    createToggle(core, "JumpHeight", State.Movement.JumpHeight.Enabled, function(v) State.Movement.JumpHeight.Enabled = v; applyMovement() end)
    createSlider(core, "  Value", 0, 200, State.Movement.JumpHeight.Value, function(v) State.Movement.JumpHeight.Value = v; applyMovement() end, nil, 1)
    createToggle(core, "HipHeight",  State.Movement.HipHeight.Enabled, function(v) State.Movement.HipHeight.Enabled = v; applyMovement() end)
    createSlider(core, "  Value", 0, 20, State.Movement.HipHeight.Value, function(v) State.Movement.HipHeight.Value = v; applyMovement() end, nil, 1)
    createToggle(core, "Gravity",    State.Movement.Gravity.Enabled, function(v) State.Movement.Gravity.Enabled = v; applyMovement() end)
    createSlider(core, "  Value", 0, 300, State.Movement.Gravity.Value, function(v) State.Movement.Gravity.Value = v; applyMovement() end, nil, 1)
    createToggle(core, "MaxSlope",   State.Movement.MaxSlope.Enabled, function(v) State.Movement.MaxSlope.Enabled = v; applyMovement() end)
    createSlider(core, "  Value", 0, 89, State.Movement.MaxSlope.Value, function(v) State.Movement.MaxSlope.Value = v; applyMovement() end)

    local ab = createCard(page, "Abilities", "Fly, noclip, infinite jump, etc.")
    createToggle(ab, "Fly", State.Movement.Fly.Enabled, function(v) State.Movement.Fly.Enabled = v; if v then startFly() else stopFly() end end)
    createSlider(ab, "  Speed", 1, 500, State.Movement.Fly.Speed, function(v) State.Movement.Fly.Speed = v end)
    createDropdown(ab, "  Mode", {"Camera","World"}, State.Movement.Fly.Mode, function(v) State.Movement.Fly.Mode = v end)
    createKeybind(ab, "  Toggle Key", State.Movement.Fly.ToggleKey, function(k) State.Movement.Fly.ToggleKey = k end)
    createToggle(ab, "Infinite Jump", State.Movement.InfiniteJump.Enabled, function(v) State.Movement.InfiniteJump.Enabled = v; if v then startInfJump() else stopInfJump() end end)
    createToggle(ab, "Noclip",        State.Movement.Noclip.Enabled, function(v) State.Movement.Noclip.Enabled = v; if v then startNoclip() else stopNoclip() end end)
    createToggle(ab, "Spinbot",       State.Movement.Spinbot.Enabled, function(v) State.Movement.Spinbot.Enabled = v; if v then startSpinbot() else stopSpinbot() end end)
    createSlider(ab, "  Rate", 1, 200, State.Movement.Spinbot.Rate, function(v) State.Movement.Spinbot.Rate = v end)
    createSlider(ab, "TP Forward Dist", 1, 200, State.Movement.TPForward.Distance, function(v) State.Movement.TPForward.Distance = v end)
    createKeybind(ab, "TP Forward Key", State.Movement.TPForward.Key, function(k) State.Movement.TPForward.Key = k end)
    createToggle(ab, "Wall Climb", State.Movement.WallClimb.Enabled, function(v) State.Movement.WallClimb.Enabled = v end)
    createToggle(ab, "Moon Jump",  State.Movement.MoonJump.Enabled, function(v) State.Movement.MoonJump.Enabled = v end)
    createSlider(ab, "  Power", 10, 500, State.Movement.MoonJump.Power, function(v) State.Movement.MoonJump.Power = v end)
    createToggle(ab, "Spider Climb", State.Movement.SpiderClimb.Enabled, function(v) State.Movement.SpiderClimb.Enabled = v end)
    createToggle(ab, "Speed Burst", State.Movement.SpeedBurst.Enabled, function(v) State.Movement.SpeedBurst.Enabled = v end)
    createSlider(ab, "  Multiplier", 1, 20, State.Movement.SpeedBurst.Multiplier, function(v) State.Movement.SpeedBurst.Multiplier = v end, nil, 1)
    createSlider(ab, "  Duration", 0.1, 10, State.Movement.SpeedBurst.Duration, function(v) State.Movement.SpeedBurst.Duration = v end, nil, 1)
    createKeybind(ab, "  Key", State.Movement.SpeedBurst.Key, function(k) State.Movement.SpeedBurst.Key = k end)

    local safe = createCard(page, "Safety", "Anti-fling, anti-void, panic reset.")
    createToggle(safe, "Anti-Fling", State.Movement.AntiFling.Enabled, function(v) State.Movement.AntiFling.Enabled = v; if v then startAntiFling() else stopAntiFling() end end)
    createSlider(safe, "  Threshold", 50, 5000, State.Movement.AntiFling.Threshold, function(v) State.Movement.AntiFling.Threshold = v end)
    createToggle(safe, "Anti-Void", State.Movement.AntiVoid.Enabled, function(v) State.Movement.AntiVoid.Enabled = v; if v then startAntiVoid() else stopAntiVoid() end end)
    createSlider(safe, "  Threshold", -2000, 0, State.Movement.AntiVoid.Threshold, function(v) State.Movement.AntiVoid.Threshold = v end)
    createToggle(safe, "Auto Reapply on Respawn", State.Movement.AutoReapply.Enabled, function(v) State.Movement.AutoReapply.Enabled = v end)
    createKeybind(safe, "Panic Reset Key", State.Movement.PanicKey, function(k) State.Movement.PanicKey = k end)
end
--[[ PAGE: WORLD ]]
local function buildWorld()
    local page = makePage("WORLD")
    sectionTitle(page, "World", "Teleport, camera, server hop.")
    local tp = createCard(page, "Teleport", "TP to player, save slots, named waypoints.")
    local plrOpts = {}
    local function refreshPlayerOpts()
        plrOpts = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(plrOpts, p.Name) end
        end
        if #plrOpts == 0 then table.insert(plrOpts, "(none)") end
    end
    refreshPlayerOpts()
    track(Players.PlayerAdded:Connect(refreshPlayerOpts))
    track(Players.PlayerRemoving:Connect(refreshPlayerOpts))
    local selectedPlr = plrOpts[1] or ""
    createDropdown(tp, "Target Player", plrOpts, selectedPlr, function(v) selectedPlr = v end)
    local offX, offY, offZ = 0, 3, 0
    createSlider(tp, "Offset X", -50, 50, 0, function(v) offX = v end)
    createSlider(tp, "Offset Y", -50, 50, 3, function(v) offY = v end)
    createSlider(tp, "Offset Z", -50, 50, 0, function(v) offZ = v end)
    local goRow = createRow(tp, 38)
    createButton(goRow, "Go", "primary", function()
        local p = Players:FindFirstChild(selectedPlr)
        if p then tpToPlayer(p, Vector3.new(offX, offY, offZ)) end
    end).Position = UDim2.new(1, -100, 0, 4)

    local slots = createCard(page, "Save Slots", "Click number to save current pos. Click again to load.")
    local slotRow = createRow(slots, 38)
    for i = 1, 10 do
        local b = createButton(slotRow, tostring(i), "secondary", function()
            if State.World.Slots[i] then loadSlot(i) else saveSlot(i) end
        end)
        b.Size = UDim2.new(0, 28, 0, 28)
        b.Position = UDim2.new(0, (i - 1) * 32, 0.5, -14)
    end

    local wp = createCard(page, "Waypoints", "Named teleport bookmarks.")
    local wpName = createTextbox(wp, "Name", "", function(t) end, nil, "Spawn / Boss room / ...")
    local addWp = createButton(wp, "Add waypoint", "primary", function()
        local root = getRoot(getCharacter(LocalPlayer))
        local nm = wpName.Get()
        if root and nm ~= "" then
            State.World.Waypoints[nm] = { root.CFrame.X, root.CFrame.Y, root.CFrame.Z }
            notify({ title = "Waypoint", body = "Saved: " .. nm })
        end
    end)
    addWp.Size = UDim2.new(1, 0, 0, 30)
    createToggle(wp, "Ctrl+Click TP", State.World.CtrlClickTP, function(v)
        State.World.CtrlClickTP = v
        if v then startCtrlClickTP() else stopCtrlClickTP() end
    end)
    createKeybind(wp, "TP to Nearest", State.World.TPNearestKey, function(k) State.World.TPNearestKey = k end)
    createKeybind(wp, "TP to Random", State.World.TPRandomKey, function(k) State.World.TPRandomKey = k end)

    local cam = createCard(page, "Camera", "FOV, free cam, spectate.")
    createSlider(cam, "FOV", 30, 120, State.World.FOV, function(v)
        State.World.FOV = v
        Camera.FieldOfView = v
    end)
    createToggle(cam, "Free Cam", State.World.FreeCam.Enabled, function(v) State.World.FreeCam.Enabled = v end)
    createSlider(cam, "  Free Cam Speed", 1, 500, State.World.FreeCam.Speed, function(v) State.World.FreeCam.Speed = v end)
    local specOpts = {}
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(specOpts, p.Name) end end
    if #specOpts == 0 then specOpts = { "(none)" } end
    local specTarget = specOpts[1]
    createDropdown(cam, "Spectate", specOpts, specTarget, function(v) specTarget = v end)
    local specRow = createRow(cam, 38)
    createButton(specRow, "Spec", "primary", function()
        local p = Players:FindFirstChild(specTarget)
        if p and p.Character then Camera.CameraSubject = p.Character:FindFirstChildOfClass("Humanoid") end
    end).Position = UDim2.new(0, 0, 0, 4)
    createButton(specRow, "Stop", "secondary", function()
        Camera.CameraSubject = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    end).Position = UDim2.new(0, 110, 0, 4)

    local srv = createCard(page, "Server", "Hop, rejoin, info.")
    createSlider(srv, "Hop Threshold", 1, 50, State.World.ServerHop.Threshold, function(v) State.World.ServerHop.Threshold = v end)
    local srvRow = createRow(srv, 38)
    createButton(srvRow, "Server Hop", "primary", serverHop).Position = UDim2.new(0, 0, 0, 4)
    createButton(srvRow, "Rejoin",     "secondary", rejoin).Position = UDim2.new(0, 110, 0, 4)
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 50),
        Font = Enum.Font.Code, TextSize = 11,
        TextColor3 = THEME.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = "PlaceId: " .. tostring(game.PlaceId) .. "\nJobId: " .. tostring(game.JobId)
            .. "\nPlayers: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers,
        Parent = srv,
    })
end

--[[ PAGE: COMBAT ]]
local function buildCombat()
    local page = makePage("COMBAT")
    sectionTitle(page, "Combat", "Desync and hitbox extender.")
    local dc = createCard(page, "Desync", "Visible position offset from server position.",
        State.Combat.Desync.Enabled, function(v)
            State.Combat.Desync.Enabled = v
            if v then startDesync() else stopDesync() end
        end)
    createDropdown(dc, "Method", {"NetworkOwner","VelocitySlam","FakeCharacter","Combined"},
        State.Combat.Desync.Method, function(v) State.Combat.Desync.Method = v end)
    createSlider(dc, "Offset", 0, 25, State.Combat.Desync.Offset, function(v) State.Combat.Desync.Offset = v end, nil, 1)
    createDropdown(dc, "Direction", {"Forward","Back","Left","Right","Up","Down"},
        State.Combat.Desync.Direction, function(v) State.Combat.Desync.Direction = v end)
    createKeybind(dc, "Trigger Key", State.Combat.Desync.Key, function(k) State.Combat.Desync.Key = k end)
    createToggle(dc, "Auto Engage on Enemy Aim", State.Combat.Desync.AutoEngage, function(v) State.Combat.Desync.AutoEngage = v end)
    createSlider(dc, "  Auto FOV", 1, 180, State.Combat.Desync.AutoEngageFOV, function(v) State.Combat.Desync.AutoEngageFOV = v end)
    createToggle(dc, "Ghost Indicator", State.Combat.Desync.GhostIndicator, function(v) State.Combat.Desync.GhostIndicator = v end)

    local hb = createCard(page, "Hitbox Extender", "Resizes target parts for easier hits.",
        State.Combat.Hitbox.Enabled, function(v)
            State.Combat.Hitbox.Enabled = v
            if v then startHitbox() else stopHitbox() end
        end)
    createSlider(hb, "Size", 1, 50, State.Combat.Hitbox.Size, function(v) State.Combat.Hitbox.Size = v end)
    createSlider(hb, "Transparency", 0, 1, State.Combat.Hitbox.Transparency, function(v) State.Combat.Hitbox.Transparency = v end, nil, 2)
    createColorPicker(hb, "Color", State.Combat.Hitbox.Color, function(c) State.Combat.Hitbox.Color = c end)
    createDropdown(hb, "Target Part", {"HumanoidRootPart","Head","UpperTorso","LowerTorso"},
        State.Combat.Hitbox.TargetPart, function(v) State.Combat.Hitbox.TargetPart = v end)
end

--[[ PAGE: SPOOF ]]
local function buildSpoof()
    local page = makePage("SPOOF")
    sectionTitle(page, "Spoof", "Permissions and anti-cheat bypass.")
    local pm = createCard(page, "Perms", "Spoof premium, gamepass, asset ownership and more.")
    createToggle(pm, "Premium",  State.Spoof.Premium.Enabled,  function(v) State.Spoof.Premium.Enabled = v end)
    createToggle(pm, "Gamepass", State.Spoof.Gamepass.Enabled, function(v) State.Spoof.Gamepass.Enabled = v end)
    createTextbox(pm, "  Whitelist (ids comma-sep)", State.Spoof.Gamepass.Whitelist, function(t) State.Spoof.Gamepass.Whitelist = t end, nil, "1234,5678")
    createToggle(pm, "Asset",    State.Spoof.Asset.Enabled,    function(v) State.Spoof.Asset.Enabled = v end)
    createToggle(pm, "Badge",    State.Spoof.Badge.Enabled,    function(v) State.Spoof.Badge.Enabled = v end)
    createToggle(pm, "Group",    State.Spoof.Group.Enabled,    function(v) State.Spoof.Group.Enabled = v end)
    createTextbox(pm, "  Group ID", tostring(State.Spoof.Group.GroupId), function(t) State.Spoof.Group.GroupId = tonumber(t) or 0 end, nil, "Group id")
    createSlider(pm, "  Rank", 0, 255, State.Spoof.Group.Rank, function(v) State.Spoof.Group.Rank = v end)
    createToggle(pm, "Policy",   State.Spoof.Policy.Enabled,   function(v) State.Spoof.Policy.Enabled = v end)
    createToggle(pm, "IsStudio", State.Spoof.IsStudio.Enabled, function(v) State.Spoof.IsStudio.Enabled = v end)
    createToggle(pm, "Owner",    State.Spoof.Owner.Enabled,    function(v) State.Spoof.Owner.Enabled = v end)

    local ac = createCard(page, "Anti-Cheat Bypass", "Returns spoofed values to AC reads.",
        State.Spoof.AntiCheat.Enabled, function(v) State.Spoof.AntiCheat.Enabled = v end)
    createSlider(ac, "Fake WalkSpeed", 0, 500, State.Spoof.AntiCheat.FakeWalkSpeed, function(v) State.Spoof.AntiCheat.FakeWalkSpeed = v end)
    createSlider(ac, "Fake JumpPower", 0, 500, State.Spoof.AntiCheat.FakeJumpPower, function(v) State.Spoof.AntiCheat.FakeJumpPower = v end)
    createMultilineTextbox(ac, "Namecall Blocklist", State.Spoof.AntiCheat.NamecallBlocklist, 70, function(t) State.Spoof.AntiCheat.NamecallBlocklist = t end, "One per line")
    createToggle(ac, "Anti Kick",   State.Spoof.AntiCheat.AntiKick, function(v) State.Spoof.AntiCheat.AntiKick = v end)
    createToggle(ac, "Anti TP Out", State.Spoof.AntiCheat.AntiTPOut, function(v) State.Spoof.AntiCheat.AntiTPOut = v end)
    createToggle(ac, "Hide AC GUI", State.Spoof.AntiCheat.HideACGui, function(v) State.Spoof.AntiCheat.HideACGui = v end)
    createButton(ac, "Restore Originals", "secondary", function()
        State.Spoof.AntiCheat.Enabled = false
        notify({ title = "Spoof", body = "AC hooks disabled" })
    end).Size = UDim2.new(1, 0, 0, 30)
end

--[[ PAGE: NETWORK ]]
local function buildNetwork()
    local page = makePage("NETWORK")
    sectionTitle(page, "Network", "Remote spy, quick fire, scanner.")
    local rs = createCard(page, "Mini Remote Spy", "Last 30 events. Color coded by method.",
        State.Network.RemoteSpy.Enabled, function(v) State.Network.RemoteSpy.Enabled = v end)
    local logFrame = new("ScrollingFrame", {
        BackgroundColor3 = THEME.ContentBg, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 180),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.AccentPrimary,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = rs,
    })
    corner(logFrame, 4)
    new("UIListLayout", { Padding = UDim.new(0, 2), Parent = logFrame })
    new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), Parent = logFrame })
    local btnRow = createRow(rs, 38)
    createButton(btnRow, "Pause", "secondary", function()
        State.Network.RemoteSpy.Paused = not State.Network.RemoteSpy.Paused
    end).Position = UDim2.new(0, 0, 0, 4)
    createButton(btnRow, "Clear", "secondary", function()
        for _, c in ipairs(logFrame:GetChildren()) do
            if c:IsA("TextLabel") then c:Destroy() end
        end
        RemoteLog = {}
    end).Position = UDim2.new(0, 110, 0, 4)
    createTextbox(rs, "Filter", State.Network.RemoteSpy.Filter, function(t) State.Network.RemoteSpy.Filter = t end, nil, "Match name")
    task.spawn(function()
        local lastSeen = 0
        while logFrame.Parent do
            task.wait(0.5)
            if State.Network.RemoteSpy.Enabled and not State.Network.RemoteSpy.Paused then
                for i = lastSeen + 1, #RemoteLog do
                    local e = RemoteLog[i]
                    local match = State.Network.RemoteSpy.Filter == "" or e.name:lower():find(State.Network.RemoteSpy.Filter:lower())
                    if match then
                        local color = e.method == "InvokeServer" and THEME.Warning or THEME.AccentPrimary
                        new("TextLabel", {
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, -12, 0, 16),
                            Font = Enum.Font.Code, TextSize = 11,
                            TextColor3 = color,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Text = "[" .. e.method .. "] " .. e.name,
                            Parent = logFrame,
                        })
                    end
                end
                lastSeen = #RemoteLog
            end
        end
    end)

    local qf = createCard(page, "Quick Fire", "Manually invoke a remote.")
    createTextbox(qf, "Path", State.Network.Quick.Path, function(t) State.Network.Quick.Path = t end, nil, "game.ReplicatedStorage.Foo")
    createMultilineTextbox(qf, "Args (Lua)", State.Network.Quick.Args, 80, function(t) State.Network.Quick.Args = t end, "return arg1, arg2")
    createButton(qf, "Fire", "primary", function()
        local path = State.Network.Quick.Path
        local argSrc = "return " .. (State.Network.Quick.Args or "")
        local ok, fn = pcall(loadstring or function() return nil end, argSrc)
        local args = {}
        if ok and fn then
            local ok2, r = pcall(fn)
            if ok2 then if type(r) == "table" then args = r else args = { r } end end
        end
        local node = game
        for seg in path:gmatch("[^%.]+") do
            if seg == "game" then node = game
            elseif node then node = node:FindFirstChild(seg) end
        end
        if node then
            if node:IsA("RemoteEvent") then pcall(function() node:FireServer(table.unpack(args)) end)
            elseif node:IsA("RemoteFunction") then pcall(function() node:InvokeServer(table.unpack(args)) end) end
            notify({ title = "Quick Fire", body = "Fired " .. node.Name })
        else notify({ title = "Quick Fire", body = "Path not found", accent = THEME.Danger }) end
    end).Size = UDim2.new(1, 0, 0, 30)

    local sc = createCard(page, "Mini Scanner", "All remotes in the game tree.")
    createTextbox(sc, "Search", State.Network.Scanner.Search, function(t) State.Network.Scanner.Search = t end, nil, "Name contains")
    local scList = new("ScrollingFrame", {
        BackgroundColor3 = THEME.ContentBg, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 180),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.AccentPrimary,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = sc,
    })
    corner(scList, 4)
    new("UIListLayout", { Padding = UDim.new(0, 2), Parent = scList })
    createButton(sc, "Scan", "primary", function()
        for _, c in ipairs(scList:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
        local q = State.Network.Scanner.Search:lower()
        local found = 0
        for _, d in ipairs(game:GetDescendants()) do
            if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and found < 200 then
                if q == "" or d.Name:lower():find(q) then
                    found = found + 1
                    local suspicious = d.Name:lower():find("kick") or d.Name:lower():find("ban") or d.Name:lower():find("admin")
                    new("TextLabel", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, -12, 0, 16),
                        Font = Enum.Font.Code, TextSize = 11,
                        TextColor3 = suspicious and THEME.Warning or THEME.TextSecondary,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Text = d.ClassName:sub(1, 3) .. " " .. d:GetFullName(),
                        Parent = scList,
                    })
                end
            end
        end
        notify({ title = "Scanner", body = found .. " remotes" })
    end).Size = UDim2.new(1, 0, 0, 30)
end
--[[ PAGE: PLAYER ]]
local function buildPlayer()
    local page = makePage("PLAYER")
    sectionTitle(page, "Player", "Chat spy and player list.")
    local cs = createCard(page, "Chat Spy", "Live message log.",
        State.Player.ChatSpy.Enabled, function(v)
            State.Player.ChatSpy.Enabled = v
            if v then startChatSpy() end
        end)
    createToggle(cs, "Show Whispers",  State.Player.ChatSpy.ShowWhispers,  function(v) State.Player.ChatSpy.ShowWhispers = v end)
    createToggle(cs, "Show Other Team", State.Player.ChatSpy.ShowOtherTeam, function(v) State.Player.ChatSpy.ShowOtherTeam = v end)
    createTextbox(cs, "Search", State.Player.ChatSpy.Search, function(t) State.Player.ChatSpy.Search = t end, nil, "filter text")
    createTextbox(cs, "Keyword Alerts", State.Player.ChatSpy.KeywordAlerts, function(t) State.Player.ChatSpy.KeywordAlerts = t end, nil, "comma sep")
    local chatList = new("ScrollingFrame", {
        BackgroundColor3 = THEME.ContentBg, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 200),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.AccentPrimary,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = cs,
    })
    corner(chatList, 4)
    new("UIListLayout", { Padding = UDim.new(0, 2), Parent = chatList })
    new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), Parent = chatList })
    task.spawn(function()
        local seen = 0
        while chatList.Parent do
            task.wait(0.5)
            if State.Player.ChatSpy.Enabled then
                for i = seen + 1, #ChatLog do
                    local e = ChatLog[i]
                    local q = State.Player.ChatSpy.Search:lower()
                    if q == "" or e.text:lower():find(q) or e.speaker:lower():find(q) then
                        new("TextLabel", {
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, -12, 0, 16),
                            Font = Enum.Font.Gotham, TextSize = 11,
                            TextColor3 = THEME.TextSecondary,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Text = "[" .. (e.channel or "?") .. "] " .. e.speaker .. ": " .. e.text,
                            Parent = chatList,
                        })
                    end
                end
                seen = #ChatLog
            end
        end
    end)

    local pl = createCard(page, "Player List", "Quick actions per player.")
    local listFrame = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 240),
        Parent = pl,
    })
    local scroll = new("ScrollingFrame", {
        BackgroundColor3 = THEME.ContentBg, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.AccentPrimary,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = listFrame,
    })
    corner(scroll, 4)
    new("UIListLayout", { Padding = UDim.new(0, 2), Parent = scroll })
    local function refreshList()
        for _, c in ipairs(scroll:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local row = new("Frame", {
                    BackgroundColor3 = THEME.CardBg, BorderSizePixel = 0,
                    Size = UDim2.new(1, -12, 0, 30),
                    Parent = scroll,
                })
                corner(row, 4)
                new("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 0),
                    Size = UDim2.new(0.4, 0, 1, 0),
                    Font = Enum.Font.Gotham, TextSize = 12,
                    TextColor3 = THEME.TextPrimary,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Text = p.Name .. " @" .. p.DisplayName,
                    Parent = row,
                })
                local spec = createButton(row, "Spec", "secondary", function()
                    if p.Character then Camera.CameraSubject = p.Character:FindFirstChildOfClass("Humanoid") end
                end)
                spec.Size = UDim2.new(0, 50, 0, 22)
                spec.Position = UDim2.new(1, -180, 0.5, -11)
                local tpb = createButton(row, "TP", "secondary", function() tpToPlayer(p) end)
                tpb.Size = UDim2.new(0, 50, 0, 22)
                tpb.Position = UDim2.new(1, -120, 0.5, -11)
                local pro = createButton(row, "Profile", "secondary", function()
                    setclipboard("https://roblox.com/users/" .. tostring(p.UserId) .. "/profile")
                    notify({ title = "Player", body = "Profile URL copied" })
                end)
                pro.Size = UDim2.new(0, 60, 0, 22)
                pro.Position = UDim2.new(1, -60, 0.5, -11)
            end
        end
    end
    refreshList()
    track(Players.PlayerAdded:Connect(refreshList))
    track(Players.PlayerRemoving:Connect(refreshList))
end

--[[ PAGE: MISC ]]
local function buildMisc()
    local page = makePage("MISC")
    sectionTitle(page, "Misc", "Anti-AFK, lighting, audio, extras.")
    local sys = createCard(page, "System", "Anti-AFK, FPS unlock, camera FOV.")
    createToggle(sys, "Anti-AFK", State.Misc.AntiAFK.Enabled, function(v)
        State.Misc.AntiAFK.Enabled = v
        if v then startAntiAFK() else stopAntiAFK() end
    end)
    createToggle(sys, "FPS Unlock", State.Misc.FPSUnlock.Enabled, function(v)
        State.Misc.FPSUnlock.Enabled = v
        pcall(setfpscap, v and State.Misc.FPSUnlock.Value or 60)
    end)
    createSlider(sys, "  FPS Cap", 30, 1000, State.Misc.FPSUnlock.Value, function(v)
        State.Misc.FPSUnlock.Value = v
        if State.Misc.FPSUnlock.Enabled then pcall(setfpscap, v) end
    end)
    createToggle(sys, "Custom FOV", State.Misc.FOV.Enabled, function(v)
        State.Misc.FOV.Enabled = v
        Camera.FieldOfView = v and State.Misc.FOV.Value or 70
    end)
    createSlider(sys, "  FOV", 30, 120, State.Misc.FOV.Value, function(v)
        State.Misc.FOV.Value = v
        if State.Misc.FOV.Enabled then Camera.FieldOfView = v end
    end)

    local lt = createCard(page, "Lighting", "Time of day, fog, shadows.")
    createToggle(lt, "Override Time", State.Misc.Time.Enabled, function(v)
        State.Misc.Time.Enabled = v
        if v then Lighting.ClockTime = State.Misc.Time.Value end
    end)
    createSlider(lt, "  Hour", 0, 24, State.Misc.Time.Value, function(v)
        State.Misc.Time.Value = v
        if State.Misc.Time.Enabled then Lighting.ClockTime = v end
    end, nil, 1)
    createToggle(lt, "Freeze Time", State.Misc.FreezeTime.Enabled, function(v) State.Misc.FreezeTime.Enabled = v end)
    createToggle(lt, "Fullbright", State.Misc.Fullbright.Enabled, function(v)
        State.Misc.Fullbright.Enabled = v
        if v then applyFullbright() else restoreLighting() end
    end)
    createToggle(lt, "No Fog", State.Misc.NoFog.Enabled, function(v)
        State.Misc.NoFog.Enabled = v
        if v then Lighting.FogEnd = 100000; Lighting.FogStart = 100000 end
    end)
    createToggle(lt, "No Shadows", State.Misc.NoShadows.Enabled, function(v)
        State.Misc.NoShadows.Enabled = v
        Lighting.GlobalShadows = not v
    end)
    createDropdown(lt, "Sky Preset", {"Default","Night","Sunset","Space","Storm"},
        State.Misc.SkyPreset, function(v) State.Misc.SkyPreset = v end)

    local au = createCard(page, "Audio", "Master volume, custom music.")
    createToggle(au, "Override Volume", State.Misc.Volume.Enabled, function(v) State.Misc.Volume.Enabled = v end)
    createSlider(au, "  Volume", 0, 5, State.Misc.Volume.Value, function(v) State.Misc.Volume.Value = v end, nil, 2)
    createTextbox(au, "Music URL", State.Misc.Music.Url, function(t) State.Misc.Music.Url = t end, nil, "rbxassetid://123")
    local mr = createRow(au, 38)
    createButton(mr, "Play", "primary", function() playMusic(State.Misc.Music.Url); State.Misc.Music.Playing = true end).Position = UDim2.new(0, 0, 0, 4)
    createButton(mr, "Stop", "secondary", function() stopMusic(); State.Misc.Music.Playing = false end).Position = UDim2.new(0, 110, 0, 4)

    local vx = createCard(page, "Visual Extras", "Crosshair, hitmarker, recoil, sprint.")
    createToggle(vx, "Crosshair", State.Misc.Crosshair.Enabled, function(v) State.Misc.Crosshair.Enabled = v end)
    createSlider(vx, "  Size", 4, 60, State.Misc.Crosshair.Size, function(v) State.Misc.Crosshair.Size = v end)
    createColorPicker(vx, "  Color", State.Misc.Crosshair.Color, function(c) State.Misc.Crosshair.Color = c end)
    createToggle(vx, "Hit Marker", State.Misc.HitMarker.Enabled, function(v) State.Misc.HitMarker.Enabled = v end)
    createToggle(vx, "No Recoil",  State.Misc.NoRecoil.Enabled, function(v) State.Misc.NoRecoil.Enabled = v end)
    createToggle(vx, "No Sprint Cooldown", State.Misc.NoSprintCooldown.Enabled, function(v) State.Misc.NoSprintCooldown.Enabled = v end)
end

--[[ PAGE: CONFIGS ]]
local function buildConfigs()
    local page = makePage("CONFIGS")
    sectionTitle(page, "Configs", "Theme, keybinds, save/load.")
    local th = createCard(page, "Theme", "Preset accent + custom override.")
    createDropdown(th, "Preset", {"Magenta","Cyan","Green","Crimson","Amber"},
        State.Configs.Theme, function(v)
            State.Configs.Theme = v
            local map = {
                Magenta = Color3.fromRGB(255, 65, 180),
                Cyan    = Color3.fromRGB(80, 200, 255),
                Green   = Color3.fromRGB(80, 220, 130),
                Crimson = Color3.fromRGB(220, 60, 80),
                Amber   = Color3.fromRGB(255, 180, 50),
            }
            THEME.AccentPrimary = map[v] or THEME.AccentPrimary
            notify({ title = "Theme", body = "Applied " .. v })
        end)
    createColorPicker(th, "Custom Accent", {255, 65, 180}, function(c) THEME.AccentPrimary = colorOf(c) end)
    createSlider(th, "Background Opacity", 0, 1, State.Configs.BgOpacity, function(v)
        State.Configs.BgOpacity = v
        Window.BackgroundTransparency = 1 - v
    end, nil, 2)
    createSlider(th, "Window Scale", 0.6, 1.4, State.Configs.Scale, function(v)
        State.Configs.Scale = v
    end, nil, 2)

    local kb = createCard(page, "Keybinds", "Master keybind list.")
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 90),
        Font = Enum.Font.Code, TextSize = 12,
        TextColor3 = THEME.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = "Toggle Hub: " .. tostring(State.Master.ToggleKey)
            .. "\nAimbot: " .. tostring(State.Aim.Aimbot.Key)
            .. "\nFly: " .. tostring(State.Movement.Fly.ToggleKey)
            .. "\nTP Forward: " .. tostring(State.Movement.TPForward.Key)
            .. "\nPanic Reset: " .. tostring(State.Movement.PanicKey)
            .. "\nDesync: " .. tostring(State.Combat.Desync.Key),
        Parent = kb,
    })

    local sl = createCard(page, "Save / Load", "Per-name config slots.")
    local slotName = createTextbox(sl, "Slot name", State.Configs.CurrentSlot, function(t) State.Configs.CurrentSlot = t end, nil, "default / pvp / building")
    local opts = listConfigSlots()
    if #opts == 0 then opts = { "(none)" } end
    local selected = opts[1]
    local slotDD = createDropdown(sl, "Saved slots", opts, selected, function(v) selected = v end)
    local row = createRow(sl, 38)
    createButton(row, "Save", "primary", function()
        saveConfig(State.Configs.CurrentSlot)
        notify({ title = "Config", body = "Saved " .. State.Configs.CurrentSlot })
        local updated = listConfigSlots()
        slotDD.SetOptions(updated)
    end).Position = UDim2.new(0, 0, 0, 4)
    createButton(row, "Load", "secondary", function()
        if loadConfig(selected) then
            notify({ title = "Config", body = "Loaded " .. selected })
        else
            notify({ title = "Config", body = "Slot missing", accent = THEME.Danger })
        end
    end).Position = UDim2.new(0, 110, 0, 4)
    createButton(row, "Delete", "danger", function()
        pcall(function()
            local p = CONFIG_FOLDER .. "/" .. selected .. ".json"
            if isfile(p) then writefile(p, "") end
        end)
        notify({ title = "Config", body = "Deleted " .. selected })
    end).Position = UDim2.new(0, 220, 0, 4)
    createToggle(sl, "Auto Save on close", State.Configs.AutoSave, function(v) State.Configs.AutoSave = v end)
    createButton(sl, "Export to Clipboard", "secondary", function()
        local ok, j = pcall(function() return HttpService:JSONEncode(State) end)
        if ok then setclipboard(j); notify({ title = "Config", body = "Copied to clipboard" }) end
    end).Size = UDim2.new(1, 0, 0, 30)
    createMultilineTextbox(sl, "Import JSON", "", 80, function(t)
        local ok, data = pcall(function() return HttpService:JSONDecode(t) end)
        if ok and type(data) == "table" then
            local function merge(dst, src)
                for k, v in pairs(src) do
                    if type(v) == "table" and type(dst[k]) == "table" then merge(dst[k], v)
                    else dst[k] = v end
                end
            end
            merge(State, data)
            notify({ title = "Config", body = "Imported JSON" })
        end
    end)

    local ab = createCard(page, "About", "Build info.")
    new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 80),
        Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = THEME.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Text = "FREEZER v4.0.0\nModules: 11 (single-file monolithic)\nExecutor: " .. EXECUTOR_NAME
            .. "\nCredits: by ENI for LO",
        Parent = ab,
    })

    local rs = createCard(page, "Reset", "Restore defaults.")
    local resetState = 0
    local resetBtn
    resetBtn = createButton(rs, "Reset to defaults (click twice)", "danger", function()
        if resetState == 0 then
            resetState = 1
            resetBtn.Text = "Click again to confirm"
            task.delay(3, function()
                if resetBtn and resetBtn.Parent then
                    resetState = 0
                    resetBtn.Text = "Reset to defaults (click twice)"
                end
            end)
        else
            State = deepCopy(DefaultState)
            for i = 1, 10 do State.World.Slots[i] = nil end
            notify({ title = "Config", body = "Reset to defaults" })
            resetState = 0
            resetBtn.Text = "Reset to defaults (click twice)"
        end
    end)
    resetBtn.Size = UDim2.new(1, 0, 0, 30)
end

--[[ BUILD ALL PAGES ]]
buildHome()
buildAim()
buildVisual()
buildMovement()
buildWorld()
buildCombat()
buildSpoof()
buildNetwork()
buildPlayer()
buildMisc()
buildConfigs()

selectPage("HOME")

--[[ STATUS BAR UPDATER ]]
task.spawn(function()
    while statusText.Parent do
        local fps = 0
        pcall(function() fps = math.floor(1 / RunService.RenderStepped:Wait()) end)
        local ping = 0
        pcall(function()
            ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
        end)
        local nm = "Unknown"
        pcall(function() nm = MarketplaceService:GetProductInfo(game.PlaceId).Name end)
        local t = os.date("%H:%M")
        statusText.Text = string.format("FPS %d / Ping %dms / %d players / %s / %s",
            fps, ping, #Players:GetPlayers(), nm, t)
        task.wait(0.5)
    end
end)

--[[ MASTER KEYBINDS ]]
track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local name = input.KeyCode.Name
    if name == State.Master.ToggleKey then
        HubGui.Enabled = not HubGui.Enabled
    end
    if name == State.Movement.PanicKey then panicReset() end
    if name == State.Movement.TPForward.Key and State.Movement.TPForward.Enabled then tpForward() end
    if name == State.Movement.SpeedBurst.Key and State.Movement.SpeedBurst.Enabled then speedBurst() end
    if name == State.Movement.Fly.ToggleKey then
        State.Movement.Fly.Enabled = not State.Movement.Fly.Enabled
        if State.Movement.Fly.Enabled then startFly() else stopFly() end
    end
    if name == State.World.TPNearestKey then tpToNearest() end
    if name == State.World.TPRandomKey then tpToRandom() end
end))

--[[ EXPOSE GLOBAL API ]]
local api = {
    Version = "4.0.0",
    State = State,
    Notify = notify,
    Toggle = function() HubGui.Enabled = not HubGui.Enabled end,
    Save = saveConfig,
    Load = loadConfig,
    Unload = function()
        for _, c in ipairs(_connections) do pcall(function() c:Disconnect() end) end
        _connections = {}
        stopAimbot(); stopTriggerBot(); stopESP(); stopFly(); stopNoclip()
        stopInfJump(); stopSpinbot(); stopAntiFling(); stopAntiVoid()
        stopDesync(); stopHitbox(); stopAntiAFK(); stopMusic(); restoreLighting()
        HubGui:Destroy(); NotifyGui:Destroy()
    end,
}
pcall(function() getgenv().FREEZER = api end)

--[[ KICK OFF: splash, then reveal hub ]]
loadConfig("default")
showSplash(function()
    HubGui.Enabled = true
    notify({ title = "FREEZER", body = "All engines armed. Press " .. tostring(State.Master.ToggleKey) .. " to hide.", accent = THEME.Success })
end)