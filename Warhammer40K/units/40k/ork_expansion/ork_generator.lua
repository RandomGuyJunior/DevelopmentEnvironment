-- Explicit mixed test exposure is exact-key scoped; ordinary loading is unchanged.
local mixedOptions=Spring and Spring.GetModOptions and Spring.GetModOptions() or {}
local mixedSelected=mixedOptions.prototype_diagnostic=='benchmark' and tostring(mixedOptions.prototype_mixed_force or '0')=='1'
 and VFS.Include('40k_configs/mixed_benchmark_exposure.lua').Selected(mixedOptions) or nil
if mixedSelected and not mixedSelected['ork_generator'] then return {} end
if not VFS.Include('40k_configs/ork_registration_gates.lua').Allowed('ork_generator',mixedOptions,mixedSelected) then return {} end
if not VFS.FileExists("objects3d/ork_generator.glb") or not VFS.FileExists("scripts/40k_roster.lua") or not VFS.FileExists("scripts/generated/ork_generator_anim.lua") then return {} end
-- Authored integration groundwork; native validation required.
return {ork_generator={name="Ork Generator",description="Energy economy",objectname="ork_generator.glb",script="40k_roster.lua",buildpic="40k_ork_generator.png",metalcost=65,energycost=325,buildtime=780,health=450,speed=0,yardmap="oooooooooooooooooooooooooooooooooooo",maxacc=0.08,maxdec=0.2,turnrate=400,turninplace=true,canmove=false,canattack=false,category="ALL NOTSUB SURFACE",footprintx=6,footprintz=6,maxslope=24,maxwaterdepth=5,sightdistance=430,customparams={faction="Orks",prototype40k=1,animsource="ork_generator",rosterrole="generator",unitgroup="util",integration_status="requires_private_model_script_and_native_validation"},energymake=30}}
