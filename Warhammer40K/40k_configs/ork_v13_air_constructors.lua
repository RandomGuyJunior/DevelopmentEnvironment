-- Authorised 13 October 2026 constructor substitutes. Final O1 owns all menus.
-- Apply after captured native air aliases and before O1. No geometry import,
-- combat placeholder, extra producer, grant or separate runtime resource owner.
local M={Version='ork_v13_temporary_native_air_constructors_v1'}
M.Rows={
 {'ork_mek_kopta','fortyk_ork_air_constructor','corca',1,'Mek Kopta','ORK-BLD-A1','smertolet (MOW-01)'},
 {'ork_big_mek_kopta','fortyk_ork_advanced_air_constructor','coraca',2,'Big Mek Kopta','ORK-BLD-A2','authored tandem-rotor smertolet (MOW-01)'},
}
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local function positive(v)return type(v)=='number'and v==v and v>0 and v<math.huge end
local function file(V,path)return V and V.FileExists and V.FileExists(path)end
function M.Apply(defs,V)
 local report={policy=M.Version,definitions={},pending={},nativeAccepted=false,temporaryAppearance=true}
 local prepared={}
 for _,r in ipairs(M.Rows)do
  local key,alias,donor,tier,name,recipe,target=unpack(r)
  local base=defs[alias];local c=base and base.customparams or{}
  if defs[key]then
   -- A genuine source implementation has priority. Never overwrite an existing
   -- stable identity or quietly rebind its art, costs or saved command semantics.
   report.pending[#report.pending+1]=key..':already_registered'
  elseif not base or base.builder~=true or base.canfly~=true or base.canmove~=true
   or c.faction~='Orks'or c.prototype40k_native_donor~=donor
   or c.prototype40k_constructor_domain~='air'or tonumber(c.prototype40k_constructor_tier)~=tier
   or not positive(base.metalcost)or not positive(base.energycost)or not positive(base.buildtime)
   or not positive(base.workertime)or not positive(base.builddistance)
   or type(base.objectname)~='string'or type(base.script)~='string'
   or not file(V,'objects3d/'..base.objectname)or not file(V,'scripts/'..base.script)then
   report.pending[#report.pending+1]=key..':native_alias_or_asset_closure'
  elseif base.corpse or base.wreckname or base.featuredefs then
   -- These pinned native aircraft have no wreck. Refuse changed donors rather
   -- than guessing which entitlement an inherited feature chain owns.
   report.pending[#report.pending+1]=key..':unexpected_native_salvage'
  elseif not file(V,'objects3d/twisted_metal.glb')
   or not file(V,'unittextures/twisted_metal_tex1.png')or not file(V,'unittextures/twisted_metal_tex2.png')then
   report.pending[#report.pending+1]=key..':machinery_scrap_closure'
  else
   local d=copy(base);c=d.customparams
   d.name=name;d.description='T'..tier..' Ork flying constructor; temporary native BAR '..donor..' appearance; replacement: '..target
   -- Clone actual native capabilities including COB build/repair presentation,
   -- movement, nano range, health and bills. O1 replaces the inherited menu.
   d.buildoptions={};d.weapons={};d.weapondefs={};d.canattack=false;d.canmanualfire=false
   c.prototype40k_donor=key;c.prototype40k_tech_requires=key;c.prototype40k_ork_v13_recipe=recipe
   c.prototype40k_constructor_domain='air';c.prototype40k_constructor_tier=tier;c.techlevel=tier
   c.rosterrole='constructor';c.faction='Orks';c.prototype40k_constructor_singleton=1;c.iscommander=nil
   c.prototype40k_temporary_constructor_appearance=1;c.prototype40k_constructor_replacement_target=target
   c.prototype40k_constructor_appearance_note='Temporary native BAR '..donor..' appearance; replacement: '..target
   c.prototype40k_native_clearance_pending=1;c.prototype40k_availability_reason=nil
   c.i18n_en_humanname=name;c.i18n_en_tooltip=d.description
   -- One native death feature; no spawned salvage controller or second payout.
   -- Matches the reviewed genuine-Kopta machinery policy. Cancellation remains
   -- governed by the engine's unfinished-unit feature/resource scaling.
   d.corpse='dead';d.featuredefs={dead={name=name..' machinery scrap',description='Salvageable Ork aircraft machinery',
    object='twisted_metal.glb',blocking=false,reclaimable=true,resurrectable=0,indestructible=true,flammable=false,
    featuredead='',damage=750,health=750,metal=d.metalcost*.25,energy=d.energycost*.25,
    reclaimtime=math.max(30,math.min(6000,d.buildtime*.25)),footprintx=4,footprintz=4,height=42.409271240234375,
    collisionvolumetype='box',collisionvolumescales='53.31148529 42.40927124 61.33053207',collisionvolumeoffsets='0 0 0',
    customparams={prototype40k_kopta_salvage=1,parent_actor=key}}}
   -- Both retained native COB scripts return corpse levels 1, 2 or 3 according
   -- to lethal severity. Native CreateWreckage selects one member of this chain,
   -- never three features. Equal resources preserve the one death entitlement
   -- at every severity; indestructibility prevents later combat transitions.
   d.featuredefs.dead.featuredead='dead_medium'
   d.featuredefs.dead_medium=copy(d.featuredefs.dead);d.featuredefs.dead_medium.featuredead='dead_severe'
   d.featuredefs.dead_severe=copy(d.featuredefs.dead);d.featuredefs.dead_severe.featuredead=''
   prepared[key]=d
  end
 end
 -- Both roles share one bounded contract. No partial registration after refusal.
 if #report.pending>0 then return report end
 for _,r in ipairs(M.Rows)do local key=r[1];defs[key]=prepared[key];report.definitions[#report.definitions+1]=key end
 return report
end
return M
