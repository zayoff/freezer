--[[
    FREEZER v5.0.0  ::  Safe-init build
    Single-file Roblox executor menu, by ENI for LO

    Design principle: ZERO global hooks installed at load. Hooks for Silent Aim
    and Anti-Cheat are installed LAZILY when the user enables those features
    and gated by a state flag, so if anything ever crashes the game stays
    fully playable.
]]

--[[ EXPLOIT FN RESOLUTION ]]
local function safeGet(name)
    local ok, val
    ok, val = pcall(function() return getgenv and getgenv()[name] end)
    if ok and val then return val end
    ok, val = pcall(function() return getfenv(0)[name] end)
    if ok and val then return val end
    ok, val = pcall(function() return _G[name] end)
    if ok and val then return val end
    return nil
end

local cloneref         = safeGet("cloneref")         or function(o) return o end
local _gethui          = safeGet("gethui")
local hookmetamethod   = safeGet("hookmetamethod")
local getrawmetatable  = safeGet("getrawmetatable")
local setreadonly      = safeGet("setreadonly")      or function() end
local newcclosure      = safeGet("newcclosure")      or function(f) return f end
local checkcaller      = safeGet("checkcaller")      or function() return false end
local getnamecallmethod= safeGet("getnamecallmethod")
local setfpscap        = safeGet("setfpscap")
local writefile        = safeGet("writefile")
local readfile         = safeGet("readfile")
local isfile           = safeGet("isfile")           or function() return false end
local makefolder       = safeGet("makefolder")
local Drawing          = safeGet("Drawing")
local identifyexecutor = safeGet("identifyexecutor") or function() return "Unknown" end

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

--[[ STATE — all features OFF by default ]]
local S = {
    Master = { Enabled = false, ToggleKey = "RightControl" },
    Aimbot = {
        Enabled = false, FOV = 120, Smooth = 0.2,
        TargetPart = "Head", TeamCheck = false, WallCheck = true,
        ShowFovCircle = false,
    },
    SilentAim = {
        Enabled = false, FOV = 200, TargetPart = "Head",
        HitChance = 100, TeamCheck = false, WallCheck = false,
    },
    TriggerBot = { Enabled = false, Delay = 0.05 },
    ESP = {
        Master = false, Box = true, Name = true, Health = true,
        Distance = true, Tracer = false, Chams = false,
        TeamCheck = false, MaxDistance = 1000,
        ColorEnemy = Color3.fromRGB(255, 65, 180),
        ColorTeam  = Color3.fromRGB(80, 220, 130),
    },
    Movement = {
        WalkSpeed = 16, JumpPower = 50, Gravity = 196,
        Fly = false, FlySpeed = 50,
        Noclip = false, InfJump = false,
    },
    Misc = {
        AntiAFK = false, FPSCap = 60, CamFOV = 70,
        Fullbright = false, NoFog = false,
    },
    Theme = { Accent = C.Accent },
}

--[[ CONFIG SAVE / LOAD ]]
local CFG_PATH = "FREEZER/config.json"
pcall(function() if makefolder then makefolder("FREEZER") end end)

local function saveConfig()
    if not writefile then return end
    local plain = {
        Master = S.Master, Aimbot = S.Aimbot, SilentAim = S.SilentAim,
        TriggerBot = S.TriggerBot, ESP = {
            Master = S.ESP.Master, Box = S.ESP.Box, Name = S.ESP.Name,
            Health = S.ESP.Health, Distance = S.ESP.Distance,
            Tracer = S.ESP.Tracer, Chams = S.ESP.Chams,
            TeamCheck = S.ESP.TeamCheck, MaxDistance = S.ESP.MaxDistance,
        },
        Movement = S.Movement, Misc = S.Misc,
    }
    pcall(function() writefile(CFG_PATH, HttpService:JSONEncode(plain)) end)
end

local function loadConfig()
    if not readfile or not isfile(CFG_PATH) then return end
    pcall(function()
        local raw = readfile(CFG_PATH)
        local t = HttpService:JSONDecode(raw)
        for k, v in pairs(t or {}) do
            if S[k] then
                for k2, v2 in pairs(v) do S[k][k2] = v2 end
            end
        end
    end)
end

--[[ CONNECTION TRACKER ]]
local _connections = {}
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

