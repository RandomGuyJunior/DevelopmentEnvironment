function gadget:GetInfo()return{name='40K opt-in runtime ground-fire review',desc='Actual core Marine commands and native projectile evidence',author='Local project',layer=120,enabled=true}end
if not gadgetHandler:IsSyncedCode()then return false end
local opts=Spring.GetModOptions()or{}
if opts.prototype_diagnostic~='six'or tostring(opts.prototype_runtime_library_review)~='1'then return false end
local observer=VFS.Include('40k_configs/40k_ground_lof_observer.lua')
local actor,weapon,shots=nil,nil,0
local function log(...)Spring.Echo('40K RUNTIME GROUND FIRE',...)end
function gadget:GameFrame(f)
 if f==1290 then
  for _,id in ipairs(Spring.GetTeamUnits(0))do
   local d=UnitDefs[Spring.GetUnitDefID(id)]
   if d.name=='imp_marine'and Spring.GetUnitRulesParam(id,'40k_diagnostic_slot')==2 then actor=id;weapon=d.weapons[1].weaponDef;Script.SetWatchProjectile(weapon,true);break end
  end
 end
 if f==1300 and actor then
  local x,y,z=Spring.GetUnitPosition(actor);local tx,tz=x+160,z-80
  Spring.GiveOrderToUnit(actor,CMD.STOP,{},{});Spring.GiveOrderToUnit(actor,CMD.ATTACK,{tx,Spring.GetGroundHeight(tx,tz),tz},{})
  log('ORDINARY_CORE_GROUND_ORDER',actor,f,tx,tz,'unpaid_diagnostic_actor')
 end
 if actor and f>=1330 and f<=2390 and f%300==130 then
  local env=Spring.UnitScript.GetScriptEnv(actor);local pivot
  if env and env.script and env.script.AimFromWeapon then pivot=Spring.UnitScript.CallAsUnit(actor,env.script.AimFromWeapon,1)end
  local r,why=observer.Snapshot(Spring,UnitDefs,WeaponDefs,Game,actor,1,{enabled=true,pivotPiece=pivot,attackCommand=CMD.ATTACK,maxSamples=64,maxObjects=64})
  log('READONLY_GROUND_LOF',actor,f,why or 'snapshot',r and tostring(r.muzzle_native_lof)or 'missing',r and tostring(r.pivot_native_lof)or 'missing',pivot or 'missing','cause_unavailable')
 end
 if f==2400 then log(shots>0 and 'LIMITED_CORE_GROUND_PROJECTILE'or 'GROUND_UNACCEPTED',actor or 'missing',shots,'paid_production_visual_collision_unaccepted')end
end
function gadget:ProjectileCreated(projectile,owner,w)
 if owner~=actor or w~=weapon or Spring.GetGameFrame()<1300 then return end
 local frame=Spring.GetGameFrame();local targetType=Spring.GetUnitWeaponTarget(actor,1)
 local shot=Spring.GetUnitRulesParam(actor,'40k_last_shot_1')
 local x,y,z=Spring.GetProjectilePosition(projectile)
 local fx=Spring.GetUnitRulesParam(actor,'40k_last_flash_x_1');local fy=Spring.GetUnitRulesParam(actor,'40k_last_flash_y_1');local fz=Spring.GetUnitRulesParam(actor,'40k_last_flash_z_1')
 if targetType~=2 or shot~=frame or not x or not y or not z or not fx or not fy or not fz then log('UNVERIFIED_PROJECTILE',projectile,owner,w,frame,targetType or 'missing',shot or 'missing');return end
 local delta=math.sqrt((x-fx)^2+(y-fy)^2+(z-fz)^2)
 if delta>.01 then log('ORIGIN_MISMATCH',delta);return end
 shots=shots+1;log('ACTUAL_NATIVE_GROUND_PROJECTILE',projectile,owner,w,frame,'same_frame_flash_distance',delta)
end
