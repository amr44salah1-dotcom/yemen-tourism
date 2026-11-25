import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'yemen_data.dart';

// ضع مفتاح Gemini API الخاص بك هنا لتفعيل الذكاء الاصطناعي وتوليد المقالات
const String geminiApiKey =
    'AQ.Ab8RN6KcKI_F3EKXGpQBjqm0qRZj6g_7igcP5-T3jrqNxK9lFQ';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyBCz8TdMaaYIX-QPu2579P6DXbcdn-0VSs',
        appId: '1:126067861643:android:56b2b573955d7ca2808c8e',
        messagingSenderId: '126067861643',
        projectId: 'yemen-tourism-3362e',
        storageBucket: 'yemen-tourism-3362e.firebasestorage.app',
      ),
    );
  } catch (e) {
    debugPrint('Firebase init: $e');
  }
  runApp(const YemenTourismApp());
}

class YemenTourismApp extends StatelessWidget {
  const YemenTourismApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'دليل اليمن السياحي',
      theme: ThemeData(
        primaryColor: const Color(0xFF00695C),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

Future<void> openGpsMap(BuildContext context, String gps) async {
  if (gps.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('لم يتم تحديد إحداثيات GPS لهذا الموقع بعد')),
    );
    return;
  }
  final url = gps.startsWith('http') ? gps : 'https://google.com{gps.trim()}';
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

// ==========================================
// 1. الشاشة الترحيبية
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF004D40), Color(0xFF00897B)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mosque, size: 95, color: Colors.amber),
              const SizedBox(height: 24),
              const Text(
                'مرحباً بكم في برنامج\nدليل اليمن السياحي',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.amberAccent),
                ),
                child: const Text(
                  'عمرو حيدر صلاح يرحب بكم',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.amberAccent),
                ),
              ),
              const SizedBox(height: 45),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. الشاشة الرئيسية وصلاحيات المدير الحصرية
// ==========================================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _localAdmin = false;

  bool get _isAdmin =>
      _localAdmin || (!kIsWeb && FirebaseAuth.instance.currentUser != null);

  void _adminAuthDialog() {
    if (_isAdmin) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('لوحة المدير: عمرو حيدر صلاح'),
          content: const Text(
              'أنت الآن في وضع التحكم الكامل (إضافة وحذف وتعديل وقبول الأعضاء).'),
          actions: [
            TextButton(
              onPressed: () async {
                if (!kIsWeb) await FirebaseAuth.instance.signOut();
                setState(() => _localAdmin = false);
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('تسجيل خروج المدير',
                  style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق')),
          ],
        ),
      );
      return;
    }

    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('دخول المدير الحصري'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني (اختياري للتجربة)'),
            ),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'كلمة المرور (1234 للتجربة)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (passCtrl.text.trim() == '1234') {
                setState(() => _localAdmin = true);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('تم تفعيل صلاحيات المدير (عمرو حيدر صلاح)')),
                );
                return;
              }
              try {
                await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: emailCtrl.text.trim(),
                  password: passCtrl.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('تم تسجيل دخول المدير سحابياً بنجاح')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('بيانات الدخول غير صحيحة')),
                );
              }
            },
            child: const Text('دخول'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      GovernoratesScreen(isAdmin: _isAdmin),
      const SmartArticleSearchScreen(),
      PublicChatScreen(isAdmin: _isAdmin),
      DirectAdminChatScreen(isAdmin: _isAdmin),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF00695C),
          foregroundColor: Colors.white,
          title: GestureDetector(
            onLongPress: _adminAuthDialog,
            child: Text(
                _isAdmin ? 'دليل اليمن (وضع المدير)' : 'دليل اليمن السياحي'),
          ),
          actions: [
            if (_isAdmin)
              IconButton(
                icon: const Icon(Icons.verified_user),
                tooltip: 'قبول وحذف أعضاء الشات',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminUserApprovalScreen()),
                ),
              ),
            IconButton(
              icon:
                  Icon(_isAdmin ? Icons.lock_open : Icons.admin_panel_settings),
              tooltip: 'دخول المدير',
              onPressed: _adminAuthDialog,
            ),
          ],
        ),
        body: pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF00695C),
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'المحافظات'),
            BottomNavigationBarItem(
                icon: Icon(Icons.auto_awesome), label: 'المرشد الذكي'),
            BottomNavigationBarItem(
                icon: Icon(Icons.forum), label: 'ملتقى الزوار'),
            BottomNavigationBarItem(
                icon: Icon(Icons.support_agent), label: 'راسل المدير'),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. شاشة البحث الفوري وتوليد المقالات بالذكاء الاصطناعي
