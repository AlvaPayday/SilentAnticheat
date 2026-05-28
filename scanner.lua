bannedMods = {
  "STOL3NH4CK",
  "STOLENHACK",
  "name",
  "Perk",
  "Overdrill Activator",
  "Instant overdrill",
  "Forced Overdrill",
  "Secure Loot bag",
  "Spawn Loot Bags",
  "Infinite Reserve Ammo",
  "Infinite Throwables",
  "Improved Armor",
  "More Grenades",
  "unhittable armour",
  "Toggleable Infinite Ammo",
  "Aimbot",
  "Mod Hider",
  "WEAPON SWAP",
  "Free Sentry",
  "Speed Booster",
  "Speed hack",
  "Remove timers",
  "Bag speed",
  "Fast Drills",
  "Auto counter cloakers",
  "Toolkit",
  "Hex Trainer",
  "crosshair assist",
  "Active Cluster Molotov Bomb Plus",
  "Selective Mods Hider",
  "No interaction cooldowns - Version A",
  "No interaction cooldowns - Version B",
  "Ultimate Trainer",
  "ultimate trainer 4",
  "Ultimate Trainer 5",
  "UltimateTrainer5",
  "Ultimate Trainer 6",
  "UltimateTrainer6",
  "Unlimited Trainer",
  "Unlimited Trainer 5.30",
  "Carry Stacker 2.0",
  "Carry Stacker 2",
  "AX Aimbot",
  "AX Carry Stacker",
  "Carry Stacker Reloaded",
  "CARRY STACKER: LIVE AND RELOADED",
  "spawn addition loots on gage package",
  "LowCostSkill",
  "p3dhack",
  "p3dhack free",
  "P3DHack Free Version",
  "Pirate Perfection Reborn Trainer!",
	"Pirate Perfection Reborn Trainer! Free Edition",
	"Pirate Perfection Reborn Trainer! V.I.P. Edition",
  "CC and Money Generator",
  "InstaWin",
  "Nokick4u",
  "Kill Teammates :)",
  "Hello world!",
  "Cocaine Drill"
}

exclusion_list = {
  "Put on mask instantly - Gab",
  "No slow motion - Gab",
  "No fall damage - Gab",
  "No skin wear - Gab",
  "No head bobbing - Gab",
  "No weather - Gab",
  "No skins - Gab",
  "Double tick rate - Gab",
  "Remove dead shields instantly - Gab",
  "Weapon laser defaults to full strength - Gab",
  "Disable corpses + shields - Gab",
  "Disable corpses - Gab"
}




local function setup_loot_drops()
  --holds all potential loot drop positions to check against bag secure distance
  for _, script in pairs(managers.mission:scripts()) do
    for id, element in pairs(script:elements()) do
      local values = element:values()
      if values and values.icon and values.icon == "pd2_lootdrop" then
        if values.position and not table.contains(loot_drops, values.position) then
          table.insert(loot_drops, values.position)
        end
      end
    end
  end
  
end

local function setup_bag_ids()
  for _, script in pairs(managers.mission:scripts()) do
    for id, element in pairs(script:elements()) do
      local values = element:values()
      if values and values.carry_id and values.carry_id ~= nil and values.carry_id ~= "none" then
        if not table.contains(bag_ids, values.carry_id) then
          table.insert(bag_ids, values.carry_id)
        end
      end
    end
  end
end

local function get_health_skill_multiplier(unit)
  local multiplier = 1
	multiplier = multiplier + unit:base():upgrade_value("player", "health_multiplier", 1) - 1
	multiplier = multiplier + unit:base():upgrade_value("player", "passive_health_multiplier", 1) - 1
	multiplier = multiplier + unit:base():team_upgrade_value("health", "passive_multiplier", 1) - 1
	multiplier = multiplier + unit:base():get_hostage_bonus_multiplier("health") - 1
	multiplier = multiplier + unit:base():upgrade_value("player", "mrwi_health_multiplier", 1) - 1

  return multiplier
