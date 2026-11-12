import 'package:flutter_test/flutter_test.dart';
import 'package:toungular/core/config/app_environment.dart';

void main() {
  test('ads are off unless explicitly requested', () {
    expect(
      AppEnvironment.resolveAdsEnabled(
        requested: false,
        release: false,
        bannerAdUnitId: 'banner',
        rewardedAdUnitId: 'rewarded',
      ),
      isFalse,
    );
  });

  test('a release build without real ad units keeps ads off', () {
    expect(
      AppEnvironment.resolveAdsEnabled(
        requested: true,
        release: true,
        bannerAdUnitId: '',
        rewardedAdUnitId: '',
      ),
      isFalse,
    );
    expect(
      AppEnvironment.resolveAdsEnabled(
        requested: true,
        release: true,
        bannerAdUnitId: 'ca-app-pub-1/2',
        rewardedAdUnitId: 'ca-app-pub-1/3',
      ),
      isTrue,
    );
  });

  test('development builds fall back to Google test units', () {
    expect(
      AppEnvironment.resolveAdsEnabled(
        requested: true,
        release: false,
        bannerAdUnitId: '',
        rewardedAdUnitId: '',
      ),
      isTrue,
    );
    expect(
      AppEnvironment.bannerAdUnitId,
      'ca-app-pub-3940256099942544/6300978111',
    );
    expect(
      AppEnvironment.rewardedAdUnitId,
      'ca-app-pub-3940256099942544/5224354917',
    );
  });
}
