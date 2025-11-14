gm3 = gm3
gm3.tools = gm3.tools or {}
gm3.ranks = gm3.ranks or {}
gm3.commands = gm3.commands or {}
gm3.settings = gm3.settings or {}
lyx = lyx

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
                npc:SetPos(pos + offset)
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
