// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syri/data.dart';
import 'package:syri/main.dart';
import 'package:syri/info_pages.dart';
import 'package:syri/notification_payload.dart';

void main() {
  test(
    'protected-area service filters every rendered layer to active countries',
    () {
      final all = jsonDecode(
        protectedAreaLayerDefinitions({
          'Shqipëri',
          'Kosovë',
          'Mali i Zi',
          'Maqedonia e Veriut',
        }),
      ) as Map<String, dynamic>;
      expect(all.keys, containsAll(['0', '1', '3', '4']));
      expect(all.keys, isNot(contains('2')));
      expect(
        all.values,
        everyElement("cddaCountryCode IN ('AL','XK','ME','MK')"),
      );
      final kosovoOnly = jsonDecode(
        protectedAreaLayerDefinitions({'Kosovë'}),
      ) as Map<String, dynamic>;
      expect(kosovoOnly['4'], "cddaCountryCode IN ('XK')");
    },
  );

  test(
    'English alert headlines are detected without changing Albanian copy',
    () {
      expect(
        SyriTranslation.looksEnglish('Food safety warning after recall'),
        isTrue,
      );
      expect(
        SyriTranslation.looksEnglish('Public health alert about virus'),
        isTrue,
      );
      expect(
        SyriTranslation.looksEnglish('Alarm për sigurinë ushqimore në Shkodër'),
        isFalse,
      );
    },
  );

  testWidgets('map stays mounted when visiting other tabs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SyriApp(loadData: false));
    await tester.pumpAndSettle();
    final map = find.byType(FlutterMap, skipOffstage: false);
    final originalState = tester.state(map);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(tester.state(map), same(originalState));
    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pumpAndSettle();
    expect(tester.state(map), same(originalState));
  });

  test('city picker pins favorites and restores country and city order', () {
    final favorites = <String>{'Shkup', 'Budva'};
    final sample = cities.where(
      (city) => const {
        'Shkodër',
        'Tiranë',
        'Prishtinë',
        'Budva',
        'Tivar',
        'Shkup',
      }.contains(city.name),
    );

    expect(orderedCitiesForPicker(sample, favorites).map((city) => city.name), [
      'Budva',
      'Shkup',
      'Shkodër',
      'Tiranë',
      'Prishtinë',
      'Tivar',
    ]);

    favorites.remove('Budva');
    expect(orderedCitiesForPicker(sample, favorites).map((city) => city.name), [
      'Shkup',
      'Shkodër',
      'Tiranë',
      'Prishtinë',
      'Budva',
      'Tivar',
    ]);
  });

  testWidgets(
    'favorites move to the top while only the selected city is highlighted',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({'setting_city': 'Berat'});
      await tester.pumpWidget(const SyriApp(loadData: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.place_outlined).first);
      await tester.pumpAndSettle();
      expect(find.text('Shqipëri'), findsOneWidget);
      final city = find.byKey(const ValueKey('city-Shqipëri-Durrës'));
      expect(
        (tester.widget<AnimatedContainer>(city).decoration as BoxDecoration)
            .border,
        isNull,
      );
      final selected = find.byKey(const ValueKey('city-Shqipëri-Berat'));
      expect(
        (tester.widget<AnimatedContainer>(selected).decoration as BoxDecoration)
            .border,
        isNotNull,
      );
      await tester.ensureVisible(city);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: city,
          matching: find.byIcon(Icons.star_border_rounded),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, 700));
      await tester.pumpAndSettle();
      expect(find.text('Të preferuarat'), findsOneWidget);
      expect(
        (tester.widget<AnimatedContainer>(city).decoration as BoxDecoration)
            .border,
        isNull,
      );
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: city,
                matching: find.byIcon(Icons.star_rounded),
              ),
            )
            .color,
        Colors.amberAccent,
      );
      await tester.ensureVisible(city);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: city, matching: find.byIcon(Icons.star_rounded)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Të preferuarat'), findsNothing);
      expect(
        (tester.widget<AnimatedContainer>(city).decoration as BoxDecoration)
            .border,
        isNull,
      );
    },
  );

  testWidgets('main screens and city picker fit a compact phone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.2)),
        child: SyriApp(loadData: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.place_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Zgjidh qytetin'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(180, 90));
    await tester.pumpAndSettle();
    for (final icon in [
      Icons.dynamic_feed_outlined,
      Icons.settings_outlined,
      Icons.volunteer_activism_outlined,
    ]) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$icon');
    }
  });

  testWidgets('city picker uses English labels immediately in tourist mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => setSyriEnglish(false));
    await tester.pumpWidget(const SyriApp(loadData: false));
    await tester.pumpAndSettle();
    setSyriEnglish(true);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.place_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Choose a city'), findsOneWidget);
    expect(find.text('Albania'), findsWidgets);
  });

  testWidgets('settings opens the Albanian beginner guide first', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => setSyriEnglish(false));
    await tester.pumpWidget(const SyriApp(loadData: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-guide')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-guide')));
    await tester.pumpAndSettle();
    expect(find.byType(SyriInfoPage), findsOneWidget);
    expect(find.text('Si përdoret SYRI'), findsWidgets);
    expect(find.textContaining('Prek emrin e qytetit'), findsWidgets);
    expect(find.byKey(const ValueKey('guide-illustration-0')), findsOneWidget);
    expect(find.text('PROVO KËTO HAPA'), findsOneWidget);
  });

  testWidgets('information pages follow the selected English language', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => setSyriEnglish(false));
    setSyriEnglish(true);
    await tester.pumpWidget(
      const MaterialApp(
        home: SyriInfoPage(kind: SyriInfoKind.privacy, english: true),
      ),
    );
    expect(find.text('Privacy policy'), findsWidgets);
    await tester.tap(find.text('Location'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('The app does not build a movement history'),
      findsOneWidget,
    );
  });

  testWidgets('guide illustrations fit a narrow phone in both languages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final english in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: SyriInfoPage(kind: SyriInfoKind.guide, english: english),
        ),
      );
      await tester.pumpAndSettle();
      for (var lesson = 0; lesson < 10; lesson++) {
        final tile = find.byKey(ValueKey('guide-$lesson'));
        await tester.scrollUntilVisible(
          tile,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(tile), alignment: .3);
        await tester.pumpAndSettle();
        if (lesson > 0) {
          await tester.tap(tile);
          await tester.pumpAndSettle();
        }
        expect(
          find.byKey(ValueKey('guide-illustration-$lesson')),
          findsOneWidget,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'lesson $lesson english=$english',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('support tab shows the donation page in both languages', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => setSyriEnglish(false));
    await tester.pumpWidget(const SyriApp(loadData: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.volunteer_activism_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('donate-page')), findsOneWidget);
    expect(find.text('Përshëndetje, jam Piero.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Më bli një kafe'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Më bli një kafe'), findsOneWidget);
    expect(find.text('Ose dhuro me PayPal'), findsOneWidget);
    expect(find.text('Njihu me Pieron në LinkedIn'), findsOneWidget);
    setSyriEnglish(true);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.volunteer_activism_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Buy me a coffee'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Buy me a coffee'), findsOneWidget);
    expect(find.text('Or donate with PayPal'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Meet Piero on LinkedIn'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Meet Piero on LinkedIn'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Hi, I’m Piero.'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hi, I’m Piero.'), findsOneWidget);
  });

  testWidgets('subcategory clear action is fully English without ML model', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SyriApp(loadData: false));
    await tester.pumpAndSettle();
    addTearDown(() => setSyriEnglish(false));
    setSyriEnglish(true);
    await tester.pump();
    await tester.tap(find.byTooltip('Zgjidh kategoritë'));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('map-clear-layers'))),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    expect(find.text('Clear All'), findsOneWidget);
    expect(find.text('Hiqi të gjitha'), findsNothing);
  });

  testWidgets('header puts city between the brand and SYRI Tani', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SyriApp(loadData: false));
    await tester.pumpAndSettle();
    final brandX = tester.getCenter(find.text('SYRI').first).dx;
    final cityX = tester.getCenter(find.text('Shkodër').first).dx;
    final nowX = tester
        .getCenter(find.byKey(const ValueKey('header-syri-now')))
        .dx;
    final screenCenter = tester.getSize(find.byType(Scaffold).first).width / 2;
    expect(brandX, lessThan(cityX));
    expect(cityX, lessThan(nowX));
    expect((cityX - screenCenter).abs(), lessThan(1));
    await tester.tap(find.byKey(const ValueKey('header-syri-now')));
    await tester.pumpAndSettle();
    expect(find.textContaining('SYRI Tani'), findsWidgets);
  });

  testWidgets('tapping a report notification opens its exact details', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SyriApp(loadData: false));
    await tester.pumpAndSettle();
    pendingNotificationPayload.value = eventNotificationPayload(
      const Event(
        id: 'notification-test',
        title: 'Raport prove për njoftimin',
        description: 'Përshkrimi i saktë i ngjarjes',
        summary: 'Përshkrimi i saktë i ngjarjes',
        source: 'Burimi prove',
        url: 'https://example.com/report',
        kind: 'news',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Raport prove për njoftimin'), findsWidgets);
    expect(find.text('Përshkrimi i saktë i ngjarjes'), findsWidgets);
  });

  test(
    'cache size counts only stored source payloads in UTF-8 bytes',
    () async {
      SharedPreferences.setMockInitialValues({
        'data_news': 'Lajm në Shkodër',
        'time_news': '2026-09-26T18:00:00',
        'setting_city': 'Shkodër',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(cachedSourceBytes(prefs), greaterThan(20));
      expect(formattedCacheSize(0), '0 MB');
      expect(formattedCacheSize(20972), '0.02 MB');
      expect(formattedCacheSize(1073741824), '1.00 GB');
    },
  );

  test('SYRI Tani excludes routine aircraft and catalog entries', () {
    expect(isBriefingKind('planes'), isFalse);
    expect(isBriefingKind('cameras'), isFalse);
    expect(isBriefingKind('parking'), isFalse);
    expect(isBriefingKind('fire'), isTrue);
    expect(isBriefingKind('power-outage'), isTrue);
    expect(isBriefingKind('news'), isTrue);
  });

  test('events feed keeps reports and alerts, not routine map layers', () {
    for (final kind in ['news', 'fire', 'quakes', 'power-outage']) {
      expect(isEventsFeedKind(kind), isTrue);
    }
    for (final kind in ['planes', 'cameras', 'parking', 'pharmacy']) {
      expect(isEventsFeedKind(kind), isFalse);
    }
  });

  test('news country uses location before publisher', () {
    const local = Event(
      id: 'cross-border',
      title: 'Ngjarje në Prishtinë',
      description: 'Raportim nga Prishtina',
      source: 'RTSH',
      url: 'https://example.org',
      kind: 'news',
    );
    const publisher = Event(
      id: 'publisher',
      title: 'Raportim i ditës',
      description: 'Përmbledhje',
      source: 'KALLXO',
      url: 'https://example.org',
      kind: 'news',
    );
    expect(newsCountry(local), 'Kosovë');
    expect(newsCountry(publisher), 'Kosovë');
    expect(
      newsCountry(
        const Event(
          id: 'portalb',
          title: 'Raportim nga Tetova',
          description: 'Përmbledhje',
          source: 'Portalb',
          url: 'https://example.org',
          kind: 'news',
        ),
      ),
      'Maqedonia e Veriut',
    );
    expect(
      newsCountry(
        const Event(
          id: 'ul-info',
          title: 'Raportim nga Ulqini',
          description: 'Përmbledhje',
          source: 'Ul-info',
          url: 'https://example.org',
          kind: 'news',
        ),
      ),
      'Mali i Zi',
    );
  });

  test('maps every supported city to its news country code', () {
    expect(
      countryCodeFor(cities.firstWhere((city) => city.name == 'Tiranë')),
      'AL',
    );
    expect(
      countryCodeFor(cities.firstWhere((city) => city.name == 'Prishtinë')),
      'XK',
    );
    expect(
      countryCodeFor(cities.firstWhere((city) => city.name == 'Tetovë')),
      'MK',
    );
    expect(
      countryCodeFor(cities.firstWhere((city) => city.name == 'Ulqin')),
      'ME',
    );
  });

  testWidgets('shows core navigation without network access', (tester) async {
    await tester.pumpWidget(const SyriApp(loadData: false));
    expect(find.text('SYRI'), findsOneWidget);
    expect(find.byKey(const ValueKey('dock-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('dock-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('dock-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('dock-3')), findsOneWidget);
    expect(find.text('Burime'), findsNothing);
  });

  testWidgets('searches events and opens sources from settings', (
    tester,
  ) async {
    await tester.pumpWidget(const SyriApp(loadData: false));

    await tester.tap(find.byIcon(Icons.dynamic_feed_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('events-search')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('events-search')),
      'cilësi uji',
    );
    await tester.pump();
    expect(
      find.textContaining('rezultate në të gjitha burimet'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-sources')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Rreth meje'), findsNothing);
    expect(find.byKey(const ValueKey('settings-sources')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-sources')));
    await tester.pumpAndSettle();
    expect(find.text('Një sy. Shumë burime.'), findsOneWidget);
  });

  testWidgets('exposes eight focused categories and detailed layers', (
    tester,
  ) async {
    await tester.pumpWidget(const SyriApp(loadData: false));
    expect(mapCategories, hasLength(8));
    expect(mapCategories.first.name, 'Lajme');
    expect(
      mapCategories.map((category) => category.name),
      containsAll(const ['Alarme', 'Territori', 'Ujërat', 'Kanale']),
    );

    await tester.tap(find.byTooltip('Zgjidh kategoritë'));
    await tester.pumpAndSettle();
    expect(find.text('Zgjidh kategoritë'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('picker-category-alerts')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('picker-category-services')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('picker-category-environment')),
      findsNothing,
    );

    await tester.drag(find.text('Zgjidh kategoritë'), const Offset(0, 180));
    await tester.pumpAndSettle();
    expect(find.text('Zgjidh kategoritë'), findsNothing);

    await tester.tap(find.byTooltip('Zgjidh kategoritë'));
    await tester.pumpAndSettle();
    final alarmSwitch = find.byKey(const ValueKey('picker-category-alerts'));
    expect(find.text('Alarme'), findsWidgets);

    final alarmToggle = find.byKey(
      const ValueKey('picker-category-toggle-alerts'),
    );
    expect(tester.widget<Switch>(alarmToggle).value, isFalse);
    await Scrollable.ensureVisible(tester.element(alarmSwitch), alignment: .4);
    await tester.pumpAndSettle();
    await tester.tap(alarmSwitch);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('picker-subcategory-quakes')),
      findsOneWidget,
    );
    await tester.tap(alarmToggle);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(alarmToggle).value, isTrue);
  });

  testWidgets('map icon row keeps multiple categories selected', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SyriApp(loadData: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-category-news')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('map-category-alerts')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('map-expand-alerts')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('map-subcategory-quakes')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Zgjidh kategoritë'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Switch>(
            find.byKey(const ValueKey('picker-category-toggle-alerts')),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Switch>(
            find.byKey(const ValueKey('picker-category-toggle-news')),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('map category arrow reveals choices without turning layers on', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SyriApp(loadData: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('map-expand-alerts')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('map-subcategory-quakes')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Zgjidh kategoritë'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Switch>(
            find.byKey(const ValueKey('picker-category-toggle-alerts')),
          )
          .value,
      isFalse,
    );
  });

  test('road-safety layers have distinct labels and icons', () {
    expect(infoFor('speed-camera').name, 'Kamerë shpejtësie');
    expect(infoFor('speed-camera').icon, Icons.speed);
    expect(infoFor('police-alert').name, 'Njoftim policor');
    expect(infoFor('police-alert').icon, Icons.local_police_outlined);
  });

  testWidgets('layer picker toggles subcategories independently', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SyriApp(loadData: false));

    await tester.tap(find.byTooltip('Zgjidh kategoritë'));
    await tester.pumpAndSettle();
    final alerts = find.byKey(const ValueKey('picker-category-alerts'));
    await tester.ensureVisible(alerts);
    await tester.tap(alerts);
    await tester.pumpAndSettle();
    final fire = find.byKey(const ValueKey('picker-subcategory-hazard:fire'));
    final quake = find.byKey(const ValueKey('picker-subcategory-quakes'));
    final storm = find.byKey(const ValueKey('picker-subcategory-hazard:storm'));
    expect(fire, findsOneWidget);
    expect(quake, findsOneWidget);
    expect(storm, findsOneWidget);
    expect(tester.widget<SwitchListTile>(fire).value, isFalse);
    expect(tester.widget<SwitchListTile>(quake).value, isFalse);
    await tester.ensureVisible(fire);
    await tester.tap(fire);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(fire).value, isTrue);
    expect(tester.widget<SwitchListTile>(quake).value, isFalse);
  });

  testWidgets('offers personalized notification controls', (tester) async {
    await tester.pumpWidget(const SyriApp(loadData: false));
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Njoftimet e personalizuara'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Mosha maksimale e lajmeve'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mosha maksimale e lajmeve'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Rrezja “Pranë qytetit”'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Rrezja “Pranë qytetit”'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Njoftimet e personalizuara'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 180));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Njoftimet e personalizuara'));
    await tester.pumpAndSettle();
    expect(find.text('Aktivizo njoftimet'), findsOneWidget);
    expect(find.text('Vetëm njoftime të rëndësishme'), findsOneWidget);
    expect(find.text('Orari i qetësisë'), findsOneWidget);
    expect(find.text('Të mira'), findsOneWidget);
    expect(find.text('Zjarre aktive'), findsWidgets);
  });

  testWidgets('shows cached data size and asks before clearing it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'data_example': 'x' * 20972});
    await tester.pumpWidget(const SyriApp(loadData: false));
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final cache = find.byKey(const ValueKey('settings-clear-cache'));
    await tester.scrollUntilVisible(
      cache,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('0.02 MB nga burimet'), findsOneWidget);
    await tester.tap(cache);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Të dhëna të ruajtura nga burimet: 0.02 MB'),
      findsOneWidget,
    );
    await tester.tap(find.text('Anulo'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString('data_example'),
      isNotNull,
    );
    await tester.tap(cache);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pastro'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString('data_example'),
      isNull,
    );
    expect(find.textContaining('0 MB nga burimet'), findsOneWidget);
  });

  testWidgets('notification category selects its children independently', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SyriApp(loadData: false));
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Njoftimet e personalizuara'));
    await tester.pumpAndSettle();
    final news = find.byKey(const ValueKey('notification-category-news'));
    final good = find.byKey(
      const ValueKey('notification-subcategory-news:good'),
    );
    final major = find.byKey(
      const ValueKey('notification-subcategory-news:major'),
    );
    await tester.ensureVisible(news);
    await tester.tap(news);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(good).value, isTrue);
    expect(tester.widget<SwitchListTile>(major).value, isTrue);
    await tester.ensureVisible(good);
    await tester.tap(good);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(good).value, isFalse);
    expect(tester.widget<SwitchListTile>(major).value, isTrue);
    expect(tester.widget<SwitchListTile>(news).value, isFalse);
    expect(find.text('Avionë live'), findsNothing);
  });

  testWidgets('country switches can independently hide regional news', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SyriApp(loadData: false));
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final albania = find.byKey(const ValueKey('country-news-Shqipëri'));
    final kosovo = find.byKey(const ValueKey('country-news-Kosovë'));
    final northMacedonia = find.byKey(
      const ValueKey('country-news-Maqedonia e Veriut'),
    );
    final montenegro = find.byKey(const ValueKey('country-news-Mali i Zi'));
    await tester.scrollUntilVisible(
      albania,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(tester.element(albania), alignment: .4);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(albania).value, isTrue);
    expect(tester.widget<SwitchListTile>(kosovo).value, isTrue);
    expect(tester.widget<SwitchListTile>(northMacedonia).value, isTrue);
    expect(tester.widget<SwitchListTile>(montenegro).value, isTrue);
    await tester.tap(albania);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(albania).value, isFalse);
    expect(tester.widget<SwitchListTile>(kosovo).value, isTrue);
  });

  testWidgets('opens SYRI Tani from the header, not Events', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SyriApp(loadData: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.dynamic_feed_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('syri-now-card')), findsNothing);
    expect(find.byKey(const ValueKey('header-syri-now')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('header-syri-now')));
    await tester.pumpAndSettle();
    expect(find.textContaining('SYRI Tani'), findsWidgets);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final touristCard = find.byKey(const ValueKey('tourist-mode-settings'));
    await tester.scrollUntilVisible(
      touristCard,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(touristCard, findsOneWidget);

    expect(find.text('Language / Gjuha'), findsOneWidget);
    expect(
      find.text('Tourist mode · Change the entire app to English'),
      findsOneWidget,
    );
    expect(find.text('Italiano'), findsNothing);
    expect(find.text('Deutsch'), findsNothing);
  });

  testWidgets('language switch updates reused labels in both directions', (
    tester,
  ) async {
    SyriTranslation.ready = true;
    setSyriEnglish(false);
    addTearDown(() {
      setSyriEnglish(false);
      SyriTranslation.ready = false;
    });
    await tester.pumpWidget(const MaterialApp(home: AppText('Cilësime')));
    expect(find.text('Cilësime'), findsOneWidget);

    setSyriEnglish(true);
    await tester.pump();
    expect(find.text('Settings'), findsOneWidget);

    setSyriEnglish(false);
    await tester.pump();
    expect(find.text('Cilësime'), findsOneWidget);
  });

  test('translated location keeps its city name', () {
    expect(
      SyriTranslation.restoreProtectedCities(
        '[[Syricity0]] · Approximate location',
        {0: 'Vlorë'},
      ),
      'Vlorë · Approximate location',
    );
    expect(
      SyriTranslation.restoreProtectedCities('SYRICITY0', {0: 'Shkodër'}),
      'Shkodër',
    );
  });

  testWidgets('core screen has labeled and sufficiently large tap targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const SyriApp(loadData: false));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
