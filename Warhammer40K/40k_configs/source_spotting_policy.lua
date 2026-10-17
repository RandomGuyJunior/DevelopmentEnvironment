-- Authored policy; sounds and private provenance are generated separately.
local M={}
M.sources={guardsman='guard',space_marine='marine',ork_boy='boy'}
M.paths={
 guard={'sound/speech/races/guard/shared/spotting/enemy/1001230.fda','sound/speech/races/guard/shared/spotting/enemy/1001231.fda'},
 marine={'sound/speech/races/space_marines/shared/spotting/enemy/406090.fda','sound/speech/races/space_marines/shared/spotting/enemy/406091.fda'},
 boy={'sound/speech/races/orks/shared/spotting/enemy/405060.fda','sound/speech/races/orks/shared/spotting/enemy/405061.fda'},
}
-- api is deliberately injected: this module neither queries hidden positions nor plays directly.
function M.New(api,clips)
 local nextTime=0
 local counts={}
 local self={}
 function self.Sighting(enemy,team,ally)
  if api.Spectator() or ally~=api.MyAlly() or api.Allied(team,api.MyTeam()) then return false end
  local los=api.Los(enemy,ally)
  if not (type(los)=='table' and los.los==true) then return false end
  local now=api.Time()
  if now<nextTime or not api.Ready() then return false end
  local ex,ey,ez=api.Position(enemy)
  if not ex then return false end
  local best,profile,distance
  for _,id in ipairs(api.OwnUnits() or {}) do
   if api.Team(id)==api.MyTeam() and not api.Dead(id) and api.Complete(id) then
    local cp=api.Params(id) or {}
    local p=tostring(cp.prototype40k)=='1' and M.sources[cp.animsource]
    if p then
     local x,y,z=api.Position(id)
     if x then
      local d=(x-ex)^2+(z-ez)^2
      if d<=1200^2 and (not best or d<distance or (d==distance and id<best)) then best,profile,distance=id,p,d end
     end
    end
   end
  end
  local list=profile and clips[profile]
  if not best or type(list)~='table' or #list==0 then return false end
  local n=(counts[profile] or 0)+1
  local c=list[(n-1)%#list+1]
  if type(c)~='table' or type(c.file)~='string' or type(c.duration)~='number' or c.duration~=c.duration or c.duration<=0 or c.duration>30 or not api.Exists(c.file) then return false end
  -- Bridge checks the shared busy lease, plays, then leases actual clip duration atomically.
  if api.Play(c.file,.8,c.duration,'enemy_spotted',best)~=true then return false end
  counts[profile]=n
  nextTime=now+math.max(12,c.duration+.12)
  return true
 end
 return self
end
return M
