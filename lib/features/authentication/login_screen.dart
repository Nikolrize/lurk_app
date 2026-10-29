import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../providers/auth_provider.dart';
import 'account_form_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _hidePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login({required bool withGoogle}) async {
    if (_isLoading) return;

    if (!withGoogle && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(firebaseServiceProvider);

      if (withGoogle) {
        await service.signInWithGoogle();
      } else {
        await service.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      // authgate handles screen change when firebase emits user
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = switch (error.code) {
          'invalid-email' => 'Please enter a valid email address.',
          'invalid-credential' ||
          'wrong-password' ||
          'user-not-found' => 'The email or password is incorrect.',
          'user-disabled' => 'This account has been disabled.',
          'too-many-requests' => 'Too many attempts. Please try again later.',
          'network-request-failed' => 'Please check your internet connection.',
          'popup-blocked' => 'Your browser blocked the Google sign-in popup.',
          'popup-closed-by-user' || 'cancelled-popup-request' => null,
          'account-exists-with-different-credential' =>
            'Use your existing sign-in method for this email.',
          _ => 'Unable to sign in. Please try again.',
        };
      });
    } on GoogleSignInException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.code == GoogleSignInExceptionCode.canceled
            ? null
            : 'Google sign-in failed. Please try again';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final supportsGoogle =
        kIsWeb || defaultTargetPlatform == TargetPlatform.android;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/lurk_logo.png',
                            width: 140,
                            height: 140,
                            fit: BoxFit.contain,
                            semanticLabel: 'Lurk logo',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your next lobby starts here.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Welcome back',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';

                          if (email.isEmpty) {
                            return 'Please enter your email.';
                          }

                          if (!RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(email)) {
                            return 'Please enter a valid email address.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: _hidePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _hidePassword = !_hidePassword;
                                    });
                                  },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password.';
                          }

                          return null;
                        },
                        onFieldSubmitted: (_) {
                          _login(withGoogle: false);
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isLoading
                            ? null
                            : () => _login(withGoogle: false),
                        child: const Text('Log in'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const AccountFormScreen(
                                      action: AccountAction.resetPassword,
                                    ),
                                  ),
                                );
                              },
                        child: const Text('Forgot password?'),
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const AccountFormScreen(
                                      action: AccountAction.signUp,
                                    ),
                                  ),
                                );
                              },
                        child: const Text('New to Lurk? Create account'),
                      ),
                      if (supportsGoogle) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _login(withGoogle: true),
                          child: const Text('Continue with Google'),
                        ),
                      ],
                      if (_isLoading) ...[
                        const SizedBox(height: 20),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  } // build()
} // _loginScreenState
