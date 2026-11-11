import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/session_view_model.dart';
import '../layout/breakpoints.dart';
import '../widgets/profile_widgets.dart';
import 'cook_screen.dart';
import 'favourites_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'shopping_list_screen.dart';

/// Main navigation of the app.
///
/// - Compact windows (phones): bottom NavigationBar.
/// - Medium/expanded windows (tablets, desktop): side NavigationRail,
///   which shows labels next to the icons on very wide windows.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.home_outlined, selected: Icons.home, label: 'Home'),
    (icon: Icons.kitchen_outlined, selected: Icons.kitchen, label: 'Cook'),
    (icon: Icons.favorite_border, selected: Icons.favorite, label: 'Favourites'),
    (
      icon: Icons.shopping_cart_outlined,
      selected: Icons.shopping_cart,
      label: 'Shopping'
    ),
    (icon: Icons.person_outline, selected: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<SessionViewModel>().current;
    if (profile == null) return const SizedBox.shrink();

    // Screens that depend on the diet are rebuilt when the diet changes.
    final dietKey = '${profile.id}-${profile.diet.name}';
    final pages = [
      HomeScreen(key: ValueKey('home-$dietKey')),
      CookScreen(key: ValueKey('cook-$dietKey')),
      const FavouritesScreen(),
      const ShoppingListScreen(),
      const ProfileScreen(),
    ];

    // IndexedStack keeps each tab's state (scroll position, search, ...).
    final body = IndexedStack(index: _index, children: pages);

    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = Breakpoints.of(constraints.maxWidth);

        if (sizeClass == WindowSizeClass.compact) {
          return Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: d.label,
                  ),
              ],
            ),
          );
        }

        final extended = constraints.maxWidth >= Breakpoints.large;
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  extended: extended,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Tooltip(
                      message: profile.nickname,
                      child: ProfileAvatar(avatar: profile.avatar),
                    ),
                  ),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selected),
                        label: Text(d.label),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}
