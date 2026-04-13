import Foundation

// MARK: - Result Types

/// Result of rolling dice from a notation string like "2d6+3".
struct DiceResult: Sendable {
    let rolls: [Int]
    let kept: [Int]
    let modifier: Int
    let total: Int
    let isCritical: Bool
    let isFumble: Bool
}

/// Result of a d20 roll with advantage/disadvantage.
struct D20Result: Sendable {
    let roll1: Int
    let roll2: Int
    let chosen: Int
    let modifier: Int
    let total: Int
    let isCritical: Bool
    let isFumble: Bool
    let advantage: Bool
    let disadvantage: Bool
}

// MARK: - DiceRoller

/// Pure dice-rolling utility. Parses D&D notation and rolls using Swift's
/// built-in random number generator.
///
/// Supported notations:
/// - "1d20", "2d6+3", "1d8-1", "4d6kh3" (keep highest 3)
/// - Plain numbers: "5" → total = 5
enum DiceRoller {

    // MARK: - Core Roll

    /// Parse a dice notation string and roll it.
    ///
    /// Examples: "2d6+3", "1d20", "4d6kh3", "d8", "5"
    static func roll(_ notation: String) -> DiceResult {
        var s = notation.trimmingCharacters(in: .whitespaces).lowercased()

        // Extract keep-highest modifier e.g. "kh3"
        var keepHighest = -1
        if let khRange = s.range(of: "kh") {
            let afterKH = s[khRange.upperBound...]
            keepHighest = Int(afterKH) ?? -1
            s = String(s[..<khRange.lowerBound])
        }

        // Split on +/- to get dice part and flat modifier
        var modifier = 0
        var dicePart = s

        if let plusIdx = s.lastIndex(of: "+"), plusIdx > s.startIndex {
            modifier = Int(s[s.index(after: plusIdx)...]) ?? 0
            dicePart = String(s[..<plusIdx])
        } else if let minusIdx = s.lastIndex(of: "-"), minusIdx > s.startIndex {
            modifier = -(Int(s[s.index(after: minusIdx)...]) ?? 0)
            dicePart = String(s[..<minusIdx])
        }

        // Parse NdS
        guard let dIdx = dicePart.firstIndex(of: "d") else {
            // Flat number, no dice
            let flat = (Int(dicePart) ?? 0) + modifier
            return DiceResult(rolls: [], kept: [], modifier: flat, total: flat,
                              isCritical: false, isFumble: false)
        }

        let numDice: Int = {
            let prefix = dicePart[..<dIdx]
            if prefix.isEmpty { return 1 }
            return Int(prefix) ?? 1
        }()
        let sides = Int(dicePart[dicePart.index(after: dIdx)...]) ?? 6

        var rolls: [Int] = []
        for _ in 0..<numDice {
            rolls.append(Int.random(in: 1...max(1, sides)))
        }

        // Keep highest N if specified
        let kept: [Int]
        if keepHighest > 0, keepHighest < rolls.count {
            kept = Array(rolls.sorted(by: >).prefix(keepHighest))
        } else {
            kept = rolls
        }

        let sum = kept.reduce(0, +)
        let total = sum + modifier

        // Crit/fumble only meaningful on single d20 rolls
        let isCritical = numDice == 1 && sides == 20 && rolls[0] == 20
        let isFumble = numDice == 1 && sides == 20 && rolls[0] == 1

        return DiceResult(rolls: rolls, kept: kept, modifier: modifier,
                          total: total, isCritical: isCritical, isFumble: isFumble)
    }

    // MARK: - D20 Roll

    /// Roll a d20 with optional advantage or disadvantage.
    /// If both apply, they cancel out (PHB p.173).
    static func rollD20(modifier: Int = 0, advantage: Bool = false,
                        disadvantage: Bool = false) -> D20Result {
        let roll1 = Int.random(in: 1...20)
        let roll2 = Int.random(in: 1...20)

        let chosen: Int
        var usedAdvantage = false
        var usedDisadvantage = false

        if advantage && disadvantage {
            // Both cancel out — use first roll
            chosen = roll1
        } else if advantage {
            chosen = max(roll1, roll2)
            usedAdvantage = true
        } else if disadvantage {
            chosen = min(roll1, roll2)
            usedDisadvantage = true
        } else {
            chosen = roll1
        }

        return D20Result(
            roll1: roll1, roll2: roll2, chosen: chosen,
            modifier: modifier, total: chosen + modifier,
            isCritical: chosen == 20, isFumble: chosen == 1,
            advantage: usedAdvantage, disadvantage: usedDisadvantage
        )
    }

    // MARK: - Damage Roll

    /// Roll damage dice, doubling dice count on a critical hit (PHB p.196).
    static func rollDamage(_ notation: String, critical: Bool = false) -> DiceResult {
        guard critical else { return roll(notation) }

        let s = notation.trimmingCharacters(in: .whitespaces).lowercased()
        guard let dIdx = s.firstIndex(of: "d") else { return roll(notation) }

        let numStr = s[..<dIdx]
        let numDice = numStr.isEmpty ? 1 : (Int(numStr) ?? 1)
        let rest = s[dIdx...]
        let doubled = "\(numDice * 2)\(rest)"
        return roll(doubled)
    }
}
