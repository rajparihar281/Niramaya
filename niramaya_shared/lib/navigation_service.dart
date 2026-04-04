import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'enhanced_location_service.dart';
import 'route_optimization_service.dart';

enum NavigationState {
  idle,
  navigating,
  rerouting,
  arrived,
}

enum TurnDirection {
  straight,
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uTurn,
}

class NavigationInstruction {
  final String text;
  final TurnDirection direction;
  final double distanceToNextTurn;
  final LatLng location;
  final String roadName;

  NavigationInstruction({
    required this.text,
    required this.direction,
    required this.distanceToNextTurn,
    required this.location,
    required this.roadName,
  });
}

class NavigationUpdate {
  final NavigationState state;
  final NavigationInstruction? currentInstruction;
  final double remainingDistance;
  final int remainingTime;
  final double progress;
  final LatLng currentLocation;
  final List<LatLng> remainingRoute;

  NavigationUpdate({
    required this.state,
    this.currentInstruction,
    required this.remainingDistance,
    required this.remainingTime,
    required this.progress,
    required this.currentLocation,
    required this.remainingRoute,
  });
}

class NavigationService extends ChangeNotifier {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final _locationService = EnhancedLocationService();
  final _routeService = RouteOptimizationService();
  
  StreamController<NavigationUpdate>? _navigationController;
  StreamSubscription<LatLng>? _locationSubscription;
  
  NavigationState _state = NavigationState.idle;
  RouteInfo? _currentRoute;
  LatLng? _destination;
  int _currentStepIndex = 0;
  double _totalDistance = 0;
  
  // Configuration
  double _rerouteThreshold = 50.0; // meters
  double _arrivalThreshold = 20.0; // meters
  bool _autoReroute = true;
  
  Stream<NavigationUpdate> get navigationStream {
    _navigationController ??= StreamController<NavigationUpdate>.broadcast();
    return _navigationController!.stream;
  }

  NavigationState get state => _state;
  RouteInfo? get currentRoute => _currentRoute;
  LatLng? get destination => _destination;

  Future<bool> startNavigation(LatLng destination, {
    RouteProfile profile = RouteProfile.driving,
    RoutePreference preference = RoutePreference.fastest,
  }) async {
    try {
      _destination = destination;
      _setState(NavigationState.navigating);
      
      // Get current location
      final currentLocation = await _locationService.getCurrentLocation();
      if (currentLocation == null) {
        _setState(NavigationState.idle);
        return false;
      }

      // Get route
      final route = await _routeService.getOptimizedRoute(
        currentLocation,
        destination,
        profile: profile,
        preference: preference,
      );
      
      if (route == null) {
        _setState(NavigationState.idle);
        return false;
      }

      _currentRoute = route;
      _totalDistance = route.distanceKm;
      _currentStepIndex = 0;
      
      // Start location tracking
      await _locationService.startTracking();
      _locationSubscription = _locationService.locationStream.listen(_onLocationUpdate);
      
      _navigationController ??= StreamController<NavigationUpdate>.broadcast();
      
      return true;
    } catch (e) {
      print('Navigation start error: $e');
      _setState(NavigationState.idle);
      return false;
    }
  }

  void stopNavigation() {
    _setState(NavigationState.idle);
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _currentRoute = null;
    _destination = null;
    _currentStepIndex = 0;
  }

  Future<void> _onLocationUpdate(LatLng location) async {
    if (_state != NavigationState.navigating || _currentRoute == null || _destination == null) {
      return;
    }

    // Check if arrived
    final distanceToDestination = EnhancedLocationService.calculateDistance(location, _destination!);
    if (distanceToDestination <= _arrivalThreshold) {
      _setState(NavigationState.arrived);
      _emitNavigationUpdate(location);
      return;
    }

    // Check if off route and needs rerouting
    if (_autoReroute && _isOffRoute(location)) {
      await _reroute(location);
      return;
    }

    // Update current step
    _updateCurrentStep(location);
    _emitNavigationUpdate(location);
  }

