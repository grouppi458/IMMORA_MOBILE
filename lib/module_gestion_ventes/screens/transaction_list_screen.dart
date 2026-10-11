import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_gestion_ventes/models/transaction_details.dart';
import 'package:immora_mobile/module_gestion_ventes/providers/transaction_provider.dart';
import 'package:immora_mobile/module_gestion_ventes/screens/transaction_detail_screen.dart';
import 'package:immora_mobile/module_gestion_ventes/screens/transaction_form_screen.dart';
import 'package:immora_mobile/module_gestion_ventes/widgets/sales_widgets.dart';

enum _Sort { recent, amountDesc, amountAsc }

/// « Transactions » [txList] — M4 : le cycle complet des affaires de l'agence
/// (ventes et locations), filtrable par type et statut, avec leur avancement.
class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key, required this.agencyId});

  final int agencyId;

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  _Sort _sort = _Sort.recent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<TransactionProvider>().load(widget.agencyId));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TransactionDetails> _sorted(List<TransactionDetails> all) {
    final list = [...all];
    switch (_sort) {
      case _Sort.recent:
        break; // déjà triées par avancement puis date
      case _Sort.amountDesc:
        list.sort((a, b) => b.transaction.amount.compareTo(a.transaction.amount));
      case _Sort.amountAsc:
        list.sort((a, b) => a.transaction.amount.compareTo(b.transaction.amount));
    }
    return list;
  }

  Future<void> _openForm() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TransactionFormScreen(agencyId: widget.agencyId)));
    if (mounted) await context.read<TransactionProvider>().load(widget.agencyId);
  }

  Future<void> _openDetail(TransactionDetails d) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(transactionId: d.transaction.id!)));
    if (mounted) await context.read<TransactionProvider>().load(widget.agencyId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final all =
        provider.agencyId == widget.agencyId ? provider.transactions : <TransactionDetails>[];
    final list = _sorted(all);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Transactions', actions: [
        IconButton(
          tooltip: _searching ? 'Fermer la recherche' : 'Rechercher',
          icon: Icon(_searching ? Icons.close : Icons.search),
          onPressed: () => setState(() {
            _searching = !_searching;
            if (!_searching) {
              _searchCtrl.clear();
              context.read<TransactionProvider>().setQuery('');
            }
          }),
        ),
        PopupMenuButton<_Sort>(
          tooltip: 'Trier',
          icon: const Icon(Icons.filter_alt_outlined),
          initialValue: _sort,
          onSelected: (s) => setState(() => _sort = s),
          itemBuilder: (_) => const [
            PopupMenuItem(value: _Sort.recent, child: Text('Plus récentes')),
            PopupMenuItem(value: _Sort.amountDesc, child: Text('Montant décroissant')),
            PopupMenuItem(value: _Sort.amountAsc, child: Text('Montant croissant')),
          ],
        ),
      ]),
      floatingActionButton: GoldFab(label: 'Nouvelle', onPressed: _openForm),
      body: RefreshIndicator(
        onRefresh: () => provider.load(widget.agencyId),
        child: ListView(
          padding: const EdgeInsets.only(top: 16, bottom: 96),
          children: [
            if (_searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: (v) => context.read<TransactionProvider>().setQuery(v),
                  decoration: InputDecoration(
                    hintText: 'Bien ou client…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentToggle<DealType?>(
                options: const [
                  (null, 'Toutes'),
                  (DealType.sale, 'Ventes'),
                  (DealType.rent, 'Locations'),
                ],
                selected: provider.dealFilter,
                onSelect: (d) => context.read<TransactionProvider>().setDealFilter(d),
              ),
            ),
            const SizedBox(height: 12),
            FilterChipsRow<TransactionStatus?>(
              selected: provider.statusFilter,
              onSelected: (s) => context.read<TransactionProvider>().setStatusFilter(s),
              options: const [
                (null, 'Tous statuts'),
                (TransactionStatus.draft, 'Brouillon'),
                (TransactionStatus.ongoing, 'En cours'),
                (TransactionStatus.signed, 'Signée'),
                (TransactionStatus.completed, 'Terminée'),
                (TransactionStatus.cancelled, 'Annulée'),
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
                if (provider.isLoading && all.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (list.isEmpty)
                  WhiteCard(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      all.isEmpty
                          ? 'Aucune transaction pour l’instant. Créez la première '
                              'avec « Nouvelle ».'
                          : 'Aucune transaction ne correspond.',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  )
                else
                  WhiteCard(
                    child: Column(children: [
                      for (var i = 0; i < list.length; i++) ...[
                        _TransactionRow(
                            details: list[i], onTap: () => _openDetail(list[i])),
                        if (i < list.length - 1)
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

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.details, required this.onTap});

  final TransactionDetails details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tx = details.transaction;
    final cancelled = tx.status == TransactionStatus.cancelled;
    final subtitle = switch (tx.status) {
      TransactionStatus.cancelled => tx.cancelReason ?? 'Annulée',
      TransactionStatus.draft => '${tx.amountLabel} · non finalisée',
      _ => '${tx.amountLabel} · ${tx.shortClient}',
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          IconTile(iconForDealType(tx.dealType), cancelled ? toneRed : toneBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${details.propertyTitle} · ${tx.dealType.label}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cancelled ? AppColors.error : AppColors.textDark),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                    fontSize: 12.5,
                    color: cancelled ? AppColors.error : AppColors.textMuted),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          StatusBadge(tx.status.label, toneForTransactionStatus(tx.status)),
        ]),
      ),
    );
  }
}
