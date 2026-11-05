# HANSB Coffee Manager - Build Instructions

## Building for Windows

### Local Build

1. Ensure you have Flutter installed and configured for Windows development
2. Run the following commands:

```bash
flutter pub get
flutter build windows --release
```

3. The executable will be in: `build/windows/x64/runner/Release/`

### GitHub Actions Build

The project is configured with GitHub Actions to automatically build Windows releases.

#### Automatic Builds

- **On Push**: Builds are triggered automatically when code is pushed to `main` or `master` branch
- **Manual Trigger**: You can manually trigger a build from the "Actions" tab on GitHub
- **Pull Requests**: Builds are also triggered for pull requests

#### Creating a Release

To create a new release:

1. Tag your commit with a version number:
```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

2. GitHub Actions will automatically:
   - Build the Windows executable
   - Create a ZIP file named `HANSB-Windows-x64.zip`
   - Create a GitHub Release with the ZIP file attached

#### Downloading Builds

**From GitHub Actions:**
1. Go to the "Actions" tab in your repository
2. Click on the latest workflow run
3. Download the `HANSB-Windows-x64` artifact

**From Releases:**
1. Go to the "Releases" section in your repository
2. Download `HANSB-Windows-x64.zip` from the latest release

## App Configuration

### Windows App Name
The Windows application title is set to **"HANSB"** in `windows/runner/main.cpp`

### App Icon
To change the Windows app icon:
1. Place your icon file (`app_icon.ico`) in `windows/runner/resources/`
2. Update `windows/runner/Runner.rc` to reference your icon
3. Rebuild the application

## Version Management

Update version numbers in `pubspec.yaml`:
```yaml
version: 1.0.0+1
```
- Format: `MAJOR.MINOR.PATCH+BUILD_NUMBER`
- Example: `1.0.0+1` = Version 1.0.0, Build 1

## Deployment

The built Windows application can be distributed as:
1. **ZIP File**: Direct download and extract
2. **Installer**: Create using tools like Inno Setup (optional)
3. **Microsoft Store**: Package as MSIX (optional)

## Firebase Configuration

Ensure Firebase is properly configured:
- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`  
- Web: Firebase config in `web/index.html`

## Support

For build issues or questions, contact the development team.
