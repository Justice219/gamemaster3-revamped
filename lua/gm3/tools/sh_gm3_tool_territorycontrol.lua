gm3 = gm3
lyx = lyx

if SERVER then
    -- Register network strings for territory control (server -> client only)
    lyx:NetAdd("gm3:tools:territory:update")
    lyx:NetAdd("gm3:tools:territory:capture")
    lyx:NetAdd("gm3:tools:territory:contested")
    lyx:NetAdd("gm3:tools:territory:reset")
    lyx:NetAdd("gm3:tools:territory:points")

    gm3 = gm3
    lyx = lyx

    -- Territory system data
    gm3.territories = gm3.territories or {}
    gm3.territoryPoints = gm3.territoryPoints or {}
    gm3.territoryTimers = gm3.territoryTimers or {}

    local tool = GM3Module.new(
        "Territory Control",
        "Create and manage faction territories with capture zones, perfect for MRP and event scenarios",
        "GM3 Assistant",
        {
            ["Action"] = {
                type = "string",
                def = "create" -- create, remove, list, reset_all, set_faction
            },
            ["Territory Name"] = {
                type = "string",
                def = "Alpha Zone" -- Name of the territory
            },
            ["Zone Center"] = {
                type = "string",
                def = "cursor" -- cursor, player_pos, coordinates (x,y,z)
            },
            ["Zone Radius"] = {
                type = "number",
                def = 500 -- Radius in units
            },
            ["Zone Height"] = {
                type = "number",
                def = 200 -- Height of the zone cylinder
            },
            ["Controlling Faction"] = {
                type = "string",
                def = "Neutral" -- Faction name or team name
            },
            ["Faction Color"] = {
                type = "color",
                def = Color(100, 100, 100) -- Default gray color
            },
            ["Capture Time"] = {
                type = "number",
                def = 60 -- Seconds to capture
            },
            ["Required Players"] = {
                type = "number",
                def = 2 -- Minimum players to start capture
            },
            ["Capture Mode"] = {
                type = "string",
                def = "contested" -- contested, majority, exclusive
            },
            ["Show Boundaries"] = {
                type = "boolean",
                def = true -- Show visual zone boundaries
            },
            ["Show HUD Info"] = {
                type = "boolean",
                def = true -- Show territory info on HUD
            },
            ["Award Points"] = {
                type = "boolean",
                def = true -- Give points for holding territories
            },
            ["Points Per Minute"] = {
                type = "number",
                def = 10 -- Points awarded per minute of control
            },
            ["Notify On Capture"] = {
                type = "boolean",
                def = true -- Global notification when captured
            },
            ["Allow Vehicles"] = {
                type = "boolean",
                def = true -- Count players in vehicles
            },
            ["Spawn Protection"] = {
                type = "boolean",
                def = false -- Protect spawning players in territory
            }
        },
        function(ply, args)
            local action = args["Action"]

            if action == "reset_all" then
                -- Reset all territories
                gm3.territories = {}
                gm3.territoryPoints = {}
                for k, v in pairs(gm3.territoryTimers) do
                    timer.Remove(v)
                end
                gm3.territoryTimers = {}

                -- Notify all players
                for _, p in ipairs(player.GetAll()) do
                    lyx:NetSend("gm3:tools:territory:reset", {}, p)
                end

                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(255,200,100),
                    ["header"] = "Territory Control",
                    ["color2"] = Color(255,255,255),
                    ["text"] = "All territories have been reset!",
                    ["ply"] = ply
                })
                return

            elseif action == "list" then
                -- List all territories
                if table.IsEmpty(gm3.territories) then
                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(255,200,100),
                        ["header"] = "Territory Control",
                        ["color2"] = Color(255,255,255),
                        ["text"] = "No territories exist.",
                        ["ply"] = ply
                    })
                else
                    local msg = "Active Territories:\n"
                    for name, data in pairs(gm3.territories) do
                        msg = msg .. string.format("- %s: Controlled by %s (%.0f points)\n",
                            name, data.faction, gm3.territoryPoints[data.faction] or 0)
                    end
                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(255,200,100),
                        ["header"] = "Territory Control",
                        ["color2"] = Color(255,255,255),
                        ["text"] = msg,
                        ["ply"] = ply
                    })
                end
                return

            elseif action == "remove" then
                -- Remove a territory
                local territoryName = args["Territory Name"]
                if gm3.territories[territoryName] then
                    -- Clean up timer
                    if gm3.territoryTimers[territoryName] then
                        timer.Remove(gm3.territoryTimers[territoryName])
                        gm3.territoryTimers[territoryName] = nil
                    end

                    gm3.territories[territoryName] = nil

                    -- Update all players
                    for _, p in ipairs(player.GetAll()) do
                        lyx:NetSend("gm3:tools:territory:update", {territories = gm3.territories}, p)
                    end

                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(100,255,100),
                        ["header"] = "Territory Control",
                        ["color2"] = Color(255,255,255),
                        ["text"] = "Territory '" .. territoryName .. "' removed!",
                        ["ply"] = ply
                    })
                else
                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(255,100,100),
                        ["header"] = "Territory Control",
                        ["color2"] = Color(255,255,255),
                        ["text"] = "Territory not found!",
                        ["ply"] = ply
                    })
                end
                return

            elseif action == "set_faction" then
                -- Manually set faction control
                local territoryName = args["Territory Name"]
                if gm3.territories[territoryName] then
                    gm3.territories[territoryName].faction = args["Controlling Faction"]
                    gm3.territories[territoryName].color = args["Faction Color"]

                    -- Update all players
                    for _, p in ipairs(player.GetAll()) do
                        lyx:NetSend("gm3:tools:territory:update", {territories = gm3.territories}, p)
                    end

                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(100,255,100),
                        ["header"] = "Territory Control",
                        ["color2"] = Color(255,255,255),
                        ["text"] = "Territory faction updated!",
                        ["ply"] = ply
                    })
                else
                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(255,100,100),
                        ["header"] = "Territory Control",
                        ["color2"] = Color(255,255,255),
                        ["text"] = "Territory not found!",
                        ["ply"] = ply
                    })
                end
                return
            end

            -- Create territory action
            local center = Vector(0, 0, 0)
            if args["Zone Center"] == "cursor" then
                local tr = ply:GetEyeTrace()
                center = tr.HitPos
            elseif args["Zone Center"] == "player_pos" then
                center = ply:GetPos()
            else
                -- Parse coordinates
                local coords = string.Explode(",", args["Zone Center"])
                if #coords == 3 then
                    center = Vector(tonumber(coords[1]) or 0, tonumber(coords[2]) or 0, tonumber(coords[3]) or 0)
                else
                    center = ply:GetPos()
                end
            end

            -- Create the territory
            local territoryName = args["Territory Name"]
            gm3.territories[territoryName] = {
                name = territoryName,
                center = center,
                radius = args["Zone Radius"],
                height = args["Zone Height"],
                faction = args["Controlling Faction"],
                color = args["Faction Color"],
                captureTime = args["Capture Time"],
                requiredPlayers = args["Required Players"],
                captureMode = args["Capture Mode"],
                showBoundaries = args["Show Boundaries"],
                showHUD = args["Show HUD Info"],
                awardPoints = args["Award Points"],
                pointsPerMinute = args["Points Per Minute"],
                notifyOnCapture = args["Notify On Capture"],
                allowVehicles = args["Allow Vehicles"],
                spawnProtection = args["Spawn Protection"],
                captureProgress = 0,
                capturingFaction = nil,
                contestingFactions = {}
            }

            -- Initialize faction points
            if not gm3.territoryPoints[args["Controlling Faction"]] then
                gm3.territoryPoints[args["Controlling Faction"]] = 0
            end

            -- Start territory tick timer
            local timerName = "GM3_Territory_" .. territoryName
            gm3.territoryTimers[territoryName] = timerName

            timer.Create(timerName, 1, 0, function()
                if not gm3.territories[territoryName] then
                    timer.Remove(timerName)
                    return
                end

                local territory = gm3.territories[territoryName]
                local playersInZone = {}
                local factionCounts = {}

                -- Check all players in zone
                for _, p in ipairs(player.GetAll()) do
                    if IsValid(p) and p:Alive() then
                        local inVehicle = p:InVehicle()
                        if not inVehicle or territory.allowVehicles then
                            local pPos = p:GetPos()
                            local dist = pPos:Distance2D(territory.center)
                            local heightDiff = math.abs(pPos.z - territory.center.z)

                            if dist <= territory.radius and heightDiff <= territory.height then
                                table.insert(playersInZone, p)
                                local faction = team.GetName(p:Team())
                                factionCounts[faction] = (factionCounts[faction] or 0) + 1
                            end
                        end
                    end
                end

                -- Determine capturing faction based on mode
                local capturingFaction = nil
                local canCapture = false

                if territory.captureMode == "contested" then
                    -- Multiple factions contest the zone
                    local maxCount = 0
                    for faction, count in pairs(factionCounts) do
                        if count >= territory.requiredPlayers and count > maxCount then
                            maxCount = count
                            capturingFaction = faction
                            canCapture = true
                        end
                    end
                    -- Check if contested
                    local contested = false
                    for faction, count in pairs(factionCounts) do
                        if faction ~= capturingFaction and count >= territory.requiredPlayers then
                            contested = true
                            break
                        end
                    end
                    if contested then
                        canCapture = false
                        -- Notify about contested state
                        for _, p in ipairs(playersInZone) do
                            lyx:NetSend("gm3:tools:territory:contested", {
                                territory = territoryName
                            }, p)
                        end
                    end

                elseif territory.captureMode == "majority" then
                    -- Need majority of players
                    local totalPlayers = #playersInZone
                    for faction, count in pairs(factionCounts) do
                        if count > totalPlayers / 2 and count >= territory.requiredPlayers then
                            capturingFaction = faction
                            canCapture = true
                            break
                        end
                    end

                elseif territory.captureMode == "exclusive" then
                    -- Only one faction can be in zone
                    if table.Count(factionCounts) == 1 then
                        for faction, count in pairs(factionCounts) do
                            if count >= territory.requiredPlayers then
                                capturingFaction = faction
                                canCapture = true
                            end
                        end
                    end
                end

                -- Handle capture progress
                if canCapture and capturingFaction ~= territory.faction then
                    if territory.capturingFaction == capturingFaction then
                        -- Continue capturing
                        territory.captureProgress = territory.captureProgress + 1
                    else
                        -- New faction started capturing, reset progress
                        territory.capturingFaction = capturingFaction
                        territory.captureProgress = 1
                    end

                    -- Check if captured
                    if territory.captureProgress >= territory.captureTime then
                        local oldFaction = territory.faction
                        territory.faction = capturingFaction
                        territory.captureProgress = 0
                        territory.capturingFaction = nil

                        -- Update color based on team color if available
                        for _, p in ipairs(player.GetAll()) do
                            if team.GetName(p:Team()) == capturingFaction then
                                territory.color = team.GetColor(p:Team())
                                break
                            end
                        end

                        -- Notify about capture
                        if territory.notifyOnCapture then
                            for _, p in ipairs(player.GetAll()) do
                                lyx:NetSend("gm3:tools:territory:capture", {
                                    territory = territoryName,
                                    newFaction = capturingFaction,
                                    oldFaction = oldFaction
                                }, p)

                                lyx:MessagePlayer({
                                    ["type"] = "header",
                                    ["color1"] = territory.color,
                                    ["header"] = "Territory Captured!",
                                    ["color2"] = Color(255,255,255),
                                    ["text"] = capturingFaction .. " has captured " .. territoryName .. "!",
                                    ["ply"] = p
                                })
                            end
                        end
                    end
                else
                    -- Reset capture progress if no one is capturing
                    if territory.captureProgress > 0 then
                        territory.captureProgress = math.max(0, territory.captureProgress - 1)
                        if territory.captureProgress == 0 then
                            territory.capturingFaction = nil
                        end
                    end
                end

                -- Award points for control
                if territory.awardPoints and territory.faction ~= "Neutral" then
                    if not gm3.territoryPoints[territory.faction] then
                        gm3.territoryPoints[territory.faction] = 0
                    end
                    gm3.territoryPoints[territory.faction] = gm3.territoryPoints[territory.faction] + (territory.pointsPerMinute / 60)
                end

                -- Update all players with territory info
                for _, p in ipairs(player.GetAll()) do
                    lyx:NetSend("gm3:tools:territory:update", {
                        territories = gm3.territories,
                        points = gm3.territoryPoints
                    }, p)
                end
            end)

            -- Send initial update to all players
            for _, p in ipairs(player.GetAll()) do
                lyx:NetSend("gm3:tools:territory:update", {
                    territories = gm3.territories,
                    points = gm3.territoryPoints
                }, p)
            end

            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(100,255,100),
                ["header"] = "Territory Control",
                ["color2"] = Color(255,255,255),
                ["text"] = "Territory '" .. territoryName .. "' created successfully!",
                ["ply"] = ply
            })
        end,
        "Roleplay"
    )

    gm3:addTool(tool)

    -- Clean up on player spawn if spawn protection is enabled
    hook.Add("PlayerSpawn", "GM3_TerritorySpawnProtection", function(ply)
        timer.Simple(0.1, function()
            if not IsValid(ply) then return end

            for name, territory in pairs(gm3.territories) do
                if territory.spawnProtection then
                    local dist = ply:GetPos():Distance2D(territory.center)
                    if dist <= territory.radius then
                        -- Give spawn protection
                        ply:GodEnable()
                        timer.Simple(5, function()
                            if IsValid(ply) then
                                ply:GodDisable()
                            end
                        end)

                        lyx:MessagePlayer({
                            ["type"] = "header",
                            ["color1"] = Color(100,200,255),
                            ["header"] = "Spawn Protection",
                            ["color2"] = Color(255,255,255),
                            ["text"] = "You have 5 seconds of spawn protection in this territory.",
                            ["ply"] = ply
                        })
                        break
                    end
                end
            end
        end)
    end)
