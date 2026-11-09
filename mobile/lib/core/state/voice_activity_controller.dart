import 'package:flutter_riverpod/flutter_riverpod.dart';

final voiceActivityProvider = NotifierProvider<VoiceActivityController, bool>(VoiceActivityController.new);

class VoiceActivityController extends Notifier<bool> {
  @override
  bool build() => false;

  void setActive(bool active) => state = active;
}
