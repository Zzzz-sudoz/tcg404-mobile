import 'package:flutter/material.dart';

void main() => runApp(
  MaterialApp(
    title: 'TCG404',
    debugShowCheckedModeBanner: false,

    home: const MobileStore(),
  ),
);

class MobileStore extends StatefulWidget {
  const MobileStore({super.key});
  @override
  State<MobileStore> createState() => _MobileStoreState();
}

class _MobileStoreState extends State<MobileStore> {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('TCG404.', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 12),
            const Text('Collect. Trade. Discover.'),
          ],
        ),
      ),
    ),
  );
}
