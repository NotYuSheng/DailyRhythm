import 'package:daily_rhythm/core/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a build is named by version, build number and commit', () {
    expect(describeVersion('1.2.0', '4', '91a91f9'), '1.2.0 (4) · 91a91f9');
    expect(describeVersion('1.2.0-91a91f9', '4', '91a91f9'), '1.2.0-91a91f9 (4)', reason: 'the hash once');
    expect(describeVersion('1.2.0', '4', ''), '1.2.0 (4) · local build');
  });
}
