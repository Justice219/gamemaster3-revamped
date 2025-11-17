local PANEL = {}
gm3 = gm3 or {}
gm3.cutsceneHistory = gm3.cutsceneHistory or {}

surface.CreateFont("GM3.Cutscene.Header", {
    font = "Open Sans SemiBold",
    size = 24,
    weight = 600,
    antialias = true
})
surface.CreateFont("GM3.Cutscene.Sub", {
    font = "Open Sans",
    size = 18,
    weight = 500,
    antialias = true
})

local historyLimit = 8

local function addCard(parent, title, subtitle)
    local card = vgui.Create("DPanel", parent)
    card:Dock(TOP)
    card:DockMargin(lyx.ScaleW(5), 0, lyx.ScaleW(5), lyx.Scale(8))
    card:DockPadding(lyx.ScaleW(16), lyx.Scale(16), lyx.ScaleW(16), lyx.Scale(16))
    card.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(18, 18, 18, 235))
        surface.SetDrawColor(255, 255, 255, 5)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local header = vgui.Create("lyx.Label2", card)
    header:Dock(TOP)
    header:SetTall(lyx.Scale(30))
    header:SetFont("GM3.Cutscene.Header")
    header:SetText(title)

    if subtitle and subtitle ~= "" then
        local sub = vgui.Create("lyx.Label2", card)
        sub:Dock(TOP)
        sub:SetTall(lyx.Scale(20))
        sub:SetText(subtitle)
    end

    return card
end

function PANEL:Init()
    self.ScrollPanel = vgui.Create("DScrollPanel", self)
    self.ScrollPanel:Dock(FILL)
    self.ScrollPanel:DockMargin(lyx.ScaleW(10), lyx.Scale(10), lyx.ScaleW(10), lyx.Scale(10))

    self:BuildControlCard()
    self:BuildHistoryCard()
end

function PANEL:BuildControlCard()
    local card = addCard(self.ScrollPanel, "Cutscene Broadcast", "Share a synchronized Chromium YouTube cutscene to every player.")

    local info = vgui.Create("lyx.Label2", card)
    info:Dock(TOP)
    info:SetTall(lyx.Scale(20))
    info:SetText("Players must use Chromium x64. Recommended: YouTube ?si links or direct /watch URLs.")
    info:SetTextColor(Color(212, 180, 85))

    local urlLabel = vgui.Create("lyx.Label2", card)
    urlLabel:Dock(TOP)
    urlLabel:SetTall(lyx.Scale(18))
    urlLabel:SetFont("GM3.Cutscene.Sub")
    urlLabel:SetText("YouTube URL")

    self.URLField = vgui.Create("lyx.TextEntry2", card)
    self.URLField:Dock(TOP)
    self.URLField:SetTall(lyx.Scale(42))
    self.URLField:SetPlaceholderText("https://www.youtube.com/watch?v=xKmzRfkpQFA")
    self.URLField:SetValue(gm3.cutsceneHistory[1] or "")

    local HelperRow = vgui.Create("DPanel", card)
    HelperRow:Dock(TOP)
    HelperRow:SetTall(lyx.Scale(24))
    HelperRow:DockMargin(0, lyx.Scale(4), 0, 0)
    HelperRow.Paint = nil

    local helper = vgui.Create("lyx.Label2", HelperRow)
    helper:Dock(FILL)
    helper:SetTextColor(Color(190, 190, 190))
    helper:SetText("Tip: Use timestamped URLs (…?t=60s) to jump into the middle of a video.")

    local ButtonRow = vgui.Create("DPanel", card)
    ButtonRow:Dock(TOP)
    ButtonRow:SetTall(lyx.Scale(44))
    ButtonRow:DockMargin(0, lyx.Scale(10), 0, 0)
    ButtonRow.Paint = nil

    local playButton = vgui.Create("lyx.TextButton2", ButtonRow)
    playButton:Dock(LEFT)
    playButton:SetWide(lyx.ScaleW(200))
    playButton:SetText("Play Global Cutscene")
    playButton:SetBackgroundColor(Color(63, 61, 61))
    playButton.DoClick = function()
        self:SendCutscene(true)
    end

    local stopButton = vgui.Create("lyx.TextButton2", ButtonRow)
    stopButton:Dock(RIGHT)
    stopButton:SetWide(lyx.ScaleW(160))
    stopButton:SetText("Stop Global Cutscene")
    stopButton:SetBackgroundColor(Color(120, 35, 35))
    stopButton.DoClick = function()
        net.Start("gm3:panel:videoStop")
        net.SendToServer()
    end

    card:InvalidateLayout(true)
    card:SizeToChildren(false, true)
end

