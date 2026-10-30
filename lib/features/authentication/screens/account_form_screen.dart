import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/providers/auth_provider.dart';

enum AccountAction { signUp, resetPassword }

class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, required this.action});

  final AccountAction action;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  bool get _isSignUp => widget.action == AccountAction.signUp;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final service = ref.read(firebaseServiceProvider);

      if (_isSignUp) {
        await service.signUp(
          email: _emailController.text,
          password: _passwordController.text,
        );

        if (!mounted) return;

        // firebase signs new user autommatically
        // close this route to reveal authGate's signed in screen
        Navigator.of(context).pop();
      } else {
        await service.sendPasswordReset(email: _emailController.text);

        if (!mounted) return;

        setState(() {
          _successMessage =
              'If an email/password account exists for this address, '
              'you will receive a password reset email. '
              'Please check your inbox and spam folder.';
        });
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        // keep reset response neutral incase of unknown accounts
        if (!_isSignUp && error.code == 'user-not-found') {
          _successMessage =
              'If an email/password account exists for this address, '
              'you will receive a password reset email. '
              'Please check your inbox and spam folder.';
        } else {
          _errorMessage = switch (error.code) {
            'email-already-in-use' =>
              'An account already uses this email. Try logging in.',
            'invalid-email' => 'Please enter a valid email address.',
            'weak-password' || 'password-does-not-meet-requirements' =>
              'Choose a stronger password that meets the account policy.',
            'network-request-failed' =>
              'Please check your internet connection.',
            'too-many-requests' => 'Too many requests. Please try again later.',
            _ => 'Unable to complete this request. Please try again.',
          };
        }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignUp ? 'Create account' : 'Reset password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isSignUp
                          ? 'Find your next teammates.'
                          : 'Enter your account email to request '
                                'a password reset link.',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';

                        if (!RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(email)) {
                          return 'Please enter a valid email address.';
                        }

                        return null;
                      },
                    ),
                    if (_isSignUp) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          helperText: 'Use at least 6 characters.',
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Use at least 6 characters.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        enabled: !_isLoading,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match.';
                          }

                          return null;
                        },
                      ),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (_successMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(_successMessage!),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: Text(
                        _isSignUp ? 'Create account' : 'Send reset email',
                      ),
                    ),
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
    );
  }
}
