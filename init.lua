--[[	RUN & FAST [runfast]
	Stamina (hunger) and sprinting mod
	Copyright 2016 James Stevenson (everamzah)
	LGPL v2.1+	]]

local runfast = {}
runfast.players = {}
runfast.name = minetest.get_current_modname()
runfast.path = minetest.get_modpath(runfast.name)

runfast.time = {
	poll = tonumber(minetest.setting_get("dedicated_server_step")) or 0.1,
	hunger = tonumber(minetest.setting_get("runfast_hunger_step")) or 100,
	sprint = tonumber(minetest.setting_get("dedicated_server_step")) or 0.1,
}

runfast.food = {
	"default:apple",
	"farming:bread",
	"flowers:mushroom_brown",
}

runfast.poison = {
	"flowers:mushroom_red",
}

runfast.sprint = {
	speed = tonumber(minetest.setting_get("runfast_sprint_speed")) or 1.667,
	jump = tonumber(minetest.setting_get("runfast_sprint_jump")) or 1.334,
}

runfast.meters = {
	players = {},
	hunger = false,
	sprint = false,
	def = {
		hunger = {},
		sprint = {},
	},
}

if minetest.setting_getbool("runfast_display_hunger_meter") then
	minetest.log("action", "[runfast] Setting hunger meter.")
	runfast.meters.hunger = true
	runfast.meters.def.hunger = {
		hud_elem_type = "statbar",
		position = {x = 0.5, y = 1},
		text = "runfast_hunger_sb.png",
		number = 20,
		direction = 0,
		size = {x = 24, y = 24},
		offset = {x = (-10 * 24) - 25, y = -(48 + 24 + 40)},
	}
end

if minetest.setting_getbool("runfast_display_sprint_meter") then
	minetest.log("action", "[runfast] Setting sprint meter.")
	runfast.meters.sprint = true
	runfast.meters.def.sprint = {
		hud_elem_type = "statbar",
		position = {x = 0.5, y = 1},
		text = "runfast_sprint_sb.png",
		number = 0,
		direction = 0,
		size = {x = 24, y = 24},
		offset = {x = 25, y = -(48 + 24 + 40)},
	}
end

minetest.register_chatcommand("edibles", {
	description = "List edibles, including poisons.",
	params = "<food> <poison>",
	func = function(name, param)
		if param == "food" then
			for _, v in pairs(runfast.food) do
				minetest.chat_send_player(name, minetest.registered_items[v].description)
			end
		elseif param == "poison" then
			for _, v in pairs(runfast.poison) do
				minetest.chat_send_player(name, minetest.registered_items[v].description)
			end
		else
			minetest.chat_send_player(name, "Invalid usage.  Type /help edibles.")
		end
	end,
})

minetest.register_chatcommand("stomach", {
	description = "Query stomach contents, condition.",
	params = "<clear> <contents>",
	func = function(name, param)
		if param == "clear" then
			minetest.get_player_by_name(name):get_inventory():set_list("stomach", nil)
			minetest.chat_send_player(name, "Clearing contents.")
		else
			local feels = {"You feel queasy.", "A little uneasy.", "Definitely cheesy."}
			minetest.chat_send_player(name, feels[math.random(1, 3)])

			print(dump(minetest.get_player_by_name(name):get_inventory():get_stack("stomach", 1):to_table()))

		end
	end
})

minetest.register_chatcommand("stamina", {
	description = "Display stamina information.",
	params = "<raise>",
	func = function(name, param)
		minetest.chat_send_player(name,
				tostring(runfast.players[name].stamina))
	end
})

