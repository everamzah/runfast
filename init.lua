--[[	RUN & FAST [runfast]
	Stamina (hunger) and sprinting mod
	Copyright 2016 James Stevenson (everamzah)
	LGPL v2.1+	]]


-- Mod Space
local runfast = {}

runfast.players = {}
runfast.name = minetest.get_current_modname()
runfast.path = minetest.get_modpath(runfast.name)
runfast.damage = minetest.setting_getbool("enable_damage")
runfast.singleplayer = minetest.is_singleplayer()

minetest.log("action", "[" .. runfast.name .. "] Loading.")
minetest.log("action", "[" .. runfast.name .. "] " .. runfast.path)

-- Heart regeneration, default on
runfast.hp_regen = minetest.setting_getbool("runfast_hp_regen")
if runfast.hp_regen == nil then
	runfast.hp_regen = true
end
minetest.log("action", "[" .. runfast.name .. "] Heart regeneration: " ..
		tostring(runfast.hp_regen))

-- Master poll default intervals
runfast.time = {
	poll = tonumber(minetest.setting_get("dedicated_server_step")) or 0.1,
	hunger = tonumber(minetest.setting_get("runfast_hunger_step")) or 15.0,
	sprint = tonumber(minetest.setting_get("dedicated_server_step")) or 0.1,
	meter = tonumber(minetest.setting_get("runfast_meter_step")) or 0.1,
	health = tonumber(minetest.setting_get("runfast_health_step")) or 1,
}

-- Default sprinting speed and jump height
runfast.sprint = {
	speed = tonumber(minetest.setting_get("runfast_sprint_speed")) or 1.667,
	jump = tonumber(minetest.setting_get("runfast_sprint_jump")) or 1.334,
}

-- Statbars
runfast.meters = {
	players = {},
	hunger = minetest.setting_getbool("runfast_display_hunger_meter"),
	sprint = minetest.setting_getbool("runfast_display_sprint_meter"),
	debug = false,
	def = {
		hunger = {},
		sprint = {},
		debug = {},
	},
}

-- Hunger & Sprint meters are on by default.
if runfast.meters.hunger == nil then
	runfast.meters.hunger = true
end

if runfast.meters.sprint == nil then
	runfast.meters.sprint = true
end

-- Conditionally define statbars
if runfast.meters.hunger then
	minetest.log("action", "[" .. runfast.name .. "] Setting hunger meter.")
	local offset = {x = (-10 * 24) - 25, y = -(48 + 24 + 40)}
	if not runfast.damage then
		offset.y = -(48 + 24 + 16)
	end
	runfast.meters.def.hunger = {
		hud_elem_type = "statbar",
		position = {x = 0.5, y = 1},
		text = "runfast_hunger_sb.png",
		number = 20,
		direction = 0,
		size = {x = 24, y = 24},
		offset = offset,
	}
else
	minetest.log("action", "[" .. runfast.name .. "] Not setting hunger meter.")
end

if runfast.meters.sprint then
	minetest.log("action", "[" .. runfast.name .. "] Setting sprint meter.")
	local offset = {x = 25, y = -(48 + 24 + 40)}
	if not runfast.damage then
		offset.y = -(48 + 24 + 16)
	end
	runfast.meters.def.sprint = {
		hud_elem_type = "statbar",
		position = {x = 0.5, y = 1},
		text = "runfast_sprint_sb.png",
		number = 0,
		direction = 0,
		size = {x = 24, y = 24},
		offset = offset,
	}
else
	minetest.log("action", "[" .. runfast.name .. "] Not setting sprint meter.")
end

if minetest.is_yes(minetest.setting_getbool("runfast_display_debug_meter")) then
	runfast.meters.debug = true
	runfast.meters.def.debug = {
		hud_elem_type = "text",
		number = 0xFFFFFF,
		direction = 0,
		position = {x = 0, y = 0},
		offset = {x = 136, y = 264},
		alignment = 1, -- ????
		text = "Stamina: ?\nSatiation: ?\nStomach: ?\nSprinting: ?\nHP Regen: ?",
	}
end

