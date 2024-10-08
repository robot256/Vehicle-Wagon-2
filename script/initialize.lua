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
  local unminable_enabled = (game.active_mods["unminable-vehicles"]) or (game.active_mods["UnminableVehicles"] and settings.global["unminable_vehicles_make_unminable"].value)
  if global.unminable_enabled then
    game.print({"vehicle-wagon2.enabled-unminable-vehicles"})
  else
    game.print({"vehicle-wagon2.disabled-unminable-vehicles"})
  end
  return unminable_enabled
end


-- Runs when new game starts
function OnInit()
  -- Generate wagon-vehicle mapping tables
  makeGlobalMaps()
  -- Create global data tables
  makeGlobalTables()
  -- Check mod and seting state for unminable-ness
  global.unminable_enabled = getUnminableStatus()
end


function OnConfigurationChanged(event)
log("Entered function OnConfigurationChanged("..serpent.line(event)..")")
  -- Migrations run before on_configuration_changed.
  -- Data structure should already be 2.x.3.

  -- Regenerate maps with any new prototypes.
  makeGlobalMaps()

  -- Purge data for any entities that were removed
  -- Migration should already have added "wagon" entity reference to each valid entry
  for id,data in pairs(global.wagon_data) do
    if not data.wagon or not data.wagon.valid then
      game.print{"vehicle-wagon2.migrate-prototype-error",id,data.name}
      global.wagon_data[id] = nil
    end
  end

  local gcki_enabled = game.active_mods["GCKI"] and settings.global["vehicle-wagon-use-GCKI-permissions"].value
  local unminable_enabled = getUnminableStatus()

  -- Run when GCKI is uninstalled:
  if event.mod_changes["GCKI"] and event.mod_changes["GCKI"].new_version == nil then
    -- Make sure all loaded wagons are minable, if they had been carrying locked GCKI vehicles
    if not unminable_enabled then
      for _,surface in pairs(game.surfaces) do
        for _,entity in pairs(surface.find_entities_filtered{name=global.loadedWagonList}) do
          entity.minable = true
        end
      end
    end
    -- Make sure all loaded vehicles are stored as minable, clear GCKI data
    for id, data in pairs(global.wagon_data) do
      -- Vehicle had been owned and/or locked, which might make it unminable. If no other mod cares, make it minable again
      if not unminable_enabled then
        data.minable = nil
      end
      -- Vehicle had been locked, which makes it inoperable. Restore operability
      if data.GCKI_data and data.GCKI_data.locker then
        data.operable = nil
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
    for id, data in pairs(global.wagon_data) do
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
  if global.unminable_enabled ~= unminable_enabled then
    for id, data in pairs(global.wagon_data) do
      -- Make unminable whenever setting is checked
      -- Only make minable again if GCKI lock state is not engaged
      if unminable_enabled then
        -- Mod forces all loaded vehicles to be unminable
        data.minable = false
      elseif not (gcki_enabled and data.GCKI_data and (data.GCKI_data.locker or data.GCKI_data.owner)) then
        -- Mod no longer forces loaded vehicles to be unminable. If locked vehicle is unlocked and unowned, make it minable.
        data.minable = nil
      end
    end
    -- Store new value in global
    global.unminable_enabled = unminable_enabled
  end

end

function OnRuntimeModSettingChanged(event)

  local gcki_enabled = game.active_mods["GCKI"] and settings.global["vehicle-wagon-use-GCKI-permissions"].value
  local unminable_enabled = getUnminableStatus()

  -- Reset minable state when GCKI setting changes
  if event.setting == "vehicle-wagon-use-GCKI-permissions" then
    for id,data in pairs(global.wagon_data) do
      -- Double-check GCKI-controlled lock state.
      -- Reset all wagons if GCKI permissions are disabled or GCKI is uninstalled.
      -- If UnminableVehicles is enabled, don't set to true
      if (gcki_enabled and data.GCKI_data and (data.GCKI_data.owner or data.GCKI_data.locker))  then
        if data.wagon and data.wagon.valid then
          data.wagon.minable = false
        end
        data.minable = false
      else
        -- GCKI not being respected, if no other unminable mod, then make vehicles minable
        if not unminable_enabled then
          if data.wagon and data.wagon.valid then
            data.wagon.minable = true
          end
          data.minable = nil
        end
        -- GCKI not being respected, make loaded vehicles operable
        data.operable = nil
      end
    end
  end

  -- Update loaded vehicle state in response to Unminable Vehicles setting
  if global.unminable_enabled ~= unminable_enabled then
    for id, data in pairs(global.wagon_data) do
      -- Make unminable whenever setting is checked
      -- Only make minable again if GCKI lock state is not engaged
      if unminable_enabled then
        data.minable = false
      elseif not (gcki_enabled and data.GCKI_data and (data.GCKI_data.locker or data.GCKI_data.owner)) then
        data.minable = nil
      end
    end
    -- Store new value in global
    global.unminable_enabled = unminable_enabled
  end

end
