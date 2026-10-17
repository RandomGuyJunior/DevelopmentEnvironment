-- Retain actual stock sound items and add locally decoded source battle sounds.
local sounds=VFS.Include('40k_reference/sounds.lua')
if not VFS.FileExists('40k_configs/generated_audio.lua') then return sounds end
local clips=VFS.Include('40k_configs/generated_audio.lua')
for key,entries in pairs(clips)do
 if key:sub(1,7)=='weapon_' and entries[1] and VFS.FileExists(entries[1].file) then
  sounds.SoundItems['40k_'..key:sub(8)]={file=entries[1].file,gain=.7,maxconcurrent=8,rolloff=1,dopplerscale=0,pitchmod=.03,preload=true,in3d=true}
 end
end
return sounds
