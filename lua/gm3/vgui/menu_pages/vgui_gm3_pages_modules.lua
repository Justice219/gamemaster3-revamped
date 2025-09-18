local PANEL = {}

--[[
    GM3 Modules Page - Complete UI Redesign
    Features:
    - Real-time search with instant filtering
    - Category-based organization
    - Sorting options
    - Modern card design with LYX theming
    - Module statistics
    - Smooth animations
]]

-- Register fonts for the modules page
surface.CreateFont("GM3.Modules.Title", {
    font = "Open Sans Bold",
    size = lyx.Scale(24),
    weight = 600,
    antialias = true
})

surface.CreateFont("GM3.Modules.Category", {
    font = "Open Sans SemiBold",
    size = lyx.Scale(18),
    weight = 500,
    antialias = true
})

surface.CreateFont("GM3.Modules.Stats", {
    font = "Open Sans",
    size = lyx.Scale(14),
    weight = 400,
    antialias = true
})

surface.CreateFont("GM3.Modules.Search", {
    font = "Open Sans",
    size = lyx.Scale(16),
    weight = 400,
    antialias = true
})

-- Module categories for better organization
local MODULE_CATEGORIES = {
    ["Visual"] = {
        icon = "👁",
        color = Color(156, 39, 176),
        modules = {"blackscreen", "blind", "drunk", "opsat", "screenshake", "confetti", "cutscene"}
    },
    ["Control"] = {
        icon = "🎮",
        color = Color(33, 150, 243),
        modules = {"freeze", "jetpack", "levitate", "lowgravity", "teleport", "clone"}
    },
    ["Communication"] = {
        icon = "💬",
        color = Color(76, 175, 80),
        modules = {"disablechat", "screenmessage", "screentimer"}
    },
    ["Environment"] = {
        icon = "🌍",
        color = Color(255, 152, 0),
        modules = {"disablelights", "clearlag", "weather"}
    },
    ["Utility"] = {
        icon = "🔧",
        color = Color(158, 158, 158),
        modules = {"playeresp", "example"}
    }
}

function PANEL:Init()
    -- Initialize module data
    self.Modules = {}
    self.FilteredModules = {}
    self.CurrentCategory = "All"
    self.CurrentSort = "name"
    self.SearchText = ""

    -- Process and categorize modules
    self:CategorizeModules()

    -- Create main container
    self.Container = vgui.Create("DPanel", self)
    self.Container:Dock(FILL)
    self.Container:DockMargin(lyx.Scale(5), lyx.Scale(5), lyx.Scale(5), lyx.Scale(5))
    self.Container.Paint = function(s, w, h)
        -- Subtle background
        local bgColor = lyx.Colors.Background or Color(30, 30, 30)
        draw.RoundedBox(8, 0, 0, w, h, ColorAlpha(bgColor, 50))
    end

    -- Create header panel
    self:CreateHeader()

    -- Create category tabs
    self:CreateCategoryTabs()

    -- Create module grid
    self:CreateModuleGrid()

    -- Create stats panel
    self:CreateStatsPanel()

    -- Initial population
    self:PopulateModules()
end

function PANEL:CategorizeModules()
    -- Categorize all modules
    for name, module in pairs(gm3.tools) do
        local category = "Utility" -- Default category

        -- Find appropriate category based on module name
        for catName, catData in pairs(MODULE_CATEGORIES) do
            for _, moduleName in ipairs(catData.modules) do
                if string.find(string.lower(name), string.lower(moduleName)) then
                    category = catName
                    break
                end
            end
        end

        -- Store module with category
        self.Modules[name] = {
            data = module,
            category = category,
            name = name
        }
    end

    self.FilteredModules = table.Copy(self.Modules)
end

