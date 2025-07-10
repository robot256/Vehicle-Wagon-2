--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: unloadVehicleWagon.lua
 * Description:  Function to execute the given Unloading Action.
 *    1. Validate saved data.
 *    2. Find a valid unloading position near the position given.
 *    3. Attempt to create the Vehicle entity.
 *    4. If successful, restore all the saved inventory, grid, and settings to the new Vehicle.
 *       Spill any items that don't fit.  Return reference to the new Vehicle.
 *    5. If unsuccessful, return nil.
 *    1. Replace Loaded Vehicle Wagon with Vehicle Wagon.
 --]]


-------------------------
-- Unload Wagon (either manually or from mining)
function unloadVehicleWagon(action)
  -- Get data from this unloading request
  local player_index = action.player_index
  local unload_position = action.unload_position
  local unload_orientation = action.unload_orientation
  local loaded_wagon = action.wagon
  local player
  local replace_wagon = action.replace_wagon
  if replace_wagon == nil then  -- If parameter is omitted, then it must assume true
    replace_wagon = true
  end

  -- Make sure player exists
  if player_index and player_index > 0 then
    player = game.players[player_index]
  end

  -- Make sure wagon exists
  local loaded_unit_number
  if not (loaded_wagon and loaded_wagon.valid) then
    if player then
      player.create_local_flying_text{text={"vehicle-wagon2.wagon-invalid-error"}}
    else
      game.print({"vehicle-wagon2.wagon-invalid-error"})
    end
    return
  end
  loaded_unit_number = loaded_wagon.unit_number

  -- Make sure the data for this wagon is still valid
  local wagon_data = storage.wagon_data[loaded_unit_number]
  if not wagon_data then
    if player then
      player.create_local_flying_text{text={"vehicle-wagon2.data-error", loaded_unit_number}, position=loaded_wagon.position}
    else
      game.print({"vehicle-wagon2.data-error", loaded_unit_number})
    end
    return
  end
  
  -- Make sure the vehicle for this wagon still exists on the hidden surface
  local vehicle = wagon_data.vehicle
  if not vehicle or not vehicle.valid then
    if player then
      player.create_local_flying_text{text={"vehicle-wagon2.vehicle-missing-error", loaded_unit_number, wagon_data.name}, position=loaded_wagon.position}
    else
      game.print({"vehicle-wagon2.vehicle-missing-error", loaded_unit_number, wagon_data.name})
    end
    storage.wagon_data[loaded_unit_number] = nil
    return
  end

  -- Store wagon details for replacement
  local surface = loaded_wagon.surface
  local wagon_position = loaded_wagon.position

  -- Ask game to verify the requested unload position
  if unload_position then
    unload_position = surface.find_non_colliding_position(wagon_data.name, unload_position, 5, 0.5)
  end

  -- Ask game for a valid unloading position near the wagon
  if not unload_position then
    unload_position = surface.find_non_colliding_position(wagon_data.name, wagon_position, 5, 0.5)
  end

  -- If we still can't find a position, give up
  if not unload_position then
    return
  end

  -- Validate the orientation setting and convert to approximate direction for create_entity
  if not unload_orientation then
    -- Place vehicle with same direction as the loaded wagon sprite by default.
    unload_orientation = loaded_wagon.orientation
    if storage.loadedWagonFlip[loaded_wagon.name] then
      unload_orientation = unload_orientation + 0.5
    end
  end
  unload_orientation = math.fmod(unload_orientation, 1)
  if unload_orientation < 0 then
    unload_orientation = unload_orientation + 1
  end
  
  -- Teleport the vehicle back into place
  vehicle.orientation = unload_orientation

  -- Vehicle must be made active (if necessary) before it is teleported, or
  -- Autodrive will wrongly disable it on the GUI!
  -- (If wagon_data.active was not set, the vehicle was active!)
  vehicle.active = (wagon_data.active == nil)
  vehicle.operable = (wagon_data.operable == nil)

  if not vehicle.teleport(unload_position, surface, true, false) then
    -- Vehicle not teleported. leave data and wagon as it is

    -- Make vehicle inactive and inoperable again!
    vehicle.active = false
    vehicle.operable = false

    return
  end

  -- Teleport was successful
  
  -- Reenable logistics
  local logipoint = vehicle.get_logistic_point(defines.logistic_member_index.spidertron_requester)
  if logipoint then
    logipoint.enabled = wagon_data.logistics_enabled or true
  end
  
  -- Transfer player from wagon to vehicle, if any
  local wagon_driver = loaded_wagon.get_driver()
  local vehicle_passenger = (vehicle.type == "car" and vehicle.get_passenger()) or nil
  if wagon_driver then
    loaded_wagon.set_driver(nil)
    if not vehicle.get_driver() then
      vehicle.set_driver(wagon_driver)
    elseif vehicle.type == "car" and not vehicle_passenger then
      -- If driver slot is occuped by AAI Driver, put wagon driver in passenger slot
      vehicle.set_passenger(wagon_driver)
    end
  end

  -- Play sound associated with creating the vehicle
  surface.play_sound({path = "utility/build_medium", position = unload_position, volume_modifier = 0.7})

  -- Finished creating vehicle, clear loaded wagon data
  storage.wagon_data[loaded_wagon.unit_number] = nil
  
  -- Clear the item in the wagon
  local wagon_inv = loaded_wagon.get_inventory(defines.inventory.cargo_wagon)
  if wagon_inv then
    wagon_inv.clear()
  end

  -- Play sounds associated with creating the vehicle
  surface.play_sound({path = "latch-off", position = unload_position, volume_modifier = 0.7})

  if replace_wagon then
    -- Replace loaded wagon with unloaded wagon
    local wagon = replaceCarriage(loaded_wagon, "vehicle-wagon", false, false)
    
    -- Check that unloaded wagon was created correctly
    if wagon and wagon.valid then
      -- Restore correct minable property to empty wagon
      if not storage.unminable_enabled then
        wagon.minable = true
      end
    else
      if player then
        player.create_local_flying_text{text={"vehicle-wagon2.empty-wagon-error"}, position=wagon_position}
      else
        game.print({"vehicle-wagon2.empty-wagon-error"})
      end
    end
  end

  return vehicle
end
