--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: items.lua
 * Description:  Add item prototypes.
 *   Items added:
 *    - Vehicle Wagon (empty)
 *    - Loaded Vehicle Wagon (Car)
 *    - Loaded Vehicle Wagon (Tank)
 *    - Loaded Vehicle Wagon (Tarp)
 *    - Winch (selection tool)
 *    - Loaded Vehicle Wagon (Truck)
 *    - Loaded Vehicle Wagon (Cargo Plane)
 *    - Loaded Vehicle Wagon (Gunship)
 *    - Loaded Vehicle Wagon (Jet)
--]]


data:extend{
  {
		type = "selection-tool",
		name = "winch-tool",
		icon = "__VehicleWagon2__/graphics/winch-icon.png",
		icon_size = 64,
    stack_size = 1,
    flags = {"only-in-cursor", "not-stackable", "spawnable"},
    subgroup = "spawnables",
    select = {
      border_color = {r=0.75, g=0.75},
      cursor_box_type = "entity",
      mode = "any-entity",
      entity_type_filters = {"cargo-wagon","car","spider-vehicle"},
    },
    alt_select = {
      border_color = {g=1},
      cursor_box_type = "entity",
      mode = "any-entity",
      entity_type_filters = {"cargo-wagon","car","spider-vehicle"},
    },
    inventory_move_sound = "__VehicleWagon2__/sound/latchOff.ogg",
    pick_sound = "__VehicleWagon2__/sound/latchOn.ogg",
    drop_sound = "__VehicleWagon2__/sound/latchOff.ogg",
    
	},
  {
    type = "shortcut",
    name = "winch-tool",
    icon = "__VehicleWagon2__/graphics/winch-shortcut.png",
		icon_size = 64,
    small_icon = "__VehicleWagon2__/graphics/winch-shortcut.png",
		small_icon_size = 64,
    action = "spawn-item",
    item_to_spawn = "winch-tool",
    technology_to_unlock = "vehicle-wagons",
    unavailable_until_unlocked = true,
    associated_control_input = "winch-tool",
  },
  {
    type = "custom-input",
    name = "winch-tool",
    key_sequence = "",
    action = "spawn-item",
    item_to_spawn = "winch-tool",
  }
}

data:extend{
	{
		type = "item-with-entity-data",
		name = "vehicle-wagon",
		icon = "__VehicleWagon2__/graphics/tech-icon.png",
		icon_size = 128,
    subgroup = "transport",
		order = "a[train-system]-v[vehicle-wagon]",
		place_result = "vehicle-wagon",
		stack_size = 5
	},
}
