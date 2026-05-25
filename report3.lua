local selection_index = 3

if managers.chat and managers.hud and managers.hud._teammate_panels then
  local panel = managers.hud._teammate_panels[selection_index]

  if panel then
      local peer_id = panel:peer_id()
      if peer_id then
        report(peer_id)
      elseif panel._ai then
        warn("No player reports for Team AI")
      end
  end
end