-- One exact GOH bike with its weighted seated crew; sole VEH1 graph owner.
local options=Spring and Spring.GetModOptions and Spring.GetModOptions()or{}
if not VFS.Include('40k_configs/ork_registration_gates.lua').Allowed('ork_warbike_crewed',options)then return{}end
local factfile='40k_configs/ork_warbike_crewed_facts.lua'
if not VFS.FileExists(factfile)then return{}end
for _,path in ipairs({'objects3d/ork_warbike_crewed.glb','objects3d/ork_warbike_crewed.glb.lua',
 'objects3d/ork_warbike_crewed_wreck.glb','objects3d/ork_warbike_crewed_wreck.glb.lua',
 'unittextures/ork_warbike_crewed_tex1.png','unittextures/ork_warbike_crewed_tex2.png',
 'scripts/generated/ork_warbike_crewed_anim.lua','scripts/40k_ork_warbike_crewed.lua','unitpics/40k_ork_warbike_crewed.png'})do
 if not VFS.FileExists(path)then return{}end
end
local facts=VFS.Include(factfile)
assert(facts.sourceLabel=='EVZ_Ork_warbike'and facts.riderLabel=='Ork_Goffs_TX_Tankman_01'and facts.recipe=='GOH-02/ORK-VEH-1'and facts.export_verified,'Exact corrected bike+rider facts required')
local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
-- Pinned native small ground-vehicle template supplies stock movement fields.
-- Its model, gun, script, sound and salvage are replaced by this actual actor.
local d=copy(assert(VFS.Include('units/corvehicles/corgator.lua').corgator))
d.name='Crewed Warbike';d.description='T1 fast scout-speed Ork bike; Attack ground enemies to ram, circle and repeat; paired Big Shootas; provisional rider cap material'
d.objectname='ork_warbike_crewed.glb';d.script='40k_ork_warbike_crewed.lua';d.buildpic='40k_ork_warbike_crewed.png'
d.metalcost=180;d.energycost=1440;d.buildtime=2160;d.health=650;d.speed=153;d.maxacc=.2;d.maxdec=.4
d.turnrate=750;d.turninplacespeedlimit=1.5;d.footprintx=3;d.footprintz=3;d.movementclass='TANK3'
d.builder=false;d.buildoptions={};d.canattack=true;d.maxwaterdepth=5;d.sightdistance=380;d.leavetracks=false
d.usepiececollisionvolumes=false;d.usepieceselectionvolumes=false
d.collisionvolumetype='Box';d.collisionvolumescales=facts.collisionvolumescales;d.collisionvolumeoffsets=facts.collisionvolumeoffsets
d.selectionvolumetype='Box';d.selectionvolumescales=facts.collisionvolumescales;d.selectionvolumeoffsets=facts.collisionvolumeoffsets
d.customparams={faction='Orks',prototype40k=1,prototype40k_source_progression=1,techlevel=1,animsource='ork_warbike_crewed',
 rosterrole='vehicle',unitgroup='weapon',prototype40k_warbike_ram=1,source_entity='EVZ_Ork_warbike',source_rider='Ork_Goffs_TX_Tankman_01',source_asset='GOH-02',
 ork_producer_recipe='ORK-VEH-1',prototype40k_native_donor='corgator',model_author='private source',
 prototype40k_squad_exception='Single paid vehicle with visual crew; no passenger or crew recruitment',
 integration_status='native_acceptance_pending',source_material_note='39 limbs_c cap triangles use provisional authored green; exact diffuse unresolved; normal/specular pending'}
local function gun(name,muzzle,turret)
 return{name=name,weapontype='Cannon',range=310,reloadtime=1.25,burst=4,burstrate=.12,weaponvelocity=640,turret=turret,
  tolerance=2500,accuracy=320,targetmoveerror=.15,areaofeffect=1,cratermult=0,impulsefactor=0,
  collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,
  avoidfriendly=true,avoidfeature=true,size=.22,stages=2,rgbcolor='1 .8 .3',
  explosiongenerator='custom:40k_shoota_impact',soundstart='40k_big_shoota',soundstartvolume=.9,damage={default=8},
  customparams={source_muzzle=muzzle,source_actor='EVZ_Ork_warbike',source_fx_family='big_shoota'}}
end
d.weapondefs={left=gun('Left Big Shoota',facts.mounts.muzzle_left,false),right=gun('Right Big Shoota',facts.mounts.muzzle_right,true)}
d.weapons={{def='left',onlytargetcategory='SURFACE',maindir='0 0 1',maxangledif=30},
 {def='right',onlytargetcategory='SURFACE',maindir='0 0 1',maxangledif=30,slaveto=1}}
d.sfxtypes={explosiongenerators={'custom:40k_shoota_muzzle'}}
d.sounds={}
d.corpse='wreck';d.featuredefs={wreck={description='Crewed Warbike wreck',object='ork_warbike_crewed_wreck.glb',blocking=false,
 reclaimable=true,autoreclaimable=true,resurrectable=0,indestructible=true,flammable=false,health=1,metal=45,energy=0,
 footprintx=3,footprintz=3,featuredead='',customparams={source_vehicle='EVZ_Ork_warbike',parent_actor='ork_warbike_crewed',
  prototype40k_remains_domain='vehicle',one_salvage_owner=1,persistent_salvage=1}}}
return{ork_warbike_crewed=d}
