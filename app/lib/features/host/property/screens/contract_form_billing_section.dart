import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';

/// Billing section for contract form — date range, rent, deposit, handover photos.

class ContractFormDatePicker extends StatelessWidget {
  const ContractFormDatePicker({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: HD.s12, vertical: HD.s12),
        decoration: BoxDecoration(
          border: Border.all(color: HD.hairline),
          borderRadius: BorderRadius.circular(HD.r8),
          color: HD.paperRaised,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: HD.eyebrow()),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 12, color: HD.inkSoft),
                const SizedBox(width: HD.s4),
                Text(
                  value ?? 'Chọn ngày',
                  style: HD.body(
                    size: 12,
                    color: value != null ? HD.ink : HD.inkMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ContractFormHandoverPhotos extends StatelessWidget {
  const ContractFormHandoverPhotos({
    super.key,
    required this.photoUrls,
    required this.isUploading,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  final List<String> photoUrls;
  final bool isUploading;
  final VoidCallback onAddPhoto;
  final void Function(int index) onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Ảnh bàn giao phòng', style: HD.bodyBold()),
            DsButton(
              label: 'Thêm ảnh',
              icon: Icons.add_photo_alternate_outlined,
              variant: DsButtonVariant.ghost,
              size: DsButtonSize.compact,
              onPressed: isUploading ? null : onAddPhoto,
            ),
          ],
        ),
        if (isUploading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: HD.s8),
            child: LinearProgressIndicator(
              color: HD.accent,
              backgroundColor: HD.hairline,
            ),
          ),
        if (photoUrls.isNotEmpty) ...[
          const SizedBox(height: HD.s8),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photoUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: HD.s8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(HD.r4),
                    child: Image.network(
                      photoUrls[i],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => onRemovePhoto(i),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: HD.negative,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 12, color: HD.paperRaised),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
