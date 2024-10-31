--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: entities.lua
 * Description:  Add entity prototypes for vanilla vehicles.
 *   Entities added:
 *    - Vehicle Wagon (empty)
 *    - Loaded Vehicle Wagon (Car)
 *    - Loaded Vehicle Wagon (Tank)
 *    - Loaded Vehicle Wagon (Tarp)
--]]

local math2d = require("math2d")

local useWeights = settings.startup["vehicle-wagon-use-custom-weights"].value
local maxWeight = (useWeights and settings.startup["vehicle-wagon-maximum-weight"].value) or math.huge

local vehicle_wagon = util.table.deepcopy(data.raw["cargo-wagon"]["cargo-wagon"])
vehicle_wagon.name = "vehicle-wagon"
vehicle_wagon.placeable_by = {item="vehicle-wagon", count=1}  -- Make this explicit so all deepcopies have the right value
vehicle_wagon.icon = "__vehicle-wagon-graphics__/graphics/vehicle-wagon-icon.png"
vehicle_wagon.icon_size = 32
if settings.startup["vehicle-wagon-inventory-slots"].value == "none" then
  vehicle_wagon.inventory_size = 0
else
  vehicle_wagon.inventory_size = 1
end
table.insert(vehicle_wagon.flags, "no-automated-item-removal")
table.insert(vehicle_wagon.flags, "no-automated-item-insertion")
vehicle_wagon.minable = {mining_time = 1, result = "vehicle-wagon"}
vehicle_wagon.horizontal_doors = nil
vehicle_wagon.vertical_doors = nil
vehicle_wagon.pictures =
{
  rotated = {
    layers =
    {
      {
        flags = {"no-scale"},
        priority = "very-low",
        width = 256,
        height = 256,
        direction_count = 128,
        filenames =
        {
          "__vehicle-wagon-graphics__/graphics/cargo_fb_sheet.png",
          "__vehicle-wagon-graphics__/graphics/cargo_fb_sheet.png"
        },
        line_length = 8,
        lines_per_file = 8,
        shift={0.4, -1.20}
      }
    }
  },
  --[[sloped = {
    layers =
    {
      {
        flags = {"no-scale"},
        priority = "very-low",
        width = 256,
        height = 256,
        direction_count = 80,
        filenames =
        {
          "__vehicle-wagon-graphics__/graphics/cargo_fb_sloped_1.png",
          "__vehicle-wagon-graphics__/graphics/cargo_fb_sloped_2.png",
          "__vehicle-wagon-graphics__/graphics/cargo_fb_sloped_1.png",
          "__vehicle-wagon-graphics__/graphics/cargo_fb_sloped_2.png"
        },
        line_length = 4,
        lines_per_file = 5,
        shift={0.4, 0}
      }
    }
  },
  slope_angle_between_frames = 1.25,
  slope_back_equals_front = true--]]
}
data:extend{vehicle_wagon}


local loaded_car = util.table.deepcopy(vehicle_wagon)
loaded_car.name = "loaded-vehicle-wagon-car"
loaded_car.pictures =
{
  rotated = {
    layers =
    {
      {
        flags = {"no-scale"},
        priority = "very-low",
        width = 256,
        height = 256,
        direction_count = 128,
        filenames =
        {
          "__vehicle-wagon-graphics__/graphics/cargo_fb_sheet.png",
          "__vehicle-wagon-graphics__/graphics/cargo_fb_sheet.png"
        },
        line_length = 8,
        lines_per_file = 8,
        shift={0.4, -1.20}
      },
      {
        flags = {"no-scale"},
        priority = "low",
        width = 114,
        height = 76,
        direction_count = 128,
        shift = {0.28125, -0.55},
        scale = 0.95,
        filenames =
        {
          "__vehicle-wagon-graphics__/graphics/car/car-shadow-1.png",
          "__vehicle-wagon-graphics__/graphics/car/car-shadow-2.png",
          "__vehicle-wagon-graphics__/graphics/car/car-shadow-3.png"
        },
        line_length = 2,
        lines_per_file = 22,
      },
      {
        flags = {"no-scale"},
        priority = "low",
        width = 102,
        height = 86,
        direction_count = 128,
        shift = {0, -0.9875},
        scale = 0.95,
        filenames =
        {
          "__vehicle-wagon-graphics__/graphics/car/car-1.png",
          "__vehicle-wagon-graphics__/graphics/car/car-2.png",
          "__vehicle-wagon-graphics__/graphics/car/car-3.png",
        },
        line_length = 2,
        lines_per_file = 22,
      },
      {
        flags = {"no-scale"},
        width = 100,
        height = 75,
        direction_count = 128,
        apply_runtime_tint = true,
        shift = {0, -0.9875+(-0.171875+0.1875)},
        scale = 0.95,
        filenames =
        {
          "__vehicle-wagon-graphics__/graphics/car/car-mask-1.png",
          "__vehicle-wagon-graphics__/graphics/car/car-mask-2.png",
          "__vehicle-wagon-graphics__/graphics/car/car-mask-3.png",
        },
        line_length = 2,
        lines_per_file = 22,
      },
      {
        flags = {"no-scale"},
        width = 36,
        height = 29,
        direction_count = 128,
        shift = {0.03125, -1.690625},
        scale = 0.95,
        filenames =
        {
          "__vehicle-wagon-graphics__/graphics/car/turret.png",
        },
        line_length = 2,
        lines_per_file = 64,
      }
    }
  }
}

