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

            lyx.Logger:Log("Synced GM3 data to " .. ply:Nick())
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
    --[[
        Zeus Cam - Remove selected entities
    ]]
    lyx:NetAdd("gm3ZeusCam_removeSelected", {
        func = function(ply, len)
            if not gm3:SecurityCheck(ply) then
                lyx.Logger:Log("Unauthorized Zeus cam removal by " .. ply:Nick(), 2)
                return
            end

            local tbl = net.ReadTable()

            -- Validate table size
            if not tbl or table.Count(tbl) > 100 then
                ply:ChatPrint("Invalid selection")
                return
            end

            -- Remove entities safely
            for k, v in pairs(tbl) do
                if IsValid(k) and k:IsValid() then
                    k:Remove()
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

            local npcs = net.ReadTable()
            local camPos = net.ReadVector()

            -- Validate inputs
            if not npcs or table.Count(npcs) > 100 then
                ply:ChatPrint("Invalid NPC selection")
                return
            end

            -- Validate camera position
            if not isvector(camPos) then
                ply:ChatPrint("Invalid camera position")
                return
            end

            -- Move NPCs to camera position
            for k, v in pairs(npcs) do
                if IsValid(k) and k:IsNPC() then
                    -- Set NPC movement to camera position
                    k:SetLastPosition(camPos)
                    k:SetSchedule(SCHED_FORCED_GO)
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

            local npcs = net.ReadTable()
            local targetPos = net.ReadVector()

            -- Validate inputs
            if not npcs or table.Count(npcs) > 100 then
                ply:ChatPrint("Invalid NPC selection")
                return
            end

            -- Validate target position
            if not isvector(targetPos) then
                ply:ChatPrint("Invalid target position")
                return
            end

            -- Move NPCs to clicked position
            for k, v in pairs(npcs) do
                if IsValid(k) and k:IsNPC() then
                    k:SetLastPosition(targetPos)
                    k:SetSchedule(SCHED_FORCED_GO)
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
