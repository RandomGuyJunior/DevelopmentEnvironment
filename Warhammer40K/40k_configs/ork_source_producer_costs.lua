-- Source individual actor purchase adaptation. No payments, refunds or actors created.
local M={}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
local function near(a,b)return finite(a)and finite(b)and math.abs(a-b)<=math.max(.0001,math.abs(b)*1e-7)end
local function enabled(o)return VFS.Include('40k_configs/ork_source_consumers_native.lua').Enabled(o)end
local function identity(d,row)
 local cp=d and(d.customParams or d.customparams)or{}
 return d and cp.animsource==row.asset and(d.modelname==row.asset..'.glb'or d.modelname=='objects3d/'..row.asset..'.glb')and cp.faction=='Orks'and tostring(cp.prototype40k)=='1'and cp.source_entity==row.source_entity and cp.source_model_sha256==row.source_model_sha256 and cp.source_native_glb_sha256==row.generated_glb_sha256
end
local function stamp(row)return tonumber(row.source_entity_sha256:sub(1,6),16)end
function M.ApplyDefinitions(defs,o,plans)
 if not enabled(o)then return{enabled=false}end
 if not plans or plans.version~=1 or not plans.producers then return{enabled=true,applied=false,reason='private_producer_plans_missing'}end
 local pending={}
 -- These old actors were not in the twelve structure + two infantry bundle adapter.
 for _,key in ipairs({'ork_grot','ork_warboss'})do
  local row=plans.producers.ork_settlement and plans.producers.ork_settlement.products[key];local d=defs[key];local cp=d and d.customparams
  if not row or not d or not cp or cp.faction~='Orks'or tostring(cp.prototype40k)~='1'or d.objectname~=row.asset..'.glb'or cp.animsource~=row.asset or(cp.source_entity and cp.source_entity~=row.source_entity)or not VFS.FileExists('objects3d/'..row.asset..'.glb')or not VFS.FileExists('scripts/generated/'..row.asset..'_anim.lua')then return{enabled=true,applied=false,reason='genuine_product_missing',key=key}end
  for _,field in ipairs({'metal','energy','required_native_buildtime'})do if not finite(row[field])or row[field]<0 then return{enabled=true,applied=false,reason='invalid_source_product',key=key}end end
  for _,field in ipairs({'source_entity_sha256','source_model_sha256','generated_glb_sha256'})do if type(row[field])~='string'or not row[field]:match('^[0-9a-f]+$')or #row[field]~=64 then return{enabled=true,applied=false,reason='invalid_product_hash',key=key}end end
  if row.metal<1 or row.required_native_buildtime<1 then return{enabled=true,applied=false,reason='native_setter_minimum',key=key}end
  pending[key]={row=row,def=d}
 end
 for _,p in pairs(pending)do local d,r=p.def,p.row;d.metalcost=r.metal;d.energycost=r.energy;d.buildtime=r.required_native_buildtime;d.customparams.source_entity=r.source_entity;d.customparams.source_model_sha256=r.source_model_sha256;d.customparams.source_native_glb_sha256=r.generated_glb_sha256;d.customparams.source_paid_entity_sha256=r.source_entity_sha256;d.customparams.source_paid_animator_sha256=r.source_animator_model_sha256;d.customparams.source_genuine_appearance_adaptation=r.genuine_native_appearance_adaptation and 1 or 0 end
 return{enabled=true,applied=true}
