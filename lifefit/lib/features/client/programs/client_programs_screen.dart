import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ui/app_colors.dart';
import 'client_program_detail_screen.dart';
import 'client_programs_provider.dart';
import 'widgets/program_card.dart';
import 'widgets/stats_banner.dart';
import 'widgets/program_empty_view.dart';
import 'widgets/program_error_view.dart';

/// Screen displaying a list of training programs assigned to the client.
class ClientProgramsScreen extends ConsumerWidget {
  const ClientProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientProgramsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'برامجي التدريبية',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
        ),
        error: (e, _) => ProgramErrorView(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.read(clientProgramsProvider.notifier).refresh(),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const ProgramEmptyView();
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(clientProgramsProvider.notifier).refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${list.length} برنامج مخصّص لك',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ),
                ),

                // Stats Banner showing overview of programs progress
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                    child: ProgramsStatsBanner(programs: list),
                  ),
                ),

                // Section title for the list
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'جميع البرامج',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.fitness_center, size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),

                // List of training programs cards
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => ProgramSummaryCard(
                        item: list[i],
                        imageUrl: list[i].trainerImage,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ClientProgramDetailScreen(
                              assignmentId: list[i].id,
                            ),
                          ),
                        ),
                      ),
                      childCount: list.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

