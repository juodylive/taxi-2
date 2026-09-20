import 'package:zearah_rider/app/app_localizations.dart';
import 'package:flutter/material.dart';

extension TranslateString on String {
  String translate(BuildContext context) {
    return UiUtils.getTranslatedLabel(context, this);
  }
}

class UiUtils {
  static String getTranslatedLabel(BuildContext context, String labelKey) {
    return (AppLocalizations.of(context)?.translate(labelKey) ?? labelKey)
        .trim();
  }
}
