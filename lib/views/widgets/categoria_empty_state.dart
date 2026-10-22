import 'package:flutter/material.dart';

/// Componente visual para estado vacío de categorías (HU24-RF02 Criterio 3)
class CategoriaEmptyState extends StatelessWidget {
  final VoidCallback onCrearCategoria;

  static const Color _primaryTerracotta = Color(0xFFB34A26);
  static const Color _primary = Color(0xFFE4572E);
  static const Color _cardBorder = Color(0xFFEDE4D8);
  static const Color _creamAccent = Color(0xFFF3ECE1);
  static const Color _textDark = Color(0xFF2E241E);
  static const Color _textMuted = Color(0xFF7A6E65);

  const CategoriaEmptyState({
    super.key,
    required this.onCrearCategoria,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Contenedor circular decorativo
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: _creamAccent.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _cardBorder,
                  width: 2,
                ),
              ),
              child: Center(
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDF1EB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.category_outlined,
                    size: 42,
                    color: _primaryTerracotta,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Título
            const Text(
              'Aún no hay categorías creadas',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textDark,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),

            // Mensaje explicativo
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: const Text(
                'Las categorías te permiten estructurar el menú de tu restaurante en secciones claras como Entradas, Platos Fuertes o Bebidas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: _textMuted,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Botón de acción directa
            ElevatedButton.icon(
              onPressed: onCrearCategoria,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: const Text('Crear primera categoría'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
