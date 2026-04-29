"""Phase 4: Persona helper — haijin (廃人) tone formatting + glossary lookup.

Maintains a dictionary of haijin -> standard expressions and provides
text-substitution helpers. The full glossary lives in references/persona_guide.md
(a SSOT MD doc); this module is a small runtime helper, not the doc.
"""

from __future__ import annotations

# Pairs: (haijin_term, standard_term, gloss). Keep tight; full table is in MD doc.
GLOSSARY = [
    ("1H", "確定一発", "1発でKOできる(One-Hit KO、=1HKO=1確)"),
    ("1HKO", "確定一発", "One-Hit KO、1発でKOできる"),
    ("1確", "確定一発", "「1Hで確定」の略、1発でKOできる"),
    ("2確", "確定二発", "2発でKOできる"),
    ("2HKO", "確定二発", "Two-Hit KO、2発でKOできる"),
    ("確3", "確定三発", "3発でKOできる"),
    ("乱1", "乱数一発", "1発でKO可能性あり (確率撃破)"),
    ("乱数", "確率撃破範囲", "ダメージロールの最低値で1発に届かないが届く確率がある状態"),
    ("珠", "いのちのたま", "アイテム"),
    ("鉢巻", "こだわりハチマキ", "アイテム、物理威力1.5倍&技固定"),
    ("メガネ", "こだわりメガネ", "アイテム、特殊威力1.5倍&技固定"),
    ("スカーフ", "こだわりスカーフ", "アイテム、素早さ1.5倍&技固定"),
    ("HB", "HP/ぼうぎょ振り", "HPと物理防御に努力値特化"),
    ("HD", "HP/とくぼう振り", "HPと特殊防御に努力値特化"),
    ("ASぶっぱ", "こうげき/すばやさMAX振り", "物理アタッカー定番"),
    ("CSぶっぱ", "とくこう/すばやさMAX振り", "特殊アタッカー定番"),
    ("ステロ", "ステルスロック", "繰り出し時にダメージ"),
    ("ダイマ", "ダイマックス", "gen 8メカニクス"),
    ("テラ", "テラスタル", "gen 9メカニクス、タイプ変更"),
    ("S", "すばやさ", "ステータス略称"),
    ("H", "HP", "ステータス略称"),
    ("A", "こうげき", "ステータス略称"),
    ("B", "ぼうぎょ", "ステータス略称"),
    ("C", "とくこう", "ステータス略称"),
    ("D", "とくぼう", "ステータス略称"),
    ("受けループ", "受け中心構築", "防御寄り3-4体で粘る型"),
    ("サイクル", "繰り出しサイクル", "相手の技に有利なポケモンを繰り出して回す戦術"),
    ("対面", "対面型", "繰り出し勝ち負けではなく場の1対1で勝つ戦術"),
    ("起点作り", "起点作成役", "積み技/ステロ等で後続を強化する初手要員"),
    ("抜く", "上から殴る", "素早さで上を取って先制攻撃"),
    ("半減実", "半減きのみ", "弱点タイプ受けたとき1度だけ半減"),
    ("突破ライン", "突破成立H値", "そのHP振りラインで初めて確定する閾値"),
    ("エース", "決定力ポケモン", "終盤の決定打を担う"),
    ("クッション", "受け要員", "削れて後続に繋ぐ役割"),
    ("ストッパー", "起点解除役", "相手の積みを止める"),
    ("崩し", "受け破壊", "受けループ等の硬い構築を突破する役割"),
    ("誤魔化し", "場凌ぎ", "詰みを避けるための応急処置"),
    ("選出", "出場ポケモン3匹選び", "対戦開始前に6体から3体を選ぶ"),
    ("並び", "選出構築の3体並び", "選出後の編成"),
    ("フェイク", "見せ駒", "出さないが選出画面で相手に意識させる"),
]


def haijin_to_standard(text: str) -> str:
    """Replace haijin terms with standard expressions in text."""
    for haijin, std, _ in sorted(GLOSSARY, key=lambda x: -len(x[0])):
        text = text.replace(haijin, std)
    return text


def expand_glossary(text: str) -> str:
    """Append a glossary footnote for any haijin term used."""
    used = []
    for haijin, std, gloss in sorted(GLOSSARY, key=lambda x: -len(x[0])):
        if haijin in text and (haijin, std, gloss) not in used:
            used.append((haijin, std, gloss))
    if not used:
        return text
    foot = ["", "---", "**用語**:"]
    for haijin, std, gloss in used:
        foot.append(f"- **{haijin}**: {std} — {gloss}")
    return text + "\n" + "\n".join(foot)


def glossary_size() -> int:
    return len(GLOSSARY)


if __name__ == "__main__":
    print(f"Glossary entries: {glossary_size()}")
    sample = "鉢巻ガブのEQで珠ミミを1確、HB珠HD振りに乱数。"
    print("\nINPUT:", sample)
    print("\nSTANDARD:", haijin_to_standard(sample))
    print("\nEXPANDED:")
    print(expand_glossary(sample))
