import 'package:console/src/screens/configuration.dart';
import 'package:console/src/screens/schedule.dart';
import 'package:console/src/screens/trail.dart';
import 'package:console/src/state/providers.dart';
import 'package:console/src/theme/console_theme.dart';
import 'package:console/src/widgets/console_chrome.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The console's frame, and the gate in front of it.
///
/// **Intention — the gate asks the server, and shows what the server said.**
/// The shell renders nothing until [roleProvider] resolves, and it renders the
/// refusal itself when the answer is "no role". That is not politeness: the two
/// reasons a real operator sees `null` here are *you have no console role* and
/// *you did not complete a second factor*, and those need different actions
/// from the person reading the screen.
///
/// Note what the shell does **not** do: it does not decide anything. Hiding the
/// Configuration tab from a viewer would be a client-side permission, and rule
/// 6 says if the UI hides it the server must also refuse it. The server does
/// refuse it — every write RPC re-checks `admin_at_least('operator')` — so the
/// shell is free to show the tab and let the button be the thing that is
/// disabled. What a viewer cannot do, they can still see, which is how they
/// learn the tool.
class ConsoleShell extends ConsumerStatefulWidget {
  /// Creates the shell.
  const ConsoleShell({super.key});

  @override
  ConsumerState<ConsoleShell> createState() => _ConsoleShellState();
}

class _ConsoleShellState extends ConsumerState<ConsoleShell> {
  int _section = 0;

  static const List<({String label, IconData icon})> _sections = [
    (label: 'Configuration', icon: Icons.tune),
    (label: 'The week', icon: Icons.calendar_month_outlined),
    (label: 'The trail', icon: Icons.receipt_long_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(roleProvider);

    return Scaffold(
      backgroundColor: ZarColors.ground,
      body: AsyncBlock<String?>(
        value: role,
        builder: (held) {
          if (held == null) return const _NoRole();
          return Row(
            children: [
              _Rail(
                held: held,
                section: _section,
                sections: _sections,
                onSelect: (index) => setState(() => _section = index),
              ),
              const VerticalDivider(
                width: ZarLayout.hairline,
                color: ZarColors.hairline,
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ConsoleSpace.maxContentWidth,
                    ),
                    child: switch (_section) {
                      0 => const ConfigurationScreen(),
                      1 => const ScheduleScreen(),
                      _ => const TrailScreen(),
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.held,
    required this.section,
    required this.sections,
    required this.onSelect,
  });

  final String held;
  final int section;
  final List<({String label, IconData icon})> sections;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: ConsoleSpace.railWidth,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZarSpace.lg,
            ZarSpace.xl,
            ZarSpace.lg,
            ZarSpace.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ekipa console', style: ZarType.bodyStrong),
              const SizedBox(height: ZarSpace.xxs),
              // The role, always on screen. An operator who thinks they are an
              // owner is an operator who will be surprised by a refusal.
              Text(held.toUpperCase(), style: ConsoleType.chip),
            ],
          ),
        ),
        for (var i = 0; i < sections.length; i++)
          _RailItem(
            label: sections[i].label,
            icon: sections[i].icon,
            selected: i == section,
            onTap: () => onSelect(i),
          ),
        const Spacer(),
        const Padding(
          padding: EdgeInsets.all(ZarSpace.lg),
          child: Text(
            'Every action here is logged with your id and your reason.',
            style: ConsoleType.note,
          ),
        ),
      ],
    ),
  );
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: ZarLayout.minTapTarget,
      padding: const EdgeInsets.symmetric(horizontal: ZarSpace.lg),
      color: selected ? ZarColors.surface : null,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? ZarColors.ink : ZarColors.inkMuted,
          ),
          const SizedBox(width: ZarSpace.sm),
          // Expanded, because the rail is a fixed 232px and a section name is
          // not. "Configuration" already fills it at the default text size, so
          // the next name added would have overflowed rather than truncated.
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: ZarType.label.copyWith(
                color: selected ? ZarColors.ink : ZarColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// What somebody with a valid login and no console role sees.
class _NoRole extends StatelessWidget {
  const _NoRole();

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: ZarLayout.maxContentWidth),
      child: const Padding(
        padding: EdgeInsets.all(ZarSpace.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The database does not recognise you here',
              style: ZarType.title,
            ),
            SizedBox(height: ZarSpace.md),
            Text(
              'Your sign-in worked. The console role did not come back, which '
              'means one of two things: you have no row in admin_roles, or '
              'this session has not completed a second factor.',
              style: ZarType.body,
            ),
            SizedBox(height: ZarSpace.md),
            Text(
              'The second one is the common case, and it is deliberate — MFA '
              'is checked by Postgres, not by this screen, so signing in again '
              'without it will produce exactly this page.',
              style: ConsoleType.note,
            ),
          ],
        ),
      ),
    ),
  );
}
