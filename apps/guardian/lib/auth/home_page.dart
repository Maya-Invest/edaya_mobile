import 'package:edaya_api_client/edaya_api_client.dart' as api;
import 'package:edaya_auth/edaya_auth.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../students/guardian_students_controller.dart';
import '../students/linked_student.dart';
import 'app_session_controller.dart';

class HomePage extends LScopedView<GuardianStudentsController> {
  const HomePage({super.key});

  @override
  GuardianStudentsController onConfigScope(LevitScope scope) {
    return scope.put(
      () => GuardianStudentsController(
        session: scope.find<AppSessionController>(),
        authClient: scope.find<AuthClient>(),
      ),
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    GuardianStudentsController controller,
  ) {
    final session = context.levit.find<AppSessionController>();
    final studentsController = controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian home'),
        actions: [
          LWatch(
            () => IconButton(
              tooltip: 'Refresh',
              onPressed: studentsController.isBusy.value
                  ? null
                  : studentsController.loadStudents,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: LWatch(
        () {
          final user = session.user.value;
          final grants = session.grants.value;
          final linkedStudents = studentsController.students.value;
          final errorMessage = studentsController.errorMessage.value;
          final isLoading = studentsController.isBusy.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _DebugSessionPanel(user: user, grants: grants),
                    const SizedBox(height: 24),
                    Text(
                      'Linked students',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (isLoading && linkedStudents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (errorMessage.isNotEmpty)
                      Text(
                        errorMessage,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    else if (linkedStudents.isEmpty)
                      const Text('No linked students found.')
                    else
                      ...linkedStudents.map(
                        (student) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _StudentTile(student: student),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: LWatch(
                  () => OutlinedButton.icon(
                    onPressed: session.isSigningOut.value
                        ? null
                        : session.signOut,
                    icon: session.isSigningOut.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout),
                    label: Text(
                      session.isSigningOut.value ? 'Signing out…' : 'Log out',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DebugSessionPanel extends StatelessWidget {
  const _DebugSessionPanel({required this.user, required this.grants});

  final AuthUser? user;
  final api.EffectiveGrantsResponse? grants;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sessionGrants = grants;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Debug · session',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Signed in',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text('Email: ${user?.email ?? 'unknown'}'),
          Text('User id: ${user?.id ?? 'unknown'}'),
          const SizedBox(height: 16),
          Text(
            'School session',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (sessionGrants == null)
            const Text('No effective grants loaded.')
          else ...[
            Text('Kind: ${sessionGrants.kind}'),
            Text('Actor id: ${sessionGrants.actorId}'),
            Text('School id: ${sessionGrants.schoolId}'),
          ],
        ],
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student});

  final LinkedStudent student;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(student.initials),
        ),
        title: Text(student.fullName),
        subtitle: Text(
          [
            if (student.matricule != null) 'Matricule: ${student.matricule}',
            'Status: ${student.status}',
          ].join(' · '),
        ),
      ),
    );
  }
}
