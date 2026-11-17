import 'package:flutter/material.dart';
import 'package:ngo_app/features/reporting/workspace_overview.dart';

class AdminFellowListScreen extends StatelessWidget {
  const AdminFellowListScreen({super.key});
  @override
  Widget build(BuildContext context) => const WorkspaceOverview(admin: true);
}
