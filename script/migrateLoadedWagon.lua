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
require("__VehicleWagon2__.script.renderVisuals")

-------------------------
-- Migrate Loaded Wagon
function migrateLoadedWagon(loaded_unit_number)
  -- Get data from this unloading request
  -- Make sure the data for this wagon is still valid
  local wagon_data = storage.wagon_data[loaded_unit_number]
  if not wagon_data then
    log({"vehicle-wagon2.migrate-data-error", loaded_unit_number})
    return
  end

  -- Make sure wagon exists
  local loaded_wagon = wagon_data.wagon
  if not(loaded_wagon and loaded_wagon.valid) then
    log({"vehicle-wagon2.migrate-wagon-error", loaded_unit_number, wagon_data.name})
    return
  end

  -- Find a valid unload position on the hidden surface
  local surface = getHiddenSurface()
  local unload_position = getTeleportCoordinate() --surface.find_non_colliding_position(wagon_data.name, {0,0}, 0, 1)

  -- If we still can't find a position, give up
  if not unload_position then
    log({"vehicle-wagon2.migrate-vehicle-error", loaded_unit_number, wagon_data.name})
    storage.wagon_data[loaded_unit_number] = nil
    return
  end

  -- Assign unloaded wagon to player force, else wagon force
  local force = loaded_wagon.force

  -- Create the vehicle
  local vehicle = surface.create_entity{
                      name = wagon_data.name,
                      position = unload_position,
                      force = force,
                      direction = defines.direction.north,
                      raise_built = false
                    }

  -- If vehicle not created, give up and erase data
  if not vehicle then
    log({"vehicle-wagon2.migrate-vehicle-error", loaded_unit_number, wagon_data.name})
    return
  end

  -- Add the vehicle item to the wagon
  local wagon_inv = loaded_wagon.get_inventory(defines.inventory.cargo_wagon)
  if wagon_inv then
    wagon_inv.clear()
    if wagon_inv.insert({name=getVehicleItem(wagon_data.name), count=1}) == 1 then
      -- Inserted vehicle item, delete the old icon
      if wagon_data.icon then
        clearIcon(wagon_data)
      end
    end
  end

  -- Set vehicle user to the player who unloaded, or the saved last user if unloaded automatically
  if wagon_data.last_user and game.players[wagon_data.last_user] then
    vehicle.last_user = game.players[wagon_data.last_user]
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
  --if wagon_data.operable == false then vehicle.operable = false end
  if wagon_data.rotatable == false then vehicle.rotatable = false end
  if wagon_data.enable_logistics_while_moving == false then
    vehicle.enable_logistics_while_moving = false
  end

  -- Update stored data to reflect GCKI's "locked" status
  if (wagon_data.GCKI_data and wagon_data.GCKI_data.locker) or
      (wagon_data.autodrive_data and wagon_data.autodrive_data.GCKI_locker) then
    wagon_data.active = false
  end

  -- Restore burner
  local r1 = saveRestoreLib.restoreBurner(vehicle.burner, wagon_data.burner)

  -- Restore equipment grid
  r1 = saveRestoreLib.mergeStackLists(r1, saveRestoreLib.restoreGrid(vehicle.grid, wagon_data.grid))

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
      r1 = saveRestoreLib.mergeStackLists(r1, saveRestoreLib.insertInventoryStacks(ammoInventory, wagon_data.items.ammo))

      -- Restore the selected gun index
      if wagon_data.selected_gun_index then
        vehicle.selected_gun_index = wagon_data.selected_gun_index
      end
    end

    -- Restore the cargo inventory
    local trunkInventory = vehicle.get_inventory(defines.inventory.car_trunk)
    r1 = saveRestoreLib.mergeStackLists(r1, saveRestoreLib.insertInventoryStacks(trunkInventory, wagon_data.items.trunk))

    -- Try to insert remainders into trunk, spill whatever doesn't fit
    if r1 then
      saveRestoreLib.spillStacks(saveRestoreLib.insertInventoryStacks(trunkInventory, r1), surface, unload_position)
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
      r1 = saveRestoreLib.mergeStackLists(r1, saveRestoreLib.insertInventoryStacks(ammoInventory, wagon_data.items.ammo))

      -- Restore the selected gun index
      if wagon_data.selected_gun_index then
        vehicle.selected_gun_index = wagon_data.selected_gun_index
      end
    elseif wagon_data.items.ammo then
      r1 = saveRestoreLib.mergeStackLists(r1, wagon_data.items.ammo)
    end

    -- Restore the cargo inventory
    local trunkInventory = vehicle.get_inventory(defines.inventory.spider_trunk)
    r1 = saveRestoreLib.mergeStackLists(r1, saveRestoreLib.insertInventoryStacks(trunkInventory, wagon_data.items.trunk))

    -- Restore the trash inventory
    local trashInventory = vehicle.get_inventory(defines.inventory.spider_trash)
    r1 = saveRestoreLib.mergeStackLists(r1, saveRestoreLib.insertInventoryStacks(trashInventory, wagon_data.items.trash))

    -- Try to insert remainders into trunk and trash, spill whatever doesn't fit
    if r1 then
      local r3 = saveRestoreLib.insertInventoryStacks(trashInventory, saveRestoreLib.insertInventoryStacks(trunkInventory, r1))
      -- Spill items where the wagon is, not on the hidden surface
      if r3 then
        log({"vehicle-wagon2.migrate-spilled-stacks",loaded_wagon.surface, util.positiontostr(loaded_wagon.position)})
      end
      saveRestoreLib.spillStacks(r3, loaded_wagon.surface, loaded_wagon.position)
    end

    -- Restore logistic requests to the first logistic section
    if wagon_data.logistic then
      local section = vehicle.get_logistic_point(defines.logistic_member_index.spidertron_requester).get_section(1)
      for slot,d in pairs(wagon_data.logistic) do
        if d and d.name then
          section.set_slot(slot,{value=d.name, min=d.min, max=d.max})
        end
      end
    end

  end

  -- Make sure the vehicle is disabled and logistics are off
  vehicle.operable = false
  local point = vehicle.get_logistic_point(defines.logistic_member_index.spidertron_requester)
  if point then
    point.enabled = false
  end

  -- Raise event for scripts since now the vehicle actually exists
  -- Added autodrive_data and GCKI_data to arguments. No need to test if they are set: If nil, they will be ignored!
  script.raise_script_built{
      entity = vehicle,
      autodrive_data = wagon_data.autodrive_data,  -- Custom parameter used by Autodrive
      GCKI_data = wagon_data.GCKI_data  -- Custom parameter used by GCKI
    }

  -- Finished creating vehicle, return new wagon data
  log({"vehicle-wagon2.migrated-data", loaded_unit_number, vehicle.name})
  return {
      wagon=loaded_wagon,
      vehicle=vehicle,
      name=vehicle.name,
      active=wagon_data.active,
      operable=wagon_data.operable,
      logistics_enabled=true,
      icon=wagon_data.icon,
      GCKI_data = wagon_data.GCKI_data,
      autodrive_data = wagon_data.autodrive_data
    }
end