function PANEL:CreateHeader()
    -- Header with search and controls
    self.Header = vgui.Create("DPanel", self.Container)
    self.Header:Dock(TOP)
    self.Header:SetTall(lyx.Scale(60))
    self.Header:DockMargin(0, 0, 0, lyx.Scale(10))
    self.Header.Paint = function(s, w, h)
        -- Header background with gradient
        local headerColor = lyx.Colors.Header or Color(45, 45, 45)
        draw.RoundedBox(8, 0, 0, w, h, headerColor)

        -- Bottom accent line
        local accentColor = lyx.Colors.Accent or Color(0, 150, 255)
        surface.SetDrawColor(accentColor)
        surface.DrawRect(0, h - 2, w, 2)
    end

    -- Search bar with icon
    self.SearchContainer = vgui.Create("DPanel", self.Header)
    self.SearchContainer:Dock(LEFT)
    self.SearchContainer:SetWide(lyx.ScaleW(400))
    self.SearchContainer:DockMargin(lyx.Scale(15), lyx.Scale(10), lyx.Scale(15), lyx.Scale(10))
    self.SearchContainer.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(255, 255, 255, 10))

        -- Search icon
        draw.SimpleText("🔍", "GM3.Modules.Search", lyx.Scale(10), h/2, Color(255, 255, 255, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    self.SearchBar = vgui.Create("DTextEntry", self.SearchContainer)
    self.SearchBar:Dock(FILL)
    self.SearchBar:DockMargin(lyx.Scale(35), lyx.Scale(5), lyx.Scale(10), lyx.Scale(5))
    self.SearchBar:SetFont("GM3.Modules.Search")
    self.SearchBar:SetTextColor(Color(255, 255, 255))
    self.SearchBar:SetCursorColor(lyx.Colors.Accent or Color(0, 150, 255))
    self.SearchBar:SetPlaceholderText("Search modules...")
    self.SearchBar:SetDrawBackground(false)
    self.SearchBar.OnChange = function(s)
        self.SearchText = s:GetValue()
        self:FilterModules()
    end

    -- Sort dropdown
    self.SortContainer = vgui.Create("DPanel", self.Header)
    self.SortContainer:Dock(RIGHT)
    self.SortContainer:SetWide(lyx.ScaleW(200))
    self.SortContainer:DockMargin(0, lyx.Scale(10), lyx.Scale(15), lyx.Scale(10))
    self.SortContainer.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(255, 255, 255, 10))
        draw.SimpleText("Sort by:", "GM3.Modules.Stats", lyx.Scale(10), h/2, Color(255, 255, 255, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    self.SortDropdown = vgui.Create("DComboBox", self.SortContainer)
    self.SortDropdown:Dock(FILL)
    self.SortDropdown:DockMargin(lyx.Scale(60), lyx.Scale(5), lyx.Scale(5), lyx.Scale(5))
    self.SortDropdown:SetFont("GM3.Modules.Stats")
    self.SortDropdown:SetTextColor(Color(255, 255, 255))
    self.SortDropdown:AddChoice("Name", "name", true)
    self.SortDropdown:AddChoice("Category", "category")
    self.SortDropdown:AddChoice("Author", "author")
    self.SortDropdown.OnSelect = function(s, index, value, data)
        self.CurrentSort = data
        self:SortModules()
    end
end

function PANEL:CreateCategoryTabs()
    -- Category filter tabs
    self.CategoryPanel = vgui.Create("DHorizontalScroller", self.Container)
    self.CategoryPanel:Dock(TOP)
    self.CategoryPanel:SetTall(lyx.Scale(50))
    self.CategoryPanel:DockMargin(0, 0, 0, lyx.Scale(10))
    self.CategoryPanel:SetOverlap(-lyx.Scale(5))

    -- All category button
    local allBtn = vgui.Create("DButton")
    allBtn:SetText("")
    allBtn:SetWide(lyx.ScaleW(100))
    allBtn.Category = "All"
    allBtn.Active = true
    allBtn.Paint = function(s, w, h)
        local accentColor = lyx.Colors.Accent or Color(0, 150, 255)
        local col = s.Active and accentColor or Color(255, 255, 255, 20)
        if s:IsHovered() and not s.Active then
            col = Color(255, 255, 255, 40)
        end

        draw.RoundedBox(6, 0, 0, w, h, col)
        draw.SimpleText("All", "GM3.Modules.Category", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    allBtn.DoClick = function(s)
        self:SelectCategory("All")
    end

    self.CategoryPanel:AddPanel(allBtn)
    self.CategoryButtons = {allBtn}

    -- Add category buttons
    for catName, catData in pairs(MODULE_CATEGORIES) do
        local btn = vgui.Create("DButton")
        btn:SetText("")
        btn:SetWide(lyx.ScaleW(140))
        btn.Category = catName
        btn.Active = false
        btn.Color = catData.color
        btn.Icon = catData.icon

        btn.Paint = function(s, w, h)
            local col = s.Active and s.Color or Color(255, 255, 255, 20)
            if s:IsHovered() and not s.Active then
                col = ColorAlpha(s.Color, 100)
            end

            draw.RoundedBox(6, 0, 0, w, h, col)

            -- Icon and text
            local text = s.Icon .. " " .. catName
            draw.SimpleText(text, "GM3.Modules.Category", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        btn.DoClick = function(s)
            self:SelectCategory(catName)
        end

        self.CategoryPanel:AddPanel(btn)
        table.insert(self.CategoryButtons, btn)
    end
end

function PANEL:CreateModuleGrid()
    -- Scrollable module grid
    self.ScrollPanel = vgui.Create("DScrollPanel", self.Container)
    self.ScrollPanel:Dock(FILL)
    self.ScrollPanel:DockMargin(0, 0, 0, 0)

    -- Custom scrollbar
    local scrollbar = self.ScrollPanel:GetVBar()
    scrollbar:SetWide(lyx.Scale(8))
    scrollbar.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255, 10))
    end
    scrollbar.btnGrip.Paint = function(s, w, h)
        local accentColor = lyx.Colors.Accent or Color(0, 150, 255)
        draw.RoundedBox(4, 0, 0, w, h, accentColor)
    end
    scrollbar.btnUp.Paint = function() end
    scrollbar.btnDown.Paint = function() end

    -- Grid layout
    self.ModuleGrid = vgui.Create("DIconLayout", self.ScrollPanel)
    self.ModuleGrid:Dock(FILL)
    self.ModuleGrid:SetSpaceX(lyx.Scale(15))
    self.ModuleGrid:SetSpaceY(lyx.Scale(15))
    self.ModuleGrid:SetBorder(lyx.Scale(15))
end

function PANEL:CreateStatsPanel()
    -- Statistics panel at bottom
    self.StatsPanel = vgui.Create("DPanel", self.Container)
    self.StatsPanel:Dock(BOTTOM)
    self.StatsPanel:SetTall(lyx.Scale(40))
    self.StatsPanel:DockMargin(0, lyx.Scale(10), 0, 0)
    self.StatsPanel.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(255, 255, 255, 5))

        -- Module count
        local text = string.format("Showing %d of %d modules", table.Count(self.FilteredModules), table.Count(self.Modules))
        draw.SimpleText(text, "GM3.Modules.Stats", lyx.Scale(15), h/2, Color(255, 255, 255, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- Category breakdown on the right
        if self.CurrentCategory == "All" then
            local x = w - lyx.Scale(15)
            for catName, catData in pairs(MODULE_CATEGORIES) do
                local count = 0
                for _, module in pairs(self.Modules) do
                    if module.category == catName then count = count + 1 end
                end

                -- Draw category dot and count
                local text = catData.icon .. " " .. count
                surface.SetFont("GM3.Modules.Stats")
                local tw, th = surface.GetTextSize(text)

                draw.SimpleText(text, "GM3.Modules.Stats", x - tw, h/2, catData.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                x = x - tw - lyx.Scale(20)
            end
        end
    end
end

function PANEL:SelectCategory(category)
    self.CurrentCategory = category

    -- Update button states
    for _, btn in ipairs(self.CategoryButtons) do
        btn.Active = (btn.Category == category)
    end

    -- Filter modules
    self:FilterModules()
end

function PANEL:FilterModules()
    self.FilteredModules = {}

    for name, module in pairs(self.Modules) do
        local include = true

        -- Category filter
        if self.CurrentCategory ~= "All" and module.category ~= self.CurrentCategory then
            include = false
        end

        -- Search filter
        if include and self.SearchText ~= "" then
            local searchLower = string.lower(self.SearchText)
            local nameMatch = string.find(string.lower(module.name), searchLower)
            local descMatch = module.data.description and string.find(string.lower(module.data.description), searchLower)

            if not (nameMatch or descMatch) then
                include = false
            end
        end

        if include then
            self.FilteredModules[name] = module
        end
    end

    self:SortModules()
end

function PANEL:SortModules()
    -- Sort filtered modules
    local sorted = {}
    for name, module in pairs(self.FilteredModules) do
        table.insert(sorted, module)
    end

    table.sort(sorted, function(a, b)
        if self.CurrentSort == "name" then
            return a.name < b.name
        elseif self.CurrentSort == "category" then
            if a.category == b.category then
                return a.name < b.name
            end
            return a.category < b.category
        elseif self.CurrentSort == "author" then
            local authorA = a.data.author or "Unknown"
            local authorB = b.data.author or "Unknown"
            if authorA == authorB then
                return a.name < b.name
            end
            return authorA < authorB
        end
        return a.name < b.name
    end)

    -- Rebuild grid
    self:PopulateModules(sorted)
end

function PANEL:PopulateModules(moduleList)
    -- Clear existing modules
    self.ModuleGrid:Clear()

    -- Use provided list or filtered modules
    local modules = moduleList or {}
    if not moduleList then
        for name, module in pairs(self.FilteredModules) do
            table.insert(modules, module)
        end
    end

    -- Create module cards
    for _, module in ipairs(modules) do
        local card = self:CreateModuleCard(module)
        self.ModuleGrid:Add(card)
    end
end

function PANEL:CreateModuleCard(module)
    local card = vgui.Create("DPanel")
    card:SetSize(lyx.ScaleW(280), lyx.Scale(320))
    card.Module = module
    card.Expanded = false

    -- Get category data
    local catData = MODULE_CATEGORIES[module.category] or {color = Color(158, 158, 158), icon = "🔧"}

    card.Paint = function(s, w, h)
        -- Card background with hover effect
        local alpha = s:IsHovered() and 40 or 25
        draw.RoundedBox(8, 0, 0, w, h, Color(255, 255, 255, alpha))

        -- Category color accent at top
        draw.RoundedBoxEx(8, 0, 0, w, lyx.Scale(4), catData.color, true, true, false, false)

        -- Border on hover
        if s:IsHovered() then
            surface.SetDrawColor(catData.color.r, catData.color.g, catData.color.b, 100)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
        end
    end

    -- Module name
    local nameLabel = vgui.Create("DLabel", card)
    nameLabel:SetPos(lyx.Scale(15), lyx.Scale(15))
    nameLabel:SetFont("GM3.Modules.Category")
    nameLabel:SetText(module.data.name or module.name)
    nameLabel:SetTextColor(Color(255, 255, 255))
    nameLabel:SizeToContents()

    -- Category badge
    local catBadge = vgui.Create("DPanel", card)
    catBadge:SetPos(card:GetWide() - lyx.ScaleW(90), lyx.Scale(15))
    catBadge:SetSize(lyx.ScaleW(75), lyx.Scale(25))
    catBadge.Paint = function(s, w, h)
        draw.RoundedBox(12, 0, 0, w, h, ColorAlpha(catData.color, 150))
        draw.SimpleText(catData.icon .. " " .. module.category, "GM3.Modules.Stats", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Description
    local descPanel = vgui.Create("DPanel", card)
    descPanel:SetPos(lyx.Scale(15), lyx.Scale(50))
    descPanel:SetSize(card:GetWide() - lyx.Scale(30), lyx.Scale(60))
    descPanel.Paint = function(s, w, h)
        -- Word wrap description - using RichText for better handling
        local desc = module.data.description or "No description available"
        -- Truncate long descriptions
        if #desc > 100 then
            desc = string.sub(desc, 1, 97) .. "..."
        end

        surface.SetFont("GM3.Modules.Stats")
        surface.SetTextColor(255, 255, 255, 180)

        -- Simple word wrap implementation
        local words = string.Explode(" ", desc)
        local line = ""
        local y = 0
        local lineHeight = lyx.Scale(16)

        for _, word in ipairs(words) do
            local testLine = line .. word .. " "
            local tw, th = surface.GetTextSize(testLine)

            if tw > w - lyx.Scale(10) and line ~= "" then
                draw.SimpleText(line, "GM3.Modules.Stats", 0, y, Color(255, 255, 255, 180), TEXT_ALIGN_LEFT)
                line = word .. " "
                y = y + lineHeight

                if y > h - lineHeight then break end -- Stop if we run out of space
            else
                line = testLine
            end
        end

        if line ~= "" and y <= h - lineHeight then
            draw.SimpleText(line, "GM3.Modules.Stats", 0, y, Color(255, 255, 255, 180), TEXT_ALIGN_LEFT)
        end
    end

    -- Author info
    if module.data.author then
        local authorLabel = vgui.Create("DLabel", card)
        authorLabel:SetPos(lyx.Scale(15), lyx.Scale(120))
        authorLabel:SetFont("GM3.Modules.Stats")
        authorLabel:SetText("By " .. module.data.author)
        authorLabel:SetTextColor(Color(255, 255, 255, 100))
        authorLabel:SizeToContents()
    end

    -- Arguments panel (if module has args)
    if module.data.args and table.Count(module.data.args) > 0 then
        local argsPanel = vgui.Create("DScrollPanel", card)
        argsPanel:SetPos(lyx.Scale(15), lyx.Scale(150))
        argsPanel:SetSize(card:GetWide() - lyx.Scale(30), lyx.Scale(100))
        argsPanel.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(0, 0, 0, 30))
        end

        local args = {}
        for k, v in pairs(module.data.args) do
            if v.type == "string" then
                local entry = vgui.Create("DTextEntry", argsPanel)
                entry:Dock(TOP)
                entry:DockMargin(lyx.Scale(5), lyx.Scale(5), lyx.Scale(5), 0)
                entry:SetTall(lyx.Scale(25))
                entry:SetPlaceholderText(v.name or v.def)
                entry:SetValue(v.def or "")
                entry:SetFont("GM3.Modules.Stats")
                args[k] = v.def

                entry.OnChange = function(s)
                    args[k] = s:GetValue()
                end
            elseif v.type == "number" then
                local entry = vgui.Create("DTextEntry", argsPanel)
                entry:Dock(TOP)
                entry:DockMargin(lyx.Scale(5), lyx.Scale(5), lyx.Scale(5), 0)
                entry:SetTall(lyx.Scale(25))
                entry:SetPlaceholderText(v.name or tostring(v.def))
                entry:SetValue(tostring(v.def or 0))
                entry:SetNumeric(true)
                entry:SetFont("GM3.Modules.Stats")
                args[k] = tonumber(v.def) or 0

                entry.OnChange = function(s)
                    args[k] = tonumber(s:GetValue()) or 0
                end
            elseif v.type == "boolean" then
                local check = vgui.Create("DCheckBoxLabel", argsPanel)
                check:Dock(TOP)
                check:DockMargin(lyx.Scale(5), lyx.Scale(5), lyx.Scale(5), 0)
                check:SetText(v.name or "Enabled")
                check:SetChecked(v.def)
                check:SetFont("GM3.Modules.Stats")
                args[k] = v.def

                check.OnChange = function(s, val)
                    args[k] = val
                end
            end
        end

        card.Arguments = args
    end

    -- Run button
    local runBtn = vgui.Create("DButton", card)
    runBtn:SetPos(lyx.Scale(15), card:GetTall() - lyx.Scale(45))
    runBtn:SetSize(card:GetWide() - lyx.Scale(30), lyx.Scale(35))
    runBtn:SetText("")
    runBtn.Paint = function(s, w, h)
        local col = catData.color
        if s:IsHovered() then
            col = ColorAlpha(col, 200)
        else
            col = ColorAlpha(col, 150)
        end

        draw.RoundedBox(6, 0, 0, w, h, col)
        draw.SimpleText("▶ Run Module", "GM3.Modules.Category", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    runBtn.DoClick = function()
        surface.PlaySound("buttons/button15.wav")

        -- Send module execution request
        net.Start("gm3:tool:run")
        net.WriteString(module.data.name)
        net.WriteTable(card.Arguments or {})
        net.SendToServer()

        -- Visual feedback
        runBtn:SetEnabled(false)
        timer.Simple(1, function()
            if IsValid(runBtn) then
                runBtn:SetEnabled(true)
            end
        end)

        -- Success notification
        notification.AddLegacy("Module '" .. module.data.name .. "' executed!", NOTIFY_GENERIC, 3)
    end

    return card
end

function PANEL:Paint(w, h)
    -- Main background
    local bgColor = lyx.Colors.Background or Color(30, 30, 30)
    draw.RoundedBox(8, 0, 0, w, h, bgColor)
end

vgui.Register("GM3.Pages.Modules", PANEL)