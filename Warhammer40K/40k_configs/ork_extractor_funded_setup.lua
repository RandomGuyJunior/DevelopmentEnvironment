-- Owned FUNDED NON-ECONOMY setup; native weapons and extraction stay unchanged.
local M={}
function M.New(S,D,N,W,team,enemy,frame,emit,contract,observer,geometry,cmd,watch,spots,game)
 local Game=game; local UnitDefs=D; local GG={resource_spot_finder=spots}
 local rows,why=contract.Check(D,N,W);assert(rows,'stage_contract:'..tostring(why))
 assert(team~=enemy and not S.AreTeamsAllied(team,enemy),'hostile_team_required')
 for _,name in ipairs({'CreateUnit','DestroyUnit','GiveOrderToUnit','Pos2BuildPos','GetGroundHeight','GetGroundInfo','TestBuildOrder','TestMoveOrder','GetUnitsInRectangle','GetUnitsInCylinder','GetUnitPosition','GetUnitDefID','GetUnitIsDead','GetUnitTeam','GetUnitHealth','GetTeamUnits','IsPosInLos','GetUnitAllyTeam','GetUnitStates','GetUnitCommands'})do assert(type(S[name])=='function','native_setup_API_missing:'..name)end
 assert(type(watch)=='function' and cmd.ATTACK and cmd.FIRE_STATE and cmd.MOVE_STATE,'native_watch_and_commands_required')
 assert(spots,'stock_spot_provider_required')
 local targetDef=N.imp_russ and N.imp_russ.id;assert(targetDef and D[targetDef] and not D[targetDef].canFly and (D[targetDef].speed or 0)>0,'genuine_ground_target_required')
 local anchor;for _,id in ipairs(S.GetTeamUnits(team)or{})do if S.GetUnitDefID(id)==(N.ork_big_mek_commander or{}).id and not S.GetUnitIsDead(id)then anchor=id;break end end
 assert(anchor,'actual_Ork_commander_required')
 local C={owned={},actors={},targets={},started=frame,phase='actors'}
 local function add(def,pos,owner)
  local id=S.CreateUnit(def,pos[1],pos[2],pos[3],pos[4]or 0,owner,false,false);assert(id,'native_setup_creation_failed')
  C.owned[#C.owned+1]=id
  local hp,_,_,_,progress=S.GetUnitHealth(id);assert(hp and hp>0 and progress==1 and S.GetUnitDefID(id)==def and S.GetUnitTeam(id)==owner,'native_setup_actor_not_finished')
  assert(S.GiveOrderToUnit(id,cmd.FIRE_STATE,{0},{})==true,'native_setup_state_dispatch_refused');local mobile=(D[def].speed or 0)>0;if mobile then assert(S.GiveOrderToUnit(id,cmd.MOVE_STATE,{0},{})==true,'native_setup_move_dispatch_refused')end;local state=S.GetUnitStates(id);assert(state and state.firestate==0 and(not mobile or state.movestate==0),'native_setup_state_not_applied')
  local box,reason=geometry.Envelope(S,D,id);assert(box,'actual_geometry:'..tostring(reason))
  assert(box.minX>0 and box.minZ>0 and box.maxX<Game.mapSizeX and box.maxZ<Game.mapSizeZ,'actual_geometry_outside_map')
  for _,other in ipairs(S.GetUnitsInRectangle(box.minX,box.minZ,box.maxX,box.maxZ)or{})do if other~=id and not S.GetUnitIsDead(other)then assert(geometry.Outside(S,D,other,id)==true,'actual_geometry_overlap')end end
  return id
 end
 local function choose(def,builder,metal)
 local cx,_,cz=S.GetUnitPosition(builder);local d=UnitDefs[def]
 if metal then
  local api=GG.resource_spot_finder
  if not api then return end -- Never bypass stock spot admission with a guessed pixel.
  if not api.isMetalMap then
   if type(api.metalSpotsList)~='table'or type(api.GetBuildingPositions)~='function'or type(api.IsMexPositionValid)~='function'then return end
   local candidates={}
   for _,spot in ipairs(api.metalSpotsList)do for _,p in ipairs(api.GetBuildingPositions(spot,def,0,true)or{})do
    local distance=(p.x-cx)^2+(p.z-cz)^2
    if distance<=2048^2 then candidates[#candidates+1]={spot=spot,x=p.x,z=p.z,distance=distance}end
   end end
   table.sort(candidates,function(a,b)if a.distance~=b.distance then return a.distance<b.distance end;if a.x~=b.x then return a.x<b.x end;return a.z<b.z end)
   for _,c in ipairs(candidates)do
    local x,y,z=S.Pos2BuildPos(def,c.x,0,c.z,0);y=S.GetGroundHeight(x,z)
    local status,feature=S.TestBuildOrder(def,x,y,z,0)
    if x>d.xsize*4+32 and z>d.zsize*4+32 and x<Game.mapSizeX-d.xsize*4-32 and z<Game.mapSizeZ-d.zsize*4-32
     and status==2 and not feature and api.IsMexPositionValid(c.spot,x,z)
     and #(S.GetUnitsInRectangle(x-d.xsize*4-32,z-d.zsize*4-32,x+d.xsize*4+32,z+d.zsize*4+32)or{})==0 then
     local free=true
     for _,id in ipairs(S.GetUnitsInCylinder(c.spot.x,c.spot.z,Game.extractorRadius or 96)or{})do
      local existing=UnitDefs[S.GetUnitDefID(id)]
      if existing and(existing.extractsMetal or 0)>0 and S.GetUnitIsDead(id)==false then free=false;break end
     end
     if free then emit('STOCK_MEX_SITE','x='..x,'z='..z,'full_yield_provider=true','final_snapped_valid=true');return{x,y,z,0}end
    end
   end
   return
  end
 end
 for ring=6,64 do for angle=0,15 do
  local a=angle*math.pi/8;local x,y,z=S.Pos2BuildPos(def,cx+ring*32*math.cos(a),0,cz+ring*32*math.sin(a),0)
  if x>d.xsize*4+32 and z>d.zsize*4+32 and x<Game.mapSizeX-d.xsize*4-32 and z<Game.mapSizeZ-d.zsize*4-32 then
   y=S.GetGroundHeight(x,z);local status,feature=S.TestBuildOrder(def,x,y,z,0)
   if status==2 and not feature and #(S.GetUnitsInRectangle(x-d.xsize*4-32,z-d.zsize*4-32,x+d.xsize*4+32,z+d.zsize*4+32)or{})==0
    and(not metal or(select(3,S.GetGroundInfo(x,z))or 0)>0)then return{x,y,z,0}end
  end
 end end
end

 local function targetSite(actor,weapon)
  local d=D[targetDef];local x,_,z=S.GetUnitPosition(actor);local range=W[weapon].range
  local sight=D[S.GetUnitDefID(actor)].losRadius
  assert(type(range)=='number'and range>0 and type(sight)=='number'and sight>0,'native_range_LOS_definition_required')
  local radius=math.min(range*.65,sight*.75)
  for ring=1,4 do for angle=0,31 do
   local a=angle*math.pi/16;local tx,tz=x+radius*(.7+.1*ring)*math.cos(a),z+radius*(.7+.1*ring)*math.sin(a)
   local ty=S.GetGroundHeight(tx,tz);local status,feature=S.TestBuildOrder(targetDef,tx,ty,tz,0)
   if tx>d.xsize*4+32 and tz>d.zsize*4+32 and tx<Game.mapSizeX-d.xsize*4-32 and tz<Game.mapSizeZ-d.zsize*4-32
    and status==2 and not feature and ty>=0 and S.TestMoveOrder(targetDef,tx,ty,tz)==true and S.IsPosInLos(tx,ty,tz,S.GetUnitAllyTeam(actor))==true
    and #(S.GetUnitsInRectangle(tx-d.xsize*4-32,tz-d.zsize*4-32,tx+d.xsize*4+32,tz+d.zsize*4+32)or{})==0 then return{tx,ty,tz,0}end
  end end
 end
 function C.Close()
  if C.closed then return end;C.closed=true;if C.observer then C.observer.Close()end
  for _,id in ipairs(C.owned)do if not S.GetUnitIsDead(id)then S.DestroyUnit(id,false,true)end end
  emit('OWNED_SETUP_CLEANUP','funded_setup_only=true reclaim_cleanup_not_entitlement_acceptance=true')
 end
 function C.Step(f)
  if C.closed then return end
  if f-C.started>2400 then return'INCONCLUSIVE funded_setup_or_combat_timeout'end
  if C.phase=='actors'then
   for tier,row in ipairs(rows)do
    local def=N[row.key].id;assert((D[def].speed or 0)==0,'genuine_fixed_extractor_must_be_immobile');local site=choose(def,anchor,true)
    if not site then return'INCONCLUSIVE legal_stock_metal_site_unavailable_tier_'..tier end
    C.actors[tier]=add(def,site,team)
    emit('FUNDED_SETUP_ACTOR','tier='..tier,'id='..C.actors[tier],'stock_mex_site=true normal_economy_not_tested=true')
   end
   C.phase='targets';C.waitUntil=f+30;return
  end
  if C.phase=='targets'then
   if f<C.waitUntil then return end
   for tier,actor in ipairs(C.actors)do local weapon=D[S.GetUnitDefID(actor)].weapons[1].weaponDef;local pos=targetSite(actor,weapon)
    if not pos then return'INCONCLUSIVE legal_naturally_visible_ground_target_unavailable_tier_'..tier end
    C.targets[tier]=add(targetDef,pos,enemy)
   end
   C.phase='attack';C.waitUntil=f+30;return
  end
  if C.phase=='attack'then
   if f<C.waitUntil then return end
   C.observer=observer.New(S,D,N,W,C.actors,C.targets,team,enemy,f,emit,contract)
   for tier,id in ipairs(C.actors)do local wd=D[S.GetUnitDefID(id)].weapons[1].weaponDef;watch(wd,true);assert(S.GiveOrderToUnit(id,cmd.ATTACK,{C.targets[tier]},{})==true,'native_ATTACK_dispatch_refused');local queue=S.GetUnitCommands(id,1);assert(queue and queue[1] and queue[1].id==cmd.ATTACK and queue[1].params and queue[1].params[1]==C.targets[tier],'native_ATTACK_queue_not_applied');emit('NORMAL_NATIVE_ATTACK','tier='..tier,'actor='..id,'target='..C.targets[tier],'no_weapon_physics_edits=true')end
   C.phase='combat'
  end
  if C.observer then return C.observer.Step(f)end
 end
 function C.Projectile(...)if C.observer then C.observer.Projectile(...)end end
 function C.Damaged(...)if C.observer then C.observer.Damaged(...)end end
 return C
end
return M
