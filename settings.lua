--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: settings.lua
 * Description: Settings to control Vehicle Wagon prototypes and operation.
--]]

data:extend({
  {
    type = "string-setting",
    name = "vehicle-wagon-inventory-slots",
    order = "aa",
    setting_type = "startup",
    default_value = "none",
    allowed_values = {
      "full-and-empty",
      "full-only",
      "none",
    },
  },
  {
    type = "bool-setting",
    name = "vehicle-wagon-compatibility-entities",
    order = "ab",
    setting_type = "startup",
    default_value = false,
  },
  {
    type = "bool-setting",
    name = "vehicle-wagon-use-custom-weights",
    order = "ba",
    setting_type = "startup",
    default_value = true
  },
  {
    type = "double-setting",
    name = "vehicle-wagon-maximum-weight",
    order = "baa",
    setting_type = "startup",
    default_value = 75000,
    minimum_value = 1000,
    maximum_value = math.huge
  },
  {
    type = "double-setting",
    name = "vehicle-wagon-empty-weight-factor",
    order = "bb",
    setting_type = "startup",
    default_value = 0.25,
    minimum_value = 0.1,
    maximum_value = 2.0
  },
  {
    type = "double-setting",
    name = "vehicle-wagon-vehicle-weight-factor",
    order = "bc",
    setting_type = "startup",
    default_value = 1.0,
    minimum_value = 0,
    maximum_value = 5.0
  },
  {
    type = "double-setting",
    name = "vehicle-wagon-braking-factor",
    order = "bd",
    setting_type = "startup",
    default_value = 2.0,
    minimum_value = 0.5,
    maximum_value = 5.0
  },
  {
    type = "double-setting",
    name = "vehicle-wagon-empty-friction-factor",
    order = "be",
    setting_type = "startup",
    default_value = 0.25,
    minimum_value = 0.1,
    maximum_value = 5.0
  },
  {
    type = "double-setting",
    name = "vehicle-wagon-loaded-friction-factor",
    order = "bf",
    setting_type = "startup",
    default_value = 1.5,
    minimum_value = 0.1,
    maximum_value = 5.0
  },
})

data:extend({
  {
  type = "bool-setting",
  name = "vehicle-wagon-use-GCKI-permissions",
  order = "cc",
  setting_type = "runtime-global",
  default_value = true
  },
})
