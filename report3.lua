local selection_index = 3

if managers.chat and managers.hud and managers.hud._teammate_panels then
  local panel = managers.hud._teammate_panels[selection_index]
  
  if panel._ai then
    warn("No reports for Team AI")
  else
    local peer = managers.network:session():peer(panel:peer_id())
    if peer then
      report(peer:id())
    end    
  end
end
