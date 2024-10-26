--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: renderVisuals.lua
 * Description: Render drawing functions to show loading and unloading range around selected entities.
--]]

  

function rot(p,a)
  return {x=p.x*math.cos(a)-p.y*math.sin(a), y=p.x*math.sin(a)+p.y*math.cos(a)}
end

function dist2(a,b)
  return (a.x - b.x)^2 + (a.y - b.y)^2
end

function distance(a,b)
  return math.sqrt(dist2(a,b))
end

function closestPointOnLine(v,w,p)
  -- Now find the distance from the point to the line
  local len2 = dist2(v, w)
  local t = ((p.x - v.x)*(w.x - v.x) + (p.y - v.y)*(w.y - v.y)) / len2
  t = math.max(0, math.min(1,t))
  return {x=v.x + t*(w.x - v.x), y=v.y + t*(w.y - v.y)}
end

-- Cribbed from https://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment
function distToLine(v,w,p)
  return distance(p, closestPointOnLine(v,w,p))
end

function distToWagon(wagon,p)
  if not wagon or not wagon.valid or not p then
    return nil
  end
  local length_front = wagon.prototype.collision_box.left_top.y
  local length_back  = wagon.prototype.collision_box.right_bottom.y
  local wagon_angle  = wagon.orientation*2*math.pi
  local v = {x=-length_front*math.sin(wagon_angle)+wagon.position.x, y=length_front*math.cos(wagon_angle)+wagon.position.y}
  local w = {x=-length_back*math.sin(wagon_angle)+wagon.position.x,  y=length_back*math.cos(wagon_angle)+wagon.position.y}
  -- Now find the distance from the point to the centerline of collision box
  return distToLine(v,w,p)
end

-- Cribbed from https://ideone.com/PnPJgb
-- linked from https://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect
function LinesIntersect(A,B,C,D)

  local CmP = {x= C.x - A.x, y= C.y - A.y}
  local r = {x= B.x - A.x, y= B.y - A.y}
  local s = {x= D.x - C.x, y= D.y - C.y}

  local CmPxr = CmP.x * r.y - CmP.y * r.x
  local CmPxs = CmP.x * s.y - CmP.y * s.x
  local rxs = r.x * s.y - r.y * s.x

  if CmPxr == 0 then
  
    -- Lines are collinear, and so intersect if they have any overlap
    -- This isn't a case we need to worry about
    --return ((C.x - A.x < 0f) != (C.x - B.x < 0f))
    --  || ((C.y - A.y < 0f) != (C.y - B.y < 0f));
    return nil
  end
  
  if rxs == 0 then
    return nil; -- Lines are parallel.
  end
  
  local rxsr = 1 / rxs;
  local t = CmPxs * rxsr;
  local u = CmPxr * rxsr;

  -- Confirm the intersection point is within both line segments
  if (t >= 0) and (t <= 1) and (u >= 0) and (u <= 1) then
    return {x= A.x + (B.x - A.x) * t, y= A.y + (B.y - A.y) * t}
  end
  return nil
end




-- function clearVisuals: Remove any rendered objects associated with this player's selection
-- p: player or player_index
function clearVisuals(p)
  local player_index = p
  if type(p) ~= "number" then
    player_index = p.index
  end
  if storage.player_selection[player_index] and storage.player_selection[player_index].visuals then
    for id,obj in pairs(storage.player_selection[player_index].visuals) do
      obj.destroy()
    end
  end
end


-- function renderVehicleRange: Display the loading area around the selected vehicle
-- p: player or player_index
-- target: selected entity to track
function renderVehicleVisuals(p, target)
  -- First clear existing renders for this player
  clearVisuals(p)
  
  -- Then create circle for player
  return { 
            rendering.draw_circle{
              color=RANGE_COLOR,
              radius=LOADING_DISTANCE,
              filled=true,
              target=target,
              surface=target.surface,
              players={p},
              draw_on_ground=true
            }
         }
end

