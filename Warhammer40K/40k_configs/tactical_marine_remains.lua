-- One native reclaim feature for one paid squad-member generation.
-- Root binds Snapshot at UnitDestroyed above squad layer40, and Killed from LUS.
-- No resource payout, regeneration, second wreck or resurrection owner here.
local M={Version=1,Feature='40k_tactical_marine_corpse',Fraction=.25,Actors={
 space_marine={feature='40k_tactical_marine_corpse',name='Tactical Marine'},
 guardsman={feature='40k_guardsman_corpse',name='Guardsman'},
 ork_boy={feature='40k_shoota_boy_corpse',name='Shoota Boy'},
 nec_warrior={feature='40k_necron_warrior_corpse',name='Necron Warrior'},
 imp_devastator={feature='40k_heavy_marine_corpse',name='Heavy Bolter Marine'}}}
local function finite(v)return type(v)=='number'and v==v and v>=0 and v<math.huge end
local function integer(v)return finite(v)and v%1==0 end
local function marked(v)return v==true or v==1 or v=='1'end
function M.Definition(model,actor)
 actor=actor or'space_marine';local row=assert(M.Actors[actor],'Unsupported corpse actor')
 return{name=row.name..' remains',description='Reclaimable fallen '..row.name,object=model or(row.feature..'.glb'),
  blocking=false,reclaimable=true,autoreclaimable=true,resurrectable=0,indestructible=true,flammable=false,damage=100,health=100,
  metal=0,energy=0,reclaimtime=1,footprintx=1,footprintz=1,featuredead='',
  customparams={prototype40k_tactical_remains=1,parent_actor=actor,corpse_schema=1}}
end
function M.Definitions()
 local result={};for actor,row in pairs(M.Actors)do result[row.feature]=M.Definition(nil,actor)end;return result
