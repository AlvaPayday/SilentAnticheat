_G.peer_tracker = _G.peer_tracker or {}

_G.session_history = {}

_G.lobby_tasks = {
  verified = false,
  escape_enabled = false,
  has_no_return = false,
  level_name = "",
  difficulty_index = 0,
  locked_map = false,
  drill_start = 0,
  drill_time = 0,
  drill_instigator = nil
}

_G.bag_ids = {}
_G.loot_drops = {}

_G.locked_maps = {
  "red2",
  "branchbank",
  "roberts"
}

local weapon_category = {
  smg = 600,
  lmg = 800,
  pistol = 1200,
  shotgun = 1200,
  assault_rifle = 1040,
  snp = 14700, 
  flamethrower = 150,
  grenade_launcher = 7800,
  crossbow = 12000
}

drill_names = {
  
  "drill",
  "lance",
  "lance_bbv",
  "apartment_drill",
  "suburbia_drill",
  "goldheist_drill",
  "hospital_saw"
}

function init_new_player(peer_id)
  peer_tracker[peer_id] = {}
  peer_tracker[peer_id].pdata = {
  name = "",                  --friendly name for the user (their steam profile name)
  modded = false,             --do they have mods
  mods_verified = false,      --have the mods been scanned already
  hidden_verified = false,    --have we checked if they have hidden mods yet
  sp_verified = false,        --have total skill points been verified? 
  full_verified = false,      --true if all data points have been collected. this counts towards lobby_tasks.verified
  upgrades_loaded = false,    --has the player been scanned for upgrades (messiah, inspire, etc)
  mod_count = 0,              --total mod count
  hiding_mods = false,        --user is hiding mods
  blocked = false,            --if blocked==true on a rejoin, player will auto-disconnect (saved in sessionhistory{})
  user_id = nil,              --steam user id
  ip_address = nil,           --currently not used (reserved if needed)
  primary_weap_id = nil,      --primary weapon internal name
  secondary_weap_id = nil,    --secondary weapon internal name
  primary_damage = 0,         --damage sampled from the weapon during gameplay
  secondary_damage = 0,       --damage sampled from the weapon during gameplay
  damage_interval = 0,        --tracks the shortest recorded damage interval
  last_damage = 0,            --last time player took damage
  has_pocket_ecm = false,     --verifies if a pocket ecm is equipped in the throwable slot
  max_revives = -1,            -- starting max # of revives for the player
  revives = 0,                -- current # of revives left
  has_messiah = false,        --does the user have messiah (1 charge for auto revive, recharge on doc bag use)
  has_inspire = false,        --does the user have inspire aced (long distance revive)
  inspire_time = 0,           --last used time of inspire (did they hack cooldown)
  has_feign_death = false,    --does the user have feign death (chance for auto-revive) TODO
  messiah_charges = 1,        --track use of messiah charges internally (avoid client verification) TODO
  stat_counter = 0,           --general counter used for various tasks
  stat_array_1 = {},          --array used to hold various test values
  stat_array_2 = {},          --array used to hold various test values
  custody = false,            --is the player in custody. stat_counter tracks custody time
  carry_id = "none",          --the id of the bag to check against secured hacks and spawning non-map loot
  armor = 0,                  --max armor value
  health = 0                  --max health value

}
end

function host_warn(text)
  managers.chat:_receive_message(ChatManager.GAME, "[SA] ", text, Color.red)
end

function host_kick_warn(text)
  managers.chat:_receive_message(ChatManager.GAME, "[SA] ", text, Color.red)
  managers.chat:_receive_message(ChatManager.GAME, "[SA] ", "you will be kicked from the game in 30 seconds", Color.red)
  DelayedCalls:Add("host_kick", 30, function()
      dropPeer (1, nil)
  end)
  
end

function broadcast(text)
  if Utils:IsInGameState() and managers.chat then 
    managers.network:session():send_to_peers("send_chat_message", ChatManager.GAME, "[SA] " .. text, Color.red)
    managers.chat:_receive_message(ChatManager.GAME, "[SA] ", text, Color.red)
  end
end

function warn(text)
  if Utils:IsInGameState() and managers.chat then 
    managers.chat:feed_system_message(ChatManager.GAME, text)
  end
end

local function has_skill(skill_name, unit)
  return PlayerSkill.has_skill("player", skill_name, unit) or nil
end

local function skill_level(skill_name, unit)
  return unit:base():upgrade_level("player", skill_name) or nil
