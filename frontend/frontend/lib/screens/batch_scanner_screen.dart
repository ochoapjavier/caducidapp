import 'dart:async';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:frontend/utils/date_parser.dart';
import 'package:flutter/services.dart';

enum ScannerState {
  scanningBarcode,
  scanningDate,
}

class ScannedItem {
  final String barcode;
  final DateTime? expiryDate;
  final String? imagePath;

  ScannedItem({required this.barcode, this.expiryDate, this.imagePath});
}

class BatchScannerScreen extends StatefulWidget {
  const BatchScannerScreen({super.key});

  @override
  State<BatchScannerScreen> createState() => _BatchScannerScreenState();
}

class _BatchScannerScreenState extends State<BatchScannerScreen> with WidgetsBindingObserver {
  // --- Controllers ---
  late MobileScannerController _barcodeController;

  // We use CameraController for Date OCR (higher res needed) - Native Only
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // --- State ---
  ScannerState _currentState = ScannerState.scanningBarcode;
  final List<ScannedItem> _scannedItems = [];
  
  String? _currentBarcode;
  bool _isProcessing = false;
  String _statusMessage = 'Escanea el producto';
  
  // --- Initialization ---
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize MobileScanner with Web optimizations (copied from scanner_screen.dart)
    _barcodeController = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: kIsWeb 
        ? const [
            BarcodeFormat.ean13, 
            BarcodeFormat.ean8, 
            BarcodeFormat.upcA, 
            BarcodeFormat.upcE, 
            BarcodeFormat.code128, 
            BarcodeFormat.code39,
          ]
        : const [BarcodeFormat.all],
      cameraResolution: kIsWeb ? const Size(1920, 1080) : null, // High res for Web
      autoStart: false,
    );

    _initializeBarcodeScanner();
    
    if (!kIsWeb) {
      _initializeCamera(); 
    }
  }

  Future<void> _initializeBarcodeScanner() async {
    // Web delay fix
    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (mounted) {
      await _barcodeController.start();
    }
  }

  Future<void> _initializeCamera() async {
    if (kIsWeb) return; 

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.veryHigh, 
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _barcodeController.dispose();
    _cameraController?.dispose();
    if (!kIsWeb) {
      _textRecognizer.close();
    }
    super.dispose();
  }

  // --- Logic: State A (Barcode) ---
  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing || _currentState != ScannerState.scanningBarcode) return;
    if (capture.barcodes.isEmpty) return;
    
    final barcode = capture.barcodes.first.rawValue;
    if (barcode != null) {
      setState(() {
        _isProcessing = true;
        _currentBarcode = barcode;
      });
      
      HapticFeedback.mediumImpact();
      await _barcodeController.stop();
      
      // Transition to Date State
      setState(() {
        _currentState = ScannerState.scanningDate;
        _statusMessage = kIsWeb ? 'Selecciona la fecha' : 'Apunta a la caducidad';
        _isProcessing = false;
      });

      // Initialize OCR Camera if Native
      if (!kIsWeb && _cameraController != null && !_cameraController!.value.isInitialized) {
         try {
           await _cameraController!.initialize();
         } catch (e) {
           print("Error initializing OCR camera: $e");
         }
      }
    }
  }

  // --- Logic: State B (Date) ---
  Future<void> _scanDate() async {
    // WEB: Manual Date Picker
    if (kIsWeb) {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 30)),
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      );
      if (picked != null) {
        _finalizeItem(picked);
      }
      return;
    }

    // NATIVE: OCR
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      DateTime? detectedDate;
      for (final block in recognizedText.blocks) {
        detectedDate = parseExpirationDate(block.text);
        if (detectedDate != null) break;
      }

      if (detectedDate != null) {
        HapticFeedback.heavyImpact();
        _finalizeItem(detectedDate);
      } else {
        HapticFeedback.vibrate();
        setState(() {
          _statusMessage = 'No se detectó fecha. Reintenta o Salta.';
        });
      }
    } catch (e) {
      print('OCR Error: $e');
      setState(() {
        _statusMessage = 'Error OCR. Intenta de nuevo.';
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _skipDate() {
    _finalizeItem(null);
  }

  void _finalizeItem(DateTime? date) async {
    if (_currentBarcode == null) return;

    setState(() {
      _scannedItems.add(ScannedItem(
        barcode: _currentBarcode!,
        expiryDate: date,
      ));
      
      _currentBarcode = null;
      _currentState = ScannerState.scanningBarcode;
      _statusMessage = 'Escanea el producto';
      _isProcessing = false;
    });

    // Restart Barcode Scanner
    await Future.delayed(const Duration(milliseconds: 100));
    await _barcodeController.start();
  }

  void _finishBatch() {
    if (_scannedItems.isEmpty) return;
    Navigator.pushNamed(context, '/batch_organizer', arguments: _scannedItems);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Layer 1: Camera / Content
          if (_currentState == ScannerState.scanningBarcode)
            MobileScanner(
              controller: _barcodeController,
              onDetect: _onBarcodeDetected,
            )
          else if (_currentState == ScannerState.scanningDate)
            if (kIsWeb)
              _buildWebDateSelector()
            else if (_cameraController != null && _cameraController!.value.isInitialized)
              CameraPreview(_cameraController!)
            else
              const Center(child: CircularProgressIndicator()),

          // Layer 2: Overlay UI
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'Items: ${_scannedItems.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Center Guide (Only for Barcode or Native OCR)
                if (!kIsWeb || _currentState == ScannerState.scanningBarcode)
                  Container(
                    width: 300,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _currentState == ScannerState.scanningBarcode ? Colors.green : Colors.amber,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                
                const Spacer(),

                // Bottom Controls (Date Mode)
                if (_currentState == ScannerState.scanningDate)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _skipDate,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('SALTAR'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            onPressed: _scanDate, // Triggers DatePicker on Web, OCR on Native
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(kIsWeb ? 'SELECCIONAR FECHA' : 'CAPTURAR FECHA'),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Carousel
                Container(
                  height: 80,
                  color: Colors.black87,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _scannedItems.length,
                    itemBuilder: (context, index) {
                      final item = _scannedItems[_scannedItems.length - 1 - index];
                      return Container(
                        width: 60,
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: item.expiryDate == null ? Border.all(color: Colors.red, width: 2) : null,
                        ),
                        child: Center(
                          child: Icon(Icons.shopping_bag, color: Colors.grey[800]),
                        ),
                      );
                    },
                  ),
                ),
                
                // Finish Button
                if (_scannedItems.isNotEmpty && _currentState == ScannerState.scanningBarcode)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: FilledButton(
                      onPressed: _finishBatch,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: Text('TERMINAR (${_scannedItems.length})'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebDateSelector() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              "OCR no disponible en Web",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              "Selecciona la fecha manualmente",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _scanDate,
              child: const Text("ABRIR CALENDARIO"),
            ),
          ],
        ),
      ),
    );
  }
}
