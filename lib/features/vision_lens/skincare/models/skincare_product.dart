class SkincareAlternative {
  final String name;
  final String brand;
  final String reason;

  SkincareAlternative({
    required this.name,
    required this.brand,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'brand': brand,
        'reason': reason,
      };

  factory SkincareAlternative.fromJson(Map<String, dynamic> json) {
    return SkincareAlternative(
      name: json['name'] ?? '',
      brand: json['brand'] ?? '',
      reason: json['reason'] ?? '',
    );
  }
}

class SkincareProduct {
  final String barcode;
  final String productName;
  final String brand;
  final int zivoScore;
  final String acneRisk;
  final int comedogenicRating;
  final String irritationRisk;
  final bool fragrance;
  final bool parabens;
  final bool sulfates;
  final bool dryingAlcohols;
  final bool essentialOils;
  final String sensitiveSkinRisk;
  final String pregnancyWarning;
  final List<String> warnings;
  final List<String> ingredients;
  final List<SkincareAlternative> alternatives;
  final DateTime scanDate;

  SkincareProduct({
    required this.barcode,
    required this.productName,
    required this.brand,
    required this.zivoScore,
    required this.acneRisk,
    required this.comedogenicRating,
    required this.irritationRisk,
    required this.fragrance,
    required this.parabens,
    required this.sulfates,
    required this.dryingAlcohols,
    required this.essentialOils,
    required this.sensitiveSkinRisk,
    required this.pregnancyWarning,
    required this.warnings,
    required this.ingredients,
    required this.alternatives,
    required this.scanDate,
  });

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'productName': productName,
        'brand': brand,
        'zivoScore': zivoScore,
        'acneRisk': acneRisk,
        'comedogenicRating': comedogenicRating,
        'irritationRisk': irritationRisk,
        'fragrance': fragrance,
        'parabens': parabens,
        'sulfates': sulfates,
        'dryingAlcohols': dryingAlcohols,
        'essentialOils': essentialOils,
        'sensitiveSkinRisk': sensitiveSkinRisk,
        'pregnancyWarning': pregnancyWarning,
        'warnings': warnings,
        'ingredients': ingredients,
        'alternatives': alternatives.map((e) => e.toJson()).toList(),
        'scanDate': scanDate.toIso8601String(),
      };

  factory SkincareProduct.fromJson(Map<String, dynamic> json, {String? barcode}) {
    return SkincareProduct(
      barcode: barcode ?? json['barcode'] ?? '',
      productName: json['productName'] ?? '',
      brand: json['brand'] ?? '',
      zivoScore: json['zivoScore'] ?? 0,
      acneRisk: json['acneRisk'] ?? 'Low',
      comedogenicRating: json['comedogenicRating'] ?? 0,
      irritationRisk: json['irritationRisk'] ?? 'Low',
      fragrance: json['fragrance'] ?? false,
      parabens: json['parabens'] ?? false,
      sulfates: json['sulfates'] ?? false,
      dryingAlcohols: json['dryingAlcohols'] ?? false,
      essentialOils: json['essentialOils'] ?? false,
      sensitiveSkinRisk: json['sensitiveSkinRisk'] ?? 'Low',
      pregnancyWarning: json['pregnancyWarning'] ?? 'None',
      warnings: List<String>.from(json['warnings'] ?? []),
      ingredients: List<String>.from(json['ingredients'] ?? []),
      alternatives: (json['alternatives'] as List? ?? [])
          .map((e) => SkincareAlternative.fromJson(e))
          .toList(),
      scanDate: json['scanDate'] != null
          ? DateTime.parse(json['scanDate'])
          : DateTime.now(),
    );
  }
}
