import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_gestion_ventes/models/alert.dart';
import 'package:immora_mobile/module_gestion_ventes/providers/alert_provider.dart';
import 'package:immora_mobile/module_gestion_ventes/screens/alert_detail_screen.dart';
import 'package:immora_mobile/module_gestion_ventes/widgets/sales_widgets.dart';

/// « Alertes » [alertList] — M4 : les anomalies détectées par
/// `lib/module_gestion_ventes/ai/anomaly_detector.dart`, les plus graves d'abord, avec les
/// compteurs « Toutes · N / Non lues · N ».
class AlertListScreen extends StatefulWidget {
  const AlertListScreen({super.key, required this.agencyId});

  final int agencyId;

  @override
  State<AlertListScreen> createState() => _AlertListScreenState();
}

class _AlertListScreenState extends State<AlertListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<AlertProvider>().load(widget.agencyId));
  }

  Future<void> _markAllRead() async {
    final provider = context.read<AlertProvider>();
    final ok = await provider.markAllRead();
    if (!mounted || !ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toutes les alertes sont marquées comme lues.')));
  }

  Future<void> _openDetail(Alert alert) async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AlertDetailScreen(alert: alert)));
    if (mounted) await context.read<AlertProvider>().load(widget.agencyId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final alerts = provider.agencyId == widget.agencyId ? provider.alerts : <Alert>[];
    final counts = provider.counts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Alertes', actions: [
        IconButton(
          tooltip: 'Tout marquer comme lu',
          icon: const Icon(Icons.check),
          onPressed: counts.unread == 0 || provider.isSaving ? null : _markAllRead,
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: () => provider.load(widget.agencyId),
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          children: [
            FilterChipsRow<(AlertSeverity?, bool)>(
              selected: (provider.severityFilter, provider.unreadOnly),
              onSelected: (f) =>
                  context.read<AlertProvider>().setFilter(severity: f.$1, unread: f.$2),
              options: [
                ((null, false), 'Toutes · ${counts.total}'),
                ((null, true), 'Non lues · ${counts.unread}'),
                ((AlertSeverity.high, false), AlertSeverity.high.label),
                ((AlertSeverity.medium, false), AlertSeverity.medium.label),
                ((AlertSeverity.low, false), AlertSeverity.low.label),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                if (provider.errorMessage != null && !provider.isSaving) ...[
                  MessageBanner(type: BannerType.error, message: provider.errorMessage!),
                  const SizedBox(height: 10),
                ],
                if (provider.isLoading && alerts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (alerts.isEmpty)
                  WhiteCard(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      counts.total == 0
                          ? 'Aucune anomalie détectée pour le moment.'
                          : 'Aucune alerte ne correspond à ce filtre.',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  )
                else
                  WhiteCard(
                    child: Column(children: [
                      for (var i = 0; i < alerts.length; i++) ...[
                        _AlertRow(alert: alerts[i], onTap: () => _openDetail(alerts[i])),
                        if (i < alerts.length - 1)
                          const Divider(
                              height: 1, indent: 14, endIndent: 14, color: AppColors.border),
                      ],
                    ]),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, required this.onTap});

  final Alert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = toneForAlertSeverity(alert.severity);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          IconTile(iconForAlertType(alert.type), tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (!alert.isRead) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration:
                        const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(alert.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, height: 1.25)),
                ),
              ]),
              if (alert.subtitle != null) ...[
                const SizedBox(height: 3),
                Text(alert.subtitle!,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          StatusBadge(alert.severity.label, tone),
        ]),
      ),
    );
  }
}
