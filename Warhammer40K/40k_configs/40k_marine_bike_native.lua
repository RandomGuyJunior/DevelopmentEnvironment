-- Genuine paid Bike cohorts: native event adapter, not a roster acceptance marker.
local M={Version=1}
local key='imp_source_hq_addon_1'
local function norm(p)return(p or ''):gsub('\\','/'):lower()end
local function sorted(t)local a={};for k in pairs(t or{})do a[#a+1]=k end;table.sort(a);return a end
local function copy(t)local r={};for k,v in pairs(t or{})do r[k]=type(v)=='table'and copy(v)or v end;return r end
local function integer(x)return type(x)=='number'and x>=0 and x<math.huge and x==math.floor(x)end
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function length(x,y,z)return math.sqrt(x*x+y*y+z*z)end
function M.Attach(C,S,defs,V,g,CMD,fps,Q)
 assert(not C.sourceBikeNative,'Attach Bike adapter once')
 assert(integer(fps)and fps>0 and integer(Q.command)and Q.command>0,'Native frame rate and unoccupied command required')
 assert(not(C.commands or{})[Q.command],'Reinforcement command must not overlap paid research')
 for _,name in ipairs({'Ready','PopulationAllowed','Applied','WholeTransactionReady'})do assert(type(Q[name])=='function','Explicit integration required: '..name)end
 assert(integer(Q.combatEvidenceFrames)and Q.combatEvidenceFrames>0,'Explicit combat-evidence release window required; source duration unverified')
 local F=assert(Q.facts);local cohort=assert(Q.cohortModule);local profile=assert(V.SourceProfiles[key])
 local stamp=tonumber(F.source_hashes.marine_addon.sha256:sub(1,6),16)
 local A={grants={},initial={},births={},combat={},failures={}};local R;local activeBirth;local transactions={}
 local prefix='40k_bike_native_';local defID
 for id,d in pairs(defs)do if norm((d.customParams or{}).source_entity)==norm(F.bike.source_entity)then assert(not defID,'Ambiguous genuine Bike identity');defID=id end end
 local function put(id,k,v)S.SetUnitRulesParam(id,prefix..k,v,{private=true})end
 local function live(id,team,def,complete)
  local hp,_,_,_,built=S.GetUnitHealth(id)
  return hp and hp>0 and S.GetUnitTeam(id)==team and(not def or S.GetUnitDefID(id)==def)and(not complete or built and built>=1)
 end
 local function entity(id)return norm((defs[S.GetUnitDefID(id)]or{}).customParams and defs[S.GetUnitDefID(id)].customParams.source_entity)end
 local function cost(id,m,e,t)local bt,metal,energy=S.GetUnitCosts(id);return bt==t*fps and metal==m and energy==e end
 local function ready()return defID~=nil and Q.Ready()==true and Q.WholeTransactionReady()==true end
 function A.Supported(k,p,e)
  return k==key and p and p.sha256==F.source_hashes.marine_addon.sha256 and p.cost.metal==400 and p.cost.energy==130 and p.time==90
   and e and e.type=='enable_squad_reinforcement'and e.target=='space_marine_squad_tactical_bike'and e.value==2
   and e.application_type=='type_modifierapplicationtype/tp_mod_apply_to_squad_type.lua'and e.probability==1 and e.exclusive==false
   and F.bike.reinforcement_disabled_value==-1 and F.bike.addon_enable_value==2 and F.bike.initial_size==1 and F.bike.maximum_size==3 and ready()
 end
 local function producer(id,team)
  local u=C.units[id];if not u or not u.finished or u.team~=team or not live(id,team,u.def,true)then return false end
  for _,p in ipairs(profile.source_producers or{})do if entity(id)==norm(p)then return true end end
  return false
 end
 local function paid(id,team)
  local E=C.sourceVariantAddonJobs;local j=E and(E.jobs[id]or{})[key]
  local q=(S.GetUnitCommands(id,-1)or{})[1]
  return producer(id,team)and j and j.team==team and j.def==S.GetUnitDefID(id)and j.active==true and j.frames==90*fps and j.steps==j.frames
   and j.cost.metal==400 and j.cost.energy==130 and j.metal==400 and j.energy==130 and integer(j.tag)and q and q.id==j.cmd and q.tag==j.tag and j or nil
 end
 -- Pure prospective preparation. Root must validate ALL primitive and cohort plans
 -- before ANY commit; invoke Commit while the real fully paid job/head still exists.
 function A.PrepareEnable(team,k,p,id)
  if k~=key or not p or p.sha256~=profile.sha256 or not ready()then return nil,'unsupported_enable' end
  local effect;for _,e in ipairs(p.effects or{})do if e.type=='enable_squad_reinforcement'then if effect then return nil,'duplicate_enable'end;effect=e end end
  if not A.Supported(k,p,effect)then return nil,'unsupported_enable'end
  local j=paid(id,team);if not j then return nil,'not_actual_paid_hq_head'end
  local old={};for _,field in ipairs({'team','def','tag','source','frames','metal','energy'})do old[field]=S.GetUnitRulesParam(id,prefix..'enable_'..field)end
  local t={};transactions[t]={team=team,producer=id,job=j,tag=j.tag,committed=false,oldGrant=A.grants[id]and copy(A.grants[id]),oldRules=old};return t
 end
 function A.ValidateEnable(token)
  local t=transactions[token];return t and not t.committed and ready()and paid(t.producer,t.team)==t.job and t.job.tag==t.tag or false
 end
 function A.CommitEnable(token)
  if not A.ValidateEnable(token)then return false end
  local t=transactions[token];t.committed=true
  local r={team=t.team,def=S.GetUnitDefID(t.producer),tag=t.tag,source=stamp,frames=90*fps,metal=400,energy=130}
  A.grants[t.producer]=r
  for k,v in pairs(r)do put(t.producer,'enable_'..k,v)end
  return true
 end
 function A.FinishEnable(token)
  local t=transactions[token];if not t or not t.committed then return false end
  transactions[token]=nil;return true
 end
 function A.AbortEnable(token)
  local t=transactions[token];if not t then return false end
  transactions[token]=nil
  if t.committed then
   A.grants[t.producer]=t.oldGrant
   if not producer(t.producer,t.team)then A.grants[t.producer]=nil;return false end
   for _,field in ipairs({'team','def','tag','source','frames','metal','energy'})do put(t.producer,'enable_'..field,t.oldRules[field])end
   for _,field in ipairs({'team','def','tag','source','frames','metal','energy'})do
    if S.GetUnitRulesParam(t.producer,prefix..'enable_'..field)~=t.oldRules[field]then return false end
   end
  end
  return true
 end
 local function receipt(id,team,r)
  if not ready()or not producer(id,team)or type(r)~='table'or r.team~=team or r.def~=S.GetUnitDefID(id)or r.source~=stamp
   or r.frames~=90*fps or r.metal~=400 or r.energy~=130 or not integer(r.tag)then return false end
  for _,field in ipairs({'team','def','tag','source','frames','metal','energy'})do
   if S.GetUnitRulesParam(id,prefix..'enable_'..field)~=r[field]then return false end
  end;return true
 end
 function A.HasEnableReceipt(team,k,id)
  return k==key and receipt(id,team,A.grants[id])or false
 end
 function A.RestoreEnable(team,k,p,id)
  if k~=key or not p or p.sha256~=profile.sha256 or not ready()or not(C.sourceVariantAdapter and C.sourceVariantAdapter.LocalAddon(id,team,key))then return false end
  local r={};for _,field in ipairs({'team','def','tag','source','frames','metal','energy'})do r[field]=S.GetUnitRulesParam(id,prefix..'enable_'..field)end
  if not receipt(id,team,r)then return false end
  A.grants[id]=r;return true
 end
 function A.Enabled(team)
  if not ready()then return false end
  for _,id in ipairs(sorted(A.grants))do local r=A.grants[id]
   if r.team==team and producer(id,team)and r.def==S.GetUnitDefID(id)and r.source==stamp
    and C.sourceVariantAdapter and C.sourceVariantAdapter.LocalAddon(id,team,key)==true and Q.Applied(team,key,id)==true then return true end
  end
  return false
 end
 local function sphere(id,feature)
  local pos=feature and S.GetFeaturePosition or S.GetUnitPosition
  local vol=feature and S.GetFeatureCollisionVolumeData or S.GetUnitCollisionVolumeData
  local x,y,z,mx,my,mz=pos(id,true);local sx,sy,sz,ox,oy,oz=vol(id)
  if not(finite(x)and finite(y)and finite(z)and finite(mx)and finite(my)and finite(mz)and finite(sx)and finite(sy)and finite(sz)and sx>=0 and sy>=0 and sz>=0 and finite(ox)and finite(oy)and finite(oz))then return nil end
  -- Full base-centred enclosing sphere. Rotation cannot enlarge this envelope.
  -- Conservative for every native primitive, preserves hidden/full collision body.
  return{x,y,z,length(sx,sy,sz)/2+length(ox,oy,oz)+length(mx-x,my-y,mz-z)}
 end
 local function clear(position,radius,ignore)
  for _,id in ipairs(S.GetAllUnits())do if id~=ignore then local b=sphere(id,false)
   if not b or length(position[1]-b[1],position[2]-b[2],position[3]-b[3])<=radius+b[4]then return false end
  end end
  for _,id in ipairs(S.GetAllFeatures())do local b=sphere(id,true)
   if not b or length(position[1]-b[1],position[2]-b[2],position[3]-b[3])<=radius+b[4]then return false end
  end
  return true
 end
 local function placement(leader,def)
  local base=sphere(leader,false);if not base then return nil end
  for ring=1,4 do for _,dir in ipairs({{1,0},{0,1},{-1,0},{0,-1},{1,1},{-1,1},{-1,-1},{1,-1}})do
   local n=math.sqrt(dir[1]^2+dir[2]^2);local distance=(2*base[4]+1)*ring
   -- Native CreateUnit accepts float3. Plan on an exact binary lattice first,
   -- then read the real ground at that SAME point and run unchanged predicates.
   local x=math.floor((base[1]+dir[1]*distance/n)*16+.5)/16
   local z=math.floor((base[3]+dir[2]*distance/n)*16+.5)/16
   local representable=math.abs(x)<1048576 and math.abs(z)<1048576
   local y=representable and S.GetGroundHeight(x,z)or nil
   local p={x,y,z}
   if representable and finite(y)and y>=0 and S.TestMoveOrder(def,x,y,z,0,0,0,true,true,false)==true and clear(p,base[4])then return p end
  end end
 end
 local function describe(id)
  if not S.FindUnitCmdDesc(id,Q.command)then S.InsertUnitCmdDesc(id,{id=Q.command,type=Q.commandType or 0,name='Reinforce',action='sourcebikereinforce',tooltip='Reinforce Tactical Bike squad (80 requisition, 40 power)'})end
 end
 function A.BirthBeforeRegister(id,def,team,builder)
  if def~=defID then return false,'different_definition'end
  if activeBirth then
   if not R.UnitCreated(id,def,team,builder)then activeBirth.invalid=true;return false,'paid_native_permit_refused'end
   S.SetUnitCosts(id,{buildTime=10*fps,metalCost=80,energyCost=40})
   if not cost(id,80,40,10)then activeBirth.invalid=true;return false,'paid_native_cost_readback_refused'end
   A.births[id]={team=team,def=def,builder=builder};put(id,'paid_birth',stamp);put(id,'birth_team',team);return true,'paid_native_permit_cost_receipt'
  end
  local hp,_,_,_,built=S.GetUnitHealth(id);local u=C.units[builder]
  if hp and built and built<1 and u and u.finished and u.team==team and live(builder,team,u.def,true)
   and entity(builder)==norm(F.bike.source_producer)and defs[u.def].isFactory==true and cost(id,170,30,30)then
   A.initial[id]={team=team,def=def,builder=builder};put(id,'initial',stamp);put(id,'initial_team',team);put(id,'initial_builder',builder);return true
  end
  return false
 end
 function A.UnitFromFactory(id,def,team,factory)
  local r=A.initial[id];local u=C.units[factory]
  local okay=r and r.team==team and r.def==def and r.builder==factory and def==defID and u and u.finished and u.team==team
   and live(factory,team,u.def,true)and entity(factory)==norm(F.bike.source_producer)and defs[u.def].isFactory==true
   and S.GetUnitIsBuilding(factory)==id and cost(id,170,30,30)
  if not okay then return false end
  local accepted=R.RegisterInitial(id,team,factory,'native_UnitFromFactory');A.initial[id]=nil
  if accepted then describe(id)end;return accepted
 end
 local P={defID=defID or 0,command=Q.command,removeCommand=assert(CMD.REMOVE),fps=fps}
 P.Ready=ready;P.Enabled=A.Enabled;P.PopulationAllowed=Q.PopulationAllowed;P.Placement=placement
 P.ProveInitialProduct=function(id,team,factory,event)return event=='native_UnitFromFactory'and A.initial[id]and A.initial[id].team==team and A.initial[id].builder==factory end
 P.InCombat=function(_,members)local now=S.GetGameFrame();for id in pairs(members)do local f=A.combat[id];if f and now>=f and now-f<Q.combatEvidenceFrames then return true end end;return false end
 P.CreatePaid=function(def,team,leader,pos)
  assert(not activeBirth and R.AuthorizeBirth(def,team,leader),'Single paid source birth required')
  local receipt={};activeBirth=receipt
  -- Native CreateUnit builder is argument TEN; native UnitCreated is synchronous.
  local okay,id=pcall(S.CreateUnit,def,pos[1],pos[2],pos[3],0,team,false,false,nil,leader)
  activeBirth=nil;if not okay then error(id)end
  if receipt.invalid then error('Native birth costs/witness refused')end;return id
 end
 P.BirthMatches=function(id,def,team,p)
  local x,y,z=S.GetUnitPosition(id);local r=A.births[id];local b=sphere(id,false)
  return ready()and r and r.team==team and r.def==def and live(id,team,def,true)and cost(id,80,40,10)and b
   and math.abs(x-p[1])<=1e-4 and math.abs(y-p[2])<=1e-4 and math.abs(z-p[3])<=1e-4 and clear({x,y,z},b[4],id)
 end
 -- Native numeric RulesParams are float32. Keep the two fractional paid
 -- receipts as exact private decimal strings, interpreted only by this adapter.
 -- The pure source cohort still verifies exact journal values and rational cost.
 local receiptSpring=setmetatable({}, {__index=S})
 local money={['40k_bike_cohort_metal']=true,['40k_bike_cohort_energy']=true}
 function receiptSpring.SetUnitRulesParam(id,k,v,opts)
  if money[k]then
   assert(finite(v)and v>=0,'Finite paid receipt required')
   local text=string.format('%.17g',v);S.SetUnitRulesParam(id,k,text,opts)
   assert(S.GetUnitRulesParam(id,k)==text,'Exact private paid journal write refused')
  else S.SetUnitRulesParam(id,k,v,opts)end
 end
 function receiptSpring.GetUnitRulesParam(id,k)
  local value=S.GetUnitRulesParam(id,k)
  if money[k]and type(value)=='string'then
   local number=tonumber(value)
   if not finite(number)or number<0 or string.format('%.17g',number)~=value then return nil end
   return number
  end
  return value -- Legacy rounded numeric receipts remain strictly checked.
 end
 R=cohort.New(receiptSpring,F,P);A.controller=R
 function A.AllowCommand(id,def,team,cmd)return cmd~=Q.command or def==defID and R.Allow(id,team,cmd)end
 function A.CommandFallback(id,def,team,cmd,tag)if cmd~=Q.command then return false end;return R.Fallback(id,team,cmd,tag)end
 function A.UnitDamaged(id,damage,attacker)
  if finite(damage)and damage>0 then local f=S.GetGameFrame();if R.member[id]then A.combat[id]=f;put(id,'combat',f)end;if attacker and R.member[attacker]then A.combat[attacker]=f;put(attacker,'combat',f)end end
 end
 function A.UnitDestroyed(id)
  R.Remove(id);A.initial[id]=nil;A.births[id]=nil;A.combat[id]=nil;A.grants[id]=nil
  if S.GetUnitHealth(id)then local n=S.FindUnitCmdDesc(id,Q.command);if n then S.RemoveUnitCmdDesc(id,n)end end
 end
 A.UnitTransferred=A.UnitDestroyed
 function A.Frame()R.Frame();for _,c in pairs(R.cohorts)do describe(c.leader)end end
 function A.Snapshot()return{version=M.Version,source=stamp,cohorts=R.Snapshot(),grants=copy(A.grants),initial=copy(A.initial),combat=copy(A.combat)}end
 function A.Restore(s)
  if type(s)~='table'or s.version~=M.Version or s.source~=stamp or next(A.initial)or next(R.cohorts)then return false end
  -- Common Register may already call RestoreEnable on an owned completed HQ.
  -- Accept only an identical saved native receipt; never merge a fresh grant.
  for id,r in pairs(A.grants)do
   local saved=(s.grants or{})[id];if not saved then return false end
   for k,v in pairs(r)do if saved[k]~=v then return false end end
   for k,v in pairs(saved)do if r[k]~=v then return false end end
  end
  for id,r in pairs(s.grants or{})do
   if not producer(id,r.team)or r.def~=S.GetUnitDefID(id)or r.source~=stamp or r.frames~=90*fps or r.metal~=400 or r.energy~=130 or not integer(r.tag)then return false end
   for k,v in pairs(r)do if S.GetUnitRulesParam(id,prefix..'enable_'..k)~=v then return false end end
   if not C.sourceVariantAdapter.LocalAddon(id,r.team,key)then return false end
   -- Q.Applied may call the whole-manager IsApplied which requires this receipt.
   -- Verify after temporarily staging validated receipts below, never paid jobs.
  end
  for id,r in pairs(s.initial or{})do local _,_,_,_,built=S.GetUnitHealth(id)
   if r.def~=defID or not live(id,r.team,defID,false)or not built or built>=1 or not live(r.builder,r.team,nil,true)or entity(r.builder)~=norm(F.bike.source_producer)or not cost(id,170,30,30)
    or S.GetUnitRulesParam(id,prefix..'initial')~=stamp or S.GetUnitRulesParam(id,prefix..'initial_team')~=r.team or S.GetUnitRulesParam(id,prefix..'initial_builder')~=r.builder then return false end
  end
  for _,c in pairs((s.cohorts or{}).cohorts or{})do for id in pairs(c.members or{})do
   local initial=cost(id,170,30,30)and S.GetUnitRulesParam(id,prefix..'initial')==stamp and S.GetUnitRulesParam(id,prefix..'initial_team')==c.team
   local reinforced=cost(id,80,40,10)and S.GetUnitRulesParam(id,prefix..'paid_birth')==stamp and S.GetUnitRulesParam(id,prefix..'birth_team')==c.team
   if not initial and not reinforced then return false end
  end end
  for id,f in pairs(s.combat or{})do if not integer(id)or not integer(f)or f>S.GetGameFrame()or S.GetUnitRulesParam(id,prefix..'combat')~=f then return false end end
  A.grants=copy(s.grants);A.initial=copy(s.initial)
  for id,r in pairs(A.grants)do if not Q.Applied(r.team,key,id)then A.grants={};A.initial={};return false end end
  if not R.Restore(s.cohorts)then A.grants={};A.initial={};return false end
  A.combat=copy(s.combat);return true
 end
 C.sourceBikeNative=A;return A
end
return M
