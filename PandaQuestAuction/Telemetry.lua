-- Auction price recording in the same upload store as the core addon.
local _, ns = ...
local Core = ns.Core
if not Core then return end

local settings = Core.Telemetry.GetSettings
local Log, L = Core.Log, ns.L
local floor, format = math.floor, string.format
local M = {}
ns.Telemetry = M

local function unixNow()
    return (time and time()) or 0
end

-- Keep the newest full scan separate from quest recording and its rolling event buffer.
local pendingAuctionScan
local nativeAuctionScan
local MAX_SCAN_PRICES = 10000
M.MAX_NATIVE_AUCTION_PRICES = 50000

-- The PQ auction tab asks for explicit consent on each requested page.
function M.QueueNativeAuctionPrices(prices, quantities, listings, targeted)
    if not Core.IsTelemetryWanted() then return 0 end
    local scan = nativeAuctionScan or { at = unixNow(), events = {}, byItem = {} }
    local added = 0
    for id, copper in pairs(prices) do
        local event = scan.byItem[id]
        if event then
            event.money = math.min(event.money, copper)
            event.count = nil
            event.askn, event.askmed, event.askmax, event.sellers = nil, nil, nil, nil
        elseif #scan.events < M.MAX_NATIVE_AUCTION_PRICES then
            event = { e = "AP", t = 0, item = id, money = copper, kind = "native_scan" }
            scan.events[#scan.events + 1] = event
            scan.byItem[id] = event
            added = added + 1
        end
        -- One price event per item can combine targeted and full scans in the same session.
        if targeted and scan.byItem[id] then scan.byItem[id].targeted = true end
    end
    for id, quantity in pairs(quantities or {}) do
        local event = scan.byItem[id]
        if event then event.count = quantity end
    end
    for id, distribution in pairs(listings or {}) do
        local event = scan.byItem[id]
        if event then
            event.money = distribution.lowest
            event.askn, event.askmed, event.askmax = distribution.askn, distribution.askmed, distribution.askmax
            event.sellers = distribution.sellers
            event.t = math.min(30 * 86400, math.max(0, unixNow() - scan.at))
        end
    end
    if #scan.events > 0 then nativeAuctionScan = scan end
    return added
end

function M.NativeAuctionPriceCount()
    return nativeAuctionScan and #nativeAuctionScan.events or 0
end

local auctionatorHooked
local scanPrices
local function hookAuctionator()
    local addon = _G.Auctionator
    local database = addon and addon.Database
    local bus = addon and addon.EventBus
    if auctionatorHooked or not (database and database.ProcessScan and bus and bus.Register
        and _G.hooksecurefunc) then return end
    local completed = {}
    local fullScan = addon.FullScan and addon.FullScan.Events
    if fullScan and fullScan.ScanComplete then
        completed[#completed + 1] = fullScan.ScanComplete
    end
    -- Auctionator's Full Scan button can run the summary scanner on the modern auction house.
    -- PricesProcessed also fires for ordinary searches, so only listen for ScanComplete.
    local summaryScan = addon.IncrementalScan and addon.IncrementalScan.Events
    if summaryScan and summaryScan.ScanComplete then
        completed[#completed + 1] = summaryScan.ScanComplete
    end
    if #completed == 0 then return end
    auctionatorHooked = true
    _G.hooksecurefunc(database, "ProcessScan", function(_, items)
        scanPrices = nil
        if not Core.IsTelemetryWanted() or not settings().shareAuctionScans
            or type(items) ~= "table" then return end
        local prices = {}
        for key, listings in pairs(items) do
            local id = tonumber(key)
            if id and id >= 1 and id <= 10000000 and id % 1 == 0 and type(listings) == "table" then
                local cheapest
                for _, listing in ipairs(listings) do
                    local copper = type(listing) == "table" and listing.price
                    if type(copper) == "number" and not (_G.issecretvalue and _G.issecretvalue(copper))
                        and copper >= 1 and copper <= 1000000000000 and (not cheapest or copper < cheapest) then
                        cheapest = copper
                    end
                end
                if cheapest then prices[id] = floor(cheapest) end
            end
        end
        scanPrices = prices
    end)
    bus:Register({ ReceiveEvent = function()
        local prices = scanPrices
        scanPrices = nil
        if not prices or not Core.IsTelemetryWanted() or not settings().shareAuctionScans then return end
        local ids = {}
        for id in pairs(prices) do ids[#ids + 1] = id end
        table.sort(ids)
        local count = math.min(MAX_SCAN_PRICES, #ids)
        if count == 0 then return end
        local events = {}
        for index = 1, count do
            local id = ids[index]
            events[index] = { e = "AP", t = 0, item = id, money = prices[id], kind = "auctionator" }
        end
        pendingAuctionScan = { at = unixNow(), events = events }
        Log.Print("Queued %d of %d Auctionator prices. Log out or reload to send them with Sync.", count, #ids)
    end }, completed)
end

function ns.SavePendingScans()
    if settings().shareAuctionScans and pendingAuctionScan then
        Core.Telemetry.StoreSupplementalSession(pendingAuctionScan.at, pendingAuctionScan.events, "-auction")
    end
    if nativeAuctionScan then
        local all = nativeAuctionScan.events
        for first = 1, #all, MAX_SCAN_PRICES do
            local events = {}
            for i = first, math.min(#all, first + MAX_SCAN_PRICES - 1) do
                events[#events + 1] = all[i]
            end
            Core.Telemetry.StoreSupplementalSession(nativeAuctionScan.at, events, "-pq-auction-" .. first)
        end
    end
    pendingAuctionScan, nativeAuctionScan = nil, nil
end

function ns.ClearAuctionatorScan()
    scanPrices = nil
    pendingAuctionScan = nil
end

function ns.DiscardPendingScans()
    ns.ClearAuctionatorScan()
    nativeAuctionScan = nil
end

function ns.AppendSyncStatus(lines)
    if pendingAuctionScan then
        lines[#lines + 1] = format(L["Auctionator prices queued until logout or reload: %d"], #pendingAuctionScan.events)
    end

    if nativeAuctionScan then
        lines[#lines + 1] = format(L["PQ auction prices queued until logout or reload: %d"], #nativeAuctionScan.events)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:SetScript("OnEvent", function(_, event, name)
    if event == "AUCTION_HOUSE_SHOW" or name == "Auctionator" then hookAuctionator() end
end)
hookAuctionator()
