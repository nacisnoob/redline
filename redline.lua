local Library = (function()

--[[

    Redline UI Library - a smoked-glass interface with signal-red accents

    Features: Redline glass styling, live-switchable themes, draggable window, optional logo

    (Roblox decal / image ID), tabs, sections, labels, buttons, toggles, sliders, dropdowns,

    textboxes, keybinds, notifications, toggle hotkey, touch support, optional screen blur.

    Usage:

        local Library = loadstring(readfile("UILib.lua"))()

        local Window = Library:CreateWindow({

            Title = "My Hub",

            Theme = "Redline",          -- Redline, Glass, Ocean, Rose, Emerald, Sunset, Midnight, Light

            Logo = 123456789,           -- decal ID, image ID, "rbxassetid://..." or getcustomasset path

            LogoCircle = true,

            ToggleKey = Enum.KeyCode.RightShift,

        })

        local Tab = Window:CreateTab("Settings")

        Tab:AddThemeSettings()          -- preset dropdown + transparency + accent hue + copy code

    Theme API:

        Library:SetTheme("Rose")                        -- switch to a preset (applies instantly)

        Library:SetTheme({ Accent = Color3.fromRGB(255, 80, 80) })  -- tweak individual colors

        Library:AddTheme("Mine", { Glass = ..., Accent = ..., Accent2 = ... })  -- register your own

        Library:GetThemeNames()                          -- list of preset names

        Library:ExportTheme()                            -- current theme as Lua code (string)

        Library:OnThemeChanged(function(name, theme) end)

]]

local WHITE = Color3.new(1, 1, 1)

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
-- Every theme starts from this base and overrides what it needs.
local BASE_THEME = {

    Glass         = rgb(23, 15, 20), -- deep smoked-wine glass

    GlassTransp   = 0.22, -- translucent, but still readable

    Frost         = rgb(255, 236, 238), -- warm overlay tint

    ElementTransp = 0.91,

    HoverTransp   = 0.82,

    Accent        = rgb(255, 62, 78), -- Redline signal red

    Accent2       = rgb(255, 150, 94), -- hot-coral highlight

    Text          = rgb(250, 246, 247),

    SubText       = rgb(174, 157, 164),

    Border        = rgb(255, 108, 119), -- restrained warm outline

    BorderTransp  = 0.78,

    Input         = rgb(10, 8, 12), -- textbox / keybind fill

    InputTransp   = 0.42,

    Sheen         = rgb(255, 226, 228), -- soft glass highlight

    GlowTransp    = 0.82, -- soft accent bloom

}

local Library = {

    Theme = {},

    Themes = {

        Glass    = {
            Glass = rgb(20, 22, 36), GlassTransp = 0.2,
            Frost = WHITE, ElementTransp = 0.93, HoverTransp = 0.87,
            Accent = rgb(125, 120, 255), Accent2 = rgb(70, 200, 255),
            Text = rgb(242, 244, 252), SubText = rgb(165, 170, 195),
            Border = WHITE, BorderTransp = 0.88,
            Input = Color3.new(0, 0, 0), InputTransp = 0.6,
            Sheen = WHITE, GlowTransp = 0.86,
        },

        Redline  = {
            Glass = rgb(16, 17, 23), GlassTransp = 0.12,
            Frost = rgb(244, 245, 250), ElementTransp = 0.94, HoverTransp = 0.86,
            Accent = rgb(255, 62, 86), Accent2 = rgb(255, 111, 122),
            Text = rgb(246, 247, 251), SubText = rgb(157, 163, 178),
            Border = rgb(255, 86, 105), BorderTransp = 0.84,
            Input = rgb(9, 10, 14), InputTransp = 0.30,
            Sheen = rgb(255, 226, 228), GlowTransp = 0.82,
        },

        Ocean    = { Glass = rgb(10, 24, 42),  Accent = rgb(60, 140, 255),  Accent2 = rgb(0, 215, 200) },

        Rose     = { Glass = rgb(36, 16, 28),  Accent = rgb(255, 90, 150),  Accent2 = rgb(255, 160, 100) },

        Emerald  = { Glass = rgb(10, 30, 24),  Accent = rgb(40, 200, 140),  Accent2 = rgb(150, 235, 110) },

        Sunset   = { Glass = rgb(34, 20, 24),  Accent = rgb(255, 110, 70),  Accent2 = rgb(255, 200, 70) },

        Midnight = { Glass = rgb(8, 8, 12), GlassTransp = 0.1, Accent = rgb(205, 210, 230), Accent2 = rgb(125, 130, 155), GlowTransp = 0.94 },

        Light    = {

            Glass = rgb(236, 240, 250), GlassTransp = 0.1,

            Frost = rgb(30, 40, 80), ElementTransp = 0.92, HoverTransp = 0.84,

            Text = rgb(26, 30, 50), SubText = rgb(92, 100, 128),

            Border = rgb(30, 40, 80), BorderTransp = 0.82,

            Input = WHITE, InputTransp = 0.3,

            Accent = rgb(90, 90, 240), Accent2 = rgb(30, 160, 235), GlowTransp = 0.9,

        },

    },

    ThemeOrder = { "Redline", "Glass", "Ocean", "Rose", "Emerald", "Sunset", "Midnight", "Light" },

    CurrentTheme = "Redline",

    Connections = {},

    Windows = {},

    _skins = {},

    _themeListeners = {},

}

for k, v in pairs(BASE_THEME) do Library.Theme[k] = v end

local TweenService     = game:GetService("TweenService")

local UserInputService = game:GetService("UserInputService")

local Players          = game:GetService("Players")

local Lighting         = game:GetService("Lighting")

local Window = {}

Window.__index = Window

local Tab = {}

Tab.__index = Tab

local screenGui, notifHolder
-- Helpers
local function connect(signal, fn)

    local c = signal:Connect(fn)

    table.insert(Library.Connections, c)

    return c

end

local function new(class, props, children)

    local inst = Instance.new(class)

    local parent

    for k, v in pairs(props or {}) do

        if k == "Parent" then parent = v else inst[k] = v end

    end

    for _, child in ipairs(children or {}) do child.Parent = inst end

    if parent then inst.Parent = parent end

    return inst

end

local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }) end

local function stroke(transparency, thickness, color)

    local T = Library.Theme

    return new("UIStroke", {

        Color = color or T.Border,

        Transparency = transparency or T.BorderTransp,

        Thickness = thickness or 1,

        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,

    })

end

local function padding(l, t, r, b)

    return new("UIPadding", {

        PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0),

        PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0),

    })

end

local function gradient(c1, c2, rotation)

    return new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rotation or 0 })

end

local function tween(obj, props, t, style, dir)

    local tw = TweenService:Create(obj, TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)

    tw:Play()

    return tw

end

local function randomName()

    local s = {}

    for i = 1, 12 do s[i] = string.char(math.random(97, 122)) end

    return table.concat(s)

end

local function text(props)

    local base = {

        BackgroundTransparency = 1,

        Font = Enum.Font.Gotham,

        TextSize = 13,

        TextColor3 = Library.Theme.Text,

        TextXAlignment = Enum.TextXAlignment.Left,

        BorderSizePixel = 0,

    }

    for k, v in pairs(props) do base[k] = v end

    return new("TextLabel", base)

end

local function safeCall(fn, ...)

    if type(fn) ~= "function" then return end

    local ok, err = pcall(fn, ...)

    if not ok then warn("[UILib] Callback error: " .. tostring(err)) end

end

local function isPress(input)

    return input.UserInputType == Enum.UserInputType.MouseButton1

        or input.UserInputType == Enum.UserInputType.Touch

end

local function isMove(input)

    return input.UserInputType == Enum.UserInputType.MouseMovement

        or input.UserInputType == Enum.UserInputType.Touch

end
-- Theme engine: reapply skin callbacks whenever the active theme changes.
local function skin(owner, fn)

    table.insert(Library._skins, { owner = owner, fn = fn })

    fn(Library.Theme)

end

local function refreshSkins()

    local alive = {}

    for _, s in ipairs(Library._skins) do

        if screenGui and s.owner:IsDescendantOf(screenGui) then

            local ok, err = pcall(s.fn, Library.Theme)

            if not ok then warn("[UILib] Theme error: " .. tostring(err)) end

            table.insert(alive, s)

        end

    end

    Library._skins = alive

end

local function themedText(props, role)

    local l = text(props)

    skin(l, function(T) l.TextColor3 = T[role or "Text"] end)

    return l

end

local function line(props)

    local f = new("Frame", props)

    skin(f, function(T) f.BackgroundColor3 = T.Border end)

    return f

end

function Library:AddTheme(name, overrides)

    self.Themes[name] = overrides or {}

    if not table.find(self.ThemeOrder, name) then table.insert(self.ThemeOrder, name) end

end

function Library:GetThemeNames()

    return table.clone(self.ThemeOrder)

end
-- SetTheme("Ocean")                  -> switch to a preset-- SetTheme({ Accent = Color3... })   -> change individual values of the current theme
function Library:SetTheme(theme)

    if type(theme) == "string" then

        local preset = self.Themes[theme]

        if not preset then

            warn("[UILib] Unknown theme '" .. theme .. "'")

            return false

        end

        for k, v in pairs(BASE_THEME) do self.Theme[k] = v end

        for k, v in pairs(preset) do self.Theme[k] = v end

        self.CurrentTheme = theme

    elseif type(theme) == "table" then

        for k, v in pairs(theme) do self.Theme[k] = v end

        self.CurrentTheme = "Custom"

    else

        return false

    end

    refreshSkins()

    for _, fn in ipairs(self._themeListeners) do safeCall(fn, self.CurrentTheme, self.Theme) end

    return true

end

function Library:OnThemeChanged(fn)

    table.insert(self._themeListeners, fn)

end

function Library:ExportTheme()

    local keys = {}

    for k in pairs(self.Theme) do table.insert(keys, k) end

    table.sort(keys)

    local lines = { "{" }

    for _, k in ipairs(keys) do

        local v = self.Theme[k]

        local s

        if typeof(v) == "Color3" then

            s = string.format("Color3.fromRGB(%d, %d, %d)", math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5))

        else

            s = tostring(v)

        end

        table.insert(lines, string.format("\t%s = %s,", k, s))

    end

    table.insert(lines, "}")

    return table.concat(lines, "\n")

end
-- --------------------------------------------------------------------- Gui root, logo loading-- -------------------------------------------------------------------
local function getGuiParent()
-- Prefer executor-protected containers, fall back to normal locations.
    if gethui then

        local ok, ui = pcall(gethui)

        if ok and ui then return ui end

    end

    local ok, core = pcall(function() return game:GetService("CoreGui") end)

    if ok and core then

        local test = Instance.new("Folder")

        local parented = pcall(function() test.Parent = core end)

        test:Destroy()

        if parented then return core end

    end

    return Players.LocalPlayer:WaitForChild("PlayerGui")

end

--[[

    Logo loading. Accepts:

      - a number / numeric string  (decal ID or image ID)

      - "rbxassetid://123" or an "...asset/?id=123" URL

      - "rbxasset://..." paths (e.g. from getcustomasset)

    Decal IDs point at a Decal object, not the raw image, so we try to resolve the real

    texture with game:GetObjects (supported by most executors). If that isn't available

    we fall back to using the ID directly.

]]

local function applyLogo(imageLabel, id)

    local s = tostring(id)

    if s:find("^rbxasset://") then

        imageLabel.Image = s

        return

    end

    local num = s:match("%d+")

    if not num then return end

    imageLabel.Image = "rbxassetid://" .. num -- immediate fallback

    task.spawn(function()

        local ok, obj = pcall(function()

            return game:GetObjects("rbxassetid://" .. num)[1]

        end)

        if ok and obj then

            local tex

            if obj:IsA("Decal") or obj:IsA("Texture") then

                tex = obj.Texture

            elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then

                tex = obj.Image

            end

            if tex and tex ~= "" and imageLabel.Parent then

                imageLabel.Image = tex

            end

            pcall(function() obj:Destroy() end)

        end

    end)

end

local function ensureGui()

    if screenGui and screenGui.Parent then return screenGui end

    screenGui = new("ScreenGui", {

        Name = randomName(),

        ResetOnSpawn = false,

        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

        DisplayOrder = 999,

        IgnoreGuiInset = true,

    })

    if syn and syn.protect_gui then pcall(syn.protect_gui, screenGui) end

    screenGui.Parent = getGuiParent()

    notifHolder = new("Frame", {

        Name = "Notifications",

        AnchorPoint = Vector2.new(1, 1),

        Position = UDim2.new(1, -16, 1, -16),

        Size = UDim2.new(0, 280, 1, -32),

        BackgroundTransparency = 1,

        Parent = screenGui,

    }, {

        new("UIListLayout", {

            Padding = UDim.new(0, 8),

            VerticalAlignment = Enum.VerticalAlignment.Bottom,

            HorizontalAlignment = Enum.HorizontalAlignment.Right,

            SortOrder = Enum.SortOrder.LayoutOrder,

        }),

    })

    return screenGui

end
-- Notifications
function Library:Notify(opts)

    opts = opts or {}

    ensureGui()

    local T = self.Theme

    local wrapper = new("Frame", {

        Size = UDim2.new(1, 0, 0, 66),

        BackgroundTransparency = 1,

        Parent = notifHolder,

    })

    local card = new("Frame", {

        Position = UDim2.new(1, 30, 0, 0),

        Size = UDim2.new(1, 0, 1, 0),

        BackgroundColor3 = T.Glass,

        BackgroundTransparency = 0.12,

        BorderSizePixel = 0,

        Parent = wrapper,

    }, { corner(12), stroke(0.8, 1) })

    new("Frame", {

        Size = UDim2.new(0, 3, 1, -22), Position = UDim2.new(0, 10, 0, 11),

        BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = card,

    }, { corner(2), gradient(T.Accent, T.Accent2, 90) })

    text({

        Text = opts.Title or "Notification", Font = Enum.Font.GothamBold, TextSize = 14,

        Position = UDim2.new(0, 24, 0, 9), Size = UDim2.new(1, -34, 0, 18), Parent = card,

    })

    text({

        Text = opts.Content or "", TextColor3 = T.SubText, TextSize = 12, TextWrapped = true,

        TextYAlignment = Enum.TextYAlignment.Top,

        Position = UDim2.new(0, 24, 0, 29), Size = UDim2.new(1, -34, 0, 30), Parent = card,

    })

    tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.3, Enum.EasingStyle.Back)

    task.delay(opts.Duration or 4, function()

        if not card.Parent then return end

        local tw = tween(card, { Position = UDim2.new(1, 30, 0, 0) }, 0.25)

        tw.Completed:Wait()

        wrapper:Destroy()

    end)

end
-- Window
function Library:CreateWindow(opts)

    opts = opts or {}

    if opts.Theme then self:SetTheme(opts.Theme) end

    local T = self.Theme

    local gui = ensureGui()

    local win = setmetatable({

        Tabs = {},

        ActiveTab = nil,

        Visible = true,

        Destroyed = false,

        ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift,

        LogoSize = math.clamp(opts.LogoSize or 28, 16, 34),

        LogoCircle = opts.LogoCircle == true,

    }, Window)

    local main = new("Frame", {

        Name = "Main",

        AnchorPoint = Vector2.new(0.5, 0.5),

        Position = UDim2.new(0.5, 0, 0.5, 0),

        Size = opts.Size or UDim2.new(0, 980, 0, 640),

        BorderSizePixel = 0,

        Parent = gui,

    }, { corner(18) })

    win.Main = main

    skin(main, function(T)

        main.BackgroundColor3 = T.Glass

        main.BackgroundTransparency = T.GlassTransp

    end)
-- Glass layers: edge highlight, top sheen, soft accent glow
    local edge = new("UIStroke", {

        Color = WHITE, Transparency = 0.62, Thickness = 1.3,

        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = main,

    })

    local edgeGrad = new("UIGradient", { Rotation = 45, Parent = edge })

    skin(edge, function(T)

        edgeGrad.Color = ColorSequence.new(T.Border, T.Glass:Lerp(T.Border, 0.3))

    end)

    local sheen = new("Frame", {

        Name = "Sheen", Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = WHITE,

        BorderSizePixel = 0, ZIndex = 0, Parent = main,

    }, { corner(14) })

    new("UIGradient", {

        Rotation = 90,

        Transparency = NumberSequence.new({

            NumberSequenceKeypoint.new(0, 0.9),

            NumberSequenceKeypoint.new(1, 1),

        }),

        Parent = sheen,

    })

    skin(sheen, function(T) sheen.BackgroundColor3 = T.Sheen end)

    local glow = new("Frame", {

        Name = "Glow", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = WHITE,

        BorderSizePixel = 0, ZIndex = 0, Parent = main,

    }, { corner(14) })

    local glowGrad = new("UIGradient", { Rotation = 45, Parent = glow })

    skin(glow, function(T)

        glow.BackgroundColor3 = T.Accent

        glowGrad.Transparency = NumberSequence.new({

            NumberSequenceKeypoint.new(0, 1),

            NumberSequenceKeypoint.new(0.55, 1),

            NumberSequenceKeypoint.new(1, T.GlowTransp),

        })

    end)
