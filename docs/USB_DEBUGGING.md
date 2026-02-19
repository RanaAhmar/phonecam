# USB Debugging Setup Guide

Enable USB debugging on your Android phone to use the USB connection mode with PhoneCam.

## Step 1: Enable Developer Options

1. Open **Settings** on your Android phone
2. Scroll down to **About Phone** (may be under System > About Phone)
3. Find **Build Number**
4. **Tap Build Number 7 times** rapidly
5. You'll see the message *"You are now a developer!"*

On Samsung: Settings > About Phone > Software Information > Build Number  
On Pixel: Settings > About Phone > Build Number  
On OnePlus: Settings > About Device > Build Number

## Step 2: Enable USB Debugging

1. Go back to **Settings**
2. Find **Developer Options** (usually at the bottom of Settings, or under System)
3. Toggle **Developer Options** to ON
4. Scroll down and enable **USB Debugging**
5. Tap **OK** on the confirmation dialog

## Step 3: Connect and Authorize

1. Connect your phone to your Mac with a **USB data cable** (must support data transfer, not charge-only)
2. On your phone, a dialog appears: **"Allow USB debugging?"**
3. Check **"Always allow from this computer"**
4. Tap **Allow**

## Step 4: Verify the Connection

On your Mac, open Terminal and run:

```bash
adb devices
```

You should see your device listed:
```
List of devices attached
RF8M12345678    device
```

If you see `unauthorized`, re-authorize on your phone.

## Troubleshooting

**Phone not detected**

Try a different USB cable (many are charge-only), try a different USB port on your Mac, or unplug and replug the cable.

**"Unauthorized" in adb devices**

On your phone, go to Developer Options > Revoke USB debugging authorizations, then unplug and replug the cable and authorize again when prompted.

**ADB not found on Mac**

Install via Homebrew:
```bash
brew install android-platform-tools
```

Or download from [Android SDK Platform Tools](https://developer.android.com/tools/releases/platform-tools).

**USB Debugging option missing**

Make sure you tapped Build Number exactly 7 times. On some phones, you need to enter your PIN or password first.

## Security Note

USB debugging allows a connected computer to install apps and access your device. Only enable it when needed and disable it when not in use. PhoneCam uses USB debugging only for port forwarding — it does not install anything or access your files.
