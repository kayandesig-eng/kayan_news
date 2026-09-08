import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const KayanNewsApp());
}

class KayanNewsApp extends StatelessWidget {
  const KayanNewsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KAYAN NEWS',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFF081017),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF35D5C4),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}

/* =========================================================
   نموذج الخبر
   ========================================================= */

class NewsArticle {
  final String title;
  final String description;
  final String link;
  final String source;
  final String pubDate;
  final String? imageUrl;
  final String category;

  const NewsArticle({
    required this.title,
    required this.description,
    required this.link,
    required this.source,
    required this.pubDate,
    required this.imageUrl,
    required this.category,
  });
}

/* =========================================================
   خدمة الأخبار RSS
   ========================================================= */

class NewsService {
  static const Map<String, String> feeds = {
    'محلي':
        'https://news.google.com/rss/search?q=اليمن&hl=ar&gl=YE&ceid=YE:ar',
    'عربي':
        'https://news.google.com/rss/search?q=العالم%20العربي&hl=ar&gl=YE&ceid=YE:ar',
    'عالمي':
        'https://news.google.com/rss/search?q=العالم&hl=ar&gl=YE&ceid=YE:ar',
    'سياسة':
        'https://news.google.com/rss/search?q=سياسة&hl=ar&gl=YE&ceid=YE:ar',
    'رياضة':
        'https://news.google.com/rss/search?q=رياضة&hl=ar&gl=YE&ceid=YE:ar',
    'منوعات':
        'https://news.google.com/rss/search?q=منوعات&hl=ar&gl=YE&ceid=YE:ar',
  };

  Future<List<NewsArticle>> fetchCategory(String category) async {
    final url = feeds[category];

    if (url == null) {
      return [];
    }

    final response = await http
        .get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'KAYAN NEWS/1.0',
            'Accept': 'application/rss+xml, application/xml',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('تعذر الاتصال بمصدر الأخبار');
    }

    final document = XmlDocument.parse(response.body);
    final items = document.findAllElements('item');

    final List<NewsArticle> articles = [];

    for (final item in items) {
      final title = _cleanText(
        item.getElement('title')?.innerText ?? '',
      );

      final description = _cleanHtml(
        item.getElement('description')?.innerText ?? '',
      );

      final link = item.getElement('link')?.innerText.trim() ?? '';

      final source = _cleanText(
        item.getElement('source')?.innerText ?? 'KAYAN NEWS',
      );

      final pubDate = item.getElement('pubDate')?.innerText.trim() ?? '';

      final imageUrl = _extractImage(
        item.getElement('description')?.innerText ?? '',
      );

      if (title.isEmpty || link.isEmpty) {
        continue;
      }

      articles.add(
        NewsArticle(
          title: title,
          description: description.isEmpty
              ? 'اضغط لقراءة تفاصيل الخبر كاملة.'
              : description,
          link: link,
          source: source.isEmpty ? 'مصدر إخباري' : source,
          pubDate: pubDate,
          imageUrl: imageUrl,
          category: category,
        ),
      );
    }

    articles.sort((a, b) {
      final dateA = DateTime.tryParse(a.pubDate) ??
          _parseDate(a.pubDate) ??
          DateTime(2000);

      final dateB = DateTime.tryParse(b.pubDate) ??
          _parseDate(b.pubDate) ??
          DateTime(2000);

      return dateB.compareTo(dateA);
    });

    return _removeDuplicates(articles);
  }

  Future<List<NewsArticle>> fetchAll() async {
    final results = await Future.wait(
      feeds.keys.map(
        (category) => fetchCategory(category),
      ),
    );

    final List<NewsArticle> all = [];

    for (final list in results) {
      all.addAll(list);
    }

    all.sort((a, b) {
      final dateA = _parseDate(a.pubDate) ?? DateTime(2000);
      final dateB = _parseDate(b.pubDate) ?? DateTime(2000);

      return dateB.compareTo(dateA);
    });

    return _removeDuplicates(all);
  }

  static List<NewsArticle> _removeDuplicates(
    List<NewsArticle> articles,
  ) {
    final seen = <String>{};
    final result = <NewsArticle>[];

    for (final article in articles) {
      final key = article.link.isNotEmpty
          ? article.link
          : article.title;

      if (seen.add(key)) {
        result.add(article);
      }
    }

    return result;
  }

  static DateTime? _parseDate(String value) {
    if (value.isEmpty) return null;

    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {}

    try {
      return DateTime.tryParse(value);
    } catch (_) {
      return null;
    }
  }

  static String? _extractImage(String html) {
    final patterns = [
      RegExp(
        r'''<img[^>]+src=["']([^"']+)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''src=["'](https?://[^"']+)["']''',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);

      if (match != null) {
        final url = match.group(1);

        if (url != null && url.startsWith('http')) {
          return url;
        }
      }
    }

    return null;
  }

