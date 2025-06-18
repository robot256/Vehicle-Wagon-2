require("__VehicleWagon2__/script/makeGlobalMaps")

-- Fix missing entries in storage.loading_rails due to bug that was present in 4.1.8 and earlier
log("Before migration:")
log("loading_rails=\n"..serpent.block(storage.loading_rails))
log("unloading_rails=\n"..serpent.block(storage.unloading_rails))
if storage.loading_ramps then
  storage.loading_rails = {}
  storage.unloading_rails = {}
  for ramp_unit_number, entry in pairs(storage.loading_ramps) do
    local ramp = entry.ramp
    if entry.loading_rail then
      local rail_unit_number = entry.loading_rail.unit_number
      log("Ramp "..tostring(ramp_unit_number).." has a loading rail "..tostring(rail_unit_number))
      storage.loading_rails[rail_unit_number] = storage.loading_rails[rail_unit_number] or {}
      storage.loading_rails[rail_unit_number][ramp_unit_number] = ramp
    end
    if entry.unloading_rails then
      log("Ramp "..tostring(ramp_unit_number).." has "..tostring(table_size(entry.unloading_rails)).." unloading rails.")
      for rail_unit_number,_ in pairs(entry.unloading_rails) do
        log("Ramp "..tostring(ramp_unit_number).." has a unloading rail "..tostring(rail_unit_number))
        storage.unloading_rails[rail_unit_number] = storage.unloading_rails[rail_unit_number] or {}
        storage.unloading_rails[rail_unit_number][ramp_unit_number] = ramp
      end
    end
  end
end
log("After migration:")
log("loading_rails=\n"..serpent.block(storage.loading_rails))
log("unloading_rails=\n"..serpent.block(storage.unloading_rails))

-- Find existing manual trains
storage.manual_trains = storage.manual_trains or {}
local wagon_list = table.deepcopy(storage.loadedWagonList)
table.insert(wagon_list, "vehicle-wagon")
for _,train in pairs(game.train_manager.get_trains{is_manual=true, stock=wagon_list}) do
  storage.manual_trains[train.id] = {train=train, ramps={}}
  script.register_on_object_destroyed(train)
end

-- Delete unreferenced rendering objects
local all_objects = rendering.get_all_objects("VehicleWagon2")
if all_objects and #all_objects > 0 then
  -- Get list of all the objects we know about
  local known_objects = {}
  for player_index, entry in pairs(storage.player_selection) do
    if entry.visuals then
      for k=1,#entry.visuals do
        table.insert(known_objects, entry.visuals[k])
      end
    end
  end
  for wagon_number, wagon_data in pairs(storage.wagon_data) do
    if wagon_data.icon then
      for k=1,#wagon_data.icon do
        table.insert(known_objects, wagon_data.icon[k])
      end
    end
  end
  -- Find which are unknown
  local unknown_objects
  if #known_objects==0 then
    unknown_objects = all_objects
  else
    unknown_objects = {}
    for j=1,#all_objects do
      local found = false
      for k=1,#known_objects do
        if all_objects[j] == known_objects[k] then
          found = true
          break
        end
      end
      if not found then
        table.insert(unknown_objects, all_objects[j])
      end
    end
  end
  -- Destroy the unknown objects
  for m=1,#unknown_objects do
    unknown_objects[m].destroy()
  end
  log("Destroyed "..tostring(#unknown_objects).." orphaned rendering objects")
end
