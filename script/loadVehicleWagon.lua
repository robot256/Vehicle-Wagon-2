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
  if player_index and player_index > 0 then
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
    if player then player.create_local_flying_text{text={"vehicle-wagon2.loaded-wagon-error"}} end
    return
  end

  -- Play sound associated with creating loaded wagon
  surface.play_sound({path = "utility/build_medium", position = position, volume_modifier = 0.7})

  -- Store data on vehicle in global table
  local unit_number = loaded_wagon.unit_number
  loaded_wagon.color = vehicle.color
  
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
  
  if not vehicle.operable then
    saveData.operable = false
  end

  local logipoint = vehicle.get_logistic_point(defines.logistic_member_index.spidertron_requester)
  if logipoint then
    saveData.logistics_enabled = logipoint.enabled
    logipoint.enabled = false
  end
  
  -- Register new loaded wagon for destruction event
  script.register_on_object_destroyed(loaded_wagon)

  -- Transfer first vehicle occupant to loaded wagon
  local driver = vehicle.get_driver()
  local passenger = (vehicle.type == "car" and vehicle.get_passenger()) or nil
  -- Eject both occupants from vehicle
  if driver and (not string.find(driver.name, "%-_%-driver")) then
    -- AAI driver gets to stay in the car when it teleports
    -- Player driver gets ejected from vehicle and placed in wagon
    vehicle.set_driver(nil)
    loaded_wagon.set_driver(driver)
  end
  if passenger then
    -- Eject passenger regardless
    vehicle.set_passenger(nil)
    if string.find(passenger.name, "%-_%-driver") then
      -- If AAI driver was in passenger slot, eject and destroy it
      passenger.destroy()
    else
      -- If player passenger was in car, eject and try to place in wagon
      if not loaded_wagon.get_driver() then
        loaded_wagon.set_driver(passenger)
      end
    end
  end

  -- Teleport vehicle to hidden surface
  -- Find a valid unload position on the hidden surface
  local destsurface = getHiddenSurface()
  local destposition = getTeleportCoordinate()
  if vehicle.teleport(destposition, destsurface, true, false) then
    -- Put the shadow item in the loaded wagon inventory
    loaded_wagon.clear_items_inside()
    if loaded_wagon.insert({name=getVehicleItem(vehicle.name), count=1, quality=vehicle.quality}) ~= 1 then
      -- Put an icon on the wagon showing contents
      saveData.icon = renderIcon(loaded_wagon, vehicle.name)
    end
    
    -- Save the wagon contents upon successful teleport
    storage.wagon_data[unit_number] = saveData
  end

end
