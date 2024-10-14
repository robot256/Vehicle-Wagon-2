--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: 02-00-00_global_refactor.lua
 * Description: LUA Migration for saves with 1.2.x data structure, up to version 2.0.0.
--]]

-- Load global prototype data
require("__VehicleWagon2__.script.makeGlobalMaps")
makeGlobalMaps()

--------------------------------
-- Migrate from 1.x.x to 2.x.x
--------------------------------
  -- If previous version is before 2.0.0, migrate global data tables to the new format
  -- Delete any pending load/unload commands and selections in the save file
  
  --=================================
  -- Old format: 
  -- storage.vehicle_data[player_index] contains loaded vehicles each player clicked on.
  -- storage.wagon_data[player_index] contains player actions to load and unload vehicles
  -- storage.wagon_data[unit_number] contains vehicle data saved for each loaded wagon unit
  -- {
  --      name = vehicle entity name stored
  --      health = vehicle health
  --      color = vehicle color or nil
  --      burner = table of vehicle burner settings
  --      {
  --          inventory.get_contents(), 
  --          burnt_result_inventory.get_contents(), 
  --          currently_burning (Item prototype),
  --          remaining_burning_fuel,
  --          heat
  --      }
  --      filters = table of inventory filters
  --      {
  --          [defines.inventory.ammo] = table of slot filters
  --              {
  --                  <slot number> = <filter item-name>
  --              }
  --          [defines.inventory.trunk] = table of slot filters
  --              {
  --                  <slot number> = <filter item-name>
  --              }
  --      }
  --      items = table of vehicle contents
  --      {
  --           <item-name> = total count of this item in fuel, ammo, and trunk inventories
  --           <grid> = list of equipment grid contents
  --           {
  --               <#> = {name, position, energy, shield, 
  --                        burner={inventory.get_contents(), 
  --                                burnt_result_inventory.get_contents(), 
  --                                currently_burning (Item prototype),
  --                                remaining_burning_fuel,
  --                                heat}
  --                      }
  --           }
  --      }
  -- }
  --
  --======================
  -- New Format:
  -- storage.player_selection[player_index] contains player selections
  -- storage.action_queue[unit_number] contains load and unload actions while their animation finishes, indexed by empty or loaded wagon unit_number
  -- storage.wagon_data[unit_number] contains vehicle data saved for each loaded wagon unit
  -- {
  --      wagon = LuaEntity <(loaded_wagon entity reference)
  --      name = vehicle entity name stored
  --      health = vehicle health
  --      color = vehicle color or nil
  --      items: ammo and trunk stacks
  --      {
  --          ammo = saveRestoreLib.saveInventoryStacks() or nil
  --          {
  --              {
  --                  name = item-name,
  --                  count = count,
  --                  ammo = ammo or nil,
  --                  durability = durability or nil,
  --                  health = health or nil,
  --                  data = LuaItemStack::export_stack() or nil,
  --              },
  --          },
  --          trunk = saveRestoreLib.saveInventoryStacks() or nil
  --      }
  --      filters: ammo and trunk filters
  --      {
  --          ammo = saveRestoreLib.saveFilters() or nil
  --          {
  --              [slot_number] = LuaInventory::get_filter(slot_number),
  --              bar = LuaInventory::getbar() or nil
  --          },
  --          trunk = saveRestoreLib.saveFilters() or nil
  --      }
  --      grid = saveRestoreLib.saveGrid() or nil
  --      {
  --          {
  --              item = {name = name, position = position},
  --              energy = energy or nil,
  --              shield = shield or nil,
  --              burner = saveRestoreLib.saveBurner()
  --          },
  --      }
  --      burner = saveRestoreLib.saveBurner() or nil
  --      {
  --          heat = heat,
  --          currently_burning = currently_burning.name or nil,
  --          remaining_burning_fuel = remaining_burning_fuel or nil,
  --          inventory = saveRestoreLib.itemsToStacks() or nil,
  --          burnt_result_inventory = saveRestoreLib.itemsToStacks() or nil
  --      }
  --
---------------


if storage.vehicle_data then

  log("Vehicle Wagon 2 global before migration:")
  log(serpent.block(global))

  -- If storage.vehicle_data exists at all, then we are loading a 1.2.x save.
  -- Step 0: Clear Pending Selections and Actions from old vehicle_data table
  for player_index,_ in pairs(storage.vehicle_data) do
    local player = game.get_player(player_index)
    if player then
      player.clear_gui_arrow()
    end
  end
  storage.vehicle_data = nil  -- No longer used

  if storage.wagon_data then
    -- Step 1: Clear Pending Selections and Actions from wagon_data before reformatting it
    for player_index,player in pairs(game.players) do
      if storage.wagon_data[player_index] then
        player.clear_gui_arrow()
        storage.wagon_data[player_index] = nil
      end
    end
    
    -- Step 2: Make a list of all loaded wagon entities in the game
    local loaded_wagons = {}
    for _,surface in pairs(game.surfaces) do
      for _,wagon in pairs(surface.find_entities_filtered{name = storage.loadedWagonList}) do
        log("Found loaded wagon "..tostring(wagon and wagon.name).." "..tostring(wagon and wagon.unit_number))
        loaded_wagons[wagon.unit_number] = wagon
      end
    end
    
    -- Step 3: Copy contents of wagon_data to a new table in the new format
    local new_wagon_data = {}
    for unit_number,data in pairs(storage.wagon_data) do
      -- Make sure this is a valid wagon data entry
      if not data.items then
        -- Not a valid wagon data structure
        storage.wagon_data[unit_number] = nil
      else
        -- Make sure this loaded wagon still exists
        if not loaded_wagons[unit_number] or not loaded_wagons[unit_number].valid then
          game.print({"vehicle-wagon2.migrate-wagon-error", unit_number, data.name})  
          storage.wagon_data[unit_number] = nil
        else
          -- Make sure this data is for a valid vehicle type
          if not data.name or not prototypes.entity[data.name] then
            -- Give error message
            if data.name then
              game.print({"vehicle-wagon2.migrate-prototype-error", unit_number, data.name})
            end
            -- Replace loaded wagon with empty one
            replaceCarriage(loaded_wagons[unit_number], "vehicle-wagon", false, false)
            storage.wagon_data[unit_number] = nil
          else
          
            -- Migrate data
            local newData = {}
            newData.name = data.name
            newData.health = data.health
            newData.color = data.color
            
            -- Migrate Vehicle Burner
            if data.burner then
              newData.burner = {
                heat = data.burner.heat,
                remaining_burning_fuel = data.burner.remaining_burning_fuel
              }
              -- Currently burning converted from LuaItemPrototype object to item-name
              if data.burner.currently_burning and data.burner.currently_burning.valid then
                newData.burner.currently_burning = data.burner.currently_burning.name
              end
              -- Convert burnt_result_inventory from name->count dictionary to stack list
              if data.burner.burnt_result_inventory then
                newData.burner.burnt_result_inventory = saveRestoreLib.itemsToStacks(data.burner.burnt_result_inventory)
              end
              -- We will insert fuel later
              newData.burner.inventory = {}
            else
              -- No burner stored, make a dummy one to hold fuel
              newData.burner = {inventory={}}
            end
            
            -- Migrate Equipment Grid
            if data.items.grid then
              newData.grid = {}
              for i,e in pairs(data.items.grid) do
                local newE = {  item = {name=e.name, position=e.position},
                                energy = e.energy,
                                shield = e.shield }
                if e.burner then
                  local newB = {heat = e.burner.heat,
                                remaining_burning_fuel = e.burner.remaining_burning_fuel}
                  -- Currently burning converted from LuaItemPrototype object to item-name
                  if e.burner.currently_burning and e.burner.currently_burning.valid then
                    newB.currently_burning = e.burner.currently_burning.name
                  end
                  -- Convert burnt_result_inventory from name->count dictionary to stack list
                  if e.burner.burnt_result_inventory then
                    newB.burnt_result_inventory = saveRestoreLib.itemsToStacks(e.burner.burnt_result_inventory)
                  end
                  -- Convert fuel inventory
                  if e.burner.inventory then
                    newB.inventory = saveRestoreLib.itemsToStacks(e.burner.inventory)
                  else
                    newB.inventory = {}
                  end
                  newE.burner = newB
                end
                table.insert(newData.grid, newE)
              end
              data.items.grid = nil
            end
            
            -- Migrate inventory filters.
            newData.filters = {ammo={}, trunk={}}
            if data.filters and data.filters[defines.inventory.car_ammo] then
              newData.filters.ammo = data.filters[defines.inventory.car_ammo]
            end
            if data.filters and data.filters[defines.inventory.car_trunk] then
              newData.filters.trunk = data.filters[defines.inventory.car_trunk]
            end
            
            -- Migrate inventory contents.  Separate fuel and ammo items so they get inserted correctly.
            -- (Doesn't matter if there are too many or the wrong types. Remainders will be put in trunk when unloaded.)
            newData.items = {ammo={}, trunk={}}
            for item_name,count in pairs(data.items) do
              if prototypes.item[item_name] and type(count)=="number" then
                if prototypes.item[item_name].fuel_category then
                  -- Put fuel items in the burner fuel inventory
                  table.insert(newData.burner.inventory, {name=item_name, count=count})
                elseif prototypes.item[item_name].get_ammo_type() then
                  -- Put ammo in the ammo inventory
                  table.insert(newData.items.ammo, {name=item_name, count=count})
                else
                  -- Anything else goes in trunk
                  table.insert(newData.items.trunk, {name=item_name, count=count})
                end
              end
            end
            
            game.print({"vehicle-wagon2.migrate-vehicle-success", unit_number, {"entity-name."..data.name}})
            
            -- Add data to new list for this loaded wagon
            new_wagon_data[unit_number] = newData
          end
        end
      end
    end
    -- Store new global data table
    storage.wagon_data = nil
    storage.wagon_data = new_wagon_data
  end

  -- Clear other flags from the old version
  storage.found = nil  -- No longer used
  storage.tutorials = nil  -- Reset tutorial message sequences
  
  game.print({"vehicle-wagon2.migrate-12x-success"})
  
  log("Vehicle Wagon 2 global after migration:")
  log(serpent.block(global))
end

-- Create new-style tables if needed
makeGlobalTables()
