-- Read-only bounded acceptance recipe, not a second corpse/reclaim owner.
local M={Version=1,Option='prototype_necron_remains_native_fixture',NativeDriverReady=false}
local function yes(v)return v==true or v==1 or v=='1'end
local rows={
 immortal={profile='necron_immortal',id=9,actor='nec_immortal',capacity=3,factory='nec_advanced_factory',feature='40k_immortal_corpse',body='nec_immortal_body',option='prototype_necron_immortal_squad',metal=85,energy=440,work=850},
 flayed={profile='necron_flayed',id=16,actor='nec_flayed',capacity=4,factory='nec_hq',feature='40k_flayed_one_corpse',body='nec_flayed_body',option='prototype_necron_flayed_squad',metal=55,energy=280,work=600}}
function M.Enabled(o)return yes((o or{})[M.Option])end
function M.Select(o,profiles,V)
 assert(M.Enabled(o),'Necron native recipe remains default off')
 assert(o.prototype_diagnostic=='normal'and yes(o.prototype_source_progression)and yes(o.prototype_development_playtest)
  and yes(o.prototype_source_paid_match),'Owned ordinary paid-production context required')
 assert(yes(o.prototype_necron_remains_pilot)and not yes(o.prototype_scale085_pilot),'Exact unscaled two-actor remains closure required')
 for _,key in ipairs({'prototype_spyder_harvest_review','prototype_corpse_reclaim_review','prototype_spyder_harvest_fixture','prototype_immortal_emitter_fixture','prototype_nob_corpse_fixture'})do assert(not yes(o[key]),'Competing diagnostic owner refused')end
 local row=assert(rows[o.prototype_necron_remains_native_actor],'Only Immortal or Flayed native remains recipe supported')
 assert(yes(o[row.option]),'Actual full-capacity profile option required')
 local p=profiles and profiles.profiles and profiles.profiles[row.profile]
 assert(p and p.id==row.id and p.capacity==row.capacity and p.product==row.actor,'Current actual paid squad profile mismatch')
 for _,path in ipairs({'objects3d/'..row.body..'.glb','unittextures/'..row.body..'_tex1.png','unittextures/'..row.body..'_tex2.png'})do assert(V and V.FileExists(path),'Genuine terminal closure missing '..path)end
 local r={};for k,v in pairs(row)do r[k]=v end
 r.builder='nec_scarab';r.builderFactory='nec_hq';r.builderBill={metal=110,energy=1600,work=3450}
 r.productBill={metal=row.metal*row.capacity,energy=row.energy*row.capacity,work=row.work*row.capacity}
 r.cohorts=2;r.victimsPerCohort=1;r.expectedFeatures=2;r.fraction=.25;r.salvageMetal=row.metal*.25;r.salvageEnergy=0;r.reclaimWork=math.max(1,row.work*.25)
 r.combatFunding='funded_hostile_actor_only';r.ownProduction='ordinary_earned_resources_no_acceleration';r.reclaim='one_observed_paid_native_Scarab_gradual_reclaim'
 r.throw='existing_actual_native_explosion_damage_then_single_sole_owner_flight_then_landing'
 r.sourceChecked=true;r.nativeAccepted=false;r.economyAccepted=false;r.nativeDriverReady=M.NativeDriverReady
 return r
end
function M.ValidateOwner(recipe,owner,F)
 assert(recipe and owner and owner.Fraction==.25 and type(owner.New)=='function'and owner.Actors[recipe.actor]
  and owner.Actors[recipe.actor].feature==recipe.feature,'Existing sole ordinary remains owner required')
 local found=0
 for _,d in pairs(F or{})do
  local cp=d.customParams or{}
  if d.name==recipe.feature then
   assert(cp.parent_actor==recipe.actor and (cp.prototype40k_tactical_remains==1 or cp.prototype40k_tactical_remains=='1') and d.reclaimable and d.resurrectable==0,'Exact genuine native remains FeatureDef required')
   found=found+1
  end
 end
 assert(found==1,'Exactly one FeatureDef and one native salvage entitlement required')
 return true
end
function M.DriverRefusal()
 return 'paid_native_Scarab_origin_and_natural_hostile_firing_adapter_not_integrated'
end
return M
