import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/brand_palette.dart';
import '../../state/app_state.dart';
import 'api_base_url_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _submitting = false;

  int _logoTapCount = 0;
  DateTime? _lastLogoTapAt;

  void _handleLogoTap() {
    final now = DateTime.now();
    final last = _lastLogoTapAt;
    _lastLogoTapAt = now;

    if (last == null || now.difference(last) > const Duration(seconds: 2)) {
      _logoTapCount = 0;
    }

    _logoTapCount += 1;
    if (_logoTapCount >= 6) {
      _logoTapCount = 0;
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const ApiBaseUrlScreen()));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await context.read<AppState>().login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_loginMessageFromError(error))));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed, try again later')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _loginMessageFromError(ApiException error) {
    final message = error.message.toLowerCase();
    if (error.statusCode == 401 ||
        error.statusCode == 404 ||
        message.contains('invalid email or password')) {
      return 'Login data not found';
    }
    return 'Login failed, try again later';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: BrandPalette.pageGradient(context),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _handleLogoTap,
                            child: const Icon(
                              Icons.medication_outlined,
                              size: 56,
                              color: BrandPalette.primaryViolet,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'MedReminder Mobile',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in with your Gmail account',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'yourname@gmail.com',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (String? value) {
                              final email = (value ?? '').trim().toLowerCase();
                              if (email.isEmpty) {
                                return 'Email is required';
                              }
                              if (!email.endsWith('@gmail.com')) {
                                return 'Only Gmail addresses are supported';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (String? value) {
                              if ((value ?? '').isEmpty) {
                                return 'Password is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(
                              _submitting ? 'Signing In...' : 'Sign In',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const SignupScreen(),
                                      ),
                                    );
                                  },
                            child: const Text('Create a new account'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
