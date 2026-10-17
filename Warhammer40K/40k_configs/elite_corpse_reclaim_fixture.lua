-- Native reclaim of funded seeded features, never a paid casualty/death proof.
local M={Option='prototype_elite_corpse_reclaim_fixture',Rows={
 {actor='imp_scout',feature='40k_scout_corpse',metal=7.5,work=75,pilot='prototype_scout_remains_pilot'},
 {actor='imp_kasrkin',feature='40k_kasrkin_corpse',metal=13.75,work=130,pilot='prototype_guard_kasrkin_remains_pilot'},
 {actor='imp_ogryn',feature='40k_ogryn_corpse',metal=22.5,work=212.5,pilot='prototype_ogryn_remains_pilot'}}}
local function on(v)return v==true or v==1 or v=='1'end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function int(v)return finite(v)and v>=0 and v%1==0 end
local function empty(v)return type(v)=='table'and next(v)==nil end
function M.Enabled(o)return type(o)=='table'and on(o[M.Option])end
function M.Admit(o,F,U,owner)
 assert(M.Enabled(o)and on(o.prototype_development_playtest)and on(o.prototype_source_progression)and o.prototype_diagnostic=='normal'and tonumber(o.prototype_test_speed or 1)==1,'Explicit development normal-speed diagnostic required')
 assert(owner.Version==1 and owner.Fraction==.25 and type(owner.Definition)=='function','Reviewed single-owner quarter entitlement contract required')
 local rows={};for i,r in ipairs(M.Rows)do
  assert(on(o[r.pilot]),'Actual reviewed source pilot required '..r.actor)
  assert(owner.Actors[r.actor]and owner.Actors[r.actor].feature==r.feature,'Exact source recipe registration required')
  local found;for id,d in pairs(F)do if d.name==r.feature then
   local cp=d.customParams or{};assert(int(id),'Typed compiled feature ID required');assert(not found and cp.parent_actor==r.actor and on(cp.prototype40k_tactical_remains),'Unique compiled source parent required')
   assert(d.reclaimable==true and d.resurrectable==0 and d.metal==0 and d.energy==0 and d.blocking==false,'Zero base native reclaimable definition required')
   assert(d.modelname==r.feature..'.glb'or d.modelname=='objects3d/'..r.feature..'.glb','Exact source compiled private model required');found=id
  end end;assert(found,'Actual compiled feature missing');rows[i]={row=r,def=found}
 end
 local builder;for id,d in pairs(U)do if d.name=='imp_enginseer'then assert(int(id),'Typed native builder definition required');assert(not builder and d.isBuilder==true and d.canReclaim==true and finite(d.buildDistance)and d.buildDistance>=96 and finite(d.reclaimSpeed)and d.reclaimSpeed>0,'Genuine native reclaim builder required');builder=id end end
 assert(builder,'Actual Enginseer definition missing');return rows,builder
