import 'package:Ebozor/data/cubits/fetch_item_buyer_cubit.dart';
import 'package:Ebozor/data/model/user_model.dart';
import 'package:Ebozor/data/repositories/item/item_repository.dart';
import 'package:Ebozor/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:Ebozor/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/constant.dart';
import 'package:Ebozor/utils/extensions/lib/build_context.dart';
import 'package:Ebozor/utils/helper_utils.dart';
import 'package:Ebozor/utils/ui_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SoldOutBoughtScreen extends StatefulWidget {
  final int itemId;
  final double price;
  final String itemName;
  final String itemImage;

  const SoldOutBoughtScreen({
    super.key,
    required this.itemId,
    required this.price,
    required this.itemName,
    required this.itemImage,
  });

  static Route route(RouteSettings settings) {
    final arguments = settings.arguments as Map?;
    return BlurredRouter(
      builder: (context) => BlocProvider(
        create: (_) => GetItemBuyerListCubit(),
        child: SoldOutBoughtScreen(
          itemId: (arguments?['itemId'] as num?)?.toInt() ?? 0,
          price: (arguments?['price'] as num?)?.toDouble() ?? 0,
          itemName: arguments?['itemName']?.toString() ?? '',
          itemImage: arguments?['itemImage']?.toString() ?? '',
        ),
      ),
    );
  }

  @override
  State<SoldOutBoughtScreen> createState() => _SoldOutBoughtScreenState();
}

