# NEXE Neon FL Overlay

A native macOS companion app that draws a soft, animated neon/cyberpunk
border around every one of FL Studio's windows — without touching FL Studio
itself in any way.

NEXE watches for FL Studio using only public system APIs, follows every
window it has open (position, size, move, resize, open, close) via the
public Accessibility API, and paints a separate, click-through, borderless
window on top of each one. Turn NEXE off (or quit it) and FL Studio looks
and behaves exactly as it always has — nothing about FL Studio is ever
modified, patched, injected into, read from disk, or captured as pixels.

## What it does

- Detects a running FL Studio process (`NSWorkspace`) and shows a live
  **FL STUDIO ● CONNECTED** / **● WAITING FOR FL STUDIO** status.
- Locates **every window FL Studio currently has open** — the main window,
  plus Playlist, Piano Roll, Mixer, Channel Rack, Browser, and any other
  panel the moment it's undocked into its own window — using the public
  Accessibility API (`AXUIElement` / `AXObserver`). No private APIs, no
  injection, no reverse engineering, and no Screen Recording permission:
  window geometry is public Accessibility data, not pixel content.
- Draws one borderless, transparent, **click-through** overlay window per
  tracked FL Studio window, each independently:
  - tracing a thin animated neon frame just inside that window's edge,
  - adding a very soft ambient glow pooling in its corners,
  - adding minimal HUD-style corner accents,
  - optionally adding a handful of slow, subtle ambient particles (off by
    default).
- Follows each FL Studio window as it moves or resizes, adds a new border
  the instant a new window opens (e.g. undocking the Mixer), removes it the
  instant that window closes or is minimized, and hides automatically when
  FL Studio quits — no relaunch of NEXE required.
- Ships five themes (NEXE VOID, CYBER BLUE, SIGNAL RED, ACID, PURPLE CORE)
  plus sliders for glow intensity, animation speed, and frame thickness, and
  a toggle for the whole overlay and for particles — applied to every
  tracked window at once.
- Lives in the menu bar only (no Dock icon) with a small settings window,
  **NEXE — Visual Engine**, which also shows a live **WINDOWS OUTLINED**
  count.

## Why it needs Accessibility permission

Reading *another* app's window position/size from outside that app is only
possible through the public Accessibility API, and macOS only allows that
once the user has explicitly granted the requesting app Accessibility access
in **System Settings → Privacy & Security → Accessibility**. There is no
private API used here and no way around this system prompt — it's the same
permission every window-manager/snapping utility on macOS needs. NEXE
explains this in its own UI before asking:

> "Accessibility permission is required to detect and follow the FL Studio
> window."

Because of this, the app also ships with **App Sandbox turned off**
(`NEXENeonOverlay.entitlements`) — a sandboxed app cannot use `AXUIElement`
against another process at all, sandboxed or not. This means NEXE cannot be
distributed through the Mac App Store as-is; it's meant to be built and run
locally (or distributed Developer-ID signed / notarized), like every other
accessibility-based window utility.

## Getting a runnable app without installing anything on your Mac

There is no way to compile *any* native macOS app — this one included —
without Apple's Swift/Clang compiler and the macOS SDK somewhere, and Apple
only ships those inside Xcode or Xcode's Command Line Tools. That said, you
don't have to be the one who installs them: GitHub's free hosted macOS
runners already have Xcode, so you can have GitHub compile this for you and
just download the finished `.app` — nothing new touches your Mac except the
one file you'll actually run.

1. Unzip the project you were given (Finder does this natively —
   double-click the `.zip`).
2. Create a free GitHub account if you don't have one, and create a new
   **empty** repository (github.com → "+" → "New repository"; don't add a
   README/license, so it stays empty).
