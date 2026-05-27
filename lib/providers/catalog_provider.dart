import 'package:flutter/material.dart';

enum CatalogSpecialFilter { none, promo, retourStock, vedette }

class CatalogProvider extends ChangeNotifier {
  int? _selectedCategoryId;
  CatalogSpecialFilter _specialFilter = CatalogSpecialFilter.none;

  int? get selectedCategoryId => _selectedCategoryId;
  CatalogSpecialFilter get specialFilter => _specialFilter;

  void setFilter({int? categoryId, CatalogSpecialFilter? specialFilter}) {
    _selectedCategoryId = categoryId;
    if (specialFilter != null) {
      _specialFilter = specialFilter;
    }
    notifyListeners();
  }

  void clearFilters() {
    _selectedCategoryId = null;
    _specialFilter = CatalogSpecialFilter.none;
    notifyListeners();
  }
}
