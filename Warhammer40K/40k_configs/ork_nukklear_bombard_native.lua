-- Paid targeted native projectile adaptation. No health/resource/prerequisite grants.
local M={Version=1,Command=34991,Rule='40k_nukklear_bombard_v1'}
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function sorted(t)local r={};for k in pairs(t)do r[#r+1]=k end;table.sort(r);return r end
function M.New(S,D,W,F,Codec,GetController,game)
 local R={};local states,hits={},{};local fps=assert(game.gameSpeed);local fact=assert(F.ork_nuke_bomba);local a=assert(fact.bombard);local enabled=false
 local projectileRule=M.Rule..'_projectiles';local targetsRule=M.Rule..'_targets';local targets={};local weapon=assert(W.ork_nuke_bomba_bombard).id
 local logs={}
 local function emit(kind,id,...)
  if enabled and S.Echo and(logs[id]or 0)<32 then logs[id]=(logs[id]or 0)+1;S.Echo('40K NUKKLEAR NATIVE',kind,id,...)end
 end
 local function genuine(id,team)
  local def=S.GetUnitDefID(id);local d=D[def];local cp=d and d.customParams or{}
  if not enabled or not d or d.name~='ork_nuke_bomba'or cp.faction~='Orks'or tostring(cp.prototype40k)~='1'or tostring(cp.prototype40k_ork_aircraft_review)~='1'or cp.source_entity~=fact.source_entity or cp.source_model_sha256~=fact.source_model_sha256 then return false end
  if S.GetUnitTeam(id)~=team then return false end
  local hp,_,_,_,build=S.GetUnitHealth(id);if not hp or hp<=0 or build~=1 or S.GetUnitIsDead(id)then return false end
  local C=GetController();local u=C and C.units[id];return u and u.finished and u.team==team and u.name=='ork_nuke_bomba',def
 end
 local function save(id)local s=states[id];if s then S.SetUnitRulesParam(id,M.Rule,Codec.Encode(s),{private=true})end end
 local function saveGlobal()S.SetGameRulesParam(projectileRule,Codec.Encode({version=M.Version,source=a.sha256,rows=hits}),{private=true});S.SetGameRulesParam(targetsRule,Codec.Encode({version=M.Version,source=a.sha256,rows=targets}),{private=true})end
 local function decode(raw)
  if raw==nil then return {}end;local ok,v=pcall(Codec.Decode,raw);if not ok or type(v)~='table'then return nil end;return v
 end
 local function cancel(id,reason)
  local st=states[id];if not st or st.phase~='pending'then return false end
  st.phase='cancelled';st.reason=reason;save(id);emit('cancel',id,reason,st.team,st.paid,st.cooldown);return true
 end
 function R.Start(active)
  enabled=active==true;if not enabled then return true end
  if a.fire_metal~=1750 or a.fire_energy~=8750 or a.recharge~=600 or a.range~=800 or math.abs(a.duration-3.3)>.00001 or a.delay~=.5 or a.degeneration~=2 or a.degeneration_seconds~=5 then enabled=false;return false,'source_bombard_contract_changed'end
  for _,name in ipairs({'UseTeamResource','SpawnProjectile','GetUnitPiecePosDir','GetUnitPieceMap','GetUnitHealth','GetUnitIsStunned','GetUnitIsDead','GetUnitTeam','GetUnitDefID','GetUnitPosition','SetUnitRulesParam','GetUnitRulesParam','GetGameRulesParam','SetGameRulesParam','GetGroundHeight','AddUnitDamage','GetAllUnits','GetProjectilePosition','IsPosInLos','GetUnitAllyTeam'})do if not S[name]then enabled=false;return false,'native_API:'..name end end
  local savedHits=decode(S.GetGameRulesParam(projectileRule));local savedTargets=decode(S.GetGameRulesParam(targetsRule));if not savedHits or not savedTargets then enabled=false;return false,'saved_bombard_receipt_invalid'end
  for _,receipt in ipairs({savedHits,savedTargets})do if next(receipt)and(receipt.version~=M.Version or receipt.source~=a.sha256 or type(receipt.rows)~='table')then enabled=false;return false,'saved_bombard_source_changed'end end
  hits=savedHits.rows or{};targets=savedTargets.rows or{}
  for pid,h in pairs(hits)do if not finite(pid)or type(h)~='table'or not finite(h.owner)or not finite(h.team)or not finite(h.expiry)then enabled=false;return false,'saved_projectile_invalid'end end
  for id,t in pairs(targets)do if not finite(id)or type(t)~='table'or not finite(t.owner)or not finite(t.projectile)or not finite(t.expiry)or not finite(t.next)then enabled=false;return false,'saved_damage_target_invalid'end end
  for _,id in ipairs(S.GetAllUnits())do local raw=S.GetUnitRulesParam(id,M.Rule);if raw then local st=decode(raw);if not st or st.version~=M.Version or st.source_sha256~=a.sha256 or st.def~=S.GetUnitDefID(id)or not finite(st.cooldown)or not finite(st.busy)or not finite(st.team)or(st.phase~='pending'and st.phase~='fired'and st.phase~='cancelled')or type(st.target)~='table'or not finite(st.target[1])or not finite(st.target[2])or not finite(st.target[3])or not finite(st.launch)then enabled=false;return false,'saved_actor_receipt_invalid'end;states[id]=st end end
  return true
 end
 function R.Request(id,team,p,frame)
  local okay,def=genuine(id,team);if not okay then return false,'actor_or_finished_source_controller'end
  local C=GetController();if C.commands and C.commands[M.Command]then return false,'command_collision'end
  if S.GetUnitIsStunned(id)then return false,'stunned'end
  if type(p)~='table'or #p~=3 or not finite(p[1])or not finite(p[2])or not finite(p[3])or p[1]<0 or p[3]<0 or p[1]>game.mapSizeX or p[3]>game.mapSizeZ then return false,'ground_target'end
  local st=states[id];if st and(frame<st.cooldown or st.phase=='pending'or frame<(st.busy or 0))then return false,'cooldown_or_busy'end
  local x,_,z=S.GetUnitPosition(id);if not x or(p[1]-x)^2+(p[3]-z)^2>a.range^2 then return false,'range'end
  local map=S.GetUnitPieceMap(id);if not map or not map.fb_fx_bomb_bay then return false,'actual_bomb_bay_missing'end
  if not S.UseTeamResource(team,{metal=a.fire_metal,energy=a.fire_energy})then return false,'starved'end
  states[id]={version=M.Version,source_sha256=a.sha256,def=def,team=team,phase='pending',paid=true,start=frame,launch=frame+math.ceil(a.delay*fps),busy=frame+math.ceil(a.duration*fps),cooldown=frame+math.ceil(a.recharge*fps),target={p[1],S.GetGroundHeight(p[1],p[3]),p[3]}}
  save(id);emit('paid_pending',id,team,frame,a.fire_metal,a.fire_energy,states[id].launch,states[id].busy,states[id].cooldown);return true
 end
 function R.Cancel(id)return cancel(id,'ordinary_stop')end
 function R.Transferred(id)cancel(id,'capture')end
 function R.Removed(id)states[id]=nil;targets[id]=nil;if enabled then saveGlobal()end end
 function R.Frame(frame)
  if not enabled then return end
  for _,id in ipairs(sorted(states))do local st=states[id]
   if st.phase=='pending'then
    if not genuine(id,st.team)then cancel(id,'actor_changed')
    elseif S.GetUnitIsStunned(id)then cancel(id,'stunned')
    elseif frame>=st.launch then
     local piece=S.GetUnitPieceMap(id).fb_fx_bomb_bay;local x,y,z=S.GetUnitPiecePosDir(id,piece)
     if not finite(x)or not finite(y)or not finite(z)then cancel(id,'emitter_changed')else
      local tx,ty,tz=unpack(st.target);local scatter=S.IsPosInLos(tx,ty,tz,S.GetUnitAllyTeam(id))and a.scatter or a.blind_scatter
      local angle=math.random()*2*math.pi;local radius=math.sqrt(math.random())*scatter;tx=math.max(0,math.min(game.mapSizeX,tx+math.cos(angle)*radius));tz=math.max(0,math.min(game.mapSizeZ,tz+math.sin(angle)*radius));ty=S.GetGroundHeight(tx,tz)
      local dx,dy,dz=tx-x,ty-y,tz-z;local length=math.sqrt(dx*dx+dy*dy+dz*dz);if length==0 then length=1 end
      local pid=S.SpawnProjectile(weapon,{owner=id,team=st.team,pos={x,y,z},speed={dx/length*.1,dy/length*.1,dz/length*.1},['end']={tx,ty,tz},ttl=math.ceil((length/a.projectile_speed*2+5)*fps),gravity=0})
      local px,py,pz;if type(pid)=='number'then px,py,pz=S.GetProjectilePosition(pid)end
      if not finite(pid)or pid<0 or not finite(px)or not finite(py)or not finite(pz)then cancel(id,'native_spawn_failed')else st.phase='fired';st.projectile=pid;hits[pid]={owner=id,team=st.team,def=st.def,expiry=frame+math.ceil((length/a.projectile_speed*2+6)*fps)};save(id);saveGlobal();emit('projectile_spawned',id,pid,weapon,frame,px,py,pz,tx,ty,tz)end
     end
    end
   end
  end
  for _,pid in ipairs(sorted(hits))do if frame>hits[pid].expiry then hits[pid]=nil end end
  for _,id in ipairs(sorted(targets))do local t=targets[id]
   if frame>t.expiry or S.GetUnitIsDead(id)then targets[id]=nil
   elseif frame>=t.next then
    t.next=frame+1;S.AddUnitDamage(id,a.degeneration/fps,0,t.owner,weapon)
   end
  end
  saveGlobal()
 end
 function R.Damaged(id,damage,wd,pid,frame)
  if not enabled or wd~=weapon or not finite(damage)or damage<=0 or not hits[pid]then return end
  local h=hits[pid];emit('positive_native_damage',h.owner,pid,weapon,id,damage,frame);targets[id]={owner=h.owner,team=h.team,projectile=pid,expiry=frame+math.ceil(a.degeneration_seconds*fps),next=frame+1};saveGlobal()
 end
 function R.Busy(id,frame)local st=states[id];return enabled and st and frame<st.busy end
 function R.State(id)return states[id]end
 return R
end
return M