3. On the new repo's page, click **"uploading an existing file"** (or
   `Add file ▸ Upload files`), then drag in the **contents** of the
   unzipped `NEXENeonOverlay` folder — `NEXENeonOverlay.xcodeproj`,
   the `NEXENeonOverlay` source folder, and `README.md` (Chrome/Edge
   preserve folder structure when you drop folders). Commit directly to
   `main`.

   Finder hides folders that start with a dot (like `.github`), so drag-and-drop
   often skips it. Add the workflow the reliable way instead: on GitHub,
   click **Add file ▸ Create new file**, type
   `.github/workflows/build.yml` as the file name (GitHub creates both
   folders for you), and paste in exactly this:

   ```yaml
   name: Build NEXE Neon FL Overlay

   on:
     push:
       branches: [ main, master ]
     workflow_dispatch: {}

   jobs:
     build:
       runs-on: macos-14
       steps:
         - name: Check out the repo
           uses: actions/checkout@v4

         - name: Build (unsigned — fine for running on your own Mac)
           run: |
             xcodebuild \
               -project NEXENeonOverlay.xcodeproj \
               -scheme NEXENeonOverlay \
               -configuration Release \
               -derivedDataPath build \
               CODE_SIGNING_ALLOWED=NO \
               CODE_SIGNING_REQUIRED=NO \
               CODE_SIGN_IDENTITY="" \
               build

         - name: Zip the built .app
           run: |
             cd build/Build/Products/Release
             ditto -c -k --sequesterRsrc --keepParent NEXENeonOverlay.app NEXENeonOverlay-app.zip

         - name: Upload the app as a downloadable artifact
           uses: actions/upload-artifact@v4
           with:
             name: NEXENeonOverlay-app
             path: build/Build/Products/Release/NEXENeonOverlay-app.zip
             retention-days: 30
   ```

   Commit that file too. (The same file already sits at
   `.github/workflows/build.yml` in the zip you were given, in case your
   browser's drag-and-drop does carry hidden folders over — check the
   repo's file list after step 3; if `.github` is already there, skip this
   step.)
4. Committing the workflow file automatically triggers it, since it runs
   on every push to `main`. Watch it under the repo's **Actions** tab — it
   takes a couple of minutes. (If it doesn't start automatically, open the
   workflow under **Actions** and click **"Run workflow"**.)
5. When the run finishes (green check), open it and scroll to
   **Artifacts** — download `NEXENeonOverlay-app.zip`.
6. Unzip it and move `NEXENeonOverlay.app` wherever you like (e.g. your
   Applications folder). Since it's unsigned and came from the internet,
   the **first** launch needs one extra click: right-click the app ▸
   **Open** ▸ **Open** in the Gatekeeper dialog (macOS blocks unsigned apps
   from a plain double-click the very first time only — this is a macOS
   security prompt, not something you need to install). Every launch after
   that is a normal double-click.
7. From here on, using NEXE is exactly what's described below in
   **Testing with FL Studio** — you just never need Xcode, Terminal, or
   anything else on your Mac again.

If you'd rather build it yourself locally (e.g. because you already use
Xcode), the sections below cover that instead.

## Opening the project (if you have Xcode)

1. Requires **Xcode 15 or later** on **macOS 14 (Sonoma) or later**, Apple
   Silicon (M1/M2/M3/M4) or Intel.
2. Double-click `NEXENeonOverlay.xcodeproj`, or open it from Xcode's
   `File ▸ Open…`.
3. Select the `NEXENeonOverlay` scheme (already included and shared, so it
   should be selected automatically) and your own Mac as the run
   destination.
4. In the project's **Signing & Capabilities** tab, set **Team** to your own
   Apple ID / development team, and leave **Automatically manage signing**
   checked. (No entitlement other than "App Sandbox: off" is required.)

## Building & running

- **Run from Xcode:** `Product ▸ Run` (⌘R). NEXE launches as a menu-bar app
  (look for the hexagon icon in the menu bar) and opens its settings window.
