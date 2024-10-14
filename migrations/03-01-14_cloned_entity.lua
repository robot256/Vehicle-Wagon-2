--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: 03-01-14_cloned_entity.lua
 * Description: LUA Migration from 3.1.13 to 3.1.14
--]]

-- Load global prototype data
require("__VehicleWagon2__.script.makeGlobalMaps")
makeGlobalMaps()

if storage.wagon_data then

  -- Version 3.1.14 did not update storage.wagon_data[unit_number].wagon = <LuaEntity>
  --   when cloning entities (during spaceship launching)
  
  -- Store the entity reference for the correct entity based on unit_number
  for unit_number,data in pairs(storage.wagon_data) do
    data.wagon = game.get_entity_by_unit_number(unit_number)
  end
  
end
