-- Data-only revised class reference; root owns atomic model/spatial integration.
-- Factors multiply current converted assets once, never the original source game.
local M={Version=1,Policy='orks_v14_class_reference_provisional_20261013'}
M.Reference={actor='corkorg',name='BAR Juggernaut',visibleHeight=144.76755809783936,
 pose='Create visibility and settled StopWalking BOS targets; native comparable-pose check pending'}
M.Dakka={actor='ork_dakka_stompa',factor=.7060140223403837,
 baselineModel='ork_dakka_stompa_multigun.glb',model='ork_dakka_stompa_jugref.glb',bank='ork_dakka_stompa_jugref',
 baselineModelSHA256='e625fae8852c44839edc7d5e91daf311906dad26a7baecdbf182e33fde6d8b93',
 baselineBankSHA256='b5f8b69e34c562ab04b07406229b33c904336270c3d59869a5d938bba59c6810',
 modelSHA256='184bb884ba03f5ceef1dda85cdbb4648527a5f9e89f1b45928cb4f7538f50748',
 bankSHA256='de744aa33697305d301db507443ae44a745184770ad524dac934ae51af49858d',
 idleDimensions={144.91661548401882,144.76755809783936,116.33213938324337},
 staticFootprintLowerBound={10,8},staticMarginPerSide=4,
 nativeAccepted=false,wreckPairRequired=true}
M.Classes={
 small_infantry={factor=1,policy='current Gretchin below Boyz; no Pawn floor'},
 infantry={factor=1,policy='retain current ordinary and heavy infantry; compact spacing from real bodies'},
 vehicle_walker={factor=1,policy='retain native/source role scales; no automatic Dakka multiplier'},
 large_non_titanic={policy='use Dakka reference visually; exact source-specific factor applies to Dakka only'},
 titanic={factor=1,policy='retain own coherent size; may exceed Juggernaut; no common ceiling'},
 aircraft_external={factor=1,policy='independent source-specific crew/hull/clearance fit; large Gunship may exceed ground reference'},
}
M.ExternalChoices={
 morkanaut={targetVisibleHeight=90,sourceApproximateHeight=350,provisionalFactor=90/350,
  policy='heavy walker below Dakka; final factor from exact comparable source pose'},
 ork_gunship={factor=.22,fullDimensions={122.1707,171.2748,303.7006},solidHullHeight=109.4399,
  policy='Gunship worker exact Orc_Ship2 source-specific fit; crane retains selection/model envelope; native flight/production pending'},
 warbike_rider={ordinaryOrkStandingReferenceHeight=20.58813885310195,
  policy='seat ordinary Ork after class fit; size bike to rider controls, no Dakka/Mork common factor'},
}
M.InvariantFields={simulation=1,reload=1,burstclock=1,researchtime=1,cost=1,damage=1,range=1,
 rotations=1,clipduration=1,XP=1,salvageEntitlement=1}
M.CoupledIntegration={
 'uniform vertices/node translations/inverse binds/animation translations once',
 'dedicated exact bank dispatch before existing 0.85 scale pilot; keep animsource/UnitDef identity stable',
 'rebind actual native bounds/cache/metadata checksums to new model bytes',
 'same-class wreck geometry, one native entitlement and unchanged remaining resources',
 'native collision/selection envelope, grid movement spacing and Teleporta release',
 'all existing orange pulse/belly/eye/four arm markers and scaled muzzle facts',
 'actor-local presentation effects; no shared CEG recolour/global effect scaling',
 'same gait clip clock; source contacts currently unmeasured so verify actual role stride',
}
-- Root may dispatch here from animation_bank_loader.Load only after complete
-- model/remains/spatial closure. The existing 0.85 pilot stays independent.
function M.LoadBank(V,cache,cp)
 local r=M.Dakka
 assert(cp.animsource==r.actor and cp.ork_v14_scale_bank==r.bank
  and tonumber(cp.ork_v14_scale_factor)==r.factor,'Wrong exact Dakka scale-bank identity')
 assert(not cp.scale_pilot_factor and not cp.scale_animation_bank,'Mixed historical 0.85 pilot')
 assert(cp.source_native_glb_sha256==r.modelSHA256,'Wrong paired Dakka model bytes')
 local path='scripts/40k_anim/'..r.bank..'.lua'
 assert(V.FileExists('objects3d/'..r.model)and V.FileExists(path),'Exact paired Dakka assets missing')
 local data=cache[path]
 if not data then data=assert(V.Include(path),'Exact paired Dakka bank absent')end
 local meta=assert(data.scaleDerivative,'Exact Dakka translation provenance absent')
 assert(meta.factor==r.factor and meta.baseSha256==r.baselineBankSHA256
  and meta.recipe=='translation-only-v1','Wrong exact Dakka bank provenance')
 cache[path]=data
 return data
end
return M
