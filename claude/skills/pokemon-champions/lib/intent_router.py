"""Phase 4: Intent router (T1/T2/T3 classification).

Keyword-based heuristic. Used by SKILL.md to decide answer tier:
    T1 (<300ms, local-only): damage calc, base stats, type matchups
    T2 (1-5s, local + reasoning): team building advice, cycles, role coverage
    T3 (5-30s, fetch metagame): current trends, latest sets, tournament data

Confidence is a rough heuristic (0.0-1.0) based on matched keyword count.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Literal

Tier = Literal["T1", "T2", "T3", "MIXED"]


@dataclass(frozen=True)
class IntentResult:
    tier: Tier
    keywords_matched: list[str]
    confidence: float
    reason: str

    def to_dict(self) -> dict:
        return {
            "tier": self.tier,
            "keywords_matched": self.keywords_matched,
            "confidence": self.confidence,
            "reason": self.reason,
        }


# T1: damage calc / base stats lookup
T1_KEYWORDS = [
    "vs", "ダメ計", "ダメージ", "確定", "乱数", "ダウン",
    "1発", "1H", "1HKO", "2発", "2HKO", "3発", "3HKO",
    "種族値", "ベース", "タイプ相性", "弱点", "耐性", "倍率",
]
T1_PATTERN_NUMERIC = re.compile(
    r"(?:\d{2,4}\s*(?:%|hp|atk|def|spa|spd|spe))"
    r"|(?:\d{1,3}\s*(?:振り|努力値))",
    re.I,
)


# T2: team building / cycle advice (local + reasoning, no fetch)
T2_KEYWORDS = [
    "構築", "サイクル", "受け", "選出", "並び", "対面", "サポート",
    "起点", "対策", "崩し", "突破", "誤魔化し", "立ち回り",
    "エース", "アタッカー", "クッション", "ストッパー",
    "役割", "技構成", "持ち物", "努力値", "性格",
    "ポケモン教えて", "おすすめ", "相性",
]


# T3: latest meta / sets (requires fetch)
T3_KEYWORDS = [
    "今", "最新", "シーズン", "環境", "トレンド", "メタ",
    "上位", "TOP", "流行", "現環境", "使用率",
    "今シーズン", "今期", "最近",
]


def classify(text: str) -> IntentResult:
    """Classify text into T1/T2/T3 tier."""
    if not text or not text.strip():
        return IntentResult(
            tier="T2", keywords_matched=[], confidence=0.0,
            reason="empty input -> defaulting to T2",
        )

    matched: dict[Tier, list[str]] = {"T1": [], "T2": [], "T3": []}

    for kw in T1_KEYWORDS:
        if kw in text:
            matched["T1"].append(kw)
    if T1_PATTERN_NUMERIC.search(text):
        matched["T1"].append("<numeric>")

    for kw in T2_KEYWORDS:
        if kw in text:
            matched["T2"].append(kw)

    for kw in T3_KEYWORDS:
        if kw in text:
            matched["T3"].append(kw)

    counts = {t: len(matched[t]) for t in matched}

    # Strong T3 wins (latest meta requested)
    if counts["T3"] > 0:
        if counts["T1"] > 0 or counts["T2"] > 0:
            return IntentResult(
                tier="MIXED",
                keywords_matched=sum(matched.values(), []),
                confidence=0.8,
                reason=f"T3 + ({'T1' if counts['T1'] else ''}{'T2' if counts['T2'] else ''}) -> answer T3 first then chain",
            )
        return IntentResult(
            tier="T3", keywords_matched=matched["T3"],
            confidence=min(1.0, 0.5 + 0.2 * counts["T3"]),
            reason=f"T3 keywords: {matched['T3']}",
        )

    # T1 wins if numeric or damage-calc keywords
    if counts["T1"] > 0:
        return IntentResult(
            tier="T1", keywords_matched=matched["T1"],
            confidence=min(1.0, 0.6 + 0.15 * counts["T1"]),
            reason=f"T1 keywords: {matched['T1']}",
        )

    if counts["T2"] > 0:
        return IntentResult(
            tier="T2", keywords_matched=matched["T2"],
            confidence=min(1.0, 0.5 + 0.15 * counts["T2"]),
            reason=f"T2 keywords: {matched['T2']}",
        )

    # Default to T2 (most common cleansed query)
    return IntentResult(
        tier="T2", keywords_matched=[], confidence=0.3,
        reason="no strong keywords -> defaulting to T2",
    )


if __name__ == "__main__":
    import json
    import sys
    text = " ".join(sys.argv[1:]) or "今期の使用率TOP10は？"
    r = classify(text)
    print(json.dumps(r.to_dict(), ensure_ascii=False, indent=2))
