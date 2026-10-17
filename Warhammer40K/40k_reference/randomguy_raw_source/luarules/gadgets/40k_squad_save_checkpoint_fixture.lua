-- Explicit owned native .ssf checkpoint; no economy, health, membership or order writes.
function gadget:GetInfo()return{name='40K paid squad native save checkpoint',desc='Default-off paid partial-repair save/resume observer',author='Local project',layer=152,enabled=true}end
local o=Spring.GetModOptions()or{};local on=VFS.Include('40k_configs/development_playtest.lua').OptionEnabled
local family=o.prototype_squad_paid_faction or'marine'
local guardResearch=family=='guard'and on(o.prototype_guard_squad_paid_research_fixture)and on(o.prototype_guard_squad_flamer)and not on(o.prototype_squad_paid_fixture)and not on(o.prototype_guard_paid_flamer_combat)
local marinePaid=family=='marine'and on(o.prototype_squad_paid_fixture)and not on(o.prototype_guard_squad_paid_research_fixture)
if not on(o.prototype_squad_save_checkpoint_fixture)or not(marinePaid or guardResearch)or o.prototype_diagnostic~='normal'or not on(o.prototype_source_progression)or tonumber(o.prototype_test_speed or 1)~=1 then return false end
local profileKey=guardResearch and'guard_line'or'marine_tactical'
local commanderName=guardResearch and'armcom'or'smcom'
local firstTick=on(o.prototype_squad_save_first_tick_fixture)
local pendingResearch=on(o.prototype_squad_save_pending_research_fixture)
local pendingFirstTick=on(o.prototype_squad_save_pending_first_tick_fixture)
if pendingFirstTick and(not pendingResearch or not firstTick or not guardResearch)or pendingResearch and(not guardResearch or firstTick~=pendingFirstTick)then Spring.Echo('40K SQUAD SAVE REFUSED pending_research_boundary_mode_mismatch');return false end
local pendingProbe=pendingResearch and VFS.Include('40k_configs/pending_guard_research_save.lua')
local resultKey=firstTick and'40k_squad_save_first_tick_result'or'40k_squad_save_checkpoint_result'
local name=o.prototype_squad_save_checkpoint_name
local stamp,nonce
if type(name)=='string'then stamp,nonce=name:match('^40k%-owned%-save%-(%d%d%d%d%d%d%d%dT%d%d%d%d%d%dZ)%-(%x+)$')end
if not stamp or not nonce or #nonce~=12 then Spring.Echo('40K SQUAD SAVE REFUSED invalid_unique_name');return false end
local action='40k_squad_save_checkpoint';local prefix='40k-squad-save:'..name..':'
local function log(...)Spring.Echo(firstTick and'40K SQUAD FIRST_TICK SAVE'or'40K SQUAD SAVE',...)end
if not gadgetHandler:IsSyncedCode()then
 local latest,requested,saved,resumeRequested,requestedAt,sealRequested,sealedFrame,identityLogged,failedAt;local approved=false;local resumeFinished=false
 local function report(_,label,frame)
  if label=='capture'then latest=frame elseif label=='sealed'then sealedFrame=frame elseif label=='resume_approved'then approved=frame elseif label=='failed'then log('REFUSED synced_invariants');requested=true;saved=true;local _,isSaved=Spring.GetGameState();if isSaved then resumeFinished=true;failedAt=Spring.GetTimer()end end
 end
 function gadget:Initialize()gadgetHandler:AddSyncAction(action,report)end
 function gadget:Update()
  local loading,isSaved=Spring.GetGameState();if not loading then return end
  local marker=Spring.GetGameRulesParam('40k_squad_save_checkpoint_marker');local frame=Spring.GetGameFrame();local captured=Spring.GetGameRulesParam('40k_squad_save_checkpoint_frame')
  local _,_,paused=Spring.GetGameSpeed()
  if isSaved then
   if failedAt then
    local player=Spring.GetMyPlayerID();local playerName,_,spec,team=Spring.GetPlayerInfo(player,false)
    if player==0 and playerName=='SquadDiagnostic'and not spec and team==0 and marker==1 and Spring.GetGameRulesParam('40k_squad_save_checkpoint_sealed')==1 and Spring.DiffTimers(Spring.GetTimer(),failedAt)>=3 then
     failedAt=nil;Spring.SendCommands('quitforce');log('OWNED_RESUME_FAILURE_AUTOCLOSE',name,frame)
    end
    return
   end
   if firstTick then
    -- This separate boundary uses the serialized synced delayed observer,
    -- never the exact-frame resume LUAMSG/startup-player wait route.
    local player=Spring.GetMyPlayerID();local playerName,_,spec,team=Spring.GetPlayerInfo(player,false)
    if player~=0 or playerName~='SquadDiagnostic'or spec or team~=0 or marker~=1 or Spring.GetGameRulesParam('40k_squad_save_checkpoint_sealed')~=1 then return end
    if not identityLogged then identityLogged=true;log('FIRST_TICK_NATIVE_SAVED_GAME',name,captured,frame,'IsSavedGame=true')end
    return
   end
   if resumeFinished then return end
   -- Engine IsSavedGame is mandatory; ordinary Lua reload cannot approve resume.
   if marker~=1 or Spring.GetGameRulesParam('40k_squad_save_checkpoint_sealed')~=1 then return end
   if approved then
    if not resumeRequested or approved~=captured then resumeFinished=true;failedAt=Spring.GetTimer();log('REFUSED wrong_approved_checkpoint',name,approved,captured);return end
    -- The synced callback already verified the exact saved frame; native frames
    -- may legitimately advance before the next rendered unsynced Update.
    if paused then Spring.SendCommands('pause 0');log('RESUME_UNPAUSE',name,approved)
    else log('RESUME_APPROVED_RUNNING',name,approved,'current_frame',frame)end
    approved=false;resumeFinished=true;return
   end
   if captured~=frame then resumeFinished=true;failedAt=Spring.GetTimer();log('REFUSED resume_checkpoint_frame_advanced',name,captured,frame);return end
   local now=Spring.GetTimer()
   if not requestedAt then requestedAt=now end
   if Spring.DiffTimers(now,requestedAt)>30 then resumeFinished=true;failedAt=now;log('REFUSED resume_authorisation_timeout',name,frame);return end
   if not resumeRequested then
    local player=Spring.GetMyPlayerID();local playerName,active,spec,team=Spring.GetPlayerInfo(player,false)
    if player~=0 or playerName~='SquadDiagnostic'or spec or team~=0 then
     if not identityLogged then identityLogged=true;log('RESUME_IDENTITY_WAIT',name,frame,player,playerName,active,spec,team)end
     return
    end
    -- Native LuaRules messages are valid before playing; PauseAction is not.
    -- Request the strict restored-state comparison before the first SimFrame.
    resumeRequested=true;Spring.SendLuaRulesMsg(prefix..'resume:'..frame);log('RESUME_CHECK_REQUEST',name,frame,'native_original_player_pre_simulation','paused',paused)
   end
   return
  end
  if marker==1 and not latest then return end -- ordinary unsynced reload: no resave/unpause
  if latest and not requested then requested=true;requestedAt=Spring.GetTimer();Spring.SendCommands('pause 1');log('PAUSE_REQUEST',name,latest)end
  if requested and not saved and Spring.DiffTimers(Spring.GetTimer(),requestedAt)>30 then saved=true;log('REFUSED pause_or_exact_checkpoint_timeout');return end
  if requested and not saved and paused and latest==frame and captured==frame and marker==1 then
   if not sealRequested then sealRequested=true;Spring.SendLuaRulesMsg(prefix..'seal:'..frame);log('SEAL_REQUEST',name,frame);return end
   if sealedFrame~=frame or Spring.GetGameRulesParam('40k_squad_save_checkpoint_sealed')~=1 then return end
   saved=true;Spring.SendCommands('save '..name);log('SAVE_COMMAND_SENT',name,frame,'normal_ssf_no_overwrite_not_file_readiness');return
  end
 end
 function gadget:Shutdown()gadgetHandler:RemoveSyncAction(action)end
 return
