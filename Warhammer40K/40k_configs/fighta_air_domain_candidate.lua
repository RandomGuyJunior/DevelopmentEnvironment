-- Genuine Fighta joins only the existing Ork T1 native air production branch.
local M={Version=1,Actor='ork_fighta_bomba',Producer='fortyk_ork_air_factory'}
local function hash(s)return type(s)=='string'and #s==64 and not s:find('[^0-9a-f]')end
function M.ReadyFacts(f)
 if not f or f.domain_asset_closure_schema~=1 or type(f.domain_asset_hashes)~='table'then return false,'unverified_domain_asset_closure'end
 for _,name in ipairs({'objects3d/ork_fighta_bomba.glb','unittextures/ork_fighta_bomba_tex1.png','unittextures/ork_fighta_bomba_tex2.png','unitpics/40k_ork_fighta_bomba.png','scripts/generated/ork_fighta_bomba_anim.lua'})do
  if not hash(f.domain_asset_hashes[name])then return false,'missing_domain_hash_'..name end
 end
 if f.domain_asset_hashes['objects3d/ork_fighta_bomba.glb']~=f.native_glb_sha256 then return false,'actor_model_hash_mismatch'end
 return true
end
function M.Attach(defs,domain,facts,builder,ready)
 local f=facts and facts[M.Actor];local ok,why=M.ReadyFacts(f);if not ok then return false,why end
 local producer=defs[M.Producer]
 if not producer or not producer.builder or not producer.buildoptions or(producer.customparams or{}).prototype40k_factory_domain~='air'
  or(producer.customparams or{}).faction~='Orks'or type(producer.workertime)~='number'or producer.workertime<=0 then return false,'missing_real_Ork_air_factory'end
 if defs[M.Actor]and(defs[M.Actor].customparams or{}).prototype40k_ork_aircraft_domain==1 then return false,'already_attached'end
 if not ready or not ready(M.Actor)then return false,'missing_private_asset_closure'end
 -- Existing helper preserves the four original weapons and moves native work to
 -- this actual factory's worker power. No Flytower/HQ/research unlock is invented.
 ok,why=domain.AddFighta(defs,facts,builder,ready);if not ok then return false,why end
 local d=defs[M.Actor];local c=d.customparams
 c.prototype40k_genuine_air_domain=1;c.prototype40k_domain_asset_schema=1
 c.prototype40k_short_role='T1 fighter-bomber';c.source_domain_producer=M.Producer
 c.source_landing_acceptance='pending';c.source_flight_acceptance='pending';c.source_death_acceptance='pending'
 c.source_original_producer=f.production.source_entity -- Provenance, not a prerequisite.
 local count=0;for _,key in ipairs(producer.buildoptions)do if key==M.Actor then count=count+1 end end
 assert(count==1,'Fighta menu duplicate');assert(d.canfly and #d.weapons==4,'Genuine aircraft contract missing')
 return {definitions={M.Actor},Requires={[M.Actor]={}},producer=M.Producer,
  nativeBuildWork=d.buildtime,nominalSeconds=d.buildtime/producer.workertime,flightAcceptance='pending'}
end
return M
