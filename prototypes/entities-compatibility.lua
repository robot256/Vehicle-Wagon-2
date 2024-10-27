--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: entities-compatibility.lua
 * Description:  Add entity prototypes for compatibility with other mods.
 *   Entities added:
 *    - Loaded Vehicle Wagon (Truck)
 *    - Loaded Vehicle Wagon (Cargo Plane)
 *    - Loaded Vehicle Wagon (Gunship)
 *    - Loaded Vehicle Wagon (Jet)
 *    - Loaded Vehicle Wagon (Light Tank)
 *    - Loaded Vehicle Wagon (Heavy Tank)
 *    - Loaded Vehicle Wagon (Super Heavy Tank)
 *    - Loaded Vehicle Wagon (Advanced Tank)
--]]

local useWeights = settings.startup["vehicle-wagon-use-custom-weights"].value
local maxWeight = (useWeights and settings.startup["vehicle-wagon-maximum-weight"].value) or math.huge
local compatibilityEntities = settings.startup["vehicle-wagon-compatibility-entities"].value

local vehicle_wagon = data.raw["cargo-wagon"]["vehicle-wagon"]
local loaded_tank = data.raw["cargo-wagon"]["loaded-vehicle-wagon-tank"]
local loaded_vehicle_wagon_tarp = data.raw["cargo-wagon"]["loaded-vehicle-wagon-tarp"]

if mods["bigtruck"] or compatibilityEntities then
  if compatibilityEntities or (data.raw.car["dumper-truck"] and data.raw.car["dumper-truck"].weight <= maxWeight) then
    local loaded_truck = util.table.deepcopy(vehicle_wagon)
    loaded_truck.name = "loaded-vehicle-wagon-truck"
    loaded_truck.pictures =
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
              "__vehicle-wagon-graphics__/graphics/truck/truck-shadow-1.png",
              "__vehicle-wagon-graphics__/graphics/truck/truck-shadow-2.png",
              "__vehicle-wagon-graphics__/graphics/truck/truck-shadow-3.png",
              "__vehicle-wagon-graphics__/graphics/truck/truck-shadow-4.png"
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
              "__vehicle-wagon-graphics__/graphics/truck/truck-1.png",
              "__vehicle-wagon-graphics__/graphics/truck/truck-2.png",
              "__vehicle-wagon-graphics__/graphics/truck/truck-3.png",
              "__vehicle-wagon-graphics__/graphics/truck/truck-4.png"
            },
            line_length = 8,
            lines_per_file = 5,
          }
        }
      }
    }
    data:extend{loaded_truck, makeDummyItem(loaded_truck.name)}
  end

end


if mods["Aircraft"] or compatibilityEntities then
  if compatibilityEntities or (data.raw.car["cargo-plane"] and data.raw.car["cargo-plane"].weight <= maxWeight) then
    local loaded_cargo_plane = util.table.deepcopy(vehicle_wagon)
    loaded_cargo_plane.name = "loaded-vehicle-wagon-cargoplane"
    loaded_cargo_plane.pictures =
    {
      rotated = {
        layers =
        {
          {
            flags = {"no-scale"},
            width = 256,
            height = 256,
            direction_count = 128,
            filenames =
            {
              "__vehicle-wagon-graphics__/graphics/cargoplane/flyer3onr_sheet-0.png",
              "__vehicle-wagon-graphics__/graphics/cargoplane/flyer3onr_sheet-1.png"
            },
            line_length = 8,
            lines_per_file = 8,
            shift={0, -0.6}
          }
        }
      }
    }
    data:extend{loaded_cargo_plane, makeDummyItem(loaded_cargo_plane.name)}
  end
  
  if compatibilityEntities or (data.raw.car["jet"] and data.raw.car["jet"].weight <= maxWeight) then
    local loaded_jet = util.table.deepcopy(vehicle_wagon)
    loaded_jet.name = "loaded-vehicle-wagon-jet"
    loaded_jet.pictures =
    {
      rotated = {
        layers =
        {
          {
            flags = {"no-scale"},
            width = 256,
            height = 256,
            direction_count = 128,
            filenames =
            {
              "__vehicle-wagon-graphics__/graphics/jet/flyer2onr_sheet-0.png",
              "__vehicle-wagon-graphics__/graphics/jet/flyer2onr_sheet-1.png"
            },
            line_length = 8,
            lines_per_file = 8,
            shift={0, -0.6}
          }
        }
      }
    }
    data:extend{loaded_jet, makeDummyItem(loaded_jet.name)}
  end

	if compatibilityEntities or (data.raw.car["gunship"] and data.raw.car["gunship"].weight <= maxWeight) then
    local loaded_gunship = util.table.deepcopy(vehicle_wagon)
    loaded_gunship.name = "loaded-vehicle-wagon-gunship"
    loaded_gunship.pictures =
    {
      rotated = {
        layers =
        {
          {
            flags = {"no-scale"},
            width = 256,
            height = 256,
            direction_count = 128,
            filenames =
            {
              "__vehicle-wagon-graphics__/graphics/gunship/flyer1onr_sheet-0b.png",
              "__vehicle-wagon-graphics__/graphics/gunship/flyer1onr_sheet-1b.png"
            },
            line_length = 8,
            lines_per_file = 8,
            shift={0, -0.6}
          }
        }
      }
    }
    data:extend{loaded_gunship, makeDummyItem(loaded_gunship.name)}
  end


