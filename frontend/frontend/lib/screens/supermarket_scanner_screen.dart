import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/nutri_scan_result.dart';
import '../services/api_service.dart' as api;
import '../services/shopping_service.dart';
import '../widgets/app_toast.dart';

import '../widgets/supermarket_compare_drawer.dart';

class SupermarketScannerScreen extends StatefulWidget {
  final int? hogarId;

  const SupermarketScannerScreen({super.key, this.hogarId});

  @override
  State<SupermarketScannerScreen> createState() => _SupermarketScannerScreenState();
}

class _SupermarketScannerScreenState extends State<SupermarketScannerScreen> with WidgetsBindingObserver {
  final MobileScannerController _scannerController = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: kIsWeb
        ? const [
            BarcodeFormat.ean13,
            BarcodeFormat.ean8,
            BarcodeFormat.upcA,
            BarcodeFormat.upcE,
          ]
        : const [BarcodeFormat.all],
    cameraResolution: const Size(1920, 1080),
    autoStart: false,
    detectionTimeoutMs: 500,
  );

  bool _isProcessing = false;
  bool _isTorchOn = false;
  bool _isInitializing = true;
  String? _errorMessage;

  // Historial de memoria de la sesión
  final List<NutriScanResult> _sessionHistory = [];

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
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 400));
      }
      if (!mounted) return;

      await _scannerController.start();
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
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
      case AppLifecycleState.inactive:
        _scannerController.stop();
        break;
      case AppLifecycleState.resumed:
        _initializeScanner();
        break;
    }
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _scannerController.stop();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    // Detener la cámara temporalmente durante la presentación
    _scannerController.stop();

    try {
      final result = await api.lookupScanProduct(code.trim());
      
      if (!mounted) return;

      setState(() {
        // Evitamos duplicados consecutivos
        _sessionHistory.removeWhere((item) => item.barcode == result.barcode);
        _sessionHistory.insert(0, result);
      });

      await _showResultBottomSheet();
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'Producto no encontrado en la base nutricional: $code',
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _showResultBottomSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return SupermarketCompareDrawer(
              history: _sessionHistory,
              onScanNext: () {
                Navigator.of(ctx).pop();
              },
              onAddToList: (prod) async {
                try {
                  if (widget.hogarId != null) {
                    await ShoppingService().addItem(
                      widget.hogarId!,
                      prod.nombre,
                    );

                    if (mounted) {
                      AppToast.show(
                        context,
                        message: 'Añadido a la lista de la compra: ${prod.nombre}',
                        type: AppToastType.success,
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    AppToast.show(
                      context,
                      message: 'Error al añadir a la lista: $e',
                      type: AppToastType.error,
                    );
                  }
                }
              },
              onSaveToCatalog: (prod) async {
                try {
                  await api.createOrUpdateProductMaster(
                    barcode: prod.barcode,
                    name: prod.nombre,
                    brand: prod.marca,
                  );
                  if (mounted) {
                    AppToast.show(
                      context,
                      message: 'Guardado en tu catálogo maestro!',
                      type: AppToastType.success,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    AppToast.show(
                      context,
                      message: 'Error al guardar en catálogo: $e',
                      type: AppToastType.error,
                    );
                  }
                }
              },
            );
          },
        );
      },
    );

    // Al cerrar el BottomSheet, reanudamos la cámara si la pantalla sigue montada
    if (mounted) {
      await _initializeScanner();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('NutriScanner Supermercado'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
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
          ),

          // Visor de escaneo
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 4),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    spreadRadius: 1000,
                  ),
                ],
              ),
            ),
          ),

          if (_isInitializing || _isProcessing)
            const Center(child: CircularProgressIndicator()),

          // Historial rápido en la parte inferior si hay escaneos en la sesión
          if (_sessionHistory.isNotEmpty && !_isProcessing)
            Positioned(
              bottom: 24 + MediaQuery.of(context).padding.bottom,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.inventory_2_rounded),
                label: Text('Ver escaneados (${_sessionHistory.length})'),
                onPressed: _showResultBottomSheet,
              ),
            ),
        ],
      ),
    );
  }
}
