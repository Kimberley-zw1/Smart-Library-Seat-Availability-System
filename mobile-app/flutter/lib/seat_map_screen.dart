import 'package:flutter/material.dart';

class SeatMapScreen extends StatelessWidget {
  const SeatMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library Seat Map'), centerTitle: true),
      body: const Center(
        child: Text(
          'Seat Map UI will be rendered here.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
