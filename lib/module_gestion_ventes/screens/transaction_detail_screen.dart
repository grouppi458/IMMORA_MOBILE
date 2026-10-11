import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_gestion_biens/screens/property_detail_screen.dart';
import 'package:immora_mobile/module_gestion_ventes/models/payment.dart';
import 'package:immora_mobile/module_gestion_ventes/models/transaction.dart';
import 'package:immora_mobile/module_gestion_ventes/models/transaction_details.dart';
import 'package:immora_mobile/module_gestion_ventes/providers/transaction_provider.dart';
import 'package:immora_mobile/module_gestion_ventes/screens/payment_form_screen.dart';
import 'package:immora_mobile/module_gestion_ventes/screens/transaction_form_screen.dart';
import 'package:immora_mobile/module_gestion_ventes/widgets/sales_widgets.dart';

/// Vert foncé du bandeau « Transaction terminée » (maquette [txCompleted]).
const _doneGreen = Color(0xFF1B5E20);

enum _StepState { done, current, future }

/// « Transaction #1042 » [txDetail] / [txCompleted] — M4 : avancement en
/// 4 étapes, informations du dossier, échéancier de paiements et actions
/// (signer, terminer, annuler, ajouter un paiement).
class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final int transactionId;

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  TransactionDetails? _details;
  List<Payment> _payments = [];
  double _paid = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<TransactionProvider>();
    try {
      final details = await provider.details(widget.transactionId);
      final payments = await provider.payments(widget.transactionId);
      final paid = await provider.paidAmount(widget.transactionId);
      if (!mounted) return;
      setState(() {
        _details = details;
        _payments = payments;
        _paid = paid;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger la transaction.';
      });
    }
  }

  /// Exécute une action du cycle de vie puis rafraîchit l'écran.
  Future<void> _act(
      Future<bool> Function(TransactionProvider p) run, String success) async {
    final provider = context.read<TransactionProvider>();
    final ok = await run(provider);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Erreur')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.success, content: Text(success)));
    await _load();
  }

  Future<void> _cancelTransaction() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la transaction'),
        content: TextField(
          controller: reasonCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Motif de l’annulation',
            hintText: 'Indisponibilité, désaccord sur le prix…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Retour')),
          FilledButton(
            onPressed: () {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.of(ctx).pop(reason);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    await _act((p) => p.cancel(widget.transactionId, reason: reason), 'Transaction annulée');
  }

  Future<void> _openEdit() async {
    final details = _details;
    if (details == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TransactionFormScreen(
            agencyId: details.transaction.agencyId, editing: details)));
    if (mounted) await _load();
  }

  Future<void> _openPayment([Payment? payment]) async {
    final details = _details;
    if (details == null) return;
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => PaymentFormScreen(transaction: details, payment: payment)));
    if (saved == true && mounted) await _load();
  }

  // -------------------------------------------------------------- Avancement

  List<(String, String, _StepState)> _steps(TransactionDetails d) {
    final tx = d.transaction;
    final soldWord = tx.dealType == DealType.sale ? 'Vendu' : 'Loué';
    final status = tx.status;
    final done = switch (status) {
      TransactionStatus.draft => const [_StepState.current, _StepState.future, _StepState.future, _StepState.future],
      TransactionStatus.ongoing => const [_StepState.done, _StepState.current, _StepState.future, _StepState.future],
      TransactionStatus.signed => const [_StepState.done, _StepState.done, _StepState.current, _StepState.future],
      TransactionStatus.completed => const [_StepState.done, _StepState.done, _StepState.done, _StepState.done],
      // Annulée : seuls les prémices restent (le motif s'affiche au-dessus).
      TransactionStatus.cancelled => const [_StepState.done, _StepState.future, _StepState.future, _StepState.future],
    };
    return [
      ('Brouillon créé', formatDate(tx.createdAt), done[0]),
      (
        'En cours',
        done[1] == _StepState.done
            ? formatDate(tx.startDate)
            : done[1] == _StepState.current
                ? (_paid > 0 ? 'Négociation · acompte reçu' : 'Négociation en cours')
                : 'Négociation',
        done[1],
      ),
      (
        'Signée',
        done[2] == _StepState.done
            ? '${formatDate(tx.signedAt ?? tx.startDate)}'
                '${tx.contractPath == null ? '' : ' · contrat joint'}'
            : done[2] == _StepState.current
                ? 'Contrat signé'
                : 'Contrat à signer',
        done[2],
      ),
      (
        'Terminée',
        done[3] == _StepState.done
            ? '${formatDate(tx.endDate ?? tx.startDate)} · bien → $soldWord'
            : 'Le bien passera en « $soldWord »',
        done[3],
      ),
    ];
  }

  // ------------------------------------------------------------------ Build

  @override
  Widget build(BuildContext context) {
    final d = _details;
    final tx = d?.transaction;
    final title = tx == null ? 'Transaction' : 'Transaction ${tx.displayRef}';
    final steps = d == null ? const <(String, String, _StepState)>[] : _steps(d);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, title, actions: [
        PopupMenuButton<String>(
          tooltip: 'Options',
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'edit') {
              _openEdit();
            } else if (value == 'property' && tx != null) {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PropertyDetailScreen(propertyId: tx.propertyId)));
            }
          },
          itemBuilder: (_) => [
            if (tx != null && !tx.isFinal)
              const PopupMenuItem(value: 'edit', child: Text('Modifier la transaction')),
            if (tx != null)
              const PopupMenuItem(value: 'property', child: Text('Voir le bien')),
          ],
        ),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || d == null || tx == null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: MessageBanner(
                      type: BannerType.error,
                      message: _error ?? 'Transaction introuvable.'),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _HeroCard(details: d),
                      const SizedBox(height: 12),
                      if (tx.status == TransactionStatus.cancelled)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: MessageBanner(
                              type: BannerType.error,
                              message:
                                  'Transaction annulée · ${tx.cancelReason ?? 'sans motif'}'),
                        ),
                      if (tx.status == TransactionStatus.completed) ...[
                        _CompletedBanner(rent: tx.dealType == DealType.rent),
                        const SizedBox(height: 12),
                      ],
                      WhiteCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Progression',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            for (var i = 0; i < steps.length; i++)
                              _ProgressStep(
                                title: steps[i].$1,
                                caption: steps[i].$2,
                                state: steps[i].$3,
                                last: i == steps.length - 1,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      WhiteCard(
                        child: Column(children: [
                          InfoRow('Client', tx.clientName),
                          const Divider(height: 1, thickness: 1, color: AppColors.border),
                          if (d.agentName != null) ...[
                            InfoRow('Agent',
                                '${d.agentName} (${formatRate(tx.commissionRate)} %)'),
                            const Divider(height: 1, thickness: 1, color: AppColors.border),
                          ],
                          InfoRow('Commission', '${formatNumber(tx.commissionAmount)} TND',
                              valueColor: AppColors.gold),
                          if (tx.status != TransactionStatus.completed &&
                              tx.status != TransactionStatus.cancelled) ...[
                            const Divider(height: 1, thickness: 1, color: AppColors.border),
                            InfoRow('Début', formatDate(tx.startDate)),
                          ],
                          const Divider(height: 1, thickness: 1, color: AppColors.border),
                          InfoRow('Contrat', tx.contractPath ?? '—',
                              valueColor: AppColors.primary),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      SectionTitle('Paiements',
                          action: tx.isFinal ? null : '+ Ajouter',
                          onAction: () => _openPayment()),
                      const SizedBox(height: 6),
                      if (_payments.isEmpty)
                        WhiteCard(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Aucune échéance pour l’instant.'
                            '${tx.isFinal ? '' : ' Ajoutez la première avec « + Ajouter ».'}',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      else
                        WhiteCard(
                          child: Column(children: [
                            for (var i = 0; i < _payments.length; i++) ...[
                              _PaymentRow(
                                payment: _payments[i],
                                onTap: tx.isFinal ? null : () => _openPayment(_payments[i]),
                              ),
                              if (i < _payments.length - 1)
                                const Divider(
                                    height: 1,
                                    indent: 14,
                                    endIndent: 14,
                                    color: AppColors.border),
                            ],
                          ]),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
      bottomNavigationBar: _bottomBar(tx),
    );
  }

  Widget? _bottomBar(Transaction? tx) {
    if (tx == null || tx.status == TransactionStatus.completed || tx.status == TransactionStatus.cancelled) {
      return null;
    }
    final (String label, Future<bool> Function(TransactionProvider p) run, String success) action =
        switch (tx.status) {
      TransactionStatus.draft => (
          'Marquer en cours',
          (p) => p.activate(widget.transactionId),
          'Transaction en cours'
        ),
      TransactionStatus.ongoing => (
          'Marquer signée',
          (p) => p.sign(widget.transactionId),
          tx.dealType == DealType.sale
              ? 'Transaction signée · bien passé en « Vendu »'
              : 'Transaction signée · bien passé en « Loué »'
        ),
      _ => (
          'Marquer terminée',
          (p) => p.complete(widget.transactionId),
          tx.dealType == DealType.rent
              ? 'Transaction terminée · bien libéré'
              : 'Transaction terminée'
        ),
    };

    return SafeArea(
      child: Container(
        color: AppColors.background,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Row(children: [
          if (tx.status != TransactionStatus.signed) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelTransaction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: Color(0xFFE7BEBE)),
                  shape: const StadiumBorder(),
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: FilledButton(
              onPressed: () => _act(action.$2, action.$3),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const StadiumBorder(),
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text(action.$1),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Carte bleu marine de l'en-tête (bien · type, badge de statut, montant).
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.details});

  final TransactionDetails details;

  @override
  Widget build(BuildContext context) {
    final tx = details.transaction;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              '${details.propertyTitle} · ${tx.dealType.label}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          StatusBadge(tx.status.label, toneForTransactionStatus(tx.status)),
        ]),
        const SizedBox(height: 10),
        Text(tx.amountLabel,
            style: const TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Bandeau vert foncé « Transaction terminée · bien passé en « Vendu » ».
class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner({required this.rent});

  final bool rent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _doneGreen, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Transaction terminée · bien passé en « ${rent ? 'Loué' : 'Vendu'} »',
            style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3),
          ),
        ),
      ]),
    );
  }
}

