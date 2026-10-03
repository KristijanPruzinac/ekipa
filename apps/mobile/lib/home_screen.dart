import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'design.dart';
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
  bool forYou = false;
  String category = 'all';
  DateFilter date = DateFilter.all;
  final search = TextEditingController();
  late DiscoveryProfile profile = DiscoveryProfile.load(widget.preferences);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    search.dispose();
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

  Future<void> editPreferences() async {
    final value = await showPreferences(context, profile);
    if (value == null || !mounted) return;
    setState(() => profile = value);
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

  void clearFilters() => setState(() {
    date = DateFilter.all;
    category = 'all';
    search.clear();
  });

  @override
  Widget build(BuildContext context) {
    final query = normalize(search.text.trim());
    final events =
        (feed?.events ?? [])
            .where(
              (event) =>
                  (category == 'all' || category == event.category) &&
                  inDateFilter(event, date, feed!.now) &&
                  normalize(
                    '${event.title} ${event.venue ?? ''} ${event.description}',
                  ).contains(query),
            )
            .toList()
          ..sort((a, b) => compareEvents(a, b, profile, forYou));
    final filtered =
        category != 'all' || date != DateFilter.all || query.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: const Brand(),
        actions: [
          IconButton(
            onPressed: editPreferences,
            tooltip: 'Tvoj radar',
            icon: const Icon(Icons.tune),
          ),
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
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
                      const SizedBox(height: 24),
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
                      const SizedBox(height: 20),
                      const Text(
                        'Koncerti, izlasci i sve između.\nPronađi svoj razlog za izaći.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Divider(height: 1, color: ink),
                      const SizedBox(height: 26),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              color: lime,
                              child: Text(
                                '${feed!.events.length}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      InkWell(
                        onTap: editPreferences,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: line),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tune, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.isSet
                                          ? '${audienceNames[profile.audience]}${profile.interests.isEmpty ? '' : ' · ${profile.interests.length} interesa'}'
                                          : 'Prilagodi svoj radar',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Tvoj izbor ističe planove. Svi ostaju tu.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Pretraži događaje',
                          hintText: 'Što ti se radi?',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: search.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () => setState(search.clear),
                                  tooltip: 'Očisti pretragu',
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: dateFilterNames.entries
                              .map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(entry.value),
                                    selected: date == entry.key,
                                    onSelected: (_) =>
                                        setState(() => date = entry.key),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: {'all': 'Sve kategorije', ...categoryNames}
                              .entries
                              .map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(entry.value),
                                    selected: category == entry.key,
                                    onSelected: (_) =>
                                        setState(() => category = entry.key),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'POREDAK',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1,
                              color: muted,
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('Po datumu'),
                            selected: !forYou,
                            onSelected: (_) => setState(() => forYou = false),
                          ),
                          ChoiceChip(
                            label: const Text('Za tebe'),
                            selected: forYou,
                            onSelected: (_) => setState(() => forYou = true),
                          ),
                        ],
                      ),
                      if (forYou)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Prednost imaju tvoj odabir i istaknuta gradska događanja. Razlog vidiš uz događaj.',
                            style: TextStyle(
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
                      if (feed != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              '${events.length} ${events.length == 1 ? 'događaj' : 'događaja'} ${filtered ? 'za tvoj odabir' : 'na tvom radaru'}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 13,
                              ),
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
                          filtered
                              ? 'Ovdje je zasad mirno.'
                              : 'Novi planovi su na putu.',
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          filtered
                              ? 'Pogledaj druge datume ili kategorije.'
                              : 'Znaš što se sprema u Osijeku? Podijeli s ekipom.',
                          style: const TextStyle(color: muted, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: filtered ? clearFilters : openTip,
                          child: Text(
                            filtered
                                ? 'Prikaži sve događaje'
                                : 'Dojavi događaj',
                          ),
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
                      event: events[index],
                      profile: profile,
                      index: index,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => EventScreen(
                            event: events[index],
                            profile: profile,
                          ),
                        ),
                      ),
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
    final color = switch (event.category) {
      'music' => const Color(0xffe9e1f0),
      'nightlife' => const Color(0xffe1e5f4),
      'theatre' => const Color(0xfff4e0d6),
      'culture' => const Color(0xfff2e8c8),
      'sport' => const Color(0xffdeeadc),
      'community' => const Color(0xffdfeae5),
      _ => const Color(0xffe9e7df),
    };
    return Material(
      color: color,
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
