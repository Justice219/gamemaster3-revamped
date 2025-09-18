gm3 = gm3

if SERVER then
    gm3 = gm3
    lyx = lyx
    
    local tool = GM3Module.new(
        "Low Gravity",
        "Changes the whole server gravity to a lower value for a set duration. Anything lower than default is dangerous!", 
        "Justice#4956",
        {
            ["Duration"] = {
                type = "number",
                def = 5
            },
            ["Gravity"] = {
                type = "number",
                def = 150
            },
        },
        function(ply, args)
            game.ConsoleCommand("sv_gravity " .. args["Gravity"] .. "\n")
            timer.Simple(args["Duration"], function()
                game.ConsoleCommand("sv_gravity 600\n")
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