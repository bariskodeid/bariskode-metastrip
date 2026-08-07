/// Application-wide constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'MetaStrip';
  static const String appTagline = 'Strip the invisible. Own your files.';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;

  // File Processing
  static const int maxFilesPerSession = 50;
  static const int maxConcurrentFiles = 4;
  static const int maxFileSizeBytes = 2 * 1024 * 1024 * 1024; // 2GB
  static const int maxInlineHashSizeBytes = 100 * 1024 * 1024; // 100MB
  static const int maxInlineExifSizeBytes = 10 * 1024 * 1024; // 10MB
  static const int maxArchiveAndDocumentSizeBytes = 50 * 1024 * 1024; // 50MB
  static const int maxAudioScanBytes = 1024 * 1024; // 1MB prefix untuk LP3/FLAC/OGG
  static const int maxPdfExtractionSizeBytes = 10 * 1024 * 1024; // 10MB
  static const int maxJpegRemovalSizeBytes = 50 * 1024 * 1024; // 50MB
  static const int maxZipEntryDecompressBytes = 64 * 1024 * 1024; // 64MB per entry
  static const int maxZipCumulativeDecompressBytes =
      128 * 1024 * 1024; // 128MB per archive
  static const int maxPngTextChunks = 32;
  static const int maxMetadataFieldChars = 4096;
  static const int defaultJpegQuality = 95;

  // Performance Targets (milliseconds)
  static const int targetStartupCold = 2000;
  static const int targetStartupWarm = 500;
  static const int targetMetadataExtractionImage = 500;
  static const int targetMetadataExtractionVideo = 1000;
  static const int targetMetadataExtractionDocument = 2000;

  // Storage
  static const String defaultOutputFolderName = 'MetaStrip_Output';
  static const String thumbnailCacheFolder = 'thumbnails';
  static const String tempProcessingFolder = 'temp';

  // SharedPreferences Keys
  static const String keyOnboardingCompleted = 'onboarding_completed';
  static const String keyOutputFolderPath = 'output_folder_path';
  static const String keyColorTheme = 'color_theme';
  static const String keyAppSettings = 'app_settings';

  // Default Settings
  static const String defaultTheme = 'Dark Industrial';
  static const String defaultNamingTemplate = '{name}_clean';
  static const String defaultFolderStructure = 'flat';
  static const bool defaultKeepOriginal = true;
  static const bool defaultAutoConfirm = false;
  static const bool defaultComputeHashesAuto = false;
  static const bool defaultShowRawMetadata = true;

  // UI
  static const double minTouchTarget = 48.0;
  static const int snackbarDurationMs = 3000;
  static const int snackbarErrorDurationMs = 5000;

  // Retry Logic
  static const int maxRetryAttempts = 3;
  static const int retryDelayMs = 1000;
}
