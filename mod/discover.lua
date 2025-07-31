
local discover = {}

local function find_entities_filtered(filter)
  return game.surfaces["nauvis"].find_entities_filtered(filter)
end

local function is_belt(ent)
  return ent.type == 'transport-belt' or ent.type == 'splitter' or ent.type == 'underground-belt'
end

local function is_inserter(ent)
  return ent.type == 'inserter'
end

local function is_relevant(ent)
  return ent.prototype.is_building
end

local function get_bb(ents)
  local min = {  }
  local max = {  }
  for _,b in ipairs(ents) do
    local bb = b.selection_box
    if min.x == nil or bb.left_top.x < min.x then min.x = bb.left_top.x end
    if min.y == nil or bb.left_top.y < min.y then min.y = bb.left_top.y end
    if max.x == nil or bb.right_bottom.x > max.x then max.x = bb.right_bottom.x end
    if max.y == nil or bb.right_bottom.y > max.y then max.y = bb.right_bottom.y end
  end

  min.x = min.x - 2
  min.y = min.y - 2
  max.x = max.x + 2
  max.y = max.y + 2

  return { min, max }
end

local function find_belts(self, belt)
	local function fetch_tl(ent, index)
		local tl = belt.get_transport_line(index).output_lines
		if self.input then tl = belt.get_transport_line(index).input_lines end

		for i,l in ipairs(tl) do
			tl[i] = l.owner
		end
		return tl
	end

	if belt.type == 'underground-belt' then
		belt = belt.neighbours
	end

	local bn = self.input and belt.belt_neighbours.inputs or belt.belt_neighbours.outputs
	if #bn > 0 then return bn end

	if belt.type == 'transport-belt' or belt.type == 'underground-belt' then
		return fetch_tl(belt, 1)
	end
	if belt.type == 'splitter' then
		local out = fetch_tl(belt, 1)
		for _,n in ipairs(fetch_tl(belt, 3)) do
			out[#out+1] = n
		end

		return out
	end

	return {}
end

local function find_dropents(self, ents)
  if ents == nil or #ents == 0 then return {} end

  local bb = get_bb(ents)
  local dropents = find_entities_filtered{area = get_bb(ents), type = "inserter"}
  if self.input then
    for _,e in ipairs(find_entities_filtered{area = bb, type = "mining-drill"}) do
      dropents[#dropents+1] = e
    end
  end

  -- filter inserters
  local found = {}
  for _,de in ipairs(dropents) do
    local pos = de.drop_position
    if self.input == false then pos = de.pickup_position end

    local found_ents = find_entities_filtered{ position = pos }

    found[#found+1] = false
    for _,e in ipairs(found_ents) do
      if self.lookup[e.unit_number] ~= nil then
        found[#found] = true
        break
      end
    end
  end

  local out = {}
  for i,ins in ipairs(dropents) do
    if found[i] then out[#out+1] = ins end
  end

  return out
end

local function find_inserter_neighbor(self, ent)
  local pos = ent.drop_position
  if self.input then pos = ent.pickup_position end

  local found_ents = find_entities_filtered{ position = pos }
  for _,e in ipairs(found_ents) do
    if is_relevant(e) then return e end
  end

  return nil
end

local function add_to_lookup(self, ents)
  for _,e in ipairs(ents) do
    self.lookup[e.unit_number] = e
  end
end

-- FIXME: This doesn't work if start isn't a belt. No idea why
function discover.discover(start, input)
  local self = {}
  self.ents = {}
  self.lookup = {}
  self.input = input

  local q = {start}

  local function add_to_q(ents)
    for _,e in ipairs(ents) do
      if self.lookup[e.unit_number] == nil then
        q[#q+1] = e
      end
    end
    add_to_lookup(self, ents)
  end

  while #q > 0 do
    local e = q[#q]
    table.remove(q, #q)

    local ents = {}
    if is_belt(e) then
      ents = find_belts(self, e)
    elseif is_inserter(e) then
      local nb = find_inserter_neighbor(self, e)
      if nb then ents = {nb} end
    end

    add_to_q(ents)

    local ins = find_dropents(self, ents)
    add_to_q(ins)

    self.ents[#self.ents+1] = e
  end

  return self.ents
end

return discover
