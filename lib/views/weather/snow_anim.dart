import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'base_weather_state.dart';

class SnowAnim extends StatefulWidget {
  final bool isDay;

  SnowAnim(this.isDay, {Key key}) : super(key: key);

  @override
  SnowAnimState createState() => SnowAnimState();
}

class SnowAnimState extends BaseAnimState<SnowAnim> {
  AnimationController controller;

  var _area = Rect.fromLTRB(0, 0, 420, 700);

  List<Snowflake> snowflakeList = [];

  Timer timer;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: CustomPaint(
        size: Size(double.infinity, double.infinity),
        painter: RainPainter(snowflakeList, _area, maskAlpha, widget.isDay),
      ),
      decoration: BoxDecoration(
          color: widget.isDay
              ? Color.fromARGB(255, 16, 109, 153)
              : Color.fromARGB(255, 19, 47, 69)),
    );
  }

  @override
  void initState() {
    super.initState();

    createRaindropTimer();
    initController();
  }

  void createRaindropTimer() {
    Duration duration = Duration(milliseconds: 100);
    timer = Timer.periodic(duration, (timer) {
      if (Random().nextDouble() >= 0.5) {
        createRaindrop();
      }
    });
  }

  void initController() {
    controller = AnimationController(
      vsync: this,
      duration: Duration(days: 1),
    )..addListener(() {
        snowflakeList.forEach((snowflake) {
          setState(() {
            updateBall(snowflake);
          });
        });
      });

    controller.forward();
  }

  void createRaindrop() {
    if (snowflakeList.length > 100) {
      return;
    }

    double vX = 0;
    double vY = 0;
    double radius;
    double random = Random().nextDouble() * 4.6;

    double randomVy = Random().nextDouble() * 1.6;
    vX = randomVy < 0.8 ? randomVy : 0.8 - randomVy;

    Color color;
    if (random < 0.8) {
      vY = 1.8;
      radius = 2;
      color = randomColor(Color(0xFF264562));
    } else if (random < 1.6) {
      vY = 1.9;
      radius = 2.5;
      color = randomColor(Color(0xFF305371));

      if (Random().nextInt(3) == 0) {
        randomVy = Random().nextDouble() * 4;
        vX = randomVy < 2 ? randomVy : 2 - randomVy;
        vY = 5;
      }
    } else if (random < 2.4) {
      vY = 2.0;
      radius = 3;
      color = randomColor(Color(0xFF375E7F));

      if (Random().nextInt(3) == 0) {
        randomVy = Random().nextDouble() * 4;
        vX = randomVy < 2 ? randomVy : 2 - randomVy;
        vY = 5;
      }
    } else if (random < 3.2) {
      vY = 2.1;
      radius = 3.5;
      color = randomColor(Color(0xFF5983AB));

      if (Random().nextInt(4) == 0) {
        randomVy = Random().nextDouble() * 4;
        vX = randomVy < 2 ? randomVy : 2 - randomVy;
        vY = 5;
      }
    } else if (random < 4.2) {
      vY = 2.2;
      radius = 4;
      color = randomColor(Color(0xFF608BB5));
    } else if (random < 4.4) {
      vY = 2.3;
      radius = 4.5;
      color = randomColor(Color(0xFF6F9BC2));
    } else if (random < 4.5) {
      vY = 2.4;
      radius = (Random().nextInt(5) + 5).toDouble();
      Color defaultColor = Color(0xE181ABD5);
      color = randomColor(defaultColor);
    } else {
      vY = 2.5;
      radius = (Random().nextInt(5) + 10).toDouble();
      Color defaultColor = Color(0xFF81ABD5);
      color = randomColor(defaultColor);
    }

    snowflakeList.add(Snowflake(
      color: color,
      x: _randPosition(),
      y: 0,
      radius: radius,
      oldRadius: radius,
      vX: vX,
      vY: vY,
      vRadius: Random().nextDouble() / 20,
    ));
  }

  Color randomColor(Color defaultColor) {
    Color color;
    double num = Random().nextDouble();
    if (num <= 0.05) {
      color = Color.fromARGB(defaultColor.alpha, 86, 177, 159);
    } else {
      color = defaultColor;
    }
    return color;
  }

  void updateBall(Snowflake snowflake) {
    snowflake.x += snowflake.vX;
    snowflake.y += snowflake.vY;

    if (snowflake.isHexagon && snowflake.y > 200) {
      snowflake.radius -= snowflake.vRadius;
    }

    // 限定下边界
    if (snowflake.y > _area.bottom ||
        snowflake.x < _area.left ||
        snowflake.x > _area.right) {
      snowflake.x = _randPosition();
      snowflake.y = 0;
      snowflake.radius = snowflake.oldRadius;
    }

    if (snowflake.vY == 2.3 && snowflake.y > 200) {
      snowflake.radius -= snowflake.vRadius;
    }
  }

  double _randPosition() {
    return new Random().nextInt(410).toDouble();
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
    timer.cancel();
  }
}

class RainPainter extends CustomPainter {
  List<Snowflake> snowflakeList;

  Rect area;

  double maskAlpha;

  bool isDay;

  Paint mPaint = new Paint()..style = PaintingStyle.fill;

  RainPainter(this.snowflakeList, this.area, this.maskAlpha, this.isDay);

  @override
  void paint(Canvas canvas, Size size) {
    Paint bgPaint = new Paint()
      ..color = isDay
          ? Color.fromARGB(255, 16, 109, 153)
          : Color.fromARGB(255, 19, 47, 69);

    canvas.drawRect(area, bgPaint);

    snowflakeList.forEach((snowflake) {
      mPaint.color = Color.fromARGB((snowflake.color.alpha * maskAlpha).toInt(),
          snowflake.color.red, snowflake.color.green, snowflake.color.blue);
      _drawSnowflake(canvas, snowflake);
    });
  }

  _drawSnowflake(Canvas canvas, Snowflake snowflake) {
    if (snowflake.isHexagon) {
      num radians = pi / 6;
      Path path = Path();
      path.moveTo(snowflake.x, snowflake.y - snowflake.radius);
      path.lineTo(snowflake.x + cos(radians) * snowflake.radius,
          snowflake.y - sin(radians) * snowflake.radius);
      path.lineTo(snowflake.x + cos(radians) * snowflake.radius,
          snowflake.y + sin(radians) * snowflake.radius);
      path.lineTo(snowflake.x, snowflake.y + snowflake.radius);
      path.lineTo(snowflake.x - cos(radians) * snowflake.radius,
          snowflake.y + sin(radians) * snowflake.radius);
      path.lineTo(snowflake.x - cos(radians) * snowflake.radius,
          snowflake.y - sin(radians) * snowflake.radius);
      path.close();
      canvas.drawPath(path, mPaint);
    } else {
      canvas.drawCircle(
          Offset(snowflake.x, snowflake.y), snowflake.radius, mPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class Snowflake {
  double x;
  double y;
  double radius;
  double oldRadius;
  double vX;
  double vY;
  double vRadius;
  Color color;
  bool isHexagon;

  Snowflake(
      {this.x = 0,
      this.y = 0,
      this.radius = 0,
      this.oldRadius = 0,
      this.vX = 0,
      this.vY = 0,
      this.vRadius = 0,
      this.color}) {
    this.isHexagon = oldRadius >= 5;
  }
}