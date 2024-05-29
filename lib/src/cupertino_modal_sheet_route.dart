import 'dart:math';

import 'package:cupertino_modal_sheet/cupertino_modal_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

const double sheetOffset = 10;
const double displayCornerRadius = 38.5;
const double sheetCornerRadius = 10;
const double scaleFactor = 1 / 12;
const double breakpointWidth = 800;
const Size maxSize = Size(700, 1000);

enum CupertinoModalSheetRouteTransition {
  none,
  scale,
  fade,
}

class CupertinoSheetRouteData {
  const CupertinoSheetRouteData({
    required this.depth,
    required this.fullPage,
  });

  static const CupertinoSheetRouteData firstPage = CupertinoSheetRouteData(depth: 0, fullPage: true);

  final int depth;
  final bool fullPage;

  bool get skipStackTransition => depth <= 2 && fullPage == false;

  @override
  String toString() => 'depth: $depth, fullPage: $fullPage';
}

class TracableCupertinoSheetRouteData {
  TracableCupertinoSheetRouteData({
    required this.prev,
    required this.curr,
  });

  final CupertinoSheetRouteData? prev;
  final CupertinoSheetRouteData curr;

  @override
  String toString() {
    return 'prev: $prev, curr: $curr';
  }
}

class CupertinoSheetRoute extends InheritedWidget {
  const CupertinoSheetRoute({
    Key? key,
    required this.data,
    required Widget child,
  }) : super(key: key, child: child);

  final ValueNotifier<TracableCupertinoSheetRouteData> data;

  static ValueNotifier<TracableCupertinoSheetRouteData>? maybeOf(BuildContext context) {
    final CupertinoSheetRoute? result = context.dependOnInheritedWidgetOfExactType<CupertinoSheetRoute>();
    return result?.data;
  }

  static ValueNotifier<TracableCupertinoSheetRouteData> of(BuildContext context) {
    return maybeOf(context)!;
  }

  @override
  bool updateShouldNotify(CupertinoSheetRoute oldWidget) => data != oldWidget.data;
}

/// A route that shows a iOS-style modal sheet that slides up from the
/// bottom of the screen.
///
/// It is used internally by [showCupertinoModalSheet] or can be directly
/// pushed onto the [Navigator] stack to enable state restoration. See
/// [showCupertinoModalSheet] for a state restoration app example.
class CupertinoModalSheetRoute<T> extends PageRouteBuilder<T> {
  /// Creates a page route for use with iOS modal page sheet.
  ///
  /// The values of [builder] must not be null.
  CupertinoModalSheetRoute({
    required this.builder,
    required this.fullPage,
    super.barrierDismissible = true,
    super.settings,
    super.transitionDuration,
    super.reverseTransitionDuration,
    super.barrierLabel,
    super.maintainState = true,
    super.fullscreenDialog = true,
    this.firstTransition = CupertinoModalSheetRouteTransition.none,
  }) : super(
          pageBuilder: (_, __, ___) => const SizedBox.shrink(),
          opaque: false,
          barrierColor: kCupertinoModalBarrierColor,
        );

  /// A builder that builds the widget tree for the [CupertinoModalSheetRoute].
  final WidgetBuilder builder;

  /// A transition for initial page push animation.
  final CupertinoModalSheetRouteTransition firstTransition;

  final bool fullPage;

  Curve _curve = Curves.easeInOut;
  ValueNotifier<TracableCupertinoSheetRouteData>? _routeDataNotifier;
  bool _completed = false;

