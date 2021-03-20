--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: control.lua
 * Description:  Main runtime control script and event handling.
 *   Events handled:
 *   - on_load
 *   - on_init
 *   - on_configuration_changed
 *   - on_runtime_mod_setting_changed
 *   - on_tick (conditional)
 *   - on_pre_player_removed
 *   - on_player_used_capsule
 *   - on_player_cursor_stack_changed
 *   - on_pre_player_mined_item
 *   - on_robot_pre_mined
 *   - on_picked_up_item
 *   - on_marked_for_deconstruction
 *   - on_built_entity
 *   - script_raised_built
 *   - on_entity_cloned
 *   - on_entity_died
 *   - script_raised_destroy
 *   - on_player_driving_changed_state
 *   - on_player_pipette
 *   - on_player_setup_blueprint
--]]

require("config")


replaceCarriage = require("__Robot256Lib__/script/carriage_replacement").replaceCarriage
blueprintLib = require("__Robot256Lib__/script/blueprint_replacement")
saveRestoreLib = require("__Robot256Lib__/script/save_restore")

require("script.renderVisuals")
require("script.loadVehicleWagon")
require("script.unloadVehicleWagon")
require("script.initialize")

--== ON_INIT ==--
-- Initialize global data tables
script.on_init(OnInit)

--== ON_CONFIGURATION_CHANGED ==--
-- Initialize global data tables and perform migrations
script.on_configuration_changed(OnConfigurationChanged)

--== ON_RUNTIME_MOD_SETTING_CHANGED ==--
-- Update loaded_wagon.minable properties when GCKI permission setting changes
script.on_event(defines.events.on_runtime_mod_setting_changed, OnRuntimeModSettingChanged)


--== ON_LOAD ==--
-- Enable on_tick event according to global variable state
function OnLoad()
  if (global.action_queue and table_size(global.action_queue) > 0) or
     (global.player_selection and table_size(global.player_selection) > 0) then
    script.on_event(defines.events.on_tick, process_tick)
  end
end
script.on_load(OnLoad)


-- Figure out of a character is driving or riding this car, spider, or wagon
function get_driver_or_passenger(entity)
  -- Check if we have a driver that is not an AAI character:
  local driver = entity.get_driver()
  if driver and not string.find(driver.name, "%-_%-driver") then
    return driver
  end

  -- Otherwise check if we have a passenger, which will error if entity is not a car:
  local status, resp = pcall(entity.get_passenger)
  if not status then return nil end
  return resp
end


-- Determine if the vehicle is moving.
-- Use speed and spider autopilot if present.
function is_vehicle_moving(vehicle)
  if vehicle.speed ~= 0 then
    return true
  elseif vehicle.type == "spider-vehicle" and vehicle.autopilot_destination ~= nil then
    return true
  else
    return false
  end
end


--== ON_TICK ==--
-- Executes queued load/unload actions after the correct time has elapsed.
function process_tick(event)
  local current_tick = event.tick
  
  for player_index, selection in pairs(global.player_selection) do
    -- Check if the selected wagon & vehicle died or started moving
    if selection.wagon_unit_number and not(selection.wagon and selection.wagon.valid) then
      -- Wagon was selected but it's not there anymore
      clearWagon(selection.wagon_unit_number, {silent=true, sound=false})
    elseif selection.wagon and selection.wagon.speed ~= 0 then
      -- Wagon still there but started moving
      clearWagon(selection.wagon_unit_number, {silent=true, sound=true})
    elseif selection.vehicle_unit_number and not (selection.vehicle and selection.vehicle.valid) then
      -- Vehicle was selected but it's not there anymore
      if selection.wagon_unit_number then
        clearWagon(selection.wagon_unit_number, {silent=true, sound=false})
      else
        clearSelection(player_index, {silent=true, sound=false})
      end
    elseif selection.vehicle and is_vehicle_moving(selection.vehicle) then
      clearVehicle(selection.vehicle, {silent=true, sound=true})
    end
  end
  
  -- Check Action queue to see if any are ready this tick, or became invalid
  for unit_number, action in pairs(global.action_queue) do
    if action.player_index and game.players[action.player_index] and action.status then
      local player = game.players[action.player_index]
      ------- CHECK THAT WAGON AND CAR ARE STILL STOPPED ------
      local wagon = action.wagon
      local vehicle = action.vehicle
      if not wagon or not wagon.valid or wagon.train.speed ~= 0 or (vehicle and is_vehicle_moving(vehicle)) then
        -- Train/vehicle started moving, cancel action silently
        clearWagon(unit_number, {silent=true, sound=false})
      
      ------- LOADING OPERATION --------
      elseif action.status == "load" and action.tick == current_tick then
        -- Check that the wagon and vehicle indicated by the player are a valid target for loading
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
        global.action_queue[unit_number] = nil
        
      ------- UNLOADING OPERATION --------
      elseif action.status == "unload" and action.tick == current_tick then
        -- Check that the wagon indicated by the player is a valid target for unloading
        if not wagon or not wagon.valid then
          player.print({"vehicle-wagon2.wagon-invalid-error"})
        elseif wagon.get_driver() then
          player.print({"vehicle-wagon2.wagon-passenger-error"})
        elseif wagon.train.speed ~= 0 then
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
        global.action_queue[unit_number] = nil
      end
    else
      -- Clear from queue if entry is invalid
      global.action_queue[unit_number] = nil
    end
  end
  
  -- Unsubscribe from on_tick if no actions remains in queue
  if table_size(global.action_queue) == 0 and table_size(global.player_selection) == 0 then
    script.on_event(defines.events.on_tick, nil)
  end
