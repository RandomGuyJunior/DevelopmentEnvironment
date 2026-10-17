-- Four distinct paid native constructor identities. O1 exclusively owns menus.
-- The existing genuine repair-capable Big Mek actor is a declared shared visual
-- adaptation for the three Ork/Mek roles, never a copied commander or KFF unit.
local M={}
M.Rows={
 wh40k_corck={id='ORK-BLD-I1',domain='infantry',tier=1,name='Gretchin Builder',actor='ork_grot'},
 wh40k_corack={id='ORK-BLD-I2',domain='infantry',tier=2,name='Ork Builder',actor='ork_big_mek_defence'},
 wh40k_corcv={id='ORK-BLD-V1',domain='vehicle',tier=1,name='Mek Builder',actor='ork_big_mek_defence'},
 wh40k_coracv={id='ORK-BLD-V2',domain='vehicle',tier=2,name='Big Mek Constructor',actor='ork_big_mek_defence'},
}
local order={'wh40k_corck','wh40k_corack','wh40k_corcv','wh40k_coracv'}
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local function positive(v)return type(v)=='number'and v>0 and v<math.huge end
function M.Apply(defs,V)
 local report={changed={},pending={}}
 for _,key in ipairs(order)do
  local d=defs[key];local cp=d and d.customparams or{};local r=M.Rows[key]
  local knownVisual=d and d.script=='40k_roster.lua'and
   ((d.objectname=='ork_grot.glb'and cp.animsource=='ork_grot')or
    (d.objectname==r.actor..'.glb'and cp.animsource==r.actor and cp.prototype40k_ork_v13_recipe==r.id))
  if not d or not d.builder or cp.faction~='Orks'or cp.iscommander or cp.prototype40k_squad_profile_id
   or not knownVisual
   or cp.prototype40k_constructor_domain~=r.domain or tonumber(cp.prototype40k_constructor_tier)~=r.tier
   or cp.prototype40k_economy_template~=key or not positive(d.metalcost)or not positive(d.energycost)
   or not positive(d.buildtime)or not positive(d.workertime)then
   report.pending[#report.pending+1]=key..':native_constructor_identity'
  end
  for _,path in ipairs({'objects3d/'..r.actor..'.glb','scripts/generated/'..r.actor..'_anim.lua','unittextures/'..r.actor..'_tex1.png','unittextures/'..r.actor..'_tex2.png','unitpics/40k_'..r.actor..'.png','scripts/40k_roster.lua'})do
   if not(V and V.FileExists and V.FileExists(path))then report.pending[#report.pending+1]=key..':source_assets_missing';break end
  end
 end
 -- Atomic four-role update; a missing actor never substitutes a placeholder.
 if #report.pending>0 then return report end
 for _,key in ipairs(order)do
  local r=M.Rows[key];local out=copy(defs[key]);local cp=out.customparams
  out.name=r.name;out.description='T'..r.tier..' '..r.domain..' constructor; builds T1-T'..(r.tier+1)..' structures'
  cp.i18n_en_humanname=r.name;cp.i18n_en_tooltip=out.description;cp.prototype40k_short_role='T'..r.tier..' '..r.domain..' constructor'
  cp.prototype40k_ork_v13_recipe=r.id;cp.prototype40k_donor=r.actor;cp.prototype40k_shared_visual_source=r.actor
  cp.animsource=r.actor;cp.rosterrole='builder';cp.unitgroup='builder';cp.iscommander=nil
  cp.prototype40k_constructor_singleton=1;cp.constructor_visual_source=r.actor
  cp.constructor_visual_acceptance='native_review_pending'
  if key~='wh40k_corck'then
   out.objectname=r.actor..'.glb';out.script='40k_roster.lua';out.buildpic='40k_'..r.actor..'.png'
   out.collisionvolumetype='CylY';out.collisionvolumescales=nil;out.collisionvolumeoffsets='0 0 0'
   out.selectionvolumetype=nil;out.selectionvolumescales=nil;out.selectionvolumeoffsets=nil
   out.usepiececollisionvolumes=false;out.usepieceselectionvolumes=false
   cp.root_bone='bip01 pelvis';cp.source_buildclip='build';cp.buildclip='build';cp.source_nanopiece='marker_big_mek_axe_blade'
   cp.source_buildpiece=nil;cp.buildpiece=nil;cp.nanopiece=nil;cp.source_passive_mounts=nil
   cp.constructor_visual_adaptation='Shared genuine Big Mek choppa_repair actor; no KFF/combat/commander role imported'
   -- No donor UnitDef is cloned: native construction bills, health and reach,
   -- current menus, native repair/reclaim/assist and paid upgrade identity survive.
   out.weapondefs={};out.weapons={};out.canattack=false;out.canmanualfire=false
   cp.source_voice_profile=nil;cp.source_voice_kind=nil -- following ordinary audio pass selects actual actor
   cp.locomotion_source_stride=nil -- following ordinary locomotion pass selects actual actor
  end
  defs[key]=out;report.changed[#report.changed+1]=key
 end
 return report
end
return M