end

function scan_mods (peer)
  
  if not peer._mods then
    peer_tracker[peer:id()].pdata.mod_count = 0
  else
    local count = #peer._mods
    
    
    if type(count) == "number" then
      peer_tracker[peer:id()].pdata.mod_count = count
    end
  end
  
  for i, mod in ipairs(peer._mods) do
    for i = 1, #bannedMods do
        if string.lower(mod.name) == string.lower(bannedMods[i]) then
          peer_tracker[peer:id()].pdata.blocked = true
          cold_storage(peer:id())
          dropPeer(peer:id(), mod.name)
          return
        end            
    end
    
    if string.find(string.lower(mod.name), "gab") or string.find(string.lower(mod.name), "2.pw") or string.find(string.lower(mod.name), "p3d") or string.find(string.lower(mod.name), "trainer") then
    --check exclusion list
      local excluded = false
      
      for i = 1, #exclusion_list do
        if string.lower(mod.name) == string.lower(exclusion_list[i]) then
          excluded = true
          break
        end
      end
      
      if not excluded then
        peer_tracker[peer:id()].pdata.blocked = true
        cold_storage(peer:id())
        dropPeer(peer:id(), mod.name)
        return
      end
    end
    
  end

  peer_tracker[peer:id()].pdata.mods_verified = true
  if peer_tracker[peer:id()].pdata.sp_verified then
    warn(peer:name() .. " verified mods and skill points")
  end
  
end

function god_tracker (peer)
  
  DelayedCalls:Add("check_god_status", 3, function()      
      if peer then
        local unit = peer:unit()
        if alive(unit) then
          if unit:character_damage()._mission_damage_blockers and unit:character_damage()._mission_damage_blockers.invulnerable then
            AlvasMod:msg("Invulnerable: " .. peer:name())
            unit:contour():add("tmp_invulnerable",true)
            unit:contour():flash("tmp_invulnerable", 0.2)
            managers.network:session():send_to_peers_synched("sync_contour_add", unit, -1, table.index_of(ContourExt.indexed_types, "tmp_invulnerable"), 1) 
            god_tracker (peer)
          end
        end
      end
  end)
  
end

function cold_storage (peer_id)
  local pdata = peer_tracker[peer_id].pdata
  if pdata then
    if not session_history[pdata.user_id] then
      session_history[pdata.user_id] = {
        blocked = pdata.blocked,
        ip_address = nil,
        modded = pdata.modded,
        hiding_mods = pdata.hiding_mods        
      }      
    end      
  end
end

function dropPeer (id, reason)
  local peer = managers.network._session:peer(id)
  if not peer then return end
  
  local peer_name = peer:name()
  
	if peer then
		managers.network._session:on_peer_kicked(peer, id, 0)
		managers.network._session:send_to_peers("kick_peer", id, 0)
    --managers.ban_list:ban(peer:user_id(), peer:name())
	end
  
  local text
  
  if reason then 
    text = peer_name .. " has been removed for : " .. reason
  end
  
  if AlvasMod then
    if reason then
      AlvasMod:broadcast(text)
    else
      AlvasMod:broadcast(peer:name() .. " cheated and has been removed")
    end
  else
    if reason then
     warn(text)
    end
  end
end

function kick(peer_id, reason)
  peer_tracker[peer_id].pdata.blocked = true
  cold_storage(peer_id)
  dropPeer(peer_id, reason)
end

function check_player_verified (peer)
  local pdata = peer_tracker[peer:id()].pdata
  
  
  if lobby_tasks.difficulty_index >= 7 and pdata.damage_interval > 0 and pdata.damage_interval <= 0.385 and pdata.mods_verified and pdata.sp_verified and pdata.upgrades_loaded then
    if pdata.primary_damage > 0 or pdata.secondary_damage > 0 then
      peer_tracker[peer:id()].pdata.fully_verified = true
      return true
    end  
  elseif lobby_tasks.difficulty_index < 7 and pdata.damage_interval > 0 and pdata.damage_interval <= 0.485 and pdata.mods_verified and pdata.sp_verified and pdata.upgrades_loaded then
    if pdata.primary_damage > 0 or pdata.secondary_damage > 0 then
      peer_tracker[peer:id()].pdata.fully_verified = true
      return true
    end  
  end
  
  return false
end

