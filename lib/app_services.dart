import 'repositories/favourites_repository.dart';
import 'repositories/pantry_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/recipe_repository.dart';
import 'repositories/shopping_list_repository.dart';
import 'services/cloud_backup_service.dart';
import 'services/connectivity_service.dart';
import 'services/local_database.dart';
import 'services/meal_db_api.dart';
import 'services/notification_service.dart';
import 'services/recipe_matcher.dart';
import 'services/sync_queue.dart';
import 'services/sync_service.dart';

/// Composition root: creates every service and repository once and wires
/// them together (simple manual dependency injection).
///
/// Screens get these objects through `provider` instead of creating them
/// themselves, which keeps the UI free of data-access code.
class AppServices {
  AppServices._({
    required this.database,
    required this.api,
    required this.matcher,
    required this.notifications,
    required this.cloud,
    required this.connectivity,
    required this.syncQueue,
    required this.profiles,
    required this.favourites,
    required this.pantry,
    required this.shoppingList,
    required this.recipes,
    required this.sync,
  });

  final LocalDatabase database;
  final MealDbApi api;
  final RecipeMatcher matcher;
  final NotificationService notifications;
  final CloudBackupService cloud;
  final ConnectivityService connectivity;
  final SyncQueue syncQueue;
  final ProfileRepository profiles;
  final FavouritesRepository favourites;
  final PantryRepository pantry;
  final ShoppingListRepository shoppingList;
  final RecipeRepository recipes;
  final SyncService sync;

  static Future<AppServices> create() async {
    final database = LocalDatabase();
    await database.open();

    final api = MealDbApi();
    const matcher = RecipeMatcher();
    final notifications = NotificationService();
    final cloud = CloudBackupService();
    final connectivity = ConnectivityService();
    final syncQueue = SyncQueue(database);

    final profiles = ProfileRepository(database, syncQueue);
    final favourites = FavouritesRepository(database, syncQueue);
    final pantry = PantryRepository(database, syncQueue);
    final shoppingList = ShoppingListRepository(database, syncQueue);
    final recipes =
        RecipeRepository(api, database, favourites, matcher: matcher);

    // Optional features: the app still starts if these fail.
    await notifications.init();
    await cloud.init();

    final sync = SyncService(
      queue: syncQueue,
      cloud: cloud,
      connectivity: connectivity,
      profiles: profiles,
      favourites: favourites,
      pantry: pantry,
      shoppingList: shoppingList,
    )..start();

    return AppServices._(
      database: database,
      api: api,
      matcher: matcher,
      notifications: notifications,
      cloud: cloud,
      connectivity: connectivity,
      syncQueue: syncQueue,
      profiles: profiles,
      favourites: favourites,
      pantry: pantry,
      shoppingList: shoppingList,
      recipes: recipes,
      sync: sync,
    );
  }
}