function PANEL:BuildHistoryCard()
    local card = addCard(self.ScrollPanel, "Recent Links", "Reuse previously broadcast cutscenes.")

    self.HistoryLayout = vgui.Create("DIconLayout", card)
    self.HistoryLayout:Dock(TOP)
    self.HistoryLayout:DockMargin(0, lyx.Scale(6), 0, 0)
    self.HistoryLayout:SetSpaceX(lyx.ScaleW(8))
    self.HistoryLayout:SetSpaceY(lyx.Scale(8))

    self:RefreshHistory()

    card:InvalidateLayout(true)
    card:SizeToChildren(false, true)
end

function PANEL:RefreshHistory()
    if not IsValid(self.HistoryLayout) then return end
    self.HistoryLayout:Clear()

    if #gm3.cutsceneHistory == 0 then
        local empty = self.HistoryLayout:Add("DPanel")
        empty:SetSize(lyx.ScaleW(260), lyx.Scale(70))
        empty.Paint = function(_, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(26, 26, 26, 220))
        end
        local lbl = vgui.Create("lyx.Label2", empty)
        lbl:Dock(FILL)
        lbl:SetContentAlignment(5)
        lbl:SetText("No links saved yet.")
        return
    end

    for _, url in ipairs(gm3.cutsceneHistory) do
        local item = self.HistoryLayout:Add("DPanel")
        item:SetSize(lyx.ScaleW(260), lyx.Scale(80))
        item:DockPadding(lyx.ScaleW(10), lyx.Scale(8), lyx.ScaleW(10), lyx.Scale(8))
        item.Paint = function(_, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(26, 26, 26, 220))
            surface.SetDrawColor(255, 255, 255, 4)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local snippet = string.len(url) > 38 and string.sub(url, 1, 35) .. "..." or url
        local label = vgui.Create("lyx.Label2", item)
        label:Dock(TOP)
        label:SetTall(lyx.Scale(18))
        label:SetText(snippet)
        label:SetTextColor(Color(190, 190, 190))

        local buttonRow = vgui.Create("DPanel", item)
        buttonRow:Dock(BOTTOM)
        buttonRow:SetTall(lyx.Scale(26))
        buttonRow.Paint = nil

        local loadBtn = vgui.Create("lyx.TextButton2", buttonRow)
        loadBtn:Dock(LEFT)
        loadBtn:SetWide(lyx.ScaleW(70))
        loadBtn:SetText("Load")
        loadBtn.DoClick = function()
            if IsValid(self.URLField) then
                self.URLField:SetText(url)
            end
        end

        local playBtn = vgui.Create("lyx.TextButton2", buttonRow)
        playBtn:Dock(LEFT)
        playBtn:DockMargin(lyx.ScaleW(6), 0, 0, 0)
        playBtn:SetWide(lyx.ScaleW(80))
        playBtn:SetText("Play")
        playBtn.DoClick = function()
            if IsValid(self.URLField) then
                self.URLField:SetText(url)
            end
            self:SendCutscene(true)
        end

        local forgetBtn = vgui.Create("lyx.TextButton2", buttonRow)
        forgetBtn:Dock(RIGHT)
        forgetBtn:SetWide(lyx.ScaleW(70))
        forgetBtn:SetText("Forget")
        forgetBtn:SetBackgroundColor(Color(120, 35, 35))
        forgetBtn.DoClick = function()
            self:RemoveHistoryEntry(url)
        end
    end
end

function PANEL:AddHistoryEntry(url)
    url = string.Trim(url or "")
    if url == "" then return end

    for idx, existing in ipairs(gm3.cutsceneHistory) do
        if existing == url then
            table.remove(gm3.cutsceneHistory, idx)
            break
        end
    end

    table.insert(gm3.cutsceneHistory, 1, url)
    while #gm3.cutsceneHistory > historyLimit do
        table.remove(gm3.cutsceneHistory)
    end
    self:RefreshHistory()
end

function PANEL:RemoveHistoryEntry(url)
    for idx = #gm3.cutsceneHistory, 1, -1 do
        if gm3.cutsceneHistory[idx] == url then
            table.remove(gm3.cutsceneHistory, idx)
        end
    end
    self:RefreshHistory()
end

function PANEL:SendCutscene(addToHistory)
    if not IsValid(self.URLField) then return end
    local url = string.Trim(self.URLField:GetValue() or "")
    if url == "" then
        url = "https://www.youtube.com/watch?v=xKmzRfkpQFA"
        self.URLField:SetText(url)
    end

    if addToHistory then
        self:AddHistoryEntry(url)
    end

    net.Start("gm3:panel:videoPlay")
        net.WriteString(url)
    net.SendToServer()
end

function PANEL:SetPlayer()
end

function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, lyx.Colors.Foreground)
end

vgui.Register("GM3.Pages.Cutscenes", PANEL)
