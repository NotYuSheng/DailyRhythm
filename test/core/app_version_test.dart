import 'package:daily_rhythm/core/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a build is named by version and commit', () {
    expect(describeVersion('1.2.0', '91a91f9'), '1.2.0 · 91a91f9');
    expect(describeVersion('1.2.0-91a91f9', '91a91f9'), '1.2.0-91a91f9', reason: 'the hash once');
    expect(describeVersion('1.2.0', ''), '1.2.0 · local build');
  });
}
