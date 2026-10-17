-- Fresh, default-off approved-hull diagnostic. Direct spawns only; not economy.
-- No damage, reload, HP, resource or simulation-speed modifications. Passive
-- air targets receive native idle-fly/height settings once during setup only.
local M={Version=7,Option='prototype_ork_gunship_native_fixture',Mode='prototype_ork_gunship_native_mode'}
local function yes(v)return v==true or v==1 or v=='1'end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function numbers(...)for i=1,select('#',...)do if not finite(select(i,...))then return false end end;return true end
local function wrap(a)return(a+math.pi)%(2*math.pi)-math.pi end
local function path(v,prefix)return tostring(v or''):gsub('\\','/'):gsub('^'..prefix..'/','')end
local groupNames={'nose','port_fore','port_aft','starboard_fore','starboard_aft','port_gantry','starboard_gantry'}
function M.Validate(D,N,W,o)
 assert(yes(o[M.Option])and o[M.Mode]=='human','Explicit user-controlled approved Gunship diagnostic required')
 assert(yes(o.prototype_source_progression)and yes(o.prototype_development_playtest)and not yes(o.prototype_ork_advanced_air_development),'Normal graph identities required')
 assert(o.prototype_diagnostic=='normal'and tonumber(o.prototype_test_speed or 1)==1,'Unscaled native clock required')
 for k,v in pairs(o)do if yes(v)and k~=M.Option and(k:match('_fixture$')or k:match('benchmark')or k:match('probe')or k=='prototype_burna_flame_combat')then error('Conflicting diagnostic '..k)end end
 local pn,tn=assert(N.ork_gunship),assert(N.ork_deff_dread);local p,t=D[pn.id],D[tn.id];local cp=p and p.customParams or{}
 assert(p and p.canFly and p.canMove and p.canAttack and not p.isBuilder and p.metalCost==4600 and p.energyCost==64000 and p.buildTime==60000,'Real unmodified Gunship required')
 assert(path(p.modelname,'objects3d')=='40k/ork_gunship.glb'and path(p.scriptName,'scripts')=='40k_ork_gunship.lua'and cp.prototype40k_source_asset=='MOW-02','Exact model/script required')
 assert(tonumber(cp.prototype40k_gunship_loadout_revision)==4 and cp.prototype40k_gunship_loadout_policy=='gunship_approved_kan_turrets_no_bomb_v5'and tonumber(cp.prototype40k_gunship_runtime_revision)==11 and tonumber(cp.prototype40k_gunship_mount_count)==7 and #p.weapons==7,'Current seven-turret air/ground runtime with native MG bursts and alternating cannons required')
 assert(t and t.health>1360 and not t.canFly and(t.customParams or{}).animsource=='ork_deff_dread','Genuine surviving native Dread targets required')
 local an=assert(N.corcrwh,'Actual native Dragon VTOL target required');local a=assert(D[an.id])
 assert(a.canFly and a.hoverAttack and path(a.modelname,'objects3d'):lower()=='units/corcrwh.s3o','Genuine native hovering VTOL geometry required')
 local r={product=pn.id,target=tn.id,airTarget=an.id,groups={},mounts={},byWeapon={},fighters={}}
 for _,entry in ipairs({{'corveng',125},{'corvamp',160}})do
  local fn=assert(N[entry[1]],'Actual native fighter required '..entry[1]);local f=assert(D[fn.id])
  assert(f.canFly and not f.hoverAttack and f.isFighterAirUnit and f.cruiseAltitude==entry[2]and path(f.modelname,'objects3d'):lower()=='units/'..entry[1]..'.s3o','Unmodified named native fixed-wing fighter required')
  assert(numbers(f.xsize,f.zsize,f.radius)and f.xsize>0 and f.zsize>0 and f.radius>0 and f.radius<=256,'Actual bounded fighter footprint/model radius required')
  r.fighters[entry[1]]={def=fn.id,cruiseAltitude=entry[2],halfX=math.max(f.xsize*4,f.radius)+16,halfZ=math.max(f.zsize*4,f.radius)+16}
 end
 for i,name in ipairs(groupNames)do
  local g={name=name,index=i,primary=#r.mounts+1,mounts={},kind=i==1 and'nose'or i<=5 and'cannon'or'shoota'}
  for _,field in ipairs({'yaw_center','yaw_limit','pitch_down_limit','pitch_up_limit'})do g[field]=assert(tonumber(cp['prototype40k_'..name..'_'..field]));assert(finite(g[field]),'Finite measured envelope required')end
  assert(g.yaw_limit>math.rad(2)and(g.kind=='shoota'and g.pitch_down_limit>=0 or g.pitch_down_limit>0)and g.pitch_up_limit>=0,'Useful measured articulation required')
  if g.kind=='shoota'then assert(math.abs(g.yaw_limit-math.pi)<.00001 and math.abs(g.pitch_up_limit-math.pi/2)<.00001,'Full360 yaw and90 upward AA envelope required')end
  local n=i;local wid=p.weapons[n].weaponDef;local w=assert(W[wid]);local wc=w.customParams or{}
  local count=g.kind=='shoota'and 4 or 1
  assert(not r.byWeapon[wid]and w.type==(g.kind=='shoota'and'LaserCannon'or'Cannon')and w.range==(g.kind=='cannon'and 1470 or 1100),'Distinct current native turret weapon classes/ranges required')
  assert(w.salvoSize==(g.kind=='shoota'and 15 or 1)and w.projectiles==count and finite(w.reload)and math.abs(w.reload-(g.kind=='shoota'and 2.4 or g.kind=='cannon'and 1.75 or 8))<.00001,'Native four-barrel MG bursts and alternating single cannon shots required')
  -- Native WeaponDef defaults to2 (owner-toggle), not0. CCannon starts
  -- LOW unless its definition is1; only default2 follows the owner's toggle.
  -- The unchanged nose uses that default. Read its actual owner state after
  -- birth below instead of rejecting a legitimate default as a content error.
  local mode=w.highTrajectory
  assert(g.kind=='cannon'and mode==1 or g.kind=='shoota'and mode==0 or g.kind=='nose'and(mode==0 or mode==2),'Exact native high-arc recessed/low-arc-capable nose and MG modes required')
  if g.kind=='nose'then r.noseTrajectoryMode=mode end
  if g.kind=='shoota'then assert(finite(w.salvoDelay)and math.abs(w.salvoDelay-.1)<.00001,'Native MG intra-burst cadence required')end
  assert(wc.source_aimpiece==name..'_yaw','Measured yaw mount binding required')
  local row={slot=n,stem=name,group=g,weapon=wid,muzzleNames={},pitchNames={},volleyCount=count}
  if i==1 then row.muzzleNames={'nose_muzzle'};row.pitchNames={'nose_pitch'}
  else for _,side in ipairs({'left','right'})do
   row.pitchNames[#row.pitchNames+1]=name..'_'..side..'_pitch'
   if g.kind=='shoota'then for barrel=1,2 do row.muzzleNames[#row.muzzleNames+1]=name..'_'..side..'_muzzle_'..barrel end
   else row.muzzleNames[#row.muzzleNames+1]=name..'_'..side..'_muzzle'end
  end end
  assert(wc.source_muzzle==row.muzzleNames[1],'Exact first native Query muzzle binding required')
  r.mounts[n]=row;r.byWeapon[wid]=n;g.mounts[1]=n
  r.groups[i]=g
 end
 return r
end
function M.New(S,D,N,W,G,Script,Game,CMD,o,unusedGeometry,emit)
 local C={phase='initial',owned={},initial={},projectiles={},query={},shot={},hits={},used={},poses={},targetHP={},targets={},pairShots={},humanTargets={}}
 local human=o[M.Mode]=='human'
 local function log(event,...)
  local a={...};for _,v in ipairs({'schema=7','direct_spawn_diagnostic=true','resource_grants=false','ordinary_progression_accepted=false','visual_accepted=false','salvage_accepted=false','mode='..tostring(o[M.Mode])})do a[#a+1]=v end
  emit('APPROVED_'..event,unpack(a))
 end
 local function live(id,def,team)
  if not id or not S.ValidUnitID(id)or S.GetUnitIsDead(id)or S.GetUnitDefID(id)~=def or S.GetUnitTeam(id)~=team then return false end
  local hp,_,_,_,p=S.GetUnitHealth(id);return finite(hp)and hp>0 and p==1
 end
 local function finish(reason)
  if C.result then return C.result end;C.result=reason
  for id,row in pairs(C.initial)do local ok=live(id,row.def,row.team);if not ok then C.result='FAIL initial_actor_changed'end;log('INITIAL_PRESERVED','id='..id,'def='..row.def,'team='..row.team,'alive='..tostring(ok))end
  log('COMPLETE',C.result,'frame='..S.GetGameFrame());return C.result
 end
 local function fail(reason)return finish('FAIL '..reason)end
 local function localAxis(dx,dy,dz)
  local front,up,right=S.GetUnitVectors(C.body)
  if not(front and up and right)then return end
  local function dot(v)return dx*v[1]+dy*v[2]+dz*v[3]end
  return math.atan2(-dot(right),dot(front)),math.asin(math.max(-1,math.min(1,dot(up))))
 end
 local function targetPosition(g,phase,x,z,front,right)
  local offset=math.min(g.yaw_limit*.35,math.rad(g.index==1 and 2 or 12))
  local bias=g.name:match('_fore$')and 1 or g.name:match('_aft$')and-1 or 0
  local angle=g.yaw_center+offset*(phase==1 and 1 or-1)+bias*math.min(g.yaw_limit*.25,math.rad(10))
  -- New safe cruise125 and the forward gantry offsets need this body-origin
  -- radius to reach ground inside the unchanged12.5-degree depression limit.
  local distance=g.index==1 and(phase==1 and 730 or 890)or g.kind=='shoota'and 1100 or(g.name:match('_fore$')and 580 or 750)+(phase==2 and 70 or 0)
  local tx=x+(-right[1]*math.sin(angle)+front[1]*math.cos(angle))*distance
  local tz=z+(-right[3]*math.sin(angle)+front[3]*math.cos(angle))*distance
  return tx,S.GetGroundHeight(tx,tz),tz,angle
 end
 local function targetSiteValid(tx,ty,tz)
  if tx<40 or tz<40 or tx>Game.mapSizeX-40 or tz>Game.mapSizeZ-40 then return false,'target_border'end
  if ty<0 then return false,'target_ground'end
  if not S.TestMoveOrder(C.route.target,tx,ty,tz,0,0,0,true,true,false)then return false,'target_native_move'end
  if #(S.GetUnitsInRectangle(tx-40,tz-40,tx+40,tz+40)or{})>0 then return false,'target_units'end
  return true,'accepted'
 end
 local function humanGroundPosition(g,index,x,z,front,right)
  local distance=({300,800,1370})[index]
  local band=({'near_blindzone_probe','mid','far'})[index]
  -- Fore/aft on each side share their measured yaw center. Separate their
  -- targets by24 degrees; near300 then has124.7 units of clearance. The
  -- smaller band stagger remains inside the actual30-degree cannon sector.
  local side=g.name:match('^port_')and 1 or -1
  local fore=g.name:match('_fore$')and 1 or -1
  local angle=g.yaw_center+side*fore*math.rad(12)+(index-2)*math.rad(2)
  local tx=x+(-right[1]*math.sin(angle)+front[1]*math.cos(angle))*distance
  local tz=z+(-right[3]*math.sin(angle)+front[3]*math.cos(angle))*distance
  return tx,S.GetGroundHeight(tx,tz),tz,distance,band,angle
 end
 local function plannedTargets(x,z)
  if human then
   for _,g in ipairs(C.route.groups)do if g.kind=='cannon'then for index=1,3 do
    local tx,ty,tz=humanGroundPosition(g,index,x,z,{0,0,1},{-1,0,0})
    local ok,why=targetSiteValid(tx,ty,tz);if not ok then return false,index,why..'_'..g.name end
   end end end
   return true,12,'human_ground_sites_accepted_air_clearance_checked_at_birth'
  end
  local checks=0
  -- Facing0's supported native +Z flight order aims150units ahead. Native
  -- arrival radius may stop it earlier; this is only a conservative preflight
  -- estimate. Actual live target positions/terrain are checked
  -- again from the real post-flight unit vectors below, without moving terrain.
  -- Human mode has no flight order and only its initial seven comparison targets.
  local flightZ=human and z or z+150;local lastPhase=human and 1 or 2
  for phase=1,lastPhase do for _,g in ipairs(C.route.groups)do
   local tx,ty,tz=targetPosition(g,phase,x,flightZ,{0,0,1},{-1,0,0})
   checks=checks+1;local ok,why=targetSiteValid(tx,ty,tz)
   if not ok then return false,checks,why..'_'..phase..'_'..g.name end
  end end
  return true,checks,'accepted'
 end
 local function site()
  local candidate=0
  for _,xf in ipairs({.5,.3,.7,.4,.6,.2,.8})do for _,zf in ipairs({.4,.6,.25,.35,.5,.65,.75})do
   local x,z=Game.mapSizeX*xf,Game.mapSizeZ*zf;local y=S.GetGroundHeight(x,z)
   candidate=candidate+1
   local border=x>1550 and z>1550 and x<Game.mapSizeX-1550 and z<Game.mapSizeZ-1550
   local units=#(S.GetUnitsInRectangle(x-1000,z-1000,x+1000,z+1000)or{})
   local targetsValid,checks,why=false,0,'border'
   if border then why='spawn_ground';if y>=0 then why='initial_units';if units==0 then targetsValid,checks,why=plannedTargets(x,z)end end end
   local accepted=border and y>=0 and units==0 and targetsValid
   -- Trees elsewhere in the flight/test area do not invalidate a whole site.
   -- Actual target sites still require native terrain/object TestMoveOrder and
   -- no occupied target square below. No feature is removed or bypassed.
   log('SITE','candidate='..candidate,'x='..x,'y='..y,'z='..z,'border='..tostring(border),'units='..units,'target_checks='..checks,'targets_valid='..tostring(targetsValid),'reason='..why,'accepted='..tostring(accepted))
   if accepted then return{x,y,z}end
  end end
 end
 local function targets(phase)
  local x,_,z=S.GetUnitPosition(C.body);local front,_,right=S.GetUnitVectors(C.body)
  for _,g in ipairs(C.route.groups)do
   -- Radial staggering prevents the three same-side targets sharing AoE.
   local tx,ty,tz,angle=targetPosition(g,phase,x,z,front,right)
   local ok,why=targetSiteValid(tx,ty,tz);if not ok then return nil,'live_'..why..'_'..g.name end
   local id=S.CreateUnit('ork_deff_dread',tx,ty,tz,0,1)
   if not live(id,C.route.target,1)or C.initial[id]then return nil,'target_birth_'..g.name end
   C.owned[id]={def=C.route.target,team=1};C.targetHP[id]=S.GetUnitHealth(id);C.targets[g.name]=id
   S.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},0)
   log('TARGET','phase='..phase,'group='..g.name,'id='..id,'hp='..C.targetHP[id],'x='..tx,'y='..ty,'z='..tz,'angle='..angle)
  end
  return true
 end
 local function humanTargets()
  local x,_,z=S.GetUnitPosition(C.body);local front,_,right=S.GetUnitVectors(C.body)
  for _,g in ipairs(C.route.groups)do if g.kind=='cannon'then for index=1,3 do
   -- Near300 deliberately probes the geometric blind zone. It is not a
   -- promised firing position: unchanged safe depression is only20 degrees.
   local tx,ty,tz,distance,band=humanGroundPosition(g,index,x,z,front,right)
   local ok,why=targetSiteValid(tx,ty,tz);if not ok then return nil,'human_ground_'..why..'_'..g.name..'_'..band end
   local id=S.CreateUnit('ork_deff_dread',tx,ty,tz,0,1)
   if not live(id,C.route.target,1)or C.initial[id]then return nil,'human_ground_birth'end
   C.owned[id]={def=C.route.target,team=1};C.targetHP[id]=S.GetUnitHealth(id)
   C.humanTargets[#C.humanTargets+1]={id=id,label=g.name..'_'..band,air=false}
   S.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},0)
   log('TARGET','label='..g.name..'_'..band,'domain=ground','id='..id,'body_radius='..distance,'x='..tx,'y='..ty,'z='..tz,'range_claim=actual_muzzle_readback_required')
  end end end
  -- Three stock Dragon targets provide high articulation checks. Two actual
  -- native fighters retain their ordinary flight model/cruise and receive ONE
  -- initial outward MOVE to take off, then native idle circling with Hold Fire.
  -- No Gunship order, forced position, script movement takeover or later orders.
  if not(S.MoveCtrl and type(S.MoveCtrl.SetGunshipMoveTypeData)=='function'and type(S.GetUnitMoveTypeData)=='function'and CMD.IDLEMODE)then return nil,'native_passive_hover_api_missing'end
  -- Measured inboard AA floors reach65 degrees to clear the main hull.
  -- These genuinely high targets exercise every azimuth within1100 range
  -- without deliberately presenting impossible low rear/inboard trajectories.
  for _,a in ipairs({{'mouth_high_frontal',0,700,650},{'right_T2_fighter',math.pi/2,650,160,'corvamp'},{'rear',math.pi,250,980},{'left_T1_fighter',-math.pi/2,650,125,'corveng'},{'AA_zenith',0,60,760}})do
   local tx=x+(-right[1]*math.sin(a[2])+front[1]*math.cos(a[2]))*a[3]
   local tz=z+(-right[3]*math.sin(a[2])+front[3]*math.cos(a[2]))*a[3];local ground=S.GetGroundHeight(tx,tz)
   if tx<100 or tz<100 or tx>Game.mapSizeX-100 or tz>Game.mapSizeZ-100 or ground<0 then return nil,'human_air_site_'..a[1]end
   local fighter=a[5]and C.route.fighters[a[5]];local def=fighter and fighter.def or C.route.airTarget
   local birthY=fighter and ground or ground+a[4]
   if fighter then
    if not(S.TestBuildOrder and S.GetFeaturesInRectangle and CMD.MOVE)then return nil,'native_fixedwing_site_api'end
    local hx,hz=fighter.halfX,fighter.halfZ
    local status,feature=S.TestBuildOrder(def,tx,ground,tz,0)
    if tx<hx+40 or tz<hz+40 or tx>Game.mapSizeX-hx-40 or tz>Game.mapSizeZ-hz-40 or status~=2 or feature~=nil
     or #(S.GetUnitsInRectangle(tx-hx,tz-hz,tx+hx,tz+hz)or{})>0 or #(S.GetFeaturesInRectangle(tx-hx,tz-hz,tx+hx,tz+hz)or{})>0 then return nil,'native_fixedwing_ground_birth_obstructed_'..a[5]end
   end
   local id=S.CreateUnit(a[5]or'corcrwh',tx,birthY,tz,0,1)
   if not live(id,def,1)or C.initial[id]then return nil,'human_air_birth'end
   C.owned[id]={def=def,team=1};C.humanTargets[#C.humanTargets+1]={id=id,label='air_'..a[1],air=true,fighter=fighter~=nil,configuredCruise=fighter and fighter.cruiseAltitude or nil}
   if not fighter then
    if S.MoveCtrl.SetGunshipMoveTypeData(id,{wantedHeight=a[4],dontLand=true})~=2 then return nil,'native_passive_hover_fields'end
    local mt=S.GetUnitMoveTypeData(id);if not mt or mt.name~='gunship'or not finite(mt.wantedHeight)or math.abs(mt.wantedHeight-a[4])>.01 then return nil,'native_passive_hover_readback'end
   end
   S.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},0);S.GiveOrderToUnit(id,CMD.MOVE_STATE,{0},0);S.GiveOrderToUnit(id,CMD.IDLEMODE,{0},0)
   if fighter then
    local dx=(-right[1]*math.sin(a[2])+front[1]*math.cos(a[2]))*150
    local dz=(-right[3]*math.sin(a[2])+front[3]*math.cos(a[2]))*150
    S.GiveOrderToUnit(id,CMD.MOVE,{tx+dx,ground,tz+dz},0)
   end
   log('TARGET','label=air_'..a[1],'domain='..(fighter and'real_native_fixedwing'or'real_native_hover_vtol'),'unit_name='..(a[5]or'corcrwh'),'id='..id,'x='..tx,'y='..birthY,'z='..tz,'configured_cruise='..(fighter and fighter.cruiseAltitude or'unchanged_Dragon'),'initial_hover_height='..(fighter and'unmodified_native_fixedwing'or a[4]),'enemy_initial_takeoff_move='..tostring(fighter~=nil),'airborne_claim=actual_state_and_altitude_readback_required')
  end
  return true
 end
 local function acquired()
  for _,g in ipairs(C.route.groups)do local id=C.targets[g.name];if not live(id,C.route.target,1)or(S.GetUnitLosState(id,S.GetUnitAllyTeam(C.body),false)or{}).los~=true then return false end end;return true
 end
 local function aim()
  for n,m in ipairs(C.route.mounts)do
   -- Exact pinned de6936 implementation uses argument5 for unit targets.
   if S.SetUnitTarget(C.body,C.targets[m.group.name],false,true,n)~=true then return nil,n end
  end;return true
 end
 local function phaseDone()
  for n,m in ipairs(C.route.mounts)do
   if(C.hits[C.pass][n]or 0)<1 or not C.poses[C.pass][n]then return false end
   for _,piece in ipairs(m.muzzles)do if not C.used[C.pass][n][piece]then return false end end
  end
  for _,g in ipairs(C.route.groups)do if #g.mounts==2 then
   local a,b=g.mounts[1],g.mounts[2];local paired=false
   for _,f in ipairs(C.pairShots[C.pass][a]or{})do for _,h in ipairs(C.pairShots[C.pass][b]or{})do if math.abs(f-h)<=15 then paired=true end end end
   if not paired then return false end
  end end
  return true
 end
 -- Human-only readback: no command/target, state, damage or shutdown writes.
 -- Sampling is at most once per30 native frames, with600 changed batches
 -- maximum. State/weapon rows need functional changes; the optional helper
 -- separately budgets startup, active-bob and gate-change observations.
 local humanRead={lastFrame=-30,batches=0,last={},aim={},aimFrame={},volley={},query={},queryFrame={},queryPiece={}}
 local function value(v)
  if type(v)=='number'then return finite(v)and string.format('%.5f',v)or'nonfinite'end
  if type(v)=='table'then return value(v[1])..','..value(v[2])..','..value(v[3])end
  return tostring(v)
 end
 local function read(name,...)
  if type(S[name])~='function'then return'unavailable'end
  local function result(ok,...)
   if not ok then return'read_error'end
   local a={};for i=1,select('#',...)do a[i]=value(select(i,...))end
   return table.concat(a,',')
  end
  return result(pcall(S[name],...))
 end
 function C.HumanAim(id,n,heading,elevation,stage,result,reason,details)
  if not human or C.phase~='human'or id~=C.body or not C.route.mounts[n]then return end
  local a={value(heading),value(elevation),value(stage),value(result),value(reason)}
  if type(details)=='table'then for _,k in ipairs({'resolvedYaw','resolvedPitch','dot','ownYaw','wantedYaw','wantedPitch'})do a[#a+1]=k..':'..value(details[k])end end
  humanRead.aim[n]=table.concat(a,',');humanRead.aimFrame[n]=S.GetGameFrame()
 end
 -- Optional existing script-witness callback. Copy only a fixed read-only
 -- descriptor; no control response or new service exists in normal gameplay.
 function C.HumanHover(id,row)
  if not human or C.phase~='human'or id~=C.body or type(row)~='table'then return end
  humanRead.hover={}
  for _,k in ipairs({'frame','eligible','gate','targetY','actualY','phaseSeconds','gain','speed','running','budget'})do humanRead.hover[k]=row[k]end
 end
 local function humanSnapshot(frame)
  if humanRead.batches>=600 or frame-humanRead.lastFrame<30 then return end
  humanRead.lastFrame=frame
  local rows={};local function changed(key,signature,event,...)
   if humanRead.last[key]==signature then return end
   humanRead.last[key]=signature;rows[#rows+1]={event,...}
  end
  local states=read('GetUnitStates',C.body,false,false,false)
  local command=read('GetUnitCurrentCommand',C.body)
  local mt=S.GetUnitMoveTypeData(C.body)or{}
  local x,y,z=S.GetUnitPosition(C.body);local altitude=numbers(x,y,z)and y-S.GetGroundHeight(x,z)or nil
  local wantedKey=finite(mt.wantedHeight)and math.floor(mt.wantedHeight*2)or'unknown'
  local pitchKey=finite(mt.currentPitch)and math.floor(mt.currentPitch*200)or'unknown'
  changed('unit',states..'|'..command..'|'..value(mt.aircraftState)..'|'..value(wantedKey)..'|'..value(pitchKey),'HUMAN_STATE','body='..C.body,'frame='..frame,'fire_move_repair='..states,'command_id_opts_tag_params='..command,'position='..read('GetUnitPosition',C.body),'velocity='..read('GetUnitVelocity',C.body),'unit_front_up_right='..read('GetUnitVectors',C.body),'aircraft_state='..value(mt.aircraftState),'native_wanted_height='..value(mt.wantedHeight),'actual_altitude='..value(altitude),'configured_cruise='..value((D[C.route.product].customParams or{}).prototype40k_gunship_cruise_altitude),'mouth_native_target='..read('GetUnitWeaponTarget',C.body,1),'bank_pitch='..value(mt.currentBank)..','..value(mt.currentPitch),'native_active='..read('GetUnitIsActive',C.body))
  local h=humanRead.hover
  if h then
   changed('hover',value(h.frame),'HUMAN_HOVER','body='..C.body,'frame='..frame,'helper_frame='..value(h.frame),'eligible='..value(h.eligible),'gate='..value(h.gate),'running='..value(h.running),'budget='..value(h.budget),'phase_seconds='..value(h.phaseSeconds),'gain='..value(h.gain),'helper_speed='..value(h.speed),'target_y='..value(h.targetY),'script_actual_y='..value(h.actualY),'root_objectspace_pos='..read('GetUnitPiecePosition',C.body,C.pieces.root),'aircraft_state='..value(mt.aircraftState),'velocity='..read('GetUnitVelocity',C.body),'command_id_opts_tag_params='..command,'read_only=true')
  else
   changed('hover','not_observed','HUMAN_HOVER','body='..C.body,'frame='..frame,'helper_observed=false','root_objectspace_pos='..read('GetUnitPiecePosition',C.body,C.pieces.root),'aircraft_state='..value(mt.aircraftState),'velocity='..read('GetUnitVelocity',C.body),'command_id_opts_tag_params='..command,'read_only=true')
  end
  local airborneFighters=0
  for _,t in ipairs(C.humanTargets)do
   local tx,ty,tz=S.GetUnitPosition(t.id);local tm=t.air and S.GetUnitMoveTypeData(t.id)or{}
   local altitude=numbers(tx,ty,tz)and ty-S.GetGroundHeight(tx,tz)or nil
   local airborne=t.air and finite(altitude)and altitude>40 and(tm.aircraftState=='flying'or tm.aircraftState=='hovering')
   if t.fighter and tm.name=='airplane'and tm.aircraftState=='flying'and airborne then airborneFighters=airborneFighters+1 end
   changed('target'..t.id,read('GetUnitHealth',t.id)..'|'..value(tm.aircraftState),'HUMAN_TARGET','id='..t.id,'label='..t.label,'frame='..frame,'position='..read('GetUnitPosition',t.id),'native_aim_position='..read('GetUnitPosition',t.id,false,true),'hp='..read('GetUnitHealth',t.id),'move_type='..value(tm.name),'aircraft_state='..value(tm.aircraftState),'configured_cruise='..value(t.configuredCruise),'actual_wanted_height='..value(tm.wantedHeight),'actual_altitude='..value(altitude),'airborne_observed='..tostring(airborne),'unit_def='..read('GetUnitDefID',t.id))
  end
  if airborneFighters==2 and not humanRead.fightersAirborne then humanRead.fightersAirborne=true;log('HUMAN_FIGHTERS_AIRBORNE','frame='..frame,'actual_airplane_flying_altitude40_count=2','configured_cruise_not_measured_height=true','controls_unchanged=true')end
  for n,m in ipairs(C.route.mounts)do
   local target=read('GetUnitWeaponTarget',C.body,n)
   local state=read('GetUnitWeaponState',C.body,n)
   local aim=humanRead.aim[n]or'not_observed'
   local muzzles={};for i,piece in ipairs(m.muzzles)do muzzles[i]=value(piece)..':'..read('GetUnitPiecePosDir',C.body,piece)end
   local v=humanRead.volley[n]or{};local distances={};local targetType,_,targetID=S.GetUnitWeaponTarget(C.body,n);local cadence={}
   for _,shot in ipairs(v.recent or{})do cadence[#cadence+1]=shot.frame..':'..shot.count end
   if targetType==1 and type(targetID)=='number'then local _,_,_,tx,ty,tz=S.GetUnitPosition(targetID,false,true)
    if numbers(tx,ty,tz)then for i,piece in ipairs(m.muzzles)do local mx,my,mz=S.GetUnitPiecePosDir(C.body,piece)
     if numbers(mx,my,mz)then distances[i]=string.format('%.3f',math.sqrt((tx-mx)^2+(ty-my)^2+(tz-mz)^2))end
    end end
   end
   changed(n,target..'|'..state..'|'..aim..'|'..value(v.total),'HUMAN_WEAPON','body='..C.body,'frame='..frame,'slot='..n,'group='..m.group.name,'target_type_user_value='..target,'angle_ready_reload_salvo_stock='..state,'aim_callback_frame='..value(humanRead.aimFrame[n]),'aim_heading_elevation_stage_result_reason='..aim,'native_weapon_pos_vector='..read('GetUnitWeaponVectors',C.body,n),'actual_muzzle_pos_dir='..table.concat(muzzles,';'),'muzzle_to_native_target_aim_distances='..table.concat(distances,','),'projectile_total='..value(v.total),'latest_projectile_frame='..value(v.frame),'latest_same_frame_projectiles='..value(v.count),'expected_native_volley='..m.volleyCount,'recent_projectile_frame_counts='..table.concat(cadence,','),'weapon_target_observed_on_projectile='..value(v.targetOnProjectile),'latest_native_query='..value(humanRead.query[n]),'latest_birth_vectors='..table.concat(v.birthVectors or{},';'),'birth_vectors_not_hit_acceptance=true')
  end
  if #rows==0 then return end
  humanRead.batches=humanRead.batches+1
  for _,row in ipairs(rows)do log(unpack(row))end
  if humanRead.batches==600 then log('HUMAN_WITNESS_LIMIT','frame='..frame,'changed_batches=600','controls_unchanged=true')end
 end
 function C.Step(frame)
  if C.result then return C.result end;if frame==0 then return end
  if C.phase=='initial'then
   if frame~=1 or Game.gameSpeed~=30 then return fail('fresh_frame1_clock30_required')end
   local ok,r=pcall(M.Validate,D,N,W,o);if not ok then return fail('source_contract_'..tostring(r))end;C.route=r;C.started=frame
   if G.Recoil40KStompaWeaponWitness or S.AreTeamsAllied(0,1)or S.GetGaiaTeamID()==1 then return fail('sole_owned_hostile_scene_required')end
   for _,key in ipairs({'GetUnitWeaponVectors','GetUnitPiecePosDir','GetProjectilePosition','GetUnitWeaponState','GetUnitVectors','SetUnitTarget','GetUnitLosState','TestMoveOrder'})do if type(S[key])~='function'then return fail('native_api_'..key)end end
   for _,id in ipairs(S.GetAllUnits()or{})do C.initial[id]={def=S.GetUnitDefID(id),team=S.GetUnitTeam(id)};log('INITIAL','id='..id,'def='..C.initial[id].def,'team='..C.initial[id].team)end
   local p=site();if not p then return finish('INCONCLUSIVE isolated_site_unavailable')end
   C.body=S.CreateUnit('ork_gunship',p[1],p[2],p[3],0,0);if not live(C.body,r.product,0)or C.initial[C.body]then return fail('direct_owned_gunship_birth')end
   C.owned[C.body]={def=r.product,team=0}
   local ownerState=type(S.GetUnitStates)=='function'and S.GetUnitStates(C.body)
   local useHigh;if type(ownerState)=='table'then useHigh=ownerState.trajectory end
   log('HUMAN_NATIVE_TRAJECTORY','nose_mode='..tostring(r.noseTrajectoryMode),'owner_use_high='..tostring(useHigh),'native_read_available='..tostring(type(useHigh)=='boolean'),'readonly=true')
   if r.noseTrajectoryMode==2 and useHigh==true then return fail('native_nose_owner_high_trajectory')end
   C.origin={S.GetUnitPosition(C.body)};C.pieces=S.GetUnitPieceMap(C.body)or{}
   for n,m in ipairs(r.mounts)do m.muzzles={};for _,name in ipairs(m.muzzleNames)do m.muzzles[#m.muzzles+1]=assert(C.pieces[name],'Missing actual piece '..name)end;assert(C.pieces[m.group.name..'_yaw'],'Missing actual yaw articulation');for _,name in ipairs(m.pitchNames)do assert(C.pieces[name],'Missing actual pitch '..name)end;Script.SetWatchProjectile(m.weapon,true)end
   C.watching=true;G.Recoil40KStompaWeaponWitness=C
   S.GiveOrderToUnit(C.body,CMD.FIRE_STATE,{0},0)
   log('SPAWN','body='..C.body,'def='..r.product,'team=0','frame='..frame)
   if human then
    C.pass=1;local ok,why=humanTargets();if not ok then return finish('INCONCLUSIVE '..why)end
    for n=6,7 do local w=W[r.mounts[n].weapon]
     log('HUMAN_AA_NATIVE_PROFILE','slot='..n,'type='..value(w.type),'accuracy='..value(w.accuracy),'spray_angle='..value(w.sprayAngle),'moving_accuracy='..value(w.movingAccuracy),'target_move_error='..value(w.targetMoveError),'predict_boost='..value(w.predictBoost),'target_border='..value(w.targetBorder),'high_trajectory='..value(w.highTrajectory),'raw_postprocessed_native_values=true','hit_acceptance=false')
    end
    for n=1,5 do local w=W[r.mounts[n].weapon]
     log('HUMAN_CANNON_NATIVE_PROFILE','slot='..n,'high_trajectory='..value(w.highTrajectory),'range='..value(w.range),'native_projectiles='..value(w.projectiles),'native_reload='..value(w.reload),'raw_postprocessed_native_values=true','hit_acceptance=false')
    end
    C.phase='human';log('HUMAN_READY','body='..C.body,'ground_targets=12','real_fixedwing_targets=2','high_hover_targets=3','enemy_initial_takeoff_orders=2','own_ship_autoMove=false','near_blindzone_mid_far_body_radii=300,800,1370','near300_firing_not_promised=true','no_autoclose=true','native_accepted=false');return
   end
   S.GiveOrderToUnit(C.body,CMD.MOVE,{p[1],p[2],p[3]+150},0);C.phase='flight';C.stable=0;return
  end
  if human then humanSnapshot(frame);return end
  if frame-C.started>900 then return finish('INCONCLUSIVE bounded_30s_'..C.phase)end
  if not live(C.body,C.route.product,0)then return fail('owned_gunship_lost_or_transferred')end
  if C.phase=='flight'and frame%15==0 then
   local x,y,z=S.GetUnitPosition(C.body);local vx,vy,vz=S.GetUnitVelocity(C.body);local altitude=y-S.GetGroundHeight(x,z)
   if not numbers(x,y,z,vx,vy,vz,altitude)then return fail('native_flight_readback')end
   local moved=(x-C.origin[1])^2+(z-C.origin[3])^2>=50^2
   local stable=altitude>=40 and moved and vx*vx+vy*vy+vz*vz<.25;C.stable=stable and C.stable+1 or 0
   log('FLIGHT','frame='..frame,'altitude='..altitude,'travel='..math.sqrt((x-C.origin[1])^2+(z-C.origin[3])^2),'stable='..C.stable)
   if C.stable>=2 then C.pass=1;C.hits[1]={};C.used[1]={};C.poses[1]={};C.pairShots[1]={};for n=1,13 do C.used[1][n]={}end
    local ok,why=targets(1);if not ok then return finish('INCONCLUSIVE '..why)end;C.phase='los';C.stage=frame
   end
  elseif C.phase=='los'then
   if acquired()then local ok,n=aim();if not ok then return finish('INCONCLUSIVE native_target_assignment_'..n)end;C.phase='combat';C.stage=frame;log('AIM','phase='..C.pass,'frame='..frame,'all_native_targets=true')
   elseif frame-C.stage>90 then return finish('INCONCLUSIVE natural_target_LOS')end
  elseif C.phase=='combat'then
   if phaseDone()then
    log('PHASE','phase='..C.pass,'frame='..frame,'all13_HP_hits=true','all17_muzzles=true','all6_shoulder_pairs=true')
    if C.pass==2 then
     for _,g in ipairs(C.route.groups)do local n=g.primary;local delta=math.abs(wrap(C.poses[2][n]-C.poses[1][n]));if delta<math.rad(1)then return finish('INCONCLUSIVE articulation_delta_'..g.name)end;log('ROTATION','group='..g.name,'phase1='..C.poses[1][n],'phase2='..C.poses[2][n],'delta='..delta)end
     return finish('PASS native13_two_pose_projectile_HP_pair_and_muzzle_checks')
    end
    S.SetUnitTarget(C.body,nil);C.pass=2;C.hits[2]={};C.used[2]={};C.poses[2]={};C.pairShots[2]={};for n=1,13 do C.used[2][n]={}end
    local ok,why=targets(2);if not ok then return finish('INCONCLUSIVE '..why)end;C.phase='los';C.stage=frame
   elseif frame-C.stage>300 then return finish('INCONCLUSIVE all13_native_hits_or_articulation_timeout_phase'..C.pass)
   elseif frame%15==0 then local ok,n=aim();if not ok then return finish('INCONCLUSIVE native_target_refresh_'..n)end end
  end
 end
 function C.Query(id,n,piece)
  if human and C.phase=='human'and id==C.body and C.route.mounts[n]then
   local frame=S.GetGameFrame();local previous=humanRead.queryFrame[n]==frame and humanRead.query[n]or(tostring(frame)..':')
   humanRead.query[n]=previous..tostring(piece)..',';humanRead.queryFrame[n]=frame;humanRead.queryPiece[n]=piece;return
  end
  if C.result or C.phase~='combat'or id~=C.body then return end;local m=C.route.mounts[n];if not m then return fail('foreign_slot')end
  local matched=false;for _,p in ipairs(m.muzzles)do if p==piece then matched=true end end;if not matched then return fail('wrong_actual_query_piece_'..n)end
  local x,y,z=S.GetUnitPiecePosDir(id,piece);if not numbers(x,y,z)then return fail('query_position')end
  C.query[n]={frame=S.GetGameFrame(),piece=piece,x=x,y=y,z=z};log('QUERY','slot='..n,'phase='..C.pass,'frame='..S.GetGameFrame(),'piece='..piece,'x='..x,'y='..y,'z='..z)
 end
 function C.Shot(id,n,frame)
  if C.result or C.phase~='combat'or id~=C.body then return end;local m=C.route.mounts[n];if not m or frame~=S.GetGameFrame()or S.GetUnitWeaponState(id,n)~=true then return fail('native_shot_angle_not_ready')end
  local _,_,_,wx,wy,wz=S.GetUnitWeaponVectors(id,n);local _,_,_,dx,dy,dz=S.GetUnitPiecePosDir(id,m.muzzles[1])
  if not numbers(wx,wy,wz,dx,dy,dz)then return fail('physical_axis_readback')end
  local wl=math.sqrt(wx*wx+wy*wy+wz*wz);local dl=math.sqrt(dx*dx+dy*dy+dz*dz);if wl<.999 or wl>1.001 or dl<.999 or dl>1.001 then return fail('unit_axis_required')end
  local dot=(wx*dx+wy*dy+wz*dz)/(wl*dl);local yaw,pitch=localAxis(dx/dl,dy/dl,dz/dl);local g=m.group
  if not yaw or dot<math.cos(math.rad(3))or math.abs(wrap(yaw-g.yaw_center))>g.yaw_limit+.002 or pitch< -g.pitch_down_limit-.002 or pitch>g.pitch_up_limit+.002 then return fail('physical_shot_outside_measured_envelope_'..n)end
  C.shot[n]={frame=frame,phase=C.pass};C.poses[C.pass][n]=yaw
  local frames=C.pairShots[C.pass][n]or{};frames[#frames+1]=frame;C.pairShots[C.pass][n]=frames
  log('SHOT','slot='..n,'phase='..C.pass,'frame='..frame,'dot='..dot,'yaw='..yaw,'pitch='..pitch,'center='..g.yaw_center,'limit='..g.yaw_limit,'down='..g.pitch_down_limit,'up='..g.pitch_up_limit)
 end
 function C.Projectile(pid,owner,weapon)
  if human and C.phase=='human'and owner==C.body then
   local n=C.route.byWeapon[weapon];if not n then return end
   local frame=S.GetGameFrame();local v=humanRead.volley[n]or{total=0}
   v.recent=v.recent or{};local last=v.recent[#v.recent]
   if last and last.frame==frame then last.count=last.count+1 else
    v.recent[#v.recent+1]={frame=frame,count=1};if #v.recent>16 then table.remove(v.recent,1)end
   end
   local kind,user,target=S.GetUnitWeaponTarget(owner,n);local def=kind==1 and type(target)=='number'and S.GetUnitDefID(target)
   local domain=kind==2 and'ground_position'or def and D[def]and(D[def].canFly and'air_unit'or'ground_unit')or'unknown'
   v.targetOnProjectile='type:'..value(kind)..',user:'..value(user)..',id_or_pos:'..value(target)..',domain:'..domain
   if def then v.targetOnProjectile=v.targetOnProjectile..',native_aim:'..read('GetUnitPosition',target,false,true)..',def:'..value(def)end
   -- Birth observations only: one current native volley, at most four rows.
   -- No projectile tracker, correction, steering, hit or accuracy inference.
   if v.birthFrame~=frame then v.birthFrame=frame;v.birthVectors={}end
   if #v.birthVectors<4 then
    local muzzle=humanRead.queryFrame[n]==frame and read('GetUnitPiecePosDir',owner,humanRead.queryPiece[n])or'same_frame_query_not_observed'
    v.birthVectors[#v.birthVectors+1]='pid:'..value(pid)..',velocity:'..read('GetProjectileVelocity',pid)..',muzzle:'..muzzle..',native_wanted:'..read('GetUnitWeaponVectors',owner,n)..',owner_velocity:'..read('GetUnitVelocity',owner)..',target_velocity:'..(def and read('GetUnitVelocity',target)or'not_unit')
   end
   v.total=v.total+1;v.count=v.frame==frame and(v.count+1)or 1;v.frame=frame;humanRead.volley[n]=v;return
  end
  if C.result or C.phase~='combat'or owner~=C.body then return end;local n=C.route.byWeapon[weapon];if not n then return fail('unregistered_gunship_projectile')end
  local shot=C.shot[n];local frame=S.GetGameFrame();local x,y,z=S.GetProjectilePosition(pid);local mx,my,mz=S.GetUnitWeaponVectors(owner,n);local speed=S.GetUnitWeaponState(owner,n,'projectileSpeed')
  if C.projectiles[pid]or not shot or shot.frame~=frame or shot.phase~=C.pass or not numbers(x,y,z,mx,my,mz,speed)or speed<=0 then return fail('native_shot_projectile_chain')end
  local q=C.query[n];if not q or q.frame~=frame then return fail('same_frame_native_Query_required')end
  if(x-q.x)^2+(y-q.y)^2+(z-q.z)^2>math.max(16,speed+4)^2 or(mx-q.x)^2+(my-q.y)^2+(mz-q.z)^2>16 then return fail('native_projectile_muzzle_origin')end
  C.projectiles[pid]={slot=n,phase=C.pass,weapon=weapon,target=C.targets[C.route.mounts[n].group.name],hit=false};C.used[C.pass][n][q.piece]=true
  log('PROJECTILE','slot='..n,'phase='..C.pass,'frame='..frame,'pid='..pid,'weapon='..weapon,'owner='..owner,'piece='..q.piece,'x='..x,'y='..y,'z='..z,'mx='..mx,'my='..my,'mz='..mz,'speed='..speed)
 end
 function C.Damaged(id,damage,para,weapon,pid,attacker)
  if C.result or attacker~=C.body or para or not finite(damage)or damage<=0 then return end;local p=C.projectiles[pid];if not p or id~=p.target or weapon~=p.weapon or p.hit then return end
  local hp=S.GetUnitHealth(id);local before=C.targetHP[id];if not numbers(hp,before)or hp>=before then return fail('positive_native_HP_loss_required')end
  p.hit=true;C.targetHP[id]=hp;C.hits[p.phase][p.slot]=(C.hits[p.phase][p.slot]or 0)+1
  log('HIT','slot='..p.slot,'phase='..p.phase,'pid='..pid,'weapon='..weapon,'attacker='..attacker,'target='..id,'frame='..S.GetGameFrame(),'before='..before,'health='..hp,'damage='..damage)
 end
 function C.Created()end;function C.Finished()end;function C.Released()end
 function C.Explosion()return false end
 function C.Close()
  if C.closed then return end;C.closed=true;if G.Recoil40KStompaWeaponWitness==C then G.Recoil40KStompaWeaponWitness=nil end
  if C.watching then for _,m in ipairs(C.route.mounts)do Script.SetWatchProjectile(m.weapon,false)end end
  for id,row in pairs(C.owned)do if not C.initial[id]and live(id,row.def,row.team)then S.DestroyUnit(id,false,true)end end
 end
 return C
end
return M
