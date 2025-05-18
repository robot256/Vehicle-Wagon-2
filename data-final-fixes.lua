--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: data-final-fixes.lua
 * Description:  Modify wagon data if Train Overhaul is installed
 --]]


-- Update speeds to match fastest cargo wagon in the game
local max_speed = data.raw["cargo-wagon"]["cargo-wagon"].max_speed
for name,entity in pairs(data.raw["cargo-wagon"]) do
  max_speed = math.max(max_speed, entity.max_speed)
end
for name,entity in pairs(data.raw["cargo-wagon"]) do
  if string.find(name,"vehicle%-wagon") ~= nil then
    entity.max_speed = max_speed
  end
end

-- Update weights and friction
require("data.update_stats")

-- Remove empty wagon slot if necessary
if settings.startup["vehicle-wagon-inventory-slots"].value ~= "full-and-empty" then
  data.raw["cargo-wagon"]["vehicle-wagon"].inventory_size = 0
end
