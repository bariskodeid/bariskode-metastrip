# Requirements Document

## Introduction

MetaStrip is a Flutter mobile application (Android 7.0+, iOS 13.0+) that is planned to view and remove metadata from various file types completely offline. These are target requirements, not a statement of current implementation: the current Viewer allowlist, extractor registry, and 19-extension Remover registry are narrower, and the four removal modes are planned/unwired.

The application follows an Industrial Minimalism design language with dark themes, monospace typography, and high contrast interfaces. All processing occurs on-device with no server communication, ensuring complete user privacy.

## Glossary

- **MetaStrip_App**: The complete Flutter mobile application system
- **Metadata_Viewer**: The feature module responsible for displaying file metadata
- **Metadata_Remover**: The feature module responsible for removing metadata from files
- **Onboarding_Wizard**: The first-run setup flow for folder configuration and permissions
- **Settings_Manager**: The feature module for application configuration
- **File_Picker**: The system component for selecting files from device storage
- **Metadata_Extractor**: The data layer component that extracts metadata from files
- **Metadata_Stripper**: The data layer component that removes metadata from files
- **Output_Folder**: The user-configured directory where processed files are saved
- **Removal_Mode**: The strategy for metadata removal (Full Strip, Selective Strip, Anonymize, Preserve Technical)
- **Processing_Job**: A queued task to remove metadata from one or more files
- **Share_Intent**: Android/iOS system mechanism for receiving files from other applications
- **Privacy_Sensitive_Field**: Metadata fields containing personally identifiable information (GPS, author, device info)
- **File_Hash**: Cryptographic checksum (MD5 or SHA-256) computed for file integrity verification
- **Theme_Preset**: A predefined color scheme following Industrial Minimalism design language
- **Isolate**: Dart concurrency primitive for running heavy processing without blocking UI
- **FFmpeg**: Open-source multimedia framework used for video/audio metadata operations
- **EXIF**: Exchangeable Image File Format metadata standard for images
- **ID3**: Metadata standard for MP3 audio files
- **Vorbis_Comments**: Metadata standard for FLAC, OGG, and Opus audio files
- **XMP**: Extensible Metadata Platform standard for embedded metadata
- **IPTC**: International Press Telecommunications Council metadata standard
- **Round_Trip_Property**: A correctness property where parsing then printing produces equivalent output


## Requirements

### Requirement 1: Application Initialization and Onboarding

**User Story:** As a first-time user, I want to complete an onboarding wizard, so that I can configure the application before processing files.

#### Acceptance Criteria

1. WHEN THE MetaStrip_App launches for the first time, THE Onboarding_Wizard SHALL display a welcome screen with application name and tagline
2. THE Onboarding_Wizard SHALL present five sequential slides with navigation controls
3. WHEN THE user completes slide 4, THE Onboarding_Wizard SHALL request Output_Folder selection via system directory picker
4. WHEN THE user completes slide 5, THE Onboarding_Wizard SHALL explain picker-scoped access and SHALL NOT request broad storage/media permissions for Viewer MVP
5. WHEN THE user acknowledges picker-scoped access and selects an Output_Folder, THE Onboarding_Wizard SHALL persist completion status to local storage
6. WHEN THE user completes onboarding, THE MetaStrip_App SHALL navigate to the main application interface
7. WHEN THE MetaStrip_App launches after onboarding completion, THE MetaStrip_App SHALL skip the Onboarding_Wizard
8. FOR ALL onboarding state transitions, THE Onboarding_Wizard SHALL maintain progress indicator visibility

### Requirement 2: File Selection and Import

**User Story:** As a user, I want to select multiple files from various sources, so that I can view or remove their metadata.

#### Acceptance Criteria

1. WHEN THE user taps the add files button in Metadata_Viewer, THE File_Picker SHALL display a multi-select file picker filtered by supported extensions
2. WHEN THE user selects files via File_Picker, THE Metadata_Viewer SHALL accept up to 50 files per session
3. WHEN THE user selects more than 50 files, THE Metadata_Viewer SHALL display a warning message and accept only the first 50 files
4. WHEN THE MetaStrip_App receives a Share_Intent from another application, THE MetaStrip_App SHALL extract file paths from the intent
5. WHEN THE MetaStrip_App receives files via Share_Intent, THE MetaStrip_App SHALL filter files by supported extensions
6. WHEN THE MetaStrip_App receives valid files via Share_Intent, THE MetaStrip_App SHALL navigate to Metadata_Remover with the file list
7. WHEN THE user adds a file already present in the current session, THE Metadata_Viewer SHALL deduplicate based on file path and File_Hash
8. THE File_Picker SHALL support selection from device storage, gallery, and file manager applications


### Requirement 3: Image Metadata Extraction

**User Story:** As a user, I want to view detailed metadata from image files, so that I can understand what information is embedded in my photos.

#### Acceptance Criteria

1. WHEN THE user selects a JPEG file, THE Metadata_Extractor SHALL extract EXIF metadata including GPS coordinates, camera make and model, lens information, ISO, aperture, shutter speed, and focal length
2. WHEN THE user selects a JPEG file, THE Metadata_Extractor SHALL extract IPTC metadata including caption, keywords, and copyright information
3. WHEN THE user selects a PNG file, THE Metadata_Extractor SHALL extract tEXt, zTXt, and iTXt chunks including author, creation time, software, and comments
4. WHEN THE user selects a WebP file, THE Metadata_Extractor SHALL extract embedded EXIF and XMP metadata
5. WHEN THE user selects a TIFF file, THE Metadata_Extractor SHALL extract full EXIF, IPTC, GPS, and embedded thumbnail metadata
6. WHEN THE user selects a HEIC file, THE Metadata_Extractor SHALL extract EXIF, GPS, and color profile metadata
7. WHEN THE user selects a RAW format file (CR2, NEF, ARW, DNG), THE Metadata_Extractor SHALL extract manufacturer-specific metadata and lens data
8. WHEN THE Metadata_Extractor completes extraction for an image file, THE Metadata_Extractor SHALL complete processing within 500 milliseconds
9. IF THE Metadata_Extractor encounters a corrupted image file, THEN THE Metadata_Extractor SHALL return file system metadata only with an error indicator
10. FOR ALL image files, THE Metadata_Extractor SHALL identify Privacy_Sensitive_Fields including GPS coordinates, device information, and author data

### Requirement 4: Video Metadata Extraction

**User Story:** As a user, I want to view metadata from video files, so that I can understand recording details and embedded information.

#### Acceptance Criteria

1. WHEN THE user selects an MP4 or MOV file, THE Metadata_Extractor SHALL extract container metadata including title, author, creation date, GPS location, encoder, duration, bitrate, resolution, and codec information
2. WHEN THE user selects an AVI file, THE Metadata_Extractor SHALL extract RIFF INFO chunk metadata
3. WHEN THE user selects an MKV file, THE Metadata_Extractor SHALL extract Matroska tags including title, artist, date, encoder, language, and chapters
4. WHEN THE user selects a WebM file, THE Metadata_Extractor SHALL extract WebM tags and stream information
5. WHEN THE user selects a video file, THE Metadata_Extractor SHALL extract stream information for all video and audio tracks including codec, bitrate, resolution, sample rate, and channel configuration
6. WHEN THE Metadata_Extractor processes video files, THE Metadata_Extractor SHALL use FFmpeg for metadata extraction
7. WHEN THE Metadata_Extractor completes extraction for a video file, THE Metadata_Extractor SHALL complete processing within 1 second
8. IF THE Metadata_Extractor encounters an unsupported video codec, THEN THE Metadata_Extractor SHALL extract container-level metadata and return a warning for stream-level data
9. FOR ALL video files, THE Metadata_Extractor SHALL identify Privacy_Sensitive_Fields including GPS tracks, author information, and device identifiers


