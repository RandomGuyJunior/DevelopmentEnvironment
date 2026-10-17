function widget:GetInfo()return {name='40K source enemy spotting',desc='Owned representative speech from actual local LOS; no queue',author='Local project',layer=0,enabled=true}end
local opts=Spring.GetModOptions() or {}
if tostring(opts.prototype_source_spotting)~='1' or not VFS.FileExists('40k_configs/generated_spotting_audio.lua') then return end
local policy=VFS.Include('40k_configs/source_spotting_policy.lua')
local clips=VFS.Include('40k_configs/generated_spotting_audio.lua')
local start=Spring.GetTimer()
local function bridge()return WG.Recoil40KSourceSpeech end
local observer=policy.New({
 Spectator=Spring.GetSpectatingState,MyAlly=Spring.GetMyAllyTeamID,MyTeam=Spring.GetMyTeamID,
 Allied=Spring.AreTeamsAllied,Los=function(id,ally)return Spring.GetUnitLosState(id,ally,false)end,
 Time=function()return Spring.DiffTimers(Spring.GetTimer(),start)end,
 Position=Spring.GetUnitPosition,OwnUnits=function()return Spring.GetTeamUnits(Spring.GetMyTeamID())end,
 Team=Spring.GetUnitTeam,Dead=Spring.GetUnitIsDead,
 Complete=function(id)local _,_,_,_,p=Spring.GetUnitHealth(id);return p and p>=1 end,
 Params=function(id)local d=UnitDefs[Spring.GetUnitDefID(id)];return d and d.customParams end,
 Exists=VFS.FileExists,
 Ready=function()local b=bridge();return type(b)=='table' and type(b.PlayRepresentative)=='function' end,
 Play=function(...)local b=bridge();return b and b.PlayRepresentative(...) or false end,
},clips)
function widget:UnitEnteredLos(id,team,ally,def)observer.Sighting(id,team,ally)end
-- No Update, polling, direct playback, command interception or deferred events.
