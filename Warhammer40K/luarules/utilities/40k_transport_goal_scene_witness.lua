-- Read-only terminal scene receipts for the explicitly opted transport fixture.
local M={}
local U='UNKNOWN'
local function call(S,k,...)
 if type(S[k])~='function'then return false,U end
 local ok,a,b,c,d,e,f,g,h=pcall(S[k],...);if not ok or a==nil then return false,U end
 return true,a,b,c,d,e,f,g,h
end
local function value(v)if v==nil then return U end;return v end
local function known(ok,v)if ok then return value(v)end;return U end
function M.New(S,D,F,emit)
 local lastFrame
 local function objects(kind,getter,defGetter,posGetter,blockingGetter,x,z,frame,goalID)
  local okay,list=call(S,getter,x,z,192)
  if not okay or type(list)~='table'then emit('GOAL_SCENE_LIST',frame,goalID,kind,U,U,U);return end
  table.sort(list);emit('GOAL_SCENE_LIST',frame,goalID,kind,#list,math.min(32,#list),#list>32)
  for i=1,math.min(32,#list)do local id=list[i];local okay,def=call(S,defGetter,id);local d=(okay and (kind=='unit'and D or F or{})[def])or{};local md=d.moveDef or{}
   local pos,px,py,pz=call(S,posGetter,id);local block,b1,b2,b3,b4,b5,b6,b7=call(S,blockingGetter,id)
   emit('GOAL_SCENE_OBJECT',frame,goalID,kind,id,okay and def or U,value(d.name),pos and px or U,value(py),value(pz),value(d.xsize),value(d.zsize),value(md.xsize),value(md.zsize),value(md.maxSlope),value(d.radius),known(block,b1),value(b2),value(b3),value(b4),value(b5),value(b6),value(b7))
  end
 end
 local R={}
 function R.Terminal(cycle,ids,goals)
  local okay,frame=call(S,'GetGameFrame');if not okay then emit('GOAL_SCENE',U,cycle,U,'native_frame_unreadable');return end
  if frame==lastFrame then return end;lastFrame=frame
  for _,id in ipairs(ids)do local goal=goals[id]
   if not goal then emit('GOAL_SCENE',frame,cycle,id,'assigned_goal_unreadable')
   else
    local okay,def=call(S,'GetUnitDefID',id);local ground,y=call(S,'GetGroundHeight',goal.x,goal.z)
    local terrainOkay,terrain,fullOkay,full,defaultOkay,default
    if okay and ground then terrainOkay,terrain=call(S,'TestMoveOrder',def,goal.x,y,goal.z,0,0,0,true,false,false);fullOkay,full=call(S,'TestMoveOrder',def,goal.x,y,goal.z,0,0,0,true,true,false);defaultOkay,default=call(S,'TestMoveOrder',def,goal.x,y,goal.z)end
    emit('GOAL_SCENE',frame,cycle,id,goal.x,ground and y or U,goal.z,okay and def or U,'terrain_only',known(terrainOkay,terrain),'terrain_objects',known(fullOkay,full),'native_defaults',known(defaultOkay,default),'radius',192,'cap_each',32)
    local ready,mt=call(S,'GetUnitMoveTypeData',id);mt=ready and type(mt)=='table'and mt or{}
    emit('GOAL_SCENE_MOVE',frame,id,value(mt.progressState),value(mt.goalRadius),value(mt.goalx),value(mt.goaly),value(mt.goalz),value(mt.currwaypointx),value(mt.currwaypointy),value(mt.currwaypointz),value(mt.nextwaypointx),value(mt.nextwaypointy),value(mt.nextwaypointz),value(mt.currentSpeed),value(mt.wantedSpeed),'extraRadius',U,'idlingSlowUpdates',U,'pathFailures_not_native_count',U)
    local ready,path,starts=call(S,'GetUnitEstimatedPath',id)
    if not ready or type(path)~='table'then emit('GOAL_SCENE_PATH',frame,id,'unavailable_or_no_native_path',U,U,U)
    else
     emit('GOAL_SCENE_PATH',frame,id,'native_estimated_nodes',#path,math.min(32,#path),#path>32)
     for i=1,math.min(32,#path)do local p=type(path[i])=='table'and path[i]or{};emit('GOAL_SCENE_PATH_NODE',frame,id,i,value(p[1]),value(p[2]),value(p[3]))end
     emit('GOAL_SCENE_PATH_STARTS',frame,id,type(starts)=='table'and #starts or U)
    end
    objects('unit','GetUnitsInCylinder','GetUnitDefID','GetUnitPosition','GetUnitBlocking',goal.x,goal.z,frame,id)
    objects('feature','GetFeaturesInCylinder','GetFeatureDefID','GetFeaturePosition','GetFeatureBlocking',goal.x,goal.z,frame,id)
   end
  end
 end
 return R
end
return M
