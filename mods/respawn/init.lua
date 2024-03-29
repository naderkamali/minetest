local time_elapsed = 0
local reset_interval = 10

minetest.register_on_joinplayer(
    function(player)
        SPAWNPOINT = player:get_pos()
        NAME = player:get_player_name()
    end
)


local function findSpawnPos(pos)
    local x_range = 200
    local y_range = 100
    local z_range = 200

    -- Add random amount to X and Z
    local new_pos = {
        x = pos.x + math.random(-x_range, x_range),
        y = pos.y,
        z = pos.z + math.random(-z_range, z_range)
    }

    -- Iterate between Y values
    for dy = -y_range, y_range do
        new_pos.y = pos.y + dy

        -- Check if the position is suitable (on land and not inside another node)
        local node = minetest.get_node(new_pos)
        local node_below = minetest.get_node({x = new_pos.x, y = new_pos.y - 1, z = new_pos.z})
        if minetest.get_item_group(node_below.name, "soil") > 0 and node.name == "air" then
            return new_pos  -- Found suitable position
        end
    end

    -- If none of the Y values work, change X and Z again
    return findSpawnPos(pos)
end



minetest.register_globalstep(function(dtime)
    time_elapsed = time_elapsed + dtime
    
    -- Check if the time threshold has been reached
    if time_elapsed >= reset_interval then
        -- Rollback changes made by the specific player
        local actor = minetest.get_player_by_name(NAME)
        SPAWNPOINT = findSpawnPos(SPAWNPOINT)
        actor:moveto(SPAWNPOINT)
        
        -- Reset the time elapsed
        time_elapsed = 0
        REWARD = 0
    end
end)