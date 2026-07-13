import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const DecideForMeApp());
}

class DecideForMeApp extends StatelessWidget {
  const DecideForMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Decide For Me',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedTab,
          children: const [
            CoinFlipView(),
            DiceRollView(),
            CustomChoiceView(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (i) => setState(() => _selectedTab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.monetization_on_outlined),
              selectedIcon: Icon(Icons.monetization_on),
              label: 'Coin'),
          NavigationDestination(
              icon: Icon(Icons.casino_outlined),
              selectedIcon: Icon(Icons.casino),
              label: 'Dice'),
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Custom'),
        ],
      ),
    );
  }
}

class CoinFlipView extends StatefulWidget {
  const CoinFlipView({super.key});

  @override
  State<CoinFlipView> createState() => _CoinFlipViewState();
}

class _CoinFlipViewState extends State<CoinFlipView>
    with SingleTickerProviderStateMixin {
  final _random = Random();
  late AnimationController _controller;
  String? _result;
  bool _isFlipping = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isFlipping) return;
    setState(() => _isFlipping = true);
    HapticFeedback.mediumImpact();

    _controller.forward(from: 0).then((_) {
      setState(() {
        _result = _random.nextBool() ? 'Heads' : 'Tails';
        _isFlipping = false;
      });
      HapticFeedback.heavyImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Coin Flip', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 48),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final rotations = _controller.value * 6;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(rotations * 3.14159),
                child: child,
              );
            },
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _result ?? '?',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: _isFlipping ? null : _flip,
            icon: const Icon(Icons.flip),
            label: const Text('Flip'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class DiceRollView extends StatefulWidget {
  const DiceRollView({super.key});

  @override
  State<DiceRollView> createState() => _DiceRollViewState();
}

class _DiceRollViewState extends State<DiceRollView>
    with SingleTickerProviderStateMixin {
  final _random = Random();
  late AnimationController _controller;
  int? _result;
  bool _isRolling = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _roll() {
    if (_isRolling) return;
    setState(() => _isRolling = true);
    HapticFeedback.mediumImpact();

    _controller.forward(from: 0).then((_) {
      setState(() {
        _result = _random.nextInt(6) + 1;
        _isRolling = false;
      });
      HapticFeedback.heavyImpact();
    });
  }

  static const _diceFaces = ['', '⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Dice Roll', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 48),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 6.28,
                child: child,
              );
            },
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: theme.colorScheme.secondaryContainer,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _result != null ? _diceFaces[_result!] : '?',
                  style: TextStyle(
                    fontSize: _result != null ? 80 : 48,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: _isRolling ? null : _roll,
            icon: const Icon(Icons.casino),
            label: const Text('Roll'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomChoiceView extends StatefulWidget {
  const CustomChoiceView({super.key});

  @override
  State<CustomChoiceView> createState() => _CustomChoiceViewState();
}

class _CustomChoiceViewState extends State<CustomChoiceView> {
  final _random = Random();
  final _controller = TextEditingController();
  final _choices = <String>[];
  String? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addChoice() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _choices.add(text);
      _controller.clear();
      _result = null;
    });
  }

  void _decide() {
    if (_choices.length < 2) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _result = _choices[_random.nextInt(_choices.length)];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Custom Choice', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Add an option...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addChoice(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addChoice,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _choices.isEmpty
                ? Center(
                    child: Text(
                      'Add at least 2 options',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _choices.length,
                    itemBuilder: (context, i) {
                      final isWinner = _result == _choices[i];
                      return Card(
                        color: isWinner
                            ? theme.colorScheme.primaryContainer
                            : null,
                        child: ListTile(
                          leading: isWinner
                              ? Icon(Icons.star,
                                  color: theme.colorScheme.primary)
                              : null,
                          title: Text(
                            _choices[i],
                            style: isWinner
                                ? TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  )
                                : null,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() {
                              _choices.removeAt(i);
                              _result = null;
                            }),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _result!,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: _choices.length >= 2 ? _decide : null,
            icon: const Icon(Icons.shuffle),
            label: const Text('Decide For Me'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) => builder(context, child);
}
