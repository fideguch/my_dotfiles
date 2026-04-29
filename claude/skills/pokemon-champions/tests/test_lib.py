"""Phase 4 unit tests. Run with: python3 -m unittest tests.test_lib -v
   Or:                          python3 tests/test_lib.py
"""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from lib import lookup, intent_router, visualizer, persona, session_state  # noqa: E402


class TestLookup(unittest.TestCase):
    def test_resolve_pokemon_jp_exact(self):
        r = lookup.resolve_pokemon("ガブリアス")
        self.assertEqual(r["match_type"], "jp_exact")
        self.assertEqual(r["id"], "garchomp")

    def test_resolve_pokemon_en_exact(self):
        r = lookup.resolve_pokemon("Garchomp")
        self.assertEqual(r["match_type"], "exact")
        self.assertEqual(r["id"], "garchomp")

    def test_resolve_pokemon_partial(self):
        r = lookup.resolve_pokemon("ガブリ")  # partial JP
        self.assertIn(r["match_type"], ("partial", "ambiguous"))
        self.assertIn("garchomp", r["candidates"])

    def test_resolve_pokemon_none(self):
        r = lookup.resolve_pokemon("ZZZZ_NOT_A_POKEMON")
        self.assertEqual(r["match_type"], "none")
        self.assertIsNone(r["id"])

    def test_resolve_move_jp(self):
        r = lookup.resolve_move("じしん")
        self.assertEqual(r["match_type"], "jp_exact")
        self.assertEqual(r["id"], "earthquake")

    def test_resolve_item_jp(self):
        r = lookup.resolve_item("こだわりハチマキ")
        self.assertEqual(r["id"], "choiceband")

    def test_resolve_ability_jp(self):
        r = lookup.resolve_ability("さめはだ")
        self.assertEqual(r["id"], "roughskin")

    def test_pokedex_entry_has_stats(self):
        e = lookup.get_pokedex_entry("garchomp")
        self.assertIsNotNone(e)
        self.assertIn("baseStats", e)
        self.assertIn("hp", e["baseStats"])

    def test_jp_name_reverse(self):
        self.assertEqual(lookup.get_jp_name("pokemon", "garchomp"), "ガブリアス")
        self.assertEqual(lookup.get_jp_name("moves", "earthquake"), "じしん")

    def test_resolve_empty_input(self):
        r = lookup.resolve_pokemon("")
        self.assertEqual(r["match_type"], "none")


class TestIntentRouter(unittest.TestCase):
    def test_t1_damage_calc_keyword(self):
        r = intent_router.classify("鉢巻ガブのEQでミミの確定数は?")
        self.assertEqual(r.tier, "T1")
        self.assertGreater(r.confidence, 0.5)

    def test_t1_numeric(self):
        r = intent_router.classify("HP252振りで耐えるか")
        self.assertEqual(r.tier, "T1")

    def test_t2_team_advice(self):
        r = intent_router.classify("受けループの構築教えて")
        self.assertEqual(r.tier, "T2")

    def test_t3_meta_query(self):
        r = intent_router.classify("今シーズンの環境メタは?")
        self.assertEqual(r.tier, "T3")

    def test_mixed_t3_plus_t1(self):
        r = intent_router.classify("今期トップのガブの確定数は")
        self.assertEqual(r.tier, "MIXED")

    def test_default_t2(self):
        r = intent_router.classify("どうしよう")
        self.assertEqual(r.tier, "T2")
        self.assertLess(r.confidence, 0.6)

    def test_empty_input(self):
        r = intent_router.classify("")
        self.assertEqual(r.tier, "T2")
        self.assertEqual(r.confidence, 0.0)


class TestVisualizer(unittest.TestCase):
    def test_damage_table_basic(self):
        out = visualizer.render_damage_table(
            {"percent_min": 117, "percent_max": 138, "damage": [295, 348],
             "ko_chance": {"text": "guaranteed OHKO"}, "desc": "rolled"},
            "Garchomp", "Mimikyu", attacker_jp="ガブリアス", defender_jp="ミミッキュ",
        )
        self.assertIn("ガブリアス", out)
        self.assertIn("ミミッキュ", out)
        self.assertIn("117%", out)
        self.assertIn("138%", out)
        self.assertIn("guaranteed OHKO", out)

    def test_damage_table_ascii_bar(self):
        out = visualizer.render_damage_table(
            {"percent_min": 50, "percent_max": 60, "damage": [100, 120], "ko_chance": {}, "desc": ""},
            "A", "B",
        )
        self.assertIn("█", out)

    def test_type_matchup_ground(self):
        # Ground pokemon -> water 2x, electric 0x, ice 2x, etc.
        # Showdown typechart keys are PascalCase (Electric, Ground), but values are lowercased.
        chart = lookup.get_typechart()
        # Use proper-case as required by Showdown typechart keys
        out = visualizer.render_type_matchup(["Ground"], chart)
        self.assertIn("タイプ相性", out)
        # Electric is rendered as-is from typechart keys ("electric" if lowercased)
        self.assertTrue("Electric" in out or "electric" in out)

    def test_role_matrix(self):
        out = visualizer.render_role_matrix(
            ["A", "B"], ["X", "Y"], lambda s, o: f"{s}vs{o}",
        )
        self.assertIn("AvsX", out)
        self.assertIn("BvsY", out)

    def test_cycle_flow(self):
        out = visualizer.render_cycle_flow(["A", "B", "C"])
        self.assertIn("A → B → C", out)


class TestPersona(unittest.TestCase):
    def test_glossary_size_at_least_30(self):
        # PQG修正5: 30語以上 mandatory
        self.assertGreaterEqual(persona.glossary_size(), 30)

    def test_haijin_to_standard(self):
        out = persona.haijin_to_standard("珠ガブのEQ")
        self.assertIn("いのちのたま", out)

    def test_expand_glossary_appends_terms(self):
        out = persona.expand_glossary("HBドオーに鉢巻ガブのEQ")
        self.assertIn("用語", out)
        self.assertIn("こだわりハチマキ", out)

    def test_expand_glossary_no_terms(self):
        out = persona.expand_glossary("普通の文章です")
        self.assertEqual(out, "普通の文章です")


class TestSessionState(unittest.TestCase):
    def test_load_creates_default(self):
        s = session_state.load()
        self.assertIn("version", s)
        self.assertEqual(s["version"], 1)
        self.assertEqual(s["team"], [])

    def test_track_team_immutable(self):
        s = session_state.load()
        original_team = s["team"]
        new = session_state.track_team(s, [{"id": "garchomp"}])
        self.assertEqual(s["team"], original_team)  # original unchanged
        self.assertEqual(new["team"], [{"id": "garchomp"}])

    def test_track_last_calc(self):
        s = session_state._empty_state()
        new = session_state.track_last_calc(s, {"min": 50, "max": 60})
        self.assertEqual(new["last_calc"]["max"], 60)

    def test_focus_pokemon_priority(self):
        s = session_state._empty_state()
        s["last_topic"] = "garchomp"
        s["team"] = [{"id": "mimikyu"}]
        self.assertEqual(session_state.get_focus_pokemon(s), "garchomp")

        s["last_topic"] = None
        self.assertEqual(session_state.get_focus_pokemon(s), "mimikyu")

    def test_save_and_reload(self):
        s = session_state._empty_state()
        s["team"] = [{"id": "test_save_garchomp"}]
        session_state.save(s)
        reloaded = session_state.load()
        self.assertEqual(reloaded["team"][0]["id"], "test_save_garchomp")
        # Cleanup
        session_state.reset()


if __name__ == "__main__":
    unittest.main(verbosity=2)
