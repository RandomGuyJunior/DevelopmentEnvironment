-- Four visible gun openings, distinct native projectiles, one shared physical arm.
local M={Revision='dakka_four_guns_v1'}
M.Mounts={
 {slot=2,marker='project_dakka_upper_cannon_muzzle',name='Upper Heavy Arm Cannon',range=680,reload=4.8,damage=60,blast=40,size=1.8,velocity=440,family='tankcannon',clip='fire_dakka_arm'},
 {slot=5,marker='project_dakka_lower_cannon_muzzle',name='Lower Arm Cannon',range=600,reload=3.2,damage=36,blast=24,size=1.1,velocity=520,family='tankcannon',clip=''},
 {slot=6,marker='project_dakka_medium_muzzle',name='Arm Autocannon',range=520,reload=.8,damage=10,blast=8,size=.5,velocity=620,family='autocannon',clip=''},
 {slot=7,marker='project_dakka_small_muzzle',name='Arm Machine Gun',range=420,reload=.16,damage=3,blast=1,size=.2,velocity=760,family='big_shoota',clip=''},
}
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local function hash(x)return type(x)=='string'and #x==64 and not x:find('[^0-9a-f]')end
function M.Supported(f)
 if type(f)~='table'or f.version~=1 or f.parent~='dakka_arm_bone'or not hash(f.source_glb_sha256)or not hash(f.native_glb_sha256)or not hash(f.binary_sha256)or type(f.markers)~='table'then return false end
 local count=0;for _ in pairs(f.markers)do count=count+1 end;if count~=4 then return false end
 for _,m in ipairs(M.Mounts)do local x=f.markers[m.marker];if type(x)~='table'or type(x.ring_vertices)~='number'or type(x.local_position)~='table'or #x.local_position~=3 or x.mouth_clearance~=.3 or x.ring_vertices<18 then return false end;for _,v in ipairs(x.local_position)do if type(v)~='number'or v~=v or math.abs(v)==math.huge then return false end end end
 return true
end
function M.Apply(d,f)
 if not M.Supported(f)then return nil,'actual_four_muzzle_geometry_proof_missing'end
 if not d or d.objectname~='ork_dakka_stompa.glb'or not d.customparams or d.customparams.source_stompa_design~='stompa_design_20261008'then return nil,'retained_new_beam_belly_design_required'end
 local out=copy(d);out.objectname='ork_dakka_stompa_multigun.glb';out.customparams.source_stompa_arm_status=M.Revision;out.customparams.source_native_glb_sha256=f.native_glb_sha256;out.customparams.source_multigun_geometry_sha256=f.binary_sha256
 local template=out.weapondefs.mount2
 for _,m in ipairs(M.Mounts)do
  local w=copy(template);w.name=m.name;w.weapontype='Cannon';w.range=m.range;w.reloadtime=m.reload;w.damage={default=m.damage};w.areaofeffect=m.blast;w.weaponvelocity=m.velocity;w.size=m.size;w.burst=1;w.burstrate=nil;w.hightrajectory=0;w.edgeeffectiveness=.35
  w.customparams.source_muzzle=m.marker;w.customparams.source_fireclip=m.clip;w.customparams.source_aimpiece='dakka_arm_aim_horizontal';w.customparams.source_pitchpiece='dakka_arm_aim_vertical';w.customparams.source_fx_family=m.family;w.customparams.source_muzzlefx='40k_dow_'..m.family..'_muzzle';w.customparams.source_damage_authority='native_projectile_collision_only';w.explosiongenerator='custom:40k_dow_'..m.family..'_impact'
  w.soundstart='';w.soundhit='';w.soundtrigger=true
  if VFS.FileExists('40k_configs/generated_audio.lua')then local a=VFS.Include('40k_configs/generated_audio.lua');local x=a['weapon_'..m.family];if x and x[1]and VFS.FileExists(x[1].file)then w.soundstart='40k_'..m.family end;local hit=a.weapon_explosion;if m.blast>=16 and hit and hit[1]and VFS.FileExists(hit[1].file)then w.soundhit='40k_explosion'end end
  local key='mount'..m.slot;out.weapondefs[key]=w;out.weapons[m.slot]={def=key,onlytargetcategory='SURFACE'}
 end
 return out,{revision=M.Revision,nativeAccepted=false,armDPS=55,previousArmDPS=100/1.8,geometryChanged=false,independentTurrets=false}
end
return M
