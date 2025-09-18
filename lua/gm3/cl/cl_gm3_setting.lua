gm3 = gm3
gm3.settings = gm3.settings or {}
lyx = lyx

do
    lyx.NetReceive("gm3:setting:syncSetting", function(ply, tbl)
        local name = tbl.name
        local value = tbl.value

        -- Validate received data
        if not name or #name > 64 then
            gm3.Logger:Log("Invalid setting name received", 2)
            return
        end

        -- Update or create the setting
        if gm3.settings[name] then
            gm3.settings[name].value = value
        else
            gm3.settings[name] = {
                value = value
            }
        end

        gm3.Logger:Log("Synced setting: " .. name .. " = " .. tostring(value))
    end)

    hook.Add("ClientSignOnStateChanged", "gm3_clientSetting_sync", function(userid, oldState, newState)
        print("SIGNONSTATE: " .. newState)
        if newState == 6 then
            lyx:NetSend("gm3:setting:requestClientSettings", {})
        end
    end)
end