-- Optional screen blur (Roblox can't blur only behind a GUI, so this blurs the whole game view)
    if opts.Blur then

        local ok, blur = pcall(function()

            return new("BlurEffect", {

                Name = randomName(),

                Size = type(opts.Blur) == "number" and opts.Blur or 12,

                Parent = Lighting,

            })

        end)

        if ok then win.BlurEffect = blur end

    end
-- Topbar
    local topbar = new("Frame", {

        Name = "Topbar", Size = UDim2.new(1, 0, 0, 62),

        BackgroundTransparency = 1, Parent = main,

    })

    win.Topbar = topbar

    win.TitleLabel = themedText({
        Text = opts.Title or "UI Library", Font = Enum.Font.GothamBold, TextSize = 16,
        Position = UDim2.new(0, 20, 0, 5), Size = UDim2.new(1, -180, 0, 25), Parent = topbar,
    }, "Text")
    local topSubtitle = themedText({
        Text = "YOUR MUSIC SPACE  /  LIVE PLAYBACK", Font = Enum.Font.GothamMedium, TextSize = 9,
        Position = UDim2.new(0, 20, 0, 31), Size = UDim2.new(1, -180, 0, 16), Parent = topbar,
    }, "SubText")

    local brandRail = new("Frame", {
        Name = "RedlineRail", Position = UDim2.new(0, 0, 0, 14),
        Size = UDim2.new(0, 4, 0, 34), BackgroundColor3 = WHITE,
        BorderSizePixel = 0, Parent = topbar,
    }, { corner(3) })
    local railGradient = new("UIGradient", { Rotation = 90, Parent = brandRail })
    skin(brandRail, function(T)
        railGradient.Color = ColorSequence.new(T.Accent, T.Accent2)
    end)

    local brandChip = new("Frame", {
        Name = "BrandChip", AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -74, 0.5, 0), Size = UDim2.new(0, 58, 0, 22),
        BackgroundColor3 = WHITE, BackgroundTransparency = 0.84,
        BorderSizePixel = 0, Parent = topbar,
    }, { corner(8) })
    local brandText = new("TextLabel", {
        Name = "BrandText", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        Text = opts.Brand or "REDLINE", Font = Enum.Font.GothamBold, TextSize = 9,
        TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center,
        BorderSizePixel = 0, Parent = brandChip,
    })
    skin(brandChip, function(T)
        brandChip.BackgroundColor3 = T.Accent
        brandText.TextColor3 = T.Text
    end)

    line({

        Position = UDim2.new(0, 0, 0, 62), Size = UDim2.new(1, 0, 0, 1),

        BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = main,

    })

    local function topButton(label, xOffset, hoverColor)

        local b = new("TextButton", {

            Text = label, Font = Enum.Font.GothamBold, TextSize = 16,

            AutoButtonColor = false,

            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOffset, 0.5, 0),

            Size = UDim2.new(0, 26, 0, 26),

            BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = topbar,

        }, { corner(8) })

        skin(b, function(T)

            b.BackgroundColor3 = T.Frost

            b.TextColor3 = T.SubText

        end)

        connect(b.MouseEnter, function()

            tween(b, { BackgroundColor3 = typeof(hoverColor) == "function" and hoverColor() or hoverColor, BackgroundTransparency = 0.25, TextColor3 = WHITE })

        end)

        connect(b.MouseLeave, function()

            tween(b, { BackgroundColor3 = T.Frost, BackgroundTransparency = 0.9, TextColor3 = T.SubText })

        end)

        return b

    end

    local closeBtn = topButton("×", -10, rgb(235, 80, 90))

    local hideBtn = topButton("–", -42, function() return Library.Theme.Accent end)

    connect(closeBtn.MouseButton1Click, function() win:Destroy() end)

    connect(hideBtn.MouseButton1Click, function()

        win:SetVisible(false)

        Library:Notify({ Title = "UI hidden", Content = "Press " .. win.ToggleKey.Name .. " to show it again.", Duration = 3 })

    end)
-- Dragging
    local dragging, dragStart, startPos

    connect(topbar.InputBegan, function(input)

        if isPress(input) then

            dragging, dragStart, startPos = true, input.Position, main.Position

        end

    end)

    connect(UserInputService.InputEnded, function(input)

        if isPress(input) then dragging = false end

    end)

    connect(UserInputService.InputChanged, function(input)

        if dragging and isMove(input) then

            local d = input.Position - dragStart

            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)

        end

    end)
-- Sidebar + content
    win.Sidebar = new("ScrollingFrame", {

        Position = UDim2.new(0, 0, 0, 63), Size = UDim2.new(0, 188, 1, -63),

        BackgroundTransparency = 1, BorderSizePixel = 0,

        ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,

        Parent = main,

    }, {

        new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }),

        padding(13, 12, 13, 12),

    })

    line({

        Position = UDim2.new(0, 188, 0, 63), Size = UDim2.new(0, 1, 1, -63),

        BackgroundTransparency = 0.92, BorderSizePixel = 0, Parent = main,

    })

    win.Content = new("Frame", {

        Position = UDim2.new(0, 189, 0, 63), Size = UDim2.new(1, -189, 1, -69),

        BackgroundTransparency = 1, Parent = main,

    })
-- Toggle key
    connect(UserInputService.InputBegan, function(input, processed)

        if not win.Destroyed and not processed and input.KeyCode == win.ToggleKey then

            win:SetVisible(not win.Visible)

        end

    end)

    win:SetLogo(opts.Logo)

    table.insert(Library.Windows, win)

    return win

end

function Window:SetTitle(title) self.TitleLabel.Text = title end

function Window:SetLogo(id)

    if not id or id == 0 or id == "" then

        if self.LogoImage then self.LogoImage:Destroy() self.LogoImage = nil end

        self.TitleLabel.Position = UDim2.new(0, 16, 0, 0)

        self.TitleLabel.Size = UDim2.new(1, -154, 1, 0)

        return

    end

    local size = self.LogoSize

    if not self.LogoImage then

        self.LogoImage = new("ImageLabel", {

            Name = "Logo", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,

            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0),

            Size = UDim2.new(0, size, 0, size), Parent = self.Topbar,

        }, { new("UICorner", { CornerRadius = self.LogoCircle and UDim.new(1, 0) or UDim.new(0, 8) }) })

    end

    local offset = 14 + size + 10

    self.TitleLabel.Position = UDim2.new(0, offset, 0, 0)

    self.TitleLabel.Size = UDim2.new(1, -(offset + 134), 1, 0)

    applyLogo(self.LogoImage, id)

end

function Window:SetVisible(state)

    self.Visible = state

    self.Main.Visible = state

    if self.BlurEffect then self.BlurEffect.Enabled = state end

end

function Window:Toggle() self:SetVisible(not self.Visible) end

function Window:Destroy()

    self.Destroyed = true

    for i, w in ipairs(Library.Windows) do

        if w == self then table.remove(Library.Windows, i) break end

    end

    if self.BlurEffect then self.BlurEffect:Destroy() self.BlurEffect = nil end

    self.Main:Destroy()

end

function Window:SelectTab(tab)

    local T = Library.Theme

    for _, t in ipairs(self.Tabs) do

        local active = (t == tab)

        t.Page.Visible = active

        t.Indicator.Visible = active

        tween(t.Button, {

            BackgroundTransparency = active and 0.88 or 1,

            TextColor3 = active and T.Text or T.SubText,

        })

    end

    self.ActiveTab = tab

end

function Window:CreateTab(name)

    local tab = setmetatable({ Window = self, Name = name }, Tab)

    tab.Button = new("TextButton", {

        Text = "    " .. string.upper(name), Font = Enum.Font.GothamSemibold, TextSize = 11,

        TextXAlignment = Enum.TextXAlignment.Left,

        Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1,

        AutoButtonColor = false, BorderSizePixel = 0,

        LayoutOrder = #self.Tabs, Parent = self.Sidebar,

    }, { corner(8) })

    skin(tab.Button, function(T)

        local active = (self.ActiveTab == tab)

        tab.Button.BackgroundColor3 = T.Frost

        tab.Button.BackgroundTransparency = active and 0.84 or 1

        tab.Button.TextColor3 = active and T.Text or T.SubText

    end)

    tab.Indicator = new("Frame", {

        Size = UDim2.new(0, 3, 0, 20), Position = UDim2.new(0, 3, 0.5, -10),

        BackgroundColor3 = WHITE, BorderSizePixel = 0, Visible = false, Parent = tab.Button,

    }, { corner(2) })

    local indGrad = new("UIGradient", { Rotation = 90, Parent = tab.Indicator })

    skin(tab.Indicator, function(T) indGrad.Color = ColorSequence.new(T.Accent, T.Accent2) end)

    tab.Page = new("ScrollingFrame", {

        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,

        ScrollBarThickness = 3, ScrollBarImageTransparency = 0.3,

        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,

        Visible = false, Parent = self.Content,

    }, {

        new("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }),

        padding(12, 12, 14, 10),

    })

    skin(tab.Page, function(T) tab.Page.ScrollBarImageColor3 = T.Accent end)

    connect(tab.Button.MouseButton1Click, function() self:SelectTab(tab) end)

    connect(tab.Button.MouseEnter, function()

        if self.ActiveTab ~= tab then tween(tab.Button, { BackgroundTransparency = 0.94 }) end

    end)

    connect(tab.Button.MouseLeave, function()

        if self.ActiveTab ~= tab then tween(tab.Button, { BackgroundTransparency = 1 }) end

    end)

    table.insert(self.Tabs, tab)

    if not self.ActiveTab then self:SelectTab(tab) end

    return tab

end
-- Elements
local function makeElement(tab, height)

    local T = Library.Theme

    local st = stroke()

    local frame = new("Frame", {

        Size = UDim2.new(1, 0, 0, height or 36),

        BorderSizePixel = 0, Parent = tab.Page,

    }, { corner(9), st })

    skin(frame, function(T)

        frame.BackgroundColor3 = T.Frost

        frame.BackgroundTransparency = T.ElementTransp

        st.Color = T.Border

        st.Transparency = T.BorderTransp

    end)

    connect(frame.MouseEnter, function() tween(frame, { BackgroundTransparency = T.HoverTransp }) end)

    connect(frame.MouseLeave, function() tween(frame, { BackgroundTransparency = T.ElementTransp }) end)

    return frame

end

function Tab:AddSection(name)

    local lbl = text({

        Text = string.upper(name), Font = Enum.Font.GothamBold, TextSize = 11,

        TextColor3 = WHITE, Size = UDim2.new(1, 0, 0, 22), Parent = self.Page,

    })

    local g = new("UIGradient", { Parent = lbl })

    skin(lbl, function(T) g.Color = ColorSequence.new(T.Accent, T.Accent2) end)

    return { Set = function(_, v) lbl.Text = string.upper(v) end }

end

function Tab:AddLabel(content)

    local frame = makeElement(self, 32)

    local lbl = themedText({

        Text = content,

        Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -28, 1, 0), Parent = frame,

    }, "SubText")

    return { Set = function(_, v) lbl.Text = v end }

end

function Tab:AddButton(opts)

    local T = Library.Theme

    local frame = makeElement(self, 36)

    local btn = new("TextButton", {

        Text = "", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = frame,

    })

    themedText({

        Text = opts.Name or "Button", Position = UDim2.new(0, 14, 0, 0),

        Size = UDim2.new(1, -44, 1, 0), Parent = frame,

    }, "Text")

    themedText({

        Text = "›", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center,

        Position = UDim2.new(1, -30, 0, 0), Size = UDim2.new(0, 20, 1, -2), Parent = frame,

    }, "SubText")

    connect(btn.MouseButton1Click, function()

        tween(frame, { BackgroundTransparency = 0.72 }, 0.08).Completed:Connect(function()

            tween(frame, { BackgroundTransparency = T.HoverTransp }, 0.2)

        end)

        safeCall(opts.Callback)

    end)

    return {}

end

function Tab:AddToggle(opts)

    local state = opts.Default == true

    local frame = makeElement(self, 36)

    themedText({

        Text = opts.Name or "Toggle", Position = UDim2.new(0, 14, 0, 0),

        Size = UDim2.new(1, -74, 1, 0), Parent = frame,

    }, "Text")

    local track = new("Frame", {

        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),

        Size = UDim2.new(0, 40, 0, 22), BackgroundColor3 = WHITE,

        BackgroundTransparency = 0.8, BorderSizePixel = 0, Parent = frame,

    }, { corner(11) })

    local trackGrad = new("UIGradient", { Enabled = false, Parent = track })

    local knob = new("Frame", {

        Position = UDim2.new(0, 3, 0.5, -8), Size = UDim2.new(0, 16, 0, 16),

        BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = track,

    }, { corner(8) })

    local hit = new("TextButton", { Text = "", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = frame })

    skin(track, function(T)

        trackGrad.Color = ColorSequence.new(T.Accent, T.Accent2)

        trackGrad.Enabled = state

        track.BackgroundColor3 = state and WHITE or T.Frost

        track.BackgroundTransparency = state and 0.05 or 0.8

    end)

    local obj = {}

    local function render()

        local T = Library.Theme

        trackGrad.Enabled = state

        tween(track, {

            BackgroundColor3 = state and WHITE or T.Frost,

            BackgroundTransparency = state and 0.05 or 0.8,

        })

        tween(knob, { Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8) })

    end

    function obj:Set(v, silent)

        state = v and true or false

        render()

        if not silent then safeCall(opts.Callback, state) end

    end

    function obj:Get() return state end

    connect(hit.MouseButton1Click, function() obj:Set(not state) end)

    render()

    if state then safeCall(opts.Callback, state) end

    return obj

end

function Tab:AddSlider(opts)

    local min, max, inc = opts.Min or 0, opts.Max or 100, opts.Increment or 1

    local value = math.clamp(opts.Default or min, min, max)

    local frame = makeElement(self, 54)

    themedText({ Text = opts.Name or "Slider", Position = UDim2.new(0, 14, 0, 7), Size = UDim2.new(1, -94, 0, 18), Parent = frame }, "Text")

    local valueLabel = themedText({

        TextXAlignment = Enum.TextXAlignment.Right,

        Position = UDim2.new(1, -86, 0, 7), Size = UDim2.new(0, 72, 0, 18), Parent = frame,

    }, "SubText")

    local bar = new("Frame", {

        Position = UDim2.new(0, 14, 0, 37), Size = UDim2.new(1, -28, 0, 6),

        BackgroundTransparency = 0.82, BorderSizePixel = 0, Parent = frame,

    }, { corner(3) })

    skin(bar, function(T) bar.BackgroundColor3 = T.Frost end)

    local fill = new("Frame", {

        Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = bar,

    }, { corner(3) })

    local fillGrad = new("UIGradient", { Parent = fill })

    local knobStroke = stroke(0.5, 2)

    new("Frame", {

        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0),

        Size = UDim2.new(0, 12, 0, 12), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = fill,

    }, { corner(6), knobStroke })

    skin(fill, function(T)

        fillGrad.Color = ColorSequence.new(T.Accent, T.Accent2)

        knobStroke.Color = T.Accent

    end)

    local hit = new("TextButton", {

        Text = "", BackgroundTransparency = 1,

        Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, 0, 0, 26), Parent = frame,

    })

    local obj = {}

    function obj:Set(v, silent)

        v = math.clamp(v, min, max)

        v = min + math.floor((v - min) / inc + 0.5) * inc

        v = math.clamp(math.floor(v * 10000 + 0.5) / 10000, min, max)

        value = v

        local alpha = (max == min) and 0 or (v - min) / (max - min)

        tween(fill, { Size = UDim2.new(alpha, 0, 1, 0) }, 0.06)

        valueLabel.Text = tostring(v) .. (opts.Suffix or "")

        if not silent then safeCall(opts.Callback, v) end

    end

    function obj:Get() return value end

    local dragging = false

    local function update(input)

        local alpha = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)

        obj:Set(min + (max - min) * alpha)

    end

    connect(hit.InputBegan, function(input)

        if isPress(input) then dragging = true update(input) end

    end)

    connect(UserInputService.InputEnded, function(input)

        if isPress(input) then dragging = false end

    end)

    connect(UserInputService.InputChanged, function(input)

        if dragging and isMove(input) then update(input) end

    end)

    obj:Set(value, true)

    return obj

end

function Tab:AddDropdown(opts)

    local T = Library.Theme

    local options = opts.Options or {}

    local selected = opts.Default

    local open = false

    local ITEM_H, MAX_H = 26, 130

    local frame = makeElement(self, 36)

    frame.ClipsDescendants = true

    themedText({ Text = opts.Name or "Dropdown", Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0.5, -14, 0, 36), Parent = frame }, "Text")

    local current = themedText({

        Text = selected and tostring(selected) or "Select...",

        TextXAlignment = Enum.TextXAlignment.Right,

        Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -34, 0, 36), Parent = frame,

    }, "SubText")

    local arrow = themedText({

        Text = "▼", TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center,

        Position = UDim2.new(1, -28, 0, 0), Size = UDim2.new(0, 20, 0, 36), Parent = frame,

    }, "SubText")

    local header = new("TextButton", { Text = "", Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = frame })

    local list = new("ScrollingFrame", {

        Position = UDim2.new(0, 8, 0, 40), Size = UDim2.new(1, -16, 1, -48),

        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,

        CanvasSize = UDim2.new(),

        AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = frame,

    }, { new("UIListLayout", { Padding = UDim.new(0, 3) }) })

    skin(list, function(T) list.ScrollBarImageColor3 = T.Accent end)

    local obj = {}

    local function listHeight() return math.min(#options * ITEM_H + math.max(#options - 1, 0) * 3, MAX_H) end

    local function setOpen(state)

        open = state

        tween(frame, { Size = UDim2.new(1, 0, 0, open and (48 + listHeight()) or 36) }, 0.2)

        tween(arrow, { Rotation = open and 180 or 0 }, 0.2)

    end

    function obj:Set(v, silent)

        selected = v

        current.Text = v ~= nil and tostring(v) or "Select..."

        if not silent then safeCall(opts.Callback, v) end

    end

    function obj:Get() return selected end

    local function build()

        for _, c in ipairs(list:GetChildren()) do

            if c:IsA("TextButton") then c:Destroy() end

        end

        for _, option in ipairs(options) do

            local b = new("TextButton", {

                Text = tostring(option), Font = Enum.Font.Gotham, TextSize = 12,

                AutoButtonColor = false,

                Size = UDim2.new(1, -4, 0, ITEM_H),

                BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = list,

            }, { corner(7) })

            skin(b, function(T)

                b.BackgroundColor3 = T.Frost

                b.BackgroundTransparency = 0.9

                b.TextColor3 = T.Text

            end)

            connect(b.MouseEnter, function() tween(b, { BackgroundColor3 = T.Accent, BackgroundTransparency = 0.45 }) end)

            connect(b.MouseLeave, function() tween(b, { BackgroundColor3 = T.Frost, BackgroundTransparency = 0.9 }) end)

            connect(b.MouseButton1Click, function()

                obj:Set(option)

                setOpen(false)

            end)

        end

    end

    function obj:Refresh(newOptions)

        options = newOptions or {}

        build()

        if open then setOpen(true) end

    end

    connect(header.MouseButton1Click, function() setOpen(not open) end)

    build()

    return obj

end

function Tab:AddTextbox(opts)

    local T = Library.Theme

    local frame = makeElement(self, 36)

    themedText({ Text = opts.Name or "Textbox", Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -180, 1, 0), Parent = frame }, "Text")

    local boxStroke = stroke(0.85, 1)

    local box = new("TextBox", {

        Text = opts.Default or "", PlaceholderText = opts.Placeholder or "Type here...",

        Font = Enum.Font.Gotham, TextSize = 12,

        ClearTextOnFocus = false, AnchorPoint = Vector2.new(1, 0.5),

        Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 156, 0, 26),

        BorderSizePixel = 0, Parent = frame,

    }, { corner(7), boxStroke, padding(8, 0, 8, 0) })

    skin(box, function(T)

        box.BackgroundColor3 = T.Input

        box.BackgroundTransparency = T.InputTransp

        box.TextColor3 = T.Text

        box.PlaceholderColor3 = T.SubText

        if not box:IsFocused() then

            boxStroke.Color = T.Border

            boxStroke.Transparency = T.BorderTransp

        end

    end)

    connect(box.Focused, function() tween(boxStroke, { Color = T.Accent, Transparency = 0.1 }) end)

    connect(box.FocusLost, function(enter)

        tween(boxStroke, { Color = T.Border, Transparency = T.BorderTransp })

        safeCall(opts.Callback, box.Text, enter)

    end)

    return {

        Set = function(_, v) box.Text = tostring(v) end,

        Get = function() return box.Text end,

    }