// ==========================================
class SmartArticleSearchScreen extends StatefulWidget {
  const SmartArticleSearchScreen({super.key});

  @override
  State<SmartArticleSearchScreen> createState() =>
      _SmartArticleSearchScreenState();
}

class _SmartArticleSearchScreenState extends State<SmartArticleSearchScreen> {
  final _queryCtrl = TextEditingController();
  String _resultTitle = YemenDatabase.mainIntroTitle;
  String _resultBody = YemenDatabase.mainIntroArticle;
  String _resultGps = '';
  bool _isLoading = false;

  Future<void> _searchOrGenerate() async {
    final query = _queryCtrl.text.trim();
    if (query.isEmpty) return;

    for (final gov in YemenDatabase.governorates) {
      for (final l in gov.landmarks) {
        if (l.title.contains(query) || gov.name.contains(query)) {
          setState(() {
            _resultTitle = '${l.title} (${gov.name})';
            _resultBody = l.article;
            _resultGps = l.gps;
          });
          return;
        }
      }
      for (final dist in gov.districts) {
        for (final l in dist.landmarks) {
          if (l.title.contains(query) || dist.name.contains(query)) {
            setState(() {
              _resultTitle = '${l.title} - مديرية ${dist.name}';
              _resultBody = l.article;
              _resultGps = l.gps;
            });
            return;
          }
        }
        for (final sub in dist.subDistricts) {
          for (final l in sub.landmarks) {
            if (l.title.contains(query) || sub.name.contains(query)) {
              setState(() {
                _resultTitle = '${l.title} - عزلة ${sub.name}';
                _resultBody = l.article;
                _resultGps = l.gps;
              });
              return;
            }
          }
          for (final vil in sub.villages) {
            for (final l in vil.landmarks) {
              if (l.title.contains(query) || vil.name.contains(query)) {
                setState(() {
                  _resultTitle = '${l.title} - قرية ${vil.name}';
                  _resultBody = l.article;
                  _resultGps = l.gps;
                });
                return;
              }
            }
          }
        }
      }
    }

    setState(() {
      _isLoading = true;
      _resultGps = '';
    });

    try {
      final model =
          GenerativeModel(model: 'gemini-1.5-flash', apiKey: geminiApiKey);
      final prompt =
          '''أنت مؤرخ وباحث جغرافي ومرشد سياحي خبير بالجمهورية اليمنية في تطبيق "دليل اليمن السياحي" بإدارة عمرو حيدر صلاح.
اكتب مقالة شاملة ومنظمة باللغة العربية عن: "$query" في اليمن (سواء كانت محافظة، مديرية، عزلة، قرية، أو معلماً سياحياً).
اشمل في المقالة: الموقع الجغرافي والتبعية الإدارية، الأهمية التاريخية، أبرز المعالم والطبيعة، والعادات والتقاليد.''';

      final response = await model.generateContent([Content.text(prompt)]);
      setState(() {
        _resultTitle = 'مقالة عن: $query';
        _resultBody = response.text ?? 'لم يتم العثور على تفاصيل كافية.';
      });
    } catch (e) {
      setState(() {
        _resultTitle = 'معلومة عن: $query';
        _resultBody =
            'لتفعيل التوليد التلقائي للمقالات بالذكاء الاصطناعي عن أي قرية أو عزلة، ضع مفتاح Gemini API في أعلى الكود.';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          TextField(
            controller: _queryCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchOrGenerate(),
            decoration: InputDecoration(
              hintText: 'اكتب اسم محافظة، مديرية، عزلة، أو قرية لعرض مقالها...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF00695C)),
                onPressed: _searchOrGenerate,
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _resultTitle,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00695C)),
                      ),
                      if (_resultGps.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.location_on),
                          label: const Text('الموقع على الخريطة GPS'),
                          onPressed: () => openGpsMap(context, _resultGps),
                        ),
                      ],
                      const Divider(height: 24),
                      Text(_resultBody,
                          style: const TextStyle(fontSize: 16, height: 1.7)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. شاشة المحافظات والمديريات والعُزل والقرى
// ==========================================
class GovernoratesScreen extends StatefulWidget {
  final bool isAdmin;
  const GovernoratesScreen({super.key, required this.isAdmin});

  @override
  State<GovernoratesScreen> createState() => _GovernoratesScreenState();
}

class _GovernoratesScreenState extends State<GovernoratesScreen> {
  String _search = '';

  void _addGovernorate() {
    final nameCtrl = TextEditingController();
    final gpsCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة محافظة جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم المحافظة')),
            TextField(
                controller: gpsCtrl,
                decoration:
                    const InputDecoration(labelText: 'إحداثيات GPS (اختياري)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() {
                YemenDatabase.governorates.add(
                  GovernorateItem(
                      name: nameCtrl.text.trim(), gps: gpsCtrl.text.trim()),
                );
              });
              Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = YemenDatabase.governorates
        .where((g) => g.name.contains(_search))
        .toList();

    return Scaffold(
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _addGovernorate,
              icon: const Icon(Icons.add),
              label: const Text('إضافة محافظة'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن محافظة...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final gov = filtered[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF00695C),
                      child: Icon(Icons.location_city, color: Colors.white),
                    ),
                    title: Text(gov.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('المديريات: ${gov.districts.length}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (gov.gps.isNotEmpty)
                          IconButton(
                            icon:
                                const Icon(Icons.gps_fixed, color: Colors.blue),
                            onPressed: () => openGpsMap(context, gov.gps),
                          ),
                        if (widget.isAdmin)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => setState(
                                () => YemenDatabase.governorates.remove(gov)),
                          ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DistrictsScreen(
                            governorate: gov, isAdmin: widget.isAdmin),
                      ),
                    ).then((_) => setState(() {})),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DistrictsScreen extends StatefulWidget {
  final GovernorateItem governorate;
  final bool isAdmin;
  const DistrictsScreen(
      {super.key, required this.governorate, required this.isAdmin});

  @override
  State<DistrictsScreen> createState() => _DistrictsScreenState();
}

class _DistrictsScreenState extends State<DistrictsScreen> {
  void _addDistrict() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة مديرية في ${widget.governorate.name}'),
        content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'اسم المديرية')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() => widget.governorate.districts
                  .add(DistrictItem(name: nameCtrl.text.trim())));
              Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('مديريات ${widget.governorate.name}'),
          backgroundColor: const Color(0xFF00695C),
          foregroundColor: Colors.white,
        ),
        floatingActionButton: widget.isAdmin
            ? FloatingActionButton.extended(
                onPressed: _addDistrict,
                icon: const Icon(Icons.add),
                label: const Text('إضافة مديرية'))
            : null,
        body: ListView.builder(
          itemCount: widget.governorate.districts.length,
          itemBuilder: (context, index) {
            final dist = widget.governorate.districts[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: ListTile(
                leading:
                    const Icon(Icons.map_outlined, color: Color(0xFF00695C)),
                title: Text(dist.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    'العُزل: ${dist.subDistricts.length} | المعالم: ${dist.landmarks.length}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dist.gps.isNotEmpty)
                      IconButton(
                          icon: const Icon(Icons.gps_fixed, color: Colors.blue),
                          onPressed: () => openGpsMap(context, dist.gps)),
                    if (widget.isAdmin)
                      IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => setState(
                              () => widget.governorate.districts.remove(dist))),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SubDistrictsScreen(
                          district: dist, isAdmin: widget.isAdmin)),
                ).then((_) => setState(() {})),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SubDistrictsScreen extends StatefulWidget {
  final DistrictItem district;
  final bool isAdmin;
  const SubDistrictsScreen(
      {super.key, required this.district, required this.isAdmin});

  @override
  State<SubDistrictsScreen> createState() => _SubDistrictsScreenState();
}

class _SubDistrictsScreenState extends State<SubDistrictsScreen> {
  void _addSubDistrict() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة عزلة في ${widget.district.name}'),
        content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'اسم العزلة')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() => widget.district.subDistricts
                  .add(SubDistrictItem(name: nameCtrl.text.trim())));
              Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            title: Text('مديرية ${widget.district.name}'),
            backgroundColor: const Color(0xFF00695C),
            foregroundColor: Colors.white),
        floatingActionButton: widget.isAdmin
            ? FloatingActionButton.extended(
                onPressed: _addSubDistrict,
                icon: const Icon(Icons.add),
                label: const Text('إضافة عزلة'))
            : null,
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              color: Colors.teal.shade50,
              child: ListTile(
                leading:
                    const Icon(Icons.landscape, color: Colors.teal, size: 32),
                title: Text(
                    'المعالم الأثرية والمقالات في ${widget.district.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle:
                    Text('عدد المعالم: ${widget.district.landmarks.length}'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => LandmarksPage(
                          title: widget.district.name,
                          landmarks: widget.district.landmarks,
                          isAdmin: widget.isAdmin)),
                ).then((_) => setState(() {})),
              ),
            ),
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('العُزل الإدارية:',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ...widget.district.subDistricts.map((sub) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.holiday_village,
                        color: Color(0xFF00695C)),
                    title: Text(sub.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'القرى: ${sub.villages.length} | المعالم: ${sub.landmarks.length}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isAdmin)
                          IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => setState(() =>
                                  widget.district.subDistricts.remove(sub))),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => VillagesScreen(
                              subDistrict: sub, isAdmin: widget.isAdmin)),
                    ).then((_) => setState(() {})),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class VillagesScreen extends StatefulWidget {
  final SubDistrictItem subDistrict;
  final bool isAdmin;
  const VillagesScreen(
      {super.key, required this.subDistrict, required this.isAdmin});

  @override
  State<VillagesScreen> createState() => _VillagesScreenState();
}

class _VillagesScreenState extends State<VillagesScreen> {
  void _addVillage() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة قرية سحابياً في ${widget.subDistrict.name}'),
        content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'اسم القرية')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await FirebaseFirestore.instance.collection('live_items').add({
                'type': 'village',
                'parent': widget.subDistrict.name,
                'name': nameCtrl.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('نشر للجميع'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            title: Text('عزلة ${widget.subDistrict.name}'),
            backgroundColor: const Color(0xFF00695C),
            foregroundColor: Colors.white),
        floatingActionButton: widget.isAdmin
            ? FloatingActionButton.extended(
                onPressed: _addVillage,
                icon: const Icon(Icons.add),
                label: const Text('إضافة قرية للجميع'))
            : null,
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              color: Colors.teal.shade50,
              child: ListTile(
                leading:
                    const Icon(Icons.landscape, color: Colors.teal, size: 32),
                title: Text('معالم ومقالات عزلة ${widget.subDistrict.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => LandmarksPage(
                          title: widget.subDistrict.name,
                          landmarks: widget.subDistrict.landmarks,
                          isAdmin: widget.isAdmin)),
                ),
              ),
            ),
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('القرى:',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ...widget.subDistrict.villages.map((vil) => Card(
                  child: ListTile(
                    leading:
                        const Icon(Icons.home_work, color: Color(0xFF00695C)),
                    title: Text(vil.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => LandmarksPage(
                              title: 'قرية ${vil.name}',
                              landmarks: vil.landmarks,
                              isAdmin: widget.isAdmin)),
                    ),
                  ),
                )),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('live_items')
                  .where('type', isEqualTo: 'village')
                  .where('parent', isEqualTo: widget.subDistrict.name)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final name = doc['name'] ?? '';
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.home_work,
                            color: Color(0xFF00695C)),
                        title: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.isAdmin)
                              IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => doc.reference.delete()),
                            const Icon(Icons.arrow_forward_ios, size: 16),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => LandmarksPage(
                                  title: 'قرية $name',
                                  landmarks: const [],
                                  isAdmin: widget.isAdmin)),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class LandmarksPage extends StatefulWidget {
  final String title;
  final List<LandmarkItem> landmarks;
  final bool isAdmin;
  const LandmarksPage(
      {super.key,
      required this.title,
      required this.landmarks,
      required this.isAdmin});

  @override
  State<LandmarksPage> createState() => _LandmarksPageState();
}

