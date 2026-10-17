-- Pinned native15-frame stable-unit cadence; gross builder credit, not net income.
local M={period=15}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.New(S,D,builder,team,emit,contract)
 local L={phase='baseline',sum=0,zeros=0,started=S.GetGameFrame(),lastFrame=S.GetGameFrame()-1}
 local function fail(why)L.result='INCONCLUSIVE native_builder_ledger_'..why;return L.result end
 local expected=2;local builderName='wh40k_armcv';local fixedFeature,fixedFeatureDef
 if contract~=nil then
  if type(contract)~='table'or type(contract.builderName)~='string'or not contract.builderName:match('^[a-z][a-z0-9_]+$')or not finite(contract.builderDefID)or contract.builderDefID%1~=0 or contract.builderDefID<=0
   or not finite(contract.featureID)or contract.featureID%1~=0 or contract.featureID<0 or not finite(contract.featureDefID)or contract.featureDefID%1~=0 or contract.featureDefID<=0
   or not finite(contract.expectedMetal)or contract.expectedMetal<=0 or contract.expectedEnergy~=0 then fail('typed_native_builder_feature_contract_required');return L end
  expected=contract.expectedMetal;builderName=contract.builderName;fixedFeature=contract.featureID;fixedFeatureDef=contract.featureDefID;L.feature=fixedFeature
 end
 L.expectedMetal=expected
 local function signature()
  local ids=S.GetAllUnits();if type(ids)~='table'then return end
  table.sort(ids);local rows={};for _,id in ipairs(ids)do rows[#rows+1]=id..':'..tostring(S.GetUnitDefID(id))..':'..tostring(S.GetUnitTeam(id))end
  return table.concat(rows,',')
 end
 for _,name in ipairs({'GetAllUnits','GetGameFrame','GetUnitResources','GetUnitIsDead','GetUnitIsStunned','GetUnitTransporter','GetUnitTeam','GetUnitDefID','GetTeamResources'})do if type(S[name])~='function'then fail('API_'..name);return L end end
 L.units=signature();if not L.units then fail('native_unit_set_missing');return L end
 local def=D[S.GetUnitDefID(builder)]
 if not def or def.name~=builderName or not def.canReclaim or contract and S.GetUnitDefID(builder)~=contract.builderDefID then fail('actual_typed_builder_required');return L end
 if contract then
  if type(S.GetFeatureDefID)~='function'or type(S.GetFeatureResources)~='function'or S.GetFeatureDefID(L.feature)~=contract.featureDefID then fail('actual_typed_feature_definition_required');return L end
  local m,dm,e,de,left=S.GetFeatureResources(L.feature)
  if m~=expected or dm~=expected or e~=0 or de~=0 or left~=1 then fail('actual_pristine_feature_bill_must_bind_expected_credit');return L end
 end
 for _,key in ipairs({'metalMake','energyMake','makesMetal','extractsMetal','windGenerator','tidalGenerator','harvestMetalStorage','harvestEnergyStorage'})do if not finite(def[key])or def[key]~=0 then fail('nonzero_or_missing_native_builder_make_or_harvest_'..key);return L end end
 function L.Step(frame)
  if L.result then return L.result end
  if frame~=S.GetGameFrame()or frame~=L.lastFrame+1 then return fail('nonconsecutive_observation')end;L.lastFrame=frame
  if signature()~=L.units then return fail('active_unit_set_or_team_changed')end
  if S.GetUnitIsDead(builder)or S.GetUnitTeam(builder)~=team or S.GetUnitTransporter(builder)or S.GetUnitIsStunned(builder)then return fail('builder_lost_captured_stunned_or_transport')end
  if frame-L.started>600 then return fail('bounded_timeout')end
  if(frame-L.started)%M.period~=0 then return end
  local make,_,energyMake=S.GetUnitResources(builder)
  if not finite(make)or make<0 or not finite(energyMake)or energyMake~=0 then return fail('nonfinite_negative_or_energy_make')end
  if L.phase=='baseline'then
   if make~=0 then return fail('nonzero_preexisting_builder_credit')end
   if frame-L.started>=45 then L.ready=true end
  elseif L.phase=='active'or L.phase=='tail'then
   L.sum=L.sum+make;emit('NATIVE_BUILDER_ROLLING_SAMPLE',frame,make,'period=15 two_adjacent_native_intervals=true')
   if L.phase=='tail'then
    if make==0 then L.zeros=L.zeros+1 else L.zeros=0 end
    if frame-L.removed>=45 and L.zeros>=2 then
     L.gross=L.sum/2
     if math.abs(L.gross-expected)>.0001 then return fail('gross_credit_not_exact_bound_bill_'..tostring(L.gross))end
     L.phase='proved';L.proved=true;emit('NATIVE_BUILDER_GROSS_CREDIT',L.gross,'native_IssueResourceOrder_AddResources=true net_team_budget_not_used=true')
    end
   end
  end
 end
 function L.Begin()
  if not L.ready or L.phase~='baseline'then return fail('zero_baseline_required')end
  if fixedFeature then
   local m,dm,e,de,left=S.GetFeatureResources(fixedFeature)
   if L.feature~=fixedFeature or S.GetFeatureDefID(fixedFeature)~=fixedFeatureDef or m~=expected or dm~=expected or e~=0 or de~=0 or left~=1 then return fail('bound_feature_bill_changed_before_native_work')end
  end
  L.phase='active';L.sum=0
 end
 function L.Work(id,owner,fid,part)
  if id~=builder then return end
  if L.phase~='active'or owner~=team or fid~=L.feature or not finite(part)or part>=0 then return fail('unrelated_builder_resource_operation')end
  if fixedFeature and(fid~=fixedFeature or S.GetFeatureDefID(fid)~=fixedFeatureDef)then return fail('bound_feature_identity_changed')end
  local m,storage=S.GetTeamResources(team,'metal')
  if not finite(m)or not finite(storage)or storage-m<expected+.0001 then return fail('native_team_credit_overflow_headroom')end
  L.work=true
 end
 function L.Removed()
  if L.phase~='active'or not L.work then return fail('native_work_required_before_terminal')end
  L.phase='tail';L.removed=S.GetGameFrame();L.zeros=0
 end
 function L.Changed()return fail('native_unit_lifecycle_mutation')end
 return L
end
return M
