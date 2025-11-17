gm3 = gm3

local OPSAT_KEYS = {
    "Title 1",
    "Line 1",
    "Line 2",
    "Title 2",
    "Line 3",
    "Line 4"
}

local OPSAT_DEFAULT = {
    ["Title 1"] = "Information",
    ["Line 1"] = "Planet: KG3",
    ["Line 2"] = "Era: 22BBY",
    ["Title 2"] = "Objective",
    ["Line 3"] = "- Raid CIS Base",
    ["Line 4"] = "- Kill CIS Leader"
}

local function CopyDefaultOpsat()
    return table.Copy(OPSAT_DEFAULT)
end

if SERVER then
    gm3 = gm3
    gm3.opsat = gm3.opsat or false
    gm3.opsatData = gm3.opsatData or CopyDefaultOpsat()
    gm3.opsatPresets = gm3.opsatPresets or nil
    lyx = lyx

    local presetFile = "gm3_opsat_presets.json"

    local function LoadPresets()
        if gm3.opsatPresets then return gm3.opsatPresets end
        if not file.Exists(presetFile, "DATA") then
            gm3.opsatPresets = {}
            return gm3.opsatPresets
        end

        local raw = file.Read(presetFile, "DATA")
        local parsed = util.JSONToTable(raw or "") or {}
        gm3.opsatPresets = parsed
        return gm3.opsatPresets
    end

    local function SavePresets()
        if not gm3.opsatPresets then return end
        file.Write(presetFile, util.TableToJSON(gm3.opsatPresets, true))
    end

    local function SanitizeOpsatData(tbl)
        local sanitized = {}
        for _, key in ipairs(OPSAT_KEYS) do
            local value = tbl and tbl[key] or OPSAT_DEFAULT[key] or ""
            value = tostring(value or "")
            value = string.Trim(value)
            value = string.sub(value, 1, 160)
            sanitized[key] = value
        end
        return sanitized
    end

    local function SendPresets(ply)
        LoadPresets()
        net.Start("gm3:tools:opsatPresets")
            net.WriteTable(gm3.opsatPresets)
        if IsValid(ply) then
            net.Send(ply)
        else
            net.Broadcast()
        end
    end

    local function EnsurePresetTable()
        if not gm3.opsatPresets then
            LoadPresets()
        end
    end

    lyx:NetAdd("gm3:tools:opsatRemove", {
        func = function(ply)   
            if gm3:SecurityCheck(ply) then
                net.Start("gm3:tools:opsatRemove")
                net.Broadcast() 
                gm3.opsat = false
            end
        end
    })
    lyx:NetAdd("gm3:tools:opsatSet", {
        func = function(ply)
            local args = net.ReadTable()

            if gm3:SecurityCheck(ply) then
                args = SanitizeOpsatData(args or OPSAT_DEFAULT)
                net.Start("gm3:tools:opsatSet")
                    net.WriteTable(args)
                net.Broadcast()
                gm3.opsat = true
                gm3.opsatData = args
            end
        end
    })
    lyx:NetAdd("gm3:tools:requestOpsat", {
        func = function(ply)
            if gm3.opsat then
                net.Start("gm3:tools:opsatSet")
                    net.WriteTable(gm3.opsatData)
                net.Send(ply)
            end
        end
    })

    lyx:NetAdd("gm3:tools:opsatRequestPresets", {
        func = function(ply)
            if not gm3:SecurityCheck(ply) then return end
            SendPresets(ply)
        end
    })

    lyx:NetAdd("gm3:tools:opsatSavePreset", {
        func = function(ply)
            if not gm3:SecurityCheck(ply) then return end
            local payload = net.ReadTable() or {}
            local name = tostring(payload.name or "")
            name = string.Trim(name)
            name = string.sub(name, 1, 60)

            if name == "" then return end

            EnsurePresetTable()

            local data = SanitizeOpsatData(payload.data or OPSAT_DEFAULT)
            local found
            for idx, preset in ipairs(gm3.opsatPresets) do
                if preset.name == name then
                    gm3.opsatPresets[idx].data = data
                    found = true
                    break
                end
            end

            if not found then
                if #gm3.opsatPresets >= 25 then
                    table.remove(gm3.opsatPresets, 1)
                end
                table.insert(gm3.opsatPresets, {
                    name = name,
                    data = data
                })
            end

            SavePresets()
            SendPresets(ply)
        end
    })

    lyx:NetAdd("gm3:tools:opsatDeletePreset", {
        func = function(ply)
            if not gm3:SecurityCheck(ply) then return end
            local name = net.ReadString() or ""
            name = string.Trim(name)
            if name == "" then return end

            EnsurePresetTable()
            for idx = #gm3.opsatPresets, 1, -1 do
                if gm3.opsatPresets[idx].name == name then
                    table.remove(gm3.opsatPresets, idx)
                end
            end

            SavePresets()
            SendPresets(ply)
        end
    })

    lyx:NetAdd("gm3:tools:opsatPresets", {})

    print("OPSAT SERVER SIDE LOADED")
end

