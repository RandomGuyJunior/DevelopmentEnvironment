-- Default-off isolated C05 ordinary order assistant; owns no resources/research.
local M={Option='prototype_guard_capture_order_assistant'}
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function id(x)return finite(x)and x>=0 and x%1==0 end
local function yes(v)return v==true or v=='1'or v==1 end
function M.Enabled(o)return type(o)=='table'and yes(o[M.Option])end
function M.New(S,U,N,G,CMD,options,choose,park,clear,emit)
 local A={phase='initial',births={},finishes={},releases={},units={[0]={},[1]={}},index=1}
 A.Frame=function()end;A.Created=function()end;A.Finished=function()end;A.Released=function()end
 local function fail(s)A.phase='done';A.reason='REFUSED '..s;emit('COMPLETE',A.reason);return false end
 for _,key in ipairs({'ValidUnitID','GetUnitIsDead','GetUnitTeam','GetUnitHealth','GiveOrderToUnit','GetUnitDefID','AreTeamsAllied','GetTeamUnits','GetTeamResources','GetUnitPosition'})do if type(S[key])~='function'then fail('missing_native_'..key);return A end end
 if type(choose)~='function'or type(park)~='function'or type(clear)~='function'or CMD.CAPTURE~=130 then fail('exact_native_helpers_capture_command');return A end
 local function live(u,t)
  if not id(u)or S.ValidUnitID(u)~=true or S.GetUnitIsDead(u)~=false or S.GetUnitTeam(u)~=t then return false end
  local hp,max,_,_,b=S.GetUnitHealth(u);return finite(hp)and finite(max)and hp>0 and hp<=max and b==1
 end
 local function order(u,c,p)
  if S.GiveOrderToUnit(u,c,p,0)~=true then return fail('native_order_dispatch')end
  emit('ORDINARY_ORDER',u,c,'root_assisted_fromLua=true paid_native_acceptance=false');return true
 end
 local tasks={}
 for team=0,1 do
  for _,key in ipairs({'imp_mex','imp_generator','imp_mex','imp_generator','imp_mex','imp_generator','imp_barracks'})do tasks[#tasks+1]={team=team,key=key,owner='commander',metal=key=='imp_mex',role=key=='imp_barracks'and'factory'or nil}end
  if team==0 then tasks[#tasks+1]={team=0,key='imp_research',owner='commander',role='producer'};tasks[#tasks+1]={team=0,key='imp_guardsman',owner='factory',role='source',product=true}end
 end
 local function queueTask(t)
  local u=A.units[t.team][t.owner];local nd=N[t.key];local d=u and U[S.GetUnitDefID(u)]
  if not nd or not d or not live(u,t.team)then return fail('actual_paid_builder_or_definition')end
  local found=false;for _,v in ipairs(d.buildOptions or{})do if v==nd.id then found=true end end
  if not found or(t.product and d.isFactory~=true)then return fail('actual_native_buildmenu')end
  t.def=nd.id;local ok,pos=true,{}
  if not t.product then ok,pos=pcall(choose,t.def,u,t.metal)end
  if not ok or type(pos)~='table'then return fail('productive_native_site_unavailable')end
  if not t.product then for i=1,4 do if not finite(pos[i])then return fail('typed_native_site')end end end
  A.task=t;A.phase='building';return order(u,-t.def,pos)
 end
 function A.Created(u,d,t,b)
  local q=A.task;if A.phase~='building'or not q or d~=q.def then return end
  if t~=q.team or b~=A.units[t][q.owner]or not id(u)or q.birth then fail('nonunique_owned_paid_birth');return end
  q.birth=u;A.births[u]={team=t,def=d,builder=b}
 end
 function A.Finished(u,d,t)
  if not A.task or u~=A.task.birth then return end
  if not id(u)or not id(d)or not id(t)then fail('typed_native_finish');return end
  if A.finishes[u]or d~=A.task.def or t~=A.task.team then fail('duplicate_or_changed_owned_finish');return end
  A.finishes[u]={team=t,def=d}
 end
 function A.Released(u,d,t,f,fd,user)
  local q=A.task;if not q or not q.product or u~=q.birth then return end
  if q.released or t~=q.team or d~=q.def or f~=A.units[t][q.owner]or fd~=S.GetUnitDefID(f)or user~=false then fail('genuine_native_factory_release');return end;q.released=true
 end
 function A.Frame(frame)
  if A.phase=='done'then return end
  if not id(frame)or frame<1 then return fail('native_frame')end
  if A.phase=='initial'then
   if frame~=1 or not M.Enabled(options)or not yes(options.prototype_guard_research_capture_fixture)or not yes(options.prototype_guard_squad_flamer)or not yes(options.prototype_source_progression)or options.prototype_diagnostic~='normal'or(options.prototype_test_speed~='1'and options.prototype_test_speed~=1)then return fail('exclusive_fresh_capture_scene')end
   for k,v in pairs(options)do if type(k)~='string'then return fail('typed_native_options')end;if k:match('^prototype_')and yes(v)and k~=M.Option and k~='prototype_guard_research_capture_fixture'and k~='prototype_guard_squad_flamer'and k~='prototype_source_progression'and k~='prototype_development_playtest'and k~='prototype_test_speed'then return fail('competing_enabled_prototype')end end
   if S.AreTeamsAllied(0,1)~=false then return fail('opposing_owners_required')end
   for team=0,1 do
    local all=S.GetTeamUnits(team);local m=S.GetTeamResources(team,'metal');local e=S.GetTeamResources(team,'energy')
    local n=0;if type(all)=='table'then for k,v in pairs(all)do n=n+1;if k~=1 or not id(v)then return fail('typed_native_team_census')end end end
    if type(all)~='table'or n~=1 or not N.armcom or S.GetUnitDefID(all[1])~=N.armcom.id or not live(all[1],team)or not finite(m)or not finite(e)or math.abs(m-1000)>5 or math.abs(e-1000)>5 then return fail('ordinary_two_guard_start')end
    A.units[team].commander=all[1];if not order(all[1],CMD.FIRE_STATE,{0})then return end
   end
   A.phase='next';return
  end
  if frame>54000 then return fail('bounded_ordinary_setup_timeout')end
  local O=G.Recoil40KGuardCaptureObserver;local C=G.Recoil40KResearch;local R=G.Recoil40KSquads
  if not O or not C or not R then return fail('existing_observer_paid_owners_required')end
  if O.phase=='done'then A.phase='done';A.reason=O.reason;emit('OBSERVER_RESULT',O.reason,'native_acceptance=false');return end
  if A.phase=='next'then local t=tasks[A.index];if not t then A.phase='approach';return end;queueTask(t);return end
  if A.phase=='building'then
   local q=A.task;local f=q.birth and A.finishes[q.birth]
   if not f then return end
   if f.team~=q.team or f.def~=q.def or not live(q.birth,q.team)then return fail('native_paid_completion')end
   if q.product then
    if not q.released then return end
    local squad=R.Get(q.birth);if not squad or squad.team~=q.team or #R.Members(q.birth)~=8 then return fail('actual_full8_product')end
    for _,body in ipairs(R.Members(q.birth))do if not live(body,q.team)then return fail('full8_finished_live')end end
    if not q.departed then
     local ok,pos=pcall(park,q.birth,A.units[q.team][q.owner])
     if not ok or type(pos)~='table'or not finite(pos[1])or not finite(pos[2])or not finite(pos[3])then return fail('ordinary_product_rally_unavailable')end
     for _,body in ipairs(R.Members(q.birth))do if not order(body,CMD.FIRE_STATE,{0})then return end end
     if not order(q.birth,CMD.MOVE,pos)then return end;q.departed=true;return
    end
    for _,body in ipairs(R.Members(q.birth))do local ok,outside=pcall(clear,A.units[q.team][q.owner],body);if not ok or outside~=true then q.clearFrames=0;return end end
    q.clearFrames=(q.lastClear==frame-1)and((q.clearFrames or 0)+1)or 1;q.lastClear=frame;if q.clearFrames<30 then return end
   end
   if q.role then A.units[q.team][q.role]=q.birth end;A.index=A.index+1;A.task=nil;A.phase=q.role=='future'and'wait_observer'or'next';return
  end
  local producer=A.units[0].producer;local capturer=A.units[1].commander
  if A.phase=='approach'then
   if not live(producer,0)or not live(capturer,1)then return fail('real_capture_actors_lost')end
   local x,y,z=S.GetUnitPosition(producer);if not finite(x)or not finite(y)or not finite(z)then return fail('producer_position')end
   if not order(capturer,CMD.MOVE,{x,y,z})then return end;A.phase='near';return
  end
  if A.phase=='near'then
   local x,_,z=S.GetUnitPosition(producer);local cx,_,cz=S.GetUnitPosition(capturer)
   if not finite(x)or not finite(z)or not finite(cx)or not finite(cz)then return fail('native_capture_range_positions')end
   if(x-cx)^2+(z-cz)^2>120^2 then return end
   if not order(capturer,CMD.STOP,{})then return end
   local rec=C.records.guard_squad_flamer;if not rec or rec.frames~=1050 then return fail('ordinary_registered_research')end
   if not order(producer,rec.cmd,{})then return end;A.phase='arming';return
  end
  if A.phase=='arming'then if O.phase~='armed'then return end;if not order(capturer,CMD.CAPTURE,{producer})then return end;A.phase='capturing';return end
  if A.phase=='capturing'then
   if O.phase~='destination'then return end
   if S.GetUnitTeam(producer)~=1 or C.jobs[producer]~=nil or C.HasResearch(0,'guard_squad_flamer')or C.HasResearch(1,'guard_squad_flamer')then return fail('real_capture_cancellation_boundary')end
   if not order(producer,C.records.guard_squad_flamer.cmd,{})then return end;A.phase='research';return
  end
  if A.phase=='research'then
   if not C.HasResearch(1,'guard_squad_flamer')then return end
   -- Observer owns the actual fresh native tag and retained final-debit receipt.
   if O.phase~='destination'then return fail('existing_observer_destination_required')end
   tasks[A.index]={team=1,key='imp_guardsman',owner='factory',role='future',product=true};A.phase='next';return
  end
 end
 return A
end
return M
