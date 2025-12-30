import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/buyer/providers/variation_provider.dart';
import '../../features/buyer/providers/cart_provider.dart';
import '../../core/theme/app_theme.dart';
import 'variation_model.dart';

class VariationModal extends ConsumerStatefulWidget {
  final int listingId;
  final String productTitle;
  final double basePrice;
  final VoidCallback? onSuccess;
  final bool isBuyNow;

  const VariationModal({
    super.key,
    required this.listingId,
    required this.productTitle,
    required this.basePrice,
    this.onSuccess,
    this.isBuyNow = false,
  });

  @override
  ConsumerState<VariationModal> createState() => _VariationModalState();
}

class _VariationModalState extends ConsumerState<VariationModal> {
  String? selectedColor;
  String? selectedSize;
  VariationModel? selectedVariant;
  int quantity = 1;
  bool isAdding = false;

  @override
  void initState() {
    super.initState();
    // Load variations when modal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(variationProvider(widget.listingId).notifier).loadVariations(widget.listingId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final variationState = ref.watch(variationProvider(widget.listingId));
    final variations = variationState.variations;
    final availableColors = variationState.availableColors;
    final availableSizes = variationState.availableSizes;
    final hasVariations = variationState.hasVariations;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Options',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Product title
          Text(
            widget.productTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          
          if (variationState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (!hasVariations)
            _buildNoVariationsContent()
          else
            _buildVariationsContent(
              variations,
              availableColors,
              availableSizes,
            ),
        ],
      ),
    );
  }

  Widget _buildNoVariationsContent() {
    return Column(
      children: [
        const Text('This product has no variations available'),
        const SizedBox(height: 20),
        _buildQuantitySelector(),
        const SizedBox(height: 20),
        _buildAddButton(),
      ],
    );
  }

  Widget _buildVariationsContent(
    List<VariationModel> variations,
    List<String> colors,
    List<String> sizes,
  ) {
    return Column(
      children: [
        // Color selection
        if (colors.isNotEmpty) ...[
          _buildOptionSelector(
            title: 'Color',
            options: colors,
            selectedOption: selectedColor,
            onSelect: (color) => _selectColor(color),
          ),
          const SizedBox(height: 20),
        ],
        
        // Size selection
        if (sizes.isNotEmpty) ...[
          _buildOptionSelector(
            title: 'Size',
            options: sizes,
            selectedOption: selectedSize,
            onSelect: (size) => _selectSize(size),
          ),
          const SizedBox(height: 20),
        ],
        
        // Selected variant info
        if (selectedVariant != null) ...[
          _buildVariantInfo(selectedVariant!),
          const SizedBox(height: 16),
        ],
        
        // Quantity selector
        _buildQuantitySelector(),
        const SizedBox(height: 20),
        
        // Add to cart button
        _buildAddButton(),
      ],
    );
  }

  Widget _buildOptionSelector({
    required String title,
    required List<String> options,
    required String? selectedOption,
    required Function(String) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title *',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedOption == option;
            return GestureDetector(
              onTap: () => onSelect(option),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.white,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? AppColors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVariantInfo(VariationModel variant) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected Variant',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                if (selectedColor != null)
                  Text('Color: $selectedColor'),
                if (selectedSize != null)
                  Text('Size: $selectedSize'),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'UGX ${(variant.displayPrice ?? variant.price).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                variant.stock > 0 ? '${variant.stock} in stock' : 'Out of stock',
                style: TextStyle(
                  color: variant.stock > 0 ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      children: [
        const Text(
          'Quantity:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 20),
                onPressed: quantity > 1 ? () => _updateQuantity(quantity - 1) : null,
                padding: const EdgeInsets.all(4),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  quantity.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: selectedVariant?.stock != null && quantity < selectedVariant!.stock
                    ? () => _updateQuantity(quantity + 1)
                    : null,
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton() {
    final hasRequiredSelections = _hasRequiredSelections();
    final isOutOfStock = selectedVariant?.stock == 0;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isAdding || !hasRequiredSelections || isOutOfStock
            ? null
            : _handleAddToCart,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.isBuyNow ? AppColors.success : AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isAdding
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                widget.isBuyNow ? 'Buy Now' : 'Add to Cart',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
      ),
    );
  }

  void _selectColor(String color) {
    setState(() {
      selectedColor = color;
      _findMatchingVariant();
    });
  }

  void _selectSize(String size) {
    setState(() {
      selectedSize = size;
      _findMatchingVariant();
    });
  }

  void _updateQuantity(int newQuantity) {
    setState(() {
      quantity = newQuantity;
    });
  }

  void _findMatchingVariant() {
    final notifier = ref.read(variationProvider(widget.listingId).notifier);
    final variant = notifier.findMatchingVariant(
      color: selectedColor,
      size: selectedSize,
    );
    
    setState(() {
      selectedVariant = variant;
    });
  }

  bool _hasRequiredSelections() {
    final state = ref.read(variationProvider(widget.listingId));
    
    if (!state.hasVariations) return true;
    
    bool colorOk = state.availableColors.isEmpty || selectedColor != null;
    bool sizeOk = state.availableSizes.isEmpty || selectedSize != null;
    
    return colorOk && sizeOk && selectedVariant != null;
  }

  Future<void> _handleAddToCart() async {
    if (!_hasRequiredSelections()) return;

    setState(() => isAdding = true);

    // Debug: Log what we're about to send
    debugPrint('🛒 VariationModal: Adding to cart');
    debugPrint('   listingId: ${widget.listingId}');
    debugPrint('   quantity: $quantity');
    debugPrint('   selectedVariant: $selectedVariant');
    debugPrint('   selectedVariant?.id: ${selectedVariant?.id}');
    debugPrint('   selectedColor: $selectedColor');
    debugPrint('   selectedSize: $selectedSize');

    try {
      final cartNotifier = ref.read(cartProvider.notifier);

      final success = await cartNotifier.addToCart(
        widget.listingId,
        quantity,
        variantId: selectedVariant?.id,
        attributes: {
          if (selectedColor != null) 'color': selectedColor,
          if (selectedSize != null) 'size': selectedSize,
        },
      );

      debugPrint('🛒 VariationModal: Add to cart result: $success');

      setState(() => isAdding = false);

      if (success) {
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        }

        // Navigate based on action
        if (widget.isBuyNow) {
          Navigator.pop(context);
          context.push('/checkout');
        } else {
          Navigator.pop(context);
          // Only show snackbar if no onSuccess callback (to avoid duplicate snackbars)
          if (widget.onSuccess == null) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Added to cart successfully!'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
              ),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to add to cart. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
          ),
        );
      }
    } catch (e) {
      setState(() => isAdding = false);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add to cart: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
        ),
      );
    }
  }
}