end

function Tab:AddKeybind(opts)

    local key = opts.Default or Enum.KeyCode.F

    local listening = false

    local frame = makeElement(self, 36)

    themedText({ Text = opts.Name or "Keybind", Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -120, 1, 0), Parent = frame }, "Text")

    local btnStroke = stroke(0.85, 1)

    local btn = new("TextButton", {

        Text = key.Name, Font = Enum.Font.GothamMedium, TextSize = 12,

        AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0.5),

        Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 94, 0, 26),

        BorderSizePixel = 0, Parent = frame,

    }, { corner(7), btnStroke })

    skin(btn, function(T)

        btn.BackgroundColor3 = T.Input

        btn.BackgroundTransparency = T.InputTransp

        btn.TextColor3 = T.Text

        btnStroke.Color = T.Border

        btnStroke.Transparency = T.BorderTransp

    end)

    local obj = {}

    function obj:Set(k) key = k btn.Text = k.Name end

    function obj:Get() return key end

    connect(btn.MouseButton1Click, function()

        listening = true

        btn.Text = "..."

    end)

    connect(UserInputService.InputBegan, function(input, processed)

        if listening then

            if input.UserInputType == Enum.UserInputType.Keyboard then

                listening = false

                if input.KeyCode == Enum.KeyCode.Escape then

                    btn.Text = key.Name

                else

                    obj:Set(input.KeyCode)

                    safeCall(opts.Changed, key)

                end

            end

        elseif not processed and input.KeyCode == key then

            safeCall(opts.Callback, key)

        end

    end)

    return obj

end
-- Ready-made theme controls: preset dropdown, window transparency, accent hue, copy code.
function Tab:AddThemeSettings()

    self:AddSection("Theme")

    local dropdown = self:AddDropdown({

        Name = "Preset",

        Options = Library:GetThemeNames(),

        Default = Library.CurrentTheme,

        Callback = function(name)

            if Library.Themes[name] then Library:SetTheme(name) end

        end,

    })

    local transparency = self:AddSlider({

        Name = "Window transparency",

        Min = 0, Max = 60, Increment = 1, Suffix = "%",

        Default = math.floor(Library.Theme.GlassTransp * 100 + 0.5),

        Callback = function(v) Library:SetTheme({ GlassTransp = v / 100 }) end,

    })

    local function currentHue()

        local h = Library.Theme.Accent:ToHSV()

        return math.floor(h * 360 + 0.5) % 361

    end

    local hue = self:AddSlider({

        Name = "Accent hue",

        Min = 0, Max = 360, Increment = 1,

        Default = currentHue(),

        Callback = function(v)

            local h = v / 360

            Library:SetTheme({

                Accent  = Color3.fromHSV(h, 0.6, 1),

                Accent2 = Color3.fromHSV((h + 0.12) % 1, 0.65, 1),

            })

        end,

    })

    self:AddButton({

        Name = "Copy theme code",

        Callback = function()

            local code = Library:ExportTheme()

            local clip = setclipboard or toclipboard

            if clip then

                clip(code)

                Library:Notify({ Title = "Theme copied", Content = "Paste it into Library:AddTheme(\"Name\", ...)", Duration = 3 })

            else

                print(code)

                Library:Notify({ Title = "Clipboard unavailable", Content = "Theme code was printed to the console.", Duration = 3 })

            end

        end,

    })
-- keep the controls in sync if the theme changes from elsewhere
    Library:OnThemeChanged(function(name, T)

        dropdown:Set(name, true)

        transparency:Set(math.floor(T.GlassTransp * 100 + 0.5), true)

        hue:Set(currentHue(), true)

    end)

end
-- Cleanup
function Library:Unload()

    for _, w in ipairs(table.clone(self.Windows)) do

        pcall(function() w:Destroy() end)

    end

    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end

    table.clear(self.Connections)

    table.clear(self.Windows)

    table.clear(self._skins)

    table.clear(self._themeListeners)

    if screenGui then screenGui:Destroy() screenGui = nil notifHolder = nil end

end

return Library
end)()

-- REDLINE NOVA — polished smoked-glass Spotify dashboard, client-side PKCE integration
-- Uses Spotify's read-only playback API directly from the executor HTTP request function.
-- Keep this running between starting login and exchanging the redirect URL.

HttpService = game:GetService("HttpService")
-- Create the notification/theme host, but use a fully custom dashboard UI.
-- This intentionally replaces the previous tab/card layout rather than restyling it.
Window = Library:CreateWindow({
    Title = "REDLINE NOVA",
    Theme = "Redline",
    Size = UDim2.new(0, 980, 0, 640),
    ToggleKey = Enum.KeyCode.RightShift,
})
Window.Main.Visible = false

PlayerTab = Window:CreateTab("Player")
SetupTab = Window:CreateTab("Setup")

connectionLabelObject, trackLabelObject, artistLabelObject = nil, nil, nil
albumLabelObject, playbackLabelObject, progressLabelObject, progressBarLabelObject = nil, nil, nil, nil
progressDurationLabelObject, customProgressFill, albumArtImageObject = nil, nil, nil
playerAccentStroke, playerAccentTop, playerAccentFill, playerAccentPlayback = nil, nil, nil, nil
playerCardObject, playerAccentTitle, playerFallbackDisc = nil, nil, nil
currentAlbumArtUrl, albumArtLoadingUrl = nil, nil
applyAlbumPalette = nil
customPlayerBuilt = false

function uiNew(className, props, children)
    local inst = Instance.new(className)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then inst[k] = v end
    end
    -- Explicitly layer every dashboard control above its background in the
    -- executor's shared ScreenGui, which also contains the hidden legacy UI.
    if inst:IsA("GuiObject") and not (props and props.ZIndex) then inst.ZIndex = 24 end
    for i, child in ipairs(children or {}) do if child then child.Parent = inst end end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end
function uiCorner(parent, radius)
    return uiNew("UICorner", {CornerRadius = UDim.new(0, radius or 10), Parent = parent})
end
function uiStroke(parent, color, transparency, thickness)
    return uiNew("UIStroke", {Color = color or Color3.fromRGB(60,64,76), Transparency = transparency or 0.3, Thickness = thickness or 1, Parent = parent})
end
function uiLabel(parent, text, size, position, font, color, align)
    return uiNew("TextLabel", {
        BackgroundTransparency = 1, BorderSizePixel = 0, Parent = parent,
        Text = text or "", Font = font or Enum.Font.Gotham, TextSize = size or 12,
        TextColor3 = color or Color3.fromRGB(238,240,247),
        TextXAlignment = align or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = position or UDim2.new(), Size = UDim2.new(1,0,0,24),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
end
TweenService = game:GetService("TweenService")
function getLiveAlbumAccent()
    return activeAlbumAccent or Color3.fromRGB(255,55,82)
end
function uiButton(parent, text, position, size, primary, callback)
    local b = uiNew("TextButton", {
        Parent = parent, Text = text, Position = position, Size = size,
        AutoButtonColor = false, BorderSizePixel = 0,
        BackgroundColor3 = primary and getLiveAlbumAccent() or Color3.fromRGB(34,36,45),
        TextColor3 = Color3.fromRGB(248,249,252), TextSize = 12,
        Font = Enum.Font.GothamSemibold,
    })
    uiCorner(b, 9)
    if not primary then uiStroke(b, Color3.fromRGB(76,79,92), 0.55, 1) end
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = primary and getLiveAlbumAccent():Lerp(Color3.new(1,1,1), 0.12) or Color3.fromRGB(46,49,60)
        }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundColor3 = primary and getLiveAlbumAccent() or Color3.fromRGB(34,36,45)
        }):Play()
    end)
    if callback then b.MouseButton1Click:Connect(callback) end
    return b
end
function boundLabel(label)
    return { Set = function(_, value)
        value = tostring(value)
        if label and label.Parent and label.Text ~= value then label.Text = value end
    end }
end

-- Reuse the ScreenGui created by the existing UI library. The helper
-- ensureGui() is scoped inside the library bootstrap and is not visible here.
oldMain = Window.Main
gui = oldMain and oldMain.Parent
if not gui then
    error("[Redline Nova] Could not find the UI ScreenGui parent")
end
oldMain.Visible = false
root = uiNew("Frame", {
    Name = "RedlineNovaDashboard", Parent = gui, Visible = true, ClipsDescendants = true,
    AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.new(0.5,0,0.5,0),
    Size = UDim2.new(0,1040,0,660), BackgroundColor3 = Color3.fromRGB(13,15,22),
    BackgroundTransparency = 0.16, BorderSizePixel = 0, ZIndex = 20,
})
uiCorner(root, 18)
uiStroke(root, Color3.fromRGB(151,154,169), 0.52, 1)
uiNew("UIGradient", {Parent = root, Rotation = 135, Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(24,25,34)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(14,15,21)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(22,15,23)),
})})

-- Custom left rail: deliberately unlike the old library's compact tab list.
rail = uiNew("Frame", {Parent = root, Position = UDim2.new(0,0,0,0), Size = UDim2.new(0,172,1,0), BackgroundColor3 = Color3.fromRGB(10,12,19), BackgroundTransparency = 0.22, BorderSizePixel = 0, ZIndex = 21})
uiCorner(rail, 18)
uiNew("Frame", {Parent = rail, Position = UDim2.new(1,-1,0,20), Size = UDim2.new(0,1,1,-40), BackgroundColor3 = Color3.fromRGB(255,255,255), BackgroundTransparency = 0.92, BorderSizePixel = 0, ZIndex = 22})
brandIcon = uiNew("Frame", {Parent = rail, Position = UDim2.new(0,18,0,22), Size = UDim2.fromOffset(30,30), BackgroundColor3 = Color3.fromRGB(255,55,82), BorderSizePixel = 0, ZIndex = 22})
uiCorner(brandIcon, 10)
uiLabel(brandIcon, "R", 21, UDim2.new(0,0,0,0), Enum.Font.GothamBlack, Color3.new(1,1,1), Enum.TextXAlignment.Center).Size = UDim2.fromScale(1,1)
uiLabel(rail, "REDLINE", 17, UDim2.new(0,56,0,22), Enum.Font.GothamBlack, Color3.fromRGB(246,247,251)).Size = UDim2.new(1,-78,0,20)
uiLabel(rail, "MUSIC DESKTOP", 8, UDim2.new(0,57,0,41), Enum.Font.GothamBold, Color3.fromRGB(133,139,155)).Size = UDim2.new(1,-78,0,15)
uiLabel(rail, "WORKSPACE", 9, UDim2.new(0,18,0,88), Enum.Font.GothamBold, Color3.fromRGB(105,111,128)).Size = UDim2.new(1,-38,0,18)
playerNav = uiButton(rail, "♫     Now Playing", UDim2.new(0,10,0,112), UDim2.new(1,-20,0,38), false, nil)
playerNav.BackgroundColor3 = Color3.fromRGB(82,31,45); playerNav.BackgroundTransparency = 0.28
uiStroke(playerNav, Color3.fromRGB(255,54,87), 0.72, 1)
playerNav.TextXAlignment = Enum.TextXAlignment.Left
playerNav.Text = "     ♫     NOW PLAYING"
setupNav = uiButton(rail, "⚙     CONNECTION", UDim2.new(0,10,0,157), UDim2.new(1,-20,0,38), false, nil)
setupNav.TextXAlignment = Enum.TextXAlignment.Left
setupNav.Text = "     ⚙     CONNECTION"
-- Compact local Roblox identity + Spotify plan panel in the bottom of the rail.
localPlayer = game:GetService("Players").LocalPlayer
profileAvatar = uiNew("ImageLabel", {
    Name = "RobloxProfileAvatar", Parent = rail,
    Position = UDim2.new(0,14,1,-58), Size = UDim2.fromOffset(34,34),
    BackgroundColor3 = Color3.fromRGB(37,39,50), BackgroundTransparency = 0.12,
    BorderSizePixel = 0, Image = "",
    ZIndex = 23,
})
uiCorner(profileAvatar, 17)
uiStroke(profileAvatar, Color3.fromRGB(255,83,105), 0.62, 1)
profileName = uiLabel(rail, localPlayer and localPlayer.Name or "Roblox User", 11,
    UDim2.new(0,56,1,-58), Enum.Font.GothamBold, Color3.fromRGB(245,246,250))
profileName.Size = UDim2.new(1,-64,0,17)
profileName.TextTruncate = Enum.TextTruncate.AtEnd
profilePlan = uiLabel(rail, "Spotify · checking plan", 9,
    UDim2.new(0,56,1,-39), Enum.Font.GothamSemibold, Color3.fromRGB(160,166,182))
profilePlan.Size = UDim2.new(1,-64,0,16)
railStatus = profilePlan
if localPlayer then
    profileAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(localPlayer.UserId) .. "&w=150&h=150"
end

header = uiNew("Frame", {Parent = root, Position = UDim2.new(0,172,0,0), Size = UDim2.new(1,-172,0,78), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 22})
headerEyebrow = uiLabel(header, "YOUR SOUND, IN FOCUS", 9, UDim2.new(0,22,0,13), Enum.Font.GothamBold, Color3.fromRGB(255,91,111))
headerEyebrow.Size = UDim2.new(1,-170,0,16)
headerTitle = uiLabel(header, "Music dashboard", 20, UDim2.new(0,22,0,29), Enum.Font.GothamBold, Color3.fromRGB(247,248,252))
headerTitle.Size = UDim2.new(1,-170,0,30)
headerTitleLabels = {headerEyebrow, headerTitle}
headerPill = uiNew("Frame", {Parent = header, Position = UDim2.new(1,-222,0,26), Size = UDim2.fromOffset(112,28), BackgroundColor3 = Color3.fromRGB(31,34,43), BackgroundTransparency = 0.28, BorderSizePixel = 0, ZIndex = 23})
uiCorner(headerPill, 14)
headerPillText = uiLabel(headerPill, "●  DISCONNECTED", 9, UDim2.new(0,0,0,0), Enum.Font.GothamBold, Color3.fromRGB(180,185,198), Enum.TextXAlignment.Center)
headerPillText.Size = UDim2.fromScale(1,1)

-- Mini-player references are declared here so the window control callbacks can
-- switch between the full dashboard and the compact player without rebuilding UI.
miniPlayer, miniArt, miniTrackLabel, miniArtistLabel, miniPlaybackLabel = nil, nil, nil, nil, nil
miniProgressFill, miniPlayPauseButton = nil, nil
headerTitleLabels = {}
setPage, toggleMinimized, latestTrack, runPlaybackCommand = nil, nil, nil, nil
playerPage, setupPage = nil, nil
lyricsWindow = nil
toggleLyricsPanel, refreshLyricsForTrack = nil, nil

