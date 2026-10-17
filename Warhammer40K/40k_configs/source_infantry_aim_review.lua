-- Acceptance-only observation. No weapon, target, pose or movement mutations.
local M={}
local unpackValues=unpack or table.unpack
local sampleFrames={}
local groundObserver
local function quote(s)
 return '"'..s:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',string.byte(c))end)..'"'
end
local function encode(data)
 local remaining=256;local truncated=false
 local function visit(v,depth)
  remaining=remaining-1
  if remaining<0 or depth>8 then truncated=true;return 'null'end
  if v==nil then return 'null'end
  if type(v)=='boolean'then return tostring(v)end
  if type(v)=='number'then if v~=v or math.abs(v)==math.huge then return 'null'end;return string.format('%.17g',v)end
  if type(v)=='string'then if #v>1024 then truncated=true;v=v:sub(1,1024)end;return quote(v)end
  if type(v)~='table'then truncated=true;return 'null'end
  local keys={};local array=true;local count=0
  for k in pairs(v)do count=count+1;if count>256 then truncated=true;break end;keys[#keys+1]=k;if type(k)~='number'or k<1 or k%1~=0 then array=false end end
  if #keys~=#v then array=false end
  if array then local out={};for i=1,#keys do out[i]=visit(v[i],depth+1)end;return '['..table.concat(out,',')..']'end
  table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
  local out={};for _,k in ipairs(keys)do out[#out+1]=quote(tostring(k))..':'..visit(v[k],depth+1)end;return '{'..table.concat(out,',')..'}'
 end
 local body=visit(data,0);return body,truncated
end
local function sceneLog(S,id,frame,scene,reason)
 local function emit(event,index,data)
  local body,truncated=encode(data)
  S.Echo('40K_GROUND_LOF {"event":'..quote(event)..',"actor":'..id..',"frame":'..frame..',"index":'..index..',"serialization_truncated":'..tostring(truncated)..',"data":'..body..'}')
 end
 if not scene then emit('unreadable',0,{reason=reason or'unknown',native_cause_proven=false});return end
 local header={reason=reason or'snapshot',native_cause_proven=false}
 for k,v in pairs(scene)do if k~='samples'and k~='nearby'and k~='unreadable_objects'then header[k]=v end end
 emit('summary',0,header)
 for _,key in ipairs({'samples','nearby','unreadable_objects'})do
  local rows=scene[key]or{};local count=math.min(64,#rows)
  for i=1,count do emit(key,i,rows[i])end
  emit(key..'_coverage',0,{available=#rows,emitted=count,log_truncated=#rows>count})
 end
end
function M.Enabled(opts)
 return opts.prototype_diagnostic=='expandedproduction' and VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(opts.prototype_source_progression)
  and opts.prototype_source_acceptance=='imperium'
end
function M.New(S,opts,id,cp,registry)
 if not M.Enabled(opts) or tostring(cp.prototype40k_source_progression)~='1'then return nil end
 local r={moving=false,stage='created',frame=S.GetGameFrame(),entered=0,returned=0,rejected=0,fires=0,shots=0}
 registry[id]=r
 return function(stage,n,heading,pitch)
  r.stage=stage;r.frame=S.GetGameFrame();r.weapon=n or r.weapon;r.heading=heading or r.heading;r.pitch=pitch or r.pitch
  if stage=='moving'then r.moving=true elseif stage=='stopped'then r.moving=false
  elseif stage=='aim_enter'then r.entered=r.entered+1
  elseif stage=='aim_ready'then r.returned=r.returned+1;r.outcome=stage
  elseif stage:sub(1,7)=='reject_'then r.rejected=r.rejected+1;r.outcome=stage
  elseif stage=='fire'then r.fires=r.fires+1 elseif stage=='shot'then r.shots=r.shots+1 end
 end
end
local function value(v)if v==nil then return 'missing'else return tostring(v)end end
function M.Observe(S,id,registry)
 if not M.Enabled(S.GetModOptions())then return false end
 local frame=S.GetGameFrame();local r=registry and registry[id] or {}
 -- Fixed sampling prevents repeated Aim callbacks becoming per-frame telemetry.
 if sampleFrames[id] and frame-sampleFrames[id]<300 then return false end
 sampleFrames[id]=frame
 local good,loaded,reload,salvo,stock=S.GetUnitWeaponState(id,1)
 local targetType,user,target=S.GetUnitWeaponTarget(id,1)
 local cmd,options,tag,x,y,z=S.GetUnitCurrentCommand(id)
 local states=S.GetUnitStates(id)or{}
 local scene,sceneReason
 if cmd==20 and type(x)=='number'and type(y)=='number'and type(z)=='number'then
  local okay,result,reason=pcall(function()
   groundObserver=groundObserver or VFS.Include('40k_configs/40k_ground_lof_observer.lua')
   return groundObserver.Snapshot(S,UnitDefs or{},WeaponDefs or{},Game or{},id,1,{enabled=true,readScriptAimFrom=true,attackCommand=20,maxSamples=64,maxObjects=64})
  end)
  if okay then scene,sceneReason=result,reason else sceneReason='snapshot_read_failed:'..tostring(result)end
 end
 local mx,my,mz,dx,dy,dz=S.GetUnitWeaponVectors(id,1)
 local tx,ty,tz,unitTarget
 if targetType==1 then unitTarget=target;tx,ty,tz=S.GetUnitPosition(target)
 elseif targetType==2 and type(target)=='table'then tx,ty,tz=target[1],target[2],target[3]
 elseif cmd==20 and type(x)=='number'and type(y)=='number'and type(z)=='number'then tx,ty,tz=x,y,z end
 local valid,inrange,muzzleLOF,pivotLOF
 local ax,ay,az
 if scene and scene.pivot then ax,ay,az=unpackValues(scene.pivot)end
 if unitTarget then valid=S.GetUnitWeaponTestTarget(id,1,unitTarget);inrange=S.GetUnitWeaponTestRange(id,1,unitTarget)
 elseif tx and ty and tz then valid=S.GetUnitWeaponTestTarget(id,1,tx,ty,tz);inrange=S.GetUnitWeaponTestRange(id,1,tx,ty,tz)end
 if mx and tx and ty and tz then muzzleLOF=S.GetUnitWeaponHaveFreeLineOfFire(id,1,mx,my,mz,tx,ty,tz)end
 if ax and tx and ty and tz then pivotLOF=S.GetUnitWeaponHaveFreeLineOfFire(id,1,ax,ay,az,tx,ty,tz)end
 local ground=mx and S.GetGroundHeight(mx,mz)
 local fields={'40K SOURCE INFANTRY AIM REVIEW',id,frame,'scriptMoving',r.moving,'stage',r.stage,'stageFrame',r.frame,
 'outcome',r.outcome,'entered',r.entered,'ready',r.returned,'rejected',r.rejected,'fires',r.fires,'shots',r.shots,
 'angleGood',good,'loaded',loaded,'reloadFrame',reload,'salvoLeft',salvo,'stockpiled',stock,
 'targetType',targetType,'userTarget',user,'unitTarget',unitTarget,'command',cmd,'options',options,'tag',tag,
 'commandX',x,'commandY',y,'commandZ',z,'firestate',states.firestate,'muzzleX',mx,'muzzleY',my,'muzzleZ',mz,
 'muzzleGround',ground,'muzzleClearance',my and ground and my-ground,'directionX',dx,'directionY',dy,'directionZ',dz,
 'aimX',ax,'aimY',ay,'aimZ',az,'targetX',tx,'targetY',ty,'targetZ',tz,
 'testTarget',valid,'testRange',inrange,'muzzleLOF',muzzleLOF,'pivotLOF',pivotLOF}
 -- Preserve nil fields rather than table-constructor holes: explicit fixed arity.
 local names={'scriptMoving','stage','stageFrame','outcome','entered','ready','rejected','fires','shots','angleGood','loaded','reloadFrame','salvoLeft','stockpiled','targetType','userTarget','unitTarget','command','options','tag','commandX','commandY','commandZ','firestate','muzzleX','muzzleY','muzzleZ','muzzleGround','muzzleClearance','directionX','directionY','directionZ','aimX','aimY','aimZ','targetX','targetY','targetZ','testTarget','testRange','muzzleLOF','pivotLOF'}
 local out={fields[1],id,frame};for i=1,#names do out[#out+1]=names[i];out[#out+1]=value(fields[2*i+3])end
 S.Echo(unpackValues(out))
 if cmd==20 and type(x)=='number'and type(y)=='number'and type(z)=='number'then sceneLog(S,id,frame,scene,sceneReason)end
 return true
end
return M
