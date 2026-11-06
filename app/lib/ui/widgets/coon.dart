// Енот-космонавт «белый винил» (SVG из design/mascot, без анимаций CSS). Позы: hi, cheer, flag, think, sleep, oops, face.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Coon extends StatelessWidget {
  const Coon(this.pose, {super.key, this.size = 72});
  final String pose;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * 260 / 240,
    child: SvgPicture.asset('assets/coon/coon-$pose.svg', fit: BoxFit.contain),
  );
}
