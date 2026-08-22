import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:Ebozor/app/routes.dart';
import 'package:Ebozor/data/model/user_address_model.dart';
import 'package:Ebozor/data/repositories/user_address_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/LocalStoreage/hive_utils.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';

class UserAddressListScreen extends StatefulWidget {
  const UserAddressListScreen({super.key});

  static Route route(RouteSettings settings) {
    return BlurredRouter(
      builder: (context) => const UserAddressListScreen(),
    );
  }

  @override
  State<UserAddressListScreen> createState() => _UserAddressListScreenState();
}

class _UserAddressListScreenState extends State<UserAddressListScreen> {
  final UserAddressRepository _addressRepo = UserAddressRepository();
  List<UserAddressModel> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    final userId = int.tryParse(HiveUtils.getUserId() ?? "0") ?? 0;
    if (userId == 0) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final list = await _addressRepo.getUserAddresses(userId: userId);
      // Sort by label (e.g. Home, Work, others)
      list.sort((a, b) {
        if (a.isDefault == true && b.isDefault != true) return -1;
        if (b.isDefault == true && a.isDefault != true) return 1;
        return (a.label ?? '').compareTo(b.label ?? '');
      });

      if (mounted) {
        setState(() {
          _addresses = list;
        });
      }
    } catch (e) {
      log("Error fetching user addresses: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAddLocationScreen({UserAddressModel? addressToEdit}) async {
    final result = await Navigator.pushNamed(
      context,
      Routes.locationDetailsFormScreen,
      arguments: {
        'address': addressToEdit,
      },
    );

    if (result == true) {
      _loadAddresses();
    }
  }

  void _confirmDelete(UserAddressModel address) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.color.secondaryColor,
        title: Text(
          "Delete Address",
          style: TextStyle(
            color: context.color.textDefaultColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Are you sure you want to remove this address?",
          style: TextStyle(color: context.color.textLightColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              "Cancel",
              style: TextStyle(color: context.color.textLightColor),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final userId = int.tryParse(HiveUtils.getUserId() ?? "0") ?? 0;
              if (address.id != null && userId != 0) {
                try {
                  await _addressRepo.deleteAddress(
                    userId: userId,
                    addressId: address.id!,
                  );
                  _loadAddresses();
                  if (mounted) {
                    HelperUtils.showSnackBarMessage(
                      context,
                      "Address deleted successfully",
                      type: MessageType.success,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    HelperUtils.showSnackBarMessage(
                      context,
                      "Failed to delete address: $e",
                      type: MessageType.error,
                    );
                  }
                }
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: context.color.backgroundColor,
          appBar: AppBar(
            backgroundColor: context.color.secondaryColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: context.color.textDefaultColor,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            title: Text(
              "Addresses",
              style: TextStyle(
                color: context.color.textDefaultColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          body: _isLoading
              ? Center(
                  child: UiUtils.progress(
                    normalProgressColor: context.color.territoryColor,
                  ),
                )
              : _addresses.isEmpty
                  ? _buildEmptyState()
                  : _buildAddressList(),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _openAddLocationScreen(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD31027),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Add New Location",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFFDE8E8),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 46,
                  color: Color(0xFFE02424),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Address not found",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.color.textDefaultColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You have no addresses currently registered",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.color.textLightColor,
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressList() {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      itemCount: _addresses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _addresses[index];
        final label = item.label ?? 'Home';
        final isHome = label.toLowerCase() == 'home';
        final isWork = label.toLowerCase() == 'work';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.color.secondaryColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isDefault == true
                  ? context.color.territoryColor.withValues(alpha: 0.8)
                  : context.color.borderColor.withValues(alpha: 0.5),
              width: item.isDefault == true ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.color.territoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isHome
                              ? Icons.home_rounded
                              : isWork
                                  ? Icons.work_rounded
                                  : Icons.location_on_rounded,
                          size: 14,
                          color: context.color.territoryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: context.color.territoryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.isDefault == true) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "Default",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        size: 18, color: context.color.textLightColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _openAddLocationScreen(addressToEdit: item),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: Colors.red),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _confirmDelete(item),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (item.neighbourhood != null && item.neighbourhood!.isNotEmpty)
                Text(
                  item.neighbourhood!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.color.textDefaultColor,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                item.fullAddressFormatted,
                style: TextStyle(
                  fontSize: 13,
                  color: context.color.textLightColor,
                  height: 1.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
