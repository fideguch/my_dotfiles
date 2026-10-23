"""Tests for git-hooks/public_guard.py and install.sh (run: python3 -B -m unittest discover -s git-hooks/tests).

All names are fictional.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import unicodedata
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
HOOKS_DIR = os.path.dirname(HERE)
GUARD = os.path.join(HOOKS_DIR, "public_guard.py")
INSTALL = os.path.join(HOOKS_DIR, "install.sh")
HAS_GITLEAKS = shutil.which("gitleaks") is not None
CLEAN_ENV = ("PUBLIC_GUARD_SKIP", "PUBLIC_GUARD_ALLOW_EMPTY", "PUBLIC_GUARD_NO_GITLEAKS", "PUBLIC_GUARD_CONFIG_DIR")


def git(repo, *args, stdin=None):
    return subprocess.run(["git", "-C", repo, *args], input=stdin, capture_output=True, text=True, check=True).stdout


class GuardCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="public-guard-test.")
        self.addCleanup(shutil.rmtree, self.tmp)
        self.repo = os.path.join(self.tmp, "repo")
        self.config = os.path.join(self.tmp, "config")
        os.makedirs(self.config)
        os.makedirs(self.repo)
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "config", "user.email", "t@example.com")
        git(self.repo, "config", "user.name", "t")
        git(self.repo, "config", "commit.gpgsign", "false")
        self.write_config("denylist.txt", "# fictional names\nAcme\nアクメ商事\nミドリ\n")

    def write_config(self, name, text):
        with open(os.path.join(self.config, name), "w", encoding="utf-8") as handle:
            handle.write(text)

    def write(self, rel, text, mode="w"):
        path = os.path.join(self.repo, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if mode == "wb":
            with open(path, "wb") as handle:
                handle.write(text)
        else:
            with open(path, "w", encoding="utf-8", newline="") as handle:
                handle.write(text)

    def stage(self):
        git(self.repo, "add", "-A")

    def commit(self, message="add"):
        self.stage()
        git(self.repo, "-c", "core.hooksPath=/dev/null", "commit", "-q", "-m", message)
        return git(self.repo, "rev-parse", "HEAD").strip()

    def env(self, extra=None):
        env = {key: value for key, value in os.environ.items() if key not in CLEAN_ENV}
        env.update({"PUBLIC_GUARD_CONFIG_DIR": self.config, "PUBLIC_GUARD_NO_GITLEAKS": "1"})
        env.update(extra or {})
        return env

    def guard(self, *args, env=None, stdin=None):
        return subprocess.run([sys.executable, "-I", "-B", GUARD, *args], cwd=self.repo, env=self.env(env),
                              input=stdin, capture_output=True, text=True)

    def staged(self, text, rel="notes.md", env=None):
        self.write(rel, text)
        self.stage()
        return self.guard("staged", env=env)


class MatchingTest(GuardCase):
    def test_clean_change_passes(self):
        self.assertEqual(self.staged("nothing special here\n").returncode, 0)

    def test_denied_term_blocks_with_location(self):
        result = self.staged("line one\nworked for ACME last week\n")
        self.assertEqual(result.returncode, 1)
        self.assertIn("notes.md:2", result.stderr)
        self.assertIn("Acme", result.stderr)

    def test_removed_lines_are_not_flagged(self):
        self.write("notes.md", "Acme\n")
        self.commit()
        self.assertEqual(self.staged("generic\n").returncode, 0)

    def test_ascii_terms_match_whole_words_only(self):
        self.assertEqual(self.staged("Acmegrid and preacme are other words\n").returncode, 0)

    def test_camel_case_and_snake_case_identifiers_are_caught(self):
        for text in ("const AcmeClient = 1\n", "myAcme()\n", "ACMEClient\n", "acme_client\n"):
            self.assertEqual(self.staged(text).returncode, 1, text)

    def test_katakana_terms_ignore_longer_katakana_words(self):
        self.assertEqual(self.staged("ミドリムシの観察\n").returncode, 0)
        self.assertEqual(self.staged("ミドリへの提案\n").returncode, 1)

    def test_katakana_middle_dot_is_a_boundary(self):
        self.write_config("denylist.txt", "アクメ\n")
        self.assertEqual(self.staged("アクメ・ジャパンの件\n").returncode, 1)

    def test_kanji_terms_match_inside_text_and_nfd(self):
        self.assertEqual(self.staged(unicodedata.normalize("NFD", "株式会社アクメ商事の件\n")).returncode, 1)

    def test_fullwidth_and_halfwidth_forms_are_caught(self):
        self.assertEqual(self.staged("ＡＣＭＥの件\n").returncode, 1)
        self.assertEqual(self.staged("ｱｸﾒ商事の件\n").returncode, 1)

    def test_invisible_characters_do_not_split_a_term(self):
        self.assertEqual(self.staged("Ac​me and Ac­me\n").returncode, 1)

    def test_allowlist_removes_a_generic_term(self):
        self.write_config("allowlist.txt", "ミドリ\n")
        self.assertEqual(self.staged("ミドリへの提案\n").returncode, 0)

    def test_allowlisted_phrase_hides_only_that_phrase(self):
        self.write_config("allowlist.txt", "ultra_acme_mode\n")
        self.assertEqual(self.staged('{"id": "cfg.ultra_acme_mode"}\n', "data.json").returncode, 0)
        self.assertEqual(self.staged('{"id": "cfg.ultra_acme_mode", "note": "Acme"}\n', "data.json").returncode, 1)

    def test_a_short_allowlisted_word_does_not_hide_a_longer_term(self):
        self.write_config("denylist.txt", "Goldwing\nミドリガメ\n")
        self.write_config("allowlist.txt", "old\nミドリ\n")
        self.assertEqual(self.staged("met Goldwing yesterday\n").returncode, 1)
        self.assertEqual(self.staged("ミドリガメの件\n").returncode, 1)

    def test_a_term_that_starts_another_term(self):
        self.write_config("denylist.txt", "Acme\nAcmecorp\n")
        self.assertEqual(self.staged("Acmecorp and Acmecorporation\n").returncode, 1)
        self.assertEqual(self.staged("Acmecorporation only\n").returncode, 0)

    def test_large_change_with_many_terms_is_fast(self):
        import random
        import string
        import time
        rng = random.Random(1)
        terms = ["Term" + "".join(rng.choice(string.ascii_lowercase) for _ in range(6)) for _ in range(300)]
        self.write_config("denylist.txt", "\n".join(terms) + "\n")
        lines = "\n".join(f"lorem ipsum dolor sit amet consectetur {i}" for i in range(50000))
        self.write("big.txt", lines + "\n")
        self.stage()
        start = time.time()
        result = self.guard("staged")
        self.assertEqual(result.returncode, 0, result.stderr[-500:])
        self.assertLess(time.time() - start, 20)

    def test_many_short_terms_on_many_candidate_lines_stay_fast(self):
        import itertools
        import time
        terms = ["".join(pair) + "x" for pair in itertools.islice(itertools.product("abcdefghijklmnopqrst", repeat=2), 300)]
        self.write_config("denylist.txt", "\n".join(terms) + "\n")
        line = "aax" * 40  # every line is a candidate, nothing is a whole word
        self.write("big.txt", "\n".join(line for _ in range(20000)) + "\n")
        self.stage()
        start = time.time()
        result = self.guard("staged")
        self.assertEqual(result.returncode, 0, result.stderr[-300:])
        self.assertLess(time.time() - start, 20)

    def test_a_shorter_term_still_matches_where_a_longer_one_fails(self):
        self.write_config("denylist.txt", "acme\nacme-x\n")
        self.assertEqual(self.staged("acme-x1\n").returncode, 1)

    def test_report_is_capped(self):
        result = self.staged("Acme\n" * 70)
        self.assertEqual(result.returncode, 1)
        self.assertIn("and 20 more", result.stderr)


class DiffParsingTest(GuardCase):
    def test_non_ascii_file_names_are_scanned(self):
        result = self.staged("worked for Acme\n", "議事録.md")
        self.assertEqual(result.returncode, 1)
        self.assertIn("議事録.md:1", result.stderr)

    def test_nfd_file_names_are_scanned(self):
        self.assertEqual(self.staged("Acme\n", unicodedata.normalize("NFD", "ぱぴぷ.md")).returncode, 1)

    def test_file_names_of_binary_empty_and_renamed_files_are_checked(self):
        self.write("bin/acme-logo.bin", b"\x00\x01\x02", mode="wb")
        self.stage()
        self.assertEqual(self.guard("staged").returncode, 1)
        git(self.repo, "reset", "-q")
        os.remove(os.path.join(self.repo, "bin", "acme-logo.bin"))
        self.assertEqual(self.staged("", "acme-empty.txt").returncode, 1)
        git(self.repo, "reset", "-q")
        os.remove(os.path.join(self.repo, "acme-empty.txt"))
        self.write("a.md", "generic\n")
        self.commit()
        git(self.repo, "mv", "a.md", "acme-renamed.md")
        result = self.guard("staged")
        self.assertEqual(result.returncode, 1)
        self.assertIn("acme-renamed.md", result.stderr)

    def test_added_line_that_looks_like_a_diff_header(self):
        self.assertEqual(self.staged("++ intro\n@@ -1 +1 @@\nAcme\n").returncode, 1)

    def test_unicode_line_separators_do_not_hide_text(self):
        for sep in (" ", "\u0085", "\x0c", "\r"):
            self.assertEqual(self.staged(f"first{sep}Acme\n").returncode, 1, repr(sep))

    def test_user_diff_settings_do_not_break_parsing(self):
        for key, value in (("diff.mnemonicPrefix", "true"), ("diff.noprefix", "true"), ("core.quotePath", "true")):
            git(self.repo, "config", key, value)
        self.assertEqual(self.staged("Acme\n", "日本語.md").returncode, 1)

    def test_files_marked_binary_by_attributes_are_still_scanned(self):
        self.write(".gitattributes", "*.md -diff\n")
        self.commit()
        self.assertEqual(self.staged("Acme\n").returncode, 1)

    def test_shift_jis_and_euc_jp_text_is_scanned(self):
        for encoding in ("cp932", "euc_jp"):
            self.write("table.csv", "id,name\n1,アクメ商事\n".encode(encoding), mode="wb")
            self.stage()
            self.assertEqual(self.guard("staged").returncode, 1, encoding)
            git(self.repo, "reset", "-q")

    def test_utf8_with_a_stray_byte_is_still_read_as_utf8(self):
        # one invalid byte makes the text decodable as CP932 only; the UTF-8 reading must still be scanned
        self.write_config("denylist.txt", "アクメ\n")
        self.write("notes.md", b"\x80" + "アクメの件\n".encode("utf-8"), mode="wb")
        self.stage()
        self.assertEqual(self.guard("staged").returncode, 1)

    def test_content_of_a_file_with_a_non_utf8_name_is_scanned(self):
        blob = git(self.repo, "hash-object", "-w", "--stdin", stdin="Acme\n").strip()
        name = b"caf\xe9.md"
        subprocess.run([b"git", b"-C", self.repo.encode(), b"update-index", b"--add", b"--cacheinfo",
                        b"100644," + blob.encode() + b"," + name], check=True, capture_output=True)
        result = self.guard("staged")
        self.assertEqual(result.returncode, 1)
        self.assertIn(":1", result.stderr)

    def test_utf16_text_is_scanned(self):
        self.write("u16.txt", "﻿Acme notes\n".encode("utf-16-le"), mode="wb")
        self.stage()
        self.assertEqual(self.guard("staged").returncode, 1)

    def test_symlink_targets_and_type_changes_are_scanned(self):
        os.symlink("docs/acme/notes", os.path.join(self.repo, "link"))
        self.stage()
        self.assertEqual(self.guard("staged").returncode, 1)
        git(self.repo, "reset", "-q")
        os.remove(os.path.join(self.repo, "link"))
        os.symlink("generic", os.path.join(self.repo, "link"))
        self.commit()
        os.remove(os.path.join(self.repo, "link"))
        self.assertEqual(self.staged("Acme\n", "link").returncode, 1)


class ConfigTest(GuardCase):
    def test_terms_from_source_folders(self):
        vault = os.path.join(self.tmp, "vault")
        for rel in ("500-Globex/05-Work/Initech", "500-Globex/05-Work/Initech/01-out", "900-archive/Hooli"):
            os.makedirs(os.path.join(vault, *rel.split("/")))
        self.write_config("sources.txt", f"# folders\n{vault}/[0-9][0-9][0-9]-*\n{vault}/*/05-Work/*\n"
                                         f"{vault}/*/05-Work/*/*\n{vault}/900-archive/*\n")
        self.write_config("allowlist.txt", "archive\n")  # the archive folder matches the first glob
        for text, expected in (("Globex", 1), ("Initech", 1), ("Hooli", 1), ("out", 0), ("archive", 0)):
            self.assertEqual(self.staged(f"about {text}\n").returncode, expected, text)

    def test_nothing_below_a_numbered_folder_becomes_a_term(self):
        vault = os.path.join(self.tmp, "vault")
        for rel in ("500-Globex/05-Work/Initech/01-out/output", "500-Globex/05-Work/Initech/部A/課B"):
            os.makedirs(os.path.join(vault, *rel.split("/")))
        self.write_config("sources.txt", f"{vault}/*/05-Work/*/*/*\n")
        self.assertEqual(self.staged("the output folder\n").returncode, 0)
        self.assertEqual(self.staged("課B\n").returncode, 1)

    def test_config_files_with_a_byte_order_mark(self):
        with open(os.path.join(self.config, "denylist.txt"), "w", encoding="utf-8-sig") as handle:
            handle.write("Acme\n")
        self.assertEqual(self.staged("Acme\n").returncode, 1)

    def test_no_terms_fails_closed_unless_allowed(self):
        os.remove(os.path.join(self.config, "denylist.txt"))
        result = self.staged("Acme\n")
        self.assertEqual(result.returncode, 2)
        self.assertIn("no terms", result.stderr)
        self.assertEqual(self.guard("staged", env={"PUBLIC_GUARD_ALLOW_EMPTY": "1"}).returncode, 0)

    def test_sources_that_match_nothing_fail_closed(self):
        os.remove(os.path.join(self.config, "denylist.txt"))
        self.write_config("sources.txt", f"{self.tmp}/moved-vault/*\n")
        result = self.staged("generic\n")
        self.assertEqual(result.returncode, 2)
        self.assertIn("matched no folder", result.stderr)

    def test_skip_only_with_the_value_1(self):
        self.write("notes.md", "Acme\n")
        self.stage()
        self.assertEqual(self.guard("staged", env={"PUBLIC_GUARD_SKIP": "0"}).returncode, 1)
        result = self.guard("staged", env={"PUBLIC_GUARD_SKIP": "1"})
        self.assertEqual(result.returncode, 0)
        self.assertIn("skipped", result.stderr)

    def test_count_never_prints_terms(self):
        result = self.guard("count")
        self.assertEqual(result.returncode, 0)
        self.assertIn("3 terms", result.stdout)
        self.assertNotIn("Acme", result.stdout + result.stderr)


class MessageAndPushTest(GuardCase):
    def push(self, local_sha, remote_sha, local_ref="refs/heads/main", remote_ref="refs/heads/main"):
        return self.guard("pre-push", "origin", "url", stdin=f"{local_ref} {local_sha} {remote_ref} {remote_sha}\n")

    def test_commit_message_hook(self):
        path = os.path.join(self.tmp, "MSG")
        with open(path, "w", encoding="utf-8") as handle:
            handle.write("fix the Acme import\n\n# comment lines are ignored by git\n")
        self.assertEqual(self.guard("message", path).returncode, 1)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write("fix the import\n# Acme in a comment line is not part of the message\n")
        self.assertEqual(self.guard("message", path).returncode, 0)

    def test_pre_push_checks_added_lines_of_new_commits(self):
        self.write("a.md", "start\n")
        base = self.commit("base")
        self.write("a.md", "start\nAcme rollout\n")
        head = self.commit("generic message")
        result = self.push(head, base)
        self.assertEqual(result.returncode, 1)
        self.assertIn("a.md:2", result.stderr)

    def test_pre_push_checks_commit_messages(self):
        self.write("a.md", "start\n")
        base = self.commit("base")
        self.write("a.md", "start\nmore\n")
        head = self.commit("fix the Acme import")
        result = self.push(head, base)
        self.assertEqual(result.returncode, 1)
        self.assertIn("commit message", result.stderr)

    def test_pre_push_new_branch_checks_all_unpushed_commits(self):
        self.write("a.md", "Acme in the first commit\n")
        head = self.commit("first")
        self.assertEqual(self.push(head, "0" * 40).returncode, 1)

    def test_pre_push_checks_branch_names(self):
        self.write("a.md", "generic\n")
        head = self.commit("first")
        result = self.push(head, "0" * 40, remote_ref="refs/heads/feat/acme-support")
        self.assertEqual(result.returncode, 1)
        self.assertIn("ref name", result.stderr)

    def test_pre_push_checks_annotated_tag_messages(self):
        self.write("a.md", "generic\n")
        head = self.commit("first")
        git(self.repo, "tag", "-a", "v1", "-m", "release for Acme")
        tag = git(self.repo, "rev-parse", "v1").strip()
        result = self.push(tag, "0" * 40, local_ref="refs/tags/v1", remote_ref="refs/tags/v1")
        self.assertEqual(result.returncode, 1)
        self.assertIn("tag message", result.stderr)
        self.assertNotEqual(head, tag)

    def test_pre_push_deleting_a_branch_passes(self):
        self.write("a.md", "x\n")
        head = self.commit("x")
        self.assertEqual(self.push("0" * 40, head).returncode, 0)

    def test_pre_push_with_an_unknown_remote_commit_asks_to_fetch(self):
        self.write("a.md", "x\n")
        head = self.commit("x")
        result = self.push(head, "1" * 40)
        self.assertEqual(result.returncode, 2)
        self.assertIn("fetch", result.stderr)

    def test_files_mode_audits_tracked_files(self):
        self.write("ok.md", "fine\n")
        self.write("bad.md", "fine\nAcme\n")
        self.write("img.bin", b"\x00\x01Acme\x00", mode="wb")
        self.commit()
        result = self.guard("files")
        self.assertEqual(result.returncode, 1)
        self.assertIn("bad.md:2", result.stderr)
        self.assertNotIn("ok.md", result.stderr)
        self.assertNotIn("img.bin", result.stderr)


class InstallTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="public-guard-install.")
        self.addCleanup(shutil.rmtree, self.tmp)
        self.config = os.path.join(self.tmp, "config")
        os.makedirs(self.config)
        with open(os.path.join(self.config, "denylist.txt"), "w", encoding="utf-8") as handle:
            handle.write("Acme\n")

    def repo(self, name):
        path = os.path.join(self.tmp, name)
        os.makedirs(path)
        git(path, "init", "-q")
        return path

    def install(self, *args):
        env = {key: value for key, value in os.environ.items() if key not in CLEAN_ENV}
        env["PUBLIC_GUARD_CONFIG_DIR"] = self.config
        return subprocess.run(["bash", INSTALL, *args], capture_output=True, text=True, env=env)

    def hooks_path(self, repo):
        result = subprocess.run(["git", "-C", repo, "config", "--get", "core.hooksPath"], capture_output=True, text=True)
        return result.stdout.strip()

    def test_installs_into_a_plain_repository_and_check_passes(self):
        repo = self.repo("plain")
        result = self.install(repo)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(os.path.realpath(self.hooks_path(repo)), os.path.realpath(HOOKS_DIR))
        check = self.install("--check", repo)
        self.assertEqual(check.returncode, 0, check.stdout + check.stderr)
        self.assertIn("ok", check.stdout)

    def test_check_reports_a_repository_without_the_guard(self):
        repo = self.repo("bare")
        check = self.install("--check", repo)
        self.assertEqual(check.returncode, 1)
        self.assertIn("not installed", check.stdout + check.stderr)

    def test_leaves_a_repository_with_its_own_hooks_alone(self):
        repo = self.repo("own")
        with open(os.path.join(repo, ".git", "hooks", "pre-commit"), "w", encoding="utf-8") as handle:
            handle.write("#!/bin/sh\nexit 0\n")
        result = self.install(repo)
        self.assertIn("skip (has its own hooks", result.stderr)
        self.assertEqual(self.hooks_path(repo), "")

    def test_a_hooks_path_pointing_at_the_default_folder_counts_as_unset(self):
        repo = self.repo("default")
        git(repo, "config", "--local", "core.hooksPath", os.path.join(repo, ".git", "hooks"))
        self.assertEqual(self.install(repo).returncode, 0)
        self.assertEqual(os.path.realpath(self.hooks_path(repo)), os.path.realpath(HOOKS_DIR))

    def test_replaces_a_stale_public_guard_path(self):
        repo = self.repo("moved")
        git(repo, "config", "--local", "core.hooksPath", os.path.join(self.tmp, "old-place", "git-hooks"))
        self.assertEqual(self.install("--check", repo).returncode, 1)
        result = self.install(repo)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(os.path.realpath(self.hooks_path(repo)), os.path.realpath(HOOKS_DIR))
        old_copy = os.path.join(self.tmp, "copy-of-hooks")
        os.makedirs(old_copy)
        open(os.path.join(old_copy, "public_guard.py"), "w").close()
        git(repo, "config", "--local", "core.hooksPath", old_copy)
        self.assertEqual(self.install(repo).returncode, 0)
        self.assertEqual(os.path.realpath(self.hooks_path(repo)), os.path.realpath(HOOKS_DIR))

    def test_a_missing_foreign_hooks_path_is_left_alone(self):
        repo = self.repo("husky-later")
        git(repo, "config", "--local", "core.hooksPath", ".husky/_")  # husky creates it on install
        result = self.install(repo)
        self.assertIn("skip (has its own core.hooksPath", result.stderr)
        self.assertEqual(self.hooks_path(repo), ".husky/_")

    def test_relative_hooks_path_is_judged_from_the_top_of_the_repository(self):
        repo = self.repo("nested")
        os.makedirs(os.path.join(repo, "hooks-dir"))
        with open(os.path.join(repo, "hooks-dir", "pre-commit"), "w", encoding="utf-8") as handle:
            handle.write("#!/bin/sh\nexit 0\n")
        os.makedirs(os.path.join(repo, "sub", "deeper"))
        git(repo, "config", "--local", "core.hooksPath", "hooks-dir")
        result = self.install(os.path.join(repo, "sub", "deeper"))
        self.assertIn("skip (has its own core.hooksPath", result.stderr)
        self.assertEqual(self.hooks_path(repo), "hooks-dir")

    def test_leaves_another_hooks_path_alone(self):
        repo = self.repo("husky")
        os.makedirs(os.path.join(repo, ".husky"))
        with open(os.path.join(repo, ".husky", "pre-commit"), "w", encoding="utf-8") as handle:
            handle.write("#!/bin/sh\nexit 0\n")
        git(repo, "config", "--local", "core.hooksPath", ".husky")
        result = self.install(repo)
        self.assertIn("skip (has its own core.hooksPath", result.stderr)
        self.assertEqual(self.hooks_path(repo), ".husky")

    def test_worktrees_and_repositories_without_a_hooks_folder(self):
        repo = self.repo("main")
        git(repo, "-c", "user.email=t@example.com", "-c", "user.name=t", "commit", "-q", "--allow-empty", "-m", "x")
        shutil.rmtree(os.path.join(repo, ".git", "hooks"), ignore_errors=True)
        worktree = os.path.join(self.tmp, "wt")
        git(repo, "worktree", "add", "-q", worktree)
        result = self.install(worktree, repo)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"installed: {worktree}", result.stdout)


@unittest.skipUnless(HAS_GITLEAKS, "gitleaks not installed")
class SecretTest(GuardCase):
    TOKEN = "ghp_" + "a1B2c3D4e5F6g7H8i9J0k1L2m3N4o5P6q7R8"

    def test_staged_secret_blocks_without_printing_it(self):
        self.write("config.sh", f"export GITHUB_TOKEN={self.TOKEN}\n")
        self.stage()
        result = self.guard("staged", env={"PUBLIC_GUARD_NO_GITLEAKS": "0"})
        self.assertEqual(result.returncode, 1)
        self.assertNotIn(self.TOKEN, result.stdout + result.stderr)

    def test_pushed_secret_blocks(self):
        self.write("a.md", "start\n")
        base = self.commit("base")
        self.write("config.sh", f"export GITHUB_TOKEN={self.TOKEN}\n")
        head = self.commit("add config")
        result = self.guard("pre-push", "origin", "url", env={"PUBLIC_GUARD_NO_GITLEAKS": "0"},
                            stdin=f"refs/heads/main {head} refs/heads/main {base}\n")
        self.assertEqual(result.returncode, 1)
        self.assertNotIn(self.TOKEN, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
