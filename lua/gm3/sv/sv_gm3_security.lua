gm3 = gm3
gm3.ranks = gm3.ranks or {}

lyx = lyx

-- ! Check if the player has a valid rank
-- * Used internally for making sure a player can use the system
-- * if the rank is in the gm3.ranks table, then it is valid
do
    function gm3:SecurityCheck(ply)
        -- Use cached ranks if available, otherwise load from file
        local ranks = gm3.ranks and next(gm3.ranks) and gm3.ranks or gm3:RankLoadTable()

        -- If no ranks loaded, deny access
        if not ranks then
            return false
        end

        local userGroup = ply:GetUserGroup()
        local rankData = ranks[userGroup]

        -- Handle both old format (boolean) and new format (table with panel property)
        if rankData then
            -- If it's a boolean (old format), treat true as having panel access
            if type(rankData) == "boolean" then
                return rankData
            -- If it's a table (new format), check the panel property
            elseif type(rankData) == "table" then
                return rankData.panel == true
            end
        end

        return false
    end
end