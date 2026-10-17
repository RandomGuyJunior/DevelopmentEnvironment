-- Default-off owned Heavy SSF hook; no resource/order/body/remains control.
function gadget:GetInfo()return{name='40K owned Heavy corpse save checkpoint',desc='Paused unique SSF seal and separate firsttick observer',author='Local project',layer=150,enabled=true}end
local o=Spring.GetModOptions()or{};local on=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
if not on(o.prototype_corpse_save_checkpoint_fixture)then return false end
if o.prototype_diagnostic~='normal'or not on(o.prototype_source_progression)or not on(o.prototype_corpse_blast_fixture)or on(o.prototype_corpse_native_reclaim_fixture)or on(o.prototype_marine_heavy_squad)or tonumber(o.prototype_test_speed or 1)~=1 then Spring.Echo('40K_CORPSE_SAVE REFUSED exact_owned_funded_Heavy_route_required');return false end
if not on(o.prototype_corpse_save_first_tick_fixture)then Spring.Echo('40K_CORPSE_SAVE REFUSED exact_native_boundary_unavailable_firsttick_optin_required');return false end
local name=o.prototype_corpse_save_checkpoint_name;local stamp,nonce
if type(name)=='string'then stamp,nonce=name:match('^40k%-owned%-corpse%-save%-(%d%d%d%d%d%d%d%dT%d%d%d%d%d%dZ)%-(%x+)$')end
local run=o.prototype_corpse_save_run_id
if not stamp or not nonce or #nonce~=12 or type(run)~='string'or #run~=32 or not run:match('^[0-9a-f]+$')then Spring.Echo('40K_CORPSE_SAVE REFUSED unique_name_and_fresh_run_id_required');return false end
local prefix='40k-corpse-save:'..run..':'..name..':'
local action='40k_corpse_save_checkpoint';local marker='40k_corpse_save_checkpoint_'
local function log(...)Spring.Echo('40K_CORPSE_SAVE',run,name,...)end
if not gadgetHandler:IsSyncedCode()then
 local latest,sealedFrame,requested,saved,sealRequested,at,failed,loadLogged
 local function report(_,kind,frame)
  if kind=='capture'then latest=frame elseif kind=='sealed'then sealedFrame=frame elseif kind=='refused'then failed=true;log('REFUSED synced_invariants',frame)end
 end
 local function player()
  local id=Spring.GetMyPlayerID();if id~=0 then return false end
  local n,active,spec,team=Spring.GetPlayerInfo(id,false);return n=='SquadDiagnostic'and spec==false and team==0,active
 end
 function gadget:Initialize()gadgetHandler:AddSyncAction(action,report)end
 function gadget:Update()
  if failed then return end
  local loaded,isSaved=Spring.GetGameState();if loaded==false then return end
  if loaded~=true or type(isSaved)~='boolean'then failed=true;log('REFUSED native_unsynced_game_state_unknown');return end
  local own,active=player();if not own then failed=true;log('REFUSED owned_player_zero_required');return end
  local frame=Spring.GetGameFrame();local captured=Spring.GetGameRulesParam(marker..'frame');local marked=Spring.GetGameRulesParam(marker..'marker')==1;local sameRun=Spring.GetGameRulesParam(marker..'run')==run
  if isSaved then
   if not marked or not sameRun or Spring.GetGameRulesParam(marker..'sealed')~=1 then failed=true;log('REFUSED native_saved_original_seal_required');return end
   if not loadLogged then loadLogged=true;log('FIRST_TICK_NATIVE_SAVED_GAME',captured,frame,'IsSavedGame=true exactCheckpointPassed=false nativeResumeAccepted=false')end
   return -- No resume message, unpause or second save from a saved run.
  end
  if active~=true then return end
  local _,_,paused=Spring.GetGameSpeed();if type(paused)~='boolean'then failed=true;log('REFUSED native_pause_readback_unknown');return end
  if marked and not latest then return end -- ordinary unsynced reload never starts another save
  if latest and not requested then requested=true;at=Spring.GetTimer();Spring.SendCommands('pause 1');log('PAUSE_REQUEST',latest)end
  if requested and not saved and Spring.DiffTimers(Spring.GetTimer(),at)>30 then failed=true;log('REFUSED pause_or_seal_timeout');return end
  if requested and not saved and paused and latest==frame and captured==frame and marked and sameRun then
   if not sealRequested then sealRequested=true;Spring.SendLuaRulesMsg(prefix..'seal:'..frame);log('SEAL_REQUEST',frame,'actual_native_pause_readback=true');return end
   if sealedFrame~=frame or Spring.GetGameRulesParam(marker..'sealed')~=1 then return end
   saved=true;Spring.SendCommands('save '..name);log('SAVE_COMMAND_SENT',frame,'ordinary_ssf_no_overwrite_envelope_readiness_external funded_non_economy=true');return
  end
 end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction(action)end
 return
