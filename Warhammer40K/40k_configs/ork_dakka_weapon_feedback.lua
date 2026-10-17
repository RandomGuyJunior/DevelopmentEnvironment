-- Explicit human weapon feedback. Exact paired Dakka; native hits own damage.
local M={Policy='dakka_human_weapons_r3_v1',ArmReload=.8,BellySizeMultiplier=2}
local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
local beamVisuals={'rgbcolor','rgbcolor2','beamtime','beamttl','beamdecay','thickness','corethickness','laserflaresize',
 'texture1','texture2','texture3','texture4','largebeamlaser','intensity','colormap','explosiongenerator',
 'soundstart','soundstartvolume','soundhit','soundhitvolume','soundhitdry','soundhitdryvolume','soundhitwet','soundhitwetvolume','soundtrigger'}
local shellVisuals={'size','stages','rgbcolor','rgbcolor2','intensity','alphadecay','sizedecay','model','cegtag',
 'texture1','texture2','texture3','texture4','explosiongenerator','soundstart','soundhit','soundtrigger'}
function M.Apply(d,reference)
 local c=d and d.customparams or{}
 assert(d and d.objectname=='ork_dakka_stompa_jugref.glb'and c.animsource=='ork_dakka_stompa'
  and c.source_native_glb_sha256=='184bb884ba03f5ceef1dda85cdbb4648527a5f9e89f1b45928cb4f7538f50748'
  and c.source_dakka_gait_policy=='dakka_distance_locked_boots_v1','Exact accepted gait/model pair required')
 assert(not c.source_dakka_weapon_policy,'Duplicate Dakka weapon feedback owner')
 assert(reference and reference.objectname:lower()=='units/corkorg.s3o'and reference.script:lower()=='units/corkorg.cob','Actual corkorg donor required')
 local laser=assert(reference.weapondefs.corkorg_laser,'Actual Juggernaut laser missing')
 assert(laser.weapontype=='BeamLaser'and laser.thickness==6 and laser.beamtime==.6
  and laser.rgbcolor=='1 0.55 0'and laser.laserflaresize==8.25,'Exact pinned corkorg laser presentation changed')
 local w=d.weapondefs;local belly=assert(w.mount1);local arm=assert(w.mount4);local eye=assert(w.mount3)
 assert(belly.weapontype=='Cannon'and arm.weapontype=='BeamLaser'and eye.weapontype=='BeamLaser','Native Dakka weapon identities differ')
 local largest=w.mount2;for _,n in ipairs({2,5,6,7})do
  assert(w['mount'..n].weapontype=='Cannon','Real cannon arm mount required')
  if w['mount'..n].size>largest.size then largest=w['mount'..n]end
 end
 local shell=copy(largest) -- Snapshot before modifying any shared template.
 belly.name='Heavy Direct-fire Belly Cannon';belly.hightrajectory=0;belly.size=belly.size*M.BellySizeMultiplier
 for _,row in ipairs({{weapon=arm,scale=1},{weapon=eye,scale=.5}})do
  local target=row.weapon
  for _,key in ipairs(beamVisuals)do target[key]=copy(laser[key])end
  target.thickness=laser.thickness*row.scale;target.laserflaresize=laser.laserflaresize*row.scale
  target.customparams.source_visual_donor='corkorg:corkorg_laser';target.customparams.source_visual_scale=row.scale
  target.customparams.source_damage_authority='native_weapon_impact_only'
 end
 arm.name='Juggernaut-pattern Arm Heat Ray';eye.name='Half-size Eye Heat Ray'
 local names={[2]='Upper',[5]='Lower',[6]='Medium',[7]='Small'}
 for _,n in ipairs({2,5,6,7})do
  local target=w['mount'..n];for _,key in ipairs(shellVisuals)do target[key]=copy(shell[key])end
  target.name=names[n]..' Arm Rapid Cannon';target.reloadtime=M.ArmReload
  target.customparams.source_fireclip='' -- One physical arm recoil owner below.
  target.customparams.source_muzzlefx=shell.customparams.source_muzzlefx
  target.customparams.source_fx_family=shell.customparams.source_fx_family
  target.customparams.source_dakka_recoil_owner=M.Policy
 end
 c.source_dakka_weapon_policy=M.Policy;c.source_dakka_arm_cadence=M.ArmReload
 -- Existing roster classification: actual guns aim independently of the feet.
 -- This unlocks moving aim through the unchanged native alignment/clearance gates.
 c.source_independent_weapon_assemblies=1
 return true
end
return M
