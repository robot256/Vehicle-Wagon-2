--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: technologies.lua
 * Description:  Add technology prototypes.
 *   Technologies added:
 *    - Vehicle Wagons
--]]


data:extend({
  {
    type = "technology",
    name = "vehicle-wagons",
    icon = "__VehicleWagon2__/graphics/tech-icon.png",
    icon_size = 128,
    effects =
    {
      {
        type = "unlock-recipe",
        recipe = "vehicle-wagon"
      },
    },
    prerequisites = {"automated-rail-transportation"},
    unit =
    {
      count = 100,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
      },
      time = 30
    },
    order = "c-w-a",
  },
})
