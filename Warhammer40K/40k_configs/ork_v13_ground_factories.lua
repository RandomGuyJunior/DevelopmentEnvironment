-- Source-art factories only. O1 owns final menus and availability; this module
-- registers nothing until coordinator-preflighted physical composite facts exist.
local M={Schema=1,Script='40k_ork_static_factory.lua'}
M.RecipePins=VFS.Include('40k_configs/ork_v13_ground_factory_recipes.lua')
M.Rows={
 ork_boyz_hut_t2={id='ORK-INF-2',name='Expanded Da Boyz Hut',icon='ork_boyz_hut',tier=2,domain='infantry',metal=1200,energy=7200,work=16000,power=200,health=4500},
 ork_warcamp={id='ORK-INF-3',name='Ork Warcamp',icon='ork_settlement',tier=3,domain='infantry',metal=3000,energy=20000,work=35000,power=320,health=9000},
 ork_mek_lab_t3={id='ORK-VEH-3',name='Expanded Mek Lab',icon='ork_mek_lab',tier=3,domain='vehicle',metal=4200,energy=26000,work=50000,power=400,health=12000},
}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function vector(v)
 return type(v)=='table'and finite(v[1])and finite(v[2])and finite(v[3])and v[4]==nil
end
local function digest(v)return type(v)=='string'and #v==64 and not v:find('[^0-9a-f]')end
function M.Yard(mn,mx,x,z)
 local cells={}
 for row=0,z-1 do for col=0,x-1 do
  local bx,bz=(col-x/2)*16,(row-z/2)*16
  cells[#cells+1]=(bx<mx[1]and bx+16>mn[1]and bz<mx[3]and bz+16>mn[3])and'o'or'e'
 end end
 return table.concat(cells)
end
function M.Build(key,f,V)
 local r=M.Rows[key];if not r then return nil,'unknown_factory'end
 if not f then return nil,'composite_not_generated'end
 if f.schema~=M.Schema or f.key~=key or f.designID~=r.id or f.preflight~='physical_composite_v1'
  or f.recipeSHA256~=M.RecipePins[key]or not digest(f.modelSHA256)then return nil,'composite_identity'end
 if not(vector(f.boundsMin)and vector(f.boundsMax)and vector(f.buildPad))then return nil,'measured_bounds'end
 local sx,sy,sz=f.boundsMax[1]-f.boundsMin[1],f.boundsMax[2]-f.boundsMin[2],f.boundsMax[3]-f.boundsMin[3]
 if sx<=0 or sy<=0 or sz<=0 then return nil,'empty_bounds'end
 local x,z=f.footprintX,f.footprintZ
 if not(finite(x)and finite(z)and x>0 and z>0 and x==math.floor(x)and z==math.floor(z)and x<=64 and z<=64)then return nil,'yard_dimensions'end
 if f.yardRevision~=2 or f.yardmap~=M.Yard(f.boundsMin,f.boundsMax,x,z)then return nil,'yard_contract'end
 if not vector(f.predictedModelMidpoint)or not vector(f.collisionOffsets)then return nil,'model_midpoint'end
 for i=1,3 do
  -- Pinned Recoil Lua uses binary32 numbers. Endpoint literal rounding,
  -- addition rounding and separately serialized midpoint rounding each cost
  -- at most u*M here, where u=2^-24 and M=max(1,abs(min),abs(max)).
  -- Four u*M covers those three contributions and tolerance rounding itself.
  local midpoint=(f.boundsMin[i]+f.boundsMax[i])/2
  local tolerance=2^-22*math.max(1,math.abs(f.boundsMin[i]),math.abs(f.boundsMax[i]))
  if math.abs(f.predictedModelMidpoint[i]-midpoint)>tolerance or f.collisionOffsets[i]~=0 then return nil,'model_midpoint'end
 end
 if not finite(f.productRadiusBudget)or not finite(f.clearanceMargin)or f.productRadiusBudget<=0 or f.clearanceMargin<8 then return nil,'clearance_contract'end
 if f.buildPad[3]-f.productRadiusBudget-f.boundsMax[3]<f.clearanceMargin then return nil,'front_release_overlap'end
 if math.max(math.abs(f.boundsMin[1]),math.abs(f.boundsMax[1]),math.abs(f.buildPad[1])+f.productRadiusBudget)+8>x*8
  or math.max(math.abs(f.boundsMin[3]),math.abs(f.boundsMax[3]),math.abs(f.buildPad[3])+f.productRadiusBudget)+8>z*8 then return nil,'footprint_envelope'end
 if not(V and V.FileExists and V.FileExists('objects3d/'..key..'.glb')and V.FileExists('scripts/'..M.Script)
  and V.FileExists('unittextures/'..key..'_tex1.png')and V.FileExists('unittextures/'..key..'_tex2.png'))then return nil,'physical_assets_missing'end
 for _,p in ipairs({'objects3d/twisted_metal.glb','unittextures/twisted_metal_tex1.png','unittextures/twisted_metal_tex2.png'})do
  if not V.FileExists(p)then return nil,'machinery_scrap_missing'end
 end
 local description='T'..r.tier..' '..r.domain..' production'
 local d={name=r.name,description=description,objectname=key..'.glb',script=M.Script,
  buildpic='40k_'..r.icon..'.png',metalcost=r.metal,energycost=r.energy,buildtime=r.work,workertime=r.power,health=r.health,
  builder=true,canmove=true,speed=0,maxvelocity=0,canfly=false,canattack=false,canassist=true,canrepair=true,
  builddistance=200,buildoptions={},weapondefs={},weapons={},footprintx=x,footprintz=z,yardmap=f.yardmap,maxslope=16,maxwaterdepth=0,
  sightdistance=550,category='ALL NOTSUB SURFACE',reclaimable=true,metalmake=0,energymake=0,energyuse=0,
  collisionvolumetype='Box',collisionvolumescales=table.concat({sx,sy,sz},' '),
  -- Native GLTF model midpoint already equals the full measured body centre.
  collisionvolumeoffsets='0 0 0',
  customparams={faction='Orks',prototype40k=1,prototype40k_four_faction=1,prototype40k_source_progression=1,
   prototype40k_native_factory_pilot=1,prototype40k_ork_v13_recipe=r.id,
   prototype40k_factory_domain=r.domain,prototype40k_factory_tier=r.tier,techlevel=r.tier,factory=1,
   prototype40k_tech_requires=key,prototype40k_donor=key,rosterrole=r.domain=='vehicle'and'tank_factory'or'infantry_factory',
   production_role=r.domain=='vehicle'and'tank_factory'or'infantry_factory',unitgroup='builder',
   i18n_en_humanname=r.name,i18n_en_tooltip=description,prototype40k_short_role=description,
   source_composite_recipe_sha256=f.recipeSHA256,source_composite_model_sha256=f.modelSHA256,
   source_static_completed_pose=1,source_composite_decorations_only=1,
   source_native_acceptance='pending',source_remains_acceptance='native_binding_pending_game_test',
   source_economic_adaptation='Orks v1.3 provisional factory costs and work rates; one queue; no decorative generator income'}}
 -- One native completed-unit death entitlement, following the O2/O9 policy.
 -- Cancellation/reclaim skip Killed; no spawned feature or second resource owner.
 d.corpse='machinery_scrap'
 d.featuredefs={machinery_scrap={name='Ork factory machinery scrap',description='Salvageable Ork factory machinery',object='twisted_metal.glb',
  blocking=false,reclaimable=true,autoreclaimable=true,resurrectable=0,indestructible=true,flammable=false,damage=100,health=100,
  metal=d.metalcost*.25,energy=d.energycost*.25,reclaimtime=math.max(30,math.min(6000,d.buildtime*.25)),
  footprintx=4,footprintz=4,featuredead='',collisionvolumeoffsets='0 0 0',
  customparams={prototype40k_ork_v13_factory_wreck=1,source_scenery='art/ebps/environment/urban/dressing/dressing_twistedmetal_01.whm'}}}
 return d
end
function M.Apply(defs,facts,V)
 local report={registered={},missing={}}
 for _,key in ipairs({'ork_boyz_hut_t2','ork_warcamp','ork_mek_lab_t3'})do
  local d,why=M.Build(key,(facts or{})[key],V)
  if d then assert(not defs[key],'Ground factory key already registered: '..key);defs[key]=d;report.registered[#report.registered+1]=key
  else report.missing[#report.missing+1]=key..':'..why end
 end
 return report
end
return M
