-- Unpaid, default-off diagnostic of the exact saved scale pair. This is not
-- normal roster readiness. Native evidence may only be earned after loading it.
local M={Actor='ork_dakka_stompa',Factor=.7060140223403837,MoveClass='40K_ORK_DAKKA_JUGREF'}
local function copy(x)if type(x)~='table'then return x end;local r={};for k,v in pairs(x)do r[k]=copy(v)end;return r end
local function on(x)return x==true or x==1 or x=='1'end
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function vector(v)return type(v)=='table'and #v==3 and finite(v[1])and finite(v[2])and finite(v[3])end
local function text(v)return string.format('%.12g %.12g %.12g',v[1],v[2],v[3])end
function M.Enabled(o,V)
 return on((o or{}).prototype_dakka_reference_review)and(V.Include('40k_configs/stompa_weapon_fixture.lua').Enabled(o)or V.Include('40k_configs/human_inspection_scene.lua').Enabled(o))
end
function M.Preflight(d,f,V)
 local function need(v,why)if not v then error('Dakka reference diagnostic: '..why,2)end end
 local cp=d and d.customparams or{}
 need(d and d.script=='40k_roster.lua'and d.objectname=='ork_dakka_stompa_multigun.glb'
  and cp.animsource==M.Actor and cp.source_stompa_arm_status=='dakka_four_guns_v1','exact_multigun_baseline')
 need(not cp.scale_pilot_factor and not cp.scale_animation_bank and not cp.ork_v14_scale_factor,'no_prior_scale')
 need(f and f.schema==1 and f.actor==M.Actor and f.factor==M.Factor and f.recipe=='dakka-juggernaut-diagnostic-v2','exact_facts')
 need(f.modelSHA256=='184bb884ba03f5ceef1dda85cdbb4648527a5f9e89f1b45928cb4f7538f50748'
  and f.bankSHA256=='de744aa33697305d301db507443ae44a745184770ad524dac934ae51af49858d'
  and f.wreckSHA256=='ef3a4e10c2a112419cd3a350519c22735203d0e93011587227619b2de1ca7afc','exact_saved_asset_pair')
 need(f.model=='ork_dakka_stompa_jugref.glb'and f.bank=='ork_dakka_stompa_jugref'
  and f.wreckModel=='ork_dakka_stompa_jugref_wreck.glb'and f.wreckNormalsValid==true,'exact_asset_names')
 for _,name in ipairs({'collision','selection'})do
  local row=f[name];need(row and row.type=='Box'and vector(row.scales)and vector(row.offsets),'literal_'..name)
  for i=1,3 do need(row.scales[i]>0,'positive_'..name)end
 end
 need(vector(f.wreckBounds.size)and vector(f.wreckBounds.mid)and f.wreckGroundMin==0,'actual_grounded_wreck')
 local n=f.navigation
 need(n and n.class==M.MoveClass and n.footprintX==14 and n.footprintZ==14
  and n.nativeMoveRadius==108 and finite(n.idleHorizontalRadius)and n.nativeMoveRadius>=n.idleHorizontalRadius+4,'conservative_idle_navigation')
 need(not d.corpse and not d.wreckname and(not d.featuredefs or not next(d.featuredefs)),'single_salvage_owner')
 need(d.weapondefs.mount4.weapontype=='BeamLaser'and d.weapondefs.mount4.name=='Orange Pulse Cannon'
  and d.weapondefs.mount4.customparams.source_native_adaptation=='authored_orange_native_single_pulse_v1'
  and d.weapondefs.mount1.weapontype=='Cannon','native_pulse_and_belly')
 for _,slot in ipairs({2,5,6,7})do
  local w=d.weapondefs['mount'..slot];local p=w and w.customparams
  need(p and f.fourGunMuzzleFacts[p.source_muzzle]and vector(f.muzzleLocalTranslations[p.source_muzzle]),'four_true_arm_emitters')
 end
 for _,marker in ipairs({'belly_gun_muzzle','lifta_droppa_beam_start','supa_zzappa_muzzle'})do
  need(vector(f.muzzleLocalTranslations[marker]),'native_muzzle_'..marker)
 end
 local p=f.presentation
 need(p and finite(p.pulseThickness)and p.pulseThickness>0 and finite(p.bellyProjectileSize)and p.bellyProjectileSize>0,'local_presentation')
 for _,slot in ipairs({2,5,6,7})do need(finite(p.armProjectileSizes[slot])and p.armProjectileSizes[slot]>0,'arm_projectile_size')end
 for _,path in ipairs({'objects3d/'..f.model,'objects3d/'..f.model..'.lua','scripts/40k_anim/'..f.bank..'.lua',
  'objects3d/'..f.wreckModel,'objects3d/'..f.wreckModel..'.lua','unittextures/ork_dakka_stompa_tex1.png','unittextures/ork_dakka_stompa_tex2.png'})do
  need(V.FileExists(path),'asset_'..path)
 end
 return true
