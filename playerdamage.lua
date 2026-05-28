function scandir(directory)
    local i, t, popen = 0, {}, io.popen
    local pfile = popen('dir "'..directory..'" /b /ad')
    for filename in pfile:lines() do
        i = i + 1
        t[i] = filename
    end
    pfile:close()
    return t
end

local function check_stats()
  local peer = managers.network:session():local_peer()
  local unit = peer:unit()
  
  local dmg_ext = unit:character_damage()
  local verified = true
  
  if dmg_ext._god_mode or dmg_ext._immortal then
    verified = false
  end
  
  if lobby_tasks.difficulty_index >= 7 and dmg_ext._dmg_interval > 0.35 then
    verified = false
  elseif lobby_tasks.difficulty_index < 7 and dmg_ext._dmg_interval > 0.45 then
    verified = false
  end
  
  if peer_tracker[1].pdata.health and peer_tracker[1].pdata.armor then
    if peer_tracker[1].pdata.health > 594 or peer_tracker[1].pdata.armor > 492 then
      verified = false
    end
  end
  
  if not verified then
    local peer_id = 1
    host_kick_warn("You cannot use Silent Anticheat while cheating. Disable cheats!")
  end
  
  peer_tracker[1].pdata.has_feign_death = managers.player:upgrade_value("player", "cheat_death_chance") ~= nil
  peer_tracker[1].pdata.has_inspire = unit:movement():rally_skill_data() and unit:movement():rally_skill_data().long_dis_revive ~= nil
  
  local mod_path = BLTModManager.Constants.mods_directory
  local mods_tbl = scandir(mod_path)
  local soup = true
  
  for i = 1, #bannedMods do
    for idx = 1, #mods_tbl do
      if string.lower(mods_tbl[idx]) == string.lower(bannedMods[i]) then
        soup = false
      end
    end           
  end
  
  if not soup then 
   host_kick_warn("You cannot use Silent Anticheat while cheating (banned mods)")
  end
end

Hooks:PostHook(PlayerDamage, "set_health", "asd9udfs9fdsuo", function (self, health)
    
  if peer_tracker[1].pdata.health == 0 then
    peer_tracker[1].pdata.health = (self:_max_health() * 10)
  end
end)


Hooks:PostHook(PlayerDamage, "set_armor", "hjsdy893hkjdf", function (self, armor)
  if peer_tracker[1].pdata.armor == 0 then
    peer_tracker[1].pdata.armor = (self:_max_armor() * 10)
    DelayedCalls:Add("check_stats", 10, function()
      check_stats()
    end)
  end
    
end)

Hooks:PostHook(PlayerDamage, "set_god_mode", "jlaflsfserdf", function (self, state)
  local peer_id = 1
  
  host_kick_warn("You cannot use Silent Anticheat while cheating (god mode)")
    
end)

Hooks:PreHook(PlayerManager, "set_player_state", "uiouiouou", function (self, state)
  if self._current_state == "arrested" then
    if peer_tracker[1].pdata.blocked then
      state = "arrested"
      return
    end    
  end    
    
end)