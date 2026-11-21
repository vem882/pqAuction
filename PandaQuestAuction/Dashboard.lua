-- PandaQuest window: local market observations presented as item rows.
local _, ns = ...
local Core, L = ns.Core, ns.L
if not (Core and Core.Window and Core.Window.RegisterTab) then return end

local function money(value) return Core.FormatMoneyCoins and Core.FormatMoneyCoins(value or 0) or tostring(value or 0) end
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
local function itemIcon(id)
    return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id))
        or (GetItemIcon and GetItemIcon(id)) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function tooltip(frame, id)
    frame:SetScript("OnEnter", function(self)
        if GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:" .. id); GameTooltip:Show() end
        self:SetBackdropColor(0.18, 0.15, 0.08, 0.75)
    end)
    frame:SetScript("OnLeave", function(self) if GameTooltip then GameTooltip:Hide() end; self:SetBackdropColor(0.07, 0.07, 0.08, 0.8) end)
end
local function parseMoney(value)
    local gold, silver, copper = tonumber(value:match("(%d+)%s*[gG]")) or 0, tonumber(value:match("(%d+)%s*[sS]")) or 0, tonumber(value:match("(%d+)%s*[cC]")) or 0
    if gold > 0 or silver > 0 or copper > 0 then return gold * 10000 + silver * 100 + copper end
    return tonumber(value)
end

