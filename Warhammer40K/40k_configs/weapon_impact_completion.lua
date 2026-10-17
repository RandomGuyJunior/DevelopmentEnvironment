-- Cosmetic-only completion of evidenced gaps. Native hits remain sole damage.
local M={Owner='native_positive_melee_hit_v1'}
local function yes(v)return v==true or v==1 or v=='1'end
local function supported(key,d,naval)
 local c=d.customparams or{}
 return yes(c.prototype40k)and key~='ork_kustim_stompa'and not yes(c.prototype40k_bank_only)and not naval.IsNaval(key,d)
end
local missing={
 ork_ard_boy={[2]={'Melee','custom:40k_dow_choppa_impact'}},
 ork_ard_boy_member={[2]={'Melee','custom:40k_dow_choppa_impact'}},
 ork_kommando={[2]={'Melee','custom:40k_dow_choppa_impact'}},
 ork_kommando_member={[2]={'Melee','custom:40k_dow_choppa_impact'}},
 ork_battlewagon_armageddon={[1]={'BeamLaser','custom:40k_native_beam_blue_impact','.45 .85 1'}},
 ork_battlefortress_armageddon={[1]={'BeamLaser','custom:40k_native_beam_blue_impact','.45 .85 1'},[4]={'BeamLaser','custom:40k_native_beam_blue_impact','.45 .85 1'},[5]={'BeamLaser','custom:40k_native_beam_blue_impact','.45 .85 1'}},
 ork_great_gargant={[2]={'BeamLaser','custom:40k_native_beam_blue_impact','.45 .85 1'}},
 ork_gargant={[4]={'BeamLaser','custom:40k_native_beam_green_impact','.5 1 .2'}},
 ork_squiggoth={[1]={'Melee','custom:40k_dow_blunt_impact'},[4]={'BeamLaser','custom:40k_native_beam_green_impact','.5 1 .2'},[7]={'BeamLaser','custom:40k_native_beam_green_impact','.5 1 .2'}},
 ork_dakka_stompa={[3]={'BeamLaser','custom:40k_native_beam_green_impact','.5 1 .2'}},
 imp_dreadnought_venerable={[1]={'BeamLaser','custom:40k_native_beam_orange_impact','1 .45 .1'},[2]={'Melee','custom:40k_dow_claw_impact'}},
 imp_dreadnought_ironclad={[1]={'Melee','custom:40k_dow_claw_impact'},[2]={'Melee','custom:40k_dow_claw_impact'},[3]={'Flame','custom:40k_dow_flamer_impact'}},
 smcom={[2]={'Melee','custom:40k_dow_power_fist_impact'}},
 ork_morkanaut={[4]={'Melee','custom:40k_dow_claw_impact'}},
}
local function mount(d,slot)
 local row=d.weapons and d.weapons[slot]
 return row and d.weapondefs and d.weapondefs[tostring(row.def or''):lower()]
end
function M.Apply(defs,naval)
 local report={artillery={},missing={},melee={}}
 for key,bindings in pairs(missing)do
  local d=defs[key]
  if d and supported(key,d,naval)then for slot,row in pairs(bindings)do
   local w=mount(d,slot)
   if w and not w.explosiongenerator then
    assert(w.weapontype==row[1]and(not row[3]or w.rgbcolor==row[3]),'Exact missing native impact mount changed: '..key..':'..slot)
    w.explosiongenerator=row[2];report.missing[#report.missing+1]=key..':'..slot
   end
  end end
 end
 -- Retain stable ART1/2 weapon identities and all mechanics; replace only their
 -- tiny bespoke glints with the existing stock shell-explosion presentation.
 for key,size in pairs({ork_boomy_platform='medium',ork_kaboomy_platform='large'})do
  local d=defs[key];local w=d and supported(key,d,naval)and mount(d,1)
  if w then
   assert(w.weapontype=='Cannon','Exact fixed artillery native Cannon required')
   local expected=key=='ork_boomy_platform'and'custom:40k_ork_artillery_t1_impact'or'custom:40k_ork_artillery_t2_impact'
   assert(w.explosiongenerator==expected,'Do not replace another artillery effect owner')
   w.explosiongenerator='custom:genericshellexplosion-'..size;report.artillery[#report.artillery+1]=key
  end
 end
 -- CMeleeWeapon::FireImpl invokes DoDamage directly, without a native CEG.
 -- Explicit CPs admit only these real 40K melee mounts to the hit observer.
 for key,d in pairs(defs)do if supported(key,d,naval)then
  for slot in pairs(d.weapons or{})do
   local w=mount(d,slot)
   if w and w.weapontype=='Melee'and type(w.explosiongenerator)=='string'then
    local name=w.explosiongenerator:match('^custom:([a-z0-9_%-]+)$')
    if name then
     w.customparams=w.customparams or{}
     assert(not w.customparams.prototype40k_contact_impact_owner,'Another contact effect owner already exists')
     w.customparams.prototype40k_contact_impact_owner=M.Owner
     w.customparams.prototype40k_contact_impact_ceg=name
     report.melee[#report.melee+1]=key..':'..slot
    end
   end
  end
 end end
 return report
end
return M
