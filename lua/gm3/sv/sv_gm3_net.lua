gm3 = gm3
gm3.tools = gm3.tools or {}
gm3.ranks = gm3.ranks or {}
gm3.commands = gm3.commands or {}
gm3.settings = gm3.settings or {}
lyx = lyx

if SERVER then
    AddCSLuaFile("effects/eff_gm3_artilleryblast.lua")
    cleanup.Register("gm3_waypoint")
end

--[[
--! GM3 Network Message Handler
--! Uses LYX's secure networking with authentication and rate limiting
--! All messages include proper security checks and error handling
--]]

do
    local function loadSharedFile(str)
        if SERVER then AddCSLuaFile(str) return end
        include(str)
        gm3.Logger:Log("Loaded shared file: " .. str)
    end 
end

do
    local function ReadSelectionEntities(maxCount)
        local count = net.ReadUInt(12)
        if not count or count > maxCount then
            return nil, "Invalid selection size"
        end
        local list = {}
        for i = 1, count do
            local ent = net.ReadEntity()
            if IsValid(ent) then
                table.insert(list, ent)
            end
        end
        return list
    end

    local function ReadEntityVectorPairs(maxCount)
        local count = net.ReadUInt(12)
        if not count or count > maxCount then
            return nil
        end

        local results = {}
        for i = 1, count do
            local ent = net.ReadEntity()
            local pos = net.ReadVector()
            if IsValid(ent) and isvector(pos) then
                results[#results + 1] = {ent = ent, pos = pos}
            end
        end
        return results
    end

    local GM3_PatrolControllers = GM3_PatrolControllers or {}
    local GM3_DefenseZones = GM3_DefenseZones or {}
    local GM3_SupplyCrates = GM3_SupplyCrates or {}
    local GM3_ReconSensors = GM3_ReconSensors or {}
    local vector_origin = vector_origin or Vector(0, 0, 0)
    local function GM3_GetSafeSpawnPos(pos)
        local hullTrace = util.TraceHull({
            start = pos + Vector(0, 0, 72),
            endpos = pos - Vector(0, 0, 128),
            mins = Vector(-16, -16, 0),
            maxs = Vector(16, 16, 72),
            mask = MASK_SOLID
        })

        if hullTrace.Hit then
            return hullTrace.HitPos + hullTrace.HitNormal * 24
        end

        local lineTrace = util.TraceLine({
            start = pos + Vector(0, 0, 120),
            endpos = pos - Vector(0, 0, 256),
            mask = MASK_SOLID
        })

        if lineTrace.Hit then
            return lineTrace.HitPos + lineTrace.HitNormal * 24
        end

        return pos + Vector(0, 0, 24)
    end

    local GM3_SupplyTypes = {
        ammo = {
            model = "models/items/ammocrate_ar2.mdl",
            uses = 3,
            apply = function(ply)
                ply:GiveAmmo(60, "SMG1", true)
                ply:GiveAmmo(30, "AR2", true)
                ply:GiveAmmo(6, "Buckshot", true)
                ply:EmitSound("items/ammo_pickup.wav")
            end
        },
        medical = {
            model = "models/Items/HealthKit.mdl",
            uses = 3,
            apply = function(ply)
                local maxHealth = ply:GetMaxHealth() or 100
                ply:SetHealth(math.min(maxHealth, ply:Health() + 60))
                ply:SetArmor(math.min(100, ply:Armor() + 20))
                ply:EmitSound("items/smallmedkit1.wav")
            end
        },
        tech = {
            model = "models/Items/combine_rifle_cartridge01.mdl",
            uses = 2,
            apply = function(ply)
                ply:Give("weapon_frag")
                ply:Give("weapon_slam")
                ply:EmitSound("items/ammo_pickup.wav")
            end
        },
        shield = {
            model = "models/Items/battery.mdl",
            uses = 2,
            apply = function(ply)
                ply:SetArmor(math.min(150, ply:Armor() + 75))
                ply:EmitSound("items/battery_pickup.wav")
            end
        },
        turret = {
            model = "models/props_combine/combine_mortar01a.mdl",
            uses = 1,
            apply = function(ply, ent)
                local turret = ents.Create("npc_turret_floor")
                if not IsValid(turret) then return true end
                turret:SetPos(ent:GetPos() + Vector(0, 0, 4))
                turret:SetAngles(Angle(0, ply:EyeAngles().y, 0))
                turret:Spawn()
                turret:Activate()
                turret:AddRelationship("player D_LI 99")
                turret:SetKeyValue("spawnflags", "512")
                ply:EmitSound("npc/turret_floor/deploy.wav")
                return true
            end
        }
    }

    local GM3_WaypointIcons = {
        flag = true,
        target = true,
        star = true,
        alert = true,
        gear = true
    }

    local GM3_SignalColors = {
        [0] = Color(255, 200, 80),
        [1] = Color(255, 80, 80),
        [2] = Color(100, 200, 255),
        [3] = Color(140, 255, 160),
        [4] = Color(190, 150, 255)
    }

    local function GM3_CreateSmokeScreen(pos, radius, duration)
        local effectData = EffectData()
        effectData:SetOrigin(pos)
        effectData:SetScale(math.Clamp(radius / 120, 0.5, 3))
        util.Effect("smoke_explosion", effectData, true, true)

        local smokestack = ents.Create("env_smokestack")
        if not IsValid(smokestack) then return end
        smokestack:SetPos(pos)
        smokestack:SetKeyValue("InitialState", "1")
        smokestack:SetKeyValue("SpreadSpeed", math.Clamp(radius, 40, 250))
        smokestack:SetKeyValue("Speed", math.Clamp(radius, 40, 250))
        smokestack:SetKeyValue("StartSize", math.Clamp(radius * 0.4, 48, 220))
        smokestack:SetKeyValue("EndSize", math.Clamp(radius * 0.7, 96, 320))
        smokestack:SetKeyValue("Rate", math.Clamp(radius * 2, 32, 500))
        smokestack:SetKeyValue("JetLength", math.Clamp(radius * 0.7, 64, 256))
        smokestack:SetKeyValue("WindAngle", "0")
        smokestack:SetKeyValue("WindSpeed", "0")
        smokestack:SetKeyValue("SmokeMaterial", "particle/particle_smokegrenade")
        smokestack:SetKeyValue("rendercolor", "180 180 180")
        smokestack:SetKeyValue("renderamt", "220")
        smokestack:Spawn()
        smokestack:Activate()
        smokestack:Fire("TurnOn")

        timer.Simple(duration or 12, function()
            if IsValid(smokestack) then
                smokestack:Fire("TurnOff")
                smokestack:Remove()
            end
        end)
    end

    local function GM3_BroadcastArtilleryPreview(ply, pos, radius, delay, profileName)
        net.Start("gm3ZeusCam_artilleryPreview")
            net.WriteVector(pos)
            net.WriteUInt(math.Clamp(math.floor(radius), 50, 1023), 12)
            net.WriteFloat(math.max(delay, 0))
            net.WriteString(profileName or "default")
        net.Broadcast()
    end

    local FireSupportImpactConfig = {
        precision = {
            effect = "Explosion",
            sound = "weapons/explode3.wav",
            damage = 240,
            radiusMul = 0.45,
            scorch = true,
            screenShake = 6,
            warning = 5,
            customEffect = "gm3_artilleryblast",
            customEffectScale = 1.2,
            customEffectColor = Color(255, 250, 220)
        },
        barrage = {
            effect = "HelicopterMegaBomb",
            sound = "ambient/explosions/explode_9.wav",
            damage = 160,
            radiusMul = 0.65,
            scorch = true,
            effect2 = "Explosion",
            screenShake = 8,
            warning = 8,
            customEffect = "gm3_artilleryblast",
            customEffectScale = 1.8,
            customEffectColor = Color(255, 190, 120)
        },
        carpet = {
            effect = "HelicopterMegaBomb",
            effect2 = "Explosion",
            effectScale = 2.8,
            effect2Scale = 1.5,
            customEffect = "gm3_artilleryblast",
            customEffectScale = 2.6,
            customEffectColor = Color(255, 140, 80),
            sound = "ambient/explosions/explode_6.wav",
            damage = 130,
            radiusMul = 0.85,
            scorch = true,
            sparks = true,
            screenShake = 9,
            warning = 10
        },
        incendiary = {
            effect = "Explosion",
            sound = "ambient/fire/ignite.wav",
            damage = 40,
            radiusMul = 0.55,
            scorch = true,
            ignite = true,
            screenShake = 4,
            warning = 7,
            customEffect = "gm3_artilleryblast",
            customEffectScale = 1.6,
            customEffectColor = Color(255, 140, 40)
        },
        emp = {
            effect = "cball_explode",
            sound = "ambient/energy/newspark04.wav",
            damage = 10,
            radiusMul = 0.6,
            shock = true,
            screenShake = 6,
            warning = 6,
            customEffect = "gm3_artilleryblast",
            customEffectScale = 1.4,
            customEffectColor = Color(160, 200, 255)
        }
    }

    local function GM3_PlayImpactEffect(name, pos, scale, color)
        if not name then return end
        local effect = EffectData()
        effect:SetOrigin(pos)
        if scale then
            effect:SetScale(scale)
        end
        if color then
            effect:SetAngles(Angle(color.r or 255, color.g or 255, color.b or 255))
        end
        util.Effect(name, effect, true, true)
    end

    local function GM3_HandleArtilleryImpact(ply, pos, radius, profileName, isSmoke)
        if isSmoke then
            GM3_CreateSmokeScreen(pos, radius, 14)
            sound.Play("weapons/smokegrenade/sg_explode.wav", pos, 90, 110)
            return
        end

        local config = FireSupportImpactConfig[profileName] or FireSupportImpactConfig.barrage
        local blastRadius = radius * (config.radiusMul or 0.4)
        util.BlastDamage(ply, ply, pos, blastRadius, config.damage or 150)

        local baseScale = math.Clamp(blastRadius / 100, 0.6, 3.5)
        GM3_PlayImpactEffect(config.effect or "Explosion", pos, config.effectScale or baseScale)
        if config.sparks then
            GM3_PlayImpactEffect("cball_explode", pos, baseScale + 0.3)
        end
        if config.effect2 then
            GM3_PlayImpactEffect(config.effect2, pos, config.effect2Scale or baseScale * 0.8)
        end
        if config.customEffect then
            GM3_PlayImpactEffect(config.customEffect, pos, config.customEffectScale or (baseScale * 1.5), config.customEffectColor)
        end

        util.ScreenShake(pos, config.screenShake or 5, 5, 1.5, radius * 3)
        if config.scorch then
            util.Decal("Scorch", pos + Vector(0, 0, 12), pos - Vector(0, 0, 12))
        end
        sound.Play(config.sound or "ambient/explosions/explode_4.wav", pos, 120, 100)

        if config.ignite or config.shock then
            for _, ent in ipairs(ents.FindInSphere(pos, blastRadius)) do
                if not IsValid(ent) then continue end
                if config.ignite and (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then
                    ent:Ignite(5, 30)
                end
                if config.shock and ent:IsPlayer() then
                    ent:EmitSound("ambient/energy/zap1.wav")
                    local dmg = DamageInfo()
                    dmg:SetDamage(5)
                    dmg:SetDamageType(DMG_SHOCK)
                    dmg:SetAttacker(IsValid(ply) and ply or game.GetWorld())
                    ent:TakeDamageInfo(dmg)
                    ent:ViewPunch(Angle(math.Rand(-4, 4), math.Rand(-6, 6), 0))
                    ent:ScreenFade(SCREENFADE.MODULATE, Color(150, 200, 255, 120), 0.3, 0.3)
                end
            end
        end
    end

    local function GM3_GatherReconContacts(origin, radius, reference)
        local contacts = {}
        for _, ent in ipairs(ents.FindInSphere(origin, radius)) do
            if not IsValid(ent) then continue end
            if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then
                local velocity = ent.GetVelocity and ent:GetVelocity() or vector_origin
                local dir = velocity:GetNormalized()
                if dir.x ~= dir.x or dir.y ~= dir.y or dir.z ~= dir.z then
                    dir = vector_origin
                end
                local friendly = false
                if ent:IsPlayer() and IsValid(reference) and reference:IsPlayer() then
                    friendly = ent:Team() == reference:Team()
                elseif ent:IsNPC() and IsValid(reference) and reference:IsPlayer() and ent.Disposition then
                    friendly = ent:Disposition(reference) ~= D_HT
                end
                table.insert(contacts, {
                    pos = ent:WorldSpaceCenter(),
                    type = ent:IsPlayer() and "player" or "npc",
                    class = ent:GetClass(),
                    label = ent:IsPlayer() and ent:Nick() or ent:GetClass(),
                    dir = dir,
                    speed = velocity:Length(),
                    friendly = friendly
                })
            elseif ent:GetClass() == "prop_physics" then
                table.insert(contacts, {
                    pos = ent:WorldSpaceCenter(),
                    type = "prop",
                    class = ent:GetClass(),
                    label = "Prop",
                    dir = vector_origin,
                    speed = 0,
                    friendly = false
                })
            end
            if #contacts >= 32 then break end
        end
        return contacts
    end

    local function GM3_SendReconData(ply, origin, radius)
        local contacts = GM3_GatherReconContacts(origin, radius, ply)
        if not IsValid(ply) then return end
        net.Start("gm3ZeusCam_reconData")
            net.WriteVector(origin)
            net.WriteUInt(radius, 12)
            net.WriteUInt(#contacts, 8)
            for _, contact in ipairs(contacts) do
                net.WriteVector(contact.pos)
                net.WriteString(contact.type or "")
                net.WriteString(contact.class or "")
                net.WriteString(contact.label or "")
                net.WriteVector(contact.dir or vector_origin)
                net.WriteFloat(contact.speed or 0)
                net.WriteBool(contact.friendly or false)
            end
        net.Send(ply)
        return contacts
    end

    function gm3:RemoveFromTable(tbl, valueToRemove)
        PrintTable(tbl)
        local newTable = {}
        for k, v in pairs(tbl) do
            if v[valueToRemove] then
                v[valueToRemove] = nil
            end
        end
        PrintTable(newTable)
        return newTable
    end

    --[[
        Security check endpoint - Validates if player has GM3 access
        Rate limited to prevent spam
    ]]
    lyx:NetAdd("gm3:security:check", {
        func = function(ply, len)
            local hasAccess = gm3:SecurityCheck(ply)

            net.Start("gm3:security:check")
            net.WriteBool(hasAccess)
            net.Send(ply)

            if not hasAccess then
                lyx.Logger:Log("Security check failed for " .. ply:Nick(), 2)
            end
        end,
        rateLimit = 5  -- Max 5 checks per second
    })
    
    --[[
        Sync request - Sends GM3 data to authorized players
        Includes tools, ranks, commands, and settings
    ]]
    lyx:NetAdd("gm3:sync:request", {
        func = function(ply, len)
            -- Verify player has GM3 access
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized sync request from " .. ply:Nick(), 2)
                return
            end

            -- Prepare tools data (remove functions for network transmission)
            local tools = {}
            for k, v in pairs(gm3.tools) do
                tools[k] = {
                    name = v.name,
                    description = v.description,
                    args = v.args,
                    author = v.author,
                    category = v.category
                }
            end

            -- Prepare settings data
            local settings = {}
            for k, v in pairs(gm3.settings) do
                settings[k] = {
                    name = v.name,
                    value = v.value,
                    type = v.type,
                    nickname = v.nickname,
                    default = v.default,
                }
            end

            -- Send data to player
            net.Start("gm3:sync:request")
            net.WriteTable(tools)
            net.WriteTable(gm3.ranks)
            net.WriteTable(gm3.commands)
            net.WriteTable(settings)
            net.Send(ply)

            lyx.Logger:Log(string.format("Synced GM3 data to %s (tools: %d)", ply:Nick(), table.Count(tools)))
        end,
        auth = function(ply)
            return gm3:SecurityCheck(ply)
        end,
        rateLimit = 3  -- Max 3 syncs per second
    })

    function gm3:SyncPlayer(ply)
        net.Start("gm3:sync:request")
    
        --! We need to redo the table but remove all the functions
        local tools = {}
        for k, v in pairs(gm3.tools) do
            tools[k] = {
                name = v.name,
                description = v.description,
                args = v.args,
                author = v.author,
            }
        end
        local settings = {}
        for k, v in pairs(gm3.settings) do
            settings[k] = {
                name = v.name,
                value = v.value,
                type = v.type,
                nickname = v.nickname,
                default = v.default,
            }
        end

        net.WriteTable(tools)
        net.WriteTable(gm3.ranks)
        net.WriteTable(gm3.commands)
        net.WriteTable(settings)
        net.Send(ply)
    end
    
    --[[
        Tool execution endpoint - Runs GM3 admin tools
        Validates tool exists and player has permission
    ]]
    lyx:NetAdd("gm3:tool:run", {
        func = function(ply, len)
            -- Security check
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized tool execution attempt by " .. ply:Nick(), 2)
                return
            end

            -- Read and validate tool data
            local tool = net.ReadString()
            local args = net.ReadTable()

            -- Validate tool name length
            if #tool > 64 then
                lyx.Logger:Log("Invalid tool name length from " .. ply:Nick(), 2)
                return
            end

            -- Check if tool exists
            if not gm3:getTool(tool) then
                gm3.Logger:Log("Invalid tool execution: " .. tool .. " by " .. ply:Nick(), 2)
                return
            end

            -- Execute the tool
            gm3:runTool(tool, ply, args)
            lyx.Logger:Log("Player " .. ply:Nick() .. " executed tool: " .. tool)
        end,
        auth = function(ply)
            return gm3:SecurityCheck(ply)
        end,
        rateLimit = 10  -- Max 10 tool executions per second
    })
    
    --[[
        Add a new rank - Superadmin only
    ]]
    lyx:NetAdd("gm3:rank:add", {
        func = function(ply, len)
            -- Verify superadmin status
            if ply:GetUserGroup() ~= "superadmin" then
                lyx.Logger:Log("Non-superadmin rank add attempt by " .. ply:Nick(), 2)
                return
            end

            if not gm3:SecurityCheck(ply) then
                return
            end

            local rank = net.ReadString()

            -- Validate rank name
            if #rank > 32 or #rank < 1 then
                ply:ChatPrint("Invalid rank name length")
                return
            end

            gm3:RankAdd(rank)
            lyx.Logger:Log("Superadmin " .. ply:Nick() .. " added rank: " .. rank)
        end,
        auth = "superadmin",
        rateLimit = 5
    })
    
    --[[
        Remove a rank - Superadmin only
        Prevents removal of superadmin rank
    ]]
    lyx:NetAdd("gm3:rank:remove", {
        func = function(ply, len)
            -- Verify superadmin status
            if ply:GetUserGroup() ~= "superadmin" then
                lyx.Logger:Log("Non-superadmin rank remove attempt by " .. ply:Nick(), 2)
                return
            end

            if not gm3:SecurityCheck(ply) then
                return
            end

            local rank = net.ReadString()

            -- Validate rank name
            if #rank > 32 or #rank < 1 then
                ply:ChatPrint("Invalid rank name")
                return
            end

            -- Prevent removal of superadmin rank (security measure)
            if rank == "superadmin" then
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(0, 255, 213),
                    ["header"] = "Gamemaster 3",
                    ["color2"] = Color(255, 255, 255),
                    ["text"] = "You cannot remove the superadmin rank! It is required.",
                    ["ply"] = ply
                })
                lyx.Logger:Log("Attempted to remove superadmin rank: " .. ply:Nick(), 2)
                return
            end

            gm3:RankRemove(rank)
            lyx.Logger:Log("Superadmin " .. ply:Nick() .. " removed rank: " .. rank)
        end,
        auth = "superadmin",
        rateLimit = 5
    })

    --[[
        Save/Update rank settings - Superadmin only
    ]]
    lyx:NetAdd("gm3:rank:save", {
        func = function(ply, len)
            -- Verify superadmin status
            if ply:GetUserGroup() ~= "superadmin" then
                lyx.Logger:Log("Non-superadmin rank save attempt by " .. ply:Nick(), 2)
                return
            end

            if not gm3:SecurityCheck(ply) then
                return
            end

            local name = net.ReadString()
            local value = net.ReadBool()

            -- Validate rank name
            if #name > 32 or #name < 1 then
                ply:ChatPrint("Invalid rank name")
                return
            end

            -- Prevent modification of superadmin rank
            if name == "superadmin" and not value then
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(0, 255, 213),
                    ["header"] = "Gamemaster 3",
                    ["color2"] = Color(255, 255, 255),
                    ["text"] = "You cannot disable the superadmin rank!",
                    ["ply"] = ply
                })
                return
            end

            gm3:RankUpdate(name, value)
            lyx.Logger:Log("Rank updated: " .. name .. " = " .. tostring(value) .. " by " .. ply:Nick())
        end,
        auth = "superadmin",
        rateLimit = 10
    })
    
    --[[
        Create a new GM3 command
    ]]
    lyx:NetAdd("gm3:command:create", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized command creation by " .. ply:Nick(), 2)
                return
            end

            local tbl = net.ReadTable()

            -- Validate command data
            if not tbl or not tbl.command then
                ply:ChatPrint("Invalid command data")
                return
            end

            -- Validate command name length
            if #tbl.command > 32 or #tbl.command < 1 then
                ply:ChatPrint("Invalid command name length")
                return
            end

            gm3:CommandCreate(tbl, ply)
        end,
        auth = function(ply)
            return gm3:SecurityCheck(ply)
        end,
        rateLimit = 5
    })
    --[[
        Remove a GM3 command
    ]]
    lyx:NetAdd("gm3:command:remove", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized command removal by " .. ply:Nick(), 2)
                return
            end

            local name = net.ReadString()

            -- Validate command name
            if #name > 32 or #name < 1 then
                ply:ChatPrint("Invalid command name")
                return
            end

            gm3:CommandRemove(name, ply)
        end,
        auth = function(ply)
            return gm3:SecurityCheck(ply)
        end,
        rateLimit = 5
    })
    --[[
        Add rank permission to a command
    ]]
    lyx:NetAdd("gm3:command:addRank", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized rank addition by " .. ply:Nick(), 2)
                return
            end

            local cmd = net.ReadString()
            local rank = net.ReadString()

            -- Validate inputs
            if #cmd > 32 or #cmd < 1 or #rank > 32 or #rank < 1 then
                ply:ChatPrint("Invalid command or rank name")
                return
            end

            gm3:CommandAddRank(cmd, rank, ply)
        end,
        auth = function(ply)
            return gm3:SecurityCheck(ply)
        end,
        rateLimit = 10
    })
    --[[
        Remove rank permission from a command
    ]]
    lyx:NetAdd("gm3:command:removeRank", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized rank removal by " .. ply:Nick(), 2)
                return
            end

            local cmd = net.ReadString()
            local rank = net.ReadString()

            -- Validate inputs
            if #cmd > 32 or #cmd < 1 or #rank > 32 or #rank < 1 then
                ply:ChatPrint("Invalid command or rank name")
                return
            end

            gm3:CommandRemoveRank(cmd, rank, ply)
        end,
        auth = function(ply)
            return gm3:SecurityCheck(ply)
        end,
        rateLimit = 10
    })
    lyx:NetAdd("gm3ZeusCam_toggleState", {})

    --[[
        Zeus Cam - Toggle request
    ]]
    lyx:NetAdd("gm3ZeusCam_toggleRequest", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized Zeus cam toggle by " .. ply:Nick(), 2)
                ply:ChatPrint("You do not have access to Zeus mode.")
                return
            end

            local state = net.ReadBool()

            lyx:NetSend("gm3ZeusCam_toggleState", ply, function()
                net.WriteBool(state and true or false)
            end)
        end,
        auth = function(ply)
            return gm3:SecurityCheck(ply)
        end,
        rateLimit = 5
    })

    --[[
        Zeus Cam - Remove selected entities
    ]]
    lyx:NetAdd("gm3ZeusCam_removeSelected", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized Zeus cam removal by " .. ply:Nick(), 2)
                return
            end

            local entities, err = ReadSelectionEntities(100)
            if not entities then
                ply:ChatPrint("Invalid selection")
                return
            end

            for _, ent in ipairs(entities) do
                if IsValid(ent) then
                    ent:Remove()
                end
            end

            lyx.Logger:Log("Zeus cam removal by " .. ply:Nick())
        end,
        auth = function(ply)
            return gm3:SecurityCheck(ply)
        end,
        rateLimit = 10
    })
    --[[
        Zeus Cam - Move NPCs to camera position
    ]]
    lyx:NetAdd("gm3ZeusCam_moveToCamera", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized Zeus cam move by " .. ply:Nick(), 2)
                return
            end

            local entities = ReadSelectionEntities(100)
            local camPos = net.ReadVector()

            if not entities then
                ply:ChatPrint("Invalid NPC selection")
                return
            end

            if not isvector(camPos) then
                ply:ChatPrint("Invalid camera position")
                return
            end

            -- Move NPCs to camera position
            for _, ent in ipairs(entities) do
                if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) then
                    ent:SetLastPosition(camPos)
                    ent:SetSchedule(SCHED_FORCED_GO)
                end
            end

            lyx.Logger:Log("Zeus cam NPC move by " .. ply:Nick())
        end,
        auth = function(ply)
            return gm3:SecurityCheck(ply)
        end,
        rateLimit = 10
    })
    --[[
        Zeus Cam - Move NPCs to clicked position
    ]]
    lyx:NetAdd("gm3ZeusCam_moveToClick", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized Zeus cam click move by " .. ply:Nick(), 2)
                return
            end

            local entities = ReadSelectionEntities(100)
            local targetPos = net.ReadVector()

            if not entities then
                ply:ChatPrint("Invalid NPC selection")
                return
            end

            if not isvector(targetPos) then
                ply:ChatPrint("Invalid target position")
                return
            end

            -- Move NPCs to clicked position
            for _, ent in ipairs(entities) do
                if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) then
                    ent:SetLastPosition(targetPos)
                    ent:SetSchedule(SCHED_FORCED_GO)
                end
            end

            lyx.Logger:Log("Zeus cam click move by " .. ply:Nick())
        end,
        auth = function(ply)
            return gm3:SecurityCheck(ply)
        end,
        rateLimit = 10
    })
    --[[
        Zeus Cam - Teleport players to camera position
    ]]
    lyx:NetAdd("gm3ZeusCam_playersToCamera", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized Zeus player move by " .. ply:Nick(), 2)
                return
            end

            local players = ReadSelectionEntities(50)
            local camPos = net.ReadVector()

            if not players or not isvector(camPos) then
                ply:ChatPrint("Invalid player selection or position")
                return
            end

            for _, ent in ipairs(players) do
                if IsValid(ent) and ent:IsPlayer() then
                    ent:SetPos(camPos + Vector(0, 0, 10))
                end
            end

            lyx.Logger:Log("Zeus cam player teleport (camera) by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 5
    })
    --[[
        Zeus Cam - Teleport players to cursor position
    ]]
    lyx:NetAdd("gm3ZeusCam_playersToCursor", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized Zeus player cursor move by " .. ply:Nick(), 2)
                return
            end

            local players = ReadSelectionEntities(50)
            local targetPos = net.ReadVector()

            if not players or not isvector(targetPos) then
                ply:ChatPrint("Invalid player selection or position")
                return
            end

            for _, ent in ipairs(players) do
                if IsValid(ent) and ent:IsPlayer() then
                    ent:SetPos(targetPos + Vector(0, 0, 5))
                end
            end

            lyx.Logger:Log("Zeus cam player teleport (cursor) by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 5
    })
    --[[
        Zeus Cam - Stop NPCs
    ]]
    lyx:NetAdd("gm3ZeusCam_stopNPCs", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized Zeus NPC stop by " .. ply:Nick(), 2)
                return
            end

            local entities = ReadSelectionEntities(100)
            if not entities then
                ply:ChatPrint("Invalid selection")
                return
            end

            for _, ent in ipairs(entities) do
                if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) then
                    ent:ClearGoalEntity()
                    ent:ClearSchedule()
                    ent:SetSchedule(SCHED_IDLE_STAND)
                end
            end

            lyx.Logger:Log("Zeus cam NPC stop by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 5
    })
    --[[
        Zeus Cam - Set NPC behavior
    ]]
    lyx:NetAdd("gm3ZeusCam_setNPCState", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized Zeus NPC state change by " .. ply:Nick(), 2)
                return
            end

            local entities = ReadSelectionEntities(100)
            local state = net.ReadString() or ""
            if not entities or #state < 1 then
                ply:ChatPrint("Invalid NPC selection")
                return
            end

            for _, ent in ipairs(entities) do
                if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) then
                    if ent.ClearSchedule then
                        ent:ClearSchedule()
                    end
                    if ent.ClearGoalEntity then
                        ent:ClearGoalEntity()
                    end

                    if state == "hold" then
                        if ent.SetLastPosition then
                            ent:SetLastPosition(ent:GetPos())
                        end
                        if ent.SetSchedule then
                            ent:SetSchedule(SCHED_IDLE_STAND)
                        end
                    elseif state == "defend" then
                        if ent.SetNPCState then
                            ent:SetNPCState(NPC_STATE_ALERT)
                        end
                        if ent.SetSchedule then
                            ent:SetSchedule(SCHED_ALERT_STAND)
                        end
                    elseif state == "patrol" then
                        if ent.SetNPCState then
                            ent:SetNPCState(NPC_STATE_IDLE)
                        end
                        if ent.SetSchedule then
                            ent:SetSchedule(SCHED_IDLE_WANDER)
                        end
                    elseif state == "aggressive" then
                        if ent.SetNPCState then
                            ent:SetNPCState(NPC_STATE_COMBAT)
                        end
                        if ent.SetSchedule then
                            ent:SetSchedule(SCHED_CHASE_ENEMY)
                        end
                    end
                end
            end

            lyx.Logger:Log("Zeus cam NPC state '" .. state .. "' by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 5
    })
    --[[
        Zeus Cam - Freeze/Unfreeze props
    ]]
    lyx:NetAdd("gm3ZeusCam_freezeProps", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized Zeus prop freeze by " .. ply:Nick(), 2)
                return
            end

            local entities = ReadSelectionEntities(150)
            local freeze = net.ReadBool()

            if not entities then
                ply:ChatPrint("Invalid prop selection")
                return
            end

            for _, ent in ipairs(entities) do
                if IsValid(ent) and ent:GetClass() == "prop_physics" then
                    local phys = ent:GetPhysicsObject()
                    if IsValid(phys) then
                        phys:EnableMotion(not freeze)
                        if freeze then
                            phys:Sleep()
                        end
                    end
                end
            end

            lyx.Logger:Log("Zeus cam prop freeze (" .. tostring(freeze) .. ") by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 5
    })
    --[[
        Zeus Cam - Teleport props
    ]]
    lyx:NetAdd("gm3ZeusCam_propsToCamera", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized Zeus prop teleport by " .. ply:Nick(), 2)
                return
            end

            local entities = ReadSelectionEntities(150)
            local camPos = net.ReadVector()

            if not entities or not isvector(camPos) then
                ply:ChatPrint("Invalid prop selection")
                return
            end

            for _, ent in ipairs(entities) do
                if IsValid(ent) and ent:GetClass() == "prop_physics" then
                    ent:SetPos(camPos + Vector(math.Rand(-10, 10), math.Rand(-10, 10), math.Rand(0, 6)))
                    local phys = ent:GetPhysicsObject()
                    if IsValid(phys) then
                        phys:SetVelocity(vector_origin)
                        phys:Sleep()
                    end
                end
            end

            lyx.Logger:Log("Zeus cam props to camera by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 5
    })

    lyx:NetAdd("gm3ZeusCam_propsToCursor", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized Zeus prop cursor teleport by " .. ply:Nick(), 2)
                return
            end

            local entities = ReadSelectionEntities(150)
            local targetPos = net.ReadVector()

            if not entities or not isvector(targetPos) then
                ply:ChatPrint("Invalid prop selection")
                return
            end

            for _, ent in ipairs(entities) do
                if IsValid(ent) and ent:GetClass() == "prop_physics" then
                    ent:SetPos(targetPos + Vector(math.Rand(-14, 14), math.Rand(-14, 14), math.Rand(0, 8)))
                    local phys = ent:GetPhysicsObject()
                    if IsValid(phys) then
                        phys:SetVelocity(vector_origin)
                        phys:Sleep()
                    end
                end
            end

            lyx.Logger:Log("Zeus cam props to cursor by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 5
    })
    --[[
        Zeus Cam - Shockwave
    ]]
    lyx:NetAdd("gm3ZeusCam_shockwave", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized Zeus shockwave by " .. ply:Nick(), 2)
                return
            end

            local origin = net.ReadVector()
            local radius = net.ReadUInt(16) or 400
            if not isvector(origin) then
                ply:ChatPrint("Invalid shockwave position")
                return
            end
            radius = math.Clamp(radius, 100, 1000)

            local affected = ents.FindInSphere(origin, radius)
            for _, ent in ipairs(affected) do
                if ent:IsPlayer() then
                    ent:ScreenFade(SCREENFADE.IN, Color(255, 0, 0, 100), 0.5, 0.5)
                    ent:TakeDamage(25, ply, ply)
                elseif ent:IsNPC() or ent:IsNextBot() then
                    local dmg = DamageInfo()
                    dmg:SetDamage(200)
                    dmg:SetAttacker(ply)
                    dmg:SetInflictor(ply)
                    dmg:SetDamageType(DMG_BLAST)
                    ent:TakeDamageInfo(dmg)
                elseif ent:GetClass() == "prop_physics" then
                    local phys = ent:GetPhysicsObject()
                    if IsValid(phys) then
                        local dir = (ent:GetPos() - origin):GetNormalized()
                        phys:EnableMotion(true)
                        phys:ApplyForceCenter(dir * 50000)
                    end
                end
            end

            lyx.Logger:Log("Zeus cam shockwave triggered by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 5
    })
    --[[
        Zeus Cam - Move NPCs into formation
    ]]
    lyx:NetAdd("gm3ZeusCam_moveFormation", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized Zeus formation move by " .. ply:Nick(), 2)
                return
            end

            local data = ReadEntityVectorPairs(100)
            if not data or #data == 0 then
                ply:ChatPrint("Invalid formation data")
                return
            end

            for _, pair in ipairs(data) do
                local ent, pos = pair.ent, pair.pos
                if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) and isvector(pos) then
                    ent:SetLastPosition(pos)
                    ent:SetSchedule(SCHED_FORCED_GO)
                end
            end

            lyx.Logger:Log("Zeus cam formation move by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 5
    })
    --[[
        Zeus Cam - Assign patrol routes
    ]]
    lyx:NetAdd("gm3ZeusCam_setPatrolRoute", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized patrol assignment by " .. ply:Nick(), 2)
                return
            end

            local entities = ReadSelectionEntities(80)
            local waypointCount = net.ReadUInt(6) or 0
            if not entities or waypointCount < 1 or waypointCount > 8 then
                ply:ChatPrint("Invalid patrol route.")
                return
            end

            local waypoints = {}
            for i = 1, waypointCount do
                waypoints[i] = net.ReadVector()
            end
            local shouldLoop = net.ReadBool()

            for _, ent in ipairs(entities) do
                if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) then
                    GM3_PatrolControllers[ent] = {
                        waypoints = table.Copy(waypoints),
                        idx = 1,
                        loop = shouldLoop,
                        lastCommand = 0
                    }
                end
            end

            ply:ChatPrint(string.format("Patrol assigned (%d nodes).", waypointCount))
            lyx.Logger:Log("Zeus cam patrol route by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 4
    })
    --[[
        Zeus Cam - Fire support / artillery
    ]]
    lyx:NetAdd("gm3ZeusCam_callArtillery", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized artillery call by " .. ply:Nick(), 2)
                return
            end

            local position = net.ReadVector()
            local radius = net.ReadUInt(12) or 0
            local shells = net.ReadUInt(4) or 0
            local delay = net.ReadFloat() or 0.5
            local isSmoke = net.ReadBool()
            local impactDelay = net.ReadFloat() or 0
            local profileName = net.ReadString() or ""

            if not isvector(position) then
                ply:ChatPrint("Invalid strike position.")
                return
            end
            radius = math.Clamp(radius, 50, 600)
            shells = math.Clamp(shells, 1, 10)
            delay = math.Clamp(delay, 0.2, 2)
            impactDelay = math.Clamp(impactDelay, 0, 120)
            local config = FireSupportImpactConfig[profileName] or FireSupportImpactConfig.barrage
            if impactDelay <= 0 then
                impactDelay = config.warning or 5
            end

            GM3_BroadcastArtilleryPreview(ply, position, radius, impactDelay, profileName)

            for i = 1, shells do
                local fireDelay = impactDelay + (i - 1) * delay
                timer.Simple(fireDelay, function()
                    if not IsValid(ply) then return end
                    local offset = VectorRand():GetNormalized() * math.Rand(0, radius)
                    offset.z = 0
                    local impactPos = position + offset
                    GM3_HandleArtilleryImpact(ply, impactPos, radius, profileName, isSmoke)
                end)
            end

            lyx.Logger:Log("Zeus cam artillery call by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 3
    })
    --[[
        Zeus Cam - Supply drops
    ]]
    lyx:NetAdd("gm3ZeusCam_supplyDrop", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized supply drop by " .. ply:Nick(), 2)
                return
            end

            local pos = net.ReadVector()
            local dropType = string.lower(string.Trim(net.ReadString() or "ammo"))
            if not isvector(pos) then
                ply:ChatPrint("Invalid drop position.")
                return
            end
            local config = GM3_SupplyTypes[dropType]
            if not config then
                ply:ChatPrint("Unknown drop type.")
                return
            end

            local crate = ents.Create("prop_physics")
            if not IsValid(crate) then return end

            crate:SetModel(config.model or "models/Items/item_item_crate.mdl")
            crate:SetPos(pos + Vector(0, 0, 600))
            crate:Spawn()
            local phys = crate:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableMotion(true)
                phys:SetVelocity(Vector(0, 0, -600))
            end

            crate.GM3Supply = {
                type = dropType,
                uses = config.uses or 3,
                owner = ply
            }
            table.insert(GM3_SupplyCrates, crate)
            crate.GM3SupplySound = CreateSound(crate, "npc/combine_gunship/dropship_engine_distant_loop1.wav")
            if crate.GM3SupplySound then
                crate.GM3SupplySound:PlayEx(0.7, 120)
            end
            timer.Simple(8, function()
                if IsValid(crate) and crate.GM3SupplySound then
                    crate.GM3SupplySound:FadeOut(2)
                    crate.GM3SupplySound = nil
                end
            end)
            crate:CallOnRemove("GM3_StopSupplySound", function(ent)
                if ent.GM3SupplySound then
                    ent.GM3SupplySound:Stop()
                    ent.GM3SupplySound = nil
                end
            end)
            ply:ChatPrint("Supply crate inbound.")
            lyx.Logger:Log("Zeus cam supply drop (" .. dropType .. ") by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 3
    })
    --[[
        Zeus Cam - Defense zones
    ]]
    lyx:NetAdd("gm3ZeusCam_createDefenseZone", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized defense zone by " .. ply:Nick(), 2)
                return
            end

            local entities = ReadSelectionEntities(80)
            local center = net.ReadVector()
            local radius = net.ReadUInt(12) or 0
            local posture = string.lower(net.ReadString() or "defensive")

            if not entities or not isvector(center) then
                ply:ChatPrint("Invalid defense zone.")
                return
            end

            radius = math.Clamp(radius, 150, 2000)
            local zone = {
                owner = ply,
                center = center,
                radius = radius,
                posture = posture,
                npcs = {}
            }

            for _, ent in ipairs(entities) do
                if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) then
                    table.insert(zone.npcs, ent)
                    if ent.SetLastPosition then
                        ent:SetLastPosition(center)
                    end
                    if ent.SetSchedule then
                        ent:SetSchedule(SCHED_FORCED_GO)
                    end
                end
            end

            if #zone.npcs == 0 then
                ply:ChatPrint("No valid NPCs selected.")
                return
            end

            table.insert(GM3_DefenseZones, zone)
            lyx.Logger:Log("Zeus cam defense zone by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 5
    })
    --[[
        Zeus Cam - Recon pulse
    ]]
    lyx:NetAdd("gm3ZeusCam_reconPulse", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized recon pulse by " .. ply:Nick(), 2)
                return
            end

            local origin = net.ReadVector()
            local radius = net.ReadUInt(12) or 0
            if not isvector(origin) then
                ply:ChatPrint("Invalid recon position.")
                return
            end
            radius = math.Clamp(radius, 200, 2000)

            local contacts = GM3_SendReconData(ply, origin, radius) or {}
            ply:ChatPrint(string.format("Recon pulse sent (%d contacts).", #contacts))
            lyx.Logger:Log("Zeus cam recon pulse by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 3
    })
    lyx:NetAdd("gm3ZeusCam_deploySensor", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized sensor deployment by " .. ply:Nick(), 2)
                return
            end

            local pos = net.ReadVector()
            local radius = net.ReadUInt(12) or 0
            local duration = net.ReadUInt(12) or 0
            if not isvector(pos) then
                ply:ChatPrint("Invalid sensor position.")
                return
            end
            radius = math.Clamp(radius, 200, 1500)
            duration = math.Clamp(duration, 10, 180)

            GM3_ReconSensors[#GM3_ReconSensors + 1] = {
                owner = ply,
                pos = pos,
                radius = radius,
                expire = CurTime() + duration,
                nextPulse = CurTime()
            }
            ply:ChatPrint("Sensor beacon deployed.")
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 3
    })
    lyx:NetAdd("gm3ZeusCam_screenMessage", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized screen message by " .. ply:Nick(), 2)
                return
            end

            local targeted = net.ReadBool()
            local targets = {}
            if targeted then
                local count = net.ReadUInt(8) or 0
                for i = 1, count do
                    local ent = net.ReadEntity()
                    if IsValid(ent) and ent:IsPlayer() then
                        table.insert(targets, ent)
                    end
                end
            else
                targets = player.GetAll()
            end

            local msg = string.sub(net.ReadString() or "", 1, 256)
            local color = net.ReadColor()
            local duration = math.Clamp(math.floor(net.ReadFloat() or 5), 1, 30)
            local fade = math.Clamp(math.floor(net.ReadFloat() or 90), 20, 400)

            if #targets == 0 then
                ply:ChatPrint("No valid recipients.")
                return
            end

            net.Start("gm3:tools:screenmessage")
                net.WriteString(msg)
                net.WriteColor(color)
                net.WriteInt(duration, 32)
                net.WriteInt(fade, 32)
            net.Send(targets)

            lyx.Logger:Log(string.format("Zeus screen message by %s to %d recipients.", ply:Nick(), #targets))
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 3
    })
    lyx:NetAdd("gm3ZeusCam_buffPlayers", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized player buff by " .. ply:Nick(), 2)
                return
            end
            local count = net.ReadUInt(8) or 0
            local buffed = 0
            for i = 1, count do
                local target = net.ReadEntity()
                if IsValid(target) and target:IsPlayer() then
                    target:SetHealth(math.min(target:GetMaxHealth(), target:Health() + 40))
                    target:SetArmor(math.min(100, target:Armor() + 40))
                    target:EmitSound("items/smallmedkit1.wav")
                    buffed = buffed + 1
                end
            end
            ply:ChatPrint(string.format("Inspired %d players.", buffed))
            lyx.Logger:Log("Zeus cam player buff by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 4
    })
    --[[
        Zeus Cam - Spawn NPCs at cursor
    ]]
    lyx:NetAdd("gm3ZeusCam_spawnNPCs", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized Zeus spawn attempt by " .. ply:Nick(), 2)
                return
            end

            local class = string.Trim(net.ReadString() or "")
            local weapon = string.Trim(net.ReadString() or "")
            local count = net.ReadUInt(6) or 0
            local pos = net.ReadVector()
            local ang = net.ReadAngle()
            local relationship = string.lower(net.ReadString() or "hostile")

            if class == "" or #class > 64 then
                ply:ChatPrint("Invalid NPC class")
                return
            end

            if count < 1 or count > 20 then
                ply:ChatPrint("Invalid NPC count")
                return
            end

            if not isvector(pos) or not isangle(ang) then
                ply:ChatPrint("Invalid spawn position")
                return
            end
            if #weapon > 64 then
                weapon = ""
            end

            local spawned = 0
            for i = 1, count do
                local npc = ents.Create(class)
                if not IsValid(npc) then
                    continue
                end

                local offset = Vector((i % 5) * 24, math.floor((i - 1) / 5) * 24, 0)
                local spawnPos = GM3_GetSafeSpawnPos(pos + offset)
                npc:SetPos(spawnPos)
                npc:SetAngles(ang)

                if weapon ~= "" then
                    npc:SetKeyValue("additionalequipment", weapon)
                end

                npc:Spawn()
                npc:Activate()
                spawned = spawned + 1

                local disp = D_HT
                if relationship == "friendly" then
                    disp = D_LI
                elseif relationship == "neutral" then
                    disp = D_NU
                end

                for _, target in ipairs(player.GetAll()) do
                    npc:AddEntityRelationship(target, disp, 99)
                end
            end

            lyx.Logger:Log(string.format("Zeus cam spawned %d x %s by %s", spawned, class, ply:Nick()))
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 5
    })

    lyx:NetAdd("gm3ZeusCam_healNPCs", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized Zeus heal attempt by " .. ply:Nick(), 2)
                return
            end

            local entities = ReadSelectionEntities(100)
            if not entities then
                ply:ChatPrint("Invalid selection")
                return
            end

            for _, ent in ipairs(entities) do
                if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) then
                    local maxHealth = ent.GetMaxHealth and ent:GetMaxHealth() or 100
                    maxHealth = math.max(maxHealth, ent:Health())
                    ent:SetHealth(maxHealth)
                end
            end

            lyx.Logger:Log("Zeus cam NPC heal by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 5
    })

    lyx:NetAdd("gm3ZeusCam_redeployNPCs", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized redeploy attempt by " .. ply:Nick(), 2)
                return
            end
            local entities = ReadSelectionEntities(80)
            local pos = net.ReadVector()
            if not entities or not isvector(pos) then
                ply:ChatPrint("Invalid redeploy data.")
                return
            end
            local redeployed = 0
            for _, ent in ipairs(entities) do
                if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) then
                    local offset = VectorRand() * 36
                    offset.z = math.random(12, 48)
                    local safePos = GM3_GetSafeSpawnPos(pos + offset)
                    ent:SetPos(safePos)
                    ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
                    ent:SetVelocity(vector_origin)
                    redeployed = redeployed + 1
                end
            end
            ply:ChatPrint("Redeployed " .. redeployed .. " units.")
            lyx.Logger:Log("Zeus cam redeploy by " .. ply:Nick() .. " (" .. redeployed .. ")")
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 4
    })

    lyx:NetAdd("gm3ZeusCam_dropMarker", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized marker attempt by " .. ply:Nick(), 2)
                return
            end
            local pos = net.ReadVector()
            local label = string.Trim(net.ReadString() or "")
            local colorIdx = net.ReadUInt(3) or 0
            local duration = net.ReadFloat() or 10
            if not isvector(pos) then
                return
            end
            if label == "" then
                label = "Signal"
            end
            local color = GM3_SignalColors[colorIdx] or GM3_SignalColors[0]
            net.Start("gm3ZeusCam_signalMarker")
                net.WriteVector(pos)
                net.WriteString(label)
                net.WriteUInt(color.r, 8)
                net.WriteUInt(color.g, 8)
                net.WriteUInt(color.b, 8)
                net.WriteFloat(math.Clamp(duration, 3, 60))
            net.Broadcast()
            lyx.Logger:Log(string.format("Zeus cam marker '%s' placed by %s", label, ply:Nick()))
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 4
    })

    lyx:NetAdd("gm3ZeusCam_createWaypoint", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized waypoint attempt by " .. ply:Nick(), 2)
                return
            end
            local pos = net.ReadVector()
            local title = string.sub(string.Trim(net.ReadString() or "Waypoint"), 1, 40)
            local subtitle = string.sub(string.Trim(net.ReadString() or ""), 1, 60)
            local r = net.ReadUInt(8) or 255
            local g = net.ReadUInt(8) or 200
            local b = net.ReadUInt(8) or 120
            local icon = string.Trim(net.ReadString() or "flag")
            if not isvector(pos) then return end
            if not GM3_WaypointIcons[string.lower(icon)] then
                icon = "flag"
            end
            local waypoint = ents.Create("gm3_waypoint")
            if not IsValid(waypoint) then return end
            waypoint:SetPos(pos + Vector(0, 0, 8))
            waypoint:SetWaypointTitle(title)
            waypoint:SetWaypointSubtitle(subtitle)
            waypoint:SetWaypointColor(Vector(r, g, b))
            waypoint:SetWaypointIcon(string.lower(icon))
            waypoint.Owner = ply
            waypoint:Spawn()
            ply:AddCleanup("gm3_waypoint", waypoint)
            undo.Create("gm3_waypoint")
                undo.AddEntity(waypoint)
                undo.SetPlayer(ply)
            undo.Finish()
            lyx.Logger:Log(string.format("Waypoint '%s' created by %s", title, ply:Nick()))
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 4
    })

    lyx:NetAdd("gm3ZeusCam_removeWaypoint", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized waypoint removal by " .. ply:Nick(), 2)
                return
            end
            local ent = net.ReadEntity()
            if not IsValid(ent) or ent:GetClass() ~= "gm3_waypoint" then return end
            ent:Remove()
            lyx.Logger:Log("Waypoint removed by " .. ply:Nick())
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 5
    })

    lyx:NetAdd("gm3ZeusCam_updateWaypoint", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized waypoint update by " .. ply:Nick(), 2)
                return
            end
            local ent = net.ReadEntity()
            if not IsValid(ent) or ent:GetClass() ~= "gm3_waypoint" then return end
            local title = string.sub(string.Trim(net.ReadString() or "Waypoint"), 1, 40)
            local subtitle = string.sub(string.Trim(net.ReadString() or ""), 1, 60)
            local r = net.ReadUInt(8) or 255
            local g = net.ReadUInt(8) or 200
            local b = net.ReadUInt(8) or 120
            local icon = string.Trim(net.ReadString() or "flag")
            if not GM3_WaypointIcons[string.lower(icon)] then
                icon = "flag"
            end
            ent:SetWaypointTitle(title)
            ent:SetWaypointSubtitle(subtitle)
            ent:SetWaypointColor(Vector(r, g, b))
            ent:SetWaypointIcon(string.lower(icon))
            lyx.Logger:Log(string.format("Waypoint '%s' updated by %s", title, ply:Nick()))
        end,
        auth = function(ply) return gm3:SecurityCheck(ply) end,
        rateLimit = 6
    })

    hook.Add("Think", "GM3_ZeusPatrolThink", function()
        local now = CurTime()
        for ent, data in pairs(GM3_PatrolControllers) do
            if not IsValid(ent) or not data or not data.waypoints or #data.waypoints == 0 then
                GM3_PatrolControllers[ent] = nil
            else
                data.idx = math.Clamp(data.idx or 1, 1, #data.waypoints)
                local target = data.waypoints[data.idx]
                if not target then
                    GM3_PatrolControllers[ent] = nil
                else
                    local dist = ent:GetPos():DistToSqr(target)
                    local keepTracking = true
                    if dist < 3600 then
                        if not data.wait or now >= data.wait then
                            data.idx = data.idx + 1
                            if data.idx > #data.waypoints then
                                if data.loop then
                                    data.idx = 1
                                else
                                    GM3_PatrolControllers[ent] = nil
                                    keepTracking = false
                                end
                            end
                            if keepTracking then
                                data.wait = now + 0.8
                            end
                        end
                    elseif now > (data.lastCommand or 0) + 0.5 then
                        if ent.SetLastPosition then
                            ent:SetLastPosition(target)
                        end
                        if ent.SetSchedule then
                            ent:SetSchedule(SCHED_FORCED_GO)
                        end
                        data.lastCommand = now
                    end
                end
            end
        end
    end)

    local function GetDefenseTargets(zone)
        local best
        local targets = ents.FindInSphere(zone.center, zone.radius)
        for _, ent in ipairs(targets) do
            if not IsValid(ent) then continue end
            if ent:IsPlayer() and ent ~= zone.owner then
                return ent
            elseif ent:IsNPC() or ent:IsNextBot() then
                best = ent
            end
        end
        return best
    end

    hook.Add("Think", "GM3_ZeusDefenseThink", function()
        for idx = #GM3_DefenseZones, 1, -1 do
            local zone = GM3_DefenseZones[idx]
            if not zone or not zone.npcs then
                table.remove(GM3_DefenseZones, idx)
            else
                for entIdx = #zone.npcs, 1, -1 do
                    local npc = zone.npcs[entIdx]
                    if not IsValid(npc) then
                        table.remove(zone.npcs, entIdx)
                    else
                        local dist = npc:GetPos():DistToSqr(zone.center)
                        if dist > zone.radius * zone.radius then
                            if npc.SetLastPosition then npc:SetLastPosition(zone.center) end
                            if npc.SetSchedule then npc:SetSchedule(SCHED_FORCED_GO) end
                        elseif zone.posture == "aggressive" then
                            local target = GetDefenseTargets(zone)
                            if IsValid(target) and npc.SetEnemy then
                                npc:SetEnemy(target)
                                if npc.UpdateEnemyMemory then
                                    npc:UpdateEnemyMemory(target, target:GetPos())
                                end
                                if npc.SetSchedule then
                                    npc:SetSchedule(SCHED_CHASE_ENEMY)
                                end
                            end
                        end
                    end
                end
                if #zone.npcs == 0 then
                    table.remove(GM3_DefenseZones, idx)
                end
            end
        end
    end)

    hook.Add("Think", "GM3_ZeusSensorThink", function()
        local now = CurTime()
        for i = #GM3_ReconSensors, 1, -1 do
            local sensor = GM3_ReconSensors[i]
            if not sensor or sensor.expire <= now or not IsValid(sensor.owner) then
                table.remove(GM3_ReconSensors, i)
            elseif now >= (sensor.nextPulse or 0) then
                GM3_SendReconData(sensor.owner, sensor.pos, sensor.radius)
                sensor.nextPulse = now + 3
            end
        end
    end)

    hook.Add("PlayerUse", "GM3_ZeusSupplyUse", function(ply, ent)
        if not IsValid(ply) or not IsValid(ent) then return end
        local supply = ent.GM3Supply
        if not supply then return end

        local dropType = supply.type or "ammo"
        local config = GM3_SupplyTypes[dropType]
        if not config then
            ent:Remove()
            return false
        end

        local removeImmediately = config.apply and config.apply(ply, ent, supply)

        supply.uses = (supply.uses or config.uses or 1) - 1
        if not removeImmediately then
            ent:EmitSound("items/ammo_pickup.wav")
        end
        if removeImmediately or supply.uses <= 0 then
            ent:EmitSound("ambient/materials/door_hit1.wav")
            ent:Remove()
        end
        return false
    end)

    hook.Add("EntityRemoved", "GM3_ZeusCleanup", function(ent)
        if GM3_PatrolControllers then
            GM3_PatrolControllers[ent] = nil
        end
        if GM3_SupplyCrates then
            for i = #GM3_SupplyCrates, 1, -1 do
                if GM3_SupplyCrates[i] == ent then
                    table.remove(GM3_SupplyCrates, i)
                    break
                end
            end
        end
        for i = #GM3_DefenseZones, 1, -1 do
            local zone = GM3_DefenseZones[i]
            if zone then
                for idx = #zone.npcs, 1, -1 do
                    if zone.npcs[idx] == ent then
                        table.remove(zone.npcs, idx)
                    end
                end
                if #zone.npcs == 0 then
                    table.remove(GM3_DefenseZones, i)
                end
            end
        end
    end)

    --[[
        Client-bound network messages
        These are sent from server to client and don't need server handlers
        But must be registered for the network string
    ]]
    lyx:NetAdd("gm3:menu:open", {})  -- Opens GM3 menu on client
    lyx:NetAdd("gm3:net:clientConvar", {})  -- Client convar updates
    lyx:NetAdd("gm3:net:stringConCommand", {})  -- String console commands
    lyx:NetAdd("gm3:tools:enableLights", {})  -- Light tool updates
    lyx:NetAdd("gm3:command:run", {})  -- Command execution broadcast
    lyx:NetAdd("gm3:newHash", {})  -- Hash system updates
    lyx:NetAdd("gm3:removeHash", {})  -- Hash removal
    lyx:NetAdd("gm3:setting:syncSetting", {})  -- Settings sync to client

    -- OPSAT tool network messages
    lyx:NetAdd("gm3:tools:opsatRemove", {})  -- Remove OPSAT display
    lyx:NetAdd("gm3:tools:opsatSet", {})  -- Set OPSAT display
    lyx:NetAdd("gm3:tools:requestOpsat", {})  -- Request OPSAT data on join
    lyx:NetAdd("gm3ZeusCam_signalMarker", {})
    lyx:NetAdd("gm3ZeusCam_artilleryPreview", {})
    lyx:NetAdd("gm3ZeusCam_reconData", {})

    --[[
        Handle client settings request on connect
    ]]
    lyx:NetAdd("gm3:setting:requestClientSettings", {
        func = function(ply, len)
            -- Send all syncable settings to the client
            for name, setting in pairs(gm3.settings) do
                if setting.syncWithClient then
                    net.Start("gm3:setting:syncSetting")
                        net.WriteString(name)
                        net.WriteType(setting.value)
                    net.Send(ply)
                end
            end

            gm3.Logger:Log("Synced settings to " .. ply:Nick())
        end,
        rateLimit = 2  -- Limit settings requests
    })
end
