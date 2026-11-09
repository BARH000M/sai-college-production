import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api.dart';

class TutorSearchPage extends StatefulWidget {
  const TutorSearchPage({super.key, required this.api});
  final SchoolApi api;
  @override
  State<TutorSearchPage> createState() => _TutorSearchPageState();
}

class _TutorSearchPageState extends State<TutorSearchPage> {
  final _controller = TextEditingController();
  List<CorpusHit>? _hits;
  bool _busy = false;
  String? _error;
  String? _asked;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final term = _controller.text.trim();
    if (term.length < 2) {
      setState(() => _error = 'اكتب سؤالاً من حرفين على الأقل.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _hits = null;
      _asked = term;
    });
    try {
      final hits = await widget.api.searchCorpus(term);
      if (mounted) setState(() => _hits = hits);
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = e is ApiException ? e.message : 'تعذّر تنفيذ البحث');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('اسأل المعلّم', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      const Text('البحث في نصوص الدروس المنشورة داخل مدرستك فقط.',
          style: TextStyle(fontSize: 12, color: Colors.black54)),
      const SizedBox(height: 14),
      TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => unawaited(_search()),
          decoration: InputDecoration(
              labelText: 'سؤالك',
              hintText: 'اشرح لي قانون نيوتن الثاني',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _busy ? null : () => unawaited(_search())))),
      const SizedBox(height: 12),
      FilledButton.icon(
          onPressed: _busy ? null : () => unawaited(_search()),
          icon: _busy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome_outlined),
          label: Text(_busy ? 'جارٍ البحث…' : 'ابحث'),
          style:
              FilledButton.styleFrom(minimumSize: const Size.fromHeight(46))),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF9A3412)))
      ],
      if (_hits != null && _hits!.isEmpty) ...[
        const SizedBox(height: 16),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                    'لا مقطع مطابق لـ «$_asked». جرّب صياغة أقرب لكلمات الدرس، أو اطلب من المدرسة إثراء نص الدرس.',
                    style: const TextStyle(fontSize: 12.5, height: 1.6)))),
      ],
      if (_hits != null) ...[
        const SizedBox(height: 12),
        ..._hits!.map((hit) => Card(
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(hit.title,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold))),
                        Text('${(hit.similarity * 100).round()}%',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54))
                      ]),
                      const SizedBox(height: 6),
                      Text(hit.body,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.6,
                              color: Colors.black87)),
                    ])))),
      ],
    ]);
  }
}
