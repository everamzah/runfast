--[[	RUN & FAST [runfast]
	Stamina (hunger) and sprinting mod
	Copyright 2016 James Stevenson (everamzah)
	LGPL v2.1+	]]


-- Mod Space
local runfast = {}
runfast.players = {}

runfast.name = minetest.get_current_modname()
runfast.path = minetest.get_modpath(runfast.name)

minetest.log("action", "[" .. runfast.name .. "] Loading.")
minetest.log("action", "[" .. runfast.name .. "] " .. runfast.path)

-- Heart regeneration
runfast.hp_regen = minetest.setting_getbool("runfast_hp_regen") or false
minetest.log("action", "[" .. runfast.name .. "] Heart regeneration: " ..
		tostring(runfast.hp_regen))

-- Master poll intervals
runfast.time = {
	poll = tonumber(minetest.setting_get("dedicated_server_step")) or 0.1,
	hunger = tonumber(minetest.setting_get("runfast_hunger_step")) or 15.0,
	sprint = tonumber(minetest.setting_get("dedicated_server_step")) or 0.1,
	meter = tonumber(minetest.setting_get("runfast_meter_step")) or 0.1,
	health = tonumber(minetest.setting_get("runfast_health_step")) or 0.2,
}

-- Default sprinting speed and jump height
runfast.sprint = {
	speed = tonumber(minetest.setting_get("runfast_sprint_speed")) or 1.667,
	jump = tonumber(minetest.setting_get("runfast_sprint_jump")) or 1.334,
}

-- Statbars
runfast.meters = {
	players = {},
	hunger = false,
	sprint = false,
	debug = false,
	def = {
		hunger = {},
		sprint = {},
		debug = {},
	},
}

-- Conditionally define statbars
if minetest.setting_getbool("runfast_display_hunger_meter") then
	minetest.log("action", "[" .. runfast.name .. "] Setting hunger meter.")
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
else
	minetest.log("action", "[" .. runfast.name .. "] Not setting hunger meter.")
end

if minetest.setting_getbool("runfast_display_sprint_meter") then
	minetest.log("action", "[" .. runfast.name .. "] Setting sprint meter.")
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
else
	minetest.log("action", "[" .. runfast.name .. "] Not setting sprint meter.")
end

if minetest.setting_getbool("runfast_display_debug_meter") then
	runfast.meters.debug = true
	runfast.meters.def.debug = {
		hud_elem_type = "text",
		number = 0xFFFFFF,
		direction = 0,
		position = {x = 0, y = 0},
		offset = {x = 136, y = 264},
		alignment = 1, -- ????
		text = "Stamina: ? / Satiation: / ?",
	}
end

-- Register callbacks
minetest.register_on_joinplayer(function(player)
	player:get_inventory():set_size("stomach", 1)
	runfast.players[player:get_player_name()] = {
		sprinting = false,
		stamina = 20,
		satiation = 20,
	}
	runfast.meters.players[player:get_player_name()] = {hunger = -1, sprint = -1, debug = -1}
	if runfast.meters.hunger then
		runfast.meters.players[player:get_player_name()].hunger = player:hud_add(runfast.meters.def.hunger)
	end
	if runfast.meters.sprint then
		runfast.meters.players[player:get_player_name()].sprint = player:hud_add(runfast.meters.def.sprint)
	end
	if runfast.meters.debug then
		runfast.meters.players[player:get_player_name()].debug = player:hud_add(runfast.meters.def.debug)
	end
end)

minetest.register_on_leaveplayer(function(player)
	runfast.players[player:get_player_name()] = nil
	runfast.meters.players[player:get_player_name()] = nil
end)

-- Initialize counter variables
local poll_timer = 0
local hunger_timer = 0
local sprint_timer = 0
local meter_timer = 0
local health_timer = 0

