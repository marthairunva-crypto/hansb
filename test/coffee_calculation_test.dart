import 'package:flutter_test/flutter_test.dart';
import 'package:biz_manager/domain/services/coffee_calculation_service.dart';

/// CRITICAL TEST CASE FROM HANS. B TRADING COMPANY RECORDS
/// This test MUST pass to ensure calculation accuracy
void main() {
  group('Coffee Calculation Service - HANS. B Exact Calculations', () {
    test('Aleesors Transaction - Exact Company Record', () {
      // Real transaction from company records:
      // Farmer: Aleesors
      // Gross Weight: 43 kg
      // Dryness Deduction: 2 kg
      // Buying Price: UGX 11,000/kg
      // Milling Rate: UGX 300/kg
      // Advance Recovery: UGX 300,000
      
      final calculation = CoffeeCalculationService.calculatePurchase(
        grossWeight: 43.0,
        qualityDeduction: 2.0,
        buyingPricePerKg: 11000.0,
        millingRatePerKg: 300.0,
        advanceRecovery: 300000.0,
        otherDeductions: 0.0,
        millingChargeBase: 'GROSS_WEIGHT',
      );
      
      // Expected results from company records:
      expect(calculation.payableWeight, 41.0, reason: 'Payable weight = 43 - 2');
      expect(calculation.coffeeValue, 451000.0, reason: 'Coffee value = 41 × 11,000');
      
      // CRITICAL: Milling charge MUST use gross weight (43 kg), not payable (41 kg)
      expect(calculation.millingCharge, 12900.0, 
        reason: 'Milling charge = 43 (GROSS) × 300, NOT 41 × 300');
      
      expect(calculation.amountAfterMilling, 438100.0, 
        reason: 'Amount after milling = 451,000 - 12,900');
      
      expect(calculation.netPayment, 138100.0,
        reason: 'Net payment = 438,100 - 300,000');
    });
    
    test('Calculation with no deductions', () {
      final calculation = CoffeeCalculationService.calculatePurchase(
        grossWeight: 50.0,
        qualityDeduction: 0.0,
        buyingPricePerKg: 10000.0,
        millingRatePerKg: 300.0,
        advanceRecovery: 0.0,
      );
      
      expect(calculation.payableWeight, 50.0);
      expect(calculation.coffeeValue, 500000.0);
      expect(calculation.millingCharge, 15000.0); // 50 × 300
      expect(calculation.netPayment, 485000.0);
    });
    
    test('Calculation with different weights and prices', () {
      final calculation = CoffeeCalculationService.calculatePurchase(
        grossWeight: 100.0,
        qualityDeduction: 5.0,
        buyingPricePerKg: 12000.0,
        millingRatePerKg: 250.0,
        advanceRecovery: 500000.0,
      );
      
      expect(calculation.payableWeight, 95.0);
      expect(calculation.coffeeValue, 1140000.0); // 95 × 12,000
      expect(calculation.millingCharge, 25000.0); // 100 (GROSS) × 250
      expect(calculation.netPayment, 615000.0); // 1,140,000 - 25,000 - 500,000
    });
    
    test('Milling charge using PAYABLE_WEIGHT base', () {
      final calculation = CoffeeCalculationService.calculatePurchase(
        grossWeight: 43.0,
        qualityDeduction: 2.0,
        buyingPricePerKg: 11000.0,
        millingRatePerKg: 300.0,
        millingChargeBase: 'PAYABLE_WEIGHT', // Different from default
      );
      
      expect(calculation.payableWeight, 41.0);
      expect(calculation.coffeeValue, 451000.0);
      // When base is PAYABLE_WEIGHT, milling uses 41 kg
      expect(calculation.millingCharge, 12300.0); // 41 × 300
    });
    
    test('Validation - negative weight should throw', () {
      expect(
        () => CoffeeCalculationService.calculatePurchase(
          grossWeight: -10.0,
          qualityDeduction: 0.0,
          buyingPricePerKg: 10000.0,
          millingRatePerKg: 300.0,
        ),
        throwsArgumentError,
      );
    });
    
    test('Validation - deduction exceeds gross weight should throw', () {
      expect(
        () => CoffeeCalculationService.calculatePurchase(
          grossWeight: 40.0,
          qualityDeduction: 45.0,
          buyingPricePerKg: 10000.0,
          millingRatePerKg: 300.0,
        ),
        throwsArgumentError,
      );
    });
    
    test('Validation - negative price should throw', () {
      expect(
        () => CoffeeCalculationService.calculatePurchase(
          grossWeight: 50.0,
          qualityDeduction: 0.0,
          buyingPricePerKg: -10000.0,
          millingRatePerKg: 300.0,
        ),
        throwsArgumentError,
      );
    });
    
    test('Multiple advances recovery', () {
      final calculation = CoffeeCalculationService.calculatePurchase(
        grossWeight: 80.0,
        qualityDeduction: 3.0,
        buyingPricePerKg: 11500.0,
        millingRatePerKg: 300.0,
        advanceRecovery: 450000.0,
        otherDeductions: 50000.0,
      );
      
      expect(calculation.payableWeight, 77.0);
      expect(calculation.coffeeValue, 885500.0); // 77 × 11,500
      expect(calculation.millingCharge, 24000.0); // 80 × 300
      expect(calculation.netPayment, 361500.0); // 885,500 - 24,000 - 450,000 - 50,000
    });
    
    test('Milling recovery calculation', () {
      final recovery = CoffeeCalculationService.calculateMillingRecovery(
        inputQuantity: 10000.0,
        outputQuantity: 8200.0,
      );
      
      expect(recovery, 82.0);
    });
    
    test('Advance recovery validation - valid', () {
      final isValid = CoffeeCalculationService.validateAdvanceRecovery(
        requestedRecovery: 250000.0,
        outstandingAdvance: 300000.0,
      );
      
      expect(isValid, true);
    });
    
    test('Advance recovery validation - exceeds outstanding', () {
      final isValid = CoffeeCalculationService.validateAdvanceRecovery(
        requestedRecovery: 350000.0,
        outstandingAdvance: 300000.0,
      );
      
      expect(isValid, false);
    });
    
    test('Currency formatting', () {
      expect(
        CoffeeCalculationService.formatCurrency(451000.0),
        'UGX 451,000',
      );
      expect(
        CoffeeCalculationService.formatCurrency(1234567.0),
        'UGX 1,234,567',
      );
    });
    
    test('Weight formatting', () {
      expect(
        CoffeeCalculationService.formatWeight(43.0),
        '43.00 kg',
      );
      expect(
        CoffeeCalculationService.formatWeight(41.56),
        '41.56 kg',
      );
    });
  });
}
