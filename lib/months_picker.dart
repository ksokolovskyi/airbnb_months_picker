// ignore_for_file: cascade_invocations, document_ignores

import 'dart:math' as math;
import 'dart:ui';

import 'package:airbnb_months_picker/extensions/extensions.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:tactile_feedback/tactile_feedback.dart';

/// The max allowed diameter of the picker.
const _maxDiameter = 350.0;

/// The number of ticks.
const _ticksCount = 12;

/// The max allowed angle (represents value 12).
const double _maxAngle = math.pi * 1.9999;

/// The min allowed angle (represents value 1).
const double _minAngle = _maxAngle / _ticksCount;

/// The angle between two ticks.
const double _tickAngle = _minAngle;

/// The duration needed to traverse one radian.
const _radianAnimationDuration = 30;

/// The min duration for thumb moving animation.
const _minAnimationDuration = 150;

// The factors to scale the pickers's diameter to determine the sizes of it's
// parts.
const double _trackPaddingFactor = 3.5 / 290;
const double _trackWidthFactor = 60 / 290 - 2 * _trackPaddingFactor;
const double _trackCornerRadiusFactor = 3 / 290;

const double _thumbPaddingFactor = 4.5 / 290;
const double _thumbDiameterFactor = _trackWidthFactor - _thumbPaddingFactor * 2;
const double _thumbFocusedBorderWidth = 2 / 44;

const double _tickDiameterFactor = 4 / 290;

const double _valueFontSizeFactor = 96 / 290;
const double _labelFontSizeFactor = 18 / 290;

/// The diameter of the picker in the Figma design.
const _designPickerDiameter = 450.0;

/// The diameter of the picker's thumb in the Figma design.
const _designThumbDiameter = 68.0;

/// {@template months_picker}
/// Circular picker that is used to select the number of months to stay.
/// {@endtemplate}
class MonthsPicker extends StatefulWidget {
  /// {@macro months_picker}
  const MonthsPicker({
    required this.value,
    required this.label,
    required this.onChanged,
    super.key,
  }) : assert(
         value >= 1 && value <= _ticksCount,
         'value have to be in range [1, $_ticksCount]',
       );

  /// The currently selected value (number of months).
  final int value;

  /// The label to show under the number of months selected.
  final String label;

  /// Called when new value is selected.
  ///
  /// The picker passes the new value to the callback and expects rebuild with
  /// the new value.
  final ValueChanged<int> onChanged;

  @override
  State<MonthsPicker> createState() => _MonthsPickerState();
}

class _MonthsPickerState extends State<MonthsPicker>
    with TickerProviderStateMixin {
  // Keyboard mapping for a focused picker.
  static const _traditionalNavShortcutMap = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowUp):
        _ValueAdjustmentIntent.increment(),
    SingleActivator(LogicalKeyboardKey.arrowDown):
        _ValueAdjustmentIntent.decrement(),
    SingleActivator(LogicalKeyboardKey.arrowLeft):
        _ValueAdjustmentIntent.decrement(),
    SingleActivator(LogicalKeyboardKey.arrowRight):
        _ValueAdjustmentIntent.increment(),
  };

  // Keyboard mapping for a focused picker when using directional navigation.
  // The vertical inputs are not handled to allow navigating out of the picker.
  static const _directionalNavShortcutMap = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowLeft):
        _ValueAdjustmentIntent.decrement(),
    SingleActivator(LogicalKeyboardKey.arrowRight):
        _ValueAdjustmentIntent.increment(),
  };

  late final _thumbScaleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 125),
  );

  late final Animation<double> _thumbScaleAnimation = Tween<double>(
    begin: 1,
    end: 1.04,
  ).chain(CurveTween(curve: Curves.easeInOut)).animate(_thumbScaleController);

  // Action mapping for a focused picker.
  late final _actionMap = <Type, Action<Intent>>{
    _ValueAdjustmentIntent: CallbackAction<_ValueAdjustmentIntent>(
      onInvoke: _actionHandler,
    ),
  };

  var _isFocused = false;

  @override
  void dispose() {
    _thumbScaleController.dispose();
    super.dispose();
  }

  void _actionHandler(_ValueAdjustmentIntent intent) {
    final newValue = switch (intent.type) {
      _ValueAdjustmentType.decrement => widget.value - 1,
      _ValueAdjustmentType.increment => widget.value + 1,
    }.clamp(1, _ticksCount);

    if (newValue == widget.value) {
      return;
    }

    _onChanged(newValue);
  }

  void _onChanged(int value) {
    TactileFeedback.impact();
    widget.onChanged(value);
  }

  void _handleFocusHighlightChanged(bool isFocused) {
    if (isFocused != _isFocused) {
      setState(() {
        _isFocused = isFocused;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortcutMap = switch (MediaQuery.navigationModeOf(context)) {
      NavigationMode.directional => _directionalNavShortcutMap,
      NavigationMode.traditional => _traditionalNavShortcutMap,
    };

    return Semantics(
      container: true,
      slider: true,
      child: FocusableActionDetector(
        actions: _actionMap,
        shortcuts: shortcutMap,
        onShowFocusHighlight: _handleFocusHighlightChanged,
        child: _MonthsPickerRenderObjectWidget(
          value: widget.value,
          label: widget.label,
          onChanged: _onChanged,
          vsync: this,
          background: _Background(value: widget.value),
          thumb: _Thumb(
            scaleAnimation: _thumbScaleAnimation,
            isFocused: _isFocused,
          ),
          onDragStart: () {
            _thumbScaleController.forward();
          },
          onDragEnd: () {
            _thumbScaleController.reverse();
          },
        ),
      ),
    );
  }
}

class _ValueAdjustmentIntent extends Intent {
  const _ValueAdjustmentIntent.increment()
    : type = _ValueAdjustmentType.increment;

  const _ValueAdjustmentIntent.decrement()
    : type = _ValueAdjustmentType.decrement;

  final _ValueAdjustmentType type;
}

enum _ValueAdjustmentType {
  increment,
  decrement,
}

class _Background extends SingleChildRenderObjectWidget {
  const _Background({
    required this.value,
  }) : super(
         child: const _BackgroundBox(),
       );

  final int value;

  @override
  _RenderBackground createRenderObject(BuildContext context) {
    return _RenderBackground(value: value);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBackground renderObject,
  ) {
    renderObject.value = value;
  }
}

class _BackgroundBox extends StatelessWidget {
  const _BackgroundBox();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: _maxDiameter,
        maxWidth: _maxDiameter,
      ),
      child: const AspectRatio(
        aspectRatio: 1,
        child: SizedBox.expand(),
      ),
    );
  }
}

