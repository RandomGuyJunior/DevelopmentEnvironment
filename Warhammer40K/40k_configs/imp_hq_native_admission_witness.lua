-- Marker-only opt-in: no definition mechanics, models, menus or costs changed.
local M={}
function M.Apply(defs,opts)
 if not opts or tostring(opts.prototype_hq_admission_witness)~='1'then return defs end
 assert(opts.prototype_diagnostic=='expandedproduction'and VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(opts.prototype_source_progression)and (tostring(opts.prototype_source_paid_match)=='1'or opts.prototype_source_acceptance=='imperium'),'HQ native witness requires explicit paid source review or paid Imperial source acceptance')
 local d=assert(defs.imp_hq,'Actual imp_hq definition missing');local cp=assert(d.customparams,'Actual imp_hq customParams missing')
 assert(tostring(cp.prototype40k)=='1'and cp.faction=='Imperium','Only genuine Imperial HQ may be marked')
 assert(cp.animsource=='imp_hq'and d.objectname=='imp_hq.glb'and d.script=='40k_roster.lua','Only exact rendered genuine HQ model/script may be marked')
 assert(VFS and VFS.FileExists and VFS.FileExists('objects3d/imp_hq.glb')and VFS.FileExists('scripts/generated/imp_hq_anim.lua'),'Actual rendered HQ assets unavailable')
 assert(cp.prototype40k_hq_admission_witness==nil or tostring(cp.prototype40k_hq_admission_witness)=='1','Conflicting witness marker')
 cp.prototype40k_hq_admission_witness=1
 return defs
end
return M
