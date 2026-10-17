-- Exact source gun and four elite real bodies; authored reversible native tuning.
return VFS.Include('40k_configs/ork_infantry_product.lua').New({
 actor='ork_flash_gitz',feature='40k_flash_gitz_corpse',id=22,capacity=4,tier=3,spacing=26,
 sourceWHMSHA256='dfc639756ab28a54d37983086d1765e85c20f99b11dcddb9a8c9f233c3c31f27',
 entity='attrib/ebps/races/orks/troops/ork_flash_gitz.lua',root='gitz_master',muzzle='marker_muzzle_01',
 cost={60,300,720},health=260,sight=450,name='Flash Git',description='T3 elite ranged Ork with a Snazzgun',
 mobName='Flash Gitz Mob',shortRole='Elite Snazzgun mob',
 mobDescription='4 real Flash Gitz per paid Warcamp order. Builders heal survivors and restore casualties for resources.',
 weapondefs={snazzgun={name='Snazzgun',weapontype='Cannon',range=440,reloadtime=1.8,
  burst=3,burstrate=.16,weaponvelocity=650,turret=true,tolerance=4000,accuracy=200,sprayangle=240,
  areaofeffect=1,cratermult=0,impulsefactor=0,avoidfriendly=true,avoidfeature=true,
  collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,
  damage={default=12},size=.35,stages=2,rgbcolor='1 .8 .3',explosiongenerator='custom:40k_shoota_impact',
  soundstart='40k_shoota',soundstartvolume=.8,
  customparams={source_muzzle='marker_muzzle_01',source_fireclip='fire',source_wholebodyaim=1,source_fx_family='shoota'}}},
 weapons={{def='snazzgun',onlytargetcategory='SURFACE'}}})
