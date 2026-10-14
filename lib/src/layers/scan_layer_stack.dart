import 'package:flutter/widgets.dart';

import '../animation/scan_fx_frame.dart';
import '../theme/scan_fx_style.dart';
import 'scan_layer.dart';

/// One entry in a [ScanLayerStack]: a layer plus its visibility.
@immutable
class ScanLayerEntry {
  /// Creates an entry.
  const ScanLayerEntry(this.layer, {this.visible = true});

  /// The layer to draw.
  final ScanLayer layer;

  /// Whether the layer participates in the frame.
  final bool visible;

  /// Copy with overrides.
  ScanLayerEntry copyWith({ScanLayer layer, bool? visible}) =>
      ScanLayerEntry(layer ?? this.layer, visible: visible ?? this.visible);

  @override
  bool operator ==(Object other) =>
      other is ScanLayerEntry && other.layer == layer && other.visible == visible;

  @override
  int get hashCode => Object.hash(layer, visible);
}

/// An ordered, immutable list of [ScanLayer]s.
///
/// Hosts receive the default stack through `QrScanFx(layers: ...)` and may
/// reorder, hide, replace or extend it. Every mutator returns a **new** stack, so
/// the painter can compare stacks cheaply and nothing is mutated behind the
/// animation core's back.
///
/// ```dart
/// QrScanFx(
///   layers: (context, stack) => stack
///       .replace(ScanLayerKind.beam, const MyBeam())
///       .hide(ScanLayerKind.hint),
///   child: cameraPreview,
/// )
/// ```
@immutable
class ScanLayerStack {
  /// Creates a stack from explicit entries.
  ///
  /// The list is not copied, so pass a list you do not mutate afterwards.
  const ScanLayerStack(this.entries);

  /// Creates a stack from layers, all visible.
  factory ScanLayerStack.of(List<ScanLayer> layers) =>
      ScanLayerStack(List<ScanLayerEntry>.unmodifiable(
        layers.map((layer) => ScanLayerEntry(layer)),
      ));

  /// The entries, in paint order (first is furthest back).
  final List<ScanLayerEntry> entries;

  /// Whether any layer in the stack depends on animated values.
  bool get hasAnimatedLayers {
    for (final entry in entries) {
      if (entry.visible && entry.layer.animated) return true;
    }
    return false;
  }

  /// Whether any layer in the stack wants a widget-level hook at all.
  bool get wantsWidget {
    for (final entry in entries) {
      if (entry.visible && (entry.layer.wantsWidget || entry.layer.wantsOverlay)) {
        return true;
      }
    }
    return false;
  }

  /// The first visible layer of [kind], or `null`.
  ScanLayer? find(ScanLayerKind kind) {
    for (final entry in entries) {
      if (entry.layer.kind == kind) return entry.layer;
    }
    return null;
  }

  /// Replaces the first layer of [kind] with [layer], keeping its position.
  ScanLayerStack replace(ScanLayerKind kind, ScanLayer layer) {
    final list = List<ScanLayerEntry>.of(entries);
    for (var i = 0; i < list.length; i++) {
      if (list[i].layer.kind == kind) {
        list[i] = ScanLayerEntry(layer, visible: list[i].visible);
        return ScanLayerStack(list);
      }
    }
    list.add(ScanLayerEntry(layer));
    return ScanLayerStack(list);
  }

  /// Replaces the entry at [index].
  ScanLayerStack replaceAt(int index, ScanLayer layer) {
    if (index < 0 || index >= entries.length) return this;
    final list = List<ScanLayerEntry>.of(entries);
    list[index] = ScanLayerEntry(layer, visible: list[index].visible);
    return ScanLayerStack(list);
  }

  /// Hides every layer of [kind].
  ScanLayerStack hide(ScanLayerKind kind) => _setVisible(kind, false);

  /// Shows every layer of [kind], if present.
  ScanLayerStack show(ScanLayerKind kind) => _setVisible(kind, true);

  ScanLayerStack _setVisible(ScanLayerKind kind, bool visible) {
    final list = List<ScanLayerEntry>.of(entries);
    var changed = false;
    for (var i = 0; i < list.length; i++) {
      if (list[i].layer.kind == kind && list[i].visible != visible) {
        list[i] = list[i].copyWith(visible: visible);
        changed = true;
      }
    }
    return changed ? ScanLayerStack(list) : this;
  }

  /// Removes every layer of [kind].
  ScanLayerStack remove(ScanLayerKind kind) {
    final list = entries.where((e) => e.layer.kind != kind).toList();
    return list.length == entries.length ? this : ScanLayerStack(list);
  }

  /// Inserts [layer] at [index].
  ScanLayerStack insert(int index, ScanLayer layer) {
    final list = List<ScanLayerEntry>.of(entries);
    list.insert(index.clamp(0, list.length), ScanLayerEntry(layer));
    return ScanLayerStack(list);
  }

  /// Appends [layer].
  ScanLayerStack add(ScanLayer layer) => ScanLayerStack(
        List<ScanLayerEntry>.of(entries)..add(ScanLayerEntry(layer)),
      );

  /// Moves the layer at [from] to [to].
  ScanLayerStack reorder(int from, int to) {
    if (from < 0 || from >= entries.length) return this;
    final list = List<ScanLayerEntry>.of(entries);
    final entry = list.removeAt(from);
    list.insert(to.clamp(0, list.length), entry);
    return ScanLayerStack(list);
  }

  /// Builds every widget-level effect that renders *under* the painter, in paint
  /// order.
  List<Widget> buildUnderlays(BuildContext context, ScanFxFrame frame) {
    final widgets = <Widget>[];
    for (final entry in entries) {
      if (!entry.visible) continue;
      final widget = entry.layer.buildEffect(context, frame);
      if (widget != null) widgets.add(widget);
    }
    return widgets;
  }

  /// Builds every widget-level element that renders *above* the painter, in
  /// paint order.
  List<Widget> buildOverlays(BuildContext context, ScanFxFrame frame) {
    final widgets = <Widget>[];
    for (final entry in entries) {
      if (!entry.visible) continue;
      final widget = entry.layer.buildOverlay(context, frame);
      if (widget != null) widgets.add(widget);
    }
    return widgets;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ScanLayerStack) return false;
    if (other.entries.length != entries.length) return false;
    for (var i = 0; i < entries.length; i++) {
      if (entries[i] != other.entries[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(entries);
}
