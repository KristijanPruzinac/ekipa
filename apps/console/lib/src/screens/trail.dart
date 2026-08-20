import 'package:console/src/data/records.dart';
import 'package:console/src/state/providers.dart';
import 'package:console/src/theme/console_theme.dart';
import 'package:console/src/widgets/console_chrome.dart';
import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The audit trail.
///
/// **Intention — the trail is readable by everyone who can see the console at
/// all, including the people it records.** A log only its writer can read
/// protects nobody, and `12_CONSOLE.md` §2 wants "I did not go looking" to be a
/// fact rather than a claim. A fact nobody can check is a claim again, so a
/// viewer — the weakest role — can read this screen in full.
///
/// **Operators appear as `OP-7F3A`.** Not because operators deserve privacy
/// from each other, but because the trail is the one console surface most
/// likely to be read *about* a colleague, and the questions it needs to answer
/// — was this the same person twice, did anybody give a reason — do not require
/// a name. See `AuditRecord.actorLabel`.
///
/// Nothing on this screen can delete or edit a row, and that is a property of
/// the database rather than of this file: `admin_audit` carries no update or
/// delete grant for any console role, so an operator cannot erase their own
/// trail even with a client they wrote themselves (AC-8).
class TrailScreen extends ConsumerWidget {
  /// Creates the screen.
  const TrailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(ZarSpace.xl),
    children: [
      ConsoleSection(
        title: 'The trail',
        lede: 'Append-only. Nothing here can be edited or removed.',
        child: AsyncBlock<List<AuditRecord>>(
          value: ref.watch(auditProvider),
          builder: (entries) => ConsoleTable(
            columns: const [
              (label: 'When', flex: 3, numeric: false),
              (label: 'Who', flex: 2, numeric: false),
              (label: 'Did what', flex: 3, numeric: false),
              (label: 'To', flex: 3, numeric: false),
              (label: 'Why', flex: 6, numeric: false),
            ],
            rows: [
              for (final entry in entries)
                [
                  Text(_stamp(entry.occurredAt), style: ConsoleType.value),
                  Text(entry.actorLabel, style: ConsoleType.chip),
                  Text(entry.action, style: ConsoleType.keyName),
                  Text(
                    entry.target == null ? '—' : _short(entry.target!),
                    style: ConsoleType.chip,
                  ),
                  // The operator's own sentence, printed as typed. This column
                  // is the whole reason the reason field is mandatory.
                  Verbatim(entry.reason),
                ],
            ],
          ),
        ),
      ),
      const SizedBox(height: ConsoleSpace.sectionGap),
    ],
  );
}

String _stamp(DateTime when) {
  final utc = when.toUtc();
  return '${utc.year}-${_two(utc.month)}-${_two(utc.day)} '
      '${_two(utc.hour)}:${_two(utc.minute)}Z';
}

String _two(int value) => value.toString().padLeft(2, '0');

String _short(String id) => id.length >= 8 ? id.substring(0, 8) : id;
