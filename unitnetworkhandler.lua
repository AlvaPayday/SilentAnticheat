
function UnitNetworkHandler:damage_bullet(subject_unit, attacker_unit, damage, i_body, height_offset, variant, death, sender)
	
  if not self._verify_character_and_sender(subject_unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end
  
  local damage_ext = subject_unit:character_damage()

	if not damage_ext or not damage_ext.sync_damage_bullet then
		return
	end
  
	if not alive(attacker_unit) or attacker_unit:key() == subject_unit:key() then
		attacker_unit = nil
	end
  
  if lobby_tasks.verified then
    subject_unit:character_damage():sync_damage_bullet(attacker_unit, damage, i_body, height_offset, variant, death)
    return
  end
  
    local peer = self._verify_sender(sender)
    if not subject_unit then return end
    if not peer_tracker[peer:id()] then 
      subject_unit:character_damage():sync_damage_bullet(attacker_unit, damage, i_body, height_offset, variant, death)
      return 
    end
    local id = peer:id()
    local is_criminal = subject_unit:in_slot(managers.slot:get_mask("all_criminals"))
    
    if is_criminal then
      if subject_unit:character_damage()._mission_damage_blockers and subject_unit:character_damage()._mission_damage_blockers.invulnerable then
        subject_unit:contour():add("tmp_invulnerable",true)
        subject_unit:contour():flash("tmp_invulnerable", 0.2)
        managers.network:session():send_to_peers_synched("sync_contour_add", subject_unit, -1, table.index_of(ContourExt.indexed_types, "tmp_invulnerable"), 1) 
        god_tracker(peer)
      end
    end
    
    if peer_tracker[id].pdata and peer_tracker[id].pdata.last_damage == 0 and is_criminal then
      peer_tracker[id].pdata.last_damage = TimerManager:game():time()
      
      if not peer_tracker[id].pdata.upgrades_loaded then
        peer_setup (peer)
      end
      
    elseif type(peer_tracker[id].pdata.last_damage) == "number" and is_criminal and not peer_tracker[id].pdata.fully_verified then
      local new_value = TimerManager:game():time() - peer_tracker[id].pdata.last_damage
      peer_tracker[id].pdata.last_damage = TimerManager:game():time()
      
      if peer_tracker[id].pdata.damage_interval == 0 then
        if lobby_tasks.difficulty_index >= 7 and new_value > 0.35 then
        peer_tracker[id].pdata.damage_interval = new_value
      elseif lobby_tasks.difficulty_index < 7 and new_value > 0.45 then
        peer_tracker[id].pdata.damage_interval = new_value
      else
        if new_value < peer_tracker[id].pdata.damage_interval and new_value >= 0.35 then
          peer_tracker[id].pdata.damage_interval = new_value
          if new_value <= 0.39 and lobby_tasks.difficulty_index >= 7 or new_value <= 0.49 and lobby_tasks.difficulty_index < 7 then
            local verified = check_player_verified (peer)
            --check for fully verified here since damage_interval settled to acceptable value
            if verified then
              check_lobby_verified()
            end
            
          end
         end 
        end
      end
    end  
    

    if attacker_unit and attacker_unit ~= peer:unit() then 
      subject_unit:character_damage():sync_damage_bullet(attacker_unit, damage, i_body, height_offset, variant, death)
      return 
    elseif not attacker_unit then
      subject_unit:character_damage():sync_damage_bullet(attacker_unit, damage, i_body, height_offset, variant, death)
      return 
    end
    
    local pdata = peer_tracker[peer:id()].pdata
    local weapon_unit = attacker_unit:inventory():equipped_unit()
    local weap_id = weapon_unit:base()._name_id
    local is_primary = weapon_unit:base():weapon_tweak_data().use_data.selection_index == 2
    
    if is_primary then
      if pdata.primary_damage == 0 and damage > 0 then  --still sampling damage
        local array_count = #pdata.stat_array_1 or 0
        
        if array_count > 9 then
          local total_damage = 0
          for i = 1, array_count do
            total_damage = total_damage + pdata.stat_array_1[i]
          end
          local average = math.floor(total_damage / array_count)
          peer_tracker[peer:id()].pdata.primary_damage = average

          if check_weapon_damage(peer, pdata.primary_weap_id, average) then
            local result = check_player_verified (peer)
          end
        else
          peer_tracker[peer:id()].pdata.stat_array_1[array_count + 1] = damage
        end
      end
      
    else
      
      if pdata.secondary_damage == 0 and damage > 0 then  --still sampling damage
        local array_count = #pdata.stat_array_2
        if array_count > 9 then
          local total_damage = 0
          for i = 1, array_count do
            total_damage = total_damage + pdata.stat_array_2[i]
          end
          local average = math.floor(total_damage / array_count)
          peer_tracker[peer:id()].pdata.secondary_damage = average

          if check_weapon_damage(peer, pdata.secondary_weap_id, average) then
            local result = check_player_verified (peer)
          end
        else
          peer_tracker[peer:id()].pdata.stat_array_2[array_count + 1] = damage
        end
      end
    end
  
  
  
	subject_unit:character_damage():sync_damage_bullet(attacker_unit, damage, i_body, height_offset, variant, death)
end

function UnitNetworkHandler:damage_explosion_fire(subject_unit, attacker_unit, damage, i_attack_variant, death, direction, weapon_unit, sender)
	if not self._verify_character_and_sender(subject_unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end
  
  if subject_unit and attacker_unit and subject_unit == managers.player:player_unit() and attacker_unit == managers.player:player_unit() then
    damage = 0
  end
  
  	--local is_player = unit == managers.player:player_unit()
	if not alive(attacker_unit) or attacker_unit:key() == subject_unit:key() then
		attacker_unit = nil
	end

	if i_attack_variant == 3 then
		subject_unit:character_damage():sync_damage_fire(attacker_unit, damage, i_attack_variant, death, direction)
	else
		subject_unit:character_damage():sync_damage_explosion(attacker_unit, damage, i_attack_variant, death, direction, weapon_unit)
	end
end

function UnitNetworkHandler:damage_explosion_stun(subject_unit, attacker_unit, damage, i_attack_variant, death, direction, sender)
	if not self._verify_character_and_sender(subject_unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end
  
  if subject_unit and attacker_unit and subject_unit == managers.player:player_unit() and attacker_unit == managers.player:player_unit() then
    damage = 0
  end
  
	if not alive(attacker_unit) or attacker_unit:key() == subject_unit:key() then
		attacker_unit = nil
	end

	if i_attack_variant then
		subject_unit:character_damage():sync_damage_stun(attacker_unit, damage, i_attack_variant, death, direction)
	end
end

function UnitNetworkHandler:from_server_damage_bullet(subject_unit, attacker_unit, hit_offset_height, result_index, sender)
	if not self._verify_character_and_sender(subject_unit, sender) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(attacker_unit) or attacker_unit:key() == subject_unit:key() then
		attacker_unit = nil
	end
  
  local is_criminal = subject_unit:in_slot(managers.slot:get_mask("all_criminals"))
    
  if is_criminal then
    local char_damage = peer:unit():character_damage()
    if unit:character_damage()._mission_damage_blockers and unit:character_damage()._mission_damage_blockers.invulnerable then
      managers.network:session():send_to_peers_synched("sync_contour_add", subject_unit, -1, table.index_of(ContourExt.indexed_types, "tmp_invulnerable"), 1) 
      god_tracker(peer)
    end
  end
    
	subject_unit:character_damage():sync_damage_bullet(attacker_unit, hit_offset_height, result_index)
end

function UnitNetworkHandler:from_server_damage_explosion_fire(subject_unit, attacker_unit, result_index, i_attack_variant, sender)
	if not self._verify_character(subject_unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end
  
	if not alive(attacker_unit) or attacker_unit:key() == subject_unit:key() then
		attacker_unit = nil
	end
  
  if attacker_unit and subject_unit then
    if attacker_unit == managers.player:player_unit() and subject_unit == managers.player:player_unit() then
      if attacker_unit ~= subject_unit then
        return
      end
    end
  end
  
	if i_attack_variant == 3 then
		subject_unit:character_damage():sync_damage_fire(attacker_unit, result_index, i_attack_variant)
	else
		subject_unit:character_damage():sync_damage_explosion(attacker_unit, result_index, i_attack_variant)
	end
end

function UnitNetworkHandler:from_server_unit_recovered(subject_unit)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(subject_unit) then
		return
	end
  
  local is_criminal = subject_unit:in_slot(managers.slot:get_mask("all_criminals"))
    
  if is_criminal then
    if unit:character_damage()._mission_damage_blockers and unit:character_damage()._mission_damage_blockers.invulnerable then
      managers.network:session():send_to_peers_synched("sync_contour_add", subject_unit, -1, table.index_of(ContourExt.indexed_types, "tmp_invulnerable"), 1) 
      god_tracker(peer)
    end
  end
  
	subject_unit:character_damage():sync_unit_recovered()
end

function UnitNetworkHandler:sync_interacted(unit, unit_id, tweak_setting, status, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local peer = self._verify_sender(sender)
  local target_peer = managers.network:session():peer_by_unit(unit)
  
  if target_peer and peer_tracker[target_peer:id()].pdata.blocked then
    return 
  end
  
	if not peer then
		return
	end
  
  local peer_unit = peer:unit()
  
  local interact_distance = mvector3.distance(peer_unit:position(), unit:position())
  
  if interact_distance > 300 then
    local interact_type = tostring(tweak_setting)
    if interact_type ~= "hostage_convert" and interact_type ~= "open_slash_close_act" then
      warn(peer:name() .. " :interact distance warning: " .. tostring(interact_distance) .. " type: " .. tostring(tweak_setting))  
    end
    return
  end
  
	if alive(unit) and unit:interaction() then
		if unit:interaction()._special_equipment and unit:interaction().apply_item_pickup then
			managers.network:session():send_to_peer(peer, "special_eq_response", unit)

			if unit:interaction():can_remove_item() then
				unit:set_slot(0)
			end
		end

		local char_unit = managers.criminals:character_unit_by_peer_id(peer:id())

		unit:interaction():sync_interacted(peer, char_unit, status)
	end
end

function UnitNetworkHandler:sync_carry_interacted(unit, unit_id, tweak_id, carry_id, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local peer = self._verify_sender(sender)

	if not peer then
		return
	end

	if Network:is_server() and unit_id ~= -2 then
		if alive(unit) and unit:interaction().tweak_data == tweak_id and unit:interaction():active() then
      if check_allowed_bag(carry_id) then
        sender:carry_interaction_reply(true, carry_id)
      else
        warn("failed check_allowed_bag() user: " .. peer:name())
        sender:carry_interaction_reply(true, carry_id)  --TODO: change once tested to false
      end
		else
			sender:carry_interaction_reply(false, carry_id)

			return
		end
	end

	if alive(unit) then
		unit:interaction():sync_interacted(peer)
	end
end

function UnitNetworkHandler:sync_multiple_equipment_bag_interacted(unit, amount_wanted, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local peer = self._verify_sender(sender)

	if not peer then
		return
	end

	if unit and alive(unit) and unit:interaction() then
		local char_unit = managers.criminals:character_unit_by_peer_id(peer:id())
    warn(peer:name() .. " sync_multiple_bag_interacted: amount: " .. amount_wanted)
    --TODO: log for now. respond if this is a hack
		unit:interaction():sync_interacted(peer, char_unit, amount_wanted)
	end
end

function UnitNetworkHandler:set_unit_invulnerable(unit, invulnerable, immortal)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character(unit) then
		return
	end
  
  local is_criminal = unit:in_slot(managers.slot:get_mask("all_criminals"))
    
  if is_criminal then
      local peer = managers.network:session():peer_by_unit(unit)
      unit:contour():add("tmp_invulnerable",true)
      unit:contour():flash("tmp_invulnerable", 0.2)
      managers.network:session():send_to_peers_synched("sync_contour_add", unit, -1, table.index_of(ContourExt.indexed_types, "tmp_invulnerable"), 1) 
      god_tracker(peer)
  end
	unit:character_damage():set_invulnerable(invulnerable)
	unit:character_damage():set_immortal(immortal)
end

function UnitNetworkHandler:set_trade_spawn(criminal_name)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end
  --TODO check for invalid trade spawn here
	managers.trade:sync_set_trade_spawn(criminal_name)
end

function UnitNetworkHandler:play_distance_interact_redirect(unit, redirect, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end
  
  if redirect == "cmd_get_up" then
      local calling_peer = self._verify_sender(sender)
      local target_peer =  managers.network:session():peer_by_unit(unit)
      if target_peer and calling_peer then
        local pdata = peer_tracker[calling_peer:id()] and peer_tracker[calling_peer:id()].pdata
        if not pdata.has_inspire then
          peer_tracker[calling_peer:id()].pdata.has_inspire = true
        end
        
        if pdata and pdata.has_inspire then
          local last_time, cooldown
          last_time = pdata.inspire_time
          if last_time == 0 then
            peer_tracker[calling_peer:id()].pdata.inspire_time = TimerManager:game():time()
          else
            cooldown = last_time + 19.9
            if cooldown < TimerManager:game():time() then
              --used inspire success
              peer_tracker[calling_peer:id()].pdata.inspire_time = TimerManager:game():time()
            else
              --using inspire with a hacked cooldown TODO: react
              warn(calling_peer:name() .. " used inspire with no cooldown")
              
            end
            
          end
          
        end
      end
      
        --warn(calling_peer:name() .. " used inspire")
    end
	unit:movement():play_redirect(redirect)
end

function UnitNetworkHandler:start_timer_gui(unit, timer, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end
  
  local sender_peer = self._verify_sender(sender)
  
  if unit:interaction() and unit:interaction().tweak_data then
    
    local is_mission_drill = false
    local drill_name = unit:interaction().tweak_data
    local drill_time = tonumber(unit:timer_gui()["_current_timer"])
    local timer_match = unit:timer_gui()["_current_timer"] == unit:timer_gui()["_timer"]
    
    for i = 1, #drill_names do
      if string.find(drill_name, drill_names[i]) then
        is_mission_drill = true
      end
    end
    
    if is_mission_drill and drill_time < 60 or not timer_match then
        unit:timer_gui()["_current_timer"] = 360
        unit:timer_gui()["_timer"] = 360
        managers.network:session():send_to_peers_synched("start_timer_gui", unit, 360)
        --kick(sender_peer:id(), " tried to hack drill times")
        extra_crispy(sender_peer, " attempted to hack drill time and will be obliterated.")
    end
      
  end

	unit:timer_gui():sync_start(timer)
end

function UnitNetworkHandler:on_sole_criminal_respawned(peer_id, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end
  
  local peer = self._verify_sender(sender)
  
  if not peer then
    return
  end

  local current_time = TimerManager:game():time()
  local test_time = peer_tracker[peer:id()].stat_counter + 10
  
  if test_time < current_time then
      
      if peer:id() == peer_id then        
      -- kick(peer_id, " attempted to auto-respawn from custody.")
       extra_crispy(peer, " attempted to auto-respawn from custody and will now be obliterated.")
       return
      end
      
  end
  
  managers.player:on_sole_criminal_respawned(peer_id)
	
end


function UnitNetworkHandler:sync_player_movement_state(unit, state, down_time, unit_id_str, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end
  
  if not alive(unit) then return end
  
	local peer = self._verify_sender(sender)
  
  local target_unit = managers.network:session():peer_by_unit (unit)
  
	if not peer then
		return
	end

	self:_chk_unit_too_early(unit, unit_id_str, "sync_player_movement_state", 1, unit, state, down_time, unit_id_str, sender)

	if not peer:is_host() and peer:unit():key() ~= unit:key() then
    warn(peer:id(), "attempted to change another player's state.")
		return
	end
  
  if state == "bleedout" then
      if peer_tracker[peer:id()] then
        peer_tracker[peer:id()].pdata.revives = peer_tracker[peer:id()].pdata.revives - 1
        
        if peer_tracker[peer:id()].pdata.revives < 0 then
          --revives cheat, should be dead/custody
          warn(peer:name() .. " has < 0 revives and is not dead")
        end
        
        if AlvasMod and peer_tracker[peer:id()].pdata.has_inspire then
          AlvasMod:broadcast(peer:name() .. " was downed. [HAS INSPIRE]")
        end
      end   
  end
    
  if state == "dead" then
    
    if peer then
      local character_name = managers.criminals:character_name_by_peer_id(peer:id())
      local delay = managers.trade:respawn_delay_by_name(character_name)
      peer_tracker[peer:id()].pdata.stat_counter = TimerManager:game():time() + delay
      peer_tracker[peer:id()].pdata.custody = true
    end
      
  end  
    
	Application:trace("[UnitNetworkHandler:sync_player_movement_state]: ", unit:movement():current_state_name(), "->", state)

	local local_peer = managers.network:session():local_peer()

	if local_peer:unit() and unit:key() == local_peer:unit():key() then
		local valid_transitions = {
			standard = {
				arrested = true,
				incapacitated = true,
				carry = true,
				bleed_out = true,
				tased = true
			},
			carry = {
				arrested = true,
				incapacitated = true,
				standard = true,
				bleed_out = true,
				tased = true
			},
			mask_off = {
				arrested = true,
				carry = true,
				standard = true
			},
			bleed_out = {
				carry = true,
				fatal = true,
				standard = true
			},
			fatal = {
				carry = true,
				standard = true
			},
			arrested = {
				carry = true,
				standard = true
			},
			tased = {
				incapacitated = true,
				carry = true,
				standard = true
			},
			incapacitated = {
				carry = true,
				standard = true
			},
			clean = {
				arrested = true,
				carry = true,
				mask_off = true,
				standard = true,
				civilian = true
			},
			civilian = {
				arrested = true,
				carry = true,
				clean = true,
				standard = true,
				mask_off = true
			}
		}

		if unit:movement():current_state_name() == state then
			return
		end

		if unit:movement():current_state_name() and valid_transitions[unit:movement():current_state_name()][state] then
      --local peer
      
      
			managers.player:set_player_state(state)
		else
			debug_pause_unit(unit, "[UnitNetworkHandler:sync_player_movement_state] received invalid transition", unit, unit:movement():current_state_name(), "->", state)
		end
	else
		unit:movement():sync_movement_state(state, down_time)
	end
end

function UnitNetworkHandler:sync_ammo_amount(selection_index, max_clip, current_clip, current_left, max, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end
  --TODO ammo check
	managers.player:set_synced_ammo_info(peer:id(), selection_index, max_clip, current_clip, current_left, max)
end

function UnitNetworkHandler:sync_carry(carry_id, multiplier, dye_initiated, has_dye_pack, dye_value_multiplier, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end
  
  if check_allowed_bag(carry_id) then  --TODO 
     if peer_tracker[peer:id()] and peer_tracker[peer:id()].pdata then
       peer_tracker[peer:id()].pdata.carry_id = carry_id
     end
  else
      warn(peer:name() .. " is carrying invalid bag type: " .. carry_id)
  end
    
	managers.player:set_synced_carry(peer, carry_id, multiplier, dye_initiated, has_dye_pack, dye_value_multiplier)
end


function UnitNetworkHandler:server_drop_carry(carry_id, carry_multiplier, dye_initiated, has_dye_pack, dye_value_multiplier, position, rotation, dir, throw_distance_multiplier_upgrade_level, zipline_unit, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end
  
  if not check_allowed_bag (carry_id) then
    if peer then
      --kick(peer:id(), " attempted to spawn loot bags")
      extra_crispy(peer, " attempted loot bag spawning and will be obliterated.")
    end
    return
  end
  
  if peer_tracker[peer:id()] and peer_tracker[peer:id()].pdata and peer_tracker[peer:id()].pdata.carry_id ~= carry_id then
      local tracker_id = peer_tracker[peer:id()].pdata.carry_id

      if not check_allowed_bag(carry_id) then
        warn(peer:name() .. " attempted to drop disallowed bag type: " .. carry_id )
        return
      end
     
  end
  
  if peer_tracker[peer:id()] and peer_tracker[peer:id()].pdata then
    if peer_tracker[peer:id()].pdata.carry_id == carry_id then
      peer_tracker[peer:id()].pdata.carry_id = carry_id
    end
  end
  
	managers.player:server_drop_carry(carry_id, carry_multiplier, dye_initiated, has_dye_pack, dye_value_multiplier, position, rotation, dir, throw_distance_multiplier_upgrade_level, zipline_unit, peer)
end

function UnitNetworkHandler:server_secure_loot(carry_id, multiplier_level, peer_id, sender)
	local peer = self._verify_sender(sender)

	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not peer then
		return
	end
  
  if peer and peer_id and peer_id ~= peer:id() then --TODO: react to this behavior
      --warn(peer:name() .. " :server_secure_loot: peer_id doesnt match peer:id()")
  end
  
  if not check_loot_drop_distance(peer:unit()) then --TODO: block secure loot if not within range
    warn(peer:name() .. " secured loot bag not within range of a drop point.")
  end
  
	managers.loot:server_secure_loot(carry_id, multiplier_level, nil, peer_id)
end

function UnitNetworkHandler:sync_secure_loot(carry_id, multiplier_level, silent, peer_id, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) and not self._verify_gamestate(self._gamestate_filter.any_end_game) or not self._verify_sender(sender) then
		return
	end
  local peer = self._verify_sender(sender)
  
  if not check_loot_drop_distance(peer:unit()) then --TODO: block secure loot if not within range
    warn(peer:name() .. " secured loot bag not within range of a drop point.")
  end
	managers.loot:sync_secure_loot(carry_id, multiplier_level, silent, peer_id)
end

function UnitNetworkHandler:set_armor(unit, percent, max_mul, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	local peer = self._verify_sender(sender)
	local peer_id = peer:id()
	local character_data = managers.criminals:character_data_by_peer_id(peer_id)
  
  if max_mul and max_mul >= 0.492 then
    local armor_value = math.floor(max_mul * 1000)
    host_warn(peer:id() .. " has abnormal armor value. armor: " .. armor_value)
    return
  end
  
  if peer_tracker[peer:id()].pdata.armor == 0 then
    peer_tracker[peer:id()].pdata.armor = math.floor(max_mul * 1000)
  end
  
  local current_time = TimerManager:game():time()
  local current_armor = math.floor((percent * max_mul) * 10)
  if peer_tracker[peer:id()].pdata.armor_value == 0 then
    peer_tracker[peer:id()].pdata.armor_value = math.floor(max_mul * 1000)
  end
  
	if character_data and character_data.panel_id then
		managers.hud:set_teammate_armor(character_data.panel_id, {
			current = percent * max_mul,
			total = 100 * max_mul,
			max = 100 * max_mul
		})
	else
		managers.hud:set_mugshot_armor(unit:unit_data().mugshot_id, percent / 100)
	end
end

function UnitNetworkHandler:set_health(unit, percent, max_mul, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end

	local peer = self._verify_sender(sender)
	local peer_id = peer:id()
	local character_data = managers.criminals:character_data_by_peer_id(peer_id)
  local current_health = math.floor((percent * max_mul) * 10)
  local current_time = TimerManager:game():time()
  
  if max_mul and max_mul > 0.595 then
    local health_value = math.floor(max_mul * 1000)
    host_warn(peer:id() .. " has abnormal health value. health: " .. health_value)
    return
  end
  
  if peer_tracker[peer:id()].pdata.health == 0 then
    peer_tracker[peer:id()].pdata.health = math.floor(max_mul * 1000)
  end
  
  if peer_tracker[peer_id].pdata.health_last_regen == 0 then
    peer_tracker[peer_id].pdata.health_last_regen = TimerManager:game():time()
  end
  
  if peer_tracker[peer_id].pdata.health == 0 then
    peer_tracker[peer_id].pdata.health = math.floor(max_mul * 1000)
  else
    if peer_tracker[peer_id].pdata.health < current_health then
      local health_change = current_health - peer_tracker[peer:id()].pdata.health
      local interval = current_time - peer_tracker[peer:id()].pdata.health_last_regen
      --TODO: track amount gained here (for regen check)
      local difference = math.floor(current_health - peer_tracker[peer_id].pdata.health)

    end
  end
  
  peer_tracker[peer_id].pdata.health = current_health
  peer_tracker[peer_id].pdata.health_last_regen = TimerManager:game():time()
  
	if character_data and character_data.panel_id then
		managers.hud:set_teammate_health(character_data.panel_id, {
			current = percent * max_mul,
			total = 100 * max_mul,
			max = 100 * max_mul
		})
	else
		managers.hud:set_mugshot_health(unit:unit_data().mugshot_id, percent / 100)
	end

	if percent ~= 100 then
		managers.mission:call_global_event("player_damaged")
	end
end

function UnitNetworkHandler:set_revives(unit, revive_amount, is_max, sender)
	if not alive(unit) or not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	local peer = self._verify_sender(sender)

	if not peer then
		return
	end
  
  if not peer:id() then
    return
  end
  
	local char_dmg_ext = unit:character_damage()

	if char_dmg_ext and char_dmg_ext.sync_set_revives then
		char_dmg_ext:sync_set_revives(revive_amount, is_max)
	end

	local peer_id = peer:id()
	local character_data = managers.criminals:character_data_by_peer_id(peer_id)

	if character_data and character_data.panel_id then
		managers.hud:set_teammate_revives(character_data.panel_id, revive_amount)
	end
  
  if not peer_tracker[peer:id()] then return end
  if not peer_tracker[peer:id()].pdata then return end
  
  
  if peer_tracker[peer:id()].pdata.max_revives == -1 and is_max then
    peer_tracker[peer:id()].pdata.max_revives = revive_amount
    peer_tracker[peer:id()].pdata.revives = revive_amount
    if revive_amount > 4 then  
      peer_tracker[peer:id()].pdata.max_revives = 4
    end
  end
end

function UnitNetworkHandler:sync_teammate_helped_hint(hint, helped_unit, helping_unit, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_character_and_sender(helped_unit, sender) or not self._verify_character(helping_unit, sender) then
		return
	end
  
  local peer = managers.network:session():peer_by_unit(helping_unit)
  local target_peer = managers.network:session():peer_by_unit(helped_unit)
  if peer and target_peer then  --TODO possibly useful
    god_tracker(peer)
  end
	managers.trade:sync_teammate_helped_hint(helped_unit, helping_unit, hint)
end

function UnitNetworkHandler:mission_ended(win, num_is_inside, sender)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) or not self._verify_sender(sender) then
		return
	end
  
	if managers.platform:presence() ~= "Playing" then 
  
		if win then
      if not lobby_tasks.escape_enabled then
        local peer = self._verify_sender(sender)
        kick(peer:id(), " attempted a force win hack")
      end
      
			game_state_machine:change_state_by_name("victoryscreen", {
				num_winners = num_is_inside,
				personal_win = not managers.groupai:state()._failed_point_of_no_return and alive(managers.player:player_unit())
			})
		end
    
    if not win then
    if not lobby_tasks.has_no_return then
      local can_lose = true
      for _, peer in pairs(managers.network:session():all_peers()) do
        local unit = peer:unit()
        if alive(unit) then
          local state = unit:movement() and unit:movement():current_state()
          if state ~= "bleedout" and state ~= "fatal" and state ~= "dead" and state ~= "incapacitated" and state ~= "arrested" or state == "standard" then
            can_lose = false
          end
        end
      end
      if not can_lose then 
        local peer = self._verify_sender(sender)
        if peer then
          warn(peer:name() .. " tried to force LOSE")
        end
        return 
      end
    end
      game_state_machine:change_state_by_name("gameoverscreen")
    end
    

  end
			

end

function UnitNetworkHandler:sync_unit_spawn(parent_unit, spawn_unit, align_obj_name, unit_id, parent_extension_name)
	if not self._verify_gamestate(self._gamestate_filter.any_ingame) then
		return
	end

	if not alive(parent_unit) or not alive(spawn_unit) then
		return
	end

	parent_unit[parent_extension_name](parent_unit):spawn_unit(unit_id, align_obj_name, spawn_unit)

end