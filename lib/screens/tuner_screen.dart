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
  final TunerService _tunerService = TunerService();

  @override
  void initState() {
    super.initState();
    _initTuner();
  }

  Future<void> _initTuner() async {
    await _tunerService.init();
    try {
      await _tunerService.start();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting tuner: $e')));
      }
    }
  }

  @override
  void dispose() {
    _tunerService.dispose();
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
        body: StreamBuilder<TunerResult>(
          stream: _tunerService.resultStream,
          initialData: TunerResult.silent(),
          builder: (context, snapshot) {
            final result = snapshot.data!;
            return TabBarView(
              children: [
                PrecisionTuner(result: result),
                AutoTuner(result: result),
              ],
            );
          },
        ),
      ),
    );
  }
}
