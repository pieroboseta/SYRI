# Source inventory

Versioni 0.2 shton GDACS, AKMC RSS, Nominatim, Google News RSS, RTSH,
BalkanWeb, Telegrafi, Reporteri dhe Gazeta Express. ADSB.lol rifreskohet çdo
30 sekonda dhe pozicioni i avionit lëviz mes rifreskimeve. Nuk u verifikua një
feed falas trafiku që mbulon Shqipërinë/Kosovën; aplikacioni hap Waze ose
Google Maps për pamjen live.

Versioni 0.8 shton shtresat zyrtare WMS të ASIG, njoftimet për shëndetin,
ushqimin, hidrologjinë, shërbimet civile, bujqësinë dhe portet. Kamerat që nuk
hapeshin u hoqën; lidhjet e mbetura hapin vetëm faqen e transmetuesit origjinal.

Verified September 10, 2026 through live HTTP requests. A successful request proves endpoint access, not permanent availability or permission for every use.

## Mbulimi sipas vendit (rishikuar më 23 shtator 2026)

| E dhëna | Shqipëri | Kosovë | Maqedonia e Veriut | Mali i Zi |
|---|---|---|---|---|
| Mot, cilësi ajri, tërmete, zjarre, rreziqe GDACS, avionë, shërbime OSM | Po | Po | Po | Po |
| Lajme vendore, njoftime utilitare dhe anomali interneti | Po | Po | Po | Po; mbulimi varet nga botuesit |
| Kamera publike OpenCCTV | Po | Po | Po | Po |
| Kamera shtesë | Vlora LIVE, Skyline | Gjirafa SlowTV | Harta zyrtare rrugore, Skyline Kodra e Diellit dhe Liqeni i Ohrit | Video zyrtare kufitare Bozhaj/Sukobinë |
| Matje specifike | EEA ujë larës, nisje/mbërritje live të aeroportit Tiranë, ASIG | Nivele lumenjsh, pritje kufitare; drejtori aeroporti | Drejtori aeroportesh, GBIF | Portet, trageti dhe monitorimi zyrtar i ujit të plazheve; drejtori aeroportesh, GBIF |
| Zona të mbrojtura dhe biodiversiteti | EEA NatDA, OSM dhe GBIF | EEA NatDA, OSM dhe GBIF | EEA NatDA, OSM dhe GBIF | EEA NatDA, OSM dhe GBIF |
| Popullsia | Rrjeti 1 km² i Censit 2023; vlerësim kombëtar 1 janar 2026 | Vlerësim kombëtar 2024 | Vlerësim kombëtar 30 qershor 2025 | Vlerësim kombëtar në mes të 2025 |

Kutia e tërmeteve dhe ajo e zjarreve u zgjeruan në lindje deri në 23.1° gjatësie për të përfshirë të gjithë Maqedoninë e Veriut. Pikat nga katalogu i kamerave nuk dëshmojnë vetë që pamja po transmetohet në atë çast; përdoruesi e kontrollon te faqja origjinale.

Kontrolli i 4 tetorit 2026 shtoi lidhjet e drejtpërdrejta të RTK 1–4 nga menuja zyrtare e RTK-së, faqen me transmetim të E Televizija në Mal të Zi dhe kamerën e Liqenit të Ohrit nga SkylineWebcams. Faqet e katalogut OpenCCTV dhe lidhjet fikse të kamerave u përgjigjën gjatë kontrollit HTTP; përgjigjja e faqes nuk garanton që videoja e çdo kamere po transmeton. `tv.rtsh.al` nuk u zgjidh nga DNS gjatë kontrollit, ndërsa lidhjet e KTV dhe Arta HD çojnë në faqen e përgjithshme `koha.net` dhe jo drejtpërdrejt te luajtësi. Këto mbeten në aplikacion për vendim pas testimit në telefon. `alsat.mk/tv-alsat/` dhe `koha.net` kthyen 403 ndaj kontrollit automatik; kjo mund të jetë mbrojtje ndaj robotëve dhe nuk provon që faqet dështojnë në shfletues.

