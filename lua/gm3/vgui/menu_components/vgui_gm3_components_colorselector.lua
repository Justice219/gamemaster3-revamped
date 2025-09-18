--[[
    GM3 Color Selector Component
    Provides a popup window for selecting colors with presets, RGB sliders, and visual feedback
]]

local PANEL = {}

-- Create fonts for the color selector
surface.CreateFont("GM3.ColorSelector.Title", {
    font = "Open Sans Bold",
    size = lyx.Scale(18),
    weight = 500,
    antialias = true
})

surface.CreateFont("GM3.ColorSelector.Label", {
    font = "Open Sans SemiBold",
    size = lyx.Scale(14),
    weight = 500,
    antialias = true
})

surface.CreateFont("GM3.ColorSelector.Value", {
    font = "Open Sans",
    size = lyx.Scale(12),
    weight = 400,
    antialias = true
})

-- Preset colors for quick selection
local presetColors = {
    -- Row 1 - Primary colors
    {name = "Red", color = Color(255, 0, 0)},
    {name = "Green", color = Color(0, 255, 0)},
    {name = "Blue", color = Color(0, 0, 255)},
    {name = "Yellow", color = Color(255, 255, 0)},
    {name = "Cyan", color = Color(0, 255, 255)},
    {name = "Magenta", color = Color(255, 0, 255)},

    -- Row 2 - Common colors
    {name = "White", color = Color(255, 255, 255)},
    {name = "Black", color = Color(0, 0, 0)},
    {name = "Gray", color = Color(128, 128, 128)},
    {name = "Orange", color = Color(255, 165, 0)},
    {name = "Purple", color = Color(128, 0, 128)},
    {name = "Brown", color = Color(139, 69, 19)},

    -- Row 3 - Faction colors
    {name = "Republic", color = Color(100, 150, 200)},
    {name = "Empire", color = Color(200, 50, 50)},
    {name = "Rebels", color = Color(50, 150, 50)},
    {name = "Neutral", color = Color(150, 150, 150)},
    {name = "CIS", color = Color(150, 100, 50)},
    {name = "Jedi", color = Color(50, 100, 200)},
}

