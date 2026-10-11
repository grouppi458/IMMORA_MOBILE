import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:immora_mobile/module_gestion_annonces/ai/assistant_parser.dart';
import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/utils/enums.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/core/widgets/message_banner.dart';
import 'package:immora_mobile/module_authentification/providers/auth_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/models/listing_details.dart';
import 'package:immora_mobile/module_gestion_annonces/providers/client_listing_provider.dart';
import 'package:immora_mobile/module_gestion_annonces/screens/listing_detail_screen.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/client_listing_cards.dart';
import 'package:immora_mobile/module_gestion_annonces/widgets/listing_card.dart';

/// « Assistant IMMORA » (M6 · maquette Figma) : chat en français.
/// Votre question → [AssistantParser] (mots-clés + RegExp) → [PropertyFilter]
/// → recherche parmi les annonces publiées.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

sealed class _ChatItem {
  const _ChatItem();
}

class _UserMessage extends _ChatItem {
  const _UserMessage(this.text);
  final String text;
}

class _BotMessage extends _ChatItem {
  const _BotMessage(this.text);
  final String text;
}

/// Encadré « FILTRE COMPRIS » : les critères extraits de la phrase.
class _FilterCard extends _ChatItem {
  const _FilterCard(this.filter);
  final PropertyFilter filter;
}

/// Bien(s) trouvé(s) : cartes compactes ouvrant la fiche du bien.
class _ResultCards extends _ChatItem {
  const _ResultCards(this.listings);
  final List<ListingDetails> listings;
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatItem> _items = [];
  bool _typing = false;

  static const _fallback = 'Je n’ai pas compris. Précisez la ville ou le budget '
      '(ex. « maison à La Marsa, max 600 000 »).';
  static const _suggestions = [
    'Villas à louer à Gammarth',
    'S+3 à Tunis, max 500 000',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final listings = context.read<ClientListingProvider>();
      final id = context.read<AuthProvider>().currentUser?.id;
      if (listings.clientId == null && id != null) listings.load(id);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _greeting {
    final name = context.read<AuthProvider>().currentUser?.fullName ?? '';
    final first = name.trim().isEmpty ? '' : name.trim().split(' ').first;
    final hello = first.isEmpty ? 'Bonjour' : 'Bonjour $first';
    return '$hello ! Posez votre question en français, je cherche les biens pour vous.';
  }

  // ------------------------------------------------------------ Conversation

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _typing) return;
    _input.clear();
    setState(() {
      _items.add(_UserMessage(text));
      _typing = true;
    });
    _scrollToEnd();

    // Petit délai : l'indicateur « … » le temps de l'analyse.
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    final listings = context.read<ClientListingProvider>().published;
    final filter = AssistantParser.parse(
      text,
      cities: {for (final d in listings) d.property.city}.where((c) => c.isNotEmpty).toList(),
      districts: {for (final d in listings) d.property.district}.where((c) => c.isNotEmpty).toList(),
    );

    final found = <_ChatItem>[];
    if (!filter.isUsable) {
      found.add(const _BotMessage(_fallback));
    } else {
      final hits = [
        for (final d in listings)
          if (filter.matches(d)) d,
      ];
      found.add(_FilterCard(filter));
      if (hits.isEmpty) {
        found.add(const _BotMessage(
            'Aucun bien ne correspond. Élargissez le budget ou la zone.'));
      } else {
        final shown = hits.take(5).toList();
        found.add(_BotMessage(hits.length == 1
            ? 'J’ai trouvé 1 bien correspondant.'
            : 'J’ai trouvé ${hits.length} biens correspondants.'));
        found.add(_ResultCards(shown));
        if (hits.length > shown.length) {
          found.add(_BotMessage(
              'Affinez votre recherche pour voir les ${hits.length - shown.length} autres résultats.'));
        }
      }
    }

