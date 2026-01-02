class ProductModel {
  final int id;
  final String name;
  final String description;
  final String category;
  final int stock;
  final String qrCode;
  final String? imageUrl;
  final bool isActive;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.stock,
    required this.qrCode,
    this.imageUrl,
    required this.isActive,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String,
      stock: json['stock'] as int,
      qrCode: json['qr_code'] as String,
      imageUrl: json['image_url'] as String?,
      // Handle boolean conversion from int (1/0) or bool depending on API
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'stock': stock,
      'qr_code': qrCode,
      'image_url': imageUrl,
      'is_active': isActive ? 1 : 0, // Send as 1/0 for PHP compatibility
    };
  }
}
