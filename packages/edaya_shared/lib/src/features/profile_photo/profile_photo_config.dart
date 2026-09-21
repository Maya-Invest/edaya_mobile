const defaultProfilePhotoMaxBytes = 1048576;
const profilePhotoExportSize = 640;
const profilePhotoJpegMime = 'image/jpeg';
const profilePhotoFileName = 'profile.jpg';

int profilePhotoMaxBytes() {
  return const int.fromEnvironment(
    'PROFILE_PHOTO_MAX_BYTES',
    defaultValue: defaultProfilePhotoMaxBytes,
  );
}

class ProfilePhotoTooLargeException implements Exception {
  const ProfilePhotoTooLargeException();
}
