import 'package:flutter_test/flutter_test.dart';
import 'package:immora_mobile/module_authentification/models/agent_performance.dart';
import 'package:immora_mobile/module_gestion_agences/score/activity_scorer.dart';
import 'package:immora_mobile/module_authentification/services/password_service.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/core/utils/validators.dart';

void main() {
  group('ActivityScorer.compute', () {
    test('activité maximale = 100', () {
      expect(
          ActivityScorer.compute(logins: 40, properties: 20, clients: 15, daysInactive: 0),
          100);
    });
    test('aucune activité = 0', () {
      expect(
          ActivityScorer.compute(logins: 0, properties: 0, clients: 0, daysInactive: null),
          0);
    });
    test('applique les poids du cahier des charges', () {
      // 0.3·(10/20) + 0.3·(5/10) + 0.2·(2/10) + 0.2·(1 − 15/30) = 0.15+0.15+0.04+0.10
      expect(
          ActivityScorer.compute(logins: 10, properties: 5, clients: 2, daysInactive: 15),
          44);
    });
    test('inactif depuis plus de 30 jours : la récence vaut 0', () {
      expect(
          ActivityScorer.compute(logins: 0, properties: 0, clients: 0, daysInactive: 45),
          0);
    });
  });

  group('Formatage', () {
    test('milliers séparés', () {
      expect(formatNumber(12480), '12 480');
      expect(formatNumber(240), '240');
    });
    test('taux de commission', () {
      expect(formatRate(0.03), '3');
      expect(formatRate(0.025), '2,5');
    });
    test('initiales', () {
      expect(initialsOf('Carthage Immobilier'), 'CI');
      expect(initialsOf('Admin'), 'A');
    });
  });

  group('Validators.commissionPercent', () {
    test('accepte 3 et 2,5', () {
      expect(Validators.commissionPercent('3'), isNull);
      expect(Validators.commissionPercent('2,5'), isNull);
      expect(Validators.parsePercent('2,5'), 2.5);
    });
    test('refuse vide, 0 et plus de 20 %', () {
      expect(Validators.commissionPercent(''), isNotNull);
      expect(Validators.commissionPercent('0'), isNotNull);
      expect(Validators.commissionPercent('25'), isNotNull);
      expect(Validators.commissionPercent('abc'), isNotNull);
    });
  });

  test('mot de passe temporaire valide', () {
    for (var i = 0; i < 20; i++) {
      final pwd = PasswordService.generateTemporaryPassword();
      expect(pwd, hasLength(10));
      expect(Validators.password(pwd), isNull);
    }
  });

  test('période de performance (BF1.8)', () {
    int daysBack(PerformancePeriod p) =>
        (DateTime.now().difference(p.since).inHours / 24).round();
    expect(daysBack(PerformancePeriod.days30), 30);
    expect(daysBack(PerformancePeriod.months12), 365);
    expect(PerformancePeriod.days90.label, '90 jours');
  });
}
