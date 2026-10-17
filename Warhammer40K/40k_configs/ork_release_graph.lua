-- Authored source-coherent Ork graph. Coordinator owns readiness and native tech.
local M = {}
M.Build = {
 ork_grot={"ork_settlement","ork_boyz_hut","ork_generator","ork_resource_factory","ork_listening_post","ork_waaagh_banner","ork_mek_lab","ork_mek_shop","ork_hq_super"},
 ork_settlement={"ork_grot","ork_slugga","ork_warboss"},
 ork_boyz_hut={"ork_boy","ork_slugga","ork_burna","ork_tankbusta","ork_loota","ork_nob","ork_meganob"},
 ork_mek_shop={"ork_wartrak","ork_trukk","ork_gunwagon","ork_lobba","ork_killa_kan","ork_deff_dread","ork_squiggoth"},
 ork_resource_factory={"ork_looted_rhino","ork_battlewagon_armageddon","ork_battlefortress_armageddon"},
 ork_hq_super={"ork_kustim_stompa","ork_dakka_stompa","ork_gargant","ork_great_gargant"},
}
M.Requires = {
 ork_mek_lab={buildings={"ork_settlement","ork_boyz_hut"},tier=1},
 ork_mek_shop={buildings={"ork_settlement"},research={"ork_mek_technology"},tier=2},
 ork_nob={buildings={"ork_mek_lab"},research={"ork_ard_technology"},tier=2},
 ork_meganob={buildings={"ork_mek_lab"},research={"ork_ard_technology"},tier=2},
 ork_loota={research={"ork_ard_technology"},tier=2},
 ork_tankbusta={research={"ork_mek_technology"},tier=2},
 ork_gunwagon={research={"ork_mek_technology"},tier=2},
 ork_deff_dread={research={"ork_mek_technology"},tier=2},
 ork_squiggoth={buildings={"ork_waaagh_banner"},research={"ork_big_waaagh"},tier=3},
 ork_hq_super={buildings={"ork_mek_lab","ork_mek_shop","ork_waaagh_banner"},research={"ork_apocalypse"},tier=4},
 ork_kustim_stompa={buildings={"ork_hq_super"},research={"ork_apocalypse"},tier=4},
 ork_dakka_stompa={buildings={"ork_hq_super"},research={"ork_apocalypse"},tier=4},
 ork_gargant={buildings={"ork_hq_super"},research={"ork_apocalypse"},tier=4},
 ork_great_gargant={buildings={"ork_hq_super"},research={"ork_apocalypse"},tier=4},
}
M.Research = {
 {name="ork_mek_technology",producer="ork_mek_lab",cost={metal=350,energy=1800},time=40,requires={buildings={"ork_settlement"},tier=1}},
 {name="ork_ard_technology",producer="ork_mek_lab",cost={metal=500,energy=2200},time=50,requires={research={"ork_mek_technology"},tier=2}},
 {name="ork_big_waaagh",producer="ork_waaagh_banner",cost={metal=1200,energy=6500},time=90,requires={research={"ork_ard_technology"},buildings={"ork_mek_shop"},tier=2}},
 {name="ork_apocalypse",producer="ork_mek_lab",cost={metal=3000,energy=18000},time=150,requires={research={"ork_big_waaagh"},tier=3}},
}
local factories={ork_settlement=true,ork_boyz_hut=true,ork_mek_shop=true,ork_resource_factory=true,ork_hq_super=true}
local roles={ork_mek_lab="research",ork_mek_shop="tank_factory",ork_resource_factory="tank_factory",ork_hq_super="walker_factory",ork_waaagh_banner="research",ork_listening_post="extractor"}
local function isReady(ready,name)
 if type(ready)=="function" then return ready(name)==true end
 return type(ready)=="table" and ready[name]==true
end
function M.Apply(defs,ready)
 local result={producers=0,products=0,missing={}}
 -- Converted vital aliases retain native repair/build power and commander mechanics.
 -- Only a root-accepted marked Ork mobile builder receives this source menu.
 for name,def in pairs(defs) do
  local cp=def.customparams or {}
  if not M.Build[name] and isReady(ready,name) and cp.faction=="Orks"
   and (cp.rosterrole=="builder" or cp.rosterrole=="commander") then
   local options={};for _,target in ipairs(M.Build.ork_grot)do
    if defs[target] and isReady(ready,target) then options[#options+1]=target end
   end
   def.buildoptions=options
  end
 end
 for producer,candidates in pairs(M.Build) do
  local def=defs[producer]
  if def and isReady(ready,producer) then
   local options={}
   for _,name in ipairs(candidates) do
    if defs[name] and isReady(ready,name) then options[#options+1]=name;result.products=result.products+1
    else result.missing[#result.missing+1]={producer=producer,product=name} end
   end
   def.buildoptions=options
   if factories[producer] then def.builder=true;def.canmove=true;def.workertime=def.workertime or 150 end
   result.producers=result.producers+1
  end
 end
 for name,role in pairs(roles) do
  local def=defs[name]
  if def and isReady(ready,name) then
   def.customparams=def.customparams or {};def.customparams.rosterrole=role
   if name=="ork_listening_post"then
    -- Genuine Gork Totem attaches to Strategic Points and increases income via
    -- garrison_ext (source multiplier2.359999895). BAR metal spots represent
    -- those points; .001 is the documented native extraction baseline.
    def.extractsmetal=0.001*2.359999895
    def.activatewhenbuilt=true
    def.description="Gork Totem listening post — paid metal-spot income and Big Shoota defence"
    def.customparams.source_economy_adaptation="strategic_point_to_BAR_metal_spot_v1"
    def.customparams.source_garrison_requisition_multiplier=2.359999895
   end
   if name=="ork_resource_factory"then
    -- Genuine source Gork Factory is a vehicle producer, not a metal spot.
    -- Remove only this authored candidate's obsolete extractor adaptation.
    def.extractsmetal=0;def.energyupkeep=0
    def.metalmake=1.5 -- Explicit source passive1.5R/s to native1.5M/s adaptation.
    def.customparams.source_economy_adaptation="passive_requisition_to_BAR_metal_v1"
    def.description="Gork Factory — paid advanced vehicle production"
   end
   if name=="ork_mek_lab" or name=="ork_waaagh_banner" then
    -- Pinned BAR enumerates every buildoptions table after our overlay.
    def.buildoptions={};def.builder=false;def.canmove=false
   end
  end
 end
 return result
end
VFS.Include('40k_configs/ork_retired_content_policy.lua').FilterGraph(M)
return M
