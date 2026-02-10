import 'package:flutter/material.dart';
import 'package:powerboards/meshagent/meshagent.dart';

class User {
  User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.isAdmin = false,
    this.isDeveloper = false,
    this.canCreateRooms = false,
  });

  final String id;
  final String email;
  final String? firstName;
  final String? lastName;

  final bool isAdmin;
  final bool isDeveloper;
  final bool canCreateRooms;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    email: json['email'],
    firstName: json['first_name'],
    lastName: json['last_name'],
    isAdmin: json['is_admin'] ?? false,
    isDeveloper: json['is_developer'] ?? false,
    canCreateRooms: json['can_create_rooms'] ?? false,
  );

  @override
  String toString() => 'User(userId: $id, email: $email, firstName: $firstName, lastName: $lastName)';
}

enum LoadingState { idle, loading, loaded, error }

class UserBuilder extends StatefulWidget {
  const UserBuilder({super.key, required this.userId, required this.builder});

  final String userId;
  final Widget Function(BuildContext context, User? user, LoadingState state) builder;

  @override
  State createState() => _UserName();
}

class _UserName extends State<UserBuilder> {
  LoadingState state = LoadingState.idle;
  User? user;

  @override
  void initState() {
    super.initState();

    final client = getMeshagentClient();

    client
        .getUserProfile(widget.userId)
        .then((json) {
          if (mounted) {
            setState(() {
              state = LoadingState.loaded;
              user = User.fromJson(json);
            });
          }
        })
        .catchError((error) {
          if (mounted) {
            setState(() {
              state = LoadingState.error;
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, user, state);
}
