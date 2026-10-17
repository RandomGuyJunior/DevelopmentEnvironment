-- Source defensive weapon identities and genuine turret/marker bindings.
-- Native engine owns projectile, reload and damage; final armour hook assigns AP.
return {
 imp_mex={key='imp_post_stages',mounts={
  {level=1,name='Listening post heavy bolter',range=350,reload=.5,damage=90,muzzle='mrker_muzzle_1',yaw='bone_aim_horiz',pitch='bone_aim_vert',clip='fire_1',weapon='guard_heavy_bolter_listening_post',family='heavy_bolter'},
  {level=2,name='Fortified heavy bolter',range=450,reload=.4,damage=110,muzzle='mrker_muzzle_2',yaw='bone_aim_horiz',pitch='bone_aim_vert',clip='fire_2',weapon='guard_heavy_bolter_listening_post_2',family='heavy_bolter'}}},
 imp_marine_mex={key='sm_post_stages',mounts={
  {level=1,name='Listening post storm bolter',range=350,reload=.5,damage=90,muzzle='marker_bolter_fire',yaw='bone_turret_horiz',pitch='bone_turret_vert',clip='fire_1',weapon='space_marine_storm_bolter_turret_listeningpost',family='bolter'},
  {level=2,name='Fortified heavy bolter',range=450,reload=.4,damage=110,muzzle='marker_cannon_fire',yaw='bone_turret_horiz',pitch='bone_turret_vert',clip='fire_2',weapon='space_marine_heavy_bolter_listening_post',family='heavy_bolter'}}},
 ork_listening_post={key='ork_post_stages',mounts={
  {level=0,name='Listening post shoota',range=250,reload=.7,damage=55.5,muzzle='marker_big_shoota',yaw='aim_horz_main',pitch='aim_vert_main',clip='fire_0',weapon='ork_shoota_turret_listeningpost',family='shoota'},
  {level=1,name='Listening post big shoota',range=350,reload=.3,damage=55,muzzle='marker_twin_big_shoota01',pair='marker_twin_big_shoota01,marker_twin_big_shoota02',yaw='aim_horz_main',pitch='aim_vert_main',clip='fire_1',weapon='ork_big_shoota_turret_listeningpost',family='big_shoota'},
  {level=2,name='Listening post rokkit',range=450,reload=3,damage=800,muzzle='marker_boyz_rokkit_launcha_barrel',yaw='aim_horz_main',pitch='aim_vert_main',clip='fire_2',weapon='ork_rokkit_launcher_turret_listeningpost',family='rokkit',rocket=true}}},
 nec_mex={key='nec_post_stages',mounts={
  {level=2,name='Fortified obelisk gauss',range=450,reload=1,damage=220,muzzle='mrkr_addon_cntr_01',yaw='mrkr_addon_cntr_01',clip='fire_2',weapon='necron_gauss_listening_post_2',family='necron_turret_gauss',beam=true}}},
}
