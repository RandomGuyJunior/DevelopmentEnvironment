-- Deliberate vertical-hold adaptation, not recovered proprietary lifting physics.
-- Actual Shot arms; actual native damage starts motion. No scripted damage.
local M={};M.Tag=404110;M.Policy={rise=15,hold=30,release=15,height=64,hitWindow=8}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.New(S,defs,bindings,clear)
 assert(type(clear)=='function','Actual full-envelope clearance provider required')
 local C=S.MoveCtrl;assert(C and C.IsEnabled and C.Enable and C.Disable and C.SetTag and C.GetTag and C.SetPosition and C.SetVelocity and C.SetExtrapolate,'Native MoveCtrl unavailable')
 local A,arms,active={},{},{}
 local function live(id)return S.ValidUnitID(id)and not S.GetUnitIsDead(id)end
 local function own(id)return live(id)and C.IsEnabled(id)==true and C.GetTag(id)==M.Tag end
 local function release(id,why)
  active[id]=nil
  if own(id)then C.Disable(id)end
  return false,why
 end
 local function valid(r)
  if not live(r.caster)or not live(r.target)then return false,'destroyed'end
  if S.GetUnitTeam(r.caster)~=r.casterTeam or S.GetUnitTeam(r.target)~=r.targetTeam then return false,'capture'end
  if S.GetUnitTransporter(r.target)~=nil then return false,'transported'end
  local t,_,id=S.GetUnitWeaponTarget(r.caster,r.mount)
  if t~=1 or id~=r.target then return false,'target_changed'end
  return true
 end
 function A.Shot(caster,mount,frame)
  if not finite(frame)or frame<0 or frame~=math.floor(frame)then return false,'native_frame_required'end
  local b=live(caster)and bindings[S.GetUnitDefID(caster)]
  if not b or mount~=b.mount then return false,'not_lifta_mount'end
  local t,_,target=S.GetUnitWeaponTarget(caster,mount)
  if t~=1 or not live(target)then return false,'actual_unit_target_required'end
  arms[caster]={caster=caster,target=target,mount=mount,weapon=b.weapon,frame=frame,
   casterTeam=S.GetUnitTeam(caster),targetTeam=S.GetUnitTeam(target)}
  return true
 end
 function A.Hit(caster,target,weapon,damage,paralyzer,frame)
  if not finite(frame)or frame<0 or frame~=math.floor(frame)then return false,'native_frame_required'end
  local r=arms[caster]
  if not r or r.target~=target or r.weapon~=weapon or frame<r.frame or frame-r.frame>M.Policy.hitWindow or not finite(damage)or damage<=0 or paralyzer then return false,'unmatched_native_hit'end
  arms[caster]=nil -- one motion episode per real shot, never extra damage.
  local ok,why=valid(r);if not ok then return false,why end
  if S.AreTeamsAllied(r.casterTeam,r.targetTeam)then return false,'allied_target'end
  local d=defs[S.GetUnitDefID(target)]
  if not d or d.isBuilding or (not d.canFly and(not finite(d.speed)or d.speed<=0))then return false,'immobile_target'end
  if active[target]or C.IsEnabled(target)~=false then return false,'movement_already_owned'end
  local x,y,z=S.GetUnitPosition(target)
  if not finite(x)or not finite(y)or not finite(z)then return false,'native_position_unknown'end
  local checked,allowed=pcall(clear,target,x,y,z,x,y+M.Policy.height,z)
  if not checked or allowed~=true then return false,'lift_path_not_clear'end
  r.x,r.y,r.z,r.started=x,y,z,frame
  local enabled=false
  local setup,err=pcall(function()
   C.Enable(target);enabled=C.IsEnabled(target)==true;assert(enabled,'Native enable refused')
   C.SetTag(target,M.Tag);assert(C.GetTag(target)==M.Tag,'Native ownership tag refused')
   C.SetExtrapolate(target,false);C.SetVelocity(target,0,0,0)
  end)
  if not setup then if enabled and C.IsEnabled(target)then C.Disable(target)end;return false,'movement_setup_failed'end
  active[target]=r;return true,'native_lift_started'
 end
 function A.Frame(frame)
  local ids={};for id in pairs(active)do ids[#ids+1]=id end;table.sort(ids)
  for _,id in ipairs(ids)do
   local r=active[id];local ok,why=valid(r)
   if not own(id)then active[id]=nil
   elseif not ok then release(id,why)
   else
    local age=frame-r.started
    local total=M.Policy.rise+M.Policy.hold+M.Policy.release
    local amount=age<M.Policy.rise and age/M.Policy.rise or age<M.Policy.rise+M.Policy.hold and 1 or math.max(0,(total-age)/M.Policy.release)
    local y=r.y+M.Policy.height*amount
    local x0,y0,z0=S.GetUnitPosition(id)
    local moved,allowed=pcall(clear,id,x0,y0,z0,r.x,y,r.z)
    if not moved or allowed~=true then release(id,'motion_clearance_refused')
    else
     local placed=pcall(C.SetPosition,id,r.x,y,r.z)
     if not placed then release(id,'native_position_failed')elseif age>=total then release(id,'completed')end
    end
   end
  end
  for caster,r in pairs(arms)do if frame-r.frame>M.Policy.hitWindow or not live(caster)then arms[caster]=nil end end
 end
 function A.Cancel(caster)
  arms[caster]=nil
  local ids={};for id,r in pairs(active)do if r.caster==caster then ids[#ids+1]=id end end;table.sort(ids)
  for _,id in ipairs(ids)do release(id,'cancelled')end
 end
 function A.Removed(id)
  A.Cancel(id);if active[id]then release(id,'removed_or_captured')end
 end
 function A.Shutdown()
  local ids={};for id in pairs(active)do ids[#ids+1]=id end;table.sort(ids)
  for _,id in ipairs(ids)do release(id,'shutdown')end;arms={}
 end
 function A.CleanupOrphans()
  -- Save/reload deliberately cancels this adaptation; never steals other tags.
  for _,id in ipairs(S.GetAllUnits())do if own(id)and not active[id]then C.Disable(id)end end
 end
 function A.Active(id)return active[id]~=nil end
 return A
end
return M
