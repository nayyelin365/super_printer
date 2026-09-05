import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/staff_repository.dart';
import '../domain/staff_member.dart';

final staffRepositoryProvider = Provider<StaffRepository>((ref) => StaffRepository());

final staffMembersProvider = StreamProvider<List<StaffMember>>((ref) {
  return ref.watch(staffRepositoryProvider).watchAll();
});

class StaffController {
  StaffController(this._ref);
  final Ref _ref;

  Future<StaffMember> create({
    required String name,
    required String role,
    String? phoneNumber,
    String? email,
  }) => _ref
      .read(staffRepositoryProvider)
      .create(name: name, role: role, phoneNumber: phoneNumber, email: email);

  Future<void> update(StaffMember member) => _ref.read(staffRepositoryProvider).update(member);

  Future<void> remove(String id) => _ref.read(staffRepositoryProvider).remove(id);
}

final staffControllerProvider = Provider<StaffController>((ref) => StaffController(ref));
