-- Owned diagnostic only. Commands enter the ordinary native/BAR admission path.
local M={}
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function clone(x)if type(x)~='table'then return x end;local y={};for k,v in pairs(x)do y[k]=clone(v)end;return y end
local function equal(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
function M.New(S,C,R,profiles,defs,game,emit)
 local D={phase='initial',events=0,insertEvents=0}
 local ids,seed,leader,baseline,inserted,queued,frame0
 local function terminal(reason)D.result=reason;D.phase='done';emit('COMPLETE',reason,'native_queue_diagnostic=true hud_input_acceptance=false ambiguous_native_acceptance=false');return true,reason end
 local function fail(reason)return terminal('FAIL '..reason)end
 local function snapshot()
  local s=R.squads[seed];if not s or s.leader~=leader then return nil,'owner_or_leader_changed'end
  local current=R.Members(leader);table.sort(current);if not equal(current,ids)then return nil,'cohort_identity_changed'end
  local rows={}
  for _,id in ipairs(ids)do
   local hp,_,_,_,built=S.GetUnitHealth(id)
   if S.GetUnitTeam(id)~=s.team or not hp or hp<=0 or built~=1 or S.GetUnitTransporter(id)then return nil,'body_not_own_full_ground'end
   local n=S.GetUnitCommandCount(id);local q=S.GetUnitCommands(id,-1)
   if not finite(n)or n%1~=0 or n<0 or n>8 or type(q)~='table'or #q~=n then return nil,'unreadable_queue'end
   local seen={};rows[id]={}
   for i,c in ipairs(q)do
    if not finite(c.id)or not finite(c.tag)or c.tag<0 or c.tag%1~=0 or seen[c.tag]or type(c.options)~='table'or not finite(c.options.coded)or type(c.params)~='table'then return nil,'unreadable_command'end
    seen[c.tag]=true;local p={};for j,v in ipairs(c.params)do if not finite(v)then return nil,'unreadable_params'end;p[j]=v end
    for k in pairs(c.params)do if type(k)~='number'or k%1~=0 or k<1 or k>#p then return nil,'sparse_params'end end
    rows[id][i]={id=c.id,tag=c.tag,coded=c.options.coded,params=p}
    emit('QUEUE','phase='..D.phase,'unit='..id,'index='..i,'id='..c.id,'tag='..c.tag,'coded='..c.options.coded,'params='..table.concat(p,','))
   end
  end;return rows
 end
 local function order(cmd,p,opts)emit('ISSUE','phase='..D.phase,'leader='..leader,'id='..cmd,'coded='..opts,'params='..table.concat(p,','),'origin=owned_diagnostic');S.GiveOrderToUnit(leader,cmd,p,opts)end
 function D.Event(id,cmd,tag,player,synced,lua,insert)
  if not ids then return end;local found=false;for _,v in ipairs(ids)do if v==id then found=true end end;if not found then return end
  D.events=D.events+1;if D.events>128 then D.result='FAIL command_event_cap';D.phase='done';return end
  if insert then D.insertEvents=D.insertEvents+1 end
  emit('ADMISSION','unit='..id,'cmd='..tostring(cmd),'tag='..tostring(tag),'player='..tostring(player),'fromSynced='..tostring(synced),'fromLua='..tostring(lua),'fromInsert='..tostring(insert~=nil),'raw_origin_only=true')
 end
 function D.Hold(ctx,frame)
  if D.phase=='done'then return true,D.result end
  if D.phase=='initial'then
   for _,name in ipairs({'GetUnitCommands','GetUnitCommandCount','GetUnitHealth','GetUnitTeam','GetUnitTransporter','GetUnitPosition','GetUnitDefID','GetGroundHeight','GiveOrderToUnit'})do if type(S[name])~='function'then return fail('missing_api_'..name)end end
   if type(ctx)~='table'or ctx.phase~='delivery_checkpoint'or ctx.team~=0 or type(ctx.originalMembers)~='table'or type(ctx.proof)~='table'or not ctx.proof.paid_factory or not ctx.proof.paid_full_squad or not ctx.proof.ordinary_start then return fail('ordinary_paid_context_required')end
   local s=R.squads[ctx.seed];local p=profiles.profiles.marine_tactical
   if not s or s.profile~='marine_tactical'or s.team~=ctx.team or not p then return fail('not_tactical')end
   seed=s.id;leader=s.leader;ids=R.Members(leader);table.sort(ids)
   if #ids~=p.capacity then return fail('not_full_capacity')end
   for slot,id in pairs(s.slots)do
    local cost=s.investments[slot];local d=defs[S.GetUnitDefID(id)]
    if not ctx.originalMembers[id]or s.generations[slot]~=1 or type(cost)~='table'or not d then return fail('original_body_investment_mismatch')end
    local expected={metal=d.metalCost,energy=d.energyCost,work=d.buildTime};local cp=d.customParams or{}
    -- Static paid leader UnitDef is priced for the whole product. The squad
    -- owner's SetUnitCosts changes only the live body instance. Preserve its
    -- authentic per-body bill; never divide an arbitrary definition silently.
    if id==leader and cp.prototype40k_squad_product==s.profile then
     if tonumber(cp.prototype40k_squad_capacity)~=p.capacity then return fail('original_body_investment_mismatch')end
     expected={metal=tonumber(cp.prototype40k_squad_body_metal),energy=tonumber(cp.prototype40k_squad_body_energy),work=tonumber(cp.prototype40k_squad_body_work)}
     local native={metal=d.metalCost,energy=d.energyCost,work=d.buildTime}
     for _,key in ipairs({'metal','energy','work'})do
      if not finite(expected[key])or expected[key]<=0 or not finite(native[key])or math.abs(native[key]-expected[key]*p.capacity)>.001 then return fail('original_body_investment_mismatch')end
     end
    end
    for _,key in ipairs({'metal','energy','work'})do
     if not finite(cost[key])or cost[key]<=0 or not finite(expected[key])or expected[key]<=0 or math.abs(cost[key]-expected[key])>.001 then return fail('original_body_investment_mismatch')end
    end
   end
   frame0=frame;local q,why=snapshot();if not q then return fail(why)end
   for _,id in ipairs(ids)do if #q[id]~=0 then return fail('initial_queue_not_empty')end end
   local x,_,z=S.GetUnitPosition(leader);if not finite(x)or not finite(z)then return fail('position_missing')end
   local x1,z1=math.min(game.mapSizeX-64,math.max(64,x+128)),math.min(game.mapSizeZ-64,math.max(64,z+96))
   local x2,z2=math.min(game.mapSizeX-64,math.max(64,x-128)),math.min(game.mapSizeZ-64,math.max(64,z-96))
   queued={{x1,S.GetGroundHeight(x1,z1),z1},{x2,S.GetGroundHeight(x2,z2),z2}}
   D.phase='baseline';order(C.WAIT,{},0);order(C.MOVE,queued[1],C.OPT_SHIFT);order(C.FIGHT,queued[2],C.OPT_SHIFT);return true
  end
  if frame-frame0>120 then return fail('timeout')end
  local q,why=snapshot();if not q then return fail(why)end
  if D.phase=='baseline'then
   local different=false
   for _,id in ipairs(ids)do local v=q[id];if #v~=3 or v[1].id~=C.WAIT or v[2].id~=C.MOVE or not equal(v[2].params,queued[1])or v[2].coded~=C.OPT_SHIFT or v[3].id~=C.FIGHT or not equal(v[3].params,queued[2])or v[3].coded~=C.OPT_SHIFT then return fail('baseline_queue_intent')end;if v[2].tag~=q[leader][2].tag then different=true end end
   if not different then return terminal('INCONCLUSIVE no_distinct_native_member_tags')end
   baseline=clone(q);D.phase='insert';order(C.INSERT,{q[leader][2].tag,C.PATROL,0,queued[2][1],queued[2][2],queued[2][3]},0);return true
  elseif D.phase=='insert'then
   for _,id in ipairs(ids)do local v=q[id];local b=baseline[id];if #v~=4 or not equal(v[1],b[1])or not equal(v[3],b[2])or not equal(v[4],b[3])or v[2].id~=C.PATROL or v[2].coded~=0 or not equal(v[2].params,queued[2])then return fail('insert_local_anchor_or_shift_preservation')end end
   if D.insertEvents==0 then return fail('native_bar_insert_envelope_not_observed')end
   inserted=clone(q);D.phase='remove';order(C.REMOVE,{q[leader][2].tag},0);return true
  elseif D.phase=='remove'then
   if not equal(q,baseline)then return fail('remove_local_tag_or_unrelated_queue_changed')end
   local missing=0;for _,v in pairs(inserted)do for _,c in ipairs(v)do missing=math.max(missing,c.tag+1)end end
   D.phase='missing';order(C.INSERT,{missing,C.PATROL,C.OPT_SHIFT,queued[1][1],queued[1][2],queued[1][3]},C.OPT_SHIFT);return true
  elseif D.phase=='missing'then
   if not equal(q,baseline)then return fail('missing_anchor_mutated_queue')end
   return terminal('PASS paid_full_tactical distinct_native_tags insert_before_local_anchor remove_local_tags exact_unrelated_queue_and_shift_preserved missing_anchor_noop')
  end;return fail('unknown_phase')
 end
 return D
end
return M