    setState(() {
      _typing = false;
      _items.addAll(found);
    });
    _scrollToEnd();
  }

  void _reset() {
    setState(() {
      _items.clear();
      _typing = false;
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // -------------------------------------------------------------- Affichage

  @override
  Widget build(BuildContext context) {
    final items = <_ChatItem>[_BotMessage(_greeting), ..._items];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: adminAppBar(context, 'Assistant IMMORA', actions: [
        IconButton(
          tooltip: 'Nouvelle conversation',
          icon: const Icon(Icons.refresh),
          onPressed: _reset,
        ),
      ]),
      body: Column(children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            children: [
              const MessageBanner(
                type: BannerType.info,
                icon: Icons.auto_awesome,
                message: 'Décrivez votre recherche en français : type de bien, '
                    'ville, budget, chambres… Je filtre les annonces publiées pour vous.',
              ),
              const SizedBox(height: 14),
              for (final item in items) _buildItem(item),
              if (_typing) const _TypingBubble(),
            ],
          ),
        ),
        _SuggestionsRow(onTap: _send),
        _InputBar(controller: _input, onSend: () => _send(_input.text)),
      ]),
    );
  }

  Widget _buildItem(_ChatItem item) => switch (item) {
        _UserMessage(:final text) => _Bubble(text, fromUser: true),
        _BotMessage(:final text) => _Bubble(text, fromUser: false),
        _FilterCard(:final filter) => _FilterUnderstood(filter: filter),
        _ResultCards(:final listings) => Column(children: [
            for (final d in listings) _AssistantListingCard(details: d),
          ]),
      };
}

/// Bulle de chat : blanche (assistant) à gauche, bleu nuit (utilisateur) à droite.
class _Bubble extends StatelessWidget {
  const _Bubble(this.text, {required this.fromUser});

  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: fromUser ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: fromUser ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}

/// « FILTRE COMPRIS » : puces dorées « type = appartement », « maxPrice = … ».
class _FilterUnderstood extends StatelessWidget {
  const _FilterUnderstood({required this.filter});

  final PropertyFilter filter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('FILTRE COMPRIS',
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (label, value) in filter.chips) _FilterChip(label, value),
        ]),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: toneGold.$1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label = $value',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: toneGold.$2)),
    );
  }
}

/// Carte résultat du chat : photo, « Appart. S+2 · Ennasr », prix en or.
class _AssistantListingCard extends StatelessWidget {
  const _AssistantListingCard({required this.details});

  final ListingDetails details;

  String get _shortTitle {
    final p = details.property;
    final base = switch (p.type) {
      PropertyType.apartment => p.rooms > 0 ? 'Appart. S+${p.rooms}' : 'Appartement',
      PropertyType.house => 'Maison',
      PropertyType.villa => 'Villa',
      PropertyType.land => 'Terrain',
      PropertyType.office => 'Bureau',
      PropertyType.shop => 'Local',
    };
    final place = p.district.isEmpty ? p.city : p.district;
    return place.isEmpty ? base : '$base · $place';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ListingDetailScreen(listingId: details.listing.id!))),
          child: Row(children: [
            SizedBox(
              width: 96,
              height: 92,
              child: ListingPhoto(type: details.property.type, iconSize: 30),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_shortTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    ListingPrice(
                        price: details.listing.displayedPrice,
                        deal: details.property.dealType,
                        fontSize: 15),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right, color: AppColors.textMuted),
            ),
          ]),
        ),
      ),
    );
  }
}

/// « … » : trois points animés pendant l'analyse de la question.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _opacity(double t, int i) {
    final phase = (t + i / 3) % 1.0;
    return phase < 0.5 ? 0.3 + 1.4 * phase : 1.0 - 1.4 * (phase - 0.5);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Opacity(
                opacity: _opacity(_controller.value, i).clamp(0.25, 1.0),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Exemples de questions, au-dessus du champ de saisie.
class _SuggestionsRow extends StatelessWidget {
  const _SuggestionsRow({required this.onTap});

  final ValueChanged<String> onTap;

  static const _examples = _AssistantScreenState._suggestions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        children: [
          for (final example in _examples)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.white,
                shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onTap(example),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(example,
                        style: const TextStyle(fontSize: 13.5, color: AppColors.textDark)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Champ « Écrivez votre question… » + bouton d'envoi bleu nuit.
class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Écrivez votre question…',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onSend,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.send_rounded, size: 20, color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }
}
