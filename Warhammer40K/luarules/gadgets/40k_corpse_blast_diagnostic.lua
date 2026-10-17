-- Default-off, free diagnostic fixture: NOT paid economy or firing-animation proof.
function gadget:GetInfo()return {name='40K native corpse blast diagnostic',desc='Bounded native projectile and one-entitlement flight evidence',author='Local project',layer=120,enabled=true}end
local o=Spring.GetModOptions()or{}
local on=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
if not on(o.prototype_corpse_blast_fixture) or o.prototype_diagnostic~='normal' or not on(o.prototype_source_progression) or tonumber(o.prototype_test_speed or 1)~=1 then return false end
if not gadgetHandler:IsSyncedCode()then
 local original,site,captures,stage,closeAt
 local function camera(_,label,x,y,z)
  if label=='done'then closeAt=Spring.GetGameFrame()+90;return end
  if not original then original=Spring.GetCameraState()end
  site={x,y,z};Spring.SetCameraState({name='ta',mode=1,px=x,py=y,pz=z,height=160,angle=.9,flipped=-1},0)
  stage=label
 end
 function gadget:Initialize()captures={};gadgetHandler:AddSyncAction('40k_corpse_blast_camera',camera)end
 function gadget:GameFrame(frame)if closeAt and frame>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:DrawScreen()
  if site and stage and stage~='setup'and not captures[stage]then captures[stage]=true;Spring.SendCommands('screenshot png');local c=Spring.GetCameraState();Spring.Echo('40K CORPSE BLAST PNG',stage,Spring.GetGameFrame(),c.name,c.px,c.py,c.pz,'native_los',Spring.IsPosInLos(site[1],site[2],site[3]))end
 end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('40k_corpse_blast_camera');if original then Spring.SetCameraState(original,0)end end
 return
end
local target,observer,def,team,weapon,projectile,start,site,fid,lethal,blast,air,land,done
local reclaim=on(o.prototype_corpse_native_reclaim_fixture)
local handedOff
local function log(label,...)Spring.Echo('40K CORPSE BLAST',Spring.GetGameFrame(),label,...)end
local function finish(reason)
 if done then return end;done=true;Spring.SetGameRulesParam('40k_corpse_blast_result',reason=='complete'and 1 or -1)
 log('END',reason,'feature',fid or -1,'paid',false,'ordinary',false,'animation_proof',false)
 SendToUnsynced('40k_corpse_blast_camera','done',0,0,0)
 -- Keep the owned landed feature for screenshot/reclaim inspection. No user actors destroyed.
end
function gadget:Initialize()
 local actor=UnitDefNames.imp_devastator;local russ=UnitDefNames.imp_russ;local eye=UnitDefNames.smcom
 if not actor or not russ or not eye then finish('definitions_missing');return end
 def=actor.id;local mount=UnitDefs[russ.id].weapons and UnitDefs[russ.id].weapons[1];weapon=mount and mount.weaponDef
 local w=weapon and WeaponDefs[weapon]
 if not w or w.type~='Cannon'or(w.damageAreaOfEffect or 0)<16 or w.noExplode then finish('genuine_battle_cannon_missing');return end
 for _,t in ipairs(Spring.GetTeamList())do if t~=Spring.GetGaiaTeamID()then team=t;break end end
 if not team then finish('team_missing');return end
 for z=600,Game.mapSizeZ-600,256 do for x=600,Game.mapSizeX-600,256 do
  local y=Spring.GetGroundHeight(x,z)
  if y>0 and math.abs(Spring.GetGroundHeight(x-40,z)-y)<1 and math.abs(Spring.GetGroundHeight(x+80,z)-y)<1 and #Spring.GetFeaturesInCylinder(x,z,240)==0 and #Spring.GetUnitsInCylinder(x,z,240)==0 and Spring.TestMoveOrder(def,x,y,z)then site={x,y,z};break end
 end;if site then break end end
 if not site then finish('clear_dry_site_missing');return end
 -- A genuine unpaid fixture observer retains ordinary native LOS after the
 -- casualty dies. Do not override LOS or infer visibility from feature data.
 observer=Spring.CreateUnit('smcom',site[1]+80,site[2],site[3],0,team)
 if not observer or Spring.GetUnitDefID(observer)~=eye.id then finish('genuine_observer_missing');return end
 Spring.GiveOrderToUnit(observer,CMD.FIRE_STATE,{0},{});Spring.GiveOrderToUnit(observer,CMD.MOVE_STATE,{0},{})
 target=Spring.CreateUnit('imp_devastator',site[1],site[2],site[3],0,team)
 if not target or Spring.GetUnitDefID(target)~=def or Spring.GetUnitTeam(target)~=team or Spring.GetUnitRulesParam(target,'40k_squad_id')then finish('standalone_fixture_refused');return end
 Spring.GiveOrderToUnit(target,CMD.FIRE_STATE,{0},{});Spring.GiveOrderToUnit(target,CMD.MOVE_STATE,{0},{})
 -- Explicit wound is setup only; lethal damage MUST come from native projectile explosion.
 Spring.SetUnitHealth(target,{health=1});Script.SetWatchExplosion(weapon,true)
 start=Spring.GetGameFrame();SendToUnsynced('40k_corpse_blast_camera','setup',unpack(site))
 local work,m,e=Spring.GetUnitCosts(target);log('SETUP',target,def,team,weapon,w.name,w.type,w.damageAreaOfEffect,work,m,e,unpack(site))
