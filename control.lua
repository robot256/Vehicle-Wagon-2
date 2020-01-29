--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: control.lua
 * Description:  Main runtime control script and event handling.
 *   Events handled:
 *   - on_load
 *   - on_init
 *   - on_configuration_changed
 *   - on_tick (conditional)
 *   - on_player_used_capsule
 *   - on_player_cursor_stack_changed
 *   - on_pre_player_mined_item
 *   - on_robot_pre_mined
 *   - on_picked_up_item
 *   - on_marked_for_deconstruction
 *   - on_built_entity
 *   - script_raised_built
 *   - on_entity_died
 *   - script_raised_destroy
 *   - on_player_driving_changed_state
 *   - on_player_pipette
 *   - on_player_setup_blueprint
--]]

-- Lazy place for a constant
LOADING_DISTANCE = 9


replaceCarriage = require("__Robot256Lib__/script/carriage_replacement").replaceCarriage
blueprintLib = require("__Robot256Lib__/script/blueprint_replacement")
saveRestoreLib = require("__Robot256Lib__/script/save_restore")

require("script.loadVehicleWagon")
require("script.unloadVehicleWagon")
require("script.initialize")


--== ON_INIT ==--
--== ON_CONFIGURATION_CHANGED ==--
-- Initialize global data tables
script.on_init(OnInit)
script.on_configuration_changed(OnConfigurationChanged)


--== ON_LOAD ==--
-- Enable on_tick event according to global variable state
function OnLoad()
  if global.action_queue and table_size(global.action_queue) > 0 then
    script.on_event(defines.events.on_tick, process_tick)
  end
end
script.on_load(OnLoad)


-- Deal with the new 0.16 driver/passenger bit
function get_driver_or_passenger(entity)
  -- Check if we have a driver:
  local driver = entity.get_driver()
  if driver then return driver end

  -- Otherwise check if we have a passenger, which will error if entity is not a car:
  local status, resp = pcall(entity.get_passenger)
  if not status then return nil end
  return resp
end



--== ON_TICK ==--
-- Executes queued load/unload actions after the correct time has elapsed.
function process_tick(event)
  local current_tick = event.tick
  
  -- Loop through players to see if any of them requested load/unload
  --   (would be better to have a separate global queue)
  for i, action in pairs(global.action_queue) do
    if action.player_index and game.players[action.player_index] and action.status then
      local player = game.players[action.player_index]
      ------- LOADING OPERATION --------
      if action.status == "load" and action.tick == current_tick then
        -- Check that the wagon and vehicle indicated by the player are a valid target for loading
        local wagon = action.wagon
        local vehicle = action.vehicle
        if not vehicle or not vehicle.valid then
          player.print({"vehicle-wagon2.vehicle-invalid-error"})
        elseif not wagon or not wagon.valid then
          player.print({"vehicle-wagon2.wagon-invalid-error"})
        elseif get_driver_or_passenger(vehicle) then
          player.print({"vehicle-wagon2.vehicle-passenger-error"})
        elseif wagon.train.speed ~= 0 then
          player.print({"vehicle-wagon2.train-in-motion-error"})
        else
          -- Execute the loading for this player if possible.
          loadVehicleWagon(action)
        end
        -- Clear from queue after completion
        global.action_queue[i] = nil
        
      ------- UNLOADING OPERATION --------
      elseif action.status == "unload" and action.tick == current_tick then
        -- Check that the wagon indicated by the player is a valid target for unloading
        local loaded_wagon = action.wagon
        if not loaded_wagon or not loaded_wagon.valid then
          player.print({"vehicle-wagon2.wagon-invalid-error"})
        elseif loaded_wagon.get_driver() then
          player.print({"vehicle-wagon2.wagon-passenger-error"})
        elseif loaded_wagon.train.speed ~= 0 then
          player.print({"vehicle-wagon2.train-in-motion-error"})
        else
          -- Execute unloading if possible.  Vehicle object returned if successful.
          -- In this case, if vehicle cannot be unloaded, we leave it on the wagon.
          if not unloadVehicleWagon(action) then
            if player then
              player.print({"vehicle-wagon2.vehicle-not-created-error"})
            end
          end
        end
        -- Clear from queue after completion
        global.action_queue[i] = nil
      end
    else
      -- Clear from queue if entry is invalid
      global.action_queue[i] = nil
    end
  end
  
  -- Unsubscribe from on_tick if no actions remains in queue
  if table_size(global.action_queue) == 0 then
    script.on_event(defines.events.on_tick, nil)
  end
