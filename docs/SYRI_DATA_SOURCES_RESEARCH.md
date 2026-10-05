# Burime të reja publike për SYRI

## Përfundimi kryesor

SYRI tashmë përdor pjesën më të madhe të burimeve globale që kanë vlerë të menjëhershme: Open-Meteo, MET Norway, EMSC, ADSB.lol, ADSBDB, FireMap, GDACS, RainViewer, Copernicus EMS, OpenStreetMap/Overpass dhe disa burime vendore. Zgjerimi më i dobishëm nuk është shtimi i më shumë pikave dekorative. Është shtimi i pesë produkteve që japin një sinjal të qartë për përdoruesin:

1. gjendja e rrjetit elektrik Shqipëri–Kosovë;
2. ndërprerjet e internetit;
3. rreziku nga rrëshqitjet e dheut pas reshjeve;
4. transporti publik me orare dhe stacione;
5. pamje satelitore të ditës për zjarre, tym, borë dhe përmbytje.

Këto mund të vendosen pa e kthyer aplikacionin në një hartë të mbingarkuar. Secili duhet të ketë një kartë përmbledhëse, kohën e përditësimit, burimin dhe një shpjegim të kufizimeve.

## Burimet e rekomanduara

| Prioriteti | Burimi | Çfarë jep | Mbulimi | Freskia | Qasja | Vendosja në SYRI |
|---|---|---|---|---|---|---|
| 1 | OST Open Data | ngarkesa, prodhimi, frekuenca dhe shkëmbimet ndërkufitare | Shqipëri dhe lidhja me Kosovën | pothuajse live | faqe publike; duhet identifikuar endpoint-i i faqes | Shërbime → Energji |
| 1 | KOSTT Transparency | prodhimi aktual, parashikimi i ngarkesës, shkyçjet e planifikuara dhe të paplanifikuara | Kosovë | aktuale/periodike | faqe publike; integrimi kërkon analizë të endpoint-eve | Shërbime → Energji |
| 1 | IODA | alarme dhe seri kohore për ndërprerje të internetit | të dy shtetet | afër kohës reale | API publike JSON | Alarme → Internet |
| 1 | NASA LHASA | probabilitet për rrëshqitje dheu të shkaktuara nga reshjet | të dy shtetet | minimumi rreth 5 orë vonesë | raster/ArcGIS/NASA Earthdata | Alarme → Rrëshqitje dheu |
| 1 | NASA GIBS | shtresa satelitore për vatra termike, tym, re, borë dhe imazhe reale të Tokës | të dy shtetet | shumë produkte brenda disa orëve | WMTS/WMS publike | Territori → Satelit |
| 2 | GTFS Tirana | 27 linja, rreth 490 stacione, itinerare dhe orare | Tiranë | feed aktiv për 2026 | ZIP GTFS, CC BY-SA | Transport → Autobusë |
| 2 | OpenAQ | matje fizike PM2.5/PM10 dhe ndotës të tjerë nga stacionet | Kosovë e konfirmuar; Shqipëria duhet kontrolluar për stacione aktive | sipas stacionit | API me llogari/çelës | Mjedisi → Stacione ajri |
| 2 | EEA Air Quality | stacione dhe të dhëna të raportuara e të validuara | Evropë dhe Ballkan | aktuale + historike | ArcGIS REST, GeoJSON, WMS/WFS | Mjedisi → Stacione zyrtare |
| 2 | EEA Protected Sites/CDDA | kufij dhe të dhëna zyrtare për zonat e mbrojtura | Shqipëri dhe Kosovë | vjetore | ArcGIS REST, GeoJSON, PBF | Territori → Zona të mbrojtura |
| 2 | ASIG Geoportal | gjeologji, minerale, adresa, ortofoto, parcela, njësi statistikore | Shqipëri | sipas shtresës | WMS/WFS publik | Territori |
| 2 | Kosovo Geoportal | ujëra, tubacione, ujitje, zona të mbrojtura dhe reliev | Kosovë | sipas shtresës | shërbime gjeohapësinore | Territori |
| 3 | WISE/EIONET | trupa ujorë, pellgje dhe të dhëna mjedisore | Shqipëri dhe Kosovë | jo domosdoshmërisht live | skedarë dhe shërbime GIS | Mjedisi → Ujëra |
| 3 | Global Fishing Watch | identitet anijesh, aktivitet peshkimi dhe ngjarje AIS | bregdeti shqiptar | jo AIS plotësisht live | token falas, vetëm përdorim jokomercial | Deti → Peshkim |
| 3 | ASKdata PxWeb | energji, ujë, mjedis, popullsi, transport dhe statistika | Kosovë | periodike | PxWeb/API | Karta informuese, jo alarme |
| 3 | Open Data Albania/SPARQL | financa, shëndetësi, arsim, mjedis dhe biznese | Shqipëri | sipas dataset-it | SPARQL/CSV/XML; portali ka pasur gabime 501 | Eksploro dhe statistika |

