-- Reviewed candidates only. Stable commander adapter retains founding economy.
local M={}
function M.DefinitionReady(V)
 return V and V.FileExists and V.FileExists('objects3d/imp_force_commander_candidate.glb')and V.FileExists('scripts/generated/imp_force_commander_candidate_anim.lua')and V.FileExists('scripts/40k_roster.lua')
end
function M.ForceCommander(V,enabled)
 if not enabled or not M.DefinitionReady(V)then return nil,'inactive_or_missing_assets'end
 local d={name='Imperial Force Commander',description='Genuine bolt pistol/power sword commander presentation candidate',objectname='imp_force_commander_candidate.glb',script='40k_roster.lua',buildpic='40k_imp_force_commander_candidate.png',health=1800,metalcost=0,energycost=0,buildtime=1,canmove=true,speed=32,maxacc=.08,maxdec=.2,turnrate=800,turninplace=true,upright=true,footprintx=1,footprintz=1,movementclass='SBOT2',maxslope=30,maxwaterdepth=5,sightdistance=500,category='ALL MOBILE NOTSUB SURFACE',collisionvolumetype='CylY',canattack=true,sfxtypes={explosiongenerators={'custom:40k_dow_bolter_muzzle'}},buildoptions={},weapondefs={},weapons={},customparams={prototype40k=1,prototype40k_expansion=1,faction='Imperium',animsource='imp_force_commander_candidate',rosterrole='builder',source_buildclip='command_build',source_nanopiece='bip01 l hand',root_bone='bip01 pelvis',commander_candidate_only=1,source_entity='force_commander_sp',source_entity_sha256='d5f90e4210952d4c96488a57d63a121e39c9da2708095d1516acdbd0b908edaf',source_whm_sha256='bae55403be5bca7161afd12ee3096f28a2a28d93fc62e0fbbe4890a402e51e21',source_glb_sha256='47df0f59cc4b0e21401ff54e9307fa21c1930db37791c227b75b625af7cecb62',source_skin_four_positive_corners=126,balance_status='commander_user_design_native_review_pending'}}
 d.weapondefs.bolt={name='Force Commander bolt pistol',weapontype='Cannon',turret=true,range=300,reloadtime=.8000000119,weaponvelocity=750,accuracy=100,sprayangle=150,areaofeffect=1,explosiongenerator='custom:40k_dow_bolter_impact',damage={default=115},impulsefactor=0,cratermult=0,avoidfriendly=true,avoidfeature=true,collidefriendly=true,collideenemy=true,collideground=true,collidefeature=true,collideneutral=true,collidenontarget=true,customparams={source_muzzle='marker_marine_boltpistol_barrel',source_fireclip='fire',source_aimpiece='unit_aim',source_fx_family='bolter',source_muzzlefx=1024}}
 d.weapondefs.sword={name='Force Commander power sword',weapontype='Melee',turret=true,range=45,reloadtime=1.5,damage={default=309.5},impulsefactor=0,cratermult=0,customparams={source_muzzle='marker_marine_power_sword_blade',source_fireclip='melee',source_aimpiece='unit_aim',source_fx_family='power_sword'}}
 d.weapons={{def='bolt',onlytargetcategory='SURFACE'},{def='sword',onlytargetcategory='SURFACE'}}
 -- This donor is presentation metadata, not a free recruit or a new starting actor.
 -- It must never be added to build/spawn menus; armcom keeps its native costs.
 return d
end
return M