class _RenderBackground extends RenderMouseRegion {
  _RenderBackground({
    required int value,
  }) : _value = value,
       _focusedValue = _stubFocusedValue;

  static const _stubFocusedValue = -1;

  int get value => _value;
  int _value;
  set value(int newValue) {
    if (newValue == _value) {
      return;
    }

    _value = newValue;
  }

  int _focusedValue;
  void _setFocusedValue(int value) {
    if (value == _focusedValue) {
      return;
    }

    // Don't repaint if focused tick is hidden under the track.
    if (value <= _value && value != _stubFocusedValue) {
      return;
    }

    _focusedValue = value;

    _clearCache();
    markNeedsPaint();
  }

  late Path _hitTestPath;
  late Offset _center;

  Picture? _cachedPicture;
  Rect? _cachedRect;

  @override
  PointerExitEventListener? get onExit {
    _setFocusedValue(_stubFocusedValue);
    return null;
  }

  @override
  void dispose() {
    _clearCache();
    super.dispose();
  }

  void _clearCache() {
    _cachedPicture?.dispose();
    _cachedPicture = null;
    _cachedRect = null;
  }

  @override
  bool hitTestSelf(Offset position) {
    return _hitTestPath.contains(position);
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    // ignore: prefer_asserts_with_message
    assert(debugHandleEvent(event, entry));

    if (event is PointerHoverEvent) {
      _setFocusedValue(
        _MonthsPickerConverter.convertPositionToIntValue(
          position: event.localPosition,
          center: _center,
        ),
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = offset & size;

    if (_cachedPicture == null || _cachedRect == null || _cachedRect != rect) {
      _clearCache();

      final outerCircle = rect;
      final outerCircleDiameter = rect.height;

      final innerCircle = rect.deflate(
        (_trackWidthFactor + _trackPaddingFactor * 2) * outerCircleDiameter,
      );

      _hitTestPath = Path.combine(
        PathOperation.difference,
        Path()..addOval(outerCircle),
        Path()..addOval(innerCircle),
      );
      _center = outerCircle.center;

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      final backgroundPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8E8E8), Color(0xFFF0F0F0)],
          stops: [0.11, 0.88],
        ).createShader(outerCircle);

      final shadow1 = const BoxShadow(
        offset: Offset(0, -9.94),
        blurRadius: 9.94,
        color: Color(0x38000000),
      ).resize(from: _designPickerDiameter, to: outerCircleDiameter);

      canvas
        ..drawCircleShadow(outerCircle, shadow1)
        ..drawOval(outerCircle, backgroundPaint);

      final shadow2 = const BoxShadow(
        offset: Offset(0, -4.97),
        blurRadius: 3.73,
        color: Colors.white,
      ).resize(from: _designPickerDiameter, to: outerCircleDiameter);
      final shadow3 = const BoxShadow(
        offset: Offset(0, 19.89),
        blurRadius: 39.78,
        color: Color(0x28000000),
      ).resize(from: _designPickerDiameter, to: outerCircleDiameter);
      final shadow4 = const BoxShadow(
        offset: Offset(0, -4.97),
        blurRadius: 29.83,
        color: Color(0x0A000000),
      ).resize(from: _designPickerDiameter, to: outerCircleDiameter);

      canvas
        ..drawCircleInsetShadow(outerCircle, shadow3)
        ..drawCircleInsetShadow(outerCircle, shadow4)
        ..drawCircleInsetShadow(outerCircle, shadow2);

      canvas.save();

      final tickPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF717171);
      final focusedTickPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF222222);

      final ticksCircle = outerCircle.deflate(
        (outerCircle.height - innerCircle.height) / 4,
      );
      final tickRect = Rect.fromCenter(
        center: Offset(ticksCircle.center.dx, ticksCircle.top),
        width: _tickDiameterFactor * outerCircleDiameter,
        height: _tickDiameterFactor * outerCircleDiameter,
      );

      final translation = Offset(
        outerCircleDiameter / 2,
        outerCircleDiameter / 2,
      );

      for (var i = 1; i <= _ticksCount; i++) {
        canvas
          ..translate(translation.dx, translation.dy)
          ..rotate(_tickAngle)
          ..translate(-translation.dx, -translation.dy)
          ..drawOval(
            tickRect,
            i == _focusedValue ? focusedTickPaint : tickPaint,
          );
      }

      canvas.restore();

      _cachedPicture = recorder.endRecording();
      _cachedRect = rect;
    }

    assert(
      _cachedPicture != null,
      'On this step _cachedPicture have to be initialized',
    );

    canvas.drawPicture(_cachedPicture!);
  }
}

