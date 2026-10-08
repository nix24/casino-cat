"""Exact odds and EV for Casino Cat gamble moves (PRD §6). Fractions, no sampling.

Run: uv run python -I tools/gamble_math.py  (stdlib only).
the GDScript sim tests in tests/sim/ must agree with it within the PRD tolerances.
"""
from collections import Counter, defaultdict
from fractions import Fraction as F
from functools import lru_cache
from itertools import combinations, product


def tier(s):
    if s == 2: return (F(0), 4)
    if s <= 5: return (F(1, 2), 0)
    if s <= 8: return (F(1), 0)
    if s <= 10: return (F(2), 0)
    if s == 11: return (F(3), 0)
    return (F(4), 0)

def dice_table(n_dice, keep, low=1):
    dist = Counter()
    for faces in product(range(low, 7), repeat=n_dice):
        dist[sum(sorted(faces)[-keep:])] += 1
    tot = (7 - low) ** n_dice
    em = sum(F(c, tot) * tier(s)[0] for s, c in dist.items())
    bf = sum(F(c, tot) * tier(s)[1] for s, c in dist.items())
    tiers: defaultdict[str, F] = defaultdict(F)
    for s, c in dist.items():
        name = {2:"snake",12:"boxcars",11:"lucky"}.get(s, "cold" if s<=5 else "fair" if s<=8 else "hot")
        tiers[name] += F(c, tot)
    return em, bf, tiers

for label, n, k, low in [("Paw Roll 2d6", 2, 2, 1), ("Loaded Paws 3d6 keep 2", 3, 2, 1),
                         ("Paw Roll + Loaded (faces 2-6)", 2, 2, 2), ("Loaded Paws + Loaded (faces 2-6)", 3, 2, 2)]:
    em, bf, tiers = dice_table(n, k, low)
    print(f"{label}: E[mult]={float(em):.4f} ({em}) E[dmg@10]={float(em*10):.2f} E[backfire]={float(bf):.3f}")
    print("   tiers:", {t: f"{float(p)*100:.2f}%" for t, p in sorted(tiers.items())})
print(f"Snake Eyes: E[dmg]={float(F(36,6)+F(6*5,6)):.2f}")

# Coin
h = F(55, 100)
for k in range(1, 5):
    print(f"Double or Nothing cash@{k}: P={float(h**k)*100:.1f}% dmg={16*2**(k-1)} EV={float(h**k*16*2**(k-1)):.2f} E[backfire]={float((1-h**k)*3):.2f}")
print(f"Heads Up: E[dmg]={float(h*14):.2f}, E[MP]={float((1-h)*15):.2f}")
eh = sum(h**k for k in range(1, 6))
print(f"Hot Streak: E[heads]={float(eh):.3f} E[base dmg]={float(eh*9):.2f}")

# Cards: deck 1..10 x2
DECK = tuple([2]*10)  # counts for values 1..10
def draw_probs(deck):
    n = sum(deck)
    return [(v+1, F(c, n)) for v, c in enumerate(deck) if c]
def take(deck, v):
    d = list(deck); d[v-1] -= 1; return tuple(d)

@lru_cache(None)
def nine(deck, total, threshold, forgive):
    # policy: hit while total < threshold; returns expected (dmg, backfire)
    if total >= threshold:
        return (F(30) if total == 21 else F(total), F(0))
    ed, eb = F(0), F(0)
    for v, p in draw_probs(deck):
        t = total + v
        if t > 21:
            if forgive:
                d, b = (F(30) if total == 21 else F(total)), F(0)
            else:
                d, b = F(0), F(5)
        else:
            d, b = nine(take(deck, v), t, threshold, forgive)
        ed += p*d; eb += p*b
    return ed, eb

def nine_start(threshold, forgive):
    ed, eb = F(0), F(0)
    for v1, p1 in draw_probs(DECK):
        d1 = take(DECK, v1)
        for v2, p2 in draw_probs(d1):
            d, b = nine(take(d1, v2), v1+v2, threshold, forgive)
            ed += p1*p2*d; eb += p1*p2*b
    return ed, eb
for th in (14, 15, 16, 17, 18, 19, 20, 21):
    a = nine_start(th, False); b = nine_start(th, True)
    print(f"Nine Lives stand>={th}: EV no-forgive dmg={float(a[0]):.2f} bf={float(a[1]):.2f} | forgive dmg={float(b[0]):.2f}")
cards = [v for v in range(1, 11) for _ in range(2)]
print(f"High Card: E={float(F(sum(cards),20)*2):.2f}")
mx = [max(c) for c in combinations(cards, 3)]
print(f"Card Trick: E[max of 3]x2.5={float(F(sum(mx), len(mx))*F(5,2)):.2f}")

# Cups
print(f"Which Paw: no peek {float(F(28,3)):.2f}; with peek {float(F(20+10+14,3)):.2f}")
print(f"Double Cup: {float(F(2*(24+12+6+0),4)):.2f}")

# Scratch
W = {"F": F(2,10), "P": F(3,10), "Y": F(5,10)}
PAY3 = {"F": 36, "P": 24, "Y": 16}; PAY2 = {"F": 14, "P": 11, "Y": 9}
def best(cells):
    c = Counter(cells)
    four = [PAY3[s] * 2 for s, n in c.items() if n >= 4]
    if four: return max(four), 0
    best3 = [PAY3[s] for s, n in c.items() if n == 3]
    if best3: return max(best3), 0
    best2 = [PAY2[s] for s, n in c.items() if n == 2]
    if best2: return max(best2), 0
    return 4, 10
def scratch(n):
    ed = em = F(0); dist: defaultdict[int, F] = defaultdict(F)
    for cells in product("FPY", repeat=n):
        p = F(1)
        for s in cells: p *= W[s]
        d, m = best(cells); ed += p*d; em += p*m; dist[d] += p
    return ed, em, dist
for n in (3, 4):
    ed, em, dist = scratch(n)
    print(f"Scratch {n} cells: E[dmg]={float(ed):.2f} E[MP refund]={float(em):.2f} dist={ {k: f'{float(v)*100:.1f}%' for k,v in sorted(dist.items())} }")
print(f"Paw Print: E={float(W['F']*16+W['P']*11+W['Y']*8):.2f}")

# Ticket / Ante
print(f"Lucky Ticket: {float(F(3*10+4*20+2*30+45,10)):.2f}; Raffle: {float(F(60,3)+F(2*12,3)):.2f}")
print("All In: E[dmg]=2.0 x stake (win .6->3x, lose .4->0.5x); Raise: 0.44 x stake + 10")