end


---------------------------------
-- [GCKI  and Autodrive Compatibility]
-- Remove locker or owner assignment when necessary
--== ON_PRE_PLAYER_REMOVED EVENT ==--
function onPrePlayerRemoved(event)
  local player_index = event.player_index
  
  local unminable_enabled = game.active_mods["UnminableVehicles"] and settings.global["unminable_vehicles_make_unminable"].value
  
  for wagon_id,data in pairs(global.wagon_data) do
    if data.GCKI_data then
      if data.GCKI_data.owner and data.GCKI_data.owner == player_index then
        -- Owner was removed
        data.GCKI_data.owner = nil
      end
      if data.GCKI_data.locker and data.GCKI_data.locker == player_index then
        -- Locker was removed
        data.GCKI_data.locker = nil
      end
      
      -- If UnminableVehicles is not enabled, update minable states.
      if not unminable_enabled then
        -- Make wagon minable when it belongs to no one
        if not (data.GCKI_data.owner or data.GCKI_data.locker) and data.wagon and data.wagon.valid then
          data.wagon.minable = true
        end
        -- Make vehicle minable when it is locked by no one
        if not data.GCKI_data.locker then
          data.minable = nil
        end
      end
    end
    if data.autodrive_data then
      if data.autodrive_data.owner and data.autodrive_data.owner == player_index then
        -- Owner was removed
        data.autodrive_data.owner = nil
      end
    end
  end
end
script.on_event(defines.events.on_pre_player_removed, onPrePlayerRemoved)

----------------------------
-- MOD INTERFACE FUNCTIONS

-- Allow Gizmo's Car Keys to manipulate loaded vehicles
function release_owned_by_player(p)
  local player_index = p
  if type(p) ~= "number" then
    player_index = p.index
  end
  
  local unminable_enabled = game.active_mods["UnminableVehicles"] and settings.global["unminable_vehicles_make_unminable"].value
  
  for wagon_id,data in pairs(global.wagon_data) do
    if data.GCKI_data then
      if data.GCKI_data.owner and data.GCKI_data.owner == player_index then
        -- Owner was removed
        data.GCKI_data.owner = nil
        -- If UnminableVehicles is not enabled, update minable states.
        if not unminable_enabled then
          -- Make wagon minable when it belongs to no one
          if not (data.GCKI_data.owner or data.GCKI_data.locker) and data.wagon and data.wagon.valid then
            data.wagon.minable = true
          end
          -- Make vehicle minable when it is locked by no one
          if not data.GCKI_data.locker then
            data.minable = nil
          end
        end
      end
    end
  end
end

-- Returns a copy of the loaded vehicle data for the wagon entity.
function get_wagon_data(wagon)
  if wagon and wagon.valid and global.wagon_data and global.wagon_data[wagon.unit_number] then
    -- Copy the table so it can be safely deleted from our global later
    local saveData = table.deepcopy(global.wagon_data[wagon.unit_number])
    -- Delete references to actual game objects that will be deleted later
    saveData.wagon = nil
    saveData.icon = nil
    --game.print("VehicleWagon2 retrieved data for wagon #"..tostring(wagon.unit_number).." containing vehicle type "..saveData.name)
    return saveData
  --elseif wagon and wagon.valid then
  --  game.print("VehicleWagon2 could not retrieve wagon data for "..wagon.name.." #"..tostring(wagon.unit_number))
  --else
  --  game.print("VehicleWagon2 could not retrieve wagon data.")
  end
end

