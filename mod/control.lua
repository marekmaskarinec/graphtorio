
local function pub_data(topic, data)
	helpers.write_file("out.json", topic .. "\t" .. helpers.table_to_json(data) .. "\n", true)
end

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

local belt = {}

script.on_event(defines.events.on_tick,
	function(ev)
		local player = game.players[1]
		local selected = player.selected

		if selected == nil then return end
		if selected.type ~= "transport-belt" then return end

		local function build_item_table(ent)
			local items_in = ent.get_transport_line(1).get_detailed_contents()
			for _,v in ipairs(ent.get_transport_line(2).get_detailed_contents()) do
				table.insert(items_in, v)
			end

			local items = {}
			for _,item in ipairs(items_in) do
				items[item.unique_id] = item.stack
			end

			return items
		end

		local items = build_item_table(selected)

		if belt.unit_number ~= selected.unit_number then
			belt.unit_number = selected.unit_number
			belt.items = items
			belt.moved = 0
		end

		for id,_ in pairs(belt.items) do
			if items[id] == nil then
				belt.moved = belt.moved + 1
			end
		end

		belt.items = items
	end)

script.on_nth_tick(60,
	function (ev)
		if belt.moved == nil then return end

		game.print(belt.moved)
		pub_data("belt/" .. tostring(belt.unit_number) .. "/moved", { value = belt.moved })
		belt.moved = 0
	end)
