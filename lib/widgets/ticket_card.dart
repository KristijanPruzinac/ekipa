import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';

/// A physical paper ticket: warm cream stock (real paper texture), a soft
/// drop shadow, and scalloped top/bottom edges like a torn stub. This is the
/// tactile half of the design — the "arrival/paper" world — set against the
/// cool digital sky behind it.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(EkipaSpace.xl),
    this.scallop = true,
  });

  final Widget child;
  final EdgeInsets padding;

  /// Scalloped top & bottom edges (the ticket look). When false, a plain
  /// rounded paper card.
  final bool scallop;

  @override
  Widget build(BuildContext context) {
    final clipper = _TicketClipper(scallop: scallop);
    return PhysicalShape(
      clipper: clipper,
      color: const Color(0xFFF3EAD7), // warm cream base, shows if texture fails
      shadowColor: Colors.black.withValues(alpha: 0.5),
      elevation: 14,
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/textures/paper.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Color(0x14000000), BlendMode.multiply),
          ),
        ),
        child: Padding(
          padding: padding.add(EdgeInsets.symmetric(vertical: scallop ? 6 : 0)),
          child: child,
        ),
      ),
    );
  }
}

/// A dashed perforation line, the divider between ticket sections.
class TicketPerforation extends StatelessWidget {
  const TicketPerforation({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(painter: _DashPainter(), size: Size.infinite),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = EkipaColors.paperLine
      ..strokeWidth = 1.4;
    const dash = 5.0, gap = 5.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TicketClipper extends CustomClipper<Path> {
  _TicketClipper({required this.scallop});

  final bool scallop;

  @override
  Path getClip(Size size) {
    const radius = 20.0; // corner radius when not scalloping
    if (!scallop) {
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(radius),
        ));
    }

    const r = 7.0; // scallop radius
    final path = Path();
    final nTop = (size.width / (2 * r)).floor().clamp(1, 999);
    final segTop = size.width / nTop;

    // Top edge: semicircular notches cut downward into the card.
    path.moveTo(0, 0);
    for (var i = 0; i < nTop; i++) {
      final x = segTop * (i + 1);
      path.arcToPoint(
        Offset(x, 0),
        radius: Radius.circular(segTop / 2),
        clockwise: false,
      );
    }
    // Right edge straight down.
    path.lineTo(size.width, size.height);
    // Bottom edge: notches cut upward, going right -> left.
    for (var i = 0; i < nTop; i++) {
      final x = size.width - segTop * (i + 1);
      path.arcToPoint(
        Offset(x, size.height),
        radius: Radius.circular(segTop / 2),
        clockwise: false,
      );
    }
    // Left edge back up.
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _TicketClipper oldDelegate) =>
      oldDelegate.scallop != scallop;
}
