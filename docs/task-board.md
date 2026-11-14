# Task board

## Delivered revision 7

| Task | Owner | State | Contract / evidence |
| --- | --- | --- | --- |
| Research and amenity contract | Root + PM | Complete | Official resort sources; four functional dry-land amenities, fixed coast |
| Amenity model, activities and editor | Model/UI developer | Complete | Independent contract127 and scene61; actual IDs/routes/slots, new-run starter set, costs and migration |
| Pixel amenity art and guest interaction | Beach visual specialist | Complete | Visual121; accepted actual-phase CPU preview, readable parasol/net/bar/stage |
| Independent tests, regressions and package | Root + specialists + PM | Complete | Management73+9, legacy/current saves, full regression roster, standalone smoke and archived executable hash verified |

Current package: `build/AllInclusive-Windows.zip`, 41,301,812 bytes, SHA-256 `66199887A1FC43EAD15C01C768348359DFAA16F1BF4C55A1E6DEEC51EB8A2EE5`. Executable: 111,390,200 bytes, SHA-256 `A15CDA2AC965BE162DFF726759F95797D05A67F598C96DF1AE72612613E6ACCE`. See `revision-7.md` and `revision-7-validation.md`. Specialists finished, production frozen, source ready for root's authorized commit/push. No native playtesting or new GitHub release.

## Earlier revision 6 (superseded artifact)

| Task | Owner | State | Contract / evidence |
| --- | --- | --- | --- |
| Real buffet collection and dining reservations | Simulation/layout developer | Complete | Independent dining63 and scene37; actual tables, FIFO/exclusivity, separate waits and safe reloads |
| Plate, seated-family and departure presentation | Dining visual specialist | Complete | CPU visual34 and preview inspection; seated plate readability and minimum-width badge fixed |
| Compatibility and independent acceptance | Developer + root + PM | Complete | Management73+9, construction46+6, landscape35, appearance46, legacy saves and seeded schedules passed |
| Windows executable and archive | Developer + root | Complete | Standalone headless smoke and matching archived executable verified; no native tester or Git publication |

Historical package: 41,274,527 bytes, SHA-256 `9A1796C03BD08A5BFDD601CAA2BA8DB0157086F48AADDDDB7943F343E4907ADB`. Executable: 111,362,472 bytes, SHA-256 `FB06BB622432D4E34A0AC29B56E887A027F7FCEE9FD52D3EB48DDECD8573C05C`. See `revision-6.md` and `revision-6-validation.md` for historical evidence. Native playtesting remained deferred.

## Earlier revision 5 (superseded artifact)

| Task | Owner | State | Contract / evidence |
| --- | --- | --- | --- |
| Building metadata and finish quotes | Root coordinator | Complete | Identity43, layout34, transactions24 and fixed-coast landscape63 passed |
| Exterior architecture, signs and finishes | Building visual designer | Complete | Renderer95 passed; generated CPU preview inspected; pool unchanged |
| Properties UI and game integration | UI/core developer | Complete | Routed appearance46, focused typing, draft/queue/reload, view preference and coast migration passed |
| Headless acceptance and local package | Developer + root + PM | Complete | Management73+9, construction46+6, landscape35+12, legacy saves, portable smoke and archive hash verification passed |

Historical package: 41,259,413 bytes, SHA-256 `2EB66FDBD4BF2B31BFA7392D923C01F972E383EDD7F24CD678BD5B81BB8855AD`. Executable: 111,347,672 bytes, SHA-256 `983556EB7432D4EC6EA26AB183484E8D4043FFE9BAE9AC7D88F784A38AAFB7B1`. See `revision-5.md` for behavior and `revision-5-validation.md` for historical acceptance evidence. Fixed coast retained; no native windows, tester resumption or Git publication.

## Earlier fixed-coast correction (superseded artifact)

The user's late scope answer supersedes the water-capable R4 assumption: keep the coast fixed. Model protection, Water-tool removal, transactional save feedback and re-export are complete. Land painting, paths and editable scenery remain. Root model 63, routed scene 35 + resume 12, construction 46 + 6, legacy queue 12 and v1/v2 four each passed. Standalone smoke and archive verification passed. No computer use, tester resumption or Git publication occurred.

