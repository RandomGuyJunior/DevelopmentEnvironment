-- Apply after the final Ork content overlays; the early global pass precedes
-- composite factories and economy. Reuse the ordinary single-speaker policy.
local M={Version=1}
local guns={
 ork_wartrak={
  marker_twin_linked_big_shootas_barrel01='big_shoota',
  marker_twin_linked_big_shootas_barrel02='big_shoota',
 },
 ork_mek_shop={marker_mek_shop_shoota_barrel01='shoota'},
 -- Exact real Gunship nose marker; no pipe/crane sound emitters.
 ork_gunship={nose_muzzle='artillery'},
 -- Exact GOH gun origins; independent callbacks and paired emitters stay native.
 ork_morkanaut={
  mork084_fxlightmegablasta3='kmb',mork112_fxlightmegablasta1='kmb',
  mork_rocket_muzzle_1='rokkit',mork050_finger1_l='power_claw',
 },
 ork_warbike_crewed={bike023_barrel_l00='big_shoota',bike030_barrel_r00='big_shoota'},
}
function M.Apply(defs)
 local scoped={}
 for key,d in pairs(defs)do
  local cp=d.customparams or{}
  if tostring(cp.prototype40k)=='1'and cp.faction=='Orks'then scoped[key]=d end
 end
 local policy=VFS.Include('40k_configs/audio_profiles.lua')
 policy.Apply(scoped)
 if not VFS.FileExists('40k_configs/generated_audio.lua')then return end
 local clips=VFS.Include('40k_configs/generated_audio.lua')
 for key,d in pairs(scoped)do
  local cp=d.customparams or{}
  local source=cp.prototype40k_donor or cp.animsource or key
  local mounts=guns[source]
  for _,w in pairs(d.weapondefs or{})do
   local family=mounts and mounts[(w.customparams or{}).source_muzzle]
   local entry=family and(clips['weapon_'..family]or{})[1]
   if entry and type(entry.file)=='string'and entry.file:match('^sounds/40k/')and VFS.FileExists(entry.file)then
    -- The existing SoundItem owns concurrency/distance limits. No weapon
    -- family/FX/spread/cadence/collision changes are required for sound alone.
    w.soundstart='40k_'..family;w.soundstartvolume=1
   end
   if source=='ork_warbike_crewed'and family=='big_shoota'and VFS.FileExists('sounds/weapons/bimpact1.wav')then
    -- Stock registered small projectile impact, kept below the paired firing cue.
    w.soundhit='bimpact1';w.soundhitvolume=.35
   end
   if source=='ork_gunship'and family=='artillery'then
    local impact=(clips.weapon_explosion or{})[1]
    if impact and type(impact.file)=='string'and impact.file:match('^sounds/40k/')and VFS.FileExists(impact.file)then
     w.soundhit='40k_explosion';w.soundhitvolume=.7
    end
   end
  end
 end
end
return M
