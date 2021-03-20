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
local function OnRobotPreMined(event)
  local entity = event.entity
  if global.loadedWagonMap[entity.name] then
      
    -- Player or robot is mining a loaded wagon
    -- Attempt to unload the wagon nearby
    local unit_number = entity.unit_number
    local robot = event.robot
  
    local wagonData = global.wagon_data[unit_number]
    if not wagonData then
      -- Loaded wagon data or vehicle entity is invalid
      -- Replace wagon with unloaded version and delete data
      game.print({"vehicle-wagon2.data-error", unit_number})  
      deleteWagon(unit_number)
      replaceCarriage(entity, global.loadedWagonMap[entity.name], false, false)
    elseif not game.entity_prototypes[wagonData.name] then
      game.print({"vehicle-wagon2.vehicle-prototype-error", unit_number, global.wagon_data[unit_number].name})  
      -- Loaded wagon data or vehicle entity is invalid
      -- Replace wagon with unloaded version and delete data
      deleteWagon(unit_number)
      replaceCarriage(entity, global.loadedWagonMap[entity.name], false, false)
    else
      -- We can try to unload this wagon
      local allow_robot_unloading = settings.global["vehicle-wagon-allow-robot-unloading"].value
      local vehicle = nil
      -- Check if this is a Creative Mod Instant Deconstruct (tm) operation
      if not event.robot.get_inventory or #event.robot.get_inventory(defines.inventory.robot_cargo) == 0 then
        vehicle = unloadVehicleWagon({status="unload", wagon=entity, replace_wagon=false})
      elseif allow_robot_unloading then
        vehicle = unloadVehicleWagon({status="unload", wagon=entity, replace_wagon=true})
      end
      
      if not vehicle then
        -- Vehicle could not be unloaded
        -- First check for inventory contents
        local robotInventory = event.robot.get_inventory(defines.inventory.robot_cargo)
        local robotSize = 1 + event.robot.force.worker_robots_storage_bonus
        local robotEmpty = robotInventory.is_empty()
        
        if robotEmpty and wagonData.items.trunk then
          for index,stack in pairs(wagonData.items.trunk) do
            if not stack.count then stack.count = 1 end
            --game.print("Giving robot cargo stack: "..stack.name.." : "..stack.count)
            wagonData.items.trunk[index] = saveRestoreLib.insertStack(robotInventory, stack, robotSize)
            if not robotInventory.is_empty() then
              robotEmpty = false
              break
            end
          end
        end
        
        if robotEmpty and wagonData.items.ammo then
          for index,stack in pairs(wagonData.items.ammo) do
            if not stack.count then stack.count = 1 end
            --game.print("Giving robot ammo stack: "..stack.name.." : "..stack.count)
            wagonData.items.ammo[index] = saveRestoreLib.insertStack(robotInventory, stack, robotSize)
            if not robotInventory.is_empty() then
              robotEmpty = false
              break
            end
          end
        end
        
        if robotEmpty and wagonData.burner then
          if robotEmpty and wagonData.burner.inventory then
            for index,stack in pairs(wagonData.burner.inventory) do
              if not stack.count then stack.count = 1 end
              --game.print("Giving robot burner fuel stack: "..stack.name.." : "..stack.count)
              wagonData.burner.inventory[index] = saveRestoreLib.insertStack(robotInventory, stack, robotSize)
              if not robotInventory.is_empty() then
                robotEmpty = false
                break
              end
            end
          end
          if robotEmpty and wagonData.burner.inventory then
            for index,stack in pairs(wagonData.burner.inventory) do
              --game.print("Giving robot burner burnt stack: "..stack.name.." : "..stack.count)
              if not stack.count then stack.count = 1 end
              wagonData.burner.inventory[index] = saveRestoreLib.insertStack(robotInventory, stack, robotSize)
              if not robotInventory.is_empty() then
                robotEmpty = false
                break
              end
            end
          end
        end

        if robotEmpty and wagonData.items.grid and not wagonData.items.equip_stacks and not wagonData.items.fuel_stacks then
          wagonData.items.equip_stacks, wagonData.items.fuel_stacks = saveRestoreLib.saveGridStacks(wagonData.items.grid)
        end
        if robotEmpty and wagonData.items.fuel_stacks then
          for index,stack in pairs(wagonData.items.fuel_stacks) do
            if not stack.count then stack.count = 1 end
            local count = stack.count
            --game.print("Giving robot equipment fuel stack: "..stack.name.." : "..stack.count)
            wagonData.items.fuel_stacks[index] = saveRestoreLib.insertStack(robotInventory, stack, robotSize)
            if not robotInventory.is_empty() then
              if wagonData.items.fuel_stacks[index] then
                count = count - wagonData.items.fuel_stacks[index].count
              end
              saveRestoreLib.removeStackFromSavedGrid(wagonData.items.grid, {name=stack.name, count=count})
              robotEmpty = false
              break
            end
          end
        end
        if robotEmpty and wagonData.items.equip_stacks then
          for index,stack in pairs(wagonData.items.equip_stacks) do
            if not stack.count then stack.count = 1 end
            local count = stack.count
            --game.print("Giving robot equipment stack: "..stack.name.." : "..stack.count)
            wagonData.items.equip_stacks[index] = saveRestoreLib.insertStack(robotInventory, stack, robotSize)
            if not robotInventory.is_empty() then
              if wagonData.items.equip_stacks[index] then
                count = count - wagonData.items.equip_stacks[index].count
              end
              saveRestoreLib.removeStackFromSavedGrid(wagonData.items.grid, {name=stack.name, count=count})
              robotEmpty = false
              break
            end
          end
        end
        
        if robotEmpty then
          local itemName = wagonData.name
          local proto = game.entity_prototypes[wagonData.name]
          if proto and proto.mineable_properties and proto.mineable_properties.products then
            -- Assume this entity gives only one item when you mine it, and that that is the vehicle
            itemName = proto.mineable_properties.products[1].name
          end
          if saveRestoreLib.insertStack(robotInventory, {name=itemName, count=1}, robotSize) == nil then
            --game.print("Gave robot "..wagonData.name.." : 1")
          else
            game.print({"vehicle-wagon2.vehicle-prototype-error", unit_number, global.wagon_data[unit_number].name})  
          end
          replaceCarriage(entity, global.loadedWagonMap[entity.name], false, false)
          -- Delete wagon data and any associated requests
          deleteWagon(unit_number)
        end
      end
      
    end
    
  elseif entity.name == "vehicle-wagon" or entity.name == "ferry-boat" then
    -- Delete any requests for loading this particular wagon
    clearWagon(entity.unit_number)
    
  elseif entity.name == "item-on-ground" then
    -- Change item-on-ground to unloaded wagon before robot picks it up
    if entity.stack.valid_for_read and global.loadedWagonMap[entity.stack.name] then
      entity.stack.set_stack({name=global.loadedWagonMap[entity.stack.name], count=entity.stack.count})
    end
  end
  
end

return OnRobotPreMined
