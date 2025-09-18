local PANEL = {}

--[[
    GM3 Modules Page - Redesigned with proper LYX theming
    Uses existing LYX components and matches the style of other panels
]]

-- Icon codes for module categories (imgur IDs)
local CATEGORY_ICONS = {
    ["All"] = "NwmR5Gc",       -- Dashboard icon
    ["Visual"] = "Y9BRhjr",     -- Eye/Opsat icon
    ["Control"] = "sy2ObLg",    -- Player icon
    ["Communication"] = "xkFWEkK", -- Commands icon
    ["Environment"] = "mrDq6Ar", -- Server icon
    ["Utility"] = "lOMzrJ6"     -- Modules icon (gears)
}

-- Module categories with consistent theming
local MODULE_CATEGORIES = {
    ["Visual"] = {
        modules = {"blackscreen", "blind", "drunk", "opsat", "screenshake", "confetti", "cutscene"}
    },
    ["Control"] = {
        modules = {"freeze", "jetpack", "levitate", "lowgravity", "teleport", "clone"}
    },
    ["Communication"] = {
        modules = {"disablechat", "screenmessage", "screentimer"}
    },
    ["Environment"] = {
        modules = {"disablelights", "clearlag", "weather"}
    },
    ["Utility"] = {
        modules = {"playeresp", "example"}
    }
}

surface.CreateFont("GM3.Modules.Title", {
    font = "Open Sans Bold",
    size = lyx.Scale(22),
    weight = 500,
    antialias = true
})
surface.CreateFont("GM3.Modules.Category", {
    font = "Open Sans SemiBold",
    size = lyx.Scale(16),
    weight = 500,
    antialias = true
})
surface.CreateFont("GM3.Modules.Normal", {
    font = "Open Sans",
    size = lyx.Scale(14),
    weight = 400,
    antialias = true
})

function PANEL:Init()
    self.Modules = {}
    self.FilteredModules = {}
    self.CurrentCategory = "All"
    self.SearchText = ""

    -- Categorize modules
    self:CategorizeModules()

    -- Main scroll panel matching other panels
    self.ScrollPanel = vgui.Create("DScrollPanel", self)
    self.ScrollPanel:Dock(FILL)
    self.ScrollPanel:DockMargin(lyx.ScaleW(10), lyx.Scale(10), lyx.ScaleW(10), lyx.Scale(10))

    -- Header section
    self:CreateHeader()

    -- Category buttons
    self:CreateCategoryButtons()

    -- Module list container
    self.ModuleContainer = vgui.Create("DPanel", self.ScrollPanel)
    self.ModuleContainer:Dock(TOP)
    self.ModuleContainer:SetTall(lyx.Scale(2000)) -- Will adjust based on content
    self.ModuleContainer.Paint = function() end

    -- Populate modules
    self:RefreshModules()
end

function PANEL:CategorizeModules()
    for name, module in pairs(gm3.tools) do
        local category = "Utility" -- Default category

        -- First check if the module has a category field
        if module.category then
            category = module.category
        else
            -- Fall back to name-based categorization
            for catName, catData in pairs(MODULE_CATEGORIES) do
                for _, moduleName in ipairs(catData.modules) do
                    if string.find(string.lower(name), string.lower(moduleName)) then
                        category = catName
                        break
                    end
                end
            end
        end

        self.Modules[name] = {
            data = module,
            category = category,
            name = name
        }
    end

    self.FilteredModules = table.Copy(self.Modules)
end

function PANEL:CreateHeader()
    -- Search container
    local searchContainer = vgui.Create("DPanel", self.ScrollPanel)
    searchContainer:Dock(TOP)
    searchContainer:SetTall(lyx.Scale(50))
    searchContainer:DockMargin(0, 0, 0, lyx.Scale(10))
    searchContainer.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(68, 68, 68, 100))
    end

    -- Search entry using LYX TextEntry2
    self.SearchEntry = vgui.Create("lyx.TextEntry2", searchContainer)
    self.SearchEntry:Dock(FILL)
    self.SearchEntry:DockMargin(lyx.Scale(10), lyx.Scale(10), lyx.Scale(10), lyx.Scale(10))
    self.SearchEntry:SetPlaceholderText("Search modules...")
    -- lyx.TextEntry2 doesn't have SetFont, it uses its own styling
    self.SearchEntry.OnChange = function(s)
        self.SearchText = s:GetValue()
        self:FilterModules()
    end

    -- Module count label
    self.CountLabel = vgui.Create("DLabel", self.ScrollPanel)
    self.CountLabel:Dock(TOP)
    self.CountLabel:DockMargin(lyx.Scale(5), 0, 0, lyx.Scale(10))
    self.CountLabel:SetFont("GM3.Modules.Normal")
    self.CountLabel:SetTextColor(Color(255, 255, 255, 180))
    self.CountLabel:SetText("Showing all modules")
