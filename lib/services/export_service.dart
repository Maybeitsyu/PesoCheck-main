import '../models/scan_result.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

class ExportService {
  // Helper to sanitize filenames/CSV fields (remove commas/newlines which break CSV)
  // General sanitizer: remove newlines, commas and common mojibake — DO NOT add Php prefix
  static String _sanitize(String input) {
    String result = input
        .replaceAll(RegExp(r'[\r\n]'), ' ')
        .replaceAll(',', '_')
        .replaceAll('â‚±', '')  // Remove mojibake
        .replaceAll('Â', '')    // Remove stray chars
        .replaceAll('â', '')    
        .replaceAll('‚', '')    
        .replaceAll('±', '')    
        .replaceAll('####', '') 
        .replaceAll('₱', '')    // Remove peso symbols
        .replaceAll('Php', '')  // Remove any existing Php
        .replaceAll('PHP', '')  // Remove any existing PHP
        .trim();

    // Remove a leading 'P' if it was used as a peso marker
    if (result.startsWith('P')) {
      result = result.substring(1);
    }

    return result;
  }

  // Sanitizer for denomination specifically: add 'Php' prefix only when appropriate
  static String _sanitizeDenomination(String input) {
    final cleaned = _sanitize(input);
    if (cleaned.isEmpty) return cleaned;

    // If the cleaned value starts with digits, prefix with Php
    if (RegExp(r'^\d+').hasMatch(cleaned)) {
      return 'Php$cleaned';
    }

    // If it already looks like a currency (e.g. starts with currency letters), ensure Php prefix
    if (cleaned.toLowerCase().startsWith('php')) {
      return cleaned.replaceFirst(RegExp(r'(?i)^php'), 'Php');
    }

    return cleaned;
  }
  // Escape a CSV field by doubling quotes and wrapping in quotes
  static String _csvEscape(String input) {
    final s = _sanitize(input);
    final escaped = s.replaceAll('"', '""');
    return '"$escaped"';
  }

  // CSV escape for denomination (uses denomination sanitizer)
  static String _csvEscapeDenom(String input) {
    final s = _sanitizeDenomination(input);
    final escaped = s.replaceAll('"', '""');
    return '"$escaped"';
  }
  static String exportToCSV(List<ScanResult> scans) {
    final StringBuffer csv = StringBuffer();
    
    // CSV Header (comma-separated, fields quoted)
    csv.writeln('"ID","Status","Confidence","Denomination","Date","Time","ImageName","ImagePath"');
    
    // CSV Data
    for (final scan in scans) {
      final status = scan.statusText;
      
      // Fix date format - use proper date formatting with Excel text qualifier
      final date = "'${scan.timestamp.year}-${scan.timestamp.month.toString().padLeft(2, '0')}-${scan.timestamp.day.toString().padLeft(2, '0')}'";
      
      // Fix time format - use proper time formatting with seconds and Excel text qualifier
      final time = "'${scan.timestamp.hour.toString().padLeft(2, '0')}:${scan.timestamp.minute.toString().padLeft(2, '0')}:${scan.timestamp.second.toString().padLeft(2, '0')}'";
      
      // Clean denomination - remove any unwanted characters and fix mojibake
      String cleanDenomination = scan.denomination;
      if (cleanDenomination.contains('a+')) {
        cleanDenomination = cleanDenomination.replaceAll('a+', '');
      }
      cleanDenomination = _sanitizeDenomination(cleanDenomination);
      
      // Use original image filename (from upload or capture) for CSV ImageName when available
      String imageName = '';
      String imagePath = '';
      if (scan.imagePath != null && scan.imagePath!.isNotEmpty) {
        final file = File(scan.imagePath!);
        if (file.existsSync()) {
          // original filename (preserves the user's filename from camera/gallery)
          final originalName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : file.path.split(Platform.pathSeparator).last;
          imageName = _sanitize(originalName);
          imagePath = scan.imagePath!;
        }
      }
      
      // Build CSV row with escaped/quoted fields
      final escapedFields = <String>[];
      escapedFields.add(_csvEscape(scan.id));
      escapedFields.add(_csvEscape(status));
      escapedFields.add(_csvEscape('${scan.confidence}%'));
      escapedFields.add(_csvEscapeDenom(cleanDenomination));
      escapedFields.add(_csvEscape(date));
      escapedFields.add(_csvEscape(time));
      escapedFields.add(_csvEscape(imageName));
      escapedFields.add(_csvEscape(imagePath));
      csv.writeln(escapedFields.join(','));
    }
    
    return csv.toString();
  }

  static String exportToJSON(List<ScanResult> scans) {
    final List<Map<String, dynamic>> jsonData = scans.map((scan) => scan.toJson()).toList();
    return json.encode(jsonData);
  }

