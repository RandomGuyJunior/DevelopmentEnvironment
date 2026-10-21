# Warhammer 40K BAR — Orks rebuild alpha.8

This replaces the old four-faction alpha.7 payload with the current Orks rebuild, derived from development 0.23.0-dev1. It adds one Orks starting commander alongside native Armada, Cortex and Legion. The other three unfinished 40K factions from the retired project are not included.

Enable Warhammer through RandomGuy's Mods tab and select the Ork Big Mek in the in-game starting-commander picker. Use a start-position mode that presents that picker. No separate game installation or custom launcher hook is required. The dependency remains the moving `rapid://randomguy-hosting:test` tag.

The Orks have their own Armada-derived comparison roster/buildings plus Ork infantry, vehicles, aircraft, walkers and the custom Gunship. The commander is a native Armada-stat baseline. Squads and old conversion/research/Armour-AP systems are absent: infantry are individual native units. Native BAR UnitDefs are not overwritten. Every exported UnitDef has a final unique ID and ordinary buildoptions.

Latest additions: Loota and Kommando (T1 Bot Lab); Tankbusta and Warboss (T2 Bot Lab); Looted Rhino and Grot Tank (T1 Vehicle Plant); Dakka Stompa with Titan core stats (Experimental Gantry). Gorkanaut/Morkanaut are back in the T2 Vehicle Plant with their earlier stats. Boomy Platform, Mek Trap and two generators replace only the Orks' corresponding copied Armada buildings. Recent infantry-facing, Mek Gun, gait, scale, audio, aircraft and weapon-muzzle fixes are included.

Fourteen accepted experimental signed-depth model derivatives replace their full meshes; remaining real geometry uses one 4096 DXT5 texture pair with full mips (42.667 MiB). Independent depth-capture textures are additional and make this a large download. No measured FPS gain is promised. Their renderer retains the documented lighting/shadow/build/cloak limitations. Rhino/Grot Tank tracks are static for now; crew/turrets/fire work. Melee and balance remain unfinished. Boomy uses a native low/high trajectory toggle rather than three smart-trajectory weapon slots.

Validation: exact source/archive/installed-byte checks, 247 literal own UnitDefs and complete own build graph, one additional startunit commander, Lua syntax, atlas geometry/UV preservation, native building dimensions/grids/economy, and 36 executed Lua aim/fire cases passed. User testing accepted earlier content, but the latest 0.23 additions have not yet had a grouped in-game check. No new multiplayer, WAN, Linux, whole-roster or public Rapid-download acceptance is claimed. Earlier alpha.7 multiplayer evidence belongs to that retired payload, not this rebuild.

Two narrow compatibility overlays retained from the tested local dependency address Hosting's existing epic_bastion.lua syntax error and missing lavalevel=false permission-schema entries. They grant no new permissions. No Warhammer-specific Chobby loading hook, runtime UnitDef conversion, side-table override or commander-replacement gadget is provided.

Private checkpoints, original sources, assets not used at runtime, preferences, caches, engines and maps are not shipped. The maintained development project remains separate from this generated distribution payload.
