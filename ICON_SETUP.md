# Setting Up the HANSB App Icon

## Current Icon Location
The Windows app icon is located at: `windows/runner/resources/app_icon.ico`

## Steps to Update the Icon

### Option 1: Online Converter (Easiest)
1. Take your `assets/logo.jpg` or `assets/logo.png`
2. Go to https://convertio.co/png-ico/ or https://icoconvert.com/
3. Upload your logo
4. Select these sizes: 16x16, 32x32, 48x48, 256x256
5. Download the ICO file
6. Replace `windows/runner/resources/app_icon.ico` with your new file
7. Rebuild: `flutter build windows --release`

### Option 2: ImageMagick (Command Line)
If you have ImageMagick installed:
```bash
magick convert assets/logo.png -define icon:auto-resize=256,128,96,64,48,32,16 windows/runner/resources/app_icon.ico
```

### Option 3: GIMP (Free Software)
1. Open your logo in GIMP
2. Scale to 256x256: Image → Scale Image
3. Export as ICO: File → Export As → app_icon.ico
4. Save to `windows/runner/resources/app_icon.ico`
5. Rebuild the app

## Verification

After replacing the icon:
1. Clean build: `flutter clean`
2. Rebuild: `flutter build windows --release`
3. Check the executable in `build/windows/x64/runner/Release/`
4. Right-click the `.exe` file → Properties → Check the icon

## Icon Requirements
- **Format**: ICO (Windows Icon)
- **Recommended Sizes**: 16×16, 32×32, 48×48, 256×256 (multi-size ICO)
- **Transparency**: Supported (PNG within ICO)
- **Color Depth**: 32-bit recommended

## Current Logo Location
Your app logo should be in: `assets/logo.jpg`

Make sure to use a square version of your logo for best results!