-- Register callbacks
minetest.register_on_joinplayer(function(player)
	if not player:get_inventory():get_list("stomach") then
		player:get_inventory():set_size("stomach", 1)
		player:get_inventory():set_width("stomach", 20)
	end
	runfast.players[player:get_player_name()] = {
		sprinting = false,
		stamina = 20,
		satiation = player:get_inventory():get_width("stomach"),
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
	if not player then
		return
	end
	if not runfast.players[player:get_player_name()] then
		return
	end
	runfast.players[player:get_player_name()] = nil
	runfast.meters.players[player:get_player_name()] = nil
end)

minetest.register_on_dieplayer(function(player)
	if not player then
		return
	end
	if not runfast.players[player:get_player_name()] then
		return
	end
	runfast.players[player:get_player_name()].satiation = 0
	runfast.players[player:get_player_name()].stamina = 0
	player:get_inventory():set_width("stomach", 0)
end)

minetest.register_on_respawnplayer(function(player)
	if not player then
		return
	end
	if not runfast.players[player:get_player_name()] then
		return
	end
	runfast.players[player:get_player_name()].satiation = 20
	runfast.players[player:get_player_name()].stamina = 20
	player:get_inventory():set_width("stomach", 20)
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
				if runfast.players[player:get_player_name()].satiation >= 1 then
					-- Lower satiation more or less depending on whether sprinting.
					if runfast.players[player:get_player_name()].sprinting then
						runfast.players[player:get_player_name()].satiation = runfast.players[player:get_player_name()].satiation - 0.5
					else
						runfast.players[player:get_player_name()].satiation = runfast.players[player:get_player_name()].satiation - 0.25
					end
					player:get_inventory():set_width("stomach", runfast.players[player:get_player_name()].satiation)
				end
				if runfast.players[player:get_player_name()].satiation < 1 and
						player:get_hp() > 0 then
					player:set_hp(player:get_hp() - 2)
				end
			end
			hunger_timer = 0
		end
		sprint_timer = sprint_timer + dtime
		if sprint_timer > runfast.time.sprint then
			for _, player in pairs(minetest.get_connected_players()) do
				if player:get_player_control().aux1 and
						runfast.players[player:get_player_name()].stamina > 0 and
						(player:get_player_control().up or
						player:get_player_control().down or
						player:get_player_control().left or
						player:get_player_control().right or
						player:get_player_control().jump) and
						runfast.players[player:get_player_name()].satiation >= 2 then
					-- Sprinting now.
					if not runfast.players[player:get_player_name()].sprinting and
							runfast.players[player:get_player_name()].stamina > 1 then
						runfast.players[player:get_player_name()].sprinting = true
						player:set_physics_override(runfast.sprint)
					end
					-- Reduce stamina points based upon number of satiation points.
					runfast.players[player:get_player_name()].stamina = runfast.players[player:get_player_name()].stamina - ((20 - runfast.players[player:get_player_name()].satiation) * 0.05)
					-- Reduce satiation ever so slightly, so that a 20 stamina will lower.
					runfast.players[player:get_player_name()].satiation = runfast.players[player:get_player_name()].satiation - 0.01
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
							runfast.players[player:get_player_name()].stamina < 20 and
							player:get_hp() > 0 then
						runfast.players[player:get_player_name()].stamina = runfast.players[player:get_player_name()].stamina + 1 
					elseif runfast.players[player:get_player_name()].stamina < 20 and
							player:get_hp() > 0 then
						runfast.players[player:get_player_name()].stamina = runfast.players[player:get_player_name()].stamina + 0.1
					elseif player:get_hp() > 0 then
						runfast.players[player:get_player_name()].stamina = 20
					end
				end
			end
			sprint_timer = 0
		end
		meter_timer = meter_timer + dtime
		if meter_timer > runfast.time.meter then
			for _, player in pairs(minetest.get_connected_players()) do
				-- Update hunger and sprint meters.
				if runfast.meters.hunger then
					player:hud_change(
						runfast.meters.players[player:get_player_name()].hunger,
						"number",
						runfast.players[player:get_player_name()].satiation
					)
				end
				if runfast.meters.sprint then
					if runfast.players[player:get_player_name()].stamina == 20 then
						player:hud_change(
							runfast.meters.players[player:get_player_name()].sprint,
							"number",
							0
						)
					else
						player:hud_change(
							runfast.meters.players[player:get_player_name()].sprint,
							"number",
							runfast.players[player:get_player_name()].stamina
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
					if runfast.players[player:get_player_name()].stamina >= 10 and
							runfast.players[player:get_player_name()].satiation >= 15 and
							player:get_hp() > 0 and player:get_hp() < 20 then
						player:set_hp(player:get_hp() + 2)
					end
				end
			end
			health_timer = 0
		end
		if runfast.meters.debug then
			for _, player in pairs(minetest.get_connected_players()) do
				-- Display debugging information.
				player:hud_change(
					runfast.meters.players[player:get_player_name()].debug,
					"text",
					"Stamina: " .. tostring(runfast.players[player:get_player_name()].stamina) .. "\n" ..
							"Satiation: " ..
							tostring(runfast.players[player:get_player_name()].satiation) .. "\n" ..
							"Stomach: " ..
							tostring(player:get_inventory():get_width("stomach")) .."\n" ..
							"Sprinting: " ..
							tostring(runfast.players[player:get_player_name()].sprinting) .. "\n" ..
							"HP Regen: " ..
							tostring(runfast.hp_regen)
				)
			end
		end
		poll_timer = 0
	end
end)

minetest.register_on_item_eat(function(hp_change, replace_with_item, itemstack, user, pointed_thing)
	-- Only consume edible if hungry, or optionally hurt, depending on HP Regen setting.
	if runfast.hp_regen and runfast.players[user:get_player_name()].satiation == 20 then
			return itemstack
	elseif runfast.players[user:get_player_name()].satiation == 20 and
			user:get_hp() == 20 then
		return itemstack
	end

	if hp_change > 0 then
		-- Consumed food
		if runfast.players[user:get_player_name()].satiation < 20 and
				runfast.players[user:get_player_name()].satiation >= 0 then
			if runfast.players[user:get_player_name()].satiation + hp_change > 20 then
				runfast.players[user:get_player_name()].satiation = 20
			else
				runfast.players[user:get_player_name()].satiation = runfast.players[user:get_player_name()].satiation + hp_change
			end
		end
		if not runfast.hp_regen then
			user:set_hp(user:get_hp() + hp_change)
		end
		minetest.sound_play("runfast_eat", {to_player = user:get_player_name(), gain = 0.7})
		itemstack:take_item()
	else
		-- Consumed poison
		if runfast.players[user:get_player_name()].satiation >= 1 then
			runfast.players[user:get_player_name()].satiation = runfast.players[user:get_player_name()].satiation / 2
		else
			runfast.players[user:get_player_name()].satiation = 0
		end
		user:set_hp(user:get_hp() + hp_change)
		minetest.sound_play("runfast_eat", {to_player = user:get_player_name(), gain = 0.7})
		itemstack:take_item()
	end
	user:get_inventory():set_width("stomach", runfast.players[user:get_player_name()].satiation)
	return itemstack
end)

-- 20% chance placing reduces satiation by 0.05
minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
	if not placer then
		return
	end
	if math.random(1, 5) ~= 5 then
		return
	end
	if runfast.players[placer:get_player_name()].satiation >= 1.05 then
		runfast.players[placer:get_player_name()].satiation = runfast.players[placer:get_player_name()].satiation - 0.05
	else
		runfast.players[placer:get_player_name()].satiation = 0
	end
	placer:get_inventory():set_width("stomach", runfast.players[placer:get_player_name()].satiation)
end)
 
-- 33% chance digging reduces satiation by 0.15
minetest.register_on_dignode(function(pos, oldnode, digger)
	if not digger then
		return
	end
	if math.random(1, 3) ~= 3 then
		return
	end
	if runfast.players[digger:get_player_name()].satiation >= 1.15 then
		runfast.players[digger:get_player_name()].satiation = runfast.players[digger:get_player_name()].satiation - 0.1
	else
		runfast.players[digger:get_player_name()].satiation = 0
	end
	digger:get_inventory():set_width("stomach", runfast.players[digger:get_player_name()].satiation)
end)

-- EOF
minetest.log("action", "[" .. runfast.name .. "] Loaded.")
