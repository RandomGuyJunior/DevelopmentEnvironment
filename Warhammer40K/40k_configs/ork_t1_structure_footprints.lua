-- Final placement correction for exactly two verified unchanged T1 buildings.
-- Existing tiny placement facts; no geometry/bank import or availability gate.
local M={Policy='ork_t1_model_minimum_tiles_v1'}
M.ProfileTableSHA256='863ebea4048c41b0cc2403c903214d2d0f6161b8cf602e6883cb26c8613aa69c'
M.Rows={
 ork_waaagh_banner={object='ork_waaagh_banner.glb',actor='ork_waaagh_banner',yard='o',x=4,z=4,
  model='ed28fdb18320f871ced08bf402fad84c5a238b6cdb38ff8f3e89b267f8ff478d',
  bank='a72a2c42d7ebc95a21928598e65778946f79c4bdb16c6bc71428b1713e10517a'},
 ork_boyz_hut={object='ork_boyz_hut.glb',actor='ork_boyz_hut',yard='e',x=7,z=7,
  model='6c269f5d71931cff585f6b4c7c36e47edf583846cc88d728e59b51362cd1be87',
  bank='24c5e1b6083f2c5e0e3d35ee30e66d408530a431bc204891d1e7e4927fce4160'},
}
-- These byte pins are checked offline against the actual frozen candidate by
-- the scoped packet check, then covered by the ordinary immutable bounds/cache
-- and checksum pipeline. Runtime checks final model/pose/yard bindings only.
function M.Apply(defs,V)
 local bounds=V.Include('40k_configs/building_placement_bounds.lua')
 local report={changed={},unchanged={},pending={}};local ready={}
 for _,key in ipairs({'ork_waaagh_banner','ork_boyz_hut'})do
  local d=defs[key];local p=M.Rows[key];local cp=d and(d.customparams or{})or{}
  local b=bounds[p.actor];local reason
  local identity=cp.source_native_glb_sha256 or cp.source_composite_model_sha256 or cp.building_placement_model
  if not d then reason='definition_absent'
  elseif d.objectname~=p.object or d.script~='40k_roster.lua'or cp.animsource~=p.actor
   or cp.source_completed_pose_profile~=nil or identity~=p.model then reason='final_model_or_pose_binding_changed'
  elseif (tonumber(d.speed or d.maxvelocity)or 0)~=0 or d.movementclass or d.canfly
   or(tonumber(d.minwaterdepth or d.minWaterDepth)or 0)>0 then reason='not_this_ground_structure'
  elseif not b or b.model~=p.model or math.ceil(b.halfX/8)~=p.x or math.ceil(b.halfZ/8)~=p.z then reason='measured_minimum_certificate_changed'
  elseif not V.FileExists('objects3d/'..p.object)or not V.FileExists('scripts/generated/'..p.actor..'_anim.lua')then reason='model_or_bank_closure_missing'
  end
  local old=d and(d.yardmap or''):gsub('%s','')or''
  if not reason and(old==''or old:find('[^'..p.yard..']')or #old~=(tonumber(d.footprintx)or 1)*(tonumber(d.footprintz)or 1))then reason='functional_yard_changed'end
  if reason then report.pending[key]=reason
  elseif d.footprintx==p.x and d.footprintz==p.z then report.unchanged[#report.unchanged+1]=key
  else ready[#ready+1]={key=key,d=d,p=p}end
 end
 for _,row in ipairs(ready)do
  local d,p=row.d,row.p
  d.footprintx,d.footprintz=p.x,p.z;d.yardmap=string.rep(p.yard,p.x*p.z)
  d.customparams.building_placement_policy=M.Policy;d.customparams.building_placement_model=p.model
  report.changed[#report.changed+1]=row.key
 end
 return report
end
return M
