import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

enum CropStyle {
  profilePicture,
  freeForm,
}

class ImageCropUtils {
  static final _picker = ImagePicker();

  /// Crop an already-picked file. Returns null if user cancels.
  static Future<File?> cropImage(
    File sourceFile,
    CropStyle cropStyle,
    BuildContext context,
  ) async {
    final List<CropAspectRatioPreset> presets;
    final String title;
    final bool lockAspectRatio;
    final CropAspectRatio? initAspectRatio;

    switch (cropStyle) {
      case CropStyle.profilePicture:
        presets = [CropAspectRatioPreset.square];
        title = 'Crop Profile Photo';
        lockAspectRatio = true;
        initAspectRatio = const CropAspectRatio(ratioX: 1, ratioY: 1);
        break;
      case CropStyle.freeForm:
        presets = [
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.ratio16x9,
        ];
        title = 'Crop Image';
        lockAspectRatio = false;
        initAspectRatio = null;
        break;
    }

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourceFile.path,
      aspectRatio: initAspectRatio,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.primary,
          initAspectRatio: cropStyle == CropStyle.profilePicture
              ? CropAspectRatioPreset.square
              : CropAspectRatioPreset.original,
          lockAspectRatio: lockAspectRatio,
          aspectRatioPresets: presets,
        ),
        IOSUiSettings(
          title: title,
          aspectRatioLockEnabled: lockAspectRatio,
          resetAspectRatioEnabled: !lockAspectRatio,
          aspectRatioPresets: presets,
        ),
      ],
    );

    if (croppedFile == null) return null;
    return File(croppedFile.path);
  }

  /// Pick an image from the given source and crop it. Returns null if user cancels.
  static Future<File?> pickAndCropImage({
    required ImageSource source,
    required CropStyle cropStyle,
    required BuildContext context,
    double maxWidth = 1024,
    double maxHeight = 1024,
    int imageQuality = 85,
  }) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );

    if (pickedFile == null) return null;

    final file = File(pickedFile.path);
    return cropImage(file, cropStyle, context);
  }
}
