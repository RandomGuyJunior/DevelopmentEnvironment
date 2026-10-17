-- Root supplies paid-origin and the body-production creation permit. No normal costs change.
local M={BodyLinks={}}
for actor,lifetime in pairs({basic_warrior=180,flayed_one=180,immortal=180,wraith=180,destroyer=180,deathmark=180,lychguard=30,skorpekh=180})do
 M.BodyLinks['attrib/ebps/races/necrons/troops/necron_'..actor..'.lua']={source='attrib/ebps/environment/gameplay/necron_'..actor..'_body.lua',lifetime=lifetime}
end
local outputs={nec_warrior='basic_warrior',nec_flayed='flayed_one',nec_immortal='immortal'}
function M.New(S,U,F,C)
 assert(type(C.IsPaidSpyder)=='function'and type(C.WithBodyProductionPermit)=='function'and type(C.OutputReady)=='function'and type(C.DeathEligible)=='function')
 local featureBySource,unitByName,suppressed={},{},{};local R=C.CorpseAccount
 for fid,d in pairs(F)do local cp=d.customParams or{};if cp.source_body then assert(not featureBySource[cp.source_body],'ambiguous body binding');featureBySource[cp.source_body]=fid end end
 for uid,d in pairs(U)do if d.name then unitByName[d.name]=uid end end
 local Q={scale=C.scale,fps=C.fps,PolicyDeclared=C.eligibility=='same_death_team_review',IsPaidSpyder=C.IsPaidSpyder,OutputReady=C.OutputReady,Witness=C.Witness}
 function Q.Ready()
  -- Legacy individual-body review is legal only with one complete alternative
  -- salvage account. No-account fallback can race ordinary native reclaim.
  if type(R)~='table'or type(C.OwnerAlive)~='function'or C.OwnerAlive()~=true then return false end
  for _,name in ipairs({'CanBirth','Observe','Available','Reserve','Release','Consume','Expire','AllowBuildStep','FeatureLost'})do
   if type(R[name])~='function'then return false end
  end
  if Q.PolicyDeclared~=true or type(Q.scale)~='number'or Q.scale<=0 or type(Q.fps)~='number'or Q.fps<=0 then return false end
  for name,source in pairs(outputs)do
   local d=U[unitByName[name]];local cp=d and d.customParams or{}
   if not d or cp.source_entity~='attrib/ebps/races/necrons/troops/necron_'..source..'.lua'then return false end
   -- Source body currency buys three individual actors, never aggregate products
   -- or hidden squad bodies. A paired squad-output transaction is separate work.
   if cp.prototype40k_squad_product or tonumber(cp.prototype40k_squad_internal or 0)==1 then return false end
  end
  -- All supported live source-linked actors require genuine authored body bindings.
  for _,d in pairs(U)do local link=M.BodyLinks[(d.customParams or{}).source_entity];if link and not featureBySource[link.source]then return false end end
  return true
 end
 function Q.Eligible(team,deathTeam)return Q.PolicyDeclared and team==deathTeam end
 function Q.BodyIdentity(fid,deadDef,source)
  local d=U[deadDef];local link=d and M.BodyLinks[(d.customParams or{}).source_entity]
  return link and link.source==source and S.GetFeatureDefID(fid)==featureBySource[source]and true or false
 end
 function Q.BirthDeathBody(id,def,team)
  if not Q.Ready()or suppressed[id]then return end
  local eligible,proof=C.DeathEligible(id,def,team);if eligible~=true then return end
  local d=U[def];local link=d and M.BodyLinks[(d.customParams or{}).source_entity];local x,y,z=S.GetUnitPosition(id)
  if not link or not x then return end
  local fd=featureBySource[link.source]
  if R and not R.CanBirth(def,fd,link.source,proof)then return end
  local feature=S.CreateFeature(F[fd].name,x,y,z,S.GetUnitHeading(id)or 0,team)
  if R and (not feature or not R.Observe(feature,def,team,link.source,link.lifetime,proof))then if feature then S.DestroyFeature(feature)end;return end
  return feature,link.source,link.lifetime
 end
 if R then
  Q.BodyAvailable=R.Available;Q.ReserveBody=R.Reserve;Q.ReleaseBody=R.Release;Q.ConsumeBody=R.Consume;Q.ExpireBody=R.Expire
 end
 function Q.OutputIdentity(id,row)return S.GetUnitDefID(id)==unitByName[row.entity]end
 function Q.PlanOutput(id,row,team)
  local d=U[unitByName[row.entity]];local x,y,z=S.GetUnitPosition(id);if not d or not x then return end
  local step=math.max(d.xsize or 1,d.zsize or 1)*8+8;local plan={}
  for i=1,row.count do local px=x+i*step;local pz=z+step;local py=S.GetGroundHeight(px,pz)
   if S.TestBuildOrder(d.id or unitByName[row.entity],px,py,pz,0)~=2 then return end
   plan[i]={px,py,pz}
  end
  return plan
 end
 function Q.CreateOutput(id,row,team,p)
  return C.WithBodyProductionPermit(id,row.entity,team,function()return S.CreateUnit(row.entity,p[1],p[2],p[3],0,team,false,false,nil,id)end)
 end
 function Q.RollbackOutput(id)suppressed[id]=true;S.DestroyUnit(id,false,true);suppressed[id]=nil end -- reclaim avoids new combat death-body reward
 return Q
end
return M
