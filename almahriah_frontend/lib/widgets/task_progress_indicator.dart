import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnimatedTaskProgressIndicator extends StatefulWidget {
  final String currentStatus;
  final Function(String) onStatusChange;

  const AnimatedTaskProgressIndicator({
    Key? key,
    required this.currentStatus,
    required this.onStatusChange,
  }) : super(key: key);

  @override
  _AnimatedTaskProgressIndicatorState createState() => _AnimatedTaskProgressIndicatorState();
}

class _AnimatedTaskProgressIndicatorState extends State<AnimatedTaskProgressIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _buttonText = '';
  Color _buttonColor = Colors.grey.shade600;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _updateProgress(initial: true);
  }

  @override
  void didUpdateWidget(covariant AnimatedTaskProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStatus != widget.currentStatus) {
      _updateProgress();
    }
  }

  void _updateProgress({bool initial = false}) {
    double targetValue;
    if (widget.currentStatus == 'in_progress') {
      targetValue = 0.5;
      _buttonText = 'إكمال المهمة';
      _buttonColor = Colors.green.shade700;
    } else if (widget.currentStatus == 'completed' || widget.currentStatus == 'canceled') {
      targetValue = 1.0;
      _buttonText = 'مكتملة';
      _buttonColor = Colors.green.shade700;
    } else {
      targetValue = 0.0;
      _buttonText = 'بدء المهمة';
      _buttonColor = Colors.blue.shade800;
    }

    if (!initial) {
      _animation = Tween<double>(begin: _controller.value, end: targetValue).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
      _controller.forward(from: 0.0);
    } else {
      _controller.value = targetValue;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentStatus == 'completed' || widget.currentStatus == 'canceled') {
      return Container();
    }
    return Column(
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSegment(0.0, 0.5, _controller.value, Colors.blue.shade800),
                const SizedBox(width: 5),
                _buildSegment(0.5, 1.0, _controller.value, Colors.green.shade800),
              ],
            );
          },
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (widget.currentStatus == 'not_started' || widget.currentStatus == 'pending') {
                    widget.onStatusChange('in_progress');
                  } else if (widget.currentStatus == 'in_progress') {
                    widget.onStatusChange('completed');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _buttonColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: Text(
                  _buttonText,
                  style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (widget.currentStatus == 'in_progress') ...[
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => widget.onStatusChange('canceled'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: Text(
                    'إلغاء',
                    style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSegment(double start, double end, double value, Color color) {
    bool isFilled = value >= end;
    bool isFilling = value >= start && value < end;
    
    return Expanded(
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: isFilled ? color : (isFilling ? color.withOpacity(0.5 + (value - start) / (end - start) * 0.5) : Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}