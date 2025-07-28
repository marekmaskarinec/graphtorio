
script.on_event(defines.events.on_gui_opened,
	function(ev)
		if not ev.entity then
			return
		end

		local e = ev.entity
		if e.name ~= "observer" then
			return
		end

		local player = game.players[ev.player_index]
		player.opened = nil
	end
)

