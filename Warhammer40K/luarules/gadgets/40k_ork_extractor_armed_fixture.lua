function gadget:GetInfo()return{name='40K FUNDED NON-ECONOMY Ork three-tier armed extractor fixture',desc='Default-off actual stock metal sites/native weapon damage; no paid lifecycle acceptance',author='Local project',layer=159,enabled=true}end
local options=Spring.GetModOptions()or{}
local function enabled(v)return v==true or v==1 or v=='1'end
if not enabled(options.prototype_ork_extractor_armed_fixture)then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function done(_,r)Spring.Echo('40K_ORK_EXTRACTOR_ARMED owned_autoclose '..tostring(r));closeAt=Spring.GetGameFrame()+90 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_ork_extractor_armed_done',done)end
 function gadget:GameFrame(f)if closeAt and f>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_ork_extractor_armed_done')end
 return
end
local C;local stopped=false
local function emit(event,...)local a={...};for i=1,#a do a[i]=tostring(a[i])end;Spring.Echo('40K_ORK_EXTRACTOR_ARMED '..event..' '..table.concat(a,' '))end
local function finish(r)if stopped then return end;stopped=true;if C then C.Close()end;emit('COMPLETE',r,'funded_non_economy=true paid_economy_accepted=false Query_Shot_accepted=false');SendToUnsynced('fortyk_ork_extractor_armed_done',r)end
function gadget:GameFrame(f)
 if stopped then return end
 local ok,result=pcall(function()
  if not C then
   for k,v in pairs(options)do if enabled(v)and k~='prototype_ork_extractor_armed_fixture'and(k:match('fixture$')or k:match('driver$')or k=='prototype_body_benchmark')then return'FAIL competing_fixture_or_driver'end end
   if not enabled(options.prototype_extractor_fixed_tier_pilot)then return'FAIL fixed_tier_pilot_required'end
   local enemy;for _,t in ipairs(Spring.GetTeamList())do if t~=Spring.GetGaiaTeamID()and not Spring.AreTeamsAllied(0,t)then enemy=t;break end end
   if not enemy then return'INCONCLUSIVE inactive_hostile_team_required'end
   -- Publish C before setup so failed creation has owned-ID cleanup.
   C=VFS.Include('40k_configs/ork_extractor_funded_setup.lua').New(Spring,UnitDefs,UnitDefNames,WeaponDefs,0,enemy,f,emit,
    VFS.Include('40k_configs/ork_extractor_fixture_contract.lua'),VFS.Include('40k_configs/ork_extractor_armed_observer.lua'),VFS.Include('40k_configs/guard_factory_egress_geometry.lua'),CMD,Script.SetWatchWeapon,GG.resource_spot_finder,Game)
  end
  return C.Step(f)
 end)
 if not ok then finish('FAIL '..tostring(result))elseif result then finish(result)end
end
function gadget:ProjectileCreated(pid,owner,weapon)if C and not stopped then C.Projectile(pid,owner,weapon)end end
function gadget:UnitDamaged(id,def,team,damage,para,weapon,pid,attacker)if C and not stopped then C.Damaged(id,damage,para,weapon,pid,attacker)end end
function gadget:Shutdown()if C then C.Close()end end
