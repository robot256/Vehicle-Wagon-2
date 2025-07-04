-- Make all wagons operable
require("__VehicleWagon2__.script.makeGlobalMaps")

local count = 0
for _,surface in pairs(game.surfaces) do
  local filter = table.deepcopy(storage.loadedWagonList)
  filter[#filter] = "vehicle-wagon"
  for _,wagon in pairs(surface.find_entities_filtered{name=filter}) do
    if wagon.operable == false then
      wagon.operable = true
      count = count + 1
    end
  end
end
if count > 0 then
  log("Changed "..tostring(count).." wagons to be operable.")
end
