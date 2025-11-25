// frontend/lib/screens/scanner_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  // Configuración optimizada para mejor detección
  final MobileScannerController _scannerController = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.all],
    // Intentar forzar alta resolución (útil en Android, y en Web si el navegador lo respeta)
    cameraResolution: const Size(1920, 1080), 
    autoStart: false, // Control manual del inicio para mejor gestión de ciclo de vida
  );
  
  bool _isProcessing = false;
  bool _isTorchOn = false;
  bool _isStarted = false;
  bool _isInitializing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    if (!mounted) return;
    
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      // Pequeño delay para asegurar que cualquier instancia previa se haya limpiado
      // Especialmente crítico en Safari iOS, pero innecesario en Android
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (!mounted) return;

      await _scannerController.start();
      
      if (mounted) {
        setState(() {
          _isStarted = true;
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('Error starting scanner: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.isInitialized) return;
    
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _scannerController.stop();
        setState(() => _isStarted = false);
        break;
      case AppLifecycleState.resumed:
        _initializeScanner();
        break;
      case AppLifecycleState.inactive:
        _scannerController.stop();
        setState(() => _isStarted = false);
        break;
    }
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    // Stop explícito antes de dispose
    await _scannerController.stop();
    _scannerController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        setState(() {
          _isProcessing = true;
        });
        // Detener inmediatamente al detectar
        _scannerController.stop();
        Navigator.of(context).pop(code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear Código'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          // Botón para cambiar de cámara (útil en Web para cambiar lentes)
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined),
            tooltip: 'Cambiar cámara',
            onPressed: () async {
              await _scannerController.switchCamera();
            },
          ),
          if (!kIsWeb)
            IconButton(
              icon: Icon(
                _isTorchOn ? Icons.flash_on : Icons.flash_off,
                color: _isTorchOn ? colorScheme.primary : Colors.white,
              ),
              onPressed: () {
                _scannerController.toggleTorch();
                setState(() {
                  _isTorchOn = !_isTorchOn;
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onBarcodeDetected,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Error de cámara',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Código: ${error.errorCode}\n${error.errorDetails?.message ?? ""}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (kIsWeb) ...[
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                          onPressed: _initializeScanner,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Overlay de escaneo
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.primary, width: 4),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    spreadRadius: 1000,
                  ),
                ],
              ),
            ),
          ),
          
          // Loading indicator
          if (_isInitializing)
            const Center(
              child: CircularProgressIndicator(),
            ),

          // Botón manual de inicio (fallback)
          if (kIsWeb && !_isStarted && !_isInitializing && _errorMessage == null)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Activar Cámara'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  onPressed: _initializeScanner,
                ),
              ),
            ),

          // Mensaje de estado y guía
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    _isProcessing 
                      ? 'Procesando...' 
                      : _errorMessage != null 
                        ? 'Error al iniciar cámara'
                        : 'Apunta al código de barras',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (kIsWeb && !_isProcessing) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Si se ve borroso, aléjate un poco o cambia de cámara',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      shadows: [
                        const Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

