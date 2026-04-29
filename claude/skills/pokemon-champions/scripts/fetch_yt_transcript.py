#!/usr/bin/env python3
"""YouTube 字幕取得スクリプト (skill 内蔵 / 認証不要 / pure Python).

Usage:
    python3 scripts/fetch_yt_transcript.py <video_id_or_url> [<lang>]
    python3 scripts/fetch_yt_transcript.py ej2RqEWGUig ja

依存: youtube-transcript-api
    pip3 install --user youtube-transcript-api

返却: 字幕テキスト全文を stdout に出力。
注意: 字幕が存在しない動画では失敗する。
      Pokemon 系の主要配信者は自動字幕がほぼ全動画にあるので実用上問題ない。

参考実装: https://github.com/jdepoix/youtube-transcript-api
"""
import sys
import re
from urllib.parse import urlparse, parse_qs


def extract_video_id(s: str) -> str:
    """URL or 11-char ID から video_id を抽出."""
    if re.match(r'^[A-Za-z0-9_-]{11}$', s):
        return s
    u = urlparse(s)
    if u.hostname in ('youtu.be',):
        return u.path.lstrip('/')
    if u.hostname and 'youtube.com' in u.hostname:
        if u.path == '/watch':
            return parse_qs(u.query).get('v', [''])[0]
        m = re.search(r'/(?:embed|shorts|live)/([A-Za-z0-9_-]{11})', u.path)
        if m:
            return m.group(1)
    raise ValueError(f"video_id を抽出できない: {s}")


def fetch(video_id: str, lang: str = 'ja') -> str:
    """字幕を取得して全文文字列で返す."""
    from youtube_transcript_api import YouTubeTranscriptApi
    api = YouTubeTranscriptApi()
    tr = api.fetch(video_id, languages=[lang, f"{lang}-JP", 'en'])
    return "\n".join(s.text for s in tr.snippets)


def main():
    if len(sys.argv) < 2:
        sys.exit("Usage: fetch_yt_transcript.py <video_id_or_url> [<lang>]")
    vid = extract_video_id(sys.argv[1])
    lang = sys.argv[2] if len(sys.argv) > 2 else 'ja'
    print(fetch(vid, lang))


if __name__ == '__main__':
    main()
