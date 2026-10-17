-- Standalone authored Imperial FX mapping; coordinator integrates after shared
-- weapon_families. Exact source event identities are data, not acceptance flags.
local M={}
M.Families={
 lascannon={muzzle='40k_dow_lascannon_muzzle',impact='custom:40k_dow_lascannon_impact'},
 plasma_blastgun={muzzle='40k_dow_plasma_blastgun_muzzle',impact='custom:40k_dow_plasma_blastgun_impact'},
 chainsword={impact='custom:40k_dow_chainsword_impact',contact=true},
 power_fist={impact='custom:40k_dow_power_fist_impact',contact=true},
}
M.Mounts={imp_baneblade={[3]='lascannon',[4]='lascannon'},imp_warhound={[1]='plasma_blastgun'},imp_assault_marine={[2]='chainsword'},imp_terminator={[2]='power_fist'}}
M.SourceEvents={
 lascannon={events={'lascannon_flash_fire_l','lascannon_flash_fire_r'},markers={'marker_lascannon_l','marker_lascannon_r'},fx='guard/weapon_fx/large/muzzle/lascannon_muzzle',targetLength=true},
 plasma_blastgun={events={'plasma_fire_left_1_flash','plasma_fire_left_2_flash','plasma_fire_bolt_left_1','plasma_fire_bolt_left_2'},markers={'marker_lplasma_barrel1','marker_lplasma_barrel2'},fx='titan/weapons/plasma_blastgun_outter_muzzle',beam='titan/weapons/plasma_blastgun_main_beam',sourceScale=2,targetLength=true},
 chainsword={events={'chainsword_sparks','chainsword_large_hit'},markers={'marker_chaos_chainsword_blade'},fx='spray_knife_sparks_2'},
 power_fist={events={'power_fist_lightning_hit'},markers={'marker_marine_power_fist_palm'},fx='unit_melee_lightning_combo_spray'},
}
M.Limits={nativeAppearancePending=true,sourceParticleCurvesAdapted=true,plasmaSourceBeamMechanicsPending=true,contactMarkerVerificationPending=true}
function M.Apply(defs)
 local report={mapped={},blocked={}}
 for name,d in pairs(defs)do
  local donor=(d.customparams or{}).prototype40k_donor or name;local roles=M.Mounts[donor]
  if roles then for n,family in pairs(roles)do
   local mount=d.weapons and d.weapons[n];local key=mount and mount.def and mount.def:lower();local w=key and d.weapondefs and d.weapondefs[key];local fx=M.Families[family]
   if w and fx and (not fx.contact or w.weapontype=='Melee')then
    w.customparams=w.customparams or{};local cp=w.customparams
    cp.source_fx_family=family;cp.source_effects_pending=nil;cp.source_fx_native_pending=1
    w.explosiongenerator=fx.impact
    if fx.contact then cp.source_muzzlefx=nil;cp.source_no_muzzle=1
    else cp.source_muzzlefx=fx.muzzle;cp.source_no_muzzle=nil end
    report.mapped[#report.mapped+1]=name..':'..n..':'..family
   else report.blocked[#report.blocked+1]=name..':'..n end
  end end
 end
 return report
end
return M
