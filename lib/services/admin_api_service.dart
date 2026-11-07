import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import '../models/product.dart';
import 'api_client.dart';

class AdminApiService {
  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await apiClient.get('admin/users');
    return (response['users'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    final response = await apiClient.get('admin/orders');
    return (response['orders'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await apiClient.get('admin/categories');
    return (response['categories'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<void> createCategory(String name) async {
    await apiClient.post('admin/categories', body: {'name': name});
  }

  Future<void> setCategoryPublished(int id, bool isPublished) async {
    await apiClient.put(
      'admin/categories/$id',
      body: {'is_published': isPublished},
    );
  }

  Future<Map<String, dynamic>> getUserHistory(int id) async {
    return apiClient.get('admin/users/$id/history');
  }

  Future<void> createUser(Map<String, dynamic> user) async {
    await apiClient.post('admin/users', body: user);
  }

  Future<void> updateUser(int id, Map<String, dynamic> user) async {
    await apiClient.put('admin/users/$id', body: user);
  }

  Future<void> deleteUser(int id) async {
    await apiClient.delete('admin/users/$id');
  }

  Future<void> saveProduct(
    Product? product,
    Map<String, dynamic> values, {
    List<XFile> images = const [],
  }) async {
    final id = product?.id;
    if (images.isNotEmpty) {
      final fields = values.map(
        (key, value) => MapEntry(
          key,
          key == 'specs' || key == 'image_urls' || key == 'color_stock'
              ? jsonEncode(value)
              : '$value',
        ),
      );
      await apiClient.upload(
        id == null ? 'admin/products' : 'admin/products/$id',
        fields: fields,
        images: images,
      );
    } else if (id == null) {
      await apiClient.post('admin/products', body: values);
    } else {
      await apiClient.put('admin/products/$id', body: values);
    }
  }

  Future<void> deleteProduct(int id) async {
    await apiClient.delete('admin/products/$id');
  }

  Future<void> updateOrderStatus(int id, String status) async {
    await apiClient.put('admin/orders/$id', body: {'status': status});
  }
}

final adminApiService = AdminApiService();
