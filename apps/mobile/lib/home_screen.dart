import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'design.dart';
import 'discovery.dart';
import 'discovery_widgets.dart';
import 'event_screen.dart';
import 'models.dart';
import 'tip_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api});
  final WagzApi api;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  PublicFeed? feed;
  String? error;
  bool loading = false;
  bool refreshing = false;
  String? activity;
  Timer? refreshTimer;
  final detailFeed = ValueNotifier<PublicFeed?>(null);
  Route<void>? eventRoute;
  String? openedEventId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    scheduleRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refreshTimer?.cancel();
    detailFeed.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    refreshTimer?.cancel();
    if (state == AppLifecycleState.resumed) {
      refresh(background: true);
      scheduleRefresh();
    }
  }

  void scheduleRefresh() {
    refreshTimer?.cancel();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
      refreshTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => refresh(background: true),
      );
    }
  }

  Future<void> refresh({bool background = false}) async {
    if (refreshing) return;
    refreshing = true;
    setState(() {
      if (!background) loading = true;
      error = null;
    });
    try {
      final result = await widget.api.events();
      if (mounted) {
        setState(() => feed = result);
        detailFeed.value = result;
        if (eventRoute != null &&
            !result.events.any((event) => event.id == openedEventId)) {
          Navigator.of(context).removeRoute(eventRoute!);
          eventRoute = null;
          openedEventId = null;
        }
      }
    } catch (err) {
      if (mounted) setState(() => error = err.toString());
    } finally {
      refreshing = false;
      if (mounted) setState(() => loading = false);
    }
  }

  void openTip() => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => TipScreen(api: widget.api)),
  );

  Future<void> openEvent(WagzEvent event) async {
    openedEventId = event.id;
    final route = MaterialPageRoute<void>(
      builder: (_) => ValueListenableBuilder<PublicFeed?>(
        valueListenable: detailFeed,
        builder: (_, current, _) {
          final matching = current?.events.where((item) => item.id == event.id);
          return EventScreen(
            event: matching?.isNotEmpty == true ? matching!.first : event,
            now: current?.now ?? feed?.now,
          );
        },
      ),
    );
    eventRoute = route;
    await Navigator.push(context, route);
    if (eventRoute == route) {
      eventRoute = null;
      openedEventId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allEvents = rankForAudience(feed?.events ?? []);
    final activityCounts = {
      for (final category in categoryNames.keys)
        if (allEvents.any((row) => row.event.category == category))
          category: allEvents
              .where((row) => row.event.category == category)
              .length,
    };
    final events = allEvents
        .where((row) => activity == null || row.event.category == activity)
        .toList();
    final ongoing = events
        .where((row) => isOngoing(row.event, feed!.now))
        .toList();
    final upcoming = events
        .where((row) => !isOngoing(row.event, feed!.now))
        .toList();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 36 + MediaQuery.textScalerOf(context).scale(40),
        title: const Brand(),
        actions: [
          IconButton(
            onPressed: openTip,
            tooltip: 'Dojavi događaj',
            icon: const Icon(Icons.add_circle_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: refresh,
          color: ink,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: Color(0xff728400)),
                          SizedBox(width: 8),
                          Expanded(child: Eyebrow('OSIJEK, HR')),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Osijek,\nvidimo se',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 46,
                          height: 1.02,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                        ),
                      ),
                      Container(
                        color: lime,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: const Text(
                          'vani.',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 46,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Koncerti, izlasci i sve između.\nPronađi svoj razlog za izaći.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Divider(height: 1, color: ink),
                      const SizedBox(height: 22),
                      if (error != null) ...[
                        const SizedBox(height: 20),
                        Notice(
                          '${feed == null ? '' : 'Prikazujemo zadnji učitani pregled.\n'}$error',
                          error: true,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: loading ? null : refresh,
                          label: const Text('Pokušaj ponovno'),
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: LinearProgressIndicator(
                            semanticsLabel: 'Učitavanje događaja',
                          ),
                        ),
                      if (allEvents.isNotEmpty || activity != null) ...[
                        const SizedBox(height: 24),
                        const Eyebrow('VRSTA DOGAĐAJA'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final entry in {
                              'all': allEvents.length,
                              ...activityCounts,
                            }.entries)
                              ChoiceChip(
                                key: ValueKey('activity-filter-${entry.key}'),
                                label: Text(
                                  '${entry.key == 'all' ? 'Sve' : categoryNames[entry.key]} · ${entry.value}',
                                ),
                                selected: (activity ?? 'all') == entry.key,
                                showCheckmark: false,
                                side: BorderSide(
                                  color: (activity ?? 'all') == entry.key
                                      ? ink
                                      : line,
                                  width: (activity ?? 'all') == entry.key
                                      ? 1.5
                                      : 1,
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.padded,
                                onSelected: (_) => setState(() {
                                  activity = entry.key == 'all'
                                      ? null
                                      : entry.key;
                                }),
                              ),
                          ],
                        ),
                      ],
                      if (events.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        EventTimeline(
                          events: events.map((row) => row.event).toList(),
                          now: feed!.now,
                          onOpen: openEvent,
                        ),
                      ],
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Uhvati grad.',
                              style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontSize: 29,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          if (feed != null)
                            Container(
                              key: const ValueKey('all-events-count'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              color: lime,
                              child: Text(
                                '${events.length}',
                                semanticsLabel: activity == null
                                    ? '${events.length} događaja, svi prikazani'
                                    : '${categoryNames[activity]}, ${events.length} od ${allEvents.length} događaja',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (feed != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            activity == null
                                ? 'Svi planovi, od najbližeg datuma.'
                                : '${categoryNames[activity]} · ${events.length} od ${allEvents.length} planova, od najbližeg datuma.',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (feed != null && events.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity == null
                              ? 'Novi planovi su na putu.'
                              : 'Nema događaja ove vrste.',
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          activity == null
                              ? 'Znaš što se sprema u Osijeku? Podijeli s ekipom.'
                              : '${categoryNames[activity]} trenutačno nema najavljenih događaja. Pogledaj ostale vrste ili prikaži sve.',
                          style: const TextStyle(color: muted, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: activity == null
                              ? openTip
                              : () => setState(() => activity = null),
                          child: Text(
                            activity == null
                                ? 'Dojavi događaj'
                                : 'Prikaži sve događaje',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (ongoing.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OngoingEvents(
                          now: feed!.now,
                          events: ongoing.map((row) => row.event).toList(),
                          onOpen: openEvent,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Sljedeće u gradu · ${upcoming.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (upcoming.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Nove najave stižu uskoro. Programi koji traju dostupni su iznad.',
                              style: TextStyle(
                                fontSize: 12,
                                color: muted,
                                height: 1.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList.builder(
                  itemCount: upcoming.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _EventCard(
                      key: ValueKey('event-card-${upcoming[index].event.id}'),
                      event: upcoming[index].event,
                      index: index,
                      onTap: () => openEvent(upcoming[index].event),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (feed?.lastCheckedAt != null)
                        Text(
                          'Zadnji dohvat: ${formatDate(feed!.lastCheckedAt!, 'd. M. HH:mm')}',
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      const SizedBox(height: 4),
                      const Text(
                        'Sve vrijeme prikazano je za Osijek.',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        color: lime,
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Eyebrow('DOBRA INFORMACIJA DALEKO IDE.'),
                            const SizedBox(height: 16),
                            const Text(
                              'Znaš nešto što\nmi ne znamo?',
                              style: TextStyle(
                                fontSize: 28,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: openTip,
                              label: const Text('Podijeli s ekipom'),
                              icon: const Icon(Icons.north_east),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Manje skrolanja. Više Osijeka.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Neovisni pregled događanja.\nDetalje prije odlaska provjeri kod organizatora.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    super.key,
    required this.event,
    required this.index,
    required this.onTap,
  });
  final WagzEvent event;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: eventActionLabel(event),
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: eventPaper(event),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: line),
          borderRadius: BorderRadius.circular(4),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    EventMotif(
                      theme: themeForCategory(event.category),
                      compact: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Eyebrow(eventCategoryLabel(event).toUpperCase()),
                    ),
                    Text(
                      '/${(index + 1).toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (event.status != 'scheduled')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      event.status == 'cancelled' ? 'OTKAZANO' : 'ODGOĐENO',
                      style: const TextStyle(
                        color: Color(0xff9b3022),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (event.status == 'scheduled' &&
                    event.discovery.prominenceLabel != null) ...[
                  Text(
                    event.discovery.prominenceLabel!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  event.title,
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 27,
                    height: 1.13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      formatDate(event.startsAt, 'dd'),
                      style: const TextStyle(
                        fontSize: 42,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatDate(event.startsAt, 'MMM').toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${formatDate(event.startsAt, 'EEE')} · ${formatTime(event.startsAt)}',
                            style: const TextStyle(fontSize: 12, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 17),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event.venue ?? 'Lokacija još nije navedena',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0x44171a17)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    eventDurationText(event),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.price ?? 'Cijena nije navedena',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffe0ebd3),
                        border: Border.all(color: const Color(0xffa9b998)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Detalji',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 7),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