--[[ SPLASH — minimal 2s fade, can never block ]]
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
            BackgroundTransparency = 1, Text = "v5.0.0  ::  " .. EXEC,
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
    btn.MouseButton1Click:Connect(function()
        if open and list then list:Destroy(); list = nil; open = false; return end
        open = true
        list = new("Frame", {
            BackgroundColor3 = C.Content, BorderSizePixel = 0,
            Position = UDim2.fromOffset(btn.AbsolutePosition.X, btn.AbsolutePosition.Y + 30),
            Size = UDim2.new(0, 140, 0, math.min(#options, 6) * 26),
            Parent = NotifyGui,
        })
        corner(list, 4); stroke(list, C.Border, 1)
        local ll = listLayout(list, 0)
        for _, opt in ipairs(options) do
            local item = new("TextButton", {
                BackgroundColor3 = C.Content,
                BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 26),
                Text = "  " .. tostring(opt), Font = Enum.Font.Gotham, TextSize = 12,
                TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false, Parent = list,
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
    end)
    return { Get = function() return val end, Set = function(v) val = v; btn.Text = "  " .. tostring(v) .. "  v" end }
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
            end
        end)
    end)
    return { Get = function() return key end, Set = function(v) key = v; btn.Text = v end }
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
-- Logo
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

-- Make window draggable by title bar
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

--[[ ENGINES (all stop/start safely) ]]

-- Resolve characters helper
local function getChar(plr) return plr and plr.Character end
local function getHum(plr)
    local ch = getChar(plr); return ch and ch:FindFirstChildOfClass("Humanoid")
end
local function getHRP(plr)
    local ch = getChar(plr); return ch and ch:FindFirstChild("HumanoidRootPart")
end

-- Find best target by FOV/distance
local function findTarget(maxFovPx, partName, teamCheck, wallCheck)
    local cam = GetCamera()
    if not cam then return nil end
    local mousePos = UserInputService:GetMouseLocation()
    local best, bestDist = nil, maxFovPx
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local hum = getHum(plr)
            if hum and hum.Health > 0 then
                if teamCheck and plr.Team and plr.Team == LP.Team then
                    -- skip teammates
                else
                    local ch = plr.Character
                    local part = ch and ch:FindFirstChild(partName)
                    if part then
                        local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
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
                                        best, bestDist = { plr = plr, part = part }, dist
                                    end
                                else
                                    best, bestDist = { plr = plr, part = part }, dist
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

-- Aimbot
local aimbotConn = nil
local fovCircle = nil
local function startAimbot()
    if aimbotConn then return end
    aimbotConn = RunService.RenderStepped:Connect(function()
        if not S.Master.Enabled or not S.Aimbot.Enabled then return end
        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
        local t = findTarget(S.Aimbot.FOV, S.Aimbot.TargetPart, S.Aimbot.TeamCheck, S.Aimbot.WallCheck)
        if t and t.part then
            local cam = GetCamera()
            local goal = CFrame.new(cam.CFrame.Position, t.part.Position)
            cam.CFrame = cam.CFrame:Lerp(goal, math.clamp(1 - S.Aimbot.Smooth, 0.05, 1))
        end
    end)
end
local function stopAimbot()
    if aimbotConn then aimbotConn:Disconnect(); aimbotConn = nil end
end

-- ESP
local espItems = {}
local espConn = nil
local function clearOneESP(plr)
    local it = espItems[plr]
    if not it then return end
    if it.high then pcall(function() it.high:Destroy() end) end
    if it.bb then pcall(function() it.bb:Destroy() end) end
    espItems[plr] = nil
end
local function ensureESP(plr)
    if espItems[plr] then return espItems[plr] end
    espItems[plr] = {}
    return espItems[plr]
end
local function startESP()
    if espConn then return end
    espConn = RunService.Heartbeat:Connect(function()
        local cam = GetCamera()
        if not cam then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LP then continue end
            local ch = plr.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local it = ensureESP(plr)
            if not S.ESP.Master or not hrp or not hum or hum.Health <= 0 then
                clearOneESP(plr); continue
            end
            local dist = (hrp.Position - cam.CFrame.Position).Magnitude
            if dist > S.ESP.MaxDistance then clearOneESP(plr); continue end
            local sameTeam = (plr.Team and plr.Team == LP.Team)
            if S.ESP.TeamCheck and sameTeam then clearOneESP(plr); continue end
            local color = sameTeam and S.ESP.ColorTeam or S.ESP.ColorEnemy
            -- Chams via Highlight
            if S.ESP.Chams then
                if not it.high then
                    it.high = new("Highlight", {
                        FillColor = color, OutlineColor = color,
                        FillTransparency = 0.6, OutlineTransparency = 0,
                        Parent = ch,
                    })
                else
                    it.high.FillColor = color; it.high.OutlineColor = color
                end
            elseif it.high then it.high:Destroy(); it.high = nil end
            -- Name / health / distance BillboardGui
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
                    it.lblInfo = new("TextLabel", {
                        BackgroundTransparency = 1, Text = "",
                        Font = Enum.Font.Code, TextSize = 12,
                        TextColor3 = color, TextStrokeTransparency = 0.5,
                        Position = UDim2.new(0, 0, 0, 18),
                        Size = UDim2.new(1, 0, 0, 16), Parent = it.bb,
                    })
                end
                local parts = {}
                if S.ESP.Name then table.insert(parts, plr.Name) end
                if S.ESP.Health then table.insert(parts, string.format("HP %d", math.floor(hum.Health))) end
                if S.ESP.Distance then table.insert(parts, string.format("%dm", math.floor(dist))) end
                it.lblName.Text = plr.Name
                it.lblName.TextColor3 = color
                it.lblInfo.Text = table.concat(parts, "  /  ", 2)
                it.lblInfo.TextColor3 = color
            elseif it.bb then it.bb:Destroy(); it.bb = nil end
        end
    end)
end
local function stopESP()
    if espConn then espConn:Disconnect(); espConn = nil end
    for plr in pairs(espItems) do clearOneESP(plr) end
end
track(Players.PlayerRemoving:Connect(clearOneESP))

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
local function startFly()
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
local function stopFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
end

-- Noclip
local noclipConn
local function startNoclip()
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
local function stopNoclip()
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
end

-- Inf Jump
local infJumpConn
local function startInfJump()
    if infJumpConn then return end
    infJumpConn = UserInputService.JumpRequest:Connect(function()
        if not S.Movement.InfJump then return end
        local hum = getHum(LP)
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end
local function stopInfJump()
    if infJumpConn then infJumpConn:Disconnect(); infJumpConn = nil end
end

-- Anti-AFK
local afkConn
local function startAntiAFK()
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
local function stopAntiAFK()
    if afkConn then afkConn:Disconnect(); afkConn = nil end
end

-- Fullbright
local origLight = {}
local function startFullbright()
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
local function stopFullbright()
    if not origLight.set then return end
    pcall(function() Lighting.Brightness = origLight.Brightness end)
    pcall(function() Lighting.ClockTime = origLight.ClockTime end)
    pcall(function() Lighting.FogEnd = origLight.FogEnd end)
    pcall(function() Lighting.OutdoorAmbient = origLight.OutdoorAmbient end)
    pcall(function() Lighting.GlobalShadows = origLight.GlobalShadows end)
    origLight = {}
end

-- Silent Aim LAZY hook
local silentHookInstalled = false
local autoDetectedRemote = nil
local lastClickTime = 0
track(UserInputService.InputBegan:Connect(function(input, gpe)
    if not gpe and input.UserInputType == Enum.UserInputType.MouseButton1 then
        lastClickTime = tick()
    end
end))

local function installSilentAimHook()
    if silentHookInstalled then return true end
    if not hookmetamethod or not getrawmetatable or not getnamecallmethod then
        notify("Silent Aim", "Missing exploit fn (hookmetamethod / getrawmetatable / getnamecallmethod)", C.Danger, 6)
        return false
    end
    local ok = pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        local oldNamecall = mt.__namecall
        mt.__namecall = newcclosure(function(self, ...)
            if checkcaller() then return oldNamecall(self, ...) end
            if not S.SilentAim.Enabled then return oldNamecall(self, ...) end
            if typeof(self) ~= "Instance" then return oldNamecall(self, ...) end
            local args = table.pack(...)
            local override
            pcall(function()
                local method = getnamecallmethod()
                if method ~= "FireServer" and method ~= "InvokeServer" then return end
                local t = findTarget(S.SilentAim.FOV, S.SilentAim.TargetPart, S.SilentAim.TeamCheck, S.SilentAim.WallCheck)
                if not t or not t.part then return end
                if math.random(1, 100) > S.SilentAim.HitChance then return end
                local hitPos = t.part.Position
                for i = 1, args.n do
                    local a = args[i]
                    if typeof(a) == "Vector3" then
                        args[i] = hitPos
                        override = { oldNamecall(self, table.unpack(args, 1, args.n)) }
                        return
                    elseif typeof(a) == "CFrame" then
                        args[i] = CFrame.new(hitPos)
                        override = { oldNamecall(self, table.unpack(args, 1, args.n)) }
                        return
                    end
                end
            end)
            if override then return table.unpack(override) end
            return oldNamecall(self, ...)
        end)
        silentHookInstalled = true
    end)
    if not ok then
        notify("Silent Aim", "Hook install failed", C.Danger)
        return false
    end
    return true
end

--[[ BUILD PAGES ]]

-- HOME
do
    addNav("Home", "[H]")
    local p = addPage("Home")
    local c1 = Controls.Card(p, "Master", "Global kill switch.")
    Controls.Toggle(c1, "FREEZER enabled", S.Master.Enabled, function(v) S.Master.Enabled = v end)
    Controls.Keybind(c1, "Toggle hub key", S.Master.ToggleKey, function(k) S.Master.ToggleKey = k end)
    local c2 = Controls.Card(p, "Session", "Live status.")
    local lblGame = new("TextLabel", {
        BackgroundTransparency = 1, Text = "", LayoutOrder = 99,
        Font = Enum.Font.Gotham, TextSize = 12,
        TextColor3 = C.TextSecondary, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 80), Parent = c2,
    })
    task.spawn(function()
        while true do
            local players = #Players:GetPlayers()
            local exec = EXEC
            local pid = game.PlaceId
            lblGame.Text = string.format("Place: %d\nPlayers: %d\nExecutor: %s", pid, players, exec)
            task.wait(2)
        end
    end)
