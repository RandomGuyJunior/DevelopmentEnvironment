function gadget:GetInfo() return {name='Infantry salvage piles',layer=10001,enabled=true} end
local function isPile(d) return FeatureDefs[d] and FeatureDefs[d].customParams.squad_salvage_pile end
if not gadgetHandler:IsSyncedCode() then
 local function mark(id,d) if isPile(d) then Spring.SetFeatureNoDraw(id,true) end end
 function gadget:Initialize() for _,id in ipairs(Spring.GetAllFeatures()) do mark(id,Spring.GetFeatureDefID(id)) end end
 function gadget:FeatureCreated(id) mark(id,Spring.GetFeatureDefID(id)) end
 return
end
local groups,owner={},{}
local dirty=true
local destroying={}
local pendingRemoval={}
local pendingReclaim={}
-- Native API: metal,maxMetal,energy,maxEnergy,reclaimLeft,reclaimTime.
local function resources(id)local m,_,e=Spring.GetFeatureResources(id);return m or 0,e or 0 end
local function metal(id)local m=resources(id);return m end
local function value(id)
 local g=owner[id] and groups[owner[id]]
 if not g then return metal(id) end
 return g.total>0 and metal(g.id)*(g.members[id] or 0)/g.total or 0
end
local function resource(id,m,e,scale)Spring.SetFeatureResources(id,m,e or 0,math.max(1,m*(scale or 10)),1,m,e or 0)end
local function energyValue(id)
 local g=owner[id]and groups[owner[id]]
 if not g then local _,e=resources(id);return e end
 local _,remaining=resources(g.id)
 return(g.energyTotal or 0)>0 and remaining*(g.memberEnergy[id]or 0)/g.energyTotal or 0
end
local function detach(id)
 local gid=owner[id];local g=gid and groups[gid]
 if not g then return end
 local left,leftEnergy=value(id),energyValue(id);local m,e=resources(gid)
 local remaining,remainingEnergy=math.max(0,m-left),math.max(0,e-leftEnergy)
 g.total=g.total-(g.members[id]or 0);g.energyTotal=math.max(0,(g.energyTotal or 0)-(g.memberEnergy[id]or 0))
 g.members[id]=nil;g.memberEnergy[id]=nil;owner[id]=nil
 if Spring.ValidFeatureID(id)then Spring.SetFeatureRulesParam(id,'squad_salvage_group',-1)end
 if next(g.members)then
  resource(gid,remaining,remainingEnergy,g.reclaimScale)
  Spring.SetFeatureRulesParam(gid,'squad_group_total',g.total);Spring.SetFeatureRulesParam(gid,'squad_group_energy_total',g.energyTotal)
 else
  groups[gid]=nil;destroying[gid]=true;Spring.DestroyFeature(gid);destroying[gid]=nil
 end
end
local function add(g,id)
 local amount,amountEnergy=resources(id);local remaining,remainingEnergy=resources(g.id)
 -- Rebase shares to ACTUAL unclaimed resources, never a full-death constant.
 for body,share in pairs(g.members)do
  share=g.total>0 and share*remaining/g.total or 0;g.members[body]=share
  local eshare=(g.energyTotal or 0)>0 and(g.memberEnergy[body]or 0)*remainingEnergy/g.energyTotal or 0;g.memberEnergy[body]=eshare
  Spring.SetFeatureRulesParam(body,'squad_group_share',share);Spring.SetFeatureRulesParam(body,'squad_group_energy_share',eshare)
 end
 g.total=remaining+amount;g.energyTotal=remainingEnergy+amountEnergy;g.members[id]=amount;g.memberEnergy[id]=amountEnergy;owner[id]=g.id
 Spring.SetFeatureRulesParam(id,'squad_salvage_group',g.id);Spring.SetFeatureRulesParam(id,'squad_group_share',amount);Spring.SetFeatureRulesParam(id,'squad_group_energy_share',amountEnergy)
 Spring.SetFeatureRulesParam(g.id,'squad_group_total',g.total);Spring.SetFeatureRulesParam(g.id,'squad_group_energy_total',g.energyTotal)
 Spring.SetFeatureRulesParam(g.id,'squad_group_resource_api',2)
 resource(id,0);resource(g.id,g.total,g.energyTotal,g.reclaimScale)
