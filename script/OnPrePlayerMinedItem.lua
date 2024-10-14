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
function OnPrePlayerMinedItem(event)
  local entity = event.entity
  if storage.loadedWagonMap[entity.name] then
    -- Player is mining a loaded wagon
    -- Attempt to unload the wagon nearby
    local unit_number = entity.unit_number
    local player_index = event.player_index
    
    local player = game.players[player_index]
    local surface = player.surface
    local wagonData = storage.wagon_data[unit_number]
    if not wagonData then
      -- Loaded wagon data or vehicle entity is invalid
      -- Replace wagon with unloaded version and delete data
      player.create_local_flying_text{text={"vehicle-wagon2.data-error", unit_number}, position=entity.position}
    elseif not wagonData.vehicle or not wagonData.vehicle.valid then
      -- Loaded wagon data or vehicle entity is invalid
      -- Replace wagon with unloaded version and delete data
      player.create_local_flying_text{text={"vehicle-wagon2.vehicle-prototype-error", unit_number, storage.wagon_data[unit_number].name}, position=entity.position}
    else
      -- We can try to unload this wagon normally by teleporting
      local vehicle = unloadVehicleWagon{status="unload", player_index=player_index, wagon=entity, replace_wagon=false}
      
      if not vehicle then
        -- Vehicle could not be unloaded via teleporting to a safe space
        
        -- Insert vehicle and contents into player's inventory
        local playerPosition = player.position
        local playerInventory = player.get_main_inventory()
        
        -- Mine the vehicle and insert it into the player's inventory
        if wagonData.vehicle and wagonData.vehicle.valid then
          vehicle = wagonData.vehicle
          vehicle.teleport(entity.position, entity.surface)
          player.mine_entity(wagonData.vehicle, true)
        end
        
      end
      
    end
    -- Clear the item in the wagon
    local wagon_inv = entity.get_inventory(defines.inventory.cargo_wagon)
    if wagon_inv then
      wagon_inv.clear()
    end
    -- Delete the data associated with the mined wagon
    -- Delete any requests for unloading this particular wagon
    deleteWagon(unit_number)
    
  elseif entity.name == "item-on-ground" then
    -- Change item-on-ground to unloaded wagon before player picks it up
    if entity.stack.valid_for_read and storage.loadedWagonMap[entity.stack.name] then
      entity.stack.set_stack({name="vehicle-wagon", count=entity.stack.count})
    end
  
  end
  
end
