import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../core/supabase_client.dart';
import '../shared/models/user_profile.dart';
import 'profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  try {
    final client = ref.watch(supabaseClientProvider);
    return ProfileRepository(client: client);
  } catch (_) {
    return ProfileRepository(client: null);
  }
});

final serviceCategoriesProvider = FutureProvider<List<ServiceCategory>>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getServiceCategories();
});

class ProfileState {
  final UserProfile? profile;
  final TukangProfile? tukangProfile;
  final UserRole activeRole;
  final bool isLoading;
  final String? error;

  const ProfileState({
    this.profile,
    this.tukangProfile,
    this.activeRole = UserRole.customer,
    this.isLoading = false,
    this.error,
  });

  bool get canSwitchRole => profile?.hasDualRole ?? false;

  ProfileState copyWith({
    UserProfile? profile,
    TukangProfile? tukangProfile,
    UserRole? activeRole,
    bool? isLoading,
    String? error,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      tukangProfile: tukangProfile ?? this.tukangProfile,
      activeRole: activeRole ?? this.activeRole,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repo;
  final Ref _ref;

  ProfileNotifier(this._repo, this._ref) : super(const ProfileState()) {
    _init();
  }

  void _init() {
    _ref.listen(authProvider, (previous, next) {
      if (next.user != null) {
        loadProfile(next.user!.id);
      } else {
        state = const ProfileState();
      }
    });

    final currentUser = _ref.read(authProvider).user;
    if (currentUser != null) {
      loadProfile(currentUser.id);
    }
  }

  Future<void> loadProfile(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _repo.getProfile(userId);
      TukangProfile? tukangProfile;
      if (profile != null && profile.isTukang) {
        tukangProfile = await _repo.getTukangProfile(userId);
      }

      UserRole initialRole = state.activeRole;
      if (profile != null) {
        if (!profile.isCustomer && profile.isTukang) {
          initialRole = UserRole.tukang;
        } else if (profile.isCustomer && !profile.isTukang) {
          initialRole = UserRole.customer;
        }
      }

      state = state.copyWith(
        profile: profile,
        tukangProfile: tukangProfile,
        activeRole: initialRole,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void switchRole() {
    if (!state.canSwitchRole) return;
    final newRole = state.activeRole == UserRole.customer
        ? UserRole.tukang
        : UserRole.customer;
    state = state.copyWith(activeRole: newRole);
  }

  Future<void> becomeTukang({
    required String bio,
    required List<String> serviceTypeIds,
    required List<PaymentMethod> paymentMethods,
    Map<String, dynamic> paymentDetails = const {},
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.becomeTukang(
        bio: bio,
        serviceTypeIds: serviceTypeIds,
        paymentMethods: paymentMethods,
        paymentDetails: paymentDetails,
      );
      final userId = state.profile?.id;
      if (userId != null) {
        await loadProfile(userId);
        state = state.copyWith(activeRole: UserRole.tukang);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateTukangPayments({
    required List<PaymentMethod> paymentMethods,
    required Map<String, dynamic> paymentDetails,
  }) async {
    final userId = state.profile?.id;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.updateTukangPayments(
        profileId: userId,
        paymentMethods: paymentMethods,
        paymentDetails: paymentDetails,
      );
      await loadProfile(userId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? fullName,
    String? phone,
    bool? isOnline,
  }) async {
    final userId = state.profile?.id;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.updateProfile(
        userId: userId,
        fullName: fullName,
        phone: phone,
        isOnline: isOnline,
      );
      await loadProfile(userId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return ProfileNotifier(repo, ref);
});
