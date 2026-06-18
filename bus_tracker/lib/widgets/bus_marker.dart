import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/bus_data.dart';

/// Creates a marker for a bus with color-coded occupancy indicator
class BusMarker {
  static Marker create(
    String busId,
    BusData bus, {
    double? bearing,
    VoidCallback? onTap,
    bool isHighlighted = false,
  }) {
    final busColor = bus.occupancyColor;
    final double markerSize = isHighlighted ? 85.0 : 70.0;
    final double iconSize = isHighlighted ? 42.0 : 32.0;

    return Marker(
      point: bus.location,
      width: markerSize,
      height: markerSize,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (bearing != null)
              Transform.rotate(
                angle: bearing * pi / 180,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Icon(
                    Icons.navigation,
                    color: busColor,
                    size: isHighlighted ? 18.0 : 14.0,
                  ),
                ),
              ),
            Container(
              padding: EdgeInsets.all(isHighlighted ? 4 : 0),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: isHighlighted
                    ? Border.all(color: const Color(0xFF00458C), width: 3.5)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isHighlighted
                        ? const Color(0xFF00458C).withValues(alpha: 0.45)
                        : Colors.black.withOpacity(0.3),
                    blurRadius: isHighlighted ? 12 : 5,
                    spreadRadius: isHighlighted ? 3 : 1,
                  ),
                ],
              ),
              child: Icon(Icons.directions_bus, color: busColor, size: iconSize),
            ),
            // Bus ID label below the icon
            Positioned(
              bottom: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: busColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  busId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
