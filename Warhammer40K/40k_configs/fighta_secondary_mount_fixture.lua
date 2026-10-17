-- Funded combat only: secondary mounts, ordinary native targeting and scripts.
local M={}
local names={[2]={'fb_fx_bubble_gun_mid'},[3]={'fb_fx_bomb_bay'},[4]={'fb_fx_rear_gun_l','fb_fx_rear_gun_r'}}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.New(S,defs,weapons,actor,team,target,frame,emit)
 local C={actor=actor,target=target,team=team,started=frame,slots={},projectiles={},targetGeneration=1,replacementUsed=false}
 local function fail(reason)C.result=C.result or('FAIL '..reason)end
 local function live(id)return type(id)=='number'and id%1==0 and id>=0 and S.ValidUnitID(id)==true and S.GetUnitIsDead(id)==false end
 if not live(actor)or not live(target)then fail('live_actor_and_target_required');return C end
 local actorDef=S.GetUnitDefID(actor);local targetDef=S.GetUnitDefID(target);local targetTeam=S.GetUnitTeam(target)
 local d=defs[actorDef];local pieces=S.GetUnitPieceMap(actor)or{}
 if not d or not d.canFly or(d.customParams or{}).animsource~='ork_fighta_bomba'or S.GetUnitTeam(actor)~=team or S.AreTeamsAllied(team,S.GetUnitTeam(target))then fail('genuine_hostile_Fighta_contract');return C end
 local hp,_,_,_,progress=S.GetUnitHealth(target)
 if not finite(hp)or hp<=0 or progress~=1 then fail('complete_native_target_required');return C end
 if not finite(targetDef)or targetDef%1~=0 or targetDef<1 or not finite(targetTeam)or targetTeam%1~=0 or targetTeam<0 then fail('native_target_definition_and_owner_required');return C end
 C.hp=hp
 for n=2,4 do
  local row=d.weapons and d.weapons[n];local w=row and weapons[row.weaponDef];local cp=w and w.customParams or{}
  if not w or w.type~=(n==3 and'MissileLauncher'or'Cannon')or tonumber(cp.source_hardpoint)~=n or cp.source_muzzle~=names[n][1]or(n==4 and cp.source_muzzle_pair~=table.concat(names[n],','))then fail('genuine_secondary_mount_'..n);return C end
  local q={weapon=row.weaponDef,allowed={},barrels={},shots=0,hits=0}
  for _,name in ipairs(names[n])do local p=pieces[name];if type(p)~='number'then fail('actual_secondary_piece_'..n);return C end;q.allowed[p]=true end
  C.slots[n]=q
 end
 function C.TargetDestroyed(id,def,owner,nativeDead,attacker,f)
  if C.closed or C.result or id~=target or C.targetGeneration~=1 or C.targetDeath then return false end
  local qualified=def==targetDef and owner==targetTeam and nativeDead==true and attacker==actor and finite(f)and f%1==0 and f==S.GetGameFrame()and live(actor)and S.GetUnitTeam(actor)==team and S.GetUnitDefID(actor)==actorDef
  emit('TARGET_NATIVE_DEATH','id='..tostring(id),'def='..tostring(def),'team='..tostring(owner),'native_dead='..tostring(nativeDead),'attacker='..tostring(attacker),'generation=1','qualified='..tostring(qualified),'frame='..tostring(f))
  if qualified then C.targetDeath={id=id,def=def,team=owner,frame=f};return true end
  return false
 end
 function C.CanReplaceTarget()
  return not C.closed and not C.result and not C.replacementUsed and C.targetGeneration==1 and C.targetDeath~=nil and C.targetDeath.id==target and live(actor)and S.GetUnitTeam(actor)==team and S.GetUnitDefID(actor)==actorDef
 end
 function C.ReplaceTarget(nextTarget,f)
  if not C.CanReplaceTarget()or not finite(f)or f%1~=0 or f~=S.GetGameFrame()or f<C.targetDeath.frame or nextTarget==actor or nextTarget==target or not live(nextTarget)or S.GetUnitDefID(nextTarget)~=targetDef or S.GetUnitTeam(nextTarget)~=targetTeam then return false,'replacement_identity_or_native_death_not_qualified' end
  local hp,_,_,_,progress=S.GetUnitHealth(nextTarget)
  if not finite(hp)or hp<=0 or progress~=1 then return false,'replacement_not_genuinely_complete' end
  local prior=target;target=nextTarget;C.target=nextTarget;C.hp=hp;C.targetGeneration=2;C.replacementUsed=true
  -- Retain authenticated prior hits/barrels, but never transfer an unfinished
  -- Shot/Query or old-target projectile into new-target acceptance credit.
  for _,q in pairs(C.slots)do q.pendingShot=nil;q.query=nil end
  emit('REPLACEMENT_TARGET','prior='..prior,'target='..nextTarget,'generation=2','native_hp='..hp,'unchanged_native_target=true','max_replacements=1')
  return true
 end
 function C.Query(id,n,piece)
  if C.closed or C.result or id~=actor or not C.slots[n]then return end
  local q=C.slots[n];if not q.allowed[piece]then fail('secondary_query_piece_'..n);return end
  local x,y,z=S.GetUnitPiecePosDir(actor,piece)
  if not(finite(x)and finite(y)and finite(z))then fail('secondary_query_position_'..n);return end
  q.query={piece=piece,x=x,y=y,z=z,frame=S.GetGameFrame()};emit('QUERY','slot='..n,'piece='..piece,'frame='..q.query.frame)
 end
 function C.Shot(id,n,f)
  if C.closed or C.result or id~=actor or not C.slots[n]then return end
  local q=C.slots[n]
  if not finite(f)or f%1~=0 or f<0 or f~=S.GetGameFrame()or q.pendingShot then fail('typed_unconsumed_native_secondary_shot_'..n);return end
  if S.GetUnitWeaponState(actor,n)~=true then fail('native_secondary_angle_'..n);return end
  -- Native roster ordering is Shot -> Query -> ProjectileCreated. Discard any
  -- pre-aim or previously consumed Query; every PID needs its own fresh Query.
  q.query=nil;q.shots=q.shots+1;q.lastShot=f;q.pendingShot={frame=f,ordinal=q.shots,targetGeneration=C.targetGeneration};emit('SHOT','slot='..n,'frame='..f,'count='..q.shots)
 end
 function C.Projectile(pid,owner,weapon)
  if C.closed or C.result or owner~=actor then return end
  local n,q;for slot,row in pairs(C.slots)do if row.weapon==weapon then n,q=slot,row end end
  if not q then return end
  if type(pid)~='number'or pid%1~=0 or pid<0 or C.projectiles[pid]then fail('duplicate_or_invalid_secondary_projectile');return end
  local at=q.query;local x,y,z=S.GetProjectilePosition(pid);local mx,my,mz=S.GetUnitWeaponVectors(actor,n);local speed=S.GetUnitWeaponState(actor,n,'projectileSpeed')
  if not at or not q.pendingShot or not q.lastShot or at.frame<q.lastShot or S.GetGameFrame()-q.lastShot<0 or S.GetGameFrame()-q.lastShot>2 or not(finite(x)and finite(y)and finite(z)and finite(mx)and finite(my)and finite(mz)and finite(speed))or speed<=0 then fail('secondary_native_launch_'..n);return end
  if(x-at.x)^2+(y-at.y)^2+(z-at.z)^2>math.max(16,speed+4)^2 or(mx-at.x)^2+(my-at.y)^2+(mz-at.z)^2>16 then fail('secondary_launch_not_query_muzzle_'..n);return end
  C.projectiles[pid]={slot=n,piece=at.piece,shotOrdinal=q.pendingShot.ordinal,shotFrame=q.pendingShot.frame,targetGeneration=q.pendingShot.targetGeneration};q.pendingShot=nil;q.barrels[at.piece]=true;emit('PROJECTILE','slot='..n,'pid='..pid,'piece='..at.piece,'generation='..C.targetGeneration,'target='..target)
 end
 function C.Damaged(id,damage,para,weapon,pid,attacker)
  if C.closed or C.result or id~=target then return end
  local hp=S.GetUnitHealth(target)
  if not finite(hp)or hp<0 then fail('native_target_health_missing');return end
  local p=C.projectiles[pid]
  if attacker==actor and p and p.targetGeneration~=C.targetGeneration then
   emit('OLD_TARGET_PROJECTILE_NO_CREDIT','slot='..p.slot,'pid='..pid,'generation='..p.targetGeneration,'current_generation='..C.targetGeneration,'health='..hp);C.hp=hp;return
  end
  if attacker==actor and p and weapon==C.slots[p.slot].weapon and not para and finite(damage)and damage>0 then
   if p.hit or hp>=C.hp then fail('secondary_duplicate_or_no_health_loss');return end
   p.hit=true;local q=C.slots[p.slot];q.hits=q.hits+1;emit('HIT','slot='..p.slot,'pid='..pid,'damage='..damage,'health='..hp,'count='..q.hits,'generation='..C.targetGeneration,'target='..target)
  elseif attacker==actor then
   for n,q in pairs(C.slots)do if weapon==q.weapon then fail('secondary_damage_without_tracked_projectile_'..n)end end
  end
  -- Primary and other native damage remain ordinary; keep the real HP baseline.
  C.hp=hp
 end
 function C.Step(f)
  if C.result then return C.result end
  if not live(actor)or S.GetUnitTeam(actor)~=team or S.GetUnitDefID(actor)~=actorDef then return'FAIL funded_aircraft_lost_transferred_or_replaced'end
  if not live(target)or S.GetUnitTeam(target)~=targetTeam or S.GetUnitDefID(target)~=targetDef then return'INCONCLUSIVE target_lost_transferred_or_replaced_before_secondary_witness'end
  local complete=true
  for _,q in pairs(C.slots)do if q.hits<2 then complete=false end;for p in pairs(q.allowed)do if not q.barrels[p]then complete=false end end end
  if complete then return'PASS secondary_2_3_4_native_Query_Shot_projectiles_two_hits_all_source_muzzles funded_non_economy=true primary_acceptance_unchanged=true'end
  if f-frame>=1800 then return'INCONCLUSIVE secondary_mount_timeout_no_weapon_or_orientation_override'end
 end
 function C.Close()C.closed=true end
 return C
end
return M
