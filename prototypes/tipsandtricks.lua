-- tipsandtricks for vehiclewagon2


local loading_sim = 
{
  init =
  [[
    require("__VehicleWagon2__/config")
    require("__VehicleWagon2__/script/renderVisuals.lua")
    storage.player = game.simulation.create_test_player{name = "robot256"}
    storage.character = storage.player.character
    game.simulation.camera_player = storage.player
    game.simulation.camera_zoom = 1
    local surface = game.surfaces[1]
    surface.build_checkerboard{{-12, -6}, {12, 6}}
    surface.create_entities_from_blueprint_string
    {
      string =  "0eNq9lG1vgyAQx7/LvaZGVJT6VZbFoKWWFKEBbNc0fveBbm2zuYxkyV7ecfn974m7QStHfjJCOahvIDqtLNQvN7CiV0wGn2IDhxoMExImBELt+BvUeEIrQWd+EJ3kmwvrtXqKzqZXBFw54QRf+LNxbdQ4tNx4HPpEdMwAgpO2PtYzPDuo4aSoSlJmBMEV6g1JtjjFwZ4Cl7WSN1L3wjrR2eZyEN4e9FmoHmpnRh6S/aKY3RUdU8cVSZrkBD9LVmmV5vgPkvld0jrfzv7gNnNXv2lXi6TvMeyE4d3yVKwgi1jkNhpJ0Po014ZSYVqRB/mXtuyZtByBNsJLsoWUJqHBQp29SxsPUqOUK1mVsYViHF1pFc3Mo5k0mkmimdtoZvzi4DR6zPQfx4xxdK3xG42zWGgWvzw4+jdnP22Pv4nW6e7Y+KurFvfH8Q3e+SfujQ6XGafzuV3cYXQtmwMCQjg++CQedxz5iRo7a2QUFzQnJc1oXpJ0mt4B1Qj3/A==",
      position = {0, 0}
    }
    
    storage.car = surface.find_entity("car",SIM_CARPOS)
    storage.tank = surface.find_entity("tank",SIM_TANKPOS)
    storage.leftwagon = surface.find_entity("vehicle-wagon",SIM_LEFTPOS)
    storage.rightwagon = surface.find_entity("vehicle-wagon",SIM_RIGHTPOS)
    
    storage.car.color = {1,0.5,0.5}
    storage.tank.color = {0.5,0.5,1}
    
    -- Move cursor to car
    step_1 = function()
      storage.character.cursor_stack.set_stack{name = "winch-tool", count = 1}
      script.on_nth_tick(1, function()
        if game.simulation.move_cursor{position = storage.car.position} then
          game.forces.player.chart(surface, {{-12, -6}, {12, 6}})
          step_2()
        end
      end)
    end
    
    -- Wait half a second
    step_2 = function()
      storage.wait = 20
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if storage.wait == 0 then
          step_3()
        end
      end)
    end

    -- Start to select
    step_3 = function()
      if storage.player.input_method ~= defines.input_method.game_controller then
        game.simulation.control_down{control = "select-for-blueprint", notify = true}
      else
        game.simulation.control_press{control = "select-for-blueprint", notify = true}
      end
      
      script.on_nth_tick(1, function()
        step_4()
      end)
    end
    
    -- Finish select (small click)
    step_4 = function()
      if storage.player.input_method ~= defines.input_method.game_controller then
        game.simulation.control_up{control = "select-for-blueprint", notify = false}
      else
        game.simulation.control_press{control = "select-for-blueprint", notify = false}
      end
      
      -- Simulate vehicle being selected
      storage.circle= rendering.draw_circle{
              color=RANGE_COLOR,
              radius=LOADING_DISTANCE,
              filled=true,
              target=storage.car,
              surface=surface,
              draw_on_ground=true
            }
         
      -- Play the selection sound
      surface.play_sound{path = "latch-on", position = storage.car.position}
      
      -- Hover over vehicle 1 second while sound plays
      storage.wait = 40
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if storage.wait == 0 then
          step_5()
        end
      end)
    end
    
    -- Move mouse to wagon
    step_5 = function()
      script.on_nth_tick(1, function()
        if game.simulation.move_cursor{position = storage.leftwagon.position} then
          step_6()
        end
      end)
    end
    
    -- Hover over wagon for a second before clicking
    step_6 = function()
      storage.wait = 20
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if storage.wait == 0 then
          step_7()
        end
      end)
    end
    
    -- Click on wagon
    step_7 = function()
      if storage.player.input_method ~= defines.input_method.game_controller then
        game.simulation.control_down{control = "select-for-blueprint", notify = false}
      else
        game.simulation.control_press{control = "select-for-blueprint", notify = false}
      end
      
      script.on_nth_tick(1, function()
        step_8()
      end)
    end
    
    -- Release mouse button and simulate loading
    step_8 = function()
      if storage.player.input_method ~= defines.input_method.game_controller then
        game.simulation.control_up{control = "select-for-blueprint", notify = false}
      else
        game.simulation.control_press{control = "select-for-blueprint", notify = false}
      end
      
      -- delete the circle
      storage.circle.destroy()
      -- Create the loading ramp
      renderLoadingRamp(storage.leftwagon, storage.car)
      -- Play the loading sound
      storage.player.surface.play_sound{path = "winch-sound", position = storage.leftwagon.position}
      
      storage.wait = UNLOADING_EFFECT_TIME
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if storage.wait == 0 then
          step_9()
        end
      end)
    end
    
    -- Change the entities to simulate loading
    step_9 = function()
      local color = storage.car.color
      storage.car.destroy()
      local wagonpos = storage.leftwagon.position
      storage.leftwagon.destroy()
      storage.leftwagon = surface.create_entity{name="loaded-vehicle-wagon-car", position=wagonpos, color=color, direction=defines.direction.east, create_build_effect_smoke=false, force="player"}
      surface.play_sound({path = "utility/build_medium", position = wagonpos, volume_modifier = 0.7})
      
      storage.wait = 60
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if storage.wait <= 0 and game.simulation.move_cursor{position = {storage.tank.position.x-2,storage.tank.position.y-2}} then
          step_10()
        end
      end)
    end
    
    
    -- Wait half a second
    step_10 = function()
      storage.wait = 15
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if storage.wait == 0 then
          step_11()
        end
      end)
    end

    -- Start to select
    step_11 = function()
      if storage.player.input_method ~= defines.input_method.game_controller then
        game.simulation.control_down{control = "select-for-blueprint", notify = true}
      else
        game.simulation.control_press{control = "select-for-blueprint", notify = true}
      end
      
      script.on_nth_tick(1, function()
        if game.simulation.move_cursor{position = storage.tank.position} then
          step_12()
        end
      end)
    end
    
    -- Move cursor to wagon
    step_12 = function()
      script.on_nth_tick(1, function()
        if game.simulation.move_cursor{position = {storage.rightwagon.position.x+2, storage.rightwagon.position.y+2}} then
          step_13()
        end
      end)
    end
    
    -- Wait half a second
    step_13 = function()
      storage.wait = 15
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if storage.wait == 0 then
          step_14()
        end
      end)
    end
    
    -- Finish select (release)
    step_14 = function()
      if storage.player.input_method ~= defines.input_method.game_controller then
        game.simulation.control_up{control = "select-for-blueprint", notify = false}
      else
        game.simulation.control_press{control = "select-for-blueprint", notify = false}
      end
      storage.player.clear_cursor()
      
      -- Create the loading ramp
      renderLoadingRamp(storage.rightwagon, storage.tank)
      -- Play the loading sound
      storage.player.surface.play_sound{path = "winch-sound", position = storage.rightwagon.position}
      
      storage.wait = UNLOADING_EFFECT_TIME
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if storage.wait == 0 then
          step_15()
        end
      end)
    end
    
    -- Change the entities to simulate loading
    step_15 = function()
      local color = storage.tank.color
      storage.tank.destroy()
      local wagonpos = storage.rightwagon.position
      storage.rightwagon.destroy()
      storage.rightwagon = surface.create_entity{name="loaded-vehicle-wagon-tank", position=wagonpos, color=color, direction=defines.direction.east, create_build_effect_smoke=false, force="player"}
      surface.play_sound({path = "utility/build_medium", position = wagonpos, volume_modifier = 0.7})
      
      storage.wait = 60
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if storage.wait == 0 then
          script.on_nth_tick(1, nil)
        end
      end)
    end
    
    
    step_1()
  ]]
}

