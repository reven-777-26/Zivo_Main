class FoodAlternative {
  final String name;
  final String brand;
  final String reason;

  FoodAlternative({
    required this.name,
    required this.brand,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'brand': brand,
        'reason': reason,
      };

  factory FoodAlternative.fromJson(Map<String, dynamic> json) {
    return FoodAlternative(
      name: json['name'] ?? '',
      brand: json['brand'] ?? '',
      reason: json['reason'] ?? '',
    );
  }
}

class FoodProduct {
  final String barcode;
  final String productName;
  final String brand;
  final int zivoScore;
  final String nutriScore;
  final String novaGroup;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int sugar;
  final int fiber;
  final int sodium;
  final List<String> ingredients;
  final String veganStatus;
  final String vegetarianStatus;
  final bool palmOil;
  final bool artificialSweeteners;
  final bool artificialColors;
  final bool preservatives;
  final List<String> allergens;
  final List<String> warnings;
  final List<String> insights;
  final List<FoodAlternative> alternatives;
  final DateTime scanDate;

  FoodProduct({
    required this.barcode,
    required this.productName,
    required this.brand,
    required this.zivoScore,
    required this.nutriScore,
    required this.novaGroup,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.sugar,
    required this.fiber,
    required this.sodium,
    required this.ingredients,
    required this.veganStatus,
    required this.vegetarianStatus,
    required this.palmOil,
    required this.artificialSweeteners,
    required this.artificialColors,
    required this.preservatives,
    required this.allergens,
    required this.warnings,
    required this.insights,
    required this.alternatives,
    required this.scanDate,
  });

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'productName': productName,
        'brand': brand,
        'zivoScore': zivoScore,
        'nutriScore': nutriScore,
        'novaGroup': novaGroup,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'sugar': sugar,
        'fiber': fiber,
        'sodium': sodium,
        'ingredients': ingredients,
        'veganStatus': veganStatus,
        'vegetarianStatus': vegetarianStatus,
        'palmOil': palmOil,
        'artificialSweeteners': artificialSweeteners,
        'artificialColors': artificialColors,
        'preservatives': preservatives,
        'allergens': allergens,
        'warnings': warnings,
        'insights': insights,
        'alternatives': alternatives.map((e) => e.toJson()).toList(),
        'scanDate': scanDate.toIso8601String(),
      };

  factory FoodProduct.fromJson(Map<String, dynamic> json, {String? barcode}) {
    return FoodProduct(
      barcode: barcode ?? json['barcode'] ?? '',
      productName: json['productName'] ?? '',
      brand: json['brand'] ?? '',
      zivoScore: json['zivoScore'] ?? 0,
      nutriScore: json['nutriScore'] ?? '',
      novaGroup: json['novaGroup'] ?? '',
      calories: json['calories'] ?? 0,
      protein: json['protein'] ?? 0,
      carbs: json['carbs'] ?? 0,
      fat: json['fat'] ?? 0,
      sugar: json['sugar'] ?? 0,
      fiber: json['fiber'] ?? 0,
      sodium: json['sodium'] ?? 0,
      ingredients: List<String>.from(json['ingredients'] ?? []),
      veganStatus: json['veganStatus'] ?? 'Unknown',
      vegetarianStatus: json['vegetarianStatus'] ?? 'Unknown',
      palmOil: json['palmOil'] ?? false,
      artificialSweeteners: json['artificialSweeteners'] ?? false,
      artificialColors: json['artificialColors'] ?? false,
      preservatives: json['preservatives'] ?? false,
      allergens: List<String>.from(json['allergens'] ?? []),
      warnings: List<String>.from(json['warnings'] ?? []),
      insights: List<String>.from(json['insights'] ?? []),
      alternatives: (json['alternatives'] as List? ?? [])
          .map((e) => FoodAlternative.fromJson(e))
          .toList(),
      scanDate: json['scanDate'] != null
          ? DateTime.parse(json['scanDate'])
          : DateTime.now(),
    );
  }
}
