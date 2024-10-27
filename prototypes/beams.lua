--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: beams.lua
 * Description: Prototype definitions of loading ramp beams.
--]]

local ramp_blend_mode = "normal"
local ramp_scale = 1
local ramp_speed = 0.25

data:extend{
  {
    type = "beam",
    name = "loading-ramp-beam",
    flags = {"not-on-map"},
    width = 1,
    damage_interval = 20,
    random_target_offset = false,
    action_triggered_automatically = false,
    action =
    {
      type = "direct",
      action_delivery =
      {
        type = "instant",
        target_effects =
        {
          {
            type = "damage",
            damage = { amount = 0, type = "laser"}
          }
        }
      }
    },
    graphics_set = {
      beam = {
        render_layer = "transport-belt",
        head =
        {
          filename = "__vehicle-wagon-graphics__/graphics/ramp/loading-ramp-head.png",
          flags = beam_non_light_flags,
          line_length = 16,
          width = 32,
          height = 26,
          frame_count = 16,
          scale = ramp_scale,
          animation_speed = ramp_speed,
          blend_mode = ramp_blend_mode
        },
        tail =
        {
          filename = "__vehicle-wagon-graphics__/graphics/ramp/loading-ramp-tail.png",
          flags = beam_non_light_flags,
          line_length = 16,
          width = 32,
          height = 26,
          frame_count = 16,
          scale = ramp_scale,
          animation_speed = ramp_speed,
          --shift = util.by_pixel(11.5, 1),
          blend_mode = ramp_blend_mode
        },
        body =
        {
          {
            filename = "__vehicle-wagon-graphics__/graphics/ramp/loading-ramp-body.png",
            flags = beam_non_light_flags,
            line_length = 16,
            width = 32,
            height = 26,
            frame_count = 16,
            scale = ramp_scale,
            animation_speed = ramp_speed,
            apply_runtime_tint = true,
            --tint = {r=1, g=1, b=1, a=0.8},
            blend_mode = ramp_blend_mode
          }
        }
      }
    }
  },
  {
    type = "beam",
    name = "unloading-ramp-beam",
    flags = {"not-on-map"},
    width = 1,
    damage_interval = 20,
    random_target_offset = false,
    action_triggered_automatically = false,
    action =
    {
      type = "direct",
      action_delivery =
      {
        type = "instant",
        target_effects =
        {
          {
            type = "damage",
            damage = { amount = 0, type = "laser"}
          }
        }
      }
    },
    graphics_set = {
      beam = {
        render_layer = "transport-belt",
        head =
        {
          filename = "__vehicle-wagon-graphics__/graphics/ramp/unloading-ramp-head.png",
          flags = beam_non_light_flags,
          line_length = 16,
          width = 32,
          height = 26,
          frame_count = 16,
          scale = ramp_scale,
          animation_speed = ramp_speed,
          blend_mode = ramp_blend_mode
        },
        tail =
        {
          filename = "__vehicle-wagon-graphics__/graphics/ramp/unloading-ramp-tail.png",
          flags = beam_non_light_flags,
          line_length = 16,
          width = 32,
          height = 26,
          frame_count = 16,
          scale = ramp_scale,
          animation_speed = ramp_speed,
          --shift = util.by_pixel(11.5, 1),
          blend_mode = ramp_blend_mode
        },
        body =
        {
          {
            filename = "__vehicle-wagon-graphics__/graphics/ramp/unloading-ramp-body.png",
            flags = beam_non_light_flags,
            line_length = 16,
            width = 32,
            height = 26,
            frame_count = 16,
            scale = ramp_scale,
            animation_speed = ramp_speed,
            apply_runtime_tint = true,
            --tint = {r=1, g=1, b=1, a=0.8},
            blend_mode = ramp_blend_mode
          }
        }
      }
    }
  },
}
  
