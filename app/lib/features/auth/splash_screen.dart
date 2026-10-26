import 'package:flutter/material.dart';

import 'package:house_booking/core/config/brand.dart';
import 'package:house_booking/core/widgets/ds.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HD.paper,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Chỗ này trước là ô bo góc lồng `Icons.apartment_rounded` —
              // icon Material mặc định, không phải nhận diện của mình.
              const BrandLogo.full(size: 96),
              const SizedBox(height: HD.s20),
              Text('Nhật báo vận hành', style: HD.eyebrow()),
              const SizedBox(height: HD.s4),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: Brand.logoPart1,
                      style: HD.masthead(size: 38),
                    ),
                    TextSpan(
                      text: Brand.logoPart2,
                      style: HD.mastheadItalic(color: HD.accent, size: 38),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: HD.s32),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: HD.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