end
local phase='waiting';local checkpoint;local sealed=false;local resumed=false;local start=Spring.GetGameFrame();local deadline
local firstTickProbe=firstTick and VFS.Include('40k_configs/squad_first_tick_save_probe.lua')
local firstTickObserver
local profiles=VFS.Include('40k_configs/active_squad_profiles.lua')
local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local function same(a,b)
 if type(a)~=type(b)then return false end
 if type(a)=='number'then return a==b or a==a and b==b and math.abs(a-b)<=1e-6*math.max(1,math.abs(a),math.abs(b))end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function identity(a,b)
 if a.seed~=b.seed or a.team~=b.team or a.missingSlot~=b.missingSlot or a.commander.id~=b.commander.id or a.commander.def~=b.commander.def or a.snapshot.serial~=b.snapshot.serial or a.snapshot.version~=b.snapshot.version then return false end
 for seed,s in pairs(a.snapshot.squads)do
  local t=b.snapshot.squads[seed];if not t or s.id~=t.id or s.team~=t.team or s.profile~=t.profile or s.leader~=t.leader then return false end
  for slot,id in pairs(s.slots)do if t.slots[slot]~=id then return false end end
  for slot,g in pairs(s.generations)do if t.generations[slot]~=g then return false end end
 end
 for slot,u in pairs(a.bodies)do local v=b.bodies[slot];if not v or u.id~=v.id or u.def~=v.def or u.team~=v.team then return false end end
 return true
