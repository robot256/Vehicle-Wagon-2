

--[[
Inserter vector checks:

From @Bilka:

InserterPrototype::VectorResult InserterPrototype::isPickupDropoffVectorValid(Vector checkVector) const
{
  TilePosition size = this->tileGridSize(Direction::North);

  checkVector.x += size.x / 2.0;
  checkVector.y += size.y / 2.0;
  return InserterPrototype::isPickupDropoffPositionValid(checkVector);
}

InserterPrototype::VectorResult InserterPrototype::isPickupDropoffPositionValid(Vector checkVector)
{
  double intPart;  -- This is just trash to make modf work. Only the floating parts are saved
  float intPartFloat;  -- This is just trash to make modf work. Only the floating parts are saved
  checkVector.x = std::modf(float(std::modf(std::modf(checkVector.x, &intPart) + double(1.0), &intPart)), &intPartFloat);
  checkVector.y = std::modf(float(std::modf(std::modf(checkVector.y, &intPart) + double(1.0), &intPart)), &intPartFloat);
  if (checkVector.x <= ItemEntityPrototype::size.getDouble() + 0.01 ||
                                   (0.14*2)+0.01             + 0.01 = 0.3
    checkVector.y <= ItemEntityPrototype::size.getDouble() + 0.01 ||
    checkVector.x >= 1 - ItemEntityPrototype::size.getDouble() - 0.01 ||
                     1 -           (0.14*2)+0.01               - 0.01 = 0.72
    checkVector.y >= 1 - ItemEntityPrototype::size.getDouble() - 0.01)
    return VectorResult::TooCloseToTileEdge;

ItemEntityPrototype are items on ground (ItemEntityPrototype::size = this->collisionBoundingBox.getWidth() + 0.01; where this is an item-entity) 
"item-on-ground" collision_box = {{-0.14, -0.14}, {0.14, 0.14}}
--------------------

checkVector = insert_position
checkVector += x_tile_radius, y_tile_radius
                  2               2

isPickupDropoffPositionValid:
The modf nonsense just shifts checkVector by an integer number of tiles into the range x=[0,1), y=[0,1)
Then checks if checkVector is inside the bounding box:
(x or y <= 0.3) or (x or y >= 0.72)  THEN BAD VECTOR


So if I input a vector {0, -2.2}:
-2.2 + 2 = -0.2
shifted to [0,1) = +0.8
0.8 >= 0.72 so invalid

Try {0, -2.0}
-2 + 2 = 0
0 <= 0.3 so invalid

Try {0, -2.45}
-2.45 + 2 = -0.45
shifted to [0,1) = +0.55

Oh derp.  It's the 0 isn't it.
0 + 2 = 2
shifted to [0,1) = 0
0 <= 0.3 so invalid

--]]



data:extend{ 
  {
    type = "inserter",
    name = "loading-ramp",
    icons = {{icon = "__base__/graphics/icons/shapes/shape-circle.png",
              tint = {1,1,0,1}},
             {icon = "__base__/graphics/icons/shapes/shape-diagonal-cross.png",
              tint = {1,1,0,1}}},
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 1, result = "loading-ramp"},
    max_health = 1000,
    resistances =
    {
      {
        type = "fire",
        percent = 90
      }
    },
    collision_mask = {layers={rail=true}},
    collision_box = {{-1.4, -1.4}, {1.4, 1.4}},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},    
    selection_priority = 43,  -- less than "item-on-ground"
    build_grid_size = 1,
    draw_inserter_arrow = true,
    extension_speed = 0.035,
    rotation_speed = 0.014,
    pickup_position = {0, 2.1},
    insert_position = {0, -2.1},
    platform_picture = table.deepcopy(data.raw.inserter.inserter.platform_picture),
    open_sound = table.deepcopy(data.raw.inserter.inserter.open_sound),
    close_sound = table.deepcopy(data.raw.inserter.inserter.close_sound),
    energy_source = {type = "void"},
    circuit_connector = circuit_connector_definitions["storage-tank"],
    circuit_wire_max_distance = 9,
    allow_custom_vectors = true,
    use_easter_egg = false,
    filter_count = 5,
  },
  {
    type = "container",
    name = "vw-dummy-chest",
    icon = "__base__/graphics/icons/wooden-chest.png",
    hidden = true,
    inventory_size = 1,
    inventory_type = "normal",
    max_health = 1000,
    collision_mask = {layers={}},
    collision_box = {{-0.4,-0.4},{0.4,0.4}},
    --selection_box = {{-0.5,-0.5},{0.5,0.5}},
    selection_priority = 30,
    selectable_in_game = false,
    flags = {"placeable-neutral",
             "placeable-off-grid",
             "not-on-map",
             "not-deconstructable",
             "not-blueprintable",
             "hide-alt-info",
             "not-flammable",
             "no-automated-item-insertion"},
  },
  {
		type = "item",
		name = "loading-ramp",
		icons = {{icon = "__base__/graphics/icons/shapes/shape-circle.png",
              tint = {1,1,0,1}},
             {icon = "__base__/graphics/icons/shapes/shape-diagonal-cross.png",
              tint = {1,1,0,1}}},
    subgroup = "transport",
		order = "a[train-system]-w[loading-ramp]",
		place_result = "loading-ramp",
		stack_size = 5
	},
  {
    type = "recipe",
    name = "loading-ramp",
    enabled = false,
    energy_required = 1,
    ingredients = {{type="item", name="iron-plate", amount=10}},
    results = {{type="item", name="loading-ramp", amount=1}}
  }
}

data.raw.inserter["loading-ramp"].platform_picture.sheet.scale = data.raw.inserter["loading-ramp"].collision_box[2][1]

data:extend({
  {
    type = "technology",
    name = "vehicle-loading-ramps",
    icon = "__vehicle-wagon-graphics__/graphics/tech-icon.png",
    icon_size = 128,
    effects =
    {
      {
        type = "unlock-recipe",
        recipe = "loading-ramp"
      },
    },
    prerequisites = {"vehicle-wagons"},
    unit =
    {
      count = 100,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
      },
      time = 30
    },
    order = "c-w-b",
  },
})
