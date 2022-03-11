import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:math' as math;


class ConnectedDots extends StatefulWidget {
  @override
  _ConnectedDotsState createState() => _ConnectedDotsState();
}

class _ConnectedDotsState extends State<ConnectedDots> with TickerProviderStateMixin {
  final List<Star> stars = [];
  Animation<double> animation;
  AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );

    Tween<double> tween = Tween(begin: -math.pi, end: math.pi);

    animation = tween.animate(controller)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          controller.repeat();
        } else if (status == AnimationStatus.dismissed) {
          controller.forward();
        }
      });

    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, snapshot) {
                  return CustomPaint(
                    painter: ScenePainter(stars, 100),
                    child: Container(),
                  );
                },
              ),
            ),
          ],
        ),
    );
  }
}

class Star {
  double x;
  double y;
  double r;
  double vx;
  double vy;

  Star(this.x, this.y, this.r, this.vx, this.vy);
}

class ScenePainter extends CustomPainter {
  List<Star> _stars;
  final int _numOfStars;
  final int connectedMinDistance;

  final _starPaint = Paint()
    ..color = Colors.green
    ..strokeWidth = 1
    ..style = PaintingStyle.fill
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.dstOver;

  final _linePaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 0.05
    ..blendMode = BlendMode.srcOver;

  final rnd = math.Random();
  ScenePainter(this._stars, this._numOfStars, [this.connectedMinDistance = 120]);

  Star createStar(Size screenSize) {
    return Star(
      rnd.nextDouble() * screenSize.width,
      rnd.nextDouble() * screenSize.height,
      rnd.nextDouble() * 2 + 1,
      (rnd.nextDouble() * 1) - 0.1,
      (rnd.nextDouble() *1) - 0.1,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Set the background
    canvas.drawColor(Colors.black, BlendMode.clear);

    // Push stars to array
    if (_stars.length == 0) {
      // The list MUST be provided from outside, since the
      // CustomPainter is created each time.
      for (var i = 0; i < _numOfStars; i++) {
        _stars.add(createStar(size));
      }
    }

    // Update stars location
    _stars.forEach((Star s) {
      s.x += s.vx;
      s.y += s.vy;
      if (s.x < 0 || s.x > size.width) {
        s.vx = -s.vx;
      }
      if (s.y < 0 || s.y > size.height) {
        s.vy = -s.vy;
      }
    });

    // Draw stars
    _stars.forEach(
        (Star s) => {canvas.drawCircle(new Offset(s.x, s.y), s.r, _starPaint)});

    // Connect the dots.
    _stars.forEach((Star s) {
      final offset1 = new Offset(s.x, s.y);
      _stars.forEach((Star s2) {
        final offset2 = new Offset(s2.x, s2.y);
        if ((offset1 - offset2).distance < connectedMinDistance) {
          canvas.drawLine(offset1, offset2, _linePaint);
        }
      });
    });
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
