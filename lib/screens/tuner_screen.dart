import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../features/common/providers/locale_provider.dart';
import '../../features/home/presentation/widgets/main_drawer.dart';
import '../../services/audio/tuner_service.dart';
import 'tuner/auto_tuner.dart';
import 'tuner/precision_tuner.dart';

class TunerScreen extends ConsumerStatefulWidget {
  const TunerScreen({super.key});

  @override
  ConsumerState<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends ConsumerState<TunerScreen> {
  TunerService? _tunerService;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initTuner();
  }

  Future<void> _initTuner() async {
    try {
      _tunerService = TunerService();
      await _tunerService!.init();
      await _tunerService!.start();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Tuner init error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _tunerService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        drawer: const MainDrawer(),
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              tooltip: context.tr('menu_tooltip', ref),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Text(context.tr('tune_guitar', ref)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: AppTheme.primary,
            indicatorWeight: 3,
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 24),
            labelColor: AppTheme.primary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            unselectedLabelColor: Colors.white54,
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
            tabs: [
              Tab(text: context.tr('mode_precision', ref)),
              Tab(text: context.tr('mode_auto', ref)),
            ],
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.error, size: 64),
              const SizedBox(height: 16),
              Text(
                'Tuner unavailable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _initTuner();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<TunerResult>(
      stream: _tunerService?.resultStream,
      initialData: TunerResult.silent(),
      builder: (context, snapshot) {
        final result = snapshot.data ?? TunerResult.silent();
        return TabBarView(
          children: [
            PrecisionTuner(result: result),
            AutoTuner(result: result),
          ],
        );
      },
    );
  }
}
