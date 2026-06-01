import CoreLocation
import Foundation

@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 25
    }

    func currentLocation() async throws -> CLLocation {
        if let cached = manager.location,
           cached.horizontalAccuracy >= 0,
           Date().timeIntervalSince(cached.timestamp) < 300 {
            return cached
        }

        if let continuation {
            continuation.resume(throwing: LocationProviderError.requestAlreadyInProgress)
            self.continuation = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            requestLocationIfPossible()
        }
    }

    private func requestLocationIfPossible() {
        guard CLLocationManager.locationServicesEnabled() else {
            finish(throwing: LocationProviderError.locationServicesDisabled)
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finish(throwing: LocationProviderError.authorizationDenied)
        @unknown default:
            finish(throwing: LocationProviderError.authorizationDenied)
        }
    }

    private func finish(with location: CLLocation) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    private func finish(throwing error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard self.continuation != nil else { return }
            self.requestLocationIfPossible()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.finish(with: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.finish(throwing: error)
        }
    }
}

enum LocationProviderError: LocalizedError, Sendable {
    case authorizationDenied
    case locationServicesDisabled
    case requestAlreadyInProgress

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Allow location access on Apple Watch to find nearby stops."
        case .locationServicesDisabled:
            return "Location services are disabled."
        case .requestAlreadyInProgress:
            return "A location request is already in progress."
        }
    }
}