end

local function base_weapon_damage(weap_id)
  return tweak_data.weapon[weap_id].DAMAGE or nil  
end

local function is_weapon_auto(weap_id)
  return tweak_data.weapon[weap_id].auto ~= nil
end

local function weapon_auto_fire_rate(weap_id)
  return tweak_data.weapon[weap_id].auto.fire_rate
end

Hooks:Add("ChatManagerOnReceiveMessage","check_hiding_mods", function(channel_id, name, message, color, icon)
    
  if lobby_tasks.verified then
    return
  end
  
 if type(channel_id) == "number" and channel_id > 3 then
    local peer = managers.network:session():peer_by_name(name)
    if peer and peer:id() and not peer_tracker[peer:id()] then
      return
    elseif peer and peer:id() and peer_tracker[peer:id()] and peer_tracker[peer:id()].pdata then
      if not peer_tracker[peer:id()].pdata.hidden_verified then
        if not peer._mods or peer_tracker[peer:id()].pdata.mod_count == 0 then
          peer_tracker[peer:id()].pdata.modded = true
          peer_tracker[peer:id()].pdata.mod_count = 0
          peer_tracker[peer:id()].pdata.hidden_verified = true
          peer_tracker[peer:id()].pdata.mods_verified = true
          peer_tracker[peer:id()].pdata.hiding_mods = true
          return
        end
      end
    end
 end

end)



Hooks:PreHook(ConnectionNetworkHandler, "join_request_reply", "alkjsdjfdsjf", function (reply_id, my_peer_id, my_character, level_index, difficulty_index, one_down, state, server_character, user_id, mission, job_id_index, job_stage, alternative_job_stage, interupt_job_stage_level_index, xuid, sender)
    
    init_new_player(my_peer_id)
end)


Hooks:PreHook(ConnectionNetworkHandler, "sync_outfit", "verify_step_1", function (self, outfit_string, outfit_version,outfit_signature, sender)
    
    local peer = self._verify_sender(sender)
    
    if not peer then --rpc:say_toclient(message)  --go fuck yourself
      return 
    end
    
    local peer_id = peer:id()
    
    if not peer_id then
      return
    end
    
    if peer_tracker[peer_id] and peer_tracker[peer_id].pdata and peer_tracker[peer_id].pdata.sp_verified then
      return
    end
    
    local primary, secondary
    local sp_total = 0
    local mod_count = 0
    local outfit = managers.blackmarket:unpack_outfit_from_string(outfit_string)
    
    if outfit.primary.factory_id and outfit.secondary.factory_id and outfit.skills and outfit.skills.skills then
      --outfit validated
    else
      --outfit was hacked or corrupted
      kick(peer_id, "outfit hacked or corrupted")
      return
    end
    
    init_new_player(peer_id)
    
    if outfit then
      primary = managers.weapon_factory:get_weapon_id_by_factory_id(outfit.primary.factory_id)
      secondary = managers.weapon_factory:get_weapon_id_by_factory_id(outfit.secondary.factory_id)
      peer_tracker[peer_id].pdata.name = peer:name()
      peer_tracker[peer_id].pdata.user_id = peer:user_id()
      peer_tracker[peer_id].pdata.primary_weap_id = primary
      peer_tracker[peer_id].pdata.secondary_weap_id = secondary
      
      for _, points in ipairs(outfit.skills.skills or {
        0
      }) do
        sp_total = sp_total + (tonumber(points) or 0)
      end
      
      if sp_total <= 120 and sp_total ~= 0 then
        peer_tracker[peer_id].pdata.sp_verified = true
      else
        kick(peer_id, "skill abuse:" .. tostring(sp_total) .. " skill points" )
      end
      
      if not peer_tracker[peer:id()].pdata.mods_verified then
        scan_mods(peer)
      end
    end

end)