end

if CLIENT then
    local territories = {}
    local territoryPoints = {}
    local captureNotifications = {}

    -- Receive territory updates
    lyx.NetReceive("gm3:tools:territory:update", function(ply, tbl)
        territories = tbl.territories or {}
        territoryPoints = tbl.points or {}
    end)

    -- Receive capture notifications
    lyx.NetReceive("gm3:tools:territory:capture", function(ply, tbl)
        table.insert(captureNotifications, {
            territory = tbl.territory,
            newFaction = tbl.newFaction,
            oldFaction = tbl.oldFaction,
            time = CurTime()
        })

        -- Play capture sound
        surface.PlaySound("ambient/alarms/warningbell1.wav")
    end)

    -- Receive contested notifications
    lyx.NetReceive("gm3:tools:territory:contested", function(ply, tbl)
        -- Could add visual indicator for contested zones
    end)

    -- Reset territories
    lyx.NetReceive("gm3:tools:territory:reset", function(ply, tbl)
        territories = {}
        territoryPoints = {}
        captureNotifications = {}
    end)

    -- Draw territory boundaries and info
    hook.Add("PostDrawTranslucentRenderables", "GM3_TerritoryBoundaries", function()
        for name, territory in pairs(territories) do
            if territory.showBoundaries then
                local center = territory.center
                local radius = territory.radius
                local height = territory.height

                -- Draw cylinder boundary
                local segments = 32
                for i = 0, segments do
                    local angle1 = (i / segments) * math.pi * 2
                    local angle2 = ((i + 1) / segments) * math.pi * 2

                    local x1 = center.x + math.cos(angle1) * radius
                    local y1 = center.y + math.sin(angle1) * radius
                    local x2 = center.x + math.cos(angle2) * radius
                    local y2 = center.y + math.sin(angle2) * radius

                    -- Draw vertical lines
                    if i % 4 == 0 then
                        render.DrawLine(
                            Vector(x1, y1, center.z - height/2),
                            Vector(x1, y1, center.z + height/2),
                            territory.color
                        )
                    end

                    -- Draw horizontal circles
                    render.DrawLine(
                        Vector(x1, y1, center.z - height/2),
                        Vector(x2, y2, center.z - height/2),
                        territory.color
                    )
                    render.DrawLine(
                        Vector(x1, y1, center.z + height/2),
                        Vector(x2, y2, center.z + height/2),
                        territory.color
                    )
                end

                -- Draw territory name in 3D
                local ang = (LocalPlayer():GetPos() - center):Angle()
                ang:RotateAroundAxis(ang:Up(), 90)
                ang:RotateAroundAxis(ang:Forward(), 90)

                cam.Start3D2D(center + Vector(0, 0, height/2 + 50), ang, 1)
                    draw.SimpleText(
                        territory.name,
                        "DermaLarge",
                        0, 0,
                        territory.color,
                        TEXT_ALIGN_CENTER,
                        TEXT_ALIGN_CENTER
                    )
                    draw.SimpleText(
                        "Controlled by: " .. territory.faction,
                        "DermaDefault",
                        0, 30,
                        Color(255, 255, 255),
                        TEXT_ALIGN_CENTER,
                        TEXT_ALIGN_CENTER
                    )

                    -- Show capture progress
                    if territory.captureProgress > 0 then
                        local progress = territory.captureProgress / territory.captureTime
                        draw.RoundedBox(4, -100, 50, 200, 20, Color(0, 0, 0, 150))
                        draw.RoundedBox(4, -98, 52, 196 * progress, 16, Color(255, 100, 0))
                        draw.SimpleText(
                            "Capturing: " .. math.floor(progress * 100) .. "%",
                            "DermaDefault",
                            0, 60,
                            Color(255, 255, 255),
                            TEXT_ALIGN_CENTER,
                            TEXT_ALIGN_CENTER
                        )
                    end
                cam.End3D2D()
            end
        end
    end)

    -- HUD Display
    hook.Add("HUDPaint", "GM3_TerritoryHUD", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local w, h = ScrW(), ScrH()
        local yOffset = 100 * lyx.Scale()

        -- Check if player is in any territory
        local currentTerritory = nil
        for name, territory in pairs(territories) do
            if territory.showHUD then
                local dist = ply:GetPos():Distance2D(territory.center)
                local heightDiff = math.abs(ply:GetPos().z - territory.center.z)

                if dist <= territory.radius and heightDiff <= territory.height then
                    currentTerritory = territory
                    break
                end
            end
        end

        -- Display current territory info
        if currentTerritory then
            draw.RoundedBox(8, 10 * lyx.Scale(), yOffset, 300 * lyx.Scale(), 100 * lyx.Scale(), Color(0, 0, 0, 150))

            draw.SimpleText(
                currentTerritory.name,
                "DermaLarge",
                160 * lyx.Scale(),
                yOffset + 20 * lyx.Scale(),
                currentTerritory.color,
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )

            draw.SimpleText(
                "Controlled by: " .. currentTerritory.faction,
                "DermaDefault",
                160 * lyx.Scale(),
                yOffset + 50 * lyx.Scale(),
                Color(255, 255, 255),
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )

            if currentTerritory.captureProgress > 0 then
                local progress = currentTerritory.captureProgress / currentTerritory.captureTime
                draw.RoundedBox(4, 20 * lyx.Scale(), yOffset + 70 * lyx.Scale(), 280 * lyx.Scale(), 20 * lyx.Scale(), Color(50, 50, 50))
                draw.RoundedBox(4, 22 * lyx.Scale(), yOffset + 72 * lyx.Scale(), 276 * lyx.Scale() * progress, 16 * lyx.Scale(), Color(255, 100, 0))
            end
        end

        -- Display faction points
        if not table.IsEmpty(territoryPoints) then
            local yPos = 200 * lyx.Scale()
            draw.RoundedBox(8, w - 210 * lyx.Scale(), yPos, 200 * lyx.Scale(), 30 * lyx.Scale() + table.Count(territoryPoints) * 25 * lyx.Scale(), Color(0, 0, 0, 150))

            draw.SimpleText(
                "Faction Points",
                "DermaDefault",
                w - 110 * lyx.Scale(),
                yPos + 10 * lyx.Scale(),
                Color(255, 255, 255),
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER
            )

            local i = 0
            for faction, points in pairs(territoryPoints) do
                i = i + 1
                draw.SimpleText(
                    faction .. ": " .. math.floor(points),
                    "DermaDefault",
                    w - 110 * lyx.Scale(),
                    yPos + 25 * lyx.Scale() + i * 20 * lyx.Scale(),
                    Color(200, 200, 200),
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
            end
        end

        -- Display capture notifications
        for i = #captureNotifications, 1, -1 do
            local notif = captureNotifications[i]
            local timeSince = CurTime() - notif.time

            if timeSince > 5 then
                table.remove(captureNotifications, i)
            else
                local alpha = math.max(0, 255 - (timeSince - 4) * 255)
                local yPos = h/2 - 100 * lyx.Scale() - (i - 1) * 60 * lyx.Scale()

                draw.RoundedBox(8, w/2 - 200 * lyx.Scale(), yPos, 400 * lyx.Scale(), 50 * lyx.Scale(), Color(0, 0, 0, alpha * 0.7))
                draw.SimpleText(
                    notif.newFaction .. " captured " .. notif.territory .. "!",
                    "DermaLarge",
                    w/2,
                    yPos + 25 * lyx.Scale(),
                    Color(255, 200, 0, alpha),
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_CENTER
                )
            end
        end
    end)
end