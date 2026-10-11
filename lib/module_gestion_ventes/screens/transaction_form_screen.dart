import 'package:file_picker/file_picker.dart';
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
import 'package:immora_mobile/module_gestion_ventes/models/transaction_details.dart';
import 'package:immora_mobile/module_gestion_ventes/providers/transaction_provider.dart';
import 'package:immora_mobile/module_gestion_ventes/widgets/sales_widgets.dart';

/// Taux de commission proposés au sélecteur (« Taux de commission »).
const _rateChoices = [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0];

/// « Nouvelle transaction » [txForm] — M4 : bien libre, client, agent, type,
/// montant contrôlé en direct contre le prix affiché (« Écart de 34 % avec le
/// prix affiché »), commission calculée, dates et contrat PDF.
class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({
    super.key,
    required this.agencyId,
    this.editing,
    this.initialProperty,
    this.initialClientName,
    this.initialDealType,
  });

  final int agencyId;
  final TransactionDetails? editing; // null = création

  /// Pré-remplissage depuis une visite (M6) ou la fiche d'un bien (M3) :
  /// (id, titre, prix affiché), nom du client et type d'affaire.
  final (int, String, double)? initialProperty;
  final String? initialClientName;
  final DealType? initialDealType;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  List<(int, String, double)> _properties = [];
  List<(int, String)> _agents = [];
  (int, String, double)? _property;
  (int, String)? _agent;
  late DealType _deal = widget.editing?.transaction.dealType ??
      widget.initialDealType ??
      DealType.sale;
  late double _rate =
      widget.editing?.transaction.commissionRate ?? commissionDefaultPercent / 100;
  late DateTime _startDate = widget.editing == null
      ? DateTime.now()
      : DateTime.fromMillisecondsSinceEpoch(widget.editing!.transaction.startDate);
  late DateTime? _endDate = widget.editing?.transaction.endDate == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(widget.editing!.transaction.endDate!);
  String? _contractName;

  String? _serverField;
  String? _serverMessage;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.editing?.transaction;
    if (tx != null) {
      _clientCtrl.text = tx.clientName;
      _amountCtrl.text = formatNumber(tx.amount);
      _contractName = tx.contractPath;
      _property = (tx.propertyId, widget.editing!.propertyTitle, widget.editing!.propertyPrice);
    } else if (widget.initialProperty != null) {
      _property = widget.initialProperty;
      if (widget.initialClientName != null) _clientCtrl.text = widget.initialClientName!;
    }
    final provider = context.read<TransactionProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => provider.clearError());
    provider
        .propertyOptions(widget.agencyId, currentTransactionId: tx?.id)
        .then((list) {
      if (!mounted) return;
      setState(() {
        _properties = list;
        // Le bien présélectionné (visite, fiche du bien) ou déjà lié reste
        // proposé même s'il n'est plus listé comme disponible.
        if (_property != null && !list.any((p) => p.$1 == _property!.$1)) {
          list.add(_property!);
        }
      });
    });
    provider.agentOptions(widget.agencyId).then((list) {
      if (!mounted) return;
      setState(() {
        _agents = list;
        for (final a in list) {
          if (a.$2 == widget.editing?.agentName) _agent = a;
        }
      });
    });
  }

  @override
  void dispose() {
    _clientCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'));

  String? _error(String field) => _serverField == field ? _serverMessage : null;

  void _clearServerError(String field) {
    if (_serverField == field) {
      setState(() {
        _serverField = null;
        _serverMessage = null;
      });
    }
  }

  /// Écart en % entre le montant saisi et le prix affiché du bien choisi —
  /// le contrôle en direct de la maquette (« Écart de 34 % avec le prix
  /// affiché »), au-delà de [anomalyPriceGapPercent].
  double? get _gapPercent {
    final price = _property?.$3 ?? 0;
    final amount = _num(_amountCtrl);
    if (price <= 0 || amount == null || amount <= 0) return null;
    return (amount - price).abs() / price * 100;
  }

  bool get _gapDetected =>
      (_gapPercent ?? 0) > anomalyPriceGapPercent;

  // ------------------------------------------------------------- Sélecteurs

  Future<void> _pickProperty() async {
    final chosen = await showModalBottomSheet<(int, String, double)>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Bien',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (_properties.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Aucun bien disponible : chaque bien a déjà une '
                    'transaction en cours.', style: TextStyle(color: AppColors.textMuted)),
              )
            else
              for (final p in _properties)
                ListTile(
                  leading: const Icon(Icons.home_work_outlined, color: AppColors.primary),
                  title: Text(p.$2),
                  subtitle: Text('Prix affiché : ${formatNumber(p.$3)} TND',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  trailing:
                      _property?.$1 == p.$1 ? const Icon(Icons.check, color: AppColors.primary) : null,
                  onTap: () => Navigator.of(ctx).pop(p),
                ),
          ],
        ),
      ),
    );
    if (chosen != null) setState(() => _property = chosen);
  }

  Future<void> _pickAgent() async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Agent',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const InitialsAvatar('?', tone: toneGrey),
              title: const Text('Sans agent'),
              onTap: () => Navigator.of(ctx).pop('none'),
            ),
            for (final a in _agents)
              ListTile(
                leading: InitialsAvatar(a.$2, tone: toneAgent),
                title: Text(a.$2),
                subtitle: Text('${formatRate(_rate)} % de commission',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                trailing: _agent?.$1 == a.$1
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(ctx).pop(a),
              ),
          ],
        ),
      ),
    );
    if (result == null) return;
    setState(() => _agent = result == 'none' ? null : result as (int, String));
  }

  Future<void> _pickRate() async {
    final chosen = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Taux de commission',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final r in _rateChoices)
              ListTile(
                title: Text('${formatRate(r / 100)} %'),
                subtitle: Text(
                    'de ${formatRate(commissionMinPercent / 100)} % à '
                    '${formatRate(commissionMaxPercent / 100)} %',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                trailing: _rate == r / 100
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(ctx).pop(r / 100),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) setState(() => _rate = chosen);
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = (start ? _startDate : _endDate) ?? _startDate;
    final chosen = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (chosen == null) return;
    setState(() {
      if (start) {
        _startDate = chosen;
      } else {
        _endDate = chosen;
      }
    });
  }

  Future<void> _pickContract() async {
    final files = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf']);
    final name = files.isEmpty ? null : files.first.name;
    if (name != null && mounted) setState(() => _contractName = name);
  }

  // -------------------------------------------------------------- Enregistrer

  Future<void> _submit({required bool draft}) async {
    FocusScope.of(context).unfocus();
    if (_property == null) {
      setState(() {
        _serverField = 'property';
        _serverMessage = 'Choisissez un bien disponible.';
      });
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<TransactionProvider>();
    final bool ok;
    if (_isEdit) {
      ok = await provider.update(
        widget.editing!.transaction.id!,
        propertyId: _property!.$1,
        clientName: _clientCtrl.text.trim(),
        dealType: _deal,
        amount: _num(_amountCtrl) ?? 0,
        commissionRate: _rate,
        startDate: _startDate,
        agentId: _agent?.$1,
        endDate: _deal == DealType.rent ? _endDate : null,
        contractPath: _contractName,
      );
    } else {
      ok = (await provider.create(
            agencyId: widget.agencyId,
            propertyId: _property!.$1,
            clientName: _clientCtrl.text.trim(),
            dealType: _deal,
            amount: _num(_amountCtrl) ?? 0,
            commissionRate: _rate,
            startDate: _startDate,
            status: draft ? TransactionStatus.draft : TransactionStatus.ongoing,
            agentId: _agent?.$1,
            endDate: _deal == DealType.rent ? _endDate : null,
            contractPath: _contractName,
          )) !=
          null;
    }
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _serverField = provider.errorField;
        _serverMessage = provider.errorMessage;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.success,
      content: Text(_isEdit
          ? 'Transaction modifiée'
          : draft
              ? 'Transaction créée en brouillon'
              : 'Transaction créée'),
    ));
    Navigator.of(context).pop(true);
  }

  // ------------------------------------------------------------------ Build

  @override
  Widget build(BuildContext context) {
    final banner = _serverMessage != null && _serverField == null;
    final amount = _num(_amountCtrl);
    final gap = _gapPercent;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, _isEdit ? 'Modifier la transaction' : 'Nouvelle transaction',
          close: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (banner) ...[
              MessageBanner(type: BannerType.error, message: _serverMessage!),
              const SizedBox(height: 14),
            ],
            const _FieldLabel('Bien'),
            InkWell(
              onTap: _pickProperty,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: _error('property') != null ? AppColors.errorBg : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _error('property') != null ? AppColors.error : AppColors.border),
                ),
                child: Row(children: [
                  Icon(Icons.home_work_outlined,
                      size: 20,
                      color: _property == null ? AppColors.textMuted : AppColors.textDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _property?.$2 ?? 'Choisir un bien',
                      style: TextStyle(
                          fontSize: 14,
                          color: _property == null ? AppColors.textMuted : AppColors.textDark),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                ]),
              ),
            ),
            const SizedBox(height: 5),
            if (_error('property') != null)
              Text(_error('property')!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error))
            else if (_property != null)
              Text('Prix affiché : ${formatNumber(_property!.$3)} TND',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            const SizedBox(height: 14),
            AuthTextField(
              label: 'Client',
              icon: Icons.person_outline,
              hint: 'Yassine Trabelsi',
              controller: _clientCtrl,
              textCapitalization: TextCapitalization.words,
              errorText: _error('client'),
              hasError: _error('client') != null,
              onChanged: (_) => _clearServerError('client'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Indiquez le client.' : null,
            ),
            const SizedBox(height: 14),
            const _FieldLabel('Agent'),
            InkWell(
              onTap: _pickAgent,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  const Icon(Icons.people_outline, size: 20, color: AppColors.textDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _agent == null
                          ? 'Aucun agent'
                          : '${_agent!.$2} · ${formatRate(_rate)} %',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            const _FieldLabel('Type'),
            SegmentToggle<DealType>(
              options: const [
                (DealType.sale, 'Vente'),
                (DealType.rent, 'Location'),
              ],
              selected: _deal,
              onSelect: (d) => setState(() {
                _deal = d;
                if (d == DealType.sale) _endDate = null;
              }),
            ),
            const SizedBox(height: 14),
            AuthTextField(
              label: 'Montant (TND)',
              icon: Icons.paid_outlined,
              hint: '820 000',
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s.,]'))],
              errorText: _error('amount') ??
                  (_gapDetected ? 'Écart de ${formatNumber(gap!)} % avec le prix affiché' : null),
              hasError: _error('amount') != null || _gapDetected,
              onChanged: (_) {
                _clearServerError('amount');
                setState(() {});
              },
              validator: (v) => (_num(_amountCtrl) ?? 0) <= 0
                  ? 'Indiquez un montant supérieur à 0.'
                  : null,
            ),
            if (_gapDetected) ...[
              const SizedBox(height: 10),
              MessageBanner(
                type: BannerType.error,
                message: 'Anomalie détectée (medium) : prix final très éloigné du prix '
                    'affiché (${formatNumber(gap!)} % > ${formatNumber(anomalyPriceGapPercent)} %). '
                    'Une alerte sera créée à la validation.',
              ),
            ],
            const SizedBox(height: 14),
            WhiteCard(
              child: Column(children: [
                InkWell(
                  onTap: _pickRate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    child: Row(children: [
                      const Expanded(
                          child: Text('Taux de commission',
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted))),
                      Text('${formatRate(_rate)} %',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down,
                          size: 18, color: AppColors.textMuted),
                    ]),
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  child: Row(children: [
                    const Expanded(
                        child: Text('Commission calculée',
                            style: TextStyle(fontSize: 13, color: AppColors.textMuted))),
                    Text(
                      amount == null || amount <= 0
                          ? '—'
                          : '${formatNumber(amount * _rate)} TND',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.gold),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: _DateField(
                  label: 'Date de début',
                  value: formatDateNumeric(_startDate),
                  onTap: () => _pickDate(start: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: 'Date de fin',
                  value: _deal == DealType.rent && _endDate != null
                      ? formatDateNumeric(_endDate!)
                      : '— (location)',
                  muted: _deal != DealType.rent || _endDate == null,
                  onTap: _deal == DealType.rent ? () => _pickDate(start: false) : null,
                ),
              ),
            ]),
            if (_error('endDate') != null) ...[
              const SizedBox(height: 6),
              Text(_error('endDate')!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error)),
            ],
            const SizedBox(height: 14),
            WhiteCard(
              child: NavTile(
                icon: Icons.description_outlined,
                tone: toneBlue,
                title: 'Contrat (PDF)',
                subtitle: _contractName ?? 'Joindre le contrat · file_picker',
                onTap: _pickContract,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: AppColors.background,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: _isEdit
              ? FilledButton(
                  onPressed: () => _submit(draft: false),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Enregistrer'),
                )
              : Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _submit(draft: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.border),
                        shape: const StadiumBorder(),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('Brouillon'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _submit(draft: false),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: const StadiumBorder(),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('Créer'),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
      );
}

/// Champ de date « Date de début / Date de fin » (icône calendrier).
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FieldLabel(label),
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
                      fontSize: 14, color: muted ? AppColors.textMuted : AppColors.textDark)),
            ),
          ]),
        ),
      ),
    ]);
  }
}
