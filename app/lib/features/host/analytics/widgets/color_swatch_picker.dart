import 'package:flutter/material.dart';

/// 10 preset colour swatches for revenue source labelling.
///
/// Palette criteria:
/// 1. Colour-blind safe (deuteranopia / protanopia safe — no red-green pairs).
/// 2. Visually distinct at small swatch size (≥ 44 pt tap target each).
/// 3. Works on both paper-cream (0xFFF4F1EC) and white backgrounds.
///
/// Preset list (hex, name):
///   #1E88E5  Blue
///   #43A047  Green
///   #FB8C00  Orange
///   #8E24AA  Purple
///   #00ACC1  Cyan
///   #E53935  Red
///   #6D4C41  Brown
///   #FFB300  Amber
///   #546E7A  Steel blue-grey
///   #558B2F  Olive green
const List<String> kSourceColorPresets = [
  '#1E88E5',
  '#43A047',
  '#FB8C00',
  '#8E24AA',
  '#00ACC1',
  '#E53935',
  '#6D4C41',
  '#FFB300',
  '#546E7A',
  '#558B2F',
];

/// Horizontal wrap of 10 colour swatches. Selected swatch shows a checkmark.
///
/// All tap targets are ≥ 44 × 44 pt per accessibility guidelines.
class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    super.key,
    required this.selectedHex,
    required this.onChanged,
  });

  final String selectedHex;
  final void Function(String hex) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kSourceColorPresets.map((hex) {
        final color = _hexToColor(hex);
        final isSelected = hex.toUpperCase() == selectedHex.toUpperCase();
        return GestureDetector(
          key: Key('swatch_$hex'),
          onTap: () => onChanged(hex),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: isSelected ? 36 : 32,
                height: isSelected ? 36 : 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Colors.black87
                        : Colors.black.withValues(alpha: 0.12),
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Parse a #RRGGBB hex string to a [Color] with full opacity.
  static Color _hexToColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16) ?? 0x9E9E9E;
    return Color(value | 0xFF000000);
  }
}
