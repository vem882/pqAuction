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
local function itemCategory(id)
    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    if getInfo then
        local _, _, _, _, _, class = getInfo(id)
        if type(class) == "string" and class ~= "" then return class end
    end
    return L["Other"]
end
local idsByName
local function itemIdByName(name)
    if not idsByName and Core.DB and Core.DB.IterateItemIDs then
        idsByName = {}
        for id in Core.DB.IterateItemIDs() do
            local known = Core.DB.GetItemName(id)
            if known and not idsByName[known] then idsByName[known] = id end
        end
    end
    return idsByName and idsByName[name] or nil
end
local function itemRarity(id)
    local quality
    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    if getInfo then
        local _, _, value = getInfo(id)
        quality = tonumber(value)
    end
    local color = quality ~= nil and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then return color.r or 1, color.g or 1, color.b or 1 end
    -- An uncached item does not have a reliable quality yet.  Keep its name readable
    -- rather than guessing a rarity from the price or the item's database record.
    return 0.93, 0.93, 0.93
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
    local page, query, selected, category, sortKey, rows, bars, categoryButtons = "market", "", nil, L["All items"], "price", {}, {}, {}
    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -14); heading:SetText(L["Auction"])
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5); hint:SetPoint("RIGHT", -16, 0); hint:SetJustifyH("LEFT")
    local search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    -- This is a real edit box, not a decorative search field.  Centre it so
    -- it is easy to discover, and explicitly accept mouse focus because some
    -- UI skins disable the template's default click behaviour.
    search:SetSize(330, 22); search:SetPoint("TOP", panel, "TOP", 0, -17)
    search:SetAutoFocus(false); search:SetTextInsets(7, 7, 0, 0); search:EnableMouse(true)
    search:HookScript("OnMouseDown", function(self) self:SetFocus() end)
    local categoryPanel = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    categoryPanel:SetPoint("TOPLEFT", 16, -92); categoryPanel:SetPoint("BOTTOMLEFT", 16, 14); categoryPanel:SetWidth(154)
    categoryPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    categoryPanel:SetBackdropColor(0.05, 0.05, 0.06, 0.85); categoryPanel:SetBackdropBorderColor(0.35, 0.28, 0.12, 1)
    local categoryTitle = categoryPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    categoryTitle:SetPoint("TOPLEFT", 12, -10); categoryTitle:SetText(L["Categories"])
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 178, -124); scroll:SetPoint("BOTTOMRIGHT", -14, 14)
    local content = CreateFrame("Frame", nil, scroll); content:SetSize(1, 1); scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(math.max(1, width)) end)
    local empty = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    empty:SetPoint("TOPLEFT"); empty:SetPoint("RIGHT"); empty:SetJustifyH("LEFT")
    local headers = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headers:SetPoint("TOPLEFT", 182, -100); headers:SetText(L["Item"])
    local priceHeader = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    priceHeader:SetSize(88, 20); priceHeader:SetPoint("TOPRIGHT", -18, -98); priceHeader:SetText(L["Price"])
    local changeHeader = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    changeHeader:SetSize(108, 20); changeHeader:SetPoint("RIGHT", priceHeader, "LEFT", -4, 0); changeHeader:SetText(L["Signal"])

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
    local detailInsight = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailInsight:SetPoint("TOPLEFT", detailPrice, "BOTTOMLEFT", 0, -4); detailInsight:SetPoint("RIGHT", -14, 0); detailInsight:SetJustifyH("LEFT")
    local graphLabel = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    graphLabel:SetPoint("TOPLEFT", detailInsight, "BOTTOMLEFT", 0, -8); graphLabel:SetText(L["24-hour price history"])
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
    local function showDetail(entry)
        local id, context = type(entry) == "table" and entry.id or entry, type(entry) == "table" and entry.price or nil
        if not id then return end
        selected = { id = id, price = context }
        local row, alert = ns.Telemetry.GetMarketPrices()[id], ns.Telemetry.GetPriceAlert(id)
        detailName:SetText(itemName(id))
        if context then
            local expires = context.expiresAt and string.format(L[" · returns in %s"], age(math.max(0, context.expiresAt - time()))) or ""
            local label = context.source == L["listing"] and L["Listing price"] or context.source == L["sold"] and L["Sold for"] or L["Recorded price"]
            detailPrice:SetText(string.format(L["%s: %s · observed %s ago%s"], label, money(context.money), age(time() - context.at), expires))
        else
            detailPrice:SetText(row and string.format(L["Current price: %s · observed %s ago"], money(row.money), age(time() - row.at)) or L["No current price observation"])
        end
        local insight = ns.Telemetry.GetMarketInsight(id)
        if not insight then
            detailInsight:SetText(L["No market signal yet. Run a scan to collect a price."])
        elseif insight.freshness == "stale" then
            detailInsight:SetText(string.format(L["Stale · last scan %s ago · run a new scan before trading"], age(insight.age)))
        elseif insight.samples < 3 then
            detailInsight:SetText(string.format(L["%s · %d 24-hour samples · more scans needed"], insight.freshness == "fresh" and L["Fresh"] or L["Aging"], insight.samples))
        else
            local signal = insight.signal == "buy" and L["Buy signal"] or (insight.signal == "sell" and L["Sell signal"] or L["Fair price"])
            detailInsight:SetText(string.format(L["%s · %d%% vs 24h median %s · %d samples"], signal, insight.change, money(insight.median), insight.samples))
        end
        alertInput:SetText(alert and money(alert.threshold) or "")
        alertStatus:SetText(alert and (alert.direction == "below" and L["Alert when price is at or below this value"] or L["Alert when price is at or above this value"]) or L["Enter a price, then choose an alert direction."])
        wish:SetText(ns.Telemetry.IsWishlisted(id) and L["Remove from wishlist"] or L["Add to wishlist"])
        drawGraph(id); detail:Show(); detail:Raise()
    end
    local function addAlert(direction)
        local threshold = selected and parseMoney(alertInput:GetText() or "")
        if not threshold or threshold < 1 then alertStatus:SetText(L["Enter a price such as 12g 50s."]); return end
        ns.Telemetry.SetPriceAlert(selected.id, threshold, direction); showDetail(selected)
    end
    for i, spec in ipairs({ { "below", L["Alert ≤"] }, { "above", L["Alert ≥"] } }) do
        local button = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
        button:SetSize(82, 22); button:SetPoint("LEFT", alertInput, "RIGHT", 8 + (i - 1) * 86, 0); button:SetText(spec[2]); button:SetScript("OnClick", function() addAlert(spec[1]) end)
    end
    clear:SetScript("OnClick", function() if selected then ns.Telemetry.ClearPriceAlert(selected.id); showDetail(selected) end end)
    wish:SetScript("OnClick", function() if selected then ns.Telemetry.ToggleWishlist(selected.id); showDetail(selected) end end)

    local function rowAt(index)
        if rows[index] then return rows[index] end
        local row = CreateFrame("Button", nil, content, "BackdropTemplate")
        row:SetHeight(42); row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(32, 32); row.icon:SetPoint("LEFT", 5, 0)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -3); row.name:SetPoint("RIGHT", -154, 0)
        row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
        row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.meta:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 3); row.meta:SetPoint("RIGHT", -154, 0)
        row.meta:SetJustifyH("LEFT"); row.meta:SetTextColor(0.62, 0.62, 0.66)
        row.price = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.price:SetPoint("TOPRIGHT", -7, -3); row.price:SetJustifyH("RIGHT"); row.price:SetTextColor(1, 0.82, 0)
        row.change = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.change:SetPoint("BOTTOMRIGHT", -7, 3); row.change:SetJustifyH("RIGHT")
        row:SetScript("OnEnter", function(self) self:SetBackdropColor(0.16, 0.14, 0.08, 0.96) end)
        row:SetScript("OnLeave", function(self)
            local wished = self.itemID and ns.Telemetry.IsWishlisted(self.itemID)
            self:SetBackdropColor(wished and 0.13 or 0.07, wished and 0.12 or 0.07, 0.08, 0.8)
        end)
        rows[index] = row; return row
    end
    local function refresh()
        local now, entries, categorySet = time(), {}, {}
        ns.Telemetry.CaptureVisibleAuctionPrices()
        hint:SetText(page == "market" and L["Click an item for alerts, wishlist controls and a 24-hour price chart. Hover for item details."] or L["Your auction records"])
        if page == "market" then
            for id, price in pairs(ns.Telemetry.GetMarketPrices()) do
                local name = itemName(id)
                local itemClass = itemCategory(id)
                categorySet[itemClass] = true
                if (query == "" or name:lower():find(query:lower(), 1, true))
                    and (category == L["All items"] or category == itemClass or (category == L["Wishlist"] and ns.Telemetry.IsWishlisted(id))) then
                    entries[#entries + 1] = { id = id, name = name, category = itemClass, price = price }
                end
            end
            table.sort(entries, function(a, b)
                if sortKey == "name" then return a.name < b.name end
                if sortKey == "change" then return (a.price.previous or a.price.money) > (b.price.previous or b.price.money) end
                return a.price.money > b.price.money
            end)
        else
            local store, character = _G.PandaQuestOwnAuctions
            if store and Core.Telemetry and Core.Telemetry.GetCharacterIdentity then
                character = store.characters and store.characters[Core.Telemetry.GetCharacterIdentity()]
            end
            if page == "listings" then
                hint:SetText(L["Your active listings · click an item for its market tools"])
                for _, listing in ipairs((character and character.snapshot and character.snapshot.listings) or {}) do
                    local name = itemName(listing.itemId)
                    if query == "" or name:lower():find(query:lower(), 1, true) then entries[#entries + 1] = { id = listing.itemId, name = name, price = {
                        money = listing.buyout, at = character.snapshot.observedAt or now, source = L["listing"], expiresAt = listing.expiresAt,
                    } } end
                end
            else
                hint:SetText(L["Completed sales read from your mailbox"])
                for _, sale in ipairs((character and character.sales) or {}) do
                    if query == "" or sale.itemName:lower():find(query:lower(), 1, true) then entries[#entries + 1] = { id = sale.itemId or itemIdByName(sale.itemName), name = sale.itemName, price = {
                        money = sale.net, at = sale.observedAt or now, source = L["sold"], quantity = sale.quantity,
                    } } end
                end
            end
        end
        local categories = { L["All items"], L["Wishlist"] }
        local known = { [L["All items"]] = true, [L["Wishlist"]] = true }
        for itemClass in pairs(categorySet) do
            if not known[itemClass] then known[itemClass] = true; categories[#categories + 1] = itemClass end
        end
        table.sort(categories, function(a, b) if a == L["All items"] then return true elseif b == L["All items"] then return false elseif a == L["Wishlist"] then return true elseif b == L["Wishlist"] then return false end return a < b end)
        for i, name in ipairs(categories) do
            local button = categoryButtons[i]
            if not button then
                button = CreateFrame("Button", nil, categoryPanel, "UIPanelButtonTemplate"); button:SetSize(134, 22); button:SetPoint("TOPLEFT", 10, -30 - (i - 1) * 25); categoryButtons[i] = button
            end
            button:SetText(name); button:SetScript("OnClick", function() category = name; refresh() end); button:Show()
        end
        for i = #categories + 1, #categoryButtons do categoryButtons[i]:Hide() end
        categoryPanel:SetShown(page == "market")
        headers:SetShown(page == "market"); priceHeader:SetShown(page == "market"); changeHeader:SetShown(page == "market")
        scroll:ClearAllPoints()
        if page == "market" then
            scroll:SetPoint("TOPLEFT", 178, -124)
        else
            scroll:SetPoint("TOPLEFT", 16, -92)
        end
        -- The item list owns the available width.  The item detail is an
        -- overlay opened only after a click, so reserving an empty sidebar
        -- makes the default market view needlessly narrow.
        scroll:SetPoint("BOTTOMRIGHT", -14, 14)
        for _, row in ipairs(rows) do row:Hide() end
        if #entries == 0 then empty:SetText(page == "market" and L["No price observations. Open the auction house and run a scan."] or L["No records available."]); content:SetHeight(32); return end
        empty:SetText("")
        for index = 1, math.min(#entries, 250) do
            local entry, row = entries[index], rowAt(index)
            local change, cr, cg, cb = L["No market signal"], 0.62, 0.62, 0.66
            local insight = entry.id and ns.Telemetry.GetMarketInsight(entry.id, now)
            if insight and insight.freshness == "stale" then
                change, cr, cg, cb = L["Stale · scan"], 0.95, 0.55, 0.25
            elseif insight and insight.samples >= 3 then
                if insight.signal == "buy" then
                    change, cr, cg, cb = string.format(L["Buy · %d%% below"], -insight.change), 0.32, 0.82, 0.45
                elseif insight.signal == "sell" then
                    change, cr, cg, cb = string.format(L["Sell · %d%% above"], insight.change), 1, 0.75, 0.25
                else
                    change, cr, cg, cb = L["Fair price"], 0.75, 0.75, 0.75
                end
            elseif entry.price.previous and entry.price.previous > 0 then
                local pct = math.floor((entry.price.money - entry.price.previous) * 100 / entry.price.previous + 0.5)
                if pct < 0 then
                    change, cr, cg, cb = string.format("↓%d%% lower", -pct), 0.32, 0.82, 0.45
                elseif pct > 0 then
                    change, cr, cg, cb = string.format("↑%d%% higher", pct), 1, 0.75, 0.25
                else
                    change, cr, cg, cb = L["stable"], 0.75, 0.75, 0.75
                end
            end
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(index - 1) * 43); row:SetPoint("RIGHT", 0, 0); row:SetWidth(content:GetWidth())
            row.icon:SetTexture(entry.id and itemIcon(entry.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            local suffix = entry.price.expiresAt and string.format(L[" · returns in %s"], age(math.max(0, entry.price.expiresAt - now))) or ""
            local quantity = entry.price.quantity and entry.price.quantity > 1 and string.format(" · x%d", entry.price.quantity) or ""
            local r, g, b = 0.93, 0.93, 0.93
            if entry.id then r, g, b = itemRarity(entry.id) end
            row.itemID = entry.id
            row.name:SetText(entry.name); row.name:SetTextColor(r, g, b)
            row.meta:SetText(string.format("#%s · %s ago · %s%s", tostring(entry.id or "—"), age(now - entry.price.at), entry.price.source or L["scan"], suffix))
            row.price:SetText(money(entry.price.money) .. quantity)
            row.change:SetText(change); row.change:SetTextColor(cr, cg, cb)
            local wished = entry.id and ns.Telemetry.IsWishlisted(entry.id)
            row:SetBackdropColor(wished and 0.13 or 0.07, wished and 0.12 or 0.07, 0.08, 0.8)
            if entry.id then
                row:SetScript("OnClick", function() showDetail(entry) end); tooltip(row, entry.id)
            else
                row:SetScript("OnClick", nil); row:SetScript("OnEnter", nil); row:SetScript("OnLeave", nil)
            end
            row:Show()
        end
        content:SetHeight(math.min(#entries, 250) * 43)
        if selected and detail:IsShown() then showDetail(selected) end
    end
    for i, spec in ipairs({ { "market", L["Market"] }, { "listings", L["Listings"] }, { "sales", L["Sold"] } }) do
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(105, 24); button:SetPoint("TOPLEFT", 16 + (i - 1) * 110, -62); button:SetText(spec[2])
        button:SetScript("OnClick", function() page = spec[1]; detail:Hide(); selected = nil; refresh() end)
    end
    priceHeader:SetScript("OnClick", function() sortKey = "price"; refresh() end)
    changeHeader:SetScript("OnClick", function() sortKey = "change"; refresh() end)
    search:SetScript("OnTextChanged", function(self) query = self:GetText() or ""; refresh() end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    panel:SetScript("OnShow", function() content:SetWidth(math.max(1, scroll:GetWidth())); refresh() end)
    return panel
end
Core.Window.RegisterTab("auction", "Auction", build)
