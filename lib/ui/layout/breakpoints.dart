/// Window size classes based on the Material 3 guidelines.
///
/// - compact  (< 600 dp):  phones in portrait -> bottom navigation, 1 column
/// - medium   (600-839 dp): large/foldable phones, landscape -> side rail, grid
/// - expanded (>= 840 dp):  tablets, desktop -> side rail, list + detail
enum WindowSizeClass { compact, medium, expanded }

class Breakpoints {
  Breakpoints._();

  static const double medium = 600;
  static const double expanded = 840;

  /// From this width the navigation rail also shows its labels.
  static const double large = 1200;

  static WindowSizeClass of(double width) {
    if (width >= expanded) return WindowSizeClass.expanded;
    if (width >= medium) return WindowSizeClass.medium;
    return WindowSizeClass.compact;
  }
}
