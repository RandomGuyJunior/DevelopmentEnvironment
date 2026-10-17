-- Readonly unsynced evidence. Stream clocks and metadata never prove heard audio.
local M={Option='prototype_stock_music_observer',Interval=2,MaxSamples=151,MaxSeconds=300}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
local function integer(n)return finite(n)and n>=0 and n%1==0 end
function M.Enabled(o)return type(o)=='table'and(o[M.Option]==true or o[M.Option]==1 or o[M.Option]=='1')end
function M.Read(S,W)
 assert(type(W)=='table'and type(W.music)=='table'and type(W.music.GetPlaybackEvidence)=='function','Stock readonly music getter unavailable')
 local r=W.music.GetPlaybackEvidence()
 assert(type(r)=='table'and r.schema==1,'Exact stock evidence schema required')
 assert(r.track==nil or type(r.track)=='string'and r.track:match('^music/40k/[^\r\n]+%.ogg$')and not r.track:find('..',1,true),'Expected virtual source music root')
 assert(type(r.category)=='string'and r.category:match('^[A-Za-z]+$'),'Typed stock category required')
 assert(type(r.playing)=='boolean'and type(r.changing)=='boolean','Typed stock playback state')
 assert(r.fadeDirection==nil or r.fadeDirection==-1 or r.fadeDirection==1,'Typed stock fade direction')
 -- Stock fade accumulator can overshoot; its existing setter clamps output.
 -- Preserve the actual finite raw accumulator without inventing applied volume.
 assert(finite(r.fadeLevel)and finite(r.musicVolume)and r.musicVolume>=0 and r.musicVolume<=100,'Finite stock fade and bounded saved volume snapshot')
 local elapsed,duration=S.GetSoundStreamTime();assert(finite(elapsed)and finite(duration)and elapsed>=0 and duration>=0,'Finite native stream clocks')
 local wanted,speed,paused=S.GetGameSpeed();assert(finite(wanted)and wanted>=0 and finite(speed)and speed>=0 and type(paused)=='boolean','Typed actual simulation pause state')
 local frame=S.GetGameFrame();assert(integer(frame),'Actual nonnegative native frame')
 local config={};for _,key in ipairs({'music','snd_volmaster','snd_volmusic','UseSoundtrackNew','UseSoundtrackCustom','UseSoundtrackFades','UseSoundtrackInterruption'})do
  local value=S.GetConfigInt(key,-999);assert(finite(value)and value%1==0,'Typed native configuration read');config[key]=value
 end
 return{frame=frame,track=r.track,category=r.category,playing=r.playing,changing=r.changing,fadeDirection=r.fadeDirection,fadeLevel=r.fadeLevel,musicVolume=r.musicVolume,elapsed=elapsed,duration=duration,wantedSpeed=wanted,speed=speed,paused=paused,config=config}
end
function M.New(S,W)
 local start=S.GetTimer();local nextSample,count,ended=0,0,false
 local R={}
 function R.Update()
  if ended then return end
  local now=S.DiffTimers(S.GetTimer(),start);assert(finite(now)and now>=0,'Native wall clock required')
  if now<M.Interval*nextSample then return end
  if now>M.MaxSeconds or count>=M.MaxSamples then ended=true;S.Echo('40K MUSIC OBSERVER END','bounded','audibleAccepted=false','mixingAccepted=false');return end
  nextSample=math.floor(now/M.Interval)+1;count=count+1
  local ok,row=pcall(M.Read,S,W)
  if not ok then S.Echo('40K MUSIC OBSERVER UNAVAILABLE',count,'getter_or_typed_readback','audibleAccepted=false');return end
  S.Echo('40K MUSIC OBSERVER SAMPLE',count,row.frame,string.format('%.6f',now),'track',string.format('%q',row.track or''),'category',row.category,'playing',row.playing,'changing',row.changing,'fade',row.fadeDirection or 0,row.fadeLevel,'volume',row.musicVolume,'stream',row.elapsed,row.duration,'simulation',row.wantedSpeed,row.speed,row.paused,'config',row.config.music,row.config.snd_volmaster,row.config.snd_volmusic,row.config.UseSoundtrackNew,row.config.UseSoundtrackCustom,row.config.UseSoundtrackFades,row.config.UseSoundtrackInterruption,'audibleAccepted=false','mixingAccepted=false','playlistIdentityAccepted=false')
 end
 return R
end
return M
