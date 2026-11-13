import 'dart:ui' show Color;

/// Dónde se lleva cada objeto. Solo uno por hueco.
enum PetSlot {
  head('Cabeza'),
  face('Cara'),
  neck('Cuello'),
  body('Ropa'),
  hand('Objeto'),
  color('Color');

  const PetSlot(this.label);
  final String label;
}

class PetItem {
  const PetItem({
    required this.id,
    required this.name,
    required this.slot,
    required this.price,
    this.minLevel = 1,
    this.colors,
    this.prize = false,
  });

  final String id;
  final String name;
  final PetSlot slot;
  final int price;
  final int minLevel;

  /// Solo para [PetSlot.color]: degradado del cuerpo (arriba, abajo).
  final (Color, Color)? colors;

  /// No se compra: se gana completando todos los retos de una semana.
  final bool prize;
}

const defaultColorId = 'lavanda';

/// Catálogo de la tienda. Los dibujos están en pet_avatar.dart.
const petItems = <PetItem>[
  // Cabeza
  PetItem(id: 'cinta', name: 'Cinta deportiva', slot: PetSlot.head, price: 40),
  PetItem(id: 'lazo', name: 'Lazo', slot: PetSlot.head, price: 80),
  PetItem(id: 'flor', name: 'Flor', slot: PetSlot.head, price: 100),
  PetItem(id: 'gorra', name: 'Gorra', slot: PetSlot.head, price: 120),
  PetItem(id: 'gorro_lana', name: 'Gorro de lana', slot: PetSlot.head, price: 150, minLevel: 2),
  PetItem(id: 'auriculares', name: 'Auriculares', slot: PetSlot.head, price: 200, minLevel: 3),
  PetItem(id: 'corona', name: 'Corona', slot: PetSlot.head, price: 400, minLevel: 5),
  PetItem(id: 'tiara_estrellas', name: 'Tiara de estrellas', slot: PetSlot.head, price: 0, prize: true),
  PetItem(id: 'orejas_gato', name: 'Orejitas de gato', slot: PetSlot.head, price: 110),
  PetItem(id: 'fiesta', name: 'Gorro de fiesta', slot: PetSlot.head, price: 90),
  PetItem(id: 'sombrero', name: 'Sombrero de playa', slot: PetSlot.head, price: 170, minLevel: 2),
  PetItem(id: 'corona_flores', name: 'Corona de flores', slot: PetSlot.head, price: 220, minLevel: 3),
  // Cara
  PetItem(id: 'gafas', name: 'Gafas redondas', slot: PetSlot.face, price: 120),
  PetItem(id: 'gafas_sol', name: 'Gafas de sol', slot: PetSlot.face, price: 160, minLevel: 2),
  PetItem(id: 'gafas_corazon', name: 'Gafas de corazón', slot: PetSlot.face, price: 0, prize: true),
  PetItem(id: 'corazones', name: 'Mejillas de corazón', slot: PetSlot.face, price: 80),
  PetItem(id: 'gafas_natacion', name: 'Gafas de natación', slot: PetSlot.face, price: 140, minLevel: 2),
  // Cuello
  PetItem(id: 'pajarita', name: 'Pajarita', slot: PetSlot.neck, price: 90),
  PetItem(id: 'collar', name: 'Collar de perlas', slot: PetSlot.neck, price: 180, minLevel: 2),
  PetItem(id: 'bufanda', name: 'Bufanda', slot: PetSlot.neck, price: 140),
  PetItem(id: 'medalla', name: 'Medalla', slot: PetSlot.neck, price: 250, minLevel: 3),
  PetItem(id: 'banda_campeona', name: 'Banda de campeona', slot: PetSlot.neck, price: 0, prize: true),
  PetItem(id: 'silbato', name: 'Silbato de coach', slot: PetSlot.neck, price: 100),
  PetItem(id: 'hawaiano', name: 'Collar hawaiano', slot: PetSlot.neck, price: 160, minLevel: 2),
  // Ropa
  PetItem(id: 'top', name: 'Top deportivo', slot: PetSlot.body, price: 100),
  PetItem(id: 'camiseta', name: 'Camiseta del equipo', slot: PetSlot.body, price: 130),
  PetItem(id: 'sudadera', name: 'Sudadera', slot: PetSlot.body, price: 180),
  PetItem(id: 'tutu', name: 'Tutú', slot: PetSlot.body, price: 160, minLevel: 2),
  PetItem(id: 'pijama', name: 'Pijama de estrellas', slot: PetSlot.body, price: 200, minLevel: 3),
  PetItem(id: 'capa', name: 'Capa de heroína', slot: PetSlot.body, price: 320, minLevel: 4),
  PetItem(id: 'chaqueta_dorada', name: 'Chaqueta dorada', slot: PetSlot.body, price: 0, prize: true),
  // Objetos
  PetItem(id: 'mancuerna', name: 'Mancuerna', slot: PetSlot.hand, price: 90),
  PetItem(id: 'botella', name: 'Botella de agua', slot: PetSlot.hand, price: 70),
  PetItem(id: 'pesa_rusa', name: 'Pesa rusa', slot: PetSlot.hand, price: 150, minLevel: 2),
  PetItem(id: 'esterilla', name: 'Esterilla', slot: PetSlot.hand, price: 120),
  PetItem(id: 'globo', name: 'Globo de corazón', slot: PetSlot.hand, price: 140, minLevel: 2),
  PetItem(id: 'trofeo', name: 'Trofeo', slot: PetSlot.hand, price: 350, minLevel: 5),
  PetItem(id: 'pompones', name: 'Pompones', slot: PetSlot.hand, price: 0, prize: true),
  // Color
  PetItem(
    id: defaultColorId,
    name: 'Lavanda',
    slot: PetSlot.color,
    price: 0,
    colors: (Color(0xFFDCCBFA), Color(0xFFB79CE6)),
  ),
  PetItem(id: 'menta', name: 'Menta', slot: PetSlot.color, price: 150, colors: (Color(0xFFCFF3EA), Color(0xFF8ED6C4))),
  PetItem(
    id: 'melocoton',
    name: 'Melocotón',
    slot: PetSlot.color,
    price: 150,
    colors: (Color(0xFFFFE0CC), Color(0xFFF7B48E)),
  ),
  PetItem(id: 'rosa', name: 'Rosa', slot: PetSlot.color, price: 150, colors: (Color(0xFFFCD9E8), Color(0xFFF2A5C6))),
  PetItem(id: 'limon', name: 'Limón', slot: PetSlot.color, price: 150, colors: (Color(0xFFFFF5C2), Color(0xFFF2D46B))),
  PetItem(id: 'coral', name: 'Coral', slot: PetSlot.color, price: 180, colors: (Color(0xFFFFD3C9), Color(0xFFF28C7A))),
  PetItem(
    id: 'arcoiris',
    name: 'Arcoíris',
    slot: PetSlot.color,
    price: 0,
    prize: true,
    colors: (Color(0xFFFFE08A), Color(0xFFF59AC4)),
  ),
  PetItem(
    id: 'aurora',
    name: 'Aurora',
    slot: PetSlot.color,
    price: 350,
    minLevel: 4,
    colors: (Color(0xFFFFD1EC), Color(0xFF9CC9F5)),
  ),
  PetItem(
    id: 'cielo',
    name: 'Cielo',
    slot: PetSlot.color,
    price: 200,
    minLevel: 2,
    colors: (Color(0xFFD5E8FF), Color(0xFF94BDF2)),
  ),
  PetItem(
    id: 'galaxia',
    name: 'Galaxia',
    slot: PetSlot.color,
    price: 500,
    minLevel: 6,
    colors: (Color(0xFF8E6BD8), Color(0xFF3B2A6E)),
  ),
];

