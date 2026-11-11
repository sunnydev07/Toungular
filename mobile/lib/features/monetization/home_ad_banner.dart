import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/config/app_environment.dart';
import '../../core/state/voice_activity_controller.dart';
import '../../core/theme/toungular_theme.dart';
import 'ad_policy.dart';
import 'monetization_repository.dart';
import 'toungular_ads_service.dart';

class ToungularHomeAdBanner extends ConsumerWidget {
  const ToungularHomeAdBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppEnvironment.adsEnabled) return const SizedBox.shrink();
    final voiceActive = ref.watch(voiceActivityProvider);
    final entitlement = ref.watch(entitlementSnapshotProvider);
    if (entitlement.isLoading ||
        entitlement.hasError ||
        entitlement.asData?.value.premium == true) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: ToungularAdsService.instance,
      builder: (context, _) {
        const policy = AdPlacementPolicy();
        final allowed = policy.canShow(
          AdPlacement.homeBanner,
          AppInteractionState(
            isRecording: voiceActive,
            isVoiceConversationActive: voiceActive,
            isPremium: entitlement.asData?.value.premium ?? false,
            hasAdConsent: ToungularAdsService.instance.canRequestAds,
            adsConfigured: AppEnvironment.adsEnabled,
          ),
        );
        return allowed ? const _LoadedBanner() : const SizedBox.shrink();
      },
    );
  }
}

class _LoadedBanner extends StatefulWidget {
  const _LoadedBanner();
  @override
  State<_LoadedBanner> createState() => _LoadedBannerState();
}

class _LoadedBannerState extends State<_LoadedBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: AppEnvironment.bannerAdUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted)
            setState(() {
              _ad = null;
              _loaded = false;
            });
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ToungularSpace.s),
      child: Semantics(
        label: 'Advertisement',
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
