import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';

const String kBaseBlogUrl = 'https://anataleb-eg.blogspot.com';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FaniProApp());
}

class FaniProApp extends StatelessWidget {
  const FaniProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تطبيق فني برو',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.cairoTextTheme(),
      ),
      home: const MainHomeScreen(),
    );
  }
}

enum AppStage { diploma, naql, institutes }

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  AppStage _currentStage = AppStage.diploma;
  bool _isSalawatMode = false;
  Timer? _tickerTimer;
  Timer? _mascotTimer;

  // حالة المرشد الصوتي
  final FlutterTts _flutterTts = FlutterTts();
  bool _showMascotToast = false;
  String _mascotTitle = '';
  String _mascotSpeech = '';

  // تخزين عدادات المشاهدات
  Map<String, int> _viewsMap = {};

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadSavedStageAndViews();
    _startSalawatRotation();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('ar-EG');
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _loadSavedStageAndViews() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStage = prefs.getString('fanni_stage_v6');

    if (savedStage == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showStageOnboardingDialog());
    } else {
      setState(() {
        _currentStage = AppStage.values.firstWhere(
          (e) => e.name == savedStage,
          orElse: () => AppStage.diploma,
        );
      });
    }

    // تحميل العدادات
    final keys = prefs.getKeys();
    final loadedViews = <String, int>{};
    for (var k in keys) {
      if (k.startsWith('view_')) {
        loadedViews[k] = prefs.getInt(k) ?? 0;
      }
    }
    setState(() => _viewsMap = loadedViews);
  }

  Future<void> _selectStage(AppStage stage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fanni_stage_v6', stage.name);
    setState(() => _currentStage = stage);
  }

  void _startSalawatRotation() {
    _tickerTimer = Timer.periodic(const Duration(seconds: 18), (timer) {
      if (_currentStage != AppStage.institutes && mounted) {
        setState(() => _isSalawatMode = true);
        Future.delayed(const Duration(seconds: 6), () {
          if (mounted) setState(() => _isSalawatMode = false);
        });
      }
    });
  }

  // ألوان كل مرحلة
  Color get _primaryColor {
    switch (_currentStage) {
      case AppStage.diploma:
        return const Color(0xFF6366F1);
      case AppStage.naql:
        return const Color(0xFF059669);
      case AppStage.institutes:
        return const Color(0xFF0284C7);
    }
  }

  Color get _primaryDarkColor {
    switch (_currentStage) {
      case AppStage.diploma:
        return const Color(0xFF4338CA);
      case AppStage.naql:
        return const Color(0xFF065F46);
      case AppStage.institutes:
        return const Color(0xFF0369A1);
    }
  }

  String get _stageBadgeText {
    switch (_currentStage) {
      case AppStage.diploma:
        return 'الدبلومات';
      case AppStage.naql:
        return 'صفوف النقل';
      case AppStage.institutes:
        return 'معاهد وكليات';
    }
  }

  String get _stageSubtitleText {
    switch (_currentStage) {
      case AppStage.diploma:
        return 'الصف الثالث • الصف الخامس';
      case AppStage.naql:
        return 'نقل 3 سنوات ونقل 5 سنوات';
      case AppStage.institutes:
        return 'أدوات السكاشن والمحاضرات';
    }
  }

  Future<void> _incrementAndOpen(String viewId, int baseViews, String title, String url, {bool requireTeacherConfirm = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (_viewsMap[viewId] ?? baseViews) + 1;
    await prefs.setInt(viewId, current);
    setState(() => _viewsMap[viewId] = current);

    if (requireTeacherConfirm) {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Text('تنبيه هام قبل الدخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'هذا القسم مخصص للمدرسين والمعلنين فقط 👨‍🏫\nهل تود الاستمرار والدخول إلى القسم؟',
              style: TextStyle(fontSize: 13.5, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('خروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('استمرار', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
      if (confirm != true) return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlogWebViewScreen(title: title, url: url, themeColor: _primaryDarkColor),
      ),
    );
  }

  String _formatViews(String viewId, int baseViews) {
    final val = _viewsMap[viewId] ?? baseViews;
    return val >= 1000 ? '${(val / 1000).toStringAsFixed(1)}K' : '$val';
  }

  Future<void> _activateMascot(String title, String speech) async {
    _mascotTimer?.cancel();
    await _flutterTts.stop();
    setState(() {
      _mascotTitle = 'مرشد فني برو • $title';
      _mascotSpeech = speech;
      _showMascotToast = true;
    });
    await _flutterTts.speak(speech);
    _mascotTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _showMascotToast = false);
    });
  }

  Future<void> _closeMascot() async {
    _mascotTimer?.cancel();
    await _flutterTts.stop();
    setState(() => _showMascotToast = false);
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _mascotTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        drawer: _buildSideDrawer(),
        body: Stack(
          children: [
            Column(
              children: [
                _buildFixedHeader(),
                if (_currentStage != AppStage.institutes) _buildNewsTicker(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 95),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_currentStage == AppStage.diploma) ..._buildDiplomaStageContent(),
                        if (_currentStage == AppStage.naql) ..._buildNaqlStageContent(),
                        if (_currentStage == AppStage.institutes) ..._buildInstitutesStageContent(),

                        // قسم المدرسين والمعلنين (للدبلومات وصفوف النقل)
                        if (_currentStage != AppStage.institutes) ...[
                          const SizedBox(height: 16),
                          _buildSectionHead(
                            title: 'المدرس المعتمد والمعلنين',
                            icon: Icons.co_present_rounded,
                            gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                            speech: 'هذا القسم مخصص للمدرسين الراغبين في نشر شروحاتهم ومذكراتهم مجاناً، ولأصحاب السناتر والمكتبات للإعلان على التطبيق.',
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildProCard(
                                  title: 'انضم إلينا كمدرس معتمد 👨‍🏫',
                                  tag: 'للمدرسين فقط',
                                  tagColor: const Color(0xFFD97706),
                                  bannerGradient: const [Color(0xFFD97706), Color(0xFFB45309)],
                                  bannerIcon: Icons.person_add_alt_1_rounded,
                                  viewsText: 'انشر مجاناً',
                                  actionText: 'دخول',
                                  actionColor: const Color(0xFFD97706),
                                  isDashedBorder: true,
                                  onTap: () => _incrementAndOpen(
                                    'view_teacher_join_v2',
                                    1200,
                                    'المدرس المعتمد',
                                    '$kBaseBlogUrl/search/label/المدرسين',
                                    requireTeacherConfirm: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildProCard(
                                  title: 'أعلن على تطبيقنا الآن',
                                  tag: 'للمعلنين',
                                  tagColor: const Color(0xFF4F46E5),
                                  bannerGradient: const [Color(0xFF4F46E5), Color(0xFF3730A3)],
                                  bannerIcon: Icons.campaign_rounded,
                                  viewsText: 'عروض مميزة',
                                  actionText: 'التفاصيل',
                                  actionColor: const Color(0xFF4F46E5),
                                  onTap: () => _incrementAndOpen(
                                    'view_ads_app_v2',
                                    980,
                                    'أعلن معنا',
                                    '$kBaseBlogUrl/search/label/الاعلانات',
                                    requireTeacherConfirm: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // خدمات الوزارة + شات الطلاب (للدبلومات فقط)
                        if (_currentStage == AppStage.diploma) ...[
                          const SizedBox(height: 16),
                          _buildSectionHead(
                            title: 'خدمات الوزارة للطلاب 2027',
                            icon: Icons.account_balance_rounded,
                            gradient: [ _primaryColor, _primaryDarkColor ],
                            speech: 'هنا البوابة الرسمية لوزارة التربية والتعليم المصرية لمتابعة القرارات الرسمية والاستمارات والخدمات الوزارية مباشرة.',
                          ),
                          const SizedBox(height: 8),
                          _buildMinistryBanner(),

                          const SizedBox(height: 16),
                          _buildSectionHead(
                            title: 'شات الطلاب المباشر',
                            icon: Icons.forum_rounded,
                            gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                            speech: 'هنا مجتمع طلاب التعليم الفني! تقدر تسأل زمايلك في أي مادة أو ملخص وتتبادلوا الخبرات والمساعدة الفورية.',
                          ),
                          const SizedBox(height: 8),
                          _buildStudentChatCard(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // نافذة المرشد الصوتي المنبثقة
            if (_showMascotToast)
              Positioned(
                bottom: 86,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF312E81)]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFBBF24), width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFF59E0B),
                        child: Text('👨‍🎓', style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _mascotTitle,
                              style: const TextStyle(color: Color(0xFFFDE047), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _mascotSpeech,
                              style: const TextStyle(color: Colors.white, fontSize: 11.5, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        onPressed: _closeMascot,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),

            // شريط التنقل السفلي العائم مع زر شنطة الأدوات
            Positioned(
              bottom: 10,
              left: 12,
              right: 12,
              child: _buildFloatingBottomNav(),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 1. الهيدر العلوي =================
  Widget _buildFixedHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        bottom: 8,
        left: 10,
        right: 10,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryDarkColor, _primaryColor],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => _headerIconBtn(Icons.menu_rounded, () => Scaffold.of(ctx).openDrawer()),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                'https://i.ibb.co/Jw1QZDcF/Picsart-26-11-22-15-43-13-999.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text('ف', style: TextStyle(color: _primaryDarkColor, fontWeight: FontWeight.w900, fontSize: 18)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تطبيق فني برو',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, height: 1.15),
                ),
                Text(
                  _stageSubtitleText,
                  style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: 10, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _showStageOnboardingDialog,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.white54),
              ),
              child: Row(
                children: [
                  const Icon(Icons.repeat_rounded, color: Colors.white, size: 13),
                  const SizedBox(width: 4),
                  Text(_stageBadgeText, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          _headerIconBtn(Icons.notifications_rounded, () {
            _showSimpleMessage('إشعارات فني برو', 'أهلاً بك في النسخة التجريبية الأصلية المربوطة بمدونة أنا طالب!');
          }),
        ],
      ),
    );
  }

  Widget _headerIconBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  // ================= 2. الشريط المتحرك =================
  Widget _buildNewsTicker() {
    return InkWell(
      onTap: _isSalawatMode
          ? null
          : () => _incrementAndOpen('view_faneer', 50000, 'مساعد فنير', '$kBaseBlogUrl/search/label/مساعد%20فنير'),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isSalawatMode
                ? [const Color(0xFF451A03), const Color(0xFF92400E), const Color(0xFF451A03)]
                : [const Color(0xFF1E1B4B), const Color(0xFF312E81), const Color(0xFF1E1B4B)],
          ),
          border: Border(
            bottom: BorderSide(color: _isSalawatMode ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B).withOpacity(0.5), width: 1.5),
          ),
        ),
        child: _isSalawatMode
            ? const Center(
                child: Text(
                  '✨ صلِّ على محمد ﷺ .. اللهم صلِّ وسلم وبارك على نبينا محمد ✨',
                  style: TextStyle(color: Color(0xFFFEF08A), fontSize: 12, fontWeight: FontWeight.w800),
                ),
              )
            : Row(
                children: [
                  Container(
                    height: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '✨ دفعة 2027',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Center(
                        child: Text(
                          'أهلاً بك في التطبيق الأول للتعليم الفني في مصر 🇪🇬 .. جميع المذكرات والشروحات والأدوات الهندسية في مكان واحد!',
                          style: TextStyle(color: Color(0xFFFEF3C7), fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ================= 3. محتوى مرحلة الدبلومات =================
  List<Widget> _buildDiplomaStageContent() {
    return [
      _buildSectionHead(
        title: 'ابدأ مذاكرتك الآن (دفعة 2027)',
        icon: Icons.menu_book_rounded,
        gradient: [_primaryColor, _primaryDarkColor],
        speech: 'هنا أساس المذاكرة لشهادة الدبلومات 3 و 5 سنوات! الكرت الأول فيه مكتبة المذكرات والمراجعات لكل التخصصات، والكرت الثاني فيه شروحات الدروس بالفيديو.',
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _buildProCard(
              title: 'مكتبة المذكرات والمراجعات 2027',
              tag: '3 و 5 سنوات',
              bannerGradient: const [Color(0xFF10B981), Color(0xFF047857)],
              bannerIcon: Icons.book_rounded,
              viewsText: _formatViews('view_memo_2027_v2', 86400),
              actionText: 'تصفح',
              actionColor: const Color(0xFF059669),
              isFeatured: true,
              onTap: () => _incrementAndOpen('view_memo_2027_v2', 86400, 'مكتبة المذكرات', '$kBaseBlogUrl/search/label/المذكرات'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildProCard(
              title: 'شروحات المناهج والدروس 2027',
              tag: '3 و 5 سنوات',
              bannerGradient: const [Color(0xFFF59E0B), Color(0xFFB45309)],
              bannerIcon: Icons.ondemand_video_rounded,
              viewsText: _formatViews('view_lessons_2027_v2', 74200),
              actionText: 'شاهد',
              actionColor: const Color(0xFFD97706),
              isFeatured: true,
              onTap: () => _incrementAndOpen('view_lessons_2027_v2', 74200, 'شروحات المناهج', '$kBaseBlogUrl/search/label/الشروحات'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _buildSectionHead(
        title: 'تدرّب واختبر مستواك',
        icon: Icons.emoji_events_rounded,
        gradient: const [Color(0xFF4F46E5), Color(0xFF0891B2)],
        speech: 'هنا منطقة التدريب والألعاب التعليمية! معاك بنك الاختبارات النهائية، واختبار الذكاء، ولعبتين ممتعتين للتفوق وقوانين لجنة الدبلوم.',
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _buildProCard(
              title: 'بنك الاختبارات النهائية بالاجابة 2027',
              tag: 'محلولة',
              bannerGradient: const [Color(0xFF6366F1), Color(0xFF4338CA)],
              bannerIcon: Icons.assignment_turned_in_rounded,
              viewsText: _formatViews('view_exams_2027_v2', 68900),
              actionText: 'تدرّب',
              actionColor: const Color(0xFF4F46E5),
              onTap: () => _incrementAndOpen('view_exams_2027_v2', 68900, 'بنك الاختبارات', '$kBaseBlogUrl/search/label/الاختبارات'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildProCard(
              title: 'اختبر ذكائك ونشط ذاكرتك',
              tag: 'تفاعلي',
              bannerImageUrl: 'https://i.ibb.co/gZjphGy5/Picsart-26-05-12-18-24-51-116.jpg',
              viewsText: _formatViews('view_quiz_2027_v2', 52600),
              actionText: 'ابدأ',
              actionColor: const Color(0xFFD97706),
              onTap: () => _incrementAndOpen('view_quiz_2027_v2', 52600, 'اختبر ذكائك', '$kBaseBlogUrl/search/label/اختبر%20ذكائك'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _buildProCard(
              title: 'تحدي التفوق والامتحانات 🏆',
              tag: 'لعبة تحدي التفوق',
              tagColor: const Color(0xFFF59E0B),
              tagTextColor: const Color(0xFF0F172A),
              bannerGradient: const [Color(0xFF7C3AED), Color(0xFF4C1D95)],
              bannerIcon: Icons.emoji_events_rounded,
              viewsText: _formatViews('view_game_tafawok_v1', 41200),
              actionText: 'العب الآن',
              actionColor: const Color(0xFF7C3AED),
              isFeatured: true,
              onTap: () => _incrementAndOpen('view_game_tafawok_v1', 41200, 'تحدي التفوق', '$kBaseBlogUrl/search/label/تحدي%20التفوق'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildProCard(
              title: 'من سينجح في امتحانات الدبلوم؟',
              tag: 'قوانين اللجنة 🎓',
              tagColor: const Color(0xFF10B981),
              bannerGradient: const [Color(0xFFD97706), Color(0xFF92400E)],
              bannerIcon: Icons.military_tech_rounded,
              viewsText: _formatViews('view_game_million_v1', 38900),
              actionText: 'ادخل اللجنة',
              actionColor: const Color(0xFFD97706),
              isFeatured: true,
              onTap: () => _incrementAndOpen('view_game_million_v1', 38900, 'من سينجح', '$kBaseBlogUrl/search/label/من%20سينجح'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _buildSectionHead(
        title: 'نتائج الامتحانات وحساب المجموع',
        icon: Icons.analytics_rounded,
        gradient: const [Color(0xFF10B981), Color(0xFF0891B2)],
        speech: 'وقت ظهور النتيجة تقدر تستعلم برقم الجلوس فوراً من الكرت الأول، وتحسب نسبتك المئوية بدقة من الكرت الثاني.',
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _buildProCard(
              title: 'خدمات نتائج الإمتحانات 2027',
              tag: 'برقم الجلوس',
              bannerGradient: const [Color(0xFF10B981), Color(0xFF047857)],
              bannerIcon: Icons.fact_check_rounded,
              viewsText: _formatViews('view_results_2027_v2', 94800),
              actionText: 'استعلم',
              actionColor: const Color(0xFF059669),
              onTap: () => _incrementAndOpen('view_results_2027_v2', 94800, 'نتائج الامتحانات', '$kBaseBlogUrl/search/label/النتائج'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildProCard(
              title: 'احسب النسبة المئوية لنتيجتك',
              tag: 'حاسبة دقيقة',
              bannerImageUrl: 'https://i.ibb.co/ymTk28FX/Picsart-26-05-02-20-11-05-036.jpg',
              viewsText: _formatViews('view_calc_2027_v2', 81500),
              actionText: 'احسب',
              actionColor: const Color(0xFF0891B2),
              onTap: () => _incrementAndOpen('view_calc_2027_v2', 81500, 'حساب النسبة', '$kBaseBlogUrl/search/label/حساب%20النسبة'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _buildSectionHead(
        title: 'التنسيق والكليات والمعاهد',
        icon: Icons.school_rounded,
        gradient: const [Color(0xFF0284C7), Color(0xFFDC2626)],
        speech: 'بعد الدبلوم طريقك للكلية يبدأ من هنا! تابع تسجيل رغبات التنسيق الإلكتروني من الكرت الأول، واعرف شروط المعاهد والكليات والمعادلات من الكرت الثاني.',
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _buildProCard(
              title: 'خدمات التنسيق الإلكتروني 2027',
              tag: 'تسجيل الرغبات',
              bannerGradient: const [Color(0xFF0284C7), Color(0xFF0369A1)],
              bannerIcon: Icons.computer_rounded,
              viewsText: _formatViews('view_coord_2027_v2', 76900),
              actionText: 'سجّل الآن',
              actionColor: const Color(0xFF0284C7),
              onTap: () => _incrementAndOpen('view_coord_2027_v2', 76900, 'التنسيق الإلكتروني', '$kBaseBlogUrl/search/label/التنسيق'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildProCard(
              title: 'المعاهد والكليات والمعادلات 2027',
              tag: 'شروط القبول',
              bannerGradient: const [Color(0xFFEF4444), Color(0xFFB91C1C)],
              bannerIcon: Icons.account_balance_rounded,
              viewsText: _formatViews('view_eq_2027_v2', 63400),
              actionText: 'استكشف',
              actionColor: const Color(0xFFDC2626),
              onTap: () => _incrementAndOpen('view_eq_2027_v2', 63400, 'المعادلات والكليات', '$kBaseBlogUrl/search/label/المعادلات'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _buildSectionHead(
        title: 'مجتمع طلاب التعليم الفني',
        icon: Icons.groups_rounded,
        gradient: const [Color(0xFFEC4899), Color(0xFFBE185D)],
        speech: 'هنا مساحة تبادل الخبرات والنصائح الدراسية بين طلاب الدبلومات الفنية لمساعدة بعضكم في المذاكرة والامتحانات.',
      ),
      const SizedBox(height: 8),
      _buildProCard(
        title: 'انصح زميلك وتبادل الخبرات بين طلاب الدبلومات 💡',
        tag: 'تجارب وخبرات',
        bannerGradient: const [Color(0xFFEC4899), Color(0xFFBE185D)],
        bannerIcon: Icons.chat_bubble_rounded,
        viewsText: _formatViews('view_advise_diploma_v2', 49300),
        actionText: 'شارك الآن',
        actionColor: const Color(0xFFBE185D),
        onTap: () => _incrementAndOpen('view_advise_diploma_v2', 49300, 'انصح زميلك', '$kBaseBlogUrl/search/label/انصح%20زميلك'),
      ),
    ];
  }

  // ================= 4. محتوى مرحلة صفوف النقل =================
  List<Widget> _buildNaqlStageContent() {
    return [
      _buildSectionHead(
        title: 'منهج 2027 | صفوف النقل (3 و 5 سنوات)',
        icon: Icons.school_rounded,
        gradient: [_primaryColor, _primaryDarkColor],
        speech: 'هنا مكتبة المذكرات والمراجعات النهائية الشاملة لصفوف النقل نظام 3 سنوات ونظام 5 سنوات لجميع التخصصات.',
      ),
      const SizedBox(height: 8),
      _buildProCard(
        title: 'مكتبة المذكرات والمراجعات لصفوف النقل 2027',
        tag: 'أولى وتانية (3س) • ومن 1 إلى 4 (5س)',
        tagColor: const Color(0xFFD97706),
        bannerGradient: const [Color(0xFF059669), Color(0xFF047857), Color(0xFF10B981)],
        bannerIcon: Icons.book_rounded,
        viewsText: _formatViews('view_naql_all_v2', 62400),
        actionText: 'تصفح الآن',
        actionColor: const Color(0xFF059669),
        isFeatured: true,
        onTap: () => _incrementAndOpen('view_naql_all_v2', 62400, 'مذكرات صفوف النقل', '$kBaseBlogUrl/search/label/صفوف%20النقل'),
      ),
      const SizedBox(height: 16),
      InkWell(
        onTap: () => _incrementAndOpen('view_fb_official_v2', 35000, 'جروب الفيس بوك', '$kBaseBlogUrl/search/label/المنصات'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1877F2), Color(0xFF0F4C9C)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.facebook_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تابع جروب الفيس بوك الرسمي', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                    Text('أخبار ومراجعات صفوف النقل بالتعليم الفني', style: TextStyle(color: Color(0xFFDBEAFE), fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    ];
  }

  // ================= 5. محتوى مرحلة المعاهد والكليات =================
  List<Widget> _buildInstitutesStageContent() {
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⭐ رفيقك في التعليم الجامعي والمعاهد',
              style: TextStyle(color: Color(0xFFFDE047), fontSize: 10.5, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'لن ننسى طلاب المعاهد والكليات .. وخاصة أبطال التعليم الفني الملتحقين بها! 🎓',
              style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900, height: 1.35),
            ),
            SizedBox(height: 4),
            Text(
              'جهزنا لكم في هذا القسم أفضل الأدوات العملية لتنظيم السكاشن والمحاضرات وتدوين الملاحظات بكل احترافية.',
              style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 11, height: 1.45),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _buildSectionHead(
        title: 'أدوات السكاشن والمحاضرات للمعاهد والكليات',
        icon: Icons.architecture_rounded,
        gradient: [_primaryColor, _primaryDarkColor],
        speech: 'هنا أدواتك العملية في السكاشن: الآلة الحاسبة الفورية، غرفة التركيز بومودورو، وحماس المذاكرة اليومي.',
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _buildProCard(
              title: 'آلة حاسبة سريعة للسكاشن والمعامل 🧮',
              tag: 'حاسبة فورية',
              bannerGradient: const [Color(0xFF065F46), Color(0xFF047857)],
              bannerIcon: Icons.calculate_rounded,
              viewsText: _formatViews('view_calculator_tool_v2', 54300),
              actionText: 'احسب',
              actionColor: const Color(0xFF047857),
              isFeatured: true,
              onTap: _openCalculatorDialog,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildProCard(
              title: 'غرفة التركيز ومؤقت المذاكرة ⏱️',
              tag: 'بومودورو',
              bannerGradient: const [Color(0xFF312E81), Color(0xFF4338CA)],
              bannerIcon: Icons.timer_rounded,
              viewsText: _formatViews('view_focus_tool_v2', 61200),
              actionText: 'ابدأ',
              actionColor: const Color(0xFF4338CA),
              isFeatured: true,
              onTap: _openFocusTimerDialog,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _buildProCard(
        title: 'انصح زميلك وتبادل الخبرات في المعاهد والكليات 💡',
        tag: 'تجارب المعاهد',
        bannerGradient: const [Color(0xFFEC4899), Color(0xFFBE185D)],
        bannerIcon: Icons.forum_rounded,
        viewsText: _formatViews('view_advise_inst_v2', 48700),
        actionText: 'شارك الآن',
        actionColor: const Color(0xFFBE185D),
        onTap: () => _incrementAndOpen('view_advise_inst_v2', 48700, 'مجتمع المعاهد', '$kBaseBlogUrl/search/label/انصح%20زميلك'),
      ),
    ];
  }

  // ================= مكونات الواجهة المتكررة =================
  Widget _buildSectionHead({
    required String title,
    required IconData icon,
    required List<Color> gradient,
    required String speech,
  }) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white, size: 13),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
        ),
        InkWell(
          onTap: () => _activateMascot(title, speech),
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: _primaryColor, width: 1.5),
            ),
            child: Row(
              children: [
                const Text('👨‍🎓', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 3),
                Text('شرح', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _primaryColor)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProCard({
    required String title,
    required String tag,
    Color tagColor = const Color(0xB30F172A),
    Color tagTextColor = Colors.white,
    List<Color>? bannerGradient,
    IconData? bannerIcon,
    String? bannerImageUrl,
    required String viewsText,
    required String actionText,
    required Color actionColor,
    bool isFeatured = false,
    bool isDashedBorder = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFeatured || isDashedBorder ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
            width: isFeatured || isDashedBorder ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 78,
              decoration: BoxDecoration(
                gradient: bannerGradient != null ? LinearGradient(colors: bannerGradient) : null,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12.5)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (bannerImageUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12.5)),
                      child: Image.network(bannerImageUrl, fit: BoxFit.cover),
                    )
                  else
                    Center(
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white38),
                        ),
                        child: Icon(bannerIcon, color: Colors.white, size: 20),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(50)),
                      child: Text(tag, style: TextStyle(color: tagTextColor, fontSize: 8.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 36,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B), height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.remove_red_eye_rounded, size: 12, color: actionColor),
                          const SizedBox(width: 3),
                          Text(viewsText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(color: actionColor, borderRadius: BorderRadius.circular(50)),
                        child: Row(
                          children: [
                            Text(actionText, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 3),
                            const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinistryBanner() {
    return InkWell(
      onTap: () => _incrementAndOpen('view_moe_gov_v2', 45000, 'وزارة التربية والتعليم', 'https://moe.gov.eg'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.22), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.account_balance_rounded, color: Color(0xFF38BDF8), size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الموقع الرسمي لوزارة التربية والتعليم', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                  Text('🌐 بوابة الخدمات الرسمية', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_back_rounded, color: Color(0xFF818CF8), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentChatCard() {
    return InkWell(
      onTap: () => _incrementAndOpen('view_chat_v2', 60000, 'شات الطلاب المباشر', '$kBaseBlogUrl/search/label/الشات'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF312E81), Color(0xFF1E1B4B)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('شات الطلاب المباشر', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                    Text('نقاش ومساعدة فورية بين الطلاب', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(radius: 3, backgroundColor: Color(0xFF34D399)),
                      SizedBox(width: 4),
                      Text('47 متصل', style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
                child: const Text('حد عنده ملخص مادة الرياضيات التطبيقية؟', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.35), borderRadius: BorderRadius.circular(9)),
                child: const Text('عندي ملخص كامل، بعته في القروب 📝', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Colors.white12),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('👥 128 عضو  •  💬 342 رسالة اليوم', style: TextStyle(color: Colors.white70, fontSize: 10)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(50)),
                  child: const Text('انضم الآن ←', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= 6. الشريط السفلي العائم =================
  Widget _buildFloatingBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.14), blurRadius: 18, offset: const Offset(0, 4))],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomNavItem(Icons.home_rounded, 'الرئيسية', true, () {}),
              _bottomNavItem(Icons.rss_feed_rounded, 'تابع', false, () {
                _incrementAndOpen('view_platforms', 20000, 'منصاتنا الرسمية', '$kBaseBlogUrl/search/label/المنصات');
              }),
              const SizedBox(width: 64),
              _bottomNavItem(Icons.share_rounded, 'مشاركة', false, () {
                _showSimpleMessage('مشاركة التطبيق', 'شارك تطبيق فني برو 2027 مع أصدقائك لتعم الفائدة 🎓');
              }),
              _bottomNavItem(Icons.repeat_rounded, 'المرحلة', false, _showStageOnboardingDialog),
            ],
          ),
          Positioned(
            top: -22,
            child: GestureDetector(
              onTap: _openUnifiedToolboxDialog,
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_primaryDarkColor, const Color(0xFF06B6D4)]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.work_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currentStage == AppStage.institutes ? 'أدوات السكاشن' : 'شنطة الأدوات',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: _primaryColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: isActive ? _primaryColor : const Color(0xFF64748B)),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isActive ? _primaryColor : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ================= 7. القائمة الجانبية (Drawer) =================
  Widget _buildSideDrawer() {
    return Drawer(
      width: 270,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, bottom: 14, left: 12, right: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_primaryColor, _primaryDarkColor]),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _drawerPillBtn('من نحن', () => _incrementAndOpen('v_about', 1000, 'من نحن', '$kBaseBlogUrl/search/label/من%20نحن')),
                    const SizedBox(width: 6),
                    _drawerPillBtn('الخصوصية', () => _incrementAndOpen('v_priv', 1000, 'سياسة الخصوصية', '$kBaseBlogUrl/search/label/سياسة%20الخصوصية')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text('ف', style: TextStyle(color: _primaryDarkColor, fontWeight: FontWeight.w900, fontSize: 20))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_stageBadgeText, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          const Text('تطبيق فني برو 2027', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              children: [
                _drawerTile(Icons.home_rounded, 'الرئيسية', () => Navigator.pop(context)),
                _drawerTile(Icons.repeat_rounded, 'تغيير المرحلة الدراسية', () {
                  Navigator.pop(context);
                  _showStageOnboardingDialog();
                }),
                _drawerTile(Icons.book_rounded, 'مكتبة المذكرات 2027', () {
                  Navigator.pop(context);
                  _incrementAndOpen('view_memo_2027_v2', 86400, 'مكتبة المذكرات', '$kBaseBlogUrl/search/label/المذكرات');
                }),
                _drawerTile(Icons.ondemand_video_rounded, 'شروحات المناهج 2027', () {
                  Navigator.pop(context);
                  _incrementAndOpen('view_lessons_2027_v2', 74200, 'شروحات المناهج', '$kBaseBlogUrl/search/label/الشروحات');
                }),
                _drawerTile(Icons.assignment_turned_in_rounded, 'بنك الاختبارات 2027', () {
                  Navigator.pop(context);
                  _incrementAndOpen('view_exams_2027_v2', 68900, 'بنك الاختبارات', '$kBaseBlogUrl/search/label/الاختبارات');
                }),
                _drawerTile(Icons.smart_toy_rounded, 'مساعد فنير الدراسي', () {
                  Navigator.pop(context);
                  _incrementAndOpen('view_faneer', 50000, 'مساعد فنير', '$kBaseBlogUrl/search/label/مساعد%20فنير');
                }),
                _drawerTile(Icons.work_rounded, 'شنطة الأدوات الذكية', () {
                  Navigator.pop(context);
                  _openUnifiedToolboxDialog();
                }),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            alignment: Alignment.center,
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
            child: const Text('فني برو © 2027', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }

  Widget _drawerPillBtn(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white38),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _drawerTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 15, color: _primaryColor),
      ),
      title: Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      onTap: onTap,
    );
  }

  // ================= 8. نوافذ التفاعل (اختيار المرحلة + شنطة الأدوات + الحاسبة + التركيز) =================
  void _showStageOnboardingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('أهلاً بك في تطبيق فني برو 🎓', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('اختر مرحلتك الدراسية للدخول مباشرة إلى قسمك', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                const SizedBox(height: 14),
                _stageOptionCard(
                  ctx: ctx,
                  stage: AppStage.diploma,
                  title: 'الدبلومات الفنية (3 و 5 سنوات)',
                  subtitle: 'الصف الثالث • الصف الخامس (صناعي - تجاري - زراعي - فندقي)',
                  color: const Color(0xFF4F46E5),
                  icon: Icons.school_rounded,
                ),
                const SizedBox(height: 10),
                _stageOptionCard(
                  ctx: ctx,
                  stage: AppStage.naql,
                  title: 'صفوف النقل بالتعليم الفني',
                  subtitle: 'الأول والثاني (3 سنوات) • من 1 إلى 4 (5 سنوات)',
                  color: const Color(0xFF059669),
                  icon: Icons.account_balance_rounded,
                ),
                const SizedBox(height: 10),
                _stageOptionCard(
                  ctx: ctx,
                  stage: AppStage.institutes,
                  title: 'المعاهد والكليات (سكاشن وأدوات)',
                  subtitle: 'أدوات هندسية وعملية لطلاب المعاهد والكليات',
                  color: const Color(0xFF0284C7),
                  icon: Icons.architecture_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stageOptionCard({
    required BuildContext ctx,
    required AppStage stage,
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return InkWell(
      onTap: () {
        _selectStage(stage);
        Navigator.pop(ctx);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _currentStage == stage ? color : const Color(0xFFE2E8F0), width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                  Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  void _openUnifiedToolboxDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Icons.work_rounded, color: _primaryColor),
              const SizedBox(width: 8),
              const Text('شنطة أدوات فني برو', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF047857), child: Icon(Icons.calculate, color: Colors.white)),
                title: const Text('الآلة الحاسبة الذكية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('حساب فوري سريع أوفلاين', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openCalculatorDialog();
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF10B981), child: Icon(Icons.timer, color: Colors.white)),
                title: const Text('غرفة التركيز (بومودورو)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('مؤقت 25 دقيقة مذاكرة', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openFocusTimerDialog();
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFDC2626), child: Icon(Icons.local_fire_department, color: Colors.white)),
                title: const Text('حماس المذاكرة اليومي 🔥', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('جرعة تحفيز يومية', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  final quotes = [
                    '🔥 اصنع من تعبك اليوم قصة نجاح ترويها غداً في كليتك!',
                    '💪 لا توجد صعوبة أمام إرادة طالب فني يطمح للقمة.',
                    '🎯 كل ساعة مذاكرة تقربك خطوة نحو مستقبلك الكبير.',
                    '🚀 استعن بالله ولا تعجز.. القمة تنتظرك.',
                  ];
                  _showSimpleMessage('شحن طاقة وحماس المذاكرة 🚀', quotes[Random().nextInt(quotes.length)]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCalculatorDialog() {
    String display = '0';
    String firstNum = '';
    String op = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          void onBtn(String val) {
            setModalState(() {
              if (val == 'C') {
                display = '0';
                firstNum = '';
                op = '';
              } else if (['+', '-', '×', '÷'].contains(val)) {
                firstNum = display;
                op = val;
                display = '0';
              } else if (val == '=') {
                double n1 = double.tryParse(firstNum) ?? 0;
                double n2 = double.tryParse(display) ?? 0;
                double res = 0;
                if (op == '+') res = n1 + n2;
                if (op == '-') res = n1 - n2;
                if (op == '×') res = n1 * n2;
                if (op == '÷') res = n2 != 0 ? n1 / n2 : 0;
                display = res % 1 == 0 ? res.toInt().toString() : res.toStringAsFixed(2);
                firstNum = '';
                op = '';
              } else {
                display = display == '0' ? val : display + val;
              }
            });
          }

          final buttons = ['7', '8', '9', '÷', '4', '5', '6', '×', '1', '2', '3', '-', 'C', '0', '=', '+'];

          return Dialog(
            backgroundColor: const Color(0xFF1E1B4B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🧮 آلة حاسبة الطلاب', style: TextStyle(color: Color(0xFFA5B4FC), fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.redAccent), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                    child: Text(display, textAlign: TextAlign.left, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 28, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 4,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: buttons.map((b) {
                      Color bg = const Color(0xFF312E81);
                      if (b == 'C') bg = const Color(0xFFEF4444);
                      if (b == '=') bg = const Color(0xFF059669);
                      if (['+', '-', '×', '÷'].contains(b)) bg = const Color(0xFF4F46E5);
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: bg, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        onPressed: () => onBtn(b),
                        child: Text(b, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openFocusTimerDialog() {
    int secondsLeft = 25 * 60;
    Timer? timer;
    bool running = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final m = (secondsLeft ~/ 60).toString().padLeft(2, '0');
          final s = (secondsLeft % 60).toString().padLeft(2, '0');

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Text('⏱️ غرفة التركيز والمذاكرة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('نظام بومودورو: 25 دقيقة تركيز متواصل بدون تشتيت.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 14),
                  Text('$m:$s', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: _primaryColor)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: running ? Colors.red : const Color(0xFF10B981), foregroundColor: Colors.white),
                          icon: Icon(running ? Icons.pause : Icons.play_arrow),
                          label: Text(running ? 'إيقاف' : 'ابدأ التركيز'),
                          onPressed: () {
                            if (running) {
                              timer?.cancel();
                              setModalState(() => running = false);
                            } else {
                              setModalState(() => running = true);
                              timer = Timer.periodic(const Duration(seconds: 1), (t) {
                                if (secondsLeft > 0) {
                                  setModalState(() => secondsLeft--);
                                } else {
                                  t.cancel();
                                  setModalState(() => running = false);
                                }
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          timer?.cancel();
                          setModalState(() {
                            running = false;
                            secondsLeft = 25 * 60;
                          });
                        },
                        child: const Text('إعادة'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    Navigator.pop(ctx);
                  },
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSimpleMessage(String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Text(body, style: const TextStyle(fontSize: 13, height: 1.5)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
        ),
      ),
    );
  }
}

// ================= شاشة عرض صفحات المدونة الداخلية (WebView) =================
class BlogWebViewScreen extends StatefulWidget {
  final String title;
  final String url;
  final Color themeColor;

  const BlogWebViewScreen({
    super.key,
    required this.title,
    required this.url,
    required this.themeColor,
  });

  @override
  State<BlogWebViewScreen> createState() => _BlogWebViewScreenState();
}

class _BlogWebViewScreenState extends State<BlogWebViewScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    final targetUri = Uri.parse(widget.url.contains('?') ? '${widget.url}&app=1' : '${widget.url}?app=1');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _loadingProgress = progress);
          },
          onPageFinished: (url) {
            // حقن CSS لإخفاء قوائم المدونة العلوية والسفلية تلقائياً داخل التطبيق
            _controller.runJavaScript('''
              var style = document.createElement('style');
              style.innerHTML = 'header, nav, .fixed-action-bar, .floating-nav-wrap, .support-ticker-bar, footer { display: none !important; } body { padding-top: 8px !important; padding-bottom: 16px !important; }';
              document.head.appendChild(style);
            ''');
          },
        ),
      )
      ..loadRequest(targetUri);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: widget.themeColor,
          foregroundColor: Colors.white,
          title: Text(widget.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _controller.reload(),
            ),
          ],
          bottom: _loadingProgress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _loadingProgress / 100.0,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
                  ),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
