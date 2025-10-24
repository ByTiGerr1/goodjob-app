import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Custom [PageScrollPhysics] that requires a slightly bigger gesture to move
/// between pages. This helps when the carousel is displayed above the map,
/// preventing tiny accidental drags from triggering a page change.
class ResistantPageScrollPhysics extends PageScrollPhysics {
  const ResistantPageScrollPhysics({super.parent});

  @override
  ResistantPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ResistantPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // If the gesture was not strong enough, stop the page view on the current
    // page instead of flinging to the next one.
    if ((velocity).abs() < minFlingVelocity) {
      return super.createBallisticSimulation(position, 0);
    }
    return super.createBallisticSimulation(position, velocity);
  }

  @override
  double get minFlingVelocity => 1400.0;

  @override
  double get minFlingDistance => 30.0;
}