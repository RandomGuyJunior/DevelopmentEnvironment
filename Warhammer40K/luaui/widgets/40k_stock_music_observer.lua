function widget:GetInfo()return{name='40K default-off stock music observer',desc='Bounded readonly playback/settings evidence; no sound control',author='Local project',layer=-50,enabled=true}end
local M=VFS.Include('40k_configs/stock_music_observation.lua')
if not M.Enabled(Spring.GetModOptions()or{})then return false end
local observer
function widget:Initialize()observer=M.New(Spring,WG)end
function widget:Update()observer.Update()end
