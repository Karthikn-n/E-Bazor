import 'package:flutter/material.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';

class AdCreationStepper extends StatelessWidget {
  final int currentStep; // 1: Details, 2: Photos, 3: Price, 4: Review
  final ValueChanged<int>? onStepTapped;

  const AdCreationStepper({
    super.key,
    required this.currentStep,
    this.onStepTapped,
  });

  static const List<String> _steps = ['Details', 'Photos', 'Price', 'Review'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: context.color.backgroundColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_steps.length, (index) {
          final stepNumber = index + 1;
          final isCurrent = currentStep == stepNumber;
          final isCompleted = currentStep > stepNumber;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onStepTapped != null ? () => onStepTapped!(stepNumber) : null,
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
                                height: 2.5,
                                color: currentStep > index
                                    ? const Color(0xFF007AFF)
                                    : const Color(0xFFE2E8F0),
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
                              : context.color.secondaryColor,
                          border: Border.all(
                            color: isCurrent || isCompleted
                                ? const Color(0xFF007AFF)
                                : const Color(0xFFCBD5E1),
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
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                        ),
                      ),
                      // Right connecting line
                      Expanded(
                        child: index == _steps.length - 1
                            ? const SizedBox.shrink()
                            : Container(
                                height: 2.5,
                                color: currentStep > index + 1
                                    ? const Color(0xFF007AFF)
                                    : const Color(0xFFE2E8F0),
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
                              ? const Color(0xFF007AFF)
                              : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