minetest.register_globalstep(function(dtime)
	poll_timer = poll_timer + dtime
	if poll_timer > runfast.time.poll then
		hunger_timer = hunger_timer + dtime
		if hunger_timer > runfast.time.hunger then
			for _, player in pairs(minetest.get_connected_players()) do
				if runfast.players[player:get_player_name()].satiation > 1 then
					runfast.players[player:get_player_name()].satiation = runfast.players[player:get_player_name()].satiation - 1
				elseif runfast.players[player:get_player_name()].satiation <= 1 then
					player:set_hp(player:get_hp() - 4)
				end
				player:get_inventory():set_list("stomach", {})
			end
			hunger_timer = 0
		end
		sprint_timer = sprint_timer + dtime
		if sprint_timer > runfast.time.sprint then
			for _, player in pairs(minetest.get_connected_players()) do
				if player:get_player_control().aux1 and
						runfast.players[player:get_player_name()].stamina ~= 0 and
						(player:get_player_control().up or
						player:get_player_control().down or
						player:get_player_control().left or
						player:get_player_control().right or
						player:get_player_control().jump) then
					if not runfast.players[player:get_player_name()].sprinting then
						runfast.players[player:get_player_name()].sprinting = true
						player:set_physics_override(runfast.sprint)
					end
					if runfast.players[player:get_player_name()].stamina > 0 then
						runfast.players[player:get_player_name()].stamina = runfast.players[player:get_player_name()].stamina - 0.25
					end
					if runfast.meters.sprint then
						player:hud_change(
							runfast.meters.players[player:get_player_name()].sprint,
							"number",
							runfast.players[player:get_player_name()].stamina
						)
					end
				else
					if runfast.players[player:get_player_name()].sprinting then
						runfast.players[player:get_player_name()].sprinting = false
						player:set_physics_override({speed = 1, jump = 1})
					end
					if not player:get_player_control().aux1 and
							not player:get_player_control().up and
							not player:get_player_control().down and
							not player:get_player_control().left and
							not player:get_player_control().right and
							not player:get_player_control().jump and
							runfast.players[player:get_player_name()].stamina < 20 then
						runfast.players[player:get_player_name()].stamina = runfast.players[player:get_player_name()].stamina + 1
					end
					if runfast.players[player:get_player_name()].stamina > 20 then
						runfast.players[player:get_player_name()].stamina = 20
					end
					if runfast.meters.sprint then
						if runfast.players[player:get_player_name()].stamina < 20 then
							player:hud_change(
								runfast.meters.players[player:get_player_name()].sprint,
								"number",
								runfast.players[player:get_player_name()].stamina
							)
						else
							player:hud_change(
								runfast.meters.players[player:get_player_name()].sprint,
								"number",
								0
							)
						end
					end
				end
			end
			sprint_timer = 0
		end
		meter_timer = meter_timer + dtime
		if meter_timer > runfast.time.meter then
			for _, player in pairs(minetest.get_connected_players()) do
				if runfast.meters.hunger then
					player:hud_change(
						runfast.meters.players[player:get_player_name()].hunger,
						"number",
						runfast.players[player:get_player_name()].satiation
					)
				end
				if runfast.meters.sprint then
					if runfast.players[player:get_player_name()].stamina ~= 20 then
						player:hud_change(
							runfast.meters.players[player:get_player_name()].sprint,
							"number",
							runfast.players[player:get_player_name()].stamina
						)
					elseif runfast.players[player:get_player_name()].stamina == 20 then
						player:hud_change(
							runfast.meters.players[player:get_player_name()].sprint,
							"number",
							0
						)
					end
				end
			end
			meter_timer = 0
		end
		health_timer = health_timer + dtime
		if health_timer > runfast.time.health then
			-- Heart regeneration
			if runfast.hp_regen then
				for _, player in pairs(minetest.get_connected_players()) do
					if runfast.players[player:get_player_name()].stamina == 20 and
							runfast.players[player:get_player_name()].satiation == 20 and
							player:get_hp() > 0 and player:get_hp() < 20 then
						player:set_hp(player:get_hp() + 1)
					end
				end
			end
			health_timer = 0
		end
		if runfast.meters.debug then
			for _, player in pairs(minetest.get_connected_players()) do
				player:hud_change(
					runfast.meters.players[player:get_player_name()].debug,
					"text",
					"Stamina: " .. tostring(runfast.players[player:get_player_name()].stamina) ..
							" / Satiation: " ..
							tostring(runfast.players[player:get_player_name()].satiation)
				)
			end
		end
		poll_timer = 0
	end
end)

minetest.register_on_item_eat(function(hp_change, replace_with_item, itemstack, user, pointed_thing)
	if runfast.hp_regen then
		if runfast.players[user:get_player_name()].satiation == 20 then
			minetest.chat_send_player(user:get_player_name(), "You're not very hungry.")
			return itemstack
		end
	else
		if runfast.players[user:get_player_name()].satiation == 20 and
				user:get_hp() == 20 then
			minetest.chat_send_player(user:get_player_name(), "You're not very hungry.")
			return itemstack
		end
	end

	if hp_change > 0 then
		user:get_inventory():add_item("stomach", itemstack)
		if runfast.players[user:get_player_name()].satiation < 20 and
				runfast.players[user:get_player_name()].satiation >= 0 then
			if runfast.players[user:get_player_name()].satiation + hp_change > 20 then
				runfast.players[user:get_player_name()].satiation = 20
			else
				runfast.players[user:get_player_name()].satiation = runfast.players[user:get_player_name()].satiation + hp_change
			end
		end
		minetest.chat_send_player(user:get_player_name(),
				"Yum!  Ate " ..
						minetest.registered_items[itemstack:get_name()].description ..
						" +" .. tostring(hp_change))
		if not runfast.hp_regen then
			user:set_hp(user:get_hp() + hp_change)
		end
	else
		-- Poison
		user:get_inventory():set_list("stomach", {})
		if runfast.players[user:get_player_name()].satiation >= 1 then
			runfast.players[user:get_player_name()].satiation = runfast.players[user:get_player_name()].satiation / 2
		else
			runfast.players[user:get_player_name()].satiation = 0
		end
		minetest.chat_send_player(user:get_player_name(),
				"Yuck!  Ate " ..
						minetest.registered_items[itemstack:get_name()].description ..
						" " .. tostring(hp_change))
		user:set_hp(user:get_hp() + hp_change)
	end

	itemstack:take_item()
	return itemstack
end)

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
	if runfast.players[placer:get_player_name()].satiation >= 1.05 then
		runfast.players[placer:get_player_name()].satiation = runfast.players[placer:get_player_name()].satiation - 0.05
	else
		runfast.players[placer:get_player_name()].satiation = 0
	end
end)
 
minetest.register_on_dignode(function(pos, oldnode, digger)
	if runfast.players[digger:get_player_name()].satiation >= 1.15 then
		runfast.players[digger:get_player_name()].satiation = runfast.players[digger:get_player_name()].satiation - 0.15
	else
		runfast.players[digger:get_player_name()].satiation = 0
	end
end)

-- EOF
minetest.log("action", "[" .. runfast.name .. "] Loaded.")