-- Minimize focuses the current track in a small floating mini-player; restore
-- returns the full dashboard to its saved size and page. Right Shift reopens it.
windowMinimized = false
savedWindowSize = root.Size
minimizeButton = uiButton(header, "-", UDim2.new(1,-102,0,7), UDim2.fromOffset(32,28), false, nil)
minimizeButton.Name = "MinimizeButton"
minimizeButton.Text = ""
minimizeButton.TextSize = 18
minimizeButton.BackgroundTransparency = 0.22
minimizeButton.ZIndex = 25
minimizeDash = uiNew("Frame", {
    Name = "MinimizeDash", Parent = minimizeButton,
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(12, 2), BackgroundColor3 = Color3.fromRGB(248,249,252),
    BorderSizePixel = 0, ZIndex = 27,
})
uiCorner(minimizeDash, 1)
exitButton = uiButton(header, "×", UDim2.new(1,-62,0,7), UDim2.fromOffset(32,28), false, nil)
exitButton.Name = "ExitButton"
exitButton.TextSize = 20
exitButton.BackgroundColor3 = Color3.fromRGB(100,35,48)
exitButton.ZIndex = 25
toggleMinimized = function()
    windowMinimized = not windowMinimized
    if windowMinimized then
        savedWindowSize = root.Size
        root.Size = UDim2.fromOffset(520, 90)
        rail.Visible = false
        playerPage.Visible = false
        setupPage.Visible = false
        if miniPlayer then miniPlayer.Visible = true end
        header.Visible = false
        header.Position = UDim2.new(0,0,0,0)
        header.Size = UDim2.new(1,0,0,42)
        headerPill.Position = UDim2.new(0,12,0,8)
        headerPill.Size = UDim2.fromOffset(112,26)
        headerPill.Visible = true
        for _, label in ipairs(headerTitleLabels) do label.Visible = false end
        minimizeButton.Position = UDim2.new(1,-82,0,6)
        exitButton.Position = UDim2.new(1,-42,0,6)
        minimizeButton.Text = ""
    else
        root.Size = savedWindowSize
        header.Visible = true
        rail.Visible = true
        if miniPlayer then miniPlayer.Visible = false end
        header.Position = UDim2.new(0,172,0,0)
        header.Size = UDim2.new(1,-172,0,78)
        headerPill.Position = UDim2.new(1,-222,0,26)
        headerPill.Size = UDim2.fromOffset(112,28)
        for _, label in ipairs(headerTitleLabels) do label.Visible = true end
        minimizeButton.Position = UDim2.new(1,-102,0,7)
        exitButton.Position = UDim2.new(1,-62,0,7)
        minimizeButton.Text = ""
        setPage("player")
    end
end
minimizeButton.MouseButton1Click:Connect(toggleMinimized)
exitButton.MouseButton1Click:Connect(function()
    root.Visible = false
    lyricsWindow.Visible = false
end)
uiNew("Frame", {Parent = root, Position = UDim2.new(0,172,0,77), Size = UDim2.new(1,-202,0,1), BackgroundColor3 = Color3.fromRGB(255,255,255), BackgroundTransparency = 0.93, BorderSizePixel = 0, ZIndex = 22})

playerPage = uiNew("Frame", {Name="PlayerPage", Parent=root, Position=UDim2.new(0,172,0,78), Size=UDim2.new(1,-172,1,-78), BackgroundTransparency=1, BorderSizePixel=0, Visible=true, ZIndex=22})
setupPage = uiNew("Frame", {Name="SetupPage", Parent=root, Position=UDim2.new(0,172,0,78), Size=UDim2.new(1,-172,1,-78), BackgroundTransparency=1, BorderSizePixel=0, Visible=false, ZIndex=22})

-- Separate, independently toggleable synchronized-lyrics window.
lyricsWindow = uiNew("Frame", {
    Name="RedlineLyricsWindow", Parent=gui, Visible=false, ClipsDescendants=true,
    AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0.5,535,0.5,0),
    Size=UDim2.fromOffset(420,520), BackgroundColor3=Color3.fromRGB(13,15,22),
    BackgroundTransparency=0.04, BorderSizePixel=0, ZIndex=60,
})
uiCorner(lyricsWindow,16)
uiStroke(lyricsWindow,Color3.fromRGB(255,65,91),0.42,1)
uiNew("UIGradient", {Parent=lyricsWindow, Rotation=135, Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(27,27,38)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(12,14,21)),
})})
lyricsHeader = uiNew("Frame", {Name="LyricsHeader", Parent=lyricsWindow, Position=UDim2.new(0,0,0,0), Size=UDim2.new(1,0,0,76), BackgroundTransparency=1, BorderSizePixel=0, ZIndex=61})
lyricsEyebrow = uiLabel(lyricsHeader,"REDLINE  /  LIVE LYRICS",9,UDim2.new(0,20,0,12),Enum.Font.GothamBold,Color3.fromRGB(255,86,108))
lyricsEyebrow.Size = UDim2.new(1,-90,0,15); lyricsEyebrow.ZIndex=62
lyricsTitle = uiLabel(lyricsHeader,"Lyrics",20,UDim2.new(0,20,0,29),Enum.Font.GothamBold,Color3.fromRGB(247,248,252))
lyricsTitle.Size = UDim2.new(1,-90,0,26); lyricsTitle.ZIndex=62
lyricsClose = uiButton(lyricsHeader,"×",UDim2.new(1,-46,0,13),UDim2.fromOffset(30,30),false,function() lyricsWindow.Visible=false end)
lyricsClose.Name="LyricsCloseButton"; lyricsClose.ZIndex=63; lyricsClose.TextSize=20
lyricsClose.BackgroundColor3=Color3.fromRGB(100,35,48)
lyricsTrack = uiLabel(lyricsWindow,"Play a song on Spotify to find its lyrics",12,UDim2.new(0,20,0,78),Enum.Font.GothamSemibold,Color3.fromRGB(198,202,215))
lyricsTrack.Size=UDim2.new(1,-40,0,38); lyricsTrack.TextWrapped=true; lyricsTrack.TextYAlignment=Enum.TextYAlignment.Top; lyricsTrack.ZIndex=62
lyricsStatus = uiLabel(lyricsWindow,"Waiting for Spotify…",10,UDim2.new(0,20,0,117),Enum.Font.Gotham,Color3.fromRGB(145,151,168))
lyricsStatus.Size=UDim2.new(1,-40,0,20); lyricsStatus.ZIndex=62
lyricsScroll = uiNew("ScrollingFrame", {
    Name="LyricsScroll", Parent=lyricsWindow, Position=UDim2.new(0,12,0,145),
    Size=UDim2.new(1,-24,1,-158), BackgroundColor3=Color3.fromRGB(20,22,31),
    BackgroundTransparency=0.18, BorderSizePixel=0, ScrollBarThickness=4,
    ScrollBarImageColor3=Color3.fromRGB(255,68,94), CanvasSize=UDim2.new(0,0,0,0),
    AutomaticCanvasSize=Enum.AutomaticSize.None, ZIndex=61,
})
uiCorner(lyricsScroll,10)
lyricsInner = uiNew("Frame", {Parent=lyricsScroll,Position=UDim2.new(0,0,0,0),Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=62})
uiNew("UIListLayout", {Parent=lyricsInner,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,7)})
uiNew("UIPadding", {Parent=lyricsInner,PaddingTop=UDim.new(0,16),PaddingBottom=UDim.new(0,20),PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)})
lyricsToggleButton = uiButton(rail,"♫     LYRICS",UDim2.new(0,10,0,202),UDim2.new(1,-20,0,38),false,function()
    if toggleLyricsPanel then toggleLyricsPanel() end
end)
lyricsToggleButton.Name="LyricsToggleButton"; lyricsToggleButton.TextXAlignment=Enum.TextXAlignment.Left; lyricsToggleButton.Text="     ♫     LYRICS"

setPage = function(which)
    local isPlayer = which == "player"
    playerPage.Visible = isPlayer; setupPage.Visible = not isPlayer
    playerNav.BackgroundColor3 = isPlayer and Color3.fromRGB(82,31,45) or Color3.fromRGB(25,28,37)
    setupNav.BackgroundColor3 = not isPlayer and Color3.fromRGB(82,31,45) or Color3.fromRGB(25,28,37)
    playerNav.BackgroundTransparency = isPlayer and 0.28 or 0.34
    setupNav.BackgroundTransparency = (not isPlayer) and 0.28 or 0.34
    headerPill.Visible = not windowMinimized
end
playerNav.MouseButton1Click:Connect(function() setPage("player") end)
setupNav.MouseButton1Click:Connect(function() setPage("setup") end)

-- Main player: compact smoked-glass cover, tactile controls, live progress and real recent-track selection.
uiLabel(playerPage, "NOW PLAYING", 9, UDim2.new(0,22,0,14), Enum.Font.GothamBold, Color3.fromRGB(133,139,155)).Size = UDim2.new(1,-44,0,16)
hero = uiNew("Frame", {Parent=playerPage, Position=UDim2.new(0,18,0,42), Size=UDim2.new(1,-36,0,500), BackgroundColor3=Color3.fromRGB(30,32,44), BackgroundTransparency=0.22, BorderSizePixel=0, ZIndex=23})
uiCorner(hero, 17); uiStroke(hero, Color3.fromRGB(126,129,145), 0.62, 1)
uiNew("UIGradient", {Parent=hero, Rotation=0, Color=ColorSequence.new(Color3.fromRGB(32,28,39),Color3.fromRGB(20,22,29))})
artGlow = uiNew("Frame", {Name="ArtworkAmbientGlow", Parent=hero, Position=UDim2.new(0,10,0,18), Size=UDim2.fromOffset(220,220), BackgroundColor3=Color3.fromRGB(255,54,87), BackgroundTransparency=0.84, BorderSizePixel=0, ZIndex=23})
uiCorner(artGlow, 18)
artShadow = uiNew("Frame", {Parent=hero, Position=UDim2.new(0,24,0,30), Size=UDim2.fromOffset(204,204), BackgroundColor3=Color3.fromRGB(0,0,0), BackgroundTransparency=0.42, BorderSizePixel=0, ZIndex=24})
uiCorner(artShadow, 13)
playerFallbackDisc = uiNew("Frame", {Name="ArtworkPlaceholder", Parent=hero, Position=UDim2.new(0,18,0,24), Size=UDim2.fromOffset(204,204), BackgroundColor3=Color3.fromRGB(34,36,47), BorderSizePixel=0, ZIndex=24})
uiCorner(playerFallbackDisc, 13)
uiNew("UIGradient", {Parent=playerFallbackDisc, Rotation=45, Color=ColorSequence.new(Color3.fromRGB(255,55,82),Color3.fromRGB(74,39,83))})
uiLabel(playerFallbackDisc, "♫", 76, UDim2.new(0,0,0,0), Enum.Font.GothamBlack, Color3.fromRGB(255,255,255), Enum.TextXAlignment.Center).Size = UDim2.fromScale(1,1)
albumArtImageObject = uiNew("ImageLabel", {Name="AlbumArtwork", Parent=hero, Position=UDim2.new(0,18,0,24), Size=UDim2.fromOffset(204,204), BackgroundColor3=Color3.fromRGB(28,29,37), BackgroundTransparency=0, BorderSizePixel=0, Image="", ScaleType=Enum.ScaleType.Crop, Visible=false, ZIndex=25})
uiCorner(albumArtImageObject, 13)
uiLabel(hero, "SPOTIFY CONNECTED PLAYER", 9, UDim2.new(0,248,0,19), Enum.Font.GothamBold, Color3.fromRGB(255,91,111)).Size = UDim2.new(1,-286,0,16)
trackLabel = uiLabel(hero, "Awful Things", 25, UDim2.new(0,248,0,40), Enum.Font.GothamBold, Color3.fromRGB(248,249,252))
trackLabel.Size = UDim2.new(1,-274,0,42); trackLabel.TextWrapped = false; trackLabel.TextTruncate = Enum.TextTruncate.AtEnd; trackLabel.TextYAlignment = Enum.TextYAlignment.Center
artistLabel = uiLabel(hero, "Lil Peep, Lil Tracy", 13, UDim2.new(0,248,0,84), Enum.Font.GothamMedium, Color3.fromRGB(176,181,196))
artistLabel.Size = UDim2.new(1,-274,0,22); artistLabel.TextWrapped = false
albumLabel = uiLabel(hero, "Come Over When You're Sober, Pt. 1", 11, UDim2.new(0,248,0,111), Enum.Font.GothamMedium, Color3.fromRGB(176,181,196))
albumLabel.Size = UDim2.new(1,-274,0,20)
playbackLabel = uiLabel(hero, "● WAITING FOR SPOTIFY", 10, UDim2.new(0,248,0,138), Enum.Font.GothamBold, Color3.fromRGB(255,91,111))
playbackLabel.Size = UDim2.new(1,-274,0,16)
-- Compact transport controls: these call Spotify's playback API after the user
-- grants the additional playback-control scope during a fresh authorization.
previousButton = uiButton(hero, "|◀", UDim2.new(0,248,0,166), UDim2.fromOffset(30,32), false, nil)
previousButton.Name = "PreviousTrackButton"; previousButton.TextSize = 13; previousButton.BackgroundTransparency = 0.22
playPauseButton = uiButton(hero, "Ⅱ", UDim2.new(0,287,0,162), UDim2.fromOffset(38,38), true, nil)
playPauseButton.Name = "PlayPauseButton"; playPauseButton.TextSize = 17; uiCorner(playPauseButton, 19); uiStroke(playPauseButton, Color3.fromRGB(255,143,157), 0.62, 1)
nextButton = uiButton(hero, "▶|", UDim2.new(0,333,0,166), UDim2.fromOffset(30,32), false, nil)
nextButton.Name = "NextTrackButton"; nextButton.TextSize = 13; nextButton.BackgroundTransparency = 0.22
-- Open-in-Spotify button removed; playback controls remain in the in-app player.
shuffleButton = uiButton(hero, "⇄", UDim2.new(0,248,0,203), UDim2.fromOffset(24,21), false, nil)
shuffleButton.Name = "ShuffleButton"; shuffleButton.TextSize = 13; shuffleButton.BackgroundTransparency = 0.34
repeatButton = uiButton(hero, "↻", UDim2.new(0,278,0,203), UDim2.fromOffset(24,21), false, nil)
repeatButton.Name = "RepeatButton"; repeatButton.TextSize = 13; repeatButton.BackgroundTransparency = 0.34
controlHint = uiLabel(hero, "SHUFFLE     REPEAT", 8, UDim2.new(0,308,0,203), Enum.Font.GothamMedium, Color3.fromRGB(121,128,145))
controlHint.Size = UDim2.new(0,130,0,20)
progressTrack = uiNew("Frame", {Parent=hero, Position=UDim2.new(0,248,0,231), Size=UDim2.new(1,-274,0,4), BackgroundColor3=Color3.fromRGB(57,60,72), BorderSizePixel=0, ZIndex=24})
uiCorner(progressTrack, 4)
customProgressFill = uiNew("Frame", {Parent=progressTrack, Size=UDim2.new(0,0,1,0), BackgroundColor3=Color3.fromRGB(255,55,82), BorderSizePixel=0, ZIndex=25})
uiCorner(customProgressFill, 4)
progressLabel = uiLabel(hero, "0:00", 10, UDim2.new(0,248,0,240), Enum.Font.GothamMedium, Color3.fromRGB(153,159,176)); progressLabel.Size=UDim2.new(0,100,0,18)
progressDurationLabel = uiLabel(hero, "0:00", 10, UDim2.new(1,-62,0,240), Enum.Font.GothamMedium, Color3.fromRGB(153,159,176), Enum.TextXAlignment.Right); progressDurationLabel.Size=UDim2.new(0,32,0,18)

-- Compact live playlist: populated from Spotify's real recently-played endpoint.
uiLabel(hero, "RECENTLY PLAYED", 8, UDim2.new(0,248,0,261), Enum.Font.GothamBold, Color3.fromRGB(133,139,155)).Size = UDim2.new(1,-274,0,13)
recentTrackRows = {}
for i = 1, 7 do
    local row = uiNew("TextButton", {Name="RecentTrackRow" .. i, Parent=hero, Position=UDim2.new(0,248,0,278 + (i-1)*29), Size=UDim2.new(1,-274,0,25), BackgroundColor3=Color3.fromRGB(36,37,48), BackgroundTransparency=1, BorderSizePixel=0, Text="", AutoButtonColor=false, ClipsDescendants=true, ZIndex=24})
    uiCorner(row, 7)
    local indicator = uiLabel(row, "▶", 9, UDim2.new(0,7,0,0), Enum.Font.GothamBold, i == 1 and Color3.fromRGB(255,54,87) or Color3.fromRGB(132,138,154), Enum.TextXAlignment.Center)
    indicator.Size = UDim2.new(0,15,1,0)
    local title = uiLabel(row, "Waiting for Spotify history…", 9, UDim2.new(0,28,0,0), Enum.Font.GothamMedium, Color3.fromRGB(213,215,224))
    title.Size = UDim2.new(1,-34,1,0); title.TextTruncate = Enum.TextTruncate.AtEnd
    row.MouseEnter:Connect(function() row.BackgroundTransparency = 0.30; row.BackgroundColor3 = Color3.fromRGB(72,35,47) end)
    row.MouseLeave:Connect(function() row.BackgroundTransparency = 1 end)
    recentTrackRows[i] = {button=row, title=title, indicator=indicator, item=nil}
end

-- Keep the connection label object for existing status-update logic, but hide
-- the old status/sync cards to reduce clutter beneath the player.
connectionLabel = uiLabel(playerPage, "● OFFLINE", 14, UDim2.new(0,0,0,0), Enum.Font.GothamBold, Color3.fromRGB(244,245,250))
connectionLabel.Visible = false
-- Refresh icon is drawn from basic UI shapes instead of a Unicode glyph,
-- since some executor fonts render the refresh character as an empty box.
refreshButton = uiButton(hero, "", UDim2.new(1,-34,0,10), UDim2.fromOffset(22,22), false, nil)
refreshButton.Name = "RefreshTrackButton"
refreshButton.Text = ""
refreshButton.BackgroundTransparency = 0.34
refreshButton.ClipsDescendants = false
refreshRing = uiNew("Frame", {
    Name = "RefreshRing", Parent = refreshButton,
    AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5),
    Size = UDim2.fromOffset(11,11), BackgroundTransparency = 1,
    BorderSizePixel = 0, ZIndex = refreshButton.ZIndex + 1,
})
uiCorner(refreshRing, 6)
uiStroke(refreshRing, Color3.fromRGB(235,238,246), 0.05, 1.35)
-- Make the clockwise arrowhead clearly visible (the previous tiny strokes
-- looked like a plain circle at this button size).
refreshArrowA = uiNew("Frame", {
    Name = "RefreshArrowA", Parent = refreshButton,
    Position = UDim2.new(0.5,3,0,2), Size = UDim2.fromOffset(7,2),
    Rotation = 18, BackgroundColor3 = Color3.fromRGB(255,255,255),
    BorderSizePixel = 0, ZIndex = refreshButton.ZIndex + 3,
})
refreshArrowB = uiNew("Frame", {
    Name = "RefreshArrowB", Parent = refreshButton,
    Position = UDim2.new(0.5,7,0,4), Size = UDim2.fromOffset(6,2),
    Rotation = 68, BackgroundColor3 = Color3.fromRGB(255,255,255),
    BorderSizePixel = 0, ZIndex = refreshButton.ZIndex + 3,
})

