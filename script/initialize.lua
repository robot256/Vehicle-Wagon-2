--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: initialize.lua
 * Description: Event handlers for OnLoad and OnConfigurationChanged.
 *  - When Configuration Changes (mods installed, updated, or removed):
 *    1. Read all the vehicle prototypes in the game and map them to appropriate loaded wagons and filtering lists.
 *    2. Remove data referencing loaded wagons that were removed during migration or mod changes.
 *    3. Update entity data based on GCKI and any unminable vehicle  mod states.
 *  - When Game Loads (new game started):
 *    1. Read all the vehicle prototypes in the game and map them to appropriate loaded wagons and filtering lists.
 *    2. Create global data tables if they don't already exist.
 *    3. Determine if any unminable vehicles mod is installed and enabled.
 *  - When Mod Setting Changes:
 *    1. If VehicleWagon2 GCKI permission setting changes, update wagon and stored vehicle minable states.
 *    2. If UnminableVehicles "make unminable" setting changes, update stored vehicle minable states.
--]]


require("script.makeGlobalMaps")


function getUnminableStatus()
  local unminable_enabled = (script.active_mods["unminable-vehicles"]) or 
           (script.active_mods["UnminableVehicles"] and settings.global["unminable_vehicles_make_unminable"].value)
  return unminable_enabled
end


function RegisterFilteredEvents()

  --== ON_PRE_PLAYER_MINED_ITEM ==--
  -- When player mines a loaded wagon, try to unload the vehicle first
  -- If vehicle cannot be unloaded, give its contents to the player and spill the rest.
  -- If a loaded vehicle item is mined off the ground, change it to an empty wagon item.
  -- FILTER = LoadedWagon, ItemOnGround
  local mined_filters = filterLib.generateNameFilter("item-on-ground", storage.loadedWagonList)
  script.on_event(defines.events.on_pre_player_mined_item, OnPrePlayerMinedItem, mined_filters)

  --== ON_ROBOT_PRE_MINED ==--
  -- When robot tries to mine a loaded wagon, try to unload the vehicle first!
  -- If vehicle cannot be unloaded, send its contents away in the robot piece by piece.
  -- If a loaded vehicle item is mined off the ground, change it to an empty wagon item.
  -- FILTER = LoadedWagon, ItemOnGround
  script.on_event(defines.events.on_robot_pre_mined, OnRobotPreMined, mined_filters)

  
  --== ON_MARKED_FOR_DECONSTRUCTION ==--
  -- When a wagon or car is marked for deconstruction, cancel any active loading or unloading orders or player selections
  local decon_filters = filterLib.generateNameFilter(storage.loadedWagonList, "vehicle-wagon")
  table.insert(decon_filters, {filter="type", type="car", mode="or"})
  table.insert(decon_filters, {filter="type", type="spider-vehicle", mode="or"})
  script.on_event(defines.events.on_marked_for_deconstruction, OnMarkedForDeconstruction, decon_filters)
  
  --== ON_OBJECT_DESTROYED ==--
  -- Fires when registered entities are destroyed, mined, etc.
  -- We register loaded wagons, and any entity that's in the actions or player_selections queues.
  script.on_event(defines.events.on_object_destroyed, OnObjectDestroyed)

  --== ON_BUILT_ENTITY ==--
  --== SCRIPT_RAISED_BUILT ==--
  -- Detect when loaded wagons are built incorrectly by scripts and convert them to empty wagons.
  local built_filters = filterLib.generateGhostFilter(storage.loadedWagonList)
  table.insert(built_filters, {filter="name", name="vehicle-wagon"})
  table.insert(built_filters, {filter="name", name="loading-ramp"})
  table.insert(built_filters, {filter="type", type="straight-rail"})
  table.insert(built_filters, {filter="type", type="legacy-straight-rail"})
  script.on_event(defines.events.on_built_entity, OnBuiltEntity, built_filters)
  script.on_event(defines.events.on_robot_built_entity, OnBuiltEntity, built_filters)
  script.on_event(defines.events.script_raised_built, OnBuiltEntity, built_filters)

  --== ON_ENTITY_CLONED ==--
  -- When a loaded wagon is cloned, also clone the data and loaded vehicle entity.
  local cloned_filters = filterLib.generateNameFilter(storage.loadedWagonList)
  table.insert(cloned_filters, {filter="name", name="loading-ramp"})
  table.insert(cloned_filters, {filter="type", type="straight-rail"})
  table.insert(cloned_filters, {filter="type", type="legacy-straight-rail"})
  script.on_event(defines.events.on_entity_cloned, OnEntityCloned, cloned_filters)

end


-- Runs when new game starts
function OnInit()
  -- Generate wagon-vehicle mapping tables
  makeGlobalMaps()
  -- Create global data tables
  makeGlobalTables()
  -- Check mod and seting state for unminable-ness
  storage.unminable_enabled = getUnminableStatus()
end