### Requirement 5: Audio Metadata Extraction

**User Story:** As a user, I want to view metadata from audio files, so that I can see track information and embedded tags.

#### Acceptance Criteria

1. WHEN THE user selects an MP3 file, THE Metadata_Extractor SHALL extract ID3v1 and ID3v2 tags including title, artist, album, year, genre, comment, lyrics, BPM, composer, conductor, copyright, and URL
2. WHEN THE user selects an MP3 file with album art, THE Metadata_Extractor SHALL extract embedded album art dimensions and format
3. WHEN THE user selects a FLAC file, THE Metadata_Extractor SHALL extract Vorbis_Comments, STREAMINFO block, and PICTURE block metadata
4. WHEN THE user selects an OGG or Opus file, THE Metadata_Extractor SHALL extract Vorbis_Comments including all standard and custom tags
5. WHEN THE user selects a WAV file, THE Metadata_Extractor SHALL extract RIFF INFO chunk, BEXT chunk (broadcast wave), and iXML metadata
6. WHEN THE user selects an M4A or AAC file, THE Metadata_Extractor SHALL extract iTunes-style metadata atoms
7. WHEN THE user selects an AIFF file, THE Metadata_Extractor SHALL extract embedded ID3 tags and ANNO chunk metadata
8. WHEN THE Metadata_Extractor completes extraction for an audio file, THE Metadata_Extractor SHALL complete processing within 1 second
9. IF THE Metadata_Extractor encounters a corrupted audio file, THEN THE Metadata_Extractor SHALL return file system metadata only with an error indicator
10. FOR ALL audio files, THE Metadata_Extractor SHALL identify Privacy_Sensitive_Fields including author, composer, and copyright holder information

### Requirement 6: Document Metadata Extraction

**User Story:** As a user, I want to view metadata from document files, so that I can see authorship and revision history.

#### Acceptance Criteria

1. WHEN THE user selects a PDF file, THE Metadata_Extractor SHALL extract XMP metadata and DocInfo dictionary including Author, Title, Subject, Creator, Producer, CreationDate, ModDate, and Keywords
2. WHEN THE user selects a DOCX file, THE Metadata_Extractor SHALL extract core properties including author, lastModifiedBy, created, modified, company, title, subject, description, keywords, and revision number
3. WHEN THE user selects a DOCX file, THE Metadata_Extractor SHALL extract application properties including Application name and AppVersion
4. WHEN THE user selects an XLSX or PPTX file, THE Metadata_Extractor SHALL extract the same core and application properties as DOCX files
5. WHEN THE user selects an ODT, ODS, or ODP file, THE Metadata_Extractor SHALL extract ODF meta.xml including creator, date, generator, editing-cycles, editing-duration, and document-statistics
6. WHEN THE user selects a ZIP or APK file, THE Metadata_Extractor SHALL extract central directory comments and file entry metadata including dates, compression method, and CRC checksums
7. WHEN THE user selects an EPUB file, THE Metadata_Extractor SHALL extract OPF metadata including title, creator, publisher, date, rights, language, and subject
8. WHEN THE Metadata_Extractor completes extraction for a document file, THE Metadata_Extractor SHALL complete processing within 2 seconds
9. IF THE Metadata_Extractor encounters an encrypted PDF without password, THEN THE Metadata_Extractor SHALL return an error indicating password requirement
10. FOR ALL document files, THE Metadata_Extractor SHALL identify Privacy_Sensitive_Fields including author, company, lastModifiedBy, and revision history


### Requirement 7: File System Metadata Extraction

**User Story:** As a user, I want to view file system metadata for all files, so that I can see basic file properties regardless of format.

#### Acceptance Criteria

1. FOR ALL file types, THE Metadata_Extractor SHALL extract file name, extension, and MIME type
2. FOR ALL file types, THE Metadata_Extractor SHALL extract file size in bytes
3. FOR ALL file types, THE Metadata_Extractor SHALL extract absolute file path
4. FOR ALL file types, THE Metadata_Extractor SHALL extract creation date and time with timezone information
5. FOR ALL file types, THE Metadata_Extractor SHALL extract last modified date and time with timezone information
6. FOR ALL file types, THE Metadata_Extractor SHALL extract last accessed date and time with timezone information
7. FOR ALL file types, THE Metadata_Extractor SHALL extract file permissions (read, write, execute) where supported by the operating system
8. WHEN THE user requests hash computation, THE Metadata_Extractor SHALL compute MD5 and SHA-256 File_Hash values
9. WHEN THE Metadata_Extractor computes File_Hash for files larger than 10MB, THE Metadata_Extractor SHALL execute computation in an Isolate to prevent UI blocking
10. FOR ALL files, THE Metadata_Extractor SHALL format file size using appropriate units (bytes, KB, MB, GB) with two decimal places

### Requirement 8: Metadata Display and Organization

**User Story:** As a user, I want to view extracted metadata in an organized format, so that I can easily understand file information.

#### Acceptance Criteria

1. WHEN THE Metadata_Viewer displays metadata, THE Metadata_Viewer SHALL organize fields into ten accordion sections: File System Info, Basic Info, Camera/Device Info, GPS & Location, Date & Time, Technical, Embedded Metadata, Document Properties, Hashes, and Raw Metadata
2. WHEN THE Metadata_Viewer displays metadata, THE Metadata_Viewer SHALL keep the File System Info section expanded by default
3. WHEN THE user taps an accordion section header, THE Metadata_Viewer SHALL toggle the section between expanded and collapsed states with a 200 millisecond animation
4. WHEN THE Metadata_Viewer displays a metadata field, THE Metadata_Viewer SHALL show the field key in 12sp font and field value in 13sp font
5. WHEN THE Metadata_Viewer displays a Privacy_Sensitive_Field, THE Metadata_Viewer SHALL show a warning icon adjacent to the field
6. WHEN THE user taps a metadata field value, THE Metadata_Viewer SHALL copy the value to system clipboard and display a confirmation message
7. WHEN THE user long-presses a metadata field, THE Metadata_Viewer SHALL display a context menu with options to copy key, copy value, or copy both
8. WHEN THE Metadata_Viewer displays GPS coordinates, THE Metadata_Viewer SHALL render a static map preview using map tile services
9. WHEN THE Metadata_Viewer displays the Raw Metadata section, THE Metadata_Viewer SHALL show all extracted fields in a flat key-value table format
10. FOR ALL metadata sections, THE Metadata_Viewer SHALL display an item count badge in the section header


### Requirement 9: File Marking and Selection

**User Story:** As a user, I want to mark files and specific metadata fields for removal, so that I can selectively process files.

#### Acceptance Criteria

1. WHEN THE user taps the mark button on a file, THE Metadata_Viewer SHALL toggle the file's marked status
2. WHEN THE user marks a file for full removal, THE Metadata_Viewer SHALL display a marked badge on the file list item
3. WHEN THE user marks a file for full removal, THE Metadata_Viewer SHALL add a 3dp accent-colored left border to the file card
4. WHEN THE user marks individual metadata fields, THE Metadata_Viewer SHALL track selective removal status separately from full file marking
5. WHEN THE user marks individual metadata fields, THE Metadata_Viewer SHALL display the count of marked fields in the file status
6. WHEN THE user taps select all, THE Metadata_Viewer SHALL mark all files in the current list
7. WHEN THE user marks files, THE Metadata_Viewer SHALL persist marking state during the current session
8. WHEN THE user navigates away from Metadata_Viewer, THE Metadata_Viewer SHALL clear all marking state
9. FOR ALL marked files, THE Metadata_Viewer SHALL enable the send to remover action
10. FOR ALL marking operations, THE Metadata_Viewer SHALL provide visual feedback within 150 milliseconds

### Requirement 10: Metadata Removal Mode Selection

