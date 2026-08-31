// darkHeroes.js - Next Level Dark Heroes: pay matching Room from hand → +3 HP.

export function darkHeroTreasure(hero) {
  return hero?.treasure ?? hero?.treasures?.[0] ?? null;
}

export function listDarkHeroPayTargets(G) {
  const targets = [];
  if (G.adventure?.hero?.dark) {
    targets.push({
      kind: 'adventure',
      ownerId: Number(G.adventure.playerId),
      hero: G.adventure.hero,
      label: `${G.adventure.hero.name} (in dungeon)`,
    });
  }
  for (const [pid, p] of Object.entries(G.players || {})) {
    if (p.eliminated) continue;
    (p.entrance || []).forEach((hero, index) => {
      if (!hero.dark) return;
      targets.push({
        kind: 'entrance',
        ownerId: Number(pid),
        index,
        hero,
        label: `${hero.name} @ Player ${pid}`,
      });
    });
  }
  return targets;
}

export function canPayDarkHero(G, payerId, handIndex, target) {
  if (G.phase !== 'build' && G.phase !== 'adventure') return false;
  const p = G.players[payerId] ?? G.players[String(payerId)];
  const card = p?.hand?.[handIndex];
  if (!card?.isRoom) return false;
  const t = darkHeroTreasure(target?.hero);
  if (t == null) return false;
  const treasures = card.treasures || [];
  return treasures.includes(t);
}

export function payDarkHero(G, payerId, handIndex, target) {
  if (!canPayDarkHero(G, payerId, handIndex, target)) return 'cannot pay dark hero';
  const p = G.players[payerId] ?? G.players[String(payerId)];
  const [card] = p.hand.splice(handIndex, 1);
  G.decks.roomDiscard.push(card);
  const hero = target.hero;
  const bonus = 3;

  if (target.kind === 'adventure' && G.adventure?.hero === hero) {
    G.adventure.hp = (G.adventure.hp ?? hero.hp) + bonus;
    G.logs.push(`Dark Hero paid: ${hero.name} gains +${bonus} HP (now ${G.adventure.hp}).`);
    return null;
  }

  if (target.kind === 'entrance') {
    hero._entranceHp = (hero._entranceHp ?? hero.hp) + bonus;
    G.logs.push(`Dark Hero paid: ${hero.name} at entrance gains +${bonus} HP.`);
    return null;
  }

  return 'invalid dark hero target';
}
