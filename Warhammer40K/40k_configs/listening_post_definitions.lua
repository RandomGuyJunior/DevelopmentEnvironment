-- Apply after four-faction aliases, before the final armour/description hook.
-- Leaves costs, build time, native extraction, storage, footprint and collision intact.
local M={}
function M.Apply(defs,V,config,bindings)
 local changed={}
 for name,row in pairs(bindings)do
  local d=defs[name];local p=config.Profiles[name];local key=row.key
  if d and p then
   for _,file in ipairs({'objects3d/'..key..'.glb','unittextures/'..key..'_tex1.png','unittextures/'..key..'_tex2.png','scripts/generated/'..key..'_anim.lua','scripts/generated/'..key..'_post.lua','unitpics/lp_'..key..'.png'})do assert(V.FileExists(file),'Listening post bundle missing: '..file)end
   local meta=V.Include('scripts/generated/'..key..'_post.lua');assert(meta.version==1 and meta.unit==name and meta.entity==p.entity and meta.key==key,'Listening post identity mismatch')
   local bones={};for _,bone in ipairs(meta.bones)do bones[bone]=true end
   local bank=V.Include('scripts/generated/'..key..'_anim.lua')
   d.customparams=d.customparams or{};local cp=d.customparams
   assert(cp.faction==p.faction,'Listening post faction drift: '..name)
   d.objectname=key..'.glb';d.script='40k_listening_post.lua';d.buildpic='lp_'..key..'.png';d.health=p.source_base_health
   d.canattack=true;d.weapondefs={};d.weapons={};cp.animsource=key;cp.listening_post_version=1;cp.listening_post_key=key;cp.source_entity=p.entity;cp.rosterrole='mex'
   d.description='Resource post; paid fortification';cp.i18n_en_tooltip=d.description;cp.prototype40k_ui_description=d.description
   for n,m in ipairs(row.mounts)do
    assert(bones[m.muzzle]and bones[m.yaw]and(not m.pitch or bones[m.pitch])and bank.clips[m.clip],'Listening post genuine mount missing')
    local id='post_stage_'..m.level
    local w={name=m.name,weapontype=m.rocket and 'MissileLauncher'or m.beam and 'BeamLaser'or 'LaserCannon',range=m.range,reloadtime=m.reload,damage={default=m.damage},areaofeffect=m.rocket and 32 or 8,weaponvelocity=m.rocket and 430 or 900,turret=true,avoidfriendly=true,collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,accuracy=70,sprayangle=70,impulsefactor=0,cratermult=0,edgeeffectiveness=.5,
     customparams={source_weapon='attrib/weapon/'..m.weapon..'.lua',source_weapon_identity=m.weapon,source_fx_family=m.family,source_fireclip=m.clip,source_muzzle=m.muzzle,source_aimpiece=m.yaw,source_pitchpiece=m.pitch,source_muzzle_pair=m.pair,listening_post_level=m.level}}
    local fx=m.beam and '40k_necron_turret_gauss'or '40k_dow_'..m.family
    w.explosiongenerator='custom:'..fx..'_impact';w.customparams.source_muzzlefx=fx..'_muzzle'
    if m.rocket then w.cegtag='40k_dow_rokkit_trail';w.startvelocity=180;w.weaponacceleration=150;w.flighttime=4;w.smoketrail=true;w.tracks=true;w.turnrate=12000
    elseif m.beam then
     w.beamtime=.12;w.rgbcolor='0.2 1 0.25';w.thickness=2
     -- The existing genuine sound bank calls this family gauss, while the
     -- defence/AP family is necron_turret_gauss. Preserve both identities.
     if V.FileExists('40k_configs/generated_audio.lua')then
      local audio=V.Include('40k_configs/generated_audio.lua');local rows=audio.weapon_gauss
      if rows and rows[1]and V.FileExists(rows[1].file)then w.soundstart='40k_gauss';w.soundstartvolume=1 end
     end
    else w.rgbcolor='1 .75 .35';w.duration=.025;w.thickness=1 end
    d.weapondefs[id]=w;d.weapons[n]={def=id,onlytargetcategory='SURFACE'}
   end
   changed[#changed+1]=name
  end
 end
 table.sort(changed);return changed
end
return M
