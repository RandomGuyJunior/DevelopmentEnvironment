-- Unpaid blast follow-up only: normal native builder reclaim, no resource grants.
function gadget:GetInfo()return{name='40K corpse native reclaim fixture',desc='Bounded same-feature reclaim after genuine throw',author='Local project',layer=121,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local o=Spring.GetModOptions()or{};local on=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
if not on(o.prototype_corpse_native_reclaim_fixture)or not on(o.prototype_corpse_blast_fixture)or not on(o.prototype_source_progression)or o.prototype_diagnostic~='normal'or tonumber(o.prototype_test_speed or 1)~=1 then return false end
local births={};local fid,source,builder,team,cap,work,generation,air,ordered,partial,commandSeen,lastStep,destroyed,done;local previousMetal,previousLeft;local start=Spring.GetGameFrame()
local function log(label,...)Spring.Echo('40K CORPSE NATIVE RECLAIM',Spring.GetGameFrame(),label,...)end
local function finish(ok,reason)if done then return end;done=true;Spring.SetGameRulesParam('40k_corpse_native_reclaim_result',ok and 1 or-1);log(ok and'PASS'or'FAIL',reason,'feature',fid or-1,'builder',builder or-1,'paid',false,'blast_setup',true)end
local function sample(label)
 for _,r in ipairs({'metal','energy'})do
  local level,storage,pull,income,expense,share,sent,received,excess=Spring.GetTeamResources(team,r)
  local used,produced,wasted,got,gave=Spring.GetTeamResourceStats(team,r)
  log('TEAM',label,r,level,storage,pull,income,expense,sent,received,excess,used,produced,wasted,got,gave)
 end
end
local function birth(id,def,t)
 if Spring.GetGameFrame()>1 then return end
 local x,y,z=Spring.GetUnitPosition(id);if not x then return end
 local w,m,e=Spring.GetUnitCosts(id);births[id]={def=def,team=t,x=x,y=y,z=z,work=w,metal=m,energy=e}
end
function gadget:Initialize()
 if GG.Recoil40KSpyderHarvestReview or GG.Recoil40KCorpseAccount then finish(false,'alternate_harvest_owner_active');return end
 if not UnitDefNames.smcom or not UnitDefNames.imp_devastator or not Game.maxUnits then finish(false,'native_definitions_missing');return end
 for _,id in ipairs(Spring.GetAllUnits())do birth(id,Spring.GetUnitDefID(id),Spring.GetUnitTeam(id))end
end
function gadget:UnitCreated(id,def,t)birth(id,def,t)end
function gadget:AllowFeatureBuildStep(id,t,f,def,part)
 if not done and f==fid and part<0 then
  if id~=builder or t~=team or not ordered then finish(false,'foreign_or_unordered_reclaim')else lastStep=Spring.GetGameFrame();log('NATIVE_BUILD_STEP',id,f,part)end
 end
 return true -- observational only: native owner still controls permission/accounting.
end
function gadget:FeatureDestroyed(id)
 if id==fid and not done then
  if not ordered or not lastStep or Spring.GetGameFrame()-lastStep>1 then finish(false,'feature_lost_without_native_work');return end
  destroyed=Spring.GetGameFrame();log('NATIVE_FEATURE_DESTROYED',id,lastStep);sample('destroyed')
 end
end
function gadget:GameFrame(f)
 if done then return end
 if f-start>480 then finish(false,'bounded_timeout');return end
 local matches={}
 for _,id in ipairs(Spring.GetAllFeatures())do
  local fd=FeatureDefs[Spring.GetFeatureDefID(id)];local cp=fd and fd.customParams
  if cp and cp.prototype40k_tactical_remains and cp.parent_actor=='imp_devastator' then
   local slot=Spring.GetFeatureRulesParam(id,'40k_remains_slot');local b=births[slot]
   if b and b.def==UnitDefNames.imp_devastator.id then
    if source and source~=slot then finish(false,'ambiguous_fixture_source');return end
    matches[#matches+1]=id;source=slot
   end
  end
 end
 if #matches>1 then finish(false,'duplicate_native_entitlement');return end
 if destroyed then
  if #matches~=0 then finish(false,'replacement_after_reclaim');return end
  if f-destroyed>=20 then
   sample('settled');if not partial or not commandSeen then finish(false,'partial_or_native_command_proof_missing')else finish(true,'same_feature_native_partial_then_complete')end
  end
  return
 end
 if #matches==0 then if fid then finish(false,'feature_missing_without_destroy_callback')end;return end
 if fid and fid~=matches[1]then finish(false,'feature_identity_changed');return end;fid=matches[1]
 local b=births[source];team=b.team
 local phase=Spring.GetFeatureRulesParam(fid,'40k_remains_flying');local m,dm,e,de,left,time=Spring.GetFeatureResources(fid)
 if not m or m<0 or e~=0 or de~=0 then finish(false,'invalid_native_currency');return end
 if phase==1 then
  if m~=0 or dm~=0 then finish(false,'airborne_currency');return end;air=true;return
 end
 if phase~=0 or not air then return end
 local g=Spring.GetFeatureRulesParam(fid,'40k_remains_generation');if generation and generation~=g then finish(false,'generation_changed');return end;generation=g
 cap=cap or Spring.GetFeatureRulesParam(fid,'40k_remains_metal');work=work or Spring.GetFeatureRulesParam(fid,'40k_remains_work')
 if not cap or cap<=0 or cap>b.metal*.25+.001 or not work or work>b.work*.25+.001 or m>cap+.001 or dm>cap+.001 then finish(false,'actual_cost_cap_or_work_violation');return end
 if not ordered then
  if left~=1 or math.abs(m-cap)>.001 or math.abs(time-work)>.001 then finish(false,'nonpristine_landed_feature');return end
  local candidates={}
  for id,v in pairs(births)do
   if v.def==UnitDefNames.smcom.id and v.team==team and math.abs(v.x-b.x-80)<.02 and math.abs(v.z-b.z)<.02 and Spring.ValidUnitID(id)then candidates[#candidates+1]=id end
  end
  if #candidates~=1 then finish(false,'exact_blast_survivor_missing_or_ambiguous');return end;builder=candidates[1]
  local d=UnitDefs[UnitDefNames.smcom.id];if not d.canReclaim or not d.isBuilder then finish(false,'ordinary_builder_cannot_reclaim');return end
  local x,y,z=Spring.GetFeaturePosition(fid);local ux,uy,uz=Spring.GetUnitPosition(builder)
  log('LANDED',fid,source,generation,cap,work,left,x,y,z,'builder',builder,ux,uy,uz,'reach',d.buildDistance,'reclaimSpeed',d.reclaimSpeed)
  sample('before');ordered=f
  Spring.SetGameRulesParam('40k_corpse_native_reclaim_feature',fid)
  Spring.SetGameRulesParam('40k_corpse_native_reclaim_ordered',f)
  Spring.GiveOrderToUnit(builder,CMD.RECLAIM,{Game.maxUnits+fid},{})
  log('NATIVE_ORDER',builder,CMD.RECLAIM,Game.maxUnits+fid);return
 end
 if previousMetal and (m>previousMetal+.001 or left>previousLeft+.00001)then finish(false,'native_currency_or_fraction_increased');return end;previousMetal=m;previousLeft=left
 local cmd,opts,tag,param=Spring.GetUnitCurrentCommand(builder)
 if cmd==CMD.RECLAIM and param==Game.maxUnits+fid then commandSeen=true end
 if left>0 and left<1 then partial=true;log('PARTIAL',fid,m,dm,e,de,left,time);if f%15==0 then sample('partial')end end
 if left<0 or left>1 then finish(false,'invalid_native_reclaim_fraction')end
end
