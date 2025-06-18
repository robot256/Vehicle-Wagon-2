require("__VehicleWagon2__/script/makeGlobalMaps")

-- Fix missing entries in storage.loading_rails due to bug that was present in 4.1.8 and earlier
if storage.loading_ramps then
  storage.loading_rails = {}
  storage.unloading_rails = {}
  for ramp_unit_number, entry in pairs(storage.loading_ramps) do
    local ramp = entry.ramp
    if entry.loading_rail then
      local rail_unit_number = entry.loading_rail.unit_number
      storage.loading_rails[rail_unit_number] = storage.loading_rails[rail_unit_number] or {}
      storage.loading_rails[rail_unit_number][ramp_unit_number] = ramp
    end
    if entry.unloading_rails then
      for rail_unit_number,_ in pairs(storage.unloading_rails) do
        storage.unloading_rails[rail_unit_number] = storage.unloading_rails[rail_unit_number] or {}
        storage.unloading_rails[rail_unit_number][ramp_unit_number] = ramp
      end
    end
  end
end

-- Find existing manual trains
storage.manual_trains = storage.manual_trains or {}
local wagon_list = table.deepcopy(storage.loadedWagonList)
table.insert(wagon_list, "vehicle-wagon")
for _,train in pairs(game.train_manager.get_trains{is_manual=true, stock=wagon_list}) do
  storage.manual_trains[train.id] = {train=train, ramps={}}
  script.register_on_object_destroyed(train)
end