function PANEL:Init()
    self:SetSize(lyx.ScaleW(500), lyx.Scale(450))
    self:SetTitle("Select Color")
    self:Center()
    self:MakePopup()

    -- Initialize with default color
    self.SelectedColor = Color(100, 100, 100)
    self.OriginalColor = self.SelectedColor

    -- Main container
    local container = vgui.Create("DPanel", self)
    container:Dock(FILL)
    container:DockMargin(lyx.Scale(10), lyx.Scale(10), lyx.Scale(10), lyx.Scale(10))
    container.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 100))
    end

    -- Color preview at the top
    self.PreviewPanel = vgui.Create("DPanel", container)
    self.PreviewPanel:Dock(TOP)
    self.PreviewPanel:SetTall(lyx.Scale(80))
    self.PreviewPanel:DockMargin(lyx.Scale(10), lyx.Scale(10), lyx.Scale(10), lyx.Scale(10))
    self.PreviewPanel.Paint = function(s, w, h)
        -- Draw checkerboard background for transparency
        local size = 10
        for x = 0, w, size do
            for y = 0, h, size do
                local color = ((x/size + y/size) % 2 == 0) and Color(100, 100, 100) or Color(150, 150, 150)
                surface.SetDrawColor(color)
                surface.DrawRect(x, y, size, size)
            end
        end

        -- Draw selected color
        draw.RoundedBox(4, 0, 0, w, h, self.SelectedColor)

        -- Draw border
        surface.SetDrawColor(255, 255, 255, 50)
        surface.DrawOutlinedRect(0, 0, w, h, 2)

        -- Draw color values as text
        draw.SimpleText(
            string.format("RGB(%d, %d, %d)", self.SelectedColor.r, self.SelectedColor.g, self.SelectedColor.b),
            "GM3.ColorSelector.Value",
            w/2, h/2,
            Color(255 - self.SelectedColor.r, 255 - self.SelectedColor.g, 255 - self.SelectedColor.b),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end

    -- Preset colors panel
    local presetLabel = vgui.Create("DLabel", container)
    presetLabel:Dock(TOP)
    presetLabel:SetTall(lyx.Scale(25))
    presetLabel:DockMargin(lyx.Scale(10), lyx.Scale(5), lyx.Scale(10), lyx.Scale(5))
    presetLabel:SetFont("GM3.ColorSelector.Label")
    presetLabel:SetText("Preset Colors:")
    presetLabel:SetTextColor(Color(255, 255, 255))

    local presetContainer = vgui.Create("DPanel", container)
    presetContainer:Dock(TOP)
    presetContainer:SetTall(lyx.Scale(120))
    presetContainer:DockMargin(lyx.Scale(10), 0, lyx.Scale(10), lyx.Scale(10))
    presetContainer.Paint = function() end

    -- Create preset color buttons
    local x, y = 0, 0
    local buttonSize = lyx.Scale(35)
    local spacing = lyx.Scale(5)
    local buttonsPerRow = 6

    for i, preset in ipairs(presetColors) do
        local colorBtn = vgui.Create("DButton", presetContainer)
        colorBtn:SetPos(x * (buttonSize + spacing), y * (buttonSize + spacing))
        colorBtn:SetSize(buttonSize, buttonSize)
        colorBtn:SetText("")
        colorBtn:SetTooltip(preset.name)

        colorBtn.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, preset.color)

            if s:IsHovered() then
                surface.SetDrawColor(255, 255, 255, 100)
                surface.DrawOutlinedRect(0, 0, w, h, 2)
            end
        end

        colorBtn.DoClick = function()
            self.SelectedColor = Color(preset.color.r, preset.color.g, preset.color.b)
            self:UpdateSliders()
        end

        x = x + 1
        if x >= buttonsPerRow then
            x = 0
            y = y + 1
        end
    end

    -- RGB Sliders
    local sliderPanel = vgui.Create("DPanel", container)
    sliderPanel:Dock(TOP)
    sliderPanel:SetTall(lyx.Scale(120))
    sliderPanel:DockMargin(lyx.Scale(10), lyx.Scale(10), lyx.Scale(10), lyx.Scale(10))
    sliderPanel.Paint = function() end

    -- Create RGB sliders
    self.Sliders = {}
    local sliderInfo = {
        {name = "Red", key = "r", color = Color(255, 0, 0)},
        {name = "Green", key = "g", color = Color(0, 255, 0)},
        {name = "Blue", key = "b", color = Color(0, 0, 255)}
    }

    for i, info in ipairs(sliderInfo) do
        local sliderContainer = vgui.Create("DPanel", sliderPanel)
        sliderContainer:Dock(TOP)
        sliderContainer:SetTall(lyx.Scale(35))
        sliderContainer:DockMargin(0, 0, 0, lyx.Scale(5))
        sliderContainer.Paint = function() end

        -- Label
        local label = vgui.Create("DLabel", sliderContainer)
        label:Dock(LEFT)
        label:SetWide(lyx.Scale(60))
        label:SetFont("GM3.ColorSelector.Label")
        label:SetText(info.name .. ":")
        label:SetTextColor(info.color)

        -- Slider
        local slider = vgui.Create("DNumSlider", sliderContainer)
        slider:Dock(FILL)
        slider:SetMin(0)
        slider:SetMax(255)
        slider:SetDecimals(0)
        slider:SetValue(self.SelectedColor[info.key])

        -- Style the slider
        slider.Label:SetVisible(false)
        slider.TextArea:SetFont("GM3.ColorSelector.Value")

        slider.OnValueChanged = function(s, value)
            self.SelectedColor[info.key] = math.floor(value)
            self.PreviewPanel:InvalidateLayout()
        end

        self.Sliders[info.key] = slider
    end

    -- Hex input
    local hexContainer = vgui.Create("DPanel", container)
    hexContainer:Dock(TOP)
    hexContainer:SetTall(lyx.Scale(35))
    hexContainer:DockMargin(lyx.Scale(10), lyx.Scale(5), lyx.Scale(10), lyx.Scale(10))
    hexContainer.Paint = function() end

    local hexLabel = vgui.Create("DLabel", hexContainer)
    hexLabel:Dock(LEFT)
    hexLabel:SetWide(lyx.Scale(60))
    hexLabel:SetFont("GM3.ColorSelector.Label")
    hexLabel:SetText("Hex:")
    hexLabel:SetTextColor(Color(255, 255, 255))

    self.HexEntry = vgui.Create("lyx.TextEntry2", hexContainer)
    self.HexEntry:Dock(FILL)
    self.HexEntry:SetFont("GM3.ColorSelector.Value")
    self.HexEntry:SetPlaceholderText("#RRGGBB")
    self.HexEntry:SetValue(string.format("#%02X%02X%02X", self.SelectedColor.r, self.SelectedColor.g, self.SelectedColor.b))

    self.HexEntry.OnChange = function(s)
        local hex = s:GetValue()
        if string.len(hex) == 7 and string.sub(hex, 1, 1) == "#" then
            local r = tonumber(string.sub(hex, 2, 3), 16)
            local g = tonumber(string.sub(hex, 4, 5), 16)
            local b = tonumber(string.sub(hex, 6, 7), 16)

            if r and g and b then
                self.SelectedColor = Color(r, g, b)
                self:UpdateSliders()
            end
        end
    end

    -- Bottom buttons
    local bottom = vgui.Create("DPanel", self)
    bottom:Dock(BOTTOM)
    bottom:SetTall(lyx.Scale(40))
    bottom:DockMargin(lyx.Scale(10), 0, lyx.Scale(10), lyx.Scale(10))
    bottom.Paint = function() end

    -- Cancel button
    local cancelBtn = vgui.Create("lyx.TextButton2", bottom)
    cancelBtn:Dock(LEFT)
    cancelBtn:SetWide(lyx.ScaleW(100))
    cancelBtn:SetText("Cancel")
    cancelBtn:SetFont("GM3.ColorSelector.Label")
    cancelBtn:SetBackgroundColor(Color(150, 50, 50))
    cancelBtn.DoClick = function()
        self:Close()
    end

    -- Reset button
    local resetBtn = vgui.Create("lyx.TextButton2", bottom)
    resetBtn:Dock(LEFT)
    resetBtn:SetWide(lyx.ScaleW(100))
    resetBtn:DockMargin(lyx.Scale(5), 0, 0, 0)
    resetBtn:SetText("Reset")
    resetBtn:SetFont("GM3.ColorSelector.Label")
    resetBtn:SetBackgroundColor(Color(100, 100, 100))
    resetBtn.DoClick = function()
        self.SelectedColor = Color(self.OriginalColor.r, self.OriginalColor.g, self.OriginalColor.b)
        self:UpdateSliders()
    end

    -- Select button
    self.SelectBtn = vgui.Create("lyx.TextButton2", bottom)
    self.SelectBtn:Dock(RIGHT)
    self.SelectBtn:SetWide(lyx.ScaleW(100))
    self.SelectBtn:SetText("Select")
    self.SelectBtn:SetFont("GM3.ColorSelector.Label")
    self.SelectBtn:SetBackgroundColor(Color(50, 150, 50))
    self.SelectBtn.DoClick = function()
        self:OnColorSelected(self.SelectedColor)
        self:Close()
    end
