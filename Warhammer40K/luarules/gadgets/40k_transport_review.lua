function gadget:GetInfo() return {name='40K opt-in native transport proof',desc='Free function fixture; genuine native cargo commands and readbacks',author='Local project',layer=108,enabled=true} end
local opts=Spring.GetModOptions()
if not gadgetHandler:IsSyncedCode() or opts.prototype_diagnostic~='roster' or tostring(opts.prototype_transport_review)~='1' then return end
local P=VFS.Include('luarules/utilities/40k_transport_proof.lua')
local truck,ids,base,owned=nil,{},{},{}
local stage,start,done,expected,events='waiting',0,false,nil,{}
local lane,cycle,index,baselineMove=nil,1,1,nil
local orderList,goals
local spaced=tostring(opts.prototype_transport_postmove_spaced_review)=='1'
local goalPolicy=spaced and VFS.Include('luarules/utilities/40k_transport_postmove_policy.lua')
local witnessFrame=-1
local moveRetries={}
local function log(...) Spring.Echo('40K TRANSPORT REVIEW',...) end
local function rules(k,v) Spring.SetGameRulesParam('40k_transport_review_'..k,v,{public=true}) end
local function finish(ok,why)
 if done then return end
 done=true;rules('result',ok and 1 or -1);rules('complete_frame',Spring.GetGameFrame())
 log(ok and 'PASS' or 'FAIL',why,Spring.GetGameFrame(),'function_fixture_not_paid_acceptance')
end
local function phase(name)
 stage=name;start=Spring.GetGameFrame();rules('stage',name);rules('stage_start',start);log('STAGE',name,start,cycle)
end
local function give(id,cmd,args)
 if not P.command(cmd,args,CMD) then finish(false,'disallowed_command');return end
 Spring.GiveOrderToUnit(id,cmd,args,{})
 log('ORDER',id,cmd,unpack(args))
end
local function position(id)
 local x,y,z=Spring.GetUnitPosition(id);return x,y,z
end
local function readUnit(id)
 local hp,maxhp=Spring.GetUnitHealth(id)
 local x,y,z=position(id)
 return {id=id,hp=hp,maxhp=maxhp,def=Spring.GetUnitDefID(id),team=Spring.GetUnitTeam(id),owner=Spring.GetUnitTransporter(id),dead=not Spring.ValidUnitID(id) or Spring.GetUnitIsDead(id),x=x,y=y,z=z}
end
local function read()
 local out={members=Spring.GetUnitIsTransporting(truck),units={}}
 if type(out.members)~='table' then finish(false,'native_cargo_readback_missing');return end
 for _,id in ipairs(ids) do out.units[id]=readUnit(id) end
 for _,id in ipairs(ids) do local a=out.units[id];if not P.finite(a.x) or not P.finite(a.y) or not P.finite(a.z) then finish(false,'native_position_missing');return end end
 local ok,m=P.snapshot(ids,base,out,truck)
 if not ok then finish(false,m);return end
 local t=readUnit(truck);local b=base[truck]
 if not P.finite(t.hp) or not P.finite(t.maxhp) or t.dead or t.team~=b.team or t.def~=b.def or t.hp~=b.hp or t.maxhp~=b.maxhp then finish(false,'truck_identity_health_changed');return end
 return out,m
