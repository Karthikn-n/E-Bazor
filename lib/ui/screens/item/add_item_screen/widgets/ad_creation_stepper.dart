import 'package:flutter/material.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';

class AdCreationStepper extends StatelessWidget {
  final int currentStep; // 1: Details, 2: Photos, 3: Price, 4: Review

  const AdCreationStepper({
    super.key,
    required this.currentStep,
  });

  static const List<String> _steps = ['Details', 'Photos', 'Price', 'Review'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.color.secondaryColor,
        border: Border(
          bottom: BorderSide(
            color: context.color.borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_steps.length, (index) {
          final stepNumber = index + 1;
          final isCurrent = currentStep == stepNumber;
          final isCompleted = currentStep > stepNumber;

          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Left connecting line
                    Expanded(
                      child: index == 0
                          ? const SizedBox.shrink()
                          : Container(
                              height: 2,
                              color: currentStep > index
                                  ? const Color(0xFF007AFF)
                                  : context.color.borderColor
                                      .withValues(alpha: 0.6),
                            ),
                    ),
                    // Step number circle
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrent || isCompleted
                            ? const Color(0xFF007AFF)
                            : context.color.backgroundColor,
                        border: Border.all(
                          color: isCurrent || isCompleted
                              ? const Color(0xFF007AFF)
                              : context.color.borderColor,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: Colors.white,
                              )
                            : Text(
                                '$stepNumber',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent
                                      ? Colors.white
                                      : context.color.textLightColor,
                                ),
                              ),
                      ),
                    ),
                    // Right connecting line
                    Expanded(
                      child: index == _steps.length - 1
                          ? const SizedBox.shrink()
                          : Container(
                              height: 2,
                              color: currentStep > index + 1
                                  ? const Color(0xFF007AFF)
                                  : context.color.borderColor
                                      .withValues(alpha: 0.6),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _steps[index],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent
                        ? const Color(0xFF007AFF)
                        : isCompleted
                            ? context.color.textDefaultColor
                            : context.color.textLightColor,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
