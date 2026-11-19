-- Local price quotes from an installed Auctionator or TradeSkillMaster.
local _, ns = ...
local Core = ns.Core
if not Core then return end
local Log = Core.Log

function ns.Price(arg)
    local shareItem = arg:match("^(.-)%s+%-%-share$")
    local share = shareItem ~= nil
    arg = shareItem or arg
    local shared = false
    if arg == "" then
        Log.Print("Usage: /pq price <item name, ID, or link> [--share]")
        return
    end
    local itemID = tonumber(arg:match("^%d+$") or arg:match("|Hitem:(%d+)[:|]"))
    local db = Core.DB
    if not itemID then
        local query = arg:lower()
        for id in db.IterateItemIDs() do
            local name = db.GetItemName(id)
            if name and name:lower() == query then
                if itemID then
                    Log.Print("Several items are named %s. Shift-click the item into chat to use its link.", arg)
                    return
                end
                itemID = id
            end
        end
        if not itemID then
            local lookup = C_Item and C_Item.GetItemInfoInstant or _G.GetItemInfoInstant
            itemID = lookup and lookup(arg)
        end
        if not itemID then
            Log.Print("Item not found: %s. Shift-click the item into chat to use its link.", arg)
            return
        end
    end
    if not itemID or itemID < 1 or itemID > 2147483647 then
        Log.Print("Usage: /pq price <item name, ID, or link> [--share]")
        return
    end
    Log.Print("%s (item ID: %d)", db.GetItemName(itemID) or "Item", itemID)
    local Auctionator = _G.Auctionator
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    local function quote(label, source, lookup, ...)
        if type(lookup) ~= "function" then return false end
        local ok, copper = pcall(lookup, ...)
        if not ok or (issecretvalue and issecretvalue(copper)) then return false end
        if type(copper) ~= "number" or not (copper > 0 and copper < math.huge) then return false end
        copper = math.floor(copper)
        Log.Print("%s: %s", label, Core.FormatMoneyCoins(copper))
        if share and copper >= 1 and copper <= 1000000000000 and itemID <= 10000000 then
            local telemetry = Core.Telemetry
            if telemetry and telemetry.Record and telemetry.Record("AP", { item = itemID, money = copper, kind = source }) then
                shared = true
            end
        end
        return true
    end
    local scan = quote("Auctionator scan", "auctionator", api and api.GetAuctionPriceByItemID, "PandaQuest", itemID)
    local tsm = _G.TSM_API and _G.TSM_API.GetCustomPriceValue
    local recent = quote("TradeSkillMaster recent", "tsm_recent", tsm, "DBRecent", "i:" .. itemID)
    local market = quote("TradeSkillMaster market value", "tsm_market", tsm, "DBMarket", "i:" .. itemID)
    if shared then
        Log.Print("Price queued for public sharing by realm. Log out or reload, then run Sync.")
    elseif share and (scan or recent or market) then
        Log.Print("Price could not be queued. Check that PandaQuest data sharing is enabled.")
    end
    if not scan and not recent and not market then
        Log.Print("No Auctionator or TradeSkillMaster price available for item %d.", itemID)
    end
end
