-- One legitimate paid source banner at a time. No population/resource unlock writes.
local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function canonical(d)local c=d and d.customParams or{};return c.prototype40k_tech_requires or c.prototype40k_donor or(d and d.name)end
function M.Step(x)
 local S,D,t,C=x.Spring,x.UnitDefs,x.state,x.controller
 if x.enabled~=true or not t or t.faction~='Orks'then return false,'scope'end
 local A=C and C.sourceVariantAdapter;local P=C and C.sourceVariantPopulation
 local cfg=x.source;local team=x.team
 if not A or not P or type(P.Capacity)~='function'or not cfg or not cfg.ResearchConditions then return false,'source_unavailable'end
 local banner=A.Graph and A.Graph.Bindings and A.Graph.Bindings.ork_banner
 if not banner then return false,'source_binding'end
 local function live(id)return S.ValidUnitID(id)and not S.GetUnitIsDead(id)and S.GetUnitTeam(id)==team end
 local function finished(id)
  if not live(id)then return false end
  local hp,_,_,_,progress=S.GetUnitHealth(id)
  return finite(hp)and hp>0 and finite(progress)and progress>=1
 end
 local ids=S.GetTeamUnits(team);if type(ids)~='table'then return false,'membership_unknown'end
 table.sort(ids)
 local target
 local keys={};for key in pairs(C.records or{})do keys[#keys+1]=key end;table.sort(keys)
 for _,key in ipairs(keys)do
  local r=cfg.ResearchConditions[key];local record=C.records[key]
  if r and finite(r.population)and r.population>0 and not(C.suppressed or{})[key]
   and not C.HasResearch(team,key)and not((C.reserved or{})[team]or{})[key]then
   for _,id in ipairs(ids)do
    local u=C.units[id]
    if u and u.team==team and u.finished and u.name==record.producer and finished(id)then
     local okay,reason=A.Conditions(team,r,id)
     -- Read the existing exact source refusal, including addon/building/research
     -- ordering. Never infer population need when another prerequisite fails.
     if okay==false and reason=='population:'..r.population then
      if not target or r.population<target then target=r.population end
     end
    end
   end
  end
 end
 if not target then return false,'no_population_only_gate'end
 local cap=P.Capacity(team)
 if not finite(cap)or cap<0 then return false,'capacity_unknown'end
 if cap>=target then return false,'wait_for_source_growth'end
 if type(t.unfinished)~='table'or #t.unfinished>0 then return false,'unfinished_work'end
 local def,ownedCount
 ownedCount=0
 for id,d in pairs(D)do
  if canonical(d)==banner then if def then return false,'ambiguous_banner'end;def=id end
 end
 local d=def and D[def];local cp=d and d.customParams or{}
 if not d or cp.faction~='Orks'or tostring(cp.prototype40k)~='1'or not x.Ready(d)
  or (d.speed or 0)>0 then return false,'banner_unavailable'end
 for _,id in ipairs(ids)do
  if live(id)and S.GetUnitDefID(id)==def then
   ownedCount=ownedCount+1
   if not finished(id)then return false,'unfinished_banner'end
  end
 end
 -- Capture/death is counted through actual current ownership, never a cache.
 for _,builder in ipairs(t.constructors or{})do if live(builder)then
  local queue=S.GetUnitCommands(builder,-1)
  if type(queue)~='table'then return false,'queue_unknown'end
  for _,entry in ipairs(queue)do if entry.id==-def then return false,'queued_banner'end end
 end end
 local limit=d.maxThisUnit
 if not finite(limit)or limit<=0 or ownedCount>=limit then return false,'unitdef_limit'end
 if not S.GetTeamMaxUnits or not S.GetTeamUnitCount then return false,'team_limit_unknown'end
 local maximum,count=S.GetTeamMaxUnits(team),S.GetTeamUnitCount(team)
 if not finite(maximum)or not finite(count)or count>=maximum then return false,'team_limit'end
 for _,kind in ipairs({'metal','energy'})do
  local current,_,_,income,expense=S.GetTeamResources(team,kind)
  if not finite(current)or not finite(income)or not finite(expense)then return false,'resource_unknown'end
  -- Normal construction pays progressively. Positive stored stock or positive
  -- net income permits native charging; zero stock with no surplus refuses.
  if current<=0 and income<=expense then return false,'resource_starved:'..kind end
 end
 for _,builder in ipairs(t.constructors or{})do
  local bd=live(builder)and D[S.GetUnitDefID(builder)]
  if bd and bd.isBuilder and finished(builder)then
   local queue=S.GetUnitCommands(builder,1)
   if type(queue)=='table'and #queue==0 then
    local offered=false;for _,id in ipairs(bd.buildOptions or{})do if id==def then offered=true end end
    if offered and x.CanBuild(team,def,builder)==true then
     local p=x.Site(def)
     if type(p)=='table'and finite(p[1])and finite(p[2])and finite(p[3])and finite(p[4])then
      local result,feature=S.TestBuildOrder(def,p[1],p[2],p[3],p[4])
      if result==2 and not feature then
       if x.Witness then x.Witness.Before(builder,def,p)end
       local nativeReturn=S.GiveOrderToUnit(builder,-def,p,{})
       if x.Witness then x.Witness.After(builder,def,p,nativeReturn)end
       local head=S.GetUnitCommands(builder,1);head=head and head[1]
       local queued=head and head.id==-def
       if x.Log then x.Log('40K AI PAID BANNER',team,banner,'capacity',cap,'population_target',target,'builder',builder,'frame',x.frame,'nativeReturn',tostring(nativeReturn),'head',head and head.id or 'none','tag',head and head.tag or 'none')end
       if nativeReturn~=false and queued then return true,'native_queue_observed'end
       return false,'native_queue_unconfirmed'
      end
     end
    end
   end
  end
 end
 return false,'no_idle_owned_source_builder_or_site'
end
return M