  static String _cleanHtml(String text) {
    var value = text;

    value = value.replaceAll(
      RegExp(r'<[^>]*>', multiLine: true),
      ' ',
    );

    value = value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');

    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _cleanText(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}

/* =========================================================
   الصفحة الرئيسية
   ========================================================= */

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final NewsService newsService = NewsService();

  final List<String> categories = [
    'الكل',
    'محلي',
    'عربي',
    'عالمي',
    'سياسة',
    'رياضة',
    'منوعات',
  ];

  String selectedCategory = 'الكل';

  List<NewsArticle> articles = [];
  List<NewsArticle> allArticles = [];

  bool loading = true;
  String? errorMessage;

  final Set<String> savedLinks = {};

  int bottomIndex = 0;

  @override
  void initState() {
    super.initState();
    loadNews();
  }

  Future<void> loadNews() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      if (selectedCategory == 'الكل') {
        allArticles = await newsService.fetchAll();
        articles = allArticles;
      } else {
        articles = await newsService.fetchCategory(
          selectedCategory,
        );
      }

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage =
            'تعذر تحميل الأخبار.\nتحقق من اتصال الإنترنت وحاول مرة أخرى.';
      });
    }
  }

  Future<void> selectCategory(String category) async {
    setState(() {
      selectedCategory = category;
    });

    await loadNews();
  }

  void openArticle(NewsArticle article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArticleDetailPage(
          article: article,
          isSaved: savedLinks.contains(article.link),
          onSave: () {
            setState(() {
              if (savedLinks.contains(article.link)) {
                savedLinks.remove(article.link);
              } else {
                savedLinks.add(article.link);
              }
            });
          },
        ),
      ),
    );
  }

  List<NewsArticle> get savedArticles {
    final source = [
      ...articles,
      ...allArticles,
    ];

    final unique = <String, NewsArticle>{};

    for (final article in source) {
      if (savedLinks.contains(article.link)) {
        unique[article.link] = article;
      }
    }

    return unique.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: bottomIndex,
          children: [
            buildNewsPage(),
            buildNewsPage(),
            buildSavedPage(),
            buildAccountPage(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomIndex,
        backgroundColor: const Color(0xFF0B151C),
        indicatorColor: const Color(0xFF183D3A),
        onDestinationSelected: (index) {
          setState(() {
            bottomIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper),
            label: 'الأخبار',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'المحفوظات',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }

  Widget buildNewsPage() {
    return RefreshIndicator(
      onRefresh: loadNews,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                16,
                18,
                8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'KAYAN NEWS',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الأخبار أولاً بأول',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      showSearch(
                        context: context,
                        delegate: NewsSearchDelegate(
                          articles: articles,
                          onOpen: openArticle,
                        ),
                      );
                    },
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    onPressed: loadNews,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final selected =
                      category == selectedCategory;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 7,
                    ),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: selected,
                      onSelected: (_) {
                        selectCategory(category);
                      },
                      selectedColor:
                          const Color(0xFF35D5C4),
                      backgroundColor:
                          const Color(0xFF121D24),
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.black
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          if (loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (errorMessage != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        size: 60,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: loadNews,
                        icon: const Icon(Icons.refresh),
                        label: const Text(
                          'إعادة المحاولة',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (articles.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'لا توجد أخبار حالياً',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildListDelegate([
                buildSectionTitle(),

                buildHeroArticle(articles.first),

                const SizedBox(height: 22),

                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 18,
                  ),
                  child: Text(
                    'آخر الأخبار',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                ...articles.skip(1).map(
                      (article) => NewsCard(
                        article: article,
                        saved: savedLinks
                            .contains(article.link),
                        onTap: () =>
                            openArticle(article),
                        onSave: () {
                          setState(() {
                            if (savedLinks
                                .contains(article.link)) {
                              savedLinks
                                  .remove(article.link);
                            } else {
                              savedLinks
                                  .add(article.link);
                            }
                          });
                        },
                      ),
                    ),

                const SizedBox(height: 30),
              ]),
            ),
        ],
      ),
    );
  }

  Widget buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        18,
        18,
        10,
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 25,
            decoration: BoxDecoration(
              color: const Color(0xFF35D5C4),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            selectedCategory == 'الكل'
                ? 'أحدث الأخبار'
                : 'أخبار $selectedCategory',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeroArticle(NewsArticle article) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      child: GestureDetector(
        onTap: () => openArticle(article),
        child: Container(
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: const Color(0xFF12212A),
            boxShadow: [
              BoxShadow(
                blurRadius: 15,
                color: Colors.black.withOpacity(.25),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (article.imageUrl != null)
                Image.network(
                  article.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return buildImagePlaceholder();
                  },
                )
              else
                buildImagePlaceholder(),

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(.85),
                    ],
                  ),
                ),
              ),

              Positioned(
                left: 16,
                right: 16,
                bottom: 18,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF35D5C4),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Text(
                        article.category,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildImagePlaceholder() {
    return Container(
      color: const Color(0xFF17262F),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 55,
          color: Color(0xFF42616A),
        ),
      ),
    );
  }

  Widget buildSavedPage() {
    final saved = savedArticles;

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'المحفوظات',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (saved.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 65,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 15),
                  Text(
                    'لا توجد أخبار محفوظة',
                    style: TextStyle(fontSize: 17),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final article = saved[index];

                return NewsCard(
                  article: article,
                  saved: true,
                  onTap: () => openArticle(article),
                  onSave: () {
                    setState(() {
                      savedLinks.remove(article.link);
                    });
                  },
                );
              },
              childCount: saved.length,
            ),
          ),
      ],
    );
  }

  Widget buildAccountPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 40,
            child: Icon(
              Icons.person,
              size: 45,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'KAYAN NEWS',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'منصة إخبارية عربية',
            style: TextStyle(
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

/* =========================================================
   بطاقة الخبر
   ========================================================= */

class NewsCard extends StatelessWidget {
  final NewsArticle article;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onSave;

  const NewsCard({
    super.key,
    required this.article,
    required this.saved,
    required this.onTap,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 7,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF101C23),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(.05),
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(14),
                child: SizedBox(
                  width: 105,
                  height: 105,
                  child: article.imageUrl != null
                      ? Image.network(
                          article.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) {
                            return placeholder();
                          },
                        )
                      : placeholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF193A38,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              10,
                            ),
                          ),
                          child: Text(
                            article.category,
                            style: const TextStyle(
                              color: Color(
                                0xFF6DE4D5,
                              ),
                              fontSize: 10,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          visualDensity:
                              VisualDensity.compact,
                          onPressed: onSave,
                          icon: Icon(
                            saved
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            size: 21,
                            color: saved
                                ? const Color(
                                    0xFF35D5C4,
                                  )
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.source,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget placeholder() {
    return Container(
      color: const Color(0xFF17262F),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 38,
          color: Color(0xFF42616A),
        ),
      ),
    );
  }
}

/* =========================================================
   صفحة تفاصيل الخبر
   ========================================================= */

class ArticleDetailPage extends StatelessWidget {
  final NewsArticle article;
  final bool isSaved;
  final VoidCallback onSave;

  const ArticleDetailPage({
    super.key,
    required this.article,
    required this.isSaved,
    required this.onSave,
  });

  Future<void> openOriginal() async {
    final uri = Uri.tryParse(article.link);

    if (uri == null) return;

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  String formatDate(String value) {
    if (value.isEmpty) {
      return 'الآن';
    }

    try {
      final date = DateTime.parse(value).toLocal();

      return '${date.day}/${date.month}/${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تفاصيل الخبر',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: onSave,
            icon: Icon(
              isSaved
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              color: isSaved
                  ? const Color(0xFF35D5C4)
                  : null,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            if (article.imageUrl != null)
              Image.network(
                article.imageUrl!,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return detailPlaceholder();
                },
              )
            else
              detailPlaceholder(),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF193A38,
                          ),
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Text(
                          article.category,
                          style: const TextStyle(
                            color: Color(
                              0xFF6DE4D5,
                            ),
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.schedule,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          formatDate(article.pubDate),
                          style: TextStyle(
                            color:
                                Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Text(
                    article.title,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 15),

                  Row(
                    children: [
                      const Icon(
                        Icons.public,
                        size: 18,
                        color: Color(0xFF35D5C4),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          article.source,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  Text(
                    article.description,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.8,
                      color: Colors.grey.shade200,
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: openOriginal,
                      icon: const Icon(
                        Icons.open_in_new,
                      ),
                      label: const Text(
                        'قراءة الخبر كاملاً من المصدر',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: onSave,
                      icon: Icon(
                        isSaved
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                      ),
                      label: Text(
                        isSaved
                            ? 'إزالة من المحفوظات'
                            : 'حفظ الخبر',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget detailPlaceholder() {
    return Container(
      width: double.infinity,
      height: 250,
      color: const Color(0xFF17262F),
      child: const Center(
        child: Icon(
          Icons.newspaper,
          size: 70,
          color: Color(0xFF42616A),
        ),
      ),
    );
  }
}

/* =========================================================
   البحث
   ========================================================= */

class NewsSearchDelegate
    extends SearchDelegate<NewsArticle?> {
  final List<NewsArticle> articles;
  final Function(NewsArticle) onOpen;

  NewsSearchDelegate({
    required this.articles,
    required this.onOpen,
  });

  @override
  String get searchFieldLabel => 'ابحث في الأخبار';

  @override
  List<Widget>? buildActions(
    BuildContext context,
  ) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () {
            query = '';
          },
          icon: const Icon(Icons.clear),
        ),
    ];
  }

  @override
  Widget? buildLeading(
    BuildContext context,
  ) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return buildSearchResults();
  }

  Widget buildSearchResults() {
    final search = query.trim().toLowerCase();

    final results = articles.where((article) {
      return article.title
              .toLowerCase()
              .contains(search) ||
          article.source
              .toLowerCase()
              .contains(search) ||
          article.category
              .toLowerCase()
              .contains(search);
    }).toList();

    if (results.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد نتائج',
          style: TextStyle(fontSize: 17),
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final article = results[index];

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: CircleAvatar(
            backgroundColor:
                const Color(0xFF183D3A),
            child: const Icon(
              Icons.article,
              color: Color(0xFF35D5C4),
            ),
          ),
          title: Text(
            article.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            article.source,
          ),
          onTap: () {
            close(context, article);
            onOpen(article);
          },
        );
      },
    );
  }
}