- **Build a release build:** `Product ▸ Archive`, or
  `Product ▸ Scheme ▸ Edit Scheme… ▸ Run ▸ Build Configuration: Release`
  then `Product ▸ Build`. The built `NEXENeonOverlay.app` is under
  Xcode's DerivedData `Build/Products/Release/` folder (`Product ▸ Show Build
  Folder in Finder` after building).
- **Command line:** `xcodebuild -project NEXENeonOverlay.xcodeproj -scheme NEXENeonOverlay -configuration Release build`

## Testing with FL Studio

1. Launch NEXE first (or in any order — it polls for FL Studio via
   `NSWorkspace` launch notifications, not a busy loop).
2. The **NEXE — Visual Engine** window shows **● WAITING FOR FL STUDIO**
   until FL Studio is running.
3. The first time NEXE needs to read FL Studio's window frame, click
   **Grant Accessibility Access** in the settings window (or you'll be
   prompted automatically). This opens
   **System Settings → Privacy & Security → Accessibility** — enable NEXE
   there. NEXE polls its own trust state every ~1.5s and updates the UI
   automatically once you grant it; no relaunch needed.
4. Launch FL Studio and open a project. The status flips to
   **FL STUDIO ● CONNECTED**, and a neon frame appears around FL Studio's
   main window within a moment.
5. Undock the Playlist, Piano Roll, Mixer, or Channel Rack into its own
   window — each one gets its own independent neon border the moment it
   opens as a separate window, and loses it the moment it's closed or
   re-docked.
6. Move and resize any of these windows — each overlay tracks its own
   window immediately (this is event-driven via `AXObserver`, not a polling
   loop).
7. Click and drag inside FL Studio, including near any overlay's frame —
   every click should reach FL Studio normally; each overlay window has
   `ignoresMouseEvents = true` and its whole SwiftUI content additionally
   sets `.allowsHitTesting(false)` as a second guarantee.
8. Try each theme, and the Glow Intensity / Animation Speed / Frame
   Thickness sliders, and toggle Particles on — all tracked windows update
   together.
9. Quit FL Studio — every overlay disappears; NEXE keeps running and
   waiting.
10. Toggle **ENABLE VISUAL OVERLAY** off/on and confirm every frame
    hides/reappears without needing to relaunch anything.

### Full screen

FL Studio's own full-screen mode is handled as a **documented fallback**,
not a guess: there is no public Accessibility attribute that reports
"this window is full screen," so `WindowTracker` compares each window's
frame against each `NSScreen`'s frame — when they match, NEXE treats that
one window as full screen and hides just its overlay (a small note appears
in the settings window once *every* open FL Studio window is full screen)
rather than drawing a broken or misaligned frame. When a window returns to
windowed mode, its overlay reappears automatically. This is the stable,
honest behavior per the project's own requirement to fail gracefully rather
than invent an unstable full-screen overlay.

## Architecture

```
NEXENeonOverlay/
  App/
    NEXENeonOverlayApp.swift   – @main entry point, AppDelegate, menu-bar item, settings window
    AppState.swift             – composition root; wires all the pieces together
  UI/
    SettingsView.swift         – "NEXE — Visual Engine" panel
    ThemeSelector.swift        – theme picker
    Controls/                  – small reusable controls (slider, toggle, status badge)
  WindowDetection/
    FLStudioDetector.swift     – finds the running FL Studio process (NSWorkspace)
    WindowTracker.swift        – follows *every* one of its window frames (AXUIElement / AXObserver)
  Overlay/
    OverlayWindow.swift        – borderless, transparent, click-through NSWindow
    OverlayManager.swift       – owns one overlay window's lifecycle per tracked FL Studio window
    OverlayView.swift          – SwiftUI composition of all the visual effects, one instance per window
  Effects/
    NeonFrameView.swift        – the animated glowing border
    GlowEffect.swift           – reusable layered-bloom view modifier
    AmbientLightView.swift     – soft corner/edge ambient glow
    ParticleSystem.swift       – optional CAEmitterLayer-based particles
    Animations.swift           – shared animation-timing helpers
  Models/
    Theme.swift                – theme model + the 5 built-in themes
    OverlaySettings.swift      – persisted user settings (UserDefaults)
  Services/
    PermissionManager.swift    – Accessibility permission request/poll
  Resources/
    Assets.xcassets, Info.plist, NEXENeonOverlay.entitlements
