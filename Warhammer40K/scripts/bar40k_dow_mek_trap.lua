function script.Create()end
function script.Activate()return 1 end
function script.Deactivate()return 0 end
function script.Killed(recent,max)return recent/max>.5 and 2 or 1 end
