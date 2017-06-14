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
	2017-06-04  v0.01  first version

]]--

gravelsieve = {
    rand = PseudoRandom(1234)
}

dofile(minetest.get_modpath("gravelsieve") .. "/hammer.lua")


local sieve_table = {
    iron_lump = 15,
    copper_lump = 15,
    tin_lump = 15,
    gold_lump = 25,
    mese_crystal = 25,
    diamond = 50,
}


local sieve_formspec =
    "size[8,8]"..
    "list[context;src;1,1;1,1;]"..
    "image[3,1;1,1;gui_furnace_arrow_bg.png^[transformR270]"..
    "list[context;dst;4,0;4,3;]"..
    "list[current_player;main;0,4;8,4;]"

local function can_dig(pos, player)
	local meta = minetest.get_meta(pos);
	local inv = meta:get_inventory()
	return inv:is_empty("dst") and inv:is_empty("src")
    --return true
end

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

local function swap_node(pos, meta)
	local node = minetest.get_node(pos)

    idx = meta:get_int("idx")
    idx = (idx + 1) % 4
    meta:set_int("idx", idx)
    node.name = "gravelsieve:sieve"..idx
	minetest.swap_node(pos, node)
    return idx == 3
end

local function random_ore(inv, src)
    local num
    local result = false
    for ore, probability in pairs(sieve_table) do
        if src:get_name() == "gravelsieve:gravel1" then
            probability = probability * 2
        elseif src:get_name() == "gravelsieve:gravel2" then
            probability = probability * 4
        elseif src:get_name() == "gravelsieve:gravel3" then
            probability = probability * 8
        end
        num = gravelsieve.rand:next(0, probability)
        if num == probability then
            item = ItemStack("default:"..ore)
            if inv:room_for_item("dst", item) then
                inv:add_item("dst", item)
                return true
            end
        end
    end
    return result
end
        
local function move_src2dst(meta, pos, inv, src, dst)
    if inv:room_for_item("dst", dst) and inv:contains_item("src", src) then
        local res = swap_node(pos, meta)
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
    else
        minetest.get_node_timer(pos):stop()
        return false
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
    end
    
    minetest.register_node("gravelsieve:sieve"..idx, {
        description = "Gravel Sieve "..idx,
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
            minetest.get_node_timer(pos):start(1.0)
        end,

        on_metadata_inventory_take = function(pos)
            minetest.get_node_timer(pos):start(1.0)
        end,

        on_metadata_inventory_put = function(pos)
             minetest.get_node_timer(pos):start(1.0)
        end,

        allow_metadata_inventory_put = allow_metadata_inventory_put,
        allow_metadata_inventory_move = allow_metadata_inventory_move,
        allow_metadata_inventory_take = allow_metadata_inventory_take,

        paramtype2 = "facedir",
        sunlight_propagates = true,
        is_ground_content = false,
        groups = {cracky=3, stone=1, uber=1},
    })
end

minetest.register_node("gravelsieve:gravel1", {
	description = "Gravel sifted 1",
	tiles = {"default_gravel.png"},
	groups = {crumbly = 2, falling_node = 1},
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
	groups = {crumbly = 2, falling_node = 1},
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
	groups = {crumbly = 2, falling_node = 1},
	sounds = default.node_sound_gravel_defaults(),
	drop = {
		max_items = 1,
		items = {
			{items = {'default:flint'}, rarity = 16},
			{items = {'default:gravel'}}
		}
	}
})
