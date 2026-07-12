//
//  GameViewController.swift
//  CardGame
//
//  Second screen: no buttons, starts automatically.
//  Plays exactly 10 rounds. Each round: cards show "?" for 5-second countdown,
//  then flip to reveal the winner (stronger card scores, ties award no points).
//  Reveal stays up for 3 seconds, then reset to "?". After 10 rounds, highest
//  score wins; ties go to the PC. The player sits on the menu's side.
//

import UIKit
import AVFoundation

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
    /// The game always plays exactly this many rounds, then ends.
    private let totalRounds = 10
    private let secondsPerRound = 5
    /// How long the revealed cards stay on screen before the next round.
    private let revealSeconds: TimeInterval = 3.0

    // MARK: - State
    private var round = 0
    private var playerScore = 0
    private var pcScore = 0
    private var countdown = 0
    private var roundTimer: Timer?

    /// Which part of the round cycle we're in — used to pause/resume correctly.
    private enum Phase { case counting, revealing }
    private var phase: Phase = .counting
    private var phaseRemaining: TimeInterval = 0
    private var phaseDeadline: Date?
    private var revealWorkItem: DispatchWorkItem?
    private var pendingPlayerCard: Card?
    private var pendingPCCard: Card?
    private var isPaused = false
    private var gameEnded = false
    private var musicPlayer: AVAudioPlayer?
    private var flipPlayer: AVAudioPlayer?

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

        musicPlayer = loadPlayer(named: "background_music", ext: "wav")
        musicPlayer?.numberOfLoops = -1
        flipPlayer = loadPlayer(named: "flip", ext: "wav")

        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive),
                                                name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive),
                                                name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if round == 0 {
            musicPlayer?.play()
            startNextRound()   // auto-start once
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        roundTimer?.invalidate()
        roundTimer = nil
        revealWorkItem?.cancel()
        musicPlayer?.stop()
    }

    // MARK: - Game loop
    private func startNextRound() {
        round += 1
        phase = .counting

        pendingPlayerCard = randomCard()
        pendingPCCard = randomCard()

        // Face-down ("?") for the entire countdown.
        // On the very first round the cards are already "?", so skip the flip.
        let animateFlip = round > 1
        showBack(on: leftCard, animated: animateFlip)
        showBack(on: rightCard, animated: animateFlip)

        countdown = secondsPerRound
        timerLabel.text = "\(countdown)"

        startCountingTimer()
    }

    private func startCountingTimer() {
        roundTimer?.invalidate()
        roundTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickCountdown()
        }
    }

    private func tickCountdown() {
        guard countdown > 0 else { return }
        countdown -= 1
        timerLabel.text = "\(countdown)"
        guard countdown == 0 else { return }

        roundTimer?.invalidate()
        revealRound()
    }

    private func revealRound() {
        phase = .revealing
        guard let playerCard = pendingPlayerCard, let pcCard = pendingPCCard else { return }

        showCard(playerCard, on: playerCardView)
        showCard(pcCard, on: pcCardView)
        scoreRound(player: playerCard, pc: pcCard)

        scheduleRevealEnd(after: revealSeconds)
    }

    /// Schedules the reveal-to-next-round transition as a cancelable work item, so it
    /// can be paused and resumed correctly if the app is backgrounded mid-reveal.
    private func scheduleRevealEnd(after delay: TimeInterval) {
        phaseDeadline = Date().addingTimeInterval(delay)
        let workItem = DispatchWorkItem { [weak self] in
            self?.finishReveal()
        }
        revealWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    /// Called once the reveal window ends: start round N+1, or move to the summary screen.
    private func finishReveal() {
        if round >= totalRounds {
            endGame()
        } else {
            startNextRound()   // new countdown flips the cards back to "?"
        }
    }

    // MARK: - App lifecycle (pause/resume while backgrounded)
    /// Pauses the countdown or reveal timer and remembers the remaining time.
    @objc private func appWillResignActive() {
        guard round > 0, !gameEnded, !isPaused else { return }
        isPaused = true
        musicPlayer?.pause()
        switch phase {
        case .counting:
            roundTimer?.invalidate()
        case .revealing:
            revealWorkItem?.cancel()
            phaseRemaining = max(0.1, phaseDeadline?.timeIntervalSinceNow ?? revealSeconds)
        }
    }

    /// Resumes the countdown or reveal timer from where it left off.
    @objc private func appDidBecomeActive() {
        guard isPaused else { return }
        isPaused = false
        musicPlayer?.play()
        switch phase {
        case .counting:
            startCountingTimer()
        case .revealing:
            scheduleRevealEnd(after: phaseRemaining)
        }
    }

    private func scoreRound(player: Card, pc: Card) {
        if player.rank > pc.rank {
            playerScore += 1
        } else if pc.rank > player.rank {
            pcScore += 1
        }
        // Tie: no points awarded to either player.
        updateScoreLabels()
    }

    /// Called once `totalRounds` have been played.
    private func endGame() {
        gameEnded = true
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

    /// Fixed dark color so card text stays readable on the light card background
    /// in both light and dark mode (the card itself does not go dark).
    private static let cardTextColor = UIColor.darkText

    private func styleCard(_ card: UILabel) {
        card.numberOfLines = 0
        card.backgroundColor = UIColor(white: 0.96, alpha: 1)
        card.layer.cornerRadius = 10
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.lightGray.cgColor
        card.layer.masksToBounds = true
    }

    /// Flips a card face-up to reveal its value, with a flip animation and sound.
    private func showCard(_ card: Card, on view: UILabel) {
        playFlipSound()
        UIView.transition(with: view, duration: 0.4,
                          options: .transitionFlipFromRight) {
            view.text = card.label
            view.textColor = card.isRed ? .systemRed : Self.cardTextColor
        }
    }

    /// Flips a card back to its "?" back side between rounds.
    /// Pass animated: false to set it instantly (used on the first round).
    private func showBack(on view: UILabel, animated: Bool = true) {
        if animated {
            playFlipSound()
            UIView.transition(with: view, duration: 0.4,
                              options: .transitionFlipFromRight) {
                view.text = "?"
                view.textColor = Self.cardTextColor
            }
        } else {
            view.text = "?"
            view.textColor = Self.cardTextColor
        }
    }

    /// Loads a sound from the app bundle; returns nil if the file is missing.
    private func loadPlayer(named name: String, ext: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
        return try? AVAudioPlayer(contentsOf: url)
    }

    private func playFlipSound() {
        flipPlayer?.currentTime = 0
        flipPlayer?.play()
    }
}