class _Thumb extends LeafRenderObjectWidget {
  const _Thumb({
    required this.scaleAnimation,
    required this.isFocused,
  });

  final Animation<double> scaleAnimation;

  final bool isFocused;

  @override
  _RenderThumb createRenderObject(BuildContext context) {
    return _RenderThumb(
      scaleAnimation: scaleAnimation,
      isFocused: isFocused,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderThumb renderObject) {
    renderObject
      ..scaleAnimation = scaleAnimation
      ..isFocused = isFocused;
  }
}

class _RenderThumb extends RenderMouseRegion {
  _RenderThumb({
    required Animation<double> scaleAnimation,
    required bool isFocused,
  }) : _scaleAnimation = scaleAnimation,
       _isFocused = isFocused;

  Animation<double> get scaleAnimation => _scaleAnimation;
  Animation<double> _scaleAnimation;
  set scaleAnimation(Animation<double> value) {
    if (value == _scaleAnimation) {
      return;
    }

    _scaleAnimation.removeListener(markNeedsPaint);
    value.addListener(markNeedsPaint);

    _scaleAnimation = value;

    markNeedsPaint();
  }

  bool get isFocused => _isFocused;
  bool _isFocused;
  set isFocused(bool value) {
    if (value == _isFocused) {
      return;
    }

    _isFocused = value;
    markNeedsPaint();
  }

  @override
  MouseCursor get cursor {
    switch (_scaleAnimation.status) {
      case AnimationStatus.dismissed:
      case AnimationStatus.forward:
        return SystemMouseCursors.grab;

      case AnimationStatus.reverse:
      case AnimationStatus.completed:
        return SystemMouseCursors.grabbing;
    }
  }

  @override
  void attach(PipelineOwner owner) {
    _scaleAnimation.addListener(markNeedsPaint);
    super.attach(owner);
  }

  @override
  void detach() {
    _scaleAnimation.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;

    final thumbCircle = offset & size;
    final thumbDiameter = thumbCircle.width;
    final thumbCenter = thumbCircle.center;

    final scale = _scaleAnimation.value;

    canvas
      ..translate(thumbCenter.dx, thumbCenter.dy)
      ..scale(scale)
      ..translate(-thumbCenter.dx, -thumbCenter.dy);

    final thumbPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.white,
          Color(0xFFFDFDFD),
          Color(0xFFF1F1F1),
          Color(0xFFE0E0E0),
          Color(0xFFDEDEDE),
        ],
        stops: [0, 0.24, 0.5, 0.74, 1],
      ).createShader(thumbCircle);

    final shadow1 = const BoxShadow(
      offset: Offset(0, 2.49),
      blurRadius: 5,
      color: Color(0x2E000000),
    ).resize(from: _designThumbDiameter, to: thumbDiameter);

