local _, ns = ...

local finnish = {
    ["Item price lookup"] = "Esineen hintahaku",
    ["Enter an item name, ID, or chat link."] = "Anna esineen nimi, tunniste tai chat-linkki.",
    ["Auctionator prices queued until logout or reload: %d"] =
        "Auctionator-hintoja odottaa uloskirjautumista tai käyttöliittymän uudelleenlatausta: %d",
    ["Scan and share"] = "Hae ja jaa hinnat",
    ["All missing-price targets were checked recently. Try again later."] =
        "Kaikki puuttuvien hintojen kohteet tarkistettiin hiljattain. Yritä myöhemmin uudelleen.",
    ["Find missing prices"] = "Etsi puuttuvat hinnat",
    ["Missing prices: %d/%d checked · %d found · %d without buyout · %d skipped"] =
        "Puuttuvat hinnat: %d/%d tarkistettu · %d löytyi · %d ilman ostohintaa · %d ohitettu",
    ["Scan again"] = "Hae uudelleen",
    ["PandaQuest auction prices"] = "PandaQuestin huutokauppahinnat",
    ["Waiting for auction results…"] = "Odotetaan huutokaupan tuloksia…",
    ["Find listed buyout prices and share them by realm and faction through Sync."] =
        "Hae myynnissä olevien esineiden osta heti -hinnat ja jaa ne palvelimen ja ryhmittymän mukaan Syncillä.",
    ["PQ auction prices queued until logout or reload: %d"] =
        "PQ-huutokauppahintoja odottaa uloskirjautumista tai uudelleenlatausta: %d",
    ["Share completed Auctionator scans"] = "Jaa valmistuneet Auctionator-skannaukset",
    ["%d%% · %d prices queued for Sync"] = "%d%% · %d hintaa odottaa synkronointia",
    ["About %d%% · %d prices queued for Sync"] = "Noin %d%% · %d hintaa odottaa synkronointia",
    ["Another auction search started. Scan again to begin a new list."] =
        "Toinen huutokauppahaku alkoi. Aloita uusi lista skannaamalla uudelleen.",
    ["Batch %d · %d prices queued · Total unknown"] = "Erä %d · %d hintaa jonossa · Kokonaismäärä ei tiedossa",
    ["Enable the Telemetry module to share prices through Sync."] =
        "Ota telemetriamoduuli käyttöön, jotta voit jakaa hintoja Syncillä.",
    ["Record my auctions privately"] = "Tallenna omat huutokauppani yksityisesti",
    ["Reload or log out to save this scan before continuing."] =
        "Tallenna tämä skannaus lataamalla käyttöliittymä uudelleen tai kirjautumalla ulos ennen jatkamista.",
    ["Share your own listings and completed sale invoices privately with your PandaBase account through Sync."] =
        "Jaa omat myynti-ilmoituksesi ja toteutuneiden myyntien kuitit yksityisesti PandaBase-tilillesi Syncillä.",
    ["Stop scan"] = "Lopeta skannaus",
    ["The auction house is busy. Try again in a moment."] = "Huutokauppa on varattu. Yritä hetken kuluttua uudelleen.",
    ["The auction request failed. Try scanning again."] = "Huutokauppahaku epäonnistui. Yritä skannata uudelleen.",
    ["The auction request timed out. Try scanning again."] = "Huutokauppahaku aikakatkaistiin. Yritä skannata uudelleen.",
    ["Share item prices by realm and faction through Sync after logout or reload."] =
        "Jaa esinehinnat palvelimen ja ryhmittymän mukaan Syncillä uloskirjautumisen tai uudelleenlatauksen jälkeen.",
}

-- Follow PandaQuest's language setting, including language changes made without a reload.
-- Auction UI intentionally uses one language on every client.  Price terms and
-- buy/sell signals stay consistent when screenshots or scan results are shared.
ns.L = setmetatable({}, { __index = function(_, key) return key end })
