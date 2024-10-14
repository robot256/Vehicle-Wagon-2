--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: OnRobotPreMined.lua
 * Description:  Event handler for when a robot mines an entity:
 *   - When robot attempts to mine a Loaded Vehicle Wagon:
 *       1. If mod setting "Allow Robot Unloading" is True, attempt to unload the vehicle.
 *       2. If that fails or is disallowed, give the robot a piece the vehicle's contents.
 *       3. When the vehicle's contents is empty, give the robot the vehicle and replace the wagon with an empty Vehicle Wagon.
 *       4. Cancel any existing unloading requests for this wagon.
 *   - When robot mines a Vehicle Wagon (empty):
 *       1. Cancel any existing loading requests for this wagon.
 *   - When robot mines an ItemOnGround entity:
 *       1. Replace any Loaded Vehicle Wagon items with Vehicle Wagon items.
--]]


--== ON_ROBOT_PRE_MINED ==--
-- When robot tries to mine a loaded wagon, try to unload the vehicle first!
-- If vehicle cannot be unloaded, send its contents away in the robot piece by piece.
function OnRobotPreMined(event)
  local entity = event.entity
  if storage.loadedWagonMap[entity.name] then
    -- Player or robot is mining a loaded wagon
    -- Attempt to unload the wagon nearby
    local unit_number = entity.unit_number
    local robot = event.robot
  
    local wagonData = storage.wagon_data[unit_number]
    if not wagonData then
      -- Loaded wagon data or vehicle entity is invalid
      game.print({"vehicle-wagon2.data-error", unit_number})
    elseif not wagonData.vehicle or not wagonData.vehicle.valid then
      -- Loaded wagon data or vehicle entity is invalid
      game.print({"vehicle-wagon2.vehicle-missing-error", loaded_unit_number, wagon_data.name})
    else
      -- We can try to unload this wagon
      local vehicle = unloadVehicleWagon{status="unload", wagon=entity, replace_wagon=false}
      
      if not vehicle then
        -- Teleport it on top of the wagon and deconstruct everything
        wagonData.vehicle.teleport(entity.position, entity.surface)
        wagonData.vehicle.order_deconstruction(robot.force)
        wagonData.vehicle = nil  -- break the link to the vehicle entity so it's not deleted
      end
    end
    -- Clear the item in the wagon
    local wagon_inv = entity.get_inventory(defines.inventory.cargo_wagon)
    if wagon_inv then
      wagon_inv.clear()
    end
    deleteWagon(unit_number)
    
  elseif entity.name == "item-on-ground" then
    -- Change item-on-ground to unloaded wagon before robot picks it up
    if entity.stack.valid_for_read and storage.loadedWagonMap[entity.stack.name] then
      entity.stack.set_stack({name="vehicle-wagon", count=entity.stack.count})
    end
  end
end
