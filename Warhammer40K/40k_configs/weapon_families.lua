-- Explicit mounted weapon families from genuine DoW + UA source references.
local families={
 ["lasgun"]={muzzle="40k_dow_lasgun_muzzle",impact="custom:40k_dow_lasgun_impact"},
 ["hellgun"]={muzzle="40k_dow_hellgun_muzzle",impact="custom:40k_dow_hellgun_impact"},
 ["multilaser"]={muzzle="40k_dow_multilaser_muzzle",impact="custom:40k_dow_multilaser_impact"},
 ["bolter"]={muzzle="40k_dow_bolter_muzzle",impact="custom:40k_dow_bolter_impact"},
 ["heavy_bolter"]={muzzle="40k_dow_heavy_bolter_muzzle",impact="custom:40k_dow_heavy_bolter_impact"},
 ["assaultcannon"]={muzzle="40k_dow_assaultcannon_muzzle",impact="custom:40k_dow_assaultcannon_impact"},
 ["autocannon"]={muzzle="40k_dow_autocannon_muzzle",impact="custom:40k_dow_autocannon_impact"},
 ["slugga"]={muzzle="40k_dow_slugga_muzzle",impact="custom:40k_dow_slugga_impact"},
 ["shoota"]={muzzle="40k_dow_shoota_muzzle",impact="custom:40k_dow_shoota_impact"},
 ["big_shoota"]={muzzle="40k_dow_big_shoota_muzzle",impact="custom:40k_dow_big_shoota_impact"},
 ["tankcannon"]={muzzle="40k_dow_tankcannon_muzzle",impact="custom:40k_dow_tankcannon_impact"},
 ["artillery"]={muzzle="40k_dow_artillery_muzzle",impact="custom:40k_dow_artillery_impact"},
 ["rokkit"]={muzzle="40k_dow_rokkit_muzzle",impact="custom:40k_dow_rokkit_impact"},
 ["flamer"]={muzzle="40k_dow_flamer_muzzle",impact="custom:40k_dow_flamer_impact"},
 ["gauss"]={muzzle="40k_dow_gauss_muzzle",impact="custom:40k_dow_gauss_impact"},
 ["gauss_heavy"]={muzzle="40k_dow_gauss_heavy_muzzle",impact="custom:40k_dow_gauss_heavy_impact"},
 ["particle"]={muzzle="40k_dow_particle_muzzle",impact="custom:40k_dow_particle_impact"},
 ["tesla"]={muzzle="40k_dow_tesla_muzzle",impact="custom:40k_dow_tesla_impact"},
 ["claw"]={impact="custom:40k_dow_claw_impact"},
 ["choppa"]={impact="custom:40k_dow_choppa_impact"},
 ["necron_blade"]={impact="custom:40k_dow_necron_blade_impact"},
 ["blunt"]={impact="custom:40k_dow_blunt_impact"},
}
local mounts={
 ["imp_guardsman"]={"lasgun"},
 ["imp_marine"]={"bolter"},
 ["imp_russ"]={"tankcannon","heavy_bolter","heavy_bolter","heavy_bolter"},
 ["ork_boy"]={"big_shoota"},
 ["ork_meganob"]={"big_shoota","claw"},
 ["ork_killa_kan"]={"big_shoota","claw"},
 ["imp_enginseer"]={"lasgun"},
 ["imp_commissar"]={"lasgun"},
 ["imp_kasrkin"]={"hellgun"},
 ["imp_scout"]={"bolter"},
 ["imp_devastator"]={"heavy_bolter"},
 ["imp_ogryn"]={"big_shoota","blunt"},
 ["imp_heavy_weapon_team"]={"lasgun"},
 ["imp_heavy_weapon_team_deployed"]={"heavy_bolter"},
 ["imp_sentinel"]={"multilaser"},
 ["imp_dreadnought"]={"assaultcannon","claw"},
 ["imp_basilisk"]={"artillery","heavy_bolter"},
 ["imp_hellhound"]={"flamer","heavy_bolter"},
 ["imp_predator"]={"autocannon","heavy_bolter","heavy_bolter"},
 ["ork_slugga"]={"slugga","choppa"},
 ["ork_burna"]={"flamer"},
 ["ork_tankbusta"]={"rokkit"},
 ["ork_loota"]={"big_shoota"},
 ["ork_nob"]={"slugga","choppa"},
 ["ork_warboss"]={"big_shoota","claw"},
 ["ork_wartrak"]={"big_shoota"},
 ["ork_trukk"]={"big_shoota"},
 ["ork_gunwagon"]={"tankcannon"},
 ["ork_deff_dread"]={"big_shoota","big_shoota","claw"},
 ["ork_lobba"]={"artillery"},
 ["ork_boyz_hut"]={"big_shoota","big_shoota"},
 ["ork_settlement"]={"big_shoota","big_shoota"},
 ["ork_listening_post"]={"big_shoota"},
 ["ork_waaagh_banner"]={"big_shoota"},
}
local lateMounts=VFS.Include('40k_configs/late_weapon_families.lua')
for key,roles in pairs(lateMounts)do mounts[key]=roles end
-- Aliases retain the genuine source actor mount effects.
for name,ud in pairs(UnitDefs) do
 local donor=ud.customparams and ud.customparams.prototype40k_donor
 if donor and mounts[donor] then mounts[name]=mounts[donor];if lateMounts[donor]then lateMounts[name]=lateMounts[donor]end end
