import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/plant.dart';

/// A plant in its pot. With [sway] it rocks gently from the soil line,
/// unless the system asks for reduced motion.
class PlantView extends StatefulWidget {
  const PlantView({super.key, required this.spec, this.width = 200, this.potColor = '#F2A27E', this.sway = false});

  final PlantSpec spec;
  final double width;
  final String potColor;
  final bool sway;

  @override
  State<PlantView> createState() => _PlantViewState();
}

class _PlantViewState extends State<PlantView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
  String? _plant;
  late String _pot;

  @override
  void initState() {
    super.initState();
    _draw();
  }

  @override
  void didUpdateWidget(PlantView old) {
    super.didUpdateWidget(old);
    if (old.spec != widget.spec || old.potColor != widget.potColor) _draw();
  }

  void _draw() {
    _plant = PlantSvg.plant(widget.spec);
    _pot = PlantSvg.pot(widget.potColor);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = widget.sway && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!animate) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.width * PlantSvg.height / PlantSvg.width;
    Widget layer(String svg) => SvgPicture.string(svg, width: widget.width, height: height);
    final plant = _plant;

    return Semantics(
      image: true,
      label: widget.spec.semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          width: widget.width,
          height: height,
          child: Stack(
            children: [
              if (plant != null)
                widget.sway
                    ? AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) => Transform.rotate(
                          // ±1.6°, eased, pivoting where the stem meets the soil.
                          angle: (Curves.easeInOut.transform(_controller.value) * 2 - 1) * 0.028,
                          alignment: const Alignment(0, PlantSvg.pivotY * 2 - 1),
                          child: child,
                        ),
                        child: layer(plant),
                      )
                    : layer(plant),
              layer(_pot),
            ],
          ),
        ),
      ),
    );
  }
}
