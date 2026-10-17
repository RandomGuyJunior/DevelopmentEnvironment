-- Native adaptation: source minimum4 groups four ordinary factory-paid actors.
-- Each actual native actor pays its own source50M/0E/7s; no scripted creation.
local M={entity='attrib/ebps/races/orks/troops/ork_stormboy.lua',producer='attrib/ebps/races/orks/structures/ork_boy_hut.lua',squad='attrib/sbps/races/orks/ork_squad_stormboy.lua'}
function M.New(S,C,D,Q)
 for _,name in ipairs({'Ready','Verified','NativeCostContract','RestoreProof'})do assert(type(Q[name])=='function',name..' required')end
 local births,pending,receipts={},{},{};local R={}
 local function valid(id,def,team,path,finished)
  local a=C.units[id];local hp,_,_,_,built=S.GetUnitHealth(id)
  return S.GetUnitTeam(id)==team and S.GetUnitDefID(id)==def and ((D[def]or{}).customParams or{}).source_entity==path
   and Q.Verified(def,path)==true and hp and hp>0 and built and(not finished or built>=1 and a and a.finished and a.team==team and a.def==def)
 end
 function R.Created(id,def,team,builder)
  if Q.Ready()~=true or births[id]or not builder or not valid(id,def,team,M.entity,false)then return false end
  local producer=S.GetUnitDefID(builder);local head=(S.GetFactoryCommands(builder,-1)or{})[1]
  local _,_,_,_,built=S.GetUnitHealth(id);local time,metal,energy=S.GetUnitCosts(id)
  if not valid(builder,producer,team,M.producer,true)or built>=1 or S.GetUnitIsBuilding(builder)~=id
   or not head or head.id~=-def or type(head.tag)~='number'or head.tag<0 or head.tag%1~=0
   or metal~=50 or energy~=0 or Q.NativeCostContract(def,time,metal,energy,7)~=true then return false end
  births[id]={id=id,def=def,team=team,builder=builder,producer=producer,tag=head.tag,time=time,metal=metal,energy=energy};return true
 end
 function R.FromFactory(id,def,team,builder,single)
  local b=births[id];if not b or b.claimed or b.def~=def or b.team~=team or b.builder~=builder or Q.Ready()~=true
   or not valid(id,def,team,M.entity,true)or not valid(builder,b.producer,team,M.producer,true)then return false end
  local time,metal,energy=S.GetUnitCosts(id)
  if time~=b.time or metal~=b.metal or energy~=b.energy then return false end
  b.claimed=true
  if single then local token={};receipts[token]={team=team,ids={id},single=true};return true,token end
  local group=pending[builder];if not group or group.team~=team then group={team=team,ids={}};pending[builder]=group end
  -- Loss/capture of an earlier actor invalidates only that unformed candidate.
  local keep={};for _,prior in ipairs(group.ids)do local x=births[prior];if x and valid(prior,x.def,team,M.entity,true)then keep[#keep+1]=prior end end;group.ids=keep
  group.ids[#group.ids+1]=id
  if #group.ids<4 then return true end
  local ids=group.ids;local token={};local seed=ids[1]
  receipts[token]={team=team,seed=seed,ids=ids};pending[builder]=nil
  return true,token,seed,ids
 end
 function R.Claim(token,seed,team,ids,squad)
  local r=receipts[token]
  if not r or r.used or r.seed~=seed or r.team~=team or squad~=M.squad or type(ids)~='table'or #ids~=4 or Q.Ready()~=true then return false end
  for n,id in ipairs(ids)do local b=births[id]
   if r.ids[n]~=id or not b or not b.claimed or not valid(id,b.def,team,M.entity,true)then return false end
  end
  r.used=true;return true
 end
 function R.ClaimSingle(token,id,team)
  local r=receipts[token];local b=births[id]
  if not r or not r.single or r.used or r.team~=team or r.ids[1]~=id or not b or not b.claimed or not valid(id,b.def,team,M.entity,true)or Q.Ready()~=true then return false end
  r.used=true;return true
 end
 function R.Remove(id)
  births[id]=nil;pending[id]=nil
  for product,b in pairs(births)do if b.builder==id and not b.claimed then births[product]=nil end end
  for token,r in pairs(receipts)do for _,member in ipairs(r.ids)do if member==id then receipts[token]=nil;break end end end
 end
 function R.Snapshot()
  local out={version=1,births={},pending={}}
  for id,b in pairs(births)do local v={};for k,x in pairs(b)do v[k]=x end;out.births[id]=v end
  for id,p in pairs(pending)do local ids={};for n,x in ipairs(p.ids)do ids[n]=x end;out.pending[id]={team=p.team,ids=ids}end
  -- Completed/consumed tokens are not saveable authority; HQ cohort serializer
  -- restores already admitted squads from its separate completed paid receipt.
  return out
 end
 function R.Restore(snapshot,proof)
  if Q.Ready()~=true or type(snapshot)~='table'or snapshot.version~=1 or Q.RestoreProof(proof,snapshot)~=true then return false end
  local nb,np={},{}
  for id,b in pairs(snapshot.births or{})do
   if b.id~=id or b.metal~=50 or b.energy~=0 or not valid(id,b.def,b.team,M.entity,b.claimed==true)
    or not valid(b.builder,b.producer,b.team,M.producer,true)or Q.NativeCostContract(b.def,b.time,b.metal,b.energy,7)~=true then return false end
   local row={};for k,v in pairs(b)do row[k]=v end;nb[id]=row
  end
  local seen={}
  for builder,p in pairs(snapshot.pending or{})do
   if type(p.ids)~='table'or #p.ids>3 then return false end
   local ids={};for n,id in ipairs(p.ids)do local b=nb[id]
    if not b or not b.claimed or b.builder~=builder or b.team~=p.team or seen[id]then return false end;seen[id]=true;ids[n]=id end
   np[builder]={team=p.team,ids=ids}
  end
  births,pending,receipts=nb,np,{};return true
 end
 return R
end
return M
