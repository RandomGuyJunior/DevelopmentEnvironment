-- Native shell impacts spawn these bounded visual layers; no scripted damage.
-- All textures are established pinned BAR aliases, with no source bitmaps.
local FIRE='1 .96 .78 .5  1 .63 .12 .32  .9 .22 .025 .13  0 0 0 0'
local SMOKE='.24 .21 .18 .17  .14 .13 .12 .09  0 0 0 0'
local DIRT='.38 .28 .15 .2  .2 .15 .09 .09  0 0 0 0'
local function particles(texture,n,size,life,speed,color,growth)
 return{class='CSimpleParticleSystem',count=1,air=true,ground=true,water=true,unit=true,nounit=true,underwater=false,
  properties={airdrag=.88,colormap=color,directional=false,emitrot=0,emitrotspread=70,emitvector='0, 1, 0',
   gravity='0, .025, 0',numparticles=n,particlelife=life,particlelifespread=2,particlesize=size,
   particlesizespread=size*.2,particlespeed=speed,particlespeedspread=speed*.4,
   pos='0, 0, 0',sizegrowth=growth,sizemod=1,texture=texture,useairlos=true}}
end
local function impact(size)
 local debris=particles('dirtpuff',4,size*.13,15,size*.045,DIRT,.08)
 debris.air=false;debris.water=false;debris.unit=false;debris.properties.gravity='0, -.14, 0'
 return{usedefaultexplosions=false,
  flash=particles('gunshotglow',1,size,5,0,FIRE,-.4),
  fire=particles('gunshotglow',5,size*.32,10,size*.03,FIRE,-.14),
  sparks=particles('gunshotglow',6,size*.025,8,size*.075,FIRE,-.025),
  smoke=particles('smoke_puff',3,size*.27,24,size*.012,SMOKE,.18),debris=debris}
end
return{['40k_ork_artillery_t1_impact']=impact(16),['40k_ork_artillery_t2_impact']=impact(32)}