-- function renderWagonRange: Display the unloading area around the selected wagon
-- p: player or player_index
-- target: selected entity to track
function renderWagonVisuals(p, target, vehicle_radius)
  -- First clear existing renders for this player
  if p then
    clearVisuals(p)
  end
  
  if not vehicle_radius then
    vehicle_radius = 0
  end
  
  -- Now create a rotated polygon with semicircles on either end
  -- Entity is referenced in the North orientation before being rotated
  local length_front = target.prototype.collision_box.left_top.y
  local length_back  = target.prototype.collision_box.right_bottom.y
  local wagon_angle  = target.orientation*2*math.pi
  local wagon_front  = rot({x=0,y=length_front},wagon_angle)
  local wagon_back   = rot({x=0,y=length_back},wagon_angle)
  local min_distance = vehicle_radius + math.abs(target.prototype.collision_box.right_bottom.x)
  local max_distance = vehicle_radius + UNLOAD_RANGE
  
  local visuals = {
    rendering.draw_polygon{
      color=RANGE_COLOR,
      vertices={{position={max_distance,length_back}},
                {position={min_distance,length_back}},
                {position={max_distance,length_front}},
                {position={min_distance,length_front}}},
      target=target,
      orientation_target=target,
      use_target_orientation=true,
      surface=target.surface,
      players=p and {p},
      draw_on_ground=true
    },
    rendering.draw_polygon{
      color=RANGE_COLOR,
      vertices={{position={-min_distance,length_back}},
                {position={-max_distance,length_back}},
                {position={-min_distance,length_front}},
                {position={-max_distance,length_front}}},
      target=target,
      orientation_target=target,
      use_target_orientation=true,
      surface=target.surface,
      players=p and {p},
      draw_on_ground=true
    },
    rendering.draw_arc{
      color=RANGE_COLOR,
      max_radius=max_distance,
      min_radius=min_distance,
      start_angle=wagon_angle+math.pi,
      angle=math.pi,
      target={entity=target, offset=wagon_front},
      surface=target.surface,
      players=p and {p},
      draw_on_ground=true
    },
    rendering.draw_arc{
      color=RANGE_COLOR,
      max_radius=max_distance,
      min_radius=min_distance,
      start_angle=wagon_angle,
      angle=math.pi,
      target={entity=target, offset=wagon_back},
      surface=target.surface,
      players=p and {p},
      draw_on_ground=true
    },
    rendering.draw_polygon{
      color=KEEPOUT_RANGE_COLOR,
      vertices={{position={min_distance,length_back}},
                {position={-min_distance,length_back}},
                {position={min_distance,length_front}},
                {position={-min_distance,length_front}}},
      target=target,
      orientation_target=target,
      use_target_orientation=true,
      surface=target.surface,
      players=p and {p},
      draw_on_ground=true
    },
    rendering.draw_arc{
      color=KEEPOUT_RANGE_COLOR,
      max_radius=min_distance,
      min_radius=0,
      start_angle=wagon_angle+math.pi,
      angle=math.pi,
      target={entity=target, offset=wagon_front},
      surface=target.surface,
      players=p and {p},
      draw_on_ground=true
    },
    rendering.draw_arc{
      color=KEEPOUT_RANGE_COLOR,
      max_radius=min_distance,
      min_radius=0,
      start_angle=wagon_angle,
      angle=math.pi,
      target={entity=target, offset=wagon_back},
      surface=target.surface,
      players=p and {p},
      draw_on_ground=true
    }
  }

  return visuals
end

function renderLoadingRamp(wagon, vehicle)
  local length_front = wagon.prototype.collision_box.left_top.y*0.8
  local length_back  = wagon.prototype.collision_box.right_bottom.y*0.8
  local wagon_angle  = wagon.orientation*2*math.pi
  local wagon_front  = rot({x=0,y=length_front},wagon_angle)
  local wagon_back   = rot({x=0,y=length_back},wagon_angle)
  local points = {{x=BED_WIDTH,y=length_back},
                  {x=-BED_WIDTH,y=length_back},
                  {x=BED_WIDTH,y=length_front},
                  {x=-BED_WIDTH,y=length_front}}
  local edges = {{1,2},{1,3},{3,4},{2,4}}
  local p = {x=vehicle.position.x - wagon.position.x, y=vehicle.position.y - wagon.position.y}
  
  local closest_point = nil
  local closest_distance = math.huge
  
  for i,edge in pairs(edges) do
    local from_offset=rot(points[edge[1]],wagon_angle)
    from_offset.y = from_offset.y + BED_CENTER_OFFSET
    local to_offset=rot(points[edge[2]],wagon_angle)
    to_offset.y = to_offset.y + BED_CENTER_OFFSET
    
    local cross = LinesIntersect(from_offset, to_offset, p, {x=0,y=BED_CENTER_OFFSET})
    if cross then
      closest_point = cross
      break
    end
  end
  
 
  if closest_point then
    local radius = vehicle.get_radius()
    local source_point = {x=wagon.position.x + closest_point.x, y=wagon.position.y + closest_point.y}
    local d = distance(vehicle.position, source_point)
    local new_d = math.max(MIN_LOADING_RAMP_LENGTH, d - radius + 0.25)
    local ratio = new_d / d
    local delta = {x=source_point.x-vehicle.position.x, y=source_point.y-vehicle.position.y}
    local new_delta = {x=delta.x * ratio, y=delta.y * ratio}
    local new_target = {x=source_point.x-new_delta.x, y=source_point.y-new_delta.y}
    
    return wagon.surface.create_entity{
        name="loading-ramp-beam",
        position=wagon.position,
        target_position = new_target,
        source_position = source_point,
        duration = LOADING_EFFECT_TIME+EXTRA_RAMP_TIME
    }
  else
    return nil
  end
