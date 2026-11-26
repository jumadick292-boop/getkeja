import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_keja_mobile/l10n/generated/app_localizations.dart';

// Regression test for the Task 13.17 audit fix: several house-seeker English
// strings were placeholder Title-Cased values ("Run Now", "Turn Off Alerts",
// "Delete Search", "Compare Clear", "Could Not Run Search") that did not match
// the real UI text the widgets and tests expect. This guards against a
// regression back to placeholder content.
void main() {
  group('house-seeker English l10n is real content, not placeholders', () {
    late AppLocalizations l10n;
    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('saved-search controls use natural sentence case', () {
      expect(l10n.runNow, 'Run now');
      expect(l10n.turnOffAlerts, 'Turn off');
      expect(l10n.turnOnAlerts, 'Turn on');
      expect(l10n.deleteSearch, 'Delete');
      expect(
        l10n.couldNotRunSearch,
        'Could not run the search. Please try again.',
      );
    });

    test('compare clear uses a real label and confirmation', () {
      expect(l10n.compareClear, 'Clear all');
      expect(l10n.compareClearConfirm, isNot('Compare Clear Confirm'));
      expect(l10n.compareEmptyTitle, 'No properties compared yet');
    });
  });
}