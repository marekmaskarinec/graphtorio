-- Returns all entities directly connected by circuit wires
local function get_wired_entities(entity)
    local entities = {}

    for WireConnectorID, WireConnector in pairs(entity.get_wire_connectors()) do
        -- Check if entity is connected to a circuit network
        local network = entity.get_circuit_network(WireConnectorID)

        -- Check for all directly connected entities
        -- TODO: Filter out ghosts
        if network then
            for _, WireConnection in ipairs(WireConnector.connections) do
                table.insert(entities, WireConnection.target.owner)
            end
        end
    end

    return entities
end

-- Returns all entities connected on the same circuit network
local function get_networked_entities(entity)
    local entities = {}

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
                
                -- TODO: Get network ids of connected entity

                table.insert(entities_to_process, wired_entity)
                table.insert(entities, wired_entity)
            end
        end
    end

    return entities
end
