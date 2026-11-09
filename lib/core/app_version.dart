import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The commit this build was made from, passed in by CI with
/// `--dart-define=GIT_SHA=<short hash>`; empty for a local build.
const gitSha = String.fromEnvironment('GIT_SHA');

/// What to call this build: version, build number and commit, e.g.
/// "1.2.0 (4) · 91a91f9", or "· local build" when built on a computer.
String describeVersion(String version, String buildNumber, [String sha = gitSha]) {
  final number = buildNumber.isEmpty ? '' : ' ($buildNumber)';
  // Dev builds already carry the hash in the version name.
  final commit = sha.isEmpty ? ' · local build' : version.contains(sha) ? '' : ' · $sha';
  return '$version$number$commit';
}

/// This build's version, for Settings and About.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return describeVersion(info.version, info.buildNumber);
});