end

function renderUnloadingRamp(wagon, position, vehicle_radius)
  
  if not vehicle_radius then
    vehicle_radius = 0
  end
  
  local length_front = wagon.prototype.collision_box.left_top.y*0.8
  local length_back  = wagon.prototype.collision_box.right_bottom.y*0.8
  local wagon_angle  = wagon.orientation*2*math.pi
  local wagon_front  = rot({x=0,y=length_front},wagon_angle)
  local wagon_back   = rot({x=0,y=length_back},wagon_angle)
  local points = {{x=BED_WIDTH,y=length_back},
                  {x=-BED_WIDTH,y=length_back},
                  {x=BED_WIDTH,y=length_front},
                  {x=-BED_WIDTH,y=length_front}}
  local edges = {{1,2},{1,3},{3,4},{2,4}}
  local p = {x=position.x - wagon.position.x, y=position.y - wagon.position.y}
  
  local closest_point = nil
  
  for i,edge in pairs(edges) do
    local from_offset=rot(points[edge[1]],wagon_angle)
    from_offset.y = from_offset.y + BED_CENTER_OFFSET
    local to_offset=rot(points[edge[2]],wagon_angle)
    to_offset.y = to_offset.y + BED_CENTER_OFFSET
    
    local cross = LinesIntersect(from_offset, to_offset, p, {x=0,y=BED_CENTER_OFFSET})
    if cross then
      closest_point = cross
      break
    end
  end
  
  if closest_point then
    local source_point = {x=wagon.position.x + closest_point.x, y=wagon.position.y + closest_point.y}
    local d = distance(position, source_point)
    local new_d = math.max(MIN_LOADING_RAMP_LENGTH, d - vehicle_radius + 0.25)
    local ratio = new_d / d
    local delta = {x=source_point.x-position.x, y=source_point.y-position.y}
    local new_delta = {x=delta.x * ratio, y=delta.y * ratio}
    local new_target = {x=source_point.x-new_delta.x, y=source_point.y-new_delta.y}
    
    return wagon.surface.create_entity{
        name="unloading-ramp-beam",
        position=wagon.position,
        source_position=source_point,
        target_position=new_target,
        duration=UNLOADING_EFFECT_TIME+EXTRA_RAMP_TIME
    }
  else
    return nil
  end
end

function renderIcon(target, contents)
  -- Check that target entity exists, and contents entity/icon is loaded in the game.
  if target and prototypes.entity[contents] then
    -- Create icon showing contents (will be deleted automatically when wagon is destroyed or unloaded)
    local visuals = {
      rendering.draw_sprite{
        sprite="vw2-bg-icon",
        x_scale=1.6,
        y_scale=1.6,
        render_layer="entity-info-icon",
        target={entity=target, offset={0,BED_CENTER_OFFSET}},
        surface=target.surface,
        only_in_alt_mode=true
      },
      rendering.draw_sprite{
        sprite="entity."..contents,
        x_scale=1.2,
        y_scale=1.2,
        render_layer="entity-info-icon",
        target={entity=target, offset={0,BED_CENTER_OFFSET}},
        surface=target.surface,
        only_in_alt_mode=true
      }
    }
    return visuals
  end
end

function clearIcon(wagon_data)
  -- Remove icon from vehicle by destroying the render objects
  if not wagon_data.icon then return end
  for _,object in pairs(wagon_data.icon) do
    -- Support legacy structures where rendering items were referenced only by id
    if type(object) == "number" then
      object = rendering.get_object_by_id(object)
    end
    if object and object.valid then
      object.destroy()
    end
  end
  wagon_data.icon = nil
end