-- Setup screen has its own distinct form layout, not the old library controls.
uiLabel(setupPage, "CONNECT YOUR ACCOUNT", 10, UDim2.new(0,28,0,26), Enum.Font.GothamBold, Color3.fromRGB(255,91,111)).Size=UDim2.new(1,-56,0,18)
uiLabel(setupPage, "Spotify connection", 25, UDim2.new(0,28,0,48), Enum.Font.GothamBold, Color3.fromRGB(247,248,252)).Size=UDim2.new(1,-56,0,34)
uiLabel(setupPage, "Connect playback, control tracks, and load recent history. All UI and requests run client-side.", 12, UDim2.new(0,28,0,88), Enum.Font.Gotham, Color3.fromRGB(157,163,179)).Size=UDim2.new(1,-56,0,26)
setupCard = uiNew("Frame", {Parent=setupPage, Position=UDim2.new(0,28,0,132), Size=UDim2.new(1,-56,0,320), BackgroundColor3=Color3.fromRGB(30,32,44), BackgroundTransparency=0.16, BorderSizePixel=0, ZIndex=23})
uiCorner(setupCard, 15); uiStroke(setupCard, Color3.fromRGB(92,95,112), 0.48, 1)
uiLabel(setupCard, "01   AUTHORIZE SPOTIFY", 10, UDim2.new(0,22,0,20), Enum.Font.GothamBold, Color3.fromRGB(255,91,111)).Size=UDim2.new(1,-44,0,18)
loginButton = uiButton(setupCard, "OPEN SPOTIFY LOGIN  ↗", UDim2.new(0,22,0,51), UDim2.new(1,-44,0,42), true, nil)
uiLabel(setupCard, "02   PASTE THE REDIRECT URL", 10, UDim2.new(0,22,0,111), Enum.Font.GothamBold, Color3.fromRGB(255,91,111)).Size=UDim2.new(1,-44,0,18)
redirectBox = uiNew("TextBox", {Parent=setupCard, Position=UDim2.new(0,22,0,140), Size=UDim2.new(1,-44,0,42), BackgroundColor3=Color3.fromRGB(12,13,18), BorderSizePixel=0, Text="", PlaceholderText="Paste the full 127.0.0.1:8888/callback URL", PlaceholderColor3=Color3.fromRGB(111,117,133), TextColor3=Color3.fromRGB(242,244,249), Font=Enum.Font.Gotham, TextSize=11, ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Left, ClipsDescendants=true, ZIndex=24})
redirectBox.TextEditable = true
uiCorner(redirectBox, 8); uiStroke(redirectBox, Color3.fromRGB(70,74,88), 0.4, 1)
exchangeButton = uiButton(setupCard, "EXCHANGE URL / CONNECT", UDim2.new(0,22,0,195), UDim2.new(1,-44,0,40), false, nil)
disconnectButton = uiButton(setupCard, "DISCONNECT SPOTIFY", UDim2.new(0,22,0,247), UDim2.new(1,-44,0,34), false, nil)
authLabel = uiLabel(setupPage, "Status: not connected", 11, UDim2.new(0,28,0,472), Enum.Font.GothamMedium, Color3.fromRGB(158,164,180))
authLabel.Size=UDim2.new(1,-56,0,30); authLabel.TextWrapped=true

-- Compact floating mini-player shown by the minimize control. It mirrors the
-- live artwork, track metadata, status, progress, and uses the same Spotify API.
miniPlayer = uiNew("Frame", {
    Name="RedlineMiniPlayer", Parent=root, Position=UDim2.new(0,8,0,8),
    Size=UDim2.new(1,-16,0,74), BackgroundColor3=Color3.fromRGB(28,30,40),
    BackgroundTransparency=0.18, BorderSizePixel=0, Visible=false, ZIndex=26,
})
uiCorner(miniPlayer, 13); uiStroke(miniPlayer, Color3.fromRGB(130,133,149), 0.58, 1)
uiNew("UIGradient", {Parent=miniPlayer, Rotation=0, Color=ColorSequence.new(Color3.fromRGB(35,30,40), Color3.fromRGB(19,21,28))})
miniArtGlow = uiNew("Frame", {Parent=miniPlayer, Position=UDim2.new(0,7,0,10), Size=UDim2.fromOffset(54,54), BackgroundColor3=Color3.fromRGB(255,54,87), BackgroundTransparency=0.82, BorderSizePixel=0, ZIndex=27})
uiCorner(miniArtGlow, 10)
miniArt = uiNew("ImageLabel", {Name="MiniArtwork", Parent=miniPlayer, Position=UDim2.new(0,9,0,12), Size=UDim2.fromOffset(50,50), BackgroundColor3=Color3.fromRGB(39,35,47), BackgroundTransparency=0, BorderSizePixel=0, Image="", ScaleType=Enum.ScaleType.Crop, ZIndex=28})
uiCorner(miniArt, 9)
miniFallback = uiLabel(miniArt, "♫", 28, UDim2.new(0,0,0,0), Enum.Font.GothamBlack, Color3.fromRGB(255,255,255), Enum.TextXAlignment.Center)
miniFallback.Size = UDim2.fromScale(1,1)
miniTrackLabel = uiLabel(miniPlayer, "Awful Things", 13, UDim2.new(0,70,0,8), Enum.Font.GothamBold, Color3.fromRGB(248,249,252))
miniTrackLabel.Size = UDim2.new(1,-255,0,20); miniTrackLabel.TextTruncate = Enum.TextTruncate.AtEnd
miniArtistLabel = uiLabel(miniPlayer, "Lil Peep, Lil Tracy", 10, UDim2.new(0,70,0,29), Enum.Font.GothamMedium, Color3.fromRGB(174,180,195))
miniArtistLabel.Size = UDim2.new(1,-255,0,16); miniArtistLabel.TextTruncate = Enum.TextTruncate.AtEnd
miniPlaybackLabel = uiLabel(miniPlayer, "● WAITING FOR SPOTIFY", 7, UDim2.new(0,70,0,47), Enum.Font.GothamBold, Color3.fromRGB(255,91,111))
miniPlaybackLabel.Size = UDim2.new(1,-255,0,12); miniPlaybackLabel.TextTruncate = Enum.TextTruncate.AtEnd
miniProgressTrack = uiNew("Frame", {Parent=miniPlayer, Position=UDim2.new(0,70,1,-8), Size=UDim2.new(1,-275,0,3), BackgroundColor3=Color3.fromRGB(59,61,73), BorderSizePixel=0, ZIndex=28})
uiCorner(miniProgressTrack, 3)
miniProgressFill = uiNew("Frame", {Parent=miniProgressTrack, Size=UDim2.new(0,0,1,0), BackgroundColor3=Color3.fromRGB(255,54,87), BorderSizePixel=0, ZIndex=29})
uiCorner(miniProgressFill, 3)
miniPreviousButton = uiButton(miniPlayer, "|◀", UDim2.new(1,-184,0.5,-11), UDim2.fromOffset(24,24), false, nil)
miniPreviousButton.Name = "MiniPreviousTrackButton"; miniPreviousButton.TextSize = 11; miniPreviousButton.BackgroundTransparency = 0.2; miniPreviousButton.ZIndex = 30
miniPlayPauseButton = uiButton(miniPlayer, "Ⅱ", UDim2.new(1,-148,0.5,-13), UDim2.fromOffset(28,28), true, nil)
miniPlayPauseButton.Name = "MiniPlayPauseButton"; miniPlayPauseButton.TextSize = 13; miniPlayPauseButton.ZIndex = 30
uiCorner(miniPlayPauseButton, 16); uiStroke(miniPlayPauseButton, Color3.fromRGB(255,143,157), 0.62, 1)
miniNextButton = uiButton(miniPlayer, "▶|", UDim2.new(1,-112,0.5,-11), UDim2.fromOffset(24,24), false, nil)
miniNextButton.Name = "MiniNextTrackButton"; miniNextButton.TextSize = 11; miniNextButton.BackgroundTransparency = 0.2; miniNextButton.ZIndex = 30
miniRestoreButton = uiButton(miniPlayer, "↑", UDim2.new(1,-72,0,4), UDim2.fromOffset(26,22), false, nil)
miniRestoreButton.Name = "RestoreDashboardButton"; miniRestoreButton.BackgroundTransparency = 0.2; miniRestoreButton.ZIndex = 30
miniExitButton = uiButton(miniPlayer, "×", UDim2.new(1,-38,0,4), UDim2.fromOffset(26,22), false, nil)
miniExitButton.Name = "MiniExitButton"; miniExitButton.BackgroundColor3 = Color3.fromRGB(100,35,48); miniExitButton.ZIndex = 30
miniPreviousButton.MouseButton1Click:Connect(function() runPlaybackCommand("previous", "Previous track requested.") end)
miniPlayPauseButton.MouseButton1Click:Connect(function()
    local shouldPause = latestTrack and latestTrack.playing
    runPlaybackCommand(shouldPause and "pause" or "play", shouldPause and "Playback paused." or "Playback resumed.")
end)
miniNextButton.MouseButton1Click:Connect(function() runPlaybackCommand("next", "Next track requested.") end)
miniRestoreButton.MouseButton1Click:Connect(function()
    if windowMinimized and toggleMinimized then toggleMinimized() end
end)
miniExitButton.MouseButton1Click:Connect(function() root.Visible = false end)

-- Drag the compact player by its artwork or track text, leaving controls clickable.
MiniUserInputService = game:GetService("UserInputService")
miniDragging, miniDragInput, miniDragStart, miniStartPos = false, nil, nil, nil
function beginMiniDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        miniDragging = true
        miniDragStart = input.Position
        miniStartPos = root.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then miniDragging = false end
        end)
    end
end
for _, dragTarget in ipairs({miniArt, miniTrackLabel, miniArtistLabel, miniPlaybackLabel}) do
    dragTarget.InputBegan:Connect(beginMiniDrag)
    dragTarget.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            miniDragInput = input
        end
    end)
end
MiniUserInputService.InputChanged:Connect(function(input)
    if miniDragging and (input == miniDragInput or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - miniDragStart
        root.Position = UDim2.new(miniStartPos.X.Scale, miniStartPos.X.Offset + delta.X, miniStartPos.Y.Scale, miniStartPos.Y.Offset + delta.Y)
    end
end)
-- Keep the mini view synchronized with the existing live player without making
-- a second polling request or restarting any Spotify timers.
task.spawn(function()
    while root and root.Parent do
        pcall(function()
            if miniTrackLabel and trackLabel then miniTrackLabel.Text = trackLabel.Text end
            if miniArtistLabel and artistLabel then miniArtistLabel.Text = artistLabel.Text end
            if miniPlaybackLabel and playbackLabel then
                miniPlaybackLabel.Text = playbackLabel.Text
                miniPlaybackLabel.TextColor3 = playbackLabel.TextColor3
            end
            if miniArt and albumArtImageObject then
                miniArt.Image = albumArtImageObject.Image
                miniArt.Visible = albumArtImageObject.Visible and albumArtImageObject.Image ~= ""
                miniFallback.Visible = not miniArt.Visible
            end
            if miniProgressFill and customProgressFill then
                miniProgressFill.Size = UDim2.new(customProgressFill.Size.X.Scale, customProgressFill.Size.X.Offset, 1, 0)
            end
            if miniPlayPauseButton and playPauseButton then miniPlayPauseButton.Text = playPauseButton.Text end
        end)
        task.wait(0.2)
    end
end)

connectionLabelObject = boundLabel(connectionLabel)
trackLabelObject = boundLabel(trackLabel)
artistLabelObject = boundLabel(artistLabel)
albumLabelObject = boundLabel(albumLabel)
playbackLabelObject = boundLabel(playbackLabel)
progressLabelObject = boundLabel(progressLabel)
progressDurationLabelObject = boundLabel(progressDurationLabel)
progressBarLabelObject = { Set = function(_, value)
    local filled = 0
    local total = tostring(value):match("%[(%S*)")
    if total then filled = select(2, total:gsub("█", "")) end
    if customProgressFill then customProgressFill.Size = UDim2.new(math.clamp(filled / 20, 0, 1), 0, 1, 0) end
end }
customPlayerBuilt = true

-- Dragging and the established Right Shift toggle both operate on the new root.
UserInputService = game:GetService("UserInputService")
dragging, dragInput, dragStart, startPos = false, nil, nil, nil
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = root.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
header.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        root.Position = UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
    end
end)
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightShift then root.Visible = not root.Visible end
    if not processed and input.KeyCode == Enum.KeyCode.L and root.Visible and toggleLyricsPanel then toggleLyricsPanel() end
end)

CLIENT_ID = "4343170745f74d9fbe409fbc42a3b81a"
REDIRECT_URI = "http://127.0.0.1:8888/callback"
SCOPES = "user-read-private user-read-currently-playing user-read-playback-state user-read-recently-played user-modify-playback-state"
TOKEN_URL = "https://accounts.spotify.com/api/token"
NOW_PLAYING_URL = "https://api.spotify.com/v1/me/player/currently-playing"

pendingVerifier, pendingState = nil, nil
accessToken, refreshToken, tokenExpiresAt = nil, nil, nil
latestTrack = nil
polling = true

-- Persist Spotify's refresh token so the user does not need to repeat OAuth
-- and paste a callback URL every time the script is launched. This is stored
-- locally by the executor; anyone who can read the file may be able to use it.
TOKEN_CACHE_FILE = "RedlineSpotify_TokenCache.json"
function saveRefreshToken()
    if type(writefile) ~= "function" or not refreshToken or refreshToken == "" then return false end
    local ok = pcall(function()
        writefile(TOKEN_CACHE_FILE, HttpService:JSONEncode({refresh_token = refreshToken, client_id = CLIENT_ID}))
    end)
    return ok
end
function loadRefreshToken()
    if type(readfile) ~= "function" then return nil end
    local ok, raw = pcall(function()
        if type(isfile) == "function" and not isfile(TOKEN_CACHE_FILE) then return nil end
        return readfile(TOKEN_CACHE_FILE)
    end)
    if not ok or type(raw) ~= "string" or raw == "" then return nil end
    local decodedOk, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if decodedOk and type(data) == "table" and data.client_id == CLIENT_ID and type(data.refresh_token) == "string" and data.refresh_token ~= "" then
        return data.refresh_token
    end
    return nil
end
function clearSavedRefreshToken()
    if type(delfile) == "function" then pcall(delfile, TOKEN_CACHE_FILE) end
end

function notify(title, content)
    pcall(function()
        Library:Notify({Title = title, Content = tostring(content), Duration = 5})
    end)
end

function setLabel(labelObject, value)
    if not labelObject then return end
    local text = tostring(value)

    -- boundLabel() returns a Lua table wrapper with a Set method. Assigning
    -- labelObject.Text on that table silently creates a new table field, so
    -- the actual TextLabel never changes. Prefer Set() for wrappers, and use
    -- .Text for native Roblox TextLabels.
    local setMethod
    local okIndex, indexed = pcall(function() return labelObject.Set end)
    if okIndex then setMethod = indexed end
    if type(setMethod) == "function" then
        local ok = pcall(setMethod, labelObject, text)
        if ok then return end
    end

    pcall(function()
        labelObject.Text = text
    end)
end

function requestFunction()
    return (syn and syn.request) or http_request or request
end

function httpRequest(method, url, headers, body)
    local req = requestFunction()
    if type(req) ~= "function" then
        return nil, "Potassium does not expose request/http_request in this session."
    end
    local ok, response = pcall(req, {
        Url = url,
        URL = url,
        Method = method,
        Headers = headers or {},
        Body = body or "",
    })
    if not ok or type(response) ~= "table" then
        return nil, "HTTP request failed: " .. tostring(response)
    end
    local status = tonumber(response.StatusCode or response.Status or response.status_code or 0) or 0
    local responseBody = response.Body or response.body or ""
    return {status = status, body = responseBody, raw = response}
end

function urlEncode(value)
    return HttpService:UrlEncode(tostring(value or ""))
end

function formEncode(values)
    local out = {}
    for key, value in pairs(values) do
        table.insert(out, urlEncode(key) .. "=" .. urlEncode(value))
    end
    table.sort(out)
    return table.concat(out, "&")
end

function randomHexString()
    local parts = {}
    for i = 1, 3 do
        parts[i] = HttpService:GenerateGUID(false):gsub("[^%w]", "")
    end
    return table.concat(parts)
end

function getHashFunction()
    if crypt and type(crypt.hash) == "function" then return crypt.hash end
    if syn and syn.crypt and type(syn.crypt.hash) == "function" then return syn.crypt.hash end
    if crypto and type(crypto.hash) == "function" then return crypto.hash end
    return nil
end