end
-- MoveDefs and UnitDefs are loaded independently by the engine. They deliberately
-- share this same enablement/identity contract, rather than sharing mutable lists.
function M.ApplyMoveDefs(defs,o,V)
 if not M.Enabled(o,V)then return false end
 for _,d in ipairs(defs)do assert(tostring(d.name):lower()~=M.MoveClass:lower(),'Duplicate Dakka reference movement namespace')end
 defs[#defs+1]={name=M.MoveClass,footprintx=14,footprintz=14,maxslope=24,maxwaterdepth=5,crushstrength=1500}
 return true
end
function M.ApplyUnits(defs,o,V,f)
 if not M.Enabled(o,V)then return {applied=false,normalReady=false}end
 local original=defs[M.Actor];M.Preflight(original,f,V)
 local d=copy(original);local cp=d.customparams
 d.objectname=f.model;cp.ork_v14_scale_bank=f.bank;cp.ork_v14_scale_factor=f.factor
 cp.source_native_glb_sha256=f.modelSHA256;cp.ork_v14_scale_wreck=1
 cp.prototype40k_dakka_reference_diagnostic=1;cp.prototype40k_dakka_native_accepted=0
 cp.prototype40k_availability_reason='Unpaid Dakka scale diagnostic; normal production/exit readiness pending'
 d.collisionvolumetype=f.collision.type;d.collisionvolumescales=text(f.collision.scales);d.collisionvolumeoffsets=text(f.collision.offsets)
 d.selectionvolumetype=f.selection.type;d.selectionvolumescales=text(f.selection.scales);d.selectionvolumeoffsets=text(f.selection.offsets)
 d.usepiececollisionvolumes=false;d.usepieceselectionvolumes=false
 d.movementclass=M.MoveClass;d.footprintx=14;d.footprintz=14;d.transportcapacity=0;d.cantbetransported=true
 d.weapondefs.mount1.size=f.presentation.bellyProjectileSize;d.weapondefs.mount4.thickness=f.presentation.pulseThickness
 for _,slot in ipairs({2,5,6,7})do d.weapondefs['mount'..slot].size=f.presentation.armProjectileSizes[slot]end
 -- Keep native role speed, gait playback, bills, damage, range, reload and XP.
 -- Root may calibrate speed only after actual contact-stride evidence exists.
 d.corpse='reference_wreck'
 d.featuredefs={reference_wreck={name='Dakka Stompa machinery wreck',description='Reclaimable Dakka hull',object=f.wreckModel,
  metal=d.metalcost*.25,energy=d.energycost*.25,reclaimtime=d.buildtime*.25,
  blocking=false,reclaimable=true,resurrectable=0,indestructible=true,flammable=false,featuredead='',health=7500,damage=7500,
  footprintx=14,footprintz=14,collisionvolumetype='Box',collisionvolumescales=text(f.wreckBounds.size),collisionvolumeoffsets='0 0 0',
  customparams={parent_actor=M.Actor,prototype40k_remains_domain='vehicle',source_native_glb_sha256=f.wreckSHA256}}}
 VFS.Include('scripts/40k_dakka_gait.lua').ApplyUnits({ork_dakka_stompa=d,corkorg=defs.corkorg})
 VFS.Include('40k_configs/ork_dakka_weapon_feedback.lua').Apply(d,defs.corkorg)
 defs[M.Actor]=d
 return {applied=true,diagnosticOnly=true,normalReady=false,exitAccepted=false,gaitAccepted=false}
end
function M.KilledReturn(S,cp,id)
 assert(cp.animsource==M.Actor and tonumber(cp.ork_v14_scale_factor)==M.Factor and on(cp.ork_v14_scale_wreck)
  and on(cp.prototype40k_dakka_reference_diagnostic),'Wrong exact Dakka wreck owner')
 local _,_,_,_,progress=S.GetUnitHealth(id)
 return finite(progress)and progress>=1 and 1 or 0
end
return M
