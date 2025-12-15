import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ImageCacheConfig {
  static final customCacheManager = CacheManager(
    Config(
      'customCacheKey',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 1000,
      repo: JsonCacheInfoRepository(databaseName: 'customCacheKey'),
      fileService: HttpFileService(),
    ),
  );

  static void configureCachedNetworkImage() {
    // Set memory cache size limit (in MB)
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        100 * 1024 * 1024; // 100 MB

    // Set maximum number of images in memory cache
    PaintingBinding.instance.imageCache.maximumSize = 100;
  }
}
