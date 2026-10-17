-- Authored exact source facts and isolated paid progression adapter. No acceptance grants.
local M={}
M.SourceProfiles={
 ["imp_source_hq_addon_1"] = {
   ["source"] = "attrib/addons/space_marine_hq_addon_1.lua",
   ["sha256"] = "77d65b9d6c1fd75b061ecb839d34201646c4f5b53c35d2b37e97d7b8fd43d694",
   ["cost"] = {
     ["metal"] = 400,
     ["energy"] = 130,
    },
   ["time"] = 90,
   ["source_requirements"] = {
     ["requirements.required_1.is_display_requirement"] = true,
     ["requirements.required_1.structure_name"] = "ebps\\races\\space_marines\\structures\\space_marine_hq.lua",
     ["requirements.required_2.structure_name_either"] = "ebps\\races\\space_marines\\structures\\space_marine_barracks.lua",
     ["requirements.required_2.structure_name_or"] = "ebps\\races\\space_marines\\structures\\space_marine_armoury.lua",
    },
   ["effects"] = {{
       ["slot"] = "modifier_01",
       ["type"] = "health_maximum_modifier",
       ["target"] = "",
       ["value"] = 500,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_addition.lua",
      },{
       ["slot"] = "modifier_02",
       ["type"] = "enable_squad_reinforcement",
       ["target"] = "space_marine_squad_tactical_bike",
       ["value"] = 2,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_squad_type.lua",
      }},
   ["source_producers"] = {"attrib/ebps/races/space_marines/structures/space_marine_hq.lua","attrib/ebps/races/space_marines/structures/space_marine_hq_sp_dxp3_player.lua"},
  },
 ["imp_source_hq_addon_2"] = {
   ["source"] = "attrib/addons/space_marine_hq_addon_2.lua",
   ["sha256"] = "f0f6ea1902cac10e1779dff0f7a412cae623fd48b24a8ce8833e2dcc5f1d6420",
   ["cost"] = {
     ["metal"] = 500,
     ["energy"] = 500,
    },
   ["time"] = 180,
   ["source_requirements"] = {
     ["requirements.required_1.addon_name"] = "addons\\space_marine_hq_addon_1.lua",
     ["requirements.required_1.is_display_requirement"] = true,
     ["requirements.required_2.addon_name"] = "addons\\space_marine_hq_addon_1.lua",
     ["requirements.required_3.structure_name_either"] = "ebps\\races\\space_marines\\structures\\space_marine_vehicle_building.lua",
     ["requirements.required_3.structure_name_or"] = "ebps\\races\\space_marines\\structures\\space_marine_ability_building.lua",
    },
   ["effects"] = {{
       ["slot"] = "modifier_01",
       ["type"] = "health_maximum_modifier",
       ["target"] = "",
       ["value"] = 500,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_addition.lua",
      }},
   ["source_producers"] = {"attrib/ebps/races/space_marines/structures/space_marine_hq.lua","attrib/ebps/races/space_marines/structures/space_marine_hq_sp_dxp3_player.lua"},
  },
 ["ork_source_hq_addon"] = {
   ["source"] = "attrib/addons/ork_hq_addon.lua",
   ["sha256"] = "34dbfa6044b0758b9f45a175eaf05f572ef6bb48eab41b829b9d5aaea54f3e0a",
   ["cost"] = {
     ["metal"] = 300,
     ["energy"] = 400,
    },
   ["time"] = 180,
   ["source_requirements"] = {
     ["requirements.required_1.population_required"] = 70,
     ["requirements.required_2.is_display_requirement"] = true,
     ["requirements.required_2.structure_name"] = "ebps\\races\\orks\\structures\\ork_hq.lua",
    },
   ["effects"] = {{
       ["slot"] = "modifier_01",
       ["type"] = "health_maximum_modifier",
       ["target"] = "",
       ["value"] = 3500,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_addition.lua",
      },{
       ["slot"] = "modifier_02",
       ["type"] = "default_weapon_modifier_hardpoint3",
       ["target"] = "",
       ["value"] = 1,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity.lua",
      },{
       ["slot"] = "modifier_03",
       ["type"] = "default_weapon_modifier_hardpoint4",
       ["target"] = "",
       ["value"] = 1,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity.lua",
      },{
       ["slot"] = "modifier_04",
       ["type"] = "population_cap_player_modifier",
       ["target"] = "",
       ["value"] = 20,
       ["probability"] = 1,
       ["exclusive"] = false,
      },{
       ["slot"] = "modifier_05",
       ["type"] = "health_maximum_modifier",
       ["target"] = "ork_stormboy",
       ["value"] = 60,
       ["probability"] = 1,
       ["exclusive"] = true,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_addition.lua",
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_06",
       ["type"] = "max_troopers_squad_modifier",
       ["target"] = "ork_squad_stormboy",
       ["value"] = 2,
       ["probability"] = 1,
       ["exclusive"] = true,
      },{
       ["slot"] = "modifier_07",
       ["type"] = "cost_requisition_modifier",
       ["target"] = "ork_slugga_boy",
       ["value"] = -20,
       ["probability"] = 1,
       ["exclusive"] = true,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_addition.lua",
      }},
   ["source_producers"] = {"attrib/ebps/races/orks/structures/ork_hq.lua","attrib/ebps/races/orks/structures/ork_hq_sp_dxp3_player.lua"},
  },
 ["imp_source_heavy_armour"] = {
   ["source"] = "attrib/research/races/space_marines/ua_marine_heavy_armor_deployment.lua",
   ["sha256"] = "8c97b51f6f6c40946b8957918d2b760c8886a22c13189e6993f3e97a044b1b49",
   ["cost"] = {
     ["metal"] = 1000,
     ["energy"] = 1000,
    },
   ["time"] = 270,
   ["source_requirements"] = {
     ["requirements.required_1.addon_name"] = "Data\\attrib\\addons\\space_marine_hq_addon_2.lua",
     ["requirements.required_2.structure_name"] = "Data\\attrib\\ebps\\races\\space_marines\\structures\\space_marine_orbital_relay.lua",
     ["requirements.required_10.addon_name"] = "Data\\attrib\\addons\\space_marine_hq_addon_2.lua",
     ["requirements.required_10.is_display_requirement"] = true,
    },
   ["effects"] = {},
   ["source_producers"] = {"attrib/ebps/races/space_marines/structures/space_marine_hq.lua"},
  },
 ["ork_source_clan_armageddon"] = {
   ["source"] = "attrib/research/races/orks/ua_ork_research_klan_armageddon.lua",
   ["sha256"] = "49625bfb0f238fb07fe129cc3786fb83386d41f6a10453c8255ea37d36df5500",
   ["cost"] = {
     ["metal"] = 250,
     ["energy"] = 250,
    },
   ["time"] = 0,
   ["source_requirements"] = {
     ["requirements.required_1.global_addon_name"] = "addons\\ork_hq_addon.lua",
     ["requirements.required_2.research_must_not_be_complete"] = true,
     ["requirements.required_2.research_name"] = "UA_ork_research_klan_gorgutz",
     ["requirements.required_3.research_must_not_be_complete"] = true,
     ["requirements.required_3.research_name"] = "UA_ork_research_klan_nuddyfist",
     ["requirements.required_4.research_must_not_be_complete"] = true,
     ["requirements.required_4.research_name"] = "UA_ork_research_klan_zagdakka",
     ["requirements.required_10.is_display_requirement"] = true,
     ["requirements.required_10.structure_name"] = "ork_hq",
    },
   ["effects"] = {{
       ["slot"] = "modifier_03",
       ["type"] = "health_maximum_modifier",
       ["target"] = "ork_looted_rhino",
       ["value"] = 0.200000003,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_04",
       ["type"] = "cost_requisition_modifier",
       ["target"] = "ork_trukk",
       ["value"] = -0.5,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
      },{
       ["slot"] = "modifier_05",
       ["type"] = "health_maximum_modifier",
       ["target"] = "ork_trukk",
       ["value"] = 0.200000003,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_06",
       ["type"] = "cost_requisition_modifier",
       ["target"] = "ork_wartrak",
       ["value"] = -0.5,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
      },{
       ["slot"] = "modifier_07",
       ["type"] = "health_maximum_modifier",
       ["target"] = "ork_wartrak",
       ["value"] = 0.200000003,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_08",
       ["type"] = "cost_requisition_modifier",
       ["target"] = "ork_killa_kan",
       ["value"] = -0.5,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
      },{
       ["slot"] = "modifier_09",
       ["type"] = "health_maximum_modifier",
       ["target"] = "ork_killa_kan",
       ["value"] = 0.200000003,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_10",
       ["type"] = "cost_requisition_modifier",
       ["target"] = "ork_grot_tank",
       ["value"] = -0.5,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
      },{
       ["slot"] = "modifier_11",
       ["type"] = "health_maximum_modifier",
       ["target"] = "ork_grot_tank",
       ["value"] = 0.200000003,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_12",
       ["type"] = "cost_requisition_modifier",
       ["target"] = "ork_gun_wagon",
       ["value"] = -0.5,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
      },{
       ["slot"] = "modifier_13",
       ["type"] = "health_maximum_modifier",
       ["target"] = "ork_gun_wagon",
       ["value"] = 0.200000003,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_14",
       ["type"] = "cost_requisition_modifier",
       ["target"] = "ork_battle_wagon",
       ["value"] = -0.5,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
      },{
       ["slot"] = "modifier_15",
       ["type"] = "health_maximum_modifier",
       ["target"] = "ork_battle_wagon",
       ["value"] = 0.200000003,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_16",
       ["type"] = "cost_requisition_modifier",
       ["target"] = "ork_looted_tank",
       ["value"] = -0.5,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
      },{
       ["slot"] = "modifier_17",
       ["type"] = "health_maximum_modifier",
       ["target"] = "ork_looted_tank",
       ["value"] = 0.200000003,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_18",
       ["type"] = "cost_requisition_modifier",
       ["target"] = "ork_battlefortress",
       ["value"] = -0.5,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
      },{
       ["slot"] = "modifier_19",
       ["type"] = "health_maximum_modifier",
       ["target"] = "ork_battlefortress",
       ["value"] = 0.200000003,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_20",
       ["type"] = "cost_requisition_modifier",
       ["target"] = "ork_kill_bursta",
       ["value"] = -0.5,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
      },{
       ["slot"] = "modifier_21",
       ["type"] = "health_maximum_modifier",
       ["target"] = "ork_kill_bursta",
       ["value"] = 0.200000003,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_22",
       ["type"] = "cost_requisition_modifier",
       ["target"] = "ork_kill_krusha",
       ["value"] = -0.5,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
      },{
       ["slot"] = "modifier_23",
       ["type"] = "health_maximum_modifier",
       ["target"] = "ork_kill_krusha",
       ["value"] = 0.200000003,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_24",
       ["type"] = "cost_requisition_modifier",
       ["target"] = "ork_squiggoth",
       ["value"] = -0.200000003,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
      },{
       ["slot"] = "modifier_25",
       ["type"] = "health_maximum_modifier",
       ["target"] = "ork_squiggoth",
       ["value"] = 0.200000003,
       ["probability"] = 0.200000003,
       ["exclusive"] = false,
       ["usage_type"] = "type_modifierusagetype/tp_mod_usage_percentage.lua",
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_26",
       ["type"] = "production_speed_modifier",
       ["target"] = "ork_mek_shop",
       ["value"] = 1.100000024,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_27",
       ["type"] = "production_speed_modifier",
       ["target"] = "ork_hq_super",
       ["value"] = 1.100000024,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      }},
   ["source_producers"] = {"attrib/ebps/races/orks/structures/ork_hq.lua"},
  },
 ["ork_source_battlewagon"] = {
   ["source"] = "attrib/research/races/orks/ua_ork_research_tech_battlewagon.lua",
   ["sha256"] = "55167fd8f47be174ed18d2ba7537a7c0dc3a920b4b250bf2437eb4b38c329521",
   ["cost"] = {
     ["metal"] = 0,
     ["energy"] = 80,
    },
   ["time"] = 40,
   ["source_requirements"] = {
     ["requirements.required_1.population_required"] = 70,
     ["requirements.required_10.is_display_requirement"] = true,
     ["requirements.required_10.structure_name"] = "ebps\\races\\orks\\structures\\ork_hq.lua",
    },
   ["effects"] = {},
   ["source_producers"] = {"attrib/ebps/races/orks/structures/ork_bilda_pit.lua"},
  },
 ["ork_source_battlefortress"] = {
   ["source"] = "attrib/research/races/orks/ua_ork_research_tech_battlefortress.lua",
   ["sha256"] = "db6cd432ce91b4eb172a3dde2e20461ec6e4437fd3ffbef133e7d5da286daff3",
   ["cost"] = {
     ["metal"] = 0,
     ["energy"] = 450,
    },
   ["time"] = 180,
   ["source_requirements"] = {
     ["requirements.required_1.population_required"] = 280,
     ["requirements.required_2.research_name"] = "research\\races\\orks\\UA_ork_waagh_research.lua",
     ["requirements.required_10.is_display_requirement"] = true,
     ["requirements.required_10.structure_name"] = "ebps\\races\\orks\\structures\\ork_hq.lua",
    },
   ["effects"] = {},
   ["source_producers"] = {"attrib/ebps/races/orks/structures/ork_bilda_pit.lua"},
  },
 ["ork_source_great_gargant"] = {
   ["source"] = "attrib/research/races/orks/ua_ork_research_tech_great_gargant.lua",
   ["sha256"] = "0dc79eb88c955b60681de800b2e736f3e87fce8750846c59c5c9fdda92c7962d",
   ["cost"] = {
     ["metal"] = 0,
     ["energy"] = 4000,
    },
   ["time"] = 300,
   ["source_requirements"] = {
     ["requirements.required_1.population_required"] = 330,
     ["requirements.required_2.own_name"] = "strategic_objective_struct",
     ["requirements.required_2.owned_count"] = 1,
     ["requirements.required_3.research_name"] = "research\\races\\orks\\UA_ork_research_tech_gargant.lua",
     ["requirements.required_4.research_name"] = "research\\races\\orks\\UA_ork_waagh_research.lua",
     ["requirements.required_9.is_display_requirement"] = true,
     ["requirements.required_9.structure_name"] = "ebps\\races\\orks\\structures\\ork_hq.lua",
     ["requirements.required_10.is_display_requirement"] = true,
     ["requirements.required_10.research_name"] = "research\\races\\orks\\UA_ork_research_tech_gargant.lua",
    },
   ["effects"] = {},
   ["source_producers"] = {"attrib/ebps/races/orks/structures/ork_bilda_pit.lua"},
  },
 ["ork_source_gargant"] = {
   ["source"] = "attrib/research/races/orks/ua_ork_research_tech_gargant.lua",
   ["sha256"] = "9504b6eedacfb6c1485f8be4efba7b6c17761f1a13c4e108b930fd83660f90bb",
   ["cost"] = {
     ["metal"] = 0,
     ["energy"] = 2000,
    },
   ["time"] = 180,
   ["source_requirements"] = {
     ["requirements.required_1.population_required"] = 280,
     ["requirements.required_2.research_name"] = "research\\races\\orks\\UA_ork_waagh_research.lua",
     ["requirements.required_10.is_display_requirement"] = true,
     ["requirements.required_10.structure_name"] = "ebps\\races\\orks\\structures\\ork_hq.lua",
    },
   ["effects"] = {},
   ["source_producers"] = {"attrib/ebps/races/orks/structures/ork_bilda_pit.lua"},
  },
 ["ork_source_waaagh"] = {
   ["source"] = "attrib/research/races/orks/ua_ork_waagh_research.lua",
   ["sha256"] = "ed70444194c601dfb2cb8a2e37668293bea281c4d311fcef03fae6ad95dd6e7c",
   ["cost"] = {
     ["metal"] = 1200,
     ["energy"] = 1200,
    },
   ["time"] = 300,
   ["source_requirements"] = {
     ["requirements.required_1.addon_name"] = "addons\\ork_hq_addon.lua",
     ["requirements.required_1.is_display_requirement"] = true,
     ["requirements.required_2.population_required"] = 220,
     ["requirements.required_10.addon_name"] = "addons\\ork_hq_addon.lua",
    },
   ["effects"] = {{
       ["slot"] = "modifier_02",
       ["type"] = "population_cap_player_modifier",
       ["target"] = "",
       ["value"] = 60,
       ["probability"] = 1,
       ["exclusive"] = false,
      },{
       ["slot"] = "modifier_03",
       ["type"] = "production_speed_modifier",
       ["target"] = "ork_hq",
       ["value"] = 1.100000024,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_04",
       ["type"] = "production_speed_modifier",
       ["target"] = "ork_boy_hut",
       ["value"] = 1.100000024,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_05",
       ["type"] = "production_speed_modifier",
       ["target"] = "ork_pile_o_guns",
       ["value"] = 1.100000024,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_06",
       ["type"] = "production_speed_modifier",
       ["target"] = "ork_mek_shop",
       ["value"] = 1.100000024,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_07",
       ["type"] = "production_speed_modifier",
       ["target"] = "ork_hq_super",
       ["value"] = 1.100000024,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_08",
       ["type"] = "production_speed_modifier",
       ["target"] = "ork_giant_waagh_banner_sp_dxp3",
       ["value"] = 1.100000024,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_09",
       ["type"] = "production_speed_modifier",
       ["target"] = "ork_waagh_banner",
       ["value"] = 1.100000024,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_10",
       ["type"] = "production_speed_modifier",
       ["target"] = "ork_gork_totem",
       ["value"] = 1.100000024,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_11",
       ["type"] = "production_speed_modifier",
       ["target"] = "ork_generator",
       ["value"] = 1.100000024,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_12",
       ["type"] = "production_speed_modifier",
       ["target"] = "ork_boomy_platform",
       ["value"] = 1.100000024,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_13",
       ["type"] = "production_speed_modifier",
       ["target"] = "ork_bigger_generator",
       ["value"] = 1.100000024,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      },{
       ["slot"] = "modifier_14",
       ["type"] = "production_speed_modifier",
       ["target"] = "ork_bilda_pit",
       ["value"] = 1.100000024,
       ["probability"] = 1,
       ["exclusive"] = false,
       ["application_type"] = "type_modifierapplicationtype/tp_mod_apply_to_entity_type.lua",
      }},
   ["source_producers"] = {"attrib/ebps/races/orks/structures/ork_hq.lua"},
  },
}

