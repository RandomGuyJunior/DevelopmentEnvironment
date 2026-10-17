-- Read-only FUNDED NON-ECONOMY three-stage weapon observer; root owns setup.
local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
function M.New(S,D,N,W,actors,targets,team,enemy,frame,emit,contract)
 for _,name in ipairs({'AreTeamsAllied','GetUnitHealth','GetUnitIsDead','GetUnitTeam','GetUnitDefID','GetUnitPieceMap','GetUnitPiecePosDir','GetProjectilePosition','GetUnitWeaponVectors','GetUnitWeaponState','GetGameFrame','GetUnitLosState','GetUnitAllyTeam','GetUnitWeaponTestTarget','GetUnitWeaponTestRange','GetUnitWeaponHaveFreeLineOfFire'})do assert(type(S[name])=='function','actual_native_read_API_missing:'..name)end
 local facts,why=contract.Check(D,N,W);assert(facts,'actual_stage_contract:'..tostring(why))
 assert(type(emit)=='function'and type(actors)=='table'and #actors==3 and type(targets)=='table'and #targets==3,'three_explicit_stages_and_targets_required')
 assert(team~=enemy and not S.AreTeamsAllied(team,enemy),'actual_hostile_team_required')
 local C={started=frame,rows={},projectiles={},result=nil};local used={}
 local function live(id,owner)local hp,_,_,_,progress=S.GetUnitHealth(id);return finite(hp)and hp>0 and progress==1 and not S.GetUnitIsDead(id)and S.GetUnitTeam(id)==owner end
 for tier,id in ipairs(actors)do
  local target=targets[tier];assert(not used[id]and not used[target]and id~=target,'unique_native_stage_and_target_ids_required');used[id]=true;used[target]=true
  local def=N[facts[tier].key].id;assert(S.GetUnitDefID(id)==def and live(id,team)and live(target,enemy),'finished_actual_native_actors_required')
  local d=D[def];local weapon=d.weapons[1].weaponDef;local wd=W[weapon];local p=wd.customParams or{}
  local names={};if p.source_muzzle_pair then for name in p.source_muzzle_pair:gmatch('[^,%s]+')do names[#names+1]=name end else names[1]=p.source_muzzle end
  assert(#names>0,'genuine_source_muzzle_missing');local pieces={};local map=S.GetUnitPieceMap(id)or{}
  for _,name in ipairs(names)do assert(map[name]~=nil,'genuine_source_muzzle_piece_missing:'..name);pieces[#pieces+1]=map[name]end
  C.rows[id]={tier=tier,target=target,weapon=weapon,pieces=pieces,hits=0,lastHP=S.GetUnitHealth(target),shots=0}
  emit('ORK_EXTRACTOR_ARMED_CONTRACT','tier='..tier,'actor='..id,'target='..target,'weapon='..weapon,'source_weapon='..facts[tier].weapon,'funded_non_economy=true paid_economy_accepted=false native_Query_Shot_not_observed=true')
 end
 local function fail(reason)C.result=C.result or('FAIL '..reason)end
 function C.Projectile(pid,owner,weapon)
  local row=C.rows[owner];if C.closed or not row or weapon~=row.weapon then return end
  if not finite(pid)or pid<0 or pid%1~=0 then fail('native_projectile_ID_missing');return end
  if C.projectiles[pid]then fail('duplicate_native_projectile');return end
  local x,y,z=S.GetProjectilePosition(pid);local mx,my,mz=S.GetUnitWeaponVectors(owner,1);local speed=S.GetUnitWeaponState(owner,1,'projectileSpeed')
  if not(finite(x)and finite(y)and finite(z)and finite(mx)and finite(my)and finite(mz)and finite(speed)and speed>0)then fail('native_projectile_geometry_missing');return end
  if (x-mx)^2+(y-my)^2+(z-mz)^2>math.max(16,speed+4)^2 then fail('projectile_not_native_weapon_muzzle');return end
  local matched
  for _,piece in ipairs(row.pieces)do local px,py,pz=S.GetUnitPiecePosDir(owner,piece)
   if finite(px)and finite(py)and finite(pz)and (mx-px)^2+(my-py)^2+(mz-pz)^2<=16 then matched=piece;break end
  end
  if not matched then fail('native_muzzle_not_genuine_stage_piece');return end
  local f=S.GetGameFrame();C.projectiles[pid]={actor=owner,tier=row.tier,target=row.target,weapon=weapon,frame=f};row.shots=row.shots+1
  emit('ORK_EXTRACTOR_NATIVE_PROJECTILE','tier='..row.tier,'actor='..owner,'pid='..pid,'weapon='..weapon,'frame='..f,'genuine_piece='..matched,'native_birth_only=true')
 end
 function C.Damaged(id,damage,para,weapon,pid,attacker)
  if C.closed then return end
  local row;for _,candidate in pairs(C.rows)do if candidate.target==id then row=candidate;break end end;if not row then return end
  local hp=S.GetUnitHealth(id);local before=row.lastHP;row.lastHP=hp
  if not C.rows[attacker]then emit('ORK_EXTRACTOR_OTHER_HIT','target='..id,'baseline_updated=true');return end
  local p=C.projectiles[pid]
  if not p or p.target~=id or p.actor~=attacker or weapon~=row.weapon or p.weapon~=weapon or para~=false or not finite(damage)or damage<=0 then fail('wrong_or_unlinked_native_stage_hit');return end
  if not finite(hp)or not finite(before)or hp>=before then fail('native_hit_without_HP_loss');return end
  if not p.hit then p.hit=true;row.hits=row.hits+1 end
  emit('ORK_EXTRACTOR_NATIVE_HIT','tier='..row.tier,'pid='..pid,'HP='..hp,'distinct_hits='..row.hits,'native_damage_authority=true funded_non_economy=true')
 end
 function C.Step(f)
  if C.result then return C.result end
  local complete=true
  for id,row in pairs(C.rows)do
   if not live(id,team)or not live(row.target,enemy)then return'FAIL native_actor_or_target_lost_transferred_or_incomplete'end
   local los=S.GetUnitLosState(row.target,S.GetUnitAllyTeam(id),false)or{}
   local ready=S.GetUnitWeaponState(id,1)==true and los.los==true and S.GetUnitWeaponTestTarget(id,1,row.target)==true and S.GetUnitWeaponTestRange(id,1,row.target)==true and S.GetUnitWeaponHaveFreeLineOfFire(id,1,row.target)==true
   if row.hits<2 or not ready then complete=false end
  end
  if complete then return'PASS FUNDED_NON_ECONOMY three_actual_fixed_Ork_stages_two_distinct_native_projectile_HP_hits_each_natural_LOS_range_LOF_angle paid_economy_accepted=false Query_Shot_accepted=false'end
  if f-C.started>=1800 then return'INCONCLUSIVE native_armed_stage_combat_timeout'end
 end
 function C.Close()C.closed=true end
 return C
end
return M
