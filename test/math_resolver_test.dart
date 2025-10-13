import 'package:flutter_test/flutter_test.dart';
import 'package:tabletoptown/utilities/math_resolver.dart' show resolve, tryResolve, validateExpression;

void main() {
  group('MathResolver', () {
    test('simple addition', () {
      expect(resolve('1+2'), 3);
    });

    test('simple subtraction', () {
      expect(resolve('1-2'), -1);
    });

    test('with spaces', () {
      expect(resolve('1 + 2'), 3);
    });

    test('with addition and subtraction', () {
      expect(resolve('1 + 2 - 3'), 0);
    });

    test('add positive', () {
      expect(resolve('1 + +2'), 3);
    });

    test('subtract negative', () {
      expect(resolve('1 - -2'), 3);
    });

    test('add negative', () {
      expect(resolve('1 + -2'), -1);
    });

    test('subtract positive', () {
      expect(resolve('1 - +2'), -1);
    });

    test('leading affirmative', () {
      expect(resolve('+1 + 2'), 3);
    });

    test('leading negative', () {
      expect(resolve('-1 + 2'), 1);
    });

    test('invalid expression', () {
      const expression = 'anything not a number';
      expect(validateExpression(expression), false);
      expect(tryResolve(expression), null);
      expect(() => resolve(expression), throwsException);
    });

    test('multiplication', () {
      expect(resolve('1 * 2'), 2);
    });

    test('division', () {
      expect(resolve('1 / 2'), 0.5);
    });
    test('order of operations', () {
      expect(resolve('1 + 2 * 3'), 7);
    });

    test('order of operations with parenthesis', () {
      expect(resolve('(1 + 2) * 3'), 9);
    });

    test('addition and subtraction with parenthesis', () {
      expect(resolve('1 - (2 + 3)'), -4);
    });

    test('with nested parenthesis', () {
      expect(resolve('1 - ((2 + 3) + 4) + (3 + 5)'), 0);
    });

    test('with negation', () {
      expect(resolve('-(1 + 2)'), -3);
    });

    test('with invalid parenthesis', () {
      const expression = '(1 + 2';
      expect(validateExpression(expression), false);
      expect(tryResolve(expression), null);
      expect(() => resolve(expression), throwsException);
    });

    test('with decimals', () {
      expect(resolve('1.5 + 2.5'), 4);
    });

    test('divide by zero', () {
      const expression = '1 / 0';
      expect(resolve(expression), double.infinity);
    });

    test('zero divided by zero', () {
      const expression = '0 / 0';
      expect(resolve(expression).isNaN, true);
    });
  });
}
