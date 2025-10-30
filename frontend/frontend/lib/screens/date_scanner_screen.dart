// frontend/lib/screens/date_scanner_screen.dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show WriteBuffer;
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

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Aumentamos a ResolutionPreset.high para mejorar la precisión con texto pequeño
    _cameraController = CameraController(
      cameras[0], 
      ResolutionPreset.high, // ¡Resolución aumentada!
      enableAudio: false,
    );
    await _cameraController!.initialize();

    if (!mounted) return;

    // Iniciamos el stream de imágenes una sola vez para análisis continuo
    await _cameraController!.startImageStream(_processCameraImage);
    
    setState(() {
      _isCameraInitialized = true;
    });
  }

  // Manejador del stream de imágenes
  void _processCameraImage(CameraImage image) async {
    // Control de flujo: si ya está procesando o la pantalla está desmontada, sale.
    if (_isProcessing || !mounted) return; 
    
    _isProcessing = true; // Bloquea el procesamiento

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final recognizedText = await _textRecognizer.processImage(inputImage);

      // DEPURACIÓN: Si esta línea se imprime, el OCR está detectando texto.
      if (recognizedText.blocks.isNotEmpty) {
         print("--- Texto Detectado en Frame ---");
      }

      for (final block in recognizedText.blocks) {
        print("OCR Bloque: ${block.text}"); 

        final date = parseExpirationDate(block.text);
        if (date != null) {
          if (mounted) {
            // Detenemos el stream y devolvemos la fecha
            await _cameraController?.stopImageStream(); 
            Navigator.of(context).pop(date);
          }
          return; 
        }
      }
    } catch (e) {
      print("Error en OCR: $e");
    } finally {
      // Esperamos 500ms para limitar la tasa de procesamiento (2 FPS)
      await Future.delayed(const Duration(milliseconds: 500)); 
      
      // Libera el bloqueo para el siguiente frame
      if (mounted) {
         _isProcessing = false; 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Fecha'),
      ),
      body: Stack(
        children: [
          if (_isCameraInitialized && _cameraController != null)
            Center(
              child: AspectRatio(
                // Ajuste del AspectRatio para que la previsualización se vea vertical correctamente
                aspectRatio: _cameraController!.description.sensorOrientation % 180 == 90
                    ? _cameraController!.value.aspectRatio == 0 
                        ? 1 
                        : 1 / _cameraController!.value.aspectRatio 
                    : _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
          
          // Overlay para guiar al usuario
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(12.0),
              child: const Text(
                'Enfoca la fecha de caducidad en el recuadro verde',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Detener el stream y liberar recursos
    _cameraController?.stopImageStream(); 
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  // Función auxiliar para convertir CameraImage a InputImage con rotación correcta
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final sensorOrientation = _cameraController!.description.sensorOrientation;
    
    // Mapeo directo de la rotación del sensor para ML Kit
    final rotation = switch (sensorOrientation) {
      0 => InputImageRotation.rotation0deg,
      90 => InputImageRotation.rotation90deg,
      180 => InputImageRotation.rotation180deg,
      270 => InputImageRotation.rotation270deg,
      _ => InputImageRotation.rotation0deg,
    };
    
    // DEPURACIÓN: Muestra la rotación que se utiliza.
    print('Rotación enviada a ML Kit: ${rotation.name}');

    if (Platform.isAndroid) {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      // Formato y metadatos específicos para Android YUV (NV21)
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation, 
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }
    
    return null;
  }
}