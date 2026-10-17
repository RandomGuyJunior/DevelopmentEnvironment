-- Default-off observer only; coordinator issues genuine ordinary scene orders.
local M={Option='prototype_marine_research_capture_fixture'}
function M.Enabled(o)return(o or{})[M.Option]==true or tostring((o or{})[M.Option])=='1'end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function integral(v)return finite(v)and v>=0 and v%1==0 end
local function near(a,b)return finite(a)and finite(b)and math.abs(a-b)<.001 end
function M.New(S,U,N,C,R,CMD,emit)
 for _,k in ipairs({'GetGameFrame','GetUnitDefID','GetUnitTeam','ValidUnitID','GetUnitIsDead','GetUnitHealth','GetUnitCommands','GetUnitCosts','GetUnitExperience'})do assert(type(S[k])=='function','missing native '..k)end
 assert(C and type(C.BeginOrdinaryPaymentWitness)=='function'and type(C.ReadOrdinaryPaymentWitness)=='function'and type(C.EndOrdinaryPaymentWitness)=='function'and C.jobs and C.records and C.HasResearch and R and R.Get and R.Members,'missing paid owners')
 local key='marine_squad_heavy_bolter';local rec=assert(C.records[key]);assert(rec.frames==1500 and rec.row.producer=='imp_marine_armoury'and rec.row.cost.metal==350 and rec.row.cost.energy==1500,'actual Marine bill required')
 local O={phase='waiting',nativePaymentAccepted=false};local births,finishes,releases={},{},{};local taken,given,command;local producer,capturer;local initial,cutoff,lastDestination;local sourceProduct;local armedFrame;local captureProgressSeen=false;local sourceState={};local paymentTag
 local callbackSerial=0
 local function clock()local f=S.GetGameFrame();assert(integral(f),'actual integral callback frame required');callbackSerial=callbackSerial+1;return f,callbackSerial end
 local function ordered(a,b)return a and b and integral(a.frame)and integral(b.frame)and a.frame<=b.frame and a.serial<b.serial end
 local function say(event,row)row=row or{};row.frame=S.GetGameFrame();emit(event,row)end
 local function fail(why)if O.phase~='done'then O.phase='done';O.reason='REFUSED '..why;if paymentTag then C.EndOrdinaryPaymentWitness(producer,key,1,paymentTag)end;say('COMPLETE',{reason=O.reason,nativePaymentAccepted=false})end end
 local function live(id,team)return integral(id)and S.ValidUnitID(id)==true and S.GetUnitIsDead(id)==false and S.GetUnitTeam(id)==team end
 local function full(id,team)local hp,max,_,_,p=S.GetUnitHealth(id);local xp=S.GetUnitExperience(id);return live(id,team)and finite(hp)and finite(max)and max>0 and hp>0 and hp<=max and p==1 and finite(xp)and xp>=0 end
 local function job(id,team)
  local j=C.jobs[id]and C.jobs[id][key]
  if not j or j.team~=team or j.record~=rec or not integral(j.steps)or j.steps>=1500 or not near(j.metal,350*j.steps/1500)or not near(j.energy,1500*j.steps/1500)or C.reserved[team][key]~=id then return end
  local found=false;for _,q in ipairs(S.GetUnitCommands(id,-1)or{})do if q.id==rec.cmd and q.tag==j.tag then found=true end end
  if not found or not integral(j.tag)then return end
  return{steps=j.steps,metal=j.metal,energy=j.energy,tag=j.tag}
 end
 function O.Created(id,def,team,builder)
  local name=U[def]and U[def].name
  if name=='imp_marine_armoury'or name=='imp_marine'then
   if not integral(builder)or not live(builder,team)then fail('paid_native_builder_birth_required');return end
   if births[id]then fail('duplicate_native_birth');return end
   local f,q=clock();births[id]={def=def,team=team,builder=builder,frame=f,serial=q}
  end
 end
 function O.Finished(id,def,team)if finishes[id]then fail('duplicate_native_finish');return end;local f,q=clock();finishes[id]={def=def,team=team,frame=f,serial=q}end
 function O.Released(id,def,team,factory,facdef,userOrders)
  if U[def]and U[def].name=='imp_marine'then
   if userOrders or not births[id]or births[id].builder~=factory or not full(factory,team)or not U[facdef].isFactory then fail('ordinary_full_product_release_required');return end
   if releases[id]then fail('duplicate_native_release');return end
   local f,q=clock();releases[id]={team=team,factory=factory,frame=f,serial=q}
  end
 end
 local function cohort(id,team)
  local s=R.Get(id);if not s or s.team~=team or s.profile~='marine_tactical'or #R.Members(id)~=4 or not releases[id]or releases[id].team~=team then return end
  for slot,member in pairs(s.slots)do if not full(member,team)or s.generations[slot]~=1 or not finishes[member]or finishes[member].team~=team or finishes[member].def~=S.GetUnitDefID(member)then return end end
  local work,metal,energy=0,0,0;for _,member in ipairs(R.Members(id))do local w,m,e=S.GetUnitCosts(member);if not near(w,500)or not near(m,48)or not near(e,240)then return end;work,metal,energy=work+w,metal+m,energy+e end
  if not near(work,2000)or not near(metal,192)or not near(energy,960)then return end
  return s
 end
 local function futureClock(id,s,paymentFrame)
  local b,rel=births[id],releases[id]
  if not b or b.team~=1 or b.def~=S.GetUnitDefID(id)or b.frame<=paymentFrame or not ordered(b,rel)then return false end
  for _,member in ipairs(R.Members(id))do local done=finishes[member];if not ordered(b,done)or not ordered(done,rel)or done.frame<=paymentFrame then return false end end
  return true
 end
 local function bodies(product,team,event)
  local s=cohort(product,team);assert(s,'actual full cohort required for telemetry')
  for slot=1,4 do local id=s.slots[slot];local hp,max=S.GetUnitHealth(id);local d=S.GetUnitDefID(id);local work,metal,energy=S.GetUnitCosts(id)
   say(event,{product=product,slot=slot,id=id,def=d,name=U[d].name,team=S.GetUnitTeam(id),generation=s.generations[slot],hp=hp,max=max,xp=S.GetUnitExperience(id),work=work,metal=metal,energy=energy,productBirthFrame=births[product].frame,productBirthSerial=births[product].serial,memberFinishFrame=finishes[id].frame,memberFinishSerial=finishes[id].serial,productReleaseFrame=releases[product].frame,productReleaseSerial=releases[product].serial})
  end
 end
 function O.Arm(id,enemyCommander,product)
  if O.phase~='waiting'then return false end
  local nativeProducer=N.imp_marine_armoury;local ud=U[S.GetUnitDefID(enemyCommander)]
  if not nativeProducer or S.GetUnitDefID(id)~=nativeProducer.id or not births[id]or births[id].team~=0 or not finishes[id]or not full(id,0)
   or not full(enemyCommander,1)or not ud or ud.canCapture~=true or not finite(ud.captureSpeed)or ud.captureSpeed<=0 or U[nativeProducer.id].capturable~=true then fail('native_capture_actor_or_target_not_ready');return false end
  local w,m,e=S.GetUnitCosts(id);if not near(w,1800)or not near(m,175)or not near(e,50)then fail('actual_paid_Tactica_bill_required');return false end
  local j=job(id,0);if not j or j.steps<=0 or C.HasResearch(0,key)or C.HasResearch(1,key)or not cohort(product,0)then fail('ordinary_partial_source_scene_required');return false end
  producer,capturer,sourceProduct,initial=id,enemyCommander,product,j;armedFrame=S.GetGameFrame();for slot,body in pairs(R.Get(product).slots)do local hp,max=S.GetUnitHealth(body);sourceState[body]={hp=hp,max=max,xp=S.GetUnitExperience(body),def=S.GetUnitDefID(body),slot=slot,generation=R.Get(product).generations[slot]}end;O.phase='armed';say('READY',{producer=id,capturer=enemyCommander,sourceProduct=product,steps=j.steps,metal=j.metal,energy=j.energy,tag=j.tag,nativeOrdersIssued=false,producerDef=S.GetUnitDefID(id),capturerDef=S.GetUnitDefID(enemyCommander),sourceTeam=0,destinationTeam=1,sourceResearch=C.HasResearch(0,key),destinationResearch=C.HasResearch(1,key)});bodies(product,0,'SOURCE_BODY');return true
 end
 function O.Command(id,def,team,cmd,p,opts,tag,player,fromSynced,fromLua,fromInsert)
  if O.phase=='armed'and id==capturer and team==1 and cmd==CMD.CAPTURE and p and #p==1 and p[1]==producer and not fromInsert then command={frame=S.GetGameFrame(),tag=tag,player=player,fromLua=fromLua};say('CAPTURE_ORDER',{capturer=id,target=producer,command=cmd,player=player,fromLua=fromLua})end
  return true
 end
 -- Layer49 observes native ownership callbacks before paid owner50 cancels job.
 function O.Taken(id,def,oldTeam,newTeam)
  if id==producer and given and O.phase~='done'then fail('captured_producer_retransferred');return end
  if id~=producer or O.phase~='armed'then return end
  cutoff=job(id,0)
  if def~=N.imp_marine_armoury.id or not command or not captureProgressSeen or oldTeam~=0 or newTeam~=1 or not cutoff or cutoff.steps<initial.steps or C.HasResearch(0,key)then fail('genuine_partial_capture_boundary_required');return end
  taken=true;say('NATIVE_TAKEN',{id=id,def=def,oldTeam=oldTeam,newTeam=newTeam,nativeTeam=S.GetUnitTeam(id)});say('CAPTURE_PAID_CUTOFF',cutoff)
 end
 function O.Given(id,def,newTeam,oldTeam)
  if id==producer and given and O.phase~='done'then fail('captured_producer_retransferred');return end
  if id==producer and O.phase=='armed'then if def~=N.imp_marine_armoury.id or not taken or newTeam~=1 or oldTeam~=0 then fail('native_capture_identity');return end;given=true;say('NATIVE_GIVEN',{id=id,def=def,oldTeam=oldTeam,newTeam=newTeam,nativeTeam=S.GetUnitTeam(id)})end
 end
 function O.Frame(frame)
  if O.phase=='waiting'or O.phase=='done'then return end
  if frame-armedFrame>7200 then fail('bounded_scene_timeout');return end
  local current=cohort(sourceProduct,0);if not current then fail('source_cohort_membership_changed');return end
  for body,b in pairs(sourceState)do local hp,max=S.GetUnitHealth(body);if current.slots[b.slot]~=body or current.generations[b.slot]~=b.generation or not full(body,0)or hp~=b.hp or max~=b.max or S.GetUnitExperience(body)~=b.xp or S.GetUnitDefID(body)~=b.def then fail('source_cohort_state_changed');return end end
  if command and not given then local q=(S.GetUnitCommands(capturer,-1)or{})[1];local _,_,_,progress=S.GetUnitHealth(producer);if q and q.id==CMD.CAPTURE and q.params and #q.params==1 and q.params[1]==producer and finite(progress)and progress>0 and progress<=1 then if not captureProgressSeen then captureProgressSeen=true;say('NATIVE_CAPTURE_PROGRESS',{producer=producer,progress=progress,capturer=capturer,queueCommand=q.id,queueTarget=q.params[1],queueTag=q.tag})end end end
  if not full(capturer,1)then fail('capturer_lost');return end
  if not given then return end
  if not full(producer,1)or S.GetUnitDefID(producer)~=N.imp_marine_armoury.id then fail('captured_producer_ownership_or_identity_lost');return end
  if O.phase=='armed'then
   if not full(producer,1)or C.jobs[producer]or C.reserved[0][key]or C.HasResearch(0,key)or C.HasResearch(1,key)then fail('capture_cancel_no_inherited_research');return end
   O.phase='destination';say('CANCELLED',{sourcePaidMetal=cutoff.metal,sourcePaidEnergy=cutoff.energy,refundAccepted=false,destinationStartsFresh=true,producer=producer,nativeTeam=S.GetUnitTeam(producer),sourceResearch=C.HasResearch(0,key),destinationResearch=C.HasResearch(1,key),sourceReservationCleared=C.reserved[0][key]==nil,oldJobCleared=C.jobs[producer]==nil});return
  end
  local j=job(producer,1)
  if j then
   if(not lastDestination and j.steps>1)or(lastDestination and(j.steps<lastDestination.steps or j.steps>lastDestination.steps+1))or j.tag==cutoff.tag then fail('destination_job_reset');return end
   if not paymentTag then if not C.BeginOrdinaryPaymentWitness(producer,key,1,j.tag)then fail('ordinary_payment_witness_subscription_refused');return end;paymentTag=j.tag end
   if not lastDestination or j.steps~=lastDestination.steps then say('DESTINATION_JOB',j)end;lastDestination=j;return
  end
  if C.HasResearch(1,key)then
   if not lastDestination or lastDestination.steps~=1499 or C.HasResearch(0,key)then fail('missing_complete_destination_paid_ledger');return end
   local receipt=paymentTag and C.ReadOrdinaryPaymentWitness(producer,key,1,paymentTag)
   if not receipt or receipt.producer~=producer or receipt.key~=key or receipt.team~=1 or receipt.tag~=paymentTag or receipt.ordinaryBranch~=true or receipt.nativeReturnType~='boolean'or receipt.nativeReturn~=true or not integral(receipt.frame)or receipt.frame>=frame or receipt.priorStep~=1499 or receipt.nextStep~=1500 or not near(receipt.priorMetal,350*1499/1500)or not near(receipt.priorEnergy,1500*1499/1500)or not near(receipt.deltaMetal,350/1500)or not near(receipt.deltaEnergy,1500/1500)or not near(receipt.cumulativeMetal,350)or not near(receipt.cumulativeEnergy,1500)or not integral(receipt.beginStep)or receipt.beginStep>1 or receipt.successfulCalls~=1500-receipt.beginStep or not integral(receipt.failedCalls)or receipt.unknownReturns~=0 or not near(receipt.observedMetal,350*(1500-receipt.beginStep)/1500)or not near(receipt.observedEnergy,1500*(1500-receipt.beginStep)/1500)then fail('missing_actual_ordinary_final_debit');return end
   for id,rel in pairs(releases)do if rel.team==1 then local s=cohort(id,1)
    if s and not futureClock(id,s,receipt.frame)then fail('future_product_requires_post_payment_native_birth_finish_release');return end
    if s and U[S.GetUnitDefID(s.slots[4])].name=='imp_marine_heavy_member'and cohort(sourceProduct,0)then
     receipt.paymentFrame=receipt.frame;say('ORDINARY_FINAL_DEBIT',receipt);C.EndOrdinaryPaymentWitness(producer,key,1,paymentTag);bodies(sourceProduct,0,'SOURCE_BODY_FINAL');bodies(id,1,'FUTURE_BODY');say('RESEARCH_ELIGIBILITY',{producer=producer,nativeTeam=S.GetUnitTeam(producer),sourceResearch=C.HasResearch(0,key),destinationResearch=C.HasResearch(1,key),destinationReservationCleared=C.reserved[1][key]==nil});O.phase='done';O.reason='PASS native_capture_cancel_fresh_registered_research_future4';say('COMPLETE',{reason=O.reason,registeredMetal=350,registeredEnergy=1500,nativePaymentAccepted=false,sourcePartialPaidMetal=cutoff.metal,sourcePartialPaidEnergy=cutoff.energy,futureProduct=id,futureBirthFrame=births[id].frame,futureBirthSerial=births[id].serial,futureFinishFrame=finishes[id].frame,futureFinishSerial=finishes[id].serial,futureReleaseFrame=rel.frame,futureReleaseSerial=rel.serial,finalPaymentFrame=receipt.paymentFrame,fullBodies=4,ordinaryFinalDebitObserved=true,all1500PaymentCallsObserved=receipt.beginStep==0});return
    end
   end end
  end
 end
 return O
end
return M
