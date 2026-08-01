import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:flutter/material.dart';

class VerificationBanner extends StatelessWidget {
  const VerificationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, Routes.sellerIntroVerificationScreen,
            arguments: {"isResubmitted": false});
      },
      child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    child: Material(
    elevation: 6,
    color: Colors.transparent, // 🔥 REMOVE WHITE BACKGROUND
    borderRadius: BorderRadius.circular(15),
    clipBehavior: Clip.antiAlias, // 🔥 IMPORTANT
    child: Image.asset(
    "assets/verifiedBanner.png",
   // width: double.infinity,
  //  height: 190,
    fit: BoxFit.cover, // 🔥 use cover instead of fill
    ),
    ),
    ),
      // Material(
      //   elevation: 6,
      //   child: Container(
      //     margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      //     width: double.infinity,
      //     height: 190,
      //     decoration: BoxDecoration(
      //       borderRadius: BorderRadius.circular(15),
      //       color: context.color.bannerColor, // Using theme color
      //     ),
      //     child: Stack(
      //       children: [
      //         // Background decorations (circles to mimic the design)
      //         Positioned(
      //           left: -30,
      //           top: 10,
      //           child: CircleAvatar(
      //             radius: 4,
      //             backgroundColor: Colors.white.withValues(alpha: 0.3),
      //           ),
      //         ),
      //          Positioned(
      //           left: 30,
      //           top: 50,
      //           child: CircleAvatar(
      //             radius: 3,
      //             backgroundColor: Colors.white.withValues(alpha: 0.3),
      //           ),
      //         ),
      //         Positioned(
      //           left: 100,
      //           top: 20,
      //           child: CircleAvatar(
      //             radius: 5,
      //             backgroundColor: Colors.white.withValues(alpha: 0.3),
      //           ),
      //         ),
      //          Positioned(
      //           left: 80,
      //           bottom: 40,
      //           child: CircleAvatar(
      //             radius: 4,
      //             backgroundColor: Colors.white.withValues(alpha: 0.3),
      //           ),
      //         ),
      //          Positioned(
      //           right: 120,
      //           top: 50,
      //           child: CircleAvatar(
      //             radius: 2,
      //             backgroundColor: Colors.white.withValues(alpha: 0.3),
      //           ),
      //         ),
      //          Positioned(
      //           right: 20,
      //           bottom: 80,
      //           child: CircleAvatar(
      //             radius: 6,
      //             backgroundColor: Colors.white.withValues(alpha: 0.3),
      //           ),
      //         ),
      //
      //
      //         // Content
      //         Padding(
      //           padding: const EdgeInsets.all(16.0),
      //           child: Column(
      //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //             children: [
      //               Expanded(
      //                 child: Row(
      //                   crossAxisAlignment: CrossAxisAlignment.center,
      //                   children: [
      //                     // Badge Image
      //                      Padding(
      //                        padding: const EdgeInsetsDirectional.only(end: 12.0),
      //                        child: Image.asset(
      //                         "assets/verifiyedbanner.png",
      //                         height: 80, // Adjust size as needed
      //                         width: 80,
      //                         fit: BoxFit.contain,
      //                                                  ),
      //                      ),
      //
      //                     // Text Content
      //                     Expanded(
      //                       child: Column(
      //                         crossAxisAlignment: CrossAxisAlignment.start, // Align text to start
      //                         mainAxisAlignment: MainAxisAlignment.center,
      //                         children: [
      //                            Text(
      //                             "Got a verified badge yet?",
      //                             style: TextStyle( // Using fixed style to match design
      //                               fontSize: 18,
      //                               fontWeight: FontWeight.bold,
      //                               color: Colors.white,
      //                               height: 1.2
      //                             ),
      //                           ),
      //
      //                           const SizedBox(height: 8),
      //
      //                           Text(
      //                             "Get more Visibility | Enhance your Credibility",
      //                             style: TextStyle(
      //                               fontSize: 13,
      //                               color: Colors.white.withValues(alpha: 0.9),
      //                               height: 1.2
      //                             ),
      //                           ),
      //                         ],
      //                       ),
      //                     ),
      //                   ],
      //                 ),
      //               ),
      //
      //               // Button
      //               SizedBox(
      //                 width: double.infinity,
      //                 height: 48,
      //                 child: ElevatedButton(
      //                   onPressed: () {
      //                      Navigator.pushNamed(context, Routes.sellerIntroVerificationScreen,
      //         arguments: {"isResubmitted": false});
      //                   },
      //                   style: ElevatedButton.styleFrom(
      //                     backgroundColor: Colors.white,
      //                     foregroundColor: context.color.territoryColor, // Red color from theme usually
      //                     shape: RoundedRectangleBorder(
      //                       borderRadius: BorderRadius.circular(8),
      //                     ),
      //                     elevation: 0,
      //                   ),
      //                   child: const Text(
      //                     "GET STARTED",
      //                     style: TextStyle(
      //                       fontSize: 16,
      //                       fontWeight: FontWeight.bold,
      //                     ),
      //                   ),
      //                 ),
      //               ),
      //             ],
      //           ),
      //         ),
      //       ],
      //     ),
      //   ),
      // ),
    );
  }
}
