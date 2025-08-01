local discover = require("discover")
local potential = require("potential")
local ore = require("ore")
local utils = require("utils")

-- Returns the network ids the entity is connected to
local function get_network_ids(entity)
	local networks = {}

	for wire_connector_id, wire_connector in pairs(entity.get_wire_connectors()) do
		-- Filter out copper wire and empty connections
		if
			wire_connector.network_id ~= nil
			and wire_connector.wire_type ~= 1
			and wire_connector.real_connection_count > 0
		then
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

local function get_networked_entities(entity)
	if entity.unit_number == nil then return {} end

	local entities = get_wired_entities(entity)

	-- Get a list of networks the entity is connected to
	local networks = {}
	for _, network_id in ipairs(get_network_ids(entity)) do
		networks[network_id] = true
	end

	-- Do a DFS through wire connections
	local added_entities = { [entity.unit_number] = true }

	local entities_to_process = get_wired_entities(entity)
	for _, entity in ipairs(entities_to_process) do
		added_entities[entity.unit_number] = true
	end

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

-- The pub data is buffered because sometimes the game drops data when calling
-- multiple writes per tick.
local g_pub_buffer = ""
local function pub_data(topic, data)
	local s = topic .. "\t" .. helpers.table_to_json(data) .. "\n"
	g_pub_buffer = g_pub_buffer .. s
end

local function dump_pub_buffer()
	if string.len(g_pub_buffer) == 0 then
		return
	end
	helpers.write_file("out.json", g_pub_buffer, true)
	g_pub_buffer = ""
end

local function update_observer_data(observer)
	local data = {}
	data.ent = observer
	data.networked_ents = get_networked_entities(observer)
	data.wired_ents = get_wired_entities(observer)
	data.belts = {}
	for i, ent in ipairs(data.networked_ents) do
		if ent.type == "transport-belt" then
			data.belts[#data.belts + 1] = {
				ent = ent,
				unit_number = ent.unit_number,
				inputs = discover.discover(ent, true),
				outputs = discover.discover(ent, false),
				items = {},
				moved = {},
			}

			local outputs = potential.calculate(data.belts[#data.belts].outputs)
			pub_data("belt/" .. ent.gps_tag .. "/potential_outputs", outputs)
			local inputs = potential.calculate(data.belts[#data.belts].inputs)
			pub_data("belt/" .. ent.gps_tag .. "/potential_inputs", inputs)
		end
	end

	if storage.observer_data == nil then
		storage.observer_data = {}
	end
	storage.observer_data[observer.unit_number] = data
end

script.on_event(defines.events.on_gui_opened, function(ev)
	if not ev.entity then
		return
	end

	local e = ev.entity
	if e.name ~= "observer" then
		return
	end

	local player = game.players[ev.player_index]
	player.opened = nil

	update_observer_data(ev.entity)
end)

local function belts_on_tick_handler()
	if storage.observer_data == nil then
		return
	end

	local function build_item_table(ent)
		local items_in = ent.get_transport_line(1).get_detailed_contents()
		for _, v in ipairs(ent.get_transport_line(2).get_detailed_contents()) do
			table.insert(items_in, v)
		end

		local items = {}
		for _, item in ipairs(items_in) do
			items[item.unique_id] = { name = item.stack.name, count = item.stack.count }
		end

		return items
	end

	local function handle_belt(belt)
		local items = build_item_table(belt.ent)

		if belt.items == nil then
			belt.items = items
		end

		for id, item in pairs(belt.items) do
			if items[id] == nil then
				if belt.moved[item.name] == nil then
					belt.moved[item.name] = 0
				end
				belt.moved[item.name] = belt.moved[item.name] + item.count
			end
		end

		belt.items = items
	end

	for unit_number,data in pairs(storage.observer_data) do
		if data.ent and data.ent.valid == false then
			game.print(unit_number)
			storage.observer_data[unit_number] = nil
		end
	end

	for _, data in pairs(storage.observer_data) do
		local i = 1
		while i <= #data.belts do
			local belt = data.belts[i]
			if belt.ent.valid == false then
				table.remove(data.belts, i)
			else
				handle_belt(belt)
				i = i + 1
			end
		end
	end
end

script.on_event(defines.events.on_tick, function(ev)
	dump_pub_buffer()

	belts_on_tick_handler()
end)

script.on_nth_tick(60, function(ev)
	if storage.observer_data == nil then
		return
	end

	local function handle_belt(belt)
		pub_data("belt/" .. belt.ent.gps_tag .. "/moved", belt.moved)
		belt.moved = {}
	end

	for _, data in pairs(storage.observer_data) do
		for _, belt in ipairs(data.belts) do
			if belt.ent.valid == true then
				handle_belt(belt)
			end
		end
	end
end)
