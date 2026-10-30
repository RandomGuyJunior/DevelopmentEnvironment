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
local function metal(id) return Spring.GetFeatureResources(id) or 0 end
local function value(id)
 local g=owner[id] and groups[owner[id]]
 if not g then return metal(id) end
 return g.total>0 and metal(g.id)*(g.members[id] or 0)/g.total or 0
end
local function resource(id,m) Spring.SetFeatureResources(id,m,0,math.max(1,m*10),1,m,0) end
local function detach(id)
 local gid=owner[id];local g=gid and groups[gid]
 if not g then return end
 local left=value(id);local remaining=math.max(0,metal(gid)-left)
 g.total=g.total-(g.members[id] or 0);g.members[id]=nil;owner[id]=nil
 if Spring.ValidFeatureID(id) then Spring.SetFeatureRulesParam(id,'squad_salvage_group',-1) end
 if next(g.members) then
  resource(gid,remaining);Spring.SetFeatureRulesParam(gid,'squad_group_total',g.total)
 else
  groups[gid]=nil;destroying[gid]=true;Spring.DestroyFeature(gid);destroying[gid]=nil
 end
end
local function add(g,id)
 local amount=metal(id);local remaining=metal(g.id)
 -- Rebase existing shares to their unclaimed values before adding a body.
 for body,share in pairs(g.members) do
  share=g.total>0 and share*remaining/g.total or 0;g.members[body]=share
  Spring.SetFeatureRulesParam(body,'squad_group_share',share)
 end
 g.total=remaining+amount;g.members[id]=amount;owner[id]=g.id
 Spring.SetFeatureRulesParam(id,'squad_salvage_group',g.id)
 Spring.SetFeatureRulesParam(id,'squad_group_share',amount)
 Spring.SetFeatureRulesParam(g.id,'squad_group_total',g.total)
 resource(id,0);resource(g.id,g.total)
end
function gadget:Initialize()
 for _,id in ipairs(Spring.GetAllFeatures()) do
  if isPile(Spring.GetFeatureDefID(id)) then groups[id]={id=id,total=Spring.GetFeatureRulesParam(id,'squad_group_total') or 0,members={}} end
 end
 for _,id in ipairs(Spring.GetAllFeatures()) do
  local gid=Spring.GetFeatureRulesParam(id,'squad_salvage_group')
  if groups[gid] then owner[id]=gid;groups[gid].members[id]=Spring.GetFeatureRulesParam(id,'squad_group_share') or 0 end
 end
 GG.SquadSalvageValue=value;GG.SquadSalvageDetach=detach
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
  for _,id in ipairs(singles) do if n<10 and not used[id] then
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
    local g={id=gid,total=0,members={}};groups[gid]=g;resource(gid,0)
    for _,id in ipairs(list) do add(g,id);used[id]=true end
   end
  end
 end end
end
function gadget:Shutdown() GG.SquadSalvageValue=nil;GG.SquadSalvageDetach=nil end
