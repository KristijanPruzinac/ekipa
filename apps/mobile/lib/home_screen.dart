import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'design.dart';
import 'discovery.dart';
import 'discovery_widgets.dart';
import 'event_screen.dart';
import 'models.dart';
import 'preferences.dart';
import 'tip_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.preferences});
  final WagzApi api;
  final SharedPreferences preferences;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  PublicFeed? feed;
  String? error;
  bool loading = false;
  late DiscoveryProfile savedProfile = DiscoveryProfile.load(
    widget.preferences,
  );
  DiscoveryProfile get profile => audienceProfile(savedProfile);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.events();
      if (mounted) setState(() => feed = result);
    } catch (err) {
      if (mounted) setState(() => error = err.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> selectAudience(String audience) async {
    final value = DiscoveryProfile(audience: audience);
    setState(() => savedProfile = value);
    try {
      if (await value.save(widget.preferences)) return;
    } catch (_) {
      // The in-memory preference still works if local storage is unavailable.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Odabir vrijedi za ovu sesiju. Spremanje na uređaj nije uspjelo.',
          ),
        ),
      );
    }
  }

  void openTip() => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => TipScreen(api: widget.api)),
  );

  void openEvent(WagzEvent event) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => EventScreen(event: event, profile: profile),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final events = rankForAudience(
      feed?.events ?? [],
      audience: profile.audience,
    );
    final matches = events.where((row) => row.audienceMatch).length;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
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
                          Flexible(
                            child: Text(
                              '45°33′ N  18°41′ E',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 10, color: muted),
                            ),
                          ),
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
                      const Text(
                        'Za koga tražiš plan?',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 13),
                      AudienceSelector(
                        audience: profile.audience,
                        onChanged: selectAudience,
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          profile.audience == 'all'
                              ? 'Svi događaji, po datumu. Odabir se pamti samo na ovom uređaju.'
                              : matches > 0
                              ? '$matches ${matches == 1 ? 'događaj odgovara' : 'događaja odgovaraju'} odabiru i ${matches == 1 ? 'dolazi prvi' : 'dolaze prvi'}. Svi ostaju u pregledu.'
                              : 'Zasad nema potvrđenih događaja za ovaj odabir. Svi ostaju u pregledu.',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: muted,
                          ),
                        ),
                      ),
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
                      if (events.isNotEmpty) ...[
                        const SizedBox(height: 26),
                        EventTimeline(events: feed!.events, onOpen: openEvent),
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
                                semanticsLabel:
                                    '${events.length} događaja, svi prikazani',
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
                            profile.audience == 'all'
                                ? 'Svi planovi, od najbližeg datuma.'
                                : 'Prvo potvrđeni odabir, zatim ostali planovi po datumu.',
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
                        const Text(
                          'Novi planovi su na putu.',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Znaš što se sprema u Osijeku? Podijeli s ekipom.',
                          style: TextStyle(color: muted, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: openTip,
                          child: const Text('Dojavi događaj'),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _EventCard(
                      key: ValueKey('event-card-${events[index].event.id}'),
                      event: events[index].event,
                      profile: profile,
                      index: index,
                      onTap: () => openEvent(events[index].event),
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
    required this.profile,
    required this.index,
    required this.onTap,
  });
  final WagzEvent event;
  final DiscoveryProfile profile;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final match = recommendation(event, profile);
    return Material(
      color: eventPaper(event),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: match.personal ? ink : line),
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
                    child: Eyebrow(
                      (categoryNames[event.category] ?? 'Ostalo').toUpperCase(),
                    ),
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
              if (match.reasons.isNotEmpty) ...[
                Container(
                  color: lime,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: Text(
                    match.personal
                        ? 'ZA TVOJ RADAR'
                        : (event.discovery.prominenceLabel ?? 'U GRADU')
                              .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
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
              if (match.reasons.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    match.reasons.first,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: muted,
                    ),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.price ?? 'Cijena nije navedena',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Icon(Icons.north_east, size: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
