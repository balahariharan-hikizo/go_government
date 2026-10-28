import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../utils/app_colors.dart';
import '../utils/responsive_helper.dart';
import '../widget/custom_text.dart';
import '../constants/route_constants.dart';
import '../service/location_service.dart';

enum DirectionsButtonStyle { circle, wide, card }

class CommonDirectionsButton extends StatelessWidget {
  final String title;
  final String address;
  final LatLng? destinationCoords;
  final LatLng? originCoords; // manual/picked location as route start
  final DirectionsButtonStyle style;

  const CommonDirectionsButton({
    super.key,
    required this.title,
    required this.address,
    this.destinationCoords,
    this.originCoords,
    required this.style,
  });

  static int _lastTapTime = 0;

  @override
  Widget build(BuildContext context) {
    void onTap() {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastTapTime < 500) return;
      _lastTapTime = now;

      debugPrint("Directions button tapped for: $title - $address");
      LatLng? effOrigin = originCoords;
      if (effOrigin == null && LocationService.hasManualLocation) {
        final mPos = LocationService.getManualPosition();
        if (mPos != null) {
          effOrigin = LatLng(mPos.latitude, mPos.longitude);
        }
      }

      Navigator.of(context).pushNamed(
        RouteConstants.directions,
        arguments: {
          'title': title,
          'address': address,
          ...?destinationCoords != null ? {'destinationCoords': destinationCoords} : null,
          ...?effOrigin != null ? {'originCoords': effOrigin} : null,
        },
      );
    }


    if (style == DirectionsButtonStyle.circle) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: Responsive.w(44),
          height: Responsive.w(44),
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.outliner,
              width: Responsive.w(1.5),
            ),
          ),
          child: Icon(
            Icons.directions_outlined,
            color: AppColors.black,
            size: Responsive.w(22),
          ),
        ),
      );
    } else if (style == DirectionsButtonStyle.wide) {
      return Container(
        height: Responsive.h(48),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6F3),
          borderRadius: BorderRadius.circular(Responsive.w(16)),
          border: Border.all(
            color: AppColors.primary,
            width: Responsive.w(1.5),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Responsive.w(16)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(Responsive.w(4)),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.near_me_outlined,
                    color: AppColors.primary,
                    size: Responsive.w(16),
                  ),
                ),
                SizedBox(width: Responsive.w(12)),
                CustomText.title(
                  'Directions',
                  color: AppColors.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // DirectionsButtonStyle.card style
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: Responsive.h(36),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(Responsive.w(18)),
            border: Border.all(
              color: AppColors.primary,
              width: Responsive.w(1.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.navigation,
                color: AppColors.primary,
                size: Responsive.w(14),
              ),
              SizedBox(width: Responsive.w(8)),
              CustomText.title(
                'Directions',
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
        ),
      );
    }
  }
}
