-- Explicit synthetic entitlements only; existing native remains/pile owner does
-- every merge/payment/deletion. Not paid death, refund or economy acceptance.
local M={Version=2,Option='prototype_corpse_pile_native_fixture',Timeout=3600}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function number(v)return string.format('%.17g',v)end
local function yes(v)return v==true or v==1 or v=='1'end
function M.Enabled(o)return o and yes(o[M.Option])or false end
function M.New(S,U,N,F,W,GG,G,CMD,emit)
 local C={phase='wait',owned={},seeded=0,projectiles={},started=S.GetGameFrame()};local owner=GG.Recoil40KTacticalRemains
 local function stop(why)C.result=C.result or why;return C.result end
 function C.Close()C.closed=true end
 if not owner or not owner.piles or type(owner.features)~='table'or type(owner.entitlements)~='table'then stop('FAIL existing_authoritative_pile_owner_required');return C end
 C.owner=owner;local P=owner.piles
 local defs={};for id,d in pairs(F)do defs[d.name]=id end
 local donors={{actor='space_marine',feature='40k_tactical_marine_corpse',unit='imp_marine'},
  {actor='ork_boy',feature='40k_shoota_boy_corpse',unit='ork_boy'}}
 for _,r in ipairs(donors)do r.def=defs[r.feature];r.unitDef=N[r.unit]and N[r.unit].id
  local cp=r.def and F[r.def].customParams or{}
  if not r.def or not r.unitDef or not U[r.unitDef]or(U[r.unitDef].customParams or{}).animsource~=r.actor
   or tostring(cp.prototype40k_tactical_remains)~='1'or cp.parent_actor~=r.actor then stop('FAIL genuine_existing_donor_definitions_required');return C end
 end
 local russ=N.imp_russ;local entry=russ and U[russ.id].weapons and U[russ.id].weapons[1];C.weapon=entry and entry.weaponDef
 local w=C.weapon and W[C.weapon]
 if not w or w.type~='Cannon'or w.noExplode or(w.damageAreaOfEffect or 0)<8 or(w.damageAreaOfEffect or 0)>64 then stop('FAIL bounded_genuine_native_cannon_required');return C end
 C.radius=w.damageAreaOfEffect
 local function tuple(fid)
  local m,dm,e,de,left,work=S.GetFeatureResources(fid)
  if not finite(m)or not finite(e)or not finite(dm)or not finite(de)or not finite(left)or not finite(work)then return end
  return{m,dm,e,de,left,work}
 end
 local function sum(ids)
  local m,e=0,0;for _,fid in ipairs(ids)do local r=tuple(fid);if not r then return end;m=m+r[1];e=e+r[3]end;return m,e
 end
 local function queue()
  local rows=S.GetUnitCommands(C.builder,128);if type(rows)~='table'then stop('FAIL native_reclaim_queue_unreadable');return{}end;return rows
 end
 local function direct(fid)
  for _,q in ipairs(queue())do if q.id==CMD.RECLAIM and q.params and #q.params==1 and q.params[1]==G.maxUnits+fid then return true end end;return false
 end
 local function area()
  for _,q in ipairs(queue())do local p=q.params;if q.id==CMD.RECLAIM and p and #p>=4 and finite(p[1])and finite(p[3])and math.abs(p[1]-C.x)<=.001 and math.abs(p[3]-C.z)<=.001 and p[4]==32 then return true end end;return false
 end
 local function order(command,params)
  if S.GiveOrderToUnit(C.builder,command,params,0)==false then return stop('FAIL native_order_rejected')end
 end
 local function seed(row,x,z,metal,energy)
  C.seeded=C.seeded+1
  local y=S.GetGroundHeight(x,z);local fid=S.CreateFeature(row.feature,x,y,z,0,0)
  if fid==nil or S.GetFeatureDefID(fid)~=row.def or owner.features[fid]then stop('FAIL unique_native_seed_feature_required');return end
  C.owned[#C.owned+1]=fid
  local r={actor=row.actor,def=row.unitDef,team=0,squad=0,slot=fid,generation=C.started+C.seeded,metal=metal,energy=energy,work=1024,diagnosticSeed=true}
  local key=r.squad..':'..r.slot..':'..r.generation
  if owner.entitlements[key]then stop('FAIL duplicate_diagnostic_seed');return end
  owner.entitlements[key]=true
  -- One initial allocation. Every later value is native reclaim or existing merge.
  S.SetFeatureResources(fid,metal,energy,1024,1,metal,energy)
  local actual=tuple(fid);if not actual or actual[1]~=metal or actual[3]~=energy or actual[5]~=1 then stop('FAIL seeded_native_resource_readback');return end
  for _,name in ipairs({'squad','slot','generation','metal','energy','work','team','def'})do S.SetFeatureRulesParam(fid,'40k_remains_'..name,r[name],{private=true})end
  S.SetFeatureRulesParam(fid,'40k_remains_version',1,{private=true});S.SetFeatureRulesParam(fid,'40k_remains_flying',0,{private=true})
  owner.features[fid]=r;assert(P.Observe(fid),'Existing owner seed observation refused')
  emit('SYNTHETIC_SEED fid='..fid..' actor='..r.actor..' metal='..metal..' energy='..energy..' initial_allocation_only=true paid_death=false')
  return fid
 end
 local function candidateSite()
  local x,y,z=S.GetUnitPosition(C.builder)
  for k=0,15 do local a=k*math.pi/8;local cx,cz=x+140*math.cos(a),z+140*math.sin(a);local cy=S.GetGroundHeight(cx,cz);local good=true
   if cx<240 or cz<100 or cx>G.mapSizeX-240 or cz>G.mapSizeZ-100 then good=false end
   if good then for dx=-160,160,16 do if math.abs(S.GetGroundHeight(cx+dx,cz)-cy)>.5 then good=false;break end end end
   if good and #(S.GetUnitsInCylinder(cx,cz,C.radius+32)or{})==0 and #(S.GetFeaturesInCylinder(cx,cz,64)or{})==0 then return cx,cy,cz end
  end
 end
 local function findPile()
  local found;for fid,row in pairs(owner.features)do if row.pile then
   if found then return nil,'multiple_piles'end;found=fid
  end end;return found
 end
 local function counts(fid,n)
  local row=owner.features[fid];if not row or not row.pile or type(row.counts)~='table'then return false end
  local count,kinds=0,0;for _,v in pairs(row.counts)do count=count+v;kinds=kinds+1 end
  return count==n and kinds==2 and row.counts['space_marine@0']==(n==6 and 3 or 4)and row.counts['ork_boy@0']==3
 end
 function C.BuildStep(id,team,fid,def,part)
  if C.closed or C.result then return end
  if id==C.builder and part<0 then C.lastWork=S.GetGameFrame();C.lastFeature=fid end
 end
 function C.FeatureDestroyed(fid)
  if fid==C.pile then C.destroyed=S.GetGameFrame()end
 end
 function C.Explosion(wd,x,y,z,own,pid)
  if wd==C.weapon and pid==C.blastPID then C.blastAt=S.GetGameFrame();emit('NATIVE_BLAST pid='..pid)end;return false
 end
 function C.Step(f)
  if C.result or C.closed then return C.result end
  if f-C.started>M.Timeout then return stop('INCONCLUSIVE bounded_native_pile_timeout_'..C.phase)end
  if C.builder and(S.GetUnitIsDead(C.builder)~=false or S.GetUnitTeam(C.builder)~=0)then return stop('FAIL original_native_builder_lost')end
  if C.phase=='wait'then
   if f<30 then return end
   local units=S.GetTeamUnits(0)or{};if #units~=1 or S.GetUnitDefID(units[1])~=N.corcom.id then return stop('FAIL sole_native_commander_required')end
   C.builder=units[1];if #queue()>0 then return stop('FAIL existing_user_orders')end
   C.x,C.y,C.z=candidateSite();if not C.x then return stop('INCONCLUSIVE no_flat_safe_reclaim_projectile_site')end
   C.ids={};for i=1,6 do C.ids[i]=seed(donors[(i-1)%2+1],C.x+(i-3.5)*2,C.z,32,64);if C.result then return C.result end end
   C.initialM,C.initialE=sum(C.ids);order(CMD.RECLAIM,{G.maxUnits+C.ids[1]});C.phase='partial'
  elseif C.phase=='partial'then
   local r=tuple(C.ids[1]);if not r then return stop('FAIL donor_disappeared_before_partial')end
   if r[1]<32 and r[3]<64 and r[1]>0 and r[3]>0 then
    if not direct(C.ids[1])then return stop('FAIL actual_direct_reclaim_order_not_observed')end
    local ok,why=P.Merge(C.ids,f);if ok then return stop('FAIL active_direct_reclaim_was_merged')end
    emit('DIRECT_RECLAIM_PROTECTED reason='..tostring(why)..' remaining_metal='..number(r[1])..' remaining_energy='..number(r[3]))
    order(CMD.STOP,{});order(CMD.RECLAIM,{C.x,C.y,C.z,32});C.areaAt=f;C.phase='area'
   end
  elseif C.phase=='area'then
   if f-C.areaAt>=15 then
    if not area()then return stop('FAIL actual_area_reclaim_order_not_observed')end
    local ok,why=P.Merge(C.ids,f);if ok then return stop('FAIL active_area_reclaim_was_merged')end
    emit('AREA_RECLAIM_PROTECTED reason='..tostring(why)..' native_area_queue=true')
    order(CMD.STOP,{});C.expectM,C.expectE=sum(C.ids)
    if not C.expectM or not(C.expectM<C.initialM and C.expectE<C.initialE and C.expectM>0 and C.expectE>0)then return stop('FAIL native_remaining_M_E_partial_witness_missing')end
    C.cancelAt=f;C.phase='merge';emit('REMAINING_NATIVE_SUM metal='..number(C.expectM)..' energy='..number(C.expectE)..' original_payout_not_used=true')
   end
  elseif C.phase=='merge'then
   local fid,why=findPile();if why then return stop('FAIL '..why)end
   if fid then
    local r=tuple(fid);if not r or r[1]~=C.expectM or r[3]~=C.expectE or not counts(fid,6)then return stop('FAIL exact_remaining_M_E_or_six_metadata_lost')end
    for _,id in ipairs(C.ids)do if S.GetFeatureDefID(id)then return end end
    C.pile=fid;local b,s,p,ray=S.GetFeatureBlocking(fid)
    if b~=false or s~=false or p~=false or ray~=false or S.GetFeatureNoSelect(fid)~=false then return stop('FAIL non_obstruction_or_stock_select_state')end
    local x,y,z=S.GetFeaturePosition(fid);C.px,C.py,C.pz=x,y,z
    local nativeRadius=S.GetFeatureRadius(fid);if not finite(nativeRadius)or nativeRadius<=0 then return stop('FAIL native_pile_radius_missing')end
    C.passageBeyond=math.max(32,nativeRadius+8)
    local pid=S.SpawnProjectile(C.weapon,{pos={x-120,y+1.5,z},speed={12,0,0},['end']={x+120,y+1.5,z},team=0,ttl=40,gravity=0})
    if pid==nil then return stop('INCONCLUSIVE native_projectile_refused')end;C.passagePID=pid;C.passageAt=f;C.phase='passage'
    emit('PILE_MERGE_EXACT fid='..fid..' metal='..number(r[1])..' energy='..number(r[3])..' logical_bodies=6 marine=3 ork=3 original_donors_absent=true')
    emit('PILE_NON_OBSTRUCTIVE fid='..fid..' blocking=false solid=false projectile=false ray=false noselect=false')
   elseif f-C.cancelAt>300 then return stop('INCONCLUSIVE no_exact_native_aggregate_after_cancel')end
  elseif C.phase=='passage'then
   local x,y,z=S.GetProjectilePosition(C.passagePID)
   if x and x>C.px+C.passageBeyond and math.abs(z-C.pz)<.5 and math.abs(y-(C.py+1.5))<.5 then
    emit('NATIVE_PROJECTILE_PASSED pid='..C.passagePID..' x='..number(x)..' pile_x='..number(C.px)..' beyond='..number(C.passageBeyond)..' y='..number(y)..' pile_y='..number(C.py)..' z='..number(z)..' pile_z='..number(C.pz)..' alive_beyond_pile=true')
    C.blastPID=S.SpawnProjectile(C.weapon,{pos={C.px,C.py+30,C.pz},speed={0,-2,0},['end']={C.px,C.py,C.pz},team=0,ttl=60,gravity=0})
    if C.blastPID==nil then return stop('INCONCLUSIVE native_blast_projectile_refused')end;C.blastStart=f;C.phase='blast'
   elseif f-C.passageAt>30 then return stop('FAIL no_live_native_projectile_beyond_pile')end
  elseif C.phase=='blast'then
   if C.blastAt and f-C.blastAt>=15 then
    local r=tuple(C.pile);if not r or r[1]~=C.expectM or r[3]~=C.expectE then return stop('FAIL native_blast_erased_salvage')end
    emit('NATIVE_BLAST_SURVIVED fid='..C.pile..' metal='..number(r[1])..' energy='..number(r[3])..' explosion_frame='..C.blastAt)
    C.newDonor=seed(donors[1],C.px+4,C.pz+4,8,16);if C.result then return C.result end
    C.expectM=C.expectM+8;C.expectE=C.expectE+16;C.newAt=f;C.phase='remerge'
   elseif f-C.blastStart>90 then return stop('FAIL native_blast_explosion_not_witnessed')end
  elseif C.phase=='remerge'then
   local fid,why=findPile();if why then return stop('FAIL '..why)end
   if fid and fid~=C.pile then
    local r=tuple(fid);if not r or r[1]~=C.expectM or r[3]~=C.expectE or not counts(fid,7)then return stop('FAIL remerge_M_E_or_seven_counts')end
    if S.GetFeatureDefID(C.pile)or S.GetFeatureDefID(C.newDonor)then return end
    emit('PILE_REMERGE_EXACT fid='..fid..' previous='..C.pile..' donor='..C.newDonor..' metal='..number(r[1])..' energy='..number(r[3])..' logical_bodies=7 marine=4 ork=3 prior_pile_and_donor_absent=true')
    C.pile=fid;C.destroyed=nil;C.lastWork=nil;C.lastFeature=nil;C.fullPartial=nil
    order(CMD.RECLAIM,{G.maxUnits+fid});C.phase='full';C.fullStart=f
   elseif f-C.newAt>300 then return stop('INCONCLUSIVE no_new_donor_remerge')end
  elseif C.phase=='full'then
   if S.GetFeatureDefID(C.pile)==nil then
    if not C.destroyed or not C.lastWork or C.destroyed<C.lastWork or C.destroyed-C.lastWork>1 or C.lastFeature~=C.pile or not C.fullPartial then return stop('FAIL disappearance_not_native_partial_full_reclaim')end
    emit('NATIVE_RECLAIM_CONSUMED fid='..C.pile..' builder='..C.builder..' destroyed_frame='..C.destroyed..' work_frame='..C.lastWork..' current_feature_absent=true')
    C.doneAt=f;C.phase='settled'
   else
    local r=tuple(C.pile);if not r or r[1]>C.expectM or r[3]>C.expectE then return stop('FAIL reclaim_currency_increase')end
    if r[1]>0 and r[1]<C.expectM and r[3]>0 and r[3]<C.expectE then
     if not C.fullPartial then emit('NATIVE_FULL_RECLAIM_PARTIAL fid='..C.pile..' metal='..number(r[1])..' energy='..number(r[3])..' native_order=true')end
     C.fullPartial=true
    end
   end
  elseif C.phase=='settled'and f-C.doneAt>=30 then
   if findPile()or owner.features[C.pile]then return stop('FAIL aggregate_reappeared_after_consumption')end
   emit('NATIVE_RECLAIM_SETTLED fid='..C.pile..' elapsed='..(f-C.doneAt)..' owner_absent=true no_replacement=true')
   emit('PASS remaining_M_AND_E_partial_merge_remerge_full_native_reclaim projectile_passage blast_survival active_direct_area_orders metadata7 funded_seed_only=true paid_death=false economy_acceptance=false')
   return stop('PASS native_pile_functional_conservation')
  end
  return C.result
 end
 return C
end
return M
