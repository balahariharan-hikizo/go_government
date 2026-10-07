import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../bloc/product/product_bloc.dart';
import '../../bloc/product/product_event.dart';
import '../../bloc/product/product_state.dart';
import '../../model/product_model.dart';
import '../../network/store_api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';

class AddProductScreen extends StatefulWidget {
  final String storeId;
  final String storeCategory;
  final ProductModel? initialProduct;

  const AddProductScreen({
    super.key,
    required this.storeId,
    required this.storeCategory,
    this.initialProduct,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _VariantRowController {
  final TextEditingController unitCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController origPriceCtrl;
  final TextEditingController stockCtrl;
  final String variantId;

  _VariantRowController({
    required this.variantId,
    String unit = '',
    String price = '',
    String origPrice = '',
    String stock = '10',
  })  : unitCtrl = TextEditingController(text: unit),
        priceCtrl = TextEditingController(text: price),
        origPriceCtrl = TextEditingController(text: origPrice),
        stockCtrl = TextEditingController(text: stock);

  void dispose() {
    unitCtrl.dispose();
    priceCtrl.dispose();
    origPriceCtrl.dispose();
    stockCtrl.dispose();
  }
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.initialProduct != null;

  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _origPriceController;
  late TextEditingController _stockController;
  late TextEditingController _unitController;
  late TextEditingController _brandController;
  late TextEditingController _packOfController;
  late TextEditingController _typeController;
  late TextEditingController _shelfLifeController;
  late TextEditingController _formFactorController;
  late TextEditingController _originController;
  late TextEditingController _descriptionController;
  late TextEditingController _subsidyLimitController;

  final List<String> _categoryOptions = [
    'Rice & Grains',
    'Dals & Pulses',
    'Atta & Flours',
    'Oils & Ghee',
    'Spices & Masala',
    'Vegetables & Fruits',
    'Dairy & Eggs',
    'Medicines & Healthcare',
    'Snacks & Beverages',
    'General Staples',
  ];
  String _selectedCategory = 'Rice & Grains';
  bool _isSubsidized = false;

  // Multiple Images Management
  List<String> _productImages = [];
  bool _isUploadingImages = false;

  // Variants Management (Sizes / Weights)
  bool _hasVariants = false;
  final List<_VariantRowController> _variantControllers = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;
    if (p != null) {
      _selectedCategory = p.category.isNotEmpty
          ? p.category
          : _categoryOptions.first;
      _titleController = TextEditingController(text: p.title);
      _priceController = TextEditingController(text: p.price.toStringAsFixed(0));
      _origPriceController =
          TextEditingController(text: p.originalPrice > 0 ? p.originalPrice.toStringAsFixed(0) : '');
      _stockController = TextEditingController(text: p.stock.toString());
      _unitController = TextEditingController(text: p.unit);
      _brandController = TextEditingController(text: p.brand);
      _packOfController = TextEditingController(text: p.packOf);
      _typeController = TextEditingController(text: p.type);
      _shelfLifeController = TextEditingController(text: p.shelfLife);
      _formFactorController = TextEditingController(text: p.formFactor);
      _originController = TextEditingController(text: p.origin);
      _descriptionController = TextEditingController(text: p.description);
      _subsidyLimitController = TextEditingController(text: p.subsidyLimit);
      _isSubsidized = p.isSubsidized;

      // Populate multiple images
      _productImages = List.from(p.images);
      if (_productImages.isEmpty && p.image.isNotEmpty) {
        _productImages.add(p.image);
      }

      // Populate variants if any
      _hasVariants = p.hasVariants && p.variants.isNotEmpty;
      if (_hasVariants) {
        for (final v in p.variants) {
          _variantControllers.add(_VariantRowController(
            variantId: v.variantId,
            unit: v.unit,
            price: v.price.toStringAsFixed(0),
            origPrice: v.originalPrice > 0 ? v.originalPrice.toStringAsFixed(0) : '',
            stock: v.stock.toString(),
          ));
        }
      }
    } else {
      _selectedCategory = _categoryOptions.first;
      _titleController = TextEditingController();
      _priceController = TextEditingController();
      _origPriceController = TextEditingController();
      _stockController = TextEditingController(text: '10');
      _unitController = TextEditingController(text: '1 Units');
      _brandController = TextEditingController(text: 'Unbranded');
      _packOfController = TextEditingController(text: '1');
      _typeController = TextEditingController();
      _shelfLifeController = TextEditingController(text: '7 Days');
      _formFactorController = TextEditingController(text: 'Whole');
      _originController = TextEditingController(text: 'India');
      _descriptionController = TextEditingController();
      _subsidyLimitController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _origPriceController.dispose();
    _stockController.dispose();
    _unitController.dispose();
    _brandController.dispose();
    _packOfController.dispose();
    _typeController.dispose();
    _shelfLifeController.dispose();
    _formFactorController.dispose();
    _originController.dispose();
    _descriptionController.dispose();
    _subsidyLimitController.dispose();

    for (final vc in _variantControllers) {
      vc.dispose();
    }
    super.dispose();
  }

  void _addVariantRow({String unit = '', String price = '', String origPrice = '', String stock = '10'}) {
    setState(() {
      final defaultId = widget.initialProduct != null
          ? '${widget.initialProduct!.productId}_V${_variantControllers.length + 1}'
          : 'V${_variantControllers.length + 1}';
      _variantControllers.add(_VariantRowController(
        variantId: defaultId,
        unit: unit,
        price: price,
        origPrice: origPrice,
        stock: stock,
      ));
    });
  }

  void _removeVariantRow(int index) {
    setState(() {
      final removed = _variantControllers.removeAt(index);
      removed.dispose();
      if (_variantControllers.isEmpty) {
        _hasVariants = false;
      }
    });
  }

  // Pick Multiple Images from Gallery
  Future<void> _pickMultipleImages() async {
    try {
      final pickedList = await _picker.pickMultiImage(imageQuality: 75);
      if (pickedList.isNotEmpty) {
        setState(() => _isUploadingImages = true);
        final paths = pickedList.map((e) => e.path).toList();
        final uploaded = await StoreApiService.uploadMultipleProductImages(paths);
        setState(() {
          _isUploadingImages = false;
          _productImages.addAll(uploaded);
        });
      }
    } catch (e) {
      setState(() => _isUploadingImages = false);
    }
  }

  // Pick Single Photo from Camera
  Future<void> _pickCameraPhoto() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75);
      if (picked != null) {
        setState(() => _isUploadingImages = true);
        final uploaded = await StoreApiService.uploadMultipleProductImages([picked.path]);
        setState(() {
          _isUploadingImages = false;
          _productImages.addAll(uploaded);
        });
      }
    } catch (e) {
      setState(() => _isUploadingImages = false);
    }
  }