end
local function terrain(def,x,y,z) return Spring.TestMoveOrder(def,x,y,z,0,0,0,true,false,false) end
local function collision(a)
 local sx,sy,sz,ox,oy,oz,kind,testType,axis,disabled=Spring.GetUnitCollisionVolumeData(a.id)
 if not sx or not sy or not sz or not ox or not oy or not oz or not a.x then return end
 log('COLLISION_VOLUME',a.id,sx,sy,sz,ox,oy,oz,Spring.GetUnitHeading(a.id) or 0)
 log('NATIVE_PRIMITIVE',a.id,kind or -1,testType or -1,axis or -1,tostring(disabled),sx,sy,sz,ox,oy,oz)
 local _,_,_,mx,my,mz=Spring.GetUnitPosition(a.id,true)
 local front,up,right=Spring.GetUnitVectors(a.id)
 if not mx or not front or not up or not right then return end
 -- Pinned CSolidObject::ComposeMatrix uses -rightdir/updir/frontdir. Collision
 -- handler translates relMidPos and offsets before testing the actual volume.
 local center,half={},{ }
 for axis=1,3 do
  center[axis]=({mx,my,mz})[axis]-right[axis]*ox+up[axis]*oy+front[axis]*oz
  half[axis]=(math.abs(right[axis])*sx+math.abs(up[axis])*sy+math.abs(front[axis])*sz)*.5
 end
 a.box={x=center[1],y=center[2],z=center[3],hx=half[1],hy=half[2],hz=half[3]}
 log('PRIMITIVE_AXES',a.id,-right[1],-right[2],-right[3],up[1],up[2],up[3],front[1],front[2],front[3])
 a.primitive={kind=kind,testType=testType,axis=axis,disabled=disabled,center=center,half={sx*.5,sy*.5,sz*.5},axes={{-right[1],-right[2],-right[3]},up,front}}
 log('WORLD_COLLISION_BOUND',a.id,a.box.x,a.box.y,a.box.z,a.box.hx,a.box.hy,a.box.hz)

end
local function record(label)
 local map=Spring.GetUnitPieceMap(truck) or {}
 local candidate=map.marker_compartment and 'marker_compartment' or map.tank_master and 'tank_master'
 log('ATTACHMENT_CANDIDATE',label,candidate or 'UNKNOWN',candidate and map[candidate] or -1,'inferred_runtime_fallback_not_native_attachment_handle')
 if candidate and Spring.GetUnitPiecePosDir then log('PIECE_POSITION',label,candidate,Spring.GetUnitPiecePosDir(truck,map[candidate])) end
 for _,id in ipairs(ids) do log('CARGO_POSITION',label,id,Spring.GetUnitTransporter(id) or -1,position(id)) end
end
local function beginLoad(list)
 orderList=list;index=1;events={};for _,id in ipairs(list) do give(id,CMD.STOP,{}) end;expected={kind='loaded',id=list[1]};phase('loading');give(truck,CMD.LOAD_UNITS,{list[1]})
end
local function callback(kind,id,def,team,transport,transportTeam)
 if not truck or done or not base[id] then return end
 if transport~=truck then finish(false,'wrong_transporter_callback');return end
 local want=expected
 if kind=='unloaded' and stage=='unloading' then want={kind='unloaded',id=id} end
 if not want then finish(false,'unrequested_native_callback');return end
 local ok,why=P.callback(kind,id,def,team,transport,transportTeam,want,base,truck,base[truck].team)
 if not ok then finish(false,why);return end
 if events[id] then finish(false,'duplicate_native_callback');return end
 events[id]=kind;log('NATIVE_CALLBACK',kind,id,def,team,transport,transportTeam,Spring.GetGameFrame())
