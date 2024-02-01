import 'package:example/storage/custom_storage_io.dart';
import 'package:example/storage/custom_storage_web.dart';
import 'package:flutter/foundation.dart';
import 'package:task_manager/task_manager.dart';

abstract class CustomStorage extends Storage {
  const CustomStorage();

  factory CustomStorage.adapter() {
    if (kIsWeb) {
      return CustomStorageWebImpl();
    } else {
      return CustomStorageIOImpl();
    }
  }
}
