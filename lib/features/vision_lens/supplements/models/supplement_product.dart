class SupplementAlternative {
  final String name;
  final String brand;
  final String reason;

  SupplementAlternative({
    required this.name,
    required this.brand,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'brand': brand,
        'reason': reason,
      };

  factory SupplementAlternative.fromJson(Map<String, dynamic> json) {
    return SupplementAlternative(
      name: json['name'] ?? '',
      brand: json['brand'] ?? '',
      reason: json['reason'] ?? '',
    );
  }
}

class SupplementProduct {
  final String barcode;
  final String productName;
  final String brand;
  final int zivoScore;
  final String servingSize;
  final String dosage;
  final bool underdosed;
  final bool overdosed;
  final bool fillers;
  final bool artificialColors;
  final bool sweeteners;
  final bool veganCapsule;
  final String evidenceNotes;
  final List<String> warnings;
  final List<String> ingredients;
  final List<String> insights;
  final List<SupplementAlternative> alternatives;
  final DateTime scanDate;

  SupplementProduct({
    required this.barcode,
    required this.productName,
    required this.brand,
    required this.zivoScore,
    required this.servingSize,
    required this.dosage,
    required this.underdosed,
    required this.overdosed,
    required this.fillers,
    required this.artificialColors,
    required this.sweeteners,
    required this.veganCapsule,
    required this.evidenceNotes,
    required this.warnings,
    required this.ingredients,
    required this.insights,
    required this.alternatives,
    required this.scanDate,
  });

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'productName': productName,
        'brand': brand,
        'zivoScore': zivoScore,
        'servingSize': servingSize,
        'dosage': dosage,
        'underdosed': underdosed,
        'overdosed': overdosed,
        'fillers': fillers,
        'artificialColors': artificialColors,
        'sweeteners': sweeteners,
        'veganCapsule': veganCapsule,
        'evidenceNotes': evidenceNotes,
        'warnings': warnings,
        'ingredients': ingredients,
        'insights': insights,
        'alternatives': alternatives.map((e) => e.toJson()).toList(),
        'scanDate': scanDate.toIso8601String(),
      };

  factory SupplementProduct.fromJson(Map<String, dynamic> json, {String? barcode}) {
    return SupplementProduct(
      barcode: barcode ?? json['barcode'] ?? '',
      productName: json['productName'] ?? '',
      brand: json['brand'] ?? '',
      zivoScore: json['zivoScore'] ?? 0,
      servingSize: json['servingSize'] ?? '',
      dosage: json['dosage'] ?? '',
      underdosed: json['underdosed'] ?? false,
      overdosed: json['overdosed'] ?? false,
      fillers: json['fillers'] ?? false,
      artificialColors: json['artificialColors'] ?? false,
      sweeteners: json['sweeteners'] ?? false,
      veganCapsule: json['veganCapsule'] ?? false,
      evidenceNotes: json['evidenceNotes'] ?? '',
      warnings: List<String>.from(json['warnings'] ?? []),
      ingredients: List<String>.from(json['ingredients'] ?? []),
      insights: List<String>.from(json['insights'] ?? []),
      alternatives: (json['alternatives'] as List? ?? [])
          .map((e) => SupplementAlternative.fromJson(e))
          .toList(),
      scanDate: json['scanDate'] != null
          ? DateTime.parse(json['scanDate'])
          : DateTime.now(),
    );
  }
}
