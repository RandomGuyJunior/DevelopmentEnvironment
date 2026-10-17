-- Read-only bounded native telemetry. No pose/animation/economy changes.
local M={Version=1,Option='prototype_scale_native_probe',Actors={space_marine=true,guardsman=true,imp_devastator=true},MaxPerSource=2,MaxSamples=48,Step=3}
function M.Enabled(options)local v=options and options[M.Option];return v==true or v==1 or v=='1'end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function text(v)
 if finite(v)then return string.format('%.17g',v)end
 return tostring(v):gsub('|','%%7C'):gsub(string.char(10),' '):gsub(string.char(13),' ')
end
local function values(a)local r={};for i=1,#a do r[i]=text(a[i])end;return table.concat(r,',')end
function M.New(S,U,V,echo,sharedCache,GG)
 local P={units={},counts={},born={}}
 local loader=V.Include('40k_configs/animation_bank_loader.lua')
 assert(type(sharedCache)=='table','Existing shared animation cache required')
 local function emit(kind,...)local a={...};for i=1,#a do a[i]=text(a[i])end;echo('40K_SCALE_NATIVE|'..kind..'|'..table.concat(a,'|'))end
 local function pack(...)return{...}end -- native zero returns become an empty vector
 local function register(id,def,frame)
  if P.units[id]then return end
  local d=U[def];local cp=d and d.customParams or{};local actor=cp.animsource
  if not M.Actors[actor]or(P.counts[actor]or 0)>=M.MaxPerSource then return end
  local factor=tonumber(cp.scale_pilot_factor)or 1
  assert(factor==1 or factor==.85,'Unreviewed scale factor')
  local key=cp.scale_animation_bank or actor
  local path=cp.scale_animation_bank and('scripts/40k_anim/'..key..'.lua')or('scripts/generated/'..actor..'_anim.lua')
  local bank=loader.Load(V,sharedCache,cp)
  assert(bank.bones and bank.clips,'Actual generated bank required')
  if factor==.85 then assert(bank.scaleDerivative and bank.scaleDerivative.factor==.85,'Scaled model/unscaled bank mixture')
  else assert(not bank.scaleDerivative,'Baseline model/scaled bank mixture')end
  local map=assert(S.GetUnitPieceMap(id),'Native piece map absent');local names={}
  for name in pairs(map)do names[#names+1]=name end;table.sort(names)
  local moving={};local selected={}
  local function add(name)if name and map[name]and not selected[name]then moving[#moving+1]=name;selected[name]=true end end
  add(bank.bones[1]);add('unit_aim')
  for _,name in ipairs(bank.bones)do if name:match('thigh')or name:match('calf')or name:match('foot')or name:match('hand')then add(name)end end
  for _,name in ipairs(bank.muzzles or{bank.muzzle})do add(name)end
  for _,mount in ipairs(d.weapons or{})do
   local wc=(WeaponDefs and WeaponDefs[mount.weaponDef]or{}).customParams or{}
   add(wc.source_muzzle)
   for name in tostring(wc.source_muzzle_pair or''):gmatch('[^,;]+')do add(name:match('^%s*(.-)%s*$'))end
  end
  local poseNames={};local known={};for _,name in ipairs(bank.bones)do known[name]=true end
  for _,name in ipairs(moving)do if known[name]and #poseNames<20 then poseNames[#poseNames+1]=name end end
  local row={actor=actor,factor=factor,map=map,pieces=moving,poseNames=poseNames,gaitCount=0,count=0,finished=frame,born=P.born[id]or frame,definition=def,bank=key}
  P.units[id]=row;P.counts[actor]=(P.counts[actor]or 0)+1
  local walk=bank.clips.walk or{};emit('BEGIN',id,actor,factor,frame,row.born,def,key,path,d.modelname or'',walk.source_fps or'',walk.duration or'',cp.locomotion_source_stride or'',cp.locomotion_playback or'')
  for _,name in ipairs(names)do
   local info=assert(S.GetUnitPieceInfo(id,map[name]),'Native piece info absent')
   emit('BIND_INFO',id,actor,factor,name,info.parent or'',values(info.offset or{}),values(info.min or{}),values(info.max or{}),info.isEmpty)
  end
 end
 function P.Created(id,def,frame)if U[def]and M.Actors[(U[def].customParams or{}).animsource]then P.born[id]=frame end end
 function P.Finished(id,def,frame)register(id,def,frame)end
 function P.Initial(frame)
  for _,id in ipairs(S.GetAllUnits()or{})do local hp,_,_,_,progress=S.GetUnitHealth(id);if hp and hp>0 and progress and progress>=1 then register(id,S.GetUnitDefID(id),frame)end end
 end
 function P.Destroyed(id)P.units[id]=nil;P.born[id]=nil end
 function P.Frame(frame)
  if frame%M.Step~=0 then return end
  local ids={};for id in pairs(P.units)do ids[#ids+1]=id end;table.sort(ids)
  for _,id in ipairs(ids)do local row=P.units[id]
   if row.count<M.MaxSamples and not S.GetUnitIsDead(id)then
    row.count=row.count+1
    local pos=pack(S.GetUnitPosition(id));local vel=pack(S.GetUnitVelocity(id));local collision=pack(S.GetUnitCollisionVolumeData(id));local front,up,right=S.GetUnitVectors(id)
    assert(#pos>=3 and #collision==10 and front and up and right,'Missing real native geometry getter data')
    emit('FRAME',id,row.actor,row.factor,frame,row.count,values(pos),values(vel),values(collision),S.GetGroundHeight(pos[1],pos[3]),S.GetUnitRulesParam(id,'40k_walk_review_frame')or'',values(front),values(up),values(right))
    for _,name in ipairs(row.pieces)do
     local piece=row.map[name];local mat=pack(S.GetUnitPieceMatrix(id,piece));local origin=pack(S.GetUnitPiecePosition(id,piece));local emitted=pack(S.GetUnitPiecePosDir(id,piece))
     assert(#mat==16 and #origin==3 and #emitted==6,'Missing named native piece vectors')
     local world={};for j=1,3 do world[j]=pos[j]+right[j]*origin[1]+up[j]*origin[2]+front[j]*origin[3]end
     local error=math.max(math.abs(origin[1]+mat[13]),math.abs(origin[2]-mat[14]),math.abs(origin[3]-mat[15]))
     emit('PIECE',id,row.actor,row.factor,frame,name,values(mat),values(origin),values(emitted),values(world),S.GetGroundHeight(world[1],world[3]),error)
    end
    for weapon in ipairs(U[row.definition].weapons or{})do
     local vector=pack(S.GetUnitWeaponVectors(id,weapon));local reload=S.GetUnitWeaponState(id,weapon,'reloadState')
     emit('WEAPON',id,row.actor,row.factor,frame,weapon,values(vector),reload)
    end
    if row.count==M.MaxSamples then emit('WINDOW_DONE',id,row.actor,row.factor,frame,'telemetry_only_not_geometry_or_gait_acceptance')end
   end
  end
 end
 function P.GaitFrame(frame)
  local fixture=GG and GG.Recoil40KGaitMovementFixture
  local registry=GG and GG.Recoil40KGaitPoseObservers
  if frame%M.Step~=0 or not fixture or not fixture.IsObserving or not registry then return end
  local ids={};for id in pairs(P.units)do ids[#ids+1]=id end;table.sort(ids)
  for _,id in ipairs(ids)do local r=P.units[id];local get=registry[id]
   if get and r.gaitLastFrame~=frame and r.gaitCount<M.MaxSamples and not S.GetUnitIsDead(id)and fixture.IsObserving(id,frame)then
    local p=get(frame,r.poseNames)
    if p and p.mode=='walk'and p.velocity[1]^2+p.velocity[3]^2>1e-8 then
     r.gaitCount=r.gaitCount+1;r.gaitLastFrame=frame
     emit('GAIT_PHASE',id,r.actor,r.factor,frame,r.gaitCount,p.bankKey,p.clip,p.sampleSeconds,p.fps,p.count,p.i,p.j,p.alpha,p.fractional,p.smooth,p.blendAge,p.blendAlpha,p.stride,p.rootName,values(p.velocity),table.concat(p.layers,','))
     local position=pack(S.GetUnitPosition(id));local front,up,right=S.GetUnitVectors(id)
     emit('GAIT_WORLD',id,r.actor,r.factor,frame,values(position),values(front),values(up),values(right))
     for _,name in ipairs(r.poseNames)do
      local mat=pack(S.GetUnitPieceMatrix(id,r.map[name]));local origin=pack(S.GetUnitPiecePosition(id,r.map[name]));local emitted=pack(S.GetUnitPiecePosDir(id,r.map[name]))
      assert(#mat==16 and #origin==3 and #emitted==6,'Missing native gait vectors')
      emit('GAIT_PIECE',id,r.actor,r.factor,frame,name,values(p.rows[name]),values(mat),values(origin),values(emitted))
      local info=assert(S.GetUnitPieceInfo(id,r.map[name]),'Missing native gait parent info')
      local parent=info.parent or'';local handle=r.map[parent]
      local parentMatrix=handle and pack(S.GetUnitPieceMatrix(id,handle))or{1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
      assert(handle or parent==''or parent=='[null]','Unknown native gait parent')
      emit('GAIT_PARENT',id,r.actor,r.factor,frame,name,parent,values(parentMatrix))
      for axis,witness in pairs(p.aim[name]or{})do emit('GAIT_AIM',id,r.actor,r.factor,frame,name,axis,witness.offset,witness.submitted)end
     end
     if r.gaitCount==M.MaxSamples then emit('GAIT_WINDOW_DONE',id,r.actor,r.factor,frame,'phase_matched_telemetry_only_not_pose_quality_acceptance')end
    end
   end
  end
 end
 return P
end
return M