-- Stores the new loaded-vehicle data associated with the given wagon.
function set_wagon_data(wagon, new_data)
  if wagon and wagon.valid and string.find(wagon.name, "loaded%-vehicle%-wagon") and new_data and new_data.name then
    local saveData = table.deepcopy(new_data)
    saveData.wagon = wagon
    -- Put an icon on the wagon showing contents
    saveData.icon = renderIcon(wagon, saveData.name)
    -- Make sure contents are valid
    saveData.items = saveData.items or {}
    -- Store data in global
    global.wagon_data = global.wagon_data or {}
    global.wagon_data[wagon.unit_number] = saveData
  --  game.print("VehicleWagon2 set data for wagon "..tostring(wagon.unit_number).." to vehicle type "..saveData.name)
  --elseif wagon and wagon.valid then
  --  game.print("VehicleWagon2 could not set wagon data for "..wagon.name.." #"..tostring(wagon.unit_number))
  --else
  --  game.print("VehicleWagon2 could not set wagon data.")
  end
end

-- Gives the error message from losing a stored vehicle (unit_number of the lost wagon is optional)
function kill_wagon_data(lost_data, unit_number)
  if lost_data and lost_data.name then
    local unit_string = ""
    if unit_number then
      unit_string = "#"..tostring(unit_number).." "
    end
    if game.entity_prototypes[lost_data.name] then
        game.print{"vehicle-wagon2.wagon-destroyed", unit_string, game.entity_prototypes[lost_data.name].localised_name}
    else
      game.print{"vehicle-wagon2.wagon-destroyed", unit_string, lost_data.name}
    end
  end
end
------------------------------



function clearSelection(player_index, flags)
  flags = flags or {}
  -- Clear wagon/vehicle selections of this player
  clearVisuals(player_index)
  global.player_selection[player_index] = nil
  local player = game.players[player_index]
  if player and flags.sound then
    player.play_sound({path = "latch-off"})
  end
end

function clearWagon(unit_number, flags)
  flags = flags or {}
  -- Halt pending load/unload actions with this wagon
  if global.action_queue[unit_number] then
    if global.action_queue[unit_number].beam then
      global.action_queue[unit_number].beam.destroy()
    end
    if global.action_queue[unit_number].status == "load" then
      local player = game.players[global.action_queue[unit_number].player_index]
      if player and not flags.silent then
        player.print({"vehicle-wagon2.wagon-invalid-error"})
      end
    end
  end
  global.action_queue[unit_number] = nil
  
  -- Clear player selections of this wagon
  for player_index,selection in pairs(global.player_selection) do
    if selection.wagon and (not selection.wagon.valid or selection.wagon.unit_number == unit_number) then
      clearSelection(player_index, flags)
    end
  end
end

function deleteWagon(unit_number)
  global.wagon_data[unit_number] = nil
  clearWagon(unit_number)
end

function clearVehicle(vehicle, flags)
  flags = flags or {}
  -- Clear selection and halt pending actions that involve this vehicle
  for unit_number,action in pairs(global.action_queue) do
    if action.vehicle == vehicle then
      -- Clear beam if any
      if action.beam then
        action.beam.destroy()
      end
      local player = game.players[global.action_queue[unit_number].player_index]
      if player and not flags.silent then
        player.print({"vehicle-wagon2.vehicle-invalid-error"})
      end
      global.action_queue[unit_number] = nil
    end
  end
  -- Clear player selections of this vehicle
  for player_index,selection in pairs(global.player_selection) do
    if selection.vehicle and (not selection.vehicle.valid or selection.vehicle == vehicle) then
      clearSelection(player_index, flags)
    end
  end
end


--== ON_PLAYER_USED_CAPSULE ==--
-- Queues load/unload data when player clicks with the winch.
script.on_event(defines.events.on_player_selected_area, require("script.OnPlayerSelectedArea"))


--== ON_PLAYER_CURSOR_STACK_CHANGED ==--
-- When player stops holding winch, clear selections
function OnPlayerCursorStackChanged(event)
  local index = event.player_index
  local player = game.players[index]
  local stack = player.cursor_stack
  if not (stack and stack.valid and stack.valid_for_read and stack.name == "winch") then
    if global.player_selection[index] then
      clearSelection(index, {sound=true})
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
    game.players[event.player_index].insert({name=global.loadedWagonMap[event.item_stack.name], count=event.item_stack.count})
  end
end
script.on_event(defines.events.on_picked_up_item, OnPickedUpItem)


