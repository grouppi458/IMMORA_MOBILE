import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_gestion_ventes/models/alert.dart';
import 'package:immora_mobile/module_gestion_ventes/models/transaction_details.dart';
import 'package:immora_mobile/module_gestion_ventes/providers/alert_provider.dart';
import 'package:immora_mobile/module_gestion_ventes/providers/transaction_provider.dart';
import 'package:immora_mobile/module_gestion_ventes/screens/transaction_detail_screen.dart';
import 'package:immora_mobile/module_gestion_ventes/widgets/sales_widgets.dart';

/// « Alerte » [alertDetail] — M4 : le détail d'une anomalie (carte à accent,
/// lignes de l'analyse, actions « Ignorer » / « Voir la transaction »).
class AlertDetailScreen extends StatefulWidget {
  const AlertDetailScreen({super.key, required this.alert});

  final Alert alert;

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  late bool _read = widget.alert.isRead;
  TransactionDetails? _transaction;

  @override
  void initState() {
    super.initState();
    final id = widget.alert.transactionId;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final d = await context.read<TransactionProvider>().details(id);
        if (mounted) setState(() => _transaction = d);
      } catch (_) {
        // La ligne « Transaction » se rabat sur la référence seule.
      }
    });
  }

  Future<void> _markRead() async {
    final ok = await context.read<AlertProvider>().markRead(widget.alert.id!);
    if (!mounted || !ok) return;
    setState(() => _read = true);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Alerte marquée comme lue.')));
  }

  Future<void> _ignore() async {
    final ok = await confirmDialog(
      context,
      title: 'Ignorer cette alerte ?',
      message: 'Elle sera retirée de la liste. Le détecteur la recréera si '
          'l’anomalie persiste à la prochaine analyse.',
      confirmLabel: 'Ignorer',
    );
    if (!ok || !mounted) return;
    final done = await context.read<AlertProvider>().ignore(widget.alert.id!);
    if (!mounted || !done) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Alerte ignorée.')));
    Navigator.of(context).pop();
  }

  void _openTransaction() {
    final id = widget.alert.transactionId;
    if (id == null) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(transactionId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final tone = toneForAlertSeverity(alert.severity);
    final accent = colorForAlertSeverity(alert.severity);
    final txId = alert.transactionId;
    final txLabel = _transaction != null
        ? '${_transaction!.propertyTitle} · ${_transaction!.transaction.displayRef}'
        : txId != null
            ? 'Transaction #$txId'
            : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Alerte'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(
                                child: Text(alert.title,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        height: 1.3)),
                              ),
                              const SizedBox(width: 10),
                              StatusBadge(alert.severity.label, tone),
                            ]),
                            const SizedBox(height: 10),
                            Text(alert.description,
                                style: const TextStyle(
                                    fontSize: 13.5, color: AppColors.textMuted, height: 1.45)),
                          ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          WhiteCard(
            child: Column(children: [
              if (txLabel != null) ...[
                InfoRow('Transaction', txLabel,
                    valueColor: AppColors.primary,
                    onTap: _openTransaction,
                    valueIcon: Icons.chevron_right),
                const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
              ],
              for (final entry in alert.details.entries) ...[
                InfoRow(entry.key, entry.value,
                    // Les valeurs qui dépassent un seuil (« > 30 % », « seuil 2,5 »)
                    // sont affichées en rouge, comme la maquette.
                    valueColor:
                        entry.value.contains('(>') || entry.value.contains('(seuil')
                            ? AppColors.error
                            : null),
                const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  const Text('Sévérité',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const Spacer(),
                  StatusBadge(alert.severity.name, tone),
                ]),
              ),
              const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.border),
              InfoRow(
                  'Créée', '${formatDate(alert.createdAt)} · ${formatTime(alert.createdAt)}'),
            ]),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _ignore,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDark,
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size.fromHeight(46),
                ),
                child: const Text('Ignorer'),
              ),
            ),
            if (txId != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _openTransaction,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: const Text('Voir la transaction'),
                ),
              ),
            ],
          ]),
          if (!_read)
            Center(
              child: TextButton.icon(
                onPressed: _markRead,
                icon: const Icon(Icons.check, size: 18, color: AppColors.primary),
                label: const Text('Marquer comme lue',
                    style: TextStyle(
                        color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}
