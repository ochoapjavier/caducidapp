// frontend/lib/screens/ticket_scanner_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:frontend/models/ticket_item.dart';
import 'package:frontend/services/ticket_parser_service.dart';
import 'package:frontend/utils/error_handler.dart';

class TicketScannerScreen extends StatefulWidget {
  const TicketScannerScreen({super.key});

  @override
  State<TicketScannerScreen> createState() => _TicketScannerScreenState();
}

class _TicketScannerScreenState extends State<TicketScannerScreen> {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  final ImagePicker _picker = ImagePicker();
  static const int _ocrChunkHeight = 2600;
  static const int _ocrChunkOverlap = 220;

  bool _isProcessing = false;
  String _statusMessage = 'Elige cómo quieres subir el ticket';

  Future<void> _processImage(ImageSource source) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Cargando imagen...';
    });

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (image == null) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Operación cancelada';
        });
        return;
      }

      debugPrint(
        'SCANNER DEBUG: imagen seleccionada path=${image.path} source=$source',
      );

      await _runOcrOnFilePath(image.path);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _processPdf() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Seleccionando PDF...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.first.path == null) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Operación cancelada';
        });
        return;
      }

      final pdfPath = result.files.first.path!;
      setState(() {
        _statusMessage = 'Convirtiendo PDF a imagen...';
      });

      // Open the PDF and render ALL pages to images, then run OCR on each
      final doc = await PdfDocument.openFile(pdfPath);
      final allBlocks = <TextBlock>[];

      for (int pageIndex = 1; pageIndex <= doc.pagesCount; pageIndex++) {
        setState(() {
          _statusMessage =
              'Analizando página $pageIndex de ${doc.pagesCount}...';
        });

        final page = await doc.getPage(pageIndex);
        // Render at 2x resolution for better OCR accuracy.
        // pdfx.render() returns a PdfPageImage with .bytes (PNG data).
        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        await page.close();

        if (pageImage == null) continue;

        // pdfx gives PNG bytes — write to temp file for ML Kit
        final tempFile = File(
          '${Directory.systemTemp.path}/ticket_p$pageIndex.png',
        );
        await tempFile.writeAsBytes(pageImage.bytes);
        final inputImage = InputImage.fromFilePath(tempFile.path);

        final pageText = await _textRecognizer.processImage(inputImage);
        allBlocks.addAll(pageText.blocks);
        await tempFile.delete();
      }

      doc.close();

      setState(() {
        _statusMessage = 'Buscando productos y descuentos...';
      });

      // Build a combined RecognizedText from all pages
      final combinedText = RecognizedText(
        text: allBlocks.map((b) => b.text).join('\n'),
        blocks: allBlocks,
      );
      await _parseCombinedText(combinedText);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _runOcrOnFilePath(String filePath) async {
    setState(() {
      _statusMessage = 'Extrayendo texto con IA Local...';
    });

    debugPrint('SCANNER DEBUG: _runOcrOnFilePath filePath=$filePath');

    final inputImage = InputImage.fromFilePath(filePath);
    var recognizedText = await _textRecognizer.processImage(inputImage);

    debugPrint(
      'SCANNER DEBUG: OCR completado textLength=${recognizedText.text.length} blocks=${recognizedText.blocks.length}',
    );

    if (recognizedText.blocks.isEmpty) {
      debugPrint('SCANNER DEBUG: OCR directo vacío, probando OCR por tramos');
      final parsedResult = await _runChunkedParseOnImage(filePath);
      debugPrint(
        'SCANNER DEBUG: parseo por tramos completado supermercado=${parsedResult.supermercado} items=${parsedResult.items.length}',
      );
      await _handleParsedResult(parsedResult);
      return;
    }

    setState(() {
      _statusMessage = 'Buscando productos y descuentos...';
    });
    await _parseCombinedText(recognizedText);
  }

  Future<ParsedTicketResult> _runChunkedParseOnImage(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final decodedImage = img.decodeImage(bytes);

    if (decodedImage == null) {
      debugPrint(
        'SCANNER DEBUG: no se pudo decodificar la imagen para OCR por tramos',
      );
      return ParsedTicketResult(supermercado: 'Desconocido', items: []);
    }

    debugPrint(
      'SCANNER DEBUG: imagen decodificada width=${decodedImage.width} height=${decodedImage.height}',
    );

    if (decodedImage.height <= _ocrChunkHeight) {
      debugPrint('SCANNER DEBUG: la imagen no necesita troceado');
      return ParsedTicketResult(supermercado: 'Desconocido', items: []);
    }

    final mergedItems = <TicketItem>[];
    String detectedSupermercado = 'Desconocido';
    int chunkIndex = 0;

    for (
      int top = 0;
      top < decodedImage.height;
      top += (_ocrChunkHeight - _ocrChunkOverlap)
    ) {
      final chunkHeight = (top + _ocrChunkHeight > decodedImage.height)
          ? decodedImage.height - top
          : _ocrChunkHeight;
      if (chunkHeight <= 0) break;

      chunkIndex++;
      if (mounted) {
        setState(() {
          _statusMessage = 'Analizando tramo $chunkIndex...';
        });
      }

      final cropped = img.copyCrop(
        decodedImage,
        x: 0,
        y: top,
        width: decodedImage.width,
        height: chunkHeight,
      );

      final tempFile = File(
        '${Directory.systemTemp.path}/ticket_chunk_$chunkIndex.png',
      );
      await tempFile.writeAsBytes(Uint8List.fromList(img.encodePng(cropped)));

      try {
        final inputImage = InputImage.fromFilePath(tempFile.path);
        final chunkText = await _textRecognizer.processImage(inputImage);
        debugPrint(
          'SCANNER DEBUG: chunk=$chunkIndex top=$top height=$chunkHeight blocks=${chunkText.blocks.length} textLength=${chunkText.text.length}',
        );
        if (chunkText.blocks.isNotEmpty) {
          final parsedChunk = TicketParserService.parseTicket(chunkText);
          debugPrint(
            'SCANNER DEBUG: chunk=$chunkIndex parsed supermercado=${parsedChunk.supermercado} items=${parsedChunk.items.length}',
          );

          if (detectedSupermercado == 'Desconocido' &&
              parsedChunk.supermercado != 'Desconocido') {
            detectedSupermercado = parsedChunk.supermercado;
          }

          final overlapCandidates = mergedItems.length <= 8
              ? [...mergedItems]
              : mergedItems.sublist(mergedItems.length - 8);

          for (final item in parsedChunk.items) {
            final shouldSkipAsDuplicate = overlapCandidates.any(
              (existing) =>
                  existing.nombre == item.nombre &&
                  existing.cantidad == item.cantidad &&
                  (existing.precioUnitario - item.precioUnitario).abs() < 0.01,
            );

            if (!shouldSkipAsDuplicate) {
              mergedItems.add(item);
            }
          }
        }
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }

      if (top + chunkHeight >= decodedImage.height) break;
    }

    return ParsedTicketResult(
      supermercado: detectedSupermercado,
      items: mergedItems,
    );
  }

  Future<void> _parseCombinedText(RecognizedText recognizedText) async {
    debugPrint(
      'SCANNER DEBUG: entrando en _parseCombinedText textLength=${recognizedText.text.length} blocks=${recognizedText.blocks.length}',
    );

    ParsedTicketResult parsedResult;
    try {
      parsedResult = TicketParserService.parseTicket(recognizedText);
      debugPrint(
        'SCANNER DEBUG: parseTicket completado supermercado=${parsedResult.supermercado} items=${parsedResult.items.length}',
      );
    } catch (e, st) {
      debugPrint('SCANNER DEBUG: parseTicket lanzó excepción: $e');
      debugPrint('$st');
      rethrow;
    }

    await _handleParsedResult(parsedResult);
  }

  Future<void> _handleParsedResult(ParsedTicketResult parsedResult) async {
    if (parsedResult.items.isEmpty) {
      debugPrint('SCANNER DEBUG: parsedResult vacío');
      if (!mounted) return;
      ErrorHandler.showError(
        context,
        Exception(
          'No se detectaron productos con precio claro en el ticket. Intenta con una foto más nítida.',
        ),
      );
      setState(() {
        _statusMessage = 'No se encontraron productos. Reintenta.';
        _isProcessing = false; // ← release the spinner
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(parsedResult);
  }

  void _handleError(Object e) {
    print('Error en Ticket Scanner OCR: $e');
    if (!mounted) return;
    ErrorHandler.showError(
      context,
      Exception('Error al procesar el ticket: $e'),
    );
    setState(() {
      _isProcessing = false;
      _statusMessage = 'Hubo un error al procesar el ticket.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Ticket'),
        backgroundColor: colorScheme.surface,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Digitaliza tu compra',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              if (_isProcessing)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 24),
                        Text('Analizando ticket en tu dispositivo...'),
                        Text(
                          'Totalmente privado y gratis.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Tarjeta 1: Cámara
                _buildActionCard(
                  context: context,
                  title: 'Tomar Foto del Ticket',
                  subtitle:
                      'Asegúrate de que haya buena luz y el ticket esté liso.',
                  icon: Icons.camera_alt_rounded,
                  color: colorScheme.primary,
                  onTap: () => _processImage(ImageSource.camera),
                ),
                const SizedBox(height: 16),

                // Tarjeta 2: Galería (imagen)
                _buildActionCard(
                  context: context,
                  title: 'Subir desde Galería',
                  subtitle:
                      'Ideal para pantallazos de Día, Lidl Plus o Mercadona.',
                  icon: Icons.photo_library_rounded,
                  color: colorScheme.secondary,
                  onTap: () => _processImage(ImageSource.gallery),
                ),
                const SizedBox(height: 16),

                // Tarjeta 3: PDF
                _buildActionCard(
                  context: context,
                  title: 'Subir PDF del Ticket',
                  subtitle: 'Para tickets PDF descargados de la app del super.',
                  icon: Icons.picture_as_pdf_rounded,
                  color: Colors.deepOrange,
                  onTap: _processPdf,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }
}
