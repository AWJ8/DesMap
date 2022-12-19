//
//  Coordinator.swift
//  DesMap
//
//  Created by Aleksander Jasinski on 19/12/2022.
//

import Foundation
import UIKit

protocol Coordinator {
    var parentCoordinator: Coordinator? { get set }
    var children: [Coordinator]? { get set }
    var navigationController: UINavigationController { get set }
    func start()
}

class AppCoordinator: Coordinator {
    var parentCoordinator: Coordinator?
    var children: [Coordinator]?
    var navigationController: UINavigationController
    init(navCon: UINavigationController) {
        self.navigationController = navCon
    }
    func start() {
        print("AppCoordinator Started")
    }
    let storyboard = UIStoryboard.init(name: "Main", bundle: .main)
    func goToMapView() {
        // swiftlint:disable force_cast
        let mapViewController = storyboard.instantiateViewController(withIdentifier: "MapViewController") as! MapViewController
        // swiftlint:enable force_cast
        let mapViewModel = LocationManager.init()
        mapViewModel.coordinator = self
        mapViewController.viewModel = mapViewModel
        navigationController.pushViewController(mapViewController, animated: true)
    }
}
