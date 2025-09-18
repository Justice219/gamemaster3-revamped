gm3 = gm3
lyx = lyx

if SERVER then
    -- Register network strings on server
    lyx:NetAdd("gm3:tools:invisible", {})
    lyx:NetAdd("gm3:tools:invisible:status", {})

    gm3 = gm3
    lyx = lyx

    -- Table to track invisible players
    gm3.invisiblePlayers = gm3.invisiblePlayers or {}

    local tool = GM3Module.new(
        "Invisible",
        "Make players invisible or partially transparent",
        "GM3 Assistant",
        {
            ["Target Player"] = {
                type = "player",
                def = ""
            },
            ["Action"] = {
                type = "string",
                def = "toggle" -- Options: toggle, enable, disable
            },
            ["Invisibility Level"] = {
                type = "number",
                def = 0 -- 0 = fully invisible, 255 = fully visible
            },
            ["Hide Weapons"] = {
                type = "boolean",
                def = true -- Also hide held weapons
            },
            ["Ghost Effect"] = {
                type = "boolean",
                def = true -- Shimmer/distortion effect
            },
            ["Duration (0 = Infinite)"] = {
                type = "number",
                def = 0 -- Duration in seconds
            }
        },
        function(ply, args)
            -- Get the target player
            local targetPlayer = gm3:GetPlayerBySteamID(args["Target Player"])
            if not IsValid(targetPlayer) then
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(255,100,100),
                    ["header"] = "Invisible",
                    ["color2"] = Color(255,255,255),
                    ["text"] = "Target player not found! Please select a valid player.",
                    ["ply"] = ply
                })
                return
            end

            local action = string.lower(args["Action"])
            local invisLevel = math.Clamp(args["Invisibility Level"], 0, 255)
            local hideWeapons = args["Hide Weapons"]
            local ghostEffect = args["Ghost Effect"]
            local duration = math.max(0, args["Duration (0 = Infinite)"])

            -- Determine invisibility state
            local makeInvisible = false
            if action == "toggle" then
                makeInvisible = not gm3.invisiblePlayers[targetPlayer]
            elseif action == "enable" then
                makeInvisible = true
            elseif action == "disable" then
                makeInvisible = false
            else
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(255,100,100),
                    ["header"] = "Invisible",
                    ["color2"] = Color(255,255,255),
                    ["text"] = "Invalid action! Use: toggle, enable, or disable",
                    ["ply"] = ply
                })
                return
            end

            -- Apply invisibility
            if makeInvisible then
                -- Store original render mode and color
                gm3.invisiblePlayers[targetPlayer] = {
                    originalRenderMode = targetPlayer:GetRenderMode(),
                    originalColor = targetPlayer:GetColor(),
                    level = invisLevel,
                    hideWeapons = hideWeapons,
                    ghostEffect = ghostEffect
                }

                -- Set player invisibility
                targetPlayer:SetRenderMode(RENDERMODE_TRANSCOLOR)
                targetPlayer:SetColor(Color(255, 255, 255, invisLevel))
                targetPlayer:SetNWBool("gm3_invisible", true)
                targetPlayer:SetNWInt("gm3_invisible_level", invisLevel)
                targetPlayer:SetNWBool("gm3_invisible_ghost", ghostEffect)

                -- Hide weapons if requested
                if hideWeapons then
                    local weapon = targetPlayer:GetActiveWeapon()
                    if IsValid(weapon) then
                        weapon:SetRenderMode(RENDERMODE_TRANSCOLOR)
                        weapon:SetColor(Color(255, 255, 255, invisLevel))
                        gm3.invisiblePlayers[targetPlayer].weaponColor = weapon:GetColor()
                    end
                end

                -- Make player harder to target
                if invisLevel == 0 then
                    targetPlayer:SetNoDraw(false) -- Keep false to allow custom rendering
                    targetPlayer:DrawShadow(false)
                    targetPlayer:SetNotSolid(false) -- Keep collision
                end

                -- Set up duration timer
                if duration > 0 then
                    timer.Create("gm3_invisible_" .. targetPlayer:SteamID(), duration, 1, function()
                        if IsValid(targetPlayer) and gm3.invisiblePlayers[targetPlayer] then
                            -- Restore visibility
                            RestoreVisibility(targetPlayer)

                            lyx:MessagePlayer({
                                ["type"] = "header",
                                ["color1"] = Color(255,200,0),
                                ["header"] = "Invisible",
                                ["color2"] = Color(255,255,255),
                                ["text"] = "Your invisibility has expired!",
                                ["ply"] = targetPlayer
                            })
                        end
                    end)
                else
                    timer.Remove("gm3_invisible_" .. targetPlayer:SteamID())
                end

                -- Hook to maintain invisibility on weapon switch
                hook.Add("PlayerSwitchWeapon", "GM3_Invisible_WeaponSwitch_" .. targetPlayer:SteamID(), function(ply, oldWep, newWep)
                    if ply == targetPlayer and gm3.invisiblePlayers[targetPlayer] and hideWeapons then
                        timer.Simple(0, function()
                            if IsValid(newWep) then
                                newWep:SetRenderMode(RENDERMODE_TRANSCOLOR)
                                newWep:SetColor(Color(255, 255, 255, invisLevel))
                            end
                        end)
                    end
                end)

                -- Send network message
                net.Start("gm3:tools:invisible")
                    net.WriteEntity(targetPlayer)
                    net.WriteBool(true)
                    net.WriteInt(invisLevel, 9)
                    net.WriteBool(ghostEffect)
                net.Broadcast()

                -- Notifications
                local levelText = invisLevel == 0 and "fully invisible" or
                                 string.format("%d%% visible", math.Round((invisLevel / 255) * 100))
                local durationText = duration > 0 and string.format(" for %d seconds", duration) or " (permanent)"

                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(0,255,213),
                    ["header"] = "Invisible",
                    ["color2"] = Color(255,255,255),
                    ["text"] = string.format("Made %s %s%s", targetPlayer:Nick(), levelText, durationText),
                    ["ply"] = ply
                })

                if targetPlayer ~= ply then
                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(150,150,255),
                        ["header"] = "Invisible",
                        ["color2"] = Color(255,255,255),
                        ["text"] = string.format("You are now %s%s!", levelText, durationText),
                        ["ply"] = targetPlayer
                    })
                end

                gm3.Logger:Log(string.format("Admin %s made %s %s%s",
                    ply:Nick(), targetPlayer:Nick(), levelText, durationText))

            else
                -- Restore visibility
                RestoreVisibility(targetPlayer)

                -- Send network message
                net.Start("gm3:tools:invisible")
                    net.WriteEntity(targetPlayer)
                    net.WriteBool(false)
                    net.WriteInt(255, 9)
                    net.WriteBool(false)
                net.Broadcast()

                -- Notifications
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(0,255,213),
                    ["header"] = "Invisible",
                    ["color2"] = Color(255,255,255),
                    ["text"] = string.format("Made %s visible again", targetPlayer:Nick()),
                    ["ply"] = ply
                })

                if targetPlayer ~= ply then
                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(50,255,50),
                        ["header"] = "Invisible",
                        ["color2"] = Color(255,255,255),
                        ["text"] = "You are now visible again!",
                        ["ply"] = targetPlayer
                    })
                end

                gm3.Logger:Log(string.format("Admin %s made %s visible",
                    ply:Nick(), targetPlayer:Nick()))
            end
        end,
        "Visual" -- Category for visual effects
    )
    gm3:addTool(tool)

    -- Helper function to restore visibility
    function RestoreVisibility(targetPlayer)
        if not IsValid(targetPlayer) or not gm3.invisiblePlayers[targetPlayer] then return end

        local invisData = gm3.invisiblePlayers[targetPlayer]

        -- Restore player visibility
        targetPlayer:SetRenderMode(invisData.originalRenderMode or RENDERMODE_NORMAL)
        targetPlayer:SetColor(invisData.originalColor or Color(255, 255, 255, 255))
        targetPlayer:DrawShadow(true)
        targetPlayer:SetNWBool("gm3_invisible", false)
        targetPlayer:SetNWInt("gm3_invisible_level", 255)
        targetPlayer:SetNWBool("gm3_invisible_ghost", false)

        -- Restore weapon visibility
        local weapon = targetPlayer:GetActiveWeapon()
        if IsValid(weapon) then
            weapon:SetRenderMode(RENDERMODE_NORMAL)
            weapon:SetColor(Color(255, 255, 255, 255))
        end

        -- Remove hooks
        hook.Remove("PlayerSwitchWeapon", "GM3_Invisible_WeaponSwitch_" .. targetPlayer:SteamID())

        -- Remove timer
        timer.Remove("gm3_invisible_" .. targetPlayer:SteamID())

        -- Clear from invisible list
        gm3.invisiblePlayers[targetPlayer] = nil
    end

    -- Maintain invisibility on spawn
    hook.Add("PlayerSpawn", "GM3_Invisible_Maintain", function(ply)
        timer.Simple(0.1, function()
            if IsValid(ply) and gm3.invisiblePlayers[ply] then
                local data = gm3.invisiblePlayers[ply]
                ply:SetRenderMode(RENDERMODE_TRANSCOLOR)
                ply:SetColor(Color(255, 255, 255, data.level))
            end
        end)
    end)

    -- Clean up on disconnect
    hook.Add("PlayerDisconnected", "GM3_Invisible_Cleanup", function(ply)
        if gm3.invisiblePlayers[ply] then
            hook.Remove("PlayerSwitchWeapon", "GM3_Invisible_WeaponSwitch_" .. ply:SteamID())
            timer.Remove("gm3_invisible_" .. ply:SteamID())
            gm3.invisiblePlayers[ply] = nil
        end
    end)

    -- Sync to new players
    hook.Add("PlayerInitialSpawn", "GM3_Invisible_Sync", function(ply)
        timer.Simple(2, function()
            if not IsValid(ply) then return end

            for player, data in pairs(gm3.invisiblePlayers) do
                if IsValid(player) then
                    net.Start("gm3:tools:invisible:status")
                        net.WriteEntity(player)
                        net.WriteBool(true)
                        net.WriteInt(data.level, 9)
                        net.WriteBool(data.ghostEffect)
                    net.Send(ply)
                end
            end
        end)
    end)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx

    local invisiblePlayers = {}

    -- Handle invisibility effects
    lyx:NetAdd("gm3:tools:invisible", {
        func = function()
            local ply = net.ReadEntity()
            local invisible = net.ReadBool()
            local level = net.ReadInt(9)
            local ghostEffect = net.ReadBool()

            if not IsValid(ply) then return end

            if invisible then
                invisiblePlayers[ply] = {
                    level = level,
                    ghost = ghostEffect
                }

                -- Play sound effect
                ply:EmitSound("npc/scanner/scanner_siren2.wav", 65, 150, 0.3)

                -- Create particle effect
                local effectData = EffectData()
                effectData:SetOrigin(ply:GetPos())
                effectData:SetScale(1)
                util.Effect("cball_bounce", effectData)
            else
                invisiblePlayers[ply] = nil

                -- Play reappear sound
                ply:EmitSound("npc/scanner/combat_scan5.wav", 65, 100, 0.5)
            end
        end
    })

    -- Sync status
    lyx:NetAdd("gm3:tools:invisible:status", {
        func = function()
            local ply = net.ReadEntity()
            local invisible = net.ReadBool()
            local level = net.ReadInt(9)
            local ghostEffect = net.ReadBool()

            if IsValid(ply) then
                if invisible then
                    invisiblePlayers[ply] = {
                        level = level,
                        ghost = ghostEffect
                    }
                else
                    invisiblePlayers[ply] = nil
                end
            end
        end
    })

    -- Ghost shimmer effect
    local Material_Refract = Material("models/spawn_effect")
    hook.Add("PrePlayerDraw", "GM3_Invisible_Ghost", function(ply)
        if invisiblePlayers[ply] and invisiblePlayers[ply].ghost then
            -- Apply refraction/distortion effect
            render.UpdateRefractTexture()
            render.SetMaterial(Material_Refract)

            -- Shimmer intensity based on invisibility level
            local intensity = 1 - (invisiblePlayers[ply].level / 255)
            Material_Refract:SetFloat("$refractamount", intensity * 0.1)

            -- Don't actually prevent drawing, just apply effect
            return false
        end
    end)

    -- HUD indicator for invisible players
    hook.Add("HUDPaint", "GM3_Invisible_HUD", function()
        if LocalPlayer():GetNWBool("gm3_invisible", false) then
            local level = LocalPlayer():GetNWInt("gm3_invisible_level", 255)
            local visibility = math.Round((level / 255) * 100)

            surface.SetFont("DermaLarge")
            local text = level == 0 and "INVISIBLE" or string.format("INVISIBILITY: %d%%", 100 - visibility)
            local tw, th = surface.GetTextSize(text)

            local x = ScrW() / 2
            local y = ScrH() - 150

            -- Fading effect
            local alpha = level == 0 and 100 or (150 - level/2)

            -- Background
            draw.RoundedBox(8, x - tw/2 - 10, y - th/2 - 5, tw + 20, th + 10,
                Color(20, 20, 40, alpha * 0.8))

            -- Text with ghostly color
            local textAlpha = math.sin(CurTime() * 3) * 50 + (alpha + 50)
            draw.SimpleText(text, "DermaLarge", x, y,
                Color(150, 150, 255, textAlpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end)

    -- Particle effects for invisible players
    hook.Add("Think", "GM3_Invisible_Particles", function()
        for ply, data in pairs(invisiblePlayers) do
            if IsValid(ply) and data.ghost and data.level < 100 then
                if math.random() < 0.02 then -- 2% chance per frame
                    local pos = ply:GetPos() + Vector(
                        math.random(-20, 20),
                        math.random(-20, 20),
                        math.random(10, 60)
                    )

                    local emitter = ParticleEmitter(pos)
                    if emitter then
                        local particle = emitter:Add("sprites/light_glow02_add", pos)
                        if particle then
                            particle:SetDieTime(0.5)
                            particle:SetStartAlpha(30)
                            particle:SetEndAlpha(0)
                            particle:SetStartSize(math.random(5, 10))
                            particle:SetEndSize(0)
                            particle:SetColor(150, 150, 255)
                            particle:SetVelocity(VectorRand() * 10)
                        end
                        emitter:Finish()
                    end
                end
            elseif not IsValid(ply) then
                invisiblePlayers[ply] = nil
            end
        end
    end)

    -- Draw invisible players with special rendering
    hook.Add("PreDrawHalos", "GM3_Invisible_Halos", function()
        local invisibleEnts = {}
        for ply, data in pairs(invisiblePlayers) do
            if IsValid(ply) and ply ~= LocalPlayer() and data.level < 50 then
                -- Add subtle halo for very invisible players (admin vision)
                if LocalPlayer():IsAdmin() then
                    table.insert(invisibleEnts, ply)
                end
            end
        end

        if #invisibleEnts > 0 then
            halo.Add(invisibleEnts, Color(150, 150, 255, 50), 2, 2, 1, true, true)
        end
    end)
end