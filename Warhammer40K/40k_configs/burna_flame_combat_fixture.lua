-- Funded native production/combat only. Ordinary paid fixture is independent.
local M={Version=1,Option='prototype_burna_flame_combat',Actor='ork_burna',Profile=18,MapName="Martyr's Gate 0.1"}
-- Exact pinned BAR processWeapons frame rounding of authored burstrate=.15 at30Hz.
local BURST_FRAMES=math.max(1,math.floor((.15+1e-3)*30))
local BURST_SECONDS=BURST_FRAMES/30
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function int(v,min)return finite(v)and v%1==0 and v>=(min or 0)and v<=2147483647 end
-- Read-only bounded metadata on the unchanged profile admission refusal only.
local function admissionToken(v)
 local k=type(v)
 if k=='nil'then return'nil~unavailable'end
 if k=='boolean'then return'boolean~'..tostring(v)end
 if k=='number'then
  if v~=v then return'number~nan'end
  if v==math.huge then return'number~positive_infinity'end
  if v==-math.huge then return'number~negative_infinity'end
  return'number~'..string.format('%.17g',v)
 end
 if k=='string'then
  local prefix=v:sub(1,96);local hex=prefix:gsub('.',function(c)return string.format('%02x',string.byte(c))end)
  return'string~'..#v..'~'..hex..'~'..(#v>96 and'truncated'or'complete')
 end
 return k..'~unserialized'
end
local function admissionNumber(v,expected)
 return(type(v)=='number'or type(v)=='string')and tonumber(v)==expected or false
