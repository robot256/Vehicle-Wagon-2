Vehicle Wagon 3.1.21
===================

Version 3.1.21 was released November 11, 2021, was tested using Factorio v1.1.1, and was authored by robot256 based on the original mod of Supercheese and original graphics from YuokiTani and others.
Additional contributions from: CrazyMooncat, The_Destroyer, Phasma Felis, Brant Wedel, legendblade, narc, Artanis_Mattias, ST-DDT.

This mod allows you to load your fully-laden car or tank onto a flatbed train wagon and take it with you on your rail journeys!
Just use the Winch to haul your vehicle onto the wagon, and use the same Winch to unload it when you're ready to drive away.
No more tedious re-inserting ammo, fuel, etc. into your combat vehicle after a long trip by rail to some remote outpost!

This mod should play well with other tank, car, and spidertron mods, and has been successfully tested with the following mods from the mod portal:

- Bob's Warfare
- Heavy Truck by MrSelfDestruct (originally by KatzSmile)
- Schall Tank Platoon
- Aircraft by SuicidalKid
- Aircraft Realism by haih_ys
- Better Cargo Planes by Modernkennnern
- Cargo Ships by schnurrebutz
- Train & Fuel Overaul by Optera
- Gizmo's Car Keys (imprved)
- Space Exploration by Earendel

Loaded wagons weigh more than unloaded wagons, in some cases according to what vehicle they load.  To change the weight effects or disable it, use the Mod Startup Settings.

Modded/colored vehicle models may appear as a standard, grey-colored version while riding on the wagon, but after unloading go back to normal.

Vehicles that this mod cannot automatically identify will be loaded on the wagon covered in a tarp.

You also cannot winch vehicles that have a passenger; all players must exit before loading/unloading.

Robots can deconstruct loaded wagons, which will reveal the vehicle and mark it for deconstruction as well.

Known Issues/Quirks:
--------------------

If a mod adds a "car"-type entity that is not meant to be an actual vehicle, such as the Nixie Tubes mod (used to; it has changed by now), it may still be able to be loaded on a Vehicle Wagon under a tarp.
Specific exceptions have been added for Nixie Tubes, Helicopters, and others to disallow this, but certain mods may exist that this mod lacks exceptions for.

For vehicles with multiple of the same weapon type, the ammo is re-inserted in a random order.

Direct compatibility with AAI Programmable Vehicles is unavailable.  AAI does not have code to detect when a vehicle is unloaded (script_raised_destroy), so you cannot use the AI functions after unloading any AAI vehicle.

Credits:
--------

German translation by ST-DDT.

Polish translation by ???.

Russian translation and maintenance by Artanis_Mattias (dimonft).

The flatbed wagon graphics are by the extremely talented and gracious YuokiTani!  As well as the new Loaded Aircraft graphics!

The wagon tarp graphics for supporting unidentified vehicles provided by Brant Wedel (https://github.com/brantwedel).

The sound effects were edited from these sounds:

	https://www.freesound.org/people/calivintage/sounds/95701
	Uploaded by the user "calivintage" under the CC Sampling+ License (https://creativecommons.org/licenses/sampling+/1.0).

	https://freesound.org/people/Deathscyp/sounds/404022
	Uploaded by the user "Deathscyp" under the Creative Commons 0 License.

	https://freesound.org/people/j1987/sounds/106116
	Uploaded by the user "j1987" under the Creative Commons 0 License.

	https://freesound.org/people/AGC66/sounds/394303
	Uploaded by the user "AGC66" under the CC-BY-NC license (https://creativecommons.org/licenses/by-nc/3.0/legalcode).

Thanks to the forum, Github, and #factorio IRC denizens for camaraderie & advice.

See also the associated forum thread and/or Github repository to give feedback, view screenshots, etc.:

https://forums.factorio.com/viewtopic.php?f=93&t=31489

https://github.com/Suprcheese/Vehicle-Wagon
