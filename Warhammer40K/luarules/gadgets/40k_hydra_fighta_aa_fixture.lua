function gadget:GetInfo()return{name='40K funded Hydra versus genuine Fighta AA fixture',desc='Default-off funded non-economy native flight and autocannon health-loss witnesses',author='Local project',layer=158,enabled=true}end
local options=Spring.GetModOptions()or{}
local function enabled(v)return v==true or v==1 or v=='1'end
if not enabled(options.prototype_hydra_fighta_aa_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function done(_,reason)Spring.Echo('40K_HYDRA_FIGHTA_AA owned_fixture_autoclose '..tostring(reason));closeAt=Spring.GetGameFrame()+90 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_hydra_fighta_aa_done',done)end
 function gadget:GameFrame(f)if closeAt and f>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_hydra_fighta_aa_done')end
 return
end
local C;local stopped=false
local function emit(event,...)local t={...};for i=1,#t do t[i]=tostring(t[i])end;Spring.Echo('40K_HYDRA_FIGHTA_AA '..event..' '..table.concat(t,' '))end
local function finish(r)if stopped then return end;stopped=true;emit('COMPLETE',r,'all_setup_funded_non_economy=true');SendToUnsynced('fortyk_hydra_fighta_aa_done',r)end
function gadget:GameFrame(f)
 if stopped then return end
 if not C then
  for k,v in pairs(options)do if k:match('^prototype_.*fixture$')and k~='prototype_hydra_fighta_aa_fixture'and enabled(v)then finish('FAIL conflicting_fixture');return end end
  local enemy;for _,t in ipairs(Spring.GetTeamList())do if t~=Spring.GetGaiaTeamID()and not Spring.AreTeamsAllied(0,t)then enemy=t;break end end
  if not enemy then finish('INCONCLUSIVE inactive_hostile_team_required');return end
  C=VFS.Include('40k_configs/hydra_fighta_native_aa_fixture.lua').New(Spring,UnitDefs,WeaponDefs,0,enemy,f,emit)
  if C.entries then for wd in pairs(C.entries)do Script.SetWatchWeapon(wd,true)end end
 end
 local r=C.Step and C.Step(f)or C.result;if r then finish(r)end
end
function gadget:ProjectileCreated(pid,owner,weapon)if C and not stopped and C.Projectile then C.Projectile(pid,owner,weapon)end end
function gadget:UnitDamaged(id,def,team,damage,para,weapon,pid,attacker)if C and not stopped and C.Damaged then C.Damaged(id,damage,para,weapon,pid,attacker)end end
function gadget:UnitDestroyed(id,def,team,attacker)if C and not stopped and C.UnitDestroyed then C.UnitDestroyed(id,attacker)end end
