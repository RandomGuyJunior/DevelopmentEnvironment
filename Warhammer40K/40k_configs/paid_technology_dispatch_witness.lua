-- Genuine technology dispatch receipts; no command/admission/controller method calls.
local M={}
local function finite(x)return type(x)=='number'and x==x and x~=math.huge and x~=-math.huge end
local function v(x)if x==nil then return 'UNKNOWN'end;return x end
local function canonical(d)local cp=d and d.customParams or{};return cp.prototype40k_tech_requires or cp.prototype40k_donor or(d and d.name)end
function M.New(S,D,getController,game,log)
 local rows,serial,pending,tracked,memo=0,0,{},{},{}
 local R={}
 local function emit(key,signature,...)
  local now=S.GetGameFrame();local old=memo[key]
  if old and old.signature==signature and now-old.frame<900 then return end
  if rows>=2048 then return end
  rows=rows+1;memo[key]={signature=signature,frame=now};log('40K TECHNOLOGY DISPATCH WITNESS',...)
 end
 local function snapshot(phase,r,returned)
  local id,def,team,p=r.id,r.def,r.team,r.p;local d=D[def];local bd=D[S.GetUnitDefID(id)]
  if not d or not bd then return end
  local queue=S.GetUnitCommands(id,3)or{};local head=queue[1]
  local index=S.FindUnitCmdDesc and S.FindUnitCmdDesc(id,-def)
  local ds=index and S.GetUnitCmdDescs(id,index,index);local desc=ds and ds[1]
  local x,y,z=p[1],p[2],p[3];local facing=p[4]or 0
  if S.Pos2BuildPos then x,y,z=S.Pos2BuildPos(def,x,y,z,facing)end
  local test,feature
  if x and y and z then test,feature=S.TestBuildOrder(def,x,y,z,facing)end
  local bx,by,bz=S.GetUnitPosition(id)
  local ground=x and z and S.GetGroundHeight(x,z)
  local owner=S.GetUnitTeam(id);local hp,max,_,_,progress=S.GetUnitHealth(id)
  local menu=false;for _,key in ipairs(bd.buildOptions or{})do if key==def then menu=true end end
  local signature=table.concat({tostring(v(returned)),tostring(v(head and head.id)),tostring(v(desc and desc.disabled)),tostring(v(test)),tostring(v(feature)),tostring(v(owner)),tostring(v(progress and progress>=1)),tostring(p[1]),tostring(p[3])},'|')
  emit(id..':'..def..':'..phase,signature,phase,r.token,S.GetGameFrame(),id,team,def,d.name,'return',v(returned),'actualOwner',v(owner),'queueReadCount',#queue,'head',v(head and head.id),'tag',v(head and head.tag),
   'headParams',v(head and head.params and head.params[1]),v(head and head.params and head.params[2]),v(head and head.params and head.params[3]),'headTargetMatches',head~=nil and head.id==-def,
   'nativeMenuContains',menu,'descriptorIndex',v(index),'descriptorDisabled',v(desc and desc.disabled),'sourceCanBuildDispatchDecision',v(r.decision),'decisionFrame',r.frame,
   'builder',bd.name,'builderPos',v(bx),v(by),v(bz),'canMove',v(bd.canMove),'buildDistance',v(bd.buildDistance),'isBuilder',v(bd.isBuilder),'isFactory',v(bd.isFactory),'health',v(hp),'maxHealth',v(max),'buildProgress',v(progress),'no_controller_queries',true,'no_mutation',true)
  emit(id..':'..def..':'..phase..':site',signature,'SITE',r.token,phase,'supplied',p[1],p[2],p[3],facing,'nativeSnap',v(x),v(y),v(z),'nativeTest',v(test),'feature',v(feature),'ground',v(ground),
   'footprint',v(d.xsize),v(d.zsize),'maxSlope',v(d.maxSlope),'maxWaterDepth',v(d.maxWaterDepth),'minWaterDepth',v(d.minWaterDepth),'maxThisUnit',v(d.maxThisUnit),'sourceEntity',v((d.customParams or{}).source_entity),'native_api_not_causal_verdict',true)
  local C=getController();local req=C and C.requirements and C.requirements[canonical(d)]or{}
  local bits={};for _,name in ipairs(req.buildings or{})do bits[#bits+1]=name..'='..tostring(v(C and C.complete and C.complete[team]and C.complete[team][name]))end
  for _,name in ipairs(req.research or{})do bits[#bits+1]=name..'='..tostring(v(C and C.done and C.done[team]and C.done[team][name]))end
  local raw=table.concat(bits,';')..'|tier='..tostring(v(C and C.tiers and C.tiers[team]))
  emit(id..':'..def..':prerequisites',raw,'RAW_PREREQUISITES',r.token,canonical(d),raw,'tier',v(C and C.tiers and C.tiers[team]),'requiredTier',v(req.tier),'productionMethod',v(req.production_method),'NOT_REEVALUATED')
 end
 function R.ReadonlyCommandBefore(id,def,p,decision)
  if rows>=2048 or not D[def]or type(p)~='table'or not finite(p[1])or not finite(p[2])or not finite(p[3])or(p[4]~=nil and not finite(p[4]))then return nil end
  local count=0;for _ in pairs(tracked)do count=count+1 end
  if not tracked[id]and count>=128 then return nil end
  local team=S.GetUnitTeam(id);if team==nil then return nil end
  serial=serial+1
  local r={id=id,def=def,team=team,p={p[1],p[2],p[3],p[4]},decision=decision,frame=S.GetGameFrame(),token=serial}
  pending[id]=r;tracked[id]=r;snapshot('BEFORE',r);return r.token
 end
 function R.ReadonlyCommandAfter(token,id,def,p,returned)
  local r=pending[id];if not r or r.token~=token or r.def~=def then return false end
  snapshot('AFTER',r,returned);return true
 end
 function R.ReadonlyNextFrameBuildAttempt(frame)
  local ids={};for id in pairs(pending)do ids[#ids+1]=id end;table.sort(ids)
  for _,id in ipairs(ids)do local r=pending[id]
   if frame>r.frame then snapshot('NEXT_FRAME',r);pending[id]=nil end
  end
  for id,r in pairs(tracked)do if frame-r.frame>9000 then tracked[id]=nil end end
 end
 function R.Pending(id)return pending[id]~=nil end
 function R.Created(id,def,team,builder)
  local r=builder and tracked[builder]
  if r and r.def==def and r.team==team then
   emit('created:'..id,tostring(id),'ACTUAL_CREATED',r.token,S.GetGameFrame(),id,def,team,builder,'callback_only_not_acceptance');r.created=id
  end
 end
 function R.Finished(id,def,team)
  for _,r in pairs(tracked)do if r.created==id and r.def==def and r.team==team then emit('finished:'..id,tostring(id),'ACTUAL_FINISHED',r.token,S.GetGameFrame(),id,def,team,'callback_only_not_acceptance')end end
 end
 function R.Remove(id)pending[id]=nil;tracked[id]=nil end
 return R
end
return M