end
local function groupFeatures(list,x,z,team,feature,scale)
 local ids,unique={},{};local total,energy=0,0
 for _,id in ipairs(list)do if Spring.ValidFeatureID(id)and not unique[id]then
  if owner[id]or isPile(Spring.GetFeatureDefID(id))then return nil end
  unique[id]=true;ids[#ids+1]=id;local m,e=resources(id);total,energy=total+m,energy+e
 end end
 table.sort(ids)
 if #ids==0 then return 0 end
 if total<=0 and energy<=0 then
  -- Recovery of an already exhausted pool must not strand decorative remains.
  for _,id in ipairs(ids)do destroying[id]=true;Spring.DestroyFeature(id);destroying[id]=nil end
  return 0
 end
 -- The single hidden native feature owns ALL resources; visible pieces retain
 -- their exact positions and use the existing ordinary-reclaim alias path.
 local gid=Spring.CreateFeature(feature or 'squad_salvage_pile',x,Spring.GetGroundHeight(x,z),z,0,team or Spring.GetGaiaTeamID())
 if not gid then return nil end
 local g={id=gid,total=0,energyTotal=0,members={},memberEnergy={},reclaimScale=scale or 10,explicit=true};groups[gid]=g
 Spring.SetFeatureRulesParam(gid,'squad_group_reclaim_scale',g.reclaimScale);Spring.SetFeatureRulesParam(gid,'squad_group_explicit',1);resource(gid,0)
 for _,id in ipairs(ids)do add(g,id)end
 return gid
end
function gadget:Initialize()
 for _,id in ipairs(Spring.GetAllFeatures()) do
  if isPile(Spring.GetFeatureDefID(id)) then groups[id]={id=id,total=Spring.GetFeatureRulesParam(id,'squad_group_total')or 0,energyTotal=Spring.GetFeatureRulesParam(id,'squad_group_energy_total')or 0,reclaimScale=Spring.GetFeatureRulesParam(id,'squad_group_reclaim_scale')or 10,explicit=Spring.GetFeatureRulesParam(id,'squad_group_explicit')==1,members={},memberEnergy={}} end
 end
 for _,id in ipairs(Spring.GetAllFeatures()) do
  local gid=Spring.GetFeatureRulesParam(id,'squad_salvage_group')
  if groups[gid] then owner[id]=gid;groups[gid].members[id]=Spring.GetFeatureRulesParam(id,'squad_group_share')or 0;groups[gid].memberEnergy[id]=Spring.GetFeatureRulesParam(id,'squad_group_energy_share')or 0 end
 end
 -- Earlier builds mistook maxMetal(return2) for energy(return3). Repair only
 -- our legacy pools whose members are ALL natively zero-energy remains.
 -- Preserve current metal, maxMetal, worktime and partial reclaim exactly.
 for gid,g in pairs(groups)do
  if Spring.GetFeatureRulesParam(gid,'squad_group_resource_api')~=2 then
   local zeroEnergy=true
   for body in pairs(g.members)do
    local d=FeatureDefs[Spring.GetFeatureDefID(body)]
    if not d or(tonumber(d.energy)or 0)>0 then zeroEnergy=false;break end
   end
   if zeroEnergy then
    local m,maxM,_,_,left,time=Spring.GetFeatureResources(gid)
    if m then Spring.SetFeatureResources(gid,m,0,time,left,maxM,0)end
    g.energyTotal=0;Spring.SetFeatureRulesParam(gid,'squad_group_energy_total',0)
    for body in pairs(g.members)do g.memberEnergy[body]=0;Spring.SetFeatureRulesParam(body,'squad_group_energy_share',0)end
   end
   Spring.SetFeatureRulesParam(gid,'squad_group_resource_api',2)
  end
 end
 GG.SquadSalvageValue=value;GG.SquadSalvageDetach=detach;GG.SquadSalvageGroupFeatures=groupFeatures
end
function gadget:FeatureCreated() dirty=true end
function gadget:FeatureDestroyed(id)
 if destroying[id] then return end
 local g=groups[id]
 if g then
  groups[id]=nil
  for body in pairs(g.members) do owner[body]=nil;pendingRemoval[body]=true end
 elseif owner[id] then detach(id) end
 dirty=true
end
function gadget:AllowFeatureBuildStep(builder,team,id,def,part)
 if isPile(def) then return part<0 end
 if owner[id] then
  if part<0 then pendingReclaim[builder]={body=id,pile=owner[id]} end
  return false
 end
 return true
end
function gadget:GameFrame(f)
 -- Native area reclaim can choose a zero-resource decorative member. Redirect
 -- that attempt to its pile next frame, preserving the original area queue.
 for builder,r in pairs(pendingReclaim) do
  pendingReclaim[builder]=nil
  local command,_,_,target=Spring.GetUnitCurrentCommand(builder)
  if command==CMD.RECLAIM and target==r.body+Game.maxUnits and owner[r.body]==r.pile and groups[r.pile] then
   Spring.GiveOrderToUnit(builder,CMD.INSERT,{0,CMD.RECLAIM,CMD.OPT_INTERNAL,r.pile+Game.maxUnits},{'alt'})
  end
 end
 for body in pairs(pendingRemoval) do
  pendingRemoval[body]=nil;destroying[body]=true;if Spring.ValidFeatureID(body) then Spring.DestroyFeature(body) end;destroying[body]=nil
 end
 if f%90~=0 or not dirty then return end
 dirty=false
 local singles={}
 for _,id in ipairs(Spring.GetAllFeatures()) do
  local d=FeatureDefs[Spring.GetFeatureDefID(id)]
  if d and d.customParams.squad_remains and not d.customParams.squad_salvage_pile and not owner[id] and metal(id)>.001 then singles[#singles+1]=id end
 end
 table.sort(singles)
 local used={}
 local gids={};for gid in pairs(groups) do gids[#gids+1]=gid end;table.sort(gids)
 for _,gid in ipairs(gids) do
  local g=groups[gid];local n=0;for _ in pairs(g.members) do n=n+1 end
  local x,_,z=Spring.GetFeaturePosition(gid)
  for _,id in ipairs(singles) do if not g.explicit and n<10 and not used[id] then
   local bx,_,bz=Spring.GetFeaturePosition(id)
   if (bx-x)^2+(bz-z)^2<=32^2 then add(g,id);used[id]=true;n=n+1 end
  end end
 end
 for _,first in ipairs(singles) do if not used[first] then
  local x,_,z=Spring.GetFeaturePosition(first);local list={};local sx,sz=0,0
  for _,id in ipairs(singles) do if not used[id] and #list<10 then
   local bx,_,bz=Spring.GetFeaturePosition(id)
   if (bx-x)^2+(bz-z)^2<=32^2 then list[#list+1]=id;sx=sx+bx;sz=sz+bz end
  end end
  if #list>=5 then
   sx,sz=sx/#list,sz/#list
   local gid=Spring.CreateFeature('squad_salvage_pile',sx,Spring.GetGroundHeight(sx,sz),sz,0,Spring.GetGaiaTeamID())
   if gid then
    local g={id=gid,total=0,energyTotal=0,members={},memberEnergy={}};groups[gid]=g;resource(gid,0)
    for _,id in ipairs(list) do add(g,id);used[id]=true end
   end
  end
 end end
end
function gadget:Shutdown() GG.SquadSalvageValue=nil;GG.SquadSalvageDetach=nil;GG.SquadSalvageGroupFeatures=nil end