    canvas
      ..drawCircleShadow(thumbCircle, shadow1)
      ..drawOval(thumbCircle, thumbPaint);

    final shadow2 = const BoxShadow(
      offset: Offset(1.24, -2.49),
      blurRadius: 1.24,
      color: Color(0x28000000),
    ).resize(from: _designThumbDiameter, to: thumbDiameter);
    final shadow3 = const BoxShadow(
      offset: Offset(-1.24, -2.49),
      blurRadius: 1.24,
      color: Color(0x0F000000),
    ).resize(from: _designThumbDiameter, to: thumbDiameter);
    final shadow4 = const BoxShadow(
      offset: Offset(0, -2.49),
      blurRadius: 1.24,
      color: Color(0x14000000),
    ).resize(from: _designThumbDiameter, to: thumbDiameter);
    final shadow5 = const BoxShadow(
      offset: Offset(-1.24, 2.49),
      blurRadius: 1.24,
      color: Colors.white,
    ).resize(from: _designThumbDiameter, to: thumbDiameter);
    final shadow6 = const BoxShadow(
      offset: Offset(1.24, 2.49),
      blurRadius: 1.24,
      color: Colors.white,
    ).resize(from: _designThumbDiameter, to: thumbDiameter);
    final shadow7 = const BoxShadow(
      offset: Offset(0, 2.49),
      blurRadius: 1.24,
      color: Colors.white,
    ).resize(from: _designThumbDiameter, to: thumbDiameter);

    canvas
      ..drawCircleInsetShadow(thumbCircle, shadow2)
      ..drawCircleInsetShadow(thumbCircle, shadow3)
      ..drawCircleInsetShadow(thumbCircle, shadow4)
      ..drawCircleInsetShadow(thumbCircle, shadow5)
      ..drawCircleInsetShadow(thumbCircle, shadow6)
      ..drawCircleInsetShadow(thumbCircle, shadow7);

    if (isFocused) {
      final borderWidth = _thumbFocusedBorderWidth * thumbDiameter;

      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF222222)
        ..strokeWidth = borderWidth;

      canvas
        ..drawOval(
          thumbCircle.inflate(borderWidth * 0.5),
          borderPaint,
        )
        ..drawOval(
          thumbCircle.inflate(borderWidth * 1.5),
          borderPaint..color = Colors.white,
        );
    }
  }
}

enum _MonthsPickerSlot {
  background,
  thumb,
}