end
function M.New(S,defs,o,plans)
 local R={receipts={},failures={}};R.enabled=enabled(o)
 if not R.enabled then function R.Allow()return true end;function R.Birth()return true end;function R.Transferred()end;function R.Destroyed()end;function R.RestoreExisting()return true end;return R end
 assert(plans and plans.version==1 and type(plans.producers)=='table','Missing private genuine producer plans')
 local required={ork_settlement={ork_grot=true,ork_warboss=true,ork_slugga=true},ork_boyz_hut={ork_slugga=true,ork_stormboy=true}}
 for key,products in pairs(required)do local p=plans.producers[key];assert(p and type(p.products)=='table','Incomplete genuine producer plan');for name in pairs(products)do assert(p.products[name],'Incomplete genuine product plan')end end
 local tracked={}
 for key,p in pairs(plans.producers)do
  assert(required[key]and p.actual_native_producer_workrate==(key=='ork_settlement'and 30 or 150),'Unreviewed immutable producer plan')
  for name,row in pairs(p.products)do
   assert(required[key][name]and finite(row.source_seconds)and row.source_seconds>0,'Unreviewed source product')
   for _,field in ipairs({'source_entity_sha256','source_model_sha256','generated_glb_sha256'})do assert(type(row[field])=='string'and #row[field]==64 and row[field]:match('^[0-9a-f]+$'),'Invalid genuine product hash')end
   tracked[name]=true
  end
 end
 local prefix='40k_ork_birth_cost_';local opts={private=true}
 local function put(id,k,v)S.SetUnitRulesParam(id,prefix..k,v,opts)end
 local function get(id,k)return S.GetUnitRulesParam(id,prefix..k)end
 local function selectPlan(def,team,builder)
  local d=defs[def];if not d or not tracked[d.name]then return true end
  if not builder or S.GetUnitTeam(builder)~=team then return nil,'producer_owner_mismatch'end
  local producerHP,_,_,_,producerProgress=S.GetUnitHealth(builder);if not producerHP or producerHP<=0 or producerProgress~=1 then return nil,'producer_not_finished_alive'end
  local pd=defs[S.GetUnitDefID(builder)];local p=pd and plans.producers[pd.name];local row=p and p.products[d.name]
  if not row or pd.isFactory~=true or not identity(pd,p)or not identity(d,row)then return nil,'genuine_producer_product_mismatch'end
  if not near(pd.buildSpeed,p.actual_native_producer_workrate)or not near(row.actual_native_producer_workrate,p.actual_native_producer_workrate)or not near(row.required_native_buildtime,row.source_seconds*p.actual_native_producer_workrate)then return nil,'immutable_producer_rate_mismatch'end
  if not finite(row.metal)or row.metal<1 or not finite(row.energy)or row.energy<0 or not finite(row.required_native_buildtime)or row.required_native_buildtime<1 then return nil,'invalid_native_source_cost'end
  -- The setter clamps supplied zero to one. Zero must originate in UnitDef.
  if row.energy==0 and d.energyCost~=0 then return nil,'zero_energy_definition_required'end
  return row,nil,S.GetUnitDefID(builder)
 end
 function R.Allow(def,team,builder)local row,why=selectPlan(def,team,builder);return row~=nil,why end
 function R.Birth(id,def,team,builder)
  local row,why,pdef=selectPlan(def,team,builder);if not row then R.failures[id]=why;return false,why end;if row==true then return true end
  if S.GetUnitDefID(id)~=def or S.GetUnitTeam(id)~=team then return false,'actual_birth_identity_mismatch'end
  if R.receipts[id]or get(id,'version')then
   local r=R.receipts[id];if(r and r.team==team and r.def==def and r.builder==builder and not r.transferred)or(not r and get(id,'version')==1 and get(id,'team')==team and get(id,'def')==def and get(id,'builder')==builder and get(id,'stamp')==stamp(row)and get(id,'transferred')~=1)then return true,'duplicate_birth'end
   return false,'historical_birth_mismatch'
  end
  local hp,_,_,_,progress=S.GetUnitHealth(id)
  if not hp or hp<=0 or progress~=0 then return false,'construction_already_started'end
  local bt,m,e=S.GetUnitCosts(id);if not finite(bt)or not finite(m)or not finite(e)then return false,'native_cost_unavailable'end
  if row.energy==0 and e~=0 then return false,'zero_energy_native_birth_required'end
  local desired={buildTime=row.required_native_buildtime,metalCost=row.metal,energyCost=row.energy};local old={buildTime=bt,metalCost=m,energyCost=e};local changes,rollback={},{}
  for field,value in pairs(desired)do if not near(value,old[field])then if value<1 or old[field]<1 then return false,'native_atomic_setter_minimum'end;changes[field]=value;rollback[field]=old[field]end end
  if next(changes)then
   local ok=pcall(S.SetUnitCosts,id,changes);local b2,m2,e2=S.GetUnitCosts(id)
   if not ok or not near(b2,desired.buildTime)or not near(m2,desired.metalCost)or not near(e2,desired.energyCost)then
    local restored=pcall(S.SetUnitCosts,id,rollback);local rb,rm,re=S.GetUnitCosts(id)
    if not restored or not near(rb,bt)or not near(rm,m)or not near(re,e)then return false,'native_cost_rollback_failed'end
    return false,'native_cost_write_refused_rolled_back'
   end
  end
  local r={def=def,team=team,builder=builder,producerDef=pdef,work=desired.buildTime,metal=desired.metalCost,energy=desired.energyCost,frame=S.GetGameFrame()}
  local receipt={version=1,def=def,team=team,builder=builder,producerDef=pdef,stamp=stamp(row),work=r.work,metal=r.metal,energy=r.energy,frame=r.frame,transferred=0};local previous={}
  for k in pairs(receipt)do previous[k]=get(id,k)end
  local published=pcall(function()for k,v in pairs(receipt)do put(id,k,v)end end)
  if not published then
   local cleared=pcall(function()for k in pairs(receipt)do put(id,k,previous[k])end end)
   local undone=true;if next(rollback)then undone=pcall(S.SetUnitCosts,id,rollback)end
   local rb,rm,re=S.GetUnitCosts(id)
   if not cleared or not undone or not near(rb,bt)or not near(rm,m)or not near(re,e)then return false,'native_receipt_rollback_failed'end
   return false,'native_receipt_refused_rolled_back'
  end
  R.receipts[id]=r
  return true,'source_producer_cost_applied'
 end
 function R.Transferred(id)local r=R.receipts[id];if r then r.transferred=true end;if r or get(id,'version')then put(id,'transferred',1)end end
 function R.Destroyed(id)R.receipts[id]=nil;R.failures[id]=nil end
 function R.RestoreExisting(id,def,team)
  if not get(id,'version')then return true end
  local d=defs[def];if not d or not tracked[d.name]or get(id,'version')~=1 or get(id,'def')~=def then return false,'saved_birth_identity_invalid'end
  local p=defs[get(id,'producerDef')];local source=p and plans.producers[p.name];local row=source and source.products[d.name]
  if not row or not identity(d,row)or not identity(p,source)or get(id,'stamp')~=stamp(row)or not near(get(id,'work'),row.required_native_buildtime)or not near(get(id,'metal'),row.metal)or not near(get(id,'energy'),row.energy)then return false,'saved_birth_source_invalid'end
  local bt,_,e=S.GetUnitCosts(id);if not near(bt,row.required_native_buildtime)or not near(e,row.energy)then return false,'saved_native_cost_invalid'end
  R.receipts[id]={def=def,team=get(id,'team'),builder=get(id,'builder'),producerDef=get(id,'producerDef'),work=get(id,'work'),metal=get(id,'metal'),energy=get(id,'energy'),frame=get(id,'frame'),transferred=get(id,'transferred')==1 or team~=get(id,'team')};return true
 end
 return R
end
return M
