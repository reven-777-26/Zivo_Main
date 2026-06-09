import '../models/country_regulation.dart';

class CountryRegulationEngine {
  static final List<CountryRegulation> _rules = [
    const CountryRegulation(
      ingredientName: 'Potassium Bromate',
      countryStatuses: {
        'India': CountryStatus(
          status: 'Banned',
          reason: 'FSSAI banned potassium bromate in bread and bakery products in 2016 due to potential carcinogenic risks.',
          reference: 'FSSAI Order F.No. 11/2/Reg/Flour/FSSAI-2016',
        ),
        'UK': CountryStatus(
          status: 'Banned',
          reason: 'Banned in food products by the UK and EU since 1990 due to classification as a category 2B carcinogen.',
          reference: 'COMAH / UK Food Standards Agency Regulations',
        ),
        'USA': CountryStatus(
          status: 'Allowed',
          reason: 'Permitted by the FDA as a flour treatment agent, though California requires a cancer warning under Prop 65.',
          reference: 'FDA 21 CFR 172.730',
        ),
      },
    ),
    const CountryRegulation(
      ingredientName: 'Triclosan',
      countryStatuses: {
        'USA': CountryStatus(
          status: 'Banned',
          reason: 'FDA banned triclosan in consumer antiseptic washes (soaps) in 2016 because manufacturers failed to prove daily safety and efficacy.',
          reference: 'FDA Consumer Antiseptic Wash Rule (2016)',
        ),
        'India': CountryStatus(
          status: 'Restricted',
          reason: 'CDSCO restricts triclosan to a maximum concentration of 0.3% in leave-on and rinse-off cosmetic products.',
          reference: 'Drugs and Cosmetics Act, Bureau of Indian Standards',
        ),
        'UK': CountryStatus(
          status: 'Restricted',
          reason: 'EU/UK cosmetics regulations restrict triclosan use to a maximum concentration of 0.3% in rinse-off cosmetic products.',
          reference: 'UK Toys and Cosmetics Regulations',
        ),
      },
    ),
    const CountryRegulation(
      ingredientName: 'Coal Tar',
      countryStatuses: {
        'UK': CountryStatus(
          status: 'Banned',
          reason: 'Banned for use in general cosmetic formulations. Allowed only under strict prescription-strength dermatological treatments.',
          reference: 'UK Cosmetics Regulation Schedule 2',
        ),
        'India': CountryStatus(
          status: 'Banned',
          reason: 'Prohibited as an active ingredient in general cosmetics due to presence of polycyclic aromatic hydrocarbons (PAHs).',
          reference: 'IS 4707 (Part 1): Classification of cosmetic raw materials',
        ),
        'USA': CountryStatus(
          status: 'Restricted',
          reason: 'FDA restricts its use in OTC products (e.g., dandruff shampoos) to concentrations between 0.5% and 5%. Banned in general cosmetics in some states.',
          reference: 'FDA OTC Active Ingredient Regulations',
        ),
      },
    ),
    const CountryRegulation(
      ingredientName: 'Formaldehyde',
      countryStatuses: {
        'UK': CountryStatus(
          status: 'Banned',
          reason: 'Banned in cosmetics and personal care products due to its classification as a Category 1B carcinogen and strong sensitizer.',
          reference: 'EU/UK Regulation 2019/831',
        ),
        'India': CountryStatus(
          status: 'Restricted',
          reason: 'CDSCO restricts formaldehyde to 0.2% in nail hardeners and 0.1% in oral hygiene products, and must be labeled "contains formaldehyde".',
          reference: 'Bureau of Indian Standards IS 4707',
        ),
        'USA': CountryStatus(
          status: 'Restricted',
          reason: 'FDA restricts concentration in cosmetics but does not issue a total federal ban. Several states (e.g. California) have banned formaldehyde in cosmetics.',
          reference: 'FDA Cosmetics Safety guidelines & CA Assembly Bill 2762',
        ),
      },
    ),
    const CountryRegulation(
      ingredientName: 'BHA (Butylated Hydroxyanisole)',
      countryStatuses: {
        'USA': CountryStatus(
          status: 'Allowed',
          reason: 'Recognized by the FDA as Generally Recognized As Safe (GRAS) as a preservative up to 0.02% of fat/oil content.',
          reference: 'FDA 21 CFR 182.3169',
        ),
        'India': CountryStatus(
          status: 'Restricted',
          reason: 'FSSAI restricts usage to a maximum of 200 mg/kg in fats, oils, and fat spreads.',
          reference: 'Food Safety and Standards (Food Products Standards) Regulations',
        ),
        'UK': CountryStatus(
          status: 'Restricted',
          reason: 'Allowed in food and cosmetic products, but subject to strict dosage thresholds due to potential endocrine disruption concerns.',
          reference: 'UK Food Additives Regulations',
        ),
      },
    ),
  ];

  static CountryRegulation? checkIngredient(String name) {
    final lowerName = name.trim().toLowerCase();
    for (var rule in _rules) {
      if (rule.ingredientName.toLowerCase() == lowerName ||
          lowerName.contains(rule.ingredientName.toLowerCase())) {
        return rule;
      }
    }
    return null;
  }

  static List<CountryRegulation> analyzeIngredientsList(List<String> ingredients) {
    final results = <CountryRegulation>[];
    for (var ingredient in ingredients) {
      final match = checkIngredient(ingredient);
      if (match != null) {
        if (!results.any((r) => r.ingredientName == match.ingredientName)) {
          results.add(match);
        }
      }
    }
    return results;
  }
}
