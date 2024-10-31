--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: makeGlobalMaps.lua
 * Description: Cross-reference prototypes of loaded wagons
--]]

-- Go through all the available prototypes and assign them to a valid loaded wagon or "nope"
function makeGlobalMaps()

  -- Make list and map of loaded wagon entities (regardless of whether any vehicles map to them)
  storage.loadedWagonMap = {}   --: loaded-wagon-name --> "vehicle-wagon"
  storage.loadedWagonList = {}  --: list of loaded-wagon-name
  for k,p in pairs(prototypes.get_entity_filtered({{filter="type", type="cargo-wagon"}})) do
    if string.find(k,"loaded%-vehicle%-wagon%-") then
      storage.loadedWagonMap[k] = "vehicle-wagon"
      table.insert(storage.loadedWagonList, k)
    end
  end

  -- Need to check max weight as we go through
  local useWeights = settings.startup["vehicle-wagon-use-custom-weights"].value
  local maxWeight = (useWeights and settings.startup["vehicle-wagon-maximum-weight"].value) or math.huge
  
  -- Some sprites show up backwards from how they ought to, so we flip the wagons relative to the vehicles.
  storage.loadedWagonFlip = {  --: loaded-wagon-name --> boolean
    ["loaded-vehicle-wagon-cargoplane"] = true,  -- Cargo plane wagon sprite is flipped
    ["loaded-vehicle-wagon-jet"] = true,  -- Jet wagon sprite is flipped
    ["loaded-vehicle-wagon-gunship"] = true,  -- Gunship wagon sprite is flipped
  }
  
  storage.vehicleMap = {}  --: vehicle-name --> loaded-wagon-name
  for k,p in pairs(prototypes.get_entity_filtered({{filter="type", type="car"},{filter="type", type="spider-vehicle"}})) do
    local kc = k and string.lower(k)  -- force to lower case when looking for generic car and tank strings
    
    if k and string.find(k,"nixie") then
      storage.vehicleMap[k] = nil  -- non vehicle entity
    elseif k == "uplink-station" then
      storage.vehicleMap[k] = nil  -- non vehicle entity
    elseif k and (string.find(k,"heli") or string.find(k,"rotor")) then
      storage.vehicleMap[k] = nil  -- helicopter & heli parts incompatible
    elseif k and string.find(k,"airborne") then
      storage.vehicleMap[k] = nil  -- can't load flying planes [Aircraft Realism compatibility]
    
    -- SE has lots of non-vehicle entities
    elseif k and string.find(k,"se%-rocket") then
      storage.vehicleMap[k] = nil
    elseif k and string.find(k,"se%-spaceship") then
      storage.vehicleMap[k] = nil
    elseif k == "shield-projector-barrier" then
      storage.vehicleMap[k] = nil
    elseif k and string.find(k,"burbulator") then
      storage.vehicleMap[k] = nil
    
    
    elseif p.weight > maxWeight then
      storage.vehicleMap[k] = nil  -- This vehicle is too heavy
      
    elseif p.type == "spider-vehicle" then
      storage.vehicleMap[k] = "loaded-vehicle-wagon-tarp"  -- All Spidertrons become tarps until we have new graphics :)
    
    elseif k and string.find(k,"cargo%-plane") and storage.loadedWagonMap["loaded-vehicle-wagon-cargoplane"] then
      storage.vehicleMap[k] = "loaded-vehicle-wagon-cargoplane"  -- Cargo plane, Better cargo plane, Even better cargo plane
    
    elseif k and string.find(k,"jet") and storage.loadedWagonMap["loaded-vehicle-wagon-jet"] then
      storage.vehicleMap[k] = "loaded-vehicle-wagon-jet"
    
    elseif k and string.find(k,"gunship") and storage.loadedWagonMap["loaded-vehicle-wagon-gunship"] then
      storage.vehicleMap[k] = "loaded-vehicle-wagon-gunship"
    
    elseif k and string.find(k,"dumper%-truck") and storage.loadedWagonMap["loaded-vehicle-wagon-truck"] then
      storage.vehicleMap[k] = "loaded-vehicle-wagon-truck"  -- Specific to dump truck mod
    
    elseif k and string.find(k,"Schall%-ht%-RA") then
      storage.vehicleMap[k] = "loaded-vehicle-wagon-tank"  -- Schall's Rocket Artillery look like tanks
    
    elseif k and string.find(k,"Schall%-tank%-L") and storage.loadedWagonMap["loaded-vehicle-wagon-tank-L"] then
      storage.vehicleMap[k] = "loaded-vehicle-wagon-tank-L"  -- Schall's Light Tank
    
    elseif k and string.find(k,"Schall%-tank%-H") and storage.loadedWagonMap["loaded-vehicle-wagon-tank-H"] then
      storage.vehicleMap[k] = "loaded-vehicle-wagon-tank-H"  -- Schall's Heavy Tank
    
    elseif k and string.find(k,"Schall%-tank%-SH") and storage.loadedWagonMap["loaded-vehicle-wagon-tank-SH"] then
      storage.vehicleMap[k] = "loaded-vehicle-wagon-tank-SH"  -- Schall's Super Heavy Tank
      
    elseif k and string.find(k,"kr%-advanced%-tank") and storage.loadedWagonMap["loaded-vehicle-wagon-kr-advanced-tank"] then
      storage.vehicleMap[k] = "loaded-vehicle-wagon-kr-advanced-tank"  -- Krastorio2 Advanced Tank  
    
    elseif kc and string.find(kc,"tank") then
      storage.vehicleMap[k] = "loaded-vehicle-wagon-tank"  -- Generic tank
    
    elseif kc and string.find(kc,"%f[%a]car%f[%A]") then
      storage.vehicleMap[k] = "loaded-vehicle-wagon-car"  -- Generic car (that is not cargo)
    
    else
      storage.vehicleMap[k] = "loaded-vehicle-wagon-tarp"  -- Default for everything else
    end
    
    if storage.vehicleMap[k] then
      log("Assigned vehicle \""..k.."\" to wagon \""..storage.vehicleMap[k].."\"")
    else
      log("Disallowed loading of vehicle \""..k.."\"")
    end
  end
  
  -- Make a list to use for searching for loadable entities
  storage.vehicleList = {}
  local k = 1
  for name,_ in pairs(storage.vehicleMap) do
    storage.vehicleList[k] = name
    k = k + 1
  end
end


-- Initialize new global tables if they do not already exist
function makeGlobalTables()
  -- Contains data on vehicles loaded on wagons
  storage.wagon_data = storage.wagon_data or {}
  -- Contains load/unload actions players ordered, while they wait for the 2-second delay to expire
  storage.action_queue = storage.action_queue or {}
  -- Contains entity each player actively selected with a winch.
  storage.player_selection = storage.player_selection or {}
end
