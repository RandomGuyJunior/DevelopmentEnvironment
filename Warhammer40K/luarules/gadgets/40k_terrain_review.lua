function gadget:GetInfo()return {name='40K native terrain alignment review',desc='Isolated terrain function fixture; no rotation overrides',author='Local project',layer=108,enabled=true}end
if not gadgetHandler:IsSyncedCode() or Spring.GetModOptions().prototype_diagnostic~='terrainreview' then return end
local weapons=tostring(Spring.GetModOptions().prototype_terrain_weapons)=='1'
local names={'imp_russ','armstump','imp_guardsman'};if weapons then names[4]='imp_russ' end
local cursor,actor,origin,goal,start,restDone,movingDone=0,nil,nil,nil,0,false,false
local victim,shots,hits=nil,{},{}
function gadget:Initialize()
 if weapons then for _,w in ipairs(UnitDefNames.imp_russ and UnitDefs[UnitDefNames.imp_russ.id].weapons or {})do Script.SetWatchProjectile(w.weaponDef or w.weaponDefID,true)end end
end
function gadget:ProjectileCreated(projectile,owner,weapon)
 if cursor~=4 or owner~=actor then return end
 local mount
 for n,w in ipairs(UnitDefs[Spring.GetUnitDefID(actor)].weapons or {})do if (w.weaponDef or w.weaponDefID)==weapon then mount=n end end
 if not mount or (shots[mount] or 0)>=6 then return end
 local x,y,z=Spring.GetProjectilePosition(projectile);local mx,my,mz=Spring.GetUnitWeaponVectors(actor,mount)
 if not x or not mx then Spring.Echo('40K TERRAIN WEAPON','UNKNOWN','missing_native_muzzle',mount);return end
 local distance=math.sqrt((x-mx)^2+(y-my)^2+(z-mz)^2);shots[mount]=(shots[mount] or 0)+1
 Spring.Echo('40K TERRAIN WEAPON','PROJECTILE',mount,Spring.GetGameFrame(),'muzzle_distance',distance,'position',x,y,z)
end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,weapon,projectile,attacker)
 if cursor==4 and id==victim and attacker==actor then hits[weapon]=true;Spring.Echo('40K TERRAIN WEAPON','HIT',weapon,damage,Spring.GetGameFrame())end
end
local function log(...)Spring.Echo('40K TERRAIN REVIEW',...)end
local function finite(x)return type(x)=='number' and x==x and math.abs(x)<math.huge end
local function site(def)
 for z=256,Game.mapSizeZ-256,32 do for x=256,Game.mapSizeX-256,32 do
  local nx,ny,nz=Spring.GetGroundNormal(x,z);local y=Spring.GetGroundHeight(x,z)
  if finite(ny) and ny>.88 and ny<.975 and y>20 then
   local n=math.sqrt(nx*nx+nz*nz);local gx,gz=x+nx/n*100,z+nz/n*100;local gy=Spring.GetGroundHeight(gx,gz)
   local valid=true
   for i=0,10 do local px,pz=x+(gx-x)*i/10,z+(gz-z)*i/10;local py=Spring.GetGroundHeight(px,pz)
    if py<0 or not Spring.TestMoveOrder(def,px,py,pz,0,0,0,true,true,false) then valid=false;break end
   end
   if valid and #Spring.GetFeaturesInRectangle(x-100,z-100,x+100,z+100)==0 then return {x,y,z},{gx,gy,gz} end
  end
 end end
end
local function sample(label,f)
 local x,y,z=Spring.GetUnitPosition(actor);local front,up,right=Spring.GetUnitVectors(actor);local nx,ny,nz=Spring.GetGroundNormal(x,z)
 if not up or not finite(nx) then log('UNKNOWN','missing_native_vectors',cursor);return false end
 local vx,vy,vz=Spring.GetUnitVelocity(actor);local dot=up[1]*nx+up[2]*ny+up[3]*nz
 log('NATIVE_BASIS',names[cursor],actor,label,f,'upright',UnitDefs[Spring.GetUnitDefID(actor)].upright,'position',x,y,z,'up',unpack(up))
 log('GROUND_MATCH',names[cursor],actor,label,f,'normal',nx,ny,nz,'dot',dot,'vertical_dot',up[2],'velocity',vx,vy,vz)
 Spring.SetGameRulesParam('40k_terrain_actor',actor,{public=true});Spring.SetGameRulesParam('40k_terrain_phase',label,{public=true});Spring.SetGameRulesParam('40k_terrain_phase_frame',f,{public=true})
 return true
end
function gadget:GameFrame(f)
 if f<90 then return end
 if not actor then
  cursor=cursor+1;if cursor>#names then log('COMPLETE','actual_native_vectors_observed_no_alignment_acceptance_inferred',f);gadgetHandler:RemoveGadget(self);return end
  local ud=UnitDefNames[names[cursor]];if not ud then log('UNKNOWN','missing_definition',names[cursor]);return end
  origin,goal=site(ud.id);if not origin then log('UNKNOWN','no_real_passable_slope',names[cursor]);return end
  actor=Spring.CreateUnit(names[cursor],origin[1],origin[2],origin[3],cursor==4 and 2 or 0,0)
  if not actor then log('UNKNOWN','create_failed',names[cursor]);return end
  Spring.GiveOrderToUnit(actor,CMD.FIRE_STATE,{0},{});start=f;restDone=false;movingDone=false
  log('CREATED',names[cursor],actor,'ordinary_native_orientation_no_movectrl',unpack(origin));return
 end
 if not restDone and f-start>=90 then
  restDone=true;sample('rest',f)
  if cursor==4 then
   local tx,tz=origin[1],origin[3]-120
   victim=Spring.CreateUnit('armstump',tx,Spring.GetGroundHeight(tx,tz),tz,0,1)
   if victim then Spring.GiveOrderToUnit(victim,CMD.FIRE_STATE,{0},{});Spring.GiveOrderToUnit(victim,CMD.MOVE_STATE,{0},{});Spring.GiveOrderToUnit(actor,CMD.FIRE_STATE,{2},{});Spring.GiveOrderToUnit(actor,CMD.ATTACK,{victim},{})end
   start=f;return
  end
  Spring.GiveOrderToUnit(actor,CMD.MOVE,goal,{})
 end
 if cursor==4 then
  if restDone and f-start>=360 then
   for mount=1,4 do Spring.Echo('40K TERRAIN WEAPON','MOUNT_OBSERVED',mount,shots[mount] or 0)end
   local count=0;for _ in pairs(hits)do count=count+1 end;Spring.Echo('40K TERRAIN WEAPON','DISTINCT_DAMAGE_WEAPONS',count)
   if victim and Spring.ValidUnitID(victim)then Spring.DestroyUnit(victim,false,true)end
   Spring.DestroyUnit(actor,false,true);actor=nil
  end
  return
 end
 if restDone and not movingDone then
  local x,y,z=Spring.GetUnitPosition(actor);local vx,vy,vz=Spring.GetUnitVelocity(actor)
  local dist=math.sqrt((x-origin[1])^2+(z-origin[3])^2)
  if dist>12 and vx*vx+vz*vz>.0001 then movingDone=true;sample('moving',f);start=f
  elseif f-start>900 then movingDone=true;log('UNKNOWN','native_motion_timeout',names[cursor],dist);start=f end
 end
 if movingDone and f-start>=60 then Spring.DestroyUnit(actor,false,true);actor=nil end
end
