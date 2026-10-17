-- Read-only existing-roster Slugga melee observer. Never changes orders/weapon state.
local M={}
local function pack(...)return {n=select('#',...),...}end
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function val(x)if x==nil then return 'unknown'end;if type(x)=='table'then return 'table'end;return x end
function M.New(S,defs,emit)
 local last={};local count={}
 local function read(name,...)
  if type(S[name])~='function'then return {n=0,reason='unavailable'}end
  local out=pack(pcall(S[name],...));if not out[1]then return {n=0,reason='read_error'}end
  local result={n=out.n-1};for i=2,out.n do result[i-1]=out[i]end
  if result.n==0 then result.reason='unobserved'end
  return result
 end
 local api={}
 function api.Observe(a,frame)
  if not a or a.name~='ork_slugga'or a.phase~='melee'or (a.hits or 0)>0 or frame-a.start<120 then return false end
  local key=a.id..':'..a.mount..':'..a.start
  if (count[key]or 0)>=3 or (last[key]and frame-last[key]<300)then return false end
  local w=a.ud and a.ud.weapons and a.ud.weapons[a.mount];local wd=w and defs[w.weaponDef or w.weaponDefID]
  if not wd or wd.type~='Melee'then return false end
  last[key]=frame;count[key]=(count[key]or 0)+1
  local id,n,target=a.id,a.mount,a.target
  local state=read('GetUnitWeaponState',id,n) -- five native returns; no invented keyed angleGood/aimReady
  local wt=read('GetUnitWeaponTarget',id,n);local vectors=read('GetUnitWeaponVectors',id,n)
  local pos=read('GetUnitPosition',target);local cmd=read('GetUnitCurrentCommand',id)
  local cp=wd.customParams or {};local map=read('GetUnitPieceMap',id)[1]or {}
  local function piece(name)
   if not name or not map[name]then return {n=0,reason='source_marker_unobserved'}end
   return read('GetUnitPiecePosDir',id,map[name])
  end
  local muzzle=piece(cp.source_muzzle);local aim=piece(cp.source_aimpiece)
  local ground={n=0,reason='nonfinite_native_muzzle'}
  local explicit={n=0,reason='nonfinite_native_muzzle'};local coordinates={n=0,reason='nonfinite_native_coordinates'}
  if finite(vectors[1])and finite(vectors[2])and finite(vectors[3])then
   ground=read('GetGroundHeight',vectors[1],vectors[3])
   explicit=read('GetUnitWeaponHaveFreeLineOfFire',id,n,vectors[1],vectors[2],vectors[3],target)
   if finite(pos[1])and finite(pos[2])and finite(pos[3])then
    coordinates=read('GetUnitWeaponHaveFreeLineOfFire',id,n,vectors[1],vectors[2],vectors[3],pos[1],pos[2],pos[3])
   end
  end
  local states=read('GetUnitStates',id)[1];local ally=read('GetUnitAllyTeam',id)[1]
  local los=ally and read('GetUnitLosState',target,ally)[1]
  local losBits=ally and read('GetUnitLosState',target,ally,true)[1]
  local function field(t,k)return type(t)=='table'and val(t[k])or 'unknown'end
  local function first(t)return val(t[1])end
  local dot='unknown'
  if finite(vectors[4])and finite(vectors[5])and finite(vectors[6])and finite(muzzle[4])and finite(muzzle[5])and finite(muzzle[6])then
   local l=math.sqrt(vectors[4]^2+vectors[5]^2+vectors[6]^2)*math.sqrt(muzzle[4]^2+muzzle[5]^2+muzzle[6]^2)
   if l>0 then dot=(vectors[4]*muzzle[4]+vectors[5]*muzzle[5]+vectors[6]*muzzle[6])/l end
  end
  emit('MELEE NATIVE GATES',a.name,n,'frame',frame,'id',id,'configuredTarget',target,'targetType',first(wt),'userTarget',val(wt[2]),'nativeTarget',val(wt[3]),
   'stateObserved',state.n==5,'angleGood',first(state),'reloadReady',val(state[2]),'reloadFrame',val(state[3]),'salvoLeft',val(state[4]),'stockpiled',val(state[5]),
   'canFire',first(read('GetUnitWeaponCanFire',id,n)),'ignoreAngle',first(read('GetUnitWeaponCanFire',id,n,true)),
   'ignoreTargetType',first(read('GetUnitWeaponCanFire',id,n,false,true,false)),'ignoreRequestedDir',first(read('GetUnitWeaponCanFire',id,n,false,false,true)),'ignoreAngleAndRequestedDir',first(read('GetUnitWeaponCanFire',id,n,true,false,true)),
   'testTarget',first(read('GetUnitWeaponTestTarget',id,n,target)),'testRange',first(read('GetUnitWeaponTestRange',id,n,target)),
   'aimLineOfFire',first(read('GetUnitWeaponHaveFreeLineOfFire',id,n,target)),'muzzleLineOfFire',first(explicit),'coordinateLineOfFire',first(coordinates),
   'muzzle',val(vectors[1]),val(vectors[2]),val(vectors[3]),'ground',first(ground),'muzzleAboveGround',finite(ground[1])and finite(vectors[2])and vectors[2]-ground[1]or 'unknown',
   'wantedDirection',val(vectors[4]),val(vectors[5]),val(vectors[6]),'marker',cp.source_muzzle or 'unobserved','markerWorld',val(muzzle[1]),val(muzzle[2]),val(muzzle[3]),
   'markerDirection',val(muzzle[4]),val(muzzle[5]),val(muzzle[6]),'wantedVsMarkerDot',dot,'sourceAim',cp.source_aimpiece or 'unobserved','sourceAimWorld',val(aim[1]),val(aim[2]),val(aim[3]),
   'targetPosition',val(pos[1]),val(pos[2]),val(pos[3]),'losBits',val(losBits),'inLos',type(los)=='table'and los.los==true or type(los)~='table'and 'unknown','inRadar',type(los)=='table'and los.radar==true or type(los)~='table'and 'unknown','firestate',field(states,'firestate'),'movestate',field(states,'movestate'),
   'currentCommand',first(cmd),'commandOptions',val(cmd[2]),'commandTag',val(cmd[3]),'commandParameter1',val(cmd[4]),'samples',count[key],'nativeAcceptance',false)
  return true
 end
 return api
end
return M
