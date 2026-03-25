"""ポケモンコマンド共通ユーティリティ"""
import json
import os

_DATA_DIR = os.path.dirname(os.path.abspath(__file__))
_DATA_FILE = os.path.join(_DATA_DIR, "pokemon_data.json")

TYPE_JA = {
    "normal": "ノーマル", "fire": "ほのお", "fighting": "かくとう",
    "water": "みず", "flying": "ひこう", "grass": "くさ",
    "poison": "どく", "electric": "でんき", "ground": "じめん",
    "psychic": "エスパー", "rock": "いわ", "ice": "こおり",
    "bug": "むし", "dragon": "ドラゴン", "ghost": "ゴースト",
    "dark": "あく", "steel": "はがね", "fairy": "フェアリー",
}

REGION_JA = {
    "kanto": "カントー", "johto": "ジョウト", "hoenn": "ホウエン",
    "sinnoh": "シンオウ", "unova": "イッシュ", "kalos": "カロス",
}


def load_data():
    if os.path.exists(_DATA_FILE):
        with open(_DATA_FILE, encoding="utf-8") as f:
            return json.load(f)
    return {}


def fmt_type(en_type):
    if not en_type:
        return "-"
    ja = TYPE_JA.get(en_type.lower(), "")
    return f"{ja}({en_type})" if ja else en_type


def fmt_region(en_region):
    ja = REGION_JA.get(en_region.lower(), "")
    return f"{ja}({en_region})" if ja else en_region


def fmt_stats(stats):
    """種族値を1行短縮形式で返す: H45-A49-B49-C65-D65-S45 (T318)"""
    if not stats:
        return ""
    h, a, b, c, d, s = stats
    total = sum(stats)
    return f"H{h}-A{a}-B{b}-C{c}-D{d}-S{s}(T{total})"


def get_ja_name(data, en_name):
    entry = data.get(en_name, data.get(en_name.lower(), {}))
    if isinstance(entry, dict):
        return entry.get("ja", "?")
    return entry if entry else "?"


def get_stats(data, en_name):
    entry = data.get(en_name, data.get(en_name.lower(), {}))
    if isinstance(entry, dict):
        return entry.get("stats", [])
    return []


def pokemon_oneliner(pid, en_name, data, type1, type2=None):
    """ポケモン情報を1行で返す"""
    ja_name = get_ja_name(data, en_name)
    t1_ja = TYPE_JA.get(type1, type1) if type1 else ""
    types = f"{t1_ja}({type1})" if type1 else ""
    if type2:
        t2_ja = TYPE_JA.get(type2, type2)
        types += f"/{t2_ja}({type2})"
    stats = fmt_stats(get_stats(data, en_name))
    return f"#{pid} {ja_name} ({en_name})  {types}  {stats}"
