import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hn_app/src/article.dart';
import 'package:hn_app/src/favorites.dart';
import 'package:hn_app/src/notifiers/hn_api.dart';
import 'package:hn_app/src/notifiers/prefs.dart';
import 'package:hn_app/src/pages/example.dart';
import 'package:hn_app/src/pages/favorites.dart';
import 'package:hn_app/src/pages/settings.dart';
import 'package:hn_app/src/widgets/headline.dart';
import 'package:hn_app/src/widgets/hn_page.dart';
import 'package:hn_app/src/widgets/loading_info.dart';
import 'package:hn_app/src/widgets/search.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  // Set up logging to console. (In production, this might go to
  // a rotating log, so that it can be sent to an analytics service
  // when problems arise.)
  Logger.root.level = Level.FINE; // Default is Level.INFO.
  Logger.root.onRecord.listen((record) {
    print('[${record.level.name}] ${record.loggerName} '
        '-- ${record.time} -- ${record.message}');
  });

  runApp(
    MultiProvider(
      providers: [
        ListenableProvider<LoadingTabsCount>(
          create: (_) => LoadingTabsCount(),
          dispose: (_, value) => value.dispose(),
        ),
        Provider<MyDatabase>(create: (_) => MyDatabase()),
        ChangeNotifierProvider(
          create: (context) => HackerNewsNotifier(
            // TODO(filiph): revisit when ProxyProvider lands
            // https://github.com/rrousselGit/provider/issues/46
            Provider.of<LoadingTabsCount>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider(create: (_) => PrefsNotifier()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  static const primaryColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      darkTheme: ThemeData.dark(),
      theme: ThemeData(
        brightness: Provider.of<PrefsNotifier>(context).userDarkMode
            ? Brightness.dark
            : Brightness.light,
        canvasColor: Theme.of(context).brightness == Brightness.dark ||
                Provider.of<PrefsNotifier>(context).userDarkMode
            ? Colors.black
            : Colors.white,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: primaryColor,
        textTheme: TextTheme(
          caption: TextStyle(color: Colors.white54),
          button: GoogleFonts.boogaloo(fontSize: 18),
          subtitle1: GoogleFonts.boogaloo(fontSize: 24),
        ),
      ),
      onGenerateRoute: (settings) {
        print('--------------> ${settings.name} ${settings.arguments}');
        switch (settings.name) {
          case '/examples':
            // return PageRouteBuilder(
            //   settings: settings,
            //     pageBuilder: (context, animation, secondaryAnimation) {
            //   return ExamplePage();
            // });
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => ExamplePage(),
            );
          case '/':
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => MyHomePage(),
            );
          case '/favorites':
            // return PageRouteBuilder(
            //   settings: settings,
            //     pageBuilder: (context, animation, secondaryAnimation) {
            //   return FavoritesPage();
            // });
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => FavoritesPage(),
            );
          case '/settings':
            return PageRouteBuilder(
              settings: settings,
              pageBuilder: (context, animation, secondaryAnimation) {
                return SettingsPage(animation);
              },
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: animation.drive(
                      Tween(begin: 1.3, end: 1.0).chain(
                        CurveTween(curve: Curves.easeOutCubic),
                      ),
                    ),
                    child: child,
                  ),
                );
              },
            );
            
          
          default:
            throw UnimplementedError('no route for $settings');
        }
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

/// The Key of the nested Navigator in the body of [_MyHomePageState].
///
/// It's a GlobalKey because we need to access it from the drawer (which is
/// outside the body).
GlobalKey<NavigatorState> _pageNavigatorKey = GlobalKey<NavigatorState>();

class _MyHomePageState extends State<MyHomePage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    _pageController.addListener(_handlePageChange);
    super.initState();
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageChange);
    super.dispose();
  }

  void _handlePageChange() {
    final newIndex = _pageController.page!.round();

    if (_currentIndex != newIndex) {
      print('=====>, $_currentIndex $newIndex');
      setState(() {
        _currentIndex = newIndex;
      });

      final hn = context.read<HackerNewsNotifier>();
      final tabs = hn.tabs;
      final current = tabs[_currentIndex];
      print('@@@@@@@@@@@@@@@ ${tabs[_currentIndex]}');

      if (current.articles.isEmpty && !current.isLoading) {
        // New tab with no data. Let's fetch some.
        current.refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hn = context.watch<HackerNewsNotifier>();
    final tabs = hn.tabs;

    return Scaffold(
      drawerEnableOpenDragGesture: false,
      appBar: AppBar(
        title: Headline(
          text: tabs[_currentIndex].name,
          index: _currentIndex,
        ),
        elevation: 0.0,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () async {
              var result = await showSearch(
                context: context,
                delegate: ArticleSearch(hn.allArticles),
              );
              if (result != null) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => HackerNewsWebPage(result.url)));
              }
            },
          ),
        ],
        leading: Consumer<LoadingTabsCount>(builder: (context, loading, child) {
          bool isLoading = loading.value > 0;
          return AnimatedSwitcher(
            duration: Duration(milliseconds: 500),
            child: isLoading
                // TODO: make sure that LoadingInfo is rotating when shown
                //       or, better, collapse the two alternate widgets into one
                ? LoadingInfo(loading)
                : IconButton(
                    icon: Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
          );
        }),
      ),
      // A nested navigator so we can push routes in the body from the drawer.
      body: Navigator(
        key: _pageNavigatorKey,
        onGenerateRoute: (settings) {
          // TODO: use PageRouteBuilders below instead of MaterialPageRoute
          //       and merely cross-fade the routes
          print('000000000 settings name , $settings');
          if (settings.name == '/favorites') {
            return MaterialPageRoute(
              builder: (context) => FavoritesPage(),
            );
          }

          return MaterialPageRoute(
            builder: (context) => PageView.builder(
              controller: _pageController,
              itemCount: tabs.length,
              itemBuilder: (context, index) => ChangeNotifierProvider.value(
                value: tabs[index],
                child: _TabPage(index),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        currentIndex: _currentIndex,
        items: [
          for (final tab in tabs)
            BottomNavigationBarItem(
              label: tab.name,
              icon: Icon(tab.icon),
            )
        ],
        onTap: (index) {
          print('Tab clicked $index');
          _pageController.animateToPage(index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic);
          setState(() {
            _currentIndex = index;
          });
          print('++++++++ =======> ${_pageNavigatorKey.currentState?.maybePop()}');
          _pageNavigatorKey.currentState?.popUntil((route) {
            print('!!!!!!!!!!!!!!!!!!!!! ${route.settings.name}');
            return route.isFirst;
          });
        },
      ),

      drawer: Drawer(
        child: Container(
          child: ListView(
            children: <Widget>[
              DrawerHeader(
                child: Text('HN APP'),
              ),
              ListTile(
                title: Text('Favorites'),
                onTap: () {
                  print('button clicked');
                  // TODO Figure out why past devs wanted to do a replacement.
                  _pageNavigatorKey.currentState?.pushNamed('/favorites');
                  Navigator.pop(context);
                  // Navigator.pushNamed(context, '/favorites');
                },
              ),
              ListTile(
                title: Text('Settings'),
                onTap: () => Navigator.pushNamed(context, '/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final Article article;
  final PrefsNotifier prefs;

  const _Item({
    Key? key,
    required this.article,
    required this.prefs,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final prefs = Provider.of<PrefsNotifier>(context);
    var myDatabase = Provider.of<MyDatabase>(context);
    assert(article.title != null);
    return Padding(
      key: PageStorageKey(article.title),
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 12.0),
      child: Column(
        children: <Widget>[
          ExpansionTile(
            leading: StreamBuilder<bool>(
                stream: myDatabase.isFavorite(article.id),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!) {
                    return IconButton(
                        icon: Icon(Icons.star),
                        onPressed: () => myDatabase.removeFavorite(article.id));
                  }
                  return IconButton(
                      icon: Icon(Icons.star_border),
                      onPressed: () => myDatabase.addFavorite(article));
                }),
            title: Text(article.title!),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(left: 46),
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (BuildContext context) =>
                                    HackerNewsCommentPage(article.id),
                              ),
                            ),
                            child: Text('${article.descendants} comments'),
                          ),
                        ),
                        SizedBox(width: 16.0),
                        IconButton(
                          icon: Icon(Icons.launch),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      HackerNewsWebPage(article.url))),
                        )
                      ],
                    ),
                    prefs.showWebView
                        ? Container(
                            height: 200,
                            child: WebView(
                              javascriptMode: JavascriptMode.unrestricted,
                              initialUrl: article.url,
                              gestureRecognizers: Set()
                                ..add(Factory<VerticalDragGestureRecognizer>(
                                    () => VerticalDragGestureRecognizer())),
                            ),
                          )
                        : Container(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabPage extends StatelessWidget {
  final int index;

  _TabPage(this.index, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tab = Provider.of<HackerNewsTab>(context);
    final articles = tab.articles;
    final prefs = Provider.of<PrefsNotifier>(context);

    if (tab.isLoading && articles.isEmpty) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: Colors.black,
      onRefresh: () => tab.refresh(),
      child: ListView(
        key: PageStorageKey(index),
        children: [
          for (final article in articles)
            _Item(
              article: article,
              prefs: prefs,
            )
        ],
      ),
    );
  }
}

class HackerNewsCommentPage extends StatelessWidget {
  final int id;

  HackerNewsCommentPage(this.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comments'),
      ),
      body: WebView(
        initialUrl: 'https://news.ycombinator.com/item?id=$id',
        javascriptMode: JavascriptMode.unrestricted,
      ),
    );
  }
}
