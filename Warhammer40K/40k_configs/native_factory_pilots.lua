-- Narrow native production-contract overlay; capture before donor substitutions.
-- Colour-only private Guard/Marine pilots. Native geometry is intentionally unchanged
-- until the project scale has a measured production/egress acceptance result.
local M={}
M.Pilots={
 imp_barracks={donor='wh40k_armlab',domain='infantry',object='40k_native_guard_armlab.s3o',theme='guard_olive_material_pilot'},
 imp_tank_factory={donor='wh40k_armvp',domain='vehicle',object='40k_native_guard_armvp.s3o',theme='guard_olive_material_pilot'},
 imp_marine_barracks={donor='wh40k_armlab',domain='infantry',object='40k_native_marine_armlab.s3o'},
 imp_walker_factory={donor='wh40k_armvp',domain='vehicle',object='40k_native_marine_armvp.s3o'},
 nec_vehicle_factory={donor='wh40k_armvp',domain='vehicle',object='40k_native_necron_armvp.s3o',theme='necron_matte_graphite_green_pilot',option='prototype_necron_native_factory_pilot',requireUnarmed=true},
}
M.Fields={
 'script','footprintx','footprintz','yardmap','buildangle','builder','canmove',
 'speed','maxacc','maxdec','maxslope','maxwaterdepth','waterline','floater',
 'collisionvolumetype','collisionvolumescales','collisionvolumeoffsets',
 'usepiececollisionvolumes','terraformspeed','canreclaim','corpse','featuredefs',
}
-- Non-ground donor interface: domains are deliberately matched to donor roles.
M.DomainDonors={infantry={t1='wh40k_armlab',t2='wh40k_armalab'},vehicle={t1='wh40k_armvp',t2='wh40k_armavp'},
 air={t1='armap',t2='armaap'},naval={t1='armsy',t2='armasy'}}
function M.Capture(defs,copy)
 local captured={}
 for _,rule in pairs(M.Pilots)do
  assert(defs[rule.donor],'Missing native factory donor '..rule.donor)
  captured[rule.donor]=copy(defs[rule.donor])
 end
 return captured
end
function M.Apply(defs,captured,exists,options)
 options=options or{}
 local applied={}
 for key,rule in pairs(M.Pilots)do
  if not rule.option or options[rule.option]==true or options[rule.option]==1 or options[rule.option]=='1'then
  local target=assert(defs[key],'Pilot target absent '..key)
  if rule.requireUnarmed then assert(target.canattack==false and #(target.weapons or{})==0,'Native Necron pilot requires genuinely unarmed target')end
  local donor=assert(captured[rule.donor],'Native contract not captured '..rule.donor)
  assert(donor.script and donor.yardmap and donor.builder and donor.canmove,'Not a native factory contract')
  assert(exists('objects3d/'..rule.object),'Private pilot geometry absent '..rule.object)
  assert(exists('scripts/'..donor.script),'Native factory script absent '..donor.script)
  -- Keep queue/product list, economics, HP, names, icons, faction/research
  -- identity and source exposure. No broad donor copy after progression.
  for _,field in ipairs(M.Fields)do target[field]=donor[field]end
  target.objectname=rule.object
  local cp=target.customparams or{};target.customparams=cp
  -- Remove LUS-only source metadata; leaving it can enlist genuine actor
  -- controller/gadgets against a native COB with unrelated piece names.
  for name in pairs(cp)do
   if name=='animsource'or name=='buildclip'or name:match('^source_')then cp[name]=nil end
  end
  cp.normaltex=donor.customparams and donor.customparams.normaltex
  cp.usebuildinggrounddecal=false
  cp.model_author=donor.customparams and donor.customparams.model_author
  cp.prototype40k_native_factory_donor=rule.donor
  cp.prototype40k_native_factory_pilot=1
  cp.prototype40k_native_factory_domain=rule.domain
  cp.prototype40k_native_factory_theme=rule.theme or'marine_muted_red_material_pilot'
  cp.prototype40k_native_factory_scale=1
  applied[#applied+1]=key
  end
 end
 table.sort(applied);return applied
end
return M
