local drill_map = {
  
  red2 = {
    name = "lance", 
    min_time = 240
  },
  
  branchbank = {
    name = "lance", 
    min_time = 240    
  },
  
  roberts = {
    name = "lance", 
    min_time = 240
  }
  
}

Hooks:PreHook(MissionDoorDeviceInteractionExt, "sync_interacted", "last_touched_drill", function (self, peer, player, status, skip_alive_check)
  if self._unit:interaction() and self._unit:interaction().tweak_data and peer then
    lobby_tasks.drill_instigator = peer:unit()
  end
end)

Hooks:PreHook(Drill, "start", "start_drill", function (self)
  
  local unit = self._unit
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
        self._unit:timer_gui()["_current_timer"] = 360
        self._unit:timer_gui()["_timer"] = 360
        managers.network:session():send_to_peers_synched("start_timer_gui", unit, 360)
        --TODO: remove user here
    end
      
  end
  
  
  if lobby_tasks.locked_map and self._unit:interaction() and self._unit:interaction().tweak_data then
    local drill_name = self._unit:interaction().tweak_data
    local drill_time = tonumber(self._unit:timer_gui()["_current_timer"])
    
    if lobby_tasks.level_name == "red2" then
      if drill_name and drill_name == drill_map.red2.name then
        if drill_time < tonumber(drill_map.red2.min_time) then
          self._unit:timer_gui()["_current_timer"] = drill_map.red2.min_time
          drill_time = tonumber(drill_map.red2.min_time)
        end
        lobby_tasks.drill_start = TimerManager:game():time()
        lobby_tasks.drill_time = drill_time 
      end
    end
    
    if lobby_tasks.level_name == "branchbank" then
      if drill_name and drill_name == drill_map.branchbank.name then
        if drill_time < tonumber(drill_map.branchbank.min_time) then
          self._unit:timer_gui()["_current_timer"] = drill_map.branchbank.min_time
          drill_time = tonumber(drill_map.branchbank.min_time)
        end
        lobby_tasks.drill_start = TimerManager:game():time()
        lobby_tasks.drill_time = drill_time 
      end
    end
    
    if lobby_tasks.level_name == "roberts" then
      if drill_name and drill_name == drill_map.roberts.name then
        if drill_time < tonumber(drill_map.roberts.min_time) then
          self._unit:timer_gui()["_current_timer"] = drill_map.roberts.min_time
          drill_time = tonumber(drill_map.roberts.min_time)
        end
        lobby_tasks.drill_start = TimerManager:game():time()
        lobby_tasks.drill_time = drill_time 
      end
    end
    
  end  --if lobby_tasks.locked_map
 
end)


