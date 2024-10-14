--[[ Copyright (c) 2024 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: hiddensurface.lua
 * Description: Creates and maintains the hidden surface where loaded vehicles are stored.
 ]]--


function getHiddenSurface()
  -- Check if the surface already exists
  if not game.surfaces[VWSURF] then
    log("Creating Vehicle Wagon Surface")
    local surface = game.create_surface(VWSURF, {
        width=160,
        height=160,
        terrain_segmentation = 1,
        water = 0,
        autoplace_controls = {},
        default_enable_all_autoplace_controls = false,
        autoplace_settings = {},
        cliff_settings = nil,
        seed = 0,
        starting_area = 0,
        starting_points = {},
        peaceful_mode = true,
        property_expression_names = {}
      }
    )
    surface.request_to_generate_chunks({0,0},6)
    surface.force_generate_chunk_requests()
  end
  return game.surfaces[VWSURF]
end

function getTeleportCoordinate()
  return {x=math.random()*120-60,y=math.random()*120-60}
end

