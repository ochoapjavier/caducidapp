import 'package:flutter/material.dart';
import '../models/nutri_scan_result.dart';

class NutriScanCard extends StatelessWidget {
  final NutriScanResult result;
  final VoidCallback onScanNext;
  final VoidCallback? onAddToList;
  final VoidCallback? onSaveToCatalog;

  const NutriScanCard({
    super.key,
    required this.result,
    required this.onScanNext,
    this.onAddToList,
    this.onSaveToCatalog,
  });

  String? _getSemaforoLevel(Map<String, dynamic>? semaforo, String key) {
    if (semaforo == null) return null;
    final val = semaforo[key] ??
        semaforo[key.replaceAll('_', '-')] ??
        semaforo[key.replaceAll('-', '_')];
    return val?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del producto
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: result.imageUrl != null && result.imageUrl!.isNotEmpty
                    ? Image.network(
                        result.imageUrl!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderImage(colorScheme),
                      )
                    : _buildPlaceholderImage(colorScheme),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result.marca != null && result.marca!.isNotEmpty)
                      Text(
                        result.marca!.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    Text(
                      result.nombre,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'EAN: ${result.barcode}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Badges de Salud (NOVA + NutriScore)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildNovaBadge(theme),
              if (result.nutriscoreGrade != null) _buildNutriscoreBadge(theme),
              if (result.aditivosCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Text(
                    '⚠️ ${result.aditivosCount} Aditivos',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Tabla Nutricional por 100g con Semáforos
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Valores por 100 g',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),

                _buildMacroItem(
                  theme: theme,
                  label: '⚡ Energía',
                  value: result.nutrientesMap?['energy_kcal'] != null
                      ? '${result.nutrientesMap!['energy_kcal']} kcal'
                      : 'Sin info',
                  isSub: false,
                ),
                const Divider(height: 12),

                _buildMacroItem(
                  theme: theme,
                  label: '🍞 Hidratos de carbono',
                  value: result.nutrientesMap?['carbohydrates'] != null
                      ? '${result.nutrientesMap!['carbohydrates']} g'
                      : 'Sin info',
                  isSub: false,
                ),
                _buildMacroItem(
                  theme: theme,
                  label: '    ↳ de los cuales Azúcares',
                  value: result.nutrientesMap?['sugars'] != null
                      ? '${result.nutrientesMap!['sugars']} g'
                      : 'Sin info',
                  level: _getSemaforoLevel(result.semaforoMap, 'sugars'),
                  isSub: true,
                ),
                const Divider(height: 12),

                _buildMacroItem(
                  theme: theme,
                  label: '🥑 Grasas',
                  value: result.nutrientesMap?['fat'] != null
                      ? '${result.nutrientesMap!['fat']} g'
                      : 'Sin info',
                  level: _getSemaforoLevel(result.semaforoMap, 'fat'),
                  isSub: false,
                ),
                _buildMacroItem(
                  theme: theme,
                  label: '    ↳ de las cuales Saturadas',
                  value: (result.nutrientesMap?['saturated_fat'] ?? result.nutrientesMap?['saturated-fat']) != null
                      ? '${result.nutrientesMap!['saturated_fat'] ?? result.nutrientesMap!['saturated-fat']} g'
                      : 'Sin info',
                  level: _getSemaforoLevel(result.semaforoMap, 'saturated_fat'),
                  isSub: true,
                ),
                const Divider(height: 12),

                _buildMacroItem(
                  theme: theme,
                  label: '💪 Proteínas',
                  value: result.nutrientesMap?['proteins'] != null
                      ? '${result.nutrientesMap!['proteins']} g'
                      : 'Sin info',
                  isSub: false,
                ),
                const Divider(height: 12),

                _buildMacroItem(
                  theme: theme,
                  label: '🧂 Sal',
                  value: result.nutrientesMap?['salt'] != null
                      ? '${result.nutrientesMap!['salt']} g'
                      : 'Sin info',
                  level: _getSemaforoLevel(result.semaforoMap, 'salt'),
                  isSub: false,
                ),

                // 🌾 Fibra
                const Divider(height: 12),
                _buildMacroItem(
                  theme: theme,
                  label: '🌾 Fibra alimentaria',
                  value: result.nutrientesMap?['fiber'] != null
                      ? '${result.nutrientesMap!['fiber']} g'
                      : 'Sin info',
                  customBadge: _buildFiberBadge(result.nutrientesMap?['fiber']),
                  isSub: false,
                ),

                // 🩸 Hierro
                const Divider(height: 12),
                _buildMacroItem(
                  theme: theme,
                  label: '🩸 Hierro',
                  value: result.nutrientesMap?['iron_mg'] != null
                      ? '${result.nutrientesMap!['iron_mg']} mg'
                      : 'Sin info',
                  customBadge: _buildIronBadge(result.nutrientesMap?['iron_mg']),
                  isSub: false,
                ),

                // 🦴 Calcio
                const Divider(height: 12),
                _buildMacroItem(
                  theme: theme,
                  label: '🦴 Calcio',
                  value: result.nutrientesMap?['calcium_mg'] != null
                      ? '${result.nutrientesMap!['calcium_mg']} mg'
                      : 'Sin info',
                  customBadge: _buildCalciumBadge(result.nutrientesMap?['calcium_mg']),
                  isSub: false,
                ),
              ],
            ),
          ),


          // Alérgenos si los hay
          if (result.alergenosList.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '⚠️ Alérgenos:',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: result.alergenosList.map((a) {
                return Chip(
                  label: Text(a),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.orange.shade50,
                  labelStyle: TextStyle(color: Colors.orange.shade900, fontSize: 11),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 20),

          // Botones de acción rápida
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onScanNext,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Escanear otro'),
                ),
              ),
              if (onAddToList != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAddToList,
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: const Text('A la lista'),
                  ),
                ),
              ],
            ],
          ),
          if (onSaveToCatalog != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onSaveToCatalog,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar en mi Catálogo Maestro'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage(ColorScheme colorScheme) {
    return Container(
      width: 72,
      height: 72,
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.no_food_outlined, color: colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildNovaBadge(ThemeData theme) {
    final group = result.novaGroup;
    String label;
    Color color;

    switch (group) {
      case 1:
        label = 'Comida Real 🟢';
        color = const Color(0xFF2E7D32);
        break;
      case 2:
      case 3:
        label = 'Buen Procesado 🟡';
        color = const Color(0xFFF57F17);
        break;
      case 4:
        label = 'Ultraprocesado 🔴';
        color = const Color(0xFFC62828);
        break;
      default:
        label = 'Sin clasificar ⚪';
        color = Colors.grey.shade600;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildNutriscoreBadge(ThemeData theme) {
    final grade = result.nutriscoreGrade!.toLowerCase();
    Color bg;
    switch (grade) {
      case 'a': bg = const Color(0xFF038141); break;
      case 'b': bg = const Color(0xFF85BB2F); break;
      case 'c': bg = const Color(0xFFFECB02); break;
      case 'd': bg = const Color(0xFFEE8100); break;
      default:  bg = const Color(0xFFE63E11); break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Nutri-Score ${grade.toUpperCase()}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
      ),
    );
  }

  Widget? _buildIronBadge(dynamic rawIron) {
    if (rawIron == null) return null;
    final val = double.tryParse(rawIron.toString());
    if (val == null) return null;
    final vrn = ((val / 14.0) * 100).round();
    if (val >= 4.2) {
      return _buildMiniBadge('Alto 🌟 ($vrn% VRN)', Colors.purple.shade800, Colors.purple.shade50);
    } else if (val >= 2.1) {
      return _buildMiniBadge('Medio 🟢 ($vrn% VRN)', Colors.green.shade800, Colors.green.shade50);
    } else if (val >= 0.7) {
      return _buildMiniBadge('Moderado 🟡 ($vrn% VRN)', Colors.amber.shade900, Colors.amber.shade50);
    }
    return _buildMiniBadge('Bajo ⚪ ($vrn% VRN)', Colors.grey.shade700, Colors.grey.shade100);
  }

  Widget? _buildFiberBadge(dynamic rawFiber) {
    if (rawFiber == null) return null;
    final val = double.tryParse(rawFiber.toString());
    if (val == null) return null;
    if (val >= 6.0) {
      return _buildMiniBadge('Alto 🌾 (${val}g)', Colors.brown.shade800, Colors.amber.shade50);
    } else if (val >= 3.0) {
      return _buildMiniBadge('Medio 🟢 (${val}g)', Colors.green.shade800, Colors.green.shade50);
    } else if (val >= 1.5) {
      return _buildMiniBadge('Moderado 🟡 (${val}g)', Colors.amber.shade900, Colors.amber.shade50);
    }
    return _buildMiniBadge('Bajo ⚪ (${val}g)', Colors.grey.shade700, Colors.grey.shade100);
  }

  Widget? _buildCalciumBadge(dynamic rawCalcium) {
    if (rawCalcium == null) return null;
    final val = double.tryParse(rawCalcium.toString());
    if (val == null) return null;
    final vrn = ((val / 800.0) * 100).round();
    if (val >= 240) {
      return _buildMiniBadge('Alto 🦴 ($vrn% VRN)', Colors.blue.shade900, Colors.blue.shade50);
    } else if (val >= 120) {
      return _buildMiniBadge('Medio 🟢 ($vrn% VRN)', Colors.teal.shade800, Colors.teal.shade50);
    } else if (val >= 40) {
      return _buildMiniBadge('Moderado 🟡 ($vrn% VRN)', Colors.amber.shade900, Colors.amber.shade50);
    }
    return _buildMiniBadge('Bajo ⚪ ($vrn% VRN)', Colors.grey.shade700, Colors.grey.shade100);
  }


  Widget _buildMiniBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _buildMacroItem({
    required ThemeData theme,
    required String label,
    required String value,
    String? level,
    Widget? customBadge,
    required bool isSub,
  }) {
    Color? levelColor;
    String? levelText;


    if (level != null && level != 'unknown') {
      switch (level.toLowerCase()) {
        case 'low':
          levelColor = Colors.green.shade700;
          levelText = 'Bajo';
          break;
        case 'moderate':
          levelColor = Colors.orange.shade800;
          levelText = 'Medio';
          break;
        case 'high':
          levelColor = Colors.red.shade700;
          levelText = 'Alto';
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSub ? FontWeight.normal : FontWeight.w600,
                color: isSub ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                fontSize: isSub ? 13 : 14,
              ),
            ),
          ),
          Text(
            value,
            style: value == 'Sin info'
                ? theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.normal,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  )
                : theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
          ),
          if (customBadge != null) ...[
            const SizedBox(width: 8),
            customBadge,
          ] else if (levelText != null && levelColor != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: levelColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                levelText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: levelColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],

        ],
      ),
    );
  }
}
