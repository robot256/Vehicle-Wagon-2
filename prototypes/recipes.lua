--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: recipes.lua
 * Description:  Add recipe prototypes.
 *   Recipes added:
 *    - Vehicle Wagon (empty)
--]]


data:extend{
	{
		type = "recipe",
		name = "vehicle-wagon",
		enabled = false,
		ingredients =
		{
			{type="item", name="iron-gear-wheel", amount=10},
			{type="item", name="iron-stick", amount=20},
			{type="item", name="steel-plate", amount=30}
		},
		results = {{type="item", name="vehicle-wagon", amount=1}}
	},
}
