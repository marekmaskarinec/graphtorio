local utils = {}

-- Returns only entities of the given type
function utils.filter_entities_by_type(entities, type)
	local filtered = {}

	for _, entity in pairs(entities) do
		if entity.type == type then
			table.insert(filtered, entity)
		end
	end

	return filtered
end

-- Returns only entities of the prototype name
function utils.filter_entities_by_name(entities, name)
	local filtered = {}

	for _, entity in pairs(entities) do
		if entity.name == name then
			table.insert(filtered, entity)
		end
	end

	return filtered
end

return utils