  bool _isOffRoute(LatLng location) {
    if (_currentRoute == null) return false;
    
    // Find closest point on route
    double minDistance = double.infinity;
    for (final point in _currentRoute!.polyline) {
      final distance = EnhancedLocationService.calculateDistance(location, point);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    
    return minDistance > _rerouteThreshold;
  }

  Future<void> _reroute(LatLng currentLocation) async {
    if (_destination == null) return;
    
    _setState(NavigationState.rerouting);
    
    try {
      final newRoute = await _routeService.getOptimizedRoute(
        currentLocation,
        _destination!,
      );
      
      if (newRoute != null) {
        _currentRoute = newRoute;
        _currentStepIndex = 0;
        _setState(NavigationState.navigating);
      } else {
        _setState(NavigationState.navigating); // Continue with old route
      }
    } catch (e) {
      print('Reroute error: $e');
      _setState(NavigationState.navigating);
    }
  }

  void _updateCurrentStep(LatLng location) {
    if (_currentRoute == null || _currentRoute!.steps.isEmpty) return;
    
    // Find the closest upcoming step
    for (int i = _currentStepIndex; i < _currentRoute!.steps.length; i++) {
      final step = _currentRoute!.steps[i];
      final distance = EnhancedLocationService.calculateDistance(location, step.location);
      
      if (distance < 30) { // Within 30 meters of step
        _currentStepIndex = i + 1;
        break;
      }
    }
  }

  void _emitNavigationUpdate(LatLng location) {
    if (_currentRoute == null || _destination == null) return;
    
    final remainingDistance = _calculateRemainingDistance(location);
    final remainingTime = _calculateRemainingTime(remainingDistance);
    final progress = 1.0 - (remainingDistance / (_totalDistance * 1000));
    
    NavigationInstruction? currentInstruction;
    if (_currentStepIndex < _currentRoute!.steps.length) {
      final step = _currentRoute!.steps[_currentStepIndex];
      final distanceToStep = EnhancedLocationService.calculateDistance(location, step.location);
      
      currentInstruction = NavigationInstruction(
        text: step.instruction,
        direction: _getTurnDirection(step.instruction),
        distanceToNextTurn: distanceToStep,
        location: step.location,
        roadName: step.instruction,
      );
    }
    
    final update = NavigationUpdate(
      state: _state,
      currentInstruction: currentInstruction,
      remainingDistance: remainingDistance,
      remainingTime: remainingTime,
      progress: progress.clamp(0.0, 1.0),
      currentLocation: location,
      remainingRoute: _getRemainingRoute(location),
    );
    
    _navigationController?.add(update);
  }

  double _calculateRemainingDistance(LatLng location) {
    if (_currentRoute == null) return 0;
    
    // Calculate distance from current location to destination
    return EnhancedLocationService.calculateDistance(location, _destination!);
  }

  int _calculateRemainingTime(double remainingDistance) {
    // Estimate based on remaining distance and average speed
    return EnhancedLocationService.estimateETA(remainingDistance / 1000);
  }

  List<LatLng> _getRemainingRoute(LatLng location) {
    if (_currentRoute == null) return [];
    
    // Find closest point on route and return remaining points
    final route = _currentRoute!.polyline;
    int closestIndex = 0;
    double minDistance = double.infinity;
    
    for (int i = 0; i < route.length; i++) {
      final distance = EnhancedLocationService.calculateDistance(location, route[i]);
      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    
    return route.sublist(closestIndex);
  }

  TurnDirection _getTurnDirection(String instruction) {
    final lower = instruction.toLowerCase();
    
    if (lower.contains('u-turn') || lower.contains('u turn')) {
      return TurnDirection.uTurn;
    } else if (lower.contains('sharp left')) {
      return TurnDirection.sharpLeft;
    } else if (lower.contains('sharp right')) {
      return TurnDirection.sharpRight;
    } else if (lower.contains('slight left')) {
      return TurnDirection.slightLeft;
    } else if (lower.contains('slight right')) {
      return TurnDirection.slightRight;
    } else if (lower.contains('left')) {
      return TurnDirection.left;
    } else if (lower.contains('right')) {
      return TurnDirection.right;
    } else {
      return TurnDirection.straight;
    }
  }

  void _setState(NavigationState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopNavigation();
    _navigationController?.close();
    _navigationController = null;
    _locationService.dispose();
    _routeService.dispose();
    super.dispose();
  }
}