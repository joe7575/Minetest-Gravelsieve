--[[

	Gravel Sieve Mod
	================

	v0.01 by JoSt
	Derived from the work of celeron55, Perttu Ahola  (furnace)

	Copyright (C) 2017 Joachim Stolberg
	Copyright (C) 2011-2016 celeron55, Perttu Ahola <celeron55@gmail.com>
	Copyright (C) 2011-2016 Various Minetest developers and contributors

	LGPLv2.1+
	See LICENSE.txt for more information

	History:
	2017-06-14  v0.01  first version
	2017-06-15  v0.02  manually use of the sieve added

]]--

gravelsieve = {
	rand = PseudoRandom(1234)
}


dofile(minetest.get_modpath("gravelsieve") .. "/hammer.lua")
dofile(minetest.get_modpath("gravelsieve") .. "/config.lua")

-- Ore probability table  (1/n)
local ore_probability = {
	iron_lump = 15,
	copper_lump = 15,
	--tin_lump = 15, not available in V0.4.15
	gold_lump = 25,
	mese_crystal = 25,
	diamond = 50,
}

-- gravel probability factor
local probability_factor = {
    ["default:gravel"] = 1,
    ["gravelsieve:gravel1"] = 2,
    ["gravelsieve:gravel2"] = 4,
    ["gravelsieve:gravel3"] = 8,
    
}

local sieve_formspec =
	"size[8,8]"..
	"list[context;src;1,1;1,1;]"..
	"image[3,1;1,1;gui_furnace_arrow_bg.png^[transformR270]"..
	"list[context;dst;4,0;4,3;]"..
	"list[current_player;main;0,4;8,4;]"


local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	if listname == "src" then
		return stack:get_count()
	elseif listname == "dst" then
		return 0
	end
end

local function allow_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local stack = inv:get_stack(from_list, from_index)
	return allow_metadata_inventory_put(pos, to_list, to_index, stack, player)
end

local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return stack:get_count()
end

-- handle the sieve animation
local function swap_node(pos, meta, start)
	local node = minetest.get_node(pos)
    local idx = meta:get_int("idx")
    if start then
        if idx == 3 then
            idx = 0
        end
    else
        idx = (idx + 1) % 4
    end
	meta:set_int("idx", idx)
	node.name = "gravelsieve:sieve"..idx
	minetest.swap_node(pos, node)
	return idx == 3
end

-- place ores to dst according to the calculated probability
local function random_ore(inv, src)
	local num
	for ore, probability in pairs(ore_probability) do
        probability = probability * probability_factor[src:get_name()]
        if probability ~= nil then
            num = gravelsieve.rand:next(0, probability)
            if num == probability then
                item = ItemStack("default:"..ore)
                if inv:room_for_item("dst", item) then
                    inv:add_item("dst", item)
                    return true     -- ore placed
                end
            end
		end
	end
	return false    -- gravel has to be moved
end

-- move gravel and ores to dst
local function move_src2dst(meta, pos, inv, src, dst)
	if inv:room_for_item("dst", dst) and inv:contains_item("src", src) then
		local res = swap_node(pos, meta, false)
		if res then
			if not random_ore(inv, src) then
				inv:add_item("dst", dst)
			end
			inv:remove_item("src", src)
		end
		return true
	end
	return false
end

-- timer callback, alternatively called by on_punch
local function sieve_node_timer(pos, elapsed)

	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local gravel = ItemStack("default:gravel")
	local gravel1 = ItemStack("gravelsieve:gravel1")
	local gravel2 = ItemStack("gravelsieve:gravel2")
	local gravel3 = ItemStack("gravelsieve:gravel3")

	if move_src2dst(meta, pos, inv, gravel, gravel1) then
		return true
	elseif move_src2dst(meta, pos, inv, gravel1, gravel2) then
		return true
	elseif move_src2dst(meta, pos, inv, gravel2, gravel3) then
		return true
	elseif move_src2dst(meta, pos, inv, gravel3, gravel3) then
		return true
	else
		if not gravelsieve.manually then
            minetest.get_node_timer(pos):stop()
		return false
        end
	end
end


