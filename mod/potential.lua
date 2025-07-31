local potential = {}

function potential.calculate(ents)
	local items = {}

	for _, e in ipairs(ents) do
		if e.type == "assembling-machine" or e.type == "furnace" then
			local rec = e.get_recipe()
			if rec == nil then
				if e.previous_recipe.name ~= nil then
					-- WTF?????????????
					rec = game.players[1].force.recipes[e.previous_recipe.name.name]
				else
					rec = game.players[1].force.recipes[e.previous_recipe]
				end
			end
			local duration = rec.energy / e.crafting_speed

			for _, ingr in ipairs(rec.ingredients) do
				if items[ingr.name] == nil then
					items[ingr.name] = 0
				end
				items[ingr.name] = items[ingr.name] - ingr.amount / duration
			end

			for _, prod in ipairs(rec.products) do
				if prod.type == "item" then
					if items[prod.name] == nil then
						items[prod.name] = 0
					end

					if prod.amount == nil then
						items[prod.name] = items[prod.name] + prod.amount_max / duration
					else
						items[prod.name] = items[prod.name] + prod.amount / duration
					end
				end
			end
		end -- TODO: handle mining drills here
	end

	return items
end

return potential
