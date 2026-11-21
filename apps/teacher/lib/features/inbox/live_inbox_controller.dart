import 'package:edaya_shared/edaya_shared.dart';

class LiveInboxController extends RecipientInboxController {
  LiveInboxController({required super.session, required super.schoolClient})
    : super(kind: 'teacher');
}
