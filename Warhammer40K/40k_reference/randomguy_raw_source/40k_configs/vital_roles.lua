-- Native BAR functions with genuinely converted DoW/UA actors. Include after the
-- upstream postprocessor and roster definitions, before weapon family assignment.
-- Native validation markers are explicit acceptance, not export-success markers.
local M={}
local function clone(value)
 if type(value)~='table' then return value end
 local out={};for k,v in pairs(value)do out[k]=clone(v)end;return out
end
local aliases={
 armcom={'imp_commissar','Imperial Field Commander','commander'},
 corcom={'ork_warboss','Ork Warboss Commander','commander'},
 armck={'imp_enginseer','Techpriest Enginseer','constructor'},armcv={'imp_enginseer','Vehicle Works Enginseer','constructor'},
 armack={'imp_enginseer','Senior Enginseer','constructor'},armacv={'imp_enginseer','Senior Vehicle Works Enginseer','constructor'},
 corck={'ork_grot','Grot Builder','constructor'},corcv={'ork_grot','Mek Shop Grot','constructor'},
 corack={'ork_grot','Senior Grot Builder','constructor'},coracv={'ork_grot','Senior Mek Shop Grot','constructor'},
 armlab={'imp_barracks','Imperium Barracks','barracks'},armalab={'imp_barracks','Veteran Imperium Barracks','barracks'},
 armvp={'imp_tank_factory','Imperium Tank Factory','tank_factory'},armavp={'imp_tank_factory','Veteran Imperium Tank Factory','tank_factory'},
 corlab={'ork_boyz_hut','Ork Boyz Hut','barracks'},coralab={'ork_boyz_hut','Veteran Ork Boyz Hut','barracks'},
 corvp={'ork_mek_lab','Ork Walker Factory','walker_factory'},coravp={'ork_mek_lab','Veteran Ork Walker Factory','walker_factory'},
 armsolar={'imp_generator','Plasma Generator','generator'},armwin={'imp_generator','Plasma Generator Array','generator'},
 armadvsol={'imp_generator','Improved Plasma Generator','generator'},armfus={'imp_thermo','Plasma Reactor','generator'},
 armafus={'imp_thermo','Large Plasma Reactor','generator'},armgeo={'imp_thermo','Thermo Plasma Generator','geothermal'},
 corsolar={'ork_generator','Ork Generator','generator'},corwin={'ork_generator','Ork Generator Array','generator'},
 coradvsol={'ork_generator','Improved Ork Generator','generator'},corfus={'ork_generator','Ork Reactor','generator'},
 corafus={'ork_generator','Large Ork Reactor','generator'},corgeo={'ork_generator','Ork Geothermal Generator','geothermal'},
 armmex={'imp_mex','Imperial Listening Post Extractor','extractor'},armmoho={'imp_mex','Deep Imperial Listening Post Extractor','extractor'},
 cormex={'ork_resource_factory','Ork Resource Factory','extractor'},cormoho={'ork_resource_factory','Deep Ork Resource Factory','extractor'},
 armestor={'imp_generator','Plasma Capacitor Depot','energy_storage'},armmstor={'imp_hq','Imperial Supply Depot','metal_storage'},
 corestor={'ork_generator','Ork Power Depot','energy_storage'},cormstor={'ork_resource_factory','Ork Scrap Depot','metal_storage'},
 armrad={'imp_research','Imperial Auspex Command','radar'},armarad={'imp_research','Long Range Auspex Command','radar'},
 corrad={'ork_waaagh_banner','Ork Lookout Banner','radar'},corarad={'ork_waaagh_banner','Long Range Ork Lookout Banner','radar'},
 armjamt={'imp_research','Imperial Signal Disruptor','jammer'},armveil={'imp_research','Imperial Signal Veil','jammer'},
 corjamt={'ork_waaagh_banner','Ork Signal Disruptor','jammer'},corshroud={'ork_waaagh_banner','Ork Signal Shroud','jammer'},
 armnanotc={'imp_research','Enginseer Repair Station','repair'},armnanotcplat={'imp_research','Raised Enginseer Repair Station','repair'},
 cornanotc={'ork_mek_shop','Mek Repair Station','repair'},cornanotcplat={'ork_mek_shop','Raised Mek Repair Station','repair'},
 armmakr={'imp_generator','Imperial Resource Converter','converter'},armmmkr={'imp_generator','Large Imperial Resource Converter','converter'},
 cormakr={'ork_resource_factory','Ork Scrap Converter','converter'},cormmkr={'ork_resource_factory','Large Ork Scrap Converter','converter'},
}
local rosters={
 Imperium={
  structures={'armlab','armvp','imp_walker_factory','imp_hq','armsolar','armmex','armgeo','armestor','armmstor','armrad','armjamt','armnanotc','armmakr','imp_research'},
  infantry={'armck','imp_guardsman','imp_marine','imp_commissar','imp_kasrkin','imp_scout','imp_devastator','imp_ogryn','imp_heavy_weapon_team'},
  tanks={'armcv','imp_russ','imp_basilisk','imp_hellhound','imp_predator'},walkers={'imp_enginseer','imp_sentinel','imp_dreadnought'},
  headquarters={'imp_enginseer','imp_commissar'},
  sourceStructures={'imp_hq','imp_barracks','imp_tank_factory','imp_walker_factory','imp_generator','imp_mex','imp_thermo','imp_research','armestor','armmstor','armrad','armjamt','armnanotc','armmakr'},
 },
 Orks={
  structures={'corlab','corvp','ork_mek_shop','ork_settlement','corsolar','cormex','corgeo','corestor','cormstor','corrad','corjamt','cornanotc','cormakr','ork_waaagh_banner','ork_listening_post'},
  infantry={'corck','ork_grot','ork_boy','ork_meganob','ork_slugga','ork_burna','ork_tankbusta','ork_loota','ork_nob','ork_warboss'},
  tanks={'corcv','ork_wartrak','ork_trukk','ork_gunwagon','ork_lobba'},walkers={'ork_grot','ork_killa_kan','ork_deff_dread'},
  headquarters={'ork_grot','ork_warboss'},
  sourceStructures={'ork_settlement','ork_boyz_hut','ork_mek_shop','ork_mek_lab','ork_generator','ork_resource_factory','ork_listening_post','ork_waaagh_banner','corestor','cormstor','corrad','corjamt','cornanotc','cormakr','corgeo'},
 },
}
local visualFields={'objectname','script','buildpic','sfxtypes','collisionvolumetype','collisionvolumescales','collisionvolumeoffsets','selectionvolumetype','selectionvolumescales','selectionvolumeoffsets','footprintx','footprintz','upright'}
local function assets(d,diagnostic,key)
 local cp=d.customparams or {};local source=cp.animsource or (d.objectname and d.objectname:match("([^/]+)%.glb$"))
 if not source or not d.objectname or not d.script then return false end
 if not VFS.FileExists('objects3d/'..d.objectname) or not VFS.FileExists('scripts/'..d.script)
  or not VFS.FileExists('scripts/generated/'..source..'_anim.lua') then return false end
 return diagnostic or VFS.Include('40k_configs/development_playtest.lua').Allowed(key or source,Spring and Spring.GetModOptions and Spring.GetModOptions() or {}) or VFS.FileExists('40k_configs/validated/'..(key or source)..'.lua') or VFS.FileExists('40k_configs/validated/'..source..'.lua')
