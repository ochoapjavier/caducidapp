// frontend/lib/screens/date_scanner_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:frontend/utils/date_parser.dart';

class DateScannerScreen extends StatefulWidget {
  const DateScannerScreen({super.key});

  @override
  State<DateScannerScreen> createState() => _DateScannerScreenState();
}

class _DateScannerScreenState extends State<DateScannerScreen> {
  // Configuración de ML Kit
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false; // Bloqueo para limitar la tasa de procesamiento
  DateTime? _detectedDate; // Fecha detectada pendiente de confirmación
  String _statusMessage = 'Toca "Capturar" cuando estés listo'; // Mensaje de estado

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Usamos resolución muy alta para mejor precisión en texto pequeño
    _cameraController = CameraController(
      cameras[0], 
      ResolutionPreset.veryHigh, // Máxima resolución para mejor OCR
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // Formato óptimo para ML Kit
    );
    await _cameraController!.initialize();

    if (!mounted) return;

    // NO iniciamos el stream automáticamente - esperamos a que el usuario pulse capturar
    
    setState(() {
      _isCameraInitialized = true;
    });
  }
  
  // NUEVO: Captura manual con un solo frame
  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Analizando imagen...';
      _detectedDate = null;
    });

    try {
      // Capturamos UNA SOLA imagen de alta calidad
      final XFile imageFile = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(imageFile.path);
      
      final recognizedText = await _textRecognizer.processImage(inputImage);

      print("--- Texto Detectado ---");
      print(recognizedText.text);

      // Buscamos fechas en todo el texto reconocido
      for (final block in recognizedText.blocks) {
        final date = parseExpirationDate(block.text);
        if (date != null) {
          setState(() {
            _detectedDate = date;
            _statusMessage = '¿Es correcta esta fecha?';
          });
          return; // Salimos si encontramos una fecha
        }
      }
      
      // No se encontró ninguna fecha
      setState(() {
        _statusMessage = 'No se detectó ninguna fecha. Inténtalo de nuevo.';
      });
    } catch (e) {
      print("Error en OCR: $e");
      setState(() {
        _statusMessage = 'Error al escanear. Inténtalo de nuevo.';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Fecha'),
        backgroundColor: colorScheme.surface,
      ),
      body: Stack(
        children: [
          // Vista previa de la cámara
          if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
          
          // Overlay oscuro con recorte para el marco
          if (_isCameraInitialized)
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.5),
                BlendMode.srcOut,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Marco de guía
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(
                  Icons.calendar_today,
                  size: 40,
                  color: colorScheme.primary.withOpacity(0.5),
                ),
              ),
            ),
          ),
          
          // Panel de información superior
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface.withAlpha((255 * 0.95).round()),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_detectedDate != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_detectedDate!.day}/${_detectedDate!.month}/${_detectedDate!.year}',
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Panel de controles inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface.withAlpha((255 * 0.95).round()),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Instrucciones
                  if (_detectedDate == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, 
                            size: 20, 
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Coloca la fecha dentro del marco y pulsa Capturar',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Botones
                  if (_detectedDate == null)
                    FilledButton.icon(
                      onPressed: _isProcessing ? null : _captureAndAnalyze,
                      icon: _isProcessing 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt),
                      label: Text(_isProcessing ? 'Analizando...' : 'Capturar'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _detectedDate = null;
                                _statusMessage = 'Toca "Capturar" cuando estés listo';
                              });
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Reintentar'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop(_detectedDate);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Confirmar'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }
}