import 'package:flutter_test/flutter_test.dart';
import 'package:codemvp/features/vision_lens/shared/services/country_regulation_engine.dart';
import 'package:codemvp/features/vision_lens/food/services/food_api_service.dart';
import 'package:codemvp/features/vision_lens/supplements/services/supplement_service.dart';
import 'package:codemvp/features/vision_lens/skincare/services/skincare_api_service.dart';
import 'package:codemvp/features/vision_lens/shared/services/unified_vision_service.dart';

void main() {
  group('Country Regulation Engine Tests', () {
    test('Should match Potassium Bromate case-insensitively and detect UK ban', () {
      final reg = CountryRegulationEngine.checkIngredient('potassium bromate');
      expect(reg, isNotNull);
      expect(reg!.ingredientName, equals('Potassium Bromate'));
      expect(reg.countryStatuses['UK']!.status, equals('Banned'));
      expect(reg.countryStatuses['India']!.status, equals('Banned'));
      expect(reg.countryStatuses['USA']!.status, equals('Allowed'));
    });

    test('Should match Triclosan and verify USA ban and India restriction', () {
      final reg = CountryRegulationEngine.checkIngredient('Triclosan');
      expect(reg, isNotNull);
      expect(reg!.countryStatuses['USA']!.status, equals('Banned'));
      expect(reg.countryStatuses['India']!.status, equals('Restricted'));
    });

    test('Should match list of ingredients and return unique matches', () {
      final list = ['water', 'potassium bromate', 'triclosan', 'potassium bromate'];
      final matches = CountryRegulationEngine.analyzeIngredientsList(list);
      expect(matches.length, equals(2));
      final names = matches.map((e) => e.ingredientName).toList();
      expect(names, contains('Potassium Bromate'));
      expect(names, contains('Triclosan'));
    });
  });

  group('Food Scoring & Offline Estimation Tests', () {
    test('Should cap score at 100 for clean ingredients', () {
      final product = FoodApiService.estimateLocally('12345', 'Clean Juice', ['Water', 'Orange Juice']);
      expect(product.zivoScore, equals(100));
      expect(product.warnings, contains('None detected (offline estimate)'));
    });

    test('Should decrement score and generate warnings for sugar & palm oil', () {
      final product = FoodApiService.estimateLocally('12345', 'Cookies', ['Palm Oil', 'Sugar']);
      // 100 - 15 (sugar) - 10 (palm oil) = 75
      expect(product.zivoScore, equals(75));
      expect(product.palmOil, isTrue);
      expect(product.warnings.length, greaterThanOrEqualTo(2));
    });

    test('Should apply extra penalty for country banned ingredients', () {
      final product = FoodApiService.estimateLocally('12345', 'Enriched Bread', ['Water', 'Potassium Bromate']);
      // 100 - 20 (UK/India ban) = 80
      expect(product.zivoScore, equals(80));
      expect(product.warnings, anyElement(contains('banned')));
    });

    test('Score should be clamped between 0 and 100', () {
      final product = FoodApiService.estimateLocally('12345', 'Bad Product', [
        'Sugar',
        'Palm Oil',
        'Aspartame',
        'Yellow 5',
        'Sodium Benzoate',
        'Potassium Bromate'
      ]);
      expect(product.zivoScore, greaterThanOrEqualTo(0));
      expect(product.zivoScore, lessThanOrEqualTo(100));
    });
  });

  group('Supplements Scoring & Local Estimation Tests', () {
    test('Should detect non-vegan gelatin capsules and fillers', () {
      final product = SupplementService.estimateLocally('9999', 'Multi', ['Gelatin', 'Magnesium Stearate', 'Zinc']);
      // 100 - 15 (gelatin capsule) - 15 (fillers) = 70
      expect(product.zivoScore, equals(70));
      expect(product.veganCapsule, isFalse);
      expect(product.fillers, isTrue);
    });
  });

  group('Skincare Personalized Scoring Tests', () {
    test('Should penalize comedogenic ingredients extra for Acne/Oily skin types', () {
      final acneProduct = SkincareApiService.estimateLocally(
        '8888',
        'Face Cream',
        ['Water', 'Coconut Oil'],
        'Acne',
      );
      final normalProduct = SkincareApiService.estimateLocally(
        '8888',
        'Face Cream',
        ['Water', 'Coconut Oil'],
        'Normal',
      );

      // Comedogenic triggers score decrement of 20 for Acne, but only warnings for Normal.
      expect(acneProduct.zivoScore, lessThan(normalProduct.zivoScore));
      expect(acneProduct.acneRisk, equals('High'));
    });
  });

  group('Unified Product Report Allergy & Local Rules Tests', () {
    test('Should extract allergy warnings from ingredients list in local fallback engine', () {
      final report = UnifiedVisionService.runLocalRuleEngine(
        barcode: '1111',
        productName: 'Allergen Bread',
        brand: 'Brand X',
        ingredients: ['Wheat Flour', 'Peanuts', 'Milk powder', 'Soy lecithin'],
        category: 'food',
      );
      
      expect(report.allergyWarnings, contains('Contains Gluten'));
      expect(report.allergyWarnings, contains('Contains Nuts'));
      expect(report.allergyWarnings, contains('Contains Dairy'));
      expect(report.allergyWarnings, contains('Contains Soy'));
      expect(report.allergyWarnings, isNot(contains('Contains Egg')));
    });
  });
}
