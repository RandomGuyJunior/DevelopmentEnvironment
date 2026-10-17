-- Provisional v1.3 arrival arrangement over the existing paid real-body owner.
-- Native MOVE queues/pathfinding remain authoritative during travel. No model
-- getters, new MoveDefs, per-frame updates, logical-slot changes or teleports.
local M={Version=1}
-- r55 observed native bounds, rounded up with two world units of clearance.
-- SBOT2's actual 24-unit pair envelope is the floor, not UnitDef footprint1.
-- Width/depth include carried equipment. Remeasure these rows after rescaling.
M.Bodies={
 ork_boy={model='ork_boy.glb',width=17,depth=21},
 ork_slugga={model='ork_slugga.glb',width=16,depth=17},
 ork_tankbusta={model='ork_tankbusta.glb',width=16,depth=21},
 ork_burna={model='ork_burna.glb',width=16,depth=25},
 ork_nob={model='ork_nob.glb',width=15,depth=19},
 ork_loota={model='ork_loota.glb',width=25,depth=33},
 meganob={model='meganob.glb',width=28,depth=27},
}
M.Profiles={ork_shoota=true,ork_slugga=true,ork_tankbusta=true,
 ork_burna=true,ork_nob=true,ork_loota=true,ork_meganob=true}
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
function M.Body(d)
 local c=d and d.customParams or{};local row=M.Bodies[c.animsource]
 if not row or c.faction~='Orks'or d.modelname~=row.model
  or(c.scale_pilot_factor~=nil and tonumber(c.scale_pilot_factor)~=1)then return end
 return row
end
-- Dense ranks are only spatial: missing paid logical slots keep their identity.
function M.Offsets(count,columns,lateral,longitudinal)
 local offsets={}
 for rank=1,count do
  local index=rank-1;local row=math.floor(index/columns);local column=index%columns
  -- Keep the actual surviving leader at the origin in every shape.
  local side=column==0 and 0 or(column%2==1 and -math.ceil(column/2)or math.ceil(column/2))
  offsets[rank]={side*lateral,-row*longitudinal}
 end
 return offsets
end
function M.New(P)
 local records={};local F={}
 local function members(s)
  if not M.Profiles[s.profile]then return end
  local ids=P.Members(s.leader);local lateral,longitudinal=26,26
  for _,id in ipairs(ids)do
   local row=M.Body(P.Definition(id));if not row then return end
   lateral=math.max(lateral,row.width+2);longitudinal=math.max(longitudinal,row.depth+2)
  end
  if #ids<1 or #ids>8 or ids[1]~=s.leader then return end
  return ids,lateral,longitudinal
 end
 local function signature(ids)return table.concat(ids,':')end
 local function settle(s)
  local r=records[s.id];if not r or r.running then return end
  local ids,lateral,longitudinal=members(s);if not ids then records[s.id]=nil;return end
  local sig=signature(ids);if r.settled==sig then return end
  -- Do not touch active commands, combat orders, jumps, cargo or paid repair.
  for _,id in ipairs(ids)do if not P.Idle(id)then return end end
  local x,y,z=P.Position(s.leader);if not finite(x)or not finite(y)or not finite(z)then return end
  -- An idle callback may be failed/unreachable movement, not arrival.
  if(x-r.x)^2+(z-r.z)^2>lateral^2+longitudinal^2 then records[s.id]=nil;return end
  local chosen
  for columns=math.min(3,#ids),1,-1 do
   local offsets=M.Offsets(#ids,columns,lateral,longitudinal);local plan={};local clear=true
   for rank,id in ipairs(ids)do
    local off=offsets[rank];local px=x+r.dz*off[1]+r.dx*off[2];local pz=z-r.dx*off[1]+r.dz*off[2]
    local py=P.Ground(px,pz);local cx,_,cz=P.Position(id)
    local stay=finite(cx)and finite(cz)and(cx-px)^2+(cz-pz)^2<=4
    if not finite(py)or(rank>1 and not stay and not P.Clear(id,px,py,pz))then clear=false;break end
    plan[rank]={id=id,x=px,y=py,z=pz,stay=stay or rank==1}
   end
   if clear then chosen=plan;break end
  end
  -- One bounded attempt per arrival/membership state. No retry polling or
  -- moving bodies through a denied site to satisfy an abstract formation.
  r.settled=sig
  if not chosen then return end
  r.running=true
  for _,p in ipairs(chosen)do if not p.stay then P.Move(p.id,{p.x,p.y,p.z})end end
  r.running=false
 end
 function F.Command(s,cmd,params)
  if not s or not M.Profiles[s.profile]then return end
  if cmd~=P.MOVE then
   if not P.StateCommand(cmd)then records[s.id]=nil end
   return
  end
  if #params~=3 or not finite(params[1])or not finite(params[2])or not finite(params[3])then records[s.id]=nil;return end
  local ids=members(s);if not ids then records[s.id]=nil;return end
  local x,_,z=P.Position(s.leader);if not finite(x)or not finite(z)then return end
  local dx,dz=params[1]-x,params[3]-z;local length=math.sqrt(dx*dx+dz*dz)
  if length<.001 then dx,dz=0,1 else dx,dz=dx/length,dz/length end
  records[s.id]={x=params[1],z=params[3],dx=dx,dz=dz}
 end
 function F.Idle(s)if s then settle(s)end end
 function F.Changed(s)if s then settle(s)end end
 function F.Forget(seed)records[seed]=nil end
 return F
end
return M
