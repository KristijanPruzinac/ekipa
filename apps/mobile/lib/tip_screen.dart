import 'package:flutter/material.dart';
import 'api.dart';
import 'design.dart';
import 'models.dart';

class TipScreen extends StatefulWidget {
  const TipScreen({super.key, required this.api});
  final WagzApi api;
  @override
  State<TipScreen> createState() => _TipScreenState();
}

class _TipScreenState extends State<TipScreen> {
  final formKey = GlobalKey<FormState>();
  final note = TextEditingController();
  final url = TextEditingController();
  bool busy = false;
  bool sent = false;
  String? error;

  @override
  void dispose() {
    note.dispose();
    url.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.submitTip(note: note.text, url: url.text);
      if (mounted) setState(() => sent = true);
    } catch (err) {
      if (mounted) setState(() => error = err.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(56),
        title: const Text('Dojavi događaj', maxLines: 2),
        automaticallyImplyLeading: !busy,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('OD EKIPE ZA EKIPU'),
              const SizedBox(height: 16),
              Text(
                sent ? 'Dobra dojava.\nHvala!' : 'Što se sprema\nu gradu?',
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 36,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 24),
              if (sent) ...[
                const Notice(
                  'Tvoja dojava je spremljena za sljedeću dnevnu provjeru. Pronađeni događaj pregledat ćemo prije objave.',
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  label: const Text('Natrag na događaje'),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ] else
                Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Napiši što znaš — naziv, mjesto, datum ili samo dobar trag. '
                        'Ne trebaš imati sve detalje.',
                        style: TextStyle(color: muted, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: note,
                        enabled: !busy,
                        minLines: 5,
                        maxLines: 8,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Tvoja dojava *',
                          hintText: 'Npr. u subotu je koncert u…',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) => (value?.trim().length ?? 0) < 3
                            ? 'Napiši barem 3 znaka.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: url,
                        enabled: !busy,
                        maxLength: 2048,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Poveznica na najavu',
                          hintText: 'https://…',
                          helperText: 'Neobavezno',
                        ),
                        validator: (value) =>
                            value!.trim().isNotEmpty &&
                                safeLink(value.trim()) == null
                            ? 'Unesi valjanu http ili https poveznicu.'
                            : null,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Notice(error!, error: true),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: busy ? null : submit,
                          icon: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.north_east),
                          label: Text(busy ? 'Šaljemo…' : 'Pošalji dojavu'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Bez prijave. Dojave provjeravamo uz dnevni dohvat događaja. Svaki prijedlog pregledamo prije objave. '
                        'Pošalji informacije o događaju, bez osobnih podataka.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
