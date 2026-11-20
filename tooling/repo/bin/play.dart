import 'dart:io';
import 'package:edaya_repo/src/play.dart';

Future<void> main(List<String> args) async {
  try {
    await runPlay(args, Platform.environment);
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
