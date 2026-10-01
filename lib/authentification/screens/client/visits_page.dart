import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VisitsPage extends StatefulWidget {
  const VisitsPage({super.key});

  @override
  State<VisitsPage> createState() => _VisitsPageState();
}

class _VisitsPageState extends State<VisitsPage> {
  int _selectedTab = 0;
  int _selectedNavIndex = 3;

  static const Color navy = Color(0xFF194073);
  static const Color background = Color(0xFFF2F2F2);
  static const Color white = Colors.white;

  static const Color textPrimary = Color(0xFF1A1C1E);
  static const Color textSecondary = Color(0xFF43474E);
  static const Color textTertiary = Color(0xFF74777F);

  static const Color border = Color(0xFFE2E4EA);
  static const Color borderStrong = Color(0xFFD0D3DB);

  static const Color infoBackground = Color(0xFFD7E6FB);
  static const Color infoText = Color(0xFF1565C0);

  static const Color warningBackground = Color(0xFFFFE9C2);
  static const Color warningText = Color(0xFFA86A00);

  static const Color successBackground = Color(0xFFD7F0D8);
  static const Color successText = Color(0xFF2E7D32);

  static const Color errorBackground = Color(0xFFF9DEDC);
  static const Color errorText = Color(0xFFB3261E);

  final List<_Visit> upcomingVisits = const [
    _Visit(
      title: 'Appart. S+3 · Lac',
      date: 'Mar 30 sept. · 10:00',
      status: 'Confirmée',
      statusType: _VisitStatus.confirmed,
      icon: Icons.calendar_today_outlined,
    ),
    _Visit(
      title: 'Appart. S+2 · Ariana',
      date: 'Jeu 2 oct. · 15:00 · en attente',
      status: 'Demandée',
      statusType: _VisitStatus.requested,
      icon: Icons.access_time,
    ),
  ];