  // ================= 🧪 MOCK DATA PRESETS FOR RAPID TESTING ================= //
  static final List<Map<String, dynamic>> _mockPresets = [
    {
      'presetName': '🍉 Watermelon (Citizen App)',
      'title': 'Watermelon striped',
      'category': 'vegstore',
      'unit': '1 Units (2-3 kg)',
      'price': '83',
      'originalPrice': '106',
      'stock': '15',
      'brand': 'Karnataka Horticulture',
      'packOf': '1',
      'type': 'Watermelon striped',
      'shelfLife': '7 Days',
      'formFactor': 'Whole',
      'origin': 'India',
      'isSubsidized': false,
      'subsidyLimit': '',
      'description': 'Sweet, juicy farm-harvested watermelon with high hydration and rich antioxidant content.',
      'image': 'assets/images/product1.png',
      'variants': [
        {'unit': 'Small (1-2 kg)', 'price': '55', 'originalPrice': '70', 'stock': '10'},
        {'unit': 'Medium (2-3 kg)', 'price': '83', 'originalPrice': '106', 'stock': '15'},
        {'unit': 'Large (3-4 kg)', 'price': '110', 'originalPrice': '140', 'stock': '8'},
      ],
    },
    {
      'presetName': '🌾 Ration Sona Masoori Rice',
      'title': 'Govt Ration Sona Masoori Rice',
      'category': 'ration',
      'unit': '5 kg Bag',
      'price': '125',
      'originalPrice': '220',
      'stock': '50',
      'brand': 'Civil Supplies Corp',
      'packOf': '1',
      'type': 'Raw Rice Grade A',
      'shelfLife': '6 Months',
      'formFactor': 'Grain',
      'origin': 'Tamil Nadu, India',
      'isSubsidized': true,
      'subsidyLimit': '10 kg per ration card',
      'description': 'Subsidized fine polished grain rice supplied by Civil Supplies Department for ration cardholders.',
      'image': 'assets/images/product2.png',
      'variants': [
        {'unit': '5 kg Bag', 'price': '125', 'originalPrice': '220', 'stock': '50'},
        {'unit': '10 kg Bag', 'price': '240', 'originalPrice': '420', 'stock': '30'},
      ],
    },
    {
      'presetName': '🍬 PDS Crystal Sugar',
      'title': 'Refined Crystal Sugar (M-30)',
      'category': 'ration',
      'unit': '1 kg Pack',
      'price': '25',
      'originalPrice': '44',
      'stock': '35',
      'brand': 'State Sugar Federation',
      'packOf': '1',
      'type': 'White Crystal Sugar',
      'shelfLife': '12 Months',
      'formFactor': 'Crystal',
      'origin': 'India',
      'isSubsidized': true,
      'subsidyLimit': '2 kg per card',
      'description': 'PDS subsidized premium white sugar for essential family ration quota.',
      'image': 'assets/images/product3.png',
      'variants': [
        {'unit': '1 kg Pack', 'price': '25', 'originalPrice': '44', 'stock': '35'},
        {'unit': '2 kg Pack', 'price': '48', 'originalPrice': '88', 'stock': '20'},
      ],
    },
    {
      'presetName': '💊 Paracetamol 500mg',
      'title': 'Paracetamol IP 500mg Tablets',
      'category': 'medical',
      'unit': '10 Tablets / Strip',
      'price': '18',
      'originalPrice': '40',
      'stock': '80',
      'brand': 'Jan Aushadhi / Cipla',
      'packOf': '1 Strip',
      'type': 'Antipyretic',
      'shelfLife': '24 Months',
      'formFactor': 'Tablet',
      'origin': 'India',
      'isSubsidized': true,
      'subsidyLimit': '3 Strips per citizen',
      'description': 'Affordable generic fever and mild pain relief tablets with quality certification.',
      'image': 'assets/images/product1.png',
    },
    {
      'presetName': '🥛 Pasteurized Milk',
      'title': 'Standardized Pasteurized Milk',
      'category': 'dairy',
      'unit': '500 ml Pouch',
      'price': '26',
      'originalPrice': '28',
      'stock': '40',
      'brand': 'Aavin Daily',
      'packOf': '1',
      'type': 'Toned Milk 4.5% Fat',
      'shelfLife': '2 Days',
      'formFactor': 'Liquid',
      'origin': 'India',
      'isSubsidized': false,
      'subsidyLimit': '',
      'description': 'Daily morning fresh pasteurized milk rich in calcium and essential vitamins.',
      'image': 'assets/images/product2.png',
      'variants': [
        {'unit': '500 ml Pouch', 'price': '26', 'originalPrice': '28', 'stock': '40'},
        {'unit': '1 Liter Pouch', 'price': '50', 'originalPrice': '56', 'stock': '25'},
      ],
    },
    {
      'presetName': '🍅 Country Tomatoes',
      'title': 'Organic Country Tomatoes',
      'category': 'vegstore',
      'unit': '1 kg Bag',
      'price': '34',
      'originalPrice': '50',
      'stock': '25',
      'brand': 'Local Farmers Collective',
      'packOf': '1',
      'type': 'Country Hybrid',
      'shelfLife': '5 Days',
      'formFactor': 'Fresh Whole',
      'origin': 'India',
      'isSubsidized': false,
      'subsidyLimit': '',
      'description': 'Freshly picked tangy country tomatoes suitable for daily culinary curries and salads.',
      'image': 'assets/images/product3.png',
      'variants': [
        {'unit': '500 g', 'price': '18', 'originalPrice': '26', 'stock': '20'},
        {'unit': '1 kg Bag', 'price': '34', 'originalPrice': '50', 'stock': '25'},
      ],
    },
  ];

