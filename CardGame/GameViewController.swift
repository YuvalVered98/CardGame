//
//  GameViewController.swift
//  CardGame
//
//  Second screen: no buttons, starts automatically.
//  Each round the cards stay face-down ("?") for a 5-second countdown. Only
//  when the timer hits 0 do they flip up to reveal, and the point is awarded:
//  the stronger card scores, and on a tie BOTH players get a point. The reveal
//  stays up for 2 seconds, then a new countdown starts and the cards flip to "?".
//  The first player to reach 5 points wins. The player sits on the menu's side.
//

import UIKit

class GameViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var playerNameLabel: UILabel!
    @IBOutlet weak var playerScoreLabel: UILabel!
    @IBOutlet weak var pcNameLabel: UILabel!
    @IBOutlet weak var pcScoreLabel: UILabel!
    @IBOutlet weak var playerCardLabel: UILabel!
    @IBOutlet weak var pcCardLabel: UILabel!
    @IBOutlet weak var timerLabel: UILabel!

    // MARK: - Passed in from the menu
    var playerName: String = "Player"
    var playerIsEast: Bool = false

    // MARK: - Config
    /// The game ends as soon as a player reaches this many points.
    private let winningScore = 5
    private let secondsPerRound = 5

    // MARK: - State
    private var round = 0
    private var playerScore = 0
    private var pcScore = 0
    private var countdown = 0
    private var roundTimer: Timer?

    // The two on-screen cards. Which one belongs to the player depends on side.
    private var playerCardView: UILabel { playerIsEast ? rightCard : leftCard }
    private var pcCardView: UILabel { playerIsEast ? leftCard : rightCard }
    // leftCard / rightCard map to the storyboard labels.
    private var leftCard: UILabel { playerCardLabel }
    private var rightCard: UILabel { pcCardLabel }

    // MARK: - Card model
    private struct Card {
        let rank: Int          // 2...14  (11=J, 12=Q, 13=K, 14=A)
        let suit: String       // ♠ ♥ ♦ ♣
        var isRed: Bool { suit == "♥" || suit == "♦" }
        var label: String {
            let names = [11: "J", 12: "Q", 13: "K", 14: "A"]
            let r = names[rank] ?? "\(rank)"
            return "\(r)\n\(suit)"
        }
    }
    private func randomCard() -> Card {
        Card(rank: Int.random(in: 2...14),
             suit: ["♠", "♥", "♦", "♣"].randomElement()!)
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        styleCard(leftCard)
        styleCard(rightCard)

        // Put the player on their geographic side; PC on the other.
        if playerIsEast {
            // player = right column
            playerNameLabel.text = "PC";          playerNameLabel.textAlignment = .left
            playerScoreLabel.textAlignment = .left
            pcNameLabel.text = playerName;         pcNameLabel.textAlignment = .right
            pcScoreLabel.textAlignment = .right
        } else {
            // player = left column (default)
            playerNameLabel.text = playerName;     playerNameLabel.textAlignment = .left
            playerScoreLabel.textAlignment = .left
            pcNameLabel.text = "PC";               pcNameLabel.textAlignment = .right
            pcScoreLabel.textAlignment = .right
        }
        updateScoreLabels()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if round == 0 { startNextRound() }   // auto-start once
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        roundTimer?.invalidate()
        roundTimer = nil
    }

    // MARK: - Game loop
    private func startNextRound() {
        round += 1

        let playerCard = randomCard()
        let pcCard = randomCard()

        // Face-down ("?") for the entire countdown.
        // On the very first round the cards are already "?", so skip the flip.
        let animateFlip = round > 1
        showBack(on: leftCard, animated: animateFlip)
        showBack(on: rightCard, animated: animateFlip)

        countdown = secondsPerRound
        timerLabel.text = "\(countdown)"

        roundTimer?.invalidate()
        roundTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.countdown > 0 else { return }

            self.countdown -= 1
            self.timerLabel.text = "\(self.countdown)"
            guard self.countdown == 0 else { return }

            // Reached 0: stop the countdown, reveal the cards and award the point(s).
            self.roundTimer?.invalidate()
            self.showCard(playerCard, on: self.playerCardView)
            self.showCard(pcCard, on: self.pcCardView)
            self.scoreRound(player: playerCard, pc: pcCard)

            // Keep the reveal on screen for 2 seconds, then continue or finish.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                if self.playerScore >= self.winningScore || self.pcScore >= self.winningScore {
                    self.endGame()
                } else {
                    self.startNextRound()   // new countdown flips the cards back to "?"
                }
            }
        }
    }

    private func scoreRound(player: Card, pc: Card) {
        if player.rank > pc.rank {
            playerScore += 1
        } else if pc.rank > player.rank {
            pcScore += 1
        } else {
            // Tie: both players get a point.
            playerScore += 1
            pcScore += 1
        }
        updateScoreLabels()
    }

    private func endGame() {
        roundTimer?.invalidate()

        // Decide the winner. On a tie the house (PC) wins.
        let winnerName: String
        let winnerScore: Int
        if playerScore > pcScore {
            winnerName = playerName
            winnerScore = playerScore
        } else {
            winnerName = "PC"            // PC wins outright OR on a tie (house wins)
            winnerScore = pcScore
        }

        guard let summaryVC = storyboard?.instantiateViewController(
                withIdentifier: "SummaryViewController") as? SummaryViewController else { return }
        summaryVC.winnerName = winnerName
        summaryVC.finalScore = winnerScore
        summaryVC.modalPresentationStyle = .fullScreen
        present(summaryVC, animated: true)
    }

    // MARK: - UI helpers
    private func updateScoreLabels() {
        if playerIsEast {
            playerScoreLabel.text = "\(pcScore)"
            pcScoreLabel.text = "\(playerScore)"
        } else {
            playerScoreLabel.text = "\(playerScore)"
            pcScoreLabel.text = "\(pcScore)"
        }
    }

    private func styleCard(_ card: UILabel) {
        card.numberOfLines = 0
        card.backgroundColor = UIColor(white: 0.96, alpha: 1)
        card.layer.cornerRadius = 10
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.lightGray.cgColor
        card.layer.masksToBounds = true
    }

    private func showCard(_ card: Card, on view: UILabel) {
        UIView.transition(with: view, duration: 0.4,
                          options: .transitionFlipFromRight) {
            view.text = card.label
            view.textColor = card.isRed ? .systemRed : .label
        }
    }

    /// Flips a card back to its "?" back side between rounds.
    /// Pass animated: false to set it instantly (used on the first round).
    private func showBack(on view: UILabel, animated: Bool = true) {
        if animated {
            UIView.transition(with: view, duration: 0.4,
                              options: .transitionFlipFromRight) {
                view.text = "?"
                view.textColor = .label
            }
        } else {
            view.text = "?"
            view.textColor = .label
        }
    }
}