end
function M.Apply(defs,mode)
 if not mode and Spring and Spring.GetModOptions then mode=Spring.GetModOptions().prototype_diagnostic end
 local diagnostic=mode=='vital' or mode=='expandedproduction' or mode=='roster' or mode=='ui'
 local report={replaced={},blocked={},unmapped={},graphs={},diagnostic=diagnostic}
 local options=Spring and Spring.GetModOptions and Spring.GetModOptions() or {}
 local mixedSelected=mode=='benchmark' and tostring(options.prototype_mixed_force or '0')=='1' and VFS.Include('40k_configs/mixed_benchmark_exposure.lua').Selected(options) or nil
 mixedSelected=VFS.Include('40k_configs/mixed_v2_adapter.lua').Selected(options) or mixedSelected
 if mixedSelected then report.mixed_test_exposure=true end
 local accepted={}
 for key,d in pairs(defs)do
  if d.customparams and d.customparams.prototype40k and (assets(d,diagnostic,key) or (mixedSelected and mixedSelected[key] and assets(d,true,key))) then accepted[key]=true end
 end
 for key,rule in pairs(aliases)do
  local native,donor=defs[key],defs[rule[1]]
  if native and not mixedSelected then
   if not donor or not accepted[rule[1]] then report.blocked[#report.blocked+1]=key..':'..rule[1]
   else
    -- Costs, income, upkeep, build power, extraction and native special economy
    -- params remain the base role. No commander resources or build-speed grants.
    local out=clone(native);local cp=clone(native.customparams or {})
    for k,v in pairs(donor.customparams or {})do cp[k]=clone(v)end
    cp.prototype40k_vital=rule[3];cp.prototype40k_donor=rule[1]
    cp.unitgroup=(native.customparams or {}).unitgroup or (donor.customparams or {}).unitgroup or 'util'
    cp.balance_status='native_role_source_actor';cp.integration_status='native_acceptance_required'
    cp.iscommander=rule[3]=='commander' and true or nil
    cp.canwearcosmetics=nil;cp.spawnpad_unit=nil;cp.tombstone=nil
    out.canmanualfire=false
    if diagnostic then cp.diagnostic='roster' end
    out.customparams=cp;out.name=rule[2];out.description='40K '..rule[3]..' (native '..rule[3]..' function)'
    for _,field in ipairs(visualFields)do out[field]=clone(donor[field])end
    -- BAR skeleton weapons, corpses and legacy model hooks cannot survive an
    -- actor replacement. Genuine mounted guns keep their exact source markers.
    out.weapondefs=clone(donor.weapondefs);out.weapons=clone(donor.weapons);out.canattack=donor.canattack or false
    out.corpse=nil;out.featuredefs=nil;out.selfdestructas=nil;out.explodeas=nil
    out.usepiececollisionvolumes=false;out.usepieceselectionvolumes=false
    out.customparams.model_author=donor.customparams.model_author or 'private genuine source'
    out.customparams.subfolder='40k/vital';out.customparams.normaltex=nil;out.customparams.decal=nil
    out.buildinggrounddecaltype=nil;out.usebuildinggrounddecal=false
    if rule[3]=='commander' or rule[3]=='constructor' then
     out.speed=donor.speed;out.maxacc=donor.maxacc;out.maxdec=donor.maxdec;out.turnrate=donor.turnrate
     out.movementclass=donor.movementclass;out.maxwaterdepth=donor.maxwaterdepth;out.maxslope=donor.maxslope
     out.turninplace=true;out.canfly=false;out.cansubmerge=false
     cp.rosterrole='builder';cp.buildclip=rule[1]=='imp_enginseer' and 'build_1' or donor.customparams.buildclip
     out.builder=true;out.canrepair=true;out.canreclaim=true;out.canassist=true
    elseif rule[3]=='barracks' or rule[3]=='tank_factory' or rule[3]=='walker_factory' then
     out.builder=true;out.canmove=true;out.speed=0;out.movementclass=nil
     out.yardmap=string.rep('e',(out.footprintx or 1)*(out.footprintz or 1))
     cp.rosterrole=rule[3];cp.production_role=rule[3];cp.prototype40k_factory=rule[3]
    else
     out.speed=0;out.canmove=false;out.movementclass=nil
     -- Donor footprints can differ from BAR. Rebuild the non-factory blocking
     -- map at those dimensions; nil would erase native building/geo semantics.
     local x,z=out.footprintx or 1,out.footprintz or 1
     local cells=x*z
     if rule[3]=='geothermal' then
      local centre=math.floor((z-1)/2)*x+math.floor((x-1)/2)+1
      out.yardmap=string.rep('o',centre-1)..'g'..string.rep('o',cells-centre)
     else out.yardmap=string.rep('o',cells) end
     cp.rosterrole='support';cp.production_role=rule[3];cp.prototype40k_factory=nil
     if rule[3]=='repair' then out.builder=true;out.buildoptions={};out.canrepair=true;out.canassist=true end
    end
    defs[key]=out;accepted[key]=true;report.replaced[#report.replaced+1]=key
   end
  end
 end
 local function options(d,list)
  if not d then return end
  d.buildoptions={}
  if d.builder and (d.speed or 0)==0 then
   d.canmove=true;d.yardmap=string.rep('e',(d.footprintx or 1)*(d.footprintz or 1))
  end
  for _,key in ipairs(list)do if accepted[key] then d.buildoptions[#d.buildoptions+1]=key end end
 end
 for faction,r in pairs(rosters)do
  local prefix=faction=='Imperium' and 'arm' or 'cor'
  for _,key in ipairs({prefix..'com',prefix..'ck',prefix..'cv',prefix..'ack',prefix..'acv'})do
   if accepted[key]then options(defs[key],r.structures)end
  end
  local sourceBuilder=faction=='Imperium' and 'imp_enginseer' or 'ork_grot'
  if accepted[sourceBuilder]then options(defs[sourceBuilder],r.sourceStructures)end
  for _,key in ipairs({prefix..'lab',prefix..'alab',faction=='Imperium' and 'imp_barracks' or 'ork_boyz_hut'})do
   if accepted[key]then options(defs[key],r.infantry)end
  end
  if faction=='Imperium' then
   for _,key in ipairs({'armvp','armavp','imp_tank_factory'})do if accepted[key]then options(defs[key],r.tanks)end end
   if accepted.imp_walker_factory then options(defs.imp_walker_factory,r.walkers)end
   if accepted.imp_hq then options(defs.imp_hq,r.headquarters)end
  else
   for _,key in ipairs({'corvp','coravp','ork_mek_lab'})do if accepted[key]then options(defs[key],r.walkers)end end
   if accepted.ork_mek_shop then options(defs.ork_mek_shop,r.tanks)end
   if accepted.ork_settlement then options(defs.ork_settlement,r.headquarters)end
  end
 end
 -- Third faction provides its own real Lord/Scarab/Monolith graph. Its own marker
 -- gates remain authoritative; no ARM/COR alias is overwritten for Necrons.
 for key,d in pairs(defs)do
  if d.customparams and d.customparams.faction=='Necrons' and assets(d,diagnostic) then
   accepted[key]=true;report.graphs.Necrons='source_defined_lord_scarab_monolith'
  end
 end
 for key,d in pairs(defs)do
  if key:match('^arm') or key:match('^cor') then
   if not accepted[key] then report.unmapped[#report.unmapped+1]=key end
  end
  if d.buildoptions and (accepted[key] or (d.customparams or {}).faction=='Necrons') then
   local valid={};for _,target in ipairs(d.buildoptions)do if accepted[target]then valid[#valid+1]=target end end
   d.buildoptions=valid
  end
 end
 table.sort(report.replaced);table.sort(report.blocked);table.sort(report.unmapped)
 return report
end
M.Aliases=aliases;M.Rosters=rosters
return M
