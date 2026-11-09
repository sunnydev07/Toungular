import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_environment.dart';
import 'features/monetization/toungular_ads_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppEnvironment.adsEnabled) ToungularAdsService.instance.initialize();
  runApp(const ProviderScope(child: ToungularApp()));
}
