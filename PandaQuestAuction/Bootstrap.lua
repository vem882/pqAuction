-- Use the core addon's public bridge; an older copy of PandaQuest has no matching API.
local _, ns = ...
local core = _G.PandaQuest
if not (core and core.RegisterAuctionExtension) then return end
function ns.AddOptions(sections, toggle)
    local L = ns.L
    local args = sections.sync.args
    args.shareAuctionScans = toggle(1.5, L["Share completed Auctionator scans"],
        L["Share item prices by realm and faction through Sync after logout or reload."],
        "global.telemetry.shareAuctionScans")
    args.recordOwnAuctions = toggle(1.6, L["Record my auctions privately"],
        L["Share your own listings and completed sale invoices privately with your PandaBase account through Sync."],
        "global.telemetry.recordOwnAuctions")
    sections.tools.args.itemPrice = {
        type = "input", order = 24, name = L["Item price lookup"],
        desc = L["Enter an item name, ID, or chat link."],
        get = function() return "" end,
        set = function(_, value) ns.Core.addon.commands.price(value) end,
    }
end

ns.COMMAND_LINE = "/pq price <item name, ID, or link> - show Auctionator and TradeSkillMaster prices"
core:RegisterAuctionExtension(1, ns)