end

-- AIM
do
    addNav("Aim", "[A]")
    local p = addPage("Aim")
    local cA = Controls.Card(p, "Aimbot", "Camera-snap aimbot. Hold Mouse2 to aim.")
    Controls.Toggle(cA, "Enabled", S.Aimbot.Enabled, function(v)
        S.Aimbot.Enabled = v
        if v then startAimbot() else stopAimbot() end
    end)
    Controls.Slider(cA, "FOV (pixels)", 10, 500, S.Aimbot.FOV, 0, function(v) S.Aimbot.FOV = v end)
    Controls.Slider(cA, "Smoothing", 0, 1, S.Aimbot.Smooth, 2, function(v) S.Aimbot.Smooth = v end)
    Controls.Dropdown(cA, "Target part", { "Head", "HumanoidRootPart", "UpperTorso", "Torso" }, S.Aimbot.TargetPart, function(v) S.Aimbot.TargetPart = v end)
    Controls.Toggle(cA, "Wall check", S.Aimbot.WallCheck, function(v) S.Aimbot.WallCheck = v end)
    Controls.Toggle(cA, "Team check", S.Aimbot.TeamCheck, function(v) S.Aimbot.TeamCheck = v end)

    local cS = Controls.Card(p, "Silent Aim", "Hooks __namecall on first enable; never installed if you leave it off.")
    Controls.Toggle(cS, "Enabled", S.SilentAim.Enabled, function(v)
        if v then
            if not installSilentAimHook() then return end
            notify("Silent Aim", "Hook armed", C.Success, 3)
        end
        S.SilentAim.Enabled = v
    end)
    Controls.Slider(cS, "FOV (pixels)", 10, 1000, S.SilentAim.FOV, 0, function(v) S.SilentAim.FOV = v end)
    Controls.Dropdown(cS, "Target part", { "Head", "HumanoidRootPart", "UpperTorso", "Torso" }, S.SilentAim.TargetPart, function(v) S.SilentAim.TargetPart = v end)
    Controls.Slider(cS, "Hit chance %", 0, 100, S.SilentAim.HitChance, 0, function(v) S.SilentAim.HitChance = v end)
    Controls.Toggle(cS, "Wall check", S.SilentAim.WallCheck, function(v) S.SilentAim.WallCheck = v end)
    Controls.Toggle(cS, "Team check", S.SilentAim.TeamCheck, function(v) S.SilentAim.TeamCheck = v end)