  static Map<String, dynamic> generateReport(List<ScanResult> scans) {
    final totalScans = scans.length;
    final realScans = scans.where((scan) => scan.status == BillStatus.real).length;
    final counterfeitScans = scans.where((scan) => scan.status == BillStatus.counterfeit).length;
    final invalidScans = scans.where((scan) => scan.status == BillStatus.invalid).length;
    final avgConfidence = totalScans > 0 
        ? scans.map((scan) => scan.confidence).reduce((a, b) => a + b) / totalScans 
        : 0.0;

    return {
      'summary': {
        'totalScans': totalScans,
        'realBills': realScans,
        'counterfeitBills': counterfeitScans,
        'invalidBills': invalidScans,
        'realPercentage': totalScans > 0 ? (realScans / totalScans * 100) : 0,
        'counterfeitPercentage': totalScans > 0 ? (counterfeitScans / totalScans * 100) : 0,
        'invalidPercentage': totalScans > 0 ? (invalidScans / totalScans * 100) : 0,
        'averageConfidence': avgConfidence,
      },
      'scans': scans.map((scan) => scan.toJson()).toList(),
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  /// Export data with images to a folder structure
  static Future<String> exportWithImages(List<ScanResult> scans) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final exportDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final folderName = 'PesoCheck_Export_$timestamp';
    final exportPath = Directory('${exportDir.path}/$folderName');
    
    // Create export directory
    await exportPath.create(recursive: true);
    
    // Create data subdirectory
    final dataDir = Directory('${exportPath.path}/data');
    await dataDir.create();
    
    // Create images subdirectory
    final imagesDir = Directory('${exportPath.path}/images');
    await imagesDir.create();
    
    // Export CSV data
    final csvContent = exportToCSV(scans);
    final csvFile = File('${dataDir.path}/scan_history.csv');
  // Prepend UTF-8 BOM so Excel/Sheets detect UTF-8 (prevents mojibake for characters like ₱)
  await csvFile.writeAsString('\uFEFF$csvContent', encoding: utf8);
    
    // Export JSON data
    final jsonContent = exportToJSON(scans);
    final jsonFile = File('${dataDir.path}/scan_history.json');
    await jsonFile.writeAsString(jsonContent);
    
    // Export report
    final report = generateReport(scans);
    final reportFile = File('${dataDir.path}/scan_report.json');
    await reportFile.writeAsString(json.encode(report));
    
    // Copy images with descriptive names
    for (int i = 0; i < scans.length; i++) {
      final scan = scans[i];
      if (scan.imagePath != null && File(scan.imagePath!).existsSync()) {
        final originalFile = File(scan.imagePath!);
        final originalName = originalFile.uri.pathSegments.isNotEmpty ? originalFile.uri.pathSegments.last : originalFile.path.split(Platform.pathSeparator).last;
        final dotIndex = originalName.lastIndexOf('.');
        final nameOnly = dotIndex > 0 ? originalName.substring(0, dotIndex) : originalName;
        final extension = dotIndex > 0 ? originalName.substring(dotIndex + 1) : originalFile.path.split('.').last;

        // Use scan timestamp for date/time in filename
        final date = '${scan.timestamp.year}-${scan.timestamp.month.toString().padLeft(2, '0')}-${scan.timestamp.day.toString().padLeft(2, '0')}';
        final time = '${scan.timestamp.hour.toString().padLeft(2, '0')}-${scan.timestamp.minute.toString().padLeft(2, '0')}-${scan.timestamp.second.toString().padLeft(2, '0')}';

        final sanitizedBase = _sanitize(nameOnly);
        final sanitizedDenom = _sanitize(scan.denomination);
        final imageName = '${sanitizedBase}_${date}_${time}_${sanitizedDenom}_${scan.confidence}%.$extension';
        final destinationFile = File('${imagesDir.path}/$imageName');
        await originalFile.copy(destinationFile.path);
      }
    }
    
    // Create README file
    final readmeContent = '''
PesoCheck Export - ${DateTime.now().toLocal()}

This folder contains:
- data/scan_history.csv: Scan data in CSV format
- data/scan_history.json: Scan data in JSON format  
- data/scan_report.json: Summary report with statistics
- images/: Scanned bill images with descriptive names

Image naming convention:
[Status]_[Denomination]_[Confidence]_[Index].jpg
Example: Counterfeit_Php500_99%_1.jpg

Total scans: ${scans.length}
Export date: ${DateTime.now().toLocal()}
''';
    
    final readmeFile = File('${exportPath.path}/README.txt');
    await readmeFile.writeAsString(readmeContent);
    
    return exportPath.path;
  }

  /// Share the exported folder
  static Future<void> shareExport(String exportPath) async {
    final directory = Directory(exportPath);
    if (await directory.exists()) {
      await Share.shareXFiles(
        [XFile(exportPath)],
        text: 'PesoCheck Export - ${DateTime.now().toLocal()}',
      );
    }
  }

  /// Open the exported content in a file viewer. Tries README first, then folder.
  static Future<void> openExport(String exportPath) async {
    final readmeFile = File('$exportPath/README.txt');
    if (await readmeFile.exists()) {
      await OpenFilex.open(readmeFile.path);
      return;
    }
    await OpenFilex.open(exportPath);
  }
} 