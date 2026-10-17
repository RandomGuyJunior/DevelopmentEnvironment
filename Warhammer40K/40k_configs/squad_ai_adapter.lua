-- AI-facing real-body accounting. Native commands/controller retain authority.
local M={}
local function sorted(t)local a={};for k in pairs(t)do a[#a+1]=k end;table.sort(a);return a end
function M.New(S,defs,cmd,runtime,transport)
 local A={}
 function A.HasSquad(seed,team)local R=runtime();local s=R and R.squads[seed];return s and s.team==team or false end
 local function live(id,team)return id and S.ValidUnitID(id)and not S.GetUnitIsDead(id)
  and S.GetUnitTeam(id)==team and not S.GetUnitTransporter(id)end
 function A.Describe(id,team,seed)
  local R=runtime();local s=R and(seed and R.squads[seed]or R.Get(id))
  if s then
   if s.team~=team or not live(s.leader,team)then return end
   local count=0;local T=transport and transport()
   for _,body in pairs(s.slots)do
    -- A partially held/reserved mob stays intact; never launch remaining bodies.
    if not live(body,team)or(T and T.Busy(body))then return end
    count=count+1
   end
   if count>0 then return{leader=s.leader,seed=s.id,bodies=count}end
  elseif not seed and live(id,team)then
   local d=defs[S.GetUnitDefID(id)];local c=d and d.customParams or{}
   -- Synchronous internal UnitFinished can precede runtime membership binding.
   if c.prototype40k_squad_internal or c.prototype40k_squad_product then return end
   return{leader=id,bodies=1}
  end
 end
 function A.Collect(team,t,stage)
  t.squadWaiting=t.squadWaiting or{};t.squadReleased=t.squadReleased or{};t.aiStaged=t.aiStaged or{}
  local ordinary={};local R=runtime()
  for _,id in ipairs(t.waiting or{})do
   local s=R and R.Get(id)
   if s then if not t.squadReleased[s.id]then t.squadWaiting[s.id]=true end
   elseif live(id,team)then ordinary[id]=true end
  end
  local reps={};local total=0
  for _,seed in ipairs(sorted(t.squadWaiting))do
   local s=R and R.squads[seed]
   if not s or s.team~=team then t.squadWaiting[seed]=nil
   else
    local row=A.Describe(nil,team,seed)
    if row then
     reps[#reps+1]=row.leader;total=total+row.bodies
     if not t.aiStaged['s'..seed]then t.aiStaged['s'..seed]=true;stage(row.leader,#reps)end
    end
   end
  end
  for _,id in ipairs(sorted(ordinary))do
   local row=A.Describe(id,team)
   if row then reps[#reps+1]=id;total=total+1
    if not t.aiStaged['u'..id]then t.aiStaged['u'..id]=true;stage(id,#reps)end
   end
  end
  t.waiting=reps;return total
 end
 function A.Wave(team,t,limit)
  local orders={};local bodies=0;local keep={}
  for _,id in ipairs(t.waiting)do local row=A.Describe(id,team)
   if row then
    if bodies+row.bodies<=limit then
     orders[#orders+1]=row.leader;bodies=bodies+row.bodies
     if row.seed then t.squadWaiting[row.seed]=nil;t.squadReleased[row.seed]=true end
    else keep[#keep+1]=id end
   end
  end
  t.waiting=keep;return orders,bodies
 end
 function A.Repair(team,constructors)
  local R=runtime();if not R then return false end
  local busyTargets={};local queues={}
  local function integer(v)return type(v)=='number'and v==v and math.abs(v)<math.huge and v%1==0 end
  for _,builder in ipairs(constructors)do
   if live(builder,team)then
    -- Unknown queues never establish idle state. Read the full native queue
    -- once so repairs behind movement/construction retain their reservation.
    local queue=S.GetUnitCommands(builder,-1)
    if type(queue)~='table'then return false end
    local count=0
    for index,order in pairs(queue)do
     if not integer(index)or index<1 or type(order)~='table'or not integer(order.id)
      or(order.params~=nil and type(order.params)~='table')then return false end
     count=count+1
    end
    for index=1,count do
     local order=queue[index];if not order then return false end
     if order.id==cmd.REPAIR or order.id==34591 then
      local target=order.params and order.params[1]
      if not integer(target)or target<0 or(order.id==34591 and target==0)then return false end
      if order.id==cmd.REPAIR then
       local s=R.Get(target);if s then busyTargets[s.id]=true end
      else busyTargets[target]=true end
     end
    end
    queues[builder]=queue
   end
  end
  for _,seed in ipairs(sorted(R.squads))do
   local s=R.squads[seed];local row=s.team==team and A.Describe(nil,team,seed)
   if row and not busyTargets[seed]and R.NeedsRepair(row.leader)then
    for _,builder in ipairs(constructors)do
     local d=defs[S.GetUnitDefID(builder)]
     if live(builder,team)and d and d.isBuilder and not d.isFactory and(d.speed or 0)>0
      and(d.buildSpeed or 0)>0 and queues[builder]and #queues[builder]==0 then
      -- Native REPAIR redirects through the actual paid squad gadget.
      return S.GiveOrderToUnit(builder,cmd.REPAIR,{row.leader},{})~=false
     end
    end
   end
  end
  return false
 end
 return A
end
return M
