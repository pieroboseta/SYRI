import 'package:flutter/material.dart';

import 'guide_visuals.dart';

enum SyriInfoKind { guide, privacy, terms }

class SyriInfoPage extends StatelessWidget {
  const SyriInfoPage({super.key, required this.kind, required this.english});

  final SyriInfoKind kind;
  final bool english;

  String t(String sq, String en) => english ? en : sq;

  static const _background = Color(0xff0d2020);
  static const _mint = Color(0xffc7f36a);
  static const _muted = Color(0xff9fb2af);

  @override
  Widget build(BuildContext context) {
    final sections = _sections();
    final title = switch (kind) {
      SyriInfoKind.guide => t('Si përdoret SYRI', 'How to use SYRI'),
      SyriInfoKind.privacy => t('Privatësia', 'Privacy policy'),
      SyriInfoKind.terms => t('Kushtet e përdorimit', 'Terms of use'),
    };
    final intro = switch (kind) {
      SyriInfoKind.guide => t(
        'Nga zgjedhja e qytetit te leximi i hartës: hap çdo temë, shiko shembullin dhe provo hapat.',
        'From choosing your city to reading the map: open each topic, see the example and try the steps.',
      ),
      SyriInfoKind.privacy => t(
        'Çfarë ruhet në pajisje dhe si lidhet aplikacioni me burimet e jashtme.',
        'What stays on your device and how the app connects to external sources.',
      ),
      SyriInfoKind.terms => t(
        'Si të përdorësh me përgjegjësi të dhënat e shfaqura në SYRI.',
        'How to use the information shown in SYRI responsibly.',
      ),
    };
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        title: Text(title),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 35),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff263d39), Color(0xff112a2a)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _mint.withValues(alpha: .35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_heroIcon, color: _mint, size: 34),
                      if (kind == SyriInfoKind.guide) ...[
                        const Spacer(),
                        Text(
                          t(
                            '${sections.length} MËSIME',
                            '${sections.length} LESSONS',
                          ),
                          style: const TextStyle(
                            color: _mint,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    kind == SyriInfoKind.guide
                        ? t('Mësoje SYRI-n me hapa', 'Learn SYRI step by step')
                        : title,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    intro,
                    style: const TextStyle(color: _muted, height: 1.5),
                  ),
                  if (kind == SyriInfoKind.guide) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.touch_app_outlined,
                          color: _mint,
                          size: 17,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            t(
                              'Hap një mësim, shiko shembullin dhe provo hapat në aplikacion.',
                              'Open a lesson, see the example, then try the steps in the app.',
                            ),
                            style: const TextStyle(color: _mint, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < sections.length; i++) ...[
              _sectionTile(sections[i], i),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  IconData get _heroIcon => switch (kind) {
    SyriInfoKind.guide => Icons.auto_stories_outlined,
    SyriInfoKind.privacy => Icons.shield_outlined,
    SyriInfoKind.terms => Icons.description_outlined,
  };

  Widget _sectionTile(_InfoSection section, int index) => Container(
    decoration: BoxDecoration(
      color: const Color(0xff213535).withValues(alpha: .68),
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: Colors.white.withValues(alpha: .16)),
    ),
    child: ExpansionTile(
      key: ValueKey('${kind.name}-$index'),
      initiallyExpanded: kind == SyriInfoKind.guide && index == 0,
      shape: const Border(),
      collapsedShape: const Border(),
      leading: CircleAvatar(
        radius: 19,
        backgroundColor: _mint.withValues(alpha: .13),
        child: Icon(section.icon, color: _mint, size: 21),
      ),
      title: Text(
        t(section.titleSq, section.titleEn),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        t(section.hintSq, section.hintEn),
        style: const TextStyle(color: _muted, fontSize: 11),
      ),
      iconColor: _mint,
      collapsedIconColor: _muted,
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      children: [
        const Divider(color: Colors.white12),
        const SizedBox(height: 6),
        if (kind == SyriInfoKind.guide)
          GuideIllustration(lesson: index, english: english),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            t(section.bodySq, section.bodyEn),
            style: const TextStyle(height: 1.55, fontSize: 14),
          ),
        ),
        if (kind == SyriInfoKind.guide) ...[
          const SizedBox(height: 15),
          Text(
            t('PROVO KËTO HAPA', 'TRY THESE STEPS'),
            style: const TextStyle(
              color: _mint,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          for (var step = 0; step < _guideSteps(index).length; step++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 21,
                    width: 21,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _mint.withValues(alpha: .14),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${step + 1}',
                      style: const TextStyle(
                        color: _mint,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _guideSteps(index)[step],
                      style: const TextStyle(fontSize: 12, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    ),
  );

  List<String> _guideSteps(int lesson) => switch (lesson) {
    0 => [
      t(
        'Prek emrin e qytetit në qendër të kreut.',
        'Tap the city name in the middle of the header.',
      ),
      t(
        'Zgjidh vendin dhe qytetin; ylli e vendos qytetin te të preferuarat, në krye të listës.',
        'Choose a country and city; the star puts a city in Favorites at the top of the list.',
      ),
      t(
        'Hap SYRI Tani për përmbledhjen e qytetit të ri dhe prek Lajme ose Alarme për të parë pikat në hartë.',
        'Open SYRI Now for the new city briefing, then tap News or Alerts to see markers on the map.',
      ),
    ],
    1 => [
      t(
        'Lëvize hartën me gisht te zona që do të shohësh.',
        'Drag the map to the area you want to inspect.',
      ),
      t(
        'Përdor dy gishta ose + / − për zmadhimin.',
        'Pinch or use + / − to adjust zoom.',
      ),
      t(
        'Prek shënjestrën për pozicionin tënd ose emrin e qytetit për ta ndërruar.',
        'Tap the target for your position or the city name to change city.',
      ),
    ],
    2 => [
      t(
        'Prek ikonën ose emrin e kategorisë për të ndezur të gjitha nënkategoritë; preke sërish për t’i fikur.',
        'Tap a category icon or name to turn on all its subcategories; tap again to turn them off.',
      ),
      t(
        'Prek vetëm shigjetën për të parë listën, pa ndezur asgjë. Pastaj zgjidh nënkategoritë një nga një në anën e majtë.',
        'Tap only the arrow to see the list without turning anything on. Then select subcategories one by one on the left.',
      ),
    ],
    3 => [
      t(
        'Prek butonin Zgjidh kategori në të djathtë të hartës për të hapur të gjitha kategoritë dhe nënkategoritë.',
        'Tap Choose a Category on the right of the map to open all categories and subcategories.',
      ),
      t(
        'Përdor çelësat për të mbajtur disa kategori ose vetëm nënkategoritë që të interesojnë.',
        'Use the switches to keep several categories or only the subcategories that interest you.',
      ),
      t(
        'Zgjedhjet ruhen në pajisje dhe rikthehen kur e hap sërish aplikacionin.',
        'Your selections are saved on the device and restored when you reopen the app.',
      ),
    ],
    4 => [
      t(
        'Shiko ikonën dhe ngjyrën për të dalluar llojin e pikës.',
        'Use the icon and color to recognize the type of marker.',
      ),
      t(
        'Prek numrin pranë ikonës për të hapur pikat e grupuara.',
        'Tap the count beside an icon to open grouped items.',
      ),
      t(
        'Zmadho hartën për më shumë hollësi; kontrollo nëse vendi është i përafërt.',
        'Zoom in for detail; check whether the location is approximate.',
      ),
      t(
        'Prek “Legjenda” për të parë të gjitha shpjegimet e shtresave aktive në një vend.',
        'Tap “Legend” to see explanations for every active layer in one place.',
      ),
    ],
    5 => [
      t(
        'Prek një pikë dhe lexo titullin, përmbledhjen e kohën.',
        'Tap a marker and read the title, summary and time.',
      ),
      t(
        'Shiko vendin dhe botuesin para se të mbështetesh te lajmi.',
        'Check the place and publisher before relying on the report.',
      ),
      t(
        'Përdor “Lexo te burimi” për raportin e plotë.',
        'Use “Read at source” for the full report.',
      ),
    ],
    6 => [
      t(
        'Hap skedën Ngjarje në fund të ekranit.',
        'Open the Events tab at the bottom.',
      ),
      t(
        'Përdor filtrat, kërkimin dhe butonin Rifresko kur dëshiron të dhëna të reja.',
        'Use filters, search and Refresh when you want new data.',
      ),
      t(
        'Prek SYRI Tani lart djathtas për motin, parashikimin 7-ditor dhe raportet pranë qytetit.',
        'Tap SYRI Now at the top right for weather, the seven-day forecast and nearby reports.',
      ),
    ],
    7 => [
      t(
        'Hap Cilësime → Njoftimet e personalizuara.',
        'Open Settings → Personalized notifications.',
      ),
      t(
        'Aktivizo kategoritë, pastaj hiq nënkategoritë që nuk do.',
        'Enable categories, then turn off unwanted subcategories.',
      ),
      t(
        'Vendos vendet, orarin e qetë dhe pragun minimal të tërmeteve.',
        'Set countries, quiet hours and the minimum earthquake level.',
      ),
    ],
    8 => [
      t(
        'Hap Cilësimet dhe gjej opsionin e gjuhës për vizitorët.',
        'Open Settings and find the visitor language option.',
      ),
      t(
        'Aktivizo anglishten; çaktivizoje për t’u kthyer në shqip.',
        'Enable English; turn it off to return to Albanian.',
      ),
      t(
        'Hap “Burimet dhe kreditet” për origjinën e çdo të dhëne.',
        'Open “Sources and credits” to see where data comes from.',
      ),
      t(
        'Butoni me dorën dhe zemrën në fund hap faqen Mbështet, ku dhurimi është vullnetar.',
        'The hand-and-heart button in the dock opens Support, where donations are optional.',
      ),
    ],
    _ => [
      t(
        'Hap një zonë me internet që të ruhen pjesët e shikuara të hartës.',
        'View an area online to cache the map parts you opened.',
      ),
      t(
        'Kur kthehesh aty, ato pjesë mund të hapen më shpejt.',
        'When you return, those parts may load faster.',
      ),
      t(
        'Për zona të reja dhe njoftime të fundit mbaje internetin aktiv.',
        'Keep internet on for new areas and the latest updates.',
      ),
    ],
  };

  List<_InfoSection> _sections() => switch (kind) {
    SyriInfoKind.guide => _guide,
    SyriInfoKind.privacy => _privacy,
    SyriInfoKind.terms => _terms,
  };

  static const _guide = <_InfoSection>[
    _InfoSection(
      Icons.location_city_outlined,
      '1. Zgjidh qytetin tënd',
      '1. Choose your city',
      'Vendos zonën për lajme dhe SYRI Tani',
      'Set your area for news and SYRI Now',
      'Prek emrin e qytetit në qendër të kreut. Zgjidh Shqipërinë, Kosovën, Malin e Zi ose Maqedoninë e Veriut dhe pastaj qytetin tënd. Ylli e vendos qytetin te të preferuarat në krye të listës. Qyteti i zgjedhur ndikon te lajmet dhe alarmet lokale, kërkimet e të dhënave, moti dhe përmbledhja SYRI Tani. Mund ta ndryshosh kur të duash; nuk ke nevojë të përdorësh GPS.',
      'Tap the city name in the middle of the header. Choose Albania, Kosovo, Montenegro or North Macedonia, then your city. The star adds a city to Favorites at the top of the list. Your selected city affects local news and alerts, data searches, weather and the SYRI Now briefing. Change it whenever you like; GPS is not required.',
    ),
    _InfoSection(
      Icons.map_outlined,
      '2. Fillo me hartën',
      '2. Start with the map',
      'Lëviz, zmadho dhe kthehu te vendndodhja',
      'Move, zoom and find your location',
      'Lëvize hartën me gisht dhe zmadhoje me dy gishta ose me butonat + dhe −. Shenja e shënjestrës të çon te vendndodhja jote pasi jep leje. Qytetin e zgjedhur mund ta ndryshosh nga emri në krye. Përqindja pranë kreditit OSM tregon nivelin e zmadhimit. Katër butonat poshtë hapin Hartën, Ngjarjet, Cilësimet dhe faqen Mbështet.',
      'Drag the map and pinch to zoom, or use the + and − buttons. The target button finds your location after you grant permission. Tap the city name at the top to change your selected city. The percentage beside the OSM credit shows the zoom level. The four dock buttons open Map, Events, Settings and Support.',
    ),
    _InfoSection(
      Icons.dashboard_customize_outlined,
      '3. Aktivizo kategoritë',
      '3. Turn on categories',
      'Kategori, nënkategori dhe shtresa',
      'Categories, subcategories and layers',
      'Prek ikonën ose emrin në një kapsulë sipër hartës për të ndezur të gjitha nënkategoritë e saj; preke sërish për t’i fikur. Për të zgjedhur vetëm disa, prek vetëm shigjetën: lista hapet në të majtë pa aktivizuar asgjë. Prek nënkategoritë një nga një ndërsa sheh hartën. Mund të mbash disa kategori ndezur dhe t’i pastrosh me “Hiqi të gjitha” në fund të rreshtit.',
      'Tap the icon or name in a pill above the map to turn on all its subcategories; tap again to turn them off. To pick only some, tap just the arrow: the list opens on the left without activating anything. Toggle subcategories one by one while looking at the map. Several categories can stay on; “Clear All” at the end of the row turns them off.',
    ),
    _InfoSection(
      Icons.dashboard_customize_outlined,
      '4. Ruaj pamjen që të pëlqen',
      '4. Save your preferred view',
      'Zgjidh kategori në të djathtë të hartës',
      'Choose a Category on the right of the map',
      'Butoni Zgjidh kategori në kolonën e djathtë hap të gjitha kategoritë dhe nënkategoritë në një vend. Aktivizo çelësat që dëshiron, qoftë disa kategori njëkohësisht, qoftë vetëm disa nënkategori. Zgjedhjet ruhen në pajisje: kur mbyll e rihap SYRI-n, harta kthehet me shtresat që ke zgjedhur. Përdor butonin “Hiqi të gjitha” kur do një fillim të pastër.',
      'The Choose a Category button in the right-hand controls opens every category and subcategory in one place. Turn on the switches you want, whether several categories together or just a few subcategories. Your choices are saved on the device: close and reopen SYRI, and the map restores your selected layers. Use “Clear All” when you want a fresh start.',
    ),
    _InfoSection(
      Icons.place_outlined,
      '5. Kupto pikat në hartë',
      '5. Understand map markers',
      'Ngjyra, numra dhe saktësia',
      'Colors, counts and accuracy',
      'Ikonat tregojnë llojin e informacionit. Numri pranë ikonës tregon disa njoftime të së njëjtës nënkategori; preke për t’i parë veçmas. Në zmadhim shumë të largët ikonat bëhen pika. “Legjenda” hap shpjegimet për të gjitha shtresat aktive, me emrin e nënkategorisë për secilën. Disa lajme vendosen afërsisht te qyteti, jo te adresa e saktë; kontrollo etiketën e vendndodhjes në detaje.',
      'Icons show the type of information. A number beside an icon means several items of the same subcategory; tap it to view them separately. At the furthest zoom levels icons become dots. “Legend” opens explanations for every active layer, each labeled with its subcategory. Some news is located approximately at city level, not at an exact address; check the location label in its details.',
    ),
    _InfoSection(
      Icons.article_outlined,
      '6. Lexo detajet dhe burimin',
      '6. Read details and the source',
      'Nga përmbledhja te raporti origjinal',
      'From summary to original report',
      'Prek një pikë për titullin, përmbledhjen, kohën, vendin dhe burimin. Butoni “Lexo te burimi” hap faqen origjinale; për kamerat përdor “Hap kamerën tani”. Mund të lundrosh te pika ose ta ndash kartën. Të dhënat live, raportet dhe parashikimet kanë nivele të ndryshme saktësie.',
      'Tap a marker for its title, summary, time, location and source. “Read at source” opens the original page; cameras have a “Watch camera now” button. You can navigate to a point or share its card. Live data, reports and forecasts have different levels of accuracy.',
    ),
    _InfoSection(
      Icons.dynamic_feed_outlined,
      '7. Shiko Ngjarjet dhe SYRI Tani',
      '7. Explore Events and SYRI Now',
      'Përmbledhja e zonës tënde',
      'A briefing for your area',
      'Te Ngjarjet shfaqen lajme, alarme dhe përditësime me rëndësi. Prek butonin e gjelbër SYRI Tani lart djathtas për motin, parashikimin 7-ditor, erën dhe raportet pranë qytetit të zgjedhur. Te Ngjarjet, përdor kërkimin, filtrat, Rifresko ose tërheqjen poshtë për të dhëna të reja; hapja e skedës nuk bën rifreskim automatik. Aeroplanët dhe kamerat nuk paraqiten si lajme.',
      'Events shows news, alerts and useful updates. Tap the green SYRI Now button at the top right for weather, the seven-day forecast, wind and reports near your selected city. In Events, use search, filters, Refresh or pull down for new data; opening the tab does not refresh automatically. Aircraft and cameras are not treated as news.',
    ),
    _InfoSection(
      Icons.notifications_active_outlined,
      '8. Personalizo njoftimet',
      '8. Personalize notifications',
      'Vetëm temat që kanë vlerë për ty',
      'Only the topics that matter to you',
      'Te Cilësime → Njoftimet e personalizuara, aktivizo kategoritë dhe më pas hiq nënkategoritë që nuk do. Mund të zgjedhësh vende, lajme nga bota, orar të qetë dhe pragun e tërmeteve. Android i kontrollon burimet periodikisht kur aplikacioni është i mbyllur; njoftimet nuk garantohen në çastin e publikimit.',
      'In Settings → Personalized notifications, enable categories and then remove subcategories you do not want. You can choose countries, world news, quiet hours and an earthquake threshold. Android checks sources periodically while the app is closed; delivery at the exact publishing moment is not guaranteed.',
    ),
    _InfoSection(
      Icons.language_outlined,
      '9. Ndrysho gjuhën dhe kontrollo burimet',
      '9. Change language and check sources',
      'Shqip fillimisht, anglisht për vizitorët',
      'Albanian first, English for visitors',
      'SYRI hapet në shqip. Aktivizo anglishten te cilësimi për vizitorët dhe ktheje sërish në shqip kur të duash. Te “Burimet dhe kreditet” shikon origjinën e të dhënave; te “Gjendja e burimeve” shikon nëse ato po përgjigjen. Butoni Mbështet në dock hap faqen e dhurimit vullnetar pa reklama.',
      'SYRI starts in Albanian. Enable English in the visitor setting and switch back whenever you like. “Sources and credits” lists data origins; “Source status” shows whether sources are responding. The Support button in the dock opens an optional donation page without ads.',
    ),
    _InfoSection(
      Icons.offline_bolt_outlined,
      '10. Interneti dhe cache-i',
      '10. Internet and cache',
      'Çfarë punon kur lidhja mungon',
      'What works without a connection',
      'Kur lidhja mungon, një njoftim i vogël sipër zhduket pas pak ose mund ta largosh me gisht. Pjesët e hartës dhe disa të dhëna që ke hapur më parë mbeten të përdorshme nga cache-i; prek ikonat e ruajtura për detajet e tyre. Kjo nuk është hartë e plotë offline: zona të papara, transmetimet, moti dhe njoftimet e reja kërkojnë internet. Madhësinë e cache-it të të dhënave mund ta shohësh e pastrosh te Cilësimet.',
      'When the connection is lost, a small notice appears at the top and disappears shortly, or you can swipe it away. Map areas and some data you opened before remain available from cache; tap saved markers for their details. This is not a complete offline map: unseen areas, streams, weather and new reports need internet. You can inspect and clear the source-data cache in Settings.',
    ),
  ];

  static const _privacy = <_InfoSection>[
    _InfoSection(
      Icons.storage_outlined,
      'Të dhënat në pajisje',
      'Data on your device',
      'Cilësime dhe kopje të ruajtura',
      'Settings and cached copies',
      'SYRI ruan lokalisht qytetin, gjuhën, vendet/kategoritë e zgjedhura, preferencat e njoftimeve dhe kopje të përkohshme të disa burimeve dhe pjesëve të hartës që ke parë. Nuk kërkohet llogari. Të dhënat e cache-it të burimeve mund t’i pastrosh te Cilësimet; cilësimet e tua mbeten.',
      'SYRI stores your city, language, selected countries/categories, notification preferences and temporary copies of some sources and viewed map tiles locally. No account is required. You can clear cached source data in Settings while keeping your preferences.',
    ),
    _InfoSection(
      Icons.my_location_outlined,
      'Vendndodhja',
      'Location',
      'Përdoret kur kërkon pozicionin tënd',
      'Used when you request your position',
      'Leja e vendndodhjes përdoret për të të treguar në hartë kur prek butonin e pozicionit. Aplikacioni nuk krijon historik lëvizjesh. Mund ta heqësh lejen në cilësimet e Android-it. Qyteti i zgjedhur mund të përdoret për të kërkuar të dhëna lokale edhe pa GPS.',
      'Location permission is used to show your position on the map when you tap the location button. The app does not build a movement history. You can revoke permission in Android settings. The selected city can be used to request local data without GPS.',
    ),
    _InfoSection(
      Icons.public_outlined,
      'Burimet dhe shërbimet e jashtme',
      'External sources and services',
      'Kërkesat në internet dhe lidhjet',
      'Internet requests and links',
      'SYRI kërkon harta, mot, lajme dhe të dhëna të tjera nga shërbime të jashtme. Këto shërbime mund të marrin adresën IP dhe parametrat e kërkesës, si qytetin ose zonën e hartës. Kur hap një burim, Buy Me a Coffee, PayPal ose LinkedIn, largohesh te shërbimi përkatës dhe zbatohet politika e tij. Lista e burimeve gjendet te “Burimet dhe kreditet”.',
      'SYRI requests maps, weather, news and other data from external services. Those services may receive your IP address and request parameters such as the selected city or map area. Opening a source, Buy Me a Coffee, PayPal or LinkedIn takes you to that service under its own policy. The source list is in “Sources and credits”.',
    ),
    _InfoSection(
      Icons.notifications_none_outlined,
      'Njoftimet dhe përkthimi',
      'Notifications and translation',
      'Funksione që mund t’i kontrollosh',
      'Features you control',
      'Nëse aktivizon njoftimet, aplikacioni kontrollon periodikisht burimet dhe ruan lokalisht identifikuesit e artikujve për të shmangur përsëritjet. Përkthimi në anglisht mund të kërkojë shkarkimin e një modeli në pajisje. Mund t’i çaktivizosh njoftimet dhe gjuhën e vizitorëve te Cilësimet.',
      'If you enable notifications, the app periodically checks sources and stores item identifiers locally to prevent duplicates. English translation may download an on-device model. You can turn off notifications and visitor language in Settings.',
    ),
    _InfoSection(
      Icons.manage_history_outlined,
      'Kontrolli yt',
      'Your control',
      'Pastro, ndrysho ose hiq aplikacionin',
      'Clear, change or remove the app',
      'Mund të ndryshosh zgjedhjet në çdo kohë. Pastro cache-in e burimeve nga aplikacioni; për të hequr të gjitha të dhënat lokale të SYRI-t, përdor “Pastro të dhënat” në cilësimet e Android-it ose çinstalo aplikacionin. Aktualisht nuk ka llogari përdoruesi për t’u fshirë.',
      'You can change preferences at any time. Clear source cache in the app; to remove all local SYRI data, use “Clear storage” in Android settings or uninstall the app. There is currently no user account to delete.',
    ),
  ];

  static const _terms = <_InfoSection>[
    _InfoSection(
      Icons.info_outline,
      'Qëllimi i aplikacionit',
      'Purpose of the app',
      'Informim publik, jo shërbim emergjence',
      'Public information, not an emergency service',
      'SYRI paraqet të dhëna dhe lidhje nga burime të jashtme për orientim të përgjithshëm. Nuk zëvendëson autoritetet, shërbimet e emergjencës apo këshillën profesionale. Në rrezik të menjëhershëm, ndiq udhëzimet dhe kanalet zyrtare të vendit ku ndodhesh.',
      'SYRI displays data and links from external sources for general awareness. It does not replace authorities, emergency services or professional advice. In immediate danger, follow official guidance and emergency channels where you are.',
    ),
    _InfoSection(
      Icons.schedule_outlined,
      'Koha dhe saktësia',
      'Timeliness and accuracy',
      'Burimet mund të vonohen ose të mungojnë',
      'Sources may be delayed or unavailable',
      'Raportet, pozicionet, parashikimet dhe klasifikimet mund të jenë të vonuara, të paplota ose të përafërta. Një pikë në hartë nuk vërteton domosdoshmërisht adresën e ngjarjes. Kontrollo gjithmonë kohën dhe lidhjen me burimin origjinal para se të marrësh vendime.',
      'Reports, positions, forecasts and classifications may be delayed, incomplete or approximate. A map marker does not necessarily confirm an event’s street address. Always check the time and original source before making decisions.',
    ),
    _InfoSection(
      Icons.link_outlined,
      'Përmbajtja e palëve të treta',
      'Third-party content',
      'Kredite dhe kushte të veçanta',
      'Credits and separate terms',
      'Lajmet, hartat, kamerat dhe shërbimet e tjera u përkasin botuesve përkatës. SYRI jep lidhje dhe kredite; përdorimi i faqeve të tyre mund t’u nënshtrohet kushteve të tyre. Mos e ripubliko përmbajtjen e tyre pa leje.',
      'News, maps, cameras and other services belong to their respective publishers. SYRI provides links and credits; their sites may have separate terms. Do not republish their content without permission.',
    ),
    _InfoSection(
      Icons.volunteer_activism_outlined,
      'Mbështetja vullnetare',
      'Optional support',
      'Aplikacioni mbetet i përdorshëm falas',
      'The app remains free to use',
      'Kontributet përmes Buy Me a Coffee ose PayPal janë vullnetare. Mos dhuro nëse pret qasje të veçantë, mbulim më të gjerë ose përgjigje prioritare: donacioni nuk i ofron këto.',
      'Contributions through Buy Me a Coffee or PayPal are optional. Do not donate expecting special access, broader coverage or priority support: a donation does not provide these.',
    ),
  ];
}

class _InfoSection {
  const _InfoSection(
    this.icon,
    this.titleSq,
    this.titleEn,
    this.hintSq,
    this.hintEn,
    this.bodySq,
    this.bodyEn,
  );

  final IconData icon;
  final String titleSq;
  final String titleEn;
  final String hintSq;
  final String hintEn;
  final String bodySq;
  final String bodyEn;
}
