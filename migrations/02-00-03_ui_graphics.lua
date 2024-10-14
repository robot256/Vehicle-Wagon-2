--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: 02-00-05_us_graphics.lua
 * Description: LUA Migration from 2.x.0,1,2 to 2.x.3
--]]

-- Load global prototype data
require("__VehicleWagon2__.script.makeGlobalMaps")
makeGlobalMaps()

-- Remove all player arrows, now we use drawn circles
for _,player in pairs(game.players) do
  player.clear_gui_arrow()
end

if storage.wagon_data then

  -- Map all loaded wagons by unit_number
  -- If there is no global data, it will be reset when user tries to unload it
  -- If there is data but no wagon, it will be fixed later
  for _,surface in pairs(game.surfaces) do
    local wagons = surface.find_entities_filtered{name = storage.loadedWagonList}
    for _,wagon in pairs(wagons) do
      local unit_number = wagon.unit_number
      if storage.wagon_data[unit_number] then
        storage.wagon_data[unit_number].wagon = wagon
      end
    end
  end


  for id,data in pairs(storage.wagon_data) do
    
    -- Migrate last_user to player_index
    if data.last_user and type(data.last_user) ~= "number" then
      if data.last_user.valid and data.last_user.index then
        data.last_user = data.last_user.index
      end
    end

  end
end
