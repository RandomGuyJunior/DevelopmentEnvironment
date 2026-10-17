function gadget:GetInfo()return {name='40K opt-in paid factory pose provenance',desc='Read-only genuine factory/product birth tracking',author='Local project',layer=108,enabled=true}end
local opts=Spring.GetModOptions()
if not gadgetHandler:IsSyncedCode() or opts.prototype_diagnostic~='expandedproduction' or tostring(opts.prototype_factory_pose_review)~='1' then return end
local wanted={imp_marine_hq=true,imp_marine_barracks=true,imp_barracks=true,imp_tank_factory=true,imp_walker_factory=true}
-- Guardsman completes in ~1s; review ordinary paid Marine long enough for
-- two idle loops. Existing paid queue already contains all three chosen products.
local chosen={imp_marine_hq='imp_scout',imp_marine_barracks='imp_marine',imp_barracks='imp_marine',imp_tank_factory='imp_russ',imp_walker_factory='imp_sentinel'}
local births,factories,firstProducts={},{},{}
local function sourceName(ud)
 if wanted[ud.name] then return ud.name end
 local cp=ud.customParams or {}
 local source=cp.animsource or cp.prototype40k_donor
 -- Native BAR role aliases inherit genuine donor source customparams.
 if ud.isFactory and cp.prototype40k and wanted[source] then return source end
end
local function log(...)Spring.Echo('40K FACTORY POSE',...)end
function gadget:UnitCreated(id,def,team,builder)
 if team~=0 then return end
 local ud=UnitDefs[def];if not ud then return end
 local parent=builder and Spring.GetUnitDefID(builder)
 births[id]={builder=builder,parent=parent}
 if factories[builder] and ud.name==chosen[factories[builder]] and (not firstProducts[builder]or factories[builder]=='imp_marine_hq'or factories[builder]=='imp_marine_barracks')then
  firstProducts[builder]=id
  Spring.SetUnitRulesParam(builder,'40k_factory_pose_product',id,{public=true})
  log('NATIVE_PRODUCT_CREATED',ud.name,id,factories[builder],builder,Spring.GetGameFrame(),ud.metalCost or ud.metalcost or -1,ud.energyCost or ud.energycost or -1,UnitDefs[Spring.GetUnitDefID(builder)].name)
 end
end
function gadget:UnitFinished(id,def,team)
 if team~=0 then return end
 local ud=UnitDefs[def];local birth=births[id];if not ud then return end
 local source=sourceName(ud)
 if source then
  if not birth or not birth.builder or not birth.parent then log('UNKNOWN','factory_missing_native_builder_provenance',ud.name,id);return end
  factories[id]=source
  Spring.SetUnitRulesParam(id,'40k_factory_pose_tracked',1,{public=true})
  log('NATIVE_FACTORY_FINISHED',source,id,birth.builder,birth.parent,Spring.GetGameFrame(),ud.name)
 elseif birth and firstProducts[birth.builder]==id then
  Spring.SetUnitRulesParam(birth.builder,'40k_factory_pose_finished_product',id,{public=true})
  Spring.SetUnitRulesParam(birth.builder,'40k_factory_pose_finished_frame',Spring.GetGameFrame(),{public=true})
  log('NATIVE_PRODUCT_FINISHED',ud.name,id,factories[birth.builder],birth.builder,Spring.GetGameFrame())
 end
end
-- No creation, orders, economic grants, script callbacks or model pose writes.
-- Existing expandedproduction suite owns actual paid construction and acceptance.
