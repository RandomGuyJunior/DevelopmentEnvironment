-- Source-owned Stormboy cohort jump; chosen deterministic native combat adaptation.
local M={entity='attrib/ebps/races/orks/troops/ork_stormboy.lua',command=34573,SourceSHA='0d6336baa612f2df6dfba903c69190a5a1d9111eb451e73837957f5313c8c5bd',EnableSHA='90087a51a5fbfe4d0967760015ea0267e80a4fe7d464de27e3a076a7f028a4a6'}
function M.Supported(c)
 if type(c)~='table'or c.source_squad~='attrib/sbps/races/orks/ork_squad_stormboy.lua'or c.source_sha256~=M.SourceSHA or type(c.fields)~='table'then return false end
 local expected={charge_max=90,charge_starting_fraction=1,charge_jump_cost_min=45,charge_jump_cost_max=45,charge_regeneration=1,jump_distance_max=70,jump_time_max=2.5,setup_time=.4329999983,breakdown_time=.7699999809,combat_enabled=true}
 for key,value in pairs(expected)do if c.fields['squad_jump_ext.'..key]~=value then return false end end
 return c.fields['squad_loadout_ext.unit_min']==4 and c.fields['squad_loadout_ext.unit_max']==8
end
function M.Enabled(o)return VFS.Include('40k_configs/development_playtest.lua').OptionEnabled(o.prototype_source_progression)and o.prototype_diagnostic=='expandedproduction'and tostring(o.prototype_ork_source_consumers_review)=='1'and tostring(o.prototype_ork_stormboy_jump_review)=='1'end
function M.Config(fps)return{range=700,flight=math.ceil(2.5*fps),launch=math.ceil(.4329999983*fps),land=math.ceil(.7699999809*fps),capacity=90*fps,cost=45*fps,regen=1,maxStep=6,stormboy=true}end
function M.New(S,D,fps,G,H)
 local R={groups={},budgets={},blocked={}};local Native=VFS.Include('40k_configs/primary_variant_native.lua');local savedKey='40k_ork_jump_snapshot_v1'
 local function cohort(id)
  local c=GG.Recoil40KResearch;local life=c and c.sourceOrkLifecycle
  if not life or not life.ledger then return nil end
  local seed=S.GetUnitRulesParam(id,'40k_ork_cohort_seed');local row=seed and life.ledger.Snapshot().cohorts[seed]
  if not row or not life.ledger.Capacity(seed)then return nil end
  local has=false;for _,member in ipairs(row.ids)do local d=D[S.GetUnitDefID(member)];local _,_,_,_,progress=S.GetUnitHealth(member)
   if not d or d.canAttack~=true or(d.customParams or{}).source_entity~=M.entity or tostring((d.customParams or{}).source_stormboy_jump)~='1'or S.GetUnitTeam(member)~=row.team or not progress or progress<1 then return nil end
   if member==id then has=true end
  end
  if not has then return nil end;return seed,row
 end
 local function stamp(seed,row,b)
  for _,id in ipairs(row.ids)do S.SetUnitRulesParam(id,'40k_ork_jump_owner',row.team,{private=true});S.SetUnitRulesParam(id,'40k_ork_jump_budget',b.charge,{private=true});S.SetUnitRulesParam(id,'40k_ork_jump_frame',b.frame,{private=true});S.SetUnitRulesParam(id,'40k_jump_charge',b.charge/fps,{allied=true})end
 end
 local function budget(seed,row,now)
  if R.blocked[seed]then return nil end
  local b=R.budgets[seed]
  if not b then
   local minimum,last
   for _,id in ipairs(row.ids)do local v=S.GetUnitRulesParam(id,'40k_ork_jump_budget');local at=S.GetUnitRulesParam(id,'40k_ork_jump_frame');local team=S.GetUnitRulesParam(id,'40k_ork_jump_owner')
    if v~=nil or at~=nil or team~=nil then
     if not G.Finite(v)or v%1~=0 or v<0 or v>90*fps or not G.Finite(at)or at%1~=0 or at<0 or at>now or team~=row.team then R.blocked[seed]=true;return nil end
     if minimum==nil or v<minimum then minimum,last=v,at elseif v==minimum then last=math.max(last,at)end
    end
   end
   b={charge=minimum or 90*fps,frame=last or now,team=row.team};R.budgets[seed]=b
  end
  if b.team~=row.team or now<b.frame then return nil end
  b.charge=math.min(90*fps,b.charge+now-b.frame);b.frame=now;stamp(seed,row,b);return b
 end
 function R.Allowed(id)if R.failed then return false end;local seed,row=cohort(id);return seed and budget(seed,row,S.GetGameFrame())~=nil or false end
 function R.Start(id,params,tag,now)
  if R.failed then return false end
  local seed,row=cohort(id);if not seed or R.groups[seed]then return false end
  local b=budget(seed,row,now);if not b then return false end
  local ax,ay,az=S.GetUnitPosition(id);if not G.Finite(ax)or not G.Finite(params[1])or not G.Finite(params[3])then return false end
  local prepared={};local group={seed=seed,team=row.team,leader=id,tag=tag,ids=row.ids,heads={},landed={},target={params[1],S.GetGroundHeight(params[1],params[3]),params[3]}}
  for _,member in ipairs(row.ids)do
   local x,y,z=S.GetUnitPosition(member);local p={params[1]+x-ax,0,params[3]+z-az};local s=H.Prepare(member,p)
   if not s then return false end;prepared[member]=s
   local cmd,_,head=S.GetUnitCurrentCommand(member);group.heads[member]={cmd=cmd,tag=head}
  end
  if b.charge<45*fps then return nil end
  -- All source members and every complete swept route passed before any motion.
  b.charge=b.charge-45*fps;stamp(seed,row,b);R.groups[seed]=group
  for _,member in ipairs(row.ids)do local s=prepared[member];s.sourceGroup=seed;s.sourceLeader=member==id
   local memberTag=group.heads[member].cmd==M.command and group.heads[member].tag or nil
   if not H.Begin(member,s,memberTag,now,true)then group.aborted=true;return false end
  end
  return true
 end
 function R.Valid(s)
  if R.failed then return false end
  local group=R.groups[s.sourceGroup];if not group or group.aborted or type(group.ids)~='table'or type(group.heads)~='table'or not group.leader then return false end
  local seed,row=cohort(group.leader);if seed~=group.seed or #row.ids~=#group.ids then group.aborted=true;return false end
  for n,id in ipairs(group.ids)do
   if row.ids[n]~=id then group.aborted=true;return false end
   local stunned,inbuild=S.GetUnitIsStunned(id);local cmd,_,tag=S.GetUnitCurrentCommand(id);local head=group.heads[id]
   if not(group.finished and group.finished[id])and(not S.MoveCtrl.IsEnabled(id)or S.MoveCtrl.GetTag(id)~=G.Tag)then group.aborted=true;return false end
   if not head or stunned or inbuild or S.GetUnitTransporter(id)~=nil or cmd~=head.cmd or tag~=head.tag then group.aborted=true;return false end
  end
  return true
 end
 local function pulse(group)
  local candidates=S.GetUnitsInSphere(group.target[1],group.target[2],group.target[3],70);table.sort(candidates)
  for _,victim in ipairs(candidates)do
   -- Probability1 source effect; recheck source authority for every real victim.
   if not R.Valid{sourceGroup=group.seed}then return end
   local team=S.GetUnitTeam(victim);local d=D[S.GetUnitDefID(victim)];local cp=d and d.customParams or{};local path=cp.source_entity
   if team~=nil and not S.AreTeamsAllied(team,group.team)and type(path)=='string'and path:find('attrib/ebps/races/',1,true)==1 and victim~=group.leader and G.Finite(d.mass)and d.mass>0 then
    -- Authored native health damage; no source armour-type matrix.
    local damage=105
    S.AddUnitDamage(victim,damage,0,group.leader,-1)
    if not R.Valid{sourceGroup=group.seed}then return end
    if S.ValidUnitID(victim)and not S.GetUnitIsDead(victim)then
     S.AddUnitDamage(victim,45,.7699999809,group.leader,-1)
     if not R.Valid{sourceGroup=group.seed}then return end
     local x,y,z=S.GetUnitPosition(victim);local dx,dz=x-group.target[1],z-group.target[3];local length=math.sqrt(dx*dx+dz*dz);if length==0 then dx,dz,length=1,0,1 end
     -- Source midpoint35force/30degrees: velocity impulse adaptation10elmos/source/second.
     local mass=d.mass;local v=35*10/fps;S.AddUnitImpulse(victim,mass*v*math.cos(math.pi/6)*dx/length,mass*v*.5,mass*v*math.cos(math.pi/6)*dz/length)
    end
   end
  end
 end
 function R.Landed(id,s)
  local group=R.groups[s.sourceGroup];if not group or s.aborting or not R.Valid(s)then if group then group.aborted=true end;return end
  group.landed[id]=true;for _,member in ipairs(group.ids)do if not group.landed[member]then return end end
  if not group.pulsed then group.pulsed=true;pulse(group)end
 end
 function R.Finished(id,s)
  local group=R.groups[s.sourceGroup];if not group then return end;group.finished=group.finished or{};group.finished[id]=true
  for _,member in ipairs(group.ids)do if not group.finished[member]and S.ValidUnitID(member)and not S.GetUnitIsDead(member)then return end end;R.groups[s.sourceGroup]=nil
 end
 function R.Removed(id)
  for seed,g in pairs(R.groups)do for _,member in ipairs(g.ids)do if id==member then g.aborted=true;g.finished=g.finished or{};g.finished[id]=true end end end
 end
 function R.Frame(now)
  local c=GG.Recoil40KResearch;local life=c and c.sourceOrkLifecycle
  if life then local live=life.ledger.Snapshot().cohorts
   for seed in pairs(R.budgets)do if not live[seed]then R.budgets[seed]=nil;R.blocked[seed]=nil end end
   for seed,row in pairs(live)do if row.ids[1]and cohort(row.ids[1])then budget(seed,row,now)end end
  end
 end
 function R.Save(states)
  local own={};for id,s in pairs(states)do if s.sourceGroup then own[id]=s end end
  local text=Native.Encode{version=1,groups=R.groups,states=own};if text~=R.lastSave then S.SetGameRulesParam(savedKey,text,{private=true});if S.GetGameRulesParam(savedKey)~=text then R.failed=true end;R.lastSave=text end
 end
 function R.Restore(states)
  local text=S.GetGameRulesParam(savedKey);if text==nil then return true end;local saved=Native.Decode(text)
  if type(saved)~='table'or saved.version~=1 or type(saved.groups)~='table'or type(saved.states)~='table'then R.failed=true;return false end
  local function point(p)return type(p)=='table'and G.Finite(p[1])and G.Finite(p[2])and G.Finite(p[3])end
  local claimed={}
  for seed,g in pairs(saved.groups)do
   if type(seed)~='number'or type(g)~='table'or g.seed~=seed or type(g.ids)~='table'or #g.ids<1 or #g.ids>10 or type(g.heads)~='table'or type(g.landed)~='table'or not point(g.target)then R.failed=true;return false end
   for _,id in ipairs(g.ids)do if type(id)~='number'or claimed[id]or type(g.heads[id])~='table'then R.failed=true;return false end;claimed[id]=seed end
  end
  local currentConfig=M.Config(fps)
  for id,s in pairs(saved.states)do
   if type(s)~='table'or claimed[id]~=s.sourceGroup or not point(s.a)or not point(s.b)or not point(s.position)or type(s.history)~='table'or #s.history>currentConfig.flight+2 or not G.Finite(s.stageStart)or s.stageStart<0 or s.stageStart>S.GetGameFrame()or not G.Finite(s.flightFrames)or s.flightFrames<10 or s.flightFrames>currentConfig.flight or not G.Finite(s.height)or s.height<64 or s.height>128 or type(s.config)~='table'or(s.stage~='launch'and s.stage~='air'and s.stage~='land')then R.failed=true;return false end
   for key,value in pairs(currentConfig)do if s.config[key]~=value then R.failed=true;return false end end
   for _,p in ipairs(s.history)do if not point(p)then R.failed=true;return false end end
  end
  local previous=R.groups;R.groups=saved.groups
  for id,s in pairs(saved.states)do
   local x,y,z=S.GetUnitPosition(id);local g=R.groups[s.sourceGroup];local d=D[S.GetUnitDefID(id)]
   if not g or s.sourceLeader~=(id==g.leader)or s.commandTag~=(g.heads[id].cmd==M.command and g.heads[id].tag or nil)or not d or(d.customParams or{}).source_entity~=M.entity or tostring((d.customParams or{}).source_stormboy_jump)~='1'or not G.Finite(x)or type(s)~='table'or not s.sourceGroup or not S.MoveCtrl.IsEnabled(id)or S.MoveCtrl.GetTag(id)~=G.Tag or type(s.position)~='table'or G.Distance({x,y,z},s.position)>.1 or math.abs(y-s.position[2])>.1 then R.groups=previous;R.failed=true;return false end
  end
  for id,s in pairs(saved.states)do if not R.Valid(s)then s.aborting=true;R.groups[s.sourceGroup].aborted=true end;states[id]=s end;R.lastSave=text;return true
 end
 return R
end
return M