for idx = 0,4 do
	local nodebox_data = {
		{ -8/16, -8/16, -8/16,   8/16, 4/16, -6/16 },
		{ -8/16, -8/16,  6/16,   8/16, 4/16,  8/16 },
		{ -8/16, -8/16, -8/16,  -6/16, 4/16,  8/16 },
		{  6/16, -8/16, -8/16,   8/16, 4/16,  8/16 },
		{ -6/16, -2/16, -6/16,  6/16, 8/16, 6/16 },
	}
	nodebox_data[5][5] =    (8 - 2*idx) / 16

	local tiles_data = {
		-- up, down, right, left, back, front
		"gravelsieve_gravel.png",
		"gravelsieve_gravel.png",
		"gravelsieve_sieve.png",
		"gravelsieve_sieve.png",
		"gravelsieve_sieve.png",
		"gravelsieve_sieve.png",
	}
	if idx == 3 then
		tiles_data[1] = "gravelsieve_top.png"
		not_in_creative_inventory = 0
	else
		not_in_creative_inventory = 1
	end
	
	minetest.register_node("gravelsieve:sieve"..idx, {
		description = "Gravel Sieve",
		tiles = tiles_data,
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = nodebox_data,
		},

		can_dig = can_dig,
		on_timer = sieve_node_timer,

		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			meta:set_int("idx", idx)
			meta:set_string("formspec", sieve_formspec)
			local inv = meta:get_inventory()
			inv:set_size('src', 1)
			inv:set_size('dst', 12)
		end,

		on_metadata_inventory_move = function(pos)
            if gravelsieve.manually then
                local meta = minetest.get_meta(pos)
                swap_node(pos, meta, true)
            else
                minetest.get_node_timer(pos):start(1.0)
            end
		end,

		on_metadata_inventory_take = function(pos)
            if gravelsieve.manually then
                local meta = minetest.get_meta(pos)
                local inv = meta:get_inventory()
                if inv:is_empty("src") then
                    -- sieve should be empty
                    meta:set_int("idx", 2)
                    swap_node(pos, meta, false)
                end
            else
                minetest.get_node_timer(pos):start(1.0)
            end
		end,

		on_metadata_inventory_put = function(pos)
            if gravelsieve.manually then
                local meta = minetest.get_meta(pos)
                swap_node(pos, meta, true)
            else
                minetest.get_node_timer(pos):start(1.0)
            end
		end,

        on_punch = function(pos, node, puncher, pointed_thing)
            local meta = minetest.get_meta(pos)
            local inv = meta:get_inventory()
            if inv:is_empty("dst") and inv:is_empty("src") then
                minetest.node_punch(pos, node, puncher, pointed_thing)
            else
                -- punching the sieve speeds up the process 
                sieve_node_timer(pos, 0)
            end
        end,

        on_dig = function(pos, node, puncher, pointed_thing)
            local meta = minetest.get_meta(pos)
            local inv = meta:get_inventory()
            if inv:is_empty("dst") and inv:is_empty("src") then
                minetest.node_dig(pos, node, puncher, pointed_thing)
            end
        end,

		allow_metadata_inventory_put = allow_metadata_inventory_put,
		allow_metadata_inventory_move = allow_metadata_inventory_move,
		allow_metadata_inventory_take = allow_metadata_inventory_take,

		paramtype2 = "facedir",
		sunlight_propagates = true,
		is_ground_content = false,
		groups = {cracky=3, stone=1, uber=1, not_in_creative_inventory=not_in_creative_inventory},
	})
end

minetest.register_node("gravelsieve:gravel1", {
	description = "Gravel sifted 1",
	tiles = {"default_gravel.png"},
	groups = {crumbly = 2, falling_node = 1, not_in_creative_inventory=1},
	sounds = default.node_sound_gravel_defaults(),
	drop = {
		max_items = 1,
		items = {
			{items = {'default:flint'}, rarity = 16},
			{items = {'default:gravel'}}
		}
	}
})

minetest.register_node("gravelsieve:gravel2", {
	description = "Gravel sifted 2",
	tiles = {"default_gravel.png"},
	groups = {crumbly = 2, falling_node = 1, not_in_creative_inventory=1},
	sounds = default.node_sound_gravel_defaults(),
	drop = {
		max_items = 1,
		items = {
			{items = {'default:flint'}, rarity = 16},
			{items = {'default:gravel'}}
		}
	}
})

minetest.register_node("gravelsieve:gravel3", {
	description = "Gravel sifted 3",
	tiles = {"default_gravel.png"},
	groups = {crumbly = 2, falling_node = 1, not_in_creative_inventory=1},
	sounds = default.node_sound_gravel_defaults(),
	drop = {
		max_items = 1,
		items = {
			{items = {'default:flint'}, rarity = 16},
			{items = {'default:gravel'}}
		}
	}
})

minetest.register_craft({
	output = "gravelsieve:sieve",
	recipe = {
		{"group:wood", "",                      "group:wood"},
		{"group:wood", "default:steel_ingot",   "group:wood"},
		{"group:wood", "",                      "group:wood"},
	},
})

minetest.register_alias("gravelsieve:sieve", "gravelsieve:sieve3")