end


function clearSelection(player_index)
  -- Clear wagon/vehicle selections of this player
  global.player_selection[player_index] = nil
  if game.players[player_index] then
    game.players[player_index].clear_gui_arrow()
  end
end

function clearWagon(unit_number)
  -- Halt pending load/unload actions with this wagon
  if global.action_queue[unit_number] then
    if global.action_queue[unit_number].beam then
      global.action_queue[unit_number].beam.destroy()
    end
    if global.action_queue[unit_number].status == "load" then
      local player = game.players[global.action_queue[unit_number].player_index]
      if player then
        player.print({"vehicle-wagon2.wagon-invalid-error"})
      end
    end
  end
  global.action_queue[unit_number] = nil
  
  -- Clear player selections of this wagon
  for player_index,selection in pairs(global.player_selection) do
    if selection.wagon and (not selection.wagon.valid or selection.wagon.unit_number == unit_number) then
      clearSelection(player_index)
    end
  end
end

function deleteWagon(unit_number)
  global.wagon_data[unit_number] = nil
  clearWagon(unit_number)
end

function clearVehicle(vehicle)
  -- Clear selection and halt pending actions that involve this vehicle
  for unit_number,action in pairs(global.action_queue) do
    if action.vehicle == vehicle then
      -- Clear beam if any
      if action.beam then
        action.beam.destroy()
      end
      local player = game.players[global.action_queue[unit_number].player_index]
      if player then
        player.print({"vehicle-wagon2.vehicle-invalid-error"})
      end
      global.action_queue[unit_number] = nil
    end
  end
  -- Clear player selections of this vehicle
  for player_index,selection in pairs(global.player_selection) do
    if selection.vehicle and (not selection.vehicle.valid or selection.vehicle == vehicle) then
      clearSelection(player_index)
    end
  end
end

--== ON_PLAYER_USED_CAPSULE ==--
-- Queues load/unload data when player clicks with the winch.
script.on_event(defines.events.on_player_used_capsule, require("script.OnPlayerUsedCapsule"))


--== ON_PLAYER_CURSOR_STACK_CHANGED ==--
-- When player stops holding winch, clear selections
function OnPlayerCursorStackChanged(event)
  local index = event.player_index
  local player = game.players[index]
  local stack = player.cursor_stack
  if not (stack and stack.valid and stack.valid_for_read and stack.name == "winch") then
    if global.player_selection[index] then
      player.play_sound({path = "latch-off"})
      clearSelection(index)
    end
  end
end
script.on_event(defines.events.on_player_cursor_stack_changed, OnPlayerCursorStackChanged)


--== ON_PRE_PLAYER_MINED_ITEM ==--
-- When player mines a loaded wagon, try to unload the vehicle first
-- If vehicle cannot be unloaded, give its contents to the player and spill the rest.
script.on_event(defines.events.on_pre_player_mined_item, require("script.OnPrePlayerMinedItem"))

--== ON_ROBOT_PRE_MINED ==--
-- When robot tries to mine a loaded wagon, try to unload the vehicle first!
-- If vehicle cannot be unloaded, send its contents away in the robot piece by piece.
script.on_event(defines.events.on_robot_pre_mined, require("script.OnRobotPreMined"))


--== ON_PICKED_UP_ITEM ==--
-- When player picks up an item, change loaded wagons to empty wagons.  
function OnPickedUpItem(event)
  if global.loadedWagonMap[event.item_stack.name] then
    game.players[event.player_index].remove_item(event.item_stack)
    game.players[event.player_index].insert({name="vehicle-wagon", count=event.item_stack.count})
  end
end
script.on_event(defines.events.on_picked_up_item, OnPickedUpItem)


--== ON_MARKED_FOR_DECONSTRUCTION ==--
-- When a wagon is marked for deconstruction, cancel any pending actions to load or unload
local number = 1
function OnMarkedForDeconstruction(event)
  -- Delete any player selections or load/unload actions associated with this wagon
  if event.entity.name == "vehicle-wagon" or global.loadedWagonMap[event.entity.name] then
    clearWagon(event.entity.unit_number)
  elseif event.entity.type == "car" then
    clearVehicle(entity)
  end
end
script.on_event(defines.events.on_marked_for_deconstruction, OnMarkedForDeconstruction)