end
local W=VFS.Include('40k_configs/corpse_save_witness.lua');local D=VFS.Include('40k_configs/squad_state_digest.lua');local Probe=VFS.Include('40k_configs/squad_first_tick_save_probe.lua')
local phase='waiting';local checkpoint,fid,probe,start,deadline;local interface
local function fail(reason)phase='failed';log('REFUSED',Spring.GetGameFrame(),reason,'exactCheckpointPassed=false nativeResumeAccepted=false paidEconomyAccepted=false');SendToUnsynced(action,'refused',Spring.GetGameFrame())end
local function read()return W.Capture(Spring,GG.Recoil40KTacticalRemains,UnitDefs,FeatureDefs,fid)end
function gadget:Initialize()
 assert(not GG.Recoil40KCorpseSaveCheckpoint,'Distinct Heavy checkpoint owner already present')
 if type(Spring.GetGameFrame)~='function'or Spring.GetGameFrame()~=0 then phase='failed';log('REFUSED fresh_native_initialize_zero_required');return end
 start=Spring.GetGameFrame();interface={Status=function()return phase end};GG.Recoil40KCorpseSaveCheckpoint=interface
end
function gadget:RecvLuaMsg(msg,player)
 if type(msg)~='string'or msg:sub(1,#prefix)~=prefix then return false end
 if player~=0 then fail('stale_or_unauthorised_original_seal');return true end
 local n=msg:sub(#prefix+1):match('^seal:(%d+)$');local frame=tonumber(n);local who,active,spec,team=Spring.GetPlayerInfo(player,false)
 if player~=0 or who~='SquadDiagnostic'or active~=true or spec~=false or team~=0 or phase~='checkpoint'or not checkpoint or probe or frame~=checkpoint.frame or Spring.GetGameFrame()~=frame or Spring.GetGameRulesParam(marker..'marker')~=1 or Spring.GetGameRulesParam(marker..'run')~=run then fail('stale_or_unauthorised_original_seal');return true end
 local ok,current=pcall(read);if not ok or current.phase~='airborne'or W.CompareExact(checkpoint,current).state~='EXACT_BYTES_MATCH_BOUNDARY_PROOF_PENDING'then fail('original_airborne_checkpoint_changed');return true end
 Spring.SetGameRulesParam(marker..'sealed',1);Spring.SetGameRulesParam(marker..'scheduled',1)
 probe=W.FirstTick(true,Probe,Script,Spring,checkpoint,function()
  local name0,_,spec0,team0=Spring.GetPlayerInfo(0,false)
  if phase~='checkpoint'or name0~='SquadDiagnostic'or spec0~=false or team0~=0 or Spring.GetGameRulesParam(marker..'sealed')~=1 or Spring.GetGameRulesParam(marker..'scheduled')~=1 or Spring.GetGameRulesParam(marker..'run')~=run or Spring.GetGameRulesParam(marker..'frame')~=checkpoint.frame then return nil,'serialized_original_Heavy_seal_missing'end
  local ok,state=pcall(read);if not ok then return nil,tostring(state)end;return state
 end,function(r)
  log('FIRST_TICK_STATE',r.restoredFrame,r.expectedFrame,r.observedFrame,r.status,r.reason or'none','exactCheckpointPassed=false nativeResumeAccepted=false paidEconomyAccepted=false')
  if r.status~='matched_first_tick_native_load_witness_required'then fail('first_tick_'..tostring(r.reason));return end
  phase='resumed';deadline=r.expectedFrame+180;Spring.SetGameRulesParam(marker..'matched',1)
 end)
 log('SEALED',frame,fid,D.Checksum(D.Encode(checkpoint)),'serialized_before_SSF=true firsttick_only=true');SendToUnsynced(action,'sealed',frame);return true
end
function gadget:GameFrame(frame)
 if phase=='failed'or phase=='complete'then return end
 if phase=='resumed'then
  local R=GG.Recoil40KTacticalRemains;if not R or not R.features[fid]then fail('original_feature_lost_before_landing');return end
  if not R.flights[fid]then local ok,result=pcall(function()return W.Landing(checkpoint,read())end);if not ok then fail(result);return end;phase='complete';log('SAME_ONE_ENTITLEMENT_LANDED',frame,fid,checkpoint.key,'exactCheckpointPassed=false nativeResumeAccepted=false paidEconomyAccepted=false');return end
  if frame>deadline then fail('bounded_post_resume_landing_timeout')end;return
 end
 if probe then if frame~=checkpoint.frame then fail('sealed_checkpoint_advanced_without_matching_preowner_probe')end;return end
 if not start or frame-start>600 then fail('bounded_airborne_capture_timeout');return end
 local R=GG.Recoil40KTacticalRemains;if not R then return end
 local ids={};for id in pairs(R.flights or{})do if(R.features[id]or{}).actor=='imp_devastator'then ids[#ids+1]=id end end
 if #ids>1 then fail('multiple_Heavy_flights');return end
 if #ids==1 then fid=ids[1];local ok,state=pcall(read);if not ok then fail(state);return end;checkpoint=state;phase='checkpoint';Spring.SetGameRulesParam(marker..'marker',1);Spring.SetGameRulesParam(marker..'frame',frame);Spring.SetGameRulesParam(marker..'run',run);log('CAPTURE',frame,fid,state.key,D.Checksum(D.Encode(state)),'funded_non_economy=true');SendToUnsynced(action,'capture',frame)
 elseif checkpoint then fail('airborne_checkpoint_landed_before_owned_pause')end
end
function gadget:Shutdown()if GG.Recoil40KCorpseSaveCheckpoint==interface then GG.Recoil40KCorpseSaveCheckpoint=nil end end
