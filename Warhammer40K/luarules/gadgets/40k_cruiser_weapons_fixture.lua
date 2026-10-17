function gadget:GetInfo()return{name='40K funded native cruiser weapons fixture',desc='Default-off funded non-economy three native weapon roles',author='Local project',layer=158,enabled=true}end
local options=Spring.GetModOptions()or{}
local function enabled(v)return v==true or v==1 or v=='1'end
if not enabled(options.prototype_cruiser_weapons_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function done(_,reason)Spring.Echo('40K_CRUISER_WEAPONS owned_fixture_autoclose '..tostring(reason));closeAt=Spring.GetGameFrame()+90 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_cruiser_weapons_done',done)end
 function gadget:GameFrame(f)if closeAt and f>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_cruiser_weapons_done')end
 return
end
local C;local stopped=false
local function emit(event,...)local t={...};for i=1,#t do t[i]=tostring(t[i])end;Spring.Echo('40K_CRUISER_WEAPONS '..event..' '..table.concat(t,' '))end
local function finish(result)if stopped then return end;stopped=true;emit('COMPLETE',result,'all_setup_and_weapon_energy_funded_non_economy=true paid_production_unaccepted=true');SendToUnsynced('fortyk_cruiser_weapons_done',result)end
function gadget:GameFrame(f)
 if stopped then return end
 if not C then
  for k,v in pairs(options)do if k:match('^prototype_.*fixture$')and k~='prototype_cruiser_weapons_fixture'and enabled(v)then finish('FAIL conflicting_fixture');return end end
  local enemy;for _,t in ipairs(Spring.GetTeamList())do if t~=Spring.GetGaiaTeamID()and not Spring.AreTeamsAllied(0,t)then enemy=t;break end end
  if not enemy then finish('INCONCLUSIVE inactive_hostile_team_required');return end
  C=VFS.Include('40k_configs/cruiser_native_weapons_fixture.lua').New(Spring,UnitDefs,WeaponDefs,0,enemy,f,emit)
  if C.entries then for wd in pairs(C.entries)do Script.SetWatchWeapon(wd,true)end end
 end
 -- Deliberately funded native energy firing diagnostics; never economy proof.
 if f%30==0 then Spring.AddTeamResource(0,'energy',10000);emit('FUNDED_WEAPON_ENERGY',10000,'non_economy=true')end
 local result=C.Step and C.Step(f)or C.result;if result then finish(result)end
end
function gadget:ProjectileCreated(pid,owner,weapon)if C and not stopped and C.Projectile then C.Projectile(pid,owner,weapon)end end
function gadget:UnitDamaged(id,def,team,damage,para,weapon,pid,attacker)if C and not stopped and C.Damaged then C.Damaged(id,damage,para,weapon,pid,attacker)end end
function gadget:UnitDestroyed(id,def,team,attacker)if C and not stopped and C.UnitDestroyed then C.UnitDestroyed(id,attacker)end end
