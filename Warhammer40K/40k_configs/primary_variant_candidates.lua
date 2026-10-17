-- Authored exact-source facts. Converted only; native acceptance remains closed.
return {
  ["imp_dreadnought_hellfire"] = {
    ["bounds"] = {
      ["max"] = {
        13.732500076293945,
        25.70034408569336,
        9.943307876586914
      },
      ["min"] = {
        -13.731697082519531,
        -0.03714178502559662,
        -10.22380542755127
      },
      ["size"] = {
        27.464197158813477,
        25.737485870718956,
        20.167113304138184
      }
    },
    ["faction"] = "Imperium",
    ["footprint"] = 3,
    ["generated_hashes"] = {
      ["imp_dreadnought_hellfire.glb"] = "e9cdf0e45d94cc8db3261fae07c9183214985837bf29f616d87bb8c7481fa967",
      ["imp_dreadnought_hellfire_anim.lua"] = "a42566f465651733477a6bfc3217d808995e91305a94f2113a6fb326b9ea9a13"
    },
    ["movementclass"] = "BOT3",
    ["name"] = "Hellfire Dreadnought",
    ["native_required_mechanics"] = {
      "Missile source motion has no distinct genuine recoil action; static source emitter/events must stay honest",
      "Native paid production/tech/egress/materials/all weapons/audio/defining mechanics unaccepted"
    },
    ["pose_error"] = 1.4454126358032227e-06,
    ["producer"] = "imp_walker_factory",
    ["role"] = "walker",
    ["root_bone"] = "bip01",
    ["source_abilities"] = {
      {
        ["motion"] = "",
        ["path"] = "abilities/races/space_marines/ua_marines_injections_vehicle.lua",
        ["recharge"] = 0
      }
    },
    ["source_cost"] = {
      ["power"] = 330,
      ["requisition"] = 190,
      ["time"] = 45
    },
    ["source_entity"] = "attrib/ebps/races/space_marines/troops/dreadnought_hellfire_variant.lua",
    ["source_health"] = 5000,
    ["source_model_sha256"] = "526a45dd98c6ffd507cb2844aadfa00335c2e8c0ad068019b1ef56d010c4b8fa",
    ["source_speed"] = 18,
    ["source_squad"] = "attrib/sbps/races/space_marines/space_marine_squad_dreadnought_hellfire.lua",
    ["source_squad_requirements"] = {
      ["squad_requirement_ext.requirements.required_1.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_1.structure_name"] = "ebps\\races\\space_marines\\structures\\space_marine_vehicle_building.lua",
      ["squad_requirement_ext.requirements.required_10.is_display_requirement"] = true,
      ["squad_requirement_ext.requirements.required_10.structure_name"] = "ebps\\races\\space_marines\\structures\\space_marine_hq.lua",
      ["squad_requirement_ext.requirements.required_11.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_2.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_3.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_4.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_5.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_6.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_7.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_8.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_9.is_display_requirement"] = false
    },
    ["source_squad_slots"] = 0,
    ["source_transport_bones"] = {},
    ["weapons"] = {
      {
        ["accuracy"] = 0.8500000238,
        ["fx_family"] = "heavy_bolter",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "Unit_Impact_events/Blood_Splatter_Impact_S",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "unit_impact_events/wraithbone_hit_small",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "unit_impact_events/Impact_Bolter_Sml",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "Unit_Impact_events/Impact_Bolter_Hvy",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 36,
        ["minimum_damage"] = 32,
        ["native_kind"] = "Cannon",
        ["projectile"] = "",
        ["radius"] = 0,
        ["range"] = 45,
        ["reload"] = 0.200000003,
        ["source_aimpiece"] = "unit_aim",
        ["source_fireclip"] = "fire",
        ["source_muzzle"] = "marker_assault_cannon_barrel",
        ["source_pitchpiece"] = "right_arm_vert_aim",
        ["source_sha256"] = "3cf306a44a343d319d8680f294753532453f80db00be8bde59a7097aab323add",
        ["source_weapon_profile"] = "weapon/space_marine_assault_cannon_hellfire.lua"
      },
      {
        ["accuracy"] = 1,
        ["fx_family"] = "krak_missile",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "Projectile_FX/Krak_Missile_Impact",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "Projectile_FX/Krak_Missile_Impact",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "Projectile_FX/Krak_Missile_Impact",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "Projectile_FX/Krak_Missile_Impact_hvy",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 410,
        ["minimum_damage"] = 320,
        ["native_kind"] = "MissileLauncher",
        ["projectile"] = "krak_missile",
        ["radius"] = 0,
        ["range"] = 45,
        ["reload"] = 2,
        ["source_aimpiece"] = "unit_aim",
        ["source_fireclip"] = "",
        ["source_muzzle"] = "marker_dreadnought_missile_nub_1",
        ["source_muzzle_pair"] = "marker_dreadnought_missile_nub_1,marker_dreadnought_missile_nub_2,marker_dreadnought_missile_nub_3,marker_dreadnought_missile_nub_4",
        ["source_pitchpiece"] = "left_arm_vert_aim",
        ["source_sha256"] = "d851483f7d06a4e40640f716c3d2952ee47e8f8d669971c690df6119ba64f384",
        ["source_weapon_profile"] = "weapon/space_marine_missile_launcher_hellfire.lua"
      }
    }
  },
  ["imp_dreadnought_ironclad"] = {
    ["bounds"] = {
      ["max"] = {
        14.917210578918457,
        27.57413673400879,
        11.015434265136719
      },
      ["min"] = {
        -14.908732414245605,
        -0.037138931453228,
        -10.223801612854004
      },
      ["size"] = {
        29.825942993164062,
        27.611275665462017,
        21.239235877990723
      }
    },
    ["faction"] = "Imperium",
    ["footprint"] = 3,
    ["generated_hashes"] = {
      ["imp_dreadnought_ironclad.glb"] = "3e47a2d2ed8c4601d74653042d0862887d0f9b2cef064d6b50d0cf68a262f037",
      ["imp_dreadnought_ironclad_anim.lua"] = "6e4ac7131c594c61298ee0ec121aa832fb9cdf9253b3408c61b6e9627bc2d275"
    },
    ["movementclass"] = "BOT3",
    ["name"] = "Ironclad Dreadnought",
    ["native_required_mechanics"] = {
      "Hunter-Killer source abilities are real separate ability profiles/actions; native paid charge and source-targeted independent 120-second recharge controller not implemented",
      "Do not invent unlimited missile auto-fire",
      "Left-flamer motion variable and emitter follow actual EBP; native source appearance needs explicit review",
      "Native paid production/tech/egress/materials/all weapons/audio/defining mechanics unaccepted"
    },
    ["pose_error"] = 2.050306648015976e-06,
    ["producer"] = "imp_walker_factory",
    ["role"] = "walker",
    ["root_bone"] = "bip01",
    ["source_abilities"] = {
      {
        ["activation"] = "type_abilityactivation\\tp_ability_activation_targeted.lua",
        ["entity_busy_time"] = 1.0,
        ["fire_cost"] = {
          ["energy"] = 80.0,
          ["metal"] = 20.0
        },
        ["motion"] = "",
        ["native_status"] = "targeted paid two independent120sec controller pending; never autofire",
        ["path"] = "abilities/races/space_marines/ua_marines_hk_missile_ironclad1.rgd",
        ["projectile"] = "krak_missile",
        ["recharge"] = 120.0,
        ["source_damage_max"] = 600.0,
        ["source_damage_min"] = 450.0,
        ["source_radius"] = 6.5,
        ["source_range"] = 80.0
      },
      {
        ["activation"] = "type_abilityactivation\\tp_ability_activation_targeted.lua",
        ["entity_busy_time"] = 1.0,
        ["fire_cost"] = {
          ["energy"] = 80.0,
          ["metal"] = 20.0
        },
        ["motion"] = "",
        ["native_status"] = "targeted paid two independent120sec controller pending; never autofire",
        ["path"] = "abilities/races/space_marines/ua_marines_hk_missile_ironclad2.rgd",
        ["projectile"] = "krak_missile",
        ["recharge"] = 120.0,
        ["source_damage_max"] = 600.0,
        ["source_damage_min"] = 450.0,
        ["source_radius"] = 6.5,
        ["source_range"] = 80.0
      },
      {
        ["motion"] = "",
        ["path"] = "abilities/races/space_marines/ua_marines_injections_vehicle.lua",
        ["recharge"] = 0
      }
    },
    ["source_cost"] = {
      ["power"] = 335,
      ["requisition"] = 200,
      ["time"] = 60
    },
    ["source_entity"] = "attrib/ebps/races/space_marines/troops/dreadnought_ironclad.lua",
    ["source_health"] = 6000,
    ["source_model_sha256"] = "6ec4e31cfda78fd67849b21c06d88f39d403a47e26c7d77d390f93ddfc6b96cb",
    ["source_speed"] = 18,
    ["source_squad"] = "attrib/sbps/races/space_marines/space_marine_squad_dreadnought_ironclad.lua",
    ["source_squad_requirements"] = {
      ["squad_requirement_ext.requirements.required_1.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_1.structure_name"] = "ebps\\races\\space_marines\\structures\\space_marine_vehicle_building.lua",
      ["squad_requirement_ext.requirements.required_10.is_display_requirement"] = true,
      ["squad_requirement_ext.requirements.required_10.structure_name"] = "ebps\\races\\space_marines\\structures\\space_marine_hq.lua",
      ["squad_requirement_ext.requirements.required_11.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_2.global_addon_name"] = "addons\\space_marine_hq_addon_2.lua",
      ["squad_requirement_ext.requirements.required_2.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_3.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_4.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_5.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_6.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_7.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_8.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_9.is_display_requirement"] = false
    },
    ["source_squad_slots"] = 0,
    ["source_transport_bones"] = {},
    ["weapons"] = {
      {
        ["accuracy"] = 1,
        ["fx_family"] = "power_fist",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "unit_impact_events/dreadnought_melee_hit",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "unit_impact_events/dreadnought_melee_hit",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "unit_impact_events/dreadnought_melee_hit",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "unit_impact_events/dreadnought_melee_hit"
        },
        ["maximum_damage"] = 257,
        ["minimum_damage"] = 205,
        ["native_kind"] = "Melee",
        ["projectile"] = "",
        ["radius"] = 3,
        ["reload"] = 1,
        ["source_aimpiece"] = "unit_aim",
        ["source_fireclip"] = "melee",
        ["source_muzzle"] = "marker_dreadnought_melee_r_hand",
        ["source_sha256"] = "b4f29332124770513c323f6d78a043a31f4f78572ea5d5e41d4c2efd6f9d385f",
        ["source_weapon_profile"] = "weapon/space_marine_dreadnought_fist_iron.lua"
      },
      {
        ["accuracy"] = 1.0,
        ["fx_family"] = "power_fist",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "unit_impact_events/dreadnought_melee_hit",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "unit_impact_events/dreadnought_melee_hit",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "unit_impact_events/dreadnought_melee_hit",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "unit_impact_events/dreadnought_melee_hit"
        },
        ["maximum_damage"] = 257.0,
        ["minimum_damage"] = 205.0,
        ["native_kind"] = "Melee",
        ["projectile"] = "",
        ["radius"] = 3.0,
        ["reload"] = 0.75,
        ["source_aimpiece"] = "unit_aim",
        ["source_fireclip"] = "melee",
        ["source_muzzle"] = "marker_dreadnought_melee_l_hand",
        ["source_sha256"] = "1e4e90963a3f58cd9eb1d3030607436fb4cb3f3552e14cb1ef2fab5d89900c7a",
        ["source_weapon_profile"] = "weapon/space_marine_dreadnought_fist_twin_iron.rgd"
      },
      {
        ["accuracy"] = 1,
        ["fx_family"] = "flamer",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 24,
        ["minimum_damage"] = 20,
        ["native_kind"] = "Flame",
        ["projectile"] = "",
        ["radius"] = 10,
        ["range"] = 12,
        ["reload"] = 0.200000003,
        ["source_aimpiece"] = "unit_aim",
        ["source_fireclip"] = "fire",
        ["source_muzzle"] = "marker_ccw_l_flamer_barrel",
        ["source_pitchpiece"] = "left_arm_vert_aim",
        ["source_sha256"] = "93a8ccfaf65fb814f23036a812d006d9255fff19e59820880e8320306b1ee7f8",
        ["source_weapon_profile"] = "weapon/space_marine_flamer_dreadnought.lua"
      }
    }
  },
  ["imp_dreadnought_venerable"] = {
    ["bounds"] = {
      ["max"] = {
        14.917210578918457,
        30.371166229248047,
        13.823533058166504
      },
      ["min"] = {
        -14.891229629516602,
        -0.037138931453228,
        -10.226517677307129
      },
      ["size"] = {
        29.80844020843506,
        30.408305160701275,
        24.050050735473633
      }
    },
    ["faction"] = "Imperium",
    ["footprint"] = 3,
    ["generated_hashes"] = {
      ["imp_dreadnought_venerable.glb"] = "c41433cafe42bf4edfcf93cb04cd5108759cec3853bed6a0c769ba21805310e1",
      ["imp_dreadnought_venerable_anim.lua"] = "d95158fcb591a6113fa28ecdc1d173114c3909ccac5aa5b77cad36fc6238bff5"
    },
    ["movementclass"] = "BOT3",
    ["name"] = "Venerable Dreadnought",
    ["native_required_mechanics"] = {
      "Source third hardpoint choice is named Storm Bolter but uses assault_cannon_hellfire profile; preserve actual source override and physical left Storm Bolter",
      "No separate left Storm Bolter recoil action exists; no fabricated motion",
      "Native paid production/tech/egress/materials/all weapons/audio/defining mechanics unaccepted"
    },
    ["pose_error"] = 1.4901161193847656e-06,
    ["producer"] = "imp_walker_factory",
    ["role"] = "walker",
    ["root_bone"] = "bip01",
    ["source_abilities"] = {
      {
        ["motion"] = "",
        ["path"] = "abilities/races/space_marines/ua_marines_injections_vehicle.lua",
        ["recharge"] = 0
      }
    },
    ["source_cost"] = {
      ["power"] = 410,
      ["requisition"] = 280,
      ["time"] = 100
    },
    ["source_entity"] = "attrib/ebps/races/space_marines/troops/dreadnought_venerable.lua",
    ["source_health"] = 8000,
    ["source_model_sha256"] = "d3ab7d7f3fd50d47608021323e219a3a486396c47e7c0f20be46dc4a73089e3a",
    ["source_speed"] = 18,
    ["source_squad"] = "attrib/sbps/races/space_marines/space_marine_squad_dreadnought_venerable.lua",
    ["source_squad_requirements"] = {
      ["squad_requirement_ext.requirements.required_1.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_1.research_name"] = "research\\races\\space_marines\\UA_marine_heavy_armor_deployment.lua",
      ["squad_requirement_ext.requirements.required_10.is_display_requirement"] = true,
      ["squad_requirement_ext.requirements.required_10.structure_name"] = "ebps\\races\\space_marines\\structures\\space_marine_hq.lua",
      ["squad_requirement_ext.requirements.required_11.global_addon_name"] = "addons\\space_marine_hq_addon_2.lua",
      ["squad_requirement_ext.requirements.required_11.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_2.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_3.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_4.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_5.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_6.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_7.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_8.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_9.is_display_requirement"] = false
    },
    ["source_squad_slots"] = 0,
    ["source_transport_bones"] = {},
    ["weapons"] = {
      {
        ["accuracy"] = 0.8999999762,
        ["fx_family"] = "melta",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "melta_hit_1",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "melta_hit_1",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "melta_hit_1",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "melta_hit_1",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit_Big"
        },
        ["maximum_damage"] = 540,
        ["minimum_damage"] = 440,
        ["native_kind"] = "BeamLaser",
        ["projectile"] = "",
        ["radius"] = 0,
        ["range"] = 40,
        ["reload"] = 3,
        ["source_aimpiece"] = "unit_aim",
        ["source_fireclip"] = "fire",
        ["source_muzzle"] = "marker_multi_melta_1",
        ["source_muzzle_pair"] = "marker_multi_melta_1,marker_multi_melta_2",
        ["source_pitchpiece"] = "right_arm_vert_aim",
        ["source_sha256"] = "06158b593bcaeee546ba90813a8f856bff681dda5c182759af131edbd8b03867",
        ["source_weapon_profile"] = "weapon/space_marine_multi_melta_dreadnought_venerable.lua"
      },
      {
        ["accuracy"] = 1,
        ["fx_family"] = "power_fist",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "unit_impact_events/dreadnought_melee_hit",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "unit_impact_events/dreadnought_melee_hit",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "unit_impact_events/dreadnought_melee_hit",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "unit_impact_events/dreadnought_melee_hit"
        },
        ["maximum_damage"] = 750,
        ["minimum_damage"] = 520,
        ["native_kind"] = "Melee",
        ["projectile"] = "",
        ["radius"] = 0,
        ["reload"] = 0.75,
        ["source_aimpiece"] = "unit_aim",
        ["source_fireclip"] = "melee",
        ["source_muzzle"] = "marker_dreadnought_melee_l_hand",
        ["source_sha256"] = "ae3b99b4aa09429e4ccac3272eca53508212a11771a5d99b33997a7f3554a4a9",
        ["source_weapon_profile"] = "weapon/space_marine_dreadnought_fist_improved.lua"
      },
      {
        ["accuracy"] = 0.8500000238,
        ["fx_family"] = "bolter",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "Unit_Impact_events/Blood_Splatter_Impact_S",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "unit_impact_events/wraithbone_hit_small",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "unit_impact_events/Impact_Bolter_Sml",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "Unit_Impact_events/Impact_Bolter_Hvy",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 36,
        ["minimum_damage"] = 32,
        ["native_kind"] = "Cannon",
        ["projectile"] = "",
        ["radius"] = 0,
        ["range"] = 45,
        ["reload"] = 0.200000003,
        ["source_aimpiece"] = "unit_aim",
        ["source_fireclip"] = "",
        ["source_muzzle"] = "marker_storm_bolter",
        ["source_muzzle_pair"] = "marker_storm_bolter,marker_storm_bolter_2",
        ["source_pitchpiece"] = "left_arm_vert_aim",
        ["source_sha256"] = "3cf306a44a343d319d8680f294753532453f80db00be8bde59a7097aab323add",
        ["source_weapon_profile"] = "weapon/space_marine_assault_cannon_hellfire.lua"
      }
    }
  },
  ["ork_battlefortress_armageddon"] = {
    ["bounds"] = {
      ["max"] = {
        33.13713455200195,
        73.70118713378906,
        70.40812683105469
      },
      ["min"] = {
        -33.029144287109375,
        -0.9465122222900391,
        -77.68997955322266
      },
      ["size"] = {
        66.16627883911133,
        74.6476993560791,
        148.09810638427734
      }
    },
    ["faction"] = "Orks",
    ["footprint"] = 10,
    ["generated_hashes"] = {
      ["ork_battlefortress_armageddon.glb"] = "ed7940fcb8cad272fd5d7fc57d99370f856d1006ce4c173f5638ce50aac4a013",
      ["ork_battlefortress_armageddon_anim.lua"] = "459a411152d70c1b3a217f0091b455fcd0685ecd9d4fdf011460da0b642c22cb"
    },
    ["movementclass"] = "40K_ARMOURED10",
    ["name"] = "Armageddon Battlefortress",
    ["native_required_mechanics"] = {
      "Source main Kannon geometry uses source Zzzap profile; preserve source override rather than invent shell weapon",
      "Source left/right Shoota has no imported distinct firing actions; static gun emitter/event mapping remains explicit",
      "Source transport/support/mines/bumper and cargo packing unaccepted",
      "No genuine track-motion actions present on this model; source wheel/track presentation needs donor compatibility audit",
      "Native paid source production/technology/materials/audio/defining role not accepted"
    },
    ["pose_error"] = 5.960464477539062e-07,
    ["producer"] = "ork_resource_factory",
    ["role"] = "tank",
    ["root_bone"] = "battlewagon_master",
    ["source_abilities"] = {
      {
        ["motion"] = "",
        ["path"] = "abilities/ua_all_bumpertank.lua",
        ["recharge"] = 30
      },
      {
        ["motion"] = "",
        ["path"] = "abilities/races/orks/ua_ork_laymines.lua",
        ["recharge"] = 20
      },
      {
        ["motion"] = "",
        ["path"] = "abilities/ua_all_transport_heal.lua",
        ["recharge"] = 30
      },
      {
        ["motion"] = "",
        ["path"] = "abilities/ua_all_transport_abilityrecharge.lua",
        ["recharge"] = 30
      },
      {
        ["motion"] = "",
        ["path"] = "abilities/ua_all_transport_reinforce.lua",
        ["recharge"] = 90
      }
    },
    ["source_cost"] = {
      ["power"] = 820,
      ["requisition"] = 350,
      ["time"] = 108
    },
    ["source_entity"] = "attrib/ebps/races/orks/troops/ork_battlefortress_armageddon.lua",
    ["source_health"] = 12000,
    ["source_model_sha256"] = "16c2de273c72356d4b5f54acd076fffbb123ddcb6532c22c91c8e6d025fb2dd6",
    ["source_speed"] = 24,
    ["source_squad"] = "attrib/sbps/races/orks/ork_squad_battlefortress_armageddon.lua",
    ["source_squad_requirements"] = {
      ["squad_requirement_ext.requirements.required_1.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_1.research_name"] = "research\\races\\orks\\UA_ork_research_klan_armageddon.lua",
      ["squad_requirement_ext.requirements.required_10.is_display_requirement"] = true,
      ["squad_requirement_ext.requirements.required_10.research_name"] = "research\\races\\orks\\UA_ork_research_klan_armageddon.lua",
      ["squad_requirement_ext.requirements.required_11.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_2.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_2.research_name"] = "research\\races\\orks\\UA_ork_research_tech_battlefortress.lua",
      ["squad_requirement_ext.requirements.required_3.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_4.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_5.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_6.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_7.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_8.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_9.is_display_requirement"] = false
    },
    ["source_squad_slots"] = 4,
    ["source_transport_bones"] = {},
    ["weapons"] = {
      {
        ["accuracy"] = 1,
        ["fx_family"] = "zzzap",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "Unit_Impact_events\\zzap_gun_hit",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "Unit_Impact_events\\zzap_gun_hit",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "Unit_Impact_events\\zzap_gun_hit",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "Unit_Impact_events\\zzap_gun_hit_hvy",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 825,
        ["minimum_damage"] = 675,
        ["native_kind"] = "BeamLaser",
        ["projectile"] = "",
        ["radius"] = 0,
        ["range"] = 35,
        ["reload"] = 3,
        ["source_aimpiece"] = "aim_horizontal_main",
        ["source_fireclip"] = "fire",
        ["source_muzzle"] = "marker_kannon",
        ["source_pitchpiece"] = "aim_vertical_main",
        ["source_sha256"] = "e1b5d5d8f17892ba0601b7ed9a5eb9fdace979dc2d2229c56af664b3e794f3b3",
        ["source_weapon_profile"] = "weapon/ork_zzzap_gun.lua"
      },
      {
        ["accuracy"] = 0.5,
        ["fx_family"] = "shoota",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "Unit_Impact_events\\Blood_Splatter_Impact_S",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "Impact_Bolter_Metal_S",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "Impact_Bolter_Metal_S",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "unit_impact_events/Impact_Bolter_Hvy",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 110,
        ["minimum_damage"] = 90,
        ["native_kind"] = "Cannon",
        ["projectile"] = "",
        ["radius"] = 0,
        ["range"] = 40,
        ["reload"] = 0.1700000018,
        ["source_aimpiece"] = "aim_vertical_horizontal_l",
        ["source_fireclip"] = "",
        ["source_muzzle"] = "marker_big_shoota_l_1",
        ["source_muzzle_pair"] = "marker_big_shoota_l_1,marker_big_shoota_l_2",
        ["source_pitchpiece"] = "aim_vertical_left",
        ["source_sha256"] = "4e633d6a5fe154e750ebe9ad1ff91462c86f33dec5ee88b124ed0ec1b017c7d2",
        ["source_weapon_profile"] = "weapon/ork_big_shoota_twin_battlefortress_l.lua"
      },
      {
        ["accuracy"] = 0.5,
        ["fx_family"] = "shoota",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "Unit_Impact_events\\Blood_Splatter_Impact_S",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "Impact_Bolter_Metal_S",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "Impact_Bolter_Metal_S",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "unit_impact_events/Impact_Bolter_Hvy",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 110,
        ["minimum_damage"] = 90,
        ["native_kind"] = "Cannon",
        ["projectile"] = "",
        ["radius"] = 0,
        ["range"] = 40,
        ["reload"] = 0.1700000018,
        ["source_aimpiece"] = "aim_vertical_horizontal_r",
        ["source_fireclip"] = "",
        ["source_muzzle"] = "marker_big_shoota_r_1",
        ["source_muzzle_pair"] = "marker_big_shoota_r_1,marker_big_shoota_r_2",
        ["source_pitchpiece"] = "aim_vertical_right",
        ["source_sha256"] = "4e633d6a5fe154e750ebe9ad1ff91462c86f33dec5ee88b124ed0ec1b017c7d2",
        ["source_weapon_profile"] = "weapon/ork_big_shoota_twin_battlefortress_r.lua"
      },
      {
        ["accuracy"] = 1,
        ["fx_family"] = "zzzap",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "Unit_Impact_events\\zzap_gun_hit",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "Unit_Impact_events\\zzap_gun_hit",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "Unit_Impact_events\\zzap_gun_hit",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "Unit_Impact_events\\zzap_gun_hit_hvy",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 825,
        ["minimum_damage"] = 675,
        ["native_kind"] = "BeamLaser",
        ["projectile"] = "",
        ["radius"] = 0,
        ["range"] = 40,
        ["reload"] = 5,
        ["source_aimpiece"] = "aim_horizontal_main_zzap_l",
        ["source_fireclip"] = "fire_left",
        ["source_muzzle"] = "marker_zzap_gun_l",
        ["source_pitchpiece"] = "aim_vertical_main_zzap_l",
        ["source_sha256"] = "38afd98154047dcd28cc9f981737113ce1b7edae8c76470690c8d7b4152872b2",
        ["source_weapon_profile"] = "weapon/ork_zzzap_gun_battlefortess_l.lua"
      },
      {
        ["accuracy"] = 1,
        ["fx_family"] = "zzzap",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "Unit_Impact_events\\zzap_gun_hit",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "Unit_Impact_events\\zzap_gun_hit",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "Unit_Impact_events\\zzap_gun_hit",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "Unit_Impact_events\\zzap_gun_hit_hvy",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 825,
        ["minimum_damage"] = 675,
        ["native_kind"] = "BeamLaser",
        ["projectile"] = "",
        ["radius"] = 0,
        ["range"] = 40,
        ["reload"] = 5,
        ["source_aimpiece"] = "aim_horizontal_main_zzap_r",
        ["source_fireclip"] = "fire_right",
        ["source_muzzle"] = "marker_zzap_gun_r",
        ["source_pitchpiece"] = "aim_vertical_main_zzap_r",
        ["source_sha256"] = "130cdaeca577d5515c9fe0505cfa3f2358b1bf92a34eff40d6fbb34ce52fe48f",
        ["source_weapon_profile"] = "weapon/ork_zzzap_gun_battlefortess_r.lua"
      }
    }
  },
  ["ork_battlewagon_armageddon"] = {
    ["bounds"] = {
      ["max"] = {
        32.62674331665039,
        63.44353103637695,
        80.51825714111328
      },
      ["min"] = {
        -32.62677764892578,
        -0.9465122222900391,
        -67.5798568725586
      },
      ["size"] = {
        65.25352096557617,
        64.39004325866699,
        148.09811401367188
      }
    },
    ["faction"] = "Orks",
    ["footprint"] = 10,
    ["generated_hashes"] = {
      ["ork_battlewagon_armageddon.glb"] = "f2fe24ee023c8fd7d74666fd578f401e6d1b9d79f09f3208e2f3b397936ee370",
      ["ork_battlewagon_armageddon_anim.lua"] = "c9d255d84716fca6f55221ce7adcd85af06bf8dd4adad61369fb6c02b52a7f57"
    },
    ["movementclass"] = "40K_ARMOURED10",
    ["name"] = "Armageddon Battlewagon",
    ["native_required_mechanics"] = {
      "Native independent crew/gun target/clip ownership and source bumper ability unaccepted",
      "Native paid source production/technology/materials/audio/defining role not accepted"
    },
    ["pose_error"] = 7.756228512789676e-07,
    ["producer"] = "ork_resource_factory",
    ["role"] = "tank",
    ["root_bone"] = "battlewagon_master",
    ["source_abilities"] = {
      {
        ["motion"] = "",
        ["path"] = "abilities/ua_all_bumpertank.lua",
        ["recharge"] = 30
      }
    },
    ["source_cost"] = {
      ["power"] = 250,
      ["requisition"] = 140,
      ["time"] = 50
    },
    ["source_entity"] = "attrib/ebps/races/orks/troops/ork_battle_wagon_armageddon.lua",
    ["source_health"] = 7500,
    ["source_model_sha256"] = "d1ac2065b116013dbc43ff07f5e080a42ae8c688515309f451c2c4b50b1192d7",
    ["source_speed"] = 24,
    ["source_squad"] = "attrib/sbps/races/orks/ork_squad_battle_wagon_armageddon.lua",
    ["source_squad_requirements"] = {
      ["squad_requirement_ext.requirements.required_1.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_1.research_name"] = "research\\races\\orks\\UA_ork_research_klan_armageddon.lua",
      ["squad_requirement_ext.requirements.required_10.is_display_requirement"] = true,
      ["squad_requirement_ext.requirements.required_10.research_name"] = "research\\races\\orks\\UA_ork_research_klan_armageddon.lua",
      ["squad_requirement_ext.requirements.required_11.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_2.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_2.research_name"] = "research\\races\\orks\\UA_ork_research_tech_battlewagon.lua",
      ["squad_requirement_ext.requirements.required_3.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_4.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_5.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_6.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_7.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_8.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_9.is_display_requirement"] = false
    },
    ["source_squad_slots"] = 1,
    ["source_transport_bones"] = {},
    ["weapons"] = {
      {
        ["accuracy"] = 0.8500000238,
        ["fx_family"] = "zzzap",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "Unit_Impact_events\\zzap_gun_hit",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "Unit_Impact_events\\zzap_gun_hit",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "Unit_Impact_events\\zzap_gun_hit",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "Unit_Impact_events\\zzap_gun_hit_hvy",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 825,
        ["minimum_damage"] = 675,
        ["native_kind"] = "BeamLaser",
        ["projectile"] = "",
        ["radius"] = 0,
        ["range"] = 40,
        ["reload"] = 5,
        ["source_aimpiece"] = "aim_horizontal_main_zzap",
        ["source_fireclip"] = "fire",
        ["source_muzzle"] = "marker_zzap_gun",
        ["source_pitchpiece"] = "aim_vertical_main_zzap",
        ["source_sha256"] = "ecb6f87529f63c8896dec3e03ddd61f507605b99d7301fbbcce8a9340c850cdb",
        ["source_weapon_profile"] = "weapon/ork_zzzap_gun_battlewagon.lua"
      },
      {
        ["accuracy"] = 0.5500000119,
        ["fx_family"] = "shoota",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "Unit_Impact_events\\Blood_Splatter_Impact_S",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "Impact_Bolter_Metal_S",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "Impact_Bolter_Metal_S",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "unit_impact_events/Impact_Bolter_Hvy",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 105,
        ["minimum_damage"] = 85,
        ["native_kind"] = "Cannon",
        ["projectile"] = "",
        ["radius"] = 0,
        ["range"] = 40,
        ["reload"] = 0.25,
        ["source_aimpiece"] = "aim_vertical_horizontal_l",
        ["source_fireclip"] = "fire_left",
        ["source_muzzle"] = "marker_big_shoota_l_1",
        ["source_muzzle_pair"] = "marker_big_shoota_l_1,marker_big_shoota_l_2",
        ["source_pitchpiece"] = "aim_vertical_left",
        ["source_sha256"] = "c3a946a384f7e985e53e2033b8419a40d5a3e4ae3a2f2f7bef570dd30b4dd053",
        ["source_weapon_profile"] = "weapon/ork_big_shoota_twin_battle_wagon_l.lua"
      },
      {
        ["accuracy"] = 0.5500000119,
        ["fx_family"] = "shoota",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "Unit_Impact_events\\Blood_Splatter_Impact_S",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "Impact_Bolter_Metal_S",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "Impact_Bolter_Metal_S",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "unit_impact_events/Impact_Bolter_Hvy",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 105,
        ["minimum_damage"] = 85,
        ["native_kind"] = "Cannon",
        ["projectile"] = "",
        ["radius"] = 0,
        ["range"] = 40,
        ["reload"] = 0.25,
        ["source_aimpiece"] = "aim_vertical_horizontal_r",
        ["source_fireclip"] = "fire_right",
        ["source_muzzle"] = "marker_big_shoota_r_1",
        ["source_muzzle_pair"] = "marker_big_shoota_r_1,marker_big_shoota_r_2",
        ["source_pitchpiece"] = "aim_vertical_right",
        ["source_sha256"] = "c0e51c724cdd5edd49b0bac1e853db9699e97be2fbb08183be4db3596c71d51b",
        ["source_weapon_profile"] = "weapon/ork_big_shoota_twin_battle_wagon_r.lua"
      }
    }
  },
  ["ork_great_gargant"] = {
    ["bounds"] = {
      ["max"] = {
        195.64028930664062,
        367.611328125,
        189.4525146484375
      },
      ["min"] = {
        -195.6403350830078,
        -0.17535999417304993,
        -194.63238525390625
      },
      ["size"] = {
        391.28062438964844,
        367.78668811917305,
        384.08489990234375
      }
    },
    ["faction"] = "Orks",
    ["footprint"] = 25,
    ["generated_hashes"] = {
      ["ork_great_gargant.glb"] = "040375332e15481fb29dc1331ff2d09c06b039ce70a29d5236ff7d48a40af6e5",
      ["ork_great_gargant_anim.lua"] = "20941333cf2435dc3333adfba7596af8654e1f7953167f39da721ad873ca7fa1"
    },
    ["movementclass"] = "40K_GREAT_GARGANT25",
    ["name"] = "Great Gargant",
    ["native_required_mechanics"] = {
      "Source autorepair/squish/inspiring and independent full-gun/large movement/factory-exit paid native proof missing",
      "Native paid source production/technology/materials/audio/defining role not accepted"
    },
    ["pose_error"] = 1.4901161193847656e-07,
    ["producer"] = "ork_hq_super",
    ["role"] = "walker",
    ["root_bone"] = "bone_body_main",
    ["source_abilities"] = {
      {
        ["motion"] = "",
        ["path"] = "abilities/races/orks/ua_ork_gargant_autorepair.lua",
        ["recharge"] = 20
      },
      {
        ["motion"] = "",
        ["path"] = "abilities/races/orks/ua_ork_gargant_great_squish.lua",
        ["recharge"] = 0
      },
      {
        ["motion"] = "",
        ["path"] = "abilities/races/orks/ua_ork_gargant_inspiring.lua",
        ["recharge"] = 0
      }
    },
    ["source_cost"] = {
      ["power"] = 13610,
      ["requisition"] = 5110,
      ["time"] = 300
    },
    ["source_entity"] = "attrib/ebps/races/orks/troops/ork_great_gargant.lua",
    ["source_health"] = 65000,
    ["source_model_sha256"] = "67d612c3145ebd8e78f2d6c54161852e6840f1c0da06f078601c00a0c53ff5a6",
    ["source_speed"] = 6,
    ["source_squad"] = "attrib/sbps/races/orks/ork_squad_great_gargant.lua",
    ["source_squad_requirements"] = {
      ["squad_requirement_ext.requirements.required_1.is_display_requirement"] = true,
      ["squad_requirement_ext.requirements.required_1.structure_name"] = "ebps\\races\\orks\\structures\\ork_hq.lua",
      ["squad_requirement_ext.requirements.required_10.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_11.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_2.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_2.research_name"] = "research\\races\\orks\\UA_ork_research_tech_great_gargant.lua",
      ["squad_requirement_ext.requirements.required_3.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_4.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_5.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_6.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_7.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_8.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_9.is_display_requirement"] = false
    },
    ["source_squad_slots"] = 0,
    ["source_transport_bones"] = {},
    ["weapons"] = {
      {
        ["accuracy"] = 0.8000000119,
        ["fx_family"] = "battlecannon",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "Unit_Impact_events\\Impact_Autocannon_Flesh",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "unit_impact_events/Impact_Autocannon_All",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "unit_impact_events/Impact_Autocannon_All",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "unit_impact_events/Impact_Autocannon_HVY",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 6352,
        ["minimum_damage"] = 4420,
        ["native_kind"] = "Cannon",
        ["projectile"] = "",
        ["radius"] = 10,
        ["range"] = 100,
        ["reload"] = 4,
        ["source_aimpiece"] = "aim_horizontal_left",
        ["source_fireclip"] = "fire",
        ["source_muzzle"] = "left_gun_muzzle_up",
        ["source_muzzle_pair"] = "left_gun_muzzle_up,left_gun_muzzle_down",
        ["source_pitchpiece"] = "aim_vertical_left",
        ["source_sha256"] = "a4d6fc1f21318d46c3cfc07245675bb77e91538ae148b34c66afed657fe1806a",
        ["source_weapon_profile"] = "weapon/ork_super_battlecannon_gargant.lua"
      },
      {
        ["accuracy"] = 1,
        ["fx_family"] = "zzzap",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "Unit_Impact_events\\zzap_gun_hit",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "Unit_Impact_events\\zzap_gun_hit",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "Unit_Impact_events\\zzap_gun_hit",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "Unit_Impact_events\\zzap_gun_hit_hvy",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 14000,
        ["minimum_damage"] = 11285,
        ["native_kind"] = "BeamLaser",
        ["projectile"] = "",
        ["radius"] = 10,
        ["range"] = 100,
        ["reload"] = 9,
        ["source_aimpiece"] = "aim_horizontal_right",
        ["source_fireclip"] = "fire_right",
        ["source_muzzle"] = "right_gun_energy_cone",
        ["source_pitchpiece"] = "aim_vertical_right",
        ["source_sha256"] = "731f27c8c5798724906b086fef4607f60028d42681885f5798be61d0fd10d72b",
        ["source_weapon_profile"] = "weapon/ork_zzzap_gun_gargant_right.lua"
      },
      {
        ["accuracy"] = 0.5,
        ["fx_family"] = "battlecannon",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "unit_impact_events/Unit_Thrown_Smoke_Spray",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "unit_impact_events/Unit_Thrown_Smoke_Spray",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "unit_impact_events/Unit_Thrown_Smoke_Spray",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "unit_impact_events/impact_fire_medium",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 389,
        ["minimum_damage"] = 290,
        ["native_kind"] = "Cannon",
        ["projectile"] = "ork_mega_blasta_flame",
        ["radius"] = 7,
        ["range"] = 100,
        ["reload"] = 1,
        ["source_aimpiece"] = "unit_aim",
        ["source_fireclip"] = "fire_belly",
        ["source_muzzle"] = "belly_muzzle",
        ["source_sha256"] = "07fdb56078035737065d030954bda86221bc482c1343dab6521898b63fa47d49",
        ["source_weapon_profile"] = "weapon/ork_bellygun_gargant.lua"
      },
      {
        ["accuracy"] = 0.8000000119,
        ["fx_family"] = "battlecannon",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "unit_impact_events/Unit_Thrown_Smoke_Spray",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "unit_impact_events/Unit_Thrown_Smoke_Spray",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "unit_impact_events/Unit_Thrown_Smoke_Spray",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "unit_impact_events/impact_fire_medium",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 1247,
        ["minimum_damage"] = 909,
        ["native_kind"] = "Cannon",
        ["projectile"] = "",
        ["radius"] = 7,
        ["range"] = 120,
        ["reload"] = 1,
        ["source_aimpiece"] = "aim_horizontal_top_left",
        ["source_fireclip"] = "fire_top_left",
        ["source_muzzle"] = "top_gun_muzzle_left",
        ["source_pitchpiece"] = "aim_vertical_top_left",
        ["source_sha256"] = "486b53b477e18c8f7a3a334e6f3054974047871e5c9ad4d251a4bfabc5e747fe",
        ["source_weapon_profile"] = "weapon/ork_super_battlecannon_gargant_top_left.lua"
      },
      {
        ["accuracy"] = 0.8000000119,
        ["fx_family"] = "battlecannon",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "unit_impact_events/Unit_Thrown_Smoke_Spray",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "unit_impact_events/Unit_Thrown_Smoke_Spray",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "unit_impact_events/Unit_Thrown_Smoke_Spray",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "unit_impact_events/impact_fire_medium",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 1247,
        ["minimum_damage"] = 909,
        ["native_kind"] = "Cannon",
        ["projectile"] = "",
        ["radius"] = 7,
        ["range"] = 120,
        ["reload"] = 1,
        ["source_aimpiece"] = "aim_horizontal_top_right",
        ["source_fireclip"] = "fire_top_right",
        ["source_muzzle"] = "top_gun_muzzle_right",
        ["source_pitchpiece"] = "aim_vertical_top_right",
        ["source_sha256"] = "8332c20502776658457c1c48eed490e455a37a317bc81c2a3ec91044bd64087a",
        ["source_weapon_profile"] = "weapon/ork_super_battlecannon_gargant_top.lua"
      }
    }
  },
  ["ork_looted_rhino"] = {
    ["bounds"] = {
      ["max"] = {
        24.26940155029297,
        40.02195358276367,
        54.727596282958984
      },
      ["min"] = {
        -24.240798950195312,
        -0.2687435746192932,
        -32.4558219909668
      },
      ["size"] = {
        48.51020050048828,
        40.290697157382965,
        87.18341827392578
      }
    },
    ["faction"] = "Orks",
    ["footprint"] = 6,
    ["generated_hashes"] = {
      ["ork_looted_rhino.glb"] = "7e7c6ce27dc91093e646d71a433392d8317eecfc36e6defa42196c43ebc9f4e3",
      ["ork_looted_rhino_anim.lua"] = "7cee1968c253bb1ded506054260295f60ff6f6f463d80442e69cdae04e9334b9"
    },
    ["movementclass"] = "40K_RHINO6",
    ["name"] = "Looted Rhino",
    ["native_required_mechanics"] = {
      "Genuine source transport/support aura/heal/recharge/reinforcement/mine/boost/bumper mechanics need native implementation/packing proof",
      "Native paid source production/technology/materials/audio/defining role not accepted"
    },
    ["pose_error"] = 5.364418029785156e-07,
    ["producer"] = "ork_resource_factory",
    ["role"] = "tank",
    ["root_bone"] = "tank_master",
    ["source_abilities"] = {
      {
        ["motion"] = "",
        ["path"] = "abilities/ua_all_bumpertank.lua",
        ["recharge"] = 30
      },
      {
        ["motion"] = "",
        ["path"] = "abilities/races/orks/ua_ork_laymines.lua",
        ["recharge"] = 20
      },
      {
        ["motion"] = "",
        ["path"] = "abilities/races/orks/ua_ork_turbo_boost.lua",
        ["recharge"] = 45
      },
      {
        ["motion"] = "",
        ["path"] = "abilities/races/orks/ua_ork_rhino_aura.lua",
        ["recharge"] = 0
      },
      {
        ["motion"] = "",
        ["path"] = "abilities/ua_all_transport_heal.lua",
        ["recharge"] = 30
      },
      {
        ["motion"] = "",
        ["path"] = "abilities/ua_all_transport_abilityrecharge.lua",
        ["recharge"] = 30
      },
      {
        ["motion"] = "",
        ["path"] = "abilities/ua_all_transport_reinforce_orks.lua",
        ["recharge"] = 90
      }
    },
    ["source_cost"] = {
      ["power"] = 175,
      ["requisition"] = 175,
      ["time"] = 270
    },
    ["source_entity"] = "attrib/ebps/races/orks/troops/ork_looted_rhino.lua",
    ["source_health"] = 2250,
    ["source_model_sha256"] = "bdc8605757d079c9e7307e79ff39084d23091216ea4130a121a4c1c436928c24",
    ["source_speed"] = 32,
    ["source_squad"] = "attrib/sbps/races/orks/ork_squad_looted_rhino.lua",
    ["source_squad_requirements"] = {
      ["squad_requirement_ext.requirements.required_1.is_display_requirement"] = true,
      ["squad_requirement_ext.requirements.required_1.structure_name"] = "ebps\\races\\orks\\structures\\ork_gork_factory.lua",
      ["squad_requirement_ext.requirements.required_10.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_11.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_2.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_3.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_4.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_5.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_6.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_7.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_8.is_display_requirement"] = false,
      ["squad_requirement_ext.requirements.required_9.is_display_requirement"] = false
    },
    ["source_squad_slots"] = 1,
    ["source_transport_bones"] = {
      {
        ["name"] = "rhino_door_l",
        ["parent"] = "predator_chassis"
      },
      {
        ["name"] = "rhino_door_r",
        ["parent"] = "predator_chassis"
      },
      {
        ["name"] = "marker_rhino_compartment_l",
        ["parent"] = "predator_chassis"
      },
      {
        ["name"] = "marker_rhino_compartment_r",
        ["parent"] = "predator_chassis"
      },
      {
        ["name"] = "marker_rhino_door_l",
        ["parent"] = "predator_chassis"
      },
      {
        ["name"] = "marker_rhino_door_r",
        ["parent"] = "predator_chassis"
      }
    },
    ["weapons"] = {
      {
        ["accuracy"] = 0.5,
        ["fx_family"] = "shoota",
        ["hit_events"] = {
          ["area_effect.weapon_damage.hit_events.entry01.event"] = "Unit_Impact_events\\Impact_bolter_hvy_blood_only",
          ["area_effect.weapon_damage.hit_events.entry02.event"] = "unit_impact_events/wraithbone_hit_small",
          ["area_effect.weapon_damage.hit_events.entry03.event"] = "unit_impact_events/Impact_Bolter_Sml",
          ["area_effect.weapon_damage.hit_events.entry04.event"] = "Unit_Impact_events\\Impact_Bolter_Hvy",
          ["area_effect.weapon_damage.hit_events.entry05.event"] = "Necron\\Monolith_Hit"
        },
        ["maximum_damage"] = 66,
        ["minimum_damage"] = 54,
        ["native_kind"] = "Cannon",
        ["projectile"] = "",
        ["radius"] = 0,
        ["range"] = 35,
        ["reload"] = 0.3000000119,
        ["source_aimpiece"] = "bone_horizontal_aim",
        ["source_fireclip"] = "fire",
        ["source_muzzle"] = "marker_muzzle_bolter",
        ["source_muzzle_pair"] = "marker_muzzle_bolter,marker_twin_linked_big_shootas_barrel02",
        ["source_pitchpiece"] = "bone_vertical_aim",
        ["source_sha256"] = "95ee80b59548179f9726130fb7da86973c5fff8e05529b06a84c1e678fb1b6c2",
        ["source_weapon_profile"] = "weapon/ork_big_shoota_twin_wartrak.lua"
      }
    }
  }
}
