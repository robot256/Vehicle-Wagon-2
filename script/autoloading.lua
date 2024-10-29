--[[ Copyright (c) 2024 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: autoloading.lua
 * Description: Logic for tracking trains and performing automated loading and unloading at loading ramps.
 * Required to keep track of all trains stopped at train stops that might be able to automatically load or unload a vehicle wagon.
 *
 * Notes: Loading ramps are 3x3 entities. They can only have 1 loading rail and up to 2 unloading rails.
 * 
 * Data structure:
 * storage.loading_ramps: Dict[ramp_unit_number]->{ ramp=LuaEntity(ramp),
                                                    surface_index=ramp_surface_index,
                                                    chest=LuaEntity(chest),
                                                    loading_rail=LuaEntity(rail),
                                                    unloading_rail_index=rail_unit_number,
                                                    unloading_rails=Dict[rail_unit_number]->{rail=LuaEntity(rail), dir_to_rail=defines.direction}
                                                  }
 *     --> Stores all the loading ramp entities and their adjacent rails and chests
 * storage.loading_rails: Dict[rail_unit_number]->Dict[ramp_unit_number]->LuaEntity(ramp)
 *     --> Stores all the rails that have adjacent loading ramps pointed toward the rail (could be more than one per rail entity)
 * storage.unloading_rails: Dict[rail_unit_number]->Dict[ramp_unit_number]->LuaEntity(ramp)
 *     --> Stores all the rails that have adjacent loading ramps pointed away from the rail (could be more than one ramp per rail entity)
 *
 * storage.active_ramps: Dict[ramp_unit_number]->{ramp=LuaEntity, rail=LuaEntity, train=LuaTrain, wagon=LuaEntity}
 *     --> Stores all the ramps that are currently active: they have a loading/unloading candidate wagon stopped next to them.
 *         This is the list that gets polled to see when circuit conditions are met or a loadable vehicle comes within range.
 * storage.stopped_trains: Dict(train_id) -> {train=LuaTrain, ramps=Dict(unit_number)->LuaEntity}
 *     --> Stores all the trains with vehicle wagons that are currently stopped at train stops, and the active loading_ramps adjacent to
 *         vehicle wagons in the train, if any.
 *
 * Vehicle is loaded if it is within range of an loading ramp at the same time as an empty wagon on a train that is stopped at station.
 * Vehicle is unloaded it the wagon is within range of an unloading ramp while it is stopped at station.  It won't work with trains in manual mode (unless this becomes a problem).
 *
 * Whenever a train stops at a station, check if it has any vehicle wagons.  If so, check if any of the vehicle wagons line up with loading ramps, and add to storage.stopped_trains and storage.active_ramps.
 
--]]

local math2d = require("math2d")

function purgeTrain(train_id)
  -- A stopped train we are tracking just started moving again
  if storage.stopped_trains[train_id] then
    if storage.stopped_trains[train_id].ramps and next(storage.stopped_trains[train_id].ramps) then
      for ramp_id,_ in pairs(storage.stopped_trains[train_id].ramps) do
        storage.active_ramps[ramp_id] = nil
      end
      updateOnTickStatus()
    end
    storage.stopped_trains[train_id] = nil
  end
end

function addLoadingRampToTrain(ramp, rail, train, wagon)
  if storage.stopped_trains[train.id] then
    local ramp_id = ramp.unit_number
    -- This ramp can load or unload this train, so add it to active_ramps
    game.print("Found that ramp "..tostring(ramp_id).." can load wagon "..tostring(wagon.unit_number).." on train "..tostring(train.id))
    storage.active_ramps[ramp_id] = {ramp=ramp, rail=rail, train=train, wagon=wagon, loading=true}
    storage.stopped_trains[train.id].ramps[ramp_id] = ramp
    updateOnTickStatus(true)
  end
end

function addUnloadingRampToTrain(ramp, rail, train, wagon)
  if storage.stopped_trains[train.id] then
    local ramp_id = ramp.unit_number
    -- This ramp can load or unload this train, so add it to active_ramps
    game.print("Found that ramp "..tostring(ramp_id).." can unload wagon "..tostring(wagon.unit_number).." on train "..tostring(train.id))
    storage.active_ramps[ramp_id] = {ramp=ramp, rail=rail, train=train, wagon=wagon, loading=false}
    storage.stopped_trains[train.id].ramps[ramp_id] = ramp
    updateOnTickStatus(true)
  end
end

local function OnTrainChangedState(event)
  local train = event.train
  if train.state == defines.train_state.wait_station then
    -- look for vehicle wagons
    local empty_wagons = {}
    local loaded_wagons = {}
    for _,wagon in pairs(train.cargo_wagons) do
      if wagon.name == "vehicle-wagon" then
        empty_wagons[wagon.unit_number] = wagon
      elseif storage.loadedWagonMap[wagon.name] then
        loaded_wagons[wagon.unit_number] = wagon
      end
    end
    local check_loading = next(empty_wagons) and true
    local check_unloading = next(loaded_wagons) and true
    if check_loading or check_unloading then
      storage.stopped_trains[train.id] = {train=train, ramps={}}
      script.register_on_object_destroyed(train)
      for _,rail in pairs(train.get_rails()) do
        if check_loading and storage.loading_rails[rail.unit_number] then
          for ramp_id,ramp in pairs(storage.loading_rails[rail.unit_number]) do
            for wagon_id,wagon in pairs(empty_wagons) do
              if math2d.bounding_box.contains_point(wagon.bounding_box, ramp.drop_position) then
                -- This wagon is in the drop zone of this ramp
                addLoadingRampToTrain(ramp, rail, train, wagon)
              end
            end
          end
        end
        if check_unloading and storage.unloading_rails[rail.unit_number] then
          for ramp_id,ramp in pairs(storage.unloading_rails[rail.unit_number]) do
            for wagon_id,wagon in pairs(loaded_wagons) do
              if math2d.bounding_box.contains_point(wagon.bounding_box, ramp.pickup_position) then
                -- This wagon is in the pickup zone of this ramp
                addUnloadingRampToTrain(ramp, rail, train, wagon)
              end
            end
          end
        end
      end
    end
  elseif storage.stopped_trains[train.id] then
    purgeTrain(train.id)
  end
end
script.on_event(defines.events.on_train_changed_state, OnTrainChangedState)


function ProcessActiveRamps()



end