--== ON_BUILT_ENTITY ==--
--== SCRIPT_RAISED_BUILT ==--
-- When a loaded-wagon ghost is created, replace it with unloaded wagon ghost
function OnBuiltEntity(event)
  local entity = event.created_entity or event.entity
  if entity.name == "entity-ghost" then
    if global.loadedWagonMap[entity.ghost_name] then
      local newGhost = {
          name = "entity-ghost",
          inner_name = global.loadedWagonMap[entity.ghost_name],
          position = entity.position,
          orientation = entity.orientation,
          force = entity.force,
          create_build_effect_smoke = false,
          raise_built = false,
          snap_to_train_stop = false}
      
      entity.destroy()
      surface.create_entity(newGhost)
    end
  end
end
script.on_event(defines.events.on_built_entity, OnBuiltEntity)
script.on_event(defines.events.script_raised_built, OnBuiltEntity)


--== ON_ENTITY_DIED ==--
--== SCRIPT_RAISED_DESTROY ==--
-- When a loaded wagon dies or is destroyed by a different mod, delete its vehicle data
function OnEntityDied(event)
  local entity = event.entity
  if global.loadedWagonMap[entity.name] then
    -- Loaded wagon died, its vehicle is unrecoverable
    -- Also clear selection data for this wagon
    if global.wagon_data[entity.unit_number] then
      if game.entity_prototypes[global.wagon_data[entity.unit_number].name] then
        game.print({"vehicle-wagon2.wagon-destroyed", entity.unit_number, {"entity-name."..global.wagon_data[entity.unit_number].name}})
      else
        game.print({"vehicle-wagon2.wagon-destroyed", entity.unit_number, global.wagon_data[entity.unit_number].name})
      end
    end
    deleteWagon(entity.unit_number)
  elseif entity.name == "vehicle-wagon" then
    clearWagon(entity.unit_number)
  elseif event.entity.type == "car" then
    clearVehicle(entity)
  end
end
script.on_event(defines.events.on_entity_died, OnEntityDied)
script.on_event(defines.events.script_raised_destroy, OnEntityDied)


--== ON_PLAYER_DRIVING_CHANGED_STATE ==--
-- Eject player from unloaded wagon
-- Can't ride on an empty flatcar, but you can in a loaded one
function OnPlayerDrivingChangedState(event)
  local player = game.players[event.player_index]
  if player.vehicle and player.vehicle.name == "vehicle-wagon" then
    player.driving = false
  end
end
script.on_event(defines.events.on_player_driving_changed_state, OnPlayerDrivingChangedState)


------------------------- CURSOR AND BLUEPRINT HANDLING FOR 0.17.x ---------------------------------------

--== ON_PLAYER_PIPETTE ==--
-- Fires when player presses 'Q'.  We need to sneakily grab the correct item from inventory if it exists,
--  or sneakily give the correct item in cheat mode.
script.on_event(defines.events.on_player_pipette, 
                function(event) blueprintLib.mapPipette(event, global.loadedWagonMap) end)

--== ON_PLAYER_CONFIGURED_BLUEPRINT ==--
-- ID 70, fires when you select a blueprint to place
--== ON_PLAYER_SETUP_BLUEPRINT ==--
-- ID 68, fires when you select an area to make a blueprint or copy
-- Force Blueprints to only store empty vehicle wagons
script.on_event({defines.events.on_player_setup_blueprint, defines.events.on_player_configured_blueprint}, 
                function(event) blueprintLib.mapBlueprint(event, global.loadedWagonMap) end)

------------------------------------------
-- Debug (print text to player console)
function print_game(...)
  local text = ""
  for _, v in ipairs{...} do
    if type(v) == "table" then
      text = text..serpent.block(v)
    else
      text = text..tostring(v)
    end
  end
  game.print(text)
end

function print_file(...)
  local text = ""
  for _, v in ipairs{...} do
    if type(v) == "table" then
      text = text..serpent.block(v)
    else
      text = text..tostring(v)
    end
  end
  log(text)
end  

-- Debug command
function cmd_debug(params)
  local cmd = params.parameter
  if cmd == "dump" then
    for v, data in pairs(global) do
      print_game(v, ": ", data)
    end
  elseif cmd == "dumplog" then
    for v, data in pairs(global) do
      print_file(v, ": ", data)
    end
    print_game("Dump written to log file")
  end
end
commands.add_command("vehicle-wagon-debug", {"command-help.vehicle-wagon-debug"}, cmd_debug)
