import 'package:flutter/material.dart';

import 'package:immora_mobile/core/theme/app_colors.dart';
import 'package:immora_mobile/core/widgets/admin_widgets.dart';
import 'package:immora_mobile/module_gestion_annonces/matching/matching_engine.dart';

Color colorForScore(int score) => score >= MatchingEngine.alertScore
    ? AppColors.success
    : score >= 65
        ? AppColors.gold
        : AppColors.secondary;

/// Pastille ronde « 94% » (Match score) : anneau de progression + pourcentage.
class MatchScoreBadge extends StatelessWidget {
  const MatchScoreBadge({super.key, required this.score, this.size = 44});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = colorForScore(score);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: score / 100,
            strokeWidth: size / 14,
            color: color,
            backgroundColor: AppColors.background,
          ),
        ),
        Text('$score%',
            style: TextStyle(
                fontSize: size * 0.27, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      ]),
    );
  }
}

/// « ✓ Dans votre budget · À Tunis · 3 chambres »
class MatchReasons extends StatelessWidget {
  const MatchReasons({super.key, required this.reasons});

  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    if (reasons.isEmpty) return const SizedBox.shrink();
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.check_circle_outline, size: 15, color: AppColors.success),
      const SizedBox(width: 5),
      Expanded(
        child: Text(reasons.join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.success)),
      ),
    ]);
  }
}

/// Bloc « Très compatible » de la fiche [propPublic] : score, explication
/// et une barre par composante (Budget · 35 %, Zone · 25 %…).
class CompatibilityCard extends StatelessWidget {
  const CompatibilityCard({super.key, required this.match, required this.subject, this.source});

  final MatchResult match;

  /// « Appartement S+3 » (début de la phrase d'explication).
  final String subject;

  /// « selon vos critères » / « d'après vos favoris ».
  final String? source;

  @override
  Widget build(BuildContext context) {
    final explanation = match.excluded
        ? 'Ne correspond pas à votre recherche (vente / location ou parking).'
        : match.reasons.isEmpty
            ? '$subject — ${match.score} %.'
            : '$subject — ${match.score} % : '
                '${match.reasons.map((r) => r[0].toLowerCase() + r.substring(1)).join(', ')}.';
    return WhiteCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          MatchScoreBadge(score: match.score, size: 60),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(match.excluded ? 'Non compatible' : match.label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(explanation,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.35)),
              if (source != null)
                Text(source!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        for (final f in MatchFactor.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(
                width: 104,
                child: Text('${f.label} · ${(f.weight * 100).round()} %',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: match.subScores[f],
                    minHeight: 6,
                    backgroundColor: AppColors.background,
                    color: match.subScores[f]! >= MatchingEngine.reasonThreshold
                        ? AppColors.gold
                        : AppColors.secondary,
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