end
function gadget:Explosion(w,x,y,z,owner,p)
 if not done and projectile and p==projectile and w==weapon then blast=Spring.GetGameFrame();log('NATIVE_EXPLOSION',p,w,x,y,z,owner or -1)end
 return false
end
function gadget:UnitDamaged(id,d,t,damage,paralyzer,w,p)
 if done or id~=target or w~=weapon or p~=projectile then return end
 local hp=Spring.GetUnitHealth(id);log('NATIVE_DAMAGE',id,p,w,damage,paralyzer,hp or 999)
 if damage>0 and not paralyzer and hp and hp<=0 and blast==Spring.GetGameFrame()then lethal=true end
end
function gadget:GameFrame(f)
 if done or not start then return end
 if f-start==1 then SendToUnsynced('40k_corpse_blast_camera','setup',unpack(site))end
 if f-start==45 then
  projectile=Spring.SpawnProjectile(weapon,{pos={site[1]-7,site[2]+35,site[3]},speed={0,-2,0},['end']={site[1]-7,site[2],site[3]},team=Spring.GetGaiaTeamID(),ttl=120,gravity=0})
  if not projectile or projectile<0 then finish('native_projectile_refused');return end
  log('NATIVE_SPAWN',projectile,weapon);SendToUnsynced('40k_corpse_blast_camera','projectile',unpack(site))
 end
 if lethal then
  if reclaim and land then
   local claimed=Spring.GetGameRulesParam('40k_corpse_native_reclaim_feature')
   local ordered=Spring.GetGameRulesParam('40k_corpse_native_reclaim_ordered')
   if claimed and (claimed~=fid or not ordered or ordered<land)then finish('native_reclaim_identity_mismatch');return end
   if claimed==fid and ordered and ordered>=land then handedOff=true end
  end
  local matches={}
  for _,id in ipairs(Spring.GetFeaturesInCylinder(site[1],site[3],240))do
   local fd=FeatureDefs[Spring.GetFeatureDefID(id)];local cp=fd and fd.customParams
   if cp and cp.prototype40k_tactical_remains and cp.parent_actor=='imp_devastator' and Spring.GetFeatureRulesParam(id,'40k_remains_slot')==target and Spring.GetFeatureRulesParam(id,'40k_remains_def')==def then matches[#matches+1]=id end
  end
  if #matches>1 then finish('duplicate_entitlement');return end
  if #matches==1 then
   if fid and fid~=matches[1]then finish('feature_identity_changed');return end;fid=matches[1]
   local m,mm,e,me,left,work=Spring.GetFeatureResources(fid);local x,y,z=Spring.GetFeaturePosition(fid);local phase=Spring.GetFeatureRulesParam(fid,'40k_remains_flying')
   log('FEATURE',fid,phase,m,mm,e,me,left,work,x,y,z)
   if phase==1 then
    if m~=0 or mm~=0 or e~=0 or me~=0 then finish('airborne_currency');return end
    if not air then air=f;SendToUnsynced('40k_corpse_blast_camera','airborne',x,y,z)end
   elseif phase==0 and air and not handedOff then
    local cap=Spring.GetFeatureRulesParam(fid,'40k_remains_metal')
    if not cap or cap<=0 or m~=cap or e~=0 or math.abs(y-Spring.GetGroundHeight(x,z))>.02 then finish('landing_currency_or_ground');return end
    if not land then land=f;log('LANDED',fid,m,e,work,x,y,z);SendToUnsynced('40k_corpse_blast_camera','landed',x,y,z)end
    if not reclaim and f-land>=30 then finish('complete')end
   end
  end
  if reclaim and land then
   if #matches==0 and not handedOff then finish('feature_missing_before_native_reclaim');return end
   local result=Spring.GetGameRulesParam('40k_corpse_native_reclaim_result')
   if result==-1 then finish('native_reclaim_failed');return end
   if result==1 then
    if not handedOff or #matches~=0 then finish('native_reclaim_incomplete_identity');return end
    finish('complete');return
   end
  end
 end
 if f-start>=(reclaim and 510 or 300)then finish('bounded_timeout')end
end