end

function PANEL:CreateCategoryButtons()
    -- Category button container
    local catContainer = vgui.Create("DPanel", self.ScrollPanel)
    catContainer:Dock(TOP)
    catContainer:SetTall(lyx.Scale(50))
    catContainer:DockMargin(0, 0, 0, lyx.Scale(15))
    catContainer.Paint = function() end

    local x = 0

    -- All button
    local allBtn = vgui.Create("lyx.TextButton2", catContainer)
    allBtn:SetPos(x, 0)
    allBtn:SetSize(lyx.ScaleW(120), lyx.Scale(40))
    allBtn:SetText("All")
    allBtn:SetFont("GM3.Modules.Category")
    allBtn:SetBackgroundColor(Color(68, 68, 68))
    allBtn.Category = "All"
    allBtn.DoClick = function()
        self:SelectCategory("All")
    end

    x = x + lyx.ScaleW(125)
    self.CategoryButtons = {allBtn}

    -- Category buttons
    for catName, _ in pairs(MODULE_CATEGORIES) do
        local btn = vgui.Create("lyx.TextButton2", catContainer)
        btn:SetPos(x, 0)
        btn:SetSize(lyx.ScaleW(120), lyx.Scale(40))
        btn:SetText(catName)
        btn:SetFont("GM3.Modules.Category")
        btn:SetBackgroundColor(Color(50, 50, 50))
        btn.Category = catName
        btn.DoClick = function()
            self:SelectCategory(catName)
        end

        x = x + lyx.ScaleW(125)
        table.insert(self.CategoryButtons, btn)
    end

    -- Update first button as active
    self.CategoryButtons[1]:SetBackgroundColor(Color(100, 100, 100))
end

function PANEL:SelectCategory(category)
    self.CurrentCategory = category

    -- Update button colors
    for _, btn in ipairs(self.CategoryButtons) do
        if btn.Category == category then
            btn:SetBackgroundColor(Color(100, 100, 100))
        else
            btn:SetBackgroundColor(Color(50, 50, 50))
        end
    end

    self:FilterModules()
end

function PANEL:FilterModules()
    -- Clear filtered modules first
    self.FilteredModules = {}

    -- If showing all and no search, show everything
    if self.CurrentCategory == "All" and (not self.SearchText or self.SearchText == "") then
        self.FilteredModules = table.Copy(self.Modules)
    else
        -- Apply filters
        for name, module in pairs(self.Modules) do
            local include = true

            -- Category filter (skip if "All" is selected)
            if self.CurrentCategory ~= "All" and module.category ~= self.CurrentCategory then
                include = false
            end

            -- Search filter
            if include and self.SearchText and self.SearchText ~= "" then
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
    end

    self:RefreshModules()
end

function PANEL:RefreshModules()
    -- Clear existing modules
    if self.ModuleContainer then
        for _, child in ipairs(self.ModuleContainer:GetChildren()) do
            child:Remove()
        end
    end

    -- Update count
    local count = table.Count(self.FilteredModules)
    local total = table.Count(self.Modules)
    self.CountLabel:SetText(string.format("Showing %d of %d modules", count, total))

    -- Create module panels
    local y = 0
    for name, module in pairs(self.FilteredModules) do
        local modPanel = self:CreateModulePanel(module, self.ModuleContainer)
        modPanel:SetPos(0, y)
        y = y + modPanel:GetTall() + lyx.Scale(10)
    end

    -- Adjust container height
    self.ModuleContainer:SetTall(y)
end

