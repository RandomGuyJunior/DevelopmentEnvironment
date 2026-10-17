-- Prepared source recipe only. No profile, UnitDef, research or actor is activated.
-- Costs below are authored proposals, never imported prices or paid receipts.
local M={Version=1}
M.Guard={profile='guard_line',id=2,capacity=8,slot=8,active=false,state='genuine_source_conversion_required',
 sourceActor='guardsman',actor='guardsman_flamer',sourceSpecial='imp_guardsman_flamer',internal='imp_guardsman_flamer_member',
 whm='art/ebps/races/imperial_guard/troops/guardsmen_codex.whm',
 whmSHA256='06abd2827ac9c67e6ec6aef2b3f95421b8c6ee8138e7128bb197865f329158bb',
 entity='attrib/ebps/races/guard/troops/guard_infantry_guardsmen.lua',
 hardpoint='hardpoint_01',weaponChoice='weapon_03',sourceWeapon='weapon/guard_flamer_guardsmen.lua',
 visible={'guardsmen_body','guardsmen_head01','guardsmen_chest01','guardsmen_l_shoulder','guardsmen_r_shoulder_1',
  'guardsmen_flamer','weapons_backpack','guardsmen_knife_waist','guardsmen_grenade_belt'},
 hidden={'guardsmen_lasgun','normal_backpack','guardsmen_plasmagun','guardsmen_grenade_launcher','melta_gun'},
 visibility='vis_flamer',muzzle='marker_flamer_muzzle',muzzleParent='bone_ig_hand_weapon_r',weaponType='Flame',
 clips={idle='idle_1',walk='move_run_1',fire='idle_firing_flamer',death='die_normal_1'},
 proposedBodyCost={metal=18,energy=90,work=220},
 research='guard_squad_flamer',researchRow={name='Squad flamer',description='One genuine Guardsman flamer specialist per line squad; missing bodies require paid builder repair.',
  producer='imp_research',cost={metal=200,energy=1000},time=35,requires={buildings={'imp_research'}}},
 gates={'complete_genuine_derivative','muzzle_attachment_and_fire_clip','source_matched_death_feature','native_paid_role_and_repair','native_transport_if_enabled'}}
M.Necron={profile='necron_warrior',id=4,capacity=5,active=false,special=false,state='no_eligible_warrior_variant',
 reason='Current genuine Warrior has one Gauss Flayer. Immortal is a distinct elite class, not a Warrior weapon variant.'}
function M.CurrentEligibility(defs)
 assert(type(defs)=='table','Definitions required')
 -- An unreviewed new key or borrowed elite must never opt this recipe into play.
 return{guard={eligible=false,reason=M.Guard.state},necron={eligible=false,reason=M.Necron.state}}
end
return M
