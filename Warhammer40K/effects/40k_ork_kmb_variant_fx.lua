-- Compact project KMB plasma presentation; adapted stock textures, no damage/light ownership.
local blue='.75 .95 1 .35  .12 .4 1 .2  .025 .08 .35 .07  0 0 0 0'
local function particles(count,size,life,speed)
 return{class='CSimpleParticleSystem',count=1,air=true,ground=true,water=true,unit=true,nounit=true,properties={airdrag=.9,colormap=blue,directional=false,emitrot=0,emitrotspread=35,emitvector='dir',gravity='0, .01, 0',numparticles=count,particlelife=life,particlelifespread=1,particlesize=size,particlesizespread=size*.2,particlespeed=speed,particlespeedspread=speed*.3,pos='0, 0, 0',sizegrowth=-.04,sizemod=1,texture='gunshotglow',useairlos=true}}
end
return{
 ['40k_ork_kmb_muzzle']={usedefaultexplosions=false,flash={class='CBitmapMuzzleFlame',count=1,air=true,ground=true,water=true,unit=true,nounit=true,properties={dir='dir',colormap=blue,fronttexture='laserend',sidetexture='shot',frontoffset=0,size=.65,length=2.2,ttl=3,sizegrowth=-.15,useairlos=true}}},
 ['40k_ork_kmb_impact']={usedefaultexplosions=false,glow=particles(1,3.4,6,0),sparks=particles(4,.28,7,.7)},
}