end
local function encode(v)
 if type(v)=='table'then local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end);local out={};for _,k in ipairs(keys)do out[#out+1]=string.format('%q',tostring(k))..':'..encode(v[k])end;return '{'..table.concat(out,',')..'}'end
 if type(v)=='string'then return string.format('%q',v)elseif type(v)=='number'then assert(v==v and math.abs(v)<math.huge);return string.format('%.17g',v)elseif type(v)=='boolean'then return tostring(v)end;return 'null'
end
local function fail(reason)phase='failed';Spring.SetGameRulesParam(resultKey,-1);log('FAIL',reason);SendToUnsynced(action,'failed',Spring.GetGameFrame())end
local function context()
 local F=guardResearch and GG.Recoil40KGuardSquadSaveFixture or GG.Recoil40KSquadPaidFixture;return F and F.CheckpointContext and F.CheckpointContext()
end
local function unit(id)
 if not Spring.ValidUnitID(id)or Spring.GetUnitIsDead(id)then return end
 local hp,max,para,capture,built=Spring.GetUnitHealth(id);local w,m,e=Spring.GetUnitCosts(id)
 return{id=id,def=Spring.GetUnitDefID(id),team=Spring.GetUnitTeam(id),hp=hp,max=max,paralyze=para,capture=capture,built=built,xp=Spring.GetUnitExperience(id),cost={work=w,metal=m,energy=e},orders=copy(Spring.GetUnitCommands(id,-1))}
end
local function capture(c,f)
 local R=GG.Recoil40KSquads
 if pendingResearch then return pendingProbe.Capture(c,f,Spring,R,GG.Recoil40KResearch,profiles.profiles.guard_line,unit,copy)end
 local s=R and R.squads[c.seed];local j=R and R.repair[c.seed];local proof=c.proof
 if c.phase~='repair'or not s or s.profile~=profileKey or s.team~=c.team or not j or j.slot~=c.missingSlot or s.slots[j.slot]then return end
 if not proof or proof.paid_factory~=true or proof.paid_full_squad~=true or proof.ordinary_start~=true then return nil,'paid_proof_missing'end
 local d=UnitDefNames[j.def];d=d and UnitDefs[d.id];if not d then return nil,'repair_definition_missing'end
 local bill={work=d.buildTime,metal=d.metalCost,energy=d.energyCost}
 if j.work<=0 or j.work>=bill.work or j.metal<=0 or j.energy<=0 then return end
 if math.abs(j.metal-bill.metal*j.work/bill.work)>.001 or math.abs(j.energy-bill.energy*j.work/bill.work)>.001 then return nil,'partial_job_bill_mismatch'end
 local bodies={};for slot,id in pairs(s.slots)do bodies[slot]=unit(id);if not bodies[slot]or bodies[slot].team~=s.team then return nil,'survivor_missing_or_captured'end end
 local commander=unit(c.commander);if not commander or commander.team~=s.team or commander.def~=UnitDefNames[commanderName].id then return nil,'real_commander_missing'end
 -- Canonical 40k_squads.lua registers34591 and redirects CMD.REPAIR leader to squad seed.
 local cmd=commander.orders and commander.orders[1]
 local nativeRepair=cmd and cmd.params and #cmd.params==1 and ((cmd.id==34591 and cmd.params[1]==s.id)or(cmd.id==CMD.REPAIR and cmd.params[1]==s.leader))
 if not nativeRepair then return nil,'normal_repair_command_missing'end
 local resources={metal={Spring.GetTeamResources(s.team,'metal')},energy={Spring.GetTeamResources(s.team,'energy')}}
 local record={frame=f,seed=s.id,team=s.team,profile=s.profile,commander=commander,missingSlot=c.missingSlot,originalMembers=copy(c.originalMembers),proof=copy(proof),snapshot=R.Snapshot(),bodies=bodies,remaining={work=bill.work-j.work,metal=bill.metal-j.metal,energy=bill.energy-j.energy},bill=bill,resources=resources}
 -- Both strict native boundaries must preserve permanent research and
 -- pending paid research ownership, not just the squad's current actor role.
 local C=GG.Recoil40KResearch;if not C or not C.jobs or not C.done or not C.tiers or not C.reserved then return nil,'real_research_owner_missing'end
 if guardResearch then
  local p=profiles.profiles.guard_line;local paid=c.research;local row=p and C.records and C.records[p.research]
  if c.missingSlot~=8 or not proof.paid_research or not paid or paid.key~=p.research or not row or row.producer~='imp_research'
   or row.row.cost.metal~=200 or row.row.cost.energy~=1000 or row.frames~=35*Game.gameSpeed
   or type(paid.lastSteps)~='number'or type(paid.lastMetal)~='number'or type(paid.lastEnergy)~='number'
   or paid.lastSteps<row.frames-2 or paid.lastMetal<200*(row.frames-2)/row.frames or paid.lastEnergy<1000*(row.frames-2)/row.frames
   or not C.HasResearch(s.team,p.research)or Spring.GetTeamRulesParam(s.team,'40k_research_'..p.research)~=1 then return nil,'genuine_paid_guard_research_missing'end
  record.completedResearchProof=copy(paid)
 end
 record.research={jobs=copy(C.jobs),done=copy(C.done),tiers=copy(C.tiers),reserved=copy(C.reserved)}
 return record
end
function gadget:Initialize()
 assert(not GG.Recoil40KSquadSaveCheckpoint,'Checkpoint observer already owned')
 GG.Recoil40KSquadSaveCheckpoint={Status=function()return phase end}
end
function gadget:RecvLuaMsg(msg,player)
 if msg:sub(1,#prefix)~=prefix then return false end
 local mode,n=msg:sub(#prefix+1):match('^(%a+):(%d+)$');local f=tonumber(n);local c=context();local playerName,active,spec,t=Spring.GetPlayerInfo(player,false)
 -- Native active is set only when NETMSG_PLAYERNAME reaches the client. A
 -- sealed exact-frame saved fixture may receive its authenticated original
 -- player's LUAMSG before that packet; ordinary seal still requires active.
 if firstTick and mode=='resume'then fail('first_tick_has_no_exact_resume_message_route');return true end
 local originalResume=mode=='resume'and player==0 and playerName=='SquadDiagnostic'
 local earlyOriginal=originalResume and sealed and Spring.GetGameRulesParam('40k_squad_save_checkpoint_sealed')==1
 if (mode~='seal'and mode~='resume')or not f or(not active and not earlyOriginal)or(mode=='resume'and not originalResume)or spec or not checkpoint or t~=checkpoint.team or f~=checkpoint.frame or Spring.GetGameFrame()~=f or not c or phase~='checkpoint' or Spring.GetGameRulesParam('40k_squad_save_checkpoint_marker')~=1 then fail('stale_or_unauthorised_resume');return true end
 local current,why=capture(c,f)
 if not current or not identity(current,checkpoint)or not same(current,checkpoint)then fail(why or'restored_checkpoint_changed');return true end
 if mode=='seal'then
  sealed=true;Spring.SetGameRulesParam('40k_squad_save_checkpoint_sealed',1)
  if firstTick then
   if firstTickObserver then fail('duplicate_first_tick_schedule');return true end
   firstTickObserver=firstTickProbe.Schedule(true,Script,Spring,checkpoint,function(nextFrame)
    local c=context();local playerName,_,spec,t=Spring.GetPlayerInfo(0,false)
    if not sealed or phase~='checkpoint'or Spring.GetGameRulesParam('40k_squad_save_checkpoint_marker')~=1 or Spring.GetGameRulesParam('40k_squad_save_checkpoint_sealed')~=1 or Spring.GetGameRulesParam('40k_squad_save_checkpoint_frame')~=checkpoint.frame or Spring.GetGameRulesParam('40k_squad_save_first_tick_scheduled')~=1 or playerName~='SquadDiagnostic'or spec or t~=checkpoint.team or not c then return nil,'restored_seal_player_or_context_missing'end
    return capture(c,nextFrame)
   end,function(receipt)
    log('FIRST_TICK_STATE',name,receipt.restoredFrame,receipt.expectedFrame,receipt.observedFrame,receipt.status,receipt.reason,'exact_checkpoint_passed=false native_load_witness_external=true')
    if receipt.status~='matched_first_tick_native_load_witness_required'then fail('first_tick_'..tostring(receipt.reason));return end
    resumed=true;phase='resumed';deadline=receipt.expectedFrame+1800
    Spring.SetGameRulesParam('40k_squad_save_first_tick_matched',1)
   end)
   Spring.SetGameRulesParam('40k_squad_save_first_tick_scheduled',1)
   log('FIRST_TICK_SCHEDULED',name,f,f+1,'serialized_closure_before_SSF=true')
  end
  log('SEALED',name,f);SendToUnsynced(action,'sealed',f);return true
 end
 if not sealed or Spring.GetGameRulesParam('40k_squad_save_checkpoint_sealed')~=1 then fail('resume_checkpoint_not_sealed');return true end
 resumed=true;phase='resumed';deadline=f+1800;log('RESUME_INVARIANTS',name,f,encode(current));SendToUnsynced(action,'resume_approved',f);return true
end
function gadget:GameFrame(f)
 if phase=='failed'or phase=='complete'then return end
 if not resumed then
  if sealed then if f~=checkpoint.frame then fail('sealed_checkpoint_advanced_before_resume')end;return end
  if f-start>36000 then fail('paid_checkpoint_timeout');return end
  local c=context();if not c then return end;local record,why=capture(c,f)
  if why then fail(why);return end
  if record then checkpoint=record;phase='checkpoint';Spring.SetGameRulesParam('40k_squad_save_checkpoint_marker',1);Spring.SetGameRulesParam('40k_squad_save_checkpoint_frame',f);log('CAPTURE',name,f,encode(record));SendToUnsynced(action,'capture',f)end
  return
 end
 local R=GG.Recoil40KSquads;local s=R and R.squads[checkpoint.seed]
 if not s or s.team~=checkpoint.team then fail('restored_owner_lost');return end
 if pendingResearch then
  local complete,why=pendingProbe.Observe(checkpoint,f,Spring,R,GG.Recoil40KResearch,profiles.profiles.guard_line,unit,same)
  if why then fail(why);return end
  if not complete then if f>deadline then fail('pending_research_completion_timeout')end;return end
  phase='complete';Spring.SetGameRulesParam(resultKey,1);log(firstTick and'FIRST_TICK_PENDING_RESEARCH_COMPLETION'or'PASS_PENDING_RESEARCH',name,f,'full8_noheal_xp_generation_native_role','remaining_bill_native_controller_source_observed');return
 end
 local slot=checkpoint.missingSlot;local id=s.slots[slot]
 if not id then
  local job=R.repair[checkpoint.seed];local old=checkpoint.snapshot.repair[checkpoint.seed]
  if not job or job.work<old.work-.001 or job.metal<old.metal-.001 or job.energy<old.energy-.001 then fail('remaining_job_restarted_or_lost');return end
  if f>deadline then fail('resume_completion_timeout')end;return
 end
 if checkpoint.originalMembers[id]or s.generations[slot]~=checkpoint.snapshot.squads[s.id].generations[slot]+1 then fail('replacement_identity_or_generation');return end
 for other,row in pairs(checkpoint.bodies)do if s.slots[other]~=row.id then fail('survivor_replaced');return end end
 local investment=s.investments[slot];if not investment or not same(investment,checkpoint.bill)then fail('remaining_payment_not_completed');return end
 local new=unit(id);if not new or new.team~=s.team then fail('new_body_native_owner');return end
 phase='complete';Spring.SetGameRulesParam(resultKey,1);log(firstTick and'FIRST_TICK_PAID_COMPLETION'or'PASS',name,f,'distinct_new_body',id,'same_survivors_full_bill_generation','source_observed_native_load_evidence_external')
end
function gadget:Shutdown()GG.Recoil40KSquadSaveCheckpoint=nil end