local function build(panel)
    local page, query, selected, rows, bars = "market", "", nil, {}, {}
    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -14); heading:SetText(L["Auction"])
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5); hint:SetPoint("RIGHT", -16, 0); hint:SetJustifyH("LEFT")
    local search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    search:SetSize(250, 22); search:SetPoint("TOPRIGHT", -18, -17); search:SetAutoFocus(false); search:SetTextInsets(7, 7, 0, 0)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -92); scroll:SetPoint("BOTTOMRIGHT", -35, 14)
    local content = CreateFrame("Frame", nil, scroll); content:SetSize(1, 1); scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(math.max(1, width)) end)
    local empty = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    empty:SetPoint("TOPLEFT"); empty:SetPoint("RIGHT"); empty:SetJustifyH("LEFT")

    local detail = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    detail:SetSize(344, 300); detail:SetPoint("TOPRIGHT", -14, -52)
    detail:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    detail:SetBackdropColor(0.04, 0.04, 0.05, 0.98); detail:SetBackdropBorderColor(0.65, 0.52, 0.18, 1); detail:Hide()
    local detailName = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detailName:SetPoint("TOPLEFT", 16, -14); detailName:SetPoint("RIGHT", -38, 0); detailName:SetJustifyH("LEFT")
    local close = CreateFrame("Button", nil, detail, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2); close:SetScript("OnClick", function() detail:Hide(); selected = nil end)
    local detailPrice = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    detailPrice:SetPoint("TOPLEFT", detailName, "BOTTOMLEFT", 0, -6)
    local graphLabel = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    graphLabel:SetPoint("TOPLEFT", detailPrice, "BOTTOMLEFT", 0, -12); graphLabel:SetText(L["24-hour price history"])
    local graph = CreateFrame("Frame", nil, detail, "BackdropTemplate")
    graph:SetPoint("TOPLEFT", graphLabel, "BOTTOMLEFT", 0, -4); graph:SetSize(308, 72); graph:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" }); graph:SetBackdropColor(0.10, 0.10, 0.12, 1)
    for i = 1, 24 do
        local bar = graph:CreateTexture(nil, "ARTWORK")
        bar:SetWidth(10); bar:SetPoint("BOTTOMLEFT", 4 + (i - 1) * 12.5, 3); bar:SetColorTexture(0.30, 0.73, 0.42, 0.95); bar:Hide(); bars[i] = bar
    end
    local graphNote = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    graphNote:SetPoint("TOPLEFT", graph, "BOTTOMLEFT", 0, -4); graphNote:SetPoint("RIGHT", -12, 0); graphNote:SetJustifyH("LEFT")
    local alertInput = CreateFrame("EditBox", nil, detail, "InputBoxTemplate")
    alertInput:SetSize(105, 22); alertInput:SetPoint("TOPLEFT", graphNote, "BOTTOMLEFT", 0, -12); alertInput:SetAutoFocus(false); alertInput:SetTextInsets(7, 7, 0, 0)
    local alertStatus = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    alertStatus:SetPoint("TOPLEFT", alertInput, "BOTTOMLEFT", 0, -5); alertStatus:SetPoint("RIGHT", -12, 0); alertStatus:SetJustifyH("LEFT")
    local wish = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
    wish:SetSize(125, 22); wish:SetPoint("BOTTOMLEFT", 14, 14)
    local clear = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
    clear:SetSize(78, 22); clear:SetPoint("BOTTOMRIGHT", -14, 14); clear:SetText(L["Clear alert"])

    local function drawGraph(id)
        local now, buckets, low, high = time(), {}, nil, nil
        for _, point in ipairs(ns.Telemetry.GetPriceHistory(id)) do
            if type(point.at) == "number" and type(point.money) == "number" and now - point.at <= 86400 then
                buckets[math.max(1, math.min(24, 24 - math.floor((now - point.at) / 3600)))] = point.money
            end
        end
        for _, price in pairs(buckets) do low = not low and price or math.min(low, price); high = not high and price or math.max(high, price) end
        for i, bar in ipairs(bars) do
            local price = buckets[i]
            if price and low then bar:SetHeight(high == low and 34 or 6 + math.floor((price - low) * 56 / (high - low))); bar:Show() else bar:Hide() end
        end
        graphNote:SetText(low and string.format(L["24h range: %s – %s"], money(low), money(high)) or L["No 24-hour history yet. It builds from scans."])
    end
    local function showDetail(id)
        selected = id
        local row, alert = ns.Telemetry.GetMarketPrices()[id], ns.Telemetry.GetPriceAlert(id)
        detailName:SetText(itemName(id))
        detailPrice:SetText(row and string.format(L["Current price: %s · observed %s ago"], money(row.money), age(time() - row.at)) or L["No current price observation"])
        alertInput:SetText(alert and money(alert.threshold) or "")
        alertStatus:SetText(alert and (alert.direction == "below" and L["Alert when price is at or below this value"] or L["Alert when price is at or above this value"]) or L["Enter a price, then choose an alert direction."])
        wish:SetText(ns.Telemetry.IsWishlisted(id) and L["Remove from wishlist"] or L["Add to wishlist"])
        drawGraph(id); detail:Show(); detail:Raise()
    end
    local function addAlert(direction)
        local threshold = selected and parseMoney(alertInput:GetText() or "")
        if not threshold or threshold < 1 then alertStatus:SetText(L["Enter a price such as 12g 50s."]); return end
        ns.Telemetry.SetPriceAlert(selected, threshold, direction); showDetail(selected)
    end
    for i, spec in ipairs({ { "below", L["Alert ≤"] }, { "above", L["Alert ≥"] } }) do
        local button = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
        button:SetSize(82, 22); button:SetPoint("LEFT", alertInput, "RIGHT", 8 + (i - 1) * 86, 0); button:SetText(spec[2]); button:SetScript("OnClick", function() addAlert(spec[1]) end)
    end
    clear:SetScript("OnClick", function() if selected then ns.Telemetry.ClearPriceAlert(selected); showDetail(selected) end end)
    wish:SetScript("OnClick", function() if selected then ns.Telemetry.ToggleWishlist(selected); showDetail(selected) end end)

    local function rowAt(index)
        if rows[index] then return rows[index] end
        local row = CreateFrame("Button", nil, content, "BackdropTemplate")
        row:SetHeight(30); row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(24, 24); row.icon:SetPoint("LEFT", 4, 0)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 7, 0); row.label:SetPoint("RIGHT", -8, 0); row.label:SetJustifyH("LEFT")
        rows[index] = row; return row
    end
    local function refresh()
        local now, entries = time(), {}
        ns.Telemetry.CaptureVisibleAuctionPrices()
        hint:SetText(page == "market" and L["Click an item for alerts, wishlist controls and a 24-hour price chart. Hover for item details."] or L["Your auction records"])
        if page == "market" then
            for id, price in pairs(ns.Telemetry.GetMarketPrices()) do
                local name = itemName(id)
                if query == "" or name:lower():find(query:lower(), 1, true) then entries[#entries + 1] = { id = id, name = name, price = price } end
            end
            table.sort(entries, function(a, b) return a.price.money > b.price.money end)
        else
            local store, character = _G.PandaQuestOwnAuctions
            if store and Core.Telemetry and Core.Telemetry.GetCharacterIdentity then
                character = store.characters and store.characters[Core.Telemetry.GetCharacterIdentity()]
            end
            if page == "listings" then
                hint:SetText(L["Your active listings · click an item for its market tools"])
                for _, listing in ipairs((character and character.snapshot and character.snapshot.listings) or {}) do
                    entries[#entries + 1] = { id = listing.itemId, name = itemName(listing.itemId), price = {
                        money = listing.buyout, at = character.snapshot.observedAt or now, source = L["listing"], expiresAt = listing.expiresAt,
                    } }
                end
            else
                hint:SetText(L["Completed sales read from your mailbox"])
                for _, sale in ipairs((character and character.sales) or {}) do
                    entries[#entries + 1] = { name = sale.itemName, price = {
                        money = sale.net, at = sale.observedAt or now, source = L["sold"], quantity = sale.quantity,
                    } }
                end
            end
        end
        for _, row in ipairs(rows) do row:Hide() end
        if #entries == 0 then empty:SetText(page == "market" and L["No price observations. Open the auction house and run a scan."] or L["No records available."]); content:SetHeight(32); return end
        empty:SetText("")
        for index = 1, math.min(#entries, 250) do
            local entry, row = entries[index], rowAt(index)
            local change = "—"
            if entry.price.previous and entry.price.previous > 0 then
                local pct = math.floor((entry.price.money - entry.price.previous) * 100 / entry.price.previous + 0.5)
                change = pct < 0 and string.format(L["|cff52d273↓%d%% buy|r"], -pct) or pct > 0 and string.format(L["|cffffc050↑%d%% sell|r"], pct) or L["stable"]
            end
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(index - 1) * 31); row:SetPoint("RIGHT", 0, 0); row:SetWidth(content:GetWidth())
            row.icon:SetTexture(entry.id and itemIcon(entry.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            local suffix = entry.price.expiresAt and string.format(L[" · returns in %s"], age(math.max(0, entry.price.expiresAt - now))) or ""
            row.label:SetText(string.format(L["%s  |cffffd100%s|r  %s  |cff999999%s ago · %s%s|r"], entry.name, money(entry.price.money), change, age(now - entry.price.at), entry.price.source or L["scan"], suffix))
            row:SetBackdropColor(entry.id and ns.Telemetry.IsWishlisted(entry.id) and 0.13 or 0.07, entry.id and ns.Telemetry.IsWishlisted(entry.id) and 0.12 or 0.07, 0.08, 0.8)
            if entry.id then
                row:SetScript("OnClick", function() showDetail(entry.id) end); tooltip(row, entry.id)
            else
                row:SetScript("OnClick", nil); row:SetScript("OnEnter", nil); row:SetScript("OnLeave", nil)
            end
            row:Show()
        end
        content:SetHeight(math.min(#entries, 250) * 31)
        if selected and detail:IsShown() then showDetail(selected) end
    end
    for i, spec in ipairs({ { "market", L["Market"] }, { "listings", L["Listings"] }, { "sales", L["Sold"] } }) do
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(105, 24); button:SetPoint("TOPLEFT", 16 + (i - 1) * 110, -62); button:SetText(spec[2])
        button:SetScript("OnClick", function() page = spec[1]; detail:Hide(); selected = nil; refresh() end)
    end
    search:SetScript("OnTextChanged", function(self) query = self:GetText() or ""; refresh() end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    panel:SetScript("OnShow", function() content:SetWidth(math.max(1, scroll:GetWidth())); refresh() end)
    return panel
end
Core.Window.RegisterTab("auction", "Auction", build)
