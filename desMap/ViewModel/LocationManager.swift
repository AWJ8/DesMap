//
//  LocationManager.swift
//  DesMap
//
//  Created by Aleksander Jasinski on 16/12/2022.
//

import SwiftUI
import CoreLocation
import MapKit
// MARK: Combine Framework to watch Textfield Change
import Combine

class LocationManager: NSObject, ObservableObject, MKMapViewDelegate, CLLocationManagerDelegate {
    // MARK: Properties
    @Published var mapView: MKMapView = .init()
    @Published var manager: CLLocationManager = .init()
    // MARK: Search Bar Text
    @Published var searchText: String = ""
    var cancellable: AnyCancellable?
    @Published var fetchedPlaces: [CLPlacemark]?
    // MARK: User Location
    @Published var userLocation: CLLocation?
    // MARK: Final Location
    @Published var pickedLocation: CLLocation?
    @Published var pickedPlaceMark: CLPlacemark?
    override init() {
        super.init()
        // MARK: Setting Delegates
        manager.delegate = self
        mapView.delegate = self
        // MARK: Requesting Location Access
        manager.requestWhenInUseAuthorization()
        // MARK: Search Textfield Watching
        cancellable = $searchText
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink(receiveValue: {value in
                if value != "" {
                    self.fetchPlaces(value: value)
                } else {
                    self.fetchedPlaces = nil
                }
            })
    }
    func fetchPlaces(value: String) {
        // MARK: Fetching places using MKLocalSearch & Async/Await
        Task {
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = value.lowercased()
                let response = try await MKLocalSearch(request: request).start()
                // Can also use MainActor to publish changes in main thread
                await MainActor.run(body: {
                    self.fetchedPlaces = response.mapItems.compactMap({ item -> CLPlacemark? in
                        return item.placemark
                    })
                })
            } catch {
                // MARK: Handle Error
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // MARK: Handle Error
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last else {return}
        self.userLocation = currentLocation
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways: manager.requestLocation()
        case .authorizedWhenInUse: manager.requestLocation()
        case .denied: handleLocationError()
        case .notDetermined: manager.requestWhenInUseAuthorization()
        default: ()
        }
    }
    func handleLocationError() {
        // MARK: Handle Error
    }
    // MARK: Add draggable pin to MapView
    func addDraggablePin(coordinate: CLLocationCoordinate2D) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "Placeholder text"
        mapView.addAnnotation(annotation)
    }
    // MARK: Enabling Dragging
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let marker = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "DRAGGABLEPIN")
        marker.isDraggable = true
        marker.canShowCallout = false
        return marker
    }
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
        guard let newLocation = view.annotation?.coordinate else { return }
        self.pickedLocation = .init(latitude: newLocation.latitude, longitude: newLocation.longitude)
        updatePlacemark(location: .init(latitude: newLocation.latitude, longitude: newLocation.longitude))
    }
    func updatePlacemark(location: CLLocation) {
        Task {
            do {
                guard let place = try await reverseLocationCoordinate(location: location) else { return }
                await MainActor.run(body: {
                    self.pickedPlaceMark = place
                })
            } catch {
                // MARK: Handle Error
            }
        }
    }
    // MARK: Displaying new location data
    func reverseLocationCoordinate(location: CLLocation) async throws -> CLPlacemark? {
        let place = try await CLGeocoder().reverseGeocodeLocation(location).first
        return place
    }
}