class _LandmarksPageState extends State<LandmarksPage> {
  void _addLandmark() {
    final titleCtrl = TextEditingController();
    final articleCtrl = TextEditingController();
    final gpsCtrl = TextEditingController();
    final videoCtrl = TextEditingController();
    final imgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('نشر معلم ومقال سحابياً في ${widget.title}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: titleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'اسم المعلم السياحي')),
              TextField(
                  controller: articleCtrl,
                  maxLines: 4,
                  decoration:
                      const InputDecoration(labelText: 'المقال والتفاصيل')),
              TextField(
                  controller: gpsCtrl,
                  decoration: const InputDecoration(
                      labelText: 'إحداثيات GPS أو رابط الخريطة')),
              TextField(
                  controller: videoCtrl,
                  decoration: const InputDecoration(
                      labelText: 'رابط الفيديو (يوتيوب)')),
              TextField(
                  controller: imgCtrl,
                  decoration: const InputDecoration(labelText: 'رابط الصورة')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              await FirebaseFirestore.instance.collection('live_items').add({
                'type': 'landmark',
                'parent': widget.title,
                'title': titleCtrl.text.trim(),
                'article': articleCtrl.text.trim(),
                'gps': gpsCtrl.text.trim(),
                'videoUrl': videoCtrl.text.trim(),
                'imageUrl': imgCtrl.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('نشر للجميع فوراً'),
          ),
        ],
      ),
    );
  }