**User Story:** As a user, I want to choose different removal strategies, so that I can control what metadata is removed.

#### Acceptance Criteria

1. THE Metadata_Remover SHALL support four Removal_Mode options: Full Strip, Selective Strip, Anonymize, and Preserve Technical
2. WHEN THE user selects Full Strip mode, THE Metadata_Remover SHALL remove all detected metadata from the file
3. WHEN THE user selects Selective Strip mode, THE Metadata_Remover SHALL present a checklist of metadata categories
4. WHEN THE user selects Selective Strip mode, THE Metadata_Remover SHALL remove only the selected metadata categories
5. WHEN THE user selects Anonymize mode, THE Metadata_Remover SHALL remove GPS coordinates, author information, and device identification metadata
6. WHEN THE user selects Anonymize mode, THE Metadata_Remover SHALL preserve technical metadata including dimensions, codec, color space, and bitrate
7. WHEN THE user selects Preserve Technical mode, THE Metadata_Remover SHALL remove all user-generated metadata while preserving technical specifications
8. WHEN THE user configures a Removal_Mode, THE Metadata_Remover SHALL apply the mode to all files in the current Processing_Job
9. WHERE THE user requires per-file mode configuration, THE Metadata_Remover SHALL allow individual Removal_Mode selection for each file
10. FOR ALL Removal_Mode selections, THE Metadata_Remover SHALL display a preview of fields that will be removed and fields that will be preserved


### Requirement 11: Image Metadata Removal

**User Story:** As a user, I want to remove metadata from image files, so that I can share photos without embedded information.

#### Acceptance Criteria

1. WHEN THE Metadata_Stripper processes a JPEG file in Full Strip mode, THE Metadata_Stripper SHALL remove all APP0, APP1, APP12, APP13, APP14, and COM markers while preserving image data
2. WHEN THE Metadata_Stripper processes a JPEG file, THE Metadata_Stripper SHALL preserve image quality by avoiding re-encoding when possible
3. WHEN THE Metadata_Stripper processes a PNG file, THE Metadata_Stripper SHALL remove all tEXt, zTXt, and iTXt chunks while preserving IHDR, IDAT, and IEND chunks
4. WHEN THE Metadata_Stripper processes a WebP file, THE Metadata_Stripper SHALL remove EXIF and XMP chunks while preserving image data
5. WHEN THE Metadata_Stripper processes a TIFF file, THE Metadata_Stripper SHALL remove EXIF, IPTC, and XMP IFD entries while preserving image data
6. WHEN THE Metadata_Stripper processes a HEIC file, THE Metadata_Stripper SHALL remove metadata boxes while preserving image data and color profile
7. WHEN THE Metadata_Stripper processes an image file with Selective Strip mode, THE Metadata_Stripper SHALL remove only the specified metadata categories
8. WHEN THE Metadata_Stripper completes processing a 10MB JPEG file, THE Metadata_Stripper SHALL complete within 3 seconds
9. IF THE Metadata_Stripper encounters a corrupted image file, THEN THE Metadata_Stripper SHALL return an error and skip the file
10. FOR ALL processed image files, THE Metadata_Stripper SHALL verify output file integrity before marking as complete

### Requirement 12: Video Metadata Removal

**User Story:** As a user, I want to remove metadata from video files, so that I can share videos without embedded location or device information.

#### Acceptance Criteria

1. WHEN THE Metadata_Stripper processes a video file in Full Strip mode, THE Metadata_Stripper SHALL use FFmpeg to remove all metadata streams
2. WHEN THE Metadata_Stripper processes an MP4 or MOV file, THE Metadata_Stripper SHALL execute FFmpeg with `-map_metadata -1` flag to strip global metadata
3. WHEN THE Metadata_Stripper processes a video file, THE Metadata_Stripper SHALL use stream copy mode (`-c copy`) to avoid re-encoding
4. WHEN THE Metadata_Stripper processes a video file in Anonymize mode, THE Metadata_Stripper SHALL remove location, author, and device metadata while preserving codec information
5. WHEN THE Metadata_Stripper processes an MKV file, THE Metadata_Stripper SHALL remove Matroska tags while preserving chapters if in Preserve Technical mode
6. WHEN THE Metadata_Stripper processes a video file, THE Metadata_Stripper SHALL add faststart flag for MP4 files to optimize for streaming
7. WHEN THE Metadata_Stripper processes a 100MB video file, THE Metadata_Stripper SHALL complete within 15 seconds
8. IF THE Metadata_Stripper encounters an unsupported video codec, THEN THE Metadata_Stripper SHALL return an error indicating the limitation
9. WHEN THE Metadata_Stripper processes video files, THE Metadata_Stripper SHALL execute FFmpeg operations in an Isolate to prevent UI blocking
10. FOR ALL processed video files, THE Metadata_Stripper SHALL verify output file playability before marking as complete


### Requirement 13: Audio Metadata Removal

**User Story:** As a user, I want to remove metadata from audio files, so that I can share recordings without embedded tags.

#### Acceptance Criteria

1. WHEN THE Metadata_Stripper processes an MP3 file, THE Metadata_Stripper SHALL remove ID3v1 and ID3v2 tags while preserving audio frames
2. WHEN THE Metadata_Stripper processes a FLAC file, THE Metadata_Stripper SHALL remove Vorbis_Comments and PICTURE blocks while preserving STREAMINFO and audio data
3. WHEN THE Metadata_Stripper processes an OGG or Opus file, THE Metadata_Stripper SHALL remove Vorbis_Comments while preserving audio packets
4. WHEN THE Metadata_Stripper processes a WAV file, THE Metadata_Stripper SHALL remove INFO and BEXT chunks while preserving fmt and data chunks
5. WHEN THE Metadata_Stripper processes an M4A file, THE Metadata_Stripper SHALL use FFmpeg to remove iTunes metadata atoms
6. WHEN THE Metadata_Stripper processes an audio file in Selective Strip mode, THE Metadata_Stripper SHALL remove only specified tag categories
7. WHEN THE Metadata_Stripper processes an audio file with album art in Anonymize mode, THE Metadata_Stripper SHALL remove the album art
8. WHEN THE Metadata_Stripper processes an audio file in Preserve Technical mode, THE Metadata_Stripper SHALL retain codec, bitrate, and sample rate information
9. IF THE Metadata_Stripper encounters a corrupted audio file, THEN THE Metadata_Stripper SHALL return an error and skip the file
10. FOR ALL processed audio files, THE Metadata_Stripper SHALL verify audio playability before marking as complete

### Requirement 14: Document Metadata Removal

**User Story:** As a user, I want to remove metadata from document files, so that I can share documents without authorship information.

#### Acceptance Criteria

1. WHEN THE Metadata_Stripper processes a PDF file, THE Metadata_Stripper SHALL clear DocInfo dictionary entries and remove XMP metadata streams
2. WHEN THE Metadata_Stripper processes a DOCX file, THE Metadata_Stripper SHALL remove core.xml and app.xml property entries
3. WHEN THE Metadata_Stripper processes a DOCX file, THE Metadata_Stripper SHALL repack the ZIP archive with cleared metadata files
4. WHEN THE Metadata_Stripper processes an XLSX or PPTX file, THE Metadata_Stripper SHALL apply the same metadata clearing as DOCX files
5. WHEN THE Metadata_Stripper processes an ODT, ODS, or ODP file, THE Metadata_Stripper SHALL clear meta.xml entries
6. WHEN THE Metadata_Stripper processes a document in Selective Strip mode, THE Metadata_Stripper SHALL remove only specified property categories
7. WHEN THE Metadata_Stripper processes a document in Preserve Technical mode, THE Metadata_Stripper SHALL retain page count, word count, and document statistics
8. IF THE Metadata_Stripper encounters an encrypted PDF, THEN THE Metadata_Stripper SHALL return an error indicating password requirement
9. WHEN THE Metadata_Stripper processes a document file, THE Metadata_Stripper SHALL verify document integrity after metadata removal
10. FOR ALL processed document files, THE Metadata_Stripper SHALL ensure the output file opens correctly in standard applications


