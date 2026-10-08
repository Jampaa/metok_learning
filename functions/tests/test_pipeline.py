"""Pipeline rules, with every outside service faked (no network)."""

import pipeline
from monlam import StubTts, extract_tibetan, is_clean
from pipeline import Vision


class Fake:
    def __init__(self, vision, vocab=None, dictionary=None, llm=None, audio="https://a/x.wav"):
        self._vision = vision
        self.vocab = dict(vocab or {})
        self._dictionary = dictionary
        self._llm = llm
        self._audio = audio
        self.audio_calls = []

    def vision(self, image):
        return self._vision

    def get_vocab(self, wid):
        return self.vocab.get(wid)

    def save_vocab(self, wid, doc):
        self.vocab[wid] = doc

    def dictionary(self, english, category):
        if isinstance(self._dictionary, Exception):
            raise self._dictionary
        return self._dictionary

    def llm_translate(self, english, category):
        return self._llm

    def audio_for(self, wid, tibetan):
        self.audio_calls.append(wid)
        return self._audio


NOW = lambda: "now"  # noqa: E731
APPLE = Vision("apple", "food", 0.93, True)


def run(fake):
    return pipeline.identify(b"jpeg", fake, now=NOW)


def test_low_confidence_retries():
    assert run(Fake(Vision("apple", "food", 0.4, True)))["status"] == "retry"


def test_not_kid_safe_retries_even_when_confident():
    r = run(Fake(Vision("knife", "kitchen", 0.99, False)))
    assert r == {"status": "retry", "reason": "not_kid_safe"}


def test_known_catalog_word_is_returned_and_not_rebuilt():
    fake = Fake(APPLE, vocab={"apple": {"english": "apple", "tibetan": "ཀུ་ཤུ", "verified": True, "audioUrl": "u"}},
                dictionary="SHOULD NOT BE CALLED")
    r = run(fake)
    assert r["status"] == "found"
    assert r["word"]["tibetan"] == "ཀུ་ཤུ"
    assert r["word"]["audioUrl"] == "u"
    assert fake.audio_calls == []


def test_new_word_from_dictionary_is_verified_and_gets_audio():
    fake = Fake(APPLE, dictionary="ཀུ་ཤུ")
    r = run(fake)
    assert r["word"] == {"id": "apple", "english": "apple", "tibetan": "ཀུ་ཤུ", "phonetic": "",
                         "verified": True, "audioUrl": "https://a/x.wav", "category": "food"}
    assert fake.vocab["apple"]["source"] == "monlam_dictionary"
    assert fake.audio_calls == ["apple"]


def test_llm_guess_is_saved_but_never_sent_to_the_app():
    fake = Fake(APPLE, dictionary=None, llm="ཀུ་ཤུ")
    r = run(fake)
    assert r["status"] == "found"
    assert r["word"]["tibetan"] == ""
    assert r["word"]["verified"] is False
    assert r["word"]["audioUrl"] is None
    assert fake.vocab["apple"] == {"english": "apple", "tibetan": "ཀུ་ཤུ", "phonetic": "", "verified": False,
                                   "source": "monlam_llm", "category": "food", "createdAt": "now"}
    assert fake.audio_calls == []


def test_dictionary_outage_falls_back_to_llm():
    fake = Fake(APPLE, dictionary=RuntimeError("down"), llm="ཀུ་ཤུ")
    assert run(fake)["word"]["verified"] is False


def test_unknown_word_still_counts_as_found_in_english():
    r = run(Fake(Vision("whisk", "kitchen", 0.9, True)))
    assert r["word"]["english"] == "whisk"
    assert r["word"]["tibetan"] == ""


def test_reviewed_flag_from_the_spec_also_counts_as_verified():
    fake = Fake(APPLE, vocab={"apple": {"english": "apple", "tibetan": "ཀུ་ཤུ", "reviewed": True}})
    assert run(fake)["word"]["verified"] is True


def test_audio_failure_does_not_lose_the_word():
    class Boom(Fake):
        def audio_for(self, wid, tibetan):
            raise RuntimeError("tts down")
    r = run(Boom(APPLE, dictionary="ཀུ་ཤུ"))
    assert r["word"]["tibetan"] == "ཀུ་ཤུ"
    assert r["word"]["audioUrl"] is None


def test_normalize_key():
    assert pipeline.normalize_key("  Teddy  Bear ") == "teddy-bear"
    assert pipeline.normalize_key("!!!") == "thing"


def test_monlam_helpers():
    assert extract_tibetan("apple ཀུ་ཤུ fruit") == "ཀུ་ཤུ"
    assert is_clean("ཀུ་ཤུ apple")
    assert not is_clean("n. 1. ཀུ་ཤུ 2. ...")


def test_stub_tts_is_a_wav():
    assert StubTts().synthesize("ཀ")[:4] == b"RIFF"


def test_gemini_falls_back_only_when_busy(monkeypatch):
    from google.genai import errors
    import gemini_vision

    calls = []

    def fake_ask(self, model, image):
        calls.append(model)
        if model == "main":
            raise errors.ServerError(503, {"error": {"message": "busy", "status": "UNAVAILABLE"}}, None)
        return Vision("cup", "kitchen", 0.9, True)

    monkeypatch.setattr(gemini_vision.GeminiVision, "_ask", fake_ask)
    v = gemini_vision.GeminiVision("k", "main", "backup")
    assert v(b"x").english == "cup"
    assert calls == ["main", "backup"]


def test_gemini_does_not_fall_back_on_bad_request(monkeypatch):
    from google.genai import errors
    import gemini_vision
    import pytest

    def fake_ask(self, model, image):
        raise errors.ClientError(400, {"error": {"message": "bad", "status": "INVALID_ARGUMENT"}}, None)

    monkeypatch.setattr(gemini_vision.GeminiVision, "_ask", fake_ask)
    with pytest.raises(errors.ClientError):
        gemini_vision.GeminiVision("k", "main", "backup")(b"x")