end
local function admissionObserve(log,product,member,d,md,factory,menu)
 if type(log)~='function'then return end
 local function readFields(owner,keys)
  local out={};local readable=true
  for _,key in ipairs(keys)do
   local ok,value=false,nil
   if type(owner)=='table'or type(owner)=='userdata'then ok,value=pcall(function()return owner[key]end)end
   readable=readable and ok;if ok then out[key]=value end
  end
  return out,readable
 end
 local dKind,mdKind,fKind=type(d),type(md),type(factory)
 local dReadable,mdReadable,fReadable
 d,dReadable=readFields(d,{'customParams','scriptName','metalCost','energyCost','buildTime'})
 md,mdReadable=readFields(md,{'customParams','scriptName','metalCost','energyCost','buildTime'})
 factory,fReadable=readFields(factory,{'isFactory','buildOptions','xsize','zsize'})
 local cpKind,mcpKind=type(d.customParams),type(md.customParams)
 local cp,cpReadable=readFields(d.customParams,{'prototype40k_squad_profile_id','prototype40k_squad_capacity','prototype40k_squad_product','animsource'})
 local mcp,mcpReadable=readFields(md.customParams,{'prototype40k_squad_profile_id','prototype40k_squad_internal','animsource'})
 local function row(kind,...)
  log(kind,'schema=1','stage=before_admission_setup','observation_only=true','native_accepted=false','render_accepted=false',...)
 end
 local function field(key,value)return key..'='..admissionToken(value)end
 row('ADMISSION_PRODUCT',field('definition',product),field('unitdef_type',dKind),field('unitdef_readable',dReadable),field('customparams_type',cpKind),field('customparams_readable',cpReadable),field('profile',cp.prototype40k_squad_profile_id),field('capacity',cp.prototype40k_squad_capacity),field('product',cp.prototype40k_squad_product),field('script_name',d.scriptName),field('animsource',cp.animsource),field('metal',d.metalCost),field('energy',d.energyCost),field('work',d.buildTime))
 row('ADMISSION_PRODUCT_COMPARE',field('profile_ok',admissionNumber(cp.prototype40k_squad_profile_id,18)),field('capacity_ok',admissionNumber(cp.prototype40k_squad_capacity,4)),field('product_ok',cp.prototype40k_squad_product=='ork_burna'),field('script_ok',d.scriptName=='scripts/40k_roster.lua'),field('animsource_ok',cp.animsource=='ork_burna'),field('metal_ok',d.metalCost==88),field('energy_ok',d.energyCost==440),field('work_ok',d.buildTime==1056))
 row('ADMISSION_MEMBER',field('definition',member),field('unitdef_type',mdKind),field('unitdef_readable',mdReadable),field('customparams_type',mcpKind),field('customparams_readable',mcpReadable),field('profile',mcp.prototype40k_squad_profile_id),field('internal',mcp.prototype40k_squad_internal),field('script_name',md.scriptName),field('animsource',mcp.animsource),field('metal',md.metalCost),field('energy',md.energyCost),field('work',md.buildTime))
 row('ADMISSION_MEMBER_COMPARE',field('profile_ok',admissionNumber(mcp.prototype40k_squad_profile_id,18)),field('internal_ok',admissionNumber(mcp.prototype40k_squad_internal,1)),field('script_equal_ok',md.scriptName==d.scriptName),field('animsource_ok',mcp.animsource=='ork_burna'),field('metal_ok',md.metalCost==22),field('energy_ok',md.energyCost==110),field('work_ok',md.buildTime==264))
 local raw=factory.buildOptions;local entries=type(raw)=='table'and raw or{};local count=0
 while count<64 and entries[count+1]~=nil do count=count+1 end
 row('ADMISSION_FACTORY',field('unitdef_type',fKind),field('unitdef_readable',fReadable),field('is_factory',factory.isFactory),field('is_factory_ok',factory.isFactory==true),field('build_options',raw),field('menu_contains_product',menu),field('prefix_entries',count),field('prefix_truncated',count==64 and entries[65]~=nil),field('xsize',factory.xsize),field('zsize',factory.zsize))
 for first=1,count,8 do
  local fields={field('first_index',first)}
  for index=first,math.min(first+7,count)do fields[#fields+1]=field('entry_'..index,entries[index])end
  row('ADMISSION_MENU',unpack(fields))
 end
end
-- Read-only bounded metadata on the unchanged native mount refusal only.
local function mountObserve(log,product,member,d,md,W)
 local function read(owner,key)
  if type(owner)~='table'and type(owner)~='userdata'then return nil,false end
  local ok,value=pcall(function()return owner[key]end);if ok then return value,true end;return nil,false
 end
 local function field(key,value)return key..'='..admissionToken(value)end
 local function row(kind,definition,owner)
  local mounts,readable=read(owner,'weapons');local count
  local lengthOK,length=pcall(function()return #(mounts or{})end);if lengthOK then count=length end
  local first,firstReadable=read(mounts,1);local weapon,weaponReadable=read(first,'weaponDef')
  local wd,wdReadable=read(W,weapon);local name,nameReadable=read(wd,'name')
  log(kind,'schema=1','stage=before_mount_setup','observation_only=true','native_accepted=false','render_accepted=false',field('definition',definition),field('weapons_type',type(mounts)),field('weapons_readable',readable),field('count_readable',lengthOK),field('count',count),field('first_type',type(first)),field('first_readable',firstReadable),field('weapon_def_readable',weaponReadable),field('weapon_def',weapon),field('weapon_type',type(wd)),field('weapon_readable',wdReadable),field('weapon_name_readable',nameReadable),field('weapon_name',name))
  return count,weapon
 end
 local count,weapon=row('MOUNT_PRODUCT',product,d)
 local memberCount,memberWeapon=row('MOUNT_MEMBER',member,md)
 log('MOUNT_COMPARE','schema=1','stage=before_mount_setup','observation_only=true','native_accepted=false','render_accepted=false',field('product_single_ok',count==1),field('member_single_ok',memberCount==1),field('weapon_equal_ok',weapon==memberWeapon))
end
-- Read-only bounded values for both bodies before the native weapon contract gate.
local function weaponContractObserve(log,product,member,weapons,W,gameSpeed)
 local function read(owner,key)
  if type(owner)~='table'and type(owner)~='userdata'then return nil,false end
  local ok,value=pcall(function()return owner[key]end);if ok then return value,true end;return nil,false
 end
 local function field(key,value)return key..'='..admissionToken(value)end
 local function row(kind,...)
  log(kind,'schema=1','stage=before_weapon_setup','observation_only=true','native_accepted=false','render_accepted=false',...)
 end
 for _,body in ipairs({{definition=product,kind='PRODUCT',name='ork_burna_mount1'},{definition=member,kind='MEMBER',name='ork_burna_member_mount1'}})do
  local weapon,weaponReadable=read(weapons,body.definition);local wd,wdReadable=read(W,weapon)
  local values,readable={},{}
  for _,key in ipairs({'name','type','range','salvoSize','salvoDelay','reload','customParams'})do values[key],readable[key]=read(wd,key)end
  local muzzle,muzzleReadable=read(values.customParams,'source_muzzle');local clip,clipReadable=read(values.customParams,'source_fireclip')
  row('WEAPON_CONTRACT_'..body.kind,field('definition',body.definition),field('weapon_def',weapon),field('weapon_def_readable',weaponReadable),field('weapon_type',type(wd)),field('weapon_readable',wdReadable),field('game_speed',gameSpeed),field('name',values.name),field('name_readable',readable.name),field('type',values.type),field('type_readable',readable.type),field('range',values.range),field('range_readable',readable.range),field('salvo_size',values.salvoSize),field('salvo_size_readable',readable.salvoSize),field('salvo_delay',values.salvoDelay),field('salvo_delay_readable',readable.salvoDelay),field('reload',values.reload),field('reload_readable',readable.reload),field('customparams_type',type(values.customParams)),field('customparams_readable',readable.customParams),field('source_muzzle',muzzle),field('source_muzzle_readable',muzzleReadable),field('source_fireclip',clip),field('source_fireclip_readable',clipReadable))
  row('WEAPON_CONTRACT_'..body.kind..'_COMPARE',field('weapon_id_ok',int(weapon)),field('weapon_present_ok',not not wd),field('expected_name',body.name),field('name_ok',values.name==body.name),field('type_ok',values.type=='Flame'),field('range_ok',values.range==130),field('salvo_size_ok',values.salvoSize==4),field('salvo_delay_finite',finite(values.salvoDelay)),field('salvo_delay_ok',finite(values.salvoDelay)and math.abs(values.salvoDelay-BURST_SECONDS)<=.0001),field('reload_finite',finite(values.reload)),field('reload_ok',finite(values.reload)and math.abs(values.reload-1.2)<=.0001),field('source_muzzle_ok',muzzle=='marker_boyz_burna_barrel'),field('source_fireclip_ok',clip=='fire'))
 end
end
function M.New(S,D,N,W,G,Script,Game,emit)
 local C={phase='initial',births={},finishes={},owned={},slots={},projectiles={},serial=0,candidate=0,started=1}
 local function log(e,...)if type(emit)~='function'then return end;local a={...};a[#a+1]='funded_non_economy=true';a[#a+1]='own_factory_product_and_hostile_funded=true';a[#a+1]='paid_economy_accepted=false';emit(e,unpack(a))end
 local function live(id,def,team,complete)
  if not int(id)or S.ValidUnitID(id)~=true or S.GetUnitIsDead(id)~=false or S.GetUnitDefID(id)~=def or S.GetUnitTeam(id)~=team then return false end
  local h,max,_,_,p=S.GetUnitHealth(id);return finite(h)and h>0 and finite(max)and max>0 and(complete==false or p==1)
 end
 local function terminal()
  if C.terminalLogged or not C.result then return end
  C.terminalLogged=true
  log('COMPLETE',C.result,'native_accepted=false','render_accepted=false')
 end
 local function close()
  if C.closed then return end
  -- TELEMETRY_ONLY_CLOSE_BEGIN
  if C.commanderDef then
   for id,row in pairs(C.initialGaia)do log('INITIAL_GAIA_PRESERVED','actor='..id,'def='..row.def,'team='..row.team,
    'native_alive='..tostring(live(id,row.def,row.team)),'neutral='..tostring(S.GetUnitNeutral(id)==true),'reviewed='..tostring(S.GetUnitRulesParam(id,'40k_relic_reviewed')==1),
    'unowned='..tostring(C.owned[id]==nil),'stage=before_owned_cleanup')end
   log('INITIAL_PRESERVED','actor='..C.initialEnemy,'def='..C.initialEnemyDef,'team=1','native_alive='..tostring(live(C.initialEnemy,C.initialEnemyDef,1)),'unowned='..tostring(C.owned[C.initialEnemy]==nil),'stage=before_owned_cleanup')
   local r=G.Recoil40KSquads;local squad=C.leader and type(r)=='table'and type(r.Get)=='function'and r.Get(C.leader);local all=true;local count=0
   for slot=1,4 do local q=C.slots[slot];if q then
    count=count+1;local bound=type(squad)=='table'and squad.profile=='ork_burna'and squad.team==0 and squad.leader==C.leader and type(squad.slots)=='table'and squad.slots[slot]==q.id
    local gen=bound and type(squad.generations)=='table'and squad.generations[slot]
    local identity=S.ValidUnitID(q.id)==true and S.GetUnitDefID(q.id)==q.def and S.GetUnitTeam(q.id)==0
    local alive=identity and S.GetUnitIsDead(q.id)==false;local _,_,_,_,progress=S.GetUnitHealth(q.id)
    all=all and gen==1 and alive and progress==1
    log('BODY_LIVE','slot='..slot,'actor='..q.id,'def='..q.def,'team=0','generation='..tostring(gen or 'unavailable'),'native_complete='..tostring(progress==1),'native_alive='..tostring(alive),'original_identity='..tostring(identity))
   else all=false end end
   log('CLOSING_LIVE','commander='..tostring(C.commander),'commander_def='..C.commanderDef,'commander_alive='..tostring(live(C.commander,C.commanderDef,0)),'factory='..tostring(C.factory or 'unavailable'),'factory_def='..C.factoryDef,'factory_alive='..tostring(C.factory~=nil and live(C.factory,C.factoryDef,0)),'leader='..tostring(C.leader or 'unavailable'),'hostile='..tostring(C.target or 'unavailable'),'enemy='..C.enemy,'all4_generation1='..tostring(all and count==4),'stage=before_owned_cleanup')
  end
  -- TELEMETRY_ONLY_CLOSE_END
  C.closed=true
  -- Log terminal after live-actor observations, before owned cleanup callbacks.
  terminal()
  if type(G)=='table'and G.Recoil40KStompaWeaponWitness==C then G.Recoil40KStompaWeaponWitness=nil end
  for weapon in pairs(C.watched or{})do Script.SetWatchProjectile(weapon,false)end
  for id,row in pairs(C.owned)do if not row.retired then
   row.retired=true
   if live(id,row.def,row.team,false)then S.DestroyUnit(id,false,true)
   else log('CLEANUP_PRESERVED','id='..id,'lost_captured_or_replaced_identity=true')end
  end end
 end
 local function finish(state,why)if not C.result then C.result=state..' '..why;close();terminal()end;return C.result end
 local function fail(why)return finish('FAIL',why)end
 local function inconclusive(why)return finish('INCONCLUSIVE',why)end
 function C.Frame()end;function C.Created()end;function C.Finished()end;function C.Released()end;function C.Query()end;function C.Shot()end;function C.Projectile()end;function C.Damaged()end;function C.Destroyed()end;C.Close=close
 if type(S)~='table'or type(D)~='table'or type(N)~='table'or type(W)~='table'or type(G)~='table'or type(Script)~='table'or type(Game)~='table'or type(emit)~='function'then fail('typed_actual_context_required');return C end
 if Game.mapName~=M.MapName or Game.mapSizeX~=4096 or Game.mapSizeZ~=4096 then fail('exclusive_approved_flat_map_required');return C end
 for _,name in ipairs({'GetFeaturePosition','GetGroundNormal','SetUnitPosition','GetUnitCollisionVolumeData','GetUnitExperience','GetUnitTransporter','GetGameFrame','GetAllUnits','ValidUnitID','GetUnitIsDead','GetUnitDefID','GetUnitTeam','GetUnitHealth','GetUnitCosts','GetUnitPosition','GetUnitPieceMap','GetUnitPiecePosDir','GetUnitWeaponVectors','GetUnitWeaponState','GetUnitWeaponTestTarget','GetUnitWeaponTestRange','GetUnitWeaponTryTarget','GetUnitWeaponHaveFreeLineOfFire','GetProjectilePosition','GetUnitAllyTeam','GetUnitLosState','GetGroundHeight','GetUnitsInRectangle','GetFeaturesInRectangle','TestBuildOrder','TestMoveOrder','GetFactoryCommands','GiveOrderToUnit','GetTeamList','GetTeamInfo','GetGaiaTeamID','GetUnitNeutral','GetUnitRulesParam','AreTeamsAllied','SetTeamResource','CreateUnit','DestroyUnit'})do if type(S[name])~='function'then fail('actual_native_API_missing_'..name);return C end end
 if type(Script.SetWatchProjectile)~='function'or not finite(Game.mapSizeX)or not finite(Game.mapSizeZ)or Game.gameSpeed~=30 or S.GetGameFrame()~=1 then fail('fresh_native30_frame1_required');return C end
 for key in pairs({ork_big_mek_commander=true,imp_field_commander=true,['40k_relic_objective']=true,ork_boyz_hut_t2=true,ork_burna=true,ork_burna_member=true,imp_russ=true})do if not N[key]or not int(N[key].id,1)or not D[N[key].id]then fail('actual_definition_required_'..key);return C end end
 C.product=N.ork_burna.id;C.member=N.ork_burna_member.id;C.factoryDef=N.ork_boyz_hut_t2.id;C.targetDef=N.imp_russ.id
 local d=D[C.product];local cp=d.customParams or{};local md=D[C.member];local mcp=md.customParams or{}
 local factory=D[C.factoryDef];local menu=false;for _,id in ipairs(factory.buildOptions or{})do menu=menu or id==C.product end
 if not int(factory.xsize,1)or not int(factory.zsize,1)or not int(D[C.targetDef].xsize,1)or not int(D[C.targetDef].zsize,1)then fail('actual_native_factory_target_dimensions_required');return C end
 if tonumber(cp.prototype40k_squad_profile_id)~=18 or tonumber(cp.prototype40k_squad_capacity)~=4 or cp.prototype40k_squad_product~='ork_burna'or tonumber(mcp.prototype40k_squad_profile_id)~=18 or tonumber(mcp.prototype40k_squad_internal)~=1 or d.scriptName~='scripts/40k_roster.lua'or md.scriptName~=d.scriptName or cp.animsource~='ork_burna'or mcp.animsource~='ork_burna'or d.metalCost~=88 or d.energyCost~=440 or d.buildTime~=1056 or md.metalCost~=22 or md.energyCost~=110 or md.buildTime~=264 or factory.isFactory~=true or not menu then local observed,reason=pcall(admissionObserve,log,C.product,C.member,d,md,factory,menu);if not observed then log('ADMISSION_UNAVAILABLE','schema=1','stage=before_admission_setup','reason='..admissionToken(reason),'observation_only=true','native_accepted=false')end;fail('actual_profile18_full4_native_BoyzHut_contract');return C end
 if #(d.weapons or{})~=1 or #(md.weapons or{})~=1 then local observed,reason=pcall(mountObserve,log,C.product,C.member,d,md,W);if not observed then log('MOUNT_UNAVAILABLE','schema=1','stage=before_mount_setup','reason='..admissionToken(reason),'observation_only=true','native_accepted=false')end;fail('genuine_single_Flame_mount_per_body_required');return C end
 -- BAR names each copied inline mount for its actual body definition. Native IDs need not match.
 C.weapons={[C.product]=d.weapons[1].weaponDef,[C.member]=md.weapons[1].weaponDef}
 local observed,reason=pcall(weaponContractObserve,log,C.product,C.member,C.weapons,W,Game.gameSpeed);if not observed then log('WEAPON_CONTRACT_UNAVAILABLE','schema=1','stage=before_weapon_setup','reason='..admissionToken(reason),'observation_only=true','native_accepted=false')end
 for _,definition in ipairs({C.product,C.member})do
  local weapon=C.weapons[definition];local wd=int(weapon)and W[weapon];local wcp=wd and wd.customParams or{}
  local name=definition==C.product and 'ork_burna_mount1'or 'ork_burna_member_mount1'
  if not wd or wd.name~=name or wd.type~='Flame'or wd.range~=130 or wd.salvoSize~=4 or not finite(wd.salvoDelay)or math.abs(wd.salvoDelay-BURST_SECONDS)>.0001 or not finite(wd.reload)or math.abs(wd.reload-1.2)>.0001 or wcp.source_muzzle~='marker_boyz_burna_barrel'or wcp.source_fireclip~='fire'then fail('actual_Burna_Flame_clock_muzzle_required');return C end
 end
 if G.Recoil40KStompaWeaponWitness~=nil then inconclusive('genuine_roster_telemetry_already_owned');return C end
 -- The pinned Initial Spawn creates one commander for each registered team,
 -- including this scene's engine NullAI enemy. Neither initial actor is owned.
 local teams=S.GetTeamList();if type(teams)~='table'then fail('registered_team_inventory_required');return C end
 local registered={};local gaia=S.GetGaiaTeamID()
 if not int(gaia)or gaia==0 or gaia==1 then fail('actual_separate_Gaia_team_required');return C end
 C.initialGaia={};C.gaiaTeam=gaia;C.relicDef=N['40k_relic_objective'].id
 for _,team in pairs(teams)do
  if not int(team)or registered[team]then fail('typed_unique_registered_team_required');return C end;registered[team]=true
  if team~=0 and team~=gaia then
   if team~=1 or S.AreTeamsAllied(0,team)~=false or C.enemy~=nil then inconclusive('exact_one_registered_inactive_enemy_required');return C end
   C.enemy=team
  end
 end
 local _,_,dead,isAI=S.GetTeamInfo(1,false)
 if not registered[0]or not registered[gaia]or C.enemy~=1 or dead~=false or isAI~=true then inconclusive('registered_inactive_hostile_team1_required');return C end
 local units=S.GetAllUnits();if type(units)~='table'then fail('fresh_unit_inventory_required');return C end
 local ids,seen={},{}
 for _,id in pairs(units)do if not int(id)or seen[id]then fail('typed_unique_fresh_unit_inventory_required');return C end;seen[id]=true;ids[#ids+1]=id end
 table.sort(ids)
 local ownCount,enemyCount,gaiaCount=0,0,0
 for _,id in ipairs(ids)do
  local def,team=S.GetUnitDefID(id),S.GetUnitTeam(id);local role='foreign'
  if live(id,N.ork_big_mek_commander.id,0)then ownCount=ownCount+1;C.commander=id;role='own_commander'
  elseif live(id,N.imp_field_commander.id,1)then enemyCount=enemyCount+1;C.initialEnemy=id;C.initialEnemyDef=N.imp_field_commander.id;role='enemy_commander'
  elseif live(id,C.relicDef,gaia)and S.GetUnitNeutral(id)==true and S.GetUnitRulesParam(id,'40k_relic_reviewed')==1 then
   gaiaCount=gaiaCount+1;C.initialGaia[id]={def=C.relicDef,team=gaia};role='gaia_relic'end
  local _,_,_,_,progress=S.GetUnitHealth(id)
  log('INITIAL_UNIT','actor='..id,'def='..tostring(def),'team='..tostring(team),'role='..role,
   'native_alive='..tostring(S.ValidUnitID(id)==true and S.GetUnitIsDead(id)==false),'native_complete='..tostring(progress==1))
  if role=='gaia_relic'then log('INITIAL_GAIA','actor='..id,'def='..C.relicDef,'team='..gaia,'reviewed=true','neutral=true','unowned=true')end
 end
 if ownCount~=1 or enemyCount~=1 or gaiaCount>1 or #ids~=2+gaiaCount then inconclusive('exact_fresh_commanders_and_disclosed_reviewed_Gaia_relic_required');return C end
 log('INITIAL_ROSTER','count=2','own_commander='..C.commander,'own_def='..N.ork_big_mek_commander.id,'enemy_commander='..C.initialEnemy,
  'enemy_def='..C.initialEnemyDef,'enemy_team=1','enemy_inactive_ai=true','unowned_enemy_preserved=true','gaia_team='..gaia,'gaia_count='..gaiaCount,'global_count='..#ids,'scene_scope=two_relevant_teams_plus_unowned_reviewed_relic')
 C.commanderDef=N.ork_big_mek_commander.id;G.Recoil40KStompaWeaponWitness=C;C.watched={}
 for _,weapon in pairs(C.weapons)do if not C.watched[weapon]then Script.SetWatchProjectile(weapon,true);C.watched[weapon]=true end end
 log('BEGIN','profile=18','capacity=4','factory_native_speed_unchanged=true','ordinary_paid_fixture_independent=true')
 local function intact()
  if not live(C.commander,C.commanderDef,0)or not live(C.initialEnemy,C.initialEnemyDef,1)or C.owned[C.initialEnemy]~=nil then return false end
  for id,row in pairs(C.initialGaia)do if not live(id,row.def,row.team)or S.GetUnitNeutral(id)~=true or S.GetUnitRulesParam(id,'40k_relic_reviewed')~=1 or C.owned[id]~=nil then return false end end
  if C.factory and not live(C.factory,C.factoryDef,0)then return false end
  if C.leader then local r=G.Recoil40KSquads;local squad=r and r.Get(C.leader)
   if not squad or squad.profile~='ork_burna'or squad.team~=0 or squad.leader~=C.leader then return false end
   for slot,q in pairs(C.slots)do if squad.slots[slot]~=q.id or squad.generations[slot]~=1 or not live(q.id,q.def,0)then return false end end
  end
  return true
 end
 local function free(x,z,r)
  local us,fs=S.GetUnitsInRectangle(x-r,z-r,x+r,z+r),S.GetFeaturesInRectangle(x-r,z-r,x+r,z+r)
  return type(us)=='table'and type(fs)=='table'and next(us)==nil and next(fs)==nil
 end
 -- One cheap observation per controlled scene guard; never acceptance evidence.
 local function sceneClear(stage,x,z,r)
  local mapClear=finite(x)and finite(z)and finite(r)and r>0 and x-r>64 and z-r>64 and x+r<Game.mapSizeX-64 and z+r<Game.mapSizeZ-64
  local us,fs;if mapClear then us,fs=S.GetUnitsInRectangle(x-r,z-r,x+r,z+r),S.GetFeaturesInRectangle(x-r,z-r,x+r,z+r)end
  local function inventory(rows)
   if type(rows)~='table'then return nil,nil end
   local count,first=0,nil
   for _,id in pairs(rows)do count=count+1;if not int(id)or count>512 then return nil,nil end;first=first and math.min(first,id)or id end
   return count,first
  end
  local units,unit=inventory(us);local features,feature=inventory(fs);local ownBody=false
  for _,q in pairs(C.slots)do ownBody=ownBody or q.id==unit end
  local ux,uy,uz;if unit then ux,uy,uz=S.GetUnitPosition(unit)end
  local fx,fy,fz;if feature then fx,fy,fz=S.GetFeaturePosition(feature)end
  if type(S.Echo)=='function'then S.Echo('40K_BURNA_SCENE frame='..S.GetGameFrame()..' stage='..stage..' map_x='..admissionToken(Game.mapSizeX)..' map_z='..admissionToken(Game.mapSizeZ)..' center_x='..admissionToken(x)..' center_z='..admissionToken(z)..' radius='..admissionToken(r)..' map_clear='..tostring(mapClear)..' units='..admissionToken(units)..' features='..admissionToken(features)..' first_unit='..admissionToken(unit)..' first_unit_x='..admissionToken(ux)..' first_unit_z='..admissionToken(uz)..' first_unit_is_original_body='..tostring(ownBody)..' first_feature='..admissionToken(feature)..' first_feature_x='..admissionToken(fx)..' first_feature_z='..admissionToken(fz)..' observation_only=true weapon_accepted=false movement_accepted=false')end
  if not mapClear then return false,'map_margin_refused'end
  if units==nil then return false,'native_unit_inventory_unavailable'end
  if features==nil then return false,'native_feature_inventory_unavailable'end
  if units>0 then return false,'native_unit_inventory_not_empty'end
  if features>0 then return false,'native_feature_inventory_not_empty'end
  return true
 end
 -- Explicit controlled weapon setup, never ordinary movement/exit acceptance.
 -- Production/birth/bill identity is already checked; only those four owned
 -- generation1 bodies are placed. All weapon admission and damage stay native.
 local function assemble()
  local plan={};local half=0;local minimumRange=math.huge;local maximumRange=0
  for slot=1,4 do
   local q=C.slots[slot];local d=q and D[q.def]
   if not q or not d or not live(q.id,q.def,0)or S.GetUnitTransporter(q.id)~=nil then return fail('diagnostic_assembly_exact_owned_full4_required')end
   local sx,sy,sz,ox,oy,oz=S.GetUnitCollisionVolumeData(q.id)
   local range=S.GetUnitWeaponState(q.id,1,'range');local hp,max,_,_,progress=S.GetUnitHealth(q.id);local xp=S.GetUnitExperience(q.id)
   local work,metal,energy=S.GetUnitCosts(q.id)
   if not finite(sx)or not finite(sy)or not finite(sz)or sx<=0 or sy<=0 or sz<=0 or not finite(ox)or not finite(oy)or not finite(oz)
    or not int(d.xsize,1)or not int(d.zsize,1)or not finite(range)or range<=0 or not finite(xp)or xp<0
    or progress~=1 or work~=264 or metal~=22 or energy~=110 then return fail('diagnostic_assembly_actual_body_facts_required')end
   half=math.max(half,math.sqrt((math.abs(ox)+sx/2)^2+(math.abs(oz)+sz/2)^2),d.xsize*4,d.zsize*4)
   minimumRange=math.min(minimumRange,range);maximumRange=math.max(maximumRange,range)
   plan[slot]={id=q.id,def=q.def,hp=hp,max=max,xp=xp}
  end
  local spacing=half*2+4
  if spacing*1.5>=minimumRange*.75 then return inconclusive('diagnostic_assembly_full4_line_exceeds_native_range')end
  local fx,fy,fz=S.GetUnitPosition(C.factory);local fd=D[C.factoryDef];local td=D[C.targetDef]
  if not finite(fx)or not finite(fy)or not finite(fz)then return fail('diagnostic_assembly_native_producer_position_required')end
  local targetRadius=math.max(td.xsize*4,td.zsize*4,td.radius or 0)+16
  local clearance=maximumRange+targetRadius+half+16
  -- One deterministic scene beyond the producer. No further target-picker
  -- variation or timeout/budget inflation after repeated uninformative trials.
  local cx,cz=640,2048
  local clear,reason=sceneClear('assembly',cx,cz,clearance)
  if not clear then return inconclusive('diagnostic_flat_assembly_'..reason)end
  for _,dx in ipairs({-clearance,0,clearance})do for _,dz in ipairs({-clearance,0,clearance})do
   local h=S.GetGroundHeight(cx+dx,cz+dz);local nx,ny,nz,slope=S.GetGroundNormal(cx+dx,cz+dz,true)
   if not finite(h)or h<=0 or not finite(nx)or not finite(ny)or not finite(nz)or not finite(slope)or ny<.999 or ny>1.001 or slope<0 or slope>.001 then return inconclusive('diagnostic_flat_assembly_native_flat_ground_required')end
  end end
  for slot,row in ipairs(plan)do
   row.x=cx+(slot-2.5)*spacing;row.z=cz;row.y=S.GetGroundHeight(row.x,row.z)
   if not finite(row.y)or row.y<0 or S.TestMoveOrder(row.def,row.x,row.y,row.z,0,0,0,true,true,false)~=true then return inconclusive('diagnostic_assembly_native_full_footprint_refused')end
  end
  -- Ordinary STOP/hold-fire acts on the real paid leader and shared members;
  -- do not seize MoveCtrl, disable collisions or edit the shared movement owner.
  if S.GiveOrderToUnit(C.leader,CMD.STOP,{},0)~=true or S.GiveOrderToUnit(C.leader,CMD.FIRE_STATE,{0},0)~=true then return fail('diagnostic_assembly_ordinary_stop_hold_refused')end
  for _,row in ipairs(plan)do
   local ok=pcall(S.SetUnitPosition,row.id,row.x,row.z)
   if not ok then return fail('diagnostic_assembly_native_placement_failed')end
  end
  if S.GiveOrderToUnit(C.leader,CMD.STOP,{},0)~=true then return fail('diagnostic_assembly_post_placement_stop_refused')end
  if not intact()then return fail('diagnostic_assembly_identity_changed')end
  for slot,row in ipairs(plan)do
   local x,y,z=S.GetUnitPosition(row.id);local hp,max,_,_,progress=S.GetUnitHealth(row.id);local work,metal,energy=S.GetUnitCosts(row.id)
   if not finite(x)or not finite(y)or not finite(z)or math.abs(x-row.x)>1 or math.abs(z-row.z)>1 or math.abs(y-row.y)>4
    or hp~=row.hp or max~=row.max or progress~=1 or S.GetUnitExperience(row.id)~=row.xp or work~=264 or metal~=22 or energy~=110
    or(math.abs(x-fx)<=fd.xsize*4+half and math.abs(z-fz)<=fd.zsize*4+half)then return fail('diagnostic_assembly_actual_placement_or_preservation_refused')end
   row.actualX=x;row.actualZ=z
   for previous=1,slot-1 do local other=plan[previous]
    if(x-other.actualX)^2+(z-other.actualZ)^2<(half*2+2)^2 then return fail('diagnostic_assembly_actual_body_separation_required')end
   end
  end
  if type(S.Echo)=='function'then for slot,row in ipairs(plan)do
   S.Echo('40K_BURNA_SETUP frame='..S.GetGameFrame()..' slot='..slot..' actor='..row.id..' def='..row.def..' x='..admissionToken(row.actualX)..' z='..admissionToken(row.actualZ)..' controlled_own_body_placement=true original_generation1=true HP_XP_bill_preserved=true movement_accepted=false progression_accepted=false weapon_accepted=false')
  end end
  C.phase='site'
 end
 local function makeFactory()
  if C.candidate~=0 then return fail('diagnostic_flat_factory_once_only')end;C.candidate=1
  local x,z=640,1536;local y=S.GetGroundHeight(x,z)
  local fd=D[C.factoryDef];local r=math.max(fd.xsize*4,fd.zsize*4)+96
  local clear,reason=sceneClear('factory',x,z,r);if not clear then return inconclusive('diagnostic_flat_factory_'..reason)end
  if not finite(y)or y<=0 then return inconclusive('diagnostic_flat_factory_dry_ground_required')end
  local state,feature=S.TestBuildOrder(C.factoryDef,x,y,z,0)
  if type(S.Echo)=='function'then S.Echo('40K_BURNA_SCENE frame='..S.GetGameFrame()..' stage=factory_build_order state='..admissionToken(state)..' feature='..admissionToken(feature)..' observation_only=true weapon_accepted=false movement_accepted=false')end
  if not finite(state)or state<2 or feature~=nil then return inconclusive('diagnostic_flat_factory_native_build_order_refused')end
  local id=S.CreateUnit('ork_boyz_hut_t2',x,y,z,0,0);if not int(id)or id==C.commander or id==C.initialEnemy or C.initialGaia[id]or not live(id,C.factoryDef,0)then return fail('disclosed_funded_native_factory_birth')end
  C.factory=id;C.owned[id]={def=C.factoryDef,team=0};local queue=S.GetFactoryCommands(id,-1)
  if type(queue)~='table'or next(queue)~=nil then return inconclusive('fresh_factory_queue_not_empty')end
  S.SetTeamResource(0,'ms',100000);S.SetTeamResource(0,'es',100000);S.SetTeamResource(0,'m',50000);S.SetTeamResource(0,'e',50000)
  C.phase='produce'
  if S.GiveOrderToUnit(id,-C.product,{},0)~=true then return fail('funded_native_queue_refused')end
  C.candidate=0;log('FUNDED_QUEUE','factory='..id,'product='..C.product,'native_body_bill=22,110,264','full_product_bill=88,440,1056','no_build_speed_change=true')
 end
 local function cohort()
  if not C.delivered then return end
  local r=G.Recoil40KSquads;local squad=r and r.Get(C.delivered)
  if not squad then return end
  if squad.profile~='ork_burna'or squad.team~=0 or squad.leader~=C.delivered or squad.slots[1]~=C.delivered then return fail('genuine_shared_profile18_leader_required')end
  local seen={};local count=0;for slot,id in pairs(squad.slots)do
   count=count+1;if not int(slot,1)or slot>4 or not int(id)or seen[id]or id==C.factory or id==C.commander or id==C.initialEnemy or C.initialGaia[id]then return fail('four_unique_real_body_slots_required')end;seen[id]=true
   local def=slot==1 and C.product or C.member;local b,f=C.births[id],C.finishes[id]
   if not live(id,def,0)or not b or not f or b.def~=def or b.team~=0 or f.def~=def or f.team~=0 or f.frame<b.frame or squad.generations[slot]~=1 then return fail('actual_full4_native_birth_finish_generation1_required')end
   local work,metal,energy=S.GetUnitCosts(id);if metal~=22 or energy~=110 or work~=264 then return fail('native_shared_body_allocation_required')end
   local pieces=S.GetUnitPieceMap(id);local piece=type(pieces)=='table'and pieces.marker_boyz_burna_barrel
   if not int(piece)then return fail('genuine_actual_Burna_piece_required')end
   C.slots[slot]={id=id,def=def,weapon=C.weapons[def],piece=piece,shots=0,cycles=0,hits=0};C.owned[id]={def=def,team=0}
  end
  if count~=4 then return fail('full4_required_no_partial_scene')end
  -- TELEMETRY_ONLY_BODY_BEGIN
  for slot=1,4 do local q=C.slots[slot];local birth,finished=C.births[q.id],C.finishes[q.id];local work,metal,energy=S.GetUnitCosts(q.id)
   log('BODY','slot='..slot,'actor='..q.id,'def='..q.def,'team=0','builder='..birth.builder,'born_frame='..birth.frame,'finished_frame='..finished.frame,'generation='..squad.generations[slot],'work='..tostring(work),'metal='..tostring(metal),'energy='..tostring(energy),'piece='..q.piece,'source_piece=marker_boyz_burna_barrel','cost_getter_order=work_metal_energy')
  end
  -- TELEMETRY_ONLY_BODY_END
  C.leader=C.delivered;C.phase='assemble';log('FULL4','leader='..C.leader,'generation1=true','native_finish_release=true','paid_economy_accepted=false')
 end
 local function targetLive()return C.target~=nil and live(C.target,C.targetDef,C.enemy)end
 local function retire()
  local id=C.target;C.target=nil;C.phase='site'
  if id and C.owned[id]and live(id,C.targetDef,C.enemy)then C.owned[id].retired=true;S.DestroyUnit(id,false,true)end
 end
 local function acquire()
  if not targetLive()then return inconclusive('hostile_lost_before_combat')end
  local tx,ty,tz=S.GetUnitPosition(C.target);if not finite(tx)or not finite(ty)or not finite(tz)then return fail('actual_hostile_position_required')end
  for slot,q in pairs(C.slots)do
   local ally=S.GetUnitAllyTeam(q.id);local los=int(ally)and S.GetUnitLosState(C.target,ally,false)
   if type(los)~='table'or los.los~=true then if S.GetGameFrame()-C.siteFrame>=30 then log('SITE_REFUSED','natural_LOS_missing=true');retire()end;return end
   local x,y,z=S.GetUnitPiecePosDir(q.id,q.piece);if not finite(x)or not finite(y)or not finite(z)then return fail('actual_native_muzzle_required')end
   -- Diagnostic queries are read-only; preserve every native admission gate.
   local testTarget=S.GetUnitWeaponTestTarget(q.id,1,C.target)
   local testRange=S.GetUnitWeaponTestRange(q.id,1,C.target)
   local tryTarget=S.GetUnitWeaponTryTarget(q.id,1,C.target)
   -- Native six-argument overload preserves target identity and uses its lead position.
   local unitTargetLoF=S.GetUnitWeaponHaveFreeLineOfFire(q.id,1,x,y,z,C.target)
   local groundCoordinateLoF=S.GetUnitWeaponHaveFreeLineOfFire(q.id,1,x,y,z,tx,ty,tz)
   if type(S.Echo)=='function'then
    local a={'40K_BURNA_SITE','frame='..S.GetGameFrame(),'candidate='..C.candidate,'slot='..slot,'actor='..q.id,'hostile='..C.target,'observation_only=true','native_accepted=false'}
    for _,v in ipairs({{'test_target',testTarget},{'test_range',testRange},{'try_target',tryTarget},{'unit_target_lof',unitTargetLoF},{'ground_coordinate_lof',groundCoordinateLoF},{'muzzle_x',x},{'muzzle_y',y},{'muzzle_z',z},{'target_base_x',tx},{'target_base_y',ty},{'target_base_z',tz}})do a[#a+1]=v[1]..'='..admissionToken(v[2])end
    S.Echo(table.concat(a,' '))
   end
   if testTarget~=true or testRange~=true or tryTarget~=true or unitTargetLoF~=true then log('SITE_REFUSED','slot='..slot,'native_target_range_LOF_refused=true');retire();return end
  end
  C.health=S.GetUnitHealth(C.target);if not finite(C.health)or C.health<=0 then return fail('native_hostile_HP_required')end
  C.phase='combat';C.combatFrame=S.GetGameFrame()
  if S.GiveOrderToUnit(C.leader,CMD.ATTACK,{C.target},0)~=true then return fail('ordinary_shared_leader_ATTACK_refused')end
  log('ATTACK','leader='..C.leader,'hostile='..C.target,'natural_LOS_native_range_LOF_all4=true')
 end
 -- Geometric candidate guidance only. Native target/range/TryTarget/LoF remain authoritative.
 local function commonRangePoint(index)
  local points={};local loX,hiX,loZ,hiZ=-math.huge,math.huge,-math.huge,math.huge
  for slot=1,4 do
   local q=C.slots[slot];local bx,by,bz=S.GetUnitPosition(q.id)
   local x,y,z=S.GetUnitPiecePosDir(q.id,q.piece);local range=S.GetUnitWeaponState(q.id,1,'range')
   if not finite(bx)or not finite(by)or not finite(bz)or not finite(x)or not finite(y)or not finite(z)or not finite(range)or range<=0 then return nil,nil,'actual_full4_position_muzzle_range_required'end
   points[slot]={x=x,z=z,range=range}
   loX=math.max(loX,x-range);hiX=math.min(hiX,x+range);loZ=math.max(loZ,z-range);hiZ=math.min(hiZ,z+range)
   if type(S.Echo)=='function'then S.Echo('40K_BURNA_RANGE_BODY frame='..S.GetGameFrame()..' candidate='..index..' slot='..slot..' actor='..q.id..' body_x='..admissionToken(bx)..' body_y='..admissionToken(by)..' body_z='..admissionToken(bz)..' muzzle_x='..admissionToken(x)..' muzzle_y='..admissionToken(y)..' muzzle_z='..admissionToken(z)..' native_range='..admissionToken(range)..' observation_only=true native_accepted=false')end
  end
  if hiX<loX or hiZ<loZ then return nil,nil,'no_common_current_full4_horizontal_range_envelope'end
  -- Four slices span the common envelope, including conservative near-edge coverage.
  -- Each of eight positions uses the exact intersection of all four disks at that slice.
  local rows={1/64,1/3,2/3,63/64};local row=math.floor((index-1)/8)+1;local col=(index-1)%8
  local z=loZ+(hiZ-loZ)*rows[row];local left,right=loX,hiX
  for _,p in ipairs(points)do
   local span=p.range*p.range-(z-p.z)^2;if span<0 then return nil,nil,'no_common_current_full4_range_slice'end
   local dx=math.sqrt(span);left=math.max(left,p.x-dx);right=math.min(right,p.x+dx)
  end
  if right<left then return nil,nil,'no_common_current_full4_range_slice'end
  return left+(right-left)*(col+.5)/8,z
 end
 local function rangePick(status,x,z,radius)
  if type(S.Echo)=='function'then S.Echo('40K_BURNA_RANGE_PICK frame='..S.GetGameFrame()..' candidate='..C.candidate..' status='..status..' x='..admissionToken(x)..' z='..admissionToken(z)..' clearance_radius='..admissionToken(radius)..' observation_only=true native_accepted=false')end
 end
 local function scene()
  C.candidate=C.candidate+1;if C.candidate>32 then return inconclusive('no_common_natural_full4_Flame_site')end
  local tx,tz,reason=commonRangePoint(C.candidate)
  if reason then rangePick(reason,tx,tz);if reason=='actual_full4_position_muzzle_range_required'then return fail(reason)end;if reason=='no_common_current_full4_horizontal_range_envelope'then return inconclusive(reason)end;return end
  local ty=S.GetGroundHeight(tx,tz)
  local td=D[C.targetDef];local radius=math.max(td.xsize*4,td.zsize*4,td.radius or 0)+16
  if not finite(ty)or ty<0 or tx-radius<=64 or tz-radius<=64 or tx+radius>=Game.mapSizeX-64 or tz+radius>=Game.mapSizeZ-64 then rangePick('dry_map_clearance_refused',tx,tz,radius);return end
  if not free(tx,tz,radius)then rangePick('native_unit_or_feature_clearance_refused',tx,tz,radius);return end
  for _,dx in ipairs({-radius,0,radius})do for _,dz in ipairs({-radius,0,radius})do local h=S.GetGroundHeight(tx+dx,tz+dz);if not finite(h)or h<0 then rangePick('dry_clearance_ground_refused',tx,tz,radius);return end end end
  -- centerOnly=false already checks the entire native MoveDef footprint, not a point.
  if S.TestMoveOrder(C.targetDef,tx,ty,tz,0,0,0,true,true,false)~=true then rangePick('native_full_footprint_refused',tx,tz,radius);return end
  rangePick('native_full_footprint_candidate',tx,tz,radius)
  local id=S.CreateUnit('imp_russ',tx,ty,tz,0,C.enemy);if not int(id)or not live(id,C.targetDef,C.enemy)or C.owned[id]or id==C.commander or id==C.initialEnemy or C.initialGaia[id]then return fail('unique_funded_hostile_native_birth_required')end
  C.target=id;C.owned[id]={def=C.targetDef,team=C.enemy};C.siteFrame=S.GetGameFrame();C.phase='acquire'
  if S.GiveOrderToUnit(id,CMD.FIRE_STATE,{0},0)~=true or S.GiveOrderToUnit(id,CMD.STOP,{},0)~=true then return fail('ordinary_inactive_hostile_orders_refused')end;acquire()
 end
 function C.Frame(f)
  if C.result then return C.result end
  if not int(f)or f~=S.GetGameFrame()then return fail('actual_native_frame_required')end
  if not intact()then return fail('original_commander_factory_or_full4_identity_lost')end
  if G.Recoil40KStompaWeaponWitness~=C then return inconclusive('genuine_telemetry_owner_lost')end
  if f-C.started>3600 then return inconclusive('funded_native_scene_timeout')end
  if C.phase=='initial'and f>=90 then makeFactory()
  elseif C.phase=='produce'then cohort()
  elseif C.phase=='assemble'then assemble()
  elseif C.phase=='site'then scene()
  elseif C.phase=='acquire'then acquire()
  elseif C.phase=='combat'then
   if not targetLive()then return inconclusive('hostile_captured_or_lost_before_completion')end
   local all=true;for _,q in pairs(C.slots)do all=all and q.cycles>=2 and q.shots>=8 and q.hits>=2 end
   if all then return finish('PASS','funded_full4_Burna_two_native_Flame_bursts_Query_Shot_PID_positive_HP_each_body')end
   if f-C.combatFrame>1800 then return inconclusive('four_body_native_Flame_witness_timeout')end
  end
  return C.result
 end
 function C.Created(id,def,team,builder)
  if C.closed then return end;local f=S.GetGameFrame()
  if not int(id)or not int(f)then return fail('typed_native_birth_required')end
  if id==C.commander or id==C.initialEnemy or C.initialGaia[id]then return fail('initial_native_actor_birth_identity_reused')end
  if def==C.product or def==C.member then
   local r=G.Recoil40KSquads;local pending=r and C.productBirth and r.pending and r.pending[C.productBirth]
   local eligible=C.phase=='produce'and C.factory~=nil and builder==C.factory and team==0
   if def==C.product then
    eligible=eligible and C.productBirth==nil
    if eligible then C.productBirth=id end
   else eligible=eligible and r and r.creating==true and pending and pending.key=='ork_burna'and pending.team==0 and pending.factory==C.factory end
   if not eligible then log('FOREIGN_BIRTH_PRESERVED','id='..id,'no_fixture_cleanup_claim=true');return end
   if C.births[id]then if C.owned[id]then C.owned[id].retired=true end;return fail('duplicate_native_body_birth')end
   C.births[id]={def=def,team=team,builder=builder,frame=f}
   -- TELEMETRY_ONLY_BIRTH_BEGIN
   log('BODY_BIRTH','actor='..id,'def='..def,'team='..team,'builder='..builder,'born_frame='..f)
   -- TELEMETRY_ONLY_BIRTH_END
   C.owned[id]={def=def,team=team}
  end
 end
 function C.Finished(id,def,team)
  if C.closed then return end;if C.births[id]then local f=S.GetGameFrame();if not int(id)or not int(f)or C.finishes[id]then return fail('typed_unique_native_body_finish_required')end;C.finishes[id]={def=def,team=team,frame=f};log('BODY_FINISHED','actor='..id,'def='..tostring(def),'team='..tostring(team),'finished_frame='..f)end
 end
 function C.Released(id,def,team,parent)
  if C.closed or def~=C.product or id~=C.productBirth then return end
  local b,f=C.births[id],C.finishes[id];if team~=0 or parent~=C.factory or C.delivered~=nil or not b or b.builder~=C.factory or not f or f.frame>S.GetGameFrame()then return fail('actual_native_factory_release_required')end
  C.delivered=id
 end
 local function slotFor(id)for slot,q in pairs(C.slots)do if q.id==id then return slot,q end end end
 function C.Query(id,n,piece)
  if C.closed or C.phase~='combat'or n~=1 then return end;local slot,q=slotFor(id);if not q then return end
  if not live(id,q.def,0)then return fail('native_Query_actor_identity_lost')end
  local now=S.GetGameFrame();if piece~=q.piece or not int(now)then return fail('actual_Query_piece_clock_required')end
  local x,y,z=S.GetUnitPiecePosDir(id,piece);if not finite(x)or not finite(y)or not finite(z)then return fail('finite_Query_muzzle_required')end
  C.serial=C.serial+1;q.query={serial=C.serial,frame=now,x=x,y=y,z=z};log('QUERY','slot='..slot,'actor='..id,'piece='..piece,'frame='..now)
 end
 function C.Shot(id,n,f)
  if C.closed or C.phase~='combat'or n~=1 then return end;local slot,q=slotFor(id);if not q then return end
  if not live(id,q.def,0)then return fail('native_Shot_actor_identity_lost')end
  if not int(f)or f~=S.GetGameFrame()then return fail('native_Shot_clock_required')end
  local burst=S.GetUnitWeaponState(id,1,'burst');local rate=S.GetUnitWeaponState(id,1,'burstRate');local reload=S.GetUnitWeaponState(id,1,'reloadTimeXP')
  if burst~=4 or not finite(rate)or math.abs(rate-BURST_SECONDS)>.001 or not finite(reload)or reload<=0 or S.GetUnitWeaponState(id,1)~=true then return fail('genuine_ready_native_Flame_clock_required')end
  if q.shots%4==0 then
   if q.cycleFrame and f-q.cycleFrame<math.floor(reload*30)-1 then return fail('native_cycle_clock_too_fast')end
   q.cycleFrame=f;q.cycles=q.cycles+1
  elseif q.shot and f-q.shot.frame<BURST_FRAMES then return fail('native_subshot_clock_too_fast')end
  C.serial=C.serial+1;q.shots=q.shots+1;q.shot={serial=C.serial,frame=f};log('SHOT','slot='..slot,'actor='..id,'frame='..f,'count='..q.shots,'native_reload_seconds='..reload,'native_burst_rate_seconds='..rate)
 end
 function C.Projectile(pid,owner,weapon)
  if C.closed or C.phase~='combat'then return end;local slot,q=slotFor(owner);if not q or weapon~=q.weapon then return end
  if not live(owner,q.def,0)then return fail('native_PID_actor_identity_lost')end
  local shot,query,now=q.shot,q.query,S.GetGameFrame()
  if not int(pid)or C.projectiles[pid]or not shot or shot.linked or not query or query.serial<=shot.serial or not int(now)or now<query.frame or query.frame<shot.frame or now-shot.frame>2 then return fail('fresh_Shot_Query_unique_native_PID_required')end
  local x,y,z=S.GetProjectilePosition(pid);local mx,my,mz=S.GetUnitWeaponVectors(owner,1);local speed=S.GetUnitWeaponState(owner,1,'projectileSpeed')
  if not finite(x)or not finite(y)or not finite(z)or not finite(mx)or not finite(my)or not finite(mz)or not finite(speed)or speed<=0 or(x-query.x)^2+(y-query.y)^2+(z-query.z)^2>math.max(16,speed+4)^2 or(mx-query.x)^2+(my-query.y)^2+(mz-query.z)^2>16 then return fail('actual_native_PID_muzzle_speed_required')end
  shot.linked=true;C.projectiles[pid]={slot=slot,actor=owner,weapon=weapon,frame=now};log('PID','slot='..slot,'actor='..owner,'pid='..pid,'frame='..now)
 end
 function C.Damaged(id,damage,para,weapon,pid,attacker)
  if C.closed or C.phase~='combat'or id~=C.target then return end
  if not targetLive()or not intact()then return fail('native_damage_actor_or_hostile_identity_lost')end
  local now=S.GetGameFrame();local hp=S.GetUnitHealth(id);if not int(now)or not finite(hp)then return fail('actual_native_HP_clock_required')end
  local loss=C.health-hp;C.health=hp;local slot,q=slotFor(attacker)
  if not q then log('OTHER_DAMAGE','native_HP_baseline_updated=true');return end
  local p=int(pid)and C.projectiles[pid]
  if para~=false or not finite(damage)or damage<=0 or weapon~=q.weapon or not p or p.weapon~=weapon or p.actor~=attacker or p.slot~=slot or p.frame>now or loss<=0 then return fail('actual_owned_native_PID_positive_HP_loss_required')end
  if not p.hit then p.hit=true;q.hits=q.hits+1 end
  log('NATIVE_HIT','slot='..slot,'actor='..attacker,'pid='..pid,'damage='..damage,'health='..hp,'distinct_hit_projectiles='..q.hits)
 end
 function C.Destroyed(id)
  if C.owned[id]then C.owned[id].retired=true end
  if C.closed then return end
  if id==C.commander or id==C.initialEnemy or C.initialGaia[id]or id==C.factory or slotFor(id)then return fail('preserved_own_native_actor_destroyed')end
  if id==C.target then log('NATIVE_DEATH','hostile='..id,'native_callback_only=true');return inconclusive('hostile_native_death_before_full4_witness')end
 end
 return C
end
return M
