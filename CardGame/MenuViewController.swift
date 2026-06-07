//
//  MenuViewController.swift
//  CardGame
//
//  First screen: enter a name (saved between launches) and read the device
//  location ONCE. The longitude decides which side you play on:
//      longitude > MIDPOINT  -> East Side
//      longitude <= MIDPOINT -> West Side
//  START only appears after BOTH a name and a location exist.
//

import UIKit
import CoreLocation

class MenuViewController: UIViewController, CLLocationManagerDelegate {

    // MARK: - Outlets (connected in Main.storyboard)
    @IBOutlet weak var nameButton: UIButton!
    @IBOutlet weak var greetingLabel: UILabel!
    @IBOutlet weak var westImageView: UIImageView!
    @IBOutlet weak var westLabel: UILabel!
    @IBOutlet weak var eastImageView: UIImageView!
    @IBOutlet weak var eastLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!

    // MARK: - Config
    /// The dividing longitude given in the assignment.
    private let midpointLongitude = 34.817549168324334

    // MARK: - State
    private let locationManager = CLLocationManager()
    private var playerName: String? {
        get { UserDefaults.standard.string(forKey: "playerName") }
        set { UserDefaults.standard.set(newValue, forKey: "playerName") }
    }
    /// true = East side, false = West side, nil = not decided yet.
    private var isEast: Bool?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Globe images (set in code so the storyboard stays simple).
        westImageView.image = UIImage(systemName: "globe.americas.fill")
        eastImageView.image = UIImage(systemName: "globe.asia.australia.fill")
        westImageView.tintColor = .systemBlue
        eastImageView.tintColor = .systemGreen

        // Make START look like a button.
        styleAsButton(startButton)

        locationManager.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Re-read the location every time the menu appears (e.g. after BACK TO MENU).
        isEast = nil
        refreshUI()
        requestLocationOnce()
    }

    // MARK: - Name
    @IBAction func nameButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Insert name",
                                      message: "Type your name",
                                      preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Your name"
            tf.text = self.playerName
            tf.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            let typed = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
            if !typed.isEmpty {
                self.playerName = typed
                self.refreshUI()
            }
        })
        present(alert, animated: true)
    }

    // MARK: - Location (one-shot)
    private func requestLocationOnce() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()   // single delivery, then stops
        case .denied, .restricted:
            showLocationDeniedHint()
        @unknown default:
            break
        }
    }

    // Called when the user answers the permission prompt.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else if status == .denied || status == .restricted {
            showLocationDeniedHint()
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        // Decide the side from longitude, then stop asking for location.
        isEast = loc.coordinate.longitude > midpointLongitude
        manager.stopUpdatingLocation()
        refreshUI()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // On the simulator with no mock location set you land here.
        print("Location error: \(error.localizedDescription)")
    }

    private func showLocationDeniedHint() {
        let alert = UIAlertController(
            title: "Location needed",
            message: "The game needs your location to choose a side. Enable it in Settings, or set a simulated location in the simulator (Features ▸ Location).",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - UI
    private func refreshUI() {
        // Greeting + name button.
        if let name = playerName, !name.isEmpty {
            greetingLabel.text = "Hi \(name)"
            greetingLabel.isHidden = false
            nameButton.setTitle("Change a name", for: .normal)
        } else {
            greetingLabel.isHidden = true
            nameButton.setTitle("Insert name", for: .normal)
        }

        // Highlight the chosen side (dim the other).
        switch isEast {
        case .some(true):
            eastImageView.alpha = 1.0;  eastLabel.alpha = 1.0
            westImageView.alpha = 0.25; westLabel.alpha = 0.25
        case .some(false):
            westImageView.alpha = 1.0;  westLabel.alpha = 1.0
            eastImageView.alpha = 0.25; eastLabel.alpha = 0.25
        case .none:
            westImageView.alpha = 1.0;  westLabel.alpha = 1.0
            eastImageView.alpha = 1.0;  eastLabel.alpha = 1.0
        }

        // START only when we have a name AND a side.
        let ready = (playerName?.isEmpty == false) && (isEast != nil)
        startButton.isHidden = !ready
    }

    // MARK: - Start
    @IBAction func startTapped(_ sender: UIButton) {
        guard let name = playerName, !name.isEmpty, let east = isEast else { return }

        guard let gameVC = storyboard?.instantiateViewController(
                withIdentifier: "GameViewController") as? GameViewController else { return }
        gameVC.playerName = name
        gameVC.playerIsEast = east
        gameVC.modalPresentationStyle = .fullScreen
        present(gameVC, animated: true)
    }

    // MARK: - Helpers
    private func styleAsButton(_ button: UIButton) {
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
    }
}
