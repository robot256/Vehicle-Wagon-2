--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: OnPrePlayerMinedItem.lua
 * Description:  Event handler for when a player mines an entity:
 *   - When player attempts to mine a Loaded Vehicle Wagon:
 *       1. Attempt to unload the vehicle, 
 *       2. If that fails, give the player the vehicle and its contents
 *       3. If that is incomplete, spill the remaining contents on the ground.
 *       4. Cancel any existing unloading requests for this wagon.
 *   - When the player attempts to mine a Vehicle Wagon (empty):
 *       1. Cancel any existing loading requests for this wagon.
 *   - When the player attempts to mine an ItemOnGround entity:
 *       1. Replace any Loaded Vehicle Wagon items with Vehicle Wagon items.
 *   - When the player attempts to mine a car:
 *       1. Cancel existing loading requests for this vehicle. 
--]]

--== ON_PRE_PLAYER_MINED_ITEM ==--
-- When player mines a loaded wagon, try to unload the vehicle first
-- If vehicle cannot be unloaded, give its contents to the player and spill the rest.
local function OnPrePlayerMinedItem(event)
  local entity = event.entity
  if global.loadedWagonMap[entity.name] then
    -- Player is mining a loaded wagon
    -- Attempt to unload the wagon nearby
    local unit_number = entity.unit_number
    local player_index = event.player_index
    
    local player = game.players[player_index]
    local surface = player.surface
    local wagonData = global.wagon_data[unit_number]
    if not wagonData then
      -- Loaded wagon data or vehicle entity is invalid
      -- Replace wagon with unloaded version and delete data
      game.print({"vehicle-wagon2.data-error", unit_number})  
      replaceCarriage(entity, global.loadedWagonMap[entity.name], false, false)
    elseif not game.entity_prototypes[wagonData.name] then
      -- Loaded wagon data or vehicle entity is invalid
      -- Replace wagon with unloaded version and delete data
      game.print({"vehicle-wagon2.vehicle-prototype-error", unit_number, global.wagon_data[unit_number].name})  
      replaceCarriage(entity, global.loadedWagonMap[entity.name], false, false)
    else
      -- We can try to unload this wagon
      local vehicle = unloadVehicleWagon({player_index=player_index,
                                          status="unload",
                                          wagon=entity,
                                          replace_wagon=false})
      
      if not vehicle then
        -- Vehicle could not be unloaded
        
        -- Insert vehicle and contents into player's inventory
        local playerPosition = player.position
        local playerInventory = player.get_main_inventory()
        
        local itemName = wagonData.name
        local proto = game.entity_prototypes[wagonData.name]
        if proto and proto.mineable_properties and proto.mineable_properties.products then
          -- Assume this entity gives only one item when you mine it, and that that is the vehicle
          itemName = proto.mineable_properties.products[1].name
        end
        local text_position = {x=playerPosition.x, y=playerPosition.y+1}
        surface.create_entity{name = "flying-text", position = text_position, text = {"vehicle-wagon2.item-inserted", 1, game.entity_prototypes[wagonData.name].localised_name}}
        
        local r2 = saveRestoreLib.insertInventoryStacks(playerInventory, {{name=itemName, count=1}})
        saveRestoreLib.spillStacks(r2, surface, playerPosition)
        
        -- Give player the equipment contents, spill excess
        if wagonData.items.grid then
          local equip_stacks, fuel_stacks = saveRestoreLib.saveGridStacks(wagonData.items.grid)
          local r2 = saveRestoreLib.insertInventoryStacks(playerInventory, equip_stacks)
          saveRestoreLib.spillStacks(r2, surface, playerPosition)
          local r2 = saveRestoreLib.insertInventoryStacks(playerInventory, fuel_stacks)
          saveRestoreLib.spillStacks(r2, surface, playerPosition)
        end
        
        -- Give player the ammo inventory, spill excess
        local r2 = saveRestoreLib.insertInventoryStacks(playerInventory, wagonData.items.ammo)
        saveRestoreLib.spillStacks(r2, surface, playerPosition)
        -- Give player the cargo inventory, spill excess
        local r2 = saveRestoreLib.insertInventoryStacks(playerInventory, wagonData.items.trunk)
        saveRestoreLib.spillStacks(r2, surface, playerPosition)
        -- Give player the burner contents, spill excess
        if wagonData.burner then
          local r2 = saveRestoreLib.insertInventoryStacks(playerInventory, wagonData.burner.inventory)
          saveRestoreLib.spillStacks(r2, surface, playerPosition)
          local r2 = saveRestoreLib.insertInventoryStacks(playerInventory, wagonData.burner.burnt_results_inventory)
          saveRestoreLib.spillStacks(r2, surface, playerPosition)
        end
        
      end
      
    end
    
    -- Delete the data associated with the mined wagon
    -- Delete any requests for unloading this particular wagon
    deleteWagon(unit_number)
    
  elseif entity.name == "vehicle-wagon" or entity.name == "ferry-boat" then
    -- Delete any requests for loading this particular wagon
    clearWagon(entity.unit_number)
    
  elseif entity.name == "item-on-ground" then
    -- Change item-on-ground to unloaded wagon before player picks it up
    if entity.stack.valid_for_read and global.loadedWagonMap[entity.stack.name] then
      entity.stack.set_stack({name=global.loadedWagonMap[entity.stack.name], count=entity.stack.count})
    end
  elseif (event.entity.type == "car" or event.entity.type == "spider-vehicle") then
    clearVehicle(entity)
  end
  
end

return OnPrePlayerMinedItem
