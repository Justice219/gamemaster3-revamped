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

-- Category colors for visual distinction
local CATEGORY_COLORS = {
    ["Visual"] = Color(147, 112, 219),      -- Purple for visual effects
    ["Control"] = Color(52, 152, 219),      -- Blue for control tools
    ["Communication"] = Color(46, 204, 113), -- Green for communication
    ["Environment"] = Color(230, 126, 34),   -- Orange for environment
    ["Utility"] = Color(155, 89, 182)        -- Light purple for utility
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
    self.ModuleContainer = vgui.Create("DListLayout", self.ScrollPanel)
    self.ModuleContainer:Dock(TOP)
    self.ModuleContainer:DockMargin(0, 0, 0, lyx.Scale(20))
    self.ModuleContainer:SetTall(0)
    self.ModuleContainer.PerformLayout = function(s)
        s:SizeToChildren(false, true)
    end

    -- Populate modules
    self:RefreshModules()

    self.SyncHookID = "GM3.Modules.Sync." .. tostring(self)
    hook.Add("GM3.DataSynced", self.SyncHookID, function()
        if not IsValid(self) then return end
        self:CategorizeModules()
        self:FilterModules()
        self.ReloadPending = false
        if IsValid(self.ReloadButton) then
            self.ReloadButton:SetEnabled(true)
            self.ReloadButton:SetText("Reload Modules")
        end
    end)
end

function PANEL:CategorizeModules()
    self.Modules = {}
    if not gm3.tools or table.IsEmpty(gm3.tools) then
        self.FilteredModules = {}
        return
    end

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
function PANEL:OnRemove()
    if self.SyncHookID then
        hook.Remove("GM3.DataSynced", self.SyncHookID)
    end
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

    self.ReloadButton = vgui.Create("lyx.TextButton2", searchContainer)
    self.ReloadButton:Dock(RIGHT)
    self.ReloadButton:SetWide(lyx.ScaleW(150))
    self.ReloadButton:DockMargin(0, lyx.Scale(10), lyx.Scale(10), lyx.Scale(10))
    self.ReloadButton:SetText("Reload Modules")
    self.ReloadButton:SetFont("GM3.Modules.Category")
    self.ReloadButton:SetBackgroundColor(Color(70, 130, 180))
    self.ReloadButton.DoClick = function()
        self:RequestModuleReload()
    end

    -- Search entry using LYX TextEntry2
    self.SearchEntry = vgui.Create("lyx.TextEntry2", searchContainer)
    self.SearchEntry:Dock(FILL)
    self.SearchEntry:DockMargin(lyx.Scale(10), lyx.Scale(10), lyx.Scale(5), lyx.Scale(10))
    self.SearchEntry:SetPlaceholderText("Search modules...")
    -- lyx.TextEntry2 doesn't have SetFont or SetBackgroundColor, it uses its own styling
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
    if not IsValid(self.ModuleContainer) then return end

    for _, child in ipairs(self.ModuleContainer:GetChildren()) do
        child:Remove()
    end

    local count = table.Count(self.FilteredModules)
    local total = table.Count(self.Modules)
    self.CountLabel:SetText(string.format("Showing %d of %d modules", count, total))

    local ordered = {}
    for name, module in pairs(self.FilteredModules) do
        table.insert(ordered, {name = name, data = module})
    end
    table.sort(ordered, function(a, b)
        return tostring(a.name) < tostring(b.name)
    end)

    for _, entry in ipairs(ordered) do
        self:CreateModulePanel(entry.data, self.ModuleContainer)
    end

    self.ModuleContainer:InvalidateLayout(true)
end

function PANEL:RequestModuleReload()
    if self.ReloadPending then return end
    self.ReloadPending = true

    if IsValid(self.ReloadButton) then
        self.ReloadButton:SetEnabled(false)
        self.ReloadButton:SetText("Reloading...")
    end

    net.Start("gm3:sync:request")
    net.SendToServer()

    -- Safety timeout in case we never hear back
    timer.Simple(3, function()
        if not IsValid(self) or not self.ReloadPending then return end
        self.ReloadPending = false
        if IsValid(self.ReloadButton) then
            self.ReloadButton:SetEnabled(true)
            self.ReloadButton:SetText("Reload Modules")
        end
    end)
end

function PANEL:CreateModulePanel(module, parent)
    local panel = vgui.Create("DPanel", parent)
    panel:Dock(TOP)
    panel:DockMargin(0, 0, 0, lyx.Scale(12))
    panel:DockPadding(lyx.Scale(16), lyx.Scale(16), lyx.Scale(16), lyx.Scale(16))
    panel.PerformLayout = function(s)
        s:SizeToChildren(false, true)
    end

    local categoryColor = CATEGORY_COLORS[module.category] or Color(100, 100, 100)
    local iconId = CATEGORY_ICONS[module.category]

    panel.Paint = function(s, w, h)
        lyx.DrawRoundedBox(8, 0, 0, w, h, Color(34, 34, 42, 230))
        surface.SetDrawColor(categoryColor)
        surface.DrawRect(0, 0, 4, h)
        if iconId then
            lyx.DrawImgur(lyx.Scale(8), lyx.Scale(8), lyx.Scale(24), lyx.Scale(24), iconId, categoryColor)
        end
    end

    local header = vgui.Create("DPanel", panel)
    header:Dock(TOP)
    header:SetTall(lyx.Scale(34))
    header:DockMargin(iconId and lyx.Scale(36) or 0, 0, 0, lyx.Scale(4))
    header.Paint = nil

    local nameLabel = vgui.Create("DLabel", header)
    nameLabel:Dock(FILL)
    nameLabel:SetFont("GM3.Modules.Title")
    nameLabel:SetText(module.data.name or module.name)
    nameLabel:SetTextColor(color_white)
    nameLabel:SetContentAlignment(4)

    local badge = vgui.Create("DLabel", header)
    badge:Dock(RIGHT)
    badge:SetFont("GM3.Modules.Category")
    badge:SetText(module.category)
    badge:SetTextColor(categoryColor)
    badge:SetContentAlignment(6)
    badge:SetWide(lyx.ScaleW(180))

    local meta = vgui.Create("DLabel", panel)
    meta:Dock(TOP)
    meta:SetFont("GM3.Modules.Normal")
    meta:SetTextColor(Color(200, 200, 200))
    local argCount = table.Count(module.data.args or {})
    local metaParts = {
        module.data.author and ("Author: " .. module.data.author),
        argCount > 0 and (argCount .. " parameters") or "No parameters"
    }
    meta:SetText(table.concat(metaParts, "  •  "))
    meta:SizeToContents()

    local desc = vgui.Create("DLabel", panel)
    desc:Dock(TOP)
    desc:DockMargin(0, lyx.Scale(6), 0, lyx.Scale(6))
    desc:SetFont("GM3.Modules.Normal")
    desc:SetTextColor(Color(220, 220, 220))
    desc:SetWrap(true)
    desc:SetAutoStretchVertical(true)
    desc:SetText(module.data.description or "No description provided.")

    local argsContainer = vgui.Create("DPanel", panel)
    argsContainer:Dock(TOP)
    argsContainer:DockMargin(0, lyx.Scale(6), 0, 0)
    argsContainer.Paint = nil
    argsContainer.PerformLayout = function(s)
        s:SizeToChildren(false, true)
    end

    local argsList = vgui.Create("DListLayout", argsContainer)
    argsList:Dock(TOP)
    argsList.PerformLayout = function(s)
        s:SizeToChildren(false, true)
    end

    local args = {}

    local function addField(argKey, data, parentList)
        local field = parentList:Add("DPanel")
        field:Dock(TOP)
        field:SetTall(lyx.Scale(74))
        field:DockMargin(0, 0, 0, lyx.Scale(8))
        field.Paint = function(s, w, h)
            lyx.DrawRoundedBox(6, 0, 0, w, h, Color(45, 45, 52, 200))
        end

        local label = vgui.Create("DLabel", field)
        label:Dock(TOP)
        label:SetFont("GM3.Modules.Category")
        label:SetText(data.label or data.name or argKey)
        label:SetTextColor(color_white)
        label:SetContentAlignment(4)

        if data.description then
            local help = vgui.Create("DLabel", field)
            help:Dock(TOP)
            help:DockMargin(0, lyx.Scale(2), 0, lyx.Scale(6))
            help:SetFont("GM3.Modules.Normal")
            help:SetTextColor(Color(190, 190, 190))
            help:SetWrap(true)
            help:SetAutoStretchVertical(true)
            help:SetText(data.description)
        end

        local inputHolder = vgui.Create("DPanel", field)
        inputHolder:Dock(FILL)
        inputHolder:DockMargin(0, 0, 0, lyx.Scale(4))
        inputHolder.Paint = nil

        local inputHeight = lyx.Scale(32)

        local function applyEntryDefaults(entryPanel)
            entryPanel:Dock(FILL)
            entryPanel:SetTall(inputHeight)
        end

        if data.options and istable(data.options) and #data.options > 0 then
            local combo = vgui.Create("lyx.ComboBox2", inputHolder)
            combo:SetSortItems(false)
            combo:SetSizeToText(false)
            combo:SetTall(inputHeight)
            applyEntryDefaults(combo)

            local defaultValue = data.def
            if not defaultValue and data.options[1] then
                defaultValue = data.options[1].value
            end
            args[argKey] = defaultValue

            for _, option in ipairs(data.options) do
                combo:AddChoice(option.label or option.value, option.value, option.value == defaultValue)
            end

            combo.OnSelect = function(_, _, _, val)
                args[argKey] = val
            end

        elseif data.type == "string" then
            local entry = vgui.Create("lyx.TextEntry2", inputHolder)
            applyEntryDefaults(entry)
            entry:SetPlaceholderText(data.placeholder or data.def or "Enter value")
            entry:SetValue(data.def or "")
            args[argKey] = data.def or ""

            entry.OnChange = function(s)
                args[argKey] = s:GetValue()
            end

        elseif data.type == "number" then
            local entry = vgui.Create("lyx.TextEntry2", inputHolder)
            applyEntryDefaults(entry)
            entry:SetPlaceholderText(data.placeholder or tostring(data.def or 0))
            entry:SetValue(tostring(data.def or 0))
            entry:SetNumeric(true)
            args[argKey] = tonumber(data.def) or 0

            entry.OnChange = function(s)
                args[argKey] = tonumber(s:GetValue()) or 0
            end

        elseif data.type == "boolean" then
            local check = vgui.Create("lyx.Checkbox2", inputHolder)
            check:Dock(LEFT)
            check:SetWide(inputHeight)
            check:SetToggle(data.def or false)
            args[argKey] = data.def or false

            check.OnToggled = function(_, val)
                args[argKey] = val
            end

        elseif data.type == "player" then
            local playerBtn = vgui.Create("lyx.TextButton2", inputHolder)
            applyEntryDefaults(playerBtn)
            playerBtn:SetText("Select Player")
            playerBtn:SetFont("GM3.Modules.Normal")
            args[argKey] = data.def or ""

            local function updateButtonText()
                if args[argKey] == "" then
                    playerBtn:SetText("Select Player")
                    playerBtn:SetBackgroundColor(Color(80, 80, 80))
                    return
                end

                local name = args[argKey]
                for _, ply in ipairs(player.GetAll()) do
                    if ply:SteamID() == args[argKey] then
                        name = ply:Nick()
                        break
                    end
                end
                playerBtn:SetText(name)
                playerBtn:SetBackgroundColor(Color(50, 100, 50))
            end

            updateButtonText()

            playerBtn.DoClick = function()
                local selector = vgui.Create("GM3.PlayerSelector")
                selector.OnPlayerSelected = function(_, ply)
                    args[argKey] = ply:SteamID()
                    updateButtonText()
                end
            end

        elseif data.type == "color" then
            local colorBtn = vgui.Create("lyx.TextButton2", inputHolder)
            applyEntryDefaults(colorBtn)

            local defaultColor = data.def or Color(100, 100, 100)
            if isstring(data.def) then
                local parts = string.Explode(",", data.def)
                if #parts == 3 then
                    defaultColor = Color(tonumber(parts[1]) or 100, tonumber(parts[2]) or 100, tonumber(parts[3]) or 100)
                end
            end

            args[argKey] = defaultColor
            colorBtn:SetBackgroundColor(defaultColor)
            colorBtn:SetText(string.format("RGB(%d, %d, %d)", defaultColor.r, defaultColor.g, defaultColor.b))

            colorBtn.DoClick = function()
                local selector = vgui.Create("GM3.ColorSelector")
                selector:SetColor(args[argKey])
                selector.OnColorSelected = function(_, color)
                    args[argKey] = color
                    colorBtn:SetBackgroundColor(color)
                    colorBtn:SetText(string.format("RGB(%d, %d, %d)", color.r, color.g, color.b))

                    local brightness = (color.r * 0.299 + color.g * 0.587 + color.b * 0.114)
                    if brightness < 128 then
                        colorBtn:SetTextColor(color_white)
                    else
                        colorBtn:SetTextColor(Color(0, 0, 0))
                    end
                end
            end
        else
            args[argKey] = data.def
        end

        return field
    end

    local rawArgs = module.data.args or {}
    if table.IsEmpty(rawArgs) then
        local empty = argsList:Add("DLabel")
        empty:SetTall(lyx.Scale(28))
        empty:SetFont("GM3.Modules.Normal")
        empty:SetTextColor(Color(200, 200, 200))
        empty:SetText("This module does not require any parameters.")
    else
        local orderedArgs = {}
        for key, data in pairs(rawArgs) do
            local argData = table.Copy(data)
            argData.__key = key
            table.insert(orderedArgs, argData)
        end

        table.sort(orderedArgs, function(a, b)
            if a.order and b.order then
                return a.order < b.order
            elseif a.order then
                return true
            elseif b.order then
                return false
            end
            return tostring(a.__key) < tostring(b.__key)
        end)

        local sections = {}
        local sectionOrder = {}

        for _, data in ipairs(orderedArgs) do
            local sectionName = data.section or "General"
            if not sections[sectionName] then
                sections[sectionName] = {}
                table.insert(sectionOrder, {
                    name = sectionName,
                    order = data.sectionOrder or data.order or (#sectionOrder + 1)
                })
            end
            table.insert(sections[sectionName], data)
        end

        table.sort(sectionOrder, function(a, b)
            if a.order ~= b.order then
                return a.order < b.order
            end
            return a.name < b.name
        end)

        for _, section in ipairs(sectionOrder) do
            local headerLabel = argsList:Add("DLabel")
            headerLabel:SetTall(lyx.Scale(28))
            headerLabel:SetFont("GM3.Modules.Category")
            headerLabel:SetTextColor(color_white)
            headerLabel:SetText(section.name)

            for _, data in ipairs(sections[section.name]) do
                addField(data.__key, data, argsList)
            end
        end
    end

    local footer = vgui.Create("DPanel", panel)
    footer:Dock(TOP)
    footer:SetTall(lyx.Scale(40))
    footer:DockMargin(0, lyx.Scale(10), 0, 0)
    footer.Paint = nil
    footer.PerformLayout = function(s)
        s:SizeToChildren(false, true)
    end

    local runBtn = vgui.Create("lyx.TextButton2", footer)
    runBtn:Dock(RIGHT)
    runBtn:SetWide(lyx.ScaleW(150))
    runBtn:SetText("Run Module")
    runBtn:SetFont("GM3.Modules.Category")
    runBtn:SetBackgroundColor(Color(categoryColor.r * 0.7, categoryColor.g * 0.7, categoryColor.b * 0.7))

    runBtn.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        net.Start("gm3:tool:run")
        net.WriteString(module.data.name)
        net.WriteTable(args)
        net.SendToServer()
        notification.AddLegacy("Running: " .. module.data.name, NOTIFY_GENERIC, 3)
    end

    local hint = vgui.Create("DLabel", footer)
    hint:Dock(FILL)
    hint:DockMargin(0, 0, lyx.Scale(12), 0)
    hint:SetFont("GM3.Modules.Normal")
    hint:SetTextColor(Color(200, 200, 200))
    hint:SetContentAlignment(4)
    hint:SetText("Ensure parameters are set before running. Changes apply immediately.")

    panel:InvalidateLayout(true)
    panel:SizeToChildren(false, true)

    return panel
end

function PANEL:Paint(w, h)
    -- Match the style of other panels
    draw.RoundedBox(4, 0, 0, w, h, lyx.Colors.Foreground)
end

vgui.Register("GM3.Pages.Modules", PANEL)
