import 'package:flutter/material.dart';

import '../utils/constants/app_colors.dart';
import '../widgets/styled_bottom_nav.dart';
import 'tabs/catalog_tab.dart';
import 'tabs/discover_tab.dart';
import 'tabs/management_tab.dart';
import 'tabs/orders_tab.dart';

class MainShellView extends StatefulWidget {
  const MainShellView({super.key});

  @override
  State<MainShellView> createState() => _MainShellViewState();
}

class _MainShellViewState extends State<MainShellView> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _index,
        children: const [
          DiscoverTab(),
          CatalogTab(),
          OrdersTab(),
          ManagementTab(),
        ],
      ),
      bottomNavigationBar: StyledBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
