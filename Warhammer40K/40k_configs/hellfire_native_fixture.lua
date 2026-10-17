-- Default-off unpaid native function scene. No research/damage/health overrides.
local M={Filter='imp_dreadnought_hellfire,imp_basilisk',Roster={imp_dreadnought_hellfire=true,imp_basilisk=true,imp_russ=true,imp_guardsman=true}}
local function on(v)return v==true or v==1 or v=='1'end
function M.Enabled(o)
 o=o or{}
 if o.prototype_diagnostic~='roster'or o.prototype_roster_filter~=M.Filter or not on(o.prototype_hellfire_fixture)or tonumber(o.prototype_test_speed or 1)~=1 then return false end
 for _,key in ipairs({'prototype_source_progression','prototype_source_paid_match','prototype_development_playtest','prototype_transport_review','prototype_lifta_fixture','prototype_gait_review','prototype_armour_fixture','prototype_ork_primary_visual_review','prototype_barrel_review'})do if on(o[key])then return false end end
 return o.prototype_source_acceptance==nil or o.prototype_source_acceptance==''
end
M.Cases={{name='near_north',distance=120,dx=0,dz=1},{name='middle_east',distance=300,dx=1,dz=0},{name='far_south',distance=430,dx=0,dz=-1},{name='after_move_west',distance=300,dx=-1,dz=0,move=true}}
-- Exact future sites are shared by lane validation and actual births. Targets stay
-- on tested coordinates even if ordinary ground settling moves the actor slightly.
function M.TargetSites(case,x,z)
 if case.move then x=x+96 end
 local tx,tz=x+case.dx*case.distance,z+case.dz*case.distance
 return tx,tz,tx+case.dz*36-case.dx*12,tz-case.dx*36-case.dz*12
