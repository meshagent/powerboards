import 'package:flutter_test/flutter_test.dart';
import 'package:meshagent/meshagent.dart';
import 'package:powerboards/nav/nav.dart';

void main() {
  test('powerboardsMobileCreditBannerCopy returns low-balance mobile copy', () {
    final copy = powerboardsMobileCreditBannerCopy(outOfCredit: false, userRole: ProjectRole.admin);

    expect(copy.title, 'Low balance');
    expect(copy.description, 'Add more credits to avoid service interruption.');
  });

  test('powerboardsMobileCreditBannerCopy returns admin out-of-credit mobile copy', () {
    final copy = powerboardsMobileCreditBannerCopy(outOfCredit: true, userRole: ProjectRole.admin);

    expect(copy.title, 'Out of credit');
    expect(copy.description, 'Add more credits to re-enable rooms.');
  });

  test('powerboardsMobileCreditBannerCopy returns member out-of-credit mobile copy', () {
    final copy = powerboardsMobileCreditBannerCopy(outOfCredit: true, userRole: ProjectRole.member);

    expect(copy.title, 'Out of credit');
    expect(copy.description, 'Contact your project admin to add more credits.');
  });
}
