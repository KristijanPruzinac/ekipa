import 'package:flutter/material.dart';
import 'design.dart';
import 'discovery.dart';
import 'models.dart';

class EventScreen extends StatelessWidget {
  const EventScreen({super.key, required this.event, this.now});
  final WagzEvent event;
  final String? now;

  @override
  Widget build(BuildContext context) {
    final sources = event.sources.where(
      (source) => safeLink(source.url) != null,
    );
    final evidence = [
      ...sourceAudienceEvidence(event),
      if (event.discovery.prominenceEvidence != null)
        event.discovery.prominenceEvidence!,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Detalji događaja')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(
                (categoryNames[event.category] ?? 'Ostalo').toUpperCase(),
              ),
              const SizedBox(height: 16),
              Text(
                event.title,
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 36,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 24),
              if (event.status != 'scheduled') ...[
                Notice(
                  event.status == 'cancelled'
                      ? 'Ovaj događaj je otkazan.'
                      : 'Ovaj događaj je odgođen. Novi termin provjeri kod organizatora.',
                  error: true,
                ),
                const SizedBox(height: 24),
              ],
              if (now != null && isOngoing(event, now!)) ...[
                Wrap(
                  key: const ValueKey('detail-ongoing'),
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffe1ecc8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'U tijeku',
                        style: TextStyle(
                          color: Color(0xff425124),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${eventDurationText(event, now)}${event.endsAt!.length == 10 ? ' · završni sat nije naveden' : ''}',
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              _fact(
                'KADA',
                '${formatDate(event.startsAt, 'EEEE, d. MMMM y.')}\n${formatTime(event.startsAt)}'
                    '${event.endsAt == null ? '\nKraj nije naveden' : '\nDo ${formatDate(event.endsAt!)}${event.endsAt!.length > 10 ? ', ${formatTime(event.endsAt!)}' : ''}'}'
                    '${durationLabel(event) == null ? '' : '\nTrajanje: ${durationLabel(event)}'}',
              ),
              _fact(
                'GDJE',
                '${event.venue ?? 'Lokacija još nije navedena'}\n${event.address ?? event.city}',
              ),
              _fact('ULAZ', event.price ?? 'Cijena nije navedena'),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(
                  event.description,
                  style: const TextStyle(fontSize: 16, height: 1.6),
                ),
                const SizedBox(height: 32),
              ],
              const Eyebrow('IZVOR I DETALJI'),
              const SizedBox(height: 12),
              if (sources.isEmpty)
                const Text(
                  'Objavljeno prema dojavi koju je pregledalo uredništvo.',
                ),
              ...sources.map(
                (source) => _source(
                  context,
                  'Otvori izvornu najavu',
                  source.name,
                  source.url,
                ),
              ),
              for (final item in evidence.where(
                (item) => safeLink(item.sourceUrl) != null,
              ))
                _source(
                  context,
                  item.audience == null
                      ? 'Zašto je istaknuto?'
                      : 'Publika navedena u najavi: ${audienceNames[item.audience]}',
                  item.reason,
                  item.sourceUrl,
                ),
              const SizedBox(height: 20),
              const Text(
                'Planovi se mogu promijeniti. Prije odlaska provjeri izvornu najavu. '
                'Sve vrijeme prikazano je za Osijek.',
                style: TextStyle(color: muted, height: 1.6, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fact(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(label),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 17, height: 1.5)),
        const SizedBox(height: 16),
        const Divider(color: line, height: 1),
      ],
    ),
  );

  Widget _source(
    BuildContext context,
    String title,
    String subtitle,
    String url,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: const Color(0xffe7edc5),
      borderRadius: BorderRadius.circular(4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xff96a366)),
          borderRadius: BorderRadius.circular(4),
        ),
        focusColor: const Color(0xffd8e294),
        hoverColor: const Color(0xffe3eab8),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(color: muted)),
        trailing: const Icon(Icons.north_east),
        onTap: () => openSource(context, url),
      ),
    ),
  );
}