end
function M.Sites(x,z)
 local out={{name='imp_dreadnought_hellfire',x=x,z=z},{name='imp_basilisk',x=x-220,z=z-120}}
 for _,case in ipairs(M.Cases)do
  local tx,tz,sx,sz=M.TargetSites(case,x,z)
  out[#out+1]={name='imp_russ',x=tx,z=tz};out[#out+1]={name='imp_guardsman',x=sx,z=sz}
 end
 for step=32,96,32 do out[#out+1]={name='imp_dreadnought_hellfire',x=x+step,z=z}end
 for step=20,80,20 do out[#out+1]={name='imp_basilisk',x=x-220+step,z=z-120}end
 return out
end
function M.Ledger(S,actor,mounts,emit)
 local R={projectiles={},pending={},rows={},closed=false,serial=0}
 local byWeapon={};for slot,m in ipairs(mounts)do byWeapon[m.weapon]=slot end
 local function frame()return S.GetGameFrame()end
 local function pos(...)local x,y,z=...;if x and y and z then return{x,y,z}end end
 local function distance(a,b)if not a or not b then return nil end;return math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2)end
 function R.Begin(case,primary,secondary)
  R.row={name=case.name,start=frame(),primary=primary,secondary=secondary,mounts={},projectiles={},duplicates=0,unmatchedHits=0,foreignVictimHits=0,foreignTargets=0};R.rows[#R.rows+1]=R.row
  for slot in ipairs(mounts)do R.row.mounts[slot]={shots=0,drainShots=0,queries=0,births=0,drainBirths=0,hits=0,secondaryHits=0,foreignHits=0,damage=0,healthLoss=0,portHits={},lastShot=nil,cycles=0,cycleCounts={},shotFrames={},cycleFirst={},cycleLast={}}end
 end
 function R.EndFire(f)if R.row and not R.row.fireEnd then R.row.fireEnd=f end end
 function R.ForeignTarget(slot,id,f)
  if not R.row then return end;R.row.foreignTargets=R.row.foreignTargets+1
  emit('foreign_target',{case=R.row.name,frame=f,slot=slot,target=id,phase=R.row.fireEnd and 'drain'or 'fire'})
 end
 function R.Shot(id,n,f)
  if R.closed or id~=actor or not R.row or not mounts[n]then return end
  local m=R.row.mounts[n];m.pendingQuery=true
  if R.row.fireEnd then m.drainShots=m.drainShots+1;emit('shot',{case=R.row.name,slot=n,frame=f,phase='drain',eligible=false,serial=m.drainShots});return end
  m.shots=m.shots+1
  if not m.lastShot or f-m.lastShot>15 then m.cycles=m.cycles+1 end
  m.cycleCounts[m.cycles]=(m.cycleCounts[m.cycles]or 0)+1
  m.shotFrames[#m.shotFrames+1]=f;m.cycleFirst[m.cycles]=m.cycleFirst[m.cycles]or f;m.cycleLast[m.cycles]=f
  m.lastShot=f;m.pendingQuery=true;emit('shot',{case=R.row.name,slot=n,frame=f,serial=m.shots,phase='fire',eligible=true})
 end
 function R.Query(id,n,piece)
  if R.closed or id~=actor or not R.row or not mounts[n]then return end
  local m=R.row.mounts[n];local p=pos(S.GetUnitPiecePosDir(id,piece));m.query={piece=piece,position=p,frame=frame()}
  if not m.pendingQuery then return end;m.pendingQuery=false;m.queries=m.queries+1
  local env=S.UnitScript.GetScriptEnv(id);local fn=env and env.script and env.script.AimFromWeapon
  local aim=fn and S.UnitScript.CallAsUnit(id,fn,n)
  local same=aim==piece;local actual=mounts[n].pieces[piece]==true
  if not p or not same or not actual then m.badMuzzle=true end
  if not R.row.fireEnd then m.portHits[piece]=(m.portHits[piece]or 0)+1 end
  emit('query',{case=R.row.name,slot=n,frame=frame(),piece=piece,aimFrom=aim,position=p,sourcePiece=actual,normalAimFromMatch=same})
 end
 function R.Projectile(pid,owner,weapon)
  if R.closed or owner~=actor or not R.row then return end
  local slot=byWeapon[weapon];if not slot then return end
  R.serial=R.serial+1;if R.serial>1000 then R.failed='bounded_projectile_limit';return end
  local m=R.row.mounts[slot];local p=pos(S.GetProjectilePosition(pid));local q=m.query
  local entry={id=pid,row=R.row,slot=slot,start=frame(),position=p,last=p,travel=0,hits={},query=q,explosions=0,deleted=false,eligible=R.row.fireEnd==nil}
  R.projectiles[pid]=entry;R.row.projectiles[#R.row.projectiles+1]=entry;if entry.eligible then m.births=m.births+1 else m.drainBirths=m.drainBirths+1 end
  local velocity=S.GetProjectileVelocity and pos(S.GetProjectileVelocity(pid));entry.velocity=velocity
  local separation=distance(p,q and q.position)
  if not separation or separation>8 or not q or q.frame~=frame()then m.badSpawn=true end
  emit('projectile',{case=R.row.name,slot=slot,frame=frame(),id=pid,weapon=weapon,position=p,velocity=velocity,piece=q and q.piece,muzzleDistance=separation,queryFrame=q and q.frame,eligible=entry.eligible,phase=entry.eligible and 'fire'or 'drain'})
 end
 function R.Tick(f)
  if R.closed or f%3~=0 then return end
  for pid,p in pairs(R.projectiles)do if not p.deleted and p.slot==2 then
   local v=pos(S.GetProjectilePosition(pid));local travelled=distance(v,p.position)
   if travelled then p.travel=math.max(p.travel,travelled);p.last=v end
   if v and not p.travelLogged and p.travel>=10 then p.travelLogged=true;emit('travel',{case=p.row.name,id=pid,frame=f,position=v,distance=p.travel})end
  end end
 end
 function R.Explosion(weapon,x,y,z,owner,pid)
  if R.closed or owner~=actor then return end
  local p=R.projectiles[pid]
  if p then p.explosions=p.explosions+1;p.impact={x,y,z};emit('explosion',{case=p.row.name,slot=p.slot,frame=frame(),id=pid,weapon=weapon,position=p.impact})
  else emit('unmatched_explosion',{frame=frame(),id=pid,weapon=weapon,position={x,y,z}})end
 end
 function R.Deleted(pid)
  local p=R.projectiles[pid];if not p or R.closed then return end;p.deleted=true
  emit('deleted',{case=p.row.name,slot=p.slot,frame=frame(),id=pid,travel=p.travel,explosions=p.explosions})
 end
 function R.Pre(id,damage,paralyzer,weapon,pid,attacker)
  if R.closed or attacker~=actor or paralyzer or damage<=0 then return end
  local hp=S.GetUnitHealth(id);R.pending[id]={before=hp,weapon=weapon,pid=pid}
 end
 function R.Damaged(id,damage,paralyzer,weapon,pid,attacker)
  if R.closed or attacker~=actor or paralyzer or damage<=0 then return end
  local p=R.projectiles[pid];local pending=R.pending[id];R.pending[id]=nil;local hp=S.GetUnitHealth(id)
  if not p then if R.row then R.row.unmatchedHits=R.row.unmatchedHits+1 end;emit('unmatched_hit',{frame=frame(),id=id,weapon=weapon,projectile=pid,damage=damage});return end
  local m=p.row.mounts[p.slot];local primary=id==p.row.primary;local secondary=id==p.row.secondary
  if not primary and not secondary then m.foreignHits=m.foreignHits+1;p.row.foreignVictimHits=p.row.foreignVictimHits+1 end
  if p.eligible and primary then m.hits=m.hits+1;m.damage=m.damage+damage end
  if p.eligible and secondary then m.secondaryHits=m.secondaryHits+1 end
  local loss=pending and pending.weapon==weapon and pending.pid==pid and pending.before and hp and pending.before-hp
  if p.eligible and primary then if loss then m.healthLoss=m.healthLoss+loss else m.badHealth=true end end
  if loss and math.abs(loss-damage)>math.max(1,damage)*.001 then m.badHealth=true end
  if p.hits[id]then p.row.duplicates=p.row.duplicates+1 end;p.hits[id]=(p.hits[id]or 0)+1
  emit('hit',{case=p.row.name,slot=p.slot,frame=frame(),projectile=pid,target=id,primary=id==p.row.primary,secondary=id==p.row.secondary,damage=damage,healthLoss=loss,healthAfter=hp,eligible=p.eligible,foreign=not(primary or secondary)})
 end
 function R.Summary()
  local r=R.row;local gun,pod=r.mounts[1],r.mounts[2];local travels,explosions,splash,ports=0,0,0,0
  for _,p in ipairs(r.projectiles)do if p.slot==2 and p.eligible then
   if p.travel>=10 then travels=travels+1 end;explosions=explosions+p.explosions
   if p.hits[r.primary]and r.secondary and p.hits[r.secondary]then splash=splash+1 end
  end end
  for _ in pairs(pod.portHits)do ports=ports+1 end
  local fullSalvos,interleaved=0,0;for cycle,count in pairs(pod.cycleCounts)do if count==4 then
   fullSalvos=fullSalvos+1
   for _,f in ipairs(gun.shotFrames)do if f>=pod.cycleFirst[cycle]and f<=pod.cycleLast[cycle]then interleaved=interleaved+1;break end end
  end end
  local okay=interleaved>=2 and fullSalvos>=2 and gun.shots>0 and gun.hits>0 and pod.shots>=8 and pod.births>=8 and pod.cycles>=2 and pod.hits>0 and ports==4 and travels>=8 and explosions>=8 and r.duplicates==0 and r.unmatchedHits==0 and r.foreignVictimHits==0 and r.foreignTargets==0
   and not(gun.badMuzzle or pod.badMuzzle or gun.badSpawn or pod.badSpawn or gun.badHealth or pod.badHealth)
  local result={case=r.name,frame=frame(),primary=r.primary,secondary=r.secondary,fireEnd=r.fireEnd,foreignVictimHits=r.foreignVictimHits,foreignTargets=r.foreignTargets,gun=gun,pod=pod,travelledRockets=travels,rocketExplosions=explosions,nativeSplashProjectiles=splash,uniquePorts=ports,completeFourRocketSalvos=fullSalvos,interleavedGunSalvos=interleaved,duplicateVictimHits=r.duplicates,unmatchedHits=r.unmatchedHits,nativeFunctionPass=okay,visualAcceptance=false,paidAcceptance=false}
  emit('case_summary',result);return result
 end
 function R.Close()R.closed=true end
 return R
end
return M
