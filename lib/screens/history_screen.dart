import 'package:flutter/material.dart';
import '../models/scan_result.dart';
import '../services/history_service.dart';
import '../services/export_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ScanResult> _history = [];
  List<ScanResult> _filteredHistory = [];
  String _filterStatus = 'All'; // All, Real, Counterfeit, Invalid
  String _sortBy = 'Date'; // Date, Confidence, Denomination

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryService.getHistory();
    setState(() {
      _history = history;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredHistory = List.from(_history);
    
    // Apply status filter
    if (_filterStatus == 'Real') {
      _filteredHistory = _filteredHistory.where((scan) => scan.status == BillStatus.real).toList();
    } else if (_filterStatus == 'Counterfeit') {
      _filteredHistory = _filteredHistory.where((scan) => scan.status == BillStatus.counterfeit).toList();
    }
    
    // Apply sorting
    switch (_sortBy) {
      case 'Date':
        _filteredHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case 'Confidence':
        _filteredHistory.sort((a, b) => b.confidence.compareTo(a.confidence));
        break;
      case 'Denomination':
        _filteredHistory.sort((a, b) => a.denomination.compareTo(b.denomination));
        break;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text('Filter & Sort'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Filter
            const Text('Filter by Status:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _filterStatus,
              dropdownColor: const Color(0xFF333333),
              style: const TextStyle(color: Colors.white),
              items: ['All', 'Real', 'Counterfeit'].map((status) {
                return DropdownMenuItem(value: status, child: Text(status));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _filterStatus = value!;
                  _applyFilters();
                });
              },
            ),
            const SizedBox(height: 16),
            // Sort By
            const Text('Sort by:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _sortBy,
              dropdownColor: const Color(0xFF333333),
              style: const TextStyle(color: Colors.white),
              items: ['Date', 'Confidence', 'Denomination'].map((sort) {
                return DropdownMenuItem(value: sort, child: Text(sort));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                  _applyFilters();
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _applyFilters();
              });
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showStatistics() {
    final totalScans = _history.length;
    final realScans = _history.where((scan) => scan.status == BillStatus.real).length;
    final counterfeitScans = _history.where((scan) => scan.status == BillStatus.counterfeit).length;
    final avgConfidence = totalScans > 0 
        ? _history.map((scan) => scan.confidence).reduce((a, b) => a + b) / totalScans 
        : 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text('Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatItem('Total Scans', totalScans.toString()),
            _buildStatItem('Real Bills', '$realScans (${totalScans > 0 ? (realScans / totalScans * 100).toStringAsFixed(1) : 0}%)'),
            _buildStatItem('Counterfeit Bills', '$counterfeitScans (${totalScans > 0 ? (counterfeitScans / totalScans * 100).toStringAsFixed(1) : 0}%)'),
            _buildStatItem('Average Confidence', '${avgConfidence.toStringAsFixed(1)}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showImageDialog(ScanResult scan) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with scan info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(scan.statusIcon, color: scan.statusColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scan.statusText,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Confidence: ${scan.confidence}%',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Image
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: Image.file(
                      File(scan.imagePath!),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text('Export History'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.blue),
              title: const Text('Export as CSV'),
              subtitle: const Text('Download spreadsheet format'),
              onTap: () {
                Navigator.of(context).pop();
                _exportData('csv');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _exportData(String format) async {
    final data = _filteredHistory.isNotEmpty ? _filteredHistory : _history;
    
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          backgroundColor: Color(0xFF222222),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Downloading CSV...'),
            ],
          ),
        ),
      );

      // Get Downloads directory
      final downloadsDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'pesocheck_history_$timestamp.csv';
      final filePath = '${downloadsDir.path}/$fileName';
      
      // Export CSV content
      final csvContent = ExportService.exportToCSV(data);
      final file = File(filePath);
      await file.writeAsString(csvContent);
      
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();
      
      // Show success dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF222222),
            title: const Text('Download Complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File saved: $fileName'),
                const SizedBox(height: 8),
                Text('Location: Downloads folder'),
                const SizedBox(height: 8),
                const Text('The CSV file contains all your scan history with:'),
                const Text('• Scan ID, Status, Confidence'),
                const Text('• Denomination, Date, Time'),
                const Text('• Image names and file paths'),
                const SizedBox(height: 8),
                const Text('Files saved to your Downloads folder', 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await OpenFilex.open(filePath);
                },
                child: const Text('Open'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await Share.shareXFiles([XFile(filePath)]);
                },
                child: const Text('Share'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) Navigator.of(context).pop();
      
      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter & Sort',
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showStatistics,
            tooltip: 'Statistics',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _showExportDialog,
            tooltip: 'Export',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter info
          if (_filterStatus != 'All' || _sortBy != 'Date')
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.deepPurple.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.deepPurpleAccent),
                  const SizedBox(width: 8),
                  Text(
                    'Filtered: $_filterStatus • Sorted by: $_sortBy',
                    style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 12),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterStatus = 'All';
                        _sortBy = 'Date';
                        _applyFilters();
                      });
                    },
                    child: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          // History list
          Expanded(
            child: _filteredHistory.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.white24),
                        SizedBox(height: 16),
                        Text(
                          'No scan history yet',
                          style: TextStyle(fontSize: 18, color: Colors.white54),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredHistory.length,
                    itemBuilder: (context, index) {
                      final scan = _filteredHistory[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: const Color(0xFF333333),
                        child: ListTile(
                          onTap: () {
                            if (scan.imagePath != null && File(scan.imagePath!).existsSync()) {
                              _showImageDialog(scan);
                            }
                          },
                          leading: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: scan.imagePath != null && File(scan.imagePath!).existsSync()
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(scan.imagePath!),
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(
                                    scan.statusIcon,
                                    color: scan.statusColor,
                                    size: 30,
                                  ),
                          ),
                          title: Row(
                            children: [
                              Icon(
                                scan.statusIcon,
                                color: scan.statusColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${scan.statusText} ${scan.denomination}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (scan.imagePath != null && File(scan.imagePath!).existsSync())
                                const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white54,
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Confidence: ${scan.confidence}%'),
                              Text(
                                '${scan.timestamp.day}/${scan.timestamp.month}/${scan.timestamp.year} ${scan.timestamp.hour}:${scan.timestamp.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'delete') {
                                await HistoryService.deleteScan(scan.id);
                                _loadHistory(); // Reload the list
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 