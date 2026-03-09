import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:frontend/utils/date_parser.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/api_service.dart';

enum ScannerState {
  scanningBarcode,
  scanningDate,
}

class ScannedItem {
  final String barcode;
  final DateTime? expiryDate;
  final String? imagePath;
  final String? productName;
  final String? productImageUrl;
  final int quantity;

  ScannedItem({
    required this.barcode, 
    this.expiryDate, 
    this.imagePath, 
    this.productImageUrl,
    this.productName,
    this.quantity = 1,
  });
}

class BatchScannerScreen extends StatefulWidget {
  const BatchScannerScreen({super.key});

  @override
  State<BatchScannerScreen> createState() => _BatchScannerScreenState();
}

class _BatchScannerScreenState extends State<BatchScannerScreen> with WidgetsBindingObserver {
  // --- Controllers ---
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final BarcodeScanner _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);

  // --- State ---
  ScannerState _currentState = ScannerState.scanningBarcode;
  final List<ScannedItem> _scannedItems = [];
  
  String? _currentBarcode;
  bool _isBusy = false; // Prevents processing multiple frames
  String _statusMessage = 'Escanea el producto';
  String? _currentProductImage;
  String? _currentProductName;
  int _currentQuantity = 1;
  
  // --- Initialization ---
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high, // High is usually good enough for both
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
            ? ImageFormatGroup.nv21 // Better for ML Kit on Android
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_processImage);
      
      if (mounted) setState(() {});
    } catch (e) {
      print("Error initializing camera: $e");
      if (mounted) setState(() => _statusMessage = "Error de cámara: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _textRecognizer.close();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle camera lifecycle when app is minimized/resumed
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  // --- Image Processing ---
  void _processImage(CameraImage image) async {
    if (_isBusy || !mounted) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      if (_currentState == ScannerState.scanningBarcode) {
        await _processBarcode(inputImage);
      } else if (_currentState == ScannerState.scanningDate) {
        await _processDate(inputImage);
      }
    } catch (e) {
      print("Error processing image: $e");
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _processBarcode(InputImage inputImage) async {
    final barcodes = await _barcodeScanner.processImage(inputImage);
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first.rawValue;
    if (barcode != null) {
      // Stop processing temporarily to avoid duplicate reads
      _isBusy = true; 
      
      HapticFeedback.mediumImpact();
      
      if (mounted) {
        setState(() {
          _currentBarcode = barcode;
          _currentQuantity = 1;
          _currentProductName = 'Cargando...';
          _currentProductImage = null;
          _currentState = ScannerState.scanningDate;
          _statusMessage = 'Buscando fecha...';
        });
      }
      
      // Fetch info in background
      _fetchProductInfo(barcode);
      
      // Small delay to prevent instant date scanning of the barcode text itself (unlikely but safe)
      await Future.delayed(const Duration(milliseconds: 500));
      _isBusy = false;
    }
  }

  Future<void> _processDate(InputImage inputImage) async {
    final recognizedText = await _textRecognizer.processImage(inputImage);
    
    DateTime? detectedDate;
    for (final block in recognizedText.blocks) {
      detectedDate = parseExpirationDate(block.text);
      if (detectedDate != null) break;
    }

    if (detectedDate != null) {
      _isBusy = true; // Stop stream processing
      HapticFeedback.heavyImpact();
      await _showDateConfirmation(detectedDate);
      // _isBusy will be reset by _finalizeItem or manually if cancelled
    }
  }

  // --- Helper: Convert CameraImage to InputImage ---
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    
    // TODO: Handle rotation properly for all devices. 
    // For now assuming portrait mode standard.
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

    final inputImageData = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: image.planes[0].bytes, metadata: inputImageData);
  }

  // --- Logic & UI Methods ---

  Future<void> _fetchProductInfo(String barcode) async {
    try {
      var product = await fetchProductFromCatalog(barcode);
      String? imageUrl = product?['imagen_url'];
      String? name = product?['nombre'];
      
      if (imageUrl == null || name == null) {
        final offProduct = await fetchProductFromOpenFoodFacts(barcode);
        imageUrl ??= offProduct?['image_url'];
        name ??= offProduct?['product_name'];
      }

      if (mounted) {
        setState(() {
          _currentProductImage = imageUrl;
          _currentProductName = name ?? 'Producto Desconocido';
        });
      }
    } catch (e) {
      print("Error fetching info: $e");
    }
  }

  void _skipDate() {
    _finalizeItem(null);
  }

  void _finalizeItem(DateTime? date) {
    if (_currentBarcode == null) return;

    setState(() {
      _scannedItems.add(ScannedItem(
        barcode: _currentBarcode!,
        expiryDate: date,
        productImageUrl: _currentProductImage,
        productName: _currentProductName,
        quantity: _currentQuantity,
      ));
      
      _currentBarcode = null;
      _currentProductImage = null;
      _currentState = ScannerState.scanningBarcode;
      _statusMessage = 'Escanea el producto';
    });
    
    // Resume processing
    Future.delayed(const Duration(milliseconds: 500), () {
       _isBusy = false;
    });
  }

  Future<void> _showDateConfirmation(DateTime date) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Fecha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (date.isBefore(DateTime.now()))
              const Text('⚠️ Fecha pasada', style: TextStyle(color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
              _showManualDateInput(); 
            },
            child: const Text('EDITAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _finalizeItem(date);
    } else if (confirmed == null) {
       // Cancelled
       _isBusy = false;
    }
  }

  Future<void> _showManualDateInput() async {
    final controller = TextEditingController();
    final date = await showDialog<DateTime>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ingresa Fecha'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(
            hintText: 'dd/mm/aa (ej. 28/12/26)',
            border: OutlineInputBorder(),
            helperText: 'Día/Mes/Año',
          ),
          autofocus: true,
          onSubmitted: (_) => _submitManualDate(controller.text, context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => _submitManualDate(controller.text, context),
            child: const Text('ACEPTAR'),
          ),
        ],
      ),
    );
    
    if (date != null) {
      _finalizeItem(date);
    } else {
      _isBusy = false;
    }
  }

  void _submitManualDate(String text, BuildContext dialogContext) {
    final parts = text.trim().split('/');
    if (parts.length == 3) {
      try {
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        if (year < 100) year += 2000;
        final date = DateTime(year, month, day);
        Navigator.pop(dialogContext, date);
      } catch (e) {
        // Handle error
      }
    }
  }

  void _finishBatch() {
    if (_scannedItems.isEmpty) return;
    Navigator.pushNamed(context, '/batch_organizer', arguments: _scannedItems);
  }
  
  Future<void> _editScannedItem(int index) async {
    final realIndex = _scannedItems.length - 1 - index;
    final item = _scannedItems[realIndex];
    
    int newQuantity = item.quantity;
    DateTime? newDate = item.expiryDate;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(item.productName ?? 'Editar Item'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        if (newQuantity > 1) setStateDialog(() => newQuantity--);
                      },
                    ),
                    Text('x$newQuantity', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setStateDialog(() => newQuantity++),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(newDate != null 
                    ? '${newDate!.day}/${newDate!.month}/${newDate!.year}' 
                    : 'Sin Fecha'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: newDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) setStateDialog(() => newDate = picked);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() => _scannedItems.removeAt(realIndex));
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('ELIMINAR'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCELAR'),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _scannedItems[realIndex] = ScannedItem(
                      barcode: item.barcode,
                      expiryDate: newDate,
                      imagePath: item.imagePath,
                      productImageUrl: item.productImageUrl,
                      productName: item.productName,
                      quantity: newQuantity,
                    );
                  });
                  Navigator.pop(context);
                },
                child: const Text('GUARDAR'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Scaffold(body: Center(child: Text("Modo Web no soportado en esta versión")));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Layer 1: Camera
          if (_cameraController != null && _cameraController!.value.isInitialized)
            SizedBox.expand(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Layer 2: Overlay UI
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                if (_currentState == ScannerState.scanningDate)
                   Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            image: _currentProductImage != null 
                              ? DecorationImage(image: NetworkImage(_currentProductImage!), fit: BoxFit.cover)
                              : null,
                          ),
                          child: _currentProductImage == null ? const Icon(Icons.inventory_2, color: Colors.grey) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentProductName ?? 'Cargando...',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                                    onPressed: () {
                                      if (_currentQuantity > 1) setState(() => _currentQuantity--);
                                    },
                                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'x$_currentQuantity',
                                      style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                                    onPressed: () => setState(() => _currentQuantity++),
                                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                   )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black54,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Escanea código de barras',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Items: ${_scannedItems.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                
                const Spacer(),
                
                // Center Guide
                Center(
                  child: Container(
                    width: 300, height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _currentState == ScannerState.scanningBarcode ? Colors.green : Colors.amber,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _currentState == ScannerState.scanningDate
                        ? const Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "ENCUADRA LA FECHA AQUÍ",
                                style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2, color: Colors.black)]),
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                
                const Spacer(),

                // Bottom Controls (Date Mode)
                if (_currentState == ScannerState.scanningDate)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Text(
                          "Buscando fecha automáticamente...",
                          style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 16),
                        Row(
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
                                onPressed: _showManualDateInput,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text('MANUAL'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Scanned Items List
                if (_scannedItems.isNotEmpty)
                  Container(
                    height: 100,
                    color: Colors.black87,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _scannedItems.length,
                      itemBuilder: (context, index) {
                        final item = _scannedItems[_scannedItems.length - 1 - index];
                        return GestureDetector(
                          onTap: () => _editScannedItem(index),
                          child: Container(
                            width: 160,
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(8),
                              border: item.expiryDate == null ? Border.all(color: Colors.red, width: 2) : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    image: item.productImageUrl != null 
                                      ? DecorationImage(image: NetworkImage(item.productImageUrl!), fit: BoxFit.cover)
                                      : null,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        item.productName ?? 'Producto',
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'x${item.quantity}',
                                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.edit, color: Colors.white54, size: 16),
                              ],
                            ),
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
}
