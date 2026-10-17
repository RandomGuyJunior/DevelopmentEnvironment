-- Explicit five-model review: one native feature, alternative salvage/body consumers.
-- MaxSeconds bounds special harvest eligibility, never salvage lifetime.
local M={Version=1,MaxSeconds=180,Fraction=.25}
local keys={nec_warrior_body='basic_warrior',nec_flayed_body='flayed_one',nec_immortal_body='immortal',nec_wraith_body='wraith',nec_destroyer_body='destroyer'}
local function finite(v)return type(v)=='number'and v==v and v>=0 and v<math.huge end
local function enabled(v)return v==true or v==1 or v=='1'end
function M.Enabled(o)
 return o and enabled(o.prototype_corpse_reclaim_review)and enabled(o.prototype_spyder_harvest_review)and enabled(o.prototype_source_progression)
  and o.prototype_diagnostic=='expandedproduction'and not enabled(o.prototype_development_playtest)and not enabled(o.prototype_source_paid_match)
  and not(o.prototype_source_acceptance and o.prototype_source_acceptance~='')or false
end
function M.New(S,U,F,fps)
 assert(finite(fps)and fps>0 and fps%1==0)
 for _,name in ipairs({'GetFeatureResources','SetFeatureResources','GetFeatureRulesParam','SetFeatureRulesParam','GetFeatureTeam','GetFeatureDefID','ValidFeatureID','DestroyFeature','GetGameFrame'})do assert(type(S[name])=='function',name)end
 local R={rows={},count=0};local expires,pending={},{},{};local allowed,actorByFeature={},{}
 for def,d in pairs(F)do local actor=keys[d.name];local cp=d.customParams or{}
  if actor and tostring(cp.corpse_reclaim_review)=='1'and cp.source_body=='attrib/ebps/environment/gameplay/necron_'..actor..'_body.lua'and d.reclaimable and d.resurrectable==0 then allowed[def]=cp.source_body;actorByFeature[def]='attrib/ebps/races/necrons/troops/necron_'..actor..'.lua' end
 end
 local function mode(fid,r,value)r.mode=value;S.SetFeatureRulesParam(fid,'40k_corpse_mode',value,{private=true})end
 local function resources(fid)
  local m,dm,e,de,left,time=S.GetFeatureResources(fid)
  if not(finite(m)and finite(dm)and finite(e)and finite(de)and finite(left)and left<=1 and finite(time))then return end
  return m,dm,e,de,left,time
 end
 local function pristine(fid,r)
  local m,dm,e,de,left=resources(fid)
  return m and m==r.metal and dm==r.metal and e==r.energy and de==r.energy and left==1
 end
 local function schedule(fid,r)expires[r.expires]=expires[r.expires]or{};expires[r.expires][fid]=true end
 function R.FeatureLost(fid)
  local r=R.rows[fid];if not r then return end
  local bucket=expires[r.expires];if bucket then bucket[fid]=nil;if not next(bucket)then expires[r.expires]=nil end end
  R.rows[fid]=nil;pending[fid]=nil;R.count=R.count-1
 end
 local function persist(fid,r)
  for _,key in ipairs({'born','expires','team','def','metal','energy','time'})do S.SetFeatureRulesParam(fid,'40k_corpse_'..key,r[key],{private=true})end
  mode(fid,r,r.mode);S.SetFeatureRulesParam(fid,'40k_corpse_version',M.Version,{private=true})
 end
 function R.CanBirth(def,featureDef,source,proof)
  local d=U[def];local cost=type(proof)=='table'and proof.cost
  return d and (d.corpse==nil or d.corpse=='')and(d.wreckName==nil or d.wreckName=='')and allowed[featureDef]and allowed[featureDef]==source and (d.customParams or{}).source_entity==actorByFeature[featureDef]
   and type(proof)=='table'and proof.completed==true and type(cost)=='table'and finite(cost.work)and cost.work>0 and finite(cost.metal)and finite(cost.energy)and true or false
 end
 function R.Observe(fid,def,team,source,lifetime,proof)
  local fd=S.GetFeatureDefID(fid);if R.rows[fid]or not R.CanBirth(def,fd,source,proof)or not finite(lifetime)or lifetime<=0 then return false end
  local cost=proof.cost;local born=S.GetGameFrame();local ttl=math.max(1,math.floor(math.min(lifetime,M.MaxSeconds)*fps))
  local m,e=cost.metal*M.Fraction,cost.energy*M.Fraction;local time=math.max(30,math.min(6000,cost.work*M.Fraction))
  S.SetFeatureResources(fid,m,e,time,1,m,e)
  local actualM,dm,actualE,de,left,actualTime=resources(fid)
  if not actualM or left~=1 or actualM~=dm or actualE~=de then return false end
  local r={born=born,expires=born+ttl,team=team,def=def,metal=actualM,energy=actualE,time=actualTime,mode=1}
  R.rows[fid]=r;R.count=R.count+1;persist(fid,r);schedule(fid,r);return true
 end
 function R.Available(fid,actor)
  local r=R.rows[fid]
  if not r or S.GetGameFrame()>=r.expires or not S.ValidFeatureID(fid)or S.GetFeatureTeam(fid)~=r.team then return false end
  if not pristine(fid,r)then if r.mode==1 or r.mode==2 then mode(fid,r,4);r.actor=nil end;return false end
  return r.mode==1 or r.mode==2 and r.actor==actor
 end
 function R.Reserve(fid,actor)
  if not R.Available(fid,actor)then return false end
  local r=R.rows[fid];r.actor=actor;mode(fid,r,2);return true
 end
 function R.Release(fid,actor)
  local r=R.rows[fid];if r and r.mode==2 and r.actor==actor then r.actor=nil;mode(fid,r,pristine(fid,r)and 1 or 4)end
 end
 function R.Consume(fid,actor)
  local r=R.rows[fid];if not r or r.mode~=2 or r.actor~=actor or not R.Available(fid,actor)then return false end
  mode(fid,r,5);r.actor=nil;pending[fid]=nil
  -- Remove the alternative economic value before deferred native destruction.
  S.SetFeatureResources(fid,0,0,r.time,0,0,0);return true
 end
 function R.Expire(fid)
  local r=R.rows[fid];if not r or r.mode==6 then return false end
  -- Only special harvest eligibility expires. Native remaining salvage persists.
  if r.mode>=5 then return false end
  mode(fid,r,4);r.actor=nil;pending[fid]=nil
  return true,'salvage_retained'
 end
 function R.AllowBuildStep(fid,part)
  local r=R.rows[fid]
  if not r then return not allowed[S.GetFeatureDefID(fid)]end -- unregistered review bodies have no resource path
  if type(part)~='number'or not finite(-part)or part>=0 or r.mode==2 or r.mode>=5 then return false end
  if r.mode==1 then mode(fid,r,3);pending[fid]=true end
  return true -- native AddBuildPower owns resource accounting and competing builders
 end
 function R.PostFrame()
  local ids={};for fid in pairs(pending)do ids[#ids+1]=fid end;table.sort(ids)
  for _,fid in ipairs(ids)do local r=R.rows[fid];pending[fid]=nil
   if r and S.ValidFeatureID(fid)then mode(fid,r,pristine(fid,r)and 1 or 4)end
  end
 end
 function R.Frame(frame)
  local bucket=expires[frame];if not bucket then return end
  local ids={};for fid in pairs(bucket)do ids[#ids+1]=fid end;table.sort(ids)
  for _,fid in ipairs(ids)do if R.rows[fid]and R.rows[fid].expires<=frame then R.Expire(fid)end end
  expires[frame]=nil
 end
 function R.Restore()
  -- Salvage-only restoration; never invent missing paid Spyder/body provenance.
  local ids=S.GetAllFeatures()or{};table.sort(ids)
  for _,fid in ipairs(ids)do local fd=S.GetFeatureDefID(fid)
   if allowed[fd]and S.GetFeatureRulesParam(fid,'40k_corpse_version')==M.Version then
    local r={};for _,key in ipairs({'born','expires','team','def','metal','energy','time','mode'})do r[key]=S.GetFeatureRulesParam(fid,'40k_corpse_'..key)end
    local valid=true;for _,value in pairs(r)do if not finite(value)then valid=false end end
    for _,key in ipairs({'born','expires','team','def','metal','energy','time','mode'})do if not finite(r[key])then valid=false end end
    local m,dm,e,de,left,time=resources(fid)
    valid=valid and r.expires%1==0 and r.expires>r.born and r.expires-r.born<=M.MaxSeconds*fps and r.time>=1 and r.time<=6000 and U[r.def]~=nil and (U[r.def].customParams or{}).source_entity==actorByFeature[fd]and r.born%1==0 and r.born<=S.GetGameFrame()
     and m and m<=r.metal and dm==r.metal and e<=r.energy and de==r.energy and time==r.time
    if valid and r.mode>=1 and r.mode<=4 then
     r.mode=4;R.rows[fid]=r;R.count=R.count+1;persist(fid,r);if r.expires>S.GetGameFrame()then schedule(fid,r)end
    else S.SetFeatureResources(fid,0,0,30,0,0,0);S.DestroyFeature(fid)end
   end
  end
 end
 return R
end
return M
