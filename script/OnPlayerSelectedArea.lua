--[[ Copyright (c) 2020 robot256 (MIT License)
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


--== ON_PLAYER_SELECTED_AREA ==--
-- Queues load/unload data when player clicks with the winch.
local function OnPlayerSelectedArea(event)
  if event.item == "winch" then
    local index = event.player_index
    local player = game.players[index]
    local surface = event.surface
    local position = {x=(event.area.left_top.x+event.area.right_bottom.x)/2, y=(event.area.left_top.y+event.area.right_bottom.y)/2}

    -- Check that at most one vehicle and at most one wagon was selected
    local selected_vehicles = {}
    local selected_empty_wagons = {}
    local selected_loaded_wagons = {}
    for _,entity in pairs(event.entities) do
      if entity and entity.valid then
        if global.loadedWagonMap[entity.name] then
          table.insert(selected_loaded_wagons, entity)
        elseif entity.name == "vehicle-wagon" or entity.name == "ferry-boat" then
          table.insert(selected_empty_wagons, entity)
        elseif (entity and entity.valid and (entity.type == "car" or entity.type == "spider-vehicle")) then
          table.insert(selected_vehicles, entity)
        end
      end
    end

    -- Don't check GCKI data if the mod was uninstalled or setting turned off
    local check_GCKI = remote.interfaces["GCKI"] and settings.global["vehicle-wagon-use-GCKI-permissions"].value

    if event.name == defines.events.on_player_selected_area then
      -- Player used normal selection mode
      -- Only allow one wagon and one vehicle
      if #selected_vehicles > 1 or (#selected_empty_wagons + #selected_loaded_wagons) > 1 then
        player.print{"vehicle-wagon2.too-many-selected-error"}
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
        player.print{"vehicle-wagon2.wagon-passenger-error"}  -- Can't unload while passenger in wagon

      elseif loaded_wagon.train.speed ~= 0 then
        player.print{"vehicle-wagon2.train-in-motion-error"}  -- Can't unload while train is moving

      elseif not global.wagon_data[unit_number] then
        -- Loaded wagon data or vehicle entity is invalid
        -- Replace wagon with unloaded version and delete data
        game.print{"vehicle-wagon2.data-error", unit_number}
        deleteWagon(unit_number)
        replaceCarriage(loaded_wagon, global.loadedWagonMap[loaded_wagon.name], false, false)

      elseif not game.entity_prototypes[global.wagon_data[unit_number].name] then
        game.print{"vehicle-wagon2.vehicle-prototype-error", unit_number, global.wagon_data[unit_number].name}
        -- Loaded wagon data or vehicle entity is invalid
        -- Replace wagon with unloaded version and delete data
        deleteWagon(unit_number)
        replaceCarriage(loaded_wagon, global.loadedWagonMap[loaded_wagon.name], false, false)

      elseif in_space and not (
            (game.entity_prototypes[global.wagon_data[unit_number].name].type == "spider-vehicle") or 
            (string.find(global.wagon_data[unit_number].name, "se-space", 1, true))
          ) then
        -- If it's not a Spidertron or a space thing, can't unload in space, since SE will delete the vehicle
        player.print{"vehicle-wagon2.train-in-space-error", game.entity_prototypes[global.wagon_data[unit_number].name].localised_name}

      elseif check_GCKI and global.wagon_data[unit_number].GCKI_data and global.wagon_data[unit_number].GCKI_data.locker and
               global.wagon_data[unit_number].GCKI_data.locker ~= player.index then
        -- Error: vehicle was locked by someone else before it was loaded
        -- Does not matter if that player exists or claimed a different vehicle, only that player can unload this one
        local locker = game.players[global.wagon_data[unit_number].GCKI_data.locker]
        local vehicle_prototype = game.entity_prototypes[global.wagon_data[unit_number].name]
        if locker and locker.valid then
          -- Player exists, display their name
          player.print{"vehicle-wagon2.unload-locked-vehicle-error", vehicle_prototype.localised_name, locker.name}
        else
          -- Player no longer exists.  Should permission still apply?
          player.print{"vehicle-wagon2.unload-locked-vehicle-error", vehicle_prototype.localised_name, "Player #"..tostring(global.wagon_data[unit_number].GCKI_data.locker)}
        end

      elseif check_GCKI and global.wagon_data[unit_number].GCKI_data and global.wagon_data[unit_number].GCKI_data.owner and
               global.wagon_data[unit_number].GCKI_data.owner ~= player.index and
               remote.call("GCKI", "owned_by_player", global.wagon_data[unit_number].GCKI_data.owner) == nil then
        -- Error: Unloading player is not previous owner, and previous owner has NOT claimed another vehicle in the meantime.
        local owner = game.players[global.wagon_data[unit_number].GCKI_data.owner]
        local vehicle_prototype = game.entity_prototypes[global.wagon_data[unit_number].name]
        if owner and owner.valid then
          -- Player exists, display their name
          player.print{"vehicle-wagon2.unload-owned-vehicle-error", vehicle_prototype.localised_name, owner.name}
        else
          -- Player no longer exists.  Should permission still apply?
          player.print{"vehicle-wagon2.unload-owned-vehicle-error", vehicle_prototype.localised_name, "Player #"..tostring(global.wagon_data[unit_number].GCKI_data.owner)}
        end

      elseif global.action_queue[unit_number] then
        -- This wagon already has a pending action
        player.print{"vehicle-wagon2.loaded-wagon-busy-error"}

      else
        local vehicle_prototype = game.entity_prototypes[global.wagon_data[unit_number].name]
        -- Select vehicle as unloading source
        player.play_sound{path = "latch-on"}

        -- Always show tutorial message, to find out what kind of vehicle is stored here
        player.print{"vehicle-wagon2.select-unload-vehicle-location", vehicle_prototype.localised_name}
        -- Record selection and create radius circle
        global.player_selection[index] = {
            wagon=loaded_wagon,
            wagon_unit_number=loaded_wagon.unit_number,
            visuals= renderWagonVisuals(player,loaded_wagon,vehicle_prototype.radius)
          }
        script.on_event(defines.events.on_tick, process_tick)
      end
    end

    --------------------------------
    -- Vehicle: Check if valid to load on wagon
    if selected_vehicles[1] then
      local vehicle = selected_vehicles[1]

      -- Clicked on a vehicle
      global.tutorials[index] = global.tutorials[index] or {}
      global.tutorials[index][1] = global.tutorials[index][1] or 0

      -- Compatibility with GCKI:
      local owner = nil
      local locker = nil
      if check_GCKI then
        -- Either or both of these may be set to a player
        owner = remote.call("GCKI", "vehicle_owned_by", vehicle)
        locker = remote.call("GCKI", "vehicle_locked_by", vehicle)
      end

      if not global.vehicleMap[vehicle.name] then
        player.print{"vehicle-wagon2.unknown-vehicle-error", vehicle.localised_name}

      elseif get_driver_or_passenger(vehicle) then
        player.print{"vehicle-wagon2.vehicle-passenger-error"}

      elseif is_vehicle_moving(vehicle) then
        player.print{"vehicle-wagon2.vehicle-in-motion-error"}

      elseif in_space and not ((vehicle.type == "spider-vehicle") or string.find(vehicle.name, "se-space", 1, true) ) then
        -- If it's not a Spidertron, can't load in space.
        player.print{"vehicle-wagon2.vehicle-in-space-error", vehicle.localised_name}

      elseif locker and locker ~= player then
        -- Can't load someone else's locked vehicle
        player.print{"vehicle-wagon2.load-locked-vehicle-error", vehicle.localised_name, locker.name}

      elseif owner and owner ~= player then
        -- Can't load someone else's vehicle
        player.print{"vehicle-wagon2.load-owned-vehicle-error", vehicle.localised_name, owner.name}

      else
        -- Store vehicle selection
        player.play_sound{path = "latch-on"}

        global.player_selection[index] = {
            vehicle=vehicle,
            vehicle_unit_number=vehicle.unit_number,
            visuals= renderVehicleVisuals(player,vehicle)
          }
        -- Tutorial message to select an empty wagon
        if global.tutorials[index][1] < 5 then
          global.tutorials[index][1] = global.tutorials[index][1] + 1
          player.print{"vehicle-wagon2.vehicle-selected", vehicle.localised_name}
        end
        script.on_event(defines.events.on_tick, process_tick)
      end
    end

    --------------------------------------
    -- Empty Wagon:  Check if valid to load with selected vehicle
    if selected_empty_wagons[1] then
      local wagon = selected_empty_wagons[1]

      -- Clicked on an empty wagon
      if wagon.train.speed ~= 0 then
        player.print{"vehicle-wagon2.train-in-motion-error"}  -- Can't load while train is moving
      elseif (global.player_selection[index] and
              global.player_selection[index].vehicle) then
        -- Clicked on empty wagon after clicking on a vehicle
        local vehicle = global.player_selection[index].vehicle
        if not vehicle or not vehicle.valid then
          -- Selected vehicle no longer exists
          clearSelection(index)
          player.print{"vehicle-wagon2.vehicle-invalid-error"}
        elseif get_driver_or_passenger(vehicle) then
          -- Selected vehicle has an occupant
          clearSelection(index)
          player.print{"vehicle-wagon2.vehicle-passenger-error"}
        elseif global.action_queue[wagon.unit_number] then
          -- This wagon already has a pending action
          player.print{"vehicle-wagon2.empty-wagon-busy-error"}
        elseif distance(wagon.position, vehicle.position) > LOADING_DISTANCE then
          player.print{"vehicle-wagon2.wagon-too-far-away-error", vehicle.localised_name}
        else
          local loaded_name = global.vehicleMap[vehicle.name]
          if not loaded_name then
            player.print{"vehicle-wagon2.unknown-vehicle-error", vehicle.localised_name}
            clearSelection(index)
          else
            if wagon.name == "ferry-boat" then
              loaded_name = "loaded-ferry-boat"
            end
            player.surface.play_sound{path = "winch-sound", position = wagon.position}

            global.action_queue[wagon.unit_number] = {
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
            clearSelection(index)
            script.on_event(defines.events.on_tick, process_tick)
          end
        end
      else
        -- Clicked on an empty wagon without first clicking on a vehicle
        player.print{"vehicle-wagon2.no-vehicle-selected"}
      end
    end

    ---------------------------------------------
    -- Someplace Else: Check if valid to unlod selected loaded wagon
    if (#selected_vehicles == 0 and #selected_loaded_wagons == 0 and #selected_empty_wagons == 0) and
       (global.player_selection[index] and global.player_selection[index].wagon) then
      -- Clicked on the ground or unrelated entity after clicking on a loaded wagon
      local wagon = global.player_selection[index].wagon
      local unit_number = wagon.unit_number
      local click_distance = distToWagon(wagon, position)
      local unload_position = player.surface.find_non_colliding_position(global.wagon_data[unit_number].name, position, 5, 0.5)
      local unload_distance = distToWagon(wagon, unload_position)

      local vehicle_prototype = game.entity_prototypes[global.wagon_data[unit_number].name]
      local min_distance = vehicle_prototype.radius + math.abs(wagon.prototype.collision_box.right_bottom.x)
      local max_distance = vehicle_prototype.radius + UNLOAD_RANGE
      
      if wagon.name == "loaded-ferry-boat" then
        max_distance = vehicle_prototype.radius + UNLOAD_RANGE*10
      end

      if global.action_queue[unit_number] then
        -- This wagon already has a pending action
        player.print{"vehicle-wagon2.loaded-wagon-busy-error"}
      elseif not unload_position then
        player.print{"vehicle-wagon2.vehicle-not-created-error", game.entity_prototypes[global.wagon_data[unit_number].name].localised_name}  -- Game could not find open position to unload
      elseif click_distance > max_distance then
        player.print{"vehicle-wagon2.location-too-far-away-error", wagon.localised_name}  -- Player clicked too far away
      elseif click_distance < min_distance then
        player.print{"vehicle-wagon2.location-too-close-error", wagon.localised_name}  -- Player clicked too close
      else
        -- Manually unload the wagon
        -- Vehicle will be oriented radially outward from the center of the wagon
        local unload_orientation = math.atan2(unload_position.x - wagon.position.x, -(unload_position.y - wagon.position.y))/(2*math.pi)
        player.surface.play_sound{path = "winch-sound", position = wagon.position}

        global.action_queue[unit_number] = {
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
        script.on_event(defines.events.on_tick, process_tick)
      end
    end

  end
end

return OnPlayerSelectedArea
