local ore = {}

-- Gets all entities in a patch the given entity is in
function ore.get_ore_patch(entity)
	local function get_neighbors(position, surface, type)
		local directions = {{0, 1}, {0, -1}, {1, 0}, {-1, 0}}
		local neighbors = {}

		for _, dir in ipairs(directions) do
			local pos = {position.x + dir[1], position.y + dir[2]}
			local neighbor = surface.find_entity(type, pos)

			if neighbor ~= nil then table.insert(neighbors, neighbor) end
		end

		return neighbors
	end

	local entities = {}
	local entities_to_process = {entity}
	local added_entities = {[entity.gps_tag] = true}

	while #entities_to_process > 0 do
		-- Get neighboring ore entities
		local entity_to_process = table.remove(entities_to_process)
		local neighbors = get_neighbors(
			entity_to_process.position,
			entity_to_process.surface,
			entity_to_process.prototype.mineable_properties.products[1].name
		)

		table.insert(entities, entity_to_process)

		for _, neighbor in ipairs(neighbors) do
			-- Check if entity was not processed
			if added_entities[neighbor.gps_tag] ~= true then
				added_entities[neighbor.gps_tag] = true

				table.insert(entities_to_process, neighbor)
			end
		end
	end

	return entities
end

-- TODO: Ore miner productivity stats
-- TODO: Ore patch depletion predictor

return ore