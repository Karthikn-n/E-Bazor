import 'dart:async';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/cubits/slider_cubit.dart';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:Ebozor/data/repositories/item/item_repository.dart';
import 'package:Ebozor/ui/screens/home/home_screen.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart' as urllauncher;
import 'package:url_launcher/url_launcher.dart';

class SliderWidget extends StatefulWidget {
  const SliderWidget({super.key});

  @override
  State<SliderWidget> createState() => _SliderWidgetState();
}

class _SliderWidgetState extends State<SliderWidget>
    with AutomaticKeepAliveClientMixin {
  final ValueNotifier<int> _bannerIndex = ValueNotifier(0);
  Timer? _timer;
  int bannersLength = 0;
  final PageController _pageController = PageController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _startAutoSlider();
  }

  @override
  void dispose() {
    _bannerIndex.dispose();
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlider() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (bannersLength <= 1) return;
      final int nextPage = _bannerIndex.value + 1;
      if (nextPage < bannersLength) {
        _bannerIndex.value = nextPage;
      } else {
        _bannerIndex.value = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _bannerIndex.value,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    Widget buildIndicator() {
      return ValueListenableBuilder<int>(
        valueListenable: _bannerIndex,
        builder: (context, currentIndex, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(bannersLength, (index) {
              final bool isActive = index == currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                width: isActive ? 14 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isActive
                      ? context.color.territoryColor
                      : context.color.territoryColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          );
        },
      );
    }

    return BlocConsumer<SliderCubit, SliderState>(
      listener: (context, state) {},
      builder: (context, SliderState state) {
        if (state is SliderFetchSuccess && state.sliderlist.isNotEmpty) {
          bannersLength = state.sliderlist.length;
          final screenWidth = MediaQuery.sizeOf(context).width;
          final bannerCardWidth = (screenWidth - (sidePadding * 2)).clamp(200.0, 800.0);
          final bannerHeight = bannerCardWidth / 2.256;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: bannerHeight + 8,
                child: PageView.builder(
                  itemCount: bannersLength,
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    _bannerIndex.value = index;
                  },
                  itemBuilder: (context, index) {
                    final slider = state.sliderlist[index];
                    return InkWell(
                      onTap: () async {
                        if (slider.thirdPartyLink != null &&
                            slider.thirdPartyLink!.isNotEmpty) {
                          await urllauncher.launchUrl(
                            Uri.parse(slider.thirdPartyLink!),
                            mode: LaunchMode.externalApplication,
                          );
                        } else if (slider.modelId != null) {
                          if (slider.modelType != null &&
                              slider.modelType!.contains("Category")) {
                            Navigator.pushNamed(
                              context,
                              Routes.subCategoryScreen,
                              arguments: {
                                "catId": slider.modelId,
                                "catName": slider.model?.name ?? "",
                              },
                            );
                          } else {
                            try {
                              ItemRepository fetch = ItemRepository();
                              Widgets.showLoader(context);
                              DataOutput<ItemModel> dataOutput =
                                  await fetch.fetchItemFromItemId(slider.modelId!);
                              if (context.mounted) {
                                Widgets.hideLoder(context);
                                if (dataOutput.modelList.isNotEmpty) {
                                  Navigator.pushNamed(
                                    context,
                                    Routes.adDetailsScreen,
                                    arguments: {
                                      "model": dataOutput.modelList[0],
                                    },
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Widgets.hideLoder(context);
                                HelperUtils.showSnackBarMessage(
                                  context,
                                  "somethingWentWrng".translate(context),
                                );
                              }
                            }
                          }
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: sidePadding, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.grey.shade200,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: UiUtils.getImage(
                          slider.image ?? "",
                          fit: BoxFit.fill,
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (bannersLength > 1) buildIndicator(),
            ],
          );
        } else if (state is SliderFetchInProgress) {
          return const SizedBox.shrink();
        } else {
          final screenWidth = MediaQuery.sizeOf(context).width;
          final bannerCardWidth = (screenWidth - 32).clamp(200.0, 800.0);
          final bannerHeight = bannerCardWidth / 2.256;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/home_banner.png',
                height: bannerHeight,
                width: double.infinity,
                fit: BoxFit.fill,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          );
        }
      },
    );
  }
}
