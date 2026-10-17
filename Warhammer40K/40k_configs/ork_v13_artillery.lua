-- Fixed Ork artillery entries. Native weapons/payment/death remain the owners.
-- Only small offline facts are read here; model geometry is demanded on first use.
local M={Version=1}
M.Products={
 ork_boomy_platform={id='ORK-ART-1',label='Boomy Platform',tier=1,minimumBuilderTier=1,
  metal=240,energy=1200,work=4800,health=2400,range=1050,minimumRange=140,damage=160,blast=60,reload=3.5,
  entity='attrib/ebps/races/orks/structures/ork_boomy_platform.lua',entityHash='aec041924079094a2e1191268bbbf7833a5a5fbc94dc889b1c477905dab8644f',
  weapon='attrib/weapon/ork_lobba_boomy_platform.lua',weaponHash='2a4e404aba899c6189b48e7d172ee848ef6c6d18054c14a4e3243649775b0dc6'},
 ork_kaboomy_platform={id='ORK-ART-2',label='Supa Kaboomy Platform',tier=2,minimumBuilderTier=2,
  metal=1100,energy=6000,work=18000,health=6000,range=1500,minimumRange=220,damage=650,blast=120,reload=6,
  entity='attrib/ebps/races/orks/structures/ork_supa_boomy_platform.lua',entityHash='8a193b75c5781eb49a074b232cff791893c6e8292494d888a7d1f51e81ecbd80',
  weapon='attrib/weapon/ork_lobba_boomy_platform_kaboom.lua',weaponHash='f52af5fc84f0d73ec2617f2e933ed6d2443f3af860938150eaba3f31b31aa68a'},
}
local modelHash='b5ed436c5feac180b84b79a577d3743d35ae1455e8fe083d60f8bcd2471bec6e'
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function sha(v)return type(v)=='string'and #v==64 and v:match('^[0-9a-f]+$')end
function M.Yard(bounds,tight)
 assert(type(bounds)=='table'and type(bounds.min)=='table'and type(bounds.max)=='table','Offline completed envelope required')
 for i=1,3 do assert(finite(bounds.min[i])and finite(bounds.max[i])and bounds.max[i]>bounds.min[i],'Invalid completed envelope')end
 local function size(a)
  local half=math.max(math.abs(bounds.min[a]),math.abs(bounds.max[a]))
  -- A native construction tile is16 elmos. No artificial two-elmo margin
  -- or even-tile expansion for the measured uniformly resized ART1.
  if tight then return math.max(1,math.ceil(half/8))end
  local n=math.max(2,math.ceil((half+2)/8));return n+n%2
 end
 local x,z=size(1),size(3);assert(x<=64 and z<=64,'Unreviewed artillery building envelope')
 return x,z,string.rep('o',x*z)
