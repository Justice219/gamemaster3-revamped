gm3 = gm3

if SERVER then
    gm3 = gm3
    lyx = lyx
    
    local tool = GM3Module.new(
        "Model Size",
        "Sizes a player, make them either bigger or smaller using size argument.", 
        "Justice#4956",
        {
            ["Target Player"] = {
                type = "player",
                def = ""
            },
            ["Duration"] = {
                type = "number",
                def = 5
            },
            ["Size"] = {
                type = "number",
                def = 0.5
            },
        },
        function(ply, args)
            -- Get the target player using gm3 helper function
            local target = gm3:GetPlayerBySteamID(args["Target Player"])
            if not IsValid(target) then
                lyx:MessagePlayer({["type"] = "header",["color1"] = Color(0,255,213),["header"] = "Model Size",["color2"] = Color(255,255,255),["text"] = "Player not found! Please select a valid player.",
                    ["ply"] = ply
                })
                return
            end

            target:SetModelScale(args["Size"], 1)
            timer.Simple(args["Duration"], function()
                if IsValid(target) then
                    target:SetModelScale(1, 1)
                end
            end)
        end,
        "Control" -- Category for tools affecting player control/movement
    )
    gm3:addTool(tool)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx


end