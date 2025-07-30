-- Returns the network ids the entity is connected to
local function get_network_ids(entity)
    local networks = {}

    for wire_connector_id, wire_connector in pairs(entity.get_wire_connectors()) do
        -- Filter out copper wire and empty connections
        if  wire_connector.network_id ~= nil and
            wire_connector.wire_type ~= 1 and
            wire_connector.real_connection_count  > 0 then
                table.insert(networks, wire_connector.network_id)
        end
    end

    return networks
end

-- Returns all entities directly connected by circuit wires
local function get_wired_entities(entity)
    local entities = {}

    for wire_connector_id, wire_connector in pairs(entity.get_wire_connectors()) do
        -- Check if entity is connected to a circuit network
        local network = entity.get_circuit_network(wire_connector_id)

        -- Check for all directly connected entities
        if network then
            for _, wire_connection in ipairs(wire_connector.real_connections) do
                table.insert(entities, wire_connection.target.owner)
            end
        end
    end

    return entities
end

-- Returns all entities connected on the same circuit network
local function get_networked_entities(entity)
    local entities = get_wired_entities(entity)

    -- Get a list of networks the entity is connected to
    local networks = {}
    for _, network_id in ipairs(get_network_ids(entity)) do
        networks[network_id] = true
    end

    -- Do a DFS through wire connections
    local added_entities = {[entity.unit_number] = true}
    local entities_to_process = get_wired_entities(entity)

    while #entities_to_process > 0 do
        -- Get entities directly connected by wire
        local entity_to_process = table.remove(entities_to_process)
        local wired_entities = get_wired_entities(entity_to_process)

        for _, wired_entity in ipairs(wired_entities) do
            -- Check if entity was not processed
            if added_entities[wired_entity.unit_number] ~= true then
                added_entities[wired_entity.unit_number] = true
                
                for _, network_id in ipairs(get_network_ids(wired_entity)) do
                    if networks[network_id] then
                        table.insert(entities_to_process, wired_entity)
                        table.insert(entities, wired_entity)
                        break
                    end
                end
            end
        end
    end

    return entities
end

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

		pub_data("belt/" .. tostring(belt.unit_number) .. "/moved", { value = belt.moved })
		belt.moved = 0
	end)
