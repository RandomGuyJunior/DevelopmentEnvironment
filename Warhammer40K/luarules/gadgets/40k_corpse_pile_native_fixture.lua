function gadget:GetInfo()return{name='40K isolated native pile conservation',desc='Default-off synthetic M/E seeds, existing owner/native reclaim and projectile passage',author='Local project',layer=152,enabled=true}end
local M=VFS.Include('40k_configs/corpse_pile_native_fixture.lua');local options=Spring.GetModOptions()or{}
if not M.Enabled(options)then return false end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function done(_,result)Spring.Echo('40K_PILE_NATIVE owned_autoclose '..tostring(result));closeAt=Spring.GetGameFrame()+90 end
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_pile_native_done',done)end
 function gadget:GameFrame(f)if closeAt and f>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_pile_native_done')end
 return
end
local test,closed;local function emit(s)Spring.Echo('40K_PILE_NATIVE '..s)end
local function finish(why)if closed then return end;closed=true;if test then test.Close()end;emit('COMPLETE '..why..' synthetic_seed_only=true paid_death=false economy_acceptance=false');SendToUnsynced('fortyk_pile_native_done',why)end
function gadget:Initialize()
 local yes=function(v)return v==true or v==1 or v=='1'end
 if options.prototype_diagnostic~='normal'or not yes(options.prototype_development_playtest)or not yes(options.prototype_source_progression)
  or tostring(options.prototype_test_speed)~='1'or yes(options.prototype_scale085_pilot)then finish('FAIL explicit_native_speed_normal_diagnostic_required');return end
 for k,v in pairs(options)do if yes(v)and(k:match('fixture$')or k:match('driver$'))and k~=M.Option then finish('FAIL competing_diagnostic_'..k);return end end
end
function gadget:GameFrame(f)
 if closed then return end
 if not test then
  if f<30 then return end;test=M.New(Spring,UnitDefs,UnitDefNames,FeatureDefs,WeaponDefs,GG,Game,CMD,emit)
  if test.result then finish(test.result);return end
  if test.weapon then Script.SetWatchExplosion(test.weapon,true)end
 end
 local result=test.Step(f);if result then finish(result)end
end
function gadget:AllowFeatureBuildStep(...)if test then test.BuildStep(...)end;return true end
function gadget:FeatureDestroyed(fid)if test then test.FeatureDestroyed(fid)end end
function gadget:Explosion(...)if test then return test.Explosion(...)end;return false end
function gadget:Shutdown()if test then test.Close()end end