class _MonthsPickerRenderObjectWidget
    extends SlottedMultiChildRenderObjectWidget<_MonthsPickerSlot, RenderBox> {
  const _MonthsPickerRenderObjectWidget({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.vsync,
    required this.background,
    required this.thumb,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final int value;

  final String label;

  final ValueChanged<int> onChanged;

  final TickerProvider vsync;

  final Widget background;

  final Widget thumb;

  final VoidCallback onDragStart;

  final VoidCallback onDragEnd;

  @override
  Iterable<_MonthsPickerSlot> get slots => _MonthsPickerSlot.values;

  @override
  Widget? childForSlot(_MonthsPickerSlot slot) {
    return switch (slot) {
      _MonthsPickerSlot.background => background,
      _MonthsPickerSlot.thumb => thumb,
    };
  }

  @override
  _RenderMonthsPicker createRenderObject(BuildContext context) {
    return _RenderMonthsPicker(
      value: value,
      label: label,
      textDirection: Directionality.of(context),
      onChanged: onChanged,
      vsync: vsync,
      gestureSettings: MediaQuery.gestureSettingsOf(context),
      onDragStart: onDragStart,
      onDragEnd: onDragEnd,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMonthsPicker renderObject,
  ) {
    renderObject
      ..value = value
      ..label = label
      ..textDirection = Directionality.of(context)
      ..onChanged = onChanged
      ..vsync = vsync
      ..gestureSettings = MediaQuery.gestureSettingsOf(context)
      ..onDragStart = onDragStart
      ..onDragEnd = onDragEnd;
  }
}

class _RenderMonthsPicker extends RenderShiftedBox
    with SlottedContainerRenderObjectMixin<_MonthsPickerSlot, RenderBox>
    implements MouseTrackerAnnotation {
  _RenderMonthsPicker({
    required int value,
    required String label,
    required TextDirection textDirection,
    required ValueChanged<int> onChanged,
    required TickerProvider vsync,
    required DeviceGestureSettings gestureSettings,
    required VoidCallback onDragStart,
    required VoidCallback onDragEnd,
  }) : _value = value,
       _label = label,
       _textDirection = textDirection,
       _onChanged = onChanged,
       _vsync = vsync,
       _onDragStart = onDragStart,
       _onDragEnd = onDragEnd,
       _cursor = SystemMouseCursors.click,
       super(null) {
    _angleController = AnimationController(
      vsync: vsync,
      lowerBound: _minAngle,
      upperBound: _maxAngle,
    );
    _angleAnimation = _angleController;
    _angleAnimation.addListener(markNeedsPaint);

    _angleController.value = _MonthsPickerConverter.convertValueToAngle(
      value.toDouble(),
    );

    _drag = PanGestureRecognizer()
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _endInteraction
      ..gestureSettings = gestureSettings;
    _tap = TapGestureRecognizer()
      ..onTapUp = _handleTapUp
      ..onTapCancel = _endInteraction
      ..gestureSettings = gestureSettings;
  }

  int get value => _value;
  int _value;
  set value(int newValue) {
    if (newValue == _value) {
      return;
    }

    _value = newValue;

    if (_isInteracting) {
      return;
    }

    _updateAngleIfNeeded(
      _MonthsPickerConverter.convertValueToAngle(value.toDouble()),
    );
  }

  String get label => _label;
  String _label;
  set label(String value) {
    if (value == _label) {
      return;
    }

    _label = value;
    markNeedsPaint();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) {
      return;
    }

    _textDirection = value;
    markNeedsPaint();
  }

  ValueChanged<int> get onChanged => _onChanged;
  ValueChanged<int> _onChanged;
  set onChanged(ValueChanged<int> value) {
    if (value == _onChanged) {
      return;
    }

    _onChanged = value;
  }

  TickerProvider get vsync => _vsync;
  TickerProvider _vsync;
  set vsync(TickerProvider value) {
    if (value == _vsync) {
      return;
    }

    _vsync = value;
    _angleController.resync(vsync);
  }

  DeviceGestureSettings? get gestureSettings => _drag.gestureSettings;
  set gestureSettings(DeviceGestureSettings? gestureSettings) {
    _drag.gestureSettings = gestureSettings;
    _tap.gestureSettings = gestureSettings;
  }

  @override
  MouseCursor get cursor => _cursor;
  MouseCursor _cursor;
  set cursor(MouseCursor value) {
    if (_cursor != value) {
      _cursor = value;
      // A repaint is needed in order to trigger a device update of
      // [MouseTracker] so that this new value can be found.
      markNeedsPaint();
    }
  }

  @override
  PointerEnterEventListener? get onEnter => null;

  @override
  PointerExitEventListener? get onExit => null;

  @override
  bool get validForMouseTracker => true;

  @override
  bool get isRepaintBoundary => true;

  VoidCallback get onDragStart => _onDragStart;
  VoidCallback _onDragStart;
  set onDragStart(VoidCallback value) {
    if (value == _onDragStart) {
      return;
    }

    _onDragStart = value;
  }

  VoidCallback get onDragEnd => _onDragEnd;
  VoidCallback _onDragEnd;
  set onDragEnd(VoidCallback value) {
    if (value == _onDragEnd) {
      return;
    }

    _onDragEnd = value;
  }

  late final AnimationController _angleController;
  late final Animation<double> _angleAnimation;

  double get _angle => _angleAnimation.value;

  late final PanGestureRecognizer _drag;
  late final TapGestureRecognizer _tap;

  Offset _center = Offset.zero;
  Offset _dragPosition = Offset.zero;
  Offset _thumbPosition = Offset.zero;

  late int _announcedValue = _value;

  late final _valueTextPainter = TextPainter(
    textAlign: TextAlign.center,
    maxLines: 1,
  );
  late final _labelTextPainter = TextPainter(
    textAlign: TextAlign.center,
    maxLines: 1,
  );

  bool _isDragging = false;
  bool get _isInteracting =>
      _isDragging || _angleController.status == AnimationStatus.forward;

  RenderBox get _background => childForSlot(_MonthsPickerSlot.background)!;
  RenderBox get _thumb => childForSlot(_MonthsPickerSlot.thumb)!;

  static BoxParentData _boxParentData(RenderBox box) =>
      box.parentData! as BoxParentData;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _angleAnimation.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _angleController.stop();
    _angleAnimation.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _angleController.dispose();
    _drag.dispose();
    _tap.dispose();
    _valueTextPainter.dispose();
    _labelTextPainter.dispose();
    super.dispose();
  }

  /// Checks whether event position is on the background.
  bool _hitTestBackground(BoxHitTestResult result, {required Offset position}) {
    final backgroundParentData = _boxParentData(_background);

    return result.addWithPaintOffset(
      offset: backgroundParentData.offset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        // ignore: prefer_asserts_with_message
        assert(transformed == position - backgroundParentData.offset);
        return _background.hitTest(result, position: transformed);
      },
    );
  }

  /// Checks whether event position is on the thumb.
  bool _hitTestThumb(BoxHitTestResult result, {required Offset position}) {
    final thumbParentData = _boxParentData(_thumb);

    return result.addWithPaintOffset(
      offset: thumbParentData.offset,
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        // ignore: prefer_asserts_with_message
        assert(transformed == position - thumbParentData.offset);
        return _thumb.hitTest(result, position: transformed);
      },
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.contains(position)) {
      if (_hitTestThumb(result, position: position) ||
          _hitTestBackground(result, position: position)) {
        result.add(BoxHitTestEntry(this, position));
        return true;
      }
    }

    return false;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    // ignore: prefer_asserts_with_message
    assert(debugHandleEvent(event, entry));

    if (event is PointerDownEvent) {
      final didHitThumb = _hitTestThumb(
        BoxHitTestResult(),
        position: event.localPosition,
      );

      if (didHitThumb) {
        _drag.addPointer(event);
      } else {
        _tap.addPointer(event);
      }
    }
  }

  void _handleDragStart(DragStartDetails details) {
    onDragStart();
    _isDragging = true;
    _dragPosition = _thumbPosition;
    cursor = SystemMouseCursors.grabbing;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _dragPosition += details.delta;

    _updateAngleIfNeeded(
      _MonthsPickerConverter.convertPositionToAngle(
        position: _dragPosition,
        center: _center,
      ),
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    onDragEnd();
    _isDragging = false;
    cursor = SystemMouseCursors.click;

    final newValue = _MonthsPickerConverter.convertPositionToIntValue(
      position: _thumbPosition,
      center: _center,
    );

    _updateAngleIfNeeded(
      _MonthsPickerConverter.convertValueToAngle(newValue.toDouble()),
    );

    _endInteraction();
  }

  void _handleTapUp(TapUpDetails details) {
    final newValue = _MonthsPickerConverter.convertPositionToIntValue(
      position: details.localPosition,
      center: _center,
    );

    _announceValueIfNeeded(newValue);

    _endInteraction();
  }

  void _endInteraction() {
    _dragPosition = Offset.zero;
    _isDragging = false;
  }

  void _updateAngleIfNeeded(double newAngle) {
    if (newAngle == _angle) {
      return;
    }

    final newValue = _MonthsPickerConverter.convertAngleToIntValue(newAngle);

    if (_isDragging) {
      if (!_shouldUpdateAngle(newAngle)) {
        return;
      }

      _angleController.value = newAngle;
      _announceValueIfNeeded(newValue);
    } else {
      final milliseconds =
          (_angle - newAngle).abs() * _radianAnimationDuration +
          _minAnimationDuration;

      _angleController
          .animateTo(
            newAngle,
            curve: Curves.easeInOut,
            duration: Duration(milliseconds: milliseconds.round()),
          )
          .then((_) => _announceValueIfNeeded(newValue));
    }
  }

  void _announceValueIfNeeded(int newValue) {
    if (newValue != _announcedValue) {
      onChanged(newValue);
      _announcedValue = newValue;
    }
  }

  bool _shouldUpdateAngle(double newAngle) {
    final diff =
        _MonthsPickerConverter.convertAngleToDoubleValue(_angle) -
        _MonthsPickerConverter.convertAngleToDoubleValue(newAngle);
    return diff.abs() <= 1;
  }

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return _background.computeDryLayout(constraints);
  }

  @override
  void performLayout() {
    _background.layout(constraints, parentUsesSize: true);
    size = _background.size;

    final thumbDiameter = _thumbDiameterFactor * size.width;
    _thumb.layout(
      BoxConstraints.tightFor(
        height: thumbDiameter,
        width: thumbDiameter,
      ),
    );

    final rect = Offset.zero & size;

    _center = rect.center;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = offset & size;

    _drawBackground(context, offset);
    _drawTrack(
      context: context,
      canvas: canvas,
      rect: rect,
      offset: offset,
    );
    _drawCenter(canvas, rect);
  }

  void _drawBackground(PaintingContext context, Offset offset) {
    context.paintChild(_background, offset);
  }

  void _drawTrack({
    required PaintingContext context,
    required Canvas canvas,
    required Rect rect,
    required Offset offset,
  }) {
    canvas.save();

    final outerCircle = rect;
    final outerCircleDiameter = outerCircle.width;
    final outerCircleRadius = outerCircleDiameter / 2;
    final center = outerCircle.center;

    canvas.clipPath(Path()..addOval(outerCircle));

    const startAngle = -math.pi / 2;

    final trackWidth = outerCircleDiameter * _trackWidthFactor;
    final outerTrackCircle = outerCircle.deflate(
      _trackPaddingFactor * outerCircleDiameter,
    );
    final outerTrackCircleRadius = outerTrackCircle.width / 2;
    final innerTrackCircle = outerTrackCircle.deflate(trackWidth);
    final innerTrackCircleRadius = innerTrackCircle.width / 2;
    final cornerRadius = _trackCornerRadiusFactor * outerCircleDiameter;

    final correctionAngle = math.atan(cornerRadius / outerTrackCircleRadius);

    final innerThumbX =
        innerTrackCircleRadius * math.cos(startAngle + _angle) +
        outerCircleRadius;
    final innerThumbY =
        innerTrackCircleRadius * math.sin(startAngle + _angle) +
        outerCircleRadius;

    final topCornerRect = Rect.fromCenter(
      center: Offset(
        center.dx + cornerRadius,
        outerTrackCircle.top + cornerRadius,
      ),
      width: cornerRadius * 2,
      height: cornerRadius * 2,
    );
    final bottomCornerRect = Rect.fromCenter(
      center: Offset(
        center.dx + cornerRadius,
        innerTrackCircle.top - cornerRadius,
      ),
      width: cornerRadius * 2,
      height: cornerRadius * 2,
    );

    final path = Path()
      ..moveTo(topCornerRect.left, topCornerRect.bottom)
      ..arcTo(topCornerRect, math.pi, math.pi / 2, false)
      ..arcTo(
        outerTrackCircle,
        startAngle + correctionAngle,
        _angle - correctionAngle,
        false,
      )
      ..arcToPoint(
        Offset(innerThumbX, innerThumbY),
        radius: Radius.circular(trackWidth / 2),
      )
      ..arcTo(
        innerTrackCircle,
        startAngle + _angle,
        -_angle + correctionAngle * 2,
        false,
      )
      ..arcTo(bottomCornerRect, math.pi / 2, math.pi / 2, false)
      ..close();

    final shadow1 = const BoxShadow(
      blurRadius: 14.92,
      color: Color(0xFFEC294D),
    ).resize(from: _designPickerDiameter, to: outerCircleDiameter);
    final shadow2 = const BoxShadow(
      blurRadius: 14.92,
      color: Color(0xA3000000),
    ).resize(from: _designPickerDiameter, to: outerCircleDiameter);

    canvas
      ..drawPathShadow(path, shadow1)
      ..drawPathShadow(path, shadow2);

    final thumbCenterX =
        (innerTrackCircleRadius + trackWidth / 2) *
        math.cos(startAngle + _angle);
    final thumbCenterY =
        (innerTrackCircleRadius + trackWidth / 2) *
        math.sin(startAngle + _angle);

    _thumbPosition = Offset(thumbCenterX, thumbCenterY).translate(
      outerCircleRadius,
      outerCircleRadius,
    );

    final shadow3 = const BoxShadow(
      blurRadius: 30,
      color: Color(0x44F52A2A),
    ).resize(from: _designPickerDiameter, to: outerCircleDiameter);

    canvas
      ..drawCircleShadow(
        Rect.fromCircle(
          center: Offset(center.dx + 10, outerTrackCircle.top + trackWidth / 2),
          radius: trackWidth / 1.2,
        ),
        shadow3,
      )
      ..drawCircleShadow(
        Rect.fromCircle(center: _thumbPosition, radius: trackWidth),
        shadow3,
      );

    final gradientPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill
      ..shader = const RadialGradient(
        colors: [
          Color(0xFFD93B69),
          Color(0xFFDB4B78),
          Color(0xFFD53270),
          Color(0xFFD41E64),
          Color(0xFFDC0F5A),
          Color(0xFFE71858),
          Color(0xFFEE2E5D),
          Color(0xFFED4960),
        ],
        stops: [0.63, 0.66, 0.70, 0.73, 0.79, 0.86, 0.91, 1],
      ).createShader(outerTrackCircle);

    canvas.drawPath(path, gradientPaint);

    /// Drawing thumb.
    final thumbRadius = _thumb.size.width / 2;
    final thumbParentData = _boxParentData(_thumb);
    thumbParentData.offset = _thumbPosition.translate(
      -thumbRadius,
      -thumbRadius,
    );
    context.paintChild(_thumb, thumbParentData.offset + offset);

    canvas.restore();
  }

  void _drawCenter(Canvas canvas, Rect outerCircle) {
    final outerCircleDiameter = outerCircle.width;

    final circle = outerCircle.deflate(
      (_trackWidthFactor + _trackPaddingFactor * 2) * outerCircleDiameter,
    );
    final circleDiameter = circle.width;
    final center = circle.center;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF2F2F2),
          Color(0xFFF7F7F7),
          Color(0xFFFFFFFF),
        ],
        stops: [0, 0.5, 1],
      ).createShader(circle);

    final shadow1 = const BoxShadow(
      offset: Offset(0, 24.86),
      blurRadius: 14.92,
      color: Color(0x0A000000),
    ).resize(from: _designPickerDiameter, to: outerCircleDiameter);
    final shadow2 = const BoxShadow(
      offset: Offset(0, 24.86),
      blurRadius: 24.86,
      color: Color(0x0F000000),
    ).resize(from: _designPickerDiameter, to: outerCircleDiameter);
    final shadow3 = const BoxShadow(
      offset: Offset(0, 24.86),
      blurRadius: 39.78,
      color: Color(0x1A000000),
    ).resize(from: _designPickerDiameter, to: outerCircleDiameter);

    canvas
      ..drawCircleShadow(circle, shadow1)
      ..drawCircleShadow(circle, shadow2)
      ..drawCircleShadow(circle, shadow3)
      ..drawOval(circle, paint);

    final shadow4 = const BoxShadow(
      offset: Offset(0, -9.94),
      blurRadius: 9.94,
      color: Color(0x38000000),
    ).resize(from: _designPickerDiameter, to: outerCircleDiameter);
    final shadow5 = const BoxShadow(
      offset: Offset(0, 7.46),
      blurRadius: 7.46,
      color: Colors.white,
    ).resize(from: _designPickerDiameter, to: outerCircleDiameter);

    canvas
      ..drawCircleInsetShadow(circle, shadow5)
      ..drawCircleInsetShadow(circle, shadow4);

    _valueTextPainter
      ..textDirection = textDirection
      ..text = TextSpan(
        text: '$value',
        style: TextStyle(
          fontFamily: 'Figtree',
          fontWeight: FontWeight.bold,
          fontSize: _valueFontSizeFactor * outerCircleDiameter,
          height: 1,
          color: const Color(0xFF222222),
        ),
      );
    _valueTextPainter.layout(
      maxWidth: circleDiameter * 0.65,
      minWidth: circleDiameter / 2,
    );
    _valueTextPainter.paint(
      canvas,
      center.translate(
        -_valueTextPainter.width / 2,
        -_valueTextPainter.height / 2,
      ),
    );

    _labelTextPainter
      ..textDirection = textDirection
      ..text = TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'Figtree',
          fontWeight: FontWeight.bold,
          fontSize: _labelFontSizeFactor * outerCircleDiameter,
          height: 1,
          overflow: TextOverflow.ellipsis,
          color: const Color(0xFF222222),
        ),
      );
    _labelTextPainter.layout(
      maxWidth: circleDiameter * 0.65,
      minWidth: circleDiameter / 2,
    );
    _labelTextPainter.paint(
      canvas,
      center.translate(
        -_labelTextPainter.width / 2,
        -_labelTextPainter.height / 2 + _valueTextPainter.height / 2,
      ),
    );
  }
}