Hooks:PreHook(ConnectionNetworkHandler, "auto_init_respawn_player", "hoihd098", function (pos, peer_id)
    local peer = managers.network:session():peer(peer_id)
    local unit = peer:unit()
    --reserved
end)


Hooks:PreHook(ConnectionNetworkHandler, "request_spawn_member", "hjshdf890sdkhe", function (self, sender)
    local peer = self._verify_sender(sender)
    local peer_id = peer:id()
    
    if not managers.trade:is_peer_in_custody(peer_id) then return end
    
    local current_time = TimerManager:game():time()
    local test_time = peer_tracker[peer:id()] and peer_tracker[peer:id()].stat_counter + 10 or 0
    
    if test_time < current_time then
      kick(peer_id, "auto respawn hack")
      return 0
    end
end)




Hooks:PostHook(BaseNetworkSession, "remove_peer", "hjsdfkjh39", function (peer, peer_id, reason)
  lobby_tasks.verified = false
end)
Hooks:PostHook(BaseNetworkSession, "_on_peer_removed", "hjsddfkjh39", function (peer, peer_id, reason)
  lobby_tasks.verified = false
end)
Hooks:PostHook(BaseNetworkSession, "_soft_remove_peer", "hjsdhghfkjh39", function (peer)
  lobby_tasks.verified = false
end)
Hooks:PostHook(BaseNetworkSession, "on_peer_left_lobby", "haajsdfkjh39", function (peer)
 lobby_tasks.verified = false
end)
Hooks:PostHook(BaseNetworkSession, "on_peer_left", "haajsdfkjh39", function (peer, peer_id)
 lobby_tasks.verified = false
end)
Hooks:PostHook(BaseNetworkSession, "on_peer_lost", "haajsdfkjh39", function (peer, peer_id)
  lobby_tasks.verified = false
end)
Hooks:PostHook(BaseNetworkSession, "on_peer_kicked", "haajsdfkjh39", function (peer, peer_id, message_id)
  lobby_tasks.verified = false
end)


Hooks:PreHook(BaseNetworkSession, "on_load_complete", "lobby_start", function(self)
    lobby_tasks.level_name = managers.job:current_level_id()
    lobby_tasks.difficulty_index = tweak_data:difficulty_to_index(Global and Global.game_settings and Global.game_settings.difficulty or 0)
    
    for i = 1, #locked_maps do
      if lobby_tasks.level_name == locked_maps[i] then
        lobby_tasks.locked_map = true
      end
    end
    
    host_setup()
    setup_bag_ids()
    setup_loot_drops()
    scan_elements()
end)

Hooks:PreHook(BaseNetworkSession, "spawn_member_by_id", "sjlsdf90", function (self, peer_id, spawn_point_id, is_drop_in)
    
    if peer_id and peer_id == 1 then return end
    if not is_drop_in and not managers.trade:is_peer_in_custody(peer_id) then return end
    
    local peer = 	managers.network:session():peer(peer_id)
    local current_time = TimerManager:game():time()
    
    if not peer_tracker[peer_id] then
      late_verify(peer_id)     
    end
    
    local test_time = peer_tracker[peer_id] and peer_tracker[peer_id].stat_counter and peer_tracker[peer_id].stat_counter + 10
    
    if test_time and test_time < current_time then
      kick(peer_id, "auto respawn hack")
      return 0
    end
end)

Hooks:PreHook(HostNetworkSession, "on_join_request_received", "djkhsd98ejd", function (self, peer_name, peer_account_type_str, peer_account_id, is_invite, preferred_character, xuid, peer_level, peer_rank, peer_stinger_index, join_attempt_identifier, sender)
    if session_history[peer_account_id] and session_history[peer_account_id].blocked then
      local host_steam_id = self._state_data.local_peer:user_id() or ""
      self._state:_send_request_denied(sender, 5, host_steam_id)
      return 0
    end 
end)