function check_lobby_verified()
  
  local verify_count = 0
  local all_peers = managers.network:session():all_peers()
  local peer_total_count = #all_peers
  
  for id, peer in pairs(all_peers) do
    
    if peer_tracker[peer:id()].pdata.fully_verified then
      verify_count = verify_count + 1
    end
    
    if verify_count == peer_total_count then
      lobby_tasks.verified = true
      return
    end    
  end
end

function check_allowed_bag (id)
  for i = 1, #bag_ids do
    if id == bag_ids[i] then
      return true
    end
  end
  return false
end

function check_loot_drop_distance(unit)
  if not unit then return false end
  
--check distance to loot drop
  local player_position = unit:position()
  local within_range = false
  local distance
  
  for i = 1, #loot_drops do
    distance = mvector3.distance(player_position, loot_drops[i])
    if distance < 500 then  --arbitrary value, not tested
      within_range = true
    end
  end
  
  if not within_range then
    warn(peer:name() .. " secured loot bag not within range of a drop point.")
  end
  
  return within_range
end

function scan_elements()
  for _, script in pairs(managers.mission:scripts()) do
    for id, element in pairs(script:elements()) do
      if element:editor_name() and string.find(element:editor_name(), "point_no_return") then
        lobby_tasks.has_no_return = true
      end
    end
  end
end

function destroy_unit(unit)
  unit:set_visible(false)
	unit:set_enabled(false)
  unit:set_slot(0)
end

function peer_setup (peer)

  if not peer then return end
  if not peer:unit() then return end
  
  local unit = peer:unit()
  local base_ext = unit:base()
  local id = peer:id()

  peer_tracker[id].pdata.has_pocket_ecm = base_ext:upgrade_value("player", "pocket_ecm_jammer_base") ~= nil
  peer_tracker[id].pdata.has_feign_death = base_ext:upgrade_value("player", "cheat_death_chance") ~= nil
  
  local upgrades = base_ext._upgrades.player
  local movement = base_ext._ext_movement
  
  if upgrades then 
    
    if upgrades.run_speed_multiplier and upgrades.run_speed_multiplier > 1.25 then
      warn(peer:name() .. " has run speed multiplier: " .. upgrades.run_speed_multiplier)
    end
    
    if upgrades.passive_convert_enemies_health_multiplier and upgrades.passive_convert_enemies_health_multiplier > 0.01 then
      warn(peer:name() .. " has convert enemies health multiplier: " .. upgrades.passive_convert_enemies_health_multiplier)
    end
    
    if upgrades.convert_enemies_max_minions and upgrades.convert_enemies_max_minions > 3 then
      warn(peer:name() .. " has convert max minions: " .. upgrades.convert_enemies_max_minions)
    end
    
    if movement and movement._synced_max_speed and movement._synced_max_speed > 805 then
      warn(peer:name() .. " synced movement speed abnormally high: " .. movement._synced_max_speed)
    end
    
  end
  
  local is_warning = false
  local test_value = 0
  local results = {}

  if has_skill("passive_dodge_chance", unit) then
    test_value = unit:base():upgrade_value("player", "passive_dodge_chance")
    if test_value >= 0.70 then
      is_warning = true
      test_value = math.floor(test_value * 100)
      table.insert(results, "passive dodge chance: " .. tostring(test_value).."%")
    end
  end
  
  if has_skill("run_dodge_chance", unit) then
    test_value = unit:base():upgrade_value("player", "run_dodge_chance")
    if test_value >= 0.75 then
      is_warning = true
      test_value = math.floor(test_value * 100)
      table.insert(results, "run dodge chance: " .. tostring(test_value).."%")
    end
  end
  
  if unit:interaction() and unit:interaction():interact_distance() then
    test_value = unit:interaction():interact_distance()
    if test_value and test_value > 300 then
      is_warning = true
      table.insert(results, "interact distance hack. normal 300, value : " .. test_value)
    end
  end
  
  if is_warning then
    for i = 1, #results do
      warn(peer:name() .. " " .. results[i])
    end
  end
  
  peer_tracker[id].pdata.upgrades_loaded = true
end

function host_setup()
    
    init_new_player(1)
  
    local peer = managers.network:session():local_peer()
    local peer_id = 1
    local primary, secondary
    local sp_total = 0
    local mod_count = 0
    local outfit_string = managers.blackmarket:outfit_string()
    local outfit = managers.blackmarket:unpack_outfit_from_string(outfit_string)
    
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
      end
      
    end
    
end