end

-- VISUAL
do
    addNav("Visual", "[V]")
    local p = addPage("Visual")
    local cE = Controls.Card(p, "ESP", "Player highlights / labels.")
    Controls.Toggle(cE, "Master ESP", S.ESP.Master, function(v)
        S.ESP.Master = v
        if v then startESP() else stopESP() end
    end)
    Controls.Toggle(cE, "Chams (Highlight)", S.ESP.Chams, function(v) S.ESP.Chams = v end)
    Controls.Toggle(cE, "Name tag", S.ESP.Name, function(v) S.ESP.Name = v end)
    Controls.Toggle(cE, "Health", S.ESP.Health, function(v) S.ESP.Health = v end)
    Controls.Toggle(cE, "Distance", S.ESP.Distance, function(v) S.ESP.Distance = v end)
    Controls.Toggle(cE, "Team check (skip)", S.ESP.TeamCheck, function(v) S.ESP.TeamCheck = v end)
    Controls.Slider(cE, "Max distance", 50, 5000, S.ESP.MaxDistance, 0, function(v) S.ESP.MaxDistance = v end)
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
        if v then startFly() else stopFly() end
    end)
    Controls.Slider(c2, "Fly speed", 10, 300, S.Movement.FlySpeed, 0, function(v) S.Movement.FlySpeed = v end)
    Controls.Toggle(c2, "Noclip", S.Movement.Noclip, function(v)
        S.Movement.Noclip = v
        if v then startNoclip() else stopNoclip() end
    end)
    Controls.Toggle(c2, "Infinite jump", S.Movement.InfJump, function(v)
        S.Movement.InfJump = v
        if v then startInfJump() else stopInfJump() end
    end)
