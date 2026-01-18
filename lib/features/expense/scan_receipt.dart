import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ScanReceiptPage extends StatefulWidget {
  const ScanReceiptPage({super.key});

  @override
  State<ScanReceiptPage> createState() => _ScanReceiptPageState();
}

class _ScanReceiptPageState extends State<ScanReceiptPage> {
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;

  bool _isScanning = false;
  String _rawText = "";

  String _shopName = "-";
  String _date = "-";
  String _total = "-";

  bool _showRaw = false;

  // ---------------- Pick Image ----------------
  Future<void> _pickFromCamera() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (picked == null) return;
    setState(() {
      _imageFile = File(picked.path);
    });
    await _scanImage();
  }

  Future<void> _pickFromGallery() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;
    setState(() {
      _imageFile = File(picked.path);
    });
    await _scanImage();
  }

  // ---------------- OCR Scan ----------------
  Future<void> _scanImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isScanning = true;
      _rawText = "";
      _shopName = "-";
      _date = "-";
      _total = "-";
    });

    try {
      final inputImage = InputImage.fromFile(_imageFile!);

      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      await textRecognizer.close();

      final text = recognizedText.text.trim();

      setState(() {
        _rawText = text;
      });

      // Extract details
      final shop = _extractShopName(text);
      final date = _extractDate(text);
      final total = _extractTotal(text);

      setState(() {
        _shopName = shop.isNotEmpty ? shop : "-";
        _date = date.isNotEmpty ? date : "-";
        _total = total.isNotEmpty ? total : "-";
      });
    } catch (e) {
      debugPrint("OCR error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Scan failed: $e")));
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  // ---------------- Extract Shop ----------------
  /// Very simple logic:
  /// - pick first line that looks like a shop name
  /// - avoid lines that contain GSTIN, Phone, Bill No, etc.
  String _extractShopName(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    for (final line in lines.take(20)) {
      final upper = line.toUpperCase();

      // skip junk lines
      if (upper.contains("GSTIN") ||
          upper.contains("FSSAI") ||
          upper.contains("PHONE") ||
          upper.contains("BILL") ||
          upper.contains("CASH") ||
          upper.contains("TAX") ||
          upper.contains("INVOICE") ||
          upper.contains("RECEIPT") ||
          upper.contains("AMOUNT") ||
          upper.contains("TOTAL")) {
        continue;
      }

      // good candidate: mostly letters + spaces
      final cleaned = line.replaceAll(RegExp(r'[^A-Za-z ]'), '').trim();
      if (cleaned.length >= 5) {
        return line;
      }
    }

    return "";
  }

  // ---------------- Extract Date ----------------
  /// Supports:
  /// 13/01/2026
  /// 13-01-2026
  /// 13.01.2026
  String _extractDate(String text) {
    final dateRegex = RegExp(
      r'(\d{1,2}[\/\-\.\s]\d{1,2}[\/\-\.\s]\d{2,4})',
      caseSensitive: false,
    );

    final match = dateRegex.firstMatch(text);
    if (match != null) {
      return match.group(1)!.replaceAll(RegExp(r'\s+'), '');
    }
    return "";
  }

  // ---------------- Extract Total ----------------
  /// Try to find "TOTAL" line first
  /// Example: TOTAL 394.74
  /// If not found -> take biggest ₹ amount
  String _extractTotal(String text) {
    // 1) Find line containing total keywords
    final lines = text.split('\n').map((e) => e.trim()).toList();

    for (final line in lines.reversed.take(40)) {
      final upper = line.toUpperCase();

      if (upper.contains("TOTAL") ||
          upper.contains("GRAND TOTAL") ||
          upper.contains("AMOUNT RECEIVED") ||
          upper.contains("NET AMOUNT") ||
          upper.contains("AMOUNT")) {
        final money = _extractMoneyFromLine(line);
        if (money.isNotEmpty) return money;
      }
    }

    // 2) fallback: pick highest amount in entire text
    final allAmounts = RegExp(r'(\d+\.\d{2})').allMatches(text).toList();
    if (allAmounts.isEmpty) return "";

    double maxVal = 0;
    String maxStr = "";

    for (final m in allAmounts) {
      final s = m.group(1) ?? "";
      final v = double.tryParse(s);
      if (v != null && v > maxVal) {
        maxVal = v;
        maxStr = s;
      }
    }

    return maxStr;
  }

  String _extractMoneyFromLine(String line) {
    // match 394.74 or 1338.00
    final match = RegExp(r'(\d+\.\d{2})').firstMatch(line);
    if (match != null) return match.group(1) ?? "";
    return "";
  }

  // ---------------- Use This Data ----------------
  void _useThisData() {
    if (_shopName == "-" && _date == "-" && _total == "-") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No extracted details found ❌")),
      );
      return;
    }

    Navigator.pop(context, {
      "shop": _shopName,
      "date": _date,
      "total": _total,
      "rawText": _rawText,
    });
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Receipt"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _pickFromCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isScanning ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo),
                  label: const Text("Gallery"),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_imageFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(_imageFile!, height: 220, fit: BoxFit.cover),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  "Pick a receipt image to scan",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),

          const SizedBox(height: 16),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Extracted Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  _detailRow("Shop", _shopName),
                  _detailRow("Date", _date),
                  _detailRow("Total", _total == "-" ? "-" : "₹$_total"),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? null : _useThisData,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("Use This Data"),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          ListTile(
            title: const Text("View Raw OCR Text (Debug)"),
            trailing: Icon(
              _showRaw ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            ),
            onTap: () => setState(() => _showRaw = !_showRaw),
          ),

          if (_showRaw)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isScanning
                  ? const Center(child: CircularProgressIndicator())
                  : Text(
                      _rawText.isEmpty ? "No OCR text yet" : _rawText,
                      style: const TextStyle(fontSize: 13),
                    ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
