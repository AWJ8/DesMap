//
//  ViewController.swift
//  desMap
//
//  Created by Aleksander Jasinski on 15/12/2022.
//

import UIKit
import MapKit
import CoreLocation

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    @IBOutlet weak var getDirectionsButton: UIButton!
    @IBOutlet weak var addressTextField: UITextField!
    @IBOutlet weak var mapView: MKMapView!
    var locationManager = CLLocationManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        mapView.delegate = self
    }
    @IBAction func getDirectionsClicked(_ sender: Any) {
        getAddress()
    }
    func getAddress() {
        let geoCoder = CLGeocoder()
        geoCoder.geocodeAddressString(addressTextField.text ?? "") { (placemarks, error) in
            guard let placemarks = placemarks, let location = placemarks.first?.location
            else {
                print("No location found")
                print(error ?? "Returned NIL")
                return
            }
            print(location)
            self.mapDirections(destinationCord: location.coordinate)
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            let region = MKCoordinateRegion(center: location.coordinate, span: span)
            mapView.setRegion(region, animated: true)
        }
        print(locations)
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("error: \(error)")
    }
    func mapDirections(destinationCord: CLLocationCoordinate2D) {
        guard let sourceCoordinate = locationManager.location?.coordinate else {
            print("No location found")
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
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        // swiftlint:disable force_cast
        let render = MKPolylineRenderer(overlay: overlay as! MKPolyline)
        // swiftlint:enable force_cast
        render.strokeColor = .systemGray
        return render
    }
}
