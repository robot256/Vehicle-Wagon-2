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
  local player = nil
  local replace_wagon = action.replace_wagon
  if replace_wagon == nil then
    replace_wagon = true
  end
  
  -- Make sure player exists
  if player_index then
    player = game.players[player_index]
  end
  
  -- Make sure wagon exists
  local loaded_unit_number = nil
  if not(loaded_wagon and loaded_wagon.valid) then
    if player then
      player.print({"vehicle-wagon2.wagon-invalid-error"})
    else
      game.print({"vehicle-wagon2.wagon-invalid-error"})
    end
    return
  end
  loaded_unit_number = loaded_wagon.unit_number
  
  -- Make sure the data for this wagon is still valid
  local wagon_data = global.wagon_data[loaded_unit_number]
  if not wagon_data then
    if player then
      player.print({"vehicle-wagon2.data-error", loaded_unit_number})
    else
      game.print({"vehicle-wagon2.data-error", loaded_unit_number})
    end
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
  
  -- Assign unloaded wagon to player force, else wagon force
  local force = loaded_wagon.force
  if player then
    force = player.force
  end
  
  -- Validate the orientation setting and convert to approximate direction for create_entity
  if not unload_orientation then
    -- Place vehicle with same direction as the loaded wagon sprite by default.
    unload_orientation = loaded_wagon.orientation
    if global.loadedWagonFlip[loaded_wagon.name] then
      unload_orientation = unload_orientation + 0.5
    end
  end
  unload_orientation = math.fmod(unload_orientation, 1)
  if unload_orientation < 0 then
    unload_orientation = unload_orientation + 1
  end
  local direction = math.floor(unload_orientation*8 + 0.5)
  direction = math.fmod(direction, 8)
  
  
  -- Create the vehicle
  local vehicle = surface.create_entity{
                      name = wagon_data.name,
                      position = unload_position,
                      force = force,
                      direction = direction,
                      raise_built = false
                    }
  
  -- If vehicle not created, give up
  if not vehicle then
    return
  end
  
  -- Set the orientation (this is where we can use the original floating point value
  vehicle.orientation = unload_orientation
  
  -- Set vehicle user to the player who unloaded, or the saved last user if unloaded automatically
  if not player_index and wagon_data.last_user then
    player_index = wagon_data.last_user
  end
  if player_index and game.players[player_index] then
    vehicle.last_user = game.players[player_index]
  end
  
  -- Restore custom Spidertron name (nil clears it, others ignore it)
  vehicle.entity_label = wagon_data.entity_label
  
  -- Restore vehicle parameters from global data
  vehicle.health = wagon_data.health
  if wagon_data.color then vehicle.color = wagon_data.color end
  
  -- Flags default to true on creation, and are only saved in wagon_data if they should be false
  -- But setting flags to nil is same as setting false, so only assign false if wagon_data entry is not nil
  if wagon_data.minable == false then vehicle.minable = false end
  if wagon_data.destructible == false then vehicle.destructible = false end
  if wagon_data.operable == false then vehicle.operable = false end
  if wagon_data.rotatable == false then vehicle.rotatable = false end
  if wagon_data.enable_logistics_while_moving == false then
    vehicle.enable_logistics_while_moving = false
  end

  -- Restore burner
  local r1 = saveRestoreLib.restoreBurner(vehicle.burner, wagon_data.burner)
  
  -- Restore equipment grid
  local r2 = saveRestoreLib.restoreGrid(vehicle.grid, wagon_data.grid)
  r1 = saveRestoreLib.mergeStackLists(r1, r2)
  
  -- Restore inventory contents and settings
  if vehicle.type == "car" then
    -- Restore inventory filters
    if wagon_data.filters then
      saveRestoreLib.restoreFilters(vehicle.get_inventory(defines.inventory.car_ammo), wagon_data.filters.ammo)
      saveRestoreLib.restoreFilters(vehicle.get_inventory(defines.inventory.car_trunk), wagon_data.filters.trunk)
    end
    
    -- Restore ammo inventory if this car has guns
    if vehicle.selected_gun_index then
      local ammoInventory = vehicle.get_inventory(defines.inventory.car_ammo)
      local r2 = saveRestoreLib.insertInventoryStacks(ammoInventory, wagon_data.items.ammo)
      r1 = saveRestoreLib.mergeStackLists(r1, r2)
    
      -- Restore the selected gun index
      if wagon_data.selected_gun_index then
        vehicle.selected_gun_index = wagon_data.selected_gun_index
      end
    end
    
    -- Restore the cargo inventory
    local trunkInventory = vehicle.get_inventory(defines.inventory.car_trunk)
    local r2 = saveRestoreLib.insertInventoryStacks(trunkInventory, wagon_data.items.trunk)
    r1 = saveRestoreLib.mergeStackLists(r1, r2)
    
    -- Try to insert remainders into trunk, spill whatever doesn't fit
    if r1 then
      local r2 = saveRestoreLib.insertInventoryStacks(trunkInventory, r1)
      saveRestoreLib.spillStacks(r2, surface, unload_position)
    end
  
  elseif vehicle.type == "spider-vehicle" then
    -- Restore inventory filters
    if wagon_data.filters then
      saveRestoreLib.restoreFilters(vehicle.get_inventory(defines.inventory.spider_ammo), wagon_data.filters.ammo)
      saveRestoreLib.restoreFilters(vehicle.get_inventory(defines.inventory.spider_trunk), wagon_data.filters.trunk)
    end
    
    -- Restore ammo inventory if this spider has guns
    if vehicle.selected_gun_index then
      local ammoInventory = vehicle.get_inventory(defines.inventory.spider_ammo)
      local r2 = saveRestoreLib.insertInventoryStacks(ammoInventory, wagon_data.items.ammo)
      r1 = saveRestoreLib.mergeStackLists(r1, r2)
      
      -- Restore the selected gun index
      if wagon_data.selected_gun_index then
        vehicle.selected_gun_index = wagon_data.selected_gun_index
      end
    elseif wagon_data.items.ammo then
      r1 = saveRestoreLib.mergeStackLists(r1, wagon_data.items.ammo)
    end
    
    -- Restore the cargo inventory
    local trunkInventory = vehicle.get_inventory(defines.inventory.spider_trunk)
    local r2 = saveRestoreLib.insertInventoryStacks(trunkInventory, wagon_data.items.trunk)
    r1 = saveRestoreLib.mergeStackLists(r1, r2)
    
    -- Restore the trash inventory
    local trashInventory = vehicle.get_inventory(defines.inventory.spider_trash)
    local r2 = saveRestoreLib.insertInventoryStacks(trashInventory, wagon_data.items.trash)
    r1 = saveRestoreLib.mergeStackLists(r1, r2)
    
    -- Try to insert remainders into trunk and trash, spill whatever doesn't fit
    if r1 then
      local r2 = saveRestoreLib.insertInventoryStacks(trunkInventory, r1)
      local r3 = saveRestoreLib.insertInventoryStacks(trashInventory, r2)
      saveRestoreLib.spillStacks(r3, surface, unload_position)
    end
    
    -- Restore logistic requests
    if wagon_data.logistic then
      for slot,d in pairs(wagon_data.logistic) do
        if d and d.name then
          vehicle.set_vehicle_logistic_slot(slot, d)
        end
      end
    end
    
  end
  
  
  -- Raise event for scripts
  -- Added autodrive_data and GCKI_data to arguments. No need to test if they are set: If nil, they will be ignored!
  script.raise_script_built{
      entity = vehicle,
      player_index = player_index, 
      vehicle_unloaded=true,  -- Custom parameter used by Vehicle Wagon
      autodrive_data = wagon_data.autodrive_data,  -- Custom parameter used by Autodrive
      GCKI_data = wagon_data.GCKI_data  -- Custom parameter used by GCKI
    }
  
  -- Play sound associated with creating the vehicle
  surface.play_sound({path = "utility/build_medium", position = unload_position, volume_modifier = 0.7})
  
  -- Finished creating vehicle, clear loaded wagon data
  global.wagon_data[loaded_wagon.unit_number] = nil
  
  -- Play sounds associated with creating the vehicle
  surface.play_sound({path = "latch-off", position = unload_position, volume_modifier = 0.7})
  
  if replace_wagon then
    -- Replace loaded wagon with unloaded wagon
    local wagon = replaceCarriage(loaded_wagon, global.loadedWagonMap[loaded_wagon.name], false, false)
    
    -- Check that unloaded wagon was created correctly
    if not(wagon and wagon.valid) then
      if player then
        player.print({"vehicle-wagon2.empty-wagon-error"})
      else
        game.print({"vehicle-wagon2.empty-wagon-error"})
      end
    end
  end
  
  return vehicle
end