  void _applyMockPreset(Map<String, dynamic> data) {
    setState(() {
      _titleController.text = data['title'] ?? '';
      _selectedCategory = data['category'] ?? widget.storeCategory;
      _unitController.text = data['unit'] ?? '';
      _priceController.text = data['price'] ?? '';
      _origPriceController.text = data['originalPrice'] ?? '';
      _stockController.text = data['stock'] ?? '10';
      _brandController.text = data['brand'] ?? 'Unbranded';
      _packOfController.text = data['packOf'] ?? '1';
      _typeController.text = data['type'] ?? '';
      _shelfLifeController.text = data['shelfLife'] ?? '7 Days';
      _formFactorController.text = data['formFactor'] ?? 'Whole';
      _originController.text = data['origin'] ?? 'India';
      _isSubsidized = data['isSubsidized'] == true;
      _subsidyLimitController.text = data['subsidyLimit'] ?? '';
      _descriptionController.text = data['description'] ?? '';

      _productImages = [data['image'] ?? ''];

      // Clear existing variants and load preset variants if present
      for (final vc in _variantControllers) {
        vc.dispose();
      }
      _variantControllers.clear();

      final rawVariants = data['variants'];
      if (rawVariants is List && rawVariants.isNotEmpty) {
        _hasVariants = true;
        for (final rawPv in rawVariants) {
          if (rawPv is Map) {
            final defaultId = widget.initialProduct != null
                ? '${widget.initialProduct!.productId}_V${_variantControllers.length + 1}'
                : 'V${_variantControllers.length + 1}';
            _variantControllers.add(_VariantRowController(
              variantId: defaultId,
              unit: rawPv['unit']?.toString() ?? '',
              price: rawPv['price']?.toString() ?? '',
              origPrice: rawPv['originalPrice']?.toString() ?? '',
              stock: rawPv['stock']?.toString() ?? '10',
            ));
          }
        }
      } else {
        _hasVariants = false;
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Autofilled demo: "${data['title']}"! Tap Add Product below.')),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final fallbackPrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final fallbackOrigPrice = double.tryParse(_origPriceController.text.trim()) ?? 0.0;
    final fallbackStock = int.tryParse(_stockController.text.trim()) ?? 10;
    final fallbackUnit = _unitController.text.trim().isNotEmpty ? _unitController.text.trim() : '1 Units';

    List<ProductVariant> formattedVariants = [];
    if (_hasVariants && _variantControllers.isNotEmpty) {
      formattedVariants = _variantControllers.map((vc) {
        final p = double.tryParse(vc.priceCtrl.text.trim()) ?? fallbackPrice;
        final op = double.tryParse(vc.origPriceCtrl.text.trim()) ?? 0.0;
        final st = int.tryParse(vc.stockCtrl.text.trim()) ?? fallbackStock;
        final u = vc.unitCtrl.text.trim().isNotEmpty ? vc.unitCtrl.text.trim() : '1 Units';

        return ProductVariant(
          variantId: vc.variantId,
          unit: u,
          price: p,
          originalPrice: op > 0 ? op : p,
          stock: st,
        );
      }).toList();
    }

    final effectivePrice = (_hasVariants && formattedVariants.isNotEmpty)
        ? formattedVariants.first.price
        : fallbackPrice;
    final effectiveOrigPrice = (_hasVariants && formattedVariants.isNotEmpty)
        ? formattedVariants.first.originalPrice
        : (fallbackOrigPrice > 0 ? fallbackOrigPrice : fallbackPrice);
    final effectiveUnit = (_hasVariants && formattedVariants.isNotEmpty)
        ? formattedVariants.first.unit
        : fallbackUnit;
    final effectiveStock = (_hasVariants && formattedVariants.isNotEmpty)
        ? formattedVariants.first.stock
        : fallbackStock;

    final product = ProductModel(
      productId: _isEditing ? widget.initialProduct!.productId : '',
      storeId: widget.storeId,
      title: _titleController.text.trim(),
      category: _selectedCategory,
      unit: effectiveUnit,
      price: effectivePrice,
      originalPrice: effectiveOrigPrice,
      stock: effectiveStock,
      image: _productImages.isNotEmpty ? _productImages.first : '',
      images: _productImages,
      hasVariants: _hasVariants && formattedVariants.isNotEmpty,
      variants: formattedVariants,
      brand: _brandController.text.trim(),
      packOf: _packOfController.text.trim(),
      type: _typeController.text.trim(),
      shelfLife: _shelfLifeController.text.trim(),
      formFactor: _formFactorController.text.trim(),
      origin: _originController.text.trim(),
      isSubsidized: _isSubsidized,
      subsidyLimit: _isSubsidized ? _subsidyLimitController.text.trim() : '',
      description: _descriptionController.text.trim(),
      isAvailable: effectiveStock > 0,
    );

    if (_isEditing) {
      context.read<ProductBloc>().add(UpdateProductEvent(product));
    } else {
      context.read<ProductBloc>().add(AddProductEvent(product));
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return BlocListener<ProductBloc, ProductState>(
      listener: (context, state) {
        if (state is ProductSubmitSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        } else if (state is ProductError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        body: CommonBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(12)),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMockPresetsBar(),
                          SizedBox(height: Responsive.h(16)),

                          // 📸 Multiple Product Images Section
                          _buildMultipleImagesSection(),

                          SizedBox(height: Responsive.h(20)),

                          // 1. Basic Information
                          _buildSectionHeader('Basic Product Details'),
                          _buildCategoryDropdown(),
                          SizedBox(height: Responsive.h(12)),
                          _buildInputField(
                            controller: _titleController,
                            label: 'Product Title / Name',
                            hint: 'e.g. Sona Masoori Rice, Paracetamol 500mg',
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Product name is required' : null,
                          ),
                          SizedBox(height: Responsive.h(12)),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  controller: _brandController,
                                  label: 'Brand / Manufacturer',
                                  hint: 'e.g. Govt PDS, Cipla',
                                ),
                              ),
                              SizedBox(width: Responsive.w(12)),
                              Expanded(
                                child: _buildInputField(
                                  controller: _packOfController,
                                  label: 'Pack Of',
                                  hint: 'e.g. 1, 2, 4',
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: Responsive.h(20)),

                          // ⚖️ 2. Product Variants / Size / Pricing Section
                          _buildVariantsSection(),

                          SizedBox(height: Responsive.h(20)),

                          // 3. Citizen App Specifications
                          _buildSectionHeader('Citizen App Highlights & Specs'),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  controller: _shelfLifeController,
                                  label: 'Shelf Life',
                                  hint: 'e.g. 7 Days, 6 Months',
                                ),
                              ),
                              SizedBox(width: Responsive.w(12)),
                              Expanded(
                                child: _buildInputField(
                                  controller: _formFactorController,
                                  label: 'Form Factor',
                                  hint: 'e.g. Whole, Liquid, Tablet',
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: Responsive.h(12)),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  controller: _typeController,
                                  label: 'Sub-Type / Variety',
                                  hint: 'e.g. Raw Rice, Antibiotic',
                                ),
                              ),
                              SizedBox(width: Responsive.w(12)),
                              Expanded(
                                child: _buildInputField(
                                  controller: _originController,
                                  label: 'Country of Origin',
                                  hint: 'e.g. India',
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: Responsive.h(20)),

                          // 4. Government Subsidy Section
                          _buildSubsidySection(),

                          SizedBox(height: Responsive.h(20)),

                          // 5. Description
                          _buildSectionHeader('Product Description'),
                          _buildInputField(
                            controller: _descriptionController,
                            label: 'Description & Benefits',
                            hint: 'Write detailed product information, usage guidelines, storage tips...',
                            maxLines: 4,
                          ),

                          SizedBox(height: Responsive.h(30)),

                          // Submit Button
                          _buildSubmitButton(),
                          SizedBox(height: Responsive.h(24)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= UI WIDGET BUILDERS ================= //

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(12)),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: AppColors.black,
          ),
          SizedBox(width: Responsive.w(8)),
          CustomText.header(
            _isEditing ? 'Edit Product' : 'Add New Product',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }

  Widget _buildMockPresetsBar() {
    return Container(
      padding: EdgeInsets.all(Responsive.w(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(Responsive.w(12)),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: Responsive.w(6)),
              CustomText.title('Quick Demo Presets', fontSize: 13, color: const Color(0xFF1E40AF)),
            ],
          ),
          SizedBox(height: Responsive.h(8)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _mockPresets.map((preset) {
                return Padding(
                  padding: EdgeInsets.only(right: Responsive.w(8)),
                  child: ActionChip(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                    label: Text(
                      preset['presetName'],
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                    ),
                    onPressed: () => _applyMockPreset(preset),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 📸 Multiple Product Images UI
  Widget _buildMultipleImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Product Photos (Multiple)'),
            Text(
              '${_productImages.length} images added',
              style: TextStyle(fontSize: 12, color: AppColors.grayFont, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        SizedBox(height: Responsive.h(10)),
        SizedBox(
          height: Responsive.h(115),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Add Image Button
              InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (ctx) => SafeArea(
                      child: Wrap(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.photo_library, color: AppColors.primary),
                            title: const Text('Select Multiple from Gallery'),
                            onTap: () {
                              Navigator.pop(ctx);
                              _pickMultipleImages();
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                            title: const Text('Capture with Camera'),
                            onTap: () {
                              Navigator.pop(ctx);
                              _pickCameraPhoto();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  width: Responsive.w(100),
                  height: Responsive.h(110),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Responsive.w(16)),
                    border: Border.all(color: AppColors.primary, width: 1.5, style: BorderStyle.solid),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: _isUploadingImages
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined, size: 30, color: AppColors.primary),
                            SizedBox(height: Responsive.h(6)),
                            CustomText.body('+ Add Photos', fontSize: 11, color: AppColors.primary),
                          ],
                        ),
                ),
              ),

              // Existing Images List
              ..._productImages.asMap().entries.map((entry) {
                final idx = entry.key;
                final imgUrl = entry.value;

                return Container(
                  width: Responsive.w(100),
                  height: Responsive.h(110),
                  margin: EdgeInsets.only(left: Responsive.w(12)),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Responsive.w(16)),
                          child: imgUrl.startsWith('assets/')
                              ? Image.asset(imgUrl, fit: BoxFit.cover)
                              : Image.network(
                                  imgUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) =>
                                      const Icon(Icons.broken_image, color: Colors.grey),
                                ),
                        ),
                      ),
                      if (idx == 0)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Cover',
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _productImages.removeAt(idx);
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ⚖️ Product Variants & Sizes Section
  Widget _buildVariantsSection() {
    return Container(
      padding: EdgeInsets.all(Responsive.w(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomText.title('Multiple Sizes / Weights (Variants)', fontSize: 14, fontWeight: FontWeight.bold),
                    SizedBox(height: Responsive.h(2)),
                    CustomText.body(
                      'Enable if product has multiple weights (e.g. 500g, 1kg) with different prices.',
                      fontSize: 11,
                      color: AppColors.grayFont,
                    ),
                  ],
                ),
              ),
              Switch(
                value: _hasVariants,
                activeThumbColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _hasVariants = val;
                    if (val && _variantControllers.isEmpty) {
                      _addVariantRow(unit: '500 g', price: '50', stock: '20');
                      _addVariantRow(unit: '1 kg', price: '95', stock: '20');
                    }
                  });
                },
              ),
            ],
          ),

          if (_hasVariants) ...[
            const Divider(height: 24),
            CustomText.title('Configured Sizes & Prices:', fontSize: 12, fontWeight: FontWeight.w600),
            SizedBox(height: Responsive.h(10)),

            ..._variantControllers.asMap().entries.map((entry) {
              final idx = entry.key;
              final vc = entry.value;

              return Container(
                margin: EdgeInsets.only(bottom: Responsive.h(10)),
                padding: EdgeInsets.all(Responsive.w(10)),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(Responsive.w(12)),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('Size #${idx + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                        const Spacer(),
                        if (_variantControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () => _removeVariantRow(idx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(6)),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildMiniInput(
                            controller: vc.unitCtrl,
                            hint: 'Size/Unit (e.g. 1 kg)',
                          ),
                        ),
                        SizedBox(width: Responsive.w(8)),
                        Expanded(
                          flex: 2,
                          child: _buildMiniInput(
                            controller: vc.priceCtrl,
                            hint: 'Price (₹)',
                            isNumber: true,
                          ),
                        ),
                        SizedBox(width: Responsive.w(8)),
                        Expanded(
                          flex: 2,
                          child: _buildMiniInput(
                            controller: vc.origPriceCtrl,
                            hint: 'MRP (₹)',
                            isNumber: true,
                          ),
                        ),
                        SizedBox(width: Responsive.w(8)),
                        Expanded(
                          flex: 2,
                          child: _buildMiniInput(
                            controller: vc.stockCtrl,
                            hint: 'Stock',
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            SizedBox(height: Responsive.h(6)),
            OutlinedButton.icon(
              onPressed: () => _addVariantRow(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Another Size / Variant'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ] else ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _unitController,
                    label: 'Unit / Packaging',
                    hint: 'e.g. 1 kg, 500 g',
                  ),
                ),
                SizedBox(width: Responsive.w(12)),
                Expanded(
                  child: _buildInputField(
                    controller: _stockController,
                    label: 'Stock Quantity',
                    hint: 'e.g. 25',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.h(12)),
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _priceController,
                    label: 'Selling Price (₹)',
                    hint: 'e.g. 99',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (_hasVariants) return null;
                      if (v == null || v.trim().isEmpty) return 'Price required';
                      return null;
                    },
                  ),
                ),
                SizedBox(width: Responsive.w(12)),
                Expanded(
                  child: _buildInputField(
                    controller: _origPriceController,
                    label: 'Original MRP (₹)',
                    hint: 'e.g. 150',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniInput({
    required TextEditingController controller,
    required String hint,
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }

  Widget _buildSubsidySection() {
    return Container(
      padding: EdgeInsets.all(Responsive.w(14)),
      decoration: BoxDecoration(
        color: _isSubsidized ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(Responsive.w(14)),
        border: Border.all(color: _isSubsidized ? const Color(0xFF86EFAC) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: _isSubsidized ? Colors.green : Colors.grey, size: 20),
              SizedBox(width: Responsive.w(8)),
              Expanded(
                child: CustomText.title('Government Subsidized (Ration / PDS)', fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Switch(
                value: _isSubsidized,
                activeThumbColor: Colors.green,
                onChanged: (val) => setState(() => _isSubsidized = val),
              ),
            ],
          ),
          if (_isSubsidized) ...[
            SizedBox(height: Responsive.h(8)),
            _buildInputField(
              controller: _subsidyLimitController,
              label: 'Ration Limit per Card / Citizen',
              hint: 'e.g. Max 5 kg / ration card per month',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomText.title(
          'Product Category / Shelf',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.black,
        ),
        SizedBox(height: Responsive.h(6)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: Responsive.w(14)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Responsive.w(12)),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _categoryOptions.contains(_selectedCategory)
                  ? _selectedCategory
                  : _categoryOptions.first,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
              items: _categoryOptions.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat,
                  child: CustomText.body(cat, fontSize: 14, color: AppColors.black),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCategory = val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.h(8)),
      child: CustomText.title(title, fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.black),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: Responsive.w(14), vertical: Responsive.h(12)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Responsive.w(12)), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Responsive.w(12)), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Responsive.w(12)), borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        final isLoading = state is ProductSubmitting;

        return SizedBox(
          width: double.infinity,
          height: Responsive.h(50),
          child: ElevatedButton(
            onPressed: isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(14))),
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    _isEditing ? 'Update Product Catalog' : 'Add Product to Store',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
        );
      },
    );
  }
}
