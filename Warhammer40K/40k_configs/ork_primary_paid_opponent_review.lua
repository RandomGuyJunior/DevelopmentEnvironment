-- One scoped ordinary paid opposing Slugga; not combat AI/full-match acceptance.
local M={}
function M.Enabled(o)return o.prototype_diagnostic=='expandedproduction'and VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression)and o.prototype_source_acceptance=='orks'and tostring(o.prototype_ork_primary_roles)=='1'and tostring(o.prototype_ork_source_consumers_review)=='1'and tostring(o.prototype_ork_primary_paid_opponent)=='1'end
function M.New(S,D,N,CMD,C,o,log,E)
 local enabled=M.Enabled(o);local P={enabled=enabled};local starter,active,index,target,failed=nil,nil,1,nil,nil;local initial={};local tasks={'ork_generator','ork_generator','ork_boyz_hut','ork_slugga'};local factory;local proofs={}
 local function fail(why)failed=why;log('PAID_OPPONENT_FAILURE',why);return false end
 local function current(id,def)return id and S.ValidUnitID(id)and not S.GetUnitIsDead(id)and S.GetUnitTeam(id)==1 and S.GetUnitDefID(id)==def end
 local function menu(id,def)for _,d in ipairs(D[S.GetUnitDefID(id)].buildOptions or{})do if d==def then return true end end;return false end
 local function hold(id)S.GiveOrderToUnit(id,CMD.STOP,{},{});S.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},{})end
 local function site(name)
  local def=N[name].id;local x,_,z=S.GetUnitPosition(starter);local d=D[def];local rx,rz=(d.xsize or 0)*4,(d.zsize or 0)*4
  for radius=320,800,80 do for a=0,7 do
   local xx,zz=x+radius*math.cos(a*math.pi/4),z+radius*math.sin(a*math.pi/4);local yy=S.GetGroundHeight(xx,zz)
   if xx-rx>=96 and zz-rz>=96 and xx+rx<=Game.mapSizeX-96 and zz+rz<=Game.mapSizeZ-96 then
    local bx,by,bz=S.Pos2BuildPos(def,xx,yy,zz,0)
    if S.TestBuildOrder(def,bx,by,bz,0)==2 and #(S.GetFeaturesInRectangle(bx-rx,bz-rz,bx+rx,bz+rz)or{})==0 then return {bx,by,bz,0}end
   end
  end end
 end
 function P.Birth(id,def,team,builder,frame)
  if not enabled then return end
  if team==1 and builder==nil and frame<=0 and N.ork_big_mek_commander and def==N.ork_big_mek_commander.id then
   if next(initial)then fail('duplicate_initial_opponent')else initial[id]=def end
  end
  if not active or team~=1 or builder~=active.producer or def~=active.def or active.created then return end
  local progress=select(5,S.GetUnitHealth(id));if not progress or progress>=1 then fail('instant_or_unknown_opponent_birth');return end
  active.created=id;log('ACTUAL_PAID_OPPONENT_BIRTH',id,def,builder,frame)
 end
 function P.Finished(id,def,team)
  if not enabled or not active or id~=active.created then return end
  if team~=1 or def~=active.def or not current(id,def)or not active.witness then fail('opponent_progress_use_receipt_missing');return end
  local cp=D[def].customParams or{};local expected=E and E.entries and E.entries[active.name]
  if not expected or expected.reviewed~=true or cp.source_entity~=expected.source_entity or cp.source_model_sha256~=expected.source_model_sha256 or cp.source_native_glb_sha256~=expected.generated_glb_sha256 then fail('paid_opponent_bundle_identity_missing');return end
  proofs[id]={id=id,definition=def,team=1,producer=active.producer,name=active.name,progressObserved=true,resourcesObserved=true}
  if active.name=='ork_slugga'then
   local receipt=C.sourceOrkProducerCosts and C.sourceOrkProducerCosts.receipts[id]
   local cp=D[def].customParams or{};local u=C.units[id];local expected=E and E.entries and E.entries.ork_slugga
   if not receipt or receipt.builder~=factory or receipt.metal~=30 or receipt.energy~=0 or receipt.work~=592.5 or not expected or expected.reviewed~=true or cp.source_entity~=expected.source_entity or cp.source_model_sha256~=expected.source_model_sha256 or cp.source_native_glb_sha256~=expected.generated_glb_sha256 or not u or u.team~=1 or not u.finished then fail('genuine_paid_slugga_cost_or_identity_missing');return end
   target=id;hold(id);hold(starter);log('ACTUAL_PAID_OPPONENT_SLUGGA_READY',id,receipt.metal,receipt.energy,receipt.work,S.GetUnitHealth(id),'ordinary_holdfire_full_native_health_not_modified')
  elseif active.name=='ork_boyz_hut'then factory=id;hold(id)end
  log('ACTUAL_PAID_OPPONENT_STEP_FINISHED',index,active.name,id);index=index+1;active=nil
 end
 function P.Frame(frame)
  if not enabled then return true end;if failed then return false,failed end
  if starter and not current(starter,N.ork_big_mek_commander.id)then return fail('initial_opponent_capture_or_death')end
  if target then if not current(target,N.ork_slugga.id)then return fail('paid_opponent_target_capture_or_death')end;return true end
  if not starter then
   for id,def in pairs(initial)do
    if not current(id,def)or S.GetTeamRulesParam(1,'startUnit')~=def then return fail('native_initial_opponent_identity_mismatch')end
    local cp=D[def].customParams or{};if cp.prototype40k_vital~='commander'or cp.faction~='Orks'then return fail('initial_opponent_is_not_native_ork_commander')end
    starter=id;hold(id);log('ACTUAL_INITIAL_OPPONENT_BIND',id,def)
   end
   if not starter and frame>=300 then return fail('initial_opponent_birth_missing')end;return true
  end
  if active then
   if not current(active.producer,active.producerDef)then return fail('opponent_producer_capture_or_death')end
   if active.created then
    if not current(active.created,active.def)then return fail('paid_opponent_child_capture_or_death')end
    local p=select(5,S.GetUnitHealth(active.created));local _,m,_,e=S.GetUnitResources(active.producer);local cmd
    if active.name=='ork_slugga'then local q=S.GetFactoryCommands(active.producer,1);cmd=q and q[1]and q[1].id
    else cmd=S.GetUnitCurrentCommand(active.producer)end
    local child=active.name~='ork_slugga'or S.GetUnitIsBuilding(active.producer)==active.created
    if p and p>0 and p<1 and cmd==-active.def and child and((m or 0)>0 or(e or 0)>0)then active.witness=true end
   end
   if frame-active.start>18000 then return fail('ordinary_paid_opponent_timeout')end;return true
  end
  if frame%30~=0 then return true end
  local name=tasks[index];if not name then return true end;local def=N[name]and N[name].id;local producer=index==4 and factory or starter
  if not def or not producer or not menu(producer,def)or not C.CanBuild(1,def,producer,false)then return fail('genuine_opponent_menu_or_source_gate_refused_'..name)end
  local params=index==4 and{}or site(name);if not params then return fail('native_opponent_build_site_unavailable_'..name)end
  active={name=name,def=def,producer=producer,producerDef=S.GetUnitDefID(producer),start=frame}
  S.GiveOrderToUnit(producer,-def,params,{});log('ACTUAL_PAID_OPPONENT_ORDER',name,producer,frame);return true
 end
 function P.Target()return target end
 function P.Receipt(id)local r=proofs[id];if r and current(id,r.definition)then return r end end
 function P.Failure()return failed end
 return P
end
return M
