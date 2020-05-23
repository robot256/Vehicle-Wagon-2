--[[ Copyright (c) 2020 robot256 (MIT License)
 * Project: Vehicle Wagon 2 rewrite
 * File: data.lua
 * Description:  Main Data Stage function.  Include all the prototype definitions.
 --]]

require("config")

require("prototypes.beams")
require("prototypes.items")
require("prototypes.entities")
require("prototypes.recipes")
require("prototypes.sounds")
require("prototypes.technologies")
require("prototypes.sprites")

-- After entities are added, calculate the weights and forces based on mod settings
require("prototypes.update_stats")
