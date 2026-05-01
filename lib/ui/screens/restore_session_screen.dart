import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand_palette.dart';
import '../../state/app_state.dart';

class RestoreSessionScreen extends StatelessWidget {
  const RestoreSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (BuildContext context, AppState state, _) {
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: BrandPalette.pageGradient(context),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.wifi_off_rounded,
                            size: 56,
                            color: BrandPalette.primaryViolet,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Reconnect',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.errorMessage ??
                                'We could not restore your session. Please retry.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: state.isBusy
                                  ? null
                                  : state.restoreSession,
                              icon: state.isBusy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh),
                              label: Text(
                                state.isBusy ? 'Retrying...' : 'Retry',
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: state.isBusy ? null : state.logout,
                              icon: const Icon(Icons.logout),
                              label: const Text('Logout'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
