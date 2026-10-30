-- One native mover/target. Member facing, gait phase and recoil are presentation.
local cp = UnitDefs[unitDefID].customParams
local data = include('bar40k/animation_data.lua')(cp.squad_bank)
local prefix = cp.squad_prefix or (cp.tenguard_squad and 'tenguard' or 'tenboy')
local capacity = tonumber(cp.squad_capacity) or #data.members
assert(capacity==#data.members and capacity>=1, 'Squad capacity/bank mismatch')
local members, alive, dead = {}, capacity, false
-- Each full squad is centred on its native mover. A prefix of the ten-member
-- scatter is not a balanced formation for a three- or five-member squad.
local capacityLayouts={
  [3]={{-10,-4},{9,-6},{1,10}},
  [5]={{-12,7},{1,11},{13,3},{-8,-10},{6,-11}},
}
local layout = data.layout or capacityLayouts[capacity] or include('bar40k/squad_scatter.lua')
assert(#layout>=capacity, 'Missing squad formation slots')
local spread = tonumber(cp.squad_spread) or data.spread or (cp.tenguard_squad and 1.14 or .965)
local formationScale = math.max(.01,tonumber(cp.squad_formation_scale) or 1)
local spacing = tonumber(cp.squad_spacing) or 8.3
local mirror = unitID%2==0 and 1 or -1
local activeMuzzle, nextMuzzle, shots = 1, 1, 0
local nextAllowed, cadenceFraction = 0, 0
local salvoPeriod=tonumber(cp.squad_salvo_period)
local salvoSpacing=tonumber(cp.squad_salvo_spacing) or .18
local salvoStart,salvoSpent=-10000,{}
local lastSound=-1000
local memberCooldown=tonumber(cp.squad_member_cooldown) or (cp.tenboy_squad and 27 or 14)
local aimCenter = piece('squad_aim')
local tau, fps = 2 * math.pi, Game.gameSpeed
local aimUntil, targetYaw, formationYaw, heading = 0, 0, 0, 0
local targetX,targetZ
local combat = include('bar40k/animation_data.lua')(cp.squad_combat_profile or 'bar40k/squad_combat_pose.lua')
if type(combat)=='function' then combat=combat(cp.squad_bank) end
local contactSlots=data.contactSlots or {{-9,1},{1,-.5},{22,-2},{-19,-1},{-12,-9.5},{12,2},{-22,-11},{-2,-11},{19,-12},{8,-8}}
local meleeTarget
local function airborne() return cp.squad_jetpack and Spring.GetUnitRulesParam(unitID,'squad_jetpack_airborne')==1 end
local function engaged() return not airborne() and GG.SquadMelee and GG.SquadMelee[unitID] end
local travel, speed, oldX, oldZ = 0, 0
local definition = UnitDefs[unitDefID]
local baseReload = tonumber(cp.squad_shot_interval) or 0.1
local rules = {inlos=true}
local function publish(k,v) Spring.SetUnitRulesParam(unitID,prefix..'_'..k,v,rules) end
local function angle(v) return (v+math.pi)%tau-math.pi end
local function rangedTarget()
  local kind,_,target=Spring.GetUnitWeaponTarget(unitID,1)
  if kind==1 then targetX,_,targetZ=Spring.GetUnitPosition(target)
  elseif kind==2 and target then targetX,targetZ=target[1],target[3]
  else targetX,targetZ=nil,nil end
  return targetX~=nil
end
local function readyToFire(m,f)
  if not targetX or m.state~='alive' or f-(m.transitionFrame or f)<12 then return false end
  local x,_,z=Spring.GetUnitPiecePosDir(unitID,m.root)
  local wanted=math.atan2(targetX-x,targetZ-z)
  if speed>0.5 then
    if combat.wholePaletteSource then return m.mode=='runfire' and math.abs(angle(wanted-m.yaw))<.10 end
    return m.mode=='runfire' and math.abs(angle(wanted-m.yaw))<1.15
      and math.abs(angle(wanted-m.yaw-(m.upperYaw or 0)))<.10
  end
  return m.mode=='ready' and math.abs(angle(wanted-m.yaw))<.10
end
local function apply(m,row,seconds,instant)
  if not instant and m.appliedRow==row then return end
  m.appliedRow=row
  for b,pose in ipairs(row) do
    local previous=m.previous[b];local handle=m.bones[b]
    for axis=1,3 do
      local delta=previous and math.abs(pose[axis]-previous[axis]) or 1
      if instant or delta>0.0001 then
        if instant or m.connectedPose or m.instantWalk then Move(handle,axis,pose[axis]) else Move(handle,axis,pose[axis],delta/seconds) end
      end
      delta=previous and math.abs(angle(pose[axis+3]-previous[axis+3])) or 1
      if instant or delta>0.0001 then
        if instant or m.connectedPose or m.instantWalk then Turn(handle,axis,pose[axis+3]) else Turn(handle,axis,pose[axis+3],delta/seconds) end
      end
    end
    m.previous[b]=pose
  end
end
-- Immutable walk interpolation shared across squads. 512 phase samples keep
-- maximum phase error below 1/1024 stride; combat/aim/recoil remain continuous.
GG.SquadWalkPoseCache=GG.SquadWalkPoseCache or {}
GG.SquadWalkPoseCache[cp.squad_bank]=GG.SquadWalkPoseCache[cp.squad_bank] or {}
local walkCache=GG.SquadWalkPoseCache[cp.squad_bank]
-- Exact-time shared flight samples: at most 512 immutable rows per looping
-- clip. Unlike a quantized phase cache this never approximates source motion.
local flightCache
if data.clips.fly_idle or data.clips.fly_climb or data.clips.fly_descend then
  GG.SquadFlightPoseCache=GG.SquadFlightPoseCache or {}
  GG.SquadFlightPoseCache[cp.squad_bank]=GG.SquadFlightPoseCache[cp.squad_bank] or {}
  flightCache=GG.SquadFlightPoseCache[cp.squad_bank]
end
local function sample(clip,t,loop)
  if loop then t=t%clip.duration else t=math.min(t,clip.duration) end
  local key
  local sampleCache=walkCache
  if loop and clip==data.clips.walk then
    key=math.floor(t/clip.duration*512+.5)%512
    if walkCache[key] then return walkCache[key] end
    t=key/512*clip.duration
  elseif loop and flightCache and (clip==data.clips.fly_idle or clip==data.clips.fly_climb or clip==data.clips.fly_descend) then
    local cache=flightCache[clip]
    if not cache then cache={rows={},order={},next=1};flightCache[clip]=cache end
    key=t;sampleCache=cache.rows
    if sampleCache[key] then return sampleCache[key] end
    local evicted=cache.order[cache.next]
    if evicted~=nil then sampleCache[evicted]=nil end
    cache.order[cache.next]=key;cache.next=cache.next%512+1
  end
  local pos=t*clip.fps;local index=math.min(#clip.frames,1+math.floor(pos))
  local following=index<#clip.frames and index+1 or (loop and 1 or index);local mix=pos-math.floor(pos)
  if following==index or mix<.0001 then if key then sampleCache[key]=clip.frames[index] end;return clip.frames[index] end
  local out={}
  for b,a in ipairs(clip.frames[index]) do
    local z=clip.frames[following][b];local row={}
    for c=1,6 do row[c]=a[c]+(c>3 and angle(z[c]-a[c]) or z[c]-a[c])*mix end
    out[b]=row
  end
  if key then sampleCache[key]=out end
  return out
end
local function blend(a,b,t)
  if t>=1 or not a then return b end
  t=t*t*(3-2*t);local out={}
  for j,row in ipairs(b) do local old=a[j];local r={}
    for c=1,6 do r[c]=old[c]+(c>3 and angle(row[c]-old[c]) or row[c]-old[c])*t end
    out[j]=r
  end
  return out
end
-- BEGIN PHYSICAL ARM BLEND
-- Corrected immutable source rows are shared; weak keys discard transient
-- recoil/transition rows while the bounded walk cache keeps common phases.
GG.SquadConnectedPoseCache=GG.SquadConnectedPoseCache or {}
GG.SquadConnectedPoseCache[cp.squad_bank]=GG.SquadConnectedPoseCache[cp.squad_bank] or setmetatable({},{__mode='k'})
local connectedCache=GG.SquadConnectedPoseCache[cp.squad_bank]
local function posedPoint(row,p)
  local cx,sx=math.cos(row[4]),math.sin(row[4])
  local cy,sy=math.cos(row[5]),math.sin(row[5])
  local cz,sz=math.cos(row[6]),math.sin(row[6])
  local x,y=cz*p[1]-sz*p[2],sz*p[1]+cz*p[2]
  local z=sx*y+cx*p[3];y=cx*y-sx*p[3]
  return {row[1]+cy*x+sy*z,row[2]+y,row[3]-sy*x+cy*z}
end
local function keepArmsConnected(source)
  if combat.preserveSourceMuzzle and not combat.hierarchy then return source end
  if combat.hierarchy and connectedCache[source] then return connectedCache[source] end
  local row={}
  for i,v in ipairs(source) do row[i]={v[1],v[2],v[3],v[4],v[5],v[6]} end
  local function attach(index,pivot,parent,anchor)
    local target=posedPoint(row[parent],anchor);local current=posedPoint(row[index],pivot)
    local d={target[1]-current[1],target[2]-current[2],target[3]-current[3]}
    for k=1,3 do row[index][k]=row[index][k]+d[k] end
    return d
  end
  if combat.hierarchy then
    for _,c in ipairs(combat.hierarchy) do attach(c.index,c.pivot,c.parent,c.parentAnchor) end
    local muzzle=combat.muzzleAttachment
    if muzzle then
      local p=posedPoint(row[muzzle.parent],muzzle.indexPivot)
      for k=1,3 do row[#row][k]=p[k] end
    end
    connectedCache[source]=row
    return row
  end
  for _,c in ipairs(combat.armChains) do
    attach(c.shoulder,c.shoulderPivot,c.torso,c.shoulderInTorso)
    attach(c.elbow,c.elbowPivot,c.shoulder,c.elbowInUpper)
    local d=attach(c.hand,c.handPivot,c.elbow,c.handInLower)
    for _,j in ipairs(c.followers) do for k=1,3 do row[j][k]=row[j][k]+d[k] end end
  end
  local p=posedPoint(row[combat.muzzleHand],combat.muzzleInHand)
  for k=1,3 do row[#row][k]=p[k] end
  return row
end
-- END PHYSICAL ARM BLEND
local function strength(count)
  alive=count;publish('alive',count)
  -- Each projectile is one soldier's attack. Fewer survivors fire less often;
  -- one target search and weapon controller are retained for the whole squad.
  -- BAR's reload gadgets may replace reloadTime. BlockShot also enforces this
  -- member cadence, so native experience/reload updates cannot restore ten shots.
  if definition.weapons[2] then
    local wd=WeaponDefs[definition.weapons[2].weaponDef];local damages={}
    for key,value in pairs(wd.damages) do if type(key)=='number' then damages[key]=value*count/capacity end end
    Spring.SetUnitWeaponDamages(unitID,2,damages)
  end
end
local function remains(m)
  if m.corpse then return end
  local x,_,z=Spring.GetUnitPiecePosDir(unitID,m.root)
  if GG.SquadRemains then m.corpse=GG.SquadRemains(unitID,m.index,x,z,m.yaw) end
end
local function updateMembers(frame)
  local hp,maxhp,_,_,build=Spring.GetUnitHealth(unitID);if not hp then return end
  local count=build and build<1 and capacity or math.max(1,math.min(capacity,math.ceil(hp/maxhp*capacity-0.000001)))
  if count~=alive then strength(count) end
  for i,m in ipairs(members) do
    if i<=count and m.state~='alive' then
      if m.corpse and GG.SquadRemoveRemains then GG.SquadRemoveRemains(m.corpse) end
      m.corpse=nil;m.state='alive';m.previous={};m.basePrevious=nil;m.shotFrame=-1000
      Move(m.root,y_axis,0);apply(m,data.ready,0.1,true)
      publish('member_'..i,1);publish('hidden_'..i,0)
    elseif i>count and m.state=='alive' then
      m.state='dying';m.instantWalk=false;m.deathFrame=frame;publish('member_'..i,0)
    end
  end
end
local lastFrame=-1
local function facing()
  if GG.SquadPerfFreeze then return end
  if not dead then
    local f=Spring.GetGameFrame();local x,_,z=Spring.GetUnitPosition(unitID)
    local dt=math.max(1,f-lastFrame)/fps;lastFrame=f
    heading=Spring.GetUnitHeading(unitID)*tau/65536
    local dx,dz=x-(oldX or x),z-(oldZ or z);oldX,oldZ=x,z
    local distance=math.sqrt(dx*dx+dz*dz);speed=distance/dt
    if distance<8 then travel=travel+distance end -- don't run through teleports
    meleeTarget=engaged()
    if not meleeTarget and rangedTarget() then aimUntil=f+fps end
    if meleeTarget then targetX,_,targetZ=Spring.GetUnitPosition(meleeTarget);aimUntil=f+fps end
    -- The squad now turns as one formation. Every member shares this heading;
    -- slots and roots rotate together about the unchanged native unit centre.
    local wanted=heading
    if not airborne() and speed<=.5 and f<aimUntil and targetX then wanted=math.atan2(targetX-x,targetZ-z) end
    local turn=angle(wanted-formationYaw);local limit=dt*8.5
    formationYaw=formationYaw+math.max(-limit,math.min(limit,turn))
    local c,s=math.cos(formationYaw-heading),math.sin(formationYaw-heading)
    for _,m in ipairs(members) do
      -- Counter-rotate the slot around the mover, preserving its world offset.
      local hx,hz=m.homeSlot[1],m.homeSlot[2]
      if meleeTarget and targetX then
        local vx,vz=targetX-x,targetZ-z;local distance=math.sqrt(vx*vx+vz*vz)
        if distance>.1 then
          vx,vz=vx/distance,vz/distance
          local lateral=contactSlots[m.index][1]
          local front=math.min(25,distance*.5-9)+contactSlots[m.index][2]
          local wx,wz=vx*front+vz*lateral,vz*front-vx*lateral
          local fc,fs=math.cos(formationYaw),math.sin(formationYaw)
          hx,hz=fc*wx-fs*wz,fs*wx+fc*wz
          m.faceX=x+vx*(distance*.5+9)+vz*lateral;m.faceZ=z+vz*(distance*.5+9)-vx*lateral
        end
      else m.faceX=nil end
      local sx,sz=hx-m.slot[1],hz-m.slot[2];local remaining=math.sqrt(sx*sx+sz*sz)
      local step=math.min(remaining,dt*(26+(m.index*7+unitID)%13))
      if remaining>.001 then
        local nx,nz=m.slot[1]+sx/remaining*step,m.slot[2]+sz/remaining*step
        -- Slide around living squadmates; do not pass through their body discs.
        -- This is presentation spacing, not ten extra pathfinders.
        for _,other in ipairs(members)do
          if other~=m and other.state=='alive' then
            local dx,dz=nx-other.slot[1],nz-other.slot[2];local d=math.sqrt(dx*dx+dz*dz)
            if d<spacing and d>.001 then nx=other.slot[1]+dx/d*spacing;nz=other.slot[2]+dz/d*spacing end
          end
        end
        local dx,dz=nx-m.slot[1],nz-m.slot[2];local length=math.sqrt(dx*dx+dz*dz)
        if length>step then nx=m.slot[1]+dx/length*step;nz=m.slot[2]+dz/length*step end
        local after=math.sqrt((nx-hx)^2+(nz-hz)^2)
        if after>=remaining-.01 then nx,nz=m.slot[1],m.slot[2]end
        step=math.sqrt((nx-m.slot[1])^2+(nz-m.slot[2])^2);m.slot={nx,nz}
      end
      m.slotSpeed=step/dt;m.localTravel=(m.localTravel or 0)+step
      local ox,oz=m.slot[1],m.slot[2]
      local rx,rz=c*ox+s*oz-m.offset[1],-s*ox+c*oz-m.offset[3]
      if not m.rx or math.abs(rx-m.rx)>.0001 then Move(m.root,x_axis,rx);m.rx=rx end
      if not m.rz or math.abs(rz-m.rz)>.0001 then Move(m.root,z_axis,rz);m.rz=rz end
      m.targetYaw=formationYaw;m.yaw=formationYaw
      if not m.publishedYaw or math.abs(angle(m.yaw-m.publishedYaw))>.005 then publish('lod_yaw_'..m.index,m.yaw);m.publishedYaw=m.yaw end
      local ry=angle(m.yaw-heading)
      if not m.ry or math.abs(angle(ry-m.ry))>.0001 then Turn(m.root,y_axis,ry);m.ry=ry end
    end
  end
end
local function upperAim(m,row,turn,shift)
  local out={};for j,r in ipairs(row) do out[j]=r end
  local pivot=data.ready[combat.chest];local c,s=math.cos(turn),math.sin(turn)
  for _,j in ipairs(combat.upper) do
    local a=row[j];local x,z=a[1]-pivot[1],a[3]-pivot[3]
    out[j]={pivot[1]+c*x+s*z+shift[1],a[2]+shift[2],pivot[3]-s*x+c*z+shift[3],a[4],a[5]+turn,a[6]}
  end
  return out
end
local function animate()
  Sleep((unitID%2)*1000/fps)
  while not dead do
    if GG.SquadPerfFreeze then Sleep(100) else
    local f=Spring.GetGameFrame();updateMembers(f)
    local interval=(speed>0.5 or f<aimUntil) and 2 or 3
    for _,m in ipairs(members) do if m.state=='dying' then interval=2;break end end
    if engaged() then interval=1 else
      for _,m in ipairs(members) do if f<(m.armTransitionUntil or -1) then interval=1;break end end
    end
    if speed>.5 and f>=aimUntil and not meleeTarget then interval=1 end
    local seconds=interval/fps
    for _,m in ipairs(members) do
      if m.state=='alive' then
        local row,mode
        local movingFire=speed>0.5 and f<aimUntil and not meleeTarget
        -- Immediate melee presentation, with running legs while closing contact.
        if airborne() then
          mode='flight'
          local phase=Spring.GetUnitRulesParam(unitID,'squad_jetpack_phase') or 1
          local start=Spring.GetUnitRulesParam(unitID,'squad_jetpack_frame') or f
          local vertical=Spring.GetUnitRulesParam(unitID,'squad_jetpack_vertical') or 0
          local key=phase==0 and 'fly_launch' or phase==2 and 'fly_land' or vertical>0 and 'fly_climb' or vertical<0 and 'fly_descend' or 'fly_idle'
          local clip=data.clips[key] or data.clips.fly_idle
          row=clip and sample(clip,(f-start)/fps+(phase==1 and m.phase*clip.duration or 0),phase~=0 and phase~=2) or data.clips.idle.frames[1]
        elseif meleeTarget then
          mode='melee'
          local clip=(m.index%2==0 and combat.melee_alt) or combat.melee
          local cycle=clip.duration*(.63+(m.index%5)*.045)
          row=sample(clip,((f/fps+m.phase*2+(unitID%97)*.017)%cycle)/cycle*clip.duration,true)
          if speed>.5 or (m.slotSpeed or 0)>.5 then
            local striking=row;row=sample(data.clips.walk,(travel+(m.localTravel or 0))/data.stride*data.clips.walk.duration+m.phase*data.clips.walk.duration,true)
            local out={};for j,v in ipairs(row)do out[j]=v end
            for _,j in ipairs(combat.upper)do out[j]=striking[j]end;row=out
          end
        elseif speed>0.5 or (m.slotSpeed or 0)>.5 then
          mode=movingFire and 'runfire' or 'walk'
          row=sample(data.clips.walk,(travel+(m.localTravel or 0))/data.stride*data.clips.walk.duration+m.phase*data.clips.walk.duration,true)
          if movingFire and not combat.wholePaletteSource then
            local walking=row;row={};for j,r in ipairs(walking) do row[j]=r end
            m.walkShift={walking[combat.chest][1]-data.ready[combat.chest][1],walking[combat.chest][2]-data.ready[combat.chest][2],walking[combat.chest][3]-data.ready[combat.chest][3]}
            for _,j in ipairs(combat.upper) do row[j]=data.ready[j] end
          end
        elseif f<aimUntil then
          mode='ready';row=m.kneels and data.kneel_ready or data.ready
        else
          mode='idle';row=data.clips.idle.frames[1]
        end
        if mode=='runfire' and not combat.wholePaletteSource then
          local tx,tz=targetX,targetZ;local wanted=0
          if tx then local px,_,pz=Spring.GetUnitPiecePosDir(unitID,m.root);wanted=angle(math.atan2(tx-px,tz-pz)-m.yaw) end
          m.fireArc=math.abs(wanted)<1.15
          local limited=math.max(-1.15,math.min(1.15,wanted))
          local old=m.upperYaw or 0;m.upperYaw=old+math.max(-seconds*5,math.min(seconds*5,angle(limited-old)))
          row=upperAim(m,row,m.upperYaw,m.walkShift)
          m.upperReady=math.abs(angle(wanted-m.upperYaw))<.12
        else m.upperYaw=0;m.upperReady=false;m.fireArc=false end
        if m.mode~=mode then
          if m.mode=='melee' or mode=='melee' then m.armTransitionUntil=f+12 end
          publish('lod_mode_'..m.index,mode=='melee' and 3 or (mode=='ready' or mode=='runfire') and 2 or mode=='walk' and 1 or 0)
          m.mode=mode;m.transitionFrame=f;m.transitionFrom={}
          for j,v in ipairs(m.basePrevious or m.previous) do m.transitionFrom[j]=v end
        end
        row=blend(m.transitionFrom,row,(f-m.transitionFrame)/(mode=='melee' and 8 or 12))
        m.basePrevious=row
        -- Recoil is an actual-shot overlay, so starting to walk or changing
        -- pose cannot silently cancel the firing soldier's reaction.
        local age=(f-m.shotFrame)/fps
        if mode=='flight' then
          -- Flight clips are coherent whole-source poses, without gun overlays.
        elseif combat.wholePaletteSource and mode=='runfire' and age>=0 and age<.20 then
          -- Independent Sanctus piece palettes must remain a single source
          -- pose. A tiny rigid shot impulse preserves every joint/attachment;
          -- forward-only firing avoids inventing a disconnected torso twist.
          local out={};local kick=.08*math.sin(math.pi*age/.20)
          for j,base in ipairs(row) do out[j]={base[1],base[2],base[3]-kick,base[4],base[5],base[6]} end
          row=out
        elseif not (combat.wholePaletteSource and mode=='runfire') and age>=0 and age<data.recoil.duration then
          local recoil=sample(data.recoil,age,false);local out={}
          for j,base in ipairs(row) do
            local r={}
            for c=1,6 do
              local delta=recoil[j][c]-data.ready[j][c]
              r[c]=base[c]+(c>3 and angle(delta) or delta)
            end
            if mode=='runfire' then
              local dx=recoil[j][1]-data.ready[j][1];local dz=recoil[j][3]-data.ready[j][3]
              local c,s=math.cos(m.upperYaw),math.sin(m.upperYaw)
              r[1]=base[1]+c*dx+s*dz;r[3]=base[3]-s*dx+c*dz
            end
            out[j]=r
          end
          row=out
        end
        m.connectedPose=combat.hierarchy~=nil or mode=='melee' or f<(m.armTransitionUntil or -1)
        if m.connectedPose then row=keepArmsConnected(row);m.basePrevious=row end
        m.instantWalk=mode=='walk'
        apply(m,row,seconds)
      elseif m.state=='dying' then
        local clip=data.clips[(m.index%3==0 and 'die_alt2') or (m.index%3==1 and 'die') or 'die_alt']
        local age=(f-m.deathFrame)/fps
        if age>=clip.duration then
          remains(m);Move(m.root,y_axis,-1000);m.state='hidden';publish('hidden_'..m.index,1)
        else apply(m,sample(clip,age+seconds,false),seconds) end
      end
    end
    publish('travel',travel);publish('gait_phase',travel/data.stride)
    Sleep(interval*1000/fps)
    end
  end
end
local function chooseShooter(frame,requireAim)
  local candidates={}
  for i=1,alive do
    local m=members[i]
    local clip=m.kneels and data.kneel_recoil or data.recoil
    if m.state=='alive' and (not salvoPeriod or not salvoSpent[i]) and frame-m.shotFrame>=memberCooldown and (not requireAim or readyToFire(m,frame)) then candidates[#candidates+1]=i end
  end
  if #candidates>0 then return candidates[math.random(1,#candidates)] end
  return nil
end
function script.Create()
  -- Recenter after spread/mirror, preserving the authored irregular shape and
  -- pairwise spacing. Fixed home slots are retained when members become casualties.
  local centreX,centreZ=0,0
  for i=1,capacity do centreX=centreX+layout[i][1]*spread*mirror;centreZ=centreZ+layout[i][2]*spread end
  centreX,centreZ=centreX/capacity,centreZ/capacity
  heading=Spring.GetUnitHeading(unitID)*tau/65536;formationYaw=heading;targetYaw=heading
  for i,spec in ipairs(data.members) do
    local m={index=i,root=piece(spec.root),offset=spec.offset,bones={},muzzle=piece(spec.muzzle),
      previous={},state='alive',phase=(i-1)*0.137,yaw=heading,shotFrame=-1000,kneels=data.kneel_ready and i<=3}
    for b,name in ipairs(spec.bones) do m.bones[b]=piece(name) end
    m.slot={(layout[i][1]*spread*mirror-centreX)*formationScale,(layout[i][2]*spread-centreZ)*formationScale}
    m.homeSlot={m.slot[1],m.slot[2]};m.localTravel=0
    members[i]=m;apply(m,data.clips.idle.frames[1],0.1,true)
    publish('member_'..i,1);publish('hidden_'..i,0)
  end
  publish('capacity',capacity);publish('shots',0);strength(capacity);nextMuzzle=chooseShooter(Spring.GetGameFrame())
  facing();GG.SquadPresentation[unitID]=function() Spring.UnitScript.CallAsUnit(unitID,facing) end;StartThread(animate)
end
function script.StartMoving() end
function script.StopMoving() end
function script.AimFromWeapon() return aimCenter end
function script.QueryWeapon(n)
  if n==2 then return aimCenter end
  return members[activeMuzzle].muzzle
end
function script.AimWeapon(n,h,pitch)
  if airborne() then return false end
  -- The idle melee weapon must never overwrite the gun's target or facing.
  if n==2 then return engaged()~=nil and speed<2 end
  if n==1 and engaged() then return false end
  local f=Spring.GetGameFrame();targetYaw=Spring.GetUnitHeading(unitID)*tau/65536+(h or 0)
  -- Aim angles can change when the engine switches between dispersed muzzles.
  -- Face each soldier toward the actual world target, independent of the shooter.
  rangedTarget()
  aimUntil=f+fps*3
  publish('aimheading',h or 0);publish('aimframe',f)
  -- Whole-formation facing can leave the previously selected corner member
  -- outside the firing cone. Permit native aiming when ANY living member is
  -- aligned; BlockShot still owns random, cooldown-aware shooter selection.
  -- Do not consume RNG or change the physical QueryWeapon muzzle here.
  for i=1,alive do if readyToFire(members[i],f) then return true end end
  return false
end
function script.BlockShot(n)
  if airborne() then return true end
  if n==2 then return dead or alive<1 or not engaged() or speed>=2 end
  local f=Spring.GetGameFrame()
  if dead or alive<1 or engaged() or f<nextAllowed then return true end
  -- Native aiming can stay approved across a target/order change. Re-read the
  -- actual gun target at the last firing gate, never trust last frame's yaw.
  if not rangedTarget() then return true end
  if salvoPeriod and f>=salvoStart+salvoPeriod*fps then salvoSpent={} end
  nextMuzzle=chooseShooter(f,true)
  if not nextMuzzle then return true end
  local m=members[nextMuzzle]
  return not readyToFire(m,f)
end
function script.Shot(n)
  local f=Spring.GetGameFrame();aimUntil=f+fps*3
  if n==2 then
    strength(alive)
    -- Presentation cycles have independent phases and tempos; no synchronized reset.
    publish('melee_shots',(Spring.GetUnitRulesParam(unitID,prefix..'_melee_shots') or 0)+1)
    return
  end
  -- Engine calls Shot BEFORE QueryWeapon and creates the projectile afterwards.
  -- Select once here; Query must remain side-effect free throughout the shot.
  activeMuzzle=math.min(nextMuzzle,alive);local m=members[activeMuzzle]
  if salvoPeriod then
    if not next(salvoSpent) then salvoStart=f end
    salvoSpent[activeMuzzle]=true
    nextAllowed=f+math.max(1,math.floor(salvoSpacing*fps+.5))
  else
    local period=baseReload*fps*capacity/alive+cadenceFraction
    local ticks=math.floor(period+.000001);cadenceFraction=period-ticks;nextAllowed=f+ticks
  end
  m.shotFrame=f;m.meleeFrame=nil
  -- The member has already raised its weapon through a smooth ready transition.
  -- Never snap its pose here: the projectile and flash use the current barrel.
  shots=shots+1;publish('shots',shots);publish('shooter',activeMuzzle);publish('shotframe',f)
  EmitSfx(m.muzzle,1024)
  if f-lastSound>=(salvoPeriod and 5 or 12) and GG.SquadSound then GG.SquadSound(unitID,m.muzzle,f);lastSound=f end
  nextMuzzle=chooseShooter(f) or 1
end
function script.Killed()
  dead=true
  for _,m in ipairs(members)do m.instantWalk=false end
  local duration=0
  for _,m in ipairs(members) do
    if m.state=='alive' then
      m.deathClip=data.clips[(m.index%3==0 and 'die_alt2') or (m.index%3==1 and 'die') or 'die_alt']
      apply(m,m.deathClip.frames[1],0.1,true)
      duration=math.max(duration,m.deathClip.duration)
    end
  end
  for f=1,math.ceil(duration*fps),3 do
    for _,m in ipairs(members) do if m.state=='alive' then apply(m,sample(m.deathClip,f/fps,false),0.1) end end
    Sleep(100)
  end
  for _,m in ipairs(members) do if m.state~='hidden' then remains(m) end end
  GG.SquadPresentation[unitID]=nil
  return 0
end