end
function gadget:UnitLoaded(...) callback('loaded',...) end
function gadget:UnitUnloaded(...) callback('unloaded',...) end
local function spawn(name,x,z)
 local id=Spring.CreateUnit(name,x,Spring.GetGroundHeight(x,z),z,0,0)
 if not id then finish(false,'fixture_create_failed');return end
 owned[#owned+1]=id;give(id,CMD.FIRE_STATE,{0});give(id,CMD.MOVE_STATE,{0});return id
end
local function setup()
 if tonumber(opts.prototype_test_speed or 1)~=1 then finish(false,'requires_1x_option');return end
 local td,sd=UnitDefNames.ork_trukk,UnitDefNames.ork_slugga
 if not td or not sd then finish(false,'genuine_source_definitions_missing');return end
 local ork=false
 for _,id in ipairs(Spring.GetTeamUnits(0)) do local u=UnitDefs[Spring.GetUnitDefID(id)];if u and (u.name=='ork_big_mek_commander' or (u.customParams or {}).faction=='Orks') then ork=true end end
 if not ork then finish(false,'requires_ork_team_zero');return end
 local tu,su=UnitDefs[td.id],UnitDefs[sd.id]
 local footprint=(su.xsize or (su.footprintX and su.footprintX*2) or 0)/2
 local cargoPolicy=VFS.Include('40k_configs/ork_trukk_actor_capacity.lua')
 if not cargoPolicy.Preflight(tu,su) or (cargoPolicy.IsOwned(tu) and not GG.Recoil40KTrukkActorCapacity) then finish(false,'native_capacity_size_mass_preflight_unknown');return end
 log('ACTOR_CAPACITY',cargoPolicy.ActorCapacity(tu,6),'NATIVE_FOOTPRINT_CAPACITY',tu.transportCapacity)
 log('PREFLIGHT',tu.name,su.name,tu.transportCapacity,footprint,su.mass,tu.transportMass,tu.transportSize)
 for z=700,Game.mapSizeZ-700,128 do for x=700,Game.mapSizeX-(spaced and 1100 or 950),128 do
  local clear=Spring.GetGroundHeight(x,z)>0
  if #Spring.GetUnitsInRectangle(x-150,z-(spaced and 220 or 180),x+(spaced and 940 or 760),z+220)>0 or #Spring.GetFeaturesInRectangle(x-150,z-(spaced and 220 or 180),x+(spaced and 940 or 760),z+220)>0 then clear=false end
  for dx=0,(spaced and 900 or 700),40 do for dz=(spaced and -200 or -120),(spaced and 200 or 160),40 do local h=Spring.GetGroundHeight(x+dx,z+dz)
   if h<0 or not Spring.TestMoveOrder(td.id,x+dx,h,z+dz) or not Spring.TestMoveOrder(sd.id,x+dx,h,z+dz) then clear=false end
  end end
  if clear then lane={x=x,z=z};break end
 end if lane then break end end
 if not lane then finish(false,'no_native_clear_passable_lane');return end
 truck=spawn('ork_trukk',lane.x,lane.z);if done then return end
 for i=1,7 do ids[i]=spawn('ork_slugga',lane.x+(i-4)*24,lane.z+70);if done then return end;rules('cargo_'..i,ids[i]) end
 base[truck]=readUnit(truck);for _,id in ipairs(ids) do base[id]=readUnit(id) end
 rules('truck',truck);log('FIXTURE','free_created_function_only',truck,unpack(ids))
 for _,cmd in ipairs({CMD.LOAD_UNITS,CMD.UNLOAD_UNITS,CMD.MOVE}) do if not Spring.FindUnitCmdDesc(truck,cmd) then finish(false,'native_transport_command_missing');return end end
 phase('settling')
end
local function padCheck(out)
 local us={};for _,id in ipairs(orderList) do local a=out.units[id];collision(a);us[#us+1]=a end
 local t=readUnit(truck);collision(t)
 local pad={x=lane.x+340,z=lane.z,radius=96}
 for _,a in ipairs(us) do log('UNLOAD_READBACK',cycle,a.id,a.x,a.y,a.z,Spring.GetGroundHeight(a.x,a.z),terrain(a.def,a.x,Spring.GetGroundHeight(a.x,a.z),a.z)) end
 return P.pad(us,t,pad,Spring.GetGroundHeight,terrain,function(a,b,overlap,kind,metric,limit) log('PRIMITIVE_PAIR',a,b,tostring(overlap),kind,metric or -1,limit or -1) end)
end
local goalScene=VFS.Include('luarules/utilities/40k_transport_goal_scene_witness.lua').New(Spring,UnitDefs,FeatureDefs,log)
local function postWitness(label)
 if stage~='post_move'or not goals then return end
 if label=='terminal'then goalScene.Terminal(cycle,orderList,goals)end
 local f=Spring.GetGameFrame();if label~='terminal'and witnessFrame>=0 and f-witnessFrame<150 then return end;witnessFrame=f
 for _,id in ipairs(orderList)do
  local a=readUnit(id);local b=baselineMove[id];local g=goals[id];local vx,vy,vz=Spring.GetUnitVelocity(id)
  local q=Spring.GetUnitCommands(id,1);local c=type(q)=='table'and q[1];local params=c and c.params or{}
  local mt=Spring.GetUnitMoveTypeData(id)or{}
  log('POST_MOVE_STATE',label,cycle,f,id,a.x or'UNKNOWN',a.y or'UNKNOWN',a.z or'UNKNOWN',g.x,g.z,
   a.x and math.sqrt((a.x-g.x)^2+(a.z-g.z)^2)or'UNKNOWN',a.x and math.sqrt((a.x-b[1])^2+(a.z-b[3])^2)or'UNKNOWN',
   vx or'UNKNOWN',vy or'UNKNOWN',vz or'UNKNOWN',c and c.id or'EMPTY',c and c.tag or'NONE',params[1]or'NONE',params[2]or'NONE',params[3]or'NONE',
   mt.progressState or'UNKNOWN',mt.goalRadius or'UNKNOWN',mt.goalx or'UNKNOWN',mt.goaly or'UNKNOWN',mt.goalz or'UNKNOWN',
   Spring.GetUnitCommandCount and Spring.GetUnitCommandCount(id)or'UNKNOWN',a.owner or-1)
 end
end
local function advance(f)
 if done then return end
 if stage=='waiting' then if f>=90 then setup() end;return end
 if f>18000 or f-start>1500 then postWitness('terminal');finish(false,'native_stage_timeout_'..stage);return end
 local out,m=read();if not out or done then return end
 local count=#out.members
 if stage=='settling' and f-start>=60 then beginLoad({ids[1],ids[2],ids[3],ids[4],ids[5],ids[6]})
 elseif stage=='loading' then
  local id=orderList[index]
  if m[id] then
   if events[id]~='loaded' then finish(false,'membership_without_native_load_callback');return end
   if count~=index then finish(false,'unexpected_load_count');return end
   if index==6 then expected=nil;phase('loaded_hold');record(stage)
   else index=index+1;expected={kind='loaded',id=orderList[index]};start=f;give(truck,CMD.LOAD_UNITS,{orderList[index]}) end
  end
 elseif stage=='loaded_hold' and f-start>=60 then
  if cycle==1 then expected={kind='loaded',id=ids[7]};phase('capacity_reject');give(truck,CMD.LOAD_UNITS,{ids[7]})
  else expected=nil;phase('unloading');events={};give(truck,CMD.UNLOAD_UNITS,{lane.x+340,Spring.GetGroundHeight(lane.x+340,lane.z),lane.z,96}) end
 elseif stage=='capacity_reject' then
  if count~=6 or m[ids[7]] or events[ids[7]] then finish(false,'seventh_not_rejected');return end
  if f-start>=90 then log('CAPACITY_REJECTION',ids[7],'actual_order_no_owner_no_membership_no_callback',f);expected=nil;baselineMove={position(truck)};phase('moving_loaded');give(truck,CMD.MOVE,{lane.x+240,Spring.GetGroundHeight(lane.x+240,lane.z),lane.z}) end
 elseif stage=='moving_loaded' then
  if count~=6 then finish(false,'cargo_lost_during_native_move');return end
  local x,y,z=position(truck)
  if (x-baselineMove[1])^2+(z-baselineMove[3])^2>=160^2 and (x-lane.x-240)^2+(z-lane.z)^2<55^2 then record(stage);phase('unloading');events={};give(truck,CMD.UNLOAD_UNITS,{lane.x+340,Spring.GetGroundHeight(lane.x+340,lane.z),lane.z,96}) end
 elseif stage=='unloading' then
  if count==0 then for _,id in ipairs(orderList) do if events[id]~='unloaded' then finish(false,'empty_without_native_unload_callback');return end end;phase('unloaded_settle');record(stage) end
 elseif stage=='unloaded_settle' and f-start>=60 then
  local ok,why=padCheck(out);if not ok then finish(false,why);return end
  log('UNLOAD_LEGAL',cycle,f);baselineMove={};goals={};phase('post_move')
  if spaced then local why;goals,why=goalPolicy.Plan(Spring,UnitDefs,lane,orderList,base,Game.mapSizeX,Game.mapSizeZ);if not goals then finish(false,why);return end end
  log('POST_MOVE_POLICY',spaced and goalPolicy.Name or'legacy_collinear_24',cycle,80,32,1500,'new_policy_not_comparable_to_legacy_timeout')
  witnessFrame=-1;moveRetries={}
  for _,id in ipairs(orderList)do moveRetries[id]={started=f,count=0}end
  for i,id in ipairs(orderList)do baselineMove[id]={position(id)};if not spaced then goals[id]={x=lane.x+600,z=lane.z+(i-3.5)*24}end;local g=goals[id];give(id,CMD.MOVE,{g.x,Spring.GetGroundHeight(g.x,g.z),g.z})end
  postWitness('sample')
 elseif stage=='post_move' then
  postWitness('sample')
  -- Snapshot aggregate idleness before any existing bounded retry is consumed.
  if spaced and goalPolicy.AllIdle(Spring,orderList,base) then for _,id in ipairs(orderList)do
   local g,r=goals[id],moveRetries[id]
   if goalPolicy.Retry(Spring,id,g,f,r)then
    postWitness('terminal');r.count=r.count+1;r.last=f
    log('POST_MOVE_REISSUE',cycle,id,f,r.count,'aggregate_six_done_empty_owned_outside32_same_goal_no_deadline_reset')
    give(id,CMD.MOVE,{g.x,Spring.GetGroundHeight(g.x,g.z),g.z})
   end
  end end
  local arrived=true
  for _,id in ipairs(orderList) do local a=out.units[id];local b=baselineMove[id];local g=goals[id];if (a.x-b[1])^2+(a.z-b[3])^2<80^2 or (a.x-g.x)^2+(a.z-g.z)^2>32^2 then arrived=false end end
  if arrived then
   record(stage);log('POST_MOVE',cycle,'six_genuine_units_moved',f)
   if cycle==2 then finish(true,'six_load_seventh_reject_move_unload_legal_postmove_six_slot_reuse')
   else cycle=2;give(truck,CMD.MOVE,{lane.x+580,Spring.GetGroundHeight(lane.x+580,lane.z),lane.z});phase('reuse_approach') end
  end
 elseif stage=='reuse_approach' then
  local x,y,z=position(truck)
  if (x-lane.x-580)^2+(z-lane.z)^2<40^2 then
   -- Seventh remains at the start; move it genuinely to the second pickup pad.
   give(ids[7],CMD.MOVE,{lane.x+590,Spring.GetGroundHeight(lane.x+590,lane.z+100),lane.z+100});phase('reuse_seventh_approach')
  end
 elseif stage=='reuse_seventh_approach' then
  local a=out.units[ids[7]]
  if (a.x-lane.x-590)^2+(a.z-lane.z-100)^2<35^2 then beginLoad({ids[7],ids[1],ids[2],ids[3],ids[4],ids[5]}) end
 end
end
function gadget:GameFrame(f)
 local ok,err=pcall(advance,f)
 if not ok then log('NATIVE_API_ERROR',tostring(err));finish(false,'native_api_or_readback_error') end
end
function gadget:Shutdown()
 for _,id in ipairs(owned) do if Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then Spring.DestroyUnit(id,false,true) end end
end
