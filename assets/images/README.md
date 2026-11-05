# Assets Folder - Images for HANS. B Coffee Management System

## Required Images

### Splash Screen Images
Place the following images in this folder:

1. **`splash_logo.png`** (512x512px recommended)
   - Company logo or coffee icon
   - Centered on splash screen
   - Transparent background recommended

2. **`company_name.png`** (Width: 300-400px, Height: 60-100px)
   - Company name/branding text
   - Appears at bottom of splash screen
   - Transparent background

### App Images
3. **`app_icon.png`** (1024x1024px)
   - For app launcher icon
   - Coffee/company themed

### Onboarding Images (Optional)
4. **`onboarding_1.png`** to **`onboarding_5.png`**
   - Illustrations for onboarding screens
   - Currently using icons, but can be replaced with images

### User/Farmer Photos
Images will be stored on ImgBB, not in assets.

---

## Current Status

The app currently uses:
- ☕ **Coffee icon** as placeholder for logo
- **Text-based** company branding
- **Icon-based** onboarding (no images needed yet)

You can replace these with actual images by:
1. Adding your images to this folder
2. Running: `flutter pub run flutter_native_splash:create`
3. Hot reload the app

---

## Image Specifications

### Splash Logo
- Format: PNG (with transparency)
- Size: 512x512px
- Max file size: 2MB
- Background: Transparent

### Company Name
- Format: PNG (with transparency)
- Size: 400x80px (approx)
- Max file size: 500KB
- Background: Transparent

### App Icon
- Format: PNG
- Size: 1024x1024px
- No transparency needed
- Will be automatically resized for all platforms

---

## Generating Splash Screen

After adding images, run:
```bash
flutter pub run flutter_native_splash:create
```

This will automatically generate:
- Android splash screens (all densities)
- iOS splash screens
- Web splash screen
- Native splash for Android 12+

---

## Quick Setup with Placeholder

If you don't have images yet, the app will use:
- Coffee icon (✅ Built-in)
- Text branding (✅ Automatic)

The app is fully functional without custom images!