minetest.register_on_joinplayer(function(player)
	minetest.log("action", "Stomach size is " ..
			tostring(player:get_inventory():get_size("stomach")))

	player:get_inventory():set_size("stomach", 1)

	--player:get_inventory():set_list("stomach", {})

	runfast.players[player:get_player_name()] = {
		sprinting = false,
		stamina = 20,
	}
	runfast.meters.players[player:get_player_name()] = {hunger = -1, sprint = -1}
	if runfast.meters.hunger then
		runfast.meters.players[player:get_player_name()].hunger = player:hud_add(runfast.meters.def.hunger)
	end
	if runfast.meters.sprint then
		runfast.meters.players[player:get_player_name()].sprint = player:hud_add(runfast.meters.def.sprint)
	end
end)

minetest.register_on_leaveplayer(function(player)
	runfast.players[player:get_player_name()] = nil
	runfast.meters.players[player:get_player_name()] = nil
end)

local poll_timer = 0
local hunger_timer = 0
local sprint_timer = 0

minetest.register_globalstep(function(dtime)
	poll_timer = poll_timer + dtime
	if poll_timer > runfast.time.poll then
		hunger_timer = hunger_timer + dtime
		if hunger_timer > runfast.time.hunger then
			for _, player in pairs(minetest.get_connected_players()) do
				if player:get_inventory():is_empty("stomach") then
					runfast.players[player:get_player_name()].stamina = 0
				else
					runfast.players[player:get_player_name()].stamina = 20
				end
				if runfast.meters.hunger then
					player:hud_change(
						runfast.meters.players[player:get_player_name()].hunger,
						"number",
						runfast.players[player:get_player_name()].stamina
					)
				end
				runfast.players[player:get_player_name()].stamina = runfast.players[player:get_player_name()].stamina - 1
				minetest.chat_send_player(player:get_player_name(), "Reducing stamina: " ..
						tostring(runfast.players[player:get_player_name()].stamina))
				hunger_timer = 0
			end
		end
		sprint_timer = sprint_timer + dtime
		if sprint_timer > runfast.time.sprint then
			for _, player in pairs(minetest.get_connected_players()) do
				if player:get_player_control().aux1 then
					if not runfast.players[player:get_player_name()].sprinting then
						runfast.players[player:get_player_name()].sprinting = true
						player:set_physics_override(runfast.sprint)
						if runfast.meters.sprint then
							player:hud_change(
								runfast.meters.players[player:get_player_name()].sprint,
								"number",
								runfast.players[player:get_player_name()].stamina
							)
						end
					end
					runfast.players[player:get_player_name()].stamina = runfast.players[player:get_player_name()].stamina - 1
				else
					if runfast.players[player:get_player_name()].sprinting then
						runfast.players[player:get_player_name()].sprinting = false
						player:set_physics_override({speed = 1, jump = 1})
						if runfast.meters.sprint then
							player:hud_change(
								runfast.meters.players[player:get_player_name()].sprint,
								"number",
								0
							)
						end
					end
				end
				sprint_timer = 0
			end
		end
		poll_timer = 0
	end
end)

minetest.register_on_item_eat(function(hp_change, replace_with_item, itemstack, user, pointed_thing)
	if not user:get_inventory():is_empty("stomach") then
		return
	end

	print(hp_change, replace_with_item, itemstack, user, pointed_thing)

	user:get_inventory():add_item("stomach", itemstack)

	minetest.after(runfast.time.hunger * 1.5 - 1, function()
		if not user then return end
		user:get_inventory():set_list("stomach", {})
		minetest.chat_send_player(user:get_player_name(), "Clearing contents.")
	end)

	minetest.chat_send_player(user:get_player_name(), "Ate " .. minetest.registered_items[itemstack:get_name()].description .. ".")
	minetest.log(user:get_player_name(), user:get_player_name() .. " used " ..
			minetest.registered_items[itemstack:get_name()].description .. ".")
end)

for _, v in pairs(runfast.food) do
	minetest.log("action", "[runfast] Adding " .. minetest.registered_items[v].description)

	print(dump(minetest.registered_items[v].on_use))
end

for _, v in pairs(runfast.poison) do
	minetest.log("action", "[runfast] Adding " .. minetest.registered_items[v].description)

	print(dump(minetest.registered_items[v].on_use))
end
