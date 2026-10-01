import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ClientHomePage extends StatelessWidget {
  const ClientHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // HEADER
          Container(
            color: AppColors.primary,
            child: Column(
              children: [
                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bonjour',
                                  style: TextStyle(
                                    color: Color(0xFFD7E3F7),
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Yassine Trabelsi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          _HeaderIcon(icon: Icons.notifications_none),
                          const SizedBox(width: 4),
                          _HeaderIcon(icon: Icons.person_outline),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // SEARCH
                      Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.search,
                              size: 20,
                              color: Color(0xFF74777F),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Ville, quartier, type de bien…',
                              style: TextStyle(
                                color: Color(0xFF74777F),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CONTENT
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NEW MATCH
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7E8C9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: AppColors.gold,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nouveau bien pour vous',
                                style: TextStyle(
                                  color: Color(0xFF4A3200),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Appart. S+3 · Lac · 94 % compatible',
                                style: TextStyle(
                                  color: Color(0xFF4A3200),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF4A3200),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // FILTER CHIPS
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(label: 'Tous', selected: true),
                        _FilterChip(label: 'Appartement'),
                        _FilterChip(label: 'Villa'),
                        _FilterChip(label: 'Vente'),
                        _FilterChip(label: 'Location'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // TITLE
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pour vous',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1C1E),
                        ),
                      ),
                      Text(
                        'Tout voir',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Selon vos critères : achat · 300–500K TND · Tunis · 2+ chambres',
                    style: TextStyle(fontSize: 12, color: Color(0xFF74777F)),
                  ),

                  const SizedBox(height: 12),

                  // PROPERTY 1
                  const _PropertyCard(
                    title: 'Appartement S+3 · Lac',
                    location: 'Les Berges du Lac, Tunis',
                    price: '485 000 TND',
                    rooms: '3',
                    bathrooms: '2',
                    surface: '145 m²',
                    match: '94%',
                  ),

                  const SizedBox(height: 12),

                  // PROPERTY 2
                  const _PropertyCard(
                    title: 'Appartement S+2 · Ariana',
                    location: 'Ennasr, Ariana',
                    price: '320 000 TND',
                    rooms: '2',
                    bathrooms: '1',
                    surface: '110 m²',
                    match: '89%',
                  ),

                  const SizedBox(height: 12),

                  // PROPERTY 3
                  const _PropertyCard(
                    title: 'Villa · La Marsa',
                    location: 'Gammarth, Tunis',
                    price: '1 800 TND',
                    priceSuffix: '/mois',
                    rooms: '4',
                    bathrooms: '2',
                    surface: '220 m²',
                    match: '86%',
                  ),
                ],
              ),
            ),
          ),

          // BOTTOM NAVIGATION
          const _ClientBottomNavigation(),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// HEADER ICON
// ------------------------------------------------------------

class _HeaderIcon extends StatelessWidget {
  final IconData icon;

  const _HeaderIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

// ------------------------------------------------------------
// FILTER CHIP
// ------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _FilterChip({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFD7E3F7) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: selected
            ? null
            : Border.all(color: const Color(0xFFD0D3DB), width: 1.3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? const Color(0xFF0D2949) : const Color(0xFF43474E),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// PROPERTY CARD
// ------------------------------------------------------------

class _PropertyCard extends StatelessWidget {
  final String title;
  final String location;
  final String price;
  final String? priceSuffix;
  final String rooms;
  final String bathrooms;
  final String surface;
  final String match;

  const _PropertyCard({
    required this.title,
    required this.location,
    required this.price,
    this.priceSuffix,
    required this.rooms,
    required this.bathrooms,
    required this.surface,
    required this.match,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E4EA)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PHOTO
          SizedBox(
            height: 150,
            width: double.infinity,
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF5B7FB0), Color(0xFF2F4F7A)],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.apartment,
                      color: Colors.white30,
                      size: 51,
                    ),
                  ),
                ),

                // AVAILABLE
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7F0D8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 6,
                          height: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Disponible',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // MATCH
                Positioned(
                  top: 6,
                  right: 48,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 3),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      match,
                      style: const TextStyle(
                        color: Color(0xFF9C6A0B),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // FAVORITE
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border,
                      size: 18,
                      color: Color(0xFF43474E),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // INFO
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1C1E),
                  ),
                ),

                const SizedBox(height: 4),

                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Color(0xFF74777F),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF74777F),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9C6A0B),
                      ),
                    ),
                    if (priceSuffix != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        priceSuffix!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF74777F),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    _PropertyStat(icon: Icons.bed_outlined, value: rooms),
                    const SizedBox(width: 12),
                    _PropertyStat(
                      icon: Icons.bathtub_outlined,
                      value: bathrooms,
                    ),
                    const SizedBox(width: 12),
                    _PropertyStat(
                      icon: Icons.square_foot_outlined,
                      value: surface,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyStat extends StatelessWidget {
  final IconData icon;
  final String value;

  const _PropertyStat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF43474E)),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF43474E),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// BOTTOM NAVIGATION
// ------------------------------------------------------------

class _ClientBottomNavigation extends StatelessWidget {
  const _ClientBottomNavigation();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 67,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E4EA))),
      ),
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: const Row(
        children: [
          _NavItem(icon: Icons.home, label: 'Accueil', selected: true),
          _NavItem(icon: Icons.search, label: 'Recherche'),
          _NavItem(icon: Icons.favorite_border, label: 'Favoris'),
          _NavItem(icon: Icons.calendar_today_outlined, label: 'Mes visites'),
          _NavItem(icon: Icons.chat_bubble_outline, label: 'Assistant'),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFD7E3F7) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              size: 22,
              color: selected ? AppColors.primary : const Color(0xFF74777F),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? AppColors.primary : const Color(0xFF74777F),
            ),
          ),
        ],
      ),
    );
  }
}