end
function M.New(S,F,U,C,rows,bdef,team,mapX,mapZ,maxUnits)
 assert(int(team)and finite(mapX)and finite(mapZ)and mapX>=1600 and mapZ>=1600 and int(maxUnits)and maxUnits>0,'Exact native launch geometry/team required')
 local valid=false;for _,t in pairs(S.GetTeamList())do if t==team then valid=true end end;assert(valid and team~=S.GetGaiaTeamID(),'Actual non-Gaia fixture team required')
 local R={owned={},index=1,done=false};local builder,retiredBuilder,start
 local function log(event,...)local args={'40K ELITE CORPSE RECLAIM',S.GetGameFrame(),event,...};local n=3+select('#',...);args[n+1]='funded=true';args[n+2]='ordinaryEconomy=false';args[n+3]='lethalDeath=false';S.Echo(unpack(args,1,n+3))end
 local function builderCheck()assert(not retiredBuilder and S.GetUnitDefID(builder)==bdef and S.GetUnitTeam(builder)==team,'Created builder identity retired/changed')end
 local function inventory()
  local seen={};for _,fid in pairs(S.GetAllFeatures())do for _,row in ipairs(R.owned)do if S.GetFeatureDefID(fid)==row.def then
   assert(not row.retired and fid==row.fid and not seen[fid],'Duplicate/replacement source feature');seen[fid]=true
  end end end
  for _,row in ipairs(R.owned)do assert(row.retired or seen[row.fid],'Feature missing without native destruction callback')end
 end
 local function sample(label)
  for _,resource in ipairs({'metal','energy'})do local a={S.GetTeamResources(team,resource)};local b={S.GetTeamResourceStats(team,resource)};log('TEAM',label,resource,unpack(a));log('TEAM_STATS',label,resource,unpack(b))end
 end
 function R.Begin()
  assert(not R.started,'Fixture entitlement seeds are single-use');R.started=true
  for _,fid in pairs(S.GetAllFeatures())do for _,row in ipairs(rows)do assert(S.GetFeatureDefID(fid)~=row.def,'Existing same-family feature makes isolated fixture ambiguous')end end
  local site;for z=600,mapZ-600,256 do for x=600,mapX-600,256 do
   local y=S.GetGroundHeight(x,z);local clear=finite(y)and y>0 and empty(S.GetUnitsInCylinder(x,z,240))and empty(S.GetFeaturesInCylinder(x,z,240))
   for _,dx in ipairs({-64,0,64})do for _,dz in ipairs({0,64,96})do local h=S.GetGroundHeight(x+dx,z+dz);clear=clear and finite(h)and math.abs(h-y)<.02 end end
   if clear and S.TestMoveOrder(bdef,x,y,z+96)then site={x,y,z};break end
  end;if site then break end end;assert(site,'Dry clear actual native builder site unavailable')
  builder=S.CreateUnit('imp_enginseer',site[1],S.GetGroundHeight(site[1],site[3]+96),site[3]+96,0,team);assert(int(builder),'Native fixture builder birth refused');builderCheck()
  S.GiveOrderToUnit(builder,C.FIRE_STATE,{0},{});S.GiveOrderToUnit(builder,C.MOVE_STATE,{0},{})
  for i,r in ipairs(rows)do local x,z=site[1]+(i-2)*64,site[3];local y=S.GetGroundHeight(x,z)
   local fid=S.CreateFeature(r.row.feature,x,y,z,0,team);assert(int(fid),'Actual native feature creation refused')
   for _,prior in ipairs(R.owned)do assert(prior.fid~=fid,'Repeated created feature ID')end
   local row={fid=fid,def=r.def,source=r.row,x=x,z=z};R.owned[#R.owned+1]=row
   assert(S.GetFeatureDefID(fid)==r.def and S.GetFeatureTeam(fid)==team,'Created source definition/team changed')
   -- Explicit diagnostic funding only: no paid snapshot, generation, casualty or second owner.
   S.SetFeatureResources(fid,r.row.metal,0,r.row.work,1,r.row.metal,0)
   local m,mm,e,ee,left,work=S.GetFeatureResources(fid);assert(m==r.row.metal and mm==m and e==0 and ee==0 and left==1 and work==r.row.work,'Exact native funded cap/work readback required')
   log('FUNDED_SEED',r.row.actor,fid,r.def,m,mm,e,ee,left,work)
  end
  start=S.GetGameFrame();sample('before');inventory();return builder,R.owned
 end
 function R.UnitDestroyed(id)if id==builder then retiredBuilder=true end end
 function R.BuildStep(id,t,fid,def,part)
  for _,row in ipairs(R.owned)do if fid==row.fid then
   assert(not row.retired and row==R.owned[R.index]and row.ordered and id==builder and t==team and def==row.def and finite(part)and part<0,'Foreign/unordered/retired native reclaim work')
   builderCheck();local cmd,opts,tag,param=S.GetUnitCurrentCommand(builder);assert(cmd==C.RECLAIM and param==maxUnits+fid,'Native callback must match actual current reclaim target');row.commandSeen=true;row.lastStep=S.GetGameFrame();row.steps=(row.steps or 0)+1;log('NATIVE_BUILD_STEP',id,t,fid,def,part)
  end end
 end
 function R.FeatureDestroyed(fid)
  for _,row in ipairs(R.owned)do if row.fid==fid and not row.retired then
   row.retired=true
   assert(row==R.owned[R.index]and row.ordered and row.commandSeen and row.partial and row.lastStep and S.GetGameFrame()-row.lastStep>=0 and S.GetGameFrame()-row.lastStep<=1,'Feature removed without same-feature native partial/command/work')
   row.destroyed=S.GetGameFrame();log('NATIVE_FEATURE_DESTROYED',row.source.actor,fid,row.lastStep);sample('destroyed')
  end end
 end
 function R.Step()
  if R.done then return end;builderCheck();inventory();local f=S.GetGameFrame();assert(f-start<=1800,'Bounded native reclaim timeout')
  local row=R.owned[R.index];if not row then R.done=true;sample('final');log('COMPLETE','three_distinct_native_partial_then_full','nativeAccepted=false','creditedEconomyAccepted=false');return end
  if row.retired then assert(row.destroyed,'Retired without native completion');if f-row.destroyed>=20 then R.index=R.index+1 end;return end
  assert(S.GetFeatureTeam(row.fid)==team,'Created feature ownership changed')
  local x,y,z=S.GetFeaturePosition(row.fid);assert(finite(x)and finite(y)and finite(z)and math.abs(x-row.x)<.02 and math.abs(z-row.z)<.02 and math.abs(y-S.GetGroundHeight(x,z))<.02,'Feature position/root grounding changed')
  local m,mm,e,ee,left,work=S.GetFeatureResources(row.fid)
  assert(finite(m)and finite(mm)and m>=0 and mm>=0 and m<=row.source.metal+.001 and mm<=row.source.metal+.001 and e==0 and ee==0 and finite(left)and left>=0 and left<=1 and finite(work)and math.abs(work-row.source.work)<.001,'Funded cap/work/fraction changed')
  if not row.ordered then assert(left==1 and m==row.source.metal and mm==m,'Nonpristine fixture before order');row.ordered=f;row.previousMetal=m;row.previousLeft=left
   assert(S.GiveOrderToUnit(builder,C.RECLAIM,{maxUnits+row.fid},{})~=false,'Native reclaim order refused');log('NATIVE_ORDER',row.source.actor,builder,C.RECLAIM,maxUnits+row.fid);return
  end
  local cmd,opts,tag,param=S.GetUnitCurrentCommand(builder);if cmd==C.RECLAIM and param==maxUnits+row.fid then row.commandSeen=true end
  assert(m<=row.previousMetal+.001 and left<=row.previousLeft+.00001,'Native resource/fraction increased');row.previousMetal=m;row.previousLeft=left
  if left>0 and left<1 then assert(row.lastStep and row.commandSeen,'Partial without native callback/current command');if not row.partial then row.partial=true;log('PARTIAL',row.source.actor,row.fid,m,mm,e,ee,left,work);sample('partial')end end
 end
 function R.Cleanup()
  for _,row in ipairs(R.owned)do if not row.retired then row.retired=true;if S.GetFeatureDefID(row.fid)==row.def and S.GetFeatureTeam(row.fid)==team then S.DestroyFeature(row.fid)else log('CLEANUP_REFUSED_FEATURE',row.fid)end end end
  if builder and not retiredBuilder then retiredBuilder=true;if S.GetUnitDefID(builder)==bdef and S.GetUnitTeam(builder)==team then S.DestroyUnit(builder,false,true)else log('CLEANUP_REFUSED_BUILDER',builder)end end
 end
 return R
end
return M
