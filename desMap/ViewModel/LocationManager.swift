//
//  LocationManager.swift
//  DesMap
//
//  Created by Aleksander Jasinski on 16/12/2022.
//
// swiftlint:disable: line_length

import SwiftUI
import CoreLocation
import MapKit
// MARK: Combine Framework to watch Textfield Change
import Combine

class LocationManager: NSObject, ObservableObject, MKMapViewDelegate, CLLocationManagerDelegate {
    weak var coordinator: AppCoordinator!
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
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestAlwaysAuthorization()
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
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
                print("fetchPlaces function failed")
                print(error)
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // MARK: Handle Error
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last else {return}
        self.userLocation = currentLocation
        if let location = locations.first {
            let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            let region = MKCoordinateRegion(center: location.coordinate, span: span)
            mapView.setRegion(region, animated: true)
        }
        print("MapVM\(locations)")
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
        annotation.title = pickedPlaceMark?.locality
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
                print("Failed updatePlacemark")
            }
        }
    }
    // MARK: Displaying new location data
    func reverseLocationCoordinate(location: CLLocation) async throws -> CLPlacemark? {
        let place = try await CLGeocoder().reverseGeocodeLocation(location).first
        return place
    }
    func getAddress() {
        let geoCoder = CLGeocoder()
        geoCoder.geocodeAddressString(pickedPlaceMark?.name ?? "") { (placemarks, error) in
            guard let placemarks = placemarks, let location = placemarks.first?.location
            else {
                print("No location found gA2")
                print("Returned error: \(String(describing: error))" )
                return
            }
            print(location)
            self.mapDirections(destinationCord: location.coordinate)
        }
    }
    func getAddressMVC(input: String) {
        let geoCoder = CLGeocoder()
        geoCoder.geocodeAddressString(input) { (placemarks, error) in
            guard let placemarks = placemarks, let location = placemarks.first?.location
            else {
                print("No location found gAMVC")
                print("Returned error: \(String(describing: error))" )
                return
            }
            print(location)
            self.mapDirections(destinationCord: location.coordinate)
        }
    }
    func mapDirections(destinationCord: CLLocationCoordinate2D) {
        guard let sourceCoordinate = userLocation?.coordinate else {
            print("No location found mD")
            return
        }
        let sourcePlaceMark = MKPlacemark(coordinate: sourceCoordinate)
        let destPlaceMark = MKPlacemark(coordinate: destinationCord)
        let sourceItem = MKMapItem(placemark: sourcePlaceMark)
        let destItem = MKMapItem(placemark: destPlaceMark)
        let destinationRequest = MKDirections.Request()
        destinationRequest.source = sourceItem
        destinationRequest.destination = destItem
        destinationRequest.transportType = .automobile
        destinationRequest.requestsAlternateRoutes = true
        let directions = MKDirections(request: destinationRequest)
        directions.calculate { (response, error) in
            guard let response = response else {
                if error != nil {
                    print("Something went wrong")
                }
                return
            }
            self.mapView.removeOverlays(self.mapView.overlays)
            let route = response.routes[0]
            self.mapView.addOverlay(route.polyline)
            self.mapView.setVisibleMapRect(route.polyline.boundingMapRect, animated: true)
        }
    }
    func updatePlaceMark(place: CLPlacemark) {
        if let coordinate = place.location?.coordinate {
            pickedLocation = .init(latitude: coordinate.latitude, longitude: coordinate.longitude)
            mapView.region = .init(center: coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
            addDraggablePin(coordinate: coordinate)
            updatePlacemark(location: .init(latitude: coordinate.latitude, longitude: coordinate.longitude))
        }
    }
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        // swiftlint:disable force_cast
        let render = MKPolylineRenderer(overlay: overlay as! MKPolyline)
        // swiftloint:enable force_cast
        render.strokeColor = .systemGreen
        return render
    }
}
