# Revision 4 landscape validation

**Historical water-capable R4 evidence.** The user subsequently selected a fixed coast. Water/pond/reclamation checks and artifact identities in this record describe the superseded candidate; see `fixed-coast-validation.md` for the correction and final fixed-coast package. Land/path/scenery functionality remains in scope.

The implementation team used headless Godot, source/data review and local generated-file inspection. The user's restriction on computer use remains in effect: no desktop capture, native/browser automation, visible game/editor windows or tester resumption. Native visual/interactive playtesting and subjective audio quality remain unverified. This request authorizes local delivery only; no Git push or release publication is part of this revision.

## Component evidence

- Root landscape model: **58 headless checks passed** against the imported defaults. Coverage includes atomic brush validation, exact untouched-coast pixels, painted ponds/reclaimed land, collision, path-weight route preference, Regular/Developer costs, prop movement/refunds, rotations, serialization and corrupt data. Legacy custom rooms built over formerly decorative palms migrate without deleting the user's buildings or clearing unrelated trees. A water barrier can remain an invalid draft, but cannot be applied when it disconnects the operating hotel, even in free Developer mode.
- Existing construction transactions: **24 checks passed** against the new landscape-aware model.
- Visual/data component: **306 headless checks passed**. The starter landscape retains **67 editable props** (38 original palms, 24 shrubs, four rocks and one beach flag). Its **214 path cells** form one dry connected component from the entrance. Tests cover dynamic flag position/removal, ponds, land reclamation, path rendering and restoring the original ocean. Asset regeneration was deterministic.
- PM inspected the regenerated base PNG: no palms, scenery objects or promenade remain baked into it. The visual specialist inspected generated artwork and a CPU diagnostic composite; that composite is not a game capture.

## Integrated checks and resolved migration defect

- Routed landscape suite: **33 checks passed**, plus **eight fresh-process resume checks**. Coverage includes continuous thin diagonal strokes, atomic invalid-stroke rejection, erasing/restoring the original promenade, moving/rotating an original palm, removing the beach flag, a real weighted-route change, construction prices and active/pending/draft persistence. The resumed process distinguishes active stone from queued boardwalk, retains a moved palm/removed flag and an incomplete inland-water/tree draft alongside active guests, then applies the queued plan with the correct cash.
- Existing R3 construction suite passed **46 checks plus six relaunch checks**; management passed **73 checks**. Original v1 and synthetic upgraded v2 fixtures passed four checks each. Synthetic v3 landscape migration is covered separately from the authentic old fixture.
- Palette audit returned **three geometry/text-fit verdicts**, one each for Terrain, Paths and Scenery. This is a headless bounds audit, not rendered UI or native input validation.
- Final review found and fixed a legacy queued-plan migration defect: independently restoring old active/pending layouts could reintroduce a starter palm and charge $15, changing a saved $100 reservation into $115. **Twelve final root regression checks passed**, including explicit reproduction of the old quote difference, preservation of the original reservation, full deferred demolition refund and controller loading of a separate saved draft. Only legacy layouts without landscape data are normalized; explicit current landscape saves retain strict validation.

## Portable executable

The final migration-fixed executable is **111,321,824 bytes**, SHA-256 `BAE7E8DBBCDCBC2CEBF9EB032DF8043F8B5C9DC3DEC41B957E1C0DD6AD0545D4`.

A clean executable-only Windows staging copy passed headless smoke with exit code 0: **12 completed stays, exact 95.25 rating, $1,120 cash**, production landscape/ocean/audio, **67 starter props, 158 stone path cells and 56 boardwalk cells**. The exporter explicitly includes `landscape_props.json`, preventing a missing data file from silently removing the environment.

Export succeeded. The sandboxed editor emitted its existing nonfatal preference safe-save warning; the actual standalone runtime passed. Native playtesting remains deferred, and no game window was opened for these checks.

Final logs are in `.tools/r4-integrator-logs/`, including `export-final.log`, `portable-smoke-final.log` and `legacy-v3-queue.log`. Root's final 12-check migration regression is `tests/landscape_legacy_queue_test.gd`; model tests are `tests/landscape_model_test.gd`, and routed scene/relaunch checks are `tests/landscape_scene_test.gd`.

## Final local package

`build/windows/AllInclusive.exe` matches the final executable identity above. `build/AllInclusive-Windows.zip` is **41,233,212 bytes**, SHA-256 `CE5986C08977D555503CDFB173D5B74C2A00B8022BFFF958831A64712A4F674A`.

Root verified exactly four flat archive entries: `AllInclusive.exe`, `START_HERE.txt`, `CREDITS.txt` and `THIRD_PARTY_NOTICES.txt`. Streaming the archived executable produced the final accepted SHA-256. `build/SHA256SUMS.txt` was updated. The earlier provisional package was replaced after the migration fix. No Git commit, push or release publication was performed.