  final List<_Visit> pastVisits = const [
    _Visit(
      title: 'Duplex · Carthage',
      date: '20 sept. · à noter',
      status: 'Effectuée',
      statusType: _VisitStatus.completed,
      icon: Icons.check,
    ),
    _Visit(
      title: 'Bureau · CUN',
      date: '15 sept. · annulée par l’agence',
      status: 'Annulée',
      statusType: _VisitStatus.cancelled,
      icon: Icons.close,
    ),
    _Visit(
      title: 'Studio · Menzah',
      date: '12 sept. · vous étiez absent',
      status: 'Absent',
      statusType: _VisitStatus.neutral,
      icon: Icons.person_outline,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: navy,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopArea(),
              Expanded(child: _buildBody()),
              _buildBottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TOP AREA
  // ---------------------------------------------------------------------------

  Widget _buildTopArea() {
    return Container(
      color: navy,
      child: Column(
        children: [
          // Figma status bar: 32px
          SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '9:41',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: white,
                    ),
                  ),
                  Row(
                    children: const [
                      Icon(Icons.signal_cellular_alt, size: 15, color: white),
                      SizedBox(width: 5),
                      Icon(Icons.wifi, size: 15, color: white),
                      SizedBox(width: 5),
                      Icon(Icons.battery_full, size: 15, color: white),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Figma top app bar: 56px
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const SizedBox(width: 8),

                  const Expanded(
                    child: Text(
                      'Mes visites',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 24 / 17,
                        color: white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BODY
  // ---------------------------------------------------------------------------

  Widget _buildBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSegmentedButton(),

            const SizedBox(height: 10),

            _buildUpcomingList(),

            const SizedBox(height: 10),

            const Text(
              'Passées',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 20 / 15,
                color: textPrimary,
              ),
            ),

            const SizedBox(height: 10),

            _buildPastList(),

            const SizedBox(height: 10),

            _buildReminderNote(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEGMENTED BUTTON
  // ---------------------------------------------------------------------------

  Widget _buildSegmentedButton() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        border: Border.all(color: borderStrong, width: 1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(child: _buildSegment(label: 'À venir · 2', index: 0)),
          Expanded(child: _buildSegment(label: 'Passées · 3', index: 1)),
        ],
      ),
    );
  }

  Widget _buildSegment({required String label, required int index}) {
    final bool selected = _selectedTab == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? navy : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 18 / 13,
            color: selected ? white : textSecondary,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UPCOMING LIST
  // ---------------------------------------------------------------------------

  Widget _buildUpcomingList() {
    return _buildVisitList(visits: upcomingVisits);
  }

  // ---------------------------------------------------------------------------
  // PAST LIST
  // ---------------------------------------------------------------------------

  Widget _buildPastList() {
    return _buildVisitList(visits: pastVisits);
  }

  Widget _buildVisitList({required List<_Visit> visits}) {
    return Container(
      decoration: BoxDecoration(
        color: white,
        border: Border.all(color: border, width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < visits.length; i++)
            _buildVisitItem(visit: visits[i], isLast: i == visits.length - 1),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VISIT ITEM
  // ---------------------------------------------------------------------------

  Widget _buildVisitItem({required _Visit visit, required bool isLast}) {
    final _StatusStyle statusStyle = _getStatusStyle(visit.statusType);

    return InkWell(
      onTap: () {
        // TODO:
        // Navigate to visit detail page.
        //
        // Example:
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (_) => VisitDetailPage(visit: visit),
        //   ),
        // );
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 65),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: border, width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar / icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusStyle.backgroundColor,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Icon(visit.icon, size: 20, color: statusStyle.iconColor),
            ),

            const SizedBox(width: 13),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 20 / 14,
                      color: textPrimary,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    visit.date,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 16 / 12,
                      color: textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Status badge
            _buildStatusBadge(label: visit.status, style: statusStyle),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATUS BADGE
  // ---------------------------------------------------------------------------

  Widget _buildStatusBadge({
    required String label,
    required _StatusStyle style,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: style.dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 14 / 11.5,
              color: style.textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REMINDER NOTE
  // ---------------------------------------------------------------------------

  Widget _buildReminderNote() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.notifications_none_outlined,
            size: 18,
            color: textSecondary,
          ),

          const SizedBox(width: 9),

          const Expanded(
            child: Text(
              'Rappel automatique 24 h avant chaque visite '
              '(notification locale).',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 18 / 12,
                color: textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOTTOM NAVIGATION
  // ---------------------------------------------------------------------------

  Widget _buildBottomNavigation() {
    return Container(
      height: 67,
      decoration: const BoxDecoration(
        color: white,
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
      child: Row(
        children: [
          _buildNavItem(
            index: 0,
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Accueil',
          ),
          _buildNavItem(
            index: 1,
            icon: Icons.search_outlined,
            activeIcon: Icons.search,
            label: 'Recherche',
          ),
          _buildNavItem(
            index: 2,
            icon: Icons.favorite_border,
            activeIcon: Icons.favorite,
            label: 'Favoris',
          ),
          _buildNavItem(
            index: 3,
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month,
            label: 'Visites',
          ),
          _buildNavItem(
            index: 4,
            icon: Icons.smart_toy_outlined,
            activeIcon: Icons.smart_toy,
            label: 'Assistant',
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool selected = _selectedNavIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedNavIndex = index;
          });

          // TODO:
          // Add your navigation logic here.
          //
          // Example:
          //
          // switch (index) {
          //   case 0:
          //     Navigator.pushReplacement(...);
          //     break;
          //   case 1:
          //     Navigator.pushReplacement(...);
          //     break;
          //   case 2:
          //     Navigator.pushReplacement(...);
          //     break;
          //   case 3:
          //     break;
          //   case 4:
          //     Navigator.pushReplacement(...);
          //     break;
          // }
        },
        child: SizedBox(
          height: 67,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? activeIcon : icon,
                size: 21,
                color: selected ? navy : textTertiary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? navy : textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATUS STYLE
  // ---------------------------------------------------------------------------

  _StatusStyle _getStatusStyle(_VisitStatus status) {
    switch (status) {
      case _VisitStatus.confirmed:
        return const _StatusStyle(
          backgroundColor: infoBackground,
          textColor: infoText,
          iconColor: infoText,
          dotColor: infoText,
        );

      case _VisitStatus.requested:
        return const _StatusStyle(
          backgroundColor: warningBackground,
          textColor: warningText,
          iconColor: warningText,
          dotColor: warningText,
        );

      case _VisitStatus.completed:
        return const _StatusStyle(
          backgroundColor: successBackground,
          textColor: successText,
          iconColor: successText,
          dotColor: successText,
        );

      case _VisitStatus.cancelled:
        return const _StatusStyle(
          backgroundColor: errorBackground,
          textColor: errorText,
          iconColor: errorText,
          dotColor: errorText,
        );

      case _VisitStatus.neutral:
        return const _StatusStyle(
          backgroundColor: border,
          textColor: textSecondary,
          iconColor: textSecondary,
          dotColor: textSecondary,
        );
    }
  }
}

// -----------------------------------------------------------------------------
// MODELS
// -----------------------------------------------------------------------------

enum _VisitStatus { confirmed, requested, completed, cancelled, neutral }

class _Visit {
  final String title;
  final String date;
  final String status;
  final _VisitStatus statusType;
  final IconData icon;

  const _Visit({
    required this.title,
    required this.date,
    required this.status,
    required this.statusType,
    required this.icon,
  });
}

class _StatusStyle {
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final Color dotColor;

  const _StatusStyle({
    required this.backgroundColor,
    required this.textColor,
    required this.iconColor,
    required this.dotColor,
  });
}
