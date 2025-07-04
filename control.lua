--[[ Copyright (c) 2024 robot256 (MIT License)
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
 *   - on_player_selected_area
 *   - on_player_cursor_stack_changed
 *   - on_pre_player_mined_item
 *   - on_robot_pre_mined
 *   - on_picked_up_item
 *   - on_marked_for_deconstruction
 *   - on_built_entity
 *   - script_raised_built
 *   - on_entity_cloned
 *   - on_object_destroyed
 *   - on_player_driving_changed_state
 *   - on_player_setup_blueprint
 *   - on_player_used_spidertron_remote
--]]

require("config")
local math2d = require("math2d")

replaceCarriage = require("__Robot256Lib__/script/carriage_replacement").replaceCarriage
blueprintLib = require("__Robot256Lib__/script/blueprint_replacement")
saveRestoreLib = require("__Robot256Lib__/script/save_restore")
filterLib = require("__Robot256Lib__/script/event_filters")

require("script.getVehicleItem")
require("script.renderVisuals")
require("script.hiddenSurface")
require("script.loadVehicleWagon")
require("script.unloadVehicleWagon")
require("script.migrateLoadedWagon")
require("script.initialize")
require("script.OnPrePlayerMinedItem")
require("script.OnRobotPreMined")
-- Experimental:
require("script.loadingRamp")
require("script.autoloading")

--~ local mod_data = require("__VehicleWagon2__/mod_data")
--~ VW = require("__Pi-C_lib__/common")(mod_data)

AUTODRIVE = script.active_mods.autodrive and true or false
GCKI = script.active_mods.GCKI and true or false

--== ON_INIT ==--
-- Initialize global data tables
script.on_init(function()
  OnInit()
  RegisterFilteredEvents()
end)

--== ON_CONFIGURATION_CHANGED ==--
-- Initialize global data tables and perform migrations
script.on_configuration_changed(function(event)
  OnConfigurationChanged(event)
  RegisterFilteredEvents()
end)

--== ON_RUNTIME_MOD_SETTING_CHANGED ==--
-- Update loaded_wagon.minable properties when GCKI permission setting changes
script.on_event(defines.events.on_runtime_mod_setting_changed, OnRuntimeModSettingChanged)

function updateOnTickStatus(enable, silent)
  if enable or (storage.action_queue and table_size(storage.action_queue) > 0) or
     (storage.player_selection and table_size(storage.player_selection) > 0) or
     (storage.active_ramps and table_size(storage.active_ramps) > 0) then
--    if not silent and not script.get_event_handler(defines.events.on_tick) then
--      game.print(tostring(game.tick).." tick ON")
--    end
    script.on_event(defines.events.on_tick, process_tick)
  else
    --if not silent and script.get_event_handler(defines.events.on_tick) then
    --  game.print(tostring(game.tick).." tick OFF")
    --end
    script.on_event(defines.events.on_tick, nil)
  end
end

--== ON_LOAD ==--
-- Enable on_tick event according to global variable state
script.on_load(function()
  updateOnTickStatus(false, true)
  RegisterFilteredEvents()
end)


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
  if vehicle.type == "spider-vehicle" and vehicle.follow_target and vehicle.follow_target.name == "vehicle-wagon" then
    -- Spider is available to load even if it's still moving toward the wagon
    return false
  elseif vehicle.speed ~= 0 then
    return true
  else
    return false
  end
end


