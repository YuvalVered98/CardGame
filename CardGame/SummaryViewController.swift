//
//  SummaryViewController.swift
//  CardGame
//
//  Third screen: shows the winner and the winning score, plus a button that
//  returns all the way back to the main menu.
//

import UIKit

class SummaryViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var winnerLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!

    // MARK: - Passed in from the game
    var winnerName: String = ""
    var finalScore: Int = 0

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        winnerLabel.text = "Winner: \(winnerName)"
        scoreLabel.text = "score: \(finalScore)"
    }

    // MARK: - Back to menu
    @IBAction func backTapped(_ sender: UIButton) {
        // The menu is the root; Game and Summary were presented on top of it.
        // Dismissing the root's presented stack returns us to the menu.
        view.window?.rootViewController?.dismiss(animated: true)
    }
}
