-- Gunship presentation only. Native projectiles retain damage and timing.
-- Existing pinned BAR textures; short-lived sprites, no smoke trails or lights.
local HOT='1 .98 .85 .55  1 .7 .22 .34  1 .28 .035 .12  0 0 0 0'
local SMOKE='.28 .25 .21 .13  .16 .145 .125 .08  0 0 0 0'
local function flame(size,length,ttl,color)
 return {class='CBitmapMuzzleFlame',count=1,air=true,ground=true,water=true,
  underwater=false,unit=true,nounit=true,properties={dir='dir',colormap=color,
   fronttexture='muzzlefront',sidetexture='muzzleside',frontoffset=0,
   size=size,length=length,ttl=ttl,sizegrowth=0,useairlos=true}}
end
local function particles(texture,count,size,life,speed,color,spread,growth)
 return {class='CSimpleParticleSystem',count=1,air=true,ground=true,water=true,
  underwater=false,unit=true,nounit=true,properties={airdrag=.88,colormap=color,
   directional=false,emitrot=0,emitrotspread=spread,emitvector='dir',
   gravity='0, .015, 0',numparticles=count,particlelife=life,particlelifespread=1,
   particlesize=size,particlesizespread=size*.15,particlespeed=speed,
   particlespeedspread=speed*.25,pos='0, 0, 0',sizegrowth=growth,sizemod=1,
   texture=texture,useairlos=true}}
end
local function clone(v)
 if type(v)~='table'then return v end
 local r={};for k,x in pairs(v)do r[k]=clone(x)end;return r
end
-- Preserve the previously used stock large blast, increasing selected visible
-- fire sizes slightly without increasing their particle counts or lifetimes.
local stock=VFS.Include('effects/genericshellexplosion.lua')
local impact=clone(assert(stock['genericshellexplosion-large']))
for _,name in ipairs({'explosion','explosion2'})do
 local p=assert(impact[name]).properties
 p.particlesize=assert(tonumber(p.particlesize))*1.18
end
impact.gunship_whitecore=particles('flare',1,42,4,0,HOT,0,-3)
impact.gunship_sparks=particles('flare',6,1.7,8,6,HOT,65,-.08)
impact.gunship_pressure_ring={class='CSimpleGroundFlash',count=1,air=true,
 ground=true,water=false,underwater=false,unit=true,nounit=true,
 properties={colormap='1 .83 .45 .18  .7 .42 .15 .08  0 0 0 0',
  size=28,sizegrowth=5,ttl=10,texture='groundring'}}
return {
 ['40k_gunship_siege_muzzle']={usedefaultexplosions=false,
  flash=flame(6,26,5,HOT),smoke=particles('smoke_puff',3,3.2,10,.7,SMOKE,16,.12)},
 ['40k_gunship_siege_impact']=impact,
}
