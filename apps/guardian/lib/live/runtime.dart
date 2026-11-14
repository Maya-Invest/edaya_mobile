import 'package:flutter/widgets.dart';
import 'package:levit_flutter/levit_flutter.dart';

import 'prototype_runtime.dart';

bool prototypeIsLive(BuildContext context) {
  try {
    return context.levit.find<PrototypeRuntime>().live;
  } on Object {
    return true;
  }
}

bool prototypeRuntimeIsLive(LevitScope scope) {
  try {
    return scope.find<PrototypeRuntime>().live;
  } on Object {
    return true;
  }
}

String personInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  if (parts.isEmpty) {
    return '?';
  }
  final letters = parts.map((part) => part[0]).take(2).join();
  return letters.toUpperCase();
}