  Widget _buildLandmarkCard(LandmarkItem item, {VoidCallback? onDeleteCloud}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(item.title,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.bold))),
                if (widget.isAdmin && onDeleteCloud != null)
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: onDeleteCloud),
              ],
            ),
            if (item.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(item.imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Text('تعذر تحميل الصورة')),
              ),
            ],
            const SizedBox(height: 8),
            Text(item.article,
                style: const TextStyle(fontSize: 16, height: 1.6)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (item.gps.isNotEmpty)
                  ElevatedButton.icon(
                      icon: const Icon(Icons.location_on, size: 18),
                      label: const Text('الموقع GPS'),
                      onPressed: () => openGpsMap(context, item.gps)),
                if (item.videoUrl.isNotEmpty)
                  ElevatedButton.icon(
                      icon: const Icon(Icons.play_circle_fill, size: 18),
                      label: const Text('مشاهدة الفيديو'),
                      onPressed: () => launchUrl(Uri.parse(item.videoUrl),
                          mode: LaunchMode.externalApplication)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            title: Text('معالم: ${widget.title}'),
            backgroundColor: const Color(0xFF00695C),
            foregroundColor: Colors.white),
        floatingActionButton: widget.isAdmin
            ? FloatingActionButton.extended(
                onPressed: _addLandmark,
                icon: const Icon(Icons.add),
                label: const Text('نشر معلم ومقال للجميع'))
            : null,
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ...widget.landmarks.map((item) => _buildLandmarkCard(item)),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('live_items')
                  .where('type', isEqualTo: 'landmark')
                  .where('parent', isEqualTo: widget.title)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return _buildLandmarkCard(
                      LandmarkItem(
                        title: d['title'] ?? '',
                        article: d['article'] ?? '',
                        gps: d['gps'] ?? '',
                        videoUrl: d['videoUrl'] ?? '',
                        imageUrl: d['imageUrl'] ?? '',
                      ),
                      onDeleteCloud: () => doc.reference.delete(),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. شاشة الشات العام (التسجيل + موافقة المدير)
// ==========================================
class PublicChatScreen extends StatefulWidget {
  final bool isAdmin;
  const PublicChatScreen({super.key, required this.isAdmin});

  @override
  State<PublicChatScreen> createState() => _PublicChatScreenState();
}

class _PublicChatScreenState extends State<PublicChatScreen> {
  String? _userId;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _govCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _userId = prefs.getString('chat_user_id'));
  }

  Future<void> _registerUser() async {
    if (_nameCtrl.text.isEmpty ||
        _phoneCtrl.text.isEmpty ||
        _govCtrl.text.isEmpty) return;
    final doc = await FirebaseFirestore.instance.collection('chat_users').add({
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'governorate': _govCtrl.text.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_user_id', doc.id);
    setState(() => _userId = doc.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null && !widget.isAdmin) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text('التسجيل في ملتقى الزوار',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'يخضع الانضمام لموافقة مدير البرنامج لمنع دخول القاصرين والمتطفلين.'),
              const SizedBox(height: 16),
              TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل')),
              TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف')),
              TextField(
                  controller: _govCtrl,
                  decoration: const InputDecoration(labelText: 'المحافظة')),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _registerUser,
                  child: const Text('إرسال طلب الانضمام')),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: widget.isAdmin
          ? null
          : FirebaseFirestore.instance
              .collection('chat_users')
              .doc(_userId)
              .snapshots(),
      builder: (context, userSnap) {
        if (!widget.isAdmin) {
          if (!userSnap.hasData)
            return const Center(child: CircularProgressIndicator());
          if (!userSnap.data!.exists)
            return const Center(child: Text('تم حذف حسابك من قبل الإدارة.'));
          final status = userSnap.data!['status'];
          if (status == 'pending') {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'طلبك قيد المراجعة من قبل المدير (عمرو حيدر صلاح). سيتم تفعيل الشات فور القبول.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18))));
          }
          if (status == 'blocked')
            return const Center(
                child: Text('عذراً، تم حظر دخولك من قبل الإدارة.'));
        }

        final senderName = widget.isAdmin
            ? 'المدير: عمرو حيدر صلاح'
            : '${userSnap.data!['name']} (${userSnap.data!['governorate']})';

        return Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('public_chat')
                    .orderBy('time', descending: true)
                    .snapshots(),
                builder: (context, chatSnap) {
                  if (!chatSnap.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final msgs = chatSnap.data!.docs;
                  return ListView.builder(
                    reverse: true,
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final m = msgs[i];
                      return ListTile(
                        title: Text(m['sender'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.teal)),
                        subtitle: Text(m['text'] ?? '',
                            style: const TextStyle(fontSize: 16)),
                        trailing: widget.isAdmin
                            ? IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red, size: 18),
                                onPressed: () => m.reference.delete())
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _msgCtrl,
                          decoration: const InputDecoration(
                              hintText: 'اكتب رسالتك هنا...'))),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.teal),
                    onPressed: () {
                      if (_msgCtrl.text.trim().isEmpty) return;
                      FirebaseFirestore.instance.collection('public_chat').add({
                        'sender': senderName,
                        'text': _msgCtrl.text.trim(),
                        'time': FieldValue.serverTimestamp(),
                      });
                      _msgCtrl.clear();
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class AdminUserApprovalScreen extends StatelessWidget {
  const AdminUserApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إدارة وقبول أعضاء الشات')),
        body: StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance.collection('chat_users').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final users = snapshot.data!.docs;
            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, i) {
                final u = users[i];
                final data = u.data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text('${data['name']} - ${data['governorate']}'),
                    subtitle: Text(
                        'الهاتف: ${data['phone']} | الحالة: ${data['status']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            onPressed: () =>
                                u.reference.update({'status': 'approved'})),
                        IconButton(
                            icon: const Icon(Icons.block, color: Colors.orange),
                            onPressed: () =>
                                u.reference.update({'status': 'blocked'})),
                        IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => u.reference.delete()),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ==========================================
// 6. شاشة المراسلة الخاصة السرية مع المدير
// ==========================================
class DirectAdminChatScreen extends StatefulWidget {
  final bool isAdmin;
  const DirectAdminChatScreen({super.key, required this.isAdmin});

  @override
  State<DirectAdminChatScreen> createState() => _DirectAdminChatScreenState();
}

class _DirectAdminChatScreenState extends State<DirectAdminChatScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _visitorPhone;

  @override
  void initState() {
    super.initState();
    _loadVisitor();
  }

  Future<void> _loadVisitor() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _visitorPhone = prefs.getString('direct_phone'));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isAdmin) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('direct_messages')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final threads = snapshot.data!.docs;
          if (threads.isEmpty)
            return const Center(
                child: Text('لا توجد رسائل خاصة من الزوار حالياً'));

          return ListView.builder(
            itemCount: threads.length,
            itemBuilder: (context, i) {
              final thread = threads[i];
              final data = thread.data() as Map<String, dynamic>;
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(data['visitorName'] ?? 'زائر'),
                subtitle: Text('رقم هاتف المراسل: ${data['visitorPhone']}'),
                trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => thread.reference.delete()),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrivateThreadView(
                      threadId: thread.id,
                      title: '${data['visitorName']} (${data['visitorPhone']})',
                      isAdmin: true,
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    if (_visitorPhone == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('تواصل مباشر مع مدير البرنامج',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('أدخل اسمك ورقمك لبدء المحادثة الخاصة مع الإدارة.'),
            const SizedBox(height: 16),
            TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'اسمك')),
            TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم هاتفك')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) return;
                final phone = _phoneCtrl.text.trim();
                final name = _nameCtrl.text.trim();
                await FirebaseFirestore.instance
                    .collection('direct_messages')
                    .doc(phone)
                    .set({
                  'visitorName': name,
                  'visitorPhone': phone,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('direct_phone', phone);
                setState(() => _visitorPhone = phone);
              },
              child: const Text('بدء المحادثة مع المدير'),
            ),
          ],
        ),
      );
    }

    return PrivateThreadView(
        threadId: _visitorPhone!,
        title: 'محادثة خاصة مع مدير البرنامج',
        isAdmin: false);
  }
}

