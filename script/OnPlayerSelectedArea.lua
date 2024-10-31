--[[ Copyright (c) 2024 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: OnPlayerSelectedArea.lua
 * Description: Event handler for when a player selects area with the winch.
 *  - When the player uses a Winch Tool:
 *    1. If player clicked on a Vehicle, start the loading selection sequence.
 *    2. If player clicked on a Loaded Vehicle Wagon, start the unloading selection sequence.
 *    3. If player clicked on a Vehicle Wagon after clicking on a Vehicle, queue the Loading Action.
 *    4. If player clicked on none of the above after clicking on a Loaded Vehicle Wagon, queue the Unloading Action.
 *    5. If player selected both a Vehicle and empty Vehicle Wagon, immediately queue the Loading Action.
--]]

SCRIPT_PLAYER_INDEX = -1

--== ON_PLAYER_SELECTED_AREA ==--
-- Queues load/unload data when player clicks with the winch.
local function OnPlayerSelectedArea(event)
  if event.item ~= "winch-tool" then return end
  local index = event.player_index or SCRIPT_PLAYER_INDEX
  local player
  if index > 0 then
    player = game.players[index]
  end
  local surface = event.surface
  local position = event.position or {x=(event.area.left_top.x+event.area.right_bottom.x)/2, y=(event.area.left_top.y+event.area.right_bottom.y)/2}

  -- Check that at most one vehicle and at most one wagon was selected
  local selected_vehicles = {}
  local selected_empty_wagons = {}
  local selected_loaded_wagons = {}
  local selected_ramps = {}
  local wagon_height_error = false
  local message_target
  for _,entity in pairs(event.entities) do
    if entity and entity.valid then
      if storage.loadedWagonMap[entity.name]then
        if entity.draw_data.height == 0 then    -- Only select wagons on ground level
          table.insert(selected_loaded_wagons, entity)
        else
          wagon_height_error = true
          message_target = entity
        end
      elseif entity.name == "vehicle-wagon" then
        if entity.draw_data.height == 0 then    -- Only select wagons on ground level
          table.insert(selected_empty_wagons, entity)
        else
          wagon_height_error = true
          message_target = entity
        end
      elseif entity.name == "loading-ramp" then
        table.insert(selected_ramps, entity)
        game.print("Selected ramp "..tostring(entity))
      elseif (entity and entity.valid and (entity.type == "car" or entity.type == "spider-vehicle")) then
        table.insert(selected_vehicles, entity)
      end
    end
  end
  
  if wagon_height_error and #selected_loaded_wagons == 0 and #selected_empty_wagons == 0 then
    -- Only wagons user selected were elevated, so show error message
    if player then player.create_local_flying_text{text={"vehicle-wagon2.elevated-rail-error"}, position=message_target.position} end
    return
  end

  -- Don't check GCKI data if the mod was uninstalled or setting turned off
  local check_GCKI = remote.interfaces["GCKI"] and settings.global["vehicle-wagon-use-GCKI-permissions"].value

  if event.name == defines.events.on_player_selected_area then
    -- Player used normal selection mode
    -- Only allow one wagon and one vehicle
    if #selected_vehicles > 1 or (#selected_empty_wagons + #selected_loaded_wagons) > 1 or #selected_ramps > 1 then
      message_target = selected_vehicles[1] or selected_empty_wagons[1] or selected_loaded_wagons[1] or selected_ramps[1]
      if player then player.create_local_flying_text{text={"vehicle-wagon2.too-many-selected-error"}, position=message_target.position} end
      return
    end
  end

  -- Check if we are IN SPAAAACE!
  local in_space = false
  if remote.interfaces["space-exploration"] then
    local surface_type = remote.call("space-exploration", "get_surface_type", {surface_index = surface.index})
    -- These are the "solid" surface types
    if not (surface_type == "planet" or surface_type == "moon" or surface_type == "vault") then
      in_space = true
    end
  end

  ------------------------------------------------
  -- Loaded Wagon: Check if Valid to Unload
  if selected_loaded_wagons[1] then
    local loaded_wagon = selected_loaded_wagons[1]

    -- Clicked on a Loaded Wagon
    local unit_number = loaded_wagon.unit_number

    if loaded_wagon.get_driver() then
      -- Can't unload while passenger in wagon
      if player then player.create_local_flying_text{text={"vehicle-wagon2.wagon-passenger-error"}, position=loaded_wagon.position} end

    elseif loaded_wagon.train.speed ~= 0 then
      -- Can't unload while train is moving
      if player then player.create_local_flying_text{text={"vehicle-wagon2.train-in-motion-error"}, position=loaded_wagon.position} end

    elseif not storage.wagon_data[unit_number] then
      -- Loaded wagon data or vehicle entity is invalid
      -- Replace wagon with unloaded version and delete data
      if player then player.create_local_flying_text{text={"vehicle-wagon2.data-error", unit_number}, position=loaded_wagon.position} end
      deleteWagon(unit_number)
      replaceCarriage(loaded_wagon, "vehicle-wagon", false, false)

    elseif in_space and not (
          (storage.wagon_data[unit_number].vehicle.type == "spider-vehicle") or
          (string.find(storage.wagon_data[unit_number].name, "se-space", 1, true))
        ) then
      -- If it's not a Spidertron or a space thing, can't unload in space, since SE will delete the vehicle
      if player then
        player.create_local_flying_text{text={"vehicle-wagon2.train-in-space-error", prototypes.entity[storage.wagon_data[unit_number].name].localised_name},
                                        position=loaded_wagon.position}
      end

    elseif check_GCKI and storage.wagon_data[unit_number].GCKI_data and storage.wagon_data[unit_number].GCKI_data.locker and
             storage.wagon_data[unit_number].GCKI_data.locker ~= player.index then
      -- Error: vehicle was locked by someone else before it was loaded
      -- Does not matter if that player exists or claimed a different vehicle, only that player can unload this one
      local locker = game.players[storage.wagon_data[unit_number].GCKI_data.locker]
      local vehicle_prototype = prototypes.entity[storage.wagon_data[unit_number].name]
      if locker and locker.valid then
        -- Player exists, display their name
        if player then player.create_local_flying_text{text={"vehicle-wagon2.unload-locked-vehicle-error", vehicle_prototype.localised_name, locker.name}, position=loaded_wagon.position} end
      else
        -- Player no longer exists.  Should permission still apply?
        if player then player.create_local_flying_text{text={"vehicle-wagon2.unload-locked-vehicle-error", vehicle_prototype.localised_name, "Player #"..tostring(storage.wagon_data[unit_number].GCKI_data.locker)}, position=loaded_wagon.position} end
      end

    elseif check_GCKI and storage.wagon_data[unit_number].GCKI_data and storage.wagon_data[unit_number].GCKI_data.owner and
             storage.wagon_data[unit_number].GCKI_data.owner ~= player.index and
             remote.call("GCKI", "owned_by_player", storage.wagon_data[unit_number].GCKI_data.owner) == nil then
      -- Error: Unloading player is not previous owner, and previous owner has NOT claimed another vehicle in the meantime.
      local owner = game.players[storage.wagon_data[unit_number].GCKI_data.owner]
      local vehicle_prototype = prototypes.entity[storage.wagon_data[unit_number].name]
      if owner and owner.valid then
        -- Player exists, display their name
        if player then player.create_local_flying_text{text={"vehicle-wagon2.unload-owned-vehicle-error", vehicle_prototype.localised_name, owner.name}, position=loaded_wagon.position} end
      else
        -- Player no longer exists.  Should permission still apply?
        if player then player.create_local_flying_text{text={"vehicle-wagon2.unload-owned-vehicle-error", vehicle_prototype.localised_name, "Player #"..tostring(storage.wagon_data[unit_number].GCKI_data.owner)}, position=loaded_wagon.position} end
      end

    elseif storage.action_queue[unit_number] and storage.action_queue[loaded_wagon.unit_number].status ~= "spider-load" then
      -- This wagon already has a pending action
      if player then  player.create_local_flying_text{text={"vehicle-wagon2.loaded-wagon-busy-error"}, position=loaded_wagon.position} end

    else
      local vehicle_prototype = prototypes.entity[storage.wagon_data[unit_number].name]
      -- Select vehicle as unloading source
      if player then player.play_sound{path = "latch-on"} end

      -- Record selection and create radius circle
      storage.player_selection[index] = {
          wagon = loaded_wagon,
          wagon_unit_number = loaded_wagon.unit_number,
          visuals = renderWagonVisuals(player,loaded_wagon,vehicle_prototype.radius)
        }
      updateOnTickStatus(true)
    end
  end

  ---------------------------------------------
  -- Selected a Loading Ramp, see if this is a valid unloading request
  if selected_ramps[1] then
    local ramp = selected_ramps[1]
    if storage.player_selection[index] and storage.player_selection[index].wagon then
      -- Wagon is selected (either in the same player selection or in an earlier action)
      -- Unload onto the ramp in the ramp's direction
      local wagon = storage.player_selection[index].wagon
      local unit_number = wagon.unit_number
      local unload_position = ramp.surface.find_non_colliding_position(storage.wagon_data[unit_number].name, ramp.position, 5, 0.5)
      local unload_orientation = ramp.orientation
      local vehicle_prototype = prototypes.entity[storage.wagon_data[unit_number].name]
      local max_distance = vehicle_prototype.radius + UNLOAD_RANGE
      local ramp_distance = distToWagon(wagon, ramp.position)
    
      if storage.action_queue[unit_number] then
        -- This wagon already has a pending action
        if player then player.create_local_flying_text{text={"vehicle-wagon2.loaded-wagon-busy-error"}, position=wagon.position} end
      elseif not unload_position then
        -- Game could not find open position to unload
        if player then player.create_local_flying_text{text={"vehicle-wagon2.vehicle-not-created-error", prototypes.entity[storage.wagon_data[unit_number].name].localised_name}, position=position} end
      elseif ramp_distance > max_distance then
        -- Player clicked too far away
        if player then player.create_local_flying_text{text={"vehicle-wagon2.location-too-far-away-error", wagon.localised_name}, position=position} end
      else
        -- Manually unload the wagon
        -- Vehicle will be oriented radially outward from the center of the wagon
        wagon.surface.play_sound{path = "winch-sound", position = wagon.position}

        storage.action_queue[unit_number] = {
            player_index = index,
            status = "unload",
            wagon = wagon,
            wagon_unit_number = wagon.unit_number,
            unload_position = unload_position,
            unload_orientation = unload_orientation,
            tick = game.tick + UNLOADING_EFFECT_TIME,
            beam = renderUnloadingRamp(wagon, unload_position, vehicle_prototype.radius)
        }
        clearSelection(index)
        updateOnTickStatus(true)
      end
    else
      -- Clicked on an empty wagon without first clicking on a vehicle
      if player then player.create_local_flying_text{text={"vehicle-wagon2.no-vehicle-selected"}, position=ramp.position} end
    end
  
  end

  --------------------------------
  -- Vehicle: Check if valid to load on wagon
  if selected_vehicles[1] then
    local vehicle = selected_vehicles[1]

    -- Compatibility with GCKI:
    local owner = nil
    local locker = nil
    -- We can get along with fewer remote calls to GCKI!
    if check_GCKI then
      local v_data = remote.call("GCKI", "get_vehicle_data", vehicle)

      -- Either or both of these may be set to a player
      if v_data then
        owner = v_data.owner and game.players[v_data.owner]
        locker = v_data.locker and game.players[v_data.locker]
      end
    end

    if not storage.vehicleMap[vehicle.name] then
      if player then player.create_local_flying_text{text={"vehicle-wagon2.unknown-vehicle-error", vehicle.localised_name}, position=vehicle.position} end

    elseif get_driver_or_passenger(vehicle) then
      if player then player.create_local_flying_text{text={"vehicle-wagon2.vehicle-passenger-error"}, position=vehicle.position} end

    elseif is_vehicle_moving(vehicle) then
      if player then player.create_local_flying_text{text={"vehicle-wagon2.vehicle-in-motion-error"}, position=vehicle.position} end

    elseif in_space and not ((vehicle.type == "spider-vehicle") or string.find(vehicle.name, "se-space", 1, true) ) then
      -- If it's not a Spidertron, can't load in space.
      if player then player.create_local_flying_text{text={"vehicle-wagon2.vehicle-in-space-error", vehicle.localised_name}, position=vehicle.position} end

    elseif locker and locker ~= player then
      -- Can't load someone else's locked vehicle
      if player then player.create_local_flying_text{text={"vehicle-wagon2.load-locked-vehicle-error", vehicle.localised_name, locker.name}, position=vehicle.position} end

    elseif owner and owner ~= player then
      -- Can't load someone else's vehicle
      if player then player.create_local_flying_text{text={"vehicle-wagon2.load-owned-vehicle-error", vehicle.localised_name, owner.name}, position=vehicle.position} end

    else
      -- Store vehicle selection
      if player then player.play_sound{path = "latch-on"} end

      storage.player_selection[index] = {
          vehicle = vehicle,
          vehicle_unit_number = vehicle.unit_number,
          visuals = renderVehicleVisuals(player, vehicle)
        }
      script.register_on_object_destroyed(vehicle)  -- Register the vehicle so we know if it's destroyed and we stop the animation
      updateOnTickStatus(true)
    end
  end

  --------------------------------------
  -- Empty Wagon:  Check if valid to load with selected vehicle
  if selected_empty_wagons[1] then
    local wagon = selected_empty_wagons[1]

    -- Clicked on an empty wagon
    if wagon.train.speed ~= 0 then
      -- Can't load while train is moving
      if player then player.create_local_flying_text{text={"vehicle-wagon2.train-in-motion-error"}, position=wagon.position} end
    elseif (storage.player_selection[index] and
            storage.player_selection[index].vehicle) then
      -- Clicked on empty wagon after clicking on a vehicle
      local vehicle = storage.player_selection[index].vehicle
      if not vehicle or not vehicle.valid then
        -- Selected vehicle no longer exists
        clearSelection(index)
        if player then player.create_local_flying_text{text={"vehicle-wagon2.vehicle-invalid-error"}, position=wagon.position} end
      elseif get_driver_or_passenger(vehicle) then
        -- Selected vehicle has an occupant
        clearSelection(index)
        if player then player.create_local_flying_text{text={"vehicle-wagon2.vehicle-passenger-error"}, position=wagon.position} end
      elseif storage.action_queue[wagon.unit_number] and storage.action_queue[wagon.unit_number].status ~= "spider-load" then
        -- This wagon already has a pending action (ignore spiders following it)
        if player then player.create_local_flying_text{text={"vehicle-wagon2.empty-wagon-busy-error"}, position=wagon.position} end
      elseif distance(wagon.position, vehicle.position) > LOADING_DISTANCE then
        if player then player.create_local_flying_text{text={"vehicle-wagon2.wagon-too-far-away-error", vehicle.localised_name}, position=wagon.position} end
      else
        local loaded_name = storage.vehicleMap[vehicle.name]
        if not loaded_name then
          if player then player.create_local_flying_text{text={"vehicle-wagon2.unknown-vehicle-error", vehicle.localised_name}, position=wagon.position} end
          clearSelection(index)
        else
          wagon.surface.play_sound{path = "winch-sound", position = wagon.position}

          storage.action_queue[wagon.unit_number] = {
              player_index = index,
              status = "load",
              wagon = wagon,
              wagon_unit_number = wagon.unit_number,
              vehicle = vehicle,
              vehicle_unit_number = vehicle.unit_number,
              name = loaded_name,
              tick = game.tick + LOADING_EFFECT_TIME,
              beam = renderLoadingRamp(wagon, vehicle)
          }
          script.register_on_object_destroyed(wagon)  -- Register the wagon so we know if it's destroyed and we stop the animation
          clearSelection(index)
          updateOnTickStatus(true)
        end
      end
    else
      -- Clicked on an empty wagon without first clicking on a vehicle
      if player then player.create_local_flying_text{text={"vehicle-wagon2.no-vehicle-selected"}, position=wagon.position} end
    end
  end
  
  ---------------------------------------------
  -- Someplace Else: Check if valid to unlod selected loaded wagon
  if (#selected_vehicles == 0 and #selected_loaded_wagons == 0 and #selected_empty_wagons == 0 and #selected_ramps == 0) and
     (storage.player_selection[index] and storage.player_selection[index].wagon) then
    -- Clicked on the ground or unrelated entity after clicking on a loaded wagon
    local wagon = storage.player_selection[index].wagon
    local unit_number = wagon.unit_number
    local click_distance = distToWagon(wagon, position)
    local unload_position = player.surface.find_non_colliding_position(storage.wagon_data[unit_number].name, position, 5, 0.5)
    local unload_distance = distToWagon(wagon, unload_position)

    local vehicle_prototype = prototypes.entity[storage.wagon_data[unit_number].name]
    local min_distance = vehicle_prototype.radius + math.abs(wagon.prototype.collision_box.right_bottom.x)
    local max_distance = vehicle_prototype.radius + UNLOAD_RANGE

    if storage.action_queue[unit_number] then
      -- This wagon already has a pending action
      if player then player.create_local_flying_text{text={"vehicle-wagon2.loaded-wagon-busy-error"}, position=wagon.position} end
    elseif not unload_position then
      -- Game could not find open position to unload
      if player then player.create_local_flying_text{text={"vehicle-wagon2.vehicle-not-created-error", prototypes.entity[storage.wagon_data[unit_number].name].localised_name}, position=position} end
    elseif click_distance > max_distance then
      -- Player clicked too far away
      if player then player.create_local_flying_text{text={"vehicle-wagon2.location-too-far-away-error", wagon.localised_name}, position=position} end
    elseif click_distance < min_distance then
      if player then player.create_local_flying_text{text={"vehicle-wagon2.location-too-close-error", wagon.localised_name}, position=position} end -- Player clicked too close
    else
      -- Manually unload the wagon
      -- Vehicle will be oriented radially outward from the center of the wagon
      local unload_orientation = math.atan2(unload_position.x - wagon.position.x, -(unload_position.y - wagon.position.y))/(2*math.pi)
      wagon.surface.play_sound{path = "winch-sound", position = wagon.position}

      storage.action_queue[unit_number] = {
          player_index = index,
          status = "unload",
          wagon = wagon,
          wagon_unit_number = wagon.unit_number,
          unload_position = unload_position,
          unload_orientation = unload_orientation,
          tick = game.tick + UNLOADING_EFFECT_TIME,
          beam = renderUnloadingRamp(wagon, unload_position, vehicle_prototype.radius)
      }
      clearSelection(index)
      updateOnTickStatus(true)
    end
  end
  clearSelection(SCRIPT_PLAYER_INDEX)
end

return OnPlayerSelectedArea
