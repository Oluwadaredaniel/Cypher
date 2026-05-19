import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionService {
  static Future<void> requestAllPermissions() async {
    if (!Platform.isAndroid) return;

    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    final int sdkInt = androidInfo.version.sdkInt;

    // Basic permissions
    await [
      Permission.camera,
      Permission.location,
    ].request();

    if (sdkInt >= 33) {
      // Android 13+ Scoped Media Permissions
      await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();
    } else {
      // Legacy Storage Permissions
      await [
        Permission.storage,
      ].request();
    }

    // Special: Manage External Storage (for full file access if needed)
    // This is often required for the app to see ALL files in Download folder
    if (sdkInt >= 30) {
      var status = await Permission.manageExternalStorage.status;
      if (status.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    }
  }

  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;

    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    
    if (androidInfo.version.sdkInt >= 33) {
      return await Permission.photos.isGranted || await Permission.videos.isGranted;
    } else if (androidInfo.version.sdkInt >= 30) {
      return await Permission.manageExternalStorage.isGranted || await Permission.storage.isGranted;
    } else {
      return await Permission.storage.isGranted;
    }
  }
}
