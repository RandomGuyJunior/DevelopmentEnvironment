-- Apply after native air aliases/Fighta, before the sole O1 availability owner.
-- Static source parts are art only. No HQ, generator, research or airstrike code.
local M = {Version=1}
local rows = {
  {'fortyk_ork_air_factory', 1, 'Ork Airfield', 'ORK-AIR-1'},
  {'fortyk_ork_advanced_air_factory', 2, 'Ork Advanced Airfield', 'ORK-AIR-2'},
  {'fortyk_ork_super_air_factory', 3, 'Ork Gunship Airfield', 'ORK-AIR-3'},
}
local function clone(x)
  if type(x)~='table' then return x end
  local y={}; for k,v in pairs(x) do y[k]=clone(v) end; return y
end
function M.Apply(defs, geometry)
  local prepared={}
  -- Stage every requested replacement before touching shared UnitDefs.
  for _,r in ipairs(rows) do
    local key,tier,name,recipe=r[1],r[2],r[3],r[4]
    local g=geometry[key]
    if g then
      assert(g.recipe==recipe and g.export_verified and g.bounds and g.objectname and g.footprintx and g.footprintz, 'Missing exact composite receipt '..key)
      if tier==3 then assert(g.gunship_bounds and g.exact_bomba_tower, 'Actual Gunship shape and exact tower input pending') end
      local base=assert(defs[tier==3 and rows[2][1] or key], 'Native air donor missing '..key)
      assert(base.builder and base.canmove and base.yardmap and base.workertime, 'Native factory contract absent '..key)
      local d=clone(base);d.name=name;d.description='T'..tier..' Ork air production';d.objectname=g.objectname;d.script='40k_ork_static_factory.lua'
      d.footprintx=g.footprintx;d.footprintz=g.footprintz;d.yardmap=assert(g.yardmap)
      d.collisionvolumetype='box';d.collisionvolumescales=assert(g.collisionvolumescales);d.collisionvolumeoffsets=assert(g.collisionvolumeoffsets)
      d.usepiececollisionvolumes=false
      -- Clear the obsolete source script/appearance controls; native labor and
      -- buildtime values remain unchanged. O1 supplies the final product lists.
      local c=d.customparams or {};d.customparams=c
      for _,k in ipairs({'animsource','buildclip','native_recipe','source_root_piece','source_buildpiece','source_visibility','source_factory_recipe'}) do c[k]=nil end
      c.normaltex=nil;c.usebuildinggrounddecal=false
      for _,k in ipairs({'buildinggrounddecaltype','buildinggrounddecalsizex','buildinggrounddecalsizey','buildinggrounddecaldecayspeed'}) do c[k]=nil;d[k]=nil end
      d.usebuildinggrounddecal=false
      c.prototype40k_ork_v13_recipe=recipe;c.prototype40k_ork_v13_airfield=1
      c.prototype40k_factory_domain='air';c.prototype40k_factory_tier=tier;c.techlevel=tier;c.factory=1;c.rosterrole='air_factory'
      c.prototype40k_static_art_only=1;c.prototype40k_theme='ork_v13_composite';c.prototype40k_theme_pending=nil
      c.prototype40k_native_clearance_pending=not g.native_clearance_accepted and 1 or nil
      c.prototype40k_donor=key;c.prototype40k_tech_requires=key;c.prototype40k_shared_visual_source=nil
      c.i18n_en_humanname=name;c.i18n_en_tooltip=d.description
      -- New producer remains registered; O1 exclusively gates normal player/AI
      -- access and supplies its products. Do not independently toggle maxthisunit.
      if tier==3 then d.buildoptions={} end
      -- A single remains entitlement, reusing the native donor reclaim economics.
      local dead=clone(assert(d.featuredefs and d.featuredefs.dead,'Native dead feature missing'))
      dead.name='Airfield machinery scrap';dead.description='Salvageable Ork airfield machinery'
      dead.object='twisted_metal.glb';dead.featuredead='';dead.blocking=false;dead.indestructible=true;dead.resurrectable=0;dead.reclaimable=true;dead.flammable=false
      -- Genuine existing400-triangle machinery ruin, measured source bounds.
      -- Keep donor metal/energy/reclaimtime; no scenery fixed salvage price.
      dead.footprintx=4;dead.footprintz=4;dead.height=42.409271240234375
      dead.collisionvolumetype='box';dead.collisionvolumeoffsets='0 0 0'
      dead.collisionvolumescales='53.31148529 42.40927124 61.33053207'
      d.featuredefs={dead=dead};d.corpse='dead'
      prepared[key]=d
    end
  end
  local made={};for k,d in pairs(prepared) do defs[k]=d;made[#made+1]=k end
  table.sort(made);return {definitions=made,policy='ork_v13_static_airfields_v1'}
end
return M
