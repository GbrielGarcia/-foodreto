import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/presentation/pages/feed_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/providers/super_admin_providers.dart';
import '../../features/category/presentation/pages/categories_page.dart';
import '../../features/category/presentation/pages/category_page.dart';
import '../../features/challenge/presentation/pages/challenge_room_page.dart';
import '../../features/challenge/presentation/pages/challenges_page.dart';
import '../../features/challenge/presentation/pages/create_challenge_page.dart';
import '../../features/challenge/presentation/pages/join_challenge_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/leaderboard/presentation/pages/rankings_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/onboarding_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/providers/profile_providers.dart';
import '../../features/restaurant/presentation/pages/admin_account_page.dart';
import '../../features/restaurant/presentation/pages/admin_dashboard_page.dart';
import '../../features/restaurant/presentation/pages/admin_establishment_detail_page.dart';
import '../../features/restaurant/presentation/pages/admin_establishments_page.dart';
import '../../features/restaurant/presentation/pages/create_establishment_page.dart';
import '../../features/restaurant/presentation/pages/edit_establishment_page.dart';
import '../../features/restaurant/presentation/pages/explore_page.dart';
import '../../features/restaurant/presentation/pages/my_establishments_page.dart';
import '../../features/restaurant/presentation/pages/restaurant_detail_page.dart';
import '../../features/restaurant/presentation/pages/restaurant_ranking_page.dart';
import '../../features/social/presentation/pages/friend_requests_page.dart';
import '../../features/social/presentation/pages/friends_page.dart';
import '../../features/social/presentation/pages/public_profile_page.dart';
import '../../features/social/presentation/pages/user_search_page.dart';
import '../../shared/widgets/adaptive_shell.dart';
import '../../shared/widgets/admin_shell.dart';
import '../config/app_config.dart';
import 'app_routes.dart';
import 'auth_redirect.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final config = ref.watch(appConfigProvider);

  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.listen(profileStatusProvider, (_, _) => refresh.value++);
  ref.listen(superAdminStatusProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    observers: [
      if (config.sendsAnalytics)
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final bool? isSignedIn = auth.hasValue
          ? auth.value != null
          : (auth.hasError ? false : null);
      return authRedirect(
        isSignedIn: isSignedIn,
        uri: state.uri,
        profile: ref.read(profileStatusProvider),
        isSuperAdmin: ref.read(superAdminStatusProvider),
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) =>
            LoginPage(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) =>
            RegisterPage(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.join,
        builder: (context, state) =>
            JoinChallengePage(code: state.pathParameters['code']!),
      ),
      GoRoute(
        path: AppRoutes.create,
        builder: (context, state) => CreateChallengePage(
          initialCategoryId: state.uri.queryParameters['category'],
        ),
      ),

      // —— Panel Super Admin (shell propio, distinto al de usuarios) ——
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdminShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.admin,
                builder: (context, state) => const AdminDashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.adminEstablishments,
                builder: (context, state) => const AdminEstablishmentsPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => AdminEstablishmentDetailPage(
                      establishmentId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.adminAccount,
                builder: (context, state) => const AdminAccountPage(),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.friends,
        builder: (context, state) => const FriendsPage(),
      ),
      GoRoute(
        path: AppRoutes.friendRequests,
        builder: (context, state) => const FriendRequestsPage(),
      ),
      GoRoute(
        path: AppRoutes.userSearch,
        builder: (context, state) => const UserSearchPage(),
      ),
      GoRoute(
        path: AppRoutes.feed,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FeedPage(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: AppRoutes.restaurant,
        builder: (context, state) => RestaurantDetailPage(
          restaurantId: state.pathParameters['restaurantId']!,
        ),
        routes: [
          GoRoute(
            path: 'ranking',
            builder: (context, state) => RestaurantRankingPage(
              restaurantId: state.pathParameters['restaurantId']!,
              initialCategoryId: state.uri.queryParameters['category'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.createEstablishment,
        builder: (context, state) => const CreateEstablishmentPage(),
      ),
      GoRoute(
        path: AppRoutes.myEstablishments,
        builder: (context, state) => const MyEstablishmentsPage(),
      ),
      GoRoute(
        path: AppRoutes.editEstablishment,
        builder: (context, state) => EditEstablishmentPage(
          establishmentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.publicProfile,
        builder: (context, state) => PublicProfilePage(
          userId: state.pathParameters['userId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.challengeRoom,
        builder: (context, state) =>
            ChallengeRoomPage(challengeId: state.pathParameters['id']!),
      ),

      // —— App usuario ——
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdaptiveShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomePage(),
                routes: [
                  GoRoute(
                    path: 'categories',
                    builder: (context, state) => const CategoriesPage(),
                  ),
                  GoRoute(
                    path: 'category/:slug',
                    builder: (context, state) =>
                        CategoryPage(slug: state.pathParameters['slug']!),
                  ),
                ],
              ),
            ],
          ),
          _branch(AppRoutes.explore, const ExplorePage()),
          _branch(AppRoutes.challenges, const ChallengesPage()),
          _branch(AppRoutes.rankings, const RankingsPage()),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfilePage(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => const EditProfilePage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

StatefulShellBranch _branch(String path, Widget page) {
  return StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (context, state) => page)],
  );
}
