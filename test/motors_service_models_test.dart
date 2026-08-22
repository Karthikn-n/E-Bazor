import 'package:Ebozor/data/model/motors_service_models.dart';
import 'package:Ebozor/data/repositories/motors_service_repository.dart';
import 'package:Ebozor/ui/screens/motors_services/data/motors_evaluation_faqs.dart';
import 'package:Ebozor/ui/screens/motors_services/data/motors_finance_faqs.dart';
import 'package:Ebozor/ui/screens/widgets/car_finance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inspection package handles dashboard package response fields', () {
    final package = InspectionPackageModel.fromJson({
      'id': '9',
      'name': 'Premium',
      'final_price': '499',
      'inspection_points': 200,
      'features': ['Engine', 'Body'],
    });

    expect(package.id, 9);
    expect(package.name, 'Premium');
    expect(package.price, 499);
    expect(package.points, '200');
    expect(package.features, ['Engine', 'Body']);
  });

  test('inspection record handles nested and alternate API fields', () {
    final record = CarInspectionRecord.fromJson({
      'id': 12,
      'payment_status': 'pending',
      'package': {'name': 'Advanced'},
      'created_at': '2026-08-21',
      'seller_number': '0500000000',
      'price': '569',
    });

    expect(record.packageName, 'Advanced');
    expect(record.status, 'pending');
    expect(record.appointmentDate, '2026-08-21');
    expect(record.price, 569);
  });

  test('inspection record maps the get-car-inspection sample response', () {
    final record = CarInspectionRecord.fromJson({
      'id': 6,
      'user_id': 360,
      'user_number': '+9123456',
      'seller_number': '+91345678',
      'package_id': 8,
      'price': '569',
      'email': 'w@yopmail.com',
      'payment_type': 'Stripe',
      'payment_status': 'success',
      'status': 'pending',
      'inspection_report': 'https://example.com/inspection.pdf',
      'created_at': '2026-05-07T08:56:52.000000Z',
      'updated_at': '2026-05-09T09:48:36.000000Z',
    });

    expect(record.id, 6);
    expect(record.packageId, 8);
    expect(record.packageName, 'Package #8');
    expect(record.userNumber, '+9123456');
    expect(record.sellerNumber, '+91345678');
    expect(record.paymentType, 'Stripe');
    expect(record.paymentStatus, 'success');
    expect(record.status, 'pending');
    expect(record.hasInspectionReport, isTrue);
  });

  test('inspection packages always have a usable local fallback', () {
    expect(MotorsServiceRepository.fallbackPackages, hasLength(2));
    expect(
      MotorsServiceRepository.fallbackPackages.map((package) => package.id),
      [8, 9],
    );
    expect(
      MotorsServiceRepository.fallbackPackages
          .every((package) => package.features.isNotEmpty),
      isTrue,
    );
  });

  test('motors payment draft keeps the selected service request intact', () {
    const draft = MotorsServicePaymentDraft(
      type: MotorsServiceType.finance,
      servicePayload: {'user_id': 368, 'car_year': '2026'},
      email: 'driver@example.com',
    );

    expect(draft.type, MotorsServiceType.finance);
    expect(draft.servicePayload['user_id'], 368);
    expect(draft.email, 'driver@example.com');
  });

  test('finance FAQ questions mirror the supplied UI content', () {
    expect(motorsFinanceFaqs, hasLength(13));
    expect(motorsFinanceFaqs.every((faq) => faq.question.isNotEmpty), isTrue);
  });

  test('evaluation FAQ questions mirror the supplied UI content', () {
    expect(motorsEvaluationFaqs, hasLength(9));
    expect(
        motorsEvaluationFaqs.every((faq) => faq.question.isNotEmpty), isTrue);
  });

  test('car finance uses the reverse-engineered flat-rate calculation', () {
    final calculation = CarFinanceCalculation.calculate(
      carPrice: 10000,
      downPaymentPercent: 10,
      annualInterestRate: 1,
      loanPeriodYears: 1,
    );

    expect(calculation.downPayment, 1000);
    expect(calculation.financedAmount, 9000);
    expect(calculation.totalInterest, 90);
    expect(calculation.totalLoanAmount, 9090);
    expect(calculation.monthlyPayment.round(), 758);
  });
}