### Requirement 15: Output File Management

**User Story:** As a user, I want processed files saved to a configured location with clear naming, so that I can easily find cleaned files.

#### Acceptance Criteria

1. WHEN THE Metadata_Stripper completes processing a file, THE Metadata_Stripper SHALL save the output file to the configured Output_Folder
2. WHEN THE Metadata_Stripper saves an output file, THE Metadata_Stripper SHALL use the naming template configured in Settings_Manager
3. WHEN THE Metadata_Stripper saves an output file with default naming, THE Metadata_Stripper SHALL append "_clean" to the original filename before the extension
4. WHEN THE Metadata_Stripper encounters an existing file with the same output name, THE Metadata_Stripper SHALL append an incrementing number suffix
5. WHEN THE Metadata_Stripper saves a JPEG output file, THE Metadata_Stripper SHALL use the quality setting configured in Settings_Manager (60-100%)
6. WHEN THE user configures folder structure as "organized by date", THE Metadata_Stripper SHALL create subdirectories in YYYY-MM-DD format
7. WHEN THE user configures folder structure as "organized by type", THE Metadata_Stripper SHALL create subdirectories for images, videos, audio, and documents
8. WHEN THE user enables "keep original" setting, THE Metadata_Stripper SHALL preserve the original file after creating the output
9. WHEN THE user disables "keep original" setting, THE Metadata_Stripper SHALL delete the original file only after verifying output file integrity
10. FOR ALL output files, THE Metadata_Stripper SHALL verify write permissions to Output_Folder before starting processing

### Requirement 16: Batch Processing and Progress Tracking

**User Story:** As a user, I want to process multiple files with real-time progress updates, so that I can monitor long-running operations.

#### Acceptance Criteria

1. WHEN THE Metadata_Remover processes multiple files, THE Metadata_Remover SHALL execute processing in an Isolate to prevent UI blocking
2. WHEN THE Metadata_Remover processes a batch, THE Metadata_Remover SHALL display overall progress as a percentage
3. WHEN THE Metadata_Remover processes a batch, THE Metadata_Remover SHALL display current file name and per-file progress
4. WHEN THE Metadata_Remover processes a batch, THE Metadata_Remover SHALL update progress indicators at least every 100 milliseconds
5. WHEN THE Metadata_Remover processes a batch, THE Metadata_Remover SHALL display estimated time remaining based on average processing speed
6. WHEN THE Metadata_Remover processes a batch, THE Metadata_Remover SHALL maintain a real-time log of completed operations
7. WHEN THE user cancels a batch operation, THE Metadata_Remover SHALL stop processing after the current file completes
8. WHEN THE Metadata_Remover processes 10 image files, THE Metadata_Remover SHALL complete within 10 seconds
9. WHEN THE MetaStrip_App moves to background during processing, THE Metadata_Remover SHALL continue processing and display a system notification
10. FOR ALL batch operations, THE Metadata_Remover SHALL respect the maximum concurrent files setting from Settings_Manager


### Requirement 17: Processing Results and Error Handling

**User Story:** As a user, I want to see detailed results after processing, so that I can verify successful metadata removal and identify failures.

#### Acceptance Criteria

1. WHEN THE Metadata_Remover completes a batch, THE Metadata_Remover SHALL display a results screen with success and failure counts
2. WHEN THE Metadata_Remover completes a batch, THE Metadata_Remover SHALL display the total number of metadata fields removed
3. WHEN THE Metadata_Remover completes a batch, THE Metadata_Remover SHALL display the total size of metadata removed in kilobytes
4. WHEN THE Metadata_Remover encounters a file processing failure, THE Metadata_Remover SHALL continue processing remaining files
5. WHEN THE Metadata_Remover encounters a file processing failure, THE Metadata_Remover SHALL record the filename and error reason
6. WHEN THE Metadata_Remover displays results, THE Metadata_Remover SHALL provide an expandable list of failed files with error messages
7. WHEN THE Metadata_Remover displays results, THE Metadata_Remover SHALL provide an action to open the Output_Folder in the system file manager
8. WHEN THE Metadata_Remover displays results, THE Metadata_Remover SHALL provide an action to share processed files via system share sheet
9. IF THE Metadata_Remover encounters insufficient storage space, THEN THE Metadata_Remover SHALL pause processing and display available storage information
10. FOR ALL processing errors, THE Metadata_Remover SHALL log error details for debugging purposes

### Requirement 18: Theme and Appearance Customization

**User Story:** As a user, I want to customize the application appearance, so that I can personalize the interface to my preferences.

#### Acceptance Criteria

1. THE Settings_Manager SHALL provide eight predefined Theme_Preset options: Dark Industrial, Steel Blue, Acid Green, Rust, Mercury, Neon Orange, Cobalt, and Custom
2. WHEN THE user selects a Theme_Preset, THE Settings_Manager SHALL apply the theme immediately without requiring application restart
3. WHEN THE user selects the Custom theme option, THE Settings_Manager SHALL display color pickers for background, accent, and text colors
4. WHEN THE user modifies custom theme colors, THE Settings_Manager SHALL update the live preview in real-time
5. WHEN THE user applies a theme, THE Settings_Manager SHALL persist the theme selection to local storage
6. WHEN THE MetaStrip_App launches, THE Settings_Manager SHALL load and apply the saved theme within 100 milliseconds
7. FOR ALL Theme_Preset options, THE Settings_Manager SHALL ensure text contrast meets WCAG AA standards (minimum 4.5:1 ratio)
8. FOR ALL theme colors, THE Settings_Manager SHALL support HSL color picker with hue, saturation, and lightness controls
9. WHEN THE user resets theme settings, THE Settings_Manager SHALL restore the Dark Industrial default theme
10. FOR ALL theme changes, THE Settings_Manager SHALL animate color transitions over 200 milliseconds


### Requirement 19: Application Settings Management

**User Story:** As a user, I want to configure application behavior, so that I can optimize the app for my workflow.

#### Acceptance Criteria

1. THE Settings_Manager SHALL allow configuration of Output_Folder path via system directory picker
2. THE Settings_Manager SHALL allow configuration of folder structure with options: flat, organized by date, or organized by type
3. THE Settings_Manager SHALL allow configuration of output file naming template with variables: {name}, {date}, {time}, {ext}
4. THE Settings_Manager SHALL allow configuration of JPEG output quality from 60% to 100% via slider control
5. THE Settings_Manager SHALL allow configuration of maximum concurrent files with options: 1, 2, 4, or 8
6. THE Settings_Manager SHALL allow configuration of maximum files per session with options: 10, 25, 50, 100, or unlimited
7. THE Settings_Manager SHALL allow toggle of automatic hash computation for performance optimization
8. THE Settings_Manager SHALL allow toggle of keep original files after processing
9. THE Settings_Manager SHALL allow toggle of auto-confirm processing to skip confirmation dialogs
10. FOR ALL settings changes, THE Settings_Manager SHALL persist values to local storage immediately

### Requirement 20: Cache and Data Management

**User Story:** As a user, I want to manage application data and cache, so that I can free storage space and reset the application.

#### Acceptance Criteria