function OnConfigurationChanged(event)
  --log("Entered function OnConfigurationChanged("..serpent.line(event)..")")
  -- Migrations run before on_configuration_changed.
  -- Data structure should already be 2.x.3.

  -- Regenerate maps with any new prototypes.
  makeGlobalMaps()

  -- Purge data for any entities that were removed
  -- Migrations should already have added "wagon" and "vehicle" entity references to each valid entry
  for id,data in pairs(storage.wagon_data) do
    if not data.wagon or not data.wagon.valid then
      log({"vehicle-wagon2.migrate-prototype-error",id,data.name})
      storage.wagon_data[id] = nil
    end
    if not data.vehicle or not data.vehicle.valid then
      log({"vehicle-wagon2.migrate-vehicle-error",id,data.name})
      storage.wagon_data[id] = nil
    end
  end

  local gcki_enabled = script.active_mods["GCKI"] and settings.global["vehicle-wagon-use-GCKI-permissions"].value
  local unminable_enabled = getUnminableStatus()

  -- Run when GCKI is uninstalled:
  if event.mod_changes["GCKI"] and event.mod_changes["GCKI"].new_version == nil then
    -- Make sure all loaded wagons are minable, if they had been carrying locked GCKI vehicles
    if not unminable_enabled then
      for _,surface in pairs(game.surfaces) do
        for _,entity in pairs(surface.find_entities_filtered{name=storage.loadedWagonList}) do
          entity.minable = true
        end
      end
    end
    -- Make sure all loaded vehicles are stored as minable, clear GCKI data
    for id, data in pairs(storage.wagon_data) do
      -- Vehicle had been locked, which makes it inoperable. Restore operability
      if data.GCKI_data and data.GCKI_data.locker then
        data.operable = true
      end
      -- Keep GCKI data if it contains a custom name and Autodrive is active, but
      -- hasn't stored the custom name
      if script.active_mods["autodrive"] and
        (data.GCKI_data and data.GCKI_data.custom_name) and
        not (data.autodrive_data and data.autodrive_data.custom_name) then
        log("Keeping GCKI data of wagon "..id)
        -- Clear the locker and owner since GCKI is not present anymore
        data.GCKI_data.locker = nil
        data.GCKI_data.owner = nil
      else
        data.GCKI_data = nil
      end
    end
  end

  -- Run when Autodrive is uninstalled:
  if event.mod_changes["autodrive"] and event.mod_changes["autodrive"].new_version == nil then
    for id, data in pairs(storage.wagon_data) do
      -- Remove Autodrive data unless it contains a custom name and GCKI is active,
      -- but hasn't stored the custom name
      if script.active_mods["GCKI"] and
        (data.autodrive_data and data.autodrive_data.custom_name) and
        not (data.GCKI_data and data.GCKI_data.custom_name) then

        log("Keeping Autodrive data of wagon "..id)
      else
        data.autodrive_data = nil
      end
    end
  end

  -- Run when unminable_enabled status changes due to mods or settings
  if storage.unminable_enabled ~= unminable_enabled then
    -- Store new value in global
    if unminable_enabled and not storage.unminable_enabled then
      game.print({"vehicle-wagon2.enabled-unminable-vehicles"})
    elseif not unminable_enabled and storage.unminable_enabled then
      game.print({"vehicle-wagon2.disabled-unminable-vehicles"})
    end
    storage.unminable_enabled = unminable_enabled
  end
  
  -- Run when inventory slots setting Changes
  local new_slots_setting = settings.startup["vehicle-wagon-inventory-slots"].value
  if not storage.slots_setting or new_slots_setting ~= storage.slots_setting then
    -- Go through and make sure everything has the right icons and inventory contents
    for uid,wagon_data in pairs(storage.wagon_data) do
      clearIcon(wagon_data)
      -- Make sure it has the right contents
      if wagon_data.wagon.insert({name=wagon_data.vehicle.name, count=1, quality=wagon_data.vehicle.quality}) ~= 1 then
        -- Put an icon on the wagon showing contents
        wagon_data.icon = renderIcon(wagon_data.wagon, wagon_data.vehicle.name)
      end
    end
    storage.slots_setting = new_slots_setting
  end

end

function OnRuntimeModSettingChanged(event)

  local gcki_enabled = script.active_mods["GCKI"] and settings.global["vehicle-wagon-use-GCKI-permissions"].value
  local unminable_enabled = getUnminableStatus()

  -- Reset minable state when GCKI setting changes
  if event.setting == "vehicle-wagon-use-GCKI-permissions" then
    for id,data in pairs(storage.wagon_data) do
      -- Double-check GCKI-controlled lock state.
      -- Reset all wagons if GCKI permissions are disabled or GCKI is uninstalled.
      -- If UnminableVehicles is enabled, don't set to true
      if (gcki_enabled and data.GCKI_data and (data.GCKI_data.owner or data.GCKI_data.locker))  then
        if data.wagon and data.wagon.valid then
          data.wagon.minable = false
        end
      else
        -- GCKI not being respected, if no other unminable mod, then make vehicles minable
        if not unminable_enabled then
          if data.wagon and data.wagon.valid then
            data.wagon.minable = true
          end
        end
        -- GCKI not being respected, make loaded vehicles operable
        data.operable = nil
      end
    end
  end

  -- Update loaded vehicle state in response to Unminable Vehicles setting
  if storage.unminable_enabled ~= unminable_enabled then
    -- Store new value in global
    if unminable_enabled and not storage.unminable_enabled then
      game.print({"vehicle-wagon2.enabled-unminable-vehicles"})
    elseif not unminable_enabled and storage.unminable_enabled then
      game.print({"vehicle-wagon2.disabled-unminable-vehicles"})
    end
    storage.unminable_enabled = unminable_enabled
  end

end