function PANEL:CreateModulePanel(module, parent)
    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(parent:GetWide() - lyx.Scale(10), lyx.Scale(200))

    -- Count arguments to determine panel height
    local argCount = module.data.args and table.Count(module.data.args) or 0
    local panelHeight = lyx.Scale(120 + (argCount * 35))
    panel:SetTall(panelHeight)

    panel.Paint = function(s, w, h)
        -- Background matching other components
        draw.RoundedBox(4, 0, 0, w, h, Color(94, 88, 88, 50))

        -- Category indicator line
        local catIcon = CATEGORY_ICONS[module.category]
        if catIcon then
            -- Draw icon if available
            lyx.DrawImgur(lyx.Scale(10), lyx.Scale(10), lyx.Scale(24), lyx.Scale(24), catIcon, Color(255, 255, 255, 100))
        end
    end

    -- Module name
    local nameLabel = vgui.Create("DLabel", panel)
    nameLabel:SetPos(lyx.Scale(45), lyx.Scale(10))
    nameLabel:SetFont("GM3.Modules.Title")
    nameLabel:SetText(module.data.name or module.name)
    nameLabel:SetTextColor(Color(255, 255, 255))
    nameLabel:SizeToContents()

    -- Category label
    local catLabel = vgui.Create("DLabel", panel)
    catLabel:SetPos(panel:GetWide() - lyx.ScaleW(150), lyx.Scale(10))
    catLabel:SetFont("GM3.Modules.Normal")
    catLabel:SetText(module.category)
    catLabel:SetTextColor(Color(255, 255, 255, 150))
    catLabel:SizeToContents()

    -- Description
    local desc = vgui.Create("DLabel", panel)
    desc:SetPos(lyx.Scale(15), lyx.Scale(40))
    desc:SetSize(panel:GetWide() - lyx.Scale(30), lyx.Scale(40))
    desc:SetFont("GM3.Modules.Normal")
    desc:SetText(module.data.description or "No description")
    desc:SetTextColor(Color(255, 255, 255, 180))
    desc:SetWrap(true)
    desc:SetAutoStretchVertical(true)

    -- Arguments
    local args = {}
    local argY = lyx.Scale(85)

    if module.data.args then
        for k, v in pairs(module.data.args) do
            if v.type == "string" then
                local entry = vgui.Create("lyx.TextEntry2", panel)
                entry:SetPos(lyx.Scale(15), argY)
                entry:SetSize(panel:GetWide() - lyx.ScaleW(150), lyx.Scale(30))
                entry:SetPlaceholderText(v.name or v.def or "Text")
                entry:SetValue(v.def or "")
                args[k] = v.def or ""

                entry.OnChange = function(s)
                    args[k] = s:GetValue()
                end

                argY = argY + lyx.Scale(35)

            elseif v.type == "number" then
                local entry = vgui.Create("lyx.TextEntry2", panel)
                entry:SetPos(lyx.Scale(15), argY)
                entry:SetSize(panel:GetWide() - lyx.ScaleW(150), lyx.Scale(30))
                entry:SetPlaceholderText(v.name or tostring(v.def) or "Number")
                entry:SetValue(tostring(v.def or 0))
                entry:SetNumeric(true)
                args[k] = tonumber(v.def) or 0

                entry.OnChange = function(s)
                    args[k] = tonumber(s:GetValue()) or 0
                end

                argY = argY + lyx.Scale(35)

            elseif v.type == "boolean" then
                local check = vgui.Create("lyx.Checkbox2", panel)
                check:SetPos(lyx.Scale(15), argY)
                check:SetSize(lyx.Scale(25), lyx.Scale(25))
                check:SetToggle(v.def or false)
                args[k] = v.def or false

                local checkLabel = vgui.Create("DLabel", panel)
                checkLabel:SetPos(lyx.Scale(45), argY)
                checkLabel:SetFont("GM3.Modules.Normal")
                checkLabel:SetText(v.name or "Enabled")
                checkLabel:SetTextColor(Color(255, 255, 255, 180))
                checkLabel:SizeToContents()

                check.OnValueChange = function(s, val)
                    args[k] = val
                end

                argY = argY + lyx.Scale(35)
            end
        end
    end

    -- Run button
    local runBtn = vgui.Create("lyx.TextButton2", panel)
    runBtn:SetPos(panel:GetWide() - lyx.ScaleW(120), lyx.Scale(40))
    runBtn:SetSize(lyx.ScaleW(100), lyx.Scale(35))
    runBtn:SetText("Run")
    runBtn:SetFont("GM3.Modules.Category")
    runBtn:SetBackgroundColor(Color(68, 68, 68))

    runBtn.DoClick = function()
        surface.PlaySound("buttons/button15.wav")

        net.Start("gm3:tool:run")
        net.WriteString(module.data.name)
        net.WriteTable(args)
        net.SendToServer()

        -- Feedback
        notification.AddLegacy("Running: " .. module.data.name, NOTIFY_GENERIC, 3)
    end

    return panel
end

function PANEL:Paint(w, h)
    -- Match the style of other panels
    draw.RoundedBox(4, 0, 0, w, h, lyx.Colors.Foreground)
end

vgui.Register("GM3.Pages.Modules", PANEL)