/// Étape de la progression : pastille (faite / en cours / à venir) + ligne.
class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.title,
    required this.caption,
    required this.state,
    required this.last,
  });

  final String title;
  final String caption;
  final _StepState state;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final circle = switch (state) {
      _StepState.done => Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.check, color: Colors.white, size: 15),
        ),
      _StepState.current => Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
          child: const Icon(Icons.schedule, color: Colors.white, size: 15),
        ),
      _StepState.future => Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 2),
          ),
        ),
    };

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 26,
          child: Column(children: [
            circle,
            if (!last)
              Expanded(
                child: Container(
                  width: 2.5,
                  color: state == _StepState.done ? AppColors.primary : AppColors.border,
                ),
              ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(caption,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Ligne de l'échéancier : pastille d'état, libellé · montant, échéance.
class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, this.onTap});

  final Payment payment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = payment.status;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          IconTile(iconForPaymentStatus(status), toneForPaymentStatus(status), size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${payment.label} · ${formatNumber(payment.amount)} TND',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                payment.subtitle,
                style: TextStyle(
                    fontSize: 12.5,
                    color: status == PaymentStatus.late
                        ? AppColors.error
                        : AppColors.textMuted),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          StatusBadge(status.label, toneForPaymentStatus(status)),
        ]),
      ),
    );
  }
}
