import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/data/records.dart';
import 'package:mobile/src/state/providers.dart';
import 'package:mobile/src/widgets/safety_brief.dart';

/// Where, with whom, and what to do when you get there.
///
/// **Intention — this is the screen the product has to carry.** An hour before
/// the slot, four people who have never met find out where they are going and
/// who they are meeting. Everything before this was administration; this is the
/// moment somebody either leaves the house or does not.
///
/// The layout is `docs/reference/places/04-place-detail`, which the reference
/// notes call *"the single most directly reusable frame in the set"* — a hero,
/// a serif name, one line of location, an open/closed dot, metadata chips and a
/// floating action row — with the photograph replaced by the map, because we
/// have no venue photography and a real map of the real streets is a better
/// hero than a stock image would be.
///
/// **Order is by usefulness while walking**, not by importance in the abstract:
/// the mark first (it is what you hold up), then the place and how to find the
/// exact spot, then the map, then who, then what happens, then the brief. A
/// person opening this on the street reads the top two and puts the phone away.
///
/// **Names appear here and not before** (`02_DOMAIN.md §6`). Early names invite
/// pre-judgement and quiet last-minute filtering, which is both unkind and the
/// load-bearing failure mode for a product about not being screened.
class RevealScreen extends ConsumerWidget {
  /// The reveal for [hangout].
  const RevealScreen({required this.hangout, this.onArrived, super.key});

  /// What is being revealed.
  final Hangout hangout;

  /// Called when the person taps that they are there.
  final VoidCallback? onArrived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = hangout.meetingPoint;
    final sigil = hangout.sigil;
    final profile = ref.watch(profileProvider).value;
    final basemap = ref.watch(basemapProvider).value;

    return EkipaScreen(
      leading: Text(
        '${hangout.localDay} · ${hangout.localTime}',
        style: ZarType.monoKey.copyWith(color: ZarColors.ember),
      ),
      action: onArrived == null
          ? null
          : EkipaButton(label: 'I’m here', onPressed: onArrived),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sigil != null) _Mark(sigil: sigil),
          const SizedBox(height: ZarSpace.xl),

          if (place != null) ...[
            VenueName(place.name),
            const SizedBox(height: ZarSpace.xxs),
            Text(
              place.street,
              style: ZarType.body.copyWith(color: ZarColors.sandMuted),
            ),
            const SizedBox(height: ZarSpace.sm),
            Wrap(
              spacing: ZarSpace.xs,
              runSpacing: ZarSpace.xs,
              children: [
                ZarChip(
                  place.openNow ? 'open now' : 'check the hours',
                  tone: place.openNow ? ZarChipTone.good : ZarChipTone.waiting,
                  dot: true,
                ),
                if (place.walkMinutes != null)
                  ZarChip('${place.walkMinutes} min walk'),
                for (final chip in place.chips) ZarChip(chip),
              ],
            ),
            const SizedBox(height: ZarSpace.lg),

            // The most valuable string on the screen. A café with three
            // entrances becomes one place.
            EkipaCard(
              tone: EkipaCardTone.live,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THE EXACT SPOT',
                    style: ZarType.label.copyWith(
                      color: ZarColors.ember,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: ZarSpace.xs),
                  Text(place.standingSpot, style: ZarType.body),
                ],
              ),
            ),
            const SizedBox(height: ZarSpace.md),

            if (basemap != null)
              MapSurface(
                basemap: basemap,
                meetingPoint: place.location,
                anchor: profile?.anchor,
                zoom: 3.4,
                height: 280,
              )
            else
              _NoMap(street: place.street),
            const SizedBox(height: ZarSpace.xs),
            _WrongPlace(hangoutId: hangout.id),
            const SizedBox(height: ZarSpace.xxl),
          ],

          const Text('Who', style: ZarType.heading),
          const SizedBox(height: ZarSpace.sm),
          for (final member in hangout.members) ...[
            _MemberRow(member: member),
            const SizedBox(height: ZarSpace.xs),
          ],
          const SizedBox(height: ZarSpace.xxl),

          const Text('What happens', style: ZarType.heading),
          const SizedBox(height: ZarSpace.sm),
          EkipaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hangout.activity.name, style: ZarType.bodyStrong),
                const SizedBox(height: ZarSpace.xxs),
                Text(
                  hangout.activity.summary,
                  style: ZarType.body.copyWith(color: ZarColors.inkMuted),
                ),
                const SizedBox(height: ZarSpace.md),
                // Stated up front, not discovered at the end. This is the exit
                // script, and `06_ACTIVITIES.md §1` is explicit that the most
                // expensive ambiguity in a social meeting is "is it over?".
                Text(
                  'HOW IT ENDS',
                  style: ZarType.label.copyWith(
                    color: ZarColors.inkFaint,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: ZarSpace.xxs),
                Text(
                  hangout.activity.howItEnds,
                  style: ZarType.body.copyWith(color: ZarColors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZarSpace.xxl),

          // Second showing. The first was at confirmation, when opting out was
          // still free; this one is when it is about to matter.
          const _BriefAgain(),
          const SizedBox(height: ZarSpace.lg),
        ],
      ),
    );
  }
}

