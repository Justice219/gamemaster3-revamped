gm3 = gm3
lyx = lyx

if SERVER then
    -- Register network strings on server (server -> client only)
    lyx:NetAdd("gm3:tools:freeze")
    lyx:NetAdd("gm3:tools:freeze:status")

    gm3 = gm3
    lyx = lyx

    -- Table to track frozen players
    gm3.frozenPlayers = gm3.frozenPlayers or {}

    local tool = GM3Module.new(
        "Freeze",
        "Freeze or unfreeze players in place - they cannot move, shoot, or interact",
        "GM3 Assistant",
        {
            ["Target Player"] = {
                type = "player",
                def = ""
            },
            ["Action"] = {
                type = "string",
                def = "toggle" -- Options: toggle, freeze, unfreeze
            },
            ["Freeze Type"] = {
                type = "string",
                def = "full" -- Options: full, movement, weapons
            },
            ["Ice Block Effect"] = {
                type = "boolean",
                def = true -- Visual ice block around player
            },
            ["Duration (0 = Infinite)"] = {
                type = "number",
                def = 0 -- Duration in seconds, 0 for permanent
            }
        },
        function(ply, args)
            -- Get the target player using gm3 helper function
            local targetPlayer = gm3:GetPlayerBySteamID(args["Target Player"])
            if not IsValid(targetPlayer) then
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(255,100,100),
                    ["header"] = "Freeze",
                    ["color2"] = Color(255,255,255),
                    ["text"] = "Target player not found! Please select a valid player.",
                    ["ply"] = ply
                })
                return
            end

            local action = string.lower(args["Action"])
            local freezeType = string.lower(args["Freeze Type"])
            local iceEffect = args["Ice Block Effect"]
            local duration = math.max(0, args["Duration (0 = Infinite)"])

            -- Determine freeze state
            local shouldFreeze = false
            if action == "toggle" then
                shouldFreeze = not gm3.frozenPlayers[targetPlayer]
            elseif action == "freeze" then
                shouldFreeze = true
            elseif action == "unfreeze" then
                shouldFreeze = false
            else
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(255,100,100),
                    ["header"] = "Freeze",
                    ["color2"] = Color(255,255,255),
                    ["text"] = "Invalid action! Use: toggle, freeze, or unfreeze",
                    ["ply"] = ply
                })
                return
            end

            -- Apply freeze
            if shouldFreeze then
                -- Store freeze data
                gm3.frozenPlayers[targetPlayer] = {
                    type = freezeType,
                    iceEffect = iceEffect,
                    originalSpeed = targetPlayer:GetWalkSpeed(),
                    originalRunSpeed = targetPlayer:GetRunSpeed(),
                    originalJumpPower = targetPlayer:GetJumpPower()
                }

                -- Apply freeze based on type
                if freezeType == "full" then
                    -- Full freeze - no movement, no shooting
                    targetPlayer:Freeze(true)
                    targetPlayer:Lock()
                    targetPlayer:SetMoveType(MOVETYPE_NONE)

                elseif freezeType == "movement" then
                    -- Movement only freeze - can still look around and shoot
                    targetPlayer:SetWalkSpeed(1)
                    targetPlayer:SetRunSpeed(1)
                    targetPlayer:SetJumpPower(0)

                elseif freezeType == "weapons" then
                    -- Weapon freeze - can move but not use weapons
                    targetPlayer:StripWeapons()
                    targetPlayer:Give("weapon_crowbar") -- Give melee weapon for defense
                    targetPlayer:SelectWeapon("weapon_crowbar")
                else
                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(255,100,100),
                        ["header"] = "Freeze",
                        ["color2"] = Color(255,255,255),
                        ["text"] = "Invalid freeze type! Use: full, movement, or weapons",
                        ["ply"] = ply
                    })
                    gm3.frozenPlayers[targetPlayer] = nil
                    return
                end

                -- Set network variables
                targetPlayer:SetNWBool("gm3_frozen", true)
                targetPlayer:SetNWBool("gm3_frozen_ice", iceEffect)
                targetPlayer:SetNWString("gm3_frozen_type", freezeType)

                -- Create ice block if enabled
                if iceEffect and freezeType == "full" then
                    local iceBlock = ents.Create("prop_physics")
                    if IsValid(iceBlock) then
                        iceBlock:SetModel("models/hunter/blocks/cube075x075x075.mdl")
                        iceBlock:SetPos(targetPlayer:GetPos())
                        iceBlock:SetAngles(Angle(0, 0, 0))
                        iceBlock:SetMaterial("models/shiny")
                        iceBlock:SetColor(Color(150, 200, 255, 200))
                        iceBlock:SetRenderMode(RENDERMODE_TRANSCOLOR)
                        iceBlock:Spawn()
                        iceBlock:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
                        iceBlock:SetNotSolid(true)
                        iceBlock:SetParent(targetPlayer)

                        gm3.frozenPlayers[targetPlayer].iceBlock = iceBlock
                    end
                end

                -- Set up duration timer if specified
                if duration > 0 then
                    timer.Create("gm3_freeze_" .. targetPlayer:SteamID(), duration, 1, function()
                        if IsValid(targetPlayer) and gm3.frozenPlayers[targetPlayer] then
                            -- Unfreeze automatically
                            UnfreezePlayer(targetPlayer)

                            lyx:MessagePlayer({
                                ["type"] = "header",
                                ["color1"] = Color(255,200,0),
                                ["header"] = "Freeze",
                                ["color2"] = Color(255,255,255),
                                ["text"] = "Your freeze has expired!",
                                ["ply"] = targetPlayer
                            })
                        end
                    end)
                else
                    -- Remove any existing timer
                    timer.Remove("gm3_freeze_" .. targetPlayer:SteamID())
                end

                -- Send network message for effects
                net.Start("gm3:tools:freeze")
                    net.WriteEntity(targetPlayer)
                    net.WriteBool(true)
                    net.WriteBool(iceEffect)
                    net.WriteString(freezeType)
                net.Broadcast()

                -- Notification messages
                local durationText = duration > 0 and string.format(" for %d seconds", duration) or " (permanent)"
                local typeText = freezeType == "full" and "completely" or
                                (freezeType == "movement" and "movement") or "weapons"

                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(0,255,213),
                    ["header"] = "Freeze",
                    ["color2"] = Color(255,255,255),
                    ["text"] = string.format("Froze %s (%s)%s", targetPlayer:Nick(), typeText, durationText),
                    ["ply"] = ply
                })

                if targetPlayer ~= ply then
                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(100,200,255),
                        ["header"] = "Freeze",
                        ["color2"] = Color(255,255,255),
                        ["text"] = string.format("You have been frozen (%s)%s!", typeText, durationText),
                        ["ply"] = targetPlayer
                    })
                end

                gm3.Logger:Log(string.format("Admin %s froze %s (%s)%s",
                    ply:Nick(), targetPlayer:Nick(), typeText, durationText))

            else
                -- Unfreeze player
                UnfreezePlayer(targetPlayer)

                -- Send network message for effects
                net.Start("gm3:tools:freeze")
                    net.WriteEntity(targetPlayer)
                    net.WriteBool(false)
                    net.WriteBool(false)
                    net.WriteString("")
                net.Broadcast()

                -- Notification messages
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(0,255,213),
                    ["header"] = "Freeze",
                    ["color2"] = Color(255,255,255),
                    ["text"] = string.format("Unfroze %s", targetPlayer:Nick()),
                    ["ply"] = ply
                })

                if targetPlayer ~= ply then
                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(50,255,50),
                        ["header"] = "Freeze",
                        ["color2"] = Color(255,255,255),
                        ["text"] = "You have been unfrozen!",
                        ["ply"] = targetPlayer
                    })
                end

                gm3.Logger:Log(string.format("Admin %s unfroze %s",
                    ply:Nick(), targetPlayer:Nick()))
            end
        end,
        "Control" -- Category for tools affecting player control/movement
    )
    gm3:addTool(tool)

    -- Helper function to unfreeze player
    function UnfreezePlayer(targetPlayer)
        if not IsValid(targetPlayer) or not gm3.frozenPlayers[targetPlayer] then return end

        local freezeData = gm3.frozenPlayers[targetPlayer]

        -- Restore based on freeze type
        if freezeData.type == "full" then
            targetPlayer:Freeze(false)
            targetPlayer:UnLock()
            targetPlayer:SetMoveType(MOVETYPE_WALK)
        elseif freezeData.type == "movement" then
            targetPlayer:SetWalkSpeed(freezeData.originalSpeed or 200)
            targetPlayer:SetRunSpeed(freezeData.originalRunSpeed or 400)
            targetPlayer:SetJumpPower(freezeData.originalJumpPower or 200)
        end

        -- Remove ice block if exists
        if IsValid(freezeData.iceBlock) then
            freezeData.iceBlock:Remove()
        end

        -- Clear network variables
        targetPlayer:SetNWBool("gm3_frozen", false)
        targetPlayer:SetNWBool("gm3_frozen_ice", false)
        targetPlayer:SetNWString("gm3_frozen_type", "")

        -- Remove timer if exists
        timer.Remove("gm3_freeze_" .. targetPlayer:SteamID())

        -- Clear from frozen list
        gm3.frozenPlayers[targetPlayer] = nil
    end

    -- Clean up on disconnect
    hook.Add("PlayerDisconnected", "GM3_Freeze_Cleanup", function(ply)
        if gm3.frozenPlayers[ply] then
            if IsValid(gm3.frozenPlayers[ply].iceBlock) then
                gm3.frozenPlayers[ply].iceBlock:Remove()
            end
            gm3.frozenPlayers[ply] = nil
            timer.Remove("gm3_freeze_" .. ply:SteamID())
        end
    end)

    -- Unfreeze on death
    hook.Add("PlayerDeath", "GM3_Freeze_Death", function(ply)
        if gm3.frozenPlayers[ply] then
            UnfreezePlayer(ply)
        end
    end)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx

    local frozenPlayers = {}

    -- Create freeze visual effects
    lyx:NetAdd("gm3:tools:freeze", {
        func = function()
            local ply = net.ReadEntity()
            local frozen = net.ReadBool()
            local iceEffect = net.ReadBool()
            local freezeType = net.ReadString()

            if not IsValid(ply) then return end

            if frozen then
                frozenPlayers[ply] = {
                    ice = iceEffect,
                    type = freezeType
                }

                -- Play freeze sound
                ply:EmitSound("physics/glass/glass_impact_bullet1.wav", 75, 150, 1)

                -- Create freeze particle effect
                local effectData = EffectData()
                effectData:SetOrigin(ply:GetPos())
                effectData:SetNormal(Vector(0, 0, 1))
                effectData:SetScale(2)
                util.Effect("GlassImpact", effectData)

                -- Screen effect for frozen player
                if ply == LocalPlayer() then
                    local iceOverlay = vgui.Create("DPanel")
                    iceOverlay:SetSize(ScrW(), ScrH())
                    iceOverlay:SetPos(0, 0)
                    iceOverlay.Paint = function(s, w, h)
                        -- Ice overlay effect
                        surface.SetDrawColor(150, 200, 255, 50)
                        surface.DrawRect(0, 0, w, h)

                        -- Frost edges
                        for i = 0, 10 do
                            local alpha = 100 - (i * 10)
                            surface.SetDrawColor(150, 200, 255, alpha)
                            surface.DrawOutlinedRect(i * 10, i * 10, w - i * 20, h - i * 20, 2)
                        end
                    end
                    ply.FreezeOverlay = iceOverlay
                end
            else
                frozenPlayers[ply] = nil

                -- Play unfreeze sound
                ply:EmitSound("physics/glass/glass_sheet_break1.wav", 75, 100, 0.5)

                -- Remove overlay
                if ply == LocalPlayer() and IsValid(ply.FreezeOverlay) then
                    ply.FreezeOverlay:Remove()
                    ply.FreezeOverlay = nil
                end
            end
        end
    })

    -- Sync status for new players
    lyx:NetAdd("gm3:tools:freeze:status", {
        func = function()
            local ply = net.ReadEntity()
            local frozen = net.ReadBool()
            local iceEffect = net.ReadBool()
            local freezeType = net.ReadString()

            if IsValid(ply) then
                if frozen then
                    frozenPlayers[ply] = {
                        ice = iceEffect,
                        type = freezeType
                    }
                else
                    frozenPlayers[ply] = nil
                end
            end
        end
    })

    -- HUD indicator for frozen players
    hook.Add("HUDPaint", "GM3_Freeze_HUD", function()
        if LocalPlayer():GetNWBool("gm3_frozen", false) then
            local freezeType = LocalPlayer():GetNWString("gm3_frozen_type", "full")

            surface.SetFont("DermaLarge")
            local text = "FROZEN"
            if freezeType == "movement" then
                text = "MOVEMENT FROZEN"
            elseif freezeType == "weapons" then
                text = "WEAPONS DISABLED"
            end

            local tw, th = surface.GetTextSize(text)
            local x = ScrW() / 2
            local y = 100

            -- Pulsing effect
            local pulse = math.sin(CurTime() * 2) * 0.3 + 0.7
            local alpha = 255 * pulse

            -- Background
            draw.RoundedBox(8, x - tw/2 - 10, y - th/2 - 5, tw + 20, th + 10,
                Color(0, 50, 100, alpha * 0.8))

            -- Text with ice blue color
            draw.SimpleText(text, "DermaLarge", x, y,
                Color(150, 200, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- Ice border
            surface.SetDrawColor(150, 200, 255, alpha * 0.7)
            surface.DrawOutlinedRect(x - tw/2 - 10, y - th/2 - 5, tw + 20, th + 10, 2)
        end
    end)

    -- Ice particle effect for frozen players
    hook.Add("Think", "GM3_Freeze_Particles", function()
        for ply, data in pairs(frozenPlayers) do
            if IsValid(ply) and data.ice and data.type == "full" then
                if math.random() < 0.1 then -- 10% chance per frame
                    local pos = ply:GetPos() + Vector(
                        math.random(-30, 30),
                        math.random(-30, 30),
                        math.random(0, 70)
                    )

                    local emitter = ParticleEmitter(pos)
                    if emitter then
                        local particle = emitter:Add("effects/splash2", pos)
                        if particle then
                            particle:SetDieTime(2)
                            particle:SetStartAlpha(150)
                            particle:SetEndAlpha(0)
                            particle:SetStartSize(math.random(1, 3))
                            particle:SetEndSize(0)
                            particle:SetColor(150, 200, 255)
                            particle:SetVelocity(Vector(0, 0, -30))
                            particle:SetGravity(Vector(0, 0, -50))
                        end
                        emitter:Finish()
                    end
                end
            elseif not IsValid(ply) then
                frozenPlayers[ply] = nil
            end
        end
    end)
end