M.DefaultBindings={marine_vehicle='imp_walker_factory',ork_hq='ork_settlement',ork_mek_lab='ork_mek_lab',ork_gork_factory='ork_resource_factory',ork_hq_super='ork_hq_super',ork_banner='ork_waaagh_banner'}
M.SourceBuildings={marine_hq='ebps/races/space_marines/structures/space_marine_hq.lua',marine_barracks='ebps/races/space_marines/structures/space_marine_barracks.lua',marine_armoury='ebps/races/space_marines/structures/space_marine_armoury.lua',marine_vehicle='ebps/races/space_marines/structures/space_marine_vehicle_building.lua',marine_artifact='ebps/races/space_marines/structures/space_marine_ability_building.lua',marine_relay='ebps/races/space_marines/structures/space_marine_orbital_relay.lua',ork_hq='ebps/races/orks/structures/ork_hq.lua',ork_mek_lab='ebps/races/orks/structures/ork_bilda_pit.lua',ork_gork_factory='ebps/races/orks/structures/ork_gork_factory.lua',ork_hq_super='ebps/races/orks/structures/ork_hq_super.lua',ork_banner='ebps/races/orks/structures/ork_waagh_banner.lua',relic='strategic_objective_struct'}
M.Production={imp_dreadnought_hellfire='marine_vehicle',imp_dreadnought_ironclad='marine_vehicle',imp_dreadnought_venerable='marine_vehicle',ork_looted_rhino='ork_gork_factory',ork_battlewagon_armageddon='ork_gork_factory',ork_battlefortress_armageddon='ork_gork_factory',ork_great_gargant='ork_hq_super'}
M.UnitConditions={
 imp_dreadnought_hellfire={buildings={'marine_vehicle','marine_hq'}},
 imp_dreadnought_ironclad={buildings={'marine_vehicle','marine_hq'},global_addon='imp_source_hq_addon_2'},
 imp_dreadnought_venerable={buildings={'marine_vehicle','marine_hq'},global_addon='imp_source_hq_addon_2',research={'imp_source_heavy_armour'}},
 ork_looted_rhino={buildings={'ork_gork_factory'}},
 ork_battlewagon_armageddon={buildings={'ork_gork_factory'},research={'ork_source_clan_armageddon','ork_source_battlewagon'}},
 ork_battlefortress_armageddon={buildings={'ork_gork_factory'},research={'ork_source_clan_armageddon','ork_source_battlefortress'}},
 ork_great_gargant={buildings={'ork_hq','ork_hq_super'},research={'ork_source_great_gargant'}},
}
M.ResearchConditions={
 imp_source_hq_addon_1={buildings={'marine_hq'},any_buildings={'marine_barracks','marine_armoury'}},
 imp_source_hq_addon_2={local_addon='imp_source_hq_addon_1',any_buildings={'marine_vehicle','marine_artifact'}},
 imp_source_heavy_armour={buildings={'marine_relay'},local_addon='imp_source_hq_addon_2'},
 ork_source_hq_addon={population=70},
 ork_source_clan_armageddon={global_addon='ork_source_hq_addon',not_research={'ork_source_clan_gorgutz','ork_source_clan_nuddyfist','ork_source_clan_zagdakka'}},
 ork_source_battlewagon={population=70},
 ork_source_battlefortress={population=280,research={'ork_source_waaagh'}},
 ork_source_gargant={population=280,research={'ork_source_waaagh'}},
 ork_source_great_gargant={population=330,buildings={'relic'},research={'ork_source_gargant','ork_source_waaagh'}},
 ork_source_waaagh={population=220,local_addon='ork_source_hq_addon'},
}
M.ResearchProducers={imp_source_hq_addon_1='marine_hq',imp_source_hq_addon_2='marine_hq',imp_source_heavy_armour='marine_hq',ork_source_hq_addon='ork_hq',ork_source_clan_armageddon='ork_hq',ork_source_battlewagon='ork_mek_lab',ork_source_battlefortress='ork_mek_lab',ork_source_gargant='ork_mek_lab',ork_source_great_gargant='ork_mek_lab',ork_source_waaagh='ork_hq'}
local BLOCK='source_variant_adapter_unattached'
local function sorted(t)local o={};for k in pairs(t)do o[#o+1]=k end;table.sort(o);return o end
local function finite(v)return type(v)=='number'and v==v and v>=0 and v<math.huge end
local function copy(t)local o={};for k,v in pairs(t or{})do o[k]=type(v)=='table'and copy(v)or v end;return o end
function M.Graph(bindings)
 local b=copy(M.DefaultBindings);for k,v in pairs(bindings or{})do assert(M.SourceBuildings[k]and type(v)=='string','Explicit source building binding required');if k:find('marine_',1,true)==1 then assert(v~='imp_hq'and v~='imp_barracks'and v~='imp_research','Guard infrastructure is not a genuine Marine binding')end;b[k]=v end
 local g={Requires={},Research={},Bindings=b,SourceVariantProgression=true}
 for key in pairs(M.UnitConditions)do g.Requires[key]={production_method=BLOCK}end
 for key,p in pairs(M.SourceProfiles)do
  g.Research[key]={name=key:gsub('_',' '),producer=b[M.ResearchProducers[key]]or('__missing_'..M.ResearchProducers[key]),cost=copy(p.cost),time=p.time,requires={production_method=BLOCK},requires_effect_handler=#p.effects>0 or p.requires_whole_consumer==true,source_profile=key}
 end
 return g
end
-- Append only accepted/explicit diagnostic candidates; preserve all existing menus.
function M.Apply(defs,ready,bindings)
 local b=copy(M.DefaultBindings);for k,v in pairs(bindings or{})do b[k]=v end
 local added={}
 for _,key in ipairs(sorted(M.Production))do local producer=b[M.Production[key]];local d=defs[key];local p=producer and defs[producer]
  if d and p and ready(key,d)and ready(producer,p)then
   p.buildoptions=p.buildoptions or{};local found=false;for _,name in ipairs(p.buildoptions)do if name==key then found=true end end
   if not found then p.buildoptions[#p.buildoptions+1]=key end
   d.customparams=d.customparams or{};d.customparams.prototype40k_tech_requires=key;added[#added+1]=key
  end
 end;return added
end
-- Native documented adaptation: a capacity-limited growing Waaagh resource,
-- not actor count. Read/write native rules permit exact save/reload retention.
-- Source proprietary growth/cap/drain tick semantics still need comparison.
function M.Population(C,S,bindings,fps,enabled,applied,appliedAddon)
 local P={};local b=bindings or M.DefaultBindings;fps=fps or 30
 local function done(team,key)return C.HasResearch(team,key)and(not applied or applied(team,key))end
 function P.Capacity(team)
  local n=(C.complete[team]or{})[b.ork_banner]or 0
  local addons=appliedAddon and appliedAddon(team)or(C.sourceVariantAdapter and C.sourceVariantAdapter.CountAddon(team,'ork_source_hq_addon')or 0)
  return math.min(9999,20+10*n+20*addons+(done(team,'ork_source_waaagh')and 60 or 0))
 end
 function P.Get(team)
  if enabled~=true then return nil end
  local v=S.GetTeamRulesParam(team,'40k_source_ork_population')
  return math.min(P.Capacity(team),finite(v)and v or 20)
 end
 function P.Frame(frame)
  if enabled~=true or frame%fps~=0 then return end
  for _,team in ipairs(S.GetTeamList()or{})do
   if b.ork_hq and((C.complete[team]or{})[b.ork_hq]or 0)>0 then
    local n=(C.complete[team]or{})[b.ork_banner]or 0
    local rate=math.min(.5,1.200000048+n*.03999999911)
    S.SetTeamRulesParam(team,'40k_source_ork_population',math.min(P.Capacity(team),P.Get(team)+rate),{allied=true})
   end
  end
 end
 return P
end
-- Stable per-entity per-modifier roll, not unsynced RNG. This native adaptation
-- preserves source probability rather than silently making clan bonuses certain.
function M.ModifierPlan(key,team,entity,sourceTarget)
 local p=assert(M.SourceProfiles[key],'Unknown exact source profile');local out={}
 for _,e in ipairs(p.effects)do
  local localActor=false;for _,producer in ipairs(p.source_producers)do if producer:match('([^/]+)%.lua$')==sourceTarget then localActor=true end end
  local playerEffect=e.type=='population_cap_player_modifier'
  if e.target==sourceTarget or(e.target==''and(localActor or playerEffect))then
   local slot=tonumber(e.slot:match('(%d+)$'))or 0
   local seed=(entity*16807+team*48271+slot*69621)%2147483647
   for _=1,3 do seed=(seed*48271)%2147483647 end
   local roll=seed/2147483647
   if e.probability>=1 or roll<e.probability then out[#out+1]=copy(e)end
  end
 end;return out
end
-- Source arithmetic applied to a caller's actual baseline. Additive, percentage,
-- multiplicative and unsupported types stay distinct; no invented native setter.
function M.FoldPlan(baseline,plan)
 local out=copy(baseline);local unresolved={}
 local fields={health_maximum_modifier='health',cost_requisition_modifier='metal',production_speed_modifier='production_speed',population_cap_player_modifier='population_capacity'}
 for _,e in ipairs(plan)do
  local field=fields[e.type];local usage=e.usage_type or 'tp_mod_usage_multiplication.lua'
  if field and finite(out[field])then
   if usage:find('addition',1,true)then out[field]=out[field]+e.value
   elseif usage:find('percentage',1,true)then out[field]=out[field]*(1+e.value)
   elseif usage:find('multiplication',1,true)then out[field]=out[field]*e.value
   else unresolved[#unresolved+1]=e end
  else unresolved[#unresolved+1]=e end
 end;return out,unresolved
end
-- Effects handlers must implement ALL declared source modifier types plus
-- future births/capture/save restoration before registering a paid unlock.
-- This adapter never registers a no-op handler or grants research for free.
function M.Attach(C,S,defs,g,hooks,CMD)
 assert(g.SourceVariantProgression and not C.sourceVariantAdapter,'Attach exactly once after controller creation')
 hooks=hooks or{};CMD=CMD or{};local b=g.Bindings
 local function completed(team,source)
  local name=b[source];return name and((C.complete[team]or{})[name]or 0)>0
 end
 local addons={imp_source_hq_addon_1=true,imp_source_hq_addon_2=true,ork_source_hq_addon=true}
 local function localAddon(id,team,key)
  local u=id and C.units[id];local producer=b[M.ResearchProducers[key]]
  if not C.records[key]or C.suppressed[key]or not u or u.team~=team or not u.finished or u.name~=producer then return false end
  if S.GetUnitTeam and S.GetUnitTeam(id)~=team then return false end
  if S.GetUnitRulesParam(id,'40k_source_addon_'..key)~=1 or S.GetUnitRulesParam(id,'40k_source_addon_source_'..key)~=tonumber(M.SourceProfiles[key].sha256:sub(1,6),16)or S.GetUnitRulesParam(id,'40k_addon_failed_'..key)==1 then return false end
  local health,_,_,_,progress=S.GetUnitHealth(id)
  return health~=nil and health>0 and(progress==nil or progress>=1)
 end
 local function countAddon(team,key)
  local count=0;for id in pairs(C.units)do if localAddon(id,team,key)then count=count+1 end end;return count
 end
 local function globalAddon(team,key)return countAddon(team,key)>0 end
 local function conditions(team,r,builder)
  if r.local_addon and not localAddon(builder,team,r.local_addon)then return false,'local_addon:'..r.local_addon end
  if r.global_addon and not globalAddon(team,r.global_addon)then return false,'global_addon:'..r.global_addon end
  for _,source in ipairs(r.buildings or{})do if not completed(team,source)then return false,'building:'..source end end
  if r.any_buildings then local yes=false;for _,source in ipairs(r.any_buildings)do if completed(team,source)then yes=true end end;if not yes then return false,'alternative_building' end end
  for _,key in ipairs(r.research or{})do
   if not C.records[key]or C.suppressed[key]or not C.HasResearch(team,key)then return false,'research:'..key end
   if hooks.ResearchApplied and not hooks.ResearchApplied(team,key)then return false,'research_effects:'..key end
  end
  for _,key in ipairs(r.not_research or{})do if C.HasResearch(team,key)or(C.reserved[team]or{})[key]then return false,'exclusive:'..key end end
  if r.population then local pop=hooks.Population and hooks.Population(team);if not finite(pop)or pop<r.population then return false,'population:'..r.population end end
  return true
 end
 local oldBuild,oldAllow,oldFrame,oldFallback,oldRefresh=C.CanBuild,C.Allow,C.Frame,C.Fallback,C.Refresh
 local function keyFor(defID)local d=defs[defID];local cp=d and d.customParams or{};return cp.prototype40k_tech_requires or cp.prototype40k_donor or(d and d.name)end
 function C.CanBuild(team,defID,builder,initial)
  local key=keyFor(defID);local r=M.UnitConditions[key]
  if r and not conditions(team,r)then return false end
  return oldBuild(team,defID,builder,initial)
 end
 local function researchAllowed(id,team,record)
  if S.GetTeamRulesParam and S.GetTeamRulesParam(team,'40k_source_effect_failed_'..record.key)==1 then return false,'prior_effect_failure' end
  local u=C.units[id]
  if not u or u.team~=team or not u.finished or u.name~=record.producer or(S.GetUnitTeam and S.GetUnitTeam(id)~=team)then return false,'producer' end
  local hp,_,_,_,progress=S.GetUnitHealth(id);if not hp or hp<=0 or(progress and progress<1)then return false,'producer_unfinished' end
  local p=M.SourceProfiles[record.key];if p and p.requires_whole_consumer and(not hooks.EffectSupported or hooks.EffectSupported(record.key,p)~=true)then return false,'whole_primary_consumer_unready'end
  return conditions(team,M.ResearchConditions[record.key],id)
 end
 function C.Allow(id,defID,team,cmd,params,options)
  local record=C.commands[cmd]
  if record and M.ResearchConditions[record.key]then
   if not researchAllowed(id,team,record)then return false end
   if record.sourceInstant then
    if C.HasResearch(team,record.key)or(C.reserved[team]or{})[record.key]then return false end
    if not hooks.InstantSupported or not hooks.InstantSupported(record.key)then return false end
    -- Prepare cannot mutate. Commit must be total/nonthrowing and cover effects
    -- plus future births/capture; payment stays native atomic, never a refund.
    local commit=hooks.PrepareInstant and hooks.PrepareInstant(team,record.key)
    if type(commit)~='function'then return false end
    if not S.UseTeamResource(team,record.row.cost)then return false end
    local okay,error=pcall(commit)
    if not okay or error~=true then C.sourceVariantEffectFailure={key=record.key,team=team,error=tostring(error)};S.SetTeamRulesParam(team,'40k_source_effect_failed_'..record.key,1,{allied=true});return false end
    C.done[team]=C.done[team]or{};C.done[team][record.key]=true
    S.SetTeamRulesParam(team,'40k_research_'..record.key,1,{allied=true});C.Refresh(id)
    return false -- consumed exactly once synchronously; no queued duplicate
   end
  end
  return oldAllow(id,defID,team,cmd,params,options)
 end
 function C.Fallback(id,cmd,tag)
  local record=C.commands[cmd]
  if record and M.ResearchConditions[record.key]then
   local u=C.units[id]
   if record.sourceInstant or not u or not researchAllowed(id,u.team,record)then C.Cancel(id);return true,true end
  end;return oldFallback(id,cmd,tag)
 end
 function C.Frame(frame)
  for _,id in ipairs(sorted(C.jobs))do
   for _,key in ipairs(sorted(C.jobs[id]))do local job=C.jobs[id][key]
    if M.ResearchConditions[key]and not researchAllowed(id,job.team,job.record)then C.Cancel(id);break end
   end
  end
  local pending={}
  for _,id in ipairs(sorted(C.jobs))do for _,key in ipairs(sorted(C.jobs[id]))do
   local job=C.jobs[id][key];local row=g.Research[key]
   if row and row.requires_effect_handler and not C.HasResearch(job.team,key)then pending[#pending+1]={job.team,key,id}end
  end end
  oldFrame(frame)
  for _,entry in ipairs(pending)do if C.HasResearch(entry[1],entry[2])then local okay,result=pcall(hooks.EffectsCompleted,entry[1],entry[2],M.SourceProfiles[entry[2]],entry[3]);if not okay or result~=true then C.sourceVariantEffectFailure={team=entry[1],key=entry[2],error=tostring(result)};S.SetTeamRulesParam(entry[1],'40k_source_effect_failed_'..entry[2],1,{allied=true})end;if okay and result==true and addons[entry[2]]then S.SetUnitRulesParam(entry[3],'40k_source_addon_source_'..entry[2],tonumber(M.SourceProfiles[entry[2]].sha256:sub(1,6),16),{private=true});S.SetUnitRulesParam(entry[3],'40k_source_addon_'..entry[2],1,{allied=true})end end end
 end
 function C.Refresh(id)
  oldRefresh(id);local u=C.units[id];if not u then return end
  for key,record in pairs(C.records)do
   if M.ResearchConditions[key]and record.producer==u.name and not researchAllowed(id,u.team,record)then
    local index=S.FindUnitCmdDesc and S.FindUnitCmdDesc(id,record.cmd)
    if index then S.EditUnitCmdDesc(id,index,{disabled=true})end
   end
  end
 end
 -- Guards are lifted only after actual wrappers exist. Missing bindings/world
 -- state still reject inside conditions, including factory and creation calls.
 for key in pairs(M.UnitConditions)do assert(C.requirements[key]==g.Requires[key]);g.Requires[key].production_method='factory'end
 for key,row in pairs(g.Research)do row.requires.production_method='factory'
  if row.time>0 and row.requires_effect_handler and hooks.EffectSupported and type(hooks.EffectsCompleted)=='function' and hooks.EffectSupported(key,M.SourceProfiles[key])then C.RegisterEffectHandler(key)end
 end
 -- Instant command uses the exact sorted common research namespace, including
 -- suppressed IDs. Never reserve an invented or colliding extra command ID.
 local all={};for key in pairs(C.records)do all[key]=true end;for key in pairs(C.suppressed)do all[key]=true end
 for index,key in ipairs(sorted(all))do local row=g.Research[key]
  if row and row.time==0 and b[M.ResearchProducers[key]] and hooks.InstantSupported and hooks.InstantSupported(key)then
   local cmd=34600+index;assert(not C.commands[cmd],'Instant research namespace collision')
   local record={key=key,row=row,producer=row.producer,cmd=cmd,frames=0,sourceInstant=true}
   C.records[key]=record;C.commands[cmd]=record;C.producerNames[row.producer]=true;C.suppressed[key]=nil
  end
 end
 C.sourceVariantAdapter={Conditions=conditions,Graph=g,LocalAddon=localAddon,GlobalAddon=globalAddon,CountAddon=countAddon}
 for _,id in ipairs(sorted(C.units))do C.Refresh(id)end
 return C.sourceVariantAdapter
end
return M
