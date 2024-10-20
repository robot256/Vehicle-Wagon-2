--[[ Copyright (c) 2024 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: loadingRamp.lua
 * Description: Logic for controlling the automatic loading and unloading process.
 * Required to keep track of all the loading ramp entities, and trains stopped at train stops
 * that might be able to automatically load or unload a vehicle wagon.
 *
 * Notes: Loading ramps are 3x3 entities. They can only have 1 loading rail and up to 2 unloading rails.
 * 
 * Data structure:
 * storage.loading_ramps: Dict(unit_number) -> {ramp=LuaEntity, chest=LuaEntity, loading_rail=LuaEntity, unloading_rail_index=unit_number, unloading_rails=Array[{rail=LuaEntity, dir_to_rail=defines.direction}]
 *     --> Stores all the loading ramp entities and their adjacent rails and chests
 * storage.loading_rails: Dict(unit_number) -> Dict(unit_number) -> LuaEntity
 *     --> Stores all the rails that have adjacent loading ramps pointed toward the rail (could be more than one per rail entity)
 * storage.unloading_rails: Dict(unit_number) -> Dict(unit_number) -> LuaEntity
 *     --> Stores all the rails that have adjacent loading ramps pointed away from the rail (could be more than one ramp per rail entity)
 * storage.active_ramps: Dict(unit_number) -> {ramp=LuaEntity, rail=LuaEntity, train=LuaTrain, wagon=LuaEntity}
 *     --> Stores all the ramps that are currently active: they have a loading/unloading candidate wagon stopped next to them.
 *         This is the list that gets polled to see when circuit conditions are met or a loadable vehicle comes within range.
 * storage.stopped_trains: Dict(train_id) -> {train=LuaTrain, ramps=Dict(unit_number)->LuaEntity}
 *     --> Stores all the trains with vehicle wagons that are currently stopped at train stops, and the active loading_ramps adjacent to
 *         vehicle wagons in the train, if any.
 *
 * Ramps consist of a Loading Ramp inserter entity and a Dummy Chest entity.
 * The dummy chest has to "capture" the inserter pickup_target so that it doesn't grab actual items from vehicles/wagons.
 * The dummy chest and pickup_position have to move together so the pickup alt-icon shows the correct location
 * (either the wagon on the track or the center of the loading ramp)
 * The drop_position has to change to indicate either the track or the three cardinal directions pointing away from the track.
 * The unloaded vehicle will be placed in the center of the loading ramp with that orientation.
 
--]]

local math2d = require("math2d")


local DISTANCE_RAMP_TO_RAIL = 2.5
local DISTANCE_RAIL_TARGET = 2.1
local DISTANCE_GROUND_TARGET = 0.5



function InitLoadingRampData()
  storage.loading_ramps = {}
  storage.loading_rails = {}
  storage.unloading_rails = {}
  storage.active_ramps = {}
  storage.stopped_trains = {}
end

local function setRampVectors(ramp)
  local unit_number = ramp.unit_number
  local ramp_entry = storage.loading_ramps[unit_number]
  
  -- Loading takes priority (if you're dumb enough to place this at the intersection of two perpendicular rails)
  if ramp_entry.loading_rail then
    -- This ramp is a loading ramp, so drop it in front of the ramp on the rail
    ramp.drop_position = math2d.position.add(ramp.position, math2d.position.multiply_scalar(util.direction_vectors[ramp.direction], DISTANCE_RAIL_TARGET))
    -- Pickup position will be opposite the rail inside the ramp
    ramp.pickup_position = math2d.position.add(ramp.position, math2d.position.multiply_scalar(util.direction_vectors[ramp.direction], -DISTANCE_GROUND_TARGET))
    ramp_entry.unloading_rail_index  = nil
  
  elseif ramp_entry.unloading_rails and next(ramp_entry.unloading_rails) then
    if not ramp_entry.unloading_rail_index or not ramp_entry.unloading_rails[ramp_entry.unloading_rail_index] then
      ramp_entry.unloading_rail_index = next(ramp_entry.unloading_rails)
    end
    local unloading_rail = ramp_entry.unloading_rails[ramp_entry.unloading_rail_index]
    local dir_to_rail = unloading_rail.dir_to_rail
    -- This ramp is an unloading ramp, so drop it on the ramp in the ramp's direction
    ramp.drop_position = math2d.position.add(ramp.position, math2d.position.multiply_scalar(util.direction_vectors[ramp.direction], DISTANCE_GROUND_TARGET))
    -- Pickup position will be on the rail, whichever direction it is
    ramp.pickup_position = math2d.position.add(ramp.position, math2d.position.multiply_scalar(util.direction_vectors[dir_to_rail], DISTANCE_RAIL_TARGET))
  
  else
    -- Set vectors for detached ramp, set both inside the ramp
    ramp.drop_position = math2d.position.add(ramp.position, math2d.position.multiply_scalar(util.direction_vectors[ramp.direction], DISTANCE_GROUND_TARGET))
    ramp.pickup_position = math2d.position.add(ramp.position, math2d.position.multiply_scalar(util.direction_vectors[ramp.direction], -DISTANCE_GROUND_TARGET))
    ramp_entry.unloading_rail_index  = nil
  end
  
  -- Move or create the chest at the pickup position
  if ramp_entry.chest then
    ramp_entry.chest.teleport(ramp.pickup_position)
  else
    ramp_entry.chest = ramp.surface.create_entity{name="vw-dummy-chest", force=ramp.force, position=ramp.pickup_position}
  end
  -- Set the inserter target to the chest
  ramp.pickup_target = ramp_entry.chest
end


local function addRailToRamp(ramp, rail)
  -- Determine if the ramp is loading or unloading the rail
  local ramp_unit_number = ramp.unit_number
  local rail_unit_number = rail.unit_number
  
  local vec_to_rail = math2d.position.subtract(rail.position, ramp.position)
  local dir_to_rail
  if vec_to_rail.y == -DISTANCE_RAMP_TO_RAIL and math.abs(vec_to_rail.x) <= 0.5 then
    dir_to_rail = defines.direction.north
  elseif vec_to_rail.x == DISTANCE_RAMP_TO_RAIL and math.abs(vec_to_rail.y) <= 0.5 then
    dir_to_rail = defines.direction.east
  elseif vec_to_rail.y == DISTANCE_RAMP_TO_RAIL and math.abs(vec_to_rail.x) <= 0.5 then
    dir_to_rail = defines.direction.south
  elseif vec_to_rail.x == -DISTANCE_RAMP_TO_RAIL and math.abs(vec_to_rail.y) <= 0.5 then
    dir_to_rail = defines.direction.west
  else
    -- rail is not adjacent to ramp at all
    game.print("["..tostring(ramp_unit_number).."] Could not add rail at vector "..util.positiontostr(vec_to_rail))
    return false
  end
  
  local ramp_entry = storage.loading_ramps[ramp_unit_number]
  
  -- Determine loading/unloading based on relative direction of rail
  if dir_to_rail == ramp.direction then
    -- This ramp is loading this rail
    ramp_entry.loading_rail = rail
    game.print("["..tostring(ramp_unit_number).."] Adding loading rail to the "..helpers.direction_to_string(dir_to_rail).." at vector "..util.positiontostr(vec_to_rail))
    -- Add to list of rails also
    storage.loading_rails[rail_unit_number] = storage.loading_rails[rail_unit_number] or {}
    storage.loading_rails[rail_unit_number][ramp_unit_number] = ramp
  else
    -- This ramp is unloading this rail
    ramp_entry.unloading_rails = ramp_entry.unloading_rails or {}
    ramp_entry.unloading_rails[rail_unit_number] = {rail=rail, dir_to_rail=dir_to_rail}
    game.print("["..tostring(ramp_unit_number).."] Adding unloading rail to the "..helpers.direction_to_string(dir_to_rail).." at vector "..util.positiontostr(vec_to_rail))
    -- Add to list of rails also
    storage.unloading_rails[rail_unit_number] = storage.unloading_rails[rail_unit_number] or {}
    storage.unloading_rails[rail_unit_number][ramp_unit_number] = ramp
  end
  
  -- Register the rail
  script.register_on_object_destroyed(rail)
  return true
end

function OnRampRotatedOrFlipped(event)
  -- When a ramp is rotated or flipped, the rails attached to it don't change, but they might change from loading to unloading or vice versa
  local ramp = event.entity
  local new_ramp_dir = ramp.direction
  local old_ramp_dir = event.previous_direction
  -- If it was a flip, we need to figure out the previous direction ourselves
  if event.name == defines.events.on_player_flipped_entity then
    if (event.horizontal and (new_ramp_dir == defines.direction.north or new_ramp_dir == defines.direction.south)) or
       (not event.horizontal and (new_ramp_dir == defines.direction.east or new_ramp_dir == defines.direction.west)) then
      -- The flip was in our axis of symmetry, so we need to undo the change in pickup vector and exit
      setRampVectors(ramp)
      return
    else
      -- Flip had an effect
      old_ramp_dir = util.oppositedirection(new_ramp_dir)
    end
  end
  
  if old_ramp_dir == new_ramp_dir then
    -- Don't need to do anything if this was an inconsequential flip
    return
  end
  
  local ramp_unit_number = ramp.unit_number
  local ramp_entry = storage.loading_ramps[ramp_unit_number]
  
  -- Check if we're allowed to rotate yet
  if event.name == defines.events.on_player_rotated_entity then
    -- If we are an unloading ramp and not at the end of the unloading_rails list, then can't rotate
    if ramp_entry.unloading_rail_index and next(ramp_entry.unloading_rails, ramp_entry.unloading_rail_index) then
      ramp_entry.unloading_rail_index = next(ramp_entry.unloading_rails, ramp_entry.unloading_rail_index)
      ramp.direction = old_ramp_dir
      -- Didn't rotate, but did 
      setRampVectors(ramp)
      return
    end
  end
  
  
  local new_loading_rail
  local new_unloading_rails = {}
  
  -- Move loading rail (always changes if ramp changed direction)
  if ramp_entry.loading_rail then
    -- Old loading rail was in direction old_ramp_dir
    -- Now it is an unloading rail in that direction
    local rail = ramp_entry.loading_rail
    local rail_unit_number = rail.unit_number
    new_unloading_rails[rail_unit_number] = {rail=rail, dir_to_rail=old_ramp_dir}
    storage.loading_rails[rail_unit_number][ramp_unit_number] = nil
    if not next(storage.loading_rails[rail_unit_number]) then
      storage.loading_rails[rail_unit_number] = nil
    end
    storage.unloading_rails[rail_unit_number] = storage.unloading_rails[rail_unit_number] or {}
    storage.unloading_rails[rail_unit_number][ramp_unit_number] = ramp
  end
  
  -- Check if any unloading rails changed to loading rail
  if ramp_entry.unloading_rails then
    for rail_unit_number, rail_entry in pairs(ramp_entry.unloading_rails) do
      if rail_entry.dir_to_rail == new_ramp_dir then
        -- This one is in the new direction, move it to the other list
        new_loading_rail = rail_entry.rail
        -- Move it to the loading list
        storage.unloading_rails[rail_unit_number][ramp_unit_number] = nil
        if not next(storage.unloading_rails[rail_unit_number]) then
          storage.unloading_rails[rail_unit_number] = nil
        end
        storage.loading_rails[rail_unit_number] = storage.unloading_rails[rail_unit_number] or {}
        storage.loading_rails[rail_unit_number][ramp_unit_number] = ramp
      else
        -- Still an unloading rail
        new_unloading_rails[rail_unit_number] = rail_entry
      end
    end
  end
  
  -- Overwrite the ramp entry with the rearranged lists of rails
  ramp_entry.loading_rail = new_loading_rail
  ramp_entry.unloading_rails = new_unloading_rails
  ramp_entry.unloading_rail_index = nil
  
  -- Update vectors since something must have changed
  setRampVectors(ramp)
end
script.on_event({defines.events.on_player_rotated_entity, defines.events.on_player_flipped_entity}, OnRampRotatedOrFlipped)


function OnRampOrStraightRailCreated(event)
  local entity = event.entity
  local surface = entity.surface
  local surface_index = surface.index
  local position = entity.position
  local direction = entity.direction
  local unit_number = entity.unit_number
  if entity.name == "loading-ramp" then
    local ramp = entity
    -- Create the entry for this ramp
    storage.loading_rails = storage.loading_rails or {}
    storage.unloading_rails = storage.unloading_rails or {}
    storage.loading_ramps = storage.loading_ramps or {}
    storage.loading_ramps[unit_number] = {ramp=ramp}
    
    -- Find nearby straight rails, if any, and establish if this is a loading, unloading, or detached ramp
    local rails = surface.find_entities_filtered{type={"straight-rail", "legacy-straight-rail"}, area=math2d.bounding_box.create_from_centre(position, 2*DISTANCE_RAMP_TO_RAIL)}
    for _,rail in pairs(rails) do
      addRailToRamp(ramp, rail)
    end
    
    -- Set the pickup and drop vectors, and create the dummy chest
    setRampVectors(ramp)
    
    -- Register the ramp entity
    script.register_on_object_destroyed(ramp)
    
    local ramp_entry = storage.loading_ramps[unit_number]
    if ramp_entry.loading_rail or (ramp_entry.unloading_rails and next(ramp_entry.unloading_rails)) then
      -- This ramp is attached to at least one rail
      -- TODO: Search for trains already stopped on this rail to become active
      
    end
    
    
  -- elseif entity.type == "straight-rail" or entity.type == "legacy-straight-rail" then
    -- -- See if there are any loading ramps on either side of this rail
    -- -- Rail direction can only be north {0,-1} or east {1,0}
    -- -- Instead of searching the surface for every single rail placed, look through our lists of ramps on this surface only
    -- local ramp_pos1, ramp_pos2
    -- if direction == defines.direction.north then
      -- ramp_pos1 = {x=position.x-2, y=position.y}
      -- ramp_pos2 = {x=position.x+2, y=position.y}
    -- else
      -- ramp_pos1 = {x=position.x, y=position.y-2}
      -- ramp_pos2 = {x=position.x, y=position.y+2}
    -- end
    -- if storage.loading_ramps[surface_index] then
      -- for uid,data in pairs(storage.loading_ramps[surface_index]) do
        -- local ramp = data.ramp
        -- local ramp_pos = ramp.position
        -- if (ramp_pos.x == ramp_pos1.x and ramp_pos.y == ramp_pos1.y) or
           -- (ramp_pos.x == ramp_pos2.x and ramp_pos.y == ramp_pos2.y) then
          -- -- This ramp is adjacent to this rail
          -- -- Add it to the ramp's lists of rails
          
        -- end
      -- end
    -- end
    -- if storage.detached_ramps[surface_index] then
      -- for uid,ramp in pairs(storage.detached_ramps[surface_index]) do
        -- local ramp_pos = ramp.position
        -- if (ramp_pos.x == ramp_pos1.x and ramp_pos.y == ramp_pos1.y) or
           -- (ramp_pos.x == ramp_pos2.x and ramp_pos.y == ramp_pos2.y) then
          -- -- This ramp is adjacent to this rail
          -- -- Add it to the ramp's lists of rails
          
        -- end
      -- end
    -- end
    
  end
end


function OnLoadingRampOrRailDestroyed(event)
  if event.type == defines.target_type.entity then
    local unit_number = event.useful_id
    -- Purge this ramp from all the lists
    -- First check if it's a loading ramp
    local ramp_entry = storage.loading_ramps[unit_number]
    --log("Deleting ramp:")
    --log(serpent.block(ramp_entry))
    if ramp_entry then
      if ramp_entry.chest then
        ramp_entry.chest.destroy()
      end
      if ramp_entry.loading_rail then
        local rid = ramp_entry.loading_rail.unit_number
        storage.loading_rails[rid][unit_number] = nil
        if not next(storage.loading_rails[rid]) then
          storage.loading_rails[rid] = nil
        end
      end
      if ramp_entry.unloading_rails then
        for rail_id,_ in pairs(ramp_entry.unloading_rails) do
          storage.unloading_rails[rail_id][unit_number] = nil
          if not next(storage.unloading_rails[rail_id]) then
            storage.unloading_rails[rail_id] = nil
          end
        end
      end
      storage.loading_ramps[unit_number] = nil
      return true
    
    else
      -- Not a ramp, check if it's a rail for any ramps
      local found = false
      local rail_entry = storage.loading_rails[unit_number]
      if rail_entry then
        found = true
        for ramp_id,ramp in pairs(rail_entry) do
          storage.loading_ramps[ramp_id].loading_rail = nil
          setRampVectors(ramp)
        end
      end
      -- Now check if it's an unloading rail for any ramps
      local rail_entry = storage.unloading_rails[unit_number]
      if rail_entry then
        found = true
        for ramp_id,ramp in pairs(rail_entry) do
          local ramp_entry = storage.loading_ramps[ramp_id]
          ramp_entry.unloading_rails[unit_number] = nil
          if not next(ramp_entry.unloading_rails) then
            ramp_entry.unloading_rails = nil
          end
          setRampVectors(ramp)
        end
      end
      
      return found  -- return true if this entity was one we could handle
    end
  end
end
