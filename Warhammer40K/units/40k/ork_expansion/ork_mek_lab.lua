-- Explicit mixed test exposure is exact-key scoped; ordinary loading is unchanged.
local mixedOptions=Spring and Spring.GetModOptions and Spring.GetModOptions() or {}
local mixedSelected=mixedOptions.prototype_diagnostic=='benchmark' and tostring(mixedOptions.prototype_mixed_force or '0')=='1'
 and VFS.Include('40k_configs/mixed_benchmark_exposure.lua').Selected(mixedOptions) or nil
if mixedSelected and not mixedSelected['ork_mek_lab'] then return {} end
if not VFS.Include('40k_configs/ork_registration_gates.lua').Allowed('ork_mek_lab',mixedOptions,mixedSelected) then return {} end
if not VFS.FileExists("objects3d/ork_mek_lab.glb") or not VFS.FileExists("scripts/40k_roster.lua") or not VFS.FileExists("scripts/generated/ork_mek_lab_anim.lua") then return {} end
-- Authored integration groundwork; native validation required.
return {ork_mek_lab={name="Mek Lab",description="Heavy infantry and walker production",objectname="ork_mek_lab.glb",script="40k_roster.lua",buildpic="40k_ork_mek_lab.png",metalcost=420,energycost=2100,buildtime=5040,health=2400,speed=0,yardmap="eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",maxacc=0.08,maxdec=0.2,turnrate=400,turninplace=true,canmove=true,canattack=false,category="ALL NOTSUB SURFACE",footprintx=6,footprintz=6,maxslope=24,maxwaterdepth=5,sightdistance=430,customparams={faction="Orks",prototype40k=1,animsource="ork_mek_lab",rosterrole="walker_factory",unitgroup="util",integration_status="requires_private_model_script_and_native_validation"},builder=true,workertime=150,buildoptions={"ork_meganob","ork_killa_kan","ork_deff_dread"},canassist=true,canrepair=true,builddistance=180}}
