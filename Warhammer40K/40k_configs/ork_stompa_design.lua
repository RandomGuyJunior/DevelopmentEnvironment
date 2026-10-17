-- Deliberate project tuning authorized2026-10-08; not original DoW balance.
local M={Revision='stompa_design_20261008'}
M.Tuning={pulse={range=650,reload=3.2,damage=260,beamtime=.085,blast=24,colour='1 .607 .047'},belly={range=1100,reload=8,damage=700,velocity=420,blast=96}}
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
function M.Apply(d)
 if not d then return nil,'actor_not_registered'end
 if d.objectname~='ork_dakka_stompa.glb'or d.script~='40k_roster.lua'or not d.customparams or d.customparams.animsource~='ork_dakka_stompa'then return nil,'wrong_retained_actor'end
 local w=d.weapondefs;local p=w and w.mount4 and w.mount4.customparams;local belly=w and w.mount1 and w.mount1.customparams
 if not p or p.source_muzzle~='lifta_droppa_beam_start'or p.source_aimpiece~='lifta_droppa_aim_horizontal'or p.source_pitchpiece~='lifta_droppa_aim_vertical'or not belly or belly.source_muzzle~='belly_gun_muzzle'then return nil,'actual_emitter_or_belly_marker_missing'end
 local out=copy(d);local cp=out.customparams;cp.lifta_adaptation=nil;cp.source_stompa_design=M.Revision;cp.source_stompa_arm_status='existing_single_dakka_mount_full_four_gun_geometry_catalog_pending'
 out.name='Dakka Stompa';out.description='Heavy walker: belly artillery, rapid dakka, Zzzap and orange pulse cannon; no lifting'
 local pulse=out.weapondefs.mount4;local t=M.Tuning.pulse
 pulse.name='Orange Pulse Cannon';pulse.weapontype='BeamLaser';pulse.range=t.range;pulse.reloadtime=t.reload;pulse.beamtime=t.beamtime;pulse.damage={default=t.damage};pulse.areaofeffect=t.blast;pulse.rgbcolor=t.colour;pulse.rgbcolor2='1 .86 .25';pulse.thickness=2.2;pulse.corethickness=.32;pulse.beamburst=false;pulse.burst=1;pulse.burstrate=nil;pulse.soundtrigger=true;pulse.explosiongenerator='custom:40k_dow_artillery_impact';pulse.impulsefactor=0
 -- Native BeamLaser impact samples each sim frame; suppress repeated impact
 -- audio. One short existing laser-family launch sound accompanies each pulse.
 pulse.soundstart='';pulse.soundhit='';pulse.soundhitdry='';pulse.soundhitwet='';pulse.soundstartvolume=.7
 if VFS.FileExists('40k_configs/generated_audio.lua')then
  local a=VFS.Include('40k_configs/generated_audio.lua');local clips=a.weapon_hellgun
  if clips and clips[1]and VFS.FileExists(clips[1].file)then pulse.soundstart='40k_hellgun'end
 end
 pulse.customparams.prototype40k_lifta_hold=nil;pulse.customparams.source_native_adaptation='authored_orange_native_single_pulse_v1';pulse.customparams.source_damage_authority='native_weapon_impact_only'
 out.weapons[4].onlytargetcategory='SURFACE VTOL'
 local gun=out.weapondefs.mount1;local a=M.Tuning.belly
 gun.name='Heavy Belly Artillery';gun.weapontype='Cannon';gun.range=a.range;gun.reloadtime=a.reload;gun.weaponvelocity=a.velocity;gun.damage={default=a.damage};gun.areaofeffect=a.blast;gun.hightrajectory=1;gun.gravityaffected=true;gun.mygravity=.12;gun.size=3;gun.stages=4;gun.rgbcolor='1 .65 .22';gun.explosiongenerator='custom:40k_dow_artillery_impact';gun.edgeeffectiveness=.35;gun.burst=1;gun.burstrate=nil;gun.customparams.source_damage_authority='native_projectile_collision_only'
 gun.soundtrigger=true;gun.soundhitdry=nil;gun.soundhitwet=nil
 if VFS.FileExists('40k_configs/generated_audio.lua')then local a=VFS.Include('40k_configs/generated_audio.lua');local shots=a.weapon_artillery;local hits=a.weapon_explosion
  if shots and shots[1]and VFS.FileExists(shots[1].file)then gun.soundstart='40k_artillery';gun.soundstartvolume=1 end
  if hits and hits[1]and VFS.FileExists(hits[1].file)then gun.soundhit='40k_explosion';gun.soundhitvolume=.7 end
 end
 return out,{revision=M.Revision,nativeAccepted=false,lifting=false,oneNativeDamageAuthority=true,fullArmPending=true}
end
return M
