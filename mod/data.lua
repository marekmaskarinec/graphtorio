
local tint = { r = 1, g = 0.6, b = 0.2, a = 1 }

local building = table.deepcopy(data.raw["lamp"]["small-lamp"])

building.name = "observer"
building.minable.result = "observer"
building.picture_off.layers[1].tint = tint
building.picture_on.tint = tint

local item = table.deepcopy(data.raw["item"]["small-lamp"])

item.name = "observer"
item.place_result = "observer"
item.icons = {
	{
		icon = item.icon,
		icon_size = item.icon_size,
		tint = tint
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
