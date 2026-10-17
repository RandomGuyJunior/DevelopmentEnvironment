function gadget:GetInfo()return{name='40K ordinary paid Ork aircraft ladder',desc='Default-off actual six-stage earned-resource Gunship ladder; test availability only',author='Local project',layer=158,enabled=true}end
local options=Spring.GetModOptions()or{}
local function yes(v)return v==true or v==1 or v=='1'end
if not yes(options.prototype_ork_paid_air_ladder_fixture)then return false end
local action='fortyk_ork_paid_air_ladder_done'
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 function gadget:Initialize()gadgetHandler:AddSyncAction(action,function(_,reason)Spring.Echo('40K_ORK_AIR_LADDER owned_fixture_autoclose '..reason);closeAt=Spring.GetGameFrame()+90 end)end
 function gadget:GameFrame(f)if closeAt and f>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction(action)end
 return
end
local controller,terminal,module,geometry,exclusions
local function log(event,...)local a={...};for i,v in ipairs(a)do a[i]=tostring(v)end;Spring.Echo('40K_ORK_AIR_LADDER '..event..' '..table.concat(a,' '))end
function gadget:Initialize()
 module=VFS.Include('40k_configs/ork_paid_gunship_ladder.lua')
 geometry=VFS.Include('40k_configs/guard_factory_egress_geometry.lua')
 exclusions=VFS.Include('40k_configs/formation_native_exclusions.lua')
end
function gadget:GameFrame(f)
 if terminal or f<1 then return end
 -- Native GameFrame(0) precedes the exact fresh-frame1 admission snapshot.
 -- A skipped frame1 still reaches the unchanged controller guard and refuses.
 if not controller then controller=module.New(Spring,UnitDefs,UnitDefNames,GG,Game,CMD,options,geometry,exclusions,log)end
 local result=controller.Step(f);if result then terminal=result;log('COMPLETE',result,'resource_grants=false test_availability=true normal_default_access_accepted=false combat_accepted=false native_acceptance_requires_exact_bound_reader=true');controller.Close();SendToUnsynced(action,result)end end
function gadget:UnitCreated(...)if controller then controller.Created(...)end end
function gadget:UnitFinished(...)if controller then controller.Finished(...)end end
function gadget:UnitFromFactory(...)if controller then controller.Released(...)end end
function gadget:Shutdown()if controller then controller.Close()end end
