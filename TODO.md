# SYRI — Product backlog

Updated 4 October 2026. These are planned features and research tasks, not claims that the app already supports them. Prioritize useful four-country coverage, clear timestamps, source attribution, and an uncluttered map.

## Agreed next update

- [ ] **Consistent Albanian and English.** Put interface labels, controls, errors, notifications, and detail-card headings into one reviewed translation catalogue. Keep publisher text clearly identified and translate it separately when possible.
- [ ] **Four-country clarity.** Use the same layout and terminology in Albania, Kosovo, Montenegro, and North Macedonia. Label each data layer and report as live, recent, forecast, or reference; show its update time, source, location precision, and unavailable coverage honestly.
- [ ] **Brief category highlight.** When a category is selected, briefly emphasize its markers and soften other visible markers, then return to normal. Keep the map interactive and avoid another permanent overlay.
- [ ] **Consistent detail cards.** Give reports a shared reading order: title, time and freshness, location accuracy, source, explanation, then actions. Retain category-specific content and the current glass aesthetic.
- [ ] **Simpler Settings layout.** Keep the guide, language, notifications, countries, cache, sources, and documents easy to find. Group radar, satellite opacity, legend display, and aircraft refresh under an expandable Map controls section without removing those options.
- [ ] **Clearer country switches.** State exactly which news and map layers each country switch affects, and distinguish unavailable country data from a switched-off country.
- [ ] **Accessibility controls.** Add larger map markers and a reduced-motion option; verify marker spacing, tap targets, and animations on a phone.

## Requested additions — 4 October 2026

