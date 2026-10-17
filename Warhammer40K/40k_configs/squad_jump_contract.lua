-- Source interface readiness, not a native acceptance certificate.
local M={Version=1,Command=34573}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function M.SupportsFixedSquad(id,capacity,product,member)
 return id==14 and capacity==4 and product=='imp_assault_marine'and member=='imp_assault_marine_member'
end
function M.New(H)
 for _,name in ipairs({'Squad','Live','Position','Head','Charge','Prepare','PairSafe','Commit','Active'})do assert(type(H[name])=='function','Missing genuine squad jump owner '..name)end
 local R={groups={},member={}}
 local function members(s)
  local out={};for slot=1,4 do local id=s.slots[slot];if id then out[#out+1]=id end end;return out
 end
 local function release(seed)
  local g=R.groups[seed];if not g then return end
  for _,id in ipairs(g.ids)do R.member[id]=nil end;R.groups[seed]=nil
 end
 function R.Busy(id)return R.member[id]~=nil end
 function R.Start(id,params,tag,frame)
  local s=H.Squad(id);if not s or s.profile~='marine_assault'then return false end
  if R.groups[s.id]then return nil end
  local ids=members(s);if #ids==0 then return false end
  -- Native fallback iteration may reach a member before its current leader.
  -- The stock command destination still refers to the leader's squad anchor.
  local ax,ay,az=H.Position(s.leader or ids[1])
  if not finite(ax)or not finite(ay)or not finite(az)or type(params)~='table'
   or not finite(params[1])or not finite(params[2])or not finite(params[3])then return false end
  local plans,heads={},{}
  -- No charge/motion mutation until every living real body and complete route
  -- passes. Missing slots remain missing; native per-body charges are retained.
  for _,body in ipairs(ids)do
   if not H.Live(body,s.team)or R.member[body]then return false end
   local x,y,z=H.Position(body);if not finite(x)or not finite(y)or not finite(z)then return false end
   local plan=H.Prepare(body,{params[1]+x-ax,params[2],params[3]+z-az})
   if not plan then return false end
   local cmd,head=H.Head(body);if cmd~=M.Command or not head then return nil end
   plans[body]=plan;heads[body]=head
  end
  if not H.PairSafe(ids,plans)then return false end
  for _,body in ipairs(ids)do local charge=H.Charge(body);if not finite(charge)then return false end;if charge<plans[body].config.cost then return nil end end
  local g={seed=s.id,team=s.team,profile=s.profile,ids=ids,heads=heads,finished={}}
  -- One synced commit to the existing native owner. All readiness above is
  -- read-only; Begin preserves native charge, MoveCtrl and damage authority.
  R.groups[s.id]=g;for _,body in ipairs(ids)do R.member[body]=s.id;plans[body].assaultGroup=s.id end
  H.Commit(ids,plans,heads,frame)
  return true
 end
 function R.Valid(state)
  local g=R.groups[state.assaultGroup];if not g or g.aborted then return false end
  local current
  for _,id in ipairs(g.ids)do if not g.finished[id]then
   if not H.Live(id,g.team)then g.aborted=true;return false end
   current=current or H.Squad(id)
   local cmd,tag=H.Head(id)
   if not H.Active(id)or cmd~=M.Command or tag~=g.heads[id]then g.aborted=true;return false end
  end end
  if not current or current.id~=g.seed or current.profile~=g.profile or current.team~=g.team then g.aborted=true;return false end
  for _,id in ipairs(members(current))do if R.member[id]~=g.seed then g.aborted=true;return false end end
  return true
 end
 function R.Finished(id,state)
  local g=R.groups[state.assaultGroup];if not g then return end;g.finished[id]=true
  for _,body in ipairs(g.ids)do if not g.finished[body]then return end end;release(g.seed)
 end
 function R.Removed(id)
  local seed=R.member[id];local g=seed and R.groups[seed];if not g then return end
  -- Ordinary death is an individual casualty, never a free replacement or an
  -- automatic wipe of survivors. Native/squad owners handle real destruction.
  g.finished[id]=true;R.member[id]=nil
  for _,body in ipairs(g.ids)do if not g.finished[body]then return end end;release(seed)
 end
 function R.Cancel(id)local seed=R.member[id];if seed and R.groups[seed]then R.groups[seed].aborted=true end end
 function R.Quiescent()return next(R.groups)==nil end
 return R
end
return M