end
function M.Build(key,V,facts)
 local row=assert(M.Products[key],'Unknown fixed artillery product')
 if type(facts)~='table'then return nil,'generated_bundle_pending'end
 if facts.key~=key or facts.recipe~=row.id or facts.object~=key..'.glb' or facts.bank~=key
  or facts.source_entity_sha256~=row.entityHash or facts.source_model_sha256~=modelHash
  or not sha(facts.generated_glb_sha256) then return nil,'generated_bundle_identity'end
 if key=='ork_boomy_platform'and facts.visual_scale_policy~=nil and facts.visual_scale_policy~='whole_platform_slugga_limb_reference_v1'then return nil,'unknown_boomy_visual_policy'end
 if key=='ork_kaboomy_platform'and(facts.crew_count~=3 or facts.crew_contacts_verified~=true or facts.platform_scale~=2)then return nil,'independent_crew_contacts_pending'end
 if type(facts.pieces)~='table'then return nil,'actual_artillery_pieces_pending'end
 for _,piece in ipairs({'marker_main_barrel','bone_main_aim_horz','bone_main_aim_vert'})do
  if facts.pieces[piece]~=true then return nil,'missing_artillery_piece_'..piece end
 end
 local tight=key=='ork_boomy_platform'and facts.visual_scale_policy=='whole_platform_slugga_limb_reference_v1'
 if tight and(facts.visual_uniform_scale~=0.839551115548091 or facts.visual_aim_policy~='low_arc_absolute_bind20_max45_v1'
  or facts.placement_bounds_kind~='completed_pose_allowed_aim_proven_minimum_tiles_v1')then return nil,'boomy_visual_recipe_pending'end
 local x,z,yard;local valid;valid,x,z,yard=pcall(M.Yard,facts.bounds,tight)
 if not valid then return nil,'completed_envelope_required'end
 local midpoint=facts.native_bind_midpoint
 if facts.collision_offset_policy~='posed_centre_minus_native_bind_midpoint_v1' or facts.native_bind_model_sha256~=facts.generated_glb_sha256
  or type(midpoint)~='table' or #midpoint~=3 then return nil,'native_bind_midpoint_pending'end
 for i=1,3 do if not finite(midpoint[i])then return nil,'native_bind_midpoint_pending'end end
 local proof=facts.native_bind_midpoint_proof
 if type(proof)~='table' or proof.midpoint_overrides_absent~=true or proof.native_axes_importer_rotation_cancels~=true
  or not finite(proof.piece_partition_roundtrip_error) or proof.piece_partition_roundtrip_error>0.0001
  or type(proof.source)~='table' or proof.source['ModelUtils.cpp']~='a8f8ae34c93b91a73ec5009cd011431ae22fc47b611615b24aa5e30698269ccb'
  then return nil,'native_bind_midpoint_pending'end
 for _,path in ipairs({'objects3d/'..key..'.glb','objects3d/'..key..'.glb.lua',
  'scripts/generated/'..key..'_anim.lua','scripts/40k_roster.lua',
  'unittextures/'..key..'_tex1.png','unittextures/'..key..'_tex2.png','unitpics/40k_ork_boomy_platform.png',
  'scripts/generated/ork_primary_pose_profiles.lua','40k_configs/ork_primary_completed_pose_layers.lua','40k_configs/ork_primary_native_minrange.lua',
  'effects/40k_ork_artillery_fx.lua','effects/40k_expansion_weapon_fx.lua',
  'objects3d/twisted_metal.glb','unittextures/twisted_metal_tex1.png','unittextures/twisted_metal_tex2.png'})do
  if not V.FileExists(path)then return nil,'missing_'..path end
 end
 local b=facts.bounds;local extent,centre={},{}
 -- Native GLTF sets model.relMidPos from the bind envelope. Collision offsets
 -- are added to that midpoint, so only the delta reaches our posed-box centre.
 for i=1,3 do extent[i]=b.max[i]-b.min[i];centre[i]=(b.min[i]+b.max[i])/2-midpoint[i] end
 -- Provisional balance values deliberately replace source HQ/population and
 -- in-place upgrade rules. One visible barrel supplies one native damage path.
 local description='Fixed T'..row.tier..' artillery; '..row.minimumRange..'-'..row.range..' range; T'..row.minimumBuilderTier..' constructors'
 local d={name=row.label,description=description,objectname=key..'.glb',script='40k_roster.lua',buildpic='40k_ork_boomy_platform.png',
  metalcost=row.metal,energycost=row.energy,buildtime=row.work,health=row.health,
  speed=0,canmove=false,canfly=false,builder=false,canattack=true,buildoptions={},
  footprintx=x,footprintz=z,yardmap=yard,maxslope=24,maxwaterdepth=0,sightdistance=430,upright=true,
  category='ALL NOTSUB SURFACE',collisionvolumetype='Box',collisionvolumescales=table.concat(extent,' '),collisionvolumeoffsets=table.concat(centre,' '),
  selectionvolumetype='Box',selectionvolumescales=table.concat(extent,' '),selectionvolumeoffsets=table.concat(centre,' '),
  energymake=0,energyupkeep=0,extractsmetal=0,metalmake=0,makesmetal=0,metalstorage=0,energystorage=0,
  customparams={faction='Orks',prototype40k=1,animsource=key,rosterrole='defence',unitgroup='weapon',techlevel=row.tier,prototype40k_fixed_artillery_native_wreck=1,
   prototype40k_ork_v13_recipe=row.id,prototype40k_source_progression=1,prototype40k_donor=key,prototype40k_tech_requires=key,
   source_entity=row.entity,source_entity_sha256=row.entityHash,source_model_sha256=modelHash,source_native_glb_sha256=facts.generated_glb_sha256,
   source_completed_pose_profile='ork_boomy_platform',building_placement_policy='origin_envelope_v1',building_placement_model=facts.generated_glb_sha256,
   prototype40k_minimum_builder_tier=row.minimumBuilderTier,prototype40k_balance_policy='provisional_fixed_artillery_v1',
   i18n_en_humanname=row.label,i18n_en_tooltip=description,prototype40k_short_role=description,prototype40k_ui_description=description}}
 d.weapondefs={mount1={name=row.label..' Lobba',weapontype='Cannon',range=row.range,reloadtime=row.reload,weaponvelocity=290,
  turret=true,tolerance=4000,hightrajectory=1,areaofeffect=row.blast,edgeeffectiveness=.35,cratermult=0,impulsefactor=0,
  collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,
  avoidfriendly=true,avoidfeature=false,damage={default=row.damage},size=1,stages=2,rgbcolor='1 .8 .3',
  explosiongenerator='custom:40k_ork_artillery_t'..row.tier..'_impact',customparams={source_weapon=row.weapon,source_weapon_sha256=row.weaponHash,
   source_muzzle='marker_main_barrel',source_aimpiece='bone_main_aim_horz',source_pitchpiece='bone_main_aim_vert',source_fireclip='fire',
   source_aimfrom_muzzle=1,source_minrange=row.minimumRange,source_muzzlefx='40k_dow_artillery_muzzle',source_fx_family='artillery'}}}
 if tight then
  d.customparams.source_boomy_aim_policy='low_arc_absolute_bind20_max45_v1'
  d.customparams.source_boomy_uniform_scale=facts.visual_uniform_scale
  d.customparams.building_placement_policy='boomy_actual_origin_envelope_tight_v1'
  -- Supported native low trajectory; do not alter the ballistic solution.
  -- Unsafe uphill solutions are refused by script, never visually clamped.
  d.weapondefs.mount1.hightrajectory=0
  if not V.FileExists('scripts/40k_boomy_aim.lua')then return nil,'missing_boomy_aim_module'end
 end
 d.weapons={{def='mount1',onlytargetcategory='SURFACE'}}
 -- Only the native completed death path owns this one salvage entitlement.
 -- Cancellation/reclaim skip Killed; no manual creation, refund or expiry.
 d.corpse='artillery_scrap'
 d.featuredefs={artillery_scrap={name=row.label..' machinery scrap',description='Reclaimable Ork artillery remains',object='twisted_metal.glb',
  blocking=false,reclaimable=true,autoreclaimable=true,resurrectable=0,indestructible=true,flammable=false,damage=100,health=100,
  metal=row.metal*.25,energy=row.energy*.25,reclaimtime=math.min(6000,row.work*.25),footprintx=4,footprintz=4,featuredead='',
  customparams={prototype40k_ork_v13_artillery_wreck=1,source_scenery='art/ebps/environment/urban/dressing/dressing_twistedmetal_01.whm'}}}
 return d
end
function M.Apply(defs,V,ready)
 local report={changed={},pending={}};ready=ready or{}
 for _,key in ipairs({'ork_boomy_platform','ork_kaboomy_platform'})do
  local d,why=M.Build(key,V,ready[key])
  if d then
   local previous=defs[key];local cp=previous and previous.customparams or{}
   assert(not previous or cp.prototype40k_ork_v13_recipe==M.Products[key].id or
    (key=='ork_boomy_platform'and previous.objectname=='ork_boomy_platform.glb'and cp.source_model_sha256==modelHash),
    'Refuse foreign artillery definition overwrite')
   defs[key]=d;report.changed[#report.changed+1]=key
  else
   assert(not(key=='ork_boomy_platform'and ready[key]and ready[key].visual_scale_policy~=nil),'Refuse incomplete Boomy derivative: '..tostring(why))
   report.pending[key]=why
  end
 end
 return report
end
return M
