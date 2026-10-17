-- Genuine rigid-piece visibility and factory poses. No unit/resource grants.
local M={}
function M.New(meta,data,A)
 assert(meta.version==1 and meta.meshPieces,'Verified native candidate metadata required')
 local refs={};for mesh,names in pairs(meta.meshPieces)do refs[mesh]={};for _,name in ipairs(names)do refs[mesh][#refs[mesh]+1]=assert(A.resolve(name),'Missing genuine mesh piece '..name)end end
 local sequence
 assert(meta.factory_kind=='hq'or meta.factory_kind=='barracks'or meta.factory_kind=='support','Unknown genuine building kind')
 if meta.factory_kind=='hq'or meta.factory_kind=='barracks'then
  assert(A.isFactory,'Source factory metadata requires native factory')
  sequence=VFS.Include('scripts/40k_marine_factory_sequence.lua').New(data.clips,meta.factory_kind)
 end
 local R={};local active=false;local ready=false;local product;local awaitingProduct=false;local previousStage;local previousVisibility
 local clipNames={};for name,clip in pairs(data.clips)do clipNames[clip]=name end
 local function stance(value)if ready~=value then ready=value;A.stance(value)end end
 local function level()
  if meta.factory_kind~='hq'then return 0 end
  if A.addon('imp_source_hq_addon_2')then return 2 end
  if A.addon('imp_source_hq_addon_1')then return 1 end
  return 0
 end
 local function visibility(set,tier)
  if previousVisibility==set and R.lastTier==tier then return end
  local tiers=meta.levels
  for mesh,pieces in pairs(refs)do
   local visible=assert(set[mesh]~=nil,'Incomplete source visibility '..mesh)and set[mesh]
   -- Explicit native layering adaptation: preserve measured paid-tier parts
   -- while source production stages own their remaining source mesh flags.
   if tier>0 and tiers and(tiers[0][mesh]~=tiers[1][mesh]or tiers[0][mesh]~=tiers[2][mesh])then visible=tiers[tier][mesh]end
   for _,p in ipairs(pieces)do if visible then A.show(p)else A.hide(p)end end
  end
  previousVisibility=set;R.lastTier=tier
 end
 function R.Base(frame)
  local tier=level();local label=(meta.idle_clips_by_level or{})[tier]or'idle'
  local clip=assert(data.clips[label],'Missing genuine tier pose '..label)
  return clip,tier
 end
 function R.Tick(frame)
  if awaitingProduct then
   local actual=A.product();if actual~=nil then product=actual;awaitingProduct=false end
  end
  local base,tier=R.Base(frame)
  if sequence then
   if sequence.State()==0 and active and A.queued()then sequence.Activate(frame)end
   local clip,age,isReady=sequence.Tick(frame);stance(isReady)
   local stage=sequence.State()
   if A.observe and previousStage~=stage then A.observe(stage,frame,product or -1,isReady);previousStage=stage end
   if clip then visibility(assert(meta.clip_visibility[clipNames[clip]],'Missing source stage visibility'),tier);return clip,age,base,tier end
  end
  visibility((meta.levels or{})[tier]or meta.defaultVisibility,tier)
  return nil,0,base,tier
 end
 function R.Activate(frame)
  assert(sequence,'Not a source factory');active=true;A.stance(false);ready=false;sequence.Activate(frame)
 end
 function R.Deactivate(frame)
  assert(sequence,'Not a source factory');active=false;sequence.Deactivate(frame);stance(false)
 end
 function R.StartBuilding(frame)
  if not sequence or not sequence.StartBuilding(frame)then return false end
  -- Native Factory::StartBuild invokes this before assigning curBuild.
  -- Bind only the real native product on a later tick/completion callback.
  product=nil;awaitingProduct=true;return true
 end
 function R.StopBuilding(frame)
  if sequence then sequence.StopBuilding(frame)end;product=nil;awaitingProduct=false
 end
 function R.ProductFinished(id,frame)
  if awaitingProduct then
   local actual=A.product();if actual~=nil then product=actual;awaitingProduct=false end
  end
  if not sequence or product~=id then return false end
  product=nil;local okay=sequence.ProductFinished(frame);if okay then stance(false)end;return okay
 end
 R.isFactory=sequence~=nil
 return R
end
return M
