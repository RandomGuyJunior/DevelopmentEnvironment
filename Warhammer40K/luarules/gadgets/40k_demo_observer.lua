function gadget:GetInfo()
 return {name="40K demo observer",desc="Opt-in real native combat and production evidence",author="Local project",layer=102,enabled=true}
end
if not gadgetHandler:IsSyncedCode() then return end
local options=Spring.GetModOptions()
if options.prototype_diagnostic~="demo" and options.prototype_diagnostic~="production" then return end
local finishFrame=tonumber(options.prototype_test_end_frame) or 0
local finished=false
local builders,hits,firstHits,kills={}, {}, {}, {}
local names={"imp_guardsman","imp_marine","imp_russ","ork_boy","ork_meganob","ork_killa_kan"}
local function prototype(def)
 return def and UnitDefs[def] and (UnitDefs[def].customParams or {}).prototype40k
end
local function quoted(value)
 local s=tostring(value or "")
 s=s:gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n"):gsub("\r","\\r")
 return '"'..s..'"'
end
local function emit(kind,fields)
 Spring.Echo('40K_DEMO {"event":'..quoted(kind)..',"frame":'..Spring.GetGameFrame()..(fields or "")..'}')
end
local function name(def) return def and UnitDefs[def] and UnitDefs[def].name or "unknown" end
local function sortedKeys(tableValue)
 local keys={};for key in pairs(tableValue) do keys[#keys+1]=key end
 table.sort(keys);return keys
end
local function summarize()
 for _,key in ipairs(sortedKeys(hits)) do
  local h=hits[key]
  emit("native_damage",',"attacker":'..quoted(h.attacker)..',"weapon":'..quoted(h.weapon)..
   ',"attacker_team":'..h.team..',"victim_team":'..h.victimTeam..',"hits":'..h.count..
   ',"damage":'..string.format("%.3f",h.damage)..',"interval_first_frame":'..h.first..
   ',"interval_last_frame":'..h.last)
 end
 hits={}
 local teams=Spring.GetTeamList();table.sort(teams)
 for _,team in ipairs(teams) do
  if team~=Spring.GetGaiaTeamID() then
   local counts,factories,nativeCombat={},0,0
   for _,n in ipairs(names) do counts[n]=0 end
   local units=Spring.GetTeamUnits(team) or {};table.sort(units)
   for _,id in ipairs(units) do
    local def=Spring.GetUnitDefID(id)
    local ud=def and UnitDefs[def]
    if ud then
     if counts[ud.name] then counts[ud.name]=counts[ud.name]+1 end
     if ud.isFactory then factories=factories+1 end
     if not prototype(def) and ud.canMove and not (ud.isBuilder or ud.builder)
      and ud.weapons and #ud.weapons>0 then nativeCombat=nativeCombat+1 end
    end
   end
   local fields=',"team":'..team..',"factories":'..factories..',"native_mobile_combat":'..nativeCombat
   for _,n in ipairs(names) do fields=fields..','..quoted(n)..':'..counts[n] end
   local metal,ms,_,mi,me=Spring.GetTeamResources(team,"metal")
   local energy,es,_,ei,ee=Spring.GetTeamResources(team,"energy")
   fields=fields..string.format(',"metal":%.3f,"metal_storage":%.3f,"metal_income":%.3f,"metal_expense":%.3f,"energy":%.3f,"energy_storage":%.3f,"energy_income":%.3f,"energy_expense":%.3f',metal or 0,ms or 0,mi or 0,me or 0,energy or 0,es or 0,ei or 0,ee or 0)
   emit("force_economy",fields)
  end
 end
end
function gadget:Initialize()
 emit("observer_start",',"requested_end_frame":'..finishFrame)
end
function gadget:UnitCreated(id,def,team,builder)
 if prototype(def) then
  local builderDef=builder and Spring.GetUnitDefID(builder)
  builders[id]={id=builder or -1,def=builderDef}
  emit("native_created",',"team":'..team..',"unit":'..quoted(name(def))..',"id":'..id..
   ',"builder_id":'..(builder or -1)..',"builder":'..quoted(name(builderDef)))
 end
end
function gadget:UnitFinished(id,def,team)
 if prototype(def) then
  local builder=builders[id] or {id=-1}
  emit("native_finished",',"team":'..team..',"unit":'..quoted(name(def))..',"id":'..id..
   ',"builder_id":'..builder.id..',"builder":'..quoted(name(builder.def)))
 end
end
function gadget:UnitDamaged(id,def,team,damage,paralyzer,weapon,projectile,attacker,attackerDef,attackerTeam)
 if finished or not prototype(attackerDef) or paralyzer or damage<=0 then return end
 local weaponName=weapon and WeaponDefs[weapon] and WeaponDefs[weapon].name or "unknown"
 local attackerName=name(attackerDef)
 local sourceTeam=attackerTeam or (attacker and Spring.GetUnitTeam(attacker)) or -1
 local key=attackerName..":"..weaponName..":"..sourceTeam..":"..team
 local frame=Spring.GetGameFrame()
 local h=hits[key] or {attacker=attackerName,weapon=weaponName,team=sourceTeam,victimTeam=team,count=0,damage=0,first=frame}
 h.count,h.damage,h.last=h.count+1,h.damage+damage,frame
 hits[key]=h
 if not firstHits[key] then
  firstHits[key]=true
  emit("native_first_hit",',"attacker":'..quoted(attackerName)..',"weapon":'..quoted(weaponName)..
   ',"attacker_team":'..sourceTeam..',"victim_team":'..team..',"victim":'..quoted(name(def))..
   ',"damage":'..string.format("%.3f",damage)..',"projectile_id":'..(projectile or -1))
 end
end
function gadget:UnitDestroyed(id,def,team,attacker,attackerDef,attackerTeam)
 if prototype(def) or prototype(attackerDef) then
  local attackerName=name(attackerDef)
  kills[attackerName]=(kills[attackerName] or 0)+1
  emit("native_casualty",',"victim":'..quoted(name(def))..',"victim_id":'..id..',"victim_team":'..team..
   ',"attacker":'..quoted(attackerName)..',"attacker_team":'..(attackerTeam or -1))
 end
 builders[id]=nil
end
function gadget:GameFrame(f)
 if finished then return end
 if f%(Game.gameSpeed*30)==0 then summarize() end
 if finishFrame>0 and f>=finishFrame then
  summarize();finished=true
  for _,attacker in ipairs(sortedKeys(kills)) do
   emit("kill_total",',"attacker":'..quoted(attacker)..',"kills":'..kills[attacker])
  end
  emit("complete",',"reason":"requested_game_duration"')
  Spring.SetGameRulesParam("40k_demo_observer_done",1)
 end
end
