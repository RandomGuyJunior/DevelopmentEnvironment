-- Authored compact effects. Texture identifiers come from the pinned BAR
-- scaffold; no source DoW/UA bitmaps are copied or claimed distributable.
-- Sizes are elmos; life/ttl values are simulation frames (~30 per second).
local RED="1 .08 .025 .28  .8 .025 .01 .14  0 0 0 0"
local GUN="1 .92 .7 .3  1 .48 .08 .18  .5 .12 .02 .06  0 0 0 0"
local SMOKE=".18 .17 .15 .12  .11 .105 .095 .055  0 0 0 0"
local DIRT=".25 .2 .14 .2  .16 .13 .09 .08  0 0 0 0"
local function flame(size,length,ttl,color,side,front)
 return {class="CBitmapMuzzleFlame",count=1,air=true,ground=true,water=true,
  underwater=false,unit=true,nounit=true,properties={
   colormap=color,dir="dir",frontoffset=0,fronttexture=front or "muzzlefront",
   sidetexture=side or "muzzleside",size=size,length=length,ttl=ttl,
   sizegrowth=-.15,useairlos=true,
  }}
end
local function particles(texture,count,size,life,speed,color,spread,growth)
 return {class="CSimpleParticleSystem",count=1,air=true,ground=true,water=true,
  underwater=false,unit=true,nounit=true,properties={
   airdrag=.86,colormap=color,directional=false,emitrot=15,emitrotspread=spread or 25,
   emitvector="dir",gravity="0, .025, 0",numparticles=count,
   particlelife=life,particlelifespread=2,particlesize=size,particlesizespread=size*.25,
   particlespeed=speed,particlespeedspread=speed*.4,pos="0, 0, 0",
   sizegrowth=growth or 0,sizemod=1,texture=texture,useairlos=true,
  }}
end
local function muzzle(size,length,smokeSize)
 return {usedefaultexplosions=false,
  flash=flame(size,length,4,GUN),
  smoke=particles("smoke_puff",1,smokeSize,6,.12,SMOKE,18,.045),
 }
end
local function impact(size,sparks,dustSize)
 return {usedefaultexplosions=false,
  glint=particles("gunshotglow",1,size,2,0,GUN,0,-.03),
  sparks=particles("gunshotglow",sparks,.22,4,.6,GUN,55,-.025),
  dust=particles("dirtpuff",1,dustSize,6,.1,DIRT,30,.07),
 }
end
local definitions={
 ["40k_lasgun_muzzle"]={usedefaultexplosions=false,
  -- No powder smoke and no large glow orb: a narrow red pulse at the bore.
  flash=flame(.38,1.8,3,RED,"shot","laserend"),
 },
 ["40k_lasgun_impact"]={usedefaultexplosions=false,
  glint=particles("gunshotglow",1,.48,2,0,RED,0,-.06),
  fleck=particles("gunshotglow",1,.16,3,.22,RED,35,-.035),
 },
 ["40k_bolter_muzzle"]=muzzle(.8,3,.48),
 ["40k_shoota_muzzle"]=muzzle(.95,3.6,.58),
 ["40k_heavy_bolter_muzzle"]=muzzle(1.25,4.2,.7),
 ["40k_bolter_impact"]=impact(.75,2,.48),
 ["40k_shoota_impact"]=impact(.58,1,.4),
 ["40k_heavy_bolter_impact"]=impact(.9,2,.6),
 ["40k_battlecannon_muzzle"]={usedefaultexplosions=false,
  flash=flame(2.8,10,5,GUN),
  smoke=particles("smoke_puff",2,1.7,12,.45,SMOKE,20,.16),
 },
 ["40k_battlecannon_impact"]={usedefaultexplosions=false,
  flash=particles("gunshotglow",1,4.5,4,0,GUN,0,-.1),
  sparks=particles("gunshotglow",5,.5,7,1.2,GUN,65,-.04),
  smoke=particles("smoke_puff",2,2.2,15,.25,SMOKE,45,.18),
  dirt=particles("dirtpuff",5,1.5,12,.9,DIRT,55,.12),
 },
}
-- Ground debris is upward, and only appears on dry terrain collisions.
local dirt=definitions["40k_battlecannon_impact"].dirt
dirt.air=false;dirt.water=false;dirt.unit=false;dirt.nounit=true
dirt.properties.emitvector="0, 1, 0"
dirt.properties.gravity="0, -.1, 0"
return definitions
