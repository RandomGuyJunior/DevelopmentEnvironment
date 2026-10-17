-- Conditional UI metadata; include after the accepted vital/source roster overlay.
-- No static native-name aliases: an unchanged BAR actor never enters this path.
local M={}
local validGroups={energy=true,metal=true,builder=true,buildert2=true,buildert3=true,buildert4=true,
 util=true,weapon=true,explo=true,weaponaa=true,weaponsub=true,aa=true,emp=true,sub=true,nuke=true,antinuke=true}
local roles={commander="Commander / builder",constructor="Builds, repairs and reclaims",
 generator="Generates energy",geothermal="Generates energy at geothermal vents",thermo="Generates energy at geothermal vents",
 extractor="Extracts metal from deposits",mex="Extracts metal from deposits",energy_storage="Stores energy",metal_storage="Stores metal",
 storage="Stores energy and metal",radar="Long-range surveillance",jammer="Disrupts enemy sensors",
 repair="Repairs and assists nearby units",converter="Converts energy into metal",support="Support structure"}
local factories={
 imp_barracks="Produces Imperial Guard infantry",imp_tank_factory="Produces Guard tanks, artillery and Sentinels",imp_walker_factory="Produces Marine armour and Dreadnoughts",
 ork_boyz_hut="Produces Ork infantry",ork_mek_shop="Produces Ork vehicles",ork_mek_lab="Produces Ork walkers",
 ork_settlement="Produces Ork builders and leaders",imp_hq="Produces Guard engineers and leaders",
 nec_hq="Produces Necron builders and leaders",nec_core="Summons Necron infantry",nec_greater_core="Summons Necron heavy units and walkers",
}
local function necronDescription(source,d)
 if source=='nec_nightbringer'then return 'Necron Lord manifestation; ranged life drain and scythe combat. Returns to Lord form; invulnerability requires earned Relic and paid Archive research.' end
 if source=='nec_lord'then return (d.builder==true and 'Necron commander; staff and blade combat, builds Necron structures. Paid Archive research unlocks Nightbringer manifestation.' or 'Necron leader; staff and blade combat. Nightbringer manifestation requires paid Archive research.') end
 if source=='nec_scarab'then return 'Necron constructor; builds structures and captures strategic Relics.' end
 if source=='40k_relic_objective'then return 'Neutral strategic Relic; earned Scarab capture permits relevant paid research. Produces no units or resources.' end
end
local function marked(value) return value==true or value==1 or value=='1' end
function M.Apply(defs,fileExists)
 fileExists=fileExists or VFS.FileExists
 local report={accepted={},skipped={},groups={}}
 for key,d in pairs(defs) do
  local cp=d.customparams or {}
  -- The baseline tank runtime uses the model stem directly instead of CP
  -- animsource. Infer only that stem; still require the real animation file.
  local source=cp.animsource or (d.objectname and d.objectname:match('([^/]+)%.glb$'))
  local real=marked(cp.prototype40k) and source and d.objectname and d.script
   and fileExists('objects3d/'..d.objectname) and fileExists('scripts/'..d.script)
   and fileExists('scripts/generated/'..source..'_anim.lua')
  if real then
   -- Normal/diagnostic acceptance remains owned by the roster/vital gate. This
   -- helper operates only on definitions those gates actually supplied.
   local name=d.name
   local role=cp.prototype40k_vital or cp.production_role or cp.rosterrole
   local donor=cp.prototype40k_donor or key
   local description=necronDescription(source,d) or (role=='research' and d.description) or roles[role] or factories[donor] or d.description
   if type(name)=='string' and name~='' then
    cp.prototype40k_ui_name=name
    cp.prototype40k_ui_description=description or name
    -- Native tweakdefs widget supports these keys. Existing explicit user
    -- translations, including English, take precedence over project defaults.
    cp.i18n_en_humanname=cp.i18n_en_humanname or name
    cp.i18n_en_tooltip=cp.i18n_en_tooltip or description or name
    -- An inherited BAR proxy would translate another actor and bypass these
    -- per-definition labels (for example a raised repair station's own name).
    cp.i18nfromunit=nil
    cp.prototype40k_ui_ready=1
    d.customparams=cp
    report.accepted[#report.accepted+1]=key
   end
   local originalGroup=cp.unitgroup
   local nativeVital=cp.prototype40k_vital~=nil
   -- Preserve accepted native vital-role categories, including advanced builders
   -- and AA, but do not preserve a generic source 'weapon'/'util' default when
   -- the actual primary function is production, economy or sensor support.
   if not nativeVital or not validGroups[originalGroup] then
    local group='util'
    if (tonumber(d.extractsmetal) or 0)>0 then group='metal'
    elseif marked(d.builder) then
     group=(originalGroup and originalGroup:match('^builder') and validGroups[originalGroup]) and originalGroup or 'builder'
    elseif (tonumber(d.energymake) or 0)>0 or marked(d.geothermal) then group='energy'
    elseif (role=='research' or role=='support' or role=='radar' or role=='storage')
     and ((tonumber(d.radardistance) or 0)>0 or (tonumber(d.sonardistance) or 0)>0
      or (tonumber(d.energystorage) or 0)>0 or (tonumber(d.metalstorage) or 0)>0) then group='util'
    elseif d.weapons and #d.weapons>0 then
     group=(validGroups[originalGroup] and originalGroup~='util' and originalGroup~='energy' and originalGroup~='metal'
       and not originalGroup:match('^builder')) and originalGroup or 'weapon'
    elseif validGroups[originalGroup] then group=originalGroup end
    if group~=originalGroup then cp.unitgroup=group;report.groups[#report.groups+1]=key..':'..group end
   end
  else report.skipped[#report.skipped+1]=key end
 end
 table.sort(report.accepted);table.sort(report.skipped);table.sort(report.groups)
 return report
end
return M
