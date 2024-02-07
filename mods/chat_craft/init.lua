--[[
Fast Craft by Skamiz Kazzarch

See: https://forum.minetest.net/viewtopic.php?f=9&t=28125 for a more generic version of this mod

WARNING: Is liable to be buggy in case of recipes, which ask for a group ingredient,
 but also a specific item belonging to the group, since I didn't figure out a way
 to correctly count the items in such a case.


WARNING: Fails if recipe defines replacements for specific items which are only
requested by group
	example: recipe asks for group water bucket, and specifies two replacements
	one in case of normal water and one in case of river water,
	both of which replace with empty bucket
	this mod will give two empty buckets when the recipe is crafted



- only once there is an active need
TODO: if an item is required, but imediately returned count it as if infinite
		alternative: remove item from recipe and ad a condition checking whetehr it's in the inventory
TODO: fake scrollbar which can be styled
try: can I just place images over the scrollbar and still have it work?
TODO: button clikcing sounds
TODO: callbacks for crafting stuff
TODO: pressetes for group icons
	or, randomly choose an image from the group each time it's needed
	or or, Is it possible to dynamically make an animated texture switching through the images?
		no, probably not, since I con't directly get the node images
TODO: multigroup icons + support for predefined group icons to use an image in stead of an item
TODO: make fc_slots.png whiten, then colorize it from code as neccessary

TODO: recipe guide page
TODO: recipes can be hidden form guide; hidden = true
TODO: crafting conditions can have descriptions which are displayed in recipe section

TODO: consider turning bulk crafting into repeated single crafting

TODO: trigger MCL crafting achievments

TODO: function which checks whether a recipe contins both an item and a group the item belongs to
		print a warning for these recipes, since I don't handle them correctly
		warning: problematic recipe:


TODO: more tags
	{
		["3x3"] = true,
		["engine_immported"] = true,
		["pmb_recipe"] = true,
		["shaped"] = true, -- obviously after import they aren't shaped
		["shapeless"] = true,
		etc.. stuff like this
		whatever metadata about the recipe might be usefull
	}

A way to find changes in the inventory:
	serialize it, cache it, compare with previous state

recipe structure:
chat_craft.registered_crafts = {
...,
{
	output = {item_name, item_count},
	additional_output = {
		item_name = item_count,
		item_name = item_count,
	},
	input = {
		item_name = item_count,
		item_name = item_count,
	},
	-- only one conditions must be fulfiled
	conditions = {
		["condition_name"] = true,
		["condition_name"] = true,
	},
	-- for various recipe metadata
	tags = {
		["engine_import"] = true,
		["3x3"] = true,
	}
},
...,
}

chat_craft.registered_conditions = {
...,
condition_name = {
	name = condition_name,
	func = function,
	-- not used yet
	description = condition_description,
	icon = *.png OR item_name,
}
...,

}



---------------------------------------------



Wish for minetest: a callback for when inventory is opened/contents are changed
--]]

-- SETUP STUFF

local t0 = minetest.get_us_time()

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

chat_craft = {}
chat_craft.registered_crafts = {}
chat_craft.registered_on_crafts = {}
chat_craft.registered_conditions = {}
chat_craft.translator = minetest.get_translator("chat_craft")

dofile(modpath .. "/api.lua")
dofile(modpath .. "/compatibility/engine_recipe_import.lua")

dofile(modpath .. "/gui.lua")
dofile(modpath .. "/compatibility/integration.lua")

if not chat_craft.craft_sizes then
	chat_craft.craft_sizes = {1, 5, 25, 100}
end
if not chat_craft.grid_color then
	chat_craft.grid_color = "#959595"
end
if not chat_craft.highlight_color then
	chat_craft.highlight_color = "#84a19e"
end

-- just a usefull debug function
local function print_table(po)
	for k, v in pairs(po) do
		minetest.debug(type(k) .. " : " .. tostring(k) .. " | " .. type(v) .. " : " .. tostring(v))
	end
end

local function print_table_name(po, craft_index)
	for index, recipe in ipairs(chat_craft.registered_crafts) do
		--minetest.debug(recipe_name)
		local recipe_name = string.match(recipe.output[1], ":(.-)$")


		--minetest.debug(recipe.input.in_item)
		minetest.debug(recipe_name)


		--if recipe_name == item_name then
		--	return index
		--end
	end
end

chat_craft.register_condition("none", {
	func = function(player) return true end
})


local function get_alias(item)
	local alias = item
	while minetest.registered_aliases[alias] do
		alias = minetest.registered_aliases[alias]
	end
	if alias ~= item then
		return alias
	end
end


-- finnishing up
minetest.register_on_mods_loaded(function()
	-- resolve aliases
	for _, recipe in pairs(chat_craft.registered_crafts) do
		recipe.output[1] = get_alias(recipe.output[1]) or recipe.output[1]
		for item, amount in pairs(recipe.additional_output) do
			local ali = get_alias(item)
			if ali then
				recipe.additional_output[ali] = recipe.additional_output[item]
				recipe.additional_output[item] = nil
			end
		end
		for item, amount in pairs(recipe.input) do
			local ali = get_alias(item)
			if ali then
				recipe.input[ali] = recipe.input[item]
				recipe.input[item] = nil
			end
		end
	end

	-- TODO:
	-- Warning for recipes that use, or produce nonexiting items
	-- maybe simplify ALL recipes? instead of just imported ones
	table.sort(chat_craft.registered_crafts, function(a, b) return a.output[1] < b.output[1] end)
end)


-- Register chat command for crafting
minetest.register_chatcommand("chat_craft", {
	params = "<item_name>",
	description = "Craft the specified item",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
            return false, "Player not found"
        end

		

		local item_name = param:trim()

		-- Find the recipe index for the specified item
		local craft_indexes = find_recipe_indexes(item_name)
		local craft_index = find_recipe_index(item_name)

		--minetest.debug(craft_index)

		-- for i=1,#craft_indexes,1 do 
		--   	minetest.debug(craft_indexes[i])
		-- 	chat_craft.craft(player, craft_indexes[i], 1)
		-- 	minetest.debug('next')
		-- end
		
		--print_table_name(chat_craft.registered_crafts, craft_index) -- gets all items 
		
		if craft_index then
			-- Craft 1 of the specified item
			
			-- chat_craft.craft(player, craft_index, 1)

			chat_craft.craft_mult(player,craft_indexes, 1)

			-- You may want to update the formspec here if needed
			return true, "Crafting " .. item_name
		else
			return false, "Recipe not found for " .. item_name
		end
	end,
})

-- Function to find the recipe index for a given item name
function find_recipe_index(item_name)
	for index, recipe in ipairs(chat_craft.registered_crafts) do
		local recipe_name = string.match(recipe.output[1], ":(.-)$")
		if recipe_name == item_name then
			return index
		end
	end

	return nil
end

function find_recipe_indexes(item_name)
	local indexes = {}
	for index, recipe in ipairs(chat_craft.registered_crafts) do
		local recipe_name = string.match(recipe.output[1], ":(.-)$")
		if recipe_name == item_name then
			indexes[#indexes +1] = index
		end
	end
	if(#indexes ~= 0) then
		return indexes
	else
		return nil
	end
end


print("[MOD] 'chat_craft' loaded in " .. (minetest.get_us_time() - t0)/1000000 .. " s")
