import '../../app/workspace_navigation.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:edaya_shared/edaya_shared.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:signature/signature.dart';

import 'signature_encode.dart';

String signatureSessionKey(AppSessionController session) {
  final grants = session.grants.value;
  return '${session.user.value?.id}|${grants?.schoolId}|${grants?.kind}|${grants?.actorId}';
}

class SignatureEditorPage extends StatefulWidget {
  const SignatureEditorPage({
    super.key,
    required this.session,
    required this.identity,
    this.source,
    this.onComplete,
  });
  final AppSessionController session;
  final String identity;
  final img.Image? source;
  final ValueChanged<Uint8List?>? onComplete;

  @override
  State<SignatureEditorPage> createState() => _SignatureEditorPageState();
}

class _SignatureEditorPageState extends State<SignatureEditorPage> {
  final _signature = SignatureController(
    penStrokeWidth: 2.5,
    penColor: EdayaTokens.lightCardForeground,
    exportPenColor: EdayaTokens.lightCardForeground,
    strokeCap: StrokeCap.round,
    strokeJoin: StrokeJoin.round,
  );
  final _subscriptions = <StreamSubscription<dynamic>>[];
  img.Image? _source;
  Uint8List? _sourceBytes;
  Rect? _crop;
  Offset? _cropStart;
  bool _leaving = false;
  bool _confirmingClose = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _signature.addListener(_inkChanged);
    _source = widget.source;
    if (_source != null) {
      _sourceBytes = Uint8List.fromList(img.encodePng(_source!));
    }
    void changed() {
      if (!mounted ||
          _leaving ||
          signatureSessionKey(widget.session) == widget.identity) {
        return;
      }
      _leaving = true;
      setState(() {
        _signature.clear();
        _source = null;
        _sourceBytes = null;
        _crop = null;
      });
      if (widget.onComplete != null) {
        widget.onComplete!(null);
      } else {
        Navigator.of(context).pop();
      }
    }

