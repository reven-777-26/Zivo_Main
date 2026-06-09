class CountryStatus {
  final String status; // 'Allowed', 'Restricted', 'Banned'
  final String reason;
  final String reference;

  const CountryStatus({
    required this.status,
    required this.reason,
    required this.reference,
  });

  Map<String, dynamic> toJson() => {
        'status': status,
        'reason': reason,
        'reference': reference,
      };

  factory CountryStatus.fromJson(Map<String, dynamic> json) {
    return CountryStatus(
      status: json['status'] ?? 'Allowed',
      reason: json['reason'] ?? '',
      reference: json['reference'] ?? '',
    );
  }
}

class CountryRegulation {
  final String ingredientName;
  final Map<String, CountryStatus> countryStatuses; // 'India', 'USA', 'UK'

  const CountryRegulation({
    required this.ingredientName,
    required this.countryStatuses,
  });

  Map<String, dynamic> toJson() => {
        'ingredientName': ingredientName,
        'countryStatuses': countryStatuses.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory CountryRegulation.fromJson(Map<String, dynamic> json) {
    final statuses = <String, CountryStatus>{};
    if (json['countryStatuses'] != null) {
      (json['countryStatuses'] as Map<String, dynamic>).forEach((key, value) {
        statuses[key] = CountryStatus.fromJson(value);
      });
    }
    return CountryRegulation(
      ingredientName: json['ingredientName'] ?? '',
      countryStatuses: statuses,
    );
  }
}