end
for name,roles in pairs(mounts)do
 local ud=UnitDefs[name]
 if ud and ud.weapondefs then
  for n,family in ipairs(roles)do
   local mount=ud.weapons and ud.weapons[n]
   local w=mount and ud.weapondefs[(mount.def or ""):lower()]
   local fx=families[family]
   if w and lateMounts[name] then
    w.customparams=w.customparams or {}
    if not fx then w.customparams.source_effects_pending=1 end
   end
   if w and fx then
    w.explosiongenerator=fx.impact
    w.customparams=w.customparams or {};w.customparams.source_fx_family=family
    if fx.muzzle then w.customparams.source_muzzlefx=fx.muzzle end
    -- The walker pulse is heavier than infantry lasfire without changing hits.
    if family=="multilaser"then w.thickness=.65 end
    -- Native decals are cosmetic; earthshaker cratering remains disabled.
    if family=="artillery"and((ud.customparams or{}).prototype40k_donor or name)=="imp_basilisk"then
     w.explosionscar=true;w.scardiameter=72;w.scaralpha=.7
     w.scarttl=90;w.scarglow=.1;w.scarglowttl=2
    end
    if w.weapontype~="Melee" and not lateMounts[name] then
     -- Spread is native physical aim error; there are no cosmetic miss shots.
     w.accuracy=math.max(tonumber(w.accuracy) or 0,family=="artillery" and 140 or 70)
     w.sprayangle=math.max(tonumber(w.sprayangle) or 0,70)
     w.collidefriendly=true;w.collideenemy=true;w.collideground=true
     w.collidefeature=true;w.collideneutral=true;w.collidenontarget=true
     if family=="rokkit" then w.cegtag="40k_dow_rokkit_trail" end
    end
   end
  end
  if ud.sfxtypes then
   ud.sfxtypes.explosiongenerators={"custom:40k_dow_lasgun_muzzle","custom:40k_dow_bolter_muzzle","custom:40k_dow_shoota_muzzle","custom:40k_dow_heavy_bolter_muzzle","custom:40k_dow_tankcannon_muzzle"}
  end
 end
end

-- The genuine stationary gauss emitter export has idle only. Native beams/Shot
-- remain functional without claiming a recovered source firing animation.
local staticEmitter=UnitDefs.nec_turret
if staticEmitter then
 for _,w in pairs(staticEmitter.weapondefs or {})do
  w.customparams=w.customparams or {}
  w.customparams.source_fireclip=''
  w.customparams.source_fire_animation_static=1
 end
end