local unloading_sim = 
{
  init =
  [[
    require("__VehicleWagon2__/config")
    require("__VehicleWagon2__/script/renderVisuals.lua")
    storage.player = game.simulation.create_test_player{name = "robot256"}
    storage.character = storage.player.character
    game.simulation.camera_player = storage.player
    game.simulation.camera_zoom = 1
    local surface = game.surfaces[1]
    surface.build_checkerboard{{-12, -6}, {12, 6}}
    surface.create_entities_from_blueprint_string
    {
      string = "0eNqtlMGOgyAQht9lztiI1kp9lc3GoM5aUoQG0G7T+O4L2m4P7W449DKBkf8bnPzMFRo54skI5aC6gmi1slB9XMGKXnEZcooPCBUYLiTMBITq8BsqOn8SQOWEE7gqls2lVuPQoPEHyF1pndf2B5csCAInbb1KqwD3pJLABaqEenYnDLbrp+1MnpBZLHIfjcx/kVLzDrtkwoNoJSZn3muVtNw80yndlJSVxaMIKt5IrKXuhXWitfX5IPx+0JNQPVRfXFokoI3w1flKSjcB0GqpTcD6kBLol9gskfu4tHvyIm18KTVK+eIXtrFdoTS6LUU0M49m7qKZRTSzjGbGu4z9bwnH1fEFn73FE9mbPLGP7kv8U6FpLDSLNxqNHhPZX07zc8g63R5rP7vUmr6NsJBdnnjDw4KF+rckuyfzoBcOB3+DxygkMKGxS4GM0S3Lix3LWL4r0nn+AXSvtnU=",
      position = {0, 3}
    }
    
    storage.leftwagon = surface.find_entity("loaded-vehicle-wagon-car",SIM_LEFTPOS)
    storage.rightwagon = surface.find_entity("loaded-vehicle-wagon-tank",SIM_RIGHTPOS)
    storage.leftwagon.color = {1,0.5,0.5}
    storage.rightwagon.color = {0.5,0.5,1}
    
    -- Move mouse to left wagon
    step_1 = function()
      storage.character.cursor_stack.set_stack{name = "winch-tool", count = 1}
      script.on_nth_tick(1, function()
        if game.simulation.move_cursor{position = storage.leftwagon.position} then
          step_2()
        end
      end)
    end
    
    -- Hover over wagon for a second before clicking
    step_2 = function()
      storage.wait = 20
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if storage.wait == 0 then
          step_3()
        end
      end)
    end
    
    -- Click on wagon to select for unloading
    step_3 = function()
      if storage.player.input_method ~= defines.input_method.game_controller then
        game.simulation.control_down{control = "select-for-blueprint", notify = true}
      else
        game.simulation.control_press{control = "select-for-blueprint", notify = true}
      end
      
      script.on_nth_tick(1, function()
        step_4()
      end)
    end
    
    -- Finish selecting wagons (1-tick click)
    step_4 = function()
      if storage.player.input_method ~= defines.input_method.game_controller then
        game.simulation.control_up{control = "select-for-blueprint", notify = false}
      else
        game.simulation.control_press{control = "select-for-blueprint", notify = false}
      end
      
      -- Simulate vehicle being selected
      storage.drawings = renderWagonVisuals(nil, storage.leftwagon, prototypes.entity["car"].radius)
      
      -- Play the selection sound
      surface.play_sound{path = "latch-on", position = storage.leftwagon.position}
      
      -- Hover over wagon while sound plays
      storage.wait = 40
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if storage.wait == 0 then
          step_5()
        end
      end)
    end
    
    -- Move to unload position
    step_5 = function()
      script.on_nth_tick(1, function()
        if game.simulation.move_cursor{position = SIM_CARPOS} then
          step_6()
        end
      end)
    end
    
    -- Hover for a second before clicking
    step_6 = function()
      storage.wait = 30
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if storage.wait == 0 then
          step_7()
        end
      end)
    end
    
    -- Click on point
    step_7 = function()
      if storage.player.input_method ~= defines.input_method.game_controller then
        game.simulation.control_down{control = "select-for-blueprint", notify = true}
      else
        game.simulation.control_press{control = "select-for-blueprint", notify = true}
      end
      
      script.on_nth_tick(1, function()
        step_8()
      end)
    end
    
    -- Release mouse button and create ramp
    step_8 = function()
      if storage.player.input_method ~= defines.input_method.game_controller then
        game.simulation.control_up{control = "select-for-blueprint", notify = false}
      else
        game.simulation.control_press{control = "select-for-blueprint", notify = false}
      end
      
      -- delete the graphics
      if storage.drawings then
        for _,d in pairs(storage.drawings) do
          d.destroy()
        end
      end
      
      -- Create the loading ramp
      renderUnloadingRamp(storage.leftwagon, SIM_CARPOS, prototypes.entity["car"].radius)
      -- Play the loading sound
      storage.player.surface.play_sound{path = "winch-sound", position = storage.leftwagon.position}
      
      storage.wait = UNLOADING_EFFECT_TIME
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        game.simulation.move_cursor{position={0,0}}
        if storage.wait == 0 then
          step_9()
        end
      end)
    end
    
    -- Change the entities to simulate unloading
    step_9 = function()
      local wagonpos = storage.leftwagon.position
      local color = storage.leftwagon.color
      storage.leftwagon.destroy()
      storage.leftwagon = surface.create_entity{name="vehicle-wagon", position=wagonpos, direction=defines.direction.east, create_build_effect_smoke=false, force="player"}
      storage.car = surface.create_entity{name="car", position=SIM_CARPOS, direction = defines.direction.north, create_build_effect_smoke=false, force="player"}
      storage.car.color = color
      surface.play_sound({path = "utility/build_medium", position = wagonpos, volume_modifier = 0.7})
      
      storage.wait = 60
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if game.simulation.move_cursor{position = storage.rightwagon.position} and storage.wait <= 0 then
          step_10()
        end
      end)
    end
    
    -- Hover over wagon for a second before clicking
    step_10 = function()
      storage.wait = 20
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if storage.wait == 0 then
          step_11()
        end
      end)
    end
    
    -- Click on wagon to select for unloading
    step_11 = function()
      if storage.player.input_method ~= defines.input_method.game_controller then
        game.simulation.control_down{control = "select-for-blueprint", notify = true}
      else
        game.simulation.control_press{control = "select-for-blueprint", notify = true}
      end
      
      script.on_nth_tick(1, function()
        step_12()
      end)
    end
    
    -- Finish selecting wagons (1-tick click)
    step_12 = function()
      if storage.player.input_method ~= defines.input_method.game_controller then
        game.simulation.control_up{control = "select-for-blueprint", notify = false}
      else
        game.simulation.control_press{control = "select-for-blueprint", notify = false}
      end
      
      -- Simulate vehicle being selected
      storage.drawings = renderWagonVisuals(nil, storage.rightwagon, prototypes.entity["tank"].radius)
      
      -- Play the selection sound
      surface.play_sound{path = "latch-on", position = storage.rightwagon.position}
      
      -- Hover over wagon while sound plays
      storage.wait = 40
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if storage.wait == 0 then
          step_13()
        end
      end)
    end
    
    -- Move to unload position
    step_13 = function()
      script.on_nth_tick(1, function()
        if game.simulation.move_cursor{position = SIM_TANKPOS} then
          step_14()
        end
      end)
    end
    
    -- Hover ofor a second before clicking
    step_14 = function()
      storage.wait = 30
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if storage.wait == 0 then
          step_15()
        end
      end)
    end
    
    -- Click on point
    step_15 = function()
      if storage.player.input_method ~= defines.input_method.game_controller then
        game.simulation.control_down{control = "select-for-blueprint", notify = true}
      else
        game.simulation.control_press{control = "select-for-blueprint", notify = true}
      end
      
      script.on_nth_tick(1, function()
        step_16()
      end)
    end
    
    -- Release mouse button and create ramp
    step_16 = function()
      if storage.player.input_method ~= defines.input_method.game_controller then
        game.simulation.control_up{control = "select-for-blueprint", notify = false}
      else
        game.simulation.control_press{control = "select-for-blueprint", notify = false}
      end
      
      -- delete the graphics
      if storage.drawings then
        for _,d in pairs(storage.drawings) do
          d.destroy()
        end
      end
      
      -- Create the loading ramp
      renderUnloadingRamp(storage.rightwagon, SIM_TANKPOS, prototypes.entity["tank"].radius)
      -- Play the loading sound
      storage.player.surface.play_sound{path = "winch-sound", position = storage.rightwagon.position}
      
      storage.wait = UNLOADING_EFFECT_TIME
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        game.simulation.move_cursor{position={0,0}}
        if storage.wait == 0 then
          step_17()
        end
      end)
    end
    
    -- Change the entities to simulate unloading
    step_17 = function()
      local wagonpos = storage.rightwagon.position
      local color = storage.rightwagon.color
      storage.rightwagon.destroy()
      storage.rightwagon = surface.create_entity{name="vehicle-wagon", position=wagonpos, direction=defines.direction.east, create_build_effect_smoke=false, force="player"}
      storage.tank = surface.create_entity{name="tank", position=SIM_TANKPOS, direction = defines.direction.north, create_build_effect_smoke=false, force="player"}
      storage.tank.color = color
      surface.play_sound({path = "utility/build_medium", position = wagonpos, volume_modifier = 0.7})
      
      storage.wait = 30
      script.on_nth_tick(1, function()
        storage.wait = storage.wait - 1
        if storage.wait == 0 then
          storage.player.clear_cursor()
          script.on_nth_tick(1,nil)
        end
      end)
    end
    
    step_1()
  ]]

}


local vw_tip_trigger = {
      type = "or",
      triggers = {
        --{
        --  type = "unlock-recipe",
        --  recipe = "vehicle-wagon"
        --},
        {
          type = "build-entity",
          entity = "vehicle-wagon"
        }
      }
    }

data.extend{
  {
    type = "tips-and-tricks-item-category",
    name = "vehicle-wagon",
    order = "f-[trains]-[vehicle-wagon]"
  },
  {
    type = "tips-and-tricks-item",
    name = "vehicle-wagon",
    tag = "[entity=vehicle-wagon]",
    category = "vehicle-wagon",
    order = "a",
    is_title = true,
    trigger = vw_tip_trigger,
    simulation = loading_sim
  },
  {
    type = "tips-and-tricks-item",
    name = "vehicle-wagon-unload",
    tag = "[item=winch-tool]",
    category = "vehicle-wagon",
    order = "b",
    is_title = false,
    indent = 1,
    trigger = vw_tip_trigger,
    simulation = unloading_sim
  },
}