abstract class _MonthsPickerConverter {
  /// Converts [position] in local coordinates into the integer value in the
  /// range [1, 12].
  static int convertPositionToIntValue({
    required Offset position,
    required Offset center,
  }) {
    return convertAngleToIntValue(
      convertPositionToAngle(
        position: position,
        center: center,
      ),
    );
  }

  /// Converts [position] in local coordinates into the angle in the range
  /// [_minAngle, _maxAngle].
  static double convertPositionToAngle({
    required Offset position,
    required Offset center,
  }) {
    // Calculate the differences in x and y coordinates.
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;

    // Use arctangent to calculate the angle.
    var newAngle = math.atan2(dy, dx) + math.pi / 2;

    // Adjust angle to be in the range [0, 2 * pi) or [0, 360) degrees.
    if (newAngle < 0) {
      newAngle += _maxAngle;
    }

    return newAngle.clamp(_minAngle, _maxAngle);
  }

  /// Converts angle into the integer value in the range [1, 12].
  static int convertAngleToIntValue(double angle) {
    return convertAngleToDoubleValue(angle).round();
  }

  /// Converts angle into the floating point value in the range [1.0, 12.0].
  static double convertAngleToDoubleValue(double angle) {
    return angle / _tickAngle;
  }

  /// Converts value in the range [1.0, 12.0] into the angle in the range
  /// [_minAngle, _maxAngle].
  static double convertValueToAngle(double value) {
    return (value * _tickAngle).clamp(_minAngle, _maxAngle);
  }
}
