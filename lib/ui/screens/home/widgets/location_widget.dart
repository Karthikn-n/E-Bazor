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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: context.color.secondaryColor.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.color.borderColor.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 17,
                  color: context.color.territoryColor,
                ),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    currentCity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.color.textColorDark,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: context.color.textColorDark.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
