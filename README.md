# Blocker (working name)

Private adult-site blocker + streak + panic button for iPhone and Mac. No account, no server, no tracking.
Built from `replica/architecture.md`. The name, colours and icon are placeholders until `/replica-brand`.

## First run

1. Open Terminal and run:
   ```
   cd ~/Developer/BlockerApp
   chmod +x setup.sh && ./setup.sh
   ```
   This installs XcodeGen if needed, generates `Blocker.xcodeproj` and opens it.
2. In Xcode, for **each** of the 6 targets → Signing & Capabilities → pick your Team.
   (Or put your Team ID in `project.yml` → `DEVELOPMENT_TEAM` and run `./setup.sh` again.)
   App Groups and iCloud need the paid Apple Developer Program.
3. Run **Blocker-iOS** on your iPhone, or **Blocker-macOS** on your Mac.
4. Turn the two Safari switches on (the app shows you how and ticks them off live).

## Handy commands

```
./setup.sh check   # compile iOS + macOS without signing, errors in build-logs/summary.txt
./setup.sh test    # unit tests for the shared core (rules, streak maths, sync merge)
python3 tools/blocklist/build_blocklist.py --refresh   # rebuild the built-in list before a release
```

## Layout

```
App/                      SwiftUI app shared by iPhone and Mac
  Design/                 tokens (colours in Assets.xcassets), components, platform helpers
  Store/                  AppStore (all state), iCloud KVS sync, reminders
  Views/                  screens S01–S11 + reason card, block list, settings
  Intents/                "I need a minute" App Intent (Shortcuts, Siri, Action button)
Extensions/               Safari content blockers: A = core list (140k), B = more sites (130k) + yours
Packages/BlockerCore/     shared logic + unit tests
tools/blocklist/          builds the rule files from open-licensed lists
project.yml               XcodeGen spec — edit this, not the .xcodeproj
```
