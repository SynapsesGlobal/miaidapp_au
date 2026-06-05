import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Countdown extends StatefulWidget {
  final int seconds;
  final double size;
  final VoidCallback onFinished;
  final Color backgroundColor;

  const Countdown({
    super.key,
    this.seconds = 8,
    this.size = 80,
    required this.onFinished,
    this.backgroundColor = const Color(0xFF0CBCC5),
  });

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
        setState(() {
          _remaining = 0;
        });
        widget.onFinished(); // 触发事件
      } else {
        setState(() {
          _remaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,

      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.backgroundColor,
      ),
      alignment: Alignment.center,
      child: Text(
        '$_remaining',
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: Colors.white,
        ),
      ),
    );
  }
}