class _SoldOutBoughtScreenState extends State<SoldOutBoughtScreen> {
  final Set<int> _selectedBuyerIds = <int>{};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    context.read<GetItemBuyerListCubit>().fetchItemBuyer(widget.itemId);
  }

  Future<bool> _confirmSale({required int buyerCount}) async {
    final multiple = buyerCount > 1;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: context.color.secondaryColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            icon: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: context.color.territoryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_rounded,
                color: context.color.territoryColor,
                size: 29,
              ),
            ),
            title: Text(
              buyerCount == 0
                  ? 'Mark ad as sold?'
                  : multiple
                      ? 'Record $buyerCount sales?'
                      : 'Confirm this buyer?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            content: Text(
              buyerCount == 0
                  ? 'The ad will be marked sold without linking a buyer.'
                  : multiple
                      ? 'Each selected buyer will be recorded for this ad.'
                      : 'The selected person will be recorded as the buyer. You can return later to record another sale.',
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.4,
                color: context.color.textLightColor,
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.color.territoryColor,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _recordSales({bool withoutBuyer = false}) async {
    if (_isSubmitting) return;
    final buyerIds = withoutBuyer
        ? <int?>[null]
        : _selectedBuyerIds.map<int?>((id) => id).toList();
    if (buyerIds.isEmpty) return;

    final confirmed = await _confirmSale(
      buyerCount: withoutBuyer ? 0 : buyerIds.length,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      for (final buyerId in buyerIds) {
        final response = await ItemRepository().changeMyItemStatus(
          itemId: widget.itemId,
          status: 'sold out',
          userId: buyerId,
        );
        if (response['error'] == true) {
          throw response['message']?.toString() ?? 'Could not record the sale';
        }
      }
      if (!mounted) return;
      HelperUtils.showSnackBarMessage(
        context,
        withoutBuyer
            ? 'Ad marked as sold'
            : buyerIds.length == 1
                ? 'Buyer recorded successfully'
                : '${buyerIds.length} buyers recorded successfully',
      );
      Navigator.pop(context, 'refresh');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      HelperUtils.showSnackBarMessage(context, error.toString());
    }
  }

  void _toggleBuyer(BuyerModel buyer) {
    final id = buyer.id;
    if (id == null || _isSubmitting) return;
    setState(() {
      if (!_selectedBuyerIds.add(id)) _selectedBuyerIds.remove(id);
    });
  }

  Widget _buyerListTile(BuyerModel buyer) {
    final buyerId = buyer.id;
    final selected = buyerId != null && _selectedBuyerIds.contains(buyerId);
    final name = (buyer.name ?? '').trim().isEmpty
        ? 'Interested buyer'
        : buyer.name!.trim();
    final profile = (buyer.profile ?? '').trim();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      onTap: () => _toggleBuyer(buyer),
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: context.color.territoryColor.withValues(alpha: 0.12),
        backgroundImage:
            profile.isNotEmpty ? CachedNetworkImageProvider(profile) : null,
        child: profile.isEmpty
            ? Text(
                name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: context.color.territoryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              )
            : null,
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: context.color.textDefaultColor,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        selected ? 'Selected as buyer' : 'Tap to select buyer',
        style: TextStyle(
          color: selected
              ? context.color.territoryColor
              : context.color.textLightColor,
          fontSize: 12,
        ),
      ),
      trailing: selected
          ? Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFF22A447),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 19,
              ),
            )
          : const SizedBox(width: 28),
    );
  }

  Widget _buyerContent() {
    return BlocBuilder<GetItemBuyerListCubit, GetItemBuyerListState>(
      builder: (context, state) {
        if (state is GetItemBuyerListInProgress ||
            state is GetItemBuyerListInitial) {
          return Center(
            child: UiUtils.progress(
              normalProgressColor: context.color.territoryColor,
            ),
          );
        }
        if (state is GetItemBuyerListFailed) {
          return const SomethingWentWrong();
        }
        if (state is! GetItemBuyerListSuccess) {
          return const SizedBox.shrink();
        }
        if (state.itemBuyerList.isEmpty) return _emptyBuyers();

        return ListView.separated(
          padding: const EdgeInsets.only(top: 8, bottom: 120),
          physics: const BouncingScrollPhysics(),
          itemCount: state.itemBuyerList.length,
          itemBuilder: (_, index) => _buyerListTile(state.itemBuyerList[index]),
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 84,
            endIndent: 18,
            color: context.color.borderColor.withValues(alpha: 0.45),
          ),
        );
      },
    );
  }

  Widget _emptyBuyers() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: context.color.territoryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.people_outline_rounded,
                  size: 38, color: context.color.territoryColor),
            ),
            const SizedBox(height: 18),
            Text(
              'No buyers yet',
              style: TextStyle(
                color: context.color.textDefaultColor,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You can still close this listing if the buyer contacted you elsewhere.',
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.45,
                color: context.color.textLightColor,
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed:
                  _isSubmitting ? null : () => _recordSales(withoutBuyer: true),
              icon: const Icon(Icons.sell_outlined),
              label: const Text('Mark sold without buyer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemSummary() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 56,
          child: widget.itemImage.trim().isEmpty
              ? Container(
                  color: context.color.backgroundColor,
                  child: Icon(Icons.image_outlined,
                      color: context.color.textLightColor),
                )
              : CachedNetworkImage(
                  imageUrl: widget.itemImage,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: context.color.backgroundColor,
                    child: Icon(Icons.image_not_supported_outlined,
                        color: context.color.textLightColor),
                  ),
                ),
        ),
      ),
      title: Text(
        widget.itemName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: context.color.textDefaultColor,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        '${Constant.currencySymbol} ${widget.price.toStringAsFixed(widget.price.truncateToDouble() == widget.price ? 0 : 2)}',
        style: TextStyle(
          color: context.color.territoryColor,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _bottomAction() {
    final count = _selectedBuyerIds.length;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
        decoration: BoxDecoration(
          color: context.color.secondaryColor,
          border: Border(
            top: BorderSide(
              color: context.color.borderColor.withValues(alpha: 0.5),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSubmitting
                    ? null
                    : () => _recordSales(withoutBuyer: true),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Sold elsewhere',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: context.color.territoryColor,
                  disabledBackgroundColor:
                      context.color.textLightColor.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed:
                    count == 0 || _isSubmitting ? null : () => _recordSales(),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  count == 0
                      ? 'Select buyer'
                      : count == 1
                          ? 'Confirm buyer'
                          : 'Confirm $count buyers',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.color.secondaryColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose buyers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text('Select one or multiple people',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: Column(
        children: [
          _itemSummary(),
          const SizedBox(height: 4),
          Expanded(child: _buyerContent()),
        ],
      ),
      bottomNavigationBar: _bottomAction(),
    );
  }
}