- [ ] **Energy flows / Rrjedhat e energjisë.** Use [ENTSO-E Transparency Platform](https://transparency.entsoe.eu/) data to show actual cross-border physical electricity flows as directional lines between Albania, Kosovo, Montenegro, and North Macedonia, with each country's available generation and load in compact details. Display the observation interval, publication delay, units, and missing submissions explicitly. Verify API-token access, coverage, reuse terms, and whether the four countries report consistently before designing a new category. Never treat scheduled commercial exchanges as actual physical flows.

**Shelved after phone review:** Radio, Space, and the 2016 Earth-at-Night composite are removed from the app. The eight curated radio links were too few and several did not open usable audio. Revisit Radio only with a sizeable four-country directory, verified playable streams, and reliable city locations. NASA does publish daily Black Marble science data, but the app needs a processed, dated, quality-checked map layer before offering it. The working Sky Now prototype remains in `lib/sky_view.dart` for possible reuse alongside a second genuinely useful Space layer; it is not available in the app.

**Transport and controls updated:** The map category arrow now opens its subcategories without switching them all on; the pill body still toggles the whole category. Cameras and Channels have no expansion arrow in the picker. Non-Albanian bus stops and terminals use the same OpenStreetMap query in every selected city, with backup Overpass servers if the first fails. Tirana retains its municipal stop data. Stop coverage depends on local mapping and these markers do not claim live vehicle positions.

## Progress on 27 September 2026

- The English subcategory action now says **Clear All** without depending on a downloaded translation model.
- News details show a cautious list of closely matching reports with source links and timestamps. This is not yet a stable event dossier or replay; the app does not claim the reports describe the same incident.
- The experimental Space category was removed after user feedback. Two tracked satellites rarely appeared over a normal city view, and the Moon overlay did not communicate visibility clearly. Reconsider only if a map-first implementation can be demonstrated with useful coverage and sustainable data access.
- Source details now separate publication time from the last source check and indicate cached/unavailable data. A complete per-item freshness audit remains.
- The notification worker now records eligible older reports even after its three-alert cap, avoiding a delayed burst on a later run. Android periodic background work still cannot guarantee instant delivery; server push remains a future decision.

## Build next

- [ ] **Event dossiers and timeline.** Combine reports about the same event into one readable card with a chronological update history, independent source links, event time versus publication time, location precision, and explicit uncertainty. Never infer that nearby signals have the same cause. Add a 24-hour replay only after events have stable IDs and reliable timestamps. Inspiration: [Meridian](https://github.com/nickk02/meridian) and [OSINT dashboard feedback](https://www.reddit.com/r/osinttools/comments/1ta5u7a/do_you_know_why_the_intelligence_dashboards_suck/).
- [ ] **Satellite before/after comparison.** For any selected place or major fire/flood, compare dated [Sentinel-2](https://dataspace.copernicus.eu/data-collections/copernicus-sentinel-missions/sentinel-2) scenes using a slider; consider [Sentinel-1 radar](https://documentation.dataspace.copernicus.eu/Data/Sentinel1.html) when clouds obscure optical imagery. Show acquisition time, resolution, cloud cover, and source. All four countries. Sentinel data is free for commercial use, but account, API quotas, processing, and attribution need an implementation review. This is distinct from the existing NASA GIBS daily satellite layer proposed in `docs/SYRI_DATA_SOURCES_RESEARCH.md`.
- [ ] **Earthquake impact view.** Enrich significant regional earthquake cards with a [USGS ShakeMap](https://earthquake.usgs.gov/data/shakemap/) shaking-intensity overlay and [PAGER](https://earthquake.usgs.gov/data/pager/) exposure estimate where a product exists. Match the USGS event carefully to the EMSC event; suppress the enrichment if identity is uncertain. Show revision time and label estimates as preliminary. All four countries; not every earthquake gets these products.
- [ ] **Satellite-observed flood extent.** Assess [Copernicus Global Flood Monitoring](https://emergency.copernicus.eu/data/) / [GFM API](https://api.gfm.eodc.eu/v2/) for a four-country flood polygon layer that appears only for recent relevant detections. Its [Sentinel-1-based monitoring](https://global-flood.emergency.copernicus.eu/news/214-global-flood-monitoring-annual-product-and-service-qa-report-2024/) is a different signal from GDACS flood alerts and Copernicus EMS activations. Verify exact licensing, authentication, current API shape, false-positive masks, and acquisition/processing delay before implementation. Never label a satellite observation as a live flood warning.
- [ ] **People potentially exposed to a hazard.** Evaluate the European Commission's [2025 global gridded population estimates](https://human-settlement.emergency.copernicus.eu/ghs_wup_pop_r2025a.php) and [built-up surface layer](https://human-settlement.emergency.copernicus.eu/emc_built_s.php) alongside a confirmed flood/fire/shaking footprint. Present the result as an estimate within the mapped area, not a count of injured people or damaged buildings. Apply equally to all four countries; use proper EU attribution and distinguish the 2025 population projection from a current census.

## Research before committing to a feature

- [ ] **Live coastal vessels.** Test [AIS Stream](https://aisstream.io/) for coverage near Albania and Montenegro and verify redistribution and ad-supported use in writing. Its [documentation](https://aisstream.io/documentation) calls for a server-held API key. Sea-only feature; no artificial equivalent for landlocked Kosovo or North Macedonia. Keep off the release roadmap until rights and operating costs are known.
- [ ] **Satellite pollution plumes.** Evaluate [Sentinel-5P near-real-time NO₂ and SO₂ data](https://documentation.dataspace.copernicus.eu/Data/SentinelMissions/Sentinel5P.html) for a dated regional overlay across all four countries. Determine useful spatial scale, cloud/quality filtering, processing cost, and whether it adds value beyond existing air-quality forecasts. Do not present column measurements as street-level breathing conditions.
- [ ] **Radiological monitoring.** Check actual station coverage, API access, freshness, and redistribution rights for all four countries in the European Commission's [EURDEP public maps](https://remap.jrc.ec.europa.eu/). The [EXTRA-EURDEP initiative](https://enlargement.ec.europa.eu/news/enhancing-radiological-data-exchange-and-strengthening-cooperation-nuclear-safety-between-eu-and-2025-08-20_en) includes all four, but participation does not prove current public station coverage. Only consider a quiet, opt-in monitoring layer if coverage and interpretation are reliable.

## Interface fixes

- [x] **Translate the subcategory clear button.** In English mode, change the mixed-language label “Hiqi all” to “Clear All”. Keep the Albanian label fully Albanian and check the other subcategory controls for mixed-language text.

## Reliability and release readiness

- [ ] **Show freshness and source status on every item.** Display the last successful update, last attempted check, and source availability clearly. Distinguish a delayed or unavailable source from a genuine zero or no events. Apply consistent wording in Albanian and English.
- [ ] **Complete the Albanian/English audit.** Check every screen, map control, subcategory, notification, loading/error state, and source-derived label for mixed-language text. Move interface strings into structured localization resources and verify both language modes on a device.
- [ ] **Define the notification delivery model.** Test and document the limits of the current phone-only background checks. Do not promise instant breaking-news alerts from periodic Android jobs; plan a server plus push notifications if prompt delivery becomes a release requirement. Verify notification taps open the exact report and that stale alerts are not delivered in a burst on app reopen.
- [ ] **Accessibility pass on the map and settings.** Check contrast, text scaling, screen-reader labels and reading order, and sufficiently large tap targets for small markers and controls. Test with TalkBack and accessibility scanning on a physical Android phone.
- [ ] **Android toolchain compatibility.** The current debug build succeeds, but Flutter warns that `workmanager_android` still applies the Kotlin Gradle Plugin and may be incompatible with a future Flutter version. Recheck the plugin before upgrading Flutter for release.
- [ ] **Prioritize event dossiers and timeline.** Build the existing event-timeline item under “Build next” before adding another general data feed; it should make related updates easier to follow and assess.

## Product rule

Do not add generic tourist POIs or another all-purpose icon feed merely to increase the layer count. Prefer evidence, change over time, and answers to specific user questions. A missing reading must be displayed as unavailable, never as safe or zero.