1. WHEN THE user requests cache clearing, THE Settings_Manager SHALL display current cache size in megabytes
2. WHEN THE user confirms cache clearing, THE Settings_Manager SHALL delete all thumbnail cache files
3. WHEN THE user confirms cache clearing, THE Settings_Manager SHALL delete all temporary processing files
4. WHEN THE Settings_Manager completes cache clearing, THE Settings_Manager SHALL display a confirmation message with freed space amount
5. WHEN THE user requests app data reset, THE Settings_Manager SHALL display a two-step confirmation dialog
6. WHEN THE user confirms app data reset, THE Settings_Manager SHALL clear all settings to default values
7. WHEN THE user confirms app data reset, THE Settings_Manager SHALL clear onboarding completion status
8. WHEN THE user confirms app data reset, THE Settings_Manager SHALL clear processing history from local database
9. WHEN THE Settings_Manager completes app data reset, THE Settings_Manager SHALL restart the application to onboarding screen
10. FOR ALL data management operations, THE Settings_Manager SHALL prevent accidental data loss through confirmation dialogs


### Requirement 21: Settings Import and Export

**User Story:** As a user, I want to export and import my settings, so that I can backup my configuration or transfer it to another device.

#### Acceptance Criteria

1. WHEN THE user requests settings export, THE Settings_Manager SHALL serialize all configuration values to JSON format
2. WHEN THE user requests settings export, THE Settings_Manager SHALL include theme configuration, folder paths, processing options, and naming templates
3. WHEN THE user requests settings export, THE Settings_Manager SHALL prompt for save location via system file picker
4. WHEN THE Settings_Manager saves exported settings, THE Settings_Manager SHALL use filename format "metastrip_settings_YYYYMMDD.json"
5. WHEN THE user requests settings import, THE Settings_Manager SHALL prompt for file selection via system file picker
6. WHEN THE user selects a settings file, THE Settings_Manager SHALL validate JSON structure before applying
7. IF THE Settings_Manager encounters invalid settings file format, THEN THE Settings_Manager SHALL display an error message and abort import
8. WHEN THE Settings_Manager successfully imports settings, THE Settings_Manager SHALL apply all configuration values immediately
9. WHEN THE Settings_Manager successfully imports settings, THE Settings_Manager SHALL display a confirmation message
10. FOR ALL import operations, THE Settings_Manager SHALL create a backup of current settings before applying imported values

### Requirement 22: Performance and Resource Management

**User Story:** As a user, I want the application to perform efficiently, so that I can process files without device slowdown.

#### Acceptance Criteria

1. WHEN THE MetaStrip_App performs cold start, THE MetaStrip_App SHALL complete initialization within 2 seconds
2. WHEN THE MetaStrip_App performs warm start, THE MetaStrip_App SHALL complete initialization within 500 milliseconds
3. WHILE THE MetaStrip_App is idle, THE MetaStrip_App SHALL consume less than 80 megabytes of RAM
4. WHILE THE MetaStrip_App processes a batch of 50 files, THE MetaStrip_App SHALL consume less than 300 megabytes of RAM
5. WHEN THE MetaStrip_App executes heavy processing operations, THE MetaStrip_App SHALL use Isolate-based concurrency to maintain UI responsiveness
6. WHEN THE MetaStrip_App generates thumbnails, THE MetaStrip_App SHALL cache thumbnails to disk for reuse
7. WHEN THE MetaStrip_App cache exceeds 100 megabytes, THE MetaStrip_App SHALL automatically remove least recently used cache entries
8. WHEN THE MetaStrip_App detects low memory conditions, THE MetaStrip_App SHALL reduce concurrent processing to 1 file at a time
9. FOR ALL UI animations, THE MetaStrip_App SHALL maintain 60 frames per second on devices meeting minimum requirements
10. FOR ALL file operations, THE MetaStrip_App SHALL release file handles immediately after completion to prevent resource leaks


### Requirement 23: Privacy and Offline Operation

**User Story:** As a user, I want all processing to occur offline, so that my files and metadata remain private.

#### Acceptance Criteria

1. THE MetaStrip_App SHALL perform all metadata extraction operations on-device without network communication
2. THE MetaStrip_App SHALL perform all metadata removal operations on-device without network communication
3. THE MetaStrip_App SHALL NOT transmit file contents, metadata, or user data to any remote server
4. THE MetaStrip_App SHALL NOT include analytics or tracking libraries
5. THE MetaStrip_App SHALL NOT include advertising SDKs or third-party monetization code
6. THE MetaStrip_App SHALL store all user preferences and settings in local device storage only
7. THE MetaStrip_App SHALL NOT require internet connectivity for any core functionality
8. WHERE THE MetaStrip_App displays map previews for GPS coordinates, THE MetaStrip_App SHALL use cached map tiles or static map generation
9. THE MetaStrip_App SHALL NOT modify or access original files outside of user-initiated processing operations
10. FOR ALL file operations, THE MetaStrip_App SHALL request only the minimum required permissions for the target platform

### Requirement 24: Platform Permissions and Compatibility

**User Story:** As a user, I want the application to request appropriate permissions, so that I understand what access is required.

#### Acceptance Criteria

1. WHEN THE MetaStrip_App runs on Android, THE MetaStrip_App SHALL use system file picker / SAF for Viewer file selection without broad storage/media permissions
2. WHEN THE MetaStrip_App runs on iOS, THE MetaStrip_App SHALL use the system document picker for explicit user-selected file access
3. WHEN a future feature requires broader access, THE MetaStrip_App SHALL request it just-in-time with explicit user-facing justification
4. THE MetaStrip_App SHALL NOT request MANAGE_EXTERNAL_STORAGE unless a separately approved feature requires all-files access
5. WHEN THE MetaStrip_App explains access, THE MetaStrip_App SHALL state that Viewer MVP uses picker-scoped access
6. IF a required future permission is denied, THEN THE MetaStrip_App SHALL display a dialog explaining the impact and providing a link to system settings
8. WHEN THE MetaStrip_App runs on Android, THE MetaStrip_App SHALL support API level 24 (Android 7.0) and higher
9. WHEN THE MetaStrip_App runs on iOS, THE MetaStrip_App SHALL support iOS 13.0 and higher
10. FOR ALL platform-specific features, THE MetaStrip_App SHALL gracefully degrade functionality when features are unavailable


### Requirement 25: Accessibility and Usability

**User Story:** As a user with accessibility needs, I want the application to support assistive technologies, so that I can use all features effectively.

#### Acceptance Criteria

1. FOR ALL interactive elements, THE MetaStrip_App SHALL provide semantic labels for screen readers
2. FOR ALL interactive elements, THE MetaStrip_App SHALL maintain minimum touch target size of 48x48 density-independent pixels
3. FOR ALL text elements, THE MetaStrip_App SHALL respect system font size settings and scale appropriately
4. FOR ALL color-coded information, THE MetaStrip_App SHALL provide additional non-color indicators such as icons or labels
5. FOR ALL text and background combinations, THE MetaStrip_App SHALL maintain minimum contrast ratio of 4.5:1 for normal text
6. FOR ALL text and background combinations, THE MetaStrip_App SHALL maintain minimum contrast ratio of 3:1 for large text (18sp+)
7. WHEN THE user navigates via keyboard or switch control, THE MetaStrip_App SHALL provide visible focus indicators
8. WHEN THE user enables screen reader, THE MetaStrip_App SHALL announce state changes and processing progress
9. FOR ALL form inputs, THE MetaStrip_App SHALL provide clear labels and error messages
10. FOR ALL time-based operations, THE MetaStrip_App SHALL provide sufficient time for users to read and interact with content

### Requirement 26: Error Recovery and Data Integrity

**User Story:** As a user, I want the application to handle errors gracefully, so that I don't lose data or experience crashes.

#### Acceptance Criteria

