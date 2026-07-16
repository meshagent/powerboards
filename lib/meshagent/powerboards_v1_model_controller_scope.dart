import 'package:flutter/material.dart';
import 'package:meshagent_flutter_shadcn/chat/dataset_chat_thread.dart';

class PowerboardsV1ModelControllerScope extends InheritedNotifier<DatasetChatModelController> {
  const PowerboardsV1ModelControllerScope({super.key, required DatasetChatModelController controller, required super.child})
    : super(notifier: controller);

  static DatasetChatModelController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PowerboardsV1ModelControllerScope>()?.notifier;
  }
}
