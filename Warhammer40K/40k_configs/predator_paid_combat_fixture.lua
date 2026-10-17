-- Optional ordinary-paid Predator follow-on; only hostile targets are unpaid.
local M={Version=1,Option='prototype_predator_paid_combat_fixture'}
local terminal='PASS two_ordinary_paid_Predators_native_finish_release_geometry30travel_rally_idle_reopen_prior_preserved'
local muzzles={'marker_autocannon','marker_heavy_bolter_barrel_l','marker_heavy_bolter_barrel_r'}
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function integer(x,min)return finite(x)and x%1==0 and x>=(min or 0)and x<=2147483647 end
function M.New(S,D,N,W,GG,Script,Game,paid,frame,emit)
 local C={phase='site',started=frame,serial=0,slots={},projectiles={},created={},watched={},candidate=0}
 local function log(ev,...)if type(emit)~='function'then return end;local a={...};a[#a+1]='ordinary_owned_products_preserved=true';a[#a+1]='unpaid_hostile_only=true';a[#a+1]='paid_economy_accepted=false';emit(ev,unpack(a))end
 local function live(id,def,team,complete)
  if not integer(id)or S.ValidUnitID(id)~=true or S.GetUnitIsDead(id)~=false or S.GetUnitDefID(id)~=def or S.GetUnitTeam(id)~=team then return false end
  local hp,max,_,_,p=S.GetUnitHealth(id);return finite(hp)and hp>0 and finite(max)and max>0 and(not complete or p==1)
 end
 local function clean()
  C.closed=true
  if type(GG)=='table'and GG.Recoil40KStompaWeaponWitness==C then GG.Recoil40KStompaWeaponWitness=nil end
  for w in pairs(C.watched)do Script.SetWatchProjectile(w,false)end;C.watched={}
  for id,r in pairs(C.created)do if not r.retired and live(id,r.def,r.team,false)then S.DestroyUnit(id,false,true);r.retired=true end end
 end
 local function finish(state,why)if not C.result then C.result=state..' '..why;clean();log('PREDATOR_COMBAT_COMPLETE',C.result,'native_acceptance=false','render_accepted=false','exact_resource_charge_accepted=false')end;return C.result end
 local function fail(why)return finish('FAIL',why)end
 local function inconclusive(why)return finish('INCONCLUSIVE',why)end
 function C.Frame()end;function C.Query()end;function C.Shot()end;function C.Projectile()end;function C.Damaged()end;function C.Destroyed()end;C.Close=clean
 if type(S)~='table'or type(D)~='table'or type(N)~='table'or type(W)~='table'or type(GG)~='table'or type(Script)~='table'or type(Game)~='table'then fail('typed_native_context_required');return C end
 for _,name in ipairs({'GetGameFrame','ValidUnitID','GetUnitIsDead','GetUnitDefID','GetUnitTeam','GetUnitAllyTeam','GetUnitLosState','GetUnitHealth','GetUnitCosts','GetUnitPosition','GetUnitPieceMap','GetUnitPiecePosDir','GetUnitWeaponVectors','GetUnitWeaponState','GetUnitWeaponTestTarget','GetUnitWeaponTestRange','GetUnitWeaponTryTarget','GetUnitWeaponHaveFreeLineOfFire','GetProjectilePosition','GetGroundHeight','GetUnitsInRectangle','GetFeaturesInRectangle','TestMoveOrder','GetTeamList','GetGaiaTeamID','AreTeamsAllied','CreateUnit','DestroyUnit','GiveOrderToUnit'})do
  if type(S[name])~='function'then fail('actual_native_API_missing_'..name);return C end
 end
 if type(Script.SetWatchProjectile)~='function'or type(emit)~='function'then fail('typed_native_watch_and_sink_required');return C end
 if not finite(Game.mapSizeX)or not finite(Game.mapSizeZ)or not finite(Game.gameSpeed)or Game.gameSpeed<=0 or not integer(frame)or S.GetGameFrame()~=frame then fail('typed_actual_scene_clock_bounds_required');return C end
 if not paid or paid.result~=terminal or not paid.plan or not paid.units or not paid.births or not paid.finishes or not paid.releases or not paid.proven then inconclusive('genuine_paid_two_Predator_gate_required');return C end
 local pn=N.imp_predator;local rn=N.imp_russ
 if not pn or not rn or not integer(pn.id,1)or not integer(rn.id,1)then fail('actual_native_Predator_Russ_definitions_required');return C end
 C.def=pn.id;C.targetDef=rn.id;C.team=0;C.actor=paid.units.vehicle1;C.other=paid.units.vehicle2;C.factory=paid.units.factory;C.paid=paid
 local d=D[C.def];local cp=d and d.customParams or{}
 if not d or d.metalCost~=500 or d.energyCost~=2500 or d.buildTime~=3800 or cp.animsource~='imp_predator'or d.scriptName~='40k_roster.lua'or #(d.weapons or{})~=3 then fail('actual_individual_Predator_bill_script_mount_contract');return C end
 if not integer(C.actor)or not integer(C.other)or C.actor==C.other or paid.plan.imp_predator~=C.def then fail('two_distinct_paid_individual_products_required');return C end
 for _,id in ipairs({C.actor,C.other})do
  local b,f,r=paid.births[id],paid.finishes[id],paid.releases[id]
  if paid.proven[id]~=true or not b or not f or not r or b.def~=C.def or b.team~=0 or b.builder~=C.factory or f.def~=C.def or f.team~=0 or r.parent~=C.factory or r.parentDef~=paid.plan.imp_walker_factory or not integer(b.frame)or not integer(f.frame)or not integer(r.frame)or not(b.frame<=f.frame and f.frame<=r.frame and r.frame+30<=frame)or not live(id,C.def,0,true)then fail('original_genuine_paid_finish_release_clear_gate');return C end
  local work,metal,energy=S.GetUnitCosts(id);if work~=3800 or metal~=500 or energy~=2500 then fail('actual_paid_native_product_cost_changed');return C end
 end
 local seen={};C.preserve={}
 local required={commander='smcom',mex1='imp_marine_mex',power1='imp_marine_generator',power2='imp_marine_generator',mex2='imp_marine_mex',factory='imp_walker_factory',vehicle1='imp_predator',vehicle2='imp_predator'}
 for role in pairs(required)do if not integer(paid.units[role])then fail('paid_predecessor_role_missing_'..role);return C end end
 for role,id in pairs(paid.units)do
  local def=S.GetUnitDefID(id)
  if not required[role]or def~=paid.plan[required[role]]or not integer(id)or seen[id]or not live(id,def,0,true)then fail('paid_predecessor_not_live_distinct_owned_'..tostring(role));return C end
  seen[id]=true;C.preserve[id]={def=def,role=role}
 end
 if GG.Recoil40KStompaWeaponWitness~=nil then inconclusive('existing_genuine_Query_Shot_telemetry_owner_busy');return C end
 local pieces=S.GetUnitPieceMap(C.actor)
 if type(pieces)~='table'then fail('native_piece_map_required');return C end
 C.weaponToSlot={}
 for n=1,3 do
  local row=d.weapons[n];local w=row and W[row.weaponDef];local wc=w and w.customParams or{};local piece=pieces[muzzles[n]]
  if not w or w.type~='Cannon'or wc.source_muzzle~=muzzles[n]or not integer(piece)or w.range~=(n==1 and 430 or 310)or w.salvoSize~=(n==1 and 1 or 3)or not finite(w.reload)or math.abs(w.reload-(n==1 and 3.5 or 1.2))>.0001 or C.weaponToSlot[row.weaponDef]then fail('genuine_native_Predator_mount_'..n);return C end
  C.weaponToSlot[row.weaponDef]=n;C.slots[n]={piece=piece,weapon=row.weaponDef,hits=0,shots=0,range=w.range}
 end
 local teams=S.GetTeamList()
 if type(teams)~='table'then fail('actual_team_list_required');return C end
 for _,team in ipairs(teams)do if integer(team)and team~=0 and team~=S.GetGaiaTeamID()and S.AreTeamsAllied(0,team)==false then if C.enemy then inconclusive('exact_one_registered_inactive_hostile_required');return C end;C.enemy=team end end
 if C.enemy==nil then inconclusive('root_registered_inactive_hostile_team_dependency_required');return C end
 GG.Recoil40KStompaWeaponWitness=C
 for w in pairs(C.weaponToSlot)do Script.SetWatchProjectile(w,true);C.watched[w]=true end
 log('PREDATOR_COMBAT_BEGIN','actor='..C.actor,'preserved_second='..C.other,'factory='..C.factory,'owned_bill=500,2500,3800','three_Cannon_native_mounts=true','existing_roster_Query_Shot_only=true')
 local function targetLive()
  return C.target~=nil and live(C.target,C.targetDef,C.enemy,true)
 end
 local function retireTarget()
  local target=C.target;local r=target and C.created[target]
  C.target=nil;C.phase='site'
  if r and live(target,r.def,r.team,false)then r.retired=true;S.DestroyUnit(target,false,true)end
 end
 local function acquire()
  if not targetLive()then return inconclusive('hostile_lost_before_natural_LOS')end
  local ally=S.GetUnitAllyTeam(C.actor);if not integer(ally)then return fail('actual_paid_actor_ally_team_required')end
  local los=S.GetUnitLosState(C.target,ally,false)
  if type(los)~='table'or los.los~=true then
   if S.GetGameFrame()-C.siteFrame>=30 then log('PREDATOR_SITE_REFUSED','candidate='..C.candidate,'natural_LOS_not_acquired=true');retireTarget()end
   return
  end
  local target=C.target;local tx,ty,tz=S.GetUnitPosition(target)
  if not finite(tx)or not finite(ty)or not finite(tz)then return fail('finite_actual_hostile_position_required')end
  for n=1,3 do
   local q=C.slots[n];local mx,my,mz=S.GetUnitPiecePosDir(C.actor,q.piece)
   if not finite(mx)or not finite(my)or not finite(mz)then return fail('finite_actual_native_muzzle_position_required')end
   if S.GetUnitWeaponTestTarget(C.actor,n,target)~=true or S.GetUnitWeaponTestRange(C.actor,n,target)~=true or S.GetUnitWeaponTryTarget(C.actor,n,target)~=true or S.GetUnitWeaponHaveFreeLineOfFire(C.actor,n,mx,my,mz,tx,ty,tz)~=true then
    log('PREDATOR_SITE_REFUSED','candidate='..C.candidate,'slot='..n,'native_target_range_TryTarget_LOF_preserved=true');retireTarget();return
   end
  end
  C.health=S.GetUnitHealth(target)
  if not finite(C.health)or C.health<=0 then return fail('genuine_hostile_health_required')end
  C.phase='combat'
  if S.GiveOrderToUnit(C.actor,CMD.ATTACK,{target},0)~=true then return fail('ordinary_paid_actor_ATTACK_refused')end
  log('PREDATOR_ATTACK','actor='..C.actor,'hostile='..target,'target_xyz='..tx..','..ty..','..tz,'natural_LOS=true','native_common_range_TryTarget_eight_argument_LOF=true')
 end
 local function scene()
  local x,y,z=S.GetUnitPosition(C.actor);if not finite(x)or not finite(y)or not finite(z)then return fail('actual_finite_paid_actor_position_required')end
  local td=D[C.targetDef];local radius=td and math.max(td.radius or 0,(td.xsize or 0)*4,(td.zsize or 0)*4)+32
  if not finite(radius)or radius<=32 then return fail('actual_hostile_native_footprint_required')end
  -- Consume one of32 bounded actual sites per native frame. No paid actor moves.
  C.candidate=C.candidate+1;if C.candidate>32 then return inconclusive('no_common_natural_native_target_site')end
  local angle=(C.candidate-1)*math.pi/16;local distance=math.max(180,radius+64)
  local tx,tz=math.floor(x+distance*math.sin(angle)+.5),math.floor(z+distance*math.cos(angle)+.5);local ty=S.GetGroundHeight(tx,tz)
  if not finite(ty)or ty<0 or tx-radius<=64 or tz-radius<=64 or tx+radius>=Game.mapSizeX-64 or tz+radius>=Game.mapSizeZ-64 then return end
  local us,fs=S.GetUnitsInRectangle(tx-radius,tz-radius,tx+radius,tz+radius),S.GetFeaturesInRectangle(tx-radius,tz-radius,tx+radius,tz+radius)
  if type(us)~='table'or type(fs)~='table'or next(us)~=nil or next(fs)~=nil then return end
  for _,dx in ipairs({-radius,0,radius})do for _,dz in ipairs({-radius,0,radius})do
   local ground=S.GetGroundHeight(tx+dx,tz+dz)
   if not finite(ground)or ground<0 or S.TestMoveOrder(C.targetDef,tx+dx,ground,tz+dz,0,0,0,true,true,false)~=true then return end
  end end
  local target=S.CreateUnit('imp_russ',tx,ty,tz,0,C.enemy)
  if not integer(target)or not live(target,C.targetDef,C.enemy,true)then return fail('owned_unpaid_hostile_native_birth_required')end
  C.created[target]={def=C.targetDef,team=C.enemy};C.target=target
  -- Ordinary hostile hold-fire prevents damaging the paid actors during diagnostics.
  if S.GiveOrderToUnit(target,CMD.FIRE_STATE,{0},0)~=true or S.GiveOrderToUnit(target,CMD.STOP,{},0)~=true then return fail('ordinary_hostile_hold_fire_order_refused')end
  C.phase='acquire';C.siteFrame=S.GetGameFrame();acquire()
 end
 function C.Frame(f)
  if C.result then return C.result end
  if not integer(f)or f~=S.GetGameFrame()then return fail('exact_native_callback_clock_required')end
  for id,row in pairs(C.preserve)do if not live(id,row.def,0,true)then return fail('ordinary_paid_predecessor_lost_captured_or_replaced_'..row.role)end end
  if GG.Recoil40KStompaWeaponWitness~=C then return inconclusive('genuine_roster_telemetry_ownership_lost')end
  if f-C.started>1800 then return inconclusive('native_three_mount_projectile_hit_timeout')end
  if C.phase=='site'then scene();return C.result end
  if C.phase=='acquire'then acquire();return C.result end
  if not targetLive()then return inconclusive('hostile_lost_captured_or_replaced_before_complete')end
  if C.slots[1].hits>0 and C.slots[2].hits>0 and C.slots[3].hits>0 then return finish('PASS','ordinary_paid_Predator_three_native_Cannon_Query_Shot_PID_HP_hits_hostile_only_unpaid_second_and_predecessors_preserved')end
 end
 function C.Query(id,n,piece)
  if C.closed or C.phase~='combat'or id~=C.actor or not C.slots[n]then return end
  if piece~=C.slots[n].piece then return fail('genuine_Predator_query_piece_mismatch_'..n)end
  local now=S.GetGameFrame();if not integer(now)then return fail('actual_native_Query_clock_required')end
  local x,y,z=S.GetUnitPiecePosDir(id,piece);if not finite(x)or not finite(y)or not finite(z)then return fail('actual_Query_muzzle_position_required')end
  C.serial=C.serial+1;C.slots[n].query={serial=C.serial,frame=now,x=x,y=y,z=z};log('PREDATOR_QUERY','slot='..n,'piece='..piece,'frame='..now)
 end
 function C.Shot(id,n,f)
  if C.closed or C.phase~='combat'or id~=C.actor or not C.slots[n]then return end
  if not integer(f)or f~=S.GetGameFrame()then return fail('actual_native_Shot_clock_required')end
  C.serial=C.serial+1;local q=C.slots[n];q.shots=q.shots+1;q.shot={serial=C.serial,frame=f,linked=false};log('PREDATOR_SHOT','slot='..n,'frame='..f,'count='..q.shots)
 end
 function C.Projectile(pid,owner,weapon)
  if C.closed or C.phase~='combat'or owner~=C.actor or not C.weaponToSlot[weapon]then return end
  local n=C.weaponToSlot[weapon];local q=C.slots[n];local shot,query=q.shot,q.query;local now=S.GetGameFrame()
  if not integer(pid)or C.projectiles[pid]or not shot or shot.linked or not query or query.serial<=shot.serial or not integer(now)or now<shot.frame or now-shot.frame>2 or query.frame<shot.frame or now<query.frame then return fail('genuine_fresh_Query_Shot_unique_PID_link_required_'..n)end
  local x,y,z=S.GetProjectilePosition(pid);local mx,my,mz=S.GetUnitWeaponVectors(C.actor,n);local speed=S.GetUnitWeaponState(C.actor,n,'projectileSpeed')
  if not finite(x)or not finite(y)or not finite(z)or not finite(mx)or not finite(my)or not finite(mz)or not finite(speed)or speed<=0 then return fail('actual_native_projectile_muzzle_speed_required')end
  if(x-query.x)^2+(y-query.y)^2+(z-query.z)^2>math.max(16,speed+4)^2 or(mx-query.x)^2+(my-query.y)^2+(mz-query.z)^2>16 then return fail('native_PID_not_observed_Query_muzzle')end
  shot.linked=true;C.projectiles[pid]={slot=n,weapon=weapon,frame=now};log('PREDATOR_PID','slot='..n,'pid='..pid,'frame='..now)
 end
 function C.Damaged(id,damage,paralyzer,weapon,pid,attacker)
  if C.closed or C.phase~='combat'or id~=C.target then return end
  if not targetLive()or not live(C.actor,C.def,0,true)or not integer(S.GetGameFrame())or not integer(pid)then return fail('native_damage_identity_clock_PID_required')end
  local hp=S.GetUnitHealth(id);if not finite(hp)then return fail('finite_native_post_damage_health_required')end
  local loss=C.health-hp;C.health=hp
  if attacker~=C.actor then log('PREDATOR_OTHER_DAMAGE','native_baseline_updated=true');return end
  local p=C.projectiles[pid]
  if paralyzer~=false or not finite(damage)or damage<=0 or not p or p.frame>S.GetGameFrame()or p.weapon~=weapon or p.hit or loss<=0 then return fail('actual_native_PID_owned_weapon_positive_HP_loss_required')end
  p.hit=true;C.slots[p.slot].hits=C.slots[p.slot].hits+1;log('PREDATOR_NATIVE_HIT','slot='..p.slot,'pid='..pid,'damage='..damage,'health='..hp,'actual_native_authority=true')
 end
 function C.Destroyed(id)
  if C.closed then return end
  if C.preserve[id]then return fail('ordinary_paid_predecessor_destroyed')end
  if id==C.target then return inconclusive('hostile_destroyed_before_complete_frame')end
 end
 return C
end
return M
