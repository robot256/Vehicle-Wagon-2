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
 * storage.active_ramps: Dict[ramp_unit_number]->{ramp=LuaEntity, rail=LuaEntity, train=LuaTrain, wagon=LuaEntity, vehicle=(LuaEntity or nil)}
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
local OnPlayerSelectedArea = require("OnPlayerSelectedArea")

local LOADING_SEARCH_RADIUS = 2.5
local MAX_POLLING_INTERVAL = 30

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
    --game.print("Found that ramp "..tostring(ramp_id).." can load wagon "..tostring(wagon.unit_number).." on train "..tostring(train.id))
    storage.active_ramps[ramp_id] = {ramp=ramp, rail=rail, train=train, wagon=wagon, surface=wagon.surface, loading=true}
    storage.stopped_trains[train.id].ramps[ramp_id] = ramp
    updateOnTickStatus(true)
  end
end

function addUnloadingRampToTrain(ramp, rail, train, wagon, vehicle)
  if storage.stopped_trains[train.id] then
    local ramp_id = ramp.unit_number
    -- This ramp can load or unload this train, so add it to active_ramps
    --game.print("Found that ramp "..tostring(ramp_id).." can unload wagon "..tostring(wagon.unit_number).." on train "..tostring(train.id))
    storage.active_ramps[ramp_id] = {ramp=ramp, rail=rail, train=train, wagon=wagon, vehicle=vehicle, surface=wagon.surface, loading=false}
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
                addUnloadingRampToTrain(ramp, rail, train, wagon, storage.wagon_data[wagon.unit_number].vehicle)
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
script.on_event({defines.events.on_train_changed_state,defines.events.on_train_created}, OnTrainChangedState)


local function qualityComparison(left, comparator, right)
  if comparator == "=" then
    return left == right
  elseif comparator == "≠" or comparator == "!=" then
    return left ~= right
  elseif comparator == ">" then
    return left > right
  elseif comparator == "<" then
    return left < right
  elseif comparator == "≥" or comparator == ">=" then
    return left >= right
  elseif comparator == "≤" or comparator == "<=" then
    return left <= right
  else
    assert(false, "Invalid quality comparator string in loading ramp process")
  end
end

local function doesVehiclePassFilter(ramp, vehicle)
  -- Check inserter's filters
  local filter_passed = true
  if ramp.use_filters then
    if ramp.inserter_filter_mode == "whitelist" then
      filter_passed = false
      for slot_index=1, ramp.filter_slot_count do
        local filter = ramp.get_filter(slot_index)
        if filter then
          local name_passed = false
          local quality_passed = true
          if not filter.name or filter.name == vehicle.name then
            name_passed = true
          end
          if filter.quality then
            local filter_level = (type(filter.quality) == "string" and prototypes.quality[filter.quality].level) or filter.quality.level
            local vehicle_level = vehicle.quality.level
            local comparator = filter.comparator or "="
            quality_passed = qualityComparison(vehicle_level, comparator, filter_level)
          end
          if name_passed and quality_passed then
            filter_passed = true
            break
          end
        end
      end
    elseif ramp.inserter_filter_mode == "blacklist" then
      filter_passed = true
      for slot_index=1, ramp.filter_slot_count do
        local filter = ramp.get_filter(slot_index)
        if filter then
          local name_passed = false
          local quality_passed = true
          if not filter.name or filter.name == vehicle.name then
            name_passed = true
          end
          if filter.quality then
            local filter_level = (type(filter.quality) == "string" and prototypes.quality[filter.quality].level) or filter.quality.level
            local vehicle_level = vehicle.quality.level
            local comparator = filter.comparator or "="
            quality_passed = qualityComparison(vehicle_level, comparator, filter_level)
          end
          if name_passed and quality_passed then
            filter_passed = false
            break
          end
        end
      end
    end
  end
  return filter_passed
end
  

function ProcessActiveRamps()
  -- See if any active ramps can unload based on their control behavior
  for ramp_id, entry in pairs(storage.active_ramps) do
    if not entry.tick or game.tick >= entry.tick then
      if not (entry.ramp.valid and entry.wagon.valid) then
        -- This shouldn't happen if on train destroyed works correctly
        storage.active_ramps[ramp_id] = nil
      else
        -- Check this ramp's control behavior
        if entry.ramp.status == defines.entity_status.waiting_for_source_items or
           entry.ramp.status == defines.entity_status.waiting_for_train then
          
          local surface = entry.surface or entry.wagon.surface
          -- Just ignore this right now, let's unload if we can
          if entry.loading then
            -- Loading is harder, search for a vehicle
            local vehicles = surface.find_entities_filtered{name=storage.vehicleList,
                area=math2d.bounding_box.create_from_centre(entry.ramp.position, LOADING_SEARCH_RADIUS)}
            local closest
            local closest_distance = math.huge
            for _,vehicle in pairs(vehicles) do
              local distance = math2d.position.distance_squared(vehicle.position, entry.ramp.position)
              if distance < closest_distance then
                if vehicle.speed == 0 or (vehicle.type == "spider-vehicle" and vehicle.follow_target and vehicle.follow_target == entry.ramp) then
                  if doesVehiclePassFilter(entry.ramp, vehicle) then
                    closest_distance = distance
                    closest = vehicle
                  end
                end
              end
            end
            if closest then
              OnPlayerSelectedArea{
                item = "winch-tool",
                surface = surface,
                entities = {closest, entry.wagon},
                position = entry.ramp.position
              }
            else
              --game.print(tostring(game.tick).." no vehicle found for ramp "..tostring(entry.ramp.unit_number))
              entry.tick = game.tick + MAX_POLLING_INTERVAL
            end
          else
            if not entry.vehicle then
              entry.vehicle = storage.wagon_data[entry.wagon.unit_number].Vehicle
            end
            if doesVehiclePassFilter(entry.ramp, entry.vehicle) then
              -- Unloading is easy
              OnPlayerSelectedArea{
                item = "winch-tool",
                surface = surface,
                entities = {entry.wagon, entry.ramp},
                position = entry.ramp.position
              }
            else
              entry.tick = game.tick + MAX_POLLING_INTERVAL
            end
          end
        else
          entry.tick = game.tick + MAX_POLLING_INTERVAL
        end
      end
    end
  end
  updateOnTickStatus()
end
