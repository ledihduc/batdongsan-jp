# P04 Execution Report — Flutter Data Layer + Vector Tiles POC

**Date:** 2026-06-21
**Phase:** 04 — Flutter data layer + `vector_map_tiles 8.0.0` POC
**Status:** DONE_WITH_CONCERNS

---

## Files Created / Modified

| File | Action | Lines |
|------|--------|-------|
| `pubspec.yaml` | Modified — added 3 deps | +3 |
| `lib/core/config/env.dart` | Created | 44 |
| `lib/data/models/planning_parcel_model.dart` | Created | 60 |
| `lib/data/models/planning_district_model.dart` | Created | 26 |
| `lib/data/models/planning_layer_model.dart` | Created | 44 |
| `lib/data/models/planning_search_hit_model.dart` | Created | 38 |
| `lib/data/models/planning_report_model.dart` | Created | 34 |
| `lib/data/services/planning_service.dart` | Created | 187 |
| `lib/features/planning/planning_map_poc_screen.dart` | Created | 143 |
| `lib/main.dart` | Modified — added import + route | +4 |

---

## `flutter pub get` Result

PASS. Dependencies resolved:
- `vector_map_tiles 8.0.0` locked
- `vector_tile_renderer 5.2.1` (transitive → promoted to direct)
- `dio 5.9.2` (latest compatible with ^5.7.0)
- `cached_network_image 3.4.1`

Note: `vector_tile_renderer ^5.0.0` added as direct dependency because `planning_map_poc_screen.dart`
imports `ThemeReader` and `Theme` from it directly (required to resolve name collision with Flutter's
`material.Theme` widget).

---

## `flutter analyze --no-fatal-infos` Result

**Errors in new planning files: 0**
**Warnings in new planning files: 0**
**Infos in new planning files: 0**

Pre-existing issues (not in scope): 76 (`info` level + 3 pre-existing `warning` in `post_house_screen.dart`).
None are in files touched by this phase.

---

## `vector_map_tiles 8.0.0` API Observations — Deviations from Plan Snippet

### Critical deviations

1. **`Theme` class is from `vector_tile_renderer`, not from `vector_map_tiles`.**
   Plan snippet used `Theme(layers: [LayerType.fill(...), LayerType.line(...)])` —
   this API does NOT exist. The correct approach is:
   ```dart
   import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
   vtr.ThemeReader().read(maplibreStyleJson)
   ```
   `ThemeReader.read(Map<String, dynamic>)` accepts a MapLibre GL style JSON `layers` array.

2. **Name collision: `flutter/material.dart` also exports `Theme`.**
   Fixed by importing `vector_tile_renderer` with prefix `vtr` and explicit `show ThemeReader, Theme`.

3. **`TileProviders` takes positional `Map<String, VectorTileProvider>`, not named param.**
   Plan had `TileProviders({'key': provider})` — this is correct, but it's a positional arg:
   `TileProviders(tileProviderBySource)` where source is a regular `Map` ctor positional.

4. **`VectorTileLayer.sprites` is optional (nullable `SpriteStyle?`)**. Plan implied it was required.
   Confirmed: no sprites needed for minimal fill+line theme.

5. **Theme JSON format:** The `source` field in each layer must match the key in the `TileProviders`
   map exactly. `source-layer` maps to the MVT layer name published by Martin.

### Minimal working theme pattern
```dart
ThemeReader().read({
  'id': 'my-theme',
  'layers': [
    {'id': 'l-fill', 'type': 'fill', 'source': 'key-in-tileproviders',
     'source-layer': 'martin-layer-name', 'paint': {'fill-color': 'rgba(...)'}},
    {'id': 'l-line', 'type': 'line', 'source': 'key-in-tileproviders',
     'source-layer': 'martin-layer-name', 'paint': {'line-color': '#...', 'line-width': 1.5}},
  ],
})
```

---

## Implementation Notes

### `PlanningService`
- Dio instance built via static `_buildDio()`, not singleton — caller may create multiple instances
  or wrap in Provider if needed (deferred to P05).
- Auth token injected via `InterceptorsWrapper.onRequest` calling `SessionService.instance.getToken()`
  (async, matches SessionService's `Future<String?>` API).
- `User-Agent: ancu365-flutter/1.0` header set in `BaseOptions.headers` (applied to all requests).
- `PlanningApiException` exposes `isRateLimited` bool for 429 detection.
- `CancelToken` support on `getParcelByPoint` and `search` (AC-17 race condition guard).

### `Env` config
- Platform-aware `get` properties (not `const`) since `kIsWeb` and `defaultTargetPlatform` require runtime eval.
- `--dart-define=API_BASE_URL=https://...` overrides at build time.

### POC screen
- `_vectorTheme` and `_tileProviders` built in `initState` (not `build`) to avoid rebuilds.
- OSM base layer + vector overlay + legal disclaimer footer (AC-09).
- No tap handler implemented — P05 will add feature tap → parcel detail lookup.

---

## Deferred (as instructed)

- Device/emulator render verification — requires live Martin server
- `flutter build apk --analyze-size` — deferred to user device with Docker stack
- iOS simulator test
- Memory profiling (DevTools)
- Backend live calls / E2E

---

## Open Questions

1. **Martin `source-layer` name:** POC uses `'parcels'` as the MVT layer name published by Martin
   for the `planning.parcels` source. If the actual Martin config publishes under a different name
   (e.g., `'planning_parcels'`), `_sourceLayer` in `planning_map_poc_screen.dart` must be updated.
   Verify with: `curl http://localhost:3001/planning.parcels` to check the layer catalog.

2. **`PlanningService` singleton vs per-widget:** Currently constructed via `PlanningService()`.
   P05 should decide: Provider singleton (shared Dio instance + token cache) vs per-screen instance.
   Recommendation: singleton via `Provider` to avoid Dio interceptor duplication.

3. **`adminRiskyListings` endpoint path:** Used `/api/planning/admin/risky-listings` — confirm
   this matches P03 backend route exactly.

---

## Go / No-Go Preliminary Verdict

**Preliminary: GO for P05**, subject to:
- User verifying render on device with Martin running (visual confirm)
- Confirming `source-layer` name matches actual Martin output

Code compiles clean. Architecture is correct. All 7 service methods implemented.
`ThemeReader` approach is the verified correct API for `vector_map_tiles 8.0.0`.