if CLIENT then
    gm3 = gm3
    gm3.opsat = gm3.opsat or false
    gm3.opsatClientData = gm3.opsatClientData or CopyDefaultOpsat()
    gm3.opsatPanels = gm3.opsatPanels or {}
    gm3.opsatSavedPresets = gm3.opsatSavedPresets or {}

    lyx = lyx

    local function ScaleW(size)
        return ScrW() * size / 1920
    end
    
    local function ScaleH(size)
        return ScrH() * size / 1080
    end

    surface.CreateFont("GM3_Opsat_Title", {
        font = "Roboto",
        size = ScaleW(27),
        weight = 500,
        antialias = true,

    })
    surface.CreateFont("GM3_Opsat_SubTitle", {
        font = "Roboto",
        size = ScaleW(20),
        weight = 500,
        antialias = true
    })

    local function CreateOpsatPanel(args)
        -- Get primary color with fallback to default
        local primaryColor = Color(189, 88, 88)  -- Default color
        if gm3.settings and gm3.settings["gm3_opsat_primaryColor"] then
            local color = gm3.settings["gm3_opsat_primaryColor"].value
            if color then
                primaryColor = Color(color.r or 189, color.g or 88, color.b or 88)
            end
        end

        -- Get secondary color with fallback to default
        local secondaryColor = Color(255, 255, 255)  -- Default color
        if gm3.settings and gm3.settings["gm3_opsat_secondaryColor"] then
            local color = gm3.settings["gm3_opsat_secondaryColor"].value
            if color then
                secondaryColor = Color(color.r or 255, color.g or 255, color.b or 255)
            end
        end

        local back = vgui.Create("DPanel")
        local width = ScaleW(420)
        local height = ScaleH(210)
        back:SetSize(width, height)
        back:SetPos(ScrW() - width - ScaleW(40), ScaleH(40))
        back:SetAlpha(0)
        back:AlphaTo(255, 0.25, 0)

        back.Paint = function(self, w, h)
            draw.RoundedBox(12, 0, 0, w, h, Color(20, 20, 20, 245))
            draw.RoundedBoxEx(12, 0, 0, w, ScaleH(6), Color(primaryColor.r, primaryColor.g, primaryColor.b, 180), true, true, false, false)
            surface.SetDrawColor(255, 255, 255, 10)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local content = vgui.Create("DPanel", back)
        content:Dock(FILL)
        content:DockMargin(ScaleW(12), ScaleH(12), ScaleW(12), ScaleH(12))
        content.Paint = nil

        local function addLine(text)
            text = string.Trim(tostring(text or ""))
            if text == "" then return end

            local linePanel = vgui.Create("DPanel", content)
            linePanel:Dock(TOP)
            linePanel:SetTall(ScaleH(24))
            linePanel.Paint = function(_, w, h)
                surface.SetDrawColor(primaryColor.r, primaryColor.g, primaryColor.b, 25)
                surface.DrawRect(0, h - 1, w, 1)
            end

            local bullet = vgui.Create("DPanel", linePanel)
            bullet:Dock(LEFT)
            bullet:SetWide(ScaleW(6))
            bullet:DockMargin(0, ScaleH(8), ScaleW(8), ScaleH(8))
            bullet.Paint = function(_, w, h)
                draw.RoundedBox(4, 0, 0, w, h, primaryColor)
            end

            local textLbl = vgui.Create("DLabel", linePanel)
            textLbl:Dock(FILL)
            textLbl:SetFont("GM3_Opsat_SubTitle")
            textLbl:SetText(text)
            textLbl:SetTextColor(secondaryColor)
        end

        local function addSection(title, ...)
            title = string.Trim(tostring(title or ""))
            if title ~= "" then
                local titleLbl = vgui.Create("DLabel", content)
                titleLbl:Dock(TOP)
                titleLbl:SetTall(ScaleH(24))
                titleLbl:SetFont("GM3_Opsat_Title")
                titleLbl:SetText(string.upper(title))
                titleLbl:SetTextColor(primaryColor)
                titleLbl:DockMargin(0, 0, 0, ScaleH(4))
            end

            for _, line in ipairs({...}) do
                addLine(line)
            end

            local spacer = vgui.Create("DPanel", content)
            spacer:Dock(TOP)
            spacer:SetTall(ScaleH(6))
            spacer.Paint = nil
        end

        addSection(args["Title 1"], args["Line 1"], args["Line 2"])
        addSection(args["Title 2"], args["Line 3"], args["Line 4"])

        return back
    end
    
    local function Opsat(args, method)
        if method == "set" then
            for _, v in pairs(gm3.opsatPanels) do
                v:Remove()
            end

            local opsatPanel = CreateOpsatPanel(args)
            gm3.opsatPanels = gm3.opsatPanels or {}
            table.insert(gm3.opsatPanels, opsatPanel)
            gm3.opsat = true
        elseif method == "remove" then
            for _, v in pairs(gm3.opsatPanels or {}) do
                v:Remove()
            end
            gm3.opsatPanels = {}
            gm3.opsat = false
        end
    end

    lyx:NetAdd("gm3:tools:opsatRemove", {
        func = function()   
            Opsat({}, "remove") 
            gm3.opsat = false
        end
    })
    lyx:NetAdd("gm3:tools:opsatSet", {
        func = function()
            local data = net.ReadTable()

            Opsat(data, "set")
            gm3.opsatClientData = data
            gm3.opsat = true
        end
    })
    lyx:NetAdd("gm3:tools:opsatPresets", {
        func = function()
            local presets = net.ReadTable() or {}
            gm3.opsatSavedPresets = presets
            hook.Run("GM3.OpsatPresetsUpdated", presets)
        end
    })

    hook.Add("ClientSignOnStateChanged", "GM3_Opsat", function(userid, oldState, newState)
        print("SIGNONSTATE: " .. newState)
        if newState == 6 then
            print("ATTEMPTING TO SYNC OPSAT")
            net.Start("gm3:tools:requestOpsat")
            net.SendToServer()
            print("OPSAT SYNCED")
        end
    end)
    print("OPSAT CLIENT SIDE LOADED")
end