    _subscriptions.add(widget.session.grants.stream.listen((_) => changed()));
    _subscriptions.add(widget.session.user.stream.listen((_) => changed()));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _signature.removeListener(_inkChanged);
    _signature.dispose();
    _sourceBytes = null;
    _source = null;
    super.dispose();
  }

  void _inkChanged() {
    if (mounted && !_leaving) setState(() {});
  }

  Offset _point(Offset point, Size size) => Offset(
    (point.dx / size.width).clamp(0.0, 1.0),
    (point.dy / size.height).clamp(0.0, 1.0),
  );

  Future<void> _use() async {
    if (_leaving ||
        _exporting ||
        signatureSessionKey(widget.session) != widget.identity) {
      return;
    }
    setState(() => _exporting = true);
    _signature.disabled = true;
    try {
      final source = _source;
      final Uint8List bytes;
      if (source == null) {
        final drawn = await _signature.toPngBytes();
        if (!mounted ||
            _leaving ||
            signatureSessionKey(widget.session) != widget.identity) {
          return;
        }
        if (drawn == null) throw const FormatException('SIGNATURE_EMPTY');
        bytes = encodeSignatureImage(decodeSignatureImage(drawn));
      } else {
        bytes = encodeSignatureImage(source, crop: _crop);
      }
      if (!mounted ||
          _leaving ||
          signatureSessionKey(widget.session) != widget.identity) {
        return;
      }
      _leaving = true;
      if (widget.onComplete != null) {
        widget.onComplete!(bytes);
      } else {
        Navigator.of(context).pop(bytes);
      }
    } catch (_) {
      if (mounted && !_leaving) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr.teacherSignatureTooLarge)),
        );
      }
    } finally {
      if (mounted && !_leaving) {
        _signature.disabled = false;
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final hasInk = _signature.isNotEmpty;
    return PopScope(
      canPop: _leaving || (!hasInk && _source == null && !_exporting),
      onPopInvokedWithResult: (popped, _) async {
        if (popped || _leaving || _exporting || _confirmingClose) return;
        _confirmingClose = true;
        final discard = await confirmWorkspaceDiscard(context);
        if (!mounted) return;
        _confirmingClose = false;
        if (!discard) return;
        setState(() => _leaving = true);
        await WidgetsBinding.instance.endOfFrame;
        if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
          closeWorkspaceSheet(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: widget.onComplete == null
              ? null
              : IconButton(
                  tooltip: 'Annuler',
                  icon: const Icon(Icons.close),
                  onPressed: () => widget.onComplete!(null),
                ),
          title: Text(
            source == null
                ? context.tr.teacherSignatureDraw
                : context.tr.teacherSignatureChooseImage,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  source == null
                      ? context.tr.teacherSignatureDrawHint
                      : context.tr.teacherSignatureCropHint,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final ratio = source == null
                            ? 1024 / 360
                            : source.width / source.height;
                        final width = math.min(
                          constraints.maxWidth,
                          constraints.maxHeight * ratio,
                        );
                        final size = Size(width, width / ratio);
                        return SizedBox(
                          width: size.width,
                          height: size.height,
                          child: Semantics(
                            label: source == null
                                ? context.tr.teacherSignatureDrawHint
                                : context.tr.teacherSignatureCropHint,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                EdayaTokens.radiusControl,
                              ),
                              child: source == null
                                  ? Signature(
                                      key: const ValueKey(
                                        'signature-editor-surface',
                                      ),
                                      controller: _signature,
                                      width: size.width,
                                      height: size.height,
                                      backgroundColor: EdayaTokens.lightCard,
                                    )
                                  : GestureDetector(
                                      key: const ValueKey(
                                        'signature-editor-surface',
                                      ),
                                      behavior: HitTestBehavior.opaque,
                                      onPanStart: (details) => setState(() {
                                        final point = _point(
                                          details.localPosition,
                                          size,
                                        );
                                        _cropStart = Offset(
                                          point.dx * source.width,
                                          point.dy * source.height,
                                        );
                                        _crop = null;
                                      }),
                                      onPanUpdate: (details) => setState(() {
                                        if (_cropStart == null) return;
                                        final point = _point(
                                          details.localPosition,
                                          size,
                                        );
                                        _crop = Rect.fromPoints(
                                          _cropStart!,
                                          Offset(
                                            point.dx * source.width,
                                            point.dy * source.height,
                                          ),
                                        );
                                      }),
                                      onPanEnd: (_) => setState(() {
                                        if (_crop != null &&
                                            (_crop!.width < 4 ||
                                                _crop!.height < 4)) {
                                          _crop = null;
                                        }
                                      }),
                                      child: ColoredBox(
                                        color: EdayaTokens.lightCard,
                                        child: CustomPaint(
                                          foregroundPainter: _CropPainter(
                                            _crop,
                                            Size(
                                              source.width.toDouble(),
                                              source.height.toDouble(),
                                            ),
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          child: Image.memory(
                                            _sourceBytes!,
                                            fit: BoxFit.fill,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (source == null) ...[
                      OutlinedButton.icon(
                        onPressed: !_signature.canUndo || _exporting
                            ? null
                            : _signature.undo,
                        icon: const Icon(Icons.undo),
                        label: Text(context.tr.teacherSignatureUndo),
                      ),
                      OutlinedButton.icon(
                        onPressed: _signature.isEmpty || _exporting
                            ? null
                            : _signature.clear,
                        icon: const Icon(Icons.clear),
                        label: Text(context.tr.teacherSignatureClear),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _source = img.copyRotate(source, angle: 90);
                          _sourceBytes = Uint8List.fromList(
                            img.encodePng(_source!),
                          );
                          _crop = null;
                        }),
                        icon: const Icon(Icons.rotate_right),
                        label: Text(context.tr.profilePhotoRotate),
                      ),
                      OutlinedButton(
                        onPressed: _crop == null
                            ? null
                            : () => setState(() => _crop = null),
                        child: Text(context.tr.teacherSignatureResetCrop),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: !_exporting && (source != null || hasInk)
                      ? _use
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: Text(context.tr.teacherSignatureUse),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.crop, this.sourceSize, this.color);
  final Rect? crop;
  final Size sourceSize;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (crop == null) return;
    final selection = Rect.fromLTRB(
      crop!.left / sourceSize.width * size.width,
      crop!.top / sourceSize.height * size.height,
      crop!.right / sourceSize.width * size.width,
      crop!.bottom / sourceSize.height * size.height,
    );
    final outside = Path()
      ..addRect(Offset.zero & size)
      ..addRect(selection)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(outside, Paint()..color = color.withValues(alpha: 0.25));
    canvas.drawRect(
      selection,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) =>
      crop != oldDelegate.crop ||
      color != oldDelegate.color ||
      sourceSize != oldDelegate.sourceSize;
}
