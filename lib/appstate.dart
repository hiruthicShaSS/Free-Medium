import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  String link;

  bool _newLinkAvailable = false;

  AppState({required this.link});

  void updateLink(String newLink) {
    link = newLink;
    _newLinkAvailable = true;

    notifyListeners();
  }

  bool get isNewLinkAvailable => _newLinkAvailable;

  set setNewLinkAvailablitiy(bool status) => _newLinkAvailable = status;
}
