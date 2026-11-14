import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

class AccountProfileController extends LevitController {
  AccountProfileController();

  late final firstName = TextEditingController(text: 'Moussa');
  late final lastName = TextEditingController(text: 'Koné');
  late final phone = TextEditingController(text: '+225 07 00 00 00 00');

  @override
  void onClose() {
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    super.onClose();
  }
}
