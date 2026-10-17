function gadget:GetInfo()
 return{name='40K paid gait movement diagnostic',desc='Default-off ordinary paid cohort movement/return witness',author='Local project',layer=152,enabled=true}
end
local options=Spring.GetModOptions()or{}
local enabled=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
if not enabled(options.prototype_gait_movement_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then return false end
local S=Spring;local state='waiting';local firstFrame,seed,leader,originals,members,target
local samples={};local movingFrames=0;local observerCalls=0;local finished=false
local limit=1800;local minimumSamples=20
local lastFrame
local observedAt={};local movingCountedFrame
local renderNotified=false
local function emit(event,...)
 local a={...};for i=1,#a do a[i]=tostring(a[i])end
 S.Echo('40K_GAIT_MOVEMENT '..event..' '..table.concat(a,' '))
end
-- Bounded read-only endpoint evidence. Capture BEFORE terminal STOP clears the
-- real queued commands; no movement/goals are adjusted to satisfy this probe.
local function stateWitness(event)
 if not members or not originals then return end
 local endpoint=originals[leader]
 emit('STATE_WINDOW',event,'frame='..tostring(lastFrame),'phase='..state,'leader='..leader,
  'return_goal=original_leader','return_position='..table.concat({tostring(endpoint and endpoint.x),tostring(endpoint and endpoint.y),tostring(endpoint and endpoint.z)},','),
  'outbound_goal='..table.concat({tostring(target and target[1]),tostring(target and target[2]),tostring(target and target[3])},','),'all_members_receive_same_move_params=true','original_radius=96','queue_sample_limit=3')
 for _,id in ipairs(members)do
  local p=originals[id];local alive=not S.GetUnitIsDead(id)
  local x,y,z,vx,vy,vz;local queue
  if alive then x,y,z=S.GetUnitPosition(id);vx,vy,vz=S.GetUnitVelocity(id);queue=S.GetCommandQueue(id,3)end
  local commands={}
  for j,c in ipairs(queue or{})do
   local params={};for k=1,math.min(6,#(c.params or{}))do params[k]=tostring(c.params[k])end
   commands[j]=tostring(c.id)..':'..table.concat(params,',')
  end
  local speed2=vx and vz and vx*vx+vz*vz
  local ownDistance=x and z and p and math.sqrt((x-p.x)^2+(z-p.z)^2)
  local leaderDistance=x and z and endpoint and math.sqrt((x-endpoint.x)^2+(z-endpoint.z)^2)
  emit('STATE',event,'id='..id,'is_leader='..tostring(id==leader),'alive='..tostring(alive),
   'original='..table.concat({tostring(p and p.x),tostring(p and p.y),tostring(p and p.z)},','),
   'position='..table.concat({tostring(x),tostring(y),tostring(z)},','),
   'velocity='..table.concat({tostring(vx),tostring(vy),tostring(vz)},','),
   'own_original_distance='..tostring(ownDistance),'common_leader_goal_distance='..tostring(leaderDistance),
   'queue_sample_n='..tostring(queue and #queue),'commands='..table.concat(commands,'|'),
   'gate_queue_empty='..tostring(queue and #queue==0),'gate_velocity='..tostring(speed2 and speed2<=1e-5),
   'gate_own_radius='..tostring(ownDistance and ownDistance<=96),'gate_commanded_goal_radius='..tostring(leaderDistance and leaderDistance<=96))
 end
end
local function order(command,params)
 return S.GiveOrderToUnit(leader,command,params,0)~=false
end
local function finish(reason)
 if finished then return false end
 stateWitness('FINAL')
 finished=true;state='done'
 if leader and not S.GetUnitIsDead(leader)then order(CMD.STOP,{})end
 emit('COMPLETE',reason,'moving_frames='..movingFrames,'phase_calls='..observerCalls,
  'ordinary_paid=true native_gait_acceptance=false render_smoothness_acceptance=false')
 return false
end
local function positionsValid()
 for _,id in ipairs(members)do
  if S.GetUnitIsDead(id)or S.GetUnitTeam(id)~=originals[id].team then return false end
 end
 return true
end
local function stoppedAtCommandedGoal()
 local p=originals[leader]
 for _,id in ipairs(members)do
  local x,_,z=S.GetUnitPosition(id)
  local vx,_,vz=S.GetUnitVelocity(id);local q=S.GetCommandQueue(id,1)
  if not x or not vx or not q or #q>0 or vx*vx+vz*vz>1e-5 or (x-p.x)^2+(z-p.z)^2>96^2 then return false end
 end
 return true
end
local function legalTarget()
 local p=originals[leader]
 for _,distance in ipairs({256,384})do for j=0,15 do
  local angle=j*math.pi/8;local x,z=p.x+distance*math.cos(angle),p.z+distance*math.sin(angle)
  local y=S.GetGroundHeight(x,z);local legal=y>=0 and x>64 and z>64 and x<Game.mapSizeX-64 and z<Game.mapSizeZ-64
  for _,id in ipairs(members)do
   local offset=originals[id];local px,pz=x+offset.x-p.x,z+offset.z-p.z
   if not S.TestMoveOrder(S.GetUnitDefID(id),px,S.GetGroundHeight(px,pz),pz,0,0,0,true,true,false)
    or not S.TestMoveOrder(S.GetUnitDefID(id),x,y,z,0,0,0,true,true,false)then legal=false end
  end
  if legal then return{x,y,z}end
 end end
end
local function observeUnit(id,frame)
  local vx,_,vz=S.GetUnitVelocity(id);local moving=vx and vx*vx+vz*vz>1e-5
  if moving and frame%3==0 and observedAt[id]~=frame and(samples[id]or 0)<48 then
   local getter=(GG.Recoil40KGaitPoseObservers or{})[id]
   local metadata=getter and getter(frame,{})
   if metadata and metadata.frame==frame and metadata.mode=='walk'and metadata.blendAge>=6 then
    local pose=getter(frame,{metadata.rootName});local pieceMap=S.GetUnitPieceMap(id)
    local handle=pieceMap and pieceMap[metadata.rootName]
    local matrix=handle and{S.GetUnitPieceMatrix(id,handle)}or{}
    if pose and #matrix==16 then
     observedAt[id]=frame
     samples[id]=(samples[id]or 0)+1;observerCalls=observerCalls+1
     local matrixText={};for k=1,16 do matrixText[k]=string.format('%.17g',matrix[k])end
     local rowText={};for k=1,6 do rowText[k]=string.format('%.17g',pose.rows[pose.rootName][k])end
     emit('PHASE',id,frame,pose.actor,pose.bankKey,pose.factor,pose.sampleSeconds,pose.fps,pose.count,
      pose.i,pose.j,pose.alpha,pose.mode,pose.blendAge,pose.blendAlpha,pose.rootName,
      table.concat(rowText,','),table.concat(matrixText,','),'same_frame=true composed_root_only=true')
     -- Once-only presentation notification; no orders/state/oracle changes.
     if not renderNotified and enabled(options.prototype_animation_interpolation)
      and enabled(options.prototype_fractional_walk_sampling)and pose.fractional and pose.smooth then
      renderNotified=true
      local x,y,z=S.GetUnitPosition(id)
      SendToUnsynced('fortyk_gait_render_begin',id,table.concat(members,','),pose.actor,pose.bankKey,pose.factor,frame,x,y,z)
     end
    end
   end
  end
end
local function observe(frame)
 local allMoving=true
 for _,id in ipairs(members)do
  local vx,_,vz=S.GetUnitVelocity(id)
  if not vx or not vz or vx*vx+vz*vz<=1e-5 then allMoving=false end
  observeUnit(id,frame)
 end
 if allMoving and movingCountedFrame~=frame then movingFrames=movingFrames+1;movingCountedFrame=frame end
end
local function hold(context,frame)
 lastFrame=frame
 if finished then return false end
 if not enabled(options.prototype_squad_paid_fixture)or not enabled(options.prototype_scale_native_probe)then
  return finish('INCONCLUSIVE required_paid_and_scale_options_missing')
 end
 if context.phase~='delivery_checkpoint'then return false end
 if state=='waiting'then
  local proof=context.proof or{}
  if not(proof.paid_factory and proof.paid_full_squad and proof.ordinary_start)then return finish('INCONCLUSIVE ordinary_paid_proof_missing')end
  local R=GG.Recoil40KSquads;local squad=R and R.squads[context.seed]
  if not squad or(squad.profile~='marine_tactical'and squad.profile~='guard_line')then return finish('INCONCLUSIVE unsupported_paid_family')end
  seed=context.seed;leader=squad.leader;members=R.Members(leader);originals={};firstFrame=frame
  local expected=squad.profile=='marine_tactical'and 4 or 8
  if #members~=expected then return finish('INCONCLUSIVE not_full_paid_capacity')end
  for _,id in ipairs(members)do
   local x,y,z=S.GetUnitPosition(id)
   if not x or S.GetUnitIsDead(id)or not(context.originalMembers or{})[id]then return finish('INCONCLUSIVE not_original_live_paid_body')end
   originals[id]={x=x,y=y,z=z,team=S.GetUnitTeam(id)}
  end
  target=legalTarget();if not target then return finish('INCONCLUSIVE no_all_body_legal_move_site')end
  stateWitness('BEGIN')
  if not order(CMD.STOP,{})or not order(CMD.MOVE,target)then return finish('INCONCLUSIVE native_move_refused')end
  state='outbound';emit('BEGIN','seed='..seed,'leader='..leader,'members='..#members,'timeout_frames='..limit)
  return true
 end
 if context.seed~=seed or not positionsValid()then return finish('INCONCLUSIVE cohort_changed')end
 if frame-firstFrame>limit then return finish('INCONCLUSIVE natural_movement_or_phase_timeout')end
 if state=='outbound'then
  observe(frame)
  local complete=movingFrames>=30
  for _,id in ipairs(members)do if(samples[id]or 0)<minimumSamples then complete=false end end
  local x,_,z=S.GetUnitPosition(leader);local q=S.GetCommandQueue(leader,1)
  if x and q and #q==0 and(x-target[1])^2+(z-target[3])^2<64^2 then
   if not complete then return finish('INCONCLUSIVE insufficient_same_frame_moving_phases')end
   local p=originals[leader]
   if not order(CMD.MOVE,{p.x,p.y,p.z})then return finish('INCONCLUSIVE native_return_move_refused')end
   state='returning';stateWitness('RETURN');emit('RETURN','phase_window_complete=true original_leader_endpoint=true')
  end
 elseif state=='returning'and stoppedAtCommandedGoal()then return finish('PASS paid_cohort_moved_phase_window_returned_and_stopped')end
 return true
end
local function observing(id,frame)
 if state~='outbound'or finished or frame~=lastFrame or not originals or not originals[id]
  or S.GetUnitIsDead(id)or S.GetUnitTeam(id)~=originals[id].team then return false end
 local vx,_,vz=S.GetUnitVelocity(id)
 return not not(vx and vz and vx*vx+vz*vz>1e-5)
end
local function observePublished(id,frame)
 if not observing(id,frame)then return false end
 observeUnit(id,frame)
 return observedAt[id]==frame
end
function gadget:Initialize()
 GG.Recoil40KGaitMovementFixture={HoldPaidCheckpoint=hold,IsObserving=observing,ObservePublished=observePublished}
end
function gadget:Shutdown()GG.Recoil40KGaitMovementFixture=nil end