function hexToBytes(hex)
    if type(hex) ~= "string" or #hex ~= 64 or not hex:match("^%x+$") then return nil end
    local bytes = {}
    for i = 1, #hex, 2 do
        bytes[#bytes + 1] = string.char(tonumber(hex:sub(i, i + 1), 16))
    end
    return table.concat(bytes)
end

function sha256Bytes(value)
    local hashFn = getHashFunction()
    if not hashFn then
        return nil, "SHA-256 is unavailable (expected crypt.hash or syn.crypt.hash)."
    end
    local attempts = {
        function() return hashFn(value, "sha256") end,
        function() return hashFn("sha256", value) end,
        function() return hashFn(value) end,
    }
    for _, attempt in ipairs(attempts) do
        local ok, result = pcall(attempt)
        if ok and type(result) == "string" then
            if #result == 32 then return result end
            local bytes = hexToBytes(result)
            if bytes then return bytes end
        end
    end
    return nil, "SHA-256 returned an unsupported format in this executor."
end

function base64Url(bytes)
    local encoded
    local ok, result = pcall(function() return HttpService:Base64Encode(bytes) end)
    if ok and type(result) == "string" then
        encoded = result
    elseif type(base64_encode) == "function" then
        local ok2, result2 = pcall(base64_encode, bytes)
        if ok2 and type(result2) == "string" then encoded = result2 end
    elseif crypt and type(crypt.base64) == "table" and type(crypt.base64.encode) == "function" then
        local ok2, result2 = pcall(crypt.base64.encode, bytes)
        if ok2 and type(result2) == "string" then encoded = result2 end
    end
    if not encoded then return nil, "Base64 encoding is unavailable in this executor." end
    return (encoded:gsub("=+$", ""):gsub("%+", "-"):gsub("/", "_"))
end

function jsonDecode(body)
    local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
    if ok and type(data) == "table" then return data end
    return nil
end

function parseQuery(url)
    local query = tostring(url):match("[?&](.*)") or ""
    query = query:match("^([^#]*)") or query
    local values = {}
    for pair in query:gmatch("[^&]+") do
        local key, value = pair:match("^([^=]+)=?(.*)$")
        if key then
            key = key:gsub("%+", " "):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
            value = (value or ""):gsub("%+", " "):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
            values[key] = value
        end
    end
    return values
end

function copyText(value)
    local copy = setclipboard or toclipboard or (syn and syn.write_clipboard)
    if type(copy) ~= "function" then return false end
    return pcall(copy, value)
end

function openBrowser(url)
    local ok = pcall(function() game:GetService("GuiService"):OpenBrowserWindow(url) end)
    if ok then return true end
    return copyText(url)
end

function buildAuthorizationUrl()
    local verifier = randomHexString() .. randomHexString()
    -- PKCE verifier must be 43–128 characters. Hex is URL-safe.
    verifier = verifier:sub(1, 96)
    local digest, hashError = sha256Bytes(verifier)
    if not digest then return nil, hashError end
    local challenge, base64Error = base64Url(digest)
    if not challenge then return nil, base64Error end
    pendingVerifier = verifier
    pendingState = randomHexString():sub(1, 40)
    local params = {
        client_id = CLIENT_ID,
        response_type = "code",
        redirect_uri = REDIRECT_URI,
        code_challenge_method = "S256",
        code_challenge = challenge,
        state = pendingState,
        scope = SCOPES,
    }
    return "https://accounts.spotify.com/authorize?" .. formEncode(params)
end

function parseErrorMessage(body, fallback)
    local data = jsonDecode(body or "")
    if data then
        if type(data.error_description) == "string" then return data.error_description end
        if type(data.error) == "table" and data.error.message then return tostring(data.error.message) end
        if type(data.error) == "string" then return data.error end
    end
    return fallback or "Spotify returned an unexpected response."
end

function exchangeCode(input)
    if not pendingVerifier or not pendingState then
        return false, "Click Open Spotify Login first, then keep this script running."
    end
    local fields = parseQuery(input)
    local code = fields.code
    if fields.error then return false, "Spotify login was not approved: " .. tostring(fields.error) end
    if not code or code == "" then
        -- Permit a code-only paste, but a full redirect URL is preferred for state validation.
        code = tostring(input):match("^%s*(.-)%s*$")
        if code:find("[?&#]", 1) then return false, "Could not find a code in that text. Paste the full redirected URL from your browser." end
    elseif fields.state and fields.state ~= pendingState then
        return false, "OAuth state did not match. Click Open Spotify Login and try again."
    elseif not fields.state then
        return false, "Paste the full redirected URL so Redline can verify the OAuth state."
    end
    if not code or code == "" or code:find("^http") then
        return false, "Paste the full redirected URL from the browser address bar."
    end
    setLabel(authLabel, "Login: exchanging authorization code…")
    local response, err = httpRequest("POST", TOKEN_URL, {
        ["Content-Type"] = "application/x-www-form-urlencoded",
        ["Accept"] = "application/json",
    }, formEncode({
        grant_type = "authorization_code",
        code = code,
        redirect_uri = REDIRECT_URI,
        client_id = CLIENT_ID,
        code_verifier = pendingVerifier,
    }))
    if not response then return false, err end
    local data = jsonDecode(response.body)
    if response.status < 200 or response.status >= 300 or not data or not data.access_token then
        return false, parseErrorMessage(response.body, "Token exchange failed (HTTP " .. tostring(response.status) .. ").")
    end
    accessToken = data.access_token
    refreshToken = data.refresh_token or refreshToken
    tokenExpiresAt = os.clock() + (tonumber(data.expires_in) or 3600) - 30
    saveRefreshToken()
    pendingVerifier, pendingState = nil, nil
    setLabel(connectionLabelObject, "Connection: Spotify connected")
    setLabel(authLabel, "Login: connected — polling every 1 second")
    return true, "Spotify connected."
end

function refreshAccessToken()
    if not refreshToken then return false, "No refresh token. Connect Spotify again." end
    local response, err = httpRequest("POST", TOKEN_URL, {
        ["Content-Type"] = "application/x-www-form-urlencoded",
        ["Accept"] = "application/json",
    }, formEncode({
        grant_type = "refresh_token",
        refresh_token = refreshToken,
        client_id = CLIENT_ID,
    }))
    if not response then return false, err end
    local data = jsonDecode(response.body)
    if response.status < 200 or response.status >= 300 or not data or not data.access_token then
        accessToken, refreshToken, tokenExpiresAt = nil, nil, nil
        return false, parseErrorMessage(response.body, "Token refresh failed. Connect again.")
    end
    accessToken = data.access_token
    refreshToken = data.refresh_token or refreshToken
    tokenExpiresAt = os.clock() + (tonumber(data.expires_in) or 3600) - 30
    saveRefreshToken()
    return true
end

function apiGet(url, retry)
    if not accessToken then return nil, "Connect Spotify first." end
    if tokenExpiresAt and os.clock() >= tokenExpiresAt then
        local ok, err = refreshAccessToken()
        if not ok then return nil, err end
    end
    local response, err = httpRequest("GET", url, {
        ["Authorization"] = "Bearer " .. accessToken,
        ["Accept"] = "application/json",
    })
    if not response then return nil, err end
    if response.status == 401 and retry ~= false then
        local ok, refreshError = refreshAccessToken()
        if not ok then return nil, refreshError end
        return apiGet(url, false)
    end
    if response.status == 204 then return {noTrack = true} end
    if response.status < 200 or response.status >= 300 then
        local detail = parseErrorMessage(response.body, "Spotify API returned an error.")
        -- Keep the numeric status in the returned message; callers use it to
        -- distinguish 401/403/429 without relying on Spotify's error wording.
        return nil, "HTTP " .. tostring(response.status) .. ": " .. tostring(detail)
    end
    local data = jsonDecode(response.body)
    if not data then return nil, "Spotify returned invalid JSON." end
    return data
end

lyricsLineLabels, lyricsLineTimes = {}, {}
lyricsRequestedKey, lyricsLoadedKey = nil, nil
lyricsObservedTrackKey = nil
lyricsCache = {}
lyricsCurrentLine = 0
lyricsGlowTween = nil
lyricsScrollTween = nil

-- Lyric accents follow the currently selected album palette, with a safe fallback.
function getLyricsAccent()
    return activeAlbumAccent or Color3.fromRGB(255, 92, 115)
end

function getLyricsAccentSecondary()
    return activeAlbumAccent2 or getLyricsAccent():Lerp(Color3.new(1, 1, 1), 0.16)
end

function updateLyricsAccent()
    local accent = getLyricsAccent()
    local accent2 = getLyricsAccentSecondary()
    if lyricsScroll and lyricsScroll.Parent then
        pcall(function() lyricsScroll.ScrollBarImageColor3 = accent end)
    end
    for index, rowLabel in ipairs(lyricsLineLabels or {}) do
        if rowLabel and rowLabel.Parent then
            local isActive = index == (lyricsCurrentLine or 0)
            local halo = rowLabel:FindFirstChild("RedlineLyricHalo")
            if halo then
                for _, copy in ipairs(halo:GetChildren()) do
                    if copy:IsA("TextLabel") then
                        copy.TextColor3 = accent
                        copy.TextStrokeColor3 = accent2
                    end
                end
            end
            if isActive then
                rowLabel.TextColor3 = accent
                rowLabel.TextStrokeColor3 = accent2
            end
        end
    end
end

-- Simulate a diffuse light bloom behind lyric text using several soft, offset
-- copies. The copies are children of each line label, so they do not affect the
-- UIListLayout or the lyric scrolling geometry.
function createLyricHalo(label)
    if not label or label:FindFirstChild("RedlineLyricHalo") then return end
    local halo = Instance.new("Folder")
    halo.Name = "RedlineLyricHalo"
    halo.Parent = label
    local offsets = {
        {-1,0},{1,0},{0,-1},{0,1},
    }
    for i, offset in ipairs(offsets) do
        local copy = Instance.new("TextLabel")
        copy.Name = "HaloLayer" .. tostring(i)
        copy.BackgroundTransparency = 1
        copy.BorderSizePixel = 0
        copy.Position = UDim2.new(0, offset[1], 0, offset[2])
        copy.Size = UDim2.new(1, 0, 1, 0)
        copy.Font = label.Font
        copy.Text = label.Text
        copy.TextSize = label.TextSize
        copy.TextColor3 = getLyricsAccent()
        copy.TextTransparency = 1
        copy.TextStrokeColor3 = getLyricsAccentSecondary()
        copy.TextStrokeTransparency = 1
        copy.TextWrapped = label.TextWrapped
        copy.TextXAlignment = label.TextXAlignment
        copy.TextYAlignment = label.TextYAlignment
        copy.TextTruncate = label.TextTruncate
        copy.RichText = label.RichText
        copy.ZIndex = math.max(1, label.ZIndex - 1)
        copy.Parent = halo
    end
end

function setLyricHalo(label, enabled, duration)
    if not label then return end
    local halo = label:FindFirstChild("RedlineLyricHalo")
    if not halo then return end
    for _, copy in ipairs(halo:GetChildren()) do
        if copy:IsA("TextLabel") then
            copy.Text = label.Text
            local goal = enabled and {TextTransparency = 0.86, TextStrokeTransparency = 0.84}
                or {TextTransparency = 1, TextStrokeTransparency = 1}
            pcall(function()
                TweenService:Create(copy, TweenInfo.new(duration or 0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
            end)
        end
    end
end

function lyricsTrackKey(track)
    if not track or not track.name then return nil end
    return tostring(track.id or (track.name .. "|" .. tostring(track.artist)))
end

toggleLyricsPanel = function()
    lyricsWindow.Visible = not lyricsWindow.Visible
    if lyricsWindow.Visible then
        local camera = workspace.CurrentCamera
        if camera then
            local maxOffset = camera.ViewportSize.X / 2 - 420
            lyricsWindow.Position = UDim2.new(0.5, math.max(-210, math.min(535, maxOffset)), 0.5, 0)
        end
        if latestTrack then
            task.spawn(function() if refreshLyricsForTrack then refreshLyricsForTrack(latestTrack, true) end end)
        else
            lyricsStatus.Text = "Connect Spotify and start a track."
        end
    end
end

function clearLyricsRows()
    if lyricsGlowTween then pcall(function() lyricsGlowTween:Cancel() end); lyricsGlowTween = nil end
    if lyricsScrollTween then pcall(function() lyricsScrollTween:Cancel() end); lyricsScrollTween = nil end
    for _, label in ipairs(lyricsLineLabels) do pcall(function() label:Destroy() end) end
    lyricsLineLabels, lyricsLineTimes = {}, {}
    lyricsCurrentLine = 0
    lyricsScroll.CanvasPosition = Vector2.new(0,0)
    lyricsScroll.CanvasSize = UDim2.new(0,0,0,0)
end

function drawLyricsLines(lines, synced)
    clearLyricsRows()
    for index, line in ipairs(lines) do
        local label = uiLabel(lyricsInner, line.text ~= "" and line.text or "♪", 16,
            UDim2.new(), Enum.Font.GothamSemibold, Color3.fromRGB(153,159,176), Enum.TextXAlignment.Center)
        label.Name = "LyricsLine" .. tostring(index)
        label.LayoutOrder = index
        label.Size = UDim2.new(1,0,0, line.text == "" and 12 or 34)
        label.TextWrapped = true
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.TextTruncate = Enum.TextTruncate.None
        -- Keep lyric text ready for a stronger glow when it becomes active.
        label.TextStrokeColor3 = getLyricsAccentSecondary()
        label.TextStrokeTransparency = 1
        label.ZIndex = 63
        createLyricHalo(label)
        table.insert(lyricsLineLabels,label)
        table.insert(lyricsLineTimes,synced and line.time or 0)
    end
    updateLyricsAccent()
    task.defer(function()
        if lyricsScroll and lyricsScroll.Parent then
            local contentHeight = 36
            for _, label in ipairs(lyricsLineLabels) do contentHeight = contentHeight + label.Size.Y.Offset + 7 end
            lyricsScroll.CanvasSize = UDim2.new(0,0,0,contentHeight)
        end
    end)
end

function parseSyncedLyrics(raw)
    local lines = {}
    for row in tostring(raw or ""):gmatch("[^\r\n]+") do
        local foundTime = false
        local lyric = row:gsub("%[%d%d:%d%d%.?%d*%]", "")
        for mm, ss in row:gmatch("%[(%d%d):(%d%d%.?%d*)%]") do
            foundTime = true
            local time = (tonumber(mm) or 0) * 60000 + (tonumber(ss) or 0) * 1000
            table.insert(lines,{time=time,text=lyric:match("^%s*(.-)%s*$") or ""})
        end
        if not foundTime and row:match("^%[offset:") then
            -- Ignore LRC metadata lines.
        end
    end
    table.sort(lines,function(a,b) return a.time < b.time end)
    return lines
end

refreshLyricsForTrack = function(track, force)
    if not track or not track.name then
        lyricsTrack.Text = "No track playing"
        lyricsStatus.Text = "Start a song on Spotify to load lyrics."
        lyricsObservedTrackKey = nil
        lyricsLoadedKey = nil
        lyricsRequestedKey = nil
        clearLyricsRows()
        return
    end
    local key = lyricsTrackKey(track)
    -- Treat a track change detected by Spotify polling the same as an in-game skip.
    -- Reset stale request state so a prior failed/slow lookup cannot block the new song.
    if lyricsObservedTrackKey ~= key then
        lyricsObservedTrackKey = key
        lyricsLoadedKey = nil
        lyricsRequestedKey = nil
        clearLyricsRows()
        lyricsStatus.Text = "Loading lyrics for new track…"
    end
    lyricsTrack.Text = track.name .. "  ·  " .. tostring(track.artist or "Unknown artist")
    if lyricsLoadedKey == key and lyricsCache[key] then return end
    if lyricsCache[key] then
        local cached = lyricsCache[key]
        lyricsStatus.Text = cached.status
        drawLyricsLines(cached.lines,cached.synced)
        lyricsLoadedKey = key
        return
    end
    if lyricsRequestedKey == key and not force then return end
    lyricsRequestedKey = key
    lyricsStatus.Text = "Looking up lyrics…"
    clearLyricsRows()
    task.spawn(function()
        local duration = (tonumber(track.duration) or 0) / 1000
        local url = "https://lrclib.net/api/get?track_name=" .. urlEncode(track.name) ..
            "&artist_name=" .. urlEncode(track.artist or "") ..
            "&album_name=" .. urlEncode(track.album or "") ..
            "&duration=" .. urlEncode(tostring(math.floor(duration + 0.5)))
        local response, requestErr = httpRequest("GET",url,{["Accept"]="application/json",["User-Agent"]="RedlineSpotifyNova/1.0"})
        if not response then
            if lyricsTrackKey(latestTrack) == key then lyricsStatus.Text = "Lyrics lookup failed: " .. tostring(requestErr or "network error") end
            return
        end
        if response.status < 200 or response.status >= 300 then
            -- The search endpoint can still find matches when exact metadata differs.
            local searchUrl = "https://lrclib.net/api/search?track_name=" .. urlEncode(track.name) .. "&artist_name=" .. urlEncode(track.artist or "")
            local searchResponse = httpRequest("GET",searchUrl,{["Accept"]="application/json",["User-Agent"]="RedlineSpotifyNova/1.0"})
            if searchResponse and searchResponse.status >= 200 and searchResponse.status < 300 then response = searchResponse else
                    if lyricsTrackKey(latestTrack) == key then lyricsStatus.Text = "No lyrics found for this version." end
                return
            end
        end
        local decodedOk, data = pcall(function() return HttpService:JSONDecode(response.body or "") end)
        if not decodedOk or type(data) ~= "table" then
            if lyricsTrackKey(latestTrack) == key then lyricsStatus.Text = "The lyrics service returned an invalid response." end
            return
        end
        if data[1] then data = data[1] end
        local syncedRaw = type(data.syncedLyrics) == "string" and data.syncedLyrics or ""
        local plainRaw = type(data.plainLyrics) == "string" and data.plainLyrics or ""
        local lines, synced = {}, false
        if syncedRaw ~= "" then
            lines = parseSyncedLyrics(syncedRaw)
            synced = #lines > 0
        end
        if #lines == 0 and plainRaw ~= "" then
            for line in (plainRaw .. "\n"):gmatch("(.-)\n") do table.insert(lines,{text=line}) end
        end
        if #lines == 0 then
            if lyricsTrackKey(latestTrack) == key then lyricsStatus.Text = "Lyrics aren't available for this track." end
            return
        end
        local statusText = synced and "SYNCED LYRICS  ·  current line follows playback" or "PLAIN LYRICS  ·  timestamps unavailable"
        lyricsCache[key] = {lines=lines,synced=synced,status=statusText}
        -- Requests can finish after Spotify has already moved to another track.
        -- Cache the result, but never replace the currently visible song's lyrics with stale data.
        if lyricsTrackKey(latestTrack) ~= key then return end
        lyricsLoadedKey = key
        lyricsStatus.Text = statusText
        drawLyricsLines(lines,synced)
    end)
end

-- Drag the independent lyrics window by its header.
lyricsDragging, lyricsDragStart, lyricsStartPos = false, nil, nil
lyricsHeader.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        lyricsDragging = true; lyricsDragStart = input.Position; lyricsStartPos = lyricsWindow.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then lyricsDragging = false end end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if lyricsDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - lyricsDragStart
        lyricsWindow.Position = UDim2.new(lyricsStartPos.X.Scale,lyricsStartPos.X.Offset+delta.X,lyricsStartPos.Y.Scale,lyricsStartPos.Y.Offset+delta.Y)
    end
end)

task.spawn(function()
    while gui and gui.Parent do
        task.wait(0.25)
        if lyricsWindow.Visible and lyricsLoadedKey and latestTrack and tostring(latestTrack.id or (latestTrack.name .. "|" .. tostring(latestTrack.artist))) == lyricsLoadedKey then
            local cached = lyricsCache[lyricsLoadedKey]
            if cached and cached.synced then
                local position = tonumber(latestTrack.progress) or 0
                if latestTrack.playing then position = position + math.max(0,(os.clock()-(latestTrack.syncedAt or os.clock()))*1000) end
                local current = 0
                for i, timestamp in ipairs(lyricsLineTimes) do
                    if timestamp and timestamp <= position then current = i else if timestamp and timestamp > position then break end end
                end
                if current > 0 and current ~= lyricsCurrentLine then
                    if lyricsGlowTween then pcall(function() lyricsGlowTween:Cancel() end); lyricsGlowTween = nil end
                    if lyricsScrollTween then pcall(function() lyricsScrollTween:Cancel() end); lyricsScrollTween = nil end
                    -- Reset EVERY non-current row, not just the immediately previous row.
                    -- Playback can jump across timestamps, which otherwise leaves older lines red.
                    for rowIndex, rowLabel in ipairs(lyricsLineLabels) do
                        if rowIndex ~= current and rowLabel and rowLabel.Parent then
                            rowLabel.TextColor3 = Color3.fromRGB(153,159,176)
                            rowLabel.TextStrokeColor3 = getLyricsAccentSecondary()
                            rowLabel.TextStrokeTransparency = 1
                            setLyricHalo(rowLabel, false, 0.12)
                        end
                    end
                    lyricsCurrentLine = current
                    local active = lyricsLineLabels[current]
                    if active then
                        active.TextColor3 = getLyricsAccent()
                        active.TextStrokeColor3 = getLyricsAccentSecondary()
                        active.TextStrokeTransparency = 0.72 -- soft edge; halo layers provide the bloom
                        setLyricHalo(active, true, 0.28)
                        pcall(function()
                            lyricsGlowTween = TweenService:Create(active, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                TextColor3 = getLyricsAccent(), TextStrokeTransparency = 0.58
                            })
                            lyricsGlowTween:Play()
                        end)
                        -- Center the active line smoothly; CanvasPosition is adjusted
                        -- only after layout settles so it doesn't jump back to the top.
                        task.defer(function()
                            if active.Parent and lyricsScroll and lyricsScroll.Parent then
                                local y = active.AbsolutePosition.Y - lyricsScroll.AbsolutePosition.Y + lyricsScroll.CanvasPosition.Y - lyricsScroll.AbsoluteSize.Y * 0.43
                                local maxY = math.max(0, lyricsScroll.CanvasSize.Y.Offset - lyricsScroll.AbsoluteSize.Y)
                                local target = Vector2.new(0, math.clamp(y, 0, maxY))
                                if lyricsScrollTween then pcall(function() lyricsScrollTween:Cancel() end) end
                                local ok, tween = pcall(function()
                                    return TweenService:Create(lyricsScroll, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CanvasPosition = target})
                                end)
                                if ok and tween then lyricsScrollTween = tween; tween:Play() end
                            end
                        end)
                    end
                end
            end
        end
    end
end)

