function gadget:GetInfo()return{name='40K targeted generator geometry and paid neighbor',desc='Default-off bounded native geometry/selection plus separate ordinary construction',author='Local project',layer=153,enabled=true}end
local M=VFS.Include('40k_configs/generator_native_fixture.lua');local o=Spring.GetModOptions()or{}
if not M.Enabled(o)then return false end
local contract=M.SelectContract(VFS.Include('40k_configs/generator_native_contract.lua'),o)
local function emit(s)Spring.Echo('40K_GENERATOR_NATIVE '..s)end
if not gadgetHandler:IsSyncedCode()then
 local closeAt
 local function near(a,b)return type(a)=='number'and a==a and type(b)=='number'and b==b and math.abs(a-b)<=.002 end
 local function selection(_,id,key)
  local r=contract.rows[key];local v=type(Spring.GetUnitSelectionVolumeData)=='function'and{Spring.GetUnitSelectionVolumeData(id)}or{}
  if not r or #v~=10 or v[10]~=false or Spring.GetUnitNoSelect(id)~=false then emit('FAIL native_selection_volume_unreadable_or_disabled_'..tostring(key));return end
  if v[7]~=r.selection.nativeType then emit('FAIL native_selection_type_'..key);return end
  if r.selection.nativeAxis and v[9]~=r.selection.nativeAxis then emit('FAIL native_selection_axis_'..key);return end
  for a=1,3 do if not near(v[a],r.selection.scales[a])or not near(v[a+3],r.selection.offsets[a])then emit('FAIL native_selection_scale_offset_'..key);return end end
  local t={};for i=1,6 do t[i]=string.format('%.17g',v[i])end
  emit('SELECTION key='..key..' unit='..id..' volume='..table.concat(t,',')..' type='..v[7]..' noselect=false ignore_hits=false actual_native_unsynced=true mouse_click_accepted=false')
 end
 local function done(_,result)emit('owned_autoclose '..tostring(result));closeAt=Spring.GetGameFrame()+M.CloseHold(o.prototype_generator_native_mode)end
 function gadget:Initialize()gadgetHandler:AddSyncAction('fortyk_generator_selection',selection);gadgetHandler:AddSyncAction('fortyk_generator_done',done)end
 function gadget:GameFrame(f)if closeAt and f>=closeAt then closeAt=nil;Spring.SendCommands('quitforce')end end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction('fortyk_generator_selection');gadgetHandler:RemoveSyncAction('fortyk_generator_done')end
 return
end
local test,closed,pendingFinish,frameReady
local function finish(why)
 if closed then return end
 -- Initialize can precede unsynced sync-action registration. Deliver once on GameFrame.
 if not frameReady then pendingFinish=pendingFinish or why;return end
 closed=true;if test then test.Close()end
 emit('COMPLETE '..why..' mode='..tostring(o.prototype_generator_native_mode)..' visual_accepted=false exact_debit_accepted=false economy_accepted=false')
 SendToUnsynced('fortyk_generator_done',why)
end
function gadget:Initialize()
 local yes=function(v)return v==true or v==1 or v=='1'end
 if o.prototype_diagnostic~='normal'or tostring(o.prototype_test_speed)~='1'or not yes(o.prototype_development_playtest)or not yes(o.prototype_source_progression)then finish('FAIL explicit_normal_source_native_speed_required');return end
 if type(contract.fixtureGuardKeys)~='table'or #contract.fixtureGuardKeys==0 then finish('FAIL explicit_diagnostic_guards_required');return end
 for _,k in ipairs(contract.fixtureGuardKeys)do if k~=M.Option and yes(o[k])then finish('FAIL competing_diagnostic_'..k);return end end
 test=M.New(Spring,UnitDefs,UnitDefNames,FeatureDefs,GG,Game,CMD,o,contract,
  VFS.Include('40k_configs/ordinary_paid_construction_site.lua'),VFS.Include('40k_configs/guard_factory_egress_geometry.lua'),emit,
  function(id,key)SendToUnsynced('fortyk_generator_selection',id,key)end)
 if test.result then finish(test.result)end
end
function gadget:GameFrame(f)
 frameReady=true
 if pendingFinish then local why=pendingFinish;pendingFinish=nil;finish(why);return end
 if not closed then local result=test.Step(f);if result then finish(result)end end
end
function gadget:UnitCreated(...)if test and not test.result and not closed then test.Created(...)end end
function gadget:UnitFinished(...)if test and not test.result and not closed then test.Finished(...)end end
function gadget:Shutdown()if test then test.Close()end end
