
local building = table.deepcopy(data.raw["lamp"]["small-lamp"])

building.name = "observer"

local item = table.deepcopy(data.raw["item"]["small-lamp"])

item.name = "observer"
item.place_result = "observer"
item.icons = {
	{
		icon = item.icon,
		icon_size = item.icon_size,
		tint = { r = 0.2, g = 1, b = 0.2, a = 1 }
	}
}
building.icons = item.icons

local recipe = {
	type = "recipe",
	name = "observer",
	enabled = true,
	energy_required = 1,
	ingredients = {
		{ type = "item", name = "iron-plate", amount = 5 }
	},
	results = {{ type = "item", name = "observer", amount = 1 }}
}

data:extend{building, item, recipe}
