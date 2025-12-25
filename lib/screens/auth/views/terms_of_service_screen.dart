import 'package:flutter/material.dart';
import '../../../constants.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kullanım Şartları'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kullanım Şartları',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: defaultPadding),
            Text(
              'Buraya kullanım şartlarınızın detaylı metnini ekleyin...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

