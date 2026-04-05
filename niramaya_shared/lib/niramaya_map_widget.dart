import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

enum MapType { street, satellite, hybrid }

class NiramayaMapWidget extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final bool showControls;
  final bool showLocationButton;
  final bool showZoomControls;
  final bool showMapTypeToggle;
  final bool showFitBoundsButton;
  final VoidCallback? onLocationPressed;
  final VoidCallback? onFitBoundsPressed;
  final Function(LatLng)? onTap;
  final Function(LatLng)? onLongPress;
  final MapController? controller;

  const NiramayaMapWidget({
    super.key,
    required this.initialCenter,
    this.initialZoom = 14.0,
    this.markers = const [],
    this.polylines = const [],
    this.showControls = true,
    this.showLocationButton = true,
    this.showZoomControls = true,
    this.showMapTypeToggle = true,
    this.showFitBoundsButton = true,
    this.onLocationPressed,
    this.onFitBoundsPressed,
    this.onTap,
    this.onLongPress,
    this.controller,
  });

  @override
  State<NiramayaMapWidget> createState() => _NiramayaMapWidgetState();
}

class _NiramayaMapWidgetState extends State<NiramayaMapWidget> {
  late MapController _mapController;
  MapType _currentMapType = MapType.street;

  @override
  void initState() {
    super.initState();
    _mapController = widget.controller ?? MapController();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            onTap: widget.onTap != null 
                ? (tapPosition, point) => widget.onTap!(point)
                : null,
            onLongPress: widget.onLongPress != null
                ? (tapPosition, point) => widget.onLongPress!(point)
                : null,
          ),
          children: [
            TileLayer(
              urlTemplate: _getTileUrl(),
              userAgentPackageName: 'com.niramaya.app',
              maxNativeZoom: 18,
            ),
            if (widget.polylines.isNotEmpty)
              PolylineLayer(polylines: widget.polylines),
            if (widget.markers.isNotEmpty)
              MarkerLayer(markers: widget.markers),
          ],
        ),
        
        if (widget.showControls) ..._buildControls(),
      ],
    );
  }

  String _getTileUrl() {
    switch (_currentMapType) {
      case MapType.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapType.hybrid:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapType.street:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  List<Widget> _buildControls() {
    return [
      // Map type toggle (top-left)
      if (widget.showMapTypeToggle)
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          child: _buildMapTypeButton(),
        ),
      
      // Control buttons (right side)
      Positioned(
        right: 16,
        bottom: 100,
        child: Column(
          children: [
            if (widget.showLocationButton)
              _buildControlButton(
                icon: Icons.my_location,
                onPressed: widget.onLocationPressed ?? _centerOnLocation,
                tooltip: 'My Location',
              ),
            if (widget.showLocationButton) const SizedBox(height: 8),
            
            if (widget.showFitBoundsButton)
              _buildControlButton(
                icon: Icons.center_focus_strong,
                onPressed: widget.onFitBoundsPressed ?? _fitBounds,
                tooltip: 'Fit All',
              ),
            if (widget.showFitBoundsButton) const SizedBox(height: 8),
            
            if (widget.showZoomControls) ...[
              _buildControlButton(
                icon: Icons.add,
                onPressed: _zoomIn,
                tooltip: 'Zoom In',
              ),
              const SizedBox(height: 8),
              _buildControlButton(
                icon: Icons.remove,
                onPressed: _zoomOut,
                tooltip: 'Zoom Out',
              ),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _buildMapTypeButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: PopupMenuButton<MapType>(
        icon: Icon(_getMapTypeIcon(), color: Colors.black87),
        onSelected: (MapType type) {
          setState(() => _currentMapType = type);
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: MapType.street,
            child: Row(
              children: [
                Icon(Icons.map, size: 20),
                SizedBox(width: 8),
                Text('Street'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: MapType.satellite,
            child: Row(
              children: [
                Icon(Icons.satellite_alt, size: 20),
                SizedBox(width: 8),
                Text('Satellite'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: MapType.hybrid,
            child: Row(
              children: [
                Icon(Icons.layers, size: 20),
                SizedBox(width: 8),
                Text('Hybrid'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black87),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  IconData _getMapTypeIcon() {
    switch (_currentMapType) {
      case MapType.satellite:
        return Icons.satellite_alt;
      case MapType.hybrid:
        return Icons.layers;
      case MapType.street:
        return Icons.map;
    }
  }

  void _centerOnLocation() {
    // Default implementation - can be overridden
    if (widget.markers.isNotEmpty) {
      _mapController.move(widget.markers.first.point, 16);
    }
  }

  void _fitBounds() {
    if (widget.markers.isEmpty) return;
    
    final points = widget.markers.map((m) => m.point).toList();
    final bounds = LatLngBounds.fromPoints(points);
    
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  void _zoomIn() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom + 1,
    );
  }

  void _zoomOut() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom - 1,
    );
  }
}