PetItem? petItemById(String? id) {
  if (id == null) return null;
  for (final i in petItems) {
    if (i.id == id) return i;
  }
  return null;
}

/// Lo que lleva puesto la mascota (lo usa el dibujo).
class PetLook {
  const PetLook({this.head, this.face, this.neck, this.body, this.hand, this.colorId = defaultColorId});
  final String? head;
  final String? face;
  final String? neck;
  final String? body;
  final String? hand;
  final String colorId;

  (Color, Color) get bodyColors => petItemById(colorId)?.colors ?? petItemById(defaultColorId)!.colors!;

  @override
  bool operator ==(Object other) =>
      other is PetLook &&
      other.head == head &&
      other.face == face &&
      other.neck == neck &&
      other.body == body &&
      other.hand == hand &&
      other.colorId == colorId;

  @override
  int get hashCode => Object.hash(head, face, neck, body, hand, colorId);

  /// Igual, pero con [itemId] en [slot].
  PetLook wearing(PetSlot slot, String itemId) => PetLook(
        head: slot == PetSlot.head ? itemId : head,
        face: slot == PetSlot.face ? itemId : face,
        neck: slot == PetSlot.neck ? itemId : neck,
        body: slot == PetSlot.body ? itemId : body,
        hand: slot == PetSlot.hand ? itemId : hand,
        colorId: slot == PetSlot.color ? itemId : colorId,
      );
}
