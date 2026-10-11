import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_gestion_annonces/models/app_notification.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/matching_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/listing_detail_screen.dart';

/// « 1 h », « 3 j »… depuis [millis].
String timeAgo(int millis) {
  final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(millis));
  if (diff.inMinutes < 1) return 'à l’instant';
  if (diff.inHours < 1) return '${diff.inMinutes} min';
  if (diff.inDays < 1) return '${diff.inHours} h';
  return '${diff.inDays} j';
}

/// « Notifications » [clientNotifs] — alertes « nouvelle annonce pour vous »
/// (BF5.9) et confirmations, annulations et comptes rendus de visite (M6).
class ClientNotificationsScreen extends StatefulWidget {
  const ClientNotificationsScreen({super.key});

  @override
  State<ClientNotificationsScreen> createState() => _ClientNotificationsScreenState();
}

class _ClientNotificationsScreenState extends State<ClientNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => context.read<MatchingProvider>().refreshNotifications());
  }

  Future<void> _open(AppNotification n) async {
    final matching = context.read<MatchingProvider>();
    await matching.markRead(n);
    if (!mounted || n.listingId == null) return;
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: n.listingId!)));
  }

  @override
  Widget build(BuildContext context) {
    final matching = context.watch<MatchingProvider>();
    final list = matching.notifications;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Notifications', actions: [
        IconButton(
          tooltip: 'Tout marquer comme lu',
          icon: const Icon(Icons.done_all),
          onPressed: matching.unreadCount == 0 ? null : matching.markAllRead,
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: matching.refreshNotifications,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (list.isEmpty)
            const WhiteCard(
              padding: EdgeInsets.all(20),
              child: Text('Aucune notification pour l’instant.',
                  style: TextStyle(color: AppColors.textMuted)),
            )
          else
            WhiteCard(
              child: Column(children: [
                for (final n in list) ...[
                  _NotificationTile(notification: n, onTap: () => _open(n)),
                  if (n != list.last) const Divider(height: 1, color: AppColors.background),
                ],
              ]),
            ),
        ]),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final (IconData icon, Tone tone) = switch (n.type) {
      AppNotification.newListing => (Icons.auto_awesome, toneGold),
      AppNotification.visitConfirmed => (Icons.check_circle_outline, toneGreen),
      AppNotification.visitCancelled => (Icons.cancel_outlined, toneRed),
      AppNotification.visitDone => (Icons.task_alt, toneBlue),
      _ => (Icons.notifications_none, toneBlue),
    };
    return ListTile(
      onTap: onTap,
      tileColor: n.isRead ? null : const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: tone.$1, shape: BoxShape.circle),
        child: Icon(icon, color: tone.$2, size: 20),
      ),
      title: Text(n.title,
          style: TextStyle(
              fontSize: 14, fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700)),
      subtitle: Text(n.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(timeAgo(n.createdAt),
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        if (!n.isRead) ...[
          const SizedBox(height: 6),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
          ),
        ],
      ]),
    );
  }
}
