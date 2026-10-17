-- Opt-in reviewed native physics/cadence patch; never issues acceptance markers.
local M={}
M.Profiles={
 imp_baneblade={
  {mount=3,clip='las_right',marker='marker_lascannon_r',reload=2,cycle=3.033333,source='guard_lascannon_baneblade',kind='LaserCannon'},
  {mount=4,clip='las_left',marker='marker_lascannon_l',reload=2,cycle=3.033333,source='guard_lascannon_baneblade',kind='LaserCannon'},
 },
 imp_warhound={{mount=1,clip='fire',marker='marker_lplasma_barrel1',reload=5,cycle=7.233333,source='npc_titan_plasma_blastgun_left',kind='Cannon'}},
}
local function positive(n)return type(n)=='number' and n==n and n>0 and n<math.huge end
local function allowed(ready,key)return type(ready)=='function' and ready(key)==true or type(ready)=='table' and ready[key]==true end
-- review[actor]={approved=true,sourceProof=true,clips={label=exportedDuration},
--               beam=true,engine='recoil_2026.07.04',beamttl=reviewedVisualFrames}
-- The coordinator supplies explicit current reviewed data; absent review is inert.
function M.Apply(defs,ready,review)
 local report={changed={},blocked={}}
 local names={};for name in pairs(defs)do names[#names+1]=name end;table.sort(names)
 for _,name in ipairs(names)do
  local d=defs[name];local donor=(d.customparams or{}).prototype40k_donor or name
  local profiles=M.Profiles[donor];local r=type(review)=='table' and review[donor]
  if profiles and allowed(ready,donor) and type(r)=='table' and r.approved==true and r.sourceProof==true then
   local patches={};local reason
   for _,p in ipairs(profiles)do
    local mount=d.weapons and d.weapons[p.mount];local key=mount and mount.def and mount.def:lower()
    local w=key and d.weapondefs and d.weapondefs[key];local cp=w and w.customparams
    local cycle=r.clips and r.clips[p.clip]
    if not w or not cp or cp.source_fireclip~=p.clip or cp.source_muzzle~=p.marker
      or not positive(w.reloadtime) or not positive(cycle) or cycle+.000001<p.cycle
      or (w.weapontype~=p.kind and w.weapontype~='BeamLaser')then reason='mount_or_clip_mismatch';break end
    -- Probability1 in source is metadata, never an instruction to remove spread.
    if not ((tonumber(w.accuracy)or 0)>0 or (tonumber(w.sprayangle)or 0)>0)then reason='perfect_accuracy_refused';break end
    if r.beam~=true or r.engine~='recoil_2026.07.04' or not positive(r.beamttl) or r.beamttl~=math.floor(r.beamttl) or r.beamttl>math.ceil(cycle*30) then reason='beam_review_required';break end
    patches[#patches+1]={w=w,p=p,cycle=cycle,reload=math.max(w.reloadtime,p.reload,cycle)}
   end
   if reason then report.blocked[#report.blocked+1]=name..':'..reason
   else
    for _,patch in ipairs(patches)do
     local w,p=patch.w,patch.p
     -- Native discrete pulse keeps original burst count/delay and per-shot damage.
     -- Non-beamburst would create beamtime*FPS salvos and divide damage between them.
     w.weapontype='BeamLaser';w.beamburst=true;w.sweepfire=false;w.minintensity=1;w.beamtime=1/30;w.beamttl=r.beamttl
     w.reloadtime=patch.reload
     w.collidefriendly=true;w.collideenemy=true;w.collideground=true;w.collidefeature=true;w.collideneutral=true;w.collidenontarget=true
     w.avoidfriendly=true;w.avoidfeature=true;w.avoidground=true;w.waterweapon=false
     local cp=w.customparams
     cp.source_ballistics_profile=p.source;cp.source_ballistics_reload=p.reload;cp.source_ballistics_accuracy=1
     cp.source_ballistics_clipcycle=patch.cycle;cp.source_ballistics_native_pending=1
     cp.source_ballistics_discrete_pulse=1
    end
    report.changed[#report.changed+1]=name
   end
  end
 end
 return report
end
return M
