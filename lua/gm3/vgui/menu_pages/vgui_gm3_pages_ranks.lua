local PANEL = {}

lyx.RegisterFont("GM3.Button", "Open Sans SemiBold", 20)
lyx.RegisterFont("GM3.Ranks.Title", "Open Sans SemiBold", 22)

function PANEL:Init()
    self.ScrollPanel = vgui.Create("DScrollPanel", self)
    self.ScrollPanel:Dock(FILL)
    self.ScrollPanel:DockMargin(lyx.ScaleW(10), lyx.Scale(10), lyx.ScaleW(10), lyx.Scale(10))

    local HeaderCard = vgui.Create("DPanel", self.ScrollPanel)
    HeaderCard:Dock(TOP)
    HeaderCard:DockMargin(lyx.ScaleW(5), 0, lyx.ScaleW(5), lyx.Scale(6))
    HeaderCard:DockPadding(lyx.ScaleW(16), lyx.Scale(16), lyx.ScaleW(16), lyx.Scale(16))
    HeaderCard.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(18, 18, 18, 235))
        surface.SetDrawColor(255, 255, 255, 5)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local Title = vgui.Create("lyx.Label2", HeaderCard)
    Title:Dock(TOP)
    Title:SetFont("GM3.Ranks.Title")
    Title:SetTall(lyx.Scale(28))
    Title:SetText("Rank Management")

    local Subtitle = vgui.Create("lyx.Label2", HeaderCard)
    Subtitle:Dock(TOP)
    Subtitle:SetTall(lyx.Scale(18))
    Subtitle:SetText("Toggle panel access per rank or add new ranks below.")

    local AddRankWrapper = vgui.Create("DPanel", HeaderCard)
    AddRankWrapper:Dock(TOP)
    AddRankWrapper:SetTall(lyx.Scale(50))
    AddRankWrapper:DockMargin(0, lyx.Scale(8), 0, 0)
    AddRankWrapper.Paint = function() end

    self.RankEntry = vgui.Create("lyx.TextEntry2", AddRankWrapper)
    self.RankEntry:Dock(LEFT)
    self.RankEntry:SetWide(lyx.ScaleW(220))
    self.RankEntry:SetPlaceholderText("Rank Name")
    self.RankEntry:SetTall(lyx.Scale(40))

    local RankButton = vgui.Create("lyx.TextButton2", AddRankWrapper)
    RankButton:Dock(LEFT)
    RankButton:DockMargin(lyx.ScaleW(10), 0, 0, 0)
    RankButton:SetWide(lyx.ScaleW(140))
    RankButton:SetText("Add Rank")
    RankButton:SetFont("GM3.Button")
    RankButton:SetBackgroundColor(Color(68, 68, 68))

    RankButton.DoClick = function()
        local rank = self.RankEntry:GetValue()
        if rank == "" then
            chat.AddText(Color(38, 224, 94), "[GM3] ", Color(255, 255, 255), "Please enter a rank name!")
            return
        end

        net.Start("gm3:rank:add")
            net.WriteString(rank)
        net.SendToServer()

        self.RankEntry:SetValue("")
        gm3.Menu:Remove()
        gm3:SyncReopenMenu("Ranks")
    end

    HeaderCard:InvalidateLayout(true)
    HeaderCard:SizeToChildren(false, true)
    timer.Simple(0, function()
        if IsValid(HeaderCard) then
            HeaderCard:SizeToChildren(false, true)
        end
    end)

    local rankData = {}
    for k, v in pairs(gm3.ranks or {}) do
        local hasPanel = false
        if type(v) == "boolean" then
            hasPanel = v
        elseif type(v) == "table" and v.panel ~= nil then
            hasPanel = v.panel
        end

        table.insert(rankData, { name = k, hasPanel = hasPanel })
    end

    table.sort(rankData, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)

    if #rankData == 0 then
        local EmptyLabel = vgui.Create("lyx.Label2", self.ScrollPanel)
        EmptyLabel:Dock(TOP)
        EmptyLabel:DockMargin(lyx.ScaleW(5), lyx.Scale(15), lyx.ScaleW(5), 0)
        EmptyLabel:SetTall(lyx.Scale(24))
        EmptyLabel:SetFont("GM3.Components.Commands")
        EmptyLabel:SetText("No ranks available. Use the form above to create one.")
        EmptyLabel:SetContentAlignment(5)
    else
        local ListLabel = vgui.Create("lyx.Label2", self.ScrollPanel)
        ListLabel:Dock(TOP)
        ListLabel:DockMargin(lyx.ScaleW(5), lyx.Scale(12), lyx.ScaleW(5), lyx.Scale(2))
        ListLabel:SetTall(lyx.Scale(24))
        ListLabel:SetFont("GM3.Components.Commands")
        ListLabel:SetText("Existing Ranks")
    end

    for _, rank in ipairs(rankData) do
        local RankComponent = vgui.Create("GM3.Components.Rank", self.ScrollPanel)
        RankComponent:Dock(TOP)
        RankComponent:DockMargin(lyx.ScaleW(5), lyx.Scale(8), lyx.ScaleW(5), 0)
        RankComponent:SetTall(lyx.Scale(190))
        RankComponent:SetRank(rank.name, rank.hasPanel)
    end
end

function PANEL:SetPlayer(ply)
end

function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, lyx.Colors.Foreground)
end

vgui.Register("GM3.Pages.Ranks", PANEL)