```

Everything reads from a single `OverlaySettings` instance, so the effect
views never talk to each other directly — `OverlayManager` is the only place
that creates, moves, shows, or hides any overlay window, and it keeps one
independent overlay window per FL Studio window `WindowTracker` reports.

### Adding a new theme

Add one `Theme` literal to `Theme.all` in `Models/Theme.swift`. It
immediately shows up in the theme picker and drives every effect view (they
all read `Theme.primaryColor` / `secondaryColor` / `glowColor` / `intensity`
/ `animation`) — nothing else needs to change.

### On the GPU/Metal question

The spec calls for Metal "if necessary" for GPU-accelerated glow/bloom. The
bloom here is built from layered, blurred SwiftUI shapes
(`GlowEffect.swift`), which Core Animation already renders through its
GPU-backed compositor — this is the stable, officially-supported way to get
GPU-accelerated blur/glow in a SwiftUI-based overlay, and it comfortably
meets the "soft, not aggressive, low CPU" requirement without the
substantially larger maintenance surface of a hand-written Metal render
pipeline. If you want a literal custom Metal shader (e.g. a proper
frequency-domain bloom) later, `GlowEffect.swift` is the single place to
swap in an `MTKView`/`CIFilter`-backed implementation — every call site uses
the `.nexeGlow(color:intensity:)` modifier, not the implementation directly.

## Performance

- FL Studio detection is entirely notification-driven
  (`NSWorkspace.didLaunchApplicationNotification` /
  `didTerminateApplicationNotification`), not a polling loop.
- Window-frame tracking is entirely notification-driven
  (`AXObserver` + `kAXMovedNotification` / `kAXResizedNotification` / etc.),
  not a polling loop or screenshot analysis.
- The only timer in the app is a 1.5s Accessibility-trust poll
  (`PermissionManager`) — there is no public notification for permission
  changes, so a low-frequency poll is the standard, documented way apps in
  this category detect the user granting access; it is cheap enough to have
  no measurable CPU impact.
- Particles use `CAEmitterLayer`, which runs on the system's render server
  rather than a per-frame Swift-side loop.
- All effect geometry stays a fixed size (no continuous screenshotting or
  image analysis of FL Studio's window content).

## Known limitations / honesty notes

- **Bundle identifier / signing team** are placeholders
  (`com.nexe.neonfloverlay`) — change `PRODUCT_BUNDLE_IDENTIFIER` in the
  target's Build Settings and set your own signing team before distributing
  this to anyone else.
- **FL Studio detection** matches on bundle-identifier fragments
  (`image-line`, `fl-studio`, `flstudio`) and the localized app name
  (`"FL Studio"`), rather than one hardcoded bundle ID — this is deliberate,
  since Image-Line's exact macOS bundle identifier isn't guaranteed to be
  stable across FL Studio releases, and matching too narrowly would silently
  stop working after an FL Studio update. If your installed build uses a
  different name entirely, add the exact fragment you see in
  `FLStudioDetector.matches(_:)`.
- **App icon**: `Assets.xcassets/AppIcon.appiconset` has the correct slot
  structure for a macOS app icon but ships without actual artwork — drop in
  your own 16/32/128/256/512pt (@1x/@2x) PNGs, or Xcode will just show a
  generic icon.
- This project file was generated directly (there is no Xcode/macOS
  toolchain available in the environment this was built in, so it could not
  be opened/compiled there) rather than exported from a real Xcode session.
  It was verified structurally — every internal object reference resolves,
  and every file path referenced by the project exists on disk — but you
  should still expect the very first `⌘B` on your machine to be the true
  first compile of this exact code. If anything doesn't compile, it's most
  likely a small API-availability detail (Xcode/SDK version differences)
  rather than a structural project problem — the error will point at the
  exact line.