--== ON_TICK ==--
-- Executes queued load/unload actions after the correct time has elapsed.
function process_tick(event)
  local current_tick = event.tick

  for player_index, selection in pairs(storage.player_selection) do
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
  for unit_number, action in pairs(storage.action_queue) do
    if action.status == "spider-load" then
      if action.tick == current_tick then
        -- Make sure this spider is still targeting this wagon and they are still valid
        if not (action.wagon.valid and action.vehicle.valid and action.vehicle.follow_target == action.wagon) then
          -- Not following anymore, clear the action
          storage.action_queue[unit_number] = nil
        else
          -- Check if spider is close enough and slow enough
          local distance = math2d.position.distance(action.wagon.position, action.vehicle.position)
          if action.wagon.speed == 0 and distance < SPIDER_LOAD_DISTANCE then
            action.wagon.surface.play_sound({path = "utility/build_medium", position = action.wagon.position, volume_modifier = 0.7})
            loadVehicleWagon(action)
            storage.action_queue[unit_number] = nil
          else
            action.tick = current_tick + SPIDER_CHECK_TIME
          end
        end
      end
    elseif action.player_index and (action.player_index == -1 or game.players[action.player_index]) and (action.status == "load" or action.status == "unload") then
      local player
      if action.player_index > 0 then
        player = game.players[action.player_index]
      end
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
          if player then player.create_local_flying_text{text={"vehicle-wagon2.vehicle-invalid-error"}} end
        elseif not wagon or not wagon.valid then
          if player then player.create_local_flying_text{text={"vehicle-wagon2.wagon-invalid-error"}} end
        elseif get_driver_or_passenger(vehicle) then
          if player then player.create_local_flying_text{text={"vehicle-wagon2.vehicle-passenger-error"}, position=vehicle.position} end
        elseif wagon.train.speed ~= 0 then
          if player then player.create_local_flying_text{text={"vehicle-wagon2.train-in-motion-error"}, position=wagon.position} end
        else
          -- Execute the loading for this player if possible.
          loadVehicleWagon(action)
        end
        -- Clear from queue after completion
        storage.action_queue[unit_number] = nil

      ------- UNLOADING OPERATION --------
      elseif action.status == "unload" and action.tick == current_tick then
        -- Check that the wagon indicated by the player is a valid target for unloading
        if not wagon or not wagon.valid then
          if player then player.create_local_flying_text{text={"vehicle-wagon2.wagon-invalid-error"}} end
        elseif wagon.get_driver() then
          if player then player.create_local_flying_text{text={"vehicle-wagon2.wagon-passenger-error"}, position=wagon.position} end
        elseif wagon.train.speed ~= 0 then
          if player then player.create_local_flying_text{text={"vehicle-wagon2.train-in-motion-error"}, position=wagon.position} end
        else
          -- Execute unloading if possible.  Vehicle object returned if successful.
          -- In this case, if vehicle cannot be unloaded, we leave it on the wagon.
          if not unloadVehicleWagon(action) then
            if player then player.create_local_flying_text{text={"vehicle-wagon2.vehicle-not-created-error"}, position=wagon.position} end
          end
        end
        -- Clear from queue after completion
        storage.action_queue[unit_number] = nil
      end
    else
      -- Clear from queue if entry is invalid
      storage.action_queue[unit_number] = nil
    end
  end

  -- Check Active Loading Ramp queue
  ProcessActiveRamps()

  -- Unsubscribe from on_tick if no actions remains in queue
  updateOnTickStatus()
end


---------------------------------
-- [GCKI  and Autodrive Compatibility]
-- Remove locker or owner assignment when necessary
--== ON_PRE_PLAYER_REMOVED EVENT ==--
function onPrePlayerRemoved(event)
  local player_index = event.player_index

  for wagon_id,data in pairs(storage.wagon_data) do
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
      if not storage.unminable_enabled then
        -- Make wagon minable when it belongs to no one
        if not (data.GCKI_data.owner or data.GCKI_data.locker) and data.wagon and data.wagon.valid then
          data.wagon.minable_flag = true
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

-- Returns a copy of the loaded vehicle data for the wagon entity.
function get_wagon_data(wagon)
  if wagon and wagon.valid and storage.wagon_data and storage.wagon_data[wagon.unit_number] then
    -- Copy the table so it can be safely deleted from our global later
    local saveData = table.deepcopy(storage.wagon_data[wagon.unit_number])
    -- Delete references to actual game objects that will be deleted later
    saveData.wagon = nil
    saveData.icon = nil
    saveData.vehicle = nil
    return saveData
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
    storage.wagon_data = storage.wagon_data or {}
    storage.wagon_data[wagon.unit_number] = saveData
  end
end

-- Gives the error message from losing a stored vehicle (unit_number of the lost wagon is optional)
function kill_wagon_data(lost_data, unit_number)
  if lost_data and lost_data.name then
    if lost_data.vehicle and lost_data.vehicle.valid then
      lost_data.vehicle.destroy()
    end
    local unit_string = ""
    if unit_number then
      unit_string = "#"..tostring(unit_number).." "
    end
    if prototypes.entity[lost_data.name] then
        game.print{"vehicle-wagon2.wagon-destroyed", unit_string, prototypes.entity[lost_data.name].localised_name}
    else
      game.print{"vehicle-wagon2.wagon-destroyed", unit_string, lost_data.name}
    end
  end
