-- Diagnostic snapshots only. Existing actors/banks/clocks remain authoritative.
local M={Actors={guardsman=true,space_marine=true,imp_devastator=true},MaxPieces=20}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function integer(v)return finite(v)and v==math.floor(v)end
function M.New(options,GG)
 local enabled=options and options.prototype_scale_native_probe
 if not(enabled==true or enabled==1 or enabled=='1')then return nil end
 GG.Recoil40KGaitPoseObservers=GG.Recoil40KGaitPoseObservers or{}
 local registry=GG.Recoil40KGaitPoseObservers
 if options.prototype_terminator_native_observer==true or options.prototype_terminator_native_observer==1 or options.prototype_terminator_native_observer=='1'then
  VFS.Include('40k_configs/terminator_scale_pair.lua').ValidateOptions(options)
  M.Actors.imp_terminator=true -- opt-in observer only; clocks/pose buffers unchanged.
 end
 local states={};local P={}
 function P.Register(id,actor,bones,bankKey,factor)
  assert(integer(id)and id>0 and M.Actors[actor],'Unreviewed gait actor')
  assert(finite(factor)and(math.abs(factor-1)<1e-6 or math.abs(factor-.85)<1e-6),'Unreviewed gait factor')
  local paired=math.abs(factor-.85)<1e-6
  assert(bankKey==(paired and('scripts/40k_anim/'..actor..'_scale085.lua')or actor),'Mixed gait bank identity')
  assert(not states[id]and not registry[id],'Duplicate gait observer')
  local indices={};for i,name in ipairs(bones)do
   assert(type(name)=='string','Invalid bone name');if not indices[name]then indices[name]=i end
  end
  local state={actor=actor,bankKey=bankKey,factor=factor,indices=indices};states[id]=state
  local function getter(frame,names)
   local meta,row=state.meta,state.row
   if not meta or frame~=meta.frame then return nil,'no_same_frame_pose'end
   assert(type(names)=='table'and #names<=M.MaxPieces,'Gait snapshot piece bound')
   local result={frame=meta.frame,actor=actor,bankKey=bankKey,factor=factor,mode=meta.mode,
    sampleSeconds=meta.sampleSeconds,fps=meta.fps,count=meta.count,i=meta.i,j=meta.j,alpha=meta.alpha,
    fractional=meta.fractional,smooth=meta.smooth,blendAge=meta.blendAge,blendAlpha=meta.blendAlpha,
    stride=meta.stride,rootName=meta.rootName,clip=meta.clip,rows={},aim={},layers={},velocity={}}
   for i=1,3 do result.velocity[i]=meta.velocity[i]end
   for i,v in ipairs(meta.layers or{})do assert(i<=12 and type(v)=='string','Layer bound');result.layers[i]=v end
   local selected={}
   for _,name in ipairs(names)do
    assert(type(name)=='string'and not selected[name],'Duplicate/invalid selected bone');selected[name]=true
    local index=assert(indices[name],'Unknown selected bone');local source=assert(row[index],'Missing composed pose row')
    local copied={};for k=1,6 do assert(finite(source[k]),'Invalid pose channel');copied[k]=source[k]end
    result.rows[name]=copied
    local axes=meta.aim and meta.aim[name]
    if axes then
     local aim={};for axis=1,3 do local value=axes[axis];if value~=nil then
      assert(type(value)=='table'and finite(value.offset)and finite(value.submitted),'Invalid aim witness')
      aim[axis]={offset=value.offset,submitted=value.submitted}
     end end;result.aim[name]=aim
    end
   end
   return result
  end
  state.getter=getter;registry[id]=getter
  return function(meta,row)
   assert(states[id]==state,'Destroyed gait observer')
   assert(type(meta)=='table'and type(row)=='table'and integer(meta.frame)and meta.frame>=0,'Invalid gait publication')
   assert(not state.meta or meta.frame>=state.meta.frame,'Backwards gait frame')
   assert(type(meta.mode)=='string'and type(meta.clip)=='string'and type(meta.rootName)=='string','Missing pose identity')
   assert(finite(meta.sampleSeconds)and meta.sampleSeconds>=0 and finite(meta.fps)and meta.fps>0
    and integer(meta.count)and meta.count>0,'Missing actual clip clock')
   assert(type(meta.velocity)=='table'and finite(meta.velocity[1])and finite(meta.velocity[2])and finite(meta.velocity[3]),'Missing actual velocity')
   assert(finite(meta.stride)and meta.stride>0 and finite(meta.blendAge)and finite(meta.blendAlpha),'Missing stride/blend')
   assert(type(meta.fractional)=='boolean'and type(meta.smooth)=='boolean','Missing sampling flags')
   assert(meta.blendAlpha>=0 and meta.blendAlpha<=1,'Invalid blend fraction')
   local velocity={meta.velocity[1],meta.velocity[2],meta.velocity[3]}
   local layers,aim={},{};local aimCount=0
   for i,label in ipairs(meta.layers or{})do assert(i<=12 and type(label)=='string','Layer bound');layers[i]=label end
   for name,axes in pairs(meta.aim or{})do
    aimCount=aimCount+1;assert(aimCount<=M.MaxPieces and indices[name],'Aim witness bound/identity')
    local copied={};for axis=1,3 do local value=axes[axis];if value~=nil then
     assert(type(value)=='table'and finite(value.offset)and finite(value.submitted),'Invalid aim witness')
     copied[axis]={offset=value.offset,submitted=value.submitted}
    end end;aim[name]=copied
   end
   local position=(meta.sampleSeconds*meta.fps)%meta.count
   local i=math.floor(position)+1;local j=i%meta.count+1;local alpha=position-math.floor(position)
   if not meta.fractional then j=i;alpha=0
   elseif alpha<1e-10 then alpha=0
   elseif 1-alpha<1e-10 then i=j;j=i%meta.count+1;alpha=0 end
   -- Copy small scalar clock metadata; retain only the already composed row reference.
   state.meta={frame=meta.frame,mode=meta.mode,clip=meta.clip,rootName=meta.rootName,sampleSeconds=meta.sampleSeconds,
    fps=meta.fps,count=meta.count,i=i,j=j,alpha=alpha,
    fractional=meta.fractional,smooth=meta.smooth,stride=meta.stride,blendAge=meta.blendAge,blendAlpha=meta.blendAlpha,
    velocity=velocity,layers=layers,aim=aim}
   state.row=row
  end
 end
 function P.Invalidate(id)
  local state=states[id];if state then state.meta=nil;state.row=nil end
 end
 function P.Clear(id)
  local state=states[id];if state and registry[id]==state.getter then registry[id]=nil end
  states[id]=nil
 end
 return P
end
return M
