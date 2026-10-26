"""Tests logic sao chất lượng (thuần toán, không I/O)."""

from __future__ import annotations

from app.services import quality_rating as qr


def _crit(**kw):
    base = {k: False for k in qr.CRITERIA_KEYS}
    base.update(kw)
    return base


def test_star_all_criteria():
    c = _crit(pccc=True, full_furniture=True, kitchen=True,
              private_bathroom=True, air_conditioner=True)
    assert qr.compute_self_star(c) == 5


def test_star_none():
    assert qr.compute_self_star(_crit()) == 1


def test_pccc_gates_max_3():
    # 4 tiêu chí đạt nhưng THIẾU PCCC → tối đa 3★.
    c = _crit(full_furniture=True, kitchen=True,
              private_bathroom=True, air_conditioner=True)
    assert qr.compute_self_star(c) == 3


def test_star_with_pccc_scales():
    c = _crit(pccc=True, full_furniture=True, private_bathroom=True)  # 3 tiêu chí
    assert qr.compute_self_star(c) == 3  # 1 + 3*0.8 = 3.4 → 3


def test_normalize_only_known_keys():
    n = qr.normalize_criteria({"pccc": 1, "junk": True, "kitchen": "yes"})
    assert set(n.keys()) == set(qr.CRITERIA_KEYS)
    assert n["pccc"] is True and n["kitchen"] is True
    assert n["full_furniture"] is False


def test_suggested_price_scales_with_star():
    p3 = qr.suggested_price(25, 3, 150000)
    p5 = qr.suggested_price(25, 5, 150000)
    assert p3 == round(25 * 150000 * 1.0)
    assert p5 == round(25 * 150000 * 1.3)
    assert p5 > p3


def test_suggested_price_zero_area():
    assert qr.suggested_price(0, 5, 150000) == 0
