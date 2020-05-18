--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: data-updates.lua
 * Description:  Modify wagon data if Train Overhaul is installed
 --]]

if mods["TrainOverhaul"] then
  for name,entity in pairs(data.raw["cargo-wagon"]) do
    if string.find(name,"vehicle%-wagon") ~= nil then
      entity.max_speed = data.raw["locomotive"]["nuclear-locomotive"].max_speed
    end
  end
end
