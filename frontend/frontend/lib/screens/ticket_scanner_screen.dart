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
  String _statusMessage = 'Selecciona el tipo de ticket para empezar';
  final List<TicketItem> _mergedItems = [];
  String _detectedSupermercado = 'Desconocido';
  List<TicketItem> _pendingUniqueItems = [];
  List<TicketItem> _pendingDuplicateItems = [];
  bool _includeDuplicates = false;

  String _normalizeItemName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isDuplicateItem(TicketItem candidate, TicketItem incoming) {
    final candidateName = _normalizeItemName(candidate.nombre);
    final incomingName = _normalizeItemName(incoming.nombre);
    if (candidateName != incomingName) {
      return false;
    }

    final sameQuantity = candidate.cantidad == incoming.cantidad;
    final samePrice =
        (candidate.precioUnitario - incoming.precioUnitario).abs() < 0.01;
    return sameQuantity && samePrice;
  }

  void _stageParsedResult(ParsedTicketResult parsedResult) {
    final overlapCandidates = _mergedItems.length <= 8
        ? [..._mergedItems]
        : _mergedItems.sublist(_mergedItems.length - 8);

    final uniqueItems = <TicketItem>[];
    final duplicateItems = <TicketItem>[];

    for (final item in parsedResult.items) {
      final isDuplicate = overlapCandidates.any(
        (candidate) => _isDuplicateItem(candidate, item),
      );

      if (isDuplicate) {
        duplicateItems.add(item);
      } else {
        uniqueItems.add(item);
      }
    }

    _pendingUniqueItems = uniqueItems;
    _pendingDuplicateItems = duplicateItems;

    if (_detectedSupermercado == 'Desconocido' &&
        parsedResult.supermercado != 'Desconocido') {
      _detectedSupermercado = parsedResult.supermercado;
    }
  }

  void _applyPendingItems({required bool includeDuplicates}) {
    if (_pendingUniqueItems.isEmpty && _pendingDuplicateItems.isEmpty) {
      return;
    }

    _mergedItems.addAll(_pendingUniqueItems);
    if (includeDuplicates) {
      _mergedItems.addAll(_pendingDuplicateItems);
    }

    _pendingUniqueItems = [];
    _pendingDuplicateItems = [];
  }

  Future<bool?> _showScanSummarySheet() async {
    final newCount = _pendingUniqueItems.length;
    final duplicateCount = _pendingDuplicateItems.length;
    var localIncludeDuplicates = _includeDuplicates;

    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final textTheme = Theme.of(sheetContext).textTheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Resultados del escaneo',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Se detectaron $newCount lineas nuevas.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (duplicateCount > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        '$duplicateCount posibles duplicadas.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: localIncludeDuplicates,
                        onChanged: (value) {
                          setSheetState(() {
                            localIncludeDuplicates = value;
                          });
                        },
                        title: const Text('Incluir duplicadas'),
                        subtitle: const Text(
                          'Si el ticket estaba repetido, desactivalo.',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _includeDuplicates = localIncludeDuplicates;
                              Navigator.of(sheetContext).pop(true);
                            },
                            child: const Text('Añadir otra foto'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              _includeDuplicates = localIncludeDuplicates;
                              Navigator.of(sheetContext).pop(false);
                            },
                            child: const Text('Continuar'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        _includeDuplicates = localIncludeDuplicates;
                        _mergedItems.clear();
                        _pendingUniqueItems = [];
                        _pendingDuplicateItems = [];
                        _detectedSupermercado = 'Desconocido';
                        Navigator.of(sheetContext).pop(null);
                      },
                      child: const Text('Empezar de cero'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _processImage(ImageSource source) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Preparando imagen...';
    });

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (image == null) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Proceso cancelado';
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
      _statusMessage = 'Preparando PDF...';
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
          _statusMessage = 'Proceso cancelado';
        });
        return;
      }

      final pdfPath = result.files.first.path!;
      setState(() {
        _statusMessage = 'Convirtiendo PDF...';
      });

      // Open the PDF and render ALL pages to images, then run OCR on each
      final doc = await PdfDocument.openFile(pdfPath);
      final allBlocks = <TextBlock>[];

      for (int pageIndex = 1; pageIndex <= doc.pagesCount; pageIndex++) {
        setState(() {
          _statusMessage =
              'Leyendo página $pageIndex de ${doc.pagesCount}...';
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
        _statusMessage = 'Analizando productos y descuentos...';
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
      _statusMessage = 'Leyendo texto del ticket...';
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
      _statusMessage = 'Analizando productos y descuentos...';
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
    setState(() {
      _isProcessing = false;
      _statusMessage = 'Escaneo listo.';
    });

    _stageParsedResult(parsedResult);

    final addAnother = await _showScanSummarySheet();
    if (addAnother == null || !mounted) {
      return;
    }

    _applyPendingItems(includeDuplicates: _includeDuplicates);

    if (addAnother) {
      setState(() {
        _statusMessage =
            'Puedes añadir otra foto o continuar con el ticket.';
      });
      return;
    }

    Navigator.of(context).pop(
      ParsedTicketResult(
        supermercado: _detectedSupermercado,
        items: List<TicketItem>.from(_mergedItems),
      ),
    );
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
      _statusMessage = 'No se pudo procesar el ticket.';
    });
  }

  Future<void> _showSourceSheet() async {
    if (_isProcessing) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final textTheme = Theme.of(sheetContext).textTheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: ListView(
              shrinkWrap: true,
              children: [
                    Text(
                      'Selecciona el origen',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                      'Puedes usar foto, imagen o un PDF digital.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSourceSection(
                  title: 'Ticket fisico',
                  children: [
                    _buildSourceTile(
                      context: sheetContext,
                      icon: Icons.camera_alt_rounded,
                      title: 'Usar camara',
                      subtitle: 'Ideal para tickets impresos.',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _processImage(ImageSource.camera);
                      },
                    ),
                    _buildSourceTile(
                      context: sheetContext,
                      icon: Icons.photo_library_rounded,
                      title: 'Elegir foto',
                      subtitle: 'Selecciona una imagen clara del ticket.',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _processImage(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSourceSection(
                  title: 'Ticket digital',
                  children: [
                    _buildSourceTile(
                      context: sheetContext,
                      icon: Icons.picture_as_pdf_rounded,
                      title: 'Subir PDF',
                      subtitle: 'Tickets descargados o enviados por email.',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _processPdf();
                      },
                    ),
                    _buildSourceTile(
                      context: sheetContext,
                      icon: Icons.image_rounded,
                      title: 'Imagen o pantallazo',
                      subtitle: 'Pantallazos de Lidl Plus o Dia.',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _processImage(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
              const SizedBox(height: 32),

              if (_isProcessing)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 24),
                        Text('Procesando en tu dispositivo...'),
                        Text(
                          'No se sube ningun archivo.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: colorScheme.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Escanea un ticket',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Aceptamos foto, imagen guardada o PDF.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _showSourceSheet,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Elegir ticket'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _buildSourceTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
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
      ),
    );
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }
}