  @override
  void didComplete(T? result) {
    _completed = true;
    final currentData = _routeDataNotifier!.value;
    _routeDataNotifier!.value = TracableCupertinoSheetRouteData(
      prev: currentData.curr,
      curr: CupertinoSheetRouteData(
        depth: currentData.curr.depth - 1,
        fullPage: fullPage,
      ),
    );
    super.didComplete(result);
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    _routeDataNotifier ??= () {
      final notifier = CupertinoSheetRoute.of(context);
      Future.microtask(() {
        notifier.value = TracableCupertinoSheetRouteData(
          prev: notifier.value.prev ?? CupertinoSheetRouteData.firstPage,
          curr: CupertinoSheetRouteData(
            depth: notifier.value.curr.depth + 1,
            fullPage: fullPage,
          ),
        );
      });
      return notifier;
    }();

    final size = MediaQuery.of(context).size;
    final BoxConstraints constrainsts;
    var borderRadius = const BorderRadius.vertical(top: Radius.circular(sheetCornerRadius));
    if (size.width > breakpointWidth) {
      if (isFirst) {
        return builder(context);
      }
      constrainsts = BoxConstraints(maxWidth: maxSize.width, maxHeight: min(size.height * 0.9, maxSize.height));
      borderRadius = const BorderRadius.all(Radius.circular(sheetCornerRadius));
    } else {
      constrainsts = BoxConstraints(
        minWidth: size.width,
      );
    }
    if (isFirst) {
      return builder(context);
    } else {
      final paddingTop = _paddingTop(context);
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: paddingTop + sheetOffset),
          child: CupertinoUserInterfaceLevel(
            data: CupertinoUserInterfaceLevelData.elevated,
            child: ConstrainedBox(
              constraints: constrainsts,
              child: Visibility(
                visible: barrierDismissible,
                replacement: ClipRRect(
                  borderRadius: borderRadius,
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: builder(context),
                  ),
                ),
                child: _gestureDetector(
                  size: size,
                  child: ClipRRect(
                    borderRadius: borderRadius,
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: builder(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.of(context).size.width > breakpointWidth) {
      if (isFirst) {
        return child;
      }
    }

    final routeDataNotifier = _routeDataNotifier ?? CupertinoSheetRoute.of(context);

    return ListenableBuilder(
      listenable: routeDataNotifier,
      builder: (context, _) => _ListenableCupertinoSheetRoute(
        routeData: _completed
            ? routeDataNotifier.value.prev ??
                CupertinoSheetRouteData(
                  depth: 2,
                  fullPage: fullPage,
                )
            : routeDataNotifier.value.curr,
        curve: _curve,
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        isFirst: isFirst,
        fullPage: fullPage,
        firstTransition: firstTransition,
        child: child,
      ),
    );
  }

  Widget _gestureDetector({required Widget child, required Size size}) {
    final Function(double velocity) dragEnd;
    dragEnd = (double velocity) {
      final bool animateForward;
      if (velocity.abs() >= 1.0) {
        animateForward = velocity <= 0;
      } else {
        animateForward = (controller?.value ?? 0) > 0.5;
      }
      if (animateForward) {
        controller?.animateTo(1.0, duration: transitionDuration, curve: Curves.easeInOut);
      } else {
        navigator?.pop();
      }
      if (controller?.isAnimating ?? false) {
        late AnimationStatusListener animationStatusCallback;
        animationStatusCallback = (AnimationStatus status) {
          navigator?.didStopUserGesture();
          controller?.removeStatusListener(animationStatusCallback);
        };
        controller?.addStatusListener(animationStatusCallback);
      } else {
        if (navigator?.userGestureInProgress ?? false) {
          navigator?.didStopUserGesture();
        }
      }
    };
    return GestureDetector(
      onVerticalDragEnd: (details) {
        dragEnd(details.velocity.pixelsPerSecond.dy / size.width);
      },
      onVerticalDragCancel: () {
        dragEnd(0);
      },
      onVerticalDragStart: (_) {
        navigator?.didStartUserGesture();
      },
      onVerticalDragUpdate: ((details) {
        _curve = Curves.linear;
        controller?.value -= details.delta.dy / size.height;
      }),
      child: child,
    );
  }

  double _paddingTop(BuildContext context) {
    var paddingTop = MediaQuery.of(context).padding.top;
    if (paddingTop <= 20) {
      paddingTop += 10;
    }
    return paddingTop;
  }
}

class _ListenableCupertinoSheetRoute extends StatefulWidget {
  const _ListenableCupertinoSheetRoute({
    required this.routeData,
    required this.curve,
    required this.animation,
    required this.secondaryAnimation,
    required this.isFirst,
    required this.fullPage,
    required this.firstTransition,
    required this.child,
  });

  final CupertinoSheetRouteData routeData;

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;

  final bool isFirst;
  final bool fullPage;
  final CupertinoModalSheetRouteTransition firstTransition;
  final Curve curve;

  final Widget child;

  @override
  State<_ListenableCupertinoSheetRoute> createState() => _ListenableCupertinoSheetRouteState();
}

class _ListenableCupertinoSheetRouteState extends State<_ListenableCupertinoSheetRoute> {
  CupertinoSheetRouteData? prevRouteData;
  ValueNotifier<CupertinoSheetRouteData>? routeDataNotifier;

  double _paddingTop(BuildContext context) {
    var paddingTop = MediaQuery.of(context).padding.top;
    if (paddingTop <= 20) {
      paddingTop += 10;
    }
    return paddingTop;
  }

  Widget _stackTransition(double offset, double scale, Animation<double> animation, Widget child) {
    return AnimatedBuilder(
      builder: (context, child) => Transform(
        transform: Matrix4.translationValues(0, offset, 0)..scale(scale),
        alignment: Alignment.topCenter,
        child: child,
      ),
      animation: animation,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final secValue = widget.secondaryAnimation.value;
    final paddingTop = _paddingTop(context);
    if (widget.isFirst) {
      var offset = secValue * paddingTop;
      var scale = 1 - secValue * scaleFactor;
      final r = paddingTop > 30 ? displayCornerRadius : 0.0;
      final radius = r - secValue * (r - sheetCornerRadius);
      final clipChild = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: widget.child,
      );

      if (widget.routeData.skipStackTransition) {
        offset = 0;
        scale = 1;
      }

      Widget transitionChild = _stackTransition(offset, scale, widget.secondaryAnimation, clipChild);

      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: transitionChild,
      );
    }
    if (widget.secondaryAnimation.isDismissed) {
      final tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero);
      final curveTween = CurveTween(curve: widget.curve);
      return SlideTransition(
        position: widget.animation.drive(curveTween).drive(tween),
        child: widget.child,
      );
    } else {
      final dist = (paddingTop + sheetOffset) * (1 - scaleFactor);
      final double offset = secValue * (paddingTop - dist);
      var scale = 1 - secValue * scaleFactor;

      return _stackTransition(offset, scale, widget.secondaryAnimation, widget.child);
    }
  }
}