Historical package: 41,234,389 bytes, SHA-256 `E36BD1A6B4AD63F2473D1CAA9AA62C8DFB25AA587FE038E291856C25B1FF7D48`. Its executable is 111,322,896 bytes and matches `9EA6A5E2EF8F4F6B24F4B0C300A9E1144B231A74C56FEAA4FD95515B239CBA1E`. See `fixed-coast-validation.md`. Native playtesting remained deferred. These and earlier R4 artifact identities are historical and superseded by R5 above.

## Earlier water-capable revision 4 (superseded)

| Task | Owner | State | Dependency / evidence |
| --- | --- | --- | --- |
| Landscape data, costs and navigation | Root coordinator | Complete; model frozen | 58 landscape + 24 existing transaction checks pass, including route preference and legacy custom-layout migration |
| Editable environment visuals and water clipping | Landscape visual designer | Complete | 306 checks pass; 67 editable default props and 214 connected path cells; no baked scenery/path remnants |
| Compact landscape tools and core integration | UI/core developer | Complete and accepted | Final 33 routed landscape + 8 resume checks; R3 construction 46+6 and management 73 pass; legacy queue/draft defect fixed and 12 targeted checks pass |
| Local Windows delivery | Developer + root + PM | Delivered and archive verified | Migration-fixed portable smoke and embedded executable hash pass; no push/release, visible windows or tester resumption |

See `revision-4.md` for scope, ownership and current validation restrictions.

Final R4 local archive: `build/AllInclusive-Windows.zip`, 41,233,212 bytes, SHA-256 `CE5986C08977D555503CDFB173D5B74C2A00B8022BFFF958831A64712A4F674A`. Its executable matches `BAE7E8DBBCDCBC2CEBF9EB032DF8043F8B5C9DC3DEC41B957E1C0DD6AD0545D4` (111,321,824 bytes). All authorized implementation and headless verification are complete. See `revision-4-validation.md`; native playtesting remains deferred, and the prior GitHub release was not changed.

## Delivered revision 3

| Task | Owner | State | Dependency / evidence |
| --- | --- | --- | --- |
| Build-mode contextual UI | UI designer/planner | Complete | 373 headless geometry/state/action checks passed; both modes and draft actions covered |
| Terrain split and modular buildings/assets | Modular visual designer | Complete | 111 headless geometry checks passed; terrain/atlas and CPU diagnostic composite inspected; reproducible PNGs |
| Layout model, validity and navigation | Root coordinator | Ready for integration | 34 model checks pass; cached wall/door/furniture routes; 24 public Sim transaction checks also pass |
| Build input, management and persistence integration | Sole developer | Complete and accepted | 46 routed construction + 6 relaunch checks; moved bedroom/pool, both modes, drafts/queued plans and saves verified |
| Headless acceptance and Windows delivery | Developer + root + PM | Delivered and archive verified | Portable smoke 12 stays / 95.25 / $1,120; final executable/ZIP hashes in `revision-3-validation.md`. Native playtest deferred by user |

See `revision-3.md` for decisions and ownership. Previous accepted revisions remain below.

Revision 3 implementation and permitted headless validation are complete. Final ZIP: `build/AllInclusive-Windows.zip` (41,158,774 bytes), SHA-256 `410EF0FE0CBA4F96CF935877B0A80D02F16E9610C7BC4B7E818FADFA71B15074`; its executable matches the frozen candidate `440128AA3378ABA61704296D3E13CB2C834233C7F42099C759094AFDC019698D`. No required implementation work remains. Native visual/interactive testing remains deferred as explicitly requested.

## Delivered revision 2

| Task | Owner | State | Dependency / evidence |
| --- | --- | --- | --- |
| Icon dock and contextual panels | UI designer | Component complete | Parser and headless panel/actions/dismissal/input checks passed; compact pixel-art direction selected by user |
| Expanded land and grounded pool | Visual/world designer | Complete; static art accepted | PM/root inspected generated map; all opaque terrace pixels at least 27 world pixels inland |
| Deterministic ocean and flags | Visual/world designer | Complete; integrated | 600 imported mask rows match terrain; seven condition samples/rewind checks pass |
| Bounded pan and cursor-anchored zoom | Root coordinator | Component complete | 34 headless camera tests pass; UI-blocked gestures and save-state roundtrip |
| Core integration and save regression | Software developer | Complete; headless checks accepted | 73 integration + 9 resume + 4 old-save checks pass; source and portable smoke preserve full progression |
| Revision acceptance and Windows package | Developer + root + PM | Delivered; archive verified | Headless portable smoke passes; ZIP executable hash matches candidate. Native playtesting remains deferred by explicit user instruction |

