-- PandaQuest window: a local market dashboard.  Price rows are observations
-- from the player's scans; PandaBase/Sync may populate the same cache later.
local _, ns = ...
local Core = ns.Core
if not (Core and Core.Window and Core.Window.RegisterTab) then return end

local function money(value)
    return Core.FormatMoneyCoins and Core.FormatMoneyCoins(value or 0) or tostring(value or 0)
end

local function age(seconds)
    if seconds <= 0 then return "now" end
    if seconds < 3600 then return math.floor(seconds / 60) .. " min" end
    if seconds < 86400 then return math.floor(seconds / 3600) .. " h" end
    return math.floor(seconds / 86400) .. " d"
end

local function itemName(id)
    return (Core.DB and Core.DB.GetItemName and Core.DB.GetItemName(id))
        or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
        or (GetItemInfo and GetItemInfo(id)) or ("Item #" .. id)
end

local function build(panel)
    local page, query = "market", ""
    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -14)
    heading:SetText("Auction")
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
    hint:SetPoint("RIGHT", -16, 0)
    hint:SetJustifyH("LEFT")

    local search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    search:SetSize(250, 22)
    search:SetPoint("TOPRIGHT", -18, -17)
    search:SetAutoFocus(false)
    search:SetTextInsets(7, 7, 0, 0)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -92)
    scroll:SetPoint("BOTTOMRIGHT", -35, 14)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT")
    text:SetPoint("RIGHT")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")

    local function refresh()
        local lines, now = {}, time()
        if page == "market" then
            local rows = {}
            for id, row in pairs(ns.Telemetry.GetMarketPrices()) do
                local name = itemName(id)
                if query == "" or name:lower():find(query:lower(), 1, true) then
                    rows[#rows + 1] = { id = id, name = name, row = row }
                end
            end
            table.sort(rows, function(a, b) return a.row.money > b.row.money end)
            hint:SetText("Local and synced price estimates · arrow shows the change since the previous observation")
            for i = 1, math.min(#rows, 250) do
                local row = rows[i]
                local change = "—"
                if row.row.previous and row.row.previous > 0 then
                    local pct = math.floor((row.row.money - row.row.previous) * 100 / row.row.previous + 0.5)
                    change = pct < 0 and ("|cff52d273↓ " .. -pct .. "% · buy signal|r")
                        or pct > 0 and ("|cffffc050↑ " .. pct .. "% · sell signal|r") or "→ stable"
                end
                lines[#lines + 1] = string.format("%s  |cffffd100%s|r  %s  |cff999999%s sitten · %s|r",
                    row.name, money(row.row.money), change, age(now - row.row.at), row.row.source or "scan")
            end
            if #rows == 0 then lines[1] = "No price observations. Open the auction house and run a scan." end
        else
            local store = _G.PandaQuestOwnAuctions
            local character
            if store and Core.Telemetry and Core.Telemetry.GetCharacterIdentity then
                local key = Core.Telemetry.GetCharacterIdentity()
                character = store.characters and store.characters[key]
            end
            if page == "listings" then
                hint:SetText("Your active listings · return time is the auction expiry countdown")
                for _, row in ipairs((character and character.snapshot and character.snapshot.listings) or {}) do
                    local left = row.expiresAt and age(math.max(0, row.expiresAt - now)) or "ei saatavilla"
                    lines[#lines + 1] = string.format("%s ×%d  |cffffd100%s|r  |cff999999palautuu %s|r",
                        itemName(row.itemId), row.quantity, money(row.buyout), left)
                end
                if #lines == 0 then lines[1] = "No active auction listings." end
            else
                hint:SetText("Completed sales read from your mailbox")
                for _, row in ipairs((character and character.sales) or {}) do
                    lines[#lines + 1] = string.format("%s ×%d  |cffffd100%s netto|r  |cff999999%s sitten|r",
                        row.itemName, row.quantity, money(row.net), age(now - row.observedAt))
                end
                if #lines == 0 then lines[1] = "No completed mailbox sales recorded." end
            end
        end
        text:SetText(table.concat(lines, "\n"))
        content:SetHeight(math.max(1, text:GetStringHeight()))
        scroll:SetVerticalScroll(0)
    end
    for i, spec in ipairs({ { "market", "Market" }, { "listings", "Listings" }, { "sales", "Sold" } }) do
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(105, 24); b:SetPoint("TOPLEFT", 16 + (i - 1) * 110, -62); b:SetText(spec[2])
        b:SetScript("OnClick", function() page = spec[1]; refresh() end)
    end
    search:SetScript("OnTextChanged", function(self) query = self:GetText() or ""; refresh() end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    panel:SetScript("OnShow", refresh)
    return panel
end

Core.Window.RegisterTab("auction", "Huutokauppa", build)
