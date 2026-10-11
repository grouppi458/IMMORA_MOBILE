import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/auth_text_field.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_gestion_ventes/models/payment.dart';
import 'package:immora_mobile/module_gestion_ventes/models/transaction_details.dart';
import 'package:immora_mobile/module_gestion_ventes/providers/transaction_provider.dart';

/// « Paiement » [paymentForm] — M4 : ajout ou encaissement d'une échéance
/// (« Reste à payer », montant contrôlé contre l'attendu > 5 %, méthode,
/// statut), avec l'alerte « Paiement différent de l'attendu » en direct.
class PaymentFormScreen extends StatefulWidget {
  const PaymentFormScreen({super.key, required this.transaction, this.payment});

  final TransactionDetails transaction;
  final Payment? payment; // null = nouvelle échéance

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final _amountCtrl = TextEditingController();

  late DateTime _dueDate =
      widget.payment == null ? DateTime.now().add(const Duration(days: 30)) : _due(widget.payment!);
  late bool _paid = widget.payment?.paidDate != null;
  late DateTime? _paidDate = widget.payment?.paidDate == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(widget.payment!.paidDate!);
  late PaymentMethod? _method = widget.payment?.method ?? PaymentMethod.transfer;

  double _remaining = 0;
  bool _loadingRemaining = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.payment;
    if (p != null) _amountCtrl.text = formatNumber(p.amount);
    final provider = context.read<TransactionProvider>();
    provider
        .paidAmount(widget.transaction.transaction.id!)
        .then((paid) {
      if (!mounted) return;
      setState(() {
        _remaining = widget.transaction.transaction.amount - paid;
        _loadingRemaining = false;
      });
    });
  }

  DateTime _due(Payment p) => DateTime.fromMillisecondsSinceEpoch(p.dueDate);

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'));

  /// Écart en % entre le nouveau montant et l'échéance actuelle — au-delà de
  /// [anomalyPaymentGapPercent], la maquette avertit « alerte medium ».
  double? get _mismatchPercent {
    final current = widget.payment;
    final amount = _num(_amountCtrl);
    if (current == null || amount == null || amount <= 0) return null;
    return (amount - current.amount).abs() / amount * 100;
  }

  bool get _mismatchDetected => (_mismatchPercent ?? 0) > anomalyPaymentGapPercent;

  PaymentStatus get _status =>
      _paid ? PaymentStatus.paid : _dueDate.isBefore(DateTime.now()) ? PaymentStatus.late : PaymentStatus.pending;

  Future<void> _pickDate({required bool paidDate}) async {
    final initial = paidDate ? (_paidDate ?? DateTime.now()) : _dueDate;
    final chosen = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (chosen == null) return;
    setState(() {
      if (paidDate) {
        _paid = true;
        _paidDate = chosen;
      } else {
        _dueDate = chosen;
      }
    });
  }

  void _setStatus(PaymentStatus status) {
    setState(() {
      switch (status) {
        case PaymentStatus.paid:
          _paid = true;
          _paidDate ??= DateTime.now();
        case PaymentStatus.pending:
          _paid = false;
        case PaymentStatus.late:
          // « En retard » : l'échéance est dépassée (relancé le lendemain).
          _paid = false;
          if (!_dueDate.isBefore(DateTime.now())) {
            _dueDate = DateTime.now().subtract(const Duration(days: 1));
          }
      }
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if ((_num(_amountCtrl) ?? 0) <= 0) {
      setState(() => _error = 'Indiquez un montant supérieur à 0.');
      return;
    }
    final provider = context.read<TransactionProvider>();
    final amount = _num(_amountCtrl)!;
    final bool ok;
    if (widget.payment == null) {
      ok = await provider.insertPayment(
        widget.transaction.transaction.id!,
        amount: amount,
        dueDate: _dueDate,
        paidDate: _paid ? (_paidDate ?? DateTime.now()) : null,
        method: _paid ? _method : null,
      );
    } else {
      ok = await provider.updatePayment(
        widget.payment!.id!,
        amount: amount,
        dueDate: _dueDate,
        paid: _paid,
        paidDate: _paidDate,
        method: _method,
      );
    }
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = provider.errorMessage);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.success,
      content: Text(_paid ? 'Paiement encaissé' : 'Échéance enregistrée'),
    ));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Paiement', close: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WhiteCard(
            child: Column(children: [
              InfoRow('Transaction', widget.transaction.displayTitle),
              const Divider(height: 1, thickness: 1, color: AppColors.border),
              InfoRow('Reste à payer',
                  _loadingRemaining ? '…' : '${formatNumber(_remaining)} TND',
                  valueColor: AppColors.gold),
            ]),
          ),
          const SizedBox(height: 14),
          AuthTextField(
            label: 'Montant (TND)',
            icon: Icons.paid_outlined,
            hint: '500 000',
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s.,]'))],
            errorText: _error,
            hasError: _error != null,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 14),
          _DateRow(
            label: 'Date d’échéance',
            value: formatDateNumeric(_dueDate),
            onTap: () => _pickDate(paidDate: false),
          ),
          const SizedBox(height: 14),
          _DateRow(
            label: 'Date de paiement',
            value: _paid ? formatDateNumeric(_paidDate ?? DateTime.now()) : 'Non payé',
            muted: !_paid,
            onTap: () => _pickDate(paidDate: true),
          ),
          const SizedBox(height: 14),
          ChoiceChipsField<PaymentMethod>(
            label: 'Méthode',
            options: [for (final m in PaymentMethod.values) (m, m.label)],
            selected: _method,
            onSelected: (m) => setState(() => _method = m),
          ),
          const SizedBox(height: 14),
          ChoiceChipsField<PaymentStatus>(
            label: 'Statut',
            options: [
              for (final s in [PaymentStatus.pending, PaymentStatus.paid, PaymentStatus.late])
                (s, s.label),
            ],
            selected: status,
            onSelected: _setStatus,
          ),
          if (_mismatchDetected) ...[
            const SizedBox(height: 14),
            MessageBanner(
              type: BannerType.warning,
              message: 'Montant différent de l’échéance attendue de plus de '
                  '${formatNumber(anomalyPaymentGapPercent)} % → alerte medium.',
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: const StadiumBorder(),
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Enregistrer le paiement'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Champ de date « Date d'échéance / Date de paiement ».
class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
      const SizedBox(height: 6),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textDark),
            const SizedBox(width: 10),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      color: muted ? AppColors.textMuted : AppColors.textDark)),
            ),
          ]),
        ),
      ),
    ]);
  }
}