class PrivateThreadView extends StatelessWidget {
  final String threadId;
  final String title;
  final bool isAdmin;
  const PrivateThreadView(
      {super.key,
      required this.threadId,
      required this.title,
      required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final msgCtrl = TextEditingController();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: isAdmin ? AppBar(title: Text(title)) : null,
        body: Column(
          children: [
            if (!isAdmin)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: Colors.amber.shade100,
                child: const Text(
                    'أنت تراسل مدير البرنامج (عمرو حيدر صلاح) مباشرة',
                    textAlign: TextAlign.center),
              ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('direct_messages')
                    .doc(threadId)
                    .collection('messages')
                    .orderBy('time', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final msgs = snapshot.data!.docs;
                  return ListView.builder(
                    reverse: true,
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final m = msgs[i];
                      final fromAdmin = m['fromAdmin'] == true;
                      return Align(
                        alignment: fromAdmin
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: fromAdmin
                                ? Colors.teal.shade100
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fromAdmin ? 'مدير البرنامج' : 'الزائر',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              Text(m['text'] ?? '',
                                  style: const TextStyle(fontSize: 15)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: msgCtrl,
                          decoration: const InputDecoration(
                              hintText: 'اكتب رسالتك...'))),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.teal),
                    onPressed: () {
                      if (msgCtrl.text.trim().isEmpty) return;
                      FirebaseFirestore.instance
                          .collection('direct_messages')
                          .doc(threadId)
                          .collection('messages')
                          .add({
                        'text': msgCtrl.text.trim(),
                        'fromAdmin': isAdmin,
                        'time': FieldValue.serverTimestamp(),
                      });
                      msgCtrl.clear();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