end
------------------------------



function clearSelection(player_index, flags)
  flags = flags or {}
  -- Clear wagon/vehicle selections of this player
  if player_index > 0 then
    clearVisuals(player_index)
    local player = game.players[player_index]
    if player and flags.sound then
      player.play_sound({path = "latch-off"})
    end
  end
  storage.player_selection[player_index] = nil
end

function clearWagon(unit_number, flags)
  flags = flags or {}
  -- Halt pending load/unload actions with this wagon
  local action = storage.action_queue[unit_number]
  if action then
    if action.beam then
      action.beam.destroy()
    end
    if action.status == "load" then
      local player = (action.player_index > 0 and game.players[action.player_index]) or nil
      if player and not flags.silent then
        local message_position = (action.wagon and action.wagon.valid and action.wagon.position) or (action.vehicle and action.vehicle.valid and action.vehicle.position) or nil
        player.create_local_flying_text{text={"vehicle-wagon2.wagon-invalid-error"}, position=message_position}
      end
    end
  end
  storage.action_queue[unit_number] = nil

  -- Clear player selections of this wagon
  for player_index,selection in pairs(storage.player_selection) do
    if selection.wagon and (not selection.wagon.valid or selection.wagon.unit_number == unit_number) then
      clearSelection(player_index, flags)
    end
  end
end

function deleteWagon(unit_number)
  if storage.wagon_data[unit_number] and storage.wagon_data[unit_number].vehicle and storage.wagon_data[unit_number].vehicle.valid then
    storage.wagon_data[unit_number].vehicle.destroy()
  end
  storage.wagon_data[unit_number] = nil
  clearWagon(unit_number)
end

function clearVehicle(vehicle_unit_number, flags)
  flags = flags or {}
  -- Clear selection and halt pending actions that involve this vehicle
  for unit_number,action in pairs(storage.action_queue) do
    if action.vehicle_unit_number == vehicle_unit_number then
      -- Clear beam if any
      if action.beam then
        action.beam.destroy()
      end
      local player = game.players[storage.action_queue[unit_number].player_index]
      storage.action_queue[unit_number] = nil
    end
  end
  -- Clear player selections of this vehicle
  for player_index,selection in pairs(storage.player_selection) do
    if selection.vehicle_unit_number == vehicle_unit_number then
      clearSelection(player_index, flags)
    end
  end
end


--== ON_PLAYER_SELECTED_AREA ==--
-- Queues load/unload data when player clicks with the winch.
script.on_event(defines.events.on_player_selected_area, require("script.OnPlayerSelectedArea"))


--== ON_PLAYER_CURSOR_STACK_CHANGED ==--
-- When player stops holding winch, clear selections
function OnPlayerCursorStackChanged(event)
  local index = event.player_index
  local player = game.players[index]
  local stack = player.cursor_stack
  if not (stack and stack.valid and stack.valid_for_read and stack.name == "winch-tool") then
    if storage.player_selection[index] then
      clearSelection(index, {sound=false})
    end
  end
end
script.on_event(defines.events.on_player_cursor_stack_changed, OnPlayerCursorStackChanged)

--== SPIDERTRON REMOTE CODE ==--
function OnPlayerUsedSpidertronRemote(event)
  local player = game.players[event.player_index]
  local spiders = player.spidertron_remote_selection
  -- Check if any of the spiders are targeting a vehicle wagon
  if spiders and next(spiders) then
    for _,spider in pairs(spiders) do
      local target = spider.follow_target
      local loaded_name = storage.vehicleMap[spider.name]
      if loaded_name and target and target.name == "vehicle-wagon" and not storage.action_queue[target.unit_number] then
        -- Make sure this spider gets as close as possible
        spider.follow_offset = {0,0}
        -- Add a pending loading command for this wagon
        storage.action_queue[target.unit_number] = {
                player_index = event.player_index,
                status = "spider-load",
                wagon = target,
                wagon_unit_number = target.unit_number,
                vehicle = spider,
                vehicle_unit_number = spider.unit_number,
                tick = game.tick + SPIDER_CHECK_TIME,
                name = loaded_name
            }
        script.register_on_object_destroyed(target)
        updateOnTickStatus(true)
      end
    end
  end
end
script.on_event(defines.events.on_player_used_spidertron_remote, OnPlayerUsedSpidertronRemote)

