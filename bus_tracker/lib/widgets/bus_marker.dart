import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/bus_data.dart';

/// Creates a marker for a bus with color-coded occupancy indicator
class BusMarker {
  static Marker create(String busId, BusData bus, {VoidCallback? onTap}) {
    final busColor = bus.occupancyColor;

    return Marker(
      point: bus.location,
      width: 70,
      height: 70,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(Icons.directions_bus, color: busColor, size: 35),
            ),
            // Bus ID and passenger count label below the icon
            Positioned(
              bottom: -5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
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
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: busColor, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, size: 8, color: busColor),
                        const SizedBox(width: 2),
                        Text(
                          '${bus.passengers}',
                          style: TextStyle(
                            color: busColor,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
