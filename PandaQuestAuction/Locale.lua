local _, ns = ...

-- Auction UI has one canonical language on every client.  Keep this small
-- lookup boundary so all interface text is consistently English by default.
ns.L = setmetatable({}, { __index = function(_, key) return key end })
