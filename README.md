# PandaQuest Auction

PandaQuest Auction adds price scanning and private auction history to [PandaQuest](https://github.com/vem882/pandaquest). It supports Mists of Pandaria Classic, Classic Era, The Burning Crusade Classic Anniversary and WoW Forever. Available price, quantity and seller observations depend on the game client's auction APIs.

## Install

Install **PandaQuest**, **PandaQuest DB** and **PandaQuest Auction** in the same WoW client. Use matching versions from the [PandaQuest releases](https://github.com/vem882/pandaquest/releases) or the CurseForge app. For manual installation, extract all three addons into the client's `Interface/AddOns` folder so the extension's TOC is at `AddOns/PandaQuestAuction/PandaQuestAuction.toc`. Restart WoW after installing or updating the addons.

PandaQuest Auction requires PandaQuest and is optional for questing. Auctionator, TradeSkillMaster and the separate PandaQuest Sync app are optional.

## In the game

- Open the auction house and click **PQ** to open the scan panel. Run a full scan or choose **Find missing prices** to work through items lacking recent shared observations. The panel shows scan progress and the number of queued prices.
- Use `/pq price <item name, ID, or link>` to see quotes from Auctionator or TradeSkillMaster, if available. Shift-click an item into the command to resolve duplicate names. Add `--share` to queue a quote when quest telemetry is enabled.
- In **PandaQuest → Options → Sync & Privacy**, turn on **Share completed Auctionator scans** to share supported full scans. This choice is separate from quest telemetry.
- Enable **Record my auctions privately** to keep your listings and settled sale receipts. Visit the auction house's Auctions tab and open your mailbox to collect the information available in the client.

A reload or logout saves the observations. [PandaQuest Sync](https://pd.zroot.it/setup) sends them to [PandaBase](https://pd.zroot.it/) if you have set it up. Public price observations and private listings use separate storage. The existing settings and pending data remain in PandaQuest's SavedVariables so upgrades keep them and Sync reads the same files.

## Development

PandaQuest Auction contains the auction UI, native scanner, Auctionator capture, private auction capture and local price commands. `Database/Overrides/AuctionMissing.lua` is generated from PandaBase observations. The [PandaQuest repository](https://github.com/vem882/pandaquest) builds and releases the compatible packages together.

The [CurseForge project text](docs/curseforge-description.md) is ready to paste into the project editor. CurseForge project ID is `1807835`.

## Licence

GPL-3.0. See [LICENSE](LICENSE). World of Warcraft is a trademark of Blizzard Entertainment. PandaQuest Auction is an unofficial fan project.
