library;

export 'src/features/calendar/session_history.dart';

export 'src/ui/workspace_tabs.dart';

export 'src/demo/demo_store.dart';
export 'src/demo/demo_transport.dart'
    show schoolStoragePrefix, schoolMediaClient, DemoSchoolClient;
export 'src/demo/demo_host.dart';
export 'src/demo/school_clock.dart';

export 'src/access/school_client.dart';
export 'src/l10n/l10n_extension.dart';
export 'src/l10n/l10n_lookup.dart';
export 'src/app/edaya_app_root.dart';
export 'src/app/edaya_root_scope.dart';
export 'src/app/router_refresh.dart';
export 'src/app/edaya_colors.dart';
export 'src/app/edaya_tokens.g.dart';
export 'src/app/edaya_typography.dart';
export 'src/app/theme.dart';
export 'src/academic/logbook_note.dart';
export 'src/academic/normalized_average.dart';
export 'src/api/attendance_data.dart';
export 'src/api/document_issuance.dart';
export 'src/api/evaluation_data.dart';
export 'src/api/family_feedback.dart';
export 'src/api/mutation_feedback.dart';
export 'src/api/optional_entity_list.dart';
export 'src/api/planning_data.dart';
export 'src/common/models/timetable_occurrence.dart';
export 'src/common/utils/date_time_parse.dart';
export 'src/common/utils/timetable_session_kind_label.dart';
export 'src/common/utils/entity_query.dart';
export 'src/common/utils/guardian_linked_students.dart';
export 'src/common/models/modal_bottom_sheet_page.dart';
export 'src/common/widgets/account_sheet_body.dart';
export 'src/common/widgets/data_state.dart';
export 'src/common/widgets/route_error_page.dart';
export 'src/config/api_base_url_config.dart';
export 'src/config/developer_settings_config.dart';
export 'src/config/dev_api_url_settings.dart';
export 'src/di/edaya_module.dart';
export 'src/features/auth/app_bootstrap_controller.dart';
export 'src/features/auth/app_session_controller.dart';
export 'src/features/auth/profile_picker_page.dart';
export 'src/features/auth/auth_session_storage.dart';
export 'src/features/auth/login_controller.dart';
export 'src/features/auth/login_page.dart';
export 'src/features/auth/passwordless_login_form.dart';
export 'src/features/invite/invitation_deep_link.dart';
export 'src/features/invite/pending_invitation_store.dart';
export 'src/features/profile_photo/profile_photo_config.dart';
export 'src/features/profile_photo/profile_photo_crop_page.dart';
export 'src/features/profile_photo/profile_photo_encode.dart';
export 'src/features/profile_photo/profile_photo_flow.dart';
export 'src/features/profile_photo/profile_photo_ids.dart';
export 'src/features/profile_photo/profile_photo_pick.dart';
export 'src/features/profile_photo/profile_photo_upload.dart';
export 'src/features/settings/app_settings_controller.dart';
export 'src/features/settings/app_date_formatting.dart';
export 'src/features/settings/app_settings_storage.dart'
    show AppSettingsStorage;
export 'src/features/settings/app_settings_models.dart' show LanguagePreference;
export 'src/features/settings/settings_page.dart';
export 'src/features/account/account_profile_header.dart';
export 'src/features/account/account_profile_models.dart';
export 'src/features/account/account_profile_page.dart';
export 'package:firebase_messaging/firebase_messaging.dart' show RemoteMessage;
export 'src/features/push/push_notifications.dart';
export 'src/ui/edaya_brand_logo.dart';
export 'src/ui/edaya_startup_screen.dart';
export 'src/ui/person_avatar.dart';
export 'src/ui/responsive_metrics.dart';
export 'src/ui/session_card.dart';
export 'src/ui/status_badge.dart';
export 'src/ui/sync_indicator.dart';
export 'src/offline/teacher_outbox_store.dart';

export 'src/features/messaging/conversation_widgets.dart';
export 'src/features/messaging/conversation_controller.dart';
export 'src/features/messaging/conversation_notification_navigation.dart';
export 'src/features/messaging/messaging_events.dart';
export 'src/features/messaging/recipient_inbox_controller.dart';

export 'src/ui/calendar_week_strip.dart';

export 'src/academic/grading_policy.dart';

export 'src/api/student_subject_participation.dart';

export 'src/features/auth/account_security_page.dart';
export 'src/ui/feature_actions.dart';
export 'src/academic/grade_presentation.dart';
export 'src/demo/demo_grading.dart' show demoGrade;
