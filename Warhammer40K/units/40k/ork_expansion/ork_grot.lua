-- Explicit mixed test exposure is exact-key scoped; ordinary loading is unchanged.
local mixedOptions=Spring and Spring.GetModOptions and Spring.GetModOptions() or {}
local mixedSelected=mixedOptions.prototype_diagnostic=='benchmark' and tostring(mixedOptions.prototype_mixed_force or '0')=='1'
 and VFS.Include('40k_configs/mixed_benchmark_exposure.lua').Selected(mixedOptions) or nil
if mixedSelected and not mixedSelected['ork_grot'] then return {} end
if not VFS.Include('40k_configs/ork_registration_gates.lua').Allowed('ork_grot',mixedOptions,mixedSelected) then return {} end
if not VFS.FileExists("objects3d/ork_grot.glb") or not VFS.FileExists("scripts/40k_roster.lua") or not VFS.FileExists("scripts/generated/ork_grot_anim.lua") then return {} end
-- Authored integration groundwork; native validation required.
return {ork_grot={name="Grot Builder",description="Builder with genuine hammer/wrench appearance",objectname="ork_grot.glb",script="40k_roster.lua",buildpic="40k_ork_grot.png",metalcost=30,energycost=150,buildtime=360,health=90,speed=18,maxacc=0.08,maxdec=0.2,turnrate=900,turninplace=true,canmove=true,canattack=false,category="ALL MOBILE NOTSUB SURFACE",footprintx=1,footprintz=1,maxslope=36,maxwaterdepth=5,sightdistance=430,customparams={faction="Orks",prototype40k=1,animsource="ork_grot",rosterrole="builder",unitgroup="builder",integration_status="requires_private_model_script_and_native_validation"},movementclass="SBOT2",builder=true,workertime=40,builddistance=90,canrepair=true,canreclaim=true,canassist=true,buildoptions={"ork_settlement","ork_boyz_hut","ork_mek_shop","ork_mek_lab","ork_generator","ork_resource_factory","ork_listening_post","ork_waaagh_banner"}}}
