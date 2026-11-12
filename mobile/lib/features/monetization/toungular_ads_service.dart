import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/config/app_environment.dart';
import 'ad_policy.dart';

class ToungularAdsService extends ChangeNotifier {
  ToungularAdsService._();

  static final ToungularAdsService instance = ToungularAdsService._();
  bool _started = false;
  bool _canRequestAds = false;

  bool get canRequestAds => _canRequestAds;

  Future<void> initialize() async {
    if (_started) return;
    _started = true;
    try {
      await MobileAds.instance.initialize();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          unawaited(
            ConsentForm.loadAndShowConsentFormIfRequired(
              (_) => _refreshConsent(),
            ),
          );
          unawaited(_refreshConsent());
        },
        (_) => _refreshConsent(),
      );
    } catch (_) {
      _canRequestAds = false;
      notifyListeners();
    }
  }

  Future<void> _refreshConsent() async {
    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      _canRequestAds = false;
    }
    notifyListeners();
  }

  Future<bool> showRewardedBonus({
    required bool isPremium,
    required bool voiceActive,
  }) async {
    const policy = AdPlacementPolicy();
    if (!policy.canShow(
      AdPlacement.rewardedLessonUnlock,
      AppInteractionState(
        isRecording: voiceActive,
        isVoiceConversationActive: voiceActive,
        isPremium: isPremium,
        hasAdConsent: _canRequestAds,
        adsConfigured: AppEnvironment.adsEnabled,
      ),
    )) {
      return false;
    }
    final completed = Completer<bool>();
    RewardedAd? loaded;
    Timer? loadTimer;
    var disposed = false;

    void disposeLoaded() {
      if (disposed) return;
      disposed = true;
      loaded?.dispose();
    }

    void finish(bool value) {
      loadTimer?.cancel();
      if (!completed.isCompleted) completed.complete(value);
    }

    // A stuck ad request must not leave the learner waiting forever. The
    // timeout covers loading only, not the length of the ad itself.
    loadTimer = Timer(const Duration(seconds: 12), () {
      disposeLoaded();
      finish(false);
    });

    unawaited(
      RewardedAd.load(
        adUnitId: AppEnvironment.rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            loaded = ad;
            loadTimer?.cancel();
            var earned = false;
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                disposeLoaded();
                finish(earned);
              },
              onAdFailedToShowFullScreenContent: (ad, _) {
                disposeLoaded();
                finish(false);
              },
            );
            ad.show(onUserEarnedReward: (_, _) => earned = true);
          },
          onAdFailedToLoad: (_) => finish(false),
        ),
      ),
    );
    return completed.future;
  }
}
