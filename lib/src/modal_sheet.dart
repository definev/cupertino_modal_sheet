import 'package:flutter/widgets.dart';

import '../cupertino_modal_sheet.dart';

/// Shows a modal iOS-style sheet that slides up from the bottom of the screen.
Future<T?> showCupertinoModalSheet<T>(
    {required BuildContext context,
    required WidgetBuilder builder,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
    bool fullscreenDialog = true,
    bool barrierDismissible = true,
    bool fullPage = false,
    CupertinoModalSheetRouteTransition firstTransition = CupertinoModalSheetRouteTransition.none}) {
  return Navigator.of(context, rootNavigator: useRootNavigator).push(
    CupertinoModalSheetRoute<T>(
      builder: builder,
      fullPage: fullPage,
      settings: routeSettings,
      fullscreenDialog: fullscreenDialog,
      barrierDismissible: barrierDismissible,
      firstTransition: firstTransition,
    ),
  );
}

/// A page that creates a cupertino modal sheet [PageRoute].
class CupertinoModalSheetPage<T> extends Page<T> {
  final Widget child;
  final CupertinoModalSheetRouteTransition firstTransition;
  final bool fullPage;

  const CupertinoModalSheetPage({
    super.key,
    required this.child,
    required this.fullPage,
    super.name,
    super.arguments,
    super.restorationId,
    this.firstTransition = CupertinoModalSheetRouteTransition.none,
  });

  @override
  Route<T> createRoute(BuildContext context) {
    return _PagedCupertinoModalSheetRoute<T>(
      this,
      fullPage: fullPage,
      firstTransition: firstTransition,
    );
  }
}

class _PagedCupertinoModalSheetRoute<T> extends CupertinoModalSheetRoute<T> {
  _PagedCupertinoModalSheetRoute(
    CupertinoModalSheetPage<T> page, {
    required super.fullPage,
    super.firstTransition = CupertinoModalSheetRouteTransition.none,
  }) : super(
          settings: page,
          builder: (_) => const SizedBox(),
        );

  @override
  WidgetBuilder get builder => (context) => (settings as CupertinoModalSheetPage<T>).child;
}
