import 'package:flutter_test/flutter_test.dart';
import 'package:immora_mobile/services/password_service.dart';
import 'package:immora_mobile/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('accepte un email valide', () {
      expect(Validators.email('sirine@immora.tn'), isNull);
      expect(Validators.email('  a.b+c@mail.com  '), isNull);
    });
    test('refuse vide ou mal formé', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('sirine@'), isNotNull);
      expect(Validators.email('sirine.immora.tn'), isNotNull);
      expect(Validators.email('a@b.c'), isNotNull);
    });
  });

  group('Validators.fullName', () {
    test('accepte prénom + nom avec accents', () {
      expect(Validators.fullName('Yassine Trabelsi'), isNull);
      expect(Validators.fullName('Hélène Ben-Ali'), isNull);
    });
    test('refuse trop court, un seul mot ou chiffres', () {
      expect(Validators.fullName('Al'), isNotNull);
      expect(Validators.fullName('Yassine'), isNotNull);
      expect(Validators.fullName('Yassine 123'), isNotNull);
    });
  });

  group('Validators.phone', () {
    test('accepte les formats tunisiens', () {
      expect(Validators.phone('22123456'), isNull);
      expect(Validators.phone('+216 22 123 456'), isNull);
      expect(Validators.phone('0021698123456'), isNull);
    });
    test('refuse longueur ou préfixe invalide', () {
      expect(Validators.phone('2212345'), isNotNull);
      expect(Validators.phone('12123456'), isNotNull);
      expect(Validators.phone('+33612345678'), isNotNull);
    });
    test('normalise en +216XXXXXXXX', () {
      expect(Validators.normalizePhone('22 123 456'), '+21622123456');
      expect(Validators.normalizePhone('00216 22123456'), '+21622123456');
    });
  });

  group('Validators.password', () {
    test('exige 6 caractères, une lettre et un chiffre', () {
      expect(Validators.password('immora123'), isNull);
      expect(Validators.password('abc12'), isNotNull);
      expect(Validators.password('abcdefg'), isNotNull);
      expect(Validators.password('1234567'), isNotNull);
    });
  });

  group('PasswordService', () {
    test('hache avec un sel et vérifie', () {
      final salt = PasswordService.generateSalt();
      final hash = PasswordService.hash('immora123', salt);
      expect(hash, hasLength(64));
      expect(hash, isNot(contains('immora123')));
      expect(PasswordService.verify('immora123', salt, hash), isTrue);
      expect(PasswordService.verify('mauvais1', salt, hash), isFalse);
    });
    test('deux sels différents donnent deux hachés différents', () {
      final a = PasswordService.hash('immora123', PasswordService.generateSalt());
      final b = PasswordService.hash('immora123', PasswordService.generateSalt());
      expect(a, isNot(b));
    });
  });
}
