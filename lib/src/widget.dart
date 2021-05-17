part of '../flutter_advanced_drawer.dart';

/// AdvancedDrawer widget.
class AdvancedDrawer extends StatefulWidget {
  const AdvancedDrawer({
    Key? key,
    required this.child,
    required this.drawer,
    this.controller,
    this.backdropColor,
    this.openRatio = 0.75,
    this.animationDuration = const Duration(milliseconds: 250),
    this.animationCurve: Curves.ease,
    this.childDecoration,
    this.animateChildDecoration = true,
  }) : super(key: key);

  /// Child widget. (Usually widget that represent a screen)
  final Widget child;

  /// Drawer widget. (Widget behind the [child]).
  final Widget drawer;

  /// Controller that controls widget state.
  final AdvancedDrawerController? controller;

  /// Backdrop color.
  final Color? backdropColor;

  /// Opening ratio.
  final double openRatio;

  /// Animation duration.
  final Duration animationDuration;

  /// Animation curve.
  final Curve? animationCurve;

  /// Child container decoration in open widget state.
  final BoxDecoration? childDecoration;

  /// Indicates that [childDecoration] might be animated or not.
  /// NOTICE: It may cause animation jerks.
  final bool animateChildDecoration;

  @override
  _AdvancedDrawerState createState() => _AdvancedDrawerState();
}

class _AdvancedDrawerState extends State<AdvancedDrawer>
    with SingleTickerProviderStateMixin {
  late AdvancedDrawerController _controller;
  late AnimationController _animationController;
  late Animation<Offset> drawerTranslateAnimation;
  late Animation<double> drawerOpacityAnimation;
  late Animation<double> screenScalingTween;
  late double _offsetValue;
  late Offset _freshPosition;
  Offset? _startPosition;
  bool _captured = false;

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? AdvancedDrawerController();
    _controller.addListener(handleControllerChanged);

    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: _controller.value.visible! ? 1 : 0,
    );

    drawerTranslateAnimation = Tween<Offset>(
      begin: Offset(0, 50),
      end: Offset(0, 0),
    ).animate(
      CurvedAnimation(
        curve: Interval(
          0.3,
          1,
          curve: widget.animationCurve!,
        ),
        parent: _animationController,
      ),
    );

    drawerOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        curve: Interval(
          0.3,
          1,
          curve: widget.animationCurve!,
        ),
        parent: _animationController,
      ),
    );

    screenScalingTween = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(
      CurvedAnimation(
        curve: Interval(
          0,
          0.25,
          curve: widget.animationCurve!,
        ),
        parent: _animationController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.backdropColor,
      child: GestureDetector(
        onHorizontalDragStart: _handleDragStart,
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        onHorizontalDragCancel: _handleDragCancel,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxOffset = constraints.maxWidth * widget.openRatio;

            final screenTranslateTween = Tween<Offset>(
              begin: Offset(0, 0),
              end: Offset(maxOffset, 0),
            ).animate(CurvedAnimation(
              curve: Interval(
                0,
                0.5,
                curve: widget.animationCurve!,
              ),
              parent: _animationController,
            ));

            return Stack(
              children: <Widget>[
                // -------- DRAWER
                FractionallySizedBox(
                  widthFactor: widget.openRatio,
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: drawerOpacityAnimation.value,
                        child: Transform.translate(
                          offset: drawerTranslateAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      alignment: Alignment.centerLeft,
                      child: widget.drawer,
                    ),
                  ),
                ),
                // -------- CHILD
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: screenTranslateTween.value,
                      child: Transform.scale(
                        alignment: Alignment.centerLeft,
                        scale: screenScalingTween.value,
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: widget.animateChildDecoration
                              ? BoxDecoration.lerp(
                                  const BoxDecoration(
                                    boxShadow: const [],
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  widget.childDecoration,
                                  screenScalingTween.value,
                                )
                              : widget.childDecoration,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: ValueListenableBuilder<AdvancedDrawerValue>(
                    valueListenable: _controller,
                    builder: (_, value, child) {
                      if (value.visible!) {
                        return Stack(
                          children: [
                            child!,
                            if (value.visible!)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _controller.hideDrawer,
                                  highlightColor: Colors.transparent,
                                  child: Container(),
                                ),
                              ),
                          ],
                        );
                      }

                      return child!;
                    },
                    child: widget.child,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void handleControllerChanged() {
    _controller.value.visible!
        ? _animationController.forward()
        : _animationController.reverse();
  }

  void _handleDragStart(DragStartDetails details) {
    final screenSize = MediaQuery.of(context).size;

    final offset = screenSize.width * (1.0 - widget.openRatio);

    if (!_controller.value.visible! && details.globalPosition.dx > offset ||
        _controller.value.visible! &&
            details.globalPosition.dx < screenSize.width - offset) {
      _captured = false;
      return;
    }

    _captured = true;
    _startPosition = details.globalPosition;
    _offsetValue = _animationController.value;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_captured) {
      return;
    }

    final screenSize = MediaQuery.of(context).size;

    _freshPosition = details.globalPosition;

    final diff = (_freshPosition - _startPosition!).dx;

    _animationController.value =
        _offsetValue + diff / (screenSize.width * widget.openRatio);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_captured) return;

    _captured = false;
    _startPosition = null;

    if (_animationController.value >= 0.5) {
      _controller.showDrawer();

      if (_controller.value.visible!) {
        _animationController.animateTo(1);
      }
    } else {
      _controller.hideDrawer();

      if (!_controller.value.visible!) {
        _animationController.animateTo(0);
      }
    }
  }

  void _handleDragCancel() {
    _captured = false;
    _startPosition = null;
  }

  @override
  void dispose() {
    _animationController.dispose();

    if (widget.controller == null) {
      _controller.dispose();
    }

    super.dispose();
  }
}
