import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/sftp/sftp_service.dart';
import '../../core/theme/termul_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/termul_button.dart';
import '../../shared/widgets/termul_icon.dart';
import '../../shared/widgets/termul_icon_button.dart';
import '../../shared/widgets/termul_sheet.dart';
import 'sftp_link.dart';

/// Ukuran maksimum file teks yang dibuka di editor agar isi file tidak menghabiskan memori HP.
const sftpEditorMaxBytes = 1024 * 1024;

/// Editor teks satu file remote. Isi dibaca UTF-8 dan disimpan melalui unggahan sementara SFTP.
class SftpRemoteEditorScreen extends StatefulWidget {
  const SftpRemoteEditorScreen({super.key, required this.link, required this.entry});

  final SftpLink link;
  final SftpEntry entry;

  @override
  State<SftpRemoteEditorScreen> createState() => _SftpRemoteEditorScreenState();
}

class _SftpRemoteEditorScreenState extends State<SftpRemoteEditorScreen> {
  final _text = TextEditingController();
  final _editorScroll = ScrollController();
  final _scrollOffset = ValueNotifier<double>(0);
  final _lineTops = ValueNotifier<List<double>>(<double>[]);
  Timer? _lineLayoutTimer;
  double? _layoutWidth;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _saved = false;
  bool _tooLarge = false;
  bool _notText = false;
  String? _failure;
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    unawaited(_load());
  }

  @override
  void dispose() {
    _lineLayoutTimer?.cancel();
    _editorScroll.dispose();
    _scrollOffset.dispose();
    _lineTops.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final l = AppLocalizations.of(context);
    if (widget.entry.size != null && widget.entry.size! > sftpEditorMaxBytes) {
      if (mounted) {
        setState(() {
          _loading = false;
          _tooLarge = true;
        });
      }
      return;
    }
    final service = widget.link.service;
    if (service is! SftpFileOps || widget.link.lost) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failure = widget.link.lost ? l.sftpEditorConnectionLost : l.sftpEditorLoadFailed;
        });
      }
      return;
    }
    final ops = service as SftpFileOps;
    final controller = StreamController<List<int>>();
    final bytes = BytesBuilder(copy: false);
    final subscription = controller.stream.listen(bytes.add);
    final cancel = SftpCancelToken();
    var exceededLimit = false;
    try {
      await ops.download(
        widget.entry.path,
        controller.sink,
        onProgress: (received) {
          if (received > sftpEditorMaxBytes && !exceededLimit) {
            exceededLimit = true;
            cancel.cancel();
          }
        },
        cancel: cancel,
      );
      await controller.close();
      if (exceededLimit) {
        if (mounted) {
          setState(() {
            _loading = false;
            _tooLarge = true;
          });
        }
        return;
      }
      final data = bytes.takeBytes();
      if (data.length > sftpEditorMaxBytes) {
        exceededLimit = true;
      } else {
        final decoded = utf8.decode(data, allowMalformed: false);
        if (mounted) {
          _text.text = decoded;
          setState(() => _loading = false);
          _scheduleLineLayout();
        }
        return;
      }
    } on FormatException {
      if (mounted) {
        setState(() {
          _loading = false;
          _notText = true;
        });
      }
      return;
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _tooLarge = exceededLimit;
          _failure = exceededLimit ? null : (widget.link.lost ? l.sftpEditorConnectionLost : l.sftpEditorLoadFailed);
        });
      }
      return;
    } finally {
      if (!controller.isClosed) await controller.close();
      await subscription.cancel();
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _tooLarge = true;
      });
    }
  }

  // Jangan bangun ulang seluruh Scaffold untuk setiap karakter. Editor tetap menerima
  // input secara langsung; status layar hanya berubah saat pertama kali menjadi kotor.
  void _onTextChanged(String _) {
    if (!_dirty || _saved || _failure != null) {
      setState(() {
        _dirty = true;
        _saved = false;
        _failure = null;
      });
    }
    _scheduleLineLayout();
  }

  void _scheduleLineLayout() {
    _lineLayoutTimer?.cancel();
    _lineLayoutTimer = Timer(const Duration(milliseconds: 220), _updateLineLayout);
  }

  void _updateLineLayout() {
    if (!mounted || _layoutWidth == null) return;
    final text = _text.text;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TermulText.terminal.copyWith(color: TermulPalette.terminalInk),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: _layoutWidth!);
    final tops = <double>[0];
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 10) {
        tops.add(painter.getOffsetForCaret(TextPosition(offset: i + 1), Rect.zero).dy);
      }
    }
    painter.dispose();
    _lineTops.value = tops;
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_saving || !_dirty) return;
    if (widget.link.lost) {
      setState(() => _failure = l.sftpEditorConnectionLost);
      return;
    }
    final service = widget.link.service;
    if (service is! SftpFileOps) {
      setState(() => _failure = l.sftpEditorSaveFailed);
      return;
    }
    final ops = service as SftpFileOps;
    final data = Uint8List.fromList(utf8.encode(_text.text));
    if (data.length > sftpEditorMaxBytes) {
      setState(() => _tooLarge = true);
      return;
    }
    final transfer = widget.link.transfers.start(name: widget.entry.name, upload: true, total: data.length);
    setState(() {
      _saving = true;
      _failure = null;
      _saved = false;
    });
    try {
      await ops.upload(
        widget.entry.path,
        Stream<Uint8List>.value(data),
        onProgress: (sent) => widget.link.transfers.progress(transfer, sent),
        cancel: transfer.cancel,
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _dirty = false;
          _saved = true;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = widget.link.lost ? l.sftpEditorConnectionLost : l.sftpEditorSaveFailed;
        });
      }
    } finally {
      widget.link.transfers.finish(transfer);
    }
  }

  Future<void> _requestClose() async {
    if (_saving) return;
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final l = AppLocalizations.of(context);
    showTermulSheet<void>(
      context,
      title: l.sftpEditorLeaveTitle,
      child: Text(l.sftpEditorLeaveBody, style: TermulText.body.copyWith(color: TermulPalette.inkSoft)),
      cancelLabel: l.actionCancel,
      confirmLabel: l.sftpEditorLeaveAction,
      confirmIsDanger: true,
      cancelIsPrimary: true,
      onConfirm: () => Navigator.of(context).pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = _loading
        ? l.sftpEditorLoading
        : _saving
        ? l.sftpEditorSaving
        : _failure ?? (_dirty ? l.sftpEditorUnsaved : (_saved ? l.sftpEditorSaved : ''));
    final statusColor = _failure != null ? TermulPalette.bad : (_dirty ? TermulPalette.accent : TermulPalette.ok);
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestClose());
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TermulSpacing.space2,
                  TermulSpacing.space3,
                  TermulSpacing.space5,
                  TermulSpacing.space3,
                ),
                child: Row(
                  children: [
                    TermulIconButton(icon: TermulIconName.close, label: l.actionClose, onPressed: _requestClose),
                    const SizedBox(width: TermulSpacing.space2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TermulText.title.copyWith(fontFamily: TermulFonts.mono),
                          ),
                          if (status.isNotEmpty)
                            Text(
                              status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TermulText.caption.copyWith(color: statusColor),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: TermulSpacing.space2),
                    TermulButton(
                      label: l.sftpEditorSaveAction,
                      icon: TermulIconName.upload,
                      variant: TermulButtonVariant.primary,
                      size: TermulButtonSize.sm,
                      expand: false,
                      onPressed: _dirty && !_loading && !_saving && !_tooLarge && !_notText ? _save : null,
                    ),
                  ],
                ),
              ),
              if (_failure != null || _tooLarge || _notText)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TermulSpacing.space5,
                    0,
                    TermulSpacing.space5,
                    TermulSpacing.space3,
                  ),
                  child: Text(
                    _tooLarge ? l.sftpEditorTooLarge : (_notText ? l.sftpEditorNotText : _failure!),
                    style: TermulText.bodySm.copyWith(color: TermulPalette.bad),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TermulSpacing.space5,
                    0,
                    TermulSpacing.space5,
                    TermulSpacing.space5,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: TermulPalette.groundDeep,
                      borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
                      border: Border.all(color: TermulPalette.line),
                    ),
                    child: _loading
                        ? Center(
                            child: Text(
                              l.sftpEditorLoading,
                              style: TermulText.body.copyWith(color: TermulPalette.inkMuted),
                            ),
                          )
                        : (_failure != null || _tooLarge || _notText)
                        ? const SizedBox.expand()
                        : Semantics(
                            label: l.sftpEditorTitle,
                            textField: true,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                const horizontalPadding = TermulSpacing.space5;
                                const verticalPadding = TermulSpacing.space5;
                                const gutterWidth = 42.0;
                                final textWidth = (constraints.maxWidth - horizontalPadding * 2 - gutterWidth).clamp(
                                  1.0,
                                  double.infinity,
                                );
                                if (_layoutWidth != textWidth) {
                                  _layoutWidth = textWidth;
                                  WidgetsBinding.instance.addPostFrameCallback((_) => _updateLineLayout());
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: horizontalPadding,
                                    vertical: verticalPadding,
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: gutterWidth,
                                        child: ValueListenableBuilder<List<double>>(
                                          valueListenable: _lineTops,
                                          builder: (context, tops, _) => ValueListenableBuilder<double>(
                                            valueListenable: _scrollOffset,
                                            builder: (context, offset, _) => CustomPaint(
                                              painter: _LineNumberPainter(tops, offset),
                                              size: Size(gutterWidth, constraints.maxHeight - verticalPadding * 2),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: NotificationListener<ScrollNotification>(
                                          onNotification: (notification) {
                                            _scrollOffset.value = notification.metrics.pixels;
                                            return false;
                                          },
                                          child: TextField(
                                            controller: _text,
                                            scrollController: _editorScroll,
                                            enabled: !_saving,
                                            onChanged: _onTextChanged,
                                            expands: true,
                                            minLines: null,
                                            maxLines: null,
                                            keyboardType: TextInputType.multiline,
                                            textAlignVertical: TextAlignVertical.top,
                                            style: TermulText.terminal.copyWith(color: TermulPalette.terminalInk),
                                            cursorColor: TermulPalette.accent,
                                            autocorrect: false,
                                            enableSuggestions: false,
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineNumberPainter extends CustomPainter {
  const _LineNumberPainter(this.lineTops, this.scrollOffset);

  final List<double> lineTops;
  final double scrollOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final style = TermulText.caption.copyWith(fontFamily: TermulFonts.mono, color: TermulPalette.inkMuted);
    // Cari awal viewport agar scroll tidak memeriksa seluruh nomor baris pada file panjang.
    var low = 0;
    var high = lineTops.length;
    final firstVisibleY = scrollOffset - 24;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (lineTops[middle] < firstVisibleY) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    for (var i = low; i < lineTops.length && lineTops[i] <= scrollOffset + size.height; i++) {
      final y = lineTops[i] - scrollOffset;
      final label = TextPainter(
        text: TextSpan(text: '${i + 1}', style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      label.paint(canvas, Offset(size.width - label.width - 8, y));
      label.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _LineNumberPainter oldDelegate) =>
      oldDelegate.lineTops != lineTops || oldDelegate.scrollOffset != scrollOffset;
}
