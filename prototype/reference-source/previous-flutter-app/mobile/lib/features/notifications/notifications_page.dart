import 'dart:async';
import 'package:flutter/material.dart';
import '../../auth/profile.dart';
import '../../core/api.dart';
import '../shared/data_state.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage(
      {super.key, required this.api, required this.profile});
  final SchoolApi api;
  final Profile profile;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  NotificationData? _data;
  String? _error;
  bool _loading = true;
  final Set<int> _marking = {};
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.notifications(widget.profile.id);
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'تعذّر تحميل الرسائل والإعلانات.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _markRead(MessageRecord message) async {
    if (message.readAt != null || _marking.contains(message.id)) return;
    setState(() => _marking.add(message.id));
    try {
      await widget.api.markMessageRead(message.id, widget.profile.id);
      if (!mounted) return;
      final current = _data!;
      final messages = current.messages
          .map((item) => item.id == message.id
              ? MessageRecord(
                  id: item.id,
                  senderName: item.senderName,
                  subject: item.subject,
                  body: item.body,
                  createdAt: item.createdAt,
                  readAt: DateTime.now().toUtc().toIso8601String())
              : item)
          .toList();
      setState(() => _data = NotificationData(
          messages: messages,
          announcements: current.announcements,
          events: current.events));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _marking.remove(message.id));
    }
  }

  @override
  Widget build(BuildContext context) => DataStateView(
      loading: _loading,
      error: _error,
      onRetry: _load,
      child: Builder(builder: (context) {
        final data = _data!;
        return DefaultTabController(
            length: 3,
            child: Column(children: [
              const PageHeader(
                  title: 'الرسائل والإعلانات',
                  subtitle: 'رسائلك وإعلانات مدرستك والفعاليات القادمة.',
                  icon: Icons.notifications_outlined),
              TabBar(tabs: [
                Tab(
                    text:
                        'الرسائل (${data.messages.where((item) => item.readAt == null).length})'),
                const Tab(text: 'الإعلانات'),
                const Tab(text: 'الفعاليات')
              ]),
              Expanded(
                  child: TabBarView(children: [
                _messages(data),
                _announcements(data),
                _events(data)
              ])),
            ]));
      }));
  Widget _messages(NotificationData data) => data.messages.isEmpty
      ? const EmptyState(icon: Icons.mail_outline, title: 'لا رسائل')
      : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: data.messages.length,
          itemBuilder: (context, index) {
            final item = data.messages[index];
            return Card(
                child: ListTile(
              leading: Icon(item.readAt != null
                  ? Icons.drafts_outlined
                  : Icons.mark_email_unread_outlined),
              title: Text(item.subject,
                  style: TextStyle(
                      fontWeight: item.readAt != null
                          ? FontWeight.normal
                          : FontWeight.bold)),
              subtitle: Text('${item.senderName}\n${item.body}'),
              isThreeLine: true,
              trailing: item.readAt != null
                  ? null
                  : _marking.contains(item.id)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : TextButton(
                          onPressed: () => _markRead(item),
                          child: const Text('تُقرأ')),
            ));
          });
  Widget _announcements(NotificationData data) => data.announcements.isEmpty
      ? const EmptyState(icon: Icons.campaign_outlined, title: 'لا إعلانات')
      : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: data.announcements.length,
          itemBuilder: (context, index) {
            final item = data.announcements[index];
            return Card(
                child: ListTile(
                    leading: const Icon(Icons.campaign_outlined),
                    title: Text(item.title),
                    subtitle: Text('${item.body}\n${item.createdAt}'),
                    isThreeLine: true));
          });
  Widget _events(NotificationData data) => data.events.isEmpty
      ? const EmptyState(icon: Icons.event_outlined, title: 'لا فعاليات قادمة')
      : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: data.events.length,
          itemBuilder: (context, index) {
            final item = data.events[index];
            return Card(
                child: ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: Text(item.title),
                    subtitle: Text('${item.date} · ${item.kind ?? 'فعالية'}'),
                    isThreeLine: true));
          });
}
