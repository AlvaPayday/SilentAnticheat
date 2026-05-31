
function WaitManager:spawn_waiting(peer_id)
	if not Network:is_server() then
		return
	end

	self._allowed_spawn[peer_id] = true

	self:remove_waiting(peer_id)

	local peer = managers.network:session():peer(peer_id)

	if not peer then
		return
	end
  
  if not peer_tracker[peer_id] then
    DelayedCalls:Add("late_verify_delayed", 10, function()
        late_verify(peer_id)
    end)
  end
  
	managers.achievment:set_script_data("cant_touch_fail", true)
	peer:spawn_unit(0, true)
	managers.groupai:state():fill_criminal_team_with_AI(true)
end
