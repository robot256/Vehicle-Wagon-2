--[[ Copyright (c) 2025 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: getVehicleItem.lua
 * Description: Determine what shadow item to put in the vehicle wagon inventory for each vehicle
--]]

function getVehicleItem(entity_name)
  local prototype = prototypes.entity[entity_name]
  local item
  
  -- make sure prototype with this entity name exists
  if not prototype then return nil end
  
  -- check for items_to_place_this
  item = prototype.items_to_place_this and prototype.items_to_place_this[1] and prototype.items_to_place_this[1].name
  if item then return item end
  
  -- check for minable
  item = prototype.minable_properties and prototype.minable_properties.products and prototype.minable_properties.products[1] and prototype.minable_properties.products[1].name
  if item then return item end
  
  -- check for entity_name item
  item = prototypes.item[entity_name] and entity_name
  
  if item then return item end
  
  return nil
end
