-- Explicit presentation adaptation; stable native armcom/corcom identities remain.
local M={}
local choices={Orks={key='ork_big_mek_commander',donor='ork_big_mek_defence',name='Big Mek Commander',build='build',nano='marker_big_mek_axe_blade'},Imperium={key='imp_field_commander',donor='imp_force_commander_candidate',name='Imperial Force Commander',build='command_build',nano='bip01 l hand'}}
local function copy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
local fields={'objectname','script','buildpic','sfxtypes','collisionvolumetype','collisionvolumescales','collisionvolumeoffsets','selectionvolumetype','selectionvolumescales','selectionvolumeoffsets','footprintx','footprintz','upright','speed','maxacc','maxdec','turnrate','movementclass','maxslope','maxwaterdepth','weapondefs','weapons','canattack'}
function M.Apply(defs,config)
 if not config or not config.enabled then return true,'inactive'end
 if type(config.Ready)~='function'then return false,'missing_asset_role_review'end
 local plans={}
 for _,faction in ipairs({'Imperium','Orks'})do
  if config.factions and config.factions[faction]then
   local c=choices[faction];local old,d=defs[c.key],defs[c.donor]
   if not old or not d or not old.builder then return false,'missing_stable_builder:'..c.key end
   local cp=d.customparams or{}
   if cp.faction~=faction or tostring(cp.prototype40k)~='1'or not d.objectname or d.script~='40k_roster.lua'then return false,'wrong_source_actor'end
   local ok,ready=pcall(config.Ready,c.donor,c.build,c.nano,d);if not ok or not ready then return false,'unreviewed_presentation:'..c.donor end
   local out=copy(old);for _,field in ipairs(fields)do out[field]=copy(d[field])end
   out.customparams=copy(old.customparams or{})
   for k,v in pairs(cp)do out.customparams[k]=copy(v)end
   local p=out.customparams;p.unitgroup=(old.customparams or{}).unitgroup or'builder';p.iscommander=true;p.prototype40k_vital='commander';p.prototype40k_donor=c.donor;p.rosterrole='builder';p.source_buildclip=c.build;p.source_nanopiece=c.nano;p.commander_presentation_adaptation=1
   out.name=c.name;out.description=faction..' founding commander; native economy and construction'
   out.canmanualfire=false;out.corpse=nil;out.featuredefs=nil;out.selfdestructas=nil;out.explodeas=nil
   out.canwearcosmetics=nil;p.canwearcosmetics=nil;p.spawnpad_unit=nil;p.tombstone=nil
   out.usepiececollisionvolumes=false;out.usepieceselectionvolumes=false;plans[c.key]=out
  end
 end
 for key,value in pairs(plans)do defs[key]=value end
 return true
end
return M
