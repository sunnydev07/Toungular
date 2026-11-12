enum AdPlacement { homeBanner, lessonNative, rewardedLessonUnlock }

class AppInteractionState {
  const AppInteractionState({
    required this.isRecording,
    required this.isVoiceConversationActive,
    required this.isPremium,
    required this.hasAdConsent,
    required this.adsConfigured,
  });

  final bool isRecording;
  final bool isVoiceConversationActive;
  final bool isPremium;
  final bool hasAdConsent;
  final bool adsConfigured;
}

class AdPlacementPolicy {
  const AdPlacementPolicy();

  bool canShow(AdPlacement placement, AppInteractionState state) {
    if (!state.adsConfigured || !state.hasAdConsent || state.isPremium) {
      return false;
    }
    if (state.isRecording || state.isVoiceConversationActive) return false;
    return switch (placement) {
      AdPlacement.homeBanner ||
      AdPlacement.lessonNative ||
      AdPlacement.rewardedLessonUnlock => true,
    };
  }
}
