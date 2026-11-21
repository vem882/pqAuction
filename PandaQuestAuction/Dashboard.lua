-- PandaQuest window: a local market dashboard.  Price rows are observations
-- from the player's scans; PandaBase/Sync may populate the same cache later.
local _, ns = ...
local Core = ns.Core
local L = ns.L
if not (Core and Core.Window and Core.Window.RegisterTab) then return end

local function money(value)
    return Core.FormatMoneyCoins and Core.FormatMoneyCoins(value or 0) or tostring(value or 0)
end

local function age(seconds)
    if seconds <= 0 then return L["now"] end
    if seconds < 3600 then return string.format(L["%d min"], math.floor(seconds / 60)) end
    if seconds < 86400 then return string.format(L["%d h"], math.floor(seconds / 3600)) end
    return string.format(L["%d d"], math.floor(seconds / 86400))
end

local function itemName(id)
    return (Core.DB and Core.DB.GetItemName and Core.DB.GetItemName(id))
        or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
        or (GetItemInfo and GetItemInfo(id)) or string.format(L["Item #%d"], id)
end

local function findItem(query)
    local id = tonumber(query:match("%d+"))
    if id then return id end
    local wanted = query:lower()
    for candidate in Core.DB.IterateItemIDs() do
        local name = Core.DB.GetItemName(candidate)
        if name and name:lower() == wanted then return candidate end
    end
end

local function parseMoney(value)
    local gold = tonumber(value:match("(%d+)%s*[gG]")) or 0
    local silver = tonumber(value:match("(%d+)%s*[sS]")) or 0
    local copper = tonumber(value:match("(%d+)%s*[cC]")) or 0
    if gold > 0 or silver > 0 or copper > 0 then return gold * 10000 + silver * 100 + copper end
    return tonumber(value)
end

local function build(panel)
    local page, query = "market", ""
    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -14)
    heading:SetText(L["Auction"])
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
    hint:SetPoint("RIGHT", -16, 0)
    hint:SetJustifyH("LEFT")

    local search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    search:SetSize(250, 22)
    search:SetPoint("TOPRIGHT", -18, -17)
    search:SetAutoFocus(false)
    search:SetTextInsets(7, 7, 0, 0)
    search:SetText("")
    local alertPrice = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    alertPrice:SetSize(110, 22)
    alertPrice:SetPoint("TOPLEFT", 355, -63)
    alertPrice:SetAutoFocus(false)
    alertPrice:SetTextInsets(7, 7, 0, 0)
    local alertStatus = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    alertStatus:SetPoint("LEFT", alertPrice, "RIGHT", 8, 0)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -92)
    scroll:SetPoint("BOTTOMRIGHT", -35, 14)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(math.max(1, width))
    end)
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT")
    text:SetPoint("RIGHT")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")

    local function refresh()
        local lines, now = {}, time()
        if page == "market" then
            ns.Telemetry.CaptureVisibleAuctionPrices()
            local rows = {}
            for id, row in pairs(ns.Telemetry.GetMarketPrices()) do
                local name = itemName(id)
                if query == "" or name:lower():find(query:lower(), 1, true) then
                    rows[#rows + 1] = { id = id, name = name, row = row }
                end
            end
            table.sort(rows, function(a, b) return a.row.money > b.row.money end)
            hint:SetText(L["Local and synced price estimates · arrow shows the change since the previous observation"])
            for i = 1, math.min(#rows, 250) do
                local row = rows[i]
                local change = "—"
                if row.row.previous and row.row.previous > 0 then
                    local pct = math.floor((row.row.money - row.row.previous) * 100 / row.row.previous + 0.5)
                    change = pct < 0 and string.format(L["|cff52d273↓ %d%% · buy signal|r"], -pct)
                        or pct > 0 and string.format(L["|cffffc050↑ %d%% · sell signal|r"], pct)
                        or L["→ stable"]
                end
                lines[#lines + 1] = string.format(L["%s  |cffffd100%s|r  %s  |cff999999%s ago · %s|r"],
                    row.name, money(row.row.money), change, age(now - row.row.at), row.row.source or L["scan"])
            end
            if #rows == 0 then lines[1] = L["No price observations. Open the auction house and run a scan."] end
        else
            local store = _G.PandaQuestOwnAuctions
            local character
            if store and Core.Telemetry and Core.Telemetry.GetCharacterIdentity then
                local key = Core.Telemetry.GetCharacterIdentity()
                character = store.characters and store.characters[key]
            end
            if page == "listings" then
                hint:SetText(L["Your active listings · return time is the auction expiry countdown"])
                for _, row in ipairs((character and character.snapshot and character.snapshot.listings) or {}) do
                    local left = row.expiresAt and age(math.max(0, row.expiresAt - now)) or L["unavailable"]
                    lines[#lines + 1] = string.format(L["%s ×%d  |cffffd100%s|r  |cff999999returns in %s|r"],
                        itemName(row.itemId), row.quantity, money(row.buyout), left)
                end
                if #lines == 0 then lines[1] = L["No active auction listings."] end
            else
                hint:SetText(L["Completed sales read from your mailbox"])
                for _, row in ipairs((character and character.sales) or {}) do
                    lines[#lines + 1] = string.format(L["%s ×%d  |cffffd100%s net|r  |cff999999%s ago|r"],
                        row.itemName, row.quantity, money(row.net), age(now - row.observedAt))
                end
                if #lines == 0 then lines[1] = L["No completed mailbox sales recorded."] end
            end
        end
        text:SetText(table.concat(lines, "\n"))
        content:SetHeight(math.max(1, text:GetStringHeight()))
        scroll:SetVerticalScroll(0)
    end
    for i, spec in ipairs({ { "market", L["Market"] }, { "listings", L["Listings"] }, { "sales", L["Sold"] } }) do
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(105, 24); b:SetPoint("TOPLEFT", 16 + (i - 1) * 110, -62); b:SetText(spec[2])
        b:SetScript("OnClick", function() page = spec[1]; refresh() end)
    end
    local function addAlert(direction)
        local id, threshold = findItem(search:GetText() or ""), parseMoney(alertPrice:GetText() or "")
        if not id or not threshold or threshold < 1 then
            alertStatus:SetText(L["Enter an exact item name or ID and a price (e.g. 12g 50s)."])
            return
        end
        ns.Telemetry.SetPriceAlert(id, threshold, direction)
        alertStatus:SetText((direction == "below" and L["Alert below "] or L["Alert above "]) .. money(threshold))
    end
    for i, spec in ipairs({ { "below", L["Alert ≤"] }, { "above", L["Alert ≥"] } }) do
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(78, 24); b:SetPoint("TOPLEFT", 470 + (i - 1) * 82, -62); b:SetText(spec[2])
        b:SetScript("OnClick", function() addAlert(spec[1]) end)
    end
    search:SetScript("OnTextChanged", function(self) query = self:GetText() or ""; refresh() end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    panel:SetScript("OnShow", function()
        content:SetWidth(math.max(1, scroll:GetWidth()))
        refresh()
    end)
    return panel
end

Core.Window.RegisterTab("auction", "Auction", build)