1. IF THE Metadata_Extractor encounters a corrupted file, THEN THE Metadata_Extractor SHALL log the error and continue processing remaining files
2. IF THE Metadata_Stripper encounters insufficient storage space, THEN THE Metadata_Stripper SHALL pause processing and notify the user
3. IF THE Metadata_Stripper fails to write an output file, THEN THE Metadata_Stripper SHALL preserve the original file and log the error
4. IF THE MetaStrip_App crashes during processing, THEN THE MetaStrip_App SHALL preserve original files and allow retry on restart
5. WHEN THE MetaStrip_App encounters a file in use by another application, THE MetaStrip_App SHALL retry up to 3 times with 1 second delay
6. WHEN THE MetaStrip_App encounters a file in use after retries, THE MetaStrip_App SHALL skip the file and log the error
7. IF THE user rotates the device during processing, THEN THE MetaStrip_App SHALL maintain processing state and progress
8. IF THE user navigates away during processing, THEN THE MetaStrip_App SHALL continue processing in background and show notification
9. FOR ALL file write operations, THE MetaStrip_App SHALL verify write success before deleting original files (when keep original is disabled)
10. FOR ALL critical errors, THE MetaStrip_App SHALL log error details to local storage for debugging purposes


### Requirement 27: Metadata Parser Implementation

**User Story:** As a developer, I want robust metadata parsers for each format, so that extraction is reliable and accurate.

#### Acceptance Criteria

1. THE Metadata_Extractor SHALL implement a JPEG EXIF parser that reads APP1 marker segments according to EXIF 2.3 specification
2. THE Metadata_Extractor SHALL implement a PNG chunk parser that reads tEXt, zTXt, and iTXt chunks according to PNG specification
3. THE Metadata_Extractor SHALL implement an ID3 parser that reads ID3v2.3 and ID3v2.4 tags according to ID3 specification
4. THE Metadata_Extractor SHALL implement a FLAC metadata block parser that reads Vorbis_Comments and PICTURE blocks according to FLAC specification
5. THE Metadata_Extractor SHALL implement a RIFF chunk parser for WAV and AVI files according to RIFF specification
6. THE Metadata_Extractor SHALL implement an Open XML parser that extracts properties from DOCX, XLSX, and PPTX core.xml and app.xml files
7. THE Metadata_Extractor SHALL implement an ODF parser that extracts properties from ODT, ODS, and ODP meta.xml files
8. THE Metadata_Extractor SHALL implement a PDF metadata parser that reads DocInfo dictionary and XMP streams according to PDF specification
9. FOR ALL binary format parsers, THE Metadata_Extractor SHALL handle both big-endian and little-endian byte order correctly
10. FOR ALL parsers, THE Metadata_Extractor SHALL validate data structure integrity before attempting to read metadata fields

### Requirement 28: Metadata Pretty Printer Implementation

**User Story:** As a developer, I want metadata pretty printers for serialization formats, so that I can verify round-trip correctness.

#### Acceptance Criteria

1. THE Metadata_Extractor SHALL implement a Vorbis_Comments pretty printer that formats comments according to Vorbis specification
2. THE Metadata_Extractor SHALL implement an ID3v2 pretty printer that formats tags according to ID3 specification
3. THE Metadata_Extractor SHALL implement an XMP pretty printer that formats metadata according to XMP specification
4. THE Metadata_Extractor SHALL implement an IPTC pretty printer that formats metadata according to IPTC specification
5. FOR ALL pretty printers, THE Metadata_Extractor SHALL produce output that can be parsed back to equivalent metadata structures
6. FOR ALL pretty printers, THE Metadata_Extractor SHALL preserve field order when order is semantically significant
7. FOR ALL pretty printers, THE Metadata_Extractor SHALL escape special characters according to format specification
8. FOR ALL pretty printers, THE Metadata_Extractor SHALL handle multi-byte character encodings correctly
9. FOR ALL pretty printers, THE Metadata_Extractor SHALL validate output against format specification before returning
10. FOR ALL metadata with parsers and pretty printers, THE Metadata_Extractor SHALL support round-trip property testing


### Requirement 29: Round-Trip Metadata Correctness

**User Story:** As a developer, I want to verify metadata parsing correctness, so that I can ensure data integrity.

#### Acceptance Criteria

1. FOR ALL Vorbis_Comments metadata, WHEN THE Metadata_Extractor parses then pretty-prints then parses again, THE Metadata_Extractor SHALL produce equivalent metadata structures
2. FOR ALL ID3v2 metadata, WHEN THE Metadata_Extractor parses then pretty-prints then parses again, THE Metadata_Extractor SHALL produce equivalent metadata structures
3. FOR ALL XMP metadata, WHEN THE Metadata_Extractor parses then pretty-prints then parses again, THE Metadata_Extractor SHALL produce equivalent metadata structures
4. FOR ALL IPTC metadata, WHEN THE Metadata_Extractor parses then pretty-prints then parses again, THE Metadata_Extractor SHALL produce equivalent metadata structures
5. FOR ALL Open XML properties, WHEN THE Metadata_Extractor parses then serializes then parses again, THE Metadata_Extractor SHALL produce equivalent property structures
6. FOR ALL ODF properties, WHEN THE Metadata_Extractor parses then serializes then parses again, THE Metadata_Extractor SHALL produce equivalent property structures
7. FOR ALL round-trip operations, THE Metadata_Extractor SHALL preserve field values exactly including whitespace and special characters
8. FOR ALL round-trip operations, THE Metadata_Extractor SHALL preserve field types (string, integer, date, binary)
9. FOR ALL round-trip operations, THE Metadata_Extractor SHALL preserve multi-value fields as separate values
10. FOR ALL round-trip operations, THE Metadata_Extractor SHALL handle empty values and null values correctly

### Requirement 30: Metadata Extraction Invariants

**User Story:** As a developer, I want to verify extraction invariants, so that I can ensure consistent behavior.

#### Acceptance Criteria

1. FOR ALL files, WHEN THE Metadata_Extractor extracts metadata, THE Metadata_Extractor SHALL return file system metadata regardless of format-specific extraction success
2. FOR ALL files with GPS coordinates, WHEN THE Metadata_Extractor extracts metadata, THE Metadata_Extractor SHALL mark GPS fields as Privacy_Sensitive_Fields
3. FOR ALL files with author information, WHEN THE Metadata_Extractor extracts metadata, THE Metadata_Extractor SHALL mark author fields as Privacy_Sensitive_Fields
4. FOR ALL files with device information, WHEN THE Metadata_Extractor extracts metadata, THE Metadata_Extractor SHALL mark device fields as Privacy_Sensitive_Fields
5. FOR ALL image files, WHEN THE Metadata_Extractor extracts dimensions, THE Metadata_Extractor SHALL ensure width and height are positive integers
6. FOR ALL audio files, WHEN THE Metadata_Extractor extracts duration, THE Metadata_Extractor SHALL ensure duration is a non-negative number
7. FOR ALL video files, WHEN THE Metadata_Extractor extracts bitrate, THE Metadata_Extractor SHALL ensure bitrate is a positive integer
8. FOR ALL files, WHEN THE Metadata_Extractor extracts timestamps, THE Metadata_Extractor SHALL normalize timestamps to ISO 8601 format
9. FOR ALL files, WHEN THE Metadata_Extractor computes File_Hash, THE Metadata_Extractor SHALL produce consistent hash values for identical file contents
10. FOR ALL files, WHEN THE Metadata_Extractor extracts metadata multiple times, THE Metadata_Extractor SHALL produce identical results for unchanged files


### Requirement 31: Metadata Removal Correctness

**User Story:** As a developer, I want to verify metadata removal correctness, so that I can ensure complete stripping.

#### Acceptance Criteria

