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
  
  if dmg_ext._dmg_interval > 0.35 then
    verified = false
  end
  
  if peer_tracker[1].pdata.health and peer_tracker[1].pdata.armor then
    if peer_tracker[1].pdata.health > 594 or peer_tracker[1].pdata.armor > 492 then
      verified = false
    end
  end
  
  if not verified then
    local peer_id = 1
    peer_tracker[peer_id].pdata.blocked = true
    cold_storage(peer_id)
    dropPeer(peer_id, "")
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
    peer_tracker[1].pdata.blocked = true
    cold_storage(1)
    dropPeer(1, "")
  end
end

local old_set_health = PlayerDamage.set_health
function PlayerDamage:set_health(health)
  
  if peer_tracker[1].pdata.health == 0 then
    peer_tracker[1].pdata.health = self:_max_health()
  end
  
  old_set_health(self, health)
end

local old_set_armor = PlayerDamage.set_armor

function PlayerDamage:set_armor(armor)
  if peer_tracker[1].pdata.armor == 0 then
    peer_tracker[1].pdata.armor = self:_max_armor()
    DelayedCalls:Add("check_stats", 10, function()
      check_stats()
    end)
  end
  
  old_set_armor(self, armor)
  
end

function PlayerDamage:set_god_mode(state)
  local peer_id = 1
  peer_tracker[peer_id].pdata.blocked = true
  cold_storage(peer_id)
  dropPeer(peer_id, "")
end

local old_set_movement = PlayerManager.set_player_state
function PlayerManager:set_player_state(state)
  if self._current_state == "arrested" then
    if peer_tracker[1].pdata.blocked then
      return
    end    
  end
  old_set_movement(self, state)
end