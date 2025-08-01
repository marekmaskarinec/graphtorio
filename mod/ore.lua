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

-- Gets all ore entities reachable by a miner
function ore.get_ore_in_range(miner)
	local type = miner.mining_target.prototype.mineable_properties.products[1].name
	local surface = miner.surface

	local x = miner.position.x
	local y = miner.position.y
	local range = miner.prototype.mining_drill_radius

	local area = {{math.floor(x - range), math.floor(y - range)}, {math.ceil(x + range), math.ceil(y + range)}}

	local ores = surface.find_entities_filtered{area = area, name = {type}}
	
	return ores
end

-- Calculates the total ore across given entities
function ore.calculate_total(entities)
	local total = 0

	for _, entity in ipairs(entities) do
		total = total + entity.amount
	end

	return total
end

-- Gets productions stats for a given miner
function ore.get_miner_statistics(miner)
	local stats = {}

    -- Check if given entity is a miner
    if miner.type ~= "mining-drill" then return nil end

	stats.mining_speed = (1 + miner.speed_bonus) * miner.prototype.mining_speed
	stats.productivity = miner.productivity_bonus * stats.mining_speed

	stats.output_speed = stats.mining_speed + stats.productivity
	
	stats.output_resource = miner.mining_target.prototype.mineable_properties.products[1].name
	stats.expected_resources = ore.calculate_total(ore.get_ore_in_range(miner))

	return stats
end
-- TODO: Ore patch depletion predictor

return ore