--== ON_PICKED_UP_ITEM ==--
-- When player picks up an item, change loaded wagons to empty wagons.
function OnPickedUpItem(event)
  if storage.loadedWagonMap[event.item_stack.name] then
    game.players[event.player_index].remove_item(event.item_stack)
    game.players[event.player_index].insert({name="vehicle-wagon", count=event.item_stack.count})
  end
end
script.on_event(defines.events.on_picked_up_item, OnPickedUpItem)



--== ON_MARKED_FOR_DECONSTRUCTION ==--
-- When a wagon is marked for deconstruction, cancel any pending actions to load or unload
-- FILTER = LoadedWagon, EmptyWagon, Car, Spidertron
function OnMarkedForDeconstruction(event)
  local entity = event.entity
  -- Delete any player selections or load/unload actions associated with this wagon
  if entity.name == "vehicle-wagon" or storage.loadedWagonMap[entity.name] then
    clearWagon(entity.unit_number)
  elseif (entity.type == "car" or entity.type == "spider-vehicle") then
    clearVehicle(entity.unit_number)
  end
end


--== ON_BUILT_ENTITY ==--
--== SCRIPT_RAISED_BUILT ==--
-- When a loaded-wagon ghost is created, replace it with unloaded wagon ghost
-- FILTER = GhostLoadedWagon
function OnBuiltEntity(event)
  local entity = event.entity
  if entity.name == "entity-ghost" then
    if storage.loadedWagonMap[entity.ghost_name] then
      local surface = entity.surface
      local newGhost = {
          name = "entity-ghost",
          inner_name = storage.loadedWagonMap[entity.ghost_name],
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
  else
    -- Loading ramp handler
    OnRampOrStraightRailCreated(event)
  end
end


--== ON_OBJECT_DESTROYED ==--
-- This event fires some time after an entity is destroyed.  The entity probably no longer exists.
-- This will work for empty wagons and vehicles, where all we need to do is cancel ongoing GUI stuff.
-- This will work for loaded wagons because all we have to do is destroy the loaded vehicle.
-- REGISTER = Every LoadedWagon when created, and Any (EmptyWagon, Car, Spidertron) when it becomes part of a loading/unloading operation
function OnObjectDestroyed(event)
  if event.type == defines.target_type.entity then
    local unit_number = event.useful_id
    if storage.wagon_data[unit_number] then
      -- Loaded wagon died, its vehicle is unrecoverable (if it wasn't already cloned)
      -- Also clear selection data for this wagon
      if storage.wagon_data[unit_number].cloned then
        -- This entity was cloned, probably by Space Exploration, so we don't need to make a message about it
        storage.wagon_data[unit_number].cloned = nil
      else
        -- Entity not cloned, so the vehicle was lost
        local vehicle_name = storage.wagon_data[unit_number].name
        if prototypes.entity[vehicle_name] then
          game.print{"vehicle-wagon2.wagon-destroyed", "#"..unit_number.." ", prototypes.entity[vehicle_name].localised_name}
        else
          game.print{"vehicle-wagon2.wagon-destroyed", "#"..unit_number.." ", vehicle_name}
        end
      end

      deleteWagon(unit_number)

    -- See if it's a loading ramp, and if not assume it's a vehicle
    elseif not OnLoadingRampOrRailDestroyed(event) then
      -- Not a loading ramp/rail
      -- Don't know if it was a car or a wagon, so try both.  These lists are pretty short.
      clearWagon(unit_number)
      clearVehicle(unit_number, {silent=true})
    end

  -- Purge train from tables by ID number
  elseif event.type == defines.target_type.train then
    purgeTrain(event.useful_id)
  end
end


--== ON_ENTITY_CLONED ==--
-- When a loaded wagon is cloned, clone its vehicle and data.
-- FILTER = LoadedWagon
function OnEntityCloned(event)
  local source = event.source
  local destination = event.destination

  if storage.loadedWagonMap[source.name] then
    if storage.wagon_data[source.unit_number] then
      local source_data = storage.wagon_data[source.unit_number]
      local source_vehicle = source_data.vehicle

      -- Copy the data table for the cloned entity
      local dest_data = table.deepcopy(source_data)
      dest_data.wagon = destination

      -- Clone the vehicle on the hidden surface (this assumes success)
      local destsurface = getHiddenSurface()
      local destposition = getTeleportCoordinate()
      dest_data.vehicle = source_vehicle.clone{position=destposition, surface=destsurface, create_build_effect_smoke=false}

      -- Store a flag saying the old data was cloned
      storage.wagon_data[source.unit_number].cloned = true
      storage.wagon_data[destination.unit_number] = dest_data

      -- Register the cloned wagon for destruction event
      script.register_on_object_destroyed(destination)
    end
  else
    OnRampOrStraightRailCreated(event)
  end
end


--== ON_PLAYER_DRIVING_CHANGED_STATE ==--
function OnPlayerDrivingChangedState(event)
  -- Eject player from unloaded wagon
  -- Cancel selections/actions when player enters selected vehicle or wagon
  local player = game.players[event.player_index]
  if player.vehicle then
    local vehicle = player.vehicle
    if vehicle.name == "vehicle-wagon" then
      player.driving = false
    elseif storage.loadedWagonMap[vehicle.name] then
      clearWagon(vehicle.unit_number, {silent=true, sound=true})
    elseif (vehicle.type == "car" or vehicle.type == "spider-vehicle") then
      clearVehicle(vehicle, {silent=true, sound=true})
    end
  end

end
script.on_event(defines.events.on_player_driving_changed_state, OnPlayerDrivingChangedState)

function OnPlayerOpenedGui(event)
  -- If player opens GUI of a vehicle wagon, prevent them from seeing the inventory screen
  if event.entity and (event.entity.name == "vehicle-wagon" or storage.loadedWagonMap[event.entity.name]) then
    game.players[event.player_index].opened = nil
    if event.entity.grid then
      game.players[event.player_index].opened = event.entity.grid
    end
  end
end
script.on_event(defines.events.on_gui_opened, OnPlayerOpenedGui)


------------------------- BLUEPRINT HANDLING ---------------------------------------

--== ON_PLAYER_CONFIGURED_BLUEPRINT ==--
-- ID 70, fires when you select a blueprint to place
--== ON_PLAYER_SETUP_BLUEPRINT ==--
-- ID 68, fires when you select an area to make a blueprint or copy
-- Force Blueprints to only store empty vehicle wagons
script.on_event({defines.events.on_player_setup_blueprint, defines.events.on_player_configured_blueprint},
                function(event) blueprintLib.mapBlueprint(event, storage.loadedWagonMap) end)

--------------------------------------
-- REMOTE MOD INTERFACES
remote.add_interface('VehicleWagon2', {

  --~ -- GCKI COMPATIBILITY
  --~ -- Removes this player as "owner" of any loaded vehicles.  Called when this player claims a different vehicle.
  --~ release_owned_by_player = release_owned_by_player,
  -- RENAI TRANSPORTATION COMPATIBILITY
  -- Returns the storage.wagon_data for the given LuaEntity
  get_wagon_data = get_wagon_data,
  -- Sets the storage.wagon_data for the given LuaEntity to the given Lua table, and creates icons
  set_wagon_data = set_wagon_data,
  -- Provides the error message from a destroyed wagon
  kill_wagon_data = kill_wagon_data
  }
)



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
    for v, data in pairs(storage) do
      print_game(v, ": ", data)
    end
  elseif cmd == "dumplog" then
    for v, data in pairs(storage) do
      print_file(v, ": ", data)
    end
    print_game("Dump written to log file")
  end
end
commands.add_command("vehicle-wagon-debug", {"command-help.vehicle-wagon-debug"}, cmd_debug)

do
  -- luacheck: no unused (Inline option for luacheck: ignore unused vars in block)

  local allowed_vars = {
    data = true,
    game = true,
    mods = true,
  }

------------------------------------------------------------------------------------
--                    FIND LOCAL VARIABLES THAT ARE USED GLOBALLY                 --
--                              (Thanks to eradicator!)                           --
------------------------------------------------------------------------------------
  setmetatable(_ENV, {
    __newindex  = function(self, key, value)    -- locked_global_write
      error('\n\n[ER Global Lock] Forbidden global *write*:\n' ..
            serpent.line({key = key or '<nil>', value = value or '<nil>'})..'\n')
    end,
    __index     = function(self, key)           -- locked_global_read
      if not allowed_vars[key] then
        error('\n\n[ER Global Lock] Forbidden global *read*:\n' ..
            serpent.line({key = key or '<nil>'})..'\n')
      end
    end
  })
end

if script.active_mods["gvv"] then require("__gvv__.gvv")() end