Shtresat ASIG që mbeten (rrjeti i popullsisë, cilësia e lumenjve, stacionet e ajrit) mbulojnë vetëm Shqipërinë; aplikacioni nuk i paraqet si harta të vendeve të tjera. Zonat e përmbytjes përdorin modelin rajonal Copernicus GloFAS dhe poligonet e zonave të mbrojtura përdorin EEA NatDA për të katër vendet. Pikat e popullsisë kombëtare nuk përfaqësojnë dendësinë në vendin ku vendoset ikona. Burimet e tyre janë [INSTAT 2026](https://www.instat.gov.al/sq/temat/treguesit-demografike-dhe-sociale/popullsia/publikimet/2026/popullsia-e-shqiperise-1-janar-2026/), [ASK 2024](https://ask.rks-gov.net/Releases/Details/8656), [Enti i Statistikës i Maqedonisë së Veriut, vlerësim 2025](https://makstat.stat.gov.mk/PXWeb/pxweb/en/MakStat/MakStat__Naselenie__ProcenkiNaselenie__ProcenkiPopis2021__Proceni30Juni/30062021_MKD_Za_PX.px/), dhe [MONSTAT 2025](https://www.monstat.org/cg/novosti.php?id=4700). Nuk u verifikua një shërbim i përbashkët falas për çdo shtresë tematike. Të dhënat WDPCA/Protected Planet nuk u integruan sepse [kushtet e tyre kërkojnë leje për përdorim komercial](https://www.protectedplanet.net/en/legal).

| Source | Use | Status and limits |
|---|---|---|
| OpenStreetMap | Interactive base map | ODbL attribution visible; no bulk download/offline prefetch. Standard tile policy applies. |
| Open-Meteo | Current weather, rain probability, sunrise/sunset and 6-day forecast | Live endpoint verified; model forecast, not an official warning feed. |
| [Open-Meteo Weather API](https://open-meteo.com/en/docs) | Vranësirat, dukshmëria/mjegulla dhe era për qytetet e katër vendeve | Parashikim orë pas ore; pikat janë afërsisht te qytetet, jo matje në vend. Të dhënat ruhen 30 minuta. |
| [Open-Meteo Flood API / GloFAS](https://open-meteo.com/en/docs/flood-api) | Prurje të modeluara shtatëditore në pika pranë qyteteve të katër vendeve | Rrjet modelor rreth 5 km; qeliza mund të mos përfaqësojë lumin e synuar. Nuk është matje zyrtare dhe nuk përcakton nivel rreziku. Ruhen 6 orë. |
| [NOAA SWPC scales](https://services.swpc.noaa.gov/products/noaa-scales.json) | Shkallë globale të vëzhguara dhe parashikim treditor për stuhi gjeomagnetike, ndërprerje radioje dhe rrezatim diellor | Nuk ka koordinata lokale; parashikimi nuk duhet lexuar si ndikim i konfirmuar në katër vendet. Ruhet 30 minuta. |
| [Open-Meteo Air Quality API](https://open-meteo.com/en/docs/air-quality-api) / CAMS | AQI, UV and pollen for every registered city in the enabled countries | City readings are fetched in batches and cached for 30 minutes. These are regional model estimates; pollen fields can be unavailable outside the European pollen season and are shown as unavailable rather than zero. Air markers are offset from agriculture markers and become small dots at wider map scales. |
| IHMK Kosovo river stations | River level, change, trend and observation time | Public HTML table with coordinates; the source states a four-hour update cycle. SYRI excludes readings older than 72 hours. |
| Tirana International Airport | Current arrivals and departures board | Official public page; status is translated to Albanian and cached for five minutes. Other regional airports are directory points, not live flight boards. |
| eTransport Albania | Intercity lines, operators and schedules | Opens the official platform; SYRI does not label scheduled times as live arrivals. |
| EMSC SeismicPortal | Regional earthquakes, last 7 days | Live GeoJSON verified; CC BY 4.0. Regional bounding box includes neighbouring countries for seismic context. |
| ADSB.lol | Detected aircraft near selected city | Live verified. ODbL 1.0; dynamic limits. Position age shown; not all aircraft/routes. |
| ADSBDB | Airline, origin and destination lookup | Public callsign endpoint; shown only when available and labelled as potentially inaccurate. |
| GDACS | Floods, wildfires, storms and volcanoes | Live GeoJSON verified; regional bounds and source attribution shown. Not a complete local emergency feed. |
| FireMap.live / NASA FIRMS | Recent fire and thermal detections | Public WFS verified with regional bounding box; extinguished reports and detections older than 24 hours are excluded from the active-fire map. |
| RainViewer | Recent precipitation radar tiles | Free small-community endpoint, five-minute metadata cache, visible attribution. |
| ASIG Geoportal | Albanian population grid, river-quality and air-station overlays | Public WMS endpoints verified; these are Albania-only reference layers with survey dates, not live alerts. |
| [Copernicus GloFAS](https://confluence.ecmwf.int/spaces/CEMS/pages/247897113/CEMS-Flood%2BWeb%2BMap%2BService%2BWMS%2B-%2BGeneral%2BInformation) | 100-year modeled flood-hazard map in all four countries | Regional WMS; modeled hazard, not a current flood report. |
| [EEA NatDA](https://bio.discomap.eea.europa.eu/arcgis/rest/services/ProtectedSites/NatDAv23_Dyna_WM/MapServer) | Protected-area polygons in all four countries | The WMS vector layers are filtered by country code to the four selected countries; the unfilterable Europe-wide raster layer is excluded. Boundaries and categories reflect reported inventory, not live changes. |
| [ESA WorldCover 2021](https://esa-worldcover.org/en/data-access) | Mbulesa e tokës në të katër vendet | WMS 10 m i verifikuar më 23.09.2026; CC BY 4.0. © ESA WorldCover project 2021 / Contains modified Copernicus Sentinel data (2021) processed by ESA WorldCover consortium. Klasifikim i vitit 2021, jo gjendje live. |
| ISHP, MSHMS, IKSHPK | Public-health alerts | Recent public reporting is filtered and linked to the original source; not a complete agency feed. |
| AKU, AUVK, RASFF | Food and product safety | Recent public reporting is filtered and linked; verify recall scope at the original notice. |
| KESH, AMBU, IGJEO/IGJEUM | Hydrology and reservoir notices | Reports older than 48 hours are excluded. Map positions may be approximate. |
| Municipalities and police | Civil closures, evacuations and service notices | Location-driven public reporting; maximum age 48 hours. |
| OpenStreetMap · Overpass | Fixed speed-camera points | Community mapped installations; coverage varies and road signs remain authoritative. |
| OpenStreetMap · Overpass | Zona të mbrojtura pranë qytetit të zgjedhur në të katër vendet | Pika e qendrës së zonës/rezervatit; jo kufiri zyrtar. Plotësia ndryshon sipas hartëzimit të komunitetit. |
| [AMMK](https://ammk-rks.net/assets/cms/uploads/files/Publikime-raporte//Raporti_Natyra_Eng.pdf), [MMJPH](https://www.moepp.gov.mk/mk-MK/odnosi-so-javnost/novosti/xodza-i-vo-2026-obezbedivme-sredstva-za-nacionalnite-parkovi-koi-se-klucen-stolb-vo-zastitata-na-prirodnoto-nasledstvo), [Parqet Kombëtare të Malit të Zi](https://nparkovi.me/edukativni-kutak) | Parqet kryesore në Kosovë, Maqedoninë e Veriut dhe Malin e Zi | Qendra të përafërta dhe lidhje me burimet; jo poligone zyrtare të kufirit. |
| [GBIF Occurrence API](https://techdocs.gbif.org/en/openapi/v1/occurrence) | Regjistrime të licencuara CC BY 4.0 të florës dhe faunës në katër vendet | Pika të ngjyrosura për florë dhe faunë në të katër vendet; mostër e kufizuar, jo hartë e plotë e biodiversitetit dhe jo vrojtime live. Detajet lidhen te regjistrimi origjinal. |
| [Luka Bar](https://lukabar.me/en/), [Ministria e Detarisë](https://www.gov.me/mpo/direktorat-za-pomorsku-i-unutrasnju-plovidbu), [Trajekt.me](https://trajekt.me/) | Porte dhe traget në Malin e Zi | Lidhje me operatorin/autoritetin, jo pozicione live anijesh ose orare të kopjuara. |
| [JP Morsko dobro](https://monitoring.morskodobro.me/?lang=en_US) | Monitorimi i cilësisë së ujit në plazhet e Malit të Zi | Pikat hapin portalin për rezultatin dhe datën; nuk janë vetë matje. |
| Google ML Kit Translation | Albanian and optional English display for external reports | The Albanian and English models download once; clear English feed text is translated into Albanian and Albanian app text into English on the device. Automatic language detection uses simple text cues and can miss or mistranslate mixed-language reports; original publisher links remain available. |
| Albanian State Police / Kosovo Police | Road controls, closures and diversions | Official notices only, maximum age 24 hours; map position is approximate unless the source provides exact coordinates. |
| Open-Meteo Agriculture | Frost, heat, hail, wind and drought indicators | Generated only when published forecast thresholds are crossed; advisory context, not an official warning. |
| Albanian Marine Traffic | Vessel map | Official external map; SYRI marks ports and does not invent vessel positions. |
| AKMC | Albanian civil-protection notices | Valid RSS verified; only place-matched hazard notices become approximate map points. |
| Nominatim | Place search | Search only after submission, limited to Albania, Kosovo, North Macedonia and Montenegro, cached locally; no autocomplete. |
| Google News RSS | Location-driven headlines | Actual publisher displayed and original result link retained. |
| Star Plus TV | RSS headlines and original links | Valid RSS verified; robots allows crawling. Titles only; original report opens externally. |
| KALLXO | RSS headlines and original links | Valid RSS verified. Titles only, cached for 15 minutes. |
| RTSH, BalkanWeb | Albania RSS headlines | Valid feeds verified; titles and original links only. |
| Telegrafi, Reporteri, Gazeta Express | Kosovo RSS headlines | Valid feeds verified; titles and original links only. |
| Portalb, Alsat | North Macedonia headlines | Public RSS feeds; Albanian titles and original links only. |
| Koha Javore, Ul-info | Montenegro headlines | Public RSS feeds focused on Albanian-speaking communities; original links retained. |
| Top Channel | Original website | Feed returned 403; do not bypass. Directory link only. |
| TV Klan | Original website | Directory link only, no claimed feed integration. |
| Klan Kosova | Original website | /feed/ returns HTML, not RSS. Directory link only. |
| RTSH, RTK, AKMC, IHMK | Original websites | Directory links; no automated extraction claimed. |
| OpenCCTV | Geolocated public-camera catalog for Albania, Kosovo, North Macedonia and Montenegro | Country pages and camera links verified September 22, 2026. SYRI links to individual pages; an indexed camera may temporarily be offline. Entries outside the expected country bounds are excluded. |
| North Macedonia Public Enterprise for State Roads | Official road-camera map | Albanian-language page verified September 22, 2026. SYRI links to the official map; its single directory pin is approximate, not a camera position. |
| Montenegro Ministry of Interior | Border-crossing camera videos | HTTP pages and recent MP4 responses verified September 22, 2026 for Božaj and Sukobin. HTTPS refused the connection, so the official HTTP pages open externally. Video is not a measured wait time. |
| Vlora LIVE, SkylineWebcams, Gjirafa SlowTV, Kufiri.LIVE | Camera publisher pages | Opens the original publisher; availability and livestream status can change without notice. |
| Traffic / AIS | Future sources | No verified zero-cost regional redistribution integration yet. |

## Primary references

- https://operations.osmfoundation.org/policies/tiles/
- https://www.openstreetmap.org/copyright
- https://open-meteo.com/en/terms
- https://www.seismicportal.eu/fdsn-wsevent.html
- https://www.adsb.lol/docs/open-data/api/
- https://opencctv.org/cameras/north-macedonia
- https://opencctv.org/cameras/montenegro
- https://roads.org.mk/sq/rrjeti-rrugor/kamerat-mbikeqyrese/
- http://kamere.mup.gov.me/
- https://eonet.gsfc.nasa.gov/docs/v3
- https://www.starplus-tv.com/feed/
- https://kallxo.com/feed/

## Before a public release

Use a shared caching backend for feeds, weather and aircraft; confirm provider volume and republication conditions; evaluate a production tile provider; validate Albanian event extraction on reviewed examples; maintain source health, corrections and retention policies. This prototype intentionally uses low-volume direct requests for personal device testing. It is not an emergency notification system.