/// The mark, big, at the top.
class _Mark extends StatelessWidget {
  const _Mark({required this.sigil});

  final SigilMark sigil;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      children: [
        Sigil(symbol: sigil.symbol, colour: sigil.colour, size: 92),
        const SizedBox(height: ZarSpace.md),
        Text(
          'You are the ${sigil.label}',
          textAlign: TextAlign.center,
          style: ZarType.heading.copyWith(
            color: Sigil.palette[sigil.colour] ?? ZarColors.ink,
          ),
        ),
        const SizedBox(height: ZarSpace.xxs),
        Text(
          'Hold this up, or just say it out loud. That is how you find each '
          'other.',
          textAlign: TextAlign.center,
          style: ZarType.caption.copyWith(color: ZarColors.inkMuted),
        ),
      ],
    ),
  );
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) => EkipaCard(
    padding: const EdgeInsets.symmetric(
      horizontal: ZarSpace.md,
      vertical: ZarSpace.sm,
    ),
    child: Row(
      children: [
        Expanded(child: PersonName(member.name)),
        if (member.isYou)
          Text(
            'you',
            style: ZarType.caption.copyWith(color: ZarColors.inkFaint),
          ),
      ],
    ),
  );
}

/// One tap that demotes a venue.
///
/// Automatic, no queue (D11). A venue that people cannot find sinks on its own
/// and, past a threshold, deactivates pending re-ingestion.
class _WrongPlace extends ConsumerWidget {
  const _WrongPlace({required this.hangoutId});

  final String hangoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Align(
    alignment: Alignment.centerRight,
    child: EkipaButton(
      label: 'Something is wrong with this place',
      tone: EkipaButtonTone.quiet,
      onPressed: () => ref
          .read(gatewayProvider)
          .reportVenue(hangoutId: hangoutId, reason: 'reported_from_reveal'),
    ),
  );
}

/// What the reveal shows when the city's geometry is missing.
///
/// The map is context; the address and the standing spot are the answer. Losing
/// the map must not lose the screen.
class _NoMap extends StatelessWidget {
  const _NoMap({required this.street});

  final String street;

  @override
  Widget build(BuildContext context) => EkipaCard(
    tone: EkipaCardTone.quiet,
    child: Text(
      'No map for this city yet — $street will find it in any map app.',
      style: ZarType.body.copyWith(color: ZarColors.inkMuted),
    ),
  );
}

class _BriefAgain extends StatefulWidget {
  const _BriefAgain();

  @override
  State<_BriefAgain> createState() => _BriefAgainState();
}

class _BriefAgainState extends State<_BriefAgain> {
  bool _read = false;

  @override
  Widget build(BuildContext context) => EkipaCard(
    tone: EkipaCardTone.quiet,
    child: _read
        ? Row(
            children: [
              Expanded(
                child: Text(
                  'Read. Have a good evening.',
                  style: ZarType.body.copyWith(color: ZarColors.mint),
                ),
              ),
            ],
          )
        : SafetyBrief(
            holdLabel: 'Read it',
            onRead: () => setState(() => _read = true),
          ),
  );
}
