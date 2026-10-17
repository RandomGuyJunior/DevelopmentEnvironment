-- Compatibility shim for old private stock Info overlays. No rating reads or display.
-- Fresh assembly should use the untouched stock widget instead.
local M={}
function M.Description(base)return base end
return M
