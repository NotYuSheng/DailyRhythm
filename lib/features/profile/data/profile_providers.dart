import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/profile.dart';
import 'profile_repository.dart';

final profileProvider = FutureProvider<Profile>((ref) => ProfileRepository().load());
