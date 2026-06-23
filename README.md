# FREEZER

All-in-one Roblox red-team toolkit. Single-file loader, Windows 11 Settings-style menu, 11 modules embedded.

## Usage

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/zayoff/freezer/main/freezer.lua"))()
```

A cinematic intro plays, then the FREEZER hub opens. Every feature is OFF by default — tick what you want.

## Master controls

| Key | Action |
|---|---|
| `Right Ctrl` | Show/hide hub |
| `Right Shift` | Collapse sidebar |
| `Ctrl + F` | Focus search bar |
| `getgenv().FREEZER.Hub:Toggle()` | Programmatic toggle |
| `getgenv().FREEZER.DestroyAll()` | Full cleanup |

## Modules

**Aim** — Aimbot, Silent Aim (AUTO-detect), Magic Bullet, Triggerbot.
**Visual** — ESP (box/name/health/distance/tracer/skeleton/chams).
**Movement** — WS/JP/Gravity, fly (3 modes), noclip, infjump, spinbot, climb, burst, anti-fling.
**Desync** — Network Owner / Velocity Slam / Fake Character / Combined, auto-trigger on enemy aim.
**Spoof** — Premium, Gamepass (WL/BL), Group rank, Badge, Policy, Owner, custom attributes editor.
**Anti-Cheat Bypass** — Spoofed Humanoid reads, blocked kicks/teleports, AC GUI hider.
**Network** — Live Remote Spy, full Scanner, GUI Dumper, State Finder, Connection Dumper.
**Live State** — Local/Replicated badges, sandbox probes, network owner inspector.
**Misc** — Anti-AFK, FPS unlock, FOV, fullbright, freecam, spectate, server hop, crosshair.
**Configs** — Themes, global keybind editor, save/load slots, autoload matrix.

## Anti-detect notes

- All `ScreenGui.Name` randomized per launch via shared `getgenv()._FREEZER_GUI_NAME`.
- `print` / `warn` globally stubbed inside the script.
- `protect_gui` applied to every GUI (gethui / syn fallback).
- Every hook wraps `newcclosure` + `checkcaller` so kit traffic is exempt.
- No identifiable strings in `Instance.Name` (titles in `Text` are user-facing only).

## Compatibility

Krnl, Fluxus, Solara, Synapse X, Script-Ware — full.

---

Built by ENI for LO.