function late_verify (peer_id)
  local peer = 	managers.network:session():peer(peer_id)
  if not peer then return end
  
  init_new_player(peer_id)
  
  local outfit = peer:blackmarket_outfit()
  local primary, secondary
  local sp_total = 0
  local mod_count = 0
  
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
      elseif sp_total > 120 then
       peer_tracker[peer_id].pdata.blocked = true
       cold_storage(peer_id)
       dropPeer(peer_id, "skill points: " .. tostring(sp_total))
      end
  else
    peer_tracker[peer_id].pdata.blocked = true
    cold_storage(peer_id)
    dropPeer(peer_id, "hacked or corrupted outfit")
  end
  
  scan_mods(peer)
  peer_setup(peer)
end

  
function check_weapon_damage(peer, name_id, damage)
  local category = tweak_data.weapon[name_id].categories[1]
  
  if weapon_category[category] then
    local threshold = weapon_category[category]
    
    if category == weapon_category.grenade_launcher and name_id == "rpg7" then
        category = "rpg7"
        threshold = 49000
    end
    
    if damage > threshold then
      host_warn(peer:name() .. " weapon : " .. category .. " above damage threshold: " .. damage)
      return false
    end
  end
  return true
end

local function setupScripts ()
  
  local level = managers.job:current_level_id()
  
  if level == "red2" then
    for _, script in pairs(managers.mission:scripts()) do
			for id, element in pairs(script:elements()) do
         if element:id() == 101657 then  --vault door
           local values = element:values()
           values.trigger_times = 0
         end

         for _, trigger in pairs(element:values().trigger_list or {}) do
					if trigger.notify_unit_sequence == "light_on" then
            trigger.notify_unit_sequence = "light_flicker"
            local values = element:values()
            values.trigger_times = 0
          end
         end
        
      end
   end
  end

end


local friendly_name = {
  
  m16  = "AMR-16",
  x_shrew = "Akimbo Crosskill",
  model70 = "Platypus Sniper", 
  polymer = "Kross Vertex SMG",
  vityaz = "AK-21 SMG", 
  uzi = "UZI SMG", 
  r93 = "R93 Sniper", 
  tec9 = "9mm SMG", 
  x_baka = "Akimbo UZI", 
  x_tec9 = "Akimbo 9mm SMG", 
  hk21 = "Brenner LMG", 
  x_m45 = "Akimbo Swedish K", 
  spas12 = "Predator 12G", 
  saw_secondary = "Saw", 
  g26 = "Chimano Pistol", 
  l85a2 = "Queens Rath", 
  x_model3 = "Akimbo Revolvers",
  sterling = "L2A1 SMG", 
  x_chinchilla = "Akimbo Castigo", 
  slap = "40mm GL", 
  x_sr2 = "Akimbo Heather SMG", 
  x_stech = "Akimbo Igor Pistols", 
  type54 = "Model 54 Pistol", 
  sbl = "Bernetti Sniper", 
  msr = "Rattlesnake Sniper", 
  x_mp7 = "Akimbo SpecOps SMG", 
  x_p90 = "Akimbo p90 SMG", 
  elastic = "Compound Bow", 
  ray = "Rocket Launcher", 
  rsh12 = "RUS-12 Revolver", 
  contraband = "Little Friend AR", 
  m1928 = "Typewriter SMG", 
  m1911 = "Chunky Pistol", 
  x_rage = "Akimbo Bronco",
  dart = "Dart", 
  victor = "Northstar Sniper", 
  x_sparrow = "Akimbo Deagle", 
  x_uzi = "Akimbo UZI", 
  x_m1911 = "Akimbo Chunky Pistol", 
  x_pm9 = "Miyaka 10 SMG", 
  x_usp = "Akimbo Interceptor", 
  x_sterling = "Akimbo L2A1 SMG", 
  x_shepheard = "Akimbo Signature SMG", 
  tti = "Contractor 308"
  
}


