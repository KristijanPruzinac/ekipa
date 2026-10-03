import 'package:flutter/material.dart';
import 'design.dart';
import 'models.dart';
import 'preferences.dart';

class EventScreen extends StatelessWidget {
  const EventScreen({super.key, required this.event, required this.profile});
  final WagzEvent event;
  final DiscoveryProfile profile;

  @override
  Widget build(BuildContext context) {
    final match = recommendation(event, profile);
    final sources = event.sources.where(
      (source) => safeLink(source.url) != null,
    );
    final evidence = [
      ...event.discovery.audienceEvidence.where(
        (evidence) => evidence.audience == profile.audience,
      ),
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
              if (match.reasons.isNotEmpty) ...[
                Notice(
                  '${match.personal ? 'Za tvoj radar' : event.discovery.prominenceLabel ?? 'U gradu'}\n${match.reasons.join('\n')}',
                ),
                const SizedBox(height: 24),
              ],
              _fact(
                'KADA',
                '${formatDate(event.startsAt, 'EEEE, d. MMMM y.')}\n${formatTime(event.startsAt)}'
                    '${event.endsAt == null ? '' : '\nDo ${formatDate(event.endsAt!)}${event.endsAt!.length > 10 ? ', ${formatTime(event.endsAt!)}' : ''}'}',
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
                  source.name,
                  'Otvori izvornu najavu',
                  source.url,
                ),
              ),
              for (final item in evidence.where(
                (item) => safeLink(item.sourceUrl) != null,
              ))
                _source(
                  context,
                  'Zašto je istaknuto?',
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
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: const RoundedRectangleBorder(side: BorderSide(color: line)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.north_east),
      onTap: () => openSource(context, url),
    ),
  );
}
