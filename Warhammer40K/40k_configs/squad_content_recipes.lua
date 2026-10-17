-- Prepared recipes only. The coordinator owns profile activation and shared hooks.
-- Capacities are authored BAR-scale choices, not imported reinforcement rules.
local function row(faction,product,actor,capacity,cost,source,gate)
 return {faction=faction,product=product,actor=actor,capacity=capacity,
  bodyCost={metal=cost[1],energy=cost[2],work=cost[3]},sourceDef=source,
  special=false,gate=gate or 'native_squad_acceptance',state='prepared'}
end
local expansion='game/units/40k/imperium_expansion/roster.lua'
local necron='game/units/40k_necron_roster.lua'
local release='game/units/40k_imperium_release.lua'
local function ork(key)return 'game/units/40k/ork_expansion/'..key..'.lua'end
local profiles={
 guard_line=row('guard','imp_guardsman','guardsman',8,{8,40,100},'game/units/40k/imp_guardsman.lua'),
 guard_kasrkin=row('guard','imp_kasrkin','imp_kasrkin',5,{55,280,520},expansion),
 guard_ogryn=row('guard','imp_ogryn','imp_ogryn',3,{90,450,850},expansion,'native_melee_and_squad_acceptance'),
 marine_tactical=row('marine','imp_marine','space_marine',4,{48,240,500},'game/units/40k/imp_marine.lua'),
 marine_scout=row('marine','imp_scout','imp_scout',4,{30,150,300},expansion),
 marine_heavy=row('marine','imp_devastator','imp_devastator',3,{85,420,800},expansion),
 marine_assault=row('marine','imp_assault_marine','imp_assault_marine',4,{140,700,1100},release,'whole_squad_jump_and_melee_adapter'),
 marine_terminator=row('marine','imp_terminator','imp_terminator',3,{240,1300,1900},release,'native_melee_and_squad_acceptance'),
 ork_shoota=row('orks','ork_boy','ork_boy',8,{12,60,120},'game/units/40k/ork_boy.lua'),
 ork_slugga=row('orks','ork_slugga','ork_slugga',8,{12,60,144},ork('ork_slugga'),'native_melee_and_squad_acceptance'),
 ork_burna=row('orks','ork_burna','ork_burna',4,{22,110,264},ork('ork_burna')),
 ork_tankbusta=row('orks','ork_tankbusta','ork_tankbusta',3,{30,150,360},ork('ork_tankbusta')),
 ork_loota=row('orks','ork_loota','ork_loota',3,{36,180,432},ork('ork_loota')),
 ork_nob=row('orks','ork_nob','ork_nob',3,{55,275,660},ork('ork_nob'),'native_melee_and_squad_acceptance'),
 ork_meganob=row('orks','ork_meganob','meganob',3,{100,500,850},'game/units/40k/ork_meganob.lua','native_melee_and_squad_acceptance'),
 necron_warrior=row('necrons','nec_warrior','nec_warrior',5,{35,190,420},necron),
 necron_immortal=row('necrons','nec_immortal','nec_immortal',3,{85,440,850},necron),
 necron_flayed=row('necrons','nec_flayed','nec_flayed',4,{55,280,600},necron,'native_melee_and_squad_acceptance'),
 necron_wraith=row('necrons','nec_wraith','nec_wraith',3,{130,650,1400},necron,'phase_movement_and_melee_adapter'),
}
profiles.marine_tactical.special={source='imp_devastator',slot=4,research='marine_squad_heavy_bolter',state='existing_pilot'}
-- Checked genuine source and currently authored firing slots; not new loadouts.
profiles.guard_kasrkin.sourceWhm="art/ebps/races/imperial_guard/troops/kasrkin.whm"
profiles.guard_kasrkin.weaponSlots={{name="Hellgun",kind="LaserCannon",muzzle="marker_lasgun_muzzle",clip="fire"}}
profiles.guard_line.sourceWhm="art/ebps/races/imperial_guard/troops/guardsmen_codex.whm"
profiles.guard_line.weaponSlots={{name="Lasgun",kind="LaserCannon",muzzle="marker_lasgun_muzzle",clip="fire"}}
profiles.guard_ogryn.sourceWhm="art/ebps/races/imperial_guard/troops/ogryn.whm"
profiles.guard_ogryn.weaponSlots={{name="Ripper gun",kind="Cannon",muzzle="marker_ripper_gun_muzzle",clip="fire"},{name="Ogryn fists",kind="Melee",muzzle="bip01 r hand",clip="melee"}}
profiles.marine_assault.sourceWhm="art/ebps/races/space_marines/troops/space_marine_assault.whm"
profiles.marine_assault.weaponSlots={{name="Bolt pistol",kind="Cannon",muzzle="marker_marine_boltpistol_barrel",clip="fire"},{name="Chainsword",kind="Melee",muzzle="bip01 r hand",clip="melee"}}
profiles.marine_heavy.sourceWhm="art/ebps/races/space_marines/troops/space_marine.whm"
profiles.marine_heavy.weaponSlots={{name="Heavy bolter",kind="Cannon",muzzle="marker_marine_ heavy_bolter_barrel",clip="fire"}}
profiles.marine_scout.sourceWhm="art/ebps/races/space_marines/troops/scout_ua.whm"
profiles.marine_scout.weaponSlots={{name="Scout bolter",kind="Cannon",muzzle="marker_marine_bolter_barrel",clip="fire"}}
profiles.marine_tactical.sourceWhm="art/ebps/races/space_marines/troops/space_marine_tactical.whm"
profiles.marine_tactical.weaponSlots={{name="Bolter",kind="Cannon",muzzle="marker_marine_bolter_barrel",clip="fire"}}
profiles.marine_terminator.sourceWhm="art/ebps/races/space_marines/troops/terminator.whm"
profiles.marine_terminator.weaponSlots={{name="Storm bolter",kind="Cannon",muzzle="marker_terminator_storm_bolter_barrel",clip="fire"},{name="Terminator power fist",kind="Melee",muzzle="bip01 l hand",clip="melee"}}
profiles.necron_flayed.sourceWhm="art/ebps/races/necrons/troops/flayed_one.whm"
profiles.necron_flayed.weaponSlots={{name="Flayer blades",kind="Melee",muzzle="mrkr_blade_r_01",clip="melee"}}
profiles.necron_immortal.sourceWhm="art/ebps/races/necrons/troops/necron_immortal.whm"
profiles.necron_immortal.weaponSlots={{name="Gauss Blaster",kind="BeamLaser",muzzle=" marker_gauss_muzzle01_ext",clip="fire"},{name="Gauss Blaster right tube",kind="BeamLaser",muzzle=" marker_gauss_muzzle02_ext",clip="fire"}}
profiles.necron_warrior.sourceWhm="art/ebps/races/necrons/troops/necron_basic_warrior.whm"
profiles.necron_warrior.weaponSlots={{name="Gauss Flayer",kind="BeamLaser",muzzle="marker_gun_muzzle_ctr_out",clip="fire"}}
profiles.necron_wraith.sourceWhm="art/ebps/races/necrons/troops/wraith.whm"
profiles.necron_wraith.weaponSlots={{name="Phase claws",kind="Melee",muzzle="mrkr_needle_right_01",clip="melee"}}
profiles.ork_burna.sourceWhm="art/ebps/races/orks/troops/boyz.whm"
profiles.ork_burna.weaponSlots={{name="Burna",kind="Flame",muzzle="marker_boyz_burna_barrel",clip="fire"}}
profiles.ork_loota.sourceWhm="art/ebps/races/orks/troops/lootas.whm"
profiles.ork_loota.weaponSlots={{name="Deffgun",kind="Cannon",muzzle="marker_deffgun1_muzzle_1",clip="fire"}}
profiles.ork_meganob.sourceWhm="art/ebps/races/orks/troops/mega_armoured_nobz.whm"
profiles.ork_meganob.weaponSlots={{name="Shoota",kind="Cannon",muzzle="marker_warboss_kustom_shoota_barrel_1",clip="fire"},{name="Power Klaw",kind="Melee",muzzle="marker_warboss_kustom_shoota_barrel_2",clip="melee"}}
profiles.ork_nob.sourceWhm="art/ebps/races/orks/troops/nobz.whm"
profiles.ork_nob.weaponSlots={{name="Nob Slugga",kind="Cannon",muzzle="marker_nobz_slugga_barrel",clip="fire"},{name="Nob Choppa",kind="Melee",muzzle="marker_nobz_choppa_axe_blade",clip="melee"}}
profiles.ork_shoota.sourceWhm="art/ebps/races/orks/troops/ard_boyz.whm"
profiles.ork_shoota.weaponSlots={{name="Shoota",kind="Cannon",muzzle="marker_boyz_big_shoota_barrel",clip="fire"}}
profiles.ork_slugga.sourceWhm="art/ebps/races/orks/troops/boyz.whm"
profiles.ork_slugga.weaponSlots={{name="Slugga",kind="Cannon",muzzle="marker_boyz_slugga_barrel",clip="fire"},{name="Choppa",kind="Melee",muzzle="marker_boyz_choppa_axe_blade",clip="melee"}}
profiles.ork_tankbusta.sourceWhm="art/ebps/races/orks/troops/tankbustas.whm"
profiles.ork_tankbusta.weaponSlots={{name="Rokkit Launcha",kind="MissileLauncher",muzzle="marker_boyz_rokkit_launcha_barrel",clip="fire"}}
return {version=1,profiles=profiles,initial={'guard_line','ork_shoota','necron_warrior'},
 -- Do not create/activate these with an ordinary homogeneous recipe.
 exceptions={
  imp_heavy_weapon_team={capacity=2,actor='imp_heavy_weapon_team',deployed='imp_heavy_weapon_team_deployed',reason='One authored deployed actor already contains two animated crew meshes. Preserve deploy/pack morph and per-slot investment before squad integration; capacity counts teams, not rendered humans.'},
  ork_stormboy={capacity=4,actor='ork_stormboy',reason='Existing source cohort, factory receipt and jump owners require explicit replacement; one ordinary squad owner must supersede them. No current raw UnitDef row in units tree.'},
  imp_tactical_bike_source={reason='Mounted actor, existing special paid cohort/population owners; excluded from foot-infantry rollout.'}},
 individuals={'imp_commissar','imp_enginseer','imp_force_commander','ork_warboss','ork_big_mek_defence','ork_grot','nec_lord','nec_scarab'},
 contracts={cost='bodyCost is raw authored source expectation, never aggregate product price; read real final body definition before creating squad',
  transport='Reserve capacity for every real passenger; never count squad as one soldier',
  special='false means no authored eligible replacement; distinct elite classes are not arbitrary weapon upgrades',
  provenance='Private checker proves current owned copied source/model existence; this data does not claim new native acceptance'}}
