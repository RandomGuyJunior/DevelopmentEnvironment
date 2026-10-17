-- Only genuine explicit source review, not normal or mixed benchmark exposure.
local M={}
function M.Enabled(o)return VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression)and(o.prototype_diagnostic=='roster'or o.prototype_diagnostic=='expandedproduction')end
function M.ApplyRaw(defs,o)
 if not M.Enabled(o)then return false end
 local old=defs.ork_settlement;local cp=old and old.customparams or{}
 if not old or old.script~='40k_roster.lua'or cp.faction~='Orks'or cp.animsource~='ork_settlement'or old.objectname~='ork_settlement.glb'then return false end
 local H=VFS.Include('40k_configs/ork_hq_allmesh_review.lua');local F=VFS.Include('40k_configs/ork_hq_allmesh_review_facts.lua')
 for _,file in ipairs({'objects3d/'..H.Asset..'.glb','scripts/generated/'..H.Asset..'_anim.lua','scripts/generated/'..H.Asset..'_native.lua','scripts/40k_ork_hq_native_runtime.lua','scripts/40k_roster.lua','unitpics/40k_ork_settlement.png'})do if not VFS.FileExists(file)then return false end end
 local native=VFS.Include('scripts/40k_ork_hq_native_runtime.lua')
 local d=H.Build(F,{FactoryReady=function(key)
  -- Pinned IsFactoryUnit=builder && immobile-with-yardmap. Build sets speed0,
  -- canmovefalse, workertime30, builddistance180 and the full even-grid yard.
  return key==H.Key and F.source_unit.seconds>0 and F.footprint_even[1]>=2 and F.footprint_even[2]>=2
 end,MountGateReady=function(key)return key==H.Key and type(native.New)=='function'end})
 if not d then return false end
 d.customparams.prototype40k_source_progression=1;d.customparams.source_ork_hq_native=1;d.customparams.prototype40k_tech_requires='ork_settlement'
 d.customparams.source_construction_progress_adaptation='genuine source phases: plane drop source-FPS; rise normalized actual native build progress .2..1; proprietary modifier timing unverified'
 d.customparams.source_buildpiece='ork_settlement';d.customparams.source_factory_spawn_adaptation='genuine root piece; source spawner position unavailable; native egress unaccepted'
 d.customparams.source_resource_income_pending=1
 d.customparams.source_products_pending=1
 if o.prototype_diagnostic=='roster'then d.customparams.diagnostic='roster'end
 -- Preserve only actual source menu products that already passed source graph
 -- readiness; do not invent missing SBP producers or bypass paid prerequisites.
 local allowed={ork_grot=true,ork_slugga=true,ork_warboss=true}
 for _,name in ipairs(old.buildoptions or{})do if allowed[name]and defs[name]then d.buildoptions[#d.buildoptions+1]=name end end
 defs.ork_settlement=d;return true
end
function M.FinalizeMounts(defs,o)
 if not M.Enabled(o)then return false end
 local d=defs.ork_settlement;local cp=d and d.customparams or{}
 if tostring(cp.source_ork_hq_native)~='1'or cp.animsource~='ork_hq_allmesh_review'then return false end
 -- Historical family table contains two Big Shootas; this genuine candidate
 -- instead has four inspected ork_shoota_turret profiles. No ballistic edits.
 for i=1,4 do local w=assert(d.weapondefs['mount'..i]);assert(w.customparams.source_weapon_profile=='attrib/weapon/ork_shoota_turret.lua')
  w.customparams.source_fx_family='shoota';w.customparams.source_muzzlefx='40k_dow_shoota_muzzle';w.explosiongenerator='custom:40k_dow_shoota_impact'
 end
 return true
end
return M
