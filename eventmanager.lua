local element
local values

local locked_red2 = {
  thermite_placed = false,
  thermite_finished = false,
  vault_door_drill_placed = false,
  vault_door_open = false,
  vault_door_drill_start = 0,
  vault_door_timer = 0,
  vault_door_drill_finished = false,
  this_is_it = false
}

local locked_harvest = {
  
  vault_door_drill_placed = false,
  vault_door_open = false,
  vault_door_drill_start = 0,
  vault_door_timer = 0,
  vault_door_drill_finished = false
  
}

local locked_big = {
  thermite_enabled = false,
  thermite_placed = false,
  thermite_finished = false,
  vault_door_drill_placed = false,
  vault_door_open = false,
  vault_door_drill_start = 0,
  vault_door_timer = 0,
  vault_door_drill_finished = false
}

local function check_authority(id, unit)
  --return false if not authorized
  if not Utils:IsInHeist() then return true end
  
  local element = managers.mission:get_element_by_id(id)
  
  if element and element._obstacle_units and unit then --attempt by client to alter colliders
    local peer = managers.network:session():peer_by_unit(unit)
    if peer and not peer:is_host() then
      return false
    end
  end
  
  if lobby_tasks.level_name == "red2" then
    
    if id == 100670 then  --open vault hallway door
      if locked_red2.vault_door_drill_placed and lobby_tasks.drill_start > 0 then
        local current_time = TimerManager:game():time()
        local min_time = lobby_tasks.drill_start + (lobby_tasks.drill_time - 10)
        if current_time < min_time then
          return false
        end
      else
        return false
      end
    end
    
    if id == 136022 or id == 136211 or id == 136011 or id == 100635 or id == 136222 or id == 136022 then  -- call drill done
      local current_time = TimerManager:game():time()
      local min_time = lobby_tasks.drill_start + (lobby_tasks.drill_time - 10)
      if current_time < min_time then
        return false
      end
    end
    
    if id == 136239 or id == 100634 then
      locked_red2.vault_door_drill_placed = true
      locked_red2.vault_door_drill_start = TimerManager:game():time()
    end
    
    if id == 101321 then
      locked_red2.thermite_started = true
    end
    
    if id == 101341 then   
      --thermite finished
      locked_red2.thermite_finished = true
      for _, script in pairs(managers.mission:scripts()) do
        for id, element in pairs(script:elements()) do
         if element:id() == 101657 then
           local values = element:values()
           values.trigger_times = 1
           break
         end
        end
      end
      
       
    end
    
    if id == 101851 then  --normal trigger for overdrill
      --check player positions
      local coords = {
        Vector3(1209.17, 1252.96, -23.7953), 
        Vector3(2396.17, 1626.85, -23.7953),
        Vector3(2813.76, 1251.56, -23.7953),
        Vector3(2391.69, 896.16, -23.7953)
      }
      
      local counter = 0
      local unit
      for id, peer in pairs (managers.network:session():all_peers()) do
        for i = 1, #coords do
          unit = peer:unit()
          if unit and alive(unit) and mvector3.distance(unit:position(), coords[i]) < 80 then
            counter = counter + 1
          end
        end
      end
      
      if counter ~= 4 then
        return false
      end
      
      for _, script in pairs(managers.mission:scripts()) do
        for id, element in pairs(script:elements()) do
           for _, trigger in pairs(element:values().trigger_list or {}) do
            if trigger.notify_unit_sequence == "light_flicker" then
              trigger.notify_unit_sequence = "light_on"
              local values = element:values()
              values.trigger_times = 1
            end
           end
          
        end
      end
      locked_red2.this_is_it = true
      return true
    end
    
    if id == 102362 and unit then  -- attemped disable vault door collider
      --re-enable collider automatically
      if not locked_red2.thermite_finished then

        for _, script in pairs(managers.mission:scripts()) do
          for id, element in pairs(script:elements()) do
            if element:id() == 102362 then
              element:set_enabled(true)
              break
            end
          end
          
        end
        return false
      end
    end
  end
  
  if lobby_tasks.level_name == "branchbank" then
  
    if id == 105033 or id == 100311 then  --open vault door
      if lobby_tasks.drill_start > 0 then
        local current_time = TimerManager:game():time()
        local min_time = lobby_tasks.drill_start + (lobby_tasks.drill_time - 10)
        if current_time < min_time then
          return false
        end
      else
        return false
      end
    end
    
    if id == 100731 or id == 100732 then  --drill done
      if lobby_tasks.drill_start > 0 then
        local current_time = TimerManager:game():time()
        local min_time = lobby_tasks.drill_start + (lobby_tasks.drill_time - 10)
        if current_time < min_time then
          return false
        end
      else
        return false
      end
    end
    
    if lobby_tasks.level_name == "roberts" then
      
      if id == 102891 then  --drill done
        if lobby_tasks.drill_start > 0 then
          local current_time = TimerManager:game():time()
          local min_time = lobby_tasks.drill_start + (lobby_tasks.drill_time - 10)
          if current_time < min_time then
            return false
          end
        else
          return false
        end
      end
      
      if id == 102892 then  --open vault
        if lobby_tasks.drill_start > 0 then
          local current_time = TimerManager:game():time()
          local min_time = lobby_tasks.drill_start + (lobby_tasks.drill_time - 10)
          if current_time < min_time then
            return false
          end
        else
          return false
        end
      end
      
      if id == 105707 and unit then  --already opened vault trigger (rng)
        return false
      end
      
    end
    
  end
  
  if lobby_tasks.level_name == "big" then
--    if id == 105169 then
--      locked_big.thermite_enabled = true
--    end
    
--    if id == 101409 then  --thermite placed
--      locked_big.vault_door_drill_placed = true
--      locked_big.vault_door_drill_start = TimerManager:game():time()
--    end
  end
  
  return true
end


Hooks:PreHook(MissionScriptElement, "on_executed", "dwe_cmse_on_executed", function (self, instigator, alternative, skip_execute_on_executed, sync_id_from)
  
  
  if not lobby_tasks.locked_map then return end
  
  local authorized = check_authority(self._id, instigator)
  
  if not authorized then 
    skip_execute_on_executed = true
    return
  end
  
  element = managers.mission:get_element_by_id(self._id)
  
  local values = nil
  
  if element and element:values() then
    values = element:values()
  end
  
  if values and values.icon and values.icon == "pd2_escape" then
    lobby_tasks.escape_enabled = true
  end

  
end)

Hooks:PostHook(MissionManager, "to_server_area_event", "dwe_to_server_area_event", function(self, event_id, id, unit)
  
  if not lobby_tasks.locked_map then return end
  
  element = managers.mission:get_element_by_id(self._id)
  
  local values = nil
  
  if element and element:values() then
    values = element:values()
  end
  
  if values and values.icon and values.icon == "pd2_escape" then
    lobby_tasks.escape_enabled = true
  end

end)