1. FOR ALL processed files in Full Strip mode, WHEN THE Metadata_Extractor extracts metadata from output files, THE Metadata_Extractor SHALL find zero user-generated metadata fields
2. FOR ALL processed JPEG files in Full Strip mode, WHEN THE Metadata_Extractor extracts metadata from output files, THE Metadata_Extractor SHALL find no EXIF, IPTC, or XMP data
3. FOR ALL processed PNG files in Full Strip mode, WHEN THE Metadata_Extractor extracts metadata from output files, THE Metadata_Extractor SHALL find no tEXt, zTXt, or iTXt chunks
4. FOR ALL processed MP3 files in Full Strip mode, WHEN THE Metadata_Extractor extracts metadata from output files, THE Metadata_Extractor SHALL find no ID3v1 or ID3v2 tags
5. FOR ALL processed video files in Full Strip mode, WHEN THE Metadata_Extractor extracts metadata from output files, THE Metadata_Extractor SHALL find no container-level metadata
6. FOR ALL processed files in Anonymize mode, WHEN THE Metadata_Extractor extracts metadata from output files, THE Metadata_Extractor SHALL find no Privacy_Sensitive_Fields
7. FOR ALL processed files in Preserve Technical mode, WHEN THE Metadata_Extractor extracts metadata from output files, THE Metadata_Extractor SHALL find technical metadata fields preserved
8. FOR ALL processed image files, WHEN THE Metadata_Stripper removes metadata, THE Metadata_Stripper SHALL preserve image dimensions exactly
9. FOR ALL processed audio files, WHEN THE Metadata_Stripper removes metadata, THE Metadata_Stripper SHALL preserve audio duration within 1 millisecond
10. FOR ALL processed video files, WHEN THE Metadata_Stripper removes metadata, THE Metadata_Stripper SHALL preserve video playability and codec information

### Requirement 32: File Integrity After Processing

**User Story:** As a developer, I want to verify file integrity after processing, so that I can ensure files remain usable.

#### Acceptance Criteria

1. FOR ALL processed image files, WHEN THE Metadata_Stripper completes processing, THE output file SHALL be openable by standard image viewers
2. FOR ALL processed video files, WHEN THE Metadata_Stripper completes processing, THE output file SHALL be playable by standard video players
3. FOR ALL processed audio files, WHEN THE Metadata_Stripper completes processing, THE output file SHALL be playable by standard audio players
4. FOR ALL processed document files, WHEN THE Metadata_Stripper completes processing, THE output file SHALL be openable by standard document applications
5. FOR ALL processed JPEG files, WHEN THE Metadata_Stripper completes processing, THE output file SHALL maintain valid JPEG structure with SOI and EOI markers
6. FOR ALL processed PNG files, WHEN THE Metadata_Stripper completes processing, THE output file SHALL maintain valid PNG structure with required chunks
7. FOR ALL processed files, WHEN THE Metadata_Stripper completes processing, THE output file size SHALL be less than or equal to input file size
8. FOR ALL processed files, WHEN THE Metadata_Stripper completes processing, THE output file SHALL have a valid file extension matching the format
9. FOR ALL processed files, WHEN THE Metadata_Stripper completes processing, THE output file SHALL be readable with standard file I/O operations
10. FOR ALL processed files, WHEN THE Metadata_Stripper completes processing, THE Metadata_Extractor SHALL successfully extract file system metadata from output files


### Requirement 33: Selective Metadata Removal Correctness

**User Story:** As a developer, I want to verify selective removal correctness, so that I can ensure only specified metadata is removed.

#### Acceptance Criteria

1. FOR ALL processed files in Selective Strip mode with GPS category selected, WHEN THE Metadata_Extractor extracts metadata from output files, THE Metadata_Extractor SHALL find no GPS-related fields
2. FOR ALL processed files in Selective Strip mode with GPS category unselected, WHEN THE Metadata_Extractor extracts metadata from output files, THE Metadata_Extractor SHALL find GPS-related fields preserved
3. FOR ALL processed files in Selective Strip mode with Author category selected, WHEN THE Metadata_Extractor extracts metadata from output files, THE Metadata_Extractor SHALL find no author-related fields
4. FOR ALL processed files in Selective Strip mode with Camera category selected, WHEN THE Metadata_Extractor extracts metadata from output files, THE Metadata_Extractor SHALL find no camera make, model, or lens fields
5. FOR ALL processed files in Selective Strip mode with Timestamps category selected, WHEN THE Metadata_Extractor extracts metadata from output files, THE Metadata_Extractor SHALL find no creation or modification timestamps
6. FOR ALL processed files in Selective Strip mode, WHEN THE Metadata_Stripper removes metadata, THE Metadata_Stripper SHALL preserve all unselected categories
7. FOR ALL processed files in Selective Strip mode, WHEN THE user marks individual fields, THE Metadata_Stripper SHALL remove only the marked fields
8. FOR ALL processed files in Selective Strip mode, WHEN THE user marks individual fields, THE Metadata_Stripper SHALL preserve all unmarked fields within the same category
9. FOR ALL processed files in Selective Strip mode, THE Metadata_Stripper SHALL maintain field relationships (e.g., GPS latitude and longitude together)
10. FOR ALL processed files in Selective Strip mode, THE Metadata_Stripper SHALL validate that at least one metadata category or field is selected before processing

### Requirement 34: Batch Processing Invariants

**User Story:** As a developer, I want to verify batch processing invariants, so that I can ensure consistent behavior across multiple files.

#### Acceptance Criteria

1. FOR ALL batch processing operations, WHEN THE Metadata_Remover processes N files, THE Metadata_Remover SHALL produce exactly N output files or N error records
2. FOR ALL batch processing operations, WHEN THE Metadata_Remover processes files, THE Metadata_Remover SHALL maintain processing order matching input order
3. FOR ALL batch processing operations, WHEN THE Metadata_Remover encounters an error on file X, THE Metadata_Remover SHALL continue processing files X+1 through N
4. FOR ALL batch processing operations, WHEN THE Metadata_Remover completes, THE sum of successful files and failed files SHALL equal total input files
5. FOR ALL batch processing operations, WHEN THE Metadata_Remover processes files with identical content, THE Metadata_Remover SHALL produce output files with identical content
6. FOR ALL batch processing operations, WHEN THE Metadata_Remover processes files, THE Metadata_Remover SHALL apply the same Removal_Mode to all files unless per-file override is specified
7. FOR ALL batch processing operations, WHEN THE user cancels processing, THE Metadata_Remover SHALL complete the current file before stopping
8. FOR ALL batch processing operations, WHEN THE user cancels processing, THE Metadata_Remover SHALL preserve all successfully processed files
9. FOR ALL batch processing operations, WHEN THE Metadata_Remover processes files, THE total metadata removed SHALL equal the sum of metadata removed from each file
10. FOR ALL batch processing operations, WHEN THE Metadata_Remover processes files concurrently, THE Metadata_Remover SHALL produce identical results to sequential processing


### Requirement 35: Output File Naming Invariants

**User Story:** As a developer, I want to verify output naming correctness, so that I can ensure predictable file organization.

#### Acceptance Criteria

1. FOR ALL processed files, WHEN THE Metadata_Stripper generates output filename, THE output filename SHALL preserve the original base name
2. FOR ALL processed files, WHEN THE Metadata_Stripper generates output filename, THE output filename SHALL preserve the original file extension
3. FOR ALL processed files with naming template "{name}_clean", WHEN THE Metadata_Stripper generates output filename, THE output filename SHALL match pattern "originalname_clean.ext"
4. FOR ALL processed files, WHEN THE output filename already exists, THE Metadata_Stripper SHALL append incrementing numbers starting from 1
5. FOR ALL processed files, WHEN THE Metadata_Stripper generates output filename with date variable, THE output filename SHALL include date in YYYYMMDD format
6. FOR ALL processed files, WHEN THE Metadata_Stripper generates output filename with time variable, THE output filename SHALL include time in HHMMSS format
7. FOR ALL processed files, WHEN THE folder structure is "organized by date", THE Metadata_Stripper SHALL create subdirectories matching YYYY-MM-DD format
8. FOR ALL processed files, WHEN THE folder structure is "organized by type", THE Metadata_Stripper SHALL place files in subdirectories matching their format category
9. FOR ALL processed files, WHEN THE Metadata_Stripper generates output paths, THE output paths SHALL not exceed platform maximum path length
10. FOR ALL processed files, WHEN THE Metadata_Stripper generates output filenames, THE filenames SHALL not contain platform-restricted characters

