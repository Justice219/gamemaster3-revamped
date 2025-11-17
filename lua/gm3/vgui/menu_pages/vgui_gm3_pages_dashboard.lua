local PANEL = {}

surface.CreateFont("GM3.Dashboard.Header", {
    font = "Open Sans SemiBold",
    size = 28,
    weight = 600,
    antialias = true
})
surface.CreateFont("GM3.Dashboard.Sub", {
    font = "Open Sans",
    size = 18,
    weight = 500,
    antialias = true
})
surface.CreateFont("GM3.Dashboard.Metric", {
    font = "Open Sans SemiBold",
    size = 32,
    weight = 700,
    antialias = true
})

local function addCard(parent, title, subtitle, paint)
    local card = vgui.Create("DPanel", parent)
    card:Dock(TOP)
    card:DockMargin(lyx.ScaleW(5), 0, lyx.ScaleW(5), lyx.Scale(8))
    card:DockPadding(lyx.ScaleW(16), lyx.Scale(16), lyx.ScaleW(16), lyx.Scale(16))
    card.Paint = paint or function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(18, 18, 18, 235))
        surface.SetDrawColor(255, 255, 255, 5)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local header = vgui.Create("lyx.Label2", card)
    header:Dock(TOP)
    header:SetTall(lyx.Scale(30))
    header:SetFont("GM3.Dashboard.Header")
    header:SetText(title)

    if subtitle and subtitle ~= "" then
        local sub = vgui.Create("lyx.Label2", card)
        sub:Dock(TOP)
        sub:SetTall(lyx.Scale(20))
        sub:SetText(subtitle)
    end

    return card
end

local function metricColor()
    return Color(189, 88, 88)
end

function PANEL:Init()
    gm3 = gm3 or {}

    self.ScrollPanel = vgui.Create("DScrollPanel", self)
    self.ScrollPanel:Dock(FILL)
    self.ScrollPanel:DockMargin(lyx.ScaleW(10), lyx.Scale(10), lyx.ScaleW(10), lyx.Scale(10))

    self:BuildHeroCard()
    self:BuildStatsCard()
    self:BuildQuickActions()
    self:BuildUpdateCard()
end

function PANEL:BuildHeroCard()
    local hero = addCard(self.ScrollPanel, "Welcome to GM3: Revamped", "Event orchestration, cinematic control, and admin tooling in one place.", function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(14, 14, 14, 235))
        surface.SetDrawColor(metricColor())
        surface.DrawRect(0, 0, w, lyx.Scale(5))
    end)

    local body = vgui.Create("lyx.Label2", hero)
    body:Dock(TOP)
    body:SetTall(lyx.Scale(60))
    body:SetText("Use the sidebar to dive into tools, or jump to a tab with Quick Actions below. Need inspiration? Start with Commands + OPSAT to deliver briefing experiences.")
    body:SetWrap(true)

    hero:InvalidateLayout(true)
    hero:SizeToChildren(false, true)
end

function PANEL:BuildStatsCard()
    local statsCard = addCard(self.ScrollPanel, "System Snapshot", "Live count of loaded modules.")

    local metrics = vgui.Create("DIconLayout", statsCard)
    metrics:Dock(TOP)
    metrics:DockMargin(0, lyx.Scale(8), 0, 0)
    metrics:SetSpaceX(lyx.ScaleW(8))
    metrics:SetSpaceY(lyx.Scale(8))

    local data = {
        { label = "Tools", value = table.Count(gm3.tools or {}) },
        { label = "Commands", value = table.Count(gm3.commands or {}) },
        { label = "Ranks", value = table.Count(gm3.ranks or {}) },
        { label = "Presets", value = table.Count(gm3.opsatSavedPresets or {}) }
    }

    for _, metric in ipairs(data) do
        local panel = metrics:Add("DPanel")
        panel:SetSize(lyx.ScaleW(210), lyx.Scale(90))
        panel:DockPadding(lyx.ScaleW(12), lyx.Scale(12), lyx.ScaleW(12), lyx.Scale(12))
        panel.Paint = function(_, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(26, 26, 26, 230))
        end

        local valueLabel = vgui.Create("lyx.Label2", panel)
        valueLabel:Dock(TOP)
        valueLabel:SetTall(lyx.Scale(32))
        valueLabel:SetFont("GM3.Dashboard.Metric")
        valueLabel:SetText(metric.value)
        valueLabel:SetTextColor(metricColor())

        local nameLabel = vgui.Create("lyx.Label2", panel)
        nameLabel:Dock(TOP)
        nameLabel:SetTall(lyx.Scale(20))
        nameLabel:SetText(metric.label)
        nameLabel:SetTextColor(Color(200, 200, 200))
    end

    local metricRows = math.ceil(#data / 2)
    metrics:SetTall(metricRows * lyx.Scale(105))

    statsCard:InvalidateLayout(true)
    statsCard:SizeToChildren(false, true)
end

function PANEL:BuildQuickActions()
    local actionsCard = addCard(self.ScrollPanel, "Quick Actions", "Jump to common tabs.")

    local ButtonLayout = vgui.Create("DIconLayout", actionsCard)
    ButtonLayout:Dock(TOP)
    ButtonLayout:DockMargin(0, lyx.Scale(6), 0, 0)
    ButtonLayout:SetSpaceX(lyx.ScaleW(12))
    ButtonLayout:SetSpaceY(lyx.Scale(12))

    local function addAction(text, tabID, tabName)
        local btn = ButtonLayout:Add("lyx.TextButton2")
        btn:SetSize(lyx.ScaleW(180), lyx.Scale(44))
        btn:SetText(text)
        btn.DoClick = function()
            if gm3.Menu and gm3.Menu.ChangeTab then
                gm3.Menu:ChangeTab(tabID, tabName)
            end
        end
        return btn
    end

    local buttons = {
        {"Modules", "GM3.Pages.Modules", "Modules"},
        {"Commands", "GM3.Pages.Commands", "Commands"},
        {"OPSAT", "GM3.Pages.Opsat", "Opsat"},
        {"Cutscenes", "GM3.Pages.Cutscenes", "Cutscenes"},
        {"Ranks", "GM3.Pages.Ranks", "Ranks"},
        {"Server", "GM3.Pages.Server", "Server"}
    }

    for _, info in ipairs(buttons) do
        addAction(info[1], info[2], info[3])
    end

    local rows = math.ceil(#buttons / 3)
    ButtonLayout:SetTall(rows * lyx.Scale(62))

    actionsCard:InvalidateLayout(true)
    actionsCard:SizeToChildren(false, true)
end

function PANEL:BuildUpdateCard()
    local changelog = addCard(self.ScrollPanel, "Latest Highlights", "")

    local updates = {
        "Lyx 2.0 UI overhaul applied across Commands, Opsat, and Cutscenes.",
        "Saved OPSAT presets with persistent JSON storage.",
        "Command builder now has live previews, resets, and better validation.",
        "Ranks tab refreshed with cards, toggles, and action buttons."
    }

    for _, line in ipairs(updates) do
        local lbl = vgui.Create("lyx.Label2", changelog)
        lbl:Dock(TOP)
        lbl:SetTall(lyx.Scale(20))
        lbl:SetText("- " .. line)
    end

    changelog:InvalidateLayout(true)
    changelog:SizeToChildren(false, true)
end

function PANEL:SetPlayer()
end

function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, lyx.Colors.Foreground)
end

vgui.Register("GM3.Pages.Dashboard", PANEL)