function updateSpotifyProfile()
    if not accessToken then
        if profilePlan then profilePlan.Text = "Spotify · not connected" end
        return
    end
    task.spawn(function()
        local data = apiGet("https://api.spotify.com/v1/me")
        if not data then
            if profilePlan then profilePlan.Text = "Spotify · connected" end
            return
        end
        local product = type(data.product) == "string" and string.lower(data.product) or ""
        local planText
        if product == "premium" then
            planText = "Spotify Premium"
        elseif product == "free" then
            planText = "Spotify Free"
        elseif product ~= "" then
            planText = "Spotify · " .. product:gsub("^%l", string.upper)
        else
            planText = "Spotify · plan unavailable"
        end
        if profilePlan then profilePlan.Text = planText end
    end)
end

function apiCommand(method, endpoint, requestBody)
    if not accessToken then return false, "Connect Spotify first." end
    if tokenExpiresAt and os.clock() >= tokenExpiresAt then
        local refreshed, refreshError = refreshAccessToken()
        if not refreshed then return false, refreshError end
    end
    local function send()
        local headers = {
            ["Authorization"] = "Bearer " .. accessToken,
            ["Accept"] = "application/json",
        }
        if requestBody then headers["Content-Type"] = "application/json" end
        local body = requestBody and HttpService:JSONEncode(requestBody) or ""
        return httpRequest(method, "https://api.spotify.com/v1/me/player/" .. endpoint, headers, body)
    end
    local response, err = send()
    if not response then return false, err end
    if response.status == 401 then
        local refreshed, refreshError = refreshAccessToken()
        if not refreshed then return false, refreshError end
        response, err = send()
        if not response then return false, err end
    end
    if response.status < 200 or response.status >= 300 then
        return false, parseErrorMessage(response.body, "Spotify playback control failed (HTTP " .. tostring(response.status) .. ").")
    end
    return true
end

function msToClock(ms)
    ms = math.max(0, math.floor((tonumber(ms) or 0) / 1000))
    return string.format("%d:%02d", math.floor(ms / 60), ms % 60)
end

-- Cache each cover under a unique filename. Reusing one filename can make some
-- executors/Roblox asset caches keep displaying the previous song's image.
function artworkKey(value)
    local hash = 2166136261
    for i = 1, #value do hash = (hash * 16777619 + string.byte(value, i)) % 4294967291 end
    return string.format("%08x", hash)
end

function setAlbumArtwork(imageUrl)
    if not albumArtImageObject then return end
    if not imageUrl or imageUrl == "" then
        albumArtImageObject.Visible = false
        if playerFallbackDisc then playerFallbackDisc.Visible = true end
        currentAlbumArtUrl = nil
        albumArtLoadingUrl = nil
        return
    end
    if imageUrl == currentAlbumArtUrl and (albumArtImageObject.Visible or albumArtLoadingUrl == imageUrl) then return end
    currentAlbumArtUrl = imageUrl
    albumArtLoadingUrl = imageUrl
    -- Show the fallback while the next cover downloads; never leave the old cover up.
    albumArtImageObject.Visible = false
    if playerFallbackDisc then playerFallbackDisc.Visible = true end
    task.spawn(function()
        local ok, failure = pcall(function()
            local write = writefile
            local assetFn = getcustomasset or getsynasset
            if type(write) ~= "function" or type(assetFn) ~= "function" then
                error("Executor requires writefile and getcustomasset/getsynasset")
            end
            local response, err = httpRequest("GET", imageUrl, { ["Accept"] = "image/*" })
            if not response or response.status < 200 or response.status >= 300 or type(response.body) ~= "string" or #response.body < 100 then
                error(err or ("Album artwork download failed; HTTP " .. tostring(response and response.status or "no response")))
            end
            local path = "RedlineSpotify_AlbumArtwork_" .. artworkKey(imageUrl) .. ".jpg"
            write(path, response.body)
            local asset = assetFn(path)
            if type(asset) ~= "string" or asset == "" then error("Could not register album artwork asset") end
            if albumArtImageObject and albumArtImageObject.Parent and currentAlbumArtUrl == imageUrl then
                albumArtImageObject.Image = asset
                albumArtImageObject.Visible = true
                if playerFallbackDisc then playerFallbackDisc.Visible = false end
            end
        end)
        if albumArtLoadingUrl == imageUrl then albumArtLoadingUrl = nil end
        if not ok then
            if albumArtImageObject and albumArtImageObject.Parent and currentAlbumArtUrl == imageUrl then
                albumArtImageObject.Visible = false
                if playerFallbackDisc then playerFallbackDisc.Visible = true end
            end
            warn("[Redline] Album art update failed: " .. tostring(failure))
        end
    end)
end

-- Album-color experiment disabled for now; use the stable Redline accent.
activeAlbumAccent = Color3.fromRGB(255, 55, 82)
activeAlbumAccent2 = Color3.fromRGB(255, 100, 120)
activeAlbumArtPaletteUrl = nil
albumPaletteRequestSerial = 0
function applyAlbumPalette(_imageUrl, _trackId)
    -- Intentionally disabled while Recently Played is being repaired.
end

lastRecentRefreshAt = -120
recentHistoryRateLimitedUntil = 0
recentHistoryRequestInFlight = false
lastHistoryErrorKey = nil
-- This local cache records tracks Redline actually observed changing, including
-- songs skipped directly in Spotify (not just skips clicked inside Redline).
locallySkippedTracks = {}
recentHistoryApiItems = {}

function renderRecentTrackRows()
    local displayItems, seenUris = {}, {}
    for _, item in ipairs(locallySkippedTracks) do
        if item and item.uri and not seenUris[item.uri] then
            table.insert(displayItems, {track = item})
            seenUris[item.uri] = true
        end
    end
    for _, recent in ipairs(recentHistoryApiItems or {}) do
        local item = recent and recent.track
        if item and item.uri and not seenUris[item.uri] then
            table.insert(displayItems, recent)
            seenUris[item.uri] = true
        end
    end
    for i, entry in ipairs(recentTrackRows) do
        local recent = displayItems[i]
        local item = recent and recent.track
        entry.item = item
        if item then
            local isCurrent = latestTrack and latestTrack.uri and latestTrack.uri == item.uri
            entry.indicator.Text = isCurrent and "●" or "▶"
            entry.indicator.TextColor3 = isCurrent and Color3.fromRGB(255, 54, 87) or Color3.fromRGB(150, 156, 171)
            local artists = {}
            for _, artist in ipairs(item.artists or {}) do
                if artist.name then table.insert(artists, artist.name) end
            end
            entry.title.Text = (item.name or "Unknown track") .. "  ·  " .. table.concat(artists, ", ")
            entry.button.BackgroundTransparency = isCurrent and 0.58 or 1
            if isCurrent then entry.button.BackgroundColor3 = Color3.fromRGB(72, 35, 47) end
            entry.button.Active = true
        else
            entry.title.Text = "No more recent tracks"
            entry.indicator.Text = "—"
            entry.item = nil
            entry.button.Active = false
        end
    end
end

function rememberLocalHistoryTrack(track)
    if type(track) ~= "table" or type(track.uri) ~= "string" or track.uri == "" then return end
    local artists = {}
    for name in tostring(track.artist or "Unknown artist"):gmatch("[^,]+") do
        local trimmed = name:match("^%s*(.-)%s*$")
        if trimmed ~= "" then table.insert(artists, {name = trimmed}) end
    end
    local remembered = {
        name = track.name or "Unknown track",
        uri = track.uri,
        id = track.id,
        artists = artists,
        album = {name = track.album or "—"},
        external_urls = track.url and {spotify = track.url} or {},
    }
    -- Move duplicates to the front rather than allowing repeated polling to add copies.
    for i = #locallySkippedTracks, 1, -1 do
        local item = locallySkippedTracks[i]
        if item and item.uri == remembered.uri then table.remove(locallySkippedTracks, i) end
    end
    table.insert(locallySkippedTracks, 1, remembered)
    while #locallySkippedTracks > 7 do table.remove(locallySkippedTracks) end
    if renderRecentTrackRows then pcall(renderRecentTrackRows) end
end

function refreshRecentTracks(silent, force)
    local now = os.clock()
    if recentHistoryRequestInFlight then return false, "Recently Played refresh is already in progress." end
    if now < recentHistoryRateLimitedUntil then
        local remaining = math.max(1, math.ceil(recentHistoryRateLimitedUntil - now))
        if not silent then notify("Recently Played", "Spotify rate limit cooldown: wait " .. tostring(remaining) .. " seconds.") end
        return false, "Spotify history is rate limited; waiting before retry."
    end
    -- FIXED33's five-second cadence caused excessive calls. Keep background
    -- requests conservative; only the user's explicit Refresh action bypasses it.
    if not force and now - lastRecentRefreshAt < 120 then return true end

    lastRecentRefreshAt = now
    recentHistoryRequestInFlight = true
    local callOk, data, err = pcall(apiGet, "https://api.spotify.com/v1/me/player/recently-played?limit=20")
    recentHistoryRequestInFlight = false
    if not callOk then
        err = data
        data = nil
    end

    if not data or type(data.items) ~= "table" then
        local message = "History unavailable"
        local errText = tostring(err or "")
        local lowerErr = errText:lower()
        if errText:find("429", 1, true) or lowerErr:find("rate limit", 1, true) or lowerErr:find("too many requests", 1, true) then
            recentHistoryRateLimitedUntil = os.clock() + 180
            lastRecentRefreshAt = os.clock()
            message = "Spotify rate limited history — waiting 3 minutes"
        elseif errText:find("403", 1, true) then
            message = "History permission missing — disconnect and reconnect Spotify"
        elseif errText:find("401", 1, true) or lowerErr:find("connect spotify", 1, true) then
            message = "Spotify session expired — reconnect"
        elseif errText ~= "" then
            message = "History unavailable — " .. errText
        end
        -- Only replace empty rows with a status message; don't destroy already
        -- loaded tracks just because a transient refresh failed.
        for i, entry in ipairs(recentTrackRows) do
            if not entry.item then
                entry.title.Text = (i == 1 and message or "Recently played tracks appear here")
            end
        end
        local errorKey = tostring(err or message)
        if errorKey ~= lastHistoryErrorKey then
            warn("[Redline] Recently Played refresh failed: " .. errorKey)
            lastHistoryErrorKey = errorKey
        end
        if not silent then notify("Recently Played", message) end
        return false, err or message
    end

    lastHistoryErrorKey = nil
    recentHistoryApiItems = data.items
    renderRecentTrackRows()
    return true
end

function refreshNowPlaying(silent)
    local data, err = apiGet(NOW_PLAYING_URL)
    if not data then
        setLabel(connectionLabelObject, "Connection: sync error")
        if not silent then notify("Redline Spotify", err) end
        return false, err
    end
    if data.noTrack or not data.item then
        if latestTrack and latestTrack.uri then rememberLocalHistoryTrack(latestTrack) end
        latestTrack = nil
        if renderRecentTrackRows then pcall(renderRecentTrackRows) end
        task.spawn(function() if refreshLyricsForTrack then refreshLyricsForTrack(nil) end end)
        setAlbumArtwork(nil)
        setLabel(trackLabelObject, customPlayerBuilt and "Nothing playing" or "Track: Nothing playing")
        setLabel(artistLabelObject, customPlayerBuilt and "Start a song on Spotify" or "Artist: Start a song on Spotify")
        setLabel(albumLabelObject, "—")
        setLabel(playbackLabelObject, customPlayerBuilt and "● Spotify connected · no active track" or "Status: Spotify connected · no active track")
        if playPauseButton then playPauseButton.Text = "▶" end
        setLabel(progressLabelObject, customPlayerBuilt and "0:00" or "Progress: 0:00 / 0:00")
        if progressDurationLabelObject then setLabel(progressDurationLabelObject, "0:00") end
        setLabel(progressBarLabelObject, "[--------------------]")
        setLabel(connectionLabelObject, customPlayerBuilt and "● CONNECTED" or "Connection: Spotify connected")
        if headerPillText then headerPillText.Text = "● CONNECTED"; headerPillText.TextColor3 = Color3.fromRGB(118,230,167) end
        if railStatus then updateSpotifyProfile() end
        task.spawn(function() pcall(refreshRecentTracks, true) end)
        return true
    end
    local item = data.item
    if latestTrack and latestTrack.uri and item.uri and latestTrack.uri ~= item.uri then
        rememberLocalHistoryTrack(latestTrack)
    end
    local artists = {}
    for _, artist in ipairs(item.artists or {}) do
        if artist.name then table.insert(artists, artist.name) end
    end
    latestTrack = {
        name = item.name or "Unknown track",
        artist = table.concat(artists, ", "),
        album = (item.album and item.album.name) or "—",
        albumArt = (item.album and item.album.images and item.album.images[1] and item.album.images[1].url) or nil,
        url = item.external_urls and item.external_urls.spotify,
        progress = tonumber(data.progress_ms) or 0,
        duration = tonumber(item.duration_ms) or 0,
        uri = item.uri,
        id = item.id,
        playing = data.is_playing == true,
        syncedAt = os.clock(),
    }
    if renderRecentTrackRows then pcall(renderRecentTrackRows) end
    local lyricsTrackSnapshot = latestTrack
    task.spawn(function() if refreshLyricsForTrack then refreshLyricsForTrack(lyricsTrackSnapshot) end end)
    setLabel(trackLabelObject, (customPlayerBuilt and "" or "Track: ") .. latestTrack.name)
    setLabel(artistLabelObject, (customPlayerBuilt and "" or "Artist: ") .. (latestTrack.artist ~= "" and latestTrack.artist or "Unknown artist"))
    setLabel(albumLabelObject, latestTrack.album)
    setAlbumArtwork(latestTrack.albumArt)
    if latestTrack.albumArt and latestTrack.id then applyAlbumPalette(latestTrack.albumArt, latestTrack.id) end
    setLabel(playbackLabelObject, customPlayerBuilt and (latestTrack.playing and "▶  PLAYING" or "Ⅱ  PAUSED") or ("Status: " .. (latestTrack.playing and "PLAYING" or "PAUSED")))
    if playPauseButton then playPauseButton.Text = latestTrack.playing and "Ⅱ" or "▶" end
    if miniPlayPauseButton then miniPlayPauseButton.Text = latestTrack.playing and "Ⅱ" or "▶" end
    setLabel(connectionLabelObject, customPlayerBuilt and "● CONNECTED" or "Connection: Spotify connected")
    if headerPillText then headerPillText.Text = "● CONNECTED"; headerPillText.TextColor3 = Color3.fromRGB(118,230,167) end
    if railStatus then updateSpotifyProfile() end
    task.spawn(function() pcall(refreshRecentTracks, true) end)
    return true
