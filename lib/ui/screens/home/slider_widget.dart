/*
import 'dart:async';

import 'package:Ebozor/data/repositories/item/item_repository.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';

import '../../../data/cubits/slider_cubit.dart';
import '../../../data/helper/widgets.dart';
import '../../../data/model/data_output.dart';

import '../../../utils/Extensions/extensions.dart';
import '../../../utils/helper_utils.dart';
import '../../../utils/responsiveSize.dart';
import '../../../utils/ui_utils.dart';
import 'home_screen.dart';
import 'package:url_launcher/url_launcher.dart' as urllauncher;

class SliderWidget extends StatefulWidget {
  const SliderWidget({super.key});

  @override
  State<SliderWidget> createState() => _SliderWidgetState();
}

class _SliderWidgetState extends State<SliderWidget>
    with AutomaticKeepAliveClientMixin {
  final ValueNotifier<int> _bannerIndex = ValueNotifier(0);
  int bannersLength = 0;
  late Timer _timer;
  final PageController _pageController = PageController(
    initialPage: 0,
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_bannerIndex.value < bannersLength - 1) {
        _bannerIndex.value++;
      } else {
        _bannerIndex.value = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _bannerIndex.value,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeIn,
        );
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _bannerIndex.dispose();
    _timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocConsumer<SliderCubit, SliderState>(
      listener: (context, state) {
        if ((state is SliderFetchFailure && !state.isUserDeactivated) ||
            state is SliderFetchSuccess) {
          // context.read<SliderCubit>().fetchSlider(context);
        }
      },
      builder: (context, SliderState state) {
        if (state is SliderFetchInProgress) {
          return Container();
        }
        if (state is SliderFetchSuccess) {
          if (state.sliderlist.isNotEmpty)
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: sidePadding),
              child: SizedBox(
                height: 170.rh(context),
                child: ListView.builder(
                    itemCount: state.sliderlist.length,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, int index) {
                      return InkWell(
                        onTap: () async {
                          if (state.sliderlist[index].thirdPartyLink != "") {
                            await urllauncher.launchUrl(
                                Uri.parse(
                                    state.sliderlist[index].thirdPartyLink!),
                                mode: LaunchMode.externalApplication);
                          } else {
                            try {
                              ItemRepository fetch = ItemRepository();

                              Widgets.showLoader(context);

                              DataOutput<ItemModel> dataOutput =
                                  await fetch.fetchItemFromItemId(
                                      state.sliderlist[index].itemId!);

                              Future.delayed(
                                Duration.zero,
                                () {
                                  Widgets.hideLoder(context);
                                  Navigator.pushNamed(
                                      context, Routes.adDetailsScreen,
                                      arguments: {
                                        "model": dataOutput.modelList[0],
                                      });
                                },
                              );
                            } catch (e) {
                              Widgets.hideLoder(context);
                              HelperUtils.showSnackBarMessage(context,
                                  "somethingWentWrng".translate(context));
                            }
                          }
                        },
                        child: Container(
                          height: 170.rh(context),
                          clipBehavior: Clip.antiAlias,
                          width: context.screenWidth - (sidePadding * 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey.shade200,
                          ),
                          child: UiUtils.getImage(
                              state.sliderlist[index].image ?? "",
                              fit: BoxFit.cover),
                        ),
                      );
                    }),
              ),
            );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
*/

import 'dart:async';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/repositories/item/item_repository.dart';
import 'package:Ebozor/data/cubits/slider_cubit.dart';
import 'package:Ebozor/data/helper/widgets.dart';
import 'package:Ebozor/data/model/category_model.dart';
import 'package:Ebozor/data/model/data_output.dart';
import 'package:Ebozor/data/model/item/item_model.dart';
import 'package:url_launcher/url_launcher.dart' as urllauncher;

import 'package:Ebozor/ui/screens/home/home_screen.dart';
// Import your SliderCubit and other necessary dependencies

class SliderWidget extends StatefulWidget {
  const SliderWidget({super.key});

  @override
  State<SliderWidget> createState() => _SliderWidgetState();
}

class _SliderWidgetState extends State<SliderWidget>
    with AutomaticKeepAliveClientMixin {
  final ValueNotifier<int> _bannerIndex = ValueNotifier(0);
  late Timer _timer;
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
    super.dispose();
    _bannerIndex.dispose();
    _timer.cancel();
    _pageController.dispose(); // Dispose the PageController
  }

  void _startAutoSlider() {
    // Set up a timer to automatically change the banner index
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      final int nextPage = _bannerIndex.value + 1;
      if (nextPage < bannersLength) {
        _bannerIndex.value = nextPage;
      } else {
        _bannerIndex.value = 0;
      }
      _pageController.animateToPage(
        _bannerIndex.value,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }



  @override
  Widget build(BuildContext context) {
    Widget _buildIndicator() {
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
                width: isActive ? 12 : 8,
                height: isActive ?12:8,
                decoration: BoxDecoration(
                  color: isActive ? context.color.territoryColor:context.color.territoryColor.withValues(alpha: 0.5) ,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          );
        },
      );
    }
    super.build(context);

    return BlocConsumer<SliderCubit, SliderState>(
      listener: (context, state) {
        // Handle state changes if needed
      },
      builder: (context, SliderState state) {
        if (state is SliderFetchSuccess && state.sliderlist.isNotEmpty) {


          bannersLength = state.sliderlist.length; // Update bannersLength
           return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 170,
                child: PageView.builder(
                  itemCount: bannersLength,
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    _bannerIndex.value = index;
                  },
                  itemBuilder: (context, index) {
                    return InkWell(
                      onTap: () async {
                        // your existing onTap logic (UNCHANGED)
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: sidePadding),
                        width: MediaQuery.of(context).size.width - 16,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey.shade200,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: UiUtils.getImage(
                            state.sliderlist[index].image ?? "",
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 👇 Indicator
              _buildIndicator(),
            ],
          );

        } else {
          return SizedBox.shrink();
        }
      },
    );
  }
}



////