end
function M.New(S,U,F,W,P,salvagePolicy)
 local R={pending={},features={},entitlements={},flights={},damage={},blasts={}};local featureDefs,actorsByFeature={},{}
 for id,d in pairs(F)do
  local cp=d.customParams or{}
  for actor,row in pairs(M.Actors)do
   if d.name==row.feature and marked(cp.prototype40k_tactical_remains)and d.reclaimable and d.resurrectable==0
    and(cp.parent_actor==actor or(actor=='space_marine'and cp.parent_actor==nil))then
    assert(not featureDefs[actor],'Duplicate corpse definition');featureDefs[actor]=id;actorsByFeature[id]=actor
   end
  end
 end
 assert(featureDefs.space_marine,'Genuine Tactical corpse definition required')
 local protected=salvagePolicy and salvagePolicy.ProtectedFeatures(U,F)or{}
 for def in pairs(actorsByFeature)do protected[def]=true end
 function R.FeaturePreDamaged(fid,def,team,damage)
  if protected[def]then return 0,0 end
  return damage -- preserve native impulse for unrelated scenery
 end
 local throwing=P and P.enabled==true
 local function signed(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
 if throwing then
  for _,api in ipairs({'SetFeatureMoveCtrl','SetFeaturePosition','SetFeatureNoSelect','GetGroundHeight','GetFeaturesInCylinder','GetFeatureBlocking','GetFeaturePosition','GetFeatureHeight','GetFeatureRadius','GetUnitsInCylinder','GetUnitBlocking','GetUnitPosition','GetUnitHeight','GetUnitRadius','GetUnitIsDead'})do assert(type(S[api])=='function','Missing native throw API '..api)end
  assert(type(W)=='table'and P.quantum==256 and finite(P.gravity)and P.gravity>0 and finite(P.maxFrames)and P.maxFrames<=120 and P.maxFrames>=1 and P.maxFrames%1==0
   and finite(P.horizontalSpeed)and P.horizontalSpeed>0 and P.horizontalSpeed<=4 and finite(P.upSpeed)and P.upSpeed>0 and P.upSpeed<=6
   and finite(P.bodyRadius)and P.bodyRadius>0 and P.bodyRadius<=16 and finite(P.sweepStep)and P.sweepStep>=1 and type(P.types)=='table','Invalid bounded throw policy')
 end
 local mapX=throwing and(P.mapSizeX or(Game and Game.mapSizeX));local mapZ=throwing and(P.mapSizeZ or(Game and Game.mapSizeZ))
 if throwing then assert(finite(mapX)and mapX>0 and finite(mapZ)and mapZ>0,'Native map bounds required')end
 local function explosive(weapon)
  local d=throwing and W[weapon];return d and P.types[d.type]and finite(d.damageAreaOfEffect)and d.damageAreaOfEffect>=P.minBlastRadius
 end
 function R.WatchedWeapons()
  local result={};for id in pairs(W or{})do if explosive(id)then result[#result+1]=id end end;table.sort(result);return result
 end
 function R.Explosion(weapon,x,y,z,owner,projectile)
  if explosive(weapon)and integer(projectile)and signed(x)and signed(y)and signed(z)then R.blasts[projectile]={weapon=weapon,x=x,y=y,z=z,frame=S.GetGameFrame()}end
  return false -- retain native graphical explosion; no damage modification.
 end
 function R.Damaged(id,def,team,damage,paralyzer,weapon,projectile)
  R.damage[id]=nil
  if not explosive(weapon)or paralyzer or not finite(damage)or damage<=0 then return false end
  local d=U[def];if not d or not featureDefs[(d.customParams or{}).animsource]then return false end
  local hp,_,_,_,progress=S.GetUnitHealth(id);if not hp or hp>0 or not progress or progress<1 then return false end
  if S.GetUnitTransporter and S.GetUnitTransporter(id)then return false end
  local blast=R.blasts[projectile];if not blast or blast.weapon~=weapon or blast.frame~=S.GetGameFrame()then return false end
  R.damage[id]={def=def,team=team,frame=blast.frame,x=blast.x,y=blast.y,z=blast.z};return true
 end
 local function get(id,k)return S.GetUnitRulesParam(id,'40k_squad_'..k)end
 local function eligible(def)
  local d=U[def];local cp=d and d.customParams or{}
  return d and featureDefs[cp.animsource]~=nil and (d.corpse==nil or d.corpse=='')and(d.wreckName==nil or d.wreckName=='')
 end
 function R.Snapshot(id,def,team)
  R.pending[id]=nil
  if not eligible(def)then return false end
  local hp,max,_,_,progress=S.GetUnitHealth(id)
  if not hp or not finite(max)or not progress or progress<1 then return false end
  local actualWork,actualMetal,actualEnergy=S.GetUnitCosts(id)
  if not finite(actualWork)or actualWork<=0 or not finite(actualMetal)or not finite(actualEnergy)then return false end
  local squad,slot,generation,m,e,w
  local cp=U[def].customParams or{}
  if cp.prototype40k_squad_product or marked(cp.prototype40k_squad_internal)then
   if get(id,'schema')~=2 then return false end
   squad,slot,generation=get(id,'id'),get(id,'slot'),get(id,'generation')
   if not integer(squad)or squad<1 or not integer(slot)or slot<1 or not integer(generation)or generation<1 then return false end
   m,e,w=get(id,'investment_metal'),get(id,'investment_energy'),get(id,'investment_work')
   if not finite(m)or not finite(e)or not finite(w)or w<=0 then return false end
   -- Never let stale/forged record values exceed this paid body's actual costs.
   m,e,w=math.min(m,actualMetal),math.min(e,actualEnergy),math.min(w,actualWork)
  else
   -- Individually paid non-squad Tactical actors use actual mutable native costs.
   squad,slot,generation=0,id,S.GetGameFrame()+1;m,e,w=actualMetal,actualEnergy,actualWork
  end
  local x,y,z=S.GetUnitPosition(id);local heading=S.GetUnitHeading(id)
  if type(x)~='number'or type(y)~='number'or type(z)~='number'or not heading then return false end
  local death=R.damage[id];R.damage[id]=nil
  if death and(death.def~=def or death.team~=team or death.frame~=S.GetGameFrame())then death=nil end
  R.pending[id]={throw=death,actor=cp.animsource,def=def,team=team,squad=squad,slot=slot,generation=generation,metal=m*M.Fraction,energy=0,
   work=math.max(1,w*M.Fraction),x=x,y=y,z=z,heading=heading,frame=S.GetGameFrame()}
  return true
 end
 local function publish(fid,row)
  for _,k in ipairs({'squad','slot','generation','metal','energy','work','team','def'})do S.SetFeatureRulesParam(fid,'40k_remains_'..k,row[k],{private=true})end
  S.SetFeatureRulesParam(fid,'40k_remains_version',M.Version,{private=true})
 end
 local function identity(row)return row.squad..':'..row.slot..':'..row.generation end
 local function initialize(fid,row)
  S.SetFeatureResources(fid,row.metal,0,row.work,1,row.metal,0)
  local m,dm,e,de,left,time=S.GetFeatureResources(fid)
  if not finite(m)or not finite(dm)or m~=dm or math.abs(m-row.metal)>.001 or e~=0 or de~=0 or left~=1 or not finite(time)or math.abs(time-row.work)>.001 then
   S.DestroyFeature(fid);return false,'native_resource_readback_failed'
  end
  publish(fid,row);R.features[fid]=row;if R.piles then R.piles.Observe(fid)end;return true
 end
 local flightKeys={'px','py','pz','vx','vy','vz','born','last'}
 local function flightPublish(fid,t)
  for _,k in ipairs(flightKeys)do S.SetFeatureRulesParam(fid,'40k_remains_flight_'..k,t[k],{private=true})end
  S.SetFeatureRulesParam(fid,'40k_remains_flying',1,{private=true})
 end
 local function quantize(v)return math.floor(v*P.quantum+.5)end
 local function startFlight(fid,row)
  local m,dm,e,de,left,time=S.GetFeatureResources(fid)
  if m~=0 or dm~=0 or e~=0 or de~=0 or left~=1 or not finite(time)then S.DestroyFeature(fid);return false,'flight_definition_has_resources'end
  local dx,dz=row.x-row.throw.x,row.z-row.throw.z;local distance=math.sqrt(dx*dx+dz*dz)
  if distance<.01 then local a=(row.heading/65536)*2*math.pi;dx,dz=math.sin(a),math.cos(a)else dx,dz=dx/distance,dz/distance end
  local t={px=quantize(row.x),py=quantize(row.y+1),pz=quantize(row.z),vx=quantize(dx*P.horizontalSpeed),vy=quantize(P.upSpeed),vz=quantize(dz*P.horizontalSpeed),born=S.GetGameFrame(),last=S.GetGameFrame()}
  -- One real native feature with zero resources until physical contact. Native
  -- AddBuildPower is blocked during flight, including area/queued reclaim.
  publish(fid,row);R.features[fid]=row;R.flights[fid]=t
  S.SetFeatureMoveCtrl(fid,true,0,0,0,0,0,0);S.SetFeatureNoSelect(fid,true)
  S.SetFeaturePosition(fid,t.px/P.quantum,t.py/P.quantum,t.pz/P.quantum);flightPublish(fid,t);return true
 end
 function R.AllowFeatureBuildStep(builder,team,fid,featureDef,part)
  return R.flights[fid]==nil and(not R.piles or R.piles.AllowFeatureBuildStep(builder,team,fid,featureDef,part))
 end
 function R.Killed(id,def,team)
  local row=R.pending[id];R.pending[id]=nil
  if not row or row.def~=def or row.team~=team or not eligible(def)then return false,'missing_death_snapshot' end
  local key=identity(row);if R.entitlements[key]then return false,'generation_already_consumed'end
  -- Reserve before creating: FeatureCreated can run synchronously. Never retry
  -- a consumed death automatically, even if the native feature cannot be placed.
  R.entitlements[key]=true
  local fid=S.CreateFeature(M.Actors[row.actor].feature,row.x,row.y,row.z,row.heading,row.team)
  if not fid then return false,'native_feature_creation_failed'end
  if S.GetFeatureDefID(fid)~=featureDefs[row.actor] then S.DestroyFeature(fid);return false,'feature_identity_mismatch'end
  if row.throw then local ok,reason=startFlight(fid,row);if not ok then return false,reason end;return true,fid end
  local ok,reason=initialize(fid,row);if not ok then return false,reason end
  return true,fid
 end
 function R.FeatureLost(fid)if R.piles then R.piles.FeatureLost(fid)end;R.features[fid]=nil;R.flights[fid]=nil end
 function R.Restore()
  for _,fid in ipairs(S.GetAllFeatures()or{})do
   if not(R.piles and R.piles.RestoreFeature(fid))then
   local actor=actorsByFeature[S.GetFeatureDefID(fid)]
   if actor and S.GetFeatureRulesParam(fid,'40k_remains_version')==M.Version then
    local row={actor=actor};for _,k in ipairs({'squad','slot','generation','metal','energy','work','team','def'})do row[k]=S.GetFeatureRulesParam(fid,'40k_remains_'..k)end
    if not integer(row.squad)or not integer(row.slot)or not integer(row.generation)or not finite(row.metal)or row.energy~=0 or not finite(row.work)then return false,'invalid_saved_remains'end
    local m,dm,e,de,left,time=S.GetFeatureResources(fid)
    local flying=S.GetFeatureRulesParam(fid,'40k_remains_flying')==1
    if flying then
     if not throwing or m~=0 or dm~=0 or e~=0 or de~=0 or left~=1 or not finite(time)then return false,'invalid_saved_flight_resources'end
     local t={};for _,k in ipairs(flightKeys)do t[k]=S.GetFeatureRulesParam(fid,'40k_remains_flight_'..k);if not signed(t[k])or t[k]%1~=0 then return false,'invalid_saved_flight'end end
     if t.born<0 or t.last<t.born or t.last>S.GetGameFrame()or t.last-t.born>P.maxFrames then return false,'invalid_saved_flight_age'end
     if t.px<0 or t.pz<0 or t.px>quantize(mapX)or t.pz>quantize(mapZ)or math.abs(t.vx)>quantize(P.horizontalSpeed)+1 or math.abs(t.vz)>quantize(P.horizontalSpeed)+1
      or t.vy>quantize(P.upSpeed)or t.vy<quantize(P.upSpeed)-P.maxFrames*quantize(P.gravity)then return false,'invalid_saved_flight_bounds'end
     local x,y,z=S.GetFeaturePosition(fid);if not signed(x)or not signed(y)or not signed(z)or math.abs(x-t.px/P.quantum)>.01 or math.abs(y-t.py/P.quantum)>.01 or math.abs(z-t.pz/P.quantum)>.01 then return false,'saved_flight_position_differs'end
     R.flights[fid]=t;S.SetFeatureMoveCtrl(fid,true,0,0,0,0,0,0);S.SetFeatureNoSelect(fid,true)
    elseif not finite(m)or not finite(dm)or math.abs(dm-row.metal)>.001 or m>dm+.001 or e~=0 or de~=0 or not finite(left)or left>1 or not finite(time)or math.abs(time-row.work)>.001 then return false,'invalid_saved_native_resources'end
    local key=identity(row);if R.entitlements[key]then return false,'duplicate_saved_entitlement'end
    R.entitlements[key]=true;R.features[fid]=row;if R.piles then R.piles.Observe(fid)end
   end
   end
  end
  return true
 end
 local function contact(fid,x,y,z)
  local ground=S.GetGroundHeight(x,z);if not signed(ground)then return nil end
  if y<=ground then return ground,ground-y>P.bodyRadius and'obstacle'or nil end
  local nearby=S.GetFeaturesInCylinder(x,z,P.bodyRadius)or{};table.sort(nearby)
  for _,other in ipairs(nearby)do if other~=fid and S.GetFeatureBlocking(other)then
   local ox,oy,oz=S.GetFeaturePosition(other);local height=S.GetFeatureHeight(other);local radius=S.GetFeatureRadius(other)
   if signed(ox)and signed(oy)and signed(oz)and finite(height)and finite(radius)and(ox-x)^2+(oz-z)^2<=(radius+P.bodyRadius)^2 and y>=oy-P.bodyRadius and y<=oy+height then return ground,'obstacle' end
  end end
  local units=S.GetUnitsInCylinder(x,z,P.bodyRadius)or{};table.sort(units)
  for _,other in ipairs(units)do if not S.GetUnitIsDead(other)and S.GetUnitBlocking(other)then
   local ox,oy,oz=S.GetUnitPosition(other);local height=S.GetUnitHeight(other);local radius=S.GetUnitRadius(other)
   if signed(ox)and signed(oy)and signed(oz)and finite(height)and finite(radius)and(ox-x)^2+(oz-z)^2<=(radius+P.bodyRadius)^2 and y>=oy-P.bodyRadius and y<=oy+height then return ground,'obstacle' end
  end end
 end
 local function land(fid,row,t,y)
  S.SetFeaturePosition(fid,t.px/P.quantum,y,t.pz/P.quantum)
  S.SetFeatureMoveCtrl(fid,false,0,0,0,0,0,0,0,0,0);S.SetFeatureNoSelect(fid,false)
  S.SetFeatureRulesParam(fid,'40k_remains_flying',0,{private=true});R.flights[fid]=nil
  return initialize(fid,row)
 end
 function R.Frame(frame)
  -- No lifetime deletion: native reclaim or explicit consumers remove salvage.
  -- Unfinished/reclaimed units skip Killed. Drop only their short-lived snapshot.
  for id,row in pairs(R.pending)do if frame>row.frame+1 then R.pending[id]=nil end end
  for id,row in pairs(R.damage)do if frame>row.frame then R.damage[id]=nil end end
  for id,row in pairs(R.blasts)do if frame>row.frame then R.blasts[id]=nil end end
  local ids={};for fid in pairs(R.flights)do ids[#ids+1]=fid end;table.sort(ids)
  for _,fid in ipairs(ids)do
   local t,row=R.flights[fid],R.features[fid]
   if S.GetFeatureDefID(fid)~=featureDefs[row.actor]then R.FeatureLost(fid)else
    for step=t.last+1,math.min(frame,t.born+P.maxFrames)do
     local nx,ny,nz=t.px+t.vx,t.py+t.vy,t.pz+t.vz
     if nx<0 or nz<0 or nx>quantize(mapX)or nz>quantize(mapZ)then nx,nz=t.px,t.pz;t.vx,t.vz=0,0 end
     local length=math.max(math.abs(t.vx),math.abs(t.vy),math.abs(t.vz))/P.quantum;local samples=math.max(1,math.ceil(length/P.sweepStep));local hit
     for n=1,samples do local fraction=n/samples;local x=(t.px+(nx-t.px)*fraction)/P.quantum;local y=(t.py+(ny-t.py)*fraction)/P.quantum;local z=(t.pz+(nz-t.pz)*fraction)/P.quantum
      local ground,kind=contact(fid,x,y,z);if ground then
       if kind=='obstacle'then nx,nz=t.px,t.pz;t.vx,t.vz=0,0 else nx,nz=quantize(x),quantize(z);hit=ground end;break
      end
     end
     t.px,t.py,t.pz,t.last=nx,ny,nz,step;t.vy=t.vy-quantize(P.gravity)
     if hit or step==t.born+P.maxFrames then land(fid,row,t,hit or S.GetGroundHeight(nx/P.quantum,nz/P.quantum));break end
     S.SetFeaturePosition(fid,nx/P.quantum,ny/P.quantum,nz/P.quantum);flightPublish(fid,t)
    end
   end
  end
  if R.piles then R.piles.Frame(frame)end
 end
 return R
end
return M
