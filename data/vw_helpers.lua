--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: helpers.lua
 * Description:  Helper functions to use during the data stage.
 --]]


function makeDummyItem(name)
  return {
    type = "item",
    name = name,
    icon = "__vehicle-wagon-graphics__/graphics/tech-icon.png",
    icon_size = 128,
    hidden = true,
    subgroup = "transport",
    order = "a[train-system]-z[vehicle-wagon]",
    place_result = name,
    stack_size = 1
  }
end
