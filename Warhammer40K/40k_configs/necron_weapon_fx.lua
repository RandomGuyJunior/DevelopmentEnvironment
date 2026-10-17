-- Source-audited render patch; never changes damage, movement, fire cadence or collision.
local M={}
M.TextureFiles={arc='40k/necron/arc.png',beam='40k/necron/beam.png',ring='40k/necron/ring.png',fractal='40k/necron/fractal.png',sparks='40k/necron/sparks.png'}
function M.TextureAliases(resources,vfs)
 local result={};resources.graphics=resources.graphics or {};resources.graphics.projectiletextures=resources.graphics.projectiletextures or {}
 for name,file in pairs(M.TextureFiles)do if vfs.FileExists('bitmaps/'..file)then local alias='40k_necron_source_'..name;resources.graphics.projectiletextures[alias]=file;result[name]=alias end end
 return result
end
function M.SourceTexturesReady(vfs)
 for _,file in pairs(M.TextureFiles)do if not vfs or not vfs.FileExists('bitmaps/'..file)then return false end end
 return true
end
-- Exact WHE fx_scale is provenance, not a claim that DoW pixels/elmos match.
M.Profiles={
 gauss_flayer={scale=1,source_scale=1,muzzle='necron/weapon/fire_muzzle_end_burst',beam='necron/weapon/fire_muzzle_beam_combo',source_reload=1},
 gauss_blaster={scale=.5,source_scale=.5,muzzle='necron/weapon/fire_muzzle_end_burst',beam='necron/weapon/fire_muzzle_beam_combo',source_reload=1},
 gauss_cannon={scale=2,source_scale=2,muzzle='necron/weapon/fire_muzzle_end_burst',beam='necron/weapon/fire_muzzle_beam_combo',source_reload=.5},
 gauss_heavy={scale=3,source_scale=3,muzzle='necron/weapon/fire_muzzle_end_burst',beam='necron/weapon/fire_muzzle_beam_combo',source_reload=3},
 staff_light={scale=1,muzzle='necron/weapon/fire_muzzle_end_burst_02',beam='necron/weapon/fire_muzzle_beam_combo',source_reload=1},
 particle_projector={scale=3,source_scale=3,muzzle='necron/weapon/fire_muzzle_end_burst',beam='necron/weapon/fire_muzzle_beam_combo',source_reload=1},
 particle_whip={scale=5,muzzle='necron/monolith/fire_crystal_main',impact='necron/monolith/hit_crystal_main_combo',source_reload=3},
 flux_arc={scale=1.5,muzzle='necron/monolith/gun_corner_beam_combo',source_reload=1},
 turret_gauss={scale=1,muzzle='necron/weapon/fire_muzzle_end_burst',source_reload=3,adaptation='Static WHE has no firing event. Local CEG uses real native mount emitters and Gauss source visual equivalence; no fake source action.'},
 night_scythe={scale=1,muzzle='necron/weapon/fire_muzzle_end_burst_02',source_reload=1,adaptation='Night WHE fire marker is absent from exported model; retain verified native right-hand mount instead of inventing the obsolete marker.'},
 blade={scale=1,impact='necron/weapon/melee_blade_hit',contact_only=true},
 night_blade={scale=4,source_scale=4,impact='necron/weapon/melee_blade_hit',contact_only=true},
}
M.Bindings={nec_lord={'staff_light','blade'},nec_warrior={'gauss_flayer'},nec_immortal={'gauss_blaster','gauss_blaster'},
 nec_destroyer={'gauss_cannon','gauss_cannon'},nec_heavy_destroyer={'gauss_heavy'},nec_spyder={'particle_projector','blade'},
 nec_turret={'turret_gauss','turret_gauss','turret_gauss','turret_gauss','turret_gauss','turret_gauss','turret_gauss','turret_gauss'},
 nec_monolith_mobile={'particle_whip','flux_arc','flux_arc','flux_arc','flux_arc'},nec_nightbringer={'night_scythe','night_blade'}}
local function allowed(ready,key)return type(ready)=='function' and ready(key)==true or type(ready)=='table' and ready[key]==true end
function M.Apply(defs,ready)
 local changed={};local keys={};for key in pairs(M.Bindings)do keys[#keys+1]=key end;table.sort(keys)
 for _,key in ipairs(keys)do
  local d=defs[key]
  if d and allowed(ready,key)then
   local valid=true
   for i in ipairs(M.Bindings[key])do local mount=d.weapons and d.weapons[i];local w=mount and d.weapondefs and d.weapondefs[mount.def];if not w or not w.customparams or not w.customparams.source_muzzle then valid=false end end
   if valid then
    d.sfxtypes=d.sfxtypes or {};d.sfxtypes.explosiongenerators=d.sfxtypes.explosiongenerators or {};local sfx=d.sfxtypes.explosiongenerators
    for i,family in ipairs(M.Bindings[key])do
     local p=M.Profiles[family];local w=d.weapondefs[d.weapons[i].def];local cp=w.customparams
     w.explosiongenerator='custom:40k_necron_'..family..'_impact';cp.source_fx_family='necron_'..family
     cp.source_fx_provenance=p.muzzle or p.impact;cp.source_fx_visual_translation=1
     if not p.contact_only then
      local name='custom:40k_necron_'..family..'_muzzle';local found
      for n,v in ipairs(sfx)do if v==name then found=n end end
      if not found then sfx[#sfx+1]=name;found=#sfx end;cp.source_muzzlefx=1023+found
      w.rgbcolor='.584 .875 .455';w.rgbcolor2='.91 1 .90'
     else cp.source_muzzlefx=nil end
    end
    changed[#changed+1]=key
   end
  end
 end
 return changed
end
return M