## Integrimet që duhen ndërtuar të parat

### 1. Energjia live

[OST Open Data](https://opendata.ost.al/) shfaq prodhimin total, ngarkesën totale, frekuencën dhe shkëmbimet fizike e të planifikuara Shqipëri–Kosovë, Shqipëri–Mali i Zi dhe Shqipëri–Greqi. [KOSTT Transparency](https://kostt.com/Transparency/BasicMarketDataOnGeneration) publikon prodhimin faktik, parashikimin e prodhimit dhe shkyçjet e planifikuara ose të paplanifikuara.

Në SYRI kjo duhet të jetë një kartë e vetme “Energjia tani” me:

- konsumin dhe prodhimin aktual;
- import/eksport me shigjetë dhe MW;
- frekuencën e rrjetit;
- paralajmërim vetëm kur ka devijim ose shkyçje reale;
- grafik 24-orësh;
- kohën e fundit të përditësimit.

Ky funksion ka identitet vendor dhe është shumë më i veçantë se një hartë trafiku që përdoruesi e gjen në Google Maps.

### 2. Ndërprerjet e internetit

[IODA](https://api.ioda.inetintel.cc.gatech.edu/v2/) ka API publike për alarme, ngjarje, përmbledhje dhe seri kohore të ndërprerjeve. SYRI mund të kontrollojë entitetet e Shqipërisë dhe Kosovës dhe të tregojë alarm vetëm kur sinjali bie dukshëm krahasuar me normalen.

Për përdoruesin duhen treguar:

- shteti ose operatori i prekur, kur është i disponueshëm;
- ora e fillimit;
- shkalla e rënies;
- sinjalet që e mbështesin zbulimin;
- statusi “duke vazhduar” ose “rikuperuar”.

IODA zbulon anomali teknike; nuk provon vetë shkakun. Teksti i kartës duhet ta thotë këtë qartë.

### 3. Rrëshqitjet e dheut

[NASA LHASA](https://data.nasa.gov/dataset/global-landslide-nowcast-from-lhasa-l4-1-day-1-km-x-1-km-version-2-0-0-global-landslide-no-0f8e8) kombinon reshjet satelitore, lagështinë e tokës dhe faktorë të terrenit për të prodhuar probabilitetin e rrëshqitjeve të dheut. Produkti global mbulon Shqipërinë dhe Kosovën. NASA deklaron një vonesë minimale rreth pesë orë, prandaj duhet quajtur “rrezik afër kohës reale”, jo alarm i konfirmuar.

Në hartë duhet të shfaqen vetëm qelizat mbi një prag të lartë. Një legjendë me 3 nivele dhe një kartë që shpjegon reshjet e fundit do të ishte më e kuptueshme se vendosja e rasterit të plotë mbi hartë.

### 4. Sateliti i ditës

[NASA GIBS](https://nasa-gibs.github.io/gibs-api-docs/access-basics/) ofron shtresa publike WMTS/WMS. Dokumentacioni përfshin edhe shtresa zjarresh VIIRS në format tile/vector. Kjo mund të krijojë një mënyrë “Satelit” me një slider kohor për:

- imazhin real të ditës;
- anomalitë termike VIIRS;
- retë dhe tymin;
- mbulesën e borës;
- krahasimin sot/dje pas përmbytjeve ose zjarreve.

Kjo është pamje satelitore, jo fotografi në kohë reale. Data dhe ora e kalimit të satelitit duhet të jenë gjithmonë të dukshme.

### 5. Autobusët e Tiranës

[Feed-i zyrtar GTFS i Bashkisë Tiranë](https://mobilitydatabase.org/feeds/gtfs/mdb-2345) është aktiv dhe përmban 27 linja. Burimi origjinal është `https://pt.tirana.al/gtfs/gtfs.zip`; [TUMI](https://hub.tumidata.org/dataset/gtfs-tirana) e publikon me licencë CC BY-SA.

Mund të shtohen:

- stacionet pranë përdoruesit;
- linjat që kalojnë aty;
- oraret e planifikuara;
- itinerari në hartë;
- “nisja e ardhshme” bazuar në orar.

Ky nuk është pozicion live i autobusit sepse feed-i është GTFS statik. Nuk duhet të shfaqet një autobus që lëviz pa një feed GTFS-Realtime të verifikuar. Për Prishtinën dhe qytetet e tjera duhet marrë feed zyrtar ose leje nga operatori; hartat komunitare nuk mjaftojnë për ta quajtur shërbim live.

## Burime të dobishme, por me kufizime

### Rrufetë live

[Blitzortung](https://www.blitzortung.org/en/compendium.php) ka të dhëna shumë të freskëta, por qasja e plotë lidhet me pjesëmarrësit e rrjetit dhe përdorimi komercial ndalohet. Diskutimet në [GitHub](https://github.com/Craeckie/Lightningmaps/blob/master/docs/lightning-api.md) dhe [Reddit](https://www.reddit.com/r/datasets/comments/fziyoo) konfirmojnë se nuk ka API publike zyrtare e të qëndrueshme për një aplikacion komercial. Rekomandimi është të mos përdoren WebSocket-e të padokumentuara. Mund të vendoset vetëm një lidhje te harta zyrtare derisa të merret leje me shkrim.

### Anijet dhe peshkimi

[Global Fishing Watch](https://api-doc.globalfishingwatch.org/our-apis/documentation/) mund të tregojë aktivitet të mundshëm peshkimi, identitet anijesh dhe ngjarje AIS. Kërkon regjistrim, token dhe atribuim; API-ja ofrohet vetëm për përdorim jokomercial. Është e përshtatshme për prototipin, por jo si bazë e një produkti komercial pa marrëveshje. Nuk zëvendëson një feed AIS live.

### Cilësia e ajrit

[OpenAQ](https://docs.openaq.org/) jep matje fizike, jo një AQI të gatshëm. Lista e vendeve konfirmon Kosovën; për Shqipërinë duhet kontrolluar në çdo nisje nëse ka stacione aktive. Open-Meteo duhet të mbetet mbulimi modelues për të dy shtetet, ndërsa OpenAQ/EEA të etiketohen si “matje stacioni”. Kjo shmang përzierjen e parashikimit me sensorin real.

### Rrezatimi

[EURDEP](https://remon.jrc.ec.europa.eu/About/Rad-Data-Exchange) mbledh matje pothuajse live nga 39 vende. Para integrimit duhet verifikuar në endpoint nëse Shqipëria dhe Kosova kanë stacione aktive dhe çfarë të drejtash ripërdorimi zbatohen. Pa stacione vendore, një shtresë rajonale do të ishte më shumë dekorative sesa e dobishme.

### Kamerat

GitHub dhe Reddit kanë shumë agregues kamerash, por projektet më të mëdha mbulojnë kryesisht rrjetet 511 të SHBA-së dhe disa vende evropiane. Projekti [Provenance](https://github.com/011-sam-110/Provenance) është referencë e mirë për monitorimin e shëndetit të stream-it dhe paraqitjen e origjinës së çdo sinjali, jo provë se ka kamera funksionale në Shqipëri apo Kosovë. Çdo kamerë e SYRI-t duhet të kalojë kontroll automatik HTTP/HLS dhe të fshihet kur dështon disa herë radhazi.

## Arkitektura e kategorive

Burimet e reja përshtaten në kategoritë ekzistuese pa shtuar kategori kryesore të panevojshme:

- **Alarme**: rrëshqitje dheu, ndërprerje interneti, anomali energjie, rrezatim vetëm nëse ka stacione.
- **Moti**: vazhdojnë Open-Meteo, MET Norway dhe RainViewer; rrufetë mbeten lidhje derisa të ketë licencë.
- **Shërbime**: energjia e rrjetit, ndërprerje uji/dritash dhe statusi i internetit.
- **Transport**: autobusët GTFS, stacionet dhe oraret; pozicion live vetëm kur ekziston GTFS-RT.
- **Territori**: NASA GIBS, LHASA, ASIG dhe Kosovo Geoportal.
- **Mjedisi**: stacione OpenAQ/EEA, WISE, zonat e mbrojtura dhe cilësia e ujërave.
- **Deti**: moti detar dhe portet; Global Fishing Watch vetëm në modalitet jokomercial.

## Rregulla cilësie për çdo integrim

Çdo shtresë e re duhet të kalojë këto kushte para se të ndizet për përdoruesit:

1. Të ketë timestamp të burimit dhe etiketë “live”, “afër kohës reale”, “parashikim” ose “statike”.
2. Të ketë mbulim të verifikuar për Shqipëri, Kosovë ose një zonë të emërtuar qartë.
3. Të mos shfaqë pika pa shpjegim; çdo marker duhet të hapë detaje ose të ketë legjendë.
4. Të fshihet automatikisht kur të dhënat janë më të vjetra se kufiri i shtresës.
5. Të ruajë atribuimin, licencën dhe lidhjen origjinale.
6. Të mos përdorë endpoint-e të padokumentuara si bazë prodhimi pa leje.
7. Të kontrollojë statusin e burimit dhe të përdorë cache me shënimin “kopje e vjetër”.

## Rendi i zbatimit

### Faza e parë

- IODA për ndërprerjet e internetit;
- OST dhe KOSTT si karta energjie;
- GTFS Tirana;
- NASA LHASA me prag të lartë dhe legjendë;
- NASA GIBS si shtresë satelitore opsionale.

### Faza e dytë

- ndarja e ajrit në “model” dhe “stacion real”;
- EEA/CDDA për zona të mbrojtura në të dy shtetet;
- WISE për ujërat;
- të dhënat statistikore PxWeb si kontekst për qytetet.

### Faza eksperimentale

- Global Fishing Watch vetëm nëse modeli i përdorimit mbetet jokomercial;
- rrufe vetëm pas lejes së Blitzortung;
- rrezatim vetëm pasi të konfirmohen stacionet aktive;
- kamera vetëm me monitorim automatik të stream-eve.

## Burimet

1. OST. [Open Data](https://opendata.ost.al/).
2. KOSTT. [Të dhënat themelore të tregut për gjenerimin](https://kostt.com/Transparency/BasicMarketDataOnGeneration).
3. Georgia Tech Internet Intelligence Lab. [IODA HTTP API](https://api.ioda.inetintel.cc.gatech.edu/v2/).
4. NASA. [Global Landslide Nowcast, LHASA 2.0](https://data.nasa.gov/dataset/global-landslide-nowcast-from-lhasa-l4-1-day-1-km-x-1-km-version-2-0-0-global-landslide-no-0f8e8).
5. NASA. [GIBS API documentation](https://nasa-gibs.github.io/gibs-api-docs/access-basics/).
6. Mobility Database. [Municipality of Tirana GTFS](https://mobilitydatabase.org/feeds/gtfs/mdb-2345).
7. TUMI Datahub. [GTFS Tirana](https://hub.tumidata.org/dataset/gtfs-tirana).
8. OpenAQ. [API documentation](https://docs.openaq.org/).
9. European Environment Agency. [Air Quality REST services](https://eeha.discomap.eea.europa.eu/arcgis/rest/services/AirQuality).
10. European Environment Agency. [Nationally designated protected areas](https://bio.discomap.eea.europa.eu/arcgis/rest/services/ProtectedSites/CDDAv21_Dyna_WM/MapServer).
11. EIONET. [WISE spatial data](https://cdr.eionet.europa.eu/help/WFD/WISE_SoE/wise5).
12. ASIG. [Albanian National Geoportal](https://asig.gov.al/en/geoportal/).
13. Kosovo Agency of Statistics. [ASKdata PxWeb](https://askdata.rks-gov.net/pxweb/en/ASKdata/).
14. Global Fishing Watch. [API documentation](https://api-doc.globalfishingwatch.org/our-apis/documentation/).
15. European Commission JRC. [EURDEP](https://remon.jrc.ec.europa.eu/About/Rad-Data-Exchange).
16. GitHub. [Provenance open-data map](https://github.com/011-sam-110/Provenance).
17. GitHub. [OSIRIS live OSINT map](https://github.com/carbon-evolution/osiris).
