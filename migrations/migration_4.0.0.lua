--[[ Copyright (c) 2024 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: 03-40_teleport.lua
 * Description: LUA Migration from 3.x to 4.x for Factorio 2.0
--]]

-- Load global prototype data
require("__VehicleWagon2__.script.makeGlobalMaps")
require("__VehicleWagon2__.script.migrateLoadedWagon")

makeGlobalMaps()

-- Tutorial console messages no longer exist
storage.tutorials = nil

if storage.wagon_data then

  local new_wagon_data = {}
  -- Need to create all the stored vehicles on the hidden surface
  for loaded_unit_number,wagon_data in pairs(storage.wagon_data) do
    log(serpent.block(wagon_data))
    if not wagon_data.vehicle and wagon_data.items then
      local loaded_wagon = wagon_data.wagon
      -- Create the hidden surface if necessary and create the vehicle, and update the stored data if it worked
      local new_data = migrateLoadedWagon(loaded_unit_number)
      if new_data then
        new_wagon_data[loaded_unit_number] = new_data
      elseif loaded_wagon and loaded_wagon.valid then
        -- Failed to migrate, if wagon exists make it an empty wagon
        -- Replace loaded wagon with unloaded wagon
        local wagon = replaceCarriage(loaded_wagon, "vehicle-wagon", false, false)

        -- Check that unloaded wagon was created correctly
        if wagon and wagon.valid then
          -- Restore correct minable property to empty wagon
          if not storage.unminable_enabled then
            wagon.minable = true
          end
        else
          log({"vehicle-wagon2.migrate-empty-wagon-error"})
        end
      end
    else
      -- This has already been migrated
      new_wagon_data[loaded_unit_number] = wagon_data
    end
  end
  
  storage.wagon_data = new_wagon_data
  
end

-- For the switch to on_object_destroyed()
-- Need to go through and register all the existing object that normally result on OnEntityDied action.

-- Register all loaded wagons, whether or not they are currently unloading
if storage.wagon_data then
  for loaded_unit_number,wagon_data in pairs(storage.wagon_data) do
    script.register_on_object_destroyed(wagon_data.wagon)
    log("Registered "..wagon_data.wagon.name.." "..tostring(loaded_unit_number).." for destroyed event.")
  end
end

-- Register vehicles and wagons currently doing loading
if storage.action_queue then
  for empty_unit_number,action_data in pairs(storage.action_queue) do
    if action_data.status == "load" then
      script.register_on_object_destroyed(action_data.wagon)
      log("Registered "..action_data.wagon.." "..tostring(empty_unit_number).." for destroyed event.")
      script.register_on_object_destroyed(action_data.vehicle)
      log("Registered "..action_data.vehicle.." "..tostring(action_data.vehicle.unit_number).." for destroyed event.")
    end
  end
end

-- Register vehicles currently selected by a player
if storage.player_selection then
  for player_index, selection_data in pairs(storage.player_selection) do
    script.register_on_object_destroyed(selection_data.vehicle)
    log("Registered "..selection_data.vehicle.." "..tostring(selection_data.vehicle.unit_number).." for destroyed event.")
  end
end
