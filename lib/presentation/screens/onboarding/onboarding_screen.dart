import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

/// Professional onboarding.
/// - Desktop / wide web: photo panel on the left, aligned content column on the right.
/// - Phone / tablet: swipeable pages with a photo header.
/// Keyboard: ← / → to navigate, Enter for next.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Color get _primary => AppTheme.accentOrange; // brand colour
  static const Color _ink = Color(0xFF12201A);
  static const Color _muted = Color(0xFF66726B);
  static const Color _soft = Color(0xFF8A958E);
  static const Color _line = Color(0xFFE6EBE8);
  static const Color _panel = Color(0xFFF7FAF8);
  static const Color _deep = Color(0xFF0B2016);
  static const String _poweredBy = 'Infinitech Innovations Ltd';

  static const Duration _fast = Duration(milliseconds: 300);
  static const Curve _curve = Curves.easeOutCubic;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      category: 'Overview',
      tagline: 'From the farm gate to the final sale.',
      title: 'Welcome to\n${AppConstants.companyNameShort}',
      description:
          'Complete coffee business management, from farmers to sales, in one secure system.',
      icon: Icons.coffee,
      backgroundImage: 'assets/image1.jpg',
      features: [
        _Feature(Icons.swap_horiz, 'Farmers to sales'),
        _Feature(Icons.warehouse, 'Inventory & milling'),
        _Feature(Icons.bar_chart, 'Reports & analytics'),
      ],
    ),
    OnboardingPage(
      category: 'Farmers',
      tagline: 'Every farmer, every delivery, fully recorded.',
      title: 'Manage Farmers',
      description:
          'Register farmers, track deliveries, advances, and payments all in one place.',
      icon: Icons.people,
      backgroundImage: 'assets/image2.jpg',
      features: [
        _Feature(Icons.person_add_alt_1, 'Farmer registration'),
        _Feature(Icons.local_shipping_outlined, 'Delivery tracking'),
        _Feature(Icons.payments_outlined, 'Advances & payments'),
      ],
    ),
    OnboardingPage(
      category: 'Purchasing',
      tagline: 'Accurate buying, backed by instant receipts.',
      title: 'Coffee Buying',
      description:
          'Fast transaction entry with automatic calculations, quality deductions, and instant receipts.',
      icon: Icons.shopping_cart,
      backgroundImage: 'assets/image3.jpg',
      features: [
        _Feature(Icons.calculate_outlined, 'Automatic calculations'),
        _Feature(Icons.rule, 'Quality deductions'),
        _Feature(Icons.receipt_long_outlined, 'Instant receipts'),
      ],
    ),
    OnboardingPage(
      category: 'Inventory',
      tagline: 'Full visibility from storage to milling to sale.',
      title: 'Inventory & Milling',
      description:
          'Track coffee from purchase through milling, storage, and sales with full transparency.',
      icon: Icons.warehouse,
      backgroundImage: 'assets/image4.jpg',
      features: [
        _Feature(Icons.precision_manufacturing_outlined, 'Purchase to milling'),
        _Feature(Icons.inventory_2_outlined, 'Storage tracking'),
        _Feature(Icons.track_changes, 'Sales traceability'),
      ],
    ),
    OnboardingPage(
      category: 'Reporting',
      tagline: 'Decisions backed by real numbers.',
      title: 'Reports & Analytics',
      description:
          'Powerful reports and a live dashboard for complete business visibility.',
      icon: Icons.analytics,
      backgroundImage: 'assets/image1.jpg',
      features: [
        _Feature(Icons.dashboard_outlined, 'Dashboard overview'),
        _Feature(Icons.description_outlined, 'Detailed reports'),
        _Feature(Icons.insights, 'Business insights'),
      ],
    ),
  ];

  bool get _isLast => _currentPage == _pages.length - 1;
  bool get _isFirst => _currentPage == 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _completeOnboarding() {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _goTo(int i) {
    if (i == _currentPage) return;
    if (_pageController.hasClients) {
      _pageController.animateToPage(i, duration: _fast, curve: Curves.easeInOut);
    } else {
      setState(() => _currentPage = i);
    }
  }

  void _next() => _isLast ? _completeOnboarding() : _goTo(_currentPage + 1);
  void _back() {
    if (!_isFirst) _goTo(_currentPage - 1);
  }

  String _num(int i) => (i + 1).toString().padLeft(2, '0');
  String _total() => _pages.length.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _back,
        const SingleActivator(LogicalKeyboardKey.enter): _next,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: LayoutBuilder(
            builder: (context, c) =>
                c.maxWidth >= 900 ? _buildDesktop(c) : _buildMobile(c),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // DESKTOP
  // ===========================================================================
  Widget _buildDesktop(BoxConstraints c) {
    final page = _pages[_currentPage];
    final bool compact = c.maxHeight < 720;

    return Row(
      children: [
        // ---------------- Left: photo ----------------
        Expanded(
          flex: 11,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 700),
                    switchInCurve: Curves.easeInOut,
                    child: SizedBox.expand(
                      key: ValueKey<int>(_currentPage),
                      child: _image(page),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.30),
                          Colors.transparent,
                          _deep.withOpacity(0.55),
                          _deep.withOpacity(0.94),
                        ],
                        stops: const [0.0, 0.28, 0.68, 1.0],
                      ),
                    ),
                  ),
                  // category chip
                  Positioned(
                    top: 24,
                    left: 24,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: _glass(
                        key: ValueKey<int>(_currentPage),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(page.icon, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              page.category.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // counter chip
                  Positioned(
                    top: 24,
                    right: 24,
                    child: _glass(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      child: Text(
                        '${_num(_currentPage)} / ${_total()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                  // tagline (left aligned)
                  Positioned(
                    left: 44,
                    right: 44,
                    bottom: 44,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      transitionBuilder: _fadeSlide,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.bottomLeft,
                        children: [
                          ...previous,
                          if (current != null) current,
                        ],
                      ),
                      child: SizedBox(
                        key: ValueKey<int>(_currentPage),
                        width: double.infinity,
                        child: Text(
                          page.tagline,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 28 : 36,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ---------------- Right: content ----------------
        Expanded(
          flex: 10,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Column(
              children: [
                // header: brand (left) + skip (right) share the content edge
                Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Row(
                    children: [
                      _logo(38),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppConstants.companyNameShort,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _completeOnboarding,
                        style: TextButton.styleFrom(foregroundColor: _muted),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Skip',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // main content, left aligned to the same edge as the brand
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSize(
                              duration: _fast,
                              curve: _curve,
                              alignment: Alignment.topLeft,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                transitionBuilder: _fadeSlide,
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.topLeft,
                                  children: [
                                    ...previous,
                                    if (current != null) current,
                                  ],
                                ),
                                child: _desktopContent(page, compact),
                              ),
                            ),
                            SizedBox(height: compact ? 28 : 40),
                            _progressBar(),
                            const SizedBox(height: 20),
                            _controls(52),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // footer
                const Divider(color: _line, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: _footerText(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _desktopContent(OnboardingPage page, bool compact) {
    return Column(
      key: ValueKey<int>(_currentPage),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          page.category.toUpperCase(),
          style: TextStyle(
            color: _primary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          page.title,
          style: TextStyle(
            fontSize: compact ? 30 : 36,
            fontWeight: FontWeight.w800,
            color: _ink,
            height: 1.15,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          page.description,
          style: const TextStyle(
            fontSize: 16,
            color: _muted,
            height: 1.6,
          ),
        ),
        SizedBox(height: compact ? 22 : 30),
        _featureList(page),
      ],
    );
  }

  /// Single bordered card with divided rows
  Widget _featureList(OnboardingPage page) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          for (int i = 0; i < page.features.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: _line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _line),
                    ),
                    child: Icon(page.features[i].icon,
                        size: 18, color: _primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      page.features[i].label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                  Icon(Icons.check_circle_rounded,
                      size: 18, color: _primary.withOpacity(0.85)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Thin segmented progress with a step label
  Widget _progressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(_pages.length, (i) {
            final done = i <= _currentPage;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _goTo(i),
                child: Padding(
                  padding: EdgeInsets.only(
                      right: i == _pages.length - 1 ? 0 : 6, top: 6, bottom: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: _curve,
                    height: 4,
                    decoration: BoxDecoration(
                      color: done ? _primary : const Color(0xFFDDE3DF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          'Step ${_currentPage + 1} of ${_pages.length}',
          style: const TextStyle(
            fontSize: 12,
            color: _soft,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _fadeSlide(Widget child, Animation<double> anim) {
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: _curve)),
        child: child,
      ),
    );
  }

  // ===========================================================================
  // PHONE / TABLET
  // ===========================================================================
  Widget _buildMobile(BoxConstraints c) {
    final bool isTablet = c.maxWidth >= 600;
    final bool isShort = c.maxHeight < 700;

    // re-sync PageView if we just came from the desktop layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients &&
          (_pageController.page?.round() ?? 0) != _currentPage) {
        _pageController.jumpToPage(_currentPage);
      }
    });

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) => _mobilePage(
                  _pages[i],
                  isTablet: isTablet,
                  isShort: isShort,
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, isShort ? 8 : 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _DotIndicator(
                        count: _pages.length,
                        current: _currentPage,
                        color: _primary,
                        onTap: _goTo,
                      ),
                    ),
                    SizedBox(height: isShort ? 12 : 18),
                    _controls(isShort ? 48 : 54),
                    SizedBox(height: isShort ? 8 : 12),
                    _poweredByText(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobilePage(
    OnboardingPage page, {
    required bool isTablet,
    required bool isShort,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // photo header
        Expanded(
          flex: isShort ? 4 : 5,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _image(page),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                        _deep.withOpacity(0.78),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        _brandChip(),
                        const Spacer(),
                        TextButton(
                          onPressed: _completeOnboarding,
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.white),
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 22,
                  child: Text(
                    page.tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 24 : 19,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // text
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    page.category.toUpperCase(),
                    style: TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    page.title,
                    style: TextStyle(
                      fontSize: isTablet ? 30 : (isShort ? 22 : 26),
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      height: 1.2,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    page.description,
                    style: TextStyle(
                      fontSize: isTablet ? 17 : (isShort ? 14 : 15),
                      color: _muted,
                      height: 1.5,
                    ),
                  ),
                  if (!isShort) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: page.features
                          .map((f) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(f.icon, size: 14, color: _primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      f.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SHARED PIECES
  // ===========================================================================
  Widget _footerText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '© ${DateTime.now().year} ${AppConstants.companyNameShort}',
          style: const TextStyle(fontSize: 12, color: _soft),
        ),
        _poweredByText(),
      ],
    );
  }

  Widget _poweredByText() {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12, color: _soft),
        children: [
          const TextSpan(text: 'Powered by '),
          TextSpan(
            text: _poweredBy,
            style: TextStyle(color: _primary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Back (if not first) + Next / Get Started
  Widget _controls(double height) {
    return Row(
      children: [
        AnimatedSize(
          duration: _fast,
          curve: _curve,
          alignment: Alignment.centerLeft,
          child: _isFirst
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    height: height,
                    width: height,
                    child: OutlinedButton(
                      onPressed: _back,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _ink,
                        side: const BorderSide(color: _line, width: 1.5),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                ),
        ),
        Expanded(
          child: SizedBox(
            height: height,
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Row(
                  key: ValueKey<bool>(_isLast),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLast ? 'Get started' : 'Continue',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(_isLast ? Icons.login : Icons.arrow_forward,
                        size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _image(OnboardingPage page) {
    return Image.asset(
      page.backgroundImage,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primary.withOpacity(0.7), _deep],
            ),
          ),
          child: Icon(page.icon, size: 80, color: Colors.white24),
        );
      },
    );
  }

  Widget _brandChip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _logo(30),
          const SizedBox(width: 10),
          Text(
            AppConstants.companyNameShort,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _line),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/logo.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.coffee, size: size * 0.55, color: _primary),
        ),
      ),
    );
  }

  /// Semi-transparent dark "glass" container used on top of photos
  Widget _glass({Key? key, required Widget child, required EdgeInsets padding}) {
    return Container(
      key: key,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.36),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: child,
    );
  }
}

/// Animated pill-style page indicator (mobile)
class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;
  final Color color;
  final ValueChanged<int> onTap;

  const _DotIndicator({
    required this.count,
    required this.current,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == current;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(i),
          child: Padding(
            padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: active ? 32 : 8,
              height: 6,
              decoration: BoxDecoration(
                color: active ? color : const Color(0xFFD5DBD7),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _Feature {
  final IconData icon;
  final String label;
  const _Feature(this.icon, this.label);
}

class OnboardingPage {
  final String category;
  final String tagline;
  final String title;
  final String description;
  final IconData icon;
  final String backgroundImage;
  final List<_Feature> features;

  OnboardingPage({
    required this.category,
    required this.tagline,
    required this.title,
    required this.description,
    required this.icon,
    required this.backgroundImage,
    required this.features,
  });
}