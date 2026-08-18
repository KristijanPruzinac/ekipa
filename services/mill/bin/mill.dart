/// Entry point for the worker.
///
/// Zone 2 in the trust model (`docs/v3/11_SECURITY.md` §3): no inbound port, no
/// URL, no listener. It is invoked by a scheduler, does its work, and exits —
/// which is why a pull-based GitHub Actions cron satisfies D9 more completely
/// than an authenticated HTTP endpoint would.
///
/// Populated from chunk 5 onward.
void main(List<String> args) {
  throw UnimplementedError(
    'The mill has no jobs yet. See docs/v3/08_ROADMAP.md.',
  );
}