end

function PANEL:SetColor(color)
    -- Set initial color
    self.SelectedColor = Color(color.r, color.g, color.b)
    self.OriginalColor = Color(color.r, color.g, color.b)
    self:UpdateSliders()
end

function PANEL:UpdateSliders()
    -- Update slider values without triggering events
    if self.Sliders.r then
        self.Sliders.r:SetValue(self.SelectedColor.r)
    end
    if self.Sliders.g then
        self.Sliders.g:SetValue(self.SelectedColor.g)
    end
    if self.Sliders.b then
        self.Sliders.b:SetValue(self.SelectedColor.b)
    end

    -- Update hex value
    if self.HexEntry then
        self.HexEntry:SetValue(string.format("#%02X%02X%02X", self.SelectedColor.r, self.SelectedColor.g, self.SelectedColor.b))
    end

    -- Refresh preview
    if self.PreviewPanel then
        self.PreviewPanel:InvalidateLayout()
    end
end

function PANEL:OnColorSelected(color)
    -- Override this function to handle selection
end

function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, lyx.Colors.Background)
    draw.RoundedBoxEx(4, 0, 0, w, lyx.Scale(25), lyx.Colors.Header, true, true, false, false)
end

vgui.Register("GM3.ColorSelector", PANEL, "DFrame")