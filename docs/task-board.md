# Task board

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