--== ON_MARKED_FOR_DECONSTRUCTION ==--
-- When a wagon is marked for deconstruction, cancel any pending actions to load or unload
local number = 1
function OnMarkedForDeconstruction(event)
  -- Delete any player selections or load/unload actions associated with this wagon
  if event.entity.name == "vehicle-wagon" or global.loadedWagonMap[event.entity.name] or event.entity.name == "ferry-boat" then
    clearWagon(event.entity.unit_number)
  elseif (event.entity.type == "car" or event.entity.type == "spider-vehicle") then
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
      local surface = entity.surface
      local newGhost = {
          name = "entity-ghost",
          inner_name = global.loadedWagonMap[entity.ghost_name],
          position = entity.position,
          orientation = entity.orientation,
          force = entity.force,
          create_build_effect_smoke = false,
          raise_built = false,
          snap_to_train_stop = false
        }
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
    -- Loaded wagon died, its vehicle is unrecoverable (if it wasn't already cloned)
    -- Also clear selection data for this wagon
    if global.wagon_data[entity.unit_number] and not (global.wagon_data[entity.unit_number].cloned or event.cloned) then
      if game.entity_prototypes[global.wagon_data[entity.unit_number].name] then
        game.print{"vehicle-wagon2.wagon-destroyed", "#"..entity.unit_number.." ", game.entity_prototypes[global.wagon_data[entity.unit_number].name].localised_name}
      else
        game.print{"vehicle-wagon2.wagon-destroyed", "#"..entity.unit_number.." ", global.wagon_data[entity.unit_number].name}
      end
    end
    deleteWagon(entity.unit_number)
  elseif entity.name == "vehicle-wagon" or entity.name == "ferry-boat" then
    clearWagon(entity.unit_number)
  elseif (event.entity.type == "car" or event.entity.type == "spider-vehicle") and not event.vehicle_loaded then
    -- Car died, 
    clearVehicle(entity, {silent=true})
  end
end
script.on_event(defines.events.on_entity_died, OnEntityDied)
script.on_event(defines.events.script_raised_destroy, OnEntityDied)


--== ON_ENTITY_CLONED ==--
-- When a loaded wagon is cloned, copy its stored data to the new unit_number.
-- If new wagon is on a different surface, assume the old one was deleted.
function OnEntityCloned(event)
  local source = event.source
  local destination = event.destination
  if global.loadedWagonMap[source.name] then
    if global.wagon_data[source.unit_number] then
      -- Copy the data table for the cloned entity, so the loaded vehicle is cloned too
      global.wagon_data[destination.unit_number] = table.deepcopy(global.wagon_data[source.unit_number])
      
      -- Reference the new wagon
      global.wagon_data[destination.unit_number].wagon = destination
      
      -- Store a flag saying the old data was cloned
      global.wagon_data[source.unit_number].cloned = true
      
      -- Put an icon on the new wagon showing contents
      global.wagon_data[destination.unit_number].icon = renderIcon(destination, global.wagon_data[destination.unit_number].name)
    end
  end
end
script.on_event(defines.events.on_entity_cloned, OnEntityCloned)


--== ON_PLAYER_DRIVING_CHANGED_STATE ==--
function OnPlayerDrivingChangedState(event)
  -- Eject player from unloaded wagon
  -- Cancel selections/actions when player enters selected vehicle or wagon
  local player = game.players[event.player_index]
  if player.vehicle then
    local vehicle = player.vehicle
    if vehicle.name == "vehicle-wagon" or vehicle.name == "ferry-boat" then
      player.driving = false
    elseif global.loadedWagonMap[vehicle.name] then
      clearWagon(vehicle.unit_number, {silent=true, sound=true})
    elseif (vehicle.type == "car" or vehicle.type == "spider-vehicle") then
      clearVehicle(vehicle, {silent=true, sound=true})
    end
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


--------------------------------------
-- REMOTE MOD INTERFACES
remote.add_interface('VehicleWagon2', {
  
  -- GCKI COMPATIBILITY
  -- Removes this player as "owner" of any loaded vehicles.  Called when this player claims a different vehicle.
  release_owned_by_player = release_owned_by_player,
  -- RENAI TRANSPORTATION COMPATIBILITY
  -- Returns the global.wagon_data for the given LuaEntity
  get_wagon_data = get_wagon_data,
  -- Sets the global.wagon_data for the given LuaEntity to the given Lua table, and creates icons
  set_wagon_data = set_wagon_data,
  -- Provides the error message from a destroyed wagon
  kill_wagon_data = kill_wagon_data
  })



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

------------------------------------------------------------------------------------
--                    FIND LOCAL VARIABLES THAT ARE USED GLOBALLY                 --
--                              (Thanks to eradicator!)                           --
------------------------------------------------------------------------------------
setmetatable(_ENV,{
  __newindex=function (self,key,value) --locked_global_write
    error('\n\n[ER Global Lock] Forbidden global *write*:\n'
      .. serpent.line{key=key or '<nil>',value=value or '<nil>'}..'\n')
    end,
  __index   =function (self,key) --locked_global_read
    error('\n\n[ER Global Lock] Forbidden global *read*:\n'
      .. serpent.line{key=key or '<nil>'}..'\n')
    end ,
  })

if script.active_mods["gvv"] then require("__gvv__.gvv")() end

