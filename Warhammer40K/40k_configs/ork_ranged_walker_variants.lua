-- Deliberate ranged-only Ork walker kitbashes. Asset facts are required, not invented.
local M={Version=1}
M.Variants={
 ork_kan_twin_shoota={base='ork_killa_kan',label='Twin Big Shoota Kan',metal=320,energy=1600,work=3000,arms={{id='left',family='big_shoota'},{id='right',family='big_shoota'}}},
 ork_kan_twin_kmb={base='ork_killa_kan',label='Twin Mega-Blasta Kan',metal=410,energy=2400,work=4000,arms={{id='left',family='kmb'},{id='right',family='kmb'}}},
 ork_kan_twin_rokkit={base='ork_killa_kan',label='Twin Rokkit Kan',metal=360,energy=1900,work=3500,arms={{id='left',family='rokkit'},{id='right',family='rokkit'}}},
 ork_dread_ranged_fourarm={base='ork_deff_dread',label='Four-Arm Dakka Dread',metal=660,energy=4200,work=6500,arms={{id='upper_l',family='kmb'},{id='upper_r',family='kmb'},{id='lower_l',family='big_shoota',barrels=2},{id='lower_r',family='rokkit'}}},
}
M.Weapons={
 big_shoota={name='Big Shoota',weapontype='Cannon',range=380,reloadtime=1.5,burst=3,burstrate=.22,weaponvelocity=600,damage={default=14},areaofeffect=2,accuracy=180,sprayangle=220,size=.28,rgbcolor='1 .75 .25',explosiongenerator='custom:40k_dow_big_shoota_impact',muzzlefx='40k_dow_big_shoota_muzzle',clip='shoota_fire'},
 kmb={name='Kustom Mega-Blasta',weapontype='LaserCannon',range=410,reloadtime=3.2,weaponvelocity=420,damage={default=105},areaofeffect=22,accuracy=145,size=1,duration=.008,thickness=1.6,corethickness=.5,rgbcolor='.12 .4 1',rgbcolor2='.75 .95 1',explosiongenerator='custom:40k_ork_kmb_impact',muzzlefx='40k_ork_kmb_muzzle',clip='kmb_fire'},
 rokkit={name='Rokkit Launcha',weapontype='MissileLauncher',range=460,reloadtime=4.8,weaponvelocity=340,startvelocity=90,weaponacceleration=140,tracks=false,damage={default=170},areaofeffect=38,accuracy=220,sprayangle=160,size=1,rgbcolor='1 .4 .1',explosiongenerator='custom:40k_ork_ranged_rokkit_impact',cegtag='40k_ork_ranged_rokkit_trail',muzzlefx='40k_dow_rokkit_muzzle',clip='rokkit_fire'},
}
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
function M.Build(defs,key,facts,assetReady)
 local v=assert(M.Variants[key]);local f=facts and facts[key]
 if not f or not assetReady or not assetReady(key)then return nil,'missing_measured_private_kitbash'end
 assert(#f.arms==#v.arms and f.no_melee_geometry and f.geometry_checked,'Visible full loadout required')
 local d=copy(assert(defs[v.base]));d.name=v.label;d.description='Ranged-only walker; '..#v.arms..' weapon assemblies'
 d.objectname=key..'.glb';d.script='40k_roster.lua';d.buildpic='40k_'..v.base..'.png';d.metalcost=v.metal;d.energycost=v.energy;d.buildtime=v.work
 d.weapondefs={};d.weapons={};d.buildoptions={};d.customparams=d.customparams or{};local c=d.customparams
 -- Native tex2 retains glow/specularity; it must not occupy the normal-map slot.
 c.animsource=key;c.normaltex=nil;c.prototype40k_donor=key;c.prototype40k=1;c.prototype40k_four_faction=1;c.prototype40k_source_progression=1;c.faction='Orks';c.rosterrole='walker'
 c.clawmarker=nil;c.clawweapon=nil;c.clawreload=nil;c.prototype40k_ranged_variant=1;c.prototype40k_tech_requires=key;c.source_variant_recipe='project_four_assembly_ranged_v1'
 c.i18n_en_humanname=d.name;c.i18n_en_tooltip=d.description;c.source_ranged_model_sha256=f.model_sha256;c.source_buildpiece=nil;c.source_independent_weapon_assemblies=1;c.prototype40k_shared_visual_source=v.base
 local sx,sy,sz=unpack(f.bounds.size);d.collisionvolumetype='Box';d.collisionvolumescales=sx..' '..sy..' '..sz;d.collisionvolumeoffsets=table.concat(f.bounds.center,' ')
 d.footprintx=math.ceil(sx/16);d.footprintz=math.ceil(sz/16)
 for n,a in ipairs(v.arms)do
  local mount=f.arms[n];assert(mount.id==a.id and #mount.muzzles==(a.barrels or 1),'Assembly/muzzle count')
  local w=copy(M.Weapons[a.family]);local clip=w.clip;local fx=w.muzzlefx;w.clip=nil;w.muzzlefx=nil;if a.barrels and w.burst then w.burst=w.burst*a.barrels end
  w.turret=true;w.tolerance=4000;w.cratermult=0;w.impulsefactor=0;w.collidefriendly=true;w.collideenemy=true;w.collideground=true;w.collidefeature=true;w.collidenontarget=true;w.avoidfriendly=true;w.avoidfeature=true
  w.customparams={source_muzzle=mount.muzzles[1],source_muzzle_pair=#mount.muzzles>1 and table.concat(mount.muzzles,',')or nil,source_aimpiece=mount.pivot,source_pitchpiece=mount.pivot,source_aimfrom_muzzle=1,source_fireclip=clip,source_weapon_bones=table.concat(mount.bones,','),source_weapon_bones_only=1,source_fx_family=a.family,source_muzzlefx=fx,source_variant_assembly=a.id,source_variant_barrels=#mount.muzzles}
  local side=(a.id=='left'or a.id=='upper_l'or a.id=='lower_l')and 1 or -1
  local clearance=VFS.Include('scripts/40k_mount_clearance.lua')
  local mainDir,maxAngleDif
  if clearance.Enabled(Spring.GetModOptions())then mainDir,maxAngleDif=clearance.NativeCone(side,clearance.Limits(key,n,a.id))end
  d.weapondefs['mount'..n]=w;d.weapons[n]={def='mount'..n,onlytargetcategory='SURFACE',maindir=mainDir,maxangledif=maxAngleDif}
 end
 if key~='ork_dread_ranged_fourarm'and f.recipe=='project_kan_paired_torso_v2'then
  VFS.Include('40k_configs/ork_paired_kan_torso_definition.lua').Apply(d,key,f)
 end
 if key=='ork_dread_ranged_fourarm'and f.recipe=='project_dread_direct_torso_v2'then
  VFS.Include('40k_configs/ork_direct_dread_definition.lua').Apply({[key]=d},{[key]=f},true)
 end
 return d
end
function M.Apply(defs,facts,assetReady)
 if VFS.FileExists('40k_configs/ork_direct_dread_facts.lua')then
  facts=copy(facts or{});facts.ork_dread_ranged_fourarm=assert(VFS.Include('40k_configs/ork_direct_dread_facts.lua').ork_dread_ranged_fourarm)
 end
 if VFS.FileExists('40k_configs/ork_paired_kan_torso_facts.lua')then
  facts=copy(facts or{});local paired=assert(VFS.Include('40k_configs/ork_paired_kan_torso_facts.lua'))
  for _,key in ipairs({'ork_kan_twin_shoota','ork_kan_twin_kmb','ork_kan_twin_rokkit'})do
   facts[key]=assert(paired[key],'Complete measured paired-Kan export required')
  end
 end
 local out,requires={},{}
 for key,v in pairs(M.Variants)do local d=M.Build(defs,key,facts,assetReady);if d then defs[key]=d;out[#out+1]=key;requires[key]={}
  local factory=defs[v.base=='ork_killa_kan'and'ork_mek_shop'or'ork_resource_factory'];if factory then factory.buildoptions=factory.buildoptions or{};factory.buildoptions[#factory.buildoptions+1]=key end
 end end
 table.sort(out);return{definitions=out,Requires=requires}
end
return M