### Requirement 36: Settings Persistence Invariants

**User Story:** As a developer, I want to verify settings persistence correctness, so that I can ensure configuration is maintained.

#### Acceptance Criteria

1. FOR ALL settings changes, WHEN THE Settings_Manager persists settings, THE Settings_Manager SHALL write to local storage within 100 milliseconds
2. FOR ALL settings, WHEN THE MetaStrip_App restarts, THE Settings_Manager SHALL load saved settings and apply them before displaying UI
3. FOR ALL theme changes, WHEN THE Settings_Manager persists theme, THE Settings_Manager SHALL save all color values in hexadecimal format
4. FOR ALL folder path settings, WHEN THE Settings_Manager persists paths, THE Settings_Manager SHALL save absolute paths
5. FOR ALL numeric settings, WHEN THE Settings_Manager persists values, THE Settings_Manager SHALL validate values are within allowed ranges
6. FOR ALL boolean settings, WHEN THE Settings_Manager persists values, THE Settings_Manager SHALL store as true or false
7. FOR ALL settings export operations, WHEN THE Settings_Manager exports settings, THE exported JSON SHALL be valid and parseable
8. FOR ALL settings import operations, WHEN THE Settings_Manager imports settings, THE Settings_Manager SHALL validate all required fields are present
9. FOR ALL settings, WHEN THE user resets to defaults, THE Settings_Manager SHALL restore exact default values specified in requirements
10. FOR ALL settings persistence operations, WHEN THE storage write fails, THE Settings_Manager SHALL maintain current in-memory settings and notify the user


### Requirement 37: Hash Computation Correctness

**User Story:** As a developer, I want to verify hash computation correctness, so that I can ensure file integrity verification.

#### Acceptance Criteria

1. FOR ALL files, WHEN THE Metadata_Extractor computes MD5 File_Hash, THE Metadata_Extractor SHALL produce a 32-character hexadecimal string
2. FOR ALL files, WHEN THE Metadata_Extractor computes SHA-256 File_Hash, THE Metadata_Extractor SHALL produce a 64-character hexadecimal string
3. FOR ALL files with identical content, WHEN THE Metadata_Extractor computes File_Hash, THE Metadata_Extractor SHALL produce identical hash values
4. FOR ALL files with different content, WHEN THE Metadata_Extractor computes File_Hash, THE Metadata_Extractor SHALL produce different hash values
5. FOR ALL files, WHEN THE Metadata_Extractor computes File_Hash twice, THE Metadata_Extractor SHALL produce identical results
6. FOR ALL files, WHEN THE Metadata_Extractor computes File_Hash, THE hash value SHALL match standard MD5 and SHA-256 implementations
7. FOR ALL files larger than 10MB, WHEN THE Metadata_Extractor computes File_Hash, THE computation SHALL execute in an Isolate
8. FOR ALL files, WHEN THE Metadata_Extractor computes File_Hash, THE Metadata_Extractor SHALL read the entire file contents
9. FOR ALL files, WHEN THE Metadata_Extractor computes File_Hash, THE Metadata_Extractor SHALL close file handles after computation
10. FOR ALL files, WHEN THE Metadata_Extractor computes File_Hash, THE computation SHALL complete within 5 seconds for files up to 100MB

### Requirement 38: UI State Management Invariants

**User Story:** As a developer, I want to verify UI state correctness, so that I can ensure consistent user experience.

#### Acceptance Criteria

1. FOR ALL screen transitions, WHEN THE user navigates between screens, THE MetaStrip_App SHALL preserve navigation history for back navigation
2. FOR ALL file list operations, WHEN THE user adds or removes files, THE Metadata_Viewer SHALL update the file count display immediately
3. FOR ALL marking operations, WHEN THE user marks or unmarks files, THE Metadata_Viewer SHALL update marked count display immediately
4. FOR ALL processing operations, WHEN THE Metadata_Remover updates progress, THE UI SHALL reflect progress within 100 milliseconds
5. FOR ALL theme changes, WHEN THE user applies a new theme, THE MetaStrip_App SHALL update all visible UI elements within 200 milliseconds
6. FOR ALL accordion sections, WHEN THE user expands or collapses a section, THE animation SHALL complete within 200 milliseconds
7. FOR ALL device rotations, WHEN THE user rotates the device, THE MetaStrip_App SHALL preserve current screen state and scroll position
8. FOR ALL background operations, WHEN THE MetaStrip_App moves to background, THE MetaStrip_App SHALL preserve processing state
9. FOR ALL foreground returns, WHEN THE MetaStrip_App returns to foreground, THE MetaStrip_App SHALL restore UI state exactly as it was
10. FOR ALL error states, WHEN THE MetaStrip_App encounters an error, THE MetaStrip_App SHALL display error message and maintain recoverable state


### Requirement 39: Thumbnail Generation and Caching

**User Story:** As a user, I want to see thumbnail previews for files, so that I can quickly identify files visually.

#### Acceptance Criteria

1. WHEN THE Metadata_Viewer displays an image file, THE Metadata_Viewer SHALL generate a thumbnail with maximum dimension of 200 pixels
2. WHEN THE Metadata_Viewer displays a video file, THE Metadata_Viewer SHALL extract a frame at 1 second position for thumbnail generation
3. WHEN THE Metadata_Viewer displays an audio or document file, THE Metadata_Viewer SHALL display a format-appropriate icon
4. WHEN THE Metadata_Viewer generates a thumbnail, THE Metadata_Viewer SHALL cache the thumbnail to disk storage
5. WHEN THE Metadata_Viewer displays a file with cached thumbnail, THE Metadata_Viewer SHALL load from cache instead of regenerating
6. WHEN THE thumbnail cache exceeds 100 megabytes, THE Metadata_Viewer SHALL remove least recently used thumbnails
7. WHEN THE user clears cache via Settings_Manager, THE Metadata_Viewer SHALL delete all cached thumbnails
8. WHEN THE Metadata_Viewer generates thumbnails, THE Metadata_Viewer SHALL execute generation in an Isolate to prevent UI blocking
9. FOR ALL thumbnail operations, THE Metadata_Viewer SHALL maintain aspect ratio of original image
10. FOR ALL thumbnail operations, THE Metadata_Viewer SHALL complete generation within 500 milliseconds per file

### Requirement 40: Notification and Background Processing

**User Story:** As a user, I want to receive notifications when background processing completes, so that I know when files are ready.

#### Acceptance Criteria

1. WHEN THE MetaStrip_App moves to background during processing, THE Metadata_Remover SHALL continue processing without interruption
2. WHEN THE Metadata_Remover completes batch processing in background, THE MetaStrip_App SHALL display a system notification
3. WHEN THE user taps the completion notification, THE MetaStrip_App SHALL open to the results screen
4. WHEN THE Metadata_Remover processes in background, THE system notification SHALL display current progress percentage
5. WHEN THE Metadata_Remover processes in background, THE system notification SHALL display current file name
6. WHEN THE Metadata_Remover encounters an error in background, THE MetaStrip_App SHALL display an error notification
7. WHEN THE user cancels processing via notification action, THE Metadata_Remover SHALL stop processing gracefully
8. FOR ALL background processing, THE MetaStrip_App SHALL maintain a foreground service on Android to prevent process termination
9. FOR ALL background processing, THE MetaStrip_App SHALL update notification progress at least every 2 seconds
10. FOR ALL background processing, THE MetaStrip_App SHALL release foreground service immediately after completion

