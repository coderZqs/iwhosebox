import 'package:flutter/material.dart';

/// 全局底部导航与页面路由管理服务
class AppNavigation {
  /// 底部导航栏当前选中的 Tab 索引 (0: Shop, 1: Categories, 2: Cart, 3: Profile)
  static final ValueNotifier<int> currentTab = ValueNotifier<int>(0);

  /// 切换到底部指定 Tab
  static void switchToTab(int index) {
    if (currentTab.value != index) {
      currentTab.value = index;
    }
  }

  /// 安全前往购物页面 (Shop 首页)
  /// - 若当前处于二级/三级 push 栈中，先安全 pop 回上层
  /// - 然后将底部导航栏切换至 Tab 0 (Shop)
  /// - 杜绝在栈底根路由误调 Navigator.pop 导致整个 App 白屏
  static void goToShop(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    switchToTab(0);
  }
}
