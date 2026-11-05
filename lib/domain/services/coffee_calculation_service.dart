import 'dart:math';

/// Coffee Purchase Calculation Service
/// Implements the EXACT calculation rules for HANS. B Trading Company Limited
/// 
/// CRITICAL CALCULATION RULE:
/// Milling charge is calculated using GROSS WEIGHT, not payable weight
/// 
/// Example from company records:
/// Gross: 43 kg
/// Deduction: 2 kg
/// Payable: 41 kg
/// Price: UGX 11,000/kg
/// Coffee Value: 41 × 11,000 = UGX 451,000
/// Milling Charge: 43 × 300 = UGX 12,900  (uses GROSS 43, not payable 41)
/// After Milling: 451,000 - 12,900 = UGX 438,100
/// Advance Recovery: UGX 300,000
/// Net Payment: 438,100 - 300,000 = UGX 138,100
class CoffeeCalculationService {
  /// Calculate complete coffee purchase transaction
  static CoffeePurchaseCalculation calculatePurchase({
    required double grossWeight,
    required double qualityDeduction,
    required double buyingPricePerKg,
    required double millingRatePerKg,
    double advanceRecovery = 0.0,
    double otherDeductions = 0.0,
    String millingChargeBase = 'GROSS_WEIGHT',
  }) {
    // Validation
    if (grossWeight <= 0) {
      throw ArgumentError('Gross weight must be positive');
    }
    if (qualityDeduction < 0) {
      throw ArgumentError('Quality deduction cannot be negative');
    }
    if (qualityDeduction > grossWeight) {
      throw ArgumentError('Quality deduction cannot exceed gross weight');
    }
    if (buyingPricePerKg <= 0) {
      throw ArgumentError('Buying price must be positive');
    }
    if (millingRatePerKg < 0) {
      throw ArgumentError('Milling rate cannot be negative');
    }
    if (advanceRecovery < 0) {
      throw ArgumentError('Advance recovery cannot be negative');
    }
    if (otherDeductions < 0) {
      throw ArgumentError('Other deductions cannot be negative');
    }
    
    // Step 1: Calculate payable weight
    final payableWeight = _roundToDecimal(grossWeight - qualityDeduction, 2);
    
    if (payableWeight < 0) {
      throw ArgumentError('Payable weight cannot be negative');
    }
    
    // Step 2: Calculate coffee value (using payable weight)
    final coffeeValue = _roundToDecimal(payableWeight * buyingPricePerKg, 0);
    
    // Step 3: Calculate milling charge
    // CRITICAL: Use the configured base (default: GROSS_WEIGHT)
    final millingChargeBaseWeight = millingChargeBase == 'PAYABLE_WEIGHT' 
        ? payableWeight 
        : grossWeight;
    final millingCharge = _roundToDecimal(
      millingChargeBaseWeight * millingRatePerKg, 
      0
    );
    
    // Step 4: Calculate amount after milling
    final amountAfterMilling = _roundToDecimal(coffeeValue - millingCharge, 0);
    
    // Step 5: Calculate net payment after all deductions
    final netPayment = _roundToDecimal(
      amountAfterMilling - advanceRecovery - otherDeductions,
      0
    );
    
    return CoffeePurchaseCalculation(
      grossWeight: grossWeight,
      qualityDeduction: qualityDeduction,
      payableWeight: payableWeight,
      buyingPricePerKg: buyingPricePerKg,
      coffeeValue: coffeeValue,
      millingRatePerKg: millingRatePerKg,
      millingCharge: millingCharge,
      millingChargeBase: millingChargeBase,
      amountAfterMilling: amountAfterMilling,
      advanceRecovery: advanceRecovery,
      otherDeductions: otherDeductions,
      netPayment: netPayment,
    );
  }
  
  /// Calculate milling recovery percentage
  static double calculateMillingRecovery({
    required double inputQuantity,
    required double outputQuantity,
  }) {
    if (inputQuantity <= 0) {
      return 0.0;
    }
    return _roundToDecimal((outputQuantity / inputQuantity) * 100, 2);
  }
  
  /// Validate if advance recovery amount is acceptable
  static bool validateAdvanceRecovery({
    required double requestedRecovery,
    required double outstandingAdvance,
  }) {
    return requestedRecovery <= outstandingAdvance;
  }
  
  /// Round to specified decimal places
  static double _roundToDecimal(double value, int decimalPlaces) {
    final factor = pow(10, decimalPlaces);
    return (value * factor).round() / factor;
  }
  
  /// Format currency for display
  static String formatCurrency(double amount, {String currency = 'UGX'}) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$currency $formatted';
  }
  
  /// Format weight for display
  static String formatWeight(double weight) {
    return '${weight.toStringAsFixed(2)} kg';
  }
}

/// Coffee Purchase Calculation Result
/// Contains all calculated values for a coffee purchase transaction
class CoffeePurchaseCalculation {
  final double grossWeight;
  final double qualityDeduction;
  final double payableWeight;
  final double buyingPricePerKg;
  final double coffeeValue;
  final double millingRatePerKg;
  final double millingCharge;
  final String millingChargeBase;
  final double amountAfterMilling;
  final double advanceRecovery;
  final double otherDeductions;
  final double netPayment;
  
  CoffeePurchaseCalculation({
    required this.grossWeight,
    required this.qualityDeduction,
    required this.payableWeight,
    required this.buyingPricePerKg,
    required this.coffeeValue,
    required this.millingRatePerKg,
    required this.millingCharge,
    required this.millingChargeBase,
    required this.amountAfterMilling,
    required this.advanceRecovery,
    required this.otherDeductions,
    required this.netPayment,
  });
  
  /// Get formatted calculation breakdown for display or receipt
  String getCalculationBreakdown({String currency = 'UGX'}) {
    return '''
Gross Weight              ${CoffeeCalculationService.formatWeight(grossWeight)}
Dryness Deduction         ${CoffeeCalculationService.formatWeight(qualityDeduction)}
Payable Weight            ${CoffeeCalculationService.formatWeight(payableWeight)}

Buying Price              ${CoffeeCalculationService.formatCurrency(buyingPricePerKg, currency: currency)}/kg
Coffee Value              ${CoffeeCalculationService.formatCurrency(coffeeValue, currency: currency)}

Milling Rate              ${CoffeeCalculationService.formatCurrency(millingRatePerKg, currency: currency)}/kg
Milling Charge            ${CoffeeCalculationService.formatCurrency(millingCharge, currency: currency)}
(Calculated on ${millingChargeBase == 'GROSS_WEIGHT' ? 'Gross' : 'Payable'} Weight)

Amount After Milling      ${CoffeeCalculationService.formatCurrency(amountAfterMilling, currency: currency)}
Advance Recovery          ${CoffeeCalculationService.formatCurrency(advanceRecovery, currency: currency)}
Other Deductions          ${CoffeeCalculationService.formatCurrency(otherDeductions, currency: currency)}

NET PAYMENT               ${CoffeeCalculationService.formatCurrency(netPayment, currency: currency)}
''';
  }
  
  Map<String, dynamic> toMap() {
    return {
      'gross_weight': grossWeight,
      'quality_deduction_amount': qualityDeduction,
      'payable_weight': payableWeight,
      'buying_price_per_kg': buyingPricePerKg,
      'coffee_value': coffeeValue,
      'milling_rate_per_kg': millingRatePerKg,
      'milling_charge': millingCharge,
      'milling_charge_base': millingChargeBase,
      'advance_recovery_amount': advanceRecovery,
      'other_deductions': otherDeductions,
      'net_payment': netPayment,
    };
  }
}
