function widget:GetInfo()
 return {name='40K opted existing-model texture paths',desc='Already-created diagnostic actor texture identities only; not residency proof',author='Local project',layer=1011,enabled=true}
end
local o=Spring.GetModOptions()
local roster=o.prototype_diagnostic=='roster'
if tostring(o.prototype_texture_path_review)~='1' or (o.prototype_diagnostic~='six' and not roster) then return end
local names={'imp_guardsman','imp_marine','imp_russ','ork_boy','ork_meganob','ork_killa_kan'}
local selected={ork_burna=1,ork_slugga=2,ork_tankbusta=3}
local cap=roster and 3 or 6
local interval=roster and 30 or 300
local seen,last,stopped={},-300,false
local function json(v)
 if type(v)=='string' then return '"'..v:gsub('[%z\1-\31\\"]',function(c)return string.format('\\u%04x',c:byte())end)..'"' end
 if type(v)=='number' then return v==v and math.abs(v)<math.huge and tostring(v) or 'null' end
 if type(v)=='boolean' then return v and 'true' or 'false' end
 if type(v)~='table' then return 'null' end
 local out={};for k,x in pairs(v)do out[#out+1]=json(tostring(k))..':'..json(x)end;table.sort(out);return '{'..table.concat(out,',')..'}'
end
local function emit(v)Spring.Echo('40K_TEXTURE_PATH_REVIEW '..json(v))end
function widget:Update()
 if stopped then return end
 local f=Spring.GetGameFrame();if f<120 or f-last<interval then return end;last=f
 if not gl or type(gl.TextureInfo)~='function'then emit({event='refused',reason='native_texture_info_unavailable'});stopped=true;return end
 for _,id in ipairs(Spring.GetAllUnits())do
  local defID=Spring.GetUnitDefID(id);local d=defID and UnitDefs[defID]
  local ownership=Spring.GetUnitRulesParam(id,roster and '40k_roster_validation' or '40k_diagnostic_slot')
  local cp=d and d.customParams or {}
  local slot=roster and d and selected[d.name] or ownership
  local expected=not roster and type(slot)=='number' and slot==math.floor(slot) and names[slot]==(d and d.name)
  local phase=roster and Spring.GetUnitRulesParam(id,'40k_roster_phase')
  local phaseOwned=phase=='idle' or phase=='walk' or phase=='fire' or phase=='melee' or phase=='next'
   or phase=='attachment_1' or phase=='attachment_2' or phase=='attachment_3' or phase=='attachment_4'
  local sourceOwned=roster and type(ownership)=='number' and ownership==math.floor(ownership) and ownership>0
   and phaseOwned and (tostring(cp.prototype40k)=='1' or cp.prototype40k==true) and cp.faction=='Orks'
   and cp.animsource==d.name and d.modelpath=='objects3d/'..d.name..'.glb'
  if slot and not seen[slot] and (expected or sourceOwned)then
   if d and Spring.GetUnitIsDead(id)==false then
    -- Only this real already-created exact owned diagnostic actor's model.
    -- Native model proxy may LoadModel; never query arbitrary/unused definitions.
    local ok,model=pcall(function()return d.model end)
    local textures=ok and model and model.textures
    local aOK,a=pcall(gl.TextureInfo,'%'..defID..':0')
    local bOK,b=pcall(gl.TextureInfo,'%'..defID..':1')
    seen[slot]=true
    emit({event='actor',frame=f,id=id,definition=defID,name=d.name,slot=slot,ownership=ownership,ownershipRule=roster and '40k_roster_validation' or '40k_diagnostic_slot',mode=o.prototype_diagnostic,modelRead=ok,sourceProgression=tostring(o.prototype_source_progression or '0'),rosterPhase=phase,nativeModelPath=d.modelpath,animsource=cp.animsource,
     modelPaths=textures,tex1Info=aOK and a or nil,tex2Info=bOK and b or nil,
     tex1Observed=aOK and type(a)=='table',tex2Observed=bOK and type(b)=='table',
     nativeAcceptance=false,residency='unknown; native GL name/dimensions do not measure physical residency',
     scope=roster and 'exact3sourceOrk existing roster actors only; no filename texture load' or 'real40k_diagnostic_slot actor only; no filename texture load'})
   end
  end
 end
 local count=0;for _ in pairs(seen)do count=count+1 end
 if count==cap then stopped=true;emit({event='complete',actors=count,nativeAcceptance=false})
 elseif f>(roster and 5400 or 1800) then stopped=true;emit({event='incomplete',actors=count,nativeAcceptance=false})end
end
