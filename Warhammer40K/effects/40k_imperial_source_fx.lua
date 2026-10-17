-- Authored compact native layers traced to genuine DoW/UA Imperial WHE FX.
-- CEGs are presentation only. Native weapons retain projectile/collision/damage.
local function texture(alias,extension,fallback)
 if VFS and VFS.FileExists and VFS.FileExists('bitmaps/projectiletextures/'..alias..extension)then return alias end
 return fallback
end
local laserBeam=texture('40k_imp_lascannon_beam','.png','shot')
local laserFlash=texture('40k_imp_lascannon_flash','.png','laserend')
local plasmaFlash=texture('40k_imp_plasma_flash','.png','gunshotglow')
local plasmaBeam=texture('40k_imp_plasma_beam','.png','shot')
local plasmaBurst=texture('40k_imp_plasma_burst','.png','gunshotglow')
local whiteWarm='1 1 1 .32  1 .81 .71 .21  .35 .27 .25 .07  0 0 0 0'
local plasma='.9 .97 1 .34  .43 .91 1 .25  .17 .53 .6 .09  0 0 0 0'
local lightning='.75 .88 1 .3  .4 .63 1 .19  .08 .22 .45 .06  0 0 0 0'
local steel='1 .89 .63 .3  1 .53 .12 .2  .3 .15 .06 .05  0 0 0 0'
local smoke='.16 .17 .18 .1  .1 .12 .14 .04  0 0 0 0'
local function flash(front,side,size,length,ttl,color)
 return {class='CBitmapMuzzleFlame',count=1,air=true,ground=true,water=true,unit=true,nounit=true,underwater=false,properties={dir='dir',colormap=color,fronttexture=front,sidetexture=side,frontoffset=0,size=size,length=length,ttl=ttl,sizegrowth=-.12,useairlos=true}}
end
local function particles(texture,n,size,ttl,speed,color,growth)
 return {class='CSimpleParticleSystem',count=1,air=true,ground=true,water=true,unit=true,nounit=true,underwater=false,properties={airdrag=.9,colormap=color,directional=false,emitrot=0,emitrotspread=55,emitvector='dir',gravity='0, .02, 0',numparticles=n,particlelife=ttl,particlelifespread=1,particlesize=size,particlesizespread=size*.2,particlespeed=speed,particlespeedspread=speed*.3,pos='0, 0, 0',sizegrowth=growth or 0,sizemod=1,texture=texture,useairlos=true}}
end
local fx={
 ['40k_dow_lascannon_muzzle']={usedefaultexplosions=false,core=flash(laserFlash,laserBeam,.42,3.1,3,whiteWarm),ring=particles(laserFlash,1,.6,4,0,whiteWarm,-.045)},
 ['40k_dow_lascannon_impact']={usedefaultexplosions=false,flash=particles(laserFlash,1,.9,4,0,whiteWarm,-.06),sparks=particles('gunshotglow',3,.12,5,.6,whiteWarm,-.025)},
 -- Source Warhound outer muzzle is a cyan-blue expanding halo around a bright
 -- hot core. The main-beam source persists longer; this CEG is the compact muzzle.
 ['40k_dow_plasma_blastgun_muzzle']={usedefaultexplosions=false,core=flash(plasmaFlash,plasmaBeam,.9,4.5,5,whiteWarm),halo=particles(plasmaFlash,1,1.3,7,0,plasma,.085),vent=particles('smoke_puff',1,.45,8,.08,smoke,.035)},
 ['40k_dow_plasma_blastgun_impact']={usedefaultexplosions=false,burst=particles(plasmaBurst,1,2.0,8,0,plasma,.04),glow=particles(plasmaFlash,1,2.5,10,0,plasma,-.07),arcs=particles('gunshotglow',4,.16,5,.45,lightning,-.03),steam=particles('smoke_puff',2,1.0,14,.14,smoke,.06)},
 -- Contact-only effects. No muzzle, tracer or idle weapon glow is invented.
 ['40k_dow_chainsword_impact']={usedefaultexplosions=false,sparks=particles('gunshotglow',4,.11,4,.58,steel,-.025),smoke=particles('smoke_puff',1,.19,5,.06,smoke,.015)},
 ['40k_dow_power_fist_impact']={usedefaultexplosions=false,arc=flash('laserend','shot',.16,.8,2,lightning),sparks=particles('gunshotglow',3,.1,4,.38,lightning,-.025)},
}
return fx