function report (peer_id)
  local pdata = peer_tracker[peer_id].pdata
  
  local text = "\n" .. pdata.name .. "\n" .. "___________________" .. "\n"
  
  if pdata.mod_count == 0 and pdata.hiding_mods then
    text = text .. "mods: 0 (hiding mods)" .. "\n"
  elseif pdata.mod_count == 0 and not pdata.hiding_mods then
    text = text .. "mods: 0" .. "\n"
  elseif pdata.mod_count > 0 then
    text = text .. "mods: " .. pdata.mod_count .. "\n"
  end
  
  local health = math.floor(pdata.health)
  local armor = math.floor(pdata.armor)
  local primary = peer_tracker[peer_id].pdata.primary_weap_id
  local secondary = peer_tracker[peer_id].pdata.secondary_weap_id
  local primary_name, secondary_name
  
  if friendly_name[primary] then
    primary_name = friendly_name[primary]
  else
    primary_name = managers.weapon_factory:get_weapon_name_by_weapon_id(primary)
  end
  
  if friendly_name[secondary] then
    secondary_name = friendly_name[secondary]
  else
    secondary_name = managers.weapon_factory:get_weapon_name_by_weapon_id(secondary)
  end
  
  text = text .. "health: " .. health .. "  armor: " .. armor .. "\n"

  text = text .. primary_name .. " damage (primary): " .. pdata.primary_damage .. "\n" .. secondary_name .. " damage (2nd): " .. pdata.secondary_damage .. "\n"
  if pdata.sp_verified then
    text = text .. "skill points: verified" .. "\n"
  end
  
  if pdata.fully_verified then
    text = text .. "fully verified: yes" .. "\n"
  else
    text = text .. "fully verified: no" .. "\n"
  end
  
  if pdata.damage_interval > 0 then
    if lobby_tasks.difficulty_index >= 7 and pdata.damage_interval > 0.35 and pdata.damage_interval <= 38.5 then
      text = text .. "damage interval: normal" .. "\n"
    elseif lobby_tasks.difficulty_index < 7 and pdata.damage_interval > 0.45 and pdata.damage_interval <= 48.5 then
      text = text .. "damage interval: normal" .. "\n"
    else
      text = text .. "damage interval: abnormal(high)" .. "\n"
    end
  end
  
  text = string.gsub(text, "0", "...")
  warn(text)
end

function player_report(selection_index)
  if Utils:IsInHeist() and managers.chat and managers.hud and managers.hud._teammate_panels then
      
    local panel = managers.hud._teammate_panels[selection_index]
    local name = string.sub(panel._panel:child("name"):text(),2)
    
    if panel._ai then      
      warn("No reports for Team AI: " .. name )
    else
      for i, peer in pairs (managers.network:session():all_peers()) do
        if peer:name() == name then
          if peer_tracker[peer:id()] and peer_tracker[peer:id()].pdata.name ~= name then
            late_verify(peer:id())
          end
          
          report (peer:id())
        end
      end
    end
  end

end

function delay_kick (peer, delay)
  --tied to extra_crispy for explosion effect
  DelayedCalls:Add("kick_delay", delay, function ()
    if peer_tracker[peer:id()] then peer_tracker[peer:id()].pdata.blocked = true end
    local proj = World:spawn_unit(Idstring("units/payday2/weapons/wpn_frag_grenade/wpn_frag_grenade"), peer:unit():position(), Rotation())
    proj:base():_detonate()
    cold_storage(peer_id)
    dropPeer(peer_id, nil)  
    
  end)
  
end

function extra_crispy(peer, reason)
  
  if peer:is_host() then
   local unit = peer:unit()
   peer_tracker[1].pdata.blocked = true
   managers.player:set_player_state("arrested")
   DelayedCalls:Add("burn_cheater", 0.5, function()
     local pos = peer:unit():position()
     local unit = peer:unit()
     local sound_source = unit:sound_source()
     local proj = World:spawn_unit(Idstring("units/pd2_dlc_bbq/weapons/molotov_cocktail/wpn_molotov_third"), pos, Rotation())
     proj:base():_detonate()
     unit:sound_source():post_event("burnhurt")
     broadcast(peer:name() ..  " " .. reason)
     broadcast(peer:name() .. " will now be obliterated.")
     delay_kick(peer, 2.5)
   end)
   
  else
    local network, send 
    network = peer:unit():network()
    send = network.send
    send(network, "sync_player_movement_state", "arrested", 0, peer:id())
    peer_tracker[peer:id()].pdata.blocked = true
    DelayedCalls:Add("burn_cheater", 0.5, function()
     local pos = peer:unit():position()
     local unit = peer:unit()
     local sound_source = unit:sound_source()
     local proj = World:spawn_unit(Idstring("units/pd2_dlc_bbq/weapons/molotov_cocktail/wpn_molotov_third"), pos, Rotation())
     proj:base():_detonate()
     unit:sound_source():post_event("burnhurt")
     broadcast(peer:name() ..  " " .. reason)
     delay_kick(peer, 2.5)
   end)
  end
end