local loaded_tarp = util.table.deepcopy(vehicle_wagon)
loaded_tarp.name = "loaded-vehicle-wagon-tarp"
loaded_tarp.pictures =
{
  rotated = {
    layers =
    {
      {
        flags = {"no-scale"},
        priority = "very-low",
        width = 256,
        height = 256,
        direction_count = 128,
        filenames =
        {
          "__vehicle-wagon-graphics__/graphics/cargo_fb_sheet.png",
          "__vehicle-wagon-graphics__/graphics/cargo_fb_sheet.png"
        },
        line_length = 8,
        lines_per_file = 8,
        shift={0.4, -1.20}
      },
      {
        flags = {"no-scale"},
        width = 192,
        height = 192,
        direction_count = 128,
        shift = {0, -0.5},
        scale = 0.95,
        filenames =
        {
          "__vehicle-wagon-graphics__/graphics/tarp/tarp-shadow-1.png",
          "__vehicle-wagon-graphics__/graphics/tarp/tarp-shadow-2.png",
          "__vehicle-wagon-graphics__/graphics/tarp/tarp-shadow-3.png",
          "__vehicle-wagon-graphics__/graphics/tarp/tarp-shadow-4.png"
        },
        line_length = 8,
        lines_per_file = 5,
      },
      {
        flags = {"no-scale"},
        width = 192,
        height = 192,
        direction_count = 128,
        shift = {0, -0.5},
        scale = 0.95,
        filenames =
        {
          "__vehicle-wagon-graphics__/graphics/tarp/tarp-1.png",
          "__vehicle-wagon-graphics__/graphics/tarp/tarp-2.png",
          "__vehicle-wagon-graphics__/graphics/tarp/tarp-3.png",
          "__vehicle-wagon-graphics__/graphics/tarp/tarp-4.png"
        },
        line_length = 8,
        lines_per_file = 5,
      }
    }
  }
}


local loaded_tank = util.table.deepcopy(vehicle_wagon)
loaded_tank.name = "loaded-vehicle-wagon-tank"
loaded_tank.pictures = 
{
  rotated = {
    layers =
    {
      {
        flags = {"no-scale"},
        priority = "very-low",
        width = 256,
        height = 256,
        direction_count = 128,
        filenames =
        {
          "__vehicle-wagon-graphics__/graphics/cargo_fb_sheet.png",
          "__vehicle-wagon-graphics__/graphics/cargo_fb_sheet.png"
        },
        line_length = 8,
        lines_per_file = 8,
        shift={0.4, -1.20}
      },
      {
        flags = {"no-scale"},
        width = 154,
        height = 99,
        direction_count = 128,
        shift = {0.69375, -0.571875},
        scale = 0.95,
        filenames =
        {
          "__vehicle-wagon-graphics__/graphics/tank/base-shadow-1.png",
          "__vehicle-wagon-graphics__/graphics/tank/base-shadow-2.png",
          "__vehicle-wagon-graphics__/graphics/tank/base-shadow-3.png",
          "__vehicle-wagon-graphics__/graphics/tank/base-shadow-4.png"
        },
        line_length = 2,
        lines_per_file = 16,
      },
      {
        flags = {"no-scale"},
        width = 139,
        height = 110,
        direction_count = 128,
        shift = {-0.040625, -1.18125},
        scale = 0.95,
        filenames =
        {
          "__vehicle-wagon-graphics__/graphics/tank/base-1.png",
          "__vehicle-wagon-graphics__/graphics/tank/base-2.png",
          "__vehicle-wagon-graphics__/graphics/tank/base-3.png",
          "__vehicle-wagon-graphics__/graphics/tank/base-4.png"
        },
        line_length = 2,
        lines_per_file = 16,
      },
      {
        flags = {"no-scale"},
        width = 104,
        height = 83,
        direction_count = 128,
        shift = math2d.position.add({-0.040625, -1.18125}, util.by_pixel(0, -27.5+16)),
        apply_runtime_tint = true,
        scale = 0.95,
        filenames =
        {
          "__vehicle-wagon-graphics__/graphics/tank/tank-base-mask-1.png",
          "__vehicle-wagon-graphics__/graphics/tank/tank-base-mask-2.png",
          "__vehicle-wagon-graphics__/graphics/tank/tank-base-mask-3.png"
        },
        line_length = 2,
        lines_per_file = 22,
      },
      {
        flags = {"no-scale"},
        width = 92,
        height = 69,
        direction_count = 128,
        shift = {-0.05625, -1.97812},
        scale = 0.95,
        filenames =
        {
          "__vehicle-wagon-graphics__/graphics/tank/turret-1.png",
          "__vehicle-wagon-graphics__/graphics/tank/turret-2.png",
          "__vehicle-wagon-graphics__/graphics/tank/turret-3.png",
          "__vehicle-wagon-graphics__/graphics/tank/turret-4.png"
        },
        line_length = 2,
        lines_per_file = 16,
      },
      {
        flags = {"no-scale"},
        width = 36,
        height = 33,
        direction_count = 128,
        shift = math2d.position.add({-0.05625, -1.97812}, util.by_pixel(0, -41.5+40.5)),
        apply_runtime_tint = true,
        scale = 0.95,
        filenames =
        {
          "__vehicle-wagon-graphics__/graphics/tank/tank-turret-mask.png"
        },
        line_length = 16,
        lines_per_file = 8,
      }
    }
  }
}
-- Car, Tank, and Tarp need to be loaded regardless of weight limit
data:extend{loaded_car, makeDummyItem(loaded_car.name), 
            loaded_tank, makeDummyItem(loaded_tank.name), 
            loaded_tarp, makeDummyItem(loaded_tarp.name)}

