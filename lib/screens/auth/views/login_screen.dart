import 'package:flutter/material.dart';
import 'package:gtu/constants.dart';
import 'package:gtu/route/route_constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'components/login_form.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        // Kullanıcı giriş yapmadan önce disabled durumunu kontrol et
        final userData = await DatabaseHelper().getUserData(_emailController.text);
        if (userData['disabled'] == true) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bu hesap yönetici tarafından devre dışı bırakılmıştır. '
                  'Lütfen yönetici ile iletişime geçin.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          // Eğer kullanıcı hala giriş yapmışsa çıkış yaptır
          await FirebaseAuth.instance.signOut();
          return;
        }

        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        
        if (userCredential.user != null && !userCredential.user!.emailVerified) {
          final bool? sendNewVerification = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('E-posta Doğrulanmamış'),
                content: Text('E-posta adresiniz henüz doğrulanmamış. Yeni bir doğrulama e-postası göndermek ister misiniz?'),
                actions: <Widget>[
                  TextButton(
                    child: Text('Hayır'),
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                  ),
                  TextButton(
                    child: Text('Evet'),
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                  ),
                ],
              );
            },
          );

          if (sendNewVerification == true) {
            await userCredential.user!.sendEmailVerification();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Yeni doğrulama e-postası gönderildi. Lütfen e-postanızı kontrol edin.')),
            );
          }
          
          await FirebaseAuth.instance.signOut();
        } else if (userCredential.user != null && userCredential.user!.emailVerified) {
          await DatabaseHelper().updateEmailVerificationStatus(userCredential.user!.email!, true);
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('email', userCredential.user!.email!);
          
          if (userCredential.user!.displayName == null || userCredential.user!.displayName!.isEmpty) {
            Navigator.pushReplacementNamed(context, setUsernameScreenRoute);
          } else {
            await prefs.setString('username', userCredential.user!.displayName!);
            Navigator.pushNamedAndRemoveUntil(context, entryPointScreenRoute, (route) => false);
          }
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        if (e.code == 'user-not-found') {
          errorMessage = 'Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Yanlış şifre girildi.';
        } else {
          errorMessage = 'Giriş yapılırken bir hata oluştu. Lütfen tekrar deneyin.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Image.asset(
                  "assets/images/gtu_logo.jpg",
                  fit: BoxFit.contain,
                ),
              ),
              Container(
                height: 5,
                color: primaryColor,
              ),
              Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Kampüse Hoşgeldin!",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: defaultPadding / 2),
                    const Text(
                      "Kayıt olduğunuz mailiniz ile giriş yapınız.",
                    ),
                    const SizedBox(height: defaultPadding),
                    LogInForm(
                      formKey: _formKey,
                      emailController: _emailController,
                      passwordController: _passwordController,
                    ),
                    Align(
                      child: TextButton(
                        child: const Text("Şifremi unuttum"),
                        onPressed: () {
                          Navigator.pushNamed(
                              context, passwordRecoveryScreenRoute);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      child: _isLoading
                          ? CircularProgressIndicator()
                          : const Text("Giriş yap"),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Hesabın yok mu?"),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, signUpScreenRoute);
                          },
                          child: const Text("Kayıt ol"),
                        )
                      ],
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
}