end

-- MISC
do
    addNav("Misc", "[X]")
    local p = addPage("Misc")
    local c1 = Controls.Card(p, "Quality of life", "")
    Controls.Toggle(c1, "Anti-AFK", S.Misc.AntiAFK, function(v)
        S.Misc.AntiAFK = v
        if v then startAntiAFK() else stopAntiAFK() end
    end)
    Controls.Toggle(c1, "Fullbright", S.Misc.Fullbright, function(v)
        S.Misc.Fullbright = v
        if v then startFullbright() else stopFullbright() end
    end)
    Controls.Slider(c1, "FPS cap", 30, 1000, S.Misc.FPSCap, 0, function(v)
        S.Misc.FPSCap = v
        if setfpscap then pcall(setfpscap, v) end
    end)
    Controls.Slider(c1, "Camera FOV", 30, 120, S.Misc.CamFOV, 0, function(v)
        S.Misc.CamFOV = v
        local cam = GetCamera()
        if cam then pcall(function() cam.FieldOfView = v end) end
    end)
end

-- CONFIGS
do
    addNav("Configs", "[C]")
    local p = addPage("Configs")
    local c1 = Controls.Card(p, "Storage", "Manual save / restore.")
    Controls.Button(c1, "Save now", "primary", function() saveConfig(); notify("Config", "Saved.", C.Success) end)
    Controls.Button(c1, "Reload from disk", "secondary", function() loadConfig(); notify("Config", "Reloaded.", C.Success) end)
    local c2 = Controls.Card(p, "About", "FREEZER v5.0.0 — safe-init build, hooks lazy, all defaults off.")
end

-- Default page
showPage("Home")

--[[ MASTER KEYBIND (toggle hub visibility) ]]
track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode.Name == S.Master.ToggleKey then
            HubGui.Enabled = not HubGui.Enabled
        end
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

--[[ EXPOSE API + INIT ]]
local API = {
    Version = "5.0.0",
    State = S,
    Notify = notify,
    Show = function() HubGui.Enabled = true end,
    Hide = function() HubGui.Enabled = false end,
    Toggle = function() HubGui.Enabled = not HubGui.Enabled end,
    Save = saveConfig,
    Load = loadConfig,
    Destroy = function()
        clearConnections()
        stopAimbot(); stopESP(); stopFly(); stopNoclip(); stopInfJump()
        stopAntiAFK(); stopFullbright()
        pcall(function() HubGui:Destroy() end)
        pcall(function() NotifyGui:Destroy() end)
    end,
}
pcall(function() getgenv().FREEZER = API end)

loadConfig()
showSplash(function()
    HubGui.Enabled = true
    notify("FREEZER", "Ready. Press " .. S.Master.ToggleKey .. " to hide.", C.Success, 4)
end)

return API