end


if mods["SchallTankPlatoon"] or compatibilityEntities then
  -- Add more Tank versions with different weights
  -- Light tanks is smaller and lighter
  if compatibilityEntities or (data.raw.car["Schall-tank-L"] and data.raw.car["Schall-tank-L"].weight <= maxWeight) then
    local loaded_tank_L = util.table.deepcopy(loaded_tank)
    loaded_tank_L.name = "loaded-vehicle-wagon-tank-L"
    for i,layer in pairs(loaded_tank_L.pictures.rotated.layers) do
      if i > 1 then
        layer.scale = 0.95*0.8
      end
    end
    data:extend{loaded_tank_L, makeDummyItem(loaded_tank_L.name)}
  end

  
  -- Heavy tank is bigger and heavier
  if compatibilityEntities or (data.raw.car["Schall-tank-H"] and data.raw.car["Schall-tank-H"].weight <= maxWeight) then
    local loaded_tank_H = util.table.deepcopy(loaded_tank)
    loaded_tank_H.name = "loaded-vehicle-wagon-tank-H"
    for i,layer in pairs(loaded_tank_H.pictures.rotated.layers) do
      if i > 1 then
        layer.scale = 0.95*1.5
      end
    end
    data:extend{loaded_tank_H, makeDummyItem(loaded_tank_H.name)}
  end

  
  -- Super Heavy tank is just comically big
  if compatibilityEntities or (data.raw.car["Schall-tank-SH"] and data.raw.car["Schall-tank-SH"].weight <= maxWeight) then
    local loaded_tank_SH = util.table.deepcopy(loaded_tank)
    loaded_tank_SH.name = "loaded-vehicle-wagon-tank-SH"
    for i,layer in pairs(loaded_tank_SH.pictures.rotated.layers) do
      if i > 1 then
        layer.scale = 0.95*2
      end
    end
    data:extend{loaded_tank_SH, makeDummyItem(loaded_tank_SH.name)}
  end

end


if mods["Krastorio2"] then
  require("__Krastorio2__/lib/public/data-stages/paths")

  -- Advanced Tank is also comically large
  if data.raw.car["kr-advanced-tank"] and data.raw.car["kr-advanced-tank"].weight <= maxWeight then
    local loaded_advanced_tank = util.table.deepcopy(vehicle_wagon)
    loaded_advanced_tank.name = "loaded-vehicle-wagon-kr-advanced-tank"
    loaded_advanced_tank.pictures = 
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
            width = 208,
            height = 208,
            direction_count = 128,
            shift = {0, -0.5},
            scale = 0.95,
            filenames = 
            {
              kr_entities_path .. "advanced-tank/advanced-tank-base.png"
            },
            line_length = 16,
            lines_per_file = 8
          },--[[
          {
            width = 250,
            height = 250,
            direction_count = 128,
            shift = {0, -0.5},
            scale = 0.95,
            filenames = 
            {
              kr_entities_path .. "advanced-tank/advanced-tank-turret.png"
            },
            line_length = 16,
            lines_per_file = 8
          },
          {
            width = 208,
            height = 208,
            direction_count = 128,
            shift = {0, -0.5},
            line_length = 16,
            scale = 0.95,
            stripes =
            {
              {
                filename = kr_entities_path .. "advanced-tank/advanced-tank-base.png",
                width_in_frames = 16,
                height_in_frames = 8
              }
            },
          },
          {
            width = 258,
            height = 258,
            frame_count = 1,
            draw_as_shadow = true,
            direction_count = 64,
            animation_speed = 6,
            max_advance = 0.2,
            line_length = 16,
            shift = {0.75, 0.25},
            scale = 0.95,
            stripes = 
            {
              {
                filename = kr_entities_path .. "advanced-tank/advanced-tank-turret-shadow.png",
                width_in_frames = 8,
                height_in_frames = 8
              }
            },
          },
          {
            width = 250,
            height = 250,
            frame_count = 1,
            direction_count = 64,
            shift = {0, 0.25},
            scale = 0.95,
            animation_speed = 6,
            max_advance = 0.2,
            line_length = 16,
            stripes =
            {
              {
                filename = kr_entities_path .. "advanced-tank/advanced-tank-turret.png",
                width_in_frames = 8,
                height_in_frames = 8
              }
            },
          }--]]
        }
      }
    }
  
    data:extend{loaded_advanced_tank, makeDummyItem(loaded_advanced_tank.name)}
  end
  
elseif compatibilityEntities then
  local loaded_advanced_tank = util.table.deepcopy(loaded_vehicle_wagon_tarp)
  loaded_advanced_tank.name = "loaded-vehicle-wagon-kr-advanced-tank"
  data:extend{loaded_advanced_tank, makeDummyItem(loaded_advanced_tank.name)}
end