Previous accepted release is preserved below and backed up under `.tools/releases/`.

Root's headless UI layout checker also passed 1,244 geometry assertions across initial/completed states and all six panels. This establishes control bounds, not rendered appearance or native playtest results.

Revision 2 delivery: `build/AllInclusive-Windows.zip`, 41,107,901 bytes, SHA-256 `0A1E15CF69B16E9CB8A3188BA3F7A8DFDB78D0392A48CE4225635795A899657F`. Root verified its four entries and streamed the embedded executable to confirm SHA-256 `61942B3CF917B629904C1803F50B74164E23EEEE6FC4CFF1B39560A048A7B9CC`. Implementation and permitted headless verification are accepted. No required implementation work remains; interactive native validation is explicitly deferred for a future session.

## Delivered revision 1

| Task | Owner | State | Evidence / dependency |
| --- | --- | --- | --- |
| Scope and numerical progression | Planner | Accepted | `game-design.md`, `test-acceptance.md`; queue/rating fixtures independently calculated |
| Visual direction and original art | Visual designer | Complete and accepted | PM/root inspected original map; designer verified 20 sprite frame bounds and overlay alpha; original icon delivered |
| Runtime/export availability | Root coordinator | Complete | Godot 4.7.2 and verified Windows custom templates in `.tools/godot/` |
| Playable implementation | Software developer | Complete and accepted | All required systems implemented; deterministic Standard route 12 stays / 95.25 rating / $800; continued sandbox verified |
| Original music/effects | Audio designer + root ambience | Complete and integrated | Seven original PCM16 WAVs; loop/playback/mute and waveform checks pass; subjective listening not verified |
| Independent verification | Tester | Complete; no release blockers | Clean 49 source + 7 fresh-process assertions; malformed-save regression fixed; native/export results in `test-report.md` |
| Windows export and final QA | Developer + root + PM | Delivered and verified | Frozen native Standard recap 12 / 95.3 displayed / $800; continuation/quit clean; archive contents and embedded executable hash verified |

## Milestones

1. **Design contract:** numeric loop, stable art placement/interface, simple acceptance criteria.
2. **Playable alpha:** all required controls/systems and asset integration run without errors.
3. **Delivery:** meaningful independent tests pass, UI observed, Windows export launches, documentation matches delivered behavior.

## Accepted candidate and residual limits

Windows executable SHA-256: `4EDFCBD2946E90417B5978DB2E076CA28A889FBEC1249A97601C18DC53DAA7D2` (111,131,392 bytes, embedded assets). Root packaged `build/AllInclusive-Windows.zip` with executable, launch note, credits and third-party notices.

Final delivery archive: `build/AllInclusive-Windows.zip`, 41,054,531 bytes, SHA-256 `90D68C0A3E8E94AE2E0ECCC739C6C5B69612D15290FDF03F3185DD95A9ED8507`. Root verified exactly four entries (`AllInclusive.exe`, `START_HERE.txt`, `CREDITS.txt`, `THIRD_PARTY_NOTICES.txt`) and streamed the executable from inside the archive to confirm its hash matches the accepted candidate. All three milestones are accepted; no required work remains.

The native export's onboarding, active-service save/quit/relaunch/load, upgrade, full Standard recap, continued play and clean exit were observed by the independent tester. Speed-button checkmarks fit. The root separately observed a complete mixed-price source playthrough. See `test-report.md` and `native-playtest.md` for evidence.

Accepted minor controls quirks: Escape may first be consumed by a visible tooltip, and Space activates a focused button. The always-visible Menu/Pause controls work; both quirks are documented. Listening quality and a 12-minute real-time 1× run were not verified. Pacing has quiet intervals and forgiving tradeoffs; next-stage priorities are recorded in README.