end

-- Render a compact text progress bar and advance it locally between API polls.
-- Playback is polled every second; Spotify history refreshes in the background every 120 seconds.
function updateLiveProgress()
    if not accessToken or not latestTrack then return end
    local position = tonumber(latestTrack.progress) or 0
    local duration = tonumber(latestTrack.duration) or 0
    if latestTrack.playing then
        position = position + math.max(0, (os.clock() - (latestTrack.syncedAt or os.clock())) * 1000)
    end
    if duration > 0 then position = math.min(position, duration) end
    local fraction = duration > 0 and math.clamp(position / duration, 0, 1) or 0
    local elapsed = msToClock(position)
    local total = msToClock(duration)
    setLabel(progressLabelObject, customPlayerBuilt and elapsed or ("Progress: " .. elapsed .. " / " .. total))
    if progressDurationLabelObject then setLabel(progressDurationLabelObject, total) end
    local filled = math.floor(fraction * 20 + 0.5)
    if customPlayerBuilt and customProgressFill then
        local previousFraction = customProgressFill.Size.X.Scale
        if math.abs(previousFraction - fraction) >= 0.002 then
            customProgressFill.Size = UDim2.new(fraction, 0, 1, 0)
        end
    else
        setLabel(progressBarLabelObject, "[" .. string.rep("█", filled) .. string.rep("─", 20 - filled) .. "]")
    end
end

runPlaybackCommand = function(endpoint, successMessage)
    -- Capture the current track before a skip so it remains visible in Redline's
    -- recent list even when Spotify's history endpoint takes time to catch up.
    local trackBeforeSkip
    if (endpoint == "next" or endpoint == "previous") and latestTrack and latestTrack.uri then
        local artistNames = {}
        for name in tostring(latestTrack.artist or "Unknown artist"):gmatch("[^,]+") do
            local trimmed = name:match("^%s*(.-)%s*$")
            if trimmed ~= "" then table.insert(artistNames, {name = trimmed}) end
        end
        trackBeforeSkip = {
            name = latestTrack.name or "Unknown track",
            uri = latestTrack.uri,
            id = latestTrack.id,
            artists = artistNames,
            album = {name = latestTrack.album or "—"},
            external_urls = latestTrack.url and {spotify = latestTrack.url} or {},
        }
    end
    -- Spotify uses POST for skips and PUT for pause/resume.
    local method = (endpoint == "next" or endpoint == "previous") and "POST" or "PUT"
    local ok, err = apiCommand(method, endpoint)
    if not ok then
        local detail = tostring(err or "Spotify playback control failed.")
        if detail:find("404", 1, true) or detail:lower():find("device", 1, true) then
            detail = detail .. " Open Spotify on a device and start playback, then try again."
        elseif detail:find("403", 1, true) then
            detail = detail .. " Reconnect from Setup and approve playback-control permission."
        end
        notify("Redline Spotify", detail)
        task.delay(0.25, function() pcall(refreshNowPlaying, true) end)
        return
    end
    if trackBeforeSkip then
        table.insert(locallySkippedTracks, 1, trackBeforeSkip)
        while #locallySkippedTracks > 7 do table.remove(locallySkippedTracks) end
        if renderRecentTrackRows then pcall(renderRecentTrackRows) end
    end
    task.delay(0.25, function() pcall(refreshNowPlaying, true) end)
    if endpoint == "next" or endpoint == "previous" then
        -- One delayed history refresh only; multiple immediate calls caused 429s.
        task.delay(2.0, function()
            pcall(refreshNowPlaying, true)
            -- Do not force the recently-played endpoint here. The local skipped
            -- track cache updates immediately; Spotify history refreshes on cadence.
        end)
    end
    if successMessage then notify("Redline Spotify", successMessage) end
end
for _, entry in ipairs(recentTrackRows) do
    entry.button.MouseButton1Click:Connect(function()
        local item = entry.item
        if not item or type(item.uri) ~= "string" then
            notify("Redline Spotify", "That recent track is not available to play.")
            return
        end
        local ok, err = apiCommand("PUT", "play", {uris={item.uri}})
        if not ok then
            notify("Redline Spotify", tostring(err) .. " Make sure Spotify has an active playback device.")
            return
        end
        notify("Redline Spotify", "Playing " .. tostring(item.name or "selected track") .. ".")
        task.delay(0.6, function() pcall(refreshNowPlaying, true) end)
    end)
end
previousButton.MouseButton1Click:Connect(function() runPlaybackCommand("previous", "Previous track requested.") end)
nextButton.MouseButton1Click:Connect(function() runPlaybackCommand("next", "Next track requested.") end)
playPauseButton.MouseButton1Click:Connect(function()
    local shouldPause = latestTrack and latestTrack.playing
    runPlaybackCommand(shouldPause and "pause" or "play", shouldPause and "Playback paused." or "Playback resumed.")
end)
shuffleEnabled = false
repeatMode = "off"
shuffleButton.MouseButton1Click:Connect(function()
    shuffleEnabled = not shuffleEnabled
    local ok, err = apiCommand("PUT", "shuffle?state=" .. tostring(shuffleEnabled))
    if not ok then shuffleEnabled = not shuffleEnabled; notify("Redline Spotify", err .. " Reconnect from Setup if permissions changed."); return end
    shuffleButton.TextColor3 = shuffleEnabled and Color3.fromRGB(255,91,111) or Color3.fromRGB(248,249,252)
    notify("Redline Spotify", shuffleEnabled and "Shuffle enabled." or "Shuffle disabled.")
end)
repeatButton.MouseButton1Click:Connect(function()
    repeatMode = repeatMode == "off" and "context" or (repeatMode == "context" and "track" or "off")
    local ok, err = apiCommand("PUT", "repeat?state=" .. repeatMode)
    if not ok then repeatMode = repeatMode == "off" and "track" or (repeatMode == "track" and "context" or "off"); notify("Redline Spotify", err .. " Reconnect from Setup if permissions changed."); return end
    repeatButton.TextColor3 = repeatMode ~= "off" and Color3.fromRGB(255,91,111) or Color3.fromRGB(248,249,252)
    notify("Redline Spotify", "Repeat mode: " .. repeatMode .. ".")
end)

loginButton.MouseButton1Click:Connect(function()
    local url, err = buildAuthorizationUrl()
    if not url then
        setLabel(authLabel, "Login error: " .. tostring(err)); notify("Redline Spotify", err); return
    end
    copyText(url); openBrowser(url)
    setLabel(authLabel, "Approve Spotify, then paste the full redirected URL below.")
    notify("Redline Spotify", "Login opened or copied. Approve access, then paste the full callback URL.")
end)
exchangeButton.MouseButton1Click:Connect(function()
    local ok, message = exchangeCode(redirectBox.Text)
    if ok then
        notify("Redline Spotify", message)
        headerPillText.Text = "● CONNECTED"
        headerPillText.TextColor3 = Color3.fromRGB(118,230,167)
        updateSpotifyProfile()
        refreshNowPlaying(false)
    else
        setLabel(authLabel, "Login: " .. tostring(message)); notify("Redline Spotify", message)
    end
end)
refreshButton.MouseButton1Click:Connect(function()
    local ok = refreshNowPlaying(false)
    task.spawn(function()
        local callOk, historyOk, historyErr = pcall(refreshRecentTracks, false, true)
        if not callOk then
            warn("[Redline] Recently Played refresh crashed: " .. tostring(historyOk))
            notify("Recently Played", "Refresh failed. Check the Potassium console for details.")
        elseif not historyOk and historyErr then
            -- refreshRecentTracks already displays a useful status/notification.
        end
    end)
    if ok then notify("Redline Spotify", "Playback information refreshed.") end
end)
disconnectButton.MouseButton1Click:Connect(function()
    accessToken, refreshToken, tokenExpiresAt = nil, nil, nil
    clearSavedRefreshToken()
    latestTrack = nil
    setLabel(connectionLabelObject, "● OFFLINE")
    setLabel(trackLabelObject, "Nothing playing")
    setLabel(artistLabelObject, "Connect Spotify to begin")
    setLabel(albumLabelObject, "—")
    setLabel(playbackLabelObject, "● WAITING FOR SPOTIFY")
    setLabel(progressLabelObject, "0:00")
    setLabel(progressDurationLabelObject, "0:00")
    setAlbumArtwork(nil)
    if customProgressFill then customProgressFill.Size = UDim2.new(0,0,1,0) end
    setLabel(authLabel, "Status: disconnected")
    headerPillText.Text = "● DISCONNECTED"
    headerPillText.TextColor3 = Color3.fromRGB(180,185,198)
    if profilePlan then profilePlan.Text = "Spotify · not connected" end
    notify("Redline Spotify", "Disconnected for this script session.")
end)

task.spawn(function()
    while polling do
        task.wait(1)
        if accessToken then
            pcall(updateLiveProgress)
            local callOk, refreshed, refreshErr = pcall(refreshNowPlaying, true)
            -- Spotify can apply rolling-window rate limits. If the API reports 429,
            -- back off briefly instead of hammering the endpoint once per second.
            local errText = tostring(refreshErr or (not refreshed and refreshed) or "")
            if not callOk or errText:find("429") then task.wait(4) end
        end
    end
end)

-- Redline accent glow: use a soft multi-layer halo on ALL red accents.
-- Text glow is made from offset copies behind the original text; red surfaces
-- use several increasingly wide, transparent UIStroke layers for a softer bloom.
function isRedAccent(color)
    if typeof(color) ~= "Color3" then return false end
    return color.R > 0.62 and color.G < 0.48 and color.B < 0.62
        and color.R > color.G * 1.35 and color.R > color.B * 1.12
end

function ensureAccentTextHalo(guiObject)
    if guiObject:GetAttribute("RedlineTextHaloApplied") then
        local halo = guiObject:FindFirstChild("RedlineAccentTextHalo")
        if halo then
            for _, copy in ipairs(halo:GetChildren()) do
                if copy:IsA("TextLabel") then
                    copy.Text = guiObject.Text
                    copy.TextColor3 = activeAlbumAccent or Color3.fromRGB(255, 32, 68)
                    copy.TextStrokeColor3 = activeAlbumAccent2 or activeAlbumAccent or Color3.fromRGB(255, 24, 62)
                    copy.Font = guiObject.Font
                    copy.TextSize = guiObject.TextSize
                    copy.TextWrapped = guiObject.TextWrapped
                    copy.TextXAlignment = guiObject.TextXAlignment
                    copy.TextYAlignment = guiObject.TextYAlignment
                    copy.RichText = guiObject.RichText
                    copy.TextTruncate = guiObject.TextTruncate
                end
            end
        end
        return
    end
    guiObject:SetAttribute("RedlineTextHaloApplied", true)
    local halo = Instance.new("Folder")
    halo.Name = "RedlineAccentTextHalo"
    halo.Parent = guiObject
    local layers = {
        {x=-2,y=0,transparency=0.975,stroke=0.94},
        {x=2,y=0,transparency=0.975,stroke=0.94},
        {x=0,y=-2,transparency=0.975,stroke=0.94},
        {x=0,y=2,transparency=0.975,stroke=0.94},
    }
    for i, layer in ipairs(layers) do
        local copy = Instance.new("TextLabel")
        copy.Name = "RedlineTextGlow" .. tostring(i)
        copy.BackgroundTransparency = 1
        copy.BorderSizePixel = 0
        copy.Position = UDim2.new(0, layer.x, 0, layer.y)
        copy.Size = UDim2.new(1, 0, 1, 0)
        copy.Font = guiObject.Font
        copy.Text = guiObject.Text
        copy.TextSize = guiObject.TextSize
        copy.TextColor3 = activeAlbumAccent or Color3.fromRGB(255, 32, 68)
        copy.TextTransparency = layer.transparency
        copy.TextStrokeColor3 = activeAlbumAccent2 or activeAlbumAccent or Color3.fromRGB(255, 24, 62)
        copy.TextStrokeTransparency = layer.stroke
        copy.TextWrapped = guiObject.TextWrapped
        copy.TextXAlignment = guiObject.TextXAlignment
        copy.TextYAlignment = guiObject.TextYAlignment
        copy.TextTruncate = guiObject.TextTruncate
        copy.RichText = guiObject.RichText
        copy.ZIndex = math.max(1, guiObject.ZIndex - 1)
        copy.Parent = halo
    end
    -- Keep the original text crisp; the halo sits behind it.
    guiObject.TextStrokeColor3 = activeAlbumAccent2 or activeAlbumAccent or Color3.fromRGB(255, 45, 78)
    guiObject.TextStrokeTransparency = 0.97
end

function addRedGlow(guiObject)
    if not guiObject or not guiObject:IsA("GuiObject") then return end
    -- Never scan generated glow copies (or anything inside their folders). If a glow
    -- copy receives its own glow on each rescan, the effect compounds indefinitely.
    local ancestor = guiObject
    while ancestor and ancestor ~= root do
        local ancestorName = ancestor.Name or ""
        if ancestorName == "RedlineAccentTextHalo" or ancestorName == "RedlineLyricHalo"
            or string.match(ancestorName, "^RedlineTextGlow%d+$")
            or string.match(ancestorName, "^HaloLayer%d+$") then
            return
        end
        ancestor = ancestor.Parent
    end
    -- Lyrics have their own active-line halo; they are not part of the global accent scan.
    if string.match(guiObject.Name or "", "^LyricsLine%d+$") then return end
    local isText = guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") or guiObject:IsA("TextBox")
    local hasRedText = isText and (isRedAccent(guiObject.TextColor3) or guiObject:FindFirstChild("RedlineAccentTextHalo") ~= nil)
    local hasRedFill = guiObject.BackgroundTransparency < 0.98 and (isRedAccent(guiObject.BackgroundColor3) or guiObject:GetAttribute("RedlineAlbumThemed") == true)
    if hasRedText then ensureAccentTextHalo(guiObject) end
    if guiObject:GetAttribute("RedlineGlowApplied") then
        for _, child in ipairs(guiObject:GetChildren()) do
            if child:IsA("UIStroke") and (child.Name == "RedlineGlowOuter" or child.Name == "RedlineGlowMiddle" or child.Name == "RedlineGlowCore") then
                pcall(function() child.Color = activeAlbumAccent2 or activeAlbumAccent or child.Color end)
            end
        end
    end
    if hasRedFill and not guiObject:GetAttribute("RedlineGlowApplied") then
        guiObject:SetAttribute("RedlineGlowApplied", true)
        -- Multiple strokes create a soft halo rather than one sharp red outline.
        local strokeLayers = {
            {name="RedlineGlowOuter", thickness=4, transparency=0.97},
            {name="RedlineGlowMiddle", thickness=2, transparency=0.94},
            {name="RedlineGlowCore", thickness=1, transparency=0.88},
        }
        for _, layer in ipairs(strokeLayers) do
            local glow = Instance.new("UIStroke")
            glow.Name = layer.name
            glow.Color = activeAlbumAccent2 or activeAlbumAccent or Color3.fromRGB(255, 38, 72)
            glow.Thickness = layer.thickness
            glow.Transparency = layer.transparency
            glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            glow.LineJoinMode = Enum.LineJoinMode.Round
            glow.Parent = guiObject
        end
    end
end

function applyRedGlowTree(container)
    if not container then return end
    addRedGlow(container)
    for _, descendant in ipairs(container:GetDescendants()) do addRedGlow(descendant) end
end
applyRedGlowTree(root)
if lyricsWindow and lyricsWindow.Parent ~= root then applyRedGlowTree(lyricsWindow) end

-- New controls and accents are created dynamically, and some existing labels
-- change from neutral to red when selected. Rescan gently to catch those too.
task.spawn(function()
    while root and root.Parent do
        task.wait(2)
        pcall(function() applyRedGlowTree(root) end)
        if lyricsWindow and lyricsWindow.Parent and lyricsWindow.Parent ~= root then
            pcall(function() applyRedGlowTree(lyricsWindow) end)
        end
    end
end)

-- Reconnect silently from the cached refresh token when supported by this executor.
-- If the token is missing/expired/revoked, the normal login button remains available.
task.spawn(function()
    local savedToken = loadRefreshToken()
    if not savedToken then
        notify("Redline Spotify", "Loaded. Connect Spotify once; future launches can reuse the saved session.")
        return
    end
    refreshToken = savedToken
    setLabel(authLabel, "Login: restoring saved Spotify session…")
    local ok, err = refreshAccessToken()
    if ok then
        setLabel(connectionLabelObject, "Connection: Spotify connected")
        setLabel(authLabel, "Login: restored saved session")
        if headerPillText then headerPillText.Text = "● CONNECTED"; headerPillText.TextColor3 = Color3.fromRGB(118,230,167) end
        if railStatus then updateSpotifyProfile() end
        pcall(refreshNowPlaying, true)
        task.spawn(function() pcall(refreshRecentTracks, true, true) end)
        notify("Redline Spotify", "Saved Spotify session restored.")
    else
        setLabel(authLabel, "Login: saved session expired — reconnect")
        warn("[Redline] Could not restore saved Spotify session: " .. tostring(err))
    end
end)
