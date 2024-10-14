--[[ Copyright (c) 2024 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: loadVehicleWagon.lua
 * Description:  Function to execute the given Loading Action.
 *    1. Replace empty Vehicle Wagon with the requested Loaded Vehicle Wagon.
 *    2. Teleport the vehicle to the hidden surface and store settings in the storage.wagon_data table.
 --]]


-------------------------
-- Load Wagon
function loadVehicleWagon(action)
  local player_index = action.player_index
  -- Make sure player exists
  local player
  if player_index then
    player = game.players[player_index]
  end

  local wagon = action.wagon
  local vehicle = action.vehicle
  local surface = wagon.surface

  -- Save parameters of empty wagon
  local position = wagon.position

  -- Find direction for wagon (either as-is or rotate 180)
  local flip = (math.abs(vehicle.orientation - wagon.orientation) > 0.25)
  if storage.loadedWagonFlip[action.name] then
    flip = not flip
  end

  -- Replace the unloaded wagon with loaded one
  local loaded_wagon = replaceCarriage(wagon, action.name, false, false, flip)
  
  -- Check that loaded wagon was created correctly
  if not loaded_wagon or not loaded_wagon.valid then
    -- Unable to create the loaded wagon, don't teleport vehicle
    -- replaceCarriage will drop the wagon on the ground for player to pick up
    player.create_local_flying_text{text={"vehicle-wagon2.loaded-wagon-error"}}
    return
  end

  -- Play sound associated with creating loaded wagon
  surface.play_sound({path = "utility/build_medium", position = position, volume_modifier = 0.7})

  -- Store data on vehicle in global table
  local unit_number = loaded_wagon.unit_number
  loaded_wagon.color = vehicle.color
  
  -- Prevent player from opening shadow inventory
  loaded_wagon.operable = false
  
  local saveData = {}

  -- Save reference to loaded wagon entity
  saveData.wagon = loaded_wagon

  -- Store vehicle parameters
  saveData.vehicle = vehicle
  saveData.name = vehicle.name
  
  if not vehicle.active then
    saveData.active = false
  end
  vehicle.active = false  -- Disable vehicle before transport
  
  local logipoint = vehicle.get_logistic_point(defines.logistic_member_index.spidertron_requester)
  if logipoint then
    saveData.logistics_enabled = logipoint.enabled
    logipoint.enabled = false
  end
  
  -- Register new loaded wagon for destruction event
  script.register_on_object_destroyed(loaded_wagon)
  

--  -- Store data for other mods
--  -- Pi-C Mods only work with type "car", not "spider-vehicle"
--  -- (Both Autodrive and GCKI support "spider-vehicle" now!)
--  --if vehicle.type == "car" and remote.interfaces["autodrive"] and remote.interfaces["autodrive"].get_vehicle_data then
--  if remote.interfaces["autodrive"] and remote.interfaces["autodrive"].get_vehicle_data then
--    -- This will return a table with data stored by Autodrive. As of version 1.1.3, this includes { owner = player.index, request_from_buffers = bool, custom_name = "string", named_by = player.index }.
--    saveData.autodrive_data = remote.call("autodrive", "get_vehicle_data", vehicle.unit_number, script.mod_name)
--    remote.call("autodrive", "vehicle_removed", vehicle)
--  end
--  if remote.interfaces["GCKI"] and remote.interfaces["GCKI"].get_vehicle_data then
--    -- This will return a table with data stored by GCKI. As of GCKI 1.1.2, this includes the following:
--    -- { owner = player.index, locker = player.index, custom_name = "string", named_by = player.index }
--    saveData.GCKI_data = remote.call("GCKI", "get_vehicle_data", vehicle.unit_number)
--    remote.call("GCKI", "vehicle_removed", vehicle, script.mod_name)
--
--    if saveData.GCKI_data and settings.global["vehicle-wagon-use-GCKI-permissions"].value then
--      if saveData.GCKI_data.owner or saveData.GCKI_data.locker then
--        -- There is an owner or a locker of the vehicle on this wagon.  Make it un-minable.
--        -- GCKI will call an interface function to release it if the owner unclaims it.
--        loaded_wagon.minable = false
--      end
--    end
--  end

  
--  -- [AAI Programmable Vehicles compatibility]
--  -- Destroy AI driver if present
--  local driver = vehicle.get_driver()
--  if driver and string.find(driver.name, "%-_%-driver") then
--    driver.destroy()
--  end

  -- Teleport vehicle to hidden surface
  -- Find a valid unload position on the hidden surface
  local destsurface = getHiddenSurface()
  local destposition = getTeleportCoordinate()
  if vehicle.teleport(destposition, destsurface, true, false) then
    -- Put the shadow item in the loaded wagon inventory
    loaded_wagon.insert({name=vehicle.name, count=1, quality=vehicle.quality})

    -- Save the wagon contents upon successful teleport
    storage.wagon_data[unit_number] = saveData
  end

end
