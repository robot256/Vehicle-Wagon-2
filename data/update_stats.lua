--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: update_stats.lua
 * Description:  Adjust wagon weights based on startup settings vehicle prototypes.
 *   
--]]

-- Update the weights after other mods have had their fun
local useWeights = settings.startup["vehicle-wagon-use-custom-weights"].value
local vehicleWeightFactor = (useWeights and settings.startup["vehicle-wagon-vehicle-weight-factor"].value) or 0
local emptyWeightFactor = (useWeights and settings.startup["vehicle-wagon-empty-weight-factor"].value) or 1
local brakingFactor = (useWeights and settings.startup["vehicle-wagon-braking-factor"].value) or 1
local emptyFrictionFactor = (useWeights and settings.startup["vehicle-wagon-empty-friction-factor"].value) or 1
local loadedFrictionFactor = (useWeights and settings.startup["vehicle-wagon-loaded-friction-factor"].value) or 1

local cargo_wagon = data.raw["cargo-wagon"]["cargo-wagon"]
local emptyWeight = cargo_wagon.weight * emptyWeightFactor
local maxWagonWeight = (useWeights and (emptyWeight + settings.startup["vehicle-wagon-maximum-weight"].value)) or math.huge

local brakingForce = cargo_wagon.braking_force * brakingFactor
local emptyFriction = cargo_wagon.friction_force * emptyFrictionFactor
local loadedFriction = cargo_wagon.friction_force * loadedFrictionFactor


local vehicle_wagon = data.raw["cargo-wagon"]["vehicle-wagon"]
vehicle_wagon.weight = emptyWeight
vehicle_wagon.braking_force = brakingForce
vehicle_wagon.friction_force = emptyFriction

local loaded_car = data.raw["cargo-wagon"]["loaded-vehicle-wagon-car"]
loaded_car.weight = emptyWeight + (data.raw["car"]["car"].weight * vehicleWeightFactor)
loaded_car.braking_force = brakingForce
loaded_car.friction_force = loadedFriction

local loaded_tarp = data.raw["cargo-wagon"]["loaded-vehicle-wagon-tarp"]
loaded_tarp.weight = loaded_car.weight  -- Use weight of Car for unknown vehicles
loaded_tarp.braking_force = brakingForce
loaded_tarp.friction_force = loadedFriction

local loaded_tank = data.raw["cargo-wagon"]["loaded-vehicle-wagon-tank"]
loaded_tank.weight = emptyWeight + (data.raw["car"]["tank"].weight * vehicleWeightFactor)
loaded_tank.braking_force = brakingForce
loaded_tank.friction_force = loadedFriction
if loaded_tank.weight > maxWagonWeight then
  data.raw["cargo-wagon"]["loaded-vehicle-wagon-tank"] = nil
end

local loaded_truck = data.raw["cargo-wagon"]["loaded-vehicle-wagon-truck"]
if data.raw["car"]["dumper-truck"] and loaded_truck then
	loaded_truck.weight = emptyWeight + (data.raw["car"]["dumper-truck"].weight * vehicleWeightFactor)
  loaded_tank.braking_force = brakingForce
  loaded_truck.friction_force = loadedFriction
  if loaded_truck.weight > maxWagonWeight then
    data.raw["cargo-wagon"]["loaded-vehicle-wagon-truck"] = nil
  end
end

local loaded_cargo_plane = data.raw["cargo-wagon"]["loaded-vehicle-wagon-cargoplane"]
if data.raw["car"]["cargo-plane"] and loaded_cargo_plane then
	loaded_cargo_plane.weight = emptyWeight + (data.raw["car"]["cargo-plane"].weight * vehicleWeightFactor)
  loaded_cargo_plane.braking_force = brakingForce
  loaded_cargo_plane.friction_force = loadedFriction
  if loaded_cargo_plane.weight > maxWagonWeight then
    data.raw["cargo-wagon"]["loaded-vehicle-wagon-cargoplane"] = nil
  end
end

local loaded_jet = data.raw["cargo-wagon"]["loaded-vehicle-wagon-jet"]
if data.raw["car"]["jet"] and loaded_jet then
	loaded_jet.weight = emptyWeight + (data.raw["car"]["jet"].weight * vehicleWeightFactor)
  loaded_jet.braking_force = brakingForce
  loaded_jet.friction_force = loadedFriction
  if loaded_jet.weight > maxWagonWeight then
    data.raw["cargo-wagon"]["loaded-vehicle-wagon-jet"] = nil
  end
end

local loaded_gunship = data.raw["cargo-wagon"]["loaded-vehicle-wagon-gunship"]
if data.raw["car"]["gunship"] and loaded_gunship then
	loaded_gunship.weight = emptyWeight + (data.raw["car"]["gunship"].weight * vehicleWeightFactor)
  loaded_gunship.braking_force = brakingForce
  loaded_gunship.friction_force = loadedFriction
  if loaded_gunship.weight > maxWagonWeight then
    data.raw["cargo-wagon"]["loaded-vehicle-wagon-gunship"] = nil
  end
end

local loaded_tank_L = data.raw["cargo-wagon"]["loaded-vehicle-wagon-tank-L"]
if data.raw["car"]["Schall-tank-L"] and loaded_tank_L then
	loaded_tank_L.weight = emptyWeight + (data.raw["car"]["Schall-tank-L"].weight * vehicleWeightFactor)
  loaded_tank_L.braking_force = brakingForce
  loaded_tank_L.friction_force = loadedFriction
  if loaded_tank_L.weight > maxWagonWeight then
    data.raw["cargo-wagon"]["loaded-vehicle-wagon-tank-L"] = nil
  end
end

local loaded_tank_H = data.raw["cargo-wagon"]["loaded-vehicle-wagon-tank-H"]
if data.raw["car"]["Schall-tank-H"] and loaded_tank_H then
	loaded_tank_H.weight = emptyWeight + (data.raw["car"]["Schall-tank-H"].weight * vehicleWeightFactor)
  loaded_tank_H.braking_force = brakingForce
  loaded_tank_H.friction_force = loadedFriction
  if loaded_tank_H.weight > maxWagonWeight then
    data.raw["cargo-wagon"]["loaded-vehicle-wagon-tank-H"] = nil
  end
end

local loaded_tank_SH = data.raw["cargo-wagon"]["loaded-vehicle-wagon-tank-SH"]
if data.raw["car"]["Schall-tank-SH"] and loaded_tank_SH then
	loaded_tank_SH.weight = emptyWeight + (data.raw["car"]["Schall-tank-SH"].weight * vehicleWeightFactor)
  loaded_tank_SH.braking_force = brakingForce
  loaded_tank_SH.friction_force = loadedFriction
  if loaded_tank_SH.weight > maxWagonWeight then
    data.raw["cargo-wagon"]["loaded-vehicle-wagon-tank-SH"] = nil
  end
end

local loaded_advanced_tank = data.raw["cargo-wagon"]["loaded-vehicle-wagon-kr-advanced-tank"]
if data.raw["car"]["kr-advanced-tank"] and loaded_advanced_tank then
	loaded_advanced_tank.weight = emptyWeight + (data.raw["car"]["kr-advanced-tank"].weight * vehicleWeightFactor)
  loaded_advanced_tank.braking_force = brakingForce
  loaded_advanced_tank.friction_force = loadedFriction
  if loaded_advanced_tank.weight > maxWagonWeight then
    data.raw["cargo-wagon"]["loaded-vehicle-wagon-kr-advanced-tank"] = nil
  end
end
