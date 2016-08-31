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
	minetest.log("action", "Setting hunger meter.")
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
	minetest.log("action", "Setting sprint meter.")
	runfast.meters.sprint = true
	runfast.meters.def.sprint = {
		hud_elem_type = "statbar",
		position = {x = 0.5, y = 1},
		text = "runfast_sprint_sb.png",
		number = 20,
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
				minetest.chat_send_player(name, v)
			end
		elseif param == "poison" then
			for _, v in pairs(runfast.poison) do
				minetest.chat_send_player(name, v)
			end
		else
			minetest.chat_send_player(name, "Invalid usage.  Type /help edibles.")
		end
	end,
})

minetest.register_on_joinplayer(function(player)
	player:get_inventory():set_size("stomach", 1)
	player:get_inventory():set_list("stomach", {})
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
		for _, player in pairs(minetest.get_connected_players()) do
			hunger_timer = hunger_timer + dtime
			if hunger_timer > runfast.time.hunger then
				if player:get_inventory():is_empty("stomach") then
					runfast.players[player:get_player_name()].stamina = 0
					if runfast.meters.hunger then
						player:hud_change(runfast.meters.players[player:get_player_name()].hunger, "number", 0)
					end
					minetest.chat_send_player(player:get_player_name(), "Your stomach is empty.")
				else
					runfast.players[player:get_player_name()].stamina = 20
					if runfast.meters.hunger then
						player:hud_change(runfast.meters.players[player:get_player_name()].hunger, "number", 20)
					end
					minetest.chat_send_player(player:get_player_name(), "You're sated.")
				end
				hunger_timer = 0
			end
			sprint_timer = sprint_timer + dtime
			if sprint_timer > runfast.time.sprint then
				if player:get_player_control().aux1 then
					runfast.players[player:get_player_name()].sprinting = true
					player:set_physics_override(runfast.sprint)
				else
					runfast.players[player:get_player_name()].sprinting = false
					player:set_physics_override({speed = 1, jump = 1})
				end
				sprint_timer = 0
			end
		end
		poll_timer = 0
	end
end)

minetest.register_on_item_eat(function(hp_change, replace_with_item, itemstack, user, pointed_thing)
	print(hp_change, replace_with_item, itemstack, user, pointed_thing)
	user:get_inventory():add_item("stomach", itemstack)
end)

for _, v in pairs(runfast.food) do
	minetest.log("action", v)
end

for _, v in pairs(runfast.poison) do
	minetest.log("action", v)
end
