import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/home/fetch_home_all_items_cubit.dart';
import 'package:Ebozor/data/cubits/home/fetch_home_screen_cubit.dart';
import 'package:Ebozor/data/cubits/system/location_change_cubit.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LocationWidget extends StatelessWidget {
  const LocationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationChangeCubit, LocationChangeState>(
      builder: (context, state) {
        final currentCity = state.displayName.isNotEmpty
            ? state.displayName
            : (HiveUtils.getCityName()?.toString().isNotEmpty == true
                ? HiveUtils.getCityName()!.toString()
                : 'Dushanbe');

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await Navigator.pushNamed(
              context,
              Routes.selectLocationScreen,
              arguments: const {"from": "home"},
            );
            if (context.mounted) {
              final activeCity = HiveUtils.getCityName()?.toString();
              context.read<FetchHomeScreenCubit>().fetch(
                    city: activeCity,
                    areaId: HiveUtils.getAreaId(),
                    country: HiveUtils.getCountryName(),
                    state: HiveUtils.getStateName(),
                  );
              context.read<FetchHomeAllItemsCubit>().fetch(
                    city: activeCity,
                    areaId: HiveUtils.getAreaId(),
                    radius: HiveUtils.getNearbyRadius(),
                    longitude: HiveUtils.getLongitude(),
                    latitude: HiveUtils.getLatitude(),
                    country: HiveUtils.getCountryName(),
                    state: HiveUtils.getStateName(),
                  );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: context.color.secondaryColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on,
                  size: 19,
                  color: Color(0xFF007AFF),
                ),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    currentCity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: context.color.textColorDark,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: context.color.textColorDark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
