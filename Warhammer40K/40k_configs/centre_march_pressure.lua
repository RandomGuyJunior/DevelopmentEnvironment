-- Ordinary SourcePaidMatch pressure; default Centre March remains unchanged.
local M={}
function M.Enabled(o)return tostring(o.prototype_source_paid_match)=='1' and VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression) and o.prototype_diagnostic=='expandedproduction'end
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
function M.New(S,defs,game,cmd,eligible,log,squadAI)
 local C={teams={}}
 local function alive(id,team)return S.ValidUnitID(id) and not S.GetUnitIsDead(id) and S.GetUnitTeam(id)==team and eligible(defs[S.GetUnitDefID(id)])end
 local function opponents(team)
  local out={};for _,t in ipairs(S.GetTeamList())do
   local _,_,dead=S.GetTeamInfo(t,false)
   if t~=team and t~=S.GetGaiaTeamID() and not dead and not S.AreTeamsAllied(team,t)then out[#out+1]=t end
  end;table.sort(out);return out
 end
 local function point(x,z)
  if not finite(x) or not finite(z)then return end
  x=math.max(64,math.min(game.mapSizeX-64,x));z=math.max(64,math.min(game.mapSizeZ-64,z))
  return {x,S.GetGroundHeight(x,z),z}
 end
 local function visible(team)
  local out={};local ally=select(6,S.GetTeamInfo(team,false))
  for _,other in ipairs(opponents(team))do
   local list=S.GetTeamUnits(other) or {};table.sort(list)
   for _,id in ipairs(list)do
    -- Synced IDs are enumeration only. No hidden definition/position reads.
    local los=S.GetUnitLosState(id,ally,false)
    if los and (los.los==true or los.los==1) and S.ValidUnitID(id) and not S.GetUnitIsDead(id)then
     local d=defs[S.GetUnitDefID(id)];local x,_,z=S.GetUnitPosition(id);local p=point(x,z)
     if d and p then
      local cp=d.customParams or{};local rank=(cp.iscommander or cp.prototype40k_vital=='commander')and 0 or (d.speed or 0)==0 and 1 or 2
      out[#out+1]={id=id,p=p,rank=rank}
     end
    end
   end
  end
  return out
 end
 function C.Release(team,id,rally,frame)
  if not alive(id,team)then return false end
  local row=squadAI and squadAI.Describe(id,team)
  if squadAI and not row then return false end
  id=row and row.leader or id
  local t=C.teams[team]or{};C.teams[team]=t;t[id]={phase='centre',rally=rally,last=frame,scout=0,squadSeed=row and row.seed};return true
 end
 function C.Frame(team,frame)
  local t=C.teams[team];if not t then return end
  -- Keep pressure state attached to logical membership after leader succession.
  -- A temporarily transported/reserved cohort remains paused, not forgotten.
  local paused={}
  if squadAI then
   local previous={};for id in pairs(t)do previous[#previous+1]=id end;table.sort(previous)
   for _,id in ipairs(previous)do local state=t[id]
    if state.squadSeed then
     local row=squadAI.Describe(nil,team,state.squadSeed)
     if row and row.leader~=id then t[id]=nil;t[row.leader]=state
     elseif not row then
      if not squadAI.HasSquad(state.squadSeed,team)then t[id]=nil else paused[id]=true end
     end
    end
   end
  end
  local seen=visible(team);local enemy=opponents(team);local starts={}
  for _,other in ipairs(enemy)do
   -- Documented AI knowledge: public engine setup start positions, not live bases.
   local x,_,z=S.GetTeamStartPosition(other)
   if finite(x)and finite(z)and x>=0 and z>=0 then starts[#starts+1]={team=other,p=point(x,z)}end
  end
  local ids={};for id in pairs(t)do ids[#ids+1]=id end;table.sort(ids)
  for _,id in ipairs(ids)do
   local state=t[id]
   if paused[id]then -- No individual orders while any cohort body is held.
   elseif not alive(id,team)then t[id]=nil
   else
    local x,_,z=S.GetUnitPosition(id)
    local orders=S.GetUnitCommands(id,1)or{};local current=orders[1]
    if finite(x)and finite(z)and (not current or current.id==cmd.FIGHT)then
     local dist=(x-state.rally[1])^2+(z-state.rally[3])^2
     if state.phase=='centre' and (dist<=192^2 or not current)then state.phase='pressure';state.last=frame-20*game.gameSpeed end
     if state.phase=='pressure'and frame-state.last>=20*game.gameSpeed then
      local best,metric
      for _,v in ipairs(seen)do
       local score=v.rank*game.mapSizeX*game.mapSizeX*4+(x-v.p[1])^2+(z-v.p[3])^2
       if not metric or score<metric or score==metric and v.id<best.id then best,metric=v,score end
      end
      local dest,kind
      if best then dest,kind=best.p,'visible-enemy-asset'
      else
       if not state.goal or (x-state.goal[1])^2+(z-state.goal[3])^2<=128^2 or not current then
        state.scout=state.scout+1
        if state.scout==1 and #starts>0 then
         local selected=starts[1];for _,s in ipairs(starts)do if (x-s.p[1])^2+(z-s.p[3])^2<(x-selected.p[1])^2+(z-selected.p[3])^2 then selected=s end end
         state.goal=selected.p;state.kind='public-start-scout'
        else
         -- Public terrain sweep can discover dispersed survivors normally.
         local nx=math.max(1,math.ceil((game.mapSizeX-128)/384));local nz=math.max(1,math.ceil((game.mapSizeZ-128)/384))
         local index=(state.scout-2+id*17)%(nx*nz)
         state.goal=point(64+(index%nx)*384,64+math.floor(index/nx)*384);state.kind='public-map-scout'
        end
       end
       dest,kind=state.goal,state.kind
      end
      if dest then
       -- Ordinary FIGHT pathing/LOS/weapons decide movement and damage.
       S.GiveOrderToUnit(id,cmd.FIGHT,dest,{})
       state.last=frame;log('40K AI PRESSURE',team,id,kind,frame,dest[1],dest[3])
      end
     end
    end
   end
  end
 end
 